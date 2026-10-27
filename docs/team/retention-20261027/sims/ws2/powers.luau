local Catalog = Harness.require(Harness.Shared.PetCatalog)
local Rules = Harness.require(Harness.Shared.Rules)
local seen = {}
for _, id in Catalog.Order do
	local d = Catalog[id]
	if d.oneIn and (d.weight or 1) > 0 and not d.vaulted then
		local r = d.rarity
		seen[r] = seen[r] or {}
		table.insert(seen[r], string.format("%s %d/%d", id, d.price, math.floor(Rules.PetPower(id, 1, 1) + 0.5)))
	end
end
for _, r in {"Common","Uncommon","Rare","Epic","Legendary"} do print(r, table.concat(seen[r] or {}, ", ")) end
print("Duck Lv1..5", Rules.PetPower("Duck",1,1), Rules.PetPower("Duck",1,2), Rules.PetPower("Duck",1,3), Rules.PetPower("Duck",1,4), Rules.PetPower("Duck",1,5))
print("Feed Duck", Rules.ChickenUpgradePrice("Duck",1), Rules.ChickenUpgradePrice("Duck",2), Rules.ChickenUpgradePrice("Duck",3))
print("Feed Bonsai", Rules.ChickenUpgradePrice("Bonsai",1), Rules.ChickenUpgradePrice("Bonsai",2))
