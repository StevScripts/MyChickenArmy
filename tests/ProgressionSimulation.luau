--!strict
-- Isolated design experiment. Uses the real economy/session/battle modules and
-- a deterministic policy, not live player input or a claim about retention.
local Server = game:GetService("ServerStorage").PetRoll
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.PetCatalog)
local Rules = require(Shared.Rules)
local Session = require(Server.PlayerSession)
local Army = require(Server.ArmyService)
local Rolls = require(Server.RollService)
local Battles = require(Server.BattleService)
local Simulation = {}

local function rng(seed)
	local state = math.max(1, seed % 2147483647)
	return {NextNumber = function()
		state = state * 48271 % 2147483647
		return (state - 1) / 2147483646
	end}
end

local function countWins(session)
	local count = 0
	for _, won in session.firstWins do if won then count += 1 end end
	return count
end

local function homeIncome(session)
	local income = 0
	for _, pet in session.pets do income += Rules.Stats(pet.species, 1).income end
	return income * (1 + session.incomeLevel * Config.IncomeMultiplierPerLevel)
end

local function weakest(session, squadOnly)
	local selected, power = nil, math.huge
	for id, pet in session.pets do
		if squadOnly and not session:FindSlot(id) then continue end
		local value = Rules.PetPower(pet.species, 1)
		if value < power then selected, power = pet, value end
	end
	return selected, power
end

local function upgrade(session, rolls, policy)
	local count = session:Count()
	local capPrice = Config.SlotPrices[session.capacity]
	local incomePrice = Config.IncomePrices[session.incomeLevel + 1]
	local luckPrice = Config.LuckPrices[session.luck + 1]
	local rate = homeIncome(session)
	local incomePayback = if incomePrice then incomePrice / math.max(rate / (1 + session.incomeLevel * Config.IncomeMultiplierPerLevel) * Config.IncomeMultiplierPerLevel, 0.01) else math.huge
	-- Buying upgrades requires a small cash buffer so these policies can still buy offers.
	local function capacity()
		if capPrice and count >= session.capacity + 3 and session.coins >= capPrice + 260 then return Army.Expand(session) end
		return false
	end
	local function income()
		local threshold = if policy == "income" then 420 else 240
		if incomePrice and count >= 8 and incomePayback <= threshold and session.coins >= incomePrice + 120 then return Army.UpgradeIncome(session) end
		return false
	end
	local function luck()
		local targetLevel = if countWins(session) < 2 then 1 elseif countWins(session) < 4 then 2 else 4
		if luckPrice and count >= 12 and session.luck < targetLevel and session.coins >= luckPrice + 600 then return rolls:UpgradeLuck(session) end
		return false
	end
	if policy == "income" then if income() or capacity() or luck() then return end
	else if capacity() or income() or luck() then return end end
end

local function wants(session, species, policy)
	if policy == "everything" then return true end
	local _, weakPower = weakest(session, true)
	local improves = Rules.PetPower(species, 1) > weakPower * 1.03
	if session:Count() < session.capacity then return true end
	if improves then return true end
	local producerTarget = if policy == "income" then 48 else 28
	-- Ordinary duplicates remain useful producers, but leave cash for stronger offers.
	return session:Count() < producerTarget and Catalog[species].price <= session.coins * 0.45
end

local function purchase(session, rolls, now, policy, stats)
	if not session.offer or now < session.rollRevealAt then return end
	local species = session.offer.species
	if not wants(session, species, policy) or session.coins < Catalog[species].price then return end
	if session:Count() >= Config.CollectionLimit then
		stats.capBlocked += 1
		if policy == "everything" or session:IsArmyLocked() then return end
		local weak = weakest(session, false)
		if not weak or Rules.PetPower(species, 1) <= Rules.PetPower(weak.species, 1) * 1.3 then return end
		local ok = Army.Sell(session, {weak.id})
		if not ok then return end
		stats.sold += 1
	end
	local ok = rolls:Buy(session, session.offer.id, now)
	if ok then
		stats.purchases += 1
		if species == "Dragon" then stats.dragons += 1 end
	end
