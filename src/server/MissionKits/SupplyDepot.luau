--!strict
-- Missions theme kit: Supply Depot. A small loyalist supply yard, camp-sized
-- (Common). The seed picks the hero piece (striped supply tent, wooden warehouse,
-- loading crane), the perimeter (post-and-rail fence or crate barricade), a wood
-- tone, a tarp colour and the props. MissionSite.Studify adds the stud texture.
local Airship = require(script.Parent.Parent.InvasionAirship)
local Common = require(script.Parent.Common)
local rgb = Common.rgb
local Kit = {}

local R, BACK = Common.R, Common.BACK
local GOLD, DARK = Airship.GOLD, Airship.DARK
local IRON = rgb(70, 70, 82)
local HAY = rgb(237, 194, 71)
local SACK = rgb(218, 193, 139)
local CANVAS = rgb(238, 228, 204)
local DIRT = rgb(184, 136, 84)
local PACKED = rgb(160, 120, 80)

local WOODS = {
	{wood = rgb(170, 105, 55), dark = rgb(112, 66, 34), plank = rgb(196, 140, 84)},
	{wood = rgb(150, 92, 48), dark = rgb(96, 56, 30), plank = rgb(176, 120, 70)},
	{wood = rgb(186, 136, 90), dark = rgb(128, 86, 52), plank = rgb(214, 168, 116)},
}
local TARPS = {Airship.PURPLE, Airship.PURPLE, rgb(46, 120, 84), rgb(40, 84, 150)}

