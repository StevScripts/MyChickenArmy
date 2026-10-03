local RunService = game:GetService("RunService")

local rng = Random.new()
local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local cam = workspace.CurrentCamera

local hatch: Model = script.Parent.CrossHatch
local lines1: MeshPart, lines2: MeshPart = hatch:WaitForChild("HatchLines1"), hatch:WaitForChild("HatchLines2")

local distanceFromFocus = 6 -- Distance of model in studs from focus point
local maxDist = 3
local updateTime = 0.13 -- Time between each line position randomization

local currentTime = 0
RunService.RenderStepped:Connect(function(deltaTime)
	currentTime += deltaTime
	local distance = (cam.Focus.Position - cam.CFrame.Position).Magnitude
	
	if script.Parent:GetAttribute("UpdateCrossHatchPlane") == false then return end
	
	hatch:PivotTo(CFrame.new(cam.Focus.Position + cam.CFrame.LookVector * script.Parent:GetAttribute("PlaneDistance"), cam.CFrame.Position))
	hatch:ScaleTo(math.max((distance + distanceFromFocus) / 2, 0.01))
	
	if currentTime >= updateTime then
		local currentSizeMultiplier = hatch:GetScale()
		local x1 = lines1.CFrame.RightVector * rng:NextNumber(-maxDist, maxDist)
		local y1 =lines1.CFrame.LookVector * rng:NextNumber(-maxDist, maxDist)
		local x2 = lines2.CFrame.RightVector * rng:NextNumber(-maxDist, maxDist)
		local y2 =lines2.CFrame.LookVector * rng:NextNumber(-maxDist, maxDist)
		lines1.Position = hatch.WorldPivot.Position + (x1 + y1) * currentSizeMultiplier
		lines2.Position = hatch.WorldPivot.Position + (x2 + y2 - lines2.CFrame.UpVector * 0.001) * currentSizeMultiplier
		currentTime = 0
	end
end)