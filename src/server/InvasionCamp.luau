--!strict
-- October 14 Invasions: the loyalists' landing camp on a random patch of the
-- island. A stepped dirt clearing with scorch marks, a palisade along the back,
-- purple crown banners, a tent, supplies and a purple signal fire whose smoke
-- marks the spot from afar. Same chunky studded style as the authored camps;
-- nothing collides or blocks queries, so chickens path straight through.
local TweenService = game:GetService("TweenService")
local Airship = require(script.Parent.InvasionAirship)
local block, strut, crown = Airship.Block, Airship.Strut, Airship.Crown
local PURPLE, DEEP, GOLD, WOOD, DARKWOOD, DARK = Airship.PURPLE, Airship.DEEP, Airship.GOLD, Airship.WOOD, Airship.DARKWOOD, Airship.DARK
local DIRT = Color3.fromRGB(184, 136, 84)
local TRAMPLED = Color3.fromRGB(158, 112, 68)
local SCORCH = Color3.fromRGB(96, 70, 52)
local STONE = Color3.fromRGB(150, 146, 170)
local Camp = {}

Camp.Radius = 14

-- `side` (+1/-1) mirrors which way the cloth hangs from the pole.
local function banner(parent: Instance, base: CFrame, side: number)
	block(parent, "BannerBase", Vector3.new(2.2, 0.9, 2.2), base * CFrame.new(0, 0.45, 0), STONE)
	block(parent, "BannerPole", Vector3.new(0.6, 10, 0.6), base * CFrame.new(0, 5.6, 0), DARKWOOD, nil, false)
	block(parent, "BannerKnob", Vector3.new(1.1, 1.1, 1.1), base * CFrame.new(0, 11.1, 0), GOLD, nil, false)
	block(parent, "BannerBar", Vector3.new(4, 0.45, 0.45), base * CFrame.new(side * 1.6, 10, 0), DARKWOOD, nil, false)
	local cloth = base * CFrame.new(side * 1.9, 7.4, 0)
	block(parent, "BannerCloth", Vector3.new(3.4, 5, 0.25), cloth, PURPLE, nil, false)
	block(parent, "BannerTrim", Vector3.new(3.4, 0.6, 0.3), cloth * CFrame.new(0, -2.8, 0), GOLD, nil, false)
	block(parent, "BannerTail", Vector3.new(1.2, 0.8, 0.25), cloth * CFrame.new(-1.1, -3.5, 0), PURPLE, nil, false)
	block(parent, "BannerTail", Vector3.new(1.2, 0.8, 0.25), cloth * CFrame.new(1.1, -3.5, 0), PURPLE, nil, false)
	for _, face in {-1, 1} do
		crown(parent, cloth * CFrame.new(0, 0, face * 0.2) * CFrame.Angles(0, if face > 0 then math.pi else 0, 0), 0.38)
	end
end

local function tent(parent: Instance, base: CFrame)
	-- Two wedges back to back make an A-frame.
	for _, side in {-1, 1} do
		block(parent, "Tent", Vector3.new(5.2, 3.4, 2.4), base * CFrame.new(0, 1.7, side * 1.2) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
			if side > 0 then PURPLE else DEEP, "WedgePart")
	end
	block(parent, "TentRidge", Vector3.new(5.6, 0.35, 0.35), base * CFrame.new(0, 3.45, 0), GOLD, nil, false)
	block(parent, "TentDoor", Vector3.new(0.2, 2, 1.4), base * CFrame.new(-2.62, 1, 0), DARK, nil, false)
	block(parent, "TentFlag", Vector3.new(0.2, 1, 1.4), base * CFrame.new(2.75, 4.2, 0.6), GOLD, nil, false)
	block(parent, "TentFlagPole", Vector3.new(0.2, 1.8, 0.2), base * CFrame.new(2.75, 3.9, 0), DARKWOOD, nil, false)
end

local function supplies(parent: Instance, base: CFrame)
	for i, at in {Vector3.new(-1.3, 1.2, 0), Vector3.new(1.3, 1.2, 0.3), Vector3.new(0, 3.6, 0.1)} do
		local cf = base * CFrame.new(at) * CFrame.Angles(0, (i - 2) * 0.25, 0)
		block(parent, "Supply", Vector3.new(2.4, 2.4, 2.4), cf, WOOD)
		block(parent, "SupplyBand", Vector3.new(2.6, 0.4, 2.6), cf, PURPLE, nil, false)
	end
	block(parent, "Barrel", Vector3.new(2.6, 1.8, 1.8), base * CFrame.new(3.4, 1.3, -0.6) * CFrame.Angles(0, 0, math.pi / 2), DARKWOOD, nil, false).Shape = Enum.PartType.Cylinder
end

local function signalFire(parent: Instance, base: CFrame)
	block(parent, "FireBase", Vector3.new(3, 1.2, 3), base * CFrame.new(0, 0.6, 0), STONE)
	block(parent, "FireBowl", Vector3.new(3.6, 0.6, 3.6), base * CFrame.new(0, 1.5, 0), DARK)
	local coals = block(parent, "FireCoals", Vector3.new(2.6, 0.4, 2.6), base * CFrame.new(0, 1.9, 0), Color3.fromRGB(200, 90, 255), nil, false)
	coals.Material = Enum.Material.Neon
	local fire = Instance.new("Fire")
	fire.Color, fire.SecondaryColor, fire.Size, fire.Heat = Color3.fromRGB(190, 80, 255), Color3.fromRGB(255, 150, 230), 7, 12
	fire.Parent = coals
	-- The smoke column is how players spot the landing from across the island.
	local smoke = Instance.new("Smoke")
	smoke.Color, smoke.Opacity, smoke.RiseVelocity, smoke.Size = Color3.fromRGB(160, 90, 235), 0.6, 16, 9
	smoke.Parent = coals
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = Color3.fromRGB(190, 90, 255), 14, 1.4
	glow.Parent = coals
