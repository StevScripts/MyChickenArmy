--!strict
-- Observes committed gameplay; never authorizes a purchase or grants a reward.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AnalyticsService = game:GetService("AnalyticsService")
local Guide = require(game.ReplicatedStorage.PetRoll.Shared.TutorialGuide)
local Tutorial = {}
Tutorial.__index = Tutorial
local checkpoints = {30, 60, 180, 300, 600}
local meaningful = {Buy=true, Roll=true, CashUpgrade=true, BoardUpgrade=true, Expand=true,
	UpgradeChicken=true, SetArmy=true, SelectBest=true, Attack=true, CallArmy=true}
local signals = {Ready=true, Skip=true, Resume=true, Help=true, Finish=true,
	IntroStarted=true, IntroFinished=true, IntroSkipped=true,
	TreeOpen=true, TreeClose=true, ArmyOpen=true, ArmyClose=true, NodeInspect=true}
local inputs = {Keyboard=true, Touch=true, Gamepad=true}
-- Eggs wait for the first-visit film: a long allowance while the client loads,
-- then a film-length one once it reports the film started.
local INTRO_LOAD_HOLD, INTRO_FILM_HOLD = 180, 90
local function durationBucket(seconds)
	if seconds<10 then return "Under10" elseif seconds<30 then return "10To29"
	elseif seconds<60 then return "30To59" elseif seconds<120 then return "60To119" else return "120Plus" end
end
-- Bounded, local Studio evidence. No player IDs are sent as analytics categories.
Tutorial.Diagnostics = {}

-- Mirrors the client's intro eligibility. A mismatch is harmless: a client that
-- does not play the film reports IntroSkipped, which releases the hold.
function Tutorial.IntroPending(session)
	local t = session.tutorial
	return t.starterArmy == true and not t.introSeen and not t.guideCompleted and not t.guideSkipped
		and not t.rolled and not t.bought and not t.soldEggs and Guide.CollectedEggCount(t) == 0
		and session:Count() >= 3
end

function Tutorial.new(sink)
	return setmetatable({records={}, sink=sink}, Tutorial)
end

function Tutorial:Emit(record, name, value, step, detail)
	local event = {name=name, value=value or 1, step=step or "None", detail=detail or "None", version=Guide.Version,cohort=record.cohort}
	if RunService:IsStudio() then
		table.insert(Tutorial.Diagnostics, event)
		if #Tutorial.Diagnostics > 256 then table.remove(Tutorial.Diagnostics, 1) end
	end
	if self.sink then self.sink(event); return end
	if RunService:IsStudio() or not record.player or record.player.Parent ~= Players then return end
	local fields = {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name]=Guide.Version.."/"..record.cohort,
		[Enum.AnalyticsCustomFieldKeys.CustomField02.Name]=event.step,
		[Enum.AnalyticsCustomFieldKeys.CustomField03.Name]=event.detail,
	}
	-- Analytics owns the experience-wide Roblox rate budget when it is running.
	if Tutorial.Transport then Tutorial.Transport(record.player, name, event.value, fields); return end
	task.spawn(function()
		local ok, why = pcall(function() AnalyticsService:LogCustomEvent(record.player, name, event.value, fields) end)
		if not ok and not record.warned then record.warned=true; warn("[Tutorial] Analytics unavailable: " .. tostring(why)) end
	end)
end

-- Conquest funnel after the opening guide: first win per main-route camp, the
-- first King clear and failed attacks before a first win. Same rules as Emit:
-- Studio keeps the local ring only; production sends best-effort custom events.
Tutorial.ProgressVersion = "conquest-2-soft-roost"
local progressWarned = false
function Tutorial.LogProgress(userId, name, value, step, detail)
	local event = {name=name, value=value or 1, step=step or "None", detail=detail or "None",
		version=Tutorial.ProgressVersion, cohort="Conquest"}
	-- The agent ledger records these in Studio too (Analytics.Progress).
	if Tutorial.onProgress then pcall(Tutorial.onProgress, userId, name, event.value, event.step, event.detail) end
	if RunService:IsStudio() then
		table.insert(Tutorial.Diagnostics, event)
		if #Tutorial.Diagnostics > 256 then table.remove(Tutorial.Diagnostics, 1) end
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	local fields = {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name]=Tutorial.ProgressVersion,
		[Enum.AnalyticsCustomFieldKeys.CustomField02.Name]=event.step,
		[Enum.AnalyticsCustomFieldKeys.CustomField03.Name]=event.detail,
	}
	if Tutorial.Transport then Tutorial.Transport(player, name, event.value, fields); return end
	task.spawn(function()
		local ok, why = pcall(function() AnalyticsService:LogCustomEvent(player, name, event.value, fields) end)
		if not ok and not progressWarned then progressWarned=true; warn("[Conquest] Analytics unavailable: " .. tostring(why)) end
	end)
