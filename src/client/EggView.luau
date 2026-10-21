--!strict
-- Each egg is its layer's voxel mesh (docs/team/VOXEL_EGGS.md): a clone of the
-- Studio-owned template ReplicatedStorage.PetRoll.Assets.EggMeshes[species].
-- Without that folder (a scripts-only build) eggs fall back to the image sprite.
local ContentProvider=game:GetService("ContentProvider")
local PetRoll=game:GetService("ReplicatedStorage").PetRoll
local Shared=PetRoll.Shared
local Config=require(Shared.Config)
local EggArt=require(Shared.EggArt)
local EggView={}
EggView.__index=EggView

-- Sprite fallback only: each species' egg image downloads once, the first time
-- one is laid nearby; until then the egg shows the Chicken egg image.
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

-- A template's mesh origin is the egg's bottom centre, and the mesh scales about
-- it. Eggs turn their decorated front (the voxel +X/+Z corner) toward the
-- camera with a small per-egg twist, so a yard of eggs reads at a glance.
local FRONT=CFrame.Angles(0,3*math.pi/4,0)
local meshes:Instance?=nil
local function template(species:string?):BasePart?
 if not meshes then
  local assets=PetRoll:FindFirstChild("Assets")
  meshes=assets and assets:FindFirstChild("EggMeshes")
  if not meshes then return nil end
 end
 local found=(species and meshes:FindFirstChild(species)) or meshes:FindFirstChild("Duck")
 return if found and found:IsA("BasePart") then found else nil
end

-- October 21 (Stevin): no caption over eggs; their worth shows only when collected.

local function trail(parent,center)
 local a,b=Instance.new("Attachment"),Instance.new("Attachment")
 a.Position,b.Position=center+Vector3.new(-0.12,0,0),center+Vector3.new(0.12,0,0);a.Parent=parent;b.Parent=parent
 local t=Instance.new("Trail")
 t.Attachment0,t.Attachment1,t.Lifetime=a,b,0.14
 t.Color=ColorSequence.new(Color3.new(1,1,1))
 t.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.25),NumberSequenceKeypoint.new(1,1)})
 t.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})
 t.LightEmission,t.Enabled,t.Parent=0.6,false,parent
 return t
end

local function meshEgg(parent,data,source:BasePart)
 local body=source:Clone()
 body.Name="Egg_"..data.id
 -- October 20: eggs are clicked and tapped (EggController). Queryable for that ray only;
 -- they still never collide or touch, and the Glow child stays out of the ray.
 body.CanQuery,body.CanCollide,body.CanTouch=true,false,false
 body:SetAttribute("CoinValue",data.value)
 body:SetAttribute("EggCount",data.stack or 1)
 local half=(tonumber(body:GetAttribute("EggHeight")) or 1.75)/2
 local center=Instance.new("Attachment");center.Name="Center";center.Position=Vector3.new(0,half,0);center.Parent=body
 local count=data.stack or 1
 local glow=body:FindFirstChild("Glow")
 if glow and glow:IsA("BasePart") then glow.CanQuery=false end
 local seed=tonumber(data.id) or 1
 body.Parent=parent
 return setmetatable({anchor=body,shell=body,body=body,glow=if glow and glow:IsA("BasePart") then glow else nil,
  base=body.Size,glowBase=if glow and glow:IsA("BasePart") then glow.Size else nil,half=half,
  twist=math.rad(((seed*37)%51)-25),trail=trail(body,center.Position),
  seed=seed,scale=1,rotation=0,displayedValue=data.value,displayedCount=count},EggView)
end

function EggView.new(parent,data)
 local source=template(data.species)
 if source then return meshEgg(parent,data,source) end
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
 local count=data.stack or 1
 anchor.Parent=parent
 return setmetatable({anchor=anchor,shell=anchor,gui=gui,image=sprite,trail=trail(anchor,Vector3.zero),
  seed=tonumber(data.id) or 1,scale=1,rotation=0,displayedValue=data.value,displayedCount=count},EggView)
end

function EggView:SetValue(value,count)
 count=count or 1
 if self.displayedValue==value and self.displayedCount==count then return end
 self.displayedValue,self.displayedCount=value,count
 self.anchor:SetAttribute("CoinValue",value)
 self.anchor:SetAttribute("EggCount",count)
end

function EggView:Set(position,scale,tilt,_yaw)
 local body=self.body
 if body then
  scale=math.max(scale,0.001)
  if math.abs(scale-self.scale)>0.005 then
   body.Size=self.base*scale
   if self.glow then self.glow.Size=self.glowBase*scale end
   self.scale=scale
  end
  local camera=workspace.CurrentCamera
  local look=if camera then (camera.CFrame.Position-position)*Vector3.new(1,0,1) else Vector3.zero
  if look.Magnitude<0.01 then look=Vector3.new(0,0,-1) end
  local cf=CFrame.lookAt(position,position+look)*CFrame.Angles(0,0,tilt or 0)*FRONT
   *CFrame.Angles(0,self.twist,0)*CFrame.new(0,-self.half,0) -- bottom stays put as it scales
  body.CFrame=cf
  if self.glow then self.glow.CFrame=cf end
  self.position=position
  return
 end
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
