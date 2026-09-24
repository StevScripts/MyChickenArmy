--!strict
-- A shared image and one invisible anchor replace the multipart egg geometry.
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Config=require(Shared.Config)
local EggView={}
EggView.__index=EggView

function EggView.new(parent,data)
 local anchor=Instance.new("Part")
 anchor.Name,anchor.Size="Egg_"..data.id,Vector3.new(0.1,0.1,0.1)
 anchor.Anchored,anchor.CanCollide,anchor.CanTouch,anchor.CanQuery=true,false,false,false
 anchor.Transparency,anchor.CastShadow=1,false
 anchor:SetAttribute("CoinValue",data.value)
 local gui=Instance.new("BillboardGui")
 gui.Name,gui.Adornee="EggSprite",anchor
 gui.Size=UDim2.fromScale(Config.EggSpriteSize,Config.EggSpriteSize)
 gui.MaxDistance,gui.AlwaysOnTop,gui.LightInfluence=Config.EggSpriteMaxDistance,false,0
 gui.Brightness=2 -- Self-lit collectible; preserve world occlusion without dull shading.
 gui.Active,gui.ClipsDescendants,gui.Parent=false,false,anchor
 local sprite=Instance.new("ImageLabel")
 sprite.Name,sprite.BackgroundTransparency="Egg",1
 sprite.AnchorPoint,sprite.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
 sprite.Size,sprite.ScaleType=UDim2.fromScale(1,1),Enum.ScaleType.Fit
 sprite.Image,sprite.Parent=Config.EggSpriteImage,gui
 local pet=Catalog[data.species]
 if pet and (pet.rarity=="Legendary" or pet.rarity=="Mythic") then sprite.ImageColor3=Color3.fromRGB(255,221,118) end
 local a,b=Instance.new("Attachment"),Instance.new("Attachment")
 a.Position,b.Position=Vector3.new(-0.12,0,0),Vector3.new(0.12,0,0);a.Parent=anchor;b.Parent=anchor
 local trail=Instance.new("Trail")
 trail.Attachment0,trail.Attachment1,trail.Lifetime=a,b,0.14
 trail.Color=ColorSequence.new(Color3.fromRGB(255,228,92),Color3.new(1,1,1))
 trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.25),NumberSequenceKeypoint.new(1,1)})
 trail.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})
 trail.LightEmission,trail.Enabled,trail.Parent=0.6,false,anchor
 anchor.Parent=parent
 return setmetatable({anchor=anchor,shell=anchor,gui=gui,image=sprite,trail=trail,
  seed=tonumber(data.id) or 1,scale=1,rotation=0},EggView)
end

function EggView:SetValue(value)
 self.anchor:SetAttribute("CoinValue",value)
end

function EggView:Set(position,scale,tilt,_yaw)
 self.anchor.Position=position
 if math.abs(scale-self.scale)>0.01 then
  self.gui.Size=UDim2.fromScale(Config.EggSpriteSize*scale,Config.EggSpriteSize*scale)
  self.scale=scale
 end
 local rotation=math.deg(tilt or 0)
 if math.abs(rotation-self.rotation)>0.1 then self.image.Rotation=rotation;self.rotation=rotation end
 self.position=position
end

function EggView:Destroy() self.anchor:Destroy() end
return EggView
