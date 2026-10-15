--!strict
local Config = require(script.Parent.Config)

local function basePrice(income: number): number
	return math.floor(income * Config.Economy.RecruitPaybackSeconds + 0.5)
end

-- Chicken variants share stable species IDs with existing saved profiles.
local Catalog = {
 Order={"Duck","Noob","Mallard","RubberDucky","Penguin","Cardboard","Chunky","Sailor","Cheesy","Camo","Bee","Cactus","Honeycomb","Lollipop","Bucket","Zombie","Tiger","Jungle","Bonsai","Viking","Skeleton","Pirate","Slime","Gentleman","Knight","Frost","Ninja","Wizard","Storm","Jockey","Toxic","Dragon","Diamond","SolarFlare","Water","Rainbow","IceDuck","Devil","Heavenly","StormDuck"},
 Duck={name="Chicken",rarity="Common",weight=28,price=basePrice(4),income=4,hp=42,damage=4,interval=1,color={255,250,231},size=2.25},
 Mallard={name="Brown Chicken",rarity="Common",weight=7,price=basePrice(8),income=8,hp=62,damage=6,interval=1,color={165,99,55},size=2.4},
 Chunky={name="Chunky Chicken",rarity="Uncommon",weight=4,price=basePrice(16),income=16,hp=88,damage=9,interval=0.9,color={255,250,231},size=2.5},
 Sailor={name="Mushroom Chicken",rarity="Uncommon",weight=4,price=basePrice(16),income=16,hp=88,damage=9,interval=0.9,color={236,42,52},size=2.5},
 Bucket={name="Robo-Cluck",rarity="Rare",weight=2.5,price=basePrice(28),income=28,hp=170,damage=10,interval=1.15,color={159,175,194},size=2.65},
 Viking={name="Crystal Chicken",rarity="Rare",weight=1.25,price=basePrice(56),income=56,hp=185,damage=18,interval=0.95,color={173,115,247},size=2.8},
 Knight={name="Magma Chicken",rarity="Epic",weight=0.5,price=basePrice(96),income=96,hp=280,damage=24,interval=1.05,color={255,107,24},size=2.95},
 Wizard={name="Shadow Stalker",rarity="Legendary",weight=0.5,price=basePrice(160),income=160,hp=240,damage=25,interval=1.1,color={47,44,64},size=3.05,splash=true},
 Dragon={name="Golden Emperor",rarity="Legendary",weight=0.2,price=basePrice(268),income=268,hp=580,damage=48,interval=1.3,color={255,204,44},size=3.5,splash=true},
 IceDuck={name="Glitch Chicken",baseSpecies="Wizard",rarity="Mythic",weight=0.02,price=basePrice(344),income=344,hp=750,damage=58,interval=1.1,color={56,255,135},size=3.15,splash=true},
 StormDuck={name="Galaxy Overlord",baseSpecies="Dragon",rarity="Mythic",weight=0.01,price=basePrice(480),income=480,hp=1150,damage=88,interval=1.15,color={124,95,249},size=3.5,splash=true},
}

-- New appearances share an established rarity/stat/price band. The combined
-- weight of each band stays unchanged at every Luck level. IDs remain distinct
-- for collection, saves and same-variant merging.
local function variant(id, base, name, weight, color)
 local definition = table.clone(Catalog[base])
 definition.name, definition.weight, definition.color = name, weight, color
 definition.economyBase = base
 Catalog[id] = definition
end
variant("Noob","Duck","Noob Chick",10,{255,215,40})
variant("RubberDucky","Mallard","Rubber Ducky",5,{255,224,30})
variant("Camo","Sailor","Camo Chick",3,{110,133,67})
variant("Jockey","Bucket","Chicken Jockey",0.35,{113,161,64})
variant("Cardboard","Bucket","Cardboard Commando",5,{181,132,77})
variant("Cactus","Bucket","Cactus Clucker",3,{79,181,73})
variant("Gentleman","Viking","Sir Clucks-a-Lot",0.75,{57,62,78})
variant("Slime","Viking","Slime Squawker",1,{116,255,44})
variant("Frost","Knight","Frost Feather",0.5,{113,218,255})
variant("Bonsai","Knight","Bonsai Bantam",1.25,{248,138,182})
variant("Diamond","Wizard","Diamond Defender",0.2,{99,230,255})
variant("Rainbow","Dragon","Rainbow Rider",0.25,{250,111,214})
variant("Storm","StormDuck","Storm Wing",0.35,{74,176,244})

