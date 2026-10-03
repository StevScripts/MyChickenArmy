-- Show TextLabel which tells that EditableImages aren't yet supported in game if game isn't being played in studio
if not game:GetService("RunService"):IsStudio() then
	script.Parent.NotSupported.Visible = true
	script.Parent.InputURL.Visible = false
	script.Parent.Size = UDim2.new(1, 0, 0, 38)
	return
end

local AssetService = game:GetService("AssetService")
local MarketplaceService = game:GetService("MarketplaceService")

local inputURLBox: TextBox = script.Parent.InputURL
local maskSurfaceAppearance: SurfaceAppearance = game:FindFirstChild("MaskImageSurfaceAppearance", true)

-- SurfaceAppearance's ColorMap has to be edited with EditableImages since it canno't be changed while game is running
local currentEditableImage: EditableImage = nil

-- Toggles URL warning symbol
local function ToggleURLWarningVisuals(state: "On" | "Off")
	if state == "On" then
		inputURLBox.Error.Visible = true
	elseif state == "Off" then
		inputURLBox.Error.Visible = false
	end
end

-- Sets mask image based on given asset URL
script.Parent.InputURL.FocusLost:Connect(function()
	-- Remove previous EditableImage
	if currentEditableImage then currentEditableImage:Remove() end
	
	-- Get asset info through MarketplaceService
	local text = inputURLBox.Text
	local assetId = tonumber((text:gsub("%D", "")))
	local success, info = pcall(function() return MarketplaceService:GetProductInfo(assetId) end)
	local typeId
	
	if not success then
		typeId = nil
	else
		typeId = info.AssetTypeId
	end

	-- Show error symbol if asset couldn't be fetched or AssetTypeID is faulty (not Image, Decal or Face)
	if not typeId or not (typeId == 1 or typeId == 13 or typeId == 18) then
		ToggleURLWarningVisuals("On")
		return
	else
		ToggleURLWarningVisuals("Off")
	end

	local maskImageID = "rbxassetid://" .. assetId
	local newEditableImage = AssetService:CreateEditableImageAsync(maskImageID)
	newEditableImage.Parent = maskSurfaceAppearance
	inputURLBox.Text = maskImageID
end)