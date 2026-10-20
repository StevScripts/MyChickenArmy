--!strict
-- October 20 overhaul: instant Upgrades tree purchases and their snapshot
-- (docs/team/OVERHAUL_CONTRACT_20261020.md §4, §8). Every node is one Coins purchase
-- with no camp, rank or King gate; RebirthService resets the whole tree. Offers/Buy
-- keep the six pre-tree board keys working for the old cash hexes until S9 ships.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.PetCatalog)
local Rules = require(Shared.Rules)
local Tree = require(Shared.UpgradeCatalog)
local UpgradeService = {}
UpgradeService.__index = UpgradeService

local KIND_STATUS = {start = "Start", open = "Open", back = "Back", tool = "Tool"}

local function decimal(value)
	return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end

local function ready(session): boolean
	return session.loaded == true and not session.closing and not session.saveLost
end

-- Special hexes always count as owned; an upgrade hex is owned once its tier is bought.
local function owned(session, nodeId: string): boolean
	local node = Tree.Nodes[nodeId]
	if not node then return false end
	if node.kind ~= "upgrade" then return true end
	return Tree.Tier(session.upgradeTree, node.family :: string) >= (node.tier :: number)
end

-- The tutorial's Army Size 4 may spend its own earmark (PlayerSession:CanSpendCash).
local function purpose(familyId: string?): string?
	return if familyId == "ArmySize" then "ArmySize" else nil
end

-- Normal individual roll outcomes for the Luck hex; same odds as ordinary rolls
-- (Extra Luck and the verified 2x Luck pass included).
local function luckChances(session, level, window)
	local rarePlus, epicPlus, topBand = 0, 0, 0
	for id, probability in Rules.Odds(level, session.recruitTier,
		session:PaidLuckMultiplier(), session.researchEffects.rollingLuck) do
		local rarity = Catalog[id].rarity
		if rarity == "Epic" or rarity == "Legendary" or rarity == "Mythic" or rarity == "Secret" then
			rarePlus += probability
			epicPlus += probability
		elseif rarity == "Rare" then
			rarePlus += probability
		end
		if Catalog[id].income >= window.topIncome then topBand += probability end
	end
	return rarePlus, epicPlus, topBand
end

-- state.upgradeTree.luck: today's and the next Luck tier's odds for the tooltip
-- (docs/team/LUCK_WINDOW.md). next* fields are nil at the top tier.
local function luckSummary(session)
	local level = session.luck
	local window = Rules.LuckWindow(level, session:PaidLuckMultiplier(), session.researchEffects.rollingLuck)
	local summary = {multiplier = window.multiplier, windowText = window.rangeText}
	summary.rarePlusChance, summary.epicPlusChance, summary.topBandChance = luckChances(session, level, window)
	if level < #Tree.Families.Luck.tiers then
		local nextWindow = Rules.LuckWindow(level + 1, session:PaidLuckMultiplier(), session.researchEffects.rollingLuck)
		summary.nextMultiplier, summary.nextWindowText = nextWindow.multiplier, nextWindow.rangeText
		summary.nextRarePlusChance, summary.nextEpicPlusChance, summary.nextTopBandChance = luckChances(session, level + 1, nextWindow)
	end
	return summary
end

-- One node's server quote: status ("Owned", "Available", "Unaffordable", "Locked",
-- or a special hex's kind), price and the reason it can't be bought right now.
function UpgradeService.NodeOffer(session, nodeId: string)
	local node = Tree.Nodes[nodeId]
	if node.kind ~= "upgrade" then return {status = KIND_STATUS[node.kind] or "Start"} end
	if owned(session, nodeId) then return {status = "Owned"} end
	local price = Tree.Price(node.family :: string, node.tier :: number, session.rebirths) :: number
	if node.prerequisite and not owned(session, node.prerequisite) then
		return {status = "Locked", price = price, spendReason = "Buy " .. Tree.Nodes[node.prerequisite].name .. " first."}
	end
	local canSpend, reason = session:CanSpendCash(price, purpose(node.family))
	return {status = if canSpend then "Available" else "Unaffordable", price = price,
		spendReason = if canSpend then nil else reason}
