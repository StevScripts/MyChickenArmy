--!strict
-- Personal campaign/slot invariants; no live player or DataStore changes.
local Server=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Battle=require(Server.Battle)
local Battles=require(Server.BattleService)
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local Checks={}
local function wins(s,c,n) for i=1,n do s.campaignWins[c][i]=true end end
local function fixture()
 local a,b=Session.new(701,"A",1),Session.new(702,"B",2)
 local world={}
 function world:Position(index) return Vector3.new(index*100,1,-200) end
 function world:CampPosition(index,plot) return Vector3.new(plot*100,1,-200+index*30) end
 function world:SetCampBusy(_index,_busy,_plot) end
 return a,b,Battles.new({[a.userId]=a,[b.userId]=b},world)
end
function Checks.Run()
 local results={}
 local function test(name,fn) local ok,why=pcall(fn);table.insert(results,{name=name,passed=ok,error=if ok then nil else tostring(why)}) end
 test("Four pads auto-equip four; fifth owned duck remains a producer",function()
  local s=Session.new(1,"T",1);for i=1,3 do s:AddPet("Duck",1) end;s:RefreshArmy()
  assert(s.capacity==4 and #s:Lineup()==4 and s:Count()==5)
  s.armyState="Traveling";s:AccrueIncome(10);assert(#s:HomePets()==1 and s:Income()==.6 and s:HomePets()[1].cash==6)
 end)
 test("Each paid slot requires its permanent conquest milestone",function()
  local s=Session.new(1,"T",1);s.coins=1e6
  for _,capacity in {4,5,6,8,10} do
   local before=s.coins;assert(not Army.Expand(s));assert(s.coins==before and s.capacity==capacity)
   local r=Config.SlotUnlocks[capacity]
   for c=1,r.campaign-1 do wins(s,c,5) end;wins(s,r.campaign,r.camp)
   assert(Army.Expand(s));assert(s.capacity==r.capacity and s.coins==before-r.price)
  end
  assert(s.capacity==12 and not Army.Expand(s))
 end)
 test("Slot purchases cannot change an away squad",function()
  local s=Session.new(1,"T",1);wins(s,1,1);s.coins=1000;s.armyState="Deployed"
  assert(not Army.Expand(s));assert(s.coins==1000 and s.capacity==4)
 end)
 test("Campaign selection rejects forged, locked and busy changes",function()
  local s=Session.new(1,"T",1)
  for _,id in {0,4,1.5,"2",0/0} do assert(not s:SelectCampaign(id)) end
  assert(not s:SelectCampaign(2));wins(s,1,5);s.armyState="Deployed";assert(not s:SelectCampaign(2))
  s.armyState="Home";s.incoming="raid";assert(not s:SelectCampaign(2));s.incoming=nil;assert(s:SelectCampaign(2))
 end)
 test("Stronger replay keeps owned flock, money, paid slots and old clears",function()
  local s=Session.new(1,"T",1);wins(s,1,5);s.coins=9000;s.capacity=8;s.incomeLevel=2
  local id=s:AddPet("Dragon",1).id;s.pets[id].cash=127
  assert(s:SelectCampaign(2));assert(s.coins==9000 and s.capacity==8 and s.pets[id].cash==127 and s.incomeLevel==2)
  assert(s.campUnlocked==1 and not next(s.firstWins) and s:Completed(1))
  assert(s:SelectCampaign(1));assert(s.campUnlocked==5 and s.firstWins[5])
 end)
 test("Roll odds and sampling permanently unlock only earned campaign variants",function()
  for c=1,3 do
   local sum=0;for _,probability in Rules.Odds(4,c) do sum+=probability end;assert(math.abs(sum-1)<1e-9)
   for i=0,1000 do local id=Rules.Draw(4,i/1000,c);assert(c>=2 or id~="IceDuck");assert(c>=3 or id~="StormDuck") end
  end
  local s=Session.new(1,"T",1);wins(s,1,5);assert(s:Snapshot(0).odds.IceDuck>0 and s:Snapshot(0).odds.StormDuck==0)
  assert(s:SelectCampaign(2));assert(s:SelectCampaign(1));assert(s:Snapshot(0).odds.IceDuck>0)
 end)
 test("Two players may fight and hold the same required milestone independently",function()
  local a,b,service=fixture();assert(service:Attack(a,"camp:1",0));assert(service:Attack(b,"camp:1",0))
  local ba,bb=service.battles[a.outgoing],service.battles[b.outgoing]
  assert(ba.destination~=bb.destination);service:Finish(ba,"A",10)
  assert(a.firstWins[1] and not b.firstWins[1] and bb.phase=="Travel")
  assert(service.campBusy["1:1"]==ba.id and service.campBusy["2:1"]==bb.id)
  service:CancelPlayer(a.userId,11);assert(service.campBusy["2:1"]==bb.id);service:Destroy()
 end)
 test("Players on different difficulties use separate enemy rosters and rewards",function()
  local a,b,service=fixture();wins(b,1,5);assert(b:SelectCampaign(2))
  assert(service:Attack(a,"camp:1",0));assert(service:Attack(b,"camp:1",0))
  local ba,bb=service.battles[a.outgoing],service.battles[b.outgoing]
  assert(ba:Alive("B")==#Config.Campaigns[1].camps[1].roster)
  assert(bb:Alive("B")==#Config.Campaigns[2].camps[1].roster)
  assert(ba.reward~=bb.reward);service:Finish(bb,"A",10);assert(not a.firstWins[1] and b.firstWins[1]);service:Destroy()
 end)
 test("First clear bonus cannot be reclaimed by replaying or switching difficulties",function()
  local a,_,service=fixture();wins(a,1,5);a.campUnlocked=5
  assert(service:Attack(a,"camp:1",0));local ba=service.battles[a.outgoing];assert(ba.reward==Config.Camps[1].reward)
  service:Finish(ba,"A",10);local coins=a.coins;service:Finish(ba,"A",11);assert(a.coins==coins)
  assert(service:ReturnHome(a,12));service:Step(.1,18)
  assert(a:SelectCampaign(2));assert(a:SelectCampaign(1));assert(service:Attack(a,"camp:1",19))
  assert(service.battles[a.outgoing].reward==Config.Camps[1].reward);service:Destroy()
 end)
 test("Saved campaign history and every valid capacity round-trip",function()
  for _,capacity in Config.SlotLevels do
   local s=Session.new(1,"T",1);for c=1,3 do wins(s,c,5) end;s.capacity=capacity;s:SelectCampaign(3)
   s:AddPet("StormDuck",1);local data=s:ToData();local t=Session.new(1,"T",1);assert(t:LoadData(data))
   assert(t.capacity==capacity and t.campaign==3 and t:Completed(1) and t:Completed(2) and t:Completed(3) and t:Count()==3)
  end
 end)
 test("Corrupted campaign history fails without partially mutating the session",function()
  for _,bad in {"missing","locked","gap","capacity","extra"} do
   local s=Session.new(1,"T",1);local data=s:ToData();data.coins=9999
   if bad=="missing" then data.campaignWins=nil elseif bad=="locked" then data.campaign=2
   elseif bad=="gap" then data.campaignWins[1]={2} elseif bad=="capacity" then data.capacity=5
   else data.campaignWins[99]={1} end
   assert(not s:LoadData(data));assert(s.coins==150 and s.campaign==1 and s.capacity==4)
  end
 end)
 test("A blocked physical army cannot start combat or receive a remote victory",function()
  local b=Battle.new("blocked",1,"camp:1",Vector3.new(0,1,-20),Vector3.new(0,1,0),0)
  b:AddArmy("A",{{species="Duck",stars=1}},Vector3.new(0,1,-20));b:AddArmy("B",{{species="Duck",stars=1}},Vector3.new(0,1,0))
  b.actors={Sync=function()end,Move=function()end,Stop=function()end,Blocked=function()return false end}
  assert(b:Step(.1,Config.TravelSeconds+1)==nil and b.phase=="Travel")
  assert(b:Step(.1,Config.TravelTimeout+1)=="Blocked" and b.units[2].hp==b.units[2].maxHp)
 end)
 test("A blocked PvP march cannot mint a defender reward",function()
  local a,b,service=fixture();assert(service:Attack(a,"base:"..b.userId,0));local ba=service.battles[a.outgoing]
  service:Finish(ba,"Blocked",12);assert(a.coins==150 and b.coins==150 and a.battleEarned==0 and b.battleEarned==0);service:Destroy()
 end)
 test("Combat hits use measured positions rather than requested destinations",function()
  local b=Battle.new("range",1,"camp:1",Vector3.new(0,1,-20),Vector3.new(0,1,0),0)
  b:AddArmy("A",{{species="Dragon",stars=1}},Vector3.new(0,1,-20));b:AddArmy("B",{{species="Duck",stars=1}},Vector3.new(0,1,0));b.phase="Fight"
  b.actors={Sync=function()end,Move=function()end,Stop=function()end}
  local hp=b.units[2].hp;for i=1,10 do b:Step(.1,i*.1) end;assert(b.units[2].hp==hp)
  b.units[1].x,b.units[1].z=b.units[2].x,b.units[2].z+2;assert(b:Step(.1,2)=="A")
 end)
 test("The strongest obtainable squad can finish every authored campaign",function()
  for c=1,3 do
   local b=Battle.new("ceiling",1,"camp:5",Vector3.new(0,1,-20),Vector3.new(0,1,0),0)
   local roster={};for i=1,(if c==1 then 8 elseif c==2 then 10 else 12) do table.insert(roster,{species=if c==1 then "Dragon" elseif c==2 then "IceDuck" else "StormDuck",stars=1}) end
   b:AddArmy("A",roster,Vector3.new(0,1,-20));local defenders={}
   for _,id in Config.Campaigns[c].camps[5].roster do table.insert(defenders,{species=id,stars=1}) end
   b:AddArmy("B",defenders,Vector3.new(0,1,0));local outcome
   for i=1,600 do outcome=b:Step(.1,i*.1);if outcome then break end end
   assert(outcome=="A","Campaign "..c.." exceeds available power")
  end
 end)
 local passed=0;for _,r in results do if r.passed then passed+=1 end end
 return {passedCount=passed,count=#results,passed=passed==#results,results=results}
end
return Checks
