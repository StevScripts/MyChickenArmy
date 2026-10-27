--!strict
-- Snapshot-only guidance. Never changes prices, eligibility or player actions.
local Config = require(script.Parent.Config)
local Currency = require(script.Parent.CurrencyLimits)
local Tree = require(script.Parent.UpgradeCatalog)
local Progression = require(script.Parent.Progression)
local PetCatalog = require(script.Parent.PetCatalog)
local Guide = {}
-- October 27 (WS5, docs/team/POST_TUTORIAL_FLOW_20261027.md): the camp readiness card
-- (WS1, docs/team/CAMP_LADDER_20261027.md) fills the Camp slot when its module ships;
-- without it the timed "Next up" card stays.
local CampGuide: any = nil
do
	local module = script.Parent:FindFirstChild("CampGuide")
	if module then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then CampGuide = result end
	end
end
-- Config.Guide, read on every call so a switch flipped in Studio applies at once.
local function settings(): any
	local value = (Config :: any).Guide
	return if type(value) == "table" then value else {}
end
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
-- October 27 (WS1 camp ladder): the bands follow CampGuide's EvenRatio/ReadyRatio (1.0 /
-- 1.3) once that module ships.
Guide.CloseFightRatio = if CampGuide and type(CampGuide.EvenRatio) == "number" then CampGuide.EvenRatio else 1.3
Guide.ShouldWinRatio = if CampGuide and type(CampGuide.ReadyRatio) == "number" then CampGuide.ReadyRatio else 2
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
-- October 27 (WS5, live journeys: 72% of the players who left after the vacuum owned two
-- chickens and nothing named the third): the Camp tip's wait is on screen, "TIP • n/3".
-- 1: a chicken for the Army while it holds fewer than ArmyTipSize (the lever, the buy, or
-- the eggs and the pad for its Coins); 2: the settle wait as a count; 3: the attack.
-- Saves without the empty start, Goal hints off or Config.Guide.ArmyTips = false keep the
-- October 24 card alone (TIP • 1/1, once the Army holds three and is settled).
local ATTACK_CARDS = {
	Attack = tipCard("TipAttack", "Send your Army to attack Cluck Camp!", 1, "Camp1"),
	Roll = tipCard("TipArmyRoll", "Roll a chicken for your Army!", 1, "RollStation"),
	Buy = tipCard("TipArmyBuy", "Buy the chicken!", 1, "RollStation"),
	-- Three chickens owned but not all in the Army (a hand-picked Army).
	Equip = tipCard("TipArmyEquip", "Equip Best in My Army!", 1, nil),
	-- Its text gains the count "(n/20)"; with the vacuum not in hand the line says to equip it.
	Ready = tipCard("TipArmyReady", "Vacuum eggs to get ready for battle!", 2, "VacuumTool", nil, "Equip your Egg Vacuum!", 2),
	ReadyFull = tipCard("TipArmyReady", "Vacuum full! Sell your eggs on the green pad!", 2, "EggDeposit"),
	-- No vacuum (a Rebirth took it before the Rebuild card): eggs by hand count the same.
	ReadyHand = tipCard("TipArmyReady", "Collect eggs to get ready for battle!", 2, "Yard"),
}
Guide.ArmyChainTotal = 3

-- October 27 (WS5): after a Rebirth that took the Egg Vacuum or Flock Size I (Rebirth 1 and
-- up, or Rebirth 0 when Config.Rebirth.Intro.KeepTree is off), claim them again.
local REBUILD_CARDS = {
	Vacuum = tipCard("TipRebuildVacuum", "Claim your Egg Vacuum again!", 1, "Upgrades", "EggVacuum",
		"Open Upgrades for an Egg Vacuum!", 1, "Open the Tools category!", 1),
	Flock = tipCard("TipRebuildFlock", "Expand your plot again!", 2, "Upgrades", "Flock1", "Open Upgrades!", 2, MAIN_TAB, 2),
}

-- The rebirth rank in the snapshot (state.rebirth.rank), 0 without one.
local function rank(state: any): number
	local quote = state.rebirth
	return if type(quote) == "table" then tonumber(quote.rank) or 0 else 0
end

-- October 27 (WS5): the post-tutorial extras (the Army count cards, Rebuild, Grow and GOAL)
-- are for empty-start profiles (introRebirth set) with Goal hints on (Settings,
-- tutorial.goalsHidden). The GOAL cards and Grow also stop at Config.Guide.GoalUntilRank.
local function extrasAllowed(state: any): boolean
	return state.introRebirth ~= nil and (state.tutorial or {}).goalsHidden ~= true
