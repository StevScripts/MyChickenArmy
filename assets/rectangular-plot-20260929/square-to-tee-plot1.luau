-- Author the square starter boundary, retaining eight edges for the final T.
assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning(), "Expected Pet Roll Test in Edit")
local plot = workspace.MyChickenArmyMap["03_HomePlots"].Plot1
local recovery = game:GetService("ServerStorage").RectangularPlotRecovery20260929
assert(not recovery:FindFirstChild("Plot1BeforeTShape"), "T shape already authored")
local edge = plot.ChickenYard.Boundary.Beam
local attachments, beams = {}, {}
for _, child in edge:GetChildren() do
	if child:IsA("Attachment") then table.insert(attachments, child)
	elseif child:IsA("Beam") then table.insert(beams, child) end
end
assert(#attachments == 8 and #beams == 4, "Expected the existing eight attachments and four beams")
local history = game:GetService("ChangeHistoryService")
local recording = history:TryBeginRecording("SquareToTPlot20260929", "Square starter yard expanding into a T")
assert(recording, "Another Studio edit recording is active")
local backup = plot:Clone()
backup.Name = "Plot1BeforeTShape"
backup.Parent = recovery

local deck = plot.Deck
local edgeY = deck.CFrame:PointToObjectSpace(edge.Position).Y
edge.CFrame = deck.CFrame * CFrame.new(0, edgeY, -8.5)
edge.Size = Vector3.new(30, edge.Size.Y, 30)
local points = {Vector2.new(-15,-15),Vector2.new(15,-15),Vector2.new(15,15),Vector2.new(15,15),
	Vector2.new(15,15),Vector2.new(-15,15),Vector2.new(-15,15),Vector2.new(-15,15)}
local attachmentTemplate = attachments[1]
for i = #attachments + 1, 16 do
	local attachment = attachmentTemplate:Clone()
	attachment.Parent = edge
	table.insert(attachments, attachment)
end
local template = beams[1]
for i = #beams + 1, 8 do
	local beam = template:Clone()
	beam.Parent = edge
	table.insert(beams, beam)
end
for i, beam in beams do
	beam.Name = "YardEdge" .. i
	local a, b = points[i], points[i % 8 + 1]
	local start, finish = Vector3.new(a.X, 0, a.Y), Vector3.new(b.X, 0, b.Y)
	beam.Enabled = (finish - start).Magnitude > 0.01
	local direction = if beam.Enabled then (finish - start).Unit else Vector3.zAxis
	local across = Vector3.new(-direction.Z, 0, direction.X)
	local first, last = attachments[i * 2 - 1], attachments[i * 2]
	first.Name, last.Name = "YardEdge" .. i .. "Start", "YardEdge" .. i .. "End"
	first.CFrame, last.CFrame = CFrame.fromMatrix(start, Vector3.yAxis, across), CFrame.fromMatrix(finish, Vector3.yAxis, across)
	beam.Attachment0, beam.Attachment1 = first, last
	beam.CurveSize0, beam.CurveSize1 = 0, 0
end
local anchor = plot.Anchors.Yard
anchor.CFrame = edge.CFrame
anchor.Size = Vector3.new(30, anchor.Size.Y, 30)
plot.ChickenYard:SetAttribute("ExpansionShape", "T")
plot.ChickenYard:SetAttribute("ExpansionAxis", nil)
plot.ChickenYard:SetAttribute("ExpansionStartDepth", nil)
plot.ChickenYard:SetAttribute("ExpansionMaxDepth", nil)
plot.ChickenYard:SetAttribute("BuilderNote", "30x30 square starter. Upgrades extend the 30-stud center, then open an 84x25 back section behind the machines. HomePlotLayout.TeeYard owns the eight stages.")
history:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
return {starter = "30 x 30 square", maximum = "30-stud stem with an 84 x 25 back section", backup = backup:GetFullName()}
