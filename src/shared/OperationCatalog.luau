--!strict
-- Authored encounters: no player-power or wallet scaling.
local Rules=require(script.Parent.Rules)
local Catalog={}
Catalog.Tiers={"Veteran","Elite","Royal"}
Catalog.Colors={Color3.fromRGB(0,197,255),Color3.fromRGB(181,81,255),Color3.fromRGB(255,196,34)}
Catalog.Order={"1:1","1:2","1:3","2:1","2:2","2:3","3:1","3:2","3:3"}
Catalog.Encounters={
	["1:1"]={name="Veteran Patrol",tier=1,description="A balanced patrol. Break its front line.",firstCash=150000,replayCash=15000,groups={{"Bucket",3,4},{"Viking",3,4}}},
	["1:2"]={name="Iron Roost",tier=1,description="Durable defenders protect a heavy hitter.",firstCash=250000,replayCash=25000,groups={{"Bucket",4,6},{"Knight",3,2}}},
	["1:3"]={name="Veteran Command",tier=1,description="A mixed formation with splash support.",firstCash=500000,replayCash=50000,groups={{"Knight",4,4},{"Viking",4,4},{"Wizard",3,2}}},
	["2:1"]={name="Shadow Battery",tier=2,description="Splash attackers behind an armored screen.",firstCash=1000000,replayCash=100000,groups={{"Bucket",6,4},{"Wizard",5,4},{"Knight",5,2}}},
	["2:2"]={name="Last Line",tier=2,description="Survive a larger formation of veteran fighters.",firstCash=2000000,replayCash=200000,groups={{"Knight",6,6},{"Viking",6,4},{"IceDuck",4,2}}},
	["2:3"]={name="Elite Commander",tier=2,description="Defeat the commander and its honor guard.",firstCash=5000000,replayCash=500000,groups={{"Knight",6,4},{"Wizard",6,3}},boss={species="Dragon",hp=26000,damage=320,interval=1.6,splash=true}},
	["3:1"]={name="Royal Vanguard",tier=3,description="Elite guards with relentless splash support.",firstCash=10000000,replayCash=1000000,groups={{"Knight",8,5},{"IceDuck",7,4},{"Dragon",7,2}}},
	["3:2"]={name="Crown's Shield",tier=3,description="A royal army built to outlast your strongest flock.",firstCash=20000000,replayCash=2000000,groups={{"IceDuck",8,5},{"Dragon",8,4},{"StormDuck",7,2}}},
	["3:3"]={name="Royal Chicken King",tier=3,description="The final commander and its Royal Guard.",firstCash=50000000,replayCash=5000000,groups={{"IceDuck",9,4},{"Dragon",9,3},{"StormDuck",8,2}},boss={species="Duck",hp=120000,damage=1400,interval=1.8,splash=true}},
}

function Catalog.Roster(id)
	local definition=Catalog.Encounters[id];if not definition then return nil end
	local roster={}
	if definition.boss then
		local boss=definition.boss
		table.insert(roster,{species=boss.species,stars=1,level=1,boss=true,noRespawn=true,
			combatStats={hp=boss.hp,damage=boss.damage,interval=boss.interval,size=3.8,splash=boss.splash}})
	end
	for _,group in definition.groups do
		for _=1,group[3] do table.insert(roster,{species=group[1],stars=1,level=group[2],noRespawn=true}) end
	end
	for i,pet in roster do pet.slot=i end
	return roster
end

function Catalog.Power(id)
	local power=0
	for _,pet in Catalog.Roster(id) or {} do
		local stats=pet.combatStats or Rules.Stats(pet.species,pet.stars,pet.level)
		power+=math.sqrt(stats.hp*stats.damage/stats.interval)
	end
	return math.floor(power)
end

function Catalog.BannerTier(wins)
	local tier=0
	for t=1,3 do if wins[t..":1"] and wins[t..":2"] and wins[t..":3"] then tier=t end end
	return tier
end

return Catalog
