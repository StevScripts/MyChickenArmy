--!strict
-- Server-owned pickup ledger. Authored plots carry eggs until their sell pad is reached.
-- October 20 (docs/team/COLLECTION_TOOLS.md): players click, tap or press R2 on eggs
-- (GameServer "CollectEggs") and they fly into the unlimited bag; the held Egg Vacuum
-- pulls nearby eggs into its own cargo until it is full. The green pad sells both.
-- Walk-over pickup and the robot vacuum (Auto Collect pass) are retired.
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local Tools=require(Shared.VacuumConfig)
local Layout=require(Shared.HomePlotLayout)
local Processor=require(script.Parent.EggProcessor)
local ProcessorConfig=require(Shared.EggProcessorConfig)
local Currency=require(Shared.CurrencyLimits)
local TutorialGuide=require(Shared.TutorialGuide)
local MutationCatalog=require(Shared.MutationCatalog)
local CARRY_LIMIT=require(script.Parent.PlayerSession).CarryLimit
local EggService={}
EggService.__index=EggService
local CASH_COLLECT_SECONDS=1
local CASH_MIN_HORIZONTAL_SPEED=0.5 -- Ignore standing jitter and vertical pad travel.
-- Eggs still landing in the bag right after a sale wait for the next pass instead of
-- firing a second payout (pop and sound) a split second later.
local DEPOSIT_DEBOUNCE_SECONDS=0.5
-- Vacuum capacity follows the Flock's laying; recount it at most this often.
local CAPACITY_REFRESH_SECONDS=1
local VACUUM_TOOL="EggVacuum"

local function onCashPad(pad,position)
 if not position or not pad or not pad:IsA("BasePart") then return false end
 local at=pad.CFrame:PointToObjectSpace(position)
 return math.abs(at.X)<=pad.Size.X/2+0.7 and math.abs(at.Z)<=pad.Size.Z/2+0.7
  and at.Y>=-1 and at.Y<=pad.Size.Y/2+5
end

-- Flat distance from the player to a drop, plus the vertical reach every pickup shares.
local function reach(position,drop)
 if math.abs(drop.y-position.Y)>Tools.MaxHeight then return math.huge end
 return math.sqrt((drop.x-position.X)^2+(drop.z-position.Z)^2)
end

-- The player's live root while alive, and their character.
local function playerRoot(session)
 local player=Players:GetPlayerByUserId(session.userId)
 local character=player and player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if root and root:IsA("BasePart") and humanoid and humanoid.Health>0 then return root.Position,character,humanoid,root end
 return nil,character,humanoid,nil
end

-- Server-granted tools only: a client-made Tool never replicates to the server.
local function holding(character,name)
 local tool=character and character:FindFirstChild(name)
 return tool~=nil and tool:IsA("Tool") and tool:GetAttribute("PetRollTool")==name
end

function EggService.new(world)
 return setmetatable({world=world,yards={},serial=0,generation=0},EggService)
end

-- The saved hand-vacuum cargo (S7 persists it as `vacuumCargo`).
local function vacuumCargo(session)
 local cargo=session.vacuumCargo
 if type(cargo)~="table" then cargo={count=0,value=0};session.vacuumCargo=cargo end
 return cargo
end

-- Saved eggCarry must stay loadable. Room counts the bag and every egg already flying
-- into it. The bag has no designed limit; this only keeps the save inside CarryLimit.
local function bagRoom(session,yard)
 local count,value=session.eggCarry.count,session.eggCarry.value
 for _,drop in yard.drops do
  if drop.claimAt and not drop.paid and drop.collector~="vacuum" then count+=drop.stack or 1;value+=drop.value end
 end
 return CARRY_LIMIT-count,CARRY_LIMIT-value
end