end

function UpgradeService.new(_world, rolls)
	return setmetatable({rolls = rolls}, UpgradeService)
end

-- state.upgradeTree. Badges count what the player can buy right now, respecting
-- the starter reserve, per category and in total.
function UpgradeService:Snapshot(session)
	local nodes, badges = {}, {Main = 0, Tools = 0, Player = 0, Army = 0, total = 0}
	for id, node in Tree.Nodes do
		local offer = UpgradeService.NodeOffer(session, id)
		nodes[id] = offer
		if offer.status == "Available" then
			badges[node.category] += 1
			badges.total += 1
		end
	end
	local families = {}
	for _, id in Tree.FamilyOrder do families[id] = Tree.Tier(session.upgradeTree, id) end
	return {families = families, nodes = nodes, badges = badges, luck = luckSummary(session)}
end

-- A bought Army slot adds the best reserves to a manual lineup without replacing it.
local function fillManualArmy(session)
	if session.armySelection == nil then return end
	session.armySelection = session:BestPetIds()
	for _, id in session:AutoBestPetIds() do
		if #session.armySelection >= session:Capacity() then break end
		if not table.find(session.armySelection, id) then
			local proposed = table.clone(session.armySelection)
			table.insert(proposed, id)
			if #session:FilterArmyIds(proposed) == #proposed then session.armySelection = proposed end
		end
	end
end

local function boughtMessage(session, node): string
	local family = node.family
	if family == "ArmySize" then return "Army Size increased to " .. session:Capacity() .. " chickens." end
	if family == "RollSlot" then return "Roll slot unlocked! Your next roll uses " .. session.rollSlotsUnlocked .. " podiums." end
	if family == "Flock" then return "Flock Size " .. session:FlockSize() .. ": more of your chickens lay eggs." end
	if family == "ChickenFeed" then return "Chicken Feed unlocked! Equip it and walk to one of your chickens." end
	local value = Tree.ValueText(family, node.tier)
	return node.name .. " bought: " .. value .. "."
end

-- Buys one tree node at the server's quote. Non-yielding from check to benefit.
function UpgradeService:BuyNode(session, nodeId: any, expectedPrice: any, _now: number?): (boolean, string)
	if not ready(session) then return false, "Wait for your flock to load." end
	local node = if type(nodeId) == "string" then Tree.Nodes[nodeId] else nil
	if not node or node.kind ~= "upgrade" then return false, "Choose an upgrade." end
	if owned(session, nodeId) then return false, node.name .. " is already yours." end
	if node.prerequisite and not owned(session, node.prerequisite) then
		return false, "Buy " .. Tree.Nodes[node.prerequisite].name .. " first."
	end
	local familyId, tier = node.family :: string, node.tier :: number
	-- Tiers within a family are bought in order (the prerequisite chain above).
	if Tree.Tier(session.upgradeTree, familyId) + 1 ~= tier then return false, "Buy the earlier tiers first." end
	local price = Tree.Price(familyId, tier, session.rebirths)
	-- A replay or stale click never purchases at an unexpected price.
	if not price or expectedPrice ~= price then return false, "This upgrade changed. Try again." end
	local canSpend, reason = session:CanSpendCash(price, purpose(familyId))
	if not canSpend then return false, reason end
	session.coins -= price
	session.upgradeTree[familyId] = tier
	session:RefreshEffects()
	if familyId == "ArmySize" then fillManualArmy(session) end
	session.tutorial.upgraded = true
	session:RefreshArmy()
	session:Touch()
	return true, boughtMessage(session, node)
end

-- The next tier of a family at today's quote (the legacy Income/Luck/Expand requests).
function UpgradeService:BuyFamily(session, familyId: string): (boolean, string)
	local tier = Tree.Tier(session.upgradeTree, familyId)
	local family = Tree.Families[familyId]
	if not family or tier >= #family.tiers then return false, (if family then family.name else "This upgrade") .. " is at its maximum." end
	return self:BuyNode(session, Tree.NodeId(familyId, tier + 1), Tree.Price(familyId, tier + 1, session.rebirths))
