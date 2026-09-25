--!strict
-- One server-owned Humanoid per moving chicken. World/Battle call Step centrally.
-- Direct MoveTo handles open lanes; bounded path requests recover obstruction.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PetRoll"):WaitForChild("Shared")
local PetView = require(Shared:WaitForChild("PetView"))
local Config = require(Shared:WaitForChild("Config"))
local KingVisual = require(Shared:WaitForChild("KingVisual"))
local PetActor = {}
PetActor.__index = PetActor

local ACTORS, CHARACTERS = "DuckActors", "DuckPlayers"
-- Humanoid:MoveTo may finish about one stud from its target.
-- A smaller tolerance misclassifies successful arrivals as permanent stalls.
local ARRIVAL = Config.ActorArrivalDistance or 1.25
local STUCK_SECONDS = 2.2
local MAX_RECOVERIES = 2
local MAX_PATH_REQUESTS = 2
local PATH_TIMEOUT = 8
local BLOCK_RETRY_SECONDS = 3
local HEALTH_INTERVAL = 0.5
local activePaths = 0
local collisionReady = false
local characterConnections: {[Player]: RBXScriptConnection} = {}
local playerConnections: {[Player]: RBXScriptConnection} = {}

local function setupCollisions()
	if collisionReady then return end
	collisionReady = true
	for _, name in {ACTORS, CHARACTERS} do
		if not PhysicsService:IsCollisionGroupRegistered(name) then PhysicsService:RegisterCollisionGroup(name) end
	end
	PhysicsService:CollisionGroupSetCollidable(ACTORS, ACTORS, false)
	PhysicsService:CollisionGroupSetCollidable(ACTORS, CHARACTERS, false)
	PhysicsService:CollisionGroupSetCollidable(ACTORS, "Default", true)
	local function characterAdded(player: Player, character: Model)
		if characterConnections[player] then characterConnections[player]:Disconnect() end
		local function assign(item: Instance)
			if item:IsA("BasePart") then item.CollisionGroup = CHARACTERS end
		end
		for _, item in character:GetDescendants() do assign(item) end
		characterConnections[player] = character.DescendantAdded:Connect(assign)
	end
	local function playerAdded(player: Player)
		if playerConnections[player] then return end
		playerConnections[player] = player.CharacterAdded:Connect(function(character) characterAdded(player, character) end)
		if player.Character then characterAdded(player, player.Character) end
	end
	for _, player in Players:GetPlayers() do playerAdded(player) end
	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(function(player)
		if characterConnections[player] then characterConnections[player]:Disconnect() characterConnections[player] = nil end
		if playerConnections[player] then playerConnections[player]:Disconnect() playerConnections[player] = nil end
	end)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
local function finiteVector(value: Vector3): boolean
	return value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < 100000 and math.abs(value.Y) < 100000 and math.abs(value.Z) < 100000
end

function PetActor.new(parent: Instance, id: string, species: string, stars: number, foot: Vector3, facing: Vector3?)
	setupCollisions()
	local model = PetView.CreateRig(parent, id, species, stars, foot)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	root.CollisionGroup = ACTORS
	if facing then
		local flat = Vector3.new(facing.X, 0, facing.Z)
		if flat.Magnitude > 0.01 then model:PivotTo(CFrame.lookAt(root.Position, root.Position + flat.Unit)) end
	end
	local owns = pcall(function() root:SetNetworkOwner(nil) end)
	model:SetAttribute("ServerNetworkOwned", owns)
	if not owns then warn("Chicken actor could not acquire server physics ownership: " .. id) end
	local self = setmetatable({
		model = model, root = root, humanoid = humanoid,
		body = model:FindFirstChildWhichIsA("MeshPart", true) or model:FindFirstChild("Body"),
		parent = parent, species = species, stars = stars, safeFoot = foot, spawnFoot = foot,
		healthAt = 0, healthPosition = foot, repairAt = 0,
		footOffset = model:GetAttribute("FootOffset") :: number,
		goal = nil :: Vector3?, speed = 0, state = "idle", destroyed = false,
		lastCommand = 0, commandTarget = nil :: Vector3?,
		progressPosition = foot, progressAt = os.clock(),
		recoveries = 0, requestPending = false, requestGeneration = 0,
		waypoints = nil :: {Vector3}?, waypointIndex = 1,
	}, PetActor)
	return self