-- September22 approved full-body skins. Each shares its established band;
-- excluded Watermelon/Graffiti never enter the playable catalog.
variant("Penguin","Mallard","Penguin Chicken",5,{38,47,64})
variant("Cheesy","Chunky","Cheesy Chicken",3,{255,182,40})
variant("Bee","Sailor","Bee Chicken",3,{255,222,35})
variant("Zombie","Bucket","Zombie Chicken",2,{127,165,77})
variant("Tiger","Bucket","Tiger Chicken",2,{255,143,35})
variant("Skeleton","Viking","Skeleton Chicken",1,{225,222,190})
variant("Pirate","Viking","Pirate Chicken",1,{212,43,58})
variant("Ninja","Knight","Ninja Chicken",0.5,{66,67,103})

-- September27 approved traits; each remains available in the normal roll pool.
variant("Lollipop","Mallard","Lollipop Chicken",1,{255,33,153})
variant("Honeycomb","Sailor","Honeycomb Chicken",1,{255,189,25})
variant("Jungle","Sailor","Jungle Chicken",1.25,{81,190,65})
variant("Toxic","Bucket","Toxic Chicken",0.3,{184,255,0})
variant("Water","Knight","Water Chicken",0.15,{7,203,245})
variant("Devil","Knight","Devil Chicken",0.015,{249,32,53})
variant("Heavenly","Wizard","Heavenly Chicken",0.015,{255,242,184})
variant("SolarFlare","Wizard","Solar Flare Chicken",0.15,{255,206,28})

-- October 15 roster expansion (docs/team/CHICKEN_ROSTER_EXPANSION.md): 79 new
-- appearances in the existing stat tiers, keyed by the original economy keys.
-- Weights are set after the October 7 remap below so each band keeps its total.
local RosterExpansion = {
 Duck={{"Hatchling","Hatchling",{255,236,140}},{"Silkie","Silkie",{246,244,240}},{"SpeckledHen","Speckled Hen",{60,60,66}},
  {"BaconHair","Bacon Hair Chick",{64,194,74}},{"Scarecrow","Scarecrow Chicken",{198,162,106}},{"Pajama","Pajama Chicken",{152,198,242}},
  {"Rooster","Rooster",{150,38,26}},{"Sheep","Sheep Chicken",{242,232,204}},{"Plushie","Plushie Chicken",{250,196,170}}},
 Mallard={{"CrateRunner","Crate Runner",{112,122,64}},{"Lumberjack","Lumberjack Chicken",{204,34,40}},{"Party","Party Chicken",{255,110,170}},
  {"Cow","Cow Chicken",{32,30,34}},{"Piggy","Piggy Chicken",{250,172,184}},{"Mailman","Mailman Chicken",{150,192,232}},
  {"Raincoat","Raincoat Chicken",{255,212,40}},{"Skater","Skater Chicken",{62,192,190}}},
 Chunky={{"Miner","Miner Chicken",{250,200,40}},{"Sushi","Sushi Chicken",{250,132,80}},{"Donut","Donut Chicken",{255,140,190}},
  {"Popcorn","Popcorn Chicken",{222,38,42}},{"Gamer","Gamer Chicken",{64,66,76}},{"Frog","Frog Chicken",{96,192,72}},
  {"Taco","Taco Chicken",{236,186,86}},{"Painter","Painter Chicken",{200,30,44}},{"Sunflower","Sunflower Chicken",{255,206,40}}},
 Bucket={{"Paratrooper","Paratrooper Chicken",{108,120,66}},{"Coral","Coral Reef Chicken",{255,122,124}},{"Firefighter","Firefighter Chicken",{214,34,36}},
  {"Chef","Chef Chicken",{250,250,248}},{"Detective","Detective Chicken",{192,160,108}},{"Mummy","Mummy Chicken",{236,228,204}},
  {"Snowman","Snowman Chicken",{226,234,246}},{"Police","Police Chicken",{34,46,92}},{"Doctor","Doctor Chicken",{62,172,172}}},
 Viking={{"CastleGuard","Castle Guard Chicken",{40,82,172}},{"Jester","Court Jester",{214,40,48}},{"Ironbeak","Ironbeak Chicken",{128,132,140}},
  {"Samurai","Samurai Chicken",{196,30,38}},{"Cowboy","Cowboy Chicken",{176,128,74}},{"Steampunk","Steampunk Scratcher",{210,164,70}},
  {"ZombieHunter","Zombie Hunter",{98,62,38}},{"Ghost","Ghost Chicken",{176,242,252}},{"Archer","Archer Chicken",{62,112,52}},
  {"Rockstar","Rockstar Chicken",{34,34,38}}},
 Knight={{"DeepseaDiver","Deepsea Diver",{198,150,64}},{"DragonHatchling","Dragon Hatchling",{228,88,40}},{"RoyalGuard","Royal Guard Chicken",{204,30,42}},
  {"Neon","Neon Chicken",{255,60,200}},{"NorseRaider","Norse Raider",{130,134,142}},{"Animatronic","Animatronic Chicken",{66,138,130}},
  {"Vampire","Vampire Chicken",{176,16,38}},{"Yeti","Yeti Chicken",{150,192,232}},{"Mimic","Mimic Chicken",{146,92,50}},
  {"Gladiator","Gladiator Chicken",{204,144,62}}},
 Wizard={{"Geode","Geode Chicken",{156,82,228}},{"AirshipCaptain","Airship Captain",{32,46,98}},{"Pharaoh","Pharaoh Chicken",{240,192,54}},
  {"StainedGlass","Stained Glass Chicken",{36,86,214}},{"Moon","Moon Chicken",{214,218,232}},{"Witch","Witch Chicken",{96,60,156}},
  {"Olympian","Olympian Chicken",{244,198,70}},{"Aurora","Aurora Chicken",{80,255,170}},{"Jade","Jade Chicken",{34,132,82}}},
 Dragon={{"Phoenix","Phoenix Chicken",{255,140,34}},{"Unicorn","Unicorn Chicken",{255,108,182}},{"Kraken","Kraken Chicken",{110,50,152}},
  {"DragonKnight","Dragon Knight",{138,22,34}},{"Griffin","Griffin Chicken",{226,156,56}},{"Valkyrie","Valkyrie Chicken",{52,92,182}}},
 IceDuck={{"TimeKeeper","Time Keeper",{24,92,98}},{"Mecha","Mecha Chicken",{220,40,52}},{"Kitsune","Kitsune Spirit",{214,34,44}},
  {"Eclipse","Eclipse Chicken",{255,176,56}},{"ForestGuardian","Forest Guardian",{84,140,52}}},
 StormDuck={{"FirstHen","The First Hen",{255,212,90}},{"RiftWalker","Rift Walker",{255,70,210}},{"Supernova","Supernova Chicken",{255,186,50}}},
}
local RosterExpansionOrder = {"Duck","Mallard","Chunky","Bucket","Viking","Knight","Wizard","Dragon","IceDuck","StormDuck"}
local rosterNew = {}
for _, key in RosterExpansionOrder do
 for _, entry in RosterExpansion[key] do
  variant(entry[1], key, entry[2], 0, entry[3])
  rosterNew[entry[1]] = key
  table.insert(Catalog.Order, entry[1])
 end
