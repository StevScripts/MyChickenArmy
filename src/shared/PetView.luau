--!strict
-- Native-part chicken recipes and replaceable Humanoid rigs. Callers own lifetime.
-- Create/Move are anchored presentation APIs; CreateRig is for physical actors.
-- No per-duck scripts, tasks, or animation loops are created here.
local Catalog = require(script.Parent.PetCatalog)
local Rules = require(script.Parent.Rules)
local BlenderPetView = require(script.Parent.BlenderPetView)
local ChickenGrowth = require(script.Parent.ChickenGrowth)
local Giant = require(script.Parent.GiantChicken)
local UIColors = require(script.Parent.UIColors)
local PetView = {}
local CollectionService = game:GetService("CollectionService")

local C = Color3.fromRGB
local PALETTE = {
	bill = C(255, 163, 55), billLower = C(229, 113, 31), feet = C(249, 144, 40),
	eye = C(29, 38, 48), ivory = C(255, 246, 210), white = C(255, 253, 240),
	navy = C(31, 79, 126), silver = C(179, 208, 221), steel = C(92, 122, 144),
	gold = C(255, 204, 82), red = C(230, 71, 72), wood = C(123, 76, 49),
}

type Pose = {
	foot: Vector3, facing: Vector3, lastAt: number, phase: number,
	rootHeight: number, size: number, flash: boolean,
	colors: {[BasePart]: Color3},
}
-- Keep the Instance wrapper alive while the engine hierarchy owns the model.
-- A weak-key cache can lose an otherwise live model between hierarchy lookups,
-- leaving a visible duck frozen while its authoritative position keeps moving.
local poses: {[Model]: Pose} = {}
local replicatedFlashes: {[Model]: {active: boolean, colors: {[BasePart]: Color3}}} = {}

local function corner(parent: Instance, radius: number)
	local rounding = Instance.new("UICorner")
	rounding.CornerRadius = UDim.new(0, radius)
	rounding.Parent = parent
end

local function addTag(body: BasePart, displayName: string, offset: number)
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(120, 42)
	tag.StudsOffset = Vector3.new(0, offset, 0)
	tag.AlwaysOnTop = false
	tag.MaxDistance = 60
	tag.LightInfluence = 0
	tag.Parent = body
	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.Size = UDim2.new(1, 0, 0, 23)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.SourceSansBold
	label.TextSize = 12
	label.TextColor3 = UIColors.Text
	label.TextStrokeColor3 = UIColors.Border
	label.TextStrokeTransparency = 0.2
	label.Text = displayName
	label.Parent = tag
	local cash = Instance.new("TextLabel")
	cash.Name = "Cash"
	cash.AnchorPoint = Vector2.new(0.5, 0)
	cash.Position = UDim2.fromScale(0.5, 0)
	cash.Size = UDim2.fromOffset(76, 25)
	cash.BackgroundColor3 = UIColors.Body
	cash.BackgroundTransparency = 0
	cash.BorderSizePixel = 0
	cash.Font = Enum.Font.SourceSansBold
	cash.TextSize = 14
	cash.TextColor3 = UIColors.Rewards
	cash.TextStrokeTransparency = 1
	cash.Visible = false
	cash.Parent = tag
	corner(cash, 9)
	local health = Instance.new("Frame")
	health.Name = "Health"
	health.AnchorPoint = Vector2.new(0.5, 0)
	health.Position = UDim2.new(0.5, 0, 0, 2)
	health.Size = UDim2.fromOffset(112, 18)
	health.BorderSizePixel = 0
	health.BackgroundColor3 = C(58, 72, 79)
	health.Visible = false
	health.Parent = tag
	local outline = Instance.new("UIStroke")
	outline.Color, outline.Thickness = C(0, 0, 0), 2
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.BorderStrokePosition = Enum.BorderStrokePosition.Outer
	outline.LineJoinMode = Enum.LineJoinMode.Miter
	outline.Parent = health
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = UIColors.Money
	fill.Parent = health
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(C(255, 255, 255), C(205, 205, 205))
	gradient.Rotation, gradient.Parent = 90, fill
	local rim = Instance.new("Frame")
	rim.Name, rim.BackgroundTransparency, rim.BorderSizePixel = "InnerRim", 1, 0
	rim.Position, rim.Size = UDim2.fromOffset(1, 1), UDim2.new(1, -2, 1, -2)
	rim.ZIndex, rim.Parent = 2, health
	local highlight = Instance.new("UIStroke")
	highlight.Color, highlight.Thickness, highlight.Transparency = UIColors.Text, 1, 0.65
	highlight.ApplyStrokeMode, highlight.LineJoinMode = Enum.ApplyStrokeMode.Border, Enum.LineJoinMode.Miter
	highlight.BorderStrokePosition, highlight.Parent = Enum.BorderStrokePosition.Inner, rim
	local value = Instance.new("TextLabel")
	value.Name, value.BackgroundTransparency, value.BorderSizePixel = "Value", 1, 0
	value.Position, value.Size = UDim2.fromOffset(2, 1), UDim2.new(1, -4, 1, -2)
	value.Font, value.TextSize, value.TextScaled = Enum.Font.SourceSansBold, 14, true
	value.TextColor3, value.TextStrokeColor3, value.TextStrokeTransparency = UIColors.Text, C(0, 0, 0), 0
	value.Text, value.ZIndex, value.Parent = "", 3, health