end

function PetActor:Position(): Vector3
	if not self.root:IsDescendantOf(self.model) or not finiteVector(self.root.Position) then return self.safeFoot end
	return self.root.Position - Vector3.new(0, self.model:GetAttribute("FootOffset") or self.footOffset, 0)
end

-- Ownership transfers update this even if the model disappears before Step.
function PetActor:SetParent(parent: Instance)
	self.parent = parent
	self.model.Parent = parent
end

function PetActor:_clearPath()
	if self.pathBlocked then self.pathBlocked:Disconnect(); self.pathBlocked = nil end
	if self.path then self.path:Destroy(); self.path = nil end
	self.waypoints = nil
end

function PetActor:_cancelRequest()
	local request = self.pathRequest
	self.pathRequest, self.requestPending = nil, false
	if not request or request.done then return end
	request.done = true
	activePaths -= 1
	if request.thread and coroutine.status(request.thread) == "suspended" then task.cancel(request.thread) end
	if request.path then request.path:Destroy() end
end

function PetActor:RigIssue(): string?
	if self.destroyed then return "Destroyed" end
	if self.model.Parent ~= self.parent or not self.model:IsDescendantOf(workspace) then return "Missing model" end
	if not self.root:IsDescendantOf(self.model) or self.model.PrimaryPart ~= self.root then return "Missing root" end
	if not self.humanoid:IsDescendantOf(self.model) then return "Missing Humanoid" end
	if self.body and not self.body:IsDescendantOf(self.model) then return "Missing body" end
	if self.body and self.body.AssemblyRootPart ~= self.root.AssemblyRootPart then return "Disconnected body" end
	if self.humanoid.Health <= 0 or self.humanoid:GetState() == Enum.HumanoidStateType.Dead then return "Physical Humanoid died" end
	if not finiteVector(self.root.Position) then return "Invalid position" end
	if self.root.Anchored or self.root.AssemblyMass == math.huge then return "Anchored rig" end
	return nil
end

-- Only grounded, clear positions become recovery anchors. This uses the actor's
-- collision group, so players, other chickens and noncolliding art are ignored.
function PetActor:_safeGround(foot: Vector3): Vector3?
	if not finiteVector(foot) then return nil end
	local ray = RaycastParams.new()
	ray.FilterType, ray.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {self.model}
	ray.CollisionGroup, ray.RespectCanCollide = ACTORS, true
	local hit = workspace:Raycast(foot + Vector3.new(0, 2, 0), Vector3.new(0, -5, 0), ray)
	if not hit or hit.Normal.Y < 0.65 or math.abs(hit.Position.Y - foot.Y) > 1.5 then return nil end
	local at = Vector3.new(foot.X, hit.Position.Y, foot.Z)
	local overlap = OverlapParams.new()
	overlap.FilterType, overlap.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {self.model}
	overlap.CollisionGroup, overlap.RespectCanCollide = ACTORS, true
	local offset = self.model:GetAttribute("FootOffset") or self.footOffset
	local frame = CFrame.new(at + Vector3.new(0, offset + 0.1, 0))
	-- A conservative axis-aligned box also works when the rig is tipped over.
	if #workspace:GetPartBoundsInBox(frame, self.root.Size * 0.9, overlap) > 0 then return nil end
	return at
end

function PetActor:CanStandAt(foot: Vector3): boolean
	return not self.destroyed and self:_safeGround(foot) ~= nil
end

