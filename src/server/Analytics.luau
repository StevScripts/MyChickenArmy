--!strict
-- Observation only: never changes gameplay, never blocks a request, never trusts
-- the client for anything but its own device stats. Two outputs:
--   1. Roblox AnalyticsService (Creator Dashboard), rate-limited, live servers only.
--   2. AnalyticsLedger (DataStores) for agents. Names: AnalyticsSchema.
-- Agents: docs/analytics/AGENT_GUIDE.md explains every ledger name.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AnalyticsService = game:GetService("AnalyticsService")
local ScriptContext = game:GetService("ScriptContext")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.PetCatalog)
local ShopCatalog = require(Shared.ShopCatalog)
local Guide = require(Shared.TutorialGuide)
local Schema = require(script.Parent.AnalyticsSchema)
local Ledger = require(script.Parent.AnalyticsLedger)

local Analytics = {}
Analytics.__index = Analytics
-- Studio (and tests) record what would have been sent to Roblox here.
Analytics.Diagnostics = {} :: {any}

local CF1 = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
local CF2 = Enum.AnalyticsCustomFieldKeys.CustomField02.Name
local CF3 = Enum.AnalyticsCustomFieldKeys.CustomField03.Name
local QUEUE_CAP = 400
local REPORT_MIN_SECONDS = 20
local CLIENT_PERF_SECONDS = 300
local OBSERVE_SECONDS = 0.5
local JOURNEY_SAMPLE = 0.05 -- share of post-onboarding sessions kept as journeys

local function fields(a: string?, b: string?, c: string?)
	local result = {}
	if a then result[CF1] = string.sub(a, 1, 50) end
	if b then result[CF2] = string.sub(b, 1, 50) end
	if c then result[CF3] = string.sub(c, 1, 50) end
	return result
end

local function anon(userId: number): string
	-- Stable, non-reversible-at-a-glance id for journeys. Not a security boundary.
	local hash = 2166136261
	for i, byte in {string.byte("mca:" .. userId, 1, -1)} do
		hash = bit32.bxor(hash, byte)
		hash = (hash * 16777619) % 4294967296
	end
	return string.format("%08x", hash)
end

local function finite(value: any, low: number, high: number): number?
	if type(value) ~= "number" or value ~= value then return nil end
	return math.clamp(value, low, high)
end

-- Fresh game save (before the guide ever started) => tracked into onboarding.
function Analytics.FreshSave(session): boolean
	local t = session.tutorial or {}
	if t.starterArmy ~= true or t.guideStarted == true or t.guideCompleted == true or t.rolled or t.bought then return false end
	for _, won in session.firstWins or {} do if won then return false end end
	return session.kingCleared ~= true
end

-- Concurrent-session merge for the per-player profile (keeps the furthest progress).
function Analytics.MergeProfile(old: any, ours: any): any
	local result = table.clone(ours)
	result.sessions = math.max(old.sessions or 0, ours.sessions or 0)
	result.play = math.max(old.play or 0, ours.play or 0)
	result.days = math.max(old.days or 0, ours.days or 0)
	result.purchases = math.max(old.purchases or 0, ours.purchases or 0)
	result.robux = math.max(old.robux or 0, ours.robux or 0)
	result.onbMax = math.max(old.onbMax or 0, ours.onbMax or 0)
	result.rbx = math.max(old.rbx or 0, ours.rbx or 0)
	if old.first and (not ours.first or old.first < ours.first) then
		result.first, result.firstDay, result.firstVersion = old.first, old.firstDay, old.firstVersion
		result.tracked = old.tracked
	end
	for _, name in {"onb", "features", "ret"} do
		local merged = table.clone(ours[name] or {})
		for key, value in old[name] or {} do
			if merged[key] == nil then merged[key] = value
			elseif type(value) == "number" and type(merged[key]) == "number" then merged[key] = math.min(value, merged[key]) end
		end
		result[name] = merged
	end
	if old.firstPurchase and (not ours.firstPurchase or old.firstPurchase < ours.firstPurchase) then
		result.firstPurchase = old.firstPurchase
	end
	return result
end

type Deps = {ledger: any?, tutorial: any?, battles: any?, studio: boolean?, clock: (() -> number)?,
	wall: (() -> number)?, sender: ((string, any) -> ())?, random: (() -> number)?}

