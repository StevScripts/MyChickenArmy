-- Isolated contract checks using caller-supplied source strings keyed by src path.
-- No DataStore, real players/purchases, Studio world or shared module-cache reuse.
-- Board access is a fake boundary; this fixture does not verify authored geometry.
return function(sources, onlyNames)
	local cache, serial = {}, 0
	local function folder(name)
		return setmetatable({Name = name}, {__index = function(self, key)
			local node = {Name = key, Parent = self, path = "src/" .. name .. "/" .. key .. ".luau"}
			rawset(self, key, node)
			return node
		end})
	end
	local shared, server = folder("shared"), folder("server")
	local services = {ReplicatedStorage = {PetRoll = {Shared = shared}},
		HttpService = {GenerateGUID = function()
			serial += 1; return "upgrade-progression-" .. serial
		end},
		Players = {}, DataStoreService = {}, RunService = {IsStudio = function() return false end}}
	local original = getfenv()
	local loadModule
	loadModule = function(node)
		if cache[node.path] then return cache[node.path] end
		local fn, err = loadstring(assert(sources[node.path], "Missing source: " .. node.path), node.path)
		assert(fn, err)
		setfenv(fn, setmetatable({script = node, require = loadModule,
			game = {JobId = "", GameId = 0, GetService = function(_, name) return assert(services[name], "Unexpected service: " .. name) end}},
			{__index = original}))
		local result = fn(); cache[node.path] = result
		return result
	end
	local Config = loadModule(shared.Config)
	local Definitions = loadModule(shared.UpgradeCatalog)
	local Rules = loadModule(shared.Rules)
	local Catalog = loadModule(shared.PetCatalog)
	local Currency = loadModule(shared.CurrencyLimits)
	local Session = loadModule(server.PlayerSession)
	local Upgrades = loadModule(server.UpgradeService)
	local Army = loadModule(server.ArmyService)
	local Roll = loadModule(server.RollService)
	local results = {}
	local function check(name, fn)
		if onlyNames and not onlyNames[name] then return end
		local ok, err = pcall(fn)
		table.insert(results, {name = name, passed = ok, error = if ok then nil else tostring(err)})
	end
	local function close(actual, expected)
		assert(type(actual) == "number" and math.abs(actual - expected) < 1e-8,
			tostring(actual) .. " ~= " .. tostring(expected))
	end
	local function same(actual, expected)
		if type(actual) ~= type(expected) then return false end
		if type(actual) ~= "table" then return actual == expected end
		for key, value in actual do if not same(value, expected[key]) then return false end end
		for key in expected do if actual[key] == nil then return false end end
		return true
	end
	local function fresh()
		local s = Session.new(700, "Upgrade progression fixture", 1)
		s.loaded = true; s.plotExpansionAvailable = true
		s.rollSlotLimit = Config.RollSlotsUnlocked; s.rollSlotCount = 1
		return s
	end
	local function board()
		local b = Upgrades.new({}, Roll.new())
		b.CanUse = function() return true end
		return b
	end
	local fields = {EggSpeed = "eggSpeedLevel", EggValue = "incomeLevel", Luck = "luck",
		PlotSize = "plotSizeLevel", ArmySize = "capacity", RollSlots = "rollSlotsUnlocked"}
	local function priceValid(price)
		assert(type(price) == "number" and price > 0 and price <= Currency.MaxCoins and price % 1 == 0,
			"Invalid or unrepresentable price: " .. tostring(price))
	end
	local function buy(b, s, key)
		local offer = assert(b:Offers(s)[key], key)
		assert(offer.ready and offer.unlocked and offer.price, key .. " missing eligible offer")
		priceValid(offer.price)
		assert(offer.nextText ~= nil, key .. " missing next benefit")
		-- Fund only this fake wallet at each step; no assumption that the curve fits 1e9.
		s.coins = offer.price
		local before = s[fields[key]]
		local ok, why = b:Buy({}, s, key, offer.level, offer.price)
		assert(ok, why)
		assert(s.coins == 0 and s[fields[key]] == before + 1, key .. " incorrect charge/level")
		-- Mirror the established world binding without loading or modifying world objects.
		s.rollSlotCount = math.min(s.rollSlotLimit, s.rollSlotsUnlocked)
		assert(s.promotion == 1 and next(s.firstWins) == nil and next(s.frontierWins) == nil and not s.kingCleared)
		return offer
	end
	local function rejected(b, s, key, level, price)
		local before, revision = s:ToData(), s.revision
		assert(not b:Buy({}, s, key, level, price), key .. " unexpectedly purchased")
		assert(same(s:ToData(), before) and s.revision == revision, key .. " rejection mutated profile")
	end
	local function expectedLuck(level)
		return 1 + level * 0.10
	end
	local function assertOdds(actual, expected)
		local total = 0
		for _, id in Catalog.Order do
			close(actual[id], expected[id])
			assert(actual[id] >= 0 and actual[id] <= 1)
			if Catalog[id].weight == 0 then close(actual[id], 0) end
			total += actual[id]
		end
		close(total, 1)
	end
	local function rarityChance(odds, rarities)
		local chance = 0
		for _, id in Catalog.Order do
			if table.find(rarities, Catalog[id].rarity) then chance += odds[id] end
		end
		return chance
	end
	local function atLeastIncome(odds, income)
		local chance = 0
		for _, id in Catalog.Order do
			if Catalog[id].income >= income then chance += odds[id] end
		end
		return chance
	end
	local function displayNumber(text)
		return tonumber(string.match(text or "", "[%d%.]+"))
	end

	check("Finite tracks have complete prices/benefits and the eight-slot maximum", function()
		assert(#Definitions.EggSpeedPrices == 25 and #Definitions.EggSpeedRates == 26)
		assert(#Config.IncomePrices == 25 and #Config.LuckPrices == 20)
		assert(#Definitions.PlotScales == #Definitions.PlotPrices + 1)
		assert(Config.LegacyCollectionLimit == 100 and Config.MaxSlots == 10 and Config.RollSlotsUnlocked == 8)
		assert(#Definitions.RollSlotPrices == Config.RollSlotsUnlocked - 1 and #Definitions.PlotCapacities == #Definitions.PlotPrices + 1)
		for _, prices in {Definitions.EggSpeedPrices, Config.IncomePrices, Config.LuckPrices,
			Definitions.PlotPrices, Definitions.RollSlotPrices} do
			for index = 1, #prices do priceValid(prices[index]) end
		end
		for index = 2, 26 do assert(Definitions.EggSpeedRates[index] > Definitions.EggSpeedRates[index - 1]) end
		close(Definitions.EggSpeedRates[26], 4.75)
		close(Rules.EggUnitValue(25), 29)
		local s = fresh(); s.plotSizeLevel = #Definitions.PlotPrices
		assert(s:CollectionLimit() == 100)
		for index = 1, #Definitions.PlotScales do
			assert(Definitions.PlotScales[index] > 0 and Definitions.PlotScales[index] <= 1.2)
			if index > 1 then assert(Definitions.PlotScales[index] >= Definitions.PlotScales[index - 1]) end
		end
		close(Definitions.PlotScales[#Definitions.PlotScales], 1.2)
	end)

	check("First four Speed/Value/Luck prices and benefits remain exact", function()
		local incomePrices = {2880, 63000, 725760, 3628800}
		local luckPrices = {1920, 42000, 483840, 2419200}
		local rates = {1, 1.15, 1.30, 1.45, 1.60}
		for index = 1, 4 do
			assert(Config.IncomePrices[index] == incomePrices[index])
			assert(Definitions.EggSpeedPrices[index] == incomePrices[index])
			assert(Config.LuckPrices[index] == luckPrices[index])
		end
		local s = fresh()
		for level = 0, 4 do
			s.eggSpeedLevel = level
			close(s:EggProductionMultiplier(), rates[level + 1])
			close(Rules.EggUnitValue(level), 4 + level)
			close(Rules.LuckMultiplier(level), 1 + 0.10 * level)
		end
	end)

	check("Roll Slot opening prices stay fixed, all eight are purchasable, and the sixth is reduced", function()
		local prices = Definitions.RollSlotPrices
		assert(#prices == 7 and prices[1] == 1200 and prices[2] == 4800)
		assert(prices[3] == 120000 and prices[4] == 6000000 and prices[5] < 600000000)
		for index = 2, #prices do
			priceValid(prices[index])
			assert(prices[index] > prices[index - 1], "Later Roll Slots must cost more")
		end
	end)

	check("Every board track purchases fully without camps, then MAX rejects", function()
		for _, key in Definitions.Order do
			local s, b = fresh(), board()
			local expectedSteps = ({EggSpeed = 25, EggValue = 25, Luck = 20,
				PlotSize = #Definitions.PlotPrices, ArmySize = Config.MaxSlots - Config.StartingSlots,
				RollSlots = Config.RollSlotsUnlocked - 1})[key]
			for _ = 1, expectedSteps do
				local low = b:Offers(s)[key]
				s.promotion, s.recruitTier, s.kingCleared = 4, 4, true
				s.firstWins, s.frontierWins = {true, true}, {true, true}
				local high = b:Offers(s)[key]
				assert(high.price == low.price and high.unlocked == low.unlocked and low.unlocked)
				s.promotion, s.recruitTier, s.kingCleared = 1, 1, false
				s.firstWins, s.frontierWins = {}, {}
				buy(b, s, key)
			end
			local final = b:Offers(s)[key]
			assert(final.price == nil and final.nextText == nil, key .. " has an extra purchase/preview")
			rejected(b, s, key, final.level, 0)
			assert(s:CollectionLimit() <= 100 and s:Capacity() <= 10 and s.rollSlotsUnlocked <= 8)
		end
	end)

	check("All board tracks reject unready state, stale quotes, replay, access and insufficient funds", function()
		for _, key in Definitions.Order do
			local s, b = fresh(), board()
			local offer = b:Offers(s)[key]; s.coins = offer.price
			for _, field in {"loaded", "closing", "saveLost"} do
				local previous = s[field]; s[field] = field ~= "loaded"
				assert(not b:Offers(s)[key].ready)
				rejected(b, s, key, offer.level, offer.price); s[field] = previous
			end
			rejected(b, s, key, offer.level + 1, offer.price)
			rejected(b, s, key, offer.level, offer.price + 1)
			s.coins = offer.price - 1; rejected(b, s, key, offer.level, offer.price)
			s.coins = offer.price; b.CanUse = function() return false end
			rejected(b, s, key, offer.level, offer.price)
			b.CanUse = function() return true end
			buy(b, s, key)
			s.coins = Currency.MaxCoins
			rejected(b, s, key, offer.level, offer.price)
		end
	end)

	check("Plot capacity previews and physical limits remain authoritative", function()
		local s, b = fresh(), board()
		for level = 0, #Definitions.PlotPrices do
			s.plotSizeLevel = level
			local offer = b:Offers(s).PlotSize
			local capacities = {25, 30, 35, 40, 45, 50, 75, 100}
			local capacity = capacities[level + 1]
			assert(s:CollectionLimit() == capacity)
			close(displayNumber(offer.currentText), capacity)
			if level < #Definitions.PlotPrices then
				close(displayNumber(offer.nextText), capacities[level + 2])
			else assert(offer.nextText == nil and offer.price == nil) end
		end
		s.plotSizeLevel = 0; s.plotExpansionAvailable = false
		local offer = b:Offers(s).PlotSize; s.coins = offer.price
		assert(not offer.unlocked); rejected(b, s, "PlotSize", offer.level, offer.price)
		for _, physical in {1, 3, 6, 8} do
			local p = fresh(); p.rollSlotLimit = physical
			for _ = 2, physical do buy(b, p, "RollSlots") end
			assert(p.rollSlotsUnlocked == physical and b:Offers(p).RollSlots.price == nil)
			rejected(b, p, "RollSlots", physical, 1)
			-- Retain an owned eight-slot entitlement on a smaller authored plot.
			p.rollSlotsUnlocked = 8; p.rollSlotCount = physical
			assert(b:Offers(p).RollSlots.price == nil)
			assert(Roll.new():Roll(p, 100))
			assert(#p.offers == physical and p.rollSlotsUnlocked == 8)
		end
		local p = fresh(); p.rollSlotCount = 99
		assert(Roll.new():Roll(p, 100)); assert(#p.offers == 8)
	end)

	check("Legacy menu owners reach identical Income/Luck/Army maxima without camps", function()
		local s, rolls = fresh(), Roll.new()
		for _ = 1, 25 do
			s.coins = assert(s:GlobalUpgrade("Income")).price
			assert(Army.UpgradeIncome(s)); assert(s.coins == 0)
		end
		for _ = 1, 20 do
			s.coins = assert(s:GlobalUpgrade("Luck")).price
			assert(rolls:UpgradeLuck(s)); assert(s.coins == 0)
		end
		for _ = Config.StartingSlots + 1, Config.MaxSlots do
			s.coins = assert(s:NextSlot()).price; assert(Army.Expand(s)); assert(s.coins == 0)
		end
		assert(s.incomeLevel == 25 and s.luck == 20 and s.capacity == 10)
		assert(not Army.UpgradeIncome(s) and not rolls:UpgradeLuck(s) and not Army.Expand(s))
		assert(s.promotion == 1 and next(s.firstWins) == nil and next(s.frontierWins) == nil)
	end)

	check("Luck helper, display, normalized odds and actual rolls agree at curve boundaries", function()
		local s, b, rolls = fresh(), board(), Roll.new()
		-- Ordinary odds must not be replaced by the tutorial's forced recruit.
		s.tutorial.bought = true
		for _, level in {0, 4, 5, 19, 20} do
			s.luck = level
			close(Rules.LuckMultiplier(level), expectedLuck(level))
			local offer = b:Offers(s).Luck
			close(displayNumber(offer.currentText), expectedLuck(level))
			if level < 20 then close(displayNumber(offer.nextText), expectedLuck(level + 1))
			else assert(offer.nextText == nil and offer.price == nil) end
			local expected = Rules.Odds(level, 1, 1)
			assertOdds(Rules.Odds(level, 4, 1), expected)
			assertOdds(s:Snapshot(0).odds, expected)
			close(offer.rarePlusChance, rarityChance(expected, {"Rare", "Epic", "Legendary", "Mythic"}))
			close(offer.epicPlusChance, rarityChance(expected, {"Epic", "Legendary", "Mythic"}))
			local window = Rules.LuckWindow(level, 1, 0)
			close(offer.topBandChance, atLeastIncome(expected, window.topIncome))
			assert(offer.window.topName == window.topName)
			assert(offer.windowText == offer.window.rangeText and offer.windowText ~= "")
			if level < 20 then
				local nextOdds = Rules.Odds(level + 1, 1, 1)
				close(offer.nextRarePlusChance, rarityChance(nextOdds, {"Rare", "Epic", "Legendary", "Mythic"}))
				close(offer.nextEpicPlusChance, rarityChance(nextOdds, {"Epic", "Legendary", "Mythic"}))
				close(offer.nextTopBandChance, atLeastIncome(nextOdds, Rules.LuckWindow(level + 1, 1, 0).topIncome))
				assert(offer.nextWindowText == offer.nextWindow.rangeText and offer.nextWindowText ~= "")
			else
				assert(offer.nextRarePlusChance == nil and offer.nextEpicPlusChance == nil and offer.nextTopBandChance == nil)
				assert(offer.nextWindow == nil and offer.nextWindowText == nil)
			end
			-- Midpoints independently exercise every catalog interval in the actual draw path.
			local cumulative = 0
			for _, id in Catalog.Order do
				local chance = expected[id]
				if chance > 0 then
					local sample = cumulative + chance / 2
					assert(Rules.Draw(level, sample, 1, 1) == id)
					rolls.random = {NextNumber = function() return sample end}
					s.rollReadyAt = 0
					assert(rolls:Roll(s, 100)); assert(s.offer.species == id)
					close(s.offer.chance, chance)
				end
				cumulative += chance
			end
		end
		close(Rules.LuckMultiplier(20), 3)
	end)

	check("Paid benefits retain verified Luck policy and existing multipliers/army bonus", function()
		local s, b = fresh(), board()
		s.eggSpeedLevel, s.incomeLevel, s.luck, s.capacity = 25, 25, 20, 10
		s.entitlements = {DoubleEggSpawn = true, DoubleCash = true, DoubleLuck = true, BiggerArmy = true}
		s.paidRandomAllowed = true
		close(s:EggProductionMultiplier(), 9.5); assert(s:Capacity() == 15)
		close(displayNumber(b:Offers(s).EggSpeed.currentText), 9.5)
		close(displayNumber(b:Offers(s).Luck.currentText), 6)
		assertOdds(s:Snapshot(0).odds, Rules.Odds(20, 1, 2))
		close(s:PetEggRate("Duck", 1, 1), Rules.EggRate("Duck", 1, 1) * 9.5)
		close(s:DisplayedPetIncome("Duck", 1, 1), Rules.EggRate("Duck", 1, 1) * 9.5 * 29 * 2)
		s.eggSpeedLevel, s.luck = 24, 19
		close(displayNumber(b:Offers(s).EggSpeed.nextText), 9.5)
		close(displayNumber(b:Offers(s).Luck.nextText), 6)
		s.paidRandomAllowed = false
		close(s:PaidLuckMultiplier(), 1)
		assertOdds(s:Snapshot(0).odds, Rules.Odds(19, 1, 1))
		local restored = fresh(); assert(restored:LoadData(s:ToData()))
		assert(next(restored.entitlements) == nil, "Verified passes must not be serialized")
	end)

	check("Maximum levels roundtrip; MAX+1 and malformed levels reject without partial load", function()
		local s = fresh()
		s.eggSpeedLevel, s.incomeLevel, s.luck = 25, 25, 20
		s.plotSizeLevel, s.rollSlotsUnlocked, s.capacity = #Definitions.PlotPrices, 8, 10
		s.coins = 12345
		local data, restored = s:ToData(), fresh()
		assert(restored:LoadData(data))
		for _, field in fields do assert(restored[field] == s[field], field .. " did not roundtrip") end
		assert(restored.coins == 12345 and restored:CollectionLimit() == 100 and restored.promotion == 1)
		assert(restored:Count() == s:Count())
		for field, maximum in {eggSpeedLevel = 25, incomeLevel = 25, luck = 20,
			plotSizeLevel = #Definitions.PlotPrices, rollSlotsUnlocked = 8, capacity = 10} do
			for _, bad in {maximum + 1, -1, 0.5, math.huge, 0/0, "1"} do
				local invalid = s:ToData(); invalid[field] = bad
				local before, revision = restored:ToData(), restored.revision
				assert(not restored:LoadData(invalid), field .. " accepted " .. tostring(bad))
				assert(same(restored:ToData(), before) and restored.revision == revision)
			end
		end
	end)

	check("Earned carried/queued value and owned purchases survive all upgrades and roundtrip", function()
		local s, b = fresh(), board()
		s.eggCarry = {count = 3, value = 77}
		s.eggProcessor.batches = {{count = 5, value = 123}, {count = 7, value = 456}}
		s.eggProcessor.readyValue = 89; s.eggProcessor.progress = 0.25
		s.eggProcessor.level = 5; s.eggProcessor.finishCredits = 2
		local earned = s:ToData()
		for _, key in Definitions.Order do
			for _ = 1, 30 do
				if not b:Offers(s)[key].price then break end
				buy(b, s, key)
			end
			assert(b:Offers(s)[key].price == nil)
		end
		assert(same(s.eggCarry, earned.eggCarry) and same(s.eggProcessor, earned.eggProcessor))
		local restored = fresh(); assert(restored:LoadData(s:ToData()))
		assert(same(restored.eggCarry, earned.eggCarry) and same(restored.eggProcessor, earned.eggProcessor))
		assert(restored.rollSlotsUnlocked == 8 and restored.plotSizeLevel == #Definitions.PlotPrices)
		assert(same(restored:ToData().pets, earned.pets))
	end)

	check("Stat continuation quotes follow the reviewed growth and rounding exactly", function()
		for level = 5, 25 do
			local price = math.ceil(3628800 * 1.35 ^ (level - 4) / 1000) * 1000
			assert(Config.IncomePrices[level] == price and Definitions.EggSpeedPrices[level] == price)
			assert(price > Config.IncomePrices[level - 1])
		end
		for level = 5, 20 do
			local price = math.ceil(2419200 * 1.25 ^ (level - 4) / 1000) * 1000
			assert(Config.LuckPrices[level] == price and price > Config.LuckPrices[level - 1])
		end
		assert(Config.IncomePrices[5] == 5807000 and Config.IncomePrices[25] == 70191201000)
		assert(Config.LuckPrices[5] == 3024000 and Config.LuckPrices[20] == 85948000)
	end)

	check("Existing opening levels and legacy missing board fields retain earned capacity/slots", function()
		for level = 0, 4 do
			local s = fresh()
			s.eggSpeedLevel, s.incomeLevel, s.luck, s.plotSizeLevel = level, level, level, level
			s.rollSlotsUnlocked = 6
			local restored = fresh(); assert(restored:LoadData(s:ToData()))
			assert(restored:CollectionLimit() == s:CollectionLimit() and restored.rollSlotsUnlocked == 6)
			close(restored:EggProductionMultiplier(), 1 + level * 0.15)
			close(Rules.EggUnitValue(restored.incomeLevel), 4 + level)
			close(Rules.LuckMultiplier(restored.luck), 1 + level * 0.10)
		end
		local data = fresh():ToData()
		data.eggSpeedLevel, data.plotSizeLevel, data.rollSlotsUnlocked = nil, nil, nil
		local restored = fresh(); assert(restored:LoadData(data))
		assert(restored.eggSpeedLevel == 0 and restored.plotSizeLevel == 0 and restored.rollSlotsUnlocked == 6)
	end)

	check("New profiles start at 25 and buy seven expansions through 100", function()
		local s, b = fresh(), board()
		assert(Config.DataRevision == 11 and s.dataRevision == 11 and s:CollectionLimit() == 25)
		assert(s.plotSizeLevel == 0 and Definitions.PlotScales[1] == 0.8)
		local prices = {480, 1200, 2400, 2880, 63000, 725760, 3628800}
		assert(#Definitions.PlotPrices == 7 and #Definitions.PlotScales == 8)
		for level = 1, 7 do
			assert(b:Offers(s).PlotSize.price == prices[level])
			buy(b, s, "PlotSize")
			assert(s:CollectionLimit() == ({25, 30, 35, 40, 45, 50, 75, 100})[level + 1])
		end
		assert(b:Offers(s).PlotSize.price == nil)
		local restored = fresh(); assert(restored:LoadData(fresh():ToData()))
		assert(restored.plotSizeLevel == 0 and restored:CollectionLimit() == 25)
	end)

	check("Every flock limit accepts its last recruit, rejects overflow without charging, and saves 100", function()
		for level, capacity in {25, 30, 35, 40, 45, 50, 75, 100} do
			local s, rolls = fresh(), Roll.new()
			s.plotSizeLevel = level - 1
			while s:Count() < capacity - 1 do s:AddPet("Duck", 1) end
			s.coins = 1000; s.rollRevealAt = 0
			s.offers = {{id = "last-slot", species = "Duck", level = 1, price = 100}}
			assert(rolls:Buy(s, "last-slot", 100))
			assert(s:Count() == capacity and s.coins == 900)
			s.offers = {{id = "overflow", species = "Duck", level = 1, price = 100}}
			local before = s:ToData()
			assert(not rolls:Buy(s, "overflow", 100))
			assert(same(s:ToData(), before) and s.offers[1].id == "overflow")
			local restored = fresh(); assert(restored:LoadData(before))
			assert(restored:Count() == capacity and restored:CollectionLimit() == capacity)
			assert(same(restored:ToData().pets, before.pets))
			if capacity == 100 then
				s:AddPet("Duck", 1)
				local valid = restored:ToData()
				assert(not restored:LoadData(s:ToData()))
				assert(same(restored:ToData(), valid), "101-bird save partially loaded")
			end
		end
	end)

	check("Old plot levels migrate once, retain inventory/prices and gain the final capacities", function()
		local oldScales = {1, 1.05, 1.10, 1.15, 1.20}
		local oldPrices = {2880, 63000, 725760, 3628800}
		for revision = 6, 10 do for level = 0, 4 do
			local s = fresh()
			-- Include a full 60-bird legacy inventory; never delete overflow chickens.
			while s:Count() < 60 do s:AddPet("Duck", 1) end
			local data = s:ToData(); data.dataRevision = revision; data.plotSizeLevel = level
			data.rollSlotsUnlocked = 6
			local restored = fresh(); assert(restored:LoadData(data))
			assert(data.dataRevision == revision and data.plotSizeLevel == level, "Input save was mutated")
			assert(restored.plotSizeLevel == level + 3 and restored:CollectionLimit() == ({40, 45, 50, 75, 100})[level + 1])
			close(Definitions.PlotScales[restored.plotSizeLevel + 1], oldScales[level + 1])
			assert(board():Offers(restored).PlotSize.price == oldPrices[level + 1])
			assert(restored.rollSlotsUnlocked == 6 and same(restored:ToData().pets, data.pets))
			assert(restored.coins == data.coins and restored:Count() == 60)
			local current = restored:ToData(); assert(current.dataRevision == 11)
			for _ = 1, 3 do
				assert(restored:LoadData(current))
				assert(restored.plotSizeLevel == level + 3)
				current = restored:ToData()
			end
		end end
		local data = fresh():ToData(); data.dataRevision = 10; data.plotSizeLevel = nil; data.rollSlotsUnlocked = nil
		local restored = fresh(); assert(restored:LoadData(data))
		assert(restored.plotSizeLevel == 3 and restored:CollectionLimit() == 40 and restored.rollSlotsUnlocked == 6)
	end)

	check("Migration validates old levels and complete payload before committing", function()
		local s = fresh(); local before = s:ToData()
		for _, bad in {5, 7, -1, 0.5, math.huge, 0/0, "1"} do
			local data = fresh():ToData(); data.dataRevision = 10; data.plotSizeLevel = bad
			assert(not s:LoadData(data) and same(s:ToData(), before))
		end
		local data = fresh():ToData(); data.dataRevision = 10; data.plotSizeLevel = 4
		data.passiveEarned = -1 -- A late validation failure must not commit converted levels.
		assert(not s:LoadData(data) and same(s:ToData(), before))
		data = fresh():ToData(); data.dataRevision = 12
		assert(not s:LoadData(data) and same(s:ToData(), before))
	end)

	check("DataService commits revision 11 through its existing isolated store path", function()
		local Data = loadModule(server.DataService)
		local function copy(value)
			if type(value) ~= "table" then return value end
			local result = {}; for k, v in value do result[k] = copy(v) end; return result
		end
		for _, oldLevel in {-1, 0, 4} do
			local stored
			if oldLevel >= 0 then
				local data = fresh():ToData(); data.dataRevision = 10; data.plotSizeLevel = oldLevel
				stored = {schemaVersion = 1, data = data, updatedAt = 900}
			end
			local fakeStore = {UpdateAsync = function(_, _, callback)
				local result = callback(copy(stored))
				if result ~= nil then stored = copy(result) end
				return copy(result)
			end}
			local dataService = Data.new(fakeStore, function() return 1000 end)
			local s = fresh(); s.loaded = false
			assert(dataService:Load(s))
			local expected = if oldLevel < 0 then 0 else oldLevel + 3
			assert(s.loaded and s.plotSizeLevel == expected)
			assert(stored.data.dataRevision == 11 and stored.data.plotSizeLevel == expected)
		end
	end)

	check("Smaller runtime yard bounds scale from original geometry without cumulative shrink", function()
		local Plot = loadModule(server.PlotUpgradeService)
		local Layout = loadModule(shared.HomePlotLayout)
		local model = Instance.new("Model")
		local ok, err = pcall(function()
			local yard = Instance.new("Folder"); yard.Name = "ChickenYard"; yard.Parent = model
			local floor = Instance.new("Part"); floor.Name = "YardFloor"; floor.Size = Vector3.new(30, 1, 30)
			floor.Anchored = true; floor.Parent = yard
			local plot = Plot.new(model, 700, CFrame.new())
			assert(plot.available)
			for _, level in {0, 3, 7, 0, 7} do
				plot:SetLevel(level)
				local scale = Definitions.PlotScales[level + 1]
				assert(math.abs(floor.Size.X - 30 * scale) < 1e-4)
				local bounds = Layout.ForPlot(700)
				assert(math.abs(bounds.YardMaxX - (15 * scale - 1.6)) < 1e-4)
				assert(bounds.YardMaxX > bounds.YardMinX and bounds.YardMaxZ > bounds.YardMinZ)
			end
			plot:Destroy()
		end)
		model:Destroy(); Layout.SetYard(700, nil)
		assert(ok, err)
	end)
	check("Longer deck keeps the square and early stages fixed, fits the final T, and has 100 unique homes", function()
		local Plot = loadModule(server.PlotUpgradeService)
		local Layout = loadModule(shared.HomePlotLayout)
		local model = Instance.new("Model")
		local ok, err = pcall(function()
			local frame = CFrame.new(346.48, -2.39, -195) * CFrame.Angles(0, math.rad(120), 0)
			local yard = Instance.new("Folder"); yard.Name = "ChickenYard"; yard.Parent = model
			yard:SetAttribute("ExpansionShape", "T")
			local boundary = Instance.new("Folder"); boundary.Name = "Boundary"; boundary.Parent = yard
			local edge = Instance.new("Part"); edge.Name = "Beam"; edge.Size = Vector3.new(30, 0.01, 30)
			edge.CFrame = frame * CFrame.new(0, 5.05, -18.5); edge.Parent = boundary
			for i = 1, 8 do
				local a, b, beam = Instance.new("Attachment"), Instance.new("Attachment"), Instance.new("Beam")
				a.Parent, b.Parent = edge, edge
				beam.Name = "YardEdge" .. i; beam.Attachment0, beam.Attachment1 = a, b; beam.Parent = edge
			end
			local fence = Instance.new("Folder"); fence.Name = "BoundaryFence"; fence.Parent = model
			fence:SetAttribute("ExpansionMaxBack", 62.5); fence:SetAttribute("ExpansionMaxHalfWidth", 44)
			fence:SetAttribute("ExpansionLateDepth", 20)
			local positions = {Left = {{-38, -58.18}, {-38, 13.5}}, Right = {{38, -58.18}, {38, 13.5}},
				Front = {{-38, -58.18}, {-10, -58.18}, {9, -58.18}, {38, -58.18}}, Back = {{-38, 13.5}, {38, 13.5}}}
			for side, points in positions do
				local group = Instance.new("Folder"); group.Name = side; group.Parent = fence
				for _, point in points do
					local post = Instance.new("Part"); post.Size = Vector3.new(1, 3, 1)
					post.CFrame = frame * CFrame.new(point[1], 6, point[2]); post.Parent = group
				end
			end
			local machine = Instance.new("Part"); machine.CFrame = frame * CFrame.new(-29, 7, -19); machine.Parent = model
			local originalMachine = machine.CFrame
			local plot = Plot.new(model, 701, frame)
			local depths = {30, 36, 42, 49, 57, 63, 79, 94}
			local widths = {30, 30, 30, 30, 48, 60, 72, 84}
			local capacities = {25, 30, 35, 40, 45, 50, 75, 100}
			for _, level in {0, 1, 2, 3, 4, 5, 6, 7, 0, 7} do
				plot:SetLevel(level)
				assert((machine.CFrame.Position - originalMachine.Position).Magnitude == 0)
				local at = frame:PointToObjectSpace(edge.Position)
				assert(math.abs(at.Z - edge.Size.Z / 2 + 33.5) < 0.001, "Starter front moved")
				assert(math.abs(edge.Size.Z - depths[level + 1]) < 0.001)
				assert(math.abs(edge.Size.X - widths[level + 1]) < 0.001)
				local expectedBack = 13.5 + 29 * level / 7 + math.max(0, level - 5) * 10
				for _, post in fence.Back:GetChildren() do
					local back = frame:PointToObjectSpace(post.Position).Z
					assert(math.abs(back - expectedBack) < 0.001, "Fence stage drifted")
					assert(back < 131.853668 / 2 - 3, "Fence exceeds enlarged deck")
					assert(back > at.Z + edge.Size.Z / 2, "Yard crosses fence")
				end
				local bounds, occupied = Layout.ForPlot(701), {}
				for index = 1, capacities[level + 1] do
					local x, z = Layout.Home(index, 701)
					local cx, cz = Layout.Clamp(bounds, x, z)
					close(x, cx); close(z, cz)
					local key = string.format("%.4f,%.4f", x, z)
					assert(not occupied[key], "Home positions repeated before capacity"); occupied[key] = true
				end
				-- October 20: the robot vacuum's route checks left with the robot
				-- (archive/robot-vacuum-20261020).
			end
			plot:Destroy()
		end)
		model:Destroy(); Layout.SetYard(701, nil)
		assert(ok, err)
	end)
	return results
end
