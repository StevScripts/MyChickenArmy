local Catalog = Harness.require(Harness.Shared.PetCatalog)
local Rules = Harness.require(Harness.Shared.Rules)
local Config = Harness.require(Harness.Shared.Config)
print("PassiveIncomeMultiplier",Config.PassiveIncomeMultiplier,"EggBaseValue",Config.EggBaseValue,"EggUnitValue0",Rules.EggUnitValue(0))
print("StarterLadder",Harness.serde.encode("json",Config.Economy.StarterLadder or {}), "Favored", Harness.serde.encode("json",Config.Economy.FavoredRolls or {}))
print("ChickenUpgradeRecruitFraction",Config.Economy.ChickenUpgradeRecruitFraction, "StarterRecruitPrice", Config.Economy.StarterRecruitPrice)
for _,id in {"Duck","Rooster","Pajama","Bonsai","Bee","Mallard","Sailor","Bucket","Viking","CampRoostWarden","CampRoostArcher","CampRoostRecruit","CampIronGrunt","CampIronSapper","CampIronMajor"} do
  local d=Catalog[id]
  if d then
    local s=Rules.Stats(id,1,1)
    local line=string.format("%-17s %-9s price %6s inc/s %.2f hp %.1f dmg %.1f int %.2f size %.2f splash %s | power L1..5:",id,tostring(d.rarity),tostring(d.price),Rules.Income(id,1,1,0),s.hp,s.damage,s.interval,s.size,tostring(s.splash))
    for L=1,5 do line..=string.format(" %.1f",Rules.PetPower(id,1,L)) end
    line..=" | feed:"
    for L=1,5 do line..=" "..tostring(Rules.ChickenUpgradePrice(id,L)) end
    print(line)
  else print("missing",id) end
end
print("KillCoins Bucket/Sailor/Mallard/Duck",Config.KillCoins.Bucket,Config.KillCoins.Sailor,Config.KillCoins.Mallard,Config.KillCoins.Duck)
print("Territories", Harness.serde.encode("json",Config.Territories))
