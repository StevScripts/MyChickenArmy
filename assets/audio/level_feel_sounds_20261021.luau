-- October 21, 2026 level pass for the game-feel cues (lead session). Studio Edit-only.
-- Paste the whole file into the Command Bar of the canonical place and run it once
-- AFTER assets/audio/add_feel_sounds_20261021.luau (v2). Idempotent: rerunning changes
-- nothing. Reapply it whenever Studio is reopened from a save that predates the pass
-- (the `Leveled` attribute on SoundService.MyChickenArmyAudio.VFX.UI.MenuOpen tells you).
--
-- Every Volume below is target ÷ measured peak. Peaks were measured in Studio with an
-- AudioPlayer → Wire → AudioAnalyzer chain (no device output, so silent): PeakLevel at
-- Volume 1 over the clip's length; the spectrum was split into <2 / 2–6 / 6–12 / >12 kHz
-- bands to catch piercing clips (method: docs/AUDIO.md › October 21 level pass).
-- `AudioController:Play` keeps these Volumes against callers' overrides while the
-- `Leveled` attribute is present (pass forceVolume=true to insist).
--
-- Stevin's calls baked in (Oct 21, live listening):
--  * egg lay stays very soft (effective peak 0.05); the cartoon plop was "out of place";
--  * Gold Rush start is one warm, gentle crystal chime at 0.07 (the power-up "scares me");
--  * Feed is a normal chicken upgrade chime, not a "nom nom";
--  * no whoosh on every UI tween: menus, the Upgrades tree and tabs use soft bubble pops,
--    and the flyer/teleport Whoosh is half as loud.
-- Later October 21: Stevin replaced the sounds himself and approved the library
-- (assets/audio/library_20261021.json). A Sound with an OwnerApproved attribute is
-- skipped entirely, so rerunning this never undoes his picks or volumes.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning(), "Run in canonical Edit mode")
local library=game.SoundService:WaitForChild("MyChickenArmyAudio")
local function findCue(cue)
	for _,d in library:GetDescendants() do
		if d:IsA("Sound") and d:GetAttribute("AudioCue")==cue then return d end
	end
	return nil
