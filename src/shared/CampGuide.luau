--!strict
-- October 27 camp readiness (WS1 of the retention package; contract
-- docs/team/CAMP_LADDER_20261027.md). Snapshot-only: never changes prices, odds or
-- actions, and gives the same answer on the server (TutorialService) and the client.
--
-- Live data (Oct 26-27): 74% of Cluck Camp winners never beat Fort Roost, and 73% of
-- Fort Roost attacks started below even odds. After Cluck Camp the only goal was a
-- 10-second "Next up: conquer Fort Roost!" and a NEXT marker over a camp the Army could
-- not take. This module replaces that card with a readiness card: "Your Army can take
-- Fort Roost! Attack!" once the Army reaches ReadyRatio, otherwise the single cheapest
-- power step (Army Size, the podium chicken, Chicken Feed, or the eggs that pay for it),
-- always with an "ARMY 38 / 84" bar. WS5's TutorialGuide Camp chain asks When/Card;
-- BaseController reads the odds bands, the goal and the warning copy; BattleService
-- reads DefeatText. The camp strengths themselves are Progression.Strength.
local Config = require(script.Parent.Config)
local Rules = require(script.Parent.Rules)
local Progression = require(script.Parent.Progression)
local Currency = require(script.Parent.CurrencyLimits)
local Catalog = require(script.Parent.PetCatalog)
local Tree = require(script.Parent.UpgradeCatalog)
local CampGuide = {}

-- Odds bands (Army power / garrison power). Live: below 1.0x Fort Roost won 1 of 1,215
-- attacks, 1.0-1.3x about half, 1.3-2x 84%; headless fights turn at about 1.2-1.3x.
-- Below EvenRatio reads Very tough, then Close fight, and Should win from ReadyRatio
-- (they were 1.3 and 2.0). The readiness card says "Attack!" from ReadyRatio.
CampGuide.EvenRatio = 1.0
CampGuide.ReadyRatio = 1.3
-- Seconds the Send Army prompt stays armed as "Attack anyway" after the warning.
CampGuide.ConfirmSeconds = 5

-- Every card id Card can return (analytics validates guide steps against them).
CampGuide.Ids = {} :: {string}
for index = 2, #Progression.Camps(1) do table.insert(CampGuide.Ids, "TipNextCamp" .. index) end
for _, id in {"TipCampArmySize", "TipCampRecruit", "TipCampRoll", "TipCampFeedGet", "TipCampFeed",
	"TipCampEquip", "TipCampCollect", "TipCampSell"} do
	table.insert(CampGuide.Ids, id)
end

local function ladder(): any
	local value = (Config :: any).CampLadder
	return if type(value) == "table" then value else {}
end

-- Config.CampLadder.ReadinessTip: the readiness card, the camp defeat line and the
-- NEXT marker's readiness gate. Off restores the October 26 timed card and marker.
function CampGuide.Enabled(): boolean
	return ladder().ReadinessTip == true
end

-- Config.CampLadder.AttackWarning: the below-even warning and "Attack anyway".
function CampGuide.WarningEnabled(): boolean
	return ladder().AttackWarning == true
end

function CampGuide.Difficulty(power: number?, enemyPower: number?): string
	local enemy = tonumber(enemyPower) or 0
	if enemy <= 0 then return "Undefended" end
	local ratio = (tonumber(power) or 0) / enemy
	if ratio >= CampGuide.ReadyRatio then return "Should win" end
	if ratio >= CampGuide.EvenRatio then return "Close fight" end
	return "Very tough"
end

-- The Army power that reads Should win against `enemyPower` (Fort Roost 64 -> 84).
function CampGuide.Goal(enemyPower: number?): number
	return math.max(0, math.ceil((tonumber(enemyPower) or 0) * CampGuide.ReadyRatio - 1e-6))
end

