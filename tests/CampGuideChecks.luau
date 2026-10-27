-- October 27 camp ladder and readiness card (WS1 of the retention package;
-- docs/team/CAMP_LADDER_20261027.md): the per-camp strength (Fort Roost x0.60 = 64,
-- Ironbeak HQ x0.55 = 105), the odds bands (1.0 / 1.3), the readiness card's advice and
-- copy, the defeat line and the onFirstWin hook. Snapshot fixtures plus one isolated
-- BattleService with a stub world (no DataStore, live world, Players or prompts).
-- Run in Studio: require(game.ServerStorage.PetRollTests.CampGuideChecks).Run()
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local CampGuide=require(Shared.CampGuide)
local Progression=require(Shared.Progression)
local Rules=require(Shared.Rules)
local Config=require(Shared.Config)
local Session=require(Server.PlayerSession)
local Battles=require(Server.BattleService)
local Checks={}

-- A player after the tutorial who just took Cluck Camp: three basic Chickens in three
-- Army slots, 0 Coins, Army Size I next (1,200), no Chicken Feed.
local function afterCluckCamp(): any
	local pets={}
	for i=1,3 do
		table.insert(pets,{id="d"..i,species="Duck",stars=1,level=1,selected=true,canUpgrade=false,upgradePrice=68})
	end
	return {saveStatus="ready",armyState="Home",coins=0,capacity=3,baseCapacity=3,selectionMode="Auto",
		pets=pets,power=Rules.Power(pets),eggs={carriedValue=0},effects={chickenFeed=0},
		nextSlot={capacity=4,price=1200,tier=1},firstWins={true,false,false},
		tutorial={guideStarted=true,guideCompleted=true,coreDone=true},
		targets={{id="camp:1",power=12},{id="camp:2",power=64},{id="camp:3",power=105}},
		upgradeTree={families={},nodes={ArmySize1={status="Unaffordable",price=1200},
			ChickenFeed={status="Unaffordable",price=1000}}}}
end

local function expect(card,id,text,target,why)
	assert(card,(why or id)..": no card")
	assert(card.id==id,(why or id)..": got "..tostring(card.id).." ("..tostring(card.text)..")")
	if text then assert(card.text==text,(why or id)..": text '"..tostring(card.text).."'") end
	if target~=false then assert(card.target==target,(why or id)..": target "..tostring(card.target)) end
	assert(table.find(CampGuide.Ids,card.id),(why or id)..": id missing from CampGuide.Ids")
end

