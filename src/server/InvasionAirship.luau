--!strict
-- October 14 Invasions: the Chicken King's loyalist airship and its parachute
-- supply crates. Chunky code-built props in the map's style (Plastic blocks with
-- the map's stud MaterialVariants); no physics, prompts or collisions.
-- All motion is TweenService only.
local TweenService = game:GetService("TweenService")
local Airship = {}

Airship.PURPLE = Color3.fromRGB(112, 46, 168)
Airship.DEEP = Color3.fromRGB(78, 30, 122)
Airship.GOLD = Color3.fromRGB(255, 190, 40)
Airship.WOOD = Color3.fromRGB(150, 92, 48)
Airship.DARKWOOD = Color3.fromRGB(104, 62, 34)
Airship.DARK = Color3.fromRGB(44, 38, 52)
Airship.WHITE = Color3.fromRGB(245, 240, 250)
Airship.GEM = Color3.fromRGB(230, 60, 90)
local PURPLE, DEEP, GOLD, WOOD, DARKWOOD, DARK, WHITE, GEM =
	Airship.PURPLE, Airship.DEEP, Airship.GOLD, Airship.WOOD, Airship.DARKWOOD, Airship.DARK, Airship.WHITE, Airship.GEM

-- October 20 (owner): the map's stud MaterialVariants, matching MissionSite.Studify:
-- studs when the part's middle dimension is at least 2, the weld pattern from 0.8.
local STUDS, WELD = "Studs 2x2 Plastic", "Weld 2x2 Plastic"

-- One chunky prop block. `kind` may be "WedgePart"; `studs=false` keeps it plain.
function Airship.Block(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, kind: string?, studs: boolean?): BasePart
	local item = Instance.new(kind or "Part") :: BasePart
	item.Name, item.Size, item.Color, item.Material = name, size, color, Enum.Material.Plastic
	item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch, item.CastShadow = true, false, false, false, true
	item.TopSurface, item.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	item.CFrame = cframe
	if studs ~= false and not kind then
		local side = size.X + size.Y + size.Z - math.max(size.X, size.Y, size.Z) - math.min(size.X, size.Y, size.Z)
		if side >= 2 then item.MaterialVariant = STUDS elseif side >= 0.8 then item.MaterialVariant = WELD end
	end
	item.Parent = parent
	return item
end
local block = Airship.Block

-- A thin rope/strut from `a` to `b`.
function Airship.Strut(parent: Instance, a: Vector3, b: Vector3, color: Color3, width: number?): BasePart
	local length = (b - a).Magnitude
	return block(parent, "Rope", Vector3.new(width or 0.25, width or 0.25, length), CFrame.lookAt((a + b) / 2, b), color, nil, false)
end

-- A blocky crown in the XY plane of `cframe` (points toward +Y, facing -Z).
function Airship.Crown(parent: Instance, cframe: CFrame, scale: number)
	local s = scale
	block(parent, "CrownBase", Vector3.new(6 * s, 1.6 * s, 0.5), cframe * CFrame.new(0, 0, 0), GOLD, nil, false)
	block(parent, "CrownBand", Vector3.new(6.4 * s, 0.5 * s, 0.6), cframe * CFrame.new(0, -0.8 * s, 0), DARKWOOD, nil, false)
	for i, x in {-2.3, 0, 2.3} do
		local height = if i == 2 then 2.6 else 1.9
		block(parent, "CrownPoint", Vector3.new(1.4 * s, height * s, 0.5), cframe * CFrame.new(x * s, (0.8 + height / 2) * s, 0), GOLD, nil, false)
		block(parent, "CrownTip", Vector3.new(0.8 * s, 0.8 * s, 0.7), cframe * CFrame.new(x * s, (0.8 + height + 0.3) * s, 0), GOLD, nil, false)
	end
	block(parent, "CrownGem", Vector3.new(1.2 * s, 1 * s, 0.7), cframe * CFrame.new(0, 0, 0), GEM, nil, false)
end

