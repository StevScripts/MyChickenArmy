-- Copy authored effects only; existing rig and material templates stay authoritative.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning(),"Expected canonical Edit target")
local preview=workspace.GalaxyCratePreview
local assets=game.ReplicatedStorage.PetRoll.ChickenAssets
local name="GalaxyCrateVFXIntegration20261006"
assert(not game.ServerStorage:FindFirstChild(name),"Integration backup already exists; inspect before repeating")
local pairsList={
 {"Astronaut","astronaut_RetexturedBody","Astronaut","Body"},
 {"Alien","Body","Alien","Body"},
 {"Galaxy","Body","StormDuck","Body"},
 {"DarkMatter","Body","DarkMatter","Body"},
 {"DragonChickenFlight","DragonChickenMesh","CosmicDragon","DragonChickenMesh"},
}
local function isEffect(v) return v:IsA("ParticleEmitter") or v:IsA("Beam") or v:IsA("Trail") or v:IsA("Light") end
local function isRoot(v)
 if isEffect(v) then return true end
 if v:IsA("Bone") then return false end
 if v:IsA("Attachment") then for _,d in v:GetDescendants() do if isEffect(d) then return true end end end
 return false
end
-- Validate all mesh identities and effect roots before changing templates.
for _,p in pairsList do
 local src=preview[p[1]][p[2]];local dst=assets[p[3]][p[4]]
 assert(src:IsA("MeshPart") and dst:IsA("MeshPart"))
 assert((src.Size-dst.Size).Magnitude<.001,"Source/target mesh scale differs")
 local n=0;for _,c in src:GetChildren() do if isRoot(c) then n+=1 end end;assert(n>0,"Missing source effects")
end
local backup=Instance.new("Folder");backup.Name=name
local before=Instance.new("Folder");before.Name="Before";before.Parent=backup
local source=Instance.new("Folder");source.Name="SourceLineup";source.Parent=backup
for _,p in pairsList do assets[p[3]]:Clone().Parent=before;preview[p[1]]:Clone().Parent=source end
backup:SetAttribute("Source","Workspace.GalaxyCratePreview")
backup:SetAttribute("CreatedAt",os.date("!%Y-%m-%dT%H:%M:%SZ"))
backup.Parent=game.ServerStorage
local results={}
for _,p in pairsList do
 local src=preview[p[1]][p[2]];local model=assets[p[3]];local dst=model[p[4]]
 local old={};for _,c in dst:GetChildren() do if isRoot(c) then table.insert(old,c) end end
 for _,c in old do c:Destroy() end
 local added={}
 for _,c in src:GetChildren() do if isRoot(c) then local copy=c:Clone();copy.Parent=dst;table.insert(added,copy) end end
 local counts={particles=0,beams=0,carriers=0}
 for _,root in added do
  local nodes={root};for _,v in root:GetDescendants() do table.insert(nodes,v) end
  for _,v in nodes do
   if isEffect(v) then v:SetAttribute("ImportedEffectEnabled",nil);v:SetAttribute("GalaxyCrateAuthoredVFX",true) end
   if v:IsA("ParticleEmitter") then counts.particles+=1 end
   if v:IsA("Beam") or v:IsA("Trail") then
    assert(v.Attachment0 and v.Attachment0:IsDescendantOf(model),"External effect endpoint 0")
    assert(v.Attachment1 and v.Attachment1:IsDescendantOf(model),"External effect endpoint 1")
    if v:IsA("Beam") then counts.beams+=1 end
   elseif v:IsA("BasePart") then
    -- The pasted dragon beam carrier was still at the donor pack's position.
    -- Center it on its authored mesh attachment; factory owns the moving joint.
    assert(p[3]=="CosmicDragon" and v.Name=="Central","Unexpected cosmetic carrier")
    v.CFrame=if v.Parent:IsA("Attachment") then v.Parent.WorldCFrame else dst.CFrame
    v.Anchored=false;v.Massless=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false
    v:SetAttribute("GalaxyVFXCarrier",true)
    counts.carriers+=1
   end
  end
 end
 model:SetAttribute("VFXRevision","GalaxyLineup20261006")
 table.insert(results,{species=p[3],roots=#added,counts=counts})
end
return {backup=backup:GetFullName(),updated=results}
