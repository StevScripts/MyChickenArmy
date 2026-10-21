-- Pure probability checks: no player profiles, purchases, world objects or live RNG.
local Shared = game.ReplicatedStorage.PetRoll.Shared
local Catalog = require(Shared.PetCatalog)
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local UpgradeCatalog = require(Shared.UpgradeCatalog)
local Checks = {}

-- October 20: cash Luck is the Upgrades tree's Luck I-IV (Config.LuckPrices is a legacy view).
local LuckTiers = #UpgradeCatalog.Families.Luck.tiers

local Representatives = {"Duck", "Mallard", "Chunky", "Bucket", "Viking", "Knight", "Dragon", "Rainbow", "IceDuck", "StormDuck"}
local OpeningBudgets = {38, 22, 22, 9, 5, 3, 0.7, 0.25, 0.05, 0.01}
local ResearchBonuses = {0, 0.1, 0.2, 0.35, 0.5, 0.75, 1}
local OpeningTotal = 100.01
local Epsilon = 1e-10

local function near(actual, expected, context)
	assert(math.abs(actual - expected) < Epsilon,
		(context or "Probability") .. ": " .. tostring(actual) .. " differs from " .. tostring(expected))
end

-- October 15 "1 in X": rarer appearances carry their own stats, so bands are
-- matched by the tier stats recorded before the rarity premium (luckSignature).
local function sameStats(a, b)
	return (Catalog.LuckSignature or function(d) return d.luckSignature end)(a)
		== (Catalog.LuckSignature or function(d) return d.luckSignature end)(b)
end

local function bandFor(catalog, species)
	for index, representative in Representatives do
		if sameStats(catalog[species], catalog[representative]) then return index end
	end
	return nil
end

