--!strict
-- Single source of truth for every analytics name, step, bucket and limit.
-- Agents: read docs/analytics/AGENT_GUIDE.md before changing or reading data.
-- Rules: never reorder or rename an onboarding step, funnel step, counter or
-- bucket label in place. Append new ones and bump Schema.Version so old and new
-- data stay comparable. Studio never sends Roblox analytics (Roblox ignores it).
local Schema = {}

-- 2 (October 14 launch): onboarding step 20 Rebirth1, daily source, Rebirth
-- sink/feature, launch counters and the bigCash/longSeconds buckets.
-- 3 (October 14): mission.* launch counters.
-- 4 (October 15): the Secret rarity (roll.offer/buy, Recruit sink, crate labels).
-- 5 (October 16): full tracking plan (docs/analytics/TRACKING_PLAN.md): feature
-- funnels for every system, client UI events (menus, buttons, prompts, idle),
-- server events, real Robux from receipts, device/segment profile, state snapshots.
-- 6 (October 20): Playtime funnel (session length checkpoints, Schema.Playtime).
Schema.Version = 6

-- Agent ledger (DataStores). Studio writes to the _Studio twins so test runs
-- never pollute live data.
Schema.LedgerStore = "PetRollAnalytics_v1"
Schema.PlayerStore = "PetRollAnalyticsPlayers_v1"
Schema.StudioSuffix = "_Studio"
-- Scaling knobs. A server always writes the same shard, so contention per key is
-- servers/Shards per FlushSeconds. Raise Shards (never lower) if flushes throttle.
Schema.Shards = 16
Schema.FlushSeconds = 180
Schema.ProfileSaveSeconds = 300
Schema.PerfSampleSeconds = 60
Schema.EconomyFlushSeconds = 120
Schema.JourneyCapPerKey = 60   -- sampled journeys per day per shard key
Schema.JourneyEventCap = 60    -- trail entries kept per journey
Schema.TopCap = 150            -- distinct keys per top table per bucket
Schema.TopKeyLength = 96
Schema.PendingDayLimit = 3     -- unflushed days kept in memory after failures

-- Key formats inside Schema.LedgerStore:
--   d/<YYYY-MM-DD>/<shard>  daily aggregate written by servers (UTC days)
--   j/<YYYY-MM-DD>/<shard>  sampled player journeys
--   r/<YYYY-MM-DD>          rollup cached by AnalyticsReport for finished days
-- Key format inside Schema.PlayerStore: p/<userId>
function Schema.DayKey(day: string, shard: number): string return "d/" .. day .. "/" .. shard end
function Schema.JourneyKey(day: string, shard: number): string return "j/" .. day .. "/" .. shard end
function Schema.RollupKey(day: string): string return "r/" .. day end
function Schema.PlayerKey(userId: number): string return "p/" .. userId end

