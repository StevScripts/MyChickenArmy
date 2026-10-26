--!strict
-- Agent-facing reader for the analytics ledger and player profiles. Read-only
-- except for rollup caches (r/<day>) of finished days. Run from Studio Edit through the Studio
-- MCP; see docs/analytics/AGENT_GUIDE.md for the exact snippet and meanings.
-- Usage: Report.Summary({days = 7, env = "live"}) -> summary table
--        Report.SummaryJSON(...) -> string; Report.Journeys({day = "YYYY-MM-DD"})
--        Report.Players({env = "live", limit = 200, sortBy = "robux"}) / PlayersJSON(...)
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

-- Labels are "le<edge>" / "gt<last edge>"; bigCash edges print as "1e+06".
local function edge(label: string): number
	local kind, number = string.match(label, "^(%a%a)(.+)$")
	local value = if kind then tonumber(number) else nil
	if not value then return math.huge end
	return if kind == "gt" then value + 0.5 else value
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

-- Version 5 sections (docs/analytics/TRACKING_PLAN.md) -------------------------------

local function keysOf(map: {[string]: any}): {string}
	local list = {}
	for key in map do table.insert(list, key) end
	table.sort(list)
	return list
end

-- Feature funnels: per step sessions/players, adjacent player conversion, time to
-- convert, where sessions stalled, plus the cohort view for tracked players.
local function featureFunnels(c: {[string]: number}, h: {[string]: any}, x: {[string]: {[string]: number}})
	local list = {}
	for _, funnel in Schema.FeatureFunnels do
		local base = "fun." .. funnel.id
		local steps, previous, worst = {}, nil :: number?, nil :: any
		for index, step in funnel.steps do
			local nn = Schema.StepCode(index)
			local players = c[base .. ".p." .. nn] or 0
			local times = h[base .. ".t." .. nn]
			local p50, n = Report.Percentile(times, 0.5)
			local p90 = Report.Percentile(times, 0.9)
			local row = {id = step.id, nn = nn, sessions = c[base .. ".s." .. nn] or 0, players = players,
				conversionFromPrev = pct(players, previous), timeP50 = p50, timeP90 = p90, timeN = n,
				lastStepSessions = c[base .. ".last." .. nn] or 0}
			local from = previous or 0
			if from >= 20 and row.conversionFromPrev and (worst == nil or row.conversionFromPrev < worst.conversion) then
				worst = {id = step.id, nn = nn, conversion = row.conversionFromPrev, fromPlayers = from, players = players}
			end
			table.insert(steps, row)
			previous = players
		end
		local cohorts = {}
		for day, counters in x do
			local stepCounts, found = {}, false
			for index in funnel.steps do
				local n = counters[base .. "." .. Schema.StepCode(index)]
				if n then stepCounts[Schema.StepCode(index)] = n; found = true end
			end
			if found then table.insert(cohorts, {cohort = day, size = counters["cohort.size"] or 0, steps = stepCounts}) end
		end
		table.sort(cohorts, function(a, b) return a.cohort < b.cohort end)
		table.insert(list, {funnel = funnel.id, started = steps[1] and steps[1].players or 0, steps = steps,
			worstStep = worst, cohorts = cohorts})
	end
	return list
end

-- Playtime funnel (version 6): sessions still in the game at each checkpoint, share
-- of all joins, step-to-step retention and sessions whose last checkpoint was this
-- one. biggestDrop = checkpoint with the most sessions ending right after it.
local function playtimeSection(c: {[string]: number})
	local started = c["play.start"] or 0
	local steps, previous, biggest = {}, started, nil :: any
	for index, checkpoint in Schema.Playtime do
		local nn = Schema.PlaytimeCode(index)
		local sessions = c["play.s." .. nn] or 0
		local endedHere = c["play.last." .. nn] or 0
		table.insert(steps, {label = checkpoint.label, seconds = checkpoint.seconds, sessions = sessions,
			ofStarted = pct(sessions, started), fromPrev = pct(sessions, previous), endedHere = endedHere})
		if endedHere > 0 and (biggest == nil or endedHere > biggest.endedHere) then
			biggest = {label = checkpoint.label, endedHere = endedHere}
		end
		previous = sessions
	end
	return {started = started, endedBeforeFirst = c["play.last." .. Schema.PlaytimeCode(0)] or 0,
		steps = steps, biggestDrop = biggest}
