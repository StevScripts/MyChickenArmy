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

-- The fixed landing zone for a plot: the fallback when no random spot is free.
function InvasionLayout.Landing(plotIndex: number): Vector3?
	return InvasionLayout.Landings[plotIndex]
end

-- October 14 (owner): scouts land on a random open patch of the island instead.
-- Candidates are found once from the authored map (under PetRollWorld at runtime):
-- island ground (the huge flat base part) with no map parts (roads, camps, plots,
-- props) within ZoneClearance.
InvasionLayout.ZoneClearance = 28 -- half-size of the empty box around a candidate
InvasionLayout.MinSeparation = 90 -- two active invasions never land this close
local GRID, INNER, OUTER = 24, 70, 420
local candidates: {Vector3}? = nil

function InvasionLayout.Candidates(): {Vector3}
	if candidates then return candidates end
	local found = {}
	local map = workspace:FindFirstChild("MyChickenArmyMap") or workspace:FindFirstChild("PetRollWorld")
	if map then
		local ray = RaycastParams.new()
		ray.FilterType, ray.FilterDescendantsInstances = Enum.RaycastFilterType.Include, {map}
		local box = OverlapParams.new()
		box.FilterType, box.FilterDescendantsInstances = Enum.RaycastFilterType.Include, {map}
		local size = Vector3.new(InvasionLayout.ZoneClearance * 2, 12, InvasionLayout.ZoneClearance * 2)
		for x = -OUTER, OUTER, GRID do
			for z = -OUTER, OUTER, GRID do
				local r = math.sqrt(x * x + z * z)
				if r < INNER or r > OUTER then continue end
				local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), ray)
				if not hit or hit.Instance.Size.Magnitude < 400 then continue end
				local ground = hit.Position.Y
				local clutter = false
				for _, item in workspace:GetPartBoundsInBox(CFrame.new(x, ground + 6.5, z), size, box) do
					if item.Size.Magnitude < 400 then clutter = true; break end
				end
				if not clutter then table.insert(found, Vector3.new(x, ground + 0.05, z)) end
			end
		end
	end
	if #found > 0 then candidates = found end -- Retry later if the map was not ready.
	return found
end

-- A random open landing spot at least MinSeparation from every `taken` spot,
-- or nil when none is free.
function InvasionLayout.Pick(rng: Random, taken: {Vector3}): Vector3?
	local pool = {}
	for _, spot in InvasionLayout.Candidates() do
		local free = true
		for _, other in taken do
			if (Vector3.new(spot.X - other.X, 0, spot.Z - other.Z)).Magnitude < InvasionLayout.MinSeparation then free = false; break end
		end
		if free then table.insert(pool, spot) end
	end
	if #pool == 0 then return nil end
	return pool[rng:NextInteger(1, #pool)]
end

-- The battle frame: centred on the landing, facing back toward the island centre
-- (so the airship approaches from the sea behind the enemy line).
function InvasionLayout.Frame(plotIndex: number): CFrame?
	local landing = InvasionLayout.Landing(plotIndex)
	if not landing then return nil end
	return CFrame.lookAt(landing, Vector3.new(0, landing.Y, 0))
end

return InvasionLayout
