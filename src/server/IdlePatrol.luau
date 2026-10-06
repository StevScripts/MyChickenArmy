--!strict
-- Idle-only movement, stepped by the actor's world owner. No tasks or connections.
-- Camp encounters take ownership of these same actors when an attack starts.
local IdlePatrol = {}
IdlePatrol.__index = IdlePatrol

function IdlePatrol.new(actor, random, speed, pauseMin, pauseMax)
	return setmetatable({
		actor = actor, random = random, speed = speed,
		pauseMin = pauseMin, pauseMax = pauseMax,
		nextAt = os.clock() + random:NextNumber(0.1, 1.8),
		target = nil, deadline = 0,
	}, IdlePatrol)
end

function IdlePatrol:Step(now, chooseTarget)
	if self.actor.destroyed then return end
	local state = self.actor:Step(now)
	if self.target then
		if state == "arrived" or state == "blocked" or now >= self.deadline then
			self.actor:Stop()
			self.target = nil
			self.nextAt = now + self.random:NextNumber(self.pauseMin, self.pauseMax)
		end
		return
	end
	if now < self.nextAt then return end
	local target = chooseTarget()
	local at = self.actor:Position()
	local distance = Vector3.new(target.X - at.X, 0, target.Z - at.Z).Magnitude
	if distance < 2 then self.nextAt = now + 0.35; return end
	self.target = target
	self.deadline = now + distance / self.speed + 3
	self.actor:MoveTo(target, self.speed)
end

-- Prefer free space, including other birds' reserved destinations, over piling up.
function IdlePatrol.DiskTarget(frame, radius, patrols, current, random)
	local best, bestScore = frame.Position, -math.huge
	for _ = 1, 10 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(random:NextNumber()) * radius
		local candidate = frame:PointToWorldSpace(Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
		local score = radius * 2
		for _, patrol in patrols do
			if patrol ~= current then
				score = math.min(score, (candidate - patrol.actor:Position()).Magnitude)
				if patrol.target then score = math.min(score, (candidate - patrol.target).Magnitude) end
			end
		end
		if (candidate - current.actor:Position()).Magnitude < 3 then score -= radius * 2 end
		if score > bestScore then best, bestScore = candidate, score end
	end
	return best
end

return IdlePatrol