-- Onboarding funnel. Index = Roblox LogOnboardingFunnelStepEvent step and the NN in
-- ledger names (onb.reach.NN). Only players first seen with a fresh save are
-- "tracked" into it. Steps can be reached out of order; Roblox auto-completes
-- skipped earlier steps, the ledger records what actually happened.
Schema.Onboarding = {
	{id = "Joined",        about = "PlayerAdded on a server; plot assigned."},
	{id = "ProfileLoaded", about = "Game save loaded (or Studio session ready)."},
	{id = "IntroStarted",  about = "Client began the first-visit film (optional: no film for reduced motion).", optional = true},
	{id = "IntroEnded",    about = "Film finished or skipped (or client reported no film)."},
	{id = "ControlReady",  about = "Loading veil gone; player has control (TutorialSignal Ready)."},
	{id = "FirstEgg",      about = "First egg picked up (tutorial.collectedEggCount > 0)."},
	{id = "Collect",       about = "Guide egg goal reached (TutorialGuide.EggGoal eggs)."},
	{id = "Sell",          about = "First egg deposit at the sell pad."},
	{id = "Roll",          about = "First lever pull."},
	{id = "Recruit",       about = "First recruit bought from a roll offer."},
	{id = "Grow",          about = "Owns 4+ chickens."},
	{id = "Expand",        about = "Army size (capacity) 4+."},
	{id = "Select",        about = "4+ chickens selected for the army."},
	{id = "Deploy",        about = "Army sent to a camp (guideDeployed)."},
	{id = "Win",           about = "First camp captured (Cluck Camp in practice)."},
	{id = "GuideComplete", about = "Commander guide marked complete."},
	{id = "Camp2",         about = "Fort Roost first win."},
	{id = "Camp3",         about = "Ironbeak HQ first win."},
	{id = "King",          about = "Chicken King first clear."},
	{id = "Rebirth1",      about = "First re-enlist (Veteran I)."},
}
-- Roblox auto-completes every earlier step when a later one is logged, so
-- Analytics sends steps strictly in this order. A missing step is passed over
-- only when it is optional and a later step happened, or when this many later
-- steps happened (onb.robloxGapFill.NN counts each pass-over).
Schema.RobloxGapRelease = 3
Schema.OnboardingIndex = {} :: {[string]: number}
for index, step in Schema.Onboarding do Schema.OnboardingIndex[step.id] = index end
function Schema.StepCode(index: number): string return string.format("%02d", index) end
function Schema.StepName(index: number): string
	return Schema.StepCode(index) .. " " .. Schema.Onboarding[index].id
end

-- Recurring funnels (Roblox LogFunnelStepEvent). Onboarding counts as one of
-- Roblox's 10 funnel dashboards, so at most 9 here.
Schema.Funnels = {
	Roll = {"Rolled", "AffordableOffer", "Recruited"},
	Shop = {"Prompted", "Purchased"},
	Camp = {"Deployed", "Won"},
	-- Version 5: five more Roblox dashboards (9 of 10 with onboarding). Sent by
	-- AnalyticsFunnels from the matching FeatureFunnels steps (RobloxSteps below).
	Research = {"TreeOpened", "Started", "Completed"},
	Fuse = {"Available", "Opened", "Fused"},
	Rebirth = {"Eligible", "Opened", "Rebirthed"},
	Mission = {"Spawned", "Started", "Won"},
	Daily = {"Available", "Opened", "Claimed"},
	Playtime = {} :: {string}, -- version 6: checkpoint labels, filled from Schema.Playtime below
}
Schema.RollFunnelSessionCap = 30 -- Roblox roll-funnel sessions per player session (rate budget)