end
local function goalsOn(state: any): boolean
	local guide = settings()
	return guide.Goals ~= false and extrasAllowed(state) and rank(state) < (tonumber(guide.GoalUntilRank) or 1)
end
local function armyTipsOn(state: any): boolean
	return settings().ArmyTips ~= false and extrasAllowed(state)
end
-- A Rebirth has been taken (Rebirth 0 or a rank).
local function rebirthed(state: any): boolean
	return state.introRebirth == "done" or rank(state) >= 1
end

-- Coins earned in all (eggs and battles): the Shop reveal reads it (Config.Guide.ShopRevealEarned).
function Guide.CoinsEarned(state: any): number
	return (tonumber(state.passiveEarned) or 0) + (tonumber(state.battleEarned) or 0)
end

-- The settle wait as eggs: vacuumed eggs (to VacuumGoal), or eggs by hand scaled so
-- ArmyTipEggs reads as the same VacuumGoal.
function Guide.SettleCount(tutorial: any): number
	local byHand = math.floor(Guide.EggsCollected(tutorial) * Guide.VacuumGoal / Guide.ArmyTipEggs)
	return math.clamp(math.max(Guide.VacuumEggCount(tutorial), byHand), 0, Guide.VacuumGoal)
end

local function vacuumOwned(state: any): boolean
	local tools = state.tools
	return type(tools) == "table" and tools.eggVacuum == true
end
local function flockBought(state: any): boolean
	local tier = flockTier(state)
	if tier ~= nil then return tier >= 1 end
	local size = flockSize(state)
	return size == nil or size >= 4
end

-- An earn() step numbered inside a tip chain.
local function earnTip(state: any, price: number?, index: number): any
	local card: any = earn(state, price)
	card.index = index
	return card
end
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
			if t.guideCompleted ~= true or f.Win then return false end
			-- October 27: the count cards start once the Vacuum chain is done (it comes first).
			if armyTipsOn(state) then return true end
			local army = tonumber(state.selectedCount) or #(state.selectedIds or {})
			-- October 24 (Stevin): not right after the vacuum, once the player is a little
			-- settled: a load of vacuumed eggs sold, or ArmyTipEggs eggs by hand.
			local settled = Guide.VacuumEggCount(t) >= Guide.VacuumGoal or Guide.EggsCollected(t) >= Guide.ArmyTipEggs
			return army >= Guide.ArmyTipSize and settled
		end,
		done = function(f: any, _state: any): boolean return f.Win == true end,
		card = function(_f: any, state: any): any
			if not armyTipsOn(state) then return table.clone(ATTACK_CARDS.Attack) end
			local t: any = state.tutorial or {}
			local army = tonumber(state.selectedCount) or #(state.selectedIds or {})
			local card: any
			if army < Guide.ArmyTipSize then
				local owned = #(state.pets or {})
				local offer = state.offer
				if owned >= Guide.ArmyTipSize then
					card = table.clone(ATTACK_CARDS.Equip)
				elseif not offer then
					card = table.clone(ATTACK_CARDS.Roll)
					card.text ..= " (" .. army .. "/" .. Guide.ArmyTipSize .. ")"
				elseif (offer.price or 0) > (state.coins or 0) then
					card = earnTip(state, offer.price, 1)
				else
					card = table.clone(ATTACK_CARDS.Buy)
				end
			elseif Guide.SettleCount(t) < Guide.VacuumGoal then
				local vacuum = (state.tools or {}).vacuum
				if not vacuumOwned(state) then card = table.clone(ATTACK_CARDS.ReadyHand)
				elseif type(vacuum) == "table" and (vacuum.capacity or 0) > 0 and (vacuum.count or 0) >= vacuum.capacity then
					card = table.clone(ATTACK_CARDS.ReadyFull)
				else card = table.clone(ATTACK_CARDS.Ready) end
				if card.target ~= "EggDeposit" then
					card.text ..= " (" .. Guide.SettleCount(t) .. "/" .. Guide.VacuumGoal .. ")"
				end
			else
				card = table.clone(ATTACK_CARDS.Attack)
				card.index = 3
			end
			card.total = Guide.ArmyChainTotal
			return card
		end},
	-- October 27 (WS5): Rebuild, after a Rebirth that left the vacuum or Flock Size I unowned.
	{id = "Rebuild", payoff = "Yard rebuilt!", total = 2, cards = REBUILD_CARDS,
		when = function(_f: any, state: any): boolean
			local t: any = state.tutorial or {}
			return settings().Rebuild ~= false and extrasAllowed(state) and t.guideCompleted == true
				and t.vacuumSold == true and rebirthed(state) and type(state.tools) == "table"
		end,
		done = function(_f: any, state: any): boolean return vacuumOwned(state) and flockBought(state) end,
		card = function(_f: any, state: any): any
			if not vacuumOwned(state) then return table.clone(REBUILD_CARDS.Vacuum) end
			local offer = nodeOffer(state, "Flock1")
			local price = if offer and offer.status ~= "Owned" and type(offer.price) == "number" then offer.price else nil
			if price and price > (state.coins or 0) then return earnTip(state, price, 2) end
			return table.clone(REBUILD_CARDS.Flock)
		end},
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
	-- October 27: the Camp slot. WS1's CampGuide (when it ships) names the next camp only
	-- once the Army can take it, else the cheapest step to more power, persistent, with a
	-- tag and a power bar (card.progress); without it, the October 26 timed card.
	{id = "NextCamp", payoff = "Camp captured!", total = 1, cards = NEXT_CAMP_CARDS, quietEnd = true,
		when = function(f: any, state: any): boolean
			if CampGuide and CampGuide.When then
				local ok, when = pcall(CampGuide.When, state, f)
				if ok and when then return true end
			end
			return (state.tutorial or {}).guideCompleted == true and Guide.NextCamp(state) ~= nil
		end,
		done = function(_f: any, state: any): boolean return Guide.NextCamp(state) == nil end,
		card = function(f: any, state: any): any
			if CampGuide and CampGuide.When and CampGuide.Card then
				local ok, when = pcall(CampGuide.When, state, f)
				local shown, card = false, nil
				if ok and when then shown, card = pcall(CampGuide.Card, state, f) end
				if shown and type(card) == "table" then return card end
			end
			local index = Guide.NextCamp(state)
			return if index and NEXT_CAMP_CARDS[index] then table.clone(NEXT_CAMP_CARDS[index]) else nil
		end},
}