function Analytics.new(deps: Deps?)
	local options = deps or {} :: Deps
	local studio = if options.studio ~= nil then options.studio else RunService:IsStudio()
	local self = setmetatable({
		studio = studio,
		ledger = options.ledger or Ledger.new({version = Config.Version, studio = studio}),
		tutorial = options.tutorial, battles = options.battles,
		clock = options.clock or os.clock, wall = options.wall or os.time,
		sender = options.sender, random = options.random or math.random,
		players = {} :: {[number]: any},
		high = {} :: {any}, low = {} :: {any}, tokens = 0,
		frameSum = 0, frameCount = 0, frameMax = 0,
		nextPerf = 0, nextFlush = 0, nextProfiles = 0, nextEconomy = 0,
		productKeys = {} :: {[number]: string}, connections = {} :: {RBXScriptConnection},
		warned = false, destroyed = false, saving = 0,
	}, Analytics)
	local now = self.clock()
	self.nextPerf = now + Schema.PerfSampleSeconds
	self.nextFlush = now + Schema.FlushSeconds * (0.5 + self.random() * 0.5)
	self.nextProfiles = now + Schema.ProfileSaveSeconds
	self.nextEconomy = now + Schema.EconomyFlushSeconds
	-- Studio only: lets an agent inspect or flush the running instance via the MCP.
	if studio and not options.ledger then Analytics.Current = self end
	for _, key in ShopCatalog.ProductOrder do
		local product = ShopCatalog.Products[key]
		if product and product.productId then self.productKeys[product.productId] = key end
	end
	return self
end

function Analytics:Start()
	-- Server script errors (ours only) are a leading cause of silent player loss.
	table.insert(self.connections, ScriptContext.Error:Connect(function(message, _trace, source)
		if self.destroyed then return end
		local name = if typeof(source) == "Instance" then (source :: Instance).Name else "?"
		self.ledger:Count("err.server")
		self.ledger:Top("err.server", name .. ": " .. tostring(message))
	end))
end

-- Roblox sink ---------------------------------------------------------------

function Analytics:_Queue(high: boolean, label: string, call: () -> ())
	if self.sender then self.sender(label, call); return end
	if self.studio then
		table.insert(Analytics.Diagnostics, {label = label, at = self.clock()})
		if #Analytics.Diagnostics > 512 then table.remove(Analytics.Diagnostics, 1) end
		return
	end
	local queue = if high then self.high else self.low
	table.insert(queue, call)
	if #queue > QUEUE_CAP then
		table.remove(queue, 1)
		self.ledger:Count("analytics.robloxDropped")
	end
end

function Analytics:_Pump(dt: number)
	local perMinute = Schema.RobloxLimits.budgetBase + Schema.RobloxLimits.budgetPerPlayer * #Players:GetPlayers()
	self.tokens = math.min(perMinute / 4, self.tokens + perMinute / 60 * dt)
	while self.tokens >= 1 do
		local call = table.remove(self.high, 1) or table.remove(self.low, 1)
		if not call then break end
		self.tokens -= 1
		task.spawn(function()
			local ok, why = pcall(call)
			if not ok then
				self.ledger:Count("analytics.robloxError")
				if not self.warned then self.warned = true; warn("[Analytics] Roblox analytics call failed: " .. tostring(why)) end
			end
		end)
	end
end

-- Shared transport for TutorialService's existing FTUE custom events.
function Analytics:Custom(player: Player, name: string, value: number, customFields: any, high: boolean?)
	self:_Queue(high == true, "custom:" .. name, function()
		AnalyticsService:LogCustomEvent(player, name, value, customFields)
	end)
end

-- Per-player state ------------------------------------------------------------

function Analytics:_State(session): any
	return if session then self.players[session.userId] else nil
end

function Analytics:_Trail(st, code: string)
	if #st.trail < Schema.JourneyEventCap then
		table.insert(st.trail, {math.floor(self.clock() - st.joinedAt), code})
	end
end

function Analytics:_Play(st): number
	local base = if st.profile then st.profile.play or 0 else 0
	return base + (self.clock() - st.joinedAt)
end

function Analytics:_Stage(st): string
	if not st.tracked then return "Untracked" end
	local done = st.profile and st.profile.onb and st.profile.onb[Schema.StepCode(Schema.OnboardingIndex.GuideComplete)]
	if done or st.reachedSession[Schema.OnboardingIndex.GuideComplete] then return "Post" end
	return "Onb:" .. Schema.Onboarding[math.max(1, st.maxStep)].id
end

function Analytics:Join(player: Player, session)
	local now = self.clock()
	local st = {player = player, session = session, userId = session.userId, anon = anon(session.userId),
		joinedAt = now, platform = "Unknown", ready = false, queue = {}, reachedSession = {},
		maxStep = 0, trail = {}, journeySteps = {}, rejects = {}, econ = {}, sessionEarned = 0,
		rolls = 0, buys = 0, rollsSinceBuy = 0, rollFunnels = 0, shopFunnel = {}, errors = 0,
		pingSum = 0, pingN = 0, fpsSum = 0, fpsN = 0, nextClientPerf = 0, lastReport = -math.huge,
		observedAt = -math.huge, sessionIndex = 0}
	self.players[session.userId] = st
	self.ledger:Count("players.joinAttempt")
	self:_Reach(st, Schema.OnboardingIndex.Joined)
end

function Analytics:LoadFailed(session, reason: string?)
	local st = self:_State(session)
	self.ledger:Count("data.loadFail")
	self.ledger:Top("data.loadFail", tostring(reason or "?"))
	if st then st.loadFailed = true end
end

