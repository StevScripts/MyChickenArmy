--!strict
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Catalog = require(Shared.PetCatalog)
local Giant = require(Shared.GiantChicken)
local Progression = require(Shared.Progression)
local ShopCatalog = require(Shared.ShopCatalog)
local UpgradeCatalog = require(Shared.UpgradeCatalog)
local Currency = require(Shared.CurrencyLimits)
local EggProcessor = require(script.Parent.EggProcessor)
local OfflineCash = require(script.Parent.OfflineCash)
local ResearchRules = require(Shared.ResearchRules)
local ResearchService = require(script.Parent.ResearchService)
local TutorialGuide = require(Shared.TutorialGuide)
local MutationCatalog = require(Shared.MutationCatalog)
local RebirthService = require(script.Parent.RebirthService)
local PlayerSession = {}
PlayerSession.__index = PlayerSession
-- Saved eggCarry bound. EggService stops pickups before reaching it; older servers reject above it.
PlayerSession.CarryLimit = 1e12

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
	self.research=ResearchRules.New()
	self.researchEffects=ResearchRules.Effects(self.research)
	self.researchRecap={}
	self.operationResult=nil
	self.rallyActiveUntil=0
	local finishCredits = if self.eggProcessor then self.eggProcessor.finishCredits else 0
	self.eggProcessor = EggProcessor.New()
	self.eggProcessor.finishCredits = finishCredits
	self.enemyKills=0
	self.robuxSpent=0 -- Lifetime Robux spent in game (leaderboard only; never a benefit)
 self.incomeLevel=0
 self.promotion,self.recruitTier=1,1
 self.frontierWins,self.kingCleared={},false
 self.kingBountyPaid=false -- Full King boss bounty is paid once per player (BattleService).
 -- King of the Hill (HillService): lifetime round wins, owed Hill Rolls, Champion granted.
 self.hillWins,self.hillRollCredits,self.hillChampion=0,0,false
 -- Launch fields (docs/team/launch): Re-enlist rank and the 7-day login streak.
 -- dailyGranted is live only: the reward granted this session, for the popup.
 self.rebirths=0
 self.daily={streak=0,lastDay=0,best=0}
 self.dailyGranted=nil
 -- October 14 Giants: fusions in a row without a Giant (guarantee at Giant.PityLimit).
 self.giantPity=0
 self.dataRevision,self.legacyCapacityGrant=Config.DataRevision,0
 self.tutorial={starterArmy=true,collectedEggCount=0}
 self.fusionUnlocked=false
 self.saveStatus=self.saveStatus or "loading"
 self.saveMessage=self.saveMessage or "Loading your flock…"
	self.pets, self.slots, self.firstWins, self.raidPaid = {}, {}, {}, {}
	-- Camps beaten once on other commanders' lanes: {[ownerUserId string]=bitmask, bit i-1 = camp i}.
	self.laneCamps = {}
	-- Live egg-value bonus from held territories (BattleService). Never saved,
	-- never part of the offline rate: holdings end when the player leaves.
	self.territoryBonus = 0
	-- Set when an admin gives chickens, research, camp wins or army size
	-- (AdminService); keeps the Strongest Army board earned. Saved.
	self.adminAssisted = false
	self.discovered = {}
	-- Raw saved entries for species this build does not know; written back unchanged.
	self.unrecognizedPets, self.unrecognizedDiscovered = {}, {}
	-- Nil means automatic; an empty list is an intentionally empty manual army.
	self.armySelection = nil :: {string}?
	self.campUnlocked, self.rollReadyAt, self.rollRevealAt = 1, 0, 0
	self.armyState, self.outgoing, self.incoming, self.defending = "Home", nil, nil, nil
	self.stationedAt = nil
	self.awayPets={}
	self.passiveEarned, self.battleEarned, self.returnAt = 0, 0, 0
	self.sessionIncome={eggs=0,battle=0,territory=0}
	self.debugNext, self.debugRandom = nil, nil
	self.lastResult, self.banner = "Your first three chickens are ready. Roll FREE to recruit your fourth!", ""
	for slot, species in Config.StarterFlock do
		local pet = self:AddPet(species, 1)
		pet.investment = 0 -- Free birds have no cash purchase to refund.
		self.slots[slot] = pet.id
	end
	self.offer, self.offers = nil, {}
	self.rollSlotCount=1 -- WorldService binds the available physical displays.
	self:Touch()
end

function PlayerSession:Touch()
	self.revision += 1
end

-- A brand-new profile lays no eggs until its first-visit film ends or is skipped.
-- Transient (never saved); the deadline is a fallback so a client that never
-- reports back cannot leave the yard silent.
function PlayerSession:EggsHeld(now: number): boolean
	local deadline = self.introHoldUntil
	if deadline == nil then return false end
	if now >= deadline then self.introHoldUntil = nil; return false end
	return true
end

