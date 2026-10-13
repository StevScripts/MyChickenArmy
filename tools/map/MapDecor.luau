--!strict
-- Edit-mode map decor generator (run from the Studio command bar or Studio MCP;
-- not synced by Rojo). Rebuilds ServerStorage.MapPropKit (blocky Plastic props
-- with the island's stud overlay) and scatters copies into
-- Workspace.MyChickenArmyMap.01_Environment.Decor, keeping clear of roads,
-- home plots, main camps and the King arena. Deterministic for a given SEED.
-- Re-running replaces the previous Decor folder. Save the place afterwards.

local SEED = 20261010
local DENSITY = 1 -- 1 = default fill for the whole island
local SIZE = 0.455 -- props sit under the scale of the home bases and camps (Oct 12: 0.65 x 0.7, user asked for smaller props)

local ServerStorage = game:GetService("ServerStorage")
local map = workspace:WaitForChild("MyChickenArmyMap")
local envRoot = map["01_Environment"]
local GROUND = 1.05 -- flat top of the island cylinder
local ISLAND_RADIUS = 430
local STUD = "rbxassetid://6372755229"

-- ---------------------------------------------------------------- kit
local oldKit = ServerStorage:FindFirstChild("MapPropKit")
if oldKit then oldKit:Destroy() end
local kit = Instance.new("Folder")
kit.Name = "MapPropKit"
kit:SetAttribute("Source", "tools/map/MapDecor.luau")
kit.Parent = ServerStorage

local kitRng = Random.new(SEED)
local function C(r: number, g: number, b: number) return Color3.fromRGB(r, g, b) end
local SIDES = {Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}
local function studs(part: BasePart, faces: {Enum.NormalId})
	for _, face in faces do
		local t = Instance.new("Texture")
		t.Texture, t.Face = STUD, face
		t.StudsPerTileU, t.StudsPerTileV = 8, 8
		t.Color3, t.Transparency = Color3.new(0, 0, 0), 0.8
		t.Parent = part
	end
end
local function block(m: Model, size: Vector3, cf: CFrame, color: Color3, opt: any?): Part
	local o = opt or {}
	local p = Instance.new("Part")
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Anchored, p.CanTouch = true, false
	p.Material = o.material or Enum.Material.Plastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CanCollide = o.collide ~= false
	if o.transparency then p.Transparency = o.transparency end
	if o.studs then studs(p, if o.studs == true then {Enum.NormalId.Top} else o.studs) end
	p.Parent = m
	return p
end
local function model(name: string): Model
	local m = Instance.new("Model")
	m.Name, m.WorldPivot, m.Parent = name, CFrame.new(), kit
	return m
end
local Y = CFrame.Angles
local PINE = {C(46, 112, 38), C(58, 130, 40), C(72, 146, 44)}
local LEAF = {C(121, 154, 21), C(127, 162, 22), C(146, 184, 34)}
local TRUNK, BRANCH = C(196, 92, 38), C(170, 78, 30)
local ROCK = {C(141, 141, 211), C(157, 157, 234), C(124, 124, 194)}
local DIRT, DIRT_D, GRASS = C(186, 112, 62), C(156, 90, 50), C(127, 177, 26)

for v = 1, 3 do -- stacked pines
	local m = model("PineTree" .. v)
	local tiers, h = 3 + v, 3 + v
	block(m, Vector3.new(2, h + 2, 2), CFrame.new(0, (h + 2) / 2, 0), TRUNK)
	local y = h
	for i = 1, tiers do
		local w = 11 - (i - 1) * (8.5 / tiers) - (if v == 1 then 1.5 else 0)
		block(m, Vector3.new(w, 2.6, w), CFrame.new(0, y + 1.3, 0) * Y(0, (i % 2) * math.rad(45), 0), PINE[(i - 1) % 3 + 1], {studs = true})
		y += 2.2
	end
	block(m, Vector3.new(1.6, 2, 1.6), CFrame.new(0, y + 1, 0), PINE[3], {studs = true})
end

for v = 1, 3 do -- broadleaf block trees, like the original island trees
	local m = model("BlockTree" .. v)
	local h = 6 + v * 2
	block(m, Vector3.new(2, h, 2), CFrame.new(0, h / 2, 0), TRUNK)
	block(m, Vector3.new(1.4, 0.6, 4.5), CFrame.new(0, h * 0.55, 1.6) * Y(math.rad(-25), 0, 0), BRANCH)
	local canopy = {{9, 3.2, 9, 0, 0, 0}, {7, 3, 7, 1.2, 2.6, -0.8}, {5, 2.6, 5, -1, 4.8, 0.6}, {3, 2, 3, 0.4, 6.6, 0}}
	for i = 1, if v == 1 then 3 else 4 do
		local c = canopy[i]
		block(m, Vector3.new(c[1], c[2], c[3]), CFrame.new(c[4], h + c[5] + c[2] / 2 - 0.4, c[6]) * Y(0, math.rad(kitRng:NextInteger(0, 3) * 15), 0), LEAF[(i - 1) % 3 + 1], {studs = true})
	end
	block(m, Vector3.new(4, 2.4, 4), CFrame.new(4.2, h + 0.8, 1.8), LEAF[2], {studs = true})
end

for v = 1, 3 do -- bushes (walk-through)
	local m = model("Bush" .. v)
	for _ = 1, v + 1 do
		local s = kitRng:NextNumber(2.4, 4.2)
		block(m, Vector3.new(s, s * 0.8, s), CFrame.new(kitRng:NextNumber(-2, 2), s * 0.4, kitRng:NextNumber(-2, 2)) * Y(0, math.rad(kitRng:NextInteger(0, 89)), 0), LEAF[kitRng:NextInteger(1, 3)], {collide = false, studs = true})
	end
end

for v = 1, 3 do -- terracotta mesas with studded grass tops
	local m = model("Mesa" .. v)
	local w, d, h1 = 20 + v * 6, 14 + v * 4, 4 + v
	block(m, Vector3.new(w, h1, d), CFrame.new(0, h1 / 2, 0), DIRT, {studs = SIDES})
	block(m, Vector3.new(w + 0.2, 0.8, d + 0.2), CFrame.new(0, h1 * 0.45, 0), DIRT_D)
	block(m, Vector3.new(w + 0.6, 1, d + 0.6), CFrame.new(0, h1 + 0.5, 0), GRASS, {studs = true})
	local w2, d2, h2, ox, oz = w * 0.55, d * 0.6, 3 + v, w * 0.15, -d * 0.1
	block(m, Vector3.new(w2, h2, d2), CFrame.new(ox, h1 + 1 + h2 / 2, oz), DIRT, {studs = SIDES})
	block(m, Vector3.new(w2 + 0.6, 1, d2 + 0.6), CFrame.new(ox, h1 + 1 + h2 + 0.5, oz), GRASS, {studs = true})
	block(m, Vector3.new(w * 0.3, h1 * 0.55, d * 0.35), CFrame.new(-w * 0.5, h1 * 0.275, d * 0.3), DIRT, {studs = SIDES})
	block(m, Vector3.new(w * 0.3 + 0.6, 1, d * 0.35 + 0.6), CFrame.new(-w * 0.5, h1 * 0.55 + 0.5, d * 0.3), GRASS, {studs = true})
end

for v = 1, 3 do -- lavender rock clusters
	local m = model("Rocks" .. v)
	for i = 1, v + 2 do
		local s = Vector3.new(kitRng:NextNumber(4, 9), kitRng:NextNumber(2.5, 7 + v), kitRng:NextNumber(4, 9)) * (if i == 1 then 1.3 else 1)
		block(m, s, CFrame.new(kitRng:NextNumber(-4, 4), s.Y / 2, kitRng:NextNumber(-4, 4)) * Y(0, math.rad(kitRng:NextInteger(0, 89)), 0), ROCK[(i - 1) % 3 + 1], {studs = true})
	end
end

do -- pond in a stone rim
	local m = model("Pond1")
	local w, d = 26, 18
	block(m, Vector3.new(w + 4, 0.3, d + 4), CFrame.new(0, 0.15, 0), C(245, 205, 140), {collide = false})
	block(m, Vector3.new(w, 0.5, d), CFrame.new(0, 0.4, 0), C(52, 176, 255), {collide = false, material = Enum.Material.SmoothPlastic})
	local edges = {{w / 2 + 1, 0, 3, d + 2}, {-w / 2 - 1, 0, 3, d + 2}, {0, d / 2 + 1, w + 2, 3}, {0, -d / 2 - 1, w + 2, 3}}
	for _, e in edges do
		local long = math.max(e[3], e[4])
		local segs = math.max(2, math.floor(long / 6))
		for s = 1, segs do
			local t = (s - 0.5) / segs - 0.5
			local x = e[1] + (if e[3] > e[4] then t * e[3] else 0)
			local z = e[2] + (if e[4] > e[3] then t * e[4] else 0)
			local size = kitRng:NextNumber(2.2, 3.4)
			block(m, Vector3.new(size, kitRng:NextNumber(1.2, 2.2), size), CFrame.new(x, 0.8, z) * Y(0, math.rad(kitRng:NextInteger(0, 89)), 0), ROCK[kitRng:NextInteger(1, 3)], {studs = true})
		end
	end
	for i = 1, 6 do
		local x = kitRng:NextNumber(-w / 2 + 1, w / 2 - 1)
		local z = (if i % 2 == 0 then 1 else -1) * kitRng:NextNumber(d / 2 - 2.5, d / 2 - 0.5)
		block(m, Vector3.new(0.4, kitRng:NextNumber(2.5, 4.5), 0.4), CFrame.new(x, 2, z), C(90, 150, 40), {collide = false})
	end
end

do -- fallen log
	local m = model("Log1")
	block(m, Vector3.new(2.6, 2.6, 11), CFrame.new(0, 1.3, 0) * Y(0, math.rad(20), 0), TRUNK, {studs = SIDES})
	block(m, Vector3.new(2.8, 1.6, 2.8), CFrame.new(5, 0.8, -3), BRANCH, {studs = true})
	block(m, Vector3.new(2.2, 1.8, 2.2), CFrame.new(-2.5, 3.3, 1.2), LEAF[1], {collide = false, studs = true})
end

do -- hay bales
	local m = model("HayStack1")
	local HAY, BAND = C(240, 196, 76), C(200, 150, 46)
	for _, p in {{0, 0}, {5, 0.4}, {2.5, 3.6}} do
		block(m, Vector3.new(4.6, 3, 3.2), CFrame.new(p[1], 1.5, p[2]), HAY, {studs = true})
		block(m, Vector3.new(0.5, 3.05, 3.25), CFrame.new(p[1] - 1.2, 1.5, p[2]), BAND)
		block(m, Vector3.new(0.5, 3.05, 3.25), CFrame.new(p[1] + 1.2, 1.5, p[2]), BAND)
	end
	block(m, Vector3.new(4.6, 3, 3.2), CFrame.new(2.5, 4.5, 0.2), HAY, {studs = true})
end

do -- crate stack
	local m = model("Crates1")
	local WOOD, PLANK = C(176, 112, 62), C(130, 78, 40)
	for i, p in {{0, 0, 4}, {4.6, 0.8, 3.4}, {1.8, 4.6, 3}, {0.4, 0, 0}} do
		local s = if i == 4 then 3 else p[3]
		local y = if i == 4 then 4 + s / 2 else s / 2
		local cf = CFrame.new(p[1], y, p[2]) * Y(0, math.rad(i * 11), 0)
		block(m, Vector3.new(s, s, s), cf, WOOD, {studs = true})
		block(m, Vector3.new(s + 0.08, 0.35, s + 0.08), cf * CFrame.new(0, s * 0.3, 0), PLANK)
		block(m, Vector3.new(s + 0.08, 0.35, s + 0.08), cf * CFrame.new(0, -s * 0.3, 0), PLANK)
	end
end

do -- flower patch (walk-through)
	local m = model("Flowers1")
	local petals = {C(255, 89, 89), C(255, 255, 255), C(255, 214, 64), C(205, 120, 255)}
	for _ = 1, 9 do
		local x, z, h = kitRng:NextNumber(-4, 4), kitRng:NextNumber(-4, 4), kitRng:NextNumber(0.8, 1.6)
		block(m, Vector3.new(0.25, h, 0.25), CFrame.new(x, h / 2, z), C(90, 150, 40), {collide = false})
		block(m, Vector3.new(0.9, 0.5, 0.9), CFrame.new(x, h + 0.2, z), petals[kitRng:NextInteger(1, 4)], {collide = false})
	end
end

-- ---------------------------------------------------------------- blockers
local segs = {}
for _, p in map["02_Roads"]:GetDescendants() do
	if p:IsA("BasePart") and p.Size.Z > 40 then
		local a, b = p.CFrame * Vector3.new(0, 0, -p.Size.Z / 2), p.CFrame * Vector3.new(0, 0, p.Size.Z / 2)
		table.insert(segs, {Vector2.new(a.X, a.Z), Vector2.new(b.X, b.Z)})
	end
end
local boxes = {}
local function addBox(inst: Instance, pad: number)
	local mn, mx = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
	for _, p in inst:GetDescendants() do
		if p:IsA("BasePart") then
			local h, c = p.Size / 2, p.Position
			mn = mn:Min(Vector2.new(c.X - h.X, c.Z - h.Z)); mx = mx:Max(Vector2.new(c.X + h.X, c.Z + h.Z))
		end
	end
	if mn.X < math.huge then table.insert(boxes, {mn - Vector2.new(pad, pad), mx + Vector2.new(pad, pad)}) end
end
for _, c in map["03_HomePlots"]:GetChildren() do addBox(c, 22) end
for _, c in map["04_MainCamps"]:GetChildren() do addBox(c, 14) end
local existing = {}
for _, folderName in {"Trees", "Rocks"} do
	local f = envRoot.Environment:FindFirstChild(folderName)
	if f then for _, m in f:GetChildren() do local p = m:GetPivot().Position; table.insert(existing, Vector2.new(p.X, p.Z)) end end
end
local function segDist(p: Vector2, a: Vector2, b: Vector2): number
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end
local placed = {}
local function free(p: Vector2, r: number): boolean
	if p.Magnitude + r > ISLAND_RADIUS or p.Magnitude - r < 75 then return false end
	for _, s in segs do if segDist(p, s[1], s[2]) < 16 + r then return false end end
	for _, b in boxes do if p.X + r > b[1].X and p.X - r < b[2].X and p.Y + r > b[1].Y and p.Y - r < b[2].Y then return false end end
	for _, e in existing do if (p - e).Magnitude < r + 6 then return false end end
	for _, q in placed do if (p - q.p).Magnitude < r + q.r then return false end end
	return true
end

-- ---------------------------------------------------------------- scatter
local oldDecor = envRoot:FindFirstChild("Decor")
if oldDecor then oldDecor:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "Decor"
folder:SetAttribute("Source", "tools/map/MapDecor.luau")
folder.Parent = envRoot
local rng = Random.new(SEED + 1)
local counts = {}
local function put(name: string, p: Vector2, scale: number, r: number): boolean
	scale *= SIZE
	if not free(p, r * scale) then return false end
	local m = (kit :: any)[name]:Clone()
	if scale ~= 1 then m:ScaleTo(scale) end
	m:PivotTo(CFrame.new(p.X, GROUND, p.Y) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 359)), 0))
	m.Parent = folder
	table.insert(placed, {p = p, r = r * scale})
	counts[name] = (counts[name] or 0) + 1
	return true