end

-- Version 15 Onboarding funnel (Schema.Onboarding; docs/analytics/ONBOARDING_FUNNEL.md):
-- per step the players who reached it, the share of Joined and of the step before,
-- sessions that ended with it as the furthest step, and the median play seconds to it.
-- biggestDrop is the adjacent pair that lost the most players: where players leave.
local function onboardingSection(c: {[string]: number}, h: {[string]: any})
	local joined = c["ob.reach.01"] or 0
	local exitsNone = c["ob.exit.00"] or 0
	local steps, previous, biggest, exitsTotal = {}, nil :: number?, nil :: any, exitsNone
	for index, step in Schema.Onboarding do
		local nn = Schema.StepCode(index)
		local reached = c["ob.reach." .. nn] or 0
		local exits = c["ob.exit." .. nn] or 0
		local p50, n = Report.Percentile(h["ob.t." .. nn], 0.5)
		local row = {step = Schema.OnboardingName(index), id = step.id, reached = reached,
			ofJoined = pct(reached, joined), ofPrevious = pct(reached, previous), exitsHere = exits, p50 = p50, n = n}
		table.insert(steps, row)
		exitsTotal += exits
		if previous and previous > 0 then
			local lost = previous - reached
			if lost > 0 and (biggest == nil or lost > biggest.lost) then
				local before = steps[index - 1]
				biggest = {from = before.step, to = row.step, lost = lost, fromPlayers = previous,
					pct = pct(lost, previous), exitsAtFrom = before.exitsHere}
			end
		end
		previous = reached
	end
	return {joined = joined, steps = steps, exitsNone = exitsNone, exitsTotal = exitsTotal, biggestDrop = biggest}
end

local function uiSection(c: {[string]: number}, h: {[string]: any}, t: {[string]: any})
	local menus, seen = {}, {}
	for name in prefixed(c, "ui.menu.open.") do seen[name] = true end
	for name in prefixed(h, "ui.menu.dwell.") do seen[name] = true end
	for name in prefixed(c, "ui.menu.blocked.") do seen[name] = true end
	for menu in seen do
		local dwell = h["ui.menu.dwell." .. menu]
		local p50, n = Report.Percentile(dwell, 0.5)
		table.insert(menus, {menu = menu, opens = c["ui.menu.open." .. menu] or 0, blocked = c["ui.menu.blocked." .. menu] or 0,
			dwellP50 = p50, dwellP90 = Report.Percentile(dwell, 0.9), dwellN = n})
	end
	table.sort(menus, function(a, b) return a.opens > b.opens end)
	local loadPhases = {}
	for phase, hist in prefixed(h, "ui.load.") do loadPhases[phase] = stat(hist) end
	local bought, cancel = c["ui.prompt.bought"] or 0, c["ui.prompt.cancel"] or 0
	return {
		menus = menus, clicks = c["ui.click"] or 0, topClicks = sortedTop(t["ui.click"], 30),
		tabs = sortedTop(t["ui.tab"], 30), inspects = sortedTop(t["ui.inspect"], 30),
		prompts = {shown = c["ui.prompt.shown"] or 0, bought = bought, cancel = cancel,
			cancelRate = pct(cancel, bought + cancel), byResult = sortedTop(t["ui.prompt.result"], 30),
			byKey = sortedTop(t["ui.prompt.shown"], 30)},
		idle = (function()
			local s = stat(h["ui.idle.seconds"])
			return {n = c["ui.idle.n"] or 0, p50 = s.p50, p90 = s.p90, ended = s.n}
		end)(),
		settings = sortedTop(t["ui.setting"], 30),
		hints = {shown = sortedTop(t["ui.hint.shown"], 30), closed = sortedTop(t["ui.hint.closed"], 30)},
		loadPhases = loadPhases, leaderboards = sortedTop(t["ui.leaderboard.view"], 10),
		cameraZoom = c["ui.camera.zoom"] or 0, chatSent = c["ui.chat.sent"] or 0, emotes = c["ui.emote"] or 0,
		events = {dropped = c["ui.events.dropped"] or 0, rateLimited = c["ui.events.rateLimited"] or 0},
	}
