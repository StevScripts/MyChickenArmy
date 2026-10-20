--!strict
-- October 20 overhaul Auto Roll settings (S12, Stevin approved): stop at a "1 in X"
-- value instead of a rarity name, auto-recruit at a second "1 in X" value when the
-- player can afford it, and stop on mutations and Army upgrades. Rebirth chickens
-- always stop it (RollService). The value compares a chicken's zero-Luck odds, the
-- same "1 in X" the podium and the Index show. The server (RollService, the
-- PlayerSession save) and the client menu share this one shape.
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.PetCatalog)
local AutoRollRules = {}

export type Settings = {enabled: boolean, stopAt: number, recruitAt: number?, mutationStop: boolean, upgradeStop: boolean}

local settings = Config.AutoRoll
AutoRollRules.Min, AutoRollRules.Max = settings.MinOneIn, settings.MaxOneIn
AutoRollRules.Presets = settings.Presets
local RARITY_ORDER = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret"}

local function rollable(definition: any): boolean
	return type(definition) == "table" and type(definition.oneIn) == "number" and (definition.weight or 0) > 0
		and not definition.crateExclusive
end

-- Each rarity's most common member: old saves stored a rarity name ("Mythic" meant
-- Mythic and rarer), which converts to that rarity's smallest "1 in X".
local floors: {[string]: number} = {}
for _, id in Catalog.Order do
	local definition = Catalog[id]
	if rollable(definition) then
		floors[definition.rarity] = math.min(floors[definition.rarity] or math.huge, definition.oneIn)
	end
end

function AutoRollRules.Default(): Settings
	return {enabled = false, stopAt = settings.DefaultStop, recruitAt = nil, mutationStop = true, upgradeStop = true}
end

-- A typed, requested or saved value as a whole "1 in N", or nil when it is not a number.
function AutoRollRules.Clean(value: any): number?
	local n = tonumber(value)
	if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
	return math.clamp(math.floor(n + 0.5), AutoRollRules.Min, AutoRollRules.Max)
end

function AutoRollRules.FromRarity(rarity: any): number?
	local floor = if type(rarity) == "string" then floors[rarity] else nil
	return if floor then AutoRollRules.Clean(math.floor(floor)) else nil
end

-- Lenient save reader: anything odd falls back to the defaults and never fails a load.
-- Pre-October 20 saves hold stopAt = "Upgrade" or a rarity name; S7's interim save
-- held recruitAt as a rarity name. Both convert to "1 in X" values here.
function AutoRollRules.Read(saved: any): Settings
	local result = AutoRollRules.Default()
	if type(saved) ~= "table" then return result end
	result.enabled = saved.enabled == true
	result.mutationStop = saved.mutationStop ~= false
	local stop = saved.stopAt
	if type(stop) == "number" then
		result.stopAt = AutoRollRules.Clean(stop) or result.stopAt
		result.upgradeStop = saved.upgradeStop ~= false
	elseif type(stop) == "string" then
		result.upgradeStop = stop == "Upgrade"
		if stop ~= "Upgrade" then result.stopAt = AutoRollRules.FromRarity(stop) or result.stopAt end
	end
	local recruit = saved.recruitAt
	result.recruitAt = if type(recruit) == "number" then AutoRollRules.Clean(recruit)
		elseif type(recruit) == "string" then AutoRollRules.FromRarity(recruit) else nil
	return result
end

function AutoRollRules.Save(value: Settings): {[string]: any}
	return {enabled = value.enabled == true, stopAt = value.stopAt, recruitAt = value.recruitAt,
		mutationStop = value.mutationStop ~= false, upgradeStop = value.upgradeStop ~= false}
end

-- The "1 in X" a setting compares: the chicken's zero-Luck odds. Limited (event)
-- chickens have no catalog odds, so they use their offer chance instead.
function AutoRollRules.OneIn(species: string, chance: number?): number?
	local definition = Catalog[species]
	if definition and type(definition.oneIn) == "number" then return definition.oneIn end
	if type(chance) == "number" and chance > 0 and chance < 1 then return 1 / chance end
	return nil
end

function AutoRollRules.Meets(species: string, threshold: number?, chance: number?): boolean
	local oneIn = AutoRollRules.OneIn(species, chance)
	return threshold ~= nil and oneIn ~= nil and oneIn >= threshold
end

-- The next -/+ preset from a value (typed values step to the nearest preset).
function AutoRollRules.Step(value: number, direction: number): number
	local presets = AutoRollRules.Presets
	if direction > 0 then
		for _, preset in presets do if preset > value then return preset end end
		return presets[#presets]
	end
	for index = #presets, 1, -1 do
		if presets[index] < value then return presets[index] end
	end
	return presets[1]
end

local function commas(value: number): string
	local digits = string.format("%.0f", math.floor(value))
	return (digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- "1 in 20,000"
function AutoRollRules.Text(value: number): string
	return "1 in " .. commas(value)
end

-- What a stop value covers, for the menu: "Stops for 9 chickens (Mythic and up)".
function AutoRollRules.Describe(threshold: number, verb: string?): string
	local total, met = {}, {}
	local count = 0
	for _, id in Catalog.Order do
		local definition = Catalog[id]
		if rollable(definition) then
			local rarity = definition.rarity
			total[rarity] = (total[rarity] or 0) + 1
			if definition.oneIn >= threshold then
				met[rarity] = (met[rarity] or 0) + 1
				count += 1
			end
		end
	end
	local action = verb or "Stops for"
	if count == 0 then return "No chicken is that rare" end
	for _, rarity in RARITY_ORDER do
		if (met[rarity] or 0) > 0 then
			local some = met[rarity] < total[rarity]
			local band = if rarity == "Secret" then (if some then "rarest Secret" else "Secret only")
				else (if some then "rarer " .. rarity .. " and up" else rarity .. " and up")
			return action .. " " .. count .. (if count == 1 then " chicken" else " chickens") .. " (" .. band .. ")"
		end
	end
	return action .. " " .. count .. " chickens"
end

return AutoRollRules
