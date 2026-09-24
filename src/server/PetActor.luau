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
local PetActor = {}
PetActor.__index = PetActor

local ACTORS, CHARACTERS = "DuckActors", "DuckPlayers"
-- Humanoid:MoveTo may finish about one stud from its target.
-- A smaller tolerance misclassifies successful arrivals as permanent stalls.
local ARRIVAL = Config.ActorArrivalDistance or 1.25
local STUCK_SECONDS = 2.2
local MAX_RECOVERIES = 2
local MAX_PATH_REQUESTS = 2
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
	return self.root.Position - Vector3.new(0, self.model:GetAttribute("FootOffset") or self.footOffset, 0)
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
	if self.destroyed or not finiteVector(foot) or speed ~= speed then return false end
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
		self.requestPending = false
		self.waypoints = nil
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
	self.requestPending, self.waypoints, self.goal = false, nil, nil
	self.state, self.speed, self.commandTarget = "idle", 0, nil
	self.humanoid:Move(Vector3.zero)
	self.humanoid.WalkSpeed = 0
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

function PetActor:_block(reason: string)
	self:Stop()
	self.state = "blocked"
	-- Retain the failed goal so repeatedly issuing the same command cannot
	-- quietly restart unlimited retries. A different trip may try again.
	self.goal = self.failedGoal
	self.model:SetAttribute("MovementBlocked", true)
	self.model:SetAttribute("MovementBlockReason", reason)
end

function PetActor:_recover(now: number)
	if self.requestPending or activePaths >= MAX_PATH_REQUESTS or not self.goal then return end
	if self.recoveries >= MAX_RECOVERIES then
		self.failedGoal = self.goal
		self:_block("No walkable route after two recovery attempts")
		return
	end
	self.recoveries += 1
	self.requestPending = true
	self.requestGeneration += 1
	local generation, target, origin = self.requestGeneration, self.goal, self:Position()
	self.progressAt, self.progressPosition = now, origin
	activePaths += 1
	-- A short-lived request only; no per-duck perpetual task or MoveToFinished wait.
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = math.max(self.root.Size.X, self.root.Size.Z) / 2 + 0.15,
			AgentHeight = math.max(2, self.model:GetAttribute("VisualHeight") or 4),
			AgentCanJump = false, AgentCanClimb = false, WaypointSpacing = 5,
		})
		local ok = pcall(function() path:ComputeAsync(origin, target) end)
		activePaths -= 1
		if self.destroyed or generation ~= self.requestGeneration then path:Destroy() return end
		self.requestPending = false
		self.progressAt, self.progressPosition = os.clock(), self:Position()
		if ok and path.Status == Enum.PathStatus.Success then
			local points = {}
			for _, waypoint in path:GetWaypoints() do
				if flatDistance(waypoint.Position, self:Position()) > ARRIVAL then table.insert(points, waypoint.Position) end
			end
			self.waypoints = if #points > 0 then points else nil
			self.waypointIndex = 1
			self:_command(if self.waypoints then self.waypoints[1] else target, os.clock(), true)
		else
			self.waypoints = nil
			self:_command(target, os.clock(), true)
		end
		path:Destroy()
	end)
end

-- Returns idle / moving / arrived / blocked. Callers decide route/fight outcomes;
-- a blocked actor never teleports, wins a fight remotely, or resets its HP.
function PetActor:Step(now: number): string
	if self.destroyed then return "destroyed" end
	if self.state == "blocked" then return "blocked" end
	if not self.goal then return self.state end
	local position = self:Position()
	if position.Y < self.goal.Y - 12 then
		self.failedGoal = self.goal
		self:_block("Chicken fell below the walkable route")
		return "blocked"
	end
	if flatDistance(position, self.goal) <= ARRIVAL and math.abs(position.Y - self.goal.Y) < 3 then
		self:Stop()
		self.state = "arrived"
		return "arrived"
	end
	if self.waypoints then
		local waypoint = self.waypoints[self.waypointIndex]
		if waypoint and flatDistance(position, waypoint) <= ARRIVAL + 0.25 then
			self.waypointIndex += 1
			if self.waypointIndex > #self.waypoints then self.waypoints = nil end
		end
	end
	if flatDistance(position, self.progressPosition) >= 0.3 then
		self.progressAt, self.progressPosition = now, position
	elseif now - self.progressAt >= STUCK_SECONDS then
		self:_recover(now)
	end
	if self.state == "blocked" then return "blocked" end
	local target = if self.waypoints then self.waypoints[self.waypointIndex] else self.goal
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
