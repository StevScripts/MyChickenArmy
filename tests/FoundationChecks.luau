--!strict
-- Launch foundation (docs/team/launch/02_LEAD.md §3): additive saved fields load
-- safely, and with every launch stub neutral the game matches main before the
-- foundation. Isolated sessions only; no DataStore or live-world access.
-- Baseline numbers were captured on main 038df3e in a fresh Run-mode server.
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local Rolls=require(Server.RollService)
local Offline=require(Server.OfflineCash)
local King=require(Server.KingEncounter)
local Rebirth=require(Server.RebirthService)
local Mutations=require(Shared.MutationCatalog)
local Progression=require(Shared.Progression)
local Rules=require(Shared.Rules)
local Config=require(Shared.Config)
local Checks={}

local function near(a,b,why)
 assert(math.abs(a-b)<1e-6,(why or "Values differ")..": "..tostring(a).." ~= "..tostring(b))
end

-- The same fixed flock the baseline used.
local function baselineSession()
 local s=Session.new(-951,"Base",1);s.loaded=true
 s.tutorial.guideCompleted=true;s.tutorial.bought=true
 s.introRebirth=nil -- Oct 27: a pre-empty-start profile, so podiums quote catalog prices (no StarterPrices)
 for id in s.pets do s.pets[id]=nil end
 local a=s:AddPet("Knight",1);a.level=3
 local b=s:AddPet("Dragon",1);b.level=2
 s:AddPet("Duck",1)
 s.incomeLevel=2;s.eggSpeedLevel=3
 s:RefreshArmy()
 return s
end

