-- Attacking any commander's lane, Mini War style (October 13): any camp in any
-- order, held territories pay egg value, a hold limit, contested camps pay half.
-- Isolated sessions and a stub world; no saved players or live-world mutation.
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local Battles=require(Server.BattleService)
local Route=require(Shared.CampaignRoute)
local Config=require(Shared.Config)
local Checks={}

local function setup()
 local s=Session.new(-931,"Stev",1);s.loaded=true;s.tutorial.wonCamp=true
 local f=Session.new(-932,"Friend",2);f.loaded=true;f.tutorial.wonCamp=true
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
 return s,f,Battles.new({[s.userId]=s,[f.userId]=f},world),world
end

local function current(service,session) return assert(service.battles[session.outgoing]) end
local function target(service,session,id)
 for _,entry in service:Targets(session,0) do if entry.id==id then return entry end end
 return nil
end
-- Defenders down, army on site, capture complete.
local function conquer(service,session,now)
 local b=current(service,session)
 for _,u in b.units do
  if u.side=="B" then u.hp=0;u.respawnAt=nil
  else u.x,u.z,u.marchPath,u.reinforcing,u.retiring=b.destination.X,b.destination.Z,nil,false,false end
 end
 service:Finish(b,"A",now)
 return b
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,why=pcall(fn)
  table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
 end

 test("Any camp on any commanded lane is a direct order",function()
  local s,_,service=setup()
  for i=1,3 do
   local entry=assert(target(service,s,"camp:2:"..i),"Missing friend's camp "..i)
   assert(entry.name=="Friend's "..Route.Name("camp:"..i) and entry.laneOwnerName=="Friend")
   assert(entry.available and not entry.via and entry.holdBonus==Config.Territories.CampBonus[i])
  end
  assert(not target(service,s,"camp:3:1"),"An open plot's lane was listed")
  assert(service:Attack(s,"camp:2:3",0))
  local b=current(service,s)
  assert(b.target=="camp:2:3" and not b.routeGoal and b.plotIndex==2 and b.campKey=="2:3")
  assert(b.destination==Vector3.new(2000,1,240))
  local _,_,service2=setup();local own=service2.sessions[-931]
  assert(service2:Attack(own,"camp:3",0) and current(service2,own).target=="camp:3","Own lane still forced order")
 end)

 test("New commanders take their own Cluck Camp first",function()
  local s,_,service=setup();s.tutorial.wonCamp=false
  for _,id in {"camp:2","camp:2:1","king:1"} do
   local entry=assert(target(service,s,id))
   assert(not entry.available and entry.reason=="Take your Cluck Camp first",id)
   local ok,why=service:Attack(s,id,0);assert(not ok and why:find("Cluck Camp",1,true))
  end
  assert(target(service,s,"camp:1").available and service:Attack(s,"camp:1",0))
  conquer(service,s,1)
  assert(service:Started(s) and target(service,s,"camp:2:1").available)
 end)

 test("A foreign win is saved per lane, takes the flag and grants no first win",function()
  local s,f,service,world=setup()
  assert(service:Attack(s,"camp:2:2",0));conquer(service,s,1)
  assert(s.laneCamps[tostring(f.userId)]==2 and not s.firstWins[2])
  assert(service.campOwners["2:2"].userId==s.userId and world.owners["2:2"]==s.userId)
  assert(s.lastResult:find("+15% egg value",1,true))
 end)

 test("The friend retakes their camp",function()
  local s,f,service=setup()
  service:SetTerritoryOwner("2:2",s,{plot=2,index=2})
  local entry=assert(target(service,f,"camp:2"))
  assert(not entry.owned and entry.available and entry.reason:find("Stev",1,true))
  assert(service:Attack(f,"camp:2",0))
  local b=current(service,f);assert(b:Alive("B")>0 and not b.friendlyTerritory)
  conquer(service,f,1)
  assert(service.campOwners["2:2"].userId==f.userId)
 end)

 test("The King opens after one full lane in any order, not a mix of lanes",function()
  local s,f,service=setup()
  s.firstWins={true,true};s.laneCamps={[tostring(f.userId)]=4}
  assert(not service:KingOpen(s))
  assert(service:Attack(s,"king:1",0) and current(service,s).target=="camp:3")
  local s2,f2,service2=setup()
  for _,i in {3,1,2} do
   assert(service2:Attack(s2,"camp:2:"..i,i*10),"Order "..i.." failed")
   conquer(service2,s2,i*10+1)
   if i~=2 then assert(not service2:KingOpen(s2)) end
  end
  assert(service2:KingOpen(s2) and s2.laneCamps[tostring(f2.userId)]==7 and next(s2.firstWins)==nil)
  assert(service2:Attack(s2,"king:1",50) and current(service2,s2).target=="king:1")
 end)

 test("Held territories pay stacking egg value; contested ones pay half",function()
  local s,f,service=setup()
  service:SetTerritoryOwner("1:1",s,{plot=1,index=1})
  service:SetTerritoryOwner("2:3",s,{plot=2,index=3})
  service:SetTerritoryOwner("king:1",s,{king=true})
  service:RefreshTerritoryBonus()
  local bonus=Config.Territories
  local full=bonus.CampBonus[1]+bonus.CampBonus[3]+bonus.KingBonus
  assert(math.abs(s.territoryBonus-full)<1e-6,"Bonus "..s.territoryBonus)
  assert(service:Attack(f,"camp:3",1))
  local raid=current(service,f);raid.phase="Fight"
  service:RefreshTerritoryBonus()
  assert(math.abs(s.territoryBonus-(full-bonus.CampBonus[3]*(1-bonus.ContestedShare)))<1e-6,"Contest did not halve")
  raid.phase="Travel";service:RefreshTerritoryBonus()
  assert(math.abs(s.territoryBonus-full)<1e-6,"Marching army already counted as contesting")
  service:SetTerritoryOwner("king:1",nil);service:RefreshTerritoryBonus()
  assert(math.abs(s.territoryBonus-(full-bonus.KingBonus))<1e-6)
  assert(f.territoryBonus==0)
 end)

 test("The hold limit stops a new capture until one is unclaimed; research raises it",function()
  local s,f,service=setup()
  local others={}
  for plot=3,6 do
   local o=Session.new(-940-plot,"Other"..plot,plot);o.tutorial.wonCamp=true
   service.sessions[o.userId]=o;table.insert(others,o)
  end
  for plot=3,5 do for i=1,3 do
   if service:HoldCount(s)<Config.Territories.HoldLimit then service:SetTerritoryOwner(plot..":"..i,s,{plot=plot,index=i}) end
  end end
  assert(service:HoldCount(s)==8 and service:HoldLimit(s)==8)
  local entry=assert(target(service,s,"camp:2:1"))
  assert(not entry.available and entry.reason:find("8/8",1,true))
  local ok,why=service:Attack(s,"camp:2:1",0);assert(not ok and why:find("Unclaim",1,true))
  s.researchEffects.holdCap=9
  assert(service:HoldLimit(s)==9 and service:Attack(s,"camp:2:1",1))
  -- A capture that lands on a full limit beats the camp but plants no flag.
  s.researchEffects.holdCap=0
  conquer(service,s,2)
  assert(not service.campOwners["2:1"] and s.laneCamps[tostring(f.userId)]==1 and s.lastResult:find("limit",1,true))
 end)

 test("A returning army turns around; a beaten one recovers first",function()
  local s,_,service=setup();s.firstWins={true}
  assert(service:Attack(s,"camp:1",0))
  local b=current(service,s)
  for _,u in b.units do if u.side=="A" then u.x,u.z=1000,-40 end end
  assert(service:ReturnHome(s,1) and b.phase=="Returning" and s.armyState=="Returning")
  assert(target(service,s,"camp:2").available,"Returning army could not be sent")
  assert(service:Attack(s,"camp:2",2))
  local turned=current(service,s)
  assert(turned~=b and turned.target=="camp:2" and s.armyState=="Traveling" and not service.battles[b.id])
  for _,u in turned.units do if u.side=="A" then assert(u.x==1000 and u.z==-40,"Squad jumped instead of turning around") end end
  local s2,_,service2=setup();s2.firstWins={true}
  assert(service2:Attack(s2,"camp:1",0))
  local lost=current(service2,s2);service2:Finish(lost,"B",1)
  local ok,why=service2:Attack(s2,"camp:2",2)
  assert(not ok and why:find("recovering",1,true) and current(service2,s2)==lost)
  assert(not target(service2,s2,"camp:2").available)
 end)

 test("A King order while fighting its first required camp keeps that fight, then moves on",function()
  local s,_,service=setup()
  assert(service:Attack(s,"camp:1",0))
  local b=current(service,s);b.phase="Fight"
  assert(target(service,s,"king:1").available)
  local ok,why=service:Attack(s,"king:1",1)
  assert(ok and why:find("onward",1,true) and current(service,s)==b and b.routeGoal=="king:1")
  conquer(service,s,2)
  assert(b.phase=="Holding" and s.firstWins[1] and not b.autoReturnAt)
 end)

 test("A lane closes when its commander leaves",function()
  local s,f,service,world=setup()
  assert(service:Attack(s,"camp:2:1",0));conquer(service,s,1)
  assert(service:ReturnHome(s,2))
  assert(service:Attack(s,"camp:2:2",3))
  local b=current(service,s)
  service:CancelPlayer(f.userId,4)
  assert(b.phase=="Returning" and s.lastResult:find("Friend",1,true))
  assert(not service.campOwners["2:1"] and world.owners["2:1"]==nil)
  service.sessions[f.userId]=nil
  local ok,why=service:Attack(s,"camp:2:2",5)
  assert(not ok and why:find("no commander",1,true))
  assert(s.laneCamps[tostring(f.userId)]==1,"Leaving erased saved lane progress")
 end)

 test("Lane progress saves, loads and never rejects a profile",function()
  local s=Session.new(-933,"Saver",1)
  s.laneCamps={["-932"]=5,["77"]=7};s.territoryBonus=0.4
  local data=s:ToData()
  assert(data.territoryBonus==nil,"Live bonus was saved")
  local loaded=Session.new(-933,"Saver",1)
  assert(loaded:LoadData(data))
  assert(loaded.laneCamps["-932"]==5 and loaded.laneCamps["77"]==7 and loaded.territoryBonus==0)
  data.laneCamps={bad=1,["5"]=9,["6"]="x",["7"]=2,["8"]=0}
  local junk=Session.new(-933,"Saver",1);assert(junk:LoadData(data))
  local count=0;for _ in junk.laneCamps do count+=1 end
  assert(count==1 and junk.laneCamps["7"]==2)
  -- The same-day draft field (highest camp in order) reads as camps 1..N.
  data.laneCamps=nil;data.laneWins={["9"]=2,["10"]=4}
  local draft=Session.new(-933,"Saver",1);assert(draft:LoadData(data))
  assert(draft.laneCamps["9"]==3 and draft.laneCamps["10"]==nil)
  data.laneWins=nil
  local old=Session.new(-933,"Saver",1);assert(old:LoadData(data) and next(old.laneCamps)==nil)
  local many={};for i=1,150 do many[tostring(i)]=if i<=10 then 7 else 1 end
  data.laneCamps=many
  local big=Session.new(-933,"Saver",1);assert(big:LoadData(data))
  count=0;for _ in big.laneCamps do count+=1 end
  assert(count==100 and big.laneCamps["1"]==7)
  -- A camp-win gap from the old mid-march redirect still loads.
  data.laneCamps=nil;data.firstWins={1,3}
  local gap=Session.new(-933,"Saver",1);assert(gap:LoadData(data))
  assert(gap.firstWins[1] and gap.firstWins[3] and not gap.firstWins[2])
 end)
 return results
end
return Checks
