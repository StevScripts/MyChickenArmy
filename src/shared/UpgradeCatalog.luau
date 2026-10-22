--!strict
-- October 20 overhaul Upgrades tree (docs/team/OVERHAUL_CONTRACT_20261020.md §4).
-- A few named tiers per family, in a main tree and three "Open" subtrees. Every
-- node is an instant Coins purchase, resets on Rebirth and has no camp, rank or King
-- gate (September 25 rule). Prices here are the base quotes: the server snapshot is
-- the only price a client may show (it can scale with Rebirth rank).
-- Tier values and prices are drafts for the P0 fit in tests/ProgressionSimulation.
-- October 21 later (P5, docs/team/REBIRTH_PACING_20261021.md "reference-shaped ladder"):
-- Egg Speed III-IV, Egg Value III-IV and Flock Size 7-15 cost far more (Egg Speed IV
-- 60M, Egg Value IV 250M, Flock Size 15 2B; were 30K, 45K, 70K), so the run after a
-- Rebirth climbs the tree over several Rebirths, as in the reference, instead of
-- rebuying all of it with the Time Skip Coins. Values are unchanged: saved tiers keep
-- their meaning and need no TreeMigrations step.
local Config = require(script.Parent.Config)
local Gems = require(script.Parent.GemUpgradeCatalog)
local Mutations = require(script.Parent.MutationCatalog)
local Catalog = {}

export type Tier = {value: number, price: number, yardStage: number?}
-- A tier's own hex name, icon and big tier number (Luck's Super/Mega chains, mutations).
export type Label = {name: string, icon: string, numeral: number?}
export type Family = {
	id: string, name: string, category: string, icon: string, description: string,
	effect: string?, field: string?, base: number, format: string, unit: string?,
	tiers: {Tier}, positions: {{number}}, prerequisite: string?, labels: {Label}?,
}
export type Node = {
	id: string, kind: string, category: string, q: number, r: number, name: string, icon: string,
	family: string?, tier: number?, numeral: number?, prerequisite: string?, opens: string?,
}

Catalog.Categories = {"Main", "Tools", "Player", "Army"}
-- Each category's center hex. "start", "back" and "open" nodes always count as owned.
Catalog.Roots = {Main = "Start", Tools = "ToolsBack", Player = "PlayerBack", Army = "ArmyBack"}

local ROMAN = {"I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"}

-- `effect`: key in the effect table (UpgradeCatalog.Effects); `field`: a derived
-- PlayerSession field kept for existing readers. Values are cumulative per tier.
local function tiers(list: {{number}}): {Tier}
	local result = {}
	for index, entry in list do result[index] = {value = entry[1], price = entry[2], yardStage = entry[3]} end
	return result
end

