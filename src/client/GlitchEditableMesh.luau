--!strict
-- Local vertex deformation only. The existing clip adapter still owns every
-- Bone.Transform, and the server retains the physical shell/combat state.
local AssetService = game:GetService("AssetService")
local GlitchMesh = {}
GlitchMesh.__index = GlitchMesh

local INTERVAL = 1 / 12
local MAX_VERTICES = 768 -- Includes UV-seam splits of the small cuboid model.
local CULL_DISTANCE = 110

local function numberAttribute(model: Model, name: string, default: number, low: number, high: number): number
	local value = model:GetAttribute(name)
	if type(value) ~= "number" or value ~= value then return default end
	return math.clamp(value, low, high)
end

local function sameAlpha(a: number, b: number?): boolean
	return b ~= nil and math.abs(a - b) < 0.00001
end

-- ApplyMesh changes mesh content/mesh bounds, texture and collision metadata.
-- Keep the current size/pose/texture and the SAME live Bone instances. This
-- synchronous section never yields, so an animation step cannot see no bones.
local function applyPreservingRig(body: MeshPart, source: MeshPart)
	local size, pose, texture = body.Size, body.CFrame, body.TextureContent
	local roots, originals = {}, {}
	for _, child in body:GetChildren() do
		if child:IsA("Bone") then
			table.insert(roots, child)
			originals[child] = true
			child.Parent = nil
		end
	end
	local ok, problem = pcall(function() body:ApplyMesh(source) end)
	-- ApplyMesh's documented copy set contains no hierarchy, but remove any
	-- generated root before returning the existing animation targets.
	for _, child in body:GetChildren() do
		if child:IsA("Bone") and not originals[child] then child:Destroy() end
	end
	for _, bone in roots do bone.Parent = body end
	body.Size, body.CFrame, body.TextureContent = size, pose, texture
	if not ok then error(problem, 0) end
end

function GlitchMesh.new(model: Model)
	if model:GetAttribute("ChickenVisualV3") ~= true or model:GetAttribute("Appearance") ~= "Glitch" then return nil end
	model:SetAttribute("GlitchMeshStatus", "waiting")
	model:SetAttribute("GlitchMeshError", nil)
	return setmetatable({model = model, body = nil, mesh = nil, original = nil, vertices = nil,
		attempted = false, loading = false, generation = 0, destroyed = false,
		nextUpdate = 0, deformed = false, lastAlpha = nil, externalAlpha = 0}, GlitchMesh)
end

function GlitchMesh._status(self: any, status: string, problem: any?)
	if self.destroyed then return end
	self.model:SetAttribute("GlitchMeshStatus", status)
	self.model:SetAttribute("GlitchMeshError", if problem then string.sub(tostring(problem), 1, 400) else nil)
end

function GlitchMesh._externalAlpha(self: any): number
	local body = self.body
	if not body then return 1 end
	local current = body.LocalTransparencyModifier
	if not sameAlpha(current, self.lastAlpha) then self.externalAlpha = current end
	return self.externalAlpha
end

function GlitchMesh._alpha(self: any, alpha: number)
	local body = self.body
	local value = math.max(self:_externalAlpha(), alpha)
	body.LocalTransparencyModifier = value
	self.lastAlpha = value
end

function GlitchMesh._restoreAlpha(self: any)
	local body = self.body
	if body and sameAlpha(body.LocalTransparencyModifier, self.lastAlpha) then
		body.LocalTransparencyModifier = self.externalAlpha
	end
	self.lastAlpha = nil
end

function GlitchMesh._reset(self: any)
	self:_restoreAlpha()
	if self.deformed and self.mesh and self.vertices then
		for _, vertex in self.vertices do self.mesh:SetPosition(vertex.id, vertex.position) end
	end
	self.deformed = false
end

