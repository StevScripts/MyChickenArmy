--!strict
-- Version 11 Tutorial funnel (Schema.TutorialFunnel; docs/analytics/TUTORIAL_FUNNEL.md).
-- A part of Analytics: the host calls every public method through Analytics:_Part, so
-- an error here only loses this funnel's data. Observation only; it never changes
-- gameplay. It owns Roblox's Onboarding dashboard from version 11 on.
--
-- Per-session state lives in st.tf; per-player state in profile.tf (step code ->
-- play seconds when reached), profile.tfSkip (code -> true when passed over) and
-- profile.tfRbx (the last step sent to Roblox).
local AnalyticsService = game:GetService("AnalyticsService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Guide = require(Shared.TutorialGuide)
local Schema = require(script.Parent.AnalyticsSchema)

local Tutorial = {}
Tutorial.__index = Tutorial

local CF1 = Enum.AnalyticsCustomFieldKeys.CustomField01.Name
local CF2 = Enum.AnalyticsCustomFieldKeys.CustomField02.Name
local Steps = Schema.TutorialFunnel
local Index = Schema.TutorialFunnelIndex

function Tutorial.new(host)
	return setmetatable({host = host}, Tutorial)
end

-- Concurrent-session merge (Analytics.MergeProfile): earliest time per step wins.
function Tutorial.MergeProfile(old: any, ours: any, result: any)
	if not old.tf and not ours.tf then return end
	local merged = table.clone(ours.tf or {})
	for code, seconds in old.tf or {} do
		if merged[code] == nil or (type(seconds) == "number" and seconds < merged[code]) then merged[code] = seconds end
	end
	local skipped = table.clone(ours.tfSkip or {})
	for code in old.tfSkip or {} do skipped[code] = true end
	result.tf, result.tfSkip = merged, skipped
	result.tfRbx = math.max(old.tfRbx or 0, ours.tfRbx or 0)
end

local function code(index: number): string return Schema.StepCode(index) end

function Tutorial:Join(st)
	st.tf = {reached = {}, skipped = {}, queue = {}, lastAt = nil, next = 1, ready = false}
	self:Reach(st, Index.Joined)
end

-- The ledger profile is known: decide tracking, then record what waited for it.
function Tutorial:Profile(st)
	local tf = st.tf
	if not tf then return end
	local profile = st.profile
	if profile and st.freshSave and not profile.tf then profile.tf, profile.tfSkip = {}, {} end
	tf.tracked = st.freshSave == true or (profile ~= nil and profile.tf ~= nil)
	tf.next = (if profile then profile.tfRbx or 0 else 0) + 1
	tf.ready = true
	if not tf.tracked then return end
	for _, index in tf.queue do self:Record(st, index) end
	tf.queue = {}
	self:Reach(st, Index.Loaded)
	self:Send(st)
end

function Tutorial:Reached(st, index: number): boolean
	local tf = st.tf
	if tf.reached[index] then return true end
	local profile = st.profile
	return profile ~= nil and profile.tf ~= nil and profile.tf[code(index)] ~= nil
end

function Tutorial:Skipped(st, index: number): boolean
	local profile = st.profile
	return st.tf.skipped[index] == true or (profile ~= nil and profile.tfSkip ~= nil and profile.tfSkip[code(index)] == true)
end

function Tutorial:Reach(st, index: number?)
	local tf = st.tf
	if not index or not tf or tf.reached[index] then return end
	if not tf.ready then
		if not table.find(tf.queue, index) then table.insert(tf.queue, index) end
		return
	end
	if not tf.tracked then return end
	self:Record(st, index)
	self:Send(st)
end

-- One step, once per player: reach counts, timings, cohort, then soft steps passed by.
function Tutorial:Record(st, index: number)
	local tf, host, profile = st.tf, self.host, st.profile
	if self:Reached(st, index) then tf.reached[index] = true; return end
	tf.reached[index] = true
	local nn = code(index)
	local play: number = host:_Play(st)
	local ledger = host.ledger
	ledger:Count("tf.reach." .. nn)
	ledger:Count("tf.reach." .. nn .. "|" .. tostring(st.platform or "Unknown"))
	ledger:Hist("tf.t." .. nn, "seconds", play)
	if tf.lastAt then ledger:Hist("tf.d." .. nn, "seconds", math.max(0, play - tf.lastAt)) end
	tf.lastAt = play
	if (st.sessionIndex or 1) <= 1 then ledger:Count("tf.s1." .. nn) end
	-- A later step means every earlier soft step not seen was passed over.
	for earlier = index - 1, 1, -1 do
		if Steps[earlier].kind == "soft" and not self:Reached(st, earlier) and not self:Skipped(st, earlier) then
			tf.skipped[earlier] = true
			ledger:Count("tf.skip." .. code(earlier))
			if profile and profile.tfSkip then profile.tfSkip[code(earlier)] = true end
		end
	end
	if index > 1 and not self:Reached(st, index - 1) and not self:Skipped(st, index - 1) then
		ledger:Count("tf.gap." .. nn)
	end
	if profile and profile.tf then
		profile.tf[nn] = math.floor(play)
		if profile.firstDay then ledger:Cohort(profile.firstDay, "tf." .. nn) end
	end
	host:_Trail(st, "tf:" .. Steps[index].id)
end

-- Roblox onboarding steps go out strictly in order. Skipped soft steps are passed
-- over; a missing hard step waits until Schema.RobloxGapRelease later steps happen.
function Tutorial:Send(st)
	local tf = st.tf
	if not tf.tracked or not tf.ready then return end
	local total = #Steps
	while tf.next <= total do
		local index = tf.next
		if not self:Reached(st, index) then
			if not self:Skipped(st, index) then
				local later = 0
				for j = index + 1, total do if self:Reached(st, j) then later += 1 end end
				if later < Schema.RobloxGapRelease then return end
				self.host.ledger:Count("tf.robloxGapFill." .. code(index))
			end
			tf.next += 1
			continue
		end
		local player, name = st.player, Schema.TutorialFunnelName(index)
		local fields = {[CF1] = string.sub(tostring(Config.Version), 1, 50), [CF2] = string.sub(tostring(st.platform or "Unknown"), 1, 50)}
		self.host:_Queue(true, "onboarding:" .. name, function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, index, name, fields)
		end)
		tf.next += 1
		if st.profile then st.profile.tfRbx = math.max(st.profile.tfRbx or 0, index) end
	end
