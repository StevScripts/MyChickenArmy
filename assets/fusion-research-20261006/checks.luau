-- Disposable Edit-safe server-VM checks; never reaches live sessions, DataStore,
-- remotes or authored map instances. Camp facts are synthetic, not battle tests.
-- Requires the current modules (the caller may supply an isolated module loader).
local Server = game.ServerStorage.PetRoll
local Shared = game.ReplicatedStorage.PetRoll.Shared
local Session = require(Server.PlayerSession)
local Army = require(Server.ArmyService)
local Stand = require(Server.MergeStand)
local Upgrades = require(Server.UpgradeService)
local Transactions = require(Server.ResearchService)
local Research = require(Shared.ResearchRules)
local Catalog = require(Shared.ResearchCatalog)
local Rules = require(Shared.Rules)
local Giant = require(Shared.GiantChicken)
local Config = require(Shared.Config)
local checks = {}
local serial = 0
local requirement = "Unlock the Fuse Machine in the skill tree first."

local function check(name, ok)
	table.insert(checks, {name=name, ok=ok==true})
	assert(ok, name)
end

local function fresh()
	serial += 1
	local session = Session.new(-86000-serial, "Fusion research fixture", 1)
	session.loaded, session.saveStatus = true, "session"
	return session
end

local function funded()
	local session = fresh()
	-- Isolate fusion from the independent starter army budget/floor protection.
	session.coins, session.tutorial.guideCompleted = 100000, true
	return session
end

local function same(a, b)
	if type(a)~=type(b) then return false end
	if type(a)~="table" then return a==b end
	for key, value in a do if not same(value, b[key]) then return false end end
	for key in b do if a[key]==nil then return false end end
	return true
end

local function restore(data)
	local session = fresh()
	local ok, reason = session:LoadData(data)
	assert(ok, reason)
	return session
end

local function triple(session)
	local ids = {}
	for id in session.pets do table.insert(ids, id) end
	table.sort(ids)
	return {firstId=ids[1], secondId=ids[2], thirdId=ids[3],
		level=1, expectedPrice=Rules.MergePrice("Duck", 1)}
end

local function merge(session, request)
	return Army.Merge(session, request.firstId, request.secondId, request.thirdId,
		request.level, request.expectedPrice)
end

local function start(session, now)
	local node = Catalog.Nodes.FuseMachine
	return Transactions.Start(session, node.id, session.research.revision,
		node.price, Research.Duration(node, session.researchEffects), now)
end

local node = Catalog.Nodes.FuseMachine
check("manual fusion remains enabled", Config.Features.Merging==true)
check("Fuse Machine is an early Army research unlock", node.branch=="Army" and node.prerequisite=="Start"
	and node.price==5000 and node.duration==120 and node.effect=="fusion" and node.value==1)
local locked = funded()
local allowed, reason = locked:MergeAccess()
check("fresh profiles deny fusion with the actionable server error", not allowed and reason==requirement and locked.fusionUnlocked==false)
local snapshot = locked:Snapshot(0)
check("fresh snapshot supplies the same locked requirement", snapshot.mergeUnlocked==false and snapshot.mergeRequirement==requirement)
check("fresh save stamps version 2 and explicit locked access", locked:ToData().fusionUnlockVersion==2 and locked:ToData().fusionUnlocked==false)
check("fresh locked access survives rejoin", not restore(locked:ToData()):MergeAccess())
local before, revision = locked:ToData(), locked.revision
local request = triple(locked)
local merged, mergeReason = merge(locked, request)
check("funded matching trio receives the locked error", not merged and mergeReason==requirement)
check("locked single fusion is atomic", same(before, locked:ToData()) and locked.revision==revision)
local batchOk, batchReason = Army.MergeAll(locked, {request})
check("locked batch uses the same error and preserves all saved state", not batchOk and batchReason==requirement
	and same(before, locked:ToData()) and locked.revision==revision)
