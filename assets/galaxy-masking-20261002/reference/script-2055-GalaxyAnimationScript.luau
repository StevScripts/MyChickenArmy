local RunService = game:GetService("RunService")

local rng = Random.new()
local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local cam = workspace.CurrentCamera

local distanceFromFocus = 6 -- Distance of model in studs from focus point

local galaxyPlane: Model = script.Parent.GalaxyMask
local stars1: MeshPart, stars2: MeshPart = galaxyPlane:WaitForChild("Stars1"), galaxyPlane:WaitForChild("Stars2")
local galaxy1: MeshPart, galaxy2: MeshPart = galaxyPlane:WaitForChild("Galaxy1"), galaxyPlane:WaitForChild("Galaxy2")
local planes: {MeshPart} = {stars1, galaxy1, stars2, galaxy2}
local zOffset = {-0.002, -0.001, 0.001, 0.002}

-- Repositions plane attachments so that they loop
local function LoopPlanes()
	local origin = galaxyPlane.WorldPivot.Position
	for i, plane: MeshPart in planes do
		local size = planes[i].Size / 2
		local localOffset = plane.CFrame:VectorToObjectSpace(plane.Position - origin)
		local x, y = (localOffset.X + size.X / 2) % size.X - size.X / 2, (localOffset.Y + size.Y / 2) % size.Y - size.Y / 2
		local worldOffset = plane.CFrame:VectorToWorldSpace(Vector3.new(x, y, zOffset[i]))
		plane.Position = origin + worldOffset
	end
end

local currentTime = 0
RunService.RenderStepped:Connect(function(deltaTime)
	currentTime += deltaTime
	local distance = (cam.Focus.Position - cam.CFrame.Position).Magnitude
	
	if script.Parent:GetAttribute("UpdateCrossHatchPlane") == false then return end
	
	galaxyPlane:PivotTo(CFrame.new(cam.Focus.Position + cam.CFrame.LookVector * script.Parent:GetAttribute("PlaneDistance"), cam.CFrame.Position))
	galaxyPlane:ScaleTo(math.max((distance + distanceFromFocus) / 2, 0.01))
	local currentSizeMultiplier = galaxyPlane:GetScale()
	
	stars1.Position += stars1.CFrame.UpVector * deltaTime * currentSizeMultiplier * 0.4
	stars2.Position += stars2.CFrame.UpVector * deltaTime * currentSizeMultiplier * 0.2
	galaxy1.Position += galaxy1.CFrame.RightVector * deltaTime * currentSizeMultiplier * 0.08
	galaxy2.Position += galaxy2.CFrame.UpVector * deltaTime * currentSizeMultiplier * 0.05
	LoopPlanes()
end)