-- Built at the origin facing -Z (nose), the pivot at the balloon's centre.
function Airship.Build(): Model
	local model = Instance.new("Model")
	model.Name = "LoyalistAirship"
	local o = CFrame.new(0, 0, 0)
	-- Stepped balloon: overlapping blocks read as a round envelope in the map's voxel style.
	local layers = {Vector3.new(12, 10, 30), Vector3.new(9, 7, 37), Vector3.new(15, 6.5, 24), Vector3.new(8, 12.4, 24)}
	local core = block(model, "Envelope", layers[1], o, PURPLE)
	model.PrimaryPart = core
	for i = 2, #layers do block(model, "Envelope", layers[i], o, if i == 3 then DEEP else PURPLE) end
	block(model, "Nose", Vector3.new(5, 4.6, 1.6), o * CFrame.new(0, 0, -19.2), GOLD)
	block(model, "Tail", Vector3.new(5, 4.6, 1.6), o * CFrame.new(0, 0, 19.2), DEEP)
	-- Gold bands follow the same stepped cross-section.
	for _, z in {-9, 0, 9} do
		for i, layer in layers do
			if i == 2 then continue end
			block(model, "Band", Vector3.new(layer.X + 0.35, layer.Y + 0.35, 1.3), o * CFrame.new(0, 0, z), GOLD, nil, false)
		end
	end
	-- The King's crown on both flanks.
	for _, side in {-1, 1} do
		Airship.Crown(model, o * CFrame.new(side * 7.85, -0.6, -4.5) * CFrame.Angles(0, side * math.pi / 2, 0), 0.75)
		Airship.Crown(model, o * CFrame.new(side * 7.85, -0.6, 4.5) * CFrame.Angles(0, side * math.pi / 2, 0), 0.75)
	end
	-- Tail fins: purple with a gold edge.
	block(model, "FinTop", Vector3.new(0.9, 6, 6), o * CFrame.new(0, 8.6, 16), PURPLE, nil, false)
	block(model, "FinTopEdge", Vector3.new(1.1, 1, 6.4), o * CFrame.new(0, 11.6, 16), GOLD, nil, false)
	block(model, "FinBottom", Vector3.new(0.9, 4, 5), o * CFrame.new(0, -7.6, 16.5), PURPLE, nil, false)
	for _, side in {-1, 1} do
		block(model, "FinSide", Vector3.new(6, 0.9, 6), o * CFrame.new(side * 9.5, 0, 16), PURPLE, nil, false)
		block(model, "FinSideEdge", Vector3.new(1, 1.1, 6.4), o * CFrame.new(side * 12.5, 0, 16), GOLD, nil, false)
	end
	-- Wooden gondola: a little boat hanging on ropes.
	local hull = o * CFrame.new(0, -11, 0)
	block(model, "Keel", Vector3.new(4.4, 1, 12), hull * CFrame.new(0, -1.7, 0), DARKWOOD)
	block(model, "Hull", Vector3.new(6.6, 2.6, 14), hull * CFrame.new(0, 0, 0), WOOD)
	block(model, "Bow", Vector3.new(6.6, 2.6, 3), hull * CFrame.new(0, 0, -8.5) * CFrame.Angles(0, 0, math.pi), WOOD, "WedgePart")
	block(model, "HullStripe", Vector3.new(6.9, 0.5, 14.2), hull * CFrame.new(0, 0.5, 0), PURPLE, nil, false)
	block(model, "Deck", Vector3.new(6, 0.3, 13.6), hull * CFrame.new(0, 1.45, 0), Color3.fromRGB(196, 140, 84))
	for _, side in {-1, 1} do
		block(model, "Rail", Vector3.new(0.45, 0.4, 14), hull * CFrame.new(side * 3.1, 2.9, 0), GOLD, nil, false)
		for z = -6, 6, 3 do block(model, "RailPost", Vector3.new(0.45, 1.4, 0.45), hull * CFrame.new(side * 3.1, 2.2, z), DARKWOOD, nil, false) end
		-- Engine pods with a spinning-propeller blur.
		local engine = block(model, "Engine", Vector3.new(1.8, 1.8, 3.4), hull * CFrame.new(side * 4.4, -0.2, 4.6), DARK)
		block(model, "EngineCap", Vector3.new(2.1, 0.5, 3.6), hull * CFrame.new(side * 4.4, 0.8, 4.6), GOLD, nil, false)
		local blur = block(model, "PropellerBlur", Vector3.new(0.2, 4.6, 4.6), hull * CFrame.new(side * 4.4, -0.2, 6.5) * CFrame.Angles(0, math.pi / 2, 0), WHITE, nil, false)
		blur.Shape, blur.Transparency, blur.CastShadow = Enum.PartType.Cylinder, 0.65, false
		local exhaust = Instance.new("Smoke")
		exhaust.Color, exhaust.Opacity, exhaust.RiseVelocity, exhaust.Size = Color3.fromRGB(120, 110, 130), 0.12, 2, 0.6
		exhaust.Parent = engine
	end
	block(model, "Cabin", Vector3.new(4, 2.4, 4.4), hull * CFrame.new(0, 2.8, 2.6), PURPLE)
	block(model, "CabinRoof", Vector3.new(4.8, 0.6, 5.2), hull * CFrame.new(0, 4.3, 2.6), GOLD)
	for _, side in {-1, 1} do block(model, "Window", Vector3.new(0.2, 0.9, 1.4), hull * CFrame.new(side * 2.05, 3, 2.6), Color3.fromRGB(255, 226, 140), nil, false).Material = Enum.Material.Neon end
	-- Stern flag.
	block(model, "Mast", Vector3.new(0.4, 5, 0.4), hull * CFrame.new(0, 3.9, 6.4), DARKWOOD, nil, false)
	block(model, "Flag", Vector3.new(0.2, 1.8, 2.8), hull * CFrame.new(0, 5.4, 7.9), PURPLE, nil, false)
	block(model, "FlagTrim", Vector3.new(0.25, 0.4, 2.8), hull * CFrame.new(0, 4.4, 7.9), GOLD, nil, false)
	-- Ropes from the deck corners up to the balloon.
	for _, x in {-2.6, 2.6} do
		for _, z in {-5, 5} do Airship.Strut(model, (hull * CFrame.new(x, 1.5, z)).Position, Vector3.new(x * 0.8, -5.2, z * 1.4), DARK) end
	end
	return model
