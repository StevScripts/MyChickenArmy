--!strict
-- Local fight feedback: voxel feather puffs, a comic hit spark, floating damage
-- numbers and knockout poofs, plus their sounds. Presentation only; the server's
-- battle snapshots decide every hit, knockout and number shown here.
-- October 21 (Stevin: "I only see the animations and no fighting vfx"): hits add a
-- neon impact flash, a slash streak and a spark burst; knockouts a big flash, a
-- ground shockwave and a star burst; lunges kick up dust. Sized to read from the
-- camera at a camp, not only up close.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.UITheme)

local INK = Color3.fromRGB(16, 23, 16)
local GOLD = Color3.fromRGB(255, 214, 64)
local HOT = Color3.fromRGB(255, 150, 40)
local FEATHER = Color3.new(1, 1, 1)
local FEATHER_WARM = Color3.fromRGB(236, 226, 204)
local DUST = Color3.fromRGB(214, 186, 140)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKS = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.35, GOLD), ColorSequenceKeypoint.new(1, HOT)})
-- Busy fights stay readable and cheap: extra effects are skipped, never queued.
local MAX_FEATHERS, MAX_NUMBERS, MAX_STRIKES, MAX_DUST = 90, 14, 10, 8

local Effects = {}
Effects.__index = Effects

function Effects.new(app, folder: Instance)
	return setmetatable({app = app, folder = folder, feathers = 0, numbers = 0, strikes = 0, dust = 0}, Effects)
end

-- A short-lived neon part for flashes and slashes; counted against MAX_STRIKES.
function Effects:Strike(name: string, shape: Enum.PartType, lifetime: number): Part?
	if self.app.reducedMotion or self.strikes >= MAX_STRIKES then return nil end
	self.strikes += 1
	task.delay(lifetime, function() self.strikes -= 1 end)
	local part = Instance.new("Part")
	part.Name, part.Shape, part.Material = name, shape, Enum.Material.Neon
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	Debris:AddItem(part, lifetime)
	return part
end

-- A bright ball pops at the point of impact and fades: the hit reads from afar.
function Effects:Flash(position: Vector3, size: number, color: Color3)
	local ball = self:Strike("HitFlash", Enum.PartType.Ball, 0.26)
	if not ball then return end
	ball.Size, ball.Position, ball.Color, ball.Transparency = Vector3.one * size * 0.3, position, color, 0
	ball.Parent = self.folder
	-- Pops to full size solid, then fades while it keeps swelling a little.
	TweenService:Create(ball, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.one * size * 0.85}):Play()
	TweenService:Create(ball, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.06),
		{Size = Vector3.one * size, Transparency = 1}):Play()
end

-- A white streak cuts across the victim, crossing the way it faces at a slant.
function Effects:Slash(position: Vector3, facing: Vector3, big: boolean)
	local slash = self:Strike("HitSlash", Enum.PartType.Block, 0.25)
	if not slash then return end
	local across = Vector3.new(-facing.Z, 0, facing.X)
	if across.Magnitude < 0.1 then across = Vector3.xAxis end
	local length = if big then 5.5 else 4.4
	-- Slanted 25–45° up or down so it reads as a cut, not a bar.
	slash.CFrame = CFrame.lookAt(position, position + across.Unit)
		* CFrame.Angles(math.rad(math.random(25, 45) * (if math.random() < 0.5 then -1 else 1)), 0, 0)
	slash.Size, slash.Color, slash.Transparency = Vector3.new(0.4, 0.4, length * 0.25), if big then GOLD else Color3.new(1, 1, 1), 0
	slash.Parent = self.folder
	TweenService:Create(slash, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(0.34, 0.34, length)}):Play()
	TweenService:Create(slash, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.06),
		{Size = Vector3.new(0.04, 0.04, length * 1.15), Transparency = 1}):Play()
end

-- Hot sparks spray out of the impact (the shared WorldFeel burst and budget).
function Effects:Sparks(position: Vector3, count: number, size: number)
	local feel = self.app.worldFeel
	if not feel then return end
	feel:Burst(position, {color = SPARKS, count = count, size = size, speed = {9, 16}, spread = 180,
		lifetime = {0.15, 0.32}, gravity = -30, light = 1})
end

-- A small dirt kick at the feet of a chicken that lunges.
function Effects:Dust(position: Vector3)
	if self.app.reducedMotion or self.dust >= MAX_DUST then return end
	self.dust += 1
	task.delay(0.7, function() self.dust -= 1 end)
	local attachment = Instance.new("Attachment")
	attachment.Parent = self:Anchor(position, 0.7)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture, emitter.Color, emitter.LightInfluence = SMOKE, ColorSequence.new(DUST), 0
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.4)})
	emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)})
	emitter.Lifetime, emitter.Speed = NumberRange.new(0.3, 0.5), NumberRange.new(2, 4)
	emitter.SpreadAngle, emitter.Drag, emitter.Rate = Vector2.new(70, 70), 5, 0
	emitter.EmissionDirection, emitter.Acceleration = Enum.NormalId.Top, Vector3.new(0, -2, 0)
	emitter.Parent = attachment
	emitter:Emit(5)
