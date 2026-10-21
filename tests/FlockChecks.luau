-- October 20 Flock and storage (docs/team/FLOCK_STORAGE.md). Isolated sessions only;
-- no DataStore or live-world access. Flock Size is stubbed per session (s.FlockSize).
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Eggs=require(Server.EggService)
local Offline=require(Server.OfflineCash)
local Tuning=require(Shared.OfflineCashConfig)
local Checks={}

local function near(a,b,why)
 assert(math.abs(a-b)<1e-6,(why or "Values differ")..": "..tostring(a).." ~= "..tostring(b))
end

-- Five chickens from weakest to strongest layer, Flock Size 3, no Army picks.
local function flockSession(id)
 local s=Session.new(id,"Flock",1);s.loaded=true
 s.tutorial.guideCompleted=true;s.tutorial.bought=true
 for petId in s.pets do s.pets[petId]=nil end
 s.slots,s.armySelection={},{}
 s.researchEffects=table.clone(s.researchEffects)
 local size=3
 s.FlockSize=function() return size end
 local pets={duck=s:AddPet("Duck",1),mallard=s:AddPet("Mallard",1),chunky=s:AddPet("Chunky",1),
  knight=s:AddPet("Knight",1),spare=s:AddPet("Duck",1)}
 return s,pets,function(n) size=n end
end

