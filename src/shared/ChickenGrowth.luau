--!strict
-- Normal level growth. Combat stays in Rules. October 20: Giants are retired, so
-- every chicken grows by level; the giantSize argument is ignored.
local Growth = {}
Growth.BaseScale = 0.75
local SCALES = {1, 1.18, 1.32, 1.44, 1.54, 1.63, 1.71, 1.78, 1.84, 1.90}

function Growth.ScaleForLevel(level: number): number
	return SCALES[math.clamp(math.floor(level), 1, #SCALES)]
end

function Growth.Apply(model: Model, level: number, _giantSize: number?): number
	-- The encounter owns the King's deliberately oversized silhouette.
	if model:GetAttribute("ChickenKing") then return 1 end
	local root = model.PrimaryPart
	if not root then return 1 end
	local mergeScale = Growth.ScaleForLevel(level)
	local baseScale = model:GetAttribute("BaseVisualScale") or Growth.BaseScale
	-- Record the applied factor so repeated updates never shrink a chicken again.
	local previous = model:GetAttribute("AppliedChickenScale") or (model:GetAttribute("MergeVisualScale") or 1)
		* (model:GetAttribute("AppliedBaseVisualScale") or model:GetAttribute("AppliedFieldVisualScale") or 1)
	local offset = model:GetAttribute("FootOffset") or (model:GetAttribute("Size") or 2.25) * 0.45
	local desired = baseScale*mergeScale
	model:SetAttribute("GiantSize", nil)
	model:SetAttribute("AppliedChickenScale",desired)
	model:SetAttribute("MergeVisualScale", mergeScale)
	model:SetAttribute("AppliedBaseVisualScale", baseScale)
	model:SetAttribute("FieldVisualScale", nil)
	model:SetAttribute("AppliedFieldVisualScale", nil)
	if desired == previous then return 1 end
	local ratio = desired / previous
	local foot = root.Position - Vector3.new(0, offset, 0)
	local rotation = root.CFrame.Rotation
	model:ScaleTo(model:GetScale() * ratio)
	for _, name in {"Size", "ClipScale", "VisualHeight", "VisualWidth", "VisualDepth"} do
		local value = model:GetAttribute(name)
		if typeof(value) == "number" then model:SetAttribute(name, value * ratio) end
	end
	local newOffset = offset*ratio
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	model:SetAttribute("FootOffset",newOffset)
	if humanoid then humanoid.HipHeight = math.max(0,newOffset-root.Size.Y/2) end
	model:PivotTo(CFrame.new(foot + Vector3.new(0,newOffset,0)) * rotation)
	local tag = root:FindFirstChild("Tag")
	if tag and tag:IsA("BillboardGui") then
		tag.StudsOffset = Vector3.new(0, (model:GetAttribute("VisualHeight") or offset * ratio * 2)
			- newOffset + 0.43, 0)
	end
	return ratio
end

return Growth
