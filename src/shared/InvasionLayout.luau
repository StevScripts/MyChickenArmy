--!strict
-- October 14 Invasions: each home plot has one landing zone on the island beside
-- it, where the Chicken King's loyalists drop from their airship. Measured from
-- the authored map (flat island ground, fewest props within 23 studs, inside the
-- island edge), evenly spaced about 60° apart so neighbours never share one.
local InvasionLayout = {}

InvasionLayout.Landings = {
	Vector3.new(409.8, 1.05, -9.5),
	Vector3.new(245.6, 1.05, 340.6),
	Vector3.new(-172.6, 1.05, 388.3),
	Vector3.new(-393.7, 1.05, 32.2),
	Vector3.new(-271.1, 1.05, -320.9),
	Vector3.new(169.0, 1.05, -379.1),
}

-- The landing zone for a plot, or nil for an unknown plot.
function InvasionLayout.Landing(plotIndex: number): Vector3?
	return InvasionLayout.Landings[plotIndex]
end

-- The battle frame: centred on the landing, facing back toward the island centre
-- (so the airship approaches from the sea behind the enemy line).
function InvasionLayout.Frame(plotIndex: number): CFrame?
	local landing = InvasionLayout.Landing(plotIndex)
	if not landing then return nil end
	return CFrame.lookAt(landing, Vector3.new(0, landing.Y, 0))
end

return InvasionLayout
