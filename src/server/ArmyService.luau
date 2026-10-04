--!strict
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Catalog = require(Shared.PetCatalog)
local Giant = require(Shared.GiantChicken)
local sizeRandom = Random.new()
local Progression = require(Shared.Progression)
local ArmyService = {}

-- Selection is intent only, editable during combat. BattleService moves the rigs.

local function ownedIds(session,values)
	local capacity=session:Capacity()
	if type(values)~="table" or #values>capacity then return nil end
	local ids,seen,count={},{},0
	for index,id in values do
		count+=1
		if count>capacity or type(index)~="number" or index%1~=0
			or index<1 or index>#values or type(id)~="string" or #id>64
			or not session.pets[id] or seen[id] then return nil end
		ids[index]=id;seen[id]=true
	end
	if count~=#values then return nil end
	return ids
end

function ArmyService.SetSelection(session,petIds,expectedIds)
	local ids,expected=ownedIds(session,petIds),ownedIds(session,expectedIds)
	if not ids or not expected then return false,"Choose different chickens from your own flock." end
	if #session:FilterArmyIds(ids)<#ids then return false,"Only one Colossal (20+ studs) can be in your army." end
	local current=session:BestPetIds()
	if #expected~=#current then return false,"Your army changed. Choose again." end
	for index,id in current do
		if expected[index]~=id then return false,"Your army changed. Choose again." end
	end
	-- Atomic and non-yielding: never accept client power, capacity, stats or ownership.
	session.armySelection=ids
	session:RefreshArmy();session:Touch()
	return true,"Army updated. Your manual lineup will stay selected."
end

function ArmyService.SelectBest(session)
	session.armySelection=nil
	session:RefreshArmy();session:Touch()
	return true,"Best chickens selected. Automatic selection is on."
end

local function formationSlot(session,slot)
	return type(slot)=="number" and slot%1==0 and slot>=1 and slot<=session.researchEffects.formations
end

function ArmyService.SaveFormation(session,slot,name,expectedIds,expectedRevision)
	if not formationSlot(session,slot) then return false,"Research another formation slot first." end
	if session.research.revision~=expectedRevision then return false,"Your formations changed. Try again." end
	if type(name)~="string" or #name<1 or #name>40 or not utf8.len(name) or name:find("%c") then
		return false,"Use a formation name between 1 and 40 characters."
	end
	local expected=ownedIds(session,expectedIds);local selected=session:BestPetIds()
	if not expected or #expected~=#selected then return false,"Your army changed. Choose again." end
	for i,id in selected do if expected[i]~=id then return false,"Your army changed. Choose again." end end
	if #selected==0 then return false,"Select some chickens before saving a formation." end
	-- Personal names are only returned to their owner; never broadcast as world text.
	session.research.formations[tostring(slot)]={name=name,petIds=table.clone(selected)}
	session.research.revision+=1;session:Touch()
	return true,"Formation saved."
end

function ArmyService.ApplyFormation(session,slot,expectedIds,expectedRevision)
	if not formationSlot(session,slot) or session.research.revision~=expectedRevision then
		return false,"Your formations changed. Try again."
	end
	local preset=session.research.formations[tostring(slot)]
	if not preset then return false,"Save this formation first." end
	local owned={}
	for _,id in preset.petIds do if session.pets[id] then table.insert(owned,id) end end
	local ids=session:FilterArmyIds(owned)
	if #ids==0 then return false,"No chickens from this formation remain in your flock." end
	local ok,message=ArmyService.SetSelection(session,ids,expectedIds)
	if not ok then return ok,message end
	local skipped=#preset.petIds-#ids
	return true,"Formation applied."..(if skipped>0 then " "..skipped.." unavailable chickens skipped." else "")
end

function ArmyService.Favorite(session, petId)
	local pet = if type(petId)=="string" then session.pets[petId] else nil
	if not pet then return false, "Select an owned animal." end
	pet.favorite = not pet.favorite
	session:Touch()
	return true, if pet.favorite then "Chicken protected from selling." else "Chicken unprotected."
end

