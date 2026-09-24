--!strict
-- Isolated accounting/observation checks. No Players, profiles, clocks or DataStores are changed.
-- Optional module injection also permits running these engine-independent helpers in the Luau CLI.
local Checks = {}

local function session(userId)
	local value = {userId = userId, loaded = true, coins = 0, receipts = {}, pets = {}}
	function value:Credit(amount, source)
		assert(amount >= 1 and amount % 1 == 0 and amount < math.huge, "Credit must contain whole coins")
		assert(source == "territory", "Wrong income source")
		self.coins += amount
		table.insert(self.receipts, amount)
	end
	return value
end

function Checks.Run(modules)
	local server = if modules then nil else game:GetService("ServerStorage").PetRoll
	local Income = if modules then modules.TerritoryIncome else require(server.TerritoryIncome)
	local Telemetry = if modules then modules.LoopTelemetry else require(server.LoopTelemetry)
	local results = {}
	local function test(name, operation)
		local ok, detail = pcall(operation)
		table.insert(results, {name = name, passed = ok, detail = tostring(detail)})
	end

	test("Ten eligible seconds award 80 whole coins across different step splits", function()
		for _, steps in {{10}, {2, 3, 5}, table.create(100, 0.1), table.create(600, 1 / 60), {0.03, 1.17, 0.001, 2.499, 6.3}} do
			local income, owner = Income.new(8), session(1)
			local paid = 0
			for _, dt in steps do paid += income:Step(owner, dt) end
			assert(paid == 80 and owner.coins == 80, "Step splitting changed the payout: " .. paid)
		end
		return "80 coins with large, fixed and uneven intervals"
	end)

	test("A pause does not accrue and resumes only from supplied eligible time", function()
		local income, owner = Income.new(8), session(2)
		assert(income:Step(owner, 0.1) == 0)
		for _ = 1, 100 do assert(income:Step(owner, 0) == 0) end
		assert(owner.coins == 0)
		assert(income:Step(owner, 0.025) == 1 and owner.coins == 1)
		return "Pause contributes no time; pre-pause earned fraction remains the owner's"
	end)

	test("Loading, closing and save-lost sessions cannot receive coins", function()
		for _, flag in {"loaded", "closing", "saveLost"} do
			local income, owner = Income.new(8), session(3)
			owner[flag] = flag ~= "loaded"
			assert(income:Step(owner, 100) == 0 and owner.coins == 0)
			owner[flag] = flag == "loaded"
			assert(income:Step(owner, 0.125) == 1 and owner.coins == 1, "Ineligible time was banked")
		end
		return "Lifecycle gates do not store missed income"
	end)

	test("Invalid intervals and numeric overflow are rejected without poisoning carry", function()
		local income, owner = Income.new(8), session(4)
		assert(income:Step(owner, 0.1) == 0)
		for _, dt in {0, -1, math.huge, -math.huge, 0 / 0, 1e308, "1", false} do
			assert(income:Step(owner, dt) == 0)
		end
		assert(income:Step(owner, 0.025) == 1 and owner.coins == 1)
		return "Invalid input never credits or loses the valid remainder"
	end)

	test("Ownership switches keep fractional earnings with each session", function()
		local income, first, second = Income.new(8), session(5), session(6)
		assert(income:Step(first, 0.1) == 0)
		assert(income:Step(second, 0.025) == 0 and second.coins == 0)
		assert(income:Step(first, 0.025) == 1 and first.coins == 1)
		assert(income:Step(second, 0.1) == 1 and second.coins == 1)
		return "New owners never inherit the previous owner's fraction"
	end)

	test("Release, rejoin and test reset discard stale session fractions", function()
		for _, action in {"release", "rejoin", "reset"} do
			local income, owner = Income.new(8), session(7)
			income:Step(owner, 0.1)
			if action == "release" then income:Release(owner.userId)
			elseif action == "rejoin" then owner = session(7)
			else owner.pets = {} end
			assert(income:Step(owner, 0.025) == 0 and owner.coins == 0, action .. " leaked old carry")
		end
		return "All three lifecycle boundaries start fresh accounting"
	end)

	test("A stale closing session cannot clear a replacement session's earnings", function()
		local income, old, current = Income.new(8), session(14), session(14)
		income:Step(old, 0.1)
		income:Step(current, 0.1)
		old.closing = true
		assert(income:Step(old, 10) == 0)
		assert(income:Step(current, 0.025) == 1 and current.coins == 1 and old.coins == 0)
		return "Delayed old-session work cannot alter the current session's fraction"
	end)

	test("Destroyed or disabled income helpers never issue later credits", function()
		local income, owner = Income.new(8), session(8)
		income:Step(owner, 0.1); income:Destroy()
		assert(income:Step(owner, 10) == 0 and owner.coins == 0)
		assert(Income.new(0):Step(owner, 10) == 0)
		for _, rate in {-1, math.huge, 0 / 0} do assert(not pcall(Income.new, rate)) end
		return "No work after teardown; invalid configured rates fail early"
	end)

	test("A failing telemetry sink cannot fail or replay the confirmed observation", function()
		local calls = 0
		local telemetry = Telemetry.new(function()
			calls += 1
			error("Injected observation failure")
		end)
		assert(telemetry:Record("TerritoryCaptured", {userId = 9}, "capture-1"))
		assert(not telemetry:Record("TerritoryCaptured", {userId = 9}, "capture-1"))
		local rows = telemetry:Drain()
		assert(calls == 1 and #rows == 1 and rows[1].name == "TerritoryCaptured")
		assert(not telemetry:Record("TerritoryCaptured", {userId = 9}, "capture-1"), "Draining cleared deduplication")
		return "Sink failure stays local; no retries or duplicate receipt"
	end)

	test("Observations snapshot primitives and isolate caller/sink mutation", function()
		local telemetry = Telemetry.new(function(event) event.fields.coins = -999 end)
		local fields = {userId = 10, coins = 80, valid = true, nested = {bad = true}, invalid = math.huge}
		telemetry:Record("TerritoryIncome", fields)
		fields.coins = 500
		local row = telemetry:Drain()[1]
		assert(row.fields.coins == 80 and row.fields.valid and row.fields.nested == nil and row.fields.invalid == nil)
		return "A confirmed observation cannot be rewritten through an external table"
	end)

	test("Local observations and deduplication remain bounded", function()
		local telemetry = Telemetry.new()
		for index = 1, 1000 do telemetry:Record("ArmyGrowth", {userId = 11, index = index}, tostring(index)) end
		local rows = telemetry:Drain()
		assert(#rows <= 256 and rows[#rows].fields.index == 1000)
		assert(not telemetry:Record("ArmyGrowth", {userId = 11}, "1000"))
		assert(telemetry:Record("ArmyGrowth", {userId = 11}, "1"), "Old dedup keys should be evicted")
		return "Latest 256 observations and 512 dedup keys retained at most"
	end)

	test("Telemetry release removes only that user's observations and dedup keys", function()
		local telemetry = Telemetry.new()
		telemetry:Record("ArmyGrowth", {userId = 12}, "first")
		telemetry:Record("ArmyGrowth", {userId = 13}, "first")
		telemetry:Release(12)
		local rows = telemetry:Drain()
		assert(#rows == 1 and rows[1].fields.userId == 13)
		assert(telemetry:Record("ArmyGrowth", {userId = 12}, "first"))
		assert(not telemetry:Record("ArmyGrowth", {userId = 13}, "first"))
		telemetry:Destroy()
		assert(not telemetry:Record("ArmyGrowth", {userId = 12}, "later") and #telemetry:Drain() == 0)
		return "Session cleanup is isolated; destroyed telemetry accepts nothing"
	end)

	return results
end

return Checks
