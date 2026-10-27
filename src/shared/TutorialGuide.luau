--!strict
-- Snapshot-only guidance. Never changes prices, eligibility or player actions.
local Config = require(script.Parent.Config)
local Currency = require(script.Parent.CurrencyLimits)
local Tree = require(script.Parent.UpgradeCatalog)
local Progression = require(script.Parent.Progression)
local Guide = {}
-- Latest October 21 (Stevin: "keep the tutorial as SHORT as possible"): only the three
-- systems a new player needs, as one numbered list "TUTORIAL • n/7": click eggs and
-- sell them, roll a chicken, then claim, use and sell with the Egg Vacuum. The guide
-- completes there (no Flock Size I, no Army or Cluck Camp lessons). Later the same day
-- (Stevin): no instructions at all after the tutorial; the post-guide Next goals are
-- gone. docs/team/COMMANDER_TUTORIAL.md has the contract.
-- Later October 21 (Stevin, from his reference recording): one last lesson, conquer a
-- Camp. The guide walks the player to Cluck Camp, they send their Army, a short film
-- follows the march (MarchFilm) and the win completes the tutorial: "TUTORIAL • n/8".
-- October 23 empty start (supersedes the two notes above; Stevin, from the Drop a Fruit
-- recording): a fresh profile has no chickens and 0 Coins, and the guide is six lessons
-- "TUTORIAL • n/6": pull the lever, grab the chicken, click 3 eggs, sell them, claim
-- Start in Upgrades, buy Flock Size I (it grows the yard). The Egg Vacuum, the first
-- Camp and Rebirth 0 follow as tips ("TIP • n/N", Guide.Tips) once it is done.
-- October 24 (Stevin): a seventh card, pull the lever again; eggs lay every second until
-- the tutorial completes (PlayerSession.LaySeconds). October 25 (Stevin): card 7 "Roll
-- another chicken!" keeps the basic Chicken on the podium at 20 Coins
-- (Config.Economy.StarterLadder, RollService) and card 8 recruits it, with the arrow to
-- the eggs and the pad whenever the Coins are short; the tutorial completes on that
-- recruit, then Daily Rewards opens. The next five pulls favour the basic Chicken.
Guide.Version = "empty-8-recruit"
-- Later October 21 (Stevin: "one-to-one" with the recording, keep it short): 3 eggs,
-- like its "Tap your fruits (0/3)". Each menu lesson also carries the words for the
-- step before it (`outside`: the menu or tool isn't open yet; `wrongTab`: the
-- Upgrades map shows another category), so the card reads one action at a time.
Guide.EggGoal = 3
-- Eggs the Egg Vacuum tip asks for (tutorial.vacuumEggCount, EggService). Later
-- October 21 (Stevin): vacuum 20, then sell them on the pad (tutorial.vacuumSold).
Guide.VacuumGoal = 20
Guide.Core = {"Roll", "Recruit", "Collect", "Sell", "Start", "Expand", "RollAgain", "Recruit2"}
-- Facts whose first flip is an FTUE milestone (TutorialService) and, during a lesson,
-- the card's "done!" tick (CommanderGuide). The old lessons stay for their events.
Guide.Milestones = {"Roll", "Recruit", "Collect", "Sell", "Start", "Expand", "RollAgain", "Recruit2",
	"Flock", "Grow", "Core", "Vacuum",
	"VacuumUse", "VacuumSell", "Select", "Deploy", "Win"}
-- The analytics funnel for this guide is Schema.Onboarding (server, schema 15; docs/analytics/ONBOARDING_FUNNEL.md).
-- The last card, also the payoff line with the confetti (CommanderGuide).
Guide.CompleteText = "Your yard is up and running. Keep collecting!"
-- Tips (October 23; retimed October 24-25, Stevin). The Egg Vacuum is free and its tip
-- offers it once the player has collected VacuumTipEggs more eggs by hand after the tutorial
-- completed (tutorial.eggsAtComplete, set by TutorialService; counted on the chain's first
-- card since October 27), then it counts
-- VacuumTipGoal vacuumed eggs (the saved count still runs to VacuumGoal for the funnel)
-- and ends with the sale of those eggs on the pad (tutorial.vacuumSold). The Camp tip waits
-- for an Army of ArmyTipSize and a player a little settled in: VacuumGoal eggs vacuumed, or
-- ArmyTipEggs eggs collected by hand without the vacuum. The Gem Upgrade card leaves after
-- GemTipSeconds on screen.
Guide.VacuumTipEggs = 12
Guide.VacuumTipGoal = 10
Guide.ArmyTipSize = 3
Guide.ArmyTipEggs = 60
Guide.GemTipSeconds = 20
-- Lever pulls, saved as tutorial.rollCount up to this (RollService, PlayerSession).
Guide.RollCountLimit = 10

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

