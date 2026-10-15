--!strict
-- First-visit story, "One Chicken Isn't an Army" (no dialogue; five short
-- bottom-bar captions since October 14): a starter chicken
-- marches on Cluck Camp alone, gets launched home, and the Commander guide
-- becomes its plan. Presentation only. Every actor is a local clone; the server
-- records introSeen and never grants anything for watching or skipping.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local SoundService = game:GetService("SoundService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("PetRoll"):WaitForChild("Shared")
local Config = require(Shared.Config)
local MapLayout = require(Shared.MapLayout)
local March = require(Shared.ArmyMarch)
local CampCommand = require(Shared.CampCommand)
local Guide = require(Shared.TutorialGuide)
local Theme = require(script.Parent.UITheme)
local EggView = require(script.Parent.EggView)

local Intro = {}
Intro.__index = Intro

local UP = Vector3.yAxis
local KING_SCALE = 2.6
local DUST = Color3.fromRGB(214, 196, 160)
local BAR_HEIGHT = 0.11
local GOLD = Theme.Arcade.gold
local LINEAR = Enum.EasingStyle.Linear
local SINE = Enum.EasingStyle.Sine
local QUAD = Enum.EasingStyle.Quad
local IN, OUT, INOUT = Enum.EasingDirection.In, Enum.EasingDirection.Out, Enum.EasingDirection.InOut
local SCALED_ATTRIBUTES = {"Size", "ClipScale", "FootOffset", "VisualHeight", "VisualWidth", "VisualDepth"}
local CLEARED_ATTRIBUTES = {"PetId", "OwnerId", "OwnerUserId", "BattleId", "UnitId", "Side", "Defeated", "CampGuard",
	"AttackStartedAt", "LocalAttackAt", "Recruiting", "PresentationHidden", "AtHome", "LaneOwnerIndex"}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function ground(v: Vector3): Vector3
	return MapLayout.FootPosition(v.X, v.Z)
end

local function bump(model: Model, attribute: string)
	model:SetAttribute(attribute, (model:GetAttribute(attribute) or 0) + 1)
end

-- Fresh starter-army profiles only; established and legacy saves never see it.
function Intro.Eligible(state): boolean
	if not Config.Features.IntroCutscene or not state then return false end
	if RunService:IsStudio() and workspace:GetAttribute("PetRollSkipIntro") == true then return false end
	if state.saveStatus ~= "saved" and state.saveStatus ~= "studio-session" then return false end
	local t = state.tutorial or {}
	return t.starterArmy == true and not t.introSeen and not t.guideCompleted and not t.guideSkipped
		and not t.rolled and not t.bought and not t.soldEggs and Guide.CollectedEggCount(t) == 0
		and (state.campsWon or 0) == 0 and type(state.plotIndex) == "number" and #(state.pets or {}) >= 3
end

function Intro.new(app)
	return setmetatable({app = app, playing = false, started = false, eligible = nil,
		threads = {}, tweens = {}, hidden = {}, watches = {}, brows = {}}, Intro)
end

function Intro:Observe(state)
	if not state then return end
	-- Decide on the first loaded snapshot: egg pickups during the loading veil
	-- must not disqualify a brand-new profile.
	if self.eligible == nil and (state.saveStatus == "saved" or state.saveStatus == "studio-session") then
		self.eligible = Intro.Eligible(state)
		if self.eligible then self:Prepare(state) end
	end
end

-- True while a first-visit film is still waiting behind the loading veil, so the
-- guide's Ready timestamp starts when the player actually gets control.
function Intro:Pending(): boolean
	return self.playing or (self.eligible == true and not self.started)
end

-- The loading veil hides this; StreamingEnabled must not film an empty field.
function Intro:Prepare(state)
	local home = MapLayout.HomeFrame(state.plotIndex)
	local inward = flat(home.LookVector).Unit
	for _, point in {Vector3.new(0, 2, 0), home.Position + inward * 125} do
		task.spawn(function()
			pcall(function() Players.LocalPlayer:RequestStreamAroundAsync(point, 4) end)
		end)
	end
end

-- Scene geometry comes from the player's own plot and lane, so all six homes
-- get the same film from their own side of the island.
function Intro:Resolve(state, anywhere: boolean?)
	local world = workspace:FindFirstChild("PetRollWorld")
	local index = state.plotIndex
	local plot = world and world:FindFirstChild("Plot" .. index)
	local lane = world and world:FindFirstChild("Lane" .. index)
	local camp = lane and lane:FindFirstChild("Camp1")
	local campAnchor = camp and CampCommand.Anchor(camp)
	local pets = plot and plot:FindFirstChild("Pets")
	local sell = plot and plot:FindFirstChild("sellpart", true)
	local station = plot and plot:FindFirstChild("RollStation")
	local anchors = plot and plot:FindFirstChild("Anchors", true)
	local yard = anchors and anchors:FindFirstChild("Yard")
	if not (campAnchor and pets and sell and station and yard) then return nil end
	-- The hero is the first free starter by id, so every play stars the same bird.
	local ids = {}
	for _, pet in state.pets do
		if pet.species == "Duck" and pet.investment == 0 then table.insert(ids, pet.id) end
	end
	table.sort(ids)
	local chickens = {}
	for _, id in ids do
		local model = pets:FindFirstChild(id)
		if model then table.insert(chickens, model) end
	end
	-- A Settings replay can star any three home chickens once the starters moved on.
	if self.mode == "replay" and #chickens < 3 then
		local models = {}
		for _, model in pets:GetChildren() do
			if model:IsA("Model") and not table.find(chickens, model) then table.insert(models, model) end
		end
		table.sort(models, function(a, b) return a.Name < b.Name end)
		for _, model in models do
			if #chickens >= 3 then break end
			table.insert(chickens, model)
		end
		while #chickens > 0 and #chickens < 3 do table.insert(chickens, chickens[#chickens]) end
		if #ids == 0 and chickens[1] then ids = {chickens[1]:GetAttribute("PetId") or chickens[1].Name} end
	end
	if #ids == 0 or (#chickens < 3 and not anywhere) then return nil end
	local heroSource = chickens[1]
	if anywhere then
		for _, model in world:GetDescendants() do
			if model:IsA("Model") and model:GetAttribute("PetId") == ids[1] then heroSource = model;break end
		end
		heroSource = heroSource or pets:FindFirstChildWhichIsA("Model")
		if not heroSource then return nil end
	end
	local arena = world:FindFirstChild("KingArena")
	-- The server's frozen idle arena; the live one may be conquered or mid-fight.
	local set = ReplicatedStorage:FindFirstChild("PetRollIntroSet")
	local center = (set or arena) and (set or arena):FindFirstChild("CaptureAnchor")
	local defenders = camp:FindFirstChild("Defenders")
	local guards = {}
	for _, guard in (if defenders then defenders:GetChildren() else {}) do
		if guard:IsA("Model") then table.insert(guards, guard) end
	end
	local home = MapLayout.HomeFrame(index)
	local inward = flat(home.LookVector).Unit
	return {world = world, plot = plot, lane = lane, camp = camp, campAt = campAnchor.Position,
		chickens = chickens, hero = heroSource, heroId = ids[1],
		king = if set then set:FindFirstChild("ChickenKing") elseif arena then arena:FindFirstChild("ChickenKing") else nil,
		arena = arena, set = set, index = index,
		kingAt = if center then center.Position else Vector3.new(0, 2, 0),
		guards = guards, sell = sell, station = station, yard = yard.Position,
		inward = inward, right = inward:Cross(UP).Unit}
end

-- Loading calls this as its veil fades. Returning true keeps the HUD hidden.
function Intro:Begin(): boolean
	if self.started then return false end
	self.started = true
	local state = self.app.state
	if not self.eligible or self.app.reducedMotion or not state or (state.tutorial or {}).introSeen then
		self.eligible = false
		-- The server holds a new profile's eggs for the film; tell it there is none.
		local t = state and state.tutorial or {}
		if t.starterArmy and not t.introSeen then
			self.app:Request("TutorialSignal", {signal = "IntroSkipped"})
		end
		return false
	end
	self:Play("intro")
	return true
end

function Intro:Play(mode: string)
	self.playing, self.mode = true, mode
	self:Lock()
	-- Music from the first frame; this track is near-silent for its first 3s.
	self:PlayTrack("A Military Action", 0.1, 3)
	self.thread = task.spawn(function()
		local ok, why = pcall(function() self:Run() end)
		if not ok then warn("[IntroCutscene] " .. tostring(why)) end
		if self.playing then self:Finish(false) end
	end)
end

function Intro:CanReplay(): boolean
	local state = self.app.state
	return Config.Features.IntroCutscene and not self.playing and state ~= nil
		and type(state.plotIndex) == "number" and #(state.pets or {}) > 0
end

-- Settings > Test as a new player: the real first-visit film, with its signals,
-- so the server's new-player egg hold and onboarding behave as they would live.
function Intro:PlayAsNewPlayer(): boolean
	if self.playing or not self:CanReplay() then return false end
	self.eligible, self.started = true, true
	self:Prepare(self.app.state)
	self:Play("intro")
	return true
end

-- Settings > Replay intro: the same film with no save signals.
function Intro:Replay(): boolean
	if not self:CanReplay() then return false end
	self:Prepare(self.app.state)
	self:Play("replay")
	return true
end

-- Staging -------------------------------------------------------------------

function Intro:Track(tween: Tween): Tween
	table.insert(self.tweens, tween)
	tween:Play()
	return tween
end

function Intro:Tween(item: Instance, seconds: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?, repeats: number?, reverses: boolean?): Tween
	return self:Track(TweenService:Create(item, TweenInfo.new(seconds, style or SINE, direction or INOUT, repeats or 0, reverses or false), goal))
end

function Intro:Spawn(callback)
	local thread = task.spawn(callback)
	table.insert(self.threads, thread)
	return thread
end

function Intro:Wait(at: number)
	local remaining = at - (os.clock() - self.clock)
	if remaining > 0 then task.wait(remaining) end
	-- Studio framing aid: set workspace PetRollIntroPauseAt (seconds) on the
	-- client to hold the film there; change or clear it to continue.
	local pause = if RunService:IsStudio() then workspace:GetAttribute("PetRollIntroPauseAt") else nil
	if type(pause) == "number" and at > pause then
		local held = os.clock()
		while workspace:GetAttribute("PetRollIntroPauseAt") == pause and self.playing do task.wait(0.1) end
		self.clock += os.clock() - held
	end
end

-- Hides a live model on this screen only. GUIs collapse their draw distance so the
-- server's own Enabled changes during the film still land. With watch, anything
-- added under the model mid-film is hidden too.
function Intro:Hide(model: Instance?, watch: boolean?)
	if not model or self.hidden[model] then return end
	local saved = {}
	local function hide(item: Instance)
		if saved[item] ~= nil then return end
		if item:IsA("BasePart") or item:IsA("Decal") then
			saved[item] = item.LocalTransparencyModifier
			item.LocalTransparencyModifier = 1
		elseif item:IsA("BillboardGui") or item:IsA("SurfaceGui") then
			saved[item] = item.MaxDistance
			item.MaxDistance = 0.001
		end
	end
	hide(model)
	for _, item in model:GetDescendants() do hide(item) end
	self.hidden[model] = saved
	if watch then table.insert(self.watches, model.DescendantAdded:Connect(hide)) end
end

-- Other players, their yards' flocks and live battles would make every film different.
function Intro:HideOthers(scene)
	local me = Players.LocalPlayer
	for _, player in Players:GetPlayers() do
		if player ~= me then self:Hide(player.Character, true) end
	end
	table.insert(self.watches, workspace.ChildAdded:Connect(function(child)
		local owner = Players:GetPlayerFromCharacter(child)
		if owner and owner ~= me then self:Hide(child, true) end
	end))
	local function hideWorld(child: Instance)
		local index = tonumber(child.Name:match("^Plot(%d+)$"))
		if index and index ~= scene.index then self:Hide(child:FindFirstChild("Pets"), true)
		elseif child.Name == "Battles" then self:Hide(child, true) end
	end
	for _, child in scene.world:GetChildren() do hideWorld(child) end
	table.insert(self.watches, scene.world.ChildAdded:Connect(hideWorld))
end

-- Swaps the live arena for a local clone of the frozen set. Its Royal Flock is staged
-- in place; the King is staged by the caller (or here, unscaled, with withKing).
function Intro:StageArena(scene, withKing: boolean?): Model?
	if not scene.set then return nil end
	self:Hide(scene.arena, true)
	local set = scene.set:Clone()
	local actors = {}
	for _, item in set:GetChildren() do
		if item:IsA("Model") and item:GetAttribute("Species") then table.insert(actors, item.Name);item:Destroy() end
	end
	for _, gui in set:GetDescendants() do
		if gui:IsA("BillboardGui") or gui:IsA("SurfaceGui") then gui.Enabled = false end
	end
	set.Name, set.Parent = "Arena", self.folder
	local king
	for _, name in actors do
		local source = scene.set:FindFirstChild(name)
		if name ~= "ChickenKing" then
			self:Stage(source, "Set" .. name):PivotTo(source:GetPivot())
		elseif withKing then
			king = self:Stage(source, "King");king:PivotTo(source:GetPivot())
		end
	end
	return king
end

-- The yard's live eggs would crowd the one egg the story is about. EggController
-- keeps toggling Enabled, so collapse their draw distance instead.
function Intro:HideEggs()
	local folder = workspace:FindFirstChild("PetRollEggVisuals")
	if not folder then return end
	local saved = {}
	self.eggSaved = saved
	local function hide(item)
		if item:IsA("BillboardGui") and saved[item] == nil then saved[item] = item.MaxDistance;item.MaxDistance = 0.001 end
	end
	for _, item in folder:GetDescendants() do hide(item) end
	self.eggWatch = folder.DescendantAdded:Connect(hide)
end

-- Chicken name/level tags would read as captions in a wordless film.
function Intro:HideTags(root: Instance?)
	if not root then return end
	for _, item in root:GetDescendants() do
		if item:IsA("Model") and item:GetAttribute("Species") and not self.hidden[item] then
			local saved = {}
			for _, gui in item:GetDescendants() do
				if gui:IsA("BillboardGui") then saved[gui] = gui.MaxDistance;gui.MaxDistance = 0.001 end
			end
			self.hidden[item] = saved
		end
	end
end

function Intro:Stage(source: Model, name: string): Model
	local model = source:Clone()
	model.Name = name
	local root = model.PrimaryPart
	local removed = {}
	-- The frozen set parks its tags in an attribute; staged actors get them back.
	for _, item in {model :: Instance, table.unpack(model:GetDescendants())} do
		local tags = item:GetAttribute("IntroTags")
		if type(tags) == "string" then
			for tag in tags:gmatch("[^,]+") do CollectionService:AddTag(item, tag) end
			item:SetAttribute("IntroTags", nil)
		end
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			-- Welded parts follow the anchored root, so the crown can track the head bone.
			item.Anchored = item == root
			item.CanCollide, item.CanTouch, item.CanQuery, item.Massless = false, false, false, true
			item.LocalTransparencyModifier = 0
		elseif item:IsA("Decal") then
			item.LocalTransparencyModifier = 0
		elseif item:IsA("BillboardGui") or item:IsA("SurfaceGui") then
			item.Enabled = false
		elseif item:IsA("Humanoid") or item:IsA("Highlight") or item:IsA("BaseScript") then
			table.insert(removed, item)
		end
	end
	for _, item in removed do item:Destroy() end
	for _, attribute in CLEARED_ATTRIBUTES do model:SetAttribute(attribute, nil) end
	-- DuckRig=false makes the animator read PreviewSpeed instead of physics velocity.
	model:SetAttribute("DuckRig", false)
	model:SetAttribute("Moving", false)
	model:SetAttribute("PreviewSpeed", 0)
	model.Parent = self.folder
	return model
end

function Intro:Scale(model: Model, factor: number)
	model:ScaleTo(model:GetScale() * factor)
	for _, name in SCALED_ATTRIBUTES do
		local value = model:GetAttribute(name)
		if type(value) == "number" then model:SetAttribute(name, value * factor) end
	end
	local crown = model:FindFirstChild("RoyalCrown")
	local joint = crown and crown:FindFirstChild("CrownJoint")
	local offset = joint and joint:GetAttribute("HeadOffset")
	if typeof(offset) == "CFrame" then joint:SetAttribute("HeadOffset", offset.Rotation + offset.Position * factor) end
end

function Intro:Pivot(model: Model, foot: Vector3, facing: Vector3): CFrame
	local at = foot + UP * (model:GetAttribute("FootOffset") or 1.25)
	return CFrame.lookAt(at, at + flat(facing))
end

function Intro:Place(model: Model, foot: Vector3, facing: Vector3)
	model:PivotTo(self:Pivot(model, foot, facing))
end

-- A CFrameValue tween keeps whole-model movement on TweenService.
function Intro:Move(model: Model, target: CFrame, seconds: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Parent = self.folder
	value.Changed:Connect(function(cf) if model.Parent then model:PivotTo(cf) end end)
	local tween = self:Tween(value, seconds, {Value = target}, style or SINE, direction or INOUT)
	tween.Completed:Once(function() value:Destroy() end)
	return tween
end

function Intro:Face(model: Model, direction: Vector3, seconds: number?): Tween
	local at = model:GetPivot().Position
	return self:Move(model, CFrame.lookAt(at, at + flat(direction)), seconds or 0.3, QUAD, OUT)
end

function Intro:Hop(model: Model, height: number, seconds: number)
	local base = model:GetPivot()
	self:Spawn(function()
		self:Move(model, base + UP * height, seconds / 2, QUAD, OUT).Completed:Wait()
		self:Move(model, base, seconds / 2, QUAD, IN)
	end)
end

-- Walk a ground path at a fixed speed, snapping to face each new leg.
function Intro:Walk(model: Model, points: {Vector3}, speed: number, dusty: boolean?)
	self:Spawn(function()
		model:SetAttribute("PreviewSpeed", speed)
		model:SetAttribute("Moving", true)
		for i = 2, #points do
			local a, b = points[i - 1], points[i]
			local direction = flat(b - a)
			if direction.Magnitude < 0.05 then continue end
			model:PivotTo(self:Pivot(model, a, direction))
			self:Move(model, self:Pivot(model, b, direction), (b - a).Magnitude / speed, LINEAR).Completed:Wait()
		end
		model:SetAttribute("Moving", false)
		model:SetAttribute("PreviewSpeed", 0)
	end)
	if dusty then
		self:Spawn(function()
			while model.Parent and model:GetAttribute("Moving") do
				self:Dust(model:GetPivot().Position - UP * (model:GetAttribute("FootOffset") or 1.25), 0.35, 2)
				task.wait(0.2)
			end
		end)
	end
end

-- Studio occlusion audit: set workspace PetRollIntroAudit=true on the client and
-- read Intro.AuditLog afterward. Logs anything solid between the camera and an
-- on-screen actor, and any moment the lens sits inside scenery.
function Intro:Audit()
	if not RunService:IsStudio() or workspace:GetAttribute("PetRollIntroAudit") ~= true then return end
	local log = {}
	Intro.AuditLog = log
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	self:Spawn(function()
		while self.playing and self.folder do
			task.wait(0.05)
			local camera = workspace.CurrentCamera
			local origin = camera.CFrame.Position
			local ignored: {Instance} = {self.folder}
			for model in self.hidden do table.insert(ignored, model) end
			local t = os.clock() - self.clock
			overlap.FilterDescendantsInstances = ignored
			for _, part in workspace:GetPartBoundsInRadius(origin, 0.3, overlap) do
				if part.Transparency < 0.5 and part.LocalTransparencyModifier < 1 then
					table.insert(log, {t = t, actor = "CAMERA", blocker = part:GetFullName()})
				end
			end
			for _, model in self.folder:GetChildren() do
				local root = model:IsA("Model") and model.PrimaryPart
				if root then
					local screen, visible = camera:WorldToViewportPoint(root.Position)
					if visible and screen.Z > 0 then
						local skip = table.clone(ignored)
						for _ = 1, 6 do
							params.FilterDescendantsInstances = skip
							local hit = workspace:Raycast(origin, root.Position - origin, params)
							if not hit then break end
							if hit.Instance.Transparency < 0.5 and hit.Instance.LocalTransparencyModifier < 1 then
								table.insert(log, {t = t, actor = model.Name, blocker = hit.Instance:GetFullName(),
									distance = (root.Position - origin).Magnitude})
								break
							end
							table.insert(skip, hit.Instance)
						end
					end
				end
			end
		end
	end)
end

-- Pull a camera in front of any visible prop between it and its subject, so
-- every plot's tents, stands and fences stay out of the lens.
function Intro:Clear(focus: Vector3, position: Vector3): Vector3
	local offset = position - focus
	if offset.Magnitude < 0.05 then return position end
	local hit = self:Obstacle(focus, position)
	return if hit then hit.Position - offset.Unit * 0.8 else position
end

-- Everything we film around: our clones, the hidden live models, live eggs.
function Intro:Ignored(): {Instance}
	local ignored: {Instance} = {}
	for _, item in {Players.LocalPlayer.Character, workspace:FindFirstChild("PetRollEggVisuals")} do
		if item then table.insert(ignored, item) end
	end
	-- Actors and effects never block a shot, but the staged arena's walls do.
	for _, item in (if self.folder then self.folder:GetChildren() else {}) do
		if item.Name ~= "Arena" then table.insert(ignored, item) end
	end
	for model in self.hidden do table.insert(ignored, model) end
	return ignored
end

-- The first visible part between two points, skipping see-through ones.
function Intro:Obstacle(from: Vector3, to: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignored = self:Ignored()
	for _ = 1, 8 do
		params.FilterDescendantsInstances = ignored
		local hit = workspace:Raycast(from, to - from, params)
		if not hit then return nil end
		if hit.Instance.Transparency < 0.5 and hit.Instance.LocalTransparencyModifier < 1 then return hit end
		table.insert(ignored, hit.Instance)
	end
	return nil
end

-- Puts back something hidden mid-film (Unlock restores everything else).
function Intro:Show(model: Instance)
	local saved = self.hidden[model]
	if not saved then return end
	for item, value in saved do
		if item.Parent then
			if item:IsA("LayerCollector") then (item :: any).MaxDistance = value else (item :: any).LocalTransparencyModifier = value end
		end
	end
	self.hidden[model] = nil
end

-- Hides, for one shot, whatever still stands between these lens positions and the
-- targets: the smallest building piece (under 40 studs) that owns each blocking part.
function Intro:ClearView(lenses: {Vector3}, targets: {Vector3}): {Instance}
	local cleared = {}
	for _, lens in lenses do
		for _, target in targets do
			for _ = 1, 8 do
				local hit = self:Obstacle(lens, target)
				if not hit then break end
				local piece: Instance = hit.Instance
				while piece.Parent and piece.Parent:IsA("Model") and piece.Parent ~= workspace do
					local size = (piece.Parent :: Model):GetExtentsSize()
					if size.Magnitude > 40 then break end
					piece = piece.Parent
				end
				self:Hide(piece)
				table.insert(cleared, piece)
			end
		end
	end
	return cleared
end

function Intro:Inside(position: Vector3): boolean
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = self:Ignored()
	for _, part in workspace:GetPartBoundsInRadius(position, 0.6, overlap) do
		if part.Transparency < 0.5 and part.LocalTransparencyModifier < 1 then return true end
	end
	return false
end

-- Slide a lens toward its subject until it is out of the scenery.
function Intro:Settle(focus: Vector3, position: Vector3): Vector3
	for _ = 1, 12 do
		if not self:Inside(position) then return position end
		position = position:Lerp(focus, 0.15)
	end
	return position
end

-- First candidate lens with nothing solid in front of any of the targets.
function Intro:Pick(candidates: {Vector3}, targets: {Vector3}): Vector3
	for _, spot in candidates do
		local clear = not self:Inside(spot)
		for _, target in targets do
			if not clear then break end
			if self:Obstacle(spot, target) then clear = false end
		end
		if clear then return spot end
	end
	return candidates[1]
end

-- Which side of a subject has the longer clear view.
function Intro:OpenSide(focus: Vector3, side: Vector3, distance: number): Vector3
	local left = (self:Clear(focus, focus - side * distance) - focus).Magnitude
	local right = (self:Clear(focus, focus + side * distance) - focus).Magnitude
	return if left > right + 0.5 then -side else side
end

-- anchor: where clearance is measured from when the focus is far away.
function Intro:Cut(position: Vector3, focus: Vector3, fov: number?, anchor: Vector3?)
	position = self:Settle(anchor or focus, self:Clear(anchor or focus, position))
	-- A dolly still finishing would overwrite the cut on its last frame.
	if self.cameraTween then self.cameraTween:Cancel();self.cameraTween = nil end
	local camera = workspace.CurrentCamera
	camera.CFrame = CFrame.lookAt(position, focus)
	camera.FieldOfView = fov or 70
end

function Intro:Dolly(position: Vector3, focus: Vector3, seconds: number, style: Enum.EasingStyle?, fov: number?, anchor: Vector3?)
	position = self:Settle(anchor or focus, self:Clear(anchor or focus, position))
	local goal: any = {CFrame = CFrame.lookAt(position, focus)}
	if fov then goal.FieldOfView = fov end
	if self.cameraTween then self.cameraTween:Cancel() end
	self.cameraTween = self:Tween(workspace.CurrentCamera, seconds, goal, style or SINE, INOUT)
	return self.cameraTween
end

-- Decaying jolts. Only use on a held camera; a running dolly overwrites it.
function Intro:Shake(strength: number, count: number)
	self:Spawn(function()
		local camera = workspace.CurrentCamera
		local random = Random.new()
		for i = 1, count do
			local offset = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(-1, 1), 0) * strength * (1 - (i - 1) / count)
			camera.CFrame *= CFrame.new(offset)
			task.wait(0.035)
			camera.CFrame *= CFrame.new(-offset)
		end
	end)
end

-- Cues live in MyChickenArmyAudio.Intro/<scene>, one Sound per moment. Volume and
-- PlaybackSpeed come from that Sound; rise only scales its speed (roll ticks).
function Intro:Sound(name: string, rise: number?)
	local audio = self.app.audio
	local cue = "Intro_" .. name
	local template = audio.templates[cue]
	local pitch = if rise and template then template.PlaybackSpeed * rise else nil
	audio:Play(cue, pitch, {noFallback = true, voiceKey = cue})
end

function Intro:PlayTrack(name: string, fade: number, startAt: number?)
	local audio = self.app.audio
	self:StopTrack(0.4)
	if not audio.musicEnabled then return end
	local library = SoundService:FindFirstChild("MyChickenArmyAudio")
	local template = library and library:FindFirstChild(name, true)
	if not template or not template:IsA("Sound") or template.SoundId == "" then return end
	local sound = template:Clone()
	sound.Looped, sound.SoundGroup, sound.Volume = false, audio.musicGroup, 0
	sound.Parent = audio.folder or SoundService
	sound.TimePosition = startAt or 0
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(fade), {Volume = template.Volume}):Play()
	self.music = sound
end

function Intro:StopTrack(fade: number)
	local sound = self.music
	self.music = nil
	if not sound then return end
	local tween = TweenService:Create(sound, TweenInfo.new(fade), {Volume = 0})
	tween.Completed:Once(function() sound:Destroy() end)
	tween:Play()
end

function Intro:Sparkle(position: Vector3, color: Color3, count: number, size: number)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition, anchor.Parent = position, workspace.Terrain
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0)})
	sparks.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
	sparks.Lifetime, sparks.Speed = NumberRange.new(0.4, 0.9), NumberRange.new(3, 9)
	sparks.SpreadAngle, sparks.Acceleration = Vector2.new(180, 180), Vector3.new(0, -6, 0)
	sparks.Rate, sparks.LightEmission, sparks.Parent = 0, 0.8, anchor
	sparks:Emit(count)
	task.delay(1.5, function() anchor:Destroy() end)
