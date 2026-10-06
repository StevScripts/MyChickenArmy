--!strict
-- Normal level growth or a persistent Giant body extent. Combat stays in Rules.
local Giant = require(script.Parent.GiantChicken)
local Growth = {}
Growth.BaseScale = 0.75
local SCALES = {1, 1.18, 1.32, 1.44, 1.54, 1.63, 1.71, 1.78, 1.84, 1.90}

function Growth.ScaleForLevel(level: number): number
	return SCALES[math.clamp(math.floor(level), 1, #SCALES)]
end

function Growth.Apply(model: Model, level: number, giantSize: number?): number
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
	if not model:GetAttribute("BaseVisualExtent") then
		model:SetAttribute("BaseVisualExtent",math.max(model:GetAttribute("VisualHeight") or 1,
			model:GetAttribute("VisualWidth") or 1,model:GetAttribute("VisualDepth") or 1)/previous)
		model:SetAttribute("BaseRootSize",root.Size/previous)
		model:SetAttribute("BaseFootOffset",offset/previous)
		model:SetAttribute("BaseNavigationHeight",(model:GetAttribute("NavigationHeight") or model:GetAttribute("VisualHeight") or 4)/previous)
	end
	local giant = Giant.IsValidSize(giantSize)
	local desired = if giant then (giantSize :: number)/model:GetAttribute("BaseVisualExtent") else baseScale*mergeScale
	model:SetAttribute("GiantSize",if giant then giantSize else nil)
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
	if humanoid and giant then
		-- Giant art must not create a 27-stud pathfinding agent or collision shell.
		-- Keep the normal walking root near the feet; move its visual joints upward
		-- by the matching offset so the enlarged mesh remains grounded.
		local walkingOffset = model:GetAttribute("BaseFootOffset")*baseScale
		local delta = newOffset-walkingOffset
		for _,joint in root:GetChildren() do
			if joint:IsA("Motor6D") and joint.Part0==root then
				joint.C0=CFrame.new(0,delta,0)*joint.C0
			end
		end
		root.Size=model:GetAttribute("BaseRootSize")*baseScale
		newOffset=walkingOffset
		model:SetAttribute("NavigationHeight",math.max(2,model:GetAttribute("BaseNavigationHeight")*baseScale))
	end
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
