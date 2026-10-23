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

-- October 22 owner decision (docs/team/RARITY_REBALANCE_20261022.md): the roll pool
-- is narrowed to 78 chickens, one steady odds ladder like the Drop a Fruit Index. Every
-- chicken with effects stays (ten to a rarity); Stevin picked the eight plain ones that
-- stay. Each rarity lists its Luck bands, most common chicken first. A moved chicken
-- takes its new tier's original stats (the October 7 pattern); the 11 original tier
-- species never move. Inside a rarity each chicken is `step` times rarer than the one
-- before (October 23, below), and no chicken reads rarer than the next rarity's first.
-- Each rarity's share of rolls matches LuckBands. The basic Chicken keeps 28 (28% of rolls).
-- The value ladder (`valueSpan`, `valueTotal`, LuckBands `value`) is the morning's
-- 78-chicken ladder: it sets each chicken's price, income and power ("1 in X"), so
-- the later switch to reference-like chances changed how often, never what a chicken
-- is worth.
-- October 23 (Stevin, from the Drop a Fruit Index: "look at the 1 in values, theyre not
-- all close"): each rarity is now ONE odds ladder, every chicken `step` times rarer than
-- the one before it, across its Luck bands (they used to split fixed band totals, which
-- packed the Commons into 1 in 15-25). Each rarity's share of rolls is unchanged; the
-- band weights in LuckBands follow their members. Steps are the widest that keep every
-- rarity's rarest below the next rarity's first with a x1.1 gap and Mythic where it was:
-- Common 1 in 7-78, Uncommon 87-590, Rare 660-5,900, Epic 9,400-87,000, Legendary
-- 147,000-271,000. Mythic and Secret keep their ladders.
local RollPool = {
 {rarity="Common", step=1.24, valueSpan=1.57, bands={
  {key="Duck", total=47.5, valueTotal=38, ids={"Duck","Rooster","RubberDucky","Cardboard"}},
  {key="Mallard", total=45.4, valueTotal=22, ids={"Pajama","Party","Piggy","Gamer","Donut","Painter","Popcorn","Miner","Bonsai"}}}},
 {rarity="Uncommon", step=1.19, valueSpan=1.12, bands={
  {key="Chunky", total=6.32, valueTotal=22, ids={"Bee","Cow","ZombieHunter","Ironbeak","Detective","Mummy","Coral","CastleGuard","Snowman","Honeycomb","Jungle","Lollipop"}}}},
 {rarity="Rare", step=1.22, valueSpan=1.89, bands={
  {key="Bucket", total=0.48, valueTotal=9, ids={"Bucket","Neon","Gladiator","DeepseaDiver","Rockstar","Slime"}},
  {key="Viking", total=0.282, valueTotal=5, ids={"Viking","Ghost","Steampunk","Jester","Toxic","Frost"}}}},
 {rarity="Epic", step=1.25, valueSpan=2.83, bands={
  {key="Knight", total=0.0434, valueTotal=3, ids={"Knight","Jockey","Aurora","AirshipCaptain","Mimic","Animatronic","Vampire","Yeti","DragonHatchling","Wizard","Storm"}}}},
 {rarity="Legendary", step=1.07, valueSpan=2.78, bands={
  {key="Wizard", total=0.0033, valueTotal=0.7, ids={"Dragon","Witch","Jade","StainedGlass","Geode","Pharaoh"}},
  {key="Dragon", total=0.0018, valueTotal=0.25, ids={"Rainbow","Diamond","Water","SolarFlare"}}}},
 {rarity="Mythic", step=6.15 ^ (1 / 9), valueSpan=4, bands={
  {key="IceDuck", total=0.0003, valueTotal=0.05, ids={"IceDuck","Griffin","DragonKnight","Kraken","Unicorn","Moon","Olympian","Valkyrie","Phoenix","Devil"}}}},
 {rarity="Secret", step=7.37 ^ (1 / 9), valueSpan=4, bands={
  {key="StormDuck", total=0.00147, valueTotal=0.01, ids={"FirstHen","StormDuck","ForestGuardian","TimeKeeper","Eclipse","Kitsune","Mecha","Heavenly","Supernova","RiftWalker"}}}},
}
Catalog.RollPool = RollPool
-- Out of the roll pool (weight 0) but kept for saves: owned copies keep these level-1
-- stats from before the change, and the Index shows them only once found. Mallard,
-- Chunky and Sailor still lead camps, the King and Missions.
local RetiredFromRolls: {[string]: {rarity: string, income: number, hp: number, damage: number, price: number}} = {
 Noob={rarity="Common",income=6,hp=51,damage=5,price=600},
 Mallard={rarity="Common",income=8,hp=62,damage=6,price=1800},
 Penguin={rarity="Common",income=9,hp=66,damage=6,price=2000},
 Chunky={rarity="Uncommon",income=16,hp=88,damage=9,price=3000},
 Sailor={rarity="Uncommon",income=16,hp=88,damage=9,price=3000},
 Cheesy={rarity="Uncommon",income=17,hp=91,damage=9,price=3500},
 Camo={rarity="Uncommon",income=17,hp=91,damage=9,price=3500},
 Cactus={rarity="Uncommon",income=17,hp=91,damage=9,price=3500},
 Zombie={rarity="Rare",income=29,hp=173,damage=10,price=9000},
 Tiger={rarity="Rare",income=29,hp=173,damage=10,price=9000},
 Skeleton={rarity="Rare",income=59,hp=190,damage=18,price=16000},
 Pirate={rarity="Rare",income=59,hp=190,damage=18,price=16000},
 Gentleman={rarity="Rare",income=62,hp=195,damage=19,price=19000},
 Ninja={rarity="Epic",income=96,hp=280,damage=24,price=57600},
 Hatchling={rarity="Common",income=8,hp=59,damage=6,price=2500},
 Silkie={rarity="Common",income=8,hp=59,damage=6,price=2500},
 SpeckledHen={rarity="Common",income=8,hp=59,damage=6,price=2500},
 BaconHair={rarity="Common",income=8,hp=59,damage=6,price=2500},
 Scarecrow={rarity="Common",income=8,hp=59,damage=6,price=2500},
 Sheep={rarity="Common",income=8,hp=59,damage=6,price=2500},
 Plushie={rarity="Common",income=8,hp=59,damage=6,price=2500},
 CrateRunner={rarity="Common",income=10,hp=69,damage=7,price=2200},
 Lumberjack={rarity="Common",income=10,hp=69,damage=7,price=2200},
 Mailman={rarity="Common",income=10,hp=69,damage=7,price=2200},
 Raincoat={rarity="Common",income=10,hp=69,damage=7,price=2200},
 Skater={rarity="Common",income=10,hp=69,damage=7,price=2200},
 Sushi={rarity="Uncommon",income=19,hp=96,damage=10,price=4500},
 Frog={rarity="Uncommon",income=19,hp=96,damage=10,price=4500},
 Taco={rarity="Uncommon",income=19,hp=96,damage=10,price=4500},
 Sunflower={rarity="Uncommon",income=19,hp=96,damage=10,price=4500},
 Paratrooper={rarity="Rare",income=35,hp=190,damage=11,price=17000},
 Firefighter={rarity="Rare",income=35,hp=190,damage=11,price=17000},
 Chef={rarity="Rare",income=35,hp=190,damage=11,price=17000},
 Police={rarity="Rare",income=35,hp=190,damage=11,price=17000},
 Doctor={rarity="Rare",income=35,hp=190,damage=11,price=17000},
 Samurai={rarity="Rare",income=67,hp=202,damage=20,price=25000},
 Cowboy={rarity="Rare",income=67,hp=202,damage=20,price=25000},
 Archer={rarity="Rare",income=67,hp=202,damage=20,price=25000},
 RoyalGuard={rarity="Epic",income=111,hp=301,damage=26,price=74460},
 NorseRaider={rarity="Epic",income=111,hp=301,damage=26,price=74460},
}
Catalog.RetiredFromRolls = RetiredFromRolls
do
 local AnchorWeight = {Duck=28}
 -- Ladder weights for one rarity: each member a steady step rarer, a band's members
 -- sharing its total (less the anchored Chicken).
 local function ladder(group, span: number, totalKey: string)
  local count = 0
  for _, band in group.bands do for _, id in band.ids do if not AnchorWeight[id] then count += 1 end end end
  local step, rank, result = span ^ (-1 / math.max(1, count - 1)), 0, {}
  for _, band in group.bands do
   local weights, sum, free = {}, 0, band[totalKey]
   for i, id in band.ids do
    if AnchorWeight[id] then weights[i] = 0; free -= AnchorWeight[id]
    else weights[i] = step ^ rank; rank += 1 end
    sum += weights[i]
   end
   for i, id in band.ids do result[id] = AnchorWeight[id] or free * weights[i] / sum end
  end
  return result
 end
 -- October 23: the real odds are one ladder over the whole rarity (its band totals
 -- summed), each member `step` times rarer than the one before.
 local function rarityLadder(group)
  local free, members = 0, {}
  for _, band in group.bands do
   free += band.total
   for _, id in band.ids do
    if AnchorWeight[id] then free -= AnchorWeight[id] else table.insert(members, id) end
   end
  end
  local step: number, sum, result = group.step, 0, {}
  for rank = 0, #members - 1 do sum += step ^ -rank end
  for rank, id in members do result[id] = free * step ^ -(rank - 1) / sum end
  for _, band in group.bands do
   for _, id in band.ids do result[id] = AnchorWeight[id] or result[id] end
  end
  return result
 end
 for _, group in RollPool do
  local weights, values = rarityLadder(group), ladder(group, group.valueSpan, "valueTotal")
  for _, band in group.bands do
   local s = tierStats[band.key]
   for _, id in band.ids do
    local d = Catalog[id] :: any
    if not TierRarity[id] and d.economyBase ~= band.key then
     d.price,d.income,d.hp,d.damage,d.interval,d.size,d.splash = s.price,s.income,s.hp,s.damage,s.interval,s.size,s.splash
     d.economyBase = band.key
    end
    d.rarity = group.rarity
    d.weight, d.valueWeight = weights[id], values[id]
   end
  end
 end
 for id in RetiredFromRolls do
  local d = Catalog[id] :: any
  d.weight, d.vaulted = 0, true
 end
end

-- October 21 owner decision: the October 20 "Veteran Corps" Rebirth chickens are
-- retired. They had no voxel model and showed as the old round part chicken; every
-- chicken in the game is a voxel model. RebirthOrder stays empty, so Rebirth grants
-- and podium swaps stop. A saved Veteran loads as the chicken whose exact stats it
-- copied (PlayerSession), e.g. Veteran3 "Sergeant Scratch" becomes a Robo-Cluck.
Catalog.RebirthOrder = table.freeze({})
-- October 22 (Stevin): a Rebirth is earned by FINDING a chicken, not paid with one.
-- Ranks 1..Config.Rebirth.FindRanks each name the chicken that must be in the Index
-- (owned once; selling it later does not matter) before that Rebirth; later ranks need
-- only the Coins. Rarer every rank, picked from the discovery probe so a player who
-- rolls has seen it before the Coins are there (docs/team/REBIRTH_SCREEN.md "Rebirth
-- finds"): Rare, Epic, Legendary, Mythic, then the Secret First Hen at 15.
-- October 22 roll pool: every find is a chicken with effects (they always stay in the
-- roll pool). With the reference-like chances (mostly Commons, gentle Luck) a find rarer
-- than about 1 in 25,000 kept simulated players waiting hours with the Coins in hand (The
-- First Hen 3-26 h, Storm Wing 1-5 h), so the ladder runs Uncommon (1-4), Rare (5-11) and
-- the four easiest Epics (12-15, up to Mimic at 1 in 25,000).
Catalog.RebirthFinds = table.freeze({"Ironbeak", "Detective", "Snowman", "Jungle", "Bucket", "Gladiator", "DeepseaDiver",
	"Rockstar", "Ghost", "Jester", "Frost", "Knight", "Aurora", "AirshipCaptain", "Mimic"})
local retired = {}
for rank, species in {"Chunky","Chunky","Bucket","Bucket","Viking","Viking","Knight","Knight","Knight",
 "Dragon","Dragon","Dragon","Rainbow","Rainbow","Rainbow","IceDuck","IceDuck","IceDuck","IceDuck"} do
 retired["Veteran" .. rank] = species
end
for rank = 20, 30 do retired["Veteran" .. rank] = "StormDuck" end
Catalog.RetiredSpecies = table.freeze(retired)

-- October 15 owner request: each mission territory has its own Loyalist guards
-- (docs/team/LOYALIST_GUARDS.md). They are enemy only: never in Order, so they are
-- never rolled, offered, owned or shown in the Index. Each copies the final stats of
-- the chicken it replaced in OperationCatalog, so every fight keeps its strength.
Catalog.Loyalists = {
 {"LoyalCrateScout","Crate Scout","Bucket",{206,168,112}},
 {"LoyalSpyglassScout","Spyglass Scout","Viking",{176,30,44}},
 {"LoyalDropTrooper","Drop Trooper","Bucket",{118,124,134}},
 {"LoyalAnvilBrute","Anvil Brute","Knight",{96,96,104}},
 {"LoyalSergeant","Veteran Sergeant","Knight",{176,30,44}},
 {"LoyalLancer","Assault Lancer","Viking",{158,164,172}},
 {"LoyalMortarHen","Mortar Hen","Wizard",{190,112,58}},
 {"LoyalShadowBulwark","Shadow Bulwark","Bucket",{46,50,70}},
 {"LoyalShadowGunner","Shadow Gunner","Wizard",{84,86,104}},
 {"LoyalNightCaptain","Night Captain","Knight",{34,40,76}},
 {"LoyalFleetMarine","Fleet Marine","Knight",{40,70,140}},
 {"LoyalDeckRaider","Deck Raider","Viking",{236,236,236}},
 {"LoyalFrostGunner","Frost Gunner","IceDuck",{176,222,246}},
 {"LoyalHonorGuard","Honor Guard","Knight",{72,44,70}},
 {"LoyalEmberAdept","Ember Adept","Wizard",{70,34,70}},
 {"LoyalDragonCommander","Dragon Commander","Dragon",{176,30,44}},
 {"LoyalVanguardPaladin","Vanguard Paladin","Knight",{244,236,214}},
 {"LoyalGlacierLancer","Glacier Lancer","IceDuck",{206,232,248}},
 {"LoyalDrakeKnight","Crimson Drake Knight","Dragon",{176,30,44}},
 {"LoyalShieldbearer","Crown Shieldbearer","IceDuck",{226,222,210}},
 {"LoyalRoyalWarden","Royal Warden","Dragon",{80,50,46}},
 {"LoyalStormHerald","Storm Herald","StormDuck",{40,70,170}},
 {"LoyalFrostGuard","King's Frost Guard","IceDuck",{150,220,255}},
 {"LoyalFlameGuard","King's Flame Guard","Dragon",{255,120,40}},
 {"LoyalThunderGuard","King's Thunder Guard","StormDuck",{255,226,70}},
 {"LoyalArmadaKing","Armada King","Duck",{236,186,58}},
}
for _, entry in Catalog.Loyalists do
 local definition = table.clone(Catalog[entry[3]])
 definition.name, definition.weight, definition.color = entry[2], 0, entry[4]
 definition.economyBase = definition.economyBase or entry[3]
 definition.baseSpecies = definition.baseSpecies or entry[3]
 definition.enemyOnly = true
 Catalog[entry[1]] = definition
end

-- October 15 owner decision: "1 in X" rarity (docs/team/ONE_IN_X_RARITY.md).
-- Luck's strength bands live here so the catalog can compute each chicken's
-- zero-Luck odds; ChickenLuck reads the same table. Bands are matched by each
-- chicken's tier stats (luckSignature, recorded before the rarity premium).
-- October 22 (Stevin: "I want my chances to be similar to that other game… it was
-- mostly common"): the weights match the Drop a Fruit Index at zero Luck. Common 93%
-- (the basic Chicken 28%), Uncommon 6.3%, Rare 0.76%, Epic 0.043%, Legendary 0.005%,
-- Mythic 0.0016%, Secret 0.0002%. They were 60 / 22 / 14 / 3 / 0.95 / 0.06 / 0.0015;
-- `value` keeps those old budgets for each chicken's price, income and power.
Catalog.LuckBands = {
	{species="Duck", weight=47.5, value=38}, {species="Mallard", weight=45.4, value=22},
	{species="Chunky", weight=6.32, value=22}, {species="Bucket", weight=0.48, value=9},
	{species="Viking", weight=0.282, value=5}, {species="Knight", weight=0.0434, value=3},
	{species="Dragon", weight=0.0033, value=0.7}, {species="Rainbow", weight=0.0018, value=0.25},
	{species="IceDuck", weight=0.0003, value=0.05}, {species="StormDuck", weight=0.00147, value=0.01},
}
-- October 14 owner retune: only this share of the strongest band's odds stays.
Catalog.LuckTopBandKeep = 0.15
function Catalog.LuckSignature(definition): string
	return definition.luckSignature or table.concat({definition.income, definition.hp, definition.damage,
		definition.interval, definition.attackWindup or Config.AttackWindupSeconds,
		if definition.splash then 1 else 0}, ":")
end
for _, definition in Catalog do
	if type(definition) == "table" and definition.name then definition.luckSignature = Catalog.LuckSignature(definition) end
end
-- October 23: a band's weight is its members' weights (the RollPool rarity ladders), so
-- the numbers above are only the starting split; each rarity's total is unchanged.
do
	local bandOf = {}
	for index, band in Catalog.LuckBands do bandOf[Catalog[band.species].luckSignature] = index end
	local sums = {}
	for _, id in Catalog.Order do
		local definition = Catalog[id] :: any
		local index = definition.weight > 0 and not definition.crateExclusive and bandOf[definition.luckSignature]
		if index then sums[index] = (sums[index] or 0) + definition.weight end
	end
	for index, band in Catalog.LuckBands do
		if sums[index] then band.weight = sums[index] end
	end
end
do
	-- Zero-Luck odds: each band keeps its weight share, the top band hands most of
	-- its share to the band below, and members split their band by weight. `oneIn` is
	-- the real chance (rolls, Index, podium tags); `valueOneIn` prices the chicken.
	local function odds(budgetKey: string, weightKey: string, resultKey: string)
		local bandOf, bandChance, members, total = {}, {}, {}, 0
		for index, band in Catalog.LuckBands do
			bandOf[Catalog[band.species].luckSignature] = index
			total += band[budgetKey]
		end
		for index, band in Catalog.LuckBands do bandChance[index] = band[budgetKey] / total end
		local top = #Catalog.LuckBands
		bandChance[top - 1] += bandChance[top] * (1 - Catalog.LuckTopBandKeep)
		bandChance[top] *= Catalog.LuckTopBandKeep
		local function rollable(definition) return definition.weight > 0 and not definition.crateExclusive end
		for _, id in Catalog.Order do
			local definition, band = Catalog[id] :: any, nil
			if rollable(definition) then band = bandOf[definition.luckSignature] end
			if band then members[band] = (members[band] or 0) + definition[weightKey] end
		end
		for _, id in Catalog.Order do
			local definition = Catalog[id] :: any
			local band = rollable(definition) and bandOf[definition.luckSignature]
			if band then definition[resultKey] = 1 / (bandChance[band] * definition[weightKey] / members[band]) end
		end
	end
	odds("weight", "weight", "oneIn")
	odds("value", "valueWeight", "valueOneIn")
end

-- Rarer always means better, and rarity sets the price. R is a chicken's odds
-- relative to the basic Chicken (1 in ~3.6); r is relative to its stat tier's most
-- common member. Income = max(tier income x r^0.2, 4 x R^0.5; Common/Uncommon use
-- only the first term): never below today's
-- tier value, so no owned chicken is weakened. HP and damage follow the income gain
-- gently (square root, at most x2). Price = max(600 s of income, 2,400 x
-- R^(0.25 + 0.17 log10 R)): commons stay near their old prices, and the curve
-- steepens until a 1-in-121,000 Galaxy Overlord costs ~$100M at level 1. The rarest
-- chickens (1 in SecretOneIn or rarer) are Secret, with x SecretPricePremium on top.
-- The 11 original tier species keep their exact stats, because camps, the King and
-- invasions are built from them; only their price follows the curve.
-- October 22: these use each chicken's value odds (`valueOneIn`), so prices, income and
-- power did not move when the real chances became reference-like.
Catalog.SecretOneIn = 200000
Catalog.SecretPricePremium = 5
local ProtectedStats = {Duck=true,Mallard=true,Chunky=true,Sailor=true,Bucket=true,Viking=true,
	Knight=true,Wizard=true,Dragon=true,IceDuck=true,StormDuck=true}
function Catalog.RarityPrice(oneIn: number, income: number): number
	local relative = math.max(1, oneIn / (Catalog.Duck :: any).valueOneIn)
	local curve = 2400 * relative ^ (0.25 + 0.17 * math.log10(relative))
	local price = math.max(basePrice(income), curve) * (if oneIn >= Catalog.SecretOneIn then Catalog.SecretPricePremium else 1)
	return math.floor(price + 0.5)
end
do
	local floor = {}
	for _, id in Catalog.Order do
		local definition = Catalog[id] :: any
		if definition.valueOneIn then
			local key = definition.economyBase or id
			floor[key] = math.min(floor[key] or math.huge, definition.valueOneIn)
		end
	end
	for _, id in Catalog.Order do
		local definition = Catalog[id] :: any
		local valueOneIn = definition.valueOneIn
		if not valueOneIn then continue end
		if not ProtectedStats[id] then
			local relative = math.max(1, valueOneIn / (Catalog.Duck :: any).valueOneIn)
			local tierRatio = math.max(1, valueOneIn / floor[definition.economyBase or id])
			-- October 15 owner playtest: Common/Uncommon prices are now very low (EarlyPrices),
			-- so they keep only the within-tier bonus; the game-wide curve made cheap
			-- commons snowball (simulated 30-minute income 47x the old pace).
			local early = definition.rarity == "Common" or definition.rarity == "Uncommon"
			local income = math.max(definition.income * tierRatio ^ 0.2, if early then 0 else 4 * relative ^ 0.5)
			income = math.floor(income + 0.5)
			local strength = math.min(2, (income / definition.income) ^ 0.5)
			definition.income = income
			definition.hp = math.floor(definition.hp * strength + 0.5)
			definition.damage = math.floor(definition.damage * strength + 0.5)
		end
		definition.price = Catalog.RarityPrice(valueOneIn, definition.income)
		if valueOneIn >= Catalog.SecretOneIn then definition.rarity = "Secret" end
	end
end

-- October 15 owner playtest ("the first 10 minutes must be very easy"): Common,
-- Uncommon and Rare chickens use this level-1 price schedule instead of the rarity
-- curve, so a new player's ~$2,000 buys a real choice of chickens. Income and stats
-- are unchanged (cheaper chickens just pay back faster). Points are {odds, price};
-- prices between points are interpolated on log odds and rounded to $100.
Catalog.EarlyPrices = {
	Common = {{3.57, 600}, {23.8, 1800}, {33.3, 2000}, {90.9, 2200}, {128.6, 2500}},
	Uncommon = {{41.7, 3000}, {55.6, 3500}, {102.3, 4500}, {166.7, 6000}},
	Rare = {{72.7, 8000}, {90.9, 9000}, {145.5, 11000}, {160, 14000}, {200, 16000},
		{222.2, 17000}, {266.7, 19000}, {400, 25000}},
}
Catalog.EarlyPriceOverrides = {Noob = 600}
function Catalog.EarlyPrice(oneIn: number, rarity: string): number?
	local points = Catalog.EarlyPrices[rarity]
	if not points then return nil end
	if oneIn <= points[1][1] then return points[1][2] end
	for index = 2, #points do
		local low, high = points[index - 1], points[index]
		if oneIn <= high[1] then
			local t = math.log(oneIn / low[1]) / math.log(high[1] / low[1])
			return math.floor((low[2] + (high[2] - low[2]) * t) / 100 + 0.5) * 100
		end
	end
	return points[#points][2]
end
for _, id in Catalog.Order do
	local definition = Catalog[id] :: any
	local early = definition.valueOneIn and (Catalog.EarlyPriceOverrides[id] or Catalog.EarlyPrice(definition.valueOneIn, definition.rarity))
	if early then definition.price = early end
end

for id, stats in RetiredFromRolls do
	local definition = Catalog[id] :: any
	definition.rarity, definition.income, definition.hp, definition.damage, definition.price =
		stats.rarity, stats.income, stats.hp, stats.damage, stats.price
end

-- October 23 (Stevin: "the common chickens are all the same value"): along the roll
-- pool, most common to rarest, every chicken lays more Coins and costs more than the one
-- before it, in whole numbers. Income rises by at least 1 Coin a second and the price by
-- at least one step in its second digit (1,900 -> 2,000, 57,600 -> 58,600); nothing earns
-- or costs less than before. This includes the original tier species' income (enemies use
-- only hp, damage and timing, which stay exact).
do
	local income, price = 0, 0
	for _, group in RollPool do
		for _, band in group.bands do
			for _, id in band.ids do
				local definition = Catalog[id] :: any
				definition.income = math.max(math.floor(definition.income + 0.5), income + 1)
				local step = 10 ^ math.max(0, math.floor(math.log10(math.max(price, 1))) - 1)
				definition.price = math.max(math.floor(definition.price + 0.5), price + step)
				income, price = definition.income, definition.price
			end
		end
	end
end

-- October 22 rebalance: the Index lists each rarity from most common to rarest, then
-- that rarity's retired, limited, crate and Hill chickens.
do
	local rank = {Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5, Mythic=6, Secret=7}
	local position = {}
	for index, id in Catalog.Order do position[id] = index end
	table.sort(Catalog.Order, function(a, b)
		local da, db = Catalog[a] :: any, Catalog[b] :: any
		local ra, rb = rank[da.rarity] or 8, rank[db.rarity] or 8
		if ra ~= rb then return ra < rb end
		if (da.oneIn ~= nil) ~= (db.oneIn ~= nil) then return da.oneIn ~= nil end
		if da.oneIn and db.oneIn and da.oneIn ~= db.oneIn then return da.oneIn < db.oneIn end
		return position[a] < position[b]
	end)
end

-- "1 in 4", "1 in 129", "1 in 2,900", "1 in 444,500": three significant figures.
function Catalog.OneInText(species: string): string?
	local definition = Catalog[species]
	local value = definition and definition.oneIn
	if not value then return nil end
	local rounded = if value < 1000 then math.floor(value + 0.5)
		else (function()
			local step = 10 ^ (math.floor(math.log10(value)) - 2)
			return math.floor(value / step + 0.5) * step
		end)()
	local digits = tostring(math.max(2, rounded)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "1 in " .. digits
end

return Catalog