local function addCarry(session,count,value)
 -- Backstop only: pickups are refused before this bound is reached.
 local carry=session.eggCarry
 carry.count=math.min(CARRY_LIMIT,carry.count+count)
 carry.value=math.min(CARRY_LIMIT,carry.value+value)
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
 if not cost then return false,"Selling Speed is fully upgraded." end
 if level~=state.level or price~=cost then return false,"The upgrade changed. Try again." end
 if session.coins<cost then return false,"Not enough coins for this upgrade." end
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
  yard={pets=session.pets,layers={},drops={},receipts={},revision=0,ordinal=0,generation=self.generation,
   vacuumPending=0,vacuumPendingValue=0}
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
  -- A stack never grows past what one empty bag can hold, so every drop stays collectable.
  local function fits(drop) return drop.stack+quantity<=CARRY_LIMIT and drop.value+value<=CARRY_LIMIT end
  if existing and not fits(existing) then existing=nil end
  if not existing then for _,drop in yard.drops do if not drop.claimAt and fits(drop) then existing=drop;break end end end
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
 if session:EggsHeld(now) then return end
 local yard=self:Yard(session)
 local production=session:EggProductionMultiplier()
 -- Held territories raise live egg value only (offline uses OfflineCash.Rate).
 local unitValue=Rules.EggUnitValue(session.incomeLevel)*(1+session.researchEffects.eggValue)*(1+(session.territoryBonus or 0))
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
  -- Launch: a mutation multiplies this chicken's eggs (1 with the foundation stub).
  local accrued=layer.fraction+Rules.EggRate(pet.species,pet.stars,pet.level)*MutationCatalog.Multiplier(pet.mutation)*production*dt
  local quantity=math.floor(accrued+1e-7)
  layer.fraction=math.max(0,accrued-quantity)
  local priced=quantity*unitValue+session.research.eggValueRemainder
  local whole=math.floor(priced+1e-7)
  session.research.eggValueRemainder=math.max(0,priced-whole)
  layer.count+=quantity;layer.value+=whole
  layer.elapsed+=dt
  if layer.count>0 and layer.elapsed+1e-7>=Config.EggVisualBatchSeconds then
   layer.elapsed=0
   self:Lay(session,yard,id,layer,now)
  end
 end
 for id in yard.layers do if not session.pets[id] then yard.layers[id]=nil end end
end

-- Eggs per second the yard lays right now, counting the same chickens, rates and
-- boosts as Produce. The vacuum's capacity is seconds of this laying. S10's
-- LayingIds is the Flock at home plus fill-ins for layers away with the Army, so a
-- march never shrinks the vacuum; before S10 every chicken at home lays.
function EggService:LayingRate(session)
 local rate=0
 local function add(pet)
  if pet then rate+=Rules.EggRate(pet.species,pet.stars,pet.level)*MutationCatalog.Multiplier(pet.mutation) end
 end
 if session.LayingIds then
  for _,id in session:LayingIds() do add(session.pets[id]) end
 else
  for id,pet in session.pets do if session:IsPetHome(id) then add(pet) end end
 end
 return rate*session:EggProductionMultiplier()
end

-- Eggs the vacuum holds: Seconds plus the Tools tiers and Gem levels (also seconds)
-- of the Flock's current laying, never below MinCapacity.
function EggService:VacuumCapacity(session,yard,now)
 if yard.capacity and now<(yard.capacityAt or 0) then return yard.capacity end
 local seconds=Tools.Seconds+(session.researchEffects.vacuumCapacity or 0)
 yard.capacity=math.max(Tools.MinCapacity,math.floor(seconds*self:LayingRate(session)+0.5))
 yard.capacityAt=now+CAPACITY_REFRESH_SECONDS
 return yard.capacity
end

function EggService:VacuumRange(session)
 return Tools.Range+(session.researchEffects.vacuumRange or 0)
end

function EggService:ClickRange(session)
 return Tools.ClickRange+(session.researchEffects.pickupStuds or 0)
end

function EggService:Pay(session,yard,drop,now)
 if drop.paid then return end
 drop.paid=true
 local count=drop.stack or 1
 local credited=session:EarnedAmount(drop.value,"eggs")
 if drop.collector=="vacuum" then
  -- Claims always belong to the vacuum that made them, even if it was put away.
  yard.vacuumPending=math.max(0,(yard.vacuumPending or 0)-count)
  yard.vacuumPendingValue=math.max(0,(yard.vacuumPendingValue or 0)-drop.value)
  local cargo=vacuumCargo(session)
  cargo.count=math.min(CARRY_LIMIT,cargo.count+count)
  cargo.value=math.min(CARRY_LIMIT,cargo.value+drop.value)
 else
  addCarry(session,count,drop.value)
 end
 -- Count committed egg units once, including stacked and vacuum pickups. The
 -- saved lesson counter survives deposits and is bounded after completion.
 session.tutorial.collectedEggCount=math.min(TutorialGuide.EggGoal,TutorialGuide.CollectedEggCount(session.tutorial)+count)
 session.tutorial.collectedEggs=session.tutorial.collectedEggCount>=TutorialGuide.EggGoal
 session:Touch()
 table.insert(yard.receipts,{id=drop.id,value=credited,count=count,at=now,
  collector=drop.collector or "player",targetX=drop.targetX,targetY=drop.targetY,targetZ=drop.targetZ})
 yard.revision+=1
