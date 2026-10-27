-- October 27 discovery probe (WS4 retention; docs/team/LUCKY_START_20261027.md): the
-- first-Uncommon / first-Rare pull, the new-species curve and the rarity shares of a new
-- profile's post-tutorial pulls, with the real RollService, LuckyStart, Rules and
-- ChickenLuck (Luck 0). Usage from tools/sim:
--   lune run harness.luau ../.. discovery_probe.luau trials=6000 pulls=40 [slots=1] [only=N]
-- pulls=300 is the long-run share check. Variants: before (Lucky Start off, FavoredRolls
-- 5 x 60%), the live Config (Lucky Start on, FavoredRolls from Config) never buying, and
-- the live Config buying the first Uncommon+ and Rare+ it sees (the Index then holds it).
local options = {}
for _, arg in ARGS do
	local k, v = string.match(arg, "^(%w+)=(.*)$")
	if k then options[k] = if tonumber(v) then tonumber(v) else v end
end
local TRIALS, PULLS, SLOTS = options.trials or 6000, options.pulls or 40, options.slots or 1
local Config = Harness.require(Harness.Shared.Config)
local Catalog = Harness.require(Harness.Shared.PetCatalog)
local Session = Harness.require(Harness.Server.PlayerSession)
local RollService = Harness.require(Harness.Server.RollService)
local LuckyStart = Harness.require(Harness.Server.LuckyStart)
local RANK = LuckyStart.Rank
local LIVE_FAVOR = table.clone(Config.Economy.FavoredRolls)
local LIVE_ENABLED = Config.LuckyStart.Enabled

-- variant: {lucky=boolean, favor={rolls, chance}, buy="never"|"first"}
local function run(variant, seed)
	Config.LuckyStart.Enabled = variant.lucky
	Config.Economy.FavoredRolls = {rolls = variant.favor[1], chance = variant.favor[2], species = "Duck"}
	local perPullU, perPullR, perPullNew = table.create(PULLS, 0), table.create(PULLS, 0), table.create(PULLS, 0)
	local share = {}
	local forcedU, forcedR = 0, 0
	local rolls = RollService.new()
	rolls.random = Random.new(seed)
	for trial = 1, TRIALS do
		local s = Session.new(-(80000 + trial), "Probe", 1)
		s.loaded = true
		s:AddPet("Duck", 1); s:AddPet("Duck", 1)
		s.tutorial.bought, s.tutorial.guideCompleted, s.tutorial.rollCount = true, true, 2
		s.rollSlotsUnlocked, s.rollSlotLimit, s.rollSlotCount = SLOTS, Config.RollSlotsUnlocked, SLOTS
		local seen, seenU, seenR = {Duck = true}, false, false
		for k = 1, PULLS do
			s.rollReadyAt = 0
			assert(rolls:Roll(s, 0), "roll failed")
			local gotU, gotR = false, false
			for _, offer in s.offers do
				local rarity = Catalog[offer.species].rarity
				local rank = RANK[rarity] or 1
				if rank >= 2 then gotU = true end
				if rank >= 3 then gotR = true end
				if offer.lucky == "Uncommon" then forcedU += 1 elseif offer.lucky == "Rare" then forcedR += 1 end
				if not seen[offer.species] then seen[offer.species] = true; perPullNew[k] += 1 end
				share[rarity] = (share[rarity] or 0) + 1
				-- "Buys first seen": the first Uncommon+ and Rare+ go into the Index.
				if variant.buy == "first" and ((rank >= 2 and not seenU) or (rank >= 3 and not seenR)) then
					s.discovered[offer.species] = true
				end
			end
			if gotU then seenU = true end
			if gotR then seenR = true end
			if seenU then perPullU[k] += 1 end
			if seenR then perPullR[k] += 1 end
		end
	end
	Config.Economy.FavoredRolls = LIVE_FAVOR
	Config.LuckyStart.Enabled = LIVE_ENABLED
	return {u = perPullU, r = perPullR, new = perPullNew, share = share, forcedU = forcedU, forcedR = forcedR}
end

local function pct(x) return string.format("%5.1f%%", 100 * x / TRIALS) end
local function report(name, res)
	print("== " .. name)
	local marks = {1, 2, 3, 5, 8, 10, 15, 20, 30, 40, 100, 300}
	local line, u, r, n = "  pull:       ", "  Unc+ seen:  ", "  Rare+ seen: ", "  new spp:    "
	local cum, cumNew = 0, {}
	for k = 1, PULLS do cum += res.new[k]; cumNew[k] = cum / TRIALS end
	for _, k in marks do
		if k <= PULLS then
			line ..= string.format("%7d", k)
			u ..= string.format("%7s", pct(res.u[k])); r ..= string.format("%7s", pct(res.r[k])); n ..= string.format("%7.2f", cumNew[k])
		end
	end
	print(line); print(u); print(r); print(n)
	local function median(list)
		for k = 1, PULLS do if list[k] >= TRIALS / 2 then return tostring(k) end end
		return ">" .. PULLS
	end
	local total = 0
	for _, v in res.share do total += v end
	local shares = ""
	for _, rarity in {"Common", "Uncommon", "Rare", "Epic", "Legendary"} do
		shares ..= string.format(" %s %.2f%%", rarity, 100 * (res.share[rarity] or 0) / total)
	end
	print(string.format("  median first Unc+ pull %s, first Rare+ pull %s; forced per player U %.2f R %.2f", median(res.u),
		median(res.r), res.forcedU / TRIALS, res.forcedR / TRIALS))
	print(string.format("  shares over %d pulls:%s", PULLS, shares))
end

local variants = {
	{"BEFORE: Lucky Start off, FavoredRolls 5 x 60%", {lucky = false, favor = {5, 0.6}, buy = "never"}},
	{"LIVE CONFIG, never buys", {lucky = LIVE_ENABLED, favor = {LIVE_FAVOR.rolls, LIVE_FAVOR.chance}, buy = "never"}},
	{"LIVE CONFIG, buys the first Uncommon+ and Rare+ seen", {lucky = LIVE_ENABLED, favor = {LIVE_FAVOR.rolls, LIVE_FAVOR.chance}, buy = "first"}},
}
if options.only then variants = {variants[options.only]} end
print(string.format("discovery_probe: %d trials, %d pulls, %d podium(s), Luck 0", TRIALS, PULLS, SLOTS))
for index, variant in variants do report(variant[1], run(variant[2], 1000 + index)) end
