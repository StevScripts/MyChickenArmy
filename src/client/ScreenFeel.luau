--!strict
-- October 21 game feel: camera-side punctuation shared by every system. A short
-- decaying shake, a world flash (ColorCorrection) and a FOV punch. The camera always
-- stays with the player: no orbit, no CFrame takeover, only an offset added after the
-- camera scripts and removed before their next update (the RollCamera pattern).
-- RollCamera owns the roll's own feel; Zoom backs off while a roll holds the FOV.
-- Presentation only: nothing here changes game state. Reduced motion skips all of it.
-- docs/team/GAME_FEEL_20261021.md
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ScreenFeel = {}
ScreenFeel.__index = ScreenFeel

local BASE_FOV = 70
local MAX_STRENGTH = 0.9 -- studs
local MAX_FLASH = 0.6
local NOISE_SPEED = 22

local function same(a: CFrame, b: CFrame)
	return (a.Position - b.Position).Magnitude < 1e-4 and (a.LookVector - b.LookVector).Magnitude < 1e-5
end

function ScreenFeel.new(app)
	return setmetatable({app = app, alive = false, strength = 0, seconds = 0.3, startedAt = 0,
		seed = math.random() * 100, applied = nil, base = nil, camera = nil, zoom = nil,
		flash = nil, flashTween = nil, name = "PetRollFeel"}, ScreenFeel)
end

function ScreenFeel:Start()
	if self.alive then return end
	self.alive = true
	self.name = "PetRollFeel" .. string.gsub(tostring(os.clock()), "%.", "")
	RunService:BindToRenderStep(self.name .. "Restore", Enum.RenderPriority.Camera.Value - 1, function() self:Restore() end)
	RunService:BindToRenderStep(self.name .. "Apply", Enum.RenderPriority.Camera.Value + 1, function() self:Apply() end)
end

-- Shake layer ---------------------------------------------------------------

-- The current shake offset in view space, or nil once it has decayed.
function ScreenFeel:Offset(now: number): Vector3?
	if self.strength <= 0 then return nil end
	local elapsed = now - self.startedAt
	if elapsed >= self.seconds then self.strength = 0; return nil end
	local decay = 1 - elapsed / self.seconds
	local amount = self.strength * decay * decay * 2 -- math.noise spans about -0.5..0.5
	local t = now * NOISE_SPEED
	return Vector3.new(math.noise(self.seed, t) * amount, math.noise(self.seed + 7, t) * amount, 0)
end

-- After the camera scripts: add the shake in view space.
function ScreenFeel:Apply()
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then self.applied = nil; return end
	local offset = self:Offset(os.clock())
	if not offset then self.applied = nil; return end
	local base = camera.CFrame
	local goal = base * CFrame.new(offset)
	self.base, self.applied, self.camera = base, goal, camera
	camera.CFrame = goal
end

-- Before the camera scripts: hand back their own frame if nothing else moved it.
function ScreenFeel:Restore()
	local applied = self.applied
	if not applied then return end
	self.applied = nil
	local camera = self.camera
	if camera and workspace.CurrentCamera == camera and camera.CameraType == Enum.CameraType.Custom and same(camera.CFrame, applied) then
		camera.CFrame = self.base
	end
end

-- strength in studs (0.1 light … 0.6 heavy), seconds to decay. A stronger shake
-- replaces a running one; a weaker one only extends its tail.
function ScreenFeel:Shake(strength: number?, seconds: number?)
	if not self.alive or self.app.reducedMotion then return end
	local amount = math.min(MAX_STRENGTH, strength or 0.25)
	local now = os.clock()
	if self:Offset(now) and amount < self.strength then
		self.seconds = math.max(self.seconds, (now - self.startedAt) + (seconds or 0.3))
		return
	end
	self.strength, self.seconds, self.startedAt = amount, seconds or 0.3, now
end

-- Flash ----------------------------------------------------------------------

