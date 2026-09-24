--!strict
-- Static dressing only. WorldBuilder owns the field, roads and interactive sites.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local HomePlot = require(Shared.HomePlotLayout)

local MapScenery = {}
local FIELD_Y = 1.05
local PALETTE = {
	timber = Color3.fromRGB(170, 85, 0),
	timberDark = Color3.fromRGB(117, 59, 0),
	leafDark = Color3.fromRGB(77, 157, 59),
	leaf = Color3.fromRGB(104, 183, 72),
	leafLight = Color3.fromRGB(139, 205, 95),
	stone = Color3.fromRGB(141, 141, 211),
	stoneLight = Color3.fromRGB(188, 192, 255),
	grass = Color3.fromRGB(119, 191, 80),
	grassLight = Color3.fromRGB(157, 218, 106),
}

type Footprint = { frame: CFrame, x: number, z: number }
type SceneryKind = "Tree" | "Rocks" | "Grass"

local function model(parent: Instance, name: string, frame: CFrame?): Model
	local result = Instance.new("Model")
	result.Name = name
	if frame then result.WorldPivot = frame end
	result.Parent = parent
	return result
end

local function part(builder, parent: Instance, name: string, size: Vector3, frame: CFrame, color: Color3, studs: boolean, shadow: boolean): BasePart
	local result = builder.Part(parent, name, size, frame, color, false)
	result.Anchored = true
	result.CanCollide, result.CanTouch, result.CanQuery = false, false, false
	result.Material = Enum.Material.Plastic
	result.TopSurface = if studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	result.BottomSurface = Enum.SurfaceType.Smooth
	result.CastShadow = shadow
	return result
end

local function inward(position: Vector3): CFrame
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end

local function polar(bearing: number, radius: number): Vector3
	local angle = math.rad(bearing)
	return Vector3.new(math.sin(angle) * radius, FIELD_Y, -math.cos(angle) * radius)
end

local function footprint(frame: CFrame, halfX: number, halfZ: number): Footprint
	return { frame = frame, x = halfX, z = halfZ }
end

-- Separating axes in X/Z protect rotated native plots and camp corner envelopes.
local function overlaps(a: Footprint, b: Footprint, padding: number): boolean
	local delta = b.frame.Position - a.frame.Position
	for _, axis in { a.frame.RightVector, a.frame.LookVector, b.frame.RightVector, b.frame.LookVector } do
		local aRadius = math.abs(a.frame.RightVector:Dot(axis)) * a.x + math.abs(a.frame.LookVector:Dot(axis)) * a.z
		local bRadius = math.abs(b.frame.RightVector:Dot(axis)) * b.x + math.abs(b.frame.LookVector:Dot(axis)) * b.z
		if math.abs(delta:Dot(axis)) > aRadius + bRadius + padding then return false end
	end
	return true
end

local function radialBounds(box: Footprint): (number, number)
	local origin = box.frame:PointToObjectSpace(Vector3.new(0, FIELD_Y, 0))
	local nearest = box.frame:PointToWorldSpace(Vector3.new(math.clamp(origin.X, -box.x, box.x), 0, math.clamp(origin.Z, -box.z, box.z)))
	local minimum = Vector2.new(nearest.X, nearest.Z).Magnitude
	local maximum = 0
	for _, x in { -box.x, box.x } do
		for _, z in { -box.z, box.z } do
			local corner = box.frame:PointToWorldSpace(Vector3.new(x, 0, z))
			maximum = math.max(maximum, Vector2.new(corner.X, corner.Z).Magnitude)
		end
	end
	return minimum, maximum
end

local function tree(builder, parent: Instance, name: string, frame: CFrame, large: boolean): Model
	local group = model(parent, name, frame)
	group:SetAttribute("SceneryKind", "Tree")
	local scale = if large then Vector3.new(1.2, 1.375, 1.2) else Vector3.one
	local function piece(label: string, size: Vector3, at: Vector3, color: Color3, studs: boolean)
		return part(builder, group, label, size * scale, frame * CFrame.new(at * scale), color, studs, true)
	end
	piece("Trunk", Vector3.new(1.25, 4.75, 1.25), Vector3.new(0, 2.375, 0), PALETTE.timber, true)
	piece("TrunkFoot", Vector3.new(1.75, 0.5, 1.75), Vector3.new(0, 0.25, 0), PALETTE.timberDark, true)
	piece("LeafUnderside", Vector3.new(6.5, 1.5, 5.75), Vector3.new(0, 4.25, 0), PALETTE.leafDark, true)
	piece("LeafBody", Vector3.new(6, 2.25, 5.75), Vector3.new(0.25, 5.5, 0), PALETTE.leaf, true)
	piece("LeafShoulder", Vector3.new(3.5, 2, 4), Vector3.new(-1.5, 6.25, 0.25), PALETTE.leaf, true)
	piece("LeafTop", Vector3.new(4.25, 1.5, 4.25), Vector3.new(0.5, 7.25, -0.5), PALETTE.leafLight, true)
	group:SetAttribute("Height", if large then 11 else 8)
	return group