function Analytics:Loaded(session)
	local st = self:_State(session)
	if not st then return end
	st.loadedAt = self.clock()
	self.ledger:Hist("load.serverSeconds", "seconds", st.loadedAt - st.joinedAt)
	local fresh = Analytics.FreshSave(session)
	self:_Reach(st, Schema.OnboardingIndex.ProfileLoaded)
	task.spawn(function()
		local ok, profile = self.ledger:LoadProfile(st.userId)
		if self.players[st.userId] ~= st then return end
		if self.studio and workspace:GetAttribute("PetRollAnalyticsFreshProfile") == true then profile = nil end
		self:_Resolve(st, ok, profile, fresh)
	end)
end

function Analytics:_Resolve(st, ok: boolean, profile: any, fresh: boolean)
	local wall = self.wall()
	local today = Ledger.Today(wall)
	if not ok then
		-- Store unreachable: Roblox funnel still works from the save; no cohort writes.
		self.ledger:Count("analytics.profileLoadFail")
		st.profile, st.tracked = nil, fresh
	elseif profile == nil then
		st.isNew = true
		st.profile = {schema = Schema.Version, first = wall, firstVersion = Config.Version,
			firstDay = if fresh then today else nil, tracked = fresh, preexisting = not fresh,
			lastDay = today, days = 1, sessions = 0, play = 0, onb = {}, onbMax = 0, features = {}, ret = {},
			purchases = 0, robux = 0}
		st.tracked = fresh
		self.ledger:Count("players.unique")
		self.ledger:Count(if fresh then "players.new" else "players.preexisting")
		if fresh then self.ledger:Cohort(today, "cohort.size") end
	else
		st.profile = profile
		profile.onb, profile.features, profile.ret = profile.onb or {}, profile.features or {}, profile.ret or {}
		st.tracked = profile.tracked == true
		if profile.lastDay ~= today then
			profile.lastDay = today
			profile.days = (profile.days or 0) + 1
			self.ledger:Count("players.unique")
			self.ledger:Count("players.uniqueReturning")
			local index = if profile.firstDay then Ledger.DaysBetween(profile.firstDay, today) else nil
			if index and index >= 1 then
				self.ledger:Hist("players.daysSinceFirst", "days", index)
				for _, day in Schema.RetentionDays do
					local key = "ret.d" .. day
					if day == index and not profile.ret[key] then
						profile.ret[key] = true
						self.ledger:Cohort(profile.firstDay, key)
					end
				end
				if not profile.ret.any then profile.ret.any = true; self.ledger:Cohort(profile.firstDay, "ret.anyLater") end
			end
		end
	end
	if st.profile then
		st.profile.sessions = (st.profile.sessions or 0) + 1
		st.sessionIndex = st.profile.sessions
		self.ledger:Hist("players.sessionIndex", "count", st.sessionIndex)
	end
	self.ledger:Count("players.join")
	self.ledger:Count(if st.isNew then "players.join.new" else "players.join.returning")
	if st.tracked then self.ledger:Count("players.join.tracked") end
	st.robloxNext = (if st.profile then st.profile.rbx or 0 else 0) + 1
	st.ready = true
	for _, index in st.queue do self:_Record(st, index) end
	st.queue = {}
	self:_SendOnboarding(st)
end

-- Onboarding -----------------------------------------------------------------

function Analytics:_Reach(st, index: number)
	if st.reachedSession[index] then return end
	st.reachedSession[index] = true
	st.maxStep = math.max(st.maxStep, index)
	local code = Schema.StepCode(index)
	st.journeySteps[code] = math.floor(self.clock() - st.joinedAt)
	self:_Trail(st, "onb:" .. Schema.Onboarding[index].id)
	if st.ready then self:_Record(st, index) else table.insert(st.queue, index) end
end

function Analytics:_Reached(st, index: number): boolean
	if st.reachedSession[index] then return true end
	local profile = st.profile
	return profile ~= nil and profile.onb[Schema.StepCode(index)] ~= nil
end

-- Roblox onboarding steps, strictly in order (see Schema.RobloxGapRelease).
function Analytics:_SendOnboarding(st)
	if not st.tracked or not st.robloxNext then return end
	local total = #Schema.Onboarding
	while st.robloxNext <= total do
		local index = st.robloxNext
		if not self:_Reached(st, index) then
			local later = 0
			for j = index + 1, total do if self:_Reached(st, j) then later += 1 end end
			local needed = if Schema.Onboarding[index].optional then 1 else Schema.RobloxGapRelease
			if later < needed then return end
			self.ledger:Count("onb.robloxGapFill." .. Schema.StepCode(index))
			st.robloxNext += 1
			continue
		end
		local player, name = st.player, Schema.StepName(index)
		self:_Queue(true, "onboarding:" .. name, function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, index, name, fields(Config.Version))
		end)
		st.robloxNext += 1
		if st.profile then st.profile.rbx = math.max(st.profile.rbx or 0, index) end
	end
end

