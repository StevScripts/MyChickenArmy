-- October 27 camp ladder probe (WS1 of the retention package; docs/team/CAMP_LADDER_20261027.md).
--
--   lune run harness.luau ../.. camp_probe.luau mode=fights [camp=2] [seeds=12] [strength=0.6]
--     Real Battle.luau fights at the camp's map radius (no actors), the garrison scaled the
--     way BattleService does (hp and damage x strength x Rebirth scale). One row per Army,
--     with its power, ratio and win share. strength= overrides Config.CampLadder for the camp.
--
--   lune run harness.luau ../.. camp_probe.luau mode=early [seeds=300] [pull=45] [collect=0.6]
--       [policy=guided|unguided] [strength=0.6]
--     A data-calibrated early-player model (minutes 1.5-30 after the tutorial), not
--     ProgressionSimulation: income from the best Flock layers (Rules.Income) times a
--     collection efficiency, a lever pull every `pull` seconds with the zero-Luck odds and
--     Config.Economy.FavoredRolls, podium prices through Rules.StarterPrice, Army Size and
--     Chicken Feed from UpgradeCatalog. "guided" buys exactly what CampGuide.Advice names
--     (the readiness card); "unguided" buys chickens and the first economy hexes, never Army
--     Size (the live behaviour before October 27). Prints when the Army first reads Should
--     win at Fort Roost (CampGuide.Goal): p25 / p50 / p90 minutes. Add ~1.5 min for the march
--     and fight to read it as the first win.
local Config = Harness.require(Harness.Shared.Config)
local Rules = Harness.require(Harness.Shared.Rules)
local Catalog = Harness.require(Harness.Shared.PetCatalog)
local Tree = Harness.require(Harness.Shared.UpgradeCatalog)
local Progression = Harness.require(Harness.Shared.Progression)
local CampGuide = Harness.require(Harness.Shared.CampGuide)
local MapLayout = Harness.require(Harness.Shared.MapLayout)
local March = Harness.require(Harness.Shared.ArmyMarch)
local Battle = Harness.require(Harness.Server.Battle)

local args = {}
for _, a in ARGS do
	local k, v = string.match(a, "^(%w+)=(.+)$")
	if k then args[k] = v end
end
local MODE = args.mode or "fights"
local CAMP = tonumber(args.camp or "2") :: number
local STRENGTH = tonumber(args.strength or "") or Progression.Strength(CAMP)

-- Fights -------------------------------------------------------------------------------

local function campFrame(index: number): CFrame
	local home = MapLayout.HomeFrame(1).Position
	local outward = Vector3.new(home.X, 0, home.Z).Unit
	local p = outward * Config.CampRadii[index] + Vector3.new(0, 1.05, 0)
	return CFrame.lookAt(p, Vector3.new(0, p.Y, 0))
end

-- BattleService.scaledRoster: hp and damage times the scale.
local function scaledGuards(index: number, scale: number)
	local out = {}
	for i, pet in Progression.Roster(1, index) do
		local unit = table.clone(pet)
		local stats = table.clone(Rules.Stats(pet.species, 1, pet.level))
		stats.hp *= scale; stats.damage *= scale
		unit.combatStats = stats
		out[i] = unit
	end
	return out
end

local function fight(army, guards, index: number, seed: number): string
	math.randomseed(seed)
	local frame = campFrame(index)
	local home = MapLayout.HomeFrame(1).Position
	local b = Battle.new("probe" .. seed, 1, "camp:" .. index, home, frame.Position, 0)
	b.frame, b.campIndex, b.holdRandom = frame, index, Random.new(seed)
	local roster = {}
	for i, e in army do table.insert(roster, {id = "p" .. i, species = e[1], stars = 1, level = e[2] or 1, slot = i}) end
	b:AddArmy("A", roster, home)
	b:AddArmy("B", guards, frame.Position)
	for _, u in b.units do if u.side == "A" then March.Approach(u, b.destination, 0, nil) end end
	for step = 1, 4000 do
		local outcome = b:Step(0.1, step * 0.1)
		if outcome then return outcome end
	end
	return "Timeout"
end

local function rep(species: string, level: number, n: number)
	local t = {}
	for _ = 1, n do table.insert(t, {species, level}) end
	return t
end
local function cat(...)
	local t = {}
	for _, list in {...} do for _, e in list do table.insert(t, e) end end
	return t
end

