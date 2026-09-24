--!strict
-- Local pickup presentation. Proximity, egg value and payment remain on the server.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Feel=require(Shared.CollectionFeel)
local ShopCatalog=require(Shared.ShopCatalog)
local Motion=require(Shared.EggMotion)
local EggView=require(script.Parent.EggView)
local VacuumController=require(script.Parent.VacuumController)
local Theme=require(script.Parent.UITheme)
local Eggs={}
Eggs.__index=Eggs

function Eggs.new(app)
 return setmetatable({app=app,views={},feedback={},finishedFlights={},combo=0,lastPickup=0,total=0},Eggs)
end

function Eggs:Root()
 local character=Players.LocalPlayer.Character
 return character and character:FindFirstChild("HumanoidRootPart")
end

function Eggs:Start()
 self.folder=Instance.new("Folder");self.folder.Name="PetRollEggVisuals";self.folder.Parent=workspace
 self.vacuum=VacuumController.new(self.app,self.folder)
 self:CreateCollectionRange()
 self.popup=Instance.new("BillboardGui")
 self.popup.Name="EggPickup";self.popup.Size=UDim2.fromOffset(230,52)
 self.popup.StudsOffset=Vector3.new(0,3.7,0);self.popup.AlwaysOnTop=true
 self.popup.MaxDistance=65;self.popup.Enabled=false;self.popup.Parent=self.app.gui
 self.label=Theme.Label(self.popup,"Value","",30,Theme.Arcade.gold)
 self.label.Size=UDim2.fromScale(1,1);self.label.TextXAlignment=Enum.TextXAlignment.Center
 self.connection=RunService.RenderStepped:Connect(function() self:Step(os.clock()) end)
end

function Eggs:CreateCollectionRange()
 local anchor=Instance.new("Part")
 anchor.Name="EggCollectionRange";anchor.Anchored=true;anchor.Transparency=1
 anchor.CanCollide,anchor.CanTouch,anchor.CanQuery,anchor.CastShadow=false,false,false,false
 anchor.Size=Vector3.new(20,0.02,20);anchor.Parent=self.folder
 -- A hollow, unlit adornment stays faint against grass without filling the center.
 local ring=Instance.new("CylinderHandleAdornment")
 ring.Name="EggCollectionCircle";ring.Adornee=anchor
 ring.Radius=Config.EggMagnetRadius;ring.InnerRadius=Config.EggMagnetRadius-0.35;ring.Height=0.025
 ring.CFrame=CFrame.Angles(math.pi/2,0,0);ring.Color3=Color3.new(1,1,1)
 ring.Transparency=1;ring.AlwaysOnTop=false;ring.Visible=false
 ring.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
 self.rangeAnchor,self.rangeRing=anchor,ring
 self.rangeAlpha,self.rangeAt=0,os.clock()
end

function Eggs:StepCollectionRange(root,now)
 if not self.rangeAnchor then return end
 local state=self.app.state
 local world=workspace:FindFirstChild("PetRollWorld")
 local plot=state and state.plotIndex and world and world:FindFirstChild("Plot"..state.plotIndex)
 local deck=plot and plot:FindFirstChild("Deck")
 local humanoid=root and root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
 local visible=false
 if root and humanoid and humanoid.Health>0 and deck and deck:IsA("BasePart") then
  local at=deck.CFrame:PointToObjectSpace(root.Position)
  visible=math.abs(at.X)<=deck.Size.X/2 and math.abs(at.Z)<=deck.Size.Z/2 and math.abs(at.Y)<12
  if visible then
   local owned=state.shop and state.shop.owned
   local radius=Config.EggMagnetRadius*(if owned and owned.EggMagnet==true then ShopCatalog.RadiusMultiplier else 1)
   self.rangeAnchor.Size=Vector3.new(radius*2,0.02,radius*2)
   self.rangeRing.Radius=radius;self.rangeRing.InnerRadius=radius-0.35
   self.rangeAnchor.CFrame=CFrame.new(root.Position.X,deck.Position.Y+deck.Size.Y/2+(if plot:GetAttribute("AuthoredPlot") then 0.26 else 0.10),root.Position.Z)
   self.rangeAnchor:SetAttribute("CollectionRadius",radius)
  end
 end
 if self.app.hud then self.app.hud.income.Visible=visible end
 local dt=math.clamp(now-(self.rangeAt or now),0,0.1);self.rangeAt=now
 local target=if visible then 1 else 0
 self.rangeAlpha=if self.app.reducedMotion then target else self.rangeAlpha+(target-self.rangeAlpha)*math.min(1,dt*12)
 self.rangeRing.Transparency=1-self.rangeAlpha*0.28
 self.rangeRing.Visible=self.rangeAlpha>0.01
end