-- True when Send Army should warn first: below even odds, with the warning on.
function CampGuide.ShouldWarn(power: number?, enemyPower: number?): boolean
	local enemy = tonumber(enemyPower) or 0
	return CampGuide.WarningEnabled() and enemy > 0 and (tonumber(power) or 0) < enemy * CampGuide.EvenRatio
end

-- The first main-route camp not won yet after Cluck Camp, or nil (same rule as
-- TutorialGuide.NextCamp, which stays as the fallback).
function CampGuide.NextCamp(state: any): number?
	local wins = state.firstWins
	if type(wins) ~= "table" or wins[1] ~= true then return nil end
	for index = 2, #Progression.Camps(1) do
		if wins[index] ~= true then return index end
	end
	return nil
end

function CampGuide.CampName(index: number): string
	local camp = Progression.Camps(1)[index]
	return if camp then camp.name else "Camp " .. index
end

-- The own-lane camp's power as the server shows and fights it (state.targets carries
-- the Rebirth scale and the ladder strength), else its rank-0 power.
function CampGuide.EnemyPower(state: any, index: number): number
	local id = "camp:" .. index
	for _, entry in state.targets or {} do
		if type(entry) == "table" and entry.id == id and type(entry.power) == "number" then return entry.power end
	end
	return Progression.CampPower(index)
end

local function petPower(pet: any): number
	return Rules.PetPower(pet.species, pet.stars or 1, pet.level or 1, pet.giantSize)
end

local function nodeOffer(state: any, id: string): any
	local tree = state.upgradeTree
	local nodes = if type(tree) == "table" then tree.nodes else nil
	local offer = if type(nodes) == "table" then nodes[id] else nil
	return if type(offer) == "table" then offer else nil
end

local function buyable(offer: any): boolean
	return offer == nil or (offer.status ~= "Owned" and offer.status ~= "Locked")
end

