--!strict
-- Run on a playing server. All fixtures are disposable and outside the map.
-- This suite never grants rewards, edits profiles, or moves live characters.
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Server = game:GetService("ServerStorage").PetRoll
local Catalog = require(Shared.PetCatalog)
local PetView = require(Shared.PetView)
local PetActor = require(Server.PetActor)
local Checks = {}

local function horizontal(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function Checks.Run()
	assert(RunService:IsServer() and RunService:IsRunning(), "LiveRigChecks requires a playing server")
	local started = os.clock()
	local origin = Vector3.new(1800, 120, 1800)
	local folder = Instance.new("Folder")
	folder.Name = "LiveRigChecks_Temporary"
	folder:SetAttribute("DisposableTestFixture", true)
	folder.Parent = workspace
	local actors, results, metrics = {}, {}, {species = {}, movement = {}}
	local function test(name, operation)
		local ok, why = xpcall(operation, debug.traceback)
		table.insert(results, {name = name, passed = ok, error = if ok then nil else tostring(why)})
	end
	local function part(name: string, size: Vector3, at: Vector3, collidable: boolean, group: string?)
		local item = Instance.new("Part")
		item.Name, item.Size, item.Position = name, size, at
		item.Anchored = true
		item.CanCollide, item.CanTouch, item.CanQuery = collidable, false, false
		if group then item.CollisionGroup = group end
		item.Parent = folder
		return item
	end
	local function actor(name: string, species: string, foot: Vector3, facing: Vector3?)
		local value = PetActor.new(folder, name, species, 1, foot, facing)
		table.insert(actors, value)
		return value
	end
	local function travel(value, target: Vector3, speed: number, timeout: number, extraSample)
		local start = value:Position()
		local beginning, previousAt = os.clock(), os.clock()
		local previous = start
		local maximumStep, maximumAllowance, maxExcess = 0, 0, 0
		local state, sampleCount = "moving", 0
		assert(value:MoveTo(target, speed), "A new route was rejected")
		repeat
			task.wait(0.05)
			local now = os.clock()
			state = value:Step(now)
			local position = value:Position()
			local distance = horizontal(position, previous)
			-- Allow one stud for normal physics corrections, not a target teleport.
			local allowance = speed * (now - previousAt) * 1.8 + 1
			maximumStep = math.max(maximumStep, distance)
			maximumAllowance = math.max(maximumAllowance, allowance)
			maxExcess = math.max(maxExcess, distance - allowance)
			if extraSample then extraSample(position, now) end
			previous, previousAt = position, now
			sampleCount += 1
		until state == "arrived" or state == "blocked" or os.clock() - beginning >= timeout
		return {
			state = state, duration = os.clock() - beginning, moved = horizontal(start, value:Position()),
			remaining = horizontal(value:Position(), target), footY = value:Position().Y,
			maxStep = maximumStep, maxAllowedStep = maximumAllowance,
			maxTeleportExcess = maxExcess, samples = sampleCount,
			blocked = value.model:GetAttribute("MovementBlocked") == true,
			blockReason = value.model:GetAttribute("MovementBlockReason"),
		}
	end

	local fatalOK, fatalError = xpcall(function()
		part("IsolatedFloor", Vector3.new(160, 2, 180), origin + Vector3.new(0, -1, 35), true)
		local specimens = {}
		for index, species in Catalog.Order do
			test(species .. " creates one connected forward-facing Humanoid rig", function()
				local foot = origin + Vector3.new(-65 + ((index - 1) % 10) * 13, 0.05, -35 - math.floor((index - 1) / 10) * 10)
				local specimen = actor("Structure_" .. species, species, foot)
				specimens[species] = specimen
				local model, root = specimen.model, specimen.root
				local parts, colliders, motors, humanoids, animators = 0, 0, 0, 0, 0
				for _, item in model:GetDescendants() do
					assert(not item:IsA("LuaSourceContainer"), "Live ducks cannot contain per-pet scripts")
					if item:IsA("BasePart") then
						parts += 1
						assert(not item.Anchored, "Anchored duck part freezes the rig: " .. item.Name)
						if item.CanCollide then colliders += 1 assert(item == root, "Only HumanoidRootPart may collide") end
						if item ~= root then assert(item.Massless and not item.CanTouch and not item.CanQuery, "Cosmetic part affects physical/query behavior") end
					elseif item:IsA("Motor6D") then
						motors += 1
						assert(item.Part0 and item.Part1, "Animation joint is disconnected")
					elseif item:IsA("Humanoid") then humanoids += 1
					elseif item:IsA("Animator") then animators += 1 end
				end
				assert(model.PrimaryPart == root and root.Name == "HumanoidRootPart" and root.CanQuery, "Root selection contract failed")
				assert(colliders == 1 and humanoids == 1 and animators == 1 and motors == 6, "Unexpected collider/Humanoid/Animator/joint count")
				local connected={}
    for _,connectedPart in root:GetConnectedParts(true) do connected[connectedPart]=true end
    for _,item in model:GetDescendants() do if item:IsA("BasePart") then assert(item==root or connected[item], "Visible part disconnected: "..item.Name) end end
				assert(root:GetNetworkOwner() == nil, "Physics-sensitive duck is client-owned")
				assert(model:GetAttribute("DuckRig") == true and root:FindFirstChild("Tag"), "Rig discovery or billboard contract missing")
				local bill = model:FindFirstChild("Bill") :: BasePart
				local billDirection = Vector3.new(bill.Position.X - root.Position.X, 0, bill.Position.Z - root.Position.Z).Unit
				assert(billDirection:Dot(root.CFrame.LookVector) > 0.99, "Bill does not face root local -Z")
				local health = specimen.humanoid.Health
				PetView.Health(model, 0)
				assert(specimen.humanoid.Health == health and health > 0, "Combat display damaged the physical Humanoid")
				metrics.species[species] = {parts = parts, motors = motors, size = Catalog[species].size, billForwardDot = billDirection:Dot(root.CFrame.LookVector)}
			end)
		end
		task.wait(0.45)
		test("Every catalog rig settles with its feet on the floor", function()
			for species, specimen in specimens do
				local footY = specimen:Position().Y
				if metrics.species[species] then metrics.species[species].settledFootY = footY end
				assert(math.abs(footY - origin.Y) < 0.4, species .. " is floating or buried: footY=" .. tostring(footY))
			end
		end)

		local straight
		test("Humanoid travels 24 studs without teleporting or falsely blocking", function()
			straight = actor("StraightRoute", "Duck", origin + Vector3.new(-30, 0.05, 0), Vector3.xAxis)
			task.wait(0.25)
			local target = origin + Vector3.new(-6, 0, 0)
			local report = travel(straight, target, 8, 9)
			metrics.movement.straight = report
			assert(report.state == "arrived" and not report.blocked, "24-stud route did not arrive: " .. report.state)
			assert(report.moved >= 22.5 and report.remaining <= 1.5, "Route did not cover the expected actual distance")
			assert(report.maxTeleportExcess <= 0, "Duck teleported during normal movement")
			assert(math.abs(report.footY - origin.Y) < 0.4, "Moving duck lost ground contact")
			local root, bill = straight.root, straight.model:FindFirstChild("Bill") :: BasePart
			local billDirection = Vector3.new(bill.Position.X - root.Position.X, 0, bill.Position.Z - root.Position.Z).Unit
			report.travelFacingDot = billDirection:Dot(Vector3.xAxis)
			assert(report.travelFacingDot > 0.9, "Duck walks bill-backward on the actual route")
		end)

		local largest = Catalog.Order[1]
		for _, species in Catalog.Order do if Catalog[species].size > Catalog[largest].size then largest = species end end
		test("Largest duck crosses pond floor and noncolliding duck/player stand-ins", function()
			assert(not PhysicsService:CollisionGroupsAreCollidable("DuckActors", "DuckActors"), "Duck/duck collisions are enabled")
			assert(not PhysicsService:CollisionGroupsAreCollidable("DuckActors", "DuckPlayers"), "Duck/player collisions are enabled")
			assert(PhysicsService:CollisionGroupsAreCollidable("DuckActors", "Default"), "Ducks cannot stand on map geometry")
			local start = origin + Vector3.new(-30, 0.05, 25)
			local target = origin + Vector3.new(-6, 0.07, 25)
			local water = part("ShallowPondSurface", Vector3.new(28, 0.04, 10), origin + Vector3.new(-18, 0.05, 25), false)
			water.Transparency = 0.5
			part("DeploymentPad", Vector3.new(6, 0.07, 8), origin + Vector3.new(-6, 0.035, 25), true)
			-- This is a standalone collision probe, never a real player character.
			local standIn = part("PlayerCollisionStandIn", Vector3.new(1, 10, 7), origin + Vector3.new(-23, 5, 25), true, "DuckPlayers")
			local stationary = actor("StationaryDuckCollisionProbe", "Duck", origin + Vector3.new(-16, 0.05, 25))
			stationary:Stop()
			local walker = actor("LargestPondWalker", largest, start, Vector3.xAxis)
			task.wait(0.25)
			local nearestPlayer, nearestDuck = math.huge, math.huge
			local report = travel(walker, target, 8, 10, function(position)
				nearestPlayer = math.min(nearestPlayer, math.abs(position.X - standIn.Position.X))
				nearestDuck = math.min(nearestDuck, horizontal(position, stationary:Position()))
			end)
			report.species, report.nearestPlayerX, report.nearestDuck = largest, nearestPlayer, nearestDuck
			metrics.movement.pond = report
			assert(report.state == "arrived" and not report.blocked and report.remaining <= 1.5, "Largest duck failed the pond/pad route")
			assert(nearestPlayer < 1.5 and nearestDuck < 1.5, "Route did not exercise overlapping body collision probes")
			assert(report.maxTeleportExcess <= 0, "Largest duck teleported across the collision probes")
			assert(math.abs(report.footY - target.Y) < 0.4, "Largest duck floats or clips through deployment pad")
		end)

		test("Enclosed duck reports bounded failure without escaping or losing HP", function()
			local center = origin + Vector3.new(20, 0, 65)
			for _, sign in {-1, 1} do
				part("ClosedWallX" .. sign, Vector3.new(2, 12, 12), center + Vector3.new(sign * 5, 6, 0), true)
				part("ClosedWallZ" .. sign, Vector3.new(12, 12, 2), center + Vector3.new(0, 6, sign * 5), true)
			end
			local trapped = actor("EnclosedRoute", "Duck", center + Vector3.new(0, 0.05, 0), Vector3.xAxis)
			task.wait(0.35)
			local initialHP = trapped.humanoid.Health
			local maximumOutside = 0
			local target = center + Vector3.new(24, 0, 0)
			local report = travel(trapped, target, 8, 25, function(position)
				maximumOutside = math.max(maximumOutside, math.abs(position.X - center.X), math.abs(position.Z - center.Z))
			end)
			report.maximumFromCenter = maximumOutside
			metrics.movement.blocked = report
			assert(report.state == "blocked" and report.blocked, "Closed route did not fail within the bounded fixture timeout")
			assert(type(report.blockReason) == "string" and #report.blockReason > 0, "Blocked state has no readable failure reason")
			assert(maximumOutside < 4.5 and report.remaining > 18, "Actor escaped/teleported through the closed walls")
			assert(report.maxTeleportExcess <= 0, "Blocked actor teleported during recovery")
			assert(trapped.humanoid.Health == initialHP and initialHP > 0, "Route failure damaged the physical Humanoid")
			assert(trapped:MoveTo(target, 8) == false, "Same failed goal restarts unlimited recovery attempts")
			trapped:Stop()
			assert(trapped:Step(os.clock()) == "idle", "Stop did not cancel the blocked route")
			assert(trapped.model:GetAttribute("MovementBlocked") == false and trapped.model:GetAttribute("MovementBlockReason") == nil, "Stop retained stale failure presentation")
		end)

		test("Destroy removes actor models and can be called twice", function()
			for _, value in actors do
				local model = value.model
				value:Destroy()
				value:Destroy()
				assert(model.Parent == nil, "Destroyed actor retained its model")
				assert(value:Step(os.clock()) == "destroyed", "Destroyed actor accepts further simulation work")
			end
			for _, child in folder:GetChildren() do assert(not child:IsA("Model"), "An actor model leaked in the fixture") end
		end)
	end, debug.traceback)

	-- Cleanup runs even if factory construction, physics, or an assertion fails.
	for _, value in actors do pcall(function() value:Destroy() end) end
	folder:Destroy()
	if not fatalOK then table.insert(results, {name = "Live rig harness", passed = false, error = tostring(fatalError)}) end
	local passed = 0
	for _, result in results do if result.passed then passed += 1 end end
	metrics.duration = os.clock() - started
	metrics.fixtureRemoved = folder.Parent == nil
	return {passed = passed == #results, count = #results, passedCount = passed, results = results, metrics = metrics}
end

return Checks
