-- Isolated probability and purchase checks. Never opens saved player profiles.
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Config=require(Shared.Config)
local Catalog=require(Shared.PetCatalog)
local Rules=require(Shared.Rules)
local Progression=require(Shared.Progression)
local Session=require(game.ServerStorage.PetRoll.PlayerSession)
local Rolls=require(game.ServerStorage.PetRoll.RollService)
local Checks={}

local function near(a,b)
 assert(math.abs(a-b)<1e-10,tostring(a).." differs from "..tostring(b))
end

local function rareFirstRoll(userId)
 local session=Session.new(userId,"Open roll fixture",1)
 session.loaded=true
 local rolls=Rolls.new()
 -- Inject the service RNG, not debugRandom: this exercises the ordinary first roll.
 rolls.random={NextNumber=function() return 1-1e-8 end}
 assert(session.offer.starter and session.offer.species=="Duck")
 assert(not session.tutorial.rolled and not session.tutorial.bought)
 assert(rolls:Roll(session,0))
 assert(session.offer.species=="StormDuck" and not session.offer.starter and not session.offer.debug)
 return session,rolls
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,detail=pcall(fn)
  table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
 end

 test("All chickens are selectable at every quality and luck level",function()
  for rank=1,Progression.Count() do
   for luck=0,#Config.LuckPrices do
    local odds,total,cumulative=Rules.Odds(luck,rank),0,0
    for _,species in Catalog.Order do
     local chance=odds[species]
     assert(chance>0 and chance<1,species.." has invalid odds")
     assert(Rules.Draw(luck,cumulative+chance/2,rank)==species,species.." cannot be drawn")
     cumulative+=chance;total+=chance
    end
    near(total,1)
   end
  end
  return "All ten outcomes reachable; normalized across four quality ranks and five luck levels"
 end)

 test("Fresh odds preserve the opening while higher boosts remain useful",function()
  local fresh=Rules.Odds(0,1)
  near(fresh.StormDuck,1/20040)
  near(fresh.Viking,9/1002)
  local opening=fresh.Duck+fresh.Mallard+fresh.Sailor+fresh.Bucket
  assert(opening>0.984 and opening<0.985)
  assert(Rules.Odds(0,4).StormDuck>fresh.StormDuck*100)
  assert(Rules.Odds(4,4).StormDuck>Rules.Odds(0,4).StormDuck)
  assert(Rules.Odds(1,1).StormDuck>fresh.StormDuck)
  return "Opening four retain 98.48%; stronger boosts and luck improve rare chances"
 end)

 test("The first manual roll can reveal Storm without a debug override",function()
  local session=rareFirstRoll(-7211)
  assert(session.tutorial.rolled and session.coins==Config.StartingCoins)
  near(session.offer.chance,Rules.Odds(0,1).StormDuck)
  return "Guaranteed starter offer retained; first actual roll uses the full distribution"
 end)

 test("An unaffordable Storm offer waits and retains its original chance",function()
  local session,rolls=rareFirstRoll(-7212)
  local id,chance,coins,count=session.offer.id,session.offer.chance,session.coins,session:Count()
  assert(Catalog.StormDuck.price==192000)
  assert(not rolls:Buy(session,id,Config.RollRevealSeconds+1))
  assert(session.offer.id==id and session.coins==coins and session:Count()==count)
  session.luck=1
  session.firstWins[1],session.firstWins[2]=true,true
  assert(session:UnlockProgress())
  assert(session.offer.id==id and session.offer.tier==1 and session.offer.luck==0)
  near(session:Snapshot(100).offer.chance,chance)
  return "No discount, timeout or loss on insufficient coins; automatic boost preserves the revealed odds"
 end)

 test("A beginner can buy and save the rare chicken at its normal price",function()
  local session,rolls=rareFirstRoll(-7213)
  session.coins=Catalog.StormDuck.price+123
  local ok,_,petId=rolls:Buy(session,session.offer.id,Config.RollRevealSeconds+1)
  assert(ok and session.coins==123 and session.offer==nil)
  assert(session.pets[petId].species=="StormDuck" and session.pets[petId].investment==192000)
  local data=session:ToData()
  assert(data.offer==nil and data.promotion==1)
  local restored=Session.new(-7214,"Restore fixture",1)
  assert(restored:LoadData(data))
  assert(restored.pets[petId].species=="StormDuck" and restored.promotion==1)
  return "Exact price deducted; existing profile schema accepts an early rare chicken"
 end)

 test("Optional reroll remains free and replaces the waiting offer",function()
  local session,rolls=rareFirstRoll(-7215)
  local id,coins=session.offer.id,session.coins
  rolls.random={NextNumber=function() return 0 end}
  assert(rolls:Roll(session,Config.RollCooldown+1))
  assert(session.offer.id~=id and session.offer.species=="Duck" and session.coins==coins)
  return "Waiting is optional; rolling again does not charge coins"
 end)

 test("Tiny positive odds never render as zero",function()
  local text=Rules.FormatOdds(Rules.Odds(0,1).StormDuck)
  assert(text=="≈ 1 in 20040")
  for rank=1,Progression.Count() do
   for _,chance in Rules.Odds(0,rank) do
    local label=Rules.FormatOdds(chance)
    assert(label~="0.0%" and label~="0.00%" and label~="Unavailable")
   end
  end
  return "Rare labels preserve meaningful odds instead of rounding them to zero"
 end)
 return results
end

return Checks
