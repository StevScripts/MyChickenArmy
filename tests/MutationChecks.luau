--!strict
-- M1 mutations (docs/team/launch/14_M1_MUTATIONS.md): catalog rules, seeded roll
-- rates, fusion, income/offline hooks, saves and crates. Isolated sessions only;
-- no DataStore or live-world access. Run in a fresh Run-mode server:
--   require(game.ServerStorage.PetRollTests.MutationChecks).Run()
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local Offline=require(Server.OfflineCash)
local Rolls=require(Server.RollService)
local Crates=require(Server.CrateService)
local Mutations=require(Shared.MutationCatalog)
local Rules=require(Shared.Rules)
local Checks={}

local IDS={"Golden","Rainbow","Shadow","Cosmic"}
local MULTIPLIERS={Golden=1.5,Rainbow=2,Shadow=3,Cosmic=5}
local CHANCES={Golden=1/250,Rainbow=1/800,Shadow=1/3000,Cosmic=1/12000}

local function near(a,b,why)
 assert(math.abs(a-b)<=1e-6*math.max(1,math.abs(b)),(why or "Values differ")..": "..tostring(a).." ~= "..tostring(b))
end

-- Long loops yield when the caller allows it, so Studio stays responsive.
local function breathe()
 pcall(task.wait)
end

local function session(id)
 local s=Session.new(id,"Mutant",1);s.loaded=true
 s.tutorial.guideCompleted=true;s.tutorial.bought=true
 return s
end

-- October 20 tree v2 (S9c): Roll's second argument is how many mutations the
-- Upgrades tree unlocked (0-4, in Order), no longer the Rebirth rank.
local function rates(unlocked,count,seed)
 local rng=Random.new(seed)
 local hits={}
 for _,id in IDS do hits[id]=0 end
 local none=0
 for i=1,count do
  local id=Mutations.Roll(rng,unlocked)
  if id then hits[id]+=1 else none+=1 end
  if i%250000==0 then breathe() end
 end
 return hits,none
end

-- Temporarily replace catalog fields; always restored.
local function withPatch(patch,fn)
 local saved={}
 for key,value in patch do saved[key]=(Mutations::any)[key];(Mutations::any)[key]=value end
 local ok,why=pcall(fn)
 for key in patch do (Mutations::any)[key]=saved[key] end
 if not ok then error(why,0) end
end

