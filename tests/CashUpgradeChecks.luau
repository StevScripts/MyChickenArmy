-- Isolated cash-tree migration checks. No real player, profile, board or world mutations.
local Shared = game.ReplicatedStorage.PetRoll.Shared
local Server = game.ServerStorage.PetRoll
local Config = require(Shared.Config)
local Definitions = require(Shared.UpgradeCatalog)
local ResearchCatalog = require(Shared.ResearchCatalog)
local ResearchRules = require(Shared.ResearchRules)
local Session = require(Server.PlayerSession)
local Rolls = require(Server.RollService)
local Upgrades = require(Server.UpgradeService)
local Research = require(Server.ResearchService)
local GameServer = require(Server.GameServer)
local Checks = {}
local fields = {EggSpeed = "eggSpeedLevel", EggValue = "incomeLevel", PlotSize = "plotSizeLevel",
	ArmySize = "capacity", Luck = "luck", RollSlots = "rollSlotsUnlocked"}

local function same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for key, value in a do if not same(value, b[key]) then return false end end
	for key in b do if a[key] == nil then return false end end
	return true
end
local function fresh()
	local session = Session.new(-68001, "Cash upgrade fixture", 1)
	session.loaded = true; session.coins = 1e11
	session.plotExpansionAvailable = true
	session.rollSlotLimit = Config.RollSlotsUnlocked
	-- No world root, boards, character or proximity override exists in this fixture.
	return session, Upgrades.new({}, Rolls.new())
end
local function buy(session, upgrades, key)
	local offer = assert(upgrades:Offers(session)[key])
	local cash, level = session.coins, session[fields[key]]
	local ok, message = upgrades:Buy({}, session, key, offer.level, offer.price)
	assert(ok, key .. ": " .. tostring(message))
	assert(session.coins == cash - offer.price, key .. " charged incorrectly")
	assert(session[fields[key]] == level + 1, key .. " did not apply immediately")
	return offer
end
local function rejected(session, upgrades, key, level, price)
	local data, revision = session:ToData(), session.revision
	assert(not upgrades:Buy({}, session, key, level, price), tostring(key) .. " unexpectedly bought")
	assert(same(data, session:ToData()) and session.revision == revision, "Rejected purchase mutated state")
end

