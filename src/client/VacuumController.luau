--!strict
-- October 20 held Egg Vacuum, local presentation only (docs/team/COLLECTION_TOOLS.md).
-- EggService owns the pull, cargo and Coins; ToolService owns the Tool and its model.
-- This finds the local player's equipped vacuum, gives pulled eggs their landing
-- point (the nozzle) and plays the soft suction cue as they arrive. The robot vacuum
-- this module used to draw is retired (archive/robot-vacuum-20261020).
-- October 21 game feel: while eggs are in reach the tool hums ("VacuumLoop") and the
-- nozzle shimmers; EggController decides when (SetActive) once a frame.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Feel = require(Shared.CollectionFeel)

local Vacuum = {}
Vacuum.__index = Vacuum

local TOOL = "EggVacuum"
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local SHIMMER = Color3.fromRGB(150, 214, 255) -- The vacuum's reach ring colour.

local function touchOnly()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- One small emitter on the nozzle (the handle without one): short-lived sparkles
-- drifting in around the mouth, enabled only while eggs are in reach.
local function shimmer(host: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name, emitter.Texture, emitter.Enabled = "VacuumShimmer", SPARKLES, false
	emitter.Color = ColorSequence.new(SHIMMER, Color3.new(1, 1, 1))
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
	emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
	emitter.Lifetime, emitter.Speed = NumberRange.new(0.3, 0.45), NumberRange.new(1.5, 3)
	emitter.SpreadAngle, emitter.Drag = Vector2.new(180, 180), 4
	emitter.Rate = if touchOnly() then Feel.Feel.VacuumParticleRateTouch else Feel.Feel.VacuumParticleRate
	emitter.LightEmission, emitter.Parent = 0.6, host
	return emitter
end

function Vacuum.new(app)
	return setmetatable({app = app, lastCue = -10, loop = nil, emitter = nil}, Vacuum)
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

-- A server-confirmed vacuum pickup arrived: a quiet tick at the tool.
function Vacuum:PickupCue(now: number)
	if now - self.lastCue < Feel.Egg.SoundGap then return end
	self.lastCue = now
	local tool = self:Tool()
	local handle = tool and tool:FindFirstChild("Handle")
	self.app.audio:Play("EggPickup", 1.08, {volume = Feel.Egg.RoverVolume, parent = handle, maxDuration = Feel.Egg.SoundTail,
		voiceKey = "VacuumPickup", cooldown = Feel.Egg.SoundGap, maxVoices = Feel.Egg.MaxVoices})
end

-- The loop and shimmer follow `active` (eggs in reach with room left). Both stop on
-- unequip, idle, reduced motion and Effects off (VFXLoop drops the voice itself).
-- Cheap when idle: one FindFirstChild and two nil checks a frame.
function Vacuum:SetActive(active: boolean)
	local tool = self:Tool()
	local handle = tool and tool:FindFirstChild("Handle")
	local on = active and handle ~= nil and handle:IsA("BasePart") and not self.app.reducedMotion
	if on then
		self.loop = self.app.audio:VFXLoop("VacuumLoop", handle, self.loop)
	elseif self.loop then
		self.loop:Destroy()
		self.loop = nil
	end
	local emitter = self.emitter
	if emitter and (not handle or not emitter:IsDescendantOf(handle)) then
		emitter:Destroy()
		emitter, self.emitter = nil, nil
	end
	if on and not emitter and handle then
		emitter = shimmer(handle:FindFirstChild("Nozzle") or handle)
		self.emitter = emitter
	end
	if emitter and emitter.Enabled ~= on then emitter.Enabled = on end
end

function Vacuum:Destroy()
	if self.loop then
		self.loop:Destroy()
		self.loop = nil
	end
	if self.emitter then
		self.emitter:Destroy()
		self.emitter = nil
	end
end

return Vacuum