if MODE == "fights" then
	local seeds = tonumber(args.seeds or "12") :: number
	local guards = scaledGuards(CAMP, STRENGTH)
	local enemy = Progression.ScaledPower(Progression.Roster(1, CAMP), STRENGTH)
	print(string.format("%s x%.2f: power %d, Should win at %d (%d seeds a row)", CampGuide.CampName(CAMP), STRENGTH,
		enemy, CampGuide.Goal(enemy), seeds))
	local armies = {
		{"3 Chickens", rep("Duck", 1, 3)},
		{"Chicken + 2 Commons", cat(rep("Duck", 1, 1), rep("Noob", 1, 1), rep("Penguin", 1, 1))},
		{"3 Commons", rep("Penguin", 1, 3)},
		{"4 Chickens", rep("Duck", 1, 4)},
		{"2 Chickens + 2 Commons", cat(rep("Duck", 1, 2), rep("Noob", 1, 1), rep("Penguin", 1, 1))},
		{"4 Chickens L2", rep("Duck", 2, 4)},
		{"3 Commons + Uncommon", cat(rep("Penguin", 1, 3), rep("Chunky", 1, 1))},
		{"4 Commons", rep("Penguin", 1, 4)},
		{"3 Chickens + 2 Commons", cat(rep("Duck", 1, 3), rep("Noob", 1, 1), rep("Penguin", 1, 1))},
		{"4 Chickens L3", rep("Duck", 3, 4)},
		{"6 Chickens", rep("Duck", 1, 6)},
		{"4 Uncommons", rep("Chunky", 1, 4)},
		{"6 Commons L2", rep("Penguin", 2, 6)},
		{"5 Uncommons L2", rep("Chunky", 2, 5)},
	}
	for _, row in armies do
		local list = {}
		for _, e in row[2] do table.insert(list, {species = e[1], stars = 1, level = e[2]}) end
		local power = Rules.Power(list)
		local wins = 0
		for seed = 1, seeds do if fight(row[2], guards, CAMP, seed * 7919) == "A" then wins += 1 end end
		print(string.format("%-24s power %4d  ratio %.2f  %-11s win %3d%%", row[1], power, power / math.max(1, enemy),
			CampGuide.Difficulty(power, enemy), math.floor(wins / seeds * 100 + 0.5)))
	end
	return
end

-- Early model --------------------------------------------------------------------------

local SEEDS = tonumber(args.seeds or "300") :: number
local PULL = tonumber(args.pull or "45") :: number
local COLLECT = tonumber(args.collect or "0.6") :: number
local GUIDED = (args.policy or "guided") ~= "unguided"
local enemy = Progression.ScaledPower(Progression.Roster(1, 2), STRENGTH)
local goal = CampGuide.Goal(enemy)
local favored = Config.Economy.FavoredRolls or {rolls = 0, chance = 0, species = "Duck"}

local odds = Rules.Odds(0)
local ids = {}
for id, p in odds do if p > 0 then table.insert(ids, id) end end
table.sort(ids)
local function lcg(seed: number)
	local state = math.max(1, seed % 2147483647)
	return function(): number
		state = state * 48271 % 2147483647
		return (state - 1) / 2147483646
	end
end
local function draw(rand): string
	local x, c = rand(), 0
	for _, id in ids do
		c += odds[id]
		if x < c then return id end
	end
	return "Duck"
end
local function pp(p): number return Rules.PetPower(p.species, 1, p.level) end
local function inc(p): number return Rules.Income(p.species, 1, p.level, 0) end
local armyTiers = Tree.Families.ArmySize.tiers
local feedPrice = Tree.Families.ChickenFeed.tiers[1].price
local speedTiers, valueTiers = Tree.Families.EggSpeed.tiers, Tree.Families.EggValue.tiers