end

-- Pre-tree board offers (state.boardUpgrades) for the old cash hexes, until S9 ships.
-- Level offsets keep the old client's counts: Army Size reads StartingSlots + tier.
function UpgradeService:Offers(session, _now: number?)
	local offers = {}
	local function add(key, level, current, price)
		local canSpend, spendReason = true, ""
		if price then canSpend, spendReason = session:CanSpendCash(price, purpose(Tree.LegacyKeys[key])) end
		offers[key] = {level = level, currentText = current, price = price, unlocked = true,
			canSpend = canSpend, spendReason = spendReason, requirement = "",
			ready = session.loaded == true and not session.closing and not session.saveLost}
	end
	local function nextPrice(familyId)
		return Tree.Price(familyId, Tree.Tier(session.upgradeTree, familyId) + 1, session.rebirths)
	end
	local production = session:EggProductionMultiplier()
	add("EggSpeed", session.eggSpeedLevel, decimal(production) .. "x", nextPrice("EggSpeed"))
	add("PlotSize", Tree.Tier(session.upgradeTree, "Flock"), tostring(session:FlockSize()), nextPrice("Flock"))
	add("EggValue", session.incomeLevel, decimal(Rules.EggUnitValue(session.incomeLevel)) .. " Coins", nextPrice("EggValue"))
	add("ArmySize", Config.StartingSlots + Tree.Tier(session.upgradeTree, "ArmySize"), tostring(session:Capacity()), nextPrice("ArmySize"))
	local window = Rules.LuckWindow(session.luck, session:PaidLuckMultiplier(), session.researchEffects.rollingLuck)
	add("Luck", session.luck, decimal(window.multiplier) .. "x", nextPrice("Luck"))
	offers.Luck.maxLevel = #Tree.Families.Luck.tiers
	offers.Luck.window, offers.Luck.windowText = window, window.rangeText
	offers.Luck.rarePlusChance, offers.Luck.epicPlusChance, offers.Luck.topBandChance = luckChances(session, session.luck, window)
	if offers.Luck.price then
		local nextWindow = Rules.LuckWindow(session.luck + 1, session:PaidLuckMultiplier(), session.researchEffects.rollingLuck)
		offers.Luck.nextWindow, offers.Luck.nextWindowText = nextWindow, nextWindow.rangeText
		offers.Luck.nextText = decimal(nextWindow.multiplier) .. "x"
		offers.Luck.nextRarePlusChance, offers.Luck.nextEpicPlusChance, offers.Luck.nextTopBandChance = luckChances(session, session.luck + 1, nextWindow)
	end
	add("RollSlots", session.rollSlotsUnlocked, tostring(session.rollSlotCount or 1), nextPrice("RollSlot"))
	local function preview(key, familyId)
		local tier = Tree.Tier(session.upgradeTree, familyId)
		if offers[key].price and offers[key].nextText == nil then offers[key].nextText = Tree.ValueText(familyId, tier + 1) end
	end
	for key, familyId in Tree.LegacyKeys do preview(key, familyId) end
	return offers
end

-- Pre-tree request (CashUpgrade/BoardUpgrade): the family's next node at the shown quote.
function UpgradeService:Buy(_player, session, key, expectedLevel, expectedPrice, now: number?)
	local familyId = if type(key) == "string" then Tree.LegacyKeys[key] else nil
	if not familyId then return false, "Choose an upgrade." end
	local offer = self:Offers(session, now)[key]
	if not offer.ready then return false, "Wait for your flock to load." end
	if not offer.price then return false, "This upgrade is at its maximum." end
	if expectedLevel ~= offer.level or expectedPrice ~= offer.price then return false, "This upgrade changed. Try again." end
	local tier = Tree.Tier(session.upgradeTree, familyId)
	return self:BuyNode(session, Tree.NodeId(familyId, tier + 1), offer.price, now)
end

return UpgradeService
