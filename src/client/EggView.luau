--!strict
-- Each egg is its layer's voxel mesh (docs/team/VOXEL_EGGS.md): a clone of the
-- Studio-owned template ReplicatedStorage.PetRoll.Assets.EggMeshes[species].
-- Without that folder (a scripts-only build) eggs fall back to the image sprite.
local ContentProvider=game:GetService("ContentProvider")
local PetRoll=game:GetService("ReplicatedStorage").PetRoll
local Shared=PetRoll.Shared
local Config=require(Shared.Config)
local EggArt=require(Shared.EggArt)
local Theme=require(script.Parent.UITheme)
local Feedback=require(script.Parent.EggFeedback)
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

-- The Studio-owned voxel egg for a species (Duck fallback), for the back stack's clones.
function EggView.Template(species:string?):BasePart?
 return template(species)
end

-- October 21: one egg is one egg; the caption shows what it is worth.
local function worth(value) return Feedback.Fit(value,"","",156,18,true,false) end

local function caption(adornee,value)
 local gui=Instance.new("BillboardGui")
 gui.Name,gui.Adornee="EggQuantity",adornee
 gui.Size,gui.StudsOffset=UDim2.fromOffset(156,26),Vector3.new(0,1.45,0)
 gui.MaxDistance,gui.AlwaysOnTop,gui.LightInfluence=36,false,0
 gui.Enabled,gui.Active,gui.Parent=false,false,adornee
 local label=Theme.Label(gui,"Quantity",worth(value),18)
 label.Size,label.TextXAlignment=UDim2.fromScale(1,1),Enum.TextXAlignment.Center
 label.TextWrapped=false
 return gui,label
end

