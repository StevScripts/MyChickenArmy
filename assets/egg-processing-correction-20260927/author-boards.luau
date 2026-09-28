-- Re-runnable Edit recipe. Keeps original geometry, fonts, textures and input pads.
assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning())
local home = workspace.MyChickenArmyMap["03_HomePlots"]
local original = assert(home:FindFirstChild("EggCollectionBoard"))
local sourcePad = home.Plot1.Shops.EggDeposit.sellpart
local recovery = game.ServerStorage:FindFirstChild("EggProcessingCorrectionRecovery20260927")
if not recovery then
	recovery = Instance.new("Folder")
	recovery.Name = "EggProcessingCorrectionRecovery20260927"
	recovery.Parent = game.ServerStorage
end
if not recovery:FindFirstChild("EggCollectionBoard") then original:Clone().Parent = recovery end

local results = {}
for index = 1, 6 do
	local plot = assert(home:FindFirstChild("Plot" .. index))
	local pad = plot.Shops.EggDeposit.sellpart
	local board = if index == 1 then original else plot:FindFirstChild("EggCollectionBoard")
	if not board then
		board = original:Clone()
		for _, part in board:GetDescendants() do
			if part:IsA("BasePart") then
				part.CFrame = pad.CFrame * sourcePad.CFrame:ToObjectSpace(part.CFrame)
			end
		end
		board.Parent = plot
	end
	board:SetAttribute("PlotIndex", index)
	local content = board.Screen.SurfaceGui.EggSellingBoard.Content
	content.QueueLabel.Text = "EGGS QUEUED"
	content.QueuedCount.Text = "0"
	content.RateLabel.Text = "Selling speed"
	content.Rate.Text = "4 eggs/sec"
	for _, name in {"Upgrade", "FinishNow"} do
		local control = content:FindFirstChild(name)
		if control and control:IsA("GuiObject") then
			control.Visible = true
			control.Active = true
			control.Selectable = true
		end
	end
	board.Text.BillboardGui.name.Text = "EGGS SELLING"
	table.insert(results, {plot = index, board = board:GetFullName(),
		cashPad = board.CollectionPart.TouchPart:GetFullName(),
		inputPad = pad:GetFullName(), headlineSize = content.QueuedCount.TextSize})
end
return results
