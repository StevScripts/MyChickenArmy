--!strict
-- October 20 overhaul Gem Upgrades (docs/team/OVERHAUL_CONTRACT_20261020.md §6).
-- Bought with Gems only and never reset by a Rebirth. Rows open at a Rebirth rank;
-- these are not Coins upgrades, so the no-rank-gate rule for Coins upgrades does not
-- apply. GemUpgradeService owns purchases; UpgradeCatalog.Effects adds the effects.
local Catalog = {}

export type Upgrade = {
	id: string, name: string, row: number, column: number, unlockRank: number,
	maxLevel: number, startLevel: number, prices: {number},
	effect: string?, effects: {string}?, perLevel: number?, values: {number}?,
	text: string, texts: {string}?, icon: string,
}

-- Draft Gem prices; the P0 cost fit (tests/ProgressionSimulation) owns the numbers.
-- October 20 (Stevin, S7b): the cards follow Drop a Fruit's shop order in rows of two,
-- with +1 Flock Slot and +1 Army Slot at Rebirth 1 (its "+1 Fruit Slot").
-- Vacuum Capacity adds seconds of the Flock's laying (October 20, Stevin), like the
-- Tools tiers; S11 converts seconds to eggs.
Catalog.VacuumCapacityPerLevel = 15

local upgrades: {Upgrade} = {
	{id = "RollSpeed", name = "Roll Speed", row = 1, column = 1, unlockRank = 0, maxLevel = 5, startLevel = 0,
		prices = {5, 10, 20, 35, 60}, effect = "rollingSpeed", perLevel = 0.10,
		text = "+10% faster rolls", icon = "gemRollSpeed"},
	{id = "ExtraLuck", name = "Extra Luck", row = 1, column = 2, unlockRank = 0, maxLevel = 5, startLevel = 0,
		prices = {5, 10, 20, 35, 60}, effect = "rollingLuck", perLevel = 0.10,
		text = "+10% roll luck", icon = "gemExtraLuck"},
	{id = "VacuumCapacity", name = "Vacuum Capacity", row = 2, column = 1, unlockRank = 0, maxLevel = 3, startLevel = 0,
		prices = {10, 25, 50}, effect = "vacuumCapacity", perLevel = Catalog.VacuumCapacityPerLevel,
		text = "+" .. Catalog.VacuumCapacityPerLevel .. " s of eggs in your vacuum", icon = "gemVacuumCapacity"},
	{id = "AutoRoll", name = "Auto Roll", row = 2, column = 2, unlockRank = 0, maxLevel = 1, startLevel = 0,
		prices = {15}, effect = "autoRoll", perLevel = 1,
		text = "Unlocks Auto Roll: your podiums keep rolling for you", icon = "gemAutoRoll"},
	-- On top of the tree's Flock Size and Army Size; the yard still follows the tree.
	{id = "FlockSlot", name = "+1 Flock Slot", row = 3, column = 1, unlockRank = 1, maxLevel = 2, startLevel = 0,
		prices = {20, 60}, effect = "flockSize", perLevel = 1,
		text = "+1 chicken laying eggs in your Flock", icon = "gemFlockSlot"},
	{id = "ArmySlot", name = "+1 Army Slot", row = 3, column = 2, unlockRank = 1, maxLevel = 2, startLevel = 0,
		prices = {25, 75}, effect = "armySlots", perLevel = 1,
		text = "+1 chicken in your Army", icon = "gemArmySlot"},
	{id = "CoinBoost", name = "Coin Boost", row = 4, column = 1, unlockRank = 2, maxLevel = 10, startLevel = 0,
		prices = {10, 15, 25, 40, 60, 90, 135, 200, 300, 450}, effect = "coinBoost", perLevel = 0.10,
		text = "+10% Coins from eggs", icon = "gemCoinBoost"},
	{id = "AutoRebirth", name = "Auto Rebirth", row = 4, column = 2, unlockRank = 2, maxLevel = 1, startLevel = 0,
		prices = {25}, effect = "autoRebirth", perLevel = 1,
		text = "Unlocks Auto Rebirth: rebirths for you when you have enough Coins", icon = "gemAutoRebirth"},
	-- Time Skip starts at level 1 (5 minutes) for everyone.
	{id = "TimeSkip", name = "Time Skip", row = 5, column = 1, unlockRank = 3, maxLevel = 6, startLevel = 1,
		prices = {20, 40, 70, 110, 160}, effect = "timeSkipMinutes", perLevel = 5,
		text = "+5 min of Coins when you rebirth", icon = "gemTimeSkip"},
	{id = "MoreGems", name = "More Gems", row = 5, column = 2, unlockRank = 3, maxLevel = 5, startLevel = 0,
		prices = {25, 50, 90, 140, 200}, effect = "gemBonus", perLevel = 0.10,
		text = "+10% Gems from every rebirth", icon = "gemMoreGems"},
	{id = "KeepUpgrades", name = "Keep Upgrades", row = 6, column = 1, unlockRank = 5, maxLevel = 3, startLevel = 0,
		prices = {40, 90, 160}, effect = "keepTiers", perLevel = 1,
		text = "Keep 1 more tier of Egg Speed, Egg Value and Luck", icon = "gemKeepUpgrades"},
	{id = "Rally", name = "Rally", row = 6, column = 2, unlockRank = 5, maxLevel = 2, startLevel = 0,
		prices = {30, 80}, effect = "rallySeconds", values = {8, 12},
		text = "Rally: +20% army damage for 8 s", texts = {"Unlocks Rally: +20% army damage for 8 s", "Rally lasts 12 s"},
		icon = "gemRally"},
	{id = "MutationLuck", name = "Mutation Luck", row = 7, column = 1, unlockRank = 8, maxLevel = 5, startLevel = 0,
		prices = {40, 80, 130, 190, 260}, effect = "mutationLuck", perLevel = 0.10,
		text = "+10% mutation chance", icon = "gemMutationLuck"},
	{id = "OfflineCoins", name = "Offline Coins", row = 7, column = 2, unlockRank = 8, maxLevel = 4, startLevel = 0,
		prices = {30, 60, 100, 150}, effect = "offlineEfficiency", perLevel = 0.05,
		text = "Earn 5% more while away", icon = "gemOfflineCoins"},
	{id = "ArmyPower", name = "Army Power", row = 8, column = 1, unlockRank = 12, maxLevel = 5, startLevel = 0,
		prices = {50, 100, 175, 275, 400}, effects = {"damage", "health"}, perLevel = 0.05,
		text = "+5% army damage and health", icon = "gemArmyPower"},
	{id = "RebirthChickenOdds", name = "Rebirth Chicken Odds", row = 8, column = 2, unlockRank = 12, maxLevel = 5, startLevel = 0,
		prices = {30, 60, 100, 150, 220}, effect = "rebirthChickenChance", perLevel = 0.002,
		text = "Rebirth chickens show up 20% more", icon = "gemRebirthChickenOdds"},
}