end

-- Build the camp centred on `frame` (-Z faces away from the defender's base,
-- so the open front of the camp faces the arriving army).
function Camp.Build(parent: Instance, frame: CFrame, userId: number): Model
	local model = Instance.new("Model")
	model.Name = "InvasionZone" .. userId
	model:SetAttribute("OwnerUserId", userId)
	local ground = frame * CFrame.new(0, 0, 0)
	local center = block(model, "Center", Vector3.new(1, 0.2, 1), ground, DIRT, nil, false)
	center.Transparency = 1
	model.PrimaryPart = center
	-- The commander's guide arrow and "INVASION" marker point here.
	local marker = Instance.new("Attachment")
	marker.Name, marker.Parent = "Marker", center
	marker.WorldPosition = frame.Position + Vector3.new(0, 0.3, 0)
	-- Stepped dirt clearing (reads round in the voxel style) with a trampled middle.
	for _, size in {Vector3.new(29, 0.34, 17), Vector3.new(17, 0.34, 29), Vector3.new(25, 0.34, 25)} do
		block(model, "Clearing", size, ground, DIRT)
	end
	for _, size in {Vector3.new(19, 0.36, 11), Vector3.new(11, 0.36, 19), Vector3.new(16, 0.36, 16)} do
		block(model, "Trampled", size, ground, TRAMPLED)
	end
	local rng = Random.new(userId + math.floor(frame.Position.X * 7 + frame.Position.Z * 13))
	-- Chunky dirt clods break up the clearing's outline.
	for i = 1, 14 do
		local angle = (i + rng:NextNumber(-0.3, 0.3)) / 14 * math.pi * 2
		local r = rng:NextNumber(12.5, 15)
		local s = rng:NextNumber(2.5, 4.5)
		block(model, "Clod", Vector3.new(s, 0.32, s * rng:NextNumber(0.6, 1)),
			ground * CFrame.new(math.sin(angle) * r, 0, math.cos(angle) * r) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), DIRT)
	end
	-- Scorch marks where the airship's crates hit.
	for _ = 1, 6 do
		local at = Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-10, 10))
		local s = rng:NextNumber(2, 4)
		block(model, "Scorch", Vector3.new(s, 0.38, s * rng:NextNumber(0.6, 1)), ground * CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), SCORCH, nil, false)
	end
	-- The King's crown painted into the middle of the clearing.
	crown(model, ground * CFrame.new(0, 0.3, 1) * CFrame.Angles(-math.pi / 2, 0, 0), 1.25)
	-- Palisade along the back half, like the wooden forts but with gold caps.
	local previous: Vector3? = nil
	local count = 26
	for i = 0, count do
		local angle = math.rad(-80 + 160 * i / count)
		local radial = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local height = if i % 2 == 0 then 3.6 else 3
		local at = ground * CFrame.new(radial * Camp.Radius)
		local stake = CFrame.lookAt(at.Position, ground.Position) * CFrame.new(0, height / 2, 0)
		block(model, "Stake", Vector3.new(1, height, 1), stake, if i % 2 == 0 then WOOD else DARKWOOD, nil, false)
		block(model, "StakeCap", Vector3.new(0.7, 0.5, 0.7), stake * CFrame.new(0, height / 2 + 0.25, 0), if i % 4 == 0 then GOLD else DARKWOOD, nil, false)
		local beam = at.Position + Vector3.new(0, 1.6, 0) + (ground.Position - at.Position).Unit * 0.6
		if previous then strut(model, previous, beam, DARKWOOD, 0.45) end
		previous = beam
	end
	-- Banners flank the open front and mark the palisade's ends.
	for _, degrees in {38, -38, 100, -100} do
		local angle = math.rad(degrees)
		local at = ground * CFrame.new(math.sin(angle) * (Camp.Radius + 1.5), 0, math.cos(angle) * (Camp.Radius + 1.5))
		-- Every banner faces the arriving army, its cloth hanging toward the entrance.
		banner(model, CFrame.lookAt(at.Position, at.Position - ground.LookVector), if degrees > 0 then 1 else -1)
	end
	-- Behind the palisade: the signal fire, a tent and the supply pile.
	signalFire(model, ground * CFrame.new(0, 0, -(Camp.Radius + 3.5)))
	tent(model, ground * CFrame.new(-9.5, 0, -(Camp.Radius + 3)) * CFrame.Angles(0, math.rad(25), 0))
	supplies(model, ground * CFrame.new(9.5, 0, -(Camp.Radius + 2.5)) * CFrame.Angles(0, math.rad(-20), 0))
	model.Parent = parent
	return model
end

-- After `delay` seconds, put out the fire and fade the whole camp away.
function Camp.FadeOut(model: Model, delay: number)
	task.delay(delay, function()
		if not model.Parent then return end
		local info = TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, item in model:GetDescendants() do
			if item:IsA("Fire") or item:IsA("Smoke") or item:IsA("PointLight") then
				item.Enabled = false
			elseif item:IsA("BasePart") and item.Transparency < 1 then
				TweenService:Create(item, info, {Transparency = 1}):Play()
			elseif item:IsA("Texture") then
				TweenService:Create(item, info, {Transparency = 1}):Play()
			end
		end
		task.delay(1.7, function() model:Destroy() end)
	end)
end

return Camp
