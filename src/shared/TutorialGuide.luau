--!strict
-- Snapshot-only guidance. Never changes prices, eligibility or player actions.
local Currency = require(script.Parent.CurrencyLimits)
local Tree = require(script.Parent.UpgradeCatalog)
local Guide = {}
-- Latest October 21 (Stevin: "keep the tutorial as SHORT as possible"): only the three
-- systems a new player needs, as one numbered list "TUTORIAL • n/7": click eggs and
-- sell them, roll a chicken, then claim, use and sell with the Egg Vacuum. The guide
-- completes there (no Flock Size I, no Army or Cluck Camp lessons). Later the same day
-- (Stevin): no instructions at all after the tutorial; the post-guide Next goals are
-- gone. docs/team/COMMANDER_TUTORIAL.md has the contract.
Guide.Version = "cluck-8-essentials"
-- Later October 21 (Stevin: "one-to-one" with the recording, keep it short): 3 eggs,
-- like its "Tap your fruits (0/3)". Each menu lesson also carries the words for the
-- step before it (`outside`: the menu or tool isn't open yet; `wrongTab`: the
-- Upgrades map shows another category), so the card reads one action at a time.
Guide.EggGoal = 3
-- Eggs the Egg Vacuum tip asks for (tutorial.vacuumEggCount, EggService). Later
-- October 21 (Stevin): vacuum 20, then sell them on the pad (tutorial.vacuumSold).
Guide.VacuumGoal = 20
Guide.Core = {"Collect", "Sell", "Roll", "Recruit", "Vacuum", "VacuumUse", "VacuumSell"}
Guide.Milestones = {"Collect", "Sell", "Roll", "Recruit", "Grow", "Flock", "Core", "Vacuum", "VacuumUse",
	"VacuumSell", "Expand", "Select", "Deploy", "Win"}
-- The analytics funnel for this guide is Schema.TutorialFunnel (server, version 11).
-- The last card, also the payoff line with the confetti (CommanderGuide).
Guide.CompleteText = "Keep collecting eggs and rolling chickens!"

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
		-- A pad sale carrying vacuum eggs once the 20 are in (EggService).
		VacuumSell = type(tools) ~= "table" or t.vacuumSold == true,
		Expand = (state.capacity or 3) >= 4,
		Select = (state.selectedCount or #(state.selectedIds or {})) >= 4,
		Deploy = t.guideDeployed == true,
		Win = won,
	}
	-- The whole tutorial is done once (saved as tutorial.coreDone by TutorialService).
	local core = t.coreDone == true
	if not core then
		core = true
		for _, id in Guide.Core do if not facts[id] then core = false end end
	end
	facts.Core = core
	return facts
end

-- "TUTORIAL 2/7" for the guide card: the lesson's place in the list, counted from
-- the lessons already done (lessons may finish out of order).
function Guide.Progress(facts): (string, number, number)
	local done = 0
	for _, id in Guide.Core do if facts[id] then done += 1 end end
	return "TUTORIAL", math.min(done + 1, #Guide.Core), #Guide.Core
end

local function step(id: string, text: string, target: string?, node: string?, outside: string?, wrongTab: string?)
	return {id=id, text=text, target=target, node=node, outside=outside, wrongTab=wrongTab}
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
			elseif free then "Pull the lever for a chicken!" else "Pull the lever to roll", "RollStation")
	end
	if (offer.price or 0) > (state.coins or 0) then
		if count==0 then
			return step("Roll", "Roll again for free", "RollStation")
		end
		return earn(state, offer.price)
	end
	return step(id, if growing then "Buy a chicken ("..count.."/4)"
		elseif (offer.price or 0) <= 0 then "Grab your chicken!" else "Buy the chicken", "RollStation")
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

-- The Collect lesson names the player's own input; the layout is the same everywhere.
local COLLECT = {Touch = "Tap your eggs to collect them!", Gamepad = "Press R2 to collect your eggs!"}

local function resolve(state, input: string?, t, f)
	if t.guideSkipped then return nil end
	if f.Core or f.Win or t.guideCompleted then
		if not t.guideStarted then return nil end -- Established players are not forced through a new tutorial.
		return step("Complete", Guide.CompleteText, nil)
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
	if not f.Recruit then return recruit(state, false) end
	-- The new squad already has four birds after Recruit. Older empty-yard saves
	-- can still grow their flock without resetting or granting them extra birds.
	if not f.Grow then return recruit(state, true) end
	-- The Egg Vacuum costs 0 while the guide runs (UpgradeService.Quote).
	if not f.Vacuum then
		return step("Vacuum", "Claim your Egg Vacuum!", "Upgrades", "EggVacuum",
			"Open Upgrades for an Egg Vacuum!", "Open the Tools category!")
	elseif not f.VacuumUse then
		-- A full vacuum stops pulling eggs in: sell, then keep going.
		local vacuum = type(state.tools) == "table" and state.tools.vacuum or nil
		if type(vacuum) == "table" and (vacuum.capacity or 0) > 0 and (vacuum.count or 0) >= vacuum.capacity then
			return step("VacuumUse", "Vacuum full! Sell your eggs on the green pad!", "EggDeposit")
		end
		return step("VacuumUse", "Walk near eggs to vacuum them up! ("
			.. Guide.VacuumEggCount(state.tutorial or {}) .. "/" .. Guide.VacuumGoal .. ")", "VacuumTool", nil,
			"Equip your Egg Vacuum!")
	end
	return step("VacuumSell", "Sell your vacuumed eggs on the green pad!", "EggDeposit")
end

-- input: "Touch", "Gamepad" or anything else for mouse and keyboard (CommanderGuide).
-- Each lesson carries its place: tag "TUTORIAL", index and total.
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
