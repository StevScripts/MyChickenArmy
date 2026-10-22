--!strict
-- October 20 overhaul Rebirth chickens (docs/team/OVERHAUL_CONTRACT_20261020.md §7):
-- one Veteran Corps chicken per rank (PetCatalog.RebirthOrder), granted free at Lv 1
-- when the rank is reached, kept as a credit while storage is at its safety cap, and
-- offered on podiums afterwards. RebirthService and PlayerSession require this
-- module, so it never requires either of them.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.PetCatalog)
local Rules = require(Shared.Rules)
local RebirthChickens = {}

-- October 22 (Stevin): a Rebirth is earned by finding a chicken, not paid with one.
-- Ranks 1..Config.Rebirth.FindRanks each require PetCatalog.RebirthFinds[rank] in the
-- Index (session.discovered: owned once, sold or not); later ranks need only the Coins.
-- The grant, credit and podium-swap code below is dormant (RebirthOrder is empty) and
-- stays only to drain credits from old saves.
function RebirthChickens.Required(rank: number): string?
	local ranks = tonumber((Config.Rebirth :: any).FindRanks) or 0
	if type(rank) ~= "number" or rank ~= rank or rank < 1 or rank > ranks then return nil end
	local finds = (Catalog :: any).RebirthFinds
	local species = if type(finds) == "table" then finds[math.floor(rank)] else nil
	return if type(species) == "string" and Catalog[species] then species else nil
end

-- True when the rank needs no find or its chicken is in the Index.
function RebirthChickens.Found(session, rank: number): boolean
	local species = RebirthChickens.Required(rank)
	if species == nil then return true end
	local discovered = session.discovered
	return type(discovered) == "table" and discovered[species] == true
end

-- The next Rebirth's find while it is still missing: the podium offer Auto Roll stops
-- for and the simulation buys on sight.
function RebirthChickens.Wanted(session, species: string): boolean
	local rank = math.floor(tonumber(session.rebirths) or 0) + 1
	return RebirthChickens.Required(rank) == species and not RebirthChickens.Found(session, rank)
end

function RebirthChickens.Species(rank: number): string?
	return if type(rank) == "number" and rank == rank then Catalog.RebirthOrder[math.floor(rank)] else nil
end

-- Adds the rank's chicken at Lv 1 with nothing to refund. Storage full: a credit.
function RebirthChickens.Grant(session, rank: number): string?
	local species = RebirthChickens.Species(rank)
	if not species then return nil end
	if session:Count() >= session:CollectionLimit() then
		local credits = session.rebirthChickenCredits
		if #credits < Config.Rebirth.MaxRank then table.insert(credits, species) end
		session:Touch()
		return nil
	end
	local pet = session:AddPet(species, 1)
	pet.investment = 0
	session:Touch()
	return pet.id
end

-- Credits that fit now; returns the new pet ids so the world can walk them in.
function RebirthChickens.Deliver(session): {string}
	local delivered = {}
	local credits = session.rebirthChickenCredits
	while #credits > 0 and session:Count() < session:CollectionLimit() do
		local species = table.remove(credits, 1)
		if Catalog[species] and Catalog[species].rebirthRank then
			local pet = session:AddPet(species, 1)
			pet.investment = 0
			table.insert(delivered, pet.id)
		end
	end
	if #delivered > 0 then session:RefreshArmy(); session:Touch() end
	return delivered
end

-- Podium hook: RollService:Roll calls this right after EventService.MaybeReplace.
-- One draw decides (researchEffects.rebirthChickenChance, 1% base); a second picks
-- one of the player's unlocked Rebirth chickens. It only ever replaces a weaker
-- offer, so no stronger chicken loses odds.
function RebirthChickens.MaybeReplace(session, species: string, rng, _slot: number?): string
	local rank = math.min(math.floor(tonumber(session.rebirths) or 0), #Catalog.RebirthOrder)
	if rank < 1 or not Catalog[species] then return species end
	local effects = session.researchEffects
	local chance = if effects and type(effects.rebirthChickenChance) == "number" then effects.rebirthChickenChance else 0.01
	if rng:NextNumber() >= chance then return species end
	local pick = Catalog.RebirthOrder[math.clamp(math.floor(rng:NextNumber() * rank) + 1, 1, rank)]
	if Rules.PetPower(pick, 1, 1) <= Rules.PetPower(species, 1, 1) then return species end
	return pick
end

return RebirthChickens
