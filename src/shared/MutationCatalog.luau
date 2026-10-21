--!strict
-- Chicken mutations: a rare variant on any rolled chicken that multiplies its
-- eggs. Egg production only, never combat; Luck never changes these chances.
-- Contract: docs/team/launch/14_M1_MUTATIONS.md. Saved ids are the Defs keys;
-- PlayerSession drops any saved mutation IsValid rejects and keeps the chicken.
local MutationCatalog = {}

export type Def = {name: string, multiplier: number, chance: number, color: Color3}

-- Common to rare. Roll checks this list from the end (rarest first).
MutationCatalog.Order = {"Golden", "Rainbow", "Shadow", "Cosmic"} :: {string}

-- `color` is presentation only (badges and VFX); the other fields are the economy.
-- October 14 owner retune: Golden is "pretty rare, but not the rarest" (was 1/40);
-- the rarer mutations move down with it so the ladder keeps its order.
-- October 20 tree v2 (Stevin, S9c): mutations are bought in the Upgrades tree in this
-- order (UpgradeCatalog's Mutation family) and reset on Rebirth like the tree. This
-- replaces plan v2's Rebirth-rank unlocks; saves that had one by rank keep it
-- (PlayerSession's mutationKeep floors the tree tier).
MutationCatalog.Defs = {
	Golden  = {name = "Golden",  multiplier = 1.5, chance = 1/250,   color = Color3.fromRGB(255, 206, 54)},
	Rainbow = {name = "Rainbow", multiplier = 2,   chance = 1/800,   color = Color3.fromRGB(255, 118, 214)},
	Shadow  = {name = "Shadow",  multiplier = 3,   chance = 1/3000,  color = Color3.fromRGB(178, 104, 255)},
	Cosmic  = {name = "Cosmic",  multiplier = 5,   chance = 1/12000, color = Color3.fromRGB(96, 196, 255)},
} :: {[string]: Def}

function MutationCatalog.IsValid(id: any): boolean
	return type(id) == "string" and MutationCatalog.Defs[id] ~= nil
end

function MutationCatalog.Get(id: any): Def?
	return if type(id) == "string" then MutationCatalog.Defs[id] else nil
end

function MutationCatalog.Multiplier(id: any): number
	local def = MutationCatalog.Get(id)
	return if def then def.multiplier else 1
end

-- Sort key: 0 for none or unknown, then 1 (Golden) to 4 (Cosmic).
function MutationCatalog.Rank(id: any): number
	if not MutationCatalog.IsValid(id) then return 0 end
	return table.find(MutationCatalog.Order, id) or 0
end

-- One offer's mutation. `unlocked` is how many of Order can roll (the tree's
-- `mutations` effect, 0-4). Rarest unlocked first, one rng:NextNumber() per unlocked
-- check, so a fixed seed always gives the same result. Locked ones draw nothing.
-- chanceMultiplier (optional, October 20): 1 + the Mutation Luck Gem Upgrade
-- (researchEffects.mutationLuck). It scales every chance; the draws stay the same.
function MutationCatalog.Roll(rng, unlocked: number, chanceMultiplier: number?): string?
	local count = if type(unlocked) == "number" and unlocked == unlocked then math.floor(unlocked) else 0
	local scale = if type(chanceMultiplier) == "number" and chanceMultiplier == chanceMultiplier
		then math.clamp(chanceMultiplier, 1, 10) else 1
	local order = MutationCatalog.Order
	for index = math.min(count, #order), 1, -1 do
		local id = order[index]
		if rng:NextNumber() < MutationCatalog.Defs[id].chance * scale then return id end
	end
	return nil
end

-- The best mutation among fusion inputs (pet records), or nil. Missing entries are fine.
function MutationCatalog.Best(pets): string?
	local best: string?, bestMultiplier = nil, 1
	if type(pets) ~= "table" then return nil end
	for _, pet in pets do
		local id = if type(pet) == "table" then pet.mutation else nil
		if MutationCatalog.IsValid(id) then
			local multiplier = MutationCatalog.Multiplier(id)
			if best == nil or multiplier > bestMultiplier
				or (multiplier == bestMultiplier and MutationCatalog.Rank(id) > MutationCatalog.Rank(best)) then
				best, bestMultiplier = id, multiplier
			end
		end
	end
	return best
end

return MutationCatalog
