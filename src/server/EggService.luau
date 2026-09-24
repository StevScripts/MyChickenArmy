--!strict
-- Server-owned pickup ledger. Authored plots carry eggs until their sell pad is reached.
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Layout=require(Shared.HomePlotLayout)
local ShopCatalog=require(Shared.ShopCatalog)
local EggService={}
EggService.__index=EggService

function EggService.new(world)
 return setmetatable({world=world,yards={},serial=0,generation=0},EggService)
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
 local value=math.floor(layer.value+1e-7)
 if value<1 then return end
 layer.value-=value
 local count,existing=0,nil
 for _,drop in yard.drops do
  if drop.petId==petId and not drop.claimAt then count+=1;existing=drop end
 end
 -- At capacity, keep the value in an existing egg instead of spawning clutter.
 if count>=Config.EggsPerChicken or #yard.drops>=Config.EggMaxDrops then
  if not existing then for _,drop in yard.drops do if not drop.claimAt then existing=drop;break end end end
  if existing then
   existing.value+=value;existing.stack+=1;yard.revision+=1
   return
  end
  layer.value+=value -- All available eggs are in flight; keep their next value.
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
 local position=(frame*CFrame.new(
  math.clamp(localAt.X+math.cos(angle)*2.2,layout.YardMinX,layout.YardMaxX),
  layout.FootY,math.clamp(localAt.Z+math.sin(angle)*2.2,layout.YardMinZ,layout.YardMaxZ))).Position
 table.insert(yard.drops,{id=tostring(self.serial),petId=petId,species=pet.species,
  x=position.X,y=position.Y,z=position.Z,originX=origin.X,originY=origin.Y+0.8,originZ=origin.Z,
  value=value,stack=1,born=now,readyAt=now+Config.EggSettleSeconds})
 yard.revision+=1
end

function EggService:Produce(session,dt,now)
 local yard=self:Yard(session)
 local production=if session.entitlements and session.entitlements.DoubleEggSpawn==true then 2 else 1
 local interval=Config.EggLaySeconds/production
 for id,pet in session.pets do
  local layer=yard.layers[id]
  if not layer then
   yard.ordinal+=1
   layer={value=0,elapsed=0,ordinal=yard.ordinal,interval=interval,
    nextLay=interval*(0.5+((yard.ordinal-1)%8)/8)}
   yard.layers[id]=layer
  end
  if layer.interval~=interval then
   -- Preserve progress through this egg when ownership refreshes. Do not dump
   -- a backlog or multiply value that was already produced before the pass.
   local ratio=interval/(layer.interval or Config.EggLaySeconds)
   layer.elapsed*=ratio;layer.nextLay*=ratio;layer.interval=interval
  end
  if not session:IsPetHome(id) then continue end
  layer.value+=session:PetIncome(id)*dt*production
  layer.elapsed+=dt
  if layer.elapsed+1e-7>=layer.nextLay then
   layer.elapsed=math.max(0,layer.elapsed-layer.nextLay);layer.nextLay=interval
   self:Lay(session,yard,id,layer,now)
  end
 end
 for id in yard.layers do if not session.pets[id] then yard.layers[id]=nil end end
end

function EggService:Pay(session,yard,drop,now)
 local deposit=self.world:EggDeposit(session.plotIndex)
 local credited=session:EarnedAmount(drop.value,"eggs")
 if deposit then
  session.eggCarry.count+=drop.stack or 1
  session.eggCarry.value+=drop.value
  session:Touch()
 else
  -- Unconverted plots retain their old pickup behavior during the Plot1 trial.
  -- A returning player never strands previously carried value on an old plot.
  local carried=session.eggCarry.value
  session.eggCarry={count=0,value=0}
  credited=session:Credit(drop.value+carried,"eggs")
 end
 session.tutorial.collectedEggs=true
 table.insert(yard.receipts,{id=drop.id,value=credited,count=drop.stack or 1,at=now})
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
 -- No yield between clearing the bag and crediting: repeated overlap cannot pay twice.
 session.eggCarry={count=0,value=0}
 local credited=session:Credit(value,"eggs");session.tutorial.soldEggs=true
 local yard=self:Yard(session)
 yard.depositSerial=(yard.depositSerial or 0)+1
 yard.deposit={id=yard.generation..":"..yard.depositSerial,count=count,value=credited,at=now}
 yard.revision+=1
 return true,credited
