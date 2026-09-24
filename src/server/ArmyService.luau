--!strict
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Catalog = require(Shared.PetCatalog)
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

function ArmyService.Favorite(session, petId)
	local pet = if type(petId)=="string" then session.pets[petId] else nil
	if not pet then return false, "Select an owned animal." end
	pet.favorite = not pet.favorite
	session:Touch()
	return true, if pet.favorite then "Chicken protected from selling." else "Chicken unprotected."
end

local function mergeEligible(session, pet)
	return pet and not pet.favorite and session:IsPetHome(pet.id)
		and not (session.incoming and session:FindSlot(pet.id))
		and (pet.level or 1) < Progression.Get(session.promotion).levelCap
end

-- The physical stand offers exact pairs. Prefer retaining an existing squad ID.
function ArmyService.MergeOptions(session, automatic: boolean?)
	if not Config.Features.Merging then return {} end
	local groups, options = {}, {}
	local protected={}
	-- Automation never changes a lineup the player explicitly chose. Manual
	-- stand merges retain their existing ability to merge selected home birds.
	if automatic and session.armySelection then
		for _,id in session.armySelection do protected[id]=true end
	end
	for _, pet in session.pets do
		if not protected[pet.id] and mergeEligible(session, pet) then
			local key = pet.species .. ":" .. (pet.level or 1)
			groups[key] = groups[key] or {}
			table.insert(groups[key], pet)
		end
	end
	for key, pets in groups do
		if #pets < 2 then continue end
		table.sort(pets, function(a, b)
			local sa, sb = session:FindSlot(a.id) or math.huge, session:FindSlot(b.id) or math.huge
			if sa ~= sb then return sa < sb end
			return a.id < b.id
		end)
		local a, b = pets[1], pets[2]
		local level = a.level or 1
		local petIds = {}
		for index=1,math.floor(#pets/2)*2 do petIds[index]=pets[index].id end
		table.insert(options, {key=key, firstId=a.id, secondId=b.id, species=a.species, level=level,
			pairs=math.floor(#pets / 2), petIds=petIds,
			beforeIncome=session:DisplayedPetIncome(a.species,a.stars,level)+session:DisplayedPetIncome(b.species,b.stars,level),
			afterIncome=session:DisplayedPetIncome(a.species,1,level+1)})
	end
	table.sort(options, function(a, b)
		if a.species ~= b.species then return Catalog[a.species].price < Catalog[b.species].price
			or (Catalog[a.species].price == Catalog[b.species].price and a.species < b.species) end
		return a.level < b.level
	end)
	return options
end

local function mergePair(session, firstId, secondId, expectedLevel)
	if type(firstId) ~= "string" or type(secondId) ~= "string" or #firstId>64 or #secondId>64 or firstId == secondId then
		return nil, "Choose two different owned chickens."
	end
	local a, b = session.pets[firstId], session.pets[secondId]
	if not mergeEligible(session, a) or not mergeEligible(session, b) then
		return nil, "Merge home chickens below your unlocked level cap. Kept and deployed chickens are protected."
	end
	local level = a.level or 1
	if a.species ~= b.species or level ~= (b.level or 1) or level ~= expectedLevel then
		return nil, "That pair changed. Match the same chicken and level at the stand."
	end
	return {first=a,second=b,level=level}
end

local function consumePair(session, pair)
	local a,b,level=pair.first,pair.second,pair.level
	-- No yield: consume one exact ID and upgrade the other. Existing save data
	-- already persists individual levels and removed IDs; no parallel star tier.
	session.pets[b.id] = nil
	a.investment = (a.investment or Rules.Investment(a.species,level)) + (b.investment or Rules.Investment(b.species,level))
	a.level = level + 1
end

function ArmyService.Merge(session, firstId, secondId, expectedLevel)
	if not Config.Features.Merging then return false, "Merging is unavailable." end
	local pair,reason=mergePair(session,firstId,secondId,expectedLevel)
	if not pair then return false,reason end
	consumePair(session,pair)
	local a=pair.first
	session.tutorial.upgraded = true
	session:RefreshArmy(); session:Touch()
	return true, Catalog[a.species].name .. " merged to level " .. a.level .. "!", a.id
end

function ArmyService.MergeAll(session, pairs)
	if not Config.Features.Merging then return false, "Merging is unavailable." end
	local limit=math.floor(Config.LegacyCollectionLimit/2)
	if type(pairs)~="table" or #pairs<1 or #pairs>limit then return false,"Choose ready pairs to merge." end
	local validated,seen,count={},{},0
	for index,request in pairs do
		count+=1
		if count>limit or type(index)~="number" or index%1~=0 or index<1 or index>#pairs or type(request)~="table" then
			return false,"Invalid merge selection."
		end
		local pair,reason=mergePair(session,request.firstId,request.secondId,request.level)
		if not pair then return false,reason end
		if seen[pair.first.id] or seen[pair.second.id] then return false,"Each chicken can only merge once." end
		seen[pair.first.id],seen[pair.second.id]=true,true
		validated[index]=pair
	end
	if count~=#pairs then return false,"Invalid merge selection." end
	-- Validate every original pair before consuming any. New results never enter this batch.
	local results={}
	for _,pair in validated do
		consumePair(session,pair)
		table.insert(results,{petId=pair.first.id,species=pair.first.species,level=pair.first.level})
	end
	session.tutorial.upgraded=true
	session:RefreshArmy();session:Touch()
	return true,"Merged "..count..(if count==1 then " pair!" else " pairs!"),{count=count,results=results}
end

function ArmyService.AutoMerge(session)
	if not Config.Features.Merging then return false, "Merging is unavailable." end
	if not session.loaded or session.closing or session.saveLost or not session:AutomaticEnabled("AutoMerge") then
		return false,"Auto Merge is off."
	end
	local pairs={}
	local limit=math.floor(Config.LegacyCollectionLimit/2)
	for _,option in ArmyService.MergeOptions(session,true) do
		for index=1,#option.petIds-1,2 do
			if #pairs>=limit then break end
			table.insert(pairs,{firstId=option.petIds[index],secondId=option.petIds[index+1],level=option.level})
		end
		if #pairs>=limit then break end
	end
	if #pairs==0 then return false,"No matching home chickens are ready." end
	-- One original-pair batch per server tick. Any new pair waits until the next
	-- scheduled call, and all usual favorite, location and rank checks still apply.
	return ArmyService.MergeAll(session,pairs)
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
 if session.coins<nextSlot.price then return false,"Not enough coins for the larger squad." end
 session.coins-=nextSlot.price;session.capacity=nextSlot.capacity;session.tutorial.upgraded=true
 -- A bought slot adds one best reserve without replacing the manual lineup.
 if session.armySelection~=nil then
  for _,id in session:AutoBestPetIds() do
   if not table.find(session.armySelection,id) then table.insert(session.armySelection,id);break end
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
 if session.coins<price then return false,"Not enough coins to upgrade egg value." end
 session.coins-=price;session.incomeLevel+=1;session.tutorial.upgraded=true;session:Touch()
 return true,"Every owned chicken now earns more coins, including your deployed squad!"
end

-- Older clients may still request this action. Progress now comes only from conquest.
function ArmyService.Promote(_session)
 return false,"Territories increase army capacity. Upgrade luck for better rolls; every chicken is available from the start."
end

return ArmyService
