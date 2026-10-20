--!strict
-- October 20 overhaul Gold rolls (S12; Stevin approved the RNG-game pattern of Sol's
-- RNG bonus rolls and Slime RNG's Golden/Diamond rolls). With the Gold Machine
-- (Upgrades tree effect goldMachine), every Nth lever pull is special and every podium
-- on that pull rolls with extra Luck. Gold Rate (goldRate) shortens the count; the
-- Diamond and Prism Machines raise the boost. Numbers live in Config.GoldRolls.
-- RollService counts pulls in the saved goldRolls.count (reset by a Rebirth).
local Config = require(script.Parent.Config)
local GoldRolls = {}

local settings = Config.GoldRolls
GoldRolls.Kinds = settings.Kinds
-- S6 machine icons, uploaded October 20 (Prism uses the "RainbowMachine" art).
GoldRolls.Icons = {
	Gold = "rbxassetid://75354767460656",
	Diamond = "rbxassetid://113120386630417",
	Prism = "rbxassetid://90010215769789",
} :: {[string]: string}
-- Podium glow, counter text and alert accents for each kind.
GoldRolls.Colors = {
	Gold = Color3.fromRGB(255, 206, 54),
	Diamond = Color3.fromRGB(120, 226, 255),
	Prism = Color3.fromRGB(255, 118, 214),
} :: {[string]: Color3}

export type State = {machine: number, kind: string?, every: number, count: number, left: number, luck: number, ready: boolean}

local function whole(value: any, max: number): number
	local n = if type(value) == "number" and value == value then math.floor(value) else 0
	return math.clamp(n, 0, max)
end

-- goldMachine 0-3: none, Gold, Diamond, Prism.
function GoldRolls.Machine(effects: any): number
	return whole(type(effects) == "table" and effects.goldMachine, #settings.Kinds)
end

-- The special pull's name for these effects, or nil without the Gold Machine.
function GoldRolls.Kind(effects: any): string?
	local machine = GoldRolls.Machine(effects)
	return if machine > 0 then settings.Kinds[machine] else nil
end

-- Lever pulls per special pull (every Nth), from the Gold Rate tier.
function GoldRolls.Every(effects: any): number
	local rate = whole(type(effects) == "table" and effects.goldRate, #settings.Every - 1)
	return settings.Every[rate + 1]
end

-- The Luck multiplier a special pull of this kind adds (1 for a normal pull).
function GoldRolls.Luck(kind: string?): number
	local index = if kind then table.find(settings.Kinds, kind) else nil
	return if index then settings.Luck[index] else 1
end

-- What the machine shows. left = pulls until the special one, so 1 means the next pull.
function GoldRolls.State(count: any, effects: any): State
	local kind = GoldRolls.Kind(effects)
	local every = GoldRolls.Every(effects)
	local done = math.min(whole(count, 1e6), every - 1)
	local left = every - done
	return {machine = GoldRolls.Machine(effects), kind = kind, every = every, count = done, left = left,
		luck = GoldRolls.Luck(kind), ready = kind ~= nil and left <= 1}
end

-- Server: counts one lever pull in the saved table and returns the kind when this
-- pull is the special one. Without the Gold Machine nothing is counted.
function GoldRolls.Advance(saved: {count: number}, effects: any): string?
	local kind = GoldRolls.Kind(effects)
	if not kind then return nil end
	local done = whole(saved.count, 1e6) + 1
	if done >= GoldRolls.Every(effects) then
		saved.count = 0
		return kind
	end
	saved.count = done
	return nil
end

-- "3 Rolls Left", or "Next roll is Gold!" when the next pull is special.
function GoldRolls.Text(state: State): string
	if not state.kind then return "" end
	if state.ready then return "Next roll is " .. state.kind .. "!" end
	return state.left .. " Rolls Left"
end

return GoldRolls