function GlitchMesh._release(self: any)
	self.generation += 1 -- Invalidates every in-flight async allocation.
	self.loading = false
	self:_restoreAlpha()
	local body, mesh, original = self.body, self.mesh, self.original
	if mesh then
		local restored = not body or not body.Parent
		if body and original then restored = pcall(applyPreservingRig, body, original) end
		if restored then
			mesh:Destroy()
		else
			-- An unexpected restore failure must not replace a visible bird with
			-- an invalid mesh. Revert vertices and release on actual body removal.
			pcall(function() self:_reset() end)
			body.Destroying:Once(function() mesh:Destroy() end)
			warn("Glitch mesh restore deferred until body removal")
		end
	end
	if original then original:Destroy() end
	self.mesh, self.original, self.vertices = nil, nil, nil
	self.deformed, self.lastAlpha = false, nil
end

function GlitchMesh._start(self: any, body: MeshPart)
	self.attempted, self.loading = true, true
	self.generation += 1
	local generation = self.generation
	self:_status("loading")
	local function current(): boolean
		return not self.destroyed and self.generation == generation and self.model.Parent ~= nil
			and self.model:GetAttribute("ChickenVisualV3") == true and self.model:GetAttribute("Appearance") == "Glitch"
			and self.model:FindFirstChild("Body") == body and body.Parent ~= nil
	end
	task.spawn(function()
		local original, editable, display
		local swapped = false
		local ok, problem = pcall(function()
			-- Cosmetic mesh only: never regenerate a physical/query collider.
			if body.CanCollide or body.CanQuery or body.CanTouch then error("Glitch Body must be a non-colliding visual mesh") end
			original = body:Clone()
			if not original then error("Glitch Body is not archivable") end
			original:ClearAllChildren()
			editable = AssetService:CreateEditableMeshAsync(body.MeshContent, {FixedSize = true})
			if not current() then return end
			if not editable then error("EditableMesh allocation unavailable or client mesh budget exhausted") end
			local ids = editable:GetVertices()
			if #ids == 0 or #ids > MAX_VERTICES then error("Glitch mesh vertex count outside the bounded art budget: " .. #ids) end
			-- Creating from the original Content retains UVs, normals, bone bind
			-- poses and weights. Reject a stripped/unbound import rather than
			-- silently losing the normal walk/peck animation.
			local bones, liveBones = editable:GetBones(), {}
			for _, item in body:GetDescendants() do if item:IsA("Bone") then liveBones[item.Name] = item end end
			if #bones == 0 then error("Glitch editable mesh is missing embedded skinning bones") end
			for _, id in bones do
				local name = editable:GetBoneName(id)
				-- The importer appends an inert neutral_bone without a live Bone.
				-- Keep every authored animation/socket bone requirement intact.
				if name ~= "neutral_bone" and not liveBones[name] then
					error("Glitch embedded bone has no live animation target: " .. name)
				end
			end
			local vertices, weighted, requiredBones = {}, 0, {}
			local minimum, maximum = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
			for _, id in ids do
				local position = editable:GetPosition(id)
				minimum = minimum:Min(position)
				maximum = maximum:Max(position)
				local vertexBones, weights = editable:GetVertexBones(id), editable:GetVertexBoneWeights(id)
				local hasWeight = false
				for index, boneId in vertexBones do
					if (weights[index] or 0) > 0 then requiredBones[boneId], hasWeight = true, true end
				end
				if hasWeight then weighted += 1 end
				table.insert(vertices, table.freeze({id = id, position = position}))
			end
			if weighted == 0 then error("Glitch editable mesh has no vertex skinning weights") end
			for boneId in requiredBones do
				local name = editable:GetBoneName(boneId)
				if not liveBones[name] then error("Glitch weighted bone has no live animation target: " .. name) end
			end
			local center, extent = (minimum + maximum) / 2, maximum - minimum
			local foot = Vector3.new(center.X, minimum.Y, center.Z)
			display = AssetService:CreateMeshPartAsync(Content.fromObject(editable), {
				CollisionFidelity = body.CollisionFidelity, RenderFidelity = body.RenderFidelity,
			})
			if not current() then return end
			if not display then error("EditableMesh display allocation failed") end
			swapped = true
			applyPreservingRig(body, display)
			self.mesh, self.original = editable, original
			self.vertices, self.foot, self.extent = table.freeze(vertices), foot, extent
			self.externalAlpha = body.LocalTransparencyModifier
			self.loading = false
			self:_status("ready")
			-- Ownership transfers to the controller. The temporary display can
			-- go; Body.MeshContent retains the EditableMesh object reference.
			editable, original = nil, nil
		end)
		if display then display:Destroy() end
		if not ok and swapped and original and body.Parent then pcall(applyPreservingRig, body, original) end
		if editable then editable:Destroy() end
		if original then original:Destroy() end
		if current() and not ok then
			self.loading = false
			self:_status("failed", problem)
		end
	end)
