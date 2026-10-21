-- October 21, 2026 game-feel cues: Studio Edit-only authoring recipe (session F7).
-- Paste the whole file into the Command Bar in canonical Edit mode and run it once.
-- Idempotent: creates missing Sounds, fills BLANK SoundIds, never overwrites a
-- customised SoundId; prints a created/filled/skipped summary and returns it.
--
-- SOUND DESIGN NOTE — the voice of My Chicken Army
-- Playful toy-military: bright, short, rounded. No harsh noise, no sci-fi beeps.
--  * UI (VFX/UI) is soft pops and wooden/paper ticks, so it comes from Roblox's own
--    free "Roblox GUI" / "RBLX UI" set (creator Roblox): one family, one timbre,
--    tiny files. Hover is a 0.2 s tick; opens/closes/tabs are 0.5 s swipes.
--  * Locks, toggles, thumps and flags are real foley from the free ProSoundEffects
--    library (padlock keys, toggle switch, wood beam knocks, flag cloth) so the
--    world feels like a toy box, not a phone.
--  * Rewards escalate by tier: Roblox GUI pops (Claim) -> marimba jingle -> APM
--    stings and fanfares (Fanfare, Mission win, roll tiers). APM clips are the
--    same licensed family the intro cutscene and Victory already use.
--  * Chickens are real-ish clucks (Zelgraz / Bloom Entertainment clips, 0.4-1.3 s),
--    never cartoon honks; play them with pitchVariance so a flock never sounds
--    like one sample on loop.
--  * Military flavour is bugles and a snare roll (APM "Bugle Call", "Snare Drum -
--    Rolls") for marching and Missions; defeat is a wry APM "Loser Sting".
-- Every id below came from a Creator Store search (free audio) and passed a
-- ContentProvider preload check in Studio (IsLoaded, TimeLength) on Oct 21, 2026.
-- Alternates are listed per cue (alt/altNote) for Stevin to swap in by hand.
-- Volumes are starting points; Stevin tunes in Studio.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning(), "Run in canonical Edit mode")
local library=game.SoundService:WaitForChild("MyChickenArmyAudio")
local effects=library:FindFirstChild("Mix") and library.Mix:FindFirstChild("Effects")
assert(effects and effects:IsA("SoundGroup"), "Missing MyChickenArmyAudio.Mix.Effects")
local function folder(parent,name)
	local f=parent:FindFirstChild(name)
	if not f then f=Instance.new("Folder");f.Name=name;f.Parent=parent end
	assert(f:IsA("Folder"),"Expected Folder "..name)
	return f
