-- Isolated Edit checks: fresh source environments, fake sessions/services, no Play or DataStore.
local server=game.ServerStorage.PetRoll
local shared=game.ReplicatedStorage.PetRoll.Shared
local client=game.StarterPlayer.StarterPlayerScripts.PetRoll
local original=getfenv()
local function loader(enabled,overrides)
 local cache={}
 local loadModule
 loadModule=function(node)
  if overrides and overrides[node.Name] then return overrides[node.Name] end
  if cache[node] then return cache[node] end
  local source=node.Source
  if node==shared.EggProcessorConfig and enabled then source=source:gsub('Enabled = false','Enabled = true') end
  local fn,err=loadstring(source,node:GetFullName());assert(fn,err)
  setfenv(fn,setmetatable({script=node,require=loadModule,game={GetService=function(_,name)
   if name=='Players' then return {GetPlayerByUserId=function() return nil end} end
   return game:GetService(name)
  end}},{__index=original}))
  local result=fn();cache[node]=result;return result
 end
 return loadModule
end
local loadModule=loader(false)
local Session=loadModule(server.PlayerSession)
local Eggs=loadModule(server.EggService)
local Processor=loadModule(server.EggProcessor)
local Offline=loadModule(server.OfflineCash)
local Tuning=loadModule(shared.OfflineCashConfig)
local Currency=loadModule(shared.CurrencyLimits)
local Catalog=loadModule(shared.ShopCatalog)
local Rules=loadModule(shared.Rules)
local results={}
local cleanup={}
local function check(name,fn)
 local ok,err=pcall(fn)
 table.insert(results,{name=name,passed=ok,error=if ok then nil else tostring(err)})
end
local function fresh()
 local s=Session.new(700,'Instant sale check',1);s.loaded=true;s.pets={};s.slots={};s.awayPets={};s.coins=0
 return s
end
local function engine(s,owner)
 local pad=Instance.new('Part');pad.Size=Vector3.new(8,1,8);pad.CFrame=CFrame.new(20,0,30);table.insert(cleanup,pad)
 local world={EggDeposit=function() return pad,owner or s.userId end,plots={{}},PlotFrame=function() return CFrame.new() end}
 return Eggs.new(world),pad
