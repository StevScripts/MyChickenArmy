-- unlock_probe.luau: "how fast is everything unlocked" on top of tests/ProgressionSimulation
-- (October 22, REBIRTH_PACING_20261021.md "Unlock-everything check"). Records, per seed: the
-- tree and Gem board at every Rebirth, first offer/owned per rarity, Luck tier changes and
-- the first purchase of every tree hex. key=value options as ProgressionSimulation; out=<json>.
local options = {}
for _, arg in ARGS do
	local k, v = string.match(arg, "^(%w+)=(.*)$")
	if k then options[k] = if v == "true" then true elseif v == "false" then false elseif tonumber(v) then tonumber(v) else v end
end
local out = options.out; options.out = nil
local Config = Harness.require(Harness.Shared.Config)
local Tree = Harness.require(Harness.Shared.UpgradeCatalog)
local Gems = Harness.require(Harness.Shared.GemUpgradeCatalog)
local Catalog = Harness.require(Harness.Shared.PetCatalog)
local Rolls = Harness.require(Harness.Server.RollService)
local Upgrades = Harness.require(Harness.Server.UpgradeService)
local Rebirth = Harness.require(Harness.Server.RebirthService)
local Playtime = Harness.require(Harness.Server.PlaytimeService)
local Sim = Harness.require(Harness.Tests.ProgressionSimulation)

