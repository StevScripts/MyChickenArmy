--!strict
-- Single source of truth for every analytics name, step, bucket and limit.
-- Agents: read docs/analytics/AGENT_GUIDE.md before changing or reading data.
-- Rules: never reorder or rename an onboarding step, funnel step, counter or
-- bucket label in place. Append new ones and bump Schema.Version so old and new
-- data stay comparable. Studio never sends Roblox analytics (Roblox ignores it).
local Schema = {}

-- 2 (October 14 launch): onboarding step 20 Rebirth1, daily source, Rebirth
-- sink/feature, launch counters and the bigCash/longSeconds buckets.
Schema.Version = 2

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
}
Schema.RollFunnelSessionCap = 30 -- Roblox roll-funnel sessions per player session (rate budget)

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
Schema.Rarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic"}

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
}
-- Histogram name (prefix) -> bucket kind.
Schema.LaunchHistograms = {
	["rebirth.playSeconds"] = "longSeconds", -- rebirth.playSeconds.<N>: total play when rank N was reached
	["rebirth.cashAtRebirth"] = "bigCash",
	["daily.streak"] = "count",
}
-- Analytics profile field: highest re-enlist rank seen (profile.rebirths).

-- Every Roblox custom event name this game may send (Roblox cap: 100).
-- FTUE*/Conquest* come from TutorialService; the rest from Analytics.
Schema.CustomEvents = {
	"FTUEEntered", "FTUEMilestone", "FTUEStepEntered", "FTUEStepCompletedSeconds", "FTUEFirstPayoffSeconds",
	"FTUEOutcome", "FTUEIntro", "FTUEIntroSeconds", "FTUEFirstActionSeconds", "FTUEControlToActionSeconds",
	"FTUEActionRejected", "FTUEEntryFailure", "FTUEFollowupWindow", "FTUEGuidanceEnded", "FTUEIndependentAction",
	"FTUEInteraction", "FTUEHintShown", "FTUEReadySeconds", "FTUEStepStalled", "FTUESurvival",
	"ConquestFirstWin", "KingFirstClear", "ConquestFailed",
	"SessionEnded", "OnboardingExit", "FeatureFirstUse", "RobuxPurchase", "ScriptError", "ClientPerf", "RollSummary",
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
