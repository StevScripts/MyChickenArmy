--!strict
-- Cosmetic-only V3 and imported dragon effects. DuckAnimator owns Step/Destroy; GlitchEditableMesh
-- consumes Glitch's local attributes. This module never moves/scales a rig.
-- Mutations (docs/team/launch/14_M1_MUTATIONS.md) layer a body tint plus a few
-- particles on top of the species art; menus reuse Special.Badge for their tag.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Assets = require(Shared.ChickenAppearanceAssets)
local Mutations = require(Shared.MutationCatalog)
local Theme = require(script.Parent.UITheme)
local GalaxyTextureAnimator = require(script.Parent.GalaxyTextureAnimator)
local RainbowTextureAnimator = require(script.Parent.RainbowTextureAnimator)
local Special = {}
Special.__index = Special

local CULL_DISTANCE = 110
local UPDATE_INTERVAL = 1 / 20
local GLITCH_PERIOD = 4.2
local texturesRequested = false

-- Mutation look. Tints multiply the authored color map, so the art stays readable.
-- Only this many mutated chickens run particles at once; the rest keep the tint.
local MAX_MUTATION_PARTICLES = 24
local TINT_SCAN_SECONDS = 1
local MUTATION_TINT: {[string]: Color3} = {
	Golden = Color3.fromRGB(255, 214, 112),
	Shadow = Color3.fromRGB(92, 78, 120),
	Cosmic = Color3.fromRGB(140, 150, 255),
}
local COSMIC_SHIMMER = Color3.fromRGB(205, 175, 255)
local RAINBOW_STILL = Color3.fromHSV(0.86, 0.36, 1)
local RAINBOW_SPARKLE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 92, 92)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 196, 64)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 255, 96)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 210, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(150, 110, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 104, 214)),
})
local activeMutationParticles = 0
-- Local player's own chickens by PetId, refreshed from each snapshot. The world
-- model's server "Mutation" attribute wins whenever it is present.
local ownedMutations: {[string]: string} = {}
local phases: {[string]: NumberValue} = {}

local function contentId(value: any): string?
	if type(value) == "number" then
		return if value > 0 then "rbxassetid://" .. tostring(value) else nil
	elseif type(value) == "string" and value ~= "" and value ~= "0" and value ~= "rbxassetid://0" then
		return if string.match(value, "^%d+$") then "rbxassetid://" .. value else value
	end
	return nil
end

local function preloadTextures()
	if texturesRequested then return end
	texturesRequested = true
	local ids = {}
	for _, value in Assets.Textures or {} do
		local id = contentId(value)
		if id then table.insert(ids, id) end
	end
	if #ids > 0 then task.spawn(function() pcall(function() ContentProvider:PreloadAsync(ids) end) end) end
end

local function phaseFor(name: string): number
	local value = 0
	for i = 1, #name do value = (value * 31 + string.byte(name, i)) % 10007 end
	return value / 10007 * GLITCH_PERIOD
end

local function scalarSequence(a: number, b: number, c: number): NumberSequence
	return NumberSequence.new({NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.35, b), NumberSequenceKeypoint.new(1, c)})
end

-- One shared looping phase per name. TweenService owns the motion; chickens only
-- read the value on their existing 20 Hz update.
local function phase(name: string, seconds: number): number
	local value = phases[name]
	if not value then
		value = Instance.new("NumberValue")
		value.Name = "MutationPhase_" .. name
		phases[name] = value
		TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Value = 1}):Play()
	end
	return value.Value
end

local function multiply(a: Color3, b: Color3): Color3
	return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B)
end

local function mutationOf(model: Model): string?
	local id = model:GetAttribute("Mutation")
	if Mutations.IsValid(id) then return id end
	if next(ownedMutations) == nil then return nil end
	local petId, owner = model:GetAttribute("PetId"), model:GetAttribute("OwnerUserId")
	local player = Players.LocalPlayer
	if type(petId) ~= "string" or not player or owner ~= player.UserId then return nil end
	return ownedMutations[petId]
end

