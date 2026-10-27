--!strict
-- Player profile, device, segments, real Robux and progression snapshots
-- (docs/analytics/TRACKING_PLAN.md sections 5-7). A version 5 part of Analytics:
-- the host calls every public method through Analytics:_Part. Observation only:
-- nothing here changes gameplay, every public method is pcall-guarded, and only
-- the spawned join lookups yield. Never stores names, display names or chat.
--
-- Per-session state lives in st.ap (this module only); st.dev, st.tier and
-- st.idleSeconds are shared with the host. Profile fields (all optional, old
-- profiles load unchanged): dev, devices, geo, age, premium, followed,
-- friendsInServer, joinSource, active, idle, life, snap, lastExit, log,
-- robuxActual, robuxEstimate, robuxByKey, lastPurchase, firstPurchaseDevice.
local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local AnalyticsService = game:GetService("AnalyticsService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog = require(Shared.PetCatalog)
local Schema = require(script.Parent.AnalyticsSchema)

local AnalyticsPlayer = {}
AnalyticsPlayer.__index = AnalyticsPlayer

-- Lifetime counters kept in profile.life (merged per key with max).
AnalyticsPlayer.LifeKeys = {
	"rolls", "buys", "rareBuys", "fuses", "giants", "chickenLevels", "upgrades", "research", "rebirths",
	"missionsWon", "campsWon", "earned", "spent", "robux", "sold", "crates", "purchases",
}

local CF1 = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
local CF2 = Enum.AnalyticsCustomFieldKeys.CustomField02.Name
local CF3 = Enum.AnalyticsCustomFieldKeys.CustomField03.Name
local LOG_LIMIT = 10      -- sessions kept in profile.log
local FRIEND_CHECKS = 10  -- IsFriendsWith calls per join
local PERF_SAMPLES = 3    -- later reports averaged to refine the device tier
local KEY_LIMIT = 40      -- distinct robuxByKey entries kept per profile
local TOKEN_LIMIT = 16    -- client report strings
local warned = false

-- Successful request -> lifetime counter.
local ACTION_LIFE = {
	Roll = "rolls", Buy = "buys", Merge = "fuses", MergeAll = "fuses", UpgradeChicken = "chickenLevels",
	CashUpgrade = "upgrades", BoardUpgrade = "upgrades", BuyUpgrade = "upgrades", Luck = "upgrades", Income = "upgrades", Expand = "upgrades",
	StartResearch = "research", Rebirth = "rebirths", Sell = "sold", OpenCrate = "crates",
} :: {[string]: string}
local IGNORED_ACTIONS = {Sync = true, TutorialSignal = true, ClientReport = true, ClientEvents = true} :: {[string]: boolean}
local GIANT_OUTCOMES = {NewGiant = true, Giant = true, NewColossal = true, Colossal = true} :: {[string]: boolean}
local RARITY_RANK = {} :: {[string]: number}
for index, name in Schema.Rarities do RARITY_RANK[name] = index end

local function fields(a: string?, b: string?, c: string?)
	local result = {}
	if a then result[CF1] = string.sub(a, 1, 50) end
	if b then result[CF2] = string.sub(b, 1, 50) end
	if c then result[CF3] = string.sub(c, 1, 50) end
	return result
end

local function finite(value: any, low: number, high: number): number?
	if type(value) ~= "number" or value ~= value then return nil end
	return math.clamp(value, low, high)
end

local function num(value: any): number
	return if type(value) == "number" and value == value then value else 0
end

-- Short client strings: <= 16 chars of [%w%-_], else nil.
local function token(value: any): string?
	if type(value) ~= "string" or #value == 0 or #value > TOKEN_LIMIT then return nil end
	if string.find(value, "[^%w%-_]") then return nil end
	return value
end

local function yesNo(value: boolean): string
	return if value then "yes" else "no"
end

local function cleanKey(value: any): string
	local text = string.sub((string.gsub(tostring(value), "[^%w_]", "")), 1, 32)
	return if #text > 0 then text else "Unknown"
end

local function rarityOf(species: any): string?
	if type(species) ~= "string" then return nil end
	local definition = (Catalog :: any)[species]
	if type(definition) ~= "table" or type(definition.rarity) ~= "string" then return nil end
	return definition.rarity
end

local function countTrue(map: any): number
	local n = 0
	if type(map) == "table" then
		for _, value in map do if value then n += 1 end end
	end
	return n
end

local function addNumber(target: any, name: string, n: number)
	if n == 0 then return end
	target[name] = num(target[name]) + n
end

local function tableField(target: any, name: string): any
	local value = target[name]
	if type(value) ~= "table" then value = {}; target[name] = value end
	return value
end

local function newPending(): any
	return {life = {}, robuxByKey = {}}
end

-- Per-session state for this module (created lazily so any call order is safe).
local function state(st: any): any
	local ap = st.ap
	if type(ap) ~= "table" then
		ap = {pending = newPending(), menus = {}, menuSeq = 0, perf = {}, mem = 0, earned = 0, robux = 0,
			purchases = 0, resolved = false, left = false}
		st.ap = ap
	end
	if type(st.idleSeconds) ~= "number" then st.idleSeconds = 0 end
	return ap
end

local function platformOf(st: any): string
	local platform = st.platform
	if type(platform) == "string" and Schema.Platforms[platform] then return platform end
	local dev = st.dev
	if type(dev) == "table" and type(dev.platform) == "string" and Schema.Platforms[dev.platform] then return dev.platform end
	return "Unknown"
end

local function tierOf(st: any): string
	local dev = st.dev
	return if type(dev) == "table" and type(dev.tier) == "string" then dev.tier else "Unknown"
end

local function screenClass(dev: any): string
	local short = math.min(num(dev.vx), num(dev.vy))
	if short <= 0 then return "unknown" end
	return if short < 500 then "small" elseif short < 800 then "medium" else "large"
end

-- Device tier ------------------------------------------------------------------------
-- Roblox exposes no device model, so this scores proxies (TRACKING_PLAN section 0):
--   Phones/tablets (score starts at 0):
--     -1 phone viewport long side < 700 (iPhone 6/7/8/SE class, old small Androids)
--     +1 tablet long side >= 1180 (iPad Air/Pro class; 1024 iPads score 0)
--     +1 safe-area inset >= 20 px (notch / Dynamic Island / punch-hole: ~2018+ phones)
--     +1 client memory in use >= 1500 MB (Roblox only grows that far on high-RAM devices;
--        low memory is not penalized because usage is still low right after loading)
--   Desktop/Console/VR (score starts at 1): +1 viewport long side >= 2500 (large monitor)
--   Frame rate, only once refined (average of up to 3 reports after the loading one):
--     mobile  < 25 fps -2, < 40 -1, >= 55 +1;  others < 30 -2, < 45 -1, >= 55 +1
--   Saved graphics quality (0 = Automatic): manual 1..3 -1, manual >= 8 +1.
--   score <= -1 Low, score >= 2 High, else Mid. Missing/unknown platform: Unknown.
-- The tier counted in client.tier.* is the first-report (static) tier; the refined
-- tier is what the profile, Robux segments and PlayerSegment/seg.session.tier use.
function AnalyticsPlayer.DeviceTier(dev: any): string
	if type(dev) ~= "table" then return "Unknown" end
	local platform = dev.platform
	if type(platform) ~= "string" or not Schema.Platforms[platform] or platform == "Unknown" then return "Unknown" end
	local long = math.max(num(dev.vx), num(dev.vy))
	local quality = num(dev.quality)
	local fps = if type(dev.fps) == "number" and dev.fps == dev.fps then dev.fps else nil
	local score = 0
	if platform == "Mobile" or platform == "Tablet" then
		if platform == "Mobile" and long > 0 and long < 700 then score -= 1 end
		if platform == "Tablet" and long >= 1180 then score += 1 end
		if num(dev.inset) >= 20 then score += 1 end
		if num(dev.mem) >= 1500 then score += 1 end
		if fps then
			if fps < 25 then score -= 2 elseif fps < 40 then score -= 1 elseif fps >= 55 then score += 1 end
		end
	else
		score = 1
		if long >= 2500 then score += 1 end
		if fps then
			if fps < 30 then score -= 2 elseif fps < 45 then score -= 1 elseif fps >= 55 then score += 1 end
		end
	end
	if quality >= 1 and quality <= 3 then score -= 1 elseif quality >= 8 then score += 1 end
	return if score <= -1 then "Low" elseif score >= 2 then "High" else "Mid"
end

local function refineDevice(st: any)
	local ap, dev = state(st), st.dev
	if type(dev) ~= "table" or #ap.perf == 0 then return end
	local sum = 0
	for _, fps in ap.perf do sum += fps end
	dev.fps = math.floor(sum / #ap.perf + 0.5)
	if ap.mem > 0 then dev.mem = math.floor(ap.mem) end
	dev.tier = AnalyticsPlayer.DeviceTier(dev)
	st.tier = dev.tier
	ap.refined = true
end

-- Profile writes ------------------------------------------------------------------------

local function writeContext(st: any, profile: any)
	local ap = state(st)
	if ap.geo then profile.geo = ap.geo end
	if ap.age then profile.age = ap.age end
	if ap.premium ~= nil then profile.premium = ap.premium end
	if ap.followed ~= nil then profile.followed = ap.followed end
	if ap.joinSource then profile.joinSource = ap.joinSource end
	if ap.friends then profile.friendsInServer = math.max(num(profile.friendsInServer), ap.friends) end
end

local function writeDevice(st: any, profile: any)
	local ap, dev = state(st), st.dev
	if type(dev) ~= "table" then return end
	profile.dev = table.clone(dev)
	if ap.deviceCounted then return end
	ap.deviceCounted = true
	local devices = tableField(profile, "devices")
	devices[dev.platform] = num(devices[dev.platform]) + 1
end

local function payerCounts(host: any, st: any, tier: string, platform: string)
	local ledger = host.ledger
	ledger:Count("robux.payer.tier." .. tier)
	ledger:Count("robux.payer|" .. platform)
	ledger:Top("robux.payer.geo", state(st).geo or "??")
end

local function addByKey(target: any, key: string, amount: number)
	local byKey = tableField(target, "robuxByKey")
	if byKey[key] == nil then
		local count = 0
		for _ in byKey do count += 1 end
		if count >= KEY_LIMIT then key = "Other" end
	end
	byKey[key] = num(byKey[key]) + amount
end

-- Called once the host resolved st.profile (or gave up). Folds what this session
-- recorded before the profile arrived. Idempotent.
local function resolve(host: any, st: any)
	local ap = state(st)
	if ap.resolved then return end
	ap.resolved = true
	local profile = st.profile
	if type(profile) ~= "table" then return end -- store unreachable: nothing to save this session
	ap.prevPaid = num(profile.purchases) > 0 or num(profile.robuxActual) > 0 or num(profile.robuxEstimate) > 0
		or profile.firstPurchase ~= nil
	local pending = ap.pending
	ap.pending = newPending()
	local life = tableField(profile, "life")
	for key, n in pending.life do life[key] = num(life[key]) + n end
	addNumber(profile, "robuxActual", num(pending.robuxActual))
	addNumber(profile, "robuxEstimate", num(pending.robuxEstimate))
	for key, n in pending.robuxByKey do addByKey(profile, key, n) end
	if pending.lastPurchase then profile.lastPurchase = math.max(num(profile.lastPurchase), pending.lastPurchase) end
	if pending.firstPurchaseDevice and not ap.prevPaid and profile.firstPurchaseDevice == nil then
		profile.firstPurchaseDevice = pending.firstPurchaseDevice
	end
	writeContext(st, profile)
	writeDevice(st, profile)
	local first = ap.firstPending
	ap.firstPending = nil
	if first and not ap.prevPaid then payerCounts(host, st, first.tier, first.platform) end
end

-- Where additive data goes: the profile once resolved, else the session's pending copy.
local function sink(host: any, st: any): any
	if type(st.profile) == "table" then
		resolve(host, st)
		return st.profile
	end
	return state(st).pending
end

local function addLife(host: any, st: any, key: string, n: number)
	if n <= 0 then return end
	local life = tableField(sink(host, st), "life")
	life[key] = num(life[key]) + n
end

local function addIdle(st: any, seconds: number, sessionSeconds: number)
	st.idleSeconds = math.clamp(num(st.idleSeconds) + math.max(0, seconds), 0, math.max(0, sessionSeconds))
end

-- The most recently opened menu that is still open (the HUD is always open).
local function openMenu(ap: any): string?
	local best, bestSeq = nil, -1
	for menu, seq in ap.menus do
		if menu ~= "Hud" and seq > bestSeq then best, bestSeq = menu, seq end
	end
	return best
end

-- Progression snapshot (Schema.StateSnapshot). Live session values first, the last
-- client snapshot (st.lastState) as fallback:
--   rebirths    session.rebirths | state.rebirth.rank
--   eggSpeed    session.eggSpeedLevel | boardUpgrades.EggSpeed.level
--   eggValue    session.incomeLevel | state.incomeLevel | boardUpgrades.EggValue.level
--   luck        session.luck | state.luck
--   rollSlots   session.rollSlotsUnlocked | session.rollSlotCount | state.rollSlotCount
--   plotLevel   session.plotSizeLevel | boardUpgrades.PlotSize.level
--   armySize    state.capacity (includes the Bigger Army pass) | session.capacity
--   flock       owned chickens: session.pets | state.count
--   research    completed research nodes, excluding the free Start node
--   campsWon    state.campsWon | session.firstWins
--   missionsWon max(profile life.missionsWon, operation wins in state.operations.wins)
--   coins       session.coins | state.coins
--   power       state.power (army power)
--   bestRarity  highest Schema.Rarities rank (1 Common .. 7 Secret) among owned chickens
--   passes      owned passes in state.shop.owned | session.entitlements
--   indexFound  different chickens in the Index: session.discovered | state.discovered (version 16)
local function snapshot(host: any, st: any, session: any): {[string]: number}
	local stateValue: any = if type(st.lastState) == "table" then st.lastState else {}
	local s: any = if type(session) == "table" then session else {}
	local boards: any = if type(stateValue.boardUpgrades) == "table" then stateValue.boardUpgrades else {}
	local function first(...: any): number?
		for i = 1, select("#", ...) do
			local value = select(i, ...)
			if type(value) == "number" and value == value then return math.max(0, math.floor(value)) end
		end
		return nil
	end
	local function board(key: string): any
		local entry = boards[key]
		return if type(entry) == "table" then entry.level else nil
	end
	local rebirth: any = if type(stateValue.rebirth) == "table" then stateValue.rebirth else {}
	local snap = {} :: {[string]: number}
	snap.rebirths = first(s.rebirths, rebirth.rank) :: any
	snap.eggSpeed = first(s.eggSpeedLevel, board("EggSpeed")) :: any
	snap.eggValue = first(s.incomeLevel, stateValue.incomeLevel, board("EggValue")) :: any
	snap.luck = first(s.luck, stateValue.luck) :: any
	snap.rollSlots = first(s.rollSlotsUnlocked, s.rollSlotCount, stateValue.rollSlotCount) :: any
	snap.plotLevel = first(s.plotSizeLevel, board("PlotSize")) :: any
	snap.armySize = first(stateValue.capacity, s.capacity) :: any
	snap.flock = first(if type(s.pets) == "table" then countTrue(s.pets) else nil, stateValue.count) :: any
	local research: any = if type(s.research) == "table" then s.research
		elseif type(stateValue.research) == "table" then stateValue.research else nil
	if research and type(research.completed) == "table" then
		snap.research = countTrue(research.completed) - (if research.completed.Start then 1 else 0)
	end
	snap.campsWon = first(stateValue.campsWon, if type(s.firstWins) == "table" then countTrue(s.firstWins) else nil) :: any
	local life = sink(host, st).life
	local operations: any = stateValue.operations
	local operationWins = if type(operations) == "table" then countTrue(operations.wins) else 0
	snap.missionsWon = math.max(num(type(life) == "table" and life.missionsWon or 0), operationWins)
	snap.coins = first(s.coins, stateValue.coins) :: any
	snap.power = first(stateValue.power) :: any
	local best = 0
	local pets: any = if type(s.pets) == "table" then s.pets elseif type(stateValue.pets) == "table" then stateValue.pets else {}
	for _, pet in pets do
		if type(pet) == "table" then
			local rarity = rarityOf(pet.species)
			if rarity then best = math.max(best, RARITY_RANK[rarity] or 0) end
		end
	end
	if best > 0 then snap.bestRarity = best end
	local discovered: any = if type(s.discovered) == "table" then s.discovered
		elseif type(stateValue.discovered) == "table" then stateValue.discovered else nil
	if discovered then snap.indexFound = countTrue(discovered) end
	local shop: any = stateValue.shop
	if type(shop) == "table" and type(shop.owned) == "table" then
		snap.passes = countTrue(shop.owned)
	elseif type(s.entitlements) == "table" then
		snap.passes = countTrue(s.entitlements)
	end
	return snap
end

local function newerLog(a: any, b: any): boolean
	if #a ~= #b then return #a > #b end
	local function last(list: any): string
		local entry = list[#list]
		if type(entry) ~= "table" then return "" end
		return tostring(entry.day or "") .. string.format("%02d", num(entry.hourUTC))
	end
	return last(a) > last(b)
end

-- Public API -------------------------------------------------------------------------

function AnalyticsPlayer.new(analytics: any)
	return setmetatable({host = analytics}, AnalyticsPlayer)
end

function AnalyticsPlayer:_Guard(call: () -> ())
	local ok, why = pcall(call)
	if ok then return end
	pcall(function() self.host.ledger:Count("analytics.playerError") end)
	if not warned then
		warned = true
		warn("[AnalyticsPlayer] " .. tostring(why))
	end
end

-- Join context. Non-yielding; country and friends are looked up in a spawned thread.
function AnalyticsPlayer:Join(st: any, player: Player, session: any)
	self:_Guard(function()
		local host = self.host
		local ledger = host.ledger
		local ap = state(st)
		if ap.joined then return end
		ap.joined = true
		ap.lastActivity = host.clock()
		local okAge, age = pcall(function() return player.AccountAge end)
		if okAge and type(age) == "number" then
			ap.age = Schema.Bucket("accountDays", math.max(0, age))
			ledger:Count("seg.age." .. ap.age)
		end
		local okPremium, premium = pcall(function() return player.MembershipType == Enum.MembershipType.Premium end)
		ap.premium = okPremium and premium == true
		ledger:Count("seg.session.premium." .. yesNo(ap.premium))
		local okFollow, follow = pcall(function() return player.FollowUserId end)
		ap.followed = okFollow and type(follow) == "number" and follow ~= 0
		local okJoin, joinData = pcall(function(): any return player:GetJoinData() end)
		local data: any = if okJoin and type(joinData) == "table" then joinData else {}
		local teleported = type(data.SourcePlaceId) == "number" and data.SourcePlaceId ~= 0
		ap.joinSource = if teleported then "teleport" elseif ap.followed then "follow" else "direct"
		-- Version 16 (October 27, WS7 SOCIAL_MOMENTS.md): a join from a Roblox invite
		-- ("inv:<inviterUserId>", FriendBoost:Invite) or a notification ("note:...").
		local launch = data.LaunchData
		if type(launch) == "string" and string.sub(launch, 1, 4) == "inv:" then
			ap.joinSource = "invite"
		elseif type(launch) == "string" and string.sub(launch, 1, 5) == "note:" then
			ap.joinSource = "notification"
		end
		ledger:Count("seg.join." .. ap.joinSource)
		local date: any = os.date("!*t", host.wall())
		ledger:Hist("session.hourUTC", "hour", date.hour)
		ledger:Count("session.weekday." .. (date.wday - 1))
		local okPlayers, list = pcall(function(): any return Players:GetPlayers() end)
		local others: any = if okPlayers and type(list) == "table" then list else {}
		ledger:Hist("seg.serverSize", "count", #others)
		st.serverSizeAtJoin = #others -- version 16 (WS7): the journey's sv
		task.spawn(function()
			self:_Guard(function()
				local okGeo, code = pcall(function(): any
					return LocalizationService:GetCountryRegionForPlayerAsync(player)
				end)
				local geo = if okGeo and type(code) == "string" and string.match(code, "^%a%a$") then string.upper(code) else nil
				ap.geo = geo
				ledger:Top("seg.geo", geo or "??")
				if geo and type(st.profile) == "table" and not ap.left then st.profile.geo = geo end
				local friends, checks = 0, 0
				for _, other in others do
					if checks >= FRIEND_CHECKS then break end
					if other ~= player then
						checks += 1
						local okFriend, isFriend = pcall(function(): any return player:IsFriendsWith(other.UserId) end)
						if okFriend and isFriend == true then friends += 1 end
					end
				end
				ap.friends = math.max(ap.friends or 0, friends)
				ledger:Hist("seg.friendsInServer", "count", friends)
				if type(st.profile) == "table" and not ap.left then
					st.profile.friendsInServer = math.max(num(st.profile.friendsInServer), friends)
				end
			end)
		end)
	end)
end

function AnalyticsPlayer:Profile(st: any)
	self:_Guard(function() resolve(self.host, st) end)
end

-- Every ClientReport (raw, untrusted). The first one carrying a platform defines
-- st.dev; later perf reports refine the tier.
function AnalyticsPlayer:Device(st: any, report: any)
	self:_Guard(function()
		if type(report) ~= "table" then return end
		local host = self.host
		local ap = state(st)
		local fps = finite(report.fps, 0, 1000)
		local mem = finite(report.memMb, 0, 100000)
		if mem then ap.mem = math.max(ap.mem, mem) end
		if type(st.dev) == "table" then
			-- The first report's frame rate includes loading, so it is not averaged.
			if fps and not ap.refined and #ap.perf < PERF_SAMPLES then
				table.insert(ap.perf, fps)
				if #ap.perf >= PERF_SAMPLES then refineDevice(st) end
			end
			return
		end
		local platform = report.platform
		if type(platform) ~= "string" or not Schema.Platforms[platform] or platform == "Unknown" then return end
		local vx = math.floor(finite(report.screenX, 0, 10000) or 0)
		local vy = math.floor(finite(report.screenY, 0, 10000) or 0)
		local inset = 0
		for _, name in {"insetTop", "insetBottom", "insetLeft", "insetRight"} do
			inset = math.max(inset, finite(report[name], 0, 1000) or 0)
		end
		local quality = finite(report.quality, 0, 21)
		local dev: any = {
			platform = platform, vx = vx, vy = vy, inset = math.floor(inset),
			quality = if quality then math.floor(quality) else nil, mem = if mem then math.floor(mem) else nil,
			touch = report.touch == true, kb = report.keyboard == true, pad = report.gamepad == true,
			accel = report.accel == true, gyro = report.gyro == true, reducedMotion = report.reducedMotion == true,
			locale = token(report.locale), sysLocale = token(report.sysLocale),
			input = token(report.preferredInput), os = token(report.osHint),
		}
		dev.tier = AnalyticsPlayer.DeviceTier(dev)
		st.dev, st.tier = dev, dev.tier
		local ledger = host.ledger
		ledger:Count("client.tier." .. dev.tier)
		if (platform == "Mobile" or platform == "Tablet") and vx > 0 and vy > 0 then
			-- Long x short so one phone in either orientation is one key.
			ledger:Top("client.viewport", math.max(vx, vy) .. "x" .. math.min(vx, vy))
		end
		if dev.locale then ledger:Top("client.locale", dev.locale) end
		if dev.quality then ledger:Count("client.quality." .. dev.quality) end
		ledger:Count("client.inset." .. yesNo(dev.inset > 0))
		if type(st.profile) == "table" then writeDevice(st, st.profile) end
		local player, tier, class, memory = st.player, dev.tier, screenClass(dev), math.floor(mem or 0)
		if player then
			host:_Queue(false, "custom:DeviceProfile", function()
				AnalyticsService:LogCustomEvent(player, "DeviceProfile", memory, fields(platform, tier, class))
			end)
		end
	end)
end

function AnalyticsPlayer:Action(st: any, session: any, action: string, ok: boolean, request: any, info: any)
	self:_Guard(function()
		if type(action) ~= "string" or #action > 40 or IGNORED_ACTIONS[action] then return end
		local host = self.host
		local ap = state(st)
		ap.lastActivity = host.clock()
		ap.action = if ok then action else action .. "!"
		if not ok then return end
		local key = ACTION_LIFE[action]
		if not key then return end
		local n = 1
		if action == "MergeAll" and type(request) == "table" and type(request.triples) == "table" then
			n = math.clamp(#request.triples, 1, 50)
		elseif action == "Sell" and type(request) == "table" and type(request.petIds) == "table" then
			n = math.clamp(#request.petIds, 1, 200)
		end
		addLife(host, st, key, n)
		if action == "Buy" then
			local rarity = if type(info) == "table" and type(info.rarity) == "string" then info.rarity else nil
			if not rarity and type(info) == "table" and info.petId and type(session) == "table" and type(session.pets) == "table" then
				local pet = session.pets[info.petId]
				rarity = if type(pet) == "table" then rarityOf(pet.species) else nil
			end
			if rarity and (RARITY_RANK[rarity] or 0) >= RARITY_RANK.Rare then addLife(host, st, "rareBuys", 1) end
		end
	end)
end

-- Validated client UI events: idle time and the menu open at exit.
function AnalyticsPlayer:Client(st: any, name: string, detail: string?, value: number?)
	self:_Guard(function()
		if type(name) ~= "string" then return end
		local host = self.host
		local ap = state(st)
		local now = host.clock()
		if name == "idle.start" then
			if not ap.idleAt then ap.idleAt = now end
			return
		end
		ap.lastActivity = now
		if name == "idle.end" then
			-- The client's value is authoritative; without it, estimate from idle.start.
			local seconds = finite(value, 0, 86400)
				or (if ap.idleAt then now - ap.idleAt + Schema.IdleSeconds else 0)
			ap.idleAt = nil
			addIdle(st, seconds, now - num(st.joinedAt))
		elseif name == "menu.open" and type(detail) == "string" then
			ap.menuSeq += 1
			ap.menus[string.sub(detail, 1, 24)] = ap.menuSeq
		elseif name == "menu.close" and type(detail) == "string" then
			ap.menus[string.sub(detail, 1, 24)] = nil
		end
	end)
end

-- Server events and forwarded LaunchCount names. Only giant.fuse.* and mission.won.*
-- feed lifetime counters (giant.result / mission.result repeat them; rebirths come
-- from the Rebirth action).
function AnalyticsPlayer:Server(st: any, name: string, detail: string?, value: number?)
	self:_Guard(function()
		if type(name) ~= "string" or #name > 64 then return end
		local full = if type(detail) == "string" and #detail > 0 then name .. "." .. detail else name
		if string.match(full, "^mission%.won$") or string.match(full, "^mission%.won%.") then
			addLife(self.host, st, "missionsWon", 1)
			return
		end
		local outcome = string.match(full, "^giant%.fuse%.(%a+)$")
		if outcome and GIANT_OUTCOMES[outcome] then addLife(self.host, st, "giants", 1) end
	end)
end

function AnalyticsPlayer:Income(st: any, source: string, amount: number)
	self:_Guard(function()
		if type(source) == "string" and Schema.IgnoredSources[source] then return end
		local value = finite(amount, 0, 1e18)
		if not value or value <= 0 then return end
		local ap = state(st)
		ap.earned += value
		addLife(self.host, st, "earned", value)
	end)
end

function AnalyticsPlayer:Spent(st: any, amount: number, sku: string)
	self:_Guard(function()
		local value = finite(amount, 0, 1e18)
		if value and value > 0 then addLife(self.host, st, "spent", value) end
	end)
end

function AnalyticsPlayer:Purchase(st: any, kind: string, key: string, robux: number, actual: boolean)
	self:_Guard(function()
		local host = self.host
		local ledger = host.ledger
		local ap = state(st)
		local cleanKind = if kind == "pass" then "pass" else "product"
		local itemKey = cleanKey(key)
		local amount = math.floor(finite(robux, 0, 1e7) or 0)
		local firstInSession = ap.purchases == 0
		ap.purchases += 1
		ap.lastActivity = host.clock()
		addLife(host, st, "purchases", 1)
		local target = sink(host, st)
		local tier, platform = tierOf(st), platformOf(st)
		target.lastPurchase = math.max(num(target.lastPurchase), num(host.wall()))
		if firstInSession then
			if type(st.profile) == "table" then
				if not ap.prevPaid and target.firstPurchaseDevice == nil then target.firstPurchaseDevice = tier end
			elseif not ap.resolved then
				target.firstPurchaseDevice = tier
			end
		end
		if actual ~= true then
			-- Catalog estimate only (no receipt amount): keep it apart from real Robux.
			addNumber(target, "robuxEstimate", amount)
			return
		end
		ap.robux += amount
		addLife(host, st, "robux", amount)
		addNumber(target, "robuxActual", amount)
		addByKey(target, itemKey, amount)
		ledger:Count("robux.actual", amount)
		ledger:Count("robux.actual.n")
		ledger:Count("robux.actual." .. cleanKind .. "." .. itemKey, amount)
		ledger:Count("robux.actual|" .. platform, amount)
		ledger:Count("robux.actual.tier." .. tier, amount)
		ledger:Count("robux.actual.premium." .. yesNo(ap.premium == true), amount)
		ledger:Hist("robux.purchase", "robux", amount)
		-- First purchase ever: no purchase in earlier sessions (snapshotted when the
		-- profile resolved) and none earlier in this one.
		if firstInSession then
			if type(st.profile) == "table" then
				if not ap.prevPaid then payerCounts(host, st, tier, platform) end
			elseif not ap.resolved then
				ap.firstPending = {tier = tier, platform = platform}
			end
		end
		local player = st.player
		if player then
			host:_Queue(true, "custom:RobuxSpend", function()
				AnalyticsService:LogCustomEvent(player, "RobuxSpend", amount, fields(cleanKind, itemKey, tier))
			end)
		end
	end)
end

function AnalyticsPlayer:Progress(st: any, step: string, result: string)
	self:_Guard(function()
		if result == "firstWin" then addLife(self.host, st, "campsWon", 1) end
	end)
end

-- Session end, before the host saves the profile.
function AnalyticsPlayer:Leave(st: any, session: any)
	self:_Guard(function()
		local host = self.host
		local ledger = host.ledger
		local ap = state(st)
		if ap.left then return end
		resolve(host, st)
		ap.left = true
		local now, wall = host.clock(), num(host.wall())
		local seconds = math.max(0, now - num(st.joinedAt or now))
		-- Idle when leaving: the client's idle.start comes Schema.IdleSeconds after the last input.
		if ap.idleAt then
			addIdle(st, now - ap.idleAt + Schema.IdleSeconds, seconds)
			ap.idleAt = nil
		end
		local idle = math.clamp(num(st.idleSeconds), 0, seconds)
		local active = seconds - idle
		ledger:Hist("session.activeShare", "percent", if seconds > 0 then 100 * active / seconds else 100)
		ledger:Count("session.activeSeconds", math.floor(active))
		ledger:Count("session.idleSeconds", math.floor(idle))
		if not ap.refined then refineDevice(st) end
		local tier, platform = tierOf(st), platformOf(st)
		local profile = if type(st.profile) == "table" then st.profile else nil
		local payer = ap.purchases > 0 or ap.prevPaid == true
		ledger:Count("seg.session.tier." .. tier)
		ledger:Count("seg.payer.session." .. (if payer then "payer" else "non"))
		local menu = openMenu(ap)
		local action = ap.action
		ledger:Top("exit.menu", menu or "None")
		ledger:Top("exit.action", action or "None")
		local snap = snapshot(host, st, session)
		for name, kind in Schema.StateSnapshot do
			local value = snap[name]
			if type(value) == "number" then ledger:Hist("state." .. name, kind, value) end
		end
		local player = st.player
		if player then
			local minutes = math.floor(seconds / 6) / 10
			host:_Queue(false, "custom:PlayerSegment", function()
				AnalyticsService:LogCustomEvent(player, "PlayerSegment", minutes, fields(tier, if payer then "payer" else "non", platform))
			end)
		end
		if not profile then return end
		local okStage, stageValue = pcall(function(): any return host:_Stage(st) end)
		local stage = if okStage and type(stageValue) == "string" then stageValue else "?"
		local day = os.date("!%Y-%m-%d", wall) :: any
		local date: any = os.date("!*t", wall)
		writeContext(st, profile)
		writeDevice(st, profile)
		profile.active = math.floor(num(profile.active) + active)
		profile.idle = math.floor(num(profile.idle) + idle)
		profile.snap = snap
		profile.lastExit = {
			menu = menu, action = action,
			guide = if type(st.guideStep) == "string" then string.sub(st.guideStep, 1, 32) else nil,
			idleBefore = math.floor(math.max(0, now - num(ap.lastActivity or st.joinedAt))),
			seconds = math.floor(seconds), day = day, at = wall, coins = snap.coins, stage = stage,
		}
		local log = tableField(profile, "log")
		table.insert(log, {day = day, hourUTC = date.hour, s = math.floor(seconds), platform = platform,
			earned = math.floor(ap.earned), robux = ap.robux, stage = stage})
		while #log > LOG_LIMIT do table.remove(log, 1) end
	end)
end

-- Concurrent-session merge (called by Analytics.MergeProfile with its result).
function AnalyticsPlayer.MergeProfile(old: any, ours: any, result: any)
	if type(old) ~= "table" or type(ours) ~= "table" or type(result) ~= "table" then return end
	for _, name in {"active", "idle", "robuxActual", "robuxEstimate", "friendsInServer", "lastPurchase"} do
		local a, b = old[name], ours[name]
		if type(a) == "number" and (type(b) ~= "number" or a > b) then result[name] = a end
	end
	for _, name in {"life", "devices", "robuxByKey"} do
		local a, b = old[name], ours[name]
		if type(a) == "table" then
			local merged = if type(b) == "table" then table.clone(b) else {}
			for key, value in a do
				if type(value) == "number" and (type(merged[key]) ~= "number" or value > merged[key]) then merged[key] = value end
			end
			result[name] = merged
		end
	end
	-- First-ever facts keep the earliest copy; latest-session facts fall back to the old copy.
	if old.firstPurchaseDevice ~= nil then result.firstPurchaseDevice = old.firstPurchaseDevice end
	for _, name in {"dev", "geo", "age", "premium", "followed", "joinSource", "snap"} do
		if result[name] == nil and old[name] ~= nil then result[name] = old[name] end
	end
	if type(old.log) == "table" and (type(ours.log) ~= "table" or newerLog(old.log, ours.log)) then
		result.log = old.log
	end
	local oldExit, ourExit = old.lastExit, ours.lastExit
	if type(oldExit) == "table" and (type(ourExit) ~= "table" or num(oldExit.at) > num(ourExit.at)) then
		result.lastExit = oldExit
		if old.snap ~= nil then result.snap = old.snap end
	end
end

return AnalyticsPlayer
