-- Edit-time asset operation: only Plot1 fencing, boundary and yard anchor.
assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning(), "Expected Pet Roll Test in Edit")
local storage = game:GetService("ServerStorage")
assert(not storage:FindFirstChild("RectangularPlotRecovery20260929"), "Expansion already applied; use the recovery before rerunning")
local plot = workspace.MyChickenArmyMap["03_HomePlots"].Plot1
local deck = plot.Deck
local yard = plot.ChickenYard
local fence = plot.Props.BoundaryFence
local edge = yard.Boundary.Beam
local anchor = plot.Anchors.Yard
local history = game:GetService("ChangeHistoryService")
local recording = history:TryBeginRecording("RectangularPlot20260929", "Expand Plot1 fencing and chicken yard")
assert(recording, "Another Studio edit recording is active")

local recovery = Instance.new("Folder")
recovery.Name = "RectangularPlotRecovery20260929"
recovery.Parent = storage
local before = plot:Clone()
before.Name = "Plot1Before"
before.Parent = recovery

local left, right, front, back = -44, 44, -48.18, 52.5
local gateLeft, gateRight = -9.896184921264648, 8.80984115600586
local created = 0
local function relative(part) return deck.CFrame:ToObjectSpace(part.CFrame) end
local function partsIn(group)
	local posts, rails = {}, {}
	-- Nested models are decorative rocks/footings, not fence rails or posts.
	for _, part in group:GetChildren() do
		if part:IsA("BasePart") then
			table.insert(if part.Size.Y > 10 then rails else posts, part)
		end
	end
	table.sort(posts, function(a, b) return a.Name < b.Name end)
	return posts, rails
end
local postTemplate = select(1, partsIn(fence.Right))[1]
local function putPosts(group, posts, positions)
	while #posts < #positions do
		created += 1
		local part = postTemplate:Clone()
		part.Name = "ExpansionPost" .. created
		part.Parent = group
		table.insert(posts, part)
	end
	assert(#posts == #positions, "All existing posts must be retained")
	for i, part in posts do
		local localFrame = relative(part)
		local at = positions[i]
		part.CFrame = deck.CFrame * CFrame.new(at.X, localFrame.Y, at.Y) * localFrame.Rotation
	end
end
local function rail(part, x, z, length)
	local localFrame = relative(part)
	part.CFrame = deck.CFrame * CFrame.new(x, localFrame.Y, z) * localFrame.Rotation
	part.Size = Vector3.new(part.Size.X, length, part.Size.Z)
end
for _, side in {{fence.Left, left}, {fence.Right, right}} do
	local group, x = side[1], side[2]
	local posts, rails = partsIn(group)
	local intervals = math.max(math.ceil((back - front) / 5.5), #posts - 1)
	local positions = {}
	for i = 0, intervals do table.insert(positions, Vector2.new(x, front + (back - front) * i / intervals)) end
	putPosts(group, posts, positions)
	for _, part in rails do rail(part, x, (front + back) / 2, back - front) end
end
do
	local posts, rails = partsIn(fence.Back)
	local intervals = math.max(math.ceil((right - left) / 5.5), #posts + 1)
	local positions = {}
	for i = 1, intervals - 1 do table.insert(positions, Vector2.new(left + (right - left) * i / intervals, back)) end
	putPosts(fence.Back, posts, positions)
	for _, part in rails do
		local isLeft = relative(part).X < 0
		rail(part, if isLeft then left / 2 else right / 2, back, if isLeft then -left else right)
	end
end
do
	local posts, rails = partsIn(fence.Front)
	local wings = {{}, {}}
	for _, part in posts do table.insert(wings[if relative(part).X < 0 then 1 else 2], part) end
	for side, wing in wings do
		local a, b = if side == 1 then left else gateRight, if side == 1 then gateLeft else right
		local count = math.max(math.ceil((b - a) / 5.5), #wing)
		local positions = {}
		for i = 1, count do
			local t = if side == 1 then i / count else (i - 1) / count
			table.insert(positions, Vector2.new(a + (b - a) * t, front))
		end
		putPosts(fence.Front, wing, positions)
	end
	for _, part in rails do
		local isLeft = relative(part).X < 0
		local a, b = if isLeft then left else gateRight, if isLeft then gateLeft else right
		rail(part, (a + b) / 2, front, b - a)
	end
end

-- The authored boundary is the maximum footprint. Runtime levels extend from
-- its fixed front: 36 wide, then 32 / 38 / 44 / 50 / 56 / 62 / 68 / 74 deep.
local yardFront, yardBack, halfWidth = -23.5, 50.5, 18
local centerZ = (yardFront + yardBack) / 2
local edgeY = relative(edge).Y
edge.CFrame = deck.CFrame * CFrame.new(0, edgeY, centerZ)
edge.Size = Vector3.new(halfWidth * 2, edge.Size.Y, yardBack - yardFront)
local corners = {
	TopLeft = Vector3.new(-halfWidth, 0, -(yardBack - yardFront) / 2),
	TopRight = Vector3.new(halfWidth, 0, -(yardBack - yardFront) / 2),
	BottomLeft = Vector3.new(-halfWidth, 0, (yardBack - yardFront) / 2),
	BottomRight = Vector3.new(halfWidth, 0, (yardBack - yardFront) / 2),
}
for _, attachment in edge:GetChildren() do
	if not attachment:IsA("Attachment") then continue end
	local corner = corners[attachment.Name]
	if attachment.Name == "TopForConnectBeam" or attachment.Name == "BottomForConnectBeam" then
		corner = Vector3.new(if attachment.Position.X > 0 then -halfWidth else halfWidth, 0,
			if attachment.Name == "TopForConnectBeam" then -(yardBack - yardFront) / 2 else (yardBack - yardFront) / 2)
	end
	assert(corner, "Unknown boundary attachment " .. attachment.Name)
	attachment.Position = corner + Vector3.new(0, attachment.Position.Y, 0)
end
anchor.CFrame = deck.CFrame * CFrame.new(0, relative(anchor).Y, centerZ)
anchor.Size = Vector3.new(halfWidth * 2, anchor.Size.Y, yardBack - yardFront)
yard:SetAttribute("ExpansionAxis", "Depth")
yard:SetAttribute("ExpansionStartDepth", 32)
history:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
return {plot = plot:GetFullName(), yardWidth = 36, yardDepths = {32,38,44,50,56,62,68,74},
	fenceWidth = right - left, fenceDepth = back - front, addedFencePosts = created,
	recovery = recovery:GetFullName()}
