--!strict
-- The builder owns Fuse_Machine. Only runtime clones receive prompts and tweens.
local TweenService=game:GetService("TweenService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local PetView=require(Shared.PetView)
local Builder=require(script.Parent.WorldBuilder)
local HomePlot=require(Shared.HomePlotLayout)
local MergeStand={}
MergeStand.__index=MergeStand

function MergeStand.new(parent,frame,index,onAction,template,templateOrigin)
 local self=setmetatable({index=index,loaded=false,serial=0,tracks={},birds={},gateParts={}},MergeStand)
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
 prompt.Name,prompt.ActionText,prompt.ObjectText="MergePrompt","Merge Chickens","Fuse Machine"
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
  self.gateLift=Vector3.new(0,size.Y+0.4,0)
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
 end
 local attachment=Instance.new("Attachment",self.counter);attachment.Position=Vector3.new(0,1,0)
 local sparkles=Instance.new("ParticleEmitter")
 sparkles.Texture="rbxasset://textures/particles/sparkles_main.dds"
 sparkles.Color=ColorSequence.new(Color3.fromRGB(188,77,255),Color3.fromRGB(246,198,255))
 sparkles.Lifetime,sparkles.Speed=NumberRange.new(0.3,0.7),NumberRange.new(3,6)
 sparkles.Rate,sparkles.LightEmission,sparkles.Parent=0,0.5,attachment
 self.sparkles=sparkles
 return self
end

function MergeStand:CanUse(player)
 local character=player.Character
 local body=character and character:FindFirstChild("HumanoidRootPart")
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 return self.loaded and player.UserId==self.ownerId and body~=nil and humanoid~=nil and humanoid.Health>0
  and (body.Position-self.counter.Position).Magnitude<=14
end

function MergeStand:Sync(session)
 self.ownerId=session.userId
 self.loaded=session.loaded==true and not session.closing and not session.saveLost
 self.model:SetAttribute("OwnerUserId",session.userId)
 self.prompt.Enabled=self.loaded
end

function MergeStand:Tween(part,goal,seconds)
 local tween=TweenService:Create(part,TweenInfo.new(seconds,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),{CFrame=goal})
 table.insert(self.tracks,tween);tween:Play()
end

function MergeStand:ResetAnimation()
 self.serial+=1
 for _,tween in self.tracks do tween:Cancel() end;table.clear(self.tracks)
 for _,bird in self.birds do bird:Destroy() end;table.clear(self.birds)
 for _,entry in self.gateParts do if entry.part.Parent then entry.part.CFrame=entry.closed end end
end

function MergeStand:Celebrate(pet)
 self:ResetAnimation()
 local serial=self.serial
 local function later(delay,callback)
  task.delay(delay,function() if self.serial==serial and self.model.Parent then callback() end end)
 end
 for _,entry in self.gateParts do self:Tween(entry.part,entry.closed+self.gateLift,0.35) end
 if self.entry and pet then
  later(0.35,function()
   for index=1,3 do
    local foot=(self.entry*CFrame.new((index-2)*1.35,0,-3)).Position
    local bird=PetView.Create(self.model,"MergeInput"..index,pet.species,pet.stars or 1,foot)
    bird:ScaleTo(bird:GetScale()*0.5)
    PetView.Move(bird,foot,-self.entry.LookVector,0)
    table.insert(self.birds,bird)
    local delta=-self.entry.LookVector*5
    for _,part in bird:GetDescendants() do
     if part:IsA("BillboardGui") then part.Enabled=false
     elseif part:IsA("BasePart") then
      part.CanCollide,part.CanQuery,part.CanTouch=false,false,false
      self:Tween(part,part.CFrame+delta,0.65)
     end
    end
   end
  end)
 end
 later(1,function()
  for _,bird in self.birds do bird:Destroy() end;table.clear(self.birds)
  for _,entry in self.gateParts do self:Tween(entry.part,entry.closed,0.35) end
 end)
 later(1.4,function() self.sparkles:Emit(14) end)
 later(1.8,function() self:ResetAnimation() end)
end

function MergeStand:Clear()
 self:ResetAnimation();self.ownerId,self.loaded=nil,false
 self.model:SetAttribute("OwnerUserId",nil);self.prompt.Enabled=false
end

function MergeStand:Destroy()
 self:ResetAnimation();self.connection:Disconnect();self.model:Destroy()
end
return MergeStand
