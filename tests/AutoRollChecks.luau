-- October 20 Auto Roll and Gold rolls (S12, docs/team/AUTO_ROLL.md). Isolated
-- sessions; never opens saved player profiles. Run in a Run-mode playtest:
-- require(game.ServerStorage.PetRollTests.AutoRollChecks).Run()
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Rules=require(Shared.Rules)
local AutoRollRules=require(Shared.AutoRollRules)
local GoldRolls=require(Shared.GoldRolls)
local Session=require(game.ServerStorage.PetRoll.PlayerSession)
local Rolls=require(game.ServerStorage.PetRoll.RollService)
local Checks={}

local RAREST=1-1e-8 -- Rules.Draw's top band; no mutation draw passes this either.

-- A finished-guide session with the Auto Roll Gem Upgrade, three podiums and a fixed draw.
local function fixture(userId, draw, tree)
	local session=Session.new(userId,"Auto Roll fixture",1)
	session.loaded=true
	session.tutorial.bought,session.tutorial.guideCompleted=true,true
	session.gemUpgrades={AutoRoll=1}
	session.upgradeTree=tree or {}
	session:RefreshEffects()
	session.rollSlotCount=3
	session.offers,session.offer={},nil
	session.coins=0
	local rolls=Rolls.new()
	rolls.random={NextNumber=function() return draw end}
	return session,rolls
end

-- What the fixed draw rolls on this session's podiums, and its "1 in X".
local function drawn(session)
	local species=Rules.Draw(session.luck,RAREST,session.recruitTier,session:PaidLuckMultiplier(),
		session.researchEffects.rollingLuck or 0)
	return species,AutoRollRules.OneIn(species) or 1
end