end

-- Payers are counted once, at a player's first purchase, so a range's payers are
-- its NEW payers while revenue includes repeat buyers: ARPPU runs high on short ranges.
local function segmentRow(label: string, sessions: number, payers: number, revenue: number)
	return {segment = label, sessions = sessions, payers = payers, revenue = revenue,
		arppu = if payers > 0 then math.floor(revenue / payers * 10 + 0.5) / 10 else nil,
		payersPerSessionPct = pct(payers, sessions)}
end

local function devicesSection(c: {[string]: number}, h: {[string]: any}, t: {[string]: any})
	local tiers = {}
	for _, tier in Schema.DeviceTiers do tiers[tier] = true end
	for tier in prefixed(c, "seg.session.tier.") do tiers[tier] = true end
	for tier in prefixed(c, "robux.payer.tier.") do tiers[tier] = true end
	local byTier, fpsByTier, payersTotal = {}, {}, 0
	for _, tier in keysOf(tiers) do
		local payers = c["robux.payer.tier." .. tier] or 0
		payersTotal += payers
		table.insert(byTier, segmentRow(tier, c["seg.session.tier." .. tier] or 0, payers, c["robux.actual.tier." .. tier] or 0))
		if h["perf.fps.tier." .. tier] then fpsByTier[tier] = stat(h["perf.fps.tier." .. tier]) end
	end
	local platforms = {}
	for platform in Schema.Platforms do platforms[platform] = true end
	local byPlatform, platformPayers = {}, 0
	for _, platform in keysOf(platforms) do
		local payers = c["robux.payer|" .. platform] or 0
		platformPayers += payers
		local row = segmentRow(platform, c["session.count|" .. platform] or 0, payers, c["robux.actual|" .. platform] or 0)
		if row.sessions > 0 or row.payers > 0 or row.revenue > 0 then table.insert(byPlatform, row) end
	end
	local byPremium = {}
	for _, premium in {"yes", "no"} do
		table.insert(byPremium, {segment = premium, sessions = c["seg.session.premium." .. premium] or 0,
			revenue = c["robux.actual.premium." .. premium] or 0})
	end
	local payers = if payersTotal > 0 then payersTotal else platformPayers
	return {
		sessionsByTier = prefixed(c, "seg.session.tier."), firstReportByTier = prefixed(c, "client.tier."),
		byTier = byTier, byPlatform = byPlatform, byPremium = byPremium, fpsByTier = fpsByTier,
		viewports = sortedTop(t["client.viewport"], 30), locales = sortedTop(t["client.locale"], 30),
		payersByGeo = sortedTop(t["robux.payer.geo"], 30),
		quality = prefixed(c, "client.quality."), inset = prefixed(c, "client.inset."),
		newPayers = payers, payerRate = pct(payers, c["players.unique"]),
		note = "Tier is a proxy (viewport, memory, FPS, graphics quality); Roblox exposes no device model.",
	}
end

