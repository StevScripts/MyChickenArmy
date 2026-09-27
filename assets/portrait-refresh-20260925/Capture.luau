-- Edit-only Photobooth workflow. Clone visual models; never touch source art or the map.
local root=game.ServerStorage.PortraitRecapture20260925
local fresh=Instance.new("Folder");fresh.Name="FreshModules";fresh.Parent=root
local Shared=game.ReplicatedStorage.PetRoll.Shared:Clone();Shared.Parent=fresh
local assets=game.ReplicatedStorage.PetRoll.ChickenAssets:Clone();assets.Parent=fresh
local PetView=require(Shared.PetView)
local Catalog=require(Shared.PetCatalog)
local bindable=root.Bindings.Binding.Bindable
local Photobooth=setmetatable({}, {__index=function(_,key)
 return function(...) local r=table.pack(bindable:Invoke(key,...));assert(r[1],r[2]);return table.unpack(r,2,r.n) end
end})
local Http=game:GetService("HttpService")
local Selection=game:GetService("Selection")
local Capture={}
local DIRECTION=Vector3.new(1.15,0.55,1.55).Unit
local ROTATION=CFrame.lookAt(Vector3.zero,-DIRECTION)
local STAGE=Vector3.new(0,100,-4000)
local FILL=0.9

function Capture.One(species)
 assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning(),"Requires Pet Roll Test Edit")
 assert(Catalog[species],"Unknown chicken")
 assert(Photobooth.isConnected(),"Photobooth bindings not connected")
 local output=game.StarterGui:FindFirstChild("ChickenPortraitRecaptures20260925")
 if not output then output=Instance.new("Folder");output.Name="ChickenPortraitRecaptures20260925";output.Parent=game.StarterGui end
 assert(not output:FindFirstChild(species),"Already captured; preserve existing result")
 local camera=workspace.CurrentCamera
 local quality=settings().Rendering.EditQualityLevel
 local saved={cf=camera.CFrame,focus=camera.Focus,fov=camera.FieldOfView,kind=camera.CameraType,selection=Selection:Get()}
 local screens={}
 local model
 local ok,result=xpcall(function()
  settings().Rendering.EditQualityLevel=Enum.QualityLevel.Level21
  Selection:Set({})
  for _,gui in game.StarterGui:GetChildren() do
   if gui:IsA("ScreenGui") then screens[gui]=gui.Enabled;gui.Enabled=false end
  end
  model=PetView.Create(workspace,"PhotoboothChicken20260925",species,1,STAGE)
  for _,item in model:GetDescendants() do
   if item:IsA("BillboardGui") or item:IsA("SurfaceGui") then item:Destroy()
   elseif item:IsA("BasePart") then item.Anchored=true;item.CanQuery=false
    if item:IsA("MeshPart") then item.RenderFidelity=Enum.RenderFidelity.Precise end
   elseif item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") then item.Enabled=false end
  end
  game:GetService("ContentProvider"):PreloadAsync({model})
  local points={}
  local min=Vector3.new(math.huge,math.huge,math.huge)
  local max=Vector3.new(-math.huge,-math.huge,-math.huge)
  for _,part in model:GetDescendants() do
   if part:IsA("BasePart") and part.Transparency<1 then
    for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
     local p=ROTATION:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z)*0.5)-STAGE)
     table.insert(points,p);min=min:Min(p);max=max:Max(p)
    end end end
   end
  end
  assert(#points>0,"Empty visual")
  local center=(min+max)*0.5
  local viewport=camera.ViewportSize
  local side=math.min(512,math.floor(math.min(viewport.X,viewport.Y)-24))
  assert(side>=256,"Studio viewport too small")
  local start=Vector2.new(math.floor((viewport.X-side)/2),math.floor((viewport.Y-side)/2))
  local rect=Rect.new(start,start+Vector2.one*side)
  camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=33
  local extent=math.tan(math.rad(camera.FieldOfView/2))*(side/viewport.Y)*FILL
  local distance=0.5
  for _,point in points do
   local p=point-center
   distance=math.max(distance,p.Z+math.abs(p.X)/extent,p.Z+math.abs(p.Y)/extent,p.Z+0.2)
  end
  local focus=STAGE+ROTATION:PointToWorldSpace(center)
  -- The Jockey rider's deformed bones extend above the rest-pose mesh bounds.
  -- Offset framing upward by one tenth of the square's visible height.
  if species=="Jockey" then focus+=ROTATION.UpVector*(2*distance*math.tan(math.rad(camera.FieldOfView/2))*(side/viewport.Y)*0.10) end
  camera.CFrame=CFrame.lookAt(focus+DIRECTION*distance,focus);camera.Focus=CFrame.new(focus)
  Photobooth.yieldUntilNextFrame()
  task.wait(1)
  local captured=assert(Photobooth.captureViewport({rect=rect,type="NoSkybox",delay=1.5,alphaBleed=false}),"Capture failed")
  captured.Name=species;captured.Parent=output
  captured:SetAttribute("Species",species);captured:SetAttribute("DisplayName",Catalog[species].name)
  return {species=species,path=captured:GetFullName(),rectSize=side,osScale=tostring(Photobooth.getOSScale())}
 end,debug.traceback)
 if model then model:Destroy() end
 for gui,enabled in screens do if gui.Parent then gui.Enabled=enabled end end
 settings().Rendering.EditQualityLevel=quality
 camera.CFrame,camera.Focus,camera.FieldOfView,camera.CameraType=saved.cf,saved.focus,saved.fov,saved.kind
 Selection:Set(saved.selection)
 assert(ok,result)
 return result
end

function Capture.Export(species)
 local captured=game.StarterGui.ChickenPortraitRecaptures20260925:FindFirstChild(species)
 assert(captured,"Missing capture")
 local image=captured.TextureContent.Object
 assert(image and image:IsA("EditableImage"),"Capture is not an editable image")
 local size=image.Size
 local response=Http:RequestAsync({Url="http://127.0.0.1:18794/pixels/"..species.."?w="..size.X.."&h="..size.Y,
  Method="POST",Headers={["Content-Type"]="application/octet-stream"},Body=buffer.tostring(image:ReadPixelsBuffer(Vector2.zero,size))})
 assert(response.Success,response.StatusMessage)
 return Http:JSONDecode(response.Body)
end

return Capture