end

-- A four-point screen-space glint; reads at any distance, unlike particles.
function Intro:Glint(position: Vector3, pixels: number, color: Color3?)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.Transparency, anchor.Size = true, 1, Vector3.one * 0.1
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
	anchor.Position, anchor.Parent = position, self.folder
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.LightInfluence = UDim2.fromOffset(pixels, pixels), 0
	gui.Adornee, gui.Parent = anchor, anchor
	local star = Instance.new("Frame")
	star.AnchorPoint, star.Position, star.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0, 0)
	star.BackgroundTransparency, star.Parent = 1, gui
	for _, spec in {{0, 1, 0.14}, {90, 1, 0.14}, {45, 0.45, 0.1}, {-45, 0.45, 0.1}} do
		local ray = Instance.new("Frame")
		ray.AnchorPoint, ray.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		ray.Size, ray.Rotation = UDim2.fromScale(spec[2], spec[3]), spec[1]
		ray.BackgroundColor3, ray.BorderSizePixel = color or Color3.fromRGB(255, 246, 200), 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius, corner.Parent = UDim.new(1, 0), ray
		ray.Parent = star
	end
	self:Tween(star, 0.35, {Size = UDim2.fromScale(1, 1), Rotation = 45}, QUAD, OUT)
	task.delay(0.55, function()
		if not star.Parent then return end
		self:Tween(star, 0.45, {Size = UDim2.fromScale(0, 0), Rotation = 90}, QUAD, IN)
	end)
	task.delay(1.2, function() anchor:Destroy() end)
