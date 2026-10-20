--!strict
-- Roll camera for the local player's own podiums (Oct 20 overhaul, S2), matched to
-- Drop a Fruit's roll (Stevin's Oct 20 recording, measured frame by frame): the view
-- zooms in through the shuffle; on the reveal it snaps far out, the world flashes,
-- speed lines burst from the centre (in place of the reference's ring) and it eases
-- back. Epic and up add a short shake; Legendary and up a bigger snap, a longer
-- ease back and a brighter flash. The camera always stays with the player (Stevin
-- removed the Legendary orbit). Auto Roll gets a lighter push-in, snap and flash.
-- RollPresentationController decides when a roll counts (own lever podium, nearby,
-- no menu, normal camera, motion on); this module only presents it.
--
-- TweenService drives every move. Zooms tween Camera.FieldOfView, and the flash
-- tweens a local ColorCorrectionEffect on the camera (the world only, not the HUD).
-- The player camera rewrites Camera.CFrame every frame, so the shake tweens a value
-- that a render step adds right after the camera scripts and takes off again before
-- their next update. CameraType, Focus and controls never change.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.UITheme)
local RollCamera = {}
RollCamera.__index = RollCamera

-- Camera feel: edit these, then restart Play. Ranks: 1 Common … 4 Epic, 5 Legendary, 6 Mythic, 7 Secret.
-- Shuffle push-in: degrees of zoom (11.5 ≈ the reference's 1.25x) over the whole shuffle.
-- It holds until the chicken appears.
local PUSH_DEGREES = 11.5
local PUSH_EASING = Enum.EasingStyle.Sine
local PUSH_DIRECTION = Enum.EasingDirection.Out
local REVEAL_WAIT_SECONDS = 1 -- no reveal this long past the shuffle: just ease back
local RELEASE_SECONDS = 0.35 -- that ease back (Back Out)
-- Reveal by rank: snap = degrees wider than normal (reached in SNAP_SECONDS), back =
-- seconds to ease back (Quart In, so it lingers wide first), flash = world brightness,
-- lines = speed lines, shake = studs (0 = none).
local REVEAL = {
	{snap = 28, back = 0.42, flash = 0.35, lines = 18, shake = 0}, -- Common (the reference)
	{snap = 28, back = 0.42, flash = 0.35, lines = 18, shake = 0}, -- Uncommon
	{snap = 28, back = 0.42, flash = 0.35, lines = 18, shake = 0}, -- Rare
	{snap = 30, back = 0.48, flash = 0.4, lines = 22, shake = 0.18}, -- Epic
	{snap = 34, back = 0.6, flash = 0.5, lines = 28, shake = 0.26}, -- Legendary
	{snap = 36, back = 0.68, flash = 0.55, lines = 30, shake = 0.34}, -- Mythic
	{snap = 38, back = 0.75, flash = 0.6, lines = 34, shake = 0.42}, -- Secret
}
local SNAP_SECONDS = 0.05
local FLASH_TINT = Color3.fromRGB(205, 240, 255) -- the reference's cyan-white wash
local FLASH_RARITY_MIX = 0.35 -- Epic and up lean the wash toward their rarity color
local FLASH_HOLD_SECONDS = 0.08
local LINES_SECONDS = 0.32
local SHAKE_STEP_SECONDS = 0.04
local SHAKE_PATTERN = {
	Vector3.new(1, 0.6, 0), Vector3.new(-0.85, -0.4, 0), Vector3.new(0.6, -0.55, 0),
	Vector3.new(-0.35, 0.3, 0), Vector3.new(0.15, -0.12, 0), Vector3.zero,
}
-- Auto Roll: strength of the push-in, snap and flash; no speed lines or shake.
local AUTO_STRENGTH = 0.5

local MOST_SNAP = 0
for _, feel in REVEAL do MOST_SNAP = math.max(MOST_SNAP, feel.snap) end
local steps = 0

function RollCamera.new(app)
	steps += 1
	return setmetatable({app = app, zoom = nil, layer = nil, staleFov = nil, flash = nil, flashTween = nil,
		lines = nil, stepName = "PetRollRollCamera" .. steps}, RollCamera)
end

local function same(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < 0.001 and a.LookVector:Dot(b.LookVector) > 0.99999
		and a.UpVector:Dot(b.UpVector) > 0.99999
end

-- Called every frame by RollPresentationController with:
-- ok (motion on, alive, normal camera, no menu), near (lever podium in range),
-- roll ({key, startedAt, duration} while the lever podium shuffles), auto, and
-- reveal ({rank, color}: the rarest chicken appearing on the player's podiums this frame).
function RollCamera:Step(camera: Camera?, now: number, context)
	if camera then self:FixStaleFov(camera) end
	local usable = camera ~= nil and context.ok and context.near
	if not usable then self:ClearEffects() end
	if self.layer and (not usable or self.layer.camera ~= camera) then self:StopLayer() end
	if self.zoom and (not usable or self.zoom.camera ~= camera) then self:ClearZoom() end
	if not usable or not camera then return end
	local roll, zoom = context.roll, self.zoom
	if roll and (not zoom or zoom.key ~= roll.key or zoom.startedAt ~= roll.startedAt or zoom.duration ~= roll.duration) then
		self:StartPush(camera, roll, now, if context.auto then AUTO_STRENGTH else 1)
		zoom = self.zoom
	end
	if zoom and not zoom.landed then
		if context.reveal then
			self:Reveal(zoom, context.reveal, context.auto)
		elseif now >= zoom.startedAt + zoom.duration + REVEAL_WAIT_SECONDS then
			self:Release()
		end
	end
end

-- Field of view ------------------------------------------------------------

function RollCamera:TweenFov(zoom, goal: number, seconds: number, style: Enum.EasingStyle,
	direction: Enum.EasingDirection, done: (() -> ())?)
	local old = zoom.tween
	if old then old:Cancel();old:Destroy() end
	local tween = TweenService:Create(zoom.camera, TweenInfo.new(seconds, style, direction), {FieldOfView = goal})
	zoom.tween = tween
	if done then
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed and zoom.tween == tween then done() end
		end)
	end
	tween:Play()
end

function RollCamera:StartPush(camera: Camera, roll, now: number, strength: number)
	local remaining = roll.startedAt + roll.duration - now
	if remaining <= 0 then return end
	local old = self.zoom
	-- Back-to-back pulls keep the first resting field of view.
	local base = if old then old.base else camera.FieldOfView
	if old then self:DropZoom(old) end
	local degrees = math.clamp(PUSH_DEGREES * strength, 0, base - 1)
	local zoom = {camera = camera, base = base, key = roll.key, startedAt = roll.startedAt, duration = roll.duration,
		strength = strength, degrees = degrees, landed = false, tween = nil}
	self.zoom = zoom
	-- Walking up mid-roll eases in from the current view over the time left, with no jump.
	self:TweenFov(zoom, base - degrees, remaining, PUSH_EASING, PUSH_DIRECTION)
end

-- The chicken appears: snap far out, then ease back while the flash fades.
function RollCamera:Reveal(zoom, reveal, auto: boolean)
	zoom.landed = true
	local rank = math.clamp(math.floor(reveal.rank or 1), 1, #REVEAL)
	local feel = REVEAL[rank]
	local back = if auto then feel.back * 0.75 else feel.back
	self:TweenFov(zoom, math.min(119, zoom.base + feel.snap * zoom.strength), SNAP_SECONDS,
		Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
			self:TweenFov(zoom, zoom.base, back, Enum.EasingStyle.Quart, Enum.EasingDirection.In, function() self:DropZoom(zoom) end)
		end)
	self:Flash(zoom.camera, feel.flash * zoom.strength, if rank >= 4 then reveal.color else nil, SNAP_SECONDS + back)
	if auto then return end
	self:SpeedLines(feel.lines)
	self:Shake(zoom.camera, feel.shake)
end

function RollCamera:Release()
	local zoom = self.zoom
	if not zoom then return end
	zoom.landed = true
	self:TweenFov(zoom, zoom.base, RELEASE_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function() self:DropZoom(zoom) end)
end

function RollCamera:DropZoom(zoom)
	if self.zoom == zoom then self.zoom = nil end
	local tween = zoom.tween
	zoom.tween = nil
	if tween then tween:Cancel();tween:Destroy() end
end

-- Interruptions restore at once, with no surviving tween.
function RollCamera:ClearZoom()
	local zoom = self.zoom
	if not zoom then return end
	self:DropZoom(zoom)
	local camera = zoom.camera
	if camera.CameraType == Enum.CameraType.Custom then
		camera.FieldOfView = zoom.base
	else
		-- A cutscene took the camera mid-zoom: it owns the field of view now, and may
		-- restore our zoomed one when it hands back.
		self.staleFov = {camera = camera, base = zoom.base}
	end
end

function RollCamera:FixStaleFov(camera: Camera)
	local stale = self.staleFov
	if not stale or camera.CameraType ~= Enum.CameraType.Custom then return end
	self.staleFov = nil
	local fov = camera.FieldOfView
	if stale.camera == camera and math.abs(fov - stale.base) > 0.01 and fov > stale.base - PUSH_DEGREES - 1
		and fov < stale.base + MOST_SNAP + 1 then
		camera.FieldOfView = stale.base
	end
end

-- Flash and speed lines ----------------------------------------------------

-- A cyan-white wash of the world (Epic and up tinted by rarity) that holds a moment
-- and fades as the zoom eases back.
function RollCamera:Flash(camera: Camera, brightness: number, color: Color3?, seconds: number)
	if brightness <= 0 then return end
	local effect = self.flash
	if not effect or effect.Parent ~= camera then
		if effect then effect:Destroy() end
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "PetRollRollFlash"
		effect.Parent = camera
		self.flash = effect
	end
	if self.flashTween then self.flashTween:Cancel();self.flashTween:Destroy() end
	local amount = brightness / 0.35
	effect.Brightness, effect.Contrast, effect.Saturation = brightness, -0.15 * amount, -0.3 * amount
	effect.TintColor = if color then FLASH_TINT:Lerp(color, FLASH_RARITY_MIX) else FLASH_TINT
	effect.Enabled = true
	local tween = TweenService:Create(effect, TweenInfo.new(math.max(0.05, seconds - FLASH_HOLD_SECONDS),
		Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, FLASH_HOLD_SECONDS),
		{Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1)})
	self.flashTween = tween
	tween.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and self.flashTween == tween then
			self.flashTween = nil
			effect.Enabled = false
		end
	end)
	tween:Play()
end

-- White rush lines bursting out from the screen centre, under the HUD.
function RollCamera:SpeedLines(count: number)
	local gui = self.app and self.app.gui
	if not gui or count <= 0 then return end
	local holder = self.lines
	if not holder or holder.Parent ~= gui then
		holder = Theme.Container(gui, "RollRevealLines")
		holder.ZIndex = 0
		self.lines = holder
	end
	local size = holder.AbsoluteSize
	local center, reach = size / 2, math.max(size.X, size.Y) * 0.5
	local random = Random.new()
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + random:NextNumber(-0.12, 0.12)
		local direction = Vector2.new(math.cos(angle), math.sin(angle))
		local near, far = center + direction * reach * random:NextNumber(0.3, 0.5), center + direction * reach * 1.15
		local line = Instance.new("Frame")
		line.Name, line.AnchorPoint, line.BorderSizePixel = "Line", Vector2.new(0.5, 0.5), 0
		line.BackgroundColor3, line.BackgroundTransparency = Color3.new(1, 1, 1), 0.15
		line.Size = UDim2.fromOffset(reach * random:NextNumber(0.25, 0.4), math.max(2, size.Y * 0.005))
		line.Rotation, line.Position, line.Parent = math.deg(angle), UDim2.fromOffset(near.X, near.Y), holder
		local tween = TweenService:Create(line, TweenInfo.new(LINES_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
			0, false, random:NextNumber(0, 0.05)), {Position = UDim2.fromOffset(far.X, far.Y), BackgroundTransparency = 1})
		tween.Completed:Once(function() line:Destroy() end)
		tween:Play()
	end
end

function RollCamera:ClearEffects()
	if self.flashTween then
		self.flashTween:Cancel();self.flashTween:Destroy();self.flashTween = nil
		local effect = self.flash
		if effect then
			effect.Enabled = false
			effect.Brightness, effect.Contrast, effect.Saturation, effect.TintColor = 0, 0, 0, Color3.new(1, 1, 1)
		end
	end
	local holder = self.lines
	if holder and #holder:GetChildren() > 0 then holder:ClearAllChildren() end
end

-- Shake layer ---------------------------------------------------------------

function RollCamera:Layer(camera: Camera)
	local layer = self.layer
	if layer then return layer end
	layer = {camera = camera, shake = Instance.new("Vector3Value"), shakeSerial = 0, shaking = false,
		shakeTween = nil, base = nil, applied = nil}
	self.layer = layer
	RunService:BindToRenderStep(self.stepName .. "Restore", Enum.RenderPriority.Camera.Value - 1, function() self:Restore() end)
	RunService:BindToRenderStep(self.stepName .. "Apply", Enum.RenderPriority.Camera.Value + 1, function() self:Apply() end)
	return layer
end

-- Before the camera scripts: put back their own frame if nothing else moved it.
function RollCamera:Restore()
	local layer = self.layer
	if not layer or not layer.applied then return end
	local applied, base = layer.applied, layer.base
	layer.applied = nil
	local camera = layer.camera
	if workspace.CurrentCamera == camera and camera.CameraType == Enum.CameraType.Custom and same(camera.CFrame, applied) then
		camera.CFrame = base
	end
end

-- After the camera scripts: the shake, in view space.
function RollCamera:Apply()
	local layer = self.layer
	local camera = workspace.CurrentCamera
	if not layer or camera ~= layer.camera or camera.CameraType ~= Enum.CameraType.Custom then return end
	local base = camera.CFrame
	local goal = base * CFrame.new(layer.shake.Value)
	layer.base, layer.applied = base, goal
	camera.CFrame = goal
end

function RollCamera:StopLayer()
	local layer = self.layer
	if not layer then return end
	-- Hand the player camera its own frame back now, not a frame later.
	self:Restore()
	self.layer = nil
	RunService:UnbindFromRenderStep(self.stepName .. "Restore")
	RunService:UnbindFromRenderStep(self.stepName .. "Apply")
	layer.shakeSerial += 1
	if layer.shakeTween then layer.shakeTween:Cancel();layer.shakeTween:Destroy() end
	layer.shake:Destroy()
end

function RollCamera:Shake(camera: Camera, studs: number?)
	if not studs or studs <= 0 then return end
	local layer = self:Layer(camera)
	layer.shakeSerial += 1
	local serial = layer.shakeSerial
	layer.shaking = true
	local function jolt(index: number)
		if self.layer ~= layer or layer.shakeSerial ~= serial then return end
		local target = SHAKE_PATTERN[index]
		if not target then
			layer.shaking = false
			self:StopLayer()
			return
		end
		if layer.shakeTween then layer.shakeTween:Destroy() end
		local tween = TweenService:Create(layer.shake,
			TweenInfo.new(SHAKE_STEP_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Value = target * studs})
		layer.shakeTween = tween
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then jolt(index + 1) end
		end)
		tween:Play()
	end
	jolt(1)
end

function RollCamera:Destroy()
	self:ClearEffects()
	self:StopLayer()
	self:ClearZoom()
	if self.flash then self.flash:Destroy();self.flash = nil end
	if self.lines then self.lines:Destroy();self.lines = nil end
end

return RollCamera
