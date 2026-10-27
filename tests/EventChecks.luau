-- Halloween 2026 limited event (docs/team/launch/15_H1_HALLOWEEN.md). Isolated
-- sessions, fixed Random seeds and fixed `now` values only; no DataStore or
-- live-world access. Config.Event is patched inside each check and restored,
-- so the result never depends on the shipped Enabled/StartsAt/EndsAt values.
-- Run from a fresh Run-mode server: require(path.to.EventChecks).Run()
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local Rolls=require(Server.RollService)
local Events=require(Server.EventService)
local Catalog=require(Shared.PetCatalog)
local Rules=require(Shared.Rules)
local Config=require(Shared.Config)
local Checks={}

local SPECIES="Pumpkin"
local NOW=1792000000 -- 2026-10-14 UTC-ish; a fixed clock, never the real one
local OPEN={Enabled=true,StartsAt=NOW-86400,EndsAt=NOW+86400,Species=SPECIES,OfferChance=0.02}

-- Patch Config.Event fields for one check, then restore every original field.
local function withEvent(fields,fn)
 local event=Config.Event
 local saved={}
 for key,value in event do saved[key]=value end
 for key,value in fields do event[key]=value end
 local ok,why=pcall(fn)
 for key in event do event[key]=nil end
 for key,value in saved do event[key]=value end
 if not ok then error(why,0) end
end

local function rollerSession(id)
 local s=Session.new(id,"Event",1);s.loaded=true
 s.tutorial.guideCompleted=true;s.tutorial.bought=true
 s.introRebirth=nil -- Oct 27: catalog prices (StarterPrices only quote empty-start profiles)
 s.rollSlotCount=Config.RollSlotsUnlocked
 return s
end

