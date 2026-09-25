--!strict
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Catalog = require(Shared.PetCatalog)
local Progression = require(Shared.Progression)
local ShopCatalog = require(Shared.ShopCatalog)
local UpgradeCatalog = require(Shared.UpgradeCatalog)
local EggProcessor = require(script.Parent.EggProcessor)
local OfflineCash = require(script.Parent.OfflineCash)
local PlayerSession = {}
PlayerSession.__index = PlayerSession

function PlayerSession.new(userId: number, name: string, plotIndex: number)
	local self = setmetatable({}, PlayerSession)
	self.userId, self.name, self.plotIndex = userId, name, plotIndex
	self.revision = 0
	-- Verified by CommerceService per visit; never serialized or reset with coins.
	self.entitlements = {}
	self:Reset()
	return self
end

function PlayerSession:Reset()
	-- A debug gameplay reset must never re-deliver an acknowledged purchase.
	self.purchaseReceipts=self.purchaseReceipts or {}
	self.crateCredits=self.crateCredits or 0
	self.guaranteedLuckRolls=self.guaranteedLuckRolls or 0
	self.commerceAutomatic=self.commerceAutomatic or {AutoCollectEggs=true,AutoMerge=true}
	self.coins, self.capacity, self.luck = Config.StartingCoins, Config.StartingSlots, 0
	self.eggSpeedLevel, self.plotSizeLevel, self.rollSlotsUnlocked = 0, 0, 1
	self.eggCarry={count=0,value=0}
	self.offlineCash = {at=0,rate=0}
	self.offlineCashReceipt = nil
	local finishCredits = if self.eggProcessor then self.eggProcessor.finishCredits else 0
	self.eggProcessor = EggProcessor.New()
	self.eggProcessor.finishCredits = finishCredits
	self.enemyKills=0
 self.incomeLevel=0
 self.promotion,self.recruitTier=1,1
 self.frontierWins,self.kingCleared={},false
 self.dataRevision,self.legacyCapacityGrant=Config.DataRevision,0
 self.tutorial={}
 self.saveStatus=self.saveStatus or "loading"
 self.saveMessage=self.saveMessage or "Loading your flock…"
	self.pets, self.slots, self.firstWins, self.raidPaid = {}, {}, {}, {}
	self.discovered = {}
	-- Nil means automatic; an empty list is an intentionally empty manual army.
	self.armySelection = nil :: {string}?
	self.campUnlocked, self.rollReadyAt, self.rollRevealAt = 1, 0, 0
	self.armyState, self.outgoing, self.incoming, self.defending = "Home", nil, nil, nil
	self.stationedAt = nil
	self.awayPets={}
	self.passiveEarned, self.battleEarned, self.returnAt = 0, 0, 0
	self.sessionIncome={eggs=0,battle=0,territory=0}
	self.debugNext, self.debugRandom = nil, nil
	self.lastResult, self.banner = "Collect eggs, then walk onto the green sell pad.", ""
	for slot, species in Config.StarterFlock do
		local pet = self:AddPet(species, 1)
		pet.investment = 0 -- Free birds have no cash purchase to refund.
		self.slots[slot] = pet.id
	end
	self.offer = {id=HttpService:GenerateGUID(false), species="Duck", starter=true,
		level=1, price=Config.Economy.StarterRecruitPrice}
	self.offers={[1]=self.offer}
	self.rollSlotCount=1 -- WorldService binds the available physical displays.
	self:Touch()
end

function PlayerSession:Touch()
	self.revision += 1
end

function PlayerSession:AddPet(species: string, stars: number)
	local pet = {id=HttpService:GenerateGUID(false), species=species, stars=1, level=1, favorite=false, collected=0,investment=Catalog[species].price}
	self.pets[pet.id] = pet
	if table.find(Catalog.Order, species) then self.discovered[species] = true end
	return pet
end

function PlayerSession:Capacity(): number
 return self.capacity + (if self.entitlements.BiggerArmy then ShopCatalog.ArmyBonus else 0)
end

function PlayerSession:CollectionLimit(): number
 return math.min(Config.LegacyCollectionLimit,
  Config.CollectionLimit + self.plotSizeLevel * UpgradeCatalog.ExtraChickensPerPlotLevel)
end

