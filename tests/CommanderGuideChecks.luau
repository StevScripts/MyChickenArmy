-- October 20 Commander guide and Next goals (S14; docs/team/COMMANDER_TUTORIAL.md).
-- October 21: the short core (5 eggs, sell, Flock Size I, FREE roll) and the tips.
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
local Checks={}

local function expect(current,id,text,why)
	assert(current,(why or id)..": no step")
	assert(current.id==id,(why or id)..": got "..tostring(current.id).." ("..tostring(current.text)..")")
	if text then assert(current.text==text,(why or id)..": text '"..tostring(current.text).."'") end
end

-- The starter opening right after the intro: three Ducks, 2,400 Coins, nothing done.
local function opening()
	return {saveStatus="ready",armyState="Home",coins=2400,capacity=3,selectedCount=3,flock={size=3},
		tutorial={starterArmy=true,guideStarted=true,collectedEggCount=0},pets={{id="a"},{id="b"},{id="c"}},
		starterCashReserve=1200,starterArmyReserve=1200,starterRecruitPrice=0,eggs={carriedValue=0},nextSlot={capacity=4,price=1200,tier=1},
		tools={eggVacuum=false,chickenFeed=false,vacuum={count=0,capacity=10}},
		upgradeTree={families={},nodes={Flock1={status="Available",price=300},ArmySize1={status="Available",price=1200},
			EggVacuum={status="Available",price=0}}}}
end