-- AppController snapshots (via ChickenBrowser:Receive) keep this map current.
function Special.SetOwnedMutations(pets: any)
	table.clear(ownedMutations)
	for _, pet in if type(pets) == "table" then pets else {} do
		if type(pet) == "table" and type(pet.id) == "string" and Mutations.IsValid(pet.mutation) then
			ownedMutations[pet.id] = pet.mutation
		end
	end
end

-- A small rounded tag: the mutation name (or `text`) in the mutation's color.
-- Callers own Size/Position. Returns nil for no mutation.
function Special.Badge(parent: GuiObject, id: any, name: string?, text: string?): Frame?
	local def = Mutations.Get(id)
	if not def then return nil end
	local badge = Instance.new("Frame")
	badge.Name, badge.BorderSizePixel = name or "MutationBadge", 0
	badge.BackgroundColor3, badge.BackgroundTransparency = Color3.fromRGB(14, 12, 20), 0.05
	badge.ZIndex = parent.ZIndex + 8
	badge:SetAttribute("Mutation", def.name)
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(0.5, 0), badge
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness = def.color, 2
	stroke.ApplyStrokeMode, stroke.Parent = Enum.ApplyStrokeMode.Border, badge
	local caption = Theme.Label(badge, "MutationName", text or def.name, 20, def.color)
	caption.Position, caption.Size = UDim2.fromScale(0.07, 0.08), UDim2.fromScale(0.86, 0.84)
	caption.TextXAlignment, caption.TextWrapped = Enum.TextXAlignment.Center, false
	caption.ZIndex = badge.ZIndex + 1
	local outline = caption:FindFirstChild("TextOutline")
	if outline and outline:IsA("UIStroke") then outline.Color = Color3.new(0, 0, 0) end
	if id == "Rainbow" then
		caption.TextColor3 = Color3.new(1, 1, 1)
		local gradient = Instance.new("UIGradient")
		gradient.Color, gradient.Parent = RAINBOW_SPARKLE, caption
		local edge = Instance.new("UIGradient")
		edge.Color, edge.Parent = RAINBOW_SPARKLE, stroke
	end
	Theme.ScaleText(caption)
	badge.Parent = parent
	return badge
end

local function scaleSequence(sequence: NumberSequence, scale: number): NumberSequence
	local keys = {}
	for _, key in sequence.Keypoints do
		table.insert(keys, NumberSequenceKeypoint.new(key.Time, key.Value * scale, key.Envelope * scale))
	end
	return NumberSequence.new(keys)
end

function Special.new(model: Model, audio: any?)
	if model:GetAttribute("ChickenVisualV3") ~= true and model:GetAttribute("GalaxyDragonAnimation") ~= true then return nil end
	return setmetatable({model = model, audio = audio, sound = nil, appearance = nil, body = nil, root = nil,
		anchors = {}, emitters = {}, lights = {}, imported = {}, visible = false, destroyed = false,
		nextUpdate = 0, phase = phaseFor(model.Name), unit = 0, lastBurst = nil,
		galaxy = nil, rainbow = nil, ownsGlitch = false,
		mutation = nil, shells = {}, tints = {}, tintColor = nil, tintScanAt = 0,
		mutationParticles = false, budgeted = false, orbits = false}, Special)
end

function Special._glitch(self: any, scale: number, alpha: number, twitch: number)
	for name, value in {SpecialVisualScale = scale, SpecialGlitchAlpha = alpha, SpecialTwitch = twitch} do
		if self.model:GetAttribute(name) ~= value then self.model:SetAttribute(name, value) end
	end
end

-- Particle budget for mutated chickens (one slot per chicken, all its emitters).
function Special._budget(self: any, want: boolean)
	if want and not self.budgeted and activeMutationParticles < MAX_MUTATION_PARTICLES then
		activeMutationParticles += 1
		self.budgeted = true
	elseif not want and self.budgeted then
		activeMutationParticles -= 1
		self.budgeted = false
	end
end

