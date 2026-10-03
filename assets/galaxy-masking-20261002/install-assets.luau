-- Run through Studio Flow in canonical Edit mode only. Rebuilds this feature's
-- four inert mesh templates without importing or executing third-party scripts.
assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning())
local root = game.ReplicatedStorage.PetRoll
assert(not root:FindFirstChild("GalaxyViewportAssets"), "Inspect existing assets instead of replacing them")
local folder = Instance.new("Folder")
folder.Name = "GalaxyViewportAssets"
local assets = {
	{"Stars1", 17754155715, 17745916264, Vector3.new(16, 34, 0.001)},
	{"Stars2", 17754156768, 17745916264, Vector3.new(22, 48, 0.001)},
	{"Galaxy1", 17754152946, 17746433819, Vector3.new(12, 12, 0.001)},
	{"Galaxy2", 17754154181, 17746794246, Vector3.new(18, 18, 0.001)},
}
local ok, problem = pcall(function()
	for _, asset in assets do
		local part = game:GetService("AssetService"):CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. asset[2]))
		part.Name, part.Size = asset[1], asset[4]
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
		part.Transparency, part.TextureID, part.DoubleSided = 0, "", false
		part.Color, part.Material = Color3.new(1, 1, 1), Enum.Material.SmoothPlastic
		part.Parent = folder
		local surface = Instance.new("SurfaceAppearance")
		surface.ColorMap, surface.AlphaMode = "rbxassetid://" .. asset[3], Enum.AlphaMode.Transparency
		surface.Parent = part
	end
end)
if not ok then folder:Destroy(); error(problem) end
folder:SetAttribute("Source", "6mikael6 ViewportFrame Masking tutorial 2964839")
folder.Parent = root
return folder:GetFullName()
