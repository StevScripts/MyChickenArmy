-- Edit-mode checks against the synced module using a disposable source clone.
-- Does not move or modify the authored source map, run Play, or access profiles.
local PhysicsService = game:GetService("PhysicsService")
local source = workspace:FindFirstChild("MyChickenArmyMap")
assert(source and not game:GetService("RunService"):IsRunning(), "Run in Edit with the authored map present")
local hadScenery = PhysicsService:IsCollisionGroupRegistered("DuckScenery")
local oldPair = hadScenery and PhysicsService:CollisionGroupsAreCollidable("DuckActors", "DuckScenery")
local sourceClone = source:Clone()
local runtime, fixture
local result
local ok, failure = xpcall(function()
	local before = {}
	for _, part in sourceClone:GetDescendants() do
		if part:IsA("BasePart") then
			local index = #before + 1
			part:SetAttribute("CollisionCheckIndex", index)
			before[index] = {collide = part.CanCollide, touch = part.CanTouch, query = part.CanQuery,
				group = part.CollisionGroup, size = part.Size, frame = part.CFrame}
		end
	end
	-- Exercise the production map loader without touching the source Workspace tree.
	local chunk = assert(loadstring(game.ServerStorage.PetRoll.AuthoredMap.Source))
	setfenv(chunk, setmetatable({workspace = {FindFirstChild = function(_, name)
		return if name == "MyChickenArmyMap" then sourceClone else nil
	end}}, {__index = getfenv()}))
	runtime = chunk().Instantiate()
	local counts = {parts = 0, scenery = 0, solidScenery = 0, walkSurfaces = 0, solidGround = 0}
	local fence
	for _, part in runtime:GetDescendants() do
		if part:IsA("BasePart") then
			counts.parts += 1
			local previous = assert(before[part:GetAttribute("CollisionCheckIndex")])
			assert(part.CanCollide == previous.collide and part.CanTouch == previous.touch
				and part.CanQuery == previous.query, "Collision flags changed")
			assert(part.Size == previous.size and part.CFrame == previous.frame, "Geometry changed")
			if part:GetAttribute("WalkSurface") or part:GetAttribute("PlotGround") then
				counts.walkSurfaces += 1
				assert(part.CollisionGroup == previous.group, "Ground group changed: " .. part:GetFullName())
			end
			if part.CollisionGroup == "DuckScenery" then
				counts.scenery += 1
				if part.CanCollide then counts.solidScenery += 1 end
				if part.Name == "FenceSection3" then fence = part end
			elseif part.CanCollide then counts.solidGround += 1 end
		end
	end
	assert(counts.parts == #before and counts.solidScenery > 1000 and counts.walkSurfaces >= 61)
	assert(counts.solidGround >= 77, "Ground/support coverage incomplete")
	assert(not PhysicsService:CollisionGroupsAreCollidable("DuckActors", "DuckScenery"))
	assert(PhysicsService:CollisionGroupsAreCollidable("DuckPlayers", "DuckScenery"))
	assert(PhysicsService:CollisionGroupsAreCollidable("Default", "DuckScenery"))
	assert(PhysicsService:CollisionGroupsAreCollidable("DuckActors", "Default"))
	assert(workspace.Terrain.CollisionGroup == "Default")
	fixture = Instance.new("Folder")
	fixture.Name = "ChickenCollisionQueryCheck"
	local floor = runtime.Plot1.Deck:Clone()
	floor.Size, floor.CFrame, floor.Parent = Vector3.new(12, 1, 12), CFrame.new(2400, 100, 2400), fixture
	local prop = assert(fence):Clone()
	prop.Size, prop.CFrame, prop.Parent = Vector3.new(4, 4, 4), CFrame.new(2400, 103, 2400), fixture
	assert(prop.CollisionGroup == "DuckScenery", "Runtime prop clone lost its group")
	fixture.Parent = workspace
	local ray = RaycastParams.new()
	ray.FilterType, ray.FilterDescendantsInstances = Enum.RaycastFilterType.Include, {fixture}
	ray.RespectCanCollide, ray.CollisionGroup = true, "DuckActors"
	local chickenHit = workspace:Raycast(Vector3.new(2400, 110, 2400), Vector3.new(0, -20, 0), ray)
	assert(chickenHit and chickenHit.Instance == floor, "Chicken ground query hit a prop or missed floor")
	ray.CollisionGroup = "DuckPlayers"
	local playerHit = workspace:Raycast(Vector3.new(2400, 110, 2400), Vector3.new(0, -20, 0), ray)
	assert(playerHit and playerHit.Instance == prop, "Player no longer sees the solid prop")
	local overlap = OverlapParams.new()
	overlap.FilterType, overlap.FilterDescendantsInstances = Enum.RaycastFilterType.Include, {fixture}
	overlap.RespectCanCollide, overlap.CollisionGroup = true, "DuckActors"
	assert(#workspace:GetPartBoundsInBox(prop.CFrame, Vector3.one, overlap) == 0, "Chicken clearance blocked by prop")
	overlap.CollisionGroup = "DuckPlayers"
	assert(#workspace:GetPartBoundsInBox(prop.CFrame, Vector3.one, overlap) == 1, "Player clearance changed")
	-- Reported recruit point above the roller: clone just its vertical query column.
	local recruit = Vector3.new(342.345, 4.792, -192.024)
	local shift = Vector3.new(3000, 0, 3000)
	local recruitFixture = Instance.new("Folder")
	recruitFixture.Name, recruitFixture.Parent = "RecruitColumn", fixture
	for _, part in runtime:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide then
			local half = part.Size / 2
			local cf = part.CFrame
			local extentX = math.abs(cf.RightVector.X) * half.X + math.abs(cf.UpVector.X) * half.Y + math.abs(cf.LookVector.X) * half.Z
			local extentZ = math.abs(cf.RightVector.Z) * half.X + math.abs(cf.UpVector.Z) * half.Y + math.abs(cf.LookVector.Z) * half.Z
			if math.abs(part.Position.X - recruit.X) <= extentX + 1 and math.abs(part.Position.Z - recruit.Z) <= extentZ + 1 then
				local copy = part:Clone()
				copy:SetAttribute("OriginalQueryPath", part:GetFullName())
				copy.CFrame, copy.Anchored, copy.Parent = cf + shift, true, recruitFixture
			end
		end
	end
	ray.FilterDescendantsInstances, ray.CollisionGroup = {recruitFixture}, "DuckActors"
	local recruitGround = workspace:Raycast(recruit + shift + Vector3.yAxis * 2, -Vector3.yAxis * 12, ray)
	assert(recruitGround and recruitGround.Instance.Name == "Deck", "Recruit chicken query did not reach Deck")
	ray.CollisionGroup = "DuckPlayers"
	local recruitObstacle = workspace:Raycast(recruit + shift + Vector3.yAxis * 2, -Vector3.yAxis * 12, ray)
	assert(recruitObstacle and recruitObstacle.Instance.CollisionGroup == "DuckScenery", "Recruit player query lost the prop")
	assert(source.Parent == workspace, "Authored map was moved")
	for _, part in source:GetDescendants() do
		if part:IsA("BasePart") then
			assert(part.CollisionGroup ~= "DuckScenery" and part:GetAttribute("CollisionCheckIndex") == nil,
				"Authored source was modified")
		end
	end
	result = {passed = true, counts = counts, chickenRay = chickenHit.Instance.Name,
		playerRay = playerHit.Instance.Name, playerCollisionPreserved = true,
		clearanceQueriesPassed = true, originalMapPreserved = true, runtimePropClonePassed = true,
		recruitGround = recruitGround.Instance:GetAttribute("OriginalQueryPath"), recruitGroundY = recruitGround.Position.Y,
		recruitPlayerObstacle = recruitObstacle.Instance:GetAttribute("OriginalQueryPath")}
end, debug.traceback)
if fixture then fixture:Destroy() end
if runtime then runtime:Destroy() end
sourceClone:Destroy()
if hadScenery then PhysicsService:CollisionGroupSetCollidable("DuckActors", "DuckScenery", oldPair)
else PhysicsService:UnregisterCollisionGroup("DuckScenery") end
assert(ok, failure)
return result
