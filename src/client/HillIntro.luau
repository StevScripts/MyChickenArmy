--!strict
-- First-time King of the Hill film (docs/team/KING_OF_THE_HILL.md): ten seconds
-- on the live arena the first time a round opens for a player who has won every
-- camp or cleared the King. Presentation only: HillService marks the round
-- (state.hill.intro) and TutorialService saves tutorial.hillIntroSeen as the film
-- starts. While a round is open the arena also shows the Hill VFX: effects the
-- lead copies from ServerStorage.VFX["Weather VFX"] into
-- ReplicatedStorage.PetRoll.Assets.HillVFX (none there = no VFX). The bars, SKIP,
-- caption, Lock/Unlock and camera moves are small copies of IntroCutscene's.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PetRoll"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MapLayout = require(Shared.MapLayout)
local Theme = require(script.Parent.UITheme)

local HillIntro = {}
HillIntro.__index = HillIntro

local UP = Vector3.yAxis
local BAR_HEIGHT = 0.11
local GOLD = Theme.Arcade.gold
local SINE, QUAD = Enum.EasingStyle.Sine, Enum.EasingStyle.Quad
local OUT, INOUT = Enum.EasingDirection.Out, Enum.EasingDirection.InOut
-- October 20 pick: the Hill VFX stay over the arena for every open round, not
-- only in the film, so the film shows what players find when they get there.
local ROUND_VFX = true
local LAST_START_SECONDS = 15

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function ground(v: Vector3): Vector3
	return MapLayout.FootPosition(v.X, v.Z)
end

-- The Hill HUD's audience (HillHud:Update); they also see the round's VFX.
local function watching(state, hill): boolean
	return state.allCampsWon == true or state.kingCleared == true or hill.engaged == true
		or hill.holding == true or (hill.wins or 0) > 0 or (hill.mySeconds or 0) > 0
end

-- Chickens and characters move through every shot; only scenery blocks a lens.
local function actor(part: Instance): boolean
	local model = part:FindFirstAncestorWhichIsA("Model")
	while model do
		if model:GetAttribute("Species") ~= nil or model:FindFirstChildOfClass("Humanoid") then return true end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return false
end

-- The arena floor at the capture point (the Hill site before the arena streams in).
local function arenaCenter(): Vector3
	local world = workspace:FindFirstChild("PetRollWorld")
	local arena = world and world:FindFirstChild("KingArena")
	local anchor = arena and arena:FindFirstChild("CaptureAnchor")
	if anchor and anchor:IsA("BasePart") then return ground(anchor.Position) end
	local site = Config.IncomeOutpost.Position
	return ground(Vector3.new(site[1], site[2], site[3]))
end

function HillIntro.new(app)
	return setmetatable({app = app, playing = false, seen = false, due = false, threads = {}, tweens = {}}, HillIntro)
end

function HillIntro:Observe(state)
	local hill = state and state.hill
	local open = hill ~= nil and hill.enabled == true and hill.phase == "Open"
	self:SetVFX(self.playing or (ROUND_VFX and open and watching(state, hill)))
	-- One film per visit; the server stops asking once it saves the flag. Never in
	-- a round's last seconds, so the film cannot catch the arena changing back.
	self.due = open and hill.intro == true and not self.seen
		and (hill.endsAt or 0) - workspace:GetServerTimeNow() > LAST_START_SECONDS
	self:TryStart()
end

-- A free moment: no menu, popup, dialogue, crate, roll zoom or other film.
function HillIntro:Busy(): boolean
	local app = self.app
	if app.panel.Visible or app.research.root.Visible or app.dialogueActive == true or next(app.menuBlurOwners) ~= nil then return true end
	if app.commerce.cratePresenting or (app.intro ~= nil and app.intro:Pending()) then return true end
	-- The roll camera (RollCamera, Oct 20): a push-in/reveal zoom or its Legendary+ shake layer.
	local rollCamera = app.base and app.base.roller and app.base.roller.rollCamera
	if rollCamera and (rollCamera.zoom ~= nil or rollCamera.layer ~= nil) then return true end
	local camera = workspace.CurrentCamera
	return camera == nil or camera.CameraType ~= Enum.CameraType.Custom