end
local function randomPoint(): Vector2
	local a = math.rad(rng:NextNumber(-180, 180))
	local d = math.sqrt(rng:NextNumber((80 / ISLAND_RADIUS) ^ 2, 1)) * ISLAND_RADIUS
	return Vector2.new(math.cos(a) * d, math.sin(a) * d)
end
local function near(c: Vector2, spread: number): Vector2
	-- Gaussian-ish falloff: dense middle, thinning edges, so clusters read as natural.
	local a = rng:NextNumber(0, math.pi * 2)
	local d = spread * math.sqrt(-2 * math.log(math.max(rng:NextNumber(), 1e-4))) * 0.5
	return c + Vector2.new(math.cos(a) * d, math.sin(a) * d)
end
local function tries(n: number, fn: () -> ()) for _ = 1, math.floor(n * DENSITY) do fn() end end
local function openSpot(r: number): Vector2
	-- Cluster centres start somewhere with room, so whole groups aren't lost to roads/camps.
	for _ = 1, 40 do local p = randomPoint(); if free(p, r) then return p end end
	return randomPoint()
end
local function tree(pine: boolean): string
	return (if pine then "PineTree" else "BlockTree") .. rng:NextInteger(1, 3)
end

-- Hills: a mesa with rocks and a few trees at its foot.
tries(18, function()
	local c = openSpot(14)
	if put("Mesa" .. rng:NextInteger(1, 3), c, rng:NextNumber(0.9, 1.2), 17) then
		for _ = 1, rng:NextInteger(1, 3) do put("Rocks" .. rng:NextInteger(1, 3), near(c, 26), rng:NextNumber(0.8, 1.4), 7) end
		for _ = 1, rng:NextInteger(2, 4) do put(tree(rng:NextNumber() < 0.5), near(c, 30), rng:NextNumber(0.85, 1.2), 4.5) end
	end
end)
-- Ponds with reeds, flowers and a bush or two around them.
tries(8, function()
	local c = openSpot(14)
	if put("Pond1", c, rng:NextNumber(0.9, 1.2), 17) then
		for _ = 1, rng:NextInteger(1, 3) do put("Flowers1", near(c, 20), 1, 4) end
		for _ = 1, 2 do put("Bush" .. rng:NextInteger(1, 3), near(c, 22), rng:NextNumber(0.9, 1.2), 3) end
	end
end)
-- Woods: a dense core of one tree type that thins out at the edges.
tries(20, function()
	local c = openSpot(20)
	local pines = rng:NextNumber() < 0.6
	for _ = 1, rng:NextInteger(8, 16) do put(tree(pines ~= (rng:NextNumber() < 0.12)), near(c, 34), rng:NextNumber(0.8, 1.25), 4.5) end
	for _ = 1, rng:NextInteger(3, 6) do put("Bush" .. rng:NextInteger(1, 3), near(c, 42), rng:NextNumber(0.9, 1.3), 3) end
	if rng:NextNumber() < 0.4 then put("Log1", near(c, 40), 1, 7) end
end)
-- Rock outcrops.
tries(14, function()
	local c = openSpot(8)
	for _ = 1, rng:NextInteger(1, 3) do put("Rocks" .. rng:NextInteger(1, 3), near(c, 16), rng:NextNumber(0.9, 1.6), 7) end
end)
-- Farm touches near the home plots' side of the island.
tries(10, function()
	local p = randomPoint()
	if p.Magnitude > 280 then put(if rng:NextNumber() < 0.5 then "HayStack1" else "Crates1", p, 1, 6) end
end)
-- A few lone trees and bushes so meadows aren't empty.
tries(60, function() put(tree(rng:NextNumber() < 0.5), randomPoint(), rng:NextNumber(0.85, 1.2), 4.5) end)
tries(60, function() put("Bush" .. rng:NextInteger(1, 3), randomPoint(), rng:NextNumber(0.9, 1.3), 3) end)

local parts = 0
for _, d in folder:GetDescendants() do if d:IsA("BasePart") then parts += 1 end end
local list = {}
for k, v in counts do table.insert(list, k .. "=" .. v) end
table.sort(list)
return string.format("Decor: %d props, %d parts. %s", #placed, parts, table.concat(list, " "))