-- October 23 empty start (Stevin: "a click icon on eggs"), rebuilt October 24 from his
-- Drop a Fruit recording as the Click badge: while the guide's egg hint is on
-- (TutorialGuide.EggHint) every ready egg but the lit one wears a small white blob
-- holding a mouse with "Click" under it (touch: the hand and "Tap"; gamepad: "R2" in
-- the blob). About the egg's size, laid over it (October 24, Stevin: on the egg, not
-- above it). Off until EggController turns it on; all badges share one pulse there (no
-- per-egg tweens). `lift`: studs from the adornee to the badge's centre (0 = on the egg).
local CLICK_ICON="rbxassetid://121385630700970" -- October 24: mouse icon for the Click badge (Codex, uploaded Oct 24)
-- October 24 (Stevin: "1:1" to his reference): the whole badge as one image, the tan blob
-- with the white outline and the icon inside it; the word is drawn under it by the game.
-- CLICK_BADGE (mouse) and TAP_BADGE (finger) replace the blob frame when set; the frame
-- and CLICK_ICON/TAP_HAND remain the fallback.
local CLICK_BADGE="rbxassetid://79756670832324" -- tan blob + mouse (Codex from Stevin's reference, uploaded Oct 24)
local TAP_BADGE="rbxassetid://76701185375129" -- tan blob + pointing finger
local TAP_HAND="rbxassetid://74062853444480"
local BADGE_WIDTH,BADGE_HEIGHT=1.9,2.15 -- studs (October 24: about the reference badge, head-sized)
local BADGE_WORD={Touch="Tap",Gamepad="R2",Keyboard="Click"}
local BADGE_INK=Color3.fromRGB(34,36,44) -- the blob's thin stroke and the drawn mouse
local BADGE_KEY=Color3.fromRGB(128,132,144) -- the drawn mouse's left button and divider
local function tapIcon(adornee,lift)
 local gui=Instance.new("BillboardGui")
 gui.Name,gui.Adornee="TapIcon",adornee
 gui.Size,gui.StudsOffset=UDim2.fromScale(BADGE_WIDTH,BADGE_HEIGHT),Vector3.new(0,lift,0)
 gui.MaxDistance,gui.AlwaysOnTop,gui.LightInfluence=60,true,0
 gui.Enabled,gui.Active,gui.Parent=false,false,adornee
 -- The shared pulse scales this frame about its centre.
 local badge=Instance.new("Frame")
 badge.Name,badge.BackgroundTransparency,badge.Size=("Badge"),1,UDim2.fromScale(1,1)
 badge.AnchorPoint,badge.Position,badge.Parent=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),gui
 local pulse=Instance.new("UIScale");pulse.Parent=badge
 -- The blob: a rounded white square with a thin dark stroke in the badge's top.
 local blob=Instance.new("Frame")
 blob.Name,blob.BackgroundColor3,blob.BorderSizePixel=("Blob"),Color3.new(1,1,1),0
 blob.AnchorPoint,blob.Position,blob.Size=Vector2.new(0.5,0),UDim2.fromScale(0.5,0),UDim2.fromScale(0.74,0.74)
 Instance.new("UICorner",blob).CornerRadius=UDim.new(0.3,0)
 Instance.new("UIAspectRatioConstraint",blob).AspectRatio=1
 local rim=Instance.new("UIStroke");rim.Color,rim.Thickness,rim.Parent=BADGE_INK,2,blob
 blob.Parent=badge
 -- A whole-badge image (CLICK_BADGE/TAP_BADGE) fills the blob's cell; the blob itself
 -- then draws nothing (SetTap).
 local whole=Instance.new("ImageLabel")
 whole.Name,whole.BackgroundTransparency,whole.ScaleType,whole.Visible=("Whole"),1,Enum.ScaleType.Fit,false
 whole.AnchorPoint,whole.Position,whole.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(1.3,1.3)
 whole.Parent=blob
 -- The icon: the mouse asset, or the hand on touch.
 local icon=Instance.new("ImageLabel")
 icon.Name,icon.BackgroundTransparency,icon.ScaleType,icon.Visible=("Icon"),1,Enum.ScaleType.Fit,false
 icon.AnchorPoint,icon.Position,icon.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(0.74,0.74)
 icon.Parent=blob
 -- Without the asset, a mouse drawn from primitives: a dark pill with a lighter left
 -- button and a thin divider.
 local mouse=Instance.new("Frame")
 mouse.Name,mouse.BackgroundColor3,mouse.BorderSizePixel,mouse.Visible=("Mouse"),BADGE_INK,0,false
 mouse.AnchorPoint,mouse.Position,mouse.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.52),UDim2.fromScale(0.42,0.66)
 Instance.new("UICorner",mouse).CornerRadius=UDim.new(0.5,0)
 mouse.Parent=blob
 local button=Instance.new("Frame")
 button.Name,button.BackgroundColor3,button.BorderSizePixel=("LeftButton"),BADGE_KEY,0
 button.Position,button.Size=UDim2.fromScale(0.1,0.08),UDim2.fromScale(0.36,0.34)
 Instance.new("UICorner",button).CornerRadius=UDim.new(0.45,0)
 button.Parent=mouse
 local divider=Instance.new("Frame")
 divider.Name,divider.BackgroundColor3,divider.BorderSizePixel=("Divider"),BADGE_KEY,0
 divider.Position,divider.Size=UDim2.fromScale(0.5,0.06),UDim2.fromScale(0.06,0.38)
 divider.Parent=mouse
 -- Gamepad: "R2" in the blob instead of an icon, and no word under it.
 local key=Theme.Label(blob,"Key","R2",22,BADGE_INK)
 key.AnchorPoint,key.Position,key.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(0.8,0.56)
 key.TextXAlignment,key.TextScaled,key.Visible=Enum.TextXAlignment.Center,true,false
 local keyOutline=key:FindFirstChild("TextOutline") -- dark on white needs no outline
 if keyOutline and keyOutline:IsA("UIStroke") then keyOutline.Enabled=false end
 -- The word under the blob: white with the shared black outline.
 local word=Theme.Label(badge,"Word",BADGE_WORD.Keyboard,22,Color3.new(1,1,1))
 -- The word overlaps the blob's lower edge, as in the reference.
 word.AnchorPoint,word.Position,word.Size=Vector2.new(0.5,1),UDim2.fromScale(0.5,1),UDim2.fromScale(1,0.36)
 word.TextXAlignment,word.TextScaled=Enum.TextXAlignment.Center,true
 return gui,{pulse=pulse,icon=icon,mouse=mouse,key=key,word=word,blob=blob,rim=rim,whole=whole}
