--!strict
-- A contained, cancellable celebration of an already-confirmed merge.
local Theme=require(script.Parent.UITheme)
local Presentation={}
Presentation.__index=Presentation

function Presentation.new(app,parent,pet)
 local self=setmetatable({app=app,serial=0,tracks={},alive=true,phase="Ready"},Presentation)
 local stage=Theme.Frame(parent,"MergeStage",UDim2.fromScale(1,1))
 stage:SetAttribute("OwnsPopupStyle",true)
 stage.ZIndex=parent.ZIndex+1
 stage.Position,stage.BackgroundTransparency,stage.ClipsDescendants=UDim2.new(),1,true
 self.stage=stage
 local floor=Instance.new("Frame")
 floor.Name,floor.AnchorPoint,floor.Position="LandingShadow",Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.89)
 floor.Size,floor.BackgroundColor3,floor.BackgroundTransparency=UDim2.fromScale(0.60,0.018),Theme.Colors.dark,0.45
 floor.BorderSizePixel,floor.ZIndex,floor.Parent=0,1,stage
 floor.Visible=false
 self.inputs={}
 for i,x in {0.2,0.5,0.8} do
  local bird=app:Preview(stage,pet,UDim2.fromScale(0.34,0.66),UDim2.fromScale(x,0.48))
  bird.Name,bird.AnchorPoint="InputChicken"..i,Vector2.new(0.5,0.5)
  bird.ZIndex=stage.ZIndex+2
  self.inputs[i]=bird
 end
 local output=app:Preview(stage,{species=pet.species,level=pet.level+1},UDim2.fromScale(1.06,1.08),UDim2.fromScale(0.5,0.48))
 output.Name,output.AnchorPoint,output.Visible="MergedChicken",Vector2.new(0.5,0.5),false
 output.ZIndex=stage.ZIndex+3
 self.output=output
 local plus=Theme.Label(stage,"Plus","+",38,Theme.Colors.muted)
 plus.AnchorPoint,plus.Position,plus.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.48),UDim2.fromOffset(40,50)
 plus.TextXAlignment=Enum.TextXAlignment.Center
 self.plus=plus
 for _,bird in self.inputs do bird.Visible=false end
 self.output.Visible=true
 self.plus.Visible=false
 stage:SetAttribute("MergePhase","Ready")
 return self
end

function Presentation:SetPhase(phase)
 self.phase=phase
 self.stage:SetAttribute("MergePhase",phase)
end

function Presentation:Tween(object,channel,goals,seconds,style)
 table.insert(self.tracks,{object,channel})
 Theme.Motion:Tween(object,channel,goals,seconds,style)
end

function Presentation:Later(seconds,callback)
 local serial=self.serial
 task.delay(seconds,function()
  if self.alive and self.serial==serial and self.stage.Parent then callback() end
 end)
end

function Presentation:ShowResult()
 for _,bird in self.inputs do bird.Visible=false end
 self.plus.Visible=false
 self.output.Visible,self.output.ImageTransparency=true,0
 self.output.Size,self.output.Position=UDim2.fromScale(1.06,1.08),UDim2.fromScale(0.5,0.48)
 self:SetPhase("Complete")
end

function Presentation:Feathers()
 local puff=Instance.new("Frame")
 puff.Name,puff.Size,puff.BackgroundTransparency,puff.ZIndex="MergeFeathers",UDim2.fromScale(1,1),1,8
 puff.Parent=self.stage;self.puff=puff
 for i=1,6 do
  local angle=(i-1)*math.pi/3+0.25
  local feather=Instance.new("Frame")
  feather.Name,feather.AnchorPoint,feather.Position="Feather"..i,Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.47)
  feather.Size,feather.Rotation=UDim2.fromOffset(12+(i%2)*5,7),i*31
  feather.BackgroundColor3,feather.BorderSizePixel,feather.ZIndex=Theme.Colors.white,0,8
  feather.Parent=puff
  self:Tween(feather,"mergeFeather",{Position=UDim2.fromScale(0.5+math.cos(angle)*0.23,0.47+math.sin(angle)*0.21),
   Rotation=i*31+70,BackgroundTransparency=1,Size=UDim2.fromOffset(5,3)},0.48)
 end
 self:Later(0.5,function() puff:Destroy();self.puff=nil end)
end

function Presentation:Play(onReveal,onComplete)
 self:Cancel()
 self:SetPhase("Prepare")
 self.output.Visible=false
 for _,bird in self.inputs do bird.Visible=true end
 self.plus.Visible=false
 if self.app.reducedMotion then
  self:ShowResult()
  onReveal()
  self.app.audio:Play("RollReveal",1.1,{volume=0.3,maxDuration=0.7,voiceKey="MergeReveal"})
  onComplete()
  return
 end
 self.app.audio:Play("RollTick",0.9,{volume=0.15,maxDuration=0.15,voiceKey="MergePrepare"})
 for i,bird in self.inputs do
  local side=i-2
  self:Tween(bird,"mergeBird",{Position=UDim2.fromScale(0.5+side*0.28,0.50),Rotation=side*6},0.18)
 end
 self:Later(0.18,function()
  self:SetPhase("Hop")
  for i,bird in self.inputs do
   local side=i-2
   self:Tween(bird,"mergeBird",{Position=UDim2.fromScale(0.5+side*0.11,0.40),Rotation=-side*4},0.15,Enum.EasingStyle.Sine)
  end
 end)
 self:Later(0.33,function()
  for _,bird in self.inputs do
   self:Tween(bird,"mergeBird",{Position=UDim2.fromScale(0.5,0.48),Rotation=0},0.13,Enum.EasingStyle.Quad)
  end
 end)
 self:Later(0.46,function()
  self:SetPhase("Impact")
  for _,bird in self.inputs do bird.Visible=false end
  self:Feathers()
  self.app.audio:Play("Pop",0.88,{volume=0.4,maxDuration=0.35,voiceKey="MergeImpact"})
 end)
 self:Later(0.58,function()
  self:SetPhase("Reveal")
  local bird=self.output
  bird.Visible,bird.ImageTransparency=true,0.18
  bird.Size,bird.Position=UDim2.fromScale(0.74,0.84),UDim2.fromScale(0.5,0.44)
  self:Tween(bird,"mergeBird",{Size=UDim2.fromScale(1.06,1.08),Position=UDim2.fromScale(0.5,0.48),ImageTransparency=0},0.3,Enum.EasingStyle.Cubic)
  onReveal()
  self.app.audio:Play("RollReveal",1.1,{volume=0.3,maxDuration=0.7,voiceKey="MergeReveal"})
 end)
 self:Later(1.1,function() self:ShowResult();onComplete() end)
end

function Presentation:Cancel()
 self.serial+=1
 for _,track in self.tracks do Theme.Motion:Cancel(track[1],track[2]) end
 table.clear(self.tracks)
 if self.puff then self.puff:Destroy();self.puff=nil end
end

function Presentation:Destroy()
 self.alive=false
 self:Cancel()
 self.stage:Destroy()
end

return Presentation