end

-- Steps read from the save and the server snapshot.
function Tutorial:State(st, session, state)
	local tf = st.tf
	if not tf or not tf.ready or not tf.tracked then return end
	st.tfFacts = Guide.Facts(state)
	local facts: any, t: any = st.tfFacts, session.tutorial or {}
	local eggs = Guide.CollectedEggCount(t)
	local vacuumed = Guide.VacuumEggCount(t)
	local wins = session.firstWins or {}
	local daily = session.daily
	local checks = {
		Egg1 = eggs >= 1, Egg2 = eggs >= 2, Egg3 = eggs >= Guide.EggGoal,
		Sold = t.soldEggs == true,
		FlockBought = facts.Flock == true and facts.Collect == true,
		LeverPulled = t.rolled == true,
		ChickenTaken = facts.Recruit == true,
		CoreDone = facts.Core == true,
		DailyDay1 = facts.Core == true and type(daily) == "table" and (daily.lastDay or 0) > 0,
		VacuumClaimed = facts.Core == true and facts.Vacuum == true,
		Vacuum10 = facts.Core == true and vacuumed >= math.min(10, Guide.VacuumGoal),
		Vacuum20 = facts.Core == true and vacuumed >= Guide.VacuumGoal,
		VacuumSold = facts.Core == true and facts.VacuumSell == true,
		ArmySizeBought = facts.Core == true and facts.Expand == true,
		ArmyPicked = facts.Core == true and facts.Expand == true and facts.Select == true,
		ArmySent = t.guideDeployed == true,
		CluckCampWon = facts.Win == true,
		FortRoostWon = wins[2] == true,
		IronbeakWon = wins[3] == true,
		KingCleared = session.kingCleared == true,
		Rebirth1 = (session.rebirths or 0) >= 1,
	}
	-- Soft steps with a server fact (Daily Rewards) are checked here too; "soft" only
	-- means a later step may pass them over.
	for index, step in Steps do
		if checks[step.id] then self:Reach(st, index) end
	end
end

-- Soft steps and the film/ready steps from the client's TutorialSignal.
function Tutorial:Signal(st, signal: string)
	local tf = st.tf
	if not tf then return end
	if signal == "IntroFinished" or signal == "IntroSkipped" then self:Reach(st, Index.IntroDone); return end
	if signal == "Ready" then self:Reach(st, Index.Control); return end
	local facts = st.tfFacts
	if signal == "Skip" then
		local furthest = 0
		for index in Steps do if tf.reached[index] then furthest = index end end
		self.host.ledger:Count("tf.skipGuide." .. code(furthest))
		return
	end
	if not facts then return end
	if signal == "TreeOpen" then
		if not facts.Flock then self:Reach(st, Index.UpgradesOpen)
		elseif facts.Core and not facts.Vacuum then self:Reach(st, Index.VacUpgradesOpen)
		elseif facts.Core and facts.VacuumSell and not facts.Expand then self:Reach(st, Index.ArmyUpgradesOpen) end
	elseif signal == "ToolsOpen" then
		if facts.Core and not facts.Vacuum then self:Reach(st, Index.ToolsOpen) end
	elseif signal == "VacuumEquip" then
		if facts.Core and facts.Vacuum and not facts.VacuumUse then self:Reach(st, Index.VacuumEquipped) end
	elseif signal == "ArmyOpen" then
		if facts.Core and facts.Expand and not facts.Select then self:Reach(st, Index.MyArmyOpen) end
	end
end

-- Where an unfinished tutorial session ended.
function Tutorial:Leave(st, _session)
	local tf = st.tf
	if not tf or not tf.ready or not tf.tracked then return end
	local furthest = 0
	for index in Steps do if self:Reached(st, index) then furthest = index end end
	if furthest >= Index.CluckCampWon then return end
	local ledger = self.host.ledger
	ledger:Count("tf.exit." .. code(furthest))
	local record = self.host.tutorial and self.host.tutorial.records and self.host.tutorial.records[st.userId]
	ledger:Count("tf.exitLesson." .. tostring(record and record.step or "None"))
end

return Tutorial
