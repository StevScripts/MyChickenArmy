local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local plr = game.Players.LocalPlayer
local playerGui = plr.PlayerGui

local ctrlHeld = false

-- Initialize ViewportFrame as a variable
local viewportName = script.Name:match("%u%l*%d*") .. "Viewport"
local houseFrame: ViewportFrame = plr.PlayerGui.MaskGui:FindFirstChild(viewportName)
while not houseFrame do
	houseFrame = plr.PlayerGui.MaskGui:FindFirstChild(viewportName)
	task.wait()
end

-- Hide a single object or its descendants
local function ToggleSelected(object: BasePart | Model | Folder, visible: boolean, hideButton: ImageButton)
	if object:IsA("BasePart") then
		-- If material is glass transparency should be 0.99 to decrease ViewportFrame light reflections
		if object.Material == Enum.Material.Glass then
			object.Transparency = if visible then 0.99 else 1
		else
			object.Transparency = if visible then 0 else 1
		end
	elseif object:IsA("Model") or object:IsA("Folder") then
		for _, desc in object:GetDescendants() do
			if desc:IsA("BasePart") then
				if desc.Material == Enum.Material.Glass then
					desc.Transparency = if visible then 0.99 else 1
				else
					desc.Transparency = if visible then 0 else 1
				end
			end
		end
	end
	
	hideButton.ImageLabel.Disabled.Visible = not visible
	hideButton:SetAttribute("Visible", visible)
end

-- When holding ctrl hide / show all except selected
local function ToggleAllExceptSelected(object: BasePart | Model | Folder, visible: boolean, hideButton: ImageButton)
	ToggleSelected(object, visible, hideButton)
	for _, child in object.Parent:GetChildren() do
		if child == object then
			continue
		end
		
		-- Skip if child doesn't have a hide button
		local hideChildButton = hideButton.Parent:FindFirstChild("Hide//" .. child.Name)
		if not hideChildButton then continue end
		
		-- If selected is visible then other objects are invisible
		ToggleSelected(child, not visible, hideChildButton)
	end
end

-- Connect hide buttons within House's actions frame
for _, guiObject in script.Parent:GetChildren() do
	if guiObject:IsA("ImageButton") and guiObject.Name:match("Hide") then
		guiObject.MouseButton1Click:Connect(function()
			local visible = guiObject:GetAttribute("Visible")
			
			local object = houseFrame:FindFirstChild(guiObject.Name:split("//")[2])
			if ctrlHeld then
				ToggleAllExceptSelected(object, not visible, guiObject)
			else
				ToggleSelected(object, not visible, guiObject)
			end
		end)
	end
end