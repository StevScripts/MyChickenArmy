-- This script changes StarterCharacter to a given user ID in Character2 Example

local changeCharacterEvent: RemoteEvent = game.ReplicatedStorage.Remotes.ChangeCharacterEvent
local loadExampleEvent: RemoteEvent = game.ReplicatedStorage.Remotes.LoadExampleEvent

local currentUserIDNumber: NumberValue = game.ReplicatedStorage.CurrentUserIDNumber

changeCharacterEvent.OnServerEvent:Connect(function(plr, usedId: number)
	-- Clear StarterCharacters which aren't the original one
	for _, child in game.StarterPlayer:GetChildren() do
		if child:IsA("Model") and child.Name == "StarterCharacter" then
			if child:GetAttribute("Original") then continue end
			child:Destroy()
		end
	end
	
	local character = game.Players:CreateHumanoidModelFromUserId(usedId)
	
	-- If character is R6 then create a new rig that is R15
	if character:FindFirstChild("Torso") then
		character:Destroy()
		character = script.DefaultR15Rig:Clone()
		local humanoid: Humanoid = character:WaitForChild("Humanoid")
		local description: HumanoidDescription = game.Players:GetHumanoidDescriptionFromUserId(usedId)
		
		-- Character has to be parented to workspace before applying description
		-- Not sure if there is a better way of handling this
		character.Parent = workspace
		humanoid:ApplyDescription(description)
		character.Parent = game.StarterPlayer
	end
	
	character.Name = "StarterCharacter"
	character.Parent = game.StarterPlayer
	
	plr:LoadCharacter()

	-- Update action list
	currentUserIDNumber.Value = usedId
	loadExampleEvent:FireClient(plr, "Character2")
end)