end

function Intro:Dust(position: Vector3, size: number, count: number, color: Color3?)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition, anchor.Parent = position, workspace.Terrain
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
	puff.Color = ColorSequence.new(color or DUST)
	puff.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size * 1.6)})
	puff.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	puff.Lifetime, puff.Speed = NumberRange.new(0.45, 0.85), NumberRange.new(size * 2, size * 5)
	puff.SpreadAngle, puff.Drag = Vector2.new(85, 85), 5
	puff.Acceleration, puff.RotSpeed = Vector3.new(0, 1.5, 0), NumberRange.new(-90, 90)
	puff.Rate, puff.LightInfluence, puff.Parent = 0, 0.6, anchor
	puff:Emit(count)
	task.delay(1.2, function() anchor:Destroy() end)
end

function Intro:Flash(color: Color3, from: number, seconds: number)
	local flash = self.flash
	if not flash then return end
	flash.BackgroundColor3, flash.BackgroundTransparency = color, from
	self:Tween(flash, seconds, {BackgroundTransparency = 1}, QUAD, OUT)
end

-- A flat shockwave on the ground.
function Intro:Ring(position: Vector3, color: Color3, radius: number)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.Transparency, anchor.Size = true, 1, Vector3.one * 0.1
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = false, false, false
	anchor.Position, anchor.Parent = position, self.folder
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Adornee, ring.Radius, ring.InnerRadius, ring.Height = anchor, 0.6, 0.35, 0.06
	ring.CFrame, ring.Color3, ring.Transparency = CFrame.Angles(math.pi / 2, 0, 0), color, 0.05
	ring.Parent = anchor
	self:Tween(ring, 0.45, {Radius = radius, InnerRadius = radius - 0.35, Transparency = 1}, QUAD, OUT)
	task.delay(0.6, function() anchor:Destroy() end)
end

