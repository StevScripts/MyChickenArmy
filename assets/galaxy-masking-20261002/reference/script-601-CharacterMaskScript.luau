-- This script creates 0 alpha meshes for each body part of the custom StarterCharacter

local RunService = game:GetService("RunService")

local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local cam = workspace.CurrentCamera

local viewport: ViewportFrame = plr.PlayerGui.MaskGui:FindFirstChildWhichIsA("ViewportFrame")

-- If ViewportFrame wasn't found then wait for it to be added
while not viewport do
	viewport = plr.PlayerGui.MaskGui:FindFirstChildWhichIsA("ViewportFrame")
	task.wait()
end

-- Only run script for examples which require it
if not viewport:GetAttribute("UseCharacterMask") or viewport.Name == "Character2Viewport" then return end

local useGlassCharMask: boolean = viewport:GetAttribute("UseGlassCharacterMask")

local maskStorage = viewport.CharacterMaskMeshes
local maskClonables = game.ReplicatedStorage.CharacterMaskClonables

-- Normal variants of 0 alpha character meshes
local limbMask: MeshPart = maskClonables.LimbNormal
local torsoMask: MeshPart = maskClonables.TorsoNormal
local headMask: MeshPart = maskClonables.HeadNormal

-- Create table for storing each character mask mesh
local maskMeshes = {}
for _, child in char:GetChildren() do
	if not child:IsA("BasePart") then continue end
	
	local newMesh, originalPart
	if child.Name:match("Head") then
		-- Use normal character meshes for house example
		newMesh = headMask:Clone()
	elseif child.Name:match("Torso") then
		newMesh = torsoMask:Clone()
	elseif child.Name:match("Leg") or child.Name:match("Arm") then
		newMesh = limbMask:Clone()
	else
		continue
	end

	newMesh.CFrame = child.CFrame
	newMesh.Color = child.Color
	newMesh.Material = if useGlassCharMask then Enum.Material.Glass else child.Material
	newMesh.Transparency = if useGlassCharMask then 0.99 else 0
	newMesh.Parent = maskStorage
	
	originalPart = child
	maskMeshes[#maskMeshes + 1] = {newMesh, originalPart}
end

-- When parenting these meshes under a ViewportFrame straight away their movement is delayed
-- Not sure what causes it but parenting to workspace and then back to the frame seems to fix it
maskStorage.Parent = workspace
task.wait()
maskStorage.Parent = viewport

-- Update each characters mesh's CFrame each frame to original part
RunService.RenderStepped:Connect(function()
	for _, meshInfo in maskMeshes do
		meshInfo[1].CFrame = meshInfo[2].CFrame
	end
end)