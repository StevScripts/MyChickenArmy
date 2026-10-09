--!strict
-- Permanent cash-and-time research. Existing cash upgrade eligibility is separate.
local Catalog = {}
Catalog.Order = {"Start", "L1", "L2", "L3", "L4", "L5", "L6", "R1", "R2", "R3", "R4", "R5", "R6", "CallArmy", "FuseMachine", "A1", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9", "A10", "A11", "A12", "A13", "A14", "A15", "A16", "E1", "E2", "E3", "E4", "E5", "E6", "E7", "E8", "E9", "E10", "E11", "E12", "E13", "E14", "E15", "S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10", "S11", "S12", "S13", "S14", "S15", "S16", "S17"}
Catalog.Nodes = {
	["Start"] = {id="Start", name="Start", branch="Start", price=0, duration=0, description="Improve your rolls, egg farm or fighting flock.", q=0, r=0, icon="index"},
	["CallArmy"] = {id="CallArmy", name="Call Army", branch="Army", price=1000, duration=60, description="Unlock Call Army: recall your selected chickens to follow you.", q=-1, r=2, icon="callArmy", prerequisite="Start", effect="callArmy", value=1},
	["FuseMachine"] = {id="FuseMachine", name="Fuse Machine", branch="Army", price=5000, duration=120, description="Unlock fusion: combine 3 matching chickens into a Giant one level higher.", q=3, r=-4, icon="fuseMachine", prerequisite="R1", effect="fusion", value=1},
	["A1"] = {id="A1", name="Peck Drills", branch="Army", price=500, duration=30, description="+5% army damage", q=-1, r=0, icon="army", prerequisite="Start", effect="damage", value=0.05},
	["A2"] = {id="A2", name="Officer Training", branch="Army", price=5000, duration=120, description="+10% army damage", q=-2, r=0, icon="army", prerequisite="A1", effect="damage", value=0.1},
	["A3"] = {id="A3", name="Elite Flock", branch="Army", price=250000, duration=1800, description="+25% army damage", q=-3, r=0, icon="army", prerequisite="A2", effect="damage", value=0.25},
	["A4"] = {id="A4", name="Bandages", branch="Army", price=1500, duration=60, description="+5% army maximum health", q=-2, r=1, icon="bandages", prerequisite="A1", effect="health", value=0.05},
	["A5"] = {id="A5", name="Field Medkit", branch="Army", price=15000, duration=300, description="+10% army maximum health", q=-3, r=2, icon="medkit", prerequisite="A4", effect="health", value=0.1},
	["A6"] = {id="A6", name="Iron Feathers", branch="Army", price=250000, duration=2700, description="+25% army maximum health", q=-4, r=3, icon="medkit", prerequisite="A5", effect="health", value=0.25},
	["A7"] = {id="A7", name="Quick Feet", branch="Army", price=10000, duration=180, description="+5% army march speed", q=-2, r=-1, icon="boots", prerequisite="A2", effect="march", value=0.05},
	["A8"] = {id="A8", name="Marching Drills", branch="Army", price=100000, duration=900, description="+10% army march speed", q=-2, r=-2, icon="boots", prerequisite="A7", effect="march", value=0.1},
	["A9"] = {id="A9", name="Lightning March", branch="Army", price=2000000, duration=7200, description="+20% army march speed", q=-2, r=-3, icon="boots", prerequisite="A8", effect="march", value=0.2},
	["A10"] = {id="A10", name="Tough Shells", branch="Army", price=500000, duration=2700, description="5% less incoming combat damage", q=-4, r=2, icon="army", prerequisite="A5", effect="armor", value=0.05},
	["A11"] = {id="A11", name="Reinforced Shells", branch="Army", price=10000000, duration=28800, description="10% less incoming combat damage", q=-5, r=2, icon="army", prerequisite="A10", effect="armor", value=0.1},
	["A12"] = {id="A12", name="Field Recovery", branch="Army", price=25000, duration=300, description="10% shorter existing chicken recovery duration", q=-2, r=2, icon="medkit", prerequisite="A4", effect="recovery", value=0.1},
	["A13"] = {id="A13", name="Rescue Crew", branch="Army", price=1000000, duration=3600, description="20% shorter existing recovery duration", q=-2, r=3, icon="medkit", prerequisite="A12", effect="recovery", value=0.2},
	["A14"] = {id="A14", name="Rally", branch="Army", price=50000, duration=600, description="Manual army command: +20% damage for 8s; 90s cooldown", q=-3, r=1, icon="rally", prerequisite="A2", effect="rallySeconds", value=8},
	["A15"] = {id="A15", name="Battle Cry", branch="Army", price=5000000, duration=14400, description="Rally lasts 12s; damage and cooldown unchanged", q=-4, r=1, icon="rally", prerequisite="A14", effect="rallySeconds", value=12},
	["A16"] = {id="A16", name="King Breaker", branch="Army", price=50000000, duration=43200, description="+15% damage against explicitly tagged NPC bosses", q=-4, r=0, icon="army", prerequisite="A3", effect="bossDamage", value=0.15},
	["E1"] = {id="E1", name="Balanced Feed", branch="Economy", price=750, duration=30, description="+5% egg quantity production", q=0, r=1, icon="feed", prerequisite="Start", effect="production", value=0.05},
	["E2"] = {id="E2", name="Enriched Feed", branch="Economy", price=10000, duration=300, description="+10% egg quantity production", q=0, r=2, icon="feed", prerequisite="E1", effect="production", value=0.1},
	["E3"] = {id="E3", name="Perfect Feed", branch="Economy", price=1000000, duration=3600, description="+20% egg quantity production", q=0, r=3, icon="feed", prerequisite="E2", effect="production", value=0.2},
	["E4"] = {id="E4", name="Careful Packing", branch="Economy", price=25000, duration=600, description="+5% value on newly produced eggs", q=-1, r=3, icon="egg", prerequisite="E2", effect="eggValue", value=0.05},
	["E5"] = {id="E5", name="Farm Brand", branch="Economy", price=750000, duration=3600, description="+10% value on newly produced eggs", q=-1, r=4, icon="egg", prerequisite="E4", effect="eggValue", value=0.1},
	["E6"] = {id="E6", name="Premium Packing", branch="Economy", price=25000000, duration=28800, description="+15% value on newly produced eggs", q=-1, r=5, icon="egg", prerequisite="E5", effect="eggValue", value=0.15},
	["E7"] = {id="E7", name="Egg Magnet", branch="Economy", price=2500, duration=60, description="+1.5 studs manual pickup range", q=1, r=1, icon="magnet", prerequisite="E1", effect="pickupStuds", value=1.5},
	["E8"] = {id="E8", name="Long Reach", branch="Economy", price=50000, duration=600, description="+3 studs manual pickup range", q=2, r=1, icon="magnet", prerequisite="E7", effect="pickupStuds", value=3},
	["E9"] = {id="E9", name="Wide Sweep", branch="Economy", price=1000000, duration=3600, description="+4.5 studs manual pickup range", q=3, r=1, icon="magnet", prerequisite="E8", effect="pickupStuds", value=4.5},
	["E10"] = {id="E10", name="Bounty Ledger", branch="Economy", price=25000, duration=600, description="+5% existing NPC kill cash", q=1, r=2, icon="cash", prerequisite="E2", effect="bounty", value=0.05},
	["E11"] = {id="E11", name="Bounty Office", branch="Economy", price=750000, duration=3600, description="+10% existing NPC kill cash", q=2, r=2, icon="cash", prerequisite="E10", effect="bounty", value=0.1},
	["E12"] = {id="E12", name="Bounty Network", branch="Economy", price=25000000, duration=28800, description="+20% existing NPC kill cash", q=3, r=2, icon="cash", prerequisite="E11", effect="bounty", value=0.2},
	["E13"] = {id="E13", name="Night Shift", branch="Economy", price=2500000, duration=7200, description="Offline allowance increases from 8h to 9h", q=0, r=4, icon="feed", prerequisite="E3", effect="offlineHours", value=9},
	["E14"] = {id="E14", name="Overnight Crew", branch="Economy", price=25000000, duration=28800, description="Offline allowance becomes 10h", q=0, r=5, icon="feed", prerequisite="E13", effect="offlineHours", value=10},
	["E15"] = {id="E15", name="Round-the-Clock Farm", branch="Economy", price=150000000, duration=86400, description="Offline allowance becomes 12h", q=0, r=6, icon="feed", prerequisite="E14", effect="offlineHours", value=12},
	["S1"] = {id="S1", name="Field Notes", branch="Command", price=1000, duration=60, description="+5% research speed", q=1, r=-1, icon="index", prerequisite="Start", effect="speed", value=0.05},
	["S2"] = {id="S2", name="Study Desk", branch="Command", price=25000, duration=900, description="+10% research speed", q=2, r=-1, icon="lab", prerequisite="S1", effect="speed", value=0.1},
	["S3"] = {id="S3", name="Research Lab", branch="Command", price=2500000, duration=7200, description="+25% research speed", q=3, r=-1, icon="lab", prerequisite="S2", effect="speed", value=0.25},
	["S4"] = {id="S4", name="Researcher", branch="Command", price=150000, duration=900, description="2 simultaneous research slots total", q=2, r=-2, icon="lab", prerequisite="S1", effect="slots", value=2},
	["S5"] = {id="S5", name="Research Team", branch="Command", price=10000000, duration=7200, description="3 simultaneous research slots total", q=1, r=-2, icon="lab", prerequisite="S4", effect="slots", value=3},
	["S6"] = {id="S6", name="Flag Drill", branch="Command", price=25000, duration=600, description="+10% capture speed", q=2, r=-3, icon="index", prerequisite="S4", effect="capture", value=0.1},
	["S7"] = {id="S7", name="Banner Crew", branch="Command", price=500000, duration=2700, description="+20% capture speed", q=2, r=-4, icon="index", prerequisite="S6", effect="capture", value=0.2},
	["S8"] = {id="S8", name="Rapid Occupation", branch="Command", price=10000000, duration=14400, description="+30% capture speed", q=2, r=-5, icon="index", prerequisite="S7", effect="capture", value=0.3},
	["S9"] = {id="S9", name="Running Shoes", branch="Command", price=50000, duration=600, description="+5% player movement speed", q=3, r=-2, icon="boots", prerequisite="S2", effect="walk", value=0.05},
	["S10"] = {id="S10", name="Trail Runner", branch="Command", price=1000000, duration=3600, description="+10% player movement speed", q=4, r=-2, icon="boots", prerequisite="S9", effect="walk", value=0.1},
	["S11"] = {id="S11", name="Courier Boots", branch="Command", price=25000000, duration=28800, description="+15% player movement speed", q=5, r=-2, icon="boots", prerequisite="S10", effect="walk", value=0.15},
	["S12"] = {id="S12", name="Formation Book", branch="Command", price=15000, duration=300, description="Save 1 named army loadout", q=1, r=0, icon="index", prerequisite="S1", effect="formations", value=1},
	["S13"] = {id="S13", name="Officer's Notebook", branch="Command", price=1000000, duration=1800, description="Save 2 loadouts total", q=2, r=0, icon="index", prerequisite="S12", effect="formations", value=2},
	["S14"] = {id="S14", name="Command Archive", branch="Command", price=25000000, duration=14400, description="Save 3 loadouts total", q=3, r=0, icon="index", prerequisite="S13", effect="formations", value=3},
	["S15"] = {id="S15", name="Operations Board", branch="Command", price=2500000, duration=3600, description="Unlock a separate set of Veteran Operations", q=3, r=-3, icon="index", prerequisite="S4", effect="operations", value=1},
	["S16"] = {id="S16", name="Elite Operations", branch="Command", price=25000000, duration=28800, description="Unlock the Elite Operations set", q=4, r=-4, icon="index", prerequisite="S15", effect="operations", value=2},
	["S17"] = {id="S17", name="Royal Operations", branch="Command", price=250000000, duration=172800, description="Unlock the Royal Operations set", q=5, r=-5, icon="index", prerequisite="S16", effect="operations", value=3},
	-- Collection progression inspired by the supplied Slime RNG tree. Our tuning
	-- shifts favored chicken bands and podium frequency; it never changes fusion or slot caps.
	["L1"] = {id="L1", name="Lucky Feathers I", branch="Rolling", price=750, duration=30, description="+10% Luck strength toward stronger chickens", q=0, r=-1, icon="luck", prerequisite="Start", effect="rollingLuck", value=0.1},
	["L2"] = {id="L2", name="Lucky Feathers II", branch="Rolling", price=7500, duration=120, description="+20% Luck strength toward stronger chickens", q=0, r=-2, icon="luck", prerequisite="L1", effect="rollingLuck", value=0.2},
	["L3"] = {id="L3", name="Lucky Feathers III", branch="Rolling", price=75000, duration=600, description="+35% Luck strength toward stronger chickens", q=0, r=-3, icon="luck", prerequisite="L2", effect="rollingLuck", value=0.35},
	["L4"] = {id="L4", name="Super Luck I", branch="Rolling", price=750000, duration=1800, description="+50% Luck strength toward stronger chickens", q=0, r=-4, icon="luck", prerequisite="L3", effect="rollingLuck", value=0.5},
	["L5"] = {id="L5", name="Super Luck II", branch="Rolling", price=7500000, duration=7200, description="+75% Luck strength toward stronger chickens", q=0, r=-5, icon="luck", prerequisite="L4", effect="rollingLuck", value=0.75},
	["L6"] = {id="L6", name="Super Luck III", branch="Rolling", price=50000000, duration=28800, description="+100% Luck strength toward stronger chickens", q=0, r=-6, icon="luck", prerequisite="L5", effect="rollingLuck", value=1},
	["R1"] = {id="R1", name="Roll Speed", branch="Rolling", price=1500, duration=60, description="+10% podium roll speed", q=-1, r=-1, icon="boots", prerequisite="L1", effect="rollingSpeed", value=0.1},
	["R2"] = {id="R2", name="Faster Rolls", branch="Rolling", price=15000, duration=180, description="+20% podium roll speed", q=-1, r=-2, icon="boots", prerequisite="R1", effect="rollingSpeed", value=0.2},
	["R3"] = {id="R3", name="Rapid Rolls", branch="Rolling", price=150000, duration=900, description="+30% podium roll speed", q=-1, r=-3, icon="boots", prerequisite="R2", effect="rollingSpeed", value=0.3},
	["R4"] = {id="R4", name="Quick Rolls", branch="Rolling", price=1500000, duration=3600, description="+40% podium roll speed", q=-1, r=-4, icon="boots", prerequisite="R3", effect="rollingSpeed", value=0.4},
	["R5"] = {id="R5", name="Speed Rolls", branch="Rolling", price=15000000, duration=14400, description="+50% podium roll speed", q=-1, r=-5, icon="boots", prerequisite="R4", effect="rollingSpeed", value=0.5},
	["R6"] = {id="R6", name="Lightning Rolls", branch="Rolling", price=75000000, duration=43200, description="+60% podium roll speed", q=-1, r=-6, icon="boots", prerequisite="R5", effect="rollingSpeed", value=0.6},
}
Catalog.MaxJobs = 3
Catalog.RallyBonus = 0.20
Catalog.RallyCooldown = 90
for _,node in Catalog.Nodes do table.freeze(node) end
table.freeze(Catalog.Nodes)
table.freeze(Catalog.Order)
return table.freeze(Catalog)
