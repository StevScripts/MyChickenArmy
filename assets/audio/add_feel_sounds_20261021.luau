-- October 21, 2026 game-feel cues, v2 "Pet Simulator" restyle (session F7).
-- Paste the whole file into the Command Bar in canonical Edit mode and run it once.
--
-- SOUND DESIGN NOTE — the voice of My Chicken Army (Stevin, Oct 21: "copy sounds from
-- Pet Simulator, they have the best SFX")
-- Bright, bubbly, candy-like and satisfying, like Pet Simulator 99 / X:
--  * UI is soft pop/tock clicks and tiny blip hovers. Most come from Roblox's own
--    free "Roblox_UI_*" set (Small_Click, Bright_Click, Whoosh_01-04, Paper_Swipe,
--    Tonal_Stinger; Sweep and Cute_Goodbye as alternates) so every panel speaks one
--    timbre. (Roblox_UI_Cute_Pop measured 2.7 s, too long for a click.)
--  * Pickups and marks are bubbly pops (original bubble pops, CoreKit "bubbly_toggle",
--    AmbientSorcery "ui-simple" alternates); counts and conquest ticks are tiny
--    presses and 8-bit plings from Roblox's "Roblox_Pinball" set, pitched up by the
--    code's pitchVariance so cascades rise.
--  * Rewards are sparkles and chimes: ProSoundEffects "Magic Glows Soft Clusters Of
--    Chiming Hits" for shimmers and reveals, cash-register ka-ching for purchases and
--    claims, crystal tings for Gems, rising sparkles for level-ups and Gold Rush.
--  * Big moments are whoosh + bright jingle (original "Win Jingle!", "Quest-Complete!",
--    GladGhost6 quest jingle, N4W1N "Skybound" gacha set).
--  * Nothing harsh, sci-fi, wooden or industrial: the v1 padlocks, toggle switches,
--    wood knocks, flag cloth and deep booms are retired to the `Previous` attribute.
--  * Chickens still cluck (real-ish clips, pitchVariance): Pet Simulator has no
--    chickens, so Cluck1-3 / ChickenHappy keep their v1 sounds.
--  * LEVELS (Stevin, live listening Oct 21): event cues (Gold Rush, Missions,
--    Rebirth, reveals, fanfares) stay under ~0.35 and never startle; ambient / world
--    cues (lays, clucks) stay under ~0.25. Three cues are Stevin's own live picks
--    and are never re-sourced: EggLay (soft lip pop, 0.14), GoldRushStart (one
--    gentle sparkle ding, 0.22: the power-up was 'too loud and scares me') and
--    GoldRushEnd (falling shimmer, 0.2). Studio already holds them with a
--    `Previous` attribute; the recipe recognises the id and leaves them alone.
-- Sound-alikes only. No Creator Store re-upload of Pet Simulator's own audio is used
-- (Roblox moderates those and they go silent in the live game).
-- Every id came from a free Creator Store search and passed a ContentProvider preload
-- check in Studio (IsLoaded, TimeLength) on Oct 21, 2026; durations are in the Usage.
--
-- RESTYLE RULES (idempotent):
--  * missing Sound -> created with the new id; blank SoundId -> filled.
--  * existing id -> replaced ONLY when the Sound has no Restyled="PetSim-20261021"
--    attribute AND its current id is one this recipe wrote before (the v1 id, or the
--    original agent id for the older Click / Pop / SkillTree cues). The old id goes
--    into a `Previous` attribute and Restyled is set. Any other id is Stevin's own pick:
--    kept and reported.
--  * cues marked keep=true stay on their v1 sound (create/fill only, no Restyled).
--  * reruns change nothing. To revert a cue, paste `Previous` back into SoundId.
-- Never touched: Collection Money/CoinPickup/CoinDrop/EggPickup/EggDeposit/Collect,
-- VFX/UI Purchase and Error, Combat/*, CallArmyWhistle, Intro/*, Music/*, and Rolling
-- RollLever/RollTick/RollLand/RollReveal/RollRare.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning(), "Run in canonical Edit mode")
local RESTYLE="PetSim-20261021"
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
-- Fields: folder, cue, id (new), volume, speed, usage, alt id, alt note,
-- previous (ids this recipe may replace; blank is always allowed), keep (stay on v1).
local cues={
	-- VFX/UI --------------------------------------------------------------
	{folder="UI",cue="UIHover",id=15675032796,volume=0.22,speed=1,usage="Button hover / gamepad focus: tiny tock blip (Roblox_UI_Small_Click, 0.13 s).",alt=79315763728779,altNote="ui_hover_bubble_pop_02 by GladGhost6 (0.50 s)",previous={10066931761}},
	{folder="UI",cue="Click",id=5852470908,volume=0.4,speed=1,usage="Button press: soft bubble button pop (Cartoon bubble button Sound by FireAtacck, 0.21 s).",alt=15675059323,altNote="Roblox_UI_Bright_Click (0.37 s)",previous={139719503904449}},
	{folder="UI",cue="Pop",id=126269603852501,volume=0.4,speed=1,usage="Generic pop fallback: bubbly pop (Bubble pop sound by Storkusy, 0.28 s).",alt=137273815815490,altNote="bubble-pop-100784 (0.67 s)",previous={139800881181209}},
	{folder="UI",cue="MenuOpen",id=15675024286,volume=0.4,speed=1,usage="Any menu, panel or popup opening: soft whoosh (Roblox_UI_Whoosh_01, 0.85 s).",alt=133820081532712,altNote="swoosh-sound for UI by greenworx (0.24 s)",previous={17208405682}},
	{folder="UI",cue="MenuClose",id=15675028888,volume=0.35,speed=1,usage="Any menu, panel or popup closing: whoosh away (Roblox_UI_Whoosh_02, 0.49 s).",alt=15675081158,altNote="Roblox_UI_Cute_Goodbye (0.28 s)",previous={10066914500}},
	{folder="UI",cue="TabSwitch",id=107710687218353,volume=0.3,speed=1,usage="Category / sort / tab change: tiny UI swoosh (swoosh UI sound by greenworx, 0.24 s).",alt=15675059323,altNote="Roblox_UI_Bright_Click (0.37 s)",previous={10066968815}},
	{folder="UI",cue="Toggle",id=125454714785814,volume=0.35,speed=1,usage="Settings and Auto Roll switches: bubbly toggle (CoreKit UI bubbly_toggle by WillShockwave, 0.20 s).",alt=122170579661709,altNote="ui_toggle_on by mdsbrnmsb (0.15 s)",previous={9119717529}},
	{folder="UI",cue="Locked",id=106042048386874,volume=0.35,speed=1,usage="Pressing a locked or unaffordable control: soft nope, not Error (Skybound_UI_Error by N4W1N, 0.50 s).",alt=1394480679,altNote="BOOP by NoSwea_t (0.34 s)",previous={17208353912}},
	{folder="UI",cue="Select",id=15675059323,volume=0.35,speed=1,usage="Marking a card: bright click (Roblox_UI_Bright_Click, 0.37 s).",alt=76893939716509,altNote="Pop by Verdigrii (0.28 s)",previous={10128760939}},
	{folder="UI",cue="Equip",id=77120543307812,volume=0.45,speed=1.1,usage="A chicken joins the Army: bubble click, pitched up (ui-bubble-click by NotBlackrus, 0.50 s, x1.1).",alt=138323438407619,altNote="ui-simple-equip by AmbientSorcery (0.12 s)",previous={17208323435}},
	{folder="UI",cue="Unequip",id=76893939716509,volume=0.35,speed=0.9,usage="A chicken leaves the Army: the same pop pitched down (Pop by Verdigrii, 0.28 s, x0.9).",alt=81904985537003,altNote="ui-simple-unequip by AmbientSorcery (0.13 s)",previous={10066926605}},
	{folder="UI",cue="Lock",id=86277903237864,volume=0.4,speed=1,usage="Chicken lock on: soft UI lock click (ui_lock by KUploader, 0.17 s).",alt=90515507208380,altNote="CoreKit UI wood_toggle by WillShockwave (0.14 s)",previous={9116175991}},
	{folder="UI",cue="Unlock",id=131408467630923,volume=0.4,speed=1,usage="Chicken lock off: bright unlock chime (Unlock by crouton_TUTUR6, 0.95 s).",alt=873617644,altNote="Unlock Item by ForeverHD (2.12 s)",previous={138563650927135}},
	{folder="UI",cue="Confirm",id=135165335432475,volume=0.45,speed=1,usage="Confirm bars: Sell N, Equip Best: clean success pop (Success Correct Sound by 0FFZ3TI, 0.69 s).",alt=17208399163,altNote="Roblox GUI - Send (0.61 s)",previous={17208399163}},
	{folder="UI",cue="Claim",id=87082710377514,volume=0.35,speed=1,usage="Claiming a reward: short purchase-complete chime (Purchase Complete by Captian_Chummy, 1.20 s).",alt=134952684776633,altNote="Purchase Sound Effect by Marshymelona (2.01 s)",previous={17208380755}},
	{folder="UI",cue="Jingle",id=85963199032103,volume=0.35,speed=1,usage="Short success jingle (quest_complete_jingle by GladGhost6, 3.00 s).",alt=106145041472451,altNote="Success sound, marimba, by katorea_1 (2.04 s)",previous={106145041472451}},
	{folder="UI",cue="CountTick",id=16480550203,volume=0.2,speed=1,usage="Count-ups: Coins readout, receipts; play with pitchVariance so the cascade rises (Roblox_Pinball_Tiny_Button_Press_03, 0.18 s).",alt=93076868992220,altNote="UI_Tick (0.05 s)",previous={93076868992220}},
	{folder="UI",cue="Badge",id=17208204604,volume=0.35,speed=1,usage="A badge or count appears: bubbly pop (Roblox GUI - Bubble, 0.55 s).",alt=17669542615,altNote="mixkit dry pop-up notification alert (0.30 s)",previous={17208204604}},
	{folder="UI",cue="Shimmer",id=9116394545,volume=0.3,speed=1,usage="Sparkle sweep on MAX and Legendary+ cards (PSE Magic Glows Soft Clusters Of Chiming Hits 1, 1.43 s).",alt=117011707307950,altNote="Glitter Sparkle Magic Sound (1.47 s)",previous={9120296573}},
	{folder="UI",cue="Whoosh",id=15674975792,volume=0.35,speed=1,usage="Flyers, slides, My Base teleport (Roblox_UI_Whoosh_03, 1.10 s).",alt=15675046931,altNote="Roblox_UI_Sweep (0.61 s)",previous={127438224839678}},
	{folder="UI",cue="Fanfare",id=7464917496,volume=0.35,speed=1,usage="Big win: first capture, Rebirth banner: bright victory jingle (Victory Sound Effect 2 by BushSeed, 3.20 s).",alt=1844584807,altNote="APM Glamour Fanfare 4 (3.66 s)",previous={1844584807}},
	{folder="UI",cue="Rebirth",id=9116394756,volume=0.35,speed=1,usage="Big magic chime cluster under the Rebirth flash, gentle, never a boom (PSE Magic Glows Soft Clusters Of Chiming Hits 3, 3.34 s).",alt=9125635297,altNote="PSE Magical Exit Sparkling Pass Bys Clinking Chimes 4 (3.42 s)",previous={9120704346}},
	{folder="UI",cue="GemGain",id=78448295008483,volume=0.45,speed=1,usage="Gems arrive: crystal ting (DiamondCollect by Metalix3B, 0.71 s).",alt=11439707919,altNote="gem collect by CheckForSkills1 (1.31 s)",previous={4612374209}},
	{folder="UI",cue="GoldRushStart",id=9126076118,volume=0.22,speed=1,usage="Gold Rush begins: one gentle sparkle ding, never a rising power-up or buzzer (Stevin's pick, PSE Synth Sparkle Tone Burst Ding 15, 0.74 s).",alt=71491555548135,altNote="Skybound_Gacha_GlowUp by N4W1N (1.91 s), rejected live as too loud",previous={3406813517}},
	{folder="UI",cue="GoldRushEnd",id=9116418035,volume=0.2,speed=1,usage="Gold Rush ends: soft falling shimmer (Stevin's pick, PSE Magic Tone Falling Shimmer Flanged 3, 3.29 s).",alt=15675081158,altNote="Roblox_UI_Cute_Goodbye (0.28 s)",previous={6091466880}},
	{folder="UI",cue="NoticeIn",id=76932672222714,volume=0.35,speed=1,usage="Corner notice slides in: ding-sparkle pop (cartoon music ding sparkle pop notification, 2.53 s).",alt=71450094482101,altNote="popup notification by d3stiny_dev (1.27 s)",previous={17208361335}},
	-- Collection ----------------------------------------------------------
	{folder="Collection",cue="EggLay",id=9116312491,volume=0.14,speed=1,usage="A chicken lays: very soft, quiet lip pop, play with pitchVariance; the cartoon plop sounded out of place (Stevin's pick, PSE Lip Pops Dry Plosive Short Snaps 2, 0.45 s).",alt=17208204604,altNote="Roblox GUI - Bubble (0.55 s)",previous={18145114696}},
	{folder="Collection",cue="VacuumLoop",id=3620275022,volume=0.2,speed=1,usage="Looped hum while the Egg Vacuum runs (Vacuum_Running_old by superoverability, 1.03 s loop; no bubbly loop fits, kept).",alt=94990002530647,altNote="vacuum cleaner by SuPeR_TUbbIE123 (1.44 s)",previous={},keep=true},
	{folder="Collection",cue="VacuumFull",id=5995351511,volume=0.35,speed=1,usage="The vacuum's bar fills: bright coin ding (coin ding (uncopyrighted) by orangebaron, 0.60 s).",alt=100767074657294,altNote="Correct Sound Ding (1.27 s)",previous={18192219147}},
	{folder="Collection",cue="FeedChicken",id=120816519859447,volume=0.3,speed=1,usage="Feed: cute nom-nom (Nom Nom Nom by aceflorida18, 0.81 s).",alt=113689378789504,altNote="nom by Rocksimoncat (0.35 s)",previous={5630037419}},
	{folder="Collection",cue="LevelUp",id=9116394876,volume=0.35,speed=1.15,usage="Chicken level-up: magical rising sparkle (PSE Magic Glows Soft Clusters Of Chiming Hits 2, 2.01 s, x1.15).",alt=1293433423,altNote="Chat Progress by ClicheChloe (1.50 s)",previous={983016958}},
	{folder="Collection",cue="Cluck1",id=125408037908664,volume=0.22,speed=1,usage="Ambient cluck, spatial, pitchVariance (Cluck 1 by Zelgraz, 0.37 s).",alt=85508839801279,altNote="Chicken Flee by Zelgraz (0.44 s)",previous={},keep=true},
	{folder="Collection",cue="Cluck2",id=102341941754671,volume=0.22,speed=1,usage="Ambient cluck, spatial, pitchVariance (Cluck 2 by Zelgraz, 0.65 s).",alt=111450301740877,altNote="cluck 4 by MACTEP777771 (0.65 s)",previous={},keep=true},
	{folder="Collection",cue="Cluck3",id=88279026957024,volume=0.22,speed=1,usage="Ambient cluck, spatial, pitchVariance (Chicken sfx_3 by Bloom Entertainment, 0.73 s).",alt=77220806348821,altNote="chicken by lhvgamzelhv (1.12 s)",previous={},keep=true},
	{folder="Collection",cue="ChickenHappy",id=137857373943195,volume=0.22,speed=1,usage="Happy cluck series: feed, level-up, podium (Chicken Sfx_2 by Bloom Entertainment, 1.30 s).",alt=131137853843046,altNote="chicken_1.ogg by y4azz4y (2.32 s)",previous={},keep=true},
	-- Rolling -------------------------------------------------------------
	{folder="Rolling",cue="RollEpic",id=137357606937971,volume=0.35,speed=1.1,usage="Epic reveal: pop + sparkle hatch (Skybound_Gacha_Reveal_Common by N4W1N, 1.90 s, x1.1).",alt=9126072453,altNote="PSE Synth Sparkle Tone Bell Tone Burst 7 (1.37 s)",previous={9126072453}},
	{folder="Rolling",cue="RollLegendary",id=80777027985562,volume=0.35,speed=1,usage="Legendary reveal: sparkle reveal stinger (Reveal by Agrur1i, 2.60 s).",alt=87339438449663,altNote="APM Celebrate (Sting) (2.50 s)",previous={87339438449663}},
	{folder="Rolling",cue="RollMythic",id=9116395089,volume=0.35,speed=1,usage="Mythic reveal: big magic chime cluster (PSE Magic Glows Soft Clusters Of Chiming Hits 4, 2.46 s).",alt=9125635297,altNote="PSE Magical Exit Sparkling Pass Bys Clinking Chimes 4 (3.42 s)",previous={9125635297}},
	{folder="Rolling",cue="RollSecret",id=77246536805921,volume=0.35,speed=1,usage="Secret reveal: big magical reveal (RevealBig by MaStErpp_0904, 4.56 s).",alt=1843093012,altNote="APM Mysterious Path - Sting 4 (4.55 s)",previous={1843093012}},
	{folder="Rolling",cue="MutationHit",id=17669542369,volume=0.35,speed=1,usage="Golden / Rainbow / Shadow / Cosmic tag: arcade sparkle, already on style (mixkit fairy arcade sparkle 866, 1.50 s).",alt=117011707307950,altNote="Glitter Sparkle Magic Sound (1.47 s)",previous={},keep=true},
	{folder="Rolling",cue="AutoRollHit",id=107978604605265,volume=0.35,speed=1,usage="Auto Roll stop banner: bright double ding, already on style (UI Notification Double Ding Reverb by Project 555, 1.44 s).",alt=100237334792227,altNote="Skybound_Pickup_Ring by N4W1N (1.32 s)",previous={},keep=true},
	{folder="Rolling",cue="PodiumThump",id=135468135163946,volume=0.3,speed=1,usage="The chicken lands on the podium: soft bounce (Bounce SFX by FourRxsesLeo, 0.80 s).",alt=138910257412285,altNote="bounce1 by SpectrumSprinkles (1.44 s)",previous={9126267413}},
	-- VFX/SkillTree -------------------------------------------------------
	{folder="SkillTree",cue="UpgradeMax",id=131158134113693,volume=0.35,speed=1,usage="A track reaches MAX: quest-complete sparkle (Skybound_Quest_Complete by N4W1N, 1.90 s).",alt=103516326607012,altNote="mixkit achievement bell 600 (2.40 s)",previous={103516326607012}},
	{folder="SkillTree",cue="TierUp",id=135996502799215,volume=0.45,speed=1,usage="A tier bought: bright upgrade chime (Upgrade by crouton_TUTUR6, 0.90 s).",alt=80736831159506,altNote="UpgradeBought by Teriyaki's Games (1.72 s)",previous={80736831159506}},
	{folder="SkillTree",cue="SkillTreeHover",id=15675032796,volume=0.2,speed=1.2,usage="Hover / focus on tree buttons: tiny blip (Roblox_UI_Small_Click, 0.13 s, x1.2).",alt=17208343514,altNote="Roblox GUI - Hover 02 (0.07 s)",previous={}},
	{folder="SkillTree",cue="SkillTreePurchase",id=18264787819,volume=0.45,speed=1,usage="Server-confirmed tree purchase: crisp cash-register ding (Cash Register Ding by jogamerforgames2019, 0.89 s).",alt=6658761720,altNote="Cash Register (Kaching) by BlueSkyOffic1al (3.09 s)",previous={77584650945481}},
	{folder="SkillTree",cue="SkillTreeNodeAdded",id=9126076030,volume=0.4,speed=1,usage="A new node or frontier is revealed: sparkle ping (PSE Synth Sparkle Tone High Pitch Tone Burst Ping 4, 0.88 s).",alt=100237334792227,altNote="Skybound_Pickup_Ring by N4W1N (1.32 s)",previous={}},
	{folder="SkillTree",cue="SkillTreeNodePop",id=76893939716509,volume=0.3,speed=1,usage="Each node pops in during the opening stagger: tiny pop (Pop by Verdigrii, 0.28 s).",alt=9117848931,altNote="PSE Pops Mouth Popping 8 (0.87 s)",previous={}},
	{folder="SkillTree",cue="SkillTreeOpen",id=15675012262,volume=0.4,speed=1,usage="Upgrades tree opens: whoosh (Roblox_UI_Whoosh_04, 0.35 s).",alt=134487107455539,altNote="CoreKit UI swoosh by WillShockwave (0.40 s)",previous={}},
	{folder="SkillTree",cue="SkillTreeClose",id=15675037413,volume=0.35,speed=1,usage="Upgrades tree closes: paper swipe (Roblox_UI_Paper_Swipe, 0.62 s).",alt=15675028888,altNote="Roblox_UI_Whoosh_02 (0.49 s)",previous={}},
	-- Combat --------------------------------------------------------------
	{folder="Combat",cue="MarchStart",id=109458952687874,volume=0.35,speed=1,usage="The Army sets off: whoosh + bright zone-enter jingle (Skybound_Flight_ZoneEnter by N4W1N, 2.14 s).",alt=1842335206,altNote="APM Bugle Call (a) (4.06 s)",previous={1842335206}},
	{folder="Combat",cue="CaptureTick",id=16480579910,volume=0.3,speed=1,usage="Conquest meter section fills: pling, pitch rises in code (Roblox_Pinball_8Bit_Blip_03, 0.30 s).",alt=72644163309528,altNote="Glockenspiel C6 by AEinsertnamelol (2.71 s)",previous={9126029394}},
	{folder="Combat",cue="MissionAppear",id=15675043410,volume=0.3,speed=1,usage="A Mission site appears: soft tonal stinger (Roblox_UI_Tonal_Stinger, 1.47 s).",alt=71450094482101,altNote="popup notification by d3stiny_dev (1.27 s)",previous={1840120155}},
	{folder="Combat",cue="MissionWin",id=96659579913194,volume=0.35,speed=1,usage="A Mission is won: bright path-complete jingle (PathComplete by Agrur1i, 1.65 s).",alt=2881398164,altNote="Relaxing Jingle (used for when you win) by OisinCerulean (3.53 s)",previous={125367748123159}},
	{folder="Combat",cue="MissionLose",id=2390695935,volume=0.3,speed=1,usage="A Mission fails: soft fail tone (Fail / Error SFX by Chrythm, 1.75 s).",alt=106796270505945,altNote="Purchase Failed by Captian_Chummy (0.90 s)",previous={1839846554}},
	{folder="Combat",cue="FlagRaise",id=100237334792227,volume=0.3,speed=1,usage="Owned flag goes up: sparkle ring (Skybound_Pickup_Ring by N4W1N, 1.32 s).",alt=9114461411,altNote="PSE Flag Flapping 3 (0.93 s)",previous={9114461411}},
}
local function findCue(parent,cue)
	for _,child in parent:GetChildren() do
		if child:IsA("Sound") and child:GetAttribute("AudioCue")==cue then return child end
	end
	local byName=parent:FindFirstChild(cue)
	if byName and byName:IsA("Sound") then return byName end
	return nil
end
local counts={created={},filled={},restyled={},kept={},skipped={}}
local result={}
for _,entry in cues do
	local parent=folders[entry.folder]
	local sound=findCue(parent,entry.cue)
	local newId="rbxassetid://"..entry.id
	local allowed={}
	for _,old in entry.previous do allowed["rbxassetid://"..old]=true end
	local outcome
	if not sound then
		sound=Instance.new("Sound")
		sound.Name=entry.cue
		sound.SoundId=newId
		sound.Volume=entry.volume
		sound.PlaybackSpeed=entry.speed
		sound.Looped=entry.cue=="VacuumLoop"
		sound.PlayOnRemove=false
		sound.Parent=parent
		if not entry.keep then sound:SetAttribute("Restyled",RESTYLE);sound:SetAttribute("Previous","") end
		outcome="created"
	elseif sound.SoundId=="" then
		sound.SoundId=newId
		sound.Volume=entry.volume
		sound.PlaybackSpeed=entry.speed
		if entry.cue=="VacuumLoop" then sound.Looped=true end
		if not entry.keep then sound:SetAttribute("Restyled",RESTYLE);sound:SetAttribute("Previous","") end
		outcome="filled"
	elseif entry.keep then
		outcome="skipped"
	elseif sound:GetAttribute("Restyled")==RESTYLE then
		outcome="skipped"
	elseif sound.SoundId==newId then
		sound:SetAttribute("Restyled",RESTYLE)
		outcome="skipped"
	elseif allowed[sound.SoundId] then
		sound:SetAttribute("Previous",sound.SoundId)
		sound.SoundId=newId
		sound.Volume=entry.volume
		sound.PlaybackSpeed=entry.speed
		if entry.cue=="VacuumLoop" then sound.Looped=true end
		sound:SetAttribute("Restyled",RESTYLE)
		outcome="restyled"
	else
		outcome="kept"
	end
	sound.SoundGroup=effects
	sound:SetAttribute("AudioCue",entry.cue)
	sound:SetAttribute("Usage",entry.usage)
	sound:SetAttribute("Alternate","rbxassetid://"..entry.alt.." = "..entry.altNote)
	table.insert(counts[outcome],entry.cue)
	table.insert(result,{cue=entry.cue,outcome=outcome,path=sound:GetFullName(),id=sound.SoundId})
end
print(("add_feel_sounds_20261021 v2: created %d, filled %d, restyled %d, kept (your own id) %d, skipped %d"):format(#counts.created,#counts.filled,#counts.restyled,#counts.kept,#counts.skipped))
for _,key in {"created","filled","restyled","kept"} do
	if #counts[key]>0 then print("  "..key..": "..table.concat(counts[key],", ")) end
end
return result
