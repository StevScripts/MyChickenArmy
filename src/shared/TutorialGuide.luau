--!strict
-- Snapshot-only guidance. Never changes prices, eligibility or player actions.
local Currency = require(script.Parent.CurrencyLimits)
local Tree = require(script.Parent.UpgradeCatalog)
local Guide = {}
-- October 21 (Stevin, from the Drop a Fruit recording): a short numbered core
-- (TUTORIAL 1/5: 5 eggs, sell, Flock Size I, a FREE roll and recruit), then numbered
-- tips (TIP 1/6: a FREE Egg Vacuum, Army Size I, Select Best, Cluck Camp). The guide
-- still completes on the first camp win. docs/team/COMMANDER_TUTORIAL.md has the contract.
Guide.Version = "cluck-7-quick-core"
-- Later October 21 (Stevin: "one-to-one" with the recording, keep it short): 3 eggs,
-- like its "Tap your fruits (0/3)". Each menu lesson also carries the words for the
-- step before it (`outside`: the menu or tool isn't open yet; `wrongTab`: the
-- Upgrades map shows another category), so the card reads one action at a time.
Guide.EggGoal = 3
-- Eggs the Egg Vacuum tip asks for (tutorial.vacuumEggCount, EggService).
Guide.VacuumGoal = 3
Guide.Core = {"Collect", "Sell", "Flock", "Roll", "Recruit"}
Guide.Tips = {"Vacuum", "VacuumUse", "Expand", "Select", "Deploy", "Win"}
Guide.Milestones = {"Collect", "Sell", "Roll", "Recruit", "Grow", "Flock", "Core", "Vacuum", "VacuumUse",
	"Expand", "Select", "Deploy", "Win"}

-- The Tutorial analytics funnel (Analytics, Schema.Funnels.Tutorial): entry, the
-- core lessons, the core payoff, then the tips. Append only; never reorder.
Guide.FunnelSteps = {"Started"}
for _, id in Guide.Core do table.insert(Guide.FunnelSteps, id) end
table.insert(Guide.FunnelSteps, "CoreDone")
for _, id in Guide.Tips do table.insert(Guide.FunnelSteps, id) end

function Guide.VacuumEggCount(tutorial): number
	local count = tutorial.vacuumEggCount
	if type(count) == "number" and count == count and count < math.huge then
		return math.clamp(math.floor(count), 0, Guide.VacuumGoal)
	end
	return if tutorial.vacuumUsed == true then Guide.VacuumGoal else 0
end

function Guide.CollectedEggCount(tutorial)
	local count = tutorial.collectedEggCount
	if type(count)=="number" and count==count and count<math.huge then
		return math.clamp(math.floor(count), 0, Guide.EggGoal)
	end
	-- Boolean-only snapshots retain their earned lesson. New profiles always
	-- carry a numeric count, so an early sale or a nonempty bag cannot bypass it.
	return if count==nil and (tutorial.collectedEggs==true or tutorial.guideCompleted==true) then Guide.EggGoal else 0
end

