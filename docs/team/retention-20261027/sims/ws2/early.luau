-- WS2 early-economy agent model (scratch). A "typical new player" from tutorial completion
-- to minute N, on the real modules (PlayerSession, RollService, UpgradeService,
-- RebirthService, DailyService, PlaytimeRewards). Variants patch Config / prices first.
-- Usage (from tools/sim): lune run harness.luau ../.. <this> key=value ...
--   seeds=40 minutes=20 discount=0.25 discountEnd=rank1|recruits:12 r0mult=1.5 tree=Flock:4:8000
--   rollPatience=60 pullGap=15 sellEvery=60 eff=1 out=file.json verbose=true
local options = {seeds = 40, minutes = 20, find1 = nil, rollPatience = 60, pullGap = 15, sellEvery = 60, eff = 1,
	discount = 1, discountFloor = 150, discountEnd = "rank1", r0mult = nil, r0cost = nil, tree = nil,
	favored = nil, tutorialAt = 63, verbose = false, out = nil, feed = true, fortPower = 106, policy = "casual", treeGap = 0, treePerVisit = 4, feedAfter = 0, strength = nil, guided = false, cardDelay = 20, lucky = false, favoredSpec = nil}
for _, arg in ARGS do
	local k, v = string.match(arg, "^(%w+)=(.*)$")
	if k then options[k] = if v == "true" then true elseif v == "false" then false elseif tonumber(v) then tonumber(v) else v end
end

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

-- Variant patches -----------------------------------------------------------------
if options.r0mult then Config.Rebirth.Intro.Multiplier = options.r0mult end
if options.r0cost then Config.Rebirth.Intro.Cost = options.r0cost end
if options.favored == "off" then Config.Economy.FavoredRolls = nil end
if type(options.favoredSpec) == "string" then
	local r, c = string.match(options.favoredSpec, "(%d+)x([%d%.]+)")
	Config.Economy.FavoredRolls = {rolls = tonumber(r), chance = tonumber(c), species = "Duck"}
end
-- WS1: Fort Roost strength -> attack (readiness "ready") at 1.3x the scaled power.
local FORT_BASE = 0
if options.strength then
	local P = Harness.require(Harness.Shared.Progression)
	local R = Harness.require(Harness.Shared.Rules)
	FORT_BASE = math.floor(R.Power(P.Roster(1, 2)) * options.strength)
	options.fortPower = math.ceil(FORT_BASE * 1.3)
end
local RANK = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7}
local treeOverride = {}
if type(options.tree) == "string" then
	for fam, tier, price in string.gmatch(options.tree, "(%a+):(%d+):(%d+)") do
		treeOverride[fam .. tonumber(tier)] = tonumber(price)
	end
	local realPrice = Tree.Price
	Tree.Price = function(familyId, tier, rank)
		local o = treeOverride[familyId .. tostring(tier)]
		if o then return o end
		return realPrice(familyId, tier, rank)
	end
end

if options.r0keep then
	local realIntro = Rebirth.RebirthIntro
	Rebirth.RebirthIntro = function(session, server)
		local tree = table.clone(session.upgradeTree or {})
		local levels = {}
		for id, pet in session.pets do levels[id] = {pet.level, pet.cashLevels} end
		local ok, msg, receipt = realIntro(session, server)
		if ok then
			session.upgradeTree = tree
			if options.r0keep == "all" then
				for id, l in levels do if session.pets[id] then session.pets[id].level, session.pets[id].cashLevels = l[1], l[2] end end
			end
			session:RefreshEffects()
		end
		return ok, msg, receipt
	end
end
if options.find1 then
	local real = RebirthChickens.Required
	RebirthChickens.Required = function(rank)
		if rank == 1 then return options.find1 end
		return real(rank)
	end
