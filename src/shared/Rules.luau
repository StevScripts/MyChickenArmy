--!strict
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.PetCatalog)
local ChickenLuck = require(script.Parent.ChickenLuck)
local Giant = require(script.Parent.GiantChicken)
local UpgradeCatalog = require(script.Parent.UpgradeCatalog)
local Rules = {}

-- Frozen paid-level-era values. A new catalog price must not revalue old refunds.
local HistoricalPrices = {
	Duck=600, Mallard=1000, Chunky=2000, Sailor=2000, Bucket=3400, Viking=16000,
	Knight=26000, Wizard=48000, Dragon=96000, IceDuck=128000, StormDuck=192000,
}

-- The highest level Chicken Feed reaches for this player: Config.MaxPetLevel plus the
-- effect feedMaxLevel (S9c's Feed Max Level tiers or any later source), at most
-- Config.PetLevelLimit (October 20, S7b).
function Rules.LevelCap(effects: any): number
	local extra = if type(effects) == "table" then tonumber(effects.feedMaxLevel) else nil
	if extra == nil or extra ~= extra then extra = 0 end
	return math.clamp(Config.MaxPetLevel + math.floor(extra :: number), Config.MaxPetLevel, Config.PetLevelLimit)
end

-- Catalog income is the existing base cash/sec balance, in units of the base egg
-- value: income per second is EggRate x EggUnitValue. October 21: this is a Coins
-- rate, not an egg count; every chicken lays one egg per LaySeconds (below).
-- Retain the approved level curve: a merged bird produces 2x one input bird. Levels
-- past Config.MaxPetLevel (Feed Max Level) add +25% each instead (Stevin, Oct 20).
Rules.EggGrowthPastCap = 1.25
function Rules.EggRate(species: string, stars: number, level: number?): number
	local rank = math.clamp(level or 1, 1, Config.PetLevelLimit)
	local doubled = math.min(rank, Config.MaxPetLevel)
	local base = Catalog[species].income * Config.PassiveIncomeMultiplier
	return base / Config.EggBaseValue * 2 ^ (stars - 1) * 2 ^ (doubled - 1) * Rules.EggGrowthPastCap ^ (rank - doubled)
end

-- Seconds between two eggs from one chicken. Egg Speed and Double Egg Spawn
-- (production) lay eggs sooner, never faster than Config.EggMinLaySeconds.
function Rules.LaySeconds(production: number?): number
	local speed = if type(production) == "number" and production > 0 then production else 1
	return math.clamp(Config.EggLaySeconds / speed, Config.EggMinLaySeconds, Config.EggLaySeconds)
end

-- October 20: incomeLevel is the Upgrades tree's Egg Value tier (0-4).
function Rules.EggUnitValue(incomeLevel: number?): number
	return math.floor(Config.EggBaseValue * UpgradeCatalog.EggValueMultiplier(incomeLevel) + 0.5)
end

function Rules.Income(species: string, stars: number, level: number?, incomeLevel: number?): number
	return Rules.EggRate(species, stars, level) * Rules.EggUnitValue(incomeLevel)
end

-- Every copy-equivalent costs the same, independent of the buyer's income or coins.
function Rules.RecruitPrice(species: string, level: number?): number
	local rank = math.clamp(level or 1, 1, Config.MaxPetLevel)
	return Catalog[species].price * 2 ^ (rank - 1)
end

-- Three copies are already committed; the additional cash sink scales with
-- species and input level, never the player's wallet or earnings upgrades.
function Rules.MergePrice(species: string, level: number): number
	return math.max(1,math.ceil(Rules.RecruitPrice(species,level)*Config.Economy.FusionRecruitFraction))
end

-- Current cash-level quote. Keep the historical UpgradePrice below frozen so
-- changing today's tuning cannot revalue investments reconstructed from old saves.
-- October 8: each level doubles eggs, so a flat 75% quote paid back in constant
-- time and ran away. The extra 2.5x per level makes each quote 5x the last
-- (Common: $1,800, $9,000, $45,000 ...); level 1→2 is unchanged. Exact in floats.
Rules.ChickenUpgradeGrowth = 2.5
-- October 20 (S7b): past Config.MaxPetLevel a level adds +25% eggs, not 2x. Its Feed
-- keeps levels 1-10's slope (each level takes 2.5x longer to pay back than the last):
-- 1.25x the Lv 9 -> 10 quote, then 3.125x (1.25 x 2.5) per level. Draft until the re-fit.
-- The player's own cap (Rules.LevelCap) is checked by ChickenUpgradeEligibility.
Rules.FeedPastCapFirst = 1.25
Rules.FeedPastCapGrowth = 3.125
function Rules.ChickenUpgradePrice(species: string, level: number): number?
	if level>=Config.PetLevelLimit then return nil end
	if level>=Config.MaxPetLevel then
		local last=Rules.ChickenUpgradePrice(species,Config.MaxPetLevel-1) :: number
		return math.ceil(last*Rules.FeedPastCapFirst*Rules.FeedPastCapGrowth^(level-Config.MaxPetLevel))
	end
	return math.max(1,math.ceil(Rules.RecruitPrice(species,level)*Config.Economy.ChickenUpgradeRecruitFraction
		*Rules.ChickenUpgradeGrowth^(math.max(1,level)-1)))
end

-- Develop a species by merging; later offers supply copies one level behind it.
-- Never sell the rank's top merge level directly. Selling a species can lower future offers.
-- October 20: Chicken Feed levels (pet.cashLevels) reset on Rebirth, so they never
-- raise offers; otherwise one fed chicken would buy permanent high-level rolls.
function Rules.RecruitLevel(pets, species: string, _promotion: number): number
	local highest = 1
	for _, pet in pets do
		if pet.species == species then highest = math.max(highest, (pet.level or 1) - (pet.cashLevels or 0)) end
	end
	-- October 15: no rank cap (Fuse reaches Lv 10 from the start).
	return math.clamp(highest - 1, 1, Config.MaxPetLevel - 1)
end

function Rules.SellValue(investment: number): number
	return math.floor(investment * Config.SellFraction)
end

-- Historical cost curve retained for investment/refund compatibility only.
-- New cash purchases use ChickenUpgradePrice; this curve only reconstructs old saves.
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

-- giantSize (optional): a Giant has more health and damage and stomps (splash).
function Rules.Stats(species: string, stars: number, level: number?, giantSize: number?)
	local pet = Catalog[species]
	-- HP and damage keep +25% of base per level through Feed Max Level's levels.
	local rank = math.clamp(level or 1, 1, Config.PetLevelLimit)
	local copies = 2 ^ (stars - 1)
	local combat = 1 + (rank - 1) * Config.PetCombatPerLevel
	local investment = pet.price * copies
	for previous=1,rank-1 do investment += Rules.UpgradePrice(species, previous) or 0 end
	local giant = Giant.IsValidSize(giantSize)
	return {hp=pet.hp * Config.StarHP[stars] * combat * (if giant then Giant.HealthMultiplier else 1),
		damage=pet.damage * copies * combat * (if giant then Giant.DamageMultiplier else 1),
		income=Rules.Income(species,stars,rank,0), interval=pet.interval,
		attackWindup=pet.attackWindup or Config.AttackWindupSeconds,
		size=pet.size * Config.StarSize[stars], splash=pet.splash == true or giant,
		refund=Rules.SellValue(investment), giant=giant}
end

-- One full roster at every rank. Keep the optional tier argument for older callers;
-- conquest changes combat progression, never species eligibility or roll odds.
-- Luck strength moves a favored range through equivalent-stat bands. Keep these
-- compatibility entry points so offers, snapshots, reels and disclosures agree.
function Rules.LuckMultiplier(luckLevel: number): number
	return ChickenLuck.Multiplier(luckLevel)
end

function Rules.LuckWindow(luckLevel: number, paidMultiplier: number?, researchLuckBonus: number?)
	return ChickenLuck.Window(luckLevel, paidMultiplier, researchLuckBonus)
end

function Rules.Odds(luckLevel: number, _tier: number?, paidMultiplier: number?, researchLuckBonus: number?)
	return ChickenLuck.Odds(luckLevel, paidMultiplier, researchLuckBonus)
end

function Rules.FormatOdds(chance: number): string
	if chance <= 0 then return "Unavailable" end
	local percent = chance * 100
	if percent >= 1 then return string.format("%.1f%%", percent) end
	if percent >= 0.01 then return string.format("%.2f%%", percent) end
	return string.format("≈ 1 in %d", math.floor(1 / chance + 0.5))
end

function Rules.Draw(luckLevel: number, randomValue: number, tier: number?, paidMultiplier: number?, researchLuckBonus: number?): string
	local odds, cumulative = Rules.Odds(luckLevel,tier,paidMultiplier,researchLuckBonus), 0
	for _, id in Catalog.Order do
		cumulative += odds[id]
		if randomValue < cumulative then return id end
	end
	for i=#Catalog.Order,1,-1 do local id=Catalog.Order[i]; if odds[id]>0 then return id end end
	return "Duck"
end

function Rules.PetPower(species: string, stars: number, level: number?, giantSize: number?): number
	local stats = Rules.Stats(species, stars, level, giantSize)
	return math.sqrt(stats.hp * stats.damage / stats.interval) * (if stats.splash then 1.35 else 1)
end

function Rules.Power(roster): number
	local power = 0
	for _, pet in roster do
		power += Rules.PetPower(pet.species, pet.stars, pet.level, pet.giantSize)
	end
	return math.floor(power)
end

return Rules
