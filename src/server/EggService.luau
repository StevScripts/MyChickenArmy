--!strict
-- Server-owned pickup ledger. Authored plots carry eggs until their sell pad is reached.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local VacuumConfig=require(Shared.VacuumConfig)
local Layout=require(Shared.HomePlotLayout)
local ShopCatalog=require(Shared.ShopCatalog)
local EggRover=require(script.Parent.EggRover)
local Processor=require(script.Parent.EggProcessor)
local ProcessorConfig=require(Shared.EggProcessorConfig)
local Currency=require(Shared.CurrencyLimits)
local EggService={}
EggService.__index=EggService
local CASH_COLLECT_SECONDS=1
local CASH_MIN_HORIZONTAL_SPEED=0.5 -- Ignore standing jitter and vertical pad travel.

local function onCashPad(pad,position)
 if not position or not pad or not pad:IsA("BasePart") then return false end
 local at=pad.CFrame:PointToObjectSpace(position)
 return math.abs(at.X)<=pad.Size.X/2+0.7 and math.abs(at.Z)<=pad.Size.Z/2+0.7
  and at.Y>=-1 and at.Y<=pad.Size.Y/2+5
end

function EggService.new(world)
 return setmetatable({world=world,yards={},serial=0,generation=0},EggService)
end

function EggService:Board(session)
 local root=self.world.root
 if not root then return nil end
 local board=root:FindFirstChild("EggCollectionBoard")
 if board and board:GetAttribute("PlotIndex")==session.plotIndex then return board end
 local plot=self.world.plots[session.plotIndex]
 return plot and plot.folder:FindFirstChild("EggCollectionBoard",true)
end

function EggService:CanUseBoard(player,session)
 if not ProcessorConfig.Enabled then return false end
 local board=self:Board(session)
 local screen=board and board:FindFirstChild("Screen")
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if not screen or not screen:IsA("BasePart") or not root or not humanoid or humanoid.Health<=0 then return false end
 return (root.Position-screen.Position).Magnitude<=ProcessorConfig.BoardDistance
end

function EggService:Upgrade(player,session,level,price)
 if not ProcessorConfig.Enabled then return false,"Eggs now sell instantly." end
 if not self:CanUseBoard(player,session) then return false,"Walk up to your egg selling board." end
 local state=session.eggProcessor
 if not ProcessorConfig.ValidLevel(state.level+1) then return false,"Invalid selling upgrade level." end
 local cost=ProcessorConfig.Price(state.level)
 if not cost then return false,"This price exceeds the supported currency range." end
 if level~=state.level or price~=cost then return false,"The upgrade changed. Try again." end
 if session.coins<cost then return false,"Not enough cash for this upgrade." end
 session.coins-=cost;state.level+=1;session:Touch()
 return true,"Eggs sell at "..Processor.Rate(state,session.entitlements.DoubleEggSpawn).." eggs/sec."
end

function EggService:AcceptDeposit(session,count,value)
 if not ProcessorConfig.Enabled then
  if count<1 or value<1 or not session:CanCredit(value,"eggs") then return false end
  return true,session:Credit(value,"eggs"),false
 end
 if not Processor.Deposit(session.eggProcessor,count,value) then return false end
 session:Touch()
 -- Every plot uses the same saved queue; deposits never bypass processing.
 return true,0,true
end

function EggService:ProcessAndClaim(session,position,dt,now,grounded,velocity)
 local state=session.eggProcessor
 local yard=self:Yard(session)
 if not ProcessorConfig.Enabled then
  -- Retain earned legacy balances and pay them at the existing deposit pad.
  -- No timer, movement requirement, or consumption of saved Finish Now credits.
  if #state.batches>0 then Processor.Finish(state);session:Touch() end
  local pad,owner=self.world:EggDeposit(session.plotIndex)
  if owner==session.userId and onCashPad(pad,position) then self:ClaimReady(session,pad,now) end
  return
 end
 -- Only visit the queue/value ledger on whole-second ticks.
 if #state.batches>0 then
  yard.processorSeconds=(yard.processorSeconds or 0)+dt
  local seconds=math.floor(yard.processorSeconds+1e-9)
  if seconds>0 then
   yard.processorSeconds=math.max(0,yard.processorSeconds-seconds)
   if Processor.Step(state,seconds,Processor.Rate(state,session.entitlements.DoubleEggSpawn)) then session:Touch() end
  end
 else yard.processorSeconds=0 end
 if #state.batches==0 then yard.processorSeconds=0 end
 local board=self:Board(session)
 local collection=board and board:FindFirstChild("CollectionPart")
 local pad=collection and collection:FindFirstChild("TouchPart")
 -- An unavailable board must not strand earned cash; retain the owned-pad fallback.
 if not board then
  local fallback,owner=self.world:EggDeposit(session.plotIndex)
  if owner==session.userId then pad=fallback end
 end
 -- Every payout requires current horizontal movement, not merely pad occupancy.
 -- Read replicated root velocity on the server; client MoveDirection is not the grant authority.
 if grounded~=true or not onCashPad(pad,position) then return end
 if not velocity or not (velocity.X^2+velocity.Z^2>CASH_MIN_HORIZONTAL_SPEED^2) then return end
 self:ClaimReady(session,pad,now)