-- Record every tintable surface once, with its authored color.
function Special._tintScan(self: any)
	for _, item in self.model:GetDescendants() do
		if self.tints[item] ~= nil then continue end
		local tintable = item:IsA("SurfaceAppearance")
			or (item:IsA("BasePart") and item ~= self.root and item.Transparency < 1
				and not item:FindFirstChildOfClass("SurfaceAppearance")
				and not (item:IsA("MeshPart") and item.TextureID ~= ""))
		if tintable then
			local ok, color = pcall(function() return (item :: any).Color end)
			if ok and typeof(color) == "Color3" then self.tints[item] = color end
		end
	end
end

function Special._tint(self: any, color: Color3?)
	for item, original in self.tints do
		local value = if color then multiply(original, color) else original
		pcall(function() (item :: any).Color = value end)
	end
	self.tintColor = color
end

function Special._clear(self: any)
	if self.sound then self.sound:Destroy();self.sound=nil end
	for _, effect in self.imported do
		if effect.Parent then
			effect.Enabled = false
			if effect:IsA("ParticleEmitter") or effect:IsA("Trail") then effect:Clear() end
		end
	end
	table.clear(self.imported)
	if self.galaxy then self.galaxy:Destroy(); self.galaxy = nil end
	if self.rainbow then self.rainbow:Destroy(); self.rainbow = nil end
	for _, anchor in self.anchors do anchor.instance:Destroy() end
	for _, shell in self.shells do shell:Destroy() end
	table.clear(self.anchors)
	table.clear(self.shells)
	table.clear(self.emitters)
	table.clear(self.lights)
	if self.ownsGlitch then self:_glitch(1, 0, 0) end
	-- Restore the authored colors, including surfaces another effect parked.
	self:_tint(nil)
	table.clear(self.tints)
	self:_budget(false)
	self.mutation, self.mutationParticles, self.orbits, self.tintScanAt = nil, false, false, 0
	self.body, self.root, self.appearance = nil, nil, nil
	self.visible, self.unit, self.lastBurst = false, 0, nil
end

function Special._anchor(self: any, name: string, boneName: string, offset: Vector3): Attachment
	local anchor = Instance.new("Attachment")
	anchor.Name = "SpecialVFX_" .. name
	anchor:SetAttribute("ChickenSpecialVFX", true)
	anchor.Parent = self.body
	local prefix = self.model:GetAttribute("BonePrefix")
	local importedName = (if type(prefix) == "string" then prefix else "") .. boneName
	local bone = self.body:FindFirstChild(importedName, true)
	table.insert(self.anchors, {instance = anchor, bone = if bone and bone:IsA("Bone") then bone else nil, offset = offset})
	return anchor
end

function Special._emitter(self: any, anchor: Instance, key: string, color: Color3 | ColorSequence, rate: number,
		lifetime: NumberRange, size: NumberSequence, speed: NumberRange, acceleration: Vector3,
		transparency: NumberSequence, light: number, mutation: boolean?): ParticleEmitter?
	local texture = contentId((Assets.Textures or {})[key])
	if not texture then return nil end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = (if mutation then "MutationVFX_" else "SpecialVFX_") .. key
	emitter:SetAttribute("ChickenSpecialVFX", true)
	emitter.Texture = texture
	emitter.Color = if typeof(color) == "ColorSequence" then (color :: any) else ColorSequence.new(color :: any)
	emitter.Rate, emitter.Lifetime = rate, lifetime
	emitter.Size, emitter.Speed, emitter.Acceleration = size, speed, acceleration
	emitter.Transparency = transparency
	emitter.LightEmission, emitter.LightInfluence = light, 0
	emitter.Brightness = if light > 0 then 1.5 else 1
	emitter.EmissionDirection, emitter.SpreadAngle = Enum.NormalId.Top, Vector2.new(35, 35)
	emitter.Orientation = Enum.ParticleOrientation.FacingCamera
	emitter.LockedToPart, emitter.VelocityInheritance = false, 0.15
	emitter.Rotation = if key == "Code" then NumberRange.new(0) else NumberRange.new(-180, 180)
	emitter.RotSpeed = if key == "Smoke" then NumberRange.new(-18, 18) else NumberRange.new(-7, 7)
	emitter.Enabled = false
	emitter.Parent = anchor
	table.insert(self.emitters, {instance = emitter, size = size, speed = speed, acceleration = acceleration,
		rate = rate, burst = if key == "Code" and not mutation then 7 else 0, mutation = mutation == true})
	if mutation then self.mutationParticles = true end
	return emitter
