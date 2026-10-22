--!strict
-- October 20 collection tools (docs/team/COLLECTION_TOOLS.md): click/tap/gamepad egg
-- pickup, the held Egg Vacuum and Chicken Feed. Tuning only: EggService owns claims,
-- cargo and Coins, ToolService owns the tools and Feed purchases. The robot vacuum
-- (Auto Collect pass) is retired; its code is in archive/robot-vacuum-20261020.
-- Distances are flat studs from the player's character.
local function rgb(r: number, g: number, b: number): Color3 return Color3.fromRGB(r, g, b) end

return table.freeze({
	-- Click, tap or gamepad R2: Click Range plus the Click Range tiers (pickupStuds).
	-- The server allows ClickSlack more for a running player's latency.
	ClickRange = 12,
	ClickSlack = 3,
	ClickBatch = 12, -- Egg ids per CollectEggs request.
	ClickRequestSeconds = 0.2, -- The client batches clicks at most this often.
	MaxHeight = 12, -- Vertical reach for clicks and the vacuum.

	-- Egg Vacuum: while equipped it pulls ready eggs within Range (+ Vacuum Range tiers)
	-- until it holds Capacity eggs (+ Vacuum Capacity tiers and Gem levels, also eggs).
	-- October 21 (Stevin: "too large very easily"): a fixed egg count, no longer seconds
	-- of the Flock's laying, so Flock Size and Egg Speed never grow it for free.
	-- October 22 (Stevin: fills "JUST a little too fast"): 25, was 20 (a bit over one
	-- full yard early on; the tutorial's 20-egg VacuumGoal still fits in one load).
	Range = 10,
	Capacity = 25,
	PickupBatch = 8, -- Stacks claimed per server step.
	PickupStagger = 0.05,

	-- Chicken Feed: the prompt's reach to one of your chickens at home.
	FeedRange = 10,
	FeedSlack = 4,

	-- Hotbar order (keys 1, 2). ToolService builds each tool from its model below,
	-- unless ReplicatedStorage.PetRoll.Assets.Tools holds a Studio Tool of that name.
	ToolOrder = {"EggVacuum", "ChickenFeed"},
	ToolNames = {EggVacuum = "Egg Vacuum", ChickenFeed = "Chicken Feed"},
	-- Uploaded October 20 (assets/upgrade-icons-20261020/upload-receipts.json).
	ToolIcons = {EggVacuum = "rbxassetid://130089766443010", ChickenFeed = "rbxassetid://122007287446526"},

	-- Held models, in the Tool's grip space: -Z forward, +Y up, the hand at the origin.
	-- Size is the Roblox Size (a Cylinder's length is X); Rot is CFrame.Angles in degrees.
	-- Scale multiplies every size and position. "Egg" parts clone the Duck voxel egg.
	Models = {
		-- Claude Design canvas "Egg Vacuum Model" (https://claude.ai/artifact/MmMV4VPQBL5YG3eZmdxxvc).
		EggVacuum = {
			Scale = 0.75,
			Grip = CFrame.new(),
			Nozzle = Vector3.new(0, 0.95, -2.38), -- Pulled eggs fly into this point.
			Colors = {
				Body = rgb(229, 64, 43), Body2 = rgb(183, 51, 34), Vent = rgb(115, 32, 22), Trigger = rgb(255, 201, 60),
				Steel = rgb(185, 194, 203), Steel2 = rgb(112, 122, 134), Mouth = rgb(21, 23, 27),
				Accent = rgb(244, 183, 30), Accent2 = rgb(190, 143, 23), Tank = rgb(169, 221, 255), Egg = rgb(255, 244, 222),
			},
			Parts = {
				{Name = "Grip", Shape = "Block", Size = Vector3.new(0.42, 1.1, 0.5), At = Vector3.new(0, 0, 0.05), Rot = Vector3.new(-12, 0, 0), Color = "Body2", Material = "SmoothPlastic"},
				{Name = "Body", Shape = "Block", Size = Vector3.new(0.72, 0.8, 1.7), At = Vector3.new(0, 0.95, -0.2), Rot = Vector3.zero, Color = "Body", Material = "SmoothPlastic"},
				{Name = "BackCap", Shape = "Block", Size = Vector3.new(0.6, 0.6, 0.14), At = Vector3.new(0, 0.95, 0.7), Rot = Vector3.zero, Color = "Body2", Material = "SmoothPlastic"},
				{Name = "Vent", Shape = "Block", Size = Vector3.new(0.76, 0.06, 0.4), At = Vector3.new(0, 0.82, 0.25), Rot = Vector3.zero, Color = "Vent", Material = "SmoothPlastic"},
				{Name = "Vent", Shape = "Block", Size = Vector3.new(0.76, 0.06, 0.4), At = Vector3.new(0, 0.95, 0.25), Rot = Vector3.zero, Color = "Vent", Material = "SmoothPlastic"},
				{Name = "Vent", Shape = "Block", Size = Vector3.new(0.76, 0.06, 0.4), At = Vector3.new(0, 1.08, 0.25), Rot = Vector3.zero, Color = "Vent", Material = "SmoothPlastic"},
				{Name = "Trigger", Shape = "Block", Size = Vector3.new(0.14, 0.3, 0.14), At = Vector3.new(0, 0.42, -0.42), Rot = Vector3.new(-10, 0, 0), Color = "Trigger", Material = "SmoothPlastic"},
				{Name = "Collar", Shape = "Cylinder", Size = Vector3.new(0.3, 0.84, 0.84), At = Vector3.new(0, 0.95, -1.18), Rot = Vector3.new(0, 90, 0), Color = "Steel", Material = "Metal"},
				{Name = "Barrel", Shape = "Cylinder", Size = Vector3.new(0.8, 0.62, 0.62), At = Vector3.new(0, 0.95, -1.7), Rot = Vector3.new(0, 90, 0), Color = "Steel", Material = "Metal"},
				{Name = "Tip", Shape = "Cylinder", Size = Vector3.new(0.24, 0.88, 0.88), At = Vector3.new(0, 0.95, -2.2), Rot = Vector3.new(0, 90, 0), Color = "Steel2", Material = "Metal"},
				{Name = "Mouth", Shape = "Cylinder", Size = Vector3.new(0.04, 0.62, 0.62), At = Vector3.new(0, 0.95, -2.335), Rot = Vector3.new(0, 90, 0), Color = "Mouth", Material = "SmoothPlastic"},
				{Name = "CapBottom", Shape = "Cylinder", Size = Vector3.new(0.12, 0.86, 0.86), At = Vector3.new(0, 1.41, -0.3), Rot = Vector3.new(0, 0, 90), Color = "Accent", Material = "SmoothPlastic"},
				{Name = "Tank", Shape = "Cylinder", Size = Vector3.new(0.52, 0.76, 0.76), At = Vector3.new(0, 1.73, -0.3), Rot = Vector3.new(0, 0, 90), Color = "Tank", Material = "Glass", Transparency = 0.5},
				{Name = "CapTop", Shape = "Cylinder", Size = Vector3.new(0.12, 0.86, 0.86), At = Vector3.new(0, 2.05, -0.3), Rot = Vector3.new(0, 0, 90), Color = "Accent", Material = "SmoothPlastic"},
				{Name = "Knob", Shape = "Cylinder", Size = Vector3.new(0.08, 0.34, 0.34), At = Vector3.new(0, 2.15, -0.3), Rot = Vector3.new(0, 0, 90), Color = "Accent2", Material = "SmoothPlastic"},
				{Name = "TankEgg", Shape = "Egg", Size = Vector3.new(0.24, 0.3, 0.24), At = Vector3.new(-0.14, 1.63, -0.22), Rot = Vector3.new(0, 0, 12), Color = "Egg", Material = "SmoothPlastic"},
				{Name = "TankEgg", Shape = "Egg", Size = Vector3.new(0.24, 0.3, 0.24), At = Vector3.new(0.14, 1.63, -0.36), Rot = Vector3.new(0, 0, -10), Color = "Egg", Material = "SmoothPlastic"},
				{Name = "TankEgg", Shape = "Egg", Size = Vector3.new(0.24, 0.3, 0.24), At = Vector3.new(0, 1.82, -0.28), Rot = Vector3.new(8, 0, 0), Color = "Egg", Material = "SmoothPlastic"},
			},
		},
		-- An open feed sack (the S6 Chicken Feed icon), hanging from the hand.
		ChickenFeed = {
			Scale = 0.8,
			Grip = CFrame.new(0, 0.6, 0),
			Colors = {Sack = rgb(217, 164, 65), Rim = rgb(184, 134, 48), Band = rgb(79, 138, 46), Corn = rgb(246, 201, 69),
				Badge = rgb(245, 243, 236), Comb = rgb(214, 48, 41)},
			Parts = {
				{Name = "Sack", Shape = "Block", Size = Vector3.new(0.9, 0.8, 0.7), At = Vector3.zero, Rot = Vector3.zero, Color = "Sack", Material = "Fabric"},
				{Name = "Band", Shape = "Block", Size = Vector3.new(0.94, 0.2, 0.74), At = Vector3.new(0, -0.05, 0), Rot = Vector3.zero, Color = "Band", Material = "SmoothPlastic"},
				{Name = "Rim", Shape = "Block", Size = Vector3.new(0.96, 0.14, 0.76), At = Vector3.new(0, 0.42, 0), Rot = Vector3.zero, Color = "Rim", Material = "Fabric"},
				{Name = "Corn", Shape = "Block", Size = Vector3.new(0.8, 0.1, 0.6), At = Vector3.new(0, 0.47, 0), Rot = Vector3.zero, Color = "Corn", Material = "Pebble"},
				{Name = "Badge", Shape = "Block", Size = Vector3.new(0.24, 0.24, 0.04), At = Vector3.new(0, -0.05, -0.385), Rot = Vector3.zero, Color = "Badge", Material = "SmoothPlastic"},
				{Name = "Comb", Shape = "Block", Size = Vector3.new(0.1, 0.08, 0.04), At = Vector3.new(0, 0.11, -0.39), Rot = Vector3.zero, Color = "Comb", Material = "SmoothPlastic"},
			},
		},
	},
})
