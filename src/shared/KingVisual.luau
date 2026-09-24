--!strict
-- Reuses the stud-textured Blender chicken and its authored clips at boss scale.
local KingVisual = {}

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
	local base = root.CFrame * CFrame.new(0, height - size * 0.15, -size * 0.24)
	local crown = Instance.new("Part")
	crown.Name, crown.Size, crown.CFrame = "RoyalCrown", Vector3.new(size * 0.65, size * 0.14, size * 0.55), base
	crown.Color, crown.Material = Color3.fromRGB(255, 201, 30), Enum.Material.Metal
	crown.CanCollide, crown.CanTouch, crown.CanQuery, crown.Massless = false, false, false, true
	crown.TopSurface, crown.Parent = Enum.SurfaceType.Studs, model
	local joint = Instance.new("Weld")
	joint.Name, joint.Part0, joint.Part1 = "CrownJoint", root, crown
	joint.C0, joint.Parent = root.CFrame:ToObjectSpace(base), crown
	local head = model:FindFirstChild((model:GetAttribute("BonePrefix") or "") .. "Head", true) or model:FindFirstChild("head", true)
	if head and head:IsA("Bone") then
		joint:SetAttribute("HeadOffset", head.WorldCFrame:ToObjectSpace(base))
	end
	for i = 1, 5 do
		local tooth = Instance.new("Part")
		tooth.Name, tooth.Size = "CrownPoint" .. i, Vector3.new(size * 0.105, size * (if i == 3 then 0.3 else 0.22), size * 0.12)
		tooth.CFrame = base * CFrame.new((i - 3) * size * 0.135, size * 0.15, -size * 0.22)
		tooth.Color, tooth.Material = crown.Color, crown.Material
		tooth.CanCollide, tooth.CanTouch, tooth.CanQuery, tooth.Massless = false, false, false, true
		tooth.TopSurface, tooth.Parent = Enum.SurfaceType.Studs, model
		local weld = Instance.new("WeldConstraint"); weld.Part0, weld.Part1, weld.Parent = crown, tooth, tooth
	end
	local gem = Instance.new("Part")
	gem.Name, gem.Size, gem.CFrame = "CrownRuby", Vector3.one * size * 0.14, base * CFrame.new(0, 0, -size * 0.3) * CFrame.Angles(0, 0, math.pi / 4)
	gem.Color, gem.Material = Color3.fromRGB(255, 57, 60), Enum.Material.Neon
	gem.CanCollide, gem.CanTouch, gem.CanQuery, gem.Massless, gem.Parent = false, false, false, true, model
	local weld = Instance.new("WeldConstraint"); weld.Part0, weld.Part1, weld.Parent = crown, gem, gem
	local tag = root:FindFirstChild("Tag")
	if tag then
		tag.Size, tag.StudsOffset, tag.MaxDistance = UDim2.fromOffset(240, 62), Vector3.new(0, height + size * 0.65, 0), 180
		tag.NameLabel.Text, tag.NameLabel.TextSize = "CHICKEN KING", 24
		tag.NameLabel.TextColor3 = crown.Color
		tag.Health.Position, tag.Health.Size = UDim2.new(0.5, 0, 0, 30), UDim2.fromOffset(180, 12)
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
