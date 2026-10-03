local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local rng = Random.new()
local plr = game.Players.LocalPlayer
local cam = workspace.CurrentCamera

local worldModel: WorldModel = script.Parent.WorldModel
local sphereStorage: Folder = worldModel.PortalSpheres
local mainPortalSphere: MeshPart = worldModel.MainPortalSphere

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.FilterDescendantsInstances = {sphereStorage}

local sphereSpawnTime = 0.2
local spawnTimeVariance = 0.04
local sphereLifetime = 3
local lifetimeVariance = 0.5
local minDistance, maxDistance = 10, 18

local sizeEasing = Enum.EasingStyle.Quad
local sizeEasingDir = Enum.EasingDirection.In
local posEasing = Enum.EasingStyle.Quint
local posEasingDir = Enum.EasingDirection.Out

-- Spawn a single portal sphere and begin animating it
local function SpawnSphere()
	local newSphere = mainPortalSphere:Clone()
	newSphere.Parent = sphereStorage
	newSphere.Size *= 0.8
	
	-- Create both size and position tween for sphere and play them
	local randomPos = rng:NextUnitVector() * rng:NextNumber(minDistance, maxDistance)
	local tweenTime = sphereLifetime + rng:NextNumber(-lifetimeVariance, lifetimeVariance)
	local sizeTweenInfo = TweenInfo.new(tweenTime, sizeEasing, sizeEasingDir)
	local posTweenInfo = TweenInfo.new(tweenTime, posEasing, posEasingDir)
	local sizeTween = TweenService:Create(newSphere, sizeTweenInfo, {Size = Vector3.zero})
	local posTween = TweenService:Create(newSphere, posTweenInfo, {Position = randomPos + newSphere.Position})
	sizeTween:Play()
	posTween:Play()

	-- Destroy sphere once size tween has ended
	sizeTween.Completed:Once(function() newSphere:Destroy() end)
end

sphereStorage.Parent = workspace
task.wait()
sphereStorage.Parent = worldModel

local cameraPreviouslyInPortal = false
local currentTime = 0
local currentVariance = rng:NextNumber(-spawnTimeVariance, spawnTimeVariance)
RunService.RenderStepped:Connect(function(deltaTime: number)
	currentTime += deltaTime
	
	if currentTime >= sphereSpawnTime + currentVariance then
		-- Spawn a portal sphere
		SpawnSphere()
		
		currentTime = 0
		currentVariance = rng:NextNumber(-spawnTimeVariance, spawnTimeVariance)
	end
end)