-- WS4 discovery probe: first-Uncommon / first-Rare pull and new-species curve with the
-- real RollService/Rules/ChickenLuck, today vs proposals. Usage:
--   lune run harness.luau ../.. <this> trials=20000 pulls=40 slots=1
local options = {}
for _, arg in ARGS do
	local k, v = string.match(arg, "^(%w+)=(.*)$")
	if k then options[k] = if tonumber(v) then tonumber(v) else v end
end
local TRIALS, PULLS, SLOTS = options.trials or 20000, options.pulls or 40, options.slots or 1
local Config = Harness.require(Harness.Shared.Config)
local Catalog = Harness.require(Harness.Shared.PetCatalog)
local Rules = Harness.require(Harness.Shared.Rules)
local Session = Harness.require(Harness.Server.PlayerSession)
local RollService = Harness.require(Harness.Server.RollService)
local RANK = {Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5, Mythic=6, Secret=7}
local ORIGINAL_FAVOR = table.clone(Config.Economy.FavoredRolls)

-- Draw a species of at least `minRank`, by today's odds renormalised (Luck applies).
local function drawAtLeast(session, rng, minRank, exact)
	local odds = Rules.Odds(session.luck, session.promotion, session:PaidLuckMultiplier(), session:RollLuckBonus())
	local total = 0
	for _, id in Catalog.Order do
		local r = RANK[Catalog[id].rarity] or 0
		if r >= minRank and (not exact or r == minRank) then total += odds[id] end
	end
	local x, acc = rng:NextNumber() * total, 0
	for _, id in Catalog.Order do
		local r = RANK[Catalog[id].rarity] or 0
		if r >= minRank and (not exact or r == minRank) then
			acc += odds[id]
			if x < acc then return id end
		end
	end
	return "Bee"
end

-- variant: {favor={rolls,chance}|nil, pity={uncommonAt, uncommonEvery, rareAt, rareEvery, window}|nil, buy="never"|"first"}
local function run(variant, seed)
	Config.Economy.FavoredRolls = if variant.favor then {rolls = variant.favor[1], chance = variant.favor[2], species = "Duck"} else {rolls = 0, chance = 0, species = "Duck"}
	local perPullU, perPullR, perPullNew = table.create(PULLS, 0), table.create(PULLS, 0), table.create(PULLS, 0)
	local share40, share = {}, {}
	local rolls = RollService.new()
	rolls.random = Random.new(seed)
	local rng = Random.new(seed + 99)
	local forcedU, forcedR = 0, 0
	for trial = 1, TRIALS do
		local s = Session.new(-(80000 + trial), "Probe", 1)
		s.loaded = true
		s:AddPet("Duck", 1); s:AddPet("Duck", 1)
		s.tutorial.bought, s.tutorial.guideCompleted, s.tutorial.rollCount = true, true, 2
		s.rollSlotsUnlocked, s.rollSlotLimit, s.rollSlotCount = SLOTS, Config.RollSlotsUnlocked, SLOTS
		s.luck = variant.luck or 0
		local seen, seenU, seenR = {Duck = true}, false, false
		local sinceU, sinceR, ownedU, ownedR = 0, 0, false, false
		local firesU, firesR, lastU, lastR = 0, 0, 0, 0
		local P0 = variant.pity or {}
		local nextU, nextR = P0.uncommonAt or 1e9, P0.rareAt or 1e9
		local now = 100
		for k = 1, PULLS do
			local forcedNow = nil
			-- Proposal (final rule): Lucky Start. nextU/nextR = post-tutorial pull that is forced;
			-- a natural offer of that rarity pushes it `again` pulls later; max 2 forced each;
			-- stops once owned or past the window.
			local p = variant.pity
			if p and k <= p.window then
				if not ownedR and firesR < 2 and k >= nextR then
					s.debugNext = drawAtLeast(s, rng, 3, true); forcedR += 1; firesR += 1; forcedNow = "R"
				elseif not ownedU and firesU < 2 and k >= nextU then
					s.debugNext = drawAtLeast(s, rng, 2, true); forcedU += 1; firesU += 1; forcedNow = "U"
				end
			end
			s.rollReadyAt = 0
			local ok = rolls:Roll(s, now)
			assert(ok, "roll failed")
			now += 60
			local gotU, gotR = false, false
			for _, offer in s.offers do
				local r = RANK[Catalog[offer.species].rarity] or 1
				if r >= 2 then gotU = true end
				if r >= 3 then gotR = true end
				if not seen[offer.species] then seen[offer.species] = true; perPullNew[k] += 1 end
				local bucket = Catalog[offer.species].rarity
				share[bucket] = (share[bucket] or 0) + 1
				if k <= 40 then share40[bucket] = (share40[bucket] or 0) + 1 end
			end
			if variant.pity then
				if gotU and k >= 1 then nextU = math.max(nextU, k + P0.uncommonAgain) end
				if gotR then nextR = math.max(nextR, k + P0.rareAgain) end
				if gotU and variant.buy ~= "first" and not ownedU and nextU <= k then nextU = k + P0.uncommonAgain end
			end
			sinceU = if gotU then 0 else sinceU + 1
			sinceR = if gotR then 0 else sinceR + 1
			if gotU and not seenU then seenU = true; if variant.buy == "first" then ownedU = true end end
			if gotR and not seenR then seenR = true; if variant.buy == "first" then ownedR = true end end
			if seenU then perPullU[k] += 1 end
			if seenR then perPullR[k] += 1 end
		end
	end
	Config.Economy.FavoredRolls = ORIGINAL_FAVOR
	return {u = perPullU, r = perPullR, new = perPullNew, share = share, share40 = share40, forcedU = forcedU, forcedR = forcedR}