end
-- The proposal: podium price for empty-start profiles during the discount window.
local function discountActive(s)
	if options.discount >= 1 then return false end
	if s.introRebirth == nil then return false end
	if options.fadeAt and options.fadeAt > 0 then return true end
	if options.discountEnd == "rank1" then return (s.rebirths or 0) == 0 end
	local n = tonumber(string.match(tostring(options.discountEnd), "recruits:(%d+)"))
	if n then return (s.wsRecruits or 0) < n end
	return true
end
local function starterPrice(s, species, level, price)
	if not discountActive(s) then return price end
	local f = options.discount
	if options.fadeAt and options.fadeAt > 0 then
		f = f + (1 - f) * math.clamp((s:Count() - 2) / (options.fadeAt - 2), 0, 1)
	end
	-- fade: recruits:N with fade=true scales linearly from discount to 1
	if options.fade and options.discountEnd ~= "rank1" then
		local n = tonumber(string.match(tostring(options.discountEnd), "recruits:(%d+)")) or 1
		f = f + (1 - f) * math.clamp((s.wsRecruits or 0) / n, 0, 1)
	end
	local p = math.ceil(price * f / 5) * 5
	return math.min(price, math.max(options.discountFloor, p))
end
local realRoll = Rolls.Roll
Rolls.Roll = function(self, s, now)
	local ok, msg = realRoll(self, s, now)
	if ok then
		for _, offer in s.offers or {} do
			if not offer.starter and offer.price and offer.price > 0 and not (offer.slot == 1 and offer.price < Rules.RecruitPrice(offer.species, offer.level)) then
				offer.price = starterPrice(s, offer.species, offer.level, offer.price)
			end
		end
	end
	return ok, msg
end

