--!strict
-- October 14 Invasions: the Chicken King's loyalist airship. A chunky code-built
-- prop (no physics, no prompts) that flies in from the sea, hovers over a landing
-- zone while the loyalists drop, then flies away. Motion is TweenService only.
local TweenService = game:GetService("TweenService")
local Airship = {}

local PURPLE = Color3.fromRGB(112, 46, 168)
local GOLD = Color3.fromRGB(255, 190, 40)
local WOOD = Color3.fromRGB(122, 78, 44)
local DARK = Color3.fromRGB(40, 34, 48)

local function part(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
	local item = Instance.new("Part")
	item.Name, item.Size, item.Color = name, size, color
	item.Material = material or Enum.Material.SmoothPlastic
	item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch, item.CastShadow = true, false, false, false, true
	item.CFrame = offset
	item.Parent = model
	return item
end

local function ellipsoid(model: Model, name: string, size: Vector3, offset: CFrame, color: Color3)
	local item = part(model, name, size, offset, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = item
	return item
end

-- Built at the origin facing -Z; callers pivot it into place.
function Airship.Build(): Model
	local model = Instance.new("Model")
	model.Name = "LoyalistAirship"
	local envelope = ellipsoid(model, "Envelope", Vector3.new(14, 13, 38), CFrame.new(0, 10, 0), PURPLE)
	model.PrimaryPart = envelope
	-- Gold bands around the balloon.
	for _, z in {-9, 0, 9} do
		ellipsoid(model, "Band", Vector3.new(14.6, 13.6, 1.6), CFrame.new(0, 10, z), GOLD)
	end
	-- Tail fins.
	part(model, "FinTop", Vector3.new(0.8, 7, 6), CFrame.new(0, 17, 17), GOLD)
	part(model, "FinBottom", Vector3.new(0.8, 6, 6), CFrame.new(0, 3.5, 17), GOLD)
	part(model, "FinLeft", Vector3.new(7, 0.8, 6), CFrame.new(-6.5, 10, 17), GOLD)
	part(model, "FinRight", Vector3.new(7, 0.8, 6), CFrame.new(6.5, 10, 17), GOLD)
	-- Gondola with rails, ropes and a propeller.
	part(model, "Gondola", Vector3.new(7, 3, 14), CFrame.new(0, 1, 0), WOOD, Enum.Material.WoodPlanks)
	part(model, "RailLeft", Vector3.new(0.5, 1, 14), CFrame.new(-3.5, 3, 0), GOLD)
	part(model, "RailRight", Vector3.new(0.5, 1, 14), CFrame.new(3.5, 3, 0), GOLD)
	for _, x in {-2.5, 2.5} do
		for _, z in {-5, 5} do part(model, "Rope", Vector3.new(0.3, 5, 0.3), CFrame.new(x, 4.5, z), DARK) end
	end
	part(model, "Hub", Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 1, 7.8), DARK)
	local blade = part(model, "Propeller", Vector3.new(6, 0.6, 0.4), CFrame.new(0, 1, 8.6), DARK)
	blade.Name = "Propeller"
	-- A crown banner on each side marks the King's loyalists.
	for _, side in {-1, 1} do
		part(model, "Crest", Vector3.new(0.4, 3.2, 5), CFrame.new(side * 7.1, 10, -3), GOLD, Enum.Material.Neon)
	end
	return model
end

-- Fly in, hover over `landing` for `hoverSeconds`, then fly away and clean up.
-- `seaward` is the unit direction the ship arrives from (and leaves toward).
function Airship.Arrive(parent: Instance, landing: Vector3, seaward: Vector3, hoverSeconds: number): Model
	local model = Airship.Build()
	local flat = Vector3.new(seaward.X, 0, seaward.Z)
	local away = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, 1)
	local hover = landing + Vector3.new(0, 34, 0)
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
	local inbound = TweenService:Create(driver, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Value = facing(hover, hover - away)})
	inbound:Play()
	inbound.Completed:Once(function()
		task.delay(hoverSeconds, function()
			if not model.Parent then return end
			local outbound = TweenService:Create(driver, TweenInfo.new(3.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Value = facing(finish, finish + away)})
			outbound:Play()
			outbound.Completed:Once(function() model:Destroy(); driver:Destroy() end)
		end)
	end)
	return model
end

return Airship
