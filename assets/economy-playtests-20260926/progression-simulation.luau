-- Accelerated economy experiment using current server modules, no live profiles.
-- A perfect full-yard sweep every 20s (casual: 60s) and 3s rolls abstract movement.
-- Not a human playtest or a battle/retention prediction.
local Server=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Session=require(Server.PlayerSession)
local Rolls=require(Server.RollService)
local Army=require(Server.ArmyService)
local Upgrades=require(Server.UpgradeService)
local Eggs=require(Server.EggService)
local Offline=require(Server.OfflineCash)
local Rules=require(Shared.Rules)
local Catalog=require(Shared.PetCatalog)
local Shop=require(Shared.ShopCatalog)
local UpgradeCatalog=require(Shared.UpgradeCatalog)
local function run(seed,scenario)
 local s=Session.new(-1000-seed,'Economy simulation',1)
 s.loaded=true;s.saveStatus='simulation';s.plotExpansionAvailable=true;s.rollSlotLimit=6
 if scenario=='LowRobux' then s.entitlements.DoubleEggSpawn=true end
 if scenario=='AllPasses' or scenario=='AllItems' then
  for _,key in Shop.Order do s.entitlements[key]=true end
  s.paidRandomAllowed=true
 end
 if scenario=='CashPack' then s:Credit(Shop.Products.PocketCoins.coins,'debug') end
 if scenario=='AllItems' then for _,p in Shop.Products do if p.enabled~=false and p.coins then s:Credit(p.coins,'debug') end end end
 local pad=Instance.new('Part');pad.Size=Vector3.new(10,1,10);pad.Anchored=true
 local world={plots={{}},PetPosition=function() return Vector3.zero end,
  ReturnPosition=function() return Vector3.zero end,PlotFrame=function() return CFrame.new() end,
  EggDeposit=function() return pad,s.userId end}
 local e=Eggs.new(world);local rolls=Rolls.new();rolls.random=Random.new(seed)
 local upgrades=Upgrades.new(world,rolls)
 upgrades.CanUse=function() return true end -- Abstract walking, retain transaction checks.
 local out={scenario=scenario,seed=seed,startCash=s.coins,milestones={},snapshots={},purchases=0,upgrades=0,rolls=0,merges=0,maxDrops=0}
 local function rate() return s:EarnedAmount(s:Income()*s:EggProductionMultiplier(),'eggs') end
 local function mark(key,t) if not out.milestones[key] then out.milestones[key]=t end end
 local function snap(t)
  local y=e:Yard(s);local pending=s.eggCarry.value+s.eggProcessor.readyValue
  for _,d in y.drops do pending+=d.value end
  for _,l in y.layers do pending+=l.value end
  table.insert(out.snapshots,{seconds=t,cash=s.coins,pending=s:EarnedAmount(pending,'eggs'),earned=s.passiveEarned,
   count=s:Count(),rate=rate(),eggValue=s.incomeLevel,eggSpeed=s.eggSpeedLevel,army=s:Capacity(),
   rollSlots=s.rollSlotCount,plotSize=s.plotSizeLevel,luck=s.luck,power=Rules.Power(s:Lineup()),
   offline8h=Offline.Reward({at=1,rate=Offline.Rate(s)},28801,0).amount})
 end
 assert(rolls:Buy(s,s.offer.id,0));out.purchases=1
 local nextRoll=1
 for t=1,3600 do
  -- Yield periodically so Studio remains inspectable during accelerated work.
  if t%120==0 then task.wait() end
  e:Produce(s,1,t);local y=e:Yard(s);out.maxDrops=math.max(out.maxDrops,#y.drops)
  -- Complete claims from the previous sweep, then walk across both sale pads.
  e:SettleClaims(s,y,t,false)
  if s.eggCarry.count>0 then
   e:Deposit(s,pad.Position,t)
   e:ProcessAndClaim(s,pad.Position,1,t,true,Vector3.new(1,0,0))
  end
  local interval=if scenario=='CasualFree' then 60 else 20
  if t%interval==0 then
   for _,d in y.drops do if not d.claimAt and t>=d.readyAt then e:Claim(y,d,t,'player',Vector3.zero) end end
  end
  local before=s.coins
  local candidates={}
  local currentRate=rate()
  local offers=upgrades:Offers(s)
  local function candidate(key,gain)
   local offer=offers[key]
   if offer and offer.price and offer.unlocked and gain>0 and s.coins>=offer.price then
    table.insert(candidates,{key=key,offer=offer,roi=offer.price/gain})
   end
  end
  candidate('EggValue',currentRate/(4+s.incomeLevel))
  local nextSpeed=UpgradeCatalog.EggSpeedRates[s.eggSpeedLevel+2]
  if nextSpeed then candidate('EggSpeed',currentRate*(nextSpeed/UpgradeCatalog.EggSpeedRates[s.eggSpeedLevel+1]-1)) end
  table.sort(candidates,function(a,b)return a.roi<b.roi end)
  local chickenRoi=600/((4+s.incomeLevel)/4*s:EggProductionMultiplier()*(s.entitlements.DoubleCash and 2 or 1))
  if candidates[1] and (candidates[1].roi<=chickenRoi or s:Count()>=s:CollectionLimit()) then
   local best=candidates[1]
   if upgrades:Buy(nil,s,best.key,best.offer.level,best.offer.price) then
    out.upgrades+=1;mark('firstUpgrade',t)
   end
  end
  -- Buy convenience/combat tracks from surplus; never use camp prerequisites.
  if t%10==0 then
   for _,key in {'PlotSize','RollSlots','ArmySize','Luck'} do
    local offer=upgrades:Offers(s)[key]
    local wanted=key=='PlotSize' and s:Count()>=s:CollectionLimit()-2
     or key=='RollSlots' and s:Count()>=8 or key=='ArmySize' and s:Count()>=s:Capacity()+2
     or key=='Luck' and s:Count()>=20
    if wanted and offer.price and offer.unlocked and s.coins>=offer.price*3 then
     if upgrades:Buy(nil,s,key,offer.level,offer.price) then out.upgrades+=1;mark('firstUpgrade',t) end
    end
   end
   s.rollSlotCount=math.min(6,s.rollSlotsUnlocked)
  end
  if t>=s.rollRevealAt then
   local available={}
   for _,offer in s.offers do if offer.price<=s.coins then table.insert(available,offer) end end
   table.sort(available,function(a,b)return a.price>b.price end)
   for _,offer in available do
    if s:Count()>=s:CollectionLimit() then
     if scenario=='MergeEarly' then
      local options=Army.MergeOptions(s)
      if options[1] then
       local option=options[1]
       if Army.Merge(s,option.petIds[1],option.petIds[2],option.petIds[3],option.level) then out.merges+=1 end
      end
     else
      local weakest,weakestRate
      for id,p in s.pets do
       local candidateRate=Rules.EggRate(p.species,1,p.level)
       if not weakest or candidateRate<weakestRate then
        local eligible=s:SaleEligibility(id)
        if eligible then weakest=p;weakestRate=candidateRate end
       end
      end
      if weakest and Rules.EggRate(offer.species,1,offer.level)>Rules.EggRate(weakest.species,1,weakest.level)*1.5 then
       Army.Sell(s,{weakest.id},true,Rules.SellValue(weakest.investment))
      end
     end
    end
    if rolls:Buy(s,offer.id,t) then
     out.purchases+=1;mark('firstNormalRecruit',t)
     if Catalog[offer.species].rarity=='Rare' then mark('firstRare',t) end
     if Catalog[offer.species].rarity=='Epic' then mark('firstEpic',t) end
     if Catalog[offer.species].rarity=='Legendary' then mark('firstLegendary',t) end
     if Catalog[offer.species].rarity=='Mythic' then mark('firstMythic',t) end
    end
   end
  end
  if scenario=='MergeEarly' and t%10==0 then
   local options=Army.MergeOptions(s)
   if options[1] then local a=options[1];if Army.Merge(s,a.petIds[1],a.petIds[2],a.petIds[3],a.level) then out.merges+=1 end end
  end
  if t>=nextRoll then rolls:Roll(s,t);out.rolls+=1;nextRoll=t+3 end
  if s:Count()>=10 then mark('tenChickens',t) end
  if rate()>=100 then mark('100cashPerSecond',t) end
  if rate()>=1000 then mark('1000cashPerSecond',t) end
  if s.passiveEarned>=10000 then mark('10000earned',t) end
  if s.passiveEarned>=100000 then mark('100000earned',t) end
  if s.passiveEarned>=1000000 then mark('1000000earned',t) end
  if t==180 or t==600 or t==1800 or t==3600 then snap(t) end
 end
 pad:Destroy()
 return out
end
_G.EconomySimulationResults=_G.EconomySimulationPartial or {}
_G.EconomySimulationPartial=nil
_G.EconomySimulationStop=false
_G.EconomySimulationRunning=true
_G.EconomySimulationError=nil
task.spawn(function()
 local ok,err=pcall(function()
  for _,scenario in {'Free','LowRobux','AllPasses','CashPack','AllItems','CasualFree','MergeEarly'} do
   for seed=1,8 do
    if _G.EconomySimulationStop then return end
    local exists=false
    for _,r in _G.EconomySimulationResults do if r.scenario==scenario and r.seed==260900+seed then exists=true;break end end
    if not exists then table.insert(_G.EconomySimulationResults,run(260900+seed,scenario)) end
    task.wait()
   end
  end
 end)
 _G.EconomySimulationError=not ok and tostring(err) or nil
 _G.EconomySimulationRunning=false
end)
return 'Started 56 one-hour simulations; results in _G.EconomySimulationResults'