function PlayerSession:EggProductionMultiplier(): number
 return UpgradeCatalog.EggSpeedRates[self.eggSpeedLevel + 1]
  * (if self.entitlements.DoubleEggSpawn then 2 else 1)
end

function PlayerSession:AutomaticEnabled(key: string): boolean
 return self.entitlements[key]==true and self.commerceAutomatic[key]==true
end

function PlayerSession:PaidLuckMultiplier(): number
 return if self.entitlements.DoubleLuck and self.paidRandomAllowed==true then 2 else 1
end

function PlayerSession:LuckGuarantee()
 local schedule=ShopCatalog.GuaranteedLuck
 local count=self.guaranteedLuckRolls
 local index=math.floor(count/schedule.interval)%#schedule.sequence+1
 return {interval=schedule.interval,rollsRemaining=schedule.interval-count%schedule.interval,
  nextSpecies=schedule.sequence[index],sequence=table.clone(schedule.sequence)}
end

function PlayerSession:AdvanceGuaranteedLuck(): string?
 if self.entitlements.DoubleLuck~=true or self.paidRandomRestricted~=true then return nil end
 local guarantee=self:LuckGuarantee()
 self.guaranteedLuckRolls=(self.guaranteedLuckRolls+1)%(guarantee.interval*#guarantee.sequence)
 return if guarantee.rollsRemaining==1 then guarantee.nextSpecies else nil
end

function PlayerSession:EarnedAmount(amount: number, source: string): number
 local earned=source=="eggs" or source=="battle" or source=="territory"
 return amount * (if earned and self.entitlements.DoubleCash then 2 else 1)
end

function PlayerSession:Count(): number
	local count = 0
	for _ in self.pets do count += 1 end
	return count
end

function PlayerSession:FindSlot(id: string): number?
	for slot, petId in self.slots do if petId == id then return slot end end
	return nil
end

-- Automatic combat-power ranking. Equal-power purchases preserve the existing squad.
function PlayerSession:AutoBestPetIds()
	local ranked={}
	for id,pet in self.pets do
		table.insert(ranked,{id=id,power=Rules.PetPower(pet.species,pet.stars,pet.level),slot=self:FindSlot(id)})
	end
	table.sort(ranked,function(a,b)
		if a.power~=b.power then return a.power>b.power end
		if (a.slot~=nil)~=(b.slot~=nil) then return a.slot~=nil end
		if a.slot and b.slot then return a.slot<b.slot end
		return a.id<b.id
	end)
	local ids={}
	for i=1,math.min(self:Capacity(),#ranked) do table.insert(ids,ranked[i].id) end
	return ids
end

-- Existing deployment/reinforcement consumers use this desired roster contract.
function PlayerSession:BestPetIds()
	if self.armySelection==nil then return self:AutoBestPetIds() end
	local ids,seen={},{}
	for _,id in self.armySelection do
		if self.pets[id] and not seen[id] and #ids<self:Capacity() then
			seen[id]=true;table.insert(ids,id)
		end
	end
	return ids
end

function PlayerSession:RefreshArmy(): boolean
	-- BattleService owns physical relief handoffs while deployed.
	if self:IsArmyLocked() then return false end
	local best=self:BestPetIds()
	local chosen,slots={},{}
	for _,id in best do chosen[id]=true end
	for slot,id in self.slots do
		if slot<=self:Capacity() and chosen[id] then slots[slot]=id end
	end
	for _,id in best do
		local oldSlot=self:FindSlot(id)
		if not oldSlot or slots[oldSlot]~=id then
			for slot=1,self:Capacity() do if not slots[slot] then slots[slot]=id;break end end
		end
	end
	-- Manual ordering is explicit; automatic mode retains the stable slot behavior above.
	if self.armySelection~=nil then slots=table.clone(best) end
	local changed=false
	for slot,id in self.slots do if slots[slot]~=id then changed=true;break end end
	if not changed then for slot,id in slots do if self.slots[slot]~=id then changed=true;break end end end
	if changed then self.slots=slots;self:Touch() end
	return changed
end

local function selectedSet(session)
	local result={}
	for _,id in session:BestPetIds() do result[id]=true end
	return result
end

local function saleEligibility(session,id,selected): (boolean,string)
	local pet=if type(id)=="string" then session.pets[id] else nil
	if not pet then return false,"That chicken is no longer in your flock." end
	if pet.favorite then return false,"Favorite protected — unfavorite this chicken before selling." end
	if not session:IsPetHome(id) then return false,"This chicken is deployed or traveling." end
	if selected[id] then return false,"Selected for your army. Remove this chicken from the army before selling." end
	return true,"Reserve chicken — available to sell."
end

function PlayerSession:SaleEligibility(id): (boolean,string)
	return saleEligibility(self,id,selectedSet(self))
end

function PlayerSession:Lineup()
	local result = {}
	for slot=1, self:Capacity() do
		local pet = self.pets[self.slots[slot]]
		if pet then table.insert(result, {id=pet.id, species=pet.species, stars=pet.stars, level=pet.level, slot=slot}) end
	end
	return result
end

-- Physical home location determines egg production.
-- Every reserve stays home; deployed and incoming birds use battle actors
-- until its departure, defense or recovery transition has finished.
function PlayerSession:IsPetHome(id: string): boolean
	return self.pets[id]~=nil and not (self.awayPets and self.awayPets[id]) and (not self:IsArmyLocked() or self:FindSlot(id)==nil)
end

function PlayerSession:HomePets()
	local result={}
	for id,pet in self.pets do if self:IsPetHome(id) then table.insert(result,pet) end end
	table.sort(result,function(a,b) return a.id<b.id end)
	return result
end

function PlayerSession:PetIncome(id: string): number
	local pet=self.pets[id]
	if not pet then return 0 end
	return Rules.Income(pet.species,pet.stars,pet.level,self.incomeLevel)
end

function PlayerSession:DisplayedPetIncome(species: string, stars: number, level: number?): number
 local raw=Rules.Income(species,stars,level,self.incomeLevel)
 return self:EarnedAmount(raw*self:EggProductionMultiplier(),"eggs")
end

function PlayerSession:Income(): number
	local income=0
	for id in self.pets do if self:IsPetHome(id) then income+=self:PetIncome(id) end end
	return income
end

function PlayerSession:IsArmyLocked(): boolean
	return self.armyState ~= "Home"
end

function PlayerSession:Credit(amount: number, source: string)
	assert(type(amount)=="number" and amount==amount and amount>=0 and amount<math.huge and amount%1==0,"Coin credits must be nonnegative whole numbers")
	if amount==0 then return 0 end
	amount=self:EarnedAmount(amount,source)
	self.coins += amount
	if source == "eggs" then self.passiveEarned += amount end
	if source == "battle" then self.battleEarned += amount end
	-- Session-only observation totals; never serialized or used to authorize a purchase.
	self.sessionIncome=self.sessionIncome or {eggs=0,battle=0,territory=0}
	if self.sessionIncome[source]~=nil then self.sessionIncome[source]+=amount end
	self:Touch()
	return amount
end

-- Unlocks are permanent, earned by distinct victories; the active squad is untouched.
function PlayerSession:UnlockProgress()
 local earned=Progression.EarnedRank(self.firstWins,self.frontierWins)
 if earned<=self.promotion then return false end
 self.promotion,self.recruitTier=earned,earned
 -- A victory may happen while the player is rolling. Preserve that reveal and offer;
 -- Conquest ranks do not unlock cash upgrades or change roll odds.
 self.banner=Progression.Get(earned).name.." reached!"
 self:Touch()
 return true
end

function PlayerSession:Completed(): boolean
	for i=1,#Progression.Camps(1) do if not self.firstWins[i] then return false end end
	return true
end

function PlayerSession:NextSlot()
 local rule=Config.SlotUnlocks[self.capacity]
 if not rule then return nil end
 -- Deployment upgrades depend on cash and the configured track, never conquest.
 return {capacity=rule.capacity,displayCapacity=rule.capacity+(if self.entitlements.BiggerArmy then ShopCatalog.ArmyBonus else 0),price=rule.price,unlocked=true,
  requirement="Buy one more deployment slot"}
end

function PlayerSession:GlobalUpgrade(kind: string)
	local current=if kind=="Income" then self.incomeLevel else self.luck
	local prices=if kind=="Income" then Config.IncomePrices else Config.LuckPrices
	local price=prices[current+1]
	if not price then return nil end
	return {price=price,unlocked=true,requirement=""}
end

-- Compare a reveal to the best owned squad, including pending replacements while away.
function PlayerSession:OfferAdvice(species: string, level: number?): (string, boolean)
	local best=self:AutoBestPetIds()
	if #best<self:Capacity() then
		return "Fills an army slot",true
	end
	local weakest=self.pets[best[#best]]
	if weakest and Rules.PetPower(species,1,level)>Rules.PetPower(weakest.species,weakest.stars,weakest.level) then
		return "Stronger next squad",true
	end
	local income=self:DisplayedPetIncome(species,1,level)
	return "Lays eggs worth $"..income.."/s at home",false
end

function PlayerSession:Snapshot(now: number)
	local rank=Progression.Get(self.promotion)
	local best=self:BestPetIds()
	local selected,deployed={},{}
	local deployedIds={}
	for _,id in best do selected[id]=true end
	if self:IsArmyLocked() then
		for _,pet in self:Lineup() do table.insert(deployedIds,pet.id);deployed[pet.id]=true end
	end
	local pets={}
	for _,pet in self.pets do
		local canSell,reason=saleEligibility(self,pet.id,selected)
		table.insert(pets,{id=pet.id,species=pet.species,stars=pet.stars,level=pet.level,favorite=pet.favorite,
			slot=self:FindSlot(pet.id),selected=selected[pet.id]==true,deployed=deployed[pet.id]==true,
			canSell=canSell,saleReason=reason,income=self:DisplayedPetIncome(pet.species,pet.stars,pet.level),home=self:IsPetHome(pet.id),
			nextIncome=if (pet.level or 1)<rank.levelCap then self:DisplayedPetIncome(pet.species,pet.stars,(pet.level or 1)+1) else nil,
			levelCap=rank.levelCap,upgradeLocked=(pet.level or 1)>=rank.levelCap,
			investment=pet.investment,refund=Rules.SellValue(pet.investment or Rules.Investment(pet.species,pet.level))})
	end
	table.sort(pets,function(a,b)
		if a.species~=b.species then return a.species<b.species end
		if a.stars~=b.stars then return a.stars>b.stars end
		return a.id<b.id
	end)
	local offers={}
	for slot=1,self.rollSlotCount or 1 do
		local value=self.offers and self.offers[slot]
		if value then
			local offer=table.clone(value);offer.slot=slot
			offer.advice,offer.improvesArmy=self:OfferAdvice(offer.species,offer.level)
			table.insert(offers,offer)
		end
	end
	local offer=offers[1]
	local campsWon=0
	for i=1,#Progression.Camps(1) do if self.firstWins[i] then campsWon+=1 end end
	local eggProduction=self:EggProductionMultiplier()
	local income=self:EarnedAmount(self:Income()*eggProduction,"eggs")
	return {nextSlot=self:NextSlot(),
		progression={rank=self.promotion,name=rank.name,total=Progression.Count(),capacityCap=Config.MaxSlots+(if self.entitlements.BiggerArmy then ShopCatalog.ArmyBonus else 0),
			levelCap=rank.levelCap,ready=false,
            goal=Progression.NextGoal(self.firstWins,self.frontierWins,self.kingCleared),
            requirement=Progression.Requirement(math.min(self.promotion+1,4)),
			nextName=if self.promotion<Progression.Count() then Progression.Get(self.promotion+1).name else nil,
			recruitTier=self.recruitTier,recruitName=Progression.Get(self.recruitTier).name,
			nextUnlock=Progression.NextGoal(self.firstWins,self.frontierWins,self.kingCleared)},
		incomeUpgrade=self:GlobalUpgrade("Income"),luckUpgrade=self:GlobalUpgrade("Luck"),
		frontierWins=table.clone(self.frontierWins),kingCleared=self.kingCleared,
        firstWins=table.clone(self.firstWins),homeCount=#self:HomePets(),reserveCount=#pets-#best,homeIncome=income,incomeLevel=self.incomeLevel,
		offlineCash=if self.offlineCashReceipt then table.clone(self.offlineCashReceipt) else nil,
		tutorial=table.clone(self.tutorial),saveStatus=self.saveStatus,saveMessage=self.saveMessage,
		campsWon=campsWon,allCampsWon=self:Completed(),
		userId=self.userId,name=self.name,plotIndex=self.plotIndex,revision=self.revision,
		coins=self.coins,income=income,capacity=self:Capacity(),baseCapacity=self.capacity,count=#pets,pets=pets,discovered=table.clone(self.discovered),
		collectionLimit=self:CollectionLimit(),selectedIds=best,deployedIds=deployedIds,
		selectionMode=if self.armySelection==nil then "Auto" else "Manual",
		selectedCount=#best,deployedCount=#deployedIds,overflowCount=math.max(0,#pets-self:CollectionLimit()),
		offer=offer,offers=offers,rollSlotCount=self.rollSlotCount or 1,rollRemaining=math.max(0,self.rollReadyAt-now),odds=Rules.Odds(self.luck,self.recruitTier,self:PaidLuckMultiplier()),luck=self.luck,
		campUnlocked=self.campUnlocked,armyState=self.armyState,outgoing=self.outgoing,incoming=self.incoming,stationedAt=self.stationedAt,
		returnRemaining=math.max(0,self.returnAt-now),passiveEarned=self.passiveEarned,battleEarned=self.battleEarned,
		power=Rules.Power(self:Lineup()),deployed=#deployedIds,lastResult=self.lastResult,banner=self.banner}
end

-- The data envelope/lease belongs to DataService. This object owns its serializable player values.
function PlayerSession:ToData()
 local armySelection
 if self.armySelection~=nil then
  armySelection={}
  local seen={}
  for _,id in self.armySelection do
   if self.pets[id] and not seen[id] and #armySelection<self.capacity+ShopCatalog.ArmyBonus then
    seen[id]=true;table.insert(armySelection,id)
   end
  end
 end
	local pets={}
	for _,pet in self.pets do table.insert(pets,{id=pet.id,species=pet.species,level=pet.level,favorite=pet.favorite,collected=pet.collected or 0,
		investment=pet.investment or Rules.Investment(pet.species,pet.level)}) end
	table.sort(pets,function(a,b) return a.id<b.id end)
	local wins={}
	for index,won in self.firstWins do if won then table.insert(wins,index) end end
	table.sort(wins)
 local frontier={}
 for i,won in self.frontierWins do if won then table.insert(frontier,i) end end
 table.sort(frontier)
	return {dataRevision=Config.DataRevision,legacyCapacityGrant=self.legacyCapacityGrant or 0,
		purchaseReceipts=table.clone(self.purchaseReceipts),crateCredits=self.crateCredits,commerceAutomatic=table.clone(self.commerceAutomatic),
		guaranteedLuckRolls=self.guaranteedLuckRolls,
		eggCarry=table.clone(self.eggCarry),enemyKills=self.enemyKills,
		eggProcessor=EggProcessor.Copy(self.eggProcessor),
		offlineCash=table.clone(self.offlineCash),
		promotion=self.promotion,recruitTier=self.recruitTier,
		coins=self.coins,capacity=self.capacity,luck=self.luck,incomeLevel=self.incomeLevel,
		armySelection=armySelection,
		eggSpeedLevel=self.eggSpeedLevel,plotSizeLevel=self.plotSizeLevel,rollSlotsUnlocked=self.rollSlotsUnlocked,
		pets=pets,discovered=table.clone(self.discovered),firstWins=wins,frontierWins=frontier,kingCleared=self.kingCleared,tutorial=table.clone(self.tutorial),
		passiveEarned=self.passiveEarned,battleEarned=self.battleEarned}
end

local function numberIn(value,minimum,maximum,integer)
 return type(value)=="number" and value==value and value>=minimum and value<=maximum and (not integer or value%1==0)
end

local function readWins(entries, limit, sparse)
	if type(entries)~="table" or #entries>limit then return nil end
	local wins,count={},0
	for key,index in entries do
		count+=1
		if not numberIn(key,1,#entries,true) or not numberIn(index,1,limit,true) or wins[index] then return nil end
		wins[index]=true
	end
	if count~=#entries then return nil end
	local gap=false
	if not sparse then for i=1,limit do if not wins[i] then gap=true elseif gap then return nil end end end
	return wins
end

-- Revision 6 uses stable main-route IDs; appended camps can extend this list.
-- Earlier campaign layouts retain only IDs 1/2: their old third camp is not
-- the new Bucket Bastion and must never grant its first win.
local function readProgress(data, revision)
	if revision>=6 then return readWins(data.firstWins,#Progression.Camps(1)) end
 if revision>=4 then
  local old=readWins(data.firstWins,3)
  if not old then return nil end
  local wins={}
  for i=1,2 do if old[i] or (data.promotion or 1)>1 then wins[i]=true end end
  return wins
 end
	local selected=readWins(data.firstWins,5)
	if not selected or not numberIn(data.campaign,1,3,true)
		or type(data.campaignWins)~="table" or #data.campaignWins~=3 then return nil end
	local histories,count={},0
	for index,entries in data.campaignWins do
		count+=1
		if not numberIn(index,1,3,true) then return nil end
		histories[index]=readWins(entries,5)
		if not histories[index] then return nil end
	end
	if count~=3 then return nil end
	local unlocked=1
	for index=1,2 do if histories[index][5] then unlocked=index+1 else break end end
	if data.campaign>unlocked then return nil end
	for index=unlocked+1,3 do if next(histories[index]) then return nil end end
	for i=1,5 do if (selected[i]==true)~=(histories[data.campaign][i]==true) then return nil end end
	-- Keep only clears of the two retained route IDs from the old campaigns.
	local wins={}
	for current,previous in {1,2} do if histories[1][previous] then wins[current]=true end end
	return wins
end

function PlayerSession:LoadData(data)
	if type(data)~="table" then return false,"Invalid saved profile." end
	local receipts={}
 if data.purchaseReceipts~=nil then
  if type(data.purchaseReceipts)~="table" then return false,"Invalid purchase history." end
  for id,productId in data.purchaseReceipts do
   if type(id)~="string" or #id<1 or #id>256 or not utf8.len(id)
    or not numberIn(productId,1,2^53-1,true) then return false,"Invalid purchase history." end
   receipts[id]=productId
  end
 end
 if not numberIn(data.crateCredits or 0,0,1e9,true) then return false,"Invalid saved crate count." end
 if not numberIn(data.guaranteedLuckRolls or 0,0,1e12,true) then return false,"Invalid saved guaranteed-offer progress." end
 local automatic={AutoCollectEggs=true,AutoMerge=true}
 if data.commerceAutomatic~=nil then
  if type(data.commerceAutomatic)~="table" then return false,"Invalid automatic settings." end
  for key,value in data.commerceAutomatic do
   if automatic[key]==nil or type(value)~="boolean" then return false,"Invalid automatic settings." end
   automatic[key]=value
  end
 end
 local revision=data.dataRevision or 1
	if not numberIn(revision,1,Config.DataRevision,true) then return false,"Unsupported saved profile revision." end
	-- Additive fields: never reduce the six slots an existing profile already had.
	local eggSpeedLevel = if data.eggSpeedLevel == nil then 0 else data.eggSpeedLevel
	local plotSizeLevel = if data.plotSizeLevel == nil then 0 else data.plotSizeLevel
	local rollSlotsUnlocked = if data.rollSlotsUnlocked == nil then Config.RollSlotsUnlocked else data.rollSlotsUnlocked
	if not numberIn(eggSpeedLevel,0,#UpgradeCatalog.EggSpeedPrices,true)
		or not numberIn(plotSizeLevel,0,#UpgradeCatalog.PlotPrices,true)
		or not numberIn(rollSlotsUnlocked,1,Config.RollSlotsUnlocked,true) then
		return false,"Invalid saved board upgrades."
	end
	local legacy=revision==1
	-- New carried eggs are distinct from the already-converted revision-1 egg bag.
	local carry=data.eggCarry or {count=0,value=0}
	local processor=EggProcessor.Read(data.eggProcessor)
	if not processor then return false,"Invalid saved egg processor." end
	local offlineCash=OfflineCash.Read(data.offlineCash)
	if not offlineCash then return false,"Invalid saved offline cash." end
	if type(carry)~="table" or not numberIn(carry.count,0,1e12,true)
		or not numberIn(carry.value,0,1e12,true) or ((carry.count==0)~=(carry.value==0))
		or not numberIn(data.enemyKills or 0,0,1e12,true) then return false,"Invalid saved eggs or defeat count." end
	local promotion=if revision>=5 then data.promotion else 1
	local recruitTier=if revision>=5 then data.recruitTier else 1
	if not numberIn(promotion,1,Progression.Count(),true) or not numberIn(recruitTier,1,promotion,true) then
		return false,"Invalid saved promotion."
	end
	local capacity,grant=data.capacity,data.legacyCapacityGrant or 0
	if legacy then
		local mapped={[4]=6,[5]=6,[6]=6,[8]=12,[10]=12,[12]=12}
		capacity=if type(data.capacity)=="number" then mapped[data.capacity] else nil
		if not capacity then return false,"Invalid legacy deployment capacity." end
		grant=capacity
	elseif revision==2 then
		if not table.find({6,12,24},capacity) then return false,"Invalid previous deployment capacity." end
		if not numberIn(grant,0,12,true) or (grant~=0 and grant~=6 and grant~=12) then return false,"Invalid grandfathered capacity grant." end
	end
	-- Preserve the collection and balance; only deployed capacity is capped at ten.
	if revision<3 then capacity=math.min(capacity,Config.MaxSlots);grant=capacity end
	if not numberIn(grant,0,Config.MaxSlots,true) then return false,"Invalid capacity grant." end
	if not numberIn(data.coins,0,1e12) or not numberIn(capacity,Config.StartingSlots,Config.MaxSlots,true)
		or not table.find(Config.SlotLevels,capacity) or grant>capacity or not numberIn(data.luck,0,#Config.LuckPrices,true)
		or not numberIn(data.incomeLevel,0,#Config.IncomePrices,true) or type(data.pets)~="table" or #data.pets>Config.LegacyCollectionLimit
		or type(data.tutorial)~="table" then return false,"Invalid saved profile." end
	local converted=0
	if legacy then
		if not numberIn(data.eggBagCount or 0,0,1e12,true) or not numberIn(data.eggBagValue or 0,0,1e12) then return false,"Invalid saved egg bag." end
		converted=data.eggBagValue or 0
	end
	local pets,count={},0
	for index,pet in data.pets do
		count+=1
		if not numberIn(index,1,#data.pets,true) or type(pet)~="table" or type(pet.id)~="string" or #pet.id<1 or #pet.id>64
			or not utf8.len(pet.id) or pets[pet.id] or type(pet.species)~="string" or not table.find(Catalog.Order,pet.species)
			or type(pet.favorite)~="boolean" or not numberIn(pet.collected or 0,0,1e12) then return false,"Invalid saved chicken." end
		if legacy then
			if not numberIn(pet.cash or 0,0,1e10) or not numberIn(pet.eggCount or 0,0,1e6,true)
				or not numberIn(pet.eggTimer or 0,0,Config.LegacyEggLaySeconds) then return false,"Invalid saved egg value." end
			converted+=pet.cash or 0
		end
		local level=if revision<3 then 1 else pet.level
		if not numberIn(level,1,Config.MaxPetLevel,true) then return false,"Invalid saved chicken level." end
		local investment=if revision<5 then Rules.Investment(pet.species,level,true) else pet.investment
		if not numberIn(investment,0,1e12) then return false,"Invalid saved chicken investment." end
		pets[pet.id]={id=pet.id,species=pet.species,stars=1,level=level,favorite=pet.favorite,collected=math.ceil(pet.collected or 0),investment=math.ceil(investment)}
	end
	if count~=#data.pets then return false,"Invalid saved collection." end
	-- Optional additive field; existing profiles continue selecting their best chickens.
	local armySelection
	if data.armySelection~=nil then
		if type(data.armySelection)~="table" or #data.armySelection>capacity+ShopCatalog.ArmyBonus then
			return false,"Invalid saved army selection."
		end
		local seen,entries={},0
		armySelection={}
		for index,id in data.armySelection do
			entries+=1
			if entries>capacity+ShopCatalog.ArmyBonus or not numberIn(index,1,#data.armySelection,true)
				or type(id)~="string" or not pets[id] or seen[id] then
				return false,"Invalid saved army selection."
			end
			seen[id]=true;armySelection[index]=id
		end
		if entries~=#data.armySelection then return false,"Invalid saved army selection." end
	end
	-- Additive field in the current envelope: older saves seed their owned flock.
	-- Discovery survives sale/merge; an unbought roll offer never adds an entry.
	local discovered = {}
	if data.discovered ~= nil then
		if type(data.discovered) ~= "table" then return false,"Invalid saved chicken index." end
		for species, collected in data.discovered do
			if type(species) ~= "string" or not table.find(Catalog.Order, species) or type(collected) ~= "boolean" then
				return false,"Invalid saved chicken index."
			end
			if collected then discovered[species] = true end
		end
	end
	for _, pet in pets do discovered[pet.species] = true end
	if not numberIn(data.coins+converted,0,1e12) then return false,"Saved coin balance exceeds the supported limit." end
	local wins=readProgress(data,revision)
	if not wins then return false,"Invalid saved camp progress." end
 local frontier,king={},false
 if revision>=6 then
  frontier=readWins(data.frontierWins,#Progression.Outposts(),true)
  if not frontier or type(data.kingCleared)~="boolean" then return false,"Invalid saved exploration progress." end
  king=data.kingCleared
 elseif revision==5 then
  -- Preserve completed older stages as distinct outposts; never downgrade an earned tier.
  local old=readWins(data.firstWins,3)
  for tier=2,4 do
   local offset=(tier-2)*2
   if promotion>tier then frontier[offset+1],frontier[offset+2]=true,true
   elseif promotion==tier then
    if old[1] then frontier[offset+1]=true end
    if old[3] then frontier[offset+2]=true end
   end
  end
 end
 -- Older migrations earned ranks after two retained route camps. Preserve that
 -- entitlement without treating their old third landmark as Bucket Bastion.
 -- Current revision-6 profiles keep their saved rank; new unlocks need all camps.
 if revision<6 and wins[1] and wins[2] then
  local previousEarned=if frontier[4] then 4 elseif frontier[2] then 3 else 2
  if previousEarned>promotion then promotion,recruitTier=previousEarned,previousEarned end
 end
	local tutorial={}
	for _,key in {"rolled","bought","collected","collectedEggs","soldEggs","wonCamp","returned","upgraded"} do tutorial[key]=data.tutorial[key]==true end
	if not numberIn(data.passiveEarned or 0,0,1e12) or not numberIn(data.battleEarned or 0,0,1e12) then return false,"Invalid saved earnings." end
	-- Commit only after every field validates. Old egg values were already valued;
	-- never multiply them again, and omit them from the current save payload.
	self.purchaseReceipts,self.crateCredits,self.commerceAutomatic=receipts,data.crateCredits or 0,automatic
	self.guaranteedLuckRolls=(data.guaranteedLuckRolls or 0)%(ShopCatalog.GuaranteedLuck.interval*#ShopCatalog.GuaranteedLuck.sequence)
	self.dataRevision,self.legacyCapacityGrant=Config.DataRevision,grant
	self.eggSpeedLevel,self.plotSizeLevel,self.rollSlotsUnlocked=eggSpeedLevel,plotSizeLevel,rollSlotsUnlocked
	self.eggCarry={count=carry.count,value=carry.value};self.enemyKills=data.enemyKills or 0
	self.eggProcessor=processor
	self.offlineCash,self.offlineCashReceipt=offlineCash,nil
	-- Preserve saved ranks and validation; always use the best earned odds now.
	self.promotion,self.recruitTier=promotion,promotion
 self.frontierWins,self.kingCleared=frontier,king
	-- Preserve old saves: round any historical cents up once, never reset progress.
	self.coins,self.capacity,self.luck,self.incomeLevel=math.ceil(data.coins+converted),capacity,data.luck,data.incomeLevel
	self.pets,self.slots,self.firstWins,self.tutorial=pets,{},wins,tutorial
	self.armySelection=armySelection
	self.discovered = discovered
	self.passiveEarned,self.battleEarned=math.ceil(data.passiveEarned or 0),math.ceil(data.battleEarned or 0)
	self.armyState,self.outgoing,self.incoming,self.defending="Home",nil,nil,nil
	self.returnAt,self.stationedAt=0,nil
	self.campUnlocked=1
	while self.firstWins[self.campUnlocked] and self.campUnlocked<#Progression.Camps(1) do self.campUnlocked+=1 end
	self.offer,self.offers=nil,{}
	self:UnlockProgress();self:RefreshArmy();self:Touch()
	return true,if legacy then "Loaded and converted stored egg value to coins." else "Loaded."
end

function PlayerSession:Destroy()
	self.pets, self.slots = {}, {}
end

return PlayerSession