end

function HillIntro:TryStart()
	if not self.due or self.playing or self.retry then return end
	if self:Busy() or os.clock() < (self.waitUntil or 0) then
		self.retry = task.delay(0.5, function() self.retry = nil;self:TryStart() end)
		return
	end
	self.playing = true
	self.thread = task.spawn(function()
		local ok, why = pcall(function() self:Run() end)
		if not ok then warn("[HillIntro] " .. tostring(why)) end
		if self.playing then self:Finish(false) end
	end)
end

-- The live arena at the map's centre, filmed from the player's own side.
function HillIntro:Resolve()
	local center = arenaCenter()
	pcall(function() Players.LocalPlayer:RequestStreamAroundAsync(center, 3) end)
	local world = workspace:FindFirstChild("PetRollWorld")
	if not (world and world:FindFirstChild("KingArena")) then return nil end
	center = arenaCenter()
	local state = self.app.state
	local toward = if state and type(state.plotIndex) == "number" then flat(center - MapLayout.HomeFrame(state.plotIndex).Position)
		else flat(workspace.CurrentCamera.CFrame.LookVector)
	if toward.Magnitude < 0.1 then toward = Vector3.new(0, 0, -1) end
	toward = toward.Unit
	return {center = center, toward = toward, side = toward:Cross(UP).Unit}
end

function HillIntro:Run()
	local scene = self:Resolve()
	if not scene or not self.due or self:Busy() then
		-- Nothing filmed or saved: try again in a moment, this round or the next.
		self.playing, self.waitUntil = false, os.clock() + 5
		return
	end
	self.seen = true
	self.app:Request("TutorialSignal", {signal = "HillIntroStarted"})
	self:Lock()
	self:SetVFX(true)
	self:Film(scene)
end

-- Staging -------------------------------------------------------------------

function HillIntro:Track(tween: Tween): Tween
	table.insert(self.tweens, tween)
	tween:Play()
	return tween
end

function HillIntro:Tween(item: Instance, seconds: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	return self:Track(TweenService:Create(item, TweenInfo.new(seconds, style or SINE, direction or INOUT), goal))
end

function HillIntro:Spawn(callback)
	local thread = task.spawn(callback)
	table.insert(self.threads, thread)
	return thread
end

function HillIntro:Wait(at: number)
	local remaining = at - (os.clock() - self.clock)
	if remaining > 0 then task.wait(remaining) end
end

-- Reuses the first-visit film's cues (MyChickenArmyAudio.Intro/<scene>).
function HillIntro:Sound(name: string)
	local cue = "Intro_" .. name
	self.app.audio:Play(cue, nil, {noFallback = true, voiceKey = cue})
end

function HillIntro:PlayTrack(name: string, fade: number)
	local audio = self.app.audio
	self:StopTrack(0.4)
	if not audio.musicEnabled then return end
	local library = SoundService:FindFirstChild("MyChickenArmyAudio")
	local template = library and library:FindFirstChild(name, true)
	if not template or not template:IsA("Sound") or template.SoundId == "" then return end
	local sound = template:Clone()
	sound.Looped, sound.SoundGroup, sound.Volume = false, audio.musicGroup, 0
	sound.Parent = audio.folder or SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(fade), {Volume = template.Volume}):Play()
	self.music = sound
end

function HillIntro:StopTrack(fade: number)
	local sound = self.music
	self.music = nil
	if not sound then return end
	local tween = TweenService:Create(sound, TweenInfo.new(fade), {Volume = 0})
	tween.Completed:Once(function() sound:Destroy() end)
	tween:Play()
end