Catalog.Order = {} :: {string}
Catalog.Upgrades = {} :: {[string]: Upgrade}
for _, upgrade in upgrades do
	assert(#upgrade.prices == upgrade.maxLevel - upgrade.startLevel, "One Gem price per purchasable level: " .. upgrade.id)
	table.insert(Catalog.Order, upgrade.id)
	Catalog.Upgrades[upgrade.id] = upgrade
end

-- Saved level (missing or junk reads as the start level), clamped to the track.
function Catalog.Level(levels: any, id: string): number
	local upgrade = Catalog.Upgrades[id]
	if not upgrade then return 0 end
	local saved = if type(levels) == "table" then levels[id] else nil
	if type(saved) ~= "number" or saved ~= saved then return upgrade.startLevel end
	return math.clamp(math.floor(saved), upgrade.startLevel, upgrade.maxLevel)
end

-- Gem price of the next level, or nil at the maximum.
function Catalog.Price(id: string, level: number): number?
	local upgrade = Catalog.Upgrades[id]
	if not upgrade or level >= upgrade.maxLevel then return nil end
	return upgrade.prices[level - upgrade.startLevel + 1]
end

-- The card line for the level a purchase would reach (the current one at max).
function Catalog.Text(id: string, level: number): string
	local upgrade = Catalog.Upgrades[id]
	if not upgrade then return "" end
	local nextLevel = math.min(level + 1, upgrade.maxLevel)
	return if upgrade.texts and upgrade.texts[nextLevel] then upgrade.texts[nextLevel] else upgrade.text
end

-- Adds every Gem Upgrade's effect at its saved level into `effects` (UpgradeCatalog.Effects).
function Catalog.Apply(effects: {[string]: number}, levels: any)
	for _, id in Catalog.Order do
		local upgrade = Catalog.Upgrades[id]
		local level = Catalog.Level(levels, id)
		if level <= 0 then continue end
		if upgrade.values then
			effects[upgrade.effect :: string] = math.max(effects[upgrade.effect :: string] or 0, upgrade.values[level])
		else
			local amount = level * (upgrade.perLevel or 0)
			for _, key in upgrade.effects or {upgrade.effect :: string} do
				effects[key] = (effects[key] or 0) + amount
			end
		end
	end
end

-- Lenient save reader: known ids only, levels clamped; never fails a load.
function Catalog.Read(value: any): {[string]: number}
	local result = {}
	if type(value) ~= "table" then return result end
	for id, level in value do
		local upgrade = if type(id) == "string" then Catalog.Upgrades[id] else nil
		if upgrade and type(level) == "number" and level == level then
			local clamped = math.clamp(math.floor(level), 0, upgrade.maxLevel)
			if clamped > upgrade.startLevel then result[id] = clamped end
		end
	end
	return result
end

for _, upgrade in Catalog.Upgrades do
	table.freeze(upgrade.prices)
	if upgrade.values then table.freeze(upgrade.values) end
	if upgrade.texts then table.freeze(upgrade.texts) end
	if upgrade.effects then table.freeze(upgrade.effects) end
	table.freeze(upgrade)
end
table.freeze(Catalog.Order)
table.freeze(Catalog.Upgrades)
return table.freeze(Catalog)
