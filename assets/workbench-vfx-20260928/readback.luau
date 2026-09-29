assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning())
local sources=workspace.ChickenVFX_Workbench.Chickens
local assets=game.ReplicatedStorage.PetRoll.ChickenAssets
local recovery=game.ServerStorage.ChickenWorkbenchVFXRecovery20260928
local function effect(o) return o:IsA("ParticleEmitter") or o:IsA("Beam") or o:IsA("Trail") or o:IsA("Light") end
local common={"Enabled","Brightness","Color"}
local properties={
 ParticleEmitter={"Texture","Rate","Lifetime","Speed","Acceleration","Drag","Rotation","RotSpeed","SpreadAngle","EmissionDirection","Size","Transparency","LightEmission","LightInfluence","LockedToPart","Orientation","Shape","ShapeInOut","ShapePartial","ShapeStyle","Squash","TimeScale","VelocityInheritance","WindAffectsDrag","ZOffset","FlipbookLayout","FlipbookMode","FlipbookFramerate","FlipbookStartRandom","FlipbookSizeX","FlipbookSizeY"},
 Beam={"Texture","TextureLength","TextureMode","TextureSpeed","Color","Transparency","Width0","Width1","CurveSize0","CurveSize1","Segments","FaceCamera","LightEmission","LightInfluence","ZOffset"},
 Trail={"Texture","TextureLength","TextureMode","Lifetime","MinLength","MaxLength","WidthScale","Transparency","LightEmission","LightInfluence","FaceCamera"},
 PointLight={"Range","Shadows"},SpotLight={"Range","Shadows","Angle","Face"},SurfaceLight={"Range","Shadows","Angle","Face"}}
local function path(o,m)
 local p={} while o~=m do table.insert(p,1,o.Name.."["..o.ClassName.."]") o=o.Parent end
 return table.concat(p,"/")
end
local function describe(m)
 local lines={}
 for _,o in m:GetDescendants() do if effect(o) then
  local row={path(o,m)}
  for _,p in common do local ok,v=pcall(function()return o[p]end) if ok then table.insert(row,p.."="..tostring(v)) end end
  for _,p in properties[o.ClassName] or {} do local ok,v=pcall(function()return o[p]end) if ok then table.insert(row,p.."="..tostring(v)) end end
  local parent=o.Parent
  while parent~=m and not parent:IsA("BasePart") and not parent:IsA("Bone") do
   if parent:IsA("Attachment") then table.insert(row,"anchor="..tostring(parent.CFrame)) end
   parent=parent.Parent
  end
  if o:IsA("Beam") or o:IsA("Trail") then
   for _,p in {"Attachment0","Attachment1"} do
    assert(o[p] and o[p]:IsDescendantOf(m),"Missing/external endpoint")
    table.insert(row,p.."="..path(o[p],m)..":"..tostring(o[p].CFrame))
   end
  end
  table.insert(lines,table.concat(row,"|"))
 end end
 table.sort(lines) return table.concat(lines,"\n"),#lines
end
local report,total={},0
for _,source in sources:GetChildren() do if source:IsA("Model") then
 local species=source:GetAttribute("Species")
 local before=recovery.Before:FindFirstChild(species)
 if before then
  local target=assets[species]
  local expected=source:Clone() expected:ScaleTo(target:GetScale())
  local expectedState,expectedCount=describe(expected)
  local actualState,actualCount=describe(target)
  expected:Destroy()
  assert(expectedState==actualState,"Effect properties differ: "..species)
  local backup=recovery.WorkbenchSource[species]
  local originalState=describe(backup) local currentState=describe(source)
  assert(originalState==currentState and backup:GetScale()==source:GetScale(),"Workbench changed: "..species)
  local geometry=0
  for _,part in before:GetDescendants() do if part:IsA("BasePart") or part:IsA("Bone") then
   local route={} local at=part while at~=before do table.insert(route,1,at.Name) at=at.Parent end
   local found=target for _,name in route do found=assert(found:FindFirstChild(name),"Missing geometry") end
   assert(found.ClassName==part.ClassName and found.CFrame==part.CFrame,"Rig changed")
   if part:IsA("BasePart") then assert(found.Size==part.Size,"Size changed") end
   if part:IsA("MeshPart") then assert(found.MeshId==part.MeshId and found.TextureID==part.TextureID,"Art changed") end
   geometry+=1
  end end
  assert(target:GetScale()==before:GetScale() and target:GetPivot()==before:GetPivot(),"Template moved")
  total+=actualCount
  table.insert(report,{species=species,effects=actualCount,geometryNodes=geometry,propertiesMatch=true,workbenchUnchanged=true,rigUnchanged=true})
 end
end end
table.sort(report,function(a,b)return a.species<b.species end)
return {models=report,totalEffects=total,templates=#report,place=game.PlaceId,editOnly=true,recovery=recovery:GetFullName()}