end

function EggService:RecordDeposit(yard,count,credited,now,collector,position,queued)
 yard.depositSerial=(yard.depositSerial or 0)+1
 yard.deposit={id=yard.generation..":"..yard.depositSerial,count=count,value=credited,at=now,
  collector=collector,queued=queued,targetX=position and position.X,targetY=position and position.Y,targetZ=position and position.Z}
 -- Keep every payout when several occur between snapshots.
 yard.deposits=yard.deposits or {}
 table.insert(yard.deposits,yard.deposit)
 yard.revision+=1
end

-- The pad sells the bag and the vacuum together as one sale. A sale that carried
-- vacuum eggs is "vacuum"; both kinds get the coin burst (only "rover" never did).
function EggService:Deposit(session,position,now)
 if not session.loaded or session.closing or session.saveLost or not position then return false end
 local pad,ownerId=self.world:EggDeposit(session.plotIndex)
 if not pad or ownerId~=session.userId then return false end
 local at=pad.CFrame:PointToObjectSpace(position)
 if math.abs(at.X)>pad.Size.X/2+0.7 or math.abs(at.Z)>pad.Size.Z/2+0.7
  or at.Y< -1 or at.Y>pad.Size.Y/2+5 then return false end
 local carry,cargo=session.eggCarry,vacuumCargo(session)
 if carry.value<=0 and cargo.value<=0 then return false end
 local yard=self:Yard(session)
 if now-(yard.lastPlayerDepositAt or -math.huge)<DEPOSIT_DEBOUNCE_SECONDS then return false end
 local count,value=carry.count+cargo.count,carry.value+cargo.value
 -- No yield between ledger transfer and clearing the bag and the vacuum.
 local accepted,credited,queued=self:AcceptDeposit(session,count,value)
 if not accepted then return false end
 local vacuumed=cargo.count>0
 session.eggCarry={count=0,value=0}
 session.vacuumCargo={count=0,value=0}
 session:Touch()
 if not queued then session.tutorial.soldEggs=true end
 yard.lastPlayerDepositAt=now
 self:RecordDeposit(yard,count,credited,now,if vacuumed then "vacuum" else "player",pad.Position,queued)
 return true,credited
end

function EggService:SettleClaims(session,yard,now,forceAll)
 for i=#yard.drops,1,-1 do
  local drop=yard.drops[i]
  if drop.claimAt and (forceAll or now>=drop.claimAt+Config.EggFlightSeconds) then
   self:Pay(session,yard,drop,now);table.remove(yard.drops,i)
  end
 end
end

function EggService:Claim(yard,drop,now,collector,target)
 if drop.claimAt then return false end
 drop.claimAt=now;drop.collector=collector
 drop.targetX,drop.targetY,drop.targetZ=target.X,target.Y,target.Z
 yard.revision+=1
 return true
end

-- Takes `take` eggs off an unclaimed stack as a new drop on the same spot. Coins stay
-- whole: the new part gets its share rounded down and the eggs left behind keep the
-- rest, so a split never creates or loses value.
function EggService:Split(yard,drop,take)
 local stack=drop.stack or 1
 local value=math.floor(drop.value*take/stack)
 self.serial+=1
 local part=table.clone(drop)
 part.id=tostring(self.serial)
 part.stack,part.value=take,value
 drop.stack,drop.value=stack-take,drop.value-value
 table.insert(yard.drops,part)
 yard.revision+=1
 return part
end

-- October 20 click, tap and gamepad pickup. Each id names one ready stack within
-- Click Range of the player (plus latency slack); it flies into the bag.
function EggService:CollectClicked(session,ids,now)
 if type(ids)~="table" or not session.loaded or session.closing or session.saveLost then return 0 end
 local position=playerRoot(session)
 if not position then return 0 end
 local wanted,count={},0
 for _,id in ids do
  count+=1
  if count>Tools.ClickBatch then break end
  if type(id)=="string" and #id<=24 then wanted[id]=true end
 end
 local yard=self:Yard(session)
 local range=self:ClickRange(session)+Tools.ClickSlack
 local roomCount,roomValue=bagRoom(session,yard)
 local claimed=0
 for _,drop in yard.drops do
  if wanted[drop.id] and not drop.claimAt and now>=drop.readyAt and reach(position,drop)<=range then
   local stack=drop.stack or 1
   if stack<=roomCount and drop.value<=roomValue then
    roomCount-=stack;roomValue-=drop.value
    self:Claim(yard,drop,now+claimed*0.03,"player",position+Vector3.new(0,-0.25,0))
    claimed+=1
   end
  end
 end
 return claimed
