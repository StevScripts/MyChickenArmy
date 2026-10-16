--!strict
-- Global rankings are a projection of authoritative sessions, never a money source.
-- October 9: Strongest Army (best possible army power), all-time. October 14:
-- Top Rebirths (session.rebirths) replaces the displayed Top Supporters board.
-- October 15: Most Robux Spent is shown again on each plot's third board
-- (Leaderboard3), read from the same unchanged store, so its history carries over.
-- The server writes OrderedDataStores and publishes the top rows to
-- ReplicatedStorage.PetRoll.Leaderboards; the client module LeaderboardBoards draws them on every plot's Leaderboard1/2/3 screen.
local Players=game:GetService("Players")
local DataStoreService=game:GetService("DataStoreService")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local UserService=game:GetService("UserService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.PetRoll.Shared.Config)
local AdminConfig=require(script.Parent.AdminConfig)
local Leaderboards={}
Leaderboards.__index=Leaderboards
Leaderboards.Top=100 -- Boards scroll (LeaderboardBoards); 100 is one GetSortedAsync page.
Leaderboards.Definitions={
 {key="ArmyPower",title="STRONGEST ARMY"},
 {key="Rebirths",title="TOP REBIRTHS"},
 {key="RobuxSpent",title="MOST ROBUX SPENT"},
}

local function valueOf(session,key)
 if key=="ArmyPower" then
  local ok,power=pcall(function() return session:BestArmyPower() end)
  return if ok and type(power)=="number" then math.floor(power) else 0
 end
 if key=="Rebirths" then return math.floor(tonumber(session.rebirths) or 0) end
 return math.floor(session.robuxSpent or 0)
end

function Leaderboards.new(world,sessions,stores)
 local self=setmetatable({world=world,sessions=sessions,values={},names={},stores=stores,published={},
  nextUpdate=0,busy=false,alive=true,writing={},written={},finalAfter={}},Leaderboards)
 self.preview=stores==nil and (RunService:IsStudio() or not Config.SaveEnabled)
 if not self.preview and not self.stores then
  self.stores={}
  for _,def in Leaderboards.Definitions do
   self.stores[def.key]=DataStoreService:GetOrderedDataStore(Config.SaveName.."_Global_"..def.key.."_v1")
  end
 end
 return self
end

function Leaderboards:Publish(def,status,entries)
 local value=self.values[def.key]
 if not value then return end
 if entries then self.published[def.key]=entries end
 value.Value=HttpService:JSONEncode({key=def.key,title=def.title,status=status,
  updated=os.time(),entries=self.published[def.key] or {}})
end

function Leaderboards:Build()
 local root=ReplicatedStorage.PetRoll
 local folder=root:FindFirstChild("Leaderboards")
 if not folder then folder=Instance.new("Folder");folder.Name="Leaderboards";folder.Parent=root end
 for _,def in Leaderboards.Definitions do
  if def.hidden then continue end
  local value=folder:FindFirstChild(def.key) or Instance.new("StringValue")
  value.Name=def.key;value.Parent=folder
  self.values[def.key]=value
  self:Publish(def,"Loading rankings",{})
 end
end

-- final=true is the leave/shutdown write; it also forgets the per-server cache.
function Leaderboards:Write(session,final)
 local userId=session.userId
 if self.preview or not session.loaded or session.saveLost or session.saveStatus=="studio-session" then return end
 -- A periodic write may still be yielding; run the leave write right after it.
 if self.writing[userId] then if final then self.finalAfter[userId]=session end return end
 self.writing[userId]=true
 -- Capture before yielding; clients never submit leaderboard scores.
 local values={}
 for _,def in Leaderboards.Definitions do values[def.key]=valueOf(session,def.key) end
 local written=self.written[userId] or {};self.written[userId]=written
 for _,def in Leaderboards.Definitions do
  local value=values[def.key]
  -- Admin-assisted armies (AdminService) leave the Strongest Army board once.
  if def.key=="ArmyPower" and session.adminAssisted and AdminConfig.KeepRankingsClean then
   if written[def.key]~=-1 then
    local ok=pcall(function() self.stores[def.key]:RemoveAsync(tostring(userId)) end)
    if ok then written[def.key]=-1 end
   end
   continue
  end
  -- Skip unchanged values and never create a zero entry (no empty supporters).
  if written[def.key]==value or (value<=0 and written[def.key]==nil) then continue end
  local ok,err=pcall(function() self.stores[def.key]:SetAsync(tostring(userId),value) end)
  if ok then written[def.key]=value
  else warn("[ChickenLeaderboards] "..def.key.." update deferred: "..tostring(err)) end
 end
 self.writing[userId]=nil
 local after=self.finalAfter[userId]
 if after then self.finalAfter[userId]=nil;self:Write(after,true);return end
 if final then self.written[userId]=nil end
end

-- Display names for the shown rows, one batched request, cached per server.
function Leaderboards:ResolveNames(ids)
 local missing={}
 for _,id in ids do if not self.names[id] then table.insert(missing,id) end end
 if #missing>0 then
  local ok,infos=pcall(function() return UserService:GetUserInfosByUserIdsAsync(missing) end)
  if ok and type(infos)=="table" then
   for _,info in infos do if info.Id then self.names[info.Id]=info.DisplayName or info.Username end end
  end
  for _,id in missing do
   if not self.names[id] then
    local fetched,name=pcall(Players.GetNameFromUserIdAsync,Players,id)
    if fetched then self.names[id]=name end
   end
  end
 end
end

function Leaderboards:Refresh()
 for _,def in Leaderboards.Definitions do
  if not self.alive then return end
  if def.hidden then continue end
  local raw={}
  if self.preview then
   for _,session in self.sessions do if session.loaded and not session.saveLost and session.userId>0 then
    table.insert(raw,{key=tostring(session.userId),value=valueOf(session,def.key)})
    self.names[session.userId]=session.name
   end end
   table.sort(raw,function(a,b) if a.value==b.value then return a.key<b.key end;return a.value>b.value end)
  else
   local ok,page=pcall(function() return self.stores[def.key]:GetSortedAsync(false,Leaderboards.Top):GetCurrentPage() end)
   if not ok then self:Publish(def,"Rankings unavailable · retrying",nil);continue end
   raw=page
  end
  local ids={}
  for i=1,math.min(#raw,Leaderboards.Top) do
   local id=tonumber(raw[i].key)
   if id and raw[i].value>0 then table.insert(ids,id) end
  end
  self:ResolveNames(ids)
  if not self.alive then return end
  local entries={}
  for _,entry in raw do
   local id=tonumber(entry.key)
   if id and entry.value>0 and #entries<Leaderboards.Top then
    table.insert(entries,{rank=#entries+1,userId=id,name=string.sub(self.names[id] or ("Player "..id),1,20),value=entry.value})
   end
  end
  self:Publish(def,if self.preview then "Studio preview" else "Global",entries)
 end
end

function Leaderboards:Step(now)
 if not self.alive or self.busy or now<self.nextUpdate then return end
 self.nextUpdate=now+(if self.preview then 5 else 60);self.busy=true
 task.spawn(function()
  local ok,err=pcall(function()
   for _,session in self.sessions do if not session.closing then self:Write(session) end end
   self:Refresh()
  end)
  self.busy=false
  if not ok then warn("[ChickenLeaderboards] Refresh deferred: "..tostring(err)) end
 end)
end

function Leaderboards:Destroy()
 self.alive=false
end
return Leaderboards
