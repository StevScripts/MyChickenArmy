-- Pure analytics checks: fake DataStores and a fake Roblox sender. No players,
-- no live DataStores, no Roblox analytics calls.
local Server = game.ServerStorage.PetRoll
local Schema = require(Server.AnalyticsSchema)
local Ledger = require(Server.AnalyticsLedger)
local Analytics = require(Server.Analytics)
local Report = require(Server.AnalyticsReport)
local Checks = {}

local function fakeStore(failFirst: number?)
	local data, fails = {}, failFirst or 0
	local store = {data = data, writes = 0}
	function store:GetAsync(key) return data[key] end
	function store:SetAsync(key, value) data[key] = value end
	function store:UpdateAsync(key, fn)
		if fails > 0 then fails -= 1; error("throttled") end
		local value = fn(data[key])
		if value ~= nil then data[key] = value end
		store.writes += 1
		return value
	end
	return store
end

local function fakeSession(userId)
	local session = {userId = userId, tutorial = {starterArmy = true, collectedEggCount = 0}, firstWins = {},
		kingCleared = false, coins = 2400, pets = {}, offers = {}}
	function session:Count() local n = 0 for _ in self.pets do n += 1 end return n end
	function session:CanSpendCash(amount) return amount <= self.coins end
	return session
end

