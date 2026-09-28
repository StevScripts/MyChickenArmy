--!strict
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.PetCatalog)
local Progression = require(script.Parent.Progression)
local Rules = {}

-- Frozen paid-level-era values. A new catalog price must not revalue old refunds.
local HistoricalPrices = {
	Duck=600, Mallard=1000, Chunky=2000, Sailor=2000, Bucket=3400, Viking=16000,
	Knight=26000, Wizard=48000, Dragon=96000, IceDuck=128000, StormDuck=192000,
}

-- Catalog income is the existing base cash/sec balance. Express it as egg quantity.
-- Retain the approved level curve: a merged bird produces 2x one input bird.
function Rules.EggRate(species: string, stars: number, level: number?): number
	local rank = math.clamp(level or 1, 1, Config.MaxPetLevel)
	local base = Catalog[species].income * Config.PassiveIncomeMultiplier
	return base / Config.EggBaseValue * 2 ^ (stars - 1) * 2 ^ (rank - 1)
end

function Rules.EggUnitValue(incomeLevel: number?): number
	return math.floor(Config.EggBaseValue * (1 + (incomeLevel or 0) * Config.IncomeMultiplierPerLevel) + 0.5)
end

function Rules.Income(species: string, stars: number, level: number?, incomeLevel: number?): number
	return Rules.EggRate(species, stars, level) * Rules.EggUnitValue(incomeLevel)
end

-- Every copy-equivalent costs the same, independent of the buyer's income or coins.
function Rules.RecruitPrice(species: string, level: number?): number
	local rank = math.clamp(level or 1, 1, Config.MaxPetLevel)
	return Catalog[species].price * 2 ^ (rank - 1)
end

-- Develop a species by merging; later offers supply copies one level behind it.
-- Never sell the rank's top merge level directly. Selling a species can lower future offers.
function Rules.RecruitLevel(pets, species: string, promotion: number): number
	local highest = 1
	for _, pet in pets do
		if pet.species == species then highest = math.max(highest, pet.level or 1) end
	end
	return math.clamp(highest - 1, 1, math.max(1, Progression.Get(promotion).levelCap - 1))
end

function Rules.SellValue(investment: number): number
	return math.floor(investment * Config.SellFraction)
end

-- Historical cost curve retained for investment/refund compatibility only.
-- Gameplay levels now increase through merging; this does not authorize a purchase.
function Rules.UpgradePrice(species: string, level: number): number?
	if level>=Config.MaxPetLevel then return nil end
	local definition=Catalog[species]
	local historical=HistoricalPrices[definition.economyBase or species] or definition.price
	local price=historical * Config.PetUpgradePriceFraction * Config.PetUpgradeGrowth ^ (level-1)
	return math.max(10,math.floor(price/10 + 0.5)*10)
end

-- Revision 4 inferred resale from the old price curve, including merged levels.
-- Freeze that exact historical value when loading it, then track real investment.
function Rules.Investment(species: string, level: number?, legacy: boolean?): number
	local historicalPrices = {Duck=60,Mallard=120,Chunky=260,Sailor=260,Bucket=600,Viking=1400,
		Knight=3200,Wizard=7000,Dragon=16000,IceDuck=21000,StormDuck=36000}
	local definition=Catalog[species]
	local key=definition.economyBase or species
	local price = (if legacy then historicalPrices[key] else HistoricalPrices[key]) or definition.price
	local total = price
	for previous=1,(level or 1)-1 do
		total += if legacy then math.floor(math.max(40,price*0.5)*previous^1.5)
			else Rules.UpgradePrice(species,previous) or 0
	end
	return total
end

function Rules.Stats(species: string, stars: number, level: number?)
	local pet = Catalog[species]
	local rank = math.clamp(level or 1, 1, Config.MaxPetLevel)
	local copies = 2 ^ (stars - 1)
	local combat = 1 + (rank - 1) * Config.PetCombatPerLevel
	local investment = pet.price * copies
	for previous=1,rank-1 do investment += Rules.UpgradePrice(species, previous) or 0 end
	return {hp=pet.hp * Config.StarHP[stars] * combat, damage=pet.damage * copies * combat,
		income=Rules.Income(species,stars,rank,0), interval=pet.interval,
		size=pet.size * Config.StarSize[stars], splash=pet.splash == true,
		refund=Rules.SellValue(investment)}
end

-- One full roster at every rank. Keep the optional tier argument for older callers;
-- conquest changes combat progression, never species eligibility or roll odds.
-- One owner for the displayed weight multiplier and normalized roll odds.
-- Preserve purchased opening bonuses; later levels add smaller gains.
function Rules.LuckMultiplier(luckLevel: number): number
	local opening = math.min(luckLevel, Config.LuckOpeningLevels)
	local later = math.max(0, luckLevel - Config.LuckOpeningLevels)
	return 1 + opening * Config.LuckWeightPerLevel + later * Config.LuckContinuationWeightPerLevel
end

function Rules.Odds(luckLevel: number, _tier: number?, paidMultiplier: number?)
	local weights, total = {}, 0
	-- Server-verified paid luck doubles Rare+ weights, not normalized percentages.
	local paid = if paidMultiplier == 2 then 2 else 1
	for _, id in Catalog.Order do
		local definition = Catalog[id]
		local lucky = definition.rarity == "Rare" or definition.rarity == "Epic" or definition.rarity == "Legendary" or definition.rarity == "Mythic"
		local boost = if lucky
			then Rules.LuckMultiplier(luckLevel) * paid else 1
		weights[id] = definition.weight * boost
		total += weights[id]
	end
	for id, weight in weights do weights[id] = weight / total end
	return weights
end

function Rules.FormatOdds(chance: number): string
	if chance <= 0 then return "Unavailable" end
	local percent = chance * 100
	if percent >= 1 then return string.format("%.1f%%", percent) end
	if percent >= 0.01 then return string.format("%.2f%%", percent) end
	return string.format("≈ 1 in %d", math.floor(1 / chance + 0.5))
end

function Rules.Draw(luckLevel: number, randomValue: number, tier: number?, paidMultiplier: number?): string
	local odds, cumulative = Rules.Odds(luckLevel,tier,paidMultiplier), 0
	for _, id in Catalog.Order do
		cumulative += odds[id]
		if randomValue < cumulative then return id end
	end
	for i=#Catalog.Order,1,-1 do local id=Catalog.Order[i]; if odds[id]>0 then return id end end
	return "Duck"
end

function Rules.PetPower(species: string, stars: number, level: number?): number
	local stats = Rules.Stats(species, stars, level)
	return math.sqrt(stats.hp * stats.damage / stats.interval) * (if stats.splash then 1.35 else 1)
end

function Rules.Power(roster): number
	local power = 0
	for _, pet in roster do
		power += Rules.PetPower(pet.species, pet.stars, pet.level)
	end
	return math.floor(power)
end

return Rules
