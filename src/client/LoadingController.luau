--!strict
-- A world-backed loading veil that preloads the opening assets.
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("PetRoll"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(script.Parent.UITheme)

local LoadingController = {}
LoadingController.__index = LoadingController

local LOGO = "rbxassetid://109846889640981"
local SKIP_AFTER = 7
local PRELOAD_BATCH = 8
local ORBIT_SECONDS = 36
local ORBIT_RADIUS = Config.Map.IslandRadius * 1.5
local ORBIT_HEIGHT = Config.Map.IslandRadius * 0.95

local function contentKey(item: Instance)
	local content
	if item:IsA("ImageLabel") or item:IsA("ImageButton") then
		content = item.Image
	elseif item:IsA("Sound") then
		content = item.SoundId
	elseif item:IsA("MeshPart") then
		-- MeshPart.MeshId is not readable in a client script. Preload the
		-- instance itself so ContentProvider can discover its content.
		return item
	elseif item:IsA("SpecialMesh") then
		content = item.MeshId .. "|" .. item.TextureId
	elseif item:IsA("Decal") or item:IsA("Texture") or item:IsA("ParticleEmitter")
		or item:IsA("Beam") or item:IsA("Trail") then
		content = item.Texture
	elseif item:IsA("Animation") then
		content = item.AnimationId
	end
	if not content or content == "" or content == "|" then return nil end
	return item.ClassName .. ":" .. content
end

local function openingAssets(gui: ScreenGui, state, intro): {Instance}
	local assets = {}
	local seen = {}
	local function add(item: Instance)
		local key = contentKey(item)
		if not key or seen[key] then return end
		seen[key] = true
		table.insert(assets, item)
	end
	local function addTree(root: Instance?)
		if not root then return end
		add(root)
		for _, item in root:GetDescendants() do add(item) end
	end
	addTree(gui:FindFirstChild("LoadingOverlay"))
	local shell = gui:FindFirstChild("Shell")
	if shell then addTree(shell:FindFirstChild("HUD")) end
	local library = SoundService:FindFirstChild("MyChickenArmyAudio")
		or SoundService:WaitForChild("MyChickenArmyAudio", 2)
	if library then
		for _, name in {"Music", "Collection", "Rolling", "UI"} do
			addTree(library:FindFirstChild(name, true))
		end
		if intro and intro.eligible then addTree(library:FindFirstChild("Intro")) end
	end
	local world = workspace:FindFirstChild("PetRollWorld")
	if world and type(state.plotIndex) == "number" then
		addTree(world:FindFirstChild("Plot" .. state.plotIndex))
		if intro and intro.eligible then
			addTree(world:FindFirstChild("Lane" .. state.plotIndex))
			addTree(world:FindFirstChild("KingArena"))
		end
	end
	return assets
end

-- The loading logo sits over the real island, so give it a slow aerial view
-- instead of leaving the camera on the newly spawned character.
function LoadingController:StartOrbit()
	if self.orbitAngle then return end
	local camera = workspace.CurrentCamera
	if not camera then return end
	self.cameraFov = camera.FieldOfView
	task.spawn(function()
		pcall(function() Players.LocalPlayer:RequestStreamAroundAsync(Vector3.new(0, 2, 0), 4) end)
	end)
	local angle = Instance.new("NumberValue")
	angle.Value = 0
	self.orbitAngle = angle
	self.orbitConnection = angle.Changed:Connect(function(value)
		local current = workspace.CurrentCamera
		if not current then return end
		if current.CameraType ~= Enum.CameraType.Scriptable then current.CameraType = Enum.CameraType.Scriptable end
		current.FieldOfView = 70
		local position = Vector3.new(math.cos(value) * ORBIT_RADIUS, ORBIT_HEIGHT,
			math.sin(value) * ORBIT_RADIUS)
		current.CFrame = CFrame.lookAt(position, Vector3.new(0, 2, 0))
		current.Focus = CFrame.new(0, 2, 0)
	end)
	angle.Value = 0.001
	self.orbitTween = TweenService:Create(angle,
		TweenInfo.new(ORBIT_SECONDS, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
		{Value = math.pi * 2})
	self.orbitTween:Play()
end

function LoadingController:StopOrbit()
	if self.orbitTween then self.orbitTween:Cancel(); self.orbitTween = nil end
	if self.orbitConnection then self.orbitConnection:Disconnect(); self.orbitConnection = nil end
	if self.orbitAngle then self.orbitAngle:Destroy(); self.orbitAngle = nil end
	local camera = workspace.CurrentCamera
	if camera and self.cameraFov then camera.FieldOfView = self.cameraFov end
end

function LoadingController.new(gui: ScreenGui)
	local previous = gui:FindFirstChild("LoadingOverlay")
	if previous then previous:Destroy() end
	local previousBlur = Lighting:FindFirstChild("PetRollLoadingBlur")
	if previousBlur then previousBlur:Destroy() end

	-- Blur the live island immediately, while the other client modules initialize.
	local blur = Instance.new("BlurEffect")
	blur.Name, blur.Size, blur.Parent = "PetRollLoadingBlur", 18, Lighting

	local overlay = Instance.new("CanvasGroup")
	overlay.Name = "LoadingOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(6, 12, 8)
	overlay.BackgroundTransparency = 0.36
	overlay.BorderSizePixel = 0
	overlay.GroupTransparency = 0
	overlay.Active = true
	overlay.ZIndex = 100
	overlay.Parent = gui
	Theme.FitToInset(overlay, gui, Enum.ScreenInsets.None)

	local logo = Instance.new("ImageLabel")
	logo.Name, logo.Image = "ChickenArmyLogo", LOGO
	logo.BackgroundTransparency, logo.ScaleType = 1, Enum.ScaleType.Fit
	logo.AnchorPoint, logo.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.43)
	logo.Size = UDim2.fromScale(0.82, 0.54)
	logo.ZIndex = 101
	logo.Parent = overlay
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 512 / 342
	aspect.AspectType = Enum.AspectType.FitWithinMaxSize
	aspect.Parent = logo

	local track = Instance.new("Frame")
	track.Name = "ProgressTrack"
	track.AnchorPoint, track.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.795)
	track.Size = UDim2.fromScale(0.48, 0.026)
	track.BackgroundColor3 = Color3.fromRGB(15, 23, 15)
	track.BorderColor3, track.BorderSizePixel = Color3.fromRGB(0, 0, 0), 2
	track.ClipsDescendants = true
	track.ZIndex = 101
	track.Parent = overlay

	local segment = Instance.new("Frame")
	segment.Name = "LoadingFill"
	segment.Position, segment.Size = UDim2.fromScale(0, 0), UDim2.fromScale(0, 1)
	segment.BackgroundColor3 = Theme.ReferenceColors.Army
	segment.BorderSizePixel = 0
	segment.ZIndex = 102
	segment.Parent = track

	local percentage = Instance.new("TextLabel")
	percentage.Name, percentage.Text = "LoadingPercentage", "0%"
	percentage.AnchorPoint, percentage.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.74)
	percentage.Size = UDim2.fromScale(0.26, 0.055)
	percentage.BackgroundTransparency, percentage.BorderSizePixel = 1, 0
	percentage.Font, percentage.TextScaled = Theme.Font, true
	percentage.TextColor3 = Color3.new(1, 1, 1)
	percentage.TextStrokeColor3, percentage.TextStrokeTransparency = Color3.new(0, 0, 0), 0
	percentage.ZIndex = 102
	percentage.Parent = overlay

	local status = Instance.new("TextLabel")
	status.Name, status.Text = "LoadingStatus", "Loading your flock…"
	status.AnchorPoint, status.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.85)
	status.Size = UDim2.fromScale(0.82, 0.055)
	status.BackgroundTransparency, status.BorderSizePixel = 1, 0
	status.Font = Theme.Font
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextScaled, status.TextWrapped = true, true
	status.TextStrokeColor3, status.TextStrokeTransparency = Color3.new(0, 0, 0), 0
	status.ZIndex = 102
	status.Parent = overlay
	local skip = Instance.new("TextButton")
	skip.Name, skip.Text = "SkipLoading", "SKIP LOADING"
	skip.AnchorPoint, skip.Position = Vector2.new(1, 1), UDim2.fromScale(0.965, 0.95)
	skip.Size = UDim2.fromScale(0.18, 0.085)
	skip.BackgroundColor3, skip.BackgroundTransparency = Color3.fromRGB(10, 18, 13), 0.12
	skip.TextColor3 = Color3.new(1, 1, 1)
	skip.Font, skip.TextScaled = Theme.Font, true
	skip.AutoButtonColor, skip.Visible, skip.ZIndex = false, false, 103
	skip.Parent = overlay
	Theme.Stroke(skip, Theme.ReferenceColors.Army, 2)
	local skipAspect = Instance.new("UIAspectRatioConstraint")
	skipAspect.AspectRatio, skipAspect.AspectType = 2.8, Enum.AspectType.FitWithinMaxSize
	skipAspect.Parent = skip
	-- Shared hover/press feel; UIScale keeps the aspect-constrained box intact.
	Theme.Motion:BindButton(skip, Theme.Motion:ScaleOf(skip))

	-- Lighting blur affects the 3D yard, not ScreenGui descendants. Keep the
	-- ready HUD out of the backdrop until the loading veil reveals gameplay.
	local function hideShell(child)
		if child.Name == "Shell" then child.Visible = false end
	end
	local shellConnection = gui.ChildAdded:Connect(hideShell)
	local shell = gui:FindFirstChild("Shell")
	if shell then hideShell(shell) end

	-- October 21 game feel: the logo breathes gently while the island loads.
	Theme.Motion:Breathe(logo, 1.03, 1.4)
	local self = setmetatable({gui = gui, overlay = overlay, blur = blur, logo = logo,
		shellConnection = shellConnection,
		status = status, percentage = percentage, fill = segment, skip = skip,
		closing = false, profileReady = false, assetsReady = false, skipRequested = false}, LoadingController)
	skip.Activated:Connect(function() self:Skip() end)
	task.delay(SKIP_AFTER, function()
		if overlay.Parent and not self.closing and not self.failed then Theme.Motion:Appear(skip, true) end
	end)
	self:StartOrbit()
	return self