-- Physical repair never edits the owner's unit HP, respawn timer or pet record.
-- Rebuild through the same rig factory so deleted joints/parts cannot survive.
function PetActor:Recover(foot: Vector3?, reason: string, now: number?): boolean
	if self.destroyed then return false end
	now = now or os.clock()
	if now < self.repairAt then return false end
	self.repairAt = now + 1
	if not self.parent:IsDescendantOf(workspace) then return false end
	local safe = (foot and self:_safeGround(foot)) or self:_safeGround(self.safeFoot) or self:_safeGround(self.spawnFoot)
	if not safe then return false end
	local old, goal, speed = self.model, self.goal, self.speed
	local attributes, scale = old:GetAttributes(), old:GetScale()
	self:Stop()
	local facing = self.root.CFrame.LookVector
	local replacement = PetActor.new(self.parent, old.Name, self.species, self.stars, safe, if finiteVector(facing) then facing else nil)
	PetView.Level(replacement.model, attributes.Level or 1)
	if attributes.ChickenKing then KingVisual.Apply(replacement.model, scale / replacement.model:GetScale()) end
	for name, value in attributes do replacement.model:SetAttribute(name, value) end
	self.model, self.root, self.humanoid = replacement.model, replacement.root, replacement.humanoid
	self.body = replacement.body
	self.footOffset, self.facing = self.model:GetAttribute("FootOffset"), nil
	self.model:PivotTo(CFrame.new(safe + Vector3.new(0, self.footOffset, 0)) * self.root.CFrame.Rotation)
	self.model:SetAttribute("MovementBlocked", false)
	self.model:SetAttribute("MovementBlockReason", nil)
	self.model:SetAttribute("Moving", false)
	self.model:SetAttribute("RecoveryReason", reason)
	self.model:SetAttribute("RecoveryCount", (attributes.RecoveryCount or 0) + 1)
	if attributes.AtHome then PetView.Cash(self.model, 0, false) end
	old:Destroy()
	self.safeFoot, self.healthPosition, self.healthAt = safe, safe, now
	self.progressPosition, self.progressAt, self.recoveries = safe, now, 0
	if goal and not attributes.Defeated then self:MoveTo(goal, math.max(speed, 0.1)) end
	return true
end

function PetActor:_command(target: Vector3, now: number, force: boolean?)
	if self.destroyed then return end
	local changed = not self.commandTarget or flatDistance(target, self.commandTarget) > 0.45
	if force or now - self.lastCommand >= 2 or (changed and now - self.lastCommand >= 0.18) then
		self.humanoid.WalkSpeed = self.speed
		self.humanoid:MoveTo(target)
		self.commandTarget, self.lastCommand = target, now
	end
end

function PetActor:MoveTo(foot: Vector3, speed: number): boolean
	if self.destroyed or not finiteVector(foot) or speed ~= speed or math.abs(speed) == math.huge then return false end
	local now = os.clock()
	local at = self:Position()
	if flatDistance(at, foot) <= ARRIVAL and math.abs(at.Y - foot.Y) < 3 then
		if self.state ~= "arrived" then self:Stop(); self.state = "arrived" end
		return true
	end
	local newTrip = not self.goal or flatDistance(self.goal, foot) > 5
	if self.state == "blocked" and not newTrip then return false end
	if newTrip then
		self.requestGeneration += 1
		self:_cancelRequest()
		self:_clearPath()
		self.waypointIndex = 1
		self.progressPosition, self.progressAt = self:Position(), now
		self.recoveries = 0
		self.model:SetAttribute("MovementBlocked", false)
		self.model:SetAttribute("MovementBlockReason", nil)
	end
	self.goal = foot
	if self.facing then self.facing.Enabled=false end
	self.humanoid.AutoRotate=true
	self.speed = math.clamp(speed, 0.1, 48)
	self.state = "moving"
	if self.model:GetAttribute("Moving") ~= true then self.model:SetAttribute("Moving", true) end
	local target = if self.waypoints then self.waypoints[self.waypointIndex] else foot
	if target then self:_command(target, now) end
	return true
