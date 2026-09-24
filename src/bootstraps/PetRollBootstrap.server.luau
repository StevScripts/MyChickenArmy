--!strict
-- Editable art references stay in the place file, outside every running game.
local vfxWorkbench = workspace:FindFirstChild("ChickenVFX_Workbench")
if vfxWorkbench and vfxWorkbench:GetAttribute("ChickenVFXWorkbench") == true then
 vfxWorkbench.Parent = game:GetService("ServerStorage")
end
local modules=game:GetService("ServerStorage"):WaitForChild("PetRoll",15)
assert(modules,"PetRoll server modules are missing")
local entry=modules:WaitForChild("GameServer",15)
assert(entry,"PetRoll GameServer is missing")
local acceptance=false
if game:GetService("RunService"):IsStudio() then
 local args=game:GetService("StudioTestService"):GetTestArgs()
 acceptance=type(args)=="table" and args.suite=="PetRollAcceptance"
end
workspace:SetAttribute("PetRollAcceptanceMode",acceptance)
game:GetService("ReplicatedStorage").PetRoll:SetAttribute("AcceptanceTest",acceptance)
local server=require(entry).new()
server:Start()
-- Studio-only read-only inspection, enabled explicitly for local acceptance checks.
if game:GetService("RunService"):IsStudio() and workspace:GetAttribute("PetRollQAEnabled") then
 local qa=Instance.new("BindableFunction");qa.Name="PetRollQA";qa.Parent=game.ServerStorage
 qa.OnInvoke=function(userId)
  local session=server.sessions[userId];if not session then return nil end
  local roaming={};for id,entry in server.world.plots[session.plotIndex].roaming do roaming[id]={position=entry.position,moving=entry.moving} end
  return {state=session:Snapshot(os.clock()),loaded=session.loaded,closing=session.closing,lost=session.saveLost,roaming=roaming}
 end
end
if acceptance then task.spawn(function() require(game.ServerStorage.PetRollTests.LiveAcceptance).Run(server) end) end
game:BindToClose(function() server:Destroy() end)
