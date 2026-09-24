-- Transaction evidence for client feedback; no live player or saved profile.
local Session=require(game.ServerStorage.PetRoll.PlayerSession)
local Rolls=require(game.ServerStorage.PetRoll.RollService)
local Checks={}
function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,detail=pcall(fn);table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
 end
 test("Stronger full-squad purchase is a replacement, never count growth",function()
  local s=Session.new(-7111,"Replacement fixture",1);s.loaded=true;s.coins=10000
  s.offer.species="Bucket"
  local ok,_,id,r=Rolls.new():Buy(s,s.offer.id,0)
  assert(ok and r.assignment=="Replacement" and r.selectedBefore==3 and r.selectedAfter==3)
  assert(table.find(s:BestPetIds(),id) and r.pendingBattleId==nil)
  return "Best squad improves at constant count"
 end)
 test("Finite contest purchase defers while keeping the new chicken at home",function()
  local s=Session.new(-7112,"Deferred fixture",1);s.loaded=true;s.coins=10000
  s.armyState="Fighting";s.outgoing="contest";s.offer.species="Bucket"
  for _,id in s:BestPetIds() do s.awayPets[id]=true end
  local ok,message,id,r=Rolls.new():Buy(s,s.offer.id,0,{battleId="contest",phase="Fight",locked=true})
  assert(ok and r.assignment=="Replacement" and r.deferredUntilContestEnds and r.pendingBattleId=="contest")
  assert(s:IsPetHome(id) and s:FindSlot(id)==nil)
  assert(message:find("after this fight",1,true))
  return "New best chicken is owned/home; no immediate battlefield-arrival claim"
 end)
 test("Returning army does not receive an obsolete pending battle ID",function()
  local s=Session.new(-7113,"Return fixture",1);s.loaded=true;s.coins=10000
  s.armyState="Returning";s.offer.species="Bucket"
  local ok,message,_,r=Rolls.new():Buy(s,s.offer.id,0,{battleId="return",phase="Returning",locked=false})
  assert(ok and r.pendingBattleId==nil and not r.deferredUntilContestEnds)
  assert(message:find("gets home",1,true))
  return "Waits for next deployment rather than announcing arrival in old encounter"
 end)
 test("An offer cannot grant duplicate purchases or repeated growth",function()
  local s=Session.new(-7114,"Atomic fixture",1);s.loaded=true
  local rolls=Rolls.new();local offer=s.offer.id
  assert(rolls:Buy(s,offer,0));local balance,count=s.coins,s:Count()
  assert(not rolls:Buy(s,offer,0));assert(s.coins==balance and s:Count()==count)
  return "Consumed offer is rejected on retry"
 end)
 return results
end
return Checks
