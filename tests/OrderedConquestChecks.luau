-- Isolated route/capture regressions; no player data or live-world edits.
local S=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Session=require(S.PlayerSession)
local Battles=require(S.BattleService)
local Route=require(Shared.CampaignRoute)
local Config=require(Shared.Config)
local Layout=require(Shared.FlockLayout)
local Checks={}
local function setup()
 local s=Session.new(1,"Route Tester",1)
 s.firstWins={true,true};s.frontierWins={true,true,true,true,true,true};s.kingCleared=true;s.campUnlocked=2
 local w={}
 function w:Position(_) return Vector3.new(0,1.05,-240) end
 function w:CampPosition(i,_) return Vector3.new(0,1.05,if i==1 then -177 else -89) end
 function w:CampFrame(i,plot) return CFrame.new(self:CampPosition(i,plot)) end
 function w:ReturnPosition(_,_,slot) local x,z=Layout.Home(slot);return self:Position(1)+Vector3.new(x,0,z) end
 function w:SetCampBusy(...) end
 function w:SetOutpostBusy(...) end
 function w:OutpostFrame(i) return CFrame.new(145*math.cos(i*math.pi/3),1.05,145*math.sin(i*math.pi/3)) end
 return s,Battles.new({[1]=s},w)
end
local function prepareCapture(b,now)
 for _,u in b.units do
  u.marchPath=nil;u.reinforcing=false;u.retiring=false
  if u.side=="A" then u.hp=u.maxHp;u.x,u.z=b.destination.X,b.destination.Z
  else u.hp=0;u.respawnAt=nil end
 end
 b.assembling=false;b:BeginCapture(now)
 b.captureElapsed=Config.CaptureSeconds-.2