-- A brief wash of the world (not the HUD) in `color`, strength 0..0.6, fading over seconds.
function ScreenFeel:Flash(color: Color3?, strength: number?, seconds: number?)
	if not self.alive or self.app.reducedMotion then return end
	local effect = self.flash
	if not effect or not effect.Parent then
		effect = Instance.new("ColorCorrectionEffect")
		effect.Name = "PetRollFeelFlash"
		effect.Parent = Lighting
		self.flash = effect
	end
	if self.flashTween then self.flashTween:Cancel(); self.flashTween:Destroy(); self.flashTween = nil end
	local brightness = math.clamp(strength or 0.25, 0, MAX_FLASH)
	effect.Brightness, effect.TintColor, effect.Enabled = brightness, color or Color3.new(1, 1, 1), true
	effect.Saturation = -0.2 * brightness / 0.35
	local tween = TweenService:Create(effect, TweenInfo.new(seconds or 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Brightness = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1)})
	self.flashTween = tween
	tween.Completed:Once(function(state)
		if self.flashTween ~= tween then return end
		self.flashTween = nil
		if state == Enum.PlaybackState.Completed then effect.Enabled = false end
	end)
	tween:Play()
end

-- Zoom -----------------------------------------------------------------------

-- A quick FOV punch: `degrees` wider (positive) or tighter (negative), then back.
-- Skipped while another system (the roll camera) holds the FOV away from base.
function ScreenFeel:Zoom(degrees: number?, seconds: number?)
	if not self.alive or self.app.reducedMotion then return end
	local camera = workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then return end
	local zoom = self.zoom
	if not zoom then
		if math.abs(camera.FieldOfView - BASE_FOV) > 0.75 then return end
		zoom = {camera = camera, base = camera.FieldOfView, tween = nil}
		self.zoom = zoom
	elseif zoom.camera ~= camera then
		return
	end
	if zoom.tween then zoom.tween:Cancel(); zoom.tween:Destroy(); zoom.tween = nil end
	local total = seconds or 0.45
	local out = TweenService:Create(camera, TweenInfo.new(total * 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{FieldOfView = zoom.base + (degrees or 6)})
	zoom.tween = out
	out.Completed:Once(function(state)
		if zoom.tween ~= out then return end
		if state ~= Enum.PlaybackState.Completed then return end
		local back = TweenService:Create(camera, TweenInfo.new(total * 0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{FieldOfView = zoom.base})
		zoom.tween = back
		back.Completed:Once(function(result)
			if zoom.tween ~= back then return end
			zoom.tween = nil
			if self.zoom == zoom then self.zoom = nil end
			if result == Enum.PlaybackState.Completed then camera.FieldOfView = zoom.base end
		end)
		back:Play()
	end)
	out:Play()
end

-- Presets --------------------------------------------------------------------

-- A hit landed near the player: size 1 small, 2 medium, 3 big.
function ScreenFeel:Impact(size: number?)
	local s = size or 1
	self:Shake(0.12 * s, 0.22 + 0.06 * s)
	if s >= 2 then self:Flash(Color3.new(1, 1, 1), 0.12 * s, 0.3) end
end

-- Something great happened (rare roll, Rebirth, Mission win): flash, zoom and a little shake.
function ScreenFeel:Celebrate(color: Color3?, size: number?)
	local s = size or 2
	self:Flash(color or Color3.fromRGB(255, 244, 200), 0.14 * s, 0.4 + 0.1 * s)
	self:Zoom(3 * s, 0.5 + 0.1 * s)
	if s >= 2 then self:Shake(0.1 * s, 0.3) end
end

function ScreenFeel:Destroy()
	if not self.alive then return end
	self.alive = false
	self:Restore()
	self.strength = 0
	pcall(RunService.UnbindFromRenderStep, RunService, self.name .. "Restore")
	pcall(RunService.UnbindFromRenderStep, RunService, self.name .. "Apply")
	if self.flashTween then self.flashTween:Cancel(); self.flashTween:Destroy(); self.flashTween = nil end
	if self.flash then self.flash:Destroy(); self.flash = nil end
	local zoom = self.zoom
	if zoom then
		if zoom.tween then zoom.tween:Cancel(); zoom.tween:Destroy() end
		if zoom.camera and zoom.camera.Parent then zoom.camera.FieldOfView = zoom.base end
		self.zoom = nil
	end
end

return ScreenFeel