end

-- The local point under the gondola where crates are released.
Airship.HatchOffset = Vector3.new(0, -13.5, 0)
Airship.HoverHeight = 36
Airship.InboundSeconds = 3

-- Fly in, hover over `landing` for `hoverSeconds`, then fly away and clean up.
-- `seaward` is the unit direction the ship arrives from (and leaves toward).
function Airship.Arrive(parent: Instance, landing: Vector3, seaward: Vector3, hoverSeconds: number): Model
	local model = Airship.Build()
	local flat = Vector3.new(seaward.X, 0, seaward.Z)
	local away = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, 1)
	local hover = landing + Vector3.new(0, Airship.HoverHeight, 0)
	local start = hover + away * 260 + Vector3.new(0, 30, 0)
	local finish = hover + away * 320 + Vector3.new(0, 70, 0)
	local function facing(at: Vector3, toward: Vector3): CFrame
		return CFrame.lookAt(at, Vector3.new(toward.X, at.Y, toward.Z))
	end
	model:PivotTo(facing(start, hover))
	model.Parent = parent
	local driver = Instance.new("CFrameValue")
	driver.Value = facing(start, hover)
	driver.Changed:Connect(function(value) if model.Parent then model:PivotTo(value) end end)
	local inbound = TweenService:Create(driver, TweenInfo.new(Airship.InboundSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Value = facing(hover, hover - away)})
	inbound:Play()
	inbound.Completed:Once(function()
		-- A gentle bob while the crates go down.
		local bob = TweenService:Create(driver, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{Value = facing(hover, hover - away) + Vector3.new(0, 1.2, 0)})
		bob:Play()
		task.delay(hoverSeconds, function()
			bob:Cancel()
			if not model.Parent then return end
			local outbound = TweenService:Create(driver, TweenInfo.new(3.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Value = facing(finish, finish + away)})
			outbound:Play()
			outbound.Completed:Once(function() model:Destroy(); driver:Destroy() end)
		end)
	end)
	return model
end

