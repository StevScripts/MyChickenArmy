-- Disposable server-VM fixtures. No live sessions, DataStore, remotes or map edits.
-- Run only after the caller has checked the synced module versions in a fresh VM.
-- Egg milestones below are synthetic committed facts; this is not a movement/VFX test.
local Server = game.ServerStorage.PetRoll
local Shared = game.ReplicatedStorage.PetRoll.Shared
local Session = require(Server.PlayerSession)
local Rolls = require(Server.RollService)
local Army = require(Server.ArmyService)
local Upgrades = require(Server.UpgradeService)
local Research = require(Server.ResearchService)
local ResearchRules = require(Shared.ResearchRules)
local ResearchCatalog = require(Shared.ResearchCatalog)
local Guide = require(Shared.TutorialGuide)
local Rules = require(Shared.Rules)
local Config = require(Shared.Config)
local checks = {}
local serial = 0
local rolls = Rolls.new()
local upgrades = Upgrades.new({}, rolls) -- Portable upgrades do not call the world.

local function check(name, ok)
	table.insert(checks, {name=name, ok=ok==true})
	assert(ok, name)
end

local function fresh()
	serial += 1
	local session = Session.new(-84000-serial, "Starter army fixture", 1)
	session.loaded, session.saveStatus, session.rollSlotLimit = true, "session", 8
	return session
end

local function ids(session)
	local result = {}
	for id in session.pets do table.insert(result, id) end
	table.sort(result)
	return result
end

local function restore(session)
	local loaded = fresh()
	assert(loaded:LoadData(session:ToData()))
	return loaded
end

local function buyStarter(session)
	assert(rolls:Roll(session, 100))
	local offer = session.offer
	assert(offer.starter and offer.price==600)
	local ok, _, petId = rolls:Buy(session, offer.id, 110)
	assert(ok)
	return petId
end

local function armyPurchase(session)
	local quote = upgrades:Offers(session).ArmySize
	return upgrades:Buy(nil, session, "ArmySize", quote.level, quote.price)
end

local function quoteTriple(values, offset)
	return {firstId=values[offset], secondId=values[offset+1], thirdId=values[offset+2],
		level=1, expectedPrice=Rules.MergePrice("Duck", 1)}
end

local s = fresh()
check("new analytics guide version", Guide.Version=="cluck-3-starter-army")
check("three starters and three selected slots", s:Count()==3 and #s:BestPetIds()==3 and s.capacity==3)
check("three basic free level-one chickens", #Config.StarterFlock==3 and (function()
	for _, pet in s.pets do
		if pet.species~="Duck" or pet.level~=1 or pet.investment~=0 then return false end
	end
	return true
end)())
check("fresh cohort has no pre-rolled offer", s.tutorial.starterArmy and not s.tutorial.emptyStart and s.offer==nil and next(s.offers)==nil)
check("unchanged wallet and independently reserved purchases", s.coins==2400 and s:StarterRecruitPending() and s:StarterCashReserve()==1800 and s:StarterArmyReserve()==1200)
check("ownership does not complete Roll or Recruit", not Guide.Facts(s:Snapshot(0)).Roll and not Guide.Facts(s:Snapshot(0)).Recruit and Guide.Resolve(s:Snapshot(0)).id=="Roll")
check("only the extra six hundred is discretionary", s:CanSpendCash(600) and not s:CanSpendCash(601) and not s:CanSpendCash(601, "Unknown"))
check("each required purchase can spend its own earmark", s:CanSpendCash(600, "StarterRecruit") and s:CanSpendCash(1200, "ArmySize"))

