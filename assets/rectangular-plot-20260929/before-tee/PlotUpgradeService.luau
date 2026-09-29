--!strict
-- Resizes disposable runtime yard bounds. Depth-expanding yards keep their front
-- edge and all scenery fixed; movement and eggs share the visible perimeter.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Definitions = require(Shared.UpgradeCatalog)
local Layout = require(Shared.HomePlotLayout)
local PlotUpgradeService = {}
PlotUpgradeService.__index = PlotUpgradeService

local function bindFence(folder, frame)
	local fence = folder:FindFirstChild("BoundaryFence", true)
	if not fence or not fence:GetAttribute("ExpansionMaxBack") then return nil end
	local data = {frame = frame, parts = {}, maxBack = fence:GetAttribute("ExpansionMaxBack"),
		maxHalfWidth = fence:GetAttribute("ExpansionMaxHalfWidth"), gateLeft = -math.huge, gateRight = math.huge}
	for _, side in {"Left", "Right", "Front", "Back"} do
		local group = fence:FindFirstChild(side)
		if not group then return nil end
		for _, part in group:GetChildren() do
			-- Nested rocks/footings are stationary scenery, not fence components.
			if not part:IsA("BasePart") then continue end
			local relative = frame:ToObjectSpace(part.CFrame)
			table.insert(data.parts, {part = part, side = side, localFrame = relative, size = part.Size, rail = part.Size.Y > 10})
			if side == "Left" then data.left = relative.X
			elseif side == "Right" then data.right = relative.X
			elseif side == "Back" then data.back = relative.Z
			else
				data.front = relative.Z
				if relative.X < 0 then data.gateLeft = math.max(data.gateLeft, relative.X)
				else data.gateRight = math.min(data.gateRight, relative.X) end
			end
		end
	end
	return data
end

local function resizeFence(fence, progress)
	if not fence then return end
	local left = fence.left + (-fence.maxHalfWidth - fence.left) * progress
	local right = fence.right + (fence.maxHalfWidth - fence.right) * progress
	local back = fence.back + (fence.maxBack - fence.back) * progress
	for _, item in fence.parts do
		if not item.part.Parent then continue end
		local at = item.localFrame.Position
		local x, z, lengthScale = at.X, at.Z, 1
		if item.side == "Left" or item.side == "Right" then
			lengthScale = (back - fence.front) / (fence.back - fence.front)
			x = if item.side == "Left" then left else right
			z = fence.front + (at.Z - fence.front) * lengthScale
		elseif item.side == "Back" then
			lengthScale = (right - left) / (fence.right - fence.left)
			x, z = left + (at.X - fence.left) * lengthScale, back
		elseif at.X < 0 then
			lengthScale = (fence.gateLeft - left) / (fence.gateLeft - fence.left)
			x = fence.gateLeft + (at.X - fence.gateLeft) * lengthScale
		else
			lengthScale = (right - fence.gateRight) / (fence.right - fence.gateRight)
			x = fence.gateRight + (at.X - fence.gateRight) * lengthScale
		end
		item.part.CFrame = fence.frame * CFrame.new(x, at.Y, z) * item.localFrame.Rotation
		-- Stretch the long rail axis only; posts retain their authored dimensions.
		if item.rail then item.part.Size = Vector3.new(item.size.X, item.size.Y * lengthScale, item.size.Z) end
	end
end

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
	self.depthOnly = yard:GetAttribute("ExpansionAxis") == "Depth"
	if self.depthOnly then
		local front, back = math.huge, -math.huge
		for _, corner in self.corners do
			front, back = math.min(front, corner.Z), math.max(back, corner.Z)
		end
		self.frontZ, self.authoredDepth = front, back - front
		self.maxDepth = math.max(self.authoredDepth, yard:GetAttribute("ExpansionMaxDepth") or self.authoredDepth)
		self.startDepth = math.clamp(yard:GetAttribute("ExpansionStartDepth") or self.maxDepth, 4, self.maxDepth)
		self.fence = bindFence(folder, frame)
	end
	for _, part in yard:GetDescendants() do
		-- Grass and decorations remain authored in place on rectangular plots.
		if self.depthOnly and part ~= floor and not (boundary and part:IsDescendantOf(boundary)) then continue end
		if part:IsA("BasePart") then
			table.insert(self.parts, {part = part, localFrame = self.center:ToObjectSpace(part.CFrame), size = part.Size})
		elseif part:IsA("Attachment") and part.Parent:IsA("BasePart") then
			table.insert(self.attachments, {attachment = part, localFrame = self.center:ToObjectSpace(part.WorldCFrame)})
		end
	end
	local yardAnchor = anchors and anchors:FindFirstChild("Yard")
	if self.depthOnly and yardAnchor and yardAnchor:IsA("BasePart") and not yardAnchor:IsDescendantOf(yard) then
		table.insert(self.parts, {part = yardAnchor, localFrame = self.center:ToObjectSpace(yardAnchor.CFrame), size = yardAnchor.Size})
	end
	self:SetLevel(0)
	return self
end

function PlotUpgradeService:SetLevel(level)
	if not self.available or self.level == level then return end
	self.level = level
	local scale = Definitions.PlotScales[level + 1] or 1
	local stretch = Vector3.new(scale, 1, scale)
	local offset = Vector3.zero
	if self.depthOnly then
		local progress = math.clamp(level / #Definitions.PlotPrices, 0, 1)
		local depth = self.startDepth + (self.maxDepth - self.startDepth) * progress
		stretch = Vector3.new(1, 1, depth / self.authoredDepth)
		offset = Vector3.new(0, 0, self.frontZ * (1 - stretch.Z))
		self.folder:SetAttribute("YardDepth", depth)
		resizeFence(self.fence, progress)
	end
	for _, item in self.parts do
		if item.part.Parent then
			local relative = item.localFrame
			item.part.CFrame = self.center * (CFrame.new(relative.Position * stretch + offset) * relative.Rotation)
			item.part.Size = item.size * Vector3.new((relative.RightVector * stretch).Magnitude,
				(relative.UpVector * stretch).Magnitude, (relative.LookVector * stretch).Magnitude)
		end
	end
	for _, item in self.attachments do
		local attachment = item.attachment
		if attachment.Parent then
			local relative = item.localFrame
			attachment.CFrame = attachment.Parent.CFrame:ToObjectSpace(self.center * (CFrame.new(relative.Position * stretch + offset) * relative.Rotation))
		end
	end
	-- Read the visible perimeter even when the builder removes the separate lawn floor.
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, corner in self.corners do
		local at = self.frame:PointToObjectSpace(self.center:PointToWorldSpace(corner * stretch + offset))
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
	if self.fence then table.clear(self.fence.parts) end
end

return PlotUpgradeService
