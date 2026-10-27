-- First-session probe (October 27, WS2 retention; docs/team/EARLY_ECONOMY_20261027.md).
-- A new player's first 20-30 minutes after the tutorial, second by second, on the real
-- modules: PlayerSession, RollService (rolls, the tutorial ladder, favoured rolls),
-- UpgradeService:BuyNode, RebirthService (Rebirth 0 with KeepTree, Rebirth 1 and its
-- find), DailyService (day 1, Playtime tiles), CombatRewards, PetCatalog and Rules.
-- Promoted from the plan's scratch model (retention-20261027/sims/ws2/early.luau).
--
-- Usage (from tools/sim):
--   lune run harness.luau ../.. first_session_probe.luau profile=typical
--   lune run harness.luau ../.. first_session_probe.luau profile=engaged seeds=30 minutes=30
-- Profiles (the plan's §3.1): typical is fitted to live earnings (Oct 26-27 ledger);
-- engaged pulls, sells and browses the tree three to four times as often.
-- Live settings by default: Config.Economy.StarterPrices / FavoredRolls, the Army Size
-- prices in UpgradeCatalog, Config.Rebirth.Intro.KeepTree and Fort Roost at
-- Config.CampLadder.Strength[2]. Overrides for comparisons:
--   starter=false keepTree=false strength=1 favoredSpec=5x0.6 tree=ArmySize:1:1200
--   guided=false (the player ignores the readiness card) lucky=false|true|auto
--   find1=Gamer (the Rebirth 1 find) minGain=0.05 verbose=true out=<file.json>
-- `lucky=auto` (default) approximates WS4's Lucky Start (an Uncommon at post-tutorial
-- pull 2 and a Rare at pull 8 on podium 1) only when src/server/LuckyStart.luau is
-- missing; with it, RollService applies the real one.
--
-- Model (quote with any number): the player sells the bag every sellEvery s at
-- efficiency eff (Gold Rush x2 for 5 of every 20 min at a seeded phase), claims the
-- vacuum 20 s after the tutorial and every Playtime tile, pulls when the podiums are
-- empty or an offer waited rollPatience s (twice that on a lucky, Rare+ or Rebirth-find
-- offer), buys an offer it can afford that lays, joins the Army or is the find, buys
-- only Flock before Rebirth 0 and the cheapest useful node after it, and takes Rebirth
-- 0/1 when eligible. Cluck Camp at 3 Army chickens; Fort Roost when the Army reaches
-- 1.3x its strength (the readiness card's "ready"), always won; 90 s away. guided=true
-- follows the readiness card after Cluck Camp: the best power per Coin among Army Size,
-- Get Feed and a Feed level, cardDelay s after the last step. Absolute minutes are
-- about +-30%; differences between variants are the reliable part.
local PROFILES = {
	typical = {pullGap = 45, rollPatience = 120, sellEvery = 90, eff = 0.6, treeGap = 120, treePerVisit = 1, feed = false,
		feedAfter = 0, cardDelay = 20},
	engaged = {pullGap = 15, rollPatience = 45, sellEvery = 60, eff = 0.85, treeGap = 30, treePerVisit = 2, feed = true,
		feedAfter = 300, cardDelay = 5},
}
local options = {profile = "typical", seeds = 30, minutes = 30, tutorialAt = 63, guided = true, lucky = "auto",
	starter = true, keepTree = true, strength = nil, favoredSpec = nil, tree = nil, find1 = nil, armyFirst = false,
	minGain = 0.05, verbose = false, out = nil}
local given = {}
for _, arg in ARGS do
	local k, v = string.match(arg, "^(%w+)=(.*)$")
	if k then given[k] = if v == "true" then true elseif v == "false" then false elseif tonumber(v) then tonumber(v) else v end
end
local profile = PROFILES[given.profile or options.profile]
assert(profile, "profile=typical|engaged")
for k, v in profile do options[k] = v end
for k, v in given do options[k] = v end

local Config = Harness.require(Harness.Shared.Config)
local Rules = Harness.require(Harness.Shared.Rules)
local Tree = Harness.require(Harness.Shared.UpgradeCatalog)
local Catalog = Harness.require(Harness.Shared.PetCatalog)
local Progression = Harness.require(Harness.Shared.Progression)
local MutationCatalog = Harness.require(Harness.Shared.MutationCatalog)
local CombatRewards = Harness.require(Harness.Shared.CombatRewards)
local PlaytimeRewards = Harness.require(Harness.Shared.PlaytimeRewards)
local Session = Harness.require(Harness.Server.PlayerSession)
local Rolls = Harness.require(Harness.Server.RollService)
local Upgrades = Harness.require(Harness.Server.UpgradeService)
local Rebirth = Harness.require(Harness.Server.RebirthService)
local Army = Harness.require(Harness.Server.ArmyService)
local DailyService = Harness.require(Harness.Server.DailyService)
local RebirthChickens = Harness.require(Harness.Server.RebirthChickens)

-- Variants -----------------------------------------------------------------------------
if options.starter == false and type(Config.Economy.StarterPrices) == "table" then Config.Economy.StarterPrices.Enabled = false end
Config.Rebirth.Intro.KeepTree = options.keepTree == true
if type(options.favoredSpec) == "string" then
	local r, c = string.match(options.favoredSpec, "(%d+)x([%d%.]+)")
	Config.Economy.FavoredRolls = {rolls = tonumber(r), chance = tonumber(c), species = "Duck"}
end
if type(options.tree) == "string" then
	local override = {}
	for fam, tier, price in string.gmatch(options.tree, "(%a+):(%d+):(%d+)") do override[fam .. tonumber(tier)] = tonumber(price) end
	local realPrice = Tree.Price
	Tree.Price = function(familyId, tier, rank) return override[familyId .. tostring(tier)] or realPrice(familyId, tier, rank) end
end
if options.find1 then
	local real = RebirthChickens.Required
	RebirthChickens.Required = function(rank) return if rank == 1 then options.find1 else real(rank) end
end
-- Fort Roost: the live strength (WS1, Progression.Strength when merged, else Config), the
-- readiness card's 1.3x goal.
local function liveStrength(index)
	local strength = (Progression :: any).Strength
	if type(strength) == "function" then return strength(index) end
	local ladder = (Config :: any).CampLadder
	local value = ladder and type(ladder.Strength) == "table" and ladder.Strength[index]
	return if type(value) == "number" then value else 1
end
local strength = tonumber(options.strength) or liveStrength(2)
local FORT_POWER = math.floor(Rules.Power(Progression.Roster(1, 2)) * strength)
local FORT_GOAL = math.ceil(FORT_POWER * 1.3)
local luckyApprox = options.lucky == true or (options.lucky == "auto" and Harness.Server:FindFirstChild("LuckyStart") == nil)

-- Starter prices: RollService quotes them once WS4's hunk is in; an offer still at its
-- list price (not the starter or the ladder's) gets Rules.StarterPrice here, so both agree.
local realRoll = Rolls.Roll
Rolls.Roll = function(self, s, now)
	local ok, msg = realRoll(self, s, now)
	if ok and s.introRebirth ~= nil then
		for _, offer in s.offers or {} do
			local list = Rules.RecruitPrice(offer.species, offer.level)
			if offer.starter ~= true and offer.listPrice == nil and offer.price == list then
				local price = Rules.StarterPrice(list, s:Count())
				if price < list then offer.price, offer.listPrice = price, list end
			end
		end
	end
	return ok, msg
end

-- Helpers (mirror tests/ProgressionSimulation) -------------------------------------------
local RANK = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7}
local function lcg(seed)
	local state = math.max(1, seed % 2147483647)
	local o = {}
	function o:NextNumber(low, high)
		state = state * 48271 % 2147483647
		local x = (state - 1) / 2147483646
		return if low and high then low + (high - low) * x else x
	end
	return o
end
local function petEggs(pet, level)
	return Rules.EggRate(pet.species, pet.stars or 1, level or pet.level) * MutationCatalog.Multiplier(pet.mutation)
end
local function homeLayers(s)
	local list = {}
	for id, pet in s.pets do if s:IsPetHome(id) then table.insert(list, pet) end end
	table.sort(list, function(a, b)
		local ea, eb = petEggs(a), petEggs(b)
		if ea ~= eb then return ea > eb end
		return a.id < b.id
	end)
	return list
end
local function unitValue(s)
	return Rules.EggUnitValue(s.incomeLevel) * (1 + s.researchEffects.eggValue) * (1 + (s.territoryBonus or 0))
end
local function rawRate(s)
	local layers = homeLayers(s)
	local eggs = 0
	for i = 1, math.min(s:FlockSize(), #layers) do eggs += petEggs(layers[i]) end
	return eggs * s:EggProductionMultiplier() * unitValue(s)
end
local function cashRate(s) return s:EarnedAmount(rawRate(s), "eggs") end
local function petPower(pet, level) return Rules.PetPower(pet.species, pet.stars or 1, level or pet.level, pet.giantSize) end
local function armyPower(s) return Rules.Power(s:Lineup()) end
local function nodePrice(s, fam, tier) return Tree.Price(fam, tier, s.rebirths) end
local function nextTier(s, fam)
	local t = Tree.Tier(s.upgradeTree, fam) + 1
	return if Tree.Families[fam].tiers[t] then t else nil
end

local function runOnce(seed)
	local rng = lcg(seed * 7919)
	local s = Session.new(-(90000 + seed), "First session", 1)
	s.loaded = true
	s.rollSlotLimit = Config.RollSlotsUnlocked
	local function syncSlots() s.rollSlotCount = math.clamp(s.rollSlotsUnlocked, 1, s.rollSlotLimit or 1) end
	syncSlots()
	local rolls = Rolls.new(); rolls.random = rng
	local upgrades = Upgrades.new(nil, rolls)
	local log, samples = {}, {}
	local lastRate, lastPower = 0, 0
	local stats = {rolls = 0, recruits = 0, eggCash = 0, playtime = 0, daily = 0, battle = 0, saved = 0}
	local function buyNode(fam, tier, tag, at)
		local price = nodePrice(s, fam, tier)
		local ok = upgrades:BuyNode(s, Tree.NodeId(fam, tier), price)
		if ok then
			syncSlots()
			table.insert(log, {t = at, kind = tag or "tree", name = Tree.NodeId(fam, tier), price = price,
				rateBefore = lastRate, powerBefore = lastPower, rateAfter = cashRate(s), powerAfter = armyPower(s)})
		end
		return ok
	end

	-- The tutorial, compressed: the free starter roll, three eggs sold, Flock Size I (10
	-- Coins), the second pull and the ladder's 20-Coin Chicken; complete at tutorialAt.
	local now = 2
	assert(rolls:Roll(s, now)); now = s.rollRevealAt + 0.01
	assert(rolls:Buy(s, s.offers[1].id, now))
	s:Credit(40, "eggs")
	upgrades:BuyNode(s, "Flock1", nodePrice(s, "Flock", 1))
	now += 10
	assert(rolls:Roll(s, now)); now = s.rollRevealAt + 0.01
	s.coins = math.max(s.coins, s.offers[1].price)
	assert(rolls:Buy(s, s.offers[1].id, now))
	local t = s.tutorial
	t.rolled, t.bought, t.soldEggs, t.collectedEggCount, t.startClaimed, t.rollCount = true, true, true, 3, true, 2
	t.eggsAtComplete = 3; t.coreDone, t.guideCompleted = true, true
	s.coins = 0
	now = options.tutorialAt
	-- Daily day 1 at completion.
	local grant = DailyService.Check(s, now + DailyService.DaySeconds, nil)
	if grant then stats.daily += grant.cash end
	local vacuumAt = now + 20
	local rushPhase = (seed * 277) % 1200
	local bag, nextSell = 0, now + options.sellEvery
	local offerSince, nextPullAt = nil, now + 5
	local claimed, campWins = {}, {}
	local away = nil
	local lucky = {pulls = 0, nextU = 2, nextR = 8, firesU = 0, firesR = 0}
	local function owns(rank)
		for id, yes in s.discovered or {} do
			if yes and Catalog[id] and (RANK[Catalog[id].rarity] or 0) >= rank then return true end
		end
		for _, pet in s.pets do if (RANK[Catalog[pet.species].rarity] or 0) >= rank then return true end end
		return false
	end
	local function drawRarity(rarity)
		local odds = Rules.Odds(s.luck, s.promotion, s:PaidLuckMultiplier(), s:RollLuckBonus())
		local total = 0
		for _, id in Catalog.Order do if Catalog[id].rarity == rarity then total += odds[id] end end
		local x, acc = rng:NextNumber() * total, 0
		for _, id in Catalog.Order do
			if Catalog[id].rarity == rarity then acc += odds[id]; if x < acc then return id end end
		end
		return if rarity == "Rare" then "Bucket" else "Bee"
	end
	local nextCardAt, nextTreeAt = 0, 0
	local cardSaving = nil
	local horizon = options.minutes * 60
	local sinceLastSample = 0
	local function wantsChicken(offer)
		local pet = {species = offer.species, stars = 1, level = offer.level, mutation = offer.mutation}
		local layers = homeLayers(s)
		local size = s:FlockSize()
		if #layers < size then return true, "lays" end
		if petEggs(pet) > petEggs(layers[size]) then return true, "lays" end
		local lineup = s:Lineup()
		if #lineup < s:Capacity() then return true, "army" end
		local worst = math.huge
		for _, p in lineup do worst = math.min(worst, petPower(p)) end
		if petPower(pet) > worst then return true, "army" end
		if RebirthChickens.Wanted(s, offer.species) then return true, "find" end
		return false, nil
	end
	local function rushFactor(at) return if ((at + rushPhase) % 1200) < 300 then 2 else 1 end
	local function sell(at)
		local whole = math.floor(bag * options.eff * rushFactor(at))
		if whole >= 1 then stats.eggCash += s:Credit(whole, "eggs"); bag = 0 end
	end
	local function record(entry, at)
		entry.t = at
		entry.rateAfter, entry.powerAfter = cashRate(s), armyPower(s)
		entry.rateBefore, entry.powerBefore = entry.rateBefore or lastRate, entry.powerBefore or lastPower
		table.insert(log, entry)
	end
	local function treeWish()
		local list = {}
		local function add(fam, cond)
			local tier = nextTier(s, fam)
			if tier and cond then
				local offer = Upgrades.NodeOffer(s, Tree.NodeId(fam, tier))
				if offer.status ~= "Locked" then table.insert(list, {fam = fam, tier = tier, price = nodePrice(s, fam, tier)}) end
			end
		end
		add("Flock", s:Count() > s:FlockSize())
		add("EggSpeed", true)
		add("EggValue", true)
		add("ArmySize", s:Count() > s:Capacity())
		add("RollSlot", Tree.Tier(s.upgradeTree, "RollSlot") < 1)
		if options.feed then add("ChickenFeed", (s.researchEffects.chickenFeed or 0) < 1 and s.introRebirth == "done") end
		table.sort(list, function(a, b)
			if options.armyFirst then
				local aa, bb = a.fam == "ArmySize", b.fam == "ArmySize"
				if aa ~= bb then return aa end
			end
			return a.price < b.price
		end)
		return list
	end
	local function feedTarget()
		if (s.researchEffects.chickenFeed or 0) < 1 then return nil end
		local best
		for _, entry in s:Lineup() do
			local pet = s.pets[entry.id]
			local level = pet.level or 1
			if level < s:LevelCap() then
				local price = Rules.ChickenUpgradePrice(pet.species, level)
				if price and (not best or price < best.price) then best = {pet = pet, level = level, price = price} end
			end
		end
		return best
	end
	while now < horizon do
		lastRate, lastPower = cashRate(s), armyPower(s)
		now += 1
		bag += rawRate(s)
		if now >= nextSell then sell(now); nextSell = now + options.sellEvery end
		for index, tile in PlaytimeRewards.Tiles do
			if not claimed[index] and now >= tile.at * 60 then
				claimed[index] = true
				if tile.kind == "Coins" then
					local coins = math.floor(DailyService.Income(s) * (tile.coinMinutes or 0) * 60)
					if coins > 0 then stats.playtime += s:Credit(coins, "playtime") end
				end
			end
		end
		if now >= vacuumAt and (s.researchEffects.eggVacuum or 0) < 1 then upgrades:BuyNode(s, "EggVacuum", 0) end
		-- The Army back from a camp: Kill Coins, the win and the territory bonus.
		if away and now >= away.untilAt then
			s.armyState = "Home"
			local cash = 0
			for _, unit in Progression.Roster(s.promotion, away.index) do cash += CombatRewards.ForUnit(unit, nil, false) end
			stats.battle += s:Credit(math.floor(cash * rushFactor(now)), "battle")
			s.firstWins[away.index] = true
			campWins[away.index] = now
			s.territoryBonus = (s.territoryBonus or 0) + (Config.Territories.CampBonus[away.index] or 0)
			record({kind = "camp", name = "Camp" .. away.index, price = 0}, now)
			away = nil
			s:RefreshArmy()
		end
		-- Rebirth 0, then Rebirth 1, as soon as eligible.
		if not away then
			if Rebirth.IntroPending(s) then
				local cost = Config.Rebirth.Intro.Cost
				if s.coins < cost and s.coins + s:EarnedAmount(bag * rushFactor(now), "eggs") >= cost then sell(now) end
				if Rebirth.Quote(s).eligible and Rebirth.RebirthIntro(s, nil) then
					bag = 0; s.territoryBonus = 0; s.firstWins = {}
					record({kind = "rebirth0", name = "Rebirth0", price = cost}, now)
					syncSlots()
				end
			elseif (s.rebirths or 0) == 0 and Rebirth.Quote(s).eligible and Rebirth.Rebirth(s, 0, nil, false) then
				bag = 0; s.territoryBonus = 0
				record({kind = "rebirth1", name = "Rebirth1", price = Rebirth.Cost(1)}, now)
				syncSlots()
			end
		end
		-- The lever.
		local anyOffer, protected = false, false
		for slot = 1, s.rollSlotCount or 1 do
			local o = s.offers and s.offers[slot]
			if o then
				anyOffer = true
				local r = RANK[Catalog[o.species].rarity] or 1
				if o.lucky or (lucky.pulls < 40 and r >= 3) or RebirthChickens.Wanted(s, o.species) then protected = true end
			end
		end
		local patience = if protected then options.rollPatience * 2 else options.rollPatience
		if now >= nextPullAt and now >= s.rollReadyAt and (not anyOffer or (offerSince and now - offerSince >= patience)) then
			local forced = nil
			if luckyApprox and lucky.pulls < 40 then
				local k = lucky.pulls + 1
				if not owns(3) and lucky.firesR < 2 and k >= lucky.nextR then forced = "Rare"
				elseif not owns(2) and lucky.firesU < 2 and k >= lucky.nextU then forced = "Uncommon" end
				if forced then s.debugNext = drawRarity(forced) end
			end
			if rolls:Roll(s, now) then
				stats.rolls += 1
				offerSince = s.rollRevealAt
				nextPullAt = s.rollRevealAt + options.pullGap
				if lucky.pulls < 40 then
					lucky.pulls += 1
					if forced == "Rare" then lucky.firesR += 1 elseif forced == "Uncommon" then lucky.firesU += 1 end
					for slot, o in s.offers or {} do
						local r = RANK[Catalog[o.species].rarity] or 1
						if r >= 2 then lucky.nextU = math.max(lucky.nextU, lucky.pulls + 5) end
						if r >= 3 then lucky.nextR = math.max(lucky.nextR, lucky.pulls + 10) end
						if forced and slot == 1 then o.lucky = forced end
					end
				end
			else
				s.debugNext = nil
			end
		end
		-- Buy a wanted offer as soon as the Coins cover it (selling the bag first if that does it).
		if now >= s.rollRevealAt then
			for slot = 1, s.rollSlotCount or 1 do
				local offer = s.offers and s.offers[slot]
				local want, why = false, nil
				if offer then want, why = wantsChicken(offer) end
				if offer and want then
					if s.coins < offer.price and s.coins + s:EarnedAmount(bag * rushFactor(now), "eggs") >= offer.price then sell(now) end
					local price, list = offer.price, offer.listPrice
					if s.coins >= price and rolls:Buy(s, offer.id, now) then
						stats.recruits += 1
						if list and list > price then stats.saved += list - price end
						s:RefreshArmy()
						record({kind = "chicken", name = offer.species, price = price, why = why, rarity = Catalog[offer.species].rarity}, now)
						nextPullAt = math.min(nextPullAt, now + options.pullGap)
					end
				end
			end
		end
		-- The readiness card (WS1): after Cluck Camp and until Fort Roost falls, the best
		-- power per Coin among Army Size, Get Feed and a Feed level.
		cardSaving = nil
		if options.guided and campWins[1] and not campWins[2] and not away and now >= nextCardAt and armyPower(s) < FORT_GOAL then
			local best
			local function consider(kind, gain, price, act)
				if gain > 0 and price and (not best or gain / price > best.gain / best.price) then best = {kind = kind, gain = gain, price = price, act = act} end
			end
			local tier = nextTier(s, "ArmySize")
			if tier then
				local slots = Tree.Families.ArmySize.tiers[tier].value - Tree.Value(s.upgradeTree, "ArmySize")
				local inLineup, spare = {}, {}
				for _, e in s:Lineup() do inLineup[e.id] = true end
				for id, pet in s.pets do if not inLineup[id] then table.insert(spare, petPower(pet)) end end
				table.sort(spare, function(a, b) return a > b end)
				local gain, empty = 0, 0
				for i = 1, slots do if spare[i] then gain += spare[i] else gain += 13; empty += 1 end end
				local price = nodePrice(s, "ArmySize", tier)
				consider("ArmySize", gain, price + 150 * empty, function()
					return price <= s.coins and buyNode("ArmySize", tier, "card", now)
				end)
			end
			local cheapest
			for _, e in s:Lineup() do
				local pet = s.pets[e.id]
				local level = pet.level or 1
				if level < s:LevelCap() then
					local q = Rules.ChickenUpgradePrice(pet.species, level)
					local g = petPower(pet, level + 1) - petPower(pet, level)
					if q and (not cheapest or g / q > cheapest.g / cheapest.q) then cheapest = {pet = pet, level = level, q = q, g = g} end
				end
			end
			if cheapest then
				if (s.researchEffects.chickenFeed or 0) >= 1 then
					consider("Feed", cheapest.g, cheapest.q, function()
						local ok = Army.UpgradeChicken(s, cheapest.pet.id, cheapest.level, cheapest.q)
						if ok then record({kind = "feed", name = "card", price = cheapest.q}, now) end
						return ok
					end)
				else
					local fp = nodePrice(s, "ChickenFeed", 1)
					consider("GetFeed", cheapest.g, fp + cheapest.q, function()
						return fp <= s.coins and buyNode("ChickenFeed", 1, "card", now)
					end)
				end
			end
			if best then
				if best.price <= s.coins + s:EarnedAmount(bag * rushFactor(now), "eggs") then
					if s.coins < best.price then sell(now) end
					if best.act() then nextCardAt = now + options.cardDelay end
				else
					cardSaving = best.price
				end
			end
		end
		-- The tree: Flock only before Rebirth 0; then the cheapest useful node.
		if now >= nextTreeAt and not cardSaving then
			local boughtAny = false
			for _ = 1, options.treePerVisit do
				local pick
				for _, item in treeWish() do
					if item.fam ~= "Flock" and Rebirth.IntroPending(s) then continue end
					if item.price <= s.coins then pick = item; break end
				end
				if not pick or not buyNode(pick.fam, pick.tier, "tree", now) then break end
				boughtAny = true
			end
			if boughtAny or options.treeGap > 0 then nextTreeAt = now + options.treeGap end
		end
		-- The engaged player feeds fighters while Fort Roost is out of reach.
		if options.feed and now >= options.feedAfter and not campWins[2] and not away then
			local f = feedTarget()
			if f and f.price <= s.coins * 0.5 and Army.UpgradeChicken(s, f.pet.id, f.level, f.price) then
				record({kind = "feed", name = f.pet.species .. " Lv" .. (f.level + 1), price = f.price}, now)
			end
		end
		-- Camps: Cluck Camp at 3 Army chickens; Fort Roost at the readiness goal.
		if not away and s.armyState == "Home" then
			local power = armyPower(s)
			local target
			if not campWins[1] and #s:Lineup() >= 3 then target = 1
			elseif campWins[1] and not campWins[2] and power >= FORT_GOAL then target = 2 end
			if target then
				s.armyState = "Marching"
				away = {index = target, untilAt = now + 90}
			end
		end
		sinceLastSample += 1
		if sinceLastSample >= 30 then
			sinceLastSample = 0
			-- Coins/s with the Army counted at home (a marching Army does not lay).
			local state0 = s.armyState; s.armyState = "Home"
			local homeRate = cashRate(s); s.armyState = state0
			table.insert(samples, {t = now, coins = s.coins, rate = homeRate, power = armyPower(s), chickens = s:Count(),
				flock = s:FlockSize(), cap = s:Capacity(), earned = stats.eggCash + stats.playtime + stats.daily + stats.battle})
		end
	end
	return {seed = seed, log = log, samples = samples, stats = stats, campWins = campWins}
end

local runs = {}
for seed = 1, options.seeds do table.insert(runs, runOnce(seed)) end

-- Report ---------------------------------------------------------------------------------
local function median(xs)
	if #xs == 0 then return nil end
	table.sort(xs); return xs[math.ceil(#xs / 2)]
end
local function pct(xs, p)
	if #xs == 0 then return nil end
	table.sort(xs); return xs[math.clamp(math.ceil(#xs * p), 1, #xs)]
end
-- "Meaningful": raises steady Coins/s or Army power by minGain (5%), or a Rebirth.
local function meaningful(e)
	if e.kind == "rebirth0" or e.kind == "rebirth1" then return true end
	if not (e.kind == "chicken" or e.kind == "tree" or e.kind == "feed" or e.kind == "card") then return false end
	local r0, r1, p0, p1 = e.rateBefore or 0, e.rateAfter or 0, e.powerBefore or 0, e.powerAfter or 0
	return (r0 > 0 and r1 >= r0 * (1 + options.minGain)) or (p0 > 0 and p1 >= p0 * (1 + options.minGain)) or (r0 == 0 and r1 > 0)
end
local starterOn = type(Config.Economy.StarterPrices) == "table" and Config.Economy.StarterPrices.Enabled == true
print(string.format("First-session probe · %s · seeds %d · %d min · starter prices %s · Rebirth 0 KeepTree %s · Army Size I %s · Fort Roost %d (goal %d) · guided %s · lucky %s",
	options.profile, options.seeds, options.minutes, tostring(starterOn), tostring(Config.Rebirth.Intro.KeepTree),
	tostring(Tree.Price("ArmySize", 1, 0)), FORT_POWER, FORT_GOAL, tostring(options.guided), if luckyApprox then "approx" else "live/off"))
print(string.format("%5s %8s %8s %7s %6s %6s %5s %4s %8s", "min", "coins", "Coins/s", "earned", "power", "chick", "flock", "army", "buys"))
local function at(minute, field)
	local xs = {}
	for _, run in runs do
		local last
		for _, smp in run.samples do if smp.t <= minute * 60 then last = smp end end
		if last then table.insert(xs, last[field]) end
	end
	return median(xs)
end
for minute = 2, options.minutes do
	local buys = {}
	for _, run in runs do
		local n = 0
		for _, ev in run.log do if ev.t and ev.t <= minute * 60 and ev.t > options.tutorialAt and meaningful(ev) then n += 1 end end
		table.insert(buys, n)
	end
	print(string.format("%5d %8.0f %8.1f %7.0f %6d %6d %5d %4d %8d", minute, at(minute, "coins"), at(minute, "rate"), at(minute, "earned"),
		at(minute, "power"), at(minute, "chickens"), at(minute, "flock"), at(minute, "cap"), median(buys)))
end
local function gaps(lo, hi)
	local all, longest, counts = {}, {}, {}
	for _, run in runs do
		local prev, n, maxGap = lo, 0, 0
		for _, ev in run.log do
			if ev.t and ev.t > lo and ev.t <= hi and meaningful(ev) then
				table.insert(all, ev.t - prev); maxGap = math.max(maxGap, ev.t - prev); prev = ev.t; n += 1
			end
		end
		table.insert(longest, math.max(maxGap, hi - prev)); table.insert(counts, n)
	end
	return median(all), pct(all, 0.9), median(longest), median(counts)
end
for _, w in {{options.tutorialAt, 600, "tutorial-10 min"}, {600, 1200, "10-20 min"}} do
	local m, p90, longest, n = gaps(w[1], w[2])
	print(string.format("%-16s purchases %s · gap median %ss p90 %ss · longest dry spell (median run) %ss", w[3], tostring(n),
		tostring(m and math.floor(m)), tostring(p90 and math.floor(p90)), tostring(longest and math.floor(longest))))
end
for _, k in {"Rebirth0", "Camp1", "Camp2", "Rebirth1", "ArmySize1", "ArmySize2", "Flock2", "Flock3", "RollSlot1", "EggSpeed1", "EggValue1", "ChickenFeed1"} do
	local ts, reached = {}, 0
	for _, run in runs do
		for _, ev in run.log do if ev.name == k then table.insert(ts, ev.t / 60); reached += 1; break end end
	end
	local m = median(ts)
	print(string.format("  %-12s median %s min (%d/%d)", k, if m then string.format("%.1f", m) else "never", reached, #runs))
end
local rolls, recruits, saved, rare = {}, {}, {}, {}
for _, run in runs do
	table.insert(rolls, run.stats.rolls); table.insert(recruits, run.stats.recruits); table.insert(saved, run.stats.saved)
	for _, ev in run.log do if ev.kind == "chicken" then rare[ev.rarity] = (rare[ev.rarity] or 0) + 1 end end
end
local byRarity = {}
for k, v in rare do table.insert(byRarity, k .. "=" .. v) end
table.sort(byRarity)
print(string.format("rolls median %d · recruits median %d · Coins under list price median %d · bought by rarity %s",
	median(rolls), median(recruits), median(saved), table.concat(byRarity, ",")))
if options.verbose then
	for _, ev in runs[1].log do
		print(string.format("  %6.1f %-9s %-14s %8s %s", (ev.t or 0) / 60, ev.kind, ev.name, tostring(ev.price), tostring(ev.why or "")))
	end
end
if options.out then Harness.fs.writeFile(options.out, Harness.serde.encode("json", {options = options, runs = runs})) end
do
	local wins, reached = {}, 0
	for _, run in runs do
		local t = math.huge
		for _, ev in run.log do if ev.name == "Camp2" then t = ev.t / 60; break end end
		table.insert(wins, t)
		if t < math.huge then reached += 1 end
	end
	table.sort(wins)
	local function q(p) local v = wins[math.clamp(math.ceil(#wins * p), 1, #wins)]; return if v == math.huge then "never" else string.format("%.1f", v) end
	local m = gaps(options.tutorialAt, 600)
	print(string.format("SUMMARY fortGoal=%d fortWin p50=%s p90=%s (%d/%d) rate5=%.1f rate10=%.1f power5=%d power10=%d gapEarly=%ss",
		FORT_GOAL, q(0.5), q(0.9), reached, #wins, at(5, "rate"), at(10, "rate"), at(5, "power"), at(10, "power"), tostring(m and math.floor(m))))
end