function Analytics:_Record(st, index: number)
	if not st.tracked then return end
	local code = Schema.StepCode(index)
	local profile = st.profile
	if profile and profile.onb[code] then return end -- reached in an earlier session
	if index > 1 and not self:_Reached(st, index - 1) and not Schema.Onboarding[index - 1].optional then
		self.ledger:Count("onb.outOfOrder." .. code)
	end
	local play = self:_Play(st)
	if profile then
		profile.onb[code] = math.floor(play)
		profile.onbMax = math.max(profile.onbMax or 0, index)
		if profile.firstDay then self.ledger:Cohort(profile.firstDay, "onb." .. code) end
	end
	self.ledger:Count("onb.reach." .. code)
	self.ledger:Hist("onb.t." .. code, "seconds", play)
	self.ledger:Hist("onb.session." .. code, "count", math.max(1, st.sessionIndex))
	if st.ready then self:_SendOnboarding(st) end
end

function Analytics:Observe(session, state)
	local st = self:_State(session)
	if not st or not st.ready then return end
	local now = self.clock()
	if now - st.observedAt < OBSERVE_SECONDS then return end
	st.observedAt = now
	-- Guide step dwell, read from TutorialService's resolved step.
	local record = self.tutorial and self.tutorial.records[session.userId]
	local step = record and record.step
	if step ~= st.guideStep then
		if st.guideStep then self.ledger:Hist("guide.dwell." .. st.guideStep, "seconds", now - st.guideStepAt) end
		if step then self.ledger:Count("guide.enter." .. step); self:_Trail(st, "guide:" .. step) end
		st.guideStep, st.guideStepAt = step, now
	end
	if not st.tracked then return end
	local t = session.tutorial or {}
	local I = Schema.OnboardingIndex
	if (tonumber(t.collectedEggCount) or 0) > 0 or Guide.CollectedEggCount(t) > 0 then self:_Reach(st, I.FirstEgg) end
	local facts = Guide.Facts(state)
	for _, id in Guide.Milestones do
		if facts[id] and I[id] then self:_Reach(st, I[id]) end
	end
	if t.guideCompleted then self:_Reach(st, I.GuideComplete) end
	local wins = session.firstWins or {}
	if wins[2] then self:_Reach(st, I.Camp2) end
	if wins[3] then self:_Reach(st, I.Camp3) end
	if session.kingCleared then self:_Reach(st, I.King) end
end

function Analytics:Signal(session, signal: any)
	local st = self:_State(session)
	if not st or type(signal) ~= "string" or #signal > 32 then return end
	local I = Schema.OnboardingIndex
	if signal == "IntroStarted" then
		st.introStarted = true
		self.ledger:Count("intro.started")
		self:_Reach(st, I.IntroStarted)
	elseif signal == "IntroFinished" or signal == "IntroSkipped" then
		if st.introEnded then return end
		st.introEnded = true
		self.ledger:Count(if not st.introStarted then "intro.notShown"
			elseif signal == "IntroSkipped" then "intro.skipped" else "intro.finished")
		self:_Reach(st, I.IntroEnded)
	elseif signal == "Ready" then
		if st.readyAt then return end
		st.readyAt = self.clock()
		self.ledger:Hist("load.readySeconds", "seconds", st.readyAt - st.joinedAt)
		self:_Reach(st, I.ControlReady)
	elseif signal == "Skip" then
		self.ledger:Count("guide.skipped")
		self:_Trail(st, "guideSkip")
	else
		self.ledger:Count("ui." .. signal)
	end
end

-- Actions, economy, rolls ------------------------------------------------------

function Analytics:_Feature(st, action: string)
	local name = Schema.Features[action]
	if not name then return end
	self.ledger:Count("feature.use." .. name)
	local profile = st.profile
	if not profile or profile.features[name] then return end
	local play = math.floor(self:_Play(st))
	profile.features[name] = play
	self.ledger:Count("feature.first." .. name)
	self.ledger:Hist("feature.first." .. name, "seconds", play)
	local player, stage = st.player, self:_Stage(st)
	self:_Queue(false, "custom:FeatureFirstUse", function()
		AnalyticsService:LogCustomEvent(player, "FeatureFirstUse", play, fields(name, stage, Config.Version))
	end)
end

function Analytics:_Sink(st, session, action: string, spent: number, request: any, extra: any)
	local definition = Schema.Sinks[action]
	if not definition then
		self.ledger:Count("econ.sink.Other:" .. action, spent)
		return
	end
	local sku = definition.sku
	if action == "Buy" then
		sku ..= ":" .. tostring(extra.rarity or "?")
	elseif action == "CashUpgrade" or action == "BoardUpgrade" then
		sku ..= ":" .. string.sub(tostring(request.upgradeKey or "?"), 1, 24)
	end
	self.ledger:Count("econ.sink." .. sku, spent)
	self.ledger:Count("econ.sink." .. sku .. ".n")
	self.ledger:Count("econ.sinkTotal", spent)
	local player, balance, transaction = st.player, session.coins, definition.transaction
	self:_Queue(false, "economy:Sink:" .. sku, function()
		AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Sink, Schema.Currency, spent,
			balance, transaction, sku, fields(self:_Stage(st)))
	end)
end

