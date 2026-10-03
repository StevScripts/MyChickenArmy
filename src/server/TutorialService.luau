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
	TreeOpen=true, TreeClose=true, ArmyOpen=true, ArmyClose=true, NodeInspect=true}
local inputs = {Keyboard=true, Touch=true, Gamepad=true}
local function durationBucket(seconds)
	if seconds<10 then return "Under10" elseif seconds<30 then return "10To29"
	elseif seconds<60 then return "30To59" elseif seconds<120 then return "60To119" else return "120Plus" end
end
-- Bounded, local Studio evidence. No player IDs are sent as analytics categories.
Tutorial.Diagnostics = {}

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
	task.spawn(function()
		local ok, why = pcall(function() AnalyticsService:LogCustomEvent(record.player, name, event.value, fields) end)
		if not ok and not record.warned then record.warned=true; warn("[Tutorial] Analytics unavailable: " .. tostring(why)) end
	end)
end

function Tutorial:Begin(player, session)
	local record = {player=player, at=os.clock(), seen={}, starts={}, uiSeen={}, survival={},
		lastSignals={}, receipts={}, receiptOrder={}, cohort="Unknown", session=session}
	self.records[session.userId] = record
	session.onTutorialIncome = function(source, amount, balance)
		if not record.eligible then return end
		if source == "eggs" then
			self:Economy(record, "Source", amount, balance, "EggSale")
		end
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

function Tutorial:Economy(record, flow, amount, balance, kind)
	if amount <= 0 or self.sink or RunService:IsStudio() or not record.player or record.player.Parent ~= Players then return end
	task.spawn(function()
		pcall(function()
			AnalyticsService:LogEconomyEvent(record.player,
				if flow=="Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink,
				"Cash", amount, balance,
				if flow=="Source" then Enum.AnalyticsEconomyTransactionType.Gameplay.Name else Enum.AnalyticsEconomyTransactionType.Shop.Name,
				kind, {[Enum.AnalyticsCustomFieldKeys.CustomField01.Name]=Guide.Version})
		end)
	end)
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
		self:Economy(r, "Sink", math.max(0,before-session.coins), session.coins, action)
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
