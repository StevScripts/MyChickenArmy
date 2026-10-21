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
local Army=require(Server.ArmyService)
local TreeMigrations=require(Server.TreeMigrations)
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
	for _,pet in session.pets do if Catalog.RetiredSpecies[pet.species] or not Catalog[pet.species] then count+=1 end end
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

	-- October 21 owner decision: the round Veteran Corps placeholders are retired;
	-- every chicken is a voxel model. Each maps to the chicken whose stats it copied.
	test("Rebirth chickens are retired: none in the catalog, each Veteran maps to an equal voxel chicken",function()
		assert(#Catalog.RebirthOrder==0,"Rebirth chickens "..#Catalog.RebirthOrder)
		local count=0
		for id,species in Catalog.RetiredSpecies do
			count+=1
			assert(Catalog[id]==nil and not table.find(Catalog.Order,id),id.." is still in the catalog")
			assert(table.find(Catalog.Order,species) and Catalog[species].weight>0,id.." maps to "..species)
		end
		assert(count==Config.Rebirth.MaxRank,"Retired "..count)
		for rank=1,Config.Rebirth.MaxRank do assert(RebirthChickens.Species(rank)==nil,"Species "..rank) end
		-- Each tier key maps to the chicken that still has that tier's exact stats.
		for id,key in {Veteran1="Chunky",Veteran3="Bucket",Veteran5="Viking",Veteran7="Knight",Veteran10="Dragon",
			Veteran13="Rainbow",Veteran16="IceDuck",Veteran20="StormDuck",Veteran30="StormDuck"} do
			assert(Catalog.RetiredSpecies[id]==key,id.." -> "..tostring(Catalog.RetiredSpecies[id]))
		end
		assert(Catalog.Dragon.income==160 and Catalog.Rainbow.income==268,"Legendary tier targets")
		return "30 Veterans retired, Sergeant Scratch -> "..Catalog[Catalog.RetiredSpecies.Veteran3].name
	end)

	test("Tree values, mutation unlocks and default effects",function()
		assert(Rules.EggUnitValue(0)==4 and Rules.EggUnitValue(4)==20,"Egg unit value "..Rules.EggUnitValue(4))
		assert(Rules.LuckWindow(4).multiplier==3,"Luck tier 4")
		-- S9c: mutations are tree hexes (Golden..Cosmic in Order), not Rebirth ranks.
		assert(#Tree.Families.Mutation.tiers==#Mutations.Order and (Mutations.Defs.Shadow::any).unlockRank==nil,"Mutation tree hexes")
		assert(Tree.Effects({Mutation=2},{}).mutations==2,"Mutation tier effect")
		local effects=Tree.Effects({},{})
		assert(effects.flockSize==3 and effects.timeSkipMinutes==5 and effects.callArmy==1,"Flock, Time Skip, Call Army")
		assert(effects.keepTiers==0 and effects.autoRebirth==0 and effects.rebirthChickenChance==0.01,"Gem defaults")
		assert(effects.armySlots==0 and effects.feedMaxLevel==0,"Army slot and Feed level defaults")
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
		-- 2,000 Coins left, 1,200 kept for Army Size 4. October 21: the guide's starter
		-- chicken is FREE (StarterRecruitPrice 0), so nothing is held for it any more.
		assert(s:StarterCashReserve()==1200,"Reserve "..s:StarterCashReserve())
		ok,message=upgrades:BuyNode(s,"EggSpeed2",Tree.Price("EggSpeed",2,0))
		assert(not ok and message=="Keep 1,200 Coins for Army Size I in Upgrades.",message)
		refused("This upgrade changed. Try again.",upgrades:BuyNode(s,"EggSpeed2",1))
		refused("Egg Speed I is already yours.",upgrades:BuyNode(s,"EggSpeed1",Tree.Price("EggSpeed",1,0)))
		ok,message=upgrades:BuyNode(s,"ArmySize1",1200)
		assert(ok and s.capacity==4 and s.coins==800 and s:StarterArmyReserve()==0,message)
		refused("Buy Army Size II first.",upgrades:BuyNode(s,"ArmySize3",Tree.Price("ArmySize",3,0)))
		refused("Buy Chicken Feed in Upgrades > Tools first.",s:ChickenUpgradeEligibility((next(s.pets))))
		return "Reserve, quotes and order hold"
	end)

	test("Rebirth 1 resets the run and pays Gems and Time Skip Coins (no chicken); progress stays",function()
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
		assert(quote.nextChicken==nil and quote.multiplierNext==2 and quote.enemyScaleNext==1,"Quote rewards")
		assert(quote.timeSkipMinutes==5 and quote.cashLevels==2 and quote.kingRequired==false,"Quote details")
		local count=s:Count()
		local ok,message,receipt=Rebirth.Rebirth(s,0,NO_SERVER,false)
		assert(ok and message=="Rebirth complete: Rebirth 1",message)
		assert(s.rebirths==1 and receipt.rank==1 and receipt.gems==50 and not receipt.skip and not receipt.automatic,"Receipt")
		assert(next(s.upgradeTree)==nil and s.capacity==3 and s.luck==0 and s.eggSpeedLevel==0 and s:FlockSize()==3,
			"Tree left: "..levelsText(s.upgradeTree))
		assert(s.gems==50 and s.gemsEarned==50,"Gems "..s.gems)
		assert(s:Count()==count and receipt.petId==nil and receipt.species==nil,"A Rebirth chicken was granted")
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

	test("Gem shop: the reference order in rows of two, rows open by rank, buys use the exact quote",function()
		-- Stevin's order (October 20, S7b), as in Drop a Fruit's shop: two cards per row.
		local order={"RollSpeed","ExtraLuck","VacuumCapacity","AutoRoll","FlockSlot","ArmySlot","CoinBoost","AutoRebirth",
			"TimeSkip","MoreGems","KeepUpgrades","Rally","MutationLuck","OfflineCoins","ArmyPower"}
		assert(table.concat(GemCatalog.Order,",")==table.concat(order,","),table.concat(GemCatalog.Order,","))
		local previousRank=0
		for index,id in order do
			local upgrade=GemCatalog.Upgrades[id]
			assert(upgrade.row==math.ceil(index/2) and upgrade.column==(index-1)%2+1,
				id.." at row "..upgrade.row..", column "..upgrade.column)
			assert(upgrade.unlockRank>=previousRank,id.." opens before the row above it")
			previousRank=upgrade.unlockRank
		end
		assert(GemCatalog.Upgrades.FlockSlot.unlockRank==1 and GemCatalog.Upgrades.ArmySlot.unlockRank==1
			and GemCatalog.Upgrades.CoinBoost.unlockRank==2,"Slot and Coin Boost rows")
		local s=fixture(-9307)
		s.rebirths,s.gems=1,50
		local snapshot=GemUpgrades.Snapshot(s)
		assert(#snapshot.order==#GemCatalog.Order and not snapshot.autoRebirth.owned,"Snapshot")
		assert(snapshot.items.TimeSkip.status=="Locked" and snapshot.items.TimeSkip.level==1
			and snapshot.items.FlockSlot.status=="Available" and snapshot.items.CoinBoost.status=="Locked","Row status")
		refused("Reach Rebirth 2 to unlock Coin Boost.",GemUpgrades.Buy(s,"CoinBoost",0,10))
		refused("Reach Rebirth 3 to unlock Time Skip.",GemUpgrades.Buy(s,"TimeSkip",1,20))
		refused("This upgrade changed. Try again.",GemUpgrades.Buy(s,"AutoRoll",0,99))
		refused("Choose a Gem Upgrade.",GemUpgrades.Buy(s,"Nope",0,1))
		local ok,message=GemUpgrades.Buy(s,"AutoRoll",0,15)
		assert(ok and message=="Auto Roll unlocked!" and s.researchEffects.autoRoll==1 and s.gems==35,message)
		refused("Auto Roll is at its maximum.",GemUpgrades.Buy(s,"AutoRoll",1,nil))
		s.rebirths=2
		ok,message=GemUpgrades.Buy(s,"AutoRebirth",0,25)
		assert(ok and s.autoRebirth==true and s.researchEffects.autoRebirth==1,message)
		ok,message=GemUpgrades.Buy(s,"CoinBoost",0,10)
		assert(ok and message=="Coin Boost is now level 1!" and s.gems==0,message)
		near(s.researchEffects.coinBoost,0.1,"Coin Boost")
		refused("Need 15 more Gems.",GemUpgrades.Buy(s,"CoinBoost",1,15))
		-- Coin Boost multiplies egg Coins only, on top of the Rebirth 2 multiplier (x3).
		near(s:EarnedAmount(100,"eggs",true),330,"Egg Coins")
		near(s:EarnedAmount(100,"battle",true),100,"Battle Coins")
		refused("Invalid Auto Rebirth setting.",GemUpgrades.SetAutoRebirth(s,"yes"))
		ok,message=GemUpgrades.SetAutoRebirth(s,false)
		assert(ok and message=="Auto Rebirth off." and s.autoRebirth==false,message)
		refused("Unlock Auto Rebirth in Gem Upgrades first.",GemUpgrades.SetAutoRebirth(fixture(-9308),true))
		return "Order, locks, quotes, prices and effects hold"
	end)

	test("Time Skip and More Gems raise the next Rebirth's rewards",function()
		local s=fixture(-9309)
		s.rebirths,s.gems=3,200
		local fiveMinutes=Rebirth.TimeSkipCoins(s)
		local ok,message=GemUpgrades.Buy(s,"TimeSkip",1,20)
		assert(ok and s.researchEffects.timeSkipMinutes==10,message)
		local tenMinutes=Rebirth.TimeSkipCoins(s)
		assert(math.abs(tenMinutes-2*fiveMinutes)<=1,fiveMinutes.." then "..tenMinutes)
		ok,message=GemUpgrades.Buy(s,"MoreGems",0,25)
		assert(ok,message)
		local quote=Rebirth.Quote(s)
		-- floor((40 + 40) x 1.1) Gems for Rebirth 4.
		assert(quote.gemsNext==88 and quote.timeSkipCoins==tenMinutes,
			tostring(quote.gemsNext).." Gems, Time Skip "..tostring(quote.timeSkipCoins))
		return "Time Skip "..fiveMinutes.." -> "..tenMinutes.." Coins"
	end)

	test("+1 Flock Slot and +1 Army Slot add to the tree's sizes and stay through Rebirths and saves",function()
		local s=fixture(-9320)
		s.rebirths,s.gems=1,100
		for _=1,3 do s:AddPet("Chunky",1) end -- six chickens, so a fourth layer counts
		local before=Rebirth.TimeSkipCoins(s)
		local ok,message=GemUpgrades.Buy(s,"FlockSlot",0,20)
		assert(ok and s:FlockSize()==4,message)
		ok,message=GemUpgrades.Buy(s,"ArmySlot",0,25)
		assert(ok and s.capacity==4 and s:Capacity()==4,message)
		assert(Rebirth.TimeSkipCoins(s)>before,"Time Skip ignored the Gem Flock slot")
		setTree(s,{ArmySize=1,Flock=2})
		assert(s.capacity==5 and s:FlockSize()==6,"On top of the tree: "..s.capacity.." and "..s:FlockSize())
		local nextSlot=s:NextSlot()
		assert(nextSlot and nextSlot.tier==2 and nextSlot.capacity==7,"Next Army Size tier")
		s.entitlements.BiggerArmy=true
		assert(s:Capacity()==5+Shop.ArmyBonus and s:NextSlot().displayCapacity==7+Shop.ArmyBonus,"Bigger Army")
		s.entitlements.BiggerArmy=nil
		s.coins=Rebirth.Cost(2)
		ok,message=Rebirth.Rebirth(s,1,NO_SERVER,false)
		assert(ok and s.capacity==4 and s:FlockSize()==4,"After Rebirth: "..s.capacity.." and "..s:FlockSize())
		local t=Session.new(-9320,"Restore fixture",1)
		ok,message=t:LoadData(s:ToData())
		assert(ok and t.capacity==4 and t:FlockSize()==4 and t.gemUpgrades.FlockSlot==1 and t.gemUpgrades.ArmySlot==1,
			tostring(message))
		return "Flock 4 and Army 4 after a Rebirth"
	end)

	test("Chicken Feed past Lv 10 follows feedMaxLevel (set by hand): cap, +25% eggs, quotes, Rebirth",function()
		local s=fixture(-9321)
		setTree(s,{ChickenFeed=1})
		local pet=s:AddPet("Knight",1)
		pet.level,pet.cashLevels=10,9
		local function entry()
			for _,shown in s:Snapshot(0).pets do if shown.id==pet.id then return shown end end
			return nil
		end
		assert(s:LevelCap()==Config.MaxPetLevel and Rules.LevelCap(nil)==Config.MaxPetLevel,"Base cap")
		refused("Max level reached.",s:ChickenUpgradeEligibility(pet.id))
		local shown=entry()
		assert(shown and shown.levelCap==10 and shown.upgradePrice==nil,"Snapshot at the cap")
		-- What S9c's Feed Max Level tiers will set; any source adds up.
		s.researchEffects=table.clone(s.researchEffects)
		s.researchEffects.feedMaxLevel=4
		assert(s:LevelCap()==14 and s:ChickenUpgradeEligibility(pet.id),"Cap 14")
		local nine=Rules.ChickenUpgradePrice("Knight",9) :: number
		local ten=Rules.ChickenUpgradePrice("Knight",10)
		assert(ten==math.ceil(nine*1.25) and Rules.ChickenUpgradePrice("Knight",11)==math.ceil(nine*1.25*3.125),"Quotes")
		assert(Rules.ChickenUpgradePrice("Knight",19)~=nil and Rules.ChickenUpgradePrice("Knight",20)==nil,"Quote range")
		shown=entry()
		assert(shown and shown.levelCap==14 and shown.upgradePrice==ten,"Snapshot under the cap")
		s.coins=ten :: number
		local ok,message=Army.UpgradeChicken(s,pet.id,10,ten)
		assert(ok and pet.level==11 and pet.cashLevels==10 and s.coins==0,message)
		near(Rules.EggRate("Knight",1,11),Rules.EggRate("Knight",1,10)*1.25,"Lv 11 eggs")
		near(Rules.EggRate("Knight",1,20),Rules.EggRate("Knight",1,10)*1.25^10,"Lv 20 eggs")
		near(Rules.EggRate("Knight",1,10),Rules.EggRate("Knight",1,9)*2,"Lv 10 still doubles")
		near(Rules.Stats("Knight",1,20).hp/Rules.Stats("Knight",1,1).hp,1+19*Config.PetCombatPerLevel,"Lv 20 health")
		s.researchEffects.feedMaxLevel=99
		assert(s:LevelCap()==Config.PetLevelLimit,"Limit")
		s.researchEffects.feedMaxLevel=-3
		assert(s:LevelCap()==Config.MaxPetLevel,"Negative extra")
		-- Levels past 10 are Feed levels, so a Rebirth takes them back like the rest.
		s.coins=Rebirth.Cost(1)
		ok,message=Rebirth.Rebirth(s,0,NO_SERVER,false)
		assert(ok and pet.level==1 and pet.cashLevels==nil,"After Rebirth: Lv "..pet.level)
		return "Cap 10 -> 14 -> 20; Lv 11 bought for "..ten.." Coins"
	end)

	test("Saves keep levels up to 20 and big Feed investments; a higher level reads as 20",function()
		local s=fixture(-9322)
		local fed=s:AddPet("Knight",1)
		fed.level,fed.cashLevels,fed.investment=15,5,5e12
		local over=s:AddPet("Duck",1)
		over.level,over.cashLevels=25,15
		local t=Session.new(-9322,"Restore fixture",1)
		local ok,message=t:LoadData(s:ToData())
		assert(ok,message)
		local a,b=t.pets[fed.id],t.pets[over.id]
		assert(a.level==15 and a.cashLevels==5 and a.investment==5e12,"Lv 15 chicken")
		assert(b.level==Config.PetLevelLimit and b.cashLevels==15,"Lv 25 chicken read as "..b.level)
		return "Lv 15 kept, Lv 25 read as 20"
	end)

	test("Feed is limited by the Coins cap, not 1e12 (Galaxy Overlord past Lv 7)",function()
		local s=fixture(-9323)
		setTree(s,{ChickenFeed=1})
		local pet=s:AddPet("StormDuck",1)
		pet.level,pet.cashLevels=7,6
		pet.investment=Rules.Investment("StormDuck",7)
		local price=Rules.ChickenUpgradePrice("StormDuck",7) :: number
		s.coins=price
		local ok,message=Army.UpgradeChicken(s,pet.id,7,price)
		assert(ok and pet.level==8 and pet.investment>1e12,message)
		return "Lv 8 for "..price.." Coins"
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
		assert(receipt.petId==nil,"A Rebirth chicken was granted")
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

	test("Retired Rebirth chickens: no grant, no credit, no podium swap",function()
		local s=fixture(-9314)
		local count=s:Count()
		s.CollectionLimit=function(self) return self:Count() end
		assert(RebirthChickens.Grant(s,3)==nil and #s.rebirthChickenCredits==0,"Credit at the cap")
		s.CollectionLimit=nil
		assert(RebirthChickens.Grant(s,3)==nil and s:Count()==count,"Granted with room")
		s.rebirthChickenCredits={"Veteran3"}
		assert(#RebirthChickens.Deliver(s)==0 and s:Count()==count,"Delivered a retired credit")
		local rng=Random.new(7)
		s.researchEffects=table.clone(s.researchEffects)
		s.researchEffects.rebirthChickenChance=1
		s.rebirths=30
		for _=1,50 do assert(RebirthChickens.MaybeReplace(s,"Duck",rng,1)=="Duck","A podium offer was replaced") end
		return "Nothing granted, credited or offered"
	end)

	test("Saved Veterans load as their voxel chicken; Rebirth Chicken Odds is refunded in Gems",function()
		local s=fixture(-9340)
		local scratch=s:AddPet("Duck",1)
		local data=s:ToData()
		for _,pet in data.pets do
			if pet.id==scratch.id then pet.species,pet.level,pet.investment="Veteran3",4,0 end
		end
		data.armySelection={scratch.id}
		data.gems,data.gemsEarned=10,500
		data.gemUpgrades={RebirthChickenOdds=3,AutoRoll=1}
		data.rebirthChickenCredits={"Veteran4"}
		data.discovered={Veteran3=true,Duck=true}
		local t=Session.new(-9340,"Veteran fixture",1)
		local ok,message=t:LoadData(data)
		assert(ok,message)
		local pet=t.pets[scratch.id]
		assert(pet and pet.species=="Bucket" and pet.level==4 and pet.investment==0,"Sergeant Scratch -> "..tostring(pet and pet.species))
		assert(veterans(t)==0 and #t.unrecognizedPets==0,"A Veteran stayed")
		-- 30 + 60 + 100 Gems for three levels; the level itself is gone.
		assert(t.gems==200 and t.gemsEarned==500,"Gems "..t.gems)
		assert(levelsText(t.gemUpgrades)=="AutoRoll=1",levelsText(t.gemUpgrades))
		assert(#t.rebirthChickenCredits==0 and t.discovered.Bucket,"Credits or Index")
		local again=Session.new(-9340,"Veteran reload fixture",1)
		ok,message=again:LoadData(t:ToData())
		assert(ok and again.gems==200 and again.pets[scratch.id].species=="Bucket","Refunded twice: "..tostring(message))
		return "Veteran3 -> Robo-Cluck Lv 4, +190 Gems once"
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
		assert(#t.rebirthChickenCredits==0,"Retired chicken credits are dropped")
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
		assert(#t.rebirthChickenCredits==0 and next(t.passGemGifts)==nil,"Lists")
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
		assert(veterans(u)==0,"Rebirth chickens "..veterans(u))
		assert(#u.research.jobs==0 and u.research.completed.R1 and u.research.skipCredit==0,"Research record")
		local summary=u.economyConversion
		assert(summary and summary.families==10 and summary.skipGems==4 and summary.rankGems==220,"Conversion summary")
		local pet=u.pets[fed.id]
		assert(pet and pet.level==2 and pet.cashLevels==1 and u:ChickenUpgradeEligibility(fed.id),"Fed chicken")
		local again=Session.new(-9317,"Reload fixture",1)
		ok,message=again:LoadData(u:ToData())
		assert(ok and message=="Loaded." and again.gems==224 and veterans(again)==0 and again.economyConversion==nil,
			"Converted twice: "..tostring(message))
		assert(levelsText(again.upgradeTree)==levelsText(u.upgradeTree),"Tree changed on reload")
		return "224 Gems, 10 families, no Veterans"
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

	test("Tree versions: saves carry the version, Gold Rate keeps its count, no step runs twice",function()
		assert(fixture(-9330):ToData().upgradeTreeVersion==TreeMigrations.Version,"Saved version")
		-- Step 1 against S9c's table (every 10/8/7/6/5): live II (every 6) becomes III.
		local values={1,2,3,4}
		assert(TreeMigrations.GoldRateTier(1,{10,8,7,6,5},values)==1
			and TreeMigrations.GoldRateTier(2,{10,8,7,6,5},values)==3,"S9c table")
		assert(TreeMigrations.GoldRateTier(0,{10,8,7,6,5},values)==0,"No Gold Rate")
		assert(TreeMigrations.GoldRateTier(1,{10,8,6},{1,2})==1 and TreeMigrations.GoldRateTier(2,{10,8,6},{1,2})==2,"Live table")
		-- Tripwire: a new Gold table needs step 1 switched on in the same commit.
		local every=Config.GoldRolls.Every
		assert((every[1]==10 and every[2]==8 and every[3]==6) or TreeMigrations.Version>=1,
			"Config.GoldRolls.Every changed: set TreeMigrations.Version = 1 (step 1 keeps live Gold Rate counts)")
		local function loaded(version)
			local s=fixture(-9331)
			setTree(s,{GoldMachine=1,GoldRate=2})
			local data=s:ToData()
			data.upgradeTreeVersion=version
			local t=Session.new(-9331,"Restore fixture",1)
			local ok,message=t:LoadData(data)
			assert(ok,message)
			return t.upgradeTree.GoldRate
		end
		local tiers={}
		for index,entry in Tree.Families.GoldRate.tiers do tiers[index]=entry.value end
		local moved=if TreeMigrations.Version>=1 then TreeMigrations.GoldRateTier(2,every,tiers) else 2
		assert(loaded(nil)==moved and loaded(0)==moved,"An older save: Gold Rate "..tostring(loaded(nil)))
		assert(loaded(TreeMigrations.Version)==2 and loaded(TreeMigrations.Version+1)==2,"A current or newer save runs no step")
		return "Version "..TreeMigrations.Version..", live Gold Rate II loads as "..moved
	end)

	test("mutationKeep: rank unlocks survive S9c's Mutation tree, set once and never raised",function()
		local function load(rank,keep,tier)
			local s=fixture(-9332)
			s.rebirths=rank
			local data=s:ToData()
			data.mutationKeep=keep
			if tier then data.upgradeTree.Mutation=tier end
			local t=Session.new(-9332,"Restore fixture",1)
			local ok,message=t:LoadData(data)
			assert(ok,message)
			return t
		end
		if not Tree.Families.Mutation then
			-- Before S9c nothing is derived, so later saves keep what they have now.
			assert(Session.new(-9333,"New profile",1).mutationKeep==nil,"New profile")
			assert(load(12,nil).mutationKeep==nil and load(12,3).mutationKeep==3 and load(12,"x").mutationKeep==nil,
				"Before the Mutation family")
			return "Inactive until S9c's Mutation family"
		end
		assert(Session.new(-9333,"New profile",1).mutationKeep==0,"New profiles buy Golden in the tree")
		for _,case in {{0,1},{1,2},{4,2},{5,3},{9,3},{10,4},{30,4}} do
			local t=load(case[1],nil)
			assert(t.mutationKeep==case[2] and t.upgradeTree.Mutation==case[2],
				"Rebirth "..case[1].." -> "..tostring(t.mutationKeep).." / tier "..tostring(t.upgradeTree.Mutation))
		end
		local kept=load(12,2)
		assert(kept.mutationKeep==2 and kept.upgradeTree.Mutation==2,"A saved value never rises")
		assert(load(1,2,4).upgradeTree.Mutation==4,"A bought tier above it stays")
		assert(load(5,"junk").mutationKeep==3 and load(0,9).mutationKeep==#Mutations.Order,"Junk and range")
		local again=Session.new(-9334,"Round trip",1)
		assert(again:LoadData(kept:ToData()) and again.mutationKeep==2,"Round trip")
		return "Rebirth 0/1/5/10 keeps 1/2/3/4 mutations"
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
