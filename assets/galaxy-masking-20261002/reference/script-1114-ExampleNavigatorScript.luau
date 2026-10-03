-- This script handles UI interactions

local UserInputService = game:GetService("UserInputService")

-- Hide Note and show ActionList and ExampleSelection
if script.Parent.Parent:FindFirstChild("Note") then script.Parent.Parent.Note.Visible = false end
script.Parent.Parent.ActionList.Visible = true
script.Parent.Visible = true

local plr = game.Players.LocalPlayer

local infoFrame: Frame = script.Parent.Parent.Parent.InfoFrame
local actionList: Frame = script.Parent.Parent.ActionList
local selectionFrame: Frame = script.Parent
local collapse: ImageButton = selectionFrame.Collapse
local info: ImageButton = selectionFrame.Info
local prevExample: TextButton = selectionFrame.Previous
local nextExample: TextButton = selectionFrame.Next
local exampleName: TextLabel = selectionFrame.ExampleName

local currentExample = 1 -- Index of current example
local exampleList = {"House", "Text", "Wavytext", "Character1", "Character2", "Image", "Paint", "Portal1", "Portal2", "Reflection"}

local loadExampleEvent: RemoteEvent = game.ReplicatedStorage.Remotes.LoadExampleEvent

-- Load "House" example
loadExampleEvent:FireServer(currentExample)

-- Toggle ActionList Frame visibility
local actionsOpen = true
collapse.MouseButton1Click:Connect(function()
	if actionsOpen then
		actionList.Visible = false
		collapse.ImageLabel.UIGradient.Rotation = -90
		actionsOpen = false
	elseif not actionsOpen then
		actionList.Visible = true
		collapse.ImageLabel.UIGradient.Rotation = 90
		actionsOpen = true
	end
end)

-- Toggle info screen visibility
local infoOpen = false
info.MouseButton1Click:Connect(function()
	if infoOpen then
		infoFrame.Visible = false
		infoOpen = false
	elseif not infoOpen then
		infoFrame.Visible = true
		infoOpen = true
	end
end)

local function LoadPreviousExample()
	currentExample = 1 + (currentExample - 2) % #exampleList
	exampleName.Text = exampleList[currentExample] .. " Example"
	loadExampleEvent:FireServer(currentExample)
end

local function LoadNextExample()
	currentExample = 1 + currentExample % #exampleList
	exampleName.Text = exampleList[currentExample] .. " Example"
	loadExampleEvent:FireServer(currentExample)
end

-- Switch to previous example
prevExample.MouseButton1Click:Connect(function()
	LoadPreviousExample()
end)

-- Switch to next example
nextExample.MouseButton1Click:Connect(function()
	LoadNextExample()
end)

-- Connect keybinds for switching between examples
UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then return end
	
	if input.KeyCode == Enum.KeyCode.E then
		LoadNextExample()
	elseif input.KeyCode == Enum.KeyCode.Q then
		LoadPreviousExample()
	end
end)