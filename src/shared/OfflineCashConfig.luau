--!strict
-- Launch tuning: eight hours buys at most 9.6 minutes of sustainable production.
return table.freeze({
	Efficiency = 0.02,
	MaxSeconds = 8 * 60 * 60,
	MinSeconds = 60,
	MaxCoins = 1e12,
})
