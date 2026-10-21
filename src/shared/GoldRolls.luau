--!strict
-- October 20 overhaul Gold rolls (S12; S12b counters). Stevin's Drop a Fruit recording
-- shows the machine's Gold and Diamond counts side by side ("6 Rolls Left" with a gold
-- die, "98 Rolls Left" with a blue one), so each machine counts lever pulls on its own:
-- Gold every 10th pull (8, 6 with Gold Rate), Diamond every 100th, Prism every 500th.
-- A special pull rolls every podium with extra Luck; when two land on one pull the
-- bigger boost wins. Numbers live in Config.GoldRolls. RollService counts pulls in the
-- saved goldRolls = {count (Gold), diamond, prism}; a Rebirth resets them.
local Config = require(script.Parent.Config)
local GoldRolls = {}

local settings = Config.GoldRolls
GoldRolls.Kinds = settings.Kinds
-- Saved goldRolls field for each kind (count is the original Gold field).
GoldRolls.Fields = {Gold = "count", Diamond = "diamond", Prism = "prism"} :: {[string]: string}
-- Counter icons. The dice art waits for its upload; until then the S6 machine icons
-- stand in (Prism uses the "RainbowMachine" art).
GoldRolls.Icons = {
	Gold = "rbxassetid://75354767460656",
	Diamond = "rbxassetid://113120386630417",
	Prism = "rbxassetid://90010215769789",
} :: {[string]: string}
-- Podium glow and tag color for each kind.
GoldRolls.Colors = {
	Gold = Color3.fromRGB(255, 206, 54),
	Diamond = Color3.fromRGB(120, 226, 255),
	Prism = Color3.fromRGB(255, 118, 214),
} :: {[string]: Color3}

export type Counter = {kind: string, every: number, count: number, left: number, luck: number}

local function whole(value: any, max: number): number
	local n = if type(value) == "number" and value == value then math.floor(value) else 0
	return math.clamp(n, 0, max)
end

-- goldMachine 0-3: none, Gold, Gold + Diamond, all three.
function GoldRolls.Machine(effects: any): number
	return whole(type(effects) == "table" and effects.goldMachine, #settings.Kinds)
end

-- Lever pulls per special pull of this kind.
function GoldRolls.Every(kind: string, effects: any): number
	if kind == "Gold" then
		local rate = whole(type(effects) == "table" and effects.goldRate, #settings.Every - 1)
		return settings.Every[rate + 1]
	end
	return (settings.KindEvery and settings.KindEvery[kind]) or 100
end

-- The Luck multiplier a special pull of this kind adds (1 for a normal pull).
function GoldRolls.Luck(kind: string?): number
	local index = if kind then table.find(settings.Kinds, kind) else nil
	return if index then settings.Luck[index] else 1
end

-- The owned counters, Gold first, for the machine display and the snapshot.
-- left = pulls until that kind's special pull, so 1 means the next pull.
function GoldRolls.Counters(saved: any, effects: any): {Counter}
	local counters = {}
	for index = 1, GoldRolls.Machine(effects) do
		local kind = settings.Kinds[index]
		local every = GoldRolls.Every(kind, effects)
		local done = math.min(whole(type(saved) == "table" and saved[GoldRolls.Fields[kind]], 1e6), every - 1)
		table.insert(counters, {kind = kind, every = every, count = done, left = every - done, luck = GoldRolls.Luck(kind)})
	end
	return counters
end

-- Server: counts one lever pull on every owned counter. Returns the special kind for
-- this pull (the biggest boost that landed), or nil.
function GoldRolls.Advance(saved: {[string]: any}, effects: any): string?
	local special = nil
	for index = 1, GoldRolls.Machine(effects) do
		local kind = settings.Kinds[index]
		local field = GoldRolls.Fields[kind]
		local done = whole(saved[field], 1e6) + 1
		if done >= GoldRolls.Every(kind, effects) then
			saved[field] = 0
			special = kind -- Later kinds have bigger boosts.
		else
			saved[field] = done
		end
	end
	return special
end

-- As the reference machine reads: "6 Rolls Left", "1 Roll Left".
function GoldRolls.Text(counter: Counter): string
	return counter.left .. (if counter.left == 1 then " Roll Left" else " Rolls Left")
end

return GoldRolls