local function bandOdds(odds, catalog)
	local result = table.create(#Representatives, 0)
	for _, species in catalog.Order do
		local definition = catalog[species]
		if definition.weight > 0 and not definition.crateExclusive then
			local band = assert(bandFor(catalog, species), "Missing strength band for " .. species)
			result[band] += assert(odds[species], "Missing odds for " .. species)
		end
	end
	return result
end

local function assertImproves(before, after, context)
	local beforeTail, afterTail, improved = 0, 0, false
	for band = #Representatives, 2, -1 do
		beforeTail += before[band]
		afterTail += after[band]
		assert(afterTail + Epsilon >= beforeTail, context .. " worsened threshold " .. Representatives[band])
		if afterTail > beforeTail + Epsilon then improved = true end
	end
	assert(improved, context .. " did not improve any strength threshold")
end

local function oddsAt(level, paid, research)
	return Rules.Odds(level, 1, paid, research)
end

-- Optional runner injection returns a fresh ChickenLuck.Odds closure bound to a
-- cloned catalog. Production modules and their cached catalog are never mutated.
function Checks.Run(catalogOddsFactory)
	local results = {}
	local function check(name, callback)
		local passed, detail = pcall(callback)
		table.insert(results, {name = name, passed = passed, detail = tostring(detail)})
	end

	check("Zero Luck preserves every normal species probability and all ten strength budgets", function()
		local odds, total = oddsAt(0, 1, 0), 0
		for _, species in Catalog.Order do
			local definition = Catalog[species]
			local expected = if definition.crateExclusive then 0 else definition.weight / OpeningTotal
			near(odds[species], expected, species)
			total += odds[species]
		end
		near(total, 1)
		for band, chance in bandOdds(odds, Catalog) do near(chance, OpeningBudgets[band] / OpeningTotal) end
		for band = 2, #Representatives do
			local before, after = Representatives[band - 1], Representatives[band]
			assert(Catalog[after].income > Catalog[before].income)
			assert(Rules.PetPower(after, 1, 1) > Rules.PetPower(before, 1, 1), "Strength band order disagrees with combat")
		end
		return "Exact opening odds retained; economic and combat strength increase across bands"
	end)

	check("Every cash, research and paid combination normalizes with positive normal odds and zero crate odds", function()
		local count = 0
		for level = 0, #Config.LuckPrices do
			for _, paid in {1, 2} do
				for _, research in ResearchBonuses do
					local odds, total = oddsAt(level, paid, research), 0
					for _, species in Catalog.Order do
						local chance, definition = odds[species], Catalog[species]
						assert(type(chance) == "number" and chance == chance and chance >= 0 and chance < 1,
							species .. " has invalid probability")
						if definition.crateExclusive or definition.weight == 0 then
							near(chance, 0, species)
						else
							assert(chance > 0, species .. " became unavailable")
							assert(chance + Epsilon >= 0.1 * definition.weight / OpeningTotal, species .. " lost its global floor")
						end
						total += chance
					end
					near(total, 1)
					count += 1
				end
			end
		end
		return tostring(count) .. " distributions checked"
	end)

	check("Every cash Luck purchase improves at least one strength threshold and worsens none", function()
		for _, paid in {1, 2} do
			for _, research in ResearchBonuses do
				local previous = bandOdds(oddsAt(0, paid, research), Catalog)
				for level = 1, LuckTiers do
					local current = bandOdds(oddsAt(level, paid, research), Catalog)
					assertImproves(previous, current, "Cash Luck " .. level)
					assert(current[#current] > previous[#previous], "Cash Luck stopped improving the strongest band")
					previous = current
				end
			end
		end
		return "Every Luck tier remains useful, including with both bonus sources"
	end)

	check("Each research tier preserves every strength threshold and improves rolls at the cash cap", function()
		for level = 0, #Config.LuckPrices do
			for _, paid in {1, 2} do
				local previous = bandOdds(oddsAt(level, paid, 0), Catalog)
				for index = 2, #ResearchBonuses do
					local current = bandOdds(oddsAt(level, paid, ResearchBonuses[index]), Catalog)
					assertImproves(previous, current, "Research tier " .. index)
					assert(current[#current] > previous[#previous], "Research stopped improving the strongest band")
					previous = current
				end
			end
		end
		return "Research improves the distribution at every cash level, with and without the paid bonus"
	end)

	check("The verified paid multiplier remains useful at all cash and research levels", function()
		for level = 0, #Config.LuckPrices do
			for _, research in ResearchBonuses do
				local withoutPass = bandOdds(oddsAt(level, 1, research), Catalog)
				local withPass = bandOdds(oddsAt(level, 2, research), Catalog)
				assertImproves(withoutPass, withPass, "Paid Luck at cash " .. level)
				assert(withPass[#withPass] > withoutPass[#withoutPass])
			end
		end
		for _, unverified in {0, 1.5, 3, 100} do
			local actual, expected = oddsAt(20, unverified, 1), oddsAt(20, 1, 1)
			for _, species in Catalog.Order do near(actual[species], expected[species], species) end
		end
		return "Only the existing exact 2x eligibility input applies the paid bonus"
	end)

	check("Equivalent-stat appearances share their band's probability in stable relative proportions", function()
		assert(bandFor(Catalog, "Chunky") == bandFor(Catalog, "Sailor"), "Equivalent base families split into separate bands")
		for level = 0, #Config.LuckPrices do
			for _, paid in {1, 2} do
				for _, research in ResearchBonuses do
					local odds, ratios = oddsAt(level, paid, research), {}
					for _, species in Catalog.Order do
						local definition = Catalog[species]
						if definition.weight > 0 and not definition.crateExclusive then
							local band = assert(bandFor(Catalog, species))
							local ratio = odds[species] / definition.weight
							if ratios[band] then near(ratio, ratios[band], species) else ratios[band] = ratio end
						end
					end
				end
			end
		end
		return "All variants, including Chunky and Sailor families, share fixed strength-band budgets"
	end)

	check("Every displayed normal probability maps to its actual draw interval", function()
		for level = 0, #Config.LuckPrices do
			for _, paid in {1, 2} do
				for _, research in ResearchBonuses do
					local odds, cumulative, first, last = oddsAt(level, paid, research), 0, nil, nil
					for _, species in Catalog.Order do
						local chance = odds[species]
						if chance > 0 then
							assert(Rules.Draw(level, cumulative + chance / 2, 1, paid, research) == species,
								species .. " draw interval disagrees with odds")
							first, last = first or species, species
						end
						cumulative += chance
					end
					assert(Rules.Draw(level, 0, 1, paid, research) == first)
					assert(Rules.Draw(level, 1, 1, paid, research) == last, "Fallback selected an excluded crate species")
				end
			end
		end
		return "Interval midpoints and endpoint fallbacks agree across the complete modifier matrix"
	end)

	check("Camp rank cannot alter chicken odds", function()
		for _, level in {0, 4, 20} do
			for _, paid in {1, 2} do
				for _, research in ResearchBonuses do
					local expected = oddsAt(level, paid, research)
					for _, rank in {1, 2, 4, 100} do
						local actual = Rules.Odds(level, rank, paid, research)
						for _, species in Catalog.Order do near(actual[species], expected[species], species) end
					end
				end
			end
		end
		return "The compatibility tier argument never gates or changes normal rolls"
	end)

	check("Probabilities remain continuous as the moving window crosses every reachable band boundary", function()
		-- October 20: cash Luck moves in whole tiers, so the research bonus (Extra Luck,
		-- Gold rolls) carries the window continuously across each boundary.
		local function checkBoundary(paid, research)
			local before = oddsAt(0, paid, research - 1e-7)
			local at = oddsAt(0, paid, research)
			local after = oddsAt(0, paid, research + 1e-7)
			local beforeDistance, afterDistance = 0, 0
			for _, species in Catalog.Order do
				beforeDistance += math.abs(before[species] - at[species])
				afterDistance += math.abs(after[species] - at[species])
			end
			assert(beforeDistance < 1e-6 and afterDistance < 1e-6, "Probability jumped at a window edge")
			assertImproves(bandOdds(before, Catalog), bandOdds(after, Catalog), "Luck bonus boundary")
		end
		for shift = 1, 7 do
			-- Invert the documented tuning only to locate edges; the assertion checks
			-- continuity and ordering, not a duplicate implementation of the odds.
			local multiplier = (9 + 2 * shift) / (9 - shift)
			local paid = if multiplier > 3 then 2 else 1
			checkBoundary(paid, multiplier / paid - 1)
		end
		return "Seven transported-band boundaries are continuous"
	end)

	check("Window metadata advances continuously and retains useful research and paid progress beyond cash cap", function()
		local opening = Rules.LuckWindow(0, 1, 0)
		near(opening.multiplier, 1); near(opening.shift, 0); near(opening.left, 1); near(opening.right, 5)
		local cashCap, stackedCap = Rules.LuckWindow(20, 1, 0), Rules.LuckWindow(20, 2, 1)
		near(cashCap.multiplier, 3); near(cashCap.shift, 3.6)
		near(stackedCap.multiplier, 12); near(stackedCap.shift, 99 / 14)
		assert(stackedCap.left > cashCap.left and stackedCap.right >= cashCap.right)
		for _, paid in {1, 2} do
			for _, research in ResearchBonuses do
				local previous
				for level = 0, LuckTiers do
					local current = Rules.LuckWindow(level, paid, research)
					assert(current.left >= 1 and current.left <= current.right and current.right <= #Representatives)
					near(current.left, 1 + current.shift)
					near(current.right, math.min(#Representatives, 5 + current.shift))
					for _, field in {"firstName", "lastName", "rangeText"} do
						assert(type(current[field]) == "string" and #current[field] > 0, "Missing window text " .. field)
					end
					if previous then
						assert(current.left > previous.left and current.right >= previous.right)
					end
					previous = current
				end
			end
		end
		return "Cash cap shifts 3.6 bands; both bonuses shift about 7.07; pointers remain ordered and bounded"
	end)

	if catalogOddsFactory then
		check("Adding an equivalent appearance changes only its band's appearance shares", function()
			local fixture = {Order = table.clone(Catalog.Order)}
			for _, species in Catalog.Order do fixture[species] = table.clone(Catalog[species]) end
			local addedId = "LuckFixtureSkin"
			fixture[addedId] = table.clone(Catalog.Sailor)
			fixture[addedId].name, fixture[addedId].weight = "Luck fixture appearance", 100
			table.insert(fixture.Order, addedId)
			local fixtureOdds = catalogOddsFactory(fixture)
			for level = 0, #Config.LuckPrices do
				for _, paid in {1, 2} do
					for _, research in ResearchBonuses do
						local original, changed = oddsAt(level, paid, research), fixtureOdds(level, paid, research)
						local originalBands, changedBands = bandOdds(original, Catalog), bandOdds(changed, fixture)
						for band, chance in originalBands do near(changedBands[band], chance, "Skin changed band budget") end
						assert(changed[addedId] > 0, "Equivalent appearance was excluded")
						for _, species in Catalog.Order do
							if bandFor(Catalog, species) ~= 3 then near(changed[species], original[species], species) end
						end
					end
				end
			end
			return "A high-weight new skin shares band 3 without changing any strength-band budget or other species"
		end)
	end
	return results
end

return Checks