-- A cartoon "!" or "?" over a chicken. hold < 0 keeps it until the scene ends.
function Intro:Pop(model: Model, text: string, color: Color3?, hold: number?): BillboardGui?
	local root = model.PrimaryPart
	if not root then return nil end
	local height = (model:GetAttribute("VisualHeight") or 2.5) - (model:GetAttribute("FootOffset") or 1.25)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffset, gui.LightInfluence = UDim2.fromOffset(0, 0), Vector3.new(0, height + 1.2, 0), 0
	-- Outside the rig: chicken tag managers toggle billboards inside chicken models.
	gui.Adornee, gui.Parent = root, self.folder
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Text = UDim2.fromScale(1, 1), 1, text
	label.Font, label.TextScaled, label.TextColor3 = Theme.Font, true, color or Color3.new(1, 1, 1)
	label.TextStrokeColor3, label.TextStrokeTransparency, label.Parent = Color3.new(0, 0, 0), 0, gui
	self:Tween(gui, 0.25, {Size = UDim2.fromOffset(60, 60)}, Enum.EasingStyle.Back, OUT)
	local seconds = hold or 0.9
	if seconds >= 0 then
		task.delay(seconds, function()
			if label.Parent then self:Tween(label, 0.2, {TextTransparency = 1, TextStrokeTransparency = 1}, QUAD, IN) end
		end)
		task.delay(seconds + 0.3, function() gui:Destroy() end)
	end
	return gui
end

-- Little stars circling a dazed head.
function Intro:Dizzy(model: Model, seconds: number)
	local root = model.PrimaryPart
	if not root then return end
	local stars = {}
	for i = 1, 3 do
		local star = Instance.new("Part")
		star.Shape, star.Size, star.Material, star.Color = Enum.PartType.Ball, Vector3.one * 0.32, Enum.Material.Neon, GOLD
		star.Anchored, star.CanCollide, star.CanTouch, star.CanQuery, star.CastShadow = true, false, false, false, false
		star.Parent = self.folder
		stars[i] = star
	end
	local spin = Instance.new("NumberValue")
	spin.Parent = self.folder
	spin.Changed:Connect(function(angle)
		if not root.Parent then return end
		local center = root.Position + UP * 0.9
		for i, star in stars do
			local a = angle + i * math.pi * 2 / 3
			star.Position = center + Vector3.new(math.cos(a) * 0.8, math.sin(a * 2) * 0.1, math.sin(a) * 0.8)
		end
	end)
	self:Tween(spin, seconds, {Value = seconds * 9}, LINEAR, INOUT)
	task.delay(seconds, function()
		for _, star in stars do star:Destroy() end
		spin:Destroy()
	end)
end

function Intro:Confetti(position: Vector3)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition, anchor.Parent = position, workspace.Terrain
	local bits = Instance.new("ParticleEmitter")
	bits.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	bits.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, GOLD), ColorSequenceKeypoint.new(0.35, Theme.Arcade.green),
		ColorSequenceKeypoint.new(0.7, Theme.Arcade.blue), ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))})
	bits.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.2)})
	bits.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1)})
	bits.Lifetime, bits.Speed = NumberRange.new(1.4, 2.2), NumberRange.new(14, 24)
	bits.SpreadAngle, bits.Acceleration, bits.Drag = Vector2.new(40, 40), Vector3.new(0, -26, 0), 1.5
	bits.Rotation, bits.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-300, 300)
	bits.Rate, bits.LightEmission, bits.Parent = 0, 0.5, anchor
	bits:Emit(70)
	task.delay(2.6, function() anchor:Destroy() end)
end

-- Screen-space rush lines for the zoom and the launch.
function Intro:SpeedLines(on: boolean)
	if not on then
		if self.speed then self.speed:Destroy();self.speed = nil end
		return
	end
	if self.speed or not self.layer then return end
	local holder = Instance.new("Frame")
	-- Under the letterbox bars (91), over the world.
	holder.Name, holder.Size, holder.BackgroundTransparency, holder.ZIndex = "SpeedLines", UDim2.fromScale(1, 1), 1, 90
	holder.Parent = self.layer
	self.speed = holder
	local size = self.layer.AbsoluteSize
	local center = size / 2
	local reach = math.max(size.X, size.Y) * 0.5
	local random = Random.new(3)
	for i = 1, 18 do
		local angle = (i / 18) * math.pi * 2 + random:NextNumber(-0.12, 0.12)
		local direction = Vector2.new(math.cos(angle), math.sin(angle))
		local line = Instance.new("Frame")
		line.AnchorPoint, line.BorderSizePixel, line.BackgroundColor3 = Vector2.new(0.5, 0.5), 0, Color3.new(1, 1, 1)
		line.Size, line.Rotation = UDim2.fromOffset(reach * 0.35, math.max(2, size.Y * 0.004)), math.deg(angle)
		line.BackgroundTransparency, line.Parent = 1, holder
		local near, far = center + direction * reach * 0.45, center + direction * reach * 1.1
		task.delay(random:NextNumber(0, 0.25), function()
			if not line.Parent then return end
			line.Position, line.BackgroundTransparency = UDim2.fromOffset(near.X, near.Y), 0.25
			self:Tween(line, 0.28, {Position = UDim2.fromOffset(far.X, far.Y), BackgroundTransparency = 1}, QUAD, IN, -1)
		end)
	end
end

-- The real station's lever, pulled locally with the game's own rest pose.
function Intro:PullLever(station: Instance)
	local arm, knob = station:FindFirstChild("LeverArm"), station:FindFirstChild("LeverHandle")
	local frame = station:GetAttribute("DisplayFrame")
	local pivot = station:GetAttribute("LeverPivot") or (if typeof(frame) == "CFrame" then frame * CFrame.new(6.1, 1.85, -5) else nil)
	if not arm or not knob or typeof(pivot) ~= "CFrame" or not arm:IsA("BasePart") or not knob:IsA("BasePart") then return end
	local armRest = station:GetAttribute("LeverArmRest") or CFrame.new(0, 1.4, 0)
	local knobRest = station:GetAttribute("LeverHandleRest") or CFrame.new(0, 2.8, 0)
	local savedArm, savedKnob = arm.CFrame, knob.CFrame
	self.leverRestore = function()
		if arm.Parent then arm.CFrame = savedArm end
		if knob.Parent then knob.CFrame = savedKnob end
	end
	local angle = Instance.new("NumberValue")
	angle.Parent = self.folder
	angle.Changed:Connect(function(a)
		local at = pivot * CFrame.Angles(a, 0, 0)
		arm.CFrame, knob.CFrame = at * armRest, at * knobRest
	end)
	self:Spawn(function()
		self:Tween(angle, 0.16, {Value = -0.95}, QUAD, OUT).Completed:Wait()
		task.wait(0.12)
		self:Tween(angle, 0.45, {Value = 0}, Enum.EasingStyle.Back, OUT)
	end)
end

-- Background chickens glance around and hop instead of standing frozen.
function Intro:Fidget(model: Model, untilAt: number, seed: number)
	local random = Random.new(seed)
	self:Spawn(function()
		while model.Parent and os.clock() - self.clock < untilAt do
			task.wait(random:NextNumber(0.5, 1.1))
			if model:GetAttribute("Moving") or model:GetAttribute("Defeated") or os.clock() - self.clock >= untilAt then continue end
			if random:NextNumber() < 0.3 then
				self:Hop(model, 0.35, 0.22)
				task.wait(0.25)
			else
				local base = model:GetPivot()
				self:Move(model, base * CFrame.Angles(0, random:NextNumber(-0.6, 0.6), 0), 0.13, QUAD, OUT).Completed:Wait()
				task.wait(random:NextNumber(0.2, 0.45))
				if not model:GetAttribute("Moving") and (model:GetPivot().Position - base.Position).Magnitude < 0.2 then
					self:Move(model, base, 0.15, QUAD, OUT).Completed:Wait()
				end
			end
		end
	end)
end

-- Quick head shake: look left, right, then back.
function Intro:Shiver(model: Model)
	local base = model:GetPivot()
	self:Spawn(function()
		for _, yaw in {0.45, -0.45, 0.3, 0} do
			self:Move(model, base * CFrame.Angles(0, yaw, 0), 0.09, QUAD, OUT).Completed:Wait()
		end
	end)
end

-- Expressions ---------------------------------------------------------------
-- The rigs' faces are painted on, so acting comes from cartoon brows that ride
-- the head bone, plus puffing up and steam. Offsets are in units of the rig's Size.
local MOODS = {
	neutral = {0, 0}, happy = {-10, 0.05}, determined = {14, 0}, angry = {22, -0.01},
	furious = {28, -0.02}, surprised = {-12, 0.12}, shocked = {-20, 0.18}, worried = {-26, 0.04},
}

function Intro:Brows(model: Model, mood: string?)
	local root = model.PrimaryPart
	if not root or self.brows[model] then return end
	local head = model:FindFirstChild((model:GetAttribute("BonePrefix") or "") .. "Head", true)
	local size = model:GetAttribute("Size") or 2.25
	local set = {model = model, root = root, parts = {}, angle = 0, lift = 0}
	if head and head:IsA("Bone") then
		set.head, set.headToRoot = head, head.WorldCFrame:ToObjectSpace(root.CFrame)
	end
	for _, side in {-1, 1} do
		local brow = Instance.new("Part")
		brow.Name, brow.Size = "Brow", Vector3.new(size * 0.21, size * 0.05, size * 0.05)
		brow.Color, brow.Material = Color3.fromRGB(28, 22, 22), Enum.Material.SmoothPlastic
		brow.Anchored, brow.CanCollide, brow.CanTouch, brow.CanQuery, brow.CastShadow = true, false, false, false, false
		brow.Parent = self.folder
		set.parts[side] = brow
	end
	self.brows[model] = set
	if not self.browStep then
		self.browStep = RunService.RenderStepped:Connect(function()
			for owner, entry in self.brows do
				if not owner.Parent then
					for _, part in entry.parts do part:Destroy() end
					self.brows[owner] = nil
					continue
				end
				local s = owner:GetAttribute("Size") or 2.25
				local frame = if entry.head then entry.head.TransformedWorldCFrame * entry.headToRoot else entry.root.CFrame
				for side, part in entry.parts do
					part.CFrame = frame * CFrame.new(side * s * 0.133, s * (0.675 + entry.lift), -s * 0.55)
						* CFrame.Angles(0, 0, side * math.rad(entry.angle))
				end
			end
		end)
	end
	self:Mood(model, mood or "neutral", 0)
end

function Intro:Mood(model: Model, mood: string, seconds: number?)
	local set = self.brows[model]
	local target = MOODS[mood]
	if not set or not target then return end
	local value = Instance.new("Vector3Value")
	value.Value = Vector3.new(set.angle, set.lift, 0)
	value.Parent = self.folder
	value.Changed:Connect(function(v) set.angle, set.lift = v.X, v.Y end)
	local tween = self:Tween(value, seconds or 0.14, {Value = Vector3.new(target[1], target[2], 0)}, Enum.EasingStyle.Back, OUT)
	tween.Completed:Once(function() value:Destroy() end)
end