-- Clones the Studio-owned Hill VFX over the arena. Each effect stands centred on
-- the arena floor unless it keeps its own place (attribute KeepPosition), so the
-- lead only drops effects into the folder. Removal lets live particles fade.
function HillIntro:SetVFX(on: boolean)
	if on == (self.vfx ~= nil) then return end
	if not on then
		local vfx = self.vfx
		self.vfx = nil
		local linger = 0
		for _, item in vfx:GetDescendants() do
			if item:IsA("ParticleEmitter") then item.Enabled = false;linger = math.max(linger, item.Lifetime.Max)
			elseif item:IsA("Beam") or item:IsA("Trail") then item.Enabled = false end
		end
		task.delay(math.min(linger, 12), function() vfx:Destroy() end)
		return
	end
	local assets = ReplicatedStorage.PetRoll:FindFirstChild("Assets")
	local source = assets and assets:FindFirstChild("HillVFX")
	if not source or self.vfxFailed then return end
	-- Runs inside AppController:Receive; a bad asset must never break state updates.
	local ok, vfx = pcall(function()
		local clone = source:Clone()
		clone.Name = "PetRollHillVFX"
		local floor = arenaCenter()
		for _, item in clone:GetDescendants() do
			if item:IsA("BasePart") then
				item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery, item.CastShadow = true, false, false, false, false
				-- A plain Part that holds emitters is only their volume; never draw its box.
				if item.ClassName == "Part" and item:FindFirstChildWhichIsA("ParticleEmitter") then item.Transparency = 1 end
			end
		end
		for _, item in clone:GetChildren() do
			if item:GetAttribute("KeepPosition") == true then continue end
			if item:IsA("Model") then
				local box, size = item:GetBoundingBox()
				item:PivotTo(item:GetPivot() + (floor + UP * size.Y / 2 - box.Position))
			elseif item:IsA("BasePart") then
				item.Position = floor + UP * item.Size.Y / 2
			end
		end
		clone.Parent = workspace
		return clone
	end)
	if not ok then
		self.vfxFailed = true
		warn("[HillIntro] Hill VFX unavailable: " .. tostring(vfx))
		return
	end
	self.vfx = vfx
end

-- Camera ------------------------------------------------------------------

function HillIntro:Ignored(): {Instance}
	local ignored: {Instance} = {}
	for _, player in Players:GetPlayers() do
		if player.Character then table.insert(ignored, player.Character) end
	end
	for _, item in {workspace:FindFirstChild("PetRollEggVisuals"), self.vfx} do
		if item then table.insert(ignored, item) end
	end
	return ignored
end