function Analytics:Action(session, action: string, ok: boolean, message: any, before: number, request: any, extra: any?)
	local st = self:_State(session)
	if not st or action == "Sync" or action == "TutorialSignal" or action == "ClientReport" then return end
	local info = extra or {}
	self:_Trail(st, if ok then action else action .. "!")
	if not ok then
		self.ledger:Count("act." .. action .. ".fail")
		local reason = string.sub(tostring(message or "?"), 1, 60)
		self.ledger:Top("reject", action .. " | " .. reason)
		st.rejects[action] = (st.rejects[action] or 0) + 1
		return
	end
	self.ledger:Count("act." .. action)
	self:_Feature(st, action)
	if action == "Roll" then
		self:_Rolled(st, session)
	elseif action == "Buy" then
		local pet = info.petId and session.pets[info.petId]
		local definition = pet and Catalog[pet.species]
		info.rarity = if definition then definition.rarity else "?"
		st.buys += 1
		self.ledger:Count("roll.buy." .. info.rarity)
		self.ledger:Hist("roll.rollsPerBuy", "count", st.rollsSinceBuy)
		st.rollsSinceBuy = 0
		if st.rollFunnelId and st.rollFunnelAffordable then
			local player, id = st.player, st.rollFunnelId
			self:_Queue(false, "funnel:Roll:Recruited", function()
				AnalyticsService:LogFunnelStepEvent(player, "Roll", id, 3, "Recruited")
			end)
			st.rollFunnelId = nil
		end
	elseif action == "Attack" then
		self:_Attack(st, session, request)
	elseif action == "PreparePurchase" then
		local key = string.sub(tostring(request.key or "?"), 1, 32)
		local id = game:GetService("HttpService"):GenerateGUID(false)
		st.shopFunnel[key] = id
		self.ledger:Count("shop.prompt." .. key)
		local player = st.player
		self:_Queue(false, "funnel:Shop:Prompted", function()
			AnalyticsService:LogFunnelStepEvent(player, "Shop", id, 1, "Prompted", fields(key))
		end)
	elseif action == "OpenCrate" and info.crate and info.crate.species then
		local definition = Catalog[info.crate.species]
		self.ledger:Count("crate.open." .. (if definition then definition.rarity else "?"))
	end
	local spent = math.max(0, (before or 0) - (session.coins or 0))
	if spent > 0 then self:_Sink(st, session, action, spent, request, info) end
end

function Analytics:_Rolled(st, session)
	st.rolls += 1
	st.rollsSinceBuy += 1
	self.ledger:Count("roll.count")
	local affordable = false
	for _, offer in session.offers or {} do
		local definition = Catalog[offer.species]
		local rarity = if definition then definition.rarity else "?"
		local canPay = false
		if type(offer.price) == "number" then
			local okSpend, result = pcall(function() return session:CanSpendCash(offer.price, if offer.starter then "StarterRecruit" else nil) end)
			canPay = okSpend and result == true
		end
		self.ledger:Count("roll.offer." .. rarity)
		if canPay then
			affordable = true
			self.ledger:Count("roll.offer." .. rarity .. ".affordable")
		end
		if offer.guaranteed then self.ledger:Count("roll.offer.guaranteed") end
	end
	self.ledger:Count(if affordable then "roll.anyAffordable" else "roll.noneAffordable")
	if st.rollFunnels >= Schema.RollFunnelSessionCap then return end
	st.rollFunnels += 1
	local id = game:GetService("HttpService"):GenerateGUID(false)
	st.rollFunnelId, st.rollFunnelAffordable = id, affordable
	local player = st.player
	self:_Queue(false, "funnel:Roll:Rolled", function()
		AnalyticsService:LogFunnelStepEvent(player, "Roll", id, 1, "Rolled")
		if affordable then AnalyticsService:LogFunnelStepEvent(player, "Roll", id, 2, "AffordableOffer") end
	end)
end

local function campLevel(targetId: any): (number?, string?)
	if type(targetId) ~= "string" then return nil, nil end
	if string.sub(targetId, 1, 5) == "king:" then return 4, "King" end
	local index = tonumber(string.match(targetId, "^camp:(%d+)$"))
	if index and index >= 1 and index <= 3 then return index, "Camp" .. index end
	return nil, nil
end

function Analytics:_Attack(st, session, request)
	local level, step = campLevel(request and request.targetId)
	if not level or not step then
		self.ledger:Count("attack.other")
		return
	end
	self.ledger:Count("camp." .. step .. ".attempt")
	local won = if level == 4 then session.kingCleared == true else (session.firstWins or {})[level] == true
	if won then return end
	self.ledger:Count("camp." .. step .. ".attemptBeforeWin")
	local player, path = st.player, Schema.MainRoute
	local id = st.userId .. "-" .. step
	self:_Queue(true, "progression:Start:" .. step, function()
		AnalyticsService:LogProgressionStartEvent(player, path.path, level, path.levels[level])
		AnalyticsService:LogFunnelStepEvent(player, "Camp", id, 1, "Deployed", fields(step))
	end)
end