end

local function rocks(builder, parent: Instance, name: string, frame: CFrame): Model
	local group = model(parent, name, frame)
	group:SetAttribute("SceneryKind", "Rocks")
	part(builder, group, "LowerBlock", Vector3.new(4.75, 1.25, 3.25), frame * CFrame.new(-0.5, 0.625, 0.35), PALETTE.stone, true, true)
	part(builder, group, "MiddleBlock", Vector3.new(3.5, 1.75, 3), frame * CFrame.new(0.9, 1.375, -0.5), PALETTE.stoneLight, true, true)
	part(builder, group, "TopBlock", Vector3.new(2.6, 0.75, 2.2), frame * CFrame.new(0.4, 2.5, -0.1), PALETTE.stoneLight, true, true)
	return group
end

local function grass(builder, parent: Instance, name: string, frame: CFrame): Model
	local group = model(parent, name, frame)
	group:SetAttribute("SceneryKind", "Grass")
	-- Broad square blades, not a detailed animated grass carpet.
	for index, spec in {
		{ -0.65, 0.8, 0.12, -12 }, { 0, 1.15, -0.12, 0 }, { 0.65, 0.9, 0.15, 12 },
	} do
		part(builder, group, "Blade" .. index, Vector3.new(0.55, spec[2], 0.2),
			frame * CFrame.new(spec[1], spec[2] / 2, spec[3]) * CFrame.Angles(0, 0, math.rad(spec[4])),
			if index == 2 then PALETTE.grassLight else PALETTE.grass, false, false)
	end
	return group
end

