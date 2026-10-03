-- Studio Edit-only authoring recipe; preserves existing IDs and settings.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning())
local library=game.SoundService:WaitForChild("MyChickenArmyAudio")
local folder=library:FindFirstChild("VFX")
if not folder then folder=Instance.new("Folder");folder.Name="VFX";folder.Parent=library end
local names={Robo=true}
for _,model in game.ReplicatedStorage.PetRoll.ChickenAssets:GetChildren() do
 for _,effect in model:GetDescendants() do
  if effect:IsA("ParticleEmitter") or effect:IsA("Beam") or effect:IsA("Trail") or effect:IsA("Light") then
   names[model:GetAttribute("Appearance") or model.Name]=true;break
  end
 end
end
names.GlitchBurst=true
local result={}
for name in names do
 local sound=folder:FindFirstChild(name)
 if not sound then
  sound=Instance.new("Sound");sound.Name=name;sound.SoundId=""
  sound.Volume=0.15;sound.Looped=name~="GlitchBurst"
  sound.RollOffMode=Enum.RollOffMode.InverseTapered
  sound.RollOffMinDistance=8;sound.RollOffMaxDistance=42
  sound.SoundGroup=library.Mix.Effects;sound.Parent=folder
 end
 assert(sound:IsA("Sound"),name.." must be a Sound")
 sound:SetAttribute("AudioCue","VFX_"..name)
 sound:SetAttribute("Usage",if name=="GlitchBurst" then "One shot when the Glitch chicken breaks apart. Blank SoundId is silent."
  else "Spatial loop while nearby "..name.." chicken VFX are visible. Blank SoundId is silent; edit Volume and PlaybackSpeed here.")
 table.insert(result,{name=name,id=sound.SoundId})
end
table.sort(result,function(a,b)return a.name<b.name end)
return result