end
local vfx=folder(library,"VFX")
local folders={
	UI=folder(vfx,"UI"),
	SkillTree=folder(vfx,"SkillTree"),
	Collection=folder(library,"Collection"),
	Rolling=folder(library,"Rolling"),
	Combat=folder(library,"Combat"),
}
-- {cue, id, volume, usage, alt id, alt note}. seconds = verified TimeLength.
local cues={
	-- VFX/UI -------------------------------------------------------------
	{"UI","UIHover",10066931761,0.22,"Button hover / gamepad focus; very soft tick (RBLX UI Hover 01, 0.20 s).",17208339919,"Roblox GUI - Hover 01 (0.10 s)"},
	{"UI","MenuOpen",17208405682,0.40,"Any menu, panel or popup opening (Roblox GUI - Swipe, 0.56 s).",10128766965,"RBLX UI Swipe (0.62 s)"},
	{"UI","MenuClose",10066914500,0.35,"Any menu, panel or popup closing (RBLX UI Back, 0.56 s).",17208295577,"Roblox GUI - Call Leave (0.54 s)"},
	{"UI","TabSwitch",10066968815,0.30,"Category / sort / tab change (RBLX UI Select 02, 0.49 s).",17208396156,"Roblox GUI - Select (0.53 s)"},
	{"UI","Toggle",9119717529,0.35,"Settings and Auto Roll switches (PSE Switch Click Toggle Button 1, 0.23 s).",9120094547,"PSE Toggle Switch Metal Industrial 14 (0.44 s)"},
	{"UI","Locked",17208353912,0.35,"Pressing a locked or unaffordable control: soft nope, not Error (Roblox GUI - Negative, 0.38 s).",9126267607,"PSE Wood Hit Giant Beam Knocks 12 (0.73 s)"},
	{"UI","Select",10128760939,0.35,"Marking a card (RBLX UI Select 01, 0.58 s).",17208396156,"Roblox GUI - Select (0.53 s)"},
	{"UI","Equip",17208323435,0.45,"A chicken joins the Army (Roblox GUI - Equip, 0.62 s).",10066968815,"RBLX UI Select 02 (0.49 s)"},
	{"UI","Unequip",10066926605,0.35,"A chicken leaves the Army (RBLX UI Delete, 0.61 s).",17208389987,"Roblox GUI - Recycle (0.67 s)"},
	{"UI","Lock",9116175991,0.40,"Chicken lock on (PSE Keys In Padlock 1, 0.68 s).",9116722865,"PSE Metal Latches 4 (1.61 s)"},
	{"UI","Unlock",138563650927135,0.40,"Chicken lock off (Padlock Open by zimglo, 1.01 s).",873617644,"Unlock Item by ForeverHD (2.12 s)"},
	{"UI","Confirm",17208399163,0.45,"Confirm bars: Sell N, Equip Best (Roblox GUI - Send, 0.61 s).",17208209318,"Roblox GUI - Call Accept (0.83 s)"},
	{"UI","Claim",17208380755,0.45,"Claiming a reward (Roblox GUI - Purchase, 0.87 s).",10066947742,"RBLX UI Purchase (0.87 s)"},
	{"UI","Jingle",106145041472451,0.45,"Short success jingle, marimba bloop (Success sound by katorea_1, 2.04 s).",99980076888596,"jingle_chime_07_positive (1.66 s)"},
	{"UI","CountTick",93076868992220,0.20,"Count-ups: Coins readout, receipts; play with pitchVariance (UI_Tick, 0.05 s).",17208343514,"Roblox GUI - Hover 02 (0.07 s)"},
	{"UI","Badge",17208204604,0.35,"A badge or count appears: upgrades ready, Auto Roll hit (Roblox GUI - Bubble, 0.55 s).",17208372272,"Roblox GUI - Notification Low (3.04 s)"},
	{"UI","Shimmer",9120296573,0.30,"Sparkle sweep on MAX and Legendary+ cards (PSE Twee Light Shimmering 4, 2.63 s).",9116418035,"PSE Magic Tone Falling Shimmer Flanged 3 (3.29 s)"},
	{"UI","Whoosh",127438224839678,0.35,"Flyers, slides, My Base teleport (zapsplat cartoon whoosh whip away, 0.33 s).",9125805579,"PSE Rising Whoosh Hissing Build Up 2 (1.14 s) for longer slides"},
	{"UI","Fanfare",1844584807,0.50,"Big win: first capture, Rebirth banner (APM Glamour Fanfare 4, 3.66 s).",1844584698,"APM Winner (4.62 s)"},
	{"UI","Rebirth",9120704346,0.60,"Deep boom and whoosh under the Rebirth flash (PSE Whoosh Deep Booming Blast Reversed At Tail 1, 3.09 s).",9125402735,"PSE Boom Impact Deep Distant Thumping Hits 1 (2.88 s)"},
	{"UI","GemGain",4612374209,0.45,"Gems arrive (bling_diamond_pickup_1 by thienbao2109, 1.50 s).",435308149,"Gem_Get by D4rkly (1.88 s)"},
	{"UI","GoldRushStart",3406813517,0.50,"Gold Rush begins: rising power-up (Power_Up by thienbao2109, 1.90 s).",2789427964,"Unlock_bonus_level by thienbao2109 (2.00 s)"},
	{"UI","GoldRushEnd",6091466880,0.45,"Gold Rush ends (TIME IS UP by thienbao2109, 1.37 s).",1839857733,"APM Time Up (a), jazz time's-up sting (4.37 s)"},
	{"UI","NoticeIn",17208361335,0.35,"Corner notice slides in (Roblox GUI - Notification High, 1.52 s).",106553517979212,"UI Notification by CoreCraft Studio (0.97 s)"},
	-- Collection ---------------------------------------------------------
	{"Collection","EggLay",18145114696,0.35,"A chicken lays: soft plop, play with pitchVariance (cartoon plop sound by sup3rthe, 0.54 s).",773858658,"plop by WesFluff (0.19 s)"},
	{"Collection","VacuumLoop",3620275022,0.20,"Looped hum while the Egg Vacuum runs (Vacuum_Running_old by superoverability, 1.03 s loop).",94990002530647,"vacuum cleaner by SuPeR_TUbbIE123 (1.44 s)"},
	{"Collection","VacuumFull",18192219147,0.45,"The vacuum's bar fills: bell ding (Elevator Ding SFX by Markolo5G, 2.14 s).",9126076118,"PSE Synth Sparkle Tone Burst Ding 15 (0.74 s)"},
	{"Collection","FeedChicken",5630037419,0.40,"Feed crunch (Cartoon Munch Sound Effect by Moolootoov, 1.07 s).",78138340192174,"eat/crunch sound by Noodle Games (0.31 s)"},
	{"Collection","LevelUp",983016958,0.50,"Chicken level-up jingle (LevelUp by Crazyblox, 2.25 s).",132684971,"levelupsound by filiptibell (4.05 s)"},
	{"Collection","Cluck1",125408037908664,0.25,"Ambient cluck, spatial, pitchVariance (Cluck 1 by Zelgraz, 0.37 s).",85508839801279,"Chicken Flee by Zelgraz (0.44 s)"},
	{"Collection","Cluck2",102341941754671,0.25,"Ambient cluck, spatial, pitchVariance (Cluck 2 by Zelgraz, 0.65 s).",111450301740877,"cluck 4 by MACTEP777771 (0.65 s)"},
	{"Collection","Cluck3",88279026957024,0.25,"Ambient cluck, spatial, pitchVariance (Chicken sfx_3 by Bloom Entertainment, 0.73 s).",77220806348821,"chicken by lhvgamzelhv (1.12 s)"},
	{"Collection","ChickenHappy",137857373943195,0.25,"Happy cluck series: feed, level-up, podium (Chicken Sfx_2 by Bloom Entertainment, 1.30 s).",131137853843046,"chicken_1.ogg by y4azz4y (2.32 s)"},
	-- Rolling ------------------------------------------------------------
	{"Rolling","RollEpic",9126072453,0.50,"Epic reveal stinger (PSE Synth Sparkle Tone Bell Tone Burst 7, 1.37 s).",9126072452,"PSE Synth Sparkle Tone Bell Tone Burst 8 (1.57 s)"},
	{"Rolling","RollLegendary",87339438449663,0.55,"Legendary reveal stinger (APM Celebrate (Sting), 2.50 s).",1846432177,"APM Flourish Sting (4.26 s)"},
	{"Rolling","RollMythic",9125635297,0.55,"Mythic reveal stinger (PSE Magical Exit Sparkling Pass Bys Clinking Chimes 4, 3.42 s).",1836477530,"APM Stunning Sting (4.05 s)"},
	{"Rolling","RollSecret",1843093012,0.60,"Secret reveal stinger (APM Mysterious Path - Sting 4, 4.55 s).",1843092991,"APM Mysterious Path - Sting 3 (4.91 s)"},
	{"Rolling","MutationHit",17669542369,0.50,"Golden / Rainbow / Shadow / Cosmic tag (mixkit fairy arcade sparkle 866, 1.50 s).",117011707307950,"Glitter Sparkle Magic Sound (1.47 s)"},
	{"Rolling","AutoRollHit",107978604605265,0.45,"Auto Roll stop banner (UI Notification Double Ding Reverb by Project 555, 1.44 s).",17208327798,"Roblox GUI - Aura (2.17 s)"},
	{"Rolling","PodiumThump",9126267413,0.40,"The chicken lands on the podium (PSE Wood Hit Giant Beam Dull Thuds Knocks 10, 0.63 s).",9113551983,"PSE Boom Thump Rattling Impacts Light Crunch 4 (1.48 s)"},
	-- VFX/SkillTree ------------------------------------------------------
	{"SkillTree","UpgradeMax",103516326607012,0.50,"A track reaches MAX (mixkit achievement bell 600, 2.40 s).",89593894732695,"Success Stinger 02 by BuilderBillbert (3.16 s)"},
	{"SkillTree","TierUp",80736831159506,0.45,"A tier bought (UpgradeBought by Teriyaki's Games, 1.72 s).",85188753846582,"sfx_menu_upgrade by fajnygosciu1234 (1.33 s)"},
	-- Combat -------------------------------------------------------------
	{"Combat","MarchStart",1842335206,0.50,"The Army sets off (APM Bugle Call (a), 4.06 s).",1840205789,"APM Snare Drum - Rolls (d) (4.02 s)"},
	{"Combat","CaptureTick",9126029394,0.30,"Conquest meter section fills (PSE Switch Rotating Switch Clicks 12, 0.37 s).",137727855471828,"Tick by ThtRookie (0.63 s)"},
	{"Combat","MissionAppear",1840120155,0.50,"A Mission site appears (APM Bugle Call (C), 2.90 s).",1845415163,"APM Heraldic Bugle (5.06 s)"},
	{"Combat","MissionWin",125367748123159,0.50,"A Mission is won (Success Fanfare Medieval Trumpets by NTG537, 3.91 s).",1844584698,"APM Winner (4.62 s)"},
	{"Combat","MissionLose",1839846554,0.50,"A Mission fails (APM Loser Sting 1, 4.23 s).",138116340,"Sad Trombone (Complete Tune) by Quaint (3.92 s)"},
	{"Combat","FlagRaise",9114461411,0.40,"Owned flag goes up (PSE Flag Flapping 3, 0.93 s).",9114462292,"PSE Flagpole Hit 1, metallic ding (0.98 s)"},
}
local function findCue(parent,cue)
	for _,child in parent:GetChildren() do
		if child:IsA("Sound") and child:GetAttribute("AudioCue")==cue then return child end
	end
	local byName=parent:FindFirstChild(cue)
	if byName and byName:IsA("Sound") then return byName end
	return nil
