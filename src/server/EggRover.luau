--!strict
-- October 21 Auto Vacuum (docs/team/AUTO_VACUUM.md): one server-owned robot per yard.
-- Restored from the retired Auto Collect robot (archive/robot-vacuum-20261020), now with
-- a tank, a Range and a speed from the Upgrades > Tools tiers. This object only moves;
-- EggService owns every claim, the cargo and the Coins.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.AutoVacuumConfig)
local Layout = require(Shared.HomePlotLayout)
local EggRover = {}
EggRover.__index = EggRover

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function yawOf(direction)
	return math.atan2(-direction.X, -direction.Z)
end

-- `stats`: {range, speed} from EggService (base plus the Auto Range and Speed tiers).
function EggRover.new(id, frame, plotIndex, pad, now, stats)
	local layout = Layout.ForPlot(plotIndex)
	local minX, maxX = layout.YardMinX, layout.YardMaxX
	local minZ, maxZ = layout.YardMinZ + Config.PassEndInset, layout.YardMaxZ - Config.PassEndInset
	local floorY = layout.FootY
	-- Strips two Ranges wide: a longer reach sweeps the same yard in fewer passes.
	local passes = math.clamp(math.ceil((maxX - minX) / (stats.range * 2)), Config.MinPasses, Config.MaxPasses)
	local stripWidth = (maxX - minX) / passes
	local firstLaneX = minX + stripWidth / 2
	local approachX = firstLaneX
	if layout.YardRegions then
		local stem = layout.YardRegions[1]
		approachX = math.clamp(firstLaneX, stem.minX, stem.maxX)
	end
	local localDock = frame:PointToObjectSpace(pad.Position)
	local corridorZ = Config.DockCorridorZ + (layout.YardOffsetZ or 0)
	local dockApproachX = Config.DockApproachX + (layout.YardOffsetX or 0)
	-- The pad is outside the central lawn. Approach along the pad's side rather than
	-- taking a diagonal through the shop building.
	local approach = Vector3.new(approachX, floorY, corridorZ)
	local corridor = Vector3.new(dockApproachX, floorY, corridorZ)
	local dockApproach = Vector3.new(dockApproachX, floorY, localDock.Z)
	local dock = Vector3.new(localDock.X + Config.DockPadOffsetX, floorY, localDock.Z)
	local rows = {}
	local previous = approach
	local function appendRow(x, z)
		if layout.YardRegions and #layout.YardRegions > 1
			and not Layout.CanWalkDirect(layout, previous.X, previous.Z, x, z) then
			-- Cross the central neck instead of cutting through a T-shaped corner.
			local neck = layout.YardRegions[2].minZ
			local stem = layout.YardRegions[1]
			table.insert(rows, frame:PointToWorldSpace(Vector3.new((stem.minX + stem.maxX) / 2, floorY, neck)))
		end
		previous = Vector3.new(x, floorY, z)
		table.insert(rows, frame:PointToWorldSpace(previous))
	end
	-- One straight pass per strip, alternating direction, starting at the nearer end.
	local firstStartZ, firstFinishZ = minZ, maxZ
	if math.abs(corridorZ - maxZ) < math.abs(corridorZ - minZ) then
		firstStartZ, firstFinishZ = maxZ, minZ
	end
	for lane = 0, passes - 1 do
		local x = minX + (lane + 0.5) * stripWidth
		local startZ, finishZ = firstStartZ, firstFinishZ
		if lane % 2 == 1 then startZ, finishZ = firstFinishZ, firstStartZ end
		if layout.YardRegions then
			local laneMin, laneMax = math.huge, -math.huge
			for _, region in layout.YardRegions do
				if x >= region.minX and x <= region.maxX then
					laneMin, laneMax = math.min(laneMin, region.minZ), math.max(laneMax, region.maxZ)
				end
			end
			if laneMin > laneMax then continue end
			startZ = math.clamp(startZ, laneMin + Config.PassEndInset, laneMax - Config.PassEndInset)
			finishZ = math.clamp(finishZ, laneMin + Config.PassEndInset, laneMax - Config.PassEndInset)
		end
		appendRow(x, startZ)
		appendRow(x, finishZ)
	end
	local position = frame:PointToWorldSpace(dock)
	local direction = frame:VectorToWorldSpace(Vector3.new(-1, 0, 0))
	return setmetatable({
		id = id, enabled = true, state = "Idle", position = position,
		direction = Vector3.new(direction.X, 0, direction.Z).Unit,
		dock = position, approach = frame:PointToWorldSpace(approach), rows = rows,
		corridor = frame:PointToWorldSpace(corridor), dockApproach = frame:PointToWorldSpace(dockApproach),
		frame = frame, layout = layout, floorY = floorY,
		route = {}, waypoint = 1, range = stats.range, speed = stats.speed, passes = passes,
		nextSweepAt = now, unloadAt = 0,
		cargoCount = 0, cargoValue = 0, pendingCount = 0, pendingValue = 0,
		suctionSerial = 0, unloadSerial = 0, reversed = false, lapSerial = 0,
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
	self.reversed, self.lapSerial = false, self.suctionSerial
	self:SetRoute("Sweeping", route)
end

-- Another lap from where the last one ended: the same passes, driven the other way.
function EggRover:SweepAgain()
	self.reversed = not self.reversed
	local route = {}
	local count = #self.rows
	for i = 1, count do table.insert(route, self.rows[if self.reversed then count + 1 - i else i]) end
	self.lapSerial = self.suctionSerial
	self:SetRoute("Sweeping", route)
end

function EggRover:BeginReturn()
	local at = self.frame:PointToObjectSpace(self.position)
	local approach = self.frame:PointToObjectSpace(self.approach)
	if self.layout.YardRegions then
		local route = {}
		if #self.layout.YardRegions > 1
			and not Layout.CanWalkDirect(self.layout, at.X, at.Z, approach.X, approach.Z) then
			local stem = self.layout.YardRegions[1]
			table.insert(route, self.frame:PointToWorldSpace(Vector3.new((stem.minX + stem.maxX) / 2, self.floorY, self.layout.YardRegions[2].minZ)))
		end
		for _, point in {self.approach, self.corridor, self.dockApproach, self.dock} do table.insert(route, point) end
		self:SetRoute("Returning", route)
		return
	end
	self:SetRoute("Returning", {
		self.frame:PointToWorldSpace(Vector3.new(at.X, self.floorY, approach.Z)),
		self.approach, self.corridor, self.dockApproach, self.dock,
	})
end

-- Suction stays on along the sweep and the drive home while the tank has room.
function EggRover:CanCollect()
	return self.enabled and (self.state == "Sweeping" or self.state == "Returning")
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
		self.position += delta.Unit * math.min(distance, self.speed * dt)
	end
	return false
end

-- `full`: the tank (cargo plus eggs still flying in) has no room left; `fill` is
-- that load as a share of the tank.
function EggRover:Step(dt, now, hasEggs, full, fill)
	if self.state == "Idle" then
		if hasEggs and not full and now >= self.nextSweepAt then self:BeginSweep() end
	elseif self.state == "Sweeping" then
		-- A full tank heads home at once. At the end of the passes it heads home once
		-- the tank is nearly full, or after an empty lap with no egg waiting (no layers
		-- at home), so its cargo never waits forever; otherwise it sweeps again.
		if full then
			self:BeginReturn()
		elseif self:Move(dt) then
			local emptyLap = self.suctionSerial == self.lapSerial and not hasEggs
			if fill >= Config.ReturnFill or emptyLap then self:BeginReturn() else self:SweepAgain() end
		end
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

function EggRover:Snapshot(session, capacity)
	return {enabled = self.enabled, id = self.id, state = self.state,
		x = self.position.X, y = self.position.Y, z = self.position.Z,
		dx = self.direction.X, dz = self.direction.Z, range = self.range,
		count = self.cargoCount + self.pendingCount, capacity = capacity,
		cargoCount = self.cargoCount, cargoValue = session:EarnedAmount(self.cargoValue, "eggs"),
		suctionSerial = self.suctionSerial, unloadSerial = self.unloadSerial}
end

return EggRover