-- Flock Size from the snapshot (S10's state.flock), or nil before it existed.
local function flockSize(state): number?
	local flock = state.flock
	if type(flock) == "table" and type(flock.size) == "number" then return flock.size end
	local effects = state.effects
	return if type(effects) == "table" and type(effects.flockSize) == "number" then effects.flockSize else nil
end

function Guide.Facts(state)
	local t = state.tutorial or {}
	local won = t.wonCamp == true or (state.campsWon or 0) > 0 or state.kingCleared == true
	for _, value in state.firstWins or {} do if value then won = true end end
	local flock = flockSize(state)
	local tools = state.tools
	local facts = {
		Roll = t.rolled == true,
		-- The free squad must not count as completing the recruit lesson.
		Recruit = if t.starterArmy then t.bought == true
			else t.bought == true or #(state.pets or {}) >= (if t.emptyStart then 1 else 4),
		Collect = Guide.CollectedEggCount(t) >= Guide.EggGoal,
		Sell = t.soldEggs == true,
		Grow = #(state.pets or {}) >= 4,
		-- Flock Size I: four chickens lay (it starts at 3). A snapshot without it never blocks.
		Flock = flock == nil or flock >= 4,
		-- Owned now, or already used once (it resets on Rebirth). No tools snapshot never blocks.
		Vacuum = type(tools) ~= "table" or tools.eggVacuum == true or t.vacuumUsed == true,
		VacuumUse = type(tools) ~= "table" or Guide.VacuumEggCount(t) >= Guide.VacuumGoal,
		Expand = (state.capacity or 3) >= 4,
		Select = (state.selectedCount or #(state.selectedIds or {})) >= 4,
		Deploy = t.guideDeployed == true,
		Win = won,
	}
	-- The short core is done once (saved as tutorial.coreDone by TutorialService).
	facts.Core = t.coreDone == true or (facts.Collect and facts.Sell and facts.Flock and facts.Roll and facts.Recruit)
	return facts
end

-- "TUTORIAL 2/5" or "TIP 4/6" for the guide card: the lesson's place in its list,
-- counted from the lessons already done (lessons may finish out of order).
function Guide.Progress(facts): (string, number, number)
	local list, label = Guide.Core, "TUTORIAL"
	if facts.Core then list, label = Guide.Tips, "TIP" end
	local done = 0
	for _, id in list do if facts[id] then done += 1 end end
	return label, math.min(done + 1, #list), #list
end

local function step(id: string, text: string, target: string?, node: string?, outside: string?, wrongTab: string?)
	return {id=id, text=text, target=target, node=node, outside=outside, wrongTab=wrongTab}
end

-- A quiet post-guide line (CommanderGuide shows it as "Next: ...").
local function goal(key: string, text: string, where: string?, node: string?)
	local result = step("Goal:" .. key, text, where, node)
	result.goal = true
	return result
end

-- The server's quote for one Upgrades hex ({status, price?}), or nil before the tree.
local function treeNode(state, id: string?)
	local tree = state.upgradeTree
	local nodes = if type(tree) == "table" then tree.nodes else nil
	return if id and type(nodes) == "table" then nodes[id] else nil
end

-- The family's next Upgrades hex ("ArmySize1"), or nil once it is maxed.
function Guide.NextNode(state, familyId: string): string?
	local family = Tree.Families[familyId]
	if not family then return nil end
	local tree = state.upgradeTree
	local owned = if type(tree) == "table" and type(tree.families) == "table" then tree.families[familyId] else 0
	if type(owned) ~= "number" then owned = 0 end
	if owned >= #family.tiers then return nil end
	return Tree.NodeId(familyId, owned + 1)
end

-- Upgrades hexes in each map cell ("Main:-1:1" -> "Flock1").
local cellIds: {[string]: string} = {}
for id, node in Tree.Nodes do cellIds[node.category .. ":" .. node.q .. ":" .. node.r] = id end

-- October 20 playtest: an arrow beside a hex covered the next hex's name, because the
-- hexes are packed edge to edge. The arrow rests in an empty neighbour cell instead.
-- These are the six axial (q, r) neighbour steps; the client sorts them by where each
-- lands on screen (the map may draw its hexes pointy-top or flat-top).
Guide.PointerSides = {{1, 0}, {-1, 0}, {0, 1}, {-1, 1}, {1, -1}, {0, -1}}

-- The neighbour cell of an Upgrades hex where its arrow rests: the first in `order`
-- with no hex shown in it, else (with `coverable`) the first whose hex may be covered,
-- such as a "?" with no name. nil when there is none. `shown(id)` says whether a hex
-- is on the map now; `fits(side)` may reject a cell (the client skips the off-screen).
function Guide.PointerSide(nodeId: string, shown: (string) -> boolean, fits: ((side: {number}) -> boolean)?,
	order: {{number}}?, coverable: ((string) -> boolean)?): {number}?
	local node = Tree.Nodes[nodeId]
	if not node then return nil end
	local sides: {{number}} = order or Guide.PointerSides
	local function neighbour(side: {number}): string?
		return cellIds[node.category .. ":" .. (node.q + side[1]) .. ":" .. (node.r + side[2])]
	end
	for _, side in sides do
		local other = neighbour(side)
		if (other == nil or not shown(other)) and (fits == nil or fits(side)) then return side end
	end
	if coverable then
		for _, side in sides do
			local other = neighbour(side)
			if other ~= nil and shown(other) and coverable(other) and (fits == nil or fits(side)) then return side end
		end
	end
	return nil
end

-- Coins the player may spend right now (the starter reserve stays protected).
local function spendable(state): number
	return math.max(0, (state.coins or 0) - (state.starterCashReserve or 0))
end

-- `reserve`: Coins held back for another purchase (the starter Army Size earmark).
local function earn(state, price: number?, reserve: number?)
	local carried = (state.eggs or {}).carriedValue or 0
	local needed = if price then math.max(0, price + (reserve or 0) - (state.coins or 0)) else 1
	-- Keep gathering until this trip can fund the purchase. Any nonempty bag
	-- used to send players back to the pad, then straight back to the yard.
	if carried > 0 and carried >= needed then
		return step("RecoverSell", "Sell your eggs on the green pad!", "EggDeposit")
	end
	local more = math.ceil(needed - carried)
	return step("RecoverCollect",
		if price then "Collect eggs worth " .. Currency.Grouped(more) .. " more " .. (if more == 1 then "Coin" else "Coins")
			else "Collect eggs in your yard", "Yard")
end

local function recruit(state, growing)
	local count = #(state.pets or {})
	local id = if growing then "Grow" else "Recruit"
	local offer = state.offer
	-- October 21: the starter roll is FREE (Config.Economy.StarterRecruitPrice = 0).
	local free = (state.starterRecruitPrice or 0) <= 0 and (state.tutorial or {}).starterArmy == true
	if not offer then
		return step(if growing then id else "Roll", if growing then "Roll a chicken ("..count.."/4)"
			elseif free then "Pull the lever for a FREE chicken!" else "Pull the lever to roll", "RollStation")
	end
	if (offer.price or 0) > (state.coins or 0) then
		if count==0 then
			return step("Roll", "Roll again for free", "RollStation")
		end
		return earn(state, offer.price)
	end
	return step(id, if growing then "Buy a chicken ("..count.."/4)"
		elseif (offer.price or 0) <= 0 then "Grab your FREE chicken!" else "Buy the chicken", "RollStation")
end

-- One Upgrades purchase in the opening (Flock Size I, Army Size I): the hex, or a
-- trip to the eggs first when the server says it can't be afforded yet.
local OPEN_UPGRADES = {Flock = "Spend your Coins in Upgrades!", ArmySize = "Open Upgrades for more Army slots!"}
local function purchase(state, id: string, familyId: string, reserve: number?)
	local quote = treeNode(state, Guide.NextNode(state, familyId))
	if quote and quote.status == "Unaffordable" and type(quote.price) == "number"
		and quote.price + (reserve or 0) > (state.coins or 0) then
		return earn(state, quote.price, reserve)
	end
	local node = Guide.NextNode(state, familyId) or Tree.NodeId(familyId, 1)
	return step(id, "Buy " .. Tree.Nodes[node].name .. "!", "Upgrades", node,
		OPEN_UPGRADES[familyId] or "Open Upgrades!", "Go back to the main Upgrades!")
end

-- Army power vs a garrison's power (Rules.PetPower sums). Defenders respawn every
-- 10-15s and capture needs every guard down at once, so an even match usually
-- loses: below 1.3x reads Very tough, 1.3-2x a Close fight, 2x+ Should win.
Guide.CloseFightRatio = 1.3
Guide.ShouldWinRatio = 2
function Guide.Difficulty(power, enemyPower)
	if (enemyPower or 0) <= 0 then return "Undefended" end
	local ratio = (power or 0) / enemyPower
	if ratio >= Guide.ShouldWinRatio then return "Should win" end
	if ratio >= Guide.CloseFightRatio then return "Close fight" end
	return "Very tough"
end

local function target(state, id)
	for _, entry in state.targets or {} do if entry.id == id then return entry end end
	return nil
end

-- Compact cash for one-line goals: 950, 12.5K, 3M, 1.2B.
local CASH_STEPS: {number} = {1e12, 1e9, 1e6, 1e3}
local CASH_SUFFIXES: {string} = {"T", "B", "M", "K"}
local function shortCash(value: number?): string
	local amount = math.max(0, math.floor(value or 0))
	for index, size in CASH_STEPS do
		if amount >= size then
			local scaled = math.floor(amount / size * 10) / 10
			return (if scaled % 1 == 0 then tostring(math.floor(scaled)) else tostring(scaled)) .. CASH_SUFFIXES[index]
		end
	end
	return tostring(amount)
end

-- An open camp on another commander's lane, unless one is already held.
local function rivalCamp(state)
	if (state.holdCount or 0) >= (state.holdLimit or math.huge) then return nil end
	local open = nil
	for _, entry in state.targets or {} do
		if entry.kind == "Camp" and entry.laneOwnerName ~= nil then
			if entry.owned then return nil end
			if entry.available and not open then open = entry end
		end
	end
	return open
end

-- An Army chicken at home that Chicken Feed can level with the Coins on hand.
local function feedable(state): boolean
	local coins = spendable(state)
	for _, pet in state.pets or {} do
		if pet.selected and pet.canUpgrade and type(pet.upgradePrice) == "number" and pet.upgradePrice <= coins then
			return true
		end
	end
	return false
end

-- A podium offer that makes the picked Army stronger and can be bought now.
local function strongerOffer(state): boolean
	local coins = spendable(state)
	for _, offer in state.offers or {state.offer} do
		if offer.improvesArmy and type(offer.price) == "number" and offer.price <= coins then return true end
	end
	return false
end

-- The next camp or the King. October 20 launch review: winning Fort Roost on day 1
-- is what brings players back, and 71% of attacks were hopeless. When the odds read
-- Very tough, name the gap and the cheapest step that adds power. Never a gate.
local function attack(state, entry: any, where: string)
	local king = entry.id == "king:1"
	if Guide.Difficulty(state.power, entry.power) ~= "Very tough" then
		return goal("Attack:" .. entry.id, if king then "Challenge the Chicken King" else "Attack " .. entry.name, where)
	end
	local gap = "Army " .. shortCash(state.power) .. " / " .. (if king then "King" else entry.name) .. " "
		.. shortCash(entry.power) .. ": "
	local key = "Power:" .. entry.id .. ":"
	local tools = state.tools
	local fed = type(tools) == "table" and tools.chickenFeed == true
	if fed and feedable(state) then return goal(key .. "Feed", gap .. "feed your Army chickens", "FeedTool") end
	if strongerOffer(state) then return goal(key .. "Recruit", gap .. "buy the chicken on your podium", "RollStation") end
	local slots = Guide.NextNode(state, "ArmySize")
	local quote = treeNode(state, slots)
	if slots and quote and quote.status == "Available" and #(state.pets or {}) > (state.capacity or 3) then
		return goal(key .. "Slots", gap .. "buy " .. Tree.Nodes[slots].name .. " in Upgrades", "Upgrades", slots)
	end
	if fed then return goal(key .. "Earn", gap .. "sell eggs, then feed your Army chickens", "Yard") end
	return goal(key .. "Save", gap .. "sell eggs for Chicken Feed (Upgrades > Tools)", "Yard")
end

-- Upgrades > Tools tips: buy the Egg Vacuum (it resets on Rebirth), use it once,
-- buy Chicken Feed, and more Vacuum Capacity while the vacuum is full.
local function toolGoal(state, t: any)
	local tools = state.tools
	if type(tools) ~= "table" then return nil end
	if tools.eggVacuum ~= true then
		local quote = treeNode(state, "EggVacuum")
		if quote and quote.status == "Available" then
			return goal("Vacuum", "Buy the Egg Vacuum in Upgrades > Tools", "Upgrades", "EggVacuum")
		end
	elseif not t.vacuumUsed then
		return goal("EquipVacuum", "Equip your Egg Vacuum, then walk near your eggs", "VacuumTool")
	end
	if tools.chickenFeed ~= true then
		local quote = treeNode(state, "ChickenFeed")
		if quote and quote.status == "Available" then
			return goal("Feed", "Buy Chicken Feed in Upgrades > Tools", "Upgrades", "ChickenFeed")
		end
	end
	local vacuum = tools.vacuum
	if tools.eggVacuum == true and type(vacuum) == "table" and (vacuum.count or 0) >= math.max(1, vacuum.capacity or 0) then
		local node = Guide.NextNode(state, "VacuumCapacity")
		local quote = treeNode(state, node)
		if node and quote and quote.status == "Available" then
			return goal("Capacity", "Vacuum full? Buy Vacuum Capacity in Upgrades > Tools", "Upgrades", node)
		end
	end
	return nil
end

-- After the opening guide: one compact, snapshot-derived next goal. Never a
-- prerequisite; Coins upgrades and every target stay available as before.
-- ignoreSkip: the world NEXT marker predates the guide and stays for skipped players.
function Guide.NextGoal(state, ignoreSkip)
	if not state or state.saveStatus=="loading" or state.saveStatus=="error" then return nil end
	local t = state.tutorial or {}
	if t.guideSkipped and not ignoreSkip then return nil end -- Respect a hidden guide; Settings can resume it.
	-- October 9: goals are opt-out (Settings).
	if t.goalsHidden then return nil end
	if state.incoming then return nil end -- The battle UI owns this moment.
	-- Before `outgoing`: an army walking home still has its battle record.
	if state.armyState == "Returning" or state.armyState == "Recovering" then
		return goal("Return", "Collect eggs while your army returns", "Yard")
	end
	if state.outgoing then return nil end
	if #(state.pets or {}) == 0 then return goal("Recruit", "Roll a chicken at your podium", "RollStation") end
	if (state.selectedCount or #(state.selectedIds or {})) == 0 then return goal("Select", "My Army → Equip Best", "Army") end
	-- Rebirth v2 needs only Coins (50K for Rebirth 1) and the Army home. It resets the
	-- Upgrades tree, so it comes before the tool purchases (Stevin: only once ready).
	local rebirth = state.rebirth or {}
	if rebirth.enabled ~= false and rebirth.eligible == true and rebirth.nextRank then
		return goal("Rebirth", "Rebirth is ready! Open Rebirth on the right", "Rebirth")
	end
	local tool = toolGoal(state, t)
	if tool then return tool end
	if not state.kingCleared then
		local camps = state.routeCamps or {}
		for index = 1, 10 do
			local entry = target(state, "camp:" .. index)
			if not entry then break end
			if not camps[index] and not entry.owned then return attack(state, entry, "Camp" .. index) end
		end
		local king = not state.ownsKing and target(state, "king:1")
		return if king then attack(state, king, "KingArena") else nil
	end
	-- After the King: the first Mission win, then the next Rebirth, then rival camps.
	local operations = state.operations or {}
	local wins = operations.wins or {}
	if (operations.tier or 1) >= 1 and not (wins["1:1"] or wins["1:2"] or wins["1:3"]) then
		return goal("Operations", "Attack a loyalist site on the island", "Mission")
	end
	local cost = rebirth.cost
	if rebirth.enabled ~= false and rebirth.nextRank and type(cost) == "number" and cost > 0 then
		return goal("Rebirth:" .. tostring(rebirth.nextRank), "Rebirth " .. tostring(rebirth.nextRank) .. ": "
			.. shortCash(state.coins) .. " / " .. shortCash(cost) .. " Coins", nil)
	end
	if rivalCamp(state) then return goal("Rival", "Take a rival's camp for bonus egg value", nil) end
	return nil
end

-- The Collect lesson names the player's own input; the layout is the same everywhere.
local COLLECT = {Touch = "Tap your eggs to collect them!", Gamepad = "Press R2 to collect your eggs!"}

local function resolve(state, input: string?, t, f)
	if t.guideSkipped then return nil end
	if f.Win or t.guideCompleted then
		if not t.guideStarted then return nil end -- Established players are not forced through a new tutorial.
		return step("Complete", "Cluck Camp captured!", nil)
	end
	if state.incoming then
		return step("Defend", "Your army is defending", nil)
	end
	-- Before `outgoing`: an army walking home still has its battle record, and the
	-- launch review found this step never showed while it was checked second.
	if state.armyState == "Returning" or state.armyState == "Recovering" then
		if t.starterArmy and f.Sell then
			return step("Return", "Wait for your army to return", nil)
		end
		return step("Return", "Collect eggs while they return", "Yard")
	end
	if state.outgoing then
		return step("Battle", "Your army is fighting", nil)
	end
	-- Starter birds can teach income before recruiting. Legacy openings retain
	-- their recruit-first route, and an empty flock always needs an egg producer.
	if #(state.pets or {})==0 or (not t.starterArmy and not f.Recruit) then return recruit(state, false) end
	if not f.Collect then
		return step("Collect", (COLLECT[input or ""] or "Click your eggs to collect them!")
			.." ("..Guide.CollectedEggCount(t).."/"..Guide.EggGoal..")", "Yard")
	end
	if not f.Sell then
		if ((state.eggs or {}).carriedValue or 0) <= 0 then return earn(state) end
		return step("Sell", "Sell your eggs on the green pad!", "EggDeposit")
	end
	-- October 21: like the reference's Fruit Slot, Flock Size I opens a laying spot
	-- before the FREE roll fills it. It may not spend the Coins held for Army Size I
	-- (PlayerSession:CanSpendCash).
	if not f.Flock then return purchase(state, "Flock", "Flock", state.starterCashReserve) end
	if not f.Recruit then return recruit(state, false) end
	-- The new squad already has four birds after Recruit. Older empty-yard saves
	-- can still grow their flock without resetting or granting them extra birds.
	if not f.Grow then return recruit(state, true) end
	-- Tips. The Egg Vacuum is FREE while the guide runs (UpgradeService.Quote).
	if not f.Vacuum then
		local node = treeNode(state, "EggVacuum")
		if node == nil or node.status ~= "Locked" then
			return step("Vacuum", "Claim your FREE Egg Vacuum!", "Upgrades", "EggVacuum",
				"Open Upgrades for a FREE Egg Vacuum!", "Open the Tools category!")
		end
	elseif not f.VacuumUse then
		return step("VacuumUse", "Walk near eggs to vacuum them up! ("
			.. Guide.VacuumEggCount(state.tutorial or {}) .. "/" .. Guide.VacuumGoal .. ")", "VacuumTool", nil,
			"Equip your Egg Vacuum!")
	end
	if not f.Expand then
		local offer = state.nextSlot
		if offer and (state.coins or 0) < offer.price then return earn(state, offer.price) end
		return purchase(state, "Expand", "ArmySize")
	end
	if not f.Select then
		return step("Select", "Press Equip Best!", "Army", nil, "Open My Army!")
	end
	return step("Deploy", "Send your Army to Cluck Camp!", "Camp1")
end

-- input: "Touch", "Gamepad" or anything else for mouse and keyboard (CommanderGuide).
-- Each lesson carries its place: tag "TUTORIAL" or "TIP", index and total.
function Guide.Resolve(state, input: string?)
	if not state or state.saveStatus=="loading" or state.saveStatus=="error" then return nil end
	local t, f = state.tutorial or {}, Guide.Facts(state)
	local result = resolve(state, input, t, f)
	if result and result.id ~= "Complete" then
		result.tag, result.index, result.total = Guide.Progress(f)
	end
	return result
end

return Guide
