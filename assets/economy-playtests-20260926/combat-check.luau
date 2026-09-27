-- Real battle actors and real elapsed time. Each case has the same six birds.
-- Avatar approach is excluded: only the test character is placed at the command.
local g=assert(_G.EconomyTestServer)
local p=game.Players:GetPlayers()[1];local s=g.sessions[p.UserId]
assert(s.saveStatus=='studio-session')
local Command=require(game.ReplicatedStorage.PetRoll.Shared.CampCommand)
_G.EconomyCombatResults={};_G.EconomyCombatRunning=true
task.spawn(function()
 local ok,err=pcall(function()
  for _,preset in {'Free','AllPasses'} do
   assert(g.debug:Run(p,s,'FreshEconomy',preset,os.clock()))
   for _=1,3 do s:AddPet('Duck',1) end
   s:RefreshArmy();g.world:UpdateSession(s)
   -- A cancelled holding army retains its normal camp-clear grace briefly.
   local releaseStart=os.clock()
   while g.battles.campBusy[tostring(s.plotIndex)..':1'] and os.clock()-releaseStart<30 do task.wait(.2) end
   local camp=g.world.lanes[s.plotIndex][1].folder
   local anchor=Command.Anchor(camp)
   p.Character:PivotTo(anchor.CFrame*CFrame.new(0,4,0))
   local started=os.clock();local initial=s.coins
   g:Handle(p,{id=99001,action='Attack',targetId='camp:1'})
   local result={preset=preset,owned=s:Count(),deployed=#s:Lineup(),started=s.outgoing~=nil,phases={}}
   table.insert(_G.EconomyCombatResults,result)
   local lastPhase
   while os.clock()-started<150 do
    local battle=g.battles.battles[s.outgoing]
    local phase=battle and battle.phase or s.armyState
    if phase~=lastPhase then table.insert(result.phases,{phase=phase,seconds=os.clock()-started});lastPhase=phase end
    if s.firstWins[1] then result.winSeconds=os.clock()-started;break end
    if not battle and os.clock()-started>3 then break end
    task.wait(0.2)
   end
   result.elapsed=os.clock()-started;result.won=s.firstWins[1]==true
   result.earned=s.coins-initial;result.enemyKills=s.enemyKills
   result.homeIncome=s:Snapshot(os.clock()).income
   g.battles:CancelPlayer(s.userId,os.clock())
  end
 end)
 _G.EconomyCombatError=not ok and tostring(err) or nil;_G.EconomyCombatRunning=false
end)
return 'Two real camp encounters started'
