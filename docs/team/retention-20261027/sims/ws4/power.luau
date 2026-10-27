local Rules = Harness.require(Harness.Shared.Rules)
local Catalog = Harness.require(Harness.Shared.PetCatalog)
for _, id in {"Duck","Rooster","Bonsai","Bee","Lollipop","Bucket","Slime","Viking","Frost","Knight"} do
	print(string.format("%-10s %-20s %-9s power %5.1f income %3d price %6d", id, Catalog[id].name, Catalog[id].rarity, Rules.PetPower(id,1,1), Catalog[id].income, Catalog[id].price))
end