end
-- cue = {vol, peak (measured at Volume 1), target (effective peak), swap (asset id when the
-- clip was replaced), speed, note}
local BUBBLE=17208204604 -- Roblox GUI - Bubble (0.55 s, peak 0.239, 74 % below 2 kHz)
local plan={
	-- VFX/UI ---------------------------------------------------------------
	UIHover={vol=0.11,peak=0.789,target=0.09,swap=79315763728779,note="ui_hover_bubble_pop_02 (GladGhost6); Roblox_UI_Small_Click measured near-silent (peak 0.010)"},
	Click={vol=0.40,peak=0.495,target=0.20},
	Pop={vol=0.22,peak=1.0,target=0.22},
	MenuOpen={vol=0.55,peak=0.239,target=0.13,swap=BUBBLE,speed=1.05,note="soft bubble pop in (Stevin: the whoosh on every tween was too much)"},
	MenuClose={vol=0.45,peak=0.239,target=0.11,swap=BUBBLE,speed=0.85,note="the same pop pitched down for out"},
	TabSwitch={vol=0.30,peak=0.506,target=0.15,swap=15675059323,note="Roblox_UI_Bright_Click (was a UI swoosh)"},
	Toggle={vol=0.45,peak=0.405,target=0.18},
	Locked={vol=0.28,peak=0.637,target=0.18},
	Select={vol=0.40,peak=0.506,target=0.20},
	Equip={vol=0.46,peak=0.434,target=0.20},
	Unequip={vol=0.20,peak=1.0,target=0.20},
	Lock={vol=0.28,peak=0.705,target=0.20,swap=90515507208380,note="CoreKit UI wood_toggle; ui_lock measured near-silent (peak 0.006)"},
	Unlock={vol=0.26,peak=0.855,target=0.22},
	Confirm={vol=0.55,peak=0.400,target=0.22,swap=17208399163,note="Roblox GUI - Send (warm); Success Correct had 25 % of its energy above 12 kHz"},
	Claim={vol=1.8,peak=0.120,target=0.22},
	Jingle={vol=0.36,peak=0.699,target=0.25},
	CountTick={vol=0.19,peak=0.570,target=0.11},
	Badge={vol=0.9,peak=0.219,target=0.20},
	Shimmer={vol=0.22,peak=1.0,target=0.22,swap=117011707307950,note="Glitter Sparkle Magic Sound; PSE Magic Glows measured near-silent (peak 0.033)"},
	Whoosh={vol=0.21,peak=0.470,target=0.10,note="flyers and teleports: kept, half as loud"},
	Fanfare={vol=0.28,peak=1.0,target=0.28},
	Rebirth={vol=0.47,peak=0.553,target=0.26,swap=9125635297,note="PSE Magical Exit Sparkling Pass Bys Clinking Chimes 4; Magic Glows 3 measured near-silent"},
	GemGain={vol=0.33,peak=0.674,target=0.22,swap=11439707919,note="gem collect (57 % below 6 kHz); DiamondCollect was 80 % above 6 kHz"},
	GoldRushStart={vol=0.40,peak=0.172,target=0.07,swap=79130903404606,note="crystal fx (74 % below 2 kHz); the sparkle ding was 68 % above 12 kHz; Stevin: gentle, never a power-up"},
	GoldRushEnd={vol=0.20,peak=0.315,target=0.063,note="Stevin's pick, soft falling shimmer"},
	NoticeIn={vol=0.24,peak=0.820,target=0.20},
	-- Collection -------------------------------------------------------------
	EggLay={vol=0.21,peak=0.239,target=0.05,swap=BUBBLE,note="very soft bubble; the lip pop measured near-silent; Stevin: must stay quiet"},
	VacuumLoop={vol=0.20,peak=0.406,target=0.08},
	VacuumFull={vol=0.57,peak=0.349,target=0.20},
	FeedChicken={vol=0.22,peak=0.921,target=0.20,swap=135996502799215,speed=1.1,note="a normal chicken upgrade chime (Stevin: no nom-nom); the TierUp clip pitched 1.1"},
	LevelUp={vol=0.29,peak=0.759,target=0.22,swap=1293433423,note="Chat Progress rising chime; Magic Glows 2 measured too quiet (peak 0.109)"},
	Cluck1={vol=0.24,peak=0.413,target=0.10},
	Cluck2={vol=0.18,peak=0.545,target=0.10},
	Cluck3={vol=0.25,peak=0.407,target=0.10},
	ChickenHappy={vol=0.30,peak=0.331,target=0.10},
	-- Rolling ----------------------------------------------------------------
	PodiumThump={vol=0.42,peak=0.425,target=0.18,swap=138910257412285,note="bounce1 (SpectrumSprinkles); Bounce SFX measured too quiet (peak 0.081)"},
	RollEpic={vol=0.36,peak=0.687,target=0.25},
	RollLegendary={vol=0.33,peak=0.783,target=0.26},
	RollMythic={vol=0.33,peak=0.818,target=0.27,swap=1836477530,note="APM Stunning Sting; Magic Glows 4 measured near-silent (peak 0.064)"},
	RollSecret={vol=0.33,peak=0.854,target=0.28},
	MutationHit={vol=0.49,peak=0.515,target=0.25},
	AutoRollHit={vol=0.45,peak=0.513,target=0.23},
	-- VFX/SkillTree ----------------------------------------------------------
	UpgradeMax={vol=0.37,peak=0.710,target=0.26},
	TierUp={vol=0.27,peak=0.921,target=0.25},
	SkillTreeHover={vol=0.11,peak=0.789,target=0.09,swap=79315763728779,speed=1.2,note="ui_hover_bubble_pop_02 pitched 1.2; the authored hover measured near-silent (peak 0.008)"},
	SkillTreePurchase={vol=0.9,peak=0.313,target=0.28},
	SkillTreeNodeAdded={vol=0.29,peak=0.754,target=0.22},
	SkillTreeNodePop={vol=0.21,peak=0.679,target=0.14},
	SkillTreeOpen={vol=0.55,peak=0.239,target=0.13,swap=BUBBLE,speed=1.05,note="soft bubble pop (was Roblox_UI_Whoosh_04)"},
	SkillTreeClose={vol=0.45,peak=0.239,target=0.11,swap=BUBBLE,speed=0.85,note="pop pitched down (was Roblox_UI_Paper_Swipe)"},
	-- Combat -----------------------------------------------------------------
	MarchStart={vol=0.38,peak=0.653,target=0.25},
	CaptureTick={vol=0.26,peak=0.607,target=0.16},
	MissionAppear={vol=0.47,peak=0.464,target=0.22},
	MissionWin={vol=0.35,peak=0.775,target=0.27},
	MissionLose={vol=0.46,peak=0.389,target=0.18},
	FlagRaise={vol=0.31,peak=0.713,target=0.22},
}
local leveled,swapped,missing,approved={},{},{},{}
for cue,p in plan do
	local sound=findCue(cue)
	if not sound then table.insert(missing,cue) continue end
	if sound:GetAttribute("OwnerApproved")~=nil then table.insert(approved,cue) continue end
	if p.swap then
		local id="rbxassetid://"..p.swap
		if sound.SoundId~=id then
			sound:SetAttribute("Previous",sound.SoundId.." vol="..string.format("%.2f",sound.Volume))
			sound.SoundId=id
			table.insert(swapped,cue)
		end
		if p.note then sound:SetAttribute("Usage",(sound:GetAttribute("Usage") or "").." | Oct 21 level pass: "..p.note) end
	end
	sound.Volume=p.vol
	sound.PlaybackSpeed=p.speed or 1
	sound:SetAttribute("MeasuredPeak",p.peak)
	sound:SetAttribute("TargetPeak",p.target)
	sound:SetAttribute("Leveled","Oct21-analyzer")
	table.insert(leveled,cue)
end
print(("level_feel_sounds_20261021: leveled %d, swapped %d, missing %d, owner-approved (left alone) %d"):format(#leveled,#swapped,#missing,#approved))
if #swapped>0 then print("  swapped: "..table.concat(swapped,", ")) end
if #missing>0 then print("  missing (run add_feel_sounds first): "..table.concat(missing,", ")) end
return {leveled=leveled,swapped=swapped,missing=missing,approved=approved}