-- The node the Camp card points at now (WS1's Army Size step), so Grow never doubles it.
local function campNode(state: any, f: any): string?
	if not (CampGuide and CampGuide.When and CampGuide.Card) then return nil end
	local ok, when = pcall(CampGuide.When, state, f)
	if not (ok and when) then return nil end
	local shown, card = pcall(CampGuide.Card, state, f)
	return if shown and type(card) == "table" and type(card.node) == "string" then card.node else nil
end

-- October 27 (WS5): Grow, after Rebirth 0: buy each starter upgrade in
-- Config.Guide.GrowNodes ("Buy Egg Speed I!") as it becomes affordable, "TIP • n/3".
local GROW_CARDS: {[string]: any} = {}
local function growNodes(): {string}
	local list = settings().GrowNodes
	local nodes = {}
	if type(list) == "table" then
		for _, id in list do if type(id) == "string" and Tree.Nodes[id] then table.insert(nodes, id) end end
	end
	return nodes
end
for index, id in growNodes() do
	local node = Tree.Nodes[id]
	local tab = if node.category == "Main" then MAIN_TAB else "Open the " .. node.category .. " category!"
	GROW_CARDS[id] = tipCard("TipGrow" .. id, "Buy " .. node.name .. "!", index, "Upgrades", id, "Open Upgrades!", index, tab, index)
end
table.insert(TIPS, {id = "Grow", payoff = "Upgrades learned!", total = #growNodes(), cards = GROW_CARDS,
	when = function(_f: any, state: any): boolean
		return settings().Grow ~= false and goalsOn(state) and (state.tutorial or {}).guideCompleted == true
			and state.introRebirth == "done"
	end,
	done = function(_f: any, state: any): boolean
		for _, id in growNodes() do
			local offer = nodeOffer(state, id)
			if not offer or offer.status ~= "Owned" then return false end
		end
		return true
	end,
	card = function(f: any, state: any): any
		local list = growNodes()
		local skipNode = campNode(state, f)
		for index, id in list do
			local offer = nodeOffer(state, id)
			if id ~= skipNode and offer and offer.status == "Available" then
				local card = table.clone(GROW_CARDS[id] or tipCard("TipGrow" .. id, "Buy " .. Tree.Nodes[id].name .. "!",
					index, "Upgrades", id, "Open Upgrades!", index, MAIN_TAB, index))
				card.total = #list
				return card
			end
		end
		return nil
	end})

-- October 27 (WS5): GOAL cards, the long bar until Config.Guide.GoalUntilRank (Rebirth 1):
-- the Coins for Rebirth 0, then the chicken to find for the next Rebirth, then its Coins.
-- Tag "GOAL", no count; CommanderGuide keeps them on screen for the first
-- GoalAlwaysSeconds of a visit, then lets them peek.
local GOAL_IDS = {"GoalRebirth0", "GoalFind", "GoalRebirthCoins", "GoalRebirthReady"}
local function goal(id: string, text: string, target: string?): any
	local card: any = step(id, text, target)
	card.tag = "GOAL"
	return card
end
local function article(name: string): string
	return (if string.find(string.sub(name, 1, 1), "[AEIOUaeiou]") then "an " else "a ") .. name
end
function Guide.GoalCard(state: any): any
	local quote: any = if type(state.rebirth) == "table" then state.rebirth else {}
	local coins = math.max(0, math.floor(tonumber(state.coins) or 0))
	if state.introRebirth == "pending" then
		local cost = tonumber(quote.cost) or introCost()
		local card = goal("GoalRebirth0", "Reach " .. Currency.Grouped(cost) .. " Coins for Rebirth 0! ("
			.. Currency.Grouped(math.min(coins, cost)) .. "/" .. Currency.Grouped(cost) .. ")")
		card.fraction = if cost > 0 then math.min(1, coins / cost) else 1
		return card
	end
	local nextRank = tonumber(quote.nextRank) or rank(state) + 1
	-- The server's quote names the chicken to find (RebirthService, ranks 1..FindRanks).
	local find = quote.find
	local species = if type(find) == "table" then find.species else nil
	local found = if type(find) == "table" then find.found == true else true
	if species == nil and nextRank <= (tonumber((Config.Rebirth :: any).FindRanks) or 0) then
		species = PetCatalog.RebirthFinds[nextRank]
		found = species == nil or (type(state.discovered) == "table" and state.discovered[species] == true)
	end
	if species and not found then
		local definition = PetCatalog[species]
		local name = if type(find) == "table" and type(find.name) == "string" then find.name
			elseif type(definition) == "table" and type(definition.name) == "string" then definition.name else tostring(species)
		return goal("GoalFind", "Find " .. article(name) .. " for Rebirth " .. nextRank .. "!", "RollStation")
	end
	local cost = tonumber(quote.cost)
	if not cost or cost <= 0 then return nil end
	if quote.eligible == true then return goal("GoalRebirthReady", "Rebirth " .. nextRank .. " is ready! Open Rebirth!") end
	local percent = if coins >= cost then 100 else math.clamp(math.floor(coins / cost * 100), 0, 99)
	local card = goal("GoalRebirthCoins", "Reach " .. Currency.Grouped(cost) .. " Coins for Rebirth " .. nextRank .. "! (" .. percent .. "%)")
	-- CommanderGuide peeks a GOAL card again at each quarter of the way.
	card.fraction = math.min(1, coins / cost)
	return card
end
-- No payoff: it ends at Rebirth 1, when the HUD's Rebirth progress takes over.
table.insert(TIPS, {id = "Goal", tag = "GOAL", total = nil, cards = {}, quietEnd = true,
	when = function(_f: any, state: any): boolean
		return goalsOn(state) and (state.tutorial or {}).guideCompleted == true
	end,
	done = function(_f: any, _state: any): boolean return false end,
	card = function(_f: any, state: any): any return Guide.GoalCard(state) end})

-- October 27 (WS5) priority: Rebirth, Vacuum, Rebuild, Attack, Camp, Grow, GOAL (first
-- match wins). Profiles without the Army count cards keep the October 24 order, where the
-- settled Camp tip came before the Egg Vacuum.
local chains: {[string]: any} = {}
for _, chain in TIPS do chains[chain.id] = chain end
Guide.Tips = {chains.Rebirth, chains.Vacuum, chains.Rebuild, chains.Attack, chains.NextCamp, chains.Grow, chains.Goal}
local LEGACY_ORDER: {any} = {chains.Rebirth, chains.Attack, chains.Vacuum, chains.Rebuild, chains.NextCamp, chains.Grow, chains.Goal}

-- Every card id Guide.Resolve can return (analytics validates the client's Card signal).
Guide.CardIds = {}
for _, id in {"Complete", "Defend", "Return", "Battle", "RecoverCollect", "RecoverSell", "Roll", "Recruit", "Grow",
	"Collect", "Sell", "Start", "Expand", "RollAgain", "RollMore", "BuyChicken"} do Guide.CardIds[id] = true end
for _, cards: any in {REBIRTH_CARDS, ATTACK_CARDS, VACUUM_CARDS, REBUILD_CARDS, NEXT_CAMP_CARDS, GROW_CARDS} do
	for _, card: any in cards do Guide.CardIds[card.id] = true end
end
for _, id in GOAL_IDS do Guide.CardIds[id] = true end
if CampGuide and type(CampGuide.Ids) == "table" then
	for _, id in CampGuide.Ids do if type(id) == "string" then Guide.CardIds[id] = true end end
end

-- The first tip to show now (its card with tag "TIP" or its own, index, total and chain),
-- or nil. `skip` holds card ids the client has dismissed (CommanderGuide's timed cards).
local function tip(state: any, f: any, skip: {[string]: boolean}?): any
	local away = state.incoming or state.outgoing
		or (state.armyState ~= nil and state.armyState ~= "Home" and state.armyState ~= "Following")
	if away then return nil end
	local order: {any} = if armyTipsOn(state) then Guide.Tips else LEGACY_ORDER
	for _, chain in order do
		if not chain.done(f, state) and chain.when(f, state) then
			local card = chain.card(f, state)
			if card and not (skip and skip[card.id]) then
				card.tag = card.tag or chain.tag or "TIP"
				if card.total == nil then card.total = chain.total end
				card.chain = chain.id
				return card
			end
		end
	end
	return nil
end

-- October 27 (WS5): the progressive HUD reveal after the tutorial (HudController's "post"
-- stage; same positions, timing only). Pure: the snapshot, the facts, the client's seconds
-- since it saw the tutorial complete this visit and the visit's seconds. Every key is true
-- with Config.Guide.HudReveal off, after RevealAllSeconds, or for saves without the empty
-- start. WS7 may supply RevealHooks.FriendBoost(state, facts, sinceCore): boolean.
Guide.HudRevealKeys = {"Army", "Rebirth", "Settings", "Playtime", "Index", "FreeGift", "Shop", "GoldRush", "Boosts", "FriendBoost"}
Guide.RevealHooks = {} :: {[string]: (any, any, number) -> boolean}
function Guide.HudReveal(state: any, facts: any, sinceCore: number, visitSeconds: number): {[string]: boolean}
	local guide = settings()
	local reveal: {[string]: boolean} = {}
	local all = guide.HudReveal == false or state.introRebirth == nil
		or sinceCore >= (tonumber(guide.RevealAllSeconds) or 480)
	if all then
		for _, key in Guide.HudRevealKeys do reveal[key] = true end
		return reveal
	end
	local t: any = state.tutorial or {}
	facts = facts or {}
	local introDone = state.introRebirth == "done" or rank(state) >= 1
	local species = 0
	for _, seen in (if type(state.discovered) == "table" then state.discovered else {}) do if seen then species += 1 end end
	local boosts = state.boosts
	local boosted = type(boosts) == "table" and type(boosts.running) == "table" and next(boosts.running) ~= nil
	local late = sinceCore >= 360
	reveal.Army, reveal.Rebirth, reveal.Settings = true, true, true
	-- After the Egg Vacuum chain (its sale), or 2.5 minutes after the tutorial.
	reveal.Playtime = t.vacuumSold == true or sinceCore >= 150
	-- With the first new chicken, the first Camp, or 5 minutes after.
	reveal.Index = species >= 2 or facts.Win == true or sinceCore >= 300
	-- Its own 5-minute claim, or once Rebirth 0 is done.
	reveal.FreeGift = visitSeconds >= 300 or introDone
	reveal.Shop = Guide.CoinsEarned(state) >= (tonumber(guide.ShopRevealEarned) or 2000) or introDone or late
	reveal.GoldRush = introDone or boosted or late
	reveal.Boosts = reveal.GoldRush
	reveal.FriendBoost = facts.Win == true or (tonumber(state.friendBoost) or 0) > 0 or late
	local hook = Guide.RevealHooks.FriendBoost
	if hook then
		local ok, shown = pcall(hook, state, facts, sinceCore)
		if ok and shown then reveal.FriendBoost = true end
	end
	return reveal
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
