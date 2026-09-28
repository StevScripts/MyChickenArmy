-- Isolated Edit checks using exact source strings. No real profiles or purchases.
return function(sources)
	local cache = {}
	local function folder(name)
		return setmetatable({Name = name}, {__index = function(self, key)
			local node = {Name = key, Parent = self, path = "src/" .. name .. "/" .. key .. ".luau"}
			rawset(self, key, node)
			return node
		end})
	end
	local shared, server = folder("shared"), folder("server")
	local services = {ReplicatedStorage = {PetRoll = {Shared = shared}},
		HttpService = game:GetService("HttpService"), Players = {}, MarketplaceService = {}, PolicyService = {},
		RunService = {IsStudio = function() return true end}}
	local original = getfenv()
	local loadModule
	loadModule = function(node)
		if cache[node.path] then return cache[node.path] end
		local fn, err = loadstring(assert(sources[node.path], node.path), node.path)
		assert(fn, err)
		setfenv(fn, setmetatable({script = node, require = loadModule, game = {GetService = function(_, name)
			return assert(services[name], name)
		end}}, {__index = original}))
		local result = fn(); cache[node.path] = result
		return result
	end
	local Config = loadModule(shared.EggProcessorConfig)
	local Currency = loadModule(shared.CurrencyLimits)
	local Processor = loadModule(server.EggProcessor)
	local Eggs = loadModule(server.EggService)
	local Session = loadModule(server.PlayerSession)
	local Offline = loadModule(server.OfflineCash)
	local Products = loadModule(server.ProductService)
	local Commerce = loadModule(server.CommerceService)
	local Army = loadModule(server.ArmyService)
	local Rules = loadModule(shared.Rules)
	local Shop = loadModule(shared.ShopCatalog)
	local Catalog = loadModule(shared.PetCatalog)
	local GameConfig = loadModule(shared.Config)
	local results = {}
	local function check(name, fn)
		local ok, err = pcall(fn)
		table.insert(results, {name = name, passed = ok, error = if ok then nil else tostring(err)})
	end
	local function fresh(level)
		local s = Session.new(700, "Continuation fixture", 1)
		s.loaded = true; s.eggProcessor.level = level
		return s
	end
	local function engine()
		local e = Eggs.new({plots = {{}}})
		e.CanUseBoard = function() return true end
		return e
	end
	check("Small opening purchases; whole-egg gains grow gradually without doubling", function()
		for i, rate in {4, 5, 6, 7, 8, 9, 11, 13, 15, 17, 19} do
			assert(Config.Rate(i - 1) == rate)
		end
		local previousGain = 0
		for level = 1, 1000 do
			local gain = Config.Rate(level) - Config.Rate(level - 1)
			assert(gain >= previousGain and gain >= 1 and gain % 1 == 0)
			assert(Config.Rate(level) < 2 * Config.Rate(level - 1))
			previousGain = gain
			local price = Config.Price(level)
			assert(price == nil or (price <= Currency.MaxCoins and price > 0 and price % 1 == 0))
		end
	end)
	check("Prices compound smoothly, cross a trillion, then refuse numeric overflow", function()
		for i, price in {40, 48, 58, 70, 83, 100, 120} do assert(Config.Price(i - 1) == price) end
		local previous = Config.Price(0)
		for level = 1, 181 do
			local price = assert(Config.Price(level))
			assert(price > previous and price % 1 == 0 and price <= Currency.MaxCoins)
			assert(math.abs(price / previous - 1.20) < 0.021)
			previous = price
		end
		assert(Config.Price(132) > 1e12 and Config.Price(133) > Config.Price(132))
		assert(Config.Price(182) == nil)
		assert(Config.Price(2^53 - 1) == nil)
		local s, e = fresh(2^53 - 2), engine(); s.coins = Currency.MaxCoins
		assert(not e:Upgrade({}, s, s.eggProcessor.level, math.huge))
		assert(s.coins == Currency.MaxCoins and e:Snapshot(s, 0).processor.upgradePrice == nil)
	end)
	check("Large wallets save/reload and purchase beyond the old trillion ceiling", function()
		local s, e = fresh(132), engine()
		s.coins = Config.Price(132) + 123; s.passiveEarned = 3e12; s.battleEarned = 2e12
		local restored = fresh(0); assert(restored:LoadData(s:ToData()))
		assert(restored.coins == s.coins and restored.passiveEarned == 3e12 and restored.battleEarned == 2e12)
		assert(e:Upgrade({}, restored, 132, Config.Price(132)))
		assert(restored.coins == 123 and restored.eggProcessor.level == 133)
		for _, coins in {math.huge, 0/0, Currency.MaxCoins + 1, -1} do
			local data = s:ToData(); data.coins = coins; assert(not restored:LoadData(data))
		end
	end)
	check("Cash pad pays above one trillion and preserves ready money at numeric limit", function()
		local s, e = fresh(83), engine(); s.coins = 1e12; s.passiveEarned = 1e12
		s.eggProcessor.readyValue = 100; s.entitlements.DoubleCash = true
		local pad = {Position = Vector3.zero}
		assert(e:ClaimReady(s, pad, 10) and s.coins == 1e12 + 200 and s.passiveEarned == 1e12 + 200)
		s.coins = Currency.MaxCoins - 199; s.eggProcessor.readyValue = 100
		assert(not e:ClaimReady(s, pad, 12) and s.eggProcessor.readyValue == 100)
		s.coins -= 1; assert(e:ClaimReady(s, pad, 12) and s.coins == Currency.MaxCoins)
		assert(s:Credit(1, "battle") == 0 and s.coins == Currency.MaxCoins)
		s.coins = 0; s.passiveEarned = Currency.MaxCoins - 1
		assert(s:Credit(5, "eggs") == 10 and s.passiveEarned == Currency.MaxCoins)
		assert(fresh(0):LoadData(s:ToData()))
	end)
	check("Offline credits use expanded wallet headroom without changing time/efficiency", function()
		local reward = Offline.Reward({at = 100, rate = 10}, 200, 1e12)
		assert(reward.amount == 1000 and reward.countedSeconds == 100)
		assert(Offline.Reward({at = 100, rate = 10}, 200, Currency.MaxCoins - 30).amount == 30)
	end)
	check("Paid cash stays exact above one trillion, replays once, and defers overflow", function()
		local s = fresh(4); s.coins = 1e12; s.entitlements.DoubleCash = true
		local player = {UserId = s.userId, Parent = true}
		local players = {GetPlayerByUserId = function() return player end}
		local saved = {}
		local data = {CanPurchase = function() return true end,
			IsPurchaseSaved = function(_, _, id) return saved[id] == true end,
			CommitPurchase = function(_, _, id, _, grant)
				local ok = grant(); if ok then saved[id] = true end; return ok
			end}
		local p = Products.new(data, {[s.userId] = s}, {players = players})
		local receipt = {PlayerId = s.userId, ProductId = Shop.Products.PocketCoins.productId, PurchaseId = "fixture-1"}
		assert(p:ProcessReceipt(receipt) == Enum.ProductPurchaseDecision.PurchaseGranted)
		assert(s.coins == 1e12 + Shop.Products.PocketCoins.coins)
		assert(p:ProcessReceipt(receipt) == Enum.ProductPurchaseDecision.PurchaseGranted)
		assert(s.coins == 1e12 + Shop.Products.PocketCoins.coins)
		s.coins = Currency.MaxCoins; receipt.PurchaseId = "fixture-2"
		assert(p:ProcessReceipt(receipt) == Enum.ProductPurchaseDecision.NotProcessedYet and not saved["fixture-2"])
		s.coins -= Shop.Products.PocketCoins.coins
		assert(p:ProcessReceipt(receipt) == Enum.ProductPurchaseDecision.PurchaseGranted and s.coins == Currency.MaxCoins)
		local c = setmetatable({catalog = Shop, records = {}}, Commerce)
		c.TestAllowed = function() return false end; c._Active = function() return true end
		c.records[player.UserId] = {session = s}
		s.coins = 2e12; assert(c:PreparePurchase(player, s, "PocketCoins", true))
		s.coins = Currency.MaxCoins; assert(not c:PreparePurchase(player, s, "PocketCoins", true))
	end)
	check("Full-wallet chicken sale preserves owned chickens and money", function()
		local s = fresh(4); local pet = s:AddPet("Duck", 1)
		s.coins = Currency.MaxCoins
		local total = Rules.SellValue(pet.investment)
		assert(not Army.Sell(s, {pet.id}, false, total))
		assert(s.pets[pet.id] == pet and s.coins == Currency.MaxCoins)
	end)
	check("Current catalog retains equal egg values and prior cash potential", function()
		for _, id in Catalog.Order do for level = 1, 10 do for upgrade = 0, 4 do
			local previous = math.floor(Catalog[id].income * GameConfig.PassiveIncomeMultiplier * (1 + upgrade * 0.25) + 0.5) * 2^(level - 1)
			assert(math.abs(Rules.Income(id, 1, level, upgrade) - previous) < 1e-6)
			assert(math.abs(Rules.Income(id, 1, level, upgrade) / Rules.EggRate(id, 1, level) - (4 + upgrade)) < 1e-6)
		end end end
	end)
	check("Past former cap, repeated paid upgrades remain available with next offer", function()
		local s, e = fresh(4), engine()
		for _ = 1, 30 do
			local level = s.eggProcessor.level
			local offer = e:Snapshot(s, 0).processor
			assert(offer.upgradePrice == Config.Price(level) and offer.nextRate > offer.rate)
			s.coins = offer.upgradePrice
			assert(e:Upgrade({}, s, level, offer.upgradePrice))
			assert(s.coins == 0 and s.eggProcessor.level == level + 1)
		end
	end)
	check("Stale quotes, insufficient cash and board access still reject without mutation", function()
		local s, e = fresh(8), engine(); local price = Config.Price(8)
		s.coins = price
		assert(not e:Upgrade({}, s, 7, price))
		assert(not e:Upgrade({}, s, 8, price - 1))
		s.coins = price - 1; assert(not e:Upgrade({}, s, 8, price))
		s.coins = price; e.CanUseBoard = function() return false end
		assert(not e:Upgrade({}, s, 8, price))
		assert(s.coins == price and s.eggProcessor.level == 8)
	end)
	check("Saved high levels roundtrip; corrupt/nonfinite levels reject", function()
		for _, level in {0, 4, 5, 100, 1000000, 2^53 - 1} do
			local p = Processor.New(); p.level = level
			local copy = assert(Processor.Read(Processor.Copy(p)))
			assert(copy.level == level and Processor.Rate(copy, true) == Config.Rate(level) * 2)
			assert(Processor.Rate(copy, true) < math.huge)
		end
		for _, level in {-1, 4.5, math.huge, 0/0, 2^53, "5"} do
			local p = Processor.New(); p.level = level; assert(Processor.Read(p) == nil)
		end
		local s = fresh(8); s.coins = 123
		local restored = fresh(0)
		assert(restored:LoadData(s:ToData()))
		assert(restored.eggProcessor.level == 8 and restored.coins == 123)
	end)
	check("High-speed processing conserves value, queue bounds and Finish credits", function()
		local p = Processor.New(); p.level = 5
		assert(Processor.Deposit(p, 10000, 40000))
		Processor.Step(p, 1, Processor.Rate(p, false))
		assert(Processor.Totals(p) == 9991 and p.readyValue == 36)
		p.level = 1000000; Processor.Step(p, 1, Processor.Rate(p, true))
		assert(Processor.Totals(p) == 0 and p.readyValue == 40000 and p.progress == 0)
		assert(Processor.GrantFinish(p) and p.finishCredits == 1)
		assert(Processor.Deposit(p, 10, 40) and p.readyValue == 40040 and p.finishCredits == 0)
		assert(not Processor.Deposit(p, Config.MaxValue + 1, 1))
	end)
	check("Offline follows gradual capacity, paid multiplier and production ceiling", function()
		local s = fresh(4); s.pets = {}; s.slots = {}
		for _ = 1, 10 do local p = s:AddPet("StormDuck", 1); p.level = 3 end
		local old = Offline.Rate(s)
		assert(old == 8 * 4 * 0.02)
		s.eggProcessor.level = 5; assert(Offline.Rate(s) == 9 * 4 * 0.02)
		s.entitlements.DoubleEggSpawn = true; assert(Offline.Rate(s) == 18 * 4 * 0.02)
		s.entitlements.DoubleEggSpawn = false
		s.eggProcessor.level = 100; local productionLimited = Offline.Rate(s)
		assert(productionLimited > old and productionLimited < Config.Rate(100) * 4 * 0.02)
		s.eggProcessor.level = 1000; assert(Offline.Rate(s) == productionLimited)
	end)
	return results
end