end

function EggService:ClaimReady(session,pad,now)
 local state=session.eggProcessor
 local yard=self:Yard(session)
 -- Only the server's current ready balance can be paid; repeated requests cannot duplicate it.
 if state.readyValue<=0 or now-(yard.lastCashClaimAt or -math.huge)+1e-9<CASH_COLLECT_SECONDS then return false end
 local amount=session:EarnedAmount(state.readyValue,"eggs")
 if amount>Currency.MaxCoins-session.coins then return false end
 local raw=state.readyValue;state.readyValue=0
 local credited=session:Credit(raw,"eggs")
 yard.lastCashClaimAt=now
 session.tutorial.soldEggs=true
 yard.cashSerial=(yard.cashSerial or 0)+1
 yard.cashClaim={id=yard.generation..":"..yard.cashSerial,value=credited,at=now,
  x=pad.Position.X,y=pad.Position.Y+1,z=pad.Position.Z}
 return true
end

function EggService:Yard(session)
 local yard=self.yards[session.userId]
 -- Debug reset replaces the pet table; old eggs must not pay into a fresh test.
 if not yard or yard.pets~=session.pets then
  self.generation+=1
  yard={pets=session.pets,layers={},drops={},receipts={},revision=0,ordinal=0,generation=self.generation}
  self.yards[session.userId]=yard
 end
 return yard
end

function EggService:Lay(session,yard,petId,layer,now)
 local quantity,value=layer.count,layer.value
 if quantity<1 then return end
 local count,existing=0,nil
 for _,drop in yard.drops do
  if drop.petId==petId and not drop.claimAt then count+=1;existing=drop end
 end
 -- A visual represents an exact quantity of identical eggs. Work is bounded by
 -- drop count, even when one chicken produces hundreds of thousands per second.
 if count>=Config.EggsPerChicken or #yard.drops>=Config.EggMaxDrops then
  if not existing then for _,drop in yard.drops do if not drop.claimAt then existing=drop;break end end end
  if existing then
   existing.value+=value;existing.stack+=quantity;yard.revision+=1
   layer.count,layer.value=0,0
   return
  end
  -- All available stacks are in flight; retain their next quantity and value.
  return
 end
 local pet=session.pets[petId]
 local origin=self.world:PetPosition(session.plotIndex,petId)
  or self.world:ReturnPosition(session,petId,layer.ordinal)
 local frame=self.world:PlotFrame(session.plotIndex)
 local localAt=frame:PointToObjectSpace(origin)
 local layout=Layout.ForPlot(session.plotIndex)
 self.serial+=1
 local angle=self.serial*2.399963
 local x,z=Layout.Clamp(layout,localAt.X+math.cos(angle)*2.2,localAt.Z+math.sin(angle)*2.2)
 local position=(frame*CFrame.new(x,layout.FootY,z)).Position
 table.insert(yard.drops,{id=tostring(self.serial),petId=petId,species=pet.species,
  x=position.X,y=position.Y,z=position.Z,originX=origin.X,originY=origin.Y+0.8,originZ=origin.Z,
  value=value,stack=quantity,born=now,readyAt=now+Config.EggSettleSeconds})
 layer.count,layer.value=0,0
 yard.revision+=1
end

