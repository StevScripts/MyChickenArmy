local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local playerGui = plr.PlayerGui
local mouse = plr:GetMouse()

local ctrlHeld = false
local mouse1DownOnSlider = false

-- Initialize ViewportFrame as a variable
local viewportName = script.Name:match("%u%l*%d*") .. "Viewport"
local characterFrame: ViewportFrame = plr.PlayerGui.MaskGui:FindFirstChild(viewportName)
while not characterFrame do
	characterFrame = plr.PlayerGui.MaskGui:FindFirstChild(viewportName)
	task.wait()
end

----------------------------------------------------------------------------
-- Toggle buttons ----------------------------------------------------------
----------------------------------------------------------------------------
-- Toggle house 1 mask visibility
local hideHouseMaskButton: ImageButton = script.Parent.HideHouse1Mask
hideHouseMaskButton.MouseButton1Click:Connect(function()
	local visible = hideHouseMaskButton:GetAttribute("Visible")
	hideHouseMaskButton.ImageLabel.Disabled.Visible = not visible
	hideHouseMaskButton:SetAttribute("Visible", not visible)

	local houseMask: Model = characterFrame.House1Mask
	for _, child in houseMask:GetChildren() do
		child.Transparency = if visible then 0 else 1
	end
end)

-- Toggle real player visibility
local hidePlayerButton: ImageButton = script.Parent.HidePlayer
hidePlayerButton.MouseButton1Click:Connect(function()
	local visible = hidePlayerButton:GetAttribute("Visible")
	hidePlayerButton.ImageLabel.Disabled.Visible = not visible
	hidePlayerButton:SetAttribute("Visible", not visible)

	for _, desc in char:GetDescendants() do
		if not (desc:IsA("BasePart") or desc:IsA("Texture") or desc:IsA("Decal")) then continue end
		
		if not desc:GetAttribute("OriginalTransparency") then
			desc:SetAttribute("OriginalTransparency", desc.Transparency)
		end
		
		desc.Transparency = if visible then desc:GetAttribute("OriginalTransparency") else 1
	end
end)

-- Toggle galaxy mask visibility
local hideGalaxyMaskButton: ImageButton = script.Parent.HideGalaxyMask
hideGalaxyMaskButton.MouseButton1Click:Connect(function()
	local visible = hideGalaxyMaskButton:GetAttribute("Visible")
	hideGalaxyMaskButton.ImageLabel.Disabled.Visible = not visible
	hideGalaxyMaskButton:SetAttribute("Visible", not visible)
	
	local galaxyMaskPlane = characterFrame.GalaxyMask
	local galaxy1, galaxy2 = galaxyMaskPlane.Galaxy1, galaxyMaskPlane.Galaxy2
	galaxy1.Transparency = if visible then 0 else 1
	galaxy2.Transparency = if visible then 0 else 1
end)

-- Toggle star mask visibility
local hideStarMaskButton: ImageButton = script.Parent.HideStarMask
hideStarMaskButton.MouseButton1Click:Connect(function()
	local visible = hideStarMaskButton:GetAttribute("Visible")
	hideStarMaskButton.ImageLabel.Disabled.Visible = not visible
	hideStarMaskButton:SetAttribute("Visible", not visible)

	local galaxyMaskPlane = characterFrame.GalaxyMask
	local stars1, stars2 = galaxyMaskPlane.Stars1, galaxyMaskPlane.Stars2
	stars1.Transparency = if visible then 0 else 1
	stars2.Transparency = if visible then 0 else 1
end)

-- Toggle cross hatch plane updating
local togglePlaneUpdatingButton: ImageButton = script.Parent.TogglePlaneUpdating
togglePlaneUpdatingButton.MouseButton1Click:Connect(function()
	local update = togglePlaneUpdatingButton:GetAttribute("Update")
	togglePlaneUpdatingButton.ImageLabel.Enabled.Visible = not update
	togglePlaneUpdatingButton:SetAttribute("Update", not update)
	characterFrame:SetAttribute("UpdateCrossHatchPlane", not update)
end)

----------------------------------------------------------------------------
-- User ID input -----------------------------------------------------------
----------------------------------------------------------------------------
local inputIDBox: TextBox = script.Parent.PlayerID.Input
local currentUserIDValue = game.ReplicatedStorage.CurrentUserIDNumber.Value
inputIDBox.Text = if currentUserIDValue == 0 then plr.UserId else currentUserIDValue
local changeCharacterEvent: RemoteEvent = game.ReplicatedStorage.Remotes.ChangeCharacterEvent
local players = game.Players

-- Toggles ID warning symbol
local function ToggleIDWarningVisuals(state: "On" | "Off")
	if state == "On" then
		inputIDBox.Error.Visible = true
	elseif state == "Off" then
		inputIDBox.Error.Visible = false
	end
end

-- Sets mask image based on given asset ID
inputIDBox.FocusLost:Connect(function()
	-- Check if user ID is valid
	local text = inputIDBox.Text
	local usedId = tonumber((text:gsub("%D", "")))
	local success = pcall(function()
		local character = players:CreateHumanoidModelFromUserId(usedId)
		if character then character:Destroy() end
	end)
	local typeId

	-- Show error symbol if given user ID is invalid
	if not success then
		ToggleIDWarningVisuals("On")
		return
	else
		ToggleIDWarningVisuals("Off")
	end
	
	changeCharacterEvent:FireServer(usedId)
end)

local resetCharacter: GuiButton = script.Parent.PlayerID.ResetCharacter
resetCharacter.MouseButton1Click:Connect(function()
	inputIDBox.Text = plr.UserId
	changeCharacterEvent:FireServer(plr.UserId)
end)

----------------------------------------------------------------------------
-- Slider ------------------------------------------------------------------
----------------------------------------------------------------------------
-- Connect slider for adjusting cross hatch plane's distance from head
local slider: ImageButton = script.Parent.PlaneDistance.Slider
local sliderValueText: TextLabel = slider.Parent.SliderValue
local sliderValueEnds = Vector2.new(-4, 6)
slider.MouseButton1Down:Connect(function()
	mouse1DownOnSlider = true

	-- Create a connection to check when slider is no longer held
	local sliderConnection: RBXScriptConnection
	sliderConnection = slider.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			mouse1DownOnSlider = false
			sliderConnection:Disconnect()
		end
	end)
end)

-- Adjust slider RenderStepped when mouse 1 holding started on slider
RunService.RenderStepped:Connect(function()
	if not mouse1DownOnSlider then return end

	local relativePos = Vector2.new(mouse.X, mouse.Y) - slider.AbsolutePosition
	local alpha = math.clamp(relativePos.X / slider.AbsoluteSize.X, 0, 1)
	local roundedValue = string.format("%.2f", sliderValueEnds.X + (sliderValueEnds.Y - sliderValueEnds.X) * alpha)

	-- Position slider selector and scale progress frame based on roundedValue
	slider.Selector.Position = UDim2.fromScale(alpha, 0.5)
	slider.Progress.Size = UDim2.fromScale(alpha, 1)

	-- Update text of TextBox connected to slider
	sliderValueText.Text = roundedValue

	if tonumber(sliderValueText.Text) == roundedValue then return end
	characterFrame:SetAttribute("PlaneDistance", roundedValue)
end)