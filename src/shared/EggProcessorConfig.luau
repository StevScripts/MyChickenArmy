--!strict
local Currency = require(script.Parent.CurrencyLimits)
local Config = {
	-- September 29: deposits pay instantly. Restore the archived boards with this switch.
	Enabled = false,
	BaseRate = 4,
	FirstRateGain = 1,
	RateGainGrowth = 1.10,
	BasePrice = 40,
	PriceGrowth = 1.20,
	BoardDistance = 24,
	MaxBatches = 64,
	MaxValue = 1e12,
}

function Config.ValidLevel(level: any): boolean
	-- Serialization/integer precision boundary, not a designed progression cap.
	return type(level) == "number" and level == level and level >= 0
		and level <= 2^53 - 1 and level % 1 == 0
end

function Config.Price(level: number): number?
	-- Smaller purchases have a smooth exponential price instead of large tiers.
	-- Check the logarithm first so corrupt/extreme levels cannot produce infinity.
	local logPrice = math.log(Config.BasePrice) + level * math.log(Config.PriceGrowth)
	if logPrice > math.log(Currency.MaxCoins) then return nil end
	local raw = Config.BasePrice * Config.PriceGrowth^level
	-- Remove only sub-coin floating-point noise near an integer.
	local nearest = math.round(raw)
	local price = if math.abs(raw - nearest) < 1e-6 then nearest else math.ceil(raw)
	return if price <= Currency.MaxCoins then price else nil
end

-- Cache every numerically purchasable level once, not once per snapshot/tick.
-- Compound the added amount, rounding each purchase: +1 / +1 / +1 / +1 / +1 / +2 / ... .
local rates = {Config.BaseRate}
while Config.Price(#rates - 1) do
	local gain = math.max(1, math.round(Config.FirstRateGain * Config.RateGainGrowth^(#rates - 1)))
	table.insert(rates, rates[#rates] + gain)
end
table.freeze(rates)

function Config.Rate(level: number): number
	local rate = rates[level + 1]
	if rate then return rate end
	-- Beyond the wallet's representable purchases, retain finite increasing rates
	-- for legacy saves without exponentiating an arbitrarily large saved level.
	-- This is numerical fallback behavior, not a purchasable final tier or speed cap.
	local extra = level - (#rates - 1)
	local lastGain = rates[#rates] - rates[#rates - 1]
	return rates[#rates] + lastGain * extra * (extra + 1) / 2
end

return table.freeze(Config)
