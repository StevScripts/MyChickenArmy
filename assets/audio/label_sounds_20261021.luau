--!strict
-- October 21 (Stevin: "add all the sounds to soundservice so if there's a sound I
-- don't like I can replace it myself"). Every game sound already lives in
-- SoundService.MyChickenArmyAudio; this Edit-mode script writes a "PlaysWhen" note on
-- each one so the right Sound is easy to find, and re-creates the two egg-sale cues
-- (CoinPickup, CoinDrop) if an unsaved session lost them. It never changes an
-- existing SoundId or volume. Run it in Studio Edit, then save the place.
local SoundService = game:GetService("SoundService")
local lib = SoundService:WaitForChild("MyChickenArmyAudio")

local PLAYS_WHEN: {[string]: string} = {
	Music = "Background music loop.",
	Collect = "Fallback tick for coin landings (used only if CoinPickup is missing).",
	EggPickup = "Picking up an egg (click, tap or vacuum).",
	EggDeposit = "Stepping on the sell pad with eggs.",
	CashTick = "Coins paid: first coin of an egg sale, offline earnings, chicken sales.",
	CoinPickup = "Each coin reaching you after an egg sale (and daily/sell coin flyers).",
	CoinDrop = "Coins spilling out of the sell pad.",
	EggLay = "A chicken lays an egg.",
	VacuumLoop = "Looped hum while the Egg Vacuum runs.",
	VacuumFull = "The Egg Vacuum's bar fills up.",
	FeedChicken = "Feeding a chicken with Chicken Feed.",
	LevelUp = "A chicken levels up.",
	Cluck1 = "Ambient chicken cluck (random 1 of 3).",
	Cluck2 = "Ambient chicken cluck (random 2 of 3).",
	Cluck3 = "Ambient chicken cluck (random 3 of 3).",
	ChickenHappy = "Happy cluck (fed, equipped).",
	RollLever = "Pulling a roll lever.",
	RollTick = "Each flicker while a podium rolls.",
	RollLand = "The roll stops on a chicken.",
	RollReveal = "A Common/Uncommon chicken is revealed.",
	RollRare = "A Rare chicken is revealed.",
	RollEpic = "An Epic chicken is revealed.",
	RollLegendary = "A Legendary chicken is revealed.",
	RollMythic = "A Mythic chicken is revealed.",
	RollSecret = "A Secret chicken is revealed.",
	MutationHit = "A Golden/Rainbow/Shadow/Cosmic mutation tag appears.",
	AutoRollHit = "Auto Roll stops on a chicken you wanted.",
	PodiumThump = "The rolled chicken lands on its podium.",
	Impact = "Generic hit/landing thud.",
	Victory = "Capturing a camp.",
	CombatHit = "A chicken hits in battle.",
	CombatSwing = "A chicken swings/pecks in battle.",
	CombatKnockout = "A chicken is knocked out in battle.",
	CombatKnockoutCluck = "Squawk when a chicken is knocked out.",
	MarchStart = "Your Army sets off to a camp or Mission.",
	CaptureTick = "Each section of the capture meter fills.",
	MissionAppear = "A Mission site appears.",
	MissionWin = "A Mission is won.",
	MissionLose = "A Mission is lost.",
	FlagRaise = "A flag goes up on a captured camp.",
	CallArmyWhistle = "Call Army whistle.",
	Tick = "Fallback tick when a sound hasn't loaded yet.",
	FallbackImpact = "Fallback thud when a sound hasn't loaded yet.",
	UIHover = "Hovering a button.",
	Click = "Pressing any button.",
	Pop = "Generic pop (fallback for many small UI moments).",
	UIPurchase = "A purchase goes through (chicken, upgrade, shop).",
	Error = "An action fails (not enough Coins, etc.).",
	MenuOpen = "A menu opens.",
	MenuClose = "A menu closes.",
	TabSwitch = "Switching a tab or sort.",
	Toggle = "Flipping a switch (Settings, Auto Roll).",
	Locked = "Pressing something locked or unaffordable.",
	Select = "Marking a chicken card.",
	Equip = "A chicken joins your Army.",
	Unequip = "A chicken leaves your Army.",
	Lock = "Locking a chicken.",
	Unlock = "Unlocking a chicken.",
	Confirm = "Confirm bars (Sell N, Equip Best).",
	Claim = "Claiming a reward (daily, playtime, gift, offline).",
	Jingle = "Short success jingle (shop purchase).",
	CountTick = "Count-ups (Coins readout, receipts).",
	Badge = "A badge or count appears (upgrades ready, notices).",
	Shimmer = "Sparkle sweep (MAX tiers, Legendary+ cards, Index discovery).",
	Whoosh = "Flyers and slides (coins flying, My Base teleport).",
	Fanfare = "Big win (Mission win, Rebirth, first capture).",
	Rebirth = "Deep boom under the Rebirth flash.",
	GemGain = "Gems arrive.",
	GoldRushStart = "Gold Rush begins.",
	GoldRushEnd = "Gold Rush ends.",
	NoticeIn = "A corner notice slides in.",
	SkillTreeHover = "Hovering an Upgrades tier.",
	SkillTreePurchase = "Buying an Upgrades tier.",
	SkillTreeError = "Can't buy an Upgrades tier.",
	SkillTreeNodeAdded = "A new Upgrades tier unlocks.",
	SkillTreeNodePop = "An Upgrades tier pops in.",
	SkillTreeOpen = "Opening Upgrades.",
	SkillTreeClose = "Closing Upgrades.",
	SkillTreeResearchStarted = "Legacy research start (unused since the Oct 20 tree).",
	SkillTreeResearchCompleted = "Legacy research done; fallback for MAX tiers.",
	SkillTreeResearchSlotAdded = "Legacy research slot (unused since the Oct 20 tree).",
	UpgradeMax = "An Upgrades track reaches MAX.",
	TierUp = "An Upgrades tier is bought.",
}

local function note(sound: Sound, cue: string): string?
	local known = PLAYS_WHEN[cue]
	if known then return known end
	if cue:sub(1, 4) == "VFX_" then
		local name = cue:sub(5)
		return "Ambient loop near a " .. name .. " chicken (blank = silent; add a SoundId to give it one)."
	end
	if cue:sub(1, 6) == "Intro_" then
		return "Intro cutscene, scene " .. (sound.Parent and sound.Parent.Name or "?") .. ": " .. cue:sub(7) .. "."
	end
	if sound.Parent and sound.Parent.Name == "Music" then return "Music track (the Music cue picks the playing one)." end
	return nil
end

-- The egg-sale cues live only in the place; recreate them if a session was lost.
local collection = lib:FindFirstChild("Collection")
if collection then
	local group = collection:FindFirstChild("Collect") and (collection.Collect :: Sound).SoundGroup
	for name, id in {CoinPickup = "rbxassetid://71556378621665", CoinDrop = "rbxassetid://134911555436784"} do
		if not collection:FindFirstChild(name) then
			local sound = Instance.new("Sound")
			sound.Name, sound.SoundId, sound.Volume, sound.SoundGroup = name, id, 0.5, group
			sound.Parent = collection
		end
	end
end

local labelled, missing = 0, {}
for _, sound in lib:GetDescendants() do
	if not sound:IsA("Sound") then continue end
	local cue = sound:GetAttribute("AudioCue")
	local text = note(sound, if type(cue) == "string" then cue else sound.Name)
	if text then
		sound:SetAttribute("PlaysWhen", text)
		labelled += 1
	else
		table.insert(missing, sound:GetFullName())
	end
end
lib:SetAttribute("EditingHelp", "Every game sound is here. Select a Sound, read its PlaysWhen attribute, change its SoundId (and Volume) in Edit mode, then save the place. Keep its name and AudioCue attribute: the code plays sounds by those.")
print(("Labelled %d sounds; %d without a note: %s"):format(labelled, #missing, table.concat(missing, ", ")))
