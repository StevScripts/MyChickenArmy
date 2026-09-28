--!strict
local Currency = require(script.Parent.CurrencyLimits)
local Config = {
	-- Preserve existing purchases; these are opening tiers, not a level cap.
	Rates = table.freeze({4, 16, 64, 256, 1024}),
	Prices = table.freeze({480, 2400, 9600, 28800}),
	BoardDistance = 24,
	MaxBatches = 64,
	MaxValue = 1e12,
	ContinuationBasePrice = 86400,
	PriceGrowth = 1.10,
}

function Config.ValidLevel(level: any): boolean
	-- Serialization/integer precision boundary, not a designed progression cap.
	return type(level) == "number" and level == level and level >= 0
		and level <= 2^53 - 1 and level % 1 == 0
end

function Config.Rate(level: number): number
	local opening = Config.Rates[level + 1]
	if opening then return opening end
	-- Increasing absolute gains without exponential overflow at high saved levels.
	-- After 1,024: 4,096 / 9,216 / 16,384 / 25,600 / ... eggs/sec.
	return Config.Rates[#Config.Rates] * (level - #Config.Rates + 2)^2
end

function Config.Price(level: number): number?
	local opening = Config.Prices[level + 1]
	if opening then return opening end
	local n = level - #Config.Prices
	-- Capacity-adjusted cost plus a compounding 10% premium. Never flatten prices.
	-- Check the logarithm first so corrupt/extreme levels cannot produce infinity.
	local logPrice = math.log(Config.ContinuationBasePrice) + 2 * math.log(n + 1)
		+ n * math.log(Config.PriceGrowth)
	if logPrice > math.log(Currency.MaxCoins) then return nil end
	local raw = Config.ContinuationBasePrice * (n + 1)^2 * Config.PriceGrowth^n
	-- Remove only sub-coin floating-point noise near an integer (e.g. 380160).
	local nearest = math.round(raw)
	local price = if math.abs(raw - nearest) < 1e-6 then nearest else math.ceil(raw)
	return if price <= Currency.MaxCoins then price else nil
end

return table.freeze(Config)