function ArmyService.UpgradeChicken(session,petId,expectedLevel,expectedPrice)
	if not session.loaded or session.closing or session.saveLost then return false,"Your flock is not ready yet." end
	local allowed,reason=session:ChickenUpgradeEligibility(petId)
	if not allowed then return false,reason end
	local pet=session.pets[petId]
	local level=pet.level or 1
	local price=Rules.ChickenUpgradePrice(pet.species,level)
	if expectedLevel~=level or expectedPrice~=price then return false,"The upgrade changed. Try again." end
	if not price or session.coins<price then return false,"Not enough cash to upgrade this chicken." end
	local canSpend,spendReason=session:CanSpendCash(price)
	if not canSpend then return false,spendReason end
	local investment=(pet.investment or Rules.Investment(pet.species,level))+price
	if investment~=investment or investment<0 or investment>1e12 then
		return false,"This upgrade exceeds the saved investment limit."
	end
	-- Quote, ownership and eligibility are checked before this non-yielding purchase.
	-- Replayed requests retain the old expected level and cannot charge twice.
	session.coins-=price
	pet.level,pet.investment=level+1,investment
	session.tutorial.upgraded=true
	session:RefreshArmy();session:Touch()
	return true,Catalog[pet.species].name.." upgraded to Lv. "..pet.level.."!",pet.id
end

local function mergeEligible(session, pet)
	return pet and not pet.favorite and session:IsPetHome(pet.id)
		and not (session.incoming and session:FindSlot(pet.id))
		and (pet.level or 1) < Progression.Get(session.promotion).levelCap
end

-- Exact triples; keep a selected squad ID so the survivor retains its place.
function ArmyService.MergeOptions(session, automatic: boolean?)
	if not Config.Features.Merging then return {} end
	if session:Count()-2<session:StarterFlockMinimum() then return {} end
	local groups,options,protected={},{},{}
	if automatic and session.armySelection then
		for _,id in session.armySelection do protected[id]=true end
	end
	for _,pet in session.pets do
		if not protected[pet.id] and mergeEligible(session,pet) then
			local key=pet.species..":"..(pet.stars or 1)..":"..(pet.level or 1)
			groups[key]=groups[key] or {};table.insert(groups[key],pet)
		end
	end
	for key,pets in groups do
		if #pets<3 then continue end
		table.sort(pets,function(a,b)
			local sa,sb=session:FindSlot(a.id) or math.huge,session:FindSlot(b.id) or math.huge
			if sa~=sb then return sa<sb end
			return a.id<b.id
		end)
		local a,b,c=pets[1],pets[2],pets[3]
		local level,stars=a.level or 1,a.stars or 1
		local ids={};for _,pet in pets do table.insert(ids,pet.id) end
		local before,after=Rules.Stats(a.species,stars,level),Rules.Stats(a.species,stars,level+1)
		local income=session:DisplayedPetIncome(a.species,stars,level)
		table.insert(options,{key=key,firstId=a.id,secondId=b.id,thirdId=c.id,
			species=a.species,stars=stars,level=level,count=#pets,merges=math.floor(#pets/3),petIds=ids,
			price=Rules.MergePrice(a.species,level),
			inputIncome=income,beforeIncome=income*3,
			inputEggRate=session:PetEggRate(a.species,stars,level),
			afterEggRate=session:PetEggRate(a.species,stars,level+1),
			afterIncome=session:DisplayedPetIncome(a.species,stars,level+1),
			beforeDps=before.damage/before.interval,afterDps=after.damage/after.interval})
	end
	table.sort(options,function(a,b)
		if a.species~=b.species then return Catalog[a.species].price<Catalog[b.species].price
			or (Catalog[a.species].price==Catalog[b.species].price and a.species<b.species) end
		if a.level~=b.level then return a.level<b.level end
		return a.stars<b.stars
	end)
	return options
end

