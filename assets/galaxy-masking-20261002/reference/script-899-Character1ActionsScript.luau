local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local plr = game.Players.LocalPlayer
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

-- Toggle cross hatch plane updating
local togglePlaneUpdatingButton: ImageButton = script.Parent.TogglePlaneUpdating
togglePlaneUpdatingButton.MouseButton1Click:Connect(function()
	local update = togglePlaneUpdatingButton:GetAttribute("Update")
	togglePlaneUpdatingButton.ImageLabel.Enabled.Visible = not update
	togglePlaneUpdatingButton:SetAttribute("Update", not update)
	characterFrame:SetAttribute("UpdateCrossHatchPlane", not update)
end)

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