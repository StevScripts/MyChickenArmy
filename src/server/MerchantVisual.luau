--!strict
-- Decorative market keeper. The stand owns its lifetime and interaction prompt.
local Merchant={}
function Merchant.Create(parent,frame)
 local model=Instance.new("Model")
 model.Name,model.Parent="Merchant",parent
 local function part(name,size,at,color)
  local p=Instance.new("Part")
  p.Name,p.Size,p.CFrame=name,size,frame*at
  p.Color,p.Material=color,Enum.Material.SmoothPlastic
  p.Anchored,p.CanCollide,p.CanTouch,p.CanQuery=true,false,false,false
  p.TopSurface,p.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
  p.Parent=model;return p
 end
 local skin=Color3.fromRGB(255,216,138)
 local olive=Color3.fromRGB(78,113,42)
 local dark=Color3.fromRGB(39,53,31)
 part("LeftLeg",Vector3.new(0.72,1.6,0.85),CFrame.new(-0.44,0.8,0),dark)
 part("RightLeg",Vector3.new(0.72,1.6,0.85),CFrame.new(0.44,0.8,0),dark)
 part("Torso",Vector3.new(1.85,1.85,1),CFrame.new(0,2.45,0),olive)
 part("Apron",Vector3.new(1.45,1.55,0.12),CFrame.new(0,2.35,-0.56),Color3.fromRGB(255,187,35))
 part("Pocket",Vector3.new(0.8,0.48,0.1),CFrame.new(0,2.2,-0.65),Color3.fromRGB(218,135,26))
 part("LeftArm",Vector3.new(0.65,1.55,0.7),CFrame.new(-1.22,2.4,-0.22)*CFrame.Angles(math.rad(-20),0,math.rad(-8)),skin)
 part("RightArm",Vector3.new(0.65,1.55,0.7),CFrame.new(1.22,2.4,-0.22)*CFrame.Angles(math.rad(-20),0,math.rad(8)),skin)
 local head=part("Head",Vector3.new(1.5,1.25,1.35),CFrame.new(0,4.0,0),skin)
 local face=Instance.new("Decal")
 face.Face,face.Texture,face.Parent=Enum.NormalId.Front,"rbxasset://textures/face.png",head
 part("Cap",Vector3.new(1.6,0.48,1.45),CFrame.new(0,4.7,0),olive)
 part("CapBrim",Vector3.new(1.65,0.15,0.7),CFrame.new(0,4.5,-0.9),dark)
 model.PrimaryPart=head
 return model
end
return Merchant