end

function EggService:Collect(session,position,now)
 local yard=self:Yard(session)
 for i=#yard.drops,1,-1 do
  local drop=yard.drops[i]
  if drop.claimAt and now>=drop.claimAt+Config.EggFlightSeconds then
   self:Pay(session,yard,drop,now);table.remove(yard.drops,i)
  end
 end
 local automatic=session:AutomaticEnabled("AutoCollectEggs")
 if position or automatic then
  local near={}
  local radius=Config.EggMagnetRadius*(if session.entitlements and session.entitlements.EggMagnet==true then ShopCatalog.RadiusMultiplier else 1)
  for _,drop in yard.drops do
   if not drop.claimAt and now>=drop.readyAt then
    local distance=if position then (position-Vector3.new(drop.x,drop.y+0.8,drop.z)).Magnitude else 0
    if automatic or distance<=radius then table.insert(near,{drop=drop,distance=distance}) end
   end
  end
  table.sort(near,function(a,b)return a.distance<b.distance end)
  for i=1,math.min(Config.EggPickupBatch,#near) do
   near[i].drop.claimAt=now+(i-1)*0.06
   yard.revision+=1
  end
 end
 for i=#yard.receipts,1,-1 do if now-yard.receipts[i].at>3 then table.remove(yard.receipts,i) end end
end

function EggService:Step(sessions,dt,now)
 for _,session in sessions do
  if not session.loaded or session.closing or session.saveLost then continue end
  self:Produce(session,dt,now)
  local player=Players:GetPlayerByUserId(session.userId)
  local character=player and player.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  local humanoid=character and character:FindFirstChildOfClass("Humanoid")
  local position=if root and humanoid and humanoid.Health>0 then root.Position else nil
  self:Collect(session,position,now)
  self:Deposit(session,position,now)
 end
end

function EggService:Snapshot(session,now)
 local yard=self:Yard(session)
 local drops,receipts={},{}
 local value=0
 for _,drop in yard.drops do
  local copy=table.clone(drop)
  copy.value=session:EarnedAmount(drop.value,"eggs")
  copy.age=math.max(0,now-drop.born)
  copy.flightAge=if drop.claimAt then now-drop.claimAt else nil
  copy.born,copy.readyAt,copy.claimAt=nil,nil,nil
  table.insert(drops,copy);value+=copy.value
 end
 for _,receipt in yard.receipts do table.insert(receipts,{id=receipt.id,value=receipt.value,count=receipt.count}) end
 local deposit=if yard.deposit and now-yard.deposit.at<3 then {id=yard.deposit.id,value=yard.deposit.value,count=yard.deposit.count} else nil
 return {revision=yard.revision,generation=yard.generation,drops=drops,receipts=receipts,value=value,
  requiresDeposit=self.world:EggDeposit(session.plotIndex)~=nil,carriedCount=session.eggCarry.count,
  carriedValue=session:EarnedAmount(session.eggCarry.value,"eggs"),deposit=deposit}
end

function EggService:Release(session)
 local yard=self.yards[session.userId]
 if not yard then return end
 -- A proximity-claimed pickup is already earned even if the player leaves mid-flight.
 if not session.saveLost then for _,drop in yard.drops do
  if drop.claimAt then self:Pay(session,yard,drop,os.clock()) end
 end end
 self.yards[session.userId]=nil
end

function EggService:Destroy()
 table.clear(self.yards)
end
return EggService
