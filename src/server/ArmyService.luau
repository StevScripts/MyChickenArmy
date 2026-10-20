--!strict
local TextService = game:GetService("TextService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Catalog = require(Shared.PetCatalog)
local Currency = require(Shared.CurrencyLimits)
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
	return true,"Army updated."
end

function ArmyService.SelectBest(session)
	session.armySelection=nil
	session:RefreshArmy();session:Touch()
	return true,"Best chickens selected."
end

local function formationSlot(session,slot)
	return type(slot)=="number" and slot%1==0 and slot>=1 and slot<=session.researchEffects.formations
end

local function formationReady(session,slot,expectedIds,expectedRevision)
	if not formationSlot(session,slot) then return false,"Research another formation slot first." end
	if session.research.revision~=expectedRevision then return false,"Your formations changed. Try again." end
	local expected=ownedIds(session,expectedIds);local selected=session:BestPetIds()
	if not expected or #expected~=#selected then return false,"Your army changed. Choose again." end
	for i,id in selected do if expected[i]~=id then return false,"Your army changed. Choose again." end end
	if #selected==0 then return false,"Select some chickens before saving a formation." end
	return true,"",selected
end

-- Typed names are stored only after Roblox text filtering (shown back as
-- research.formations[slot].name). A filter failure stores "Formation N".
local function filteredName(session,slot,name)
	local fallback="Formation "..slot
	if type(session.userId)~="number" or session.userId<=0 then return fallback end
	local ok,result=pcall(function()
		local filtered=TextService:FilterStringAsync(name,session.userId,Enum.TextFilterContext.PrivateChat)
		return filtered:GetNonChatStringForUserAsync(session.userId)
	end)
	-- Saved names must still pass ResearchRules.Read (1-40 bytes, valid UTF-8).
	if not ok or type(result)~="string" or #result<1 or #result>40 or not utf8.len(result) or result:find("%c") then return fallback end
	return result
end

function ArmyService.SaveFormation(session,slot,name,expectedIds,expectedRevision)
	if type(name)~="string" or #name<1 or #name>40 or not utf8.len(name) or name:find("%c") then
		return false,"Use a formation name between 1 and 40 characters."
	end
	local ready,reason=formationReady(session,slot,expectedIds,expectedRevision)
	if not ready then return false,reason end
	local stored=filteredName(session,slot,name) -- Yields.
	if session.closing or session.saveLost then return false,"Your flock is not ready yet." end
	local selected
	ready,reason,selected=formationReady(session,slot,expectedIds,expectedRevision)
	if not ready or not selected then return false,reason end
	-- Personal names are only returned to their owner; never broadcast as world text.
	session.research.formations[tostring(slot)]={name=stored,petIds=table.clone(selected)}
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
	if not pet then return false, "Select one of your chickens." end
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
	if not price or session.coins<price then return false,"Not enough coins to upgrade this chicken." end
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
	-- October 14: Rebirth removes levels bought with cash (fusion and roll levels stay).
	pet.cashLevels=(pet.cashLevels or 0)+1
	session.tutorial.upgraded=true
	session:RefreshArmy();session:Touch()
	return true,Catalog[pet.species].name.." upgraded to Lv. "..pet.level.."!",pet.id
end

-- October 20: Fuse is removed (archive/fuse-20261020). Saved giantPity and
-- fusionUnlocked still load; nothing here creates Giants any more.

function ArmyService.Sell(session, petIds, _sparesOnly, expectedTotal)
	-- The client flag is only legacy request shape. Protection is unconditional.
	-- October 20 Sell menu: one bulk request may hold the whole storage.
	local limit=math.max(Config.LegacyCollectionLimit,session:CollectionLimit())
	if type(petIds)~="table" or #petIds==0 or #petIds>limit then return false,"Select reserve chickens to sell." end
	-- One protection context for the whole batch where the session offers it.
	local context=if session.SaleContext then session:SaleContext() else nil
	local seen,total,count={},0,0
	for index,id in petIds do
		count+=1
		if type(index)~="number" or index%1~=0 or index<1 or index>#petIds then return false,"Invalid chicken selection." end
		if type(id)~="string" or seen[id] then return false,"Invalid chicken selection." end
		local allowed,reason=session:SaleEligibility(id,context)
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
	if not session:CanCredit(total,"sale") then return false,"Spend some coins before selling these chickens." end
	-- Validate the whole batch before mutation; this transaction never yields.
	for id in seen do session.pets[id]=nil end
	session:RefreshArmy()
	session:Credit(total,"sale")
	-- The Sell screen's toast, as in the reference: "Sold 2 chickens for 8 Coins".
	return true,"Sold "..count.." "..(if count==1 then "chicken" else "chickens").." for "..Currency.Text(total),{count=count,total=total}
end

function ArmyService.Expand(session)
 local nextSlot=session:NextSlot()
 if not nextSlot then return false,"Your army already has "..session:Capacity().." slots." end
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
 return true,"Army Size increased to "..session:Capacity().." chickens."
end

function ArmyService.UpgradeIncome(session)
 local upgrade=session:GlobalUpgrade("Income")
 if not upgrade then return false,"Egg value is fully upgraded." end
 if not upgrade.unlocked then return false,upgrade.requirement.." to improve egg value again." end
 local price=upgrade.price
 local canSpend,reason=session:CanSpendCash(price)
 if not canSpend then return false,reason end
 session.coins-=price;session.incomeLevel+=1;session.tutorial.upgraded=true;session:Touch()
 return true,"Egg value upgraded. Chickens laying at home now earn more coins."
end

-- Older clients may still request promotion; cash upgrades do not require conquest.
function ArmyService.Promote(_session)
 return false,"Buy upgrades with coins in Upgrades."
end

return ArmyService
