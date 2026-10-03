--!strict
-- One live image shared by every visible Galaxy. Keep its Content identity
-- stable; changing TextureID every frame causes texture-streaming gray flashes.
local AssetService = game:GetService("AssetService")
local Assets = require(game:GetService("ReplicatedStorage").PetRoll.Shared.ChickenAppearanceAssets)
local Galaxy = {}
Galaxy.__index = Galaxy

local MAX_FRAMES, MAX_EDGE = 24, 512
local shared = {references = 0, generation = 0, state = "idle", error = nil,
	image = nil, blendImage = nil, content = nil, size = nil, frames = {}, lastIndex = 0, lastUpdate = nil,
	surface = nil, surfaceImages = {}, surfaceState = "idle", surfaceError = nil}

local function contentId(value: any): string?
	if type(value) == "number" and value > 0 then return "rbxassetid://" .. tostring(value) end
	if type(value) == "string" and value ~= "" and value ~= "0" and value ~= "rbxassetid://0" then
		return if string.match(value, "^%d+$") then "rbxassetid://" .. value else value
	end
	return nil
end

local function releaseShared()
	shared.generation += 1
	if shared.surface then shared.surface:Destroy() end
	for _, image in shared.surfaceImages do image:Destroy() end
	shared.surface, shared.surfaceImages, shared.surfaceState, shared.surfaceError = nil, {}, "idle", nil
	if shared.image then shared.image:Destroy() end
	if shared.blendImage then shared.blendImage:Destroy() end
	shared.blendImage, shared.lastUpdate = nil, nil
	shared.image, shared.content, shared.size = nil, nil, nil
	table.clear(shared.frames)
	shared.lastIndex, shared.state, shared.error = 0, "idle", nil
end

