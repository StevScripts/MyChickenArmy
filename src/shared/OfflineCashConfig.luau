--!strict
-- October 14 owner fix ("offline cash doesn't even work"): 2% paid so little that
-- players thought it was broken. 20% means eight hours away pays 96 minutes of
-- egg income. Checkpoints saved before this (no efficiency field) were recorded at
-- LegacyEfficiency and are scaled up when paid (OfflineCash.Reward).
return table.freeze({
	Efficiency = 0.2,
	LegacyEfficiency = 0.02,
	MaxSeconds = 8 * 60 * 60,
	MinSeconds = 60,
	MaxCoins = 1e12,
})
