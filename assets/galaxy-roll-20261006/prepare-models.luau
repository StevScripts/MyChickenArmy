assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning())
local assets=game.ReplicatedStorage.PetRoll.ChickenAssets
local staged=game.ReplicatedStorage.GalaxyCrateChickenAssets20261002
local out={}
for _,entry in {{"Astronaut","Astronaut"},{"Alien","Alien"},{"DarkMatter","DarkMatter"},{"CosmicDragon","DragonChickenFlight"}} do
 local species,source=entry[1],staged[entry[2]]
 assert(not assets:FindFirstChild(species),"Prepared model already exists: "..species)
 local model=source:Clone();model.Name=species
 if species~="CosmicDragon" then
  local body=model:FindFirstChild("Body") or model:FindFirstChild("astronaut_RetexturedBody");assert(body);body.Name="Body"
  local bone=model:FindFirstChild("Original_Root",true);assert(bone)
  if bone.Parent~=body then local world=bone.WorldCFrame;bone.Parent=body;bone.CFrame=body.CFrame:ToObjectSpace(world) end
  if species=="Alien" then
   for _,name in {"Original_HatSocket","Original_FaceSocket","Original_WingSocket_L","Original_WingSocket_R","Original_BackSocket","Original_ChestSocket"} do
    local original=staged.DarkMatter:FindFirstChild(name,true);assert(original)
    local parent=model:FindFirstChild(original.Parent.Name,true);assert(parent)
    local socket=original:Clone();socket.Parent=parent
   end
  end
  -- Each imported surface needs the same skin hierarchy for shared clip playback.
  for _,surface in model:GetChildren() do
   if surface:IsA("MeshPart") and surface~=body and not surface:FindFirstChildWhichIsA("Bone") then
    local mirror=bone:Clone();local world=bone.WorldCFrame;mirror.Parent=surface;mirror.CFrame=surface.CFrame:ToObjectSpace(world)
   end
  end
  for _,item in model:GetDescendants() do if item:IsA("JointInstance") or item:IsA("WeldConstraint") then item:Destroy() end end
  local old=model:FindFirstChild("RootPart");if old then old:Destroy() end
  local controller=model:FindFirstChildOfClass("AnimationController");if controller then controller:Destroy() end
  model.PrimaryPart=body
  body.PivotOffset=body.CFrame:ToObjectSpace(CFrame.identity)
  model.WorldPivot=CFrame.identity
  -- Existing gameplay clip constructors rotate a +Z-authored mesh toward -Z.
  model:PivotTo(CFrame.Angles(0,math.pi,0))
  body.PivotOffset=body.CFrame:ToObjectSpace(CFrame.identity)
  model:SetAttribute("GameplayForwardNormalized",true)
 end
 if species=="CosmicDragon" then
  for _,name in {"Animations","InitialPoses","AnimSaves","HookupNotes"} do
   local authoring=model:FindFirstChild(name);if authoring then authoring:Destroy() end
  end
 end
 model:SetAttribute("IntegrationStatus","GameplayEnabled")
 model:SetAttribute("SourceTemplate",source:GetFullName())
 model.Parent=assets
 table.insert(out,{species=species,scale=model:GetScale(),bones=#model:GetDescendants()})
end
return game.HttpService:JSONEncode(out)
