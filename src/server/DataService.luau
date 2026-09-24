--!strict
-- Small private-game persistence owner: versioned data, atomic leases and explicit failure states.
local DataStoreService=game:GetService("DataStoreService")
local HttpService=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local Config=require(game:GetService("ReplicatedStorage").PetRoll.Shared.Config)
local OfflineCash=require(script.Parent.OfflineCash)
local DataService={}
DataService.__index=DataService

function DataService.new(storeOverride,clockOverride,dependencies)
 dependencies=dependencies or {}
 local self=setmetatable({entries={},saving={},loading={},clock=clockOverride or os.time,closing=false,
  wait=dependencies.wait or task.wait,monotonic=dependencies.monotonic or os.clock},DataService)
 self.token=(if game.JobId~="" then game.JobId else "studio")..":"..HttpService:GenerateGUID(false)
 self.store=storeOverride
 if not self.store and (not RunService:IsStudio() or game.GameId~=0) then
  self.store=DataStoreService:GetDataStore(Config.SaveName..(if RunService:IsStudio() then "_Studio" else ""))
 end
 return self
end

function DataService:Update(key,callback)
 if not self.store then return false,"This unpublished local file uses session-only progress." end
 local lastError
 for attempt=1,Config.SaveAttempts do
  local ok,value=pcall(function() return self.store:UpdateAsync(key,callback) end)
  if ok then return true,value end
  lastError=tostring(value)
  if attempt<Config.SaveAttempts then self.wait(attempt) end
 end
 return false,lastError
end

function DataService:Load(session)
 if self.entries[session.userId] or self.saving[session.userId] or self.loading[session.userId] then
  session.saveStatus="error";session.saveMessage="Your previous session is still saving. Rejoin shortly."
  return false,session.saveMessage
 end
 self.loading[session.userId]=true
 local key="player_"..session.userId
 local initial=session:ToData()
 local ok,record=self:Update(key,function(old)
  local now=self.clock()
  if old~=nil and (type(old)~="table" or old.schemaVersion~=1 or type(old.data)~="table") then return nil end
  if old and old.lease then
   if type(old.lease)~="table" or type(old.lease.owner)~="string" or type(old.lease.expires)~="number" or old.lease.expires~=old.lease.expires then return nil end
   if old.lease.owner~=self.token and old.lease.expires>now then return nil end
  end
  return {schemaVersion=1,data=if old then old.data else initial,
   lease={owner=self.token,expires=now+Config.SaveLeaseSeconds},updatedAt=if old then old.updatedAt else now}
 end)
 if not ok then
  session.saveStatus="error";session.saveMessage="Save service unavailable. Your stored progress has not been replaced."
  self.loading[session.userId]=nil
  return false,record
 end
 if not record or not record.lease or record.lease.owner~=self.token then
  session.saveStatus="error";session.saveMessage="Your save is busy or uses an unsupported version. Rejoin shortly."
  self.loading[session.userId]=nil
  return false,session.saveMessage
 end
 local valid,why=session:LoadData(record.data)
 if not valid then
  -- Release only our lock; keep the unrecognized player data byte-for-byte logically intact.
  self:Update(key,function(old)
   if old and old.lease and old.lease.owner==self.token then old.lease=nil;return old end
   return nil
  end)
  session.saveStatus="error";session.saveMessage="This save needs recovery. It has not been overwritten."
  self.loading[session.userId]=nil
  return false,why
 end
 self.entries[session.userId]={session=session,key=key,lastSaved=self.clock(),leaseExpires=record.lease.expires,
  savedReceipts=table.clone(record.data.purchaseReceipts or {})}
 -- Keep requests blocked until the reward and consumed interval share one
 -- successful profile save. Retrying an uncertain write uses the same payload.
 local receipt=OfflineCash.Reward(session.offlineCash,self.clock(),session.coins)
 if receipt.amount>0 then session:Credit(receipt.amount,"offline") end
 local saved,saveError=self:Save(session,false)
 if not saved then
  session.coins-=receipt.amount
  self.entries[session.userId]=nil
  self:Update(key,function(old)
   if old and old.lease and old.lease.owner==self.token then old.lease=nil;return old end
   return nil
  end)
  session.loaded=false;session.offlineCashReceipt=nil
  session.saveStatus="error";session.saveMessage="Your offline cash is still being saved. Rejoin shortly."
  self.loading[session.userId]=nil
  return false,saveError
 end
 if receipt.amount>0 then
  receipt.id=HttpService:GenerateGUID(false)
  session.offlineCashReceipt=receipt
 end
 session.saveStatus="saved";session.saveMessage="Progress saved automatically."
 self.loading[session.userId]=nil
 session.loaded=true;session:Touch()
 return true,"Loaded."
end

function DataService:Capture(session,release)
 local payload=session:ToData()
 -- During a crash the last persisted lease may include active play. Count
 -- offline time only after its expiry; a clean exit starts at departure.
 payload.offlineCash={at=self.clock()+(if release then 0 else Config.SaveLeaseSeconds),rate=OfflineCash.Rate(session)}
 return payload
end

