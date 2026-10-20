--!strict
-- October 20 held Egg Vacuum, local presentation only (docs/team/COLLECTION_TOOLS.md).
-- EggService owns the pull, cargo and Coins; ToolService owns the Tool and its model.
-- This finds the local player's equipped vacuum, gives pulled eggs their landing
-- point (the nozzle) and plays the soft suction cue as they arrive. The robot vacuum
-- this module used to draw is retired (archive/robot-vacuum-20261020).
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Feel = require(Shared.CollectionFeel)

local Vacuum = {}
Vacuum.__index = Vacuum

local TOOL = "EggVacuum"

function Vacuum.new(app)
	return setmetatable({app = app, lastCue = -10}, Vacuum)
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

return Vacuum
