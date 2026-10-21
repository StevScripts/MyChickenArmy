--!strict
-- October 21 game feel: world-space punctuation shared by every system. Particle
-- bursts, ground rings, poofs, sparkles, highlight flashes, floating text and
-- positioned sounds, all under one budget. Presentation only: nothing here changes
-- game state. Reduced motion keeps floating text (state feedback) and drops the rest.
-- docs/team/GAME_FEEL_20261021.md
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.UITheme)
local WorldFeel = {}
WorldFeel.__index = WorldFeel

local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function touchOnly()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function sequence(color)
	if typeof(color) == "ColorSequence" then return color end
	local c = color or Color3.new(1, 1, 1)
	return ColorSequence.new(c, c:Lerp(Color3.new(1, 1, 1), 0.6))
end

function WorldFeel.new(app)
	return setmetatable({app = app, alive = false, active = 0, folder = nil,
		highlights = setmetatable({}, {__mode = "k"})}, WorldFeel)
end

function WorldFeel:Start()
	if self.alive then return end
	self.alive = true
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "PetRollWorldFeel", workspace
	self.folder = folder
end

function WorldFeel:Limit()
	return if touchOnly() then 14 else 28
end

function WorldFeel:Root(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Effects only play within `range` studs of the player (default 120).
function WorldFeel:Near(position: Vector3, range: number?): boolean
	local root = self:Root()
	return root ~= nil and (root.Position - position).Magnitude <= (range or 120)
end

function WorldFeel:Take(seconds: number): boolean
	if self.active >= self:Limit() then return false end
	self.active += 1
	task.delay(seconds, function() self.active = math.max(0, self.active - 1) end)
	return true
end

function WorldFeel:Ready(position: Vector3, seconds: number, range: number?): boolean
	return self.alive and not self.app.reducedMotion and self:Near(position, range) and self:Take(seconds)
end

-- An invisible anchored part at `position`, gone after `seconds`.
function WorldFeel:Anchor(name: string, position: Vector3, seconds: number): Part
	local part = Instance.new("Part")
	part.Name, part.Size, part.Position = name, Vector3.one, position
	part.Anchored, part.Transparency = true, 1
	part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false
	part.Parent = self.folder
	Debris:AddItem(part, seconds)
	return part
end

-- A one-shot particle burst. options: color (Color3 or ColorSequence), count (14),
-- size (0.5), speed ({4,9}), spread (90), lifetime ({0.35,0.7}), gravity (-9),
-- light (0.6), texture, range. Returns the anchor (nil when skipped).
function WorldFeel:Burst(position: Vector3, options)
	options = options or {}
	if not self:Ready(position, 1.2, options.range) then return nil end
	local anchor = self:Anchor("FeelBurst", position, 1.3)
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	local size = options.size or 0.5
	local speed = options.speed or {4, 9}
	local life = options.lifetime or {0.35, 0.7}
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name, emitter.Texture = "FeelSparkles", options.texture or SPARKLES
	emitter.Color = sequence(options.color)
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(0.6, size * 0.7), NumberSequenceKeypoint.new(1, 0)})
	emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.7, 0.25), NumberSequenceKeypoint.new(1, 1)})
	emitter.Lifetime, emitter.Speed = NumberRange.new(life[1], life[2]), NumberRange.new(speed[1], speed[2])
	emitter.SpreadAngle = Vector2.new(options.spread or 90, options.spread or 90)
	emitter.Acceleration = Vector3.new(0, options.gravity or -9, 0)
	emitter.Rate, emitter.LightEmission, emitter.RotSpeed = 0, options.light or 0.6, NumberRange.new(-180, 180)
	emitter.Parent = attachment
	emitter:Emit(options.count or 14)
	return anchor
end

-- A hollow ground ring growing out from `position`. options: color, radius (4),
-- seconds (0.5), thickness (0.25), height (0.03), transparency (0.2).
function WorldFeel:Ring(position: Vector3, options)
	options = options or {}
	local seconds = options.seconds or 0.5
	if not self:Ready(position, seconds + 0.1, options.range) then return nil end
	local anchor = self:Anchor("FeelRing", position, seconds + 0.2)
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Name, ring.Adornee, ring.Parent = "Ring", anchor, anchor
	local thickness = options.thickness or 0.25
	ring.Radius, ring.InnerRadius, ring.Height = 0.6, 0.6 - thickness, options.height or 0.03
	ring.CFrame, ring.Color3, ring.Transparency = CFrame.Angles(math.pi / 2, 0, 0), options.color or Color3.new(1, 1, 1), options.transparency or 0.2
	ring.AlwaysOnTop = false
	local radius = options.radius or 4
	TweenService:Create(ring, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Radius = radius, InnerRadius = radius - thickness, Transparency = 1}):Play()
	return anchor
end

-- A soft smoke puff (landing, teleport, knockout). options: color, count (10), size (1.4).
function WorldFeel:Poof(position: Vector3, options)
	options = options or {}
	local size = options.size or 1.4
	return self:Burst(position, {texture = SMOKE, color = options.color or Color3.fromRGB(235, 235, 230),
		count = options.count or 10, size = size, speed = {2, 5}, spread = 180, lifetime = {0.4, 0.8},
		gravity = 1.5, light = 0.1, range = options.range})
end