function Eggs:Spark(root)
 if self.sparkAttachment and self.sparkAttachment.Parent~=root then
  self.sparkAttachment:Destroy();self.sparkAttachment=nil
 end
 if not self.sparkAttachment then
  local attachment=Instance.new("Attachment");attachment.Name="EggPickupSpark";attachment.Parent=root
  local spark=Instance.new("ParticleEmitter")
  spark.Texture="rbxasset://textures/particles/sparkles_main.dds"
  spark.Color=ColorSequence.new(Color3.fromRGB(255,222,65),Color3.new(1,1,1))
  spark.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.38),NumberSequenceKeypoint.new(1,0)})
  spark.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})
  spark.Lifetime=NumberRange.new(0.22,0.38);spark.Speed=NumberRange.new(3,6)
  spark.SpreadAngle=Vector2.new(180,180);spark.Rate=0;spark.LightEmission=0.7;spark.Parent=attachment
  self.sparkAttachment,self.spark=attachment,spark
 end
 self.spark:Emit(4)
end

function Eggs:Feedback(id,value,count,receipt)
 if self.feedback[id] then return end
 local now=os.clock();self.feedback[id]=now
 if not self.finishedFlights[id] then self:PickupCue(receipt and receipt.collector,now) end
 if receipt and receipt.collector=="rover" then
  self.vacuum:Pickup(receipt,now)
  return
 end
 if now-self.lastPickup>Feel.Egg.ComboReset then self.total=0 end
 self.total+=if self.requiresDeposit then count or 1 else value;self.lastPickup=now
 local root=self:Root()
 if root then
  self.popup.Adornee=root;self.popup.Enabled=true
  self.label.Text=if self.requiresDeposit then "+"..Theme.Money(self.total).." eggs" else "+$"..Theme.Money(self.total)
 end
end

function Eggs:PickupCue(collector,now)
 if collector=="rover" then self.vacuum:PickupCue(now);return end
 if now-(self.lastCue or -10)<Feel.Egg.SoundGap then return end
 if now-(self.lastCue or -10)>Feel.Egg.ComboReset then self.combo=0 end
 self.lastCue=now;self.combo=self.combo%#Feel.Egg.Pitches+1
 self.app.audio:Play("EggPickup",Feel.Egg.Pitches[self.combo],{volume=Feel.Egg.Volume,
  maxDuration=Feel.Egg.SoundTail,voiceKey="EggPickup",maxVoices=Feel.Egg.MaxVoices,cooldown=Feel.Egg.SoundGap})
 local root=self:Root()
 if root and not self.app.reducedMotion and now-(self.lastSpark or -10)>=Feel.Egg.SparkGap then
  self.lastSpark=now;self:Spark(root)
 end
 if self.app.hud then Theme.Motion:Pulse(if self.requiresDeposit then self.app.hud.income else self.app.hud.cashIcon,Feel.Egg.HudPulse) end
end

function Eggs:StartFlight(view,now)
 -- Packets may already be settled. Start from the currently rendered position.
 local stagger=math.min((self.batchFlights or 0)*Feel.Egg.Stagger,Feel.Egg.MaxStartWindow)
 self.batchFlights=(self.batchFlights or 0)+1
 view.flightAt=now+stagger;view.flightStart=view.position
 view.lastStep=now;view.trail.Enabled=false
end

function Eggs:Receive(snapshot)
 if not snapshot or not self.folder then return end
 local now=os.clock()
 self.batchFlights=0
 self.requiresDeposit=snapshot.requiresDeposit==true
 if self.generation~=snapshot.generation then
  for _,view in self.views do view:Destroy() end
  table.clear(self.views);table.clear(self.feedback);table.clear(self.finishedFlights)
  self.generation=snapshot.generation;self.popup.Enabled=false;self.total=0;self.lastPickup=0
  self.lastDeposit=nil;self.lastCashClaim=nil;self.combo=0;self.lastCue=nil
  self.app.feedback:ResetCollections()
  self.vacuum:Clear()
 end
 self.vacuum:Receive(snapshot.rover,now)
 if snapshot.deposit and snapshot.deposit.id~=self.lastDeposit then
  self.lastDeposit=snapshot.deposit.id
  if snapshot.deposit.collector=="rover" then self.vacuum:Deposit(snapshot.deposit,now) end
  self.app.feedback:Deposit(snapshot.deposit)
 end
 if snapshot.cashClaim and snapshot.cashClaim.id~=self.lastCashClaim then
  self.lastCashClaim=snapshot.cashClaim.id
  self.app.feedback:CashReward(snapshot.cashClaim)
 end
 local seen={}
 for _,data in snapshot.drops or {} do
  seen[data.id]=true
  local view=self.views[data.id]
  if not view and not self.feedback[data.id] and not self.finishedFlights[data.id] then
   view=EggView.new(self.folder,data);self.views[data.id]=view
   view.bornAt=now-(data.age or 0)
   view.ground=Vector3.new(data.x,data.y+0.8,data.z)
   view.origin=Vector3.new(data.originX,data.originY,data.originZ)
   view:Set(view.ground,1,0,view.seed)
   local root=self:Root()
   if (data.age or 0)<0.3 and root and (root.Position-view.ground).Magnitude<35 then
    self.app.audio:Play("Pop",1.15+(view.seed%3)*0.05,{volume=0.12,parent=view.shell,maxDuration=0.4,voiceKey="EggLay",cooldown=0.2})
   end
  end
  if view then
   view.data=data;view:SetValue(data.value)
   if data.flightAge~=nil and not view.flightAt then
    self:StartFlight(view,now)
   end
  end
 end
 for _,receipt in snapshot.receipts or {} do
  local view=self.views[receipt.id]
  if view then
   -- A late packet may skip the claim snapshot; still show its short pickup flight.
   view.data.value=receipt.value
   view.data.stack=receipt.count or view.data.stack
   view.data.collector=receipt.collector or view.data.collector
   view.data.targetX=receipt.targetX or view.data.targetX
   view.data.targetY=receipt.targetY or view.data.targetY
   view.data.targetZ=receipt.targetZ or view.data.targetZ
   view.receipt=receipt
   if not view.flightAt then self:StartFlight(view,now) end
  else self:Feedback(receipt.id,receipt.value,receipt.count,receipt) end
 end
 for id,view in self.views do
  if not seen[id] and not view.flightAt then view:Destroy();self.views[id]=nil end
 end
