--!strict
-- Disposable profiles, clocks and combat tables. No live save or purchase writes.
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Server=game.ServerStorage.PetRoll
local Catalog=require(Shared.ResearchCatalog)
local Research=require(Shared.ResearchRules)
local Transactions=require(Server.ResearchService)
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Battle=require(Server.Battle)
local Abilities=require(Server.ArmyAbilities)
local Offline=require(Server.OfflineCash)
local OperationCatalog=require(Shared.OperationCatalog)
local OperationService=require(Server.OperationService)
local Config=require(Shared.Config)
local Currency=require(Shared.CurrencyLimits)
local Eggs=require(Server.EggService)
local PetRules=require(Shared.Rules)
local Checks={}

local function setup()
	local s=Session.new(-9429,"Research fixture",1)
	s.loaded=true;s.coins=1e10
	return s
end
local function grant(s,id)
	local node=Catalog.Nodes[id]
	if node.prerequisite then grant(s,node.prerequisite) end
	s.research.completed[id]=true;s.researchEffects=Research.Effects(s.research)
end
local function start(s,id,now)
	local node=Catalog.Nodes[id]
	return Transactions.Start(s,id,s.research.revision,node.price,Research.Duration(node,s.researchEffects),now)
end
local function near(a,b) assert(math.abs(a-b)<1e-6,tostring(a).." ~= "..tostring(b)) end

