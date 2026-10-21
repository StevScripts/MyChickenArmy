--!strict
-- One-time changes to what saved Upgrades tree tiers mean (October 20; the overhaul is
-- live since 22:07). Saves carry `upgradeTreeVersion` (PlayerSession:ToData writes
-- Version); PlayerSession:LoadData runs every step above a save's version once, right
-- after the tree is read. New profiles and revision <= 11 conversions are already in
-- today's meaning. Whoever changes what a saved tier means adds a step and bumps
-- Version in the same commit; never edit or reorder a released step. This is a version
-- key, not a DataRevision bump: servers on an older build reject newer revisions.
-- See docs/team/OVERHAUL_CONTRACT_20261020.md §2.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local UpgradeCatalog = require(Shared.UpgradeCatalog)
local Migrations = {}

-- S9c sets Version = 1 in the commit that changes Config.GoldRolls.Every
-- (RebirthV2Checks fails if the table changes while this is still 0).
Migrations.Version = 0

-- Config.GoldRolls.Every on live servers before S9c: Gold Rate tier 0 / I / II = a
-- Gold roll every 10 / 8 / 6 pulls. Frozen.
Migrations.LiveGoldEvery = table.freeze({10, 8, 6})

-- The Gold Rate tier that keeps a live tier's count: the lowest tier whose roll comes
-- at least as often, given today's every-N table and each tier's goldRate value.
function Migrations.GoldRateTier(oldTier: number, every: {number}, tierValues: {number}): number
	if oldTier <= 0 then return 0 end
	local live = Migrations.LiveGoldEvery
	local count = live[math.min(oldTier, #live - 1) + 1]
	for tier, value in tierValues do
		local now = every[value + 1]
		if type(now) == "number" and now <= count then return tier end
	end
	return #tierValues
end

local function goldRateByCount(tree: {[string]: number})
	local tier = UpgradeCatalog.Tier(tree, "GoldRate")
	local rolls = Config.GoldRolls
	if tier <= 0 or type(rolls) ~= "table" or type(rolls.Every) ~= "table" then return end
	local values = {}
	for index, entry in UpgradeCatalog.Families.GoldRate.tiers do values[index] = entry.value end
	tree.GoldRate = Migrations.GoldRateTier(tier, rolls.Every, values)
end

Migrations.Steps = table.freeze({
	-- 1 (S9c, Oct 20): Gold Rate's table grows to every 10/8/7/6/5, so live tier II
	-- (every 6) becomes tier III; tier I (every 8) stays.
	goldRateByCount,
} :: {(tree: {[string]: number}) -> ()})

-- Runs the steps a tree saved at version `saved` is missing (none when it is current
-- or newer). Pass the tree after UpgradeCatalog.ReadTree.
function Migrations.Run(tree: {[string]: number}, saved: number)
	for version = saved + 1, Migrations.Version do
		local step = Migrations.Steps[version]
		if step then step(tree) end
	end
end

return Migrations