-- Sparkles riding on a part for `seconds` (a chicken that just levelled, a ready egg).
function WorldFeel:Sparkle(part: BasePart, seconds: number?, options)
	options = options or {}
	local life = seconds or 1
	if not part or not part.Parent or not self:Ready(part.Position, life, options.range) then return nil end
	local attachment = Instance.new("Attachment")
	attachment.Name = "FeelSparkleAttachment"
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name, emitter.Texture = "FeelSparkle", SPARKLES
	emitter.Color = sequence(options.color or Color3.fromRGB(255, 214, 48))
	local size = options.size or 0.35
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, size), NumberSequenceKeypoint.new(1, 0)})
	emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	emitter.Lifetime, emitter.Speed = NumberRange.new(0.5, 0.9), NumberRange.new(1.5, 3)
	emitter.SpreadAngle, emitter.Acceleration = Vector2.new(180, 180), Vector3.new(0, 2, 0)
	emitter.Rate, emitter.LightEmission = options.rate or 18, 0.7
	emitter.Parent = attachment
	attachment.Parent = part
	task.delay(life, function()
		if not emitter.Parent then return end
		emitter.Enabled = false
		Debris:AddItem(attachment, 1)
	end)
	return attachment
end

-- A Highlight that flashes on a model or part and fades over `seconds` (0.5).
-- One per target at a time; reused while it runs.
function WorldFeel:Highlight(target: Instance, color: Color3?, seconds: number?)
	if not self.alive or self.app.reducedMotion or not target or not target.Parent then return nil end
	local life = seconds or 0.5
	local highlight = self.highlights[target]
	if not highlight or not highlight.Parent then
		if self.active >= self:Limit() then return nil end
		highlight = Instance.new("Highlight")
		highlight.Name, highlight.Adornee = "FeelHighlight", target
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = self.folder
		self.highlights[target] = highlight
		self.active += 1
		highlight.Destroying:Once(function()
			self.active = math.max(0, self.active - 1)
			if self.highlights[target] == highlight then self.highlights[target] = nil end
		end)
	end
	local tint = color or Color3.new(1, 1, 1)
	highlight.FillColor, highlight.OutlineColor = tint, tint
	highlight.FillTransparency, highlight.OutlineTransparency = 0.35, 0
	TweenService:Create(highlight, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{FillTransparency = 1, OutlineTransparency = 1}):Play()
	Debris:AddItem(highlight, life + 0.05)
	return highlight
end

-- Floating text at a world point ("+1,200" with the coin, "Level 4!", "MAX"). options:
-- color, size (px, 30), seconds (1.1), rise (2.5 studs), coin (true draws the coin
-- beside it), width (260), range. Kept under reduced motion (no rise). Billboards are
-- not AlwaysOnTop so Studio captures show them; the offset leans toward the camera.
function WorldFeel:Text(position: Vector3, text: string, options)
	options = options or {}
	local seconds = options.seconds or 1.1
	if not self.alive or not self:Near(position, options.range or 90) then return nil end
	if not self:Take(seconds + 0.1) then return nil end
	local anchor = self:Anchor("FeelText", position, seconds + 0.2)
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee, gui.Size = "FeelText", anchor, UDim2.fromOffset(options.width or 260, (options.size or 30) * 1.6)
	gui.MaxDistance, gui.AlwaysOnTop, gui.StudsOffset = 90, false, Vector3.new(0, 0, -0.5)
	gui.Parent = anchor
	local size = options.size or 30
	local color = options.color or Theme.Colors.gold
	local label, fades
	if options.coin then
		local _, amount, icon = Theme.CoinAmount(gui, "Amount", text, size, color)
		label, fades = amount, {icon}
	else
		label = Theme.Display(gui, "Amount", text, size, color)
		label.Size, label.TextXAlignment, label.TextScaled, label.TextWrapped = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center, false, false
		fades = {}
	end
	local scale = Instance.new("UIScale")
	scale.Scale, scale.Parent = if self.app.reducedMotion then 1 else 0.5, gui
	if self.app.reducedMotion then return anchor end
	TweenService:Create(scale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	TweenService:Create(anchor, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Position = position + Vector3.new(0, options.rise or 2.5, 0)}):Play()
	local fade = TweenInfo.new(seconds * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, seconds * 0.6)
	for _, item in fades do TweenService:Create(item, fade, {ImageTransparency = 1}):Play() end
	for _, child in label:GetDescendants() do
		if child:IsA("TextLabel") then TweenService:Create(child, fade, {TextTransparency = 1}):Play()
		elseif child:IsA("UIStroke") then TweenService:Create(child, fade, {Transparency = 1}):Play() end
	end
	return anchor
end

-- A positioned one-shot through the shared AudioController (spatial, 8–42 studs).
function WorldFeel:Sound(name: string, position: Vector3, pitch: number?, options)
	local audio = self.app.audio
	if not audio or not audio.PlayAt then return nil end
	return audio:PlayAt(name, position, pitch, options)
end

-- Burst + ring + a short sparkle: the shared "something good happened here".
-- size 1 small (egg, prompt), 2 medium (purchase, level), 3 big (capture, rare roll).
function WorldFeel:Celebrate(position: Vector3, color: Color3?, size: number?)
	local s = size or 2
	local tint = color or Theme.Colors.gold
	self:Burst(position, {color = tint, count = 8 + 8 * s, size = 0.35 + 0.15 * s, speed = {4, 6 + 3 * s}})
	self:Ring(position - Vector3.new(0, 2, 0), {color = tint, radius = 2 + 2 * s, seconds = 0.4 + 0.1 * s})
end

function WorldFeel:Clear()
	if self.folder then self.folder:ClearAllChildren() end
	self.active = 0
end

function WorldFeel:Destroy()
	self.alive = false
	if self.folder then self.folder:Destroy(); self.folder = nil end
	self.active = 0
end

return WorldFeel
