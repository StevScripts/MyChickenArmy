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
local FR = Progression.Roster(1,2)
local gp = Rules.Power(FR)
local combos = {}
local species = {{"Duck",13},{"Pajama",19.3},{"Bee",29.7},{"Bucket",38.4}}
-- n chickens of a species at level L, plus mixes
for n = 4, 8 do for _, sp in {"Duck","Pajama","Bee"} do for L = 1, 5 do
	local t = {} for i = 1, n do table.insert(t, {sp, L}) end
	local p = M.power(t)
	if p/gp >= 0.95 and p/gp <= 1.45 then table.insert(combos, {n.."x"..sp.." L"..L, t, p}) end
end end end
table.sort(combos, function(a,b) return a[3] < b[3] end)
for _, c in combos do
	local outs = {}
	local wins = 0
	for seed = 1, 20 do local o = M.fight(c[2], FR, 2, seed*7919); outs[o] = (outs[o] or 0) + 1; if o=="A" then wins+=1 end end
	local s = "" for k,v in outs do s ..= k.."="..v.." " end
	print(string.format("%-16s power %4d ratio %.2f win %3d%% %s", c[1], c[3], c[3]/gp, wins*5, s))
end
