--!strict
-- October 21 Auto Vacuum (docs/team/AUTO_VACUUM.md). The retired Auto Collect robot
-- comes back as a Tools upgrade: it drives the yard on its own, pulls in eggs within
-- its Range until its tank is full, then drives to the green pad and sells them.
-- Tuning only: EggRover moves it, EggService owns claims, cargo and Coins.
return table.freeze({
	-- October 22 (Stevin): no eggs-vacuumed unlock any more. The Auto Vacuum is an
	-- ordinary Coins purchase priced above the hand vacuum's last tier (UpgradeCatalog).

	-- Tank: like the Egg Vacuum, sized in seconds of the Flock's current laying (plus
	-- the Auto Capacity tiers), shown in eggs and never below MinCapacity.
	Seconds = 20,
	MinCapacity = 8,
	-- Range: flat studs from the nozzle (plus the Auto Range tiers). The route splits
	-- the yard into strips two Ranges wide, so a longer reach means fewer passes.
	Range = 5,
	MaxHeight = 6,
	MinPasses = 2,
	MaxPasses = 10,
	-- Drive speed in studs a second, times (1 + the Auto Speed tiers).
	MoveSpeed = 8,
	TurnSpeed = math.rad(220),
	TurnBeforeMovingAngle = math.rad(12),
	PickupBatch = 6,
	PickupStagger = 0.06,
	-- Waits at the pad this long after a sale, and until at least one egg is ready.
	IdleSeconds = 2,
	UnloadSeconds = 0.8,
	ArrivalDistance = 0.08,
	PassEndInset = 2,

	-- The Studio robot `ReplicatedStorage.PetRoll.Assets.EggVacuum` (Blender clips in
	-- VacuumClips). Builder plot-local corridor clear of the lamp near the egg stand.
	TemplateName = "EggVacuum",
	ModelScale = 4.2,
	NozzleOffset = Vector3.new(0, 0.32, -1.86),
	WheelRadius = 0.677,
	WheelDiameterScale = 1.35,
	WheelWidthScale = 1.12,
	DockCorridorZ = -5,
	DockApproachX = -20.25,
	DockPadOffsetX = 1.65,
})