-- October 20 tree v2 (S9c, Stevin's Drop a Fruit screenshots): the maps use flat-topped
-- hexes in axial (q, r) cells, so a chain is a walk of neighbour steps.
local STEPS = {N = {0, -1}, S = {0, 1}, NE = {1, -1}, SE = {1, 0}, NW = {-1, 0}, SW = {-1, 1}}
local function walk(q: number, r: number, steps: {string}?): {{number}}
	local cells = {{q, r}}
	for _, step in steps or {} do
		q, r = q + STEPS[step][1], r + STEPS[step][2]
		table.insert(cells, {q, r})
	end
	return cells
end

-- Chains of four that restart their numbering: Luck I–IV, then Super Luck I–IV...
local function chains(list: {{string}}): {Label}
	local labels = {}
	for _, chain in list do
		for numeral = 1, 4 do table.insert(labels, {name = chain[1] .. " " .. ROMAN[numeral], icon = chain[2], numeral = numeral}) end
	end
	return labels
end

local families: {Family} = {
	-- Main tree ------------------------------------------------------------------
	-- October 21 (Stevin: "I really hate the crampedness", put things where they make
	-- sense): each topic has its own side and every chain is a zig-zag lane with an empty
	-- row between lanes. The Open hexes still alternate with green ones around Start:
	-- Tools upper left (eggs to the left), Player upper right (Gold/Diamond/Prism lanes),
	-- Army below (Army Size lower left); Roll Slot, Roll Speed and Luck lanes run right.
	-- Every hex touches the hex it needs, so a few chains open from a neighbour.
	{id = "EggSpeed", name = "Egg Speed", category = "Main", icon = "eggSpeed", field = "eggSpeedLevel", base = 1,
		format = "multiplier", description = "Chickens in your Flock lay eggs faster.",
		tiers = tiers({{1.25, 400}, {1.5, 2000}, {2, 250000}, {3, 60000000}}),
		positions = walk(0, -1, {"N", "NE", "N"})},
	{id = "EggValue", name = "Egg Value", category = "Main", icon = "eggValue", field = "incomeLevel", base = 1,
		format = "multiplier", description = "Every new egg is worth more Coins.",
		tiers = tiers({{1.5, 600}, {2, 3000}, {3, 400000}, {5, 250000000}}),
		positions = walk(-1, -1, {"NW", "SW", "NW"}), prerequisite = "OpenTools"},
	-- Three chains, each its own clover: Luck I–IV, Super Luck I–IV, Mega Luck I–IV
	-- (Stevin, October 20). Values are Luck strength; the window math stays bounded.
	-- October 21 (Stevin: "Luck should take a bit"): Luck I–IV stay cheap (cycle 1–2),
	-- Super Luck is priced for Rebirth 2–5 and Mega Luck for Rebirth 5–11 of the P5 ladder
	-- (x10 Luck at ~3.8 h nonstop, day 4–5 at 45 min a day); the old 250K–150M ladder was
	-- fully bought by minute 30 (docs/team/RARITY_PACING_20261021.md §6).
	{id = "Luck", name = "Luck", category = "Main", icon = "luck", field = "luck", base = 1,
		format = "multiplier", description = "Favor stronger chickens in normal rolls.",
		tiers = tiers({{1.25, 800}, {1.5, 4000}, {2, 16000}, {3, 60000},
			{3.5, 5000000}, {4, 50000000}, {4.5, 400000000}, {5, 2000000000},
			{6, 10000000000}, {7, 50000000000}, {8, 150000000000}, {10, 400000000000}}),
		labels = chains({{"Luck", "luck"}, {"Super Luck", "superLuck"}, {"Mega Luck", "megaLuck"}}),
		-- Luck curls under Roll Speed, Super Luck climbs the right edge, Mega Luck tops it.
		positions = walk(1, 2, {"S", "SE", "SE", "NE", "SE", "NE", "SE", "SE", "S", "SW", "NW"}), prerequisite = "RollSpeed1"},
	-- Flock Size = chickens out in the yard laying. yardStage is the authored yard
	-- expansion (PlayerSession.plotSizeLevel, 0-7) that tier opens.
	{id = "Flock", name = "Flock Size", category = "Main", icon = "flockSize", effect = "flockSize", base = 3,
		format = "count", unit = "chickens laying", description = "More of your chickens lay eggs in the yard.",
		tiers = tiers({{4, 300, 0}, {5, 900, 1}, {6, 2000, 2}, {7, 25000, 3}, {8, 250000, 4}, {10, 3000000, 5},
			{12, 80000000, 6}, {15, 2000000000, 7}}),
		positions = walk(-1, 1, {"NW", "SW", "NW", "SW", "NW", "SW", "NW"})},
	-- Tier 1 is the Commander guide's protected 1,200-Coin Army Size 4 (COMMANDER_TUTORIAL.md).
	-- It opens from Army (Open), which always counts as owned, so it needs nothing new.
	{id = "ArmySize", name = "Army Size", category = "Main", icon = "armySize", field = "capacity", base = Config.StartingSlots,
		format = "count", unit = "Army slots", description = "Send more chickens into battle.",
		tiers = tiers({{4, 1200}, {6, 6000}, {8, 25000}, {10, 90000}}),
		positions = walk(-1, 2, {"SW", "SW", "NW"}), prerequisite = "OpenArmy"},
	-- Roll Slots zig-zag right from Start (Stevin: "not a straight line").
	{id = "RollSlot", name = "Roll Slot", category = "Main", icon = "rollSlots", field = "rollSlotsUnlocked", base = 1,
		format = "count", unit = "podiums", description = "Roll on more of your podiums at once.",
		tiers = tiers({{2, 1000}, {3, 4000}, {4, 12000}, {5, 30000}, {6, 75000}, {7, 180000}, {8, 400000}}),
		positions = walk(1, 0, {"NE", "SE", "NE", "SE", "NE", "SE"})},
	-- Each tier shortens the roll (RollService: RollRevealSeconds / (1 + rollingSpeed)).
	{id = "RollSpeed", name = "Roll Speed", category = "Main", icon = "rollSpeed", effect = "rollingSpeed", base = 0,
		format = "percent", description = "Every roll takes less time.",
		tiers = tiers({{0.2, 1500}, {0.4, 7500}, {0.6, 30000}, {0.8, 100000}, {1, 300000}}),
		positions = walk(1, 1, {"SE", "SE", "NE", "SE"}), prerequisite = "RollSlot1"},
	-- Mutations are bought here (Stevin, October 20), rarest furthest out. The value is
	-- how many of MutationCatalog.Order can roll; it resets on Rebirth like the tree.
	{id = "Mutation", name = "Mutations", category = "Main", icon = "mutationGolden", effect = "mutations", base = 0,
		format = "mutation", description = "Lets a rarer mutation appear on your rolls.",
		tiers = tiers({{1, 10000}, {2, 100000}, {3, 1000000}, {4, 10000000}}),
		labels = {{name = "Golden Chickens", icon = "mutationGolden"}, {name = "Rainbow Chickens", icon = "mutationRainbow"},
			{name = "Shadow Chickens", icon = "mutationShadow"}, {name = "Cosmic Chickens", icon = "mutationCosmic"}},
		positions = walk(0, 3, {"SW", "S", "SW"}), prerequisite = "Luck1"},
	-- Gold rolls (S12): each machine counts its own pulls; its Rate tiers shorten that
	-- count (Config.GoldRolls). Gold, Diamond and Prism are three lanes right of Player.
	{id = "GoldMachine", name = "Gold Machine", category = "Main", icon = "goldMachine", effect = "goldMachine", base = 0,
		format = "unlock", description = "Your roll machine counts down to a Gold roll.",
		tiers = tiers({{1, 25000}}), positions = walk(2, -2), prerequisite = "OpenPlayer"},
	{id = "GoldRate", name = "Gold Rate", category = "Main", icon = "goldRate", effect = "goldRate", base = 0,
		format = "level", description = "Gold rolls come around sooner.",
		tiers = tiers({{1, 60000}, {2, 150000}, {3, 400000}, {4, 1000000}}),
		positions = walk(3, -3, {"NE", "SE", "NE"}), prerequisite = "GoldMachine"},
	{id = "DiamondMachine", name = "Diamond Machine", category = "Main", icon = "diamondMachine", effect = "goldMachine", base = 0,
		format = "unlock", description = "Adds Diamond rolls on their own counter, separate from Gold rolls.",
		tiers = tiers({{2, 300000}}), positions = walk(3, -4), prerequisite = "GoldRate1"},
	{id = "DiamondRate", name = "Diamond Rate", category = "Main", icon = "diamondRate", effect = "diamondRate", base = 0,
		format = "level", description = "Diamond rolls come around sooner.",
		tiers = tiers({{1, 750000}, {2, 2000000}, {3, 5000000}, {4, 12000000}}),
		positions = walk(3, -5, {"NE", "SE", "NE"}), prerequisite = "DiamondMachine"},
	{id = "PrismMachine", name = "Prism Machine", category = "Main", icon = "prismMachine", effect = "goldMachine", base = 0,
		format = "unlock", description = "Adds Prism rolls on their own counter, separate from Gold and Diamond rolls.",
		tiers = tiers({{3, 1000000}}), positions = walk(3, -6), prerequisite = "DiamondRate1"},
	{id = "PrismRate", name = "Prism Rate", category = "Main", icon = "prismRate", effect = "prismRate", base = 0,
		format = "level", description = "Prism rolls come around sooner.",
		tiers = tiers({{1, 8000000}, {2, 20000000}, {3, 50000000}, {4, 120000000}}),
		positions = walk(3, -7, {"NE", "SE", "NE"}), prerequisite = "PrismMachine"},
	-- Tools ----------------------------------------------------------------------
	-- Like the reference: Back in the middle, each tool a branch with its own chains.
	-- October 20 (Stevin, S14): the hand vacuum is bought here and resets on Rebirth,
	-- like Chicken Feed. It replaces the free gift at the end of the Commander guide.
	{id = "EggVacuum", name = "Egg Vacuum", category = "Tools", icon = "eggVacuum", effect = "eggVacuum", base = 0,
		format = "unlock", description = "Equip the Egg Vacuum to pull in nearby eggs, then sell them on the pad.",
		tiers = tiers({{1, 500}}), positions = walk(-1, 1)},
	-- October 21 (Stevin: "too large very easily, not enough of a challenge"): bonus eggs
	-- on the Egg Vacuum's fixed base (VacuumConfig.Capacity). October 22 (Stevin: "a
	-- little" more) about 25% larger at the same prices: 25 base, 40, 60, 90, 150 eggs
	-- (were 20, 30, 45, 70, 120). Was
	-- 15-90 s of the Flock's laying at 500-40K, which already held two full yards and
	-- grew with every Flock Size and Egg Speed tier. Each tier is priced with the Flock
	-- tier whose yard it fits (Flock 4-5, 7, 10, 12: 20-60 eggs on the ground), so the
	-- vacuum fills about once a yard. Saved tiers keep their number (a deliberate nerf,
	-- reset by the next Rebirth anyway), so no TreeMigrations step.
	{id = "VacuumCapacity", name = "Vacuum Capacity", category = "Tools", icon = "vacuumCapacity", effect = "vacuumCapacity", base = 0,
		format = "bonusCount", unit = "eggs", description = "Your Egg Vacuum holds more eggs.",
		tiers = tiers({{15, 1500}, {35, 25000}, {65, 3000000}, {125, 100000000}}),
		positions = walk(-2, 2, {"SE", "SW", "SE"}), prerequisite = "EggVacuum"},
	-- Same day: 13, 16, 20 studs (were 14, 18, 22 by 75K, when 18 studs already reached
	-- every egg of the 30x30 starter yard from its middle).
	{id = "VacuumRange", name = "Vacuum Range", category = "Tools", icon = "vacuumRange", effect = "vacuumRange", base = 0,
		format = "studs", description = "Your Egg Vacuum reaches eggs from farther away.",
		tiers = tiers({{3, 2500}, {6, 40000}, {10, 1500000}}), positions = walk(-2, 1, {"NW", "SW"}), prerequisite = "EggVacuum"},
	-- October 21 (Stevin): the retired Auto Collect robot comes back as a tool, an
	-- ordinary Coins purchase that resets on Rebirth. Its three chains fan out above Back
	-- (docs/team/AUTO_VACUUM.md). October 22 (Stevin): no eggs-vacuumed unlock (was
	-- 5,000); instead it costs more than the hand vacuum's last tier (Vacuum Capacity IV,
	-- 100M), and its chains start above it too (were 15K-1M, all below that tier).
	{id = "AutoVacuum", name = "Auto Vacuum", category = "Tools", icon = "autoVacuum", effect = "autoVacuum", base = 0,
		format = "unlock", description = "A robot drives around your yard, vacuums up eggs and sells them on the pad for you.",
		tiers = tiers({{1, 250000000}}), positions = walk(0, -1)},
	-- Bonus seconds of the Flock's laying on top of the robot's 20 s tank: 30, 40, 60, 80 s.
	{id = "AutoVacuumCapacity", name = "Auto Capacity", category = "Tools", icon = "autoVacuumCapacity", effect = "autoVacuumCapacity", base = 0,
		format = "seconds", unit = "of eggs", description = "The Auto Vacuum holds more eggs before it drives to the pad.",
		tiers = tiers({{10, 400000000}, {20, 1500000000}, {40, 6000000000}, {60, 25000000000}}),
		positions = walk(-1, -1, {"NW", "N", "NW"}), prerequisite = "AutoVacuum"},
	-- Studs on top of the robot's 5-stud reach; a longer reach also means fewer passes.
	{id = "AutoVacuumRange", name = "Auto Range", category = "Tools", icon = "autoVacuumRange", effect = "autoVacuumRange", base = 0,
		format = "studs", description = "The Auto Vacuum pulls in eggs from farther away.",
		tiers = tiers({{2, 600000000}, {4, 3000000000}, {6, 12000000000}}),
		positions = walk(1, -2, {"NE", "N"}), prerequisite = "AutoVacuum"},
	{id = "AutoVacuumSpeed", name = "Auto Speed", category = "Tools", icon = "autoVacuumSpeed", effect = "autoVacuumSpeed", base = 0,
		format = "percent", description = "The Auto Vacuum drives faster.",
		tiers = tiers({{0.25, 500000000}, {0.5, 2500000000}, {1, 10000000000}}),
		positions = walk(0, -2, {"N", "N"}), prerequisite = "AutoVacuum"},
	{id = "ChickenFeed", name = "Chicken Feed", category = "Tools", icon = "chickenFeed", effect = "chickenFeed", base = 0,
		format = "unlock", description = "Equip Chicken Feed and walk to one of your chickens to level it up.",
		tiers = tiers({{1, 1000}}), positions = walk(1, 0)},
	-- Extra Feed levels above Lv 10, cumulative (+3/+3/+4 to Lv 20). S7 owns the cap and
	-- the levels' value (Rules.LevelCap reads effects.feedMaxLevel).
	{id = "FeedMaxLevel", name = "Max Level", category = "Tools", icon = "feedMaxLevel", effect = "feedMaxLevel", base = 0,
		format = "maxLevel", description = "Chicken Feed levels your chickens higher.",
		tiers = tiers({{3, 50000}, {6, 400000}, {10, 2500000}}),
		positions = walk(2, 0, {"SE", "NE"}), prerequisite = "ChickenFeed"},
	-- Player ---------------------------------------------------------------------
	{id = "WalkSpeed", name = "Walk Speed", category = "Player", icon = "walkSpeed", effect = "walk", base = 0,
		format = "percent", description = "You move faster.",
		tiers = tiers({{0.05, 2000}, {0.10, 10000}, {0.15, 40000}}), positions = walk(1, -1, {"NE", "SE"})},
	{id = "ClickRange", name = "Click Range", category = "Player", icon = "clickRange", effect = "pickupStuds", base = 0,
		format = "studs", description = "Collect eggs from farther away.",
		tiers = tiers({{1.5, 1000}, {3, 6000}, {4.5, 25000}}), positions = walk(-1, 0, {"NW", "SW"})},
	{id = "OfflineTime", name = "Offline Time", category = "Player", icon = "offlineTime", effect = "offlineHours", base = 8,
		format = "hours", description = "Your Flock earns Coins for longer while you're away.",
		tiers = tiers({{9, 10000}, {10, 50000}, {12, 200000}}), positions = walk(0, 1, {"SE", "SW"})},
	-- Army -----------------------------------------------------------------------
	{id = "Damage", name = "Damage", category = "Army", icon = "damage", effect = "damage", base = 0,
		format = "percent", description = "Your army deals more damage.",
		tiers = tiers({{0.05, 1000}, {0.10, 8000}, {0.25, 50000}}), positions = walk(1, -1, {"NE", "SE"})},
	{id = "BossDamage", name = "Boss Damage", category = "Army", icon = "bossDamage", effect = "bossDamage", base = 0,
		format = "percent", description = "Your army deals more damage to bosses.",
		tiers = tiers({{0.15, 250000}}), positions = walk(4, -3), prerequisite = "Damage3"},
	{id = "Health", name = "Health", category = "Army", icon = "health", effect = "health", base = 0,
		format = "percent", description = "Your chickens have more health.",
		tiers = tiers({{0.05, 1500}, {0.10, 12000}, {0.25, 60000}}), positions = walk(-1, 0, {"NW", "SW"})},
	{id = "MarchSpeed", name = "March Speed", category = "Army", icon = "marchSpeed", effect = "march", base = 0,
		format = "percent", description = "Your army marches faster.",
		tiers = tiers({{0.05, 3000}, {0.10, 20000}, {0.20, 100000}}), positions = walk(0, -1, {"NE", "NW"})},
	{id = "CaptureSpeed", name = "Capture Speed", category = "Army", icon = "captureSpeed", effect = "capture", base = 0,
		format = "percent", description = "Your army captures camps faster.",
		tiers = tiers({{0.10, 4000}, {0.20, 30000}, {0.30, 150000}}), positions = walk(-1, -1, {"NW", "NE"}),
		prerequisite = "MarchSpeed1"},
	{id = "Armor", name = "Armor", category = "Army", icon = "armor", effect = "armor", base = 0,
		format = "reduction", description = "Your chickens take less damage.",
		tiers = tiers({{0.05, 25000}, {0.10, 150000}}), positions = walk(1, 0, {"SE"})},
	{id = "Recovery", name = "Recovery", category = "Army", icon = "recovery", effect = "recovery", base = 0,
		format = "percent", description = "Knocked-out chickens recover faster.",
		tiers = tiers({{0.10, 5000}, {0.20, 40000}}), positions = walk(-1, 1, {"SW"})},
	{id = "Bounty", name = "Bounty", category = "Army", icon = "bounty", effect = "bounty", base = 0,
		format = "percent", description = "Earn more Coins from defeated enemies.",
		tiers = tiers({{0.05, 5000}, {0.10, 40000}, {0.20, 200000}}), positions = walk(0, 1, {"SE", "SW"})},
}

