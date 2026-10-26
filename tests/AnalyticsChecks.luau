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

local Guide = require(game:GetService("ReplicatedStorage").PetRoll.Shared.TutorialGuide)

-- A fresh October 23 empty-start save: no chickens, 0 Coins, introRebirth pending.
local function fakeSession(userId)
	local session = {userId = userId, tutorial = {starterArmy = true, collectedEggCount = 0, rollCount = 0}, firstWins = {},
		kingCleared = false, coins = 0, pets = {}, offers = {}, upgradeTree = {}, introRebirth = "pending", rebirths = 0}
	function session:Count() local n = 0 for _ in self.pets do n += 1 end return n end
	function session:CanSpendCash(amount) return amount <= self.coins end
	return session
end

-- Roblox onboarding step codes sent through the fake sender, in order ("01,02,...").
local function sentSteps(labels)
	local list = {}
	for _, label in labels do
		if string.sub(label, 1, 11) == "onboarding:" then table.insert(list, string.sub(label, 12, 13)) end
	end
	return table.concat(list, ",")
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
		assert(#Schema.TutorialFunnel <= Schema.RobloxLimits.stepsPerFunnel, "schema 11-14 history stays declared")
		local transactions, skus = {}, {}
		for _, d in Schema.Sources do transactions[d.transaction] = true; skus[d.sku] = true end
		for _, d in Schema.Sinks do transactions[d.transaction] = true; skus[d.sku] = true end
		local tCount, sCount = 0, 0
		for _ in transactions do tCount += 1 end
		for _ in skus do sCount += 1 end
		-- Recruit and Upgrade expand by rarity / upgrade key (<= 6 + 10).
		assert(tCount <= Schema.RobloxLimits.transactionTypes and sCount + 16 <= Schema.RobloxLimits.itemSkus)
		assert(Schema.Version == 15, "schema version")
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

	check("Onboarding schema: 15 hard steps in play order, unique ids, short Roblox labels", function()
		local expected = {"Joined", "Loaded", "Rolled", "ChickenTaken", "Egg1", "Eggs3", "Sold", "StartClaimed",
			"PlotExpanded", "RolledAgain", "TutorialDone", "VacuumBought", "Rebirth0", "CluckCampWon", "Rebirth1"}
		assert(#Schema.Onboarding == #expected, "step count " .. #Schema.Onboarding)
		for index, step in Schema.Onboarding do
			assert(step.id == expected[index], "step " .. index .. " is " .. tostring(step.id))
			assert(Schema.OnboardingIndex[step.id] == index, step.id .. " index")
			assert(#step.label <= 36 and #Schema.OnboardingName(index) <= 40, step.id .. " label")
			assert(type(step.trigger) == "string" and #step.trigger >= 8, step.id .. " trigger")
		end
		assert(Schema.OnboardingName(6) == "06 Card 3: 3 eggs clicked (3/8)", Schema.OnboardingName(6))
		assert(Schema.OnboardingName(11) == "11 Card 8: TUTORIAL DONE (8/8)", Schema.OnboardingName(11))
		assert(#Guide.Core == 8, "labels say n/8: update them with the guide's card count")
		assert(Schema.Funnels.Tutorial == nil, "the version 9 recurring funnel is gone")
		assert(#Schema.TutorialFunnel == 29 and Schema.TutorialFunnelIndex.RolledAgain == 29, "schema 11-14 history is declared, not recorded")
		assert(table.find(Schema.CustomEvents, "TutorialExit"), "custom event names are append-only")
	end)

	check("A fresh player's onboarding is recorded once, in order, with journey, exit and profile", function()
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
		assert(analytics:_Stage(analytics.players[42]) == "Ob:Joined", "stage before the profile resolves")
		clock += 2
		analytics:Loaded(session)
		task.wait()
		local st = analytics.players[42]
		assert(st.ready and st.tracked and st.isNew and st.ob.tracked, "fresh empty-start profile should be tracked")
		assert(sentSteps(labels) == "01,02", sentSteps(labels))
		analytics:Signal(session, "IntroStarted"); analytics:Signal(session, "IntroSkipped"); analytics:Signal(session, "Ready")
		local t = session.tutorial
		local state = {tutorial = t, pets = {}, capacity = 3, firstWins = {}}
		local function observe() clock += 1; analytics:Observe(session, state) end
		t.rollCount = 1; observe()
		t.bought, session.pets = true, {{species = "Duck"}}; observe()
		t.collectedEggCount = 1; observe()
		t.collectedEggCount = 3; observe()
		t.soldEggs = true; observe()
		observe() -- repeats must not re-record
		analytics:Income(session, "eggs", 12, 12)
		session.offers = {{species = "Duck", price = 150}}
		analytics:Action(session, "Roll", true, "ok", 12, {}, {})
		analytics:Action(session, "Buy", false, "Not enough cash", 12, {}, {})
		assert(analytics:_Stage(st) == "Ob:Sold", analytics:_Stage(st))
		clock += 30
		analytics:Leave(session)
		task.wait()
		assert(sentSteps(labels) == "01,02,03,04,05,06,07", sentSteps(labels))
		local bucket = ledger.pending["2026-10-09"]["v1"]
		for index = 1, 7 do assert(bucket.c["ob.reach." .. Schema.StepCode(index)] == 1, "reach " .. index) end
		assert(bucket.c["ob.reach.08"] == nil and bucket.c["ob.reach.07|Unknown"] == 1 and bucket.h["ob.t.07"], "platform split and time hist")
		assert(bucket.c["ob.exit.07"] == 1 and bucket.c["session.count"] == 1, "exit at the furthest step")
		assert(bucket.x["2026-10-09"]["cohort.size"] == 1 and bucket.x["2026-10-09"]["ob.07"] == nil, "cohort size only; no per-step cohort keys")
		for name in bucket.c do assert(string.sub(name, 1, 3) ~= "tf." and string.sub(name, 1, 4) ~= "onb.", "old funnel key " .. name) end
		for name in bucket.h do assert(string.sub(name, 1, 3) ~= "tf.", "old funnel hist " .. name) end
		assert(bucket.c["intro.skipped"] == 1 and bucket.c["roll.count"] == 1 and bucket.c["roll.anyAffordable"] == nil)
		assert(bucket.c["econ.src.eggs"] == 12 and bucket.t.reject["Buy | Not enough cash"] == 1)
		assert(not table.find(labels, "custom:TutorialExit"), "TutorialExit is no longer sent")
		assert(#ledger.journeys["2026-10-09"] == 1, "onboarding sessions always keep a journey")
		local journey = ledger.journeys["2026-10-09"][1]
		assert(journey.stage == "Ob:Sold" and journey.mx == 7 and journey.st["07"], "journey stage " .. tostring(journey.stage))
		local saved = players.data[Schema.PlayerKey(42)]
		assert(saved and saved.tracked and saved.ob["07"] and saved.obRbx == 7 and saved.tf == nil and saved.onb == nil and saved.sessions == 1, "profile saved")
		-- Second session: same steps are not counted again; day-1 return lands on the cohort.
		local ledger2 = Ledger.new({store = store, playerStore = players, studio = true, shard = 1, version = "v1",
			clock = function() return 1791547200 + 86400 end})
		local analytics2 = Analytics.new({ledger = ledger2, studio = true, clock = function() return clock end,
			wall = function() return 1791547200 + 86400 end, sender = function(label) table.insert(labels, label) end})
		local session2 = fakeSession(42)
		session2.tutorial = {starterArmy = true, guideStarted = true, collectedEggCount = 3, soldEggs = true, bought = true, rollCount = 1}
		session2.pets = {{species = "Duck"}}
		analytics2:Join(player, session2); analytics2:Loaded(session2); task.wait()
		clock += 1
		analytics2:Observe(session2, {tutorial = session2.tutorial, pets = session2.pets, capacity = 3, firstWins = {}})
		local b2 = ledger2.pending["2026-10-10"]["v1"]
		assert(b2.x["2026-10-09"]["ret.d1"] == 1, "D1 return")
		assert(b2.c["ob.reach.07"] == nil and b2.c["ob.reach.01"] == nil, "step re-counted in a later session")
		assert(sentSteps(labels) == "01,02,03,04,05,06,07", "nothing re-sent to Roblox: " .. sentSteps(labels))
		assert(analytics2:_Stage(analytics2.players[42]) == "Ob:Sold", "stage continues from the profile")
	end)

	check("Roblox gets a step only once every earlier step is reached; the ledger counts true reaches", function()
		local labels, clock = {}, 100
		local players = fakeStore()
		local ledger = Ledger.new({store = fakeStore(), playerStore = players, studio = true, shard = 0, version = "v1",
			clock = function() return 1791547200 end})
		local analytics = Analytics.new({ledger = ledger, studio = true, clock = function() return clock end,
			wall = function() return 1791547200 end, sender = function(label) table.insert(labels, label) end})
		local session = fakeSession(77)
		analytics:Join({UserId = 77}, session); analytics:Loaded(session); task.wait()
		local st = analytics.players[77]
		local t = session.tutorial
		local state = {tutorial = t, pets = {}, firstWins = {}}
		local function observe() clock += 1; analytics:Observe(session, state) end
		-- The eight cards, in order; the tutorial completes on the second chicken.
		t.rollCount, t.bought, session.pets = 1, true, {{}}; observe()
		t.collectedEggCount, t.soldEggs, t.startClaimed = 3, true, true; observe()
		session.upgradeTree.Flock = 1; observe()
		t.rollCount = 2; observe()
		assert(sentSteps(labels) == "01,02,03,04,05,06,07,08,09,10", sentSteps(labels))
		assert(analytics:_Stage(st) == "Ob:RolledAgain", analytics:_Stage(st))
		session.pets, t.coreDone = {{}, {}}, true; observe()
		assert(sentSteps(labels) == "01,02,03,04,05,06,07,08,09,10,11", sentSteps(labels))
		assert(analytics:_Stage(st) == "Ob:TutorialDone", analytics:_Stage(st))
		-- Rebirth 0 before the vacuum: the ledger counts 13 now, Roblox waits for 12.
		session.introRebirth = "done"; observe()
		local bucket = ledger.pending["2026-10-09"]["v1"]
		assert(bucket.c["ob.reach.13"] == 1 and bucket.c["ob.reach.12"] == nil, "ledger keeps true reaches")
		assert(sentSteps(labels) == "01,02,03,04,05,06,07,08,09,10,11", "no step Roblox's player did not do: " .. sentSteps(labels))
		assert(bucket.h["ob.t.13"] and bucket.c["ob.reach.13|Unknown"] == 1)
		-- The vacuum later: Roblox now gets 12 and the waiting 13.
		session.upgradeTree.EggVacuum = 1; observe()
		assert(sentSteps(labels) == "01,02,03,04,05,06,07,08,09,10,11,12,13", sentSteps(labels))
		-- Rebirth 1 without Cluck Camp: the ledger counts 15, Roblox stops at 13.
		session.rebirths = 1; observe()
		assert(bucket.c["ob.reach.15"] == 1 and bucket.c["ob.reach.14"] == nil)
		assert(sentSteps(labels) == "01,02,03,04,05,06,07,08,09,10,11,12,13", sentSteps(labels))
		assert(analytics:_Stage(st) == "Post", analytics:_Stage(st))
		-- Cluck Camp after Rebirth 1 still counts once, and Roblox catches up to 15.
		session.firstWins = {true}; observe(); observe()
		assert(bucket.c["ob.reach.14"] == 1, "camp won after Rebirth 1 still counts")
		assert(sentSteps(labels) == "01,02,03,04,05,06,07,08,09,10,11,12,13,14,15", sentSteps(labels))
		analytics:Leave(session); task.wait()
		for name in bucket.c do assert(string.sub(name, 1, 8) ~= "ob.exit.", "no exit once step 15 is reached: " .. name) end
		local saved = players.data[Schema.PlayerKey(77)]
		assert(saved and saved.ob["15"] and saved.ob["11"] and saved.ob["14"] and saved.obRbx == 15, "profile keeps true reaches and the Roblox mark")
		-- A player who stops after one egg: the exit is recorded at Egg1.
		local quitter = fakeSession(78)
		analytics:Join({UserId = 78}, quitter); analytics:Loaded(quitter); task.wait()
		quitter.tutorial.rollCount, quitter.tutorial.bought, quitter.tutorial.collectedEggCount, quitter.pets = 1, true, 1, {{}}
		clock += 1; analytics:Observe(quitter, {tutorial = quitter.tutorial, pets = quitter.pets, firstWins = {}})
		analytics:Leave(quitter); task.wait()
		assert(bucket.c["ob.exit.05"] == 1 and bucket.c["ob.reach.05"] == 2, "exit at Egg1")
	end)

	check("Playtime funnel sends 10-second then minute checkpoints and records where the session ended", function()
		local labels, clock = {}, 100
		local ledger = Ledger.new({store = fakeStore(), playerStore = fakeStore(), studio = true, shard = 0, version = "v1",
			clock = function() return 1791547200 end})
		local analytics = Analytics.new({ledger = ledger, studio = true, clock = function() return clock end,
			wall = function() return 1791547200 end, sender = function(label) table.insert(labels, label) end,
			random = function() return 1 end}) -- first ledger flush at 280 s, after this check
		assert(#Schema.Playtime == 105 and Schema.Playtime[6].label == "1m" and Schema.Playtime[105].label == "100m")
		assert(#Schema.Funnels.Playtime == 100 and Schema.Funnels.Playtime[100] == "95m")
		local session = fakeSession(5)
		analytics:Join({UserId = 5}, session)
		clock += 25; analytics:Step(0.1)
		clock += 130; analytics:Step(0.1) -- 155 s: 30s .. 2m
		analytics:Leave(session)
		local sent = {}
		for _, label in labels do if string.sub(label, 1, 16) == "funnel:Playtime:" then table.insert(sent, string.sub(label, 17)) end end
		assert(table.concat(sent, ",") == "10s,20s,30s,40s,50s,1m,2m", table.concat(sent, ","))
		local bucket = ledger.pending["2026-10-09"]["v1"]
		assert(bucket.c["play.start"] == 1 and bucket.c["play.s.007"] == 1 and bucket.c["play.s.008"] == nil)
		assert(bucket.c["play.last.007"] == 1, "ended after the 2m checkpoint")
		local summary = Report.Summarize({["2026-10-09"] = {v = {v1 = bucket}, shards = 1, source = "shards"}})
		assert(summary.playtime.started == 1 and summary.playtime.steps[7].sessions == 1 and summary.playtime.biggestDrop.label == "2m")
	end)

	check("Preexisting saves and fresh saves without introRebirth are never tracked into onboarding or cohorts", function()
		local labels = {}
		local ledger = Ledger.new({store = fakeStore(), playerStore = fakeStore(), studio = true, shard = 0, version = "v1",
			clock = function() return 1791547200 end})
		local analytics = Analytics.new({ledger = ledger, studio = true, wall = function() return 1791547200 end,
			sender = function(label) table.insert(labels, label) end})
		local session = fakeSession(7)
		session.tutorial.guideStarted, session.firstWins = true, {true}
		analytics:Join({UserId = 7}, session); analytics:Loaded(session); task.wait()
		assert(analytics:_Stage(analytics.players[7]) == "Untracked")
		-- Fresh by the save, but from before the October 23 empty start (no introRebirth).
		local older = fakeSession(8)
		older.introRebirth = nil
		analytics:Join({UserId = 8}, older); analytics:Loaded(older); task.wait()
		local st = analytics.players[8]
		assert(st.tracked == true and st.ob.tracked == false and analytics:_Stage(st) == "Untracked", "fresh but not empty-start")
		older.tutorial.rollCount, older.tutorial.bought, older.pets = 1, true, {{}}
		analytics:Observe(older, {tutorial = older.tutorial, pets = older.pets, firstWins = {}})
		analytics:Leave(older); task.wait()
		for _, label in labels do assert(string.sub(label, 1, 11) ~= "onboarding:", label) end
		local bucket = ledger.pending["2026-10-09"]["v1"]
		assert(bucket.c["players.preexisting"] == 1 and bucket.x["2026-10-09"]["cohort.size"] == 1, "cohort still counts the fresh save")
		for name in bucket.c do assert(string.sub(name, 1, 3) ~= "ob.", "onboarding key for an untracked player: " .. name) end
	end)

	check("Profile merge keeps the earliest reach times and the furthest progress", function()
		local old = {first = 10, firstDay = "2026-10-01", tracked = true, sessions = 5, play = 900, ob = {["01"] = 0, ["05"] = 40}, obRbx = 5,
			features = {}, ret = {d1 = true}}
		local ours = {first = 20, firstDay = "2026-10-02", tracked = false, sessions = 3, play = 1200, ob = {["05"] = 30, ["06"] = 50}, obRbx = 4,
			features = {Fusion = 600}, ret = {}}
		local m = Analytics.MergeProfile(old, ours)
		assert(m.first == 10 and m.firstDay == "2026-10-01" and m.tracked == true and m.sessions == 5 and m.play == 1200)
		assert(m.ob["01"] == 0 and m.ob["05"] == 30 and m.ob["06"] == 50 and m.obRbx == 5 and m.ret.d1 and m.features.Fusion == 600)
	end)

	check("Report summarizes the onboarding funnel, cohorts and raises flags from merged shards", function()
		local bucket = Ledger.NewBucket()
		-- 100 joined; the big loss is 03 -> 04 (30 players); nobody has reached Rebirth 1 yet.
		for index, reached in {100, 98, 90, 60, 50, 48, 45, 44, 42, 40, 30, 28, 25, 22, 0} do
			bucket.c["ob.reach." .. Schema.StepCode(index)] = reached
		end
		bucket.c["ob.reach.15"] = nil
		bucket.c["session.count"], bucket.c["session.seconds"] = 100, 30000
		bucket.c["ob.exit.03"], bucket.c["ob.exit.05"] = 25, 10
		bucket.h["ob.t.05"] = {le30 = 20, le60 = 30}
		bucket.x["2026-10-08"] = {["cohort.size"] = 100, ["ret.d1"] = 10}
		bucket.h["session.seconds"] = {le60 = 50, le300 = 50}
		local summary = Report.Summarize({["2026-10-09"] = {v = {v1 = bucket}, shards = 2, source = "shards"}})
		local ob = summary.onboarding
		assert(#ob.steps == 15 and ob.joined == 100 and ob.steps[2].ofPrevious == 98 and ob.steps[5].ofJoined == 50)
		assert(ob.steps[5].p50 == "le60" and ob.steps[5].n == 50 and ob.steps[3].exitsHere == 25 and ob.steps[15].reached == 0)
		assert(ob.steps[6].ofPrevious == 96 and ob.steps[15].ofPrevious == 0 and ob.steps[1].ofPrevious == nil, "0 of 22 is 0%; Joined has no previous")
		assert(ob.biggestDrop.from == Schema.OnboardingName(3) and ob.biggestDrop.to == Schema.OnboardingName(4)
			and ob.biggestDrop.lost == 30 and ob.biggestDrop.pct == 33.3 and ob.biggestDrop.exitsAtFrom == 25, "biggest drop")
		assert(ob.exitsTotal == 35 and ob.exitsNone == 0)
		assert(summary.totals.avgSessionSec == 300 and summary.totals.session.p50 == "le60")
		assert(summary.cohorts[1].retention.d1.pct == 10 and summary.cohorts[1].steps == nil)
		assert(summary.tutorialFunnel == nil and summary.tutorialExits == nil and summary.onboardingFunnel == nil)
		local areas, dropFlag = {}, nil
		for _, f in summary.flags do areas[f.area] = true; if f.area == "onboarding" then dropFlag = f end end
		assert(areas.onboarding and areas.retention, "expected onboarding and retention flags")
		assert(dropFlag.severity == "high" and string.find(dropFlag.text, Schema.OnboardingName(4), 1, true), dropFlag.text)
		local text = Report.OnboardingText(summary)
		assert(string.find(text, "100 joined", 1, true) and string.find(text, Schema.OnboardingName(5), 1, true)
			and string.find(text, "Biggest drop", 1, true), text)
		assert(select(2, string.gsub(text, "\n", "")) == 17, "header, columns, 15 rows, drop line")
		-- Fewer than 20 joined: no onboarding flag.
		local small = Ledger.NewBucket()
		small.c["ob.reach.01"], small.c["ob.reach.02"] = 10, 2
		local quiet = Report.Summarize({["2026-10-09"] = {v = {v1 = small}, shards = 1, source = "shards"}})
		for _, f in quiet.flags do assert(f.area ~= "onboarding", f.text) end
		assert(quiet.onboarding.biggestDrop.lost == 8)
	end)

	check("Version 5 schema: feature funnels, Roblox steps, client events and menus are consistent", function()
		local funnels = 1 -- onboarding
		for _ in Schema.Funnels do funnels += 1 end
		assert(funnels <= 10 and funnels <= Schema.RobloxLimits.funnels, "too many Roblox funnels: " .. funnels)
		assert(#Schema.CustomEvents <= 100)
		local funnelIds = {}
		for _, funnel in Schema.FeatureFunnels do
			assert(type(funnel.id) == "string" and string.match(funnel.id, "^%w+$"), "bad funnel id")
			assert(not funnelIds[funnel.id], "duplicate funnel " .. funnel.id); funnelIds[funnel.id] = true
			assert(#funnel.steps >= 1 and #funnel.steps <= 99, funnel.id .. " step count")
			local ids = {}
			for index, step in funnel.steps do
				assert(type(step.id) == "string" and string.match(step.id, "^%w+$"), funnel.id .. " bad step id")
				assert(not ids[step.id], funnel.id .. " repeats step " .. step.id); ids[step.id] = true
				assert(Schema.FeatureFunnelIndex[funnel.id][step.id] == index)
			end
		end
		for funnelId, map in Schema.RobloxSteps do
			local roblox = Schema.Funnels[funnelId]
			assert(roblox and funnelIds[funnelId], "RobloxSteps." .. funnelId .. " has no Roblox or feature funnel")
			local used = {}
			for stepId, robloxIndex in map do
				assert(Schema.FeatureFunnelIndex[funnelId][stepId], funnelId .. "." .. stepId .. " is not a feature step")
				assert(roblox[robloxIndex] and not used[robloxIndex], funnelId .. " Roblox step " .. tostring(robloxIndex))
				used[robloxIndex] = true
			end
		end
		local kinds = {menu = true, path = true, free = true, none = true}
		for name, kind in Schema.ClientEvents do assert(kinds[kind], "client event " .. name .. " kind " .. tostring(kind)) end
		local serverKinds = {free = true, none = true, tier = true, level = true}
		for name, kind in Schema.ServerEvents do assert(serverKinds[kind], "server event " .. name .. " kind " .. tostring(kind)) end
		assert(Schema.Menus.Other, "unknown menus fall back to Other")
		for menu, on in Schema.Menus do
			-- Menus are ledger name segments and the "<Menu>/" part of path details.
			assert(on == true and string.match(menu, "^%w+$") and #menu <= 24, "menu name " .. menu)
		end
		for name, kind in Schema.StateSnapshot do assert(Schema.Buckets[kind], "state." .. name .. " bucket " .. kind) end
		for _, tier in Schema.DeviceTiers do assert(string.match(tier, "^%w+$")) end
	end)

	check("Report computes feature funnels, UI, devices, Robux, server events and new flags", function()
		local b = Ledger.NewBucket()
		b.c["session.count"], b.c["players.unique"] = 200, 100
		b.c["fun.Feed.p.01"], b.c["fun.Feed.p.02"], b.c["fun.Feed.p.03"] = 100, 80, 20
		b.c["fun.Feed.s.01"], b.c["fun.Feed.last.02"] = 150, 30
		b.h["fun.Feed.t.03"] = {le60 = 10, le600 = 10}
		b.x["2026-10-08"] = {["cohort.size"] = 50, ["fun.Feed.01"] = 40, ["fun.Feed.03"] = 5}
		b.c["ui.menu.open.Army"], b.c["ui.menu.open.Shop"] = 150, 10
		b.h["ui.menu.dwell.Army"] = {le5 = 100, le60 = 20}
		b.c["ui.prompt.bought"], b.c["ui.prompt.cancel"] = 5, 20
		b.t["ui.click"] = {["Army/Close"] = 9, ["Shop/Buy"] = 3}
		b.c["robux.actual"], b.c["robux.actual.n"] = 900, 3
		b.c["robux.actual.product.CashPack"], b.c["robux.actual.pass.Luck"] = 400, 500
		b.c["robux.actual.tier.Low"], b.c["robux.actual.premium.yes"] = 900, 900
		b.c["robux.payer.tier.Low"], b.c["seg.session.tier.Low"] = 3, 60
		b.c["sev.data.saveFail"], b.c["sev.data.saveFail.timeout"] = 2, 2
		b.c["sev.mission.result.won.2"], b.c["sev.battle.end"] = 4, 6
		b.h["sev.battle.end.v"] = {le60 = 6}
		b.h["state.rebirths"] = {le0 = 7, le1 = 3}
		b.h["perf.fps.tier.Low"] = {le20 = 25, le60 = 5}
		local s = Report.Summarize({["2026-10-09"] = {v = {v1 = b}, shards = 1, source = "shards"}})
		local fuse
		for _, f in s.featureFunnels do if f.funnel == "Feed" then fuse = f end end
		assert(fuse and fuse.started == 100 and fuse.steps[1].conversionFromPrev == nil)
		assert(fuse.steps[2].conversionFromPrev == 80 and fuse.steps[3].conversionFromPrev == 25)
		assert(fuse.steps[3].timeP50 == "le60" and fuse.steps[3].timeP90 == "le600" and fuse.steps[2].lastStepSessions == 30)
		assert(fuse.steps[4].conversionFromPrev == 0, "20 -> 0 players is 0%")
		assert(fuse.worstStep and fuse.worstStep.id == "MaxLevelUp" and fuse.worstStep.fromPlayers == 20, "worst needs >= 20 at prev")
		assert(fuse.cohorts[1].cohort == "2026-10-08" and fuse.cohorts[1].steps["03"] == 5 and fuse.cohorts[1].size == 50)
		assert(s.ui.menus[1].menu == "Army" and s.ui.menus[1].dwellP50 == "le5" and s.ui.topClicks[1].key == "Army/Close")
		assert(s.ui.prompts.cancelRate == 80)
		assert(s.robuxActual.total == 900 and #s.robuxActual.byKey == 2 and s.robuxActual.byKind.pass == 500)
		assert(s.robuxActual.newPayers == 3 and s.robuxActual.arppu == 300)
		local low
		for _, row in s.devices.byTier do if row.segment == "Low" then low = row end end
		assert(low and low.sessions == 60 and low.revenue == 900 and low.arppu == 300 and s.devices.payerRate == 3)
		assert(s.serverEvents["data.saveFail"].count == 2 and s.serverEvents["data.saveFail"].details.timeout == 2)
		assert(s.serverEvents["mission.result"].details["won.2"] == 4 and s.serverEvents["battle.end"].value.p50 == "le60")
		local rebirths
		for _, row in s.stateSnapshots do if row.name == "rebirths" then rebirths = row end end
		assert(rebirths and rebirths.p50 == "le0" and rebirths.n == 10)
		local texts = {}
		for _, f in s.flags do texts[f.area] = (texts[f.area] or "") .. f.text .. "\n" end
		assert(texts.funnel and string.find(texts.funnel, "Fed -> Fed10", 1, true), "funnel flag")
		assert(texts.monetization, "prompt cancel flag")
		assert(texts.health and string.find(texts.health, "save failures", 1, true), "save fail flag")
		assert(texts.performance and string.find(texts.performance, "Low-tier", 1, true), "tier fps flag")
		assert(texts.ui and string.find(texts.ui, "Army", 1, true), "fast-dwell menu flag")
		assert(texts.onboarding == nil, "no onboarding data, no onboarding flag")
		assert(Report.Percentile({["le1e+06"] = 1, ["gt1e+15"] = 1, ["le1e+07"] = 2}, 0.5) == "le1e+07", "bigCash labels sort")
	end)

	check("Report.Players lists profiles through a fake store, pages, filters and sorts", function()
		local data = {
			["p/1"] = {play = 100, sessions = 2, robuxActual = 50, robux = 40, purchases = 1, geo = "US",
				dev = {platform = "Mobile", tier = "Low"}, lastExit = {menu = "Shop"}, lastSeen = 30, ob = {["01"] = 0, ["06"] = 90}},
			["p/2"] = {play = 900, sessions = 9, robux = 0, lastSeen = 20, tf = {["01"] = 0, ["18"] = 200}},
			["p/3"] = {play = 50, robuxActual = 400, purchases = 2, geo = "BR", dev = {platform = "Desktop", tier = "High"}, lastSeen = 10},
			["p/4"] = "corrupt",
		}
		local order = {"p/1", "p/2", "p/3", "p/4"}
		local store = {gets = 0}
		function store:GetAsync(key) store.gets += 1; return data[key] end
		function store:ListKeysAsync(prefix, pageSize)
			assert(prefix == "p/")
			local pages = {IsFinished = false, at = 1, size = 2}
			function pages:GetCurrentPage()
				local page = {}
				for i = self.at, math.min(self.at + self.size - 1, #order) do table.insert(page, {KeyName = order[i]}) end
				return page
			end
			function pages:AdvanceToNextPageAsync()
				self.at += self.size
				self.IsFinished = self.at + self.size > #order
			end
			return pages
		end
		local all = Report.Players({store = store, limit = 10})
		assert(all.scanned == 4 and all.listComplete and all.readFailures == 1 and all.count == 3)
		assert(all.players[1].userId == 3 and all.players[2].userId == 1 and all.players[3].userId == 2, "robux sort")
		assert(all.players[2].tier == "Low" and all.players[2].platform == "Mobile" and all.players[2].lastExit.menu == "Shop")
		assert(all.players[2].onboardingMax == 6 and all.players[3].onboardingMax == nil, "furthest onboarding step from profile.ob only")
		assert(all.totals.players == 3 and all.totals.payers == 2 and all.totals.revenue == 450)
		assert(all.totals.byTier.Low.revenue == 50 and all.totals.byGeo.BR.payers == 1 and all.totals.byPlatform.Unknown.players == 1)
		local byPlay = Report.Players({store = store, limit = 1, scan = 4, sortBy = "play"})
		assert(byPlay.count == 1 and byPlay.players[1].userId == 2 and byPlay.totals.players == 3)
		local payers = Report.Players({store = store, minRobux = 41})
		assert(payers.count == 2 and payers.totals.payers == 2)
		local capped = Report.Players({store = store, limit = 1})
		assert(capped.scanned == 1 and not capped.listComplete)
		local json = game:GetService("HttpService"):JSONEncode(all)
		assert(#json > 0)
	end)

	return results
end

return Checks
