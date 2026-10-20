--!strict
-- Runs against isolated sessions and a stub world. Does not touch live player state.
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Rolls=require(Server.RollService)
local Battles=require(Server.BattleService)
local Battle=require(Server.Battle)
local Rules=require(Shared.Rules)
local Config=require(Shared.Config)
local Tests={}

local function equal(actual,expected,message)
	assert(actual==expected,(message or "Mismatch")..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function empty(id)
	local s=Session.new(id or 1,"Tester",id or 1)
	s.pets,s.slots={},{}
	return s
end
local function pet(s,species,stars,slot)
	local p=s:AddPet(species,stars)
	if slot then s.slots[slot]=p.id end
	return p
end
local function setup()
	local sessions={}
	for i=1,3 do sessions[i]=Session.new(i,"Tester"..i,i) end
	local world={}
	function world:Position(index) return Vector3.new(index*60,1,0) end
	function world:SetCampBusy(_index,_busy) end
	return sessions,Battles.new(sessions,world)
end
local function roster(species,count,stars)
	local result={}
	for i=1,count do table.insert(result,{species=species,stars=stars or 1,slot=i}) end
	return result
end
local function simulate(a,b)
	local battle=Battle.new("test",1,"test",Vector3.new(0,1,-35),Vector3.new(0,1,0),0)
	battle:AddArmy("A",a,Vector3.new(0,1,-35));battle:AddArmy("B",b,Vector3.new(0,1,0))
	for step=1,600 do local outcome=battle:Step(0.1,step*0.1);if outcome then return outcome,step*0.1,battle end end
	error("Encounter did not terminate")
end

function Tests.Run()
 local results,metrics={},{}
 local function test(name,fn)
  local ok,why=pcall(fn);table.insert(results,{name=name,passed=ok,error=if ok then nil else tostring(why)})
 end
 test("Starter flock has two ducks and cash is uncollected",function()
  local s=Session.new(1,"T",1);equal(s.coins,Config.StartingCoins);equal(s:Count(),2);equal(#s:Lineup(),2)
  assert(math.abs(s:Income()-1.6)<.001);s:AccrueIncome(10);equal(s.coins,150)
  assert(s:Snapshot(0).storedCash>15.9)
 end)
 test("Cash belongs to individual ducks and collection cannot pay twice",function()
  local s=empty();local a=pet(s,"Duck",1);local b=pet(s,"Mallard",1)
  s:AccrueIncome(10);equal(a.cash,6);equal(b.cash,10)
  equal(s:CollectPet(a.id),6);equal(s.coins,156);equal(a.cash,0);equal(b.cash,10)
  equal(s:CollectPet(a.id),0);equal(s:CollectPet("foreign"),0);equal(s.coins,156)
  assert(s.tutorial.collected)
 end)
 test("Only home ducks earn; deployed balances stay intact",function()
  local s=empty();s.capacity=1;local strong=pet(s,"Dragon",1);local spare=pet(s,"Duck",1)
  s:RefreshArmy();s:AccrueIncome(10);local held=strong.cash;s.armyState="Traveling"
  equal(s:Income(),.6);s:AccrueIncome(10);equal(strong.cash,held);equal(spare.cash,12)
  equal(s:CollectPet(strong.id),0);equal(s:CollectPet(spare.id),12)
  s.armyState="Home";equal(s:CollectPet(strong.id),held)
 end)
 test("Cash capacity prevents unlimited idle accrual",function()
  local s=empty();local a=pet(s,"Duck",1);s:AccrueIncome(1e6)
  equal(a.cash,.6*Config.PetCashCapacitySeconds)
 end)
 test("Successful offer purchase charges once and automatically equips",function()
  local s=Session.new(1,"T",1);local r=Rolls.new();local id=s.offer.id
  local ok,_,petId=r:Buy(s,id);assert(ok);equal(s.coins,90);equal(s:Count(),3);assert(s:FindSlot(petId))
  assert(not r:Buy(s,id));equal(s.coins,90);assert(s.tutorial.bought)
 end)
 test("Unaffordable and full-collection offers are not consumed",function()
  local s=Session.new(1,"T",1);local r=Rolls.new();local offer=s.offer;s.coins=0
  assert(not r:Buy(s,offer.id));equal(s.offer,offer)
  s.coins=1000;while s:Count()<Config.CollectionLimit do pet(s,"Duck",1) end
  assert(not r:Buy(s,offer.id));equal(s.coins,1000);equal(s.offer,offer)
 end)
 test("Reveal delay and cooldown are server enforced",function()
  local s=Session.new(1,"T",1);s.debugNext="Duck";local r=Rolls.new()
  assert(r:Roll(s,100));local id=s.offer.id;assert(not r:Roll(s,101));assert(not r:Buy(s,id,101))
  equal(s.coins,150);assert(r:Buy(s,id,100+Config.RollRevealSeconds));equal(s.coins,90)
  assert(r:Roll(s,104));assert(s.tutorial.rolled)
 end)
 test("A new player's first physical roll is an affordable disclosed starter",function()
  local s=Session.new(1,"T",1);s.offer=nil;local r=Rolls.new()
  assert(r:Roll(s,100));equal(s.offer.species,"Duck");assert(s.offer.starter)
  assert(r:Buy(s,s.offer.id,103));assert(r:Roll(s,104));assert(not s.offer.starter)
 end)
 test("Eight duck odds normalize and luck increases rare odds",function()
  for level=0,4 do local sum=0;for _,chance in Rules.Odds(level) do sum+=chance end;assert(math.abs(sum-1)<1e-9) end
  assert(Rules.Odds(4).Dragon>Rules.Odds(0).Dragon);equal(Rules.Draw(0,0),"Duck");equal(Rules.Draw(0,.99999),"Dragon")
 end)
 test("Auto-best keeps weak owned ducks as productive reserves",function()
  local s=empty();s.capacity=1;local weak=pet(s,"Duck",1);local strong=pet(s,"Viking",1)
  s:RefreshArmy();assert(s:FindSlot(strong.id));equal(s:FindSlot(weak.id),nil);equal(s:Count(),2)
  s.armyState="Deployed";equal(#s:HomePets(),1);equal(s:Income(),.6)
 end)
 test("Sale pays stored cash; duplicate, protected and last-duck sales fail",function()
  local s=empty();local a=pet(s,"Duck",1);local b=pet(s,"Mallard",1);s:AccrueIncome(10)
  assert(not Army.Sell(s,{a.id,a.id}));a.favorite=true;assert(not Army.Sell(s,{a.id}))
  a.favorite=false;assert(Army.Sell(s,{a.id}));equal(s.coins,186);equal(b.cash,10)
  assert(not Army.Sell(s,{b.id}));equal(s:Count(),1)
 end)
 test("A test reset requires the explicit confirmation and resets the intended values",function()
  local ss,b=setup();local s=ss[1];s.coins=999;s.incomeLevel=3
  local d=require(Server.DebugService).new(ss,b);local actor={UserId=1}
  assert(not d:Run(actor,s,"Reset",nil,0));assert(not d:Run(actor,s,"ResetProtected","wrong",0));equal(s.coins,999)
  assert(d:Run(actor,s,"ResetProtected","RESET MY TEST SAVE",0));equal(s.coins,150);equal(s:Count(),2);equal(s.incomeLevel,0)
 end)
 test("Sparse sale requests cannot bypass the last-duck safeguard",function()
  local s=empty();local a=pet(s,"Duck",1);local b=pet(s,"Duck",1)
  assert(not Army.Sell(s,{[1]=a.id,[999]=b.id}));equal(s:Count(),2)
 end)
 test("The first podium purchase can win the introductory camp",function()
  local s=Session.new(1,"T",1);assert(Rolls.new():Buy(s,s.offer.id))
  local guards={};for _,id in Config.Camps[1].roster do table.insert(guards,{species=id,stars=1}) end
  local outcome=simulate(s:Lineup(),guards);equal(outcome,"A")
 end)
 test("Army capacity, luck and home income have bounded paid upgrades",function()
  local s=Session.new(1,"T",1);s.coins=100000
  for c=1,3 do for i=1,5 do s.campaignWins[c][i]=true end end
  for _=1,5 do assert(Army.Expand(s)) end;equal(s.capacity,12);assert(not Army.Expand(s))
  for _=1,4 do assert(Rolls.new():UpgradeLuck(s));assert(Army.UpgradeIncome(s)) end
  assert(not Rolls.new():UpgradeLuck(s));assert(not Army.UpgradeIncome(s));equal(s.luck,4);equal(s.incomeLevel,4)
  assert(math.abs(s:Income()-3.2)<.001);assert(s.tutorial.upgraded)
 end)
 test("New recruits earn at home while active army stays fixed",function()
  local ss,service=setup();local s=ss[1];s.coins=20000;assert(service:Attack(s,"camp:1",0))
  s.offer.species="Dragon";local ok,_,id=Rolls.new():Buy(s,s.offer.id,1);assert(ok)
  equal(s:FindSlot(id),nil);equal(s:Income(),24);assert(not Army.Sell(s,{id}))
  assert(service:ReturnHome(s,2));service:Step(.1,8);assert(s:FindSlot(id));equal(s.armyState,"Home")
 end)
 test("Losing an encounter preserves animals and banked coins",function()
  local ss,service=setup();local s=ss[1];assert(service:Attack(s,"camp:1",0))
  service:Finish(service.battles[s.outgoing],"B",10);equal(s.coins,150);equal(s:Count(),2);equal(s:Income(),0)
  service:Step(.1,16);equal(s.armyState,"Home");assert(s:Income()>0)
 end)
 test("Unattended base raids pay generated coins with a per-opponent cooldown",function()
  local ss,service=setup();local a,b=ss[1],ss[2];b.armyState="Deployed"
  assert(service:Attack(a,"base:2",0));local encounter=service.battles[a.outgoing]
  equal(encounter:Alive("B"),0);service:Finish(encounter,"A",10);equal(a.coins,200);equal(b.coins,150)
  service:Step(.1,16);assert(service:Attack(a,"base:2",17));service:Finish(service.battles[a.outgoing],"A",27)
  equal(a.coins,200);equal(b.coins,150)
 end)
 test("All five NPC formations fit inside their arenas",function()
  for _,camp in Config.Camps do
   local b=Battle.new("bounds",1,"x",Vector3.zero,Vector3.zero,0);local guards={}
   for _,id in camp.roster do table.insert(guards,{species=id,stars=1}) end
   b:AddArmy("B",guards,Vector3.zero)
   for _,u in b.units do assert(math.abs(u.x)+u.size<Config.CampHalfSize);assert(math.abs(u.z)+u.size<Config.CampHalfSize) end
  end
 end)
 test("Six plots face inward and five camps approach the center",function()
  local w=require(Server.WorldService).new();equal(#Config.PlotPositions,6);equal(#Config.Camps,5)
  for i=1,6 do local cf=w:PlotFrame(i);assert(cf.LookVector:Dot(-cf.Position.Unit)>.99) end
  local previous=math.huge;for _,c in Config.Camps do local d=Vector2.new(unpack(c.position)).Magnitude;assert(d<previous);previous=d end
  equal(previous,30)
 end)
 test("A common flock can defeat the first camp",function()
  local guards={};for _,id in Config.Camps[1].roster do table.insert(guards,{species=id,stars=1}) end
  local outcome,duration=simulate(roster("Duck",6),guards);equal(outcome,"A");metrics.commonFirstCampSeconds=duration
 end)
	test("A later camp order starts with the first required camp and reserves it",function()
		local ss,service=setup()
		assert(service:Attack(ss[1],"camp:2",0));equal(service.battles[ss[1].outgoing].target,"camp:1")
		assert(service:Attack(ss[2],"camp:1",0));assert(not service:Attack(ss[1],"base:2",0))
	end)
	test("NPC victory pays once and unlocks the next camp",function()
		local ss,service=setup();local s=ss[1];assert(service:Attack(s,"camp:1",0))
		local battle=service.battles[s.outgoing]
		service:Finish(battle,"A",10);service:Finish(battle,"A",11)
		equal(s.coins,500);equal(s.campUnlocked,2);equal(s:Count(),2)
		service:Step(0.1,60);equal(s.armyState,"Deployed");equal(service.campBusy["1:1"],battle.id)
		equal(battle.phase,"Holding");equal(#battle.units,2);equal(s.coins,500)
		assert(service:ReturnHome(s,61));service:Step(0.1,67);equal(s.armyState,"Home");equal(service.campBusy["1:1"],nil)
	end)
	test("Player base attacks are unilateral and reserve one attacker",function()
		local ss,service=setup();assert(service:Attack(ss[1],"base:2",0))
		equal(ss[2].armyState,"Defending");assert(not service:Attack(ss[3],"base:2",0));equal(#service.battles[ss[1].outgoing].units,4)
	end)
	test("Outgoing raid and incoming attack can coexist",function()
		local ss,service=setup();assert(service:Attack(ss[1],"camp:1",0));assert(service:Attack(ss[2],"base:1",1))
		assert(ss[1].outgoing~=ss[1].incoming);equal(service.battles[ss[1].incoming]:Alive("B"),0)
	end)
	test("Simultaneous lethal hits result in a draw",function()
		local b=Battle.new("draw",1,"x",Vector3.zero,Vector3.zero,0)
		b:AddArmy("A",roster("Duck",1),Vector3.zero);b:AddArmy("B",roster("Duck",1),Vector3.zero)
		b.phase="Fight";b.units[1].x=0;b.units[1].z=0;b.units[2].x=0;b.units[2].z=1
		for _,u in b.units do u.hp=4 end
		equal(b:Step(0.1,1),"Draw")
	end)
	test("Stomp affects at most three enemies",function()
		local b=Battle.new("stomp",1,"x",Vector3.zero,Vector3.zero,0)
		b:AddArmy("A",roster("Dragon",1),Vector3.zero);b:AddArmy("B",roster("Bucket",5),Vector3.zero);b.phase="Fight"
		for i,u in b.units do u.x=0;u.z=if i==1 then 0 else 2;u.nextAttack=if i==1 then 0 else 99 end
		b:Step(0.1,1);local damaged=0
		for _,u in b.units do if u.side=="B" and u.hp<u.maxHp then damaged+=1 end end
		equal(damaged,3)
	end)
	test("Twenty versus twenty terminates and yields profiling data",function()
		local start=os.clock();local outcome,duration=simulate(roster("Duck",20),roster("Duck",20))
		metrics.twentyVersusTwenty={outcome=outcome,simulationSeconds=duration,cpuSeconds=os.clock()-start}
		assert(outcome=="A" or outcome=="B" or outcome=="Draw")
	end)
	test("Rare army changes the result of a common-army matchup",function()
		local outcome,duration=simulate(roster("Dragon",4),roster("Duck",12))
		equal(outcome,"A");metrics.rareArmy={outcome=outcome,seconds=duration}
	end)
	test("A stationed army attacks the next camp from its current position",function()
		local ss,service=setup();local s=ss[1];assert(service:Attack(s,"camp:1",0))
		local old=service.battles[s.outgoing];service:Finish(old,"A",10);service:Step(0.1,11)
		local positions={};for _,u in old.units do positions[u.petId]={x=u.x,z=u.z} end
		assert(service:Attack(s,"camp:2",12));local nextBattle=service.battles[s.outgoing]
		equal(nextBattle.origin,old.destination);equal(service.battles[old.id],nil);equal(service.campBusy["1:1"],nextBattle.id)
		for _,u in nextBattle.units do if u.side=="A" then
			equal(u.x,positions[u.petId].x);equal(u.z,positions[u.petId].z)
			assert(u.homeX~=u.startX or u.homeZ~=u.startZ)
		end end
	end)
	test("Rejected camp orders leave the stationed army and reservation intact",function()
		local ss,service=setup();local s=ss[1];assert(service:Attack(s,"camp:1",0))
		local old=service.battles[s.outgoing];service:Finish(old,"A",10)
		assert(not service:Attack(s,"camp:1",11));assert(not service:Attack(s,"camp:999",11))
		ss[2].campUnlocked=2;assert(service:Attack(ss[2],"camp:2",11))
		assert(service:Attack(s,"camp:2",12));assert(s.outgoing~=old.id);equal(s.armyState,"Traveling")
		equal(service.campBusy["1:1"],s.outgoing);equal(s.coins,500)
	end)
	test("Disconnect or reset clears a held camp without paying again",function()
		local ss,service=setup();local s=ss[1];assert(service:Attack(s,"camp:1",0))
		service:Finish(service.battles[s.outgoing],"A",10);service:CancelPlayer(s.userId,11)
		equal(next(service.battles),nil);equal(service.campBusy["1:1"],nil);equal(s.coins,500)
		service:Step(0.1,17);equal(s.armyState,"Home")
	end)
	test("One order conquers camps in order, pays once each, and holds at the destination",function()
		local ss,service=setup();local s=ss[1]
		assert(service:Targets(s,0)[3].available)
		assert(service:Attack(s,"camp:3",0))
		for index=1,3 do
			local b=service.battles[s.outgoing];equal(b.campIndex,index)
			local at=index*10
			service:Finish(b,"A",at);service:Finish(b,"A",at+0.1)
			service:Step(0.1,at+Config.RouteRegroupSeconds+0.1)
		end
		equal(s.coins,3370);equal(s.armyState,"Deployed")
		local final=service.battles[s.outgoing];equal(final.campIndex,3);equal(final.routeGoal,nil)
		service:Step(0.1,100);equal(s.outgoing,final.id);equal(s.coins,3370)
	end)
	test("Another player cannot block a personal prerequisite route",function()
		local ss,service=setup();local s=ss[1];assert(service:Attack(s,"camp:3",0))
		ss[2].campUnlocked=2;assert(service:Attack(ss[2],"camp:2",1))
		local first=service.battles[s.outgoing];service:Finish(first,"A",10)
		service:Step(0.1,11.3);assert(s.outgoing~=first.id);equal(service.battles[s.outgoing].campIndex,2);equal(s.coins,500)
	end)
	test("Losing or recalling a route cancels every remaining destination",function()
		for _,recall in {false,true} do
			local ss,service=setup();local s=ss[1];assert(service:Attack(s,"camp:3",0))
			local b=service.battles[s.outgoing]
			if recall then
				service:Finish(b,"A",10);assert(service:ReturnHome(s,10.5))
			else service:Finish(b,"B",10) end
			service:Step(0.1,20);equal(s.armyState,"Home");equal(next(service.battles),nil)
			equal(s.firstWins[2],nil);equal(s.firstWins[3],nil)
		end
	end)
	test("Completed prerequisites remain unlocked after coming home",function()
		local ss,service=setup();local s=ss[1];s.campUnlocked=3;s.firstWins[1]=true;s.firstWins[2]=true
		assert(service:Attack(s,"camp:3",0));equal(service.battles[s.outgoing].campIndex,3)
	end)
	test("Camp release waits for the last pet, including its body width",function()
		local ss,service=setup();local s=ss[1];assert(service:Attack(s,"camp:1",0))
		local old=service.battles[s.outgoing];service:Finish(old,"A",10);service:Step(0.1,11)
		assert(service:Attack(s,"camp:2",12));local b=service.battles[s.outgoing]
		local tail=nil
		for _,u in b.units do if u.side=="A" then u.x=100;u.z=100;tail=u end end
		tail.x=0;tail.z=Config.Camps[1].position[2]+Config.CampHalfSize+tail.size*1.35
		service:ReleaseClearedCamps(13);equal(service.campBusy["1:1"],b.id)
		tail.z+=2;service:ReleaseClearedCamps(13.1);equal(service.campBusy["1:1"],b.id)
		service:ReleaseClearedCamps(13.6);equal(service.campBusy["1:1"],nil);equal(service.campBusy["1:2"],b.id)
	end)
	test("Rapid retarget and recall preserve all departing camp reservations",function()
		local ss,service=setup();local s=ss[1];assert(service:Attack(s,"camp:1",0))
		service:Finish(service.battles[s.outgoing],"A",10);service:Step(0.1,11)
		assert(service:Attack(s,"camp:2",12));local b=service.battles[s.outgoing]
		assert(service:ReturnHome(s,12.1));equal(service.campBusy["1:1"],b.id)
		service:Step(0.1,18);equal(next(service.campBusy),nil);equal(next(service.departingCamps),nil)
	end)
	test("Departing army starts at actual roaming positions",function()
		local ss,service=setup();local s=ss[1]
		function service.world:PetPosition(_index,_id) return Vector3.new(12,1,18) end
		assert(service:Attack(s,"camp:1",0));local b=service.battles[s.outgoing]
		for _,u in b.units do if u.side=="A" then equal(u.x,12);equal(u.z,18) end end
	end)
	test("Equal-power purchases do not shuffle equipped pets",function()
		local s=empty();s.capacity=1;local first=pet(s,"Duck",1,1);pet(s,"Duck",1)
		assert(not s:RefreshArmy());equal(s.slots[1],first.id)
		pet(s,"Duck",1);assert(not s:RefreshArmy());equal(s.slots[1],first.id)
	end)
 local passed=0;for _,r in results do if r.passed then passed+=1 end end
 return {passed=passed,total=#results,cases=results,metrics=metrics}
end
return Tests
