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
-- 7 (October 20 overhaul, S7): Rebirth v2 (rebirth2.*), Gems as a second currency
-- (Analytics:Gems, gems.*), Upgrades tree and Gem Upgrade buys, Rebirth chickens,
-- retired-pass Gems gifts, the economy migration, the Time Skip coin source.
-- 8 (October 20 overhaul, S16): Playtime Rewards (the playtime Coins source and
-- playtimeReward.claim.<1..12>).
-- 9 (October 21): the Tutorial funnel for the short core + tips guide
-- (ledger tut.*; Roblox funnel "Tutorial"; replaced by version 11).
-- 10 (later October 21): Tutorial step 14 VacuumSell (the vacuum tip now fills 20
-- eggs and sells them; played third among the tips, appended after Win).
-- 11 (later October 21): complete rework. Schema.TutorialFunnel (24 steps for the
-- seven-lesson tutorial, ledger tf.*) replaces the 9/10 Tutorial funnel and takes over
-- Roblox's Onboarding dashboard.
-- 12 (later October 21, Stevin: "get rid of any old [funnels] and replace them with
-- the new funnels"): the version 1-8 Schema.Onboarding steps (Grow, Expand, Select,
-- Deploy, GuideComplete: lessons the seven-lesson tutorial no longer has) stop
-- recording; Schema.TutorialFunnel is the only onboarding funnel and also sets the
-- session stage ("Tut:<step>" / "Post"). The feature funnels of removed systems
-- (Research, Fuse, the inspector's ChickenLevel, timed-build Plot) are gone, the
-- Research Roblox dashboard becomes Upgrades, and the overhaul systems get their own
-- funnels (Flock, Vacuum, Feed, GoldRolls, Mutations, Gems, PlaytimeRewards). Old
-- days keep their onb.* and fun.<removed>.* keys in the ledger; nothing reads them.
Schema.Version = 12

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

-- Roblox auto-completes every earlier onboarding step when a later one is logged, so
-- the Tutorial funnel (below) sends steps strictly in order. A missing hard step is
-- passed over once this many later steps happened (tf.robloxGapFill.NN counts each).
Schema.RobloxGapRelease = 3
function Schema.StepCode(index: number): string return string.format("%02d", index) end

-- Recurring funnels (Roblox LogFunnelStepEvent). Onboarding counts as one of
-- Roblox's 10 funnel dashboards, so at most 9 here.
Schema.Funnels = {
	Roll = {"Rolled", "AffordableOffer", "Recruited"},
	Shop = {"Prompted", "Purchased"},
	Camp = {"Deployed", "Won"},
	-- Version 5: five more Roblox dashboards (9 of 10 with onboarding). Sent by
	-- AnalyticsFunnels from the matching FeatureFunnels steps (RobloxSteps below).
	-- Version 12: Upgrades replaces Research (research merged into the instant tree on
	-- October 20, so its Started/Completed steps never fired again).
	Upgrades = {"Opened", "Inspected", "Bought"},
	-- Version 9: Fuse left the Roblox dashboards (Fuse was removed October 20).
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

-- Version 11 Tutorial funnel (later October 21, Stevin: "a complete rework of the
-- funnels to the tutorial, be VERY detailed"). One ordered funnel that follows a fresh
-- player through every action of the seven-lesson tutorial (eggs, selling, rolling,
-- the Egg Vacuum), then the first camp wins and the first Rebirth. It replaces the version 9/10 "Tutorial" recurring funnel and owns
-- Roblox's single Onboarding dashboard (LogOnboardingFunnelStepEvent) from now on;
-- since version 12 it is the only onboarding funnel (the version 1-8 onb.* steps are
-- retired). AnalyticsTutorial owns it.
--
-- Who is counted: players whose save is fresh when this version first sees them
-- (Analytics.FreshSave) and who keep a profile.tf record; everyone else is ignored.
--
-- Step kinds:
--   hard  a saved fact (save data or the server snapshot). Reached the moment it is
--         true, even if earlier steps are not (counted as tf.gap.NN then).
--   soft  a menu or tool action the client reports (TutorialSignal) while that lesson
--         is on screen. When a later step of the same lesson happens first, the soft
--         step is passed over (tf.skip.NN), never invented: the player may have
--         opened the menu before the lesson asked, or the signal was lost.
--
-- Ledger (Schema.LedgerStore, per game version and day):
--   tf.reach.NN            players reaching step NN (once per player, ever)
--   tf.reach.NN|<platform> the same split by platform (Phone, Tablet, PC, Console...)
--   tf.t.NN                histogram: total play seconds from first join to step NN
--   tf.d.NN                histogram: seconds since the previous reached step (dwell)
--   tf.s1.NN               reached during the player's first session
--   tf.gap.NN              reached while the step before it was still missing
--   tf.skip.NN             a soft step passed over because a later step happened
--   tf.exit.NN             a session ended unfinished with NN its furthest step
--   tf.exitLesson.<id>     the guide lesson on screen when that session ended
--   x[firstDay] tf.NN      cohort: players of that first day who ever reached NN
-- Roblox: LogOnboardingFunnelStepEvent(player, NN, "NN <label>", {version, platform}),
-- strictly in order (Roblox fills earlier steps itself): soft steps are passed over
-- once a later step happens; a missing hard step is released after
-- Schema.RobloxGapRelease later steps.
Schema.TutorialFunnel = {
	{id = "Joined", kind = "hard", label = "Joined the game",
		screen = "Loading screen; the player's yard is assigned.",
		trigger = "PlayerAdded on a server (Analytics:Join).",
		about = "Every tracked fresh player starts here. 100% by definition; every other rate is read against it."},
	{id = "Loaded", kind = "hard", label = "Save loaded",
		screen = "Still loading; the starter save (3 Ducks, 2,400 Coins) is ready.",
		trigger = "DataService loaded the profile and Analytics resolved the ledger profile (Analytics:Loaded).",
		about = "A drop from Joined is players leaving or failing before their save loads: DataStore errors, slow devices or instant quits. Compare with data.loadFail and load.serverSeconds."},
	{id = "IntroDone", kind = "hard", label = "Intro film done",
		screen = "The first-visit film plays (or not, with reduced motion), then the yard.",
		trigger = "Client TutorialSignal IntroFinished or IntroSkipped (also sent when no film plays).",
		about = "A drop here is quitting during the film. Read with intro.skipped vs intro.finished: many skips mean the film is too long."},
	{id = "Control", kind = "hard", label = "Player has control",
		screen = "Loading veil gone, character standing in the yard, the guide card about to show.",
		trigger = "Client TutorialSignal Ready (CommanderGuide, once the character exists and nothing blocks the screen).",
		about = "The real start of play. Join-to-here time (tf.t) is the loading cost; a big drop from IntroDone means the client failed to finish loading."},
	{id = "Egg1", kind = "hard", label = "1st egg clicked",
		screen = "TUTORIAL 1/7 'Click your eggs to collect them! (0/3)': one egg glows gold and a white hand taps it.",
		trigger = "tutorial.collectedEggCount >= 1 (EggService pays a clicked egg).",
		about = "Did the player understand the very first instruction? A drop from Control means they never clicked an egg: the glowing egg or hand is not obvious, or the egg is off screen. tf.d.05 is how long the first click took."},
	{id = "Egg2", kind = "hard", label = "2nd egg clicked",
		screen = "Same lesson, counter 1/3; the glow moves to the next nearest egg.",
		trigger = "tutorial.collectedEggCount >= 2.",
		about = "Repeating the action. Almost everyone who clicks one egg should click a second; a drop means the glow did not move clearly or no egg was ready (each chicken lays every 3 s)."},
	{id = "Egg3", kind = "hard", label = "3rd egg clicked (1/7)",
		screen = "Counter reaches 3/3; the green check pops and the card moves on.",
		trigger = "tutorial.collectedEggCount >= TutorialGuide.EggGoal (3).",
		about = "Lesson 1 of 7 done: collecting. Time from Control to here (tf.d.05 + .06 + .07) is how long collecting takes."},
	{id = "Sold", kind = "hard", label = "Sold eggs on the pad (2/7)",
		screen = "TUTORIAL 2/7 'Sell your eggs on the green pad!' with the ground beam to the pad; coins fly to the player.",
		trigger = "tutorial.soldEggs (first pad deposit).",
		about = "Lesson 2: the first payoff, Coins go up. A drop means the beam or pad is hard to find; dwell (tf.d.08) is the walk to the pad."},
	{id = "LeverPulled", kind = "hard", label = "Pulled the lever (3/7)",
		screen = "TUTORIAL 3/7 'Pull the lever for a chicken!' with the beam to the lever; its prompt reads 'Pull lever'.",
		trigger = "tutorial.rolled (RollService:Roll).",
		about = "Lesson 3: rolling, the game's main hook. A drop means the lever or its prompt is hard to find, or the roll animation confused them."},
	{id = "ChickenTaken", kind = "hard", label = "Took the chicken (4/7)",
		screen = "TUTORIAL 4/7 'Grab your chicken!': the rolled Duck stands on the podium; it costs 0 Coins.",
		trigger = "tutorial.bought (first recruit).",
		about = "Lesson 4. Should be close to 100% of LeverPulled; a drop means the reveal hid the podium prompt or they walked away mid-reveal."},
	{id = "UpgradesOpen", kind = "soft", label = "Opened Upgrades (vacuum)",
		screen = "TUTORIAL 5/7 'Open Upgrades for an Egg Vacuum!': screen darkened, gold ring and arrow on the Upgrades button.",
		trigger = "TutorialSignal TreeOpen after the chicken is taken while the Egg Vacuum is not owned.",
		about = "The first menu of the game. Does the dark screen plus ring get it opened? A drop from ChickenTaken to here is the clearest UI-comprehension failure in the tutorial."},
	{id = "ToolsOpen", kind = "soft", label = "Opened the Tools category",
		screen = "Inside Upgrades: 'Open the Tools category!' with the ring on the Tools hex.",
		trigger = "TutorialSignal ToolsOpen (the Upgrades map switched to Tools) while the Egg Vacuum is not owned.",
		about = "Second level of menu navigation. A drop between UpgradesOpen and here means the Open hexes are not recognised as buttons."},
	{id = "VacuumClaimed", kind = "hard", label = "Claimed the Egg Vacuum (5/7)",
		screen = "'Claim your Egg Vacuum!' on the ringed Egg Vacuum hex (0 Coins during the tutorial).",
		trigger = "The Egg Vacuum is owned (state.tools.eggVacuum) or was used (tutorial.vacuumUsed), after the chicken is taken.",
		about = "Lesson 5: the Upgrades menu and the first tool."},
	{id = "VacuumEquipped", kind = "soft", label = "Equipped the vacuum",
		screen = "TUTORIAL 6/7 'Equip your Egg Vacuum!' with the hotbar slot darkened and ringed.",
		trigger = "TutorialSignal VacuumEquip (the vacuum tool is in the character) before 20 eggs are vacuumed.",
		about = "Roblox's hotbar is unfamiliar to many new players. A drop here means they never pressed the slot (or the number key)."},
	{id = "Vacuum10", kind = "hard", label = "Vacuumed 10 eggs",
		screen = "'Walk near eggs to vacuum them up! (10/20)'.",
		trigger = "tutorial.vacuumEggCount >= 10.",
		about = "Halfway. The vacuum only works while held and near eggs; a drop between VacuumEquipped and here means they put it away or stood still."},
	{id = "Vacuum20", kind = "hard", label = "Vacuumed 20 eggs (6/7)",
		screen = "Counter reaches 20/20.",
		trigger = "tutorial.vacuumEggCount >= TutorialGuide.VacuumGoal (20).",
		about = "Lesson 6. tf.d.15 + tf.d.16 is how long filling takes (seconds when eggs are waiting; up to about 15 s with four chickens laying)."},
	{id = "VacuumSold", kind = "hard", label = "Sold the vacuum eggs (7/7)",
		screen = "TUTORIAL 7/7 'Sell your vacuumed eggs on the green pad!' with the beam to the pad.",
		trigger = "tutorial.vacuumSold (a pad sale carrying vacuum eggs once the 20 were in).",
		about = "Lesson 7, the last one: the vacuum loop closes. A drop means they kept collecting instead of selling; if the vacuum filled first the card says 'Vacuum full!'."},
	{id = "TutorialComplete", kind = "hard", label = "TUTORIAL COMPLETE shown",
		screen = "'TUTORIAL COMPLETE! Keep collecting eggs and rolling chickens!' with confetti for 4 s; the My Army button appears.",
		trigger = "tutorial.guideCompleted (TutorialService: all seven lessons done, or a camp win).",
		about = "The headline number: this share of Joined finished the tutorial. tf.t.18 minus tf.t.04 is how long the tutorial took after the player got control (target: about a minute)."},
	{id = "DailyDay1", kind = "soft", label = "Daily Rewards Day 1",
		screen = "Daily Rewards popup opens with Day 1 claimed (Coins).",
		trigger = "session.daily.lastDay > 0 after the tutorial (DailyService grants within 10 s of completion).",
		about = "The return hook. Soft because a server can lag; passed over (tf.skip.19) if a later step happens first. Compare with D1 retention per cohort."},
	{id = "CluckCampWon", kind = "hard", label = "Captured Cluck Camp",
		screen = "Nothing on screen guides the player any more; they find Cluck Camp on their own (camp signs show Should win / Close fight / Very tough).",
		trigger = "First camp win (firstWins, campsWon or tutorial.wonCamp).",
		about = "First fight, found without any instructions (Stevin removed all post-tutorial guidance). A drop from TutorialComplete is players who never fought or lost; read with the Camp funnel (Deployed, Won). If this is low, fighting needs its own discovery hook."},
	{id = "FortRoostWon", kind = "hard", label = "Won Fort Roost",
		screen = "No guidance; the camp sign shows the fight estimate.",
		trigger = "firstWins[2].",
		about = "The October 20 funnel review found next-day return is about 20% for players who win Fort Roost on day 1 and 2% for those who don't. The most important post-tutorial step; read by cohort."},
	{id = "IronbeakWon", kind = "hard", label = "Won Ironbeak HQ",
		screen = "No guidance.", trigger = "firstWins[3].",
		about = "Mid-route progress, usually in a later session (tf.s1 is low here)."},
	{id = "KingCleared", kind = "hard", label = "Beat the Chicken King",
		screen = "No guidance.", trigger = "session.kingCleared.",
		about = "End of the main route."},
	{id = "Rebirth1", kind = "hard", label = "First Rebirth",
		screen = "Rebirth screen.", trigger = "session.rebirths >= 1.",
		about = "Long-term retention marker: the player understood the reset loop."},
}
Schema.TutorialFunnelIndex = {} :: {[string]: number}
for index, step in Schema.TutorialFunnel do
	assert(#step.label <= 36, "Tutorial funnel label too long: " .. step.id)
	Schema.TutorialFunnelIndex[step.id] = index
end
function Schema.TutorialFunnelName(index: number): string
	return Schema.StepCode(index) .. " " .. Schema.TutorialFunnel[index].label
end

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
	rebirth   = {transaction = "Gameplay",    sku = "TimeSkip"},    -- version 7: Rebirth Time Skip Coins
	playtime  = {transaction = "TimedReward", sku = "PlaytimeReward"}, -- version 8: Playtime Rewards Coins tiles
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
	-- Version 7: an Upgrades tree node (sku gets ":<nodeId>").
	BuyUpgrade     = {transaction = "Shop",     sku = "Upgrade"},
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
	-- Version 7 (October 20 overhaul).
	BuyUpgrade = "Upgrades", BuyGemUpgrade = "GemUpgrades", SetAutoRebirth = "AutoRebirth",
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
	-- Version 7 (October 20 overhaul, docs/team/OVERHAUL_CONTRACT_20261020.md §11).
	["rebirth2.rank"] = true,     -- rebirth2.rank.<N>: first time a player reaches v2 rank N (LaunchFirst)
	["rebirth2.skip"] = true,     -- a Rebirth paid with a Skip credit
	["rebirth2.auto"] = true,     -- a Rebirth done by Auto Rebirth
	["gems.earned"] = true,       -- n = Gems paid by a Rebirth
	["gems.spent"] = true,        -- gems.spent.<upgradeId>, n = Gems spent
	["gemUpgrade.buy"] = true,    -- gemUpgrade.buy.<upgradeId>
	["upgrade.buy"] = true,       -- upgrade.buy.<nodeId>: an Upgrades tree node
	["rebirthChicken.granted"] = true,
	["rebirthChicken.offered"] = true, -- a podium offer replaced by a Rebirth chicken (S12)
	["rebirthChicken.bought"] = true,  -- that offer recruited (S12)
	["passGems"] = true,          -- passGems.<passKey>: a retired pass's one-time Gems gift
	["migration"] = true,         -- migration.economy2: a save converted to the tree and Gems
	-- Version 7, S12 (Auto Roll and Gold rolls; GameServer emits them).
	["goldRoll.pull"] = true,     -- goldRoll.pull.<Gold|Diamond|Prism>: one per special lever pull
	["autoRoll.recruit"] = true,  -- Auto Roll bought an offer at the recruit value
	["autoRoll.recruitHeld"] = true, -- recruited from the hit alert, from anywhere
	["autoRoll.skip"] = true,     -- Skip on the hit alert
	-- Version 8, S16 (Playtime Rewards; GameServer emits it).
	["playtimeReward.claim"] = true, -- playtimeReward.claim.<1..12>: a Playtime Rewards tile claimed
}
-- Histogram name (prefix) -> bucket kind.
Schema.LaunchHistograms = {
	["rebirth.playSeconds"] = "longSeconds", -- rebirth.playSeconds.<N>: total play when rank N was reached
	["rebirth.cashAtRebirth"] = "bigCash",
	["daily.streak"] = "count",
	["rebirth2.playSeconds"] = "longSeconds", -- version 7: total play when v2 rank N was reached
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
		{id = "Available", trigger = "state:effects.autoRoll (the Auto Roll Gem Upgrade)"},
		{id = "Enabled", trigger = "action:SetAutoRoll (on)"},
		{id = "Stopped", trigger = "server:autoroll.stop"},
	}},
	{id = "Upgrades", steps = {
		{id = "MenuOpened", trigger = "client:menu.open=Upgrades"},
		{id = "Inspected", trigger = "client:inspect=Upgrades/*"},
		{id = "FirstBuy", trigger = "action:BuyUpgrade (an Upgrades tree node; old clients' CashUpgrade|BoardUpgrade|Luck|Income|Expand too)"},
		{id = "Buys10", trigger = "10 Upgrades bought ever"},
		{id = "Buys50", trigger = "50 Upgrades bought ever"},
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
	-- Version 12: the October 20 overhaul systems (they replace Research, Fuse,
	-- ChickenLevel and Plot above).
	{id = "Flock", steps = {
		{id = "Tier1", trigger = "state:effects.flockSize >= Flock Size I (4 chickens laying)"},
		{id = "Tier4", trigger = "state:effects.flockSize >= Flock Size IV"},
		{id = "Tier6", trigger = "state:effects.flockSize >= Flock Size VI"},
		{id = "Max", trigger = "state:effects.flockSize at the top Flock Size tier"},
	}},
	{id = "Vacuum", steps = {
		{id = "Owned", trigger = "state:tools.eggVacuum (claimed in the tutorial's lesson 5)"},
		{id = "CapacityUp", trigger = "state:effects.vacuumCapacity >= 1"},
		{id = "RangeUp", trigger = "state:effects.vacuumRange >= 1"},
	}},
	{id = "Feed", steps = {
		{id = "Owned", trigger = "state:tools.chickenFeed (bought in Upgrades > Tools)"},
		{id = "Fed", trigger = "action:FeedChicken (a chicken level bought with Feed)"},
		{id = "Fed10", trigger = "10 chicken levels ever"},
		{id = "MaxLevelUp", trigger = "state:effects.feedMaxLevel >= 1 (Feed Max Level I)"},
	}},
	{id = "GoldRolls", steps = {
		{id = "GoldMachine", trigger = "state:effects.goldMachine >= 1"},
		{id = "GoldRoll", trigger = "server:goldRoll.pull.Gold"},
		{id = "DiamondMachine", trigger = "state:effects.goldMachine >= 2"},
		{id = "DiamondRoll", trigger = "server:goldRoll.pull.Diamond"},
		{id = "PrismMachine", trigger = "state:effects.goldMachine >= 3"},
		{id = "PrismRoll", trigger = "server:goldRoll.pull.Prism"},
	}},
	{id = "Mutations", steps = {
		{id = "Unlocked", trigger = "state:effects.mutations >= 1 (Mutations bought in the tree)"},
		{id = "Offered", trigger = "server:mutation.offer.<id>"},
		{id = "Bought", trigger = "server:mutation.buy.<id>"},
	}},
	{id = "Gems", steps = {
		{id = "Earned", trigger = "server:gems.earned (a Rebirth paid Gems)"},
		{id = "Bought", trigger = "server:gemUpgrade.buy.<id>"},
		{id = "Bought5", trigger = "5 Gem Upgrade levels ever"},
	}},
	{id = "PlaytimeRewards", steps = {
		{id = "Claimed", trigger = "server:playtimeReward.claim.<n>"},
		{id = "Tile6", trigger = "server:playtimeReward.claim.<6+>"},
		{id = "Tile12", trigger = "server:playtimeReward.claim.12"},
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
	Upgrades = {MenuOpened = 1, Inspected = 2, FirstBuy = 3},
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
	"SessionEnded", "FeatureFirstUse", "RobuxPurchase", "ScriptError", "ClientPerf", "RollSummary",
	-- Version 5 (AnalyticsPlayer / AnalyticsFunnels).
	"PlayerSegment",  -- value = session minutes; fields device tier, payer state, platform
	"RobuxSpend",     -- value = actual Robux; fields kind, key, device tier
	"MenuDwell",      -- value = seconds; fields menu, platform, stage
	"FunnelDrop",     -- value = furthest step index; fields funnel, step id, platform
	"DeviceProfile",  -- value = memory MB at first report; fields platform, tier, screen class
	-- Version 12 (replaces OnboardingExit, the retired onboarding funnel's exit).
	"TutorialExit",   -- value = seconds since the last Tutorial funnel step; fields "NN <id>", lesson, S1/S2/S3+
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
