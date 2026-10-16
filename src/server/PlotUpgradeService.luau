--!strict
-- Resizes runtime yard bounds and fences; all stations/scenery stay authored.
-- Square-to-T yards share their real usable shape with roaming, eggs and vacuum.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Definitions = require(Shared.UpgradeCatalog)
local Layout = require(Shared.HomePlotLayout)
local UIColors = require(Shared.UIColors)
local PlotUpgradeService = {}
PlotUpgradeService.__index = PlotUpgradeService

local function bindFence(folder, frame)
	local fence = folder:FindFirstChild("BoundaryFence", true)
	if not fence or not fence:GetAttribute("ExpansionMaxBack") then return nil end
	local data = {frame = frame, parts = {}, maxBack = fence:GetAttribute("ExpansionMaxBack"),
		lateDepth = fence:GetAttribute("ExpansionLateDepth") or 0,
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

local function resizeFence(fence, level)
	if not fence then return end
	local progress = math.clamp(level / #Definitions.PlotPrices, 0, 1)
	local lateProgress = math.clamp((level - (#Definitions.PlotPrices - 2)) / 2, 0, 1)
	local left = fence.left + (-fence.maxHalfWidth - fence.left) * progress
	local right = fence.right + (fence.maxHalfWidth - fence.right) * progress
	local back = fence.back + (fence.maxBack - fence.lateDepth - fence.back) * progress + fence.lateDepth * lateProgress
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
	self.anchor = anchor
	self.center = anchor.CFrame
	self.floorSize = anchor.Size
	self.floorY = frame:PointToObjectSpace((anchor.CFrame * CFrame.new(0, if floor then anchor.Size.Y / 2 else 0, 0)).Position).Y
	if yard:GetAttribute("ExpansionShape") == "T" and edge then
		self.teeEdge = edge
		-- The deck can be resized from one end; keep the authored starter square fixed.
		local starter = frame:PointToObjectSpace(edge.Position)
		self.teeOrigin = Vector2.new(starter.X, starter.Z + 8.5)
		self.yardAnchor = anchors and anchors:FindFirstChild("Yard")
		self.fence = bindFence(folder, frame)
		self:SetLevel(0)
		return self
	end
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
	if self.teeEdge then
		local bounds, outline = Layout.TeeYard(level, self.teeOrigin)
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, at in outline do
			minX, maxX = math.min(minX, at.X), math.max(maxX, at.X)
			minZ, maxZ = math.min(minZ, at.Y), math.max(maxZ, at.Y)
		end
		local edge = self.teeEdge
		edge.CFrame = self.frame * CFrame.new((minX + maxX) / 2, self.floorY, (minZ + maxZ) / 2)
		edge.Size = Vector3.new(maxX - minX, edge.Size.Y, maxZ - minZ)
		for i, at in outline do
			local beam = edge:FindFirstChild("YardEdge" .. i)
			if beam and beam:IsA("Beam") and beam.Attachment0 and beam.Attachment1 then
				local nextAt = outline[i % #outline + 1]
				local a = edge.CFrame:PointToObjectSpace(self.frame:PointToWorldSpace(Vector3.new(at.X, self.floorY, at.Y)))
				local b = edge.CFrame:PointToObjectSpace(self.frame:PointToWorldSpace(Vector3.new(nextAt.X, self.floorY, nextAt.Y)))
				beam.Enabled = (b - a).Magnitude > 0.01
				local direction = if beam.Enabled then (b - a).Unit else Vector3.zAxis
				local across = Vector3.new(-direction.Z, 0, direction.X)
				beam.Attachment0.CFrame = CFrame.fromMatrix(a, Vector3.yAxis, across)
				beam.Attachment1.CFrame = CFrame.fromMatrix(b, Vector3.yAxis, across)
			end
		end
		local yardAnchor = self.yardAnchor
		if yardAnchor and yardAnchor:IsA("BasePart") then
			yardAnchor.CFrame = edge.CFrame
			yardAnchor.Size = Vector3.new(edge.Size.X, yardAnchor.Size.Y, edge.Size.Z)
		end
		bounds.FootY = self.floorY
		Layout.SetYard(self.index, bounds)
		resizeFence(self.fence, level)
		self.folder:SetAttribute("PlotSizeLevel", level)
		self.folder:SetAttribute("YardScale", scale)
		self.folder:SetAttribute("YardDepth", maxZ - minZ)
		self.folder:SetAttribute("YardShape", if #bounds.YardRegions > 1 then "T" else "Rectangle")
		return
	end
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

-- October 16 timed builds: a countdown sign over the yard while builders work.
local function buildSign(anchor)
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Size, gui.StudsOffsetWorldSpace, gui.MaxDistance = "YardBuildSign", UDim2.fromScale(16, 4.5), Vector3.new(0, 11, 0), 140
	gui.AlwaysOnTop, gui.LightInfluence = false, 0
	local function line(name, top, height, color, maxSize)
		local label = Instance.new("TextLabel")
		label.Name, label.BackgroundTransparency = name, 1
		label.Position, label.Size = UDim2.fromScale(0, top), UDim2.fromScale(1, height)
		label.Font, label.TextColor3, label.TextScaled = Enum.Font.SourceSansBold, color, true
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness, stroke.Parent = UIColors.Border, 2, label
		local limit = Instance.new("UITextSizeConstraint")
		limit.MinTextSize, limit.MaxTextSize, limit.Parent = 1, maxSize, label
		label.Parent = gui
		return label
	end
	line("Title", 0, 0.55, UIColors.Text, 64).Text = "Builders at work"
	line("Time", 0.58, 0.42, UIColors.Rewards, 48)
	gui.Parent = anchor
	return gui
end

function PlotUpgradeService:SetBuild(build, now: number)
	if not build or not self.available then
		if self.sign then self.sign:Destroy(); self.sign = nil end
		return
	end
	self.sign = self.sign or buildSign(self.anchor)
	local seconds = math.max(0, math.ceil(build.endsAt - now))
	local text = "Flock " .. Definitions.PlotCapacity(build.level) .. " in "
		.. (if seconds >= 3600 then string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
			else string.format("%d:%02d", seconds // 60, seconds % 60))
	local label = self.sign:FindFirstChild("Time") :: TextLabel
	if label.Text ~= text then label.Text = text end
end

function PlotUpgradeService:Destroy()
	if self.sign then self.sign:Destroy(); self.sign = nil end
	Layout.SetYard(self.index, nil)
	table.clear(self.parts)
	table.clear(self.attachments)
	if self.fence then table.clear(self.fence.parts) end
end

return PlotUpgradeService
