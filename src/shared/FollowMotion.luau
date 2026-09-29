--!strict
-- Formation/steering math only. PetActor owns physics, paths and recovery.
local Motion = {}
Motion.Response = 10 -- per second; exponential response is independent of frame rate
Motion.PositionGain = 4 -- studs/second per stud of formation error
Motion.RestRadius = 0.5
Motion.TurnRate = math.rad(300) -- maximum formation yaw radians/second
Motion.LeaderDeadband = 0.75
Motion.MaxSpeed = 48

function Motion.Flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function Motion.Limit(vector: Vector3, maximum: number): Vector3
	local length = vector.Magnitude
	return if length > maximum and length > 0 then vector * (maximum / length) else vector
end

function Motion.Frame(previous: CFrame?, root: CFrame, velocity: Vector3, dt: number): CFrame
	local look = Motion.Flat(root.LookVector)
	if look.Magnitude < 0.01 then look = Vector3.new(0, 0, -1) end
	local yaw = math.atan2(-look.X, -look.Z)
	if previous then
		local before = previous.LookVector
		local oldYaw = math.atan2(-before.X, -before.Z)
		if Motion.Flat(velocity).Magnitude < Motion.LeaderDeadband then
			yaw = oldYaw -- turning the camera/character at rest must not orbit the flock
		else
			local change = math.atan2(math.sin(yaw - oldYaw), math.cos(yaw - oldYaw))
			yaw = oldYaw + math.clamp(change, -Motion.TurnRate * dt, Motion.TurnRate * dt)
		end
	end
	return CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
end

function Motion.Offset(ordinal: number, count: number, spacing: number): Vector3
	local row = math.floor((ordinal - 1) / 3)
	local columns = math.min(3, count - row * 3)
	local column = (ordinal - 1) % 3 - (columns - 1) / 2
	return Vector3.new(column * spacing, 0, 7 + spacing * row)
end

function Motion.Velocity(current: Vector3, error: Vector3, leader: Vector3, maximum: number, dt: number, onPath: boolean?): Vector3
	error, leader = Motion.Flat(error), Motion.Flat(leader)
	maximum = math.clamp(maximum, 0, Motion.MaxSpeed)
	local distance = error.Magnitude
	local desired: Vector3
	if onPath then
		-- Intermediate waypoints are crossings, not places to brake to a stop.
		desired = if distance > 0.01 then error.Unit * maximum else Vector3.zero
	else
		if leader.Magnitude < Motion.LeaderDeadband then leader = Vector3.zero end
		local correction = if distance > Motion.RestRadius
			then error * ((distance - Motion.RestRadius) * Motion.PositionGain / distance)
			else Vector3.zero
		desired = Motion.Limit(leader + correction, maximum)
	end
	local alpha = 1 - math.exp(-Motion.Response * math.clamp(dt, 0, 0.1))
	local velocity = Motion.Limit(current:Lerp(desired, alpha), maximum)
	if desired.Magnitude == 0 and velocity.Magnitude < 0.15 then return Vector3.zero end
	return velocity
end

return Motion