end

-- A mutation emitter spread over the body's own bounds (aura, twinkles).
function Special._shell(self: any, key: string, color: Color3, rate: number, lifetime: NumberRange,
		size: NumberSequence, speed: NumberRange, acceleration: Vector3, transparency: NumberSequence,
		light: number, locked: boolean)
	local emitter = self:_emitter(self.body, key, color, rate, lifetime, size, speed, acceleration, transparency, light, true)
	if not emitter then return end
	emitter.Shape, emitter.ShapeStyle = Enum.ParticleEmitterShape.Box, Enum.ParticleEmitterShapeStyle.Surface
	emitter.ShapeInOut, emitter.LockedToPart = Enum.ParticleEmitterShapeInOut.Outward, locked
	table.insert(self.shells, emitter)
end

function Special._attachMutation(self: any, id: string)
	self.mutation = id
	preloadTextures()
	self:_tintScan()
	self.tintScanAt = 0
	self:_tint(if id == "Rainbow" then RAINBOW_STILL else MUTATION_TINT[id])
	if id == "Golden" then
		for _, side in {-1, 1} do
			local anchor = self:_anchor("Mutation" .. side, "Body", Vector3.new(side * 0.85, 0.25, 0.15))
			self:_emitter(anchor, "Glitter", Color3.fromRGB(255, 226, 120), 3, NumberRange.new(0.7, 1.2),
				scalarSequence(0, 0.22, 0), NumberRange.new(0.25, 0.6), Vector3.new(0, 0.35, 0),
				scalarSequence(1, 0.05, 1), 0.9, true)
		end
	elseif id == "Rainbow" then
		for _, side in {-1, 1} do
			local anchor = self:_anchor("Mutation" .. side, "Body", Vector3.new(side * 0.85, 0.25, 0.15))
			self:_emitter(anchor, "Glitter", RAINBOW_SPARKLE, 4, NumberRange.new(0.7, 1.2),
				scalarSequence(0, 0.24, 0), NumberRange.new(0.3, 0.7), Vector3.new(0, 0.4, 0),
				scalarSequence(1, 0.05, 1), 0.9, true)
		end
	elseif id == "Shadow" then
		-- Thin purple-black aura hugging the body outline.
		self:_shell("Smoke", Color3.fromRGB(58, 20, 92), 9, NumberRange.new(0.7, 1.1),
			scalarSequence(0.25, 0.55, 0.8), NumberRange.new(0.15, 0.35), Vector3.new(0, 0.45, 0),
			scalarSequence(1, 0.62, 1), 0.15, false)
	elseif id == "Cosmic" then
		-- Starfield shimmer on the body plus two stars orbiting it.
		self:_shell("Star", Color3.fromRGB(214, 226, 255), 6, NumberRange.new(0.4, 0.8),
			scalarSequence(0, 0.12, 0), NumberRange.new(0), Vector3.zero,
			scalarSequence(1, 0.05, 1), 1, true)
		for index, start in {0, math.pi} do
			local anchor = self:_anchor("MutationOrbit" .. index, "Body", Vector3.zero)
			self.anchors[#self.anchors].orbit = {radius = 1.35, height = 0.45, start = start}
			self:_emitter(anchor, "Star", Color3.fromRGB(170, 205, 255), 9, NumberRange.new(0.45, 0.7),
				scalarSequence(0, 0.18, 0), NumberRange.new(0, 0.05), Vector3.zero,
				scalarSequence(1, 0.1, 1), 1, true)
		end
		self.orbits = true
	end
end

-- 20 Hz: pick up new surfaces, animate Rainbow/Cosmic tints only while the
-- chicken's effects are visible (static under reduced motion or at a distance)
-- and claim a particle slot when one frees up.
function Special._stepMutation(self: any, now: number, visible: boolean)
	local id = self.mutation
	local rescanned = false
	if now >= self.tintScanAt then
		self.tintScanAt = now + TINT_SCAN_SECONDS
		self:_tintScan()
		rescanned = true
	end
	local color = MUTATION_TINT[id]
	if id == "Rainbow" then
		color = if visible then Color3.fromHSV(phase("Rainbow", 6), 0.38, 1) else RAINBOW_STILL
	elseif id == "Cosmic" and visible then
		color = MUTATION_TINT.Cosmic:Lerp(COSMIC_SHIMMER, (math.sin(phase("Cosmic", 2.6) * math.pi * 2) + 1) / 2)
	end
	if rescanned or color ~= self.tintColor then self:_tint(color) end
	if visible and self.mutationParticles and not self.budgeted then
		self:_budget(true)
		if self.budgeted then
			for _, record in self.emitters do
				if record.mutation then record.instance.Enabled = true end
			end
		end
	end
end

function Special._light(self: any, anchor: Attachment, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Name, light.Color = "SpecialVFX_RedGlow", Color3.fromRGB(255, 28, 24)
	light:SetAttribute("ChickenSpecialVFX", true)
	light.Brightness, light.Range, light.Shadows, light.Enabled = brightness, range, false, false
	light.Parent = anchor
	table.insert(self.lights, {instance = light, range = range})
end

function Special._attach(self: any, body: MeshPart, root: BasePart, appearance: string, mutation: string?)
	self.body, self.root, self.appearance = body, root, appearance
	for _, effect in self.model:GetDescendants() do
		if (effect:IsA("ParticleEmitter") or effect:IsA("Beam") or effect:IsA("Trail") or effect:IsA("Light"))
			and effect:GetAttribute("ImportedEffectEnabled") == true then
			table.insert(self.imported, effect)
		end
	end
	self.ownsGlitch = appearance == "Glitch"
	if self.ownsGlitch then self:_glitch(1, 0, 0) end
	-- Galaxy's image cache is acquired lazily only while this client can use it.
	if appearance == "Golden" or appearance == "Shadow" or appearance == "Galaxy" or appearance == "Glitch" then
		preloadTextures()
		for _, side in {-1, 1} do
			local anchor = self:_anchor(tostring(side), "Body", Vector3.new(side * 1.06, -0.28, 0.38))
			if appearance == "Golden" then
				self:_emitter(anchor, "Glitter", Color3.fromRGB(255, 229, 117), 4, NumberRange.new(0.65, 1.15),
					scalarSequence(0, 0.24, 0), NumberRange.new(0.35, 0.75), Vector3.new(0, 0.4, 0),
					scalarSequence(1, 0.06, 1), 0.85)
			elseif appearance == "Shadow" then
				self:_emitter(anchor, "Smoke", Color3.fromRGB(9, 9, 13), 7, NumberRange.new(1.2, 1.9),
					scalarSequence(0.5, 1.05, 1.5), NumberRange.new(0.55, 0.85), Vector3.new(0, 0.7, 0),
					scalarSequence(1, 0.48, 1), 0)
			elseif appearance == "Galaxy" then
				self:_emitter(anchor, "Star", Color3.fromRGB(154, 216, 255), 2, NumberRange.new(0.6, 1.1),
					scalarSequence(0, 0.14, 0), NumberRange.new(0.3, 0.7), Vector3.new(0, 0.1, 0),
					scalarSequence(1, 0.1, 1), 0.8)
			else
				self:_emitter(anchor, "Code", Color3.fromRGB(86, 255, 152), 2, NumberRange.new(0.45, 0.9),
					scalarSequence(0.18, 0.28, 0.1), NumberRange.new(0.9, 1.6), Vector3.new(side * 0.5, 0.4, 0),
					scalarSequence(0.15, 0.1, 1), 0.8)
			end
		end
	elseif appearance == "Robo" then
		self:_light(self:_anchor("Eyes", "FaceSocket", Vector3.zero), 0.7, 3)
		self:_light(self:_anchor("Core", "ChestSocket", Vector3.new(0, 0, -0.05)), 0.4, 2)
	end
	if mutation then self:_attachMutation(mutation) end
end

function Special._place(self: any)
	local body, root = self.body, self.root
	-- Imported mesh height follows permanent actor/merge growth. Reading it
	-- does not modify that server-owned scale or the clip player's Glitch pose.
	local unit = math.clamp(body.Size.Y / 4.29, 0.1, 4)
	if math.abs(unit - self.unit) > 0.001 then
		self.unit = unit
		for _, record in self.emitters do
			local emitter = record.instance
			emitter.Size = scaleSequence(record.size, unit)
			emitter.Speed = NumberRange.new(record.speed.Min * unit, record.speed.Max * unit)
			emitter.Acceleration = record.acceleration * unit
		end
		for _, record in self.lights do record.instance.Range = math.min(record.range * unit, 8) end
	end
	local orbit = if self.orbits then phase("Orbit", 3.2) * math.pi * 2 else 0
	for _, record in self.anchors do
		local bone = record.bone
		local center = if bone and bone:IsDescendantOf(body) then bone.TransformedWorldCFrame.Position else body.Position
		local offset = record.offset
		if record.orbit then
			local angle = orbit + record.orbit.start
			offset = Vector3.new(math.cos(angle) * record.orbit.radius, record.orbit.height, math.sin(angle) * record.orbit.radius)
		end
		local world = center + root.CFrame:VectorToWorldSpace(offset * unit)
		-- Neutral root orientation keeps rising smoke vertical despite bone axes.
		record.instance.CFrame = body.CFrame:ToObjectSpace(CFrame.new(world) * root.CFrame.Rotation)
	end
end

function Special._visible(self: any, visible: boolean)
	if visible == self.visible then return end
	self.visible = visible
	if self.mutationParticles then self:_budget(visible) end
	for _, effect in self.imported do
		if effect.Parent then
			effect.Enabled = visible
			if not visible and (effect:IsA("ParticleEmitter") or effect:IsA("Trail")) then effect:Clear() end
		end
	end
	for _, record in self.emitters do
		record.instance.Enabled = visible and (not record.mutation or self.budgeted)
		if not visible then record.instance:Clear() end
	end
	for _, record in self.lights do record.instance.Enabled = visible end
	if not visible then
		if self.ownsGlitch then self:_glitch(1, 0, 0) end
		self.lastBurst = nil
	end
end

function Special.Step(self: any, now: number, reduced: boolean, camera: Camera?, textureTier: string?, cullDistance: number?)
	if self.destroyed then return end
	local model = self.model
	if not model.Parent then self:Destroy(); return end
	local dragon = model:GetAttribute("GalaxyDragonAnimation") == true
	local body, root = model:FindFirstChild(if dragon then "DragonChickenMesh" else "Body"), model.PrimaryPart
	if not body or not body:IsA("MeshPart") or not root then self:_clear(); return end
	-- The dragon uses only its authored VFX; its native animation and material
	-- remain with their existing owners, without generated auras or textures.
	local appearance = if dragon then "" else model:GetAttribute("Appearance") or ""
	local mutation = mutationOf(model)
	if self.body ~= body or self.root ~= root or self.appearance ~= appearance or self.mutation ~= mutation then
		self:_clear()
		self:_attach(body, root, appearance, mutation)
	end
	local textureVisible = not reduced and model:GetAttribute("ReducedMotion") ~= true
		and model:GetAttribute("Defeated") ~= true and model:GetAttribute("PresentationHidden") ~= true
		and root.LocalTransparencyModifier < 0.5 and body.LocalTransparencyModifier < 0.5
		and body.Transparency < 0.98 and camera ~= nil
		and (camera.CFrame.Position - root.Position).Magnitude <= CULL_DISTANCE
	if appearance == "Galaxy" and textureTier ~= "static" and textureVisible then
		if not self.galaxy then self.galaxy = GalaxyTextureAnimator.new(model) end
	elseif self.galaxy then
		-- Destroy restores the authored material and releases the shared image
		-- cache once the last eligible Galaxy leaves, including quality changes.
		self.galaxy:Destroy()
		self.galaxy = nil
	end
	if self.galaxy then
		self.galaxy:Step(now, reduced, camera)
		self.galaxyState, self.galaxyError = self.galaxy.state, self.galaxy.error
		self.galaxyFrame, self.galaxyFrameCount = self.galaxy.frame, self.galaxy.frameCount
	elseif appearance == "Galaxy" then
		self.galaxyState = if textureTier == "static" then "static" else "hidden"
		self.galaxyError, self.galaxyFrame, self.galaxyFrameCount = nil, 0, 0
	end
	if appearance == "Rainbow" and textureTier ~= "static" and textureVisible then
		if not self.rainbow then self.rainbow = RainbowTextureAnimator.new(model) end
	elseif self.rainbow then self.rainbow:Destroy();self.rainbow=nil end
	if self.rainbow then self.rainbow:Step(now, reduced, camera) end
	-- Shared materials scroll at render cadence; particles and other effects keep
	-- their existing inexpensive 20 Hz updates.
	if now < self.nextUpdate then return end
	self.nextUpdate = now + UPDATE_INTERVAL
	local visible = not reduced and model:GetAttribute("ReducedMotion") ~= true
		and model:GetAttribute("Defeated") ~= true and model:GetAttribute("PresentationHidden") ~= true
		and root.LocalTransparencyModifier < 0.5
		-- Glitch's breakup owns a local alpha; do not mistake that alpha for
		-- respawn hiding. Its mesh controller separately checks external alpha.
		and (body.LocalTransparencyModifier < 0.5 or appearance == "Glitch")
		and body.Transparency < 0.98 and camera ~= nil
		-- Particles follow the graphics-quality distance; animated textures above keep 110.
		and (camera.CFrame.Position - root.Position).Magnitude <= (cullDistance or CULL_DISTANCE)
	if appearance == "Glitch" and model:GetAttribute("GlitchMeshStatus") ~= "ready" then visible = false end
	-- Only nearby visible VFX get spatial audio. Empty authored IDs are silent.
	if self.audio and not dragon then
		local audible=visible and (camera.CFrame.Position-root.Position).Magnitude<=42
		self.sound=self.audio:VFXLoop("VFX_"..appearance,if audible then body else nil,self.sound)
	end
	self:_visible(visible)
	if self.mutation then self:_stepMutation(now, visible) end
	if not visible then return end
	self:_place()
	if appearance == "Glitch" then
		local clock = now + self.phase
		local cycle, position = math.floor(clock / GLITCH_PERIOD), clock % GLITCH_PERIOD
		local jitter = math.floor(clock / 0.13)
		local breakup = if position >= 2.75 and position <= 3.25 then math.sin((position - 2.75) / 0.5 * math.pi) else 0
		local scale = math.clamp(1 + math.sin(jitter * 2.71) * 0.055 + breakup * 0.04, 0.9, 1.12)
		self:_glitch(scale, breakup * 0.78, math.sin(jitter * 5.11) * (0.045 + breakup * 0.08))
		if breakup > 0 and self.lastBurst ~= cycle then
			self.lastBurst = cycle
			if self.audio and (camera.CFrame.Position-root.Position).Magnitude<=42 then
				self.audio:Play("VFX_GlitchBurst",nil,{parent=body,noFallback=true,voiceKey="VFX_GlitchBurst",cooldown=0.2})
			end
			for _, record in self.emitters do if record.burst > 0 then record.instance:Emit(record.burst) end end
		end
	end
end

function Special.Destroy(self: any)
	if self.destroyed then return end
	self:_clear()
	self.destroyed = true
end

return Special
