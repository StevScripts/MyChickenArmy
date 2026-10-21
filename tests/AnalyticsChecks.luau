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
		-- Version 11: Roblox's Onboarding dashboard carries the Tutorial funnel.
		local expected = {}
		for index = 1, 8 do table.insert(expected, Schema.TutorialFunnelName(index)) end
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

	check("Version 11 Tutorial funnel: every tutorial action once, in order, soft steps passed over, exits recorded", function()
		local labels, clock = {}, 100
		local players = fakeStore()
		local ledger = Ledger.new({store = fakeStore(), playerStore = players, studio = true, shard = 0, version = "v1",
			clock = function() return 1791547200 end})
		local analytics = Analytics.new({ledger = ledger, studio = true, clock = function() return clock end,
			wall = function() return 1791547200 end, sender = function(label) table.insert(labels, label) end})
		local session = fakeSession(77)
		analytics:Join({UserId = 77}, session); analytics:Loaded(session); task.wait()
		local st = analytics.players[77]
		assert(st.tf and st.tf.tracked, "a fresh save is tracked")
		local I = Schema.TutorialFunnelIndex
		local t = session.tutorial
		t.guideStarted = true
		local state = {tutorial = t, pets = {1, 2, 3}, capacity = 3, selectedCount = 3, firstWins = {}, flock = {size = 3},
			tools = {eggVacuum = false}}
		local function observe() clock += 1; analytics:Observe(session, state) end
		local function signal(name) clock += 1; analytics:Signal(session, name) end
		local function sent()
			local list = {}
			for _, label in labels do
				if string.sub(label, 1, 11) == "onboarding:" then table.insert(list, string.sub(label, 12, 13)) end
			end
			return table.concat(list, ",")
		end
		signal("IntroSkipped"); signal("Ready")
		t.collectedEggCount = 1; observe()
		t.collectedEggCount = 3; observe()
		t.soldEggs = true; observe()
		t.rolled = true; observe()
		t.bought, state.pets = true, {1, 2, 3, 4}; observe()
		signal("TreeOpen") -- the vacuum lesson asks for Upgrades
		state.tools.eggVacuum = true; observe() -- claimed without the Tools-tab report reaching us
		signal("VacuumEquip")
		t.vacuumEggCount = 10; observe()
		t.vacuumEggCount = 20; observe()
		t.vacuumSold = true; observe()
		t.guideCompleted = true; observe()
		session.daily = {streak = 1, lastDay = 20000}; observe()
		t.wonCamp = true; observe(); observe()
		assert(sent() == "01,02,03,04,05,06,07,08,09,10,11,13,14,15,16,17,18,19,20", sent())
		local bucket = ledger.pending["2026-10-09"]["v1"]
		local tools = Schema.StepCode(I.ToolsOpen)
		assert(bucket.c["tf.skip." .. tools] == 1 and bucket.c["tf.reach." .. tools] == nil, "Tools tab passed over")
		assert(bucket.c["tf.reach.18"] == 1 and bucket.c["tf.gap.13"] == nil and bucket.c["tf.s1.18"] == 1, "complete, no false gap")
		assert(bucket.h["tf.t.05"] and bucket.h["tf.d.05"], "time and dwell histograms")
		assert(bucket.x["2026-10-09"]["tf.18"] == 1, "cohort")
		analytics:Leave(session); task.wait()
		assert(bucket.c["tf.exit.20"] == nil, "a finished tutorial is not an exit")
		local saved = players.data[Schema.PlayerKey(77)]
		assert(saved and saved.tf and saved.tf["18"] and saved.tfSkip[tools] and saved.tfRbx == 20, "profile keeps the funnel")
		-- A player who stops after one egg: the exit and the lesson on screen are recorded.
		local quitter = fakeSession(78)
		analytics:Join({UserId = 78}, quitter); analytics:Loaded(quitter); task.wait()
		quitter.tutorial.guideStarted, quitter.tutorial.collectedEggCount = true, 1
		clock += 1; analytics:Observe(quitter, {tutorial = quitter.tutorial, pets = {1, 2, 3}, capacity = 3, firstWins = {}})
		analytics:Leave(quitter); task.wait()
		assert(bucket.c["tf.exit.05"] == 1 and bucket.c["tf.exitLesson.None"] == 1, "exit at Egg1")
	end)

	check("Tutorial funnel schema: unique ids, short Roblox labels, every step fully described", function()
		local seen = {}
		assert(#Schema.TutorialFunnel == 24 and #Schema.TutorialFunnel <= Schema.RobloxLimits.stepsPerFunnel)
		for index, step in Schema.TutorialFunnel do
			assert(not seen[step.id], "duplicate " .. step.id); seen[step.id] = true
			assert(Schema.TutorialFunnelIndex[step.id] == index and (step.kind == "hard" or step.kind == "soft"), step.id)
			assert(#Schema.TutorialFunnelName(index) <= 40, step.id .. " label")
			for _, field in {"screen", "trigger", "about"} do
				assert(type(step[field]) == "string" and #step[field] >= 8, step.id .. " needs " .. field)
			end
		end
		assert(Schema.Funnels.Tutorial == nil, "the version 9 recurring funnel is gone")
		local funnels = 1
		for _ in Schema.Funnels do funnels += 1 end
		assert(funnels <= Schema.RobloxLimits.funnels, "Roblox funnel count " .. funnels)
	end)

	check("Roblox onboarding (Tutorial funnel) goes out in order: missing hard steps wait, then fill", function()
		local labels = {}
		local ledger = Ledger.new({store = fakeStore(), playerStore = fakeStore(), studio = true, shard = 0, version = "v1",
			clock = function() return 1791547200 end})
		local analytics = Analytics.new({ledger = ledger, studio = true, sender = function(label) table.insert(labels, label) end})
		local session = fakeSession(9)
		analytics:Join({UserId = 9}, session); analytics:Loaded(session); task.wait()
		local st = analytics.players[9]
		local part, I = analytics.tutorialFunnel, Schema.TutorialFunnelIndex
		local function sent()
			local list = {}
			for _, label in labels do if string.sub(label, 1, 11) == "onboarding:" then table.insert(list, string.sub(label, 12, 13)) end end
			return table.concat(list, ",")
		end
		part:Reach(st, I.Egg3) -- eggs counted before the intro and ready reports
		assert(sent() == "01,02", sent())
		analytics:Signal(session, "IntroSkipped"); analytics:Signal(session, "Ready")
		assert(sent() == "01,02,03,04", sent())
		part:Reach(st, I.Sold)
		assert(sent() == "01,02,03,04", "Egg1 waits for three later steps: " .. sent())
		part:Reach(st, I.LeverPulled)
		assert(sent() == "01,02,03,04,07,08,09", sent())
		local bucket = ledger.pending["2026-10-09"]["v1"]
		assert(bucket.c["tf.robloxGapFill.05"] == 1 and bucket.c["tf.robloxGapFill.06"] == 1 and bucket.c["tf.gap.07"] == 1)
		assert(st.profile.tfRbx == 9)
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
		b.c["fun.Fuse.p.01"], b.c["fun.Fuse.p.02"], b.c["fun.Fuse.p.03"] = 100, 80, 20
		b.c["fun.Fuse.s.01"], b.c["fun.Fuse.last.02"] = 150, 30
		b.h["fun.Fuse.t.03"] = {le60 = 10, le600 = 10}
		b.x["2026-10-08"] = {["cohort.size"] = 50, ["fun.Fuse.01"] = 40, ["fun.Fuse.03"] = 5}
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
		for _, f in s.featureFunnels do if f.funnel == "Fuse" then fuse = f end end
		assert(fuse and fuse.started == 100 and fuse.steps[1].conversionFromPrev == nil)
		assert(fuse.steps[2].conversionFromPrev == 80 and fuse.steps[3].conversionFromPrev == 25)
		assert(fuse.steps[3].timeP50 == "le60" and fuse.steps[3].timeP90 == "le600" and fuse.steps[2].lastStepSessions == 30)
		assert(fuse.steps[4].conversionFromPrev == 0, "20 -> 0 players is 0%")
		assert(fuse.worstStep and fuse.worstStep.id == "Fused" and fuse.worstStep.fromPlayers == 20, "worst needs >= 20 at prev")
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
		assert(texts.funnel and string.find(texts.funnel, "Available -> Opened", 1, true), "funnel flag")
		assert(texts.monetization, "prompt cancel flag")
		assert(texts.health and string.find(texts.health, "save failures", 1, true), "save fail flag")
		assert(texts.performance and string.find(texts.performance, "Low-tier", 1, true), "tier fps flag")
		assert(texts.ui and string.find(texts.ui, "Army", 1, true), "fast-dwell menu flag")
		assert(Report.Percentile({["le1e+06"] = 1, ["gt1e+15"] = 1, ["le1e+07"] = 2}, 0.5) == "le1e+07", "bigCash labels sort")
	end)

	check("Report.Players lists profiles through a fake store, pages, filters and sorts", function()
		local data = {
			["p/1"] = {play = 100, sessions = 2, robuxActual = 50, robux = 40, purchases = 1, geo = "US",
				dev = {platform = "Mobile", tier = "Low"}, lastExit = {menu = "Shop"}, lastSeen = 30},
			["p/2"] = {play = 900, sessions = 9, robux = 0, lastSeen = 20},
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
