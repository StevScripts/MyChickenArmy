--!strict
-- Local pickup presentation and input. Range, egg value and payment remain on the server.
-- October 20 (docs/team/COLLECTION_TOOLS.md): click or tap an egg (gamepad: R2 grabs
-- the nearest, holding it keeps grabbing) and it flies to you at once while the server
-- confirms the claim (CollectEggs); a refused egg drops back. Eggs the held vacuum
-- pulls fly into its nozzle. Walking over eggs no longer collects them.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Feel=require(Shared.CollectionFeel)
local Tools=require(Shared.VacuumConfig)
local Motion=require(Shared.EggMotion)
local EggView=require(script.Parent.EggView)
local Feedback=require(script.Parent.EggFeedback)
local VacuumController=require(script.Parent.VacuumController)
local Theme=require(script.Parent.UITheme)
local Eggs={}
Eggs.__index=Eggs
-- Presentation-only budgets; collection distance and server timing stay in Config.
local CAPTION_DISTANCE,CAPTION_LIMIT,CAPTION_REFRESH=22,3,0.15
local POPUP_HOLD,POPUP_FADE,POPUP_LIFT=0.7,0.4,0.5
local POPUP_OFFSET=Vector3.new(0,3.7,0)
-- Picking: a direct hit on an egg wins; otherwise the egg drawn nearest the pointer
-- within this share of the screen height (taps get more room than the mouse).
local PICK_SHARE,PICK_MIN,TOUCH_PICK_SHARE,TOUCH_PICK_MIN=0.065,44,0.08,48
-- Hovering a clickable egg (the same pick a click uses) shows the hand cursor and
-- pops that egg out a little.
local HOVER_CURSOR="rbxasset://SystemCursors/PointingHand"
local HOVER_SCALE,HOVER_LIFT=0.18,0.18
local HOVER_IN=TweenInfo.new(0.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
local HOVER_OUT=TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
local TAP_SECONDS,TAP_PIXELS=0.35,14 -- Longer or farther touches are camera drags.
local CONFIRM_SECONDS=1.2 -- An unconfirmed click drops its egg back after this.
local GAMEPAD_REPEAT=0.2 -- Holding R2 grabs the next nearest egg this often.
local TOO_FAR_SECONDS=0.9
local VACUUM_RING=Color3.fromRGB(150,214,255)

function Eggs.new(app)
 return setmetatable({app=app,views={},feedback={},finishedFlights={},combo=0,lastPickup=0,
  totalCount=0,totalValue=0,popupTweens={},optimistic={},queue={},touches={},lastFlush=0,connections={},
  mousePoint=nil::Vector2?,hoverPop=Instance.new("NumberValue"),leavePop=Instance.new("NumberValue")},Eggs)
end

function Eggs:Root()
 local character=Players.LocalPlayer.Character
 return character and character:FindFirstChild("HumanoidRootPart")
end

function Eggs:Start()
 self.folder=Instance.new("Folder");self.folder.Name="PetRollEggVisuals";self.folder.Parent=workspace
 self.vacuum=VacuumController.new(self.app)
 self:CreateCollectionRange()
 self.popup=Instance.new("BillboardGui")
 self.popup.Name="EggPickup";self.popup.Size=UDim2.fromOffset(300,64)
 self.popup.StudsOffset=POPUP_OFFSET;self.popup.AlwaysOnTop=true
 self.popup.MaxDistance=65;self.popup.Enabled=false;self.popup.Parent=self.app.gui
 self.label=Theme.Label(self.popup,"Value","",30,Theme.Arcade.gold)
 self.label.Size=UDim2.new(1,0,0,34);self.label.TextXAlignment=Enum.TextXAlignment.Center
 self.label.TextWrapped=false
 self.worth=Theme.Label(self.popup,"Worth","",21)
 self.worth.Position,self.worth.Size=UDim2.fromOffset(0,34),UDim2.new(1,0,0,26)
 self.worth.TextXAlignment,self.worth.TextWrapped=Enum.TextXAlignment.Center,false
 -- One shared "Get closer" tag for an egg clicked outside Click Range.
 self.tooFar=Instance.new("BillboardGui")
 self.tooFar.Name="EggTooFar";self.tooFar.Size=UDim2.fromOffset(170,30);self.tooFar.StudsOffset=Vector3.new(0,1.7,0)
 self.tooFar.AlwaysOnTop=true;self.tooFar.LightInfluence=0;self.tooFar.MaxDistance=90
 self.tooFar.Active,self.tooFar.Enabled,self.tooFar.Parent=false,false,self.app.gui
 local tooFar=Theme.Label(self.tooFar,"Text","Get closer",22)
 tooFar.Size,tooFar.TextXAlignment,tooFar.TextWrapped=UDim2.fromScale(1,1),Enum.TextXAlignment.Center,false
 self.connection=RunService.RenderStepped:Connect(function() self:Step(os.clock()) end)
 self:BindInput()
end

function Eggs:BindInput()
 table.insert(self.connections,UserInputService.InputBegan:Connect(function(input,processed)
  if processed then return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 then
   self:Click(Vector2.new(input.Position.X,input.Position.Y),false)
  elseif input.UserInputType==Enum.UserInputType.Touch then
   self.touches[input]={at=os.clock(),x=input.Position.X,y=input.Position.Y}
   self.mousePoint=nil::Vector2? -- Touch has no hover.
  end
 end))
 table.insert(self.connections,UserInputService.InputChanged:Connect(function(input,processed)
  if input.UserInputType==Enum.UserInputType.MouseMovement then
   self.mousePoint=if processed then nil else Vector2.new(input.Position.X,input.Position.Y)
  end
 end))
 table.insert(self.connections,UserInputService.InputEnded:Connect(function(input,processed)
  local touch=self.touches[input]
  if not touch then return end
  self.touches[input]=nil
  local point=Vector2.new(input.Position.X,input.Position.Y)
  if not processed and os.clock()-touch.at<=TAP_SECONDS and (point-Vector2.new(touch.x,touch.y)).Magnitude<=TAP_PIXELS then
   self:Click(point,true)
  end
 end))
 ContextActionService:BindAction("PetRollCollectEggs",function(_,state)
  if state==Enum.UserInputState.Begin then
   self.gamepadHeld=true;self:GrabNearest(os.clock())
  elseif state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then
   self.gamepadHeld=false
  end
  return Enum.ContextActionResult.Pass
 end,false,Enum.KeyCode.ButtonR2)
end

function Eggs:CreateCollectionRange()
 local anchor=Instance.new("Part")
 anchor.Name="EggCollectionRange";anchor.Anchored=true;anchor.Transparency=1
 anchor.CanCollide,anchor.CanTouch,anchor.CanQuery,anchor.CastShadow=false,false,false,false
 anchor.Size=Vector3.new(20,0.02,20);anchor.Parent=self.folder
 -- A hollow, unlit adornment stays faint against grass without filling the center.
 local ring=Instance.new("CylinderHandleAdornment")
 ring.Name="EggCollectionCircle";ring.Adornee=anchor
 ring.Radius=Tools.ClickRange;ring.InnerRadius=Tools.ClickRange-0.35;ring.Height=0.025
 ring.CFrame=CFrame.Angles(math.pi/2,0,0);ring.Color3=Color3.new(1,1,1)
 ring.Transparency=1;ring.AlwaysOnTop=false;ring.Visible=false
 ring.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
 self.rangeAnchor,self.rangeRing=anchor,ring
 self.rangeAlpha,self.rangeAt=0,os.clock()
end

-- How far a click reaches (server value, with the Click Range tiers).
function Eggs:ClickRange()
 local snapshot=self.snapshot
 return if snapshot and type(snapshot.clickRange)=="number" then snapshot.clickRange else Tools.ClickRange
end

-- The ring shows Click Range, or the vacuum's reach while it is in hand.
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
   local vacuum=if self.vacuum:Equipped() and self.snapshot then self.snapshot.vacuum else nil
   local radius=if vacuum and type(vacuum.range)=="number" then vacuum.range else self:ClickRange()
   self.rangeAnchor.Size=Vector3.new(radius*2,0.02,radius*2)
   self.rangeRing.Radius=radius;self.rangeRing.InnerRadius=radius-0.35
   self.rangeRing.Color3=if vacuum then VACUUM_RING else Color3.new(1,1,1)
   self.rangeAnchor.CFrame=CFrame.new(root.Position.X,deck.Position.Y+deck.Size.Y/2+(if plot:GetAttribute("AuthoredPlot") then 0.26 else 0.10),root.Position.Z)
   self.rangeAnchor:SetAttribute("CollectionRadius",radius)
  end
 end
 if self.app.hud then self.app.hud.income.Visible=visible end
 local dt=math.clamp(now-(self.rangeAt or now),0,0.1);self.rangeAt=now
 local target=if visible then 1 else 0
 self.rangeAlpha=if self.app.reducedMotion then target else self.rangeAlpha+(target-self.rangeAlpha)*math.min(1,dt*12)
 self.rangeRing.Transparency=math.clamp(1-self.rangeAlpha*0.28,0,1)
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
 -- Vacuum pickups fill its meter (ToolController) instead of the popup over the player.
 if receipt and receipt.collector=="vacuum" then return end
 local root=self:Root()
 if not root then return end
 if now-self.lastPickup>Feel.Egg.ComboReset or self.popupDeposit~=self.requiresDeposit then
  self.totalCount,self.totalValue=0,0
 end
 self.totalCount+=count or 1;self.totalValue+=value
 self.lastPickup,self.popupDeposit=now,self.requiresDeposit
 if not self.popup.Enabled or self.popup.Adornee~=root then self.popup.StudsOffset=POPUP_OFFSET end
 self.popup.Adornee,self.popup.Enabled=root,true
 self.label.Text=if self.requiresDeposit then Feedback.Fit(self.totalCount,"+",if self.totalCount==1 then " egg" else " eggs",300,30,false)
  else Feedback.Fit(self.totalValue,"+","",300,30,true)
 self.worth.Text,self.worth.Visible=Feedback.Fit(self.totalValue,"Worth ","",300,21,true),self.requiresDeposit
 for _,label in {self.label,self.worth} do label.TextTransparency=0;label.TextOutline.Transparency=0 end
 self:AnimatePopup(now)
end

function Eggs:CancelPopupTweens()
 if self.popupDone then self.popupDone:Disconnect();self.popupDone=nil end
 for _,tween in self.popupTweens do tween:Cancel();tween:Destroy() end
 table.clear(self.popupTweens)
end

function Eggs:HidePopup()
 self:CancelPopupTweens()
 self.popup.Enabled=false
end

function Eggs:AnimatePopup(now)
 self:CancelPopupTweens()
 local since=now-self.lastPickup
 local remaining=POPUP_HOLD+POPUP_FADE-since
 if remaining<=0 then self.popup.Enabled=false;return end
 self.popupReduced=self.app.reducedMotion
 local function tween(target,info,properties)
  local animation=TweenService:Create(target,info,properties)
  table.insert(self.popupTweens,animation)
  return animation
 end
 if self.popupReduced then self.popup.StudsOffset=POPUP_OFFSET
 else tween(self.popup,TweenInfo.new(remaining,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
  {StudsOffset=POPUP_OFFSET+Vector3.new(0,POPUP_LIFT,0)}) end
 local fade=TweenInfo.new(math.min(POPUP_FADE,remaining),Enum.EasingStyle.Quad,Enum.EasingDirection.Out,
  0,false,math.max(0,POPUP_HOLD-since))
 local finish
 for _,label in {self.label,self.worth} do
  finish=tween(label,fade,{TextTransparency=1})
  tween(label.TextOutline,fade,{Transparency=1})
 end
 self.popupDone=finish.Completed:Connect(function(state)
  if state==Enum.PlaybackState.Completed then self:HidePopup() end
 end)
 for _,animation in self.popupTweens do animation:Play() end
end

function Eggs:PickupCue(collector,now)
 if collector=="vacuum" then self.vacuum:PickupCue(now);return end
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
 view.caption.Enabled=false
end

-- Menus, dialogue, a focused text box or a cutscene camera keep clicks for themselves.
function Eggs:Blocked(): boolean
 local app=self.app
 if not app.state or app.panel.Visible or app.dialogueActive==true then return true end
 if app.research and app.research.root and app.research.root.Visible then return true end
 if app.commerce and app.commerce.cratePresenting then return true end
 if UserInputService:GetFocusedTextBox() then return true end
 local camera=workspace.CurrentCamera
 return camera==nil or camera.CameraType==Enum.CameraType.Scriptable
end

function Eggs:Ready(view,now): boolean
 return not view.flightAt and now-view.bornAt>=Config.EggSettleSeconds
end

-- The egg under the pointer: the one the ray hits, else the one drawn nearest within
-- the pick radius. A hit on a chicken keeps its Army shortcut (BaseController).
function Eggs:PickAt(point: Vector2,touch: boolean,now: number)
 local camera=workspace.CurrentCamera
 if not camera then return nil end
 local ray=camera:ScreenPointToRay(point.X,point.Y)
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 local character=Players.LocalPlayer.Character
 params.FilterDescendantsInstances=if character then {character} else {}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*400,params)
 if hit then
  local part=hit.Instance
  if part:IsDescendantOf(self.folder) then
   local id=string.match(part.Name,"^Egg_(.+)$")
   local view=id and self.views[id]
   if view and self:Ready(view,now) then return view end
  else
   local model=part:FindFirstAncestorOfClass("Model")
   if model and model:GetAttribute("PetId") then return nil end
  end
 end
 local limit=math.max(if touch then TOUCH_PICK_MIN else PICK_MIN,camera.ViewportSize.Y*(if touch then TOUCH_PICK_SHARE else PICK_SHARE))
 local best,bestDistance=nil,limit
 for _,view in self.views do
  if self:Ready(view,now) then
   local screen,visible=camera:WorldToScreenPoint(view.ground)
   if visible then
    local distance=(Vector2.new(screen.X,screen.Y)-point).Magnitude
    if distance<bestDistance then best,bestDistance=view,distance end
   end
  end
 end
 return best
end

function Eggs:Click(point: Vector2,touch: boolean)
 local now=os.clock()
 if self:Blocked() then return end
 local view=self:PickAt(point,touch,now)
 if view then self:Grab(view,now) end
end

-- The egg under the mouse gets the hand cursor and pops out; one shared tween each
-- for the egg coming in and the egg going back (Step applies them to the egg size).
function Eggs:StepHover(now: number)
 local view=if self.mousePoint and not self:Blocked() then self:PickAt(self.mousePoint,false,now) else nil
 if view==self.hoverView then return end
 if self.hoverTween then self.hoverTween:Cancel() end
 if self.leaveTween then self.leaveTween:Cancel() end
 self.leaveView,self.leavePop.Value=self.hoverView,self.hoverPop.Value
 self.hoverView,self.hoverPop.Value=view,0
 if self.app.reducedMotion then
  self.leavePop.Value,self.hoverPop.Value=0,1
 else
  self.hoverTween=TweenService:Create(self.hoverPop,HOVER_IN,{Value=1});self.hoverTween:Play()
  self.leaveTween=TweenService:Create(self.leavePop,HOVER_OUT,{Value=0});self.leaveTween:Play()
 end
 UserInputService.MouseIcon=if view then HOVER_CURSOR else ""
end

function Eggs:HoverPop(view): number
 return if view==self.hoverView then self.hoverPop.Value elseif view==self.leaveView then self.leavePop.Value else 0
end

-- Gamepad: the nearest ready egg in Click Range.
function Eggs:GrabNearest(now: number)
 self.lastGamepadGrab=now
 if self:Blocked() then return end
 local root=self:Root()
 if not root then return end
 local best,bestDistance=nil,self:ClickRange()
 for _,view in self.views do
  if self:Ready(view,now) then
   local distance=Vector2.new(view.ground.X-root.Position.X,view.ground.Z-root.Position.Z).Magnitude
   if distance<=bestDistance then best,bestDistance=view,distance end
  end
 end
 if best then self:Grab(best,now) end
end

-- Flies the egg to the player now and asks the server for it with the next batch.
function Eggs:Grab(view,now: number): boolean
 local root=self:Root()
 if not root then return false end
 local at=view.ground
 if Vector2.new(at.X-root.Position.X,at.Z-root.Position.Z).Magnitude>self:ClickRange()
  or math.abs(at.Y-root.Position.Y)>Tools.MaxHeight then
  self:TooFar(view,now)
  return false
 end
 local id=view.data.id
 self.optimistic[id]=now
 table.insert(self.queue,id)
 view.picked=true
 view.data.collector="player"
 self:StartFlight(view,now)
 self:StepHover(now) -- The grabbed egg is no longer under the hand.
 return true
end

function Eggs:TooFar(view,now: number)
 if not self.app.reducedMotion then self.rangeAlpha=math.max(self.rangeAlpha,2.4) end
 self.tooFar.Adornee=view.anchor
 self.tooFar.Enabled=true
 self.tooFarUntil=now+TOO_FAR_SECONDS
end

function Eggs:Flush(now: number)
 if #self.queue==0 or now-self.lastFlush<Tools.ClickRequestSeconds then return end
 self.lastFlush=now
 local ids={}
 while #self.queue>0 and #ids<Tools.ClickBatch do table.insert(ids,table.remove(self.queue,1)) end
 self.app:Request("CollectEggs",{ids=ids})
end

function Eggs:Receive(snapshot)
 if not snapshot or not self.folder then return end
 local now=os.clock()
 self.batchFlights=0
 self.snapshot=snapshot
 self.requiresDeposit=snapshot.requiresDeposit==true
 if self.generation~=snapshot.generation then
  for _,view in self.views do view:Destroy() end
  table.clear(self.views);table.clear(self.feedback);table.clear(self.finishedFlights)
  table.clear(self.optimistic);table.clear(self.queue)
  self.generation=snapshot.generation;self:HidePopup();self.totalCount,self.totalValue=0,0;self.lastPickup=0
  self.nextCaptionAt=nil;self.popupDeposit=nil
  self.seenDeposits={};self.lastCashClaim=nil;self.combo=0;self.lastCue=nil
  self.app.feedback:ResetCollections()
 end
 local seenDeposits={}
 for _,deposit in snapshot.deposits or (if snapshot.deposit then {snapshot.deposit} else {}) do
  if not (self.seenDeposits and self.seenDeposits[deposit.id]) then self.app.feedback:Deposit(deposit) end
  seenDeposits[deposit.id]=true
 end
 self.seenDeposits=seenDeposits
 if snapshot.cashClaim and snapshot.cashClaim.id~=self.lastCashClaim then
  self.lastCashClaim=snapshot.cashClaim.id
  self.app.feedback:CashReward(snapshot.cashClaim)
 end
 -- Clicked eggs: a claim or payment confirms them; one the server never claimed
 -- (out of reach, already taken) drops back onto the ground.
 local present={}
 for _,data in snapshot.drops or {} do present[data.id]=data end
 for id,at in self.optimistic do
  local data=present[id]
  if not data or data.flightAge~=nil then
   self.optimistic[id]=nil
  elseif now-at>CONFIRM_SECONDS then
   self.optimistic[id]=nil;self.finishedFlights[id]=nil;self.feedback[id]=nil
   local view=self.views[id]
   if view then view:Destroy();self.views[id]=nil end
  end
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
   view.data=data;view:SetValue(data.value,data.stack)
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

function Eggs:StepCaptions(root,camera,now)
 if root and camera and now<(self.nextCaptionAt or 0) then return end
 self.nextCaptionAt=now+CAPTION_REFRESH
 local nearest={}
 for _,view in self.views do
  view.caption.Enabled=false
  if not root or not camera or view.flightAt or now-view.bornAt<Config.EggSettleSeconds then continue end
  local distance=(root.Position-view.ground).Magnitude
  if distance>CAPTION_DISTANCE then continue end
  local point,onScreen=camera:WorldToViewportPoint(view.ground+view.caption.StudsOffset)
  if onScreen then table.insert(nearest,{view=view,distance=distance,point=point}) end
 end
 table.sort(nearest,function(a,b)
  return if a.distance==b.distance then a.view.seed<b.view.seed else a.distance<b.distance
 end)
 local shown={}
 for _,candidate in nearest do
  local overlap=false
  for _,point in shown do
   if math.abs(point.X-candidate.point.X)<164 and math.abs(point.Y-candidate.point.Y)<34 then overlap=true;break end
  end
  if not overlap then
   candidate.view.caption.Enabled=true;table.insert(shown,candidate.point)
   if #shown>=CAPTION_LIMIT then break end
  end
 end
end

function Eggs:Step(now)
 local root=self:Root()
 self:StepCollectionRange(root,now)
 if self.gamepadHeld and now-(self.lastGamepadGrab or 0)>=GAMEPAD_REPEAT then self:GrabNearest(now) end
 self:Flush(now)
 self:StepHover(now)
 if self.tooFar.Enabled and (now>=(self.tooFarUntil or 0) or not self.tooFar.Adornee or not self.tooFar.Adornee.Parent) then
  self.tooFar.Enabled=false;self.tooFar.Adornee=nil
 end
 local camera=workspace.CurrentCamera
 self:StepCaptions(root,camera,now)
 for id,view in self.views do
  local age=now-view.bornAt
  if not view.flightAt and age>=Config.EggSettleSeconds and camera
   and (camera.CFrame.Position-view.ground).Magnitude>Config.EggSpriteMaxDistance then continue end
  local size=1+math.min(0.3,math.log(math.max(1,view.data.stack),2)*0.07)
  if view.flightAt then
   local t=math.clamp((now-view.flightAt)/Feel.Egg.FlightSeconds,0,1)
   local vacuum=view.data.collector=="vacuum"
   -- Vacuum pickups fly into the held nozzle; if it was put away, to the server's
   -- landing point. Clicked eggs follow the player.
   local goal=if vacuum then (self.vacuum:NozzlePosition()
     or (if view.data.targetX then Vector3.new(view.data.targetX,view.data.targetY,view.data.targetZ) else nil)
     or (if root then root.Position else view.ground))
    elseif root then root.Position+Vector3.new(0,-0.25,0) else view.ground
   local dt=math.clamp(now-(view.lastStep or now),0,0.1);view.lastStep=now
   local interrupted=not vacuum and not root or view.goal and (goal-view.goal).Magnitude>Feel.Egg.TeleportDistance
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
    if view.receipt then self:Feedback(id,view.receipt.value,view.receipt.count,view.receipt)
    elseif view.picked then
     -- A clicked egg counts in as it lands; the server's receipt later is the same egg.
     self:Feedback(id,view.data.value,view.data.stack,{collector="player"})
    end
    view:Destroy();self.views[id]=nil
   end
  elseif age<Config.EggSettleSeconds and not self.app.reducedMotion then
   local t=math.clamp(age/Config.EggSettleSeconds,0,1)
   local position=view.origin:Lerp(view.ground,t)+Vector3.new(0,math.sin(t*math.pi)*1.8,0)
   view:Set(position,size*(1+math.sin(t*math.pi)*0.08),math.sin(t*math.pi)*0.35,view.seed)
  else
   local bob=if self.app.reducedMotion then 0 else math.sin(age*2.6+view.seed)*0.07
   local pop:number=self:HoverPop(view)
   view:Set(view.ground+Vector3.new(0,bob+pop*HOVER_LIFT,0),size*(1+pop*HOVER_SCALE),0,view.seed)
  end
 end
 if self.popup.Enabled then
  if not root or self.popup.Adornee~=root then
   self:HidePopup();self.totalCount,self.totalValue=0,0;self.lastPickup=0
  elseif self.popupReduced~=self.app.reducedMotion then self:AnimatePopup(now) end
 end
 for id,at in self.feedback do if now-at>10 then self.feedback[id]=nil end end
 for id,at in self.finishedFlights do if now-at>10 then self.finishedFlights[id]=nil end end
end

function Eggs:Destroy()
 if self.connection then self.connection:Disconnect() end
 for _,connection in self.connections do connection:Disconnect() end
 table.clear(self.connections)
 ContextActionService:UnbindAction("PetRollCollectEggs")
 self:CancelPopupTweens()
 if self.hoverTween then self.hoverTween:Cancel() end
 if self.leaveTween then self.leaveTween:Cancel() end
 self.hoverPop:Destroy();self.leavePop:Destroy()
 if self.hoverView then UserInputService.MouseIcon="" end
 for _,view in self.views do view:Destroy() end
 table.clear(self.views)
 if self.rangeRing then self.rangeRing:Destroy() end
 if self.folder then self.folder:Destroy() end
 if self.popup then self.popup:Destroy() end
 if self.tooFar then self.tooFar:Destroy() end
 if self.sparkAttachment then self.sparkAttachment:Destroy() end
end
return Eggs
