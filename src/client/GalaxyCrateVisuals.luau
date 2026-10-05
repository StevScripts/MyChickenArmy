--!strict
-- Staged crate art opts in with GalaxyTextureMotion="DarkMatter". The uploaded
-- PBR atlas is immutable: only its upper-left feather UVs move across two tiles.
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GalaxyCrateVisuals = {}
GalaxyCrateVisuals.__index = GalaxyCrateVisuals
local caches: {[string]: any} = {}

local function apply(body: MeshPart, template: MeshPart)
	local size, pose, texture = body.Size, body.CFrame, body.TextureContent
	local preserved: {Instance} = {}
	for _, child in body:GetChildren() do
		if child:IsA("Bone") or child:IsA("SurfaceAppearance") then
			local item: Instance = child
			table.insert(preserved, item)
			item.Parent = nil
		end
	end
	local ok, problem = pcall(function() body:ApplyMesh(template) end)
	for _, child in preserved do child.Parent = body end
	body.Size, body.CFrame, body.TextureContent = size, pose, texture
	if not ok then error(problem, 0) end
	return true
end

local function collectUVs(mesh: EditableMesh)
	local moving: {[number]: Vector2} = {}
	local protected: {[number]: boolean} = {}
	for _, face in mesh:GetFaces() do
		local ids = mesh:GetFaceUVs(face)
		local midpoint = Vector2.zero
		for _, id in ids do midpoint += assert(mesh:GetUV(id), "Dark Matter face references a missing UV") end
		midpoint /= #ids
		for _, id in ids do
			if midpoint.Y < 0.5 then moving[id] = assert(mesh:GetUV(id)) else protected[id] = true end
		end
	end
	local count = 0
	for id, uv in moving do
		assert(not protected[id], "Dark Matter feathers share a UV with a protected detail")
		assert(uv.X > 0 and uv.X < 0.5 and uv.Y > 0 and uv.Y < 0.5,
			"Dark Matter feather UV exceeds the reserved upper-left atlas tile")
		count += 1
	end
	assert(count > 0, "No Dark Matter feather UVs found")
	return moving, count
end

local function release(cache: any)
	cache.references -= 1
	if cache.references > 0 then return end
	cache.generation += 1
	if cache.tween then cache.tween:Cancel(); cache.tween:Destroy(); cache.tween = nil end
	for _, name in {"phase", "display", "mesh"} do
		if cache[name] then cache[name]:Destroy(); cache[name] = nil end
	end
	cache.uvs = nil
	cache.state, cache.error, cache.uvCount, cache.updates = "idle", nil, 0, 0
	if caches[cache.meshId] == cache then caches[cache.meshId] = nil end
end

