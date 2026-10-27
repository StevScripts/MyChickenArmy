-- WS1 scratch: a data-calibrated early-player model (minutes 1.5-30), not ProgressionSimulation.
local Catalog = Harness.require(Harness.Shared.PetCatalog)
local Rules = Harness.require(Harness.Shared.Rules)
local Tree = Harness.require(Harness.Shared.UpgradeCatalog)

local FR_BASE = 106.7
local args = {}
for _, a in ARGS do local k, v = string.match(a, "^(%w+)=(.+)$"); if k then args[k] = v end end
local STRENGTH = tonumber(args.strength or "1")
local POLICY = args.policy or "A"
local SEEDS = tonumber(args.seeds or "300")
local PULL = tonumber(args.pull or "45")
local COLLECT = tonumber(args.collect or "0.85")
local READY = tonumber(args.ready or "1.25")
local REBIRTH0 = args.rebirth0 == "1"
local goalPower = FR_BASE * STRENGTH

local odds = Rules.Odds(0)
local function lcg(seed)
	local state = math.max(1, seed % 2147483647)
	return function() state = state * 48271 % 2147483647; return (state - 1) / 2147483646 end
end
local function draw(rand)
	local x, c = rand(), 0
	for _, id in Catalog.Order do c += odds[id] or 0; if x < c then return id end end
	return "Duck"
end
local function pp(p) return Rules.PetPower(p.species, 1, p.level) end
local function inc(p) return Rules.Income(p.species, 1, p.level, 0) end