end

function PetActor:Stop(keepFacing: boolean?)
	if self.destroyed then return end
	if not keepFacing then
		if self.facing then self.facing.Enabled=false end
		self.humanoid.AutoRotate=true
	end
	if self.state=="idle" and self.goal==nil and not self.requestPending and self.humanoid.WalkSpeed==0 then return end
	self.requestGeneration += 1
	self:_cancelRequest()
	self:_clearPath()
	self.goal = nil
	self.state, self.speed, self.commandTarget = "idle", 0, nil
	if self.humanoid.Parent then
		self.humanoid:Move(Vector3.zero)
		self.humanoid.WalkSpeed = 0
	end
	if self.model:GetAttribute("Moving") ~= false then self.model:SetAttribute("Moving", false) end
	-- An explicit cancellation clears the error presentation. _block calls Stop
	-- first, then deliberately restores its blocked state and failure reason.
	if self.model:GetAttribute("MovementBlocked") == true then
		self.model:SetAttribute("MovementBlocked", false)
		self.model:SetAttribute("MovementBlockReason", nil)
	end
end

-- Turn smoothly while planted in melee range. Moving releases the constraint
-- back to the Humanoid; this never pivots/teleports a fighting chicken.
function PetActor:Face(target: Vector3)
	if self.destroyed then return end
	self:Stop(true)
	local direction=Vector3.new(target.X-self.root.Position.X,0,target.Z-self.root.Position.Z)
	if direction.Magnitude<0.01 then return end
	if not self.facing then
		local attachment=Instance.new("Attachment");attachment.Name="CombatFacing";attachment.Parent=self.root
		local facing=Instance.new("AlignOrientation")
		facing.Name="CombatFacing";facing.Mode=Enum.OrientationAlignmentMode.OneAttachment
		facing.Attachment0=attachment;facing.RigidityEnabled=false
		facing.Responsiveness=18;facing.MaxTorque=100000;facing.MaxAngularVelocity=12
		facing.Parent=self.root;self.facing=facing
	end
	self.humanoid.AutoRotate=false
	self.facing.CFrame=CFrame.lookAt(Vector3.zero,direction.Unit)
	self.facing.Enabled=true
end

function PetActor:_block(reason: string, now: number?)
	local goal, speed = self.goal, self.speed
	self:Stop()
	self.state, self.goal, self.speed = "blocked", goal, speed
	self.blockedUntil = (now or os.clock()) + BLOCK_RETRY_SECONDS
	self.model:SetAttribute("MovementBlocked", true)
	self.model:SetAttribute("MovementBlockReason", reason)
end

function PetActor:_recover(now: number)
	if self.requestPending or activePaths >= MAX_PATH_REQUESTS or not self.goal then return end
	if self.recoveries >= MAX_RECOVERIES then
		self:_block("No walkable route after two recovery attempts", now)
		return
	end
	self:_clearPath()
	self.recoveries += 1
	self.requestPending = true
	self.requestGeneration += 1
	local generation, target, origin = self.requestGeneration, self.goal, self:Position()
	local radius = math.max(self.root.Size.X, self.root.Size.Z) / 2 + 0.15
	local height = math.max(2, self.model:GetAttribute("VisualHeight") or 4)
	self.progressAt, self.progressPosition = now, origin
	local request = {done = false, startedAt = now}
	self.pathRequest = request
	activePaths += 1
	request.thread = task.defer(function()
		-- Creation, computation and waypoint extraction all share one release path.
		local ok, points = pcall(function()
			local path = PathfindingService:CreatePath({AgentRadius = radius, AgentHeight = height,
				AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 5})
			request.path = path
			path:ComputeAsync(origin, target)
			if path.Status ~= Enum.PathStatus.Success then return nil end
			local result = {}
			for _, waypoint in path:GetWaypoints() do table.insert(result, waypoint.Position) end
			return result
		end)
		if request.done then return end
		request.done = true
		activePaths -= 1
		if self.pathRequest == request then self.pathRequest, self.requestPending = nil, false end
		if self.destroyed or generation ~= self.requestGeneration then
			if request.path then request.path:Destroy() end
			return
		end
		self.progressAt, self.progressPosition = os.clock(), self:Position()
		if ok and points and #points > 0 then
			self.path, self.waypoints, self.waypointIndex = request.path, points, 1
			self.pathBlocked = self.path.Blocked:Connect(function(index)
				if index < self.waypointIndex then return end
				self:_clearPath()
				self.progressAt = os.clock() - STUCK_SECONDS
			end)
		else
			if request.path then request.path:Destroy() end
			self:_command(target, os.clock(), true)
		end
	end)
