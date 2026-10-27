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
local function rep(sp, lv, n) local t = {} for i = 1, n do table.insert(t, {sp, lv}) end return t end
local function cat(...) local t = {} for _, l in {...} do for _, e in l do table.insert(t, e) end end return t end
print("Cluck Camp (12)")
for _, a in {{"1 Duck",rep("Duck",1,1)},{"1 Rooster",rep("Rooster",1,1)},{"1 Pajama",rep("Pajama",1,1)},{"1 Duck L3",rep("Duck",3,1)},{"1 Bee",rep("Bee",1,1)},{"2 Duck",rep("Duck",1,2)},{"3 Duck",rep("Duck",1,3)}} do
	local p = M.power(a[2]); local r = M.rate(a[2], Progression.Roster(1,1), 1, 12)
	print(string.format("  %-12s %4d %.2f %3d%%", a[1], p, p/12, math.floor(r*100+.5)))
end
local IB = Progression.Roster(1,3); local ip = Rules.Power(IB)
print("Ironbeak", ip)
for n = 5, 10 do for _, sp in {"Pajama","Bee","Bucket"} do for L = 1, 4 do
	local t = rep(sp, L, n); local p = M.power(t)
	if p/ip > 0.95 and p/ip < 1.5 then
		local r = M.rate(t, IB, 3, 10)
		print(string.format("  %dx%s L%d %4d %.2f %3d%%", n, sp, L, p, p/ip, math.floor(r*100+.5)))
	end
end end end