local function run(seed: number)
	local rand = lcg(seed * 7919)
	local s = {t = 90, coins = 0, pets = {{species = "Duck", level = 1}, {species = "Duck", level = 1}},
		cap = Config.StartingSlots, armyTier = 0, flock = 4, feed = false, favored = favored.rolls or 0,
		nextPull = 90 + PULL, offer = nil :: any, speed = 1, value = 1, speedTier = 0, valueTier = 0, readyAt = nil :: number?}
	local function lineup()
		local list = table.clone(s.pets)
		table.sort(list, function(a, b) return pp(a) > pp(b) end)
		local chosen = {}
		for i = 1, math.min(s.cap, #list) do chosen[list[i]] = true end
		return chosen
	end
	local function rate(): number
		local list = table.clone(s.pets)
		table.sort(list, function(a, b) return inc(a) > inc(b) end)
		local r = 0
		for i = 1, math.min(s.flock, #list) do r += inc(list[i]) end
		return r * s.speed * s.value * COLLECT
	end
	-- The snapshot fields CampGuide.Advice reads.
	local function snapshot()
		local chosen = lineup()
		local pets, power = {}, 0
		for i, p in s.pets do
			local selected = chosen[p] == true
			if selected then power += pp(p) end
			table.insert(pets, {id = "p" .. i, species = p.species, stars = 1, level = p.level, selected = selected,
				canUpgrade = s.feed and p.level < 10, upgradePrice = Rules.ChickenUpgradePrice(p.species, p.level), ref = p})
		end
		local offer = nil
		if s.offer then
			local free = #s.pets < s.cap
			local weakest = math.huge
			for _, p in pets do if p.selected then weakest = math.min(weakest, pp(p)) end end
			offer = {slot = 1, species = s.offer.species, level = 1, price = s.offer.price,
				improvesArmy = free or Rules.PetPower(s.offer.species, 1, 1) > weakest}
		end
		local next = armyTiers[s.armyTier + 1]
		return {coins = s.coins, capacity = s.cap, baseCapacity = s.cap, selectionMode = "Auto", pets = pets,
			power = math.floor(power), offer = offer, offers = {offer}, effects = {chickenFeed = if s.feed then 1 else 0},
			nextSlot = if next then {capacity = next.value, price = next.price, tier = s.armyTier + 1} else nil,
			upgradeTree = {nodes = {ChickenFeed = {status = if s.feed then "Owned" else "Available", price = feedPrice}}}}
	end
	local function buyOffer(): boolean
		if s.offer and s.coins >= s.offer.price then
			s.coins -= s.offer.price
			table.insert(s.pets, {species = s.offer.species, level = 1})
			s.offer = nil
			return true
		end
		return false
	end
	while s.t < 1800 do
		local dt = 5
		s.coins += rate() * dt
		s.t += dt
		if s.t >= s.nextPull then
			s.nextPull += PULL
			local id = if s.favored > 0 and rand() < (favored.chance or 0) then favored.species or "Duck" else draw(rand)
			if s.favored > 0 then s.favored -= 1 end
			s.offer = {species = id, price = Rules.StarterPrice(Catalog[id].price, #s.pets)}
		end
		local state = snapshot()
		if not s.readyAt and state.power >= goal then s.readyAt = s.t; break end
		if GUIDED then
			local advice = CampGuide.Advice(state, goal)
			if s.coins >= advice.buyPrice then
				if advice.kind == "ArmySize" then
					s.coins -= advice.buyPrice; s.armyTier += 1; s.cap = armyTiers[s.armyTier].value
				elseif advice.kind == "Recruit" then buyOffer()
				elseif advice.kind == "GetFeed" then s.coins -= feedPrice; s.feed = true
				elseif advice.kind == "Feed" then
					-- The best power per Coin among the Army (the card leaves the pick to the player).
					local best, bestValue = nil, -1
					for _, p in state.pets do
						if p.selected and p.canUpgrade and p.upgradePrice then
							local value = (Rules.PetPower(p.species, 1, p.level + 1) - pp(p)) / p.upgradePrice
							if value > bestValue then best, bestValue = p, value end
						end
					end
					if best and s.coins >= best.upgradePrice then s.coins -= best.upgradePrice; best.ref.level += 1 end
				end
			end
		else
			if s.offer and #s.pets < 12 then buyOffer() end
			if s.speedTier < 2 and s.coins >= speedTiers[s.speedTier + 1].price + 200 then
				s.coins -= speedTiers[s.speedTier + 1].price; s.speedTier += 1; s.speed = speedTiers[s.speedTier].value
			end
			if s.valueTier < 2 and s.coins >= valueTiers[s.valueTier + 1].price + 200 then
				s.coins -= valueTiers[s.valueTier + 1].price; s.valueTier += 1; s.value = valueTiers[s.valueTier].value
			end
		end
	end
	return s
end

local ready = {}
for seed = 1, SEEDS do table.insert(ready, run(seed).readyAt or math.huge) end
table.sort(ready)
local function q(f: number): string
	local v = ready[math.max(1, math.ceil(#ready * f))]
	return if v == math.huge then ">30" else string.format("%.1f", v / 60)
end
local by10, by15 = 0, 0
for _, v in ready do
	if v <= 600 then by10 += 1 end
	if v <= 900 then by15 += 1 end
end
print(string.format("Fort Roost x%.2f = %d, Should win at %d | %s, pull %ds, collect %.2f, %d seeds",
	STRENGTH, enemy, goal, if GUIDED then "guided (CampGuide.Advice)" else "unguided", PULL, COLLECT, SEEDS))
print(string.format("ready (min): p25 %s  p50 %s  p90 %s | by 10 min %d%%, by 15 min %d%%",
	q(0.25), q(0.5), q(0.9), math.floor(by10 / SEEDS * 100), math.floor(by15 / SEEDS * 100)))