end
local created,filled,skipped,result={},{},{},{}
for _,entry in cues do
	local folderName,cue,id,volume,usage,alt,altNote=table.unpack(entry)
	local parent=folders[folderName]
	local sound=findCue(parent,cue)
	local soundId="rbxassetid://"..id
	if not sound then
		sound=Instance.new("Sound")
		sound.Name=cue
		sound.SoundId=soundId
		sound.Volume=volume
		sound.PlaybackSpeed=1
		sound.Looped=cue=="VacuumLoop"
		sound.PlayOnRemove=false
		sound.Parent=parent
		table.insert(created,cue)
	elseif sound.SoundId=="" then
		sound.SoundId=soundId
		sound.Volume=volume
		sound.PlaybackSpeed=1
		if cue=="VacuumLoop" then sound.Looped=true end
		table.insert(filled,cue)
	else
		table.insert(skipped,cue)
	end
	sound.SoundGroup=effects
	sound:SetAttribute("AudioCue",cue)
	sound:SetAttribute("Usage",usage)
	sound:SetAttribute("Alternate","rbxassetid://"..alt.." = "..altNote)
	table.insert(result,{cue=cue,path=sound:GetFullName(),id=sound.SoundId})
end
print(("add_feel_sounds_20261021: created %d, filled %d, skipped (kept custom id) %d"):format(#created,#filled,#skipped))
if #created>0 then print("  created: "..table.concat(created,", ")) end
if #filled>0 then print("  filled: "..table.concat(filled,", ")) end
if #skipped>0 then print("  skipped: "..table.concat(skipped,", ")) end
return result