-- BattleService first-win/fail funnel, forwarded by TutorialService.LogProgress.
function Analytics:Progress(userId: number, name: string, value: number, step: string, detail: string)
	local st = self.players[userId]
	local level = if step == "King" then 4 else tonumber(string.match(step or "", "^Camp(%d)$"))
	if not level then return end
	local reason, odds = string.match(detail or "", "^([^/]+)/(.+)$")
	local result = if name == "ConquestFailed" then "fail" else "firstWin"
	self.ledger:Count("camp." .. step .. "." .. result)
	if result == "fail" then self.ledger:Count("camp." .. step .. ".fail." .. tostring(reason or "?")) end
	self.ledger:Count("camp." .. step .. ".odds." .. tostring(odds or "?") .. "." .. result)
	self.ledger:Hist("camp." .. step .. "." .. result .. ".seconds", "seconds", value or 0)
	if not st then return end
	self:_Trail(st, step .. ":" .. result)
	local player, path = st.player, Schema.MainRoute
	if result == "firstWin" then
		local id = st.userId .. "-" .. step
		self:_Queue(true, "progression:Complete:" .. step, function()
			AnalyticsService:LogProgressionCompleteEvent(player, path.path, level, path.levels[level])
			AnalyticsService:LogFunnelStepEvent(player, "Camp", id, 2, "Won", fields(step))
		end)
	else
		self:_Queue(true, "progression:Fail:" .. step, function()
			AnalyticsService:LogProgressionFailEvent(player, path.path, level, path.levels[level])
		end)
	end
end

function Analytics:Income(session, source: string, amount: number, balance: number)
	if Schema.IgnoredSources[source] or type(amount) ~= "number" or amount <= 0 then return end
	local st = self:_State(session)
	local name = if Schema.Sources[source] then source else "other"
	self.ledger:Count("econ.src." .. name, amount)
	self.ledger:Count("econ.src." .. name .. ".n")
	self.ledger:Count("econ.srcTotal", amount)
	if not st then return end
	st.econ[name] = (st.econ[name] or 0) + amount
	st.sessionEarned += amount
end

function Analytics:_FlushEconomy(st)
	local session = st.session
	local balance = if session then session.coins or 0 else 0
	for source, amount in st.econ do
		local definition = Schema.Sources[source]
		if definition and amount > 0 then
			local player = st.player
			self:_Queue(false, "economy:Source:" .. definition.sku, function()
				AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, Schema.Currency, amount,
					balance, definition.transaction, definition.sku, fields(self:_Stage(st)))
			end)
		end
	end
	st.econ = {}
end

-- Robux --------------------------------------------------------------------------

function Analytics:_Purchase(st, kind: string, key: string, price: number)
	local profile = st.profile
	self.ledger:Count("robux.purchases")
	self.ledger:Count("robux." .. kind .. "." .. key)
	self.ledger:Count("robux.estimate", price)
	local stage = self:_Stage(st)
	self.ledger:Count("robux.stage." .. (if stage == "Post" then "Post" elseif stage == "Untracked" then "Untracked" else "Onboarding"))
	if profile then
		profile.purchases = (profile.purchases or 0) + 1
		profile.robux = (profile.robux or 0) + price
		if not profile.firstPurchase then
			profile.firstPurchase = math.floor(self:_Play(st))
			self.ledger:Count("robux.firstPurchase")
			self.ledger:Hist("robux.firstPurchase.playSeconds", "seconds", profile.firstPurchase)
			if profile.firstDay then self.ledger:Cohort(profile.firstDay, "robux.payer") end
		end
	end
	self:_Trail(st, "robux:" .. key)
	local player, id = st.player, st.shopFunnel[key] or game:GetService("HttpService"):GenerateGUID(false)
	st.shopFunnel[key] = nil
	self:_Queue(true, "custom:RobuxPurchase", function()
		AnalyticsService:LogCustomEvent(player, "RobuxPurchase", price, fields(kind, key, stage))
		AnalyticsService:LogFunnelStepEvent(player, "Shop", id, 2, "Purchased", fields(key))
	end)
end

function Analytics:ProductGranted(session, productId: number, product: any)
	local st = self:_State(session)
	local key = self.productKeys[productId] or ("Product" .. tostring(productId))
	if product and type(product.coins) == "number" then
		self.ledger:Count("econ.src.robux", product.coins)
		self.ledger:Count("econ.src.robux.n")
		if st then
			local player, balance = st.player, session.coins
			self:_Queue(true, "economy:Source:CashPack", function()
				AnalyticsService:LogEconomyEvent(player, Enum.AnalyticsEconomyFlowType.Source, Schema.Currency,
					product.coins, balance, Enum.AnalyticsEconomyTransactionType.IAP.Name, "CashPack:" .. key)
			end)
		end
	end
	if st then self:_Purchase(st, "product", key, product and product.proposedPrice or 0) end
end

function Analytics:PassPurchased(player: Player, key: string)
	local st = self.players[player.UserId]
	local definition = ShopCatalog.Definitions and ShopCatalog.Definitions[key]
	if st then self:_Purchase(st, "pass", key, definition and definition.proposedPrice or 0) end
end

