-- October 25 (Stevin): chickens conquering a camp move around and do things instead of
-- standing on a slot while the meter fills. Pure simulation (no rigs): the roam never
-- leaves the objective, the meter fills at the same pace, every chicken acts, and the
-- Holding patrol is unchanged. No player data or live-world edits.
local S=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Session=require(S.PlayerSession)
local Battles=require(S.BattleService)
local Battle=require(S.Battle)
local Config=require(Shared.Config)
local Layout=require(Shared.FlockLayout)
local Checks={}

local function setup()
 local s=Session.new(1,"Conquer Tester",1)
 for _=1,3 do s:AddPet("Duck",1).investment=0 end
 s.firstWins={};s.kingCleared=false;s.campUnlocked=1;s.tutorial.wonCamp=true
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

-- Camp 1 with its guards down and the whole army standing in the objective, capture just begun.
local function captureBattle(seed)
 local s,service=setup()
 assert(service:Attack(s,"camp:1",0),"attack order refused")
 local b=service.battles[s.outgoing]
 for _,u in b.units do
  u.marchPath=nil;u.reinforcing=false;u.retiring=false
  if u.side=="A" then u.hp=u.maxHp;u.x,u.z=b.destination.X,b.destination.Z
  else u.hp=0;u.respawnAt=nil;u.noRespawn=true end
 end
 b.assembling=false;b.holdRandom=Random.new(seed or 7);b:BeginCapture(0)
 return s,service,b
end

local function inside(b,u) return (u.x-b.destination.X)^2+(u.z-b.destination.Z)^2<=Config.CaptureRadius^2 end
local function army(b) local list={};for _,u in b.units do if u.side=="A" then table.insert(list,u) end end;return list end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,result=pcall(fn);table.insert(results,{name=name,passed=ok,detail=tostring(result)})
 end
 test("Conquering chickens trot about inside the objective and the meter fills on time",function()
  local _,_,b=captureBattle(7)
  local units=army(b)
  local start={}
  for _,u in units do start[u.id]={x=u.x,z=u.z} end
  local moved,actions,outcomeAt={},{},nil
  for i=1,140 do
   local t=i*0.1
   local outcome=b:Step(0.1,t)
   assert(b.capturers==#units,"a conquering chicken stopped counting at "..t)
   for _,u in units do
    assert(inside(b,u),"a chicken left the objective at "..t)
    if (u.x-start[u.id].x)^2+(u.z-start[u.id].z)^2>1 then moved[u.id]=true end
    if u.action then actions[u.action]=true end
   end
   if outcome then outcomeAt=t;assert(outcome=="A","outcome "..tostring(outcome));break end
  end
  local expected=Config.ConquestSecondsByCamp[1]
  assert(outcomeAt and math.abs(outcomeAt-expected)<0.15,"captured at "..tostring(outcomeAt).."s, not "..expected)
  local movers=0;for _ in moved do movers+=1 end
  assert(movers>=2,"only "..movers.." chickens moved")
  for _,u in units do assert((u.actionSerial or 0)>=1,"a chicken never acted") end
  local kinds=0
  for name in actions do kinds+=1;assert(table.find(Battle.ConquerActions,name),"unknown action "..name) end
  assert(kinds>=2,"only "..kinds.." action kinds seen")
  return ("captured at %.1fs, %d of %d moved, %d action kinds"):format(outcomeAt,movers,#units,kinds)
 end)
 test("A chicken shoved out of the objective stops counting and walks back in",function()
  local _,_,b=captureBattle(11)
  local units=army(b)
  for i=1,20 do b:Step(0.1,i*0.1) end
  local u=units[1]
  u.x,u.z=b.destination.X+Config.CaptureRadius+3,b.destination.Z
  b:Step(0.1,2.1)
  assert(not inside(b,u) and b.capturers==#units-1,"still counted while outside")
  local back
  for i=22,80 do b:Step(0.1,i*0.1);if inside(b,u) then back=i*0.1;break end end
  assert(back,"never walked back in")
  b:Step(0.1,back+0.1)
  assert(b.capturers==#units,"not counted again after returning")
  return ("back inside after %.1fs"):format(back-2.1)
 end)
 test("Holding keeps the quiet patrol: inside the camp, no conquering actions",function()
  local _,_,b=captureBattle(3)
  local units=army(b)
  for i=1,130 do if b:Step(0.1,i*0.1) then break end end
  local serials={}
  for _,u in units do serials[u.id]=u.actionSerial or 0 end
  b:Hold(13)
  local radius=math.min(Config.CaptureRadius-2,Config.CampHalfSize-3)
  local walked=false
  for i=1,200 do
   b:Step(0.1,13+i*0.1)
   for _,u in units do
    assert(math.sqrt((u.x-b.destination.X)^2+(u.z-b.destination.Z)^2)<=radius+1.5,"patrolled outside the camp")
    assert((u.actionSerial or 0)==serials[u.id],"a holding chicken acted")
    if u.holdWalking then walked=true end
   end
  end
  assert(walked,"nobody patrolled")
  return "patrol stays inside the camp, no actions"
 end)
 test("Snapshots carry the action for the client",function()
  local _,_,b=captureBattle(5)
  for i=1,15 do b:Step(0.1,i*0.1) end
  local found
  for _,u in b:Snapshot(1.5).units do if u.side=="A" and (u.actionSerial or 0)>=1 then found=u end end
  assert(found and table.find(Battle.ConquerActions,found.action),"no action in the snapshot")
  return found.action.." #"..found.actionSerial
 end)
 return results
end

return Checks
