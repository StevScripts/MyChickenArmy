-- WS1 scratch: headless Fort Roost fights with the real Battle.luau and map geometry.
local Config = Harness.require(Harness.Shared.Config)
local Rules = Harness.require(Harness.Shared.Rules)
local Progression = Harness.require(Harness.Shared.Progression)
local MapLayout = Harness.require(Harness.Shared.MapLayout)
local March = Harness.require(Harness.Shared.ArmyMarch)
local Battle = Harness.require(Harness.Server.Battle)

local function campFrame(index)
	local home = MapLayout.HomeFrame(1).Position
	local outward = Vector3.new(home.X, 0, home.Z).Unit
	local p = outward * Config.CampRadii[index] + Vector3.new(0, 1.05, 0)
	return CFrame.lookAt(p, Vector3.new(0, p.Y, 0))
end

local M = {}
-- roster: {{species, level}}, guards: Progression-style roster; effects: {damage, health}
function M.fight(roster, guards, campIndex, seed, effects)
	math.randomseed(seed)
	local frame = campFrame(campIndex)
	local home = MapLayout.HomeFrame(1).Position
	local b = Battle.new("sim" .. seed, 1, "camp:" .. campIndex, home, frame.Position, 0)
	b.frame = frame
	b.campIndex = campIndex
	b.holdRandom = Random.new(seed)
	local army = {}
	for i, e in roster do table.insert(army, {id = "p" .. i, species = e[1], stars = 1, level = e[2] or 1, slot = i}) end
	b:AddArmy("A", army, home)
	b:AddArmy("B", Progression.Normalize(guards), frame.Position)
	if effects then b:ApplyResearch("A", effects, false) end
	for _, u in b.units do if u.side == "A" then March.Approach(u, b.destination, 0, nil) end end
	local now, dt = 0, 0.1
	for step = 1, 4000 do
		now = step * dt
		local outcome = b:Step(dt, now)
		if outcome then return outcome, now - (b.arrivedAt or 0), b end
	end
	return "Timeout", now, b
end

function M.rate(roster, guards, campIndex, n, effects)
	local wins, secs = 0, 0
	for seed = 1, n do
		local o, t = M.fight(roster, guards, campIndex, seed * 7919, effects)
		if o == "A" then wins += 1; secs += t end
	end
	return wins / n, if wins > 0 then secs / wins else 0
end

function M.power(roster)
	local list = {}
	for _, e in roster do table.insert(list, {species = e[1], stars = 1, level = e[2] or 1}) end
	return Rules.Power(list)
end
local FR = {{species="CampRoostWarden",level=1},{species="CampRoostArcher",level=1},{species="CampRoostRecruit",level=1},{species="CampRoostRecruit",level=1}}
local function rep(sp, lv, n) local t = {} for i = 1, n do table.insert(t, {sp, lv}) end return t end
local function cat(...) local t = {} for _, l in {...} do for _, e in l do table.insert(t, e) end end return t end
local cases = {
	{"3 Duck L1", rep("Duck",1,3)},
	{"3 Pajama L1", rep("Pajama",1,3)},
	{"4 Duck L1", rep("Duck",1,4)},
	{"4 Pajama L1", rep("Pajama",1,4)},
	{"4 Duck L3", rep("Duck",3,4)},
	{"4 Duck L4", rep("Duck",4,4)},
	{"5 Duck L3", rep("Duck",3,5)},
	{"4 Pajama L2", rep("Pajama",2,4)},
	{"4 Pajama L3", rep("Pajama",3,4)},
	{"4 Bee L1", rep("Bee",1,4)},
	{"6 Duck L1", rep("Duck",1,6)},
	{"6 Duck L2", rep("Duck",2,6)},
	{"6 Duck L3", rep("Duck",3,6)},
	{"6 Pajama L1", rep("Pajama",1,6)},
	{"6 Pajama L2", rep("Pajama",2,6)},
	{"6 Duck L4", rep("Duck",4,6)},
	{"6 Bee L1", rep("Bee",1,6)},
	{"8 Pajama L1", rep("Pajama",1,8)},
	{"8 Pajama L2", rep("Pajama",2,8)},
}
local target = ARGS[1] and tonumber(ARGS[1]) or 2
local guards = if target == 2 then FR else Progression.Roster(1, target)
local gp = Rules.Power(Progression.Normalize(guards))
print("camp", target, "power", gp)
for _, c in cases do
	local p = M.power(c[2])
	local r, s = M.rate(c[2], guards, target, 30)
	print(string.format("%-14s power %4d ratio %.2f  win %3d%%  avg %.0fs", c[1], p, p / gp, math.floor(r * 100 + 0.5), s))
end
