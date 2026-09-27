-- Isolated Edit checks. Caller supplies exact local source strings by src path.
-- Uses fake sessions/worlds only. No DataStore, players, checkout or Play state.
return function(sources)
 local cache={}
 local function folder(name)
  return setmetatable({Name=name},{__index=function(self,key)
   local node={Name=key,Parent=self,path="src/"..name.."/"..key..".luau"}
   rawset(self,key,node);return node
  end})
 end
 local shared,server=folder("shared"),folder("server")
 local services={ReplicatedStorage={PetRoll={Shared=shared}},HttpService=game:GetService("HttpService"),
  Players={GetPlayerByUserId=function() return nil end},RunService={IsStudio=function() return true end}}
 local original=getfenv()
 local loadModule
 loadModule=function(node)
  if cache[node.path] then return cache[node.path] end
  local fn,err=loadstring(assert(sources[node.path],node.path),node.path);assert(fn,err)
  setfenv(fn,setmetatable({script=node,require=loadModule,game={GetService=function(_,name)
   return assert(services[name],"Unexpected service "..name)
  end}},{__index=original}))
  local result=fn();cache[node.path]=result;return result
 end
 local Config=loadModule(shared.Config)
 local Catalog=loadModule(shared.PetCatalog)
 local Rules=loadModule(shared.Rules)
 local SellerConfig=loadModule(shared.EggProcessorConfig)
 local OfflineConfig=loadModule(shared.OfflineCashConfig)
 local Session=loadModule(server.PlayerSession)
 local Eggs=loadModule(server.EggService)
 local Processor=loadModule(server.EggProcessor)
 local Offline=loadModule(server.OfflineCash)
 local Army=loadModule(server.ArmyService)
 local Upgrades=loadModule(server.UpgradeService)
 local results={}
 local function check(name,fn)
  local ok,err=pcall(fn);table.insert(results,{name=name,passed=ok,error=if ok then nil else tostring(err)})
 end
 local function close(a,b)
  assert(math.abs(a-b)<1e-6,tostring(a).." ~= "..tostring(b))
 end
 local function fresh(species,level)
  local s=Session.new(700,"Egg quantity check",1)
  s.loaded=true;s.pets={};s.slots={};s.awayPets={}
  if species then local p=s:AddPet(species,1);p.level=level or 1 end
  return s
 end
 local function engine()
  return Eggs.new({PetPosition=function() return Vector3.zero end,
   PlotFrame=function() return CFrame.new() end,ReturnPosition=function() return Vector3.zero end,
   EggDeposit=function() return nil end,plots={{}}})
 end
 local function total(e,s)
  local count,value=0,0
  local y=e:Yard(s)
  for _,d in y.drops do count+=d.stack;value+=d.value end
  for _,l in y.layers do count+=l.count;value+=l.value end
  return count,value
 end
 check("All 32 species and 10 levels retain cash potential at all five egg values",function()
  assert(#Catalog.Order==32)
  for _,id in Catalog.Order do for level=1,10 do for upgrade=0,4 do
   local old=math.floor(Catalog[id].income*Config.PassiveIncomeMultiplier*(1+upgrade*0.25)+0.5)*2^(level-1)
   close(Rules.Income(id,1,level,upgrade),old)
   close(Rules.Income(id,1,level,upgrade)/Rules.EggRate(id,1,level),4+upgrade)
  end end end
  close(Rules.EggRate("Duck",1,1),1);close(Rules.EggRate("StormDuck",1,2),240)
 end)
 check("Production counts whole eggs and gives every species the same unit value",function()
  for _,id in Catalog.Order do
   local s=fresh(id);s.incomeLevel=3
   local e=engine()
   for i=1,100 do e:Produce(s,0.1,i/10) end
   local count,value=total(e,s)
   close(count,Rules.EggRate(id,1,1)*10);close(value,count*7)
   for _,d in e:Yard(s).drops do assert(d.stack>=1 and d.stack%1==0);close(d.value,d.stack*7) end
  end
 end)
 check("Slow frames catch up in one batch without per-egg work",function()
  local s=fresh("StormDuck",2);local e=engine()
  e:Produce(s,37.25,37.25)
  local count,value=total(e,s);close(count,240*37.25);close(value,count*4)
  assert(#e:Yard(s).drops==1)
 end)
 check("60 maximum-level birds retain exact millions of eggs with at most 80 visuals",function()
  local s=fresh();s.eggSpeedLevel=4;s.incomeLevel=4;s.entitlements.DoubleEggSpawn=true
  for _=1,60 do local p=s:AddPet("StormDuck",1);p.level=10 end
  local e=engine()
  for i=1,100 do e:Produce(s,0.1,i/10) end
  local count,value=total(e,s)
  close(count,60*120*512*3.2*10);close(value,count*8)
  assert(#e:Yard(s).drops<=80)
 end)
 check("Away time creates no eggs; fractional progress and speed changes are retained",function()
  local s=fresh("Duck");local id=next(s.pets);local e=engine()
  e:Produce(s,0.5,0.5);s.awayPets[id]=true;e:Produce(s,100,100.5)
  close(total(e,s),0);s.awayPets[id]=nil;s.entitlements.DoubleEggSpawn=true
  e:Produce(s,0.25,100.75);close(total(e,s),1)
  s.entitlements.DoubleEggSpawn=nil;e:Produce(s,0.5,101.25);close(total(e,s),1)
  e:Produce(s,0.5,101.75);close(total(e,s),2)
 end)
 check("Value upgrades affect only new eggs; Double Cash never changes egg counts",function()
  local s=fresh("Duck");local e=engine();e:Produce(s,1,1)
  s.incomeLevel=1;s.entitlements.DoubleCash=true;e:Produce(s,1,2)
  local count,value=total(e,s);close(count,2);close(value,9)
  local snap=e:Snapshot(s,2);close(snap.count,2);close(snap.value,18)
 end)
 check("Full in-flight yard retains production without changing claimed stacks",function()
  local s=fresh("StormDuck");local e=engine();local y=e:Yard(s)
  for i=1,80 do table.insert(y.drops,{petId="other",stack=1,value=4,claimAt=1}) end
  e:Produce(s,1,1);local id=next(s.pets);close(y.layers[id].count,120)
  table.remove(y.drops);e:Produce(s,0.25,1.25)
  close(y.drops[#y.drops].stack,150);close(y.layers[id].count,0)
  for i=1,79 do close(y.drops[i].stack,1) end
 end)
 check("Manual and vacuum pickup each transfer exact stack count/value once",function()
  for _,collector in {"player","rover"} do
   local s=fresh("StormDuck");local e=engine();local pad=Instance.new("Part")
   e.world.EggDeposit=function() return pad,s.userId end
   e:Produce(s,1,1);local y=e:Yard(s);local d=y.drops[1]
   if collector=="rover" then y.rover={enabled=true,pendingCount=0,cargoCount=0,cargoValue=0,suctionSerial=0} end
   assert(e:Claim(y,d,2,collector,Vector3.zero));assert(not e:Claim(y,d,2,collector,Vector3.zero))
   e:Pay(s,y,d,3);e:Pay(s,y,d,3)
   local bag=if collector=="rover" then {count=y.rover.cargoCount,value=y.rover.cargoValue} else s.eggCarry
   close(bag.count,120);close(bag.value,480);assert(#y.receipts==1 and y.receipts[1].count==120)
   pad:Destroy()
  end
 end)
 check("Seller conserves quantity/value through mixed old/new batches, compaction and Finish",function()
  local p=Processor.New();assert(Processor.Deposit(p,1,960)) -- old high-value egg
  for _=1,100 do assert(Processor.Deposit(p,240,240*5)) end
  assert(#p.batches<=64)
  local beforeCount,beforeValue=Processor.Totals(p)
  Processor.Step(p,1,16)
  local count,value=Processor.Totals(p);close(beforeCount-count,16);close(value+p.readyValue,beforeValue)
  assert(Processor.GrantFinish(p));close(p.readyValue,beforeValue);close(Processor.Totals(p),0)
  assert(Processor.GrantFinish(p));assert(p.finishCredits==1)
  assert(Processor.Deposit(p,7,35));close(p.readyValue,beforeValue+35);assert(p.finishCredits==0)
 end)
 check("Cash claim applies Double Cash once and cannot replay an emptied balance",function()
  local s=fresh();s.entitlements.DoubleCash=true;s.eggProcessor.readyValue=400
  local e=engine();local pad=Instance.new("Part");local before=s.coins
  assert(e:ClaimReady(s,pad,1));assert(not e:ClaimReady(s,pad,2));close(s.coins-before,800)
  close(s.eggProcessor.readyValue,0);pad:Destroy()
 end)
 check("Existing bags, seller batches, cash and paid credits roundtrip without repricing",function()
  local s=fresh("StormDuck",2);s.incomeLevel=4
  s.eggCarry={count=3,value=999};s.eggProcessor.readyValue=123
  assert(Processor.Deposit(s.eggProcessor,7,777));s.eggProcessor.finishCredits=2
  s.purchaseReceipts={priorReceipt=3714566216}
  local data=s:ToData();local restored=fresh();local ok,err=restored:LoadData(data);assert(ok,err)
  close(restored.eggCarry.count,3);close(restored.eggCarry.value,999)
  local count,value=Processor.Totals(restored.eggProcessor);close(count,7);close(value,777)
  close(restored.eggProcessor.readyValue,123);close(restored.eggProcessor.finishCredits,2)
  assert(restored.purchaseReceipts.priorReceipt==3714566216)
 end)
 check("Offline rate uses real species/level production and seller capacity exactly once",function()
  for _,species in {"Duck","StormDuck"} do for level=0,4 do
   local s=fresh(species,2);s.incomeLevel=3;s.eggSpeedLevel=4;s.eggProcessor.level=level
   s.entitlements.DoubleCash=true;s.entitlements.DoubleEggSpawn=true
   local expected=math.min(Rules.EggRate(species,1,2)*3.2,SellerConfig.Rates[level+1]*2)*7*2*OfflineConfig.Efficiency
   close(Offline.Rate(s),expected)
  end end
  close(Offline.Rate(fresh()),0)
 end)
 check("Snapshot rates and merge preview use quantity while retaining 3-to-1 level tradeoff",function()
  local s=fresh();s.eggSpeedLevel=1;s.incomeLevel=4;s.entitlements.DoubleCash=true
  for _=1,3 do s:AddPet("StormDuck",1) end
  local snap=s:Snapshot(0);close(snap.eggUnitValue,8);close(snap.homeEggsPerSecond,414)
  for _,p in snap.pets do close(p.eggsPerSecond,138);close(p.income,138*8*2) end
  local recipe=Army.MergeOptions(s)[1];assert(recipe)
  close(recipe.inputEggRate,138);close(recipe.afterEggRate,276)
  local ok,err=Army.Merge(s,recipe.firstId,recipe.secondId,recipe.thirdId,1);assert(ok,err)
  close(s:Count(),1);close(s:Snapshot(0).homeEggsPerSecond,276)
 end)
 check("Upgrade previews show one shared unit value and speed multiplier without camp gates",function()
  local s=fresh("Duck");s.entitlements.DoubleCash=true;s.entitlements.DoubleEggSpawn=true
  local board=Upgrades.new({},{});local offers=board:Offers(s)
  assert(offers.EggValue.currentText=="$4" and offers.EggValue.nextText=="$5")
  assert(offers.EggSpeed.currentText=="2x" and offers.EggSpeed.nextText=="2.3x")
  assert(offers.EggValue.unlocked and offers.EggSpeed.unlocked and s.promotion==1)
  assert(#SellerConfig.Rates==5 and #SellerConfig.Prices==4)
  for i,price in {480,2400,9600,28800} do close(SellerConfig.Prices[i],price) end
 end)
 local passed=0;for _,r in results do if r.passed then passed+=1 end end
 return {passed=passed,total=#results,results=results}
end
