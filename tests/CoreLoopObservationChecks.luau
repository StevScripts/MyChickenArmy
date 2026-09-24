-- Isolated observation checks; no profiles, world edits or network traffic.
local Server=game.ServerStorage.PetRoll
local GameServer=require(Server.GameServer)
local Session=require(Server.PlayerSession)
local Telemetry=require(Server.LoopTelemetry)
local Checks={}

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,detail=pcall(fn);table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
 end
 local function setup()
  local session=Session.new(9001,"Observation",1);session.loaded=true
  local app=setmetatable({sessions={[9001]=session},limits={},telemetry=Telemetry.new(),
   recruitObservations={},awayObservations={},battles={battles={}},world={}},GameServer)
  function app.world:CanCommand() return true end
  function app.world:UpdateSession() end
  function app:Send() end
  return app,session
 end
 test("A home purchase arrives during a locked finite contest, once",function()
  local app,s=setup();local petId=s:BestPetIds()[1]
  app.recruitObservations[s.userId]={[petId]={at=1,assignment="Added"}}
  local battle={id="finite",phase="Fight",rosterLocked=true,incomeSite=true,attacker=s.userId,
   units={{petId=petId,side="A",hp=10,reinforcing=true}}}
  function battle:ReachedCamp() return true end
  s.outgoing,s.armyState=battle.id,"Deployed";app.battles.battles[battle.id]=battle
  app:ObserveLoop(.1,2);assert(#app.telemetry:Drain()==0)
  battle.units[1].reinforcing=false
  app:ObserveLoop(.1,3);local events=app.telemetry:Drain()
  assert(#events==1 and events[1].name=="RecruitArrived" and events[1].fields.seconds==2)
  app:ObserveLoop(.1,4);assert(#app.telemetry:Drain()==0)
  return "Committed purchase observed at actual arrival, before contest resolution"
 end)
 test("Deployment counts living committed travelers separately from selection",function()
  local app,s=setup()
  local battle={id="finite",incomeSite=true,attacker=s.userId,
   units={{side="A",hp=10,reinforcing=true},{side="A",hp=10},{side="A",hp=0,contestUnavailable=true}}}
  app.battles.battles[battle.id]=battle
  function app.battles:Attack(session) session.outgoing=battle.id;return true,"Deployed" end
  app:Handle({UserId=s.userId},{action="Attack",targetId="income:1",id=1})
  local events=app.telemetry:Drain()
  assert(#events==1 and events[1].name=="ArmyDeployed")
  assert(events[1].fields.count==2 and events[1].fields.selectedCount==3)
  return "Two available committed lives, including traveler; three selected"
 end)
 test("Away estimate never debits coins or creates egg receipts",function()
  local app,s=setup();local before=s.coins
  s.armyState="Deployed";for id in s.pets do s.awayPets[id]=true end
  app:ObserveLoop(1,10);app:ObserveLoop(1,11)
  s.armyState="Home";s.awayPets={};app:ObserveLoop(.1,12)
  local events=app.telemetry:Drain()
  assert(#events==1 and events[1].name=="ArmyReturned" and events[1].fields.estimated)
  assert(events[1].fields.foregoneEggValue==32 and s.coins==before and s.sessionIncome.eggs==0)
  return "Two seconds of estimated 16/sec production remain observation only"
 end)
 return results
end

return Checks
