--!strict
-- Owns portable cash upgrade offers and transactions; Research owns timed jobs.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Rules = require(Shared.Rules)
local Definitions = require(Shared.UpgradeCatalog)
local ArmyService = require(script.Parent.ArmyService)
local UpgradeService = {}
UpgradeService.__index = UpgradeService

local function decimal(value)
	return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end

function UpgradeService.new(_world, rolls)
	return setmetatable({rolls = rolls}, UpgradeService)
end

function UpgradeService:Offers(session)
	local offers = {}
	-- Cash upgrades never require camp visits, victories or an earned rank.
	local function add(key, level, current, price, available)
		local unlocked = available ~= false
		local canSpend,spendReason=true,""
		if price then canSpend,spendReason=session:CanSpendCash(price) end
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
	local income = session:GlobalUpgrade("Income")
	add("EggValue", session.incomeLevel,
		"$" .. decimal(Rules.EggUnitValue(session.incomeLevel)),
		income and income.price)
	local army = session:NextSlot()
	add("ArmySize", session.capacity, tostring(session:Capacity()), army and army.price)
	if army then offers.ArmySize.unlocked = army.unlocked; offers.ArmySize.requirement = army.requirement end
	local luck = session:GlobalUpgrade("Luck")
	add("Luck", session.luck, decimal(Rules.LuckMultiplier(session.luck)
		* session:PaidLuckMultiplier() * (1 + (session.researchEffects.rollingLuck or 0))) .. "x", luck and luck.price)
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
	preview("EggValue", "$" .. decimal(Rules.EggUnitValue(session.incomeLevel + 1)))
	if army then preview("ArmySize", tostring(army.displayCapacity or army.capacity)) end
	preview("Luck", decimal(Rules.LuckMultiplier(session.luck + 1)
		* session:PaidLuckMultiplier() * (1 + (session.researchEffects.rollingLuck or 0))) .. "x")
	preview("RollSlots", tostring(math.min(slots + 1, physicalLimit)))
	return offers
end

function UpgradeService:Buy(_player, session, key, expectedLevel, expectedPrice)
	if type(key) ~= "string" or not table.find(Definitions.Order, key) then return false, "Choose a cash upgrade." end
	local offer = self:Offers(session)[key]
	if not offer.ready then return false, "Wait for your flock to load." end
	if not offer.price then return false, "This upgrade is at its maximum." end
	if not offer.unlocked then return false, offer.requirement end
	-- A replay or stale click never purchases another level at an unexpected price.
	if expectedLevel ~= offer.level or expectedPrice ~= offer.price then return false, "This upgrade changed. Try again." end
	local canSpend,reason=session:CanSpendCash(offer.price)
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
		session.plotSizeLevel += 1
		message = "Larger chicken yard! Flock capacity: " .. session:CollectionLimit() .. "."
	else
		session.rollSlotsUnlocked += 1
		message = "Roll slot unlocked! Your next roll uses " .. session.rollSlotsUnlocked .. " podiums."
	end
	session.tutorial.upgraded = true
	session:Touch()
	return true, message
end

return UpgradeService
