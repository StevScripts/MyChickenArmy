-- This script handles cloning of action frames for each example

local loadExampleEvent: RemoteEvent = game.ReplicatedStorage.Remotes.LoadExampleEvent

loadExampleEvent.OnClientEvent:Connect(function(example)
	-- Remove old action frames
	for _, child in script.Parent:GetChildren() do
		if child:IsA("Frame") and child.Name ~= "ActionClonables" then
			child:Remove()
		end
	end
	
	-- Clone new action frame and enable its scripts
	local newActionFrame: Frame = script.Parent.ActionClonables:FindFirstChild(example):Clone()
	newActionFrame.Parent = script.Parent
	for _, child in newActionFrame:GetChildren() do
		if child:IsA("LocalScript") then
			child.Enabled = true
		end
	end
end)
