-- Disposable server-VM checks. Never reaches live sessions, DataStore or remotes.
-- Capture facts are assigned to isolated objects; this does not prove battle routing.
-- The native prompt and model are unparented fixtures, never builder map instances.
local Server = game.ServerStorage.PetRoll
local Shared = game.ReplicatedStorage.PetRoll.Shared
local Session = require(Server.PlayerSession)
local Army = require(Server.ArmyService)
local Stand = require(Server.MergeStand)
local Rules = require(Shared.Rules)
local Giant = require(Shared.GiantChicken)
local Config = require(Shared.Config)
local checks = {}
local serial = 0
local requirement = "Capture Cluck Camp to unlock the Fuse Machine."

local function check(name, ok)
	table.insert(checks, {name=name, ok=ok==true})
	assert(ok, name)
end

local function fresh()
	serial += 1
	local session = Session.new(-85000-serial, "Fusion unlock fixture", 1)
	session.loaded, session.saveStatus = true, "session"
	return session
end

local function ids(session)
	local result = {}
	for id in session.pets do table.insert(result, id) end
	table.sort(result)
	return result
end

local function same(a, b)
	if type(a)~=type(b) then return false end
	if type(a)~="table" then return a==b end
	for key, value in a do if not same(value, b[key]) then return false end end
	for key in b do if a[key]==nil then return false end end
	return true
end

local function triple(values, offset)
	return {firstId=values[offset], secondId=values[offset+1], thirdId=values[offset+2],
		level=1, expectedPrice=Rules.MergePrice("Duck", 1)}
end

local function merge(session, request)
	return Army.Merge(session, request.firstId, request.secondId, request.thirdId,
		request.level, request.expectedPrice)
end

local function restore(data)
	local session = fresh()
	assert(session:LoadData(data))
	return session
end

check("manual fusion feature remains enabled", Config.Features.Merging==true)
local locked = fresh()
local canMerge, reason = locked:MergeAccess()
check("fresh profile explicitly starts locked", locked.fusionUnlocked==false and not canMerge and reason==requirement)
check("fresh snapshot supplies locked requirement", locked:Snapshot(0).mergeUnlocked==false and locked:Snapshot(0).mergeRequirement==requirement)
check("fresh save persists explicit false", locked:ToData().fusionUnlocked==false)
check("fresh lock survives a save/load round trip", not restore(locked:ToData()):MergeAccess())

