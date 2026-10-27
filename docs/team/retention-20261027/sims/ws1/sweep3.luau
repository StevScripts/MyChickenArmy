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
-- Scaled garrisons: copy BattleService.scaledRoster (hp and damage x scale).
local function scaledGuards(roster, scale)
	local out = {}
	for i, pet in Progression.Normalize(roster) do
		local u = table.clone(pet)
		local st = table.clone(Rules.Stats(pet.species, 1, pet.level))
		st.hp *= scale; st.damage *= scale
		u.combatStats = st
		out[i] = u
	end
	return out
end
local W,A,R = {species="CampRoostWarden",level=1},{species="CampRoostArcher",level=1},{species="CampRoostRecruit",level=1}
local FR = {W,A,R,R}
local camps = {
	{"FR x1.00", scaledGuards(FR,1), 106.7},
	{"FR x0.60", scaledGuards(FR,0.6), 106.7*0.6},
	{"FR x0.50", scaledGuards(FR,0.5), 106.7*0.5},
	{"FR x0.45", scaledGuards(FR,0.45), 106.7*0.45},
	{"FR x0.40", scaledGuards(FR,0.40), 106.7*0.40},
	{"A+R+R", Progression.Normalize({A,R,R}), 68.3},
	{"R+R+R", Progression.Normalize({R,R,R}), 57.9},
	{"W+R", Progression.Normalize({W,R}), 57.7},
	{"R+R", Progression.Normalize({R,R}), 38.6},
}
local armies = {
	{"3 Duck", {{"Duck",1},{"Duck",1},{"Duck",1}}},
	{"2 Duck+Rooster", {{"Duck",1},{"Duck",1},{"Rooster",1}}},
	{"Duck+2 Common", {{"Duck",1},{"Rooster",1},{"Pajama",1}}},
	{"3 Common", {{"Pajama",1},{"Pajama",1},{"Pajama",1}}},
	{"4 Duck", {{"Duck",1},{"Duck",1},{"Duck",1},{"Duck",1}}},
	{"2Duck+2Common", {{"Duck",1},{"Duck",1},{"Rooster",1},{"Pajama",1}}},
	{"4 Duck L2", {{"Duck",2},{"Duck",2},{"Duck",2},{"Duck",2}}},
	{"4 Common", {{"Pajama",1},{"Pajama",1},{"Pajama",1},{"Rooster",1}}},
	{"3Duck+2Common", {{"Duck",1},{"Duck",1},{"Duck",1},{"Rooster",1},{"Pajama",1}}},
	{"4 Duck L3", {{"Duck",3},{"Duck",3},{"Duck",3},{"Duck",3}}},
	{"6 Duck", {{"Duck",1},{"Duck",1},{"Duck",1},{"Duck",1},{"Duck",1},{"Duck",1}}},
}
local header = string.format("%-16s %5s", "army", "pow")
for _, c in camps do header ..= string.format(" %10s", c[1]) end
print(header)
local row = string.format("%-16s %5s", "garrison power", "")
for _, c in camps do row ..= string.format(" %10d", math.floor(c[3])) end
print(row)
for _, a in armies do
	local p = M.power(a[2])
	local line = string.format("%-16s %5d", a[1], p)
	for _, c in camps do
		local wins = 0
		for seed = 1, 12 do if M.fight(a[2], c[2], 2, seed*7919) == "A" then wins += 1 end end
		line ..= string.format(" %4.2f %3d%%", p / c[3], math.floor(wins/12*100+0.5))
	end
	print(line)
end
