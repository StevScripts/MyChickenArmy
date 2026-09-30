-- Isolated sessions and stub world; no saved players or live-world mutation.
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local Battles=require(Server.BattleService)
local Config=require(Shared.Config)
local Checks={}

local function setup()
 local s=Session.new(-926,"Camp redirect fixture",1);s.loaded=true
 local world={busy={},restored={},owners={}}
 function world:Position() return Vector3.new(10000,1,-100) end
 function world:CampPosition(i) return Vector3.new(10000,1,i*80) end
 function world:CampFrame(i) return CFrame.new(self:CampPosition(i)) end
 function world:ReturnPosition(_,_,slot) return self:Position()+Vector3.new(slot*3,0,0) end
 function world:PetPosition() return nil end
 function world:SetCampBusy(i,busy)
  self.busy[i]=busy
  if not busy and not self.owners[i] then self.restored[i]=(self.restored[i] or 0)+1 end
 end
 function world:SetTerritoryOwner(location,userId)
  if location.index then self.owners[location.index]=userId end
 end
 function world:SetOutpostBusy() end
 function world:OutpostFrame(i) return CFrame.new(10200,1,i*80) end
 return s,Battles.new({[s.userId]=s},world),world
end

local function current(service,s) return assert(service.battles[s.outgoing]) end
local function placeArmy(battle)
 for _,u in battle.units do if u.side=="A" then
  u.x,u.z=battle.destination.X,battle.destination.Z
  u.marchPath=nil;u.reinforcing=false;u.retiring=false
 end end
end
local function arrive(service,s,now)
 local b=current(service,s);placeArmy(b)
 service:Step(0,now)
 assert(b.arrivedAt==now,"Arrival must come from the real travel step")
 return b
end
local function conquer(service,s,now)
 local b=current(service,s)
 for _,u in b.units do if u.side=="B" then u.hp=0;u.respawnAt=nil end end
 arrive(service,s,now)
 service:Finish(b,"A",now)
 return b
end
local function clearLane()
 local s,service,world=setup()
 for i=1,#Config.Camps do
  assert(service:Attack(s,"camp:"..i,i*2))
  conquer(service,s,i*2+1)
 end
 return s,service,world
