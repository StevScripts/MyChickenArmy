-- Studio Edit-only authoring recipe for fight feedback (client/CombatEffects.luau).
-- One Sound per cue under MyChickenArmyAudio.Combat; reruns keep your edits.
-- Licensed ProSoundEffects/APM library IDs, the same ones the intro cutscene uses.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning())
local library=game.SoundService:WaitForChild("MyChickenArmyAudio")
local combat=library:FindFirstChild("Combat")
if not combat then combat=Instance.new("Folder");combat.Name="Combat";combat.Parent=library end
local cues={
 {"CombatHit",9120729337,0.35,1,"A chicken takes a hit (the cutscene's guard hit). Pitch varies 0.95-1.2 in code."},
 {"CombatSwing",9120716440,0.18,1,"A chicken attacks (quick peck/whoosh). Pitch varies 1.25-1.45 in code."},
 {"CombatKnockout",9116405618,0.35,1,"Smoke poof when a chicken is knocked out."},
 {"CombatKnockoutBoing",12222124,0.3,1,"Soft boing layered on the knockout poof."},
}
local result={}
for _,cue in cues do
 local name,id,volume,speed,usage=cue[1],cue[2],cue[3],cue[4],cue[5]
 local sound=combat:FindFirstChild(name)
 if not sound then
  sound=Instance.new("Sound");sound.Name=name;sound.SoundId="rbxassetid://"..id
  sound.Volume=volume;sound.PlaybackSpeed=speed
  sound.SoundGroup=library.Mix.Effects;sound.Parent=combat
 end
 sound:SetAttribute("AudioCue",name)
 sound:SetAttribute("Usage",usage)
 table.insert(result,name)
end
return result
