-- Run in the live server after capturing _G.EconomyTestServer.
-- Actual elapsed time, physical walks, production and validated requests.
local g=assert(_G.EconomyTestServer)
local player=game.Players:GetPlayers()[1]
local s=g.sessions[player.UserId]
assert(s.saveStatus=='studio-session')
local Rules=require(game.ReplicatedStorage.PetRoll.Shared.Rules)
local Layout=require(game.ReplicatedStorage.PetRoll.Shared.HomePlotLayout)
local Catalog=require(game.ReplicatedStorage.PetRoll.Shared.PetCatalog)
local runId=9100
_G.EconomyLiveRuns=_G.EconomyLiveRuns or {}
_G.EconomyLiveRunning=true
local function request(action,args)
 runId+=1;args=args or {};args.action=action;args.id=runId
 g:Handle(player,args)
end
task.spawn(function()
 local ok,err=pcall(function()
 for _,test in _G.EconomyRunQueue or {{name='Free',preset='Free',seconds=180},{name='LowRobux',preset='LowRobux',seconds=180},
  {name='AllPasses',preset='AllPasses',seconds=180},{name='CashPack',preset='CashPack',seconds=180},
  {name='AllItems',preset='AllItems',seconds=180},{name='CasualFree',preset='Free',seconds=180,casual=true}} do
  if not _G.EconomyLiveRunning then break end
  request('Debug',{command='FreshEconomy',argument=test.preset})
  -- Identical random stream, with the real paid-luck distribution when applicable.
  g.rolls.random=Random.new(260926)
  g.world:UpdateSession(s)
  player.Character:PivotTo(g.world:SpawnFrame(s.plotIndex))
  local started=os.clock()
  local result={name=test.name,seconds=test.seconds,startCash=s.coins,events={},samples={},walkTimeouts=0,walkFailures={}}
  table.insert(_G.EconomyLiveRuns,result)
  player:SetAttribute('EconomyTestRun',test.name)
  local frame=g.world:PlotFrame(s.plotIndex)
  local plot=g.world.plots[s.plotIndex]
  local function elapsed() return os.clock()-started end
  local function alive() return elapsed()<test.seconds and _G.EconomyLiveRunning end
  local function sample()
   local snap=s:Snapshot(os.clock());local eggs=g.eggs:Snapshot(s,os.clock())
   table.insert(result.samples,{t=elapsed(),cash=s.coins,earned=s.passiveEarned,count=s:Count(),
    cashPerSecond=snap.income,eggsPerSecond=snap.homeEggsPerSecond,bag=eggs.carriedValue,
    ground=eggs.value,ready=eggs.processor.readyCash,drops=#eggs.drops,capacity=s:Capacity(),
    eggValue=s.incomeLevel,eggSpeed=s.eggSpeedLevel,rollSlots=s.rollSlotCount})
  end
  local function go(position,tolerance,maxSeconds)
   if not alive() then return false end
   player:SetAttribute('EconomyTestDestination',position)
   local deadline=os.clock()+(maxSeconds or 5)
   while alive() and os.clock()<deadline do
    local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
    if root and ((root.Position-position)*Vector3.new(1,0,1)).Magnitude<=(tolerance or 2) then return true end
    task.wait(0.15)
   end
   result.walkTimeouts+=1
   table.insert(result.walkFailures,{t=elapsed(),target=tostring(position),actual=tostring(player.Character.HumanoidRootPart.Position)})
   return false
  end
  local function localGo(x,z) return go(frame:PointToWorldSpace(Vector3.new(x,3.5,z))) end
  local function event(kind,before)
   table.insert(result.events,{t=elapsed(),kind=kind,cash=s.coins,spent=before and before-s.coins,count=s:Count()})
  end
  local function sell()
   local pad=g.world:EggDeposit(s.plotIndex)
   if pad then go(pad.Position,0.5);task.wait(0.8) end
   local board=g.eggs:Board(s);local cash=board and board:FindFirstChild('TouchPart',true)
   if cash then
    -- Walk across the payout pad; standing on it is intentionally insufficient.
    go(cash.Position-cash.CFrame.RightVector*2,0.4)
    go(cash.Position+cash.CFrame.RightVector*2,0.4)
    task.wait(0.25)
   end
  end
  local function collect()
   local yard=Layout.ForPlot(s.plotIndex)
   for _,xz in {{-0.7,-0.7},{0.7,-0.7},{0.7,0},{-0.7,0},{-0.7,0.7},{0.7,0.7}} do
    local cx=(yard.YardMinX+yard.YardMaxX)/2;local cz=(yard.YardMinZ+yard.YardMaxZ)/2
    localGo(cx+xz[1]*(yard.YardMaxX-yard.YardMinX)/2,cz+xz[2]*(yard.YardMaxZ-yard.YardMinZ)/2)
   end
   sell()
  end
  local function buyOffer(offer,slot)
   local podium=plot.stations[slot].podium
   local at=frame:PointToObjectSpace(podium.Position)
   localGo(at.X,at.Z-5)
   local before,count=s.coins,s:Count()
   request('Buy',{stationIndex=s.plotIndex,offerId=offer.id})
   if s:Count()>count then event('recruit:'..offer.species,before) end
  end
  -- The onboarding offer is deliberately cheaper than later common offers.
  buyOffer(s.offer,1)
  while alive() do
   if test.casual then
    player:SetAttribute('EconomyTestDestination',nil)
    local untilAt=math.min(started+test.seconds,os.clock()+35)
    while os.clock()<untilAt do task.wait(0.25) end
   end
   collect();sample()
   if not alive() then break end
   -- Economy-first purchase choice: value upgrade if its marginal return beats
   -- a new chicken, otherwise buy affordable recruits. No debug money or rolls.
   local offers=g.upgrades:Offers(s)
   local rate=s:Income()*s:EggProductionMultiplier()
   local value=offers.EggValue
   if value and value.price and s.coins>=value.price and value.price/math.max(rate/(4+s.incomeLevel),0.01)<600 then
    local board=g.upgrades.boards[1]
    local at=frame:PointToObjectSpace(board.screen.Position)
    localGo(at.X-5,at.Z)
    local before,level=s.coins,s.incomeLevel
    request('BoardUpgrade',{upgradeKey='EggValue',expectedLevel=value.level,expectedPrice=value.price})
    if s.incomeLevel>level then event('upgrade:EggValue',before) end
   end
   go(plot.station.leverBase.Position,4)
   for _=1,6 do
    if not alive() then break end
    local best,slot
    for i,offer in s.offers do if offer.price<=s.coins and (not best or offer.price>best.price) then best,slot=offer,i end end
    if best and s:Count()<s:CollectionLimit() then buyOffer(best,slot) end
    go(plot.station.leverBase.Position,4)
    request('Roll',{stationIndex=s.plotIndex})
    task.wait(2.55)
   end
   sample()
  end
  player:SetAttribute('EconomyTestDestination',nil)
  sample();result.elapsed=elapsed();result.finished=true
  result.entitlements=table.clone(s.entitlements)
  result.memoryMb=game:GetService('Stats'):GetTotalMemoryUsageMb()
  result.instanceCount=#workspace:GetDescendants()
 end
 end)
 player:SetAttribute('EconomyTestDestination',nil);player:SetAttribute('EconomyTestRun',nil)
 _G.EconomyLiveError=not ok and tostring(err) or nil
 _G.EconomyLiveRunning=false
end)
return 'Started the configured live profiles; inspect _G.EconomyLiveRuns'