end

-- The equipped Egg Vacuum pulls the nearest ready eggs in range until it is full;
-- a stack bigger than the room left is split and the rest stays on the ground.
function EggService:Vacuum(session,yard,root,now)
 local cargo=vacuumCargo(session)
 local room=self:VacuumCapacity(session,yard,now)-cargo.count-(yard.vacuumPending or 0)
 if room<1 then return end
 local position=root.Position
 local range=self:VacuumRange(session)
 local near={}
 for _,drop in yard.drops do
  if not drop.claimAt and now>=drop.readyAt then
   local distance=reach(position,drop)
   if distance<=range then table.insert(near,{drop=drop,distance=distance}) end
  end
 end
 if #near==0 then return end
 table.sort(near,function(a,b) return a.distance<b.distance end)
 -- Clients aim each egg at the held nozzle; this is the fallback landing point.
 local target=position+root.CFrame.LookVector*1.6+Vector3.new(0,0.4,0)
 local claimed=0
 for _,entry in near do
  if claimed>=Tools.PickupBatch or room<1 then break end
  local drop=entry.drop
  if (drop.stack or 1)>room then drop=self:Split(yard,drop,room) end
  local stack=drop.stack or 1
  room-=stack
  yard.vacuumPending=(yard.vacuumPending or 0)+stack
  yard.vacuumPendingValue=(yard.vacuumPendingValue or 0)+drop.value
  self:Claim(yard,drop,now+claimed*Tools.PickupStagger,"vacuum",target)
  claimed+=1
 end
end

function EggService:Step(sessions,dt,now)
 for _,session in sessions do
  if not session.loaded or session.closing or session.saveLost then continue end
  self:Produce(session,dt,now)
  local yard=self:Yard(session)
  self:SettleClaims(session,yard,now,false)
  local position,character,humanoid,root=playerRoot(session)
  if root and session.eggVacuum==true and holding(character,VACUUM_TOOL) then self:Vacuum(session,yard,root,now) end
  for i=#yard.receipts,1,-1 do if now-yard.receipts[i].at>3 then table.remove(yard.receipts,i) end end
  for i=#(yard.deposits or {}),1,-1 do if now-yard.deposits[i].at>3 then table.remove(yard.deposits,i) end end
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
  copy.born,copy.readyAt,copy.claimAt,copy.paid=nil,nil,nil,nil
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
 local cargo=vacuumCargo(session)
 local pending=yard.vacuumPending or 0
 return {revision=yard.revision,generation=yard.generation,drops=drops,receipts=receipts,value=value,count=count,
  processor={enabled=ProcessorConfig.Enabled,queuedCount=queued,
   rate=Processor.Rate(processor,session.entitlements.DoubleEggSpawn),level=processor.level,
   nextRate=ProcessorConfig.Rate(processor.level+1)*(if session.entitlements.DoubleEggSpawn then 2 else 1),
   upgradePrice=if ProcessorConfig.Enabled then ProcessorConfig.Price(processor.level) else nil,readyCash=session:EarnedAmount(processor.readyValue,"eggs"),
   finishCredits=processor.finishCredits},cashClaim=cashClaim,
  -- Everything the pad will sell: the bag plus the vacuum's cargo.
  requiresDeposit=true,carriedCount=session.eggCarry.count+cargo.count,
  carriedValue=session:EarnedAmount(session.eggCarry.value+cargo.value,"eggs"),deposit=deposit,deposits=deposits,
  bagCount=session.eggCarry.count,clickRange=self:ClickRange(session),
  -- count includes eggs still flying into the nozzle, so the meter fills as they land.
  vacuum={count=cargo.count+pending,stored=cargo.count,
   value=session:EarnedAmount(cargo.value+(yard.vacuumPendingValue or 0),"eggs"),
   capacity=self:VacuumCapacity(session,yard,now),range=self:VacuumRange(session)}}
end

function EggService:Release(session)
 local yard=self.yards[session.userId]
 if not yard then return end
 -- A claimed pickup is already earned even if the player leaves mid-flight.
 if not session.saveLost then self:SettleClaims(session,yard,os.clock(),true) end
 self.yards[session.userId]=nil
end

function EggService:Destroy()
 table.clear(self.yards)
end
return EggService
