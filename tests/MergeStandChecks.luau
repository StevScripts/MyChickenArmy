--!strict
-- Disposable sessions only. No DataStore, commerce grants or saved player mutation.
local Server=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local Checks={}
local function setup(count)
 local s=Session.new(-731,"Merge check",1)
 s.pets,s.slots={},{};s.loaded=true
 local pets={}
 for i=1,count or 3 do pets[i]=s:AddPet("Mallard",1) end
 s.slots[1]=pets[1].id
 return s,pets[1],pets[2],pets[3]
end
function Checks.Run()
 local results={}
 local function check(name,fn)
  local ok,why=pcall(fn);table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
 end
 check("Exactly three become one; retained ID, investment, coins and save roundtrip",function()
  local s,a,b,c=setup();local coins=s.coins
  a.investment,b.investment,c.investment=101,102,103
  s.armySelection={a.id,b.id,c.id}
  assert(Army.Merge(s,a.id,b.id,c.id,1))
  assert(s:Count()==1 and a.level==2 and a.stars==1 and a.investment==306 and s.coins==coins)
  assert(s.pets[b.id]==nil and s.pets[c.id]==nil and s.slots[1]==a.id)
  assert(#s.armySelection==1 and s.armySelection[1]==a.id)
  local restored=Session.new(-732,"Round trip",1);assert(restored:LoadData(s:ToData()))
  assert(restored:Count()==1 and restored.pets[a.id].level==2 and restored.pets[a.id].investment==306)
 end)
 check("Replay and old two-ID payload cannot consume more chickens",function()
  local s,a,b,c=setup(6)
  assert(not Army.Merge(s,a.id,b.id,1))
  assert(Army.Merge(s,a.id,b.id,c.id,1))
  assert(not Army.Merge(s,a.id,b.id,c.id,1));assert(s:Count()==4 and a.level==2)
 end)
 check("Duplicate, foreign, malformed, mismatched species/stars/levels fail atomically",function()
  local s,a,b,c=setup()
  for _,ids in {{a.id,a.id,c.id},{a.id,b.id,"foreign"},{a.id,b.id,{}},{a.id,b.id,string.rep("x",65)}} do
   assert(not Army.Merge(s,ids[1],ids[2],ids[3],1))
  end
  c.species="Duck";assert(not Army.Merge(s,a.id,b.id,c.id,1));c.species=a.species
  c.stars=2;assert(not Army.Merge(s,a.id,b.id,c.id,1));c.stars=1
  c.level=2;assert(not Army.Merge(s,a.id,b.id,c.id,1));c.level=1
  assert(not Army.Merge(s,a.id,b.id,c.id,2))
  a.investment,b.investment,c.investment=5e11,5e11,5e11
  assert(not Army.Merge(s,a.id,b.id,c.id,1));assert(s:Count()==3 and a.level==1)
 end)
 check("Favorites, away, defending and capped chickens are excluded",function()
  local s,a,b,c=setup();a.favorite=true
  assert(#Army.MergeOptions(s)==0 and not Army.Merge(s,a.id,b.id,c.id,1));a.favorite=false
  s.awayPets={[c.id]=true};assert(#Army.MergeOptions(s)==0 and not Army.Merge(s,a.id,b.id,c.id,1));s.awayPets={}
  s.armyState="Deployed";assert(#Army.MergeOptions(s)==0);s.armyState="Home";s.incoming="battle"
  assert(not Army.Merge(s,a.id,b.id,c.id,1));s.incoming=nil
  a.level,b.level,c.level=Config.MaxPetLevel,Config.MaxPetLevel,Config.MaxPetLevel
  assert(#Army.MergeOptions(s)==0 and not Army.Merge(s,a.id,b.id,c.id,Config.MaxPetLevel))
 end)
 check("Three home reserves can merge while their squad is away",function()
  local s,a,b,c=setup();local fighter=s:AddPet("Dragon",1);s.slots={fighter.id};s.armyState="Deployed"
  assert(Army.Merge(s,a.id,b.id,c.id,1));assert(s.pets[fighter.id] and s:Count()==2)
 end)
 check("Only 3+ copies shown, extra copies remain; preview uses actual stats",function()
  local s,a,b,c=setup(5);s.incomeLevel=2
  local r=Army.MergeOptions(s)[1];assert(r.count==5 and #r.petIds==5 and r.merges==1)
  assert(r.firstId==a.id and r.inputIncome*3==r.beforeIncome)
  assert(r.afterIncome==s:DisplayedPetIncome(a.species,1,2))
  local stats=Rules.Stats(a.species,1,2);assert(r.afterDps==stats.damage/stats.interval)
  assert(Army.Merge(s,r.firstId,r.secondId,r.thirdId,r.level));assert(s:Count()==3 and #Army.MergeOptions(s)==0)
 end)
 check("Whole batch rejects shared IDs or invalid final triple without partial mutation",function()
  local s,a,b,c=setup(6);local r=Army.MergeOptions(s)[1];local ids=r.petIds
  local first={firstId=ids[1],secondId=ids[2],thirdId=ids[3],level=1}
  local second={firstId=ids[3],secondId=ids[5],thirdId=ids[6],level=1}
  assert(not Army.MergeAll(s,{first,second}) and s:Count()==6)
  second.firstId=ids[4];second.level=2;assert(not Army.MergeAll(s,{first,second}) and s:Count()==6)
  second.level=1;assert(Army.MergeAll(s,{first,second}));assert(s:Count()==2)
 end)
 check("Sparse batches and legacy pairs rejected; paid automation stays disabled",function()
  local s,a,b,c=setup();local triple={firstId=a.id,secondId=b.id,thirdId=c.id,level=1}
  assert(not Army.MergeAll(s,{[1]=triple,extra=triple}))
  assert(not Army.MergeAll(s,{{firstId=a.id,secondId=b.id,level=1}}))
  s.commerceAutomatic.AutoMerge=true;s.entitlements.AutoMerge=true
  assert(not Army.AutoMerge(s) and s:Count()==3 and not Config.Features.AutoMerging)
 end)
 return results
end
return Checks
