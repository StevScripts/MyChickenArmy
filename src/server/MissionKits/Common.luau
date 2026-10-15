--!strict
-- Shared toolkit for mission theme kits (docs/team/MISSIONS_PLAN.md §4).
-- October 14 owner rules: every site is about camp-sized (the camps are a 36-stud
-- square with a 14-stud clear centre) and every block carries the map's stud
-- texture (MissionSite.Studify adds it to every face after the build).
-- Frame space: origin at the courtyard centre, -Z is the back (away from the
-- owner's base), +Z the open entrance. Footprint: |x| <= 20, -21 <= z <= 21.
local Airship = require(script.Parent.Parent.InvasionAirship)
local Common = {}

Common.R = 15 -- perimeter radius
Common.CLEAR = 11.5 -- nothing inside: the loyalist formation stands here
Common.BACK = 17 -- the hero piece's centre sits at z = -BACK
Common.rgb = Color3.fromRGB

-- theta: 0 = back (-Z), pi = front (+Z).
function Common.polar(theta: number, r: number): Vector3
	return Vector3.new(math.sin(theta) * r, 0, -math.cos(theta) * r)
end

function Common.new(frame: CFrame, rng: Random)
	local ctx: any = {frame = frame, rng = rng, used = {}}
	-- Studs are added afterwards (MissionSite.Studify), so blocks start plain.
	function ctx.P(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, kind: string?): BasePart
		return Airship.Block(parent, name, size, frame * cf, color, kind, false)
	end
	function ctx.cyl(parent: Instance, name: string, length: number, diameter: number, cf: CFrame, color: Color3): BasePart
		local part = ctx.P(parent, name, Vector3.new(length, diameter, diameter), cf, color)
		part.Shape = Enum.PartType.Cylinder
		return part
	end
	function ctx.ball(parent: Instance, name: string, size: number, cf: CFrame, color: Color3): BasePart
		local part = ctx.P(parent, name, Vector3.new(size, size, size), cf, color)
		part.Shape = Enum.PartType.Ball
		return part
	end
	function ctx.neon(part: BasePart, glow: Color3?, range: number?): BasePart
		part.Material = Enum.Material.Neon
		if glow then
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness = glow, range or 10, 1.2
			light.Parent = part
		end
		return part
	end
	function ctx.fire(part: BasePart, size: number, color: Color3, secondary: Color3)
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = size, 8, color, secondary
		fire.Parent = part
	end
	function ctx.group(name: string): Model
		local model = Instance.new("Model")
		model.Name = name
		return model
	end
	function ctx.pick(list: {any}): any
		return list[rng:NextInteger(1, #list)]
	end
	function ctx.claim(at: Vector3, r: number)
		table.insert(ctx.used, {at = at, r = r})
	end
	function ctx.free(at: Vector3, r: number): boolean
		for _, other in ctx.used do
			if (other.at - at).Magnitude < other.r + r then return false end
		end
		return true
	end
	-- Seeded prop scatter in the ring between CLEAR and the perimeter, never in the
	-- entrance lane or the hero's back slot. `makers[kind](cf)` builds one prop.
	function ctx.scatter(makers: {[string]: (CFrame) -> ()}, pool: {string}, radius: {[string]: number}, count: number, facing: ((string, Vector3) -> CFrame)?)
		local tries = 0
		while count > 0 and tries < 120 do
			tries += 1
			local kind = pool[rng:NextInteger(1, #pool)]
			local r = radius[kind] or 2
			local theta = rng:NextNumber(math.rad(-140), math.rad(140))
			local at = Common.polar(theta, rng:NextNumber(Common.CLEAR + r * 0.6, Common.R - r * 0.4))
			if math.abs(at.X) < 4.5 and at.Z > 0 then continue end -- entrance lane
			if math.abs(at.X) < 6 and at.Z < -Common.R + 4 then continue end -- hero slot
			if not ctx.free(at, r) then continue end
			local cf = if facing then facing(kind, at) else CFrame.lookAt(at, Vector3.zero) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0)
			ctx.claim(at, r)
			makers[kind](cf)
			count -= 1
		end
	end
	-- Chunky stepped ground patch (reads round in the voxel style).
	function ctx.patch(parent: Instance, color: Color3, radius: number, y: number?)
		local d = radius * 2
		for _, size in {Vector3.new(d, 0.36, d * 0.62), Vector3.new(d * 0.62, 0.36, d), Vector3.new(d * 0.86, 0.36, d * 0.86)} do
			ctx.P(parent, "Ground", size, CFrame.new(0, y or 0, 0), color)
		end
	end
	-- Clods break up a patch's outline.
	function ctx.clods(parent: Instance, colors: {Color3}, rMin: number, rMax: number, count: number)
		for i = 1, count do
			local theta = (i + rng:NextNumber(-0.3, 0.3)) / count * math.pi * 2
			local s = rng:NextNumber(2.2, 3.6)
			ctx.P(parent, "Clod", Vector3.new(s, 0.34, s * rng:NextNumber(0.6, 1)),
				CFrame.new(Common.polar(theta, rng:NextNumber(rMin, rMax))) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), colors[(i % #colors) + 1])
		end
	end
	-- A short path out of the entrance toward the arriving army.
	function ctx.path(parent: Instance, color: Color3)
		ctx.P(parent, "Path", Vector3.new(6, 0.38, 7), CFrame.new(0, 0, Common.R + 2.5), color)
		for i = 1, 4 do
			local side = if i % 2 == 0 then 1 else -1
			local s = rng:NextNumber(1.6, 2.6)
			ctx.P(parent, "PathEdge", Vector3.new(s, 0.36, s), CFrame.new(side * rng:NextNumber(3, 3.8), 0, Common.R + rng:NextNumber(0, 5.5)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), color)
		end
	end
	return ctx
end

return Common
