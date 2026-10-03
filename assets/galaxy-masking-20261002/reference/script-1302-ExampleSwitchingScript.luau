-- This script handles example changing on server side

local loadExampleEvent: RemoteEvent = game.ReplicatedStorage.Remotes.LoadExampleEvent

local exampleList = {"House", "Text", "Wavytext", "Character1", "Character2", "Image", "Paint", "Portal1", "Portal2", "Reflection"}
local starterCharacter = game.StarterPlayer.StarterCharacter

local previousExample = nil

loadExampleEvent.OnServerEvent:Connect(function(plr: Player, exampleIndex: number)
	-- Parent old example back to ServerStorage
	for _, child in game.StarterGui.MaskGui:GetChildren() do
		if child:IsA("ViewportFrame") then
			child.Parent = game.ServerStorage
		end
	end
	
	local currentExample = exampleList[exampleIndex]
	
	-- Parent new example to MaskGui
	local newExample: ViewportFrame = game.ServerStorage:FindFirstChild(currentExample .. "Viewport")
	if newExample then newExample.Parent = game.StarterGui.MaskGui end
	
	-- Don't use pre-made StarterCharacter in Character2 example
	if currentExample == "Character2" then
		starterCharacter.Parent = game.ServerStorage
	elseif previousExample == "Character2" then
		-- Clear StarterCharacters which aren't the original one
		for _, child in game.StarterPlayer:GetChildren() do
			if child:IsA("Model") and child.Name == "StarterCharacter" then
				if child:GetAttribute("Original") then continue end
				child:Destroy()
			end
		end
		game.ReplicatedStorage.CurrentUserIDNumber.Value = 0
		starterCharacter.Parent = game.StarterPlayer
	end
	
	-- Reload player's character
	plr:LoadCharacter()
	
	-- Update action list
	loadExampleEvent:FireClient(plr, currentExample)
	previousExample = currentExample
end)