-- The first visible piece of scenery between two points.
function HillIntro:Obstacle(from: Vector3, to: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored = self:Ignored()
	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignored
		local hit = workspace:Raycast(from, to - from, params)
		if not hit then return nil end
		if hit.Instance.Transparency < 0.5 and hit.Instance.LocalTransparencyModifier < 1 and not actor(hit.Instance) then return hit end
		table.insert(ignored, hit.Instance)
	end
	return nil
end

-- Pull a lens in front of any prop between it and its subject.
function HillIntro:Clear(focus: Vector3, position: Vector3): Vector3
	local offset = position - focus
	if offset.Magnitude < 0.05 then return position end
	local hit = self:Obstacle(focus, position)
	return if hit then hit.Position - offset.Unit * 0.8 else position
end

function HillIntro:Inside(position: Vector3): boolean
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = self:Ignored()
	for _, part in workspace:GetPartBoundsInRadius(position, 0.6, overlap) do
		if part.Transparency < 0.5 and part.LocalTransparencyModifier < 1 and not actor(part) then return true end
	end
	return false
end

-- Slide a lens toward its subject until it is out of the scenery.
function HillIntro:Settle(focus: Vector3, position: Vector3): Vector3
	for _ = 1, 12 do
		if not self:Inside(position) then return position end
		position = position:Lerp(focus, 0.15)
	end
	return position
end

function HillIntro:Cut(position: Vector3, focus: Vector3, fov: number?)
	position = self:Settle(focus, self:Clear(focus, position))
	-- A dolly still finishing would overwrite the cut on its last frame.
	if self.cameraTween then self.cameraTween:Cancel();self.cameraTween = nil end
	local camera = workspace.CurrentCamera
	camera.CFrame = CFrame.lookAt(position, focus)
	camera.FieldOfView = fov or 70
end

-- Reduced motion holds the shot's end framing instead of moving there.
function HillIntro:Dolly(position: Vector3, focus: Vector3, seconds: number, style: Enum.EasingStyle?, fov: number?)
	if self.app.reducedMotion then self:Cut(position, focus, fov);return end
	position = self:Settle(focus, self:Clear(focus, position))
	local goal: any = {CFrame = CFrame.lookAt(position, focus)}
	if fov then goal.FieldOfView = fov end
	if self.cameraTween then self.cameraTween:Cancel() end
	self.cameraTween = self:Tween(workspace.CurrentCamera, seconds, goal, style or SINE, INOUT)
end

-- Screen chrome and player input --------------------------------------------

-- Bottom-bar caption: nil fades it out; new text fades the old line out first.
function HillIntro:Caption(text: string?)
	local caption, outline = self.caption, self.captionOutline
	if not caption or not caption.Parent then return end
	self.captionSerial += 1
	local serial = self.captionSerial
	local function fade(goal: number, seconds: number)
		if self.app.reducedMotion then
			caption.TextTransparency = goal
			if outline then outline.Transparency = goal end
			return
		end
		self:Tween(caption, seconds, {TextTransparency = goal}, QUAD, OUT)
		if outline then self:Tween(outline, seconds, {Transparency = goal}, QUAD, OUT) end
	end
	local shown = caption.TextTransparency < 1
	if not text then fade(1, 0.35);return end
	self:Spawn(function()
		if shown and not self.app.reducedMotion then
			fade(1, 0.2)
			task.wait(0.22)
			if serial ~= self.captionSerial or not caption.Parent then return end
		end
		caption.Text = text
		fade(0, 0.4)
	end)
end

-- Big gold title between the bars (the Hill HUD's lettering); nil hides it.
function HillIntro:Title(text: string?)
	local title = self.title
	if not title or not title.Parent then return end
	title.Visible = text ~= nil
	if not text then return end
	title.Text = text
	Theme.Motion:PopScale(title, 0.55, 0.4)
end

-- Black out (0) or reveal (1) behind the bars.
function HillIntro:Fade(goal: number, seconds: number)
	if self.cover then self:Tween(self.cover, seconds, {BackgroundTransparency = goal}, QUAD, OUT) end
end

function HillIntro:Lock()
	local app = self.app
	local camera = workspace.CurrentCamera
	self.cameraFov = camera.FieldOfView
	-- Full device screen, so the bars and cover reach past phone notches.
	-- MarchFilm (the tutorial's march) reuses this staging under its own layer name.
	local layer = Theme.InsetContainer(app.gui, self.layerName or "HillIntro", Enum.ScreenInsets.None)
	layer.ZIndex = 90
	self.layer = layer
	local cover = Instance.new("Frame")
	cover.Name, cover.Size, cover.BackgroundColor3 = "Cover", UDim2.fromScale(1, 1), Color3.new(0, 0, 0)
	cover.BackgroundTransparency, cover.BorderSizePixel, cover.ZIndex, cover.Parent = 1, 0, 95, layer
	self.cover = cover
	self.bars = {}
	for _, spec in {{"Top", 0}, {"Bottom", 1}} do
		local bar = Instance.new("Frame")
		bar.Name, bar.AnchorPoint = spec[1] .. "Bar", Vector2.new(0, spec[2])
		bar.Position, bar.Size = UDim2.fromScale(0, spec[2]), UDim2.fromScale(1, if app.reducedMotion then BAR_HEIGHT else 0)
		bar.BackgroundColor3, bar.BorderSizePixel, bar.ZIndex, bar.Parent = Color3.new(0, 0, 0), 0, 91, layer
		table.insert(self.bars, bar)
		if not app.reducedMotion then self:Tween(bar, 0.3, {Size = UDim2.fromScale(1, BAR_HEIGHT)}, QUAD, OUT) end
	end
	-- SKIP stays centered in the full-width bar but inside the safe width,
	-- clear of rounded corners and notches.
	local skipColumn = Theme.Container(layer, "SafeColumn")
	skipColumn.ZIndex = 96
	local function fitSkipColumn()
		local area = GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
		skipColumn.Position = UDim2.fromOffset(area.Min.X - layer.AbsolutePosition.X, 0)
		skipColumn.Size = UDim2.new(0, area.Max.X - area.Min.X, 1, 0)
	end
	layer:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitSkipColumn)
	fitSkipColumn()
	local skip = Instance.new("TextButton")
	skip.Name, skip.Text, skip.Font, skip.TextScaled = "Skip", "SKIP", Theme.Font, true
	skip.AnchorPoint, skip.Position, skip.Size = Vector2.new(1, 0.5), UDim2.fromScale(0.975, 1 - BAR_HEIGHT / 2), UDim2.fromScale(0.1, BAR_HEIGHT * 0.5)
	skip.TextColor3, skip.BackgroundColor3, skip.BackgroundTransparency = Color3.new(1, 1, 1), Color3.new(0, 0, 0), 0.2
	skip.AutoButtonColor, skip.ZIndex, skip.Parent = false, 96, skipColumn
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio, aspect.Parent = 3.2, skip
	Theme.Stroke(skip, Color3.new(1, 1, 1), 2)
	-- Aspect-constrained, so it keeps its right-edge anchor; scale grows from there.
	Theme.Motion:BindButton(skip, Theme.Motion:ScaleOf(skip))
	skip.Activated:Connect(function() if self.playing then app.audio:Play("Click");self:Finish(true) end end)
	-- One caption line, centred in the bottom bar and clear of SKIP on the right.
	local caption = Theme.Label(skipColumn, "Caption", "", 30, Color3.new(1, 1, 1))
	caption.AnchorPoint, caption.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 1 - BAR_HEIGHT / 2)
	caption.Size, caption.ZIndex = UDim2.fromScale(0.68, BAR_HEIGHT * 0.5), 96
	caption.TextXAlignment, caption.TextScaled, caption.TextWrapped = Enum.TextXAlignment.Center, true, false
	caption.TextTransparency = 1
	local captionLimit = Instance.new("UITextSizeConstraint")
	captionLimit.MaxTextSize, captionLimit.Parent = 34, caption
	local captionOutline = caption:FindFirstChild("TextOutline") :: UIStroke?
	if captionOutline then captionOutline.Color, captionOutline.Transparency = Color3.new(0, 0, 0), 1 end
	self.caption, self.captionOutline, self.captionSerial = caption, captionOutline, 0
	local title = Theme.Display(skipColumn, "Title", "", 60, GOLD)
	title.AnchorPoint, title.Position, title.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.27), UDim2.fromScale(0.7, 0.12)
	title.TextXAlignment, title.TextScaled, title.TextWrapped = Enum.TextXAlignment.Center, true, false
	title.ZIndex, title.Visible = 96, false
	self.title = title
	-- The HUD and its Hill banner come back when the film hands over.
	local shell = app.gui:FindFirstChild("Shell")
	if shell then shell.Visible = false end
	self.coreGui = {}
	for _, kind in Enum.CoreGuiType:GetEnumItems() do
		if kind ~= Enum.CoreGuiType.All then
			local ok, enabled = pcall(function() return StarterGui:GetCoreGuiEnabled(kind) end)
			if ok then self.coreGui[kind] = enabled end
		end
	end
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
	self.promptsEnabled = ProximityPromptService.Enabled
	ProximityPromptService.Enabled = false
	local scripts = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local module = scripts and scripts:FindFirstChild("PlayerModule")
	local ok, controls = pcall(function() return (require(module :: any) :: any):GetControls() end)
	if ok and controls then self.controls = controls;controls:Disable() end
	app.audio.musicHold = true
	if app.audio.music then app.audio.music:Pause() end
	self:PlayTrack("Forward Advance", 0.6)
	camera.CameraType = Enum.CameraType.Scriptable