end
function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,result=pcall(fn);table.insert(results,{name=name,passed=ok,detail=tostring(result)})
 end
 test("Old saves cannot skip prerequisites in a new server session",function()
  for _,target in {"camp:2","king:1"} do
   local s,service=setup()
   local entry;for _,t in service:Targets(s,0) do if t.id==target then entry=t end end
   assert(entry and entry.available and entry.via==Route.Name("camp:1"))
   assert(service:Attack(s,target,0))
   local b=service.battles[s.outgoing]
   assert(b.target=="camp:1" and b.routeGoal==target)
   assert(next(b.routeCamps)==nil and s.firstWins[2] and s.kingCleared)
  end
  return "Camp 2 and King orders begin at Camp 1; saved unlocks retained"
 end)
 test("King order captures Camp 1 then Camp 2 before moving to King",function()
  local s,service=setup();assert(service:Attack(s,"king:1",0))
  local time=1
  for index=1,2 do
   local b=service.battles[s.outgoing];assert(b.target=="camp:"..index)
   prepareCapture(b,time)
   assert(not b.routeCamps[index],"Defender deaths counted as conquest")
   service:Step(.1,time+.1)
   assert(s.outgoing==b.id and b.phase=="Capture" and not b.routeCamps[index],"Partial capture skipped ahead")
   service:Step(.1,time+.2)
   assert(b.phase=="Holding" and b.routeCamps[index],"Full capture did not clear prerequisite")
   service:Step(.1,time+.2+Config.RouteRegroupSeconds+.01)
   local nextBattle=service.battles[s.outgoing]
   assert(nextBattle~=b and nextBattle.routeCamps[index])
   time+=10
   -- The old camp repopulates behind the army without reversing this forward push.
   for _,u in nextBattle.units do if u.side=="A" then u.x,u.z=nextBattle.destination.X,nextBattle.destination.Z end end
   service:ReleaseClearedCamps(time);service:ReleaseClearedCamps(time+Config.CampRespawnGrace+.01)
   assert(service.campOwners["1:"..index]==nil,"Vacated camp stayed conquered")
  end
  assert(service.battles[s.outgoing].target=="king:1")
  return "Camp 1 → full capture → Camp 2 → full capture → King, with no backward loop"
 end)
 test("Recall and defeat reset the path but preserve earned progression",function()
  for _,outcome in {"Recall","B"} do
   local s,service=setup();assert(service:Attack(s,"camp:2",0))
   local b=service.battles[s.outgoing];prepareCapture(b,1);service:Finish(b,"A",1)
   assert(b.routeCamps[1])
   assert(service:Attack(s,"camp:2",3));b=service.battles[s.outgoing]
   if outcome=="Recall" then assert(service:ReturnHome(s,4)) else service:Finish(b,"B",4) end
   for i=1,1000 do service:Step(.1,4+i*.1);if s.armyState=="Home" then break end end
   assert(s.armyState=="Home","Army did not return home")
   local camps,outposts=service:RouteProgress(s)
   assert(not camps[1] and not camps[2] and next(outposts)==nil)
   assert(service:Attack(s,"camp:2",105))
   assert(service.battles[s.outgoing].target=="camp:1")
   assert(s.firstWins[1] and s.firstWins[2] and s.frontierWins[6] and s.kingCleared)
  end
  return "A new home push starts at Camp 1; permanent unlocks survive both return outcomes"
 end)
 test("An occupied prerequisite blocks the order instead of being skipped",function()
  local s,service=setup();service.campBusy["1:1"]="occupied"
  local ok=service:Attack(s,"king:1",0)
  assert(not ok and s.outgoing==nil)
  for _,t in service:Targets(s,0) do if t.id=="king:1" then assert(not t.available) end end
  return "Blocked prerequisite cannot be bypassed through another target"
 end)
 test("All side outposts are direct destinations at the starting rank",function()
  for index=1,#require(Shared.Progression).Outposts() do
   local s,service=setup()
   local target="outpost:"..index
   assert(table.concat(Route.Plan(target,{},{}),",")==target)
   local entry;for _,t in service:Targets(s,0) do if t.id==target then entry=t end end
   assert(entry and entry.available and not entry.via)
   assert(service:Attack(s,target,0))
   assert(service.battles[s.outgoing].target==target and not service.battles[s.outgoing].routeGoal)
  end
  assert(table.concat(Route.Plan("king:1",{true,true},{}),",")=="king:1")
  assert(Route.Plan("camp:99",{}, {})==nil)
  return "Optional outposts require no main camps, previous outposts or rank; King keeps its two blockers"
 end)
 test("An abandoned shared camp returns to enemies before a new capture",function()
  local s,service=setup()
  local other=Session.new(2,"Other Commander",2);service.sessions[2]=other
  assert(service:Attack(other,"outpost:1",0))
  local held=service.battles[other.outgoing];prepareCapture(held,1);service:Finish(held,"A",1)
  assert(service:ReturnHome(other,2))
  for _,u in held.units do u.x,u.z=0,-240 end
  service:ReleaseClearedCamps(3);service:ReleaseClearedCamps(3+Config.CampRespawnGrace+.01)
  assert(not service.campOwners["outpost:1"])
  assert(service:Attack(s,"outpost:1",4))
  local b=service.battles[s.outgoing]
  assert(b:Alive("B")>0 and not b.friendlyTerritory)
  prepareCapture(b,5)
  service:Step(.1,5.1)
  assert(not service.campOwners["outpost:1"])
  service:Step(.1,5.2)
  assert(service.campOwners["outpost:1"].userId==1)
  local _,outposts=service:RouteProgress(other);assert(not outposts[1])
  assert(other.frontierWins[1] and s.frontierWins[1])
  return "Hostile garrison returns after departure; full recapture required; both players keep earned wins"
 end)
 test("Holding a conquered camp suppresses enemies and repeated kill rewards",function()
  local s,service=setup()
  local before=s.coins
  assert(service:Attack(s,"camp:1",0))
  local b=service.battles[s.outgoing]
  prepareCapture(b,1);service:Finish(b,"A",1)
  assert(b.phase=="Holding" and b.defenderRespawnAt==nil and s.coins==before)
  for i=1,100 do service:Step(.1,1+i*.1) end
  assert(b:Alive("B")==0 and s.coins==before)
  return "Occupied conquered camp has no hostile respawn or repeated kill cash"
 end)
 test("A side excursion cannot reuse main-path clearance",function()
  local s,service=setup();assert(service:Attack(s,"camp:1",0))
  local b=service.battles[s.outgoing];prepareCapture(b,1);service:Finish(b,"A",1)
  assert(service:Attack(s,"outpost:4",2))
  local side=service.battles[s.outgoing]
  for _,u in side.units do if u.side=="A" then u.x,u.z=side.destination.X,side.destination.Z end end
  service:ReleaseClearedCamps(3);service:ReleaseClearedCamps(3+Config.CampRespawnGrace+.01)
  prepareCapture(side,4);service:Finish(side,"A",4)
  assert(service:Attack(s,"king:1",5))
  assert(service.battles[s.outgoing].target=="camp:1")
  return "Side destination is direct; returning to main route respects newly respawned blockers"
 end)
 test("Leaving the server releases only the departing player's ownership",function()
  local s,service=setup()
  local other=Session.new(2,"Other Commander",2);service.sessions[2]=other
  service:SetTerritoryOwner("1:1",s,{plot=1,index=1})
  service:SetTerritoryOwner("king:1",s,{king=true})
  service:SetTerritoryOwner("outpost:1",other,{outpost=1})
  service:CancelPlayer(s.userId,0)
  assert(not service.campOwners["1:1"] and not service.campOwners["king:1"])
  assert(service.campOwners["outpost:1"].userId==2 and s.firstWins[1])
  return "Session ownership clears without erasing permanent unlocks or another player's camp"
 end)
 return results
end
return Checks
