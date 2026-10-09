--!strict
-- Agent-facing reader for the analytics ledger. Read-only except for rollup
-- caches (r/<day>) of finished days. Run from Studio Edit through the Studio
-- MCP; see docs/analytics/AGENT_GUIDE.md for the exact snippet and meanings.
-- Usage: Report.Summary({days = 7, env = "live"}) -> summary table
--        Report.SummaryJSON(...) -> string; Report.Journeys({day = "YYYY-MM-DD"})
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Schema = require(script.Parent.AnalyticsSchema)
local Ledger = require(script.Parent.AnalyticsLedger)

local Report = {}

type Options = {days: number?, from: string?, to: string?, env: string?, rollups: boolean?,
	store: any?, now: number?, version: string?}

local function store(options: Options)
	if options.store then return options.store end
	local suffix = if options.env == "studio" then Schema.StudioSuffix else ""
	return DataStoreService:GetDataStore(Schema.LedgerStore .. suffix)
end

local function waitBudget(kind: Enum.DataStoreRequestType)
	for _ = 1, 120 do
		local ok, budget = pcall(function() return DataStoreService:GetRequestBudgetForRequestType(kind) end)
		if not ok or budget >= 1 then return end
		task.wait(0.5)
	end
end

local function dayTime(day: string): number
	local y, m, d = string.match(day, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	assert(y, "Days are YYYY-MM-DD (UTC): " .. tostring(day))
	return os.time({year = tonumber(y) :: number, month = tonumber(m) :: number, day = tonumber(d) :: number, hour = 12})
end

-- Inclusive UTC day list ending at `to` (default today): `days` long, or from `from`.
local function dayList(options: Options): {string}
	local to = options.to or Ledger.Today(options.now or os.time())
	local toTime = dayTime(to)
	local count = if options.from then (Ledger.DaysBetween(options.from, to) or 0) + 1 else options.days or 7
	local days = {}
	for i = count - 1, 0, -1 do table.insert(days, os.date("!%Y-%m-%d", toTime - i * 86400) :: string) end
	return days
end

-- Returns {[day] = {v = {[version] = bucket}, shards = n, source = "rollup"|"shards"|"empty"}}.
function Report.Pull(options: Options?)
	local opts = options or {} :: Options
	local ds = store(opts)
	local today = Ledger.Today(opts.now or os.time())
	local result = {}
	for _, day in dayList(opts) do
		local finished = day < today
		if opts.rollups ~= false and finished then
			waitBudget(Enum.DataStoreRequestType.GetAsync)
			local ok, rollup = pcall(function() return ds:GetAsync(Schema.RollupKey(day)) end)
			if ok and type(rollup) == "table" and rollup.v then
				result[day] = {v = rollup.v, shards = rollup.shards or 0, source = "rollup"}
				continue
			end
		end
		local merged, shards = {}, 0
		for shard = 0, Schema.Shards - 1 do
			waitBudget(Enum.DataStoreRequestType.GetAsync)
			local ok, record = pcall(function() return ds:GetAsync(Schema.DayKey(day, shard)) end)
			if ok and type(record) == "table" and type(record.v) == "table" then
				shards += 1
				for version, bucket in record.v do
					merged[version] = Ledger.MergeBucket(merged[version] or Ledger.NewBucket(), bucket)
				end
			end
		end
		result[day] = {v = merged, shards = shards, source = if shards > 0 then "shards" else "empty"}
		-- Cache finished days so later reads cost one request. Late flushes after
		-- 01:00 UTC are rare; a stale rollup can be rebuilt with rollups=false.
		if finished and shards > 0 and opts.rollups ~= false and (Ledger.DaysBetween(day, today) or 0) >= 1 then
			local hour = tonumber(os.date("!%H", opts.now or os.time())) or 0
			if (Ledger.DaysBetween(day, today) or 0) >= 2 or hour >= 1 then
				pcall(function()
					waitBudget(Enum.DataStoreRequestType.SetIncrementAsync)
					ds:SetAsync(Schema.RollupKey(day), {schema = Schema.Version, day = day, v = merged, shards = shards, builtAt = os.time()})
				end)
			end
		end
	end
	return result
end

-- Histogram helpers ------------------------------------------------------------

local function edge(label: string): number
	local kind, number = string.match(label, "^(%a%a)(%d+)$")
	if not kind then return math.huge end
	return if kind == "gt" then (tonumber(number) or 0) + 0.5 else tonumber(number) or math.huge
end

-- Upper-bound percentile: "p50 <= label". Returns the label, the edge and the sample size.
function Report.Percentile(hist: {[string]: number}?, p: number): (string?, number)
	if not hist then return nil, 0 end
	local labels, total = {}, 0
	for label, count in hist do table.insert(labels, label); total += count end
	if total == 0 then return nil, 0 end
	table.sort(labels, function(a, b) return edge(a) < edge(b) end)
	local running = 0
	for _, label in labels do
		running += hist[label]
		if running >= total * p then return label, total end
	end
	return labels[#labels], total
end

local function pct(a: number?, b: number?): number?
	if not a or not b or b == 0 then return nil end
	return math.floor(a / b * 1000 + 0.5) / 10
end

local function stat(hist)
	local p50, n = Report.Percentile(hist, 0.5)
	local p90 = Report.Percentile(hist, 0.9)
	return {p50 = p50, p90 = p90, n = n}
end

local function prefixed(map: {[string]: any}, prefix: string): {[string]: any}
	local out = {}
	for name, value in map do
		if string.sub(name, 1, #prefix) == prefix then out[string.sub(name, #prefix + 1)] = value end
	end
	return out
end

local function sortedTop(map: {[string]: number}?, limit: number)
	local list = {}
	for key, count in map or {} do table.insert(list, {key = key, n = count}) end
	table.sort(list, function(a, b) return a.n > b.n end)
	while #list > limit do table.remove(list) end
	return list
end

-- Summary ------------------------------------------------------------------------

function Report.Summarize(pulled: any, options: Options?)
	local opts = options or {} :: Options
	local total = Ledger.NewBucket()
	local perDay, perVersion, dayNames = {}, {}, {}
	for day, entry in pulled do
		table.insert(dayNames, day)
		local dayBucket = Ledger.NewBucket()
		for version, bucket in entry.v do
			if opts.version and version ~= opts.version then continue end
			Ledger.MergeBucket(dayBucket, bucket)
			perVersion[version] = Ledger.MergeBucket(perVersion[version] or Ledger.NewBucket(), bucket)
		end
		Ledger.MergeBucket(total, dayBucket)
		perDay[day] = {bucket = dayBucket, shards = entry.shards, source = entry.source}
	end
	table.sort(dayNames)
	local c, h = total.c, total.h

	local daily = {}
	for _, day in dayNames do
		local b = perDay[day].bucket
		local sessions = b.c["session.count"] or 0
		table.insert(daily, {day = day, shards = perDay[day].shards, source = perDay[day].source,
			unique = b.c["players.unique"] or 0, new = b.c["players.new"] or 0, joins = b.c["players.join"] or 0,
			sessions = sessions, avgSessionSec = if sessions > 0 then math.floor((b.c["session.seconds"] or 0) / sessions) else nil,
			medianSession = Report.Percentile(b.h["session.seconds"], 0.5), peakServerPlayers = b.m["server.peakPlayers"],
			playerMinutes = b.c["player.minutes"] or 0, robux = b.c["robux.estimate"] or 0, errorsServer = b.c["err.server"] or 0,
			errorsClient = b.c["err.client"] or 0})
	end

	-- Onboarding funnel by day of reach (all tracked players in range).
	local funnel = {}
	local first = c["onb.reach.01"]
	local previous = nil
	for index, step in Schema.Onboarding do
		local code = Schema.StepCode(index)
		local reached = c["onb.reach." .. code] or 0
		table.insert(funnel, {step = Schema.StepName(index), reached = reached, ofJoined = pct(reached, first),
			ofPrevious = pct(reached, previous), timeToStep = stat(h["onb.t." .. code]), about = step.about})
		previous = reached
	end

	-- Cohorts: x[firstDay] merged across every pulled day (steps/returns land later).
	local cohorts = {}
	for day, counters in total.x do
		local size = counters["cohort.size"] or 0
		local row = {cohort = day, size = size, steps = {}, retention = {}, payers = counters["robux.payer"] or 0,
			anyLater = counters["ret.anyLater"] or 0, anyLaterPct = pct(counters["ret.anyLater"], size)}
		for index in Schema.Onboarding do
			local code = Schema.StepCode(index)
			row.steps[code] = counters["onb." .. code] or 0
		end
		for _, d in Schema.RetentionDays do
			local n = counters["ret.d" .. d]
			if n then row.retention["d" .. d] = {n = n, pct = pct(n, size)} end
		end
		table.insert(cohorts, row)
	end
	table.sort(cohorts, function(a, b) return a.cohort < b.cohort end)

	local exits = {}
	for step, n in prefixed(c, "onb.exit.") do
		table.insert(exits, {guideStep = step, n = n, firstSession = c["onb.exitFirstSession." .. step] or 0,
			dwell = stat(h["onb.exitDwell." .. step])})
	end
	table.sort(exits, function(a, b) return a.n > b.n end)
	local exitMax = {}
	for code, n in prefixed(c, "onb.exitMax.") do table.insert(exitMax, {maxStep = code, n = n}) end
	table.sort(exitMax, function(a, b) return a.maxStep < b.maxStep end)

	local dwell = {}
	for name, hist in h do
		if string.sub(name, 1, 12) == "guide.dwell." then
			local step = string.sub(name, 13)
			table.insert(dwell, {guideStep = step, entered = c["guide.enter." .. step] or 0, dwell = stat(hist)})
		end
	end
	table.sort(dwell, function(a, b) return (a.dwell.n or 0) > (b.dwell.n or 0) end)

	local economy = {sources = {}, sinks = {}, sourceTotal = c["econ.srcTotal"] or 0, sinkTotal = c["econ.sinkTotal"] or 0,
		balanceAtLeave = stat(h["econ.balanceAtLeave"]), sessionEarned = stat(h["econ.sessionEarned"])}
	for name, amount in prefixed(c, "econ.src.") do
		if string.sub(name, -2) ~= ".n" then table.insert(economy.sources, {source = name, amount = amount, n = c["econ.src." .. name .. ".n"]}) end
	end
	for name, amount in prefixed(c, "econ.sink.") do
		if string.sub(name, -2) ~= ".n" then table.insert(economy.sinks, {sku = name, amount = amount, n = c["econ.sink." .. name .. ".n"]}) end
	end
	table.sort(economy.sources, function(a, b) return a.amount > b.amount end)
	table.sort(economy.sinks, function(a, b) return a.amount > b.amount end)

	local rolls = {count = c["roll.count"] or 0, anyAffordablePct = pct(c["roll.anyAffordable"], c["roll.count"]),
		rollsPerBuy = stat(h["roll.rollsPerBuy"]), perSession = stat(h["roll.perSession"]), byRarity = {}}
	local offers = 0
	for _, rarity in Schema.Rarities do offers += c["roll.offer." .. rarity] or 0 end
	for _, rarity in Schema.Rarities do
		local n = c["roll.offer." .. rarity] or 0
		table.insert(rolls.byRarity, {rarity = rarity, offered = n, offerShare = pct(n, offers),
			affordablePct = pct(c["roll.offer." .. rarity .. ".affordable"], n), bought = c["roll.buy." .. rarity] or 0,
			buyRate = pct(c["roll.buy." .. rarity], n)})
	end

	local camps = {}
	for _, step in {"Camp1", "Camp2", "Camp3", "King"} do
		local odds = {}
		for name, n in prefixed(c, "camp." .. step .. ".odds.") do odds[name] = n end
		table.insert(camps, {camp = step, attempts = c["camp." .. step .. ".attempt"] or 0,
			attemptsBeforeWin = c["camp." .. step .. ".attemptBeforeWin"] or 0, firstWins = c["camp." .. step .. ".firstWin"] or 0,
			fails = c["camp." .. step .. ".fail"] or 0, failReasons = prefixed(c, "camp." .. step .. ".fail."),
			firstWinSeconds = stat(h["camp." .. step .. ".firstWin.seconds"]), oddsByResult = odds})
	end

	local features = {}
	for name, n in prefixed(c, "feature.first.") do
		table.insert(features, {feature = name, firstUses = n, uses = c["feature.use." .. name] or 0,
			timeToFirstUse = stat(h["feature.first." .. name])})
	end
	table.sort(features, function(a, b) return a.firstUses > b.firstUses end)

	local robux = {purchases = c["robux.purchases"] or 0, estimate = c["robux.estimate"] or 0,
		firstPurchases = c["robux.firstPurchase"] or 0, firstPurchasePlaySeconds = stat(h["robux.firstPurchase.playSeconds"]),
		byStage = prefixed(c, "robux.stage."), products = prefixed(c, "robux.product."), passes = prefixed(c, "robux.pass."),
		prompts = prefixed(c, "shop.prompt.")}

	local platforms, perf = prefixed(c, "client.platform."), {}
	for name, hist in h do
		local metric, platform = string.match(name, "^([%w%.]+)|(%w+)$")
		if metric and platform and (metric == "perf.fps" or metric == "perf.fpsMin" or metric == "perf.memMb"
			or metric == "net.pingMs" or metric == "session.seconds") then
			perf[metric .. "|" .. platform] = stat(hist)
		end
	end

	local health = {
		errorsServer = c["err.server"] or 0, errorsClient = c["err.client"] or 0,
		topServerErrors = sortedTop(total.t["err.server"], 10), topClientErrors = sortedTop(total.t["err.client"], 10),
		topRejections = sortedTop(total.t["reject"], 15), loadFailures = c["data.loadFail"] or 0,
		topLoadFailures = sortedTop(total.t["data.loadFail"], 5), leftBeforeReady = c["players.leftBeforeReady"] or 0,
		serverFrameMs = stat(h["server.frameMs"]), serverFrameMaxMs = stat(h["server.frameMaxMs"]),
		loadServerSeconds = stat(h["load.serverSeconds"]), readySeconds = stat(h["load.readySeconds"]),
		meta = prefixed(c, "analytics."),
	}

	local sessions = c["session.count"] or 0
	local summary = {
		schema = Schema.Version, range = {from = dayNames[1], to = dayNames[#dayNames], days = #dayNames},
		versions = (function() local list = {} for v in perVersion do table.insert(list, v) end table.sort(list) return list end)(),
		totals = {unique = c["players.unique"] or 0, new = c["players.new"] or 0, preexisting = c["players.preexisting"] or 0,
			joins = c["players.join"] or 0, tracked = c["players.join.tracked"] or 0, sessions = sessions,
			avgSessionSec = if sessions > 0 then math.floor((c["session.seconds"] or 0) / sessions) else nil,
			session = stat(h["session.seconds"]), sessionNew = stat(h["session.seconds.new"]),
			sessionReturning = stat(h["session.seconds.returning"]), playerMinutes = c["player.minutes"] or 0,
			serverMinutes = c["server.minutes"] or 0},
		daily = daily, onboardingFunnel = funnel, cohorts = cohorts, onboardingExits = exits, exitByMaxStep = exitMax,
		guideDwell = dwell, intro = prefixed(c, "intro."), economy = economy, rolls = rolls, camps = camps,
		features = features, robux = robux, platforms = platforms, screens = prefixed(c, "client.screen."),
		perf = perf, health = health, loop = prefixed(c, "loop."),
	}
	summary.flags = Report.Flags(summary)
	return summary
end

-- Heuristic red flags for agents. Thresholds are starting points, not Roblox
-- benchmarks; each flag names the numbers it used so they can be re-judged.
function Report.Flags(s: any)
	local flags = {}
	local function flag(severity: string, area: string, text: string) table.insert(flags, {severity = severity, area = area, text = text}) end
	local joined = s.onboardingFunnel[1] and s.onboardingFunnel[1].reached or 0
	if joined >= 20 then
		for i = 2, #s.onboardingFunnel do
			local row = s.onboardingFunnel[i]
			if row.ofPrevious and row.ofPrevious < 80 and i <= 9 then
				flag("high", "onboarding", row.step .. " keeps only " .. row.ofPrevious .. "% of the previous step (" .. row.reached .. " players).")
			elseif row.ofPrevious and row.ofPrevious < 60 then
				flag("medium", "onboarding", row.step .. " keeps " .. row.ofPrevious .. "% of the previous step.")
			end
		end
	end
	local exitTotal = 0
	for _, e in s.onboardingExits do exitTotal += e.n end
	if exitTotal >= 20 and s.onboardingExits[1] and s.onboardingExits[1].n / exitTotal >= 0.3 then
		flag("high", "onboarding", "Guide step '" .. s.onboardingExits[1].guideStep .. "' is where " ..
			math.floor(s.onboardingExits[1].n / exitTotal * 100) .. "% of onboarding exits happen.")
	end
	for _, cohort in s.cohorts do
		local d1 = cohort.retention.d1
		if cohort.size >= 50 and d1 and d1.pct and d1.pct < 15 then
			flag("high", "retention", "Cohort " .. cohort.cohort .. " D1 is " .. d1.pct .. "% (size " .. cohort.size .. ").")
		end
	end
	if s.rolls.count >= 100 and s.rolls.anyAffordablePct and s.rolls.anyAffordablePct < 40 then
		flag("medium", "rolls", "Only " .. s.rolls.anyAffordablePct .. "% of rolls offer anything affordable.")
	end
	local sessions = s.totals.sessions
	if sessions >= 20 then
		local rate = (s.health.errorsServer + s.health.errorsClient) / sessions
		if rate >= 1 then flag("high", "health", string.format("%.1f script errors per session.", rate)) end
	end
	if (s.health.loadFailures or 0) > 0 then flag("high", "health", s.health.loadFailures .. " profile load failures.") end
	for key, value in s.perf do
		if string.sub(key, 1, 9) == "perf.fps|" and value.n >= 20 and value.p50 and (tonumber(string.match(value.p50, "%d+")) or 60) <= 30 then
			flag("medium", "performance", "Median FPS on " .. string.sub(key, 10) .. " is " .. value.p50 .. ".")
		end
	end
	if (s.health.meta.robloxDropped or 0) > 0 then
		flag("low", "analytics", s.health.meta.robloxDropped .. " Roblox analytics events dropped by the rate limiter.")
	end
	if (s.health.meta.ledgerFlushFail or 0) > 0 then
		flag("low", "analytics", "Ledger flush failures: " .. s.health.meta.ledgerFlushFail .. " (data was requeued).")
	end
	return flags
end

function Report.Summary(options: Options?)
	return Report.Summarize(Report.Pull(options), options)
end

function Report.SummaryJSON(options: Options?): string
	return HttpService:JSONEncode(Report.Summary(options))
end

-- Sampled journeys for one day: onboarding sessions plus ~5% of the rest.
function Report.Journeys(options: {day: string?, env: string?, limit: number?, onlyOnboarding: boolean?, store: any?}?)
	local opts = options or {}
	local ds = store(opts :: any)
	local day = opts.day or Ledger.Today()
	local list, dropped = {}, 0
	for shard = 0, Schema.Shards - 1 do
		waitBudget(Enum.DataStoreRequestType.GetAsync)
		local ok, record = pcall(function() return ds:GetAsync(Schema.JourneyKey(day, shard)) end)
		if ok and type(record) == "table" then
			dropped += record.dropped or 0
			for _, entry in record.list or {} do
				if not opts.onlyOnboarding or (type(entry.stage) == "string" and string.sub(entry.stage, 1, 4) == "Onb:") then
					table.insert(list, entry)
				end
			end
		end
	end
	table.sort(list, function(a, b) return (a.s or 0) < (b.s or 0) end)
	local limit = opts.limit or 100
	while #list > limit do table.remove(list) end
	return {day = day, count = #list, droppedAtWrite = dropped, journeys = list}
end

return Report