function Checks.Run()
	local results = {}
	local function check(name, fn)
		local ok, detail = pcall(fn)
		table.insert(results, {name = name, passed = ok, detail = tostring(detail)})
	end
	check("All six tracks buy instantly without a board, character, camp or research", function()
		local session, upgrades = fresh()
		assert(#Definitions.Order == 6)
		local research = ResearchRules.Copy(session.research)
		for _, key in Definitions.Order do buy(session, upgrades, key) end
		assert(same(session.research, research) and #session.research.jobs == 0)
		assert(session.promotion == 1 and next(session.firstWins) == nil and next(session.frontierWins) == nil)
		assert(session.tutorial.upgraded and session:CollectionLimit() == Definitions.PlotCapacity(1))
	end)
	check("CashUpgrade and legacy BoardUpgrade dispatch through the same transaction", function()
		local session, upgrades = fresh()
		local deliveries, updates = {}, 0
		local server = setmetatable({sessions = {[session.userId] = session}, limits = {}, upgrades = upgrades,
			armyCommands = {Sync = function() end}, world = {UpdateSession = function() updates += 1 end},
			Send = function(_, _, result) table.insert(deliveries, result) end}, GameServer)
		for index, action in {"CashUpgrade", "BoardUpgrade"} do
			local offer = upgrades:Offers(session).EggSpeed
			local before = session.coins
			server:Handle({UserId = session.userId}, {action = action, id = index, upgradeKey = "EggSpeed",
				expectedLevel = offer.level, expectedPrice = offer.price})
			assert(deliveries[index].ok and deliveries[index].action == action)
			assert(session.eggSpeedLevel == index and session.coins == before - offer.price)
		end
		assert(updates == 2)
	end)
	check("Stale quotes and duplicate clicks never debit a second level", function()
		for _, key in Definitions.Order do
			local session, upgrades = fresh()
			local offer = upgrades:Offers(session)[key]
			rejected(session, upgrades, key, offer.level + 1, offer.price)
			rejected(session, upgrades, key, offer.level, offer.price + 1)
			buy(session, upgrades, key)
			rejected(session, upgrades, key, offer.level, offer.price)
		end
		local session, upgrades = fresh()
		for _, key in {"SellingSpeed", "FinishNow", "A1", "", 5, {}} do rejected(session, upgrades, key, 0, 1) end
	end)
	check("Insufficient cash and loading, closing or lost profiles still reject every track", function()
		for _, key in Definitions.Order do
			local session, upgrades = fresh()
			local offer = upgrades:Offers(session)[key]
			session.coins = offer.price - 1
			rejected(session, upgrades, key, offer.level, offer.price)
			session.coins = offer.price
			for _, field in {"loaded", "closing", "saveLost"} do
				local old = session[field]; session[field] = field ~= "loaded"
				assert(not upgrades:Offers(session)[key].ready)
				rejected(session, upgrades, key, offer.level, offer.price)
				session[field] = old
			end
		end
	end)
	check("Configured maxima remain finite and reject the next purchase", function()
		local counts = {EggSpeed = #Definitions.EggSpeedPrices, EggValue = #Config.IncomePrices,
			PlotSize = #Definitions.PlotPrices, ArmySize = Config.MaxSlots - Config.StartingSlots,
			Luck = #Config.LuckPrices, RollSlots = Config.RollSlotsUnlocked - 1}
		for _, key in Definitions.Order do
			local session, upgrades = fresh()
			for _ = 1, counts[key] do buy(session, upgrades, key) end
			local offer = upgrades:Offers(session)[key]
			assert(offer.price == nil and offer.nextText == nil)
			rejected(session, upgrades, key, offer.level, 0)
		end
	end)
	check("Physical plot and podium limits remain authoritative and retain owned slots", function()
		local session, upgrades = fresh()
		session.plotExpansionAvailable = false
		local plot = upgrades:Offers(session).PlotSize
		assert(not plot.unlocked); rejected(session, upgrades, "PlotSize", plot.level, plot.price)
		session.rollSlotLimit = 1
		assert(upgrades:Offers(session).RollSlots.price == nil)
		rejected(session, upgrades, "RollSlots", 1, Definitions.RollSlotPrices[1])
		session.rollSlotsUnlocked = 8
		rejected(session, upgrades, "RollSlots", 8, 0)
		assert(session.rollSlotsUnlocked == 8)
	end)
	check("A fully occupied research queue does not block or consume instant cash upgrades", function()
		local session, upgrades = fresh()
		local node = ResearchCatalog.Nodes.A1
		assert(Research.Start(session, node.id, session.research.revision, node.price,
			ResearchRules.Duration(node, session.researchEffects), 100))
		assert(#session.research.jobs == session.researchEffects.slots)
		local research = ResearchRules.Copy(session.research)
		for _, key in Definitions.Order do buy(session, upgrades, key) end
		assert(same(session.research, research), "Cash upgrade changed a research job or revision")
	end)
	check("Egg Speed next preview includes the same paid and research bonuses as current production", function()
		local session, upgrades = fresh()
		for _, id in {"E1", "E2", "E3"} do session.research.completed[id] = true end
		session.researchEffects = ResearchRules.Effects(session.research)
		session.entitlements.DoubleEggSpawn = true
		local offer = upgrades:Offers(session).EggSpeed
		assert(offer.currentText == "2.4x" and offer.nextText == "2.76x")
		buy(session, upgrades, "EggSpeed")
		assert(upgrades:Offers(session).EggSpeed.currentText == offer.nextText)
		assert(math.abs(session:EggProductionMultiplier() - 2.76) < 1e-10)
	end)
	check("Saved levels, balances, earned eggs and manual army members survive migration purchases", function()
		local session, upgrades = fresh()
		local selected = session:BestPetIds(); session.armySelection = table.clone(selected)
		local reserve = session:AddPet("Duck", 1)
		session.eggCarry = {count = 3, value = 77}
		session.eggProcessor.level = 5; session.eggProcessor.finishCredits = 2
		local earned = session:ToData()
		for _, key in Definitions.Order do buy(session, upgrades, key) end
		for index, id in selected do assert(session.armySelection[index] == id, "Manual selection replaced") end
		assert(table.find(session.armySelection, reserve.id), "Bought army slot did not add the reserve")
		assert(same(session.eggCarry, earned.eggCarry) and same(session.eggProcessor, earned.eggProcessor))
		assert(same(session:ToData().pets, earned.pets))
		local restored = fresh(); assert(restored:LoadData(session:ToData()))
		for _, field in fields do assert(restored[field] == session[field], field .. " did not save") end
		assert(restored.coins == session.coins and same(restored.armySelection, session.armySelection))
		assert(restored:CollectionLimit() == session:CollectionLimit())
		assert(restored:EggProductionMultiplier() == session:EggProductionMultiplier())
		assert(same(restored.eggCarry, earned.eggCarry) and same(restored.eggProcessor, earned.eggProcessor))
	end)
	return results
end

return Checks
