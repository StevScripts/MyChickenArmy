-- Focused arrival regressions; isolated Battle instances, no player data.
local Battle=require(game.ServerStorage.PetRoll.Battle)
local March=require(game.ReplicatedStorage.PetRoll.Shared.ArmyMarch)
local Config=require(game.ReplicatedStorage.PetRoll.Shared.Config)
local Checks={}
local function setup(defenders)
 local b=Battle.new("arrival-check",1,"camp:1",Vector3.new(0,1,65),Vector3.new(0,1,0),0)
 b:AddArmy("A",{{id="front",species="Duck",stars=1},{id="tail",species="Duck",stars=1}},b.origin)
 if defenders then b:AddArmy("B",{{species="Duck",stars=1}},b.destination) end
 for _,u in b.units do u.hp=10000;u.maxHp=10000;if u.side=="B" then u.damage=0 end end
 local front,tail=b.units[1],b.units[2]
 front.x,front.z=0,11.8
 tail.x,tail.z=25,65
 March.Set(tail,{Vector3.new(25,1,65),Vector3.new(25,1,25),Vector3.new(0,1,16)},0)
 return b,front,tail
end
function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,detail=pcall(fn)
  table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
 end
 test("First arrival damages enemies while tail follows its road",function()
  local b,front,tail=setup(true)
  b:Step(.1,.1)
  assert(b.phase=="Fight" and tail.reinforcing and tail.marchPath,"Squad still waiting or tail left its route")
  local route=tail.marchPath
  local hitAt
  for i=2,35 do
   b:Step(.1,i*.1)
   if b.units[3].hp<10000 then hitAt=i*.1;break end
  end
  assert(hitAt and tail.reinforcing,"Front did not attack before the tail arrived")
  assert(tail.marchPath==route and tail.z<65 and math.abs(tail.x-25)<.01,"Combat redirected the tail off its first road segment")
  for i=36,180 do b:Step(.1,i*.1);if not tail.reinforcing then break end end
  assert(not tail.reinforcing and not tail.marchPath,"Late bird never joined")
  return "First damage at "..hitAt.."s; trailing bird kept its road and joined"
 end)
 test("Arrival has normal peck windup without an extra attack interval",function()
  local b,front,tail=setup(true)
  b.phase="Fight";front.reinforcing=true;front.nextAttack=100
  front.x,front.z=0,0;front.marchPath=nil
  tail.retiring=true
  local enemy=b.units[3];enemy.x,enemy.z=0,-1
  b:Step(.05,0)
  assert(not front.reinforcing and front.pendingAttack,"Arriving chicken did not start its peck")
  assert(enemy.hp==10000,"Peck bypassed its windup")
  b:Step(.05,Config.AttackWindupSeconds+.01)
  assert(enemy.hp<10000,"Arrival added an extra cooldown")
  return "Damage after the ordinary "..Config.AttackWindupSeconds.."s windup"
 end)
 test("Empty camp captures before the tail arrives",function()
  local b,_,tail=setup(false)
  b:Step(.1,.1)
  assert(b.phase=="Capture" and b.captureElapsed>0 and tail.reinforcing and tail.marchPath)
  return "Capture began on first arrival"
 end)
 test("Road stragglers cannot rescue a wiped front line",function()
  local b,front,tail=setup(true);b:Step(.1,.1)
  front.hp=0;front.respawnAt=0
  assert(tail.reinforcing and b:Step(.1,.2)=="B","A distant chicken prevented the wipe")
  return "Wipe detected before a base respawn"
 end)
 test("Late arrivals keep walking after victory or recall",function()
  for _,phase in {"Holding","Returning"} do
   local b,_,tail=setup(false);b:Step(.1,.1)
   if phase=="Holding" then b:Hold(.2) else b:Finish("Recall",.2) end
   for i=3,450 do b:Step(.1,i*.1) end
   assert(not tail.reinforcing and not tail.marchPath,phase.." left a straggler on the road")
   local x,z=if phase=="Holding" then tail.holdX else tail.homeX,if phase=="Holding" then tail.holdZ else tail.homeZ
   assert((tail.x-x)^2+(tail.z-z)^2<=4,phase.." did not finish movement")
  end
  return "Both handoffs finish the late bird's movement"
 end)
 return results
end
return Checks
