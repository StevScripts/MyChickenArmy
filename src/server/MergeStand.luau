--!strict
-- The builder owns Fuse_Machine. Only runtime clones receive prompts and tweens.
local TweenService=game:GetService("TweenService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local PetView=require(Shared.PetView)
local Builder=require(script.Parent.WorldBuilder)
local HomePlot=require(Shared.HomePlotLayout)
local MergeGate=require(script.Parent.MergeGate)
local MergeStand={}
MergeStand.__index=MergeStand

local function settleVisualJoints(bird)
 -- ScaleTo/placement happen in one tick; don't capture a stale motor pose before
 -- Roblox's next joint solve. Root-only motors bind the imported mesh surfaces.
 local root=bird.PrimaryPart
 for _,joint in root:GetChildren() do
  if joint:IsA("Motor6D") and joint.Part0==root and joint.Part1 then
   joint.Part1.CFrame=root.CFrame*joint.C0*joint.Transform*joint.C1:Inverse()
  end
 end
end

function MergeStand.new(parent,frame,index,onAction,template,templateOrigin)
 local self=setmetatable({index=index,loaded=false,serial=0,tracks={},birds={},gateParts={},scaleDrivers={}},MergeStand)
 local model=Instance.new("Model");model.Name,model.Parent="MergeStand",parent
 model:SetAttribute("PlotIndex",index);self.model=model
 local authored=parent:FindFirstChild("Fuse_Machine",true)
 local machine=if authored and authored:IsA("Model") then authored else nil
 if not machine and template then
  machine=template:Clone()
  machine:PivotTo(frame*templateOrigin:ToObjectSpace(template:GetPivot()))
 end
 if machine then
  machine.Parent=model;self.machine=machine
  -- Replace only obsolete runtime scenery; preserve all editor-owned originals.
  local shops=parent:FindFirstChild("Shops")
  local old=shops and shops:FindFirstChild("Merge")
  if old then old:Destroy() end
 end
 local button=machine and machine:FindFirstChild("Button",true)
 if button and not button:IsA("BasePart") then button=nil end
 local anchor=parent:FindFirstChild("MergePrompt",true)
 local at=if button then button.CFrame elseif anchor and anchor:IsA("BasePart") then anchor.CFrame else frame*HomePlot.Merge*CFrame.new(0,2,0)
 self.counter=Builder.Part(model,"Counter",Vector3.one,at,Builder.Palette.wood,false)
 self.counter.Transparency,self.counter.CastShadow=1,false
 local prompt=button and button:FindFirstChildWhichIsA("ProximityPrompt") or Instance.new("ProximityPrompt")
 prompt.Name,prompt.ActionText,prompt.ObjectText="MergePrompt","Fuse Chickens","Fuse Machine"
 prompt.KeyboardKeyCode,prompt.MaxActivationDistance=Enum.KeyCode.E,12
 prompt.HoldDuration,prompt.RequiresLineOfSight,prompt.Enabled=0,false,false
 prompt.Exclusivity,prompt.Parent=Enum.ProximityPromptExclusivity.OnePerButton,button or self.counter
 self.prompt=prompt
 self.connection=prompt.Triggered:Connect(function(player)
  if self:CanUse(player) then onAction(player,"OpenMerge",index) end
 end)
 local gate=machine and machine:FindFirstChild("Gate")
 if gate and gate:IsA("Model") then
  local bounds,size=gate:GetBoundingBox()
  for _,part in gate:GetDescendants() do
   if part:IsA("BasePart") then table.insert(self.gateParts,{part=part,closed=part.CFrame}) end
  end
  local panel=nil
  for _,entry in self.gateParts do
   if not panel or entry.part.Size.Magnitude>panel.Size.Magnitude then panel=entry.part end
  end
  local outward=if panel then panel.CFrame.LookVector else frame.LookVector
  if panel and panel.Size.X<math.min(panel.Size.Y,panel.Size.Z) then outward=panel.CFrame.RightVector end
  outward=Vector3.new(outward.X,0,outward.Z)
  if outward.Magnitude<0.01 then outward=frame.LookVector else outward=outward.Unit end
  if outward:Dot(bounds.Position-machine:GetPivot().Position)<0 then outward=-outward end
  self.entry=CFrame.lookAt(Vector3.new(bounds.Position.X,bounds.Position.Y-size.Y/2+0.1,bounds.Position.Z),
   Vector3.new(bounds.Position.X,bounds.Position.Y-size.Y/2+0.1,bounds.Position.Z)+outward)
  self.doorSize=size
  self.gate=MergeGate.new(gate,self.entry)
 end
 local attachment=Instance.new("Attachment",self.counter);attachment.Position=Vector3.new(0,1,0)
 if self.entry then attachment.Position=self.counter.CFrame:PointToObjectSpace(self.entry.Position+Vector3.new(0,2.2,0)) end
 local sparkles=Instance.new("ParticleEmitter")
 sparkles.Texture="rbxasset://textures/particles/sparkles_main.dds"
 sparkles.Color=ColorSequence.new(Color3.fromRGB(188,77,255),Color3.fromRGB(246,198,255))
 sparkles.Lifetime,sparkles.Speed=NumberRange.new(0.3,0.7),NumberRange.new(3,6)
 sparkles.Rate,sparkles.LightEmission,sparkles.Parent=0,0.5,attachment
 self.sparkles=sparkles
 local glow=Instance.new("PointLight");glow.Name="FusionGlow"
 glow.Color,glow.Brightness,glow.Range=Color3.fromRGB(183,73,255),0,9
 glow.Parent=attachment;self.glow=glow
 return self
end

function MergeStand:CanUse(player)
 local character=player.Character
 local body=character and character:FindFirstChild("HumanoidRootPart")
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 return self.loaded and not self.reveal and player.UserId==self.ownerId and body~=nil and humanoid~=nil and humanoid.Health>0
  and (body.Position-self.counter.Position).Magnitude<=14
end

function MergeStand:Sync(session)
 self.ownerId=session.userId
 self.loaded=session.loaded==true and not session.closing and not session.saveLost
 local unlocked=session:MergeAccess()
 self.model:SetAttribute("OwnerUserId",session.userId)
 self.prompt.ObjectText=if unlocked then "Fuse Machine" else "Fuse Machine · Locked"
 self.prompt.ActionText=if unlocked then "Fuse Chickens" else "Unlock in Skill Tree"
 -- Keep the native prompt available so the server can explain locked access.
 self.prompt.Enabled=self.loaded and not self.reveal
end

function MergeStand:IsRevealing(petId)
 return self.reveal~=nil and self.reveal.actor.model.Name==petId
end

function MergeStand:ReleaseChicken()
 local reveal=self.reveal
 if not reveal then return end
 self.reveal=nil
 self.prompt.Enabled=self.loaded
 local actor,bird=reveal.actor,reveal.actor.model
 table.clear(self.birds) -- This is the owned actor, never a disposable copy.
 if actor.destroyed or not bird.Parent then return end
 bird:ScaleTo(reveal.scale)
 actor:Teleport(reveal.exit)
 settleVisualJoints(bird)
 actor.root.Anchored,actor.root.CanCollide=false,reveal.collidable
 actor.humanoid.AutoRotate=reveal.autoRotate
 actor.root:SetNetworkOwner(nil)
 bird:SetAttribute("PresentationHidden",reveal.presentationHidden)
 for gui,enabled in reveal.labels do if gui.Parent then gui.Enabled=enabled end end
 reveal.onReleased(actor)
end

function MergeStand:ResetAnimation()
 self.serial+=1
 for _,tween in self.tracks do tween:Cancel() end;table.clear(self.tracks)
 for _,driver in self.scaleDrivers do driver.connection:Disconnect();driver.value:Destroy() end;table.clear(self.scaleDrivers)
 self:ReleaseChicken()
 if self.gate then self.gate:Reset() end
 if self.glow then self.glow.Brightness=0 end
 if self.sparkles then self.sparkles:Clear() end
 for _,entry in self.gateParts do if entry.part.Parent then entry.part.CFrame=entry.closed end end
end

function MergeStand:Celebrate(pet,actor,onReleased)
 self:ResetAnimation()
 if not self.entry or not pet or not actor or actor.destroyed then return false end
 -- Borrow the actual home actor for the reveal, then return that same rig to
 -- normal walking. World pauses its home updates while this record exists.
 actor:Stop()
 local bird=actor.model
 PetView.Level(bird,pet.level or 1,pet.giantSize)
 local foot=(self.entry*CFrame.new(0,0,1.65)).Position
 local offset=bird:GetAttribute("FootOffset")
 local rootAt=foot+Vector3.new(0,offset,0)
 actor.root.Anchored=true
 bird:PivotTo(CFrame.lookAt(rootAt,rootAt+self.entry.LookVector))
 settleVisualJoints(bird)
 local size=bird:GetExtentsSize()
 local distance=math.max(3.4,(bird:GetAttribute("VisualDepth") or size.Z)*0.6+2)
 local reveal={actor=actor,onReleased=onReleased,scale=bird:GetScale(),
  exit=foot+self.entry.LookVector*distance,collidable=actor.root.CanCollide,
  autoRotate=actor.humanoid.AutoRotate,presentationHidden=bird:GetAttribute("PresentationHidden"),labels={}}
 self.reveal=reveal;self.prompt.Enabled=false
 actor.root.CanCollide,actor.humanoid.AutoRotate=false,false
 bird:SetAttribute("PresentationHidden",true)
 bird:SetAttribute("RevealFullScale",reveal.scale)
 bird:SetAttribute("RevealFullFootOffset",offset)
 bird:SetAttribute("RevealExitDistance",distance)
 local fit=math.min(1,self.doorSize.X*0.78/size.X,self.doorSize.Y*0.78/size.Y,2.6/size.Z)
 if fit<1 then bird:ScaleTo(reveal.scale*fit) end
 settleVisualJoints(bird)
 local bounds,scaledSize=bird:GetBoundingBox()
 bird:PivotTo(bird:GetPivot()+Vector3.new(0,foot.Y-(bounds.Position.Y-scaledSize.Y/2),0))
 for _,item in bird:GetDescendants() do
  if item:IsA("BillboardGui") then reveal.labels[item]=item.Enabled;item.Enabled=false end
 end
 table.insert(self.birds,bird)
 local serial=self.serial
 local function later(delay,callback)
  task.delay(delay,function()
   if self.serial~=serial or not self.model.Parent then return end
   if self.reveal and (actor.destroyed or not bird.Parent) then self:ResetAnimation();return end
   callback()
  end)
 end
 -- Fusion happens behind the closed door. Only the confirmed result comes out.
 local charge=TweenService:Create(self.glow,TweenInfo.new(0.28,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,1,true),{Brightness=1.6})
 table.insert(self.tracks,charge);charge:Play()
 later(0.65,function()
  if self.gate then self.gate:Move(true,0.55) end
 end)
 later(1.2,function()
  if not self.entry then return end
  for _,bird in self.birds do
   local frame=Instance.new("CFrameValue");frame.Value=bird:GetPivot()
   local connection=frame.Changed:Connect(function(at) if bird.Parent then bird:PivotTo(at) end end)
   table.insert(self.scaleDrivers,{value=frame,connection=connection})
   local exit=TweenService:Create(frame,TweenInfo.new(0.6,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),
    {Value=frame.Value+self.entry.LookVector*bird:GetAttribute("RevealExitDistance")})
   table.insert(self.tracks,exit);exit:Play()
  end
  self.sparkles:Emit(18)
  local pulse=TweenService:Create(self.glow,TweenInfo.new(0.16,Enum.EasingStyle.Sine,Enum.EasingDirection.Out,0,true),{Brightness=2.5})
  table.insert(self.tracks,pulse);pulse:Play()
 end)
 later(1.85,function()
  for _,bird in self.birds do
   local fullScale=bird:GetAttribute("RevealFullScale")
   local foot=(self.entry*CFrame.new(0,0,1.65-bird:GetAttribute("RevealExitDistance"))).Position
   local rotation=bird:GetPivot().Rotation
   local value=Instance.new("NumberValue");value.Value=bird:GetScale()
   -- Model has no tweenable Scale property. Tween a scalar and apply ScaleTo;
   -- TweenService still owns all timing/easing, with no custom animation loop.
   local connection=value.Changed:Connect(function(scale)
    if not bird.Parent then return end
    bird:ScaleTo(scale)
    bird:PivotTo(CFrame.new(foot+Vector3.new(0,bird:GetAttribute("RevealFullFootOffset")*scale/fullScale,0))*rotation)
    settleVisualJoints(bird)
   end)
   table.insert(self.scaleDrivers,{value=value,connection=connection})
   local grow=TweenService:Create(value,TweenInfo.new(0.55,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Value=fullScale})
   table.insert(self.tracks,grow);grow:Play()
  end
 end)
 later(2,function() if self.gate then self.gate:Move(false,0.5) end end)
 -- The reveal becomes the home walk: no fade, replacement model or yard spawn.
 later(2.6,function() self:ResetAnimation() end)
 return true
end

function MergeStand:Clear()
 self:ResetAnimation();self.ownerId,self.loaded=nil,false
 self.model:SetAttribute("OwnerUserId",nil);self.prompt.Enabled=false
end

function MergeStand:Destroy()
 self:ResetAnimation();self.connection:Disconnect();self.model:Destroy()
end
return MergeStand