local function has(list,id) return table.find(list,id)~=nil end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,why=pcall(fn)
  table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
  print((if ok then "PASS " else "FAIL ")..name..(if ok then "" else " :: "..tostring(why)))
 end

 test("Only the Flock lays: the best layers, and income counts only them",function()
  local s,p=flockSession(-991)
  local flock=s:FlockIds()
  assert(#flock==3 and flock[1]==p.knight.id and has(flock,p.chunky.id) and has(flock,p.mallard.id),"Best layers")
  assert(not has(flock,p.duck.id) and not has(flock,p.spare.id),"Weaker chickens stay in storage")
  near(s:Income(),s:PetIncome(p.knight.id)+s:PetIncome(p.chunky.id)+s:PetIncome(p.mallard.id),"Income")
 end)

 test("Storage chickens lay no eggs",function()
  local s,p=flockSession(-992)
  local eggs=Eggs.new({});eggs.Lay=function() end
  for i=1,20 do eggs:Produce(s,0.5,i) end
  local layers=eggs:Yard(s).layers
  -- October 21 one egg = one egg: a layer tracks value/elapsed, not an egg count.
  local layer=layers[p.knight.id]
  assert(layer and (layer.value>0 or layer.elapsed>0),"A Flock chicken laid")
  assert(layers[p.duck.id]==nil and layers[p.spare.id]==nil,"A storage chicken laid")
 end)

 -- October 21 (owner): no Flock picks. Old requests are refused; Equip Best clears old picks.
 test("The Flock is always automatic; old picks are cleared by Equip Best",function()
  local s,p=flockSession(-993)
  assert(not Army.FlockEquip(s,p.duck.id),"Equip is refused")
  assert(not Army.FlockEquip(s,p.duck.id,p.knight.id),"Swap is refused")
  assert(not Army.FlockUnequip(s,p.knight.id),"Unequip is refused")
  assert(s.flockSelection==nil and s:FlockIds()[1]==p.knight.id,"Still the best layers")
  s.flockSelection={p.duck.id}
  assert(Army.FlockBest(s) and s.flockSelection==nil and s:FlockIds()[1]==p.knight.id,"Equip Best")
 end)

 test("A Flock chicken away with the Army gets a fill-in",function()
  local s,p=flockSession(-994)
  s.awayPets={[p.knight.id]=true}
  local laying=s:LayingIds()
  assert(#laying==3 and not has(laying,p.knight.id) and (has(laying,p.duck.id) or has(laying,p.spare.id)),"Automatic fill-in")
  assert(has(s:FlockIds(),p.knight.id),"Still in the Flock while away")
  s.flockSelection={p.knight.id,p.chunky.id,p.mallard.id}
  laying=s:LayingIds()
  assert(laying[1]~=p.knight.id and laying[2]==p.chunky.id and laying[3]==p.mallard.id,"The fill-in takes the away slot")
  s.awayPets={}
  assert(s:LayingIds()[1]==p.knight.id,"Back home, back in its slot")
 end)

 test("Flock Size growth fills new slots; a smaller size drops the last picks",function()
  local s,p,setSize=flockSession(-995)
  s.flockSelection={p.duck.id,p.mallard.id}
  assert(not s:RefreshFlock() and #s.flockSelection==2,"First check keeps the open slot")
  setSize(4);s:RefreshFlock()
  assert(#s.flockSelection==3 and s.flockSelection[3]==p.knight.id,"One new slot, best layer")
  setSize(2);s:RefreshFlock()
  assert(#s.flockSelection==2 and s.flockSelection[1]==p.duck.id and s.flockSelection[2]==p.mallard.id,"Shrink keeps the first picks")
  s.pets[p.duck.id],s.pets[p.mallard.id]=nil,nil;s:RefreshFlock()
  assert(s.flockSelection==nil,"No picks left goes back to automatic")
 end)

 -- October 21: Flock chickens sell too (the next best layer takes the slot); locked ones don't.
 test("Flock and storage chickens sell; locked and Army chickens don't",function()
  local s,p=flockSession(-996)
  local context=s:SaleContext()
  assert(s:SaleEligibility(p.knight.id,context),"Flock chicken")
  assert(s:SaleEligibility(p.duck.id,context),"Storage chicken")
  assert(Army.Favorite(s,nil,{p.duck.id,p.chunky.id},true) and p.duck.favorite and p.chunky.favorite,"Batch lock")
  local ok,why=s:SaleEligibility(p.duck.id)
  assert(not ok and why=="Locked chickens can't be sold.",tostring(why))
  assert(Army.Favorite(s,nil,{p.duck.id},false) and not p.duck.favorite,"Unlock")
  assert(not Army.Favorite(s,nil,{p.duck.id,p.duck.id},true),"Repeated ids are refused")
  s.armySelection={p.mallard.id}
  ok,why=s:SaleEligibility(p.mallard.id)
  assert(not ok and why=="Remove it from your Army first.",tostring(why))
 end)

 test("Offline earnings count only the Flock, plus Offline Coins",function()
  local s,p=flockSession(-997)
  local rate=Offline.Rate(s)
  assert(rate>0,"No offline rate")
  s:AddPet("Duck",1);near(Offline.Rate(s),rate,"A storage chicken changed the rate")
  s.awayPets={[p.knight.id]=true};near(Offline.Rate(s),rate,"An away Flock chicken still counts");s.awayPets={}
  s.researchEffects.offlineEfficiency=0.05
  near(Offline.Rate(s),rate*(Tuning.Efficiency+0.05)/Tuning.Efficiency,"Offline Coins")
  local checkpoint=Offline.Checkpoint(s,1000)
  near(checkpoint.bonus,0.05);near(checkpoint.efficiency,Tuning.Efficiency+0.05)
  local read=Offline.Read(checkpoint)
  assert(read and read.bonus==checkpoint.bonus,"The bonus survives a save")
  -- Whole Coins: allow the last Coin of float rounding.
  assert(math.abs(Offline.Reward(read,1000+3600,0).amount-3600*checkpoint.rate)<=1,"Paid at base plus bonus")
  assert(math.abs(Offline.Reward({at=1000,rate=10,efficiency=Tuning.Efficiency},1000+3600,0).amount-36000)<=1,"Old checkpoints unchanged")
 end)

 test("The chicken list keeps its version until something shown changes",function()
  local s=flockSession(-998)
  local a=s:Snapshot(0);local b=s:Snapshot(0)
  assert(a.petsVersion==b.petsVersion and a.pets==b.pets,"An unchanged list got a new version")
  local pet=s:AddPet("Duck",1)
  local c=s:Snapshot(0)
  assert(c.petsVersion~=b.petsVersion and #c.pets==#b.pets+1,"A new chicken kept the old version")
  pet.favorite=true
  local d=s:Snapshot(0)
  assert(d.petsVersion~=c.petsVersion,"A favorite kept the old version")
  assert(d.flock and d.flock.size==3 and d.flock.mode=="Auto" and #d.flock.ids==3,"Flock snapshot")
  for _,entry in d.pets do assert(entry.flock==has(d.flock.ids,entry.id),"Per-chicken Flock flag") end
 end)

 local failed=0
 for _,r in results do if not r.passed then failed+=1 end end
 print(("FlockChecks: %d passed, %d failed"):format(#results-failed,failed))
 return results
end
return Checks
