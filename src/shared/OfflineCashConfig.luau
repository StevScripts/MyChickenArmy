--!strict
-- October 14 owner fix ("offline cash doesn't even work"): 2% paid so little that
-- players thought it was broken. 20% means eight hours away pays 96 minutes of
-- egg income. Checkpoints saved before this (no efficiency field) were recorded at
-- LegacyEfficiency and are scaled up when paid (OfflineCash.Reward).
-- October 15 (owner, after the live economy pull): offline was 52% of all cash
-- earned (more than active egg income), so efficiency drops to 10% (eight hours
-- away pays 48 minutes of egg income) and the per-claim MaxCoins cap below is now
-- enforced in OfflineCash.Reward (it was declared but never applied).
return table.freeze({
	Efficiency = 0.1,
	LegacyEfficiency = 0.02,
	MaxSeconds = 8 * 60 * 60,
	MinSeconds = 60,
	MaxCoins = 1e12,
})
