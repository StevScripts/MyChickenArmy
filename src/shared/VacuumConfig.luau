--!strict
-- Egg vacuum tuning. Currency and eligibility remain server-owned.
return table.freeze({
	TemplateName = "EggVacuum",
	ModelScale = 4.2,
	NozzleOffset = Vector3.new(0, 0.32, -1.86),
	WheelRadius = 0.677,
	WheelDiameterScale = 1.35,
	WheelWidthScale = 1.12,
	MoveSpeed = 16,
	TurnSpeed = math.rad(220),
	TurnBeforeMovingAngle = math.rad(12),
	PassCount = 4,
	PassEndInset = 2,
	-- Builder plot-local clear corridor, around the small lamp near the egg stand.
	DockCorridorZ = -5,
	DockApproachX = -20.25,
	DockPadOffsetX = 1.65,
	SuctionRadius = 9,
	SuctionEdgePadding = 1.5,
	PickupBatch = 8,
	PickupStagger = 0.06,
	IdleSeconds = 1.5,
	UnloadSeconds = 0.8,
	ArrivalDistance = 0.08,
	-- No production bypass: EggService also requires RunService:IsStudio().
	StudioTestAttribute = "TestEggVacuum",
})
