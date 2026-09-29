--!strict
-- One server-owned yard sweep. This object moves; EggService owns all claims/payment.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.VacuumConfig)
local Layout = require(Shared.HomePlotLayout)
local EggRover = {}
EggRover.__index = EggRover

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function yawOf(direction)
	return math.atan2(-direction.X, -direction.Z)
end

function EggRover.new(id, frame, plotIndex, pad, now)
	local layout = Layout.ForPlot(plotIndex)
	local minX, maxX = layout.YardMinX, layout.YardMaxX
	local minZ, maxZ = layout.YardMinZ + Config.PassEndInset, layout.YardMaxZ - Config.PassEndInset
	local floorY = layout.FootY
	local stripWidth = (maxX - minX) / Config.PassCount
	local firstLaneX = minX + stripWidth / 2
	local localDock = frame:PointToObjectSpace(pad.Position)
	-- The stand input pad is outside the central lawn. Approach along the same
	-- side as the pad, rather than taking a diagonal through the shop building.
	local approach = Vector3.new(firstLaneX, floorY, Config.DockCorridorZ)
	local corridor = Vector3.new(Config.DockApproachX, floorY, Config.DockCorridorZ)
	local dockApproach = Vector3.new(Config.DockApproachX, floorY, localDock.Z)
	local dock = Vector3.new(localDock.X + Config.DockPadOffsetX, floorY, localDock.Z)
	local rows = {}
	-- Four equal strips, one straight pass per strip. Start at the nearer end
	-- of the first strip, then alternate direction; this is the same route each trip.
	local firstStartZ, firstFinishZ = minZ, maxZ
	if math.abs(Config.DockCorridorZ - maxZ) < math.abs(Config.DockCorridorZ - minZ) then
		firstStartZ, firstFinishZ = maxZ, minZ
	end
	for lane = 0, Config.PassCount - 1 do
		local x = minX + (lane + 0.5) * stripWidth
		local startZ, finishZ = firstStartZ, firstFinishZ
		if lane % 2 == 1 then startZ, finishZ = firstFinishZ, firstStartZ end
		table.insert(rows, frame:PointToWorldSpace(Vector3.new(x, floorY, startZ)))
		table.insert(rows, frame:PointToWorldSpace(Vector3.new(x, floorY, finishZ)))
	end
	local position = frame:PointToWorldSpace(dock)
	local direction = frame:VectorToWorldSpace(Vector3.new(-1, 0, 0))
	-- Upgraded plots still get four passes. Grow only the rover's intake enough
	-- to reach each strip's edges; the player's manual magnet radius is unchanged.
	local halfIntake = stripWidth / 2 + Config.SuctionEdgePadding
	local verticalOffset = 0.8 - Config.NozzleOffset.Y
	local suctionRadius = math.max(Config.SuctionRadius, math.sqrt(halfIntake ^ 2 + verticalOffset ^ 2))
	return setmetatable({
		id = id, enabled = true, state = "Idle", position = position,
		direction = Vector3.new(direction.X, 0, direction.Z).Unit,
		dock = position, approach = frame:PointToWorldSpace(approach), rows = rows,
		corridor = frame:PointToWorldSpace(corridor), dockApproach = frame:PointToWorldSpace(dockApproach),
		frame = frame, minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ, floorY = floorY,
		route = {}, waypoint = 1, suctionRadius = suctionRadius,
		nextSweepAt = now, unloadAt = 0,
		cargoCount = 0, cargoValue = 0, pendingCount = 0,
		suctionSerial = 0, unloadSerial = 0,
	}, EggRover)
end

function EggRover:Nozzle()
	return (CFrame.lookAt(self.position, self.position + self.direction) * CFrame.new(Config.NozzleOffset)).Position
end

function EggRover:SetRoute(state, route)
	self.state, self.route, self.waypoint = state, route, 1
end

function EggRover:BeginSweep()
	local route = {self.dockApproach, self.corridor, self.approach}
	for _, point in self.rows do table.insert(route, point) end
	self:SetRoute("Sweeping", route)
end

function EggRover:BeginReturn()
	local at = self.frame:PointToObjectSpace(self.position)
	local approach = self.frame:PointToObjectSpace(self.approach)
	self:SetRoute("Returning", {
		self.frame:PointToWorldSpace(Vector3.new(at.X, self.floorY, approach.Z)),
		self.approach, self.corridor, self.dockApproach, self.dock,
	})
end

function EggRover:CanCollect(now)
	-- Keep suction on along the approach and return, not just the lawn rows.
	-- Close the dock intake after the unload window so pending flights can drain.
	return self.enabled and (self.state=="Sweeping" or self.state=="Returning"
		or (self.state=="Unloading" and now<self.unloadAt))
end

function EggRover:Move(dt)
	local target = self.route[self.waypoint]
	if not target then return true end
	local delta = Vector3.new(target.X - self.position.X, 0, target.Z - self.position.Z)
	local distance = delta.Magnitude
	if distance <= Config.ArrivalDistance then
		self.position = target
		self.waypoint += 1
		return self.route[self.waypoint] == nil
	end
	local wanted = yawOf(delta.Unit)
	local yaw = yawOf(self.direction)
	local difference = math.atan2(math.sin(wanted - yaw), math.cos(wanted - yaw))
	local turn = math.clamp(difference, -Config.TurnSpeed * dt, Config.TurnSpeed * dt)
	local nextYaw = yaw + turn
	self.direction = Vector3.new(-math.sin(nextYaw), 0, -math.cos(nextYaw))
	if math.abs(difference - turn) <= Config.TurnBeforeMovingAngle then
		self.position += delta.Unit * math.min(distance, Config.MoveSpeed * dt)
	end
	return false
end

function EggRover:Step(dt, now, hasEggs)
	if self.state == "Idle" then
		if hasEggs and now >= self.nextSweepAt then self:BeginSweep() end
	elseif self.state == "Sweeping" then
		-- Cargo is an earnings ledger, not a tank limit. Finish all four passes.
		if self:Move(dt) then self:BeginReturn() end
	elseif self.state == "Returning" then
		if self:Move(dt) then
			self.state = "Unloading"
			self.unloadAt = now + Config.UnloadSeconds
		end
	end
end

function EggRover:ReadyToUnload(now)
	return self.state == "Unloading" and self.pendingCount == 0 and now >= self.unloadAt
		and flatDistance(self.position, self.dock) <= Config.ArrivalDistance
end

function EggRover:FinishUnload(now)
	self.state = "Idle"
	self.nextSweepAt = now + Config.IdleSeconds
	self.unloadSerial += 1
end

function EggRover:Snapshot(session)
	return {enabled = self.enabled, id = self.id, state = self.state,
		x = self.position.X, y = self.position.Y, z = self.position.Z,
		dx = self.direction.X, dz = self.direction.Z,
		cargoCount = self.cargoCount, cargoValue = session:EarnedAmount(self.cargoValue, "eggs"),
		suctionSerial = self.suctionSerial, unloadSerial = self.unloadSerial}
end

return EggRover
