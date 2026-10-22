--!strict
-- Local pickup presentation and input. Range, egg value and payment remain on the server.
-- October 20 (docs/team/COLLECTION_TOOLS.md): click or tap an egg (gamepad: R2 grabs
-- the nearest, holding it keeps grabbing) and it flies to you at once while the server
-- confirms the claim (CollectEggs); a refused egg drops back. Eggs the held vacuum
-- pulls fly into its nozzle. Walking over eggs no longer collects them.
-- October 21 game feel (docs/team/GAME_FEEL_20261021.md): a laid egg plops and grows
-- in with a puff at the chicken, a picked egg sparkles where it was, and the held
-- vacuum hums and shimmers while eggs are in reach. Budgets in CollectionFeel.Feel.
-- October 21 reference parity (P6, docs/team/REFERENCE_PARITY_20261021.md 2.6): every
-- egg that reaches you or the vacuum plays one short bright chime, rising in pitch
-- across a streak, and floats its own "+N" coin value over you (the server's value for
-- that egg; never computed here). This replaces the old "+N eggs · Worth" popup.
-- Holding the left mouse button keeps grabbing the egg under the pointer (like R2), so
-- the vacuum pill's "Collect (Hold)" line is true on every input.
local Players=game:GetService("Players")
local ContentProvider=game:GetService("ContentProvider")
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
local VacuumController=require(script.Parent.VacuumController)
local AutoVacuumController=require(script.Parent.AutoVacuumController)
local Theme=require(script.Parent.UITheme)
local Eggs={}
Eggs.__index=Eggs
-- Presentation-only budgets; collection distance and server timing stay in Config.
local CAPTION_DISTANCE,CAPTION_LIMIT,CAPTION_REFRESH=22,3,0.15
-- Picking: a direct hit on an egg wins; otherwise the egg drawn nearest the pointer
-- within this share of the screen height (taps get more room than the mouse).
local PICK_SHARE,PICK_MIN,TOUCH_PICK_SHARE,TOUCH_PICK_MIN=0.065,44,0.08,48
-- Hovering a clickable egg (the same pick a click uses) shows the hand cursor and
-- pops that egg out a little. The game can't load rbxasset://SystemCursors, so the hand
-- is our own image (assets/egg-hover-cursor-20261021); Roblox centres a cursor image on
-- the pointer, so its fingertip sits at the image centre.
local HOVER_CURSOR="rbxassetid://74062853444480"
local HOVER_SCALE,HOVER_LIFT=0.18,0.18
local HOVER_IN=TweenInfo.new(0.18,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
local HOVER_OUT=TweenInfo.new(0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
local TAP_SECONDS,TAP_PIXELS=0.35,14 -- Longer or farther touches are camera drags.
local CONFIRM_SECONDS=1.2 -- An unconfirmed click drops its egg back after this.
local GAMEPAD_REPEAT=0.2 -- Holding R2 grabs the next nearest egg this often.
local TOO_FAR_SECONDS=0.9
local VACUUM_RING=Color3.fromRGB(150,214,255)
-- October 21 tutorial (Stevin, like Drop a Fruit's "Tap your fruits" step): during the
-- guide's egg lesson the egg to click glows and the hand cursor taps it.
local HINT_GOLD=Color3.fromRGB(255,214,64)
local HINT_TAP=TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,-1,true)
local HINT_RIPPLE=TweenInfo.new(0.8,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,-1)
-- Back-out ease for the lay pop, computed in Step (VOXEL_EGGS.md: no per-egg tweens).
local function backOut(t:number):number
 local c1,c3=1.70158,2.70158
 local s=t-1
 return 1+c3*s*s*s+c1*s*s
end

function Eggs.new(app)
 return setmetatable({app=app,views={},feedback={},finishedFlights={},streak=0,floatPending=0,
  optimistic={},queue={},touches={},lastFlush=0,connections={},
  mousePoint=nil::Vector2?,hoverPop=Instance.new("NumberValue"),leavePop=Instance.new("NumberValue")},Eggs)
end

function Eggs:Root()
 local character=Players.LocalPlayer.Character
 return character and character:FindFirstChild("HumanoidRootPart")
end

function Eggs:Start()
 self.folder=Instance.new("Folder");self.folder.Name="PetRollEggVisuals";self.folder.Parent=workspace
 self.vacuum=VacuumController.new(self.app)
 -- October 21 Auto Vacuum robot (docs/team/AUTO_VACUUM.md).
 self.rover=AutoVacuumController.new(self.app,self.folder)
 self:CreateCollectionRange()
 -- One shared "Get closer" tag for an egg clicked outside Click Range.
 self.tooFar=Instance.new("BillboardGui")
 self.tooFar.Name="EggTooFar";self.tooFar.Size=UDim2.fromOffset(170,30);self.tooFar.StudsOffset=Vector3.new(0,1.7,0)
 self.tooFar.AlwaysOnTop=true;self.tooFar.LightInfluence=0;self.tooFar.MaxDistance=90
 self.tooFar.Active,self.tooFar.Enabled,self.tooFar.Parent=false,false,self.app.gui
 local tooFar=Theme.Label(self.tooFar,"Text","Get closer",22)
 tooFar.Size,tooFar.TextXAlignment,tooFar.TextWrapped=UDim2.fromScale(1,1),Enum.TextXAlignment.Center,false
 self.connection=RunService.RenderStepped:Connect(function() self:Step(os.clock()) end)
 task.spawn(function() -- Load the hand now so the first hover doesn't flash a blank cursor.
  local probe=Instance.new("ImageLabel");probe.Image=HOVER_CURSOR
  pcall(function() ContentProvider:PreloadAsync({probe}) end)
  probe:Destroy()
 end)
 self:BindInput()
end

function Eggs:BindInput()
 table.insert(self.connections,UserInputService.InputBegan:Connect(function(input,processed)
  if processed then return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 then
   local point=Vector2.new(input.Position.X,input.Position.Y)
   -- Holding keeps grabbing whatever egg the pointer sweeps over (Step).
   self.mousePoint=point::Vector2?
   self.mouseHeld,self.lastMouseGrab=true,os.clock()
   self:Click(point,false)
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
 table.insert(self.connections,UserInputService.WindowFocusReleased:Connect(function() self.mouseHeld=false end))
 table.insert(self.connections,UserInputService.InputEnded:Connect(function(input,processed)
  if input.UserInputType==Enum.UserInputType.MouseButton1 then self.mouseHeld=false;return end
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
 local dt=math.clamp(now-(self.rangeAt or now),0,0.1);self.rangeAt=now
 local target=if visible then 1 else 0
 self.rangeAlpha=if self.app.reducedMotion then target else self.rangeAlpha+(target-self.rangeAlpha)*math.min(1,dt*12)
 self.rangeRing.Transparency=math.clamp(1-self.rangeAlpha*0.28,0,1)
 self.rangeRing.Visible=self.rangeAlpha>0.01
end

-- Server receipts confirm an egg once. The chime and float play when the egg lands
-- (Step); a receipt for an egg whose flight was never drawn plays them here.
function Eggs:Feedback(id,value,receipt)
 if self.feedback[id] then return end
 local now=os.clock();self.feedback[id]=now
 if self.finishedFlights[id] then return end
 -- The robot's eggs pay when it sells them: its own tick, no "+N" over the player.
 if receipt and receipt.collector=="rover" then self.rover:PickupCue(now);return end
 self:Arrive(value,now,receipt and receipt.collector)
end

-- One egg reached you or the vacuum: one bright chime and its own "+N" coin float.
-- Clicked eggs also pulse the HUD's "Carrying" line; the vacuum's pill counts its own.
function Eggs:Arrive(value,now,collector)
 self:Chime(now)
 if type(value)=="number" and value>0 then
  local pending:number=self.floatPending
  self.floatPending=pending+value
 end
 self:FlushFloat(now)
end

-- The reference's cascade: a short bright tick per egg, pitch rising from ChimePitch[1]
-- by ChimeStep a chime up to ChimePitch[2], never closer than ChimeGap, and a streak
-- restarts after StreakReset without an egg. ChimeCue, else ChimeFallback, else silent.
function Eggs:Chime(now)
 local knobs=Feel.Feel
 if now-(self.lastArrival or -10)>knobs.StreakReset then self.streak=0 end
 self.lastArrival=now
 if now-(self.lastChime or -10)<knobs.ChimeGap then return end
 self.lastChime=now
 local pitch=math.min(knobs.ChimePitch[2],knobs.ChimePitch[1]+self.streak*knobs.ChimeStep)
 self.streak+=1
 self.app:Cue(knobs.ChimeCue,knobs.ChimeFallback,pitch,{volume=knobs.ChimeVolume,maxDuration=knobs.ChimeTail,
  voiceKey="EggChime",cooldown=knobs.ChimeGap,maxVoices=knobs.ChimeVoices})
end

-- "+N" with the coin over you, at most one per FloatGap (FloatGapTouch on phones):
-- eggs that land in between join the next float, so every egg's value shows. Values
-- are the server's per-egg Coins; this only adds them up. WorldFeel budgets the
-- floats and keeps them (without the rise) under reduced motion.
function Eggs:FlushFloat(now)
 local pending:number=self.floatPending
 if pending<=0 then return end
 local knobs=Feel.Feel
 local touch=UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
 if now-(self.lastFloat or -10)<(if touch then knobs.FloatGapTouch else knobs.FloatGap) then return end
 local feel,found,camera=self.app.worldFeel,self:Root(),workspace.CurrentCamera
 local root:BasePart?=if found and found:IsA("BasePart") then found else nil
 self.floatPending=0
 if not feel or not root then return end
 self.lastFloat=now
 local side=if camera then camera.CFrame.RightVector*Vector3.new(1,0,1) else Vector3.zero
 if side.Magnitude>0.01 then side=side.Unit end
 local at=root.Position+Vector3.new(0,knobs.FloatUp+math.random()*0.5,0)
  +side*(knobs.FloatSide[1]+math.random()*(knobs.FloatSide[2]-knobs.FloatSide[1]))
 feel:Text(at,"+"..Theme.Number(pending),{coin=true,size=knobs.FloatSize,seconds=knobs.FloatSeconds,rise=knobs.FloatRise,range=90})
end

-- A chicken just laid: a soft "EggLay" plop (else a quiet Pop) at the egg and a tiny
-- puff where it left the chicken, at most one per LaySoundGap across the whole yard.
-- The egg's own grow-in rides the settle curve in Step.
function Eggs:LayCue(view,now)
 if now-(self.lastLay or -10)<Feel.Feel.LaySoundGap then return end
 self.lastLay=now
 local audio=self.app.audio
 if audio:Has("EggLay") then
  audio:Play("EggLay",nil,{parent=view.shell,maxDuration=0.6,voiceKey="EggLay",cooldown=Feel.Feel.LaySoundGap,pitchVariance=0.08})
 else
  audio:Play("Pop",1.15,{volume=0.12,parent=view.shell,maxDuration=0.4,voiceKey="EggLay",cooldown=Feel.Feel.LaySoundGap,pitchVariance=0.08})
 end
 local feel=self.app.worldFeel
 if feel then feel:Poof(view.origin+Vector3.new(0,0.4,0),{count=Feel.Feel.LayPoof.Count,size=Feel.Feel.LayPoof.Size,range=Feel.Feel.LayRange}) end
end

-- A small sparkle where an egg was just picked (click, tap, R2 or the vacuum),
-- budgeted so a vacuum pulling eight stacks a step shows a few, not a storm.
function Eggs:PickBurst(position,now)
 local feel=self.app.worldFeel
 if not feel or now-(self.lastPickBurst or -10)<Feel.Feel.PickBurstGap then return end
 self.lastPickBurst=now
 feel:Burst(position,{color=Theme.Arcade.gold,count=Feel.Feel.PickBurst.Count,size=Feel.Feel.PickBurst.Size,
  speed={2,5},lifetime={0.25,0.5},light=0.7,range=60})
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

function Eggs:Click(point: Vector2,touch: boolean,quiet: boolean?)
 local now=os.clock()
 if self:Blocked() then return end
 local view=self:PickAt(point,touch,now)
 if view then self:Grab(view,now,quiet) end
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

-- The CommanderGuide turns the egg hint on for its Collect lesson. `word` is the
-- player's own input ("CLICK!" or "TAP!"); one layout everywhere.
function Eggs:SetGuideHint(on: boolean, word: string?)
 self.guideHint=on
 if word and self.hintWord then self.hintWord.Text=word end
 if not on then self:HideGuideHint() end
end

function Eggs:BuildGuideHint()
 local highlight=Instance.new("Highlight")
 highlight.Name="GuideEggHighlight";highlight.FillColor,highlight.FillTransparency=HINT_GOLD,0.45
 highlight.OutlineColor,highlight.OutlineTransparency=Color3.new(1,1,1),0
 highlight.DepthMode,highlight.Enabled=Enum.HighlightDepthMode.AlwaysOnTop,false
 highlight.Parent=self.folder
 local gui=Instance.new("BillboardGui")
 gui.Name="GuideEggTap";gui.Size=UDim2.fromOffset(120,150);gui.AlwaysOnTop,gui.LightInfluence=true,0
 gui.Active,gui.Enabled,gui.MaxDistance,gui.Parent=false,false,200,self.app.gui
 -- A ring spreads from the egg on every tap.
 local ripple=Instance.new("Frame")
 ripple.Name,ripple.AnchorPoint,ripple.Position,ripple.BackgroundTransparency=("Ripple"),Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.4),1
 ripple.Size=UDim2.fromOffset(10,10);ripple.Parent=gui
 Instance.new("UICorner",ripple).CornerRadius=UDim.new(0.5,0)
 local ring=Instance.new("UIStroke");ring.Color,ring.Thickness,ring.Parent=Color3.new(1,1,1),3,ripple
 -- The glove points up with its fingertip at the image centre, so it taps from below.
 local hand=Instance.new("ImageLabel")
 hand.Name,hand.Image,hand.BackgroundTransparency=("Hand"),HOVER_CURSOR,1
 hand.AnchorPoint,hand.Size,hand.Position=Vector2.new(0.5,0.5),UDim2.fromOffset(72,72),UDim2.fromScale(0.5,0.62)
 hand.Parent=gui
 local word=Theme.Label(gui,"Word","CLICK!",22,Color3.new(1,1,1))
 word.AnchorPoint,word.Position,word.Size=Vector2.new(0.5,0),UDim2.fromScale(0.5,0.82),UDim2.fromScale(1,0.18)
 word.TextXAlignment,word.TextScaled,word.TextWrapped=Enum.TextXAlignment.Center,true,false
 self.hintHighlight,self.hintGui,self.hintHand,self.hintRipple,self.hintRing,self.hintWord=highlight,gui,hand,ripple,ring,word
end

function Eggs:HideGuideHint()
 self.guideView=nil
 if not self.hintGui then return end
 self.hintHighlight.Enabled,self.hintHighlight.Adornee=false,nil
 self.hintGui.Enabled,self.hintGui.Adornee=false,nil
 for _,tween in self.hintTweens or {} do tween:Cancel() end
 self.hintTweens=nil
end

-- Keeps one target until it is clicked, then moves to the next nearest settled egg.
function Eggs:StepGuideHint(root,now: number)
 if not self.guideHint then return end
 if not root or self:Blocked() then self:HideGuideHint();return end
 local view=self.guideView
 if not (view and self.views[view.data.id]==view and self:Ready(view,now)) then
  view=nil
  local best=math.huge
  for _,candidate in self.views do
   if self:Ready(candidate,now) then
    local distance=(candidate.ground-root.Position).Magnitude
    if distance<best then view,best=candidate,distance end
   end
  end
 end
 if not view then self:HideGuideHint();return end
 if not self.hintGui then self:BuildGuideHint() end
 if view~=self.guideView or not self.hintGui.Enabled then
  self.guideView=view
  self.hintHighlight.Adornee,self.hintHighlight.Enabled=view.shell,true
  self.hintGui.Adornee,self.hintGui.Enabled=view.shell,true
 end
 if self.hintTweens or self.app.reducedMotion then return end
 self.hintHand.Position=UDim2.fromScale(0.5,0.62)
 self.hintRipple.Size,self.hintRing.Transparency=UDim2.fromOffset(10,10),0
 self.hintTweens={TweenService:Create(self.hintHand,HINT_TAP,{Position=UDim2.fromScale(0.5,0.47)}),
  TweenService:Create(self.hintRipple,HINT_RIPPLE,{Size=UDim2.fromOffset(70,70)}),
  TweenService:Create(self.hintRing,HINT_RIPPLE,{Transparency=1})}
 for _,tween in self.hintTweens do tween:Play() end
end

-- Flies the egg to the player now and asks the server for it with the next batch.
-- `quiet` (a mouse-hold repeat) skips the "Get closer" tag for an egg out of reach.
function Eggs:Grab(view,now: number,quiet: boolean?): boolean
 local root=self:Root()
 if not root then return false end
 local at=view.ground
 if Vector2.new(at.X-root.Position.X,at.Z-root.Position.Z).Magnitude>self:ClickRange()
  or math.abs(at.Y-root.Position.Y)>Tools.MaxHeight then
  if not quiet then self:TooFar(view,now) end
  return false
 end
 local id=view.data.id
 self.optimistic[id]=now
 table.insert(self.queue,id)
 view.picked=true
 view.data.collector="player"
 self:StartFlight(view,now)
 self:PickBurst(at,now)
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
  self.generation=snapshot.generation;self.floatPending=0;self.streak=0
  self.nextCaptionAt=nil
  self.seenDeposits={};self.lastCashClaim=nil
  self.app.feedback:ResetCollections()
  self.rover:Clear()
 end
 self.rover:Receive(snapshot.rover,now)
 local seenDeposits={}
 for _,deposit in snapshot.deposits or (if snapshot.deposit then {snapshot.deposit} else {}) do
  if not (self.seenDeposits and self.seenDeposits[deposit.id]) then
   self.app.feedback:Deposit(deposit)
   if deposit.collector=="rover" then self.rover:Deposit(deposit,now) end
  end
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
   if (data.age or 0)<0.3 and root and (root.Position-view.ground).Magnitude<Feel.Feel.LayRange then self:LayCue(view,now) end
  end
  if view then
   view.data=data;view:SetValue(data.value,data.stack)
   if data.flightAge~=nil and not view.flightAt then
    self:StartFlight(view,now)
    self:PickBurst(view.ground,now) -- The vacuum (or the server) just took it.
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
  else self:Feedback(receipt.id,receipt.value,receipt) end
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
 -- Mouse hold: the egg under the pointer, quietly (no "Get closer" on every repeat).
 local pointer:Vector2?=self.mousePoint
 if self.mouseHeld and pointer and now-(self.lastMouseGrab or 0)>=Feel.Feel.MouseHoldRepeat then
  self.lastMouseGrab=now
  self:Click(pointer,false,true)
 end
 self:Flush(now)
 self:StepHover(now)
 self:StepGuideHint(root,now)
 if self.tooFar.Enabled and (now>=(self.tooFarUntil or 0) or not self.tooFar.Adornee or not self.tooFar.Adornee.Parent) then
  self.tooFar.Enabled=false;self.tooFar.Adornee=nil
 end
 local camera=workspace.CurrentCamera
 self:StepCaptions(root,camera,now)
 -- The held vacuum is "sucking" while it has room and an egg is flying into it or
 -- a settled one sits inside its reach; VacuumController hums and shimmers meanwhile.
 local held=if self.vacuum:Equipped() and self.snapshot and type(self.snapshot.vacuum)=="table" then self.snapshot.vacuum else nil
 local vacuumReach=if held and type(held.range)=="number" and (held.count or 0)<(held.capacity or 0) then held.range else nil
 local fullReach=if held and type(held.range)=="number" and (held.capacity or 0)>0 and (held.count or 0)>=held.capacity then held.range else nil
 local sucking=false
 local blocked=0
 for id,view in self.views do
  local age=now-view.bornAt
  if vacuumReach and not sucking then
   if view.flightAt then sucking=view.data.collector=="vacuum"
   elseif root and age>=Config.EggSettleSeconds then
    sucking=Vector2.new(view.ground.X-root.Position.X,view.ground.Z-root.Position.Z).Magnitude<=vacuumReach
   end
  elseif fullReach and root and not view.flightAt and age>=Config.EggSettleSeconds
   and Vector2.new(view.ground.X-root.Position.X,view.ground.Z-root.Position.Z).Magnitude<=fullReach then
   blocked+=1
  end
  if not view.flightAt and age>=Config.EggSettleSeconds and camera
   and (camera.CFrame.Position-view.ground).Magnitude>Config.EggSpriteMaxDistance then continue end
  local size=1+math.min(0.3,math.log(math.max(1,view.data.stack),2)*0.07)
  if view.flightAt then
   local t=math.clamp((now-view.flightAt)/Feel.Egg.FlightSeconds,0,1)
   local vacuum=view.data.collector=="vacuum"
   local rover=view.data.collector=="rover"
   -- Vacuum pickups fly into the held nozzle; if it was put away, to the server's
   -- landing point. Robot pickups fly into the robot's nozzle. Clicked eggs follow the player.
   local goal=if vacuum then (self.vacuum:NozzlePosition()
     or (if view.data.targetX then Vector3.new(view.data.targetX,view.data.targetY,view.data.targetZ) else nil)
     or (if root then root.Position else view.ground))
    elseif rover then (self.rover:NozzlePosition(view.data) or view.ground)
    elseif root then root.Position+Vector3.new(0,-0.25,0) else view.ground
   local dt=math.clamp(now-(view.lastStep or now),0,0.1);view.lastStep=now
   local interrupted=not vacuum and not rover and not root or view.goal and (goal-view.goal).Magnitude>Feel.Egg.TeleportDistance
   view.goal=if not view.goal then goal else view.goal:Lerp(goal,1-math.exp(-Feel.Egg.TargetResponse*dt))
   if interrupted then t=1 end
   local position=Motion.Flight(view.flightStart,view.goal,t,view.seed,self.app.reducedMotion)
   view.trail.Enabled=not self.app.reducedMotion and t>0
   local shrink=1-math.clamp((t-0.8)/0.2,0,1)*0.85
   local lift=if self.app.reducedMotion then 1 else 1+math.sin(math.min(t*4,1)*math.pi)*0.12
   view:Set(position,size*shrink*lift,if self.app.reducedMotion then 0 else math.sin(t*math.pi)*0.24,view.seed)
   if t>=1 then
    self.finishedFlights[id]=now
    -- The egg reached you or the nozzle: its chime and "+N" (not when a teleport cut it short).
    if rover then self.rover:PickupCue(now)
    elseif not interrupted then self:Arrive(if view.receipt then view.receipt.value else view.data.value,now,view.data.collector) end
    if view.receipt then self:Feedback(id,view.receipt.value,view.receipt)
    elseif view.picked then
     -- A clicked egg counts in as it lands; the server's receipt later is the same egg.
     self:Feedback(id,view.data.value,{collector="player"})
    end
    view:Destroy();self.views[id]=nil
   end
  elseif age<Config.EggSettleSeconds and not self.app.reducedMotion then
   local t=math.clamp(age/Config.EggSettleSeconds,0,1)
   local position=view.origin:Lerp(view.ground,t)+Vector3.new(0,math.sin(t*math.pi)*1.8,0)
   -- The lay pop: the egg grows in from LayPopFrom with a Back overshoot as it lands.
   local grow=Feel.Feel.LayPopFrom+(1-Feel.Feel.LayPopFrom)*backOut(t)
   view:Set(position,size*grow,math.sin(t*math.pi)*0.35,view.seed)
  else
   local bob=if self.app.reducedMotion then 0 else math.sin(age*2.6+view.seed)*0.07
   local pop:number=self:HoverPop(view)
   view:Set(view.ground+Vector3.new(0,bob+pop*HOVER_LIFT,0),size*(1+pop*HOVER_SCALE),0,view.seed)
  end
 end
 self.vacuum:SetActive(sucking)
 self.rover:Step(now)
 -- A full vacuum refuses the eggs it can reach: a new one coming into reach shakes the
 -- pill (ToolController throttles it and skips the moment it filled).
 local tools=self.app.tools
 if blocked>(self.blockedEggs or 0) and tools and tools.VacuumRefused then tools:VacuumRefused(now) end
 self.blockedEggs=blocked
 self:FlushFloat(now)
 for id,at in self.feedback do if now-at>10 then self.feedback[id]=nil end end
 for id,at in self.finishedFlights do if now-at>10 then self.finishedFlights[id]=nil end end
end

function Eggs:Destroy()
 self:HideGuideHint()
 if self.hintGui then self.hintGui:Destroy() end
 if self.connection then self.connection:Disconnect() end
 for _,connection in self.connections do connection:Disconnect() end
 table.clear(self.connections)
 ContextActionService:UnbindAction("PetRollCollectEggs")
 if self.hoverTween then self.hoverTween:Cancel() end
 if self.leaveTween then self.leaveTween:Cancel() end
 self.hoverPop:Destroy();self.leavePop:Destroy()
 if self.hoverView then UserInputService.MouseIcon="" end
 for _,view in self.views do view:Destroy() end
 table.clear(self.views)
 if self.rangeRing then self.rangeRing:Destroy() end
 if self.folder then self.folder:Destroy() end
 if self.tooFar then self.tooFar:Destroy() end
 if self.vacuum then self.vacuum:Destroy() end
 if self.rover then self.rover:Destroy() end
end
return Eggs
