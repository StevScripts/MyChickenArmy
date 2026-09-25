-- Focused cash-pad checks with fake sessions; no saved balances or purchases.
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
 local session=Session.new(123,"ContactFixture",1)
 local now=0
 local center=pad.Position+Vector3.new(0,3,0)
 local function step(position,dt,grounded)
  now+=dt
  service:ProcessAndClaim(session,position,dt,now,grounded~=false)
 end
 return service,session,center,step
end
local service,session,center,step=fixture()
local initial=session.coins
session.eggProcessor.readyValue=100
step(center,0.1)
check("entry pays ready cash without movement",session.coins==initial+100 and session.eggProcessor.readyValue==0)
session.eggProcessor.readyValue=20
for _=1,9 do step(center,0.1) end
check("stationary claim respects one-second cooldown",session.coins==initial+100 and session.eggProcessor.readyValue==20)
step(center,0.1)
check("remaining on pad pays new cash after one second",session.coins==initial+120 and session.eggProcessor.readyValue==0)
for _=1,20 do step(center,0.1) end
check("empty balance cannot pay twice",session.coins==initial+120 and service:Yard(session).cashSerial==2)
session.eggProcessor.readyValue=30
step(center+Vector3.new(20,0,0),0.1)
check("outside pad does not collect",session.eggProcessor.readyValue==30)
step(center,0.1,false)
check("airborne over pad does not collect",session.eggProcessor.readyValue==30)
step(nil,0.1)
check("missing character does not collect",session.eggProcessor.readyValue==30)
session.plotIndex=2
step(center,0.1)
check("another plot cannot collect",session.eggProcessor.readyValue==30)
session.plotIndex=1
step(center,0.1)
check("returning onto owned pad collects",session.coins==initial+150 and session.eggProcessor.readyValue==0)
session.eggProcessor.readyValue=10
step(center+Vector3.new(20,0,0),0.1);step(center,0.1)
check("re-entry cannot bypass cooldown",session.eggProcessor.readyValue==10)
for _=1,8 do step(center,0.1) end
check("cooldown expires while still standing",session.coins==initial+160)

local _,s,c,tick=fixture()
local off=c+Vector3.new(20,0,0)
Processor.Deposit(s.eggProcessor,10,100)
for _=1,9 do tick(off,0.1) end
check("processing waits for whole second",Processor.Totals(s.eggProcessor)==10 and s.eggProcessor.readyValue==0)
tick(off,0.1)
check("whole-second processing uses current rate",Processor.Totals(s.eggProcessor)==8 and s.eggProcessor.readyValue==20)
s.eggProcessor.level=1
for _=1,10 do tick(off,0.1) end
check("upgraded rate is preserved",Processor.Totals(s.eggProcessor)==4 and s.eggProcessor.readyValue==60)
s.entitlements.DoubleEggSpawn=true
for _=1,10 do tick(off,0.1) end
check("final batch preserves value",Processor.Totals(s.eggProcessor)==0 and s.eggProcessor.readyValue==100)
s.entitlements.DoubleCash=true
local before=s.coins
tick(c,0.1)
check("cash multiplier applied exactly once",s.coins==before+200 and s.eggProcessor.readyValue==0)
tick(off,10)
Processor.Deposit(s.eggProcessor,10,100)
tick(off,0.1)
check("idle time not banked for processing",Processor.Totals(s.eggProcessor)==10)
check("saved queue still valid",Processor.Read(Processor.Copy(s.eggProcessor))~=nil)
local _,lagged,at,lagTick=fixture()
Processor.Deposit(lagged.eggProcessor,10,101)
lagTick(at+Vector3.new(20,0,0),2.6)
local count,value=Processor.Totals(lagged.eggProcessor)
check("slow frame conserves queue value",count==6 and value+lagged.eggProcessor.readyValue==101)
return passed
