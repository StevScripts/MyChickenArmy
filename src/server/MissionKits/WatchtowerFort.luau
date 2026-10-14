--!strict
-- Missions theme kit: Watchtower Fort (docs/team/MISSIONS_PLAN.md §4). A loyalist
-- stone fort in the map's chunky studded style. The seed picks one of three hero
-- pieces (tall watchtower, twin towers with a bridge, stone keep), one of three wall
-- layouts (ring with gatehouse, horseshoe, two arms), a stone palette, an accent and
-- the prop scatter, so no two forts match. Frame space: origin at the courtyard
-- centre, -Z is the back (away from the owner's base), +Z the open entrance.
-- The courtyard centre (radius ~12) stays clear for the loyalist formation.
local Airship = require(script.Parent.Parent.InvasionAirship)
local block, crown = Airship.Block, Airship.Crown
local rgb = Color3.fromRGB
local Kit = {}

local R = 17.5 -- wall radius
local CLEAR = 12.5 -- nothing inside this radius
local GOLD, DARK = Airship.GOLD, Airship.DARK
local WOOD, DARKWOOD = Airship.WOOD, Airship.DARKWOOD
local DIRT = rgb(184, 136, 84)
local IRON = rgb(70, 70, 82)
local HAY = rgb(237, 194, 71)
local SACK = rgb(218, 193, 139)

local STONES = {
	{stone = rgb(141, 141, 211), pale = rgb(188, 192, 255), dark = rgb(104, 104, 170), cobble = rgb(172, 172, 214)}, -- the map's lavender stone
	{stone = rgb(206, 170, 120), pale = rgb(236, 210, 160), dark = rgb(160, 124, 82), cobble = rgb(222, 196, 150)}, -- sandstone
	{stone = rgb(118, 124, 150), pale = rgb(162, 168, 192), dark = rgb(84, 88, 110), cobble = rgb(142, 148, 170)}, -- slate
}
local ACCENTS = {
	{roof = Airship.PURPLE, deep = Airship.DEEP}, -- loyalist purple (twice as likely)
	{roof = Airship.PURPLE, deep = Airship.DEEP},
	{roof = rgb(176, 40, 52), deep = rgb(122, 26, 38)}, -- crimson
}

-- theta: 0 = back (-Z), pi = front (+Z).
local function polar(theta: number, r: number): Vector3
	return Vector3.new(math.sin(theta) * r, 0, -math.cos(theta) * r)
end

local function group(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	return model
end

function Kit.Build(frame: CFrame, rng: Random)
	local stone = STONES[rng:NextInteger(1, #STONES)]
	local accent = ACCENTS[rng:NextInteger(1, #ACCENTS)]
	local function P(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, kind: string?, studs: boolean?): BasePart
		return block(parent, name, size, frame * cf, color, kind, studs)
	end
	local function cylinder(parent: Instance, name: string, length: number, diameter: number, cf: CFrame, color: Color3): BasePart
		local part = P(parent, name, Vector3.new(length, diameter, diameter), cf, color, nil, false)
		part.Shape = Enum.PartType.Cylinder
		return part
	end
	-- A stepped pyramid roof (stacked shrinking blocks) with a gold finial.
	local function roof(parent: Instance, base: CFrame, width: number, steps: number)
		local step = width / (steps + 1)
		for i = 0, steps - 1 do
			local w = width - i * step
			P(parent, "Roof", Vector3.new(w, 1.1, w), base * CFrame.new(0, 0.55 + i * 1.1, 0), if i % 2 == 0 then accent.roof else accent.deep)
		end
		P(parent, "Finial", Vector3.new(0.9, 1.6, 0.9), base * CFrame.new(0, steps * 1.1 + 0.8, 0), GOLD, nil, false)
	end
	-- A hanging banner (cloth, gold trim and a small crown); its +Z side faces out.
	local function banner(parent: Instance, cf: CFrame, width: number, height: number)
		P(parent, "Banner", Vector3.new(width, height, 0.3), cf, accent.roof, nil, false)
		P(parent, "BannerTrim", Vector3.new(width, 0.5, 0.35), cf * CFrame.new(0, -height / 2 + 0.25, 0), GOLD, nil, false)
		P(parent, "BannerRod", Vector3.new(width + 0.8, 0.4, 0.4), cf * CFrame.new(0, height / 2, 0), DARKWOOD, nil, false)
		crown(parent, frame * cf * CFrame.new(0, 0.4, 0.25) * CFrame.Angles(0, math.pi, 0), width / 9)
	end
	-- A square stone tower with corner merlons and a pyramid roof.
	local function tower(parent: Instance, base: CFrame, width: number, height: number, withRoof: boolean)
		P(parent, "TowerPlinth", Vector3.new(width + 1.2, 1, width + 1.2), base * CFrame.new(0, 0.5, 0), stone.dark)
		P(parent, "Tower", Vector3.new(width, height, width), base * CFrame.new(0, height / 2 + 0.5, 0), stone.stone)
		for _, y in {height * 0.45, height * 0.85} do
			P(parent, "TowerBand", Vector3.new(width + 0.4, 0.5, width + 0.4), base * CFrame.new(0, y, 0), stone.pale, nil, false)
		end
		P(parent, "Window", Vector3.new(0.9, 1.8, 0.3), base * CFrame.new(0, height * 0.65, width / 2 + 0.05), DARK, nil, false)
		local top = height + 0.5
		P(parent, "TowerCap", Vector3.new(width + 0.8, 0.6, width + 0.8), base * CFrame.new(0, top + 0.3, 0), stone.dark)
		for _, x in {-1, 1} do
			for _, z in {-1, 1} do
				P(parent, "Merlon", Vector3.new(1.2, 1.2, 1.2), base * CFrame.new(x * (width / 2), top + 1.2, z * (width / 2)), stone.pale, nil, false)
			end
		end
		if withRoof then roof(parent, base * CFrame.new(0, top + 0.6, 0), width - 0.4, 3) end
	end

	------------------------------------------------------------------ Ground
	local ground = group("Ground")
	for _, size in {Vector3.new(36, 0.36, 22), Vector3.new(22, 0.36, 36), Vector3.new(31, 0.36, 31)} do
		P(ground, "Courtyard", size, CFrame.new(), stone.cobble)
	end
	-- Darker flagstones break up the courtyard.
	for _ = 1, 12 do
		local at = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(3, 15))
		local s = rng:NextNumber(2.2, 3.8)
		P(ground, "Flagstone", Vector3.new(s, 0.4, s * rng:NextNumber(0.7, 1)), CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), stone.stone, nil, false)
	end
	-- The approach path out of the entrance, toward the owner's base.
	P(ground, "Path", Vector3.new(7, 0.38, 16), CFrame.new(0, 0, R + 6), DIRT)
	for i = 1, 6 do
		local side = if i % 2 == 0 then 1 else -1
		local s = rng:NextNumber(1.8, 3)
		P(ground, "PathEdge", Vector3.new(s, 0.36, s), CFrame.new(side * rng:NextNumber(3.6, 4.6), 0, R + rng:NextNumber(0, 13)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), DIRT)
	end
	-- Chunky clods soften the courtyard outline.
	for i = 1, 14 do
		local theta = (i + rng:NextNumber(-0.3, 0.3)) / 14 * math.pi * 2
		local s = rng:NextNumber(2.5, 4.2)
		P(ground, "Clod", Vector3.new(s, 0.34, s * rng:NextNumber(0.6, 1)),
			CFrame.new(polar(theta, rng:NextNumber(16.5, 19))) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), if i % 3 == 0 then DIRT else stone.cobble)
	end
	-- The King's crown inlaid in the courtyard, like the landing camps.
	crown(ground, frame * CFrame.new(0, 0.3, 1) * CFrame.Angles(-math.pi / 2, 0, 0), 1.25)

	------------------------------------------------------------------ Walls
	local walls = group("Walls")
	local wallDust = {}
	local layout = rng:NextInteger(1, 3) -- 1 ring + gatehouse, 2 horseshoe, 3 two arms
	local ranges = if layout == 1 then {{-145, 145}} elseif layout == 2 then {{-115, 115}} else {{-125, -38}, {38, 125}}
	local function pillar(at: Vector3)
		P(walls, "Pillar", Vector3.new(3.2, 6.4, 3.2), CFrame.new(at + Vector3.new(0, 3.2, 0)), stone.pale)
		P(walls, "PillarCap", Vector3.new(3.8, 0.6, 3.8), CFrame.new(at + Vector3.new(0, 6.7, 0)), stone.dark)
		P(walls, "PillarTop", Vector3.new(2.2, 0.9, 2.2), CFrame.new(at + Vector3.new(0, 7.45, 0)), accent.roof, nil, false)
	end
	local function wall(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude + 0.6
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid, b)
		P(walls, "WallBase", Vector3.new(2.9, 0.7, length), cf * CFrame.new(0, 0.35, 0), stone.dark)
		P(walls, "Wall", Vector3.new(2.2, 4.4, length), cf * CFrame.new(0, 2.4, 0), stone.stone)
		P(walls, "WallCap", Vector3.new(2.6, 0.5, length), cf * CFrame.new(0, 4.85, 0), stone.dark)
		local count = math.max(1, math.floor(length / 3.2))
		for i = 1, count do
			local z = -length / 2 + (i - 0.5) * length / count
			P(walls, "Merlon", Vector3.new(2.2, 1.2, 1.3), cf * CFrame.new(0, 5.7, z), stone.pale, nil, false)
		end
	end
	for _, range in ranges do
		local from, to = math.rad(range[1]), math.rad(range[2])
		local segments = math.max(2, math.floor((to - from) / math.rad(24) + 0.5))
		local previous = polar(from, R)
		pillar(previous)
		for i = 1, segments do
			local point = polar(from + (to - from) * i / segments, R)
			wall(previous, point)
			-- Pillars at the ends and every second joint; one per joint reads as a colonnade.
			if i == segments or i % 2 == 0 then pillar(point) end
			if i % 2 == 0 then table.insert(wallDust, frame * point) end
			previous = point
		end
	end
	if layout == 1 then
		-- Gatehouse: two towers on the gap's edges joined by a lintel and a banner.
		local left, right = polar(math.rad(145), R), polar(math.rad(-145), R)
		for _, at in {left, right} do
			tower(walls, CFrame.new(at), 4.6, 8.5, true)
		end
		local lintel = CFrame.lookAt((left + right) / 2 + Vector3.new(0, 8.4, 0), right + Vector3.new(0, 8.4, 0))
		P(walls, "Lintel", Vector3.new(2.6, 1.6, (right - left).Magnitude), lintel, DARKWOOD)
		P(walls, "LintelTrim", Vector3.new(2.8, 0.4, (right - left).Magnitude), lintel * CFrame.new(0, 0.9, 0), GOLD, nil, false)
		for i = -2, 2 do
			P(walls, "Portcullis", Vector3.new(0.4, 1.8, 0.4), lintel * CFrame.new(0, -1.6, i * 2.2), IRON, nil, false)
		end
		-- Hung on the outside of the lintel, facing the arriving army.
		banner(walls, CFrame.new((left + right) / 2 + Vector3.new(0, 5.6, 1.4)), 3.6, 4.2)
	end

	------------------------------------------------------------------ Hero piece
	local hero = group("Hero")
	local heroKind = rng:NextInteger(1, 3) -- 1 watchtower, 2 twin towers, 3 keep
	local back = if layout == 3 then R + 1 else R + 5.5
	local base = CFrame.new(0, 0, -back)
	if heroKind == 1 then
		-- The tall watchtower: plinth, shaft with corner pillars, lookout platform, roof.
		P(hero, "Plinth", Vector3.new(10, 1.2, 10), base * CFrame.new(0, 0.6, 0), stone.dark)
		P(hero, "Step", Vector3.new(8.6, 1, 8.6), base * CFrame.new(0, 1.7, 0), stone.pale)
		P(hero, "Shaft", Vector3.new(7, 16, 7), base * CFrame.new(0, 10.2, 0), stone.stone)
		for _, x in {-1, 1} do
			for _, z in {-1, 1} do
				P(hero, "Corner", Vector3.new(1.5, 16.6, 1.5), base * CFrame.new(x * 3.55, 10.3, z * 3.55), stone.pale, nil, false)
			end
		end
		for _, y in {7, 12.5} do
			P(hero, "Band", Vector3.new(7.6, 0.6, 7.6), base * CFrame.new(0, y, 0), stone.dark, nil, false)
		end
		for _, y in {9.8, 15.2} do
			P(hero, "Slit", Vector3.new(0.9, 2.2, 0.3), base * CFrame.new(0, y, 3.55), DARK, nil, false)
			P(hero, "SlitSide", Vector3.new(0.3, 2.2, 0.9), base * CFrame.new(3.55, y, 0), DARK, nil, false)
			P(hero, "SlitSide", Vector3.new(0.3, 2.2, 0.9), base * CFrame.new(-3.55, y, 0), DARK, nil, false)
		end
		P(hero, "Door", Vector3.new(2.6, 3.8, 0.4), base * CFrame.new(0, 4.1, 3.55), DARKWOOD, nil, false)
		P(hero, "DoorArch", Vector3.new(3.4, 0.6, 0.5), base * CFrame.new(0, 6.2, 3.6), GOLD, nil, false)
		-- Lookout platform with a railing of merlons and four posts holding the roof.
		P(hero, "Platform", Vector3.new(10, 1, 10), base * CFrame.new(0, 18.7, 0), DARKWOOD)
		for i = -2, 2 do
			for _, side in {-1, 1} do
				P(hero, "Rail", Vector3.new(1.1, 1.1, 1.1), base * CFrame.new(i * 2.2, 19.75, side * 4.5), stone.pale, nil, false)
				P(hero, "Rail", Vector3.new(1.1, 1.1, 1.1), base * CFrame.new(side * 4.5, 19.75, i * 2.2), stone.pale, nil, false)
			end
		end
		for _, x in {-1, 1} do
			for _, z in {-1, 1} do P(hero, "Post", Vector3.new(0.8, 3.4, 0.8), base * CFrame.new(x * 3.9, 20.9, z * 3.9), WOOD, nil, false) end
		end
		roof(hero, base * CFrame.new(0, 22.6, 0), 10.4, 5)
		banner(hero, base * CFrame.new(0, 13.6, 4.05), 3.4, 5.4)
	elseif heroKind == 2 then
		-- Twin towers joined by a wooden bridge with a banner hanging under it.
		for _, x in {-1, 1} do tower(hero, base * CFrame.new(x * 7, 0, 0), 5.4, 13, true) end
		P(hero, "Bridge", Vector3.new(9, 0.7, 3.2), base * CFrame.new(0, 10.4, 0), WOOD)
		for _, z in {-1, 1} do
			P(hero, "BridgeRail", Vector3.new(9, 0.5, 0.4), base * CFrame.new(0, 11.6, z * 1.5), DARKWOOD, nil, false)
			for i = -1, 1 do P(hero, "BridgePost", Vector3.new(0.4, 1.4, 0.4), base * CFrame.new(i * 3, 11.1, z * 1.5), DARKWOOD, nil, false) end
		end
		banner(hero, base * CFrame.new(0, 7.3, 0), 4, 5.4)
		P(hero, "Plinth", Vector3.new(20, 0.8, 7), base * CFrame.new(0, 0.4, 0), stone.dark)
	else
		-- The keep: a wide two-storey block with battlements and a corner turret.
		P(hero, "Plinth", Vector3.new(16, 1, 11), base * CFrame.new(0, 0.5, 0), stone.dark)
		P(hero, "Keep", Vector3.new(14, 9, 9), base * CFrame.new(0, 5.5, 0), stone.stone)
		P(hero, "Floor", Vector3.new(14.6, 0.6, 9.6), base * CFrame.new(0, 6, 0), stone.pale, nil, false)
		P(hero, "Top", Vector3.new(14.8, 0.7, 9.8), base * CFrame.new(0, 10.35, 0), stone.dark)
		for i = -3, 3 do
			P(hero, "Merlon", Vector3.new(1.3, 1.3, 1.3), base * CFrame.new(i * 2.2, 11.35, 4.4), stone.pale, nil, false)
			P(hero, "Merlon", Vector3.new(1.3, 1.3, 1.3), base * CFrame.new(i * 2.2, 11.35, -4.4), stone.pale, nil, false)
		end
		P(hero, "Gate", Vector3.new(3.6, 5, 0.4), base * CFrame.new(0, 3.5, 4.55), DARKWOOD, nil, false)
		P(hero, "GateArch", Vector3.new(4.4, 0.7, 0.5), base * CFrame.new(0, 6.3, 4.6), GOLD, nil, false)
		for _, x in {-4.5, 4.5} do
			P(hero, "Window", Vector3.new(1.2, 1.8, 0.3), base * CFrame.new(x, 7.8, 4.55), DARK, nil, false)
			banner(hero, base * CFrame.new(x, 4, 4.75), 2.6, 3.8)
		end
		tower(hero, base * CFrame.new(-7.5, 0, -3.5), 4.4, 15, true)
	end
	-- A flag on the tallest point marks the fort from across the island.
	local flagTop = if heroKind == 1 then 29.5 elseif heroKind == 2 then 20.5 else 22
	local flagX = if heroKind == 3 then -7.5 else (if heroKind == 2 then 7 else 0)
	local flagZ = if heroKind == 3 then -3.5 else 0
	P(hero, "FlagPole", Vector3.new(0.4, 6, 0.4), base * CFrame.new(flagX, flagTop, flagZ), DARKWOOD, nil, false)
	P(hero, "Flag", Vector3.new(3.4, 2.2, 0.2), base * CFrame.new(flagX + 1.9, flagTop + 1.7, flagZ), accent.roof, nil, false)
	P(hero, "FlagTip", Vector3.new(0.7, 0.7, 0.7), base * CFrame.new(flagX, flagTop + 3.2, flagZ), GOLD, nil, false)

	------------------------------------------------------------------ Props
	local props = group("Props")
	local used: {{at: Vector3, r: number}} = {}
	local function free(at: Vector3, r: number): boolean
		for _, other in used do
			if (other.at - at).Magnitude < other.r + r then return false end
		end
		return true
	end
	local makers = {}
	function makers.crates(cf: CFrame)
		for i, at in {Vector3.new(-1.3, 1.2, 0), Vector3.new(1.3, 1.2, 0.2), Vector3.new(0, 3.6, 0.1)} do
			local c = cf * CFrame.new(at) * CFrame.Angles(0, (i - 2) * 0.25, 0)
			P(props, "Crate", Vector3.new(2.4, 2.4, 2.4), c, WOOD)
			P(props, "CrateBand", Vector3.new(2.6, 0.4, 2.6), c, accent.roof, nil, false)
		end
	end
	function makers.barrels(cf: CFrame)
		for _, x in {-1.1, 1.1} do
			cylinder(props, "Barrel", 2.4, 2, cf * CFrame.new(x, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2), DARKWOOD)
			cylinder(props, "Hoop", 0.35, 2.15, cf * CFrame.new(x, 1.7, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON)
		end
	end
	function makers.rack(cf: CFrame)
		for _, x in {-1.6, 1.6} do P(props, "RackPost", Vector3.new(0.5, 3, 0.5), cf * CFrame.new(x, 1.5, 0), DARKWOOD, nil, false) end
		P(props, "RackBar", Vector3.new(3.8, 0.4, 0.5), cf * CFrame.new(0, 2.6, 0), WOOD, nil, false)
		for i = -1, 1 do
			P(props, "Spear", Vector3.new(0.25, 4, 0.25), cf * CFrame.new(i * 0.9, 2.2, 0.35) * CFrame.Angles(0.15, 0, 0), DARKWOOD, nil, false)
			P(props, "SpearTip", Vector3.new(0.45, 0.7, 0.45), cf * CFrame.new(i * 0.9, 4.25, 0.65), rgb(200, 205, 215), nil, false)
		end
	end
	function makers.dummy(cf: CFrame)
		P(props, "DummyPost", Vector3.new(0.5, 4, 0.5), cf * CFrame.new(0, 2, 0), DARKWOOD, nil, false)
		P(props, "DummyBody", Vector3.new(1.8, 2, 1.2), cf * CFrame.new(0, 3, 0), SACK, nil, false)
		P(props, "DummyHead", Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(0, 4.6, 0), SACK, nil, false)
		P(props, "DummyArms", Vector3.new(3.4, 0.4, 0.4), cf * CFrame.new(0, 3.5, 0), DARKWOOD, nil, false)
		P(props, "DummyTarget", Vector3.new(1, 1, 0.2), cf * CFrame.new(0, 3.1, 0.65), rgb(220, 60, 60), nil, false)
	end
	function makers.brazier(cf: CFrame)
		P(props, "BrazierBase", Vector3.new(1.6, 2.2, 1.6), cf * CFrame.new(0, 1.1, 0), stone.dark)
		P(props, "BrazierBowl", Vector3.new(2.2, 0.6, 2.2), cf * CFrame.new(0, 2.5, 0), IRON)
		local coals = P(props, "Coals", Vector3.new(1.6, 0.4, 1.6), cf * CFrame.new(0, 2.9, 0), rgb(255, 140, 40), nil, false)
		coals.Material = Enum.Material.Neon
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 3.5, 8, rgb(255, 140, 40), rgb(255, 220, 120)
		fire.Parent = coals
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness = rgb(255, 160, 70), 10, 1.2
		glow.Parent = coals
	end
	function makers.cannon(cf: CFrame)
		P(props, "CannonBed", Vector3.new(2.4, 0.8, 3.4), cf * CFrame.new(0, 1, 0), DARKWOOD)
		for _, x in {-1.4, 1.4} do
			cylinder(props, "Wheel", 0.5, 2.2, cf * CFrame.new(x, 1.1, -0.6), WOOD)
		end
		cylinder(props, "Barrel", 4.2, 1.3, cf * CFrame.new(0, 1.9, 0.6) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0.15), IRON)
		cylinder(props, "Muzzle", 0.5, 1.6, cf * CFrame.new(0, 2.2, 2.6) * CFrame.Angles(0, math.pi / 2, 0), DARK)
		for _, x in {-0.5, 0.5} do P(props, "Ball", Vector3.new(0.9, 0.9, 0.9), cf * CFrame.new(x, 0.45, -2.1), DARK, nil, false).Shape = Enum.PartType.Ball end
	end
	function makers.hay(cf: CFrame)
		P(props, "Hay", Vector3.new(3, 1.6, 2), cf * CFrame.new(0, 0.8, 0), HAY)
		P(props, "Hay", Vector3.new(2.6, 1.4, 1.8), cf * CFrame.new(0.3, 2.3, 0.1) * CFrame.Angles(0, 0.3, 0), HAY)
		P(props, "HayBand", Vector3.new(0.3, 1.7, 2.1), cf * CFrame.new(-0.6, 0.8, 0), DARKWOOD, nil, false)
	end
	function makers.tent(cf: CFrame)
		for _, side in {-1, 1} do
			P(props, "Tent", Vector3.new(4.6, 3, 2.2), cf * CFrame.new(0, 1.5, side * 1.1) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
				if side > 0 then accent.roof else accent.deep, "WedgePart")
		end
		P(props, "TentRidge", Vector3.new(5, 0.35, 0.35), cf * CFrame.new(0, 3.05, 0), GOLD, nil, false)
	end
	function makers.bannerPole(cf: CFrame)
		P(props, "PoleBase", Vector3.new(2, 0.8, 2), cf * CFrame.new(0, 0.4, 0), stone.dark)
		P(props, "Pole", Vector3.new(0.5, 9, 0.5), cf * CFrame.new(0, 5.1, 0), DARKWOOD, nil, false)
		P(props, "PoleKnob", Vector3.new(1, 1, 1), cf * CFrame.new(0, 10.1, 0), GOLD, nil, false)
		P(props, "PoleBar", Vector3.new(3.6, 0.4, 0.4), cf * CFrame.new(1.4, 9.2, 0), DARKWOOD, nil, false)
		P(props, "PoleCloth", Vector3.new(3, 4.4, 0.25), cf * CFrame.new(1.7, 6.8, 0), accent.roof, nil, false)
		P(props, "PoleTrim", Vector3.new(3, 0.5, 0.3), cf * CFrame.new(1.7, 4.6, 0), GOLD, nil, false)
	end
	local function place(kind: string, at: Vector3, r: number, cf: CFrame)
		table.insert(used, {at = at, r = r})
		makers[kind](cf)
	end
	-- Always: braziers flanking the entrance and two banner poles at the sides.
	for _, side in {-1, 1} do
		local at = Vector3.new(side * 6, 0, R + 2.5)
		place("brazier", at, 2, CFrame.new(at))
		local pole = polar(side * math.rad(118), R + 3.4)
		place("bannerPole", pole, 2.5, CFrame.lookAt(pole, Vector3.zero))
	end
	-- Seeded scatter in the courtyard ring, clear of the centre and the entrance.
	local pool = {"crates", "crates", "barrels", "barrels", "rack", "rack", "dummy", "dummy", "hay", "cannon", "tent", "brazier"}
	local radius = {crates = 2.6, barrels = 2.4, rack = 2.4, dummy = 1.8, hay = 2.2, cannon = 2.6, tent = 3, brazier = 1.8}
	local wanted, tries = rng:NextInteger(9, 13), 0
	while wanted > 0 and tries < 90 do
		tries += 1
		local kind = pool[rng:NextInteger(1, #pool)]
		local theta = rng:NextNumber(math.rad(-135), math.rad(135))
		local at = polar(theta, rng:NextNumber(CLEAR, R - 2.6))
		if math.abs(at.X) < 4.5 and at.Z > 0 then continue end -- keep the entrance lane open
		if not free(at, radius[kind]) then continue end
		-- Cannons aim out of the entrance; everything else faces the courtyard.
		local cf = if kind == "cannon" then CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
			else CFrame.lookAt(at, Vector3.zero) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
		place(kind, at, radius[kind], cf)
		wanted -= 1
	end

	return {
		{model = ground},
		{model = walls, dust = wallDust, dustScale = 1.2},
		{model = hero, dust = {frame * (base.Position + Vector3.new(-4, 0, 3)), frame * (base.Position + Vector3.new(4, 0, 3))}, dustScale = 1.6},
		{model = props},
	}
end

return Kit