function EggService:Produce(session,dt,now)
 local yard=self:Yard(session)
 local production=session:EggProductionMultiplier()
 local unitValue=Rules.EggUnitValue(session.incomeLevel)
 for id,pet in session.pets do
  local layer=yard.layers[id]
  if not layer then
   yard.ordinal+=1
   layer={count=0,value=0,fraction=0,elapsed=0,ordinal=yard.ordinal}
   yard.layers[id]=layer
  end
  if not session:IsPetHome(id) then continue end
  -- Speed changes affect future production only; partial eggs survive upgrades
  -- and time away. Price each completed egg once, at the shared current value.
  local accrued=layer.fraction+Rules.EggRate(pet.species,pet.stars,pet.level)*production*dt
  local quantity=math.floor(accrued+1e-7)
  layer.fraction=math.max(0,accrued-quantity)
  layer.count+=quantity;layer.value+=quantity*unitValue
  layer.elapsed+=dt
  if layer.count>0 and layer.elapsed+1e-7>=Config.EggVisualBatchSeconds then
   layer.elapsed=0
   self:Lay(session,yard,id,layer,now)
  end
 end
 for id in yard.layers do if not session.pets[id] then yard.layers[id]=nil end end
end

function EggService:Pay(session,yard,drop,now)
 if drop.paid then return end
 drop.paid=true
 local credited=session:EarnedAmount(drop.value,"eggs")
 if drop.collector=="rover" then
  local rover=yard.rover
  if rover and rover.enabled then
   rover.pendingCount=math.max(0,rover.pendingCount-(drop.stack or 1))
   rover.cargoCount+=drop.stack or 1
   rover.cargoValue+=drop.value
  else
   -- A claim already belongs to this player, even if the robot was toggled off.
   session.eggCarry.count+=drop.stack or 1
   session.eggCarry.value+=drop.value
   session:Touch()
  end
 else
  session.eggCarry.count+=drop.stack or 1
  session.eggCarry.value+=drop.value
  session:Touch()
 end
 session.tutorial.collectedEggs=true
 table.insert(yard.receipts,{id=drop.id,value=credited,count=drop.stack or 1,at=now,
  collector=drop.collector or "player",targetX=drop.targetX,targetY=drop.targetY,targetZ=drop.targetZ})
 yard.revision+=1
end

function EggService:RecordDeposit(yard,count,credited,now,collector,position,queued)
 yard.depositSerial=(yard.depositSerial or 0)+1
 yard.deposit={id=yard.generation..":"..yard.depositSerial,count=count,value=credited,at=now,
  collector=collector,queued=queued,targetX=position and position.X,targetY=position and position.Y,targetZ=position and position.Z}
 -- Keep both player and vacuum payouts when they occur between snapshots.
 yard.deposits=yard.deposits or {}
 table.insert(yard.deposits,yard.deposit)
 yard.revision+=1
end

function EggService:Deposit(session,position,now)
 if not session.loaded or session.closing or session.saveLost or not position then return false end
 local pad,ownerId=self.world:EggDeposit(session.plotIndex)
 if not pad or ownerId~=session.userId then return false end
 local at=pad.CFrame:PointToObjectSpace(position)
 if math.abs(at.X)>pad.Size.X/2+0.7 or math.abs(at.Z)>pad.Size.Z/2+0.7
  or at.Y< -1 or at.Y>pad.Size.Y/2+5 then return false end
 local carry=session.eggCarry
 if carry.value<=0 then return false end
 local count,value=carry.count,carry.value
 -- No yield between ledger transfer and clearing the bag.
 local accepted,credited,queued=self:AcceptDeposit(session,count,value)
 if not accepted then return false end
 session.eggCarry={count=0,value=0}
 session:Touch()
 if not queued then session.tutorial.soldEggs=true end
 local yard=self:Yard(session)
 self:RecordDeposit(yard,count,credited,now,"player",pad.Position,queued)
 return true,credited
end

function EggService:SettleClaims(session,yard,now,roverOnly,forceAll)
 for i=#yard.drops,1,-1 do
  local drop=yard.drops[i]
  if drop.claimAt and (forceAll or (if roverOnly then drop.collector=="rover" else now>=drop.claimAt+Config.EggFlightSeconds)) then
   self:Pay(session,yard,drop,now);table.remove(yard.drops,i)
  end
 end
end

function EggService:PreserveCargo(session,yard,now)
 local rover=yard.rover
 if not rover then return end
 -- Finish earned claims while this rover still owns them, then transfer once.
 self:SettleClaims(session,yard,now,true)
 if rover.cargoCount>0 or rover.cargoValue>0 then
  session.eggCarry.count+=rover.cargoCount
  session.eggCarry.value+=rover.cargoValue
  rover.cargoCount,rover.cargoValue=0,0
  session:Touch()
 end
 rover.enabled=false
 yard.revision+=1