function PlayerSession:AddPet(species: string, stars: number, mutation: string?)
	local pet = {id=HttpService:GenerateGUID(false), species=species, stars=1, level=1, favorite=false, collected=0,investment=Catalog[species].price}
	if MutationCatalog.IsValid(mutation) then pet.mutation = mutation end
	self.pets[pet.id] = pet
	if table.find(Catalog.Order, species) then self.discovered[species] = true end
	return pet
end

function PlayerSession:Capacity(): number
 return self.capacity + (if self.entitlements.BiggerArmy then ShopCatalog.ArmyBonus else 0)
end

function PlayerSession:CollectionLimit(): number
 return UpgradeCatalog.PlotCapacity(self.plotSizeLevel)
end

function PlayerSession:EggProductionMultiplier(): number
 return UpgradeCatalog.EggSpeedRates[self.eggSpeedLevel + 1]
  * (if self.entitlements.DoubleEggSpawn then 2 else 1)
  * (1+self.researchEffects.production)
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
 -- Re-enlist pays a permanent egg multiplier (1 at rank 0); offline cash routes here too.
 local rebirth=if source=="eggs" then RebirthService.Multiplier(self.rebirths or 0) else 1
 return amount * (if earned and self.entitlements.DoubleCash then 2 else 1) * rebirth
end

function PlayerSession:Count(): number
	local count = 0
	for _ in self.pets do count += 1 end
	return count
end

-- Saved cohorts keep their own opening; skipping/rejoining cannot spend its budget.
function PlayerSession:StarterRecruitPending(): boolean
	return not self.tutorial.bought and ((self.tutorial.starterArmy==true and not self.tutorial.guideCompleted)
		or (self.tutorial.emptyStart==true and self:Count()==0))
end

function PlayerSession:StarterArmyReserve(): number
	if not self.tutorial.starterArmy or self.tutorial.guideCompleted or self:Capacity()>=4 then return 0 end
	local nextSlot=self:NextSlot()
	return if nextSlot then nextSlot.price else 0
end

function PlayerSession:StarterCashReserve(): number
	return (if self:StarterRecruitPending() then Config.Economy.StarterRecruitPrice else 0)
		+self:StarterArmyReserve()
end

function PlayerSession:CanSpendCash(amount: number, purpose: string?): (boolean, string)
	if amount<0 or amount~=amount or self.coins<amount then return false,"Not enough cash." end
	local reserve=self:StarterCashReserve()
	-- Only validated server transactions supply a purpose. Each required purchase
	-- may use its own earmark, never the money reserved for the other purchase.
	if purpose=="StarterRecruit" and self:StarterRecruitPending() and amount==Config.Economy.StarterRecruitPrice then
		reserve-=Config.Economy.StarterRecruitPrice
	elseif purpose=="ArmySize" and amount==self:StarterArmyReserve() then
		reserve-=self:StarterArmyReserve()
	end
	if self.coins-amount<reserve then
		local reason=if self.tutorial.starterArmy then "Keep $"..reserve.." for your tutorial recruit and Army Size."
			else "Keep $"..Config.Economy.StarterRecruitPrice.." for your first chicken. Roll FREE at the lever!"
		return false,reason
	end
	return true,""
end

function PlayerSession:StarterFlockMinimum(): number
	if self.tutorial.guideCompleted then return 0 end
	if self.tutorial.starterArmy then return if self.tutorial.bought then 4 else 3 end
	return if self.tutorial.emptyStart then 1 else 0
end

function PlayerSession:ProtectStarterFlock(): boolean
	return self:StarterFlockMinimum()>0
end

function PlayerSession:MergeAccess(): (boolean, string)
	if self.fusionUnlocked==true or self.research.completed.FuseMachine==true then return true,"" end
	return false,"Unlock the Fuse Machine in Upgrades first."
end

function PlayerSession:FindSlot(id: string): number?
	for slot, petId in self.slots do if petId == id then return slot end end
	return nil
end

-- One Colossal may be selected; extra owned Colossals remain reserves.
-- Shared by auto/manual selection, save normalization and deployment lineups.
function PlayerSession:FilterArmyIds(values, capacity: number?)
	local ids,seen,colossals={},{},0
	for _,id in values do
		local pet=self.pets[id]
		if not pet or seen[id] or #ids>=(capacity or self:Capacity()) then continue end
		local colossal=Giant.IsColossal(pet.giantSize)
		if colossal and colossals>=Giant.MaxArmyColossals then continue end
		seen[id]=true;table.insert(ids,id)
		if colossal then colossals+=1 end
	end
	return ids
end

-- Automatic combat-power ranking. Equal-power purchases preserve the existing squad.
-- Strongest Army leaderboard: the best army this flock can field (top chickens
-- within army size), independent of the player's manual selection.
function PlayerSession:BestArmyPower(): number
	local roster={}
	for _,id in self:AutoBestPetIds() do local pet=self.pets[id];if pet then table.insert(roster,pet) end end
	return Rules.Power(roster)
end