-- Temporarily accept one test mutation id with a ×2 multiplier.
local function withTestMutation(fn)
 local valid,multiplier=Mutations.IsValid,Mutations.Multiplier
 Mutations.IsValid=function(id) return id=="TestGold" end
 Mutations.Multiplier=function(id) return if id=="TestGold" then 2 else 1 end
 local ok,why=pcall(fn)
 Mutations.IsValid,Mutations.Multiplier=valid,multiplier
 if not ok then error(why,0) end
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,why=pcall(fn)
  table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
  print((if ok then "PASS " else "FAIL ")..name..(if ok then "" else " :: "..tostring(why)))
 end

 test("A profile without launch fields loads with defaults",function()
  local data=Session.new(-952,"Old",1):ToData()
  data.rebirths,data.daily=nil,nil
  for _,pet in data.pets do pet.mutation=nil end
  local s=Session.new(-952,"Old",1)
  assert(s:LoadData(data))
  assert(s.rebirths==0,"rebirths")
  assert(s.daily.streak==0 and s.daily.lastDay==0 and s.daily.best==0,"daily")
  assert(s.dailyGranted==nil)
  for _,pet in s.pets do assert(pet.mutation==nil,"mutation") end
 end)

 test("Junk launch values load as defaults and keep every chicken",function()
  local base=Session.new(-953,"Junk",1)
  -- October 23 empty start: a new profile has no chickens; the junk mutations need two.
  base:AddPet("Duck",1);base:AddPet("Duck",1)
  local data=base:ToData()
  local count=#data.pets
  for _,junk in {-3,"x",1.5,0/0,math.huge,{}} do
   data.rebirths=junk;data.daily=5
   data.pets[1].mutation="Nope";data.pets[2].mutation=12
   local s=Session.new(-953,"Junk",1)
   assert(s:LoadData(data),"Profile rejected for rebirths="..tostring(junk))
   assert(s.rebirths==0 and s.daily.streak==0 and s.daily.best==0)
   assert(s:Count()==count,"A chicken was dropped")
   for _,pet in s.pets do assert(pet.mutation==nil) end
  end
  data.rebirths=3;data.daily={streak=-1,lastDay="y",best=2.5}
  local s=Session.new(-953,"Junk",1);assert(s:LoadData(data))
  assert(s.rebirths==3 and s.daily.streak==0 and s.daily.lastDay==0 and s.daily.best==0)
  -- A rank above MaxRank keeps the highest rank rather than resetting progress.
  data.rebirths=Config.Rebirth.MaxRank+4
  local high=Session.new(-953,"Junk",1);assert(high:LoadData(data))
  assert(high.rebirths==Config.Rebirth.MaxRank)
 end)

 test("A save round trip keeps rebirths, daily and a valid mutation",function()
  withTestMutation(function()
   local s=Session.new(-954,"Saver",1)
   s.rebirths=4;s.daily={streak=6,lastDay=20740,best=9};s.dailyGranted={slot=6}
   local pet=s:AddPet("Knight",1,"TestGold")
   assert(pet.mutation=="TestGold")
   local bad=s:AddPet("Duck",1,"Nope");assert(bad.mutation==nil)
   local data=s:ToData()
   assert(data.dailyGranted==nil,"Live popup state was saved")
   local loaded=Session.new(-954,"Saver",1);assert(loaded:LoadData(data))
   assert(loaded.rebirths==4)
   assert(loaded.daily.streak==6 and loaded.daily.lastDay==20740 and loaded.daily.best==9)
   assert(loaded.pets[pet.id].mutation=="TestGold")
   -- The saved table is a copy: later live edits don't alias the save.
   loaded.daily.streak=7;assert(data.daily.streak==6)
   -- Income and the snapshot follow the mutation multiplier.
   local plain=loaded:AddPet("Knight",1);plain.level=pet.level
   near(loaded:PetIncome(pet.id),2*loaded:PetIncome(plain.id),"Mutation income")
   local snap=loaded:Snapshot(0)
   local seen=false
   for _,entry in snap.pets do if entry.id==pet.id then seen=entry.mutation=="TestGold" end end
   assert(seen,"Snapshot pet lacks its mutation")
   assert(snap.rebirth and snap.rebirth.rank==4 and snap.rebirth.eligible==false)
   assert(snap.daily.streak==7 and snap.daily.granted==nil)
  end)
 end)

 test("Without mutations, income and offline rate match main",function()
  local s=baselineSession()
  -- Re-pinned October 23: the October 22 per-chicken odds retune (valueOneIn incomes)
  -- moved every number; the mutation-neutral relations below are what this guards.
  near(s:Income(),1011.52,"Income")
  near(s:DisplayedPetIncome("Knight",1,3),983,"Displayed income")
  near(Offline.Rate(s),202.304,"Offline rate")
  near(s:Snapshot(0).income,2023.04,"Snapshot income")
  assert(Rebirth.Multiplier(0)==1,"Rank 0 multiplier")
  near(s:EarnedAmount(100,"eggs"),100,"EarnedAmount")
 end)

 test("With neutral stubs, roll offers match main for a fixed seed",function()
  local s=baselineSession()
  s.rollSlotCount=4;s.debugRandom=Random.new(42)
  -- M1 adds a mutation draw per offer; stub it so the species stream matches main.
  local roll=Mutations.Roll
  Mutations.Roll=function() return nil end
  local ok,why=pcall(function() assert(Rolls.new():Roll(s,0)) end)
  Mutations.Roll=roll
  assert(ok,why)
  local offers={}
  for i,o in s.offers do offers[i]=o.species..":"..o.level..":"..o.price;assert(o.mutation==nil) end
  -- October 22 roll pool and October 23 empty start: the basic Chicken costs 150 Coins.
  assert(table.concat(offers,",")=="Duck:1:150,Cardboard:1:2100,Duck:1:150,RubberDucky:1:2000","Offers: "..table.concat(offers,","))
 end)

 test("With neutral stubs, camp and King power match main",function()
  local camps={}
  for i=1,3 do camps[i]=Rules.Power(Progression.Roster(1,i)) end
  -- October 23 empty start: Cluck Camp is one basic Chicken (power 12), so three rolled
  -- chickens read "Should win"; Fort Roost and Hen House are unchanged.
  assert(table.concat(camps,",")=="12,106,192","Camps "..table.concat(camps,",")) -- October 26: camp guards copy the old stats
  -- October 27 camp ladder (Config.CampLadder.Strength): the guards keep those stats; the
  -- fight and the shown power carry the strength (Fort Roost x0.60, Ironbeak HQ x0.55).
  local fought={}
  for i=1,3 do fought[i]=Progression.CampPower(i) end
  assert(table.concat(fought,",")=="12,64,105","Camp ladder "..table.concat(fought,","))
  local k=King.Definition(4)
  assert(k.power==497 and k.roster[1].combatStats.hp==2800 and k.roster[1].combatStats.damage==32)
  local same=King.Definition(4,Rebirth.EnemyScale(0))
  assert(same.power==497 and same.roster[2].combatStats==nil,"Rank 0 scale changed the King")
 end)

 test("The King scale hook multiplies boss, guards and reported power",function()
  local k=King.Definition(4,2)
  assert(k.roster[1].combatStats.hp==5600 and k.roster[1].combatStats.damage==64)
  local guard=k.roster[2]
  local base=Rules.Stats(guard.species,guard.stars,guard.level)
  near(guard.combatStats.hp,base.hp*2);near(guard.combatStats.damage,base.damage*2)
  assert(math.abs(k.power-2*497)<=2,"Scaled power "..k.power)
 end)

 test("Credits stay whole coins under the Re-enlist multiplier",function()
  local s=Session.new(-956,"Vet",1);s.coins=0;s.rebirths=1
  local paid=s:Credit(101,"eggs")
  assert(paid%1==0 and s.coins%1==0,"Fractional credit "..paid)
  assert(paid==math.floor(101*Rebirth.Multiplier(1)))
 end)
 local failed=0
 for _,r in results do if not r.passed then failed+=1 end end
 print(("FoundationChecks: %d passed, %d failed"):format(#results-failed,failed))
 return results
end
return Checks