local function offerCount(session)
	local count=0
	for _ in session.offers or {} do count+=1 end
	return count
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,detail=pcall(fn)
		table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
	end

	test("Old Auto Roll saves convert to 1-in-X settings",function()
		local default=AutoRollRules.Read(nil)
		assert(default.enabled==false and default.stopAt==1000 and default.recruitAt==nil)
		assert(default.mutationStop and default.upgradeStop)
		local upgrade=AutoRollRules.Read({enabled=true,stopAt="Upgrade"})
		assert(upgrade.enabled and upgrade.upgradeStop and upgrade.stopAt==1000)
		local mythic=AutoRollRules.Read({stopAt="Mythic",recruitAt="Rare",mutationStop=false})
		assert(not mythic.upgradeStop and not mythic.mutationStop)
		local floor=math.huge
		for _,id in Catalog.Order do
			local d=Catalog[id]
			if d.rarity=="Mythic" and d.oneIn and d.weight>0 and not d.crateExclusive then floor=math.min(floor,d.oneIn) end
		end
		assert(mythic.stopAt==math.floor(floor),"Mythic converts to its most common member")
		assert(mythic.recruitAt and mythic.recruitAt<mythic.stopAt)
		local odd=AutoRollRules.Read({enabled="yes",stopAt="junk",recruitAt={},upgradeStop=1})
		assert(odd.enabled==false and odd.stopAt==1000 and odd.recruitAt==nil)
		assert(AutoRollRules.Read({stopAt=1e12}).stopAt==AutoRollRules.Max)
		assert(AutoRollRules.Read({stopAt=-5}).stopAt==AutoRollRules.Min)
		local saved=AutoRollRules.Read(AutoRollRules.Save({enabled=true,stopAt=20000,recruitAt=500,mutationStop=false,upgradeStop=false}))
		assert(saved.enabled and saved.stopAt==20000 and saved.recruitAt==500 and not saved.mutationStop and not saved.upgradeStop)
		return "Upgrade, rarity names, odd values and the new shape all read leniently"
	end)

	test("Stop values step through the presets and read as 1 in X",function()
		assert(AutoRollRules.Step(1000,1)==5000 and AutoRollRules.Step(1000,-1)==500)
		assert(AutoRollRules.Step(1500,-1)==1000 and AutoRollRules.Step(1500,1)==5000)
		assert(AutoRollRules.Step(1000000,1)==1000000 and AutoRollRules.Step(100,-1)==100)
		assert(AutoRollRules.Text(20000)=="1 in 20,000" and AutoRollRules.Text(2)=="1 in 2")
		assert(string.find(AutoRollRules.Describe(2),"Common and up",1,true))
		return AutoRollRules.Describe(20000)
	end)

	test("Gold rolls count lever pulls",function()
		local saved={count=0}
		local gold={goldMachine=1,goldRate=0}
		for pull=1,9 do assert(GoldRolls.Advance(saved,gold)==nil,"pull "..pull) end
		assert(GoldRolls.State(saved.count,gold).ready and GoldRolls.Text(GoldRolls.State(saved.count,gold))=="Next roll is Gold!")
		assert(GoldRolls.Advance(saved,gold)=="Gold" and saved.count==0)
		assert(GoldRolls.Text(GoldRolls.State(saved.count,gold))=="10 Rolls Left")
		local fast={goldMachine=3,goldRate=2}
		for _=1,5 do assert(GoldRolls.Advance(saved,fast)==nil) end
		assert(GoldRolls.Advance(saved,fast)=="Prism" and GoldRolls.Luck("Prism")==10)
		saved.count=4
		assert(GoldRolls.Advance(saved,{goldMachine=0,goldRate=2})==nil and saved.count==4,"no machine counts nothing")
		assert(GoldRolls.State(99,gold).left==1,"a lower Gold Rate never shows zero")
		return "Every 10th (Gold Rate 0) and 6th (Gold Rate II) pull is special"
	end)

	test("A Gold pull boosts every podium's Luck",function()
		local session,rolls=fixture(-9101,0.5,{GoldMachine=1})
		assert(session.researchEffects.goldMachine==1,"GoldMachine node sets goldMachine")
		session.goldRolls.count=9
		local normalLuck=session.researchEffects.rollingLuck or 0
		assert(rolls:Roll(session,0))
		assert(offerCount(session)==3)
		local top=Catalog.LuckBands[#Catalog.LuckBands].species
		for _,offer in session.offers do
			assert(offer.special=="Gold" and math.abs(offer.researchLuck-((1+normalLuck)*2-1))<1e-9)
			local boosted=Rules.Odds(session.luck,session.recruitTier,offer.paidLuck,offer.researchLuck)[top]
			local plain=Rules.Odds(session.luck,session.recruitTier,offer.paidLuck,normalLuck)[top]
			assert(boosted>plain,"the rarest band is likelier on a Gold pull")
		end
		assert(session.goldRolls.count==0)
		assert(rolls:Roll(session,100))
		for _,offer in session.offers do assert(offer.special==nil) end
		assert(session.goldRolls.count==1)
		return "Special pull marks all podiums and doubles the Luck term"
	end)

	test("Auto Roll holds a chicken at the stop value; the alert recruits it from anywhere",function()
		local session,rolls=fixture(-9102,RAREST)
		local _,oneIn=drawn(session)
		session.autoRoll=AutoRollRules.Read({enabled=true,stopAt=math.floor(oneIn),upgradeStop=false})
		assert(rolls:StepAuto(session,0)=="rolled")
		assert(rolls:StepAuto(session,1)==nil,"waits for the reveal")
		assert(rolls:StepAuto(session,100)=="held")
		local snapshot=Rolls.AutoSnapshot(session)
		assert(snapshot.holding and snapshot.held.reason=="rarity" and snapshot.held.oneIn>=math.floor(oneIn))
		assert(not snapshot.held.canAfford)
		assert(rolls:StepAuto(session,101)==nil,"still holding")
		session.coins=snapshot.held.price
		local ok,message=rolls:RecruitHeld(session,snapshot.held.offerId,102)
		assert(ok,message)
		assert(offerCount(session)==2)
		assert(rolls:StepAuto(session,103)=="held","the next rare podium holds")
		assert(rolls:SetAutoRoll(session,{skip=true}))
		assert(rolls:StepAuto(session,104)=="rolled","Skip rolls on")
		assert(not Rolls.AutoSnapshot(session).holding)
		return "Hold, remote recruit and Skip"
	end)

	test("Auto-recruit buys at the recruit value only when affordable",function()
		local session,rolls=fixture(-9103,RAREST)
		local _,oneIn=drawn(session)
		assert(oneIn<AutoRollRules.Max,"the drawn chicken must not meet the stop value")
		session.autoRoll=AutoRollRules.Read({enabled=true,stopAt=AutoRollRules.Max,recruitAt=2,mutationStop=false,upgradeStop=false})
		assert(rolls:StepAuto(session,0)=="rolled")
		assert(rolls:StepAuto(session,100)=="rolled","no Coins: rolls on")
		local price=0
		for _,offer in session.offers do price+=offer.price end
		session.coins=price
		local count=session:Count()
		local result,receipts=rolls:StepAuto(session,200)
		assert(result=="recruited" and receipts and #receipts==3)
		assert(session.coins==0 and session:Count()==count+3)
		for _,item in receipts do assert(session.pets[item.petId] and item.before-item.after>0) end
		return "Three podiums recruited for exactly their prices"
	end)

	test("Army upgrade stop compares with the Army you picked",function()
		local session=fixture(-9104,RAREST)
		session.autoRoll=AutoRollRules.Read({enabled=true,stopAt=AutoRollRules.Max,mutationStop=false,upgradeStop=true})
		-- A mid band (stronger than Duck, nowhere near the stop value).
		local strong=Catalog.LuckBands[5].species
		assert(Rules.PetPower(strong,1,1)>Rules.PetPower("Duck",1,1))
		assert(Rolls.Keeper(session,{species=strong,level=1})=="upgrade")
		local duck
		for id,pet in session.pets do if pet.species=="Duck" then duck=id end end
		assert(duck,"starter Ducks")
		session.armySelection={duck}
		assert(Rolls.Keeper(session,{species="Duck",level=1})==nil,"an empty manual slot is not an upgrade")
		assert(Rolls.Keeper(session,{species=strong,level=1})=="upgrade")
		return "Manual Army: only a stronger chicken stops it"
	end)

	test("Rebirth chickens always stop it; SetAutoRoll validates",function()
		local session,rolls=fixture(-9105,RAREST)
		session.autoRoll=AutoRollRules.Read({enabled=true,stopAt=AutoRollRules.Max,mutationStop=false,upgradeStop=false})
		local veteran=Catalog.RebirthOrder[1]
		assert(Rolls.Keeper(session,{species=veteran,level=1,rebirthChicken=true})=="rebirth")
		assert(rolls:SetAutoRoll(session,{stopAt=20000}) and session.autoRoll.stopAt==20000)
		assert(not rolls:SetAutoRoll(session,{stopAt="abc"}) and session.autoRoll.stopAt==20000)
		assert(not rolls:SetAutoRoll(session,{enabled="yes"}))
		assert(rolls:SetAutoRoll(session,{recruitAt=5000}) and session.autoRoll.recruitAt==5000)
		assert(rolls:SetAutoRoll(session,{recruitAt=false}) and session.autoRoll.recruitAt==nil)
		session.gemUpgrades={}
		session:RefreshEffects()
		local ok,message=rolls:SetAutoRoll(session,{enabled=true})
		assert(not ok and message=="Unlock Auto Roll in Gem Upgrades.")
		assert(rolls:StepAuto(session,0)==nil,"locked Auto Roll never rolls")
		return "Rebirth chickens hold; requests checked"
	end)

	test("Auto Roll settings and the Gold count survive a save",function()
		local session=fixture(-9106,RAREST,{GoldMachine=1})
		session.autoRoll=AutoRollRules.Read({enabled=true,stopAt=20000,recruitAt=1000,mutationStop=false,upgradeStop=false})
		session.goldRolls.count=7
		local restored=Session.new(-9107,"Restore fixture",1)
		assert(restored:LoadData(session:ToData()))
		local auto=restored.autoRoll
		assert(auto.enabled and auto.stopAt==20000 and auto.recruitAt==1000 and not auto.mutationStop and not auto.upgradeStop)
		assert(restored.goldRolls.count==7)
		return "Settings and counter reload exactly"
	end)

	local passed=0
	for _,result in results do if result.passed then passed+=1 end end
	print(("[AutoRollChecks] %d/%d passed"):format(passed,#results))
	for _,result in results do
		print((if result.passed then "  PASS " else "  FAIL ")..result.name.." — "..result.detail)
	end
	return results
end

return Checks