end

function Tutorial:Begin(player, session)
	local record = {player=player, at=os.clock(), seen={}, starts={}, uiSeen={}, survival={},
		lastSignals={}, receipts={}, receiptOrder={}, cohort="Unknown", session=session}
	self.records[session.userId] = record
	-- Every cash credit; Analytics records the full economy (not just the guide).
	session.onTutorialIncome = function(source, amount, balance)
		if Tutorial.onIncome then Tutorial.onIncome(session, source, amount, balance) end
	end
end

function Tutorial:FirstAction(record, action)
	if record.firstAction then return end
	record.firstAction = true
	self:Emit(record, "FTUEFirstActionSeconds", os.clock()-record.at, record.step, action)
	if record.readyAt then self:Emit(record, "FTUEControlToActionSeconds", os.clock()-record.readyAt, record.step, action) end
end

function Tutorial:Independent(record, action)
	if not record.endedAt or record.independent or os.clock()-record.endedAt > 120 then return end
	record.independent = true
	self:Emit(record, "FTUEIndependentAction", os.clock()-record.endedAt, "AfterGuide", action)
end

function Tutorial:Observe(session, state)
	local r = self.records[session.userId]
	if not r or not session.loaded or session.closing or session.saveLost then return end
	-- Disposable Studio resets replace the tutorial table; never reuse the old visit's observations.
	if r.initialized and r.tutorial~=session.tutorial then
		self:Begin(r.player,session);r=self.records[session.userId]
	end
	local now, facts = os.clock(), Guide.Facts(state)
	if not r.initialized then
		r.initialized = true
		r.tutorial=session.tutorial
		if Tutorial.IntroPending(session) then session.introHoldUntil = now + INTRO_LOAD_HOLD end
		r.eligible = not session.tutorial.guideCompleted and not facts.Win
		r.cohort = if session.tutorial.guideStarted then "ReturningGuide" else "FirstGuide"
		r.seen = table.clone(facts)
		if not r.eligible then return end
		self:Emit(r, "FTUEEntered", 1, "Entry", r.cohort)
		if not session.tutorial.guideStarted then session.tutorial.guideStarted=true;session:Touch() end
	end
	if not r.eligible then return end
	state.tutorial = table.clone(session.tutorial)
	for kind, receipts in {Pickup=(state.eggs or {}).receipts or {},Sale=(state.eggs or {}).deposits or {}} do
		for _,receipt in receipts do
			local key=kind..":"..receipt.id
			if receipt.collector~="player" or r.receipts[key] then continue end
			r.receipts[key]=true;table.insert(r.receiptOrder,key)
			if #r.receiptOrder>128 then r.receipts[table.remove(r.receiptOrder,1)]=nil end
			self:FirstAction(r,"Egg"..kind);self:Independent(r,"Egg"..kind)
		end
	end
	for _, id in Guide.Milestones do
		if facts[id] and not r.seen[id] then
			r.seen[id] = true
			self:Emit(r, "FTUEMilestone", now-r.at, id, "Confirmed")
			if r.starts[id] then self:Emit(r, "FTUEStepCompletedSeconds", now-r.starts[id], id, durationBucket(now-r.starts[id])) end
			if id=="Sell" or id=="Win" then self:Emit(r, "FTUEFirstPayoffSeconds", now-r.at, id, "Confirmed") end
		end
	end
	if facts.Win and not session.tutorial.guideCompleted then
		session.tutorial.guideCompleted=true; session:Touch();state.tutorial.guideCompleted=true
		r.completedAt=now
		self:Emit(r, "FTUEOutcome", now-r.at, "Complete", if session.tutorial.guideSkipped then "SkippedVictory"
			elseif facts.Sell and facts.Expand then "Completed" else "EarlyVictory")
	end
	local current = Guide.Resolve(state)
	local step = if current then current.id else "Skipped"
	if step ~= r.step then
		r.step, r.stepAt, r.stalled = step, now, false
		if step~="Skipped" and step~="Complete" then
			r.starts[step] = r.starts[step] or now
			self:Emit(r, "FTUEStepEntered", 1, step, r.cohort)
		end
	end
	if step~="Skipped" and step~="Complete" and now-(r.stepAt or now)>=30 and not r.stalled then
		r.stalled=true;self:Emit(r, "FTUEStepStalled", 30, step, "ThirtySeconds")
	end
	for _, at in checkpoints do
		if now-r.at>=at and not r.survival[at] then
			r.survival[at]=true;self:Emit(r, "FTUESurvival", at, "Visit", "T"..at)
		end
	end
	if r.endedAt and not r.windowClosed and now-r.endedAt>=120 then
		r.windowClosed=true
		self:Emit(r, "FTUEFollowupWindow", 120, "AfterGuide", if r.independent then "Continued" else "NoAction")
	end
