--!strict
-- Presentation only. Restart Play after editing; ModuleScripts are cached.
-- Durations/cooldowns are seconds, world distances studs, HUD sizes pixels.
return {
	Egg = {
		FlightSeconds = 0.40, -- Try 0.3–0.55; does NOT change server settlement.
		Stagger = 0.04, MaxStartWindow = 0.20,
		ArcHeight = 1.65, SideArc = 0.45, -- Short trips automatically use less arc.
		TargetResponse = 26, -- Higher follows moving player/nozzle more tightly.
		TeleportDistance = 24, -- Resolve presentation when a target teleports.
		ComboReset = 0.8, SoundGap = 0.085, MaxVoices = 5,
		Pitches = {1.00, 1.06, 1.12, 1.19, 1.12, 1.06},
		Volume = 0.28, RoverVolume = 0.17, SoundTail = 0.48,
		HudPulse = 1.055, SparkGap = 0.09,
	},
	Deposit = {
		GroupWindow = 0.08, GroupGap = 0.38,
		Count = 3, -- Particles per emitter in ReplicatedStorage.EggDepositEffects.
		Lifetime = 1, -- Destroy the cloned attachment after one second.
		Volume = 0.24,
	},
	Cash = {
		Count = 20, -- Particles per emitter in the Studio-authored Assets.Money attachment.
		Lifetime = 1, -- Destroy the cloned attachment after one second.
		Volume = 0.25, -- Matches the authored Money sound.
	},
	-- October 20 egg sales: gold coins pop out of the sell pad, bounce, then fly into
	-- the player while the Coins readout counts up per coin (client/CoinBurst.luau).
	CoinBurst = {
		MinCoins = 3, MaxCoins = 14, -- One coin per egg sold, within these limits.
		PhoneMaxCoins = 7, -- Touch screens without a keyboard; effects budget only.
		MaxActive = 28, PhoneMaxActive = 14, -- Coins alive at once; extra value counts in at once.
		Size = 1.4, -- Coin width.
		Radius = {2, 4.5}, Spill = 0.6, -- Landing distance from the pad centre; may spill past its edge.
		Height = {2.6, 4.2}, -- Top of the pop above the floor.
		LaunchStagger = 0.025, -- Between coins leaving the pad.
		RiseSeconds = 0.18, FallSeconds = 0.34, -- Rise (Quad Out), then drop with a Bounce ease.
		RestSeconds = 0.05, -- On the pad before the first coin flies in.
		-- October 21 pickup (Stevin's reference recording): a stream of coins arcs into the
		-- player, and a white bubble flashes.
		FlyStagger = 0.035, FlySeconds = 0.36, -- One coin after another into the player.
		FlyArc = {1.5, 5}, FlyArcPerStud = 0.3, -- Arc peak above the straight line, by distance.
		FlipSeconds = {0.16, 0.26}, FlipWidth = 0.15, -- Spin: each coin squashes edge-on and back.
		MaxDistance = 60, -- From the pad; a farther player gets the plain Money burst instead.
		-- "CoinPickup" (falls back to "Collect") plays as each coin lands, rising a little.
		TickVolume = 0.35, PitchStep = 0.02, PitchMax = 1.25, PitchJitter = 0.04,
		HoldTimeout = 4, -- A held sale always reaches the Coins readout within this time.
		DropVolume = 0.4, DropSeconds = 0.9, -- "CoinDrop" plays as the coins spill out of the pad.
		SpillPuff = {Sparkles = 16}, -- Gold puff at the pad as the coins burst out.
		Flash = {Size = {5, 11}, Seconds = 0.38, Transparency = 0.15, GlowTransparency = 0.55, Sparkles = 14}, -- Bubble on stepping in and on the first coin.
	},
	-- October 21 game feel (docs/team/GAME_FEEL_20261021.md, F3): the yard's motion,
	-- VFX and cue budgets. A 100-chicken yard must stay cheap, so every repeating
	-- effect has a gap and a range.
	Feel = {
		LaySoundGap = 0.25, LayRange = 40, -- "EggLay" (else a quiet Pop) and a tiny poof, at most this often.
		LayPopFrom = 0.4, -- A new egg grows in from this share of its size over EggSettleSeconds (Back ease).
		LayPoof = {Count = 4, Size = 0.6}, -- The puff where the egg leaves the chicken.
		PickBurstGap = 0.12, -- Sparkle burst where an egg was picked (click or vacuum), at most this often.
		PickBurst = {Count = 5, Size = 0.28},
		VacuumParticleRate = 12, VacuumParticleRateTouch = 6, -- Suction shimmer at the nozzle while eggs are in reach.
		VacuumFullPitch = 1.3, -- "VacuumFull", else "Collect" at this pitch, when the bar fills.
		HopHeight = 1.5, HopSeconds = 0.45, -- A fed chicken's happy hop (joint pose; V3 rigs play their Victory clip).
		HappyDelay = 0.22, HappyPitch = 1.15, -- "ChickenHappy", else "CombatKnockoutCluck" at this pitch, after the crunch.
		CluckGap = 2.5, CluckRange = 40, -- One ambient Cluck1/2/3 from a random home chicken in range, at most this often.
		PromptShowGap = 0.5, -- A soft "UIHover" when a world prompt appears, at most this often.
		ArrivalJump = 60, -- A character jump of this many studs in one frame is a teleport (My Base): poof, ring, whoosh, flash.
	},
	-- Sound IDs are editable Sound objects in SoundService.MyChickenArmyAudio.
}
