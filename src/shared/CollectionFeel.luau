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
		HudPulse = 1.055, -- The HUD's "Carrying" line pulses as a clicked egg lands.
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
		-- October 21 reference parity (P6): a "Whoosh" as the sale starts, and one soft thud
		-- when the first coin meets the floor (ThudShare of the Bounce fall, after the rise).
		WhooshPitch = 1.1, WhooshSeconds = 0.6,
		ThudCue = "PodiumThump", ThudPitch = 0.85, -- Else "Impact" at ThudFallbackPitch.
		ThudFallbackPitch = 0.7, ThudVolume = 0.3, ThudShare = 0.36,
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
		VacuumParticleRate = 12, VacuumParticleRateTouch = 6, -- Gold sparkles at the nozzle while eggs are in reach.
		VacuumFullPitch = 1.3, -- "VacuumFull", else "Collect" at this pitch, when the bar fills.
		-- October 21 reference parity (P6, docs/team/REFERENCE_PARITY_20261021.md 2.6).
		-- Each egg that reaches you (click, tap, R2, mouse hold) or the vacuum chimes once and
		-- floats its own "+N" coin value over you (WorldFeel:Text, budgeted).
		ChimeCue = "EggPickup", ChimeFallback = "Collect", -- Swap the two if Collect is the brighter tick.
		ChimePitch = {0.9, 1.3}, ChimeStep = 0.04, -- Rises one step per chime across a streak, capped.
		ChimeGap = 0.07, StreakReset = 0.6, -- Gap floor between chimes; a streak restarts after this idle time.
		ChimeVolume = 0.22, ChimeTail = 0.35, ChimeVoices = 4, -- Volume applies while the cue is unleveled.
		FloatGap = 0.12, FloatGapTouch = 0.2, -- At most one float this often; eggs in between join the next one.
		FloatSize = 26, FloatSeconds = 0.8, FloatRise = 1.8, -- Pixels, seconds, studs (no rise under reduced motion).
		FloatUp = 2.4, FloatSide = {0.3, 1.5}, -- Studs above the root, then to the camera's right (random in range).
		MouseHoldRepeat = 0.12, -- Holding the left mouse button grabs the egg under the pointer this often.
		-- The suction swirl (VacuumController): two yellow ribbons from the player's sides
		-- into the nozzle while eggs are in reach. Studs, seconds, transparency.
		SwirlRadius = 4.5, SwirlHeight = -1.2, -- Where each ribbon starts, from the HumanoidRootPart.
		SwirlWidth = 2.6, SwirlTransparency = 0.35, -- Ribbon width at its outer end; opacity of its body.
		SwirlCurve = {3, 6}, SwirlSway = 0.9, -- The outer curve sways between these sizes, each way this long.
		SwirlSpeed = 1.4, -- Texture scroll toward the nozzle.
		HopHeight = 1.5, HopSeconds = 0.45, -- A fed chicken's happy hop (joint pose; V3 rigs play their Victory clip).
		HappyDelay = 0.22, HappyPitch = 1.15, -- "ChickenHappy", else "CombatKnockoutCluck" at this pitch, after the crunch.
		CluckGap = 2.5, CluckRange = 40, -- One ambient Cluck1/2/3 from a random home chicken in range, at most this often.
		PromptShowGap = 0.5, -- A soft "UIHover" when a world prompt appears, at most this often.
		ArrivalJump = 60, -- A character jump of this many studs in one frame is a teleport (My Base): poof, ring, whoosh, flash.
	},
	-- Sound IDs are editable Sound objects in SoundService.MyChickenArmyAudio.
}