function Checks.Run()
	local results={}
	local function check(name,fn)
		local ok,err=pcall(fn);table.insert(results,{name=name,passed=ok,error=if not ok then tostring(err) else nil})
	end
	check("63 unique nodes have acyclic paths, coordinates and implemented effects",function()
		assert(#Catalog.Order==63)
		local ids,coordinates={},{}
		local effects=Research.Effects(Research.New())
		for _,id in Catalog.Order do
			local node=Catalog.Nodes[id];assert(node and not ids[id]);ids[id]=true
			local key=node.q..":"..node.r;assert(not coordinates[key]);coordinates[key]=true
			if id~="Start" then assert(node.price>0 and node.duration>0 and effects[node.effect]~=nil) end
			local visited={};local cursor=id
			while cursor do assert(not visited[cursor] and Catalog.Nodes[cursor]);visited[cursor]=true;cursor=Catalog.Nodes[cursor].prerequisite end
			assert(visited.Start)
		end
	end)
	check("Fresh/legacy research starts with Start and one researcher",function()
		local data=Research.Read(nil);assert(data.completed.Start and #data.jobs==0)
		assert(Research.Effects(data).slots==1 and Research.Effects(data).offlineHours==8 and Research.Effects(data).callArmy==0)
	end)
	check("Call Army unlocks on completed research, persists, and cancelled research refunds once",function()
		local s=setup();local node=Catalog.Nodes.CallArmy;local coins=s.coins
		assert(node.prerequisite=="Start" and Research.Status(s.research,"CallArmy",coins)=="Available")
		assert(s.researchEffects.callArmy==0 and start(s,"CallArmy",100))
		assert(s.coins==coins-node.price and s.researchEffects.callArmy==0)
		local job=s.research.jobs[1]
		assert(not start(s,"CallArmy",101) and s.coins==coins-node.price)
		assert(Transactions.Cancel(s,job.id,s.research.revision,101) and s.coins==coins)
		assert(not Transactions.Cancel(s,job.id,s.research.revision,101) and s.researchEffects.callArmy==0)
		assert(start(s,"CallArmy",200));local finish=s.research.jobs[1].finishAt
		assert(#Transactions.Complete(s,finish-1)==0 and s.researchEffects.callArmy==0)
		assert(#Transactions.Complete(s,finish)==1 and s.researchEffects.callArmy==1)
		assert(#Transactions.Complete(s,finish+1)==0 and s.coins==coins-node.price)
		local loaded=setup();assert(loaded:LoadData(s:ToData()))
		assert(loaded.research.completed.CallArmy and loaded.researchEffects.callArmy==1)
	end)
	check("Existing completed research remains valid without granting Call Army",function()
		local s=setup()
		for _,id in Catalog.Order do if id~="CallArmy" then grant(s,id) end end
		local read=assert(Research.Read(Research.Copy(s.research)))
		assert(not read.completed.CallArmy and Research.Effects(read).callArmy==0)
		for _,id in Catalog.Order do if id~="CallArmy" then assert(read.completed[id]) end end
	end)
	check("Fuse Machine completes through research; a new camp win cannot grant it",function()
		local s=setup();local node=Catalog.Nodes.FuseMachine;local coins=s.coins
		assert(node.prerequisite=="Start" and node.price==5000 and node.duration==120)
		s.firstWins[1]=true
		assert(not s:MergeAccess())
		local rejoined=setup();assert(rejoined:LoadData(s:ToData()));assert(not rejoined:MergeAccess())
		assert(start(s,"FuseMachine",100));local job=s.research.jobs[1]
		assert(not s:MergeAccess() and s.coins==coins-node.price)
		assert(Transactions.Cancel(s,job.id,s.research.revision,101) and s.coins==coins)
		assert(not Transactions.Cancel(s,job.id,s.research.revision,101) and not s:MergeAccess())
		assert(start(s,"FuseMachine",200));local finish=s.research.jobs[1].finishAt
		assert(#Transactions.Complete(s,finish-1)==0 and not s:MergeAccess())
		assert(#Transactions.Complete(s,finish)==1 and s:MergeAccess() and s.researchEffects.fusion==1)
		assert(#Transactions.Complete(s,finish+1)==0 and s.coins==coins-node.price)
		local loaded=setup();assert(loaded:LoadData(s:ToData()))
		assert(loaded:MergeAccess() and loaded.research.completed.FuseMachine)
	end)
	check("Pre-research fusion access migrates without cash or unrelated research grants",function()
		local data=setup():ToData();data.fusionUnlockVersion=nil;data.fusionUnlocked=true
		data.research.completed.A1=true
		local loaded=setup();assert(loaded:LoadData(data))
		assert(loaded:MergeAccess() and loaded.coins==data.coins and loaded.research.completed.FuseMachine)
		assert(loaded.research.completed.A1 and not loaded.research.completed.CallArmy and not loaded.research.completed.A2)
		assert(loaded:ToData().fusionUnlockVersion==2)
	end)
	check("Highest completed tier replaces smaller bonuses",function()
		local s=setup();for _,id in Catalog.Order do grant(s,id) end
		near(s.researchEffects.damage,.25);near(s.researchEffects.health,.25);near(s.researchEffects.armor,.1)
		near(s.researchEffects.production,.2);near(s.researchEffects.eggValue,.15)
		near(s.researchEffects.speed,.25);assert(s.researchEffects.slots==3)
	end)
	check("Prices, prerequisites, duration quotes and stale revisions fail without charging",function()
		local s=setup();local coins=s.coins
		assert(not start(s,"A3",100));assert(not Transactions.Start(s,"A1",0,499,30,100))
		assert(not Transactions.Start(s,"A1",0,500,1,100));assert(not Transactions.Start(s,"A1",1,500,30,100))
		assert(s.coins==coins and #s.research.jobs==0)
	end)
	check("Start is one debit; duplicate request and occupied slot cannot add jobs",function()
		local s=setup();local coins=s.coins;assert(start(s,"A1",100))
		assert(s.coins==coins-500 and #s.research.jobs==1)
		assert(not Transactions.Start(s,"A1",0,500,30,100));assert(not start(s,"E1",100))
		assert(s.coins==coins-500 and #s.research.jobs==1)
	end)
	check("Completion frees a researcher exactly once without another charge",function()
		local s=setup();assert(start(s,"A1",100));local revision=s.research.revision
		assert(#Transactions.Complete(s,129)==0);assert(#Transactions.Complete(s,130)==1)
		assert(#Transactions.Complete(s,1000)==0 and #s.research.jobs==0)
		assert(s.research.revision==revision+1 and #s.researchRecap==1);near(s.researchEffects.damage,.05)
	end)
	check("Cancellation refunds actual paid cash once, without multipliers",function()
		local s=setup();s.entitlements.DoubleCash=true;local coins=s.coins
		assert(start(s,"A1",100));local job=s.research.jobs[1];job.paid=123
		assert(Transactions.Cancel(s,job.id,s.research.revision,110))
		assert(s.coins==coins-500+123);assert(not Transactions.Cancel(s,job.id,s.research.revision,110))
	end)
	check("A finished job cannot be cancelled, and full-wallet refunds preserve the job",function()
		local s=setup();assert(start(s,"A1",100));local job=s.research.jobs[1]
		s.coins=Currency.MaxCoins
		assert(not Transactions.Cancel(s,job.id,s.research.revision,110));assert(#s.research.jobs==1)
		assert(not Transactions.Cancel(s,job.id,s.research.revision,130));assert(s.research.completed.A1)
	end)
	check("Two/three researchers enforce concurrency on independent branches",function()
		local s=setup();grant(s,"S4")
		assert(start(s,"A1",100));assert(start(s,"E1",100));assert(not start(s,"S2",100))
		grant(s,"S5");assert(start(s,"S2",100));assert(#s.research.jobs==3)
		assert(Research.Read(Research.Copy(s.research)))
	end)
	check("Research-speed completion never changes a purchased finish time",function()
		local s=setup();grant(s,"S1");assert(start(s,"A1",100))
		local deadline=s.research.jobs[1].finishAt;assert(deadline==129)
		grant(s,"S3");assert(s.research.jobs[1].finishAt==deadline)
		assert(Research.Duration({duration=3600},s.researchEffects)==2880)
	end)
	check("Research save is copied deeply and rejects malformed/unknown state",function()
		local s=setup();assert(start(s,"A1",100));local data=Research.Copy(s.research)
		data.jobs[1].paid=2;assert(s.research.jobs[1].paid==500)
		data.completed.Wrong=true;assert(not Research.Read(data))
		data=Research.Copy(s.research);data.jobs[2]=table.clone(data.jobs[1]);assert(not Research.Read(data))
	end)
	check("Existing saves retain pets and cash when research is absent",function()
		local s=setup();local data=s:ToData();data.research=nil
		local loaded=setup();assert(loaded:LoadData(data))
		assert(loaded.coins==s.coins and #loaded:BestPetIds()==#s:BestPetIds())
		assert(loaded.research.completed.Start and not loaded.research.completed.A1)
	end)
	check("Offline jobs finish on load; old earning checkpoints remain unchanged",function()
		local s=setup();local now=os.time();assert(start(s,"E1",now-100))
		s.offlineCash={at=now-36000,rate=17,maxSeconds=28800}
		local data=s:ToData();local loaded=setup();assert(loaded:LoadData(data))
		assert(loaded.research.completed.E1 and #loaded.research.jobs==0)
		local award=Offline.Reward(loaded.offlineCash,now,loaded.coins)
		assert(award.amount==17*28800 and award.maxSeconds==28800)
		grant(loaded,"E15");assert(Offline.Reward(loaded.offlineCash,now,loaded.coins).amount==award.amount)
	end)
	check("New farm research combines to 1.38x and does not reprice carried eggs",function()
		local s=setup();s.eggCarry={count=4,value=17}
		local base=Offline.Rate(s);grant(s,"E3");grant(s,"E6")
		near(Offline.Rate(s),base*1.2*1.15)
		assert(s.eggCarry.value==17 and s.eggCarry.count==4)
	end)
	check("Real egg production carries fractional value and preserves old eggs",function()
		local s=setup();s.pets={};s.slots={};s.armySelection=nil
		local pet=s:AddPet("Duck",1)
		local eggs=Eggs.new({});eggs.Lay=function() end
		local dt=1/(PetRules.EggRate(pet.species,pet.stars,pet.level)*s:EggProductionMultiplier())
		local value=PetRules.EggUnitValue(s.incomeLevel)
		eggs:Produce(s,dt,0);local layer=eggs:Yard(s).layers[pet.id]
		assert(layer.count==1 and layer.value==value)
		grant(s,"E6");s.eggCarry={count=2,value=17}
		dt=1/(PetRules.EggRate(pet.species,pet.stars,pet.level)*s:EggProductionMultiplier())
		for i=1,3 do eggs:Produce(s,dt,i) end
		assert(layer.count==4);near(layer.value+s.research.eggValueRemainder,value+3*value*1.15)
		local saved=Research.Read(Research.Copy(s.research));assert(saved);near(saved.eggValueRemainder,s.research.eggValueRemainder)
		for i=4,20 do eggs:Produce(s,dt,i) end
		assert(layer.count==21 and layer.value==value+23*value);near(s.research.eggValueRemainder,0)
		assert(s.eggCarry.count==2 and s.eggCarry.value==17)
	end)
	check("Combat bonuses use base stats and preserve health fraction",function()
		local s=setup();local pet=s:AddPet("Duck",1)
		local battle=Battle.new("r",s.userId,"camp:1",Vector3.zero,Vector3.zero,0)
		battle:AddArmy("A",{pet},Vector3.zero);battle:AddArmy("B",{{species="Duck",stars=1,level=1}},Vector3.zero)
		local unit=battle.units[1];local hp,damage=unit.maxHp,unit.damage;unit.hp=hp*.2
		grant(s,"A3");grant(s,"A6");grant(s,"A16")
		battle:ApplyResearch("A",s.researchEffects,true);near(unit.maxHp,hp*1.25);near(unit.hp/unit.maxHp,.2)
		near(unit.damage,damage*1.45);near(unit.bossDamage,damage*.15)
		battle:ApplyResearch("A",s.researchEffects,true);near(unit.damage,damage*1.45)
		battle:ApplyResearch("B",s.researchEffects,true);near(battle.units[2].maxHp,hp)
	end)
	check("Real landed splash hits apply boss research only to NPC bosses",function()
		local s=setup();grant(s,"A3");grant(s,"A16")
		local pet=s:AddPet("Diamond",1)
		local b=Battle.new("hit",s.userId,"operation:3:3",Vector3.zero,Vector3.zero,0);b.phase="Fight";b.finiteRoster=true
		b:AddArmy("A",{pet},Vector3.zero)
		b:AddArmy("B",{{species="Duck",stars=1,boss=true},{species="Duck",stars=1},{id="enemy-owned",species="Duck",stars=1,boss=true}},Vector3.zero)
		for i,u in b.units do u.x,u.z=(i-1)*.1,0;u.hp,u.maxHp=10000,10000;u.nextAttack=100;u.firstAttack=false end
		b:ApplyResearch("A",s.researchEffects,false)
		local a=b.units[1];a.targetId=b.units[2].id;a.pendingAttack={targetId=a.targetId,hitAt=0}
		b:Step(.001,0)
		near(10000-b.units[2].hp,a.baseDamage*1.4)
		near(10000-b.units[3].hp,a.baseDamage*1.25*Config.SplashDamageFraction)
		near(10000-b.units[4].hp,a.baseDamage*1.25*Config.SplashDamageFraction)
	end)
	check("Real incoming damage uses armor and finite Operations never respawn",function()
		local s=setup();grant(s,"A11");local pet=s:AddPet("Duck",1)
		local b=Battle.new("armor",s.userId,"operation:1:1",Vector3.zero,Vector3.zero,0);b.phase="Fight";b.finiteRoster=true
		b:AddArmy("A",{pet},Vector3.zero);b:AddArmy("B",{{species="Duck",stars=1,noRespawn=true}},Vector3.zero)
		local a,e=b.units[1],b.units[2]
		for _,u in b.units do u.x,u.z=0,0;u.nextAttack=100;u.firstAttack=false end
		b:ApplyResearch("A",s.researchEffects,false);local hp=a.hp
		e.targetId=a.id;e.pendingAttack={targetId=a.id,hitAt=0};b:Step(.001,0);near(hp-a.hp,e.damage*.9)
		a.hp,a.respawnAt=0,1;b:StepReinforcements(.1,100)
		assert(a.hp==0 and b:Step(.1,100)=="B")
	end)
	check("Recovery completion preserves an existing deadline",function()
		local s=setup();local pet=s:AddPet("Duck",1)
		local b=Battle.new("r",s.userId,"camp:1",Vector3.zero,Vector3.zero,0);b:AddArmy("A",{pet},Vector3.zero)
		local unit=b.units[1];unit.hp=0;unit.respawnAt=100
		grant(s,"A13");b:ApplyResearch("A",s.researchEffects,false);b:StepReinforcements(.1,50)
		assert(unit.respawnAt==100 and unit.hp==0)
		unit.respawnAt=nil;b:StepReinforcements(.1,50);near(unit.respawnAt,50+Config.AttackerRespawnSeconds*.8)
	end)
	check("Capture bonus changes only the friendly portion, not neutralization",function()
		local s=setup();grant(s,"S8")
		local b=Battle.new("r",s.userId,"camp:1",Vector3.zero,Vector3.zero,0)
		b:ApplyResearch("A",s.researchEffects,false)
		near(b:CaptureRemaining(),4+4/1.3);b.captureElapsed=2;near(b:CaptureRemaining(),2+4/1.3)
	end)
	check("Rally persists its cooldown and never stacks or works at home",function()
		local s=setup();grant(s,"A14");assert(not Abilities.Rally(s,{battles={}},100))
		s.outgoing="r";local battles={battles={r={phase="Fight",attacker=s.userId,Alive=function() return 1 end}}}
		assert(Abilities.Rally(s,battles,100));assert(s.rallyActiveUntil==108 and s.research.rallyReadyAt==190)
		assert(not Abilities.Rally(s,battles,101));assert(s.rallyActiveUntil==108)
		assert(Research.Read(Research.Copy(s.research)).rallyReadyAt==190)
	end)
	check("Formation saves use owned selected IDs and stale overwrite protection",function()
		local s=setup();grant(s,"S12")
		local ids=s:BestPetIds();local revision=s.research.revision
		assert(Army.SaveFormation(s,1,"First squad",ids,revision))
		assert(not Army.SaveFormation(s,1,"Wrong",ids,revision))
		assert(not Army.SaveFormation(s,2,"Locked",ids,s.research.revision))
		-- Fixture IDs are not real users, so the unfiltered name is replaced, never stored.
		assert(s.research.formations['1'].name=="Formation 1")
	end)
	check("Formation application filters sold birds, capacity and extra Colossals",function()
		local s=setup();grant(s,"S12")
		local a,b=s:AddPet("Dragon",1),s:AddPet("StormDuck",1);a.giantSize=20;b.giantSize=22
		s.research.formations['1']={name="Old squad",petIds={a.id,b.id,"sold"}}
		assert(Army.ApplyFormation(s,1,s:BestPetIds(),s.research.revision))
		local selected=s:BestPetIds();assert(#selected==1 and selected[1]==a.id)
	end)
	check("All nine Operations have fixed authored rosters and rewards",function()
		assert(#OperationCatalog.Order==9)
		for _,id in OperationCatalog.Order do
			local definition=OperationCatalog.Encounters[id];local roster=OperationCatalog.Roster(id)
			assert(#roster>0 and #roster<=15 and definition.replayCash<definition.firstCash)
			assert(OperationCatalog.Power(id)>0)
			for _,pet in roster do assert(pet.noRespawn==true) end
		end
	end)
	check("Operation victory rewards once; replay is lower; abandonment gives nothing",function()
		local s=setup();local removed=0
		local battles={battles={},Remove=function() removed+=1 end}
		local world={UpdateSession=function() end}
		local service=OperationService.new(battles,world,{[s.userId]=s})
		local b={id="first",attacker=s.userId,operationId="1:1",units={}}
		local coins=s.coins;service:Resolve(b,"A",100);service:Resolve(b,"A",100)
		assert(s.coins==coins+150000 and removed==1 and s.research.operationWins['1:1'])
		service:Resolve({id="repeat",attacker=s.userId,operationId="1:1",units={}},"A",101)
		assert(s.coins==coins+165000)
		service:Resolve({id="quit",attacker=s.userId,operationId="1:2",units={}},"Abandoned",102)
		assert(s.coins==coins+165000 and not s.research.operationWins['1:2'])
	end)
	check("A full wallet preserves the exact Operation reward across save and pass changes",function()
		local s=setup();s.coins=Currency.MaxCoins;s.entitlements.DoubleCash=true
		local service=OperationService.new({battles={},Remove=function() end},{UpdateSession=function() end},{[s.userId]=s})
		service:Resolve({id="overflow",attacker=s.userId,operationId="1:1",units={}},"A",100)
		assert(s.research.operationWins['1:1'] and s.research.pendingOperationReward==300000)
		s.research=Research.Read(Research.Copy(s.research));s.entitlements.DoubleCash=false
		assert(OperationService.ClaimReward(s)==0)
		s.coins-=300000;assert(OperationService.ClaimReward(s)==300000 and s.coins==Currency.MaxCoins)
		assert(OperationService.ClaimReward(s)==0 and s.research.pendingOperationReward==0)
	end)
	check("Banner progression requires all three distinct first clears",function()
		local wins={['1:1']=true,['1:2']=true};assert(OperationCatalog.BannerTier(wins)==0)
		wins['1:3']=true;assert(OperationCatalog.BannerTier(wins)==1)
		for i=1,3 do wins['3:'..i]=true end;assert(OperationCatalog.BannerTier(wins)==3)
	end)
	return results
end

return Checks