end

local function pct(x) return string.format("%5.1f%%", 100 * x / TRIALS) end
local function report(name, res)
	print("== " .. name)
	local line = "  pull:      "
	local marks = {1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 30, 40}
	for _, k in marks do if k <= PULLS then line ..= string.format("%7d", k) end end
	print(line)
	local u, r, n, cum = "  Unc+ seen: ", "  Rare+ seen:", "  new spp:   ", 0
	local cumNew = {}
	for k = 1, PULLS do cum += res.new[k]; cumNew[k] = cum / TRIALS end
	for _, k in marks do
		if k <= PULLS then
			u ..= string.format("%7s", pct(res.u[k])); r ..= string.format("%7s", pct(res.r[k])); n ..= string.format("%7.2f", cumNew[k])
		end
	end
	print(u); print(r); print(n)
	-- median pull of first Uncommon / Rare
	local function median(arr)
		for k = 1, PULLS do if arr[k] >= TRIALS / 2 then return k end end
		return ">" .. PULLS
	end
	local total = 0
	for _, v in res.share do total += v end
	local sh = ""
	for _, rarity in {"Common", "Uncommon", "Rare", "Epic"} do sh ..= string.format(" %s %.2f%%", rarity, 100 * (res.share[rarity] or 0) / total) end
	print(string.format("  median first Unc+ pull %s, first Rare+ pull %s; forced U %.2f R %.2f per player; shares over %d pulls:%s",
		tostring(median(res.u)), tostring(median(res.r)), res.forcedU / TRIALS, res.forcedR / TRIALS, PULLS, sh))
end

local P = {uncommonAt = options.ua or 2, uncommonAgain = options.uag or 5, rareAt = options.ra or 8, rareAgain = options.rag or 10, window = options.win or 40}
local variants = {
	{"TODAY: FavoredRolls 5 x 60% Duck", {favor = {5, 0.6}}},
	{"FavoredRolls off, no pity", {favor = nil}},
	{"PROPOSAL (Favored 3x50%, Lucky Start) never buys", {favor = {3, 0.5}, pity = P, buy = "never"}},
	{"PROPOSAL buys first seen", {favor = {3, 0.5}, pity = P, buy = "first"}},
	{"PROPOSAL never buys, 1 podium, 100 pulls (share check)", {favor = {3, 0.5}, pity = P, buy = "never"}},
}
if options.only then variants = {variants[options.only]} end
for i, v in variants do report(v[1], run(v[2], 1000 + i)) end
