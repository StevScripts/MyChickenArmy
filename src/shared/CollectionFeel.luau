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
		RiseSeconds = 0.22, FallSeconds = 0.55, -- Rise (Quad Out), then drop with a Bounce ease.
		RestSeconds = 0.12, -- On the pad before the first coin flies in.
		FlyStagger = 0.045, FlySeconds = 0.32, -- One coin after another into the player (Back In).
		FlipSeconds = {0.16, 0.26}, FlipWidth = 0.15, -- Spin: each coin squashes edge-on and back.
		MaxDistance = 60, -- From the pad; a farther player gets the plain Money burst instead.
		TickVolume = 0.3, PitchStep = 0.035, PitchMax = 1.4, -- "Collect" plays as each coin lands.
		HoldTimeout = 4, -- A held sale always reaches the Coins readout within this time.
	},
	-- Sound IDs are editable Sound objects in SoundService.MyChickenArmyAudio.
}
