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
 -- October 23 empty start: a new profile has no chickens; these checks assume the old three-Duck flock.
 for _=1,3 do s:AddPet("Duck",1).investment=0 end
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
 -- October 13 (Mini War style): camps go in any order; only an unopened King
 -- marches through unbeaten home camps (LaneConquestChecks covers other lanes).
 local function fresh()
  local s,service=setup();s.firstWins={};s.kingCleared=false;s.campUnlocked=1;s.tutorial.wonCamp=true
  return s,service
 end
 test("Camp orders are direct; an unopened King goes through unbeaten home camps",function()
  local s,service=fresh();s.firstWins={true}
  local camp;for _,t in service:Targets(s,0) do if t.id=="camp:3" then camp=t end end
  assert(camp and camp.available and not camp.via)
  assert(service:Attack(s,"camp:3",0) and service.battles[s.outgoing].target=="camp:3")
  local k,service2=fresh();k.firstWins={true}
  local king;for _,t in service2:Targets(k,0) do if t.id=="king:1" then king=t end end
  assert(king and king.available and king.via==Route.Name("camp:2"))
  assert(service2:Attack(k,"king:1",0))
  local b=service2.battles[k.outgoing];assert(b.target=="camp:2" and b.routeGoal=="king:1")
  return "Camp 3 is direct; the King order begins at Camp 2"
 end)
 test("King opens straight away once the home lane or an earlier King is won",function()
  for _,profile in {{wins={true,true,true},king=false},{wins={},king=true}} do
   local s,service=fresh();s.firstWins,s.kingCleared=profile.wins,profile.king
   assert(service:KingOpen(s))
   assert(service:Attack(s,"king:1",0) and service.battles[s.outgoing].target=="king:1")
  end
  local s,service=fresh();s.firstWins={true,true}
  assert(not service:KingOpen(s))
  assert(service:Attack(s,"king:1",0))
  local b=service.battles[s.outgoing];assert(b.target=="camp:3" and b.routeGoal=="king:1")
  return "Full home lane or saved King clear goes direct; otherwise the missing camp first"
 end)
 test("Recall and defeat keep beaten camps counted",function()
  for _,outcome in {"Recall","B"} do
   local s,service=fresh();assert(service:Attack(s,"camp:1",0))
   local b=service.battles[s.outgoing];assert(b.target=="camp:1")
   prepareCapture(b,1);service:Finish(b,"A",1)
   assert(s.firstWins[1] and b.routeCamps[1])
   assert(service:Unclaim(s,"camp:1",2))
   assert(service:Attack(s,"camp:2",3));b=service.battles[s.outgoing]
   if outcome=="Recall" then assert(service:ReturnHome(s,4)) else service:Finish(b,"B",4) end
   for i=1,1000 do service:Step(.1,4+i*.1);if s.armyState=="Home" then break end end
   assert(s.armyState=="Home","Army did not return home")
   local camps=service:RouteProgress(s)
   assert(camps[1] and not camps[2])
   assert(service:Attack(s,"camp:2",105))
   assert(service.battles[s.outgoing].target=="camp:2")
  end
  return "After a recall or a loss, Camp 1 still counts as beaten"
 end)
 test("An occupied prerequisite blocks the order instead of being skipped",function()
  local s,service=fresh();service.campBusy["1:1"]="occupied"
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
  -- October 23 empty start: a new profile has no chickens; these checks assume the old three-Duck flock.
  for _=1,3 do other:AddPet("Duck",1).investment=0 end
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
  -- October 23 empty start: a new profile has no chickens; these checks assume the old three-Duck flock.
  for _=1,3 do other:AddPet("Duck",1).investment=0 end
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
