-- Disposable server-VM fixtures only. Does not use DataStore or live sessions.
local S=game.ServerStorage.PetRoll
local H=game.ReplicatedStorage.PetRoll.Shared
local Session=require(S.PlayerSession)
local Rolls=require(S.RollService)
local Army=require(S.ArmyService)
local Upgrades=require(S.UpgradeService)
local Research=require(S.ResearchService)
local ResearchRules=require(H.ResearchRules)
local ResearchCatalog=require(H.ResearchCatalog)
local Guide=require(H.TutorialGuide)
local Rules=require(H.Rules)
local Config=require(H.Config)
local checks={}
local function check(name,ok)
 table.insert(checks,{name=name,ok=ok==true})
 assert(ok,name)
end
local function fresh()
 local s=Session.new(-83003,"Starter fixture",1)
 s.loaded=true;s.saveStatus="session";s.rollSlotLimit=8
 return s
end
local rolls=Rolls.new()
local upgrades=Upgrades.new(nil,rolls)
local s=fresh()
check("empty yard, selection and podium",s:Count()==0 and #s:BestPetIds()==0 and next(s.slots)==nil and s.offer==nil and next(s.offers)==nil)
check("starting cash retained; first recruit reserved",s.coins==2400 and s:StarterCashReserve()==600)
check("first objective targets free lever",Guide.Resolve(s:Snapshot(0)).id=="Roll")
s.tutorial.guideSkipped=true
local blocked,message=rolls:UpgradeLuck(s)
check("skip cannot bypass cash reserve",not blocked and s.coins==2400 and message:find("first chicken")~=nil)
check("affordable army upgrade remains available",Army.Expand(s) and s.capacity==4 and s.coins==1200)
local p=upgrades:Offers(s).PlotSize
check("affordable plot upgrade remains available",upgrades:Buy(nil,s,"PlotSize",p.level,p.price) and s.coins==720)
local node=ResearchCatalog.Nodes.A1
local ok=Research.Start(s,"A1",s.research.revision,node.price,ResearchRules.Duration(node,s.researchEffects),100)
check("research cannot spend reserved cash",not ok and s.coins==720 and #s.research.jobs==0)
local researchOffer=Research.Snapshot(s,100).offers.A1
check("research UI explains reserved cash",researchOffer.status=="Unaffordable" and researchOffer.spendReason:find("first chicken")~=nil)
local loaded=fresh()
check("empty rejoin retains protection and upgrades",loaded:LoadData(s:ToData()) and loaded:Count()==0 and loaded.coins==720 and loaded.capacity==4 and loaded:StarterCashReserve()==600 and loaded.tutorial.guideSkipped)
loaded.tutorial.guideSkipped=false
check("empty rejoin still targets roll",Guide.Resolve(loaded:Snapshot(0)).id=="Roll")
loaded.rollSlotCount=8
loaded.entitlements.DoubleLuck=true;loaded.paidRandomRestricted=true;loaded.guaranteedLuckRolls=3
check("first roll accepted",rolls:Roll(loaded,10))
local first=loaded.offer
check("guaranteed affordable starter; free roll",first.starter and first.species=="Duck" and first.price==600 and first.chance==1 and #loaded.offers==1 and loaded.coins==720)
check("starter roll preserves paid guarantee progress",loaded.guaranteedLuckRolls==3)
check("first roll is measured separately",Guide.Facts(loaded:Snapshot(10)).Roll and not Guide.Facts(loaded:Snapshot(10)).Recruit)
check("reveal cannot be purchased early",not rolls:Buy(loaded,first.id,10) and loaded.coins==720)
check("reroll cannot run during reveal",not rolls:Roll(loaded,10))
check("reroll remains affordable until bought",rolls:Roll(loaded,20) and loaded.offer.price==600 and loaded.coins==720)
check("discarded offer cannot be bought",not rolls:Buy(loaded,first.id,30))
local offerId=loaded.offer.id
check("buy uses reserved cash once",rolls:Buy(loaded,offerId,30) and loaded.coins==120 and loaded:Count()==1 and loaded:StarterCashReserve()==0)
check("duplicate purchase rejected atomically",not rolls:Buy(loaded,offerId,30) and loaded.coins==120 and loaded:Count()==1)
check("guide advances to actual egg collection",Guide.Resolve(loaded:Snapshot(30)).id=="Collect" and loaded:Income()>0)
local petId=next(loaded.pets)
check("starter refund tracks actual investment",loaded.pets[petId].investment==600 and Rules.SellValue(loaded.pets[petId].investment)==300)
loaded.armySelection={};loaded:RefreshArmy()
check("deselection cannot bypass last chicken protection",not Army.Sell(loaded,{petId},true,300) and loaded:Count()==1)
local restored=fresh()
check("purchased rejoin retains one real chicken",restored:LoadData(loaded:ToData()) and restored:Count()==1 and restored.coins==120 and restored:StarterCashReserve()==0)
check("second roll uses ordinary economy",rolls:Roll(restored,40) and not restored.offer.starter and restored.offer.price>=Rules.RecruitPrice("Duck",1))
restored.tutorial.collectedEggs=true
local state=restored:Snapshot(40);state.eggs={carriedCount=1,carriedValue=4}
check("one chicken can reach first sale",Guide.Resolve(state).id=="Sell")
restored.tutorial.soldEggs=true;restored.offer=nil;restored.offers={}
check("grow flock before empty army-slot purchase",Guide.Resolve(restored:Snapshot(40)).id=="Grow")
for i=1,3 do restored:AddPet("Duck",1) end
restored.capacity=3;restored:RefreshArmy();restored.coins=1200
check("four birds then teach expansion",Guide.Resolve(restored:Snapshot(40)).id=="Expand")
check("expansion works with income established",Army.Expand(restored) and restored.coins==0)
check("manual lineup gets Select step",Guide.Resolve(restored:Snapshot(40)).id=="Select")
check("Select Best leads to camp",Army.SelectBest(restored) and Guide.Resolve(restored:Snapshot(40)).id=="Deploy")
local batch=fresh();local ids={}
for i=1,2 do local pet=batch:AddPet("Duck",1);table.insert(ids,pet.id) end
batch.armySelection={};batch:RefreshArmy()
local total=0 for _,id in ids do total+=Rules.SellValue(batch.pets[id].investment) end
check("batch sale cannot empty starter flock",not Army.Sell(batch,ids,true,total) and batch:Count()==2)
check("partial reserve sale remains available",Army.Sell(batch,{ids[1]},true,total/2) and batch:Count()==1)
batch.tutorial.guideCompleted=true
check("last-chicken protection ends with first mission",Army.Sell(batch,{ids[2]},true,total/2) and batch:Count()==0)
for _,key in {"EggSpeed","PlotSize","EggValue","ArmySize","Luck","RollSlots"} do
 local x=fresh();local quote=upgrades:Offers(x)[key]
 x.coins=quote.price+599
 local shown=upgrades:Offers(x)[key]
 check(key.." UI reserves first recruit",shown.unlocked and shown.canSpend==false and shown.spendReason:find("first chicken")~=nil)
 check(key.." rejects reserve shortfall",not upgrades:Buy(nil,x,key,quote.level,quote.price) and x.coins==quote.price+599)
 x.coins=quote.price+600
 check(key.." accepts exact reserve boundary",upgrades:Buy(nil,x,key,quote.level,quote.price) and x.coins==600)
end
for _,buy in {Army.Expand,Army.UpgradeIncome,function(x) return rolls:UpgradeLuck(x) end} do
 local x=fresh();x.coins=0
 check("legacy action cannot spend nonexistent cash",not buy(x) and x.coins==0)
end
local exact=fresh();exact.coins=600
rolls:Roll(exact,100)
check("exact reserve still buys income source",rolls:Buy(exact,exact.offer.id,110) and exact.coins==0 and exact:Income()>0)
local legacy=fresh();legacy.tutorial={rolled=true,bought=true}
for _,species in {"Duck","Duck","Mallard"} do local pet=legacy:AddPet(species,1);pet.investment=0 end
legacy.coins=9876;legacy.capacity=5;legacy.luck=1;legacy:RefreshArmy()
local old=legacy:ToData();local returning=fresh()
check("old profile loads without new onboarding policy",returning:LoadData(old) and not returning.tutorial.emptyStart and returning:StarterCashReserve()==0)
check("old flock, cash and upgrades preserved",returning:Count()==3 and returning.coins==9876 and returning.capacity==5 and returning.luck==1)
local bad=legacy:ToData();bad.coins=-1
check("invalid save cannot wipe existing progress",not returning:LoadData(bad) and returning:Count()==3 and returning.coins==9876)
return {passed=#checks,checks=checks,guideVersion=Guide.Version,scope="Disposable server fixtures; no DataStore"}