end

function LoadingController:SetProgress(completed: number, total: number)
	if self.closing then return end
	local progress = if total == 0 then 1 else math.clamp(completed / total, 0, 1)
	self.percentage.Text = string.format("%d%%", math.floor(progress * 100))
	-- October 21 game feel: the shared bar tween; each gain flashes the fill.
	Theme.Motion:Progress(self.fill, progress, 0.25, Color3.new(1, 1, 1))
	self.status.Text = if progress >= 1 then "Ready!" else string.format("Loading %d/%d items…", completed, total)
end

function LoadingController:StartPreload(state)
	if self.preloading or self.closing then return end
	self.preloading = true
	task.spawn(function()
		local assets = openingAssets(self.gui, state, self.app.intro)
		local total = #assets
		self:SetProgress(0, total)
		for first = 1, total, PRELOAD_BATCH do
			if self.closing or self.skipRequested then return end
			local batch = {}
			for index = first, math.min(first + PRELOAD_BATCH - 1, total) do
				table.insert(batch, assets[index])
			end
			local ok, err = pcall(function() ContentProvider:PreloadAsync(batch) end)
			if not ok then warn("[LoadingController] Preload failed: " .. tostring(err)) end
			self:SetProgress(math.min(first + #batch - 1, total), total)
		end
		if self.closing or self.skipRequested then return end
		self.assetsReady = true
		self:MaybeDismiss()
	end)
end

function LoadingController:Skip()
	if self.closing or self.failed or not self.skip.Visible then return end
	self.skipRequested = true
	self.skip.Text = "WAITING…"
	if not self.profileReady then self.status.Text = "Waiting for your flock…" end
	self:MaybeDismiss()
end

function LoadingController:Bind(app)
	self.app = app
	if not self.orbitAngle then self:StartOrbit() end
	-- Hand the blur to the existing shared menu owner without a visible jump.
	app:SetMenuBlur("loading", true)
	local earlyBlur = self.blur
	local handoff = TweenService:Create(earlyBlur,
		TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0})
	handoff.Completed:Once(function() earlyBlur:Destroy() end)
	handoff:Play()

	local function receive(packet)
		if type(packet) ~= "table" or type(packet.state) ~= "table" then return end
		self:ConsiderState(packet.state)
	end
	self.connection = app.remotes:WaitForChild("StateChanged").OnClientEvent:Connect(receive)
	-- AppController may already have received Sync during Start().
	if app.state then self:ConsiderState(app.state) end
	if app.reducedMotion and self.orbitTween then self.orbitTween:Pause() end
	if app.reducedMotion then Theme.Motion:StopBreathe(self.logo) end
end

function LoadingController:ConsiderState(state)
	local saveStatus = state.saveStatus
	if saveStatus == "saved" or saveStatus == "studio-session" then
		self.profileReady = true
		self:MaybeDismiss()
		if not self.closing then self:StartPreload(state) end
	elseif saveStatus == "error" and not self.profileReady then
		self.failed = true
		Theme.Motion:Appear(self.skip, false)
		self.status.Text = state.saveMessage or "Unable to load your flock. Please rejoin."
	end
end

function LoadingController:MaybeDismiss()
	if self.closing or self.failed or not self.profileReady or not (self.assetsReady or self.skipRequested) then return end
	self.closing = true
	self.status.Text = if self.skipRequested then "Continuing…" else "Ready!"
	self:Dismiss()
end

function LoadingController:Dismiss()
	if self.connection then self.connection:Disconnect(); self.connection = nil end
	self.shellConnection:Disconnect()
	-- A first-visit intro starts behind the veil and keeps the HUD until it ends.
	self:StopOrbit()
	local intro = self.app.intro
	local playing = intro ~= nil and intro:Begin()
	if not playing and workspace.CurrentCamera then
		local camera = workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then camera.CameraSubject = humanoid end
		camera.CameraType = Enum.CameraType.Custom
	end
	local shell = self.gui:FindFirstChild("Shell")
	if shell then shell.Visible = not playing end
	self.app:SetMenuBlur("loading", false)
	-- October 21 game feel: the veil lifts with a cue and the logo swells as it fades.
	self.app:Cue("MenuClose")
	Theme.Motion:StopBreathe(self.logo)
	if self.app.reducedMotion then self.overlay:Destroy(); return end
	Theme.Motion:Tween(Theme.Motion:ScaleOf(self.logo), "pop", {Scale = 1.08}, 0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fade = TweenService:Create(self.overlay,
		TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{GroupTransparency = 1})
	fade.Completed:Once(function() self.overlay:Destroy() end)
	fade:Play()
end

return LoadingController