end

function Eggs:Step(now)
 local root=self:Root()
 self.vacuum:Step(now)
 self:StepCollectionRange(root,now)
 local camera=workspace.CurrentCamera
 for id,view in self.views do
  local age=now-view.bornAt
  if not view.flightAt and age>=Config.EggSettleSeconds and camera
   and (camera.CFrame.Position-view.ground).Magnitude>Config.EggSpriteMaxDistance then continue end
  local size=1+math.min(0.3,math.log(math.max(1,view.data.stack),2)*0.07)
  if view.flightAt then
   local t=math.clamp((now-view.flightAt)/Feel.Egg.FlightSeconds,0,1)
   local rover=view.data.collector=="rover"
   -- Auto Collect targets the physical nozzle, even while the owner is away.
   -- Fallback coordinates preserve an in-flight pickup if the rover is disabled.
   local goal=if rover then self.vacuum:NozzlePosition(view.data) or view.ground
    elseif root then root.Position+Vector3.new(0,-0.25,0) else view.ground
   local dt=math.clamp(now-(view.lastStep or now),0,0.1);view.lastStep=now
   local interrupted=not rover and not root or view.goal and (goal-view.goal).Magnitude>Feel.Egg.TeleportDistance
   view.goal=if not view.goal then goal else view.goal:Lerp(goal,1-math.exp(-Feel.Egg.TargetResponse*dt))
   if interrupted then t=1 end
   local position=Motion.Flight(view.flightStart,view.goal,t,view.seed,self.app.reducedMotion)
   view.trail.Enabled=not self.app.reducedMotion and t>0
   local shrink=1-math.clamp((t-0.8)/0.2,0,1)*0.85
   local lift=if self.app.reducedMotion then 1 else 1+math.sin(math.min(t*4,1)*math.pi)*0.12
   view:Set(position,size*shrink*lift,if self.app.reducedMotion then 0 else math.sin(t*math.pi)*0.24,view.seed)
   if t>=1 then
    self.finishedFlights[id]=now
    if not interrupted then self:PickupCue(view.data.collector,now) end
    if view.receipt then self:Feedback(id,view.receipt.value,view.receipt.count,view.receipt) end
    view:Destroy();self.views[id]=nil
   end
  elseif age<Config.EggSettleSeconds and not self.app.reducedMotion then
   local t=math.clamp(age/Config.EggSettleSeconds,0,1)
   local position=view.origin:Lerp(view.ground,t)+Vector3.new(0,math.sin(t*math.pi)*1.8,0)
   view:Set(position,size*(1+math.sin(t*math.pi)*0.08),math.sin(t*math.pi)*0.35,view.seed)
  else
   local bob=if self.app.reducedMotion then 0 else math.sin(age*2.6+view.seed)*0.07
   view:Set(view.ground+Vector3.new(0,bob,0),size,0,view.seed)
  end
 end
 local since=now-self.lastPickup
 if self.popup.Enabled then
  self.popup.Enabled=since<1.1 and root~=nil
  self.popup.StudsOffset=Vector3.new(0,3.7+math.min(since,1)*0.5,0)
  self.label.TextTransparency=math.clamp((since-0.65)/0.45,0,1)
  self.label.TextOutline.Transparency=self.label.TextTransparency
 end
 for id,at in self.feedback do if now-at>10 then self.feedback[id]=nil end end
 for id,at in self.finishedFlights do if now-at>10 then self.finishedFlights[id]=nil end end
end

function Eggs:Destroy()
 if self.connection then self.connection:Disconnect() end
 if self.vacuum then self.vacuum:Destroy() end
 for _,view in self.views do view:Destroy() end
 table.clear(self.views)
 if self.rangeRing then self.rangeRing:Destroy() end
 if self.folder then self.folder:Destroy() end
 if self.popup then self.popup:Destroy() end
 if self.sparkAttachment then self.sparkAttachment:Destroy() end
end
return Eggs
