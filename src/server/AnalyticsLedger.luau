--!strict
-- Agent ledger: aggregated analytics in DataStores, separate from player saves.
-- Never gameplay state: a failed read or write only loses analytics, and every
-- DataStore call is pcall'd. Bucket shape (also read by AnalyticsReport):
--   c[name] = number                 counters (sums)
--   h[name][label] = count           histograms, labels from Schema.Bucket
--   m[name] = number                 maxima
--   t[table][key] = count            capped top tables (errors, rejections)
--   x[cohortDay][name] = number      counters attributed to a first-join day
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Schema = require(script.Parent.AnalyticsSchema)

local Ledger = {}
Ledger.__index = Ledger

function Ledger.Today(now: number?): string
	return os.date("!%Y-%m-%d", now or os.time()) :: string
end

-- Whole days between two UTC "YYYY-MM-DD" strings (b - a).
function Ledger.DaysBetween(a: string, b: string): number?
	local function parse(text: string): number?
		local y, m, d = string.match(text, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
		if not y then return nil end
		return os.time({year = tonumber(y) :: number, month = tonumber(m) :: number, day = tonumber(d) :: number, hour = 12})
	end
	local ta, tb = parse(a), parse(b)
	if not ta or not tb then return nil end
	return math.floor((tb - ta) / 86400 + 0.5)
end

function Ledger.NewBucket()
	return {c = {}, h = {}, m = {}, t = {}, x = {}}
end

local function topAdd(tableValue: {[string]: number}, key: string, n: number, cap: number)
	if tableValue[key] ~= nil then tableValue[key] += n; return end
	local count = 0
	for _ in tableValue do count += 1 end
	if count >= cap then
		tableValue["(other)"] = (tableValue["(other)"] or 0) + n
	else
		tableValue[key] = n
	end
end

-- Merges `from` into `into` and returns `into`. Never mutates `from`.
function Ledger.MergeBucket(into: any, from: any, cap: number?)
	local limit = cap or Schema.TopCap
	into.c, into.h, into.m, into.t, into.x = into.c or {}, into.h or {}, into.m or {}, into.t or {}, into.x or {}
	for name, value in from.c or {} do into.c[name] = (into.c[name] or 0) + value end
	for name, buckets in from.h or {} do
		local target = into.h[name] or {}
		into.h[name] = target
		for label, count in buckets do target[label] = (target[label] or 0) + count end
	end
	for name, value in from.m or {} do into.m[name] = math.max(into.m[name] or value, value) end
	for name, entries in from.t or {} do
		local target = into.t[name] or {}
		into.t[name] = target
		for key, count in entries do topAdd(target, key, count, limit) end
	end
	for day, counters in from.x or {} do
		local target = into.x[day] or {}
		into.x[day] = target
		for name, value in counters do target[name] = (target[name] or 0) + value end
	end
	return into
end

type Deps = {store: any?, playerStore: any?, clock: (() -> number)?, shard: number?, version: string?, studio: boolean?}

function Ledger.new(deps: Deps?)
	local options = deps or {} :: Deps
	local studio = if options.studio ~= nil then options.studio else RunService:IsStudio()
	local suffix = if studio then Schema.StudioSuffix else ""
	local store, playerStore = options.store, options.playerStore
	if not store then
		local ok, result = pcall(function() return DataStoreService:GetDataStore(Schema.LedgerStore .. suffix) end)
		store = if ok then result else nil
	end
	if not playerStore then
		local ok, result = pcall(function() return DataStoreService:GetDataStore(Schema.PlayerStore .. suffix) end)
		playerStore = if ok then result else nil
	end
	local shard = options.shard
	if not shard then
		-- Stable per server: the same server always merges into the same key.
		local hash = 0
		for i = 1, #game.JobId do hash = (hash * 31 + string.byte(game.JobId, i)) % 1000003 end
		shard = if #game.JobId > 0 then hash % Schema.Shards else math.random(0, Schema.Shards - 1)
	end
	return setmetatable({
		store = store, playerStore = playerStore, studio = studio,
		clock = options.clock or os.time, shard = shard :: number,
		version = options.version or "unknown",
		pending = {} :: {[string]: {[string]: any}}, journeys = {} :: {[string]: {any}},
		flushing = false, stats = {flushes = 0, failures = 0, journeyFailures = 0},
	}, Ledger)
end

function Ledger:Bucket(day: string?)
	local key = day or Ledger.Today(self.clock())
	local versions = self.pending[key]
	if not versions then versions = {}; self.pending[key] = versions end
	local bucket = versions[self.version]
	if not bucket then bucket = Ledger.NewBucket(); versions[self.version] = bucket end
	return bucket
end

function Ledger:Count(name: string, n: number?)
	local bucket = self:Bucket()
	bucket.c[name] = (bucket.c[name] or 0) + (n or 1)
end

function Ledger:Hist(name: string, kind: string, value: number)
	if type(value) ~= "number" or value ~= value then return end
	local bucket = self:Bucket()
	local target = bucket.h[name]
	if not target then target = {}; bucket.h[name] = target end
	local label = Schema.Bucket(kind, value)
	target[label] = (target[label] or 0) + 1
end

function Ledger:Max(name: string, value: number)
	local bucket = self:Bucket()
	bucket.m[name] = math.max(bucket.m[name] or value, value)
end

function Ledger:Top(tableName: string, key: string, n: number?)
	local bucket = self:Bucket()
	local target = bucket.t[tableName]
	if not target then target = {}; bucket.t[tableName] = target end
	topAdd(target, string.sub(key, 1, Schema.TopKeyLength), n or 1, Schema.TopCap)
end

function Ledger:Cohort(firstDay: string, name: string, n: number?)
	local bucket = self:Bucket()
	local target = bucket.x[firstDay]
	if not target then target = {}; bucket.x[firstDay] = target end
	target[name] = (target[name] or 0) + (n or 1)
end

function Ledger:Journey(record: any)
	local day = Ledger.Today(self.clock())
	local list = self.journeys[day]
	if not list then list = {}; self.journeys[day] = list end
	if #list < Schema.JourneyCapPerKey then table.insert(list, record) end
end

local function pruneDays(map: {[string]: any}, today: string)
	for day in map do
		local age = Ledger.DaysBetween(day, today)
		if age and age > Schema.PendingDayLimit then map[day] = nil end
	end
end

-- Yields. Safe to call concurrently (second caller returns at once).
function Ledger:Flush(): boolean
	if self.flushing or not self.store then return false end
	self.flushing = true
	local pending, journeys = self.pending, self.journeys
	self.pending, self.journeys = {}, {}
	local allOk = true
	for day, versions in pending do
		local ok = pcall(function()
			self.store:UpdateAsync(Schema.DayKey(day, self.shard), function(old)
				local record = if type(old) == "table" then old else {schema = Schema.Version, day = day, v = {}}
				record.v = record.v or {}
				for version, bucket in versions do
					record.v[version] = Ledger.MergeBucket(record.v[version] or Ledger.NewBucket(), bucket)
				end
				record.updated, record.writes = self.clock(), (record.writes or 0) + 1
				return record
			end)
		end)
		if ok then
			self.stats.flushes += 1
		else
			allOk = false
			self.stats.failures += 1
			-- Requeue: merge the unsent day back under anything recorded meanwhile.
			local target = self.pending[day] or {}
			self.pending[day] = target
			for version, bucket in versions do
				target[version] = Ledger.MergeBucket(target[version] or Ledger.NewBucket(), bucket)
			end
		end
	end
	for day, list in journeys do
		if #list == 0 then continue end
		local ok = pcall(function()
			self.store:UpdateAsync(Schema.JourneyKey(day, self.shard), function(old)
				local record = if type(old) == "table" then old else {schema = Schema.Version, day = day, list = {}, dropped = 0}
				record.list = record.list or {}
				for _, entry in list do
					if #record.list < Schema.JourneyCapPerKey then table.insert(record.list, entry)
					else record.dropped = (record.dropped or 0) + 1 end
				end
				return record
			end)
		end)
		if not ok then
			allOk = false
			self.stats.journeyFailures += 1
			local target = self.journeys[day] or {}
			self.journeys[day] = target
			for _, entry in list do
				if #target < Schema.JourneyCapPerKey then table.insert(target, entry) end
			end
		end
	end
	if not allOk then
		self:Count("analytics.ledgerFlushFail")
		local today = Ledger.Today(self.clock())
		pruneDays(self.pending, today)
		pruneDays(self.journeys, today)
	end
	self.flushing = false
	return allOk
end

-- Yields. Returns (true, profile|nil) or (false, nil) when the store is unreachable.
function Ledger:LoadProfile(userId: number): (boolean, any)
	if not self.playerStore then return false, nil end
	for attempt = 1, 2 do
		local ok, value = pcall(function() return self.playerStore:GetAsync(Schema.PlayerKey(userId)) end)
		if ok then return true, if type(value) == "table" then value else nil end
		if attempt < 2 then task.wait(1) end
	end
	return false, nil
end

-- Yields. `merge(old, ours)` resolves a concurrent write (another server's copy).
function Ledger:SaveProfile(userId: number, profile: any, merge: (any, any) -> any): boolean
	if not self.playerStore then return false end
	local ok = pcall(function()
		self.playerStore:UpdateAsync(Schema.PlayerKey(userId), function(old)
			if type(old) ~= "table" then return profile end
			return merge(old, profile)
		end)
	end)
	return ok
end

return Ledger