end

-- Callers own route/fight outcomes. Retries never teleport to a destination,
-- count an arrival, change combat HP or mint a new chicken.
function PetActor:Step(now: number): string
	if self.destroyed then return "destroyed" end
	local issue = self:RigIssue()
	local position = self:Position()
	if not issue and position.Y < self.safeFoot.Y - 12 then issue = "Fell below the route" end
	if issue then
		if not self:Recover(nil, issue, now) then
			self:_block(issue, now)
			return "blocked"
		end
		position = self:Position()
	end
	if now - self.healthAt >= HEALTH_INTERVAL then
		self.root.CanCollide = true
		local elapsed = now - self.healthAt
		if self.healthAt > 0 and flatDistance(position, self.healthPosition) > math.max(24, self.speed * (elapsed + 0.25) * 3) then
			self:Recover(nil, "Unexpected physics displacement", now)
			position = self:Position()
		end
		local safe = self:_safeGround(position)
		if safe then self.safeFoot = safe end
		self.healthAt, self.healthPosition = now, position
		-- These are physical glitches; combat death is the owner's Defeated flag.
		if self.humanoid.PlatformStand or self.humanoid.Sit then
			self.humanoid.PlatformStand, self.humanoid.Sit = false, false
			self.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
	if self.requestPending and now - self.pathRequest.startedAt >= PATH_TIMEOUT then
		self.requestGeneration += 1
		self:_cancelRequest()
		self.progressAt = now - STUCK_SECONDS
	end
	if self.state == "blocked" then
		if now < self.blockedUntil or not self.goal then return "blocked" end
		local goal, speed = self.goal, self.speed
		self:Stop()
		self:MoveTo(goal, speed)
	end
	if not self.goal then return self.state end
	if flatDistance(position, self.goal) <= ARRIVAL and math.abs(position.Y - self.goal.Y) < 3 then
		self:Stop()
		self.state = "arrived"
		return "arrived"
	end
	if self.waypoints then
		local waypoint = self.waypoints[self.waypointIndex]
		while waypoint and flatDistance(position, waypoint) <= ARRIVAL + 0.25 and math.abs(position.Y - waypoint.Y) < 3 do
			self.waypointIndex += 1
			waypoint = self.waypoints[self.waypointIndex]
			self.progressAt, self.progressPosition = now, position
		end
		if not waypoint then self:_clearPath() end
	end
	local target = if self.waypoints then self.waypoints[self.waypointIndex] else self.goal
	-- Sideways jitter/turning in circles is not progress toward the current leg.
	if target and flatDistance(position, target) < flatDistance(self.progressPosition, target) - 0.3 then
		self.progressAt, self.progressPosition = now, position
		self.recoveries = 0
	elseif now - self.progressAt >= STUCK_SECONDS then
		self:_recover(now)
	end
	if self.state == "blocked" then return "blocked" end
	if target then self:_command(target, now) end
	return "moving"
end

function PetActor:Destroy()
	if self.destroyed then return end
	self:Stop()
	self.destroyed = true
	self.requestGeneration += 1
	self.model:Destroy()
end

return PetActor