-- Swell up and settle back, feet kept on the ground. Only on a standing rig.
function Intro:Puff(model: Model, factor: number, seconds: number)
	local baseScale = model:GetScale()
	local base = {}
	for _, name in SCALED_ATTRIBUTES do base[name] = model:GetAttribute(name) end
	local pivot = model:GetPivot()
	local footOffset = base.FootOffset or 1.25
	local foot = pivot.Position - UP * footOffset
	local value = Instance.new("NumberValue")
	value.Value, value.Parent = 1, self.folder
	value.Changed:Connect(function(k)
		if not model.Parent then return end
		model:ScaleTo(baseScale * k)
		for name, amount in base do
			if type(amount) == "number" then model:SetAttribute(name, amount * k) end
		end
		model:PivotTo(CFrame.new(foot + UP * footOffset * k) * pivot.Rotation)
	end)
	self:Spawn(function()
		self:Tween(value, seconds * 0.35, {Value = factor}, Enum.EasingStyle.Back, OUT).Completed:Wait()
		task.wait(seconds * 0.3)
		self:Tween(value, seconds * 0.35, {Value = 1}, QUAD, IN).Completed:Wait()
		value:Destroy()
	end)
end

-- Cartoon anger steam from both sides of the head.
function Intro:Steam(model: Model)
	local root = model.PrimaryPart
	if not root then return end
	local size = model:GetAttribute("Size") or 2.25
	for _, side in {-1, 1} do
		local anchor = Instance.new("Attachment")
		anchor.WorldCFrame = root.CFrame * CFrame.new(side * size * 0.3, size * 0.62, -size * 0.35) * CFrame.Angles(0, 0, -side * 0.5)
		anchor.Parent = workspace.Terrain
		local puff = Instance.new("ParticleEmitter")
		puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
		puff.Color = ColorSequence.new(Color3.new(1, 1, 1))
		puff.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, size * 0.12), NumberSequenceKeypoint.new(1, size * 0.4)})
		puff.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
		puff.Lifetime, puff.Speed = NumberRange.new(0.35, 0.6), NumberRange.new(size * 2.2, size * 3.2)
		puff.SpreadAngle, puff.Acceleration, puff.Drag = Vector2.new(12, 12), Vector3.new(0, size, 0), 2
		puff.EmissionDirection, puff.Rate, puff.Parent = Enum.NormalId.Top, 0, anchor
		puff:Emit(5)
		task.delay(0.16, function() if puff.Parent then puff:Emit(5) end end)
		task.delay(0.32, function() if puff.Parent then puff:Emit(4) end end)
		task.delay(1.2, function() anchor:Destroy() end)
	end
end

-- An electric stare-down: a flickering bolt between two faces, with sparks.
function Intro:Zap(from: Vector3, to: Vector3, seconds: number)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.WorldPosition, a1.WorldPosition = from, to
	a0.Parent, a1.Parent = workspace.Terrain, workspace.Terrain
	local mid = Instance.new("Attachment")
	mid.WorldPosition, mid.Parent = (from + to) / 2, workspace.Terrain
	local bolt = Instance.new("Beam")
	bolt.Attachment0, bolt.Attachment1, bolt.Segments, bolt.FaceCamera = a0, a1, 14, true
	bolt.Color = ColorSequence.new(Color3.fromRGB(255, 250, 190), Color3.fromRGB(255, 214, 60))
	bolt.LightEmission, bolt.Width0, bolt.Width1 = 1, 0.14, 0.14
	bolt.Parent = self.folder
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
	sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0)})
	sparks.Lifetime, sparks.Speed, sparks.SpreadAngle = NumberRange.new(0.2, 0.4), NumberRange.new(3, 8), Vector2.new(180, 180)
	sparks.Rate, sparks.LightEmission, sparks.Parent = 70, 1, mid
	local random = Random.new()
	self:Spawn(function()
		local started = os.clock()
		while os.clock() - started < seconds and bolt.Parent do
			bolt.CurveSize0, bolt.CurveSize1 = random:NextNumber(-1.4, 1.4), random:NextNumber(-1.4, 1.4)
			bolt.Width0 = random:NextNumber(0.08, 0.2)
			task.wait(0.045)
		end
		bolt:Destroy()
		sparks.Enabled = false
	end)
	task.delay(seconds + 0.6, function() a0:Destroy();a1:Destroy();mid:Destroy() end)
end

-- Screen chrome and player input --------------------------------------------

-- Bottom-bar caption: nil fades it out; new text fades the old line out first.
-- TweenService owns the fades (tracked, so Unlock cancels them); reduced motion
-- swaps the text instantly.
function Intro:Caption(text: string?)
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
	if not text then fade(1, 0.35); return end
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

function Intro:Lock()
	local app = self.app
	local camera = workspace.CurrentCamera
	self.cameraFov = camera.FieldOfView
	-- Full device screen, so the bars and cover reach past phone notches.
	local layer = Theme.InsetContainer(app.gui, "IntroCutscene", Enum.ScreenInsets.None)
	layer.ZIndex = 90
	self.layer = layer
	local cover = Instance.new("Frame")
	cover.Name, cover.Size, cover.BackgroundColor3 = "Cover", UDim2.fromScale(1, 1), Color3.new(0, 0, 0)
	cover.BorderSizePixel, cover.ZIndex, cover.Parent = 0, 95, layer
	self.cover = cover
	local flash = Instance.new("Frame")
	flash.Name, flash.Size, flash.BackgroundTransparency = "Flash", UDim2.fromScale(1, 1), 1
	flash.BorderSizePixel, flash.ZIndex, flash.Parent = 0, 92, layer
	self.flash = flash
	self.bars = {}
	for _, spec in {{"Top", 0}, {"Bottom", 1}} do
		local bar = Instance.new("Frame")
		bar.Name, bar.AnchorPoint = spec[1] .. "Bar", Vector2.new(0, spec[2])
		bar.Position, bar.Size = UDim2.fromScale(0, spec[2]), UDim2.fromScale(1, BAR_HEIGHT)
		bar.BackgroundColor3, bar.BorderSizePixel, bar.ZIndex, bar.Parent = Color3.new(0, 0, 0), 0, 91, layer
		table.insert(self.bars, bar)
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
	skip.AutoButtonColor, skip.ZIndex, skip.Parent = true, 96, skipColumn
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio, aspect.Parent = 3.2, skip
	Theme.Stroke(skip, Color3.new(1, 1, 1), 2)
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
	-- Shell and the guide stay hidden until the story hands over to play.
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
	camera.CameraType = Enum.CameraType.Scriptable
	app.base:UpdateObjective()
end

function Intro:Unlock()
	local app = self.app
	for _, thread in self.threads do
		if thread ~= coroutine.running() then pcall(task.cancel, thread) end
	end
	table.clear(self.threads)
	for _, tween in self.tweens do tween:Cancel() end
	table.clear(self.tweens)
	self:StopTrack(0.6)
	self:SpeedLines(false)
	if self.browStep then self.browStep:Disconnect();self.browStep = nil end
	table.clear(self.brows)
	if self.leverRestore then self.leverRestore();self.leverRestore = nil end
	if self.eggWatch then self.eggWatch:Disconnect();self.eggWatch = nil end
	for gui, distance in self.eggSaved or {} do
		if gui.Parent then gui.MaxDistance = distance end
	end
	self.eggSaved = nil
	for _, watch in self.watches do watch:Disconnect() end
	table.clear(self.watches)
	if self.folder then self.folder:Destroy();self.folder = nil end
	for _, saved in self.hidden do
		for item, value in saved do
			if item.Parent then
				if item:IsA("LayerCollector") then (item :: any).MaxDistance = value else (item :: any).LocalTransparencyModifier = value end
			end
		end
	end
	table.clear(self.hidden)
	local camera = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = self.cameraFov or 70
	for kind, enabled in self.coreGui or {} do pcall(function() StarterGui:SetCoreGuiEnabled(kind, enabled) end) end
	ProximityPromptService.Enabled = if self.promptsEnabled == nil then true else self.promptsEnabled
	if self.controls then self.controls:Enable();self.controls = nil end
	app.audio.musicHold = false
	app.audio:SetMusic(app.audio.musicEnabled)
	local shell = app.gui:FindFirstChild("Shell")
	if shell then shell.Visible = true end
end

