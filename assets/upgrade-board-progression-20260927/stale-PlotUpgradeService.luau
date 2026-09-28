--!strict
-- Resizes only disposable runtime chicken-yard art. Never edits the source plot,
-- board, shops, roller or deck; movement and egg bounds share the resulting lawn.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Definitions = require(Shared.UpgradeCatalog)
local Layout = require(Shared.HomePlotLayout)
local PlotUpgradeService = {}
PlotUpgradeService.__index = PlotUpgradeService

function PlotUpgradeService.new(folder, index, frame)
	local yard = folder:FindFirstChild("ChickenYard")
	local anchors = folder:FindFirstChild("Anchors")
	local floor = yard and yard:FindFirstChild("YardFloor", true)
	local anchor = floor or (anchors and anchors:FindFirstChild("Yard"))
	local self = setmetatable({folder = folder, index = index, frame = frame, parts = {}, available = false}, PlotUpgradeService)
	if not yard or not anchor or not anchor:IsA("BasePart") then return self end
	self.available = true
	self.center = anchor.CFrame
	self.floorSize = anchor.Size
	self.floorY = if floor then frame:PointToObjectSpace((anchor.CFrame * CFrame.new(0, anchor.Size.Y / 2, 0)).Position).Y
		else Layout.ForPlot(index).FootY
	for _, part in yard:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(self.parts, {part = part, localFrame = self.center:ToObjectSpace(part.CFrame), size = part.Size})
		end
	end
	self:SetLevel(0)
	return self
end

function PlotUpgradeService:SetLevel(level)
	if not self.available or self.level == level then return end
	self.level = level
	local scale = Definitions.PlotScales[level + 1] or 1
	local stretch = Vector3.new(scale, 1, scale)
	for _, item in self.parts do
		if item.part.Parent then
			local relative = item.localFrame
			item.part.CFrame = self.center * (CFrame.new(relative.Position * stretch) * relative.Rotation)
			item.part.Size = item.size * Vector3.new((relative.RightVector * stretch).Magnitude,
				(relative.UpVector * stretch).Magnitude, (relative.LookVector * stretch).Magnitude)
		end
	end
	local center = self.frame:PointToObjectSpace(self.center.Position)
	-- Farm floors are aligned to their plot; keep chickens safely inside the border.
	local halfX = math.max(2, self.floorSize.X * scale / 2 - 1.6)
	local halfZ = math.max(2, self.floorSize.Z * scale / 2 - 1.6)
	Layout.SetYard(self.index, {YardMinX = center.X - halfX, YardMaxX = center.X + halfX,
		YardMinZ = center.Z - halfZ, YardMaxZ = center.Z + halfZ, FootY = self.floorY})
	self.folder:SetAttribute("PlotSizeLevel", level)
	self.folder:SetAttribute("YardScale", scale)
end

function PlotUpgradeService:Destroy()
	Layout.SetYard(self.index, nil)
	table.clear(self.parts)
end

return PlotUpgradeService