end
check('All six plots pay exact earned bag value immediately, once, including Double Cash',function()
 for i=1,6 do for _,double in {false,true} do
  local s=fresh();s.plotIndex=i;s.entitlements.DoubleCash=double;s.eggCarry={count=3,value=973}
  local e,pad=engine(s)
  local ok,credited=e:Deposit(s,pad.Position,1);assert(ok and credited==973*(if double then 2 else 1))
  assert(s.coins==credited and s.eggCarry.count==0 and s.eggCarry.value==0 and #s.eggProcessor.batches==0)
  assert(s.eggProcessor.readyValue==0 and s.tutorial.soldEggs and not e:Deposit(s,pad.Position,1))
  local snap=e:Snapshot(s,1);assert(not snap.processor.enabled and snap.processor.upgradePrice==nil)
  assert(snap.deposit.value==credited and not snap.deposit.queued and #snap.deposits==1)
 end end
end)
check('Ownership, proximity, loading/closing/save-loss and wallet headroom preserve unpaid bags',function()
 local s=fresh();s.eggCarry={count=10,value=40};local e,pad=engine(s,999)
 assert(not e:Deposit(s,pad.Position,1));e.world.EggDeposit=function() return pad,s.userId end
 assert(not e:Deposit(s,pad.Position+Vector3.new(100,0,0),1))
 s.loaded=false;assert(not e:Deposit(s,pad.Position,1));s.loaded=true
 s.closing=true;assert(not e:Deposit(s,pad.Position,1));s.closing=false
 s.saveLost=true;assert(not e:Deposit(s,pad.Position,1));s.saveLost=false
 s.entitlements.DoubleCash=true;s.coins=Currency.MaxCoins-79
 assert(not e:Deposit(s,pad.Position,1) and s.eggCarry.value==40 and s.eggCarry.count==10)
 s.coins-=1;assert(e:Deposit(s,pad.Position,2));assert(s.coins==Currency.MaxCoins)
end)
check('Vacuum unload pays immediately, clears once, and preserves cargo at wallet limit',function()
 local s=fresh();s.entitlements.AutoCollectEggs=true;s.entitlements.DoubleCash=true
 local e,pad=engine(s);local y=e:Yard(s)
 local rover={enabled=true,state='Unload',position=pad.Position,cargoCount=7,cargoValue=35,pendingCount=0,
  Step=function() end,Nozzle=function() return pad.Position end,ReadyToUnload=function() return true end,
  FinishUnload=function(self) self.finishes=(self.finishes or 0)+1 end}
 y.rover=rover;e:UpdateRover(s,y,0.05,1);assert(s.coins==70 and rover.cargoValue==0 and rover.cargoCount==0)
 e:UpdateRover(s,y,0.05,1.1);assert(s.coins==70 and #y.deposits==1 and y.deposit.collector=='rover')
 rover.cargoCount=7;rover.cargoValue=35;s.coins=Currency.MaxCoins-69
 e:UpdateRover(s,y,0.05,2);assert(rover.cargoValue==35 and rover.cargoCount==7)
end)
check('Saved queued and ready value settles at deposit pad without delay or movement; levels/credits survive',function()
 local s=fresh();s.entitlements.DoubleCash=true;s.eggProcessor.level=12;s.eggProcessor.finishCredits=4
 s.eggProcessor.batches={{count=2,value=961},{count=7,value=35}};s.eggProcessor.readyValue=13
 local e,pad=engine(s)
 e:ProcessAndClaim(s,pad.Position,0,1,false,Vector3.zero)
 assert(s.coins==2018 and s.eggProcessor.readyValue==0 and #s.eggProcessor.batches==0)
 assert(s.eggProcessor.level==12 and s.eggProcessor.finishCredits==4)
 e:ProcessAndClaim(s,pad.Position,0,1,false,Vector3.zero);assert(s.coins==2018)
 local saved=Processor.Read(Processor.Copy(s.eggProcessor));assert(saved.level==12 and saved.finishCredits==4)
end)
check('Saved balances are retained when owner is away or wallet is full',function()
 local s=fresh();s.eggProcessor.batches={{count=3,value=103}};s.eggProcessor.readyValue=7
 local e,pad=engine(s)
 e:ProcessAndClaim(s,nil,100,1,false,nil);assert(s.coins==0 and s.eggProcessor.readyValue==110)
 s.coins=Currency.MaxCoins-109;e:ProcessAndClaim(s,pad.Position,0,2,false,nil)
 assert(s.eggProcessor.readyValue==110);s.coins-=1;e:ProcessAndClaim(s,pad.Position,0,2,false,nil)
 assert(s.coins==Currency.MaxCoins and s.eggProcessor.readyValue==0)
end)
check('Seller upgrades and Finish Now checkout are disabled; receipt handler still recognizes paid product',function()
 local s=fresh();local e=engine(s)
 assert(not e:Upgrade({},s,0,40) and not e:CanUseBoard({},s))
 assert(Catalog.Products.FinishEggs.enabled==false)
 local Commerce=loadModule(server.CommerceService)
 local commerce=setmetatable({catalog=Catalog,records={}},{__index=Commerce})
 assert(not commerce:PreparePurchase({UserId=s.userId},s,'FinishEggs',true))
 local Products=loadModule(server.ProductService)
 local products=Products.new({},{});assert(products.products[3714566216].finishEggs)
 assert(Processor.GrantFinish(s.eggProcessor) and s.eggProcessor.finishCredits==1)
 local e2=engine(s);assert(e2:AcceptDeposit(s,2,8));assert(s.eggProcessor.finishCredits==1)
end)
check('Offline rate no longer depends on seller level; old checkpoint pays its recorded rate',function()
 local s=fresh();s:AddPet('StormDuck',1);s.incomeLevel=4;s.entitlements.DoubleCash=true;s.entitlements.DoubleEggSpawn=true
 local expected=Rules.EggRate('StormDuck',1,1)*s:EggProductionMultiplier()*Rules.EggUnitValue(4)*2*Tuning.Efficiency
 assert(math.abs(Offline.Rate(s)-expected)<1e-6)
 s.eggProcessor.level=20;assert(math.abs(Offline.Rate(s)-expected)<1e-6)
 assert(Offline.Reward({at=100,rate=3},200,0).amount==300)
end)
check('Player and vacuum receipt history survives snapshot batching without duplicate effects',function()
 local s=fresh();local e,pad=engine(s);local y=e:Yard(s)
 e:RecordDeposit(y,3,12,1,'rover',pad.Position,false)
 e:RecordDeposit(y,4,16,1,'player',pad.Position,false)
 local snap=e:Snapshot(s,1);assert(#snap.deposits==2)
 local ClientEggs=loader(false,{UITheme={},EggView={},EggFeedback={},VacuumController={}})(client.EggController)
 local values,roverEvents,resets=0,0,0
 local c=ClientEggs.new({feedback={ResetCollections=function() resets+=1 end,Deposit=function(_,r) values+=r.value end}})
 c.folder={};c.HidePopup=function() end
 c.vacuum={Receive=function() end,Clear=function() end,Deposit=function() roverEvents+=1 end}
 c:Receive(snap);c:Receive(snap);assert(values==28 and roverEvents==1 and resets==1)
 local empty=e:Snapshot(s,5);assert(#empty.deposits==0);c:Receive(empty);assert(values==28)
end)
check('Archived board controller starts no listeners or checkout loads',function()
 local Controller=loader(false,{UITheme={}})(client.EggProcessorController)
 local c=Controller.new({});c:Start();assert(#c.connections==0 and next(c.views)==nil);c:Destroy()
end)
check('Paid deposit routes to Money effect; queued legacy display remains available for restoration',function()
 local Feedback=loader(false,{UITheme={Money=tostring,Colors={gold=Color3.new(1,1,0)},Arcade={green=Color3.new(0,1,0)}}})(client.ActionFeedback)
 local root=Instance.new('Part');table.insert(cleanup,root)
 local money,bursts=0,0
 local f=setmetatable({alive=true,app={audio={Play=function() end},Notify=function() end},Root=function() return root end,
  DepositBurst=function() bursts+=1 end,ShowCash=function(_,_,value) money+=value end},{__index=Feedback})
 f:ShowDeposit({count=3,value=12,queued=false});assert(money==12 and bursts==1)
 f:ShowDeposit({count=3,value=0,queued=true});assert(money==12 and bursts==2)
end)
check('Enable switch restores timed queue, seller offer, Finish Now availability and offline cap',function()
 local enabled=loader(true);local S=enabled(server.PlayerSession);local E=enabled(server.EggService)
 local s=S.new(701,'Restore check',1);s.loaded=true
 local e=E.new({plots={{}},EggDeposit=function() return nil end})
 local coins=s.coins;local accepted,value,queued=e:AcceptDeposit(s,10,40)
 assert(accepted and queued and value==0 and s.coins==coins and #s.eggProcessor.batches==1)
 assert(enabled(shared.ShopCatalog).Products.FinishEggs.enabled)
 assert(e:Snapshot(s,1).processor.enabled and e:Snapshot(s,1).processor.upgradePrice==40)
 e:ProcessAndClaim(s,nil,1,2,false,nil)
 assert(s.eggProcessor.batches[1].count==6 and s.eggProcessor.readyValue==16)
 s.pets={};s:AddPet('StormDuck',1);s.incomeLevel=0
 assert(enabled(server.OfflineCash).Rate(s)==4*4*Tuning.Efficiency)
end)
for _,o in cleanup do o:Destroy() end
return results
