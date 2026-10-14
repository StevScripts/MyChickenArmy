--!strict
-- Authored encounters: no player-power or wallet scaling.
local Rules=require(script.Parent.Rules)
local Catalog={}
Catalog.Tiers={"Veteran","Elite","Royal"}
Catalog.Colors={Color3.fromRGB(0,197,255),Color3.fromRGB(181,81,255),Color3.fromRGB(255,196,34)}
Catalog.Order={"1:1","1:2","1:3","2:1","2:2","2:3","3:1","3:2","3:3"}
-- October 8 retune: each tier's three first clears pay about the next tier's
-- research unlock (S16 $25M, S17 $250M); replays stay 10%. The Royal King
-- (80K HP, 900 splash) is beatable by ten free level-10 Galaxy Overlords with
-- full combat research and stays the hardest fight (needs level 9+).
Catalog.Encounters={
	["1:1"]={name="Scout Landing",tier=1,description="A loyalist scout party drops in. Break its front line.",firstCash=2500000,replayCash=250000,groups={{"Bucket",3,4},{"Viking",3,4}}},
	["1:2"]={name="Iron Drop",tier=1,description="Armored loyalists land around a heavy hitter.",firstCash=7500000,replayCash=750000,groups={{"Bucket",4,6},{"Knight",3,2}}},
	["1:3"]={name="Veteran Assault",tier=1,description="A full loyalist squad with splash support.",firstCash=15000000,replayCash=1500000,groups={{"Knight",4,4},{"Viking",4,4},{"Wizard",3,2}}},
	["2:1"]={name="Shadow Battery",tier=2,description="Splash gunners drop behind an armored screen.",firstCash=25000000,replayCash=2500000,groups={{"Bucket",6,4},{"Wizard",5,4},{"Knight",5,2}}},
	["2:2"]={name="Iron Fleet",tier=2,description="A larger loyalist wave of veteran fighters.",firstCash=75000000,replayCash=7500000,groups={{"Knight",6,6},{"Viking",6,4},{"IceDuck",4,2}}},
	["2:3"]={name="Dragon Commander",tier=2,description="The loyalist commander rides in with its honor guard.",firstCash=150000000,replayCash=15000000,groups={{"Knight",6,4},{"Wizard",6,3}},boss={species="Dragon",hp=26000,damage=320,interval=1.6,splash=true}},
	["3:1"]={name="Royal Vanguard",tier=3,description="The armada's elite guard lands first.",firstCash=250000000,replayCash=25000000,groups={{"Knight",8,5},{"IceDuck",7,4},{"Dragon",7,2}}},
	["3:2"]={name="Crown's Shield",tier=3,description="The armada's shield wall, built to outlast your flock.",firstCash=750000000,replayCash=75000000,groups={{"IceDuck",8,5},{"Dragon",8,4},{"StormDuck",7,2}}},
	["3:3"]={name="The King Returns",tier=3,description="The Chicken King himself leads the armada.",firstCash=2500000000,replayCash=250000000,groups={{"IceDuck",9,4},{"Dragon",9,3},{"StormDuck",8,2}},boss={species="Duck",hp=80000,damage=900,interval=1.8,splash=true}},
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
