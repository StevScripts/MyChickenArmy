-- October 20 Commander guide and Next goals (S14; docs/team/COMMANDER_TUTORIAL.md).
-- October 21: the short core (5 eggs, sell, Flock Size I, FREE roll) and the tips.
-- Later October 21: eight lessons; the last sends the Army to a Camp and the win ends it.
-- October 23 empty start: six lessons (roll, chicken, 3 eggs, sell, claim Start, Flock
-- Size I), then the Egg Vacuum, Cluck Camp and Rebirth 0 tips ("TIP • n/N").
-- October 24: a seventh lesson, pull the lever again; the egg hint stays until the vacuum;
-- the Camp tip once a little settled in. October 25: eight lessons (card 8 recruits the
-- second basic Chicken at 150, with the arrow to the pad when short); the free vacuum's
-- tip after 12 more eggs by hand, ending with a sale; five pulls favour the Chicken.
-- Snapshot routing plus a real-session opening route. Isolated sessions only: no
-- DataStore, live world, Players or prompts. Run in Studio:
-- require(game.ServerStorage.PetRollTests.CommanderGuideChecks).Run()
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Guide=require(Shared.TutorialGuide)
local Tree=require(Shared.UpgradeCatalog)
local Session=require(Server.PlayerSession)
local Upgrades=require(Server.UpgradeService)
local Tools=require(Server.ToolService)
local Tutorial=require(Server.TutorialService)
local Rolls=require(Server.RollService)
local Config=require(Shared.Config)
local Checks={}

local function expect(current,id,text,why)
	assert(current,(why or id)..": no step")
	assert(current.id==id,(why or id)..": got "..tostring(current.id).." ("..tostring(current.text)..")")
	if text then assert(current.text==text,(why or id)..": text '"..tostring(current.text).."'") end
end

-- The empty opening right after joining (October 23): no chickens, 0 Coins, one roll
-- podium, Start claimable, Flock Size I at 30 Coins, Rebirth 0 pending.
local function opening()
	return {saveStatus="ready",armyState="Home",coins=0,capacity=3,selectedCount=0,flock={size=3},
		tutorial={starterArmy=true,guideStarted=true,collectedEggCount=0,startClaimed=false,rollCount=0},pets={},
		starterCashReserve=0,starterArmyReserve=0,starterRecruitPrice=0,eggs={carriedValue=0},nextSlot={capacity=4,price=300,tier=1},
		tools={eggVacuum=false,chickenFeed=false,vacuum={count=0,capacity=25}},
		introRebirth="pending",rebirth={intro=true,rank=0,cost=1700,eligible=false},gems=0,gemsEarned=0,
		upgradeTree={families={},nodes={Start={status="Claim",claimable=true,price=0},Flock1={status="Available",price=10},
			ArmySize1={status="Available",price=300},EggVacuum={status="Available",price=0}}}}
end

-- A player who finished the eight lessons (two chickens, Flock Size I, two pulls, nothing pending).
local function afterGuide()
	local state=opening()
	state.tutorial={starterArmy=true,guideStarted=true,guideCompleted=true,coreDone=true,bought=true,soldEggs=true,
		rolled=true,rollCount=2,startClaimed=true,collectedEggCount=3}
	state.pets={{id="a"},{id="b"}};state.selectedCount=2
	state.flock={size=4};state.upgradeTree.families.Flock=1
	state.upgradeTree.nodes.Start={status="Start"};state.upgradeTree.nodes.Flock1={status="Owned"}
	state.upgradeTree.nodes.EggVacuum={status="Available",price=0} -- free since October 25
	return state
end

-- A tip card's place and chain.
-- October 27 (WS5): run `fn` with Config.Guide switched as given, then restore it.
local function withGuide(values,fn)
	local guide=Config.Guide
	local saved={}
	for key,value in values do saved[key]=guide[key];guide[key]=value end
	local ok,result=pcall(fn)
	for key in values do guide[key]=saved[key] end
	if not ok then error(result,0) end
	return result
end
-- The timed "Next up" card instead of WS1's readiness card (Config.CampLadder.ReadinessTip),
-- so these checks read the same with or without CampGuide in the place.
local function timedCamp(fn)
	return function()
		local ladder=(Config :: any).CampLadder
		local saved=if type(ladder)=="table" then ladder.ReadinessTip else nil
		if type(ladder)=="table" then ladder.ReadinessTip=false end
		local ok,result=pcall(fn)
		if type(ladder)=="table" then ladder.ReadinessTip=saved end
		if not ok then error(result,0) end
		return result
	end
end
-- The 1.26 expectations, frozen: every new Config.Guide switch off.
local function legacy(fn)
	return timedCamp(function() return withGuide({Goals=false,ArmyTips=false,Rebuild=false,Grow=false},fn) end)
end

