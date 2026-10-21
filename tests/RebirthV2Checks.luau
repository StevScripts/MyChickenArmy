-- October 20 Rebirth v2, Gems and the Upgrades tree (S7; docs/team/OVERHAUL_CONTRACT_20261020.md
-- §4-§9). Isolated sessions only: no DataStore, live world, Players or product prompts.
-- Replaces the retired RebirthChecks (archive/tests-retired-20261020). Run in Studio:
-- require(game.ServerStorage.PetRollTests.RebirthV2Checks).Run()
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Catalog=require(Shared.PetCatalog)
local Rules=require(Shared.Rules)
local Tree=require(Shared.UpgradeCatalog)
local GemCatalog=require(Shared.GemUpgradeCatalog)
local Mutations=require(Shared.MutationCatalog)
local Shop=require(Shared.ShopCatalog)
local Session=require(Server.PlayerSession)
local Rebirth=require(Server.RebirthService)
local Upgrades=require(Server.UpgradeService)
local GemUpgrades=require(Server.GemUpgradeService)
local RebirthChickens=require(Server.RebirthChickens)
local Operations=require(Server.OperationService)
local Checks={}

-- Isolated: no live server, so no analytics, battles, yard eggs or save requests.
local NO_SERVER: any = nil

local function near(a,b,why)
	assert(math.abs(a-b)<1e-6,(why or "Values differ")..": "..tostring(a).." ~= "..tostring(b))
end

-- A refusal with exactly this message. The call goes last so its returns arrive
-- (any after the message, such as a receipt, are ignored).
local function refused(wanted,ok,message,...)
	assert(not ok,"Expected a refusal: "..wanted)
	assert(message==wanted,"Wanted '"..wanted.."', got '"..tostring(message).."'")
end

-- "EggSpeed=2, Luck=1": a saved tree or Gem levels in a stable order.
local function levelsText(levels)
	local list={}
	for id,level in levels do table.insert(list,id.."="..tostring(level)) end
	table.sort(list)
	return table.concat(list,", ")
end

local function veterans(session): number
	local count=0
	for _,pet in session.pets do if Catalog[pet.species].rebirthRank then count+=1 end end
	return count
end

-- A loaded session past the Commander guide (no starter reserve) at Rebirth 0.
local function fixture(userId)
	local session=Session.new(userId,"Rebirth fixture",1)
	session.loaded=true
	session.tutorial.bought,session.tutorial.guideCompleted=true,true
	return session
end