local function run(seed)
	local rand = lcg(seed * 7919)
	local s = {t = 90, coins = 0, earned = 0, pets = {{species="Duck",level=1},{species="Duck",level=1}},
		cap = 3, armyTier = 0, flock = 4, flockTier = 1, speed = 1, value = 1, speedTier = 0, valueTier = 0,
		feed = false, favored = 5, nextPull = 90 + PULL, offer = nil, rebirth0 = false, readyAt = nil}
	local function lineup()
		local list = table.clone(s.pets)
		table.sort(list, function(a, b) return pp(a) > pp(b) end)
		local out, power = {}, 0
		for i = 1, math.min(s.cap, #list) do out[i] = list[i]; power += pp(list[i]) end
		return out, math.floor(power), list
	end
	local function rate()
		local list = table.clone(s.pets)
		table.sort(list, function(a, b) return inc(a) > inc(b) end)
		local r = 0
		for i = 1, math.min(s.flock, #list) do r += inc(list[i]) end
		return r * s.speed * s.value * COLLECT * (if s.rebirth0 then 1.5 else 1)
	end
	local function buyOffer()
		if s.offer and s.coins >= s.offer.price then
			s.coins -= s.offer.price
			table.insert(s.pets, {species = s.offer.species, level = 1})
			s.offer = nil
			return true
		end
		return false
	end
	local speedTiers = Tree.Families.EggSpeed.tiers
	local valueTiers = Tree.Families.EggValue.tiers
	local flockTiers = Tree.Families.Flock.tiers
	local armyTiers = Tree.Families.ArmySize.tiers
	-- Advice: best power per Coin toward the goal (mirrors the planned CampReadiness.Advice).
	local function advice()
		local line, power, all = lineup()
		local weakest = if #line >= s.cap then pp(line[#line]) else 0
		local best, bestRatio = nil, -1
		local function consider(kind, price, gain, act)
			if gain <= 0 then return end
			local ratio = gain / math.max(price, 1)
			if ratio > bestRatio then best, bestRatio = {kind = kind, price = price, act = act}, ratio end
		end
		local nextArmy = armyTiers[s.armyTier + 1]
		if nextArmy then
			local slots = nextArmy.value - s.cap
			local gain, extra = 0, 0
			for i = s.cap + 1, math.min(#all, s.cap + slots) do gain += pp(all[i]) end
			if gain == 0 then gain, extra = 13, 150 end -- a 4th basic Chicken from the lever
			consider("ArmySize", nextArmy.price + extra, gain, function()
				s.coins -= nextArmy.price; s.armyTier += 1; s.cap = nextArmy.value end)
		end
		if s.offer then
			local gain = pp({species = s.offer.species, level = 1}) - weakest
			consider("Recruit", s.offer.price, gain, buyOffer)
		end
		for _, p in line do
			local price = Rules.ChickenUpgradePrice(p.species, p.level)
			if price and p.level < 10 then
				local gain = Rules.PetPower(p.species, 1, p.level + 1) - pp(p)
				local total = price + (if s.feed then 0 else Tree.Families.ChickenFeed.tiers[1].price)
				consider("Feed", total, gain, function()
					if not s.feed then s.coins -= Tree.Families.ChickenFeed.tiers[1].price; s.feed = true end
					s.coins -= price; p.level += 1 end)
			end
		end
		return best
	end
	while s.t < 1800 do
		local dt = 5
		local r = rate()
		s.coins += r * dt; s.earned += r * dt; s.t += dt
		if s.t >= s.nextPull then
			s.nextPull += PULL
			if s.favored > 0 and rand() < 0.6 then s.offer = {species = "Duck", price = 150}
			else local id = draw(rand); s.offer = {species = id, price = Catalog[id].price} end
			if s.favored > 0 then s.favored -= 1 end
		end
		local _, power = lineup()
		if not s.readyAt and power >= goalPower * READY then s.readyAt = s.t end
		if s.readyAt and s.t > s.readyAt + 300 then break end
		if REBIRTH0 and not s.rebirth0 and s.coins >= 1700 then
			s.rebirth0 = true; s.coins = 0; s.cap, s.armyTier = 3, 0; s.flock, s.flockTier = 3, 0
			s.speed, s.speedTier, s.value, s.valueTier, s.feed = 1, 0, 1, 0, false
		end
		if POLICY == "B" and not s.readyAt then
			local a = advice()
			if a and s.coins >= a.price then a.act() end
			-- cheap economy only when it doesn't delay the step much
			if s.flockTier < 1 and s.coins >= 10 then s.coins -= 10; s.flockTier = 1; s.flock = 4 end
		else
			-- data-like: chickens first (when affordable), then the first upgrades
			if s.offer and #s.pets < 12 and s.coins >= s.offer.price then buyOffer() end
			if s.flockTier < 1 and s.coins >= 10 then s.coins -= 10; s.flockTier = 1; s.flock = 4 end
			if s.speedTier < 2 and s.coins >= speedTiers[s.speedTier + 1].price + 200 then
				s.coins -= speedTiers[s.speedTier + 1].price; s.speedTier += 1; s.speed = speedTiers[s.speedTier].value end
			if s.valueTier < 2 and s.coins >= valueTiers[s.valueTier + 1].price + 200 then
				s.coins -= valueTiers[s.valueTier + 1].price; s.valueTier += 1; s.value = valueTiers[s.valueTier].value end
			if s.flockTier < 3 and #s.pets > s.flock and s.coins >= flockTiers[s.flockTier + 1].price then
				s.coins -= flockTiers[s.flockTier + 1].price; s.flockTier += 1; s.flock = flockTiers[s.flockTier].value end
		end
		s["e" .. math.floor(s.t / 60)] = s["e" .. math.floor(s.t / 60)] or {earned = s.earned, pets = #s.pets, power = power}
	end
	return s
end

local ready, e6, e10, e15, p6, p10 = {}, {}, {}, {}, {}, {}
for seed = 1, SEEDS do
	local s = run(seed)
	table.insert(ready, s.readyAt or 99999)
	if s.e6 then table.insert(e6, s.e6.earned); table.insert(p6, s.e6.power) end
	if s.e10 then table.insert(e10, s.e10.earned); table.insert(p10, s.e10.power) end
	if s.e15 then table.insert(e15, s.e15.earned) end
end
local function q(t, f) table.sort(t); return t[math.max(1, math.ceil(#t * f))] end
local function m(x) return if x >= 99999 then ">30" else string.format("%.1f", x / 60) end
print(string.format("strength %.2f goal %.0f (ready %.0f) policy %s rebirth0 %s | ready min p25 %s p50 %s p75 %s p90 %s | ready<=10m %d%% <=15m %d%%",
	STRENGTH, goalPower, goalPower * READY, POLICY, tostring(REBIRTH0), m(q(ready, .25)), m(q(ready, .5)), m(q(ready, .75)), m(q(ready, .9)),
	(function() local n = 0 for _, v in ready do if v <= 600 then n += 1 end end return math.floor(n / #ready * 100) end)(),
	(function() local n = 0 for _, v in ready do if v <= 900 then n += 1 end end return math.floor(n / #ready * 100) end)()))
print(string.format("   earned@6m %.0f @10m %.0f @15m %s | power@6m %d @10m %d", q(e6, .5), q(e10, .5), tostring(e15[1] and math.floor(q(e15, .5))), q(p6, .5), q(p10, .5)))
