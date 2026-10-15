--!strict
-- Missions theme kit: Crystal Mine. A small loyalist dig site, camp-sized
-- (Common). The seed picks the hero piece (timber mine entrance in a rock mound,
-- giant crystal cluster, wooden headframe), a crystal colour, a rock tone and the
-- props. Crystals glow (Neon + light); MissionSite.Studify studs everything else.
local Airship = require(script.Parent.Parent.InvasionAirship)
local Common = require(script.Parent.Common)
local rgb = Common.rgb
local Kit = {}

local R, BACK = Common.R, Common.BACK
local DARK = Airship.DARK
local WOOD, DARKWOOD = Airship.WOOD, Airship.DARKWOOD
local IRON = rgb(80, 82, 92)
local RAIL = rgb(120, 120, 130)

local ROCKS = {
	{rock = rgb(128, 120, 140), dark = rgb(96, 90, 108), ground = rgb(150, 140, 150)},
	{rock = rgb(140, 118, 96), dark = rgb(106, 88, 72), ground = rgb(168, 144, 116)},
	{rock = rgb(112, 120, 128), dark = rgb(82, 88, 96), ground = rgb(140, 146, 150)},
}
local CRYSTALS = {
	{glow = rgb(190, 90, 255), base = rgb(140, 60, 210)}, -- amethyst (loyalist purple)
	{glow = rgb(90, 220, 255), base = rgb(50, 150, 210)}, -- ice
	{glow = rgb(90, 255, 150), base = rgb(40, 170, 100)}, -- emerald
}