local function setTree(session,tree)
	session.upgradeTree=tree
	session:RefreshEffects()
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,detail=pcall(fn)
		table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
	end

	test("Thirty Rebirth chickens: never rolled, never weaker by rank, Cosmic Dragon's damage at most",function()
		assert(#Catalog.RebirthOrder==Config.Rebirth.MaxRank,"Rebirth chickens "..#Catalog.RebirthOrder)
		local previous=0
		for rank,id in Catalog.RebirthOrder do
			local definition=Catalog[id]
			assert(definition.weight==0 and definition.rebirthRank==rank and definition.rebirthExclusive,id)
			assert(RebirthChickens.Species(rank)==id,"Species "..rank)
			local power=Rules.PetPower(id,1,1)
			assert(power>=previous,id.." is weaker than the rank before")
			assert(definition.damage<=Catalog.CosmicDragon.damage,id.." passes Cosmic Dragon's damage")
			previous=power
		end
		-- As built and kept by Stevin: ranks 25-30 climb to 165 on the faster Galaxy interval.
		assert(Catalog.Veteran25.damage==101 and Catalog.Veteran30.damage==165,"Top damage")
		assert(Catalog.Veteran30.damage/Catalog.Veteran30.interval
			>Catalog.CosmicDragon.damage/Catalog.CosmicDragon.interval,"Veteran30 attack rate")
		return "30 Veterans, damage 101-165 at the top"
	end)

	test("Tree values, mutation ranks and default effects",function()
		assert(Rules.EggUnitValue(0)==4 and Rules.EggUnitValue(4)==20,"Egg unit value "..Rules.EggUnitValue(4))
		assert(Rules.LuckWindow(4).multiplier==3,"Luck tier 4")
		assert(Mutations.Defs.Shadow.unlockRank==5 and Mutations.Defs.Cosmic.unlockRank==10,"Mutation ranks")
		local effects=Tree.Effects({},{})
		assert(effects.flockSize==3 and effects.timeSkipMinutes==5 and effects.callArmy==1,"Flock, Time Skip, Call Army")
		assert(effects.keepTiers==0 and effects.autoRebirth==0 and effects.rebirthChickenChance==0.01,"Gem defaults")
		assert(GemCatalog.Level({},"TimeSkip")==1 and GemCatalog.Level({},"CoinBoost")==0,"Gem start levels")
		assert(Tree.ValueText("VacuumCapacity",1)=="+15 s of eggs",Tree.ValueText("VacuumCapacity",1))
		return "Defaults match the contract"
	end)

	test("Skip products by band are on sale; research skips and retired passes pay Gems",function()
		for rank=1,Config.Rebirth.MaxRank do
			local wanted=if rank<=5 then "RebirthSkip1" elseif rank<=15 then "RebirthSkip2" else "RebirthSkip3"
			assert(Shop.RebirthSkipFor(rank)==wanted,"Rank "..rank.." -> "..tostring(Shop.RebirthSkipFor(rank)))
		end
		assert(Shop.RebirthSkipFor(0)==nil and Shop.RebirthSkipFor(Config.Rebirth.MaxRank+1)==nil,"Outside the bands")
		for _,key in Shop.RebirthSkipOrder do
			local product=Shop.Products[key]
			assert(Shop.ProductOnSale(key) and product.rebirthSkip and product.paidRandom,key.." is not on sale")
		end
		for _,key in Shop.ResearchSkipOrder do assert(not Shop.ProductOnSale(key),key.." is still on sale") end
		assert(Shop.ResearchSkipGems(86400)==288 and Shop.ResearchSkipGems(60)==1,"Research skip Gems")
		for _,key in Shop.RetiredOrder do
			local pass=Shop.Definitions[key]
			assert(pass.offSale and pass.retiredGems>0 and not table.find(Shop.Order,key),key)
		end
		assert(Shop.Definitions.CommanderBanner.keepsBenefit,"The Banner cosmetic stays")
		return "Three bands, ten retired skips, four retired passes"
	end)

	test("A fresh run: the starter reserve protects Army Size 4 and tiers buy in order",function()
		local s=Session.new(-9301,"Fresh fixture",1)
		s.loaded=true
		assert(s.coins==Config.StartingCoins and s.capacity==3 and s.rollSlotsUnlocked==1 and s:FlockSize()==3,"Fresh run")
		assert(next(s.upgradeTree)==nil and s.gems==0 and s.rebirths==0,"Fresh economy")
		assert(s:StarterArmyReserve()==1200,"Army Size reserve "..s:StarterArmyReserve())
		local upgrades=Upgrades.new(nil,nil)
		local ok,message=upgrades:BuyNode(s,"EggSpeed1",Tree.Price("EggSpeed",1,0))
		assert(ok and s.eggSpeedLevel==1 and s.coins==Config.StartingCoins-400,message)
		-- 2,000 Coins left, 1,800 kept for the guide's recruit and Army Size 4.
		ok,message=upgrades:BuyNode(s,"EggSpeed2",Tree.Price("EggSpeed",2,0))
		assert(not ok and string.find(message,"Keep 1,800 Coins",1,true),message)
		refused("This upgrade changed. Try again.",upgrades:BuyNode(s,"EggSpeed2",1))
		refused("Egg Speed I is already yours.",upgrades:BuyNode(s,"EggSpeed1",Tree.Price("EggSpeed",1,0)))
		ok,message=upgrades:BuyNode(s,"ArmySize1",1200)
		assert(ok and s.capacity==4 and s.coins==800 and s:StarterArmyReserve()==0,message)
		refused("Buy Army Size II first.",upgrades:BuyNode(s,"ArmySize3",Tree.Price("ArmySize",3,0)))
		refused("Buy Chicken Feed in Upgrades > Tools first.",s:ChickenUpgradeEligibility((next(s.pets))))
		return "Reserve, quotes and order hold"
	end)

	test("Rebirth 1 resets the run and pays Gems, Time Skip Coins and Veteran1; progress stays",function()
		local s=fixture(-9302)
		setTree(s,{EggSpeed=4,EggValue=4,Luck=2,Flock=1,ArmySize=2,ChickenFeed=1})
		local fed=s:AddPet("Duck",1)
		fed.level,fed.cashLevels=3,2
		s.eggCarry={count=5,value=100}
		s.firstWins[1],s.kingCleared=true,true
		s.research.operationWins.Fixture=true
		s.coins=60000
		local quote=Rebirth.Quote(s)
		assert(quote.eligible and quote.nextRank==1 and quote.cost==50000 and quote.gemsNext==50,
			"Quote: "..tostring(quote.reason)..", "..tostring(quote.gemsNext).." Gems")
		assert(quote.nextChicken.species=="Veteran1" and quote.multiplierNext==2 and quote.enemyScaleNext==1,"Quote rewards")
		assert(quote.timeSkipMinutes==5 and quote.cashLevels==2 and quote.kingRequired==false,"Quote details")
		local count=s:Count()
		local ok,message,receipt=Rebirth.Rebirth(s,0,NO_SERVER,false)
		assert(ok and message=="Rebirth complete: Rebirth 1",message)
		assert(s.rebirths==1 and receipt.rank==1 and receipt.gems==50 and not receipt.skip and not receipt.automatic,"Receipt")
		assert(next(s.upgradeTree)==nil and s.capacity==3 and s.luck==0 and s.eggSpeedLevel==0 and s:FlockSize()==3,
			"Tree left: "..levelsText(s.upgradeTree))
		assert(s.gems==50 and s.gemsEarned==50,"Gems "..s.gems)
		local granted=s.pets[receipt.petId]
		assert(s:Count()==count+1 and granted.species=="Veteran1" and granted.level==1 and granted.investment==0,"Veteran1")
		-- Time Skip pays today's income, measured before the reset, as the quote showed.
		assert(receipt.timeSkipCoins==quote.timeSkipCoins and receipt.timeSkipCoins>Rebirth.TimeSkipCoins(s),
			"Time Skip "..receipt.timeSkipCoins.." vs quote "..quote.timeSkipCoins)
		assert(s.coins==receipt.timeSkipCoins,"Coins "..s.coins)
		assert(fed.level==1 and fed.cashLevels==nil,"Chicken Feed levels stay")
		assert(s.eggCarry.count==0 and s.eggCarry.value==0,"Carried eggs stay")
		assert(s.firstWins[1] and s.kingCleared and s.research.operationWins.Fixture,"Camp, King or Mission progress lost")
		near(s:EarnedAmount(100,"eggs",true),200,"Rebirth 1 egg multiplier")
		return "+50 Gems, Time Skip "..receipt.timeSkipCoins.." Coins"
	end)

	test("Refusals: short of Coins, stale rank, army away, not loaded",function()
		local s=fixture(-9303)
		s.coins=10
		assert(Rebirth.Quote(s).reason=="Need 49,990 more Coins",Rebirth.Quote(s).reason)
		refused("Need 49,990 more Coins",Rebirth.Rebirth(s,0,NO_SERVER,false))
		s.coins=60000
		refused("Your Rebirth changed. Try again.",Rebirth.Rebirth(s,1,NO_SERVER,false))
		s.outgoing="fixture-battle"
		assert(not Rebirth.Quote(s).armyHome,"Army counted home")
		refused("Bring your army back to your base first",Rebirth.Rebirth(s,0,NO_SERVER,false))
		s.outgoing=nil
		s.loaded=false
		refused("Your flock is not ready yet.",Rebirth.Rebirth(s,0,NO_SERVER,false))
		s.loaded=true
		assert(s.rebirths==0 and s.coins==60000 and s.gems==0,"A refusal changed the run")
		return "Nothing changes on a refusal"
	end)

	test("Max rank: no next quote or Rebirth, and a waiting Skip credit stays",function()
		local s=fixture(-9304)
		s.rebirths,s.coins,s.rebirthSkips=Config.Rebirth.MaxRank,Rebirth.Cost(Config.Rebirth.MaxRank),1
		local quote=Rebirth.Quote(s)
		assert(quote.nextRank==nil and quote.cost==nil and not quote.eligible and quote.reason=="Max Rebirth reached",
			tostring(quote.reason))
		assert(quote.gemsNext==nil and quote.nextChicken==nil and quote.skip.productKey==nil and not quote.skip.onSale,
			"Max-rank quote")
		refused("Max Rebirth reached",Rebirth.Rebirth(s,Config.Rebirth.MaxRank,NO_SERVER,false))
		refused("Max Rebirth reached",Rebirth.Rebirth(s,Config.Rebirth.MaxRank,NO_SERVER,true))
		assert(not Rebirth.Step(s,NO_SERVER) and s.rebirthSkips==1 and s.rebirths==Config.Rebirth.MaxRank,"Step at max rank")
		return "Rebirth 30 is the end"
	end)

	test("Rank numbers: costs, Gems, egg multiplier, enemy scale and Mission tiers",function()
		assert(Rebirth.Cost(1)==50000,"Rebirth 1 cost")
		assert(Rebirth.Cost(0)==nil and Rebirth.Cost(Config.Rebirth.MaxRank+1)==nil and Rebirth.Cost(1.5)==nil,"Cost domain")
		for rank=2,Config.Rebirth.MaxRank do assert(Rebirth.Cost(rank)>Rebirth.Cost(rank-1),"Cost "..rank) end
		local s=fixture(-9305)
		assert(Rebirth.Gems(s,1)==50 and Rebirth.Gems(s,30)==340,"Gems "..Rebirth.Gems(s,1).." and "..Rebirth.Gems(s,30))
		s.gemUpgrades={MoreGems=2}
		s:RefreshEffects()
		assert(Rebirth.Gems(s,10)==168,"More Gems "..Rebirth.Gems(s,10))
		assert(Rebirth.Multiplier(0)==1 and Rebirth.Multiplier(1)==2 and Rebirth.Multiplier(30)==31,"Egg multiplier")
		assert(Rebirth.EnemyScale(0)==1 and Rebirth.EnemyScale(2)==1 and Rebirth.EnemyScale(3)==1.25
			and Rebirth.EnemyScale(10)==3 and Rebirth.EnemyScale(30)==8,"Enemy scale")
		assert(Rebirth.Title(0)=="No rebirths yet" and Rebirth.Title(7)=="Rebirth 7","Titles")
		-- Mission tiers: King clear or Rebirth 5, 10, 15, or a converted research tier.
		local m=fixture(-9306)
		assert(Operations.Tier(m)==0,"No tier")
		m.kingCleared=true
		assert(Operations.Tier(m)==1,"King clear")
		m.kingCleared,m.rebirths=false,5
		assert(Operations.Tier(m)==1,"Rebirth 5")
		m.rebirths=10
		assert(Operations.Tier(m)==2,"Rebirth 10")
		m.rebirths=15
		assert(Operations.Tier(m)==3,"Rebirth 15")
		m.rebirths,m.missionTierLegacy=0,2
		assert(Operations.Tier(m)==2,"Converted tier")
		assert(Operations.LockedMessage(1)=="Defeat the Chicken King or reach Rebirth 5 first."
			and Operations.LockedMessage(3)=="Reach Rebirth 15 first.","Locked messages")
		return "Formulas match the contract"
	end)

	test("Gem Upgrades: rows open by rank and buys use the exact quote",function()
		local s=fixture(-9307)
		s.rebirths,s.gems=1,50
		local snapshot=GemUpgrades.Snapshot(s)
		assert(#snapshot.order==#GemCatalog.Order and not snapshot.autoRebirth.owned,"Snapshot")
		assert(snapshot.items.TimeSkip.status=="Locked" and snapshot.items.TimeSkip.level==1
			and snapshot.items.RollSpeed.status=="Available","Row status")
		refused("Reach Rebirth 2 to unlock Time Skip.",GemUpgrades.Buy(s,"TimeSkip",1,20))
		refused("This upgrade changed. Try again.",GemUpgrades.Buy(s,"AutoRoll",0,99))
		refused("Choose a Gem Upgrade.",GemUpgrades.Buy(s,"Nope",0,1))
		local ok,message=GemUpgrades.Buy(s,"AutoRoll",0,15)
		assert(ok and message=="Auto Roll unlocked!" and s.researchEffects.autoRoll==1 and s.gems==35,message)
		refused("Auto Roll is at its maximum.",GemUpgrades.Buy(s,"AutoRoll",1,nil))
		ok,message=GemUpgrades.Buy(s,"AutoRebirth",0,25)
		assert(ok and s.autoRebirth==true and s.researchEffects.autoRebirth==1,message)
		ok,message=GemUpgrades.Buy(s,"CoinBoost",0,10)
		assert(ok and message=="Coin Boost is now level 1!" and s.gems==0,message)
		near(s.researchEffects.coinBoost,0.1,"Coin Boost")
		refused("Need 15 more Gems.",GemUpgrades.Buy(s,"CoinBoost",1,15))
		-- Coin Boost multiplies egg Coins only, on top of the Rebirth 1 multiplier.
		near(s:EarnedAmount(100,"eggs",true),220,"Egg Coins")
		near(s:EarnedAmount(100,"battle",true),100,"Battle Coins")
		refused("Invalid Auto Rebirth setting.",GemUpgrades.SetAutoRebirth(s,"yes"))
		ok,message=GemUpgrades.SetAutoRebirth(s,false)
		assert(ok and message=="Auto Rebirth off." and s.autoRebirth==false,message)
		refused("Unlock Auto Rebirth in Gem Upgrades first.",GemUpgrades.SetAutoRebirth(fixture(-9308),true))
		return "Locks, quotes, prices and effects hold"
	end)

	test("Time Skip and More Gems raise the next Rebirth's rewards",function()
		local s=fixture(-9309)
		s.rebirths,s.gems=2,200
		local fiveMinutes=Rebirth.TimeSkipCoins(s)
		local ok,message=GemUpgrades.Buy(s,"TimeSkip",1,20)
		assert(ok and s.researchEffects.timeSkipMinutes==10,message)
		local tenMinutes=Rebirth.TimeSkipCoins(s)
		assert(math.abs(tenMinutes-2*fiveMinutes)<=1,fiveMinutes.." then "..tenMinutes)
		ok,message=GemUpgrades.Buy(s,"MoreGems",0,25)
		assert(ok,message)
		local quote=Rebirth.Quote(s)
		-- floor((40 + 30) x 1.1) Gems for Rebirth 3.
		assert(quote.gemsNext==77 and quote.timeSkipCoins==tenMinutes,
			tostring(quote.gemsNext).." Gems, Time Skip "..tostring(quote.timeSkipCoins))
		return "Time Skip "..fiveMinutes.." -> "..tenMinutes.." Coins"
	end)

	test("A Skip credit rebirths without Coins, keeps the run and waits for the army",function()
		local s=fixture(-9310)
		s.rebirths,s.coins=1,123
		setTree(s,{EggSpeed=1})
		local fed=s:AddPet("Duck",1)
		fed.level,fed.cashLevels=2,1
		refused("You have no Skip ready.",Rebirth.Rebirth(s,1,NO_SERVER,true))
		s.rebirthSkips=1
		s.outgoing="fixture-battle"
		refused("Skip ready: bring your army home.",Rebirth.Rebirth(s,1,NO_SERVER,true))
		assert(not Rebirth.Step(s,NO_SERVER) and s.rebirthSkips==1,"Step spent the credit with the army away")
		s.outgoing=nil
		local ok,message,receipt=Rebirth.Step(s,NO_SERVER)
		assert(ok and receipt.skip and not receipt.automatic and s.rebirths==2 and s.rebirthSkips==0,message)
		assert(s.upgradeTree.EggSpeed==1 and fed.level==2 and fed.cashLevels==1,"The run was reset")
		assert(s.coins==123+receipt.timeSkipCoins and s.gems==60,"Coins "..s.coins.." Gems "..s.gems)
		assert(s.pets[receipt.petId].species=="Veteran2","Veteran2")
		return "Credit spent once the army was home"
	end)

	test("Auto Rebirth: Coins ready, army home, switched on, and only with the Gem Upgrade",function()
		local s=fixture(-9311)
		s.rebirths=1
		s.gemUpgrades={AutoRebirth=1}
		s:RefreshEffects()
		s.autoRebirth=true
		s.coins=(Rebirth.Cost(2) :: number)-1
		assert(not Rebirth.Step(s,NO_SERVER) and s.rebirths==1,"Short of Coins")
		s.coins=Rebirth.Cost(2)
		s.outgoing="fixture-battle"
		assert(not Rebirth.Step(s,NO_SERVER) and s.rebirths==1,"Army away")
		s.outgoing,s.autoRebirth=nil,false
		assert(not Rebirth.Step(s,NO_SERVER) and s.rebirths==1,"Switched off")
		s.autoRebirth=true
		local ok,message,receipt=Rebirth.Step(s,NO_SERVER)
		assert(ok and receipt.automatic and not receipt.skip and s.rebirths==2,message)
		assert(s.coins==receipt.timeSkipCoins,"Coins "..s.coins)
		local other=fixture(-9312)
		other.coins=Rebirth.Cost(1)
		assert(not Rebirth.Step(other,NO_SERVER) and other.rebirths==0,"Rebirthed without Auto Rebirth")
		return "Rebirth 2 on the step it became eligible"
	end)

	test("Keep Upgrades keeps tiers of Egg Speed, Egg Value and Luck only",function()
		local s=fixture(-9313)
		s.rebirths,s.gems=5,130
		assert(GemUpgrades.Buy(s,"KeepUpgrades",0,40))
		local ok,message=GemUpgrades.Buy(s,"KeepUpgrades",1,90)
		assert(ok and s.researchEffects.keepTiers==2,message)
		setTree(s,{EggSpeed=4,EggValue=1,Luck=3,Flock=5,ArmySize=2,RollSlot=3})
		local quote=Rebirth.Quote(s)
		assert(quote.keepTiers==2 and string.find(quote.resets[2],"you keep 2 tiers",1,true),quote.resets[2])
		s.coins=Rebirth.Cost(6)
		ok,message=Rebirth.Rebirth(s,5,NO_SERVER,false)
		assert(ok,message)
		assert(levelsText(s.upgradeTree)=="EggSpeed=2, EggValue=1, Luck=2",levelsText(s.upgradeTree))
		assert(s.eggSpeedLevel==2 and s.incomeLevel==1 and s.luck==2,"Kept tiers")
		assert(s.capacity==3 and s.rollSlotsUnlocked==1 and s:FlockSize()==3,"Reset families")
		return levelsText(s.upgradeTree)
	end)

	test("Rebirth chickens: a credit while storage is full; podium offers replace only weaker chickens",function()
		local s=fixture(-9314)
		local count=s:Count()
		s.CollectionLimit=function(self) return self:Count() end
		assert(RebirthChickens.Grant(s,3)==nil and s:Count()==count and s.rebirthChickenCredits[1]=="Veteran3",
			"Credit at the cap")
		s.CollectionLimit=nil
		local delivered=RebirthChickens.Deliver(s)
		assert(#delivered==1 and s.pets[delivered[1]].species=="Veteran3" and #s.rebirthChickenCredits==0,"Delivered")
		local rng=Random.new(7)
		s.researchEffects=table.clone(s.researchEffects)
		s.researchEffects.rebirthChickenChance=1
		assert(RebirthChickens.MaybeReplace(s,"Duck",rng,1)=="Duck","Rebirth 0 was offered one")
		s.rebirths=3
		for _=1,50 do
			local species=RebirthChickens.MaybeReplace(s,"Duck",rng,1)
			local rank=Catalog[species].rebirthRank
			assert(rank and rank<=3,"Offer "..species)
		end
		assert(RebirthChickens.MaybeReplace(s,"StormDuck",rng,1)=="StormDuck","A stronger offer was replaced")
		s.researchEffects.rebirthChickenChance=0
		for _=1,20 do assert(RebirthChickens.MaybeReplace(s,"Duck",rng,1)=="Duck","Chance 0 replaced") end
		return "Credit, delivery and podium rule hold"
	end)

	test("Revision 12 saves keep the tree, Gems, Skip credits and settings",function()
		local s=fixture(-9315)
		s.rebirths=4
		-- S14: the Egg Vacuum is a bought Tools node (Stevin, October 20).
		s.upgradeTree={EggSpeed=2,Flock=3,ArmySize=1,EggVacuum=1}
		s.gemUpgrades={AutoRoll=1,CoinBoost=3,TimeSkip=2}
		s:RefreshEffects()
		s.gems,s.gemsEarned=77,300
		s.autoRebirth,s.rebirthSkips,s.missionTierLegacy=false,2,1
		s.rebirthChickenCredits={"Veteran2"}
		local data=s:ToData()
		assert(data.dataRevision==12 and Config.DataRevision==12,"Revision "..tostring(data.dataRevision))
		local t=Session.new(-9315,"Restore fixture",1)
		local ok,message=t:LoadData(data)
		assert(ok and message=="Loaded.",message)
		assert(t.rebirths==4 and levelsText(t.upgradeTree)=="ArmySize=1, EggSpeed=2, EggVacuum=1, Flock=3",levelsText(t.upgradeTree))
		assert(t.gems==77 and t.gemsEarned==300 and levelsText(t.gemUpgrades)=="AutoRoll=1, CoinBoost=3, TimeSkip=2",
			levelsText(t.gemUpgrades))
		assert(t.autoRebirth==false and t.rebirthSkips==2 and t.missionTierLegacy==1 and t.eggVacuum==false,"Settings")
		assert(#t.rebirthChickenCredits==1 and t.rebirthChickenCredits[1]=="Veteran2","Chicken credits")
		assert(t.eggSpeedLevel==2 and t.capacity==4 and t:FlockSize()==6 and t.researchEffects.timeSkipMinutes==10
			and t.researchEffects.eggVacuum==1,"Derived fields")
		near(t.researchEffects.coinBoost,0.3,"Coin Boost")
		assert(t.economyConversion==nil,"A revision 12 save converted again")
		return "Every new field reloads"
	end)

	test("A saved Egg Vacuum grant becomes this run's Tools node once; a Rebirth takes it back",function()
		local data=fixture(-9320):ToData()
		data.upgradeTree,data.eggVacuum={Luck=1},true
		local t=Session.new(-9320,"Vacuum fixture",1)
		local ok,message=t:LoadData(data)
		assert(ok,message)
		assert(levelsText(t.upgradeTree)=="EggVacuum=1, Luck=1" and t.researchEffects.eggVacuum==1 and t.eggVacuum==false,
			levelsText(t.upgradeTree))
		local saved=t:ToData()
		assert(saved.eggVacuum==false and saved.upgradeTree.EggVacuum==1,"Saved as a node")
		-- The Rebirth reset empties the tree; the old grant must not come back.
		t.upgradeTree={}
		local again=Session.new(-9320,"Vacuum reload fixture",1)
		ok,message=again:LoadData(t:ToData())
		assert(ok,message)
		assert(next(again.upgradeTree)==nil and again.researchEffects.eggVacuum==0,levelsText(again.upgradeTree))
		local quote=Upgrades.NodeOffer(again,"VacuumCapacity1")
		assert(quote.status=="Locked" and quote.spendReason=="Buy Egg Vacuum first.",tostring(quote.spendReason))
		return "Granted once, re-bought after Rebirth"
	end)

	test("Junk in the new save fields reads leniently and never refuses the profile",function()
		local data=fixture(-9316):ToData()
		data.upgradeTree={EggSpeed="x",EggValue=99,Luck=-3,Bogus=2,Flock=0/0}
		data.gemUpgrades={CoinBoost=1e9,Nope=3,TimeSkip="y",AutoRoll=-1}
		data.gems,data.gemsEarned=-5,"lots"
		data.rebirths,data.rebirthSkips,data.missionTierLegacy=45,2.7,99
		data.rebirthChickenCredits={"Veteran1","Duck",5,"Nope"}
		data.passGemGifts={Bogus=true,AutoCollectEggs="yes"}
		data.autoRebirth,data.eggVacuum="maybe",1
		local t=Session.new(-9316,"Junk fixture",1)
		local ok,message=t:LoadData(data)
		assert(ok,message)
		assert(levelsText(t.upgradeTree)=="EggValue=4",levelsText(t.upgradeTree))
		assert(levelsText(t.gemUpgrades)=="CoinBoost=10",levelsText(t.gemUpgrades))
		assert(t.gems==0 and t.gemsEarned==0 and t.rebirthSkips==2 and t.missionTierLegacy==3,"Counts")
		assert(t.rebirths==Config.Rebirth.MaxRank,"Rank "..tostring(t.rebirths))
		assert(#t.rebirthChickenCredits==1 and t.rebirthChickenCredits[1]=="Veteran1" and next(t.passGemGifts)==nil,"Lists")
		assert(t.autoRebirth==true and t.eggVacuum==false,"Flags")
		return "Loaded with safe values"
	end)

	test("Revision 11 saves convert once: nearest tiers, research chains, running jobs and Gems",function()
		local s=fixture(-9317)
		s:AddPet("Duck",1)
		local fed=s:AddPet("Duck",1)
		fed.level,fed.cashLevels=2,1
		local old=s:ToData()
		old.dataRevision=11
		old.upgradeTree,old.gems,old.gemsEarned,old.gemUpgrades,old.rebirthSkips=nil,nil,nil,nil,nil
		old.rebirths=2
		old.eggSpeedLevel,old.incomeLevel,old.luck,old.capacity,old.rollSlotsUnlocked,old.plotSizeLevel=10,8,12,7,5,4
		old.research={completed={Start=true,L1=true,L2=true,A1=true,A2=true,AutoRoll=true,A14=true,S15=true,E13=true},
			jobs={{id="job1",nodeId="R1",startedAt=1,finishAt=999999999999,paid=1500}},revision=3,skipCredit=1000}
		local u=Session.new(-9317,"Converted fixture",1)
		local ok,message=u:LoadData(old)
		assert(ok and message=="Loaded and converted to the new Upgrades.",message)
		-- Egg Speed 2.5x and Army Size 7 sit halfway between two tiers: ties round up.
		-- The running Roll Speed job counts as finished; 5 chickens fill Flock Size 5.
		-- A finished guide keeps the Egg Vacuum as this run's Tools node (S14).
		assert(levelsText(u.upgradeTree)=="ArmySize=3, ChickenFeed=1, Damage=2, EggSpeed=4, EggVacuum=1, EggValue=3, Flock=2, "
			.."Luck=4, OfflineTime=1, RollSlot=4, RollSpeed=1",levelsText(u.upgradeTree))
		assert(u.capacity==8 and u.rollSlotsUnlocked==5 and u:FlockSize()==5,"Derived fields")
		assert(levelsText(u.gemUpgrades)=="AutoRoll=1, Rally=1",levelsText(u.gemUpgrades))
		assert(u.missionTierLegacy==1 and u.eggVacuum==false and u.researchEffects.eggVacuum==1,"Mission tier and Egg Vacuum")
		-- 1,000 s of unused skip time is 4 Gems; two ranks at double Gems are 2 x (50 + 60).
		assert(u.gems==224 and u.gemsEarned==224,"Gems "..u.gems)
		assert(veterans(u)==2,"Rebirth chickens "..veterans(u))
		assert(#u.research.jobs==0 and u.research.completed.R1 and u.research.skipCredit==0,"Research record")
		local summary=u.economyConversion
		assert(summary and summary.families==10 and summary.skipGems==4 and summary.rankGems==220,"Conversion summary")
		local pet=u.pets[fed.id]
		assert(pet and pet.level==2 and pet.cashLevels==1 and u:ChickenUpgradeEligibility(fed.id),"Fed chicken")
		local again=Session.new(-9317,"Reload fixture",1)
		ok,message=again:LoadData(u:ToData())
		assert(ok and message=="Loaded." and again.gems==224 and veterans(again)==2 and again.economyConversion==nil,
			"Converted twice: "..tostring(message))
		assert(levelsText(again.upgradeTree)==levelsText(u.upgradeTree),"Tree changed on reload")
		return "224 Gems, 10 families, 2 Veterans"
	end)

	test("Old saves missing board fields keep six podiums; a mid-guide save has no Egg Vacuum yet",function()
		local old=Session.new(-9318,"Old fixture",1):ToData()
		old.dataRevision=11
		old.upgradeTree=nil
		old.rollSlotsUnlocked,old.eggSpeedLevel,old.plotSizeLevel=nil,nil,nil
		local u=Session.new(-9318,"Converted fixture",1)
		local ok,message=u:LoadData(old)
		assert(ok,message)
		assert(levelsText(u.upgradeTree)=="RollSlot=5" and u.rollSlotsUnlocked==6,levelsText(u.upgradeTree))
		assert(u.gems==0 and u.missionTierLegacy==0 and u.researchEffects.eggVacuum==0 and next(u.gemUpgrades)==nil,"Extras")
		return "Six podiums kept"
	end)

	test("Upgrades and session snapshots carry the Luck summary, Gems, effects and Rally",function()
		local s=fixture(-9319)
		setTree(s,{Luck=1})
		local snapshot=Upgrades.new(nil,nil):Snapshot(s)
		assert(snapshot.families.Luck==1 and snapshot.nodes.Luck1.status=="Owned" and type(snapshot.badges.total)=="number",
			"Tree snapshot")
		assert(snapshot.luck.windowText and snapshot.luck.epicPlusChance and snapshot.luck.nextMultiplier,"Luck summary")
		local state=s:Snapshot(0)
		assert(state.gems==0 and state.effects.flockSize==3 and state.rally.readyAt and state.rally.activeUntil,
			"Session snapshot")
		return "Snapshot fields present"
	end)

	local passed=0
	for _,result in results do if result.passed then passed+=1 end end
	print(("[RebirthV2Checks] %d/%d passed"):format(passed,#results))
	for _,result in results do
		print((if result.passed then "  PASS " else "  FAIL ")..result.name.." — "..result.detail)
	end
	return results
end

return Checks