function Checks.Run()
	local results = {}
	local function check(name, fn)
		local ok, err = pcall(fn)
		table.insert(results, {name = name, passed = ok, error = if ok then nil else tostring(err)})
	end

	check("Schema stays inside Roblox analytics limits", function()
		local seen = {}
		for _, name in Schema.CustomEvents do assert(not seen[name], "duplicate custom event " .. name); seen[name] = true end
		assert(#Schema.CustomEvents <= Schema.RobloxLimits.customEvents)
		local funnels = 1 -- onboarding
		for _, steps in Schema.Funnels do funnels += 1; assert(#steps <= Schema.RobloxLimits.stepsPerFunnel) end
		assert(funnels <= Schema.RobloxLimits.funnels)
		assert(#Schema.Onboarding <= Schema.RobloxLimits.stepsPerFunnel)
		local transactions, skus = {}, {}
		for _, d in Schema.Sources do transactions[d.transaction] = true; skus[d.sku] = true end
		for _, d in Schema.Sinks do transactions[d.transaction] = true; skus[d.sku] = true end
		local tCount, sCount = 0, 0
		for _ in transactions do tCount += 1 end
		for _ in skus do sCount += 1 end
		-- Recruit and Upgrade expand by rarity / upgrade key (<= 6 + 10).
		assert(tCount <= Schema.RobloxLimits.transactionTypes and sCount + 16 <= Schema.RobloxLimits.itemSkus)
		for index, step in Schema.Onboarding do assert(Schema.OnboardingIndex[step.id] == index) end
	end)

	check("Histogram labels are stable and cover every value", function()
		assert(Schema.Bucket("seconds", 0) == "le5" and Schema.Bucket("seconds", 30) == "le30")
		assert(Schema.Bucket("seconds", 30.01) == "le45" and Schema.Bucket("seconds", 1e9) == "gt14400")
		assert(Schema.Bucket("cash", 0) == "le0")
	end)

	check("MergeBucket sums without mutating its source and caps top tables", function()
		local a, b = Ledger.NewBucket(), Ledger.NewBucket()
		a.c.x, b.c.x, b.c.y = 2, 3, 1
		b.h.s = {le5 = 2}; b.m.peak = 7; b.x["2026-10-01"] = {["cohort.size"] = 4}
		b.t.err = {k = 2}
		Ledger.MergeBucket(a, b)
		Ledger.MergeBucket(a, b)
		assert(a.c.x == 8 and a.c.y == 2 and a.h.s.le5 == 4 and a.m.peak == 7 and a.x["2026-10-01"]["cohort.size"] == 8)
		assert(b.c.x == 3 and b.h.s.le5 == 2, "source mutated")
		local big = Ledger.NewBucket()
		for i = 1, Schema.TopCap + 5 do Ledger.MergeBucket(big, {t = {err = {["e" .. i] = 1}}}) end
		assert(big.t.err["(other)"] == 5)
	end)

	check("Ledger flushes one sharded day key, merges later flushes and requeues failures", function()
		local store = fakeStore(1)
		local clock = 1791547200 -- 2026-10-09 12:00 UTC
		local ledger = Ledger.new({store = store, playerStore = fakeStore(), clock = function() return clock end,
			shard = 3, version = "test-v", studio = true})
		ledger:Count("a", 2); ledger:Hist("h", "seconds", 12); ledger:Cohort("2026-10-08", "ret.d1")
		assert(ledger:Flush() == false, "first flush should fail")
		ledger:Count("a")
		assert(ledger:Flush() == true)
		local record = store.data[Schema.DayKey("2026-10-09", 3)]
		assert(record and record.v["test-v"].c.a == 3 and record.v["test-v"].h.h.le20 == 1)
		assert(record.v["test-v"].c["analytics.ledgerFlushFail"] == 1)
		ledger:Count("a", 4); ledger:Flush()
		assert(store.data[Schema.DayKey("2026-10-09", 3)].v["test-v"].c.a == 7)
	end)

	check("Rate limiter sends high priority first and never exceeds its token budget", function()
		local analytics = Analytics.new({ledger = Ledger.new({store = fakeStore(), playerStore = fakeStore(), studio = true, shard = 0}),
			studio = false})
		local order = {}
		for i = 1, 6 do analytics:_Queue(false, "low", function() table.insert(order, "low" .. i) end) end
		analytics:_Queue(true, "high", function() table.insert(order, "high") end)
		analytics:_Pump(60) -- 0 players: budget 10/min, burst capped at 2.5
		task.wait()
		assert(#order == 2 and order[1] == "high" and order[2] == "low1", table.concat(order, ","))
	end)

	check("A fresh player's onboarding is recorded once, in order, with cohort and journey", function()
		local labels, clock = {}, 100
		local store, players = fakeStore(), fakeStore()
		local ledger = Ledger.new({store = store, playerStore = players, studio = true, shard = 1, version = "v1",
			clock = function() return 1791547200 end})
		local analytics = Analytics.new({ledger = ledger, studio = true, clock = function() return clock end,
			wall = function() return 1791547200 end, sender = function(label) table.insert(labels, label) end,
			random = function() return 1 end})
		local session = fakeSession(42)
		local player = {UserId = 42, GetNetworkPing = function() return 0.08 end}
		analytics:Join(player, session)
		clock += 2
		analytics:Loaded(session)
		task.wait()
		local st = analytics.players[42]
		assert(st.ready and st.tracked and st.isNew, "fresh profile should be tracked")
		analytics:Signal(session, "IntroStarted"); analytics:Signal(session, "IntroSkipped"); analytics:Signal(session, "Ready")
		session.tutorial.collectedEggCount = 40; session.tutorial.soldEggs = true
		local state = {tutorial = session.tutorial, pets = {1, 2, 3}, capacity = 3, selectedCount = 3, firstWins = {}}
		clock += 1; analytics:Observe(session, state)
		clock += 1; analytics:Observe(session, state) -- repeats must not re-record
		analytics:Income(session, "eggs", 160, 2560)
		session.offers = {{species = "Duck", price = 600}}
		analytics:Action(session, "Roll", true, "ok", 2560, {}, {})
		analytics:Action(session, "Buy", false, "Not enough cash", 2560, {}, {})
		clock += 30
		analytics:Leave(session)
		task.wait()
		local onboarding = {}
		for _, label in labels do if string.sub(label, 1, 11) == "onboarding:" then table.insert(onboarding, string.sub(label, 12)) end end
		local expected = {"01 Joined", "02 ProfileLoaded", "03 IntroStarted", "04 IntroEnded", "05 ControlReady", "06 FirstEgg", "07 Collect", "08 Sell"}
		assert(table.concat(onboarding, ",") == table.concat(expected, ","), table.concat(onboarding, ","))
		local bucket = ledger.pending["2026-10-09"]["v1"]
		assert(bucket.c["onb.reach.08"] == 1 and bucket.x["2026-10-09"]["onb.08"] == 1 and bucket.x["2026-10-09"]["cohort.size"] == 1)
		assert(bucket.c["intro.skipped"] == 1 and bucket.c["roll.count"] == 1 and bucket.c["roll.anyAffordable"] == 1)
		assert(bucket.c["econ.src.eggs"] == 160 and bucket.t.reject["Buy | Not enough cash"] == 1)
		assert(bucket.c["onb.exit.None"] == 1 or bucket.c["session.count"] == 1)
		assert(#ledger.journeys["2026-10-09"] == 1, "onboarding sessions always keep a journey")
		local saved = players.data[Schema.PlayerKey(42)]
		assert(saved and saved.tracked and saved.onb["08"] and saved.sessions == 1, "profile saved")
		-- Second session: same steps are not counted again; day-1 return lands on the cohort.
		local ledger2 = Ledger.new({store = store, playerStore = players, studio = true, shard = 1, version = "v1",
			clock = function() return 1791547200 + 86400 end})
		local analytics2 = Analytics.new({ledger = ledger2, studio = true, clock = function() return clock end,
			wall = function() return 1791547200 + 86400 end, sender = function(label) table.insert(labels, label) end})
		local session2 = fakeSession(42)
		session2.tutorial = {starterArmy = true, guideStarted = true, collectedEggCount = 40, soldEggs = true}
		analytics2:Join(player, session2); analytics2:Loaded(session2); task.wait()
		analytics2:Observe(session2, {tutorial = session2.tutorial, pets = {1, 2, 3}, capacity = 3, firstWins = {}})
		local b2 = ledger2.pending["2026-10-10"]["v1"]
		assert(b2.x["2026-10-09"]["ret.d1"] == 1, "D1 return")
		assert(b2.c["onb.reach.08"] == nil, "step re-counted in a later session")
	end)

	check("Roblox onboarding steps go out strictly in order; early steps wait, optional ones are passed over", function()
		local labels = {}
		local ledger = Ledger.new({store = fakeStore(), playerStore = fakeStore(), studio = true, shard = 0, version = "v1",
			clock = function() return 1791547200 end})
		local analytics = Analytics.new({ledger = ledger, studio = true, sender = function(label) table.insert(labels, label) end})
		local session = fakeSession(9)
		analytics:Join({UserId = 9}, session); analytics:Loaded(session); task.wait()
		local st = analytics.players[9]
		local I = Schema.OnboardingIndex
		analytics:_Reach(st, I.Expand) -- a BiggerArmy pass owner starts with capacity 4+
		local function sent()
			local list = {}
			for _, label in labels do if string.sub(label, 1, 11) == "onboarding:" then table.insert(list, string.sub(label, 12, 13)) end end
			return table.concat(list, ",")
		end
		assert(sent() == "01,02", sent())
		analytics:Signal(session, "IntroSkipped") -- no film: IntroStarted never happens
		analytics:Signal(session, "Ready")
		assert(sent() == "01,02,04,05", sent())
		for _, id in {"FirstEgg", "Collect", "Sell", "Roll", "Recruit", "Grow"} do analytics:_Reach(st, I[id]) end
		assert(sent() == "01,02,04,05,06,07,08,09,10,11,12", sent())
		local bucket = ledger.pending["2026-10-09"]["v1"]
		assert(bucket.c["onb.robloxGapFill.03"] == 1 and bucket.c["onb.outOfOrder.12"] == 1)
		assert(st.profile.rbx == 12)
	end)

	check("Preexisting saves are never tracked into the onboarding funnel or cohorts", function()
		local labels = {}
		local ledger = Ledger.new({store = fakeStore(), playerStore = fakeStore(), studio = true, shard = 0, version = "v1",
			clock = function() return 1791547200 end})
		local analytics = Analytics.new({ledger = ledger, studio = true, sender = function(label) table.insert(labels, label) end})
		local session = fakeSession(7)
		session.tutorial.guideStarted, session.firstWins = true, {true}
		analytics:Join({UserId = 7}, session); analytics:Loaded(session); task.wait()
		for _, label in labels do assert(string.sub(label, 1, 11) ~= "onboarding:", label) end
		local bucket = ledger.pending["2026-10-09"]["v1"]
		assert(bucket.c["players.preexisting"] == 1 and next(bucket.x) == nil)
	end)

	check("Profile merge keeps the earliest reach times and the furthest progress", function()
		local old = {first = 10, firstDay = "2026-10-01", tracked = true, sessions = 5, play = 900, onb = {["01"] = 0, ["05"] = 40}, features = {}, ret = {d1 = true}}
		local ours = {first = 20, firstDay = "2026-10-02", tracked = false, sessions = 3, play = 1200, onb = {["05"] = 30, ["06"] = 50}, features = {Fusion = 600}, ret = {}}
		local m = Analytics.MergeProfile(old, ours)
		assert(m.first == 10 and m.firstDay == "2026-10-01" and m.tracked == true and m.sessions == 5 and m.play == 1200)
		assert(m.onb["01"] == 0 and m.onb["05"] == 30 and m.onb["06"] == 50 and m.ret.d1 and m.features.Fusion == 600)
	end)

	check("Report summarizes funnels, cohorts and raises flags from merged shards", function()
		local bucket = Ledger.NewBucket()
		bucket.c["onb.reach.01"], bucket.c["onb.reach.02"], bucket.c["onb.reach.05"] = 100, 98, 50
		bucket.c["session.count"], bucket.c["session.seconds"] = 100, 30000
		bucket.c["onb.exit.Collect"], bucket.c["onb.exit.Sell"] = 40, 10
		bucket.x["2026-10-08"] = {["cohort.size"] = 100, ["ret.d1"] = 10, ["onb.01"] = 100}
		bucket.h["session.seconds"] = {le60 = 50, le300 = 50}
		local summary = Report.Summarize({["2026-10-09"] = {v = {v1 = bucket}, shards = 2, source = "shards"}})
		assert(summary.onboardingFunnel[2].ofPrevious == 98 and summary.onboardingFunnel[5].ofJoined == 50)
		assert(summary.totals.avgSessionSec == 300 and summary.totals.session.p50 == "le60")
		assert(summary.cohorts[1].retention.d1.pct == 10 and summary.onboardingExits[1].guideStep == "Collect")
		local areas = {}
		for _, f in summary.flags do areas[f.area] = true end
		assert(areas.onboarding and areas.retention, "expected onboarding and retention flags")
	end)

	return results
end

return Checks
