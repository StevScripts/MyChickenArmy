--!strict
-- Normal recruitment only. Strength bands own probability; appearances share it.
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.PetCatalog)
local ChickenLuck = {}

-- Fixed budgets define the zero-Luck distribution. Adding an equivalent
-- appearance divides its band's budget instead of changing progression odds.
-- October 7 reset: bands follow income, combat strength AND rarity; the basic
-- Chicken leads a fresh roll and a Mythic starts at about 1 in 1,667.
ChickenLuck.Bands = Catalog.LuckBands -- Owned by PetCatalog (zero-Luck "1 in X").
local baselineShare = 0.10
-- October 14 owner retune: only this share of the top band's final probability
-- stays; the rest drops to the band below (see PetCatalog.LuckTopBandKeep).
ChickenLuck.TopBandKeep = Catalog.LuckTopBandKeep
local initialWindowEnd = 5 -- These bands contain 95.99% of baseline probability.
local bandBySignature, bandBySpecies, memberWeights = {}, {}, {}
local totalBudget = 0

-- Tier stats recorded before the rarity premium, so a rarer appearance stays in its band.
local signature = Catalog.LuckSignature

for index, band in ChickenLuck.Bands do
	local key = signature(Catalog[band.species])
	assert(not bandBySignature[key], "Luck bands must represent distinct stats")
	bandBySignature[key] = index
	memberWeights[index] = 0
	totalBudget += band.weight
end
for _, species in Catalog.Order do
	local definition = Catalog[species]
	if definition.weight > 0 and not definition.crateExclusive then
		local index = assert(bandBySignature[signature(definition)],
			"Assign a Luck strength band before adding " .. species .. " to normal rolls")
		bandBySpecies[species] = index
		memberWeights[index] += definition.weight
	end
end
for index in ChickenLuck.Bands do
	assert(memberWeights[index] > 0, "Luck bands need at least one normal chicken")
end

local function nonnegative(value: number?): number
	if not value or value ~= value or math.abs(value) == math.huge then return 0 end
	return math.max(0, value)
end

function ChickenLuck.Multiplier(luckLevel: number): number
	local level = math.min(nonnegative(luckLevel), #Config.LuckPrices)
	local opening = math.min(level, Config.LuckOpeningLevels)
	local later = math.max(0, level - Config.LuckOpeningLevels)
	return 1 + opening * Config.LuckWeightPerLevel + later * Config.LuckContinuationWeightPerLevel
end

function ChickenLuck.Window(luckLevel: number, paidMultiplier: number?, researchLuckBonus: number?)
	local paid = if paidMultiplier == 2 then 2 else 1
	local multiplier = ChickenLuck.Multiplier(luckLevel) * paid * (1 + nonnegative(researchLuckBonus))
	-- A bounded continuous shift leaves room for research and the verified pass.
	-- Cash cap: 4.5 bands; cash cap + maximum research + pass: 7.5 bands.
	local shift = (#ChickenLuck.Bands - 1) * (1 - 3 / (multiplier + 2))
	local left, right = 1 + shift, math.min(#ChickenLuck.Bands, initialWindowEnd + shift)
	local firstName = Catalog[ChickenLuck.Bands[math.floor(left)].species].name
	local lastName = Catalog[ChickenLuck.Bands[math.ceil(right)].species].name
	local top = Catalog[ChickenLuck.Bands[#ChickenLuck.Bands].species]
	return {multiplier=multiplier, shift=shift, left=left, right=right,
		firstName=firstName, lastName=lastName, rangeText=firstName .. " – " .. lastName,
		topIncome=top.income, topName=top.name}
end

function ChickenLuck.Odds(luckLevel: number, paidMultiplier: number?, researchLuckBonus: number?)
	local shift = ChickenLuck.Window(luckLevel, paidMultiplier, researchLuckBonus).shift
	local probabilities = table.create(#ChickenLuck.Bands, 0)
	for index, band in ChickenLuck.Bands do
		local baseline = band.weight / totalBudget
		probabilities[index] += baseline * baselineShare
		-- Transport the remaining mass upward, interpolating between adjacent bands.
		-- With the same baseline draw and fractional-rounding draw, increasing shift
		-- never yields a weaker band: every stronger-threshold chance is monotone.
		local destination = math.min(#ChickenLuck.Bands, index + shift)
		local lower = math.floor(destination)
		local fraction = destination - lower
		local moving = baseline * (1 - baselineShare)
		probabilities[lower] += moving * (1 - fraction)
		if fraction > 0 then probabilities[lower + 1] += moving * fraction end
	end
	local top = #ChickenLuck.Bands
	local dropped = probabilities[top] * (1 - ChickenLuck.TopBandKeep)
	probabilities[top] -= dropped
	probabilities[top - 1] += dropped

	local odds = {}
	for _, species in Catalog.Order do
		local index = bandBySpecies[species]
		odds[species] = if index then probabilities[index] * Catalog[species].weight / memberWeights[index] else 0
	end
	return odds
end

return ChickenLuck
