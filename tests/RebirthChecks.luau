-- Re-enlist (docs/team/launch/11_R1_REBIRTH_SERVER.md): costs, quote reasons and
-- refusals, the exact reset/keep split, double taps, the egg multiplier, enemy
-- scaling and the save round trip. Isolated sessions with a stub world, stub
-- analytics and a stub save service; no DataStore, no saved players and no
-- live-world mutation. Run from a fresh Run-mode server:
--   require(game.ServerStorage.PetRollTests.RebirthChecks).Run()
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local Battles=require(Server.BattleService)
local Eggs=require(Server.EggService)
local Offline=require(Server.OfflineCash)
local King=require(Server.KingEncounter)
local Rebirth=require(Server.RebirthService)
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local Progression=require(Shared.Progression)
local ResearchRules=require(Shared.ResearchRules)
local Checks={}

local function near(a,b,why)
 assert(math.abs(a-b)<1e-6*math.max(1,math.abs(b)),(why or "Values differ")..": "..tostring(a).." ~= "..tostring(b))
end

local function deepEqual(a,b): boolean
 if type(a)~="table" or type(b)~="table" then return a==b end
 for k,v in a do if not deepEqual(v,b[k]) then return false end end
 for k in b do if a[k]==nil then return false end end
 return true
end

local function stubWorld()
 local world={owners={},busy={}}
 function world:Position(plot) return Vector3.new(plot*1000,1,-100) end
 function world:CampPosition(i,plot) return Vector3.new(plot*1000,1,i*80) end
 function world:CampFrame(i,plot) return CFrame.new(self:CampPosition(i,plot)) end
 function world:ReturnPosition(session,_,slot) return self:Position(session.plotIndex)+Vector3.new((slot or 1)*3,0,0) end
 function world:PetPosition() return nil end
 function world:SetCampBusy(i,busy,plot) self.busy[plot..":"..i]=busy end
 function world:SetTerritoryOwner(location,userId)
  if location.index then self.owners[location.plot..":"..location.index]=userId end
 end
 function world:SetOutpostBusy() end
 function world:OutpostFrame(i) return CFrame.new(5000,1,i*80) end
 function world:UpdateSession() end
 return world
end

local function stubAnalytics()
 local analytics={calls={},seen={}}
 function analytics:LaunchCount(_,name) table.insert(self.calls,"count:"..name) end
 function analytics:LaunchHist(_,name,value) table.insert(self.calls,"hist:"..name..":"..tostring(value)) end
 function analytics:LaunchFirst(_,name)
  if self.seen[name] then return false end
  self.seen[name]=true;table.insert(self.calls,"first:"..name);return true
 end
 function analytics:PlaySeconds() return 4321 end
 return analytics
end

local function stubData(sessions)
 local data={entries={},saves=0}
 for _,s in sessions do data.entries[s.userId]={session=s} end
 function data:Save(session) self.saves+=1;self.lastPayload=session:ToData();return true,"Saved." end
 return data
end

-- A late player who cleared the King, holds enough cash for Veteran I and owns
-- progress in every kept field.
local function veteran(userId,plot)
 local s=Session.new(userId,"Vet"..plot,plot);s.loaded=true
 for _,key in {"guideStarted","guideDeployed","guideCompleted","bought","rolled","collected","collectedEggs","soldEggs","wonCamp","returned","upgraded","introSeen"} do
  s.tutorial[key]=true
 end
 s.kingCleared,s.kingBountyPaid=true,true
 s.firstWins={true,true,true};s.frontierWins={true};s.laneCamps={["-77"]=3}
 s.campUnlocked=#Progression.Camps(1)
 s.coins=(Rebirth.Cost(1) :: number)+12345
 s.eggSpeedLevel,s.incomeLevel,s.luck=3,2,4
 s.plotSizeLevel,s.rollSlotsUnlocked,s.capacity=2,3,5
 s.promotion,s.recruitTier=2,2
 s.hillWins,s.hillRollCredits,s.hillChampion=4,1,true
 s.crateCredits=2;s.purchaseReceipts={p1=123};s.robuxSpent=99;s.adminAssisted=true
 s.eggCarry={count=3,value=900}
 s.passiveEarned,s.battleEarned=5e9,7e6
 s.daily={streak=3,lastDay=20740,best=5}
 s.research.completed.L1=true;s.research.completed.CallArmy=true;s.research.completed.FuseMachine=true
 s.research.revision=5;s.research.operationWins={Raid1=true}
 s.researchEffects=ResearchRules.Effects(s.research);s.fusionUnlocked=true
 s.discovered.Knight=true
 local knight=s:AddPet("Knight",1);knight.level=4;knight.favorite=true;knight.giantSize=6.5
 local dragon=s:AddPet("Dragon",1);dragon.level=3
 s:RefreshArmy()
 return s