end

function EggService:UpdateRover(session,yard,dt,now)
 local pad,ownerId=self.world:EggDeposit(session.plotIndex)
 local enabled=session:AutomaticEnabled("AutoCollectEggs")
  or (RunService:IsStudio() and session.commerceTestPreset==nil
   and workspace:GetAttribute(VacuumConfig.StudioTestAttribute)==true)
 enabled=enabled and pad~=nil and pad:IsA("BasePart") and ownerId==session.userId
 if not enabled then
  if yard.rover and yard.rover.enabled then self:PreserveCargo(session,yard,now) end
  return
 end
 -- Resize the next empty sweep, not a rover carrying earned eggs or in-flight claims.
 if yard.rover and yard.rover.enabled and yard.roverPlotSize~=session.plotSizeLevel
  and yard.rover.state=="Idle" and yard.rover.cargoCount==0 and yard.rover.pendingCount==0 then
  yard.rover=nil
 end
 if not yard.rover or not yard.rover.enabled then
  yard.roverSerial=(yard.roverSerial or 0)+1
  yard.roverPlotSize=session.plotSizeLevel
  yard.rover=EggRover.new(session.userId..":"..yard.generation..":"..yard.roverSerial,
   self.world:PlotFrame(session.plotIndex),session.plotIndex,pad,now)
 end
 local rover=yard.rover
 local hasEggs=false
 for _,drop in yard.drops do
  if not drop.claimAt and now>=drop.readyAt then hasEggs=true;break end
 end
 rover:Step(dt,now,hasEggs)
 -- Send the latest nozzle as a fallback for late packets or a removed model.
 local nozzle=rover:Nozzle()
 for _,drop in yard.drops do
  if drop.collector=="rover" and drop.claimAt then
   drop.targetX,drop.targetY,drop.targetZ=nozzle.X,nozzle.Y,nozzle.Z
  end
 end
 if rover:ReadyToUnload(now) then
  -- Recheck the owner's physical input pad at the payment boundary. The rover
  -- cannot sell remotely simply because its state says it reached a dock.
  local localAt=pad.CFrame:PointToObjectSpace(rover.position)
  local atPad=math.abs(localAt.X)<=pad.Size.X/2+0.7 and math.abs(localAt.Z)<=pad.Size.Z/2+0.7
   and math.abs(localAt.Y)<=pad.Size.Y/2+5
  if not atPad then return end
  local count,value=rover.cargoCount,rover.cargoValue
  if value>0 then
   local accepted,credited,queued=self:AcceptDeposit(session,count,value)
   if not accepted then return end
   if not queued then session.tutorial.soldEggs=true end
   self:RecordDeposit(yard,count,credited,now,"rover",rover.position,queued)
  end
  rover.cargoCount,rover.cargoValue=0,0
  rover:FinishUnload(now)
 end
end

function EggService:Claim(yard,drop,now,collector,target)
 if drop.claimAt then return false end
 drop.claimAt=now;drop.collector=collector
 drop.targetX,drop.targetY,drop.targetZ=target.X,target.Y,target.Z
 yard.revision+=1
 if collector=="rover" then
  yard.rover.pendingCount+=drop.stack or 1
  yard.rover.suctionSerial+=1
 end
 return true
end

