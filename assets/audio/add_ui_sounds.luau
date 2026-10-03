-- Run in canonical Studio Edit. Existing native IDs/settings remain intact.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning())
local library=game.SoundService.MyChickenArmyAudio
local function folder(parent,name)
 local f=parent:FindFirstChild(name)
 if not f then f=Instance.new("Folder");f.Name=name;f.Parent=parent end
 return f
end
local vfx=folder(library,"VFX")
local ui,tree=folder(vfx,"UI"),folder(vfx,"SkillTree")
local function cue(parent,name,key,usage,existing,copy)
 local sound=parent:FindFirstChild(name)
 if not sound then
  sound=existing or (copy and copy:Clone()) or Instance.new("Sound")
  if not existing and not copy then sound.Volume=.25;sound.SoundId="" end
  sound.Name=name;sound.Parent=parent
 end
 assert(sound:IsA("Sound"))
 sound.Looped=false;sound.PlayOnRemove=false;sound.SoundGroup=library.Mix.Effects
 sound:SetAttribute("AudioCue",key);sound:SetAttribute("Usage",usage.." Empty SoundId stays silent.")
 return sound
end
cue(ui,"Hover","UIHover","Mouse hover or gamepad focus on UI buttons.")
cue(ui,"Click","Click","Existing UI button clicks.",library.Interface:FindFirstChild("Click"))
cue(ui,"Pop","Pop","Existing UI pop feedback.",library.Interface:FindFirstChild("Pop"))
local purchase=cue(ui,"Purchase","UIPurchase","Confirmed chicken purchases and cash upgrades.",library.Collection:FindFirstChild("ChickenPurchase"))
local failure=cue(ui,"Error","Error","General failed-action notifications.",library.Collection:FindFirstChild("Error"))
cue(tree,"Hover","SkillTreeHover","Hover/focus on skill-tree buttons.")
cue(tree,"Purchase","SkillTreePurchase","Server-confirmed instant skill-tree cash upgrade.",nil,purchase)
cue(tree,"Error","SkillTreeError","Skill-tree validation errors and denied purchases.",nil,failure)
cue(tree,"NodeAdded","SkillTreeNodeAdded","A new node or frontier is revealed after progression, once per wave; not when opening the tree.")
cue(tree,"NodePop","SkillTreeNodePop","Each node starts scaling in during the opening animation. Use a short pop or tick.")
cue(tree,"ResearchStarted","SkillTreeResearchStarted","Server confirms a timed research purchase.")
cue(tree,"ResearchCompleted","SkillTreeResearchCompleted","New research completion notification, once per recap.")
cue(tree,"ResearchSlotAdded","SkillTreeResearchSlotAdded","Researcher capacity increases after an upgrade; not initial loading.")
cue(tree,"Open","SkillTreeOpen","Skill tree opens.")
cue(tree,"Close","SkillTreeClose","Skill tree closes.")
local result={}
for _,parent in {ui,tree} do for _,s in parent:GetChildren() do table.insert(result,{path=s:GetFullName(),id=s.SoundId,cue=s:GetAttribute("AudioCue")}) end end
return result