-- Eggs collected by hand so far, counting on past the lesson's EggGoal (the server
-- saves up to PlayerSession.TutorialEggLimit). The Egg Vacuum tip reads it.
function Guide.EggsCollected(tutorial): number
	local count = tutorial.collectedEggCount
	if type(count) == "number" and count == count and count < math.huge then
		return math.max(0, math.floor(count))
	end
	return Guide.CollectedEggCount(tutorial)
end

-- Lever pulls so far (tutorial.rollCount). Saves from before the counter: a finished
-- guide has pulled enough; otherwise the old `rolled` flag counts as one pull.
function Guide.RollCount(tutorial: any): number
	local count = tutorial.rollCount
	if type(count) == "number" and count == count and count < math.huge then
		return math.clamp(math.floor(count), 0, Guide.RollCountLimit)
	end
	if tutorial.guideCompleted == true or tutorial.coreDone == true then return Guide.RollCountLimit end
	return if tutorial.rolled == true then 1 else 0
end

-- Eggs by hand when the tutorial completed (tutorial.eggsAtComplete). A finished save
-- without the field counts from the lesson's EggGoal.
function Guide.EggsAtComplete(tutorial: any): number
	local count = tutorial.eggsAtComplete
	if type(count) == "number" and count == count and count >= 0 and count < math.huge then
		return math.floor(count)
	end
	return Guide.EggGoal
end

-- Flock Size I and up from the snapshot's Upgrades tree tiers, or nil without them.
local function flockTier(state): number?
	local tree = state.upgradeTree
	local families = if type(tree) == "table" then tree.families else nil
	local tier = if type(families) == "table" then families.Flock else nil
	return if type(tier) == "number" then tier else nil
end

