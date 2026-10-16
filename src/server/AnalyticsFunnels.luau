--!strict
-- Feature funnel engine (docs/analytics/TRACKING_PLAN.md section 3). Observation
-- only: never changes gameplay and never yields. Analytics owns the per-player
-- state `st`; this module adds:
--   st.fun                session state (steps reached, furthest step, pending steps)
--   profile.fun[F][NN]    play seconds when the player first reached step NN of F
--   profile.funN          small lifetime counters this module owns (buys, fuses, ...)
--   profile.funRbx        {d = UTC day, s = {[F] = bitmask}} Roblox steps sent today
-- Ledger names: fun.<F>.s.<NN>, fun.<F>.p.<NN>, fun.<F>.t.<NN> (seconds hist),
-- fun.<F>.last.<NN>, cohort fun.<F>.<NN>, fun.unknown, analytics.funnelError.
-- Every public method is pcall-guarded; Roblox calls go through host:_Queue.
local AnalyticsService = game:GetService("AnalyticsService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog = require(Shared.PetCatalog) :: any
local ShopCatalog = require(Shared.ShopCatalog) :: any
local Schema = require(script.Parent.AnalyticsSchema)
local RobloxSteps = Schema.RobloxSteps :: any
local RobloxNames = Schema.Funnels :: any

local CF1 = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
local CF2 = Enum.AnalyticsCustomFieldKeys.CustomField02.Name
local CF3 = Enum.AnalyticsCustomFieldKeys.CustomField03.Name
local DROP_SAMPLE = 0.25   -- share of unfinished funnels sent as FunnelDrop
local DROP_CAP = 4         -- FunnelDrop events per session
local STATE_RECHECK = 5    -- seconds between full state checks while the revision is unchanged
local MAX_TEXT = 64
local DAY_SECONDS = 86400

local Funnels = {}
Funnels.__index = Funnels

-- Static lookups ------------------------------------------------------------------

local FunnelSteps = {} :: {[string]: {any}}
for _, funnel in Schema.FeatureFunnels do FunnelSteps[funnel.id] = funnel.steps end
local StepIndex = Schema.FeatureFunnelIndex :: {[string]: {[string]: number}}

local RarityRank = {} :: {[string]: number}
for index, rarity in Schema.Rarities do RarityRank[rarity] = index end

-- Own counters (profile.funN) -> the AnalyticsPlayer lifetime key (profile.life),
-- read with max so players with history before version 5 still cross thresholds.
local LifeKeys = {buys = "buys", fuses = "fuses", upgrades = "upgrades", levels = "chickenLevels", missions = "missionsWon"}
-- counter -> {{at least, funnel, step}}
local Thresholds = {
	buys = {{10, "Roll", "Recruited10"}},
	fuses = {{5, "Fuse", "Fused5"}},
	upgrades = {{10, "Upgrades", "Buys10"}, {50, "Upgrades", "Buys50"}},
	levels = {{10, "ChickenLevel", "Upgraded10"}},
	missions = {{5, "Mission", "Won5"}},
	pur = {{2, "Shop", "Repeat"}},
} :: {[string]: any}

-- Successful request -> steps. Extra conditions live in actionImpl.
local ActionSteps = {
	Roll = {{"Roll", "Pulled"}},
	Buy = {{"Roll", "Recruited"}},
	CashUpgrade = {{"Upgrades", "FirstBuy"}},
	BoardUpgrade = {{"Upgrades", "FirstBuy"}},
	Luck = {{"Upgrades", "FirstBuy"}},
	Income = {{"Upgrades", "FirstBuy"}},
	Expand = {{"Upgrades", "FirstBuy"}},
	StartResearch = {{"Research", "Started"}},
	PreparePurchase = {{"Shop", "Prompted"}},
	RefreshShop = {{"Shop", "Opened"}},
	OpenMerge = {{"Fuse", "Opened"}},
	Merge = {{"Fuse", "Fused"}},
	MergeAll = {{"Fuse", "Fused"}},
	UpgradeChicken = {{"ChickenLevel", "Upgraded"}},
	SelectBest = {{"Army", "Selected"}},
	SetArmy = {{"Army", "Selected"}},
	Equip = {{"Army", "Selected"}},
	Attack = {{"Army", "Deployed"}},
	CallArmy = {{"Army", "CallArmy"}},
	Rally = {{"Army", "Rally"}},
	SaveFormation = {{"Army", "Formation"}},
	ApplyFormation = {{"Army", "Formation"}},
	Sell = {{"Sell", "Sold"}},
	OpenCrate = {{"Crate", "Opened"}},
	SetCommerceToggle = {{"Pass", "Toggled"}},
	Rebirth = {{"Rebirth", "Rebirthed"}},
	StartOperation = {{"Mission", "Started"}},
} :: {[string]: {{string}}}
local UpgradeActions = {CashUpgrade = true, BoardUpgrade = true, Luck = true, Income = true, Expand = true}

-- client menu.open detail (Schema.Menus key) -> steps
local MenuSteps = {
	Upgrades = {{"Upgrades", "MenuOpened"}, {"Research", "TreeOpened"}},
	Army = {{"ChickenLevel", "ArmyOpened"}, {"Army", "ArmyOpened"}},
	Fuse = {{"Fuse", "Opened"}},
	Sell = {{"Sell", "Opened"}},
	Index = {{"Index", "Opened"}},
	Shop = {{"Shop", "Opened"}},
	Crate = {{"Crate", "Viewed"}},
	Rebirth = {{"Rebirth", "Opened"}},
	Missions = {{"Mission", "Opened"}},
	Daily = {{"Daily", "Opened"}},
	Offline = {{"Offline", "Shown"}},
	Settings = {{"Settings", "Opened"}},
	Leaderboard = {{"Leaderboard", "Viewed"}},
} :: {[string]: {{string}}}

-- server event name -> step (prefix names such as mission.won.<tier> are handled in serverImpl)
local ServerSteps = {
	["autoroll.stop"] = {"AutoRoll", "Stopped"},
	["research.complete"] = {"Research", "Completed"},
	["daily.shown"] = {"Daily", "Available"},
	["offline.shown"] = {"Offline", "Shown"},
	["offline.claimed"] = {"Offline", "Claimed"},
	["plot.buildStart"] = {"Plot", "BuildStarted"},
	["plot.buildDone"] = {"Plot", "BuildDone"},
	["hill.enter"] = {"Hill", "Entered"},
	["hill.hold"] = {"Hill", "Held"},
	["hill.win"] = {"Hill", "Won"},
	["rebirth.count"] = {"Rebirth", "Rebirthed"},
} :: {[string]: {string}}

local function code(index: number): string
	return string.format("%02d", index)
end

local function startsWith(text: string, prefix: string): boolean
	return string.sub(text, 1, #prefix) == prefix
end

-- "mission.won" or "mission.won.<suffix>"
local function under(name: string, base: string): boolean
	return name == base or startsWith(name, base .. ".")
end

local function text(value: any): string
	return if type(value) == "string" then string.sub(value, 1, MAX_TEXT) else ""
end

-- Session state -------------------------------------------------------------------

local function newSession()
	return {
		sess = {} :: {[string]: {[number]: boolean}}, -- steps reached this session
		far = {} :: {[string]: number},              -- furthest step per funnel this session
		pending = {} :: {any},                       -- {funnel, index, session seconds} before the profile
		n = {} :: {[string]: number},                -- counters not yet in profile.funN
		rbx = nil :: any,                            -- Roblox day masks when there is no profile
		cache = {rev = nil :: any, at = -math.huge, research = nil :: number?},
		drops = 0, resolved = false, warned = false,
	}
end

local function funOf(st: any): any
	if type(st) ~= "table" then return nil end
	if type(st.fun) ~= "table" then st.fun = newSession() end
	return st.fun
end

-- Core ----------------------------------------------------------------------------

local reach: (self: any, st: any, funnel: string, index: number) -> ()
local named: (self: any, st: any, funnel: string, stepId: string) -> ()
local resolve: (self: any, st: any) -> ()

local function counterValue(st: any, key: string): number
	local f = st.fun
	local total = f.n[key] or 0
	local profile = st.profile
	if type(profile) == "table" then
		if type(profile.funN) == "table" then total += tonumber(profile.funN[key]) or 0 end
		local lifeKey, life = LifeKeys[key], profile.life
		if lifeKey and type(life) == "table" and type(life[lifeKey]) == "number" then
			total = math.max(total, life[lifeKey])
		end
	end
	return total
end

local function checkThreshold(self: any, st: any, key: string)
	local list = Thresholds[key]
	if not list then return end
	local value = counterValue(st, key)
	for _, entry in list do
		if value >= entry[1] then named(self, st, entry[2], entry[3]) end
	end
end

local function addCounter(self: any, st: any, key: string, amount: number)
	local f = st.fun
	local profile = st.profile
	if f.resolved and type(profile) == "table" and type(profile.funN) == "table" then
		profile.funN[key] = (tonumber(profile.funN[key]) or 0) + amount
	else
		f.n[key] = (f.n[key] or 0) + amount
	end
	checkThreshold(self, st, key)
end

-- Bitmask table of Roblox steps sent today (profile when present, else session).
local function dayMask(self: any, st: any, day: string): {[string]: number}
	local f = st.fun
	local profile = st.profile
	local holder = if f.resolved and type(profile) == "table" then profile else f
	local key = if holder == f then "rbx" else "funRbx"
	local record = holder[key]
	if type(record) ~= "table" or record.d ~= day or type(record.s) ~= "table" then
		record = {d = day, s = {}}
		holder[key] = record
	end
	return record.s
end

-- Roblox funnel dashboards: one funnel session per player per funnel per UTC day.
local function sendRoblox(self: any, st: any, funnel: string, index: number)
	local map = RobloxSteps[funnel]
	local player = st.player
	if not map or not player then return end
	local step = FunnelSteps[funnel][index]
	local robloxIndex = step and map[step.id]
	local names = RobloxNames[funnel]
	local stepName = if robloxIndex and names then names[robloxIndex] else nil
	if not robloxIndex or not stepName then return end
	local host = self.host
	local day = os.date("!%Y-%m-%d", host.wall()) :: string
	local sent = dayMask(self, st, day)
	local bit = bit32.lshift(1, robloxIndex - 1)
	local mask = math.floor(tonumber(sent[funnel]) or 0)
	if bit32.band(mask, bit) ~= 0 then return end
	sent[funnel] = bit32.bor(mask, bit)
	local id = tostring(st.userId) .. "-" .. funnel .. "-" .. day
	local roblox, name = robloxIndex :: number, stepName :: string
	host:_Queue(false, "funnel:" .. funnel .. ":" .. name, function()
		AnalyticsService:LogFunnelStepEvent(player, funnel, id, roblox, name)
	end)
end

-- First time ever for this player (needs the resolved profile).
local function recordFirst(self: any, st: any, funnel: string, index: number, play: number)
	local profile = st.profile
	if type(profile) ~= "table" or type(profile.fun) ~= "table" then return end
	local steps = profile.fun[funnel]
	if type(steps) ~= "table" then steps = {}; profile.fun[funnel] = steps end
	local nn = code(index)
	if steps[nn] ~= nil then return end
	local first: number? = nil
	for _, seconds in steps do
		if type(seconds) == "number" and (first == nil or seconds < first) then first = seconds end
	end
	local whole = math.max(0, math.floor(play))
	steps[nn] = whole
	local host = self.host
	local ledger = host.ledger
	ledger:Count("fun." .. funnel .. ".p." .. nn)
	ledger:Hist("fun." .. funnel .. ".t." .. nn, "seconds", if first then math.max(0, whole - first) else 0)
	if type(profile.firstDay) == "string" and st.tracked then
		ledger:Cohort(profile.firstDay, "fun." .. funnel .. "." .. nn)
	end
	host:_Trail(st, "fun:" .. funnel .. "." .. FunnelSteps[funnel][index].id)
end

reach = function(self: any, st: any, funnel: string, index: number)
	local f = funOf(st)
	if not f then return end
	local seen = f.sess[funnel]
	if not seen then seen = {}; f.sess[funnel] = seen end
	if seen[index] then return end
	seen[index] = true
	f.far[funnel] = math.max(f.far[funnel] or 0, index)
	local host = self.host
	host.ledger:Count("fun." .. funnel .. ".s." .. code(index))
	if not f.resolved and st.profile ~= nil then resolve(self, st) end
	if f.resolved then
		recordFirst(self, st, funnel, index, host:_Play(st))
		sendRoblox(self, st, funnel, index)
	else
		table.insert(f.pending, {funnel, index, host.clock() - (tonumber(st.joinedAt) or host.clock())})
	end
end

named = function(self: any, st: any, funnel: string, stepId: string)
	local steps = StepIndex[funnel]
	local index = steps and steps[stepId]
	if not index then self.host.ledger:Count("fun.unknown"); return end
	reach(self, st, funnel, index)
end

resolve = function(self: any, st: any)
	local f = funOf(st)
	if not f or f.resolved then return end
	f.resolved = true
	local pending = f.pending
	f.pending = {}
	local profile = st.profile
	if type(profile) ~= "table" then
		-- Store unreachable: per-player steps are unknown; Roblox still gets session-deduped steps.
		for _, entry in pending do sendRoblox(self, st, entry[1], entry[2]) end
		return
	end
	if type(profile.fun) ~= "table" then profile.fun = {} end
	if type(profile.funN) ~= "table" then profile.funN = {} end
	local counts = profile.funN
	-- Robux purchases before version 5 count toward Shop.Repeat (host profile.purchases).
	if counts.pur == nil then counts.pur = if type(profile.purchases) == "number" then profile.purchases else 0 end
	local sessionCounts = f.n
	f.n = {}
	for key, value in sessionCounts do counts[key] = (tonumber(counts[key]) or 0) + value end
	local base = tonumber(profile.play) or 0
	for _, entry in pending do
		recordFirst(self, st, entry[1], entry[2], base + entry[3])
		sendRoblox(self, st, entry[1], entry[2])
	end
	for key in sessionCounts do checkThreshold(self, st, key) end
end

-- Triggers ------------------------------------------------------------------------

local function offerAffordable(session: any): boolean
	if type(session) ~= "table" or type(session.offers) ~= "table" then return false end
	for _, offer in session.offers do
		if type(offer) == "table" and type(offer.price) == "number" then
			local ok, result = pcall(session.CanSpendCash, session, offer.price, if offer.starter then "StarterRecruit" else nil)
			if ok and result == true then return true end
		end
	end
	return false
end

local function shopKeySteps(self: any, st: any, key: string, bought: boolean)
	if startsWith(key, "ResearchSkip") then
		named(self, st, "Research", if bought then "SkipBought" else "SkipPrompted")
	elseif startsWith(key, "OuterSpaceCrate") then
		named(self, st, "Crate", if bought then "Bought" else "Prompted")
	elseif ShopCatalog.Definitions[key] ~= nil then
		named(self, st, "Pass", if bought then "Bought" else "Prompted")
	end
end

local function actionImpl(self: any, st: any, session: any, action: any, ok: any, request: any, info: any)
	if type(action) ~= "string" then return end
	-- OpenSell always answers with guidance (ok=false); the request itself shows intent.
	if action == "OpenSell" then named(self, st, "Sell", "Opened") end
	if ok ~= true then return end
	local list = ActionSteps[action]
	if list then for _, pair in list do named(self, st, pair[1], pair[2]) end end
	local req = if type(request) == "table" then request else {}
	local extra = if type(info) == "table" then info else {}
	if action == "Roll" then
		if offerAffordable(session) then named(self, st, "Roll", "OfferAffordable") end
	elseif action == "Buy" then
		addCounter(self, st, "buys", 1)
		local pets = if type(session) == "table" then session.pets else nil
		local pet = if type(pets) == "table" and extra.petId ~= nil then pets[extra.petId] else nil
		local definition = if type(pet) == "table" and type(pet.species) == "string" then Catalog[pet.species] else nil
		local rank = if type(definition) == "table" then RarityRank[definition.rarity] or 0 else 0
		if rank >= RarityRank.Rare then named(self, st, "Roll", "RareOrBetter") end
		if rank >= RarityRank.Epic then named(self, st, "Roll", "EpicOrBetter") end
		if rank >= RarityRank.Legendary then named(self, st, "Roll", "LegendaryOrBetter") end
	elseif UpgradeActions[action] then
		addCounter(self, st, "upgrades", 1)
		if (action == "BoardUpgrade" or action == "CashUpgrade") and req.upgradeKey == "PlotSize" then
			named(self, st, "Plot", "Expanded")
		end
	elseif action == "Merge" then
		addCounter(self, st, "fuses", 1)
	elseif action == "MergeAll" then
		local count = if type(req.triples) == "table" then #req.triples else 1
		addCounter(self, st, "fuses", math.clamp(count, 1, 50))
	elseif action == "UpgradeChicken" then
		addCounter(self, st, "levels", 1)
	elseif action == "PreparePurchase" then
		shopKeySteps(self, st, text(req.key), false)
	elseif action == "SetAutoRoll" then
		if req.enabled == true then named(self, st, "AutoRoll", "Enabled") end
	end
end

local function countCompleted(completed: any): number
	local count = 0
	for id, done in completed do
		if done and id ~= "Start" then count += 1 end -- Start is granted to every save
	end
	return count
end

-- DailyService grants on the server once per UTC day after the guide is done, so
-- "claimable" is either a reward granted this session (the popup) or a day not yet
-- granted while the guide is done (the moment before DailyService.Check runs).
local function dailyAvailable(self: any, session: any, state: any): boolean
	local daily = state.daily
	if type(daily) ~= "table" then return false end
	if type(daily.granted) == "table" then return true end
	local tutorial = if type(session) == "table" and type(session.tutorial) == "table" then session.tutorial else state.tutorial
	if type(tutorial) ~= "table" or not (tutorial.guideCompleted == true or tutorial.wonCamp == true) then return false end
	local lastDay = tonumber(daily.lastDay)
	return lastDay ~= nil and lastDay < math.floor(self.host.wall() / DAY_SECONDS)
end

local function stateImpl(self: any, st: any, session: any, state: any)
	if type(state) ~= "table" then return end
	local f = funOf(st)
	if not f then return end
	local cache = f.cache
	local now = self.host.clock()
	local revision = state.revision
	if revision ~= nil and revision == cache.rev and now - cache.at < STATE_RECHECK then return end
	cache.rev, cache.at = revision, now

	local slots = tonumber(state.rollSlotCount) or 0
	if slots >= 2 then named(self, st, "RollSlots", "Unlocked2") end
	if slots >= 4 then named(self, st, "RollSlots", "Unlocked4") end
	if slots >= 8 then named(self, st, "RollSlots", "Unlocked8") end

	local research = state.research
	local completed = if type(research) == "table" then research.completed else nil
	if type(completed) == "table" then
		if completed.AutoRoll then named(self, st, "AutoRoll", "Available") end
		local count = countCompleted(completed)
		if cache.research ~= nil and count > cache.research then named(self, st, "Research", "Completed") end
		if cache.research == nil or count > cache.research then cache.research = count end
		if count >= 5 then named(self, st, "Research", "Completed5") end
		if count >= 15 then named(self, st, "Research", "Completed15") end
	end

	if state.mergeUnlocked == true then
		named(self, st, "Fuse", "Unlocked")
		if type(state.mergeOptions) == "table" and next(state.mergeOptions) ~= nil then named(self, st, "Fuse", "Available") end
	end

	local wins = state.firstWins
	if type(wins) == "table" then
		if wins[1] == true then named(self, st, "Route", "Camp1") end
		if wins[2] == true then named(self, st, "Route", "Camp2") end
		if wins[3] == true then named(self, st, "Route", "Camp3") end
	end
	if state.allCampsWon == true then named(self, st, "Route", "AllCamps") end
	if state.kingCleared == true then named(self, st, "Route", "King") end

	local rebirth = state.rebirth
	if type(rebirth) == "table" then
		if rebirth.eligible == true then named(self, st, "Rebirth", "Eligible") end
		local rank = tonumber(rebirth.rank) or 0
		if rank >= 2 then named(self, st, "Rebirth", "Rebirth2") end
		if rank >= 5 then named(self, st, "Rebirth", "Rebirth5") end
		if rank >= 10 then named(self, st, "Rebirth", "Rebirth10") end
	end

	if (tonumber(state.collectionLimit) or 0) >= 100 then named(self, st, "Plot", "Max") end
	if dailyAvailable(self, session, state) then named(self, st, "Daily", "Available") end
end

local function clientImpl(self: any, st: any, name: any, detail: any)
	if type(name) ~= "string" then return end
	local d = text(detail)
	if name == "menu.open" then
		local list = MenuSteps[d]
		if list then for _, pair in list do named(self, st, pair[1], pair[2]) end end
	elseif name == "inspect" then
		local menu, kind = string.match(d, "^([^/]+)/(.*)$")
		if menu == "Upgrades" then
			named(self, st, "Upgrades", "Inspected")
			if kind == "node" then named(self, st, "Research", "NodeInspected") end
		elseif menu == "Army" and kind == "chicken" then
			named(self, st, "ChickenLevel", "ChickenInspected")
		elseif menu == "Index" then
			named(self, st, "Index", "Inspected")
		end
	elseif name == "tab" then
		local menu, tab = string.match(d, "^([^/]+)/(.*)$")
		if menu == "Shop" then
			named(self, st, "Shop", "TabViewed")
			if tab == "Crates" then named(self, st, "Crate", "Viewed") end
		end
	elseif name == "prompt.shown" then
		named(self, st, "Shop", "PromptShown")
	elseif name == "setting" then
		named(self, st, "Settings", "Changed")
	elseif name == "leaderboard.view" then
		named(self, st, "Leaderboard", "Viewed")
	end
end

local function giantStep(self: any, st: any, outcome: string?)
	if outcome == "NewGiant" or outcome == "Giant" then
		named(self, st, "Fuse", "Giant")
	elseif outcome == "NewColossal" or outcome == "Colossal" then
		named(self, st, "Fuse", "Colossal")
	end
end

local function serverImpl(self: any, st: any, name: any, detail: any)
	if type(name) ~= "string" or #name > MAX_TEXT then return end
	local d = if type(detail) == "string" then string.sub(detail, 1, MAX_TEXT) else nil
	local simple = ServerSteps[name]
	if simple then
		named(self, st, simple[1], simple[2])
	elseif name == "giant.result" then
		giantStep(self, st, d)
	elseif startsWith(name, "giant.fuse.") then
		giantStep(self, st, string.sub(name, #"giant.fuse." + 1))
	elseif under(name, "mission.spawn") then
		named(self, st, "Mission", "Spawned")
	elseif under(name, "mission.start") then
		named(self, st, "Mission", "Started")
	elseif under(name, "mission.won") then
		-- Only the LaunchCount name counts toward Won5 (mission.result would double it).
		named(self, st, "Mission", "Won")
		addCounter(self, st, "missions", 1)
	elseif name == "mission.result" then
		if d == "won" or (d ~= nil and startsWith(d, "won.")) then named(self, st, "Mission", "Won") end
	elseif under(name, "daily.claim") then
		named(self, st, "Daily", "Claimed")
		local session = st.session
		local daily = if type(session) == "table" then session.daily else nil
		local streak = if type(daily) == "table" then tonumber(daily.streak) or 0 else 0
		if streak >= 3 then named(self, st, "Daily", "Streak3") end
		if streak >= 7 then named(self, st, "Daily", "Streak7") end
	end
end

local function purchaseImpl(self: any, st: any, kind: any, key: any)
	named(self, st, "Shop", "Purchased")
	addCounter(self, st, "pur", 1)
	if kind == "pass" then named(self, st, "Pass", "Bought") else shopKeySteps(self, st, text(key), true) end
end

local function leaveImpl(self: any, st: any)
	local f = funOf(st)
	if not f then return end
	-- Leave runs before the profile save: apply anything still pending.
	if not f.resolved and st.profile ~= nil then resolve(self, st) end
	local host = self.host
	local random = if type(host.random) == "function" then host.random else math.random
	for funnel, far in f.far do
		host.ledger:Count("fun." .. funnel .. ".last." .. code(far))
		local steps = FunnelSteps[funnel]
		if steps and far < #steps and st.player and f.drops < DROP_CAP and random() < DROP_SAMPLE then
			f.drops += 1
			local player, stepId, platform = st.player, tostring(steps[far].id), text(st.platform or "Unknown")
			local customFields = {[CF1] = funnel, [CF2] = stepId, [CF3] = platform}
			host:_Queue(false, "custom:FunnelDrop", function()
				AnalyticsService:LogCustomEvent(player, "FunnelDrop", far, customFields)
			end)
		end
	end
end

-- Public API (called by Analytics) ------------------------------------------------

function Funnels.new(analytics: any)
	return setmetatable({host = analytics, warned = false}, Funnels)
end

-- Runs `fn` so an internal error is counted and never propagates.
local function guard(self: any, st: any, fn: any, ...: any)
	local ok, why = pcall(fn, self, st, ...)
	if ok then return end
	pcall(function() self.host.ledger:Count("analytics.funnelError") end)
	local f = if type(st) == "table" and type(st.fun) == "table" then st.fun else nil
	local first = if f then not f.warned else not self.warned
	if f then f.warned = true else self.warned = true end
	if first then warn("[AnalyticsFunnels] " .. tostring(why)) end
end

function Funnels:Join(st: any)
	guard(self, st, function(_self: any, state: any)
		if type(state) == "table" then state.fun = newSession() end
	end)
end

function Funnels:Profile(st: any)
	guard(self, st, resolve)
end

function Funnels:Step(st: any, funnel: any, step: any)
	guard(self, st, function(me: any, state: any)
		if type(funnel) ~= "string" or type(step) ~= "string" then me.host.ledger:Count("fun.unknown"); return end
		named(me, state, string.sub(funnel, 1, MAX_TEXT), string.sub(step, 1, MAX_TEXT))
	end)
end

function Funnels:Action(st: any, session: any, action: any, ok: any, _message: any, request: any, info: any)
	guard(self, st, actionImpl, session, action, ok, request, info)
end

function Funnels:State(st: any, session: any, state: any)
	guard(self, st, stateImpl, session, state)
end

function Funnels:Client(st: any, name: any, detail: any, _value: any)
	guard(self, st, clientImpl, name, detail)
end

function Funnels:Server(st: any, name: any, detail: any, _value: any)
	guard(self, st, serverImpl, name, detail)
end

function Funnels:Purchase(st: any, kind: any, key: any, _robux: any)
	guard(self, st, purchaseImpl, kind, key)
end

function Funnels:Progress(st: any, step: any, result: any)
	guard(self, st, function(me: any, state: any)
		if result == "firstWin" then named(me, state, "Army", "Won") end
	end)
end

function Funnels:Leave(st: any, _session: any)
	guard(self, st, leaveImpl)
end

-- Concurrent-session merge (Analytics.MergeProfile): union of steps keeping the
-- smallest play seconds, max of each counter, Roblox day masks OR'd on the same day.
function Funnels.MergeProfile(old: any, ours: any, result: any): any
	if type(old) ~= "table" or type(ours) ~= "table" or type(result) ~= "table" then return result end
	local fun = {}
	local function addSteps(source: any)
		if type(source) ~= "table" then return end
		for funnel, steps in source do
			if type(funnel) ~= "string" or type(steps) ~= "table" then continue end
			local target = fun[funnel]
			if not target then target = {}; fun[funnel] = target end
			for nn, seconds in steps do
				if type(seconds) == "number" and (target[nn] == nil or seconds < target[nn]) then target[nn] = seconds end
			end
		end
	end
	addSteps(ours.fun)
	addSteps(old.fun)
	result.fun = fun
	local counts = {}
	for _, source in {ours.funN or false, old.funN or false} do
		if type(source) ~= "table" then continue end
		for key, value in source do
			if type(key) == "string" and type(value) == "number" then counts[key] = math.max(counts[key] or value, value) end
		end
	end
	result.funN = counts
	local function day(value: any): any
		return if type(value) == "table" and type(value.d) == "string" and type(value.s) == "table" then value else nil
	end
	local a, b = day(ours.funRbx), day(old.funRbx)
	if a and b and a.d == b.d then
		local masks = {}
		for _, source in {a.s, b.s} do
			for funnel, mask in source do
				if type(funnel) == "string" and type(mask) == "number" then
					masks[funnel] = bit32.bor(masks[funnel] or 0, math.floor(mask))
				end
			end
		end
		result.funRbx = {d = a.d, s = masks}
	elseif a and b then
		result.funRbx = if b.d > a.d then b else a
	else
		result.funRbx = a or b
	end
	return result
end

return Funnels
