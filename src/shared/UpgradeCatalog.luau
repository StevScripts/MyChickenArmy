--!strict
-- Board-only tracks. Existing army, income and luck prices remain in Config.
-- No rank/camp gates. Benchmark income bands below set prices only.
local Config = require(script.Parent.Config)
local UpgradeCatalog = {
	Order = {"EggSpeed", "PlotSize", "EggValue", "ArmySize", "Luck", "RollSlots"},
	BoardDistance = 24,
	EggSpeedRates = {1, 1.15, 1.30, 1.45, 1.60},
	EggSpeedPrices = table.clone(Config.IncomePrices),
	-- Prepend smaller yards; revision-10 levels shift +3 with identical old sizes.
	PlotScales = {0.80, 0.87, 0.94, 1, 1.05, 1.10, 1.15, 1.20},
	-- Physical expansion is independent of the longer stat tracks.
	PlotPrices = {480, 1200, 2400, 2880, 63000, 725760, 3628800},
	-- The two final expansions open enough space for 75, then 100 chickens.
	PlotCapacities = {25, 30, 35, 40, 45, 50, 75, 100},
	-- September 29: ~8.5 active hours in the reference F2P pacing model.
	-- Fixed prices; no time/rank gate. See docs/team/EIGHT_ROLL_PODIUMS.md.
	RollSlotPrices = {
		1200, 4800, 120000, 6000000, 150000000, 300000000, 500000000,
	},
}
for level = #UpgradeCatalog.EggSpeedRates, #UpgradeCatalog.EggSpeedPrices do
	UpgradeCatalog.EggSpeedRates[level + 1] = 1 + 0.15 * level
end
function UpgradeCatalog.PlotCapacity(level: number): number
	local index = math.clamp(math.floor(level) + 1, 1, #UpgradeCatalog.PlotCapacities)
	return math.min(Config.LegacyCollectionLimit, UpgradeCatalog.PlotCapacities[index])
end
return UpgradeCatalog