check("locked profiles advertise no manual or automatic recipes", #Army.MergeOptions(locked)==0 and #Army.MergeOptions(locked, true)==0)

locked.firstWins[1], locked.tutorial.wonCamp = true, true
check("a new Cluck Camp victory no longer grants access", not locked:MergeAccess())
local afterCamp = locked:ToData()
local rejoined = restore(afterCamp)
check("a new camp victory remains locked after save/load", afterCamp.fusionUnlockVersion==2 and afterCamp.fusionUnlocked==false
	and rejoined.firstWins[1]==true and not rejoined:MergeAccess() and not rejoined.research.completed.FuseMachine)
local missingNewFlag = locked:ToData()
missingNewFlag.fusionUnlocked = nil
check("version 2 missing access flag cannot use legacy grandfathering", not restore(missingNewFlag):MergeAccess())

local researching = funded()
local now, initialCash = os.time()+3600, researching.coins
check("Start makes Fuse Machine research available without a camp", Research.Status(researching.research, node.id, researching.coins)=="Available"
	and next(researching.firstWins)==nil and start(researching, now))
local job = researching.research.jobs[1]
check("research charges once and leaves fusion locked while running", researching.coins==initialCash-node.price
	and not researching:MergeAccess() and researching.researchEffects.fusion==0)
local running = restore(researching:ToData())
check("unfinished research remains locked on rejoin", not running:MergeAccess() and #running.research.jobs==1)
check("duplicate research does not charge again", not start(researching, now+1) and researching.coins==initialCash-node.price and #researching.research.jobs==1)
check("cancelling refunds the paid cost without unlocking", Transactions.Cancel(researching, job.id, researching.research.revision, now+1)
	and researching.coins==initialCash and not researching:MergeAccess() and #researching.research.jobs==0)
local cancelled = researching:ToData()
check("cancel can only refund once", not Transactions.Cancel(researching, job.id, researching.research.revision, now+1)
	and same(cancelled, researching:ToData()))
check("cancelled research stays locked after rejoin", not restore(cancelled):MergeAccess())
check("cancelled research can be started again", start(researching, now+2))
local deadline = researching.research.jobs[1].finishAt
check("research does not complete before its deadline", #Transactions.Complete(researching, deadline-1)==0 and not researching:MergeAccess())
check("deadline completes fusion access", #Transactions.Complete(researching, deadline)==1
	and researching:MergeAccess() and researching.researchEffects.fusion==1)
check("completion does not charge again or replay", #Transactions.Complete(researching, deadline+1)==0 and researching.coins==initialCash-node.price)
local unlockedSnapshot = researching:Snapshot(0)
check("completed snapshot clears the error", unlockedSnapshot.mergeUnlocked==true and unlockedSnapshot.mergeRequirement=="")
local earnedData = researching:ToData()
local earned = restore(earnedData)
check("completed research persists access and completed node", earnedData.fusionUnlocked==true and earned:MergeAccess()
	and earned.research.completed.FuseMachine and earned.researchEffects.fusion==1 and earned.coins==initialCash-node.price)

local offline = funded()
local offlineCash = offline.coins
check("offline fixture starts research", start(offline, os.time()-node.duration-60))
local returned = restore(offline:ToData())
check("elapsed offline job completes on load without another charge", returned:MergeAccess() and returned.research.completed.FuseMachine
	and #returned.research.jobs==0 and returned.researchEffects.fusion==1 and returned.coins==offlineCash-node.price)
check("offline completion serializes durable access", returned:ToData().fusionUnlocked==true and restore(returned:ToData()):MergeAccess())

local fee, fusionCash = Rules.MergePrice("Duck", 1), earned.coins
local earnedRequest = triple(earned)
local fused, _, survivorId = merge(earned, earnedRequest)
check("researched fusion performs the ordinary quoted transaction", fused and survivorId==earnedRequest.firstId
	and earned:Count()==1 and earned.coins==fusionCash-fee and fee==Rules.RecruitPrice("Duck", 1)*0.25)
local survivor = earned.pets[survivorId]
check("researched fusion retains next-level guaranteed Giant behavior", survivor.level==2 and survivor.species=="Duck"
	and Giant.IsValidSize(survivor.giantSize) and survivor.giantSize>=4 and survivor.giantSize<=6 and survivor.investment==0)

-- Each old access path is migrated once; it must not buy extra research for free.
for _, mode in {"earned flag", "missing flag", "old camp victory"} do
	local data = funded():ToData()
	data.fusionUnlockVersion = nil
	if mode=="earned flag" then data.fusionUnlocked=true
	elseif mode=="missing flag" then data.fusionUnlocked=nil
	else data.firstWins={1} end
	data.research.completed.A1 = true
	local expectedCompleted = table.clone(data.research.completed)
	expectedCompleted.FuseMachine = true
	local migrated = restore(data)
	check(mode.." preserves fusion access and marks just Fuse Machine complete", migrated:MergeAccess()
		and migrated.fusionUnlocked==true and same(migrated.research.completed, expectedCompleted))
	check(mode.." migration preserves cash chickens and existing research", migrated.coins==data.coins
		and same(migrated:ToData().pets, data.pets) and migrated.research.revision==data.research.revision and #migrated.research.jobs==0)
	check(mode.." migration persists without any later camp requirement", migrated:ToData().fusionUnlockVersion==2
		and restore(migrated:ToData()):MergeAccess())
end
local oldLocked = funded():ToData()
oldLocked.fusionUnlockVersion = nil
oldLocked.research.completed.A1 = true
local stillLocked = restore(oldLocked)
check("old explicit false without earned access stays locked", not stillLocked:MergeAccess() and stillLocked.fusionUnlocked==false
	and same(stillLocked.research.completed, oldLocked.research.completed))
check("old locked profile switches to version 2 on save", stillLocked:ToData().fusionUnlockVersion==2)

local incumbent = restore(earnedData)
local incumbentData, incumbentRevision = incumbent:ToData(), incumbent.revision
local function rejects(name, invalid, expectedReason)
	local ok, loadReason = incumbent:LoadData(invalid)
	check(name, not ok and loadReason==expectedReason and same(incumbentData, incumbent:ToData()) and incumbent.revision==incumbentRevision)
end
for _, value in {"true", 1, {}} do
	local invalid = funded():ToData()
	invalid.coins, invalid.fusionUnlocked = 1, value
	rejects("invalid "..type(value).." fusion flag rejects atomically", invalid, "Invalid saved fusion access.")
end
for _, value in {0, 1, 3, "2", true, {}} do
	local invalid = funded():ToData()
	invalid.coins, invalid.fusionUnlockVersion = 1, value
	rejects("unsupported fusion version "..tostring(value).." rejects atomically", invalid, "Unsupported saved fusion unlock version.")
end
for _, mode in {"version 2 flag", "old flag", "old missing flag", "old camp"} do
	local conflicted = funded()
	assert(start(conflicted, now))
	local invalid = conflicted:ToData()
	if mode=="version 2 flag" then invalid.fusionUnlocked=true
	else
		invalid.fusionUnlockVersion=nil
		if mode=="old flag" then invalid.fusionUnlocked=true
		elseif mode=="old missing flag" then invalid.fusionUnlocked=nil
		else invalid.firstWins={1} end
	end
	rejects(mode.." plus active fusion job rejects atomically", invalid, "Invalid saved fusion research.")
end

local upgradeSession = funded()
upgradeSession.plotExpansionAvailable, upgradeSession.rollSlotLimit = true, 8
local upgradeService = Upgrades.new(nil, nil)
local offers = upgradeService:Offers(upgradeSession)
for _, key in {"EggSpeed", "EggValue", "PlotSize", "ArmySize", "Luck", "RollSlots"} do
	local offer = offers[key]
	check(key.." remains purchasable without fusion research or camp progress", offer~=nil and offer.price~=nil
		and offer.unlocked and offer.canSpend and offer.ready)
end
upgradeSession.research.completed.FuseMachine = true
upgradeSession.researchEffects = Research.Effects(upgradeSession.research)
check("fusion unlock does not change cash upgrade offers", same(offers, upgradeService:Offers(upgradeSession)))

-- Actual Sync with unparented native instances; clean up even if an assertion fails.
local model, prompt = Instance.new("Model"), Instance.new("ProximityPrompt")
local promptOk, promptError = pcall(function()
	local stand = setmetatable({model=model, prompt=prompt}, Stand)
	local session = fresh()
	stand:Sync(session)
	check("locked native prompt remains visible with skill-tree action", prompt.Enabled and prompt.ObjectText=="Fuse Machine · Locked"
		and prompt.ActionText=="Unlock in Skill Tree")
	check("prompt sync preserves ownership and readiness", stand.ownerId==session.userId and stand.loaded and model:GetAttribute("OwnerUserId")==session.userId)
	stand.reveal = true
	stand:Sync(session)
	check("locked prompt remains suppressed during reveal", not prompt.Enabled)
	session.research.completed.FuseMachine = true
	stand:Sync(session)
	check("completion changes prompt copy without interrupting reveal suppression", not prompt.Enabled
		and prompt.ObjectText=="Fuse Machine" and prompt.ActionText=="Fuse Chickens")
	stand.reveal = nil
	stand:Sync(session)
	check("researched prompt returns when reveal ends", prompt.Enabled)
	for _, state in {"loaded", "closing", "saveLost"} do
		session.loaded, session.closing, session.saveLost = true, false, false
		session[state] = state~="loaded"
		stand:Sync(session)
		check(state.." guard still disables the prompt", not prompt.Enabled and not stand.loaded)
	end
end)
prompt:Destroy()
model:Destroy()
assert(promptOk, promptError)

return {passed=#checks, checks=checks,
	scope="Disposable sessions and native unparented prompt; synthetic time/camp facts; no live players, remotes, map, DataStore, Play or real purchases"}