-- Version 6 Playtime funnel: how long one session lasts since PlayerAdded. Checkpoints
-- every 10 seconds for the first minute, then every minute up to 100 minutes (105).
-- Ledger: play.start (every join), play.s.<NNN> (sessions that reached checkpoint
-- NNN), play.last.<NNN> (sessions whose last checkpoint was NNN; 000 = left before
-- 10 s). Roblox allows 100 steps per funnel, so its "Playtime" dashboard (the 10th
-- and last funnel slot) gets the first 100 checkpoints (10s .. 95m); the ledger has
-- all 105. One Roblox funnel session per game session.
Schema.Playtime = {} :: {{seconds: number, label: string}}
for seconds = 10, 50, 10 do table.insert(Schema.Playtime, {seconds = seconds, label = seconds .. "s"}) end
for minute = 1, 100 do table.insert(Schema.Playtime, {seconds = minute * 60, label = minute .. "m"}) end
for index = 1, math.min(#Schema.Playtime, 100) do Schema.Funnels.Playtime[index] = Schema.Playtime[index].label end
function Schema.PlaytimeCode(index: number): string return string.format("%03d", index) end

-- Roblox progression path for the main route.
Schema.MainRoute = {path = "MainRoute", levels = {"Cluck Camp", "Fort Roost", "Ironbeak HQ", "Chicken King"}}

-- Economy. One Roblox currency. Sources are batched per player; sinks are sent live.
Schema.Currency = "Cash"
Schema.Sources = {
	eggs      = {transaction = "Gameplay",    sku = "EggSale"},
	battle    = {transaction = "Gameplay",    sku = "BattleBounty"},
	operation = {transaction = "Gameplay",    sku = "OperationReward"},
	territory = {transaction = "Gameplay",    sku = "TerritoryIncome"},
	sale      = {transaction = "Shop",        sku = "ChickenSale"},
	offline   = {transaction = "TimedReward", sku = "OfflineEarnings"},
	robux     = {transaction = "IAP",         sku = "CashPack"},
	daily     = {transaction = "TimedReward", sku = "DailyStreak"},
}
Schema.IgnoredSources = {debug = true}
Schema.Sinks = {
	Buy            = {transaction = "Shop",     sku = "Recruit"},     -- sku gets ":<Rarity>"
	CashUpgrade    = {transaction = "Shop",     sku = "Upgrade"},     -- sku gets ":<upgradeKey>"
	BoardUpgrade   = {transaction = "Shop",     sku = "Upgrade"},
	Luck           = {transaction = "Shop",     sku = "Upgrade:Luck"},
	Income         = {transaction = "Shop",     sku = "Upgrade:Income"},
	Expand         = {transaction = "Shop",     sku = "ArmySize"},
	UpgradeChicken = {transaction = "Shop",     sku = "ChickenLevel"},
	Merge          = {transaction = "Shop",     sku = "Fusion"},
	MergeAll       = {transaction = "Shop",     sku = "Fusion"},
	StartResearch  = {transaction = "Gameplay", sku = "Research"},
	EggSellerUpgrade = {transaction = "Shop",   sku = "EggSeller"},
	StartOperation = {transaction = "Gameplay", sku = "Operation"},
	-- The whole wallet removed by a re-enlist (the cost plus the cash reset).
	Rebirth        = {transaction = "Gameplay", sku = "Rebirth"},
}
Schema.Rarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"}

-- First-use feature adoption, keyed by the request action that proves use.
Schema.Features = {
	CashUpgrade = "Upgrades", BoardUpgrade = "Upgrades", Luck = "Upgrades", Income = "Upgrades",
	StartResearch = "Research", Merge = "Fusion", MergeAll = "Fusion", UpgradeChicken = "ChickenLevel",
	SaveFormation = "Formations", ApplyFormation = "Formations", StartOperation = "Operations",
	OpenCrate = "Crate", Sell = "SellChicken", SetCommerceToggle = "PassToggle", Rally = "Rally",
	CallArmy = "CallArmy", PreparePurchase = "ShopPrompt", Favorite = "Favorite", Attack = "Attack",
	UnclaimTerritory = "Territory", Rebirth = "Rebirth",
}

-- Launch sprint ledger names (docs/team/launch). Workers record them through
-- Analytics:LaunchCount / LaunchHist / LaunchFirst, which drop any other name.
-- A trailing ".<N>" or ".<id>" suffix is allowed on every prefix below.
-- act.Rebirth / act.Rebirth.fail and feature.first.Rebirth come from Analytics:Action.
Schema.LaunchCounters = {
	["rebirth.count"] = true,     -- every successful re-enlist
	["rebirth.rank"] = true,      -- rebirth.rank.<N>: first time a player reaches rank N (LaunchFirst)
	["daily.claim"] = true,       -- daily.claim.<1..7>: streak reward slot granted
	["daily.reset"] = true,       -- a streak of 2+ broken by a missed day
	["mutation.offer"] = true,    -- mutation.offer.<id>
	["mutation.buy"] = true,      -- mutation.buy.<id>
	["mutation.fuse"] = true,     -- mutation.fuse.<id>
	["event.offer"] = true,       -- event.offer.<species>
	["event.buy"] = true,         -- event.buy.<species>
	["giant.fuse"] = true,        -- giant.fuse.<Fused|NewGiant|Giant|NewColossal|Colossal> (October 14)
	-- October 14 Missions (docs/team/MISSIONS_PLAN.md); every suffix is the tier 1..3.
	["mission.spawn"] = true,     -- a waiting site appeared
	["mission.expired"] = true,   -- a waiting site left unattacked
	["mission.start"] = true,     -- the army was sent
	["mission.won"] = true,
	["mission.lost"] = true,
	["mission.timeout"] = true,   -- the 3-minute fight limit ran out
}
-- Histogram name (prefix) -> bucket kind.
Schema.LaunchHistograms = {
	["rebirth.playSeconds"] = "longSeconds", -- rebirth.playSeconds.<N>: total play when rank N was reached
	["rebirth.cashAtRebirth"] = "bigCash",
	["daily.streak"] = "count",
}
-- Analytics profile field: highest re-enlist rank seen (profile.rebirths).

-- Feature funnels (version 5, ledger; docs/analytics/TRACKING_PLAN.md section 3).
-- Each funnel is a linear list of step ids. AnalyticsFunnels records a step once
-- per session (fun.<F>.s.<NN>) and once per player ever (fun.<F>.p.<NN>, profile
-- field fun[F][NN] = play seconds), the play seconds from the funnel's first step
-- to this one (fun.<F>.t.<NN>), and at session end the furthest step of every
-- funnel started that session (fun.<F>.last.<NN>). NN = two-digit step index.
-- `trigger` documents where the step comes from:
--   action:<Action>      a successful request (Analytics:Action)
--   fail:<Action>        a rejected request
--   state:<fact>         derived from the client snapshot (Analytics:Observe)
--   client:<event>[=d]   a validated client UI event (Analytics:ClientEvents)
--   server:<event>[=d]   a server event (Analytics:ServerEvent / LaunchCount names)
--   robux:<key prefix>   a granted Robux purchase
-- Append steps only at the end of a funnel; never reorder.
Schema.FeatureFunnels = {
	{id = "Roll", steps = {
		{id = "Pulled", trigger = "action:Roll"},
		{id = "OfferAffordable", trigger = "action:Roll with an affordable offer"},
		{id = "Recruited", trigger = "action:Buy"},
		{id = "Recruited10", trigger = "10 recruits ever (profile life.buys)"},
		{id = "RareOrBetter", trigger = "recruited a Rare+ chicken"},
		{id = "EpicOrBetter", trigger = "recruited an Epic+ chicken"},
		{id = "LegendaryOrBetter", trigger = "recruited a Legendary+ chicken"},
	}},
	{id = "RollSlots", steps = {
		{id = "Unlocked2", trigger = "state:rollSlotCount>=2"},
		{id = "Unlocked4", trigger = "state:rollSlotCount>=4"},
		{id = "Unlocked8", trigger = "state:rollSlotCount>=8"},
	}},
	{id = "AutoRoll", steps = {
		{id = "Available", trigger = "state:research completed AutoRoll"},
		{id = "Enabled", trigger = "action:SetAutoRoll (on)"},
		{id = "Stopped", trigger = "server:autoroll.stop"},
	}},
	{id = "Upgrades", steps = {
		{id = "MenuOpened", trigger = "client:menu.open=Upgrades"},
		{id = "Inspected", trigger = "client:inspect=Upgrades/*"},
		{id = "FirstBuy", trigger = "action:CashUpgrade|BoardUpgrade|Luck|Income|Expand"},
		{id = "Buys10", trigger = "10 cash upgrades ever"},
		{id = "Buys50", trigger = "50 cash upgrades ever"},
	}},
	{id = "Research", steps = {
		{id = "TreeOpened", trigger = "client:menu.open=Upgrades"},
		{id = "NodeInspected", trigger = "client:inspect=Upgrades/node"},
		{id = "Started", trigger = "action:StartResearch"},
		{id = "Completed", trigger = "state:research.completed count rose"},
		{id = "Completed5", trigger = "state:5 nodes completed"},
		{id = "Completed15", trigger = "state:15 nodes completed"},
		{id = "SkipPrompted", trigger = "action:PreparePurchase ResearchSkip*"},
		{id = "SkipBought", trigger = "robux:ResearchSkip"},
	}},
	{id = "Fuse", steps = {
		{id = "Unlocked", trigger = "state:mergeUnlocked"},
		{id = "Available", trigger = "state:mergeOptions not empty"},
		{id = "Opened", trigger = "action:OpenMerge or client:menu.open=Fuse"},
		{id = "Fused", trigger = "action:Merge|MergeAll"},
		{id = "Fused5", trigger = "5 fusions ever"},
		{id = "Giant", trigger = "server:giant.fuse NewGiant/Giant"},
		{id = "Colossal", trigger = "server:giant.fuse NewColossal/Colossal"},
	}},
	{id = "ChickenLevel", steps = {
		{id = "ArmyOpened", trigger = "client:menu.open=Army"},
		{id = "ChickenInspected", trigger = "client:inspect=Army/chicken"},
		{id = "Upgraded", trigger = "action:UpgradeChicken"},
		{id = "Upgraded10", trigger = "10 chicken levels ever"},
	}},
	{id = "Army", steps = {
		{id = "ArmyOpened", trigger = "client:menu.open=Army"},
		{id = "Selected", trigger = "action:SelectBest|SetArmy|Equip"},
		{id = "Deployed", trigger = "action:Attack"},
		{id = "Won", trigger = "camp first win (Progress firstWin)"},
		{id = "CallArmy", trigger = "action:CallArmy"},
		{id = "Rally", trigger = "action:Rally"},
		{id = "Formation", trigger = "action:SaveFormation|ApplyFormation"},
	}},
	{id = "Route", steps = {
		{id = "Camp1", trigger = "state:firstWins[1]"},
		{id = "Camp2", trigger = "state:firstWins[2]"},
		{id = "Camp3", trigger = "state:firstWins[3]"},
		{id = "AllCamps", trigger = "state:allCampsWon"},
		{id = "King", trigger = "state:kingCleared"},
	}},
	{id = "Sell", steps = {
		{id = "Opened", trigger = "action:OpenSell or client:menu.open=Sell"},
		{id = "Sold", trigger = "action:Sell"},
	}},
	{id = "Index", steps = {
		{id = "Opened", trigger = "client:menu.open=Index"},
		{id = "Inspected", trigger = "client:inspect=Index/*"},
	}},
	{id = "Shop", steps = {
		{id = "Opened", trigger = "client:menu.open=Shop or action:RefreshShop"},
		{id = "TabViewed", trigger = "client:tab=Shop/*"},
		{id = "Prompted", trigger = "action:PreparePurchase"},
		{id = "PromptShown", trigger = "client:prompt.shown"},
		{id = "Purchased", trigger = "robux:*"},
		{id = "Repeat", trigger = "second Robux purchase ever"},
	}},
	{id = "Crate", steps = {
		{id = "Viewed", trigger = "client:tab=Shop/Crates or client:menu.open=Crate"},
		{id = "Prompted", trigger = "action:PreparePurchase OuterSpaceCrate*"},
		{id = "Bought", trigger = "robux:OuterSpaceCrate"},
		{id = "Opened", trigger = "action:OpenCrate"},
	}},
	{id = "Pass", steps = {
		{id = "Prompted", trigger = "action:PreparePurchase for a pass key"},
		{id = "Bought", trigger = "robux pass"},
		{id = "Toggled", trigger = "action:SetCommerceToggle"},
	}},
	{id = "Rebirth", steps = {
		{id = "Eligible", trigger = "state:rebirth.eligible"},
		{id = "Opened", trigger = "client:menu.open=Rebirth"},
		{id = "Rebirthed", trigger = "action:Rebirth"},
		{id = "Rebirth2", trigger = "state:rebirth.rank>=2"},
		{id = "Rebirth5", trigger = "state:rebirth.rank>=5"},
		{id = "Rebirth10", trigger = "state:rebirth.rank>=10"},
	}},
	{id = "Mission", steps = {
		{id = "Spawned", trigger = "server:mission.spawn"},
		{id = "Opened", trigger = "client:menu.open=Missions"},
		{id = "Started", trigger = "action:StartOperation or server:mission.start"},
		{id = "Won", trigger = "server:mission.won"},
		{id = "Won5", trigger = "5 missions won ever"},
	}},
	{id = "Daily", steps = {
		{id = "Available", trigger = "state:daily reward claimable"},
		{id = "Opened", trigger = "client:menu.open=Daily"},
		{id = "Claimed", trigger = "server:daily.claim"},
		{id = "Streak3", trigger = "server:daily.claim with streak>=3"},
		{id = "Streak7", trigger = "server:daily.claim with streak>=7"},
	}},
	{id = "Offline", steps = {
		{id = "Shown", trigger = "server:offline.shown or client:menu.open=Offline"},
		{id = "Claimed", trigger = "server:offline.claimed"},
	}},
	{id = "Plot", steps = {
		{id = "Expanded", trigger = "action:BoardUpgrade PlotSize"},
		{id = "BuildStarted", trigger = "server:plot.buildStart"},
		{id = "BuildDone", trigger = "server:plot.buildDone"},
		{id = "Max", trigger = "state:collectionLimit>=100"},
	}},
	{id = "Hill", steps = {
		{id = "Entered", trigger = "server:hill.enter"},
		{id = "Held", trigger = "server:hill.hold"},
		{id = "Won", trigger = "server:hill.win"},
	}},
	{id = "Settings", steps = {
		{id = "Opened", trigger = "client:menu.open=Settings"},
		{id = "Changed", trigger = "client:setting"},
	}},
	{id = "Leaderboard", steps = {
		{id = "Viewed", trigger = "client:leaderboard.view"},
	}},
}
Schema.FeatureFunnelIndex = {} :: {[string]: {[string]: number}}
for _, funnel in Schema.FeatureFunnels do
	local index = {}
	for i, step in funnel.steps do index[step.id] = i end
	Schema.FeatureFunnelIndex[funnel.id] = index
end
-- Feature funnel step -> Roblox funnel step (Schema.Funnels). One Roblox funnel
-- session per player per funnel per UTC day.
Schema.RobloxSteps = {
	Research = {TreeOpened = 1, Started = 2, Completed = 3},
	Fuse = {Available = 1, Opened = 2, Fused = 3},
	Rebirth = {Eligible = 1, Opened = 2, Rebirthed = 3},
	Mission = {Spawned = 1, Started = 2, Won = 3},
	Daily = {Available = 1, Opened = 2, Claimed = 3},
}

-- Menus the client reports (menu.open / menu.close / ui.click / tab / inspect).
-- Unknown menu names are stored as "Other".
Schema.Menus = {
	Army = true, Shop = true, Index = true, Upgrades = true, Fuse = true, Settings = true, Odds = true,
	Offline = true, Rebirth = true, Daily = true, Missions = true, Sell = true, Formations = true,
	Crate = true, Admin = true, Hud = true, Roll = true, Merchant = true, Leaderboard = true, Other = true,
}

-- Client UI events (Analytics:ClientEvents). Batched by AnalyticsClient; the server
-- validates every name, clamps values and rate-limits (ClientEventsPerMinute).
-- kind: "menu" detail must be a Schema.Menus key; "path" detail is "<Menu>/<Name>"
-- (<= 48 chars, [%w_ /:%-%.]); "free" detail is a short token (<= 32 chars);
-- "none" ignores detail. value: seconds or a count, clamped to 0..86400.
Schema.ClientEvents = {
	["menu.open"] = "menu",      -- a menu became visible
	["menu.close"] = "menu",     -- value = seconds it was open (menu.dwell.<Menu> hist)
	["ui.click"] = "path",       -- any button activated: "<Menu>/<ButtonName>" (top table + counter)
	["tab"] = "path",            -- a tab/section chosen inside a menu: "<Menu>/<Tab>"
	["inspect"] = "path",        -- a card/node/chicken opened for details: "<Menu>/<kind>"
	["prompt.shown"] = "free",   -- a Roblox purchase prompt appeared: "<product|pass>:<key>"
	["prompt.result"] = "free",  -- "<key>:<bought|cancel>"
	["idle.start"] = "none",     -- no input for IdleSeconds
	["idle.end"] = "none",       -- value = idle seconds
	["setting"] = "free",        -- "<name>=<value>"
	["hint.shown"] = "free",     -- a guide/hint card appeared: <hint id>
	["hint.closed"] = "free",
	["load.phase"] = "free",     -- value = seconds since join: <phase>
	["leaderboard.view"] = "free", -- walked up to / opened a leaderboard: <board>
	["camera.zoom"] = "none",    -- value = zoom changes this minute (engagement proxy)
	["chat.sent"] = "none",      -- a chat message was sent (count only; never content)
	["emote"] = "none",
	["menu.blocked"] = "menu",   -- tried to open a menu that refused (locked/busy)
}
Schema.ClientEventsPerMinute = 120
Schema.ClientEventBatch = 50
Schema.IdleSeconds = 120

-- Server events (Analytics:ServerEvent). name -> {detail = "free"|"none"|"tier"|"level"}.
-- Counted as sev.<name>[.<detail>] and forwarded to AnalyticsFunnels/AnalyticsPlayer.
Schema.ServerEvents = {
	["offline.shown"] = "none",     -- value = cash offered
	["offline.claimed"] = "free",   -- detail = how it was claimed
	["plot.buildStart"] = "level",
	["plot.buildDone"] = "level",
	["plot.buildSkip"] = "level",
	["hill.enter"] = "none",
	["hill.hold"] = "none",         -- value = seconds held
	["hill.win"] = "none",
	["hill.lost"] = "none",
	["autoroll.stop"] = "free",     -- detail = stop reason
	["data.saveFail"] = "free",     -- detail = short reason
	["data.saveOk"] = "none",
	["remote.throttled"] = "free",  -- detail = action name
	["research.complete"] = "free", -- detail = node id
	["battle.end"] = "free",        -- detail = "<kind>:<result>", value = seconds
	["merchant.open"] = "none",
	["eggs.deposit"] = "none",      -- value = eggs deposited
	["egg.pickup"] = "none",        -- value = eggs picked up (batched)
	["daily.shown"] = "none",
	["giant.result"] = "free",      -- detail = Fused/NewGiant/Giant/NewColossal/Colossal
	["mission.result"] = "free",    -- detail = "<won|lost|timeout|expired>.<tier>"
}

-- Device tiers (AnalyticsPlayer.DeviceTier). A proxy from screen, memory, frame
-- rate and graphics quality: Roblox does not expose the device model.
Schema.DeviceTiers = {"Low", "Mid", "High", "Unknown"}

-- Per-player state snapshot at session end (AnalyticsPlayer): ledger hist
-- state.<name> with the bucket kind given here.
Schema.StateSnapshot = {
	rebirths = "count", eggSpeed = "count", eggValue = "count", luck = "count", rollSlots = "count",
	plotLevel = "count", armySize = "count", flock = "count", research = "count", campsWon = "count",
	missionsWon = "count", coins = "bigCash", power = "bigCash", bestRarity = "count", passes = "count",
}

-- Every Roblox custom event name this game may send (Roblox cap: 100).
-- FTUE*/Conquest* come from TutorialService; the rest from Analytics.
Schema.CustomEvents = {
	"FTUEEntered", "FTUEMilestone", "FTUEStepEntered", "FTUEStepCompletedSeconds", "FTUEFirstPayoffSeconds",
	"FTUEOutcome", "FTUEIntro", "FTUEIntroSeconds", "FTUEFirstActionSeconds", "FTUEControlToActionSeconds",
	"FTUEActionRejected", "FTUEEntryFailure", "FTUEFollowupWindow", "FTUEGuidanceEnded", "FTUEIndependentAction",
	"FTUEInteraction", "FTUEHintShown", "FTUEReadySeconds", "FTUEStepStalled", "FTUESurvival",
	"ConquestFirstWin", "KingFirstClear", "ConquestFailed",
	"SessionEnded", "OnboardingExit", "FeatureFirstUse", "RobuxPurchase", "ScriptError", "ClientPerf", "RollSummary",
	-- Version 5 (AnalyticsPlayer / AnalyticsFunnels).
	"PlayerSegment",  -- value = session minutes; fields device tier, payer state, platform
	"RobuxSpend",     -- value = actual Robux; fields kind, key, device tier
	"MenuDwell",      -- value = seconds; fields menu, platform, stage
	"FunnelDrop",     -- value = furthest step index; fields funnel, step id, platform
	"DeviceProfile",  -- value = memory MB at first report; fields platform, tier, screen class
}

-- Histogram buckets. A value lands in the first bucket whose edge >= value
-- (label "le<edge>"); larger values land in "gt<last edge>".
Schema.Buckets = {
	seconds = {5, 10, 20, 30, 45, 60, 90, 120, 180, 300, 450, 600, 900, 1200, 1800, 2700, 3600, 5400, 7200, 14400},
	ms      = {5, 10, 16, 20, 25, 33, 50, 100, 250, 1000},
	ping    = {25, 50, 75, 100, 150, 200, 300, 500, 1000},
	fps     = {10, 20, 30, 40, 50, 55, 60, 120},
	cash    = {0, 100, 500, 1000, 2500, 5000, 10000, 25000, 100000, 1000000, 10000000},
	count   = {0, 1, 2, 3, 5, 8, 13, 21, 34, 55, 100},
	memory  = {500, 1000, 1500, 2000, 3000, 4000},
	days    = {1, 2, 3, 4, 5, 6, 7, 14, 30, 60, 90},
	bigCash = {1e6, 1e7, 1e8, 1e9, 1e10, 1e11, 1e12, 1e13, 1e14, 1e15},
	robux   = {0, 5, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000},
	hour    = {0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 23},
	accountDays = {7, 30, 90, 180, 365, 730, 1460, 2920},
	percent = {10, 20, 30, 40, 50, 60, 70, 80, 90, 100},
	longSeconds = {1800, 3600, 5400, 7200, 10800, 14400, 21600, 28800, 43200, 72000, 108000, 172800, 360000},
}

function Schema.Bucket(kind: string, value: number): string
	local edges = Schema.Buckets[kind]
	assert(edges, "Unknown bucket kind " .. tostring(kind))
	for _, edge in edges do
		if value <= edge then return "le" .. edge end
	end
	return "gt" .. edges[#edges]
end

-- Platforms reported by AnalyticsClient. Anything else is stored as Unknown.
Schema.Platforms = {Desktop = true, Mobile = true, Tablet = true, Console = true, VR = true, Unknown = true}

-- Retention day indexes recorded per cohort (x[firstDay]["ret.dN"]).
Schema.RetentionDays = {1, 2, 3, 4, 5, 6, 7, 14, 21, 30, 60, 90}

-- Roblox limits verified 2026-10-09 (create.roblox.com/docs/production/analytics/event-types).
Schema.RobloxLimits = {
	customEvents = 100, funnels = 10, stepsPerFunnel = 100, currencies = 10,
	transactionTypes = 20, itemSkus = 100, customFields = 3, fieldCombinations = 8000,
	-- Experience-wide requests/minute = 120 + 20 * CCU. Each server spends at most
	-- Base + PerPlayer * players per minute so the whole game stays under it.
	budgetBase = 10, budgetPerPlayer = 15,
}

return Schema
