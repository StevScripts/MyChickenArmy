--!strict
-- Normal recruitment only. Strength bands own probability; appearances share it.
local Catalog = require(script.Parent.PetCatalog)
local UpgradeCatalog = require(script.Parent.UpgradeCatalog)
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
-- October 21 (Stevin: "rare chickens way too fast", "Luck should take a bit"): bands the
-- favored range climbs for every x10 of Luck strength. x2 moves it 0.68 bands, x3 (Luck
-- IV) 1.07, x10 (Mega Luck IV) 2.25; the stacked cap (x10 tree, 2x pass, +100% Playtime
-- boost, x10 Prism roll = x400) 5.85, never past the top band. The old 9 (M-1)/(M+2)
-- curve gave Luck IV a 3.6-band shift: Legendaries on 22% of podiums twelve minutes in
-- (docs/team/RARITY_PACING_20261021.md).
-- October 22 (Stevin: chances "similar to that other game… it was mostly common"): the
-- bands now match the Drop a Fruit Index (Common 93%), so a band of shift moves far more
-- of a roll; 0.35 keeps a simulated first hour at about 83% Commons (2.25 gave 21%).
-- x3 (Luck IV) moves 0.17 bands, x10 0.35, the x400 stack 0.91
-- (docs/team/RARITY_REBALANCE_20261022.md).
ChickenLuck.ShiftPerDecade = 0.35
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

-- October 20: luckLevel is the Upgrades tree's Luck tier (Luck I-IV).
function ChickenLuck.Multiplier(luckLevel: number): number
	return UpgradeCatalog.LuckMultiplier(nonnegative(luckLevel))
end

function ChickenLuck.Window(luckLevel: number, paidMultiplier: number?, researchLuckBonus: number?)
	local paid = if paidMultiplier == 2 then 2 else 1
	local multiplier = ChickenLuck.Multiplier(luckLevel) * paid * (1 + nonnegative(researchLuckBonus))
	-- A bounded continuous shift: ShiftPerDecade bands per x10 of strength, capped at the
	-- top band, so every stacked bonus still helps and nothing overflows.
	local shift = math.min(#ChickenLuck.Bands - 1, ChickenLuck.ShiftPerDecade * math.log10(math.max(1, multiplier)))
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
