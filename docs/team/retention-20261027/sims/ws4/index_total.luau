local Catalog = Harness.require(Harness.Shared.PetCatalog)
local Config = Harness.require(Harness.Shared.Config)
local total, pool, kinds = 0, 0, {}
for _, id in Catalog.Order do
	local d = Catalog[id]
	local visible = not (d.vaulted or (d.limited and not (Config.Event and Config.Event.Enabled)))
	if visible then total += 1; if d.weight > 0 and not d.crateExclusive then pool += 1 else table.insert(kinds, id .. (d.crateExclusive and "(crate)" or "") .. (d.limited and "(limited)" or "")) end end
end
print("index visible", total, "rollable", pool, "other visible:", table.concat(kinds, ", "))
local U, R = 0, 0
for _, id in Catalog.Order do local d = Catalog[id]; if d.weight > 0 and not d.crateExclusive then if d.rarity == "Uncommon" then U += 1/d.oneIn elseif d.rarity == "Rare" then R += 1/d.oneIn end end end
print(string.format("Uncommon share %.4f Rare share %.5f", U, R))
for _, id in Catalog.Order do local d = Catalog[id]; if d.rarity == "Rare" and d.weight > 0 then print(id, d.name, string.format("cond %.3f", (1/d.oneIn)/R), d.price, d.income) end end
