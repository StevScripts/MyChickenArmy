-- October 14 launch (O1): a King clear opens Veteran Operations; S15 still does.
-- Elite/Royal research is shorter. Isolated: unsaved sessions, stub battles and
-- world, no Players/characters, so Start never builds an arena or moves anyone.
-- Root runner in Studio Edit (fresh module clones, like LaneConquestChecks):
-- require(game.ServerStorage.PetRollTests.OperationUnlockChecks).Run()
-- Prints PASS/FAIL per check and a summary; error()s if any check fails.
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local OperationService=require(Server.OperationService)
local ResearchCatalog=require(Shared.ResearchCatalog)
local Research=require(Shared.ResearchRules)
local Guide=require(Shared.TutorialGuide)
local Checks={}

-- Refusals that come after the tier gate. With no real Player these are as far
-- as Start can go in Edit mode, so any of them means the gate let the player in.
local PAST_GATE={
 ["Select an army first."]=true,
 ["Wait for your character to return."]=true,
 ["The Operation arena is not available in this place."]=true,
}

local function setup(kingCleared,research)
 local s=Session.new(-9471,"Operations fixture",1);s.loaded=true
 s.kingCleared=kingCleared
 for _,id in research do
  local cursor=id
  while cursor do s.research.completed[cursor]=true;cursor=ResearchCatalog.Nodes[cursor].prerequisite end
 end
 s.researchEffects=Research.Effects(s.research)
 local service=OperationService.new({battles={},Remove=function() end},{UpdateSession=function() end},{[s.userId]=s})
 return s,service
end

local function start(service,s,id)
 return service:Start(s,id,s.research.revision,0)
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,why=pcall(fn)
  table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
 end

 test("King cleared, no S15: Veteran Patrol passes the gate; Elite is refused",function()
  local s,service=setup(true,{})
  assert(not s.research.completed.S15 and s.researchEffects.operations==0,"Fixture has Operations research")
  assert(OperationService.Tier(s)==1,"Tier "..tostring(OperationService.Tier(s)))
  local ok,why=start(service,s,"1:1")
  assert(not ok and PAST_GATE[why],"Veteran Patrol refused at the gate: "..tostring(why))
  ok,why=start(service,s,"2:1")
  assert(not ok and why==OperationService.LockedMessage(2),"Elite not locked: "..tostring(why))
  ok,why=start(service,s,"3:3")
  assert(not ok and why==OperationService.LockedMessage(3),"Royal not locked: "..tostring(why))
 end)

 test("S15 without a King clear still opens Veteran Operations",function()
  local s,service=setup(false,{"S15"})
  assert(s.researchEffects.operations==1 and OperationService.Tier(s)==1)
  local ok,why=start(service,s,"1:1")
  assert(not ok and PAST_GATE[why],"Veteran Patrol refused at the gate: "..tostring(why))
  ok,why=start(service,s,"2:1")
  assert(not ok and why==OperationService.LockedMessage(2),"Elite not locked: "..tostring(why))
 end)

 test("Neither path: Veteran is refused with the locked message",function()
  local s,service=setup(false,{})
  assert(OperationService.Tier(s)==0)
  for _,id in {"1:1","1:2","1:3"} do
   local ok,why=start(service,s,id)
   assert(not ok and why==OperationService.LockedMessage(1),id.." not locked: "..tostring(why))
  end
  assert(OperationService.LockedMessage(1):find("Chicken King",1,true),"Veteran message omits the King")
  local ok,why=start(service,s,"9:9")
  assert(not ok and why==OperationService.LockedMessage(nil),"Unknown id: "..tostring(why))
 end)

 test("Client state tier equals OperationService.Tier for every combination",function()
  for _,case in {{false,{}},{true,{}},{false,{"S15"}},{true,{"S15"}},{true,{"S16"}},{false,{"S17"}}} do
   local s,service=setup(case[1],case[2])
   local snapshot=service:Snapshot(s)
   assert(snapshot.tier==OperationService.Tier(s),"Snapshot "..tostring(snapshot.tier).." vs "..OperationService.Tier(s))
  end
  local s=setup(true,{"S16"});assert(OperationService.Tier(s)==2,"King clear lowered research tier")
  s=setup(true,{"S17"});assert(OperationService.Tier(s)==3,"King clear lowered research tier")
 end)

 test("S16 quotes 7,200 s and S17 21,600 s at research speed 0; S15 and prices unchanged",function()
  local effects=Research.Effects(Research.New())
  assert(effects.speed==0,"Fresh research speed "..tostring(effects.speed))
  local nodes=ResearchCatalog.Nodes
  assert(Research.Duration(nodes.S16,effects)==7200,"S16 "..Research.Duration(nodes.S16,effects))
  assert(Research.Duration(nodes.S17,effects)==21600,"S17 "..Research.Duration(nodes.S17,effects))
  assert(Research.Duration(nodes.S15,effects)==3600,"S15 "..Research.Duration(nodes.S15,effects))
  assert(nodes.S15.price==2500000 and nodes.S16.price==25000000 and nodes.S17.price==250000000,"A price changed")
  assert(nodes.S15.description:find("Chicken King",1,true),"S15 description")
 end)

 test("Next goal after a King clear names Veteran Patrol, then ends",function()
  local s,service=setup(true,{})
  local state={kingCleared=true,tutorial={guideCompleted=true},pets={{id="a"}},selectedCount=1,armyState="Home",
   operations=service:Snapshot(s)}
  local goal=Guide.NextGoal(state)
  assert(goal and goal.goal and goal.text:find("Veteran Patrol",1,true),"Goal: "..tostring(goal and goal.text))
  assert(not string.find(goal.id,"Goal:Attack:",1,true),"Goal reused the attack prompt id")
  state.outgoing="fight";assert(Guide.NextGoal(state)==nil,"Goal shown during a fight");state.outgoing=nil
  state.tutorial.goalsHidden=true;assert(Guide.NextGoal(state)==nil,"Hidden goals shown");state.tutorial.goalsHidden=nil
  s.research.operationWins["1:1"]=true;state.operations=service:Snapshot(s)
  assert(Guide.NextGoal(state)==nil,"Goal remained after a Veteran win")
  -- Before the King nothing changes.
  local early=Guide.NextGoal({kingCleared=false,tutorial={guideCompleted=true},pets={},armyState="Home"})
  assert(early and early.id=="Goal:Recruit","Pre-King goal changed: "..tostring(early and early.id))
  early=Guide.NextGoal({kingCleared=false,tutorial={guideCompleted=true},pets={{id="a"}},selectedCount=1,armyState="Home",
   targets={{id="king:1",name="the King",power=1}},power=10})
  assert(early and early.id=="Goal:Attack:king:1","Pre-King King goal changed: "..tostring(early and early.id))
 end)

 local failed=0
 for _,result in results do
  if result.passed then print("PASS  "..result.name)
  else failed+=1;warn("FAIL  "..result.name.."  ->  "..tostring(result.error)) end
 end
 local summary="OperationUnlockChecks: "..(#results-failed).."/"..#results.." passed"
 if failed>0 then error(summary.." ("..failed.." failed)",0) end
 print(summary)
 return results
end
return Checks