function Kit.Build(frame: CFrame, rng: Random)
	local ctx = Common.new(frame, rng)
	local P, cyl, polar = ctx.P, ctx.cyl, Common.polar
	local rocks = ctx.pick(ROCKS)
	local crystal = ctx.pick(CRYSTALS)
	-- A pointed crystal: a tall block with a smaller cap, tilted; glows.
	local function shard(parent: Instance, cf: CFrame, height: number, light: boolean?)
		local w = height * 0.32
		local body = P(parent, "Crystal", Vector3.new(w, height, w), cf * CFrame.new(0, height / 2, 0), crystal.base)
		body.Material = Enum.Material.Glass
		body.Transparency = 0.15
		ctx.neon(P(parent, "CrystalCore", Vector3.new(w * 0.5, height * 0.8, w * 0.5), cf * CFrame.new(0, height * 0.45, 0), crystal.glow),
			if light then crystal.glow else nil, 12)
		local cap = P(parent, "CrystalTip", Vector3.new(w * 0.6, height * 0.25, w * 0.6), cf * CFrame.new(0, height + height * 0.12, 0), crystal.glow)
		cap.Material = Enum.Material.Neon
	end
	local function cluster(parent: Instance, cf: CFrame, scale: number, light: boolean?)
		P(parent, "ClusterRock", Vector3.new(2.6 * scale, 0.9 * scale, 2.2 * scale), cf * CFrame.new(0, 0.45 * scale, 0), rocks.dark)
		shard(parent, cf * CFrame.new(0, 0.6 * scale, 0), 3.2 * scale, light)
		shard(parent, cf * CFrame.new(0.8 * scale, 0.5 * scale, 0.3 * scale) * CFrame.Angles(0, 0, -0.35), 2 * scale)
		shard(parent, cf * CFrame.new(-0.8 * scale, 0.5 * scale, -0.2 * scale) * CFrame.Angles(0.2, 0, 0.4), 1.7 * scale)
	end
	local function boulder(parent: Instance, cf: CFrame, size: number)
		P(parent, "Rock", Vector3.new(size, size * 0.7, size * 0.85), cf * CFrame.new(0, size * 0.35, 0) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), rocks.rock)
		P(parent, "Rock", Vector3.new(size * 0.6, size * 0.5, size * 0.6), cf * CFrame.new(size * 0.25, size * 0.8, 0) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), rocks.dark)
	end

	------------------------------------------------------------------ Ground
	local ground = ctx.group("Ground")
	ctx.patch(ground, rocks.ground, 15.5)
	for _ = 1, 8 do
		local at = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(3, 12))
		local s = rng:NextNumber(1.6, 3)
		P(ground, "Gravel", Vector3.new(s, 0.42, s * rng:NextNumber(0.6, 1)), CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), rocks.dark)
	end
	ctx.clods(ground, {rocks.ground, rocks.dark}, 14.5, 16.5, 12)
	ctx.path(ground, rocks.ground)
	-- Mine-cart rails from the entrance to the hero piece.
	for _, x in {-1.1, 1.1} do P(ground, "Rail", Vector3.new(0.3, 0.5, 30), CFrame.new(x, 0.1, 1), RAIL) end
	for i = -6, 7 do P(ground, "Sleeper", Vector3.new(3.2, 0.4, 0.6), CFrame.new(0, 0, i * 2.1 + 1), DARKWOOD) end

	------------------------------------------------------------------ Perimeter
	local outcrops = ctx.group("Outcrops")
	local outcropDust = {}
	for _, range in {{-140, -24}, {24, 140}} do
		local from, to = math.rad(range[1]), math.rad(range[2])
		local count = 6
		for i = 0, count do
			local theta = from + (to - from) * i / count
			local at = polar(theta, R + rng:NextNumber(-0.5, 0.8))
			boulder(outcrops, CFrame.new(at), rng:NextNumber(2.6, 4))
			if i % 2 == 1 then
				-- Timber shoring between some rocks.
				local post = polar(theta + (to - from) / count / 2, R)
				P(outcrops, "Shoring", Vector3.new(0.7, 3.4, 0.7), CFrame.new(post + Vector3.new(0, 1.7, 0)), WOOD)
				table.insert(outcropDust, frame * at)
			end
		end
	end

	------------------------------------------------------------------ Hero piece
	local hero = ctx.group("Hero")
	local base = CFrame.new(0, 0, -BACK)
	local heroKind = rng:NextInteger(1, 3) -- 1 mine entrance, 2 crystal cluster, 3 headframe
	if heroKind == 1 then
		-- A stepped rock mound with a timber-framed tunnel mouth.
		for i, size in {Vector3.new(14, 4, 8), Vector3.new(11, 3.4, 6.6), Vector3.new(7, 2.6, 5)} do
			P(hero, "Mound", size, base * CFrame.new(0, (i - 1) * 3.2 + size.Y / 2, -(i - 1) * 0.6), if i % 2 == 0 then rocks.dark else rocks.rock)
		end
		P(hero, "Tunnel", Vector3.new(3.6, 4, 0.4), base * CFrame.new(0, 2, 4.05), DARK)
		for _, x in {-2.1, 2.1} do P(hero, "Beam", Vector3.new(0.8, 4.6, 0.8), base * CFrame.new(x, 2.3, 4.2), WOOD) end
		P(hero, "Lintel", Vector3.new(5.2, 0.9, 0.9), base * CFrame.new(0, 4.9, 4.2), DARKWOOD)
		cluster(hero, base * CFrame.new(4.6, 4, 2.2), 0.9, true)
		cluster(hero, base * CFrame.new(-4.2, 3.6, 2), 0.7)
		cluster(hero, base * CFrame.new(0.6, 9.6, -1.2), 1.1)
	elseif heroKind == 2 then
		-- One giant crystal cluster on a rock base.
		P(hero, "Base", Vector3.new(10, 1.6, 8), base * CFrame.new(0, 0.8, 0), rocks.dark)
		P(hero, "Base", Vector3.new(7, 1.4, 6), base * CFrame.new(0, 2.3, 0), rocks.rock)
		shard(hero, base * CFrame.new(0, 3, 0), 10, true)
		shard(hero, base * CFrame.new(2.6, 2.6, 0.8) * CFrame.Angles(0, 0, -0.35), 6.4)
		shard(hero, base * CFrame.new(-2.6, 2.6, -0.4) * CFrame.Angles(0.15, 0, 0.4), 5.6)
		shard(hero, base * CFrame.new(0.4, 2.6, 2.4) * CFrame.Angles(0.45, 0, 0), 4.2)
		boulder(hero, base * CFrame.new(-4.4, 0, 2.6), 2.6)
	else
		-- A wooden mine headframe with a big wheel over a shaft.
		P(hero, "ShaftRim", Vector3.new(7, 1, 7), base * CFrame.new(0, 0.5, 0), rocks.dark)
		P(hero, "Shaft", Vector3.new(4.4, 0.4, 4.4), base * CFrame.new(0, 1.05, 0), DARK)
		for _, x in {-1, 1} do
			for _, z in {-1, 1} do P(hero, "Leg", Vector3.new(0.8, 12, 0.8), base * CFrame.new(x * 2.6, 6.4, z * 2.6) * CFrame.Angles(z * 0.06, 0, x * -0.06), WOOD) end
		end
		for _, y in {4.5, 8.5} do
			for _, z in {-2.4, 2.4} do P(hero, "Brace", Vector3.new(5.6, 0.5, 0.5), base * CFrame.new(0, y, z), DARKWOOD) end
		end
		P(hero, "Deck", Vector3.new(6, 0.6, 6), base * CFrame.new(0, 12.2, 0), DARKWOOD)
		cyl(hero, "Wheel", 0.6, 5, base * CFrame.new(0, 14.6, 0) * CFrame.Angles(0, math.pi / 2, 0), IRON)
		cyl(hero, "Hub", 1, 1.2, base * CFrame.new(0, 14.6, 0) * CFrame.Angles(0, math.pi / 2, 0), DARKWOOD)
		P(hero, "Cable", Vector3.new(0.15, 11, 0.15), base * CFrame.new(0, 7, 2.4), DARK)
		cluster(hero, base * CFrame.new(4.8, 0, 1.6), 1, true)
		cluster(hero, base * CFrame.new(-4.6, 0, 1.2), 0.8)
	end

	------------------------------------------------------------------ Props
	local props = ctx.group("Props")
	local makers = {}
	function makers.cluster(cf: CFrame) cluster(props, cf, rng:NextNumber(0.7, 1), true) end
	function makers.cart(cf: CFrame)
		P(props, "CartBody", Vector3.new(2.4, 1.6, 3.2), cf * CFrame.new(0, 1.5, 0), IRON)
		P(props, "CartRim", Vector3.new(2.6, 0.4, 3.4), cf * CFrame.new(0, 2.4, 0), DARKWOOD)
		for _, x in {-1.1, 1.1} do
			for _, z in {-1, 1} do cyl(props, "Wheel", 0.4, 1, cf * CFrame.new(x, 0.55, z), DARK) end
		end
		P(props, "Ore", Vector3.new(1.8, 0.8, 2.4), cf * CFrame.new(0, 2.6, 0), rocks.dark)
		ctx.neon(P(props, "Gem", Vector3.new(0.7, 0.7, 0.7), cf * CFrame.new(0.4, 3.1, 0.3), crystal.glow))
	end
	function makers.ore(cf: CFrame)
		for i = 1, 4 do
			local s = rng:NextNumber(0.9, 1.5)
			P(props, "Ore", Vector3.new(s, s * 0.8, s), cf * CFrame.new(rng:NextNumber(-1, 1), s * 0.4, rng:NextNumber(-1, 1)) * CFrame.Angles(0, i, 0.3), rocks.rock)
		end
		ctx.neon(P(props, "OreGem", Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(0, 1.1, 0), crystal.glow))
	end
	function makers.lantern(cf: CFrame)
		P(props, "LanternPost", Vector3.new(0.45, 3.6, 0.45), cf * CFrame.new(0, 1.8, 0), DARKWOOD)
		ctx.neon(P(props, "Lantern", Vector3.new(0.7, 0.9, 0.7), cf * CFrame.new(0, 3.9, 0), rgb(255, 200, 90)), rgb(255, 200, 110), 9)
	end
	function makers.tools(cf: CFrame)
		for _, x in {-0.9, 0.9} do P(props, "RackPost", Vector3.new(0.4, 2.4, 0.4), cf * CFrame.new(x, 1.2, 0), DARKWOOD) end
		P(props, "RackBar", Vector3.new(2.4, 0.3, 0.4), cf * CFrame.new(0, 2.1, 0), WOOD)
		for i = -1, 1, 2 do
			P(props, "Handle", Vector3.new(0.25, 2.4, 0.25), cf * CFrame.new(i * 0.5, 1.4, 0.3), WOOD)
			P(props, "PickHead", Vector3.new(1.4, 0.3, 0.3), cf * CFrame.new(i * 0.5, 2.5, 0.3), IRON)
		end
	end
	function makers.boulder(cf: CFrame) boulder(props, cf, rng:NextNumber(1.8, 2.6)) end
	for _, side in {-1, 1} do
		local at = Vector3.new(side * 4.6, 0, R + 1)
		ctx.claim(at, 1.4)
		makers.lantern(CFrame.new(at))
	end
	ctx.scatter(makers, {"cluster", "cluster", "cluster", "cart", "ore", "ore", "tools", "lantern", "boulder"},
		{cluster = 1.8, cart = 2.2, ore = 1.6, tools = 1.4, lantern = 1.2, boulder = 1.8}, rng:NextInteger(7, 10))

	return {
		{model = ground},
		{model = outcrops, dust = outcropDust, dustScale = 1.1},
		{model = hero, dust = {frame * (base.Position + Vector3.new(-3, 0, 3)), frame * (base.Position + Vector3.new(3, 0, 3))}, dustScale = 1.4},
		{model = props},
	}
end

return Kit
