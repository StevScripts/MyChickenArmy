-- Sync Studio-owned VFX only. Preserve source models, template geometry and bones.
assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning())
local sources = workspace.ChickenVFX_Workbench.Chickens
local assets = game.ReplicatedStorage.PetRoll.ChickenAssets
local recoveryName = "ChickenWorkbenchVFXRecovery20260928"
assert(not game.ServerStorage:FindFirstChild(recoveryName), "Transfer already has a recovery snapshot")

local function isEffect(item)
 return item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail") or item:IsA("Light")
end

local function counts(model)
 local result = {}
 for _, item in model:GetDescendants() do
  if isEffect(item) then result[item.ClassName] = (result[item.ClassName] or 0) + 1 end
 end
 return result
end

-- Copy effect subtrees under their original mesh/bone anchor, never the rig itself.
-- Separately parented Beam/Trail endpoints belong to the same transfer.
local function roots(model, requireEndpoints)
 local selected = {}
 local function include(item)
  assert(item:IsDescendantOf(model), "VFX references outside " .. model.Name)
  if item:IsA("Bone") then return end
  local root = item
  while root.Parent ~= model and not root.Parent:IsA("BasePart") and not root.Parent:IsA("Bone") do
   root = root.Parent
  end
  assert(not root:IsA("BasePart") and not root:IsA("Bone"), "VFX requires geometry review")
  assert(root.Parent:IsA("BasePart") or root.Parent:IsA("Bone"), "VFX needs a mesh/bone anchor")
  selected[root] = true
 end
 for _, item in model:GetDescendants() do
  if isEffect(item) then
   include(item)
   if item:IsA("Beam") or item:IsA("Trail") then
    if requireEndpoints then
     assert(item.Attachment0 and item.Attachment1, "Missing endpoint: " .. item:GetFullName())
    end
    if item.Attachment0 then include(item.Attachment0) end
    if item.Attachment1 then include(item.Attachment1) end
   end
  end
 end
 local result = {}
 for item in selected do table.insert(result, item) end
 return result
end

local function matchingAnchor(item, from, to)
 if item == from then return to end
 local parent = matchingAnchor(item.Parent, from, to)
 local found
 for _, child in parent:GetChildren() do
  if child.Name == item.Name and child.ClassName == item.ClassName then
   assert(not found, "Ambiguous rig anchor: " .. item:GetFullName())
   found = child
  end
 end
 assert(found, "Missing rig anchor: " .. item:GetFullName())
 return found
end

local staged, seen = {}, {}
local ok, failure = xpcall(function()
 for _, source in sources:GetChildren() do
  if not source:IsA("Model") then continue end
  local species = assert(source:GetAttribute("Species"), "Missing species")
  assert(not seen[species], "Duplicate species " .. species)
  seen[species] = true
  local target = assert(assets:FindFirstChild(species), "Missing template " .. species)
  local oldRoots, sourceRoots = roots(target), roots(source, true)
  if #oldRoots == 0 and #sourceRoots == 0 then continue end
  local clone = source:Clone()
  local row = {species=species, source=source, target=target, clone=clone,
   oldRoots=oldRoots, before=counts(target), anchors={}, endpoints={}, geometry={}}
  table.insert(staged, row)
  clone:ScaleTo(target:GetScale())
  row.newRoots = roots(clone, true)
  row.after = counts(clone)
  row.scale, row.pivot = target:GetScale(), target:GetPivot()
  for _, item in target:GetDescendants() do
   if item:IsA("BasePart") then
    table.insert(row.geometry, {item=item, parent=item.Parent, size=item.Size, frame=item.CFrame,
     mesh=if item:IsA("MeshPart") then item.MeshId else nil})
   elseif item:IsA("Bone") then
    table.insert(row.geometry, {item=item, parent=item.Parent, frame=item.CFrame})
   end
  end
  for _, root in row.newRoots do
   row.anchors[root] = matchingAnchor(root.Parent, clone, target)
   local items = root:GetDescendants()
   table.insert(items, root)
   for _, item in items do
    assert(not item:IsA("BasePart") and not item:IsA("Bone") and not item:IsA("LuaSourceContainer"),
     "Unexpected rig, geometry or script inside VFX")
    if item:IsA("Beam") or item:IsA("Trail") then
     for _, property in {"Attachment0", "Attachment1"} do
      local endpoint = item[property]
      if endpoint:IsA("Bone") then
       table.insert(row.endpoints, {effect=item, property=property,
        target=matchingAnchor(endpoint, clone, target)})
      end
     end
    end
   end
  end
 end
end, debug.traceback)
if not ok then
 for _, row in staged do row.clone:Destroy() end
 error(failure)
end

-- Complete before-images remain available even if a later operation fails.
local recovery = Instance.new("Folder")
recovery.Name = recoveryName
local before, authored = Instance.new("Folder"), Instance.new("Folder")
before.Name, before.Parent = "Before", recovery
authored.Name, authored.Parent = "WorkbenchSource", recovery
for _, row in staged do
 row.target:Clone().Parent = before
 local copy = row.source:Clone()
 copy.Name, copy.Parent = row.species, authored
end
recovery.Parent = game.ServerStorage

local detached = {}
local applied, applyError = xpcall(function()
 for _, row in staged do
  for _, root in row.oldRoots do
   table.insert(detached, {root=root, parent=root.Parent})
   root.Parent = nil
  end
  for _, root in row.newRoots do root.Parent = row.anchors[root] end
  for _, endpoint in row.endpoints do endpoint.effect[endpoint.property] = endpoint.target end
  for _, item in row.target:GetDescendants() do
   if item:IsA("Beam") or item:IsA("Trail") then
    assert(item.Attachment0:IsDescendantOf(row.target) and item.Attachment1:IsDescendantOf(row.target),
     "Endpoint escaped destination")
   end
  end
  for class, count in row.after do assert(counts(row.target)[class] == count, "Effect count mismatch") end
  for class, count in counts(row.target) do assert(row.after[class] == count, "Extra effects remain") end
  assert(row.target:GetScale() == row.scale and row.target:GetPivot() == row.pivot, "Template transform changed")
  for _, saved in row.geometry do
   local item = saved.item
   assert(item.Parent == saved.parent and item.CFrame == saved.frame, "Rig anchor changed")
   if saved.size then assert(item.Size == saved.size, "Geometry changed") end
   if saved.mesh then assert(item.MeshId == saved.mesh, "Mesh changed") end
  end
 end
end, debug.traceback)
if not applied then
 for _, row in staged do for _, root in row.newRoots do root:Destroy() end end
 for _, entry in detached do entry.root.Parent = entry.parent end
 for _, row in staged do row.clone:Destroy() end
 error("VFX transfer rolled back: " .. tostring(applyError))
end
for _, entry in detached do entry.root:Destroy() end
local report = {}
for _, row in staged do
 table.insert(report, {species=row.species, name=row.source.Name, source=row.source:GetFullName(),
  destination=row.target:GetFullName(), sourceScale=row.source:GetScale(), templateScale=row.scale,
  before=row.before, after=counts(row.target), roots=#row.newRoots})
 row.clone:Destroy()
end
table.sort(report, function(a,b) return a.species < b.species end)
game:GetService("ChangeHistoryService"):SetWaypoint("Sync September 28 chicken VFX")
return {recovery=recovery:GetFullName(), models=report, geometryPreserved=true, playtest=false, published=false}