-- Whole-tree and whole-board totals.
local treeTotal, treeTiers, families = 0, 0, {}
for _, id in Tree.FamilyOrder do
	local fam = Tree.Families[id]
	local sum, prices = 0, {}
	for t = 1, #fam.tiers do local p = Tree.Price(id, t) or 0; sum += p; prices[t] = p end
	families[id] = {tiers = #fam.tiers, total = sum, category = fam.category, prices = prices}
	treeTotal += sum; treeTiers += #fam.tiers
end
local gemTotal, gemLevels, gemCards = 0, 0, {}
for id, u in Gems.Upgrades do
	local sum = 0
	for _, p in u.prices do sum += p end
	gemTotal += sum; gemLevels += (u.maxLevel - u.startLevel)
	gemCards[id] = {levels = u.maxLevel - u.startLevel, total = sum, unlockRank = u.unlockRank}
end

local records, current = {}, nil
local function record(session)
	if current == nil or current.session ~= session then
		current = {session = session, seen = {}, owned = {}, luckLog = {}, rebirths = {}, firstTier = {}, lastNow = 0, lastLuck = 0}
		table.insert(records, current)
	end
	return current
end
local function scanOwned(session, now)
	for _, pet in session.pets do
		local d = Catalog[pet.species]
		if d and not current.owned[d.rarity] then
			current.owned[d.rarity] = {minutes = now / 60, rank = session.rebirths, species = pet.species, luck = session.luck}
		end
	end
end
local origRoll, origBuy, origFree = Rolls.Roll, Rolls.Buy, Playtime.FreeRolls
Rolls.Roll = function(self, session, now)
	local r = record(session)
	local ok, msg = origRoll(self, session, now)
	if ok then
		r.lastNow = now
		if session.luck ~= r.lastLuck then
			table.insert(r.luckLog, {tier = session.luck, minutes = now / 60, rank = session.rebirths})
			r.lastLuck = session.luck
		end
		for _, offer in session.offers or {} do
			local d = Catalog[offer.species]
			if d and not offer.starter and not r.seen[d.rarity] then
				r.seen[d.rarity] = {minutes = now / 60, rank = session.rebirths, species = offer.species, price = offer.price, luck = session.luck}
			end
		end
	end
	return ok, msg
end
Rolls.Buy = function(self, session, id, now, ...)
	local ok, msg = origBuy(self, session, id, now, ...)
	if ok then record(session); scanOwned(session, now) end
	return ok, msg
end
Playtime.FreeRolls = function(session, rolls)
	local granted = origFree(session, rolls)
	record(session); scanOwned(session, current.lastNow or 0)
	return granted
end
local origBuyNode = Upgrades.BuyNode
Upgrades.BuyNode = function(self, session, nodeId, ...)
	local ok, reason = origBuyNode(self, session, nodeId, ...)
	if ok then
		local r = record(session)
		if not r.firstTier[nodeId] then r.firstTier[nodeId] = {minutes = r.lastNow / 60, rank = session.rebirths} end
	end
	return ok, reason
end
local origRebirth = Rebirth.Rebirth
Rebirth.Rebirth = function(session, expectedRank, ...)
	local r = record(session)
	local owned, spent, perFamily = 0, 0, {}
	-- October 22: tree prices scale with rank (UpgradeCatalog.PriceScale), so the Coins
	-- spent on the tree and the whole-tree total are taken at this run's rank.
	local scale = Tree.PriceScale(session.rebirths)
	for id, fam in families do
		local tier = Tree.Tier(session.upgradeTree, id)
		owned += tier
		for t = 1, tier do spent += Tree.Price(id, t, session.rebirths) or 0 end
		perFamily[id] = tier
	end
	local gemsOwned = 0
	for id, u in Gems.Upgrades do gemsOwned += (Gems.Level(session.gemUpgrades, id) - u.startLevel) end
	local snap = {rank = session.rebirths + 1, coins = session.coins, gems = session.gems, treeOwned = owned, treeSpent = spent,
		tiers = perFamily, gemLevels = gemsOwned, luck = session.luck, minutes = r.lastNow / 60,
		treeTotal = treeTotal * scale, nextTreeTotal = treeTotal * Tree.PriceScale(session.rebirths + 1),
		nextCost = Rebirth.Cost(session.rebirths + 2)}
	local ok, reason, receipt = origRebirth(session, expectedRank, ...)
	if ok then table.insert(r.rebirths, snap) end
	return ok, reason, receipt
end

options.print = if options.print == nil then true else options.print
options.targetRank = options.targetRank or Config.Rebirth.MaxRank
local results = Sim.Run(options)

-- JSON needs string keys: stats.findWaits is keyed by rank (sparse).
for _, run in results.runs do
	local waits = run.stats and run.stats.findWaits
	if type(waits) == "table" then
		local byRank = {}
		for rank, seconds in waits do byRank[tostring(rank)] = seconds end
		run.stats.findWaits = byRank
	end
end
local probes = {}
for i, r in records do
	probes[i] = {seen = r.seen, owned = r.owned, luckLog = r.luckLog, rebirths = r.rebirths, firstTier = r.firstTier}
end
local function fmt(n)
	if n == nil then return "-" end
	for _, unit in {{1e15, "Qa"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}} do
		if math.abs(n) >= unit[1] then return string.format("%.2f%s", n / unit[1], unit[2]) end
	end
	return tostring(math.floor(n))
end
print(string.format("Tree: %d hexes, %s Coins in all at Rebirth 0 (x%.1f at Rebirth 10, x%.0f at 30, x%.0f at 49). Gem board: %d levels, %d Gems in all.",
	treeTiers, fmt(treeTotal), Tree.PriceScale(10), Tree.PriceScale(30), Tree.PriceScale(49), gemLevels, gemTotal))
for i, run in results.runs do
	local r = probes[i]
	print(string.format("-- seed %d rank %d after %.0f min (%.0f played)", run.seed, run.final.rank, run.minutes, run.played or run.minutes))
	for _, rarity in {"Legendary", "Mythic", "Secret"} do
		local s, o = r.seen[rarity], r.owned[rarity]
		print(string.format("   %-9s first offer %s min (R%s, %s)  first owned %s min (R%s, %s)", rarity,
			s and string.format("%.0f", s.minutes) or "never", s and s.rank or "-", s and s.species or "-",
			o and string.format("%.0f", o.minutes) or "never", o and o.rank or "-", o and o.species or "-"))
	end
	local luck = {}
	for _, e in r.luckLog do table.insert(luck, string.format("L%d@%.0fm(R%d)", e.tier, e.minutes, e.rank)) end
	print("   Luck: " .. table.concat(luck, " "))
	print("   Rebirth  wall min  Coins(cost)   tree hexes  tree spent  Mut Luck  Gems lv  next tree/income-after (min)  next tree/next cost")
	for _, snap in r.rebirths do
		local m = run.milestones["Rebirth" .. snap.rank]
		local income = m and m.income or 0
		local nextTree = snap.nextTreeTotal or treeTotal
		print(string.format("   R%-3d   %8.0f  %10s   %3d/%-3d   %10s   %d   %2d    %3d     %-8s  %s", snap.rank, m and m.minutes or snap.minutes,
			fmt(snap.coins), snap.treeOwned, treeTiers, fmt(snap.treeSpent), snap.tiers.Mutation or 0, snap.luck, snap.gemLevels,
			if income > 0 then string.format("%.1f", nextTree / income / 60) else "-",
			if snap.nextCost then string.format("%.0f%% (%s)", nextTree / snap.nextCost * 100, fmt(nextTree)) else "-"))
	end
	local firsts = {}
	for _, id in {"Mutation1", "Mutation2", "Mutation3", "Mutation4", "Luck4", "Luck8", "Luck12", "RollSlot7", "RollSpeed4", "Flock8", "EggSpeed4", "EggValue4",
		"PrismMachine", "PrismRate4", "FeedMaxLevel3", "EggVacuum", "AutoVacuum"} do
		local f = r.firstTier[id]
		table.insert(firsts, id .. "=" .. (f and string.format("%.0fm(R%d)", f.minutes, f.rank) or "never"))
	end
	print("   first buys: " .. table.concat(firsts, " "))
end
if out then
	Harness.fs.writeFile(out, Harness.serde.encode("json", {options = results.options, runs = results.runs, probes = probes,
		tree = {total = treeTotal, tiers = treeTiers, families = families}, gems = {total = gemTotal, levels = gemLevels, cards = gemCards}}))
	print("wrote " .. out)
end
