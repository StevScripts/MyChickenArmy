--!strict
-- October 20 overhaul: one-time conversion of revision ≤ 11 saves to the Upgrades
-- tree and Gems (docs/team/OVERHAUL_CONTRACT_20261020.md §9, confirmed by Stevin).
-- Pure: PlayerSession:LoadData validates the old values first, calls Convert, and
-- applies the result only after the whole profile validates. Nothing here can fail
-- a load. The old formulas below are frozen copies of the pre-October 20 tracks.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local UpgradeCatalog = require(Shared.UpgradeCatalog)
local Migration = {}

-- Old domains, for validating revision ≤ 11 saves (they are not the new tree).
Migration.Legacy = table.freeze({
	EggSpeedLevels = 25, IncomeLevels = 25, LuckLevels = 20, PlotLevels = 7, RollSlots = 8,
	SlotLevels = table.freeze({3, 4, 5, 6, 7, 8, 9, 10}),
})

-- Highest completed research value per old effect, counting running jobs as finished.
local function researchValue(completed: {[string]: boolean}, ids: {string}, values: {number}): number
	local best = 0
	for index, id in ids do
		if completed[id] then best = math.max(best, values[index]) end
	end
	return best
end

-- Highest completed tier of a one-for-one research chain (0 if none).
local function chainTier(completed: {[string]: boolean}, ids: {string}): number
	local tier = 0
	for index, id in ids do if completed[id] then tier = index end end
	return tier
end

-- The tier whose value is nearest `old` (the family's base counts as tier 0).
-- Ties round up, and nothing goes past the top tier.
local function nearest(familyId: string, old: number): number
	local family = UpgradeCatalog.Families[familyId]
	local best, distance = 0, math.abs(old - family.base)
	for tier, entry in family.tiers do
		local gap = math.abs(old - entry.value)
		if gap <= distance + 1e-9 then best, distance = tier, gap end
	end
	return best
end

-- Gems a rank pays before More Gems (RebirthService.Gems with no bonus).
local function rankGems(rank: number): number
	local rules = Config.Rebirth
	return rules.GemsBase + rules.GemsPerRank * rank
end

export type Old = {
	eggSpeedLevel: number, incomeLevel: number, luck: number, capacity: number,
	rollSlotsUnlocked: number, petCount: number, rebirths: number,
	research: any, tutorial: {[string]: any}, cashLevels: boolean,
}

-- Returns the new tree, Gem Upgrade levels, Gems, legacy Mission tier, vacuum flag
-- and a short summary for analytics.
function Migration.Convert(old: Old)
	local research = if type(old.research) == "table" then old.research else {}
	local completed: {[string]: boolean} = {}
	for id, owned in research.completed or {} do if owned == true then completed[id] = true end end
	-- A research job still running when the update lands counts as finished.
	for _, job in research.jobs or {} do
		if type(job) == "table" and type(job.nodeId) == "string" then completed[job.nodeId] = true end
	end
	local tree: {[string]: number} = {}
	local function set(familyId: string, tier: number)
		if tier > 0 then tree[familyId] = math.min(tier, #UpgradeCatalog.Families[familyId].tiers) end
	end
	-- Totals the old cash track and research gave; the new tier is the nearest one.
	local production = researchValue(completed, {"E1", "E2", "E3"}, {0.05, 0.10, 0.20})
	set("EggSpeed", nearest("EggSpeed", (1 + 0.15 * old.eggSpeedLevel) * (1 + production)))
	local eggValue = researchValue(completed, {"E4", "E5", "E6"}, {0.05, 0.10, 0.15})
	local oldUnit = math.floor(Config.EggBaseValue * (1 + 0.25 * old.incomeLevel) + 0.5) / Config.EggBaseValue
	set("EggValue", nearest("EggValue", oldUnit * (1 + eggValue)))
	local rollingLuck = researchValue(completed, {"L1", "L2", "L3", "L4", "L5", "L6"}, {0.1, 0.2, 0.35, 0.5, 0.75, 1})
	set("Luck", nearest("Luck", (1 + 0.10 * old.luck) * (1 + rollingLuck)))
	-- Every owned chicken laid before; Flock Size keeps as many laying as it can.
	set("Flock", nearest("Flock", old.petCount))
	set("ArmySize", nearest("ArmySize", old.capacity))
	set("RollSlot", math.clamp(old.rollSlotsUnlocked - 1, 0, #UpgradeCatalog.Families.RollSlot.tiers))
	set("RollSpeed", nearest("RollSpeed", researchValue(completed, {"R1", "R2", "R3", "R4", "R5", "R6"},
		{0.1, 0.2, 0.3, 0.4, 0.5, 0.6})))
	-- One-for-one research chains.
	set("Damage", chainTier(completed, {"A1", "A2", "A3"}))
	set("Health", chainTier(completed, {"A4", "A5", "A6"}))
	set("MarchSpeed", chainTier(completed, {"A7", "A8", "A9"}))
	set("Armor", chainTier(completed, {"A10", "A11"}))
	set("Recovery", chainTier(completed, {"A12", "A13"}))
	set("BossDamage", chainTier(completed, {"A16"}))
	set("Bounty", chainTier(completed, {"E10", "E11", "E12"}))
	set("CaptureSpeed", chainTier(completed, {"S6", "S7", "S8"}))
	set("WalkSpeed", chainTier(completed, {"S9", "S10", "S11"}))
	set("ClickRange", chainTier(completed, {"E7", "E8", "E9"}))
	set("OfflineTime", chainTier(completed, {"E13", "E14", "E15"}))
	-- Anyone who bought a chicken level keeps leveling this run with Chicken Feed.
	if old.cashLevels then set("ChickenFeed", 1) end
	-- Earned unlocks that became Gem Upgrades stay, free.
	local gemUpgrades: {[string]: number} = {}
	if completed.AutoRoll then gemUpgrades.AutoRoll = 1 end
	if completed.A15 then gemUpgrades.Rally = 2 elseif completed.A14 then gemUpgrades.Rally = 1 end
	-- Mission tiers opened by research (or any earlier Rebirth) stay open.
	local missionTier = chainTier(completed, {"S15", "S16", "S17"})
	if old.rebirths >= 1 then missionTier = math.max(missionTier, 1) end
	-- Unused paid research-skip time: 1 Gem per 5 minutes, rounded up.
	local skipSeconds = if type(research.skipCredit) == "number" and research.skipCredit == research.skipCredit
		then math.max(0, research.skipCredit) else 0
	local skipGems = math.ceil(skipSeconds / 300)
	-- Rebirth veterans: double the Gems their ranks would pay now.
	local rankGemsTotal = 0
	for rank = 1, math.min(old.rebirths, Config.Rebirth.MaxRank) do
		rankGemsTotal += rankGems(rank) * Config.Rebirth.LegacyGemFactor
	end
	local tutorial = old.tutorial or {}
	local eggVacuum = tutorial.guideCompleted == true or tutorial.guideSkipped == true
		or tutorial.wonCamp == true or tutorial.starterArmy ~= true
	local tiers = 0
	for _ in tree do tiers += 1 end
	return {tree = tree, gemUpgrades = gemUpgrades, gems = skipGems + rankGemsTotal, missionTierLegacy = missionTier,
		eggVacuum = eggVacuum, rebirthChickenRanks = math.min(old.rebirths, Config.Rebirth.MaxRank),
		summary = {families = tiers, skipGems = skipGems, rankGems = rankGemsTotal}}
end

return Migration
