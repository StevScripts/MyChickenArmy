-- Studio-owned art transfer only; no source, play state, save or publication.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning())
local source=workspace.ChickenVFX_Workbench.Chickens
local assets=game.ReplicatedStorage.PetRoll.ChickenAssets
local storage=game.ServerStorage
local species={"Knight","Frost","Wizard","Diamond","Dragon","IceDuck","StormDuck","Storm"}
local recoveryName="ChickenWorkbenchVFXRecovery20260927"
assert(not storage:FindFirstChild(recoveryName),"Recovery already exists; inspect before reapplying")
local function isEffect(o)
 return o:IsA("ParticleEmitter") or o:IsA("Beam") or o:IsA("Trail")
end
local function roots(model)
 local list={}
 for _,child in model.Body:GetChildren() do
  local keep=isEffect(child)
  if child:IsA("Attachment") and not child:IsA("Bone") then
   for _,o in child:GetDescendants() do if isEffect(o) then keep=true;break end end
   -- Retain any separate endpoints referenced from another effect root.
   if not keep then
    for _,o in model:GetDescendants() do
     if (o:IsA("Beam") or o:IsA("Trail")) and (o.Attachment0==child or o.Attachment1==child) then keep=true;break end
    end
   end
  end
  if keep then table.insert(list,child) end
 end
 return list
end
local function counts(model)
 local result={ParticleEmitter=0,Beam=0,Trail=0}
 for _,o in model:GetDescendants() do if isEffect(o) then result[o.ClassName]+=1 end end
 return result
end
local staged={}
for _,key in species do
 local original
 for _,m in source:GetChildren() do if m:GetAttribute("Species")==key then assert(not original,"Duplicate species");original=m end end
 assert(original and original:IsA("Model"),"Missing source "..key)
 local target=assert(assets:FindFirstChild(key),"Missing target "..key)
 local clone=original:Clone()
 local carriers={}
 for _,root in roots(clone) do
  for _,part in root:GetDescendants() do
   assert(not part:IsA("LuaSourceContainer"),"Unexpected script in VFX")
   if part:IsA("BasePart") then
    assert(part.Name=="Central" and part.Transparency==1 and part.Parent:IsA("Attachment"),"Unexpected VFX geometry")
    local parent=part.Parent
    local relative=parent.WorldCFrame:ToObjectSpace(part.CFrame)
    assert(relative.Position.Magnitude>100,"Inspect changed carrier placement")
    local anchor=Instance.new("Attachment")
    anchor.Name=part.Name
    anchor.CFrame=relative.Rotation
    for k,v in part:GetAttributes() do anchor:SetAttribute(k,v) end
    anchor.Parent=parent
    for _,child in part:GetChildren() do
     assert(child:IsA("Attachment"),"Unexpected carrier child")
     child.Parent=anchor
    end
    table.insert(carriers,{name=part.Name,oldOffset=tostring(relative.Position),newOffset="0, 0, 0"})
    part:Destroy()
   end
  end
 end
 -- Normalize preview-scale attachments, particles and beam dimensions using
 -- the same native scaling operation used when gameplay clones the asset.
 clone:ScaleTo(target:GetScale())
 local copiedRoots=roots(clone)
 assert(#copiedRoots>0)
 local missing={}
 for _,o in clone:GetDescendants() do
  if o:IsA("Beam") or o:IsA("Trail") then
   for _,property in {"Attachment0","Attachment1"} do
    local endpoint=o[property]
    if endpoint then
     assert(endpoint:IsDescendantOf(clone),"Effect references another model")
    else
     table.insert(missing,{effect=o.Name,property=property})
    end
   end
  end
 end
 table.insert(staged,{key=key,source=original,target=target,clone=clone,roots=copiedRoots,
  before=counts(target),after=counts(clone),carriers=carriers,missing=missing})
end
local recovery=Instance.new("Folder")
recovery.Name=recoveryName
local before=Instance.new("Folder");before.Name="Before";before.Parent=recovery
local authored=Instance.new("Folder");authored.Name="WorkbenchSource";authored.Parent=recovery
for _,r in staged do
 r.target:Clone().Parent=before
 local copy=r.source:Clone();copy.Name=r.key;copy.Parent=authored
end
recovery.Parent=storage
local report={}
for _,r in staged do
 for _,old in roots(r.target) do old:Destroy() end
 for _,root in r.roots do root.Parent=r.target.Body end
 -- All cross-root beam endpoints were remapped by cloning the whole source
 -- model together; move all roots before disposing of the temporary model.
 for _,o in r.target:GetDescendants() do
  if o:IsA("Beam") or o:IsA("Trail") then
   for _,property in {"Attachment0","Attachment1"} do
    local endpoint=o[property]
    assert(not endpoint or endpoint:IsDescendantOf(r.target),"Endpoint escaped destination")
   end
  end
 end
 table.insert(report,{species=r.key,displayName=r.source.Name,destination=r.target:GetFullName(),
  sourceScale=r.source:GetScale(),templateScale=r.target:GetScale(),before=r.before,after=counts(r.target),
  convertedCarriers=r.carriers,missingEndpoints=r.missing,roots=#r.roots})
 r.clone:Destroy()
end
game:GetService("ChangeHistoryService"):SetWaypoint("Apply chicken workbench VFX")
return {recovery=recovery:GetFullName(),models=report}
