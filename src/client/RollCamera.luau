--!strict
-- Roll camera for the local player's own podiums (Oct 20 overhaul, S2): a push-in
-- during the shuffle, a zoom punch and shake when an Epic or rarer chicken lands,
-- and a slow orbit around Legendary, Mythic and Secret reveals. Auto Roll gets a
-- lighter push-in and punch with no shake or orbit. RollPresentationController
-- decides when a roll counts (own lever podium, nearby, no menu, normal camera,
-- motion on); this module only moves the view.
--
-- TweenService drives every move. Zooms tween Camera.FieldOfView directly. The
-- player camera rewrites Camera.CFrame every frame, so a tween on it would be
-- overwritten: the shake and orbit tween small values instead, and a render step
-- adds them right after the camera scripts and takes them off again before their
-- next update, so the player's own view never inherits the orbit. CameraType,
-- Focus and controls never change, so cutscenes can take the camera at any time.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RollCamera = {}
RollCamera.__index = RollCamera

-- Camera feel: edit these, then restart Play. Ranks: 4 Epic, 5 Legendary, 6 Mythic, 7 Secret.
-- Push-in: degrees of zoom over the shuffle (2 before Oct 20). It holds until the chicken lands.
local PUSH_DEGREES = 7
local PUSH_EASING = Enum.EasingStyle.Sine
local PUSH_DIRECTION = Enum.EasingDirection.In
local LAND_WAIT_SECONDS = 1 -- a reveal later than this past the shuffle just eases back
-- Common to Rare: ease back out.
local RETURN_SECONDS = 0.35
local RETURN_EASING = Enum.EasingStyle.Back
local RETURN_DIRECTION = Enum.EasingDirection.Out
-- Epic and up: extra zoom degrees on the landing thump, then the same Back ease out.
local PUNCH_DEGREES = {[4] = 3, [5] = 4.5, [6] = 5.5, [7] = 6.5}
local PUNCH_IN_SECONDS = 0.07
local PUNCH_OUT_SECONDS = 0.5
-- Epic and up: shake size in studs, played as quick jolts that die down.
local SHAKE_STUDS = {[4] = 0.18, [5] = 0.26, [6] = 0.34, [7] = 0.42}
local SHAKE_STEP_SECONDS = 0.04
local SHAKE_PATTERN = {
	Vector3.new(1, 0.6, 0), Vector3.new(-0.85, -0.4, 0), Vector3.new(0.6, -0.55, 0),
	Vector3.new(-0.35, 0.3, 0), Vector3.new(0.15, -0.12, 0), Vector3.zero,
}
-- Legendary and up: degrees swept in front of the chicken, and the orbit's length.
local ORBIT_DEGREES = 55
local ORBIT_SECONDS = {[5] = 3, [6] = 3.4, [7] = 3.8}
local ORBIT_DELAY = 0.1 -- after the landing thump
local ORBIT_IN_SECONDS = 0.55
local ORBIT_OUT_SECONDS = 0.6
local ORBIT_EXIT_SECONDS = 0.35 -- walking, buying it or pulling the lever again hands back early
-- Auto Roll: strength of the push-in and punch.
local AUTO_STRENGTH = 0.5

local MOST_ZOOM = PUSH_DEGREES
for _, degrees in PUNCH_DEGREES do MOST_ZOOM = math.max(MOST_ZOOM, PUSH_DEGREES + degrees) end
local steps = 0

function RollCamera.new()
	steps += 1
	return setmetatable({zoom = nil, layer = nil, staleFov = nil, stepName = "PetRollRollCamera" .. steps}, RollCamera)
end