-- Flock Size from the snapshot (S10's state.flock), or nil before it existed.
local function flockSize(state): number?
	local flock = state.flock
	if type(flock) == "table" and type(flock.size) == "number" then return flock.size end
	local effects = state.effects
	return if type(effects) == "table" and type(effects.flockSize) == "number" then effects.flockSize else nil
end

function Guide.Facts(state)
	local t: any = state.tutorial or {}
	local won = t.wonCamp == true or (state.campsWon or 0) > 0 or state.kingCleared == true
	for _, value in state.firstWins or {} do if value then won = true end end
	local flock = flockSize(state)
	local tier = flockTier(state)
	local tools = state.tools
	local facts = {
		Roll = t.rolled == true,
		-- The free squad must not count as completing the recruit lesson.
		Recruit = if t.starterArmy then t.bought == true
			else t.bought == true or #(state.pets or {}) >= (if t.emptyStart then 1 else 4),
		Collect = Guide.CollectedEggCount(t) >= Guide.EggGoal,
		Sell = t.soldEggs == true,
		-- October 23: the Upgrades centre hex is claimed once (UpgradeService, tutorial.startClaimed).
		Start = t.startClaimed == true,
		-- October 23: Flock Size I (tree tier 1) is the last lesson; it grows the yard one
		-- stage. Without tree tiers, Flock Size 4 means the same; neither never blocks.
		Expand = if tier ~= nil then tier >= 1 else (flock == nil or flock >= 4),
		-- October 24: card 7, the lever pulled a second time (the offer may stay on the podium).
		RollAgain = Guide.RollCount(t) >= 2,
		-- October 25: card 8, the second chicken (the basic Chicken at 20, RollService).
		Recruit2 = #(state.pets or {}) >= 2,
		Grow = #(state.pets or {}) >= 4,
		-- Flock Size I: four chickens lay (it starts at 3). A snapshot without it never blocks.
		Flock = flock == nil or flock >= 4,
		-- Owned now, or already used once (it resets on Rebirth). No tools snapshot never blocks.
		Vacuum = type(tools) ~= "table" or tools.eggVacuum == true or t.vacuumUsed == true,
		VacuumUse = type(tools) ~= "table" or Guide.VacuumEggCount(t) >= Guide.VacuumGoal,
		-- A pad sale carrying vacuum eggs once the 20 are in (EggService).
		VacuumSell = type(tools) ~= "table" or t.vacuumSold == true,
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

-- A tip card (October 23). Each line it can show counts in its chain's "TIP • n/N":
-- `index` numbers its own text, `outsideIndex`/`wrongTabIndex` the lines shown while
-- its menu is closed or the Upgrades map shows another category (CommanderGuide).
local function tipCard(id: string, text: string, index: number, target: string?, node: string?,
	outside: string?, outsideIndex: number?, wrongTab: string?, wrongTabIndex: number?): any
	local card: any = step(id, text, target, node, outside, wrongTab)
	card.index, card.outsideIndex, card.wrongTabIndex = index, outsideIndex, wrongTabIndex
	return card
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
			-- October 23: no "free" wording in the tutorial (Oct 21 rule).
			return step("Roll", "Pull the lever again!", "RollStation")
		end
		return earn(state, offer.price)
	end
	return step(id, if growing then "Buy a chicken ("..count.."/4)"
		elseif (offer.price or 0) <= 0 then "Grab your chicken!" else "Buy the chicken", "RollStation")
end

-- October 24 (Stevin): the egg click badges and the lit egg stay on from the first chicken
-- through the tutorial and the first tips, until the Egg Vacuum is owned (then the vacuum
-- collects). After the guide only empty-start profiles (introRebirth set) keep them, so
-- older players never get badges on their eggs.
function Guide.EggHint(state, f): boolean
	local t: any = state.tutorial or {}
	if t.guideSkipped == true then return false end
	local tools = state.tools
	if type(tools) == "table" and tools.eggVacuum == true then return false end
	if t.vacuumUsed == true or not f.Recruit then return false end
	if f.Core or t.guideCompleted == true then return state.introRebirth ~= nil end
	return true
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

-- The second chicken (October 25): the podium's offer when the Coins cover it, else
-- collect and sell until they do; no offer on the podium means roll again.
local function nextChicken(state)
	local offer = state.offer
	if not offer then return step("RollMore", "Roll another chicken!", "RollStation") end
	if (offer.price or 0) > (state.coins or 0) then return earn(state, offer.price) end
	return step("BuyChicken", "Buy the chicken!", "RollStation")
end

-- The Collect lesson names the player's own input; the layout is the same everywhere.
local COLLECT = {Touch = "Tap your eggs to collect them!", Gamepad = "Press R2 to collect your eggs!"}
-- The Start and Flock Size I hexes are on the main Upgrades map.
local MAIN_TAB = "Open the Main category!"

-- The server's offer for an Upgrades hex (state.upgradeTree.nodes), or nil.
local function nodeOffer(state, id: string): any
	local tree = state.upgradeTree
	local nodes = if type(tree) == "table" then tree.nodes else nil
	local offer = if type(nodes) == "table" then nodes[id] else nil
	return if type(offer) == "table" then offer else nil
end

-- Rebirth 0 (Config.Rebirth.Intro): its price and the "×1.5" it pays.
local function intro(): any
	local rebirth: any = Config.Rebirth
	return if type(rebirth) == "table" and type(rebirth.Intro) == "table" then rebirth.Intro else {}
end
local function introCost(): number
	local cost = intro().Cost
	return if type(cost) == "number" then cost else 350
end
local function introMultiplier(): string
	local value = intro().Multiplier
	return "×" .. (string.format("%.2f", if type(value) == "number" then value else 1.5):gsub("0+$", ""):gsub("%.$", ""))
end

-- October 23 tips (Stevin, from the reference recording): short non-blocking chains
-- once the tutorial is done, each card "TIP • n/N" and a "TIP • COMPLETE!" payoff
-- with the chain's `payoff` line (CommanderGuide). In priority order: Rebirth 0 once it
-- is affordable, the first Camp once the Army holds ArmyTipSize chickens, the Egg
-- Vacuum once the Coins reach its price. `when` says the chain shows now
-- (starting or in progress), `done` that it is learned, `card` picks its current card
-- from `cards`. Snapshot-only, like the lessons; never while the Army is away.
local REBIRTH_CARDS = {
	Rebirth = tipCard("TipRebirth", "Tap Rebirth! Coins & Upgrades reset, but you keep " .. introMultiplier() .. " Coins forever!",
		2, "Rebirth", nil, "Rebirth is ready! Open it to earn " .. introMultiplier() .. " Coins forever!", 1),
	-- The Gem Upgrades in the Rebirth screen; it leaves after GemTipSeconds on screen.
	Gems = tipCard("TipGems", "Pick a Gem Upgrade. They never reset!", 3, "Gems"),
}
REBIRTH_CARDS.Gems.seconds = Guide.GemTipSeconds
local ATTACK_CARDS = {Attack = tipCard("TipAttack", "Send your Army to attack Cluck Camp!", 1, "Camp1")}
local VACUUM_CARDS = {
	-- October 27 (live data, TUTORIAL_FIXES_20261027.md): most finishers left within 20 s,
	-- with no card for the VacuumTipEggs wait. The wait is the chain's first card; its text
	-- gains the count "(n/12)".
	Eggs = tipCard("TipVacuumEggs", "Collect eggs for an Egg Vacuum!", 1, "Yard"),
	Buy = tipCard("TipVacuum", "Claim your Egg Vacuum!", 4, "Upgrades", "EggVacuum",
		"Open Upgrades for an Egg Vacuum!", 2, "Open the Tools category!", 3),
	-- Its text gains the count "(n/10)".
	Use = tipCard("TipVacuumUse", "Walk near eggs to vacuum them up!", 6, "VacuumTool", nil, "Equip your Egg Vacuum!", 5),
	-- A full vacuum stops pulling eggs in: sell, then keep going.
	Full = tipCard("TipVacuumUse", "Vacuum full! Sell your eggs on the green pad!", 6, "EggDeposit"),
	-- October 25 (Stevin): the chain ends by selling what was vacuumed.
	Sell = tipCard("TipVacuumSell", "Sell your eggs on the green pad!", 7, "EggDeposit"),
}

-- October 26 (Stevin): once Cluck Camp is won, point at the next camp on the route.
-- A timed card per camp (NextCampTipSeconds, once a visit, no payoff when it times
-- out); BaseController keeps a NEXT marker over that camp until it is won.
Guide.NextCampTipSeconds = 10
local NEXT_CAMP_CARDS = {}
for index = 2, #Progression.Camps(1) do
	local card = tipCard("TipNextCamp" .. index, "Next up: conquer " .. Progression.Camps(1)[index].name .. "!", 1, "Camp" .. index)
	card.seconds = Guide.NextCampTipSeconds
	NEXT_CAMP_CARDS[index] = card
end
-- The first main-route camp not won yet after Cluck Camp, or nil.
function Guide.NextCamp(state: any): number?
	local wins = state.firstWins
	if type(wins) ~= "table" or wins[1] ~= true then return nil end
	for index = 2, #Progression.Camps(1) do
		if wins[index] ~= true then return index end
	end
	return nil
end

local function gemsSpent(state: any): boolean
	return (tonumber(state.gemsEarned) or 0) > (tonumber(state.gems) or 0)
end

local TIPS: {any} = {
	{id = "Rebirth", payoff = "Rebirth learned!", total = 3, cards = REBIRTH_CARDS,
		when = function(_f: any, state: any): boolean
			if (state.tutorial or {}).guideCompleted ~= true then return false end
			if state.introRebirth == "pending" then
				local quote = state.rebirth
				return (state.coins or 0) >= introCost() and not (type(quote) == "table" and quote.eligible == false)
			end
			local quote = state.rebirth
			local rank = if type(quote) == "table" then tonumber(quote.rank) or 0 else 0
			return state.introRebirth == "done" and rank == 0 and (tonumber(state.gems) or 0) > 0
		end,
		done = function(_f: any, state: any): boolean return state.introRebirth == "done" and gemsSpent(state) end,
		card = function(_f: any, state: any): any
			return table.clone(if state.introRebirth == "pending" then REBIRTH_CARDS.Rebirth else REBIRTH_CARDS.Gems)
		end},
	{id = "Attack", payoff = "Camp captured!", total = 1, cards = ATTACK_CARDS,
		when = function(f: any, state: any): boolean
			local t: any = state.tutorial or {}
			local army = tonumber(state.selectedCount) or #(state.selectedIds or {})
			-- October 24 (Stevin): not right after the vacuum, once the player is a little
			-- settled: a load of vacuumed eggs sold, or ArmyTipEggs eggs by hand.
			local settled = Guide.VacuumEggCount(t) >= Guide.VacuumGoal or Guide.EggsCollected(t) >= Guide.ArmyTipEggs
			return t.guideCompleted == true and not f.Win and army >= Guide.ArmyTipSize and settled
		end,
		done = function(f: any, _state: any): boolean return f.Win == true end,
		card = function(_f: any, _state: any): any return table.clone(ATTACK_CARDS.Attack) end},
	{id = "Vacuum", payoff = "Vacuum learned!", total = 7, cards = VACUUM_CARDS,
		when = function(_f: any, state: any): boolean
			local t: any, tools = state.tutorial or {}, state.tools
			if t.guideCompleted ~= true or type(tools) ~= "table" then return false end
			if tools.eggVacuum == true then return true end
			if t.vacuumUsed == true then return false end
			-- The free vacuum's offer reads Available. October 27: the chain starts at
			-- completion with the VacuumTipEggs count (October 25 kept it untold).
			local offer = nodeOffer(state, "EggVacuum")
			return offer == nil or offer.status == "Available"
		end,
		done = function(_f: any, state: any): boolean return (state.tutorial or {}).vacuumSold == true end,
		card = function(_f: any, state: any): any
			local tools, t = state.tools, state.tutorial or {}
			if tools.eggVacuum ~= true then
				-- October 25 (Stevin): VacuumTipEggs more eggs by hand since the tutorial completed.
				local since = Guide.EggsCollected(t) - Guide.EggsAtComplete(t)
				if since < Guide.VacuumTipEggs then
					local card: any = table.clone(VACUUM_CARDS.Eggs)
					card.text ..= " (" .. math.max(0, since) .. "/" .. Guide.VacuumTipEggs .. ")"
					return card
				end
				return table.clone(VACUUM_CARDS.Buy)
			end
			-- The eggs are in: sell them (the chain's last card).
			if Guide.VacuumEggCount(t) >= Guide.VacuumTipGoal then return table.clone(VACUUM_CARDS.Sell) end
			local vacuum = tools.vacuum
			if type(vacuum) == "table" and (vacuum.capacity or 0) > 0 and (vacuum.count or 0) >= vacuum.capacity then
				return table.clone(VACUUM_CARDS.Full)
			end
			local card: any = table.clone(VACUUM_CARDS.Use)
			local count = math.min(Guide.VacuumEggCount(state.tutorial or {}), Guide.VacuumTipGoal)
			card.text ..= " (" .. count .. "/" .. Guide.VacuumTipGoal .. ")"
			return card
		end},
	-- Last, so it never interrupts another chain. quietEnd: a timed-out card is no payoff.
	{id = "NextCamp", payoff = "Camp captured!", total = 1, cards = NEXT_CAMP_CARDS, quietEnd = true,
		when = function(_f: any, state: any): boolean
			return (state.tutorial or {}).guideCompleted == true and Guide.NextCamp(state) ~= nil
		end,
		done = function(_f: any, state: any): boolean return Guide.NextCamp(state) == nil end,
		card = function(_f: any, state: any): any return table.clone(NEXT_CAMP_CARDS[Guide.NextCamp(state) :: number]) end},
}
Guide.Tips = TIPS

-- The first tip to show now (its card with tag "TIP", index, total and chain), or nil.
-- `skip` holds card ids the client has dismissed (CommanderGuide's timed cards).
local function tip(state: any, f: any, skip: {[string]: boolean}?): any
	local away = state.incoming or state.outgoing
		or (state.armyState ~= nil and state.armyState ~= "Home" and state.armyState ~= "Following")
	if away then return nil end
	for _, chain in Guide.Tips do
		if not chain.done(f, state) and chain.when(f, state) then
			local card = chain.card(f, state)
			if not (skip and skip[card.id]) then
				card.tag, card.total, card.chain = "TIP", chain.total, chain.id
				return card
			end
		end
	end
	return nil
end

local function resolve(state, input: string?, t, f, skip: {[string]: boolean}?): any
	if t.guideSkipped then return nil end
	if f.Core or f.Win or t.guideCompleted then
		if not t.guideStarted then return nil end -- Established players are not forced through a new tutorial.
		-- October 23: a tip once one is ready, else the completion card.
		return tip(state, f, skip) or step("Complete", Guide.CompleteText, nil)
	end
	if state.incoming then
		return step("Defend", "Your Army is defending", nil)
	end
	-- Before `outgoing`: an army walking home still has its battle record, and the
	-- launch review found this step never showed while it was checked second.
	if state.armyState == "Returning" or state.armyState == "Recovering" then
		if t.starterArmy and f.Sell then
			return step("Return", "Wait for your Army to return", nil)
		end
		return step("Return", "Collect eggs while they return", "Yard")
	end
	if state.outgoing then
		-- The reference's line once the troops are sent (lesson 8 waits for the win).
		return step("Battle", "Defeat the enemy and capture their Camp!", nil)
	end
	-- October 23 order: an empty yard rolls and takes its first chicken (lessons 1-2),
	-- then clicks 3 eggs and sells them (3-4). Legacy starter saves with birds keep
	-- their eggs-first route and take a chicken after selling.
	if #(state.pets or {})==0 or (not t.starterArmy and not f.Recruit) then return recruit(state, false) end
	if not f.Collect then
		return step("Collect", (COLLECT[input or ""] or "Click your eggs to collect them!")
			.." ("..Guide.CollectedEggCount(t).."/"..Guide.EggGoal..")", "Yard")
	end
	if not f.Sell then
		if ((state.eggs or {}).carriedValue or 0) <= 0 then return earn(state) end
		return step("Sell", "Sell your eggs on the green pad!", "EggDeposit")
	end
	if not f.Recruit or not f.Roll then return recruit(state, false) end
	-- Lesson 5: claim the Upgrades centre hex (no price, once; UpgradeService).
	if not f.Start then
		return step("Start", "Claim Start!", "Upgrades", "Start", "Open Upgrades!", MAIN_TAB)
	end
	-- Lesson 6: Flock Size I grows the yard. Short of its price, collect and sell first.
	if not f.Expand then
		local offer = nodeOffer(state, "Flock1")
		local price = if offer and offer.status ~= "Owned" and type(offer.price) == "number" then offer.price else nil
		if price and price > (state.coins or 0) then return earn(state, price) end
		return step("Expand", "Expand your plot!", "Upgrades", "Flock1", "Open Upgrades!", MAIN_TAB)
	end
	-- Lesson 7 (October 24-25): roll once more ("Roll another chicken!", Stevin's words).
	if not f.RollAgain then return step("RollAgain", "Roll another chicken!", "RollStation") end
	-- Lesson 8 (October 25, Stevin): recruit it; the lever put the basic Chicken on the podium
	-- at 20 (RollService). Short of the price, the arrow goes to the eggs and the pad first
	-- (earn), then back to the podium. The tutorial completes on this recruit.
	return nextChicken(state)
end

-- input: "Touch", "Gamepad" or anything else for mouse and keyboard (CommanderGuide).
-- Each lesson carries its place: tag "TUTORIAL", index and total; a tip card carries
-- its own (tag "TIP"). `skip`: tip card ids the client dismissed (CommanderGuide).
function Guide.Resolve(state, input: string?, skip: {[string]: boolean}?): any
	if not state or state.saveStatus=="loading" or state.saveStatus=="error" then return nil end
	local t, f = state.tutorial or {}, Guide.Facts(state)
	local result = resolve(state, input, t, f, skip)
	if result and result.id ~= "Complete" and result.tag == nil then
		result.tag, result.index, result.total = Guide.Progress(f)
	end
	return result
end

return Guide