function PlayerSession:AutoBestPetIds()
	local ranked={}
	for id,pet in self.pets do
		table.insert(ranked,{id=id,power=Rules.PetPower(pet.species,pet.stars,pet.level,pet.giantSize),slot=self:FindSlot(id)})
	end
	table.sort(ranked,function(a,b)
		if a.power~=b.power then return a.power>b.power end
		if (a.slot~=nil)~=(b.slot~=nil) then return a.slot~=nil end
		if a.slot and b.slot then return a.slot<b.slot end
		return a.id<b.id
	end)
	local ids={}
	for _,entry in ranked do table.insert(ids,entry.id) end
	return self:FilterArmyIds(ids)
end

-- Existing deployment/reinforcement consumers use this desired roster contract.
function PlayerSession:BestPetIds()
	if self.armySelection==nil then return self:AutoBestPetIds() end
	return self:FilterArmyIds(self.armySelection)
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
	local minimum=session:StarterFlockMinimum()
	if minimum>0 and session:Count()<=minimum then
		return false,"Keep "..minimum.." "..(if minimum==1 then "chicken" else "chickens").." for your first mission."
	end
	if pet.favorite then return false,"Favorite chickens can't be sold." end
	if not session:IsPetHome(id) then return false,"Your Army is away with this chicken." end
	if selected[id] then return false,"Remove it from your Army first." end
	return true,"Ready to sell."
end

function PlayerSession:SaleEligibility(id): (boolean,string)
	return saleEligibility(self,id,selectedSet(self))
end

function PlayerSession:ChickenUpgradeEligibility(id): (boolean,string)
	local pet=if type(id)=="string" and #id<=64 then self.pets[id] else nil
	if not pet then return false,"Choose a chicken from your own flock." end
	if (pet.level or 1)>=Config.MaxPetLevel then return false,"Max level reached." end
	if not self:IsPetHome(id) or (self.incoming and self:FindSlot(id)) then
		return false,"This chicken must return to your base before upgrading."
	end
	return true,""
end

function PlayerSession:Lineup()
	local result,ids = {},{}
	for slot=1, self:Capacity() do
		local id=self.slots[slot];if id then table.insert(ids,id) end
	end
	for _,id in self:FilterArmyIds(ids) do
		local pet=self.pets[id]
		table.insert(result, {id=pet.id, species=pet.species, stars=pet.stars, level=pet.level, giantSize=pet.giantSize, mutation=pet.mutation, slot=self:FindSlot(id)})
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
	return Rules.Income(pet.species,pet.stars,pet.level,self.incomeLevel)*(1+self.researchEffects.eggValue)
		*MutationCatalog.Multiplier(pet.mutation)
end

function PlayerSession:DisplayedPetIncome(species: string, stars: number, level: number?, mutation: string?): number
 local raw=Rules.Income(species,stars,level,self.incomeLevel)*(1+self.researchEffects.eggValue)*MutationCatalog.Multiplier(mutation)
 return self:EarnedAmount(raw*self:EggProductionMultiplier(),"eggs")
end

function PlayerSession:PetEggRate(species: string, stars: number, level: number?, mutation: string?): number
 return Rules.EggRate(species,stars,level)*self:EggProductionMultiplier()*MutationCatalog.Multiplier(mutation)
end

function PlayerSession:Income(): number
	local income=0
	for id in self.pets do if self:IsPetHome(id) then income+=self:PetIncome(id) end end
	return income
end

-- Egg cash per second as the HUD shows it, but without 2x Cash: earned-income
-- passes never multiply paid cash packs (ShopCatalog.CashPackAmount).
function PlayerSession:PackIncome(): number
	local rate=self:Income()*self:EggProductionMultiplier()*RebirthService.Multiplier(self.rebirths or 0)
		*(1+(self.territoryBonus or 0))
	if rate~=rate or rate<0 or rate==math.huge then return 0 end
	return rate
end

function PlayerSession:IsArmyLocked(): boolean
	return self.armyState ~= "Home"
end

function PlayerSession:CanCredit(amount: number, source: string): boolean
	return self:EarnedAmount(amount,source) <= Currency.MaxCoins-self.coins
end

function PlayerSession:Credit(amount: number, source: string)
	assert(type(amount)=="number" and amount==amount and amount>=0 and amount<math.huge and amount%1==0,"Coin credits must be nonnegative whole numbers")
	if amount==0 then return 0 end
	if not self:CanCredit(amount,source) then return 0 end
	-- Whole coins only: the Re-enlist multiplier (×1.25…) can make fractions, and
	-- receipt delivery requires a whole wallet (ProductService).
	amount=math.floor(self:EarnedAmount(amount,source))
	self.coins += amount
	-- Lifetime display counters may outgrow a repeatedly spent wallet. Saturate
	-- only those counters at the numeric boundary; never make a save unreadable.
	if source == "eggs" then self.passiveEarned = math.min(Currency.MaxCoins,self.passiveEarned+amount) end
	-- Operation rewards already captured earned multipliers when the fight ended.
	if source == "battle" or source == "operation" then self.battleEarned = math.min(Currency.MaxCoins,self.battleEarned+amount) end
	-- Session-only observation totals; never serialized or used to authorize a purchase.
	self.sessionIncome=self.sessionIncome or {eggs=0,battle=0,territory=0}
	local incomeSource=if source=="operation" then "battle" else source
	if self.sessionIncome[incomeSource]~=nil then self.sessionIncome[incomeSource]+=amount end
	self:Touch()
	if self.onTutorialIncome then pcall(self.onTutorialIncome,source,amount,self.coins) end
	return amount
