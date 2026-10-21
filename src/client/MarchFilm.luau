--!strict
-- Tutorial lesson 8/8 (docs/team/COMMANDER_TUTORIAL.md, later October 21): the short
-- film after the player sends their Army to a Camp, copied from Stevin's reference
-- recording ("Your soldiers march into battle!" / "Defeat the enemy and capture their
-- camp!"): letterbox bars, one caption line, SKIP, a chase shot on the leading
-- marching chicken, then the Camp they are about to fight for. About seven seconds,
-- once per visit. Presentation only: the march and the fight run live underneath and
-- the win completes the tutorial (TutorialService). The bars, caption, SKIP,
-- Lock/Unlock and Cut/Dolly are HillIntro's staging.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("PetRoll"):WaitForChild("Shared")
local Guide = require(Shared.TutorialGuide)
local MapLayout = require(Shared.MapLayout)
local CampCommand = require(Shared.CampCommand)
local HillIntro = require(script.Parent.HillIntro)

local MarchFilm: any = setmetatable({}, {__index = HillIntro})
MarchFilm.__index = MarchFilm

local UP = Vector3.yAxis
local QUAD = Enum.EasingStyle.Quad
local MARCH_SECONDS, CAMP_SECONDS = 3.6, 3.4

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function MarchFilm.new(app)
	local self: any = HillIntro.new(app)
	self.layerName = "MarchFilm"
	return setmetatable(self, MarchFilm)
end

-- Called after every snapshot. Starts on the server's reply to the lesson's own order:
-- an early attack before the Egg Vacuum lessons plays nothing.
function MarchFilm:Observe(state, result)
	if self.seen or self.playing or not state or type(result) ~= "table" then return end
	if result.ok ~= true or result.action ~= "Attack" or type(state.outgoing) ~= "string" then return end
	local t = state.tutorial or {}
	if not t.guideStarted or t.guideSkipped or t.guideCompleted then return end
	local facts = Guide.Facts(state)
	if facts.Core or not facts.VacuumSell or self:Busy() then return end
	local command = self.app.base and self.app.base.nearestCommand
	self.seen, self.playing = true, true
	self.battleId, self.campModel = state.outgoing, command and command.model
	self.thread = task.spawn(function()
		local ok, why = pcall(function() self:Run() end)
		if not ok then warn("[MarchFilm] " .. tostring(why)) end
		if self.playing then self:Finish(false) end
	end)
end

-- Never the Hill's VFX or its round checks.
function MarchFilm:SetVFX(_on: boolean) end

-- The Camp just ordered (the prompt's model), else where the player stands.
function MarchFilm:CampCenter(): Vector3
	local anchor = self.campModel and CampCommand.Anchor(self.campModel)
	if anchor and anchor:IsA("BasePart") and anchor:IsDescendantOf(workspace) then return anchor.Position end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else workspace.CurrentCamera.CFrame.Position
end

-- The player's marching chickens (LiveBattleActors: side "A" of this battle).
function MarchFilm:Lead(camp: Vector3): Model?
	local world = workspace:FindFirstChild("PetRollWorld")
	local battles = world and world:FindFirstChild("Battles")
	local folder = battles and battles:FindFirstChild(self.battleId)
	local lead, best = nil, math.huge
	for _, model in if folder then folder:GetChildren() else {} do
		if model:IsA("Model") and model:GetAttribute("Side") == "A" then
			local distance = (flat(model:GetPivot().Position) - flat(camp)).Magnitude
			if distance < best then lead, best = model, distance end
		end
	end
	return lead
end

-- A moving subject cannot be a tween target, so the chase reads the lead's pivot
-- each frame and eases the camera after it (side and behind, toward its heading).
function MarchFilm:Chase(lead: Model, camp: Vector3)
	local camera = workspace.CurrentCamera
	local last = lead:GetPivot().Position
	local heading = flat(camp - last)
	heading = if heading.Magnitude > 0.1 then heading.Unit else Vector3.new(0, 0, -1)
	local function goal(at: Vector3): (Vector3, Vector3)
		local side = heading:Cross(UP)
		local focus = at + heading * 4 + UP * 1.5
		return self:Clear(focus, at - heading * 11 + side * 7 + UP * 5), focus
	end
	local position, focus = goal(last)
	self:Cut(position, focus, 60)
	if self.app.reducedMotion then return end
	self.chase = RunService.RenderStepped:Connect(function(dt: number)
		if not lead.Parent then self:StopChase();return end
		local at = lead:GetPivot().Position
		local moved = flat(at - last)
		last = at
		if moved.Magnitude > 0.02 then heading = heading:Lerp(moved.Unit, math.min(1, dt * 3)).Unit end
		local wantPosition, wantFocus = goal(at)
		local blend = 1 - math.exp(-dt * 5)
		position, focus = position:Lerp(wantPosition, blend), focus:Lerp(wantFocus, blend)
		camera.CFrame = CFrame.lookAt(position, focus)
	end)
end

function MarchFilm:StopChase()
	if self.chase then self.chase:Disconnect();self.chase = nil end
end

function MarchFilm:Unlock()
	self:StopChase()
	HillIntro.Unlock(self)
end

function MarchFilm:Run()
	local app = self.app
	self:Lock()
	self.clock = os.clock()
	local camp = self:CampCenter()
	local home = MapLayout.HomeFrame(app.state.plotIndex).Position
	local toward = flat(camp - home)
	toward = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 0, -1)
	local side = toward:Cross(UP)
	-- Black behind the bars while the yard streams back in around the marchers.
	self:Fade(0, 0.2)
	pcall(function() Players.LocalPlayer:RequestStreamAroundAsync(home, 2) end)
	self:Wait(0.25)
	-- Shot 1: chase the leading chicken out of the base.
	local lead = self:Lead(camp)
	if lead then self:Chase(lead, camp)
	else
		-- Streamed out or already gone: the road out of the base toward the Camp.
		self:Cut(home + toward * 10 - side * 14 + UP * 8, home + toward * 30, 60)
		self:Dolly(home + toward * 22 - side * 12 + UP * 7, home + toward * 45, MARCH_SECONDS, QUAD)
	end
	self:Fade(1, 0.3)
	self:Caption("Your Army marches into battle!")
	self.clock = os.clock()
	self:Wait(MARCH_SECONDS)
	-- Shot 2: the Camp from the side the Army comes from, the player on its ground.
	self:StopChase()
	if app.audio:Has("Whoosh") then app.audio:Play("Whoosh", nil, {voiceKey = "MarchFilm", cooldown = 0.5}) end
	local focus = camp + UP * 2
	self:Cut(camp - toward * 30 + side * 12 + UP * 15, focus, 62)
	self:Dolly(camp - toward * 21 + side * 6 + UP * 10, focus, CAMP_SECONDS, QUAD, 56)
	self:Caption("Defeat the enemy and capture their Camp!")
	self:Wait(MARCH_SECONDS + CAMP_SECONDS)
	self:Caption(nil)
end

return MarchFilm