end
local function target(service,s,id,now)
 for _,entry in service:Targets(s,now) do if entry.id==id then return entry end end
 error("Missing target "..id)
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,why=pcall(fn)
  table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
 end

 for _,phase in {"Travel","Fight","Capture","Holding"} do
  test("Redirect from "..phase.." preserves each chicken's life and cancels attacks",function()
   local s,service=setup()
   assert(service:Attack(s,"camp:1",0))
   local old=current(service,s);old.phase=phase
   local a,b=old.units[1],old.units[2]
   a.hp=math.max(1,a.maxHp-3);a.x,a.z=10007,68;a.pendingAttack={at=100};a.targetId="enemy"
   b.hp=0;b.respawnAt=9;b.reinforcing=false
   local hp,serial=a.hp,a.spawnSerial
   assert(target(service,s,"camp:2",1).available,"Other camp was hidden during combat")
   assert(service:Attack(s,"camp:2",1))
   local nextBattle=current(service,s)
   assert(nextBattle.target=="camp:2" and nextBattle~=old and not service.battles[old.id])
   local moved,dead=nextBattle.units[1],nextBattle.units[2]
   assert(moved.petId==a.petId and moved.hp==hp and moved.x==10007 and moved.z==68)
   assert(moved.spawnSerial==serial and not moved.pendingAttack and not moved.targetId)
   assert(dead.petId==b.petId and dead.hp==0 and dead.respawnAt==9)
   assert(s.armyState=="Traveling" and s.awayPets[a.petId] and s.awayPets[b.petId])
   assert(not s.firstWins[1],"Abandoning an unfinished camp granted conquest")
  end)
 end

 test("Duplicate target and invalid orders leave the current fight untouched",function()
  local s,service=setup();assert(service:Attack(s,"camp:1",0))
  local b=current(service,s);b.phase="Fight";b.units[1].pendingAttack={at=1}
  for _,id in {"camp:1","camp:99","base:2","invalid"} do
   assert(not service:Attack(s,id,1));assert(current(service,s)==b and b.units[1].pendingAttack)
  end
  assert(not target(service,s,"camp:1",1).available)
  service.campBusy["1:2"]="another-army"
  assert(not service:Attack(s,"camp:2",1));assert(current(service,s)==b)
  assert(not target(service,s,"camp:2",1).available)
 end)

 test("Switching repeatedly does not duplicate chickens or pay a kill twice",function()
  local s,service=setup();assert(service:Attack(s,"camp:1",0))
  local b=current(service,s);local count=#s:Lineup()
  b.kills={{serial=1,side="B",species="Duck",level=1,x=0,z=0}}
  local coins=s.coins
  assert(service:Attack(s,"camp:2",1));local earned=s.coins;assert(earned>coins)
  for i=2,12 do
   assert(service:Attack(s,"camp:"..(if i%2==0 then 1 else 2),i))
   local pets={};local total=0
   for _,u in current(service,s).units do if u.side=="A" then
    assert(not pets[u.petId]);pets[u.petId]=true;total+=1
   end end
   assert(total==count and s.coins==earned)
  end
  local total=0;for _ in service.battles do total+=1 end;assert(total==1)
 end)

 test("All cleared camps remain empty through the full forward route",function()
  local s,service,world=setup();assert(service:Attack(s,"king:1",0))
  for i=1,#Config.Camps do
   local b=current(service,s);assert(b.campIndex==i,"Automatic route skipped a camp")
   conquer(service,s,i*10)
   service:Step(0,i*10+Config.RouteRegroupSeconds+.01)
   local nextBattle=current(service,s);assert(nextBattle~=b)
   service:ReleaseClearedCamps(i*10+5)
   service:ReleaseClearedCamps(i*10+9)
   for j=1,i do assert(service.campOwners["1:"..j] and not world.restored[j]) end
  end
  assert(current(service,s).isKing)
  arrive(service,s,40);service:ReleaseClearedCamps(100)
  for i=1,#Config.Camps do assert(service.campOwners["1:"..i] and not world.restored[i]) end
 end)

 test("Retreat from camp 3 to camp 1 frees reservations but preserves all claims",function()
  local s,service,world=clearLane()
  assert(service:Attack(s,"camp:1",20))
  local b=current(service,s)
  assert(b.friendlyTerritory and b:Alive("B")==0)
  for _,u in b.units do u.x,u.z=10050,120 end
  service:ReleaseClearedCamps(21);service:ReleaseClearedCamps(200)
  assert(not b.arrivedAt and not service.campClearedAt["1:2"])
  assert(not world.restored[2] and not world.restored[3])
  arrive(service,s,201)
  service:ReleaseClearedCamps(201+Config.CampRespawnGrace-.01)
  assert(not world.restored[2] and not world.restored[3])
  service:ReleaseClearedCamps(201+Config.CampRespawnGrace+.01)
  assert(not service.campBusy["1:2"] and not service.campBusy["1:3"])
  assert(not world.restored[1] and not world.restored[2] and not world.restored[3])
  assert(service.campOwners["1:1"] and service.campOwners["1:2"] and service.campOwners["1:3"])
  assert(b.routeCamps[2] and b.routeCamps[3],"Owned camps lost route passage")
  service:ReleaseClearedCamps(300);assert(not world.restored[2] and not world.restored[3])
 end)

 test("Returning to camp 2 retains ownership of camps 1 and 3",function()
  local s,service,world=clearLane();assert(service:Attack(s,"camp:2",20))
  arrive(service,s,25);service:ReleaseClearedCamps(25+Config.CampRespawnGrace+.01)
  assert(not world.restored[1] and not world.restored[2] and not world.restored[3])
  assert(service.campOwners["1:1"] and service.campOwners["1:3"] and not service.campBusy["1:3"])
 end)

 test("Changing a retreat mid-march waits for the replacement destination",function()
  local s,service,world=clearLane();assert(service:Attack(s,"camp:1",20))
  for _,u in current(service,s).units do u.x,u.z=10040,100 end
  service:ReleaseClearedCamps(25)
  assert(service:Attack(s,"camp:2",30))
  service:ReleaseClearedCamps(100);assert(not world.restored[3])
  arrive(service,s,101);service:ReleaseClearedCamps(101+Config.CampRespawnGrace+.01)
  assert(not service.campBusy["1:3"] and service.campOwners["1:3"] and not world.restored[3])
 end)

 test("A new forward order cancels a pending abandoned-camp respawn",function()
  local s,service,world=clearLane();assert(service:Attack(s,"camp:1",20));arrive(service,s,25)
  assert(service.campClearedAt["1:3"]==25)
  assert(service:Attack(s,"camp:3",26));service:ReleaseClearedCamps(100)
  assert(not world.restored[2] and not world.restored[3])
  arrive(service,s,101);service:ReleaseClearedCamps(200)
  assert(not world.restored[1] and not world.restored[2] and not world.restored[3])
  assert(not service.departingCamps["1:3"],"The new destination still had a departure timer")
 end)

 test("A living straggler delays enemies after explicitly unclaiming its old camp",function()
  local s,service,world=clearLane();assert(service:Attack(s,"camp:1",20))
  assert(service:Unclaim(s,"camp:3",21))
  local b=current(service,s);placeArmy(b)
  local straggler=b.units[2];straggler.x,straggler.z=10000,240
  service:Step(0,25);service:ReleaseClearedCamps(100)
  assert(b.arrivedAt==25 and not world.restored[2] and not world.restored[3])
  straggler.x,straggler.z=10000,80
  service:ReleaseClearedCamps(101);assert(not world.restored[3])
  service:ReleaseClearedCamps(101+Config.CampRespawnGrace+.01);assert(world.restored[3]==1)
 end)

 test("Abandoned unfinished camps recover without granting cleared-route protection",function()
  local s,service,world=setup();assert(service:Attack(s,"camp:1",0));arrive(service,s,1)
  assert(service:Attack(s,"camp:2",2));service:ReleaseClearedCamps(100)
  assert(not world.restored[1]);arrive(service,s,101)
  service:ReleaseClearedCamps(101+Config.CampRespawnGrace+.01)
  assert(world.restored[1]==1 and not s.firstWins[1] and not service.campOwners["1:1"])
 end)

 test("Returning and shared-defender armies cannot create a second outgoing battle",function()
  for _,state in {"Returning","Defending"} do
   local s,service=setup();assert(service:Attack(s,"camp:1",0))
   local b=current(service,s)
   if state=="Returning" then b.phase="Returning" else b.defender=s.userId;b.attacker=-927 end
   s.armyState=state
   assert(not service:Attack(s,"camp:2",1) and current(service,s)==b)
   assert(not target(service,s,"camp:2",1).available)
  end
 end)

 test("Leaving the server releases retained camps without erasing earned wins",function()
  local s,service,world=clearLane();service:CancelPlayer(s.userId,20)
  service:ReleaseClearedCamps(21);service:ReleaseClearedCamps(21+Config.CampRespawnGrace+.01)
  for i=1,#Config.Camps do
   assert(not service.campOwners["1:"..i] and not service.campBusy["1:"..i] and world.restored[i]==1)
   assert(s.firstWins[i])
  end
 end)

 test("Camp commands remain usable while traveling/fighting and disable the current target",function()
  local Controller=require(game:GetService("StarterPlayer").StarterPlayerScripts.PetRoll.BaseController)
  local s,service=setup();assert(service:Attack(s,"camp:1",0))
  local app={Counts=function() return 2,30,3,2,2 end}
  local controller=Controller.new(app)
  local model={Parent=workspace}
  function model:GetAttribute(key)
   return if key=="CommandTarget" then self.target elseif key=="LaneOwnerIndex" then 1 else nil
  end
  for _,state in {"Traveling","Fighting","Deployed"} do
   app.state={armyState=state,plotIndex=1,targets=service:Targets(s,1)}
   model.target="camp:2";assert(controller:CommandFor(model).action=="Attack")
   model.target="camp:1";assert(controller:CommandFor(model).action==nil)
  end
  app.state.armyState="Returning";assert(controller:CommandFor(model)==nil)
 end)

 test("Physical actor handoff reuses player models and immediately clears attack flags",function()
  local Actors=require(Server.LiveBattleActors)
  local Growth=require(Shared.ChickenGrowth)
  local s,service,world=setup();assert(service:Attack(s,"camp:1",0))
  local old=current(service,s);old.phase="Fight"
  local root=Instance.new("Folder") -- Unparented, disposable models; no live world/physics.
  local ok,why=pcall(function()
   local function fakeActor(u)
    local model=Instance.new("Model")
    model:SetAttribute("Level",u.level or 1);model:SetAttribute("MergeVisualScale",1)
    model:SetAttribute("AppliedBaseVisualScale",Growth.BaseScale)
    model:SetAttribute("Attacking",true)
    local actor={model=model,at=Vector3.new(u.x,1,u.z)}
    function actor:Stop() end
    function actor:Step() end
    function actor:Position() return self.at end
    function actor:SetParent(parent) self.model.Parent=parent end
    function actor:Destroy() self.destroyed=true;self.model:Destroy() end
    return actor
   end
   old.actors=Actors.new(root,old)
   local players,enemies={},{}
   for _,u in old.units do
    local actor=fakeActor(u);old.actors:Adopt(u,actor)
    if u.side=="A" then players[u.petId]=actor else table.insert(enemies,actor) end
   end
   world.root=root
   function world:UpdateSession()
    local b=current(service,s)
    for _,u in b.units do if not b.actors.actors[u.id] then b.actors:Adopt(u,fakeActor(u)) end end
   end
   assert(service:Attack(s,"camp:2",1))
   local b=current(service,s)
   for _,u in b.units do if u.side=="A" then
    local actor=players[u.petId]
    assert(b.actors.actors[u.id]==actor and not actor.destroyed)
    assert(actor.model:GetAttribute("BattleId")==b.id and actor.model:GetAttribute("Attacking")==false)
   end end
   for _,actor in enemies do assert(actor.destroyed) end
   service:Destroy()
  end)
  root:Destroy();assert(ok,why)
 end)
 return results
end
return Checks