end

function Tutorial:Signal(session, signal, input)
	local r = self.records[session.userId]
	if not r or not r.initialized or not signals[signal] then return end
	local now = os.clock()
	if now-(r.lastSignals[signal] or -math.huge)<1 then return end
	r.lastSignals[signal]=now
	if signal=="Skip" then
		if session.tutorial.guideSkipped or session.tutorial.guideCompleted then return end
		session.tutorial.guideSkipped=true;session:Touch()
		r.endedAt,r.independent,r.windowClosed=now,false,false
		if r.eligible then self:Emit(r,"FTUEOutcome",now-r.at,r.step,"Skipped") end
	elseif signal=="IntroStarted" then
		-- Presentation only: mark it watched before it ends so a crash cannot loop it.
		if session.tutorial.introSeen then return end
		session.tutorial.introSeen=true;session:Touch()
		if session.introHoldUntil then session.introHoldUntil = now + INTRO_FILM_HOLD end
		r.introAt=now
		self:Emit(r,"FTUEIntro",1,"Entry","Started")
	elseif signal=="IntroFinished" or signal=="IntroSkipped" then
		session.introHoldUntil = nil -- eggs start now, even if the film never ran
		if not r.introAt or r.introEnded then return end
		r.introEnded=true
		self:Emit(r,"FTUEIntroSeconds",now-r.introAt,"Entry",if signal=="IntroSkipped" then "Skipped" else "Finished")
	elseif signal=="Resume" then
		if session.tutorial.guideCompleted then return end
		session.tutorial.guideSkipped=false;session:Touch()
		r.endedAt,r.independent,r.windowClosed=nil,false,false
		if r.eligible then self:Emit(r,"FTUEOutcome",now-r.at,r.step,"Resumed") end
	elseif not r.eligible then return
	elseif signal=="Finish" then
		if session.tutorial.guideCompleted and not r.endedAt then
			r.endedAt=now;self:Emit(r,"FTUEGuidanceEnded",now-r.at,"Complete","Shown")
		end
	elseif signal=="Ready" then
		if r.readyAt then return end
		r.readyAt=now
		self:Emit(r,"FTUEReadySeconds",now-r.at,"Entry",if inputs[input] then input else "Unknown")
	else
		local key = (r.step or "None") .. ":" .. signal
		if r.uiSeen[key] then return end
		r.uiSeen[key]=true
		self:Emit(r,if signal=="Help" then "FTUEHintShown" else "FTUEInteraction",1,r.step,signal)
	end
end

function Tutorial:Action(session, action, ok, before, request, selectionBefore)
	local r = self.records[session.userId]
	if not r or not r.eligible or not meaningful[action] then return end
	if action=="CashUpgrade" or action=="BoardUpgrade" then
		local key="Attempt:"..action..":"..(r.step or "None")
		if not r.uiSeen[key] then r.uiSeen[key]=true;self:Emit(r,"FTUEInteraction",1,r.step,"Attempt"..action) end
	end
	if ok then
		if selectionBefore and selectionBefore==table.concat(session:BestPetIds(),":") then return end
		self:FirstAction(r, action);self:Independent(r, action)
		if action=="Attack" and type(request.targetId)=="string" and string.sub(request.targetId,1,5)=="camp:" then
			session.tutorial.guideDeployed=true;session:Touch()
		end
	elseif not r.uiSeen["Rejected:"..action] then
		r.uiSeen["Rejected:"..action]=true
		self:Emit(r,"FTUEActionRejected",1,r.step,action)
	end
end

function Tutorial:Release(session)
	local r=self.records[session.userId]
	if not r then return end
	if r.eligible then
		if r.endedAt and not r.windowClosed then
			self:Emit(r,"FTUEFollowupWindow",os.clock()-r.endedAt,"AfterGuide",if r.independent then "Continued" else "Exited")
		elseif not session.tutorial.guideCompleted and not session.tutorial.guideSkipped then
			self:Emit(r,"FTUEOutcome",os.clock()-r.at,r.step,"Interrupted")
		end
	elseif not r.initialized then self:Emit(r,"FTUEEntryFailure",os.clock()-r.at,"Entry","ProfileNotReady") end
	session.onTutorialIncome=nil
	self.records[session.userId]=nil
end

return Tutorial
