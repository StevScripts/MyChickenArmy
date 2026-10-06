-- Run in EDIT. Real ownership/combat modules, isolated actors; no saved profiles.
local Server=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local cache={}
local function fresh(module)
 if cache[module]~=nil then return cache[module] end
 local chunk=assert(loadstring(module.Source,"="..module:GetFullName()))
 setfenv(chunk,setmetatable({script=module,require=fresh},{__index=getfenv()}))
 local result=chunk();cache[module]=result;return result
end
local Growth=fresh(Shared.ChickenGrowth)
local created=0
local function actor(parent,name,species,stars,foot,level,boss)
 created+=1
 local model=Instance.new("Model");model.Name=name;model.Parent=parent
 local root=Instance.new("Part");root.Anchored=true;root.CFrame=CFrame.new(foot);root.Parent=model;model.PrimaryPart=root
 model:SetAttribute("FootOffset",0)
 model:SetAttribute("Level",level or 1)
 model:SetAttribute("MergeVisualScale",1)
 model:SetAttribute("AppliedBaseVisualScale",Growth.BaseScale)
 if boss then model:SetAttribute("ChickenKing",true) end
 local a={model=model,root=root,footOffset=0,stops=0,steps=0,moves=0}
 function a:Stop() self.stops+=1 end
 function a:Step() self.steps+=1;return "idle" end
 function a:Position() return self.root.Position end
 function a:SetParent(parent_) self.model.Parent=parent_ end
 function a:MoveTo() self.moves+=1 end
 function a:Destroy() self.destroyed=true;self.model:Destroy() end
 return a
end
-- Only the physical rig constructor is replaced; adoption, attributes, ownership,
-- combat state, lifecycle cleanup and respawn all execute their real modules.
cache[Server.PetActor]={new=function(parent,name,species,stars,foot)
 return actor(parent,name,species,stars,foot)
end}
local World=fresh(Server.WorldService)
local King=fresh(Server.KingArena)
local Battles=fresh(Server.BattleService)
local Session=fresh(Server.PlayerSession)
local Progression=fresh(Shared.Progression)
local KingEncounter=fresh(Server.KingEncounter)
local Config=fresh(Shared.Config)
local results={}
local function test(name,fn)
 local root=Instance.new("Folder");root.Name="GuardHandoffFixture"
 local ok,why=pcall(fn,root)
 root:Destroy()
 table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
end
local function record(parent,roster)
 local folder=Instance.new("Folder");folder.Parent=parent
 local defenders=Instance.new("Folder");defenders.Parent=folder
 local r={folder=folder,defenders=defenders,frame=CFrame.new(10000,1.05,200),busy=false,
  actors={},patrols={},roster=roster,promotion=1}
 for i,pet in roster do
  local at=r.frame.Position+Vector3.new(8+i,0,4-i)
  r.actors[i]=actor(defenders,"Guard"..i,pet.species,pet.stars,at,pet.level)
  r.patrols[i]={Step=function() error("Detached idle patrol was stepped") end}
 end
 return r
end
local function arena(parent)
 local folder=Instance.new("Folder");folder.Parent=parent
 local flag=Instance.new("Part");flag.Parent=folder
 local gui=Instance.new("BillboardGui");gui.Parent=folder
 local status=Instance.new("TextLabel");status.Parent=gui
 local k=setmetatable({folder=folder,flag=flag,status=status,busy=false,guards={},guardPatrols={},
  kingPatrol={Step=function() error("Detached King patrol was stepped") end}},King)
 for i,pet in KingEncounter.Definition().roster do
  local a=actor(folder,"Idle"..i,pet.species,pet.stars,Vector3.new(8+i,1.05,4-i),pet.level,pet.boss)
  if i==1 then k.actor=a else table.insert(k.guards,a);table.insert(k.guardPatrols,{}) end
 end
 return k
end
local function fixture(parent,target)
 local s=Session.new(-106,"Guard handoff fixture",1);s.loaded=true
 local w=World.new();w.root=parent;w.lanes[1]={}
 function w:Position() return Vector3.new(10000,1.05,100) end
 function w:ReturnPosition(_,_,slot) return self:Position()+Vector3.new(slot*3,0,0) end
 function w:OutpostFrame(i) return self.outposts[i].frame end
 function w:UpdateSession() end
 local original
 if target=="king:1" then
  w.kingArena=arena(parent);original={w.kingArena.actor}
  for _,a in w.kingArena.guards do table.insert(original,a) end
 else
  local roster=if target=="camp:1" then Progression.Roster(1,1) else Progression.OutpostRoster(1)
  local r=record(parent,roster);original=table.clone(r.actors)
  if target=="camp:1" then w.lanes[1][1]=r else w.outposts[1]=r end
 end
 local service=Battles.new({[s.userId]=s},w)
 if target=="king:1" then
  for i=1,#Config.Camps do service.campOwners["1:"..i]={userId=s.userId,name=s.name} end
 end
 local before={};for i,a in original do before[i]=a:Position() end
 local ok,why=service:Attack(s,target,0);assert(ok,why)
 return service.battles[s.outgoing],original,before,w
