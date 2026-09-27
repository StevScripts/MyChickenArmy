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
		FlightSeconds = 0.28, Stagger = 0.025, MaxSprites = 5,
		Volume = 0.24,
	},
	Cash = {
		Count = 20, -- Particles per emitter in the Studio-authored Assets.Money attachment.
		Lifetime = 1, -- Destroy the cloned attachment after one second.
		Volume = 0.25, -- Matches the authored Money sound.
	},
	-- Sound IDs are editable Sound objects in SoundService.MyChickenArmyAudio.
}