-- Just after Cluck Camp: guide complete, Fort Roost next at 63 vs 107 power.
local function afterGuide()
	local state=opening()
	state.tutorial={starterArmy=true,guideStarted=true,guideCompleted=true,bought=true,soldEggs=true,
		rolled=true,collectedEggCount=20,wonCamp=true}
	state.pets={{id="a"},{id="b"},{id="c"},{id="d"}}
	state.capacity,state.selectedCount,state.coins,state.power,state.flock=4,4,800,63,{size=4}
	state.starterCashReserve,state.starterArmyReserve=0,0
	state.campsWon,state.routeCamps=1,{true}
	state.targets={{id="camp:1",name="Cluck Camp",power=40,owned=true},{id="camp:2",name="Fort Roost",power=107}}
	state.tools={eggVacuum=false,chickenFeed=false,vacuum={count=0,capacity=40}}
	state.rebirth={enabled=true,eligible=false,nextRank=1,cost=50000}
	state.upgradeTree={families={Flock=1,ArmySize=1},nodes={EggVacuum={status="Available",price=500},
		ChickenFeed={status="Unaffordable",price=1000},ArmySize2={status="Unaffordable",price=6000},
		VacuumCapacity1={status="Locked",price=500}}}
	return state
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,detail=pcall(fn)
		table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
	end

	test("The opening teaches clicking 5 eggs in the player's own input",function()
		local state=opening()
		local first=Guide.Resolve(state)
		expect(first,"Collect","Click eggs to collect them (0/5)")
		assert(first.tag=="TUTORIAL" and first.index==1 and first.total==5,"Tag "..tostring(first.tag))
		expect(Guide.Resolve(state,"Touch"),"Collect","Tap eggs to collect them (0/5)")
		expect(Guide.Resolve(state,"Gamepad"),"Collect","Press R2 to collect eggs (0/5)")
		assert(Guide.EggGoal==5 and Guide.CollectedEggCount({collectedEggCount=37})==5,"Saved counts clamp to 5")
		state.tutorial.collectedEggCount=5
		expect(Guide.Resolve(state),"RecoverCollect","Collect eggs in your yard","Nothing to sell yet")
		state.eggs.carriedValue=80
		local sell=Guide.Resolve(state)
		expect(sell,"Sell","Step on the green sell pad")
		assert(sell.index==2,"Sell is 2/5")
		return "Click, Tap and R2 wording; 37 clamps to 5"
	end)

	test("Core: Flock Size I, a FREE roll; tips: FREE vacuum, Army Size I, Cluck Camp",function()
		local state=opening()
		state.tutorial.collectedEggCount,state.tutorial.soldEggs=5,true
		local flock=Guide.Resolve(state)
		expect(flock,"Flock","Buy Flock Size I in Upgrades")
		assert(flock.target=="Upgrades" and flock.node=="Flock1" and flock.index==3,"Flock hex "..tostring(flock.node))
		state.flock.size=4
		expect(Guide.Resolve(state),"Roll","Pull the lever for a FREE chicken!")
		state.tutorial.rolled,state.offer=true,{price=0}
		local recruit=Guide.Resolve(state)
		expect(recruit,"Recruit","Grab your FREE chicken!")
		assert(recruit.index==5 and recruit.total==5,"Recruit is 5/5")
		state.tutorial.bought,state.offer=true,nil
		state.pets={{id="a"},{id="b"},{id="c"},{id="d"}}
		assert(Guide.Facts(state).Core,"Core done")
		local vacuum=Guide.Resolve(state)
		expect(vacuum,"Vacuum","Claim your FREE Egg Vacuum in Upgrades → Tools")
		assert(vacuum.tag=="TIP" and vacuum.index==1 and vacuum.total==6 and vacuum.node=="EggVacuum","Vacuum tip")
		state.tools.eggVacuum=true
		local use=Guide.Resolve(state)
		expect(use,"VacuumUse","Equip your Egg Vacuum and walk near eggs (0/3)")
		assert(use.target=="VacuumTool","Hotbar slot")
		state.tutorial.vacuumEggCount=3
		local expand=Guide.Resolve(state)
		expect(expand,"Expand","Buy Army Size I in Upgrades")
		assert(expand.node=="ArmySize1" and expand.index==3,"Army Size hex "..tostring(expand.node))
		state.capacity=4
		expect(Guide.Resolve(state),"Select","My Army → Select Best")
		state.selectedCount=4
		local deploy=Guide.Resolve(state)
		expect(deploy,"Deploy","Cluck Camp → Send Army")
		assert(deploy.index==5,"Deploy is TIP 5/6")
		local order=table.concat(Guide.FunnelSteps,",")
		assert(order=="Started,Collect,Sell,Flock,Roll,Recruit,CoreDone,Vacuum,VacuumUse,Expand,Select,Deploy,Win",order)
		return "Flock before the roll, tips after the core"
	end)

	test("Flock Size I never spends the Coins held for Army Size I",function()
		local state=opening()
		state.tutorial.collectedEggCount,state.tutorial.soldEggs=5,true
		state.coins,state.starterCashReserve=1400,1200
		state.upgradeTree.nodes.Flock1={status="Unaffordable",price=300}
		expect(Guide.Resolve(state),"RecoverCollect","Collect eggs worth 100 more Coins")
		state.eggs.carriedValue=150
		expect(Guide.Resolve(state),"RecoverSell","Step on the green sell pad")
		return "Short by 100 Coins"
	end)

	test("An army walking home shows Return, not the fight",function()
		local state=opening()
		state.tutorial.collectedEggCount,state.tutorial.soldEggs=5,true
		state.outgoing,state.armyState="battle1","Returning"
		expect(Guide.Resolve(state),"Return","Wait for your army to return")
		state.armyState="Marching"
		expect(Guide.Resolve(state),"Battle","Your army is fighting")
		local after=afterGuide()
		after.outgoing,after.armyState="battle2","Returning"
		expect(Guide.NextGoal(after),"Goal:Return","Collect eggs while your army returns")
		after.incoming=true
		assert(Guide.NextGoal(after)==nil,"Defending shows no goal")
		return "Returning beats outgoing"
	end)

	test("After the guide: buy the Egg Vacuum, equip it, then Chicken Feed",function()
		local state=afterGuide()
		local vacuum=Guide.NextGoal(state)
		expect(vacuum,"Goal:Vacuum","Buy the Egg Vacuum in Upgrades > Tools")
		assert(vacuum.goal and vacuum.target=="Upgrades" and vacuum.node=="EggVacuum","Vacuum hex")
		state.tools.eggVacuum=true
		local equip=Guide.NextGoal(state)
		expect(equip,"Goal:EquipVacuum","Equip your Egg Vacuum, then walk near your eggs")
		assert(equip.target=="VacuumTool","Dock slot target")
		state.tutorial.vacuumUsed=true
		state.upgradeTree.nodes.ChickenFeed.status="Available"
		expect(Guide.NextGoal(state),"Goal:Feed","Buy Chicken Feed in Upgrades > Tools")
		state.tools.vacuum={count=40,capacity=40}
		state.upgradeTree.nodes.VacuumCapacity1.status="Available"
		state.upgradeTree.nodes.ChickenFeed.status="Unaffordable"
		expect(Guide.NextGoal(state),"Goal:Capacity","Vacuum full? Buy Vacuum Capacity in Upgrades > Tools")
		return "Vacuum, equip, Feed, capacity"
	end)

	test("A Very tough Fort Roost names the gap and the cheapest step; never Fuse",function()
		local state=afterGuide()
		state.tools.eggVacuum,state.tutorial.vacuumUsed=true,true
		local texts={}
		local function goal()
			local current=Guide.NextGoal(state)
			table.insert(texts,current and current.text or "")
			return current
		end
		expect(goal(),"Goal:Power:camp:2:Save","Army 63 / Fort Roost 107: sell eggs for Chicken Feed (Upgrades > Tools)")
		state.tools.chickenFeed=true
		state.pets={{id="a",selected=true,canUpgrade=true,upgradePrice=450},{id="b"},{id="c"},{id="d"}}
		local feed=goal()
		expect(feed,"Goal:Power:camp:2:Feed","Army 63 / Fort Roost 107: feed your Army chickens")
		assert(feed.target=="FeedTool","Feed slot target")
		state.coins=300
		state.offers={{price=250,improvesArmy=true}}
		expect(goal(),"Goal:Power:camp:2:Recruit","Army 63 / Fort Roost 107: buy the chicken on your podium")
		state.offers={}
		state.coins=7000
		state.pets[1].upgradePrice=9000
		state.pets[5]={id="e"}
		state.upgradeTree.nodes.ArmySize2.status="Available"
		local slots=goal()
		expect(slots,"Goal:Power:camp:2:Slots","Army 63 / Fort Roost 107: buy Army Size II in Upgrades")
		assert(slots.node=="ArmySize2","Army Size II hex")
		state.upgradeTree.nodes.ArmySize2.status="Unaffordable"
		expect(goal(),"Goal:Power:camp:2:Earn","Army 63 / Fort Roost 107: sell eggs, then feed your Army chickens")
		state.power=150
		expect(goal(),"Goal:Attack:camp:2","Attack Fort Roost")
		for _,text in texts do
			assert(not string.find(text,"Fuse") and not string.find(text,"%$"),"Old wording: "..text)
		end
		return #texts.." goals, none mention Fuse"
	end)

	test("Rebirth: only once ready before the King, progress after it",function()
		local state=afterGuide()
		state.coins,state.power=30000,300
		expect(Guide.NextGoal(state),"Goal:Vacuum",nil,"30K of 50K stays quiet before the King")
		state.rebirth.eligible=true
		local ready=Guide.NextGoal(state)
		expect(ready,"Goal:Rebirth","Rebirth is ready! Open Rebirth on the right")
		assert(ready.target=="Rebirth","HUD Rebirth button")
		state.rebirth.eligible=false
		state.tools.eggVacuum,state.tutorial.vacuumUsed=true,true
		state.kingCleared,state.operations=true,{tier=1,wins={}}
		expect(Guide.NextGoal(state),"Goal:Operations","Attack a loyalist site on the island")
		state.operations.wins={["1:2"]=true}
		expect(Guide.NextGoal(state),"Goal:Rebirth:1","Rebirth 1: 30K / 50K Coins")
		state.tutorial.goalsHidden=true
		assert(Guide.NextGoal(state)==nil,"Settings hid the goals")
		state.tutorial.goalsHidden,state.tutorial.guideSkipped=false,true
		assert(Guide.NextGoal(state)==nil and Guide.NextGoal(state,true)~=nil,"Skipped guide keeps the world marker only")
		return "Ready, Missions, then progress"
	end)

	test("The Egg Vacuum is a 500-Coin Tools node that a session buys",function()
		local node=Tree.Nodes.EggVacuum
		assert(node and node.kind=="upgrade" and node.family=="EggVacuum" and node.prerequisite=="ToolsBack","Node shape")
		assert(Tree.Price("EggVacuum",1,0)==500 and Tree.Nodes.VacuumCapacity1.prerequisite=="EggVacuum","Price and chain")
		assert(Tree.DefaultEffects.eggVacuum==0 and Tree.Effects({EggVacuum=1},{}).eggVacuum==1,"Effect key")
		local s=Session.new(-9401,"Vacuum buyer",1)
		s.loaded=true
		s.tutorial.bought,s.tutorial.guideCompleted=true,true
		assert(not Tools.Owns(s,"EggVacuum"),"Owned before buying")
		local service=Upgrades.new(nil,nil)
		assert(service:Snapshot(s).nodes.EggVacuum.status=="Available","Quote")
		local ok,message=service:BuyNode(s,"EggVacuum",500)
		assert(ok,message)
		assert(Tools.Owns(s,"EggVacuum") and s.coins==1900 and s.upgradeTree.EggVacuum==1,"Bought")
		assert(string.find(message,"Egg Vacuum"),message)
		s.upgradeTree={}
		s:RefreshEffects()
		assert(not Tools.Owns(s,"EggVacuum"),"Rebirth reset kept the vacuum")
		return message
	end)

	test("The Egg Vacuum is FREE only while the guide runs",function()
		local s=Session.new(-9405,"Free vacuum",1)
		s.loaded=true
		local service=Upgrades.new(nil,nil)
		local quote=service:Snapshot(s).nodes.EggVacuum
		assert(quote.status=="Available" and quote.price==0,"Guide quote "..tostring(quote.price))
		assert(not (service:BuyNode(s,"EggVacuum",500)),"Old price accepted")
		local ok,message=service:BuyNode(s,"EggVacuum",0)
		assert(ok and s.coins==2400 and Tools.Owns(s,"EggVacuum"),message)
		s.upgradeTree={};s:RefreshEffects()
		s.tutorial.guideCompleted=true
		assert(service:Snapshot(s).nodes.EggVacuum.price==500,"After the guide")
		return "0 during, 500 after"
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
		return "2 saved, 99 clamps"
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

	test("A real starter session walks Flock Size I and Army Size I with its reserve",function()
		local s=Session.new(-9403,"Starter route",1)
		-- DataService marks a loaded profile; the guide stays hidden while it is "loading".
		s.loaded,s.saveStatus=true,"saved"
		local service=Upgrades.new(nil,nil)
		local function route()
			local state=s:Snapshot(0)
			state.upgradeTree=service:Snapshot(s)
			state.tools={eggVacuum=Tools.Owns(s,"EggVacuum"),chickenFeed=false}
			state.tutorial.guideStarted=true
			return Guide.Resolve(state),state
		end
		expect((route()),"Collect","Click eggs to collect them (0/5)")
		s.tutorial.collectedEggCount,s.tutorial.soldEggs=5,true
		local flock,state=route()
		expect(flock,"Flock","Buy Flock Size I in Upgrades")
		assert(state.starterCashReserve==1200 and state.upgradeTree.nodes.Flock1.status=="Available","Reserve and quote")
		local ok,message=service:BuyNode(s,"Flock1",300)
		assert(ok,message)
		expect((route()),"Roll","Pull the lever for a FREE chicken!")
		s.tutorial.rolled=true
		s:AddPet("Duck",1)
		s.tutorial.bought=true
		expect((route()),"Vacuum","Claim your FREE Egg Vacuum in Upgrades → Tools")
		ok,message=service:BuyNode(s,"EggVacuum",0)
		assert(ok,message)
		s.tutorial.vacuumEggCount=3
		expect((route()),"Expand","Buy Army Size I in Upgrades")
		ok,message=s:CanSpendCash(1000)
		assert(not ok and message=="Keep 1,200 Coins for Army Size I in Upgrades.",message)
		ok,message=service:BuyNode(s,"ArmySize1",1200)
		assert(ok,message)
		expect((route()),"Deploy","Cluck Camp → Send Army")
		assert(s.coins==900 and s:FlockSize()==4 and s:Capacity()==4,"Coins "..s.coins)
		local fresh=Session.new(-9404,"Before recruit",1)
		ok,message=fresh:CanSpendCash(1300)
		assert(not ok and message=="Keep 1,200 Coins for Army Size I in Upgrades.",message)
		return "900 Coins left after Flock and Army Size"
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