end

function PetView.Create(parent: Instance, id: string, species: string, stars: number, foot: Vector3)
	local definition, stats = Catalog[species], Rules.Stats(species, stars)
	local imported = BlenderPetView.Create(parent, id, species, stars, foot, false)
	if imported then
		addTag(imported.PrimaryPart, definition.name, imported:GetAttribute("VisualHeight") - imported:GetAttribute("FootOffset") + 0.43)
		return imported
	end
	local recipe = definition.baseSpecies or species
	local size = stats.size
	local bodyColor = C(table.unpack(definition.color))
	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("Species", species)
	model:SetAttribute("Stars", stars)
	model:SetAttribute("Size", size)
	model:SetAttribute("VisualStyle", "ChunkyChicken")
	local partColors: {[BasePart]: Color3} = {}

	-- All recipe dimensions are normalized to the catalog size; +Z is the bill.
	-- The visible Body remains the primary part for existing hit feedback.
	local function part(name: string, dimensions: Vector3, position: Vector3, color: Color3,
		shape: string?, rotation: CFrame?, material: Enum.Material?): BasePart
		local item: BasePart
		if shape == "Wedge" then item = Instance.new("WedgePart")
		elseif shape == "Corner" then item = Instance.new("CornerWedgePart")
		else
			local block = Instance.new("Part")
			if shape == "Ball" then block.Shape = Enum.PartType.Ball
			elseif shape == "Cylinder" then block.Shape = Enum.PartType.Cylinder end
			item = block
		end
		item.Name = name
		item.Size = dimensions * size
		item.CFrame = CFrame.new(position * size) * (rotation or CFrame.identity)
		item.Color = color
		item.Material = material or Enum.Material.SmoothPlastic
		item.Anchored = true
		item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
		item.CastShadow = name == "Body" or name == "Head" or name == "Hat" or name == "Helmet"
		item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		item.Parent = model
		partColors[item] = color
		return item
	end
	local function cylinder(name: string, diameter: number, height: number, at: Vector3, color: Color3, material: Enum.Material?): BasePart
		return part(name, Vector3.new(height, diameter, diameter), at, color, "Cylinder", CFrame.Angles(0, 0, math.pi / 2), material)
	end

	local headColor = bodyColor:Lerp(PALETTE.ivory, 0.18)
	local wingColor = bodyColor:Lerp(PALETTE.white, 0.18)
	local breastColor = bodyColor:Lerp(PALETTE.ivory, 0.45)
	local billColor, tailColor = PALETTE.bill, wingColor
	if recipe == "Mallard" then
		bodyColor = C(165, 99, 55)
		headColor, wingColor = C(204, 145, 86), C(127, 74, 43)
		breastColor, billColor, tailColor = C(219, 167, 106), PALETTE.bill, C(85, 55, 38)
	elseif recipe == "Sailor" then
		headColor, breastColor = PALETTE.white, PALETTE.white
	elseif recipe == "Bucket" or recipe == "Viking" then
		headColor = PALETTE.white
	elseif recipe == "Knight" then
		headColor, breastColor, wingColor = PALETTE.white, PALETTE.silver, PALETTE.steel
	elseif recipe == "Wizard" then
		headColor, breastColor = PALETTE.white, C(221, 205, 255)
	elseif recipe == "Dragon" then
		headColor, breastColor = bodyColor:Lerp(C(214, 255, 180), 0.25), C(245, 224, 138)
		billColor = C(255, 194, 77)
	end

	local body = part("Body", Vector3.new(0.84, 0.78, 0.84), Vector3.new(0, 0.45, -0.02), bodyColor, "Ball")
	model.PrimaryPart = body :: Part
	part("Breast", Vector3.new(0.65, 0.46, 0.42), Vector3.new(0, 0.43, 0.30), breastColor, "Ball")
	part("Head", Vector3.new(0.67, 0.67, 0.65), Vector3.new(0, 0.98, 0.25), headColor, "Ball")
	part("Bill", Vector3.new(0.25, 0.19, 0.30), Vector3.new(0, 0.92, 0.64), billColor,
		"Wedge", CFrame.Angles(0, math.pi, 0))
	part("BillSmile", Vector3.new(0.20, 0.08, 0.24), Vector3.new(0, 0.83, 0.62), PALETTE.billLower,
		"Wedge", CFrame.Angles(math.pi, 0, 0))
	part("Wattle", Vector3.new(0.16, 0.23, 0.15), Vector3.new(0, 0.72, 0.50), PALETTE.red, "Ball")
	local bareHead = recipe == "Duck" or recipe == "Mallard"
	for index = 1, 3 do
		part("Comb" .. index, Vector3.new(0.13, if bareHead then 0.22 + (if index == 2 then 0.07 else 0) else 0.14, 0.16),
			Vector3.new(0, if bareHead then 1.32 else 1.24, 0.08 + index * 0.13), PALETTE.red,
			"Wedge", CFrame.Angles(0, math.pi, 0))
	end
	for _, side in {-1, 1} do
		part("Eye" .. side, Vector3.new(0.12, 0.15, 0.085), Vector3.new(side * 0.195, 1.04, 0.55), PALETTE.eye, "Ball")
		part("EyeGlint" .. side, Vector3.new(0.038, 0.043, 0.025), Vector3.new(side * 0.195 - 0.015, 1.074, 0.59), PALETTE.white, "Ball")
		part("Foot" .. side, Vector3.new(0.11, 0.095, 0.34), Vector3.new(side * 0.225, 0.0475, 0.22), PALETTE.feet,
			nil, CFrame.Angles(0, side * -0.13, 0))
		part("Leg" .. side, Vector3.new(0.075, 0.18, 0.075), Vector3.new(side * 0.225, 0.13, 0.16), PALETTE.feet)
		part("ToeOuter" .. side, Vector3.new(0.065, 0.08, 0.24), Vector3.new(side * 0.30, 0.04, 0.24), PALETTE.feet,
			nil, CFrame.Angles(0, side * 0.42, 0))
		part("ToeInner" .. side, Vector3.new(0.065, 0.08, 0.24), Vector3.new(side * 0.15, 0.04, 0.24), PALETTE.feet,
			nil, CFrame.Angles(0, side * -0.42, 0))
		if recipe ~= "Dragon" then
			part("Wing" .. side, Vector3.new(0.18, 0.38, 0.64), Vector3.new(side * 0.414, 0.49, -0.07), wingColor,
				"Ball", CFrame.Angles(-0.16, side * -0.15, side * -0.13))
		end
	end
	part("Tail", Vector3.new(0.28, 0.59, 0.33), Vector3.new(0, 0.68, -0.49), tailColor,
		"Wedge", CFrame.Angles(-0.22, math.pi, 0))
	for _, side in {-1, 1} do
		part("TailFan" .. side, Vector3.new(0.19, 0.47, 0.30), Vector3.new(side * 0.17, 0.61, -0.47), tailColor,
			"Wedge", CFrame.Angles(-0.18, math.pi, side * -0.28))
	end

	if recipe == "Mallard" then
		cylinder("WhiteNeckRing", 0.51, 0.075, Vector3.new(0, 0.72, 0.25), PALETTE.white)
		for _, side in {-1, 1} do
			part("BlueWingFlash" .. side, Vector3.new(0.028, 0.13, 0.30), Vector3.new(side * 0.502, 0.51, -0.12),
				C(226, 184, 126), nil, CFrame.Angles(-0.16, 0, 0))
		end
	elseif recipe == "Sailor" then
		part("SailorCollar", Vector3.new(0.63, 0.085, 0.53), Vector3.new(0, 0.70, 0.24), PALETTE.navy)
		part("Neckerchief", Vector3.new(0.20, 0.25, 0.055), Vector3.new(0, 0.62, 0.56), PALETTE.red, "Wedge")
		cylinder("HatBrim", 0.77, 0.095, Vector3.new(0, 1.285, 0.25), PALETTE.white)
		part("Hat", Vector3.new(0.62, 0.22, 0.62), Vector3.new(0, 1.375, 0.25), PALETTE.white, "Ball")
		cylinder("HatRibbon", 0.66, 0.06, Vector3.new(0, 1.33, 0.25), PALETTE.navy)
		part("HatBadge", Vector3.new(0.11, 0.11, 0.035), Vector3.new(0, 1.365, 0.578), PALETTE.gold, "Ball")
	elseif recipe == "Bucket" then
		cylinder("Helmet", 0.77, 0.39, Vector3.new(0, 1.345, 0.25), PALETTE.silver, Enum.Material.Metal)
		cylinder("BucketRim", 0.89, 0.07, Vector3.new(0, 1.145, 0.25), PALETTE.steel, Enum.Material.Metal)
		part("HandleTop", Vector3.new(0.76, 0.055, 0.055), Vector3.new(0, 1.68, 0.25), PALETTE.steel)
		for _, side in {-1, 1} do
			part("HandleSide" .. side, Vector3.new(0.055, 0.29, 0.055), Vector3.new(side * 0.36, 1.55, 0.25), PALETTE.steel)
			part("BucketRivet" .. side, Vector3.new(0.055, 0.10, 0.10), Vector3.new(side * 0.39, 1.40, 0.25), PALETTE.gold, "Ball")
		end
	elseif recipe == "Viking" then
		part("Helmet", Vector3.new(0.79, 0.39, 0.76), Vector3.new(0, 1.30, 0.25), PALETTE.steel, "Ball", nil, Enum.Material.Metal)
		cylinder("HelmetBand", 0.81, 0.07, Vector3.new(0, 1.14, 0.25), PALETTE.gold)
		for _, side in {-1, 1} do
			part("HornBase" .. side, Vector3.new(0.33, 0.15, 0.17), Vector3.new(side * 0.43, 1.39, 0.25), PALETTE.ivory,
				nil, CFrame.Angles(0, 0, side * 0.34))
			part("HornTip" .. side, Vector3.new(0.14, 0.37, 0.17), Vector3.new(side * 0.59, 1.57, 0.25), PALETTE.ivory,
				"Wedge", CFrame.Angles(0, side * math.pi / 2, side * -0.30))
		end
		part("Belt", Vector3.new(0.77, 0.105, 0.12), Vector3.new(0, 0.44, 0.48), PALETTE.wood)
		part("BeltBuckle", Vector3.new(0.14, 0.15, 0.035), Vector3.new(0, 0.44, 0.553), PALETTE.gold)
	elseif recipe == "Knight" then
		part("Helmet", Vector3.new(0.78, 0.41, 0.73), Vector3.new(0, 1.30, 0.25), PALETTE.silver, "Ball", nil, Enum.Material.Metal)
		part("HelmetBrow", Vector3.new(0.70, 0.08, 0.11), Vector3.new(0, 1.135, 0.59), PALETTE.steel)
		for _, side in {-1, 1} do
			part("CheekGuard" .. side, Vector3.new(0.09, 0.30, 0.40), Vector3.new(side * 0.35, 1.015, 0.23), PALETTE.silver)
		end
		part("RedCrest", Vector3.new(0.18, 0.37, 0.56), Vector3.new(0, 1.58, 0.18), PALETTE.red, "Wedge", CFrame.Angles(0, math.pi, 0))
		part("Shield", Vector3.new(0.12, 0.70, 0.57), Vector3.new(-0.55, 0.56, 0.05), PALETTE.navy, "Ball")
		part("ShieldBoss", Vector3.new(0.065, 0.19, 0.19), Vector3.new(-0.622, 0.56, 0.05), PALETTE.gold, "Ball")
		part("SwordBlade", Vector3.new(0.11, 0.65, 0.075), Vector3.new(0.59, 0.86, 0.04), PALETTE.silver, nil, CFrame.Angles(0, 0, -0.12), Enum.Material.Metal)
		part("SwordGrip", Vector3.new(0.10, 0.18, 0.10), Vector3.new(0.54, 0.44, 0.04), PALETTE.wood)
		part("SwordGuard", Vector3.new(0.30, 0.06, 0.14), Vector3.new(0.55, 0.54, 0.04), PALETTE.gold)
	elseif recipe == "Wizard" then
		local purple = C(102, 65, 191)
		cylinder("HatBrim", 0.97, 0.075, Vector3.new(0, 1.29, 0.25), purple)
		cylinder("Hat", 0.62, 0.24, Vector3.new(0, 1.43, 0.25), purple)
		cylinder("HatCrown", 0.41, 0.23, Vector3.new(-0.015, 1.645, 0.25), purple)
		part("HatTip", Vector3.new(0.25, 0.41, 0.27), Vector3.new(-0.075, 1.92, 0.25), purple,
			"Wedge", CFrame.Angles(0, 0, -0.28))
		cylinder("GoldHatBand", 0.645, 0.065, Vector3.new(0, 1.355, 0.25), PALETTE.gold)
		part("Staff", Vector3.new(0.10, 1.25, 0.10), Vector3.new(0.57, 0.76, 0.08), PALETTE.wood,
			nil, CFrame.Angles(0, 0, -0.12))
		part("StaffCrystal", Vector3.new(0.28, 0.34, 0.28), Vector3.new(0.655, 1.43, 0.08), C(131, 242, 246),
			nil, CFrame.Angles(0, math.pi / 4, math.pi / 4), Enum.Material.Neon)
		part("HatStarA", Vector3.new(0.15, 0.15, 0.025), Vector3.new(0.09, 1.47, 0.565), PALETTE.gold,
			nil, CFrame.Angles(0, 0, math.pi / 4))
		part("HatStarB", Vector3.new(0.065, 0.23, 0.028), Vector3.new(0.09, 1.47, 0.568), PALETTE.gold)
	elseif recipe == "Dragon" then
		local membrane = C(247, 158, 100)
		for _, side in {-1, 1} do
			part("DragonWing" .. side, Vector3.new(0.52, 0.63, 0.12), Vector3.new(side * 0.56, 0.83, -0.15), membrane,
				"Wedge", CFrame.Angles(0, side * 0.15, side * -0.13))
			part("WingTip" .. side, Vector3.new(0.32, 0.46, 0.10), Vector3.new(side * 0.76, 1.13, -0.16), membrane,
				"Wedge", CFrame.Angles(0, side * math.pi, side * -0.12))
			part("WingBone" .. side, Vector3.new(0.09, 0.77, 0.15), Vector3.new(side * 0.62, 0.91, -0.165), wingColor,
				nil, CFrame.Angles(0, 0, side * -0.31))
			part("DragonHorn" .. side, Vector3.new(0.14, 0.32, 0.17), Vector3.new(side * 0.235, 1.39, 0.15), PALETTE.ivory,
				"Wedge", CFrame.Angles(-0.3, 0, side * -0.23))
		end
		for index = 1, 3 do
			part("BackSpine" .. index, Vector3.new(0.10, 0.22 - index * 0.025, 0.18),
				Vector3.new(0, 0.84 - index * 0.08, -0.22 - index * 0.20), PALETTE.gold, "Wedge", CFrame.Angles(0, math.pi, 0))
		end
	end

	local boundsCF, bounds = model:GetBoundingBox()
	local top = boundsCF.Position.Y + bounds.Y / 2
	model:SetAttribute("VisualHeight", top)
	model:SetAttribute("VisualWidth", bounds.X)
	model:SetAttribute("VisualDepth", bounds.Z)
	model:SetAttribute("PartCount", #model:GetChildren())
	addTag(body, definition.name, top - body.Position.Y + 0.43)

	local phase = 0
	for index = 1, #id do phase += string.byte(id, index) * 0.071 end
	poses[model] = {foot = foot, facing = Vector3.zAxis, lastAt = os.clock(), phase = phase % (math.pi * 2),
		rootHeight = 0.45 * size, size = size, flash = false, colors = partColors}
	model.Destroying:Once(function() poses[model] = nil end)
	model:PivotTo(CFrame.new(foot + Vector3.new(0, 0.45 * size, 0)))
	model.Parent = parent
	return model
end


-- Physical actors use Roblox's -Z forward convention. The static recipes above
-- retain their +Z convention so roller/viewport previews keep their old poses.
function PetView.CreateRig(parent: Instance, id: string, species: string, stars: number, foot: Vector3): Model
	local imported = BlenderPetView.Create(parent, id, species, stars, foot, true)
	if imported then
		addTag(imported.PrimaryPart, Catalog[species].name, imported:GetAttribute("VisualHeight") - imported:GetAttribute("FootOffset") + 0.43)
		return imported
	end
	local model = PetView.Create(parent, id, species, stars, foot)
	local size = model:GetAttribute("Size") :: number
	-- Match the imported rig's low-obstacle clearance without raising the art.
	local footOffset = size * 0.75
	local body = model:FindFirstChild("Body") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	model:PivotTo(CFrame.new(foot + Vector3.new(0, size * 0.45, 0)) * CFrame.Angles(0, math.pi, 0))

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(0.72, 0.72, 0.85) * size
	root.CFrame = CFrame.new(foot + Vector3.new(0, footOffset, 0))
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide, root.CanTouch, root.CanQuery = true, false, true
	root.RootPriority = 127
	root.CustomPhysicalProperties = PhysicalProperties.new(1, 0.3, 0, 1, 0)
	root.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("FootOffset", footOffset)
	model:SetAttribute("RigVersion", 1)
	model:SetAttribute("DuckRig", true)
	model:SetAttribute("MovementBlocked", false)
	model:SetAttribute("Moving", false)
	model:SetAttribute("AttackSerial", 0)

	local function motor(name: string, parentPart: BasePart, child: BasePart): Motor6D
		local joint = Instance.new("Motor6D")
		joint.Name = name
		joint.Part0, joint.Part1 = parentPart, child
		joint.C0 = parentPart.CFrame:ToObjectSpace(child.CFrame)
		joint.C1 = CFrame.identity
		joint.Parent = parentPart
		return joint
	end
	local joined: {[BasePart]: boolean} = {[root] = true, [body] = true, [head] = true}
	motor("Root", root, body)
	motor("Neck", body, head)
	local appendages: {[string]: BasePart} = {}
	local feet: {[string]: BasePart} = {}
	for _, side in {-1, 1} do
		local sideName = if side == 1 then "Left" else "Right"
		local wing = (model:FindFirstChild("Wing" .. side) or model:FindFirstChild("DragonWing" .. side)) :: BasePart?
		local footPart = model:FindFirstChild("Foot" .. side) :: BasePart?
		if wing then
			motor("Wing" .. sideName, body, wing)
			joined[wing] = true
			appendages[tostring(side)] = wing
		end
		if footPart then
			motor("Foot" .. sideName, body, footPart)
			joined[footPart] = true
			feet[tostring(side)] = footPart
		end
	end

	for _, child in model:GetChildren() do
		if not child:IsA("BasePart") or joined[child] then continue end
		local owner = body
		local name = child.Name
		-- Accessories follow the animated anatomical part they belong to.
		local wingSide = string.match(name, "^WingTip(-?1)$") or string.match(name, "^WingBone(-?1)$")
			or string.match(name, "^BlueWingFlash(-?1)$")
		local footSide = string.match(name, "^ToeOuter(-?1)$") or string.match(name, "^ToeInner(-?1)$") or string.match(name, "^Leg(-?1)$")
		if footSide and feet[footSide] then
			owner = feet[footSide]
		elseif wingSide and appendages[wingSide] then
			owner = appendages[wingSide]
		elseif string.match(name, "^Bill") or string.match(name, "^Eye") or string.match(name, "^Hat")
			or string.match(name, "^Helmet") or string.match(name, "^Horn") or string.match(name, "^Handle")
			or string.match(name, "^Bucket") or string.match(name, "^Tuft") or string.match(name, "^Cheek")
			or string.match(name, "^DragonHorn") or string.match(name, "^Comb") or name == "Wattle" or name == "RedCrest" or name == "GoldHatBand" then
			owner = head
		end
		local weld = Instance.new("WeldConstraint")
		weld.Name = "AccessoryJoint"
		weld.Part0, weld.Part1 = owner, child
		weld.Parent = child
	end

	local tag = body:FindFirstChild("Tag") :: BillboardGui?
	if tag then
		tag.StudsOffset -= Vector3.new(0, size * 0.3, 0)
		tag.Parent = root
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth, humanoid.Health = 100, 100
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoJumpEnabled = false
	humanoid.HipHeight = footOffset - root.Size.Y / 2
	humanoid.AutoRotate = true
	humanoid.Parent = model
	for _, state in {Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Seated} do
		humanoid:SetStateEnabled(state, false)
	end
	local animator = Instance.new("Animator")
	animator.Parent = humanoid
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = false
			if child ~= root then
				child.Massless = true
				child.CanCollide, child.CanTouch, child.CanQuery = false, false, false
			end
		end
	end
	CollectionService:AddTag(model, "DuckRig")
	return model
end

function PetView.Move(model: Model, foot: Vector3, direction: Vector3?, hop: number?)
	-- A physical actor must only be driven by its Humanoid, never a visual lerp.
	if model:GetAttribute("DuckRig") == true then return end
	if model:GetAttribute("SkinnedChicken") then BlenderPetView.Move(model, foot, direction, hop) return end
	local pose = poses[model]
	if not pose or not model.PrimaryPart then return end
	local now = os.clock()
	local dt = math.clamp(now - pose.lastAt, 0, 0.2)
	local distance = (Vector3.new(foot.X, 0, foot.Z) - Vector3.new(pose.foot.X, 0, pose.foot.Z)).Magnitude
	local moving = distance > 0.002 and distance < pose.size * 4
	if direction then
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude > 0.01 then pose.facing = flat.Unit end
	end
	pose.phase += if moving then math.min(distance / pose.size * 13, 1.8) else dt * 1.5
	local reduced = model:GetAttribute("ReducedMotion") == true
	local rock = if reduced then 0 else math.sin(pose.phase) * (if moving then 0.065 else 0.007)
	local bounce = if reduced then 0 else math.abs(math.sin(pose.phase)) * pose.size * (if moving then 0.027 else 0.004)
	local lift = if reduced then 0 else math.max(hop or 0, 0) + bounce
	local position = foot + Vector3.new(0, pose.rootHeight + lift, 0)
	-- A Roblox lookAt frame looks down -Z; subtracting the facing vector puts
	-- this model's +Z bill toward its actual direction of travel.
	local frame = CFrame.lookAt(position, position - pose.facing) * CFrame.Angles(0, 0, rock)
	model:PivotTo(frame)
	pose.foot, pose.lastAt = foot, now
end

function PetView.Level(model, level, giantSize)
	if model:GetAttribute("Level")==level and model:GetAttribute("MergeVisualScale")
		and model:GetAttribute("GiantSize")==giantSize
		and model:GetAttribute("AppliedBaseVisualScale")== (model:GetAttribute("BaseVisualScale") or ChickenGrowth.BaseScale)
		and model:GetAttribute("FieldVisualScale")==nil
		and model:GetAttribute("AppliedFieldVisualScale")==nil then return end
	local ratio = ChickenGrowth.Apply(model, level, giantSize)
	local pose = poses[model]
	if pose and ratio ~= 1 then pose.rootHeight *= ratio; pose.size *= ratio end
	model:SetAttribute("Level",level)
	local label=model:FindFirstChild("NameLabel",true)
	local species=model:GetAttribute("Species")
	if label and species and Catalog[species] then label.Text=if model:GetAttribute("ChickenKing") then "CHICKEN KING" else (if giantSize then Giant.Kind(giantSize).." " else "")..Catalog[species].name.." · Lv. "..level end
end

function PetView.Health(model: Model, hp: number, maxHp: number)
	local primary = model.PrimaryPart
	if not primary then return end
	local tag = primary:FindFirstChild("Tag") :: BillboardGui?
	if not tag then return end
	local bar = tag:FindFirstChild("Health") :: Frame
	local fill = bar:FindFirstChild("Fill") :: Frame
	local maximum = if maxHp == maxHp then math.max(0, maxHp) else 0
	local current = if hp == hp then math.clamp(hp, 0, maximum) else 0
	local amount = if maximum > 0 then current / maximum else 0
	(tag:FindFirstChild("NameLabel") :: TextLabel).Visible = model:GetAttribute("ChickenKing") == true
	(tag:FindFirstChild("Cash") :: TextLabel).Visible = false
	tag.MaxDistance = if model:GetAttribute("ChickenKing") then 180 else 105
	bar.Visible = amount > 0
	fill.Size = UDim2.fromScale(amount, 1)
	(bar:FindFirstChild("Value") :: TextLabel).Text = string.format("%.0f/%.0f", math.ceil(current), math.ceil(maximum))
	-- Identical chicken variants need a stable side cue during a crowded fight.
	-- Bar length communicates remaining health; team color must not flip at low HP.
	local side=model:GetAttribute("Side")
	fill.BackgroundColor3=if side=="A" then UIColors.Money elseif side=="B" then UIColors.Danger
		elseif amount<0.3 then UIColors.Danger elseif amount<0.6 then UIColors.Rewards else UIColors.Purchase
end

-- Direct flock income is shown in the HUD. Home birds need no cash-collection pill.
-- Preserve the small tag-reset API used when switching actors between home and battle.
function PetView.Cash(model: Model, _amount: number, enabled: boolean?)
	local primary = model.PrimaryPart
	if not primary then return end
	local tag = primary:FindFirstChild("Tag") :: BillboardGui?
	if not tag then return end
	local cash = tag:FindFirstChild("Cash") :: TextLabel
	local label = tag:FindFirstChild("NameLabel") :: TextLabel
	(tag:FindFirstChild("Health") :: Frame).Visible = false
	cash.Visible = false
	cash.Text = ""
	label.Visible = enabled == false
	tag.MaxDistance = 38
end

PetView.SetCash = PetView.Cash

-- A transition-only operation: callers can pass the current hit-flash state
-- each frame without rewriting every part's color on every render step.
function PetView.Flash(model: Model, active: boolean)
	if model:GetAttribute("SkinnedChicken") then BlenderPetView.Flash(model, active) return end
	local pose = poses[model]
	local colors: {[BasePart]: Color3}
	if pose then
		if pose.flash == active then return end
		pose.flash = active
		colors = pose.colors
	else
		local state = replicatedFlashes[model]
		if not state then
			state = {active = false, colors = {}}
			for _, child in model:GetDescendants() do
				if child:IsA("BasePart") then state.colors[child] = child.Color end
			end
			replicatedFlashes[model] = state
			model.Destroying:Once(function() replicatedFlashes[model] = nil end)
		end
		if state.active == active then return end
		state.active = active
		colors = state.colors
	end
	for item, original in colors do
		if item.Parent then item.Color = if active then original:Lerp(Color3.new(1, 1, 1), 0.72) else original end
	end
end

return PetView
