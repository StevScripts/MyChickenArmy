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
	b:AddArmy("B", if guards[1] and guards[1].stars then guards else Progression.Normalize(guards), frame.Position)
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
local function scaled(list, scale)
	local out = {}
	for i, pet in list do local u = table.clone(pet); local st = table.clone(Rules.Stats(pet.species, 1, pet.level)); st.hp *= scale; st.damage *= scale; u.combatStats = st; out[i] = u end
	return out
end
local function rep(sp, lv, n) local t = {} for i = 1, n do table.insert(t, {sp, lv}) end return t end
local function cat(...) local t = {} for _, l in {...} do for _, e in l do table.insert(t, e) end end return t end
for _, sc in {0.5, 0.55, 0.6} do
	local IB = scaled(Progression.Roster(1, 3), sc)
	local ip = Rules.Power(Progression.Roster(1, 3)) * sc
	print(string.format("Ironbeak x%.2f power %.0f (ready %.0f)", sc, ip, ip * 1.3))
	for _, a in {{"4 Common L2", rep("Pajama",2,4)}, {"6 Duck L2", rep("Duck",2,6)}, {"6 Common", rep("Pajama",1,6)}, {"6 Common L2", rep("Pajama",2,6)}, {"4 Bee", rep("Bee",1,4)}, {"5 Bee", rep("Bee",1,5)}, {"6 Duck L3", rep("Duck",3,6)}, {"8 Common", rep("Pajama",1,8)}, {"6 Bee", rep("Bee",1,6)}} do
		local p = M.power(a[2]); local w = 0
		for seed = 1, 10 do if M.fight(a[2], IB, 3, seed * 7919) == "A" then w += 1 end end
		print(string.format("  %-12s %4d %.2f %3d%%", a[1], p, p / ip, w * 10))
	end
end
