--!strict
-- Offline cash calculation only. DataService owns the durable award boundary.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Rules = require(Shared.Rules)
local Tuning = require(Shared.OfflineCashConfig)
local OfflineCash = {}

function OfflineCash.Read(value)
	if value == nil then return {at = 0, rate = 0} end
	local function finite(n, maximum)
		return type(n) == "number" and n == n and n >= 0 and n <= maximum
	end
	if type(value) ~= "table" or not finite(value.at, 2^53 - 1) or value.at % 1 ~= 0
		or not finite(value.rate, Tuning.MaxCoins) then return nil end
	return {at = value.at, rate = value.rate}
end

function OfflineCash.Rate(session)
	-- All owned chickens return home between visits; quitting in battle must not
	-- permanently remove them from the next night's earning rate.
	local eggsPerSecond = 0
	for _, pet in session.pets do
		eggsPerSecond += Rules.EggRate(pet.species, pet.stars, pet.level)
	end
	eggsPerSecond *= session:EggProductionMultiplier()
	-- Use the existing income and pass owners. No extra multiplier at award time.
	local raw = eggsPerSecond * Rules.EggUnitValue(session.incomeLevel)
	return session:EarnedAmount(raw, "eggs") * Tuning.Efficiency
end

function OfflineCash.Reward(checkpoint, now, coins)
	local away = if checkpoint.at > 0 then math.max(0, now - checkpoint.at) else 0
	local counted = math.min(away, Tuning.MaxSeconds)
	local amount = if away >= Tuning.MinSeconds then math.floor(counted * checkpoint.rate + 1e-7) else 0
	amount = math.max(0, math.min(amount, math.floor(Tuning.MaxCoins - coins)))
	return {amount = amount, awaySeconds = away, countedSeconds = counted,
		rate = checkpoint.rate, efficiency = Tuning.Efficiency, maxSeconds = Tuning.MaxSeconds,
		capped = away > Tuning.MaxSeconds}
end

return OfflineCash
