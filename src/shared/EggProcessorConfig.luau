--!strict
return table.freeze({
	Rates = table.freeze({2, 4, 8, 16, 32}),
	Prices = table.freeze({480, 2400, 9600, 28800}),
	BoardDistance = 24,
	MaxBatches = 64,
	MaxValue = 1e12,
})