local function same(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < 0.001 and a.LookVector:Dot(b.LookVector) > 0.99999
		and a.UpVector:Dot(b.UpVector) > 0.99999
end

-- The first visible part between two points, skipping see-through ones (as IntroCutscene:Obstacle).
local function obstacle(from: Vector3, to: Vector3, ignored: {Instance}): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignored
		local hit = workspace:Raycast(from, to - from, params)
		if not hit then return nil end
		if hit.Instance.Transparency < 0.5 and hit.Instance.LocalTransparencyModifier < 1 then return hit end
		table.insert(ignored, hit.Instance)
	end
	return nil
end

-- progress 0..1 along the orbit's arc, looking at the chicken.
local function shot(plan, progress: number): CFrame
	local around = CFrame.Angles(0, plan.from + (plan.to - plan.from) * progress, 0):VectorToWorldSpace(plan.front)
	return CFrame.lookAt(plan.center + around * plan.radius + Vector3.new(0, plan.lift, 0), plan.center)
end

-- Called every frame by RollPresentationController with:
-- ok (motion on, alive, normal camera, no menu), near (lever podium in range),
-- roll ({key, startedAt, duration} while the lever podium shuffles), moving, auto,
-- gone (the orbited chicken left its podium, e.g. bought), and
-- landing ({rank, foot, front, height, ignore}: this frame's rarest fresh landing).
function RollCamera:Step(camera: Camera?, now: number, context)
	if camera then self:FixStaleFov(camera) end
	local usable = camera ~= nil and context.ok and context.near
	if self.layer and (not usable or self.layer.camera ~= camera) then self:StopLayer() end
	if self.zoom and (not usable or self.zoom.camera ~= camera) then self:ClearZoom() end
	if not usable or not camera then return end
	local roll, zoom = context.roll, self.zoom
	if roll and (not zoom or zoom.key ~= roll.key or zoom.startedAt ~= roll.startedAt or zoom.duration ~= roll.duration) then
		self:EndOrbit()
		self:StartPush(camera, roll, now, if context.auto then AUTO_STRENGTH else 1)
		zoom = self.zoom
	end
	if context.moving or context.gone then self:EndOrbit() end
	if zoom and not zoom.landed then
		if context.landing then
			self:Land(zoom, context.landing, context.auto)
		elseif now >= zoom.startedAt + zoom.duration + LAND_WAIT_SECONDS then
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

function RollCamera:Land(zoom, landing, auto: boolean)
	local rank = math.min(landing.rank, 7)
	local punch = PUNCH_DEGREES[rank]
	if not punch then self:Release();return end
	zoom.landed = true
	local camera = zoom.camera
	self:TweenFov(zoom, math.max(1, zoom.base - zoom.degrees - punch * zoom.strength), PUNCH_IN_SECONDS,
		Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
			self:TweenFov(zoom, zoom.base, PUNCH_OUT_SECONDS, RETURN_EASING, RETURN_DIRECTION, function() self:DropZoom(zoom) end)
		end)
	if auto then return end
	self:Shake(camera, SHAKE_STUDS[rank])
	local seconds = ORBIT_SECONDS[rank]
	if seconds then self:Orbit(camera, landing, seconds) end
end

function RollCamera:Release()
	local zoom = self.zoom
	if not zoom then return end
	zoom.landed = true
	self:TweenFov(zoom, zoom.base, RETURN_SECONDS, RETURN_EASING, RETURN_DIRECTION, function() self:DropZoom(zoom) end)
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
	if stale.camera == camera and math.abs(fov - stale.base) > 0.01 and fov > stale.base - MOST_ZOOM - 1
		and fov < stale.base + 3 then
		camera.FieldOfView = stale.base
	end
end

-- Shake and orbit layer ----------------------------------------------------

function RollCamera:Layer(camera: Camera)
	local layer = self.layer
	if layer then return layer end
	layer = {camera = camera, shake = Instance.new("Vector3Value"), shakeSerial = 0, shaking = false,
		shakeTween = nil, orbit = nil, base = nil, applied = nil}
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

-- After the camera scripts: shake in view space, then blend toward the orbit shot.
function RollCamera:Apply()
	local layer = self.layer
	local camera = workspace.CurrentCamera
	if not layer or camera ~= layer.camera or camera.CameraType ~= Enum.CameraType.Custom then return end
	local base = camera.CFrame
	local shake = CFrame.new(layer.shake.Value)
	local goal = base * shake
	local orbit = layer.orbit
	if orbit and orbit.blend.Value > 0 then
		goal = goal:Lerp(shot(orbit.plan, orbit.angle.Value) * shake, orbit.blend.Value)
	end
	layer.base, layer.applied = base, goal
	camera.CFrame = goal
end

function RollCamera:StopIfIdle(layer)
	if self.layer == layer and not layer.orbit and not layer.shaking then self:StopLayer() end
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
	local orbit = layer.orbit
	layer.orbit = nil
	if orbit then
		for _, tween in orbit.tweens do tween:Cancel();tween:Destroy() end
		orbit.angle:Destroy();orbit.blend:Destroy()
	end
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
			self:StopIfIdle(layer)
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

-- An arc in front of the chicken that starts on the camera's side, so the swing
-- never crosses it, pulled in front of anything solid along the way. Nil when
-- there is no room.
function RollCamera:PlanOrbit(camera: Camera, landing)
	local front = Vector3.new(landing.front.X, 0, landing.front.Z)
	if front.Magnitude < 0.01 then return nil end
	front = front.Unit
	local height = math.clamp(landing.height or 3, 1.5, 30)
	local center = landing.foot + Vector3.new(0, height * 0.55, 0)
	local side = if (camera.CFrame.Position - center):Dot(front:Cross(Vector3.yAxis)) >= 0 then 1 else -1
	local half = math.rad(ORBIT_DEGREES) / 2
	local radius = math.clamp(height * 1.8 + 7, 10, 26)
	local plan = {center = center, front = front, from = -side * half, to = side * half, radius = radius, lift = radius * 0.3 + 1}
	local ignored: {Instance} = table.clone(landing.ignore or {})
	local character = Players.LocalPlayer.Character
	if character then table.insert(ignored, character) end
	for step = 0, 4 do
		local probe = shot(plan, step / 4).Position
		local hit = obstacle(center, probe, ignored)
		if hit then radius = math.min(radius, plan.radius * (hit.Distance - 1.2) / (probe - center).Magnitude) end
	end
	if radius < math.max(6, height * 1.2 + 3) then return nil end
	plan.radius, plan.lift = radius, radius * 0.3 + 1
	return plan
end

function RollCamera:Orbit(camera: Camera, landing, seconds: number)
	local plan = self:PlanOrbit(camera, landing)
	if not plan then return end
	local layer = self:Layer(camera)
	local orbit = {plan = plan, angle = Instance.new("NumberValue"), blend = Instance.new("NumberValue"), tweens = {}, ending = false}
	layer.orbit = orbit
	local function play(value: NumberValue, goal: number, time: number, style: Enum.EasingStyle,
		direction: Enum.EasingDirection, delay: number, done: (() -> ())?)
		local tween = TweenService:Create(value, TweenInfo.new(time, style, direction, 0, false, delay), {Value = goal})
		table.insert(orbit.tweens, tween)
		if done then
			tween.Completed:Once(function(state)
				if state == Enum.PlaybackState.Completed and layer.orbit == orbit then done() end
			end)
		end
		tween:Play()
	end
	local hold = math.max(0, seconds - ORBIT_DELAY - ORBIT_IN_SECONDS - ORBIT_OUT_SECONDS)
	play(orbit.angle, 1, seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0)
	play(orbit.blend, 1, ORBIT_IN_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, ORBIT_DELAY, function()
		play(orbit.blend, 0, ORBIT_OUT_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, hold, function()
			self:DropOrbit(layer, orbit)
		end)
	end)
end

-- Freeze the swing where it is and ease back to the player's own view.
function RollCamera:EndOrbit()
	local layer = self.layer
	local orbit = layer and layer.orbit
	if not layer or not orbit or orbit.ending then return end
	orbit.ending = true
	for _, tween in orbit.tweens do tween:Cancel() end
	local tween = TweenService:Create(orbit.blend,
		TweenInfo.new(ORBIT_EXIT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Value = 0})
	table.insert(orbit.tweens, tween)
	tween.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then self:DropOrbit(layer, orbit) end
	end)
	tween:Play()
end

function RollCamera:DropOrbit(layer, orbit)
	if layer.orbit ~= orbit then return end
	layer.orbit = nil
	for _, tween in orbit.tweens do tween:Cancel();tween:Destroy() end
	orbit.angle:Destroy();orbit.blend:Destroy()
	self:StopIfIdle(layer)
end

function RollCamera:Destroy()
	self:StopLayer()
	self:ClearZoom()
end

return RollCamera
