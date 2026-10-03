local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local plr = game.Players.LocalPlayer
local playerGui = plr.PlayerGui

-- Initialize ViewportFrame as a variable
local viewportName = script.Name:match("%u%l*%d*") .. "Viewport"
local wavyTextFrame: ViewportFrame = plr.PlayerGui.MaskGui:FindFirstChild(viewportName)
while not wavyTextFrame do
	wavyTextFrame = plr.PlayerGui.MaskGui:FindFirstChild(viewportName)
	task.wait()
end

-- Connect visibility toggle buttons
for _, guiObject in script.Parent:GetChildren() do
	if guiObject.Name:match("Hide") then
		guiObject.MouseButton1Click:Connect(function()
			local visible = guiObject:GetAttribute("Visible")
			guiObject.ImageLabel.Disabled.Visible = visible
			guiObject:SetAttribute("Visible", not visible)
			
			local objectsToToggle = {}
			if guiObject.Name:match("WavyTextMask") then
				objectsToToggle = {wavyTextFrame.WavyTextMask.WavyTextMesh}
			elseif guiObject.Name:match("Background") then
				local background = wavyTextFrame.Background
				objectsToToggle = {background, background.Decal}
			elseif guiObject.Name:match("BubbleClonable") then
				objectsToToggle = {wavyTextFrame.BubbleClonable.Decal}
			end
			
			for _, object: Decal | BasePart in objectsToToggle do
				object.Transparency = if visible then 1 else 0
			end
		end)
	end
end

-- Toggle text waving
local textWavingToggleButton: ImageButton = script.Parent.ToggleTextWaving
textWavingToggleButton.MouseButton1Click:Connect(function()
	local update = textWavingToggleButton:GetAttribute("Update")
	textWavingToggleButton.ImageLabel.Enabled.Visible = not update
	textWavingToggleButton:SetAttribute("Update", not update)
	wavyTextFrame:SetAttribute("UpdateTextWaving", not update)
end)