-- Remove tutorial budget/floor constraints so a rejection can only be the lock.
locked.coins = 100000
locked.tutorial.guideCompleted = true
local lockedIds = ids(locked)
local before = locked:ToData()
local revision = locked.revision
local one = triple(lockedIds, 1)
local ok, deniedReason = merge(locked, one)
check("funded matching trio cannot bypass the lock", not ok and deniedReason==requirement)
check("locked single fusion preserves every saved value", same(before, locked:ToData()) and locked.revision==revision)
check("locked profile advertises no manual fusion options", #Army.MergeOptions(locked)==0)
check("locked profile advertises no automatic fusion options", #Army.MergeOptions(locked, true)==0)
local batchOk, batchReason = Army.MergeAll(locked, {one})
check("batch path also reports the locked requirement", not batchOk and batchReason==requirement)
check("locked batch preserves chickens cash and revision", same(before, locked:ToData()) and locked.revision==revision)

locked.tutorial.wonCamp = true
check("generic tutorial camp milestone cannot unlock fusion", not locked:MergeAccess())
locked.firstWins[2] = true
check("another main camp cannot unlock fusion", not locked:MergeAccess())
locked.firstWins = {}
locked.frontierWins[1] = true
locked.kingCleared = true
check("unrelated conquest flags cannot unlock fusion", not locked:MergeAccess())
locked.frontierWins, locked.kingCleared = {}, false
locked.tutorial.guideSkipped = true
check("skipping or finishing guidance does not grant access", not locked:MergeAccess())

locked.firstWins[1] = true
local unlocked, unlockedReason = locked:MergeAccess()
check("first Cluck capture unlocks immediately", unlocked and unlockedReason=="" and locked.fusionUnlocked==false)
check("unlocked snapshot clears the locked requirement", locked:Snapshot(0).mergeUnlocked==true and locked:Snapshot(0).mergeRequirement=="")
check("first capture serializes a permanent earned unlock", locked:ToData().fusionUnlocked==true)
local earned = restore(locked:ToData())
check("earned unlock and capture survive save/load", earned:MergeAccess() and earned.fusionUnlocked==true and earned.firstWins[1]==true)
earned.firstWins = {}
check("persisted entitlement is independent of active occupation", earned:MergeAccess())

local options = Army.MergeOptions(locked)
check("unlocked funded trio has its regular quoted recipe", #options==1 and options[1].price==Rules.MergePrice("Duck", 1))
local fee = Rules.MergePrice("Duck", 1)
check("unlock preserves existing quarter-recruit fee", fee==Rules.RecruitPrice("Duck", 1)*0.25)
local originalCash = locked.coins
local merged, _, survivorId = merge(locked, one)
check("unlocked valid triple completes the existing transaction", merged and survivorId==one.firstId and locked:Count()==1)
check("fusion charges the exact fee once", locked.coins==originalCash-fee)
local survivor = locked.pets[survivorId]
check("fusion keeps survivor identity and next-level reward", survivor.id==one.firstId and survivor.species=="Duck" and survivor.level==2)
check("fusion output remains a guaranteed Common Giant", Giant.IsValidSize(survivor.giantSize) and survivor.giantSize>=4 and survivor.giantSize<=6)
check("free inputs do not gain refundable service-fee investment", survivor.investment==0 and not locked.pets[one.secondId] and not locked.pets[one.thirdId])
check("replayed quote cannot charge the successful fusion twice", not merge(locked, one) and locked.coins==originalCash-fee and locked:Count()==1)

local batch = fresh()
batch.tutorial.guideCompleted = true
batch.firstWins[1] = true
batch.coins = 10000
for _=1,3 do batch:AddPet("Duck", 1) end
local batchIds = ids(batch)
local batchRequests = {triple(batchIds, 1), triple(batchIds, 4)}
check("unlocked batch consumes both triples at the existing fee", Army.MergeAll(batch, batchRequests) and batch:Count()==2 and batch.coins==10000-2*fee)
check("all batch outputs are next-level Giants", (function()
	for _, pet in batch.pets do if pet.level~=2 or not Giant.IsValidSize(pet.giantSize) then return false end end
	return true
end)())

-- Existing profiles keep access even if they were created under starterArmy.
for _, cohort in {"pre-tutorial", "emptyStart", "starterArmy"} do
	local legacyData = fresh():ToData()
	legacyData.fusionUnlocked = nil
	legacyData.tutorial = if cohort=="pre-tutorial" then {} else {[cohort]=true}
	legacyData.coins = 7654
	local savedPets = legacyData.pets
	local legacy = restore(legacyData)
	check(cohort.." missing-field legacy profile retains access", legacy:MergeAccess() and legacy.fusionUnlocked==true and next(legacy.firstWins)==nil)
	check(cohort.." grandfathering preserves balance and flock", legacy.coins==7654 and same(legacy:ToData().pets, savedPets) and legacy:Count()==3)
	check(cohort.." grandfathering is saved durably", legacy:ToData().fusionUnlocked==true and restore(legacy:ToData()):MergeAccess())
end
local explicit = fresh():ToData()
explicit.tutorial = {}
check("explicit false is respected independently of tutorial cohort", not restore(explicit):MergeAccess())
explicit.firstWins = {1}
check("saved first capture overrides an explicit stale false", restore(explicit):MergeAccess() and restore(explicit).fusionUnlocked==true)
explicit.firstWins, explicit.fusionUnlocked = {}, true
check("saved permanent access does not need a retained camp flag", restore(explicit):MergeAccess())

local incumbent = restore(explicit)
incumbent.coins = 4321
local incumbentState = incumbent:ToData()
local incumbentRevision = incumbent.revision
for _, invalidValue in {"true", 1, {}} do
	local invalid = fresh():ToData()
	invalid.coins = 1
	invalid.fusionUnlocked = invalidValue
	local loaded, loadReason = incumbent:LoadData(invalid)
	check("invalid "..type(invalidValue).." access is rejected atomically", not loaded and loadReason=="Invalid saved fusion access."
		and same(incumbentState, incumbent:ToData()) and incumbent.revision==incumbentRevision)
end

-- Exercise the actual Sync method with a native prompt outside the DataModel.
local model = Instance.new("Model")
local prompt = Instance.new("ProximityPrompt")
local stand = setmetatable({model=model, prompt=prompt}, Stand)
local promptSession = fresh()
stand:Sync(promptSession)
check("locked native prompt remains visible with its requirement", prompt.Enabled and prompt.ObjectText=="Fuse Machine · Locked" and prompt.ActionText=="Capture Cluck Camp")
check("prompt sync preserves ownership and loaded state", stand.ownerId==promptSession.userId and stand.loaded and model:GetAttribute("OwnerUserId")==promptSession.userId)
stand.reveal = true
stand:Sync(promptSession)
check("locked prompt is disabled during reveal", not prompt.Enabled)
promptSession.firstWins[1] = true
stand:Sync(promptSession)
check("unlock cannot interrupt reveal prompt suppression", not prompt.Enabled and prompt.ObjectText=="Fuse Machine" and prompt.ActionText=="Fuse Chickens")
stand.reveal = nil
stand:Sync(promptSession)
check("unlocked native prompt returns after reveal", prompt.Enabled and prompt.ObjectText=="Fuse Machine" and prompt.ActionText=="Fuse Chickens")
for _, state in {"loaded", "closing", "saveLost"} do
	promptSession.loaded, promptSession.closing, promptSession.saveLost = true, false, false
	promptSession[state] = state~="loaded"
	stand:Sync(promptSession)
	check(state.." guard disables native prompt", not prompt.Enabled and not stand.loaded)
end
prompt:Destroy()
model:Destroy()

return {passed=#checks, checks=checks,
	scope="Unsaved PlayerSession/ArmyService objects and unparented native MergeStand prompt; synthetic capture facts; no live players, battle, remotes, map or DataStore"}