function Intro:Finish(skipped: boolean)
	if not self.playing then return end
	self.playing = false
	if self.thread and self.thread ~= coroutine.running() then pcall(task.cancel, self.thread) end
	local cover, layer = self.cover, self.layer
	if skipped and cover then
		TweenService:Create(cover, TweenInfo.new(0.25), {BackgroundTransparency = 0}):Play()
		task.wait(0.27)
	end
	self:Unlock()
	if self.mode == "intro" then
		self.app:Request("TutorialSignal", {signal = if skipped then "IntroSkipped" else "IntroFinished"})
	end
	if layer then
		for _, bar in self.bars do TweenService:Create(bar, TweenInfo.new(0.4, QUAD, OUT), {Size = UDim2.fromScale(1, 0)}):Play() end
		local skip = layer:FindFirstChild("Skip")
		if skip then skip:Destroy() end
		if cover then TweenService:Create(cover, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play() end
		task.delay(0.45, function() layer:Destroy() end)
	end
	self.layer, self.cover = nil, nil
	if self.app.commander then self.app.commander:Update() end
	self.app.base:UpdateObjective()
end

-- The film ------------------------------------------------------------------

function Intro:Run()
	local scene
	for _ = 1, 30 do
		scene = self:Resolve(self.app.state)
		if scene then break end
		task.wait(0.1)
	end
	if not scene then return end
	if self.mode == "intro" then
		self.signalled = true
		self.app:Request("TutorialSignal", {signal = "IntroStarted"})
	end
	self.folder = Instance.new("Folder")
	self.folder.Name, self.folder.Parent = "PetRollIntro", workspace

	local inward, right = scene.inward, scene.right
	local K = ground(scene.kingAt)
	local campDir = flat(scene.campAt - scene.yard).Unit
	local heroSpot = ground(scene.yard + inward * 2)
	local eggSpot = ground(heroSpot + inward * 2 + right * 0.5)
	local stop = ground(scene.campAt - campDir * 5.2)
	local approach = ground(stop - campDir * 24)
	local guardSpots = {ground(scene.campAt - campDir * 1.6 - right * 2.1), ground(scene.campAt - campDir * 1.1), ground(scene.campAt - campDir * 1.6 + right * 2.1)}
	local lineup = ground(heroSpot + inward * 5)
	local slots = {}
	for i, x in {-4.5, -1.5, 1.5, 4.5} do slots[i] = ground(lineup + right * x) end
	local station = scene.station
	local lever = station:FindFirstChild("LeverBase")
	local pad = station:FindFirstChild("RevealPad") or station:FindFirstChild("Podium")
	local displayFoot = station:GetAttribute("DisplayFoot")
	local podium = if typeof(displayFoot) == "Vector3" then displayFoot
		elseif pad and pad:IsA("BasePart") then pad.Position + UP * pad.Size.Y / 2 else lineup
	local leverAt = if lever and lever:IsA("BasePart") then ground(lever.Position) else ground(podium)
	local leverSpot = ground(leverAt - flat(leverAt - lineup).Unit * 2.2)

	-- Hide the live versions of everyone we film; restore them at the end.
	local character = Players.LocalPlayer.Character
	self:Hide(character)
	local hiddenChickens = {}
	for _, model in scene.chickens do
		if not hiddenChickens[model] then hiddenChickens[model] = true;self:Hide(model) end
	end
	for _, model in scene.guards do self:Hide(model) end
	self:HideOthers(scene)
	if scene.set then self:StageArena(scene) else self:Hide(scene.king);self:HideTags(scene.arena) end
	self:HideEggs()
	self:HideTags(scene.lane)
	self:HideTags(scene.plot)

	local hero = self:Stage(scene.chickens[1], "Hero")
	self:Place(hero, heroSpot, inward)
	self:Brows(hero)
	local guards = {}
	for i, spot in guardSpots do
		local source = scene.guards[i] or scene.guards[1] or scene.chickens[2]
		guards[i] = self:Stage(source, "Guard" .. i)
		self:Place(guards[i], spot, campDir)
		self:Brows(guards[i])
	end
	local king
	if scene.king then
		king = self:Stage(scene.king, "King")
		self:Scale(king, KING_SCALE)
		self:Place(king, K, -inward)
		self:Brows(king, "angry")
	end
	local function crownAt(): Vector3
		local crown = king and king:FindFirstChild("RoyalCrown")
		return if crown and crown:IsA("BasePart") then crown.Position else K + UP * 14
	end
	local egg = EggView.new(self.folder, {id = "Intro", value = 4, stack = 1})
	egg.anchor.Position = hero:GetPivot().Position
	egg.gui.Size = UDim2.fromScale(0, 0)

	-- Out the gate on the real march route; a cut skips the long middle of the road.
	local route = March.Path(heroSpot, scene.campAt)
	local gateOut = ground(route[math.min(3, #route - 1)])
	local outPath = {heroSpot}
	for i = 2, math.min(3, #route - 1) do table.insert(outPath, ground(route[i])) end
	table.insert(outPath, ground(gateOut + flat(scene.campAt - gateOut).Unit * 10))
	local outLength = 0
	for i = 2, #outPath do outLength += (outPath[i] - outPath[i - 1]).Magnitude end
	local outSpeed = math.clamp(outLength / 3.4, 6, 11)

	self.clock = os.clock()
	self:Audit()

	-- 1. The Island: a slow aerial into the King's arena, then the King himself.
	self:Cut(K - inward * 170 + right * 40 + UP * 120, K, 60, K + UP * 25)
	self:Tween(self.cover, 1, {BackgroundTransparency = 1}, QUAD, OUT)
	self:Caption("This is the Chicken King. He rules the island.")
	self:Dolly(K - inward * 80 + right * 14 + UP * 42, K + UP * 3, 4.2, SINE, 58, K + UP * 25)
	self:Wait(4.2)
	local crownTop = K + UP * (if king then (king:GetAttribute("VisualHeight") or 15) + 1 else 12)
	self:Cut(K - inward * 27 - right * 4 + UP * 1.5, crownTop - UP * 6, 58)
	self:Dolly(K - inward * 20 - right * 3 + UP * 1.8, crownTop - UP * 5, 3.2, SINE, 54)
	self:Wait(4.8)
	if king then bump(king, "VictorySerial") end
	self:Sound("KingAppears")
	self:Dust(K + UP * 0.3, 1.6, 18)
	self:Wait(5.9)
	self:Sparkle(crownAt(), GOLD, 28, 1.4)
	self:Glint(crownAt() + UP, 110, GOLD)
	self:Sound("CrownGlint")

	-- 2. The Dreamer: home, an egg, and a crown on the horizon worth chasing.
	self:Wait(7.4)
	self:Caption("One little chicken dreams of beating him…")
	self:Cut(heroSpot + right * 7 + inward * 3 + UP * 2.5, heroSpot + UP * 1, 60)
	self:Dolly(heroSpot + right * 5.5 + inward * 2.4 + UP * 2.1, heroSpot + UP * 1, 2.5, SINE)
	self:Wait(7.8)
	self:Hop(hero, 0.7, 0.3)
	self:Tween(egg.anchor, 0.35, {Position = eggSpot + UP * 0.45}, QUAD, OUT)
	self:Tween(egg.gui, 0.35, {Size = UDim2.fromScale(Config.EggSpriteSize * 0.7, Config.EggSpriteSize * 0.7)}, Enum.EasingStyle.Back, OUT)
	self:Sparkle(eggSpot + UP * 0.6, Color3.new(1, 1, 1), 10, 0.5)
	self:Sound("EggLaid")
	self:Mood(hero, "happy")
	self:Wait(8.6)
	self:Face(hero, inward - right * 0.8, 0.15)
	self:Wait(9.0)
	self:Face(hero, inward + right * 0.8, 0.15)
	self:Wait(9.4)
	self:Face(hero, inward, 0.15)

	-- The hero's point of view: a punch-in, then a rush across the island to the King.
	self:Wait(9.9)
	local eyes = {}
	for _, lift in {2.2, 3.2, 4.4} do
		for _, slide in {0, 1.4, -1.4, 2.8, -2.8} do
			table.insert(eyes, heroSpot + UP * lift + inward * 1.1 + right * slide)
		end
	end
	local eye = self:Pick(eyes, {crownAt(), K + UP * 6})
	self:Cut(eye, crownAt(), 60, eye)
	self:Wait(10.25)
	self:Tween(workspace.CurrentCamera, 0.25, {FieldOfView = 34}, QUAD, OUT)
	self:Sound("LookPunchIn")
	self:Wait(10.7)
	local kingViews = {}
	for _, spec in {{34, 3, 9}, {30, -5, 9}, {27, 7, 8}, {24, -7, 8}, {22, 3, 7}, {30, 3, 14}} do
		table.insert(kingViews, K - inward * spec[1] + right * spec[2] + UP * spec[3])
	end
	local kingTargets = {K + UP * 6, crownAt()}
	local rushEnd = self:Pick(kingViews, kingTargets)
	local kingPush = self:Pick({rushEnd + flat(K - rushEnd).Unit * 4, rushEnd}, kingTargets)
	local rushPeak = (eye + rushEnd) / 2 + UP * 28
	-- This shot only: nothing may stand between the rush's final approach and the King.
	local kingLenses = {kingPush, kingPush - UP * 0.5}
	for _, u in {0.6, 0.75, 0.9, 1} do
		table.insert(kingLenses, eye:Lerp(rushPeak, u):Lerp(rushPeak:Lerp(rushEnd, u), u))
	end
	local kingClear = self:ClearView(kingLenses, {crownAt(), K + UP * 6, K + UP * 2.5, K + UP * 6 + right * 3, K + UP * 6 - right * 3})
	local rush = Instance.new("NumberValue")
	rush.Parent = self.folder
	rush.Changed:Connect(function(u)
		local a, b = eye:Lerp(rushPeak, u), rushPeak:Lerp(rushEnd, u)
		workspace.CurrentCamera.CFrame = CFrame.lookAt(a:Lerp(b, u), crownAt())
	end)
	if self.cameraTween then self.cameraTween:Cancel();self.cameraTween = nil end
	self:SpeedLines(true)
	self:Sound("RushToKing")
	self:Tween(rush, 1.15, {Value = 1}, Enum.EasingStyle.Quart, INOUT)
	self:Tween(workspace.CurrentCamera, 0.55, {FieldOfView = 78}, QUAD, OUT).Completed:Once(function()
		self:Tween(workspace.CurrentCamera, 0.6, {FieldOfView = 56}, QUAD, IN)
	end)
	self:Wait(11.85)
	self:SpeedLines(false)
	self:Glint(crownAt() + UP * 0.5, 150, GOLD)
	self:Sparkle(crownAt(), GOLD, 30, 1.3)
	self:Sound("KingCrownGlint")
	self:Dolly(kingPush - UP * 0.5, crownAt() - UP * 3, 1.2, SINE, 54)
	self:Wait(13.05)
	for _, piece in kingClear do self:Show(piece) end
	self:Cut(heroSpot + inward * 5.2 + right * 0.6 + UP * 1.9, heroSpot + UP * 1.7, 55)
	self:Dolly(heroSpot + inward * 4.2 + right * 0.4 + UP * 1.8, heroSpot + UP * 1.7, 1.8, SINE, 50)
	self:Wait(13.25)
	self:Pop(hero, "!", GOLD)
	self:Sound("HeroExclaim")
	self:Mood(hero, "surprised")
	self:Wait(13.7)
	bump(hero, "VictorySerial")
	self:Mood(hero, "determined")
	self:Sparkle(hero:GetPivot().Position + UP, GOLD, 22, 0.9)
	self:Sound("HeroVictory")
	self:Wait(14.35)
	self:Hop(hero, 0.5, 0.25)

	-- 3. The Journey: out the gate alone, then the walk up to Cluck Camp.
	self:Wait(14.85)
	self:Caption(nil)
	local gateFocus = gateOut - inward * 5 + UP * 1.5
	self:Cut(gateOut + inward * 15 + right * 5 + UP * 2.6, gateFocus, 55)
	self:Dolly(gateOut + inward * 12.5 + right * 4.2 + UP * 2.3, gateFocus, 3.6, SINE)
	self:Walk(hero, outPath, outSpeed, true)
	self:Wait(18.4)
	self:Place(hero, approach, campDir)
	for i, guard in guards do self:Fidget(guard, 18.4 + (stop - approach).Magnitude / 8 - 0.3, i) end
	local campFocus = scene.campAt + UP * 3.5
	self:Cut(approach - campDir * 7 + right * 1.5 + UP * 1.2, campFocus, 60, approach + UP)
	self:Walk(hero, {approach, stop}, 8, true)
	local arrive = 18.4 + (stop - approach).Magnitude / 8
	self:Dolly(stop - campDir * 5.5 + right * 1.3 + UP * 1, campFocus, arrive - 18.4, LINEAR, nil, stop + UP)
	self:Wait(arrive + 0.15)
	self:Hop(hero, 0.4, 0.22)

	-- 4. The Bonk: nose to nose with three guards. One chicken is not an army.
	self:Wait(arrive + 0.4)
	local t = arrive + 0.4
	local middle = (stop + guardSpots[2]) / 2
	local side = self:OpenSide(middle + UP * 1.5, right, 9)
	local standoffTargets = {stop + UP, guardSpots[1] + UP, guardSpots[2] + UP, guardSpots[3] + UP}
	local standoffViews = {}
	for _, s2 in {side, -side} do
		for _, spec in {{7.5, 2.2}, {6.5, 3.2}, {8.5, 3.5}, {6, 2}, {9.5, 5}} do
			table.insert(standoffViews, middle + s2 * spec[1] + UP * spec[2])
		end
	end
	local standoff = self:Pick(standoffViews, standoffTargets)
	local standoffPush = self:Pick({standoff:Lerp(middle + UP * 1.4, 0.2), standoff}, standoffTargets)
	self:Cut(standoff, middle + UP * 1.2, 52)
	self:Dolly(standoffPush, middle + UP * 1.2, 1.4, SINE)
	self:Face(hero, campDir, 0.15)
	self:Mood(hero, "determined")
	self:Wait(t + 0.25)
	for i, guard in guards do
		task.delay((i - 1) * 0.06, function()
			if not guard.Parent then return end
			self:Face(guard, -campDir, 0.18)
			self:Mood(guard, "surprised")
			self:Pop(guard, "!", Color3.fromRGB(255, 80, 70), 0.7)
		end)
	end
	self:Sound("GuardsTurn")
	self:Wait(t + 0.8)
	for _, guard in guards do
		self:Mood(guard, "angry")
		self:Puff(guard, 1.16, 0.45)
	end
	self:Wait(t + 1.05)
	self:Mood(hero, "furious")
	self:Puff(hero, 1.28, 0.5)
	self:Sound("HeroPuffUp")

	-- Stare-down: snap close-ups, face to face.
	self:Wait(t + 1.6)
	local heroFace = hero:GetPivot().Position + UP * 0.95
	local guardFace = guards[2]:GetPivot().Position + UP * 0.95
	-- 3/4 angle inside the gap between them, so the guards never block the lens.
	local heroBody = heroFace - UP * 0.5
	local heroLens = self:Pick({
		heroFace + campDir * 2.2 + right * 3.2 + UP * 0.5,
		heroFace + campDir * 2.0 + right * 3.8 + UP * 0.7,
		heroFace + campDir * 1.6 - right * 3.4 + UP * 0.5,
	}, {heroFace, heroBody})
	self:Cut(heroLens, heroBody + UP * 0.2, 62, heroFace)
	self:Tween(workspace.CurrentCamera, 0.28, {FieldOfView = 54}, QUAD, OUT)
	self:Sound("StareHero")
	self:Steam(hero)
	self:Sound("SteamHiss")
	self:Shake(0.12, 4)
	self:Wait(t + 2.3)
	local guardBody = guardFace - UP * 0.5
	-- From the hero's side of the gap, raised: the angry middle guard centred,
	-- the other two flanking it, none of them between it and the lens.
	local guardLens = self:Pick({
		guardFace - campDir * 3.3 + right * 0.6 + UP * 0.9,
		guardFace - campDir * 3.0 - right * 0.6 + UP * 1.2,
		guardFace - campDir * 3.4 + UP * 1.6,
	}, {guardFace, guardBody})
	self:Cut(guardLens, guardBody + UP * 0.3, 66, guardFace)
	self:Tween(workspace.CurrentCamera, 0.28, {FieldOfView = 60}, QUAD, OUT)
	self:Sound("StareGuard")
	self:Mood(guards[2], "furious")
	self:Steam(guards[2])
	self:Shake(0.12, 4)

	-- Both in frame, sparks between their eyes, the hero paws the ground.
	self:Wait(t + 3.0)
	local lowViews = {}
	for _, s2 in {side, -side} do
		for _, spec in {{8.5, 2.6}, {9.5, 3.4}, {7.5, 2.4}, {10.5, 4.2}} do
			table.insert(lowViews, middle + s2 * spec[1] + UP * spec[2])
		end
	end
	local low = self:Pick(lowViews, {heroFace, guardFace})
	self:Cut(low, middle + UP * 1.4, 50)
	self:Dolly(low:Lerp(middle + UP * 1.4, 0.12), middle + UP * 1.4, 1.15, SINE)
	self:Zap(heroFace + campDir * 0.5, guardFace - campDir * 0.5, 1.15)
	self:Sound("EyeSparks")
	for i = 0, 2 do
		task.delay(0.2 + i * 0.22, function()
			if not hero.Parent then return end
			self:Hop(hero, 0.22, 0.14)
			self:Dust(stop - campDir * 0.7 + UP * 0.2, 0.45, 6)
			self:Sound("Stomp")
		end)
	end

	-- Charge, peck, and the guard answers.
	self:Wait(t + 4.15)
	self:Sound("Charge")
	local lunge = self:Pivot(hero, stop + campDir * 1.7, campDir)
	self:Move(hero, lunge, 0.13, QUAD, IN)
	self:Dust(stop + UP * 0.2, 0.6, 8)
	self:Wait(t + 4.3)
	bump(hero, "AttackSerial")
	self:Sound("HeroPeck")
	self:Sparkle(guardFace, Color3.new(1, 1, 1), 10, 0.5)
	self:Mood(guards[2], "shocked")
	self:Wait(t + 4.45)
	self:Mood(guards[2], "furious")
	bump(guards[2], "AttackSerial")

	-- The hit and the launch happen on the same beat.
	self:Wait(t + 4.62)
	local hit = t + 4.62
	self:Caption("…but one chicken isn't an army.")
	self:Mood(hero, "shocked", 0.06)
	bump(hero, "HitSerial")
	self:StopTrack(0.15)
	local struck = hero:GetPivot().Position + UP * 0.4
	self:Flash(Color3.new(1, 1, 1), 0.3, 0.2)
	self:Glint(struck + campDir * 0.6, 170, Color3.fromRGB(255, 236, 120))
	self:Ring(ground(struck) + UP * 0.2, Color3.new(1, 1, 1), 6)
	self:Sparkle(struck, Color3.new(1, 1, 1), 30, 1)
	self:Sparkle(struck, GOLD, 14, 0.8)
	self:Dust(ground(struck) + UP * 0.2, 0.9, 12)
	self:Sound("GuardHit")
	self:Sound("LaunchWhistle")
	self:Shake(0.55, 5)
	local landing = self:Pivot(hero, heroSpot, inward).Position
	local peak = (struck + landing) / 2 + UP * 38
	local root = hero.PrimaryPart
	local trailTop, trailBottom = Instance.new("Attachment"), Instance.new("Attachment")
	trailTop.Position, trailBottom.Position = Vector3.new(0, 0.7, 0), Vector3.new(0, -0.7, 0)
	trailTop.Parent, trailBottom.Parent = root, root
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1, trail.Lifetime, trail.FaceCamera = trailTop, trailBottom, 0.35, true
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
	trail.Parent = root
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.new(1, 1, 1))
	smoke.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8)})
	smoke.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)})
	smoke.Lifetime, smoke.Speed, smoke.Rate, smoke.Parent = NumberRange.new(0.4, 0.7), NumberRange.new(0.5, 1.5), 40, trailTop
	local camera = workspace.CurrentCamera
	local landed, chasing = false, true
	local flight = Instance.new("NumberValue")
	flight.Parent = self.folder
	flight.Changed:Connect(function(u)
		if not hero.Parent or landed then return end
		local a, b = struck:Lerp(peak, u), peak:Lerp(landing, u)
		local at = a:Lerp(b, u)
		-- Fast tumble that eases as it flies, plus a sideways roll.
		hero:PivotTo(CFrame.lookAt(at, at + campDir) * CFrame.Angles(-(u ^ 0.7) * math.pi * 7, 0, u * math.pi * 1.5))
		if chasing and u > 0.03 then
			camera.CFrame = CFrame.lookAt(at + right * 15 + campDir * 6 + UP * 2.5, at)
		end
	end)
	-- Rise fast, hang at the top, then drop: an impact launch, not a glide.
	self:Spawn(function()
		task.wait(0.06)
		camera.FieldOfView = 62
		self:SpeedLines(true)
		self:Tween(flight, 0.85, {Value = 0.5}, QUAD, OUT).Completed:Wait()
		self:Sound("FallWhistle")
		self:Tween(flight, 1.0, {Value = 1}, QUAD, IN)
	end)

	-- 5. Crash Landing: a bounce, dizzy stars, then two friends rush over.
	self:Wait(hit + 1.35)
	chasing = false
	self:SpeedLines(false)
	self:Cut(heroSpot + right * 11 + inward * 8 + UP * 3, heroSpot + UP * 3, 60)
	self:Wait(hit + 1.92)
	landed = true
	trail.Enabled, smoke.Enabled = false, false
	self:Place(hero, heroSpot, inward)
	self:Dust(heroSpot + UP * 0.2, 1.5, 26)
	self:Ring(heroSpot + UP * 0.2, DUST, 7)
	self:Sparkle(heroSpot + UP * 1, Color3.new(1, 1, 1), 18, 0.8)
	self:Sound("CrashThud")
	self:Shake(0.7, 6)
	self:Hop(hero, 1.4, 0.36)
	self:Sound("BigBounce")
	self:Wait(hit + 2.35)
	self:Dust(heroSpot + UP * 0.2, 0.8, 8)
	self:Sound("SmallBounce")
	self:Hop(hero, 0.45, 0.22)
	self:Dolly(heroSpot + right * 8 + inward * 6 + UP * 2.4, heroSpot + UP * 1, 2.6, SINE)
	self:Wait(hit + 2.65)
	hero:SetAttribute("Defeated", true)
	self:Mood(hero, "worried")
	self:Dizzy(hero, 4.2)
	self:Wait(hit + 4.9)
	local f = hit + 4.9
	self:Caption(nil)
	local friends = {self:Stage(scene.chickens[2], "FriendLeft"), self:Stage(scene.chickens[3], "FriendRight")}
	self:Place(friends[1], ground(heroSpot - right * 12 - inward * 3), right)
	self:Place(friends[2], ground(heroSpot + right * 12 - inward * 3), -right)
	self:Brows(friends[1], "worried")
	self:Brows(friends[2], "worried")
	self:Cut(heroSpot + inward * 9 + right * 2 + UP * 3, heroSpot + UP * 1, 58)
	self:Dolly(heroSpot + inward * 7.5 + right * 1.5 + UP * 2.6, heroSpot + UP * 1, 3.6, SINE)
	self:Walk(friends[1], {ground(heroSpot - right * 12 - inward * 3), ground(heroSpot - right * 2.6)}, 7, true)
	self:Walk(friends[2], {ground(heroSpot + right * 12 - inward * 3), ground(heroSpot + right * 2.6)}, 7, true)
	self:Wait(f + 0.15)
	self:Pop(friends[1], "!", Color3.new(1, 1, 1), 0.7)
	self:Pop(friends[2], "!", Color3.new(1, 1, 1), 0.7)
	self:PlayTrack("Forward Advance", 1.5)
	self:Wait(f + 1.6)
	self:Face(friends[1], right, 0.2)
	self:Face(friends[2], -right, 0.2)
	self:Wait(f + 1.9)
	self:Hop(friends[1], 0.4, 0.22)
	self:Wait(f + 2.3)
	hero:SetAttribute("Defeated", false)
	self:Mood(hero, "neutral")
	self:Hop(hero, 0.6, 0.28)
	self:Wait(f + 2.7)
	self:Shiver(hero)

	-- 6. The Missing Chicken: three in a row and a gap where a fourth belongs.
	self:Wait(f + 3.5)
	local m = f + 3.5
	self:Caption("Recruit more chickens!")
	local function foot(model: Model): Vector3
		return model:GetPivot().Position - UP * (model:GetAttribute("FootOffset") or 1.25)
	end
	self:Walk(friends[1], {foot(friends[1]), slots[1]}, 6, true)
	self:Walk(hero, {foot(hero), slots[2]}, 6, true)
	self:Walk(friends[2], {foot(friends[2]), slots[3]}, 6, true)
	local road = lineup + inward * 40 + UP * 2
	local behindLine = lineup + UP * 1.5
	self:Cut(lineup - inward * 8 + right * 1 + UP * 2.4, road, 60, behindLine)
	self:Dolly(lineup - inward * 6 + right * 0.8 + UP * 2.1, road, 3.4, SINE, nil, behindLine)
	self:Wait(m + 1.1)
	for _, model in {friends[1], hero, friends[2]} do self:Face(model, inward, 0.2) end
	self:Wait(m + 1.4)
	local ghost = self:Stage(scene.chickens[1], "EmptySpot")
	self:Place(ghost, slots[4], inward)
	local outline = Instance.new("Highlight")
	outline.FillColor, outline.OutlineColor, outline.FillTransparency, outline.OutlineTransparency = Color3.new(0, 0, 0), Color3.new(1, 1, 1), 1, 1
	outline.DepthMode, outline.Parent = Enum.HighlightDepthMode.Occluded, ghost
	self:Tween(outline, 0.35, {FillTransparency = 0.15, OutlineTransparency = 0}, QUAD, OUT).Completed:Once(function()
		if outline.Parent then self:Tween(outline, 0.5, {OutlineTransparency = 0.6}, SINE, INOUT, -1, true) end
	end)
	local slotMark = self:Pop(ghost, "?", GOLD, -1)
	self:Sparkle(slots[4] + UP, Color3.new(1, 1, 1), 12, 0.6)
	self:Sound("EmptySpotAppears")
	self:Wait(m + 2.0)
	self:Face(friends[2], right, 0.2)
	self:Wait(m + 2.25)
	self:Face(hero, right, 0.2)
	self:Wait(m + 2.9)
	self:Face(hero, inward, 0.15)
	self:Hop(hero, 0.6, 0.26)
	self:Pop(hero, "!", GOLD, 0.7)
	self:Sound("HeroIdea")
	self:Mood(hero, "surprised")
	self:Mood(friends[1], "neutral")
	self:Mood(friends[2], "neutral")

	-- The hero dashes to the lever and rolls the fourth chicken.
	self:Wait(m + 3.4)
	local r = m + 3.4
	self:Fidget(friends[1], r + 6.5, 11)
	self:Fidget(friends[2], r + 6.5, 12)
	local dashFrom = foot(hero)
	local dash = (dashFrom - leverSpot).Magnitude / 9
	local dashMid = (dashFrom + leverSpot) / 2
	local dashSide = self:OpenSide(dashMid + UP * 1.5, flat(leverSpot - dashFrom).Unit:Cross(UP), 14)
	self:Cut(dashMid + dashSide * 13 + UP * 4.5, dashMid + UP * 1, 58)
	self:Dolly(dashMid + dashSide * 11 + UP * 4, leverSpot + UP * 1, dash + 0.4, SINE)
	self:Walk(hero, {dashFrom, leverSpot}, 9, true)
	self:Mood(hero, "determined")
	self:Sound("DashToLever")
	self:Wait(r + dash + 0.35)
	local p = r + dash + 0.35
	local machine = (leverAt + ground(podium)) / 2
	local machineSide = self:OpenSide(machine + UP * 1.5, flat(ground(podium) - leverAt).Unit:Cross(UP), 10)
	local machineTargets = {leverSpot + UP * 1.2, podium + UP * 1.2}
	local machineViews = {}
	for _, s2 in {machineSide, -machineSide} do
		for _, spec in {{9, 3.5}, {9, 5.5}, {7, 4.5}, {11, 6.5}} do
			table.insert(machineViews, machine + s2 * spec[1] + UP * spec[2])
		end
	end
	local machineView = self:Pick(machineViews, machineTargets)
	local machinePush = self:Pick({machineView:Lerp(machine + UP * 1.6, 0.15), machineView}, machineTargets)
	self:Cut(machineView, machine + UP * 1.5, 56)
	self:Dolly(machinePush, machine + UP * 1.6, 3.4, SINE)
	self:Face(hero, leverAt - leverSpot, 0.15)
	self:Wait(p + 0.2)
	self:Hop(hero, 0.9, 0.3)
	self:Sound("LeverHop")
	self:Wait(p + 0.35)
	self:PullLever(station)
	bump(hero, "AttackSerial")
	self:Sound("LeverPull")
	self:Dust(leverAt + UP * 0.3, 0.6, 6)
	self:Wait(p + 0.7)
	local mystery = self:Stage(scene.chickens[1], "Recruit")
	self:Place(mystery, podium, -inward)
	local shade = Instance.new("Highlight")
	shade.FillColor, shade.FillTransparency, shade.OutlineColor, shade.OutlineTransparency = Color3.new(0, 0, 0), 0, Color3.new(1, 1, 1), 0
	shade.DepthMode, shade.Parent = Enum.HighlightDepthMode.Occluded, mystery
	local question = self:Pop(mystery, "?", GOLD, -1)
	self:Sparkle(podium + UP, Color3.new(1, 1, 1), 10, 0.6)
	-- Shuffle beats speed up into the reveal, like a real roll.
	for i, beat in {0.95, 1.25, 1.5, 1.72, 1.92, 2.1} do
		self:Wait(p + beat)
		self:Sound("RollTick", 1 + (i - 1) * 0.07)
		self:Hop(mystery, 0.35, 0.16)
	end
	self:Wait(p + 2.5)
	shade:Destroy()
	if question then question:Destroy() end
	self:Flash(Color3.fromRGB(255, 244, 200), 0.45, 0.3)
	self:Sparkle(podium + UP * 1.2, GOLD, 40, 1.2)
	self:Ring(podium + UP * 0.1, GOLD, 5)
	local anchor = station:FindFirstChild("EffectAnchor")
	for _, item in (if anchor then anchor:GetDescendants() else {}) do
		if item:IsA("ParticleEmitter") then item:Emit(20) end
	end
	self:Sound("NewChickenReveal")
	self:Pop(mystery, "!", GOLD, 0.8)
	self:Brows(mystery, "surprised")
	self:Mood(hero, "surprised")
	self:Wait(p + 2.65)
	bump(mystery, "VictorySerial")
	self:Mood(mystery, "happy")
	self:Mood(hero, "happy")
	self:Wait(p + 2.9)
	self:Face(hero, podium - leverSpot, 0.15)
	self:Hop(hero, 0.6, 0.26)

	-- 7. One More: the new friend fills the gap, and the squad is ready.
	self:Wait(p + 3.7)
	local j = p + 3.7
	self:Caption("Build your army and take the island!")
	-- Jump down off the podium onto the yard, then walk to the gap.
	local toSlot = flat(slots[4] - podium).Unit
	local padReach = if pad and pad:IsA("BasePart") then math.max(pad.Size.X, pad.Size.Z) / 2 else 1.5
	local landAt = ground(podium + toSlot * (padReach + 1.6))
	self:Face(mystery, toSlot, 0.12)
	self:Wait(j + 0.15)
	local jumpTop = self:Pivot(mystery, podium + toSlot * (padReach * 0.6) + UP * 1.8, toSlot)
	self:Sound("RecruitJump")
	self:Spawn(function()
		self:Move(mystery, jumpTop, 0.24, QUAD, OUT).Completed:Wait()
		self:Move(mystery, self:Pivot(mystery, landAt, toSlot), 0.22, QUAD, IN).Completed:Wait()
		self:Dust(landAt + UP * 0.2, 0.6, 10)
		self:Sound("RecruitLand")
	end)
	self:Wait(j + 0.75)
	local join = (landAt - slots[4]).Magnitude / 8
	local back = (foot(hero) - slots[2]).Magnitude / 8
	self:Walk(mystery, {landAt, slots[4]}, 8, true)
	self:Walk(hero, {foot(hero), slots[2]}, 8, true)
	self:Cut(lineup - inward * 8 + right * 1 + UP * 2.4, road, 60, behindLine)
	self:Dolly(lineup - inward * 6.5 + right * 0.8 + UP * 2.2, road, join + 1.2, SINE, nil, behindLine)
	self:Wait(j + 0.75 + join)
	ghost:Destroy()
	if slotMark then slotMark:Destroy() end
	self:Sparkle(slots[4] + UP, GOLD, 22, 0.9)
	self:Ring(slots[4] + UP * 0.1, GOLD, 3.5)
	self:Sound("FriendJoins")
	local c = j + 1.05 + math.max(join, back)
	self:Wait(c)
	local squad = {friends[1], hero, friends[2], mystery}
	for _, model in squad do self:Face(model, inward, 0.2) end
	self:Wait(c + 0.3)
	for i, model in squad do
		self:Mood(model, "happy")
		task.delay((i - 1) * 0.08, function() if model.Parent then bump(model, "VictorySerial") end end)
	end
	self:Confetti(lineup + UP * 1.5)
	self:Sound("SquadJingle")
	self:Sound("SquadApplause")
	self:Dolly(lineup - inward * 4.5 + right * 0.6 + UP * 1.9, road, 1.6, SINE, nil, behindLine)

	-- Hand off: rise into the normal follow camera, then give back control.
	self:Wait(c + 1.8)
	self:Caption(nil)
	local body = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if body then
		local behind = body.Position - flat(body.CFrame.LookVector).Unit * 13 + UP * 6
		self:Dolly(behind, body.Position + UP * 2, 1.7, SINE, self.cameraFov or 70)
	end
	for _, bar in self.bars do self:Tween(bar, 1.4, {Size = UDim2.fromScale(1, 0)}, QUAD, INOUT) end
	self:Wait(c + 3.2)
	self:Tween(self.cover, 0.25, {BackgroundTransparency = 0}, QUAD, IN)
	self:Wait(c + 3.5)
	self:Finish(false)
end

function Intro:Destroy()
	if self.playing then
		self.playing = false
		if self.thread then pcall(task.cancel, self.thread) end
		self:Unlock()
	end
	if self.layer then self.layer:Destroy() end
end

return Intro
