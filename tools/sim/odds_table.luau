local Catalog = Harness.require(Harness.Shared.PetCatalog)
local Rules = Harness.require(Harness.Shared.Rules)
local Tree = Harness.require(Harness.Shared.UpgradeCatalog)
local RARITIES = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Secret"}
local function byRarity(odds)
	local t = {}
	for _, r in RARITIES do t[r] = 0 end
	for _, id in Catalog.Order do
		local d = Catalog[id]
		if odds[id] and odds[id] > 0 then t[d.rarity] = (t[d.rarity] or 0) + odds[id] end
	end
	return t
end
local function row(label, luckTier, paid, bonus)
	local odds = Rules.Odds(luckTier, 0, paid, bonus)
	local w = Rules.LuckWindow(luckTier, paid, bonus)
	local t = byRarity(odds)
	local rarePlus = t.Rare + t.Epic + t.Legendary + t.Mythic + t.Secret
	local legPlus = t.Legendary + t.Mythic + t.Secret
	print(string.format("%-32s M=%5.2f shift=%4.2f | C %5.1f%% U %5.1f%% R %5.1f%% E %5.1f%% L %6.2f%% M %6.3f%% S %6.4f%% | Rare+ %5.1f%% Leg+ %6.2f%% (1 in %.0f)",
		label, w.multiplier, w.shift, t.Common*100, t.Uncommon*100, t.Rare*100, t.Epic*100, t.Legendary*100, t.Mythic*100, t.Secret*100,
		rarePlus*100, legPlus*100, legPlus > 0 and 1/legPlus or 0))
end
local function tierName(tier) return if tier > 0 then Tree.Families.Luck.labels[tier].name .. " (" .. Tree.Price("Luck", tier) .. ")" else "No Luck" end
print("== Luck tiers, plain lever pull ==")
for tier = 0, 12 do row(tierName(tier), tier, 1, 0) end
print("== + Playtime +100% Luck boost (8 min and 40 min tiles) ==")
for tier = 0, 6 do row(tierName(tier) .. " +boost", tier, 1, 1) end
print("== Gold roll (every 10th pull, x2 Luck) = same as boost; Gold + boost (x4) ==")
for tier = 0, 4 do row(tierName(tier) .. " gold+boost", tier, 1, 3) end
print("== Diamond roll x5 / Prism x10 ==")
for tier = 0, 4 do row(tierName(tier) .. " diamond", tier, 1, 4) end
row("No Luck prism", 0, 1, 9)
print("== Hill roll (bonus 2 = x3) ==")
row("No Luck hill", 0, 1, 2)
print("== 2x Luck gamepass ==")
for tier = 0, 4 do row(tierName(tier) .. " 2x pass", tier, 2, 0) end
row("Mega Luck IV + pass + boost", 12, 2, 1)
print("== Species (zero-Luck odds, level-1 price, income/s) ==")
for _, id in Catalog.Order do
	local d = Catalog[id]
	if d.oneIn then print(string.format("%-12s %-10s 1 in %9.1f  price %12d  income %4d  %s", id, d.rarity, d.oneIn, d.price, d.income, d.name)) end
end
