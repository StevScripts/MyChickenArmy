--!strict
-- Version 15 Onboarding funnel (Schema.Onboarding; docs/analytics/ONBOARDING_FUNNEL.md).
-- A part of Analytics: the host calls every public method through Analytics:_Part, so
-- an error here only loses this funnel's data. Observation only; it never changes
-- gameplay. It owns Roblox's Onboarding dashboard and names the session stage
-- (Onboarding.Stage: "Ob:<step id>", "Post", "Untracked").
--
-- Fifteen hard steps in play order, each a saved or server fact, counted once per
-- player ever, only for fresh empty-start profiles. Per-session state lives in st.ob;
-- per-player state in profile.ob (step code -> play seconds when reached) and
-- profile.obRbx (the last step sent to Roblox). The file keeps its schema 11 name
-- (AnalyticsTutorial) so Analytics' part loading is unchanged; the schema 11-14
-- Tutorial funnel (tf.*, profile.tf) is history and is not recorded any more.
local AnalyticsService = game:GetService("AnalyticsService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Guide = require(Shared.TutorialGuide)
local UpgradeCatalog = require(Shared.UpgradeCatalog)
local Schema = require(script.Parent.AnalyticsSchema)

local Onboarding = {}
Onboarding.__index = Onboarding

local CF1 = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
local CF2 = Enum.AnalyticsCustomFieldKeys.CustomField02.Name
local Steps = Schema.Onboarding
local Index = Schema.OnboardingIndex
local LAST = #Steps

function Onboarding.new(host)
	return setmetatable({host = host}, Onboarding)
end

-- Concurrent-session merge (Analytics.MergeProfile): earliest time per step wins.
function Onboarding.MergeProfile(old: any, ours: any, result: any)
	if not old.ob and not ours.ob then return end
	local merged = table.clone(ours.ob or {})
	for code, seconds in old.ob or {} do
		if merged[code] == nil or (type(seconds) == "number" and seconds < merged[code]) then merged[code] = seconds end
	end
	result.ob = merged
	result.obRbx = math.max(old.obRbx or 0, ours.obRbx or 0)
end

local function code(index: number): string return Schema.StepCode(index) end

-- Fresh empty-start save: Analytics.FreshSave (guide never started, nothing rolled,
-- bought or won) and the October 23 introRebirth marker every new save carries since
-- the empty start. Older fresh saves (no marker) are never tracked here.
local function emptyStart(st): boolean
	local session = st.session
	return st.freshSave == true and type(session) == "table" and session.introRebirth ~= nil
end

function Onboarding:Join(st)
	-- at: step code -> seconds into this session (the sampled journey's step times).
	st.ob = {reached = {}, queue = {}, at = {}, next = 1, ready = false, tracked = false, done = false}
	self:Reach(st, Index.Joined)
end

-- The ledger profile is known: decide tracking, then record what waited for it.
function Onboarding:Profile(st)
	local ob = st.ob
	if not ob then return end
	local profile = st.profile
	if profile and emptyStart(st) and not profile.ob then profile.ob = {} end
	-- Without a profile (store unreachable) the save alone decides, so Roblox's funnel
	-- still works; the ledger then counts this session's steps without once-ever dedupe.
	ob.tracked = (profile ~= nil and profile.ob ~= nil) or (profile == nil and emptyStart(st))
	ob.next = (if profile then profile.obRbx or 0 else 0) + 1
	ob.ready = true
	if not ob.tracked then ob.queue = {}; return end
	for _, index in ob.queue do self:Record(st, index) end
	ob.queue = {}
	self:Record(st, Index.Loaded)
	self:Send(st, self:Furthest(st))
end

function Onboarding:Reached(st, index: number): boolean
	local ob = st.ob
	if ob.reached[index] then return true end
	local profile = st.profile
	return profile ~= nil and profile.ob ~= nil and profile.ob[code(index)] ~= nil
end

-- A step is true now. Counted once per player ever; Roblox gets it and any earlier
-- step it has not seen yet.
function Onboarding:Reach(st, index: number?)
	local ob = st.ob
	if not index or not ob then return end
	if not ob.ready then
		if not table.find(ob.queue, index) then table.insert(ob.queue, index) end
		return
	end
	if not ob.tracked then return end
	self:Record(st, index)
	self:Send(st, index)
end

function Onboarding:Record(st, index: number)
	local ob, host, profile = st.ob, self.host, st.profile
	if self:Reached(st, index) then ob.reached[index] = true; return end
	ob.reached[index] = true
	local nn = code(index)
	local now: number = host.clock()
	ob.at[nn] = math.floor(now - (tonumber(st.joinedAt) or now))
	local play: number = host:_Play(st)
	local ledger = host.ledger
	ledger:Count("ob.reach." .. nn)
	ledger:Count("ob.reach." .. nn .. "|" .. tostring(st.platform or "Unknown"))
	ledger:Hist("ob.t." .. nn, "seconds", play)
	if profile and profile.ob then profile.ob[nn] = math.floor(play) end
	host:_Trail(st, "ob:" .. Steps[index].id)
end

-- Roblox onboarding steps go out strictly in order, each only once it and every earlier
-- step are truly reached (October 25: no gap fill). A step reached early waits for the
-- missing one, so a dashboard bar never counts a step the player did not do.
function Onboarding:Send(st, _upTo: number)
	local ob = st.ob
	if not ob.tracked or not ob.ready then return end
	local player = st.player
	while ob.next <= LAST and self:Reached(st, ob.next) do
		local index = ob.next
		local name = Schema.OnboardingName(index)
		local fields = {[CF1] = string.sub(tostring(Config.Version), 1, 50), [CF2] = string.sub(tostring(st.platform or "Unknown"), 1, 50)}
		self.host:_Queue(true, "onboarding:" .. name, function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, index, name, fields)
		end)
		ob.next += 1
		if st.profile then st.profile.obRbx = math.max(st.profile.obRbx or 0, index) end
	end
end

-- Every step is a saved or server fact, read from the session on each snapshot
-- (Analytics:Observe, at most twice a second per player).
function Onboarding:State(st: any, session: any, _state: any)
	local ob = st.ob
	if not ob or not ob.ready or not ob.tracked or ob.done then return end
	local t: any = session.tutorial or {}
	local tree = session.upgradeTree
	local rolls = Guide.RollCount(t)
	local eggs = Guide.CollectedEggCount(t)
	local checks = {
		Rolled = rolls >= 1,
		ChickenTaken = t.bought == true,
		Egg1 = eggs >= 1,
		Eggs3 = eggs >= Guide.EggGoal,
		Sold = t.soldEggs == true,
		StartClaimed = t.startClaimed == true,
		PlotExpanded = UpgradeCatalog.Tier(tree, "Flock") >= 1,
		RolledAgain = rolls >= 2,
		TutorialDone = t.coreDone == true or t.guideCompleted == true,
		VacuumBought = UpgradeCatalog.Tier(tree, "EggVacuum") >= 1,
		Rebirth0 = session.introRebirth == "done",
		CluckCampWon = (session.firstWins or {})[1] == true,
		Rebirth1 = (session.rebirths or 0) >= 1,
	}
	local all: boolean = true
	for index, step in Steps do
		if checks[step.id] and not ob.reached[index] then self:Reach(st, index) end
		if not self:Reached(st, index) then all = false end
	end
	ob.done = all
end

-- Schema 11-14 had client-reported soft steps; every step is a server fact now.
function Onboarding:Signal(_st, _signal: string) end

-- Furthest step this player ever reached (0 = none yet).
function Onboarding:Furthest(st): number
	if not st.ob then return 0 end
	for index = LAST, 1, -1 do
		if self:Reached(st, index) then return index end
	end
	return 0
end

-- Session stage for Analytics (custom event fields, Robux and economy splits,
-- journeys): "Ob:<furthest step id>" before the last step, "Post" after it,
-- "Untracked" for players this funnel does not track.
function Onboarding:Stage(st): string
	local ob = st.ob
	if not ob or (ob.ready and not ob.tracked) then return "Untracked" end
	if self:Reached(st, LAST) then return "Post" end
	return "Ob:" .. Steps[math.max(self:Furthest(st), 1)].id
end

-- Where a session ended, by the player's furthest step, until the last step is reached.
function Onboarding:Leave(st, _session)
	local ob = st.ob
	if not ob or not ob.ready or not ob.tracked or self:Reached(st, LAST) then return end
	self.host.ledger:Count("ob.exit." .. code(self:Furthest(st)))
end

return Onboarding