end
-- Seasonal limiteds in the Pumpkin pattern: zero roll weight, hidden from the Index
-- until owned or their event runs. No event is configured for them yet.
variant("Gingerbread","Knight","Gingerbread Chicken",0,{182,108,56})
Catalog.Gingerbread.limited = "Christmas2026"
Catalog.Gingerbread.limitedLabel = "Limited (Christmas 2026)"
variant("Firework","Wizard","Firework Chicken",0,{24,30,76})
Catalog.Firework.limited = "NewYear2027"
Catalog.Firework.limitedLabel = "Limited (New Year 2027)"
table.insert(Catalog.Order, "Gingerbread"); table.insert(Catalog.Order, "Firework")

-- Crate-only species remain in the persistent collection/index roster. A zero
-- normal-roll weight keeps every existing station probability unchanged.
variant("Astronaut","Knight","Astronaut Chicken",0,{99,180,255})
variant("Alien","Wizard","Alien Chicken",0,{164,238,37})
variant("DarkMatter","StormDuck","Dark Matter Chicken",0,{209,54,255})
variant("CosmicDragon","StormDuck","Cosmic Dragon",0,{103,155,255})
-- October 8: the rarest crate results out-hit a free Galaxy Overlord (76.5 DPS)
-- with the same HP: Dark Matter (9%) 101/1.15 = 87.8 DPS (+15%), Cosmic Dragon
-- (1%) 165/1.6 = 103.1 DPS (+35%). Income and crate odds are unchanged.
Catalog.DarkMatter.damage = 101
Catalog.CosmicDragon.damage = 165
Catalog.CosmicDragon.interval = 1.6
Catalog.CosmicDragon.attackWindup = 32/60
for _,id in {"Astronaut","Alien","DarkMatter","CosmicDragon"} do
 Catalog[id].crateExclusive = true
 table.insert(Catalog.Order,id)
