-- Real modules, isolated encounters; no players, remotes or DataStore.
local cache={}
local function fresh(module)
 if cache[module]~=nil then return cache[module] end
 local chunk=assert(loadstring(module.Source,"="..module:GetFullName()))
 setfenv(chunk,setmetatable({script=module,require=fresh},{__index=getfenv()}))
 local result=chunk();cache[module]=result;return result
end
local Battle=fresh(game.ServerStorage.PetRoll.Battle)
local Config=fresh(game.ReplicatedStorage.PetRoll.Shared.Config)
local March=fresh(game.ReplicatedStorage.PetRoll.Shared.ArmyMarch)
local function encounter(distance,target)
 local b=Battle.new("approach-fixture",-106,target or "camp:1",Vector3.new(0,1,100),Vector3.new(0,1,0),0)
 b:AddArmy("A",{{id="front",species="Duck",stars=1,level=1}},b.origin)
 b:AddArmy("B",{{species="Duck",stars=1,level=1}},b.destination)
 local a,guard=b.units[1],b.units[2]
 a.x,a.z,guard.x,guard.z=0,distance,0,0
 return b,a,guard
end
local results={}
local function test(name,fn)
 local ok,why=pcall(fn)
 table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
end
test("guards walk toward nearby troops before melee contact",function()
 local b,a,guard=encounter(16)
 assert(b:StepSimulation(.1,.1)==nil and b.phase=="Fight")
 assert(guard.z>0 and a.z<16 and guard.targetId==a.id)
 assert(a.hp==a.maxHp and guard.hp==guard.maxHp,"Detection must not deal distant damage")
 assert(b.captureElapsed==0,"Detection must not grant remote capture")
end)
test("live actor movement receives a defender chase command",function()
 local b,a,guard=encounter(16);local moved={}
 b.actors={Move=function(_,u,x,z,speed) moved[u.id]={x=x,z=z,speed=speed} end,Stop=function() end,Face=function() end}
 b:StepSimulation(.1,.1)
 assert(moved[guard.id] and moved[guard.id].z>guard.z and moved[guard.id].speed==Config.MoveSpeed)
end)
test("distant troops do not pull the defenders out of their base",function()
 local b,_,guard=encounter(30)
 b:StepSimulation(.1,.1)
 assert(b.phase=="Travel" and guard.z==0 and not guard.targetId)
end)
test("exit and road waypoints still finish before engagement",function()
 local b,a,guard=encounter(16)
 March.Set(a,{Vector3.new(0,1,16),Vector3.new(0,1,50)},0)
 b:StepSimulation(.1,.1)
 assert(b.phase=="Travel" and a.marchPath and guard.z==0)
end)
test("a nearby front bird does not activate distant stragglers",function()
 local b,a=encounter(16)
 b:AddArmy("A",{{id="tail",species="Duck",stars=1,level=1}},Vector3.new(0,1,100))
 local tail=b.units[3]
 b:StepSimulation(.1,.1)
 assert(b.phase=="Fight" and not a.reinforcing and tail.reinforcing)
 a.hp=0;a.respawnAt=100
 assert(b:StepSimulation(.1,.2)=="B","A road straggler must not rescue a wiped frontline")
end)
test("dead and returning defenders do not trigger detection",function()
 for _,kind in {"dead","retiring","reinforcing"} do
  local b,a,guard=encounter(16)
  if kind=="dead" then guard.hp=0 else guard[kind]=true end
  assert(not b:ReachedCamp(a),kind)
 end
end)
test("income and Operations retain their existing contact boundary",function()
 local income,a=encounter(16,"income:1");income.incomeSite=true
 assert(not income:ReachedCamp(a))
 local operation,o=encounter(16);operation.operationId="fixture"
 assert(not operation:ReachedCamp(o))
 for _,target in {"camp:1","outpost:1","king:1"} do
  local b,t=encounter(16,target);assert(b:ReachedCamp(t))
 end
end)
test("nearby reinforcement joins the fight but cannot capture from outside",function()
 local b,a,guard=encounter(16);b.phase="Fight";a.reinforcing=true
 b:AddArmy("A",{{id="active-front",species="Duck",stars=1,level=1}},Vector3.new(1,1,16))
 b.units[3].x,b.units[3].z=1,16
 b:StepSimulation(.1,.1)
 assert(not a.reinforcing and guard.z>0 and b.captureElapsed==0)
 a.x,a.z=0,0;b:StepConquest(.1);assert(b.captureElapsed==.1)
end)
return results