-- Rolls `count` lever pulls on a fresh seeded session; returns every offer.
local function rollMany(id,seed,count)
 local s,roller=rollerSession(id),Rolls.new()
 s.debugRandom=Random.new(seed)
 local offers={}
 for _=1,count do
  s.rollReadyAt=0
  assert(roller:Roll(s,0))
  for slot=1,s.rollSlotCount do table.insert(offers,s.offers[slot]) end
 end
 return offers,s
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,why=pcall(fn)
  table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
  print((if ok then "PASS " else "FAIL ")..name..(if ok then "" else " :: "..tostring(why)))
 end

 test("The Pumpkin Chicken is a weight-0 limited Epic in Magma Chicken's band",function()
  local d,k=Catalog[SPECIES],Catalog.Knight
  assert(d and d.name=="Pumpkin Chicken" and d.weight==0 and d.rarity=="Epic","definition")
  assert(d.limited=="Halloween2026" and d.baseSpecies=="Knight" and not d.crateExclusive)
  for _,key in {"price","income","hp","damage","interval","size"} do assert(d[key]==k[key],key.." differs from Knight") end
  local seen=0
  for _,id in Catalog.Order do if id==SPECIES then seen+=1 end end
  assert(seen==1,"Order has Pumpkin "..seen.." times")
  assert(Rules.RecruitPrice(SPECIES,1)==Rules.RecruitPrice("Knight",1))
  assert(Rules.RecruitPrice(SPECIES,3)==Rules.RecruitPrice("Knight",3))
  assert(Rules.MergePrice(SPECIES,1)==Rules.MergePrice("Knight",1))
  assert(Rules.Investment(SPECIES,2)==Rules.Investment("Knight",2))
 end)

 test("Inactive (off, before start, after end): 10,000 calls never offer it and never draw",function()
  for label,fields in {
   off={Enabled=false,StartsAt=NOW-86400,EndsAt=NOW+86400,OfferChance=1},
   before={Enabled=true,StartsAt=NOW+1,EndsAt=NOW+86400,OfferChance=1},
   after={Enabled=true,StartsAt=NOW-86400,EndsAt=NOW,OfferChance=1},
   zero={Enabled=true,StartsAt=0,EndsAt=0,OfferChance=1}, -- the shipped placeholder window
  } do
   withEvent(fields,function()
    assert(not Events.Active(NOW),label.." is active")
    local rng,twin=Random.new(11),Random.new(11)
    for i=1,10000 do
     assert(Events.MaybeReplace(nil,"Duck",rng,(i%8)+1,NOW)=="Duck",label.." replaced a slot")
    end
    assert(rng:NextNumber()==twin:NextNumber(),label.." advanced the rng")
   end)
  end
 end)

 test("Disabled: 10,000 real roll slots never offer it",function()
  withEvent({Enabled=false,StartsAt=0,EndsAt=2^40,OfferChance=1},function()
   local offers=rollMany(-971,5,math.ceil(10000/Config.RollSlotsUnlocked))
   assert(#offers>=10000,"Only "..#offers.." slots")
   for _,offer in offers do assert(offer.species~=SPECIES,"Pumpkin offered while disabled") end
  end)
 end)

 test("An ended window leaves seeded rolls identical to a disabled event",function()
  local function species(fields)
   local list
   withEvent(fields,function()
    local offers=rollMany(-972,99,40)
    list={}
    for i,offer in offers do list[i]=offer.species..":"..tostring(offer.mutation) end
   end)
   return table.concat(list,",")
  end
  local now=os.time()
  local off=species({Enabled=false,StartsAt=0,EndsAt=0})
  local ended=species({Enabled=true,StartsAt=now-7200,EndsAt=now-3600,OfferChance=0.5})
  assert(off==ended,"An inactive event changed the roll sequence")
 end)

 test("Active: about 2% of 50,000 seeded calls, one draw per call",function()
  withEvent(OPEN,function()
   assert(Events.Active(NOW) and Events.Active(OPEN.StartsAt) and not Events.Active(OPEN.EndsAt))
   local rng,twin,hits=Random.new(2026),Random.new(2026),0
   for i=1,50000 do
    local result=Events.MaybeReplace(nil,"Bucket",rng,(i%8)+1,NOW)
    if result==SPECIES then hits+=1 else assert(result=="Bucket","Unexpected "..tostring(result)) end
   end
   for _=1,50000 do twin:NextNumber() end
   assert(rng:NextNumber()==twin:NextNumber(),"Not exactly one rng draw per call")
   local expected=50000*OPEN.OfferChance
   assert(math.abs(hits-expected)<=expected*0.15,("%d hits, expected about %d"):format(hits,expected))
  end)
 end)

 test("Malformed event config stays inactive",function()
  for _,fields in {{OfferChance=0},{OfferChance=-1},{OfferChance=2},{OfferChance=0/0},{Species="NotAChicken"},
   {StartsAt="soon"},{EndsAt="later"},{Enabled="yes"}} do
   local patched=table.clone(OPEN)
   for key,value in fields do patched[key]=value end
   withEvent(patched,function()
    local rng,twin=Random.new(3),Random.new(3)
    assert(not Events.Active(NOW),"Malformed config is active")
    assert(Events.MaybeReplace(nil,"Duck",rng,2,NOW)=="Duck")
    assert(rng:NextNumber()==twin:NextNumber())
   end)
  end
 end)

 test("Starter and forced slots are never replaced; offers price like Knight",function()
  local now=os.time()
  withEvent({Enabled=true,StartsAt=now-3600,EndsAt=now+3600,Species=SPECIES,OfferChance=1},function()
   -- A fresh profile's first free roll stays the starter Duck.
   local fresh=Session.new(-973,"Starter",1);fresh.loaded=true
   assert(fresh:StarterRecruitPending(),"Fixture is not a starter roll")
   assert(Rolls.new():Roll(fresh,0))
   assert(#fresh.offers==1 and fresh.offers[1].species=="Duck" and fresh.offers[1].starter,"Starter slot replaced")
   -- A forced first slot keeps its species; every other slot becomes the event chicken.
   local s=rollerSession(-974);s.debugRandom=Random.new(8);s.debugNext="Bucket"
   assert(Rolls.new():Roll(s,0))
   assert(s.offers[1].species=="Bucket","Forced slot replaced")
   for slot=2,s.rollSlotCount do
    local offer=s.offers[slot]
    assert(offer.species==SPECIES,"Slot "..slot.." was "..offer.species)
    assert(offer.level==1 and offer.price==Rules.RecruitPrice("Knight",1),"Price "..tostring(offer.price))
    -- Lead request 3: event offers disclose the event chance and carry event=true.
    assert(offer.chance==1 and offer.event==true,"Event offer chance field: "..tostring(offer.chance))
   end
   -- Recruit level follows owned copies like any species.
   local owned=s:AddPet(SPECIES,1);owned.level=3
   s.rollReadyAt=0;s.debugNext=nil
   assert(Rolls.new():Roll(s,0))
   assert(s.offers[1].species==SPECIES and s.offers[1].level==2 and s.offers[1].price==Rules.RecruitPrice(SPECIES,2))
  end)
 end)

 test("Never in normal odds or Rules.Draw at any Luck",function()
  for luck=0,#Config.LuckPrices do
   for _,paid in {1,2} do
    for _,research in {0,0.25,1} do
     local odds,total=Rules.Odds(luck,1,paid,research),0
     assert(odds[SPECIES]==0,"Pumpkin has normal odds")
     for _,id in Catalog.Order do total+=odds[id] end
     assert(math.abs(total-1)<1e-9,"Odds total "..total)
    end
   end
  end
  for _,luck in {0,4,#Config.LuckPrices} do
   for step=0,19999 do
    assert(Rules.Draw(luck,step/20000,1,1,0)~=SPECIES,"Draw returned Pumpkin")
   end
  end
 end)

 test("A saved Pumpkin Chicken loads and saves after the event ends",function()
  withEvent({Enabled=false,StartsAt=NOW-86400*30,EndsAt=NOW-86400},function()
   local s=Session.new(-975,"Keeper",1)
   local pet=s:AddPet(SPECIES,1);pet.level=2;pet.investment=Rules.Investment(SPECIES,2)
   local data=s:ToData()
   local loaded=Session.new(-975,"Keeper",1)
   assert(loaded:LoadData(data),"Profile rejected")
   local copy=loaded.pets[pet.id]
   assert(copy and copy.species==SPECIES and copy.level==2 and copy.investment==pet.investment,"Chicken changed")
   assert(loaded.discovered[SPECIES]==true,"Index discovery lost")
   assert(#loaded.unrecognizedPets==0,"Pumpkin treated as unknown")
   local again=loaded:ToData()
   local found=false
   for _,entry in again.pets do if entry.id==pet.id then found=entry.species==SPECIES and entry.level==2 end end
   assert(found,"Second save dropped the chicken")
   local knight=loaded:AddPet("Knight",1);knight.level=2
   assert(loaded:PetIncome(pet.id)==loaded:PetIncome(knight.id),"Income differs from its band")
  end)
 end)

 local failed=0
 for _,r in results do if not r.passed then failed+=1 end end
 print(("EventChecks: %d passed, %d failed"):format(#results-failed,failed))
 return results
end
return Checks
