--!strict
local Config = require(script.Parent.Config)

local function basePrice(income: number): number
	return math.floor(income * Config.Economy.RecruitPaybackSeconds + 0.5)
end

-- Chicken variants share stable species IDs with existing saved profiles.
local Catalog = {
 Order={"Duck","Noob","Mallard","RubberDucky","Chunky","Sailor","Camo","Bucket","Jockey","Cardboard","Cactus","Viking","Gentleman","Slime","Knight","Frost","Bonsai","Wizard","Diamond","Dragon","Rainbow","IceDuck","StormDuck","Storm"},
 Duck={name="Chicken",rarity="Common",weight=16,price=basePrice(4),income=4,hp=42,damage=4,interval=1,color={255,250,231},size=2.25},
 Mallard={name="Brown Chicken",rarity="Common",weight=12,price=basePrice(8),income=8,hp=62,damage=6,interval=1,color={165,99,55},size=2.4},
 Chunky={name="Chunky Chicken",rarity="Uncommon",weight=8,price=basePrice(16),income=16,hp=88,damage=9,interval=0.9,color={255,250,231},size=2.5},
 Sailor={name="Mushroom Chicken",rarity="Uncommon",weight=6,price=basePrice(16),income=16,hp=88,damage=9,interval=0.9,color={236,42,52},size=2.5},
 Bucket={name="Robo-Cluck",rarity="Rare",weight=6,price=basePrice(28),income=28,hp=170,damage=10,interval=1.15,color={159,175,194},size=2.65},
 Viking={name="Crystal Chicken",rarity="Rare",weight=4,price=basePrice(56),income=56,hp=185,damage=18,interval=0.95,color={173,115,247},size=2.8},
 Knight={name="Magma Chicken",rarity="Epic",weight=2,price=basePrice(96),income=96,hp=280,damage=24,interval=1.05,color={255,107,24},size=2.95},
 Wizard={name="Shadow Stalker",rarity="Legendary",weight=0.65,price=basePrice(160),income=160,hp=240,damage=25,interval=1.1,color={47,44,64},size=3.05,splash=true},
 Dragon={name="Golden Emperor",rarity="Mythic",weight=0.125,price=basePrice(268),income=268,hp=580,damage=48,interval=1.3,color={255,204,44},size=3.5,splash=true},
 IceDuck={name="Glitch Chicken",baseSpecies="Wizard",rarity="Legendary",weight=0.15,price=basePrice(344),income=344,hp=750,damage=58,interval=1.1,color={56,255,135},size=3.15,splash=true},
 StormDuck={name="Galaxy Overlord",baseSpecies="Dragon",rarity="Mythic",weight=0.025,price=basePrice(480),income=480,hp=1150,damage=88,interval=1.15,color={124,95,249},size=3.5,splash=true},
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
variant("RubberDucky","Mallard","Rubber Ducky",12,{255,224,30})
variant("Camo","Sailor","Camo Chick",6,{110,133,67})
variant("Jockey","Bucket","Chicken Jockey",3,{113,161,64})
variant("Cardboard","Bucket","Cardboard Commando",3,{181,132,77})
variant("Cactus","Bucket","Cactus Clucker",3,{79,181,73})
variant("Gentleman","Viking","Sir Clucks-a-Lot",2,{57,62,78})
variant("Slime","Viking","Slime Squawker",3,{116,255,44})
variant("Frost","Knight","Frost Feather",1.25,{113,218,255})
variant("Bonsai","Knight","Bonsai Bantam",1.25,{248,138,182})
variant("Diamond","Wizard","Diamond Defender",0.6,{99,230,255})
variant("Rainbow","Dragon","Rainbow Rider",0.125,{250,111,214})
variant("Storm","StormDuck","Storm Wing",0.025,{74,176,244})

return Catalog
