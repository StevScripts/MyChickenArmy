-- Disposable live-VM driver. Character walks using the normal Humanoid.
local player=game.Players.LocalPlayer
if _G.EconomyFrameConnection then _G.EconomyFrameConnection:Disconnect() end
_G.EconomyFrames={}
_G.EconomyFrameConnection=game:GetService('RunService').RenderStepped:Connect(function(dt)
 local label=player:GetAttribute('EconomyTestRun')
 if label then
  local list=_G.EconomyFrames[label] or {};_G.EconomyFrames[label]=list
  if #list<20000 then table.insert(list,dt*1000) end
 end
end)
_G.EconomyWalking=true
task.spawn(function()
 while _G.EconomyWalking do
  local target=player:GetAttribute('EconomyTestDestination')
  local character=player.Character
  local humanoid=character and character:FindFirstChildOfClass('Humanoid')
  if target and humanoid then humanoid:MoveTo(target) end
  task.wait(0.15)
 end
end)
return 'Normal walking and per-session render timings enabled'