local function mergeTriple(session,firstId,secondId,thirdId,expectedLevel,expectedPrice)
	if type(firstId)~="string" or type(secondId)~="string" or type(thirdId)~="string"
		or #firstId>64 or #secondId>64 or #thirdId>64
		or firstId==secondId or firstId==thirdId or secondId==thirdId then
		return nil,"Choose three different owned chickens."
	end
	local a,b,c=session.pets[firstId],session.pets[secondId],session.pets[thirdId]
	for _,pet in {a or false,b or false,c or false} do
		if not mergeEligible(session,pet) then
			return nil,"Choose unprotected home chickens below your merge level cap."
		end
	end
	local level,stars=a.level or 1,a.stars or 1
	if a.species~=b.species or a.species~=c.species or stars~=(b.stars or 1) or stars~=(c.stars or 1)
		or level~=(b.level or 1) or level~=(c.level or 1) or level~=expectedLevel then
		return nil,"Those chickens changed. Match the same chicken and level."
	end
	local price=Rules.MergePrice(a.species,level)
	if expectedPrice~=price then return nil,"The fusion price changed. Choose again." end
	local investment=(a.investment or Rules.Investment(a.species,level))
		+(b.investment or Rules.Investment(b.species,level))+(c.investment or Rules.Investment(c.species,level))
	if investment~=investment or investment<0 or investment>1e12 then
		return nil,"This merge exceeds the saved investment limit."
	end
	return {first=a,second=b,third=c,level=level,investment=investment,price=price}
end

local function consumeTriple(session,triple)
	local a,b,c,level=triple.first,triple.second,triple.third,triple.level
	local giantSize=Giant.SizeFromRoll(Catalog[a.species].rarity,sizeRandom:NextNumber(),
		math.max(a.giantSize or 0,b.giantSize or 0,c.giantSize or 0))
	-- Validate everything before mutation, without yielding. Existing saves already
	-- store the retained ID, level and investment; no new progression currency.
	a.investment=triple.investment
	session.pets[b.id],session.pets[c.id]=nil,nil
	if session.armySelection then
		for index=#session.armySelection,1,-1 do
			local id=session.armySelection[index]
			if id==b.id or id==c.id then table.remove(session.armySelection,index) end
		end
	end
	a.level=level+1
	a.giantSize=giantSize
end

function ArmyService.Merge(session,firstId,secondId,thirdId,expectedLevel,expectedPrice)
	if not Config.Features.Merging then return false,"Merging is unavailable." end
	local triple,reason=mergeTriple(session,firstId,secondId,thirdId,expectedLevel,expectedPrice)
	if not triple then return false,reason end
	if session:Count()-2<session:StarterFlockMinimum() then return false,"Keep your starter army for the first mission." end
	local canSpend,spendReason=session:CanSpendCash(triple.price)
	if not canSpend then return false,spendReason end
	-- The fee is a service cost, not refundable chicken purchase investment.
	session.coins-=triple.price
	consumeTriple(session,triple)
	local a=triple.first
	session.tutorial.upgraded=true
	session:RefreshArmy();session:Touch()
	return true,Giant.Label(a.giantSize).." · "..Catalog[a.species].name.."!",a.id
end

function ArmyService.MergeAll(session,triples)
	if not Config.Features.Merging then return false,"Merging is unavailable." end
	local limit=math.floor(Config.LegacyCollectionLimit/3)
	if type(triples)~="table" or #triples<1 or #triples>limit then return false,"Choose matching groups to merge." end
	local validated,seen,count,total={},{},0,0
	for index,request in triples do
		count+=1
		if count>limit or type(index)~="number" or index%1~=0 or index<1 or index>#triples or type(request)~="table" then
			return false,"Invalid merge selection."
		end
		local triple,reason=mergeTriple(session,request.firstId,request.secondId,request.thirdId,request.level,request.expectedPrice)
		if not triple then return false,reason end
		for _,pet in {triple.first,triple.second,triple.third} do
			if seen[pet.id] then return false,"Each chicken can only merge once." end
			seen[pet.id]=true
		end
		validated[index]=triple
		total+=triple.price
	end
	if count~=#triples then return false,"Invalid merge selection." end
	if session:Count()-2*count<session:StarterFlockMinimum() then return false,"Keep your starter army for the first mission." end
	local canSpend,spendReason=session:CanSpendCash(total)
	if not canSpend then return false,spendReason end
	session.coins-=total
	local results={}
	for _,triple in validated do
		consumeTriple(session,triple)
		table.insert(results,{petId=triple.first.id,species=triple.first.species,level=triple.first.level,giantSize=triple.first.giantSize})
	end
	session.tutorial.upgraded=true;session:RefreshArmy();session:Touch()
	return true,"Merged "..count.." groups!",{count=count,results=results,price=total}
end

