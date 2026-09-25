-- Historical movement-only behavior, superseded by contact-checks.luau on September 25.
-- Do not use this fixture to validate the current standing/entry collection contract.
-- Focused Edit checks: fake sessions only; no Play, purchases or profile writes.
assert(not game:GetService("RunService"):IsRunning())
local loaded={}
local function fresh(module)
	if loaded[module] then return loaded[module] end
	local run=assert(loadstring(module.Source,module.Name))
	setfenv(run,setmetatable({script=module,require=fresh},{__index=getfenv()}))
	local result=run();loaded[module]=result;return result
end
local root=game.ServerStorage.PetRoll
local Session=fresh(root.PlayerSession)
local Eggs=fresh(root.EggService)
local Processor=fresh(root.EggProcessor)
local authored=workspace.MyChickenArmyMap["03_HomePlots"]
local pad=authored.EggCollectionBoard.CollectionPart.TouchPart
local world={root=authored,plots={}}
function world:EggDeposit() return nil,nil end
local passed={}
local function check(name,condition) assert(condition,name);table.insert(passed,name) end
local function fixture()
	local service=Eggs.new(world)
	local session=Session.new(123,"MovementFixture",1)
	local now=0
	local center=pad.Position+Vector3.new(0,3,0)
	local function step(position,dt,grounded)
		now+=dt
		service:ProcessAndClaim(session,position,dt,now,grounded~=false)
	end
	local function walk(count)
		for i=1,count do step(center+Vector3.new(if i%2==1 then 0.2 else -0.2,0,0),0.1) end
	end
	return service,session,center,step,walk
end

local service,session,center,step,walk=fixture()
local initial=session.coins
session.eggProcessor.readyValue=100
for _=1,30 do step(center,0.1) end
check("standing/entry never collects",session.coins==initial and session.eggProcessor.readyValue==100)
walk(9)
check("movement under one second does not pay",session.coins==initial)
step(center+Vector3.new(-0.2,0,0),0.1)
check("one second of movement collects current balance",session.coins==initial+100 and session.eggProcessor.readyValue==0)
session.eggProcessor.readyValue=20
walk(10)
check("continued movement collects again after one second",session.coins==initial+120)
session.eggProcessor.readyValue=30
for _=1,20 do step(center+Vector3.new(-0.2,0,0),0.1) end
check("stopping keeps ready cash",session.coins==initial+120 and session.eggProcessor.readyValue==30)
walk(4)
step(center+Vector3.new(-0.2,0,0),0.1)
walk(9)
check("stop resets movement timer",session.coins==initial+120)
step(center+Vector3.new(-0.2,0,0),0.1)
check("movement resumes collection after a full second",session.coins==initial+150)
session.eggProcessor.readyValue=10
step(center,0.1,false)
for i=1,20 do step(center+Vector3.new(if i%2==1 then 0.2 else -0.2,0,0),0.1,false) end
check("airborne movement does not collect",session.eggProcessor.readyValue==10)
step(center,0.1)
for i=1,20 do step(center+Vector3.new(0,if i%2==1 then 0.18 else 0,0),0.1) end
check("vertical pad movement does not collect",session.eggProcessor.readyValue==10)
for i=1,20 do step(center+Vector3.new(100+i,0,0),0.1) end
check("off-pad movement does not collect",session.eggProcessor.readyValue==10)
session.plotIndex=2
walk(20)
check("another plot cannot use this collector",session.eggProcessor.readyValue==10)

local _,s,c,tick=fixture()
Processor.Deposit(s.eggProcessor,10,100)
for _=1,9 do tick(c,0.1) end
check("no fractional-second queue/value changes",Processor.Totals(s.eggProcessor)==10 and s.eggProcessor.readyValue==0)
tick(c,0.1)
check("one-second tick subtracts current rate",Processor.Totals(s.eggProcessor)==8 and s.eggProcessor.readyValue==20)
s.eggProcessor.level=1
for _=1,10 do tick(c,0.1) end
check("next second uses upgraded rate",Processor.Totals(s.eggProcessor)==4 and s.eggProcessor.readyValue==60)
s.entitlements.DoubleEggSpawn=true
for _=1,10 do tick(c,0.1) end
check("partial final tick preserves value and never goes negative",Processor.Totals(s.eggProcessor)==0 and s.eggProcessor.readyValue==100)
tick(c,10)
Processor.Deposit(s.eggProcessor,10,100)
tick(c,0.1)
check("idle seconds do not instantly process new deposits",Processor.Totals(s.eggProcessor)==10 and s.eggProcessor.readyValue==100)
check("saved queue remains valid",Processor.Read(Processor.Copy(s.eggProcessor))~=nil)

local _,lagged,at,lagTick=fixture()
Processor.Deposit(lagged.eggProcessor,10,101)
lagTick(at,2.6)
local count,value=Processor.Totals(lagged.eggProcessor)
check("delayed frame processes whole seconds without losing value",count==6 and value+lagged.eggProcessor.readyValue==101)
lagTick(at,0.4)
check("remaining elapsed time carries to next whole second",Processor.Totals(lagged.eggProcessor)==4)
return passed
