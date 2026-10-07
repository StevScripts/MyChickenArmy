--!strict
-- Reuses the stud-textured Blender chicken and its authored clips at boss scale.
local KingVisual = {}
local GOLD = Color3.fromRGB(255, 201, 30)
local TRIM = Color3.fromRGB(214, 146, 18)
local VELVET = Color3.fromRGB(176, 24, 52)
local RUBY = Color3.fromRGB(235, 40, 70)
local SAPPHIRE = Color3.fromRGB(50, 130, 255)
local EMERALD = Color3.fromRGB(40, 205, 105)

local function piece(model, name, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Name, part.Size, part.CFrame = name, size, cframe
	if shape then part.Shape = shape end
	part.Color, part.Material = color, material
	part.Reflectance = if material == Enum.Material.Metal then 0.12 else 0
	part.CanCollide, part.CanTouch, part.CanQuery, part.Massless, part.CastShadow = false, false, false, true, false
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

function KingVisual.Apply(model, scale)
	if model:GetAttribute("ChickenKing") then return end
	local root = model.PrimaryPart
	local foot = root.Position - Vector3.new(0, model:GetAttribute("FootOffset"), 0)
	model:ScaleTo(model:GetScale() * scale)
	for _, name in {"Size", "ClipScale", "FootOffset", "VisualHeight", "VisualWidth", "VisualDepth"} do
		local value = model:GetAttribute(name)
		if value then model:SetAttribute(name, value * scale) end
	end
	model:PivotTo(CFrame.new(foot + Vector3.new(0, model:GetAttribute("FootOffset"), 0)) * root.CFrame.Rotation)
	model:SetAttribute("ChickenKing", true)
	local size = model:GetAttribute("Size")
	local height = model:GetAttribute("VisualHeight") - model:GetAttribute("FootOffset")
	-- Seated on top of the head, a little back from the beak, with a jaunty tilt.
	local base = root.CFrame * CFrame.new(0, height - size * 0.02, -size * 0.2) * CFrame.Angles(0, 0, math.rad(-7))
	local crown = piece(model, "RoyalCrown", Vector3.new(size * 0.66, size * 0.05, size * 0.56), base, TRIM, Enum.Material.Metal)
	local joint = Instance.new("Weld")
	joint.Name, joint.Part0, joint.Part1 = "CrownJoint", root, crown
	joint.C0, joint.Parent = root.CFrame:ToObjectSpace(base), crown
	local head = model:FindFirstChild((model:GetAttribute("BonePrefix") or "") .. "Head", true) or model:FindFirstChild("head", true)
	if head and head:IsA("Bone") then
		joint:SetAttribute("HeadOffset", head.WorldCFrame:ToObjectSpace(base))
	end
	local w, d, h, t = size * 0.6, size * 0.5, size * 0.17, size * 0.07
	local function add(name, partSize, offset, color, material, shape)
		local part = piece(model, name, partSize, base * offset, color, material, shape)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = crown, part, part
		return part
	end
	-- Hollow band so the velvet shows, with a darker rim on top.
	local y = size * 0.025 + h / 2
	add("CrownFront", Vector3.new(w, h, t), CFrame.new(0, y, -(d - t) / 2), GOLD, Enum.Material.Metal)
	add("CrownBack", Vector3.new(w, h, t), CFrame.new(0, y, (d - t) / 2), GOLD, Enum.Material.Metal)
	add("CrownLeft", Vector3.new(t, h, d - t * 2), CFrame.new(-(w - t) / 2, y, 0), GOLD, Enum.Material.Metal)
	add("CrownRight", Vector3.new(t, h, d - t * 2), CFrame.new((w - t) / 2, y, 0), GOLD, Enum.Material.Metal)
	local top = size * 0.025 + h
	add("CrownRimFront", Vector3.new(w + size * 0.03, size * 0.035, t + size * 0.03), CFrame.new(0, top, -(d - t) / 2), TRIM, Enum.Material.Metal)
	add("CrownRimBack", Vector3.new(w + size * 0.03, size * 0.035, t + size * 0.03), CFrame.new(0, top, (d - t) / 2), TRIM, Enum.Material.Metal)
	add("CrownVelvet", Vector3.new(w - t * 2, h * 0.75, d - t * 2), CFrame.new(0, size * 0.025 + h * 0.45, 0), VELVET, Enum.Material.Fabric)
	add("CrownCushion", Vector3.new(w * 0.62, size * 0.16, d * 0.62), CFrame.new(0, top + size * 0.02, 0), VELVET, Enum.Material.Fabric, Enum.PartType.Ball)
	-- Eight points, each tipped with an orb; the front centre one stands tallest.
	for _, spot in {{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}} do
		local x, z = spot[1] * (w - t) / 2, spot[2] * (d - t) / 2
		local tall = if spot[1] == 0 and spot[2] == -1 then size * 0.2 else size * 0.13
		add("CrownPoint", Vector3.new(t * 1.1, tall, t * 1.1), CFrame.new(x, top + tall / 2, z) * CFrame.Angles(0, math.rad(45), 0), GOLD, Enum.Material.Metal)
		add("CrownOrb", Vector3.one * size * 0.075, CFrame.new(x, top + tall + size * 0.03, z), TRIM, Enum.Material.Metal, Enum.PartType.Ball)
	end
	-- Gems: a big ruby on the front, sapphires and emeralds around the band.
	add("CrownRuby", Vector3.new(size * 0.13, size * 0.13, size * 0.05), CFrame.new(0, y, -d / 2 - size * 0.01) * CFrame.Angles(0, 0, math.rad(45)), RUBY, Enum.Material.Glass)
	for _, gem in {{-1, -1, SAPPHIRE}, {1, -1, SAPPHIRE}, {-1, 1, EMERALD}, {1, 1, EMERALD}} do
		local x = gem[1] * w * 0.3
		add("CrownGem", Vector3.new(size * 0.07, size * 0.07, size * 0.04), CFrame.new(x, y, gem[2] * (d / 2 + size * 0.01)) * CFrame.Angles(0, 0, math.rad(45)), gem[3], Enum.Material.Glass)
	end
	add("CrownGemLeft", Vector3.new(size * 0.04, size * 0.09, size * 0.09), CFrame.new(-w / 2 - size * 0.01, y, 0) * CFrame.Angles(math.rad(45), 0, 0), RUBY, Enum.Material.Glass)
	add("CrownGemRight", Vector3.new(size * 0.04, size * 0.09, size * 0.09), CFrame.new(w / 2 + size * 0.01, y, 0) * CFrame.Angles(math.rad(45), 0, 0), RUBY, Enum.Material.Glass)
	-- Orb and cross on top.
	local orbY = top + size * 0.17
	local orb = add("CrownMonde", Vector3.one * size * 0.12, CFrame.new(0, orbY, 0), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
	add("CrownCrossUp", Vector3.new(size * 0.035, size * 0.13, size * 0.035), CFrame.new(0, orbY + size * 0.11, 0), TRIM, Enum.Material.Metal)
	add("CrownCrossBar", Vector3.new(size * 0.09, size * 0.035, size * 0.035), CFrame.new(0, orbY + size * 0.12, 0), TRIM, Enum.Material.Metal)
	-- A slow royal glimmer.
	local glimmer = Instance.new("ParticleEmitter")
	glimmer.Name, glimmer.Texture = "CrownGlimmer", "rbxasset://textures/particles/sparkles_main.dds"
	glimmer.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170), Color3.new(1, 1, 1))
	glimmer.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, size * 0.07), NumberSequenceKeypoint.new(1, 0)})
	glimmer.Lifetime, glimmer.Speed, glimmer.Rate = NumberRange.new(0.5, 0.9), NumberRange.new(0, 0.3), 3
	glimmer.LightEmission, glimmer.SpreadAngle, glimmer.Parent = 1, Vector2.new(180, 180), orb
	local tag = root:FindFirstChild("Tag")
	if tag then
		tag.Size, tag.StudsOffset, tag.MaxDistance = UDim2.fromOffset(240, 62), Vector3.new(0, height + size * 0.9, 0), 180
		tag.NameLabel.Text, tag.NameLabel.TextSize = "CHICKEN KING", 24
		tag.NameLabel.TextColor3 = GOLD
		tag.Health.Position, tag.Health.Size = UDim2.new(0.5, 0, 0, 30), UDim2.fromOffset(180, 22)
	end
end

function KingVisual.Update(model)
	local crown = model:FindFirstChild("RoyalCrown")
	local joint = crown and crown:FindFirstChild("CrownJoint")
	local head = model:FindFirstChild((model:GetAttribute("BonePrefix") or "") .. "Head", true) or model:FindFirstChild("head", true)
	if joint and head and head:IsA("Bone") and joint:GetAttribute("HeadOffset") then
		joint.C0 = model.PrimaryPart.CFrame:ToObjectSpace(head.TransformedWorldCFrame * joint:GetAttribute("HeadOffset"))
	end
end

return KingVisual