end

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
 local gui,label=caption(center,data.value)
 -- October 24 (Stevin): the badge sits ON the egg, centred on it, not above it.
 local tap,tapParts=tapIcon(center,0)
 local glow=body:FindFirstChild("Glow")
 if glow and glow:IsA("BasePart") then glow.CanQuery=false end
 local seed=tonumber(data.id) or 1
 body.Parent=parent
 return setmetatable({anchor=body,shell=body,body=body,glow=if glow and glow:IsA("BasePart") then glow else nil,
  base=body.Size,glowBase=if glow and glow:IsA("BasePart") then glow.Size else nil,half=half,
  twist=math.rad(((seed*37)%51)-25),trail=trail(body,center.Position),caption=gui,valueLabel=label,
  tap=tap,tapParts=tapParts,tapOn=false,tapScale=1,
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
 local captionGui,valueLabel=caption(anchor,data.value)
 local tap,tapParts=tapIcon(anchor,Config.EggSpriteSize*EggArt.Scale*0.5) -- on the sprite's centre
 anchor.Parent=parent
 return setmetatable({anchor=anchor,shell=anchor,gui=gui,image=sprite,trail=trail(anchor,Vector3.zero),caption=captionGui,valueLabel=valueLabel,
  tap=tap,tapParts=tapParts,tapOn=false,tapScale=1,
  seed=tonumber(data.id) or 1,scale=1,rotation=0,displayedValue=data.value,displayedCount=count},EggView)
end

-- The guide's Click badge (EggController): on or off, the shared pulse's scale, and the
-- player's input ("Touch", "Gamepad", anything else is mouse and keyboard) for its icon
-- and word. The badge is restyled only when the input changes.
function EggView:SetTap(on: boolean,scale: number,input: string?)
 if self.tapOn~=on then self.tapOn=on;self.tap.Enabled=on end
 if not on then return end
 local parts=self.tapParts
 if math.abs(scale-self.tapScale)>0.005 then
  self.tapScale=scale
  parts.pulse.Scale=scale
 end
 local kind=if input=="Touch" or input=="Gamepad" then input else "Keyboard"
 if kind==self.tapInput then return end
 self.tapInput=kind
 local touch,pad=kind=="Touch",kind=="Gamepad"
 -- The reference badge as one image when it is set; else the blob frame with an icon.
 local wholeImage=if pad then "" elseif touch then TAP_BADGE else CLICK_BADGE
 local whole=wholeImage~=""
 parts.whole.Image,parts.whole.Visible=wholeImage,whole
 parts.blob.BackgroundTransparency=if whole then 1 else 0
 parts.rim.Enabled=not whole
 parts.icon.Image=if touch then TAP_HAND else CLICK_ICON
 parts.icon.Visible=not whole and not pad and parts.icon.Image~=""
 parts.mouse.Visible=not whole and not pad and not touch and CLICK_ICON==""
 parts.key.Visible=pad
 parts.word.Visible=not pad
 parts.word.Text=BADGE_WORD[kind]
end

function EggView:SetValue(value,count)
 count=count or 1
 if self.displayedValue==value and self.displayedCount==count then return end
 self.displayedValue,self.displayedCount=value,count
 self.anchor:SetAttribute("CoinValue",value)
 self.anchor:SetAttribute("EggCount",count)
 self.valueLabel.Text=worth(value)
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
