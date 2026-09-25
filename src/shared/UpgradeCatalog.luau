--!strict
-- Board-only tracks. Existing army, income and luck prices remain in Config.
-- No rank/camp gates. Benchmark income bands below set prices only.
local Config = require(script.Parent.Config)
local UpgradeCatalog = {
	Order = {"EggSpeed", "PlotSize", "EggValue", "ArmySize", "Luck", "RollSlots"},
	BoardDistance = 24,
	EggSpeedRates = {1, 1.15, 1.30, 1.45, 1.60},
	EggSpeedPrices = table.clone(Config.IncomePrices),
	PlotScales = {1, 1.05, 1.10, 1.15, 1.20},
	PlotPrices = table.clone(Config.IncomePrices),
	ExtraChickensPerPlotLevel = 5,
	RollSlotPrices = {
		1200, 4800,
		math.floor(Config.Economy.ReferenceIncome[2] * 120),
		math.floor(Config.Economy.ReferenceIncome[3] * 120),
		math.floor(Config.Economy.ReferenceIncome[4] * 120),
	},
}
return UpgradeCatalog