local function withChance(id,chance,fn)
 local def=Mutations.Defs[id]
 local old=def.chance
 def.chance=chance
 local ok,why=pcall(fn)
 def.chance=old
 if not ok then error(why,0) end
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,why=pcall(fn)
  table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
  print((if ok then "PASS " else "FAIL ")..name..(if ok then "" else " :: "..tostring(why)))
 end

 test("IsValid, Multiplier and Rank for every id, nil and unknown ids",function()
  assert(#Mutations.Order==4,"Order")
  for rank,id in IDS do
   assert(Mutations.Order[rank]==id,"Order "..rank)
   assert(Mutations.IsValid(id),id)
   near(Mutations.Multiplier(id),MULTIPLIERS[id],id.." multiplier")
   assert(Mutations.Rank(id)==rank,id.." rank")
   local def=Mutations.Defs[id]
   near(def.chance,CHANCES[id],id.." chance")
   assert((def::any).unlockRank==nil,id.." has no rank unlock (S9c)")
   assert(def.name==id,id.." name")
  end
  for _,junk in {nil,"Nope","golden","",12,true,{}} do
   assert(Mutations.IsValid(junk)==false,"IsValid "..tostring(junk))
   assert(Mutations.Multiplier(junk)==1,"Multiplier "..tostring(junk))
   assert(Mutations.Rank(junk)==0,"Rank "..tostring(junk))
  end
 end)

 test("Roll draws once per unlocked check, rarest first",function()
  local calls=0
  local miss={NextNumber=function() calls+=1;return 0.999 end}
  for unlocked,expected in {[0]=0,[1]=1,[2]=2,[3]=3,[4]=4,[9]=4} do
   calls=0
   assert(Mutations.Roll(miss,unlocked)==nil)
   assert(calls==expected,unlocked.." unlocked drew "..calls.." times")
  end
  calls=0
  local hit={NextNumber=function() calls+=1;return 0 end}
  assert(Mutations.Roll(hit,4)=="Cosmic" and calls==1,"Rarest is checked first")
  assert(Mutations.Roll(hit,3)=="Shadow")
  assert(Mutations.Roll(hit,2)=="Rainbow")
  assert(Mutations.Roll(hit,1)=="Golden")
  -- Nothing unlocked, or junk, rolls nothing.
  assert(Mutations.Roll(hit,0)==nil)
  assert(Mutations.Roll(hit,0/0 :: any)==nil)
  assert(Mutations.Roll(hit,nil :: any)==nil)
  -- Same seed, same sequence.
  local a,b=Random.new(99),Random.new(99)
  for _=1,2000 do assert(Mutations.Roll(a,3)==Mutations.Roll(b,3),"Seeded rolls diverged") end
 end)

 test("Seeded roll rates match each chance; Golden alone rolls only Golden",function()
  -- 2,000,000 rolls keep Cosmic (expected 400) inside the 15% band at ~3 sigma.
  local count=2000000
  local hits=rates(4,count,20261014)
  local reach=1
  for index=#IDS,1,-1 do
   local id=IDS[index]
   local expected=count*reach*CHANCES[id]
   local drift=math.abs(hits[id]-expected)/expected
   assert(drift<=0.15,("%s: %d hits vs %.0f expected (%.1f%%)"):format(id,hits[id],expected,drift*100))
   reach*=1-CHANCES[id]
  end
  local base=rates(1,200000,7)
  assert(base.Rainbow==0 and base.Shadow==0 and base.Cosmic==0,"A locked mutation rolled with only Golden")
  local expected=200000*CHANCES.Golden
  assert(math.abs(base.Golden-expected)/expected<=0.15,"Golden alone: "..base.Golden)
  local three=rates(3,200000,11)
  assert(three.Cosmic==0,"Cosmic rolled before its tree hex")
  assert(three.Shadow>0 and three.Rainbow>0,"Three unlocked should reach Shadow and Rainbow")
  local none=rates(0,20000,13)
  assert(none.Golden==0,"Nothing unlocked rolled a mutation")
 end)

 test("Best picks the highest multiplier and tolerates missing inputs",function()
  assert(Mutations.Best({{mutation="Golden"},{},{mutation="Rainbow"}})=="Rainbow")
  assert(Mutations.Best({{mutation="Cosmic"},{mutation="Shadow"},{mutation="Golden"}})=="Cosmic")
  assert(Mutations.Best({{mutation="Golden"},false,{mutation="Nope"}} :: any)=="Golden")
  local holes:any={}
  holes[1]={mutation=nil};holes[3]={mutation="Shadow"}
  assert(Mutations.Best(holes)=="Shadow")
  assert(Mutations.Best({{},{},{}})==nil)
  assert(Mutations.Best({})==nil)
  assert(Mutations.Best(nil)==nil)
 end)

 test("A Golden chicken earns 1.5x a plain one, offline included",function()
  local s=session(-961)
  for id in s.pets do s.pets[id]=nil end
  local plain=s:AddPet("Knight",1);plain.level=3
  local gold=s:AddPet("Knight",1,"Golden");gold.level=3
  assert(gold.mutation=="Golden" and plain.mutation==nil)
  near(s:PetIncome(gold.id),1.5*s:PetIncome(plain.id),"PetIncome")
  near(s:DisplayedPetIncome("Knight",1,3,"Golden"),1.5*s:DisplayedPetIncome("Knight",1,3),"DisplayedPetIncome")
  local withGold=Offline.Rate(s)
  gold.mutation=nil
  local bothPlain=Offline.Rate(s)
  gold.mutation="Golden"
  assert(bothPlain>0,"Offline rate is zero")
  near(withGold,bothPlain*1.25,"Offline rate") -- (1 + 1.5) / 2
  local snap=s:Snapshot(0)
  local rate={}
  -- October 21 one egg = one egg: a chicken's strength (and mutation) raises each egg's worth.
  for _,entry in snap.pets do rate[entry.id]=entry.eggValue end
  near(rate[gold.id],1.5*rate[plain.id],"Snapshot Coins/egg")
  -- Mutations never touch combat.
  local a,b=Rules.Stats("Knight",1,3),Rules.Stats("Knight",1,3)
  assert(a.damage==b.damage and a.hp==b.hp)
 end)

 test("Rolled offers carry their mutation into the bought chicken",function()
  withChance("Golden",1,function()
   local s=session(-962)
   s.rollSlotCount=3;s.debugRandom=Random.new(5);s.coins=1e12
   -- S9c: Golden rolls once its Upgrades tree hex (Mutation I) is owned.
   s.upgradeTree.Mutation=1;s:RefreshEffects()
   assert(Rolls.new():Roll(s,0))
   for slot,offer in s.offers do assert(offer.mutation=="Golden","Offer "..slot.." has "..tostring(offer.mutation)) end
   local offer=s.offers[1]
   local ok,message,petId=Rolls.new():Buy(s,offer.id,1e9)
   assert(ok,message)
   assert(s.pets[petId].mutation=="Golden","Bought chicken lost its mutation")
  end)
 end)

 test("A save round trip keeps a mutation; Nope loads as none",function()
  local s=Session.new(-964,"Saver",1)
  local gold=s:AddPet("Knight",1,"Cosmic")
  local data=s:ToData()
  local loaded=Session.new(-964,"Saver",1)
  assert(loaded:LoadData(data))
  assert(loaded.pets[gold.id] and loaded.pets[gold.id].mutation=="Cosmic","Mutation lost on load")
  local count=#data.pets
  for _,pet in data.pets do if pet.id==gold.id then pet.mutation="Nope" end end
  local junk=Session.new(-964,"Saver",1)
  assert(junk:LoadData(data),"Profile rejected for a junk mutation")
  assert(junk:Count()==count,"A chicken was dropped")
  assert(junk.pets[gold.id] and junk.pets[gold.id].mutation==nil,"Junk mutation survived")
  assert(Session.new(-964,"Saver",1):AddPet("Duck",1,"Nope").mutation==nil)
 end)

 test("A Galaxy Crate chicken never carries a mutation",function()
  -- Even if every roll mutated, crates never consult the mutation roll.
  withPatch({Roll=function() return "Cosmic" end},function()
   local crates=Crates.new({catalog={Crate={enabled=true,rewards={{species="Knight",chance=1}}}},random=Random.new(3)})
   local s=session(-965)
   s.paidRandomAllowed=true;s.crateCredits=1
   local ok,message,crate=crates:Open(s)
   assert(ok,message)
   local pet=s.pets[crate.petId]
   assert(pet and pet.species=="Knight","Crate chicken missing")
   assert(pet.mutation==nil,"Crate chicken has "..tostring(pet.mutation))
  end)
 end)

 local failed=0
 for _,r in results do if not r.passed then failed+=1 end end
 print(("MutationChecks: %d passed, %d failed"):format(#results-failed,failed))
 return results
end
return Checks
