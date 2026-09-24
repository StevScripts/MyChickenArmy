--!strict
-- Uniform chicken size plus merge-level growth. Combat stats stay in Rules.
local Growth = {}
Growth.BaseScale = 0.75
local SCALES = {1, 1.18, 1.32, 1.44, 1.54, 1.63, 1.71, 1.78, 1.84, 1.90}

function Growth.ScaleForLevel(level: number): number
	return SCALES[math.clamp(math.floor(level), 1, #SCALES)]
end

function Growth.Apply(model: Model, level: number): number
	-- The encounter owns the King's deliberately oversized silhouette.
	if model:GetAttribute("ChickenKing") then return 1 end
	local root = model.PrimaryPart
	if not root then return 1 end
	local mergeScale = Growth.ScaleForLevel(level)
	local desired = Growth.BaseScale * mergeScale
	-- Record the applied factor so repeated updates never shrink a chicken again.
	local previous = (model:GetAttribute("MergeVisualScale") or 1)
		* (model:GetAttribute("AppliedBaseVisualScale") or model:GetAttribute("AppliedFieldVisualScale") or 1)
	model:SetAttribute("MergeVisualScale", mergeScale)
	model:SetAttribute("AppliedBaseVisualScale", Growth.BaseScale)
	model:SetAttribute("FieldVisualScale", nil)
	model:SetAttribute("AppliedFieldVisualScale", nil)
	if desired == previous then return 1 end
	local ratio = desired / previous
	local offset = model:GetAttribute("FootOffset") or (model:GetAttribute("Size") or 2.25) * 0.45
	local foot = root.Position - Vector3.new(0, offset, 0)
	local rotation = root.CFrame.Rotation
	model:ScaleTo(model:GetScale() * ratio)
	for _, name in {"Size", "ClipScale", "VisualHeight", "VisualWidth", "VisualDepth"} do
		local value = model:GetAttribute(name)
		if typeof(value) == "number" then model:SetAttribute(name, value * ratio) end
	end
	model:SetAttribute("FootOffset", offset * ratio)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.HipHeight = math.max(0, offset * ratio - root.Size.Y / 2) end
	model:PivotTo(CFrame.new(foot + Vector3.new(0, offset * ratio, 0)) * rotation)
	local tag = root:FindFirstChild("Tag")
	if tag and tag:IsA("BillboardGui") then
		tag.StudsOffset = Vector3.new(0, (model:GetAttribute("VisualHeight") or offset * ratio * 2)
			- offset * ratio + 0.43, 0)
	end
	return ratio
end

return Growth
