--!strict
-- October 14 Giants (docs/team/GIANT_CHICKEN_DESIGN.md): fusion is a level-up with
-- a Giant chance and guarantee, Giant inputs keep Giants, three Giants roll for a
-- Colossal, Giants fight harder, Colossals boost their side, and the guarantee
-- counter saves additively. Isolated sessions; no DataStore or world access.
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Battle=require(Server.Battle)
local Giant=require(Shared.GiantChicken)
local Rules=require(Shared.Rules)
local Checks={}

local function near(a,b,why)
 assert(math.abs(a-b)<1e-6,(why or "Values differ")..": "..tostring(a).." ~= "..tostring(b))
end

-- A fixed sequence of random numbers for ArmyService.SizeRandom.
local function script(values)
 local index=0
 return {NextNumber=function() index+=1;return values[math.min(index,#values)] end}
end

local function fuser()
 local s=Session.new(-981,"Fuser",1);s.loaded=true;s.fusionUnlocked=true
 s.tutorial.guideCompleted=true;s.promotion,s.recruitTier=4,4;s.coins=1e12
 for id in s.pets do s.pets[id]=nil end
 return s
end

-- Three matching Buckets at `level`; `giants` lists sizes for the first inputs.
local function triple(s,level,giants)
 local ids={}
 for i=1,3 do
  local pet=s:AddPet("Bucket",1);pet.level=level
  pet.giantSize=giants and giants[i] or nil
  ids[i]=pet.id
 end
 return ids
end

local function fuse(s,ids,level)
 local ok,message,petId,outcome=Army.Merge(s,ids[1],ids[2],ids[3],level,Rules.MergePrice("Bucket",level))
 assert(ok,message)
 return s.pets[petId],outcome,message
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local saved=Army.SizeRandom
  local ok,why=pcall(fn)
  Army.SizeRandom=saved
  table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
  print((if ok then "PASS " else "FAIL ")..name..(if ok then "" else " :: "..tostring(why)))
 end

 test("Giant chance is 10% + 2% per input level",function()
  near(Giant.Chance(1),.12);near(Giant.Chance(5),.20);near(Giant.Chance(9),.28)
 end)

 test("A missed roll is a plain level-up and counts toward the guarantee",function()
  local s=fuser()
  Army.SizeRandom=script({.99})
  local pet,outcome,message=fuse(s,triple(s,1),1)
  assert(pet.level==2 and pet.giantSize==nil and outcome=="Fused",outcome)
  assert(s.giantPity==1 and message:find("Fused",1,true),message)
 end)

 test("A successful roll makes a Giant and resets the guarantee",function()
  local s=fuser();s.giantPity=3
  Army.SizeRandom=script({.05,.5})
  local pet,outcome,message=fuse(s,triple(s,1),1)
  assert(outcome=="NewGiant" and Giant.IsGiant(pet) and not Giant.IsColossal(pet.giantSize),outcome)
  assert(s.giantPity==0 and message:find("GIANT!",1,true),message)
 end)

 test("The 8th fusion in a row without a Giant is guaranteed",function()
  local s=fuser()
  Army.SizeRandom=script({.99})
  for i=1,Giant.PityLimit-1 do
   local pet,outcome=fuse(s,triple(s,1),1)
   assert(outcome=="Fused" and pet.giantSize==nil,"Fusion "..i.." was "..outcome)
  end
  assert(s.giantPity==Giant.PityLimit-1)
  local pet,outcome=fuse(s,triple(s,1),1)
  assert(outcome=="NewGiant" and Giant.IsGiant(pet) and s.giantPity==0,outcome)
 end)

 test("A Giant input keeps the result a Giant without touching the guarantee",function()
  local s=fuser();s.giantPity=5
  Army.SizeRandom=script({.0})
  local pet,outcome=fuse(s,triple(s,2,{9.5}),2)
  assert(outcome=="Giant" and pet.giantSize>=9.5 and pet.level==3,outcome)
  assert(s.giantPity==5,"Guarantee changed")
 end)

 test("Three Giants roll for a Colossal; a miss is still a Giant",function()
  local s=fuser()
  Army.SizeRandom=script({.1,.5})
  local pet,outcome=fuse(s,triple(s,1,{6,7,8}),1)
  assert(outcome=="NewColossal" and Giant.IsColossal(pet.giantSize),outcome)
  local t=fuser()
  Army.SizeRandom=script({.9,.0})
  local other,miss=fuse(t,triple(t,1,{6,7,8}),1)
  assert(miss=="Giant" and Giant.IsGiant(other) and not Giant.IsColossal(other.giantSize) and other.giantSize>=8,miss)
 end)

 test("A Colossal input stays Colossal",function()
  local s=fuser()
  Army.SizeRandom=script({.0})
  local pet,outcome=fuse(s,triple(s,1,{21.5}),1)
  assert(outcome=="Colossal" and pet.giantSize==21.5,outcome)
 end)

 test("Giants have ×2 health, ×1.5 damage and stomp; power and Select Best follow",function()
  local plain=Rules.Stats("Bucket",1,3)
  local giant=Rules.Stats("Bucket",1,3,9)
  near(giant.hp,plain.hp*Giant.HealthMultiplier,"hp")
  near(giant.damage,plain.damage*Giant.DamageMultiplier,"damage")
  assert(giant.splash==true and giant.giant==true,"No stomp")
  assert(Rules.PetPower("Bucket",1,3,9)>Rules.PetPower("Bucket",1,3),"Power ignores Giants")
  assert(Rules.Power({{species="Bucket",stars=1,level=3,giantSize=9}})>Rules.Power({{species="Bucket",stars=1,level=3}}))
  -- Select Best prefers the Giant over an otherwise identical chicken.
  local s=fuser();s.capacity=3
  for _=1,3 do local p=s:AddPet("Bucket",1);p.level=3 end
  local big=s:AddPet("Bucket",1);big.level=3;big.giantSize=9
  local best=s:AutoBestPetIds()
  assert(table.find(best,big.id)~=nil,"Select Best skipped the Giant")
 end)

 test("A standing Colossal adds army damage to its side only",function()
  local function battleWith(sizes)
   local b=Battle.new("t",1,"camp:1",Vector3.zero,Vector3.new(0,0,50),0)
   local roster={}
   for i,size in sizes do table.insert(roster,{id="p"..i,species="Bucket",stars=1,level=2,giantSize=size}) end
   b:AddArmy("A",roster,Vector3.zero)
   b:AddArmy("B",{{species="Bucket",stars=1,level=2}},Vector3.new(0,0,50))
   b:ApplyResearch("A",nil,false);b:ApplyResearch("B",nil,false)
   return b
  end
  local with,without=battleWith({false,21}),battleWith({false,9})
  local function damage(b,side) for _,u in b.units do if u.side==side and not u.giantSize then return u.damage end end return 0 end
  near(damage(with,"A"),damage(without,"A")*(1+Giant.ColossalArmyDamage),"Aura")
  near(damage(with,"B"),damage(without,"B"),"Enemy side changed")
 end)

 test("The guarantee counter saves additively; junk and old saves read as 0",function()
  local s=fuser();s.giantPity=4
  local big=s:AddPet("Bucket",1);big.giantSize=12.5
  local data=s:ToData()
  local loaded=Session.new(-981,"Fuser",1);assert(loaded:LoadData(data))
  assert(loaded.giantPity==4 and loaded.pets[big.id].giantSize==12.5)
  for _,junk in {-1,2.5,"x",99,0/0} do
   data.giantPity=junk
   local bad=Session.new(-981,"Fuser",1);assert(bad:LoadData(data),"Rejected giantPity="..tostring(junk))
   assert(bad.giantPity==0)
  end
  data.giantPity=nil
  local old=Session.new(-981,"Fuser",1);assert(old:LoadData(data) and old.giantPity==0)
  assert(loaded:Snapshot(0).giantPity==4,"Snapshot lacks giantPity")
 end)

 local failed=0
 for _,r in results do if not r.passed then failed+=1 end end
 print(("GiantChecks: %d passed, %d failed"):format(#results-failed,failed))
 return results
end
return Checks