function MapScenery.Build(builder, root: Instance, positions, map): Model
	local landscape = model(root, "Landscape", CFrame.new(0, FIELD_Y, 0))
	landscape:SetAttribute("SceneryVersion", 1)
	landscape:SetAttribute("PlacementRecipe", "BuilderPalette_ThreeCampRoutes")
	local exclusions: { Footprint } = {}
	local occupied: { Footprint } = {}
	local camps: { CFrame } = {}
	local homes: { { frame: CFrame, width: number, depth: number } } = {}
	local campHalf = Config.CampHalfSize
	local function reserveCamp(frame: CFrame)
		table.insert(camps, frame)
		table.insert(exclusions, footprint(frame, campHalf + 1, campHalf + 1))
		-- Four clear approaches, including grass approaches to optional sites.
		table.insert(exclusions, footprint(frame, 8, campHalf + 12))
		table.insert(exclusions, footprint(frame, campHalf + 12, 8))
	end
	for index, position in positions do
		local at = Vector3.new(position[1], FIELD_Y, position[2])
		local frame = inward(at)
		local layout = HomePlot.ForPlot(index)
		table.insert(homes, { frame = frame, width = layout.Width, depth = layout.Depth })
		table.insert(exclusions, footprint(frame, layout.Width / 2 + 6, layout.Depth / 2 + 6))
		local radius = Vector2.new(at.X, at.Z).Magnitude
		local direction = Vector3.new(at.X, 0, at.Z).Unit
		local roadFrame = inward(direction * (radius / 2) + Vector3.new(0, FIELD_Y, 0))
		table.insert(exclusions, footprint(roadFrame, 8, radius / 2))
		for _, campRadius in Config.CampRadii do
			reserveCamp(inward(direction * campRadius + Vector3.new(0, FIELD_Y, 0)))
		end
	end
	for index = 1, 6 do reserveCamp(inward(polar(30 + (index - 1) * 60, map.OutpostRadius))) end
	if Config.IncomeOutpost and Config.IncomeOutpost.Enabled then
		local p = Config.IncomeOutpost.Position
		reserveCamp(inward(Vector3.new(p[1], FIELD_Y, p[3])))
	end

	local placed: { [SceneryKind]: number } = { Tree = 0, Rocks = 0, Grass = 0 }
	local omitted: { [SceneryKind]: number } = { Tree = 0, Rocks = 0, Grass = 0 }
	local limits: { [SceneryKind]: number } = { Tree = 36, Rocks = 36, Grass = 134 }
	local function allowed(box: Footprint, kind: SceneryKind): boolean
		local minRadius, maxRadius = radialBounds(box)
		if maxRadius > map.IslandRadius - 0.5 then return false end
		if minRadius < (if kind == "Tree" then 55 else 38) then return false end
		if minRadius <= map.HomeRingRadius + 5.6 and maxRadius >= map.HomeRingRadius - 5.6 then return false end
		for _, exclusion in exclusions do if overlaps(box, exclusion, 0) then return false end end
		for _, other in occupied do if overlaps(box, other, 0.35) then return false end end
		return true
	end
	local function place(parent: Instance, kind: SceneryKind, frame: CFrame, large: boolean?)
		local box = if kind == "Tree" then footprint(frame, if large then 3.9 else 3.25, if large then 3.45 else 2.875)
			elseif kind == "Rocks" then footprint(frame, 3, 2.5) else footprint(frame, 1.25, 1.25)
		if placed[kind] >= limits[kind] or not allowed(box, kind) then omitted[kind] += 1; return end
		placed[kind] += 1
		table.insert(occupied, box)
		local name = kind .. string.format("%02d", placed[kind])
		local item = if kind == "Tree" then tree(builder, parent, name, frame, large == true)
			elseif kind == "Rocks" then rocks(builder, parent, name, frame) else grass(builder, parent, name, frame)
		item:SetAttribute("FootprintX", box.x * 2)
		item:SetAttribute("FootprintZ", box.z * 2)
	end
	local function offsetFrame(frame: CFrame, x: number, z: number): CFrame
		return frame * CFrame.new(x, 0, z)
	end

	local outer = model(landscape, "OuterBelt")
	for index = 1, 12 do
		local frame = inward(polar(15 + (index - 1) * 30, map.IslandRadius - 6))
		local cluster = model(outer, "Cluster" .. index, frame)
		place(cluster, "Tree", frame, false)
		place(cluster, "Rocks", offsetFrame(frame, 8, 1))
		place(cluster, "Grass", offsetFrame(frame, -6, 1))
		place(cluster, "Grass", offsetFrame(frame, 14, 1))
	end

	local pockets = model(landscape, "BetweenRoutes")
	for sector = 1, 6 do
		for ringIndex, radius in { 145, 286 } do
			local frame = inward(polar(30 + (sector - 1) * 60, radius))
			local cluster = model(pockets, "Sector" .. sector .. "_Pocket" .. ringIndex, frame)
			-- Paired trees leave the radial centerline open for cross-field travel.
			place(cluster, "Tree", offsetFrame(frame, -10, -1.5), ringIndex == 2)
			place(cluster, "Tree", offsetFrame(frame, 10, 1.5), ringIndex == 1)
			place(cluster, "Rocks", offsetFrame(frame, 7, 10))
			place(cluster, "Grass", offsetFrame(frame, -11, 6))
			place(cluster, "Grass", offsetFrame(frame, -2, 10))
			place(cluster, "Grass", offsetFrame(frame, 13, -7))
		end
	end

	local campEdges = model(landscape, "CampEdges")
	for index, frame in camps do
		local cluster = model(campEdges, "Camp" .. index, frame)
		for _, side in { -1, 1 } do
			place(cluster, "Grass", offsetFrame(frame, side * (campHalf + 3.5), campHalf + 3.5))
		end
	end

	local homeEdges = model(landscape, "HomeEdges")
	for index, home in homes do
		local cluster = model(homeEdges, "Home" .. index, home.frame)
		for _, side in { -1, 1 } do
			place(cluster, "Rocks", offsetFrame(home.frame, side * (home.width / 2 + 11.5), home.depth / 2 - 3))
			place(cluster, "Grass", offsetFrame(home.frame, side * (home.width / 2 + 9.5), home.depth / 2 - 12))
			place(cluster, "Grass", offsetFrame(home.frame, side * (home.width / 2 + 14.5), home.depth / 2 - 10))
		end
	end
	for kind, count in placed do
		landscape:SetAttribute(kind .. "Count", count)
		landscape:SetAttribute(kind .. "Omitted", omitted[kind])
	end
	local partCount = 0
	for _, descendant in landscape:GetDescendants() do
		if descendant:IsA("BasePart") then partCount += 1 end
	end
	landscape:SetAttribute("PartCount", partCount)
	return landscape
end

return MapScenery
