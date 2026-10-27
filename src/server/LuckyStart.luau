--!strict
-- October 27 Lucky Start (WS4 retention; docs/team/LUCKY_START_20261027.md). Live data:
-- the median player's first Uncommon came at post-tutorial pull 13 and the first Rare at
-- pull 87, while the median finisher pulls about five times. After the tutorial, an
-- empty-start profile's post-tutorial pull UncommonAt shows an Uncommon and RareAt a Rare
-- on podium 1 (Config.LuckyStart), each drawn by today's odds inside that rarity. Any
-- Uncommon+ (Rare+) offer on any podium, natural or forced, moves the next one
-- UncommonAgain (RareAgain) pulls later. At most MaxForced each, never once that rarity
-- is in the Index, never past Window post-tutorial pulls. Long-run rarity shares, the Luck
-- window and every "1 in X" stay as they are.
-- Pure functions over a session: RollService forces and records, PlayerSession saves the
-- additive `luckyStart` table, RollStation shows the countdown. Requires only shared
-- modules and RebirthChickens, so PlayerSession may require it.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.PetCatalog)
local Rules = require(Shared.Rules)
local RebirthChickens = require(script.Parent.RebirthChickens)
local LuckyStart = {}

LuckyStart.Rank = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7}
local KIND_RANK = {Uncommon = 2, Rare = 3}

local function settings(): any
	local value = (Config :: any).LuckyStart
	return if type(value) == "table" then value else {Enabled = false}
end

local function whole(value: any, low: number, high: number, default: number): number
	if type(value) ~= "number" or value ~= value then return default end
	return math.clamp(math.floor(value), low, high)
end

local function rankOf(species: string?): number
	local definition = species and Catalog[species]
	return if definition then LuckyStart.Rank[definition.rarity] or 1 else 1
end

-- A new profile's table: nothing pulled yet, the first Uncommon and Rare where Config puts them.
function LuckyStart.Fresh()
	local cfg = settings()
	return {pulls = 0, nextU = cfg.UncommonAt or 2, nextR = cfg.RareAt or 8, firesU = 0, firesR = 0}
end

-- Saved `luckyStart` (additive, October 27). Lenient: anything malformed reads as its
-- default and a missing table reads fresh; it never rejects a save.
function LuckyStart.Read(saved: any)
	local fresh = LuckyStart.Fresh()
	if type(saved) ~= "table" then return fresh end
	return {pulls = whole(saved.pulls, 0, 1000, 0), nextU = whole(saved.nextU, 1, 1000, fresh.nextU),
		nextR = whole(saved.nextR, 1, 1000, fresh.nextR), firesU = whole(saved.firesU, 0, 1000, 0),
		firesR = whole(saved.firesR, 0, 1000, 0)}
end

-- Empty-start profiles (introRebirth set) after a completed (not skipped) tutorial,
-- inside the window of post-tutorial pulls.
function LuckyStart.Active(session: any): boolean
	local cfg = settings()
	if cfg.Enabled ~= true or session.introRebirth == nil then return false end
	local t = session.tutorial
	if type(t) ~= "table" or t.guideSkipped == true or not (t.guideCompleted == true or t.coreDone == true) then return false end
	local state = session.luckyStart
	return type(state) == "table" and (tonumber(state.pulls) or 0) < (cfg.Window or 40)
end

-- True when the Index holds a chicken of this rarity rank or rarer (owned once).
function LuckyStart.Owns(session: any, rank: number): boolean
	local discovered = session.discovered
	if type(discovered) ~= "table" then return false end
	for species, found in discovered do
		if found == true and rankOf(species) >= rank then return true end
	end
	return false
end

-- The post-tutorial pull that forces `kind`, or nil when it is owned, capped or past the window.
local function nextFor(session: any, kind: string): number?
	local state, cfg = session.luckyStart, settings()
	local fires = if kind == "Rare" then state.firesR else state.firesU
	if fires >= (cfg.MaxForced or 2) or LuckyStart.Owns(session, KIND_RANK[kind]) then return nil end
	local at = if kind == "Rare" then state.nextR else state.nextU
	return if at <= (cfg.Window or 40) then at else nil
end