-- Client reports -----------------------------------------------------------------

function Analytics:ClientReport(session, report: any)
	local st = self:_State(session)
	if not st or type(report) ~= "table" then return end
	local now = self.clock()
	if now - st.lastReport < REPORT_MIN_SECONDS then return end
	st.lastReport = now
	if type(report.platform) == "string" and Schema.Platforms[report.platform] and st.platform == "Unknown" then
		st.platform = report.platform
		self.ledger:Count("client.platform." .. st.platform)
		local x, y = finite(report.screenX, 0, 10000), finite(report.screenY, 0, 10000)
		if x and y then
			local short = math.min(x, y)
			self.ledger:Count("client.screen." .. (if short < 500 then "small" elseif short < 800 then "medium" else "large"))
		end
		for _, flag in {"touch", "keyboard", "gamepad"} do
			if report[flag] == true then self.ledger:Count("client.input." .. flag) end
		end
	end
	local platform = st.platform
	local fps, fpsMin, mem = finite(report.fps, 0, 1000), finite(report.fpsMin, 0, 1000), finite(report.memMb, 0, 100000)
	if fps then
		st.fpsSum += fps; st.fpsN += 1
		self.ledger:Hist("perf.fps|" .. platform, "fps", fps)
		if fpsMin then self.ledger:Hist("perf.fpsMin|" .. platform, "fps", fpsMin) end
		if mem then self.ledger:Hist("perf.memMb|" .. platform, "memory", mem) end
		if now >= st.nextClientPerf then
			st.nextClientPerf = now + CLIENT_PERF_SECONDS
			local player, bucket = st.player, Schema.Bucket("fps", fps)
			self:_Queue(false, "custom:ClientPerf", function()
				AnalyticsService:LogCustomEvent(player, "ClientPerf", math.floor(fps), fields(platform, bucket, Config.Version))
			end)
		end
	end
	if type(report.errors) == "table" then
		local total = 0
		for index, entry in report.errors do
			if type(index) ~= "number" or index > 5 or type(entry) ~= "table" then continue end
			local count = math.floor(finite(entry.n, 1, 1000) or 1)
			local source = string.sub(tostring(entry.s or "?"), 1, 40)
			total += count
			self.ledger:Top("err.client", source .. ": " .. string.sub(tostring(entry.m or "?"), 1, 80), count)
			local player = st.player
			self:_Queue(false, "custom:ScriptError", function()
				AnalyticsService:LogCustomEvent(player, "ScriptError", count, fields("Client", source, Config.Version))
			end)
		end
		if total > 0 then
			st.errors += total
			self.ledger:Count("err.client", total)
			self:_Trail(st, "clientError")
		end
	end
end

-- LoopTelemetry sink: ArmyGrowth, ArmyDeployed, ArmyReturned, RecruitArrived, Territory*, IncomeContest*.
function Analytics:LoopEvent(event: any)
	if type(event) ~= "table" or type(event.name) ~= "string" then return end
	local name = string.sub(event.name, 1, 40)
	self.ledger:Count("loop." .. name)
	local f = event.fields or {}
	if type(f.result) == "string" then self.ledger:Count("loop." .. name .. "." .. string.sub(f.result, 1, 24)) end
	if type(f.seconds) == "number" then self.ledger:Hist("loop." .. name .. ".seconds", "seconds", f.seconds) end
end

-- Leaving ------------------------------------------------------------------------