local function robuxActualSection(c: {[string]: number}, h: {[string]: any}, payers: number)
	local byKey, byKind = {}, {}
	for name, amount in prefixed(c, "robux.actual.") do
		if name == "n" or string.sub(name, 1, 5) == "tier." or string.sub(name, 1, 8) == "premium." then continue end
		table.insert(byKey, {key = name, robux = amount})
		local kind = string.match(name, "^([^%.]+)%.") or name
		byKind[kind] = (byKind[kind] or 0) + amount
	end
	table.sort(byKey, function(a, b) return a.robux > b.robux end)
	local total = c["robux.actual"] or 0
	return {total = total, purchases = c["robux.actual.n"] or 0, byKey = byKey, byKind = byKind,
		purchaseSize = stat(h["robux.purchase"]), purchaseSizeHist = h["robux.purchase"] or {},
		newPayers = payers, arppu = if payers > 0 then math.floor(total / payers * 10 + 0.5) / 10 else nil,
		estimate = c["robux.estimate"] or 0, estimatePurchases = c["robux.purchases"] or 0}
end

local function segmentsSection(c: {[string]: number}, h: {[string]: any}, t: {[string]: any})
	-- Every seg.<group>.<value> counter, so names added later still show up.
	local groups: {[string]: {[string]: number}} = {}
	for name, n in prefixed(c, "seg.") do
		local group, value = string.match(name, "^([^%.]+)%.(.+)$")
		if group and value then
			local target = groups[group] or {}
			groups[group] = target
			target[value] = (target[value] or 0) + n
		end
	end
	local active, idle = c["session.activeSeconds"] or 0, c["session.idleSeconds"] or 0
	local friends = h["seg.friendsInServer"] or h["session.friendsInServer"]
	local joinSource = groups.joinSource or groups.join or {}
	return {
		geo = if t["seg.geo"] then sortedTop(t["seg.geo"], 30) else sortedTop(groups.geo, 30),
		accountAge = groups.age or {}, premium = prefixed(c, "seg.session.premium."), joinSource = joinSource,
		hourUTC = h["session.hourUTC"] or {}, weekday = prefixed(c, "session.weekday."),
		serverSize = stat(h["seg.serverSize"]), serverSizeHist = h["seg.serverSize"] or {},
		friendsInServer = stat(friends), friendsInServerHist = friends or {},
		payerSessions = prefixed(c, "seg.payer.session."),
		activeShare = stat(h["session.activeShare"]), activeShareHist = h["session.activeShare"] or {},
		activeSeconds = active, idleSeconds = idle, activePct = pct(active, active + idle),
		all = groups,
	}
end

local function stateSection(h: {[string]: any})
	local out = {}
	for _, name in keysOf(Schema.StateSnapshot) do
		local hist = h["state." .. name]
		local s = stat(hist)
		table.insert(out, {name = name, kind = Schema.StateSnapshot[name], p50 = s.p50, p90 = s.p90, n = s.n, hist = hist or {}})
	end
	return out
end

