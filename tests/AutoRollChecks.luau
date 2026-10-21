-- October 20 Auto Roll panel and Gold rolls (S12, S12b; docs/team/AUTO_ROLL.md).
-- Isolated sessions; never opens saved player profiles. Run in a Run-mode playtest:
-- require(game.ServerStorage.PetRollTests.AutoRollChecks).Run()
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Rules=require(Shared.Rules)
local AutoRollRules=require(Shared.AutoRollRules)
local GoldRolls=require(Shared.GoldRolls)
local Session=require(game.ServerStorage.PetRoll.PlayerSession)
local Rolls=require(game.ServerStorage.PetRoll.RollService)
local Checks={}

local RAREST=1-1e-8 -- The last chicken Rules.Draw can reach; no mutation draw passes this either.

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

-- Settings with only these rows ON (nothing else stops it).
local function only(rows)
	return AutoRollRules.Read({enabled=true,rarities=rows.rarities or {},mutations=rows.mutations or {},
		newChicken=rows.newChicken==true,newMutation=rows.newMutation==true})
end

-- What the fixed draw rolls on this session's podiums.
local function drawn(session)
	return Rules.Draw(session.luck,RAREST,session.recruitTier,session:PaidLuckMultiplier(),session.researchEffects.rollingLuck or 0)
end

local function offerCount(session)
	local count=0
	for _ in session.offers or {} do count+=1 end
	return count
end

