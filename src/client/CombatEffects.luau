--!strict
-- Local fight feedback: voxel feather puffs, a comic hit spark, floating damage
-- numbers and knockout poofs, plus their sounds. Presentation only; the server's
-- battle snapshots decide every hit, knockout and number shown here.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.UITheme)

local INK = Color3.fromRGB(16, 23, 16)
local GOLD = Color3.fromRGB(255, 214, 64)
local FEATHER = Color3.new(1, 1, 1)
local FEATHER_WARM = Color3.fromRGB(236, 226, 204)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
-- Busy fights stay readable and cheap: extra effects are skipped, never queued.
local MAX_FEATHERS, MAX_NUMBERS = 70, 14

local Effects = {}
Effects.__index = Effects

function Effects.new(app, folder: Instance)
	return setmetatable({app = app, folder = folder, feathers = 0, numbers = 0}, Effects)
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
	gui.Size = UDim2.fromScale(if big then 4 else 2.8, if big then 4 else 2.8)
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
	local stroke = Instance.new("UIStroke");stroke.Color, stroke.Thickness, stroke.Parent = INK, if big then 3 else 2.5, label
	local size = if big then 38 else 28
	if self.app.reducedMotion then
		label.TextSize = size
	else
		label.TextSize = 10
		TweenService:Create(label, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextSize = size}):Play()
		TweenService:Create(anchor, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = start + Vector3.new(0, 2.2, 0)}):Play()
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
function Effects:Sound(cue: string, position: Vector3, pitch: number, cooldown: number)
	local anchor = self:Anchor(position, 3)
	self.app.audio:Play(cue, pitch, {noFallback = true, parent = anchor, cooldown = cooldown, maxVoices = 4})
end

function Effects:Swing(position: Vector3)
	self:Sound("CombatSwing", position, 1.25 + math.random() * 0.2, 0.08)
end

function Effects:Hit(position: Vector3, damage: number, big: boolean)
	self:Feathers(position, if big then 8 else 5, 0.9)
	self:Spark(position, big)
	if damage > 0 then self:Number(position + Vector3.new(0, 1.6, 0), damage, big) end
	self:Sound("CombatHit", position, 0.95 + math.random() * 0.25, 0.06)
end

function Effects:Knockout(position: Vector3)
	self:Feathers(position, 14, 1.2)
	self:Smoke(position)
	self:Spark(position, true)
	self:Sound("CombatKnockout", position, 1.1, 0.1)
	self:Sound("CombatKnockoutBoing", position, 1.3, 0.1)
end

return Effects