end

-- Unlocks are permanent, earned by distinct victories; the active squad is untouched.
function PlayerSession:UnlockProgress()
 local earned=Progression.EarnedRank(self.firstWins,self.frontierWins)
 if earned<=self.promotion then return false end
 self.promotion,self.recruitTier=earned,earned
 -- A victory may happen while the player is rolling. Preserve that reveal and offer;
 -- Conquest ranks do not unlock cash upgrades or change roll odds. Rank names are
 -- internal; the notice names the real unlock (the Fuse level cap).
 self.banner="Fusion up to Lv "..Progression.Get(earned).levelCap.." unlocked!"
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
  requirement="Buy one more Army slot"}
end

function PlayerSession:GlobalUpgrade(kind: string)
	local current=if kind=="Income" then self.incomeLevel else self.luck
	local prices=if kind=="Income" then Config.IncomePrices else Config.LuckPrices
	local price=prices[current+1]
	if not price then return nil end
	return {price=price,unlocked=true,requirement=""}
end

-- Compare a reveal to the best owned squad, including pending replacements while away.
function PlayerSession:OfferAdvice(species: string, level: number?, mutation: string?): (string, boolean)
	local best=self:AutoBestPetIds()
	if #best<self:Capacity() then
		return "Fills an army slot",true
	end
	local weakest=self.pets[best[#best]]
	if weakest and Rules.PetPower(species,1,level)>Rules.PetPower(weakest.species,weakest.stars,weakest.level,weakest.giantSize) then
		return "Makes your army stronger",true
	end
	local income=self:DisplayedPetIncome(species,1,level,mutation)
	return "Lays eggs worth $"..income.."/s at home",false
end

function PlayerSession:Snapshot(now: number)
	local rank=Progression.Get(self.promotion)
	local mergeUnlocked,mergeRequirement=self:MergeAccess()
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
		local canUpgrade,upgradeReason=self:ChickenUpgradeEligibility(pet.id)
		table.insert(pets,{id=pet.id,species=pet.species,stars=pet.stars,level=pet.level,favorite=pet.favorite,
			giantSize=pet.giantSize,mutation=pet.mutation,
			slot=self:FindSlot(pet.id),selected=selected[pet.id]==true,deployed=deployed[pet.id]==true,
			canSell=canSell,saleReason=reason,income=self:DisplayedPetIncome(pet.species,pet.stars,pet.level,pet.mutation),home=self:IsPetHome(pet.id),
			eggsPerSecond=self:PetEggRate(pet.species,pet.stars,pet.level,pet.mutation),
			nextIncome=if (pet.level or 1)<Config.MaxPetLevel then self:DisplayedPetIncome(pet.species,pet.stars,(pet.level or 1)+1,pet.mutation) else nil,
			upgradePrice=Rules.ChickenUpgradePrice(pet.species,pet.level or 1),canUpgrade=canUpgrade,upgradeReason=upgradeReason,
			levelCap=rank.levelCap,upgradeLocked=not canUpgrade,
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
			offer.advice,offer.improvesArmy=self:OfferAdvice(offer.species,offer.level,offer.mutation)
			table.insert(offers,offer)
		end
	end
	local offer=offers[1]
	local campsWon=0
	for i=1,#Progression.Camps(1) do if self.firstWins[i] then campsWon+=1 end end
	local eggProduction=self:EggProductionMultiplier()
	local income=self:EarnedAmount(self:Income()*eggProduction,"eggs")*(1+(self.territoryBonus or 0))
	return {research=ResearchService.Snapshot(self,os.time()),nextSlot=self:NextSlot(),
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
		mergeUnlocked=mergeUnlocked,mergeRequirement=mergeRequirement,
		campsWon=campsWon,allCampsWon=self:Completed(),territoryBonus=self.territoryBonus or 0,
		userId=self.userId,name=self.name,plotIndex=self.plotIndex,revision=self.revision,
		coins=self.coins,starterCashReserve=self:StarterCashReserve(),starterArmyReserve=self:StarterArmyReserve(),
		starterRecruitPrice=if self:StarterRecruitPending() then Config.Economy.StarterRecruitPrice else 0,
		income=income,eggUnitValue=Rules.EggUnitValue(self.incomeLevel)*(1+self.researchEffects.eggValue),
		homeEggsPerSecond=self:Income()/(Rules.EggUnitValue(self.incomeLevel)*(1+self.researchEffects.eggValue))*eggProduction,
		capacity=self:Capacity(),baseCapacity=self.capacity,count=#pets,pets=pets,discovered=table.clone(self.discovered),
		collectionLimit=self:CollectionLimit(),selectedIds=best,deployedIds=deployedIds,
		selectionMode=if self.armySelection==nil then "Auto" else "Manual",
		selectedCount=#best,deployedCount=#deployedIds,overflowCount=math.max(0,#pets-self:CollectionLimit()),
		offer=offer,offers=offers,rollSlotCount=self.rollSlotCount or 1,rollRemaining=math.max(0,self.rollReadyAt-now),odds=Rules.Odds(self.luck,self.recruitTier,self:PaidLuckMultiplier(),self.researchEffects.rollingLuck),luck=self.luck,
		campUnlocked=self.campUnlocked,armyState=self.armyState,outgoing=self.outgoing,incoming=self.incoming,stationedAt=self.stationedAt,
		returnRemaining=math.max(0,self.returnAt-now),passiveEarned=self.passiveEarned,battleEarned=self.battleEarned,
		power=Rules.Power(self:Lineup()),deployed=#deployedIds,lastResult=self.lastResult,banner=self.banner,
		rebirth=RebirthService.Quote(self),giantPity=self.giantPity or 0,
		daily={streak=self.daily.streak,lastDay=self.daily.lastDay,best=self.daily.best,
			granted=if self.dailyGranted then table.clone(self.dailyGranted) else nil}}
end

-- The data envelope/lease belongs to DataService. This object owns its serializable player values.
function PlayerSession:ToData()
 local armySelection
 if self.armySelection~=nil then
  armySelection=self:FilterArmyIds(self.armySelection,self.capacity+ShopCatalog.ArmyBonus)
 end
	local pets={}
	for _,pet in self.pets do table.insert(pets,{id=pet.id,species=pet.species,level=pet.level,favorite=pet.favorite,collected=pet.collected or 0,
		giantSize=pet.giantSize,mutation=pet.mutation,
		investment=pet.investment or Rules.Investment(pet.species,pet.level)}) end
	for _,raw in self.unrecognizedPets or {} do table.insert(pets,table.clone(raw)) end
	table.sort(pets,function(a,b) return a.id<b.id end)
	local discovered=table.clone(self.discovered)
	for species in self.unrecognizedDiscovered or {} do discovered[species]=true end
	local wins={}
	for index,won in self.firstWins do if won then table.insert(wins,index) end end
	table.sort(wins)
 local frontier={}
 for i,won in self.frontierWins do if won then table.insert(frontier,i) end end
 table.sort(frontier)
	return {research=ResearchRules.Copy(self.research),dataRevision=Config.DataRevision,legacyCapacityGrant=self.legacyCapacityGrant or 0,
		purchaseReceipts=table.clone(self.purchaseReceipts),crateCredits=self.crateCredits,commerceAutomatic=table.clone(self.commerceAutomatic),
		guaranteedLuckRolls=self.guaranteedLuckRolls,
		eggCarry=table.clone(self.eggCarry),enemyKills=self.enemyKills,robuxSpent=self.robuxSpent,
		eggProcessor=EggProcessor.Copy(self.eggProcessor),
		offlineCash=table.clone(self.offlineCash),
		promotion=self.promotion,recruitTier=self.recruitTier,
		coins=self.coins,capacity=self.capacity,luck=self.luck,incomeLevel=self.incomeLevel,
		armySelection=armySelection,
		eggSpeedLevel=self.eggSpeedLevel,plotSizeLevel=self.plotSizeLevel,rollSlotsUnlocked=self.rollSlotsUnlocked,
		pets=pets,discovered=discovered,firstWins=wins,laneCamps=table.clone(self.laneCamps or {}),adminAssisted=self.adminAssisted==true,frontierWins=frontier,kingCleared=self.kingCleared,kingBountyPaid=self.kingBountyPaid==true,tutorial=table.clone(self.tutorial),
		hillWins=self.hillWins,hillRollCredits=self.hillRollCredits,hillChampion=self.hillChampion==true,
		fusionUnlockVersion=2,
		fusionUnlocked=self.fusionUnlocked==true or self.research.completed.FuseMachine==true,
		passiveEarned=self.passiveEarned,battleEarned=self.battleEarned,
		rebirths=self.rebirths,daily=table.clone(self.daily),giantPity=self.giantPity or 0}
end

local function numberIn(value,minimum,maximum,integer)
 return type(value)=="number" and value==value and value>=minimum and value<=maximum and (not integer or value%1==0)
end

-- Counters and balances that only grew too large are repaired to their bound.
-- Wrong types, NaN, negatives and fractional counters still reject the profile.
local function clampHigh(value,minimum,maximum,integer)
 if numberIn(value,minimum,maximum,integer) then return value end
 if type(value)=="number" and value==value and value>maximum then return maximum end
 return nil
end

-- Additive October 13 field. Never rejects a profile: malformed entries are
-- dropped and at most 100 lanes are kept (the most beaten). laneWins is the
-- same day's first draft (highest camp, in-order lanes) read as camps 1..N.
local function readLaneCamps(masks, counts)
	local camps=#Progression.Camps(1)
	local full=2^camps-1
	local merged={}
	local function valid(key) return type(key)=="string" and #key<=20 and key:match("^%-?%d+$")~=nil end
	if type(counts)=="table" then
		for key,count in counts do
			if valid(key) and numberIn(count,1,camps,true) then merged[key]=2^count-1 end
		end
	end
	if type(masks)=="table" then
		for key,mask in masks do
			if valid(key) and numberIn(mask,1,full,true) then merged[key]=bit32.bor(merged[key] or 0,mask) end
		end
	end
	local kept={}
	for key,mask in merged do
		local beaten=0;for i=1,camps do if bit32.btest(mask,2^(i-1)) then beaten+=1 end end
		table.insert(kept,{key=key,mask=mask,beaten=beaten})
	end
	table.sort(kept,function(a,b) return if a.beaten~=b.beaten then a.beaten>b.beaten else a.key<b.key end)
	local result={}
	for index,entry in kept do
		if index>100 then break end
		result[entry.key]=entry.mask
	end
	return result
end

-- Additive launch fields (docs/team/LAUNCH_CHANGE_PLAN.md §3). Never reject a profile.
local function readRebirths(value): number
	if not numberIn(value,0,2^53-1,true) then return 0 end
	-- A rank above a later, lower MaxRank keeps the highest rank instead of resetting.
	return math.min(value,Config.Rebirth.MaxRank)
end

local function readDaily(value)
	local daily={streak=0,lastDay=0,best=0}
	if type(value)~="table" then return daily end
	for key in daily do
		local n=value[key]
		if numberIn(n,0,2^53-1,true) then daily[key]=n end
	end
	return daily
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
-- the new Bucket Bastion and must never grant its first win. Before October 13
-- a mid-march redirect could win a later camp first; those gaps load as saved.
local function readProgress(data, revision)
	if revision>=6 then return readWins(data.firstWins,#Progression.Camps(1),true) end
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
 local guaranteedLuckRolls=clampHigh(data.guaranteedLuckRolls or 0,0,1e12,true)
 if not guaranteedLuckRolls then return false,"Invalid saved guaranteed-offer progress." end
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
	local rollSlotsUnlocked = if data.rollSlotsUnlocked == nil then 6 else data.rollSlotsUnlocked
	-- Revision 11 prepends three plot purchases. Validate the old domain before
	-- converting, and commit/stamp only after the complete profile validates.
	local oldPlotProgress = revision < 11
	if not numberIn(eggSpeedLevel,0,#UpgradeCatalog.EggSpeedPrices,true)
		or not numberIn(plotSizeLevel,0,if oldPlotProgress then 4 else #UpgradeCatalog.PlotPrices,true)
		or not numberIn(rollSlotsUnlocked,1,Config.RollSlotsUnlocked,true) then
		return false,"Invalid saved board upgrades."
	end
	if oldPlotProgress then plotSizeLevel += 3 end
	local legacy=revision==1
	-- New carried eggs are distinct from the already-converted revision-1 egg bag.
	local carry=data.eggCarry or {count=0,value=0}
	local processor=EggProcessor.Read(data.eggProcessor)
	if not processor then return false,"Invalid saved egg processor." end
	local research=ResearchRules.Read(data.research)
	if not research then return false,"Invalid saved research." end
	local offlineCash=OfflineCash.Read(data.offlineCash)
	if not offlineCash then return false,"Invalid saved offline cash." end
	local carryCount=if type(carry)=="table" then clampHigh(carry.count,0,PlayerSession.CarryLimit,true) else nil
	local carryValue=if type(carry)=="table" then clampHigh(carry.value,0,PlayerSession.CarryLimit,true) else nil
	local enemyKills=clampHigh(data.enemyKills or 0,0,1e12,true)
	local robuxSpent=clampHigh(data.robuxSpent or 0,0,1e12,true)
	-- Additive Hill fields (October 10): missing means none earned yet.
	local hillWins=clampHigh(data.hillWins or 0,0,1e9,true)
	local hillRollCredits=clampHigh(data.hillRollCredits or 0,0,1e6,true)
	if not hillWins or not hillRollCredits or (data.hillChampion~=nil and type(data.hillChampion)~="boolean") then
		return false,"Invalid saved Hill progress."
	end
	if not carryCount or not carryValue or ((carryCount==0)~=(carryValue==0))
		or not enemyKills or not robuxSpent then return false,"Invalid saved eggs, defeat or Robux count." end
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
	local coins=clampHigh(data.coins,0,Currency.MaxCoins)
	if not coins or not numberIn(capacity,Config.StartingSlots,Config.MaxSlots,true)
		or not table.find(Config.SlotLevels,capacity) or grant>capacity or not numberIn(data.luck,0,#Config.LuckPrices,true)
		or not numberIn(data.incomeLevel,0,#Config.IncomePrices,true) or type(data.pets)~="table" or #data.pets>Config.LegacyCollectionLimit
		or type(data.tutorial)~="table" then return false,"Invalid saved profile." end
	local converted=0
	if legacy then
		if not numberIn(data.eggBagCount or 0,0,1e12,true) or not numberIn(data.eggBagValue or 0,0,1e12) then return false,"Invalid saved egg bag." end
		converted=data.eggBagValue or 0
	end
	local pets,count={},0
	local unrecognizedPets,unknownIds={},{}
	for index,pet in data.pets do
		count+=1
		if not numberIn(index,1,#data.pets,true) or type(pet)~="table" or type(pet.id)~="string" or #pet.id<1 or #pet.id>64
			or not utf8.len(pet.id) or pets[pet.id] or unknownIds[pet.id] or type(pet.species)~="string" or #pet.species>64
			then return false,"Invalid saved chicken." end
		if not table.find(Catalog.Order,pet.species) then
			-- A species removed by a later build: skip it here, keep its raw entry for the next save.
			if legacy then return false,"Invalid saved chicken." end
			unknownIds[pet.id]=true;table.insert(unrecognizedPets,table.clone(pet))
			continue
		end
		local collected=clampHigh(pet.collected or 0,0,1e12)
		if type(pet.favorite)~="boolean" or not collected then return false,"Invalid saved chicken." end
		if legacy then
			if not numberIn(pet.cash or 0,0,1e10) or not numberIn(pet.eggCount or 0,0,1e6,true)
				or not numberIn(pet.eggTimer or 0,0,Config.LegacyEggLaySeconds) then return false,"Invalid saved egg value." end
			converted+=pet.cash or 0
		end
		local level=if revision<3 then 1 else pet.level
		if not numberIn(level,1,Config.MaxPetLevel,true) then return false,"Invalid saved chicken level." end
		if pet.giantSize~=nil and not Giant.IsValidSize(pet.giantSize) then return false,"Invalid saved Giant size." end
		local investment=if revision<5 then Rules.Investment(pet.species,level,true) else pet.investment
		investment=clampHigh(investment,0,1e12)
		if not investment then return false,"Invalid saved chicken investment." end
		-- Additive launch field: an unknown or malformed mutation is dropped, never the chicken.
		pets[pet.id]={id=pet.id,species=pet.species,stars=1,level=level,giantSize=pet.giantSize,favorite=pet.favorite,collected=math.ceil(collected),investment=math.ceil(investment),
			mutation=if MutationCatalog.IsValid(pet.mutation) then pet.mutation else nil}
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
				or type(id)~="string" or not (pets[id] or unknownIds[id]) or seen[id] then
				return false,"Invalid saved army selection."
			end
			seen[id]=true
			if pets[id] then table.insert(armySelection,id) end
		end
		if entries~=#data.armySelection then return false,"Invalid saved army selection." end
	end
	-- Additive field in the current envelope: older saves seed their owned flock.
	-- Discovery survives sale/merge; an unbought roll offer never adds an entry.
	local discovered, unrecognizedDiscovered = {}, {}
	if data.discovered ~= nil then
		if type(data.discovered) ~= "table" then return false,"Invalid saved chicken index." end
		for species, collected in data.discovered do
			if type(species) ~= "string" or #species > 64 or type(collected) ~= "boolean" then
				return false,"Invalid saved chicken index."
			end
			-- Unknown index entries are preserved for the next save, not shown.
			if collected then
				if table.find(Catalog.Order, species) then discovered[species] = true else unrecognizedDiscovered[species] = true end
			end
		end
	end
	for _, pet in pets do discovered[pet.species] = true end
	local wins=readProgress(data,revision)
	if not wins then return false,"Invalid saved camp progress." end
	if data.fusionUnlocked~=nil and type(data.fusionUnlocked)~="boolean" then return false,"Invalid saved fusion access." end
	-- Additive field: older saves read as unpaid.
	if data.kingBountyPaid~=nil and type(data.kingBountyPaid)~="boolean" then return false,"Invalid saved King bounty." end
	if data.fusionUnlockVersion~=nil and data.fusionUnlockVersion~=2 then return false,"Unsupported saved fusion unlock version." end
	-- Only pre-research saves inherit the old missing-field/camp entitlement.
	-- Version 2 prevents future captures from granting access after a rejoin.
	local legacyFusion=data.fusionUnlockVersion==nil and (data.fusionUnlocked==nil or wins[1]==true)
	local fusionUnlocked=data.fusionUnlocked==true or legacyFusion or research.completed.FuseMachine==true
	if fusionUnlocked and ResearchRules.Job(research,"FuseMachine") then return false,"Invalid saved fusion research." end
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
	for _,key in {"emptyStart","starterArmy","rolled","bought","collected","collectedEggs","soldEggs","wonCamp","returned","upgraded","guideStarted","guideSkipped","guideDeployed","guideCompleted","introSeen","goalsHidden"} do tutorial[key]=data.tutorial[key]==true end
	local collectedEggCount=data.tutorial.collectedEggCount
	if collectedEggCount==nil then
		-- Existing saves already passed the one-egg lesson when they collected,
		-- sold or completed it. Only new/unfinished profiles begin counting at zero.
		collectedEggCount=if tutorial.collectedEggs or carryCount>0 or tutorial.soldEggs
			or tutorial.wonCamp or tutorial.guideCompleted then TutorialGuide.EggGoal else 0
	else
		collectedEggCount=clampHigh(collectedEggCount,0,1e12,true)
		if not collectedEggCount then return false,"Invalid saved tutorial egg count." end
	end
	tutorial.collectedEggCount=math.min(collectedEggCount,TutorialGuide.EggGoal)
	tutorial.collectedEggs=tutorial.collectedEggCount>=TutorialGuide.EggGoal
	local passiveEarned=clampHigh(data.passiveEarned or 0,0,Currency.MaxCoins)
	local battleEarned=clampHigh(data.battleEarned or 0,0,Currency.MaxCoins)
	if not passiveEarned or not battleEarned then return false,"Invalid saved earnings." end
	-- Display retained access as completed research without charging or granting
	-- unrelated research. Earned access keeps FuseMachine even without its R1 chain.
	if fusionUnlocked then research.completed.FuseMachine=true end
	-- Commit only after every field validates. Old egg values were already valued;
	-- never multiply them again, and omit them from the current save payload.
	self.purchaseReceipts,self.crateCredits,self.commerceAutomatic=receipts,data.crateCredits or 0,automatic
	self.guaranteedLuckRolls=guaranteedLuckRolls%(ShopCatalog.GuaranteedLuck.interval*#ShopCatalog.GuaranteedLuck.sequence)
	self.dataRevision,self.legacyCapacityGrant=Config.DataRevision,grant
	self.eggSpeedLevel,self.plotSizeLevel,self.rollSlotsUnlocked=eggSpeedLevel,plotSizeLevel,rollSlotsUnlocked
	self.eggCarry={count=carryCount,value=carryValue};self.enemyKills=enemyKills;self.robuxSpent=robuxSpent
	self.eggProcessor=processor
	self.offlineCash,self.offlineCashReceipt=offlineCash,nil
	self.research=research;self.researchEffects=ResearchRules.Effects(research)
	self.researchRecap={};self.rallyActiveUntil=0
	ResearchService.Complete(self,os.time())
	-- Preserve saved ranks and validation; always use the best earned odds now.
	self.promotion,self.recruitTier=promotion,promotion
 self.frontierWins,self.kingCleared=frontier,king
 self.kingBountyPaid=data.kingBountyPaid==true
 self.hillWins,self.hillRollCredits,self.hillChampion=hillWins,hillRollCredits,data.hillChampion==true
 -- Additive launch fields: missing or malformed values read as their defaults.
 self.rebirths=readRebirths(data.rebirths)
 self.daily=readDaily(data.daily)
 self.dailyGranted=nil
 -- Additive October 14 field: anything but a whole number below the guarantee reads as 0.
 self.giantPity=if numberIn(data.giantPity,0,Giant.PityLimit-1,true) then data.giantPity else 0
	-- Preserve old saves: round any historical cents up once, never reset progress.
	self.coins,self.capacity,self.luck,self.incomeLevel=math.min(Currency.MaxCoins,math.ceil(coins+converted)),capacity,data.luck,data.incomeLevel
	self.pets,self.slots,self.firstWins,self.tutorial=pets,{},wins,tutorial
	self.laneCamps=readLaneCamps(data.laneCamps,data.laneWins)
	-- Additive field; anything but true reads as false.
	self.adminAssisted=data.adminAssisted==true
	self.fusionUnlocked=fusionUnlocked
	self.armySelection=if armySelection then self:FilterArmyIds(armySelection,capacity+ShopCatalog.ArmyBonus) else nil
	self.discovered = discovered
	self.unrecognizedPets,self.unrecognizedDiscovered=unrecognizedPets,unrecognizedDiscovered
	if #unrecognizedPets>0 or next(unrecognizedDiscovered) then
		warn("[PetRoll] Profile "..tostring(self.userId).." keeps "..#unrecognizedPets.." unrecognized saved chickens for a later build.")
	end
	self.passiveEarned,self.battleEarned=math.ceil(passiveEarned),math.ceil(battleEarned)
	self.armyState,self.outgoing,self.incoming,self.defending="Home",nil,nil,nil
	self.returnAt,self.stationedAt=0,nil
	self.campUnlocked=1
	while self.firstWins[self.campUnlocked] and self.campUnlocked<#Progression.Camps(1) do self.campUnlocked+=1 end
	self.offer,self.offers=nil,{}
	self:UnlockProgress();self:RefreshArmy();self:Touch()
	return true,if legacy then "Loaded and converted stored egg value to cash." else "Loaded."
end

function PlayerSession:Destroy()
	self.pets, self.slots = {}, {}
end

return PlayerSession
