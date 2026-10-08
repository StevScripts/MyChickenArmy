--!strict
-- Editable art references stay in the place file, outside every running game.
-- Mark any Workspace authoring reference with EditOnlyReference=true to keep it
-- editable in Studio but out of every player's world.
for _, item in workspace:GetChildren() do
 if item:GetAttribute("ChickenVFXWorkbench") == true or item:GetAttribute("EditOnlyReference") == true then
  item.Parent = game:GetService("ServerStorage")
 end
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
-- GameServer:Start binds the single shutdown path (save, rankings, then Destroy).