end
-- October 10: earned only by winning Config.Hill.ChampionWins Hill rounds. A gold,
-- crowned classic Chicken (ChickenAssets.HillChampion) with Dark Matter's damage.
variant("HillChampion","StormDuck","Hill Champion",0,{255,196,48})
Catalog.HillChampion.damage = 101
Catalog.HillChampion.hillExclusive = true
table.insert(Catalog.Order,"HillChampion")
-- Launch H1 (docs/team/launch/15_H1_HALLOWEEN.md): the Halloween 2026 limited
-- chicken, in Magma Chicken's Epic band. Zero normal weight keeps every roll
-- probability unchanged; only EventService offers it while Config.Event runs.
-- Owned copies stay forever. baseSpecies picks the procedural fallback recipe
-- until the authored ChickenAssets.Pumpkin model exists.
variant("Pumpkin","Knight","Pumpkin Chicken",0,{255,140,26})
Catalog.Pumpkin.baseSpecies = "Knight"
Catalog.Pumpkin.limited = "Halloween2026"
Catalog.Pumpkin.limitedLabel = "Limited (Halloween 2026)"
table.insert(Catalog.Order,(table.find(Catalog.Order,"Toxic") or #Catalog.Order)+1,"Pumpkin") -- after the last Epic in the Index

-- October 7 rarity reset: rarer always means stronger, and the most desirable
-- appearances sit highest. The ten stat tiers keep their legacy economy keys
-- (prices, kill coins, saved investment). A species joins another tier by taking
-- that key's original stats; camp species keep their tiers. Owned copies follow.
local TierRarity = {Duck="Common",Mallard="Common",Chunky="Uncommon",Sailor="Uncommon",
 Bucket="Rare",Viking="Rare",Knight="Epic",Wizard="Legendary",Dragon="Legendary",
 IceDuck="Mythic",StormDuck="Mythic"}
local tierStats = {}
for key in TierRarity do
 local d = Catalog[key]
 tierStats[key] = {price=d.price,income=d.income,hp=d.hp,damage=d.damage,interval=d.interval,size=d.size,splash=d.splash}
end
for id, key in {Cardboard="Mallard",Lollipop="Chunky",Cactus="Chunky",Jungle="Bucket",Bonsai="Bucket",
 Wizard="Knight",Storm="Knight",Jockey="Knight",Toxic="Knight",Dragon="Wizard",Water="Wizard",
 Heavenly="IceDuck",Devil="IceDuck"} do
 local d, s = Catalog[id], tierStats[key]
 d.price,d.income,d.hp,d.damage,d.interval,d.size,d.splash = s.price,s.income,s.hp,s.damage,s.interval,s.size,s.splash
 d.economyBase = key
end
for _, id in Catalog.Order do
 Catalog[id].rarity = TierRarity[Catalog[id].economyBase or id]
end

-- October 15 roster expansion weights. Each Luck band keeps its total weight
-- (weights stay equal to Luck-0 percent odds): the new appearances share
-- RosterShare of the band and existing members keep their relative weights.
-- The basic Chicken stays locked at 28 so it still leads a fresh roll.
local RosterBand = {Duck=1,Mallard=2,Chunky=3,Sailor=3,Bucket=4,Viking=5,Knight=6,Wizard=7,Dragon=8,IceDuck=9,StormDuck=10}
local RosterShare = {[1]=0.7,[2]=0.4,[3]=0.4,[4]=0.45,[5]=0.5,[6]=0.45,[7]=0.45,[8]=0.6,[9]=0.45,[10]=0.45}
local RosterLocked = {Duck=true}
for band, share in RosterShare do
 local existing, fresh, free = {}, {}, 0
 for id, d in Catalog do
  if type(d) == "table" and d.name and (d.weight or 0) >= 0 and RosterBand[d.economyBase or id] == band then
   if rosterNew[id] then table.insert(fresh, id)
   elseif (d.weight or 0) > 0 and not RosterLocked[id] then table.insert(existing, id); free += d.weight end
  end
 end
 if #fresh > 0 and free > 0 then
  for _, id in existing do Catalog[id].weight *= (1 - share) end
  for _, id in fresh do Catalog[id].weight = free * share / #fresh end
 end
end
-- Index order: each new chicken follows the last chicken of its rarity.
for _, key in RosterExpansionOrder do
 for _, entry in RosterExpansion[key] do
  local id = entry[1]
  table.remove(Catalog.Order, table.find(Catalog.Order, id))
  local after = 0
  for i, other in Catalog.Order do
   if Catalog[other].rarity == Catalog[id].rarity then after = i end
  end
  table.insert(Catalog.Order, after + 1, id)
 end
end

return Catalog