function Kit.Build(frame: CFrame, rng: Random)
	local ctx = Common.new(frame, rng)
	local P, cyl, polar = ctx.P, ctx.cyl, Common.polar
	local wood = ctx.pick(WOODS)
	local tarp = ctx.pick(TARPS)

	------------------------------------------------------------------ Ground
	local ground = ctx.group("Ground")
	ctx.patch(ground, PACKED, 15.5)
	-- Plank floor patches and cart ruts.
	for _ = 1, 4 do
		local at = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(4, 11))
		local cf = CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		for i = -1, 1 do P(ground, "Plank", Vector3.new(1.1, 0.42, 4.2), cf * CFrame.new(i * 1.2, 0, 0), wood.plank) end
	end
	for _, x in {-1.6, 1.6} do P(ground, "Rut", Vector3.new(0.7, 0.4, 24), CFrame.new(x, 0, 2), DIRT) end
	ctx.clods(ground, {PACKED, DIRT}, 14.5, 16.5, 12)
	ctx.path(ground, DIRT)

	------------------------------------------------------------------ Perimeter
	local fence = ctx.group("Fence")
	local fenceDust = {}
	local barricade = rng:NextNumber() < 0.5
	local function post(at: Vector3)
		P(fence, "Post", Vector3.new(0.9, 3.4, 0.9), CFrame.new(at + Vector3.new(0, 1.7, 0)), wood.dark)
		P(fence, "PostCap", Vector3.new(1.1, 0.4, 1.1), CFrame.new(at + Vector3.new(0, 3.5, 0)), wood.wood)
	end
	local function rails(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		for _, y in {1.2, 2.5} do P(fence, "Rail", Vector3.new(0.5, 0.55, length), cf * CFrame.new(0, y, 0), wood.wood) end
	end
	local function crateWall(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		local count = math.max(1, math.floor(length / 2.3))
		for i = 1, count do
			local z = -length / 2 + (i - 0.5) * length / count
			local c = cf * CFrame.new(0, 1.05, z) * CFrame.Angles(0, rng:NextNumber(-0.15, 0.15), 0)
			P(fence, "Crate", Vector3.new(2.1, 2.1, 2.1), c, wood.wood)
			P(fence, "CrateBand", Vector3.new(2.25, 0.35, 2.25), c, tarp)
			if i % 2 == 1 then P(fence, "Crate", Vector3.new(1.8, 1.8, 1.8), cf * CFrame.new(0, 3, z) * CFrame.Angles(0, 0.3, 0), wood.plank) end
		end
	end
	for _, range in {{-140, -22}, {22, 140}} do
		local from, to = math.rad(range[1]), math.rad(range[2])
		local segments = math.max(2, math.floor((to - from) / math.rad(22) + 0.5))
		local previous = polar(from, R)
		if not barricade then post(previous) end
		for i = 1, segments do
			local point = polar(from + (to - from) * i / segments, R)
			if barricade then crateWall(previous, point) else rails(previous, point); post(point) end
			if i % 2 == 0 then table.insert(fenceDust, frame * point) end
			previous = point
		end
	end
	-- Gate posts with a hanging supply sign.
	for _, side in {-1, 1} do
		local at = polar(side * math.rad(140), R)
		P(fence, "GatePost", Vector3.new(1.2, 5, 1.2), CFrame.new(at + Vector3.new(0, 2.5, 0)), wood.dark)
	end
	local left, right = polar(math.rad(140), R), polar(math.rad(-140), R)
	local beam = CFrame.lookAt((left + right) / 2 + Vector3.new(0, 5, 0), right + Vector3.new(0, 5, 0))
	P(fence, "GateBeam", Vector3.new(0.8, 0.8, (right - left).Magnitude + 1), beam, wood.wood)
	P(fence, "Sign", Vector3.new(4.4, 1.6, 0.3), CFrame.new((left + right) / 2 + Vector3.new(0, 3.9, 0.3)), wood.plank)
	P(fence, "SignMark", Vector3.new(1.2, 1.2, 0.35), CFrame.new((left + right) / 2 + Vector3.new(0, 3.9, 0.35)), tarp)

	------------------------------------------------------------------ Hero piece
	local hero = ctx.group("Hero")
	local base = CFrame.new(0, 0, -BACK)
	local heroKind = rng:NextInteger(1, 3) -- 1 supply tent, 2 warehouse, 3 crane
	if heroKind == 1 then
		-- A big striped A-frame tent, open at the front, crates inside.
		for i = -2, 2 do
			local stripe = if i % 2 == 0 then tarp else CANVAS
			for _, side in {-1, 1} do
				P(hero, "Canvas", Vector3.new(2, 5, 3.8), base * CFrame.new(i * 2, 2.5, side * 1.9) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0), stripe, "WedgePart")
			end
		end
		P(hero, "Ridge", Vector3.new(10.6, 0.5, 0.5), base * CFrame.new(0, 5.1, 0), wood.dark)
		for _, x in {-5.3, 5.3} do P(hero, "Pole", Vector3.new(0.5, 6.2, 0.5), base * CFrame.new(x, 3.1, 0), wood.dark) end
		P(hero, "Pennant", Vector3.new(1.6, 1, 0.2), base * CFrame.new(-4.5, 6.4, 0), GOLD)
		for _, x in {-2.2, 0.4, 2.6} do P(hero, "Crate", Vector3.new(1.8, 1.8, 1.8), base * CFrame.new(x, 0.9, 1.6) * CFrame.Angles(0, x * 0.2, 0), wood.wood) end
	elseif heroKind == 2 then
		-- A wooden warehouse with a sloped plank roof and a big open door.
		P(hero, "Floor", Vector3.new(11, 0.6, 7), base * CFrame.new(0, 0.3, 0), wood.dark)
		for _, x in {-5.2, 5.2} do P(hero, "SideWall", Vector3.new(0.6, 5, 6.6), base * CFrame.new(x, 3.1, 0), wood.wood) end
		P(hero, "BackWall", Vector3.new(11, 5, 0.6), base * CFrame.new(0, 3.1, -3.2), wood.wood)
		for _, x in {-3.6, 3.6} do P(hero, "FrontWall", Vector3.new(3.4, 5, 0.6), base * CFrame.new(x, 3.1, 3.2), wood.wood) end
		P(hero, "DoorBeam", Vector3.new(4, 1, 0.6), base * CFrame.new(0, 5.1, 3.2), wood.dark)
		for _, side in {-1, 1} do
			P(hero, "Roof", Vector3.new(12, 2.4, 4), base * CFrame.new(0, 6.8, side * 1.9) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0), tarp, "WedgePart")
		end
		for _, x in {-5.2, 5.2} do P(hero, "Brace", Vector3.new(0.5, 0.5, 6.8), base * CFrame.new(x, 2, 0) * CFrame.Angles(0.6, 0, 0), wood.dark) end
		P(hero, "Lantern", Vector3.new(0.7, 0.9, 0.7), base * CFrame.new(2.4, 4.3, 3.7), GOLD)
		for _, x in {-1, 1} do P(hero, "Crate", Vector3.new(1.8, 1.8, 1.8), base * CFrame.new(x, 1.5, 1), wood.plank) end
	else
		-- A loading crane on a platform, a crate hanging from the jib.
		P(hero, "Platform", Vector3.new(8, 1.2, 7), base * CFrame.new(0, 0.6, 0), wood.dark)
		for _, x in {-1, 1} do P(hero, "Leg", Vector3.new(0.8, 10, 0.8), base * CFrame.new(x * 1.6, 6, -1.5) * CFrame.Angles(0, 0, x * -0.12), wood.wood) end
		P(hero, "Cross", Vector3.new(3.6, 0.6, 0.6), base * CFrame.new(0, 7, -1.5), wood.dark)
		P(hero, "Jib", Vector3.new(0.7, 0.7, 9), base * CFrame.new(0, 10.6, 1.4) * CFrame.Angles(-0.12, 0, 0), wood.wood)
		P(hero, "Counterweight", Vector3.new(2, 2, 2), base * CFrame.new(0, 10.4, -3.6), IRON)
		P(hero, "Rope", Vector3.new(0.15, 4.6, 0.15), base * CFrame.new(0, 8.4, 5.4), DARK)
		local c = base * CFrame.new(0, 5.4, 5.4) * CFrame.Angles(0, 0.4, 0)
		P(hero, "HangingCrate", Vector3.new(2.2, 2.2, 2.2), c, wood.plank)
		P(hero, "HangingBand", Vector3.new(2.35, 0.35, 2.35), c, tarp)
		cyl(hero, "Winch", 2.4, 1.4, base * CFrame.new(0, 2, -1.5), wood.dark)
		for _, x in {-2.6, 2.6} do P(hero, "Crate", Vector3.new(2, 2, 2), base * CFrame.new(x, 2.2, 1.6), wood.wood) end
	end
	P(hero, "Flag", Vector3.new(2.6, 1.6, 0.2), base * CFrame.new(1.4, 12.6, -3), tarp)
	P(hero, "FlagPole", Vector3.new(0.3, 5, 0.3), base * CFrame.new(0, 10.9, -3), wood.dark)

	------------------------------------------------------------------ Props
	local props = ctx.group("Props")
	local makers = {}
	function makers.crates(cf: CFrame)
		for i, at in {Vector3.new(-1.1, 1, 0), Vector3.new(1.1, 1, 0.2), Vector3.new(0, 3, 0.1)} do
			local c = cf * CFrame.new(at) * CFrame.Angles(0, (i - 2) * 0.25, 0)
			P(props, "Crate", Vector3.new(2, 2, 2), c, if i == 3 then wood.plank else wood.wood)
			P(props, "CrateBand", Vector3.new(2.15, 0.35, 2.15), c, tarp)
		end
	end
	function makers.barrels(cf: CFrame)
		for i, at in {Vector3.new(-0.95, 0, 0), Vector3.new(0.95, 0, 0), Vector3.new(0, 0, -1.5)} do
			if i == 3 and rng:NextNumber() < 0.5 then continue end
			cyl(props, "Barrel", 2, 1.7, cf * CFrame.new(at + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), wood.dark)
			cyl(props, "Hoop", 0.3, 1.85, cf * CFrame.new(at + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), IRON)
		end
	end
	function makers.sacks(cf: CFrame)
		for i, at in {Vector3.new(-0.8, 0.5, 0), Vector3.new(0.8, 0.5, 0.1), Vector3.new(0, 1.4, 0)} do
			P(props, "Sack", Vector3.new(1.6, 1, 1.1), cf * CFrame.new(at) * CFrame.Angles(0, i * 0.4, 0), SACK)
		end
	end
	function makers.cart(cf: CFrame)
		P(props, "CartBed", Vector3.new(2.6, 0.5, 4), cf * CFrame.new(0, 1.4, 0), wood.wood)
		for _, x in {-1.2, 1.2} do P(props, "CartSide", Vector3.new(0.3, 1, 4), cf * CFrame.new(x, 2.1, 0), wood.dark) end
		for _, x in {-1.5, 1.5} do cyl(props, "Wheel", 0.4, 2.2, cf * CFrame.new(x, 1.1, 0.3), wood.dark) end
		P(props, "Handle", Vector3.new(0.3, 0.3, 2.6), cf * CFrame.new(0, 1.2, -3), wood.dark)
		P(props, "Load", Vector3.new(2, 1, 3), cf * CFrame.new(0, 2.1, 0), SACK)
	end
	function makers.lantern(cf: CFrame)
		P(props, "LanternPost", Vector3.new(0.45, 4, 0.45), cf * CFrame.new(0, 2, 0), wood.dark)
		P(props, "LanternArm", Vector3.new(1.4, 0.3, 0.3), cf * CFrame.new(0.55, 3.9, 0), wood.dark)
		ctx.neon(P(props, "Lantern", Vector3.new(0.7, 0.9, 0.7), cf * CFrame.new(1.1, 3.4, 0), rgb(255, 200, 90)), rgb(255, 200, 110), 9)
	end
	function makers.hay(cf: CFrame)
		P(props, "Hay", Vector3.new(2.6, 1.4, 1.8), cf * CFrame.new(0, 0.7, 0), HAY)
		P(props, "Hay", Vector3.new(2.2, 1.2, 1.6), cf * CFrame.new(0.3, 2, 0.1) * CFrame.Angles(0, 0.3, 0), HAY)
	end
	for _, side in {-1, 1} do
		local at = Vector3.new(side * 4.6, 0, R + 1)
		ctx.claim(at, 1.4)
		makers.lantern(CFrame.lookAt(at, at + Vector3.new(-side, 0, 0)))
	end
	ctx.scatter(makers, {"crates", "crates", "crates", "barrels", "barrels", "sacks", "sacks", "cart", "hay", "lantern"},
		{crates = 2.2, barrels = 2.2, sacks = 1.6, cart = 2.8, hay = 1.8, lantern = 1.2}, rng:NextInteger(7, 10))

	return {
		{model = ground},
		{model = fence, dust = fenceDust, dustScale = 1},
		{model = hero, dust = {frame * (base.Position + Vector3.new(-3, 0, 3)), frame * (base.Position + Vector3.new(3, 0, 3))}, dustScale = 1.3},
		{model = props},
	}
end

return Kit
