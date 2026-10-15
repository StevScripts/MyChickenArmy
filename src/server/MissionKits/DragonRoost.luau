--!strict
-- Missions theme kit: Dragon Roost. Scorched ground with glowing lava cracks,
-- camp-sized (Common). The seed picks the hero piece (giant twig nest with eggs,
-- bone arch with a skull, volcanic spire), an egg colour and the props: bones,
-- skulls, eggs, burnt trees, lava pools. MissionSite.Studify adds the studs.
local Common = require(script.Parent.Common)
local rgb = Common.rgb
local Kit = {}

local R, BACK = Common.R, Common.BACK
local ASH = rgb(92, 84, 82)
local SCORCH = rgb(64, 58, 58)
local ROCK = rgb(78, 70, 74)
local ROCKDARK = rgb(54, 48, 52)
local BONE = rgb(236, 228, 210)
local TWIG = rgb(120, 82, 50)
local TWIGDARK = rgb(88, 58, 34)
local CHAR = rgb(48, 40, 36)
local LAVA = rgb(255, 110, 30)
local GLOW = rgb(255, 140, 50)

local EGGS = {
	{rgb(220, 60, 60), rgb(255, 196, 64)},
	{rgb(150, 70, 220), rgb(255, 196, 64)},
	{rgb(60, 170, 120), rgb(230, 230, 120)},
}

