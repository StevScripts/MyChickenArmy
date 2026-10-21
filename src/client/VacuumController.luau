--!strict
-- October 20 held Egg Vacuum, local presentation only (docs/team/COLLECTION_TOOLS.md).
-- EggService owns the pull, cargo and Coins; ToolService owns the Tool and its model.
-- This finds the local player's equipped vacuum and gives pulled eggs their landing
-- point (the nozzle). The robot vacuum this module used to draw is retired
-- (archive/robot-vacuum-20261020).
-- October 21 game feel: while eggs are in reach the tool hums ("VacuumLoop") and the
-- nozzle shimmers; EggController decides when (SetActive) once a frame.
-- October 21 reference parity (P6, docs/team/REFERENCE_PARITY_20261021.md 2.6): the
-- suction reads as a yellow swirl: two ribbons sweep in from the player's sides into the
-- nozzle (Beams with a scrolling soft texture and a looping curve sway) and the nozzle
-- sparkles gold. One persistent local effect, built once and switched on and off, so
-- it costs nothing per egg. The per-egg chime and "+N" float live in EggController.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Feel = require(Shared.CollectionFeel)

local Vacuum = {}
Vacuum.__index = Vacuum

local TOOL = "EggVacuum"
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
-- The reference's suction swirl: warm yellow fading to white at the mouth.
local GOLD = Color3.fromRGB(255, 214, 72)
local PALE = Color3.fromRGB(255, 246, 196)

local function touchOnly()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- One small emitter on the nozzle (the handle without one): short-lived gold sparkles
-- around the mouth, enabled only while eggs are in reach.
local function shimmer(host: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name, emitter.Texture, emitter.Enabled = "VacuumShimmer", SPARKLES, false
	emitter.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0)})
	emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	emitter.Lifetime, emitter.Speed = NumberRange.new(0.3, 0.45), NumberRange.new(1.5, 3)
	emitter.SpreadAngle, emitter.Drag = Vector2.new(180, 180), 4
	emitter.Rate = if touchOnly() then Feel.Feel.VacuumParticleRateTouch else Feel.Feel.VacuumParticleRate
	emitter.LightEmission, emitter.Parent = 0.7, host
	return emitter
end

type Swirl = {root: BasePart, handle: BasePart, parts: {Instance}, beams: {Beam}, sways: {Tween}}
type State = {app: any, loop: Sound?, emitter: ParticleEmitter?, swirl: Swirl?, swirlOn: boolean}

function Vacuum.new(app)
	local state: State = {app = app, loop = nil, emitter = nil, swirl = nil, swirlOn = false}
	return setmetatable(state, Vacuum)
end

-- The vacuum in the local player's hand, if equipped.
function Vacuum:Tool(): Tool?
	local character = Players.LocalPlayer.Character
	local tool = character and character:FindFirstChild(TOOL)
	return if tool and tool:IsA("Tool") and tool:GetAttribute("PetRollTool") == TOOL then tool else nil
end

function Vacuum:Equipped(): boolean
	return self:Tool() ~= nil
end

-- Where pulled eggs fly: the nozzle attachment, else the handle. Nil when put away.
function Vacuum:NozzlePosition(): Vector3?
	local tool = self:Tool()
	local handle = tool and tool:FindFirstChild("Handle")
	local nozzle = handle and handle:FindFirstChild("Nozzle")
	if nozzle and nozzle:IsA("Attachment") then return nozzle.WorldPosition end
	return if handle and handle:IsA("BasePart") then handle.Position else nil
end

function Vacuum:DestroySwirl()
	local swirl: Swirl? = self.swirl
	if not swirl then return end
	self.swirl, self.swirlOn = nil, false
	for _, sway in swirl.sways do sway:Cancel() end
	for _, part in swirl.parts do part:Destroy() end
end

