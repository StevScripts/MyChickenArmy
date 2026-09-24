--!strict
-- Shared menu portraits, with a model preview for birds without a captured image.
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Portraits=require(script.Parent.ChickenPortraits)
local Preview={}
local DIRECTION=Vector3.new(1.15,0.55,1.55).Unit
local ROTATION=CFrame.lookAt(Vector3.zero,-DIRECTION)
local FILL=0.9

function Preview.Create(parent,pet,size,position)
 local image=Portraits[pet.species]
 if type(image)=="string" and image~="" then
  local portrait=Instance.new("ImageLabel")
  portrait.Name,portrait.Size,portrait.Position="ChickenPreview",size,position or UDim2.new()
  portrait.BackgroundTransparency,portrait.ZIndex=1,3
  portrait.Image,portrait.ImageColor3=image,Color3.new(1,1,1)
  portrait.ScaleType=Enum.ScaleType.Fit
  portrait.Parent=parent
  return portrait
 end
 local PetView=require(Shared.PetView)
 local viewport=Instance.new("ViewportFrame")
 viewport.Name,viewport.Size,viewport.Position="ChickenPreview",size,position or UDim2.new()
 viewport.BackgroundTransparency,viewport.ZIndex=1,3
 viewport.Ambient=Color3.fromRGB(180,184,170)
 viewport.LightColor,viewport.LightDirection=Color3.fromRGB(255,249,214),Vector3.new(-1,-1,-2)
 viewport.Parent=parent
 local world=Instance.new("WorldModel");world.Parent=viewport
 local model=PetView.Create(world,"Preview",pet.species,pet.stars or 1,Vector3.zero)
 local points={}
 local minX,minY,minZ=math.huge,math.huge,math.huge
 local maxX,maxY,maxZ=-math.huge,-math.huge,-math.huge
 for _,part in model:GetDescendants() do
  if part:IsA("BillboardGui") then part:Destroy()
  elseif part:IsA("BasePart") and part.Transparency<1 then
   for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
    local point=ROTATION:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)*0.5))
    table.insert(points,point)
    minX,minY,minZ=math.min(minX,point.X),math.min(minY,point.Y),math.min(minZ,point.Z)
    maxX,maxY,maxZ=math.max(maxX,point.X),math.max(maxY,point.Y),math.max(maxZ,point.Z)
   end end end
  end
 end
 local center=if #points>0 then Vector3.new((minX+maxX)/2,(minY+maxY)/2,(minZ+maxZ)/2) else Vector3.zero
 local focus=ROTATION:PointToWorldSpace(center)
 local camera=Instance.new("Camera")
 camera.FieldOfView,camera.FieldOfViewMode=33,Enum.FieldOfViewMode.Vertical
 camera.Parent,viewport.CurrentCamera=viewport,camera
 local function fit()
  local dimensions=viewport.AbsoluteSize
  local aspect=if dimensions.Y>0 and dimensions.X>0 then dimensions.X/dimensions.Y else 1
  local vertical=math.tan(math.rad(camera.FieldOfView/2))*FILL
  local horizontal=vertical*aspect
  local distance=0.5
  for _,point in points do
   local relative=point-center
   distance=math.max(distance,relative.Z+math.abs(relative.X)/horizontal,
    relative.Z+math.abs(relative.Y)/vertical,relative.Z+0.2)
  end
  -- These imported meshes include generous empty corners in their rest bounds.
  -- Calibrated in Studio with common, horned, winged and tall-hat chickens.
  if model:GetAttribute("SkinnedChicken") and not model:GetAttribute("ChickenVisualV3") then distance*=0.72 end
  camera.CFrame=CFrame.lookAt(focus+DIRECTION*distance,focus)
 end
 fit()
 local connection=viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
 viewport.Destroying:Once(function() connection:Disconnect() end)
 return viewport
end

return Preview