end

test("camp and outpost transfers survive busy cleanup with their positions intact",function(root)
 for _,kind in {"camp","outpost"} do
  local w=World.new();w.lanes[1]={}
  local r=record(root,{{species="Duck",stars=1,level=1},{species="Mallard",stars=1,level=1}})
  if kind=="camp" then w.lanes[1][1]=r else w.outposts[1]=r end
  local original=table.clone(r.actors);local at=original[1]:Position()
  local taken=w:TakeTerritoryDefenders({plot=1,index=1,outpost=if kind=="outpost" then 1 else nil})
  assert(#taken==2 and taken[1]==original[1] and taken[2]==original[2])
  assert(next(r.actors)==nil and next(r.patrols)==nil)
  if kind=="camp" then w:SetCampBusy(1,true,1) else w:SetOutpostBusy(1,true) end
  w:StepCampPatrol(r,1)
  assert(not taken[1].destroyed and not taken[2].destroyed and taken[1]:Position()==at)
  assert(taken[1].stops>0 and taken[1].moves==0)
 end
end)

test("missing, busy and already conquered territories cannot surrender idle ownership",function(root)
 local w=World.new();w.lanes[1]={}
 assert(next(w:TakeTerritoryDefenders({plot=1,index=1}))==nil)
 assert(next(w:TakeTerritoryDefenders({outpost=1}))==nil)
 assert(next(w:TakeTerritoryDefenders({king=true}))==nil)
 for _,kind in {"camp","outpost","king"} do
  for _,state in {"busy","owned"} do
   local r=if kind=="king" then arena(root) else record(root,{{species="Duck",stars=1,level=1}})
   if state=="busy" then r.busy=true elseif kind=="king" then r.ownerId=99 else r.conquerorId=99 end
   if kind=="king" then w.kingArena=r elseif kind=="camp" then w.lanes[1][1]=r else w.outposts[1]=r end
   local a=if kind=="king" then r.actor else r.actors[1]
   assert(next(w:TakeTerritoryDefenders({king=kind=="king",outpost=if kind=="outpost" then 1 else nil,plot=1,index=1}))==nil)
   assert((if kind=="king" then r.actor else r.actors[1])==a and a.stops==0 and not a.destroyed)
  end
 end
end)

test("King and Royal Flock retain roster order and leave idle patrol ownership",function(root)
 local k=arena(root);local king=k.actor;local guards=table.clone(k.guards)
 local taken=k:TakeDefenders()
 assert(taken[1]==king and #taken==1+#guards)
 for i,a in guards do assert(taken[i+1]==a) end
 assert(not k.actor and not k.kingPatrol and next(k.guards)==nil and next(k.guardPatrols)==nil)
 k:SetBusy(true,"Fixture");k:Step(1)
 for _,a in taken do assert(not a.destroyed and a.moves==0 and a.stops>0) end
 assert(next(k:TakeDefenders())==nil)
end)

test("attacking camp or King adopts each existing guard without moving it",function(root)
 -- Outposts are disabled by Progression.Outposts; their handoff is covered above.
 for _,target in {"camp:1","king:1"} do
  local b,original,before=fixture(root,target)
  local index=0
  for _,u in b.units do if u.side=="B" then
   index+=1;local a=b.actors.actors[u.id]
   assert(a==original[index],target.." replaced a visible guard")
   assert(a.model.Parent==b.actors.folder and a.model:GetAttribute("Side")=="B")
   assert(a:Position()==before[index] and u.x==before[index].X and u.z==before[index].Z,target.." repositioned a guard")
   assert(not a.destroyed and a.moves==0)
  end end
  assert(index==#original and b.target==target)
 end
end)

test("guard deaths retain normal respawn positions and reuse rigs; the King stays defeated",function(root)
 local b,original=fixture(root,"king:1")
 b.phase="Fight"
 local boss,guard
 for _,u in b.units do if u.side=="B" then if u.boss then boss=u elseif not guard then guard=u end end end
 local a=b.actors.actors[guard.id];local spawnX,spawnZ=guard.spawnX,guard.spawnZ
 local count=created
 boss.hp,boss.respawnAt,guard.hp,guard.respawnAt=0,1,0,1
 b:StepDefenderSpawns(1)
 assert(boss.hp==0 and original[1]==b.actors.actors[boss.id])
 assert(guard.hp==guard.maxHp and guard.spawnSerial==1 and guard.respawnAt==nil)
 assert(b.actors.actors[guard.id]==a and not a.destroyed and created==count)
 assert(guard.x==spawnX and guard.z==spawnZ and math.abs(a:Position().X-spawnX)<.001 and math.abs(a:Position().Z-spawnZ)<.001)
end)
return results