end

function HillIntro:Unlock()
	local app = self.app
	for _, thread in self.threads do
		if thread ~= coroutine.running() then pcall(task.cancel, thread) end
	end
	table.clear(self.threads)
	for _, tween in self.tweens do tween:Cancel() end
	table.clear(self.tweens)
	self.cameraTween = nil
	self:StopTrack(0.6)
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = self.cameraFov or 70
	for kind, enabled in self.coreGui or {} do pcall(function() StarterGui:SetCoreGuiEnabled(kind, enabled) end) end
	self.coreGui = nil
	ProximityPromptService.Enabled = if self.promptsEnabled == nil then true else self.promptsEnabled
	self.promptsEnabled = nil
	if self.controls then self.controls:Enable();self.controls = nil end
	app.audio.musicHold = false
	app.audio:SetMusic(app.audio.musicEnabled)
	local shell = app.gui:FindFirstChild("Shell")
	if shell then shell.Visible = true end
end

function HillIntro:Finish(skipped: boolean)
	if not self.playing then return end
	self.playing = false
	if self.thread and self.thread ~= coroutine.running() then pcall(task.cancel, self.thread) end
	local cover, layer = self.cover, self.layer
	if skipped and cover then
		TweenService:Create(cover, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()
		task.wait(0.27)
	end
	self:Unlock()
	if layer then
		for _, bar in self.bars or {} do TweenService:Create(bar, TweenInfo.new(0.4, QUAD, OUT), {Size = UDim2.fromScale(1, 0)}):Play() end
		local skip = layer:FindFirstChild("Skip", true)
		if skip then skip:Destroy() end
		if self.title then self.title.Visible = false end
		if cover then TweenService:Create(cover, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play() end
		task.delay(0.45, function() layer:Destroy() end)
	end
	self.layer, self.cover, self.title, self.caption = nil, nil, nil, nil
	if self.app.commander then self.app.commander:Update() end
	-- The round's VFX stay for the Hill HUD's audience (or go, if ROUND_VFX is off).
	self:Observe(self.app.state)
end

-- The film ------------------------------------------------------------------

function HillIntro:Film(scene)
	self.clock = os.clock()
	local center, toward, side = scene.center, scene.toward, scene.side
	local focus = center + UP * 2
	-- 0-3.6s: from high over the player's side of the island down to the arena.
	self:Fade(0, 0.25)
	self:Wait(0.25)
	self:Cut(center - toward * 95 + UP * 58, focus, 70)
	self:Dolly(center - toward * 52 + UP * 24, focus, 3.35, QUAD, 58)
	self:Fade(1, 0.4)
	self:Wait(0.7)
	self:Title("THE HILL IS OPEN!")
	self:Sound("KingAppears")
	self:Wait(3.6)
	-- 3.6-6.8s: a low pass beside the Hill Guards.
	self:Title(nil)
	self:Cut(center - toward * 24 - side * 14 + UP * 5, focus, 62)
	self:Dolly(center - toward * 21 + side * 14 + UP * 4.5, focus, 3.2, SINE, 58)
	self:Caption("Send your Army to the Hill")
	self:Wait(6.8)
	-- 6.8-9.6s: push in on the capture point with the Hill VFX rising behind it.
	local point = center + UP * 3
	self:Cut(center - toward * 20 + side * 4 + UP * 9, point, 60)
	self:Dolly(center - toward * 11 + side * 2 + UP * 4.5, point, 2.8, SINE, 50)
	self:Caption("Hold it longest to win a Hill Roll")
	self:Sound("CrownGlint")
	self:Wait(9.6)
	self:Caption(nil)
	self:Fade(0, 0.35)
	self:Wait(10)
end

function HillIntro:Destroy()
	if self.retry then pcall(task.cancel, self.retry);self.retry = nil end
	self.due = false
	if self.playing then
		self.playing = false
		if self.thread and self.thread ~= coroutine.running() then pcall(task.cancel, self.thread) end
		self:Unlock()
		if self.layer then self.layer:Destroy() end
		self.layer, self.cover, self.title, self.caption = nil, nil, nil, nil
	end
	if self.vfx then self.vfx:Destroy();self.vfx = nil end
end

return HillIntro
