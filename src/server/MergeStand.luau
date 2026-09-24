--!strict
-- Decorative kiosk and a single menu-entry prompt. Merge choices live in MergeBrowser.
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local PetView=require(Shared.PetView)
local Builder=require(script.Parent.WorldBuilder)
local UIColors=require(Shared.UIColors)
local MergeStand={}
MergeStand.__index=MergeStand
local PURPLE=UIColors.Upgrade
local GREEN=UIColors.Purchase

local function ornament(parent,name,foot,facing,scale)
 local model=PetView.Create(parent,name,"Duck",1,foot)
 model:ScaleTo(model:GetScale()*scale)
 for _,key in {"FootOffset","Size","VisualHeight","ClipScale"} do
  local value=model:GetAttribute(key);if value then model:SetAttribute(key,value*scale) end
 end
 for _,item in model:GetDescendants() do
  if item:IsA("BillboardGui") then item.Enabled=false
  elseif item:IsA("BasePart") then item.CanCollide,item.CanQuery,item.CanTouch=false,false,false end
 end
 PetView.Move(model,foot,facing,0)
end

function MergeStand.new(parent,frame,index,onAction)
 local self=setmetatable({index=index,loaded=false},MergeStand)
 local model=Instance.new("Model");model.Name,model.Parent="MergeStand",parent
 model:SetAttribute("PlotIndex",index);model:PivotTo(frame);self.model=model
 local function part(name,size,at,color,collidable)
  return Builder.Part(model,name,size,frame*at,color,collidable)
 end
 -- Blender owns the kiosk; this invisible counter anchors the native prompt.
 self.counter=if parent:GetAttribute("AuthoredPlot") then Builder.Part(model,"Counter",Vector3.one,
  parent:FindFirstChild("MergePrompt",true).CFrame,Builder.Palette.wood,false)
  else part("Counter",Vector3.new(11,2.6,3.4),CFrame.new(0,1.45,0.6),Builder.Palette.wood,true)
 self.counter.Transparency,self.counter.CastShadow=1,false
 -- Fixed ornaments communicate the service; they are not inventory choices.
 if not parent:GetAttribute("AuthoredPlot") then
 ornament(model,"SmallChickenA",(frame*CFrame.new(-3.4,3.05,0)).Position,frame.LookVector,0.55)
 ornament(model,"SmallChickenB",(frame*CFrame.new(-1.3,3.05,0)).Position,frame.LookVector,0.55)
 ornament(model,"UpgradedChicken",(frame*CFrame.new(3,3.05,0)).Position,frame.LookVector,0.85)
 Builder.Sign(model,"Arrow",frame*CFrame.new(0.7,4.05,-0.4),"→",GREEN,1.5,1.2)
 end
 local prompt=Instance.new("ProximityPrompt")
 prompt.Style=Enum.ProximityPromptStyle.Default
 prompt.Name,prompt.ActionText,prompt.ObjectText="MergePrompt","Merge Chickens","Merge Station"
 prompt.KeyboardKeyCode,prompt.MaxActivationDistance=Enum.KeyCode.E,12
 prompt.HoldDuration,prompt.RequiresLineOfSight,prompt.Enabled=0,false,false
 prompt.Exclusivity,prompt.Parent=Enum.ProximityPromptExclusivity.OnePerButton,self.counter
 self.prompt=prompt
 self.connection=prompt.Triggered:Connect(function(player)
  if self:CanUse(player) then onAction(player,"OpenMerge",index) end
 end)
 local attachment=Instance.new("Attachment",self.counter);attachment.Position=Vector3.new(0,2,0)
 local sparkles=Instance.new("ParticleEmitter")
 sparkles.Texture="rbxasset://textures/particles/sparkles_main.dds"
 sparkles.Color=ColorSequence.new(GREEN,Builder.Palette.gold)
 sparkles.Lifetime,sparkles.Speed=NumberRange.new(0.4,0.8),NumberRange.new(5,9)
 sparkles.Rate,sparkles.LightEmission,sparkles.Parent=0,0.5,attachment
 self.sparkles=sparkles
 return self
end

function MergeStand:CanUse(player)
 local body=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 return self.loaded and player.UserId==self.ownerId and body~=nil
  and (body.Position-self.counter.Position).Magnitude<=14
end

function MergeStand:Sync(session)
 self.ownerId=session.userId
 self.loaded=session.loaded==true and not session.closing and not session.saveLost
 self.model:SetAttribute("OwnerUserId",session.userId)
 self.prompt.Enabled=self.loaded
end

function MergeStand:Celebrate()
 self.sparkles:Emit(20)
end

function MergeStand:Clear()
 self.ownerId,self.loaded=nil,false
 self.model:SetAttribute("OwnerUserId",nil);self.prompt.Enabled=false
end

function MergeStand:Destroy()
 self.connection:Disconnect();self.model:Destroy()
end

return MergeStand