local function withLadder(patch,fn)
	local ladder=(Config :: any).CampLadder
	local saved={}
	for key,value in patch do saved[key]=ladder[key];ladder[key]=value end
	local ok,why=pcall(fn)
	for key in patch do ladder[key]=saved[key] end
	assert(ok,why)
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,detail=pcall(fn)
		table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
	end

	test("The ladder scales Fort Roost to 64 and Ironbeak HQ to 105; guards keep their stats",function()
		local powers={}
		for i=1,3 do powers[i]=Progression.CampPower(i) end
		assert(table.concat(powers,",")=="12,64,105","Camp powers "..table.concat(powers,","))
		assert(Progression.Strength(1)==1 and Progression.Strength(2)==0.6 and Progression.Strength(3)==0.55 and Progression.Strength(4)==1,"Strengths")
		local roster=Progression.Roster(1,2)
		assert(Progression.ScaledPower(roster,1)==Rules.Power(roster) and Rules.Power(roster)==106,"Scale 1 is Rules.Power")
		assert(Progression.CampPower(2,2)==128,"Rebirth scale multiplies on top: "..Progression.CampPower(2,2))
		return "12 / 64 / 105"
	end)

	test("Odds bands: Very tough below 1.0x, Close fight to 1.3x, Should win from 1.3x",function()
		assert(CampGuide.Difficulty(99,100)=="Very tough" and CampGuide.Difficulty(100,100)=="Close fight")
		assert(CampGuide.Difficulty(129,100)=="Close fight" and CampGuide.Difficulty(130,100)=="Should win")
		assert(CampGuide.Difficulty(5,0)=="Undefended")
		assert(CampGuide.Goal(64)==84 and CampGuide.Goal(105)==137 and CampGuide.Goal(53)==69 and CampGuide.Goal(10)==13,"Goals")
		assert(CampGuide.ShouldWarn(63,64) and not CampGuide.ShouldWarn(64,64) and not CampGuide.ShouldWarn(10,0),"Warn below even only")
		withLadder({AttackWarning=false},function() assert(not CampGuide.ShouldWarn(10,64),"AttackWarning off") end)
		return "bands 1.0 / 1.3"
	end)

	test("Three basic Chickens after Cluck Camp: collect for Army Size I, with the ARMY bar",function()
		local state=afterCluckCamp()
		assert(CampGuide.When(state,{}),"When after Cluck Camp")
		local advice=CampGuide.Advice(state,84)
		assert(advice.kind=="ArmySize" and advice.node=="ArmySize1" and advice.buyPrice==1200,"Advice "..tostring(advice.kind))
		local card=CampGuide.Card(state,{})
		expect(card,"TipCampCollect","Collect eggs: 1,200 more Coins for Army Size I!","Yard")
		assert(card.tag=="NEXT: FORT ROOST" and card.index==1 and card.total==1 and card.camp==2,"Tag "..tostring(card.tag))
		assert(card.progress.value==38 and card.progress.goal==84 and card.progress.label=="ARMY 38 / 84","Bar "..card.progress.label)
		state.coins=400;state.eggs.carriedValue=300
		expect(CampGuide.Card(state,{}),"TipCampCollect","Collect eggs: 500 more Coins for Army Size I!","Yard","Bag counted")
		state.eggs.carriedValue=800
		expect(CampGuide.Card(state,{}),"TipCampSell","Sell your eggs for Army Size I!","EggDeposit")
		state.coins=1200;state.upgradeTree.nodes.ArmySize1.status="Available"
		local buy=CampGuide.Card(state,{})
		expect(buy,"TipCampArmySize","Buy Army Size I for more Army slots!","Upgrades")
		assert(buy.node=="ArmySize1" and buy.outside=="Open Upgrades for more Army slots!" and buy.wrongTab=="Open the Main category!","Menu lines")
		return "Army Size I first"
	end)

	test("A free slot and an improving podium chicken: buy it (else collect for it)",function()
		local state=afterCluckCamp()
		state.capacity,state.baseCapacity=4,4
		state.nextSlot={capacity=6,price=6000,tier=2}
		state.offer={slot=1,species="Noob",level=1,price=600,improvesArmy=true}
		state.offers={state.offer}
		local advice=CampGuide.Advice(state,84)
		assert(advice.kind=="Recruit","Advice "..tostring(advice.kind))
		expect(CampGuide.Card(state,{}),"TipCampCollect","Collect eggs: 600 more Coins for the chicken!","Yard")
		state.coins=600
		expect(CampGuide.Card(state,{}),"TipCampRecruit","Buy the chicken on your podium!","RollStation")
		-- Not an Army upgrade (the server's own check): roll instead of Army Size II with an empty slot.
		state.offer.improvesArmy=false
		expect(CampGuide.Card(state,{}),"TipCampRoll","Roll a stronger chicken for your Army!","RollStation")
		return "Recruit when it improves the Army"
	end)

	test("Chicken Feed: level the Army when owned, get it when it is the cheapest step",function()
		local state=afterCluckCamp()
		state.capacity,state.baseCapacity=4,4
		table.insert(state.pets,{id="d4",species="Duck",stars=1,level=1,selected=true,canUpgrade=false,upgradePrice=68})
		state.power=Rules.Power(state.pets)
		state.nextSlot={capacity=6,price=6000,tier=2}
		state.effects.chickenFeed=1
		for _,pet in state.pets do pet.canUpgrade=true end
		assert(CampGuide.Advice(state,84).kind=="Feed","Feed beats Army Size II")
		expect(CampGuide.Card(state,{}),"TipCampCollect","Collect eggs: 68 more Coins for Feed!","Yard")
		state.coins=100
		expect(CampGuide.Card(state,{}),"TipCampFeed","Feed your Army chickens to level them up!","FeedTool")
		-- No Feed yet and nothing else to buy: Chicken Feed plus its first level.
		state.effects.chickenFeed=0;state.nextSlot=nil;state.coins=1000
		state.upgradeTree.nodes.ChickenFeed.status="Available"
		local get=CampGuide.Card(state,{})
		expect(get,"TipCampFeedGet","Get Chicken Feed to level up your Army!","Upgrades")
		assert(get.node=="ChickenFeed" and get.wrongTab=="Open the Tools category!","Feed hex")
		-- Feed maxed and no slot left: roll.
		state.effects.chickenFeed=1
		for _,pet in state.pets do pet.canUpgrade=false end
		expect(CampGuide.Card(state,{}),"TipCampRoll",nil,"RollStation")
		return "Feed / Get Feed / Roll"
	end)

	test("A manual Army that leaves a stronger chicken at home: Equip Best",function()
		local state=afterCluckCamp()
		state.selectionMode="Manual"
		table.insert(state.pets,{id="u1",species="Chunky",stars=1,level=1,selected=false})
		expect(CampGuide.Card(state,{}),"TipCampEquip","Equip Best in My Army!",nil)
		return "Equip is free"
	end)

	test("Ready at 1.3x: attack Fort Roost, then Ironbeak HQ; nothing before Cluck Camp or after camp 3",function()
		local state=afterCluckCamp()
		state.power=83
		assert(CampGuide.Card(state,{}).id~="TipNextCamp2","83 is not ready")
		state.power=84
		local ready=CampGuide.Card(state,{})
		expect(ready,"TipNextCamp2","Your Army can take Fort Roost! Attack!","Camp2")
		assert(ready.progress.label=="ARMY 84 / 84","Full bar")
		state.firstWins={true,true,false}
		local third=CampGuide.Card(state,{})
		assert(third.tag=="NEXT: IRONBEAK HQ" and third.progress.goal==137,"Ironbeak goal "..tostring(third.progress.goal))
		state.power=137
		expect(CampGuide.Card(state,{}),"TipNextCamp3","Your Army can take Ironbeak HQ! Attack!","Camp3")
		state.firstWins={true,true,true}
		assert(not CampGuide.When(state,{}) and CampGuide.Card(state,{})==nil,"All camps won")
		state.firstWins={false,false,false}
		assert(CampGuide.Card(state,{})==nil,"Before Cluck Camp")
		state.firstWins={true}
		state.tutorial.guideCompleted=false
		assert(CampGuide.Card(state,{})==nil,"During the tutorial")
		state.tutorial.guideCompleted=true
		withLadder({ReadinessTip=false},function() assert(not CampGuide.When(state,{}),"ReadinessTip off") end)
		-- Without a targets list (old snapshot) the rank-0 ladder power stands in.
		state.targets=nil;state.power=10
		assert(CampGuide.Card(state,{}).progress.goal==84,"Fallback power")
		return "TipNextCamp2 / TipNextCamp3"
	end)

	test("Defeat line and warning copy",function()
		assert(CampGuide.DefeatText("Fort Roost",440,64)=="Fort Roost held! +440 Coins from the fight. Get your Army to 84 power, then attack again.")
		assert(CampGuide.DefeatText("Fort Roost",0,64)=="Fort Roost held! Get your Army to 84 power, then attack again.")
		assert(CampGuide.Warning("Fort Roost",38,84)=="Fort Roost is too strong for your Army (38/84). Send Army again to attack anyway.")
		return "copy"
	end)

	test("BattleService fights and shows the scaled camp; a lost first try names the goal; onFirstWin fires",function()
		local s=Session.new(-927,"Camp ladder fixture",1);s.loaded=true
		for _=1,3 do s:AddPet("Duck",1).investment=0 end
		s.tutorial.wonCamp=true
		local world={}
		function world:Position() return Vector3.new(10000,1,-100) end
		function world:CampPosition(i) return Vector3.new(10000,1,i*80) end
		function world:CampFrame(i) return CFrame.new(self:CampPosition(i)) end
		function world:ReturnPosition(_,_,slot) return self:Position()+Vector3.new(slot*3,0,0) end
		function world:PetPosition() return nil end
		function world:SetCampBusy() end
		function world:SetTerritoryOwner() end
		function world:SetOutpostBusy() end
		function world:OutpostFrame(i) return CFrame.new(10200,1,i*80) end
		local service=Battles.new({[s.userId]=s},world)
		local wins={}
		service.onFirstWin=function(attacker,campIndex,isKing) table.insert(wins,{attacker,campIndex,isKing}) end
		local shown
		for _,entry in service:Targets(s,1) do if entry.id=="camp:2" then shown=entry.power end end
		assert(shown==64,"Targets show Fort Roost at "..tostring(shown))
		assert(service:Attack(s,"camp:2",2))
		local battle=assert(service.battles[s.outgoing])
		assert(battle.targetPower==64,"Fought power "..tostring(battle.targetPower))
		for _,u in battle.units do if u.side=="B" and not u.petId then
			local base=Rules.Stats(u.species,1,u.level)
			assert(math.abs(u.maxHp-base.hp*0.6)<1e-6 or math.abs((u.hp or 0)-base.hp*0.6)<1e-6,"Guard hp scaled: "..tostring(u.maxHp or u.hp))
		end end
		battle.bounty=440
		service:Finish(battle,"B",3)
		assert(s.lastResult=="Fort Roost held! +440 Coins from the fight. Get your Army to 84 power, then attack again.","Defeat line: "..tostring(s.lastResult))
		assert(#wins==0,"No first win on a loss")
		-- A won Cluck Camp (no prior win) fires once.
		s.outgoing=nil;s.armyState="Home"
		assert(service:Attack(s,"camp:1",10))
		local cluck=assert(service.battles[s.outgoing])
		for _,u in cluck.units do if u.side=="B" then u.hp=0;u.respawnAt=nil end end
		service:Finish(cluck,"A",11)
		assert(#wins==1 and wins[1][1]==s and wins[1][2]==1 and wins[1][3]==false,"onFirstWin(attacker, 1, false)")
		service.onFirstWin=function() error("boom") end
		service:NotifyFirstWin(s,1,false) -- a failing callback only warns
		return "64 shown and fought; defeat line; first win"
	end)

	local passed=0
	for _,result in results do if result.passed then passed+=1 end end
	print(("[CampGuideChecks] %d/%d passed"):format(passed,#results))
	for _,result in results do
		print((if result.passed then "  PASS " else "  FAIL ")..result.name.." — "..result.detail)
	end
	return results
end

return Checks