function ArmyService.AutoMerge(session)
	if not Config.Features.Merging or not Config.Features.AutoMerging then return false,"Auto Merge is unavailable." end
	if not session.loaded or session.closing or session.saveLost or not session:AutomaticEnabled("AutoMerge") then
		return false,"Auto Merge is off."
	end
	local triples={}
	local limit=math.floor(Config.LegacyCollectionLimit/3)
	for _,option in ArmyService.MergeOptions(session,true) do
		for index=1,#option.petIds-2,3 do
			if #triples>=limit then break end
			table.insert(triples,{firstId=option.petIds[index],secondId=option.petIds[index+1],
				thirdId=option.petIds[index+2],level=option.level,expectedPrice=option.price})
		end
		if #triples>=limit then break end
	end
	if #triples==0 then return false,"No matching home chickens are ready." end
	return ArmyService.MergeAll(session,triples)
end

function ArmyService.Sell(session, petIds, _sparesOnly, expectedTotal)
	-- The client flag is only legacy request shape. Protection is unconditional.
	if type(petIds)~="table" or #petIds==0 or #petIds>Config.LegacyCollectionLimit then return false,"Select reserve chickens to sell." end
	local seen,total,count={},0,0
	for index,id in petIds do
		count+=1
		if type(index)~="number" or index%1~=0 or index<1 or index>#petIds then return false,"Invalid chicken selection." end
		if type(id)~="string" or seen[id] then return false,"Invalid chicken selection." end
		local allowed,reason=session:SaleEligibility(id)
		if not allowed then return false,reason end
		local pet=session.pets[id]
		seen[id]=true
		total+=Rules.SellValue(pet.investment or Rules.Investment(pet.species,pet.level))
	end
	if count~=#petIds then return false,"Invalid chicken selection." end
	if type(expectedTotal)~="number" or expectedTotal~=total then return false,"Your sale value changed. Choose again." end
	local minimum=session:StarterFlockMinimum()
	if session:Count()-count<minimum then
		return false,"Keep "..minimum.." "..(if minimum==1 then "chicken" else "chickens").." for your first mission."
	end
	if not session:CanCredit(total,"sale") then return false,"Spend some cash before selling these chickens." end
	-- Validate the whole batch before mutation; this transaction never yields.
	for id in seen do session.pets[id]=nil end
	session:RefreshArmy()
	session:Credit(total,"sale")
	return true,"Sold "..count.." reserve "..(if count==1 then "chicken" else "chickens").." for "..math.floor(total).." coins.",{count=count,total=total}
end

function ArmyService.Expand(session)
 local nextSlot=session:NextSlot()
 if not nextSlot then return false,"Your squad can already deploy "..session:Capacity().." chickens." end
 if not nextSlot.unlocked then return false,nextSlot.requirement.." first." end
 local canSpend,reason=session:CanSpendCash(nextSlot.price,"ArmySize")
 if not canSpend then return false,reason end
 session.coins-=nextSlot.price;session.capacity=nextSlot.capacity;session.tutorial.upgraded=true
 -- A bought slot adds one best reserve without replacing the manual lineup.
 if session.armySelection~=nil then
  session.armySelection=session:BestPetIds()
  for _,id in session:AutoBestPetIds() do
   if not table.find(session.armySelection,id) then
    local proposed=table.clone(session.armySelection);table.insert(proposed,id)
    if #session:FilterArmyIds(proposed)==#proposed then session.armySelection=proposed;break end
   end
  end
 end
 session:RefreshArmy();session:Touch()
 return true,"Deployment capacity increased to "..session:Capacity().." chickens."
end

function ArmyService.UpgradeIncome(session)
 local upgrade=session:GlobalUpgrade("Income")
 if not upgrade then return false,"Egg value is fully upgraded." end
 if not upgrade.unlocked then return false,upgrade.requirement.." to improve egg value again." end
 local price=upgrade.price
 local canSpend,reason=session:CanSpendCash(price)
 if not canSpend then return false,reason end
 session.coins-=price;session.incomeLevel+=1;session.tutorial.upgraded=true;session:Touch()
 return true,"Every owned chicken now earns more coins, including your deployed squad!"
end

-- Older clients may still request promotion; cash upgrades do not require conquest.
function ArmyService.Promote(_session)
 return false,"Promotion is unavailable. Buy available upgrades with cash; camps are not required."
end

return ArmyService
