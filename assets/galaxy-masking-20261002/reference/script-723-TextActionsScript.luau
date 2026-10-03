local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local plr = game.Players.LocalPlayer
local playerGui = plr.PlayerGui

-- Hide others except toggle selected
local function HideOthersToggleSelected(object: Folder | StringValue, visible: boolean, hideButton: ImageButton, cube1: MeshPart, cube2: MeshPart)
	if visible == false then
		if object:IsA("StringValue") then
			cube1.TextureID = object.Value
			cube2.TextureID = object.Value
		elseif object:IsA("Folder") then
			for i = 1, 2 do
				local cube = if i == 1 then cube1 else cube2
				for _, child in object:GetChildren() do
					local newImage: Decal | Texture | SurfaceAppearance = child:Clone()
					if newImage:IsA("Texture") then
						newImage.StudsPerTileU = cube.Size.X
						newImage.StudsPerTileV = cube.Size.X
						newImage.OffsetStudsU = cube.Size.X / 2
						newImage.OffsetStudsV = cube.Size.X / 2
					end
					newImage.Parent = cube
				end
			end
		end
	end
	
	hideButton.ImageLabel.Disabled.Visible = visible
	hideButton:SetAttribute("Visible", not visible)
	
	for _, child in object.Parent:GetChildren() do
		if child == object then
			continue
		end

		-- Skip if child doesn't have a hide button
		local hideChildButton = hideButton.Parent:FindFirstChild("Hide//" .. child.Name)
		if not hideChildButton then continue end

		-- Hide other objects
		hideChildButton.ImageLabel.Disabled.Visible = true
		hideChildButton:SetAttribute("Visible", false)
	end
end

-- Connect hide buttons within House's actions frame
for _, guiObject in script.Parent:GetChildren() do
	if guiObject:IsA("ImageButton") and guiObject.Name:match("Hide") then
		guiObject.MouseButton1Click:Connect(function()
			local visible = guiObject:GetAttribute("Visible")
			local textFrame = playerGui.MaskGui:FindFirstChild("TextViewport")
			if not textFrame then return end
			
			-- Remove current images from mesh
			local cube1: MeshPart = textFrame.Cube1.CubeMask
			local cube2: MeshPart = textFrame.Cube2.CubeMask
			for _, child in cube1:GetChildren() do child:Remove() end
			for _, child in cube2:GetChildren() do child:Remove() end
			cube1.TextureID = ""
			cube2.TextureID = ""
			
			local object = textFrame.Clonables:FindFirstChild(guiObject.Name:split("//")[2])
			HideOthersToggleSelected(object, visible, guiObject, cube1, cube2)
		end)
	end
end