end

local function oneRun(seed, policy, seconds)
	local random = rng(seed)
	local session = Session.new(seed, "Simulation", 1)
	local rolls = Rolls.new()
	rolls.random = random
	local world = {}
	function world:Position(_index) return Vector3.new(0, 1, -210) end
	function world:SetCampBusy(_index, _busy) end
	local battles = Battles.new({[seed] = session}, world)
	local stats = {seed = seed, policy = policy, campTimes = {}, purchases = 0, rolls = 0,
		attacks = 0, defeats = 0, capBlocked = 0, sold = 0, dragons = 0, awaySeconds = 0,
		capacityTimes = {}, incomeTimes = {}, luckTimes = {}}
	local nextRoll, nextCollect, sweepUntil, nextAttack = 4, 18 + random:NextNumber() * 10, 0, 35
	local activeBattle, previousCapacity, previousIncome, previousLuck = nil, session.capacity, 0, 0
	local horizon = math.floor(seconds / Config.BattleStep)
	local firstBuy = false
	for tick = 1, horizon do
		local now = tick * Config.BattleStep
		battles:Step(Config.BattleStep, now)
		if session.armyState ~= "Home" then stats.awaySeconds += Config.BattleStep end
		local battle = battles.battles[session.outgoing]
		if battle and battle.phase == "Holding" and now - battle.phaseAt >= 1.5 then
			battles:ReturnHome(session, now)
		end
		if battle and battle.paid and activeBattle ~= battle.id then
			activeBattle = battle.id
			if battle.outcome == "B" or battle.outcome == "Draw" then stats.defeats += 1 end
		end
		for i = 1, #Config.Camps do
			if session.firstWins[i] and not stats.campTimes[i] then
				stats.campTimes[i] = now
				if i == #Config.Camps then
					stats.finishState = {count = session:Count(), capacity = session.capacity, income = session.incomeLevel,
						luck = session.luck, dragons = stats.dragons, coins = session.coins, power = Rules.Power(session:Lineup())}
				end
			end
		end
		-- Economy accrues once per simulated second just as the server does.
		if tick % math.floor(1 / Config.BattleStep + 0.5) ~= 0 then continue end
		session:AccrueIncome(1)
		if not firstBuy and now < 2 then continue end
		if not firstBuy and now >= 2 then
			assert(rolls:Buy(session, session.offer.id, now)); firstBuy = true; stats.purchases += 1
		end
		if now >= nextCollect then
			-- A sweep takes 4–10 seconds; no lever use while walking around the yard.
			sweepUntil = now + 4 + math.min(6, #session:HomePets() * 0.12)
			nextCollect = now + 18 + random:NextNumber() * 10
			for _, pet in session:HomePets() do session:CollectPet(pet.id) end
		end
		if now >= sweepUntil then
			upgrade(session, rolls, policy)
			purchase(session, rolls, now, policy, stats)
			if now >= nextRoll then
				local hold = false
				if policy ~= "everything" and session.offer and wants(session, session.offer.species, policy) then
					local wait = (Catalog[session.offer.species].price - session.coins) / math.max(session:Income(), 0.01)
					hold = wait > 0 and wait < 12
				end
				if not hold and rolls:Roll(session, now) then stats.rolls += 1; nextRoll = now + Config.RollCooldown end
			end
		end
		if session.capacity ~= previousCapacity then stats.capacityTimes[session.capacity] = now; previousCapacity = session.capacity end
		if session.incomeLevel ~= previousIncome then stats.incomeTimes[session.incomeLevel] = now; previousIncome = session.incomeLevel end
		if session.luck ~= previousLuck then stats.luckTimes[session.luck] = now; previousLuck = session.luck end
		if session:Count() == Config.CollectionLimit and not stats.capTime then stats.capTime = now end
		if now >= nextAttack and session.armyState == "Home" then
			local power = Rules.Power(session:Lineup())
			local target = session.campUnlocked
			local roster = {}
			for _, species in Config.Camps[target].roster do table.insert(roster, {species = species, stars = 1}) end
			if power < Rules.Power(roster) * 1.12 then target = math.max(1, target - 1) end
			local ok = battles:Attack(session, "camp:" .. target, now)
			if ok then stats.attacks += 1; nextAttack = now + (if session.firstWins[target] then 85 else 45) end
		end
	end
	stats.coins, stats.count, stats.capacity, stats.incomeLevel, stats.luck = session.coins, session:Count(), session.capacity, session.incomeLevel, session.luck
	stats.power, stats.homeIncome = Rules.Power(session:Lineup()), homeIncome(session)
	stats.passiveEarned, stats.battleEarned = session.passiveEarned, session.battleEarned
	stats.complete = stats.campTimes[#Config.Camps] ~= nil
	stats.finalWithoutDragon = stats.complete and stats.finishState.dragons == 0
	assert(stats.count <= Config.CollectionLimit and #session:Lineup() <= Config.MaxSlots)
	battles:Destroy()
	return stats
end

local function quantile(values, percentile)
	if #values == 0 then return nil end
	table.sort(values)
	return values[math.clamp(math.ceil(#values * percentile), 1, #values)]
end

function Simulation.Run(options)
	options = options or {}
	local seeds, seconds = options.seeds or 30, options.seconds or 1800
	local reports = {}
	for _, policy in options.policies or {"everything", "balanced", "income"} do
		local runs = {}
		for seed = 1, seeds do table.insert(runs, oneRun(seed * 7919, policy, seconds)) end
		local summary = {policy = policy, runs = seeds, horizon = seconds, completed = 0, withoutDragon = 0, reachedCap = 0,
			campTimes = {}, levels = {}, purchases = {}, sold = {}, capTimes = {}, awaySeconds = {}, defeats = {}, upgrades = {}}
		for _, run in runs do
			if run.complete then summary.completed += 1 end
			if run.finalWithoutDragon then summary.withoutDragon += 1 end
			if run.capTime then summary.reachedCap += 1; table.insert(summary.capTimes, run.capTime) end
			for index, at in run.campTimes do summary.campTimes[index] = summary.campTimes[index] or {}; table.insert(summary.campTimes[index], at) end
			table.insert(summary.purchases, run.purchases); table.insert(summary.sold, run.sold); table.insert(summary.awaySeconds, run.awaySeconds); table.insert(summary.defeats, run.defeats)
		end
		for index = 1, #Config.Camps do
			local times = summary.campTimes[index] or {}
			summary.campTimes[index] = {reached = #times, p10 = quantile(table.clone(times), .1), median = quantile(table.clone(times), .5), p90 = quantile(table.clone(times), .9)}
		end
		for _, key in {"capacity", "incomeLevel", "luck", "count", "power", "homeIncome", "passiveEarned", "battleEarned", "coins"} do
			local values = {}; for _, run in runs do table.insert(values, run[key]) end
			summary.levels[key] = {min = quantile(table.clone(values), 0), median = quantile(table.clone(values), .5), max = quantile(table.clone(values), 1)}
		end
		for _, key in {"purchases", "sold", "capTimes", "awaySeconds", "defeats"} do
			local values = summary[key]
			summary[key] = {median = quantile(table.clone(values), .5), p90 = quantile(table.clone(values), .9)}
		end
		for _, kind in {"capacityTimes", "incomeTimes", "luckTimes"} do
			local steps = {}
			for _, run in runs do for level, at in run[kind] do steps[level] = steps[level] or {}; table.insert(steps[level], at) end end
			summary.upgrades[kind] = {}
			for level, times in steps do summary.upgrades[kind][tostring(level)] = {reached = #times, median = quantile(times, .5)} end
		end
		table.insert(reports, {summary = summary, runs = runs})
	end
	return {assumptions = "Actual production modules; 1s income, 0.1s battle steps; free roll every 4s; cash sweeps every 18–28s with 4–10s input interruption; auto-best, home-only income, safe defeat, manual recall after 1.5s. No PvP/contention/real walking/mistakes; approximate deliberate policies, not empirical playtime.",
		configuration = {config = Config, catalog = Catalog}, reports = reports}
end

return Simulation
