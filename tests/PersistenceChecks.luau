--!strict
-- Deterministic persistence checks. Never creates or accesses a real DataStore.
-- The fake copies both callback input and committed output like a remote boundary.
local Server = game:GetService("ServerStorage").PetRoll
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local DataService = require(Server.DataService)
local Session = require(Server.PlayerSession)
local Config = require(Shared.Config)
local Checks = {}

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in value do result[copy(key)] = copy(item) end
	return result
end

local function same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) == "number" and a ~= a and b ~= b then return true end
	if type(a) ~= "table" then return a == b end
	for key, value in a do if not same(value, b[key]) then return false end end
	for key in b do if a[key] == nil then return false end end
	return true
end

local function equal(a, b, why)
	assert(same(a, b), why or "Values differ")
end

local function backend()
	local store = {records = {}, calls = 0, committed = 0, failRead = 0, failCommit = 0, failAfterCommit = 0}
	function store:UpdateAsync(key, transform)
		self.calls += 1
		if self.failRead > 0 then self.failRead -= 1; error("Injected network read failure") end
		local readHook = self.onRead
		self.onRead = nil
		if readHook then readHook(key) end
		local candidate = transform(copy(self.records[key]))
		if candidate == nil then return nil end
		if self.failCommit > 0 then self.failCommit -= 1; error("Injected write failure before commit") end
		self.records[key] = copy(candidate)
		self.committed += 1
		if self.failAfterCommit > 0 then self.failAfterCommit -= 1; error("Injected lost commit acknowledgement") end
		return copy(self.records[key])
	end
	return store
end

local function fixture(id)
	local store, clock = backend(), {now = 1000}
	local service = DataService.new(store, function() return clock.now end)
	local session = Session.new(id or 90101, "PersistenceTest", 1)
	return store, clock, service, session, "player_" .. session.userId
end

local function second(store, clock, userId)
	return DataService.new(store, function() return clock.now end), Session.new(userId, "RejoinedTest", 2)
end

local function seed(store, key, data, extra)
	store.records[key] = {schemaVersion = 1, data = copy(data), updatedAt = 900}
	if extra then for field, value in extra do store.records[key][field] = copy(value) end end
end

