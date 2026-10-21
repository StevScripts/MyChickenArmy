--!strict
-- October 20 overhaul Auto Roll settings (S12b; Stevin: Drop a Fruit's board 1:1).
-- "Stop When Appear" rows: one per rarity, one per mutation plus Normal (no mutation),
-- and New Chicken / New Mutation. Any row that is ON stops Auto Roll; the recording
-- stopped for a Rare with every mutation row OFF. Rebirth chickens always stop it
-- (RollService). The server (RollService, the PlayerSession save) and the panel share
-- this one shape.
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.PetCatalog)
local Mutations = require(script.Parent.MutationCatalog)
local AutoRollRules = {}

export type Settings = {enabled: boolean, rarities: {[string]: boolean}, mutations: {[string]: boolean},
	newChicken: boolean, newMutation: boolean}

local settings = Config.AutoRoll
-- Panel order, rarest first, as on the reference board.
AutoRollRules.Rarities = settings.Rarities :: {string}
-- Our mutations in catalog order, then Normal (a chicken with no mutation).
AutoRollRules.Mutations = table.clone(Mutations.Order) :: {string}
table.insert(AutoRollRules.Mutations, "Normal")
local RANK: {[string]: number} = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7}

local function set(list: {string}): {[string]: boolean}
	local result = {}
	for _, key in list do result[key] = true end
	return result
end

-- Each rarity's most common member, to convert old "1 in X" saves.
local floors: {[string]: number} = {}
for _, id in Catalog.Order do
	local definition = Catalog[id]
	if type(definition.oneIn) == "number" and (definition.weight or 0) > 0 and not definition.crateExclusive then
		floors[definition.rarity] = math.min(floors[definition.rarity] or math.huge, definition.oneIn)
	end
end

local function rarer(rarity: string): {[string]: boolean}
	local result = {}
	for name, rank in RANK do
		if rank >= RANK[rarity] then result[name] = true end
	end
	return result
end

-- The rarity whose most common member sits nearest (on a log scale) to an old value.
local function nearest(oneIn: number): string
	local best, distance = "Legendary", math.huge
	for rarity, floor in floors do
		local gap = math.abs(math.log(floor) - math.log(oneIn))
		if gap < distance then best, distance = rarity, gap end
	end
	return best
end

local function readSet(value: any, allowed: {string}): {[string]: boolean}?
	if type(value) ~= "table" then return nil end
	local result = {}
	for key, on in value do
		if type(key) == "string" and on == true and table.find(allowed, key) then result[key] = true end
	end
	return result
end

function AutoRollRules.Default(): Settings
	return {enabled = false, rarities = set(settings.DefaultRarities), mutations = set(settings.DefaultMutations),
		newChicken = settings.DefaultNewChicken == true, newMutation = settings.DefaultNewMutation == true}
end

-- Lenient save reader; anything odd falls back to the defaults and never fails a load.
-- Saves from before S12b hold stopAt as "1 in X" (S12) or as "Upgrade" / a rarity name
-- (October 15): they turn on the nearest rarity and every rarer one, and Stop on
-- mutations turns on the four mutation rows.
function AutoRollRules.Read(saved: any): Settings
	local result = AutoRollRules.Default()
	if type(saved) ~= "table" then return result end
	result.enabled = saved.enabled == true
	local rarities = readSet(saved.rarities, AutoRollRules.Rarities)
	if rarities then
		result.rarities = rarities
		result.mutations = readSet(saved.mutations, AutoRollRules.Mutations) or {}
		result.newChicken = saved.newChicken == true
		result.newMutation = saved.newMutation == true
		return result
	end
	local stop = saved.stopAt
	if type(stop) == "number" and stop == stop and stop > 0 and stop < math.huge then
		result.rarities = rarer(nearest(math.max(2, stop)))
	elseif type(stop) == "string" and RANK[stop] then
		result.rarities = rarer(stop)
	end
	result.mutations = if saved.mutationStop == false then {} else set(settings.DefaultMutations)
	return result
end

-- The saved shape, plus the old fields so a server from before S12b reads something
-- close: the most common rarity that is ON as "1 in X", and whether mutations stop it.
function AutoRollRules.Save(value: Settings): {[string]: any}
	local rarities: {[string]: boolean} = readSet(value.rarities, AutoRollRules.Rarities) or {}
	local mutations: {[string]: boolean} = readSet(value.mutations, AutoRollRules.Mutations) or {}
	local legacyStop = math.huge
	for name in rarities do
		if floors[name] then legacyStop = math.min(legacyStop, math.floor(floors[name])) end
	end
	local anyMutation = false
	for _, id in Mutations.Order do
		if mutations[id] then anyMutation = true end
	end
	return {enabled = value.enabled == true, rarities = rarities, mutations = mutations,
		newChicken = value.newChicken == true, newMutation = value.newMutation == true,
		stopAt = if legacyStop < math.huge then legacyStop else 10000000, mutationStop = anyMutation, upgradeStop = false}
end

-- Why these settings stop for an offer, or nil: "rarity", "mutation", "normal",
-- "newChicken" or "newMutation". Rarity reads first, like the reference banner.
function AutoRollRules.Reason(value: Settings, rarity: string?, mutation: string?, newChicken: boolean, newMutation: boolean): string?
	if rarity and value.rarities[rarity] then return "rarity" end
	if mutation and value.mutations[mutation] then return "mutation" end
	if not mutation and value.mutations.Normal then return "normal" end
	if newChicken and value.newChicken then return "newChicken" end
	if newMutation and value.newMutation then return "newMutation" end
	return nil
end

local function article(word: string): string
	return if string.match(word, "^[AEIOUaeiou]") then "an " else "a "
end

-- The hit banner, as the reference words it: "Auto Roll found a Rare chicken!"
function AutoRollRules.Banner(reason: string?, rarity: string?, mutation: string?): string
	if reason == "rebirth" then return "Auto Roll found a Rebirth chicken!" end
	if reason == "mutation" and mutation then return "Auto Roll found " .. article(mutation) .. mutation .. " chicken!" end
	if reason == "newChicken" then return "Auto Roll found a new chicken!" end
	if reason == "newMutation" and mutation then return "Auto Roll found a new " .. mutation .. " chicken!" end
	local word = rarity or "rare"
	return "Auto Roll found " .. article(word) .. word .. " chicken!"
end

return AutoRollRules