Catalog.FamilyOrder = {} :: {string}
Catalog.Families = {} :: {[string]: Family}
for _, family in families do
	assert(#family.positions == #family.tiers, "One hex per tier: " .. family.id)
	table.insert(Catalog.FamilyOrder, family.id)
	Catalog.Families[family.id] = family
end

function Catalog.NodeId(familyId: string, tier: number): string
	local family = Catalog.Families[familyId]
	return if family and #family.tiers == 1 then familyId else familyId .. tier
end

-- Every hex. Special nodes first, then each family's tiers.
Catalog.Nodes = {} :: {[string]: Node}
Catalog.Order = {Main = {}, Tools = {}, Player = {}, Army = {}} :: {[string]: {string}}
local function add(node: Node)
	assert(not Catalog.Nodes[node.id], "Duplicate Upgrades node " .. node.id)
	Catalog.Nodes[node.id] = node
	table.insert(Catalog.Order[node.category], node.id)
end
add({id = "Start", kind = "start", category = "Main", q = 0, r = 0, name = "Start", icon = "start"})
add({id = "OpenTools", kind = "open", category = "Main", q = -1, r = 0, name = "Tools", icon = "openTools", opens = "Tools"})
add({id = "OpenPlayer", kind = "open", category = "Main", q = 1, r = -1, name = "Player", icon = "openPlayer", opens = "Player"})
add({id = "OpenArmy", kind = "open", category = "Main", q = 0, r = 1, name = "Army", icon = "openArmy", opens = "Army"})
for _, category in {"Tools", "Player", "Army"} do
	add({id = Catalog.Roots[category], kind = "back", category = category, q = 0, r = 0, name = "Back", icon = "back", opens = "Main"})
end
for _, family in families do
	for tier in family.tiers do
		local position = family.positions[tier]
		local label = family.labels and family.labels[tier]
		local single = #family.tiers == 1
		add({id = Catalog.NodeId(family.id, tier), kind = "upgrade", category = family.category,
			q = position[1], r = position[2], family = family.id, tier = tier,
			icon = if label then label.icon else family.icon,
			name = if label then label.name elseif single then family.name else family.name .. " " .. ROMAN[tier],
			numeral = if label then label.numeral elseif single then nil else tier,
			prerequisite = if tier > 1 then Catalog.NodeId(family.id, tier - 1)
				else family.prerequisite or Catalog.Roots[family.category]})
	end
end
for id, node in Catalog.Nodes do
	assert(node.prerequisite == nil or Catalog.Nodes[node.prerequisite], "Unknown prerequisite for " .. id)
end
do
	-- Two hexes may never share a cell inside one category map, and every hex touches
	-- the hex it needs (S9c: chains read without link lines).
	local cells = {}
	for id, node in Catalog.Nodes do
		local key = node.category .. ":" .. node.q .. ":" .. node.r
		assert(not cells[key], "Hex " .. key .. " is used by " .. tostring(cells[key]) .. " and " .. id)
		cells[key] = id
		local parent = node.prerequisite and Catalog.Nodes[node.prerequisite]
		if parent then
			local dq, dr = node.q - parent.q, node.r - parent.r
			assert(parent.category == node.category and math.max(math.abs(dq), math.abs(dr), math.abs(dq + dr)) == 1,
				"Hex " .. id .. " must touch " .. parent.id)
		end
	end
end

-- Saved tier for a family (missing or junk reads as 0), clamped to its ladder.
function Catalog.Tier(tree: any, familyId: string): number
	local family = Catalog.Families[familyId]
	local saved = if type(tree) == "table" then tree[familyId] else nil
	if not family or type(saved) ~= "number" or saved ~= saved then return 0 end
	return math.clamp(math.floor(saved), 0, #family.tiers)
end

-- The family's value at its saved tier (its base with no tier bought).
function Catalog.Value(tree: any, familyId: string): number
	local family = Catalog.Families[familyId]
	local tier = Catalog.Tier(tree, familyId)
	return if tier > 0 then family.tiers[tier].value else family.base
end

-- The authored yard expansion for the saved Flock tier.
function Catalog.YardStage(tree: any): number
	local tier = Catalog.Tier(tree, "Flock")
	return if tier > 0 then Catalog.Families.Flock.tiers[tier].yardStage or 0 else 0
end

-- P0 knob: tree prices may grow with Rebirth rank. 1 keeps the base quotes.
Catalog.RankPriceGrowth = 0
function Catalog.PriceScale(rank: number?): number
	local r = if type(rank) == "number" and rank == rank then math.max(0, math.floor(rank)) else 0
	return 1 + Catalog.RankPriceGrowth * r
end

-- Coins for `tier` of a family at Rebirth `rank` (whole Coins), or nil past the ladder.
function Catalog.Price(familyId: string, tier: number, rank: number?): number?
	local family = Catalog.Families[familyId]
	local entry = family and family.tiers[tier]
	if not entry then return nil end
	return math.ceil(entry.price * Catalog.PriceScale(rank))
end

local function decimal(value: number): string
	return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end

-- Default tooltip value for a family at `tier` (0 = nothing bought).
function Catalog.ValueText(familyId: string, tier: number): string
	local family = Catalog.Families[familyId]
	if not family then return "" end
	local value = if tier > 0 and family.tiers[tier] then family.tiers[tier].value else family.base
	local format = family.format
	if format == "multiplier" then return "x" .. decimal(value)
	elseif format == "percent" then return "+" .. decimal(value * 100) .. "%"
	elseif format == "reduction" then return decimal(value * 100) .. "% less damage taken"
	elseif format == "count" then return tostring(value) .. " " .. (family.unit or "")
	elseif format == "bonusCount" then return "+" .. tostring(value) .. " " .. (family.unit or "")
	elseif format == "studs" then return "+" .. decimal(value) .. " studs"
	elseif format == "seconds" then return "+" .. decimal(value) .. " s " .. (family.unit or "")
	elseif format == "hours" then return tostring(value) .. " h"
	elseif format == "level" then return if value > 0 then family.name .. " " .. (ROMAN[value] or tostring(value)) else "None"
	elseif format == "maxLevel" then return "Lv " .. (Config.MaxPetLevel + value)
	elseif format == "mutation" then
		local id = Mutations.Order[value]
		return if id then Mutations.Defs[id].name .. " chickens can roll" else "No mutations"
	end
	return if tier > 0 then "Unlocked" else "Locked"
end

-- Neutral values for every effect key (contract §5). Legacy research keys stay so
-- older readers never index nil; Call Army is free for everyone.
Catalog.DefaultEffects = table.freeze({
	damage = 0, health = 0, march = 0, armor = 0, recovery = 0, bossDamage = 0, rallySeconds = 0,
	callArmy = 1, fusion = 0, autoRoll = 0, production = 0, eggValue = 0, pickupStuds = 0, bounty = 0,
	offlineHours = 8, rollingLuck = 0, rollingSpeed = 0, speed = 0, slots = 1, capture = 0, walk = 0,
	formations = 0, operations = 0, holdCap = 0,
	flockSize = 3, eggVacuum = 0, vacuumCapacity = 0, vacuumRange = 0, chickenFeed = 0, goldMachine = 0, goldRate = 0,
	coinBoost = 0, gemBonus = 0, timeSkipMinutes = 0, keepTiers = 0, mutationLuck = 0,
	offlineEfficiency = 0, rebirthChickenChance = 0.01, autoRebirth = 0,
	-- S7b: Army slots from Gem Upgrades (on top of Army Size), and Chicken Feed levels
	-- above Config.MaxPetLevel from any source (S9c's Feed Max Level tiers).
	armySlots = 0, feedMaxLevel = 0,
	-- S9c: Diamond/Prism Rate tiers (GoldRolls) and how many mutations can roll.
	diamondRate = 0, prismRate = 0, mutations = 0,
	-- October 21 Auto Vacuum (EggService:UpdateRover).
	autoVacuum = 0, autoVacuumCapacity = 0, autoVacuumRange = 0, autoVacuumSpeed = 0,
})

-- Pure effect table for a saved tree and Gem Upgrade levels. The highest owned
-- tier of a family sets its effect; Gem Upgrades add on top.
function Catalog.Effects(tree: any, gemLevels: any): {[string]: number}
	local effects = table.clone(Catalog.DefaultEffects) :: {[string]: number}
	for _, id in Catalog.FamilyOrder do
		local family = Catalog.Families[id]
		local effect = family.effect
		local tier = Catalog.Tier(tree, id)
		if effect and tier > 0 then
			local value = family.tiers[tier].value
			effects[effect] = if effect == "goldMachine" then math.max(effects[effect], value) else value
		end
	end
	Gems.Apply(effects, gemLevels)
	return effects
end

-- Lenient save reader: known families only, tiers clamped; never fails a load.
function Catalog.ReadTree(value: any): {[string]: number}
	local result = {}
	if type(value) ~= "table" then return result end
	for id in Catalog.Families do
		local tier = Catalog.Tier(value, id)
		if tier > 0 then result[id] = tier end
	end
	return result
end

-- Compatibility views for readers that predate the tree (the old cash hexes,
-- PlotUpgradeService's yard stages). Remove once S9/S10 replace them.
Catalog.EggSpeedRates = {Catalog.Families.EggSpeed.base} :: {number}
Catalog.EggSpeedPrices = {} :: {number}
for index, entry in Catalog.Families.EggSpeed.tiers do
	Catalog.EggSpeedRates[index + 1] = entry.value
	Catalog.EggSpeedPrices[index] = entry.price
end
Catalog.RollSlotPrices = {} :: {number}
for index, entry in Catalog.Families.RollSlot.tiers do Catalog.RollSlotPrices[index] = entry.price end
-- The authored yard has eight stages (0-7). PlotPrices' length is the stage count
-- PlotUpgradeService reads; the prices themselves are no longer sold.
Catalog.PlotScales = {0.80, 0.87, 0.94, 1, 1.05, 1.10, 1.15, 1.20}
Catalog.PlotPrices = {480, 1200, 2400, 2880, 63000, 725760, 3628800}
Catalog.PlotCapacities = {25, 30, 35, 40, 45, 50, 75, 100}
function Catalog.PlotCapacity(level: number): number
	local index = math.clamp(math.floor(level) + 1, 1, #Catalog.PlotCapacities)
	return Catalog.PlotCapacities[index]
end
-- The six board keys of the pre-tree client, mapped to their family.
Catalog.LegacyKeys = {EggSpeed = "EggSpeed", PlotSize = "Flock", EggValue = "EggValue",
	ArmySize = "ArmySize", Luck = "Luck", RollSlots = "RollSlot"}

-- Egg Value and Luck multipliers by tier (Rules.EggUnitValue, ChickenLuck.Multiplier).
function Catalog.EggValueMultiplier(tier: number?): number
	local entries = Catalog.Families.EggValue.tiers
	local t = math.clamp(math.floor(tier or 0), 0, #entries)
	return if t > 0 then entries[t].value else Catalog.Families.EggValue.base
end
function Catalog.LuckMultiplier(tier: number?): number
	local entries = Catalog.Families.Luck.tiers
	local t = math.clamp(math.floor(tier or 0), 0, #entries)
	return if t > 0 then entries[t].value else Catalog.Families.Luck.base
end

for _, family in Catalog.Families do
	for _, entry in family.tiers do table.freeze(entry) end
	table.freeze(family.tiers)
	for _, position in family.positions do table.freeze(position) end
	table.freeze(family.positions)
	table.freeze(family)
end
for _, node in Catalog.Nodes do table.freeze(node) end
for _, list in Catalog.Order do table.freeze(list) end
table.freeze(Catalog.Order)
table.freeze(Catalog.Nodes)
table.freeze(Catalog.Families)
table.freeze(Catalog.FamilyOrder)
table.freeze(Catalog.Categories)
table.freeze(Catalog.Roots)
table.freeze(Catalog.LegacyKeys)
return Catalog