-- "Rare" or "Uncommon" when the next pull forces it (Rare first), else nil. Callers check Active.
function LuckyStart.Due(session: any): string?
	local k = session.luckyStart.pulls + 1
	local rare = nextFor(session, "Rare")
	if rare and k >= rare then return "Rare" end
	local uncommon = nextFor(session, "Uncommon")
	if uncommon and k >= uncommon then return "Uncommon" end
	return nil
end

-- A chicken of exactly `rarity`, by today's odds renormalised inside it (Luck applies
-- inside the rarity; starter-only and crate-only chickens already have odds 0).
function LuckyStart.Draw(session: any, rng: any, rarity: string, paidLuck: number?, researchLuck: number?): string?
	local odds = Rules.Odds(session.luck, session.recruitTier, paidLuck, researchLuck)
	local total = 0
	for _, id in Catalog.Order do
		if Catalog[id].rarity == rarity then total += odds[id] or 0 end
	end
	if total <= 0 then return nil end
	local pick, cumulative, last = rng:NextNumber() * total, 0, nil
	for _, id in Catalog.Order do
		local chance = if Catalog[id].rarity == rarity then odds[id] or 0 else 0
		if chance > 0 then
			cumulative += chance
			last = id
			if pick < cumulative then return id end
		end
	end
	return last
end

-- After a pull: counts it, pushes the next guarantees past any Uncommon+/Rare+ offer and
-- counts a forced one. Outside the window nothing changes.
function LuckyStart.Record(session: any, offers: {any}, forcedKind: string?)
	if not LuckyStart.Active(session) then return end
	local state, cfg = session.luckyStart, settings()
	local k = state.pulls + 1
	state.pulls = k
	for _, offer in offers do
		local rank = rankOf(offer.species)
		if rank >= 2 then state.nextU = math.max(state.nextU, k + (cfg.UncommonAgain or 5)) end
		if rank >= 3 then state.nextR = math.max(state.nextR, k + (cfg.RareAgain or 10)) end
	end
	if forcedKind == "Rare" then state.firesR += 1 elseif forcedKind == "Uncommon" then state.firesU += 1 end
end

-- The lever counter row and `state.luckyStart`: {kind, left} for the next guarantee
-- (Rare when it comes no later than the Uncommon), or nil when nothing is promised.
function LuckyStart.State(session: any): {kind: string, left: number}?
	if not LuckyStart.Active(session) then return nil end
	local pulls = session.luckyStart.pulls
	local rare, uncommon = nextFor(session, "Rare"), nextFor(session, "Uncommon")
	local kind, at
	if rare and (not uncommon or rare <= uncommon) then kind, at = "Rare", rare
	elseif uncommon then kind, at = "Uncommon", uncommon end
	if not kind or not at then return nil end
	return {kind = kind, left = math.max(1, at - pulls)}
end

-- "Rare in 6 Rolls" / "Rare next Roll!".
function LuckyStart.CounterText(state: any): string
	if type(state) ~= "table" then return "" end
	if state.left <= 1 then return state.kind .. " next Roll!" end
	return state.kind .. " in " .. state.left .. " Rolls"
end

-- The unbought offer a manual pull would roll past: a Lucky Start offer, any Rare+ while
-- Lucky Start runs, or the next Rebirth's find (slot order). Nil when the guard is off.
function LuckyStart.GuardOffer(session: any): any
	local cfg = settings()
	if cfg.Enabled ~= true or cfg.Guard ~= true then return nil end
	local active = LuckyStart.Active(session)
	for slot = 1, session.rollSlotCount or 1 do
		local offer = session.offers and session.offers[slot]
		if offer and not offer.starter and Catalog[offer.species] and (offer.lucky
			or (active and rankOf(offer.species) >= 3) or RebirthChickens.Wanted(session, offer.species)) then
			return offer
		end
	end
	return nil
end

-- "Robo-Cluck (Rare) is still on your podium! Pull again to roll past it."
function LuckyStart.GuardText(offer: any): string
	local definition = Catalog[offer.species]
	return definition.name .. " (" .. definition.rarity .. ") is still on your podium! Pull again to roll past it."
end

return LuckyStart