local function acquire(body: MeshPart)
	local meshId = body.MeshId
	local cache = caches[meshId]
	if cache then cache.references += 1; return cache end
	cache = {meshId = meshId, references = 1, generation = 0, state = "loading", updates = 0}
	caches[meshId] = cache
	local content = body.MeshContent
	local options = {CollisionFidelity = body.CollisionFidelity, RenderFidelity = body.RenderFidelity}
	local generation = cache.generation
	local function current() return cache.generation == generation and cache.references > 0 end
	task.spawn(function()
		local owned: {any} = {}
		local function own(value: any)
			assert(value, "Dark Matter mesh allocation unavailable")
			table.insert(owned, value)
			return value
		end
		local ok, problem = pcall(function()
			local mesh = own(AssetService:CreateEditableMeshAsync(content, {FixedSize = true}))
			if not current() then return false end
			assert(#mesh:GetVertices() >= 504 and #mesh:GetBones() == 18, "Unexpected Dark Matter chicken rig")
			local uvs, count = collectUVs(mesh)
			local display = own(AssetService:CreateMeshPartAsync(Content.fromObject(mesh), options))
			if not current() then return false end
			local phase = own(Instance.new("NumberValue"))
			local tween = own(TweenService:Create(phase,
				TweenInfo.new(8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Value = 0.5}))
			cache.mesh, cache.display, cache.uvs, cache.uvCount = mesh, display, uvs, count
			cache.phase, cache.tween, cache.state = phase, tween, "ready"
			table.clear(owned)
			tween:Play()
			return true
		end)
		for _, value in owned do value:Destroy() end
		if not ok and current() then cache.state, cache.error = "failed", tostring(problem) end
	end)
	return cache
end

local function restore(record: any)
	if not record.original then return end
	if record.body and record.body.Parent then
		local ok, problem = pcall(apply, record.body, record.original)
		if not ok then record.state, record.error = "failed", tostring(problem) end
	end
	record.original:Destroy()
	record.original = nil
end

local function deactivate(record: any)
	restore(record)
	if record.cache then release(record.cache); record.cache = nil end
end

function GalaxyCrateVisuals.new()
	local self = setmetatable({records = {}, connections = {}, reducedMotion = false, destroyed = false}, GalaxyCrateVisuals)
	local function discover(item: Instance)
		if item:IsA("Model") then self:Bind(item) end
	end
	for _, item in workspace:GetDescendants() do discover(item) end
	table.insert(self.connections, workspace.DescendantAdded:Connect(discover))
	table.insert(self.connections, RunService.RenderStepped:Connect(function() self:Step() end))
	return self
end

-- World-only discovery is separate from DuckAnimator: staged crate chickens
-- need neither DuckRig nor gameplay attributes to display their authored art.
function GalaxyCrateVisuals.Bind(self: any, model: Model)
	if self.destroyed or self.records[model] or model:GetAttribute("GalaxyTextureMotion") ~= "DarkMatter" then return end
	self.records[model] = {model = model, state = "idle"}
end

function GalaxyCrateVisuals.SetReducedMotion(self: any, reduced: boolean)
	self.reducedMotion = reduced == true
	if self.reducedMotion then
		for _, record in self.records do deactivate(record); record.state = "hidden" end
	end
end

function GalaxyCrateVisuals.Step(self: any)
	if self.destroyed then return end
	local camera = workspace.CurrentCamera :: Camera?
	local active: {[any]: boolean} = {}
	for model, record in self.records do
		if not model:IsDescendantOf(workspace) or model:GetAttribute("GalaxyTextureMotion") ~= "DarkMatter" then
			deactivate(record)
			self.records[model] = nil
			continue
		end
		local found = model:FindFirstChild("Body")
		local body = if found and found:IsA("MeshPart") then found else nil
		if body ~= record.body then
			deactivate(record)
			record.body, record.state, record.error = body, "idle", nil
		end
		if not body then record.state = "no-body"; continue end
		local root = model.PrimaryPart or body
		local visible = not self.reducedMotion and model:GetAttribute("ReducedMotion") ~= true
			and model:GetAttribute("Defeated") ~= true and model:GetAttribute("PresentationHidden") ~= true
			and root.LocalTransparencyModifier < 0.5 and body.LocalTransparencyModifier < 0.5
			and body.Transparency < 0.98 and camera ~= nil and (camera.CFrame.Position - root.Position).Magnitude <= 110
		if not visible then deactivate(record); record.state, record.error = "hidden", nil; continue end
		if not body:FindFirstChildOfClass("SurfaceAppearance") then
			deactivate(record); record.state = "no-material"; continue
		end
		if record.state == "failed" then continue end
		if not record.cache then
			if body.MeshId == "" then record.state = "no-source-mesh"; continue end
			record.cache = acquire(body)
		end
		local cache = record.cache
		record.state, record.error = cache.state, cache.error
		if cache.state ~= "ready" then
			if cache.state == "failed" then deactivate(record) else restore(record) end
			continue
		end
		if not record.original then
			local ok, problem = pcall(function()
				local original = body:Clone()
				assert(original, "Dark Matter source mesh cannot be preserved")
				original:ClearAllChildren()
				record.original = original
				apply(body, cache.display)
			end)
			if not ok then
				deactivate(record)
				record.state, record.error = "failed", tostring(problem)
				continue
			end
		end
		active[cache] = true
	end
	for cache in active do
		local ok, problem = pcall(function()
			-- UVs are not tweenable properties. Copy the one TweenService phase to
			-- each moving UV once per shared mesh, never alter images or vertices.
			local offset = Vector2.new(cache.phase.Value, 0)
			for id, uv in cache.uvs do cache.mesh:SetUV(id, uv + offset) end
			cache.updates += 1
		end)
		if not ok then
			local message = tostring(problem)
			cache.state, cache.error = "failed", message
			cache.tween:Cancel()
			for _, record in self.records do
				if record.cache == cache then
					deactivate(record)
					record.state, record.error = "failed", message
				end
			end
		end
	end
end

function GalaxyCrateVisuals.GetState(self: any, model: Model): any
	local record = self.records[model]
	if not record then return nil end
	local cache = record.cache
	return {state = record.state, error = record.error, meshId = if cache then cache.meshId else nil,
		references = if cache then cache.references else 0, updates = if cache then cache.updates else 0,
		movingUVs = if cache then cache.uvCount else 0, phase = if cache and cache.phase then cache.phase.Value else 0}
end

function GalaxyCrateVisuals.Destroy(self: any)
	if self.destroyed then return end
	self.destroyed = true
	for _, connection in self.connections do connection:Disconnect() end
	for _, record in self.records do deactivate(record) end
	table.clear(self.connections)
	table.clear(self.records)
end

return GalaxyCrateVisuals
