-- Follow-up: author the small starter footprint; upgrades expand yard AND fence.
assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning(), "Expected Pet Roll Test in Edit")
local plot = workspace.MyChickenArmyMap["03_HomePlots"].Plot1
local recovery = game:GetService("ServerStorage").RectangularPlotRecovery20260929
assert(not recovery:FindFirstChild("Plot1BeforeStarterCorrection"), "Starter correction already applied")
local history = game:GetService("ChangeHistoryService")
local recording = history:TryBeginRecording("StarterPlot20260929", "Start Plot1 small and expand its fence with upgrades")
assert(recording, "Another Studio edit recording is active")
local backup = plot:Clone()
backup.Name = "Plot1BeforeStarterCorrection"
backup.Parent = recovery

local deck, yard = plot.Deck, plot.ChickenYard
local edge, anchor = yard.Boundary.Beam, plot.Anchors.Yard
local oldDepth, depth, front = 74, 18, -23.5
local edgeFrame = deck.CFrame:ToObjectSpace(edge.CFrame)
local anchorFrame = deck.CFrame:ToObjectSpace(anchor.CFrame)
edge.CFrame = deck.CFrame * CFrame.new(0, edgeFrame.Y, front + depth / 2)
edge.Size = Vector3.new(36, edge.Size.Y, depth)
for _, attachment in edge:GetChildren() do
	if attachment:IsA("Attachment") then
		local at = attachment.Position
		attachment.Position = Vector3.new(at.X, at.Y, at.Z * depth / oldDepth)
	end
end
anchor.CFrame = deck.CFrame * CFrame.new(0, anchorFrame.Y, front + depth / 2)
anchor.Size = Vector3.new(36, anchor.Size.Y, depth)
yard:SetAttribute("ExpansionStartDepth", depth)
yard:SetAttribute("ExpansionMaxDepth", 74)
yard:SetAttribute("BuilderNote", "Starter footprint. Plot upgrades extend its fixed front from 18 to 74 studs deep; fence expands too. Keep props stationary.")

local fence = plot.Props.BoundaryFence
local oldHalf, half = 44, 38
local fenceFront, oldBack, back = -48.18, 52.5, 23.5
local gateLeft, gateRight = -9.896184921264648, 8.80984115600586
for _, group in fence:GetChildren() do
	for _, part in group:GetChildren() do
		-- Decor inside nested models remains untouched.
		if not part:IsA("BasePart") then continue end
		local relative = deck.CFrame:ToObjectSpace(part.CFrame)
		local at = relative.Position
		local x, z, lengthScale = at.X, at.Z, 1
		if group.Name == "Left" or group.Name == "Right" then
			lengthScale = (back - fenceFront) / (oldBack - fenceFront)
			x = if group.Name == "Left" then -half else half
			z = fenceFront + (at.Z - fenceFront) * lengthScale
		elseif group.Name == "Back" then
			lengthScale = half / oldHalf
			x, z = at.X * lengthScale, back
		elseif group.Name == "Front" then
			if at.X < 0 then
				lengthScale = (gateLeft + half) / (gateLeft + oldHalf)
				x = gateLeft + (at.X - gateLeft) * lengthScale
			else
				lengthScale = (half - gateRight) / (oldHalf - gateRight)
				x = gateRight + (at.X - gateRight) * lengthScale
			end
		else error("Unexpected fence group") end
		part.CFrame = deck.CFrame * CFrame.new(x, at.Y, z) * relative.Rotation
		if part.Size.Y > 10 then part.Size = Vector3.new(part.Size.X, part.Size.Y * lengthScale, part.Size.Z) end
	end
end
fence:SetAttribute("ExpansionMaxBack", 52.5)
fence:SetAttribute("ExpansionMaxHalfWidth", 44)
history:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
return {yardDepths = {18,26,34,42,50,58,66,74}, yardWidth = 36,
	starterFence = {width = 76, depth = 71.68}, maxFence = {width = 88, depth = 100.68},
	preview = "Starter level 0", backup = backup:GetFullName()}
