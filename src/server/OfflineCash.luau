--!strict
-- Offline cash calculation only. DataService owns the durable award boundary.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Rules = require(Shared.Rules)
local Tuning = require(Shared.OfflineCashConfig)
local Currency = require(Shared.CurrencyLimits)
local Processor = require(script.Parent.EggProcessor)
local ProcessorConfig = require(Shared.EggProcessorConfig)
local MutationCatalog = require(Shared.MutationCatalog)
local OfflineCash = {}

-- October 20 Offline Coins Gem Upgrade (effect offlineEfficiency), added to the base.
local function gemBonus(session): number
	local bonus = session.researchEffects and session.researchEffects.offlineEfficiency
	if type(bonus) ~= "number" or bonus ~= bonus or bonus <= 0 then return 0 end
	return math.min(bonus, 1 - Tuning.Efficiency)
end

function OfflineCash.Read(value)
	if value == nil then return {at = 0, rate = 0, maxSeconds=Tuning.MaxSeconds} end
	local function finite(n, maximum)
		return type(n) == "number" and n == n and n >= 0 and n <= maximum
	end
	if type(value) ~= "table" or not finite(value.at, 2^53 - 1) or value.at % 1 ~= 0
		or not finite(value.rate, Currency.MaxCoins) then return nil end
	local maximum=value.maxSeconds or Tuning.MaxSeconds
	if not finite(maximum,12*3600) or maximum<Tuning.MaxSeconds or maximum%1~=0 then return nil end
	-- Older checkpoints have no efficiency (recorded at LegacyEfficiency). An odd
	-- value is treated as legacy rather than failing the load.
	local efficiency = if finite(value.efficiency, 1) and value.efficiency > 0 then value.efficiency else nil
	-- October 20: the Offline Coins share of that efficiency; anything odd reads as none.
	local bonus = if efficiency and finite(value.bonus, efficiency) then value.bonus else nil
	return {at = value.at, rate = value.rate, maxSeconds=maximum, efficiency = efficiency, bonus = bonus}
end

function OfflineCash.Rate(session)
	-- October 20: only the Flock lays, offline too. Every chicken counts as home
	-- between visits (FlockIds has no fill-ins), so quitting in battle never drops
	-- a Flock chicken from the next night's earning rate.
	local eggsPerSecond = 0
	for _, id in session:FlockIds() do
		local pet = session.pets[id]
		if pet then eggsPerSecond += Rules.EggRate(pet.species, pet.stars, pet.level) * MutationCatalog.Multiplier(pet.mutation) end
	end
	eggsPerSecond *= session:EggProductionMultiplier()
	-- Use the existing income and pass owners. No extra multiplier at award time.
	-- EarnedAmount already applies the Re-enlist egg multiplier. October 20: the
	-- steady amount, so a live Gold Rush or Friend Boost is never frozen in here.
	local sellerRate = Processor.Rate(session.eggProcessor, session.entitlements.DoubleEggSpawn)
	local sellingRate = if ProcessorConfig.Enabled then math.min(eggsPerSecond, sellerRate) else eggsPerSecond
	local raw = sellingRate * Rules.EggUnitValue(session.incomeLevel) * (1+(session.researchEffects and session.researchEffects.eggValue or 0))
	return session:EarnedAmount(raw, "eggs", true) * (Tuning.Efficiency + gemBonus(session))
end

-- A checkpoint as saved: the frozen rate plus the efficiency it was recorded at
-- (the base plus the Offline Coins bonus, which is also kept on its own).
function OfflineCash.Checkpoint(session, at)
	local bonus = gemBonus(session)
	return {at = at, rate = OfflineCash.Rate(session), efficiency = Tuning.Efficiency + bonus, bonus = bonus,
		maxSeconds = (session.researchEffects and session.researchEffects.offlineHours or 8) * 3600}
end

function OfflineCash.Reward(checkpoint, now, coins)
	local away = if checkpoint.at > 0 then math.max(0, now - checkpoint.at) else 0
	local maximum=checkpoint.maxSeconds or Tuning.MaxSeconds
	local counted = math.min(away, maximum)
	-- Pay every checkpoint at today's base efficiency plus the Offline Coins bonus it
	-- was saved with (older saves were frozen at 2%; Gem Upgrades are never lost).
	local efficiency = Tuning.Efficiency + (checkpoint.bonus or 0)
	local rate = checkpoint.rate * efficiency / (checkpoint.efficiency or Tuning.LegacyEfficiency)
	local amount = if away >= Tuning.MinSeconds then math.floor(counted * rate + 1e-7) else 0
	local limited = amount > Tuning.MaxCoins
	amount = math.max(0, math.min(amount, Tuning.MaxCoins, math.floor(Currency.MaxCoins - coins)))
	return {amount = amount, awaySeconds = away, countedSeconds = counted,
		rate = rate, efficiency = efficiency, maxSeconds = maximum,
		capped = away > maximum or limited}
end

return OfflineCash
