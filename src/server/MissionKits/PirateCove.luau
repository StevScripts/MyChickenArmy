--!strict
-- Missions theme kit: Pirate Cove (spawns near the island's edge when it can).
-- Camp-sized (Common). The seed picks the hero piece (wrecked ship, hut on
-- stilts, rock arch over a treasure chest), sail colours and the props: palms,
-- barrels, a cannon, chests, rope, an anchor. MissionSite.Studify adds the studs.
local Airship = require(script.Parent.Parent.InvasionAirship)
local Common = require(script.Parent.Common)
local rgb = Common.rgb
local Kit = {}

local R, BACK = Common.R, Common.BACK
local GOLD, DARK = Airship.GOLD, Airship.DARK
local IRON = rgb(70, 70, 82)
local SAND = rgb(236, 214, 160)
local WETSAND = rgb(214, 188, 132)
local PALM = rgb(98, 176, 66)
local PALMDARK = rgb(70, 140, 50)
local TRUNK = rgb(160, 112, 66)
local ROCK = rgb(150, 146, 160)
local ROPE = rgb(214, 186, 128)
local THATCH = rgb(214, 176, 92)

local HULLS = {
	{wood = rgb(140, 86, 46), dark = rgb(92, 54, 28), trim = GOLD},
	{wood = rgb(110, 76, 52), dark = rgb(70, 46, 30), trim = rgb(220, 220, 220)},
	{wood = rgb(160, 104, 60), dark = rgb(104, 64, 34), trim = GOLD},
}
local SAILS = {
	{sail = rgb(245, 240, 228), stripe = rgb(200, 40, 50)},
	{sail = rgb(245, 240, 228), stripe = Airship.PURPLE},
	{sail = rgb(40, 40, 48), stripe = rgb(245, 240, 228)},
}

function Kit.Build(frame: CFrame, rng: Random)
	local ctx = Common.new(frame, rng)
	local P, cyl, polar = ctx.P, ctx.cyl, Common.polar
	local hull = ctx.pick(HULLS)
	local sails = ctx.pick(SAILS)
	local function palm(parent: Instance, cf: CFrame, height: number)
		local lean = rng:NextNumber(-0.18, 0.18)
		local top = cf * CFrame.Angles(0, 0, lean) * CFrame.new(0, height, 0)
		for i = 0, 3 do
			P(parent, "Trunk", Vector3.new(0.9 - i * 0.08, height / 4 + 0.1, 0.9 - i * 0.08), cf * CFrame.Angles(0, 0, lean) * CFrame.new(0, height / 8 + i * height / 4, 0), if i % 2 == 0 then TRUNK else hull.dark)
		end
		for k = 0, 4 do
			local yaw = k / 5 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			P(parent, "Frond", Vector3.new(1.4, 0.35, 4), top * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, 1.8) * CFrame.Angles(-0.35, 0, 0), if k % 2 == 0 then PALM else PALMDARK)
		end
		P(parent, "Coconut", Vector3.new(0.7, 0.7, 0.7), top * CFrame.new(0.4, -0.5, 0), hull.dark)
	end
	local function chest(parent: Instance, cf: CFrame)
		P(parent, "Chest", Vector3.new(2.4, 1.4, 1.6), cf * CFrame.new(0, 0.7, 0), hull.wood)
		P(parent, "ChestLid", Vector3.new(2.5, 0.5, 1.7), cf * CFrame.new(0, 1.65, -0.5) * CFrame.Angles(-0.7, 0, 0), hull.dark)
		P(parent, "ChestBand", Vector3.new(0.35, 1.5, 1.7), cf * CFrame.new(-0.7, 0.75, 0), GOLD)
		P(parent, "ChestBand", Vector3.new(0.35, 1.5, 1.7), cf * CFrame.new(0.7, 0.75, 0), GOLD)
		local coins = P(parent, "Gold", Vector3.new(2, 0.5, 1.2), cf * CFrame.new(0, 1.5, 0), GOLD)
		coins.Material = Enum.Material.Neon
	end

	------------------------------------------------------------------ Ground
	local ground = ctx.group("Ground")
	ctx.patch(ground, SAND, 15.5)
	for _ = 1, 7 do
		local at = polar(rng:NextNumber(0, math.pi * 2), rng:NextNumber(3, 12))
		local s = rng:NextNumber(1.8, 3.2)
		P(ground, "WetSand", Vector3.new(s, 0.42, s * rng:NextNumber(0.6, 1)), CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), WETSAND)
	end
	ctx.clods(ground, {SAND, WETSAND}, 14.5, 16.5, 12)
	-- A boardwalk instead of a dirt path.
	for i = 0, 5 do P(ground, "Board", Vector3.new(5, 0.45, 1), CFrame.new(0, 0.05, R - 1 + i * 1.25) * CFrame.Angles(0, rng:NextNumber(-0.05, 0.05), 0), hull.wood) end

	------------------------------------------------------------------ Perimeter
	local edge = ctx.group("Edge")
	local edgeDust = {}
	for _, range in {{-140, -26}, {26, 140}} do
		local from, to = math.rad(range[1]), math.rad(range[2])
		for i = 0, 5 do
			local theta = from + (to - from) * i / 5
			local at = polar(theta, R + rng:NextNumber(-0.5, 0.6))
			if i % 2 == 0 then
				palm(edge, CFrame.new(at), rng:NextNumber(6.5, 9))
			else
				-- Driftwood fence and rocks between the palms.
				local s = rng:NextNumber(2.2, 3.2)
				P(edge, "Rock", Vector3.new(s, s * 0.7, s * 0.9), CFrame.new(at + Vector3.new(0, s * 0.35, 0)) * CFrame.Angles(0, theta, 0.1), ROCK)
				for k = -1, 1 do
					P(edge, "Driftwood", Vector3.new(0.6, rng:NextNumber(2, 3), 0.6), CFrame.new(polar(theta + k * 0.07, R + 1.6) + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, k * 0.15), hull.dark)
				end
				table.insert(edgeDust, frame * at)
			end
		end
	end

	------------------------------------------------------------------ Hero piece
	local hero = ctx.group("Hero")
	local base = CFrame.new(0, 0, -BACK)
	local heroKind = rng:NextInteger(1, 3) -- 1 wrecked ship, 2 hut on stilts, 3 rock arch + treasure
	if heroKind == 1 then
		-- A blocky hull beached at an angle, one mast with a torn striped sail.
		local ship = base * CFrame.Angles(0, 0, 0.12)
		P(hero, "Keel", Vector3.new(12, 1, 3), ship * CFrame.new(0, 0.5, 0), hull.dark)
		P(hero, "Hull", Vector3.new(13, 2.6, 5), ship * CFrame.new(0, 2.3, 0), hull.wood)
		P(hero, "Deck", Vector3.new(12.6, 0.5, 4.6), ship * CFrame.new(0, 3.85, 0), hull.dark)
		P(hero, "Rail", Vector3.new(13, 0.5, 0.5), ship * CFrame.new(0, 4.3, 2.3), hull.trim)
		P(hero, "Bow", Vector3.new(2.6, 2.6, 5), ship * CFrame.new(7.6, 2.8, 0) * CFrame.Angles(0, math.pi / 2, 0), hull.wood, "WedgePart")
		P(hero, "Cabin", Vector3.new(3.4, 2.4, 4), ship * CFrame.new(-4.6, 5.3, 0), hull.wood)
		P(hero, "CabinRoof", Vector3.new(3.8, 0.5, 4.4), ship * CFrame.new(-4.6, 6.75, 0), hull.dark)
		P(hero, "Hole", Vector3.new(2.2, 1.6, 0.3), ship * CFrame.new(1.6, 2.2, 2.55), DARK)
		P(hero, "Mast", Vector3.new(0.7, 11, 0.7), ship * CFrame.new(1, 9.6, 0), hull.dark)
		P(hero, "Yard", Vector3.new(0.5, 0.5, 6), ship * CFrame.new(1, 13.4, 0), hull.dark)
		P(hero, "Sail", Vector3.new(0.25, 5, 5.4), ship * CFrame.new(1.25, 10.7, 0), sails.sail)
		P(hero, "SailStripe", Vector3.new(0.3, 1.1, 5.4), ship * CFrame.new(1.3, 10.7, 0), sails.stripe)
		P(hero, "Flag", Vector3.new(0.2, 1.4, 2.2), ship * CFrame.new(1, 15.6, 1.1), DARK)
	elseif heroKind == 2 then
		-- A hut on stilts with a thatched roof, a ladder and a skull flag.
		for _, x in {-2.8, 2.8} do
			for _, z in {-2.2, 2.2} do P(hero, "Stilt", Vector3.new(0.7, 4.2, 0.7), base * CFrame.new(x, 2.1, z), hull.dark) end
		end
		P(hero, "Floor", Vector3.new(7.4, 0.6, 5.8), base * CFrame.new(0, 4.4, 0), hull.wood)
		P(hero, "Walls", Vector3.new(6.2, 3.4, 4.6), base * CFrame.new(0, 6.4, 0), TRUNK)
		P(hero, "Door", Vector3.new(1.6, 2.4, 0.3), base * CFrame.new(0, 5.9, 2.35), DARK)
		for _, side in {-1, 1} do
			P(hero, "Thatch", Vector3.new(8, 2.6, 3.4), base * CFrame.new(0, 9.4, side * 1.7) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0), THATCH, "WedgePart")
		end
		for i = 0, 3 do P(hero, "Rung", Vector3.new(1.8, 0.3, 0.3), base * CFrame.new(0, 0.8 + i * 1, 3.4), hull.dark) end
		for _, x in {-0.9, 0.9} do P(hero, "LadderSide", Vector3.new(0.3, 4.4, 0.3), base * CFrame.new(x, 2.2, 3.4), hull.dark) end
		P(hero, "FlagPole", Vector3.new(0.3, 4.4, 0.3), base * CFrame.new(3.2, 12.4, 0), hull.dark)
		P(hero, "Flag", Vector3.new(2.6, 1.6, 0.2), base * CFrame.new(4.6, 13.8, 0), DARK)
		P(hero, "Skull", Vector3.new(0.7, 0.7, 0.25), base * CFrame.new(4.6, 13.9, 0.05), rgb(240, 236, 226))
	else
		-- A rock arch over a treasure chest.
		for _, x in {-4, 4} do
			P(hero, "Pillar", Vector3.new(3.4, 7, 4), base * CFrame.new(x, 3.5, 0) * CFrame.Angles(0, 0, x * -0.02), ROCK)
			P(hero, "PillarTop", Vector3.new(2.6, 1.6, 3.2), base * CFrame.new(x * 0.9, 7.6, 0), rgb(128, 124, 140))
		end
		P(hero, "Arch", Vector3.new(10, 2.2, 4), base * CFrame.new(0, 8.8, 0), ROCK)
		P(hero, "ArchTop", Vector3.new(6, 1.4, 3), base * CFrame.new(0.6, 10.5, 0), rgb(128, 124, 140))
		palm(hero, base * CFrame.new(1.8, 11, 0), 4)
		chest(hero, base * CFrame.new(0, 0, 0.6))
		for _ = 1, 5 do
			local coin = P(hero, "Coin", Vector3.new(0.6, 0.2, 0.6), base * CFrame.new(rng:NextNumber(-2.4, 2.4), 0.25, rng:NextNumber(1.2, 3)), GOLD)
			coin.Material = Enum.Material.Neon
		end
	end

	------------------------------------------------------------------ Props
	local props = ctx.group("Props")
	local makers = {}
	function makers.palm(cf: CFrame) palm(props, cf, rng:NextNumber(5.5, 7.5)) end
	function makers.barrels(cf: CFrame)
		for _, x in {-0.95, 0.95} do
			cyl(props, "Barrel", 2, 1.7, cf * CFrame.new(x, 1, 0) * CFrame.Angles(0, 0, math.pi / 2), hull.wood)
			cyl(props, "Hoop", 0.3, 1.85, cf * CFrame.new(x, 1.4, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON)
		end
	end
	function makers.chest(cf: CFrame) chest(props, cf) end
	function makers.cannon(cf: CFrame)
		P(props, "CannonBed", Vector3.new(2, 0.7, 2.8), cf * CFrame.new(0, 0.85, 0), hull.dark)
		for _, x in {-1.2, 1.2} do cyl(props, "Wheel", 0.45, 1.9, cf * CFrame.new(x, 0.95, -0.5), hull.wood) end
		cyl(props, "Barrel", 3.4, 1.1, cf * CFrame.new(0, 1.6, 0.5) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0.15), IRON)
	end
	function makers.rope(cf: CFrame)
		cyl(props, "Coil", 0.5, 2, cf * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2), ROPE)
		cyl(props, "Coil", 0.5, 1.4, cf * CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.pi / 2), ROPE)
	end
	function makers.anchor(cf: CFrame)
		P(props, "Shank", Vector3.new(0.6, 3.4, 0.6), cf * CFrame.new(0, 1.9, 0) * CFrame.Angles(0, 0, 0.3), IRON)
		P(props, "Arms", Vector3.new(2.6, 0.6, 0.6), cf * CFrame.new(0.4, 0.5, 0), IRON)
		P(props, "Ring", Vector3.new(0.9, 0.9, 0.3), cf * CFrame.new(-0.5, 3.6, 0), IRON)
	end
	function makers.campfire(cf: CFrame)
		for k = 0, 5 do P(props, "FireStone", Vector3.new(0.7, 0.5, 0.7), cf * CFrame.Angles(0, k / 6 * math.pi * 2, 0) * CFrame.new(0, 0.25, 1), ROCK) end
		local logs = P(props, "Logs", Vector3.new(1.4, 0.5, 1.4), cf * CFrame.new(0, 0.3, 0), hull.dark)
		ctx.fire(logs, 2.5, rgb(255, 140, 40), rgb(255, 220, 120))
	end
	for _, side in {-1, 1} do
		local at = Vector3.new(side * 4.4, 0, R + 1.2)
		ctx.claim(at, 1.4)
		makers.barrels(CFrame.new(at))
	end
	ctx.scatter(makers, {"palm", "palm", "barrels", "chest", "cannon", "rope", "rope", "anchor", "campfire"},
		{palm = 1.6, barrels = 2, chest = 1.8, cannon = 2.2, rope = 1.2, anchor = 1.6, campfire = 1.6}, rng:NextInteger(7, 10),
		function(kind, at)
			return if kind == "cannon" then CFrame.lookAt(at, at + Vector3.new(0, 0, 1)) else CFrame.lookAt(at, Vector3.zero) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
		end)

	return {
		{model = ground},
		{model = edge, dust = edgeDust, dustScale = 1},
		{model = hero, dust = {frame * (base.Position + Vector3.new(-3, 0, 3)), frame * (base.Position + Vector3.new(3, 0, 3))}, dustScale = 1.4},
		{model = props},
	}
end

return Kit
