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
		OutSeconds = 0.65, -- Full curve duration with Exponential Out easing.
		ReturnDelay = 0.30, -- Interrupt the outward curve, matching the supplied script.
		InSeconds = 0.30, -- Exponential In return; Quad In image fade.
		Count = 10, -- Clones of the Studio-authored Assets.CashDrop (including its trail).
		Volume = 0.28,
	},
	Sounds = {
		-- Existing game assets, separate roles/mixes; no asset upload required.
		EggPickup = "rbxassetid://6586979979", -- Soft cartoon pop.
		EggDeposit = "rbxassetid://9120914570", -- Short wood/basket contact.
		CashTick = "rbxassetid://135483737426662", -- Coin arrival.
	},
}