function Checks.Run()
	local results = {}
	local totalCalls, totalCommits = 0, 0
	local function test(name, operation)
		local ok, why = pcall(operation)
		table.insert(results, {name = name, passed = ok, error = if ok then nil else tostring(why)})
	end
	local function count(store)
		totalCalls += store.calls
		totalCommits += store.committed
	end

	test("New profile obtains a lease without sharing tables with storage", function()
		local store, clock, service, session, key = fixture()
		assert(service:Load(session))
		assert(session.loaded and session.saveStatus == "saved")
		assert(store.records[key].lease.owner == service.token)
		assert(store.records[key].lease.expires == clock.now + Config.SaveLeaseSeconds)
		local saved = copy(store.records[key])
		local pet = session:HomePets()[1]
		pet.cash = 74; session.coins += 400
		equal(store.records[key], saved, "Live session changes leaked through the fake storage boundary")
		count(store)
	end)

	test("Pets, cash, favorites, coins, upgrades and camp progress round-trip", function()
		local store, clock, service, session, key = fixture()
		assert(service:Load(session))
		session.coins = 8123.5; session.capacity = 6; session.luck = 2; session.incomeLevel = 2
		local dragon = session:AddPet("Dragon", 1)
		dragon.favorite = true; dragon.cash = 72.25; dragon.collected = 181.5
		session.firstWins[1]=true;session.firstWins[2]=true
		session.tutorial.bought = true; session.tutorial.collected = true
		session.passiveEarned = 350.25; session.battleEarned = 880
		session:RefreshArmy()
		local expected = copy(session:ToData())
		assert(service:Save(session, true))
		assert(store.records[key].lease == nil and service.entries[session.userId] == nil)
		local other, restored = second(store, clock, session.userId)
		assert(other:Load(restored))
		equal(restored:ToData(), expected, "Rejoin changed saved player values")
		assert(restored.campUnlocked == 3 and restored.armyState == "Home")
		assert(restored:FindSlot(dragon.id) ~= nil, "Best army should be restored automatically")
		count(store)
	end)

	test("Another server cannot load an unexpired lease", function()
		local store, clock, service, session, key = fixture()
		assert(service:Load(session))
		local before = copy(store.records[key])
		local other, duplicate = second(store, clock, session.userId)
		assert(not other:Load(duplicate), "Duplicate server acquired an active save")
		assert(not duplicate.loaded and other.entries[session.userId] == nil)
		equal(store.records[key], before, "Denied load changed someone else's stored record")
		count(store)
	end)

	test("The same service rejects a second live session for the same player", function()
		local store, _, service, session, key = fixture()
		assert(service:Load(session))
		local before = copy(store.records[key])
		local duplicate = Session.new(session.userId, "Duplicate", 2)
		assert(not service:Load(duplicate), "Same-service duplicate replaced the active entry")
		assert(service.entries[session.userId].session == session, "Original live entry was displaced")
		equal(store.records[key], before, "Duplicate session modified the active profile")
		count(store)
	end)

	test("A second load is denied while the first load is still in flight", function()
		local store, _, service, session, key = fixture()
		local duplicate = Session.new(session.userId, "OverlappingLoad", 2)
		local secondAccepted
		store.onRead = function()
			secondAccepted = service:Load(duplicate)
		end
		assert(service:Load(session))
		assert(secondAccepted == false, "Overlapping load acquired the same in-flight owner token")
		assert(not duplicate.loaded and service.entries[session.userId].session == session)
		assert(store.records[key].lease.owner == service.token)
		count(store)
	end)

	test("An expired lease can be taken over with its previous saved progress", function()
		local store, clock, service, session, key = fixture()
		assert(service:Load(session))
		session.coins = 1777; assert(service:Save(session, false))
		clock.now += Config.SaveLeaseSeconds + 1
		local other, restored = second(store, clock, session.userId)
		assert(other:Load(restored), "Expired lease permanently blocked the profile")
		assert(restored.coins == 1777 and store.records[key].lease.owner == other.token)
		count(store)
	end)

	test("An old lease holder cannot write or release over the new owner", function()
		local store, clock, service, session, key = fixture()
		assert(service:Load(session))
		clock.now += Config.SaveLeaseSeconds + 1
		local other, restored = second(store, clock, session.userId)
		assert(other:Load(restored))
		restored.coins = 2424; assert(other:Save(restored, false))
		local before = copy(store.records[key])
		session.coins = 999999
		assert(not service:Save(session, false))
		assert(session.saveLost, "Old holder should stop accepting player mutations")
		equal(store.records[key], before, "Stale owner overwrote new progress")
		service:Release(session)
		equal(store.records[key], before, "Stale release removed the new lease")
		count(store)
	end)

	test("Exhausted load retries preserve existing data and create no writable session", function()
		local store, _, service, session, key = fixture()
		local data = session:ToData(); data.coins = 3939
		seed(store, key, data)
		local before = copy(store.records[key])
		store.failRead = Config.SaveAttempts
		assert(not service:Load(session))
		assert(store.calls == Config.SaveAttempts, "Load did not use its bounded retry policy")
		assert(not session.loaded and service.entries[session.userId] == nil)
		assert(session.saveStatus == "error")
		equal(store.records[key], before, "Failed read replaced stored progress with defaults")
		assert(service:Load(session), "Load failure left a permanent in-flight lock")
		assert(session.coins == 3939, "Recovery did not restore the preserved profile")
		count(store)
	end)

	test("A write failure preserves storage and a later retry saves current progress", function()
		local store, _, service, session, key = fixture()
		assert(service:Load(session))
		local before = copy(store.records[key])
		session.coins = 4545
		store.failCommit = Config.SaveAttempts
		assert(not service:Save(session, false))
		equal(store.records[key], before, "Aborted callback mutated the stored record by alias")
		assert(not session.saveLost, "A temporary network failure should not imply another owner")
		assert(service:Save(session, false))
		assert(store.records[key].data.coins == 4545)
		count(store)
	end)

	test("Retry after an uncertain commit retains the same owner and payload", function()
		local store, _, service, session, key = fixture()
		assert(service:Load(session))
		session.coins = 5656
		store.failAfterCommit = 1
		assert(service:Save(session, false), "Acknowledgement loss should be recoverable through UpdateAsync retry")
		assert(store.records[key].data.coins == 5656 and store.records[key].lease.owner == service.token)
		count(store)
	end)

	test("Unsupported schema is rejected without changing any stored fields", function()
		local store, _, service, session, key = fixture()
		seed(store, key, session:ToData(), {schemaVersion = 77, recoveryNote = "keep me"})
		local before = copy(store.records[key])
		assert(not service:Load(session))
		equal(store.records[key], before, "Unsupported schema was overwritten")
		assert(service.entries[session.userId] == nil)
		count(store)
	end)

	for _, malformed in {"not a record", false, 17} do
		test("Malformed envelope " .. tostring(malformed) .. " remains untouched", function()
			local store, _, service, session, key = fixture()
			store.records[key] = malformed
			assert(not service:Load(session))
			equal(store.records[key], malformed, "Malformed envelope became a fresh save")
			count(store)
		end)
	end

	local badData = {
		{"negative coins", function(data) data.coins = -5 end},
		{"unknown animal", function(data) data.pets[1].species = "UnreleasedAnimal" end},
		{"duplicate duck IDs", function(data) data.pets[2].id = data.pets[1].id end},
		{"invalid cash", function(data) data.pets[1].cash = -25 end},
		-- October 20: revision 12 derives levels from upgradeTree; only revision 11 saves validate them.
		{"invalid legacy upgrade level", function(data) data.dataRevision = 11; data.incomeLevel = #Config.IncomePrices + 1 end},
	}
	for _, case in badData do
		test("Invalid profile with " .. case[1] .. " is preserved and its temporary lease released", function()
			local store, _, service, session, key = fixture()
			local data = session:ToData(); case[2](data)
			seed(store, key, data)
			local starting = copy(session:ToData())
			assert(not service:Load(session))
			equal(store.records[key].data, data, "Invalid player data was silently repaired or replaced")
			assert(store.records[key].lease == nil, "Recovery failure left an unnecessary active lease")
			equal(session:ToData(), starting, "Failed validation partially mutated the live session")
			assert(not session.loaded and service.entries[session.userId] == nil)
			count(store)
		end)
	end

	test("Malformed lease is preserved without acquiring ownership", function()
		local store, _, service, session, key = fixture()
		seed(store, key, session:ToData(), {lease = {owner = 12, expires = "tomorrow"}})
		local before = copy(store.records[key])
		assert(not service:Load(session))
		equal(store.records[key], before, "Malformed lease was overwritten")
		count(store)
	end)

	test("Release saves the final snapshot and permits immediate rejoin", function()
		local store, clock, service, session, key = fixture()
		assert(service:Load(session))
		session.coins = 6767; session:AddPet("Wizard", 1)
		local expected = copy(session:ToData())
		session.closing = true
		service:Release(session)
		assert(service.entries[session.userId] == nil and store.records[key].lease == nil)
		local other, restored = second(store, clock, session.userId)
		assert(other:Load(restored))
		equal(restored:ToData(), expected, "Final release missed the latest session state")
		count(store)
	end)

	test("A failed release cannot later save an emptied destroyed session", function()
		local store, _, service, session, key = fixture()
		assert(service:Load(session))
		session:AddPet("Knight", 1); session.coins = 7878
		local expected = copy(session:ToData())
		session.closing = true
		store.failCommit = Config.SaveAttempts
		service:Release(session)
		assert(service.entries[session.userId] ~= nil, "Uncommitted release should retain an immutable retry snapshot")
		session:Destroy()
		assert(session:Count() == 0, "Regression setup must model actual PlayerRemoving cleanup")
		assert(service:Save(session, true), "Retained final snapshot should be retryable")
		equal(store.records[key].data, expected, "Retry wrote the destroyed session's empty collection")
		assert(store.records[key].lease == nil)
		count(store)
	end)

	test("Scheduled release retry uses the final snapshot after session cleanup", function()
		local store, clock, service, session, key = fixture()
		assert(service:Load(session))
		session:AddPet("Wizard", 1); session.coins = 8989
		local expected = copy(session:ToData())
		session.closing = true; store.failCommit = Config.SaveAttempts
		service:Release(session)
		session:Destroy()
		clock.now += Config.SaveInterval + 1
		service:Step()
		task.wait()
		assert(service.entries[session.userId] == nil, "Scheduled retry did not finish a closing session")
		equal(store.records[key].data, expected, "Scheduled retry lost the immutable final snapshot")
		assert(store.records[key].lease == nil)
		count(store)
	end)

	local passed = 0
	for _, result in results do if result.passed then passed += 1 end end
	return {passed = passed == #results, count = #results, passedCount = passed, results = results,
		metrics = {fakeUpdateCalls = totalCalls, fakeCommits = totalCommits, realDataStoreCalls = 0}}
end

return Checks