local function tipIs(card,id,text,index,total,chain,why)
	expect(card,id,text,why)
	assert(card.tag=="TIP" and card.index==index and card.total==total and card.chain==chain,
		(why or id)..": "..tostring(card.tag).." "..tostring(card.index).."/"..tostring(card.total).." "..tostring(card.chain))
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,detail=pcall(fn)
		table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
	end

	test("The opening rolls the first chicken, then teaches clicking 3 eggs in the player's own input",function()
		local state=opening()
		local first=Guide.Resolve(state)
		expect(first,"Roll","Pull the lever for a chicken!")
		assert(first.tag=="TUTORIAL" and first.index==1 and first.total==8 and first.target=="RollStation","Tag "..tostring(first.tag).." "..tostring(first.index).."/"..tostring(first.total))
		assert(not Guide.EggHint(state,Guide.Facts(state)),"No egg hint before a chicken")
		state.tutorial.rolled,state.tutorial.rollCount,state.offer=true,1,{price=0}
		local recruit=Guide.Resolve(state)
		expect(recruit,"Recruit","Grab your chicken!")
		assert(recruit.index==2,"Recruit is 2/8")
		-- A roll that gave nothing to take (an old offer gone) asks for the lever again, without "free".
		state.offer={price=600}
		expect(Guide.Resolve(state),"Roll","Pull the lever again!")
		state.tutorial.bought,state.offer=true,nil
		state.pets={{id="a"}};state.selectedCount=1
		local collect=Guide.Resolve(state)
		expect(collect,"Collect","Click your eggs to collect them! (0/3)")
		assert(collect.index==3 and collect.target=="Yard","Collect is 3/8")
		assert(Guide.EggHint(state,Guide.Facts(state)),"Egg hint on with the first chicken")
		expect(Guide.Resolve(state,"Touch"),"Collect","Tap your eggs to collect them! (0/3)")
		expect(Guide.Resolve(state,"Gamepad"),"Collect","Press R2 to collect your eggs! (0/3)")
		assert(Guide.EggGoal==3 and Guide.CollectedEggCount({collectedEggCount=37})==3,"Saved counts clamp to 3")
		assert(Guide.EggsCollected({collectedEggCount=37})==37,"The tip count runs on past 3")
		state.tutorial.collectedEggCount=3
		expect(Guide.Resolve(state),"RecoverCollect","Collect eggs in your yard","Nothing to sell yet")
		state.eggs.carriedValue=36
		local sell=Guide.Resolve(state)
		expect(sell,"Sell","Sell your eggs on the green pad!")
		assert(sell.index==4 and sell.target=="EggDeposit","Sell is 4/8")
		assert(Guide.EggHint(state,Guide.Facts(state)),"Egg hint stays on through the sale")
		return "Roll, chicken, Click/Tap/R2 wording; 37 clamps to 3"
	end)

	test("Eight lessons: roll, chicken, 3 eggs, sell, claim Start, Flock Size I, roll again, recruit it; then complete",function()
		local state=opening()
		state.tutorial.rolled,state.tutorial.rollCount,state.tutorial.bought=true,1,true
		state.pets={{id="a"}};state.selectedCount=1
		state.tutorial.collectedEggCount,state.tutorial.soldEggs,state.coins=3,true,36
		local start=Guide.Resolve(state)
		expect(start,"Start","Claim Start!")
		assert(start.index==5 and start.total==8 and start.target=="Upgrades" and start.node=="Start"
			and start.outside=="Open Upgrades!" and start.wrongTab=="Open the Main category!","Start lesson")
		state.tutorial.startClaimed=true
		state.upgradeTree.nodes.Start={status="Start"}
		-- Flock Size I costs 10: short of it, the card sends the player back to the eggs.
		state.coins=4
		expect(Guide.Resolve(state),"RecoverCollect","Collect eggs worth 6 more Coins","Short of Flock Size I")
		state.eggs.carriedValue=8
		expect(Guide.Resolve(state),"RecoverSell","Sell your eggs on the green pad!","A bag that covers it")
		state.eggs.carriedValue,state.coins=0,12
		local expand=Guide.Resolve(state)
		expect(expand,"Expand","Expand your plot!")
		assert(expand.index==6 and expand.total==8 and expand.target=="Upgrades" and expand.node=="Flock1"
			and expand.outside=="Open Upgrades!" and expand.wrongTab=="Open the Main category!","Expand lesson")
		assert(not Guide.Facts(state).Core,"Not done before Flock Size I")
		-- The tree tier says it is bought (a snapshot without tiers reads Flock Size 4).
		state.upgradeTree.families.Flock,state.upgradeTree.nodes.Flock1=1,{status="Owned"}
		state.flock={size=4}
		assert(Guide.Facts(state).Expand and not Guide.Facts(state).Core,"Not done before the second pull")
		-- Lesson 7: the lever again; an unbought offer on the podium does not matter.
		state.offer={price=150}
		local again=Guide.Resolve(state)
		expect(again,"RollAgain","Roll another chicken!")
		assert(again.index==7 and again.total==8 and again.target=="RollStation","Roll again is 7/8")
		state.tutorial.rollCount=2
		assert(Guide.Facts(state).RollAgain and not Guide.Facts(state).Core,"Not done before the second chicken")
		-- Lesson 8 (October 25): the second chicken (the basic Chicken at 150), with the arrow
		-- to the eggs and the pad while short; the tutorial completes on the recruit.
		state.offer={species="Duck",price=150};state.coins=12
		local short=Guide.Resolve(state)
		expect(short,"RecoverCollect","Collect eggs worth 138 more Coins","Short of the second chicken")
		assert(short.index==8 and short.target=="Yard","The collect arrow is card 8")
		state.eggs.carriedValue=140
		local sell2=Guide.Resolve(state)
		expect(sell2,"RecoverSell","Sell your eggs on the green pad!","A bag that covers it")
		assert(sell2.target=="EggDeposit","The sell arrow points at the pad")
		state.eggs.carriedValue,state.coins=0,150
		local buy2=Guide.Resolve(state)
		expect(buy2,"BuyChicken","Buy the chicken!")
		assert(buy2.index==8 and buy2.total==8 and buy2.target=="RollStation","Buy is 8/8")
		state.offer=nil
		expect(Guide.Resolve(state),"RollMore","Roll another chicken!","No offer on the podium")
		state.pets={{id="a"},{id="b"}};state.selectedCount=2
		assert(Guide.Facts(state).Core and Guide.Facts(state).Recruit2,"Done with the second chicken")
		expect(Guide.Resolve(state),"Complete",Guide.CompleteText)
		assert(Guide.RollCount({rollCount=37})==Guide.RollCountLimit and Guide.RollCount({rolled=true})==1
			and Guide.RollCount({guideCompleted=true})==Guide.RollCountLimit and Guide.RollCount({})==0,"Roll counts")
		state.upgradeTree.families.Flock=nil
		assert(Guide.Facts(state).Expand,"Flock Size 4 without tiers")
		state.flock={size=3}
		assert(not Guide.Facts(state).Expand,"Flock Size 3 without tiers")
		local order=table.concat(Guide.Core,",")
		assert(order=="Roll,Recruit,Collect,Sell,Start,Expand,RollAgain,Recruit2",order)
		assert(Guide.Version=="empty-8-recruit" and Guide.CompleteText=="Your yard is up and running. Keep collecting!","Version and payoff")
		local ladder,favor=Config.Economy.StarterLadder,Config.Economy.FavoredRolls
		assert(#ladder==2 and ladder[1].species=="Duck" and ladder[1].price==0 and ladder[2].species=="Duck" and ladder[2].price==20,"Starter ladder")
		assert(favor.rolls==3 and favor.chance==0.5 and favor.species=="Duck","Favoured pulls (Oct 27: 3 x 50%)")
		return "No vacuum or Camp lessons; the second chicken ends it"
	end)

	test("An army walking home shows Return, not the fight",function()
		local state=opening()
		state.tutorial.collectedEggCount,state.tutorial.soldEggs=3,true
		state.outgoing,state.armyState="battle1","Returning"
		expect(Guide.Resolve(state),"Return","Wait for your Army to return")
		state.armyState="Marching"
		expect(Guide.Resolve(state),"Battle","Defeat the enemy and capture their Camp!")
		return "Returning beats outgoing"
	end)

	test("Flags off (1.26): after the tutorial there are no instructions until a tip is ready",legacy(function()
		local state=afterGuide()
		state.tools.eggVacuum,state.tutorial.vacuumEggCount,state.tutorial.vacuumSold=true,10,true -- the vacuum learned
		expect(Guide.Resolve(state),"Complete",Guide.CompleteText,"Only the completion card")
		assert(Guide.NextGoal==nil,"Next goals were removed")
		state.outgoing,state.armyState="battle2","Returning"
		expect(Guide.Resolve(state),"Complete",nil,"No battle or return lines after the tutorial")
		local skipped=opening()
		skipped.tutorial.guideSkipped=true
		assert(Guide.Resolve(skipped)==nil,"A hidden guide shows nothing")
		local legacy=afterGuide()
		legacy.tutorial.guideStarted=nil
		legacy.coins,legacy.rebirth=1700,{intro=true,eligible=true}
		assert(Guide.Resolve(legacy)==nil,"An established player gets no tips either")
		return "Complete card, then nothing"
	end))

	test("Flags off (1.26): after Cluck Camp, a timed card names the next camp on the route until it is won",legacy(function()
		local state=afterGuide()
		state.tools.eggVacuum,state.tutorial.vacuumEggCount,state.tutorial.vacuumSold=true,10,true
		state.firstWins={}
		assert(Guide.NextCamp(state)==nil,"Nothing before Cluck Camp")
		state.firstWins={true}
		assert(Guide.NextCamp(state)==2,"Fort Roost next")
		local card=Guide.Resolve(state)
		tipIs(card,"TipNextCamp2","Next up: conquer Fort Roost!",1,1,"NextCamp")
		assert(card.target=="Camp2" and card.seconds==Guide.NextCampTipSeconds,"Camp2 target, timed")
		expect(Guide.Resolve(state,nil,{TipNextCamp2=true}),"Complete",nil,"Gone for the visit once timed out")
		state.firstWins={true,true}
		tipIs(Guide.Resolve(state,nil,{TipNextCamp2=true}),"TipNextCamp3","Next up: conquer Ironbeak HQ!",1,1,"NextCamp")
		state.firstWins={true,true,true}
		assert(Guide.NextCamp(state)==nil,"Route done")
		expect(Guide.Resolve(state),"Complete",nil,"No card after the route")
		local chain
		for _,tip in Guide.Tips do if tip.id=="NextCamp" then chain=tip end end
		-- October 27: the Camp slot comes before Grow and the GOAL cards (both off here).
		assert(chain and chain.quietEnd==true and Guide.Tips[5]==chain,"Camp slot, no payoff on timeout")
		return "Fort Roost, then Ironbeak HQ"
	end))

	test("The egg hint stays after the tutorial until the vacuum, for empty-start profiles only",function()
		local state=afterGuide()
		assert(Guide.EggHint(state,Guide.Facts(state)),"On after the guide")
		state.tools.eggVacuum=true
		assert(not Guide.EggHint(state,Guide.Facts(state)),"Off once the vacuum is owned")
		state.tools.eggVacuum=false;state.tutorial.vacuumUsed=true
		assert(not Guide.EggHint(state,Guide.Facts(state)),"Off once the vacuum was used")
		state.tutorial.vacuumUsed=nil;state.introRebirth=nil
		assert(not Guide.EggHint(state,Guide.Facts(state)),"Older profiles get no badges after their guide")
		local skipped=afterGuide();skipped.tutorial.guideSkipped=true
		assert(not Guide.EggHint(skipped,Guide.Facts(skipped)),"A skipped guide shows none")
		return "On until the vacuum; empty-start saves only"
	end)

	test("Flags off (1.26): the free Egg Vacuum right after the tutorial, counting 12 more eggs by hand, seven cards, done once the eggs are sold",legacy(function()
		local state=afterGuide()
		-- The tutorial completed at 4 eggs by hand (TutorialService saves eggsAtComplete).
		-- October 27: the chain starts at completion with the count on its first card.
		state.tutorial.eggsAtComplete,state.tutorial.collectedEggCount=4,4
		local eggs=Guide.Resolve(state)
		tipIs(eggs,"TipVacuumEggs","Collect eggs for an Egg Vacuum! (0/12)",1,7,"Vacuum")
		assert(eggs.target=="Yard","The count card points at the eggs")
		state.tutorial.collectedEggCount=15
		tipIs(Guide.Resolve(state),"TipVacuumEggs","Collect eggs for an Egg Vacuum! (11/12)",1,7,"Vacuum","Eleven more eggs is one short")
		state.tutorial.collectedEggCount=16
		state.upgradeTree.nodes.EggVacuum={status="Locked",price=0}
		expect(Guide.Resolve(state),"Complete",nil,"Not while the offer is locked")
		state.upgradeTree.nodes.EggVacuum={status="Available",price=0}
		local buy=Guide.Resolve(state)
		tipIs(buy,"TipVacuum","Claim your Egg Vacuum!",4,7,"Vacuum")
		assert(buy.target=="Upgrades" and buy.node=="EggVacuum" and buy.outside=="Open Upgrades for an Egg Vacuum!" and buy.outsideIndex==2
			and buy.wrongTab=="Open the Tools category!" and buy.wrongTabIndex==3,"Buy card lines")
		-- Without the server's offer in the snapshot the tip shows too (the vacuum is free); a
		-- save finished before the counter existed counts from the lesson's 3 eggs.
		local bare=afterGuide();bare.upgradeTree.nodes.EggVacuum=nil;bare.coins=0;bare.tutorial.collectedEggCount=15
		tipIs(Guide.Resolve(bare),"TipVacuum","Claim your Egg Vacuum!",4,7,"Vacuum","No offer in the snapshot, 12 more eggs")
		assert(Guide.VacuumTipEggs==12 and Tree.Price("EggVacuum",1,0)==0,"Free vacuum, 12 more eggs")
		assert(Guide.EggsAtComplete({})==3 and Guide.EggsAtComplete({eggsAtComplete=4})==4,"Eggs at completion")
		state.tools.eggVacuum=true
		local use=Guide.Resolve(state)
		tipIs(use,"TipVacuumUse","Walk near eggs to vacuum them up! (0/10)",6,7,"Vacuum")
		assert(use.target=="VacuumTool" and use.outside=="Equip your Egg Vacuum!" and use.outsideIndex==5,"Equip words")
		state.tools.vacuum={count=25,capacity=25}
		local full=Guide.Resolve(state)
		tipIs(full,"TipVacuumUse","Vacuum full! Sell your eggs on the green pad!",6,7,"Vacuum")
		assert(full.target=="EggDeposit","Full vacuum goes to the pad")
		state.tools.vacuum={count=5,capacity=25}
		state.tutorial.vacuumEggCount=7
		tipIs(Guide.Resolve(state),"TipVacuumUse","Walk near eggs to vacuum them up! (7/10)",6,7,"Vacuum")
		expect(Guide.Resolve(state,nil,{TipVacuumUse=true}),"Complete",nil,"A dismissed card stays away")
		-- October 25 (Stevin): the chain ends by selling the vacuumed eggs on the pad.
		state.tutorial.vacuumEggCount=10
		local sell=Guide.Resolve(state)
		tipIs(sell,"TipVacuumSell","Sell your eggs on the green pad!",7,7,"Vacuum")
		assert(sell.target=="EggDeposit","The last card points at the pad")
		state.tutorial.vacuumSold=true
		expect(Guide.Resolve(state),"Complete",nil,"Learned once the eggs are sold")
		assert(Guide.VacuumTipGoal==10 and Guide.VacuumGoal==20,"Tip knobs; the saved goal stays 20 for the funnel")
		return "Count 12 eggs, claim, equip, 10 vacuumed, sold"
	end))

	test("Flags off (1.26): Rebirth 0 at 1,700 Coins, then its Gem card; the first Camp once settled with 3 chickens; Rebirth first",legacy(function()
		local state=afterGuide()
		state.pets={{id="a"},{id="b"},{id="c"}};state.selectedCount=3
		-- Three chickens alone bring the vacuum tip; the Camp waits until a little settled in.
		state.tools.eggVacuum,state.tutorial.vacuumEggCount,state.tutorial.vacuumSold=true,10,true
		expect(Guide.Resolve(state),"Complete",nil,"Not settled yet: no Camp tip")
		state.tutorial.vacuumEggCount=20
		local attack=Guide.Resolve(state)
		tipIs(attack,"TipAttack","Send your Army to attack Cluck Camp!",1,1,"Attack")
		assert(attack.target=="Camp1" and Guide.ArmyTipSize==3,"Camp card")
		state.tutorial.vacuumEggCount=10;state.tutorial.collectedEggCount=60
		tipIs(Guide.Resolve(state),"TipAttack","Send your Army to attack Cluck Camp!",1,1,"Attack","60 eggs by hand settle it too")
		assert(Guide.ArmyTipEggs==60,"Settled knob")
		state.selectedCount=2
		expect(Guide.Resolve(state),"Complete",nil,"Two chickens are not an Army yet")
		state.selectedCount=3
		state.outgoing,state.armyState="battle1","Marching"
		expect(Guide.Resolve(state),"Complete",nil,"No tips while the Army is away")
		state.outgoing,state.armyState=nil,"Home"
		-- Rebirth 0 comes first once it is affordable and the quote allows it.
		state.coins,state.rebirth=1700,{intro=true,rank=0,cost=1700,eligible=true}
		local rebirth=Guide.Resolve(state)
		tipIs(rebirth,"TipRebirth","Tap Rebirth! Coins & Upgrades reset, but you keep ×1.5 Coins forever!",2,3,"Rebirth")
		assert(rebirth.target=="Rebirth" and rebirth.outside=="Rebirth is ready! Open it to earn ×1.5 Coins forever!" and rebirth.outsideIndex==1,"Rebirth card lines")
		state.rebirth.eligible=false
		tipIs(Guide.Resolve(state),"TipAttack","Send your Army to attack Cluck Camp!",1,1,"Attack","An ineligible quote yields to the Camp")
		state.coins=349;state.rebirth.eligible=true
		tipIs(Guide.Resolve(state),"TipAttack","Send your Army to attack Cluck Camp!",1,1,"Attack","349 Coins")
		-- After Rebirth 0: the Gem card until a Gem is spent (or the client's timer).
		state.introRebirth,state.coins,state.gems,state.gemsEarned="done",0,30,30
		state.rebirth={rank=0,eligible=false}
		local gems=Guide.Resolve(state)
		tipIs(gems,"TipGems","Pick a Gem Upgrade. They never reset!",3,3,"Rebirth")
		assert(gems.target=="Gems" and gems.seconds==Guide.GemTipSeconds and Guide.GemTipSeconds==20,"Gem card")
		tipIs(Guide.Resolve(state,nil,{TipGems=true}),"TipAttack","Send your Army to attack Cluck Camp!",1,1,"Attack","Timed out Gem card")
		state.gems=20
		tipIs(Guide.Resolve(state),"TipAttack","Send your Army to attack Cluck Camp!",1,1,"Attack","Rebirth learned")
		state.campsWon=1
		expect(Guide.Resolve(state),"Complete",nil,"Camp captured")
		-- A legacy save without Rebirth 0 never sees its tip.
		state.introRebirth,state.coins,state.rebirth=nil,1700,{rank=0,nextRank=1,cost=50000,eligible=false}
		expect(Guide.Resolve(state),"Complete",nil,"No Rebirth 0 for older saves")
		return "Rebirth > Camp > Vacuum; each chain ends when learned"
	end))

	test("The Egg Vacuum is a free Tools node that a session claims, with 0 Coins",function()
		local node=Tree.Nodes.EggVacuum
		assert(node and node.kind=="upgrade" and node.family=="EggVacuum" and node.prerequisite=="ToolsBack","Node shape")
		assert(Tree.Price("EggVacuum",1,0)==0 and Tree.Nodes.VacuumCapacity1.prerequisite=="EggVacuum","Price and chain")
		assert(Tree.DefaultEffects.eggVacuum==0 and Tree.Effects({EggVacuum=1},{}).eggVacuum==1,"Effect key")
		local s=Session.new(-9401,"Vacuum buyer",1)
		s.loaded=true
		local service=Upgrades.new(nil,nil)
		-- October 25 (Stevin): free, so it reads Available with 0 Coins, even mid-guide.
		local quote=service:Snapshot(s).nodes.EggVacuum
		assert(quote.price==0 and quote.status=="Available","Quote "..tostring(quote.status).." "..tostring(quote.price))
		assert(not (service:BuyNode(s,"EggVacuum",150)),"A stale 150-Coin quote accepted")
		assert(not Tools.Owns(s,"EggVacuum"),"Owned before buying")
		local ok,message=service:BuyNode(s,"EggVacuum",0)
		assert(ok,message)
		assert(Tools.Owns(s,"EggVacuum") and s.coins==0 and s.upgradeTree.EggVacuum==1,"Claimed")
		assert(string.find(message,"Egg Vacuum"),message)
		s.upgradeTree={}
		s:RefreshEffects()
		assert(not Tools.Owns(s,"EggVacuum"),"Rebirth reset kept the vacuum")
		return message
	end)

	test("Start is claimed once for 0 Coins; the quote reads Claim, then Start",function()
		local s=Session.new(-9405,"Start claim",1)
		s.loaded=true
		local service=Upgrades.new(nil,nil)
		local quote=service:Snapshot(s).nodes.Start
		assert(quote.status=="Claim" and quote.claimable==true and quote.price==0,"Claimable: "..tostring(quote.status))
		assert(s.tutorial.startClaimed==false,"Fresh profile")
		local ok,message=service:BuyNode(s,"Start",0)
		assert(ok and message=="Start claimed!" and s.tutorial.startClaimed==true and s.coins==0,message)
		assert(service:Snapshot(s).nodes.Start.status=="Start","Claimed quote")
		ok,message=service:BuyNode(s,"Start",0)
		assert(not ok and message=="Start is already claimed.",message)
		local back=Session.new(-9405,"Start reload",1)
		assert(back:LoadData(s:ToData()) and back.tutorial.startClaimed==true,"Saved")
		return "Claim, then Start"
	end)

	test("The vacuum tip counter saves and clamps",function()
		local data=Session.new(-9406,"Counter",1)
		data.tutorial.vacuumEggCount,data.tutorial.coreDone=2,true
		local back=Session.new(-9406,"Counter reload",1)
		local ok,message=back:LoadData(data:ToData())
		assert(ok and back.tutorial.vacuumEggCount==2 and back.tutorial.coreDone==true,"Reload: "..tostring(message))
		local junk=data:ToData()
		junk.tutorial.vacuumEggCount=99
		ok=back:LoadData(junk)
		assert(ok and back.tutorial.vacuumEggCount==Guide.VacuumGoal,"Clamp")
		assert(Guide.VacuumEggCount({vacuumUsed=true})==Guide.VacuumGoal,"Older vacuum users pass")
		-- October 23: eggs by hand count on to 200 (the vacuum tip waits for 10 more).
		junk.tutorial.collectedEggCount=999
		ok=back:LoadData(junk)
		assert(ok and Session.TutorialEggLimit==200 and back.tutorial.collectedEggCount==200,"Hand-egg clamp "..tostring(back.tutorial.collectedEggCount))
		return "2 saved, 99 clamps; 999 eggs by hand clamp to 200"
	end)

	test("The vacuum's first egg ends the equip goal, saved for every player",function()
		local touched=0
		local session={tutorial={},Touch=function() touched+=1 end}
		local state={tutorial={},eggs={receipts={{id="1",collector="player"}},vacuum={count=0}}}
		Tutorial.ObserveVacuum(session,state)
		assert(not session.tutorial.vacuumUsed and touched==0,"A clicked egg counted")
		state.eggs.receipts={{id="2",collector="vacuum"}}
		Tutorial.ObserveVacuum(session,state)
		assert(session.tutorial.vacuumUsed and state.tutorial.vacuumUsed and touched==1,"Vacuum receipt")
		local other={tutorial={},Touch=function() end}
		Tutorial.ObserveVacuum(other,{eggs={vacuum={count=3}}})
		assert(other.tutorial.vacuumUsed,"Cargo in the vacuum")
		local data=Session.new(-9402,"Flag fixture",1)
		data.tutorial.vacuumUsed=true
		local saved=data:ToData()
		local back=Session.new(-9402,"Flag reload",1)
		local ok,message=back:LoadData(saved)
		assert(ok and back.tutorial.vacuumUsed==true,"Saved flag: "..tostring(message))
		return "Receipt and cargo; flag saves"
	end)

	test("The tree arrow rests in an empty neighbour cell, or else on a \"?\" hex",function()
		-- Layout-proof (Upgrades tree v2 moves hexes): checks the rules, not today's sides.
		local function all() return true end
		local function occupant(node,side)
			for other,neighbour in Tree.Nodes do
				if neighbour.category==node.category and neighbour.q==node.q+side[1] and neighbour.r==node.r+side[2] then
					return other
				end
			end
			return nil
		end
		local function firstEmpty(node,order)
			for _,side in order do if not occupant(node,side) then return side end end
			return nil
		end
		local reversed={}
		for index=#Guide.PointerSides,1,-1 do table.insert(reversed,Guide.PointerSides[index]) end
		local empty,boxed,hidden=0,0,0
		for _,id in {"Flock1","ArmySize1","ArmySize2","OpenTools","EggVacuum","ChickenFeed","VacuumCapacity1",
			"ToolsBack","PlayerBack","ArmyBack"} do
			local node=Tree.Nodes[id]
			assert(node,id.." is missing")
			-- The first empty cell in whatever order the client sorts the sides.
			for _,order in {Guide.PointerSides,reversed} do
				local wanted,found=firstEmpty(node,order),Guide.PointerSide(id,all,nil,order)
				assert(found==wanted,id.." took "..(if found then found[1]..","..found[2] else "none"))
			end
			local first=firstEmpty(node,Guide.PointerSides)
			if first then
				empty+=1
				-- A cell that doesn't fit on screen is skipped.
				local skipped=Guide.PointerSide(id,all,function(side) return side~=first end)
				assert(skipped~=first and (skipped==nil or occupant(node,skipped)==nil),id.." used the off-screen cell")
			else
				boxed+=1
				local side=Guide.PointerSides[3]
				local unknown=occupant(node,side)
				assert(Guide.PointerSide(id,all)==nil,id.." found a cell with all six taken")
				assert(Guide.PointerSide(id,all,nil,nil,function(other) return other==unknown end)==side,id.." skipped its ? hex")
			end
			-- A hidden hex (locked further out) leaves its cell free.
			for _,side in Guide.PointerSides do
				if side==first then break end
				local other=occupant(node,side)
				if other then
					assert(Guide.PointerSide(id,function(name) return name~=other end)==side,id.." kept hidden "..other)
					hidden+=1
					break
				end
			end
		end
		assert(empty>0 and hidden>0,"Nothing exercised")
		return empty.." from an empty cell, "..boxed.." boxed in (? fallback), "..hidden.." hidden-hex cases"
	end)

	test("A real empty-start session walks the eight lessons: recruiting the second Chicken ends it",function()
		local s=Session.new(-9403,"Starter route",1)
		-- DataService marks a loaded profile; the guide stays hidden while it is "loading".
		s.loaded,s.saveStatus=true,"saved"
		local service=Upgrades.new(nil,nil)
		local rolls=Rolls.new()
		local function route()
			local state=s:Snapshot(0)
			state.upgradeTree=service:Snapshot(s)
			state.tools={eggVacuum=Tools.Owns(s,"EggVacuum"),chickenFeed=false}
			state.tutorial.guideStarted=true
			return Guide.Resolve(state),state
		end
		assert(s.coins==0 and s:Count()==0 and s.introRebirth=="pending","Empty start")
		local first,opening=route()
		expect(first,"Roll","Pull the lever for a chicken!")
		assert(opening.rebirth.intro==true and opening.rebirth.cost==1700 and opening.rebirth.eligible==false,"Rebirth 0 quoted from the start")
		-- The real lever: the free starter Chicken, then the second Chicken at 20.
		assert(rolls:Roll(s,0))
		assert(s.offer and s.offer.species=="Duck" and s.offer.price==0 and s.tutorial.rollCount==1,"Starter roll")
		expect((route()),"Recruit","Grab your chicken!")
		assert(rolls:Buy(s,s.offer.id,100))
		assert(s:Count()==1 and s.tutorial.bought,"First chicken taken")
		expect((route()),"Collect","Click your eggs to collect them! (0/3)")
		s.tutorial.collectedEggCount,s.tutorial.soldEggs=3,true
		local start,claim=route()
		expect(start,"Start","Claim Start!")
		assert(claim.upgradeTree.nodes.Start.status=="Claim" and claim.upgradeTree.nodes.EggVacuum.price==0,"Start claimable; the vacuum is free")
		local ok,message=service:BuyNode(s,"Start",0)
		assert(ok and s.tutorial.startClaimed and s.coins==0,message)
		expect((route()),"RecoverCollect","Collect eggs worth 10 more Coins","Flock Size I costs 10")
		s.coins=12
		local expand,before=route()
		expect(expand,"Expand","Expand your plot!")
		assert(before.upgradeTree.nodes.Start.status=="Start" and before.upgradeTree.nodes.Flock1.price==10,"Flock Size I at 10")
		local service2=Tutorial.new(function() end)
		service2:Begin(nil,s)
		service2:Observe(s,before)
		assert(not s.tutorial.guideCompleted and not s.tutorial.coreDone,"Not complete before Flock Size I")
		ok,message=service:BuyNode(s,"Flock1",10)
		assert(ok and s.coins==2 and s:FlockSize()==4,message)
		-- October 24: eggs lay every second until the guide completes (one Duck: 4 Coins an egg).
		assert(s:LaySeconds(1)==1 and Config.TutorialEggLaySeconds==1,"Tutorial lay seconds "..tostring(s:LaySeconds(1)))
		expect((route()),"RollAgain","Roll another chicken!")
		assert(rolls:Roll(s,200))
		assert(s.offer and s.offer.species=="Duck" and s.offer.price==20 and s.tutorial.rollCount==2,"Second pull: the basic Chicken at 20, got "..tostring(s.offer and s.offer.species).." "..tostring(s.offer and s.offer.price))
		-- Short of the 20: the card sends the player to the eggs (the pad arrow once the bag covers it).
		expect((route()),"RecoverCollect","Collect eggs worth 18 more Coins","Short of the second Chicken")
		s.coins=20
		local buy2,mid=route()
		expect(buy2,"BuyChicken","Buy the chicken!")
		service2:Observe(s,mid)
		assert(not s.tutorial.guideCompleted,"Not complete before the recruit")
		assert(rolls:Buy(s,s.offer.id,300))
		assert(s:Count()==2 and s.coins==0,"Second chicken for 20")
		local done,final=route()
		expect(done,"Complete",Guide.CompleteText)
		assert(Guide.Facts(final).Core,"Core done")
		service2:Observe(s,final)
		assert(s.tutorial.guideCompleted and s.tutorial.coreDone and s.tutorial.eggsAtComplete==3,"Guide completed at 3 eggs by hand")
		assert(s:LaySeconds(1)==3,"Normal lay seconds after the guide: "..tostring(s:LaySeconds(1)))
		assert(service:Snapshot(s).nodes.Start.status=="Start","Start reads plain once the guide is done")
		-- The next five pulls favour the basic Chicken (60%) at its normal price; a fixed stream.
		s.debugRandom=Random.new(7)
		local chickens=0
		for pull=1,5 do
			assert(rolls:Roll(s,400+pull*100))
			if s.offer.species=="Duck" then chickens+=1 end
			assert(s.offer.price>0,"Normal price after the guide")
		end
		s.debugRandom=nil
		assert(chickens>=2,"Favoured pulls landed "..chickens.." Chickens of 5")
		local back=Session.new(-9403,"Starter reload",1)
		assert(back:LoadData(s:ToData()) and back.tutorial.rollCount==7 and back.tutorial.eggsAtComplete==3,"rollCount and eggsAtComplete save")
		-- The vacuum tip counts 12 more eggs by hand from completion (October 27), then offers it.
		s.tutorial.collectedEggCount=14
		expect((route()),"TipVacuumEggs","Collect eggs for an Egg Vacuum! (11/12)","Eleven more eggs: the count card")
		s.tutorial.collectedEggCount=15
		expect((route()),"TipVacuum","Claim your Egg Vacuum!","12 more eggs: the vacuum tip")
		s.coins=1700
		local tipCard,ready=route()
		assert(ready.rebirth.eligible==true,"Rebirth 0 eligible: "..tostring(ready.rebirth.reason))
		expect(tipCard,"TipRebirth","Tap Rebirth! Coins & Upgrades reset, but you keep ×1.5 Coins forever!","Rebirth 0 tip at 1,700")
		return "Two chickens for 0 + 20; complete on the recruit; favoured pulls; the vacuum and Rebirth 0 tips follow"
	end)

	-- October 27 (WS5, docs/team/POST_TUTORIAL_FLOW_20261027.md): the goal ladder.
	local function onScreen(state,why,skip)
		local card=Guide.Resolve(state,nil,skip)
		assert(card and card.id~="Complete",why..": "..(if card then card.id else "nothing"))
		assert(Guide.CardIds[card.id],why..": "..card.id.." missing from CardIds")
		return card
	end
	local function quote(state,fields)
		state.rebirth={rank=0,nextRank=1,cost=50000,eligible=false,
			find={species="Ironbeak",name="Ironbeak Chicken",rarity="Uncommon",found=false}}
		for key,value in fields or {} do state.rebirth[key]=value end
	end

	test("Goal ladder: a card is always on screen from completion until Rebirth 1",timedCamp(function()
		local state=afterGuide()
		state.tutorial.eggsAtComplete,state.tutorial.collectedEggCount=3,3
		onScreen(state,"Completion: the vacuum count")
		state.tutorial.collectedEggCount=15
		onScreen(state,"The vacuum claim")
		state.tools.eggVacuum,state.upgradeTree.nodes.EggVacuum=true,{status="Owned"}
		onScreen(state,"Vacuum use")
		state.tutorial.vacuumEggCount=10
		onScreen(state,"Vacuum sell")
		state.tutorial.vacuumSold=true
		-- Gap A (live: 26% of these left): two chickens, the Army count card.
		local roll=onScreen(state,"Two chickens, no offer")
		tipIs(roll,"TipArmyRoll","Roll a chicken for your Army! (2/3)",1,3,"Attack")
		assert(roll.target=="RollStation","Roll card points at the lever")
		state.offer={species="Duck",price=150};state.coins=110
		local short=onScreen(state,"Offer short")
		tipIs(short,"RecoverCollect","Collect eggs worth 40 more Coins",1,3,"Attack")
		state.eggs.carriedValue=50
		tipIs(onScreen(state,"Bag covers it"),"RecoverSell","Sell your eggs on the green pad!",1,3,"Attack")
		state.eggs.carriedValue,state.coins=0,150
		tipIs(onScreen(state,"Affordable"),"TipArmyBuy","Buy the chicken!",1,3,"Attack")
		state.offer,state.coins=nil,0
		state.pets={{id="a"},{id="b"},{id="c"}};state.selectedCount=3
		local ready=onScreen(state,"Three chickens, not settled")
		tipIs(ready,"TipArmyReady","Vacuum eggs to get ready for battle! (10/20)",2,3,"Attack")
		assert(ready.target=="VacuumTool" and ready.outside=="Equip your Egg Vacuum!","Ready card lines")
		state.tutorial.vacuumEggCount=12
		tipIs(onScreen(state,"Twelve"),"TipArmyReady","Vacuum eggs to get ready for battle! (12/20)",2,3,"Attack")
		state.tutorial.vacuumEggCount=20
		local attack=onScreen(state,"Settled")
		tipIs(attack,"TipAttack","Send your Army to attack Cluck Camp!",3,3,"Attack")
		assert(attack.target=="Camp1","Attack points at Cluck Camp")
		state.firstWins,state.campsWon={true},1
		onScreen(state,"Cluck Camp won: the Camp slot")
		state.coins=900
		local goal=onScreen(state,"Next camp timed out",{TipNextCamp2=true})
		expect(goal,"GoalRebirth0","Reach 1,700 Coins for Rebirth 0! (900/1,700)")
		assert(goal.tag=="GOAL" and goal.total==nil and goal.target==nil and goal.chain=="Goal","GOAL card shape")
		state.coins,state.rebirth=1700,{intro=true,rank=0,cost=1700,eligible=true}
		tipIs(onScreen(state,"Rebirth 0 affordable",{TipNextCamp2=true}),"TipRebirth",nil,2,3,"Rebirth")
		-- Rebirth 0 (KeepTree: the vacuum and Flock Size I stay).
		state.introRebirth,state.coins,state.gems,state.gemsEarned="done",0,30,30
		quote(state)
		tipIs(onScreen(state,"Gems unspent",{TipNextCamp2=true}),"TipGems",nil,3,3,"Rebirth")
		state.gems=0
		state.upgradeTree.nodes.ArmySize1={status="Unaffordable",price=300} -- 0 Coins
		local find=onScreen(state,"Gems spent",{TipNextCamp2=true})
		expect(find,"GoalFind","Find an Ironbeak Chicken for Rebirth 1!")
		assert(find.tag=="GOAL" and find.target=="RollStation","The find points at the lever")
		-- A tree reset (Rebirth 1+, or KeepTree off) took the vacuum and Flock Size I.
		state.tools.eggVacuum=false;state.upgradeTree.nodes.EggVacuum={status="Available",price=0}
		state.upgradeTree.families.Flock=nil;state.flock={size=3};state.upgradeTree.nodes.Flock1={status="Unaffordable",price=10}
		local rebuild=onScreen(state,"Rebuild",{TipNextCamp2=true})
		tipIs(rebuild,"TipRebuildVacuum","Claim your Egg Vacuum again!",1,2,"Rebuild")
		assert(rebuild.node=="EggVacuum" and rebuild.outside=="Open Upgrades for an Egg Vacuum!"
			and rebuild.wrongTab=="Open the Tools category!","Rebuild vacuum lines")
		state.tools.eggVacuum=true;state.upgradeTree.nodes.EggVacuum={status="Owned"}
		tipIs(onScreen(state,"Flock short",{TipNextCamp2=true}),"RecoverCollect","Collect eggs worth 10 more Coins",2,2,"Rebuild")
		state.coins=12;state.upgradeTree.nodes.Flock1={status="Available",price=10}
		local flock=onScreen(state,"Flock affordable",{TipNextCamp2=true})
		tipIs(flock,"TipRebuildFlock","Expand your plot again!",2,2,"Rebuild")
		assert(flock.node=="Flock1" and flock.outside=="Open Upgrades!" and flock.wrongTab=="Open the Main category!","Rebuild flock lines")
		state.upgradeTree.families.Flock=1;state.flock={size=4};state.upgradeTree.nodes.Flock1={status="Owned"}
		state.coins=2
		-- Grow: the starter upgrades as each becomes affordable, in Config.Guide.GrowNodes order.
		state.upgradeTree.nodes.EggSpeed1={status="Unaffordable",price=400}
		state.upgradeTree.nodes.EggValue1={status="Unaffordable",price=600}
		state.upgradeTree.nodes.ArmySize1={status="Unaffordable",price=300}
		expect(onScreen(state,"Nothing affordable: the find",{TipNextCamp2=true}),"GoalFind",nil,"Nothing affordable")
		state.coins=450
		state.upgradeTree.nodes.EggSpeed1.status,state.upgradeTree.nodes.ArmySize1.status="Available","Available"
		local grow=onScreen(state,"Grow",{TipNextCamp2=true})
		tipIs(grow,"TipGrowEggSpeed1","Buy Egg Speed I!",1,3,"Grow")
		assert(grow.target=="Upgrades" and grow.node=="EggSpeed1" and grow.outside=="Open Upgrades!"
			and grow.wrongTab=="Open the Main category!","Grow lines")
		state.upgradeTree.nodes.EggSpeed1={status="Owned"}
		tipIs(onScreen(state,"Grow skips owned",{TipNextCamp2=true}),"TipGrowArmySize1","Buy Army Size I!",3,3,"Grow")
		state.upgradeTree.nodes.ArmySize1={status="Owned"}
		expect(onScreen(state,"Egg Value I unaffordable",{TipNextCamp2=true}),"GoalFind",nil,"Egg Value I unaffordable")
		state.rebirth.find.found=true;state.coins=6000
		expect(onScreen(state,"Find owned",{TipNextCamp2=true}),"GoalRebirthCoins","Reach 50,000 Coins for Rebirth 1! (12%)")
		state.coins,state.rebirth.eligible=50000,true
		state.upgradeTree.nodes.EggValue1={status="Owned"}
		expect(onScreen(state,"Rebirth 1 ready",{TipNextCamp2=true}),"GoalRebirthReady","Rebirth 1 is ready! Open Rebirth!")
		-- Rebirth 1: the ladder ends (the HUD's Rebirth progress takes over).
		state.rebirth={rank=1,nextRank=2,cost=1000000,eligible=false}
		state.coins=0
		expect(Guide.Resolve(state,nil,{TipNextCamp2=true}),"Complete",nil,"Nothing after Rebirth 1")
		return "Vacuum, Army 2/3, buy, settle 12/20, attack, GOAL, Rebirth 0, Gems, find, Rebuild, Grow, Coins, ready"
	end))

	test("Goal ladder: priority, opt-outs and the CardIds set",timedCamp(function()
		-- The Vacuum chain comes before the Attack chain now (October 24's settled 60 eggs by hand).
		local state=afterGuide()
		state.tutorial.collectedEggCount,state.tutorial.eggsAtComplete=60,3
		state.pets={{id="a"},{id="b"},{id="c"}};state.selectedCount=3
		expect(Guide.Resolve(state),"TipVacuum",nil,"Vacuum before the Camp")
		withGuide({ArmyTips=false},function()
			expect(Guide.Resolve(state),"TipAttack",nil,"1.26 order: settled Camp before the vacuum")
		end)
		-- Goal hints off (Settings): the October 24 Camp card alone and no GOAL cards.
		local hidden=afterGuide()
		hidden.tools.eggVacuum,hidden.tutorial.vacuumEggCount,hidden.tutorial.vacuumSold=true,10,true
		hidden.tutorial.goalsHidden=true
		expect(Guide.Resolve(hidden),"Complete",nil,"Goal hints off")
		hidden.pets={{id="a"},{id="b"},{id="c"}};hidden.selectedCount=3;hidden.tutorial.vacuumEggCount=20
		tipIs(Guide.Resolve(hidden),"TipAttack","Send your Army to attack Cluck Camp!",1,1,"Attack","Old Camp card")
		-- A save without the empty start (introRebirth nil) gets none of the extras.
		local older=afterGuide()
		older.tools.eggVacuum,older.tutorial.vacuumEggCount,older.tutorial.vacuumSold=true,10,true
		older.introRebirth=nil
		expect(Guide.Resolve(older),"Complete",nil,"Older saves")
		-- Config switches, one at a time.
		local after=afterGuide()
		after.tools.eggVacuum,after.tutorial.vacuumEggCount,after.tutorial.vacuumSold=true,20,true
		after.firstWins,after.campsWon,after.pets,after.selectedCount={true},1,{{id="a"},{id="b"},{id="c"}},3
		expect(Guide.Resolve(after,nil,{TipNextCamp2=true}),"GoalRebirth0")
		withGuide({Goals=false},function() expect(Guide.Resolve(after,nil,{TipNextCamp2=true}),"Complete",nil,"Goals off") end)
		withGuide({GoalUntilRank=0},function() expect(Guide.Resolve(after,nil,{TipNextCamp2=true}),"Complete",nil,"GoalUntilRank 0") end)
		for _,id in {"TipArmyRoll","TipArmyBuy","TipArmyReady","TipAttack","TipRebuildVacuum","TipRebuildFlock","TipGrowEggSpeed1",
			"TipGrowEggValue1","TipGrowArmySize1","GoalRebirth0","GoalFind","GoalRebirthCoins","GoalRebirthReady","TipNextCamp2",
			"TipVacuumEggs","TipGems","Complete","RecoverCollect"} do
			assert(Guide.CardIds[id],id.." missing")
		end
		local order={}
		for _,chain in Guide.Tips do table.insert(order,chain.id) end
		assert(table.concat(order,",")=="Rebirth,Vacuum,Rebuild,Attack,NextCamp,Grow,Goal",table.concat(order,","))
		local grow=table.concat(Config.Guide.GrowNodes,",")
		assert(grow=="EggSpeed1,EggValue1,ArmySize1",grow)
		return "Vacuum > Attack; hints off; older saves; switches"
	end))

	test("Camp slot: WS1's CampGuide card keeps its tag, power bar and ids",function()
		local module=Shared:FindFirstChild("CampGuide")
		if not module then return "CampGuide not in this build (the timed card is the fallback)" end
		local CampGuide=require(module)
		local ladder=(Config :: any).CampLadder
		local saved=ladder.ReadinessTip
		ladder.ReadinessTip=true
		local ok,result=pcall(function()
			local state=afterGuide()
			state.tools.eggVacuum,state.tutorial.vacuumEggCount,state.tutorial.vacuumSold=true,20,true
			state.firstWins,state.campsWon,state.pets,state.selectedCount={true},1,{{id="a"},{id="b"},{id="c"}},3
			state.power=20
			local card=onScreen(state,"Camp slot")
			assert(card.chain=="NextCamp" and string.sub(card.tag,1,5)=="NEXT:","Provider tag kept: "..tostring(card.tag))
			assert(type(card.progress)=="table" and tonumber(card.progress.goal),"Power bar")
			for _,id in CampGuide.Ids do assert(Guide.CardIds[id],id.." missing from CardIds") end
			assert(Guide.CloseFightRatio==CampGuide.EvenRatio and Guide.ShouldWinRatio==CampGuide.ReadyRatio,"Bands follow CampGuide")
			return card.id.." · "..card.tag.." · "..tostring(card.progress.label)
		end)
		ladder.ReadinessTip=saved
		if not ok then error(result,0) end
		return result
	end)

	test("HUD reveal: each piece's moment, everything at the cap, with the switch off or for older saves",function()
		local state=afterGuide()
		state.discovered={Duck=true};state.passiveEarned,state.battleEarned=0,0
		local facts=Guide.Facts(state)
		local r=Guide.HudReveal(state,facts,0,60)
		assert(r.Army and r.Rebirth and r.Settings,"At completion")
		for _,key in {"Playtime","Index","FreeGift","Shop","GoldRush","Boosts","FriendBoost"} do assert(not r[key],key.." at completion") end
		state.tutorial.vacuumSold=true
		assert(Guide.HudReveal(state,facts,30,90).Playtime,"Playtime after the vacuum chain")
		state.tutorial.vacuumSold=nil
		assert(Guide.HudReveal(state,facts,150,200).Playtime,"Playtime at 150 s")
		state.discovered.Bee=true
		assert(Guide.HudReveal(state,facts,10,70).Index,"Index with a second species")
		state.discovered.Bee=nil
		assert(Guide.HudReveal(state,facts,10,300).FreeGift,"Free Gift at 5 minutes of the visit")
		state.passiveEarned=Config.Guide.ShopRevealEarned
		local shop=Guide.HudReveal(state,facts,10,70)
		assert(shop.Shop and not shop.GoldRush,"Shop at 2,000 Coins earned")
		state.passiveEarned=0
		local late=Guide.HudReveal(state,facts,360,400)
		assert(late.Shop and late.GoldRush and late.Boosts and late.FriendBoost,"Six minutes after")
		state.introRebirth="done"
		local intro=Guide.HudReveal(state,facts,10,70)
		assert(intro.Shop and intro.GoldRush and intro.Boosts and intro.FreeGift,"After Rebirth 0")
		state.introRebirth="pending"
		state.firstWins={true}
		assert(Guide.HudReveal(state,Guide.Facts(state),10,70).FriendBoost and Guide.HudReveal(state,Guide.Facts(state),10,70).Index,"Cluck Camp won")
		state.firstWins=nil
		local function every(reveal) for _,key in Guide.HudRevealKeys do if not reveal[key] then return false end end return true end
		assert(every(Guide.HudReveal(state,facts,Config.Guide.RevealAllSeconds,500)),"All at the cap")
		withGuide({HudReveal=false},function() assert(every(Guide.HudReveal(state,facts,0,0)),"Switch off") end)
		state.introRebirth=nil
		assert(every(Guide.HudReveal(state,facts,0,0)),"Older saves")
		return "Playtime, Index, Free Gift, Shop, Gold Rush, boosts, Friend Boost; cap"
	end)

	local passed=0
	for _,result in results do if result.passed then passed+=1 end end
	print(("[CommanderGuideChecks] %d/%d passed"):format(passed,#results))
	for _,result in results do
		print((if result.passed then "  PASS " else "  FAIL ")..result.name.." — "..result.detail)
	end
	return results
end

return Checks
