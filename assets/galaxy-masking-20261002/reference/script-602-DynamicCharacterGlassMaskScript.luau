-- This script converts the player's character into glass for masking in a ViewportFrame in the shape of the player
-- The glass parts render the 0 alpha planes behind them

if script.Parent.Parent ~= workspace then return end

local RunService = game:GetService("RunService")

local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local root: BasePart = char:WaitForChild("HumanoidRootPart")
local cam = workspace.CurrentCamera

local viewport: ViewportFrame = plr.PlayerGui.MaskGui:FindFirstChildWhichIsA("ViewportFrame")

-- If ViewportFrame wasn't found then wait for it to be added
while not viewport do
	viewport = plr.PlayerGui.MaskGui:FindFirstChildWhichIsA("ViewportFrame")
	task.wait()
end

-- Only run script if current example is Character2 example
if viewport.Name ~= "Character2Viewport" then return end

local worldModel: Folder = viewport.WorldModel

-- Clone character
char.Archivable = true
local newChar = char:Clone()
local newRoot: BasePart = newChar:WaitForChild("HumanoidRootPart")
newChar.Parent = worldModel

-- Convert all MeshParts in cloned character to glass for revealing mask to work
for _, desc in newChar:GetDescendants() do
	if desc:IsA("Clothing") or desc:IsA("ShirtGraphic") or desc:IsA("Decal") then desc:Destroy() continue end
	if not desc:IsA("MeshPart") then continue end

	desc.Color = Color3.new(1, 1, 1)
	desc.Material = Enum.Material.Glass
	desc.Transparency = 0.99

	-- Remove SurfaceAppearance
	for _, child in desc:GetChildren() do
		if child:IsA("SurfaceAppearance") then child:Destroy() end
	end
	desc.TextureID = ""

	originalPart = desc
end

local newMotor6DTable: {Motor6D} = {}
for _, desc in ipairs(newChar:GetDescendants()) do
	if desc:IsA("Motor6D") then
		table.insert(newMotor6DTable, desc)
	end
end

local mainMotor6DTable: {Motor6D} = {}
for _, desc in ipairs(char:GetDescendants()) do
	if desc:IsA("Motor6D") then
		table.insert(mainMotor6DTable, desc)
	end
end

-- Update cloned character's Motor6Ds to match real character's animations
RunService.RenderStepped:Connect(function()
	newRoot.CFrame = root.CFrame
	
	for i, newMotor6D: Motor6D in newMotor6DTable do
		local mainMotor6D = mainMotor6DTable[i]
		newMotor6D.C1 = mainMotor6D.C1 * mainMotor6D.Transform:Inverse()
	end
end)

local animateScript = newChar:WaitForChild("Animate", 2)
if animateScript then animateScript:Destroy() end