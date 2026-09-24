--!strict
-- Flow the authored rainbow through feather UV islands. Eyes, beak, wattle
-- and legs stay byte-identical; a single live atlas is shared by all Riders.
local AssetService = game:GetService("AssetService")
local Rainbow = {}
Rainbow.__index = Rainbow

local FPS, CYCLE_SECONDS = 20, 6
local shared: any = {references = 0, generation = 0, state = "idle",
	image = nil, surface = nil, images = {}, groups = {}, pixels = nil, tick = -1}

local function releaseShared()
	shared.generation += 1
	if shared.surface then shared.surface:Destroy() end
	if shared.image then shared.image:Destroy() end
	for _, image in shared.images do image:Destroy() end
	shared.image, shared.surface, shared.pixels = nil, nil, nil
	shared.images, shared.groups = {}, {}
	shared.state, shared.error, shared.tick = "idle", nil, -1
end

local function beginLoad(base: SurfaceAppearance)
	if shared.state ~= "idle" then return end
	shared.state = "loading"
	local generation = shared.generation
	local function current()
		return generation == shared.generation and shared.references > 0
	end
	task.spawn(function()
		local image, surface
		local images = {}
		local ok, problem = pcall(function()
			image = AssetService:CreateEditableImageAsync(base.ColorMapContent)
			if not image then error("Rainbow image allocation unavailable") end
			if not current() then return end
			local size = image.Size
			-- The importer may resize the atlas. UV tiles remain a 16x16 grid
			-- with six faces per cuboid and a bottom-left Blender UV origin.
			if size.X ~= size.Y or size.X % 16 ~= 0 then error("Rainbow expects a square 16x16-tile atlas") end
			local width, cell = size.X, size.X / 16
			local pixels = image:ReadPixelsBuffer(Vector2.zero, size)
			local groups, byColor = {}, {}
			for _, cuboid in {0, 1, 2, 5, 11} do -- Body, Neck, Head, Wing_L, Wing_R.
				for face = 0, 5 do
					local tile = cuboid * 6 + face
					local x0 = (tile % 16) * cell
					local y0 = width - (math.floor(tile / 16) + 1) * cell
					for y = y0, y0 + cell - 1 do for x = x0, x0 + cell - 1 do
						local offset = (y * width + x) * 4
						local rgba = buffer.readu32(pixels, offset)
						local group = byColor[rgba]
						if not group then
							local c = Color3.fromRGB(buffer.readu8(pixels, offset),
								buffer.readu8(pixels, offset + 1), buffer.readu8(pixels, offset + 2))
							local h, s, v = c:ToHSV()
							group = {h = h, s = s, v = v, alpha = buffer.readu8(pixels, offset + 3), offsets = {}}
							byColor[rgba] = group
							table.insert(groups, group)
						end
						table.insert(group.offsets, offset)
					end end
				end
			end
			local content: any = {ColorMap = Content.fromObject(image)}
			for key, source in {NormalMap = base.NormalMapContent, RoughnessMap = base.RoughnessMapContent,
				MetalnessMap = base.MetalnessMapContent, EmissiveMask = base.EmissiveMaskContent} do
				if not current() then return end
				if source.SourceType ~= Enum.ContentSourceType.None then
					local channel = AssetService:CreateEditableImageAsync(source)
					if not channel then error("Rainbow PBR image allocation unavailable") end
					table.insert(images, channel)
					content[key] = Content.fromObject(channel)
				end
			end
			if not current() then return end
			surface = AssetService:CreateSurfaceAppearanceAsync(content)
			surface.Name = "RainbowAnimatedPBR"
			surface.AlphaMode, surface.Color = base.AlphaMode, base.Color
			surface.EmissiveStrength, surface.EmissiveTint = base.EmissiveStrength, base.EmissiveTint
			if not current() then return end
			shared.image, shared.surface, shared.images = image, surface, images
			shared.groups, shared.pixels, shared.state, shared.error = groups, pixels, "ready", nil
			image, surface, images = nil, nil, {}
		end)
		if surface then surface:Destroy() end
		if image then image:Destroy() end
		for _, channel in images do channel:Destroy() end
		if current() and not ok then shared.state, shared.error = "failed", tostring(problem) end
	end)