-- Helpers (mirror tests/ProgressionSimulation) ----------------------------------------
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
local function flockEggs(s)
	local layers = homeLayers(s)
	local eggs = 0
	for i = 1, math.min(s:FlockSize(), #layers) do eggs += petEggs(layers[i]) end
	return eggs * s:EggProductionMultiplier(), layers
end
local function rawRate(s) return flockEggs(s) * unitValue(s) end
local function cashRate(s) return s:EarnedAmount(rawRate(s), "eggs") end
local function petPower(pet, level) return Rules.PetPower(pet.species, pet.stars or 1, level or pet.level, pet.giantSize) end
local function armyPower(s) return Rules.Power(s:Lineup()) end
local function count(s) return s:Count() end

local function nodePrice(s, fam, tier) return Tree.Price(fam, tier, s.rebirths) end
local function nextTier(s, fam)
	local t = Tree.Tier(s.upgradeTree, fam) + 1
	return if Tree.Families[fam].tiers[t] then t else nil
end

local function runOnce(seed)
	local rng = lcg(seed * 7919)
	local s = Session.new(-(90000 + seed), "WS2", 1)
	s.loaded = true
	s.rollSlotLimit = Config.RollSlotsUnlocked
	local function syncSlots() s.rollSlotCount = math.clamp(s.rollSlotsUnlocked, 1, s.rollSlotLimit or 1) end
	syncSlots()
	local rolls = Rolls.new(); rolls.random = rng
	local upgrades = Upgrades.new(nil, rolls)
	local log, samples = {}, {}
	local lastRate, lastPower = 0, 0
	local stats = {rolls = 0, recruits = 0, eggCash = 0, playtime = 0, daily = 0, battle = 0, shortfalls = 0}
	local function buyNode(fam, tier, tag)
		local price = nodePrice(s, fam, tier)
		local ok = upgrades:BuyNode(s, Tree.NodeId(fam, tier), price)
		if ok then
			syncSlots()
			table.insert(log, {t = 0, kind = tag or "tree", name = Tree.NodeId(fam, tier), price = price,
				rateBefore = lastRate, powerBefore = lastPower, rateAfter = cashRate(s), powerAfter = armyPower(s)})
		end
		return ok
	end

	-- Tutorial (compressed): starter roll, Flock I, Start claimed, ladder Duck at 20.
	local now = 2
	assert(rolls:Roll(s, now)); now = s.rollRevealAt + 0.01
	assert(rolls:Buy(s, s.offers[1].id, now))
	s.coins += 0
	-- Tutorial eggs: three eggs sold, Start, Flock I (10 Coins), roll again, buy at 20.
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
	-- Daily day 1 (claimed at ~1 min in the data).
	local grant = DailyService.Check(s, now + DailyService.DaySeconds, nil)
	if grant then stats.daily += grant.cash end
	-- Egg Vacuum claim (free) ~20 s later.
	local vacuumAt = now + 20
	local rushPhase = (seed * 277) % 1200
	local bag, nextSell = 0, now + options.sellEvery
	local offerSince, nextPullAt = nil, now + 5
	local claimed = {}
	local away = nil
	local campWins = {}
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
	local nextCardAt = 0
	local cardSaving = nil
	local wsRecruitsLog = {}
	local horizon = options.minutes * 60
	local dt = 1
	local sinceLastSample = 0
	local nextTreeAt = 0
	local function wantsChicken(offer)
		-- Lays (beats the weakest Flock layer or fills a free Flock slot) or joins the Army.
		local pet = {species = offer.species, stars = 1, level = offer.level, mutation = offer.mutation}
		local layers = homeLayers(s)
		local size = s:FlockSize()
		if #layers < size then return true, "lays" end
		local weakest = layers[size]
		if petEggs(pet) > petEggs(weakest) then return true, "lays" end
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
		if whole >= 1 then
			local c = s:Credit(whole, "eggs"); stats.eggCash += c; bag = 0
		end
	end
	local function record(entry, at)
		entry.t = at
		entry.rateAfter, entry.powerAfter = cashRate(s), armyPower(s)
		entry.rateBefore, entry.powerBefore = entry.rateBefore or lastRate, entry.powerBefore or lastPower
		table.insert(log, entry)
	end
	local function treeWish()
		-- Useful tree nodes, cheapest first (the casual player browses the tree).
		local list = {}
		local function add(fam, cond)
			local tier = nextTier(s, fam)
			if tier and cond then
				local offer = Upgrades.NodeOffer(s, Tree.NodeId(fam, tier))
				if offer.status ~= "Locked" then table.insert(list, {fam = fam, tier = tier, price = nodePrice(s, fam, tier)}) end
			end
		end
		local layers = homeLayers(s)
		add("Flock", count(s) > s:FlockSize())
		add("EggSpeed", true)
		add("EggValue", true)
		add("ArmySize", count(s) > s:Capacity())
		add("RollSlot", (Tree.Tier(s.upgradeTree, "RollSlot") < 1))
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
		-- Cheapest Feed level on an Army chicken (the casual player feeds fighters for Fort Roost).
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
		now += dt
		-- Income: Flock lays into the bag; sold every sellEvery seconds.
		bag += rawRate(s) * dt
		if now >= nextSell then sell(now); nextSell = now + options.sellEvery end
		-- Playtime tiles (session clock = now; join at 0).
		for index, tile in PlaytimeRewards.Tiles do
			if not claimed[index] and now >= tile.at * 60 then
				claimed[index] = true
				if tile.kind == "Coins" then
					local coins = math.floor(DailyService.Income(s) * (tile.coinMinutes or 0) * 60)
					if coins > 0 then stats.playtime += s:Credit(coins, "playtime") end
				end
			end
		end
		if now >= vacuumAt and (s.researchEffects.eggVacuum or 0) < 1 then
			upgrades:BuyNode(s, "EggVacuum", 0)
		end
		-- Army back from a camp.
		if away and now >= away.untilAt then
			s.armyState = "Home"
			local cash = 0
			for _, unit in Progression.Roster(s.promotion, away.index) do cash += CombatRewards.ForUnit(unit, nil, false) end
			cash = math.floor(cash * rushFactor(now))
			stats.battle += s:Credit(cash, "battle")
			s.firstWins[away.index] = true
			campWins[away.index] = now
			s.territoryBonus = (s.territoryBonus or 0) + (Config.Territories.CampBonus[away.index] or 0)
			record({kind = "camp", name = "Camp" .. away.index, price = 0, power = armyPower(s)}, now)
			away = nil
			s:RefreshArmy()
		end
		-- Rebirth 0 (tip) / Rebirth 1 as soon as eligible.
		if not away then
			if Rebirth.IntroPending(s) then
				if s.coins < Config.Rebirth.Intro.Cost and s.coins + s:EarnedAmount(bag * rushFactor(now), "eggs") >= Config.Rebirth.Intro.Cost then sell(now) end
				if Rebirth.Quote(s).eligible then
					local ok = Rebirth.RebirthIntro(s, nil)
					if ok then
						bag = 0; s.territoryBonus = 0; s.firstWins = {}
						-- Camps stay won for the route; the flags are released. Re-take later is ignored.
						record({kind = "rebirth0", name = "Rebirth0", price = Config.Rebirth.Intro.Cost}, now)
						syncSlots()
					end
				end
			elseif (s.rebirths or 0) == 0 then
				local q = Rebirth.Quote(s)
				if q.eligible then
					local ok = Rebirth.Rebirth(s, 0, nil, false)
					if ok then bag = 0; s.territoryBonus = 0; record({kind = "rebirth1", name = "Rebirth1", price = Rebirth.Cost(1)}, now); syncSlots() end
				end
			end
		end
		-- Lever: pull when the podiums are empty, or the offer waited rollPatience seconds.
		local anyOffer, protected = false, false
		for slot = 1, s.rollSlotCount or 1 do
			local o = s.offers and s.offers[slot]
			if o then
				anyOffer = true
				local r = RANK[Catalog[o.species].rarity] or 1
				if options.lucky and (o.lucky or (lucky.pulls < 40 and r >= 3) or RebirthChickens.Wanted(s, o.species)) then protected = true end
			end
		end
		local patience = if protected then options.rollPatience * 2 else options.rollPatience
		if now >= nextPullAt and now >= s.rollReadyAt and (not anyOffer or (offerSince and now - offerSince >= patience)) then
			-- WS4 Lucky Start (podium 1), mirrors retention/ws4/discovery_probe.luau.
			local forced = nil
			if options.lucky and lucky.pulls < 40 then
				local k = lucky.pulls + 1
				local ownsR, ownsU = owns(3), owns(2)
				if not ownsR and lucky.firesR < 2 and k >= lucky.nextR then forced = "Rare"
				elseif not ownsU and lucky.firesU < 2 and k >= lucky.nextU then forced = "Uncommon" end
				if forced then s.debugNext = drawRarity(forced) end
			end
			if rolls:Roll(s, now) then
				stats.rolls += 1
				offerSince = s.rollRevealAt
				nextPullAt = s.rollRevealAt + options.pullGap
				if options.lucky and lucky.pulls < 40 then
					lucky.pulls += 1
					local k = lucky.pulls
					if forced == "Rare" then lucky.firesR += 1 elseif forced == "Uncommon" then lucky.firesU += 1 end
					for slot2, o in s.offers or {} do
						local r = RANK[Catalog[o.species].rarity] or 1
						if r >= 2 then lucky.nextU = math.max(lucky.nextU, k + 5) end
						if r >= 3 then lucky.nextR = math.max(lucky.nextR, k + 10) end
						if forced and slot2 == 1 then o.lucky = forced end
					end
				end
			else
				s.debugNext = nil
			end
		end
		-- Buy a wanted offer as soon as the Coins cover it (sell the bag first if that does it).
		if now >= s.rollRevealAt then
			for slot = 1, s.rollSlotCount or 1 do
				local offer = s.offers and s.offers[slot]
				if offer then
					local want, why = wantsChicken(offer)
					if want then
						if s.coins < offer.price and s.coins + s:EarnedAmount(bag * rushFactor(now), "eggs") >= offer.price then sell(now) end
						if s.coins >= offer.price then
							local ok = rolls:Buy(s, offer.id, now)
							if ok then
								stats.recruits += 1
								s.wsRecruits = (s.wsRecruits or 0) + 1
								s:RefreshArmy()
								record({kind = "chicken", name = offer.species, price = offer.price, why = why,
									rarity = Catalog[offer.species].rarity}, now)
								nextPullAt = math.min(nextPullAt, now + options.pullGap)
							end
						else
							stats.shortfalls += 0
						end
					end
				end
			end
		end
		-- WS1 readiness card: after Cluck Camp, until Fort Roost falls, the player follows the
		-- single best power-per-Coin step (Army Size / Get Feed / Feed); recruits come from the podium rule.
		cardSaving = nil
		if options.guided and campWins[1] and not campWins[2] and not away and now >= nextCardAt and armyPower(s) < options.fortPower then
			local best
			local function consider(kind, gain, price, act)
				if gain > 0 and price and (not best or gain / price > best.gain / best.price) then best = {kind = kind, gain = gain, price = price, act = act} end
			end
			local tier = nextTier(s, "ArmySize")
			if tier then
				local slots = Tree.Families.ArmySize.tiers[tier].value - Tree.Value(s.upgradeTree, "ArmySize")
				local inLineup = {}
				for _, e in s:Lineup() do inLineup[e.id] = true end
				local spare = {}
				for id, pet in s.pets do if not inLineup[id] then table.insert(spare, petPower(pet)) end end
				table.sort(spare, function(a, b) return a > b end)
				local gain, empty = 0, 0
				for i = 1, slots do if spare[i] then gain += spare[i] else gain += 13; empty += 1 end end
				local price = nodePrice(s, "ArmySize", tier)
				consider("ArmySize", gain, price + 150 * empty, function()
					if price <= s.coins then return buyNode("ArmySize", tier, "card") end
					return false
				end)
			end
			local feedOwned = (s.researchEffects.chickenFeed or 0) >= 1
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
				if feedOwned then
					consider("Feed", cheapest.g, cheapest.q, function()
						return Army.UpgradeChicken(s, cheapest.pet.id, cheapest.level, cheapest.q)
					end)
				else
					local fp = nodePrice(s, "ChickenFeed", 1)
					consider("GetFeed", cheapest.g, fp + cheapest.q, function()
						if fp <= s.coins then return buyNode("ChickenFeed", 1, "card") end
						return false
					end)
				end
			end
			if best then
				if best.price <= s.coins + s:EarnedAmount(bag * rushFactor(now), "eggs") then
					if s.coins < best.price then sell(now) end
					if best.act() then
						if best.kind == "Feed" then record({kind = "feed", name = "card", price = best.price}, now)
						else log[#log].t = now end
						nextCardAt = now + options.cardDelay
					end
				else
					cardSaving = best.price
				end
			end
		end
		-- Tree: before Rebirth 0 only Flock; after it, the cheapest useful node.
		if now >= (nextTreeAt or 0) and not cardSaving then
			local boughtAny = false
			for _ = 1, options.treePerVisit do
				local list = treeWish()
				local pick
				for _, item in list do
					if item.fam ~= "Flock" and Rebirth.IntroPending(s) then continue end
					if item.price <= s.coins then pick = item; break end
				end
				if not pick then break end
				if not buyNode(pick.fam, pick.tier) then break end
				log[#log].t = now
				boughtAny = true
			end
			if boughtAny or options.treeGap > 0 then nextTreeAt = now + options.treeGap end
		end
		-- Feed fighters while Fort Roost is out of reach.
		if options.feed and now >= options.feedAfter and not campWins[2] and not away then
			local f = feedTarget()
			if f and f.price <= s.coins * 0.5 then
				if Army.UpgradeChicken(s, f.pet.id, f.level, f.price) then
					record({kind = "feed", name = f.pet.species .. " Lv" .. (f.level + 1), price = f.price}, now)
				end
			end
		end
		-- Camps: Cluck Camp at 3 Army chickens; Fort Roost at fortPower.
		if not away and s.armyState == "Home" then
			local power = armyPower(s)
			local target
			if not campWins[1] and #s:Lineup() >= 3 then target = 1
			elseif campWins[1] and not campWins[2] and power >= options.fortPower then target = 2 end
			if target then
				s.armyState = "Marching"
				away = {index = target, untilAt = now + 90}
			end
		end
		sinceLastSample += dt
		if sinceLastSample >= 30 then
			sinceLastSample = 0
			local st0 = s.armyState; s.armyState = "Home"
			local homeRate = cashRate(s); s.armyState = st0
			table.insert(samples, {t = now, coins = s.coins, rate = homeRate, power = armyPower(s), chickens = count(s),
				flock = s:FlockSize(), cap = s:Capacity(), earned = stats.eggCash + stats.playtime + stats.daily + stats.battle})
		end
	end
	return {seed = seed, log = log, samples = samples, stats = stats, campWins = campWins}
end

local runs = {}
for seed = 1, options.seeds do table.insert(runs, runOnce(seed)) end

-- Report ----------------------------------------------------------------------------
local function median(xs)
	if #xs == 0 then return nil end
	table.sort(xs); return xs[math.ceil(#xs / 2)]
end
local function pct(xs, p)
	if #xs == 0 then return nil end
	table.sort(xs); return xs[math.clamp(math.ceil(#xs * p), 1, #xs)]
end
local function meaningful(e)
	if e.kind == "rebirth0" or e.kind == "rebirth1" then return true end
	if not (e.kind == "chicken" or e.kind == "tree" or e.kind == "feed" or e.kind == "card") then return false end
	local r0, r1, p0, p1 = e.rateBefore or 0, e.rateAfter or 0, e.powerBefore or 0, e.powerAfter or 0
	return (r0 > 0 and r1 >= r0 * (1 + (options.minGain or 0.05))) or (p0 > 0 and p1 >= p0 * (1 + (options.minGain or 0.05)))
		or (r0 == 0 and r1 > 0)
end
print(string.format("WS2 early model · seeds %d · discount %s (%s) · r0mult %s · tree %s · patience %ds pullGap %ds sell %ds eff %.2f",
	options.seeds, tostring(options.discount), tostring(options.discountEnd), tostring(Config.Rebirth.Intro.Multiplier), tostring(options.tree),
	options.rollPatience, options.pullGap, options.sellEvery, options.eff))
print(string.format("%5s %8s %8s %7s %6s %6s %5s %4s %8s", "min", "coins", "Coins/s", "earned", "power", "chick", "flock", "army", "buys"))
for minute = 2, options.minutes do
	local c, r, e, p, ch, fl, ar, b = {}, {}, {}, {}, {}, {}, {}, {}
	for _, run in runs do
		local last
		for _, smp in run.samples do if smp.t <= minute * 60 then last = smp end end
		if last then
			table.insert(c, last.coins); table.insert(r, last.rate); table.insert(e, last.earned); table.insert(p, last.power)
			table.insert(ch, last.chickens); table.insert(fl, last.flock); table.insert(ar, last.cap)
		end
		local n = 0
		for _, ev in run.log do if ev.t and ev.t <= minute * 60 and ev.t > options.tutorialAt and meaningful(ev) then n += 1 end end
		table.insert(b, n)
	end
	print(string.format("%5d %8.0f %8.1f %7.0f %6d %6d %5d %4d %8d", minute, median(c), median(r), median(e), median(p), median(ch), median(fl), median(ar), median(b)))
end
-- Gaps between meaningful purchases.
local function gaps(lo, hi)
	local all, longest, counts = {}, {}, {}
	for _, run in runs do
		local prev = lo
		local n, maxGap = 0, 0
		for _, ev in run.log do
			if ev.t and ev.t > lo and ev.t <= hi and meaningful(ev) then
				table.insert(all, ev.t - prev); maxGap = math.max(maxGap, ev.t - prev); prev = ev.t; n += 1
			end
		end
		maxGap = math.max(maxGap, hi - prev)
		table.insert(longest, maxGap); table.insert(counts, n)
	end
	return median(all), pct(all, 0.9), median(longest), median(counts)
end
for _, w in {{options.tutorialAt, 600, "tutorial-10 min"}, {600, 1200, "10-20 min"}} do
	local m, p90, lmax, n = gaps(w[1], w[2])
	print(string.format("%-16s purchases %s · gap median %ss p90 %ss · longest dry spell (median run) %ss", w[3], tostring(n), tostring(m and math.floor(m)), tostring(p90 and math.floor(p90)), tostring(lmax and math.floor(lmax))))
end
local function milestone(kind)
	local ts, reached = {}, 0
	for _, run in runs do
		for _, ev in run.log do if ev.kind == kind or ev.name == kind then table.insert(ts, ev.t / 60); reached += 1; break end end
	end
	return median(ts), reached
end
for _, k in {"rebirth0", "Camp1", "Camp2", "rebirth1", "ArmySize1", "ArmySize2", "Flock2", "Flock3", "Flock4", "RollSlot1", "EggSpeed2", "EggValue2", "ChickenFeed"} do
	local m, n = milestone(k)
	print(string.format("  %-10s median %s min (%d/%d)", k, if m then string.format("%.1f", m) else "never", n, #runs))
end
local rolls, recruits = {}, {}
local rare = {}
for _, run in runs do
	table.insert(rolls, run.stats.rolls); table.insert(recruits, run.stats.recruits)
	for _, ev in run.log do if ev.kind == "chicken" then rare[ev.rarity] = (rare[ev.rarity] or 0) + 1 end end
end
print(string.format("rolls median %d · recruits median %d · bought by rarity %s", median(rolls), median(recruits),
	(function() local parts = {} for k, v in rare do table.insert(parts, k .. "=" .. v) end table.sort(parts) return table.concat(parts, ",") end)()))
if options.verbose then
	for _, ev in runs[1].log do
		print(string.format("  %6.1f %-9s %-14s %8s %s", (ev.t or 0) / 60, ev.kind, ev.name, tostring(ev.price), tostring(ev.why or "")))
	end
end
if options.out then
	Harness.fs.writeFile(options.out, Harness.serde.encode("json", {options = options, runs = runs}))
end
-- Combined-package summary line (lead request).
do
	local wins = {}
	for _, run in runs do
		local t = math.huge
		for _, ev in run.log do if ev.name == "Camp2" then t = ev.t / 60; break end end
		table.insert(wins, t)
	end
	table.sort(wins)
	local function q(p) local v = wins[math.clamp(math.ceil(#wins * p), 1, #wins)]; return if v == math.huge then "never" else string.format("%.1f", v) end
	local reached = 0
	for _, v in wins do if v < math.huge then reached += 1 end end
	local function at(minute, field)
		local xs = {}
		for _, run in runs do
			local last
			for _, smp in run.samples do if smp.t <= minute * 60 then last = smp end end
			if last then table.insert(xs, last[field]) end
		end
		return median(xs)
	end
	local m = gaps(options.tutorialAt, 600)
	print(string.format("SUMMARY fortGoal=%d fortWin p50=%s p90=%s (%d/%d) rate5=%.1f rate10=%.1f power5=%d power10=%d gapEarly=%ss",
		options.fortPower, q(0.5), q(0.9), reached, #wins, at(5, "rate"), at(10, "rate"), at(5, "power"), at(10, "power"), tostring(m and math.floor(m))))
end
