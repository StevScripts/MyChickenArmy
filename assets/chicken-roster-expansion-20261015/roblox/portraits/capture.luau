-- Edit-only portrait staging (Oct 15). Lays out up to 8 chickens on one camera plane at the
-- portrait angle of the Sept 25 Photobooth captures, in front of a far uniform backdrop.
-- Caller takes two viewport screenshots (black, then white backdrop) for difference matting.
local M = {}
local DIRECTION = Vector3.new(1.15, 0.55, 1.55).Unit
local ROTATION = CFrame.lookAt(Vector3.zero, -DIRECTION)
local STAGE = Vector3.new(0, 120, -4000)
local CELL, COLS, ROWS, FOV = 7.8, 4, 2, 20
function M.Setup(species)
	assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning())
	local RS = game.ReplicatedStorage
	local shared = RS.PetRoll:FindFirstChild("SharedPortrait_TEMP")
	if not shared then shared = RS.PetRoll.Shared:Clone(); shared.Name = "SharedPortrait_TEMP"; shared.Parent = RS.PetRoll end
	local PetView = require(shared.PetView)
	local stage = workspace:FindFirstChild("PortraitStage_TEMP")
	if stage then stage:Destroy() end
	stage = Instance.new("Folder"); stage.Name = "PortraitStage_TEMP"; stage.Parent = workspace
	local right, up = ROTATION.RightVector, ROTATION.UpVector
	local cells = {}
	for i, id in species do
		local model = PetView.Create(stage, "Portrait_" .. id, id, 1, STAGE + Vector3.new(0, 0, i * 40))
		for _, item in model:GetDescendants() do
			if item:IsA("BillboardGui") or item:IsA("SurfaceGui") then item:Destroy()
			elseif item:IsA("BasePart") then item.Anchored = true; item.CanQuery = false
				if item:IsA("MeshPart") then item.RenderFidelity = Enum.RenderFidelity.Precise end
			elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") then item.Enabled = false end
		end
		-- Centre the visual bounds (in camera space) on this chicken's grid cell.
		local min, max = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				for _, x in {-1, 1} do for _, y in {-1, 1} do for _, z in {-1, 1} do
					local p = ROTATION:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) * 0.5))
					min = min:Min(p); max = max:Max(p)
				end end end
			end
		end
		local center = ROTATION:PointToWorldSpace((min + max) / 2)
		local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
		local target = STAGE + right * ((col - (COLS - 1) / 2) * CELL) + up * (((ROWS - 1) / 2 - row) * CELL)
		model:PivotTo(model:GetPivot() + (target - center))
		cells[i] = {id = id, world = target}
	end
	local backdrop = Instance.new("Part"); backdrop.Name = "Backdrop"; backdrop.Anchored = true; backdrop.CastShadow = false
	backdrop.Material = Enum.Material.SmoothPlastic; backdrop.Size = Vector3.new(4000, 4000, 1)
	local back = STAGE - DIRECTION * 1500
	backdrop.CFrame = CFrame.lookAt(back, back + DIRECTION); backdrop.Color = Color3.new(0, 0, 0); backdrop.Parent = stage
	game:GetService("ContentProvider"):PreloadAsync(stage:GetChildren())
	local cam = workspace.CurrentCamera
	if not stage:GetAttribute("Saved") then
		stage:SetAttribute("Saved", true)
	end
	cam.CameraType = Enum.CameraType.Scriptable; cam.FieldOfView = FOV
	local vp = cam.ViewportSize
	local halfH = (ROWS * CELL / 2) * 1.12
	local halfW = (COLS * CELL / 2) * 1.06
	local h = math.max(halfH, halfW / (vp.X / vp.Y))
	local dist = h / math.tan(math.rad(FOV / 2))
	cam.CFrame = CFrame.lookAt(STAGE + DIRECTION * dist, STAGE); cam.Focus = CFrame.new(STAGE)
	local out = {viewport = {vp.X, vp.Y}, cells = {}}
	for i, c in cells do
		local p = cam:WorldToViewportPoint(c.world)
		local edge = cam:WorldToViewportPoint(c.world + right * (CELL / 2))
		out.cells[i] = {id = c.id, x = p.X, y = p.Y, half = (edge - p).Magnitude}
	end
	return game:GetService("HttpService"):JSONEncode(out)
end
function M.Backdrop(white)
	workspace.PortraitStage_TEMP.Backdrop.Color = if white then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
end
function M.Cleanup()
	local stage = workspace:FindFirstChild("PortraitStage_TEMP"); if stage then stage:Destroy() end
	local s = game.ReplicatedStorage.PetRoll:FindFirstChild("SharedPortrait_TEMP"); if s then s:Destroy() end
end
return M
