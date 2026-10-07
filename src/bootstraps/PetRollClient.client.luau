--!strict
-- Hide Edit-mode previews before loading the game controllers.
local gui=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("PetRollGui")
local layouts=gui:FindFirstChild("MenuLayouts")
if layouts then layouts.Visible=false end
local LoadingController=require(script.Parent:WaitForChild("PetRoll"):WaitForChild("LoadingController"))
local loading=LoadingController.new(gui)
local AppController=require(script.Parent:WaitForChild("PetRoll"):WaitForChild("AppController"))
local app=AppController.new()
app:Start()
loading:Bind(app)
if game:GetService("RunService"):IsStudio() and game:GetService("ReplicatedStorage").PetRoll:GetAttribute("AcceptanceTest") then
	task.spawn(function() require(script.Parent.PetRoll.AcceptanceClient).Run(app) end)
end
