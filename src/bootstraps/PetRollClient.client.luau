--!strict
-- Hide Edit-mode previews before loading the game controllers.
local gui=game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("PetRollGui")
local layouts=gui:FindFirstChild("MenuLayouts")
if layouts then layouts.Visible=false end
local PetRoll=script.Parent:WaitForChild("PetRoll")
-- October 27 (WS6, docs/team/MOBILE_PERFORMANCE_20261027.md): the performance tier first
-- (every presentation budget reads it), then analytics before the app, so the first
-- report (4 s) and the load phases arrive even if the player leaves while loading.
pcall(function() require(PetRoll:WaitForChild("PerfTier")).Start() end)
local okAnalytics,AnalyticsClient=pcall(require,PetRoll:WaitForChild("AnalyticsClient"))
local function phase(name:string)
	if okAnalytics then pcall(AnalyticsClient.Track,"load.phase",name,time()) end
end
-- Device/performance/error reports for server analytics; never blocks the game.
if okAnalytics then task.spawn(AnalyticsClient.Start) end
phase("boot")
local LoadingController=require(PetRoll:WaitForChild("LoadingController"))
local loading=LoadingController.new(gui)
local AppController=require(PetRoll:WaitForChild("AppController"))
local app=AppController.new()
app:Start()
phase("app")
loading:Bind(app)
if game:GetService("RunService"):IsStudio() and game:GetService("ReplicatedStorage").PetRoll:GetAttribute("AcceptanceTest") then
	task.spawn(function() require(PetRoll.AcceptanceClient).Run(app) end)
end