local function beginLoad()
	if shared.state ~= "idle" then return end
	shared.state = "loading"
	shared.generation += 1
	local generation = shared.generation
	local function current(): boolean
		return shared.generation == generation and shared.references > 0
	end
	task.spawn(function()
		local frames, size = {}, nil
		local input, output, blendImage
		local ok, problem = pcall(function()
			local ids = Assets.GalaxyFrames or {}
			if #ids < 2 or #ids > MAX_FRAMES then error("Galaxy requires 2–24 atlas frames") end
			for _, rawId in ids do
				if not current() then return end
				local id = contentId(rawId)
				if not id then error("Invalid Galaxy atlas asset ID") end
				input = AssetService:CreateEditableImageAsync(Content.fromUri(id))
				if not current() then return end
				if not input then error("Galaxy image allocation unavailable or image budget exhausted") end
				local dimensions = input.Size
				if dimensions.X > MAX_EDGE or dimensions.Y > MAX_EDGE then error("Galaxy atlas exceeds 512px budget") end
				if size and dimensions ~= size then error("Galaxy atlas frame sizes differ") end
				size = dimensions
				frames[#frames + 1] = input:ReadPixelsBuffer(Vector2.zero, dimensions)
				-- Only one temporary editable allocation exists at a time. The
				-- retained frame is a plain RGBA buffer (24MiB maximum in total).
				input:Destroy()
				input = nil
			end
			if not current() then return end
			output = AssetService:CreateEditableImage({Size = size})
			if not output then error("Galaxy output image allocation unavailable") end
			blendImage = AssetService:CreateEditableImage({Size = size})
			if not blendImage then error("Galaxy blend image allocation unavailable") end
			output:WritePixelsBuffer(Vector2.zero, size, frames[1])
			if not current() then return end
			shared.image, shared.content, shared.size = output, Content.fromObject(output), size
			shared.blendImage, shared.lastUpdate = blendImage, nil
			shared.frames, shared.lastIndex, shared.state, shared.error = frames, 1, "ready", nil
			output, blendImage = nil, nil -- Shared cache now owns the allocations.
		end)
		if input then input:Destroy() end
		if output then output:Destroy() end
		if blendImage then blendImage:Destroy() end
		if not current() or not ok then table.clear(frames) end
		if current() and not ok then shared.state, shared.error = "failed", tostring(problem) end
	end)
end

-- PBR overrides MeshPart.TextureContent. Compile one shared animated material
-- after the frame cache is ready, retaining its images until the last user exits.
local function beginSurfaceLoad(base: SurfaceAppearance)
	if shared.surfaceState ~= "idle" then return end
	shared.surfaceState = "loading"
	local generation = shared.generation
	local function current(): boolean
		return generation == shared.generation and shared.references > 0
	end
	task.spawn(function()
		local images, surface = {}, nil
		local ok, problem = pcall(function()
			local content = {ColorMap = shared.content}
			local channels = {RoughnessMap = base.RoughnessMapContent,
				MetalnessMap = base.MetalnessMapContent, NormalMap = base.NormalMapContent,
				EmissiveMask = base.EmissiveMaskContent}
			for key, source in channels do
				if not current() then return end
				if source.SourceType ~= Enum.ContentSourceType.None then
					local image = AssetService:CreateEditableImageAsync(source)
					if not image then error("Galaxy PBR image allocation unavailable") end
					table.insert(images, image)
					if not current() then return end
					content[key] = Content.fromObject(image)
				end
			end
			if not current() then return end
			surface = AssetService:CreateSurfaceAppearanceAsync(content)
			surface.Name = "GalaxyAnimatedPBR"
			surface.AlphaMode, surface.Color = base.AlphaMode, base.Color
			surface.EmissiveStrength, surface.EmissiveTint = base.EmissiveStrength, base.EmissiveTint
			if not current() then return end
			shared.surface, shared.surfaceImages, shared.surfaceState = surface, images, "ready"
			surface, images = nil, {} -- Shared cache owns both allocations.
		end)
		if surface then surface:Destroy() end
		for _, image in images do image:Destroy() end
		if current() and not ok then shared.surfaceState, shared.surfaceError = "failed", tostring(problem) end
	end)
end

function Galaxy.new(model: Model)
	if model:GetAttribute("ChickenVisualV3") ~= true or model:GetAttribute("Appearance") ~= "Galaxy" then return nil end
	shared.references += 1
	return setmetatable({model = model, body = nil, baseContent = nil, assigned = nil,
		baseSurface = nil, animatedSurface = nil,
		destroyed = false, state = "idle", error = nil, frame = 0, frameCount = 0}, Galaxy)
end

function Galaxy._restore(self: any)
	if self.animatedSurface then self.animatedSurface:Destroy(); self.animatedSurface = nil end
	if self.baseSurface then
		if self.baseSurface.Parent == nil then
			if self.body and self.body.Parent and not self.body:FindFirstChildOfClass("SurfaceAppearance") then
				self.baseSurface.Parent = self.body
			else
				-- The body was removed or another material writer took over.
				self.baseSurface:Destroy()
			end
		end
		self.baseSurface = nil
	end
	if self.body and self.assigned and self.body.TextureContent == self.assigned then
		self.body.TextureContent = self.baseContent
	end
	self.assigned = nil
end

function Galaxy.Step(self: any, now: number, reduced: boolean, camera: Camera?)
	if self.destroyed then return end
	local model = self.model
	if not model.Parent or model:GetAttribute("Appearance") ~= "Galaxy" then self:Destroy(); return end
	local body, root = model:FindFirstChild("Body"), model.PrimaryPart
	if body ~= self.body then
		self:_restore()
		self.body = if body and body:IsA("MeshPart") then body else nil
		self.baseContent = if self.body then self.body.TextureContent else nil
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
	beginLoad()
	self.state, self.error, self.frameCount = shared.state, shared.error, #shared.frames
	if shared.state ~= "ready" then self:_restore(); return end
	-- FPS describes the authored keys, not the display rate. Interpolate on
	-- DuckAnimator's existing RenderStepped clock without speeding up the loop.
	local fps = math.clamp(tonumber(Assets.GalaxyFPS) or 6, 1, 8)
	local position = (now * fps) % #shared.frames
	local index = math.floor(position) + 1
	local alpha = position % 1
	if now ~= shared.lastUpdate then
		local ok, problem = pcall(function()
			shared.image:WritePixelsBuffer(Vector2.zero, shared.size, shared.frames[index])
			if alpha > 0 then
				-- Native compositing avoids a 512x512 Luau pixel loop each frame.
				-- Reset the scratch image before multiplying its alpha so neither
				-- transparency nor previous blends accumulate. Authored atlases
				-- are opaque; source-over keeps the displayed result opaque too.
				shared.blendImage:WritePixelsBuffer(Vector2.zero, shared.size, shared.frames[index % #shared.frames + 1])
				shared.blendImage:DrawRectangle(Vector2.zero, shared.size, Color3.new(1, 1, 1),
					1 - alpha, Enum.ImageCombineType.Multiply)
				shared.image:DrawImage(Vector2.zero, shared.blendImage, Enum.ImageCombineType.BlendSourceOver)
			end
		end)
		if not ok then
			shared.state, shared.error = "failed", tostring(problem)
			self.state, self.error = shared.state, shared.error
			self:_restore()
			return
		end
		shared.lastIndex = index
		shared.lastUpdate = now -- All Galaxy instances share one composite per render frame.
	end
	local surface = self.body:FindFirstChildOfClass("SurfaceAppearance")
	if self.animatedSurface and surface ~= self.animatedSurface then self:_restore(); surface = self.body:FindFirstChildOfClass("SurfaceAppearance") end
	if surface then
		if not self.animatedSurface then
			beginSurfaceLoad(surface)
			self.state, self.error = shared.surfaceState, shared.surfaceError
			if shared.surfaceState ~= "ready" then return end -- Keep the static PBR on failure.
			self.baseSurface = surface
			surface.Parent = nil
			self.animatedSurface = shared.surface:Clone()
			self.animatedSurface.Parent = self.body
		end
	elseif self.body.TextureContent ~= shared.content then
		-- Preserve an external writer's new baseline when reclaiming this
		-- presentation, and restore only content this controller still owns.
		if self.assigned == nil or self.body.TextureContent ~= self.assigned then self.baseContent = self.body.TextureContent end
		self.body.TextureContent = shared.content
		self.assigned = shared.content
	end
	self.frame = index
end

function Galaxy.Destroy(self: any)
	if self.destroyed then return end
	self:_restore()
	self.destroyed = true
	shared.references -= 1
	if shared.references == 0 then releaseShared() end
end

return Galaxy