function Kit.Build(frame: CFrame, rng: Random)
	local ctx = Common.new(frame, rng)
	local P, polar = ctx.P, Common.polar
	local eggColors = ctx.pick(EGGS)
	local function egg(parent: Instance, cf: CFrame, size: number)
		local body = ctx.ball(parent, "Egg", size, cf * CFrame.new(0, size * 0.5, 0), eggColors[1])
		body.Size = Vector3.new(size * 0.85, size * 1.1, size * 0.85)
		P(parent, "EggSpot", Vector3.new(size * 0.3, size * 0.3, 0.2), cf * CFrame.new(0, size * 0.65, size * 0.42), eggColors[2])
	end
	local function spike(parent: Instance, cf: CFrame, height: number)
		P(parent, "Spike", Vector3.new(height * 0.45, height * 0.6, height * 0.45), cf * CFrame.new(0, height * 0.3, 0), ROCK)
		P(parent, "SpikeMid", Vector3.new(height * 0.3, height * 0.4, height * 0.3), cf * CFrame.new(0, height * 0.75, 0) * CFrame.Angles(0, 0.4, 0.08), ROCKDARK)
		P(parent, "SpikeTip", Vector3.new(height * 0.15, height * 0.25, height * 0.15), cf * CFrame.new(0, height * 1.05, 0) * CFrame.Angles(0, 0.8, 0.12), ROCK)
	end
	local function lava(parent: Instance, cf: CFrame, w: number, l: number)
		ctx.neon(P(parent, "Lava", Vector3.new(w, 0.45, l), cf, LAVA), GLOW, 8)
	end

	------------------------------------------------------------------ Ground
	local ground = ctx.group("Ground")
	ctx.patch(ground, ASH, 15.5)
	for _ = 1, 8 do
		local at = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(3, 12.5))
		local s = rng:NextNumber(2, 3.4)
		P(ground, "Scorch", Vector3.new(s, 0.42, s * rng:NextNumber(0.6, 1)), CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), SCORCH)
	end
	-- Glowing cracks running through the clearing (none crosses the entrance lane).
	for _ = 1, 5 do
		local theta = rng:NextNumber(math.rad(-130), math.rad(130))
		local at = polar(theta, rng:NextNumber(5, 12))
		lava(ground, CFrame.new(at + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, theta + rng:NextNumber(-0.6, 0.6), 0), 0.5, rng:NextNumber(3, 6))
	end
	ctx.clods(ground, {ASH, SCORCH}, 14.5, 16.5, 12)
	ctx.path(ground, SCORCH)

	------------------------------------------------------------------ Perimeter
	local edge = ctx.group("Edge")
	local edgeDust = {}
	for _, range in {{-140, -24}, {24, 140}} do
		local from, to = math.rad(range[1]), math.rad(range[2])
		for i = 0, 6 do
			local theta = from + (to - from) * i / 6
			local at = polar(theta, R + rng:NextNumber(-0.4, 0.6))
			if i % 3 == 1 then
				-- A rib bone curving up out of the ground.
				for k = 0, 2 do
					P(edge, "Rib", Vector3.new(0.8, 2.2, 0.8), CFrame.new(at) * CFrame.Angles(0, theta, 0) * CFrame.new(0, 1 + k * 1.9, k * 0.55) * CFrame.Angles(0.3 * k, 0, 0), BONE)
				end
			else
				spike(edge, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, 1), rng:NextNumber(-0.1, 0.1)), rng:NextNumber(3.6, 5.4))
			end
			if i % 2 == 0 then table.insert(edgeDust, frame * at) end
		end
	end

	------------------------------------------------------------------ Hero piece
	local hero = ctx.group("Hero")
	local base = CFrame.new(0, 0, -BACK)
	local heroKind = rng:NextInteger(1, 3) -- 1 nest, 2 bone arch, 3 volcanic spire
	if heroKind == 1 then
		-- A raised ring of twigs with three big eggs inside.
		P(hero, "Mound", Vector3.new(10, 1.6, 9), base * CFrame.new(0, 0.8, 0), ROCKDARK)
		for k = 0, 11 do
			local yaw = k / 12 * math.pi * 2
			P(hero, "Twig", Vector3.new(4, 1, 1), base * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 2.1 + (k % 2) * 0.6, 3.6) * CFrame.Angles(0, 0, (k % 3 - 1) * 0.2),
				if k % 2 == 0 then TWIG else TWIGDARK)
		end
		egg(hero, base * CFrame.new(-1.3, 1.6, 0.2), 2.6)
		egg(hero, base * CFrame.new(1.3, 1.6, -0.3), 2.3)
		egg(hero, base * CFrame.new(0, 1.6, 1.5), 2)
		spike(hero, base * CFrame.new(-4.8, 0, -2.4), 6)
		spike(hero, base * CFrame.new(4.6, 0, -2), 5)
	elseif heroKind == 2 then
		-- A huge bone arch (ribcage) with a blocky dragon skull at its top.
		for _, x in {-1, 1} do
			for k = 0, 3 do
				P(hero, "Bone", Vector3.new(1.3, 3.2, 1.3), base * CFrame.new(x * (4.6 - k * 0.9), 1.6 + k * 2.6, 0) * CFrame.Angles(0, 0, x * k * 0.28), BONE)
			end
		end
		P(hero, "Skull", Vector3.new(4.2, 2.8, 4), base * CFrame.new(0, 11.4, 0.4), BONE)
		P(hero, "Snout", Vector3.new(2.8, 1.6, 2.6), base * CFrame.new(0, 10.8, 2.8), BONE)
		for _, x in {-1, 1} do
			ctx.neon(P(hero, "Eye", Vector3.new(0.8, 0.6, 0.3), base * CFrame.new(x * 1.1, 11.8, 2.45), LAVA), GLOW, 8)
			P(hero, "Horn", Vector3.new(0.7, 2.6, 0.7), base * CFrame.new(x * 1.6, 13.6, -0.4) * CFrame.Angles(-0.4, 0, x * 0.3), BONE)
		end
		P(hero, "Base", Vector3.new(12, 1, 6), base * CFrame.new(0, 0.5, 0), ROCKDARK)
		lava(hero, base * CFrame.new(0, 1.05, 0.6), 4, 2.4)
	else
		-- A volcanic spire with lava running down its front.
		for i, size in {Vector3.new(11, 4, 8), Vector3.new(8, 4, 6), Vector3.new(5.4, 4, 4.2), Vector3.new(3.2, 3.6, 2.8)} do
			P(hero, "Spire", size, base * CFrame.new(0, (i - 1) * 3.8 + size.Y / 2, -(i - 1) * 0.3) * CFrame.Angles(0, (i - 1) * 0.15, 0), if i % 2 == 0 then ROCKDARK else ROCK)
		end
		local crater = ctx.neon(P(hero, "Crater", Vector3.new(2.2, 0.5, 2), base * CFrame.new(0, 15.2, -0.9), LAVA), GLOW, 12)
		ctx.fire(crater, 4, LAVA, rgb(255, 220, 120))
		for i = 0, 3 do lava(hero, base * CFrame.new(0, 2 + i * 3.6, 4 - i * 1.2) * CFrame.Angles(-0.25, 0, 0), 0.8, 3) end
		lava(hero, base * CFrame.new(0, 0.1, 5.4), 3, 2)
	end

	------------------------------------------------------------------ Props
	local props = ctx.group("Props")
	local makers = {}
	function makers.bones(cf: CFrame)
		for k = 0, 2 do P(props, "Bone", Vector3.new(0.5, 0.5, 2.2), cf * CFrame.new(rng:NextNumber(-0.8, 0.8), 0.3 + k * 0.3, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), BONE) end
	end
	function makers.skull(cf: CFrame)
		P(props, "Skull", Vector3.new(1.6, 1.2, 1.6), cf * CFrame.new(0, 0.6, 0), BONE)
		P(props, "Jaw", Vector3.new(1.2, 0.5, 1), cf * CFrame.new(0, 0.2, 0.6), BONE)
		for _, x in {-0.4, 0.4} do P(props, "Socket", Vector3.new(0.4, 0.35, 0.2), cf * CFrame.new(x, 0.75, 0.82), CHAR) end
	end
	function makers.eggs(cf: CFrame)
		P(props, "Twigs", Vector3.new(2.6, 0.5, 2.6), cf * CFrame.new(0, 0.25, 0), TWIG)
		egg(props, cf * CFrame.new(-0.5, 0.4, 0), 1.3)
		egg(props, cf * CFrame.new(0.6, 0.4, 0.3), 1.1)
	end
	function makers.tree(cf: CFrame)
		P(props, "BurntTrunk", Vector3.new(0.9, 4.6, 0.9), cf * CFrame.new(0, 2.3, 0) * CFrame.Angles(0, 0, 0.1), CHAR)
		P(props, "BurntBranch", Vector3.new(2.4, 0.5, 0.5), cf * CFrame.new(0.6, 3.6, 0) * CFrame.Angles(0, 0, 0.5), CHAR)
		P(props, "BurntBranch", Vector3.new(0.5, 0.5, 2), cf * CFrame.new(-0.2, 2.8, 0.6) * CFrame.Angles(0.5, 0, 0), CHAR)
	end
	function makers.pool(cf: CFrame)
		P(props, "PoolRim", Vector3.new(3.4, 0.5, 2.8), cf * CFrame.new(0, 0.25, 0), ROCKDARK)
		lava(props, cf * CFrame.new(0, 0.35, 0), 2.6, 2)
	end
	function makers.spike(cf: CFrame) spike(props, cf, rng:NextNumber(2.4, 3.4)) end
	for _, side in {-1, 1} do
		local at = Vector3.new(side * 4.6, 0, R + 1)
		ctx.claim(at, 1.6)
		makers.skull(CFrame.lookAt(at, at + Vector3.new(0, 0, 1)))
	end
	ctx.scatter(makers, {"bones", "bones", "skull", "eggs", "tree", "tree", "pool", "spike"},
		{bones = 1.4, skull = 1.2, eggs = 1.6, tree = 1.4, pool = 2, spike = 1.6}, rng:NextInteger(7, 10))

	return {
		{model = ground},
		{model = edge, dust = edgeDust, dustScale = 1.1},
		{model = hero, dust = {frame * (base.Position + Vector3.new(-3, 0, 3)), frame * (base.Position + Vector3.new(3, 0, 3))}, dustScale = 1.4},
		{model = props},
	}
end

return Kit