end

local function setup()
 local s=veteran(-961,1)
 local f=Session.new(-962,"Friend",2);f.loaded=true;f.tutorial.wonCamp=true;f.tutorial.guideCompleted=true
 local sessions={[s.userId]=s,[f.userId]=f}
 local world=stubWorld()
 local battles=Battles.new(sessions,world)
 local server={sessions=sessions,world=world,battles=battles,eggs=Eggs.new(world),
  data=stubData(sessions),analytics=stubAnalytics()}
 return s,f,server
end

local RESET={coins=true,eggSpeedLevel=true,incomeLevel=true,luck=true,firstWins=true,frontierWins=true,
 laneCamps=true,kingCleared=true,kingBountyPaid=true,eggCarry=true,offlineCash=true,rebirths=true}

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,why=pcall(fn)
  table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
  print((if ok then "PASS " else "FAIL ")..name..(if ok then "" else " :: "..tostring(why)))
 end

 test("Cost, multiplier and enemy scale match the table; rank 16 is unavailable",function()
  local costs={1e9,8e9,64e9,512e9,4096e9}
  local multipliers={1.25,1.5,1.75,2,2.25}
  local scales={1.5,2,2.5,3,3.5}
  for rank=1,5 do
   assert(Rebirth.Cost(rank)==costs[rank],"Cost "..rank..": "..tostring(Rebirth.Cost(rank)))
   near(Rebirth.Multiplier(rank),multipliers[rank],"Multiplier "..rank)
   near(Rebirth.EnemyScale(rank),scales[rank],"Enemy scale "..rank)
  end
  assert(Rebirth.Multiplier(0)==1 and Rebirth.EnemyScale(0)==1,"Rank 0 must be neutral")
  assert(Rebirth.Cost(Config.Rebirth.MaxRank)~=nil)
  assert(Rebirth.Cost(Config.Rebirth.MaxRank+1)==nil and Rebirth.Cost(16)==nil,"Rank 16 is available")
  assert(Rebirth.Cost(0)==nil and Rebirth.Cost(1.5)==nil)
  assert(Rebirth.Title(0)=="Recruit" and Rebirth.Title(1)=="Veteran I" and Rebirth.Title(4)=="Veteran IV"
   and Rebirth.Title(9)=="Veteran IX" and Rebirth.Title(14)=="Veteran XIV" and Rebirth.Title(15)=="Veteran XV")
 end)

 test("The quote has every field R1-C renders",function()
  local s=setup()
  local q=Rebirth.Quote(s)
  assert(q.enabled==true and q.rank==0 and q.nextRank==1 and q.title=="Recruit" and q.nextTitle=="Veteran I")
  assert(q.cost==1e9 and q.coins==s.coins and q.kingCleared==true and q.armyHome==true)
  assert(q.eligible==true and q.reason==nil,"Not eligible: "..tostring(q.reason))
  assert(q.multiplierNow==1 and q.multiplierNext==1.25 and q.enemyScaleNext==1.5)
  local snap=s:Snapshot(0)
  assert(snap.rebirth and snap.rebirth.eligible==true and snap.rebirth.nextTitle=="Veteran I")
 end)

 test("Refusals: disabled, max rank, no King, cash, army away, Operation, stale rank",function()
  -- Disabled.
  local s,_,server=setup()
  local enabled=Config.Rebirth.Enabled
  Config.Rebirth.Enabled=false
  local ok,why=pcall(function()
   local q=Rebirth.Quote(s)
   assert(q.enabled==false and q.eligible==false and q.reason=="Coming soon")
   local done,message=Rebirth.Rebirth(s,0,server)
   assert(not done and message=="Coming soon",message)
  end)
  Config.Rebirth.Enabled=enabled
  if not ok then error(why,0) end
  assert(s.rebirths==0 and s.kingCleared)
  -- Max rank.
  local m,_,mserver=setup();m.rebirths=Config.Rebirth.MaxRank;m.coins=1e15
  local q=Rebirth.Quote(m)
  assert(q.nextRank==nil and q.cost==nil and q.nextTitle==nil and q.reason=="Max rank reached")
  local done,message=Rebirth.Rebirth(m,Config.Rebirth.MaxRank,mserver)
  assert(not done and message=="Max rank reached",message)
  -- No King clear.
  local k,_,kserver=setup();k.kingCleared=false
  done,message=Rebirth.Rebirth(k,0,kserver)
  assert(not done and message=="Defeat the Chicken King first",message)
  -- Not enough cash.
  local c,_,cserver=setup();c.coins=(Rebirth.Cost(1) :: number)-500
  done,message=Rebirth.Rebirth(c,0,cserver)
  assert(not done and message=="Need $500 more",message)
  -- Army away (marching to its own Cluck Camp).
  local a,_,aserver=setup()
  assert(aserver.battles:Attack(a,"camp:1",0))
  assert(not Rebirth.Quote(a).armyHome)
  done,message=Rebirth.Rebirth(a,0,aserver)
  assert(not done and message=="Bring your army home first",message)
  -- Operation running.
  local o,_,oserver=setup()
  oserver.battles.battles.op1={id="op1",attacker=o.userId,operationId="Raid1"}
  o.outgoing,o.armyState="op1","Fighting"
  done,message=Rebirth.Rebirth(o,0,oserver)
  assert(not done and message=="Finish your Operation first.",message)
  -- Stale or missing expected rank.
  local r,_,rserver=setup()
  done,message=Rebirth.Rebirth(r,1,rserver)
  assert(not done and message=="Your rank changed. Try again.",message)
  done=Rebirth.Rebirth(r,nil,rserver);assert(not done)
  -- Not loaded / save lost.
  local l,_,lserver=setup();l.saveLost=true
  assert(not Rebirth.Rebirth(l,0,lserver))
  -- None of these changed anything.
  for _,each in {s,m,k,c,a,o,r,l} do assert(each.rebirths==0 or each==m,"A refusal re-enlisted") end
  assert(c.coins==(Rebirth.Cost(1) :: number)-500 and k.incomeLevel==2 and o.eggSpeedLevel==3)
 end)

 test("A re-enlist resets exactly the reset fields and keeps every other saved field",function()
  local s,f,server=setup()
  -- Flags: two own camps, a friend's camp and the King; the friend holds one of ours.
  server.battles:SetTerritoryOwner("1:1",s,{plot=1,index=1})
  server.battles:SetTerritoryOwner("2:3",s,{plot=2,index=3})
  server.battles:SetTerritoryOwner("king:1",s,{king=true})
  server.battles:SetTerritoryOwner("1:2",f,{plot=1,index=2})
  -- A yard with an egg on the ground.
  local yard=server.eggs:Yard(s)
  table.insert(yard.drops,{id="d1",petId="x",value=500,stack=1,born=0,readyAt=0})
  local before=s:ToData()
  local tutorialBefore=table.clone(s.tutorial)
  local coinsBefore=s.coins
  local ok,message=Rebirth.Rebirth(s,0,server)
  assert(ok,message)
  assert(message=="Re-enlisted as Veteran I",message)
  local after=s:ToData()
  -- Reset fields.
  assert(after.coins==Config.StartingCoins,"coins "..tostring(after.coins))
  assert(after.eggSpeedLevel==0 and after.incomeLevel==0 and after.luck==0)
  assert(#after.firstWins==0 and #after.frontierWins==0 and next(after.laneCamps)==nil)
  assert(after.kingCleared==false and after.kingBountyPaid==false)
  assert(after.eggCarry.count==0 and after.eggCarry.value==0)
  assert(after.rebirths==1 and s.rebirths==1)
  assert(type(after.offlineCash.at)=="number" and after.offlineCash.at>0)
  near(after.offlineCash.rate,Offline.Rate(s),"Offline checkpoint rate")
  assert(Offline.Read(after.offlineCash)~=nil,"Offline checkpoint would not load")
  assert(s.campUnlocked==1)
  -- Every other saved field is identical.
  for key,value in before do
   if RESET[key] then continue end
   assert(deepEqual(value,after[key]),"Kept field changed: "..key)
  end
  for key in after do assert(before[key]~=nil or RESET[key],"New saved field: "..key) end
  assert(after.promotion==2 and after.plotSizeLevel==2 and after.capacity==5 and after.hillChampion==true)
  assert(deepEqual(s.tutorial,tutorialBefore),"Tutorial changed")
  -- Territories: ours released, the friend's flag stays.
  for key,owner in server.battles.campOwners do assert(owner.userId~=s.userId,"Still holds "..key) end
  assert(server.battles.campOwners["1:2"] and server.battles.campOwners["1:2"].userId==f.userId)
  -- The yard was dropped; the next step lays a fresh one.
  assert(server.eggs.yards[s.userId]==nil,"Old yard kept")
  assert(#server.eggs:Yard(s).drops==0)
  -- Saved right away, with the new rank in the payload.
  assert(server.data.saves==1 and server.data.lastPayload.rebirths==1,"No immediate save")
  -- Analytics names (stub).
  local calls=table.concat(server.analytics.calls,",")
  assert(calls:find("count:rebirth.count",1,true) and calls:find("first:rebirth.rank.1",1,true)
   and calls:find("hist:rebirth.playSeconds.1:4321",1,true)
   and calls:find("hist:rebirth.cashAtRebirth:"..coinsBefore,1,true),calls)
  -- Next quote: Veteran II needs a new King clear.
  local q=Rebirth.Quote(s)
  assert(q.rank==1 and q.title=="Veteran I" and q.nextTitle=="Veteran II" and q.cost==8e9)
  assert(q.reason=="Defeat the Chicken King first")
 end)

 test("The same expected rank twice re-enlists only once",function()
  local s,_,server=setup()
  s.coins=1e12 -- Enough for several ranks.
  assert(Rebirth.Rebirth(s,0,server))
  s.kingCleared=true;s.coins=1e12
  local ok,message=Rebirth.Rebirth(s,0,server)
  assert(not ok and message=="Your rank changed. Try again.",message)
  assert(s.rebirths==1 and s.coins==1e12)
  assert(server.data.saves==1)
  -- With the fresh rank it goes through.
  assert(Rebirth.Rebirth(s,1,server))
  assert(s.rebirths==2)
 end)

 test("After re-enlisting, deposits pay the multiplier and cash packs do not",function()
  local s,_,server=setup()
  local rate0=Offline.Rate(s)
  assert(Rebirth.Rebirth(s,0,server))
  near(s:EarnedAmount(100,"eggs"),125,"Egg earnings")
  -- A real deposit through EggService credits the multiplied value.
  local coins=s.coins
  local accepted,credited=server.eggs:AcceptDeposit(s,1,100)
  assert(accepted and credited==125 and s.coins==coins+125,"Deposit paid "..tostring(credited))
  -- Cash packs add product coins directly (ProductService); other sources are flat.
  assert(s:EarnedAmount(100,"robux")==100 and s:EarnedAmount(100,"sale")==100
   and s:EarnedAmount(100,"offline")==100 and s:EarnedAmount(100,"battle")==100)
  -- The offline rate carries the multiplier (compare at equal upgrades).
  local probe=veteran(-969,3);probe.eggSpeedLevel,probe.incomeLevel=0,0
  local flat=Offline.Rate(probe);probe.rebirths=1
  near(Offline.Rate(probe),flat*1.25,"Offline rate multiplier")
  assert(rate0>0)
 end)

 test("Camp and King defenders scale by the right commander's rank",function()
  local s,f,server=setup()
  s.rebirths,f.rebirths=2,1
  local service=server.battles
  local function target(id)
   for _,entry in service:Targets(s,0) do if entry.id==id then return entry end end
   error("Missing target "..id)
  end
  local own=Rules.Power(Progression.Roster(s.promotion,1))
  assert(target("camp:1").power==math.floor(own*Rebirth.EnemyScale(2)),"Own lane power "..target("camp:1").power)
  local friend=Rules.Power(Progression.Roster(f.promotion,1))
  assert(target("camp:2:1").power==math.floor(friend*Rebirth.EnemyScale(1)),"Friend lane power")
  assert(target("king:1").power==King.Definition(4,Rebirth.EnemyScale(2)).power,"King power")
  -- Live defenders on our own lane carry the scaled stats.
  assert(service:Attack(s,"camp:1",0))
  local battle=service.battles[s.outgoing]
  local roster=Progression.Roster(s.promotion,1)
  local index=0
  for _,u in battle.units do if u.side=="B" then
   index+=1
   local pet=roster[index]
   near(u.maxHp,Rules.Stats(pet.species,pet.stars or 1,pet.level).hp*Rebirth.EnemyScale(2),"Defender hp")
   near(u.damage,Rules.Stats(pet.species,pet.stars or 1,pet.level).damage*Rebirth.EnemyScale(2),"Defender damage")
  end end
  assert(index==#roster)
  -- The friend's King court uses the friend's (attacker's) rank.
  f.kingCleared=true
  assert(service:Attack(f,"king:1",0))
  local court=service.battles[f.outgoing]
  local boss
  for _,u in court.units do if u.side=="B" and u.boss then boss=u end end
  assert(boss,"No boss")
  near(boss.maxHp,2800*Rebirth.EnemyScale(1),"King hp")
 end)

 test("The tutorial state is identical before and after",function()
  local s,_,server=setup()
  local before=table.clone(s.tutorial)
  assert(Rebirth.Rebirth(s,0,server))
  assert(deepEqual(before,s.tutorial))
  assert(s:StarterCashReserve()==0 and s:StarterFlockMinimum()==0,"The guide came back")
 end)

 test("A save round trip keeps rebirths and the reset profile loads",function()
  local s,_,server=setup()
  assert(Rebirth.Rebirth(s,0,server))
  local data=s:ToData()
  local loaded=Session.new(s.userId,"Vet1",1)
  local ok,why=loaded:LoadData(data)
  assert(ok,why)
  assert(loaded.rebirths==1 and loaded.coins==Config.StartingCoins and loaded.kingCleared==false)
  assert(loaded:Count()==s:Count() and loaded.research.completed.FuseMachine==true)
  assert(Rebirth.Quote(loaded).title=="Veteran I")
  near(loaded:EarnedAmount(100,"eggs"),125)
 end)

 local failed=0
 for _,r in results do if not r.passed then failed+=1 end end
 print(("RebirthChecks: %d passed, %d failed"):format(#results-failed,failed))
 return results
end
return Checks
