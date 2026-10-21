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

-- A player who finished the tutorial earlier (guide complete, nothing pending).
local function afterGuide()
	local state=opening()
	state.tutorial={starterArmy=true,guideStarted=true,guideCompleted=true,coreDone=true,bought=true,soldEggs=true,
		rolled=true,collectedEggCount=3,vacuumEggCount=20,vacuumSold=true}
	state.pets={{id="a"},{id="b"},{id="c"},{id="d"}}
	state.tools={eggVacuum=true,chickenFeed=false,vacuum={count=0,capacity=40}}
	return state
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,detail=pcall(fn)
		table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
	end

	test("The opening teaches clicking 3 eggs in the player's own input",function()
		local state=opening()
		local first=Guide.Resolve(state)
		expect(first,"Collect","Click your eggs to collect them! (0/3)")
		assert(first.tag=="TUTORIAL" and first.index==1 and first.total==7,"Tag "..tostring(first.tag))
		expect(Guide.Resolve(state,"Touch"),"Collect","Tap your eggs to collect them! (0/3)")
		expect(Guide.Resolve(state,"Gamepad"),"Collect","Press R2 to collect your eggs! (0/3)")
		assert(Guide.EggGoal==3 and Guide.CollectedEggCount({collectedEggCount=37})==3,"Saved counts clamp to 3")
		state.tutorial.collectedEggCount=3
		expect(Guide.Resolve(state),"RecoverCollect","Collect eggs in your yard","Nothing to sell yet")
		state.eggs.carriedValue=80
		local sell=Guide.Resolve(state)
		expect(sell,"Sell","Sell your eggs on the green pad!")
		assert(sell.index==2,"Sell is 2/7")
		return "Click, Tap and R2 wording; 37 clamps to 3"
	end)

	test("Seven lessons: eggs, sell, roll, chicken, vacuum claim, vacuum 20, sell; then complete",function()
		local state=opening()
		state.tutorial.collectedEggCount,state.tutorial.soldEggs=3,true
		local roll=Guide.Resolve(state)
		expect(roll,"Roll","Pull the lever for a chicken!")
		assert(roll.index==3 and roll.total==7,"Roll is 3/7")
		state.tutorial.rolled,state.offer=true,{price=0}
		local recruit=Guide.Resolve(state)
		expect(recruit,"Recruit","Grab your chicken!")
		assert(recruit.index==4,"Recruit is 4/7")
		state.tutorial.bought,state.offer=true,nil
		state.pets={{id="a"},{id="b"},{id="c"},{id="d"}}
		local vacuum=Guide.Resolve(state)
		expect(vacuum,"Vacuum","Claim your Egg Vacuum!")
		assert(vacuum.index==5 and vacuum.node=="EggVacuum" and vacuum.outside=="Open Upgrades for an Egg Vacuum!"
			and vacuum.wrongTab=="Open the Tools category!","Vacuum lesson")
		state.tools.eggVacuum=true
		local use=Guide.Resolve(state)
		expect(use,"VacuumUse","Walk near eggs to vacuum them up! (0/20)")
		assert(use.target=="VacuumTool" and use.outside=="Equip your Egg Vacuum!" and use.index==6,"Equip words")
		state.tools.vacuum={count=40,capacity=40}
		local full=Guide.Resolve(state)
		expect(full,"VacuumUse","Vacuum full! Sell your eggs on the green pad!")
		assert(full.target=="EggDeposit","Full vacuum goes to the pad")
		state.tools.vacuum={count=20,capacity=40}
		state.tutorial.vacuumEggCount=20
		local sell=Guide.Resolve(state)
		expect(sell,"VacuumSell","Sell your vacuumed eggs on the green pad!")
		assert(sell.target=="EggDeposit" and sell.index==7 and sell.total==7,"Sell is 7/7")
		assert(not Guide.Facts(state).Core,"Not done before the sale")
		state.tutorial.vacuumSold=true
		assert(Guide.Facts(state).Core,"Done after the sale")
		expect(Guide.Resolve(state),"Complete",Guide.CompleteText)
		local order=table.concat(Guide.Core,",")
		assert(order=="Collect,Sell,Roll,Recruit,Vacuum,VacuumUse,VacuumSell",order)
		return "No Flock or Army lessons"
	end)

	test("An army walking home shows Return, not the fight",function()
		local state=opening()
		state.tutorial.collectedEggCount,state.tutorial.soldEggs=3,true
		state.outgoing,state.armyState="battle1","Returning"
		expect(Guide.Resolve(state),"Return","Wait for your army to return")
		state.armyState="Marching"
		expect(Guide.Resolve(state),"Battle","Your army is fighting")
		return "Returning beats outgoing"
	end)

	test("After the tutorial there are no more instructions",function()
		local state=afterGuide()
		expect(Guide.Resolve(state),"Complete",Guide.CompleteText,"Only the completion card")
		assert(Guide.NextGoal==nil,"Next goals were removed")
		state.outgoing,state.armyState="battle2","Returning"
		expect(Guide.Resolve(state),"Complete",nil,"No battle or return lines after the tutorial")
		local skipped=opening()
		skipped.tutorial.guideSkipped=true
		assert(Guide.Resolve(skipped)==nil,"A hidden guide shows nothing")
		return "Complete card, then nothing"
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

	test("A real starter session walks the seven lessons and the guide completes",function()
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
		expect((route()),"Collect","Click your eggs to collect them! (0/3)")
		s.tutorial.collectedEggCount,s.tutorial.soldEggs=3,true
		expect((route()),"Roll","Pull the lever for a chicken!")
		s.tutorial.rolled=true
		s:AddPet("Duck",1)
		s.tutorial.bought=true
		local _,state=route()
		assert(state.upgradeTree.nodes.EggVacuum.price==0,"The vacuum costs 0 during the guide")
		expect((route()),"Vacuum","Claim your Egg Vacuum!")
		local ok,message=service:BuyNode(s,"EggVacuum",0)
		assert(ok,message)
		s.tutorial.vacuumEggCount=20
		expect((route()),"VacuumSell","Sell your vacuumed eggs on the green pad!")
		s.tutorial.vacuumSold=true
		local done,final=route()
		expect(done,"Complete",Guide.CompleteText)
		assert(Guide.Facts(final).Core and s.coins==2400,"Nothing was spent: "..s.coins)
		-- TutorialService completes the guide with the lessons (no camp win needed).
		local service2=Tutorial.new(function() end)
		service2:Begin(nil,s)
		service2:Observe(s,final)
		assert(s.tutorial.guideCompleted and s.tutorial.coreDone,"Guide completed")
		return "2,400 Coins kept; complete after the vacuum sale"
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