-- Normal route teaches income once, then reaches combat from starting cash alone.
check("free first roll succeeds", rolls:Roll(s, 10))
local first = s.offer
check("first offer is the six hundred basic recruit", first.starter and first.species=="Duck" and first.level==1 and first.price==600 and first.chance==1 and #s.offers==1 and s.coins==2400)
check("roll advances to recruit despite existing army", Guide.Resolve(s:Snapshot(10)).id=="Recruit" and Guide.Facts(s:Snapshot(10)).Roll)
check("reveal cannot be bought or rerolled early", not rolls:Buy(s, first.id, 10) and not rolls:Roll(s, 10) and s:Count()==3 and s.coins==2400)
check("reroll remains a free starter offer", rolls:Roll(s, 20) and s.offer.starter and s.offer.price==600 and s.coins==2400)
check("discarded offer cannot be purchased", not rolls:Buy(s, first.id, 30) and s:Count()==3 and s.coins==2400)
local accepted = s.offer.id
local bought, _, recruitId = rolls:Buy(s, accepted, 30)
check("starter buy adds exactly the fourth bird", bought and s:Count()==4 and s.coins==1800 and s.tutorial.bought and not s:StarterRecruitPending())
check("recruit investment reflects actual cash", s.pets[recruitId].investment==600 and Rules.SellValue(s.pets[recruitId].investment)==300)
check("only Army Size cash remains reserved", s:StarterCashReserve()==1200 and s:StarterArmyReserve()==1200)
check("duplicate recruit is rejected without mutation", not rolls:Buy(s, accepted, 30) and s:Count()==4 and s.coins==1800)
check("first collection follows recruitment", Guide.Resolve(s:Snapshot(30)).id=="Collect")
s.tutorial.collectedEggs = true
local carrying = s:Snapshot(30)
carrying.eggs = {carriedCount=1, carriedValue=4}
check("one collected egg is enough for the teaching sale", Guide.Resolve(carrying).id=="Sell")
s.tutorial.soldEggs = true
check("sale goes directly to expansion without farming", Guide.Resolve(s:Snapshot(30)).id=="Expand")
local armyQuote = upgrades:Offers(s).ArmySize
check("first Army Size purchase uses its reserved budget", armyPurchase(s) and s.capacity==4 and s.coins==600 and s:StarterCashReserve()==0)
check("stale Army Size quote cannot buy another tier", not upgrades:Buy(nil,s,"ArmySize",armyQuote.level,armyQuote.price) and s.capacity==4 and s.coins==600)
check("automatic filled lineup goes straight to camp", Guide.Resolve(s:Snapshot(30)).id=="Deploy")
check("manual empty lineup is accepted", Army.SetSelection(s, {}, s:BestPetIds()))
check("manual lineup receives Select guidance", Guide.Resolve(s:Snapshot(30)).id=="Select")
check("Select Best advances to deployment", Army.SelectBest(s) and Guide.Resolve(s:Snapshot(30)).id=="Deploy")
check("completed income lesson never loops when bag is empty", Guide.Facts(s:Snapshot(30)).Collect and Guide.Facts(s:Snapshot(30)).Sell and Guide.Resolve(s:Snapshot(30)).id=="Deploy")
local rejoined = restore(s)
check("rejoin preserves paid fourth bird and completed income lesson", rejoined:Count()==4 and rejoined.coins==600 and rejoined:StarterCashReserve()==0 and Guide.Resolve(rejoined:Snapshot(30)).id=="Deploy")
check("ordinary economy returns after discounted purchase", rolls:Roll(rejoined, 100) and not rejoined.offer.starter and rejoined.offer.price==Rules.RecruitPrice(rejoined.offer.species,rejoined.offer.level))

-- Purchases may happen out of order; the other earmark remains available.
local reordered = fresh()
check("Army Size first leaves recruit reserve", armyPurchase(reordered) and reordered.coins==1200 and reordered:StarterCashReserve()==600 and reordered:StarterRecruitPending())
check("Army Size first still asks for a roll", Guide.Resolve(reordered:Snapshot(0)).id=="Roll")
buyStarter(reordered)
check("reordered purchases have identical total cost", reordered:Count()==4 and reordered.capacity==4 and reordered.coins==600 and reordered:StarterCashReserve()==0)
local exact = fresh()
exact.coins = 1800
buyStarter(exact)
check("exact budget supports both required purchases", armyPurchase(exact) and exact.coins==0 and exact:Count()==4)
local shortage = fresh()
shortage.coins = 1799
check("own earmark cannot consume the other purchase's cash", not shortage:CanSpendCash(600,"StarterRecruit") and not shortage:CanSpendCash(1200,"ArmySize"))
assert(rolls:Roll(shortage,100))
check("starter transaction preserves Army Size reserve at shortfall", not rolls:Buy(shortage,shortage.offer.id,110) and shortage.coins==1799 and shortage:Count()==3)
check("Army Size transaction preserves recruit reserve at shortfall", not armyPurchase(shortage) and shortage.coins==1799 and shortage.capacity==3)
local pass = fresh()
pass.entitlements.BiggerArmy = true
check("effective paid capacity removes redundant Army reserve", pass:Capacity()>=4 and pass:StarterArmyReserve()==0 and pass:StarterCashReserve()==600)
buyStarter(pass)
pass.tutorial.collectedEggs, pass.tutorial.soldEggs = true, true
check("existing effective slots skip redundant expansion", Guide.Resolve(pass:Snapshot(110)).id=="Deploy")

-- Skipping, save loading and strong existing chickens never bypass the guarantee.
local skipped = fresh()
skipped.tutorial.guideSkipped = true
check("skip hides guidance but keeps budget protection", Guide.Resolve(skipped:Snapshot(0))==nil and not skipped:CanSpendCash(601))
local resume = restore(skipped)
check("saved cohort and reserve survive rejoin without added birds", resume.tutorial.starterArmy and resume.tutorial.guideSkipped and resume:Count()==3 and resume.coins==2400 and resume:StarterCashReserve()==1800)
resume.tutorial.guideSkipped = false
check("resuming unfinished purchase returns to Roll", Guide.Resolve(resume:Snapshot(0)).id=="Roll")
resume.pets[ids(resume)[1]].level = 3
resume.rollSlotCount, resume.guaranteedLuckRolls = 8, 3
resume.entitlements.DoubleLuck, resume.paidRandomRestricted = true, true
check("starter forced to basic level one regardless matching upgrades", rolls:Roll(resume,10) and resume.offer.level==1 and resume.offer.species=="Duck" and resume.offer.price==600 and #resume.offers==1)
check("starter roll does not consume paid guarantee progress", resume.guaranteedLuckRolls==3)
local beforeBuyRejoin = restore(resume)
check("unsaved offer disappears but guaranteed purchase survives rejoin", beforeBuyRejoin.offer==nil and beforeBuyRejoin:StarterRecruitPending() and beforeBuyRejoin:Count()==3 and beforeBuyRejoin:StarterCashReserve()==1800)

-- Every ordinary cash sink must preserve both tutorial earmarks.
for _, key in {"EggSpeed","PlotSize","EggValue","Luck","RollSlots"} do
	local session = fresh()
	local quote = upgrades:Offers(session)[key]
	session.coins = quote.price+1799
	local shown = upgrades:Offers(session)[key]
	check(key.." UI shows a reserve shortfall without camp gating", shown.unlocked and not shown.canSpend and #shown.spendReason>0)
	check(key.." rejects one-dollar reserve shortfall atomically", not upgrades:Buy(nil,session,key,quote.level,quote.price) and session.coins==quote.price+1799)
	session.coins = quote.price+1800
	check(key.." accepts spending above exact reserve boundary", upgrades:Buy(nil,session,key,quote.level,quote.price) and session.coins==1800)
end
local discretionary = fresh()
local plotQuote = upgrades:Offers(discretionary).PlotSize
check("starting discretionary cash still buys affordable plot upgrade", upgrades:Buy(nil,discretionary,"PlotSize",plotQuote.level,plotQuote.price) and discretionary.coins==1920 and discretionary:StarterCashReserve()==1800)
buyStarter(discretionary)
check("optional plot purchase cannot force another egg sale", armyPurchase(discretionary) and discretionary.coins==120 and discretionary:Count()==4)
local research = fresh()
local node = ResearchCatalog.Nodes.A1
research.coins = node.price+1799
check("research cannot consume required-purchase budget", not Research.Start(research,"A1",research.research.revision,node.price,ResearchRules.Duration(node,research.researchEffects),100) and #research.research.jobs==0 and research.coins==node.price+1799)
for _, purchase in {
	{name="legacy income", buy=Army.UpgradeIncome, price=Config.IncomePrices[1]},
	{name="legacy luck", buy=function(session) return rolls:UpgradeLuck(session) end, price=Config.LuckPrices[1]},
} do
	local session = fresh()
	session.coins = purchase.price+1799
	check(purchase.name.." cannot bypass reserve", not purchase.buy(session) and session.coins==purchase.price+1799)
end
local leveling = fresh()
local levelId = ids(leveling)[1]
local levelPrice = Rules.ChickenUpgradePrice("Duck",1)
leveling.coins = levelPrice+1799
check("individual chicken upgrade preserves required cash", not Army.UpgradeChicken(leveling,levelId,1,levelPrice) and leveling.pets[levelId].level==1 and leveling.coins==levelPrice+1799)
local ordinary = fresh()
buyStarter(ordinary)
assert(rolls:Roll(ordinary,200))
local ordinaryOffer = ordinary.offer
ordinary.coins = ordinaryOffer.price+1199
check("later normal recruits cannot spend the Army Size reserve", not ordinaryOffer.starter and not rolls:Buy(ordinary,ordinaryOffer.id,210) and ordinary:Count()==4 and ordinary.coins==ordinaryOffer.price+1199)
ordinary.coins = ordinaryOffer.price+1200
check("normal recruit above remaining reserve remains purchasable", rolls:Buy(ordinary,ordinaryOffer.id,210) and ordinary:Count()==5 and ordinary.coins==1200 and ordinary:StarterCashReserve()==1200)

-- Removing free birds cannot recreate the collect/sell grind or mint refunds.
local protected = fresh()
assert(Army.SetSelection(protected, {}, protected:BestPetIds()))
local starterIds = ids(protected)
check("free starter chickens cannot be sold below floor three", not Army.Sell(protected,{starterIds[1]},true,0) and protected:Count()==3 and protected.coins==2400)
check("starter triple cannot be fused below floor three", not Army.Merge(protected,starterIds[1],starterIds[2],starterIds[3],1,Rules.MergePrice("Duck",1)) and protected:Count()==3 and protected.coins==2400)
check("unavailable starter fusion is not advertised", #Army.MergeOptions(protected)==0)
local paidId = buyStarter(protected)
check("discounted chicken cannot be resold below floor four", not Army.Sell(protected,{paidId},true,300) and protected:Count()==4 and protected.coins==1800)
check("four-bird merge cannot remove the tutorial army", not Army.Merge(protected,starterIds[1],starterIds[2],starterIds[3],1,Rules.MergePrice("Duck",1)) and protected:Count()==4 and protected.coins==1800)
local extra = protected:AddPet("Duck",1)
check("genuine surplus remains sellable", Army.Sell(protected,{extra.id},true,Rules.SellValue(extra.investment)) and protected:Count()==4)
local mergeBudget = fresh()
for _=1,2 do mergeBudget:AddPet("Duck",1) end
local mergeIds = ids(mergeBudget)
local fee = Rules.MergePrice("Duck",1)
mergeBudget.coins = fee+1799
check("otherwise valid fusion cannot consume cash reserve", not Army.Merge(mergeBudget,mergeIds[1],mergeIds[2],mergeIds[3],1,fee) and mergeBudget:Count()==5 and mergeBudget.coins==fee+1799)
mergeBudget.coins = fee+1800
check("surplus fusion remains available above the floor and reserve", Army.Merge(mergeBudget,mergeIds[1],mergeIds[2],mergeIds[3],1,fee) and mergeBudget:Count()==3 and mergeBudget.coins==1800)
local batch = fresh()
buyStarter(batch)
for _=1,2 do batch:AddPet("Duck",1) end
batch.coins = 10000
local batchIds = ids(batch)
check("batch fusion validates the final combined flock floor", not Army.MergeAll(batch,{quoteTriple(batchIds,1),quoteTriple(batchIds,4)}) and batch:Count()==6 and batch.coins==10000)
protected.tutorial.guideCompleted = true
local all = ids(protected)
local refund = 0
for _, id in all do refund += Rules.SellValue(protected.pets[id].investment) end
local balance = protected.coins
check("completed mission releases flock restriction with actual refunds", Army.Sell(protected,all,true,refund) and protected:Count()==0 and protected.coins==balance+refund and refund==300)
local early = fresh()
early.tutorial.guideCompleted = true
check("early mission completion releases all reserved budget", early:StarterCashReserve()==0 and early:StarterFlockMinimum()==0 and not early:StarterRecruitPending() and early:CanSpendCash(2400))
check("early completion cannot mint a late discounted recruit", rolls:Roll(early,10) and not early.offer.starter and early.offer.price==Rules.RecruitPrice(early.offer.species,early.offer.level))

-- Existing profiles keep their exact cohort, ownership and balance; no migration grants.
local saved = fresh():ToData()
saved.tutorial = {rolled=true,bought=true}
table.remove(saved.pets)
saved.coins, saved.capacity, saved.luck = 9876, 5, 1
local established = fresh()
check("preexisting cohort loads without the new policy", established:LoadData(saved) and not established.tutorial.starterArmy and not established.tutorial.emptyStart and established:StarterCashReserve()==0)
check("preexisting flock cash and upgrades stay unchanged", established:Count()==2 and established.coins==9876 and established.capacity==5 and established.luck==1)
local invalid = established:ToData()
invalid.coins = -1
check("invalid save does not replace existing progress", not established:LoadData(invalid) and established:Count()==2 and established.coins==9876)
local oldEmptyData = fresh():ToData()
oldEmptyData.pets, oldEmptyData.tutorial = {}, {emptyStart=true}
oldEmptyData.coins = 600
local oldEmpty = fresh()
check("old empty-start save stays empty with its six hundred reserve", oldEmpty:LoadData(oldEmptyData) and oldEmpty:Count()==0 and oldEmpty.coins==600 and not oldEmpty.tutorial.starterArmy and oldEmpty:StarterCashReserve()==600)
check("old empty-start guide still begins with a roll", Guide.Resolve(oldEmpty:Snapshot(0)).id=="Roll")
buyStarter(oldEmpty)
check("old empty-start recruit does not grant three more birds or army reserve", oldEmpty:Count()==1 and oldEmpty.coins==0 and oldEmpty:StarterCashReserve()==0 and oldEmpty:StarterFlockMinimum()==1)
local oldPurchased = restore(oldEmpty)
check("legacy purchased save preserves one real chicken", oldPurchased:Count()==1 and oldPurchased.coins==0 and oldPurchased.tutorial.emptyStart and not oldPurchased.tutorial.starterArmy)

return {passed=#checks, checks=checks, guideVersion=Guide.Version,
	scope="Disposable unsaved server objects and synthetic egg milestones; no DataStore or live players"}