end

function GlitchMesh._deform(self: any, now: number)
	local model, mesh = self.model, self.mesh
	local scale = numberAttribute(model, "SpecialVisualScale", 1, 0.9, 1.12)
	local twitch = numberAttribute(model, "SpecialTwitch", 0, -0.14, 0.14)
	local alpha = numberAttribute(model, "SpecialGlitchAlpha", 0, 0, 0.8)
	local tick = math.floor(now * 12)
	local snap = tick % 6 == 0
	if snap then scale, twitch = 1, 0 end
	local height, width = math.max(self.extent.Y, 0.01), math.max(self.extent.X, 0.01)
	for _, vertex in self.vertices do
		local position = vertex.position
		local level = math.clamp((position.Y - self.foot.Y) / height, 0, 1)
		local slice = math.floor(level * 7.99)
		local shift = math.sin(slice * 2.2 + tick * 1.7) * twitch * width * 0.55
		-- Keep the soles in place. Every frame starts from immutable imported
		-- positions, so glitches cannot accumulate drift or damage the model.
		local point = self.foot + (position - self.foot) * scale + Vector3.new(shift * math.min(level * 5, 1), 0, 0)
		mesh:SetPosition(vertex.id, point)
	end
	self.deformed = not snap
	self:_alpha(alpha)
end

function GlitchMesh.Step(self: any, now: number, reduced: boolean, camera: Camera?)
	if self.destroyed or now < self.nextUpdate then return end
	self.nextUpdate = now + INTERVAL
	local model = self.model
	if not model.Parent or model:GetAttribute("Appearance") ~= "Glitch" then self:Destroy(); return end
	local body, root = model:FindFirstChild("Body"), model.PrimaryPart
	if body ~= self.body then
		self:_release()
		self.body, self.attempted = body, false
	end
	if not body or not body:IsA("MeshPart") or not root then return end
	local quiet = reduced or model:GetAttribute("ReducedMotion") == true
	local visible = not quiet and model:GetAttribute("Defeated") ~= true
		and model:GetAttribute("PresentationHidden") ~= true and root.LocalTransparencyModifier < 0.5
		and self:_externalAlpha() < 0.5 and body.Transparency < 0.98
		and camera ~= nil and (camera.CFrame.Position - root.Position).Magnitude <= CULL_DISTANCE
	if not visible then
		if self.mesh then
			local ok, problem = pcall(function() self:_reset() end)
			if not ok then self:_release(); self:_status("failed", problem); return end
		end
		if quiet and model:GetAttribute("GlitchMeshStatus") ~= "failed" then self:_status("reduced") end
		return
	end
	if not self.attempted then self:_start(body); return end
	if not self.mesh then return end
	self:_status("ready")
	local ok, problem = pcall(function() self:_deform(now) end)
	if not ok then self:_release(); self:_status("failed", problem) end
end

function GlitchMesh.Destroy(self: any)
	if self.destroyed then return end
	self:_release()
	self.model:SetAttribute("GlitchMeshStatus", nil)
	self.model:SetAttribute("GlitchMeshError", nil)
	self.destroyed = true
end

return GlitchMesh
