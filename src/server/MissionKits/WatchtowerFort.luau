--!strict
-- Missions theme kit: Watchtower Fort. A small loyalist stone fort, camp-sized
-- (Common: radius 15, footprint ~40 studs). The seed picks one of three hero
-- pieces (watchtower, twin towers with a bridge, keep), one of three wall layouts
-- (ring with gatehouse, horseshoe, two arms), a stone palette, an accent and the
-- props. MissionSite.Studify adds the map's stud texture to every face.
local Airship = require(script.Parent.Parent.InvasionAirship)
local Common = require(script.Parent.Common)
local crown = Airship.Crown
local rgb = Common.rgb
local Kit = {}

local R, BACK = Common.R, Common.BACK
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

function Kit.Build(frame: CFrame, rng: Random)
	local ctx = Common.new(frame, rng)
	local P, cyl, polar = ctx.P, ctx.cyl, Common.polar
	local stone = ctx.pick(STONES)
	local accent = ctx.pick(ACCENTS)
	local function roof(parent: Instance, base: CFrame, width: number, steps: number)
		local step = width / (steps + 1)
		for i = 0, steps - 1 do
			P(parent, "Roof", Vector3.new(width - i * step, 0.9, width - i * step), base * CFrame.new(0, 0.45 + i * 0.9, 0), if i % 2 == 0 then accent.roof else accent.deep)
		end
		P(parent, "Finial", Vector3.new(0.8, 1.3, 0.8), base * CFrame.new(0, steps * 0.9 + 0.65, 0), GOLD)
	end
	-- A hanging banner; its +Z side (with the crown) faces out.
	local function banner(parent: Instance, cf: CFrame, width: number, height: number)
		P(parent, "Banner", Vector3.new(width, height, 0.3), cf, accent.roof)
		P(parent, "BannerTrim", Vector3.new(width, 0.45, 0.35), cf * CFrame.new(0, -height / 2 + 0.22, 0), GOLD)
		P(parent, "BannerRod", Vector3.new(width + 0.6, 0.35, 0.35), cf * CFrame.new(0, height / 2, 0), DARKWOOD)
		crown(parent, frame * cf * CFrame.new(0, 0.3, 0.25) * CFrame.Angles(0, math.pi, 0), width / 10)
	end
	local function tower(parent: Instance, base: CFrame, width: number, height: number)
		P(parent, "TowerPlinth", Vector3.new(width + 1, 0.8, width + 1), base * CFrame.new(0, 0.4, 0), stone.dark)
		P(parent, "Tower", Vector3.new(width, height, width), base * CFrame.new(0, height / 2 + 0.4, 0), stone.stone)
		P(parent, "TowerBand", Vector3.new(width + 0.3, 0.45, width + 0.3), base * CFrame.new(0, height * 0.55, 0), stone.pale)
		P(parent, "Window", Vector3.new(0.8, 1.4, 0.3), base * CFrame.new(0, height * 0.72, width / 2 + 0.05), DARK)
		local top = height + 0.4
		P(parent, "TowerCap", Vector3.new(width + 0.6, 0.5, width + 0.6), base * CFrame.new(0, top + 0.25, 0), stone.dark)
		for _, x in {-1, 1} do
			for _, z in {-1, 1} do P(parent, "Merlon", Vector3.new(1, 1, 1), base * CFrame.new(x * width / 2, top + 1, z * width / 2), stone.pale) end
		end
		roof(parent, base * CFrame.new(0, top + 0.5, 0), width - 0.4, 3)
	end

	------------------------------------------------------------------ Ground
	local ground = ctx.group("Ground")
	ctx.patch(ground, stone.cobble, 15.5)
	for _ = 1, 9 do
		local at = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(3, 12.5))
		local s = rng:NextNumber(2, 3.2)
		P(ground, "Flagstone", Vector3.new(s, 0.4, s * rng:NextNumber(0.7, 1)), CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), stone.stone)
	end
	ctx.clods(ground, {stone.cobble, stone.cobble, DIRT}, 14.5, 16.5, 12)
	ctx.path(ground, DIRT)
	crown(ground, frame * CFrame.new(0, 0.3, 1) * CFrame.Angles(-math.pi / 2, 0, 0), 1)

	------------------------------------------------------------------ Walls
	local walls = ctx.group("Walls")
	local wallDust = {}
	local layout = rng:NextInteger(1, 3) -- 1 ring + gatehouse, 2 horseshoe, 3 two arms
	-- The back centre (±22°) is the hero's slot in every layout.
	local ranges = if layout == 1 then {{-145, -22}, {22, 145}} elseif layout == 2 then {{-112, -22}, {22, 112}} else {{-125, -45}, {45, 125}}
	local function pillar(at: Vector3)
		P(walls, "Pillar", Vector3.new(2.6, 5.2, 2.6), CFrame.new(at + Vector3.new(0, 2.6, 0)), stone.pale)
		P(walls, "PillarCap", Vector3.new(3.1, 0.5, 3.1), CFrame.new(at + Vector3.new(0, 5.45, 0)), stone.dark)
		P(walls, "PillarTop", Vector3.new(1.8, 0.8, 1.8), CFrame.new(at + Vector3.new(0, 6.1, 0)), accent.roof)
	end
	local function wall(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude + 0.5
		local cf = CFrame.lookAt((a + b) / 2, b)
		P(walls, "WallBase", Vector3.new(2.4, 0.6, length), cf * CFrame.new(0, 0.3, 0), stone.dark)
		P(walls, "Wall", Vector3.new(1.8, 3.6, length), cf * CFrame.new(0, 2, 0), stone.stone)
		P(walls, "WallCap", Vector3.new(2.2, 0.45, length), cf * CFrame.new(0, 4, 0), stone.dark)
		local count = math.max(1, math.floor(length / 2.8))
		for i = 1, count do
			P(walls, "Merlon", Vector3.new(1.8, 1, 1.1), cf * CFrame.new(0, 4.7, -length / 2 + (i - 0.5) * length / count), stone.pale)
		end
	end
	for _, range in ranges do
		local from, to = math.rad(range[1]), math.rad(range[2])
		local segments = math.max(2, math.floor((to - from) / math.rad(26) + 0.5))
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
		-- Gatehouse: two small towers on the gap's edges, a lintel and a banner.
		local left, right = polar(math.rad(145), R), polar(math.rad(-145), R)
		tower(walls, CFrame.new(left), 3.6, 6.4)
		tower(walls, CFrame.new(right), 3.6, 6.4)
		local span = (right - left).Magnitude
		local lintel = CFrame.lookAt((left + right) / 2 + Vector3.new(0, 6.6, 0), right + Vector3.new(0, 6.6, 0))
		P(walls, "Lintel", Vector3.new(2.2, 1.3, span), lintel, DARKWOOD)
		P(walls, "LintelTrim", Vector3.new(2.4, 0.35, span), lintel * CFrame.new(0, 0.8, 0), GOLD)
		for i = -2, 2 do P(walls, "Portcullis", Vector3.new(0.35, 1.4, 0.35), lintel * CFrame.new(0, -1.3, i * 1.9), IRON) end
		banner(walls, CFrame.new((left + right) / 2 + Vector3.new(0, 4.3, 1.2)), 2.8, 3.2)
	end

	------------------------------------------------------------------ Hero piece
	local hero = ctx.group("Hero")
	local base = CFrame.new(0, 0, -BACK)
	local heroKind = rng:NextInteger(1, 3) -- 1 watchtower, 2 twin towers, 3 keep
	local flagTop, flagX, flagZ
	if heroKind == 1 then
		P(hero, "Plinth", Vector3.new(7.4, 1, 7.4), base * CFrame.new(0, 0.5, 0), stone.dark)
		P(hero, "Shaft", Vector3.new(5.4, 11, 5.4), base * CFrame.new(0, 6.5, 0), stone.stone)
		for _, x in {-1, 1} do
			for _, z in {-1, 1} do P(hero, "Corner", Vector3.new(1.1, 11.4, 1.1), base * CFrame.new(x * 2.75, 6.7, z * 2.75), stone.pale) end
		end
		P(hero, "Band", Vector3.new(5.8, 0.5, 5.8), base * CFrame.new(0, 7.2, 0), stone.dark)
		P(hero, "Slit", Vector3.new(0.7, 1.6, 0.3), base * CFrame.new(0, 9.2, 2.75), DARK)
		P(hero, "Door", Vector3.new(2, 2.8, 0.3), base * CFrame.new(0, 2.4, 2.75), DARKWOOD)
		P(hero, "DoorArch", Vector3.new(2.6, 0.45, 0.4), base * CFrame.new(0, 4, 2.8), GOLD)
		P(hero, "Platform", Vector3.new(7.2, 0.8, 7.2), base * CFrame.new(0, 12.4, 0), DARKWOOD)
		for i = -1, 1 do
			for _, side in {-1, 1} do
				P(hero, "Rail", Vector3.new(0.9, 0.9, 0.9), base * CFrame.new(i * 2.2, 13.25, side * 3.2), stone.pale)
				P(hero, "Rail", Vector3.new(0.9, 0.9, 0.9), base * CFrame.new(side * 3.2, 13.25, i * 2.2), stone.pale)
			end
		end
		for _, x in {-1, 1} do
			for _, z in {-1, 1} do P(hero, "Post", Vector3.new(0.6, 2.6, 0.6), base * CFrame.new(x * 2.9, 14.1, z * 2.9), WOOD) end
		end
		roof(hero, base * CFrame.new(0, 15.4, 0), 7.6, 4)
		banner(hero, base * CFrame.new(0, 8.9, 2.95), 2.6, 3.6)
		flagTop, flagX, flagZ = 20.7, 0, 0
	elseif heroKind == 2 then
		for _, x in {-1, 1} do tower(hero, base * CFrame.new(x * 5, 0, 0), 4, 9) end
		P(hero, "Bridge", Vector3.new(6.2, 0.6, 2.6), base * CFrame.new(0, 7.3, 0), WOOD)
		for _, z in {-1, 1} do P(hero, "BridgeRail", Vector3.new(6.2, 0.4, 0.35), base * CFrame.new(0, 8.3, z * 1.2), DARKWOOD) end
		banner(hero, base * CFrame.new(0, 4.9, 0), 3, 3.8)
		flagTop, flagX, flagZ = 15.2, 5, 0
	else
		P(hero, "Plinth", Vector3.new(12, 0.8, 7.6), base * CFrame.new(0, 0.4, 0), stone.dark)
		P(hero, "Keep", Vector3.new(10.6, 6.6, 6.4), base * CFrame.new(0, 4.1, 0), stone.stone)
		P(hero, "Top", Vector3.new(11.2, 0.6, 7), base * CFrame.new(0, 7.7, 0), stone.dark)
		for i = -2, 2 do
			for _, z in {-3.2, 3.2} do P(hero, "Merlon", Vector3.new(1.1, 1.1, 1.1), base * CFrame.new(i * 2.4, 8.55, z), stone.pale) end
		end
		P(hero, "Gate", Vector3.new(2.8, 3.8, 0.3), base * CFrame.new(0, 2.7, 3.25), DARKWOOD)
		P(hero, "GateArch", Vector3.new(3.4, 0.55, 0.4), base * CFrame.new(0, 4.85, 3.3), GOLD)
		for _, x in {-3.6, 3.6} do banner(hero, base * CFrame.new(x, 4, 3.45), 2, 2.8) end
		tower(hero, base * CFrame.new(-5.6, 0, -2.6), 3.4, 11)
		flagTop, flagX, flagZ = 16.6, -5.6, -2.6
	end
	P(hero, "FlagPole", Vector3.new(0.35, 4.6, 0.35), base * CFrame.new(flagX, flagTop, flagZ), DARKWOOD)
	P(hero, "Flag", Vector3.new(2.8, 1.8, 0.2), base * CFrame.new(flagX + 1.55, flagTop + 1.3, flagZ), accent.roof)
	P(hero, "FlagTip", Vector3.new(0.6, 0.6, 0.6), base * CFrame.new(flagX, flagTop + 2.5, flagZ), GOLD)

	------------------------------------------------------------------ Props
	local props = ctx.group("Props")
	local makers = {}
	function makers.crates(cf: CFrame)
		for i, at in {Vector3.new(-1.1, 1, 0), Vector3.new(1.1, 1, 0.2), Vector3.new(0, 3, 0.1)} do
			local c = cf * CFrame.new(at) * CFrame.Angles(0, (i - 2) * 0.25, 0)
			P(props, "Crate", Vector3.new(2, 2, 2), c, WOOD)
			P(props, "CrateBand", Vector3.new(2.15, 0.35, 2.15), c, accent.roof)
		end
	end
	function makers.barrels(cf: CFrame)
		for _, x in {-0.95, 0.95} do
			cyl(props, "Barrel", 2, 1.7, cf * CFrame.new(x, 1, 0) * CFrame.Angles(0, 0, math.pi / 2), DARKWOOD)
			cyl(props, "Hoop", 0.3, 1.85, cf * CFrame.new(x, 1.4, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON)
		end
	end
	function makers.rack(cf: CFrame)
		for _, x in {-1.3, 1.3} do P(props, "RackPost", Vector3.new(0.45, 2.6, 0.45), cf * CFrame.new(x, 1.3, 0), DARKWOOD) end
		P(props, "RackBar", Vector3.new(3.1, 0.35, 0.45), cf * CFrame.new(0, 2.2, 0), WOOD)
		for i = -1, 1 do
			P(props, "Spear", Vector3.new(0.22, 3.4, 0.22), cf * CFrame.new(i * 0.8, 1.9, 0.3) * CFrame.Angles(0.15, 0, 0), DARKWOOD)
			P(props, "SpearTip", Vector3.new(0.4, 0.6, 0.4), cf * CFrame.new(i * 0.8, 3.65, 0.55), rgb(200, 205, 215))
		end
	end
	function makers.dummy(cf: CFrame)
		P(props, "DummyPost", Vector3.new(0.45, 3.4, 0.45), cf * CFrame.new(0, 1.7, 0), DARKWOOD)
		P(props, "DummyBody", Vector3.new(1.5, 1.7, 1), cf * CFrame.new(0, 2.6, 0), SACK)
		P(props, "DummyHead", Vector3.new(1, 1, 1), cf * CFrame.new(0, 3.9, 0), SACK)
		P(props, "DummyArms", Vector3.new(2.8, 0.35, 0.35), cf * CFrame.new(0, 3, 0), DARKWOOD)
	end
	function makers.brazier(cf: CFrame)
		P(props, "BrazierBase", Vector3.new(1.4, 1.8, 1.4), cf * CFrame.new(0, 0.9, 0), stone.dark)
		P(props, "BrazierBowl", Vector3.new(1.9, 0.5, 1.9), cf * CFrame.new(0, 2.05, 0), IRON)
		local coals = ctx.neon(P(props, "Coals", Vector3.new(1.4, 0.35, 1.4), cf * CFrame.new(0, 2.4, 0), rgb(255, 140, 40)), rgb(255, 160, 70), 9)
		ctx.fire(coals, 3, rgb(255, 140, 40), rgb(255, 220, 120))
	end
	function makers.cannon(cf: CFrame)
		P(props, "CannonBed", Vector3.new(2, 0.7, 2.8), cf * CFrame.new(0, 0.85, 0), DARKWOOD)
		for _, x in {-1.2, 1.2} do cyl(props, "Wheel", 0.45, 1.9, cf * CFrame.new(x, 0.95, -0.5), WOOD) end
		cyl(props, "Barrel", 3.4, 1.1, cf * CFrame.new(0, 1.6, 0.5) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0.15), IRON)
	end
	function makers.hay(cf: CFrame)
		P(props, "Hay", Vector3.new(2.6, 1.4, 1.8), cf * CFrame.new(0, 0.7, 0), HAY)
		P(props, "Hay", Vector3.new(2.2, 1.2, 1.6), cf * CFrame.new(0.3, 2, 0.1) * CFrame.Angles(0, 0.3, 0), HAY)
	end
	function makers.tent(cf: CFrame)
		for _, side in {-1, 1} do
			P(props, "Tent", Vector3.new(3.8, 2.6, 1.9), cf * CFrame.new(0, 1.3, side * 0.95) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
				if side > 0 then accent.roof else accent.deep, "WedgePart")
		end
		P(props, "TentRidge", Vector3.new(4.2, 0.3, 0.3), cf * CFrame.new(0, 2.65, 0), GOLD)
	end
	-- Always: braziers flanking the entrance.
	for _, side in {-1, 1} do
		local at = Vector3.new(side * 4.6, 0, R + 1)
		ctx.claim(at, 1.6)
		makers.brazier(CFrame.new(at))
	end
	ctx.scatter(makers, {"crates", "crates", "barrels", "barrels", "rack", "dummy", "dummy", "hay", "cannon", "tent"},
		{crates = 2.2, barrels = 2, rack = 2, dummy = 1.5, hay = 1.8, cannon = 2.2, tent = 2.6}, rng:NextInteger(6, 9),
		function(kind, at)
			-- Cannons aim out of the entrance; everything else faces the courtyard.
			return if kind == "cannon" then CFrame.lookAt(at, at + Vector3.new(0, 0, 1)) else CFrame.lookAt(at, Vector3.zero) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
		end)

	return {
		{model = ground},
		{model = walls, dust = wallDust, dustScale = 1},
		{model = hero, dust = {frame * (base.Position + Vector3.new(-3, 0, 3)), frame * (base.Position + Vector3.new(3, 0, 3))}, dustScale = 1.3},
		{model = props},
	}
end

return Kit
