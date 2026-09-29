--!strict
-- Resizes only disposable runtime chicken-yard art. Never edits the source plot,
-- board, shops, roller or deck; movement and egg bounds share the resulting lawn.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Definitions = require(Shared.UpgradeCatalog)
local Layout = require(Shared.HomePlotLayout)
local PlotUpgradeService = {}
PlotUpgradeService.__index = PlotUpgradeService

function PlotUpgradeService.new(folder, index, frame)
	local yard = folder:FindFirstChild("ChickenYard", true)
	local anchors = folder:FindFirstChild("Anchors", true)
	local floor = yard and yard:FindFirstChild("YardFloor", true)
	local boundary = yard and yard:FindFirstChild("Boundary", true)
	local edge = boundary and boundary:FindFirstChild("Beam")
	local anchor = floor or edge or (anchors and anchors:FindFirstChild("Yard"))
	local self = setmetatable({folder = folder, index = index, frame = frame, parts = {}, attachments = {}, corners = {}, available = false}, PlotUpgradeService)
	if not yard or not anchor or not anchor:IsA("BasePart") then return self end
	self.available = true
	self.center = anchor.CFrame
	self.floorSize = anchor.Size
	self.floorY = frame:PointToObjectSpace((anchor.CFrame * CFrame.new(0, if floor then anchor.Size.Y / 2 else 0, 0)).Position).Y
	if not floor and anchor == edge then
		for _, name in {"TopLeft", "TopRight", "BottomLeft", "BottomRight"} do
			local corner = edge:FindFirstChild(name)
			if corner and corner:IsA("Attachment") then table.insert(self.corners, corner.Position) end
		end
	end
	if #self.corners ~= 4 then
		table.clear(self.corners)
		for _, x in {-1, 1} do for _, z in {-1, 1} do
			table.insert(self.corners, Vector3.new(x * anchor.Size.X / 2, 0, z * anchor.Size.Z / 2))
		end end
	end
	for _, part in yard:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(self.parts, {part = part, localFrame = self.center:ToObjectSpace(part.CFrame), size = part.Size})
		elseif part:IsA("Attachment") and part.Parent:IsA("BasePart") then
			table.insert(self.attachments, {attachment = part, localFrame = self.center:ToObjectSpace(part.WorldCFrame)})
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
	for _, item in self.attachments do
		local attachment = item.attachment
		if attachment.Parent then
			local relative = item.localFrame
			attachment.CFrame = attachment.Parent.CFrame:ToObjectSpace(self.center * (CFrame.new(relative.Position * stretch) * relative.Rotation))
		end
	end
	-- Read the visible perimeter even when the builder removes the separate lawn floor.
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, corner in self.corners do
		local at = self.frame:PointToObjectSpace(self.center:PointToWorldSpace(corner * stretch))
		minX, maxX = math.min(minX, at.X), math.max(maxX, at.X)
		minZ, maxZ = math.min(minZ, at.Z), math.max(maxZ, at.Z)
	end
	Layout.SetYard(self.index, {YardMinX = minX + 1.6, YardMaxX = maxX - 1.6,
		YardMinZ = minZ + 1.6, YardMaxZ = maxZ - 1.6, FootY = self.floorY})
	self.folder:SetAttribute("PlotSizeLevel", level)
	self.folder:SetAttribute("YardScale", scale)
end

function PlotUpgradeService:Destroy()
	Layout.SetYard(self.index, nil)
	table.clear(self.parts)
	table.clear(self.attachments)
end

return PlotUpgradeService