-- A loyalist supply crate under a striped parachute, built at the origin
-- (crate bottom at y=0). Returns the model plus its parachute and lid groups.
local function crateModel(): (Model, Model, Model)
	local model = Instance.new("Model")
	model.Name = "SupplyCrate"
	local base = block(model, "Crate", Vector3.new(2.8, 2.6, 2.8), CFrame.new(0, 1.3, 0), WOOD)
	model.PrimaryPart = base
	for _, y in {0.45, 2.15} do block(model, "Band", Vector3.new(3, 0.45, 3), CFrame.new(0, y, 0), PURPLE, nil, false) end
	for _, x in {-1.3, 1.3} do
		for _, z in {-1.3, 1.3} do block(model, "Corner", Vector3.new(0.4, 2.7, 0.4), CFrame.new(x, 1.3, z), DARKWOOD, nil, false) end
	end
	for _, side in {-1, 1} do block(model, "Seal", Vector3.new(0.9, 0.9, 0.2), CFrame.new(0, 1.3, side * 1.45), GOLD, nil, false) end
	local lid = Instance.new("Model")
	lid.Name = "Lid"
	lid.PrimaryPart = block(lid, "Lid", Vector3.new(3.1, 0.45, 3.1), CFrame.new(0, 2.85, 0), PURPLE)
	block(lid, "LidTrim", Vector3.new(1.2, 0.2, 1.2), CFrame.new(0, 3.15, 0), GOLD, nil, false)
	lid.Parent = model
	local chute = Instance.new("Model")
	chute.Name = "Parachute"
	chute.PrimaryPart = block(chute, "Canopy", Vector3.new(8, 0.6, 8), CFrame.new(0, 9.5, 0), PURPLE, nil, false)
	block(chute, "Canopy", Vector3.new(6.4, 0.6, 6.4), CFrame.new(0, 10.1, 0), WHITE, nil, false)
	block(chute, "Canopy", Vector3.new(4.2, 0.6, 4.2), CFrame.new(0, 10.7, 0), PURPLE)
	block(chute, "Canopy", Vector3.new(1.6, 0.5, 1.6), CFrame.new(0, 11.25, 0), GOLD, nil, false)
	for _, x in {-1, 1} do
		for _, z in {-1, 1} do
			block(chute, "Skirt", Vector3.new(2, 0.9, 2), CFrame.new(x * 3.3, 9.1, z * 3.3), if (x * z) > 0 then WHITE else PURPLE, nil, false)
			Airship.Strut(chute, Vector3.new(x * 1.2, 3.1, z * 1.2), Vector3.new(x * 3.4, 9, z * 3.4), WHITE, 0.15)
		end
	end
	chute.Parent = model
	return model, chute, lid
end

local function fadeGroup(group: Instance, seconds: number, offset: Vector3?)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, item in group:GetDescendants() do
		if item:IsA("BasePart") then
			local goal: {[string]: any} = {Transparency = 1}
			if offset then goal.CFrame = item.CFrame + offset end
			TweenService:Create(item, info, goal):Play()
		elseif item:IsA("Texture") then
			TweenService:Create(item, info, {Transparency = 1}):Play()
		end
	end
	task.delay(seconds, function() group:Destroy() end)
end

-- A puff of chunky dust blocks where a crate lands.
local function dust(parent: Instance, at: Vector3)
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2 + math.random() * 0.4
		local size = 0.6 + math.random() * 0.6
		local puff = block(parent, "Dust", Vector3.new(size, size, size), CFrame.new(at + Vector3.new(0, 0.4, 0)), Color3.fromRGB(214, 178, 128), nil, false)
		puff.CastShadow = false
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (2.6 + math.random() * 1.6) + Vector3.new(0, 1 + math.random(), 0)
		TweenService:Create(puff, info, {CFrame = CFrame.new(at + out) * CFrame.Angles(math.random(), math.random(), 0), Transparency = 1, Size = puff.Size * 1.6}):Play()
		task.delay(0.75, function() puff:Destroy() end)
	end
end

-- Drop crates from `from` down to each spot over `fallSeconds`. On landing the
-- parachute folds away, the lid pops and dust puffs; the open crate stays in
-- `parent` (the landing camp) until it is cleaned up with it.
function Airship.DropCrates(parent: Instance, from: Vector3, spots: {Vector3}, fallSeconds: number)
	for i, spot in spots do
		local model, chute, lid = crateModel()
		local yaw = math.random() * math.pi * 2
		-- Released close together under the hatch, fanning out on the way down.
		local release = from + Vector3.new(spot.X - from.X, 0, spot.Z - from.Z) * 0.3
		model:PivotTo(CFrame.new(release) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 1.3, 0))
		model.Parent = parent
		local driver = Instance.new("CFrameValue")
		driver.Value = CFrame.new(release) * CFrame.Angles(0, yaw, 0)
		driver.Changed:Connect(function(value) if model.Parent then model:PivotTo(value * CFrame.new(0, 1.3, 0)) end end)
		local fall = TweenService:Create(driver, TweenInfo.new(fallSeconds + (i % 3) * 0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{Value = CFrame.new(spot) * CFrame.Angles(0, yaw + 0.6, 0)})
		fall:Play()
		fall.Completed:Once(function()
			driver:Destroy()
			if not model.Parent then return end
			dust(parent, spot)
			fadeGroup(chute, 0.6, Vector3.new(0, -4, 0))
			local pop = lid.PrimaryPart and lid.PrimaryPart.CFrame
			if pop then
				for _, item in lid:GetDescendants() do
					if item:IsA("BasePart") then
						TweenService:Create(item, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{CFrame = item.CFrame * CFrame.new(1.4, 2.4, 0) * CFrame.Angles(0, 0, -1.2)}):Play()
					end
				end
				task.delay(0.45, function() fadeGroup(lid, 0.4) end)
			end
		end)
	end
end

return Airship