function DataService:Save(session,release)
 local entry=self.entries[session.userId]
 if not entry or entry.session~=session or self.saving[session.userId] then return false,"No writable session, or save already running." end
 self.saving[session.userId]=true
 session.saveStatus="saving";session.saveMessage="Saving your flock…";session:Touch()
 local captured,payload=pcall(function() return entry.releasePayload or self:Capture(session,release) end)
 if not captured then
  self.saving[session.userId]=nil
  session.saveStatus="error";session.saveMessage="Saving interrupted. Your purchase will retry safely.";session:Touch()
  return false,tostring(payload)
 end
 local now=self.clock()
 local ok,record=self:Update(entry.key,function(old)
  if type(old)~="table" or old.schemaVersion~=1 or not old.lease or old.lease.owner~=self.token then return nil end
  return {schemaVersion=1,data=payload,updatedAt=self.clock(),
   lease=if release then nil else {owner=self.token,expires=self.clock()+Config.SaveLeaseSeconds}}
 end)
 self.saving[session.userId]=nil
 if not ok or not record then
  session.saveStatus="error";session.saveMessage="Saving interrupted. Retrying; keep this session open."
  if ok and not record then session.saveLost=true;session.saveMessage="Your save moved to another session. Rejoin to continue safely." end
  session:Touch()
  return false,if ok then "Session lock lost." else record
 end
 entry.lastSaved=now;entry.leaseExpires=now+Config.SaveLeaseSeconds
 -- Only a successful store response proves a receipt is durable. In-memory markers
 -- can also include a grant whose last save failed and must not acknowledge it yet.
 entry.savedReceipts=table.clone(record.data.purchaseReceipts or {})
 session.offlineCash=table.clone(record.data.offlineCash)
 session.saveStatus="saved";session.saveMessage="Progress saved automatically.";session:Touch()
 if release then self.entries[session.userId]=nil end
 return true,"Saved."
end

function DataService:CanPurchase(session)
 local entry=session and self.entries[session.userId]
 if not self.store or not entry or entry.session~=session or not session.loaded then
  return false,"Purchases need a loaded, saved profile."
 end
 if self.closing or session.closing or session.saveLost or session.dataReleasing or entry.releasePayload
  or self.clock()>=entry.leaseExpires then
  return false,"Your save is not writable right now."
 end
 return true,"Ready."
end

function DataService:IsPurchaseSaved(session,purchaseId,productId)
 local entry=self.entries[session.userId]
 return entry~=nil and entry.session==session and entry.savedReceipts[purchaseId]==productId
end

-- Called only by the server receipt owner. grant must be nonyielding and either
-- apply the complete reward and return true, or change nothing and return false.
function DataService:CommitPurchase(session,purchaseId,productId,grant)
 local writable,why=self:CanPurchase(session)
 if not writable then return false,why end
 if self:IsPurchaseSaved(session,purchaseId,productId) then return true,"Already delivered." end
 -- An autosave may already own an older snapshot. Let it finish before adding a
 -- receipt, so that snapshot cannot overwrite a newly acknowledged purchase.
 local deadline=self.monotonic()+20
 while self.saving[session.userId] do
  if self.monotonic()>=deadline then return false,"A save is still running." end
  self.wait(0.1)
  writable,why=self:CanPurchase(session)
  if not writable then return false,why end
 end
 writable,why=self:CanPurchase(session)
 if not writable then return false,why end
 if self:IsPurchaseSaved(session,purchaseId,productId) then return true,"Already delivered." end
 local receipts=session.purchaseReceipts
 if type(receipts)~="table" then return false,"Purchase history is unavailable." end
 local previous=receipts[purchaseId]
 if previous~=nil and previous~=productId then return false,"Purchase history does not match this receipt." end
 if previous==nil then
  local applied,reason=grant()
  if not applied then return false,reason end
  receipts[purchaseId]=productId
  session:Touch()
 end
 -- No yield between grant, marker and Save's snapshot. Failed saves retain the
 -- marker in memory; a retry persists that grant without paying it twice.
 local saved,message=self:Save(session,false)
 if saved and self:IsPurchaseSaved(session,purchaseId,productId) then return true,"Delivered and saved." end
 return false,message
end

function DataService:Step()
 if self.closing then return end
 local now=self.clock()
 for id,entry in self.entries do
  local session=entry.session
  if (entry.releasePayload or (session.loaded and not session.closing)) and not self.saving[id] and now-entry.lastSaved>=Config.SaveInterval then
   -- Advance the retry clock before scheduling so a failing service cannot spawn a save every frame.
   entry.lastSaved=now
   task.spawn(function() self:Save(session,entry.releasePayload~=nil) end)
  end
  if not session.closing and now>=entry.leaseExpires then
   session.saveLost=true;session.saveStatus="error";session.saveMessage="Save connection expired. Rejoin to protect your progress."
  end
 end
end

function DataService:Release(session)
 if session.dataReleasing then return end
 session.dataReleasing=true
 local entry=self.entries[session.userId]
 if entry and entry.session==session and not entry.releasePayload then entry.releasePayload=self:Capture(session,true) end
 local deadline=os.clock()+24
 while self.saving[session.userId] and os.clock()<deadline do task.wait(0.1) end
 if not self.saving[session.userId] then self:Save(session,true) end
 session.dataReleasing=false
end

function DataService:Close()
 self.closing=true
 for _,entry in self.entries do
  entry.session.closing=true
  task.spawn(function() self:Release(entry.session) end)
 end
 local deadline=os.clock()+25
 while next(self.entries) and os.clock()<deadline do task.wait(0.1) end
end

return DataService
