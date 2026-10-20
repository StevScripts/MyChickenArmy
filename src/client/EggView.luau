--!strict
-- One image and one invisible anchor replace the multipart egg geometry.
local ContentProvider=game:GetService("ContentProvider")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local EggArt=require(Shared.EggArt)
local Theme=require(script.Parent.UITheme)
local Feedback=require(script.Parent.EggFeedback)
local EggView={}
EggView.__index=EggView

-- Each species' egg image downloads once, the first time one is laid nearby;
-- until then the egg shows the already-loaded Chicken egg.
local ready,waiting={[EggArt.Fallback]=true},{}
local function whenReady(image,callback)
 if ready[image]~=nil then callback(ready[image]);return end
 local list=waiting[image]
 if list then table.insert(list,callback);return end
 waiting[image]={callback}
 task.spawn(function()
  -- Preload through an ImageLabel: a bare content string reports Failure for image assets.
  local probe=Instance.new("ImageLabel");probe.Image=image
  local ok=false
  pcall(function()
   ContentProvider:PreloadAsync({probe},function(_,status) ok=status==Enum.AssetFetchStatus.Success end)
  end)
  probe:Destroy()
  ready[image]=ok -- A failed image stays on the Chicken egg without retrying.
  local callbacks=waiting[image];waiting[image]=nil
  for _,fn in callbacks do fn(ok) end
 end)
end
task.spawn(function()
 local probe=Instance.new("ImageLabel");probe.Image=EggArt.Fallback
 pcall(function() ContentProvider:PreloadAsync({probe}) end)
 probe:Destroy()
end)

function EggView.new(parent,data)
 local anchor=Instance.new("Part")
 anchor.Name,anchor.Size="Egg_"..data.id,Vector3.new(0.1,0.1,0.1)
 anchor.Anchored,anchor.CanCollide,anchor.CanTouch,anchor.CanQuery=true,false,false,false
 anchor.Transparency,anchor.CastShadow=1,false
 anchor:SetAttribute("CoinValue",data.value)
 anchor:SetAttribute("EggCount",data.stack or 1)
 local gui=Instance.new("BillboardGui")
 gui.Name,gui.Adornee="EggSprite",anchor
 gui.Size=UDim2.fromScale(Config.EggSpriteSize*EggArt.Scale,Config.EggSpriteSize*EggArt.Scale)
 gui.MaxDistance,gui.AlwaysOnTop,gui.LightInfluence=Config.EggSpriteMaxDistance,false,0
 gui.Brightness=2 -- Self-lit collectible; preserve world occlusion without dull shading.
 gui.Active,gui.ClipsDescendants,gui.Parent=false,false,anchor
 local sprite=Instance.new("ImageLabel")
 sprite.Name,sprite.BackgroundTransparency="Egg",1
 sprite.AnchorPoint,sprite.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
 sprite.Size,sprite.ScaleType=UDim2.fromScale(1,1),Enum.ScaleType.Fit
 sprite.Image,sprite.Parent=EggArt.Fallback,gui
 -- Each chicken lays its own voxel egg; rarity effects are baked into the art.
 sprite.ImageColor3=Color3.new(1,1,1)
 local image=EggArt.Image(data.species)
 whenReady(image,function(ok) if ok and sprite.Parent then sprite.Image=image end end)
 local caption=Instance.new("BillboardGui")
 caption.Name,caption.Adornee="EggQuantity",anchor
 caption.Size,caption.StudsOffset=UDim2.fromOffset(156,26),Vector3.new(0,1.45,0)
 caption.MaxDistance,caption.AlwaysOnTop,caption.LightInfluence=36,false,0
 caption.Enabled,caption.Active,caption.Parent=false,false,anchor
 local count=data.stack or 1
 local valueLabel=Theme.Label(caption,"Quantity",Feedback.Fit(count,"",if count==1 then " egg" else " eggs",156,18,false),18)
 valueLabel.Size,valueLabel.TextXAlignment=UDim2.fromScale(1,1),Enum.TextXAlignment.Center
 valueLabel.TextWrapped=false
 local a,b=Instance.new("Attachment"),Instance.new("Attachment")
 a.Position,b.Position=Vector3.new(-0.12,0,0),Vector3.new(0.12,0,0);a.Parent=anchor;b.Parent=anchor
 local trail=Instance.new("Trail")
 trail.Attachment0,trail.Attachment1,trail.Lifetime=a,b,0.14
 trail.Color=ColorSequence.new(Color3.new(1,1,1))
 trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.25),NumberSequenceKeypoint.new(1,1)})
 trail.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})
 trail.LightEmission,trail.Enabled,trail.Parent=0.6,false,anchor
 anchor.Parent=parent
 return setmetatable({anchor=anchor,shell=anchor,gui=gui,image=sprite,trail=trail,caption=caption,valueLabel=valueLabel,
  seed=tonumber(data.id) or 1,scale=1,rotation=0,displayedValue=data.value,displayedCount=count},EggView)
end

function EggView:SetValue(value,count)
 count=count or 1
 if self.displayedValue==value and self.displayedCount==count then return end
 self.displayedValue,self.displayedCount=value,count
 self.anchor:SetAttribute("CoinValue",value)
 self.anchor:SetAttribute("EggCount",count)
 self.valueLabel.Text=Feedback.Fit(count,"",if count==1 then " egg" else " eggs",156,18,false)
end

function EggView:Set(position,scale,tilt,_yaw)
 self.anchor.Position=position
 if math.abs(scale-self.scale)>0.01 then
  self.gui.Size=UDim2.fromScale(Config.EggSpriteSize*EggArt.Scale*scale,Config.EggSpriteSize*EggArt.Scale*scale)
  self.scale=scale
 end
 local rotation=math.deg(tilt or 0)
 if math.abs(rotation-self.rotation)>0.1 then self.image.Rotation=rotation;self.rotation=rotation end
 self.position=position
end

function EggView:Destroy() self.anchor:Destroy() end
return EggView
