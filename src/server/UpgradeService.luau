--!strict
-- Owns portable cash upgrade offers and transactions; Research owns timed jobs.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.PetCatalog)
local Rules = require(Shared.Rules)
local Definitions = require(Shared.UpgradeCatalog)
local ArmyService = require(script.Parent.ArmyService)
local UpgradeService = {}
UpgradeService.__index = UpgradeService

local function decimal(value)
	return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end

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

function UpgradeService.new(_world, rolls)
	return setmetatable({rolls = rolls}, UpgradeService)
end

function UpgradeService:Offers(session, now: number?)
	local offers = {}
	-- Cash upgrades never require camp visits, victories or an earned rank.
	local function add(key, level, current, price, available)
		local unlocked = available ~= false
		local canSpend,spendReason=true,""
		if price then canSpend,spendReason=session:CanSpendCash(price,if key=="ArmySize" then "ArmySize" else nil) end
		offers[key] = {level = level, currentText = current, price = price, unlocked = unlocked,
			canSpend=canSpend,spendReason=spendReason,
			requirement = if available == false then "This plot has no additional upgrade space." else "",
			ready = session.loaded == true and not session.closing and not session.saveLost}
	end
	local production = session:EggProductionMultiplier()
	add("EggSpeed", session.eggSpeedLevel, decimal(production) .. "x",
		Definitions.EggSpeedPrices[session.eggSpeedLevel + 1])
	add("PlotSize", session.plotSizeLevel, tostring(session:CollectionLimit()),
		Definitions.PlotPrices[session.plotSizeLevel + 1], session.plotExpansionAvailable)
	-- October 16 timed yard builds: one at a time; the hex shows its timer meanwhile.
	offers.PlotSize.buildSeconds = Definitions.PlotBuildSeconds[session.plotSizeLevel + 1] or 0
	local build = session.plotBuild
	if build then
		offers.PlotSize.unlocked = false
		offers.PlotSize.requirement = "Your yard is being built. Ready in "
			.. math.max(1, math.ceil((build.endsAt - (now or os.time())) / 60)) .. " min."
		offers.PlotSize.building = {level = build.level, startedAt = build.startedAt, finishAt = build.endsAt}
	end
	local income = session:GlobalUpgrade("Income")
	add("EggValue", session.incomeLevel,
		decimal(Rules.EggUnitValue(session.incomeLevel)) .. " Coins",
		income and income.price)
	local army = session:NextSlot()
	add("ArmySize", session.capacity, tostring(session:Capacity()), army and army.price)
	if army then offers.ArmySize.unlocked = army.unlocked; offers.ArmySize.requirement = army.requirement end
	local luck = session:GlobalUpgrade("Luck")
	local window = Rules.LuckWindow(session.luck, session:PaidLuckMultiplier(), session.researchEffects.rollingLuck)
	add("Luck", session.luck, decimal(window.multiplier) .. "x", luck and luck.price)
	-- Normal individual roll outcomes; forced tutorial/guaranteed rolls and fixed
	-- crate pools are separate. Use the same normalized odds as ordinary rolls.
	offers.Luck.maxLevel = #Config.LuckPrices
	offers.Luck.window, offers.Luck.windowText = window, window.rangeText
	offers.Luck.rarePlusChance, offers.Luck.epicPlusChance, offers.Luck.topBandChance = luckChances(session, session.luck, window)
	if offers.Luck.price then
		local nextWindow = Rules.LuckWindow(session.luck + 1, session:PaidLuckMultiplier(), session.researchEffects.rollingLuck)
		offers.Luck.nextWindow, offers.Luck.nextWindowText = nextWindow, nextWindow.rangeText
		offers.Luck.nextText = decimal(nextWindow.multiplier) .. "x"
		offers.Luck.nextRarePlusChance, offers.Luck.nextEpicPlusChance, offers.Luck.nextTopBandChance = luckChances(session, session.luck + 1, nextWindow)
	end
	local slots = session.rollSlotsUnlocked
	local physicalLimit = session.rollSlotLimit or 1
	add("RollSlots", slots, tostring(session.rollSlotCount or 1),
		if slots < physicalLimit then Definitions.RollSlotPrices[slots] else nil)
	-- Preview the real next benefit, including verified passes, without changing
	-- prices, progression or the current value used by the purchase transaction.
	local function preview(key, value)
		if offers[key].price then offers[key].nextText = value end
	end
	local nextRate = Definitions.EggSpeedRates[session.eggSpeedLevel + 2]
	if nextRate then
		local nextProduction = production * nextRate / Definitions.EggSpeedRates[session.eggSpeedLevel + 1]
		preview("EggSpeed", decimal(nextProduction) .. "x")
	end
	preview("PlotSize", tostring(Definitions.PlotCapacity(session.plotSizeLevel + 1)))
	preview("EggValue", decimal(Rules.EggUnitValue(session.incomeLevel + 1)) .. " Coins")
	if army then preview("ArmySize", tostring(army.displayCapacity or army.capacity)) end
	preview("RollSlots", tostring(math.min(slots + 1, physicalLimit)))
	return offers
end

function UpgradeService:Buy(_player, session, key, expectedLevel, expectedPrice, now: number?)
	if type(key) ~= "string" or not table.find(Definitions.Order, key) then return false, "Choose an upgrade." end
	local clock = now or os.time()
	local offer = self:Offers(session, clock)[key]
	if not offer.ready then return false, "Wait for your flock to load." end
	if not offer.price then return false, "This upgrade is at its maximum." end
	if not offer.unlocked then return false, offer.requirement end
	-- A replay or stale click never purchases another level at an unexpected price.
	if expectedLevel ~= offer.level or expectedPrice ~= offer.price then return false, "This upgrade changed. Try again." end
	local canSpend,reason=session:CanSpendCash(offer.price,if key=="ArmySize" then "ArmySize" else nil)
	if not canSpend then return false,reason end
	if key == "ArmySize" then return ArmyService.Expand(session) end
	if key == "EggValue" then return ArmyService.UpgradeIncome(session) end
	if key == "Luck" then return self.rolls:UpgradeLuck(session) end
	-- No yields between the balance check, spend and benefit. Save with the existing profile.
	session.coins -= offer.price
	local message
	if key == "EggSpeed" then
		session.eggSpeedLevel += 1
		message = "Your chickens now lay eggs faster!"
	elseif key == "PlotSize" then
		local seconds = offer.buildSeconds or 0
		if seconds > 0 then
			-- Paid now; capacity applies when PlayerSession:CompletePlotBuild sees the end time.
			session.plotBuild = {level = session.plotSizeLevel + 1, startedAt = clock, endsAt = clock + seconds}
			message = "Builders started your yard expansion! Flock capacity "
				.. Definitions.PlotCapacity(session.plotSizeLevel + 1) .. " in " .. math.ceil(seconds / 60) .. " min."
		else
			session.plotSizeLevel += 1
			message = "Larger chicken yard! Flock capacity: " .. session:CollectionLimit() .. "."
		end
	else
		session.rollSlotsUnlocked += 1
		message = "Roll slot unlocked! Your next roll uses " .. session.rollSlotsUnlocked .. " podiums."
	end
	session.tutorial.upgraded = true
	session:Touch()
	return true, message
end

return UpgradeService