end

local function updateAtlas(now: number)
	local tick = math.floor(now * FPS)
	if shared.tick == tick then return end
	local phase = (tick % (FPS * CYCLE_SECONDS)) / (FPS * CYCLE_SECONDS)
	for _, group in shared.groups do
		local c = Color3.fromHSV((group.h + phase) % 1, group.s, group.v)
		local rgba = math.round(c.R * 255) + math.round(c.G * 255) * 256
			+ math.round(c.B * 255) * 65536 + group.alpha * 16777216
		for _, offset in group.offsets do buffer.writeu32(shared.pixels, offset, rgba) end
	end
	shared.image:WritePixelsBuffer(Vector2.zero, shared.image.Size, shared.pixels)
	shared.tick = tick
end

function Rainbow.new(model: Model)
	if model:GetAttribute("ChickenVisualV3") ~= true or model:GetAttribute("Appearance") ~= "Rainbow" then return nil end
	shared.references += 1
	return setmetatable({model = model, body = nil, baseSurface = nil, animatedSurface = nil,
		destroyed = false, state = "idle", error = nil, frame = 0}, Rainbow)
end

function Rainbow._restore(self: any)
	if self.animatedSurface then self.animatedSurface:Destroy(); self.animatedSurface = nil end
	if self.baseSurface then
		if self.baseSurface.Parent == nil then
			if self.body and self.body.Parent and not self.body:FindFirstChildOfClass("SurfaceAppearance") then
				self.baseSurface.Parent = self.body
			else self.baseSurface:Destroy() end
		end
		self.baseSurface = nil
	end
end

function Rainbow.Step(self: any, now: number, reduced: boolean, camera: Camera?)
	if self.destroyed then return end
	local model = self.model
	if not model.Parent or model:GetAttribute("Appearance") ~= "Rainbow" then self:Destroy(); return end
	local body, root = model:FindFirstChild("Body"), model.PrimaryPart
	if body ~= self.body then
		self:_restore()
		self.body = if body and body:IsA("MeshPart") then body else nil
	end
	if not self.body or not root then return end
	local visible = not reduced and model:GetAttribute("ReducedMotion") ~= true
		and model:GetAttribute("Defeated") ~= true and model:GetAttribute("PresentationHidden") ~= true
		and root.LocalTransparencyModifier < 0.5 and self.body.LocalTransparencyModifier < 0.5
		and self.body.Transparency < 0.98 and camera ~= nil
		and (camera.CFrame.Position - root.Position).Magnitude <= 110
	if not visible then
		self:_restore()
		self.state = if reduced or model:GetAttribute("ReducedMotion") == true then "reduced" else "hidden"
		return
	end
	local surface = self.body:FindFirstChildOfClass("SurfaceAppearance")
	if self.animatedSurface and surface ~= self.animatedSurface then
		self:_restore()
		surface = self.body:FindFirstChildOfClass("SurfaceAppearance")
	end
	if not surface then self.state = "no-material"; return end
	beginLoad(surface)
	self.state, self.error = shared.state, shared.error
	if shared.state ~= "ready" then self:_restore(); return end
	local ok, problem = pcall(updateAtlas, now)
	if not ok then
		shared.state, shared.error = "failed", tostring(problem)
		self.state, self.error = shared.state, shared.error
		self:_restore()
		return
	end
	if not self.animatedSurface then
		self.baseSurface = surface
		surface.Parent = nil
		self.animatedSurface = shared.surface:Clone()
		self.animatedSurface.Parent = self.body
	end
	self.frame = shared.tick % (FPS * CYCLE_SECONDS)
end

function Rainbow.Destroy(self: any)
	if self.destroyed then return end
	self:_restore()
	self.destroyed = true
	shared.references -= 1
	if shared.references == 0 then releaseShared() end
end

return Rainbow