-- The best power step per Coin toward the goal (ties: the cheaper step). Kinds:
-- Equip (a manual Army leaves a stronger chicken at home), Recruit (a podium chicken the
-- server says improves the Army), ArmySize (the next tier; each new slot holds the best
-- spare chicken, or a basic Chicken bought on the podium), Feed (a level for an Army
-- chicken), GetFeed (Chicken Feed plus that first level), Roll (an empty automatic slot
-- with nothing on the podium for it, or nothing else left). `price` ranks the
-- step; `buyPrice` is what the next purchase costs. Prices are the live quotes in the
-- snapshot (podium offers, nextSlot, the Upgrades node offers, upgradePrice).
function CampGuide.Advice(state: any, _goal: number?): any
	local capacity = tonumber(state.capacity) or 0
	local army, spare, all = {}, {}, {}
	for _, pet in state.pets or {} do
		if type(pet) == "table" and type(pet.species) == "string" and Catalog[pet.species] then
			table.insert(if pet.selected == true then army else spare, pet)
			table.insert(all, pet)
		end
	end
	local function strongest(a: any, b: any): boolean return petPower(a) > petPower(b) end
	table.sort(spare, strongest)
	table.sort(all, strongest)
	local armyPower, weakest = 0, math.huge
	for _, pet in army do
		local power = petPower(pet)
		armyPower += power
		weakest = math.min(weakest, power)
	end
	local manual = state.selectionMode == "Manual"
	local freeSlots = math.max(0, capacity - #army)
	local best: any = nil
	local function consider(step: any)
		if step.gain <= 0.01 then return end
		step.value = step.gain / math.max(step.price, 1)
		if best == nil or step.value > best.value + 1e-9
			or (math.abs(step.value - best.value) <= 1e-9 and step.price < best.price) then
			best = step
		end
	end
	-- A manual Army only changes in My Army (Equip Best); an automatic one already is the best.
	if manual then
		local top = 0
		for i = 1, math.min(capacity, #all) do top += petPower(all[i]) end
		consider({kind = "Equip", price = 0, buyPrice = 0, gain = top - armyPower})
	end
	-- A basic Chicken from the lever is the floor for an empty slot (podium quote).
	local basicPower = Rules.PetPower("Duck", 1, 1)
	local basicPrice = Rules.StarterPrice(Catalog.Duck.price, #all)
	local offers = state.offers
	if type(offers) ~= "table" or #offers == 0 then offers = {state.offer} end
	local recruit = false
	for _, offer in offers do
		if type(offer) ~= "table" or offer.improvesArmy ~= true or type(offer.price) ~= "number"
			or not Catalog[offer.species] then continue end
		local power = Rules.PetPower(offer.species, 1, offer.level or 1)
		local gain = if (not manual and freeSlots > 0) or #army == 0 then power else power - weakest
		consider({kind = "Recruit", price = offer.price, buyPrice = offer.price, gain = gain, slot = offer.slot})
		recruit = true
	end
	-- An empty automatic slot and nothing on the podium for it: the lever fills it.
	if not recruit and not manual and freeSlots > 0 then
		consider({kind = "Roll", price = basicPrice, buyPrice = 0, gain = basicPower})
	end
	local nextSlot = state.nextSlot
	if type(nextSlot) == "table" and type(nextSlot.price) == "number" and type(nextSlot.tier) == "number" then
		local node = Tree.NodeId("ArmySize", nextSlot.tier)
		local base = tonumber(state.baseCapacity) or capacity
		local added = math.max(1, (tonumber(nextSlot.capacity) or base + 1) - base)
		-- Slots already free fill first; with none of them filled the new ones gain nothing yet.
		local gain, extra = 0, 0
		if #spare > freeSlots or freeSlots == 0 then
			for i = 1, added do
				local pet = spare[freeSlots + i]
				if pet then gain += petPower(pet) else gain += basicPower; extra += basicPrice end
			end
		end
		if buyable(nodeOffer(state, node)) then
			consider({kind = "ArmySize", price = nextSlot.price + extra, buyPrice = nextSlot.price, gain = gain,
				node = node, tier = nextSlot.tier})
		end
	end
	local effects = state.effects
	local fed = type(effects) == "table" and (tonumber(effects.chickenFeed) or 0) >= 1
	local feedOffer = nodeOffer(state, "ChickenFeed")
	local feedPrice = if feedOffer and type(feedOffer.price) == "number" then feedOffer.price
		else Tree.Families.ChickenFeed.tiers[1].price
	for _, pet in army do
		if type(pet.upgradePrice) ~= "number" then continue end
		local gain = Rules.PetPower(pet.species, pet.stars or 1, (pet.level or 1) + 1, pet.giantSize) - petPower(pet)
		if fed and pet.canUpgrade == true then
			consider({kind = "Feed", price = pet.upgradePrice, buyPrice = pet.upgradePrice, gain = gain})
		elseif not fed and buyable(feedOffer) then
			consider({kind = "GetFeed", price = feedPrice + pet.upgradePrice, buyPrice = feedPrice, gain = gain,
				node = "ChickenFeed"})
		end
	end
	return best or {kind = "Roll", price = 0, buyPrice = 0, gain = 0}
end

local function card(id: string, text: string, target: string?, node: string?, outside: string?, wrongTab: string?): any
	return {id = id, text = text, target = target, node = node, outside = outside, wrongTab = wrongTab}
end

-- Short of the step's price: sell the bag when it covers the rest (the same rule as
-- TutorialGuide's earn()), else collect. A purchase card only shows when affordable, so
-- the card never walks a short player into a Coins shortfall.
local function short(state: any, price: number, what: string): any
	local coins = tonumber(state.coins) or 0
	if coins >= price then return nil end
	local needed = price - coins
	local carried = tonumber((state.eggs or {}).carriedValue) or 0
	if carried > 0 and carried >= needed then
		return card("TipCampSell", "Sell your eggs for " .. what .. "!", "EggDeposit")
	end
	local more = math.ceil(needed - carried)
	return card("TipCampCollect", "Collect eggs: " .. Currency.Grouped(more) .. " more " .. (if more == 1 then "Coin" else "Coins")
		.. " for " .. what .. "!", "Yard")
end

local function adviceCard(state: any, advice: any): any
	local kind = advice.kind
	if kind == "Equip" then return card("TipCampEquip", "Equip Best in My Army!", nil) end
	if kind == "Recruit" then
		return short(state, advice.buyPrice, "the chicken") or card("TipCampRecruit", "Buy the chicken on your podium!", "RollStation")
	end
	if kind == "ArmySize" then
		local label = (Tree.Nodes[advice.node] or {name = "Army Size"}).name
		return short(state, advice.buyPrice, label) or card("TipCampArmySize", "Buy " .. label .. " for more Army slots!",
			"Upgrades", advice.node, "Open Upgrades for more Army slots!", "Open the Main category!")
	end
	if kind == "GetFeed" then
		return short(state, advice.buyPrice, "Chicken Feed") or card("TipCampFeedGet", "Get Chicken Feed to level up your Army!",
			"Upgrades", "ChickenFeed", "Open Upgrades for Chicken Feed!", "Open the Tools category!")
	end
	if kind == "Feed" then
		return short(state, advice.buyPrice, "Feed") or card("TipCampFeed", "Feed your Army chickens to level them up!", "FeedTool")
	end
	return card("TipCampRoll", "Roll a stronger chicken for your Army!", "RollStation")
end

-- WS5's Camp chain (TutorialGuide): shows once the tutorial is done and a camp after
-- Cluck Camp is still unbeaten. Persistent; the framework hides it while the Army is away.
function CampGuide.When(state: any, _facts: any?): boolean
	if type(state) ~= "table" or not CampGuide.Enabled() then return false end
	if (state.tutorial or {}).guideCompleted ~= true then return false end
	return CampGuide.NextCamp(state) ~= nil
end

-- The card: {id, text, target, node?, outside?, wrongTab?, index, total, tag, camp,
-- progress = {value, goal, label}}. Targets: "Camp<n>", "Upgrades", "RollStation",
-- "FeedTool", "Yard", "EggDeposit" or nil (Equip). Ready from ReadyRatio; a Close fight
-- still shows the next step (the prompt only warns below even).
function CampGuide.Card(state: any, facts: any?): any
	if not CampGuide.When(state, facts) then return nil end
	local index = CampGuide.NextCamp(state) :: number
	local name = CampGuide.CampName(index)
	local goal = CampGuide.Goal(CampGuide.EnemyPower(state, index))
	local power = math.floor(tonumber(state.power) or 0)
	local result = if power >= goal then card("TipNextCamp" .. index, "Your Army can take " .. name .. "! Attack!", "Camp" .. index)
		else adviceCard(state, CampGuide.Advice(state, goal))
	result.index, result.total, result.camp = 1, 1, index
	result.tag = "NEXT: " .. string.upper(name)
	result.progress = {value = power, goal = goal, label = "ARMY " .. Currency.Grouped(power) .. " / " .. Currency.Grouped(goal)}
	return result
end

-- BattleService's result line for a lost first try at an own-lane camp.
function CampGuide.DefeatText(name: string, bounty: number?, enemyPower: number?): string
	local coins = math.floor(tonumber(bounty) or 0)
	local paid = if coins > 0 then " +" .. Currency.Text(coins) .. " from the fight." else ""
	return name .. " held!" .. paid .. " Get your Army to " .. Currency.Grouped(CampGuide.Goal(enemyPower))
		.. " power, then attack again."
end

-- The notice before a below-even attack (BaseController).
function CampGuide.Warning(name: string, power: number?, goal: number?): string
	return name .. " is too strong for your Army (" .. Currency.Grouped(tonumber(power) or 0) .. "/"
		.. Currency.Grouped(tonumber(goal) or 0) .. "). Send Army again to attack anyway."
end

return CampGuide