function EggService:Collect(session,position,now)
 local yard=self:Yard(session)
 if position then
  local near={}
  local radius=Config.EggMagnetRadius*(if session.entitlements and session.entitlements.EggMagnet==true then ShopCatalog.RadiusMultiplier else 1)
  for _,drop in yard.drops do
   if not drop.claimAt and now>=drop.readyAt then
    local distance=(position-Vector3.new(drop.x,drop.y+0.8,drop.z)).Magnitude
    if distance<=radius then table.insert(near,{drop=drop,distance=distance}) end
   end
  end
  table.sort(near,function(a,b)return a.distance<b.distance end)
  for i=1,math.min(Config.EggPickupBatch,#near) do
   self:Claim(yard,near[i].drop,now+(i-1)*0.06,"player",position+Vector3.new(0,-0.25,0))
  end
 end
 local rover=yard.rover
 if rover and rover.enabled and rover:CanCollect(now) then
  local nozzle=rover:Nozzle()
  local near={}
  for _,drop in yard.drops do
   if not drop.claimAt and now>=drop.readyAt then
    local distance=(nozzle-Vector3.new(drop.x,drop.y+0.8,drop.z)).Magnitude
    if distance<=rover.suctionRadius then table.insert(near,{drop=drop,distance=distance}) end
   end
  end
  table.sort(near,function(a,b)return a.distance<b.distance end)
  for i=1,math.min(VacuumConfig.PickupBatch,#near) do
   self:Claim(yard,near[i].drop,now+(i-1)*VacuumConfig.PickupStagger,"rover",nozzle)
  end
 end
 for i=#yard.receipts,1,-1 do if now-yard.receipts[i].at>3 then table.remove(yard.receipts,i) end end
 for i=#(yard.deposits or {}),1,-1 do if now-yard.deposits[i].at>3 then table.remove(yard.deposits,i) end end
end

function EggService:Step(sessions,dt,now)
 for _,session in sessions do
  if not session.loaded or session.closing or session.saveLost then continue end
  self:Produce(session,dt,now)
  local yard=self:Yard(session)
  self:SettleClaims(session,yard,now,false)
  self:UpdateRover(session,yard,dt,now)
  local player=Players:GetPlayerByUserId(session.userId)
  local character=player and player.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  local humanoid=character and character:FindFirstChildOfClass("Humanoid")
  local position=if root and humanoid and humanoid.Health>0 then root.Position else nil
  self:Collect(session,position,now)
  self:Deposit(session,position,now)
  local grounded=humanoid~=nil and humanoid.Health>0 and not humanoid.Jump and not humanoid.Sit
   and not humanoid.PlatformStand and humanoid.FloorMaterial~=Enum.Material.Air
  self:ProcessAndClaim(session,position,dt,now,grounded,root and root.AssemblyLinearVelocity)
 end
end

function EggService:Snapshot(session,now)
 local yard=self:Yard(session)
 local drops,receipts={},{}
 local value,count=0,0
 for _,drop in yard.drops do
  local copy=table.clone(drop)
  copy.value=session:EarnedAmount(drop.value,"eggs")
  copy.age=math.max(0,now-drop.born)
  copy.flightAge=if drop.claimAt then now-drop.claimAt else nil
  copy.born,copy.readyAt,copy.claimAt=nil,nil,nil
  table.insert(drops,copy);value+=copy.value;count+=copy.stack
 end
 for _,receipt in yard.receipts do
  local copy=table.clone(receipt);copy.at=nil;table.insert(receipts,copy)
 end
 local deposit=if yard.deposit and now-yard.deposit.at<3 then table.clone(yard.deposit) else nil
 if deposit then deposit.at=nil end
 local deposits={}
 for _,receipt in yard.deposits or {} do
  if now-receipt.at<3 then local copy=table.clone(receipt);copy.at=nil;table.insert(deposits,copy) end
 end
 local processor=session.eggProcessor
 local queued=Processor.Totals(processor)
 local cashClaim=if yard.cashClaim and now-yard.cashClaim.at<3 then table.clone(yard.cashClaim) else nil
 if cashClaim then cashClaim.at=nil end
 return {revision=yard.revision,generation=yard.generation,drops=drops,receipts=receipts,value=value,count=count,
  processor={enabled=ProcessorConfig.Enabled,queuedCount=queued,
   rate=Processor.Rate(processor,session.entitlements.DoubleEggSpawn),level=processor.level,
   nextRate=ProcessorConfig.Rate(processor.level+1)*(if session.entitlements.DoubleEggSpawn then 2 else 1),
   upgradePrice=if ProcessorConfig.Enabled then ProcessorConfig.Price(processor.level) else nil,readyCash=session:EarnedAmount(processor.readyValue,"eggs"),
   finishCredits=processor.finishCredits},cashClaim=cashClaim,
  requiresDeposit=true,carriedCount=session.eggCarry.count,
  carriedValue=session:EarnedAmount(session.eggCarry.value,"eggs"),deposit=deposit,deposits=deposits,
  rover=if yard.rover then yard.rover:Snapshot(session) else {enabled=false}}
end

function EggService:Release(session)
 local yard=self.yards[session.userId]
 if not yard then return end
 -- A proximity-claimed pickup is already earned even if the player leaves mid-flight.
 if not session.saveLost then
  local now=os.clock()
  self:SettleClaims(session,yard,now,false,true)
  self:PreserveCargo(session,yard,now)
 end
 self.yards[session.userId]=nil
end

function EggService:Destroy()
 table.clear(self.yards)
end
return EggService
