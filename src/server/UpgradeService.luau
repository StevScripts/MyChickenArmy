--!strict
-- Owns board offers and transactions, not authored GUI or general player input.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Definitions = require(Shared.UpgradeCatalog)
local ArmyService = require(script.Parent.ArmyService)
local UpgradeService = {}
UpgradeService.__index = UpgradeService

local function decimal(value)
	return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end

local function ownerPlot(instance, root)
	local node = instance
	while node and node ~= root do
		local index = node:GetAttribute("PlotIndex")
		if type(index) == "number" then return index end
		node = node.Parent
	end
	return nil
end

function UpgradeService.new(world, rolls)
	return setmetatable({world = world, rolls = rolls, boards = {}}, UpgradeService)
end

function UpgradeService:Start()
	table.clear(self.boards)
	for _, gui in self.world.root:GetDescendants() do
		if gui:IsA("SurfaceGui") and gui:FindFirstChild("UpgradesBoard") then
			local screen = if gui.Parent:IsA("BasePart") then gui.Parent else gui.Adornee
			if screen and screen:IsA("BasePart") and screen:IsDescendantOf(self.world.root) then
				table.insert(self.boards, {screen = screen, plotIndex = ownerPlot(screen, self.world.root)})
			end
		end
	end
end

function UpgradeService:CanUse(player, session)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return false end
	for _, board in self.boards do
		local screen = board.screen
		if screen:IsDescendantOf(self.world.root) and (not board.plotIndex or board.plotIndex == session.plotIndex) then
			local localAt = screen.CFrame:PointToObjectSpace(root.Position)
			local half = screen.Size / 2
			local nearest = Vector3.new(math.clamp(localAt.X, -half.X, half.X),
				math.clamp(localAt.Y, -half.Y, half.Y), math.clamp(localAt.Z, -half.Z, half.Z))
			if (localAt - nearest).Magnitude <= Definitions.BoardDistance then return true end
		end
	end
	return false
end

function UpgradeService:Offers(session)
	local offers = {}
	-- Cash upgrades never require camp visits, victories or an earned rank.
	local function add(key, level, current, price, available)
		local unlocked = available ~= false
		offers[key] = {level = level, currentText = current, price = price, unlocked = unlocked,
			requirement = if available == false then "This plot has no additional upgrade space." else "",
			ready = session.loaded == true and not session.closing and not session.saveLost}
	end
	local production = session:EggProductionMultiplier()
	add("EggSpeed", session.eggSpeedLevel, decimal(Config.EggLaySeconds / production) .. "s",
		Definitions.EggSpeedPrices[session.eggSpeedLevel + 1])
	add("PlotSize", session.plotSizeLevel, "Lv " .. (session.plotSizeLevel + 1),
		Definitions.PlotPrices[session.plotSizeLevel + 1], session.plotExpansionAvailable)
	local income = session:GlobalUpgrade("Income")
	add("EggValue", session.incomeLevel,
		decimal((1 + session.incomeLevel * Config.IncomeMultiplierPerLevel)
			* (if session.entitlements.DoubleCash then 2 else 1)) .. "x",
		income and income.price)
	local army = session:NextSlot()
	add("ArmySize", session.capacity, tostring(session:Capacity()), army and army.price)
	if army then offers.ArmySize.unlocked = army.unlocked; offers.ArmySize.requirement = army.requirement end
	local luck = session:GlobalUpgrade("Luck")
	add("Luck", session.luck, decimal((1 + session.luck * Config.LuckWeightPerLevel)
		* session:PaidLuckMultiplier()) .. "x", luck and luck.price)
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
		local nextProduction = nextRate * (if session.entitlements.DoubleEggSpawn then 2 else 1)
		preview("EggSpeed", decimal(Config.EggLaySeconds / nextProduction) .. "s")
	end
	preview("PlotSize", "Lv " .. (session.plotSizeLevel + 2))
	preview("EggValue", decimal((1 + (session.incomeLevel + 1) * Config.IncomeMultiplierPerLevel)
		* (if session.entitlements.DoubleCash then 2 else 1)) .. "x")
	if army then preview("ArmySize", tostring(army.displayCapacity or army.capacity)) end
	preview("Luck", decimal((1 + (session.luck + 1) * Config.LuckWeightPerLevel)
		* session:PaidLuckMultiplier()) .. "x")
	preview("RollSlots", tostring(math.min(slots + 1, physicalLimit)))
	return offers
end

function UpgradeService:Buy(player, session, key, expectedLevel, expectedPrice)
	if type(key) ~= "string" or not table.find(Definitions.Order, key) then return false, "Choose a board upgrade." end
	if not self:CanUse(player, session) then return false, "Walk up to the upgrades board." end
	local offer = self:Offers(session)[key]
	if not offer.ready then return false, "Wait for your flock to load." end
	if not offer.price then return false, "This upgrade is at its maximum." end
	if not offer.unlocked then return false, offer.requirement end
	-- A replay or stale click never purchases another level at an unexpected price.
	if expectedLevel ~= offer.level or expectedPrice ~= offer.price then return false, "This upgrade changed. Try again." end
	if session.coins < offer.price then return false, "Not enough cash for this upgrade." end
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