-- Two ribbons, one from each side of the player, curving forward into the nozzle. Each
-- starts tangent to a circle of SwirlRadius round the player (Attachment0's axis), ends
-- coming into the mouth from the front (our own attachment on the handle), scrolls its
-- soft texture toward the mouth and sways its curve back and forth (one looping tween).
function Vacuum:BuildSwirl(root: BasePart, handle: BasePart): Swirl
	local knobs = Feel.Feel
	local nozzle = handle:FindFirstChild("Nozzle")
	local mouth = Instance.new("Attachment")
	mouth.Name = "VacuumSwirlMouth"
	-- Axis (+X) points back into the tool, so the curve's last control point sits in front of the mouth.
	mouth.CFrame = CFrame.fromMatrix(if nozzle and nozzle:IsA("Attachment") then nozzle.Position else Vector3.zero, Vector3.zAxis, Vector3.yAxis)
	mouth.Parent = handle
	local swirl: Swirl = {root = root, handle = handle, parts = {mouth}, beams = {}, sways = {}}
	local radius, height = knobs.SwirlRadius, knobs.SwirlHeight
	for index, angle in {math.rad(20), math.rad(160)} do
		-- Root space: +X right, -Z forward. The tangent leans forward on both sides.
		local at = Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
		local tangent = if index == 1 then Vector3.new(math.sin(angle), 0, -math.cos(angle))
			else Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local start = Instance.new("Attachment")
		start.Name = "VacuumSwirl" .. index
		start.CFrame = CFrame.fromMatrix(at, tangent, Vector3.yAxis)
		start.Parent = root
		table.insert(swirl.parts, start)
		local beam = Instance.new("Beam")
		beam.Name = "VacuumSwirl"
		beam.Attachment0, beam.Attachment1 = start, mouth
		beam.Texture, beam.TextureMode, beam.TextureLength = SMOKE, Enum.TextureMode.Wrap, 2.5
		-- Positive speed scrolls from Attachment0 toward Attachment1: into the mouth.
		beam.TextureSpeed = knobs.SwirlSpeed
		beam.Color = ColorSequence.new(GOLD, PALE)
		local base = knobs.SwirlTransparency
		beam.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, base),
			NumberSequenceKeypoint.new(0.8, base + 0.1), NumberSequenceKeypoint.new(1, 0.85)})
		beam.Width0, beam.Width1 = knobs.SwirlWidth, 0.35
		beam.CurveSize0, beam.CurveSize1 = knobs.SwirlCurve[1], 1.2
		beam.FaceCamera, beam.Segments, beam.LightEmission, beam.LightInfluence = true, 16, 0.8, 0
		beam.Enabled = false
		beam.Parent = start
		table.insert(swirl.beams, beam)
		local sway = TweenService:Create(beam, TweenInfo.new(knobs.SwirlSway, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{CurveSize0 = knobs.SwirlCurve[2]})
		table.insert(swirl.sways, sway)
	end
	return swirl
end

-- The swirl follows `on`; it is rebuilt when the character or the tool changes.
function Vacuum:SetSwirl(on: boolean, handle: BasePart?)
	local character = Players.LocalPlayer.Character
	local found = character and character:FindFirstChild("HumanoidRootPart")
	local root: BasePart? = if found and found:IsA("BasePart") then found else nil
	local swirl: Swirl? = self.swirl
	-- A new character or tool (or a put-away one) needs fresh parts.
	if swirl and (swirl.root ~= root or swirl.handle ~= handle or not swirl.root.Parent or not swirl.handle.Parent) then
		self:DestroySwirl()
		swirl = nil
	end
	if on and not swirl and root and handle then
		swirl = self:BuildSwirl(root, handle)
		self.swirl = swirl
	end
	if not swirl or self.swirlOn == on then return end
	self.swirlOn = on
	for _, beam in swirl.beams do beam.Enabled = on end
	for _, sway in swirl.sways do
		if on then sway:Play() else sway:Pause() end
	end
end

-- The loop, shimmer and swirl follow `active` (eggs in reach with room left). All stop
-- on unequip, idle, reduced motion and Effects off (VFXLoop drops the voice itself).
-- Cheap when idle: one FindFirstChild and a few nil checks a frame.
function Vacuum:SetActive(active: boolean)
	local tool = self:Tool()
	local found = tool and tool:FindFirstChild("Handle")
	local handle: BasePart? = if found and found:IsA("BasePart") then found else nil
	local on = active and handle ~= nil and not self.app.reducedMotion
	local loop: Sound? = self.loop
	if on then
		self.loop = self.app.audio:VFXLoop("VacuumLoop", handle, loop)
	elseif loop then
		loop:Destroy()
		self.loop = nil
	end
	local emitter: ParticleEmitter? = self.emitter
	if emitter and (not handle or not emitter:IsDescendantOf(handle)) then
		emitter:Destroy()
		emitter, self.emitter = nil, nil
	end
	if on and not emitter and handle then
		emitter = shimmer(handle:FindFirstChild("Nozzle") or handle)
		self.emitter = emitter
	end
	if emitter and emitter.Enabled ~= on then emitter.Enabled = on end
	if on or self.swirl then self:SetSwirl(on, handle) end
end

function Vacuum:Destroy()
	local loop: Sound?, emitter: ParticleEmitter? = self.loop, self.emitter
	if loop then loop:Destroy() end
	if emitter then emitter:Destroy() end
	self.loop, self.emitter = nil, nil
	self:DestroySwirl()
end

return Vacuum
