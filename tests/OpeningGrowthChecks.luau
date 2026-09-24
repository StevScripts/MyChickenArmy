-- Isolated opening transactions. Does not read or write player profiles.
local S=game.ServerStorage.PetRoll
local Session=require(S.PlayerSession)
local Army=require(S.ArmyService)
local Rolls=require(S.RollService)
local Config=require(game.ReplicatedStorage.PetRoll.Shared.Config)
local Checks={}
function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,detail=pcall(fn);table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
 end
 test("Fourth fighter uses existing prices and leaves 600 coins",function()
  local s=Session.new(-7101,"Opening fixture",1);s.loaded=true
  assert(s.coins==2400 and #s:Lineup()==3)
  assert(Army.Expand(s));assert(s.coins==1200 and s.capacity==4)
  local ok,_,id,recruit=Rolls.new():Buy(s,s.offer.id,0)
  assert(ok and s.coins==600 and s:Count()==4 and #s:Lineup()==4)
  assert(recruit.assignment=="Added" and recruit.selectedBefore==3 and recruit.selectedAfter==4)
  assert(table.find(s:BestPetIds(),id) and s:Income()==20)
  return "2,400 → 1,200 → 600; four actual selected fighters, home income 20/sec"
 end)
 test("Buying before capacity preserves the recruit and later fields it",function()
  local s=Session.new(-7102,"Reverse fixture",1);s.loaded=true
  local ok,_,id,recruit=Rolls.new():Buy(s,s.offer.id,0)
  assert(ok and recruit.assignment=="Reserve" and #s:Lineup()==3)
  assert(Army.Expand(s));assert(s.coins==600 and #s:Lineup()==4 and table.find(s:BestPetIds(),id))
  return "Optional buy-first path remains usable"
 end)
 test("An expensive offer waits or can be replaced by another free roll",function()
  local s=Session.new(-7103,"Offer fixture",1);s.loaded=true
  local rolls=Rolls.new();assert(Army.Expand(s))
  s.debugNext="Bucket";assert(rolls:Roll(s,0))
  local offer=s.offer.id
  assert(not rolls:Buy(s,offer,Config.RollRevealSeconds+0.1))
  assert(s.coins==1200 and s.offer.id==offer)
  s.debugNext="Duck";assert(rolls:Roll(s,Config.RollCooldown+0.1))
  assert(s.coins==1200 and s.offer.id~=offer)
  assert(rolls:Buy(s,s.offer.id,Config.RollCooldown+Config.RollRevealSeconds+0.2))
  assert(s.coins==600 and #s:Lineup()==4)
  return "Unaffordable offer is preserved on failed Buy; reroll is free and optional"
 end)
 return results
end
return Checks