end

function Effects:Anchor(position: Vector3, lifetime: number): BasePart
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.Position = "CombatEffect", Vector3.one * 0.1, position
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, false, false, false
	anchor.Transparency, anchor.CastShadow = 1, false
	anchor.Parent = self.folder
	Debris:AddItem(anchor, lifetime)
	return anchor
end

-- Small white blocks burst out, then tumble down and fade.
function Effects:Feathers(position: Vector3, count: number, scale: number)
	if self.app.reducedMotion then return end
	count = math.min(count, MAX_FEATHERS - self.feathers)
	for index = 1, count do
		self.feathers += 1
		local feather = Instance.new("Part")
		feather.Name, feather.Size = "Feather", Vector3.new(0.42, 0.07, 0.2) * scale
		feather.Color = if index % 3 == 0 then FEATHER_WARM else FEATHER
		feather.Material = Enum.Material.SmoothPlastic
		feather.Anchored, feather.CanCollide, feather.CanTouch, feather.CanQuery, feather.CastShadow = true, false, false, false, false
		local spin = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		feather.CFrame = CFrame.new(position) * spin
		feather.Parent = self.folder
		local direction = Vector3.new(math.random() - 0.5, math.random() * 0.7 + 0.5, math.random() - 0.5).Unit
		local out = position + direction * (1.4 + math.random() * 1.3) * scale
		TweenService:Create(feather, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{CFrame = CFrame.new(out) * spin * CFrame.Angles(1.2, 0.6, 0)}):Play()
		local drift = out + Vector3.new((math.random() - 0.5) * 1.2, -1.8 * scale, (math.random() - 0.5) * 1.2)
		TweenService:Create(feather, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0.2),
			{CFrame = CFrame.new(drift) * spin * CFrame.Angles(3, 1.5, 0.8), Transparency = 1}):Play()
		Debris:AddItem(feather, 1)
		task.delay(1, function() self.feathers -= 1 end)
	end
end

-- A quick white-and-gold comic star at the point of impact.
function Effects:Spark(position: Vector3, big: boolean)
	if self.app.reducedMotion then return end
	local anchor = self:Anchor(position, 0.4)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(if big then 5.5 else 4, if big then 5.5 else 4)
	gui.LightInfluence, gui.Parent = 0, anchor
	local star = Instance.new("Frame")
	star.BackgroundTransparency, star.AnchorPoint = 1, Vector2.new(0.5, 0.5)
	star.Position, star.Size, star.Rotation = UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.4, 0.4), math.random(0, 45)
	star.Parent = gui
	for index = 0, 7 do
		local long = index % 2 == 0
		local ray = Instance.new("Frame")
		ray.BorderSizePixel, ray.BackgroundColor3 = 0, if long then Color3.new(1, 1, 1) else GOLD
		ray.AnchorPoint, ray.Position = Vector2.new(0.5, 1), UDim2.fromScale(0.5, 0.5)
		ray.Size, ray.Rotation = UDim2.fromScale(if long then 0.16 else 0.12, if long then 0.5 else 0.36), index * 45
		ray.Parent = star
		local stroke = Instance.new("UIStroke");stroke.Color, stroke.Thickness, stroke.Parent = INK, 1.5, ray
		TweenService:Create(ray, TweenInfo.new(0.14, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.12), {BackgroundTransparency = 1}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.14, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.12), {Transparency = 1}):Play()
	end
	TweenService:Create(star, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.fromScale(1, 1)}):Play()
end

-- Damage floats up in the UI kit's lettering; big hits are larger and gold.
function Effects:Number(position: Vector3, amount: number, big: boolean)
	if self.numbers >= MAX_NUMBERS then return end
	self.numbers += 1
	task.delay(0.85, function() self.numbers -= 1 end)
	local start = position + Vector3.new((math.random() - 0.5) * 0.8, 0, (math.random() - 0.5) * 0.8)
	local anchor = self:Anchor(start, 0.85)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.LightInfluence, gui.AlwaysOnTop, gui.MaxDistance = UDim2.fromOffset(120, 48), 0, true, 120
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency, label.Size, label.Font = 1, UDim2.fromScale(1, 1), Theme.Font
	label.Text, label.TextColor3 = "-" .. math.floor(amount + 0.5), if big then GOLD else Color3.new(1, 1, 1)
	label.Parent = gui
	local stroke = Instance.new("UIStroke");stroke.Color, stroke.Thickness, stroke.Parent = INK, if big then 3.5 else 2.5, label
	-- October 21 game feel: critical and splash hits land bigger, tilted and rise higher.
	local size = if big then 44 else 28
	label.Rotation = if big then math.random(-8, 8) else 0
	if self.app.reducedMotion then
		label.TextSize = size
	else
		label.TextSize = 10
		TweenService:Create(label, TweenInfo.new(if big then 0.22 else 0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextSize = size}):Play()
		TweenService:Create(anchor, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = start + Vector3.new(0, if big then 2.8 else 2.2, 0)}):Play()
	end
	TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.55), {TextTransparency = 1}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.25, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.55), {Transparency = 1}):Play()
