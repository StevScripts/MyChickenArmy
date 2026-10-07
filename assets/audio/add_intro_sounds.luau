-- Studio Edit-only authoring recipe for the first-visit intro cutscene.
-- One Sound per moment, grouped by scene so each can be edited on its own.
-- Edit SoundId, Volume and PlaybackSpeed in Properties; reruns keep your edits.
-- Licensed ProSoundEffects/APM library IDs (plus copies of two game sounds).
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning())
local library=game.SoundService:WaitForChild("MyChickenArmyAudio")
local intro=library:FindFirstChild("Intro")
if not intro then intro=Instance.new("Folder");intro.Name="Intro";intro.Parent=library end
-- The first version kept one flat Sound per file; scene folders replace it.
for _,child in intro:GetChildren() do
 if child:IsA("Sound") then child:Destroy() end
end
local BOOM,SHIMMER,POP,SWISH=1837830192,9116395089,9117841338,9120716440
local BOING,JINGLE=12222124,9045119921
local scenes={
 {"1_Island",{
  {"KingAppears",BOOM,0.5,1,"The giant King flaps his wings."},
  {"CrownGlint",SHIMMER,0.45,1,"Sparkle on the King's crown."},
 }},
 {"2_Dreamer",{
  {"EggLaid",POP,0.45,1,"The hero hops and lays its egg."},
  {"LookPunchIn",SWISH,0.4,1.2,"Hero's point of view snaps in toward the King."},
  {"RushToKing",9126228850,0.5,1,"Camera rushes across the island to the King."},
  {"KingCrownGlint",SHIMMER,0.45,1,"Glint on the crown when the rush arrives."},
  {"HeroExclaim",POP,0.45,1.15,"Gold '!' over the hero."},
  {"HeroVictory",140096937597354,0.25,1,"Hero's Victory pose (copy of Combat.Victory)."},
 }},
 {"4_Bonk",{
  {"GuardsTurn",BOOM,0.5,1,"The three guards turn around with red '!'."},
  {"HeroPeck",SWISH,0.4,1.3,"The hero pecks at the guards."},
  {"GuardHit",9120729337,0.55,1,"The guard's hit that launches the hero."},
  {"LaunchWhistle",9119197896,0.35,1,"Rising slide whistle as the hero flies up."},
  {"FallWhistle",9119198140,0.35,1,"Falling slide whistle from the top of the arc."},
  {"HeroPuffUp",BOING,0.4,0.7,"The hero puffs up, ready to fight."},
  {"SteamHiss",9118882814,0.3,1.3,"Anger steam from the hero's and guard's heads."},
  {"StareHero",1837830203,0.55,1,"Close-up on the hero's angry face (APM BOOM-Deep Boom 04)."},
  {"StareGuard",BOOM,0.55,1.15,"Close-up on the guard's angry face."},
  {"EyeSparks",9114277402,0.35,1,"Electric sparks between the hero and the guard (Electric Zaps 6)."},
  {"Stomp",9114523612,0.5,1,"The hero paws the ground before charging (Foot Stomp 6)."},
  {"Charge",9120728815,0.5,1,"The hero charges in to peck (Whoosh Heavy Punches 1)."},
 }},
 {"5_CrashLanding",{
  {"CrashThud",9113480915,0.6,1,"The hero slams into the yard."},
  {"BigBounce",BOING,0.4,1,"First bounce after the crash."},
  {"SmallBounce",BOING,0.4,1.25,"Second, smaller bounce."},
 }},
 {"6_MissingChicken",{
  {"EmptySpotAppears",9116405618,0.45,1,"Black '?' chicken appears in the fourth spot."},
  {"HeroIdea",POP,0.45,1.2,"Gold '!' when the hero gets the idea."},
  {"DashToLever",9120999812,0.35,1,"The hero dashes to the lever."},
  {"LeverHop",BOING,0.4,1.1,"The hero hops up to grab the lever."},
  {"LeverPull",9116259834,0.45,1,"The lever is pulled."},
  {"RollTick",9119717523,0.35,1.2,"Each roll beat; the cutscene raises the pitch a little per tick (copy of Rolling.RollTick)."},
  {"NewChickenReveal",9047103106,0.4,1,"The mystery chicken is revealed."},
 }},
 {"7_SquadComplete",{
  {"RecruitJump",BOING,0.4,1.15,"The new chicken jumps off the podium."},
  {"RecruitLand",9114523612,0.45,1,"It lands on the yard (Foot Stomp 6)."},
  {"FriendJoins",POP,0.45,0.9,"The new chicken fills the gap."},
  {"SquadJingle",JINGLE,0.4,1,"Four Victory poses and confetti."},
  {"SquadApplause",9113138088,0.35,1,"Applause under the jingle."},
 }},
 {"8_CampPayoff",{
  {"PayoffJingle",JINGLE,0.4,1,"The hero celebrates after the tutorial's Cluck Camp win."},
  {"PayoffCrownGlint",SHIMMER,0.45,1,"Crown glint on the horizon at the end of the payoff."},
 }},
}
local result={}
for _,scene in scenes do
 local folder=intro:FindFirstChild(scene[1])
 if not folder then folder=Instance.new("Folder");folder.Name=scene[1];folder.Parent=intro end
 for _,cue in scene[2] do
  local name,id,volume,speed,usage=cue[1],cue[2],cue[3],cue[4],cue[5]
  local sound=folder:FindFirstChild(name)
  if not sound then
   sound=Instance.new("Sound");sound.Name=name;sound.SoundId="rbxassetid://"..id
   sound.Volume=volume;sound.PlaybackSpeed=speed
   sound.SoundGroup=library.Mix.Effects;sound.Parent=folder
  end
  sound:SetAttribute("AudioCue","Intro_"..name)
  sound:SetAttribute("Usage",usage)
  table.insert(result,scene[1].."/"..name)
 end
end
return result