local function discoverAll(session)
	for _,id in Catalog.Order do session.discovered[id]=true end
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,detail=pcall(fn)
		table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
	end

	test("Old Auto Roll saves convert to the panel's rows",function()
		local default=AutoRollRules.Read(nil)
		assert(not default.enabled and default.rarities.Legendary and default.rarities.Mythic and default.rarities.Secret)
		assert(not default.rarities.Epic and default.mutations.Golden and default.mutations.Cosmic and not default.mutations.Normal)
		assert(default.newChicken and not default.newMutation)
		local mythic=AutoRollRules.Read({enabled=true,stopAt="Mythic",mutationStop=false})
		assert(mythic.enabled and mythic.rarities.Mythic and mythic.rarities.Secret and not mythic.rarities.Legendary)
		assert(next(mythic.mutations)==nil,"Stop on mutations off keeps every mutation row off")
		local rare=AutoRollRules.Read({stopAt="Rare"})
		assert(rare.rarities.Rare and rare.rarities.Epic and not rare.rarities.Uncommon and rare.mutations.Golden)
		local typed=AutoRollRules.Read({stopAt=1e9})
		assert(typed.rarities.Secret and not typed.rarities.Common,"a huge 1 in X keeps the rarest rows")
		local common=AutoRollRules.Read({stopAt=2})
		assert(common.rarities.Common and common.rarities.Secret,"1 in 2 turns on every rarity")
		local odd=AutoRollRules.Read({enabled="yes",rarities={Rare="yes",Fake=true,Epic=true},mutations=5})
		assert(not odd.enabled and odd.rarities.Epic and not odd.rarities.Rare and not odd.rarities.Fake)
		assert(next(odd.mutations)==nil)
		local saved=AutoRollRules.Save(only({rarities={Rare=true},mutations={Normal=true},newMutation=true}))
		local back=AutoRollRules.Read(saved)
		assert(back.rarities.Rare and back.mutations.Normal and back.newMutation and not back.newChicken)
		assert(type(saved.stopAt)=="number" and saved.mutationStop==false,"old servers get close fields")
		return "October 15 names, S12 numbers, odd values and the new rows all read leniently"
	end)

	test("Any ON row stops it, and the banner names why",function()
		local value=only({rarities={Rare=true},mutations={Golden=true}})
		assert(AutoRollRules.Reason(value,"Rare",nil,false,false)=="rarity")
		assert(AutoRollRules.Reason(value,"Common","Golden",false,false)=="mutation")
		assert(AutoRollRules.Reason(value,"Common",nil,true,false)==nil,"New Chicken off")
		assert(AutoRollRules.Reason(only({mutations={Normal=true}}),"Common",nil,false,false)=="normal")
		assert(AutoRollRules.Reason(only({newChicken=true}),"Common",nil,true,false)=="newChicken")
		assert(AutoRollRules.Reason(only({newMutation=true}),"Common","Rainbow",false,true)=="newMutation")
		assert(AutoRollRules.Banner("rarity","Rare",nil)=="Auto Roll found a Rare chicken!")
		assert(AutoRollRules.Banner("rarity","Epic",nil)=="Auto Roll found an Epic chicken!")
		assert(AutoRollRules.Banner("mutation","Common","Golden")=="Auto Roll found a Golden chicken!")
		assert(AutoRollRules.Banner("newChicken","Common",nil)=="Auto Roll found a new chicken!")
		assert(AutoRollRules.Banner("rebirth","Legendary",nil)=="Auto Roll found a Rebirth chicken!")
		return "OR rules and banner lines"
	end)

	test("Gold, Diamond and Prism count on their own",function()
		local saved={count=0}
		local all={goldMachine=3,goldRate=0}
		local kinds={}
		for pull=1,500 do
			local kind=GoldRolls.Advance(saved,all)
			if kind then kinds[kind]=(kinds[kind] or 0)+1 end
			if pull==100 then assert(kind=="Diamond","Diamond beats Gold on pull 100") end
			if pull==500 then assert(kind=="Prism","Prism beats Diamond on pull 500") end
			if pull==10 then assert(kind=="Gold") end
		end
		-- 50 tens, 5 of them hundreds (Diamond wins), and pull 500 goes to Prism.
		assert(kinds.Gold==45 and kinds.Diamond==4 and kinds.Prism==1)
		local counters=GoldRolls.Counters({count=4,diamond=2},{goldMachine=2,goldRate=0})
		assert(#counters==2 and counters[1].kind=="Gold" and counters[1].left==6 and counters[2].left==98)
		assert(GoldRolls.Text(counters[1])=="6 Rolls Left" and GoldRolls.Text({kind="Gold",every=10,count=9,left=1,luck=2})=="1 Roll Left")
		local fast={count=0}
		-- Tree v2 (S9c): Every is {10,8,7,6,5}, so tier III is every 6th.
		for _=1,5 do assert(GoldRolls.Advance(fast,{goldMachine=1,goldRate=3})==nil) end
		assert(GoldRolls.Advance(fast,{goldMachine=1,goldRate=3})=="Gold","Gold Rate III: every 6th")
		local none={count=3}
		assert(GoldRolls.Advance(none,{goldMachine=0})==nil and none.count==3,"no machine counts nothing")
		return "Three counters; the bigger boost wins a shared pull"
	end)

	test("A Diamond pull boosts every podium's Luck",function()
		local session,rolls=fixture(-9201,0.5,{GoldMachine=1,GoldRate=2,DiamondMachine=1})
		assert(session.researchEffects.goldMachine==2,"Diamond Machine sets goldMachine 2")
		session.goldRolls.count,session.goldRolls.diamond=2,99
		local normalLuck=session.researchEffects.rollingLuck or 0
		assert(rolls:Roll(session,0))
		local top=Catalog.LuckBands[#Catalog.LuckBands].species
		for _,offer in session.offers do
			assert(offer.special=="Diamond" and math.abs(offer.researchLuck-((1+normalLuck)*5-1))<1e-9)
			local boosted=Rules.Odds(session.luck,session.recruitTier,offer.paidLuck,offer.researchLuck)[top]
			assert(boosted>Rules.Odds(session.luck,session.recruitTier,offer.paidLuck,normalLuck)[top])
		end
		assert(session.goldRolls.diamond==0 and session.goldRolls.count==3,"each counter moves on its own")
		return "Diamond pull: 5x Luck on all podiums"
	end)

	test("Auto Roll holds a chicken for its rarity until recruited, rolled on or toggled",function()
		local session,rolls=fixture(-9202,RAREST)
		discoverAll(session)
		local rarity=Catalog[drawn(session)].rarity
		session.autoRoll=only({rarities={[rarity]=true}})
		assert(rolls:StepAuto(session,0)=="rolled")
		assert(rolls:StepAuto(session,1)==nil,"waits for the reveal")
		assert(rolls:StepAuto(session,100)=="held")
		local snapshot=Rolls.AutoSnapshot(session)
		assert(snapshot.holding and snapshot.held.reason=="rarity" and snapshot.held.banner==AutoRollRules.Banner("rarity",rarity,nil))
		assert(rolls:StepAuto(session,101)==nil,"still holding")
		session.coins=1e12
		assert(rolls:Buy(session,snapshot.held.offerId,102),"recruited at the podium")
		assert(offerCount(session)==2 and rolls:StepAuto(session,103)=="held","the next one holds")
		assert(rolls:SetAutoRoll(session,{enabled=false}) and rolls:SetAutoRoll(session,{enabled=true}))
		assert(rolls:StepAuto(session,104)=="rolled","turning it back on rolls on")
		return "Hold, recruit at the podium, and off/on"
	end)

	test("New Chicken and New Mutation rows",function()
		local session,rolls=fixture(-9203,RAREST)
		session.autoRoll=only({newChicken=true})
		session.discovered={}
		assert(rolls:StepAuto(session,0)=="rolled" and rolls:StepAuto(session,100)=="held")
		assert(Rolls.AutoSnapshot(session).held.reason=="newChicken")
		discoverAll(session)
		assert(Rolls.Keeper(session,{species="Duck",level=1})==nil,"known chickens roll on")
		session.autoRoll=only({newMutation=true})
		assert(Rolls.Keeper(session,{species="Duck",level=1,mutation="Golden"})=="newMutation")
		local id=next(session.pets)
		session.pets[id].species,session.pets[id].mutation="Duck","Golden"
		assert(Rolls.Keeper(session,{species="Duck",level=1,mutation="Golden"})==nil,"already owned")
		return "Index and owned mutations decide what is new"
	end)

	test("Rebirth chickens always stop it; SetAutoRoll validates",function()
		local session,rolls=fixture(-9204,RAREST)
		session.autoRoll=only({})
		assert(Rolls.Keeper(session,{species=Catalog.RebirthOrder[1],level=1,rebirthChicken=true})=="rebirth")
		assert(rolls:SetAutoRoll(session,{rarity="Rare",on=true}) and session.autoRoll.rarities.Rare)
		assert(rolls:SetAutoRoll(session,{rarity="Rare",on=false}) and not session.autoRoll.rarities.Rare)
		assert(rolls:SetAutoRoll(session,{mutation="Normal",on=true}) and session.autoRoll.mutations.Normal)
		assert(rolls:SetAutoRoll(session,{newMutation=true}) and session.autoRoll.newMutation)
		assert(not rolls:SetAutoRoll(session,{rarity="Fake",on=true}))
		assert(not rolls:SetAutoRoll(session,{rarity="Rare"}),"a row needs on")
		assert(not rolls:SetAutoRoll(session,{enabled="yes"}))
		session.gemUpgrades={}
		session:RefreshEffects()
		local ok,message=rolls:SetAutoRoll(session,{enabled=true})
		assert(not ok and message=="Unlock Auto Roll in Gem Upgrades.")
		assert(rolls:StepAuto(session,0)==nil,"locked Auto Roll never rolls")
		return "Rebirth chickens hold; requests checked"
	end)

	test("Auto Roll rows and the three counts survive a save",function()
		local session=fixture(-9205,RAREST,{GoldMachine=1})
		session.autoRoll=only({rarities={Epic=true},mutations={Shadow=true},newMutation=true})
		session.goldRolls={count=7,diamond=42,prism=301}
		local restored=Session.new(-9206,"Restore fixture",1)
		assert(restored:LoadData(session:ToData()))
		local auto=restored.autoRoll
		assert(auto.enabled and auto.rarities.Epic and not auto.rarities.Legendary and auto.mutations.Shadow)
		assert(auto.newMutation and not auto.newChicken)
		assert(restored.goldRolls.count==7 and restored.goldRolls.diamond==42 and restored.goldRolls.prism==301)
		return "Rows and counters reload exactly"
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