function Analytics:Leave(session)
	local st = self:_State(session)
	if not st then return end
	self.players[session.userId] = nil
	if not st.ready or st.loadFailed then
		self.ledger:Count("players.leftBeforeReady")
		return
	end
	local now = self.clock()
	local seconds = now - st.joinedAt
	local platform = st.platform
	local cohort = if st.isNew then "new" else "returning"
	self.ledger:Count("session.count")
	self.ledger:Count("session.count." .. cohort)
	self.ledger:Count("session.count|" .. platform)
	self.ledger:Count("session.seconds", seconds)
	self.ledger:Hist("session.seconds", "seconds", seconds)
	self.ledger:Hist("session.seconds." .. cohort, "seconds", seconds)
	self.ledger:Hist("session.seconds|" .. platform, "seconds", seconds)
	self.ledger:Hist("econ.balanceAtLeave", "cash", session.coins or 0)
	self.ledger:Hist("econ.sessionEarned", "cash", st.sessionEarned)
	if st.rolls > 0 then self.ledger:Hist("roll.perSession", "count", st.rolls) end
	if st.guideStep and st.guideStepAt then self.ledger:Hist("guide.dwell." .. st.guideStep, "seconds", now - st.guideStepAt) end
	local stage = self:_Stage(st)
	local onboarding = st.tracked and string.sub(stage, 1, 4) == "Onb:"
	if onboarding then
		local step = st.guideStep or "None"
		local dwell = if st.guideStepAt then now - st.guideStepAt else seconds
		local maxCode = Schema.StepCode(math.max(st.maxStep, if st.profile then st.profile.onbMax or 0 else 0))
		self.ledger:Count("onb.exit." .. step)
		self.ledger:Count("onb.exitMax." .. maxCode)
		self.ledger:Hist("onb.exitDwell." .. step, "seconds", dwell)
		if st.sessionIndex <= 1 then self.ledger:Count("onb.exitFirstSession." .. step) end
		local player, sessionLabel = st.player, if st.sessionIndex <= 1 then "S1" elseif st.sessionIndex == 2 then "S2" else "S3+"
		self:_Queue(false, "custom:OnboardingExit", function()
			AnalyticsService:LogCustomEvent(player, "OnboardingExit", math.floor(dwell), fields(step, "Max" .. maxCode, sessionLabel))
		end)
	end
	local player = st.player
	self:_Queue(false, "custom:SessionEnded", function()
		AnalyticsService:LogCustomEvent(player, "SessionEnded", math.floor(seconds), fields(platform, stage, cohort))
	end)
	if st.rolls > 0 then
		local rate = st.buys / st.rolls
		self:_Queue(false, "custom:RollSummary", function()
			AnalyticsService:LogCustomEvent(player, "RollSummary", st.rolls, fields(stage,
				if rate >= 0.5 then "Buy50+" elseif rate >= 0.25 then "Buy25-50" elseif rate > 0 then "Buy<25" else "Buy0", platform))
		end)
	end
	self:_FlushEconomy(st)
	if onboarding or self.random() < JOURNEY_SAMPLE then
		local rejects = {}
		for action, count in st.rejects do table.insert(rejects, action .. "x" .. count) end
		self.ledger:Journey({
			u = st.anon, v = Config.Version, p = platform, n = st.sessionIndex, new = st.isNew == true,
			tr = st.tracked == true, s = math.floor(seconds), pl = math.floor(self:_Play(st)), stage = stage,
			st = st.journeySteps, ex = st.guideStep, mx = st.maxStep, c = session.coins, pe = session:Count(),
			r = st.rolls, b = st.buys, er = st.errors, earned = st.sessionEarned, rej = rejects,
			ping = if st.pingN > 0 then math.floor(st.pingSum / st.pingN) else nil,
			fps = if st.fpsN > 0 then math.floor(st.fpsSum / st.fpsN) else nil, trail = st.trail,
		})
	end
	if st.profile then
		st.profile.play = math.floor(self:_Play(st))
		st.profile.lastSeen = self.wall()
		local profile, userId = st.profile, st.userId
		self.saving += 1
		task.spawn(function()
			if not self.ledger:SaveProfile(userId, profile, Analytics.MergeProfile) then self.ledger:Count("analytics.profileSaveFail") end
			self.saving -= 1
		end)
	end
end

-- Server loop --------------------------------------------------------------------

function Analytics:Step(dt: number)
	if self.destroyed then return end
	local now = self.clock()
	self.frameSum += dt; self.frameCount += 1; self.frameMax = math.max(self.frameMax, dt)
	self:_Pump(dt)
	if now >= self.nextPerf then
		self.nextPerf = now + Schema.PerfSampleSeconds
		local count = 0
		for _ in self.players do count += 1 end
		if self.frameCount > 0 then
			self.ledger:Hist("server.frameMs", "ms", self.frameSum / self.frameCount * 1000)
			self.ledger:Hist("server.frameMaxMs", "ms", self.frameMax * 1000)
		end
		self.frameSum, self.frameCount, self.frameMax = 0, 0, 0
		self.ledger:Count("server.minutes")
		self.ledger:Count("player.minutes", count)
		self.ledger:Max("server.peakPlayers", count)
		self.ledger:Hist("server.players", "count", count)
		for _, st in self.players do
			local okPing, ping = pcall(function() return st.player:GetNetworkPing() end)
			if okPing and type(ping) == "number" then
				local ms = ping * 1000
				st.pingSum += ms; st.pingN += 1
				self.ledger:Hist("net.pingMs|" .. st.platform, "ping", ms)
			end
		end
	end
	if now >= self.nextEconomy then
		self.nextEconomy = now + Schema.EconomyFlushSeconds
		for _, st in self.players do self:_FlushEconomy(st) end
	end
	if now >= self.nextProfiles then
		self.nextProfiles = now + Schema.ProfileSaveSeconds
		for _, st in self.players do
			if st.profile then
				local copy = table.clone(st.profile)
				copy.play = math.floor(self:_Play(st))
				local userId = st.userId
				task.spawn(function() self.ledger:SaveProfile(userId, copy, Analytics.MergeProfile) end)
			end
		end
	end
	if now >= self.nextFlush then
		self.nextFlush = now + Schema.FlushSeconds
		task.spawn(function() self.ledger:Flush() end)
	end
end

-- BindToClose: leave everyone, then flush the ledger. Yields (bounded by caller).
function Analytics:Close()
	for _, st in self.players do self:Leave(st.session) end
	local deadline = self.clock() + 10
	while self.saving > 0 and self.clock() < deadline do task.wait(0.1) end
	self.ledger:Flush()
end

function Analytics:Destroy()
	self.destroyed = true
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
end

return Analytics
