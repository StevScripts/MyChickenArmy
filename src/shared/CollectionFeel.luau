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
		-- player, a white bubble flashes, and a running "N [coin]" counter rides beside them.
		FlyStagger = 0.035, FlySeconds = 0.36, -- One coin after another into the player.
		FlyArc = {1.5, 5}, FlyArcPerStud = 0.3, -- Arc peak above the straight line, by distance.
		FlipSeconds = {0.16, 0.26}, FlipWidth = 0.15, -- Spin: each coin squashes edge-on and back.
		MaxDistance = 60, -- From the pad; a farther player gets the plain Money burst instead.
		-- "CoinPickup" (falls back to "Collect") plays as each coin lands, rising a little.
		TickVolume = 0.35, PitchStep = 0.02, PitchMax = 1.25, PitchJitter = 0.04,
		HoldTimeout = 4, -- A held sale always reaches the Coins readout within this time.
		Flash = {Size = {5, 11}, Seconds = 0.38, Transparency = 0.15, GlowTransparency = 0.55, Sparkles = 14}, -- Bubble on the first coin.
		Counter = {
			Height = 1.5, Gap = 0.4, Lift = 0.4, -- Studs: number height, gap right of the root, rise.
			Toward = 3, -- Studs toward the camera, so nearby chickens rarely cover it.
			Pop = 1.3, PopSeconds = 0.16, -- Each landing coin swells the number briefly.
			Idle = 1.1, -- No coin for this long ends the streak; the counter stays where it was.
			Linger = 1.6, Fade = 0.35, -- A left-behind counter's life, then its fade.
		},
	},
	-- Sound IDs are editable Sound objects in SoundService.MyChickenArmyAudio.
}