-- sev.<name>[.<detail>] grouped by Schema.ServerEvents name (names contain dots,
-- so the longest known name wins); value hists sev.<name>.v live in h.
local function serverEventsSection(c: {[string]: number}, h: {[string]: any})
	local names = keysOf(Schema.ServerEvents)
	table.sort(names, function(a, b) return #a > #b end)
	local out: {[string]: any} = {}
	local function split(rest: string): (string, string?)
		for _, name in names do
			if rest == name then return name, nil end
			if string.sub(rest, 1, #name + 1) == name .. "." then return name, string.sub(rest, #name + 2) end
		end
		local event, detail = string.match(rest, "^([^%.]+)%.(.+)$")
		if event then return event, detail end
		return rest, nil
	end
	local function group(event: string)
		local entry = out[event]
		if not entry then entry = {count = 0, details = {} :: {[string]: number}}; out[event] = entry end
		return entry
	end
	for rest, n in prefixed(c, "sev.") do
		local event, detail = split(rest)
		local entry = group(event)
		if detail then entry.details[detail] = (entry.details[detail] or 0) + n else entry.count += n end
	end
	for rest, hist in prefixed(h, "sev.") do
		if string.sub(rest, -2) == ".v" then group(string.sub(rest, 1, -3)).value = stat(hist) end
	end
	return out
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

	-- Version 15 Onboarding funnel (the schema 11-14 tf.* and older onb.* keys of
	-- earlier days are not read).
	local onboarding = onboardingSection(c, h)

	-- Cohorts: x[firstDay] merged across every pulled day (returns land later).
	local cohorts = {}
	for day, counters in total.x do
		local size = counters["cohort.size"] or 0
		local row = {cohort = day, size = size, retention = {}, payers = counters["robux.payer"] or 0,
			anyLater = counters["ret.anyLater"] or 0, anyLaterPct = pct(counters["ret.anyLater"], size)}
		for _, d in Schema.RetentionDays do
			local n = counters["ret.d" .. d]
			if n then row.retention["d" .. d] = {n = n, pct = pct(n, size)} end
		end
		table.insert(cohorts, row)
	end
	table.sort(cohorts, function(a, b) return a.cohort < b.cohort end)

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
		meta = prefixed(c, "analytics."), funnelUnknown = c["fun.unknown"] or 0,
	}

	local sessions = c["session.count"] or 0
	local devices = devicesSection(c, h, total.t)
	local summary = {
		schema = Schema.Version, range = {from = dayNames[1], to = dayNames[#dayNames], days = #dayNames},
		versions = (function() local list = {} for v in perVersion do table.insert(list, v) end table.sort(list) return list end)(),
		totals = {unique = c["players.unique"] or 0, new = c["players.new"] or 0, preexisting = c["players.preexisting"] or 0,
			joins = c["players.join"] or 0, tracked = c["players.join.tracked"] or 0, sessions = sessions,
			avgSessionSec = if sessions > 0 then math.floor((c["session.seconds"] or 0) / sessions) else nil,
			session = stat(h["session.seconds"]), sessionNew = stat(h["session.seconds.new"]),
			sessionReturning = stat(h["session.seconds.returning"]), playerMinutes = c["player.minutes"] or 0,
			serverMinutes = c["server.minutes"] or 0},
		daily = daily, onboarding = onboarding, cohorts = cohorts,
		guideDwell = dwell, intro = prefixed(c, "intro."), economy = economy, rolls = rolls, camps = camps,
		features = features, robux = robux, platforms = platforms, screens = prefixed(c, "client.screen."),
		perf = perf, health = health, loop = prefixed(c, "loop."),
		-- Version 5 sections.
		featureFunnels = featureFunnels(c, h, total.x), ui = uiSection(c, h, total.t),
		segments = segmentsSection(c, h, total.t), stateSnapshots = stateSection(h),
		serverEvents = serverEventsSection(c, h), playtime = playtimeSection(c),
		exits = {menu = sortedTop(total.t["exit.menu"], 30), action = sortedTop(total.t["exit.action"], 30)},
		devices = devices, robuxActual = robuxActualSection(c, h, devices.newPayers),
	}
	summary.flags = Report.Flags(summary)
	return summary
end

-- Heuristic red flags for agents. Thresholds are starting points, not Roblox
-- benchmarks; each flag names the numbers it used so they can be re-judged.
function Report.Flags(s: any)
	local flags = {}
	local function flag(severity: string, area: string, text: string) table.insert(flags, {severity = severity, area = area, text = text}) end
	-- Onboarding: the one place players leave most (the adjacent pair losing the most
	-- players, with the sessions that ended there). Needs 20+ joined to mean anything.
	local onboarding = s.onboarding
	local drop = onboarding and onboarding.biggestDrop
	if onboarding and onboarding.joined >= 20 and drop then
		flag(if (drop.pct or 0) >= 20 then "high" else "medium", "onboarding",
			string.format("Biggest onboarding drop: %s -> %s loses %d of %d players (%s%%); %d sessions ended at %s.",
				drop.from, drop.to, drop.lost, drop.fromPlayers, tostring(drop.pct), drop.exitsAtFrom, drop.from))
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

	-- Version 5 heuristics.
	for _, funnel in s.featureFunnels or {} do
		for i = 2, #funnel.steps do
			local row, prev = funnel.steps[i], funnel.steps[i - 1]
			if prev.players >= 30 and row.conversionFromPrev and row.conversionFromPrev < 50 then
				-- Milestone steps (10 buys, Rebirth 5 ...) sit late in a funnel and are expected to be low.
				flag(if i <= 3 then "medium" else "low", "funnel", funnel.funnel .. ": " .. prev.id .. " -> " .. row.id .. " keeps "
					.. row.conversionFromPrev .. "% (" .. row.players .. " of " .. prev.players .. " players).")
			end
		end
	end
	local prompts = s.ui and s.ui.prompts
	if prompts and prompts.bought + prompts.cancel >= 20 and prompts.cancelRate and prompts.cancelRate > 70 then
		flag("medium", "monetization", "Purchase prompts are cancelled " .. prompts.cancelRate .. "% of the time ("
			.. prompts.cancel .. " of " .. (prompts.bought + prompts.cancel) .. ").")
	end
	for tier, value in (s.devices and s.devices.fpsByTier) or {} do
		if value.n >= 20 and value.p50 and (tonumber(string.match(value.p50, "%d+")) or 60) <= 30 then
			flag("medium", "performance", "Median FPS on " .. tier .. "-tier devices is " .. value.p50 .. ".")
		end
	end
	local pipeline = {}
	for _, name in {"funnelError", "partError", "playerError"} do
		local n = s.health.meta[name] or 0
		if n > 0 then table.insert(pipeline, "analytics." .. name .. " " .. n) end
	end
	if (s.health.funnelUnknown or 0) > 0 then table.insert(pipeline, "fun.unknown " .. s.health.funnelUnknown) end
	local unknownSev = s.serverEvents and s.serverEvents.unknown
	if unknownSev and unknownSev.count > 0 then table.insert(pipeline, "sev.unknown " .. unknownSev.count) end
	if #pipeline > 0 then flag("low", "analytics", "Analytics pipeline errors (numbers may be low): " .. table.concat(pipeline, ", ") .. ".") end
	local saveFail = s.serverEvents and s.serverEvents["data.saveFail"]
	if saveFail then
		local n = saveFail.count
		for _, d in saveFail.details do n = math.max(n, d) end
		if n > 0 then flag("high", "health", n .. " game save failures (sev.data.saveFail).") end
	end
	if s.ui then
		local dropped = s.ui.events.dropped + s.ui.events.rateLimited
		local accepted = s.ui.clicks + s.ui.prompts.shown
		for _, menu in s.ui.menus do accepted += menu.opens end
		if dropped >= 50 and dropped / (dropped + accepted) >= 0.1 then
			flag("low", "analytics", string.format("%d client UI events dropped or rate-limited (~%d%% of UI events).",
				dropped, math.floor(dropped / (dropped + accepted) * 100)))
		end
		local sessions = s.totals.sessions
		for _, menu in s.ui.menus do
			-- Seconds buckets start at 5, so "le5" is the finest median (<= 5 s, not < 3 s).
			if menu.opens >= 50 and menu.opens >= sessions * 0.5 and menu.dwellP50 == "le5" then
				flag("low", "ui", "Menu " .. menu.menu .. " is opened " .. menu.opens .. " times with median dwell <= 5 s "
					.. "(accidental or confusing opens?).")
			end
		end
	end
	return flags
end

function Report.Summary(options: Options?)
	return Report.Summarize(Report.Pull(options), options)
end

function Report.SummaryJSON(options: Options?): string
	return HttpService:JSONEncode(Report.Summary(options))
end

-- The onboarding funnel as compact text: one line per step (reached, % of joined,
-- % of the step before, sessions that ended there, median seconds to it) and the
-- biggest drop. Pass a summary, or options for Report.Summary.
function Report.OnboardingText(summaryOrOptions: any?): string
	local summary = if type(summaryOrOptions) == "table" and summaryOrOptions.onboarding then summaryOrOptions
		else Report.Summary(summaryOrOptions)
	local ob, range = summary.onboarding, summary.range or {}
	local lines = {string.format("Onboarding %s..%s  %d joined  (schema %s)", tostring(range.from), tostring(range.to),
		ob.joined, tostring(summary.schema))}
	table.insert(lines, string.format("%-40s %7s %6s %6s %6s %8s", "step", "reached", "%join", "%prev", "exits", "p50s"))
	for _, row in ob.steps do
		table.insert(lines, string.format("%-40s %7d %6s %6s %6d %8s", row.step, row.reached,
			if row.ofJoined then tostring(row.ofJoined) else "-", if row.ofPrevious then tostring(row.ofPrevious) else "-",
			row.exitsHere, row.p50 or "-"))
	end
	if ob.exitsNone > 0 then table.insert(lines, ob.exitsNone .. " sessions ended before any step") end
	local drop = ob.biggestDrop
	if drop then
		table.insert(lines, string.format("Biggest drop: %s -> %s: %d of %d lost (%s%%), %d sessions ended there",
			drop.from, drop.to, drop.lost, drop.fromPlayers, tostring(drop.pct), drop.exitsAtFrom))
	end
	return table.concat(lines, "\n")
end

-- Sampled journeys for one day: onboarding sessions plus ~5% of the rest.
-- onlyOnboarding keeps the onboarding ones (stage "Ob:<step>"; "Tut:" in schema 11-14
-- days, "Onb:" before version 12).
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
				local stage = if type(entry.stage) == "string" then entry.stage else ""
				local prefix = string.sub(stage, 1, 4)
				if not opts.onlyOnboarding or string.sub(stage, 1, 3) == "Ob:" or prefix == "Tut:" or prefix == "Onb:" then
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

-- Players ------------------------------------------------------------------------

type PlayerOptions = {env: string?, limit: number?, scan: number?, minRobux: number?, sortBy: string?, store: any?}

local function spend(row: any): number
	return math.max(row.robuxActual or 0, row.robux or 0)
end

-- Furthest Onboarding funnel step in a profile's ob record (nil if it has none).
local function onboardingMax(ob: any): number?
	if type(ob) ~= "table" then return nil end
	local furthest = 0
	for code in ob do furthest = math.max(furthest, tonumber(code) or 0) end
	return furthest
end

-- One profile (`p/<userId>`) as a flat row. Profiles from before version 5 have
-- no dev/geo/robuxActual fields; those stay nil (robuxActual 0). `robux` is the
-- launch-price estimate: the larger of the v1 `robux` and the v5 `robuxEstimate`.
function Report.PlayerRow(key: string, profile: any)
	local dev = if type(profile.dev) == "table" then profile.dev else {}
	return {userId = tonumber(string.match(key, "^p/(%d+)$")), first = profile.first, lastSeen = profile.lastSeen,
		days = profile.days, sessions = profile.sessions or 0, play = profile.play or 0, active = profile.active,
		idle = profile.idle, robux = math.max(tonumber(profile.robux) or 0, tonumber(profile.robuxEstimate) or 0),
		robuxActual = tonumber(profile.robuxActual) or 0, purchases = tonumber(profile.purchases) or 0,
		lastPurchase = profile.lastPurchase, firstPurchaseDevice = profile.firstPurchaseDevice,
		platform = dev.platform, tier = dev.tier, os = dev.os, input = dev.input, geo = profile.geo,
		premium = profile.premium, age = profile.age, joinSource = profile.joinSource,
		friendsInServer = profile.friendsInServer, rebirths = profile.rebirths, onboardingMax = onboardingMax(profile.ob),
		lastExit = profile.lastExit, snap = profile.snap, life = profile.life, funN = profile.funN}
end

-- Lists analytics player profiles. Reads up to `scan` keys (default `limit`) in key
-- order, then sorts by `sortBy` ("robux" default, "play", "lastSeen") and returns the
-- first `limit` rows; totals cover every scanned profile that passed `minRobux`
-- (compared with the larger of robuxActual and the launch-price estimate).
-- Each profile costs one GetAsync (~60/min in Studio Edit), so keep `scan` modest.
function Report.Players(options: PlayerOptions?)
	local opts = options or {} :: PlayerOptions
	local limit = math.clamp(math.floor(opts.limit or 200), 1, 5000)
	local scan = math.clamp(math.floor(opts.scan or limit), limit, 20000)
	local sortBy = opts.sortBy or "robux"
	local real = opts.store == nil
	local ds = opts.store or DataStoreService:GetDataStore(Schema.PlayerStore .. (if opts.env == "studio" then Schema.StudioSuffix else ""))
	local function budget(kind: Enum.DataStoreRequestType) if real then waitBudget(kind) end end

	local keys, listError, complete = {}, nil :: string?, false
	budget(Enum.DataStoreRequestType.ListAsync)
	local ok, pages = pcall(function() return ds:ListKeysAsync("p/", math.min(scan, 50)) end)
	if not ok then
		listError = tostring(pages)
	else
		while true do
			local okPage, page = pcall(function() return pages:GetCurrentPage() end)
			if not okPage then listError = tostring(page); break end
			local truncated = false
			for _, entry in page do
				if #keys >= scan then truncated = true; break end
				table.insert(keys, entry.KeyName)
			end
			if pages.IsFinished then complete = not truncated; break end
			if #keys >= scan then break end
			budget(Enum.DataStoreRequestType.ListAsync)
			local advanced, why = pcall(function() pages:AdvanceToNextPageAsync() end)
			if not advanced then listError = tostring(why); break end
		end
	end

	local rows, readFailures = {}, 0
	local totals = {players = 0, payers = 0, revenue = 0, revenueEstimate = 0, play = 0,
		payerRate = nil :: number?, arppu = nil :: number?, byTier = {} :: {[string]: any}, byPlatform = {} :: {[string]: any}, byGeo = {} :: {[string]: any}}
	local function add(map: {[string]: any}, key: string, row: any)
		local entry = map[key]
		if not entry then entry = {players = 0, payers = 0, revenue = 0, play = 0}; map[key] = entry end
		entry.players += 1
		entry.play += row.play
		entry.revenue += row.robuxActual
		if row.purchases > 0 or row.robuxActual > 0 then entry.payers += 1 end
	end
	for _, key in keys do
		budget(Enum.DataStoreRequestType.GetAsync)
		local okGet, profile = pcall(function() return ds:GetAsync(key) end)
		if not okGet or type(profile) ~= "table" then readFailures += 1; continue end
		local row = Report.PlayerRow(key, profile)
		if opts.minRobux and spend(row) < opts.minRobux then continue end
		table.insert(rows, row)
		totals.players += 1
		totals.play += row.play
		totals.revenue += row.robuxActual
		totals.revenueEstimate += row.robux
		if row.purchases > 0 or row.robuxActual > 0 then totals.payers += 1 end
		add(totals.byTier, tostring(row.tier or "Unknown"), row)
		add(totals.byPlatform, tostring(row.platform or "Unknown"), row)
		add(totals.byGeo, tostring(row.geo or "Unknown"), row)
	end
	local sorters = {
		robux = function(a, b) if spend(a) ~= spend(b) then return spend(a) > spend(b) end return a.play > b.play end,
		play = function(a, b) return a.play > b.play end,
		lastSeen = function(a, b) return (a.lastSeen or 0) > (b.lastSeen or 0) end,
	}
	table.sort(rows, sorters[sortBy] or sorters.robux)
	while #rows > limit do table.remove(rows) end
	totals.payerRate = pct(totals.payers, totals.players)
	totals.arppu = if totals.payers > 0 then math.floor(totals.revenue / totals.payers * 10 + 0.5) / 10 else nil
	return {env = opts.env or "live", sortBy = sortBy, scanned = #keys, listComplete = complete, listError = listError,
		readFailures = readFailures, count = #rows, totals = totals, players = rows}
end

function Report.PlayersJSON(options: PlayerOptions?): string
	return HttpService:JSONEncode(Report.Players(options))
end

return Report
