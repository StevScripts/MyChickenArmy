--!strict
return table.freeze({
	-- Frozen historical costs, used only to validate/refund retired selling levels.
	Prices = table.freeze({480, 2400, 9600, 28800}),
	MaxBatches = 64,
	MaxValue = 1e12,
})
