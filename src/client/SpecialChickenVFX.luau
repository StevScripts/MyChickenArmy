--!strict
-- Cosmetic-only V3 and imported dragon effects. DuckAnimator owns Step/Destroy; GlitchEditableMesh
-- consumes Glitch's local attributes. This module never moves/scales a rig.
local ContentProvider = game:GetService("ContentProvider")
local Assets = require(game:GetService("ReplicatedStorage").PetRoll.Shared.ChickenAppearanceAssets)
local GalaxyTextureAnimator = require(script.Parent.GalaxyTextureAnimator)
local RainbowTextureAnimator = require(script.Parent.RainbowTextureAnimator)
local Special = {}
Special.__index = Special

local CULL_DISTANCE = 110
local UPDATE_INTERVAL = 1 / 20
local GLITCH_PERIOD = 4.2
local texturesRequested = false

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
		galaxy = nil, rainbow = nil, ownsGlitch = false}, Special)
end

function Special._glitch(self: any, scale: number, alpha: number, twitch: number)
	for name, value in {SpecialVisualScale = scale, SpecialGlitchAlpha = alpha, SpecialTwitch = twitch} do
		if self.model:GetAttribute(name) ~= value then self.model:SetAttribute(name, value) end
	end
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
	table.clear(self.anchors)
	table.clear(self.emitters)
	table.clear(self.lights)
	if self.ownsGlitch then self:_glitch(1, 0, 0) end
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

function Special._emitter(self: any, anchor: Attachment, key: string, color: Color3, rate: number,
		lifetime: NumberRange, size: NumberSequence, speed: NumberRange, acceleration: Vector3,
		transparency: NumberSequence, light: number)
	local texture = contentId((Assets.Textures or {})[key])
	if not texture then return end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "SpecialVFX_" .. key
	emitter:SetAttribute("ChickenSpecialVFX", true)
	emitter.Texture, emitter.Color = texture, ColorSequence.new(color)
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
		rate = rate, burst = if key == "Code" then 7 else 0})
end

function Special._light(self: any, anchor: Attachment, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Name, light.Color = "SpecialVFX_RedGlow", Color3.fromRGB(255, 28, 24)
	light:SetAttribute("ChickenSpecialVFX", true)
	light.Brightness, light.Range, light.Shadows, light.Enabled = brightness, range, false, false
	light.Parent = anchor
	table.insert(self.lights, {instance = light, range = range})
end

function Special._attach(self: any, body: MeshPart, root: BasePart, appearance: string)
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
	for _, record in self.anchors do
		local bone = record.bone
		local center = if bone and bone:IsDescendantOf(body) then bone.TransformedWorldCFrame.Position else body.Position
		local world = center + root.CFrame:VectorToWorldSpace(record.offset * unit)
		-- Neutral root orientation keeps rising smoke vertical despite bone axes.
		record.instance.CFrame = body.CFrame:ToObjectSpace(CFrame.new(world) * root.CFrame.Rotation)
	end
end

function Special._visible(self: any, visible: boolean)
	if visible == self.visible then return end
	self.visible = visible
	for _, effect in self.imported do
		if effect.Parent then
			effect.Enabled = visible
			if not visible and (effect:IsA("ParticleEmitter") or effect:IsA("Trail")) then effect:Clear() end
		end
	end
	for _, record in self.emitters do
		record.instance.Enabled = visible
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
	if self.body ~= body or self.root ~= root or self.appearance ~= appearance then
		self:_clear()
		self:_attach(body, root, appearance)
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
