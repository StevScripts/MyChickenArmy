local g=assert(_G.EconomyTestServer)
local p=game.Players:GetPlayers()[1];local s=g.sessions[p.UserId]
assert(s.saveStatus=='studio-session' and not _G.EconomyLiveRunning)
_G.EconomyIdleResults={};_G.EconomyIdleRunning=true
task.spawn(function()
 local ok,err=pcall(function()
  for _,preset in {'Free','AllPasses'} do
   assert(g.debug:Run(p,s,'FreshEconomy',preset,os.clock()));g.world:UpdateSession(s)
   p:SetAttribute('EconomyTestDestination',nil)
   p.Character:PivotTo(g.world:SpawnFrame(s.plotIndex))
   local started=os.clock();local initial=s.coins
   task.wait(60)
   local eggs=g.eggs:Snapshot(s,os.clock())
   table.insert(_G.EconomyIdleResults,{preset=preset,seconds=os.clock()-started,
    walletChange=s.coins-initial,groundValue=eggs.value,bag=eggs.carriedValue,
    readyCash=eggs.processor.readyCash,roverEnabled=eggs.rover.enabled,groundDrops=#eggs.drops})
  end
 end)
 _G.EconomyIdleError=not ok and tostring(err) or nil;_G.EconomyIdleRunning=false
end)
return 'Two stationary 60-second comparisons started'
