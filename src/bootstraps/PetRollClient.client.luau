--!strict
local AppController=require(script.Parent:WaitForChild("PetRoll"):WaitForChild("AppController"))
local app=AppController.new()
app:Start()
if game:GetService("RunService"):IsStudio() and game:GetService("ReplicatedStorage").PetRoll:GetAttribute("AcceptanceTest") then
	task.spawn(function() require(script.Parent.PetRoll.AcceptanceClient).Run(app) end)
end