end

function Effects:Smoke(position: Vector3)
	if self.app.reducedMotion then return end
	local attachment = Instance.new("Attachment")
	attachment.Parent = self:Anchor(position, 1)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture, emitter.Color, emitter.LightInfluence = SMOKE, ColorSequence.new(Color3.fromRGB(240, 240, 235)), 0
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.2)})
	emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	emitter.Lifetime, emitter.Speed = NumberRange.new(0.45, 0.7), NumberRange.new(4, 7)
	emitter.SpreadAngle, emitter.Drag, emitter.Rate = Vector2.new(180, 180), 6, 0
	emitter.Parent = attachment
	emitter:Emit(14)
end

-- Sounds sit at the fight so they fall off with distance like the rest of the world.
function Effects:Sound(cue: string, position: Vector3, pitch: number, cooldown: number, volume: number?)
	local anchor = self:Anchor(position, 3)
	self.app.audio:Play(cue, pitch, {noFallback = true, parent = anchor, cooldown = cooldown, maxVoices = 4,
		volume = volume, forceVolume = volume ~= nil})
end

-- `feet` is the ground under the attacker; nil skips the dust.
function Effects:Swing(position: Vector3, feet: Vector3?)
	if feet then self:Dust(feet) end
	self:Sound("CombatSwing", position, 1.25 + math.random() * 0.2, 0.08)
end

-- `facing` is the victim's facing (toward its foe); the slash crosses it.
function Effects:Hit(position: Vector3, damage: number, big: boolean, facing: Vector3?)
	self:Flash(position, if big then 4.2 else 3, if big then GOLD else Color3.new(1, 1, 1))
	self:Slash(position, facing or Vector3.zAxis, big)
	self:Sparks(position, if big then 14 else 8, if big then 0.5 else 0.38)
	self:Feathers(position, if big then 10 else 6, 1.3)
	self:Spark(position, big)
	if damage > 0 then self:Number(position + Vector3.new(0, 1.6, 0), damage, big) end
	self:Sound("CombatHit", position, 0.95 + math.random() * 0.25, 0.06)
end

-- `ground` is the floor under the fallen chicken, for the shockwave.
function Effects:Knockout(position: Vector3, ground: Vector3?)
	self:Flash(position, 5.5, GOLD)
	local feel = self.app.worldFeel
	if feel then
		feel:Ring(ground or position, {color = Color3.new(1, 1, 1), radius = 6, seconds = 0.45, thickness = 0.5, transparency = 0.1})
		feel:Burst(position, {color = GOLD, count = 16, size = 0.6, speed = {6, 11}, spread = 70, lifetime = {0.45, 0.8}, gravity = -14, light = 1})
	end
	self:Feathers(position, 18, 1.6)
	self:Smoke(position)
	self:Spark(position, true)
	self:Sound("CombatKnockout", position, 1.1, 0.1)
	self:Sound("CombatKnockoutCluck", position, 1 + math.random() * 0.15, 0.1)
end

-- October 25 (Stevin: conquering chickens should "do some conquering things"): one light
-- touch per server action (Battle.ConquerActions). Peck: a dust kick and a soft swing;
-- Hop: a puff under the feet and a happy cluck; Cluck: one of the ambient clucks. The
-- pose itself is the rig animator's (Attack / Victory clips). ConquerPeck / ConquerHop /
-- ConquerCluck are used once authored; until then these fall back to existing cues.
function Effects:Conquer(action: string?, position: Vector3, feet: Vector3?)
	local audio = self.app.audio
	local function cue(name: string, fallback: string): string
		return if audio and audio.Has and audio:Has(name) then name else fallback
	end
	if action == "Peck" then
		if feet then self:Dust(feet) end
		local name = cue("ConquerPeck", "CombatSwing")
		self:Sound(name, position, 1.3 + math.random() * 0.2, 0.12, if name == "CombatSwing" then 0.45 else nil)
	elseif action == "Hop" then
		local feel = self.app.worldFeel
		if feel and feet then feel:Poof(feet, {count = 6, size = 1}) end
		self:Sound(cue("ConquerHop", "ChickenHappy"), position, 1 + math.random() * 0.15, 0.3)
	elseif action == "Cluck" then
		local animator = self.app.animator
		if audio and audio.Has and audio:Has("ConquerCluck") then self:Sound("ConquerCluck", position, 1, 0.3)
		elseif animator and animator.Cluck then animator:Cluck(position) end
	end
end

return Effects
