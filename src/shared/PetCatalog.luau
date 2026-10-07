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

-- Crate-only species remain in the persistent collection/index roster. A zero
-- normal-roll weight keeps every existing station probability unchanged.
variant("Astronaut","Knight","Astronaut Chicken",0,{99,180,255})
variant("Alien","Wizard","Alien Chicken",0,{164,238,37})
variant("DarkMatter","StormDuck","Dark Matter Chicken",0,{209,54,255})
variant("CosmicDragon","StormDuck","Cosmic Dragon",0,{103,155,255})
Catalog.CosmicDragon.damage = 122
Catalog.CosmicDragon.interval = 1.6
Catalog.CosmicDragon.attackWindup = 32/60
for _,id in {"Astronaut","Alien","DarkMatter","CosmicDragon"} do
 Catalog[id].crateExclusive = true
 table.insert(Catalog.Order,id)
end

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

return Catalog
