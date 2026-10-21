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
local AutoRollRules = require(Shared.AutoRollRules)
local GemUpgradeCatalog = require(Shared.GemUpgradeCatalog)
local RebirthService = require(script.Parent.RebirthService)
local GoldRushService = require(script.Parent.GoldRushService)
local RebirthChickens = require(script.Parent.RebirthChickens)
local EconomyMigration = require(script.Parent.EconomyMigration)
local TreeMigrations = require(script.Parent.TreeMigrations)
local PlaytimeService = require(script.Parent.PlaytimeService)
local PlayerSession = {}
PlayerSession.__index = PlayerSession
-- Saved eggCarry bound. EggService stops pickups before reaching it; older servers reject above it.
PlayerSession.CarryLimit = 1e12
-- Saved tutorial flags. To persist a new one, add it here (one word) and list it in
-- your hand-off (docs/team/OVERHAUL_CONTRACT_20261020.md §2).
local TUTORIAL_KEYS = {"emptyStart","starterArmy","rolled","bought","collected","collectedEggs","soldEggs","wonCamp",
	"returned","upgraded","guideStarted","guideSkipped","guideDeployed","guideCompleted","introSeen","goalsHidden","hillIntroSeen",
	"vacuumUsed"}

function PlayerSession.new(userId: number, name: string, plotIndex: number)
	local self = setmetatable({}, PlayerSession)
	self.userId, self.name, self.plotIndex = userId, name, plotIndex
	self.revision = 0
	-- Verified by CommerceService per visit; never serialized or reset with coins.
	self.entitlements = {}
	-- October 20 Friend Boost (FriendBoostService): live, never saved or reset with coins.
	self.friendBoost = 0
	self:Reset()
	return self
end

function PlayerSession:Reset()
	-- A debug gameplay reset must never re-deliver an acknowledged purchase.
	self.purchaseReceipts=self.purchaseReceipts or {}
	self.crateCredits=self.crateCredits or 0
	self.guaranteedLuckRolls=self.guaranteedLuckRolls or 0
	self.commerceAutomatic=self.commerceAutomatic or {AutoCollectEggs=true,AutoMerge=true}
	-- Auto Roll settings (RollService.StepAuto, AutoRollRules); held/skipped are session-only.
	self.autoRoll=self.autoRoll or AutoRollRules.Default()
	self.coins = Config.StartingCoins
	-- October 20 economy (docs/team/OVERHAUL_CONTRACT_20261020.md §2). capacity, luck,
	-- eggSpeedLevel, incomeLevel, rollSlotsUnlocked and plotSizeLevel are derived from
	-- upgradeTree by RefreshEffects. Purchased Skip credits and pass gifts survive a
	-- debug reset like receipts.
	self.upgradeTree = {}
	self.gems, self.gemsEarned, self.gemUpgrades = 0, 0, {}
	self.autoRebirth = true
	self.rebirthSkips = self.rebirthSkips or 0
	self.passGemGifts = self.passGemGifts or {}
	self.rebirthChickenCredits = {}
	self.missionTierLegacy = 0
	-- Mutations a save keeps from its Rebirth rank (S9c's Mutation tree family). A new
	-- profile under that family keeps none; before it exists nil leaves the choice to
	-- the first load that has it (LoadData).
	self.mutationKeep = if UpgradeCatalog.Families.Mutation then 0 else nil :: number?
	-- Saved for S10 (Flock layers), S11 (hand vacuum) and S12 (Gold rolls).
	self.flockSelection = nil :: {string}?
	-- Legacy grant flag only: the Egg Vacuum is an Upgrades tree node now (LoadData).
	self.eggVacuum = false
	self.vacuumCargo = {count=0,value=0}
	self.goldRolls = {count=0}
	-- October 20 Playtime Rewards (S16, PlaytimeService): this visit's clock, claims and
	-- timed boosts. Live only, never saved; a new visit (or a reset) starts over.
	self.playtime,self.playtimeBoosts = nil,nil
	self.plotBuild = nil
	self.eggCarry={count=0,value=0}
	self.offlineCash = {at=0,rate=0}
	self.offlineCashReceipt = nil
	self.research=ResearchRules.New()
	self:RefreshEffects()
	self.researchRecap={}
	self.operationResult=nil
	self.rallyActiveUntil=0
	local finishCredits = if self.eggProcessor then self.eggProcessor.finishCredits else 0
	self.eggProcessor = EggProcessor.New()
	self.eggProcessor.finishCredits = finishCredits
	self.enemyKills=0
	self.robuxSpent=0 -- Lifetime Robux spent in game (leaderboard only; never a benefit)
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
	-- October 16 free gift (FreeGiftService): one chicken for joining the group. Saved.
	self.freeGiftClaimed = false
	-- October 16 chicken offers (ProductService): how many ladder steps are bought (0-6). Saved.
	self.chickenOfferStep = 0
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

-- October 20: the one effect table for the Upgrades tree and Gem Upgrades
-- (researchEffects keeps its name for existing readers), plus the derived fields
-- older code reads. Call after any change to upgradeTree or gemUpgrades.
function PlayerSession:RefreshEffects()
	local tree=self.upgradeTree
	self.researchEffects=UpgradeCatalog.Effects(tree,self.gemUpgrades)
	self.eggSpeedLevel=UpgradeCatalog.Tier(tree,"EggSpeed")
	self.incomeLevel=UpgradeCatalog.Tier(tree,"EggValue")
	self.luck=UpgradeCatalog.Tier(tree,"Luck")
	-- The tree's Army Size plus +1 Army Slot Gem Upgrades (S7b).
	self.capacity=UpgradeCatalog.Value(tree,"ArmySize")+math.max(0,math.floor(self.researchEffects.armySlots or 0))
	self.rollSlotsUnlocked=UpgradeCatalog.Value(tree,"RollSlot")
	self.plotSizeLevel=UpgradeCatalog.YardStage(tree)
end

-- The highest level Chicken Feed reaches: Config.MaxPetLevel plus feedMaxLevel (S7b).
function PlayerSession:LevelCap(): number
	return Rules.LevelCap(self.researchEffects)
end

-- Chickens out in the yard laying (Flock Size; S10 owns who they are).
function PlayerSession:FlockSize(): number
	return self.researchEffects.flockSize
end

function PlayerSession:TreeTier(family: string): number
	return UpgradeCatalog.Tier(self.upgradeTree,family)
end

function PlayerSession:GemLevel(id: string): number
	return GemUpgradeCatalog.Level(self.gemUpgrades,id)
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

-- October 20: storage is unlimited up to the hidden safety cap.
function PlayerSession:CollectionLimit(): number
 return Config.StorageLimit
end

-- October 20: every yard build is instant (the October 16 timed builds are retired).
function PlayerSession:CompletePlotBuild(_now: number): boolean
 self.plotBuild=nil
 return false
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

-- Roll Luck's research bonus (ChickenLuck) with a Playtime Rewards Luck boost (S16):
-- "+100% Luck" doubles it the way a Gold roll multiplies it.
function PlayerSession:RollLuckBonus(): number
 return (1+(self.researchEffects.rollingLuck or 0))*(1+PlaytimeService.Boost(self,"Luck"))-1
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

function PlayerSession:EarnedAmount(amount: number, source: string, steady: boolean?): number
 local earned=source=="eggs" or source=="battle" or source=="territory"
 -- Re-enlist pays a permanent egg multiplier (1 at rank 0); offline cash routes here too.
 local rebirth=if source=="eggs" then RebirthService.Multiplier(self.rebirths or 0) else 1
 -- October 20 Gem Upgrade Coin Boost: egg Coins only, offline included (S7).
 local coinBoost=if source=="eggs" then 1+(self.researchEffects.coinBoost or 0) else 1
 -- October 20 live boosts on earned Coins, counted when Coins are paid: Gold Rush
 -- (server-wide), Friend Boost and a Playtime Rewards Coins boost (S16). `steady`
 -- leaves them out (offline earnings, daily and playtime Coins).
 local live=if earned and not steady then GoldRushService.Multiplier()*(1+(self.friendBoost or 0))
  *(1+PlaytimeService.Boost(self,"Coins")) else 1
 return amount * (if earned and self.entitlements.DoubleCash then 2 else 1) * rebirth * coinBoost * live
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
	if amount<0 or amount~=amount or self.coins<amount then return false,"Not enough coins." end
	local reserve=self:StarterCashReserve()
	-- Only validated server transactions supply a purpose. Each required purchase
	-- may use its own earmark, never the money reserved for the other purchase.
	if purpose=="StarterRecruit" and self:StarterRecruitPending() and amount==Config.Economy.StarterRecruitPrice then
		reserve-=Config.Economy.StarterRecruitPrice
	elseif purpose=="ArmySize" and amount==self:StarterArmyReserve() then
		reserve-=self:StarterArmyReserve()
	end
	if self.coins-amount<reserve then
		-- October 20 launch review: once the recruit is bought, name only Army Size
		-- (1,307 refusals named a recruit the player already had).
		local reason=if not self.tutorial.starterArmy
			then "Keep "..Currency.Text(Config.Economy.StarterRecruitPrice).." for your first chicken. Roll FREE at the lever!"
			elseif self:StarterRecruitPending() then "Keep "..Currency.Text(reserve).." for your tutorial recruit and Army Size I."
			else "Keep "..Currency.Text(reserve).." for Army Size I in Upgrades."
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

-- October 20 Flock (docs/team/FLOCK_STORAGE.md): only Flock chickens lay eggs,
-- online and offline; every other chicken waits in storage. flockSelection nil is
-- automatic (the best egg layers); a list is the player's own picks, kept exactly.
-- A pick away with the Army leaves its slot to the next best layer at home.
local function flockSize(session): number
	-- Flock Size comes from the Upgrades tree (FlockSize, effect flockSize); 3 until set.
	local size=if session.FlockSize then session:FlockSize() else session.researchEffects.flockSize
	if type(size)~="number" or size~=size then return 3 end
	return math.clamp(math.floor(size),0,Config.LegacyCollectionLimit)
end

-- How many chickens lay at once (Flock Size).
function PlayerSession:FlockSlots(): number
	return flockSize(self)
end

local function layerRate(pet): number
	return Rules.EggRate(pet.species,pet.stars,pet.level)*MutationCatalog.Multiplier(pet.mutation)
end

-- The `count` best egg layers outside `skip`, at home unless `steady`: most eggs
-- first, then the stronger chicken. One pass, since storage can hold many chickens.
function PlayerSession:BestLayerIds(count: number, skip, steady: boolean?): {string}
	local best={}
	if count<=0 then return best end
	for id,pet in self.pets do
		if skip[id] or not (steady or self:IsPetHome(id)) then continue end
		local rate=layerRate(pet)
		local last=best[count]
		if last and rate<last.rate then continue end
		local entry={id=id,rate=rate,power=Rules.PetPower(pet.species,pet.stars,pet.level,pet.giantSize)}
		local index=#best+1
		while index>1 do
			local other=best[index-1]
			if entry.rate<other.rate or (entry.rate==other.rate and (entry.power<other.power
				or (entry.power==other.power and entry.id>other.id))) then break end
			index-=1
		end
		if index<=count then table.insert(best,index,entry);best[count+1]=nil end
	end
	local ids={}
	for index,entry in best do ids[index]=entry.id end
	return ids
end

-- The Flock in slot order and, unless `steady`, who lays right now: picks at home
-- plus fill-ins for picks away. `steady` counts every chicken as home (offline
-- earnings and sale protection use the picks themselves).
local function flockLayers(session,steady: boolean?): {string}
	local size=flockSize(session)
	local picks=session.flockSelection
	if picks==nil then return session:BestLayerIds(size,{},steady) end
	local valid,taken,away={},{},0
	for _,id in picks do
		if #valid>=size then break end
		if session.pets[id] and not taken[id] then
			taken[id]=true;table.insert(valid,id)
			if not steady and not session:IsPetHome(id) then away+=1 end
		end
	end
	if away==0 then return valid end
	local fills,used,ids=session:BestLayerIds(away,taken,false),0,{}
	for _,id in valid do
		if session:IsPetHome(id) then table.insert(ids,id)
		else used+=1;if fills[used] then table.insert(ids,fills[used]) end end
	end
	return ids
end

-- The Flock: the player's picks or the automatic best layers, in slot order.
function PlayerSession:FlockIds(): {string}
	return flockLayers(self,true)
end

-- Chickens laying eggs right now: Flock chickens at home plus their fill-ins.
function PlayerSession:LayingIds(): {string}
	return flockLayers(self,false)
end

-- Keeps the picks valid: chickens that left drop out, picks past a smaller Flock
-- Size (after a Rebirth) drop, and slots a bigger Flock Size adds fill with the best
-- layers. EggService runs it every step; valid picks are left untouched.
function PlayerSession:RefreshFlock(): boolean
	local size=flockSize(self)
	local previous=self.flockSizeSeen
	self.flockSizeSeen=size
	local picks=self.flockSelection
	if picks==nil then return false end
	local kept,taken={},{}
	for _,id in picks do
		if #kept<size and self.pets[id] and not taken[id] then taken[id]=true;table.insert(kept,id) end
	end
	if previous and size>previous then
		for _,id in self:BestLayerIds(math.min(size-#kept,size-previous),taken,true) do table.insert(kept,id) end
	end
	-- A Flock with no picks left would lay nothing; it goes back to automatic.
	if #kept==0 then self.flockSelection=nil;self:Touch();return true end
	if #kept==#picks then
		local same=true
		for index,id in kept do if picks[index]~=id then same=false;break end end
		if same then return false end
	end
	self.flockSelection=kept;self:Touch()
	return true
end

-- What a batch of sale checks shares: one Army sort and one Flock pass per batch.
function PlayerSession:SaleContext()
	local selected,flock={},{}
	for _,id in self:BestPetIds() do selected[id]=true end
	for _,id in self:FlockIds() do flock[id]=true end
	return {selected=selected,flock=flock,count=self:Count(),minimum=self:StarterFlockMinimum()}
end

local function saleEligibility(session,id,context): (boolean,string)
	local pet=if type(id)=="string" then session.pets[id] else nil
	if not pet then return false,"That chicken is no longer yours." end
	local minimum=context.minimum
	if minimum>0 and context.count<=minimum then
		return false,"Keep "..minimum.." "..(if minimum==1 then "chicken" else "chickens").." for your first mission."
	end
	if pet.favorite then return false,"Favorite chickens can't be sold." end
	if not session:IsPetHome(id) then return false,"Your Army is away with this chicken." end
	if context.selected[id] then return false,"Remove it from your Army first." end
	if context.flock[id] then return false,"Remove it from your Flock first." end
	return true,"Ready to sell."
end

-- Pass one SaleContext when checking many chickens at once.
function PlayerSession:SaleEligibility(id,context): (boolean,string)
	return saleEligibility(self,id,context or self:SaleContext())
end

function PlayerSession:ChickenUpgradeEligibility(id): (boolean,string)
	local pet=if type(id)=="string" and #id<=64 then self.pets[id] else nil
	if not pet then return false,"Choose a chicken from your own flock." end
	if (pet.level or 1)>=self:LevelCap() then return false,"Max level reached." end
	if not Config.Features.ChickenCashUpgrades then return false,"Fuse 3 matching chickens to level up." end
	-- October 20: levels are bought with Chicken Feed (Upgrades > Tools), reset on Rebirth.
	if (self.researchEffects.chickenFeed or 0)<1 then return false,"Buy Chicken Feed in Upgrades > Tools first." end
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

-- Physical home location: only chickens at home can lay (LayingIds).
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

-- Only chickens laying count (Flock chickens at home and their fill-ins).
function PlayerSession:Income(laying: {string}?): number
	local income=0
	for _,id in laying or self:LayingIds() do income+=self:PetIncome(id) end
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
 -- internal; the notice names the real unlock. October 15: Fuse reaches Lv 10 from
 -- the start, so a new rank only opens its camps.
 self.banner="New camps unlocked!"
 self:Touch()
 return true
end

function PlayerSession:Completed(): boolean
	for i=1,#Progression.Camps(1) do if not self.firstWins[i] then return false end end
	return true
end

-- The next Army Size tier (the tutorial reserve's Army Size 4 is tier 1).
-- Deployment upgrades depend on Coins and the tree, never conquest.
function PlayerSession:NextSlot()
 local tier=UpgradeCatalog.Tier(self.upgradeTree,"ArmySize")+1
 local entry=UpgradeCatalog.Families.ArmySize.tiers[tier]
 if not entry then return nil end
 local capacity=entry.value+math.max(0,math.floor(self.researchEffects.armySlots or 0))
 return {capacity=capacity,displayCapacity=capacity+(if self.entitlements.BiggerArmy then ShopCatalog.ArmyBonus else 0),
  price=UpgradeCatalog.Price("ArmySize",tier,self.rebirths),unlocked=true,requirement="Buy one more Army slot",tier=tier}
end

-- Next Egg Value ("Income") or Luck tier, for older snapshot readers.
function PlayerSession:GlobalUpgrade(kind: string)
	local family=if kind=="Income" then "EggValue" else "Luck"
	local price=UpgradeCatalog.Price(family,UpgradeCatalog.Tier(self.upgradeTree,family)+1,self.rebirths)
	if not price then return nil end
	return {price=price,unlocked=true,requirement=""}
end

-- Compare a reveal to the Army the player picked, the same rule as Auto Roll's
-- Army-upgrade stop: an open slot counts only while the Army is automatic, where a
-- recruit joins it. Pass BestPetIds when advising several offers.
function PlayerSession:OfferAdvice(species: string, level: number?, mutation: string?, army: {string}?): (string, boolean)
	local picked=army or self:BestPetIds()
	if #picked==0 or (self.armySelection==nil and #picked<self:Capacity()) then
		return "Fills an army slot",true
	end
	local weakest=math.huge
	for _,id in picked do
		local pet=self.pets[id]
		if pet then weakest=math.min(weakest,Rules.PetPower(pet.species,pet.stars,pet.level,pet.giantSize)) end
	end
	if Rules.PetPower(species,1,level)>weakest then
		return "Makes your army stronger",true
	end
	local income=self:DisplayedPetIncome(species,1,level,mutation)
	return "Lays eggs worth "..Currency.Rate(income).."/s in your Flock",false
end

-- Snapshot entries for every chicken. An entry is rebuilt only when a value shown
-- for it changes, and petsVersion moves only then: storage can hold up to
-- Config.StorageLimit chickens, so GameServer resends the list only on a change.
local PET_FIELDS={"species","stars","level","favorite","giantSize","mutation","slot","selected","deployed","home",
	"flock","laying","canSell","saleReason","income","eggsPerSecond","upgradePrice","canUpgrade","upgradeReason",
	"levelCap","investment","refund"}
local petsSerial=0 -- Server-wide, so two lists never share a version.

function PlayerSession:PetEntries(best: {string}, deployedIds: {string}, flock: {string}, laying: {string})
	local context={selected={},flock={},count=self:Count(),minimum=self:StarterFlockMinimum()}
	local deployed,layers={},{}
	for _,id in best do context.selected[id]=true end
	for _,id in flock do context.flock[id]=true end
	for _,id in deployedIds do deployed[id]=true end
	for _,id in laying do layers[id]=true end
	-- Shared factors, once per snapshot instead of once per chicken.
	local production=self:EggProductionMultiplier()
	local value=self:EarnedAmount(production*(1+self.researchEffects.eggValue),"eggs")
	local previous,entries,changed,shown=self.petEntries or {},{},false,{}
	for id,pet in self.pets do
		local level=pet.level or 1
		local mutation=MutationCatalog.Multiplier(pet.mutation)
		local canSell,saleReason=saleEligibility(self,id,context)
		local canUpgrade,upgradeReason=self:ChickenUpgradeEligibility(id)
		shown.species,shown.stars,shown.level,shown.favorite=pet.species,pet.stars,pet.level,pet.favorite
		shown.giantSize,shown.mutation,shown.slot=pet.giantSize,pet.mutation,self:FindSlot(id)
		shown.selected,shown.deployed,shown.home=context.selected[id]==true,deployed[id]==true,self:IsPetHome(id)
		shown.flock,shown.laying,shown.canSell,shown.saleReason=context.flock[id]==true,layers[id]==true,canSell,saleReason
		shown.income=Rules.Income(pet.species,pet.stars,level,self.incomeLevel)*mutation*value
		shown.eggsPerSecond=Rules.EggRate(pet.species,pet.stars,level)*production*mutation
		local levelCap=self:LevelCap()
		shown.upgradePrice=if level<levelCap then Rules.ChickenUpgradePrice(pet.species,level) else nil
		shown.canUpgrade,shown.upgradeReason=canUpgrade,upgradeReason
		shown.levelCap,shown.investment=levelCap,pet.investment
		shown.refund=Rules.SellValue(pet.investment or Rules.Investment(pet.species,pet.level))
		local entry=previous[id]
		if entry then
			for _,field in PET_FIELDS do if entry[field]~=shown[field] then entry=nil;break end end
		end
		if not entry then entry=table.clone(shown);entry.id=id;changed=true end
		entries[id]=entry
	end
	if not changed then for id in previous do if not entries[id] then changed=true;break end end end
	self.petEntries=entries
	if changed or not self.petList then
		local list={}
		for _,entry in entries do table.insert(list,entry) end
		table.sort(list,function(a,b)
			if a.species~=b.species then return a.species<b.species end
			if a.stars~=b.stars then return a.stars>b.stars end
			return a.id<b.id
		end)
		petsSerial+=1
		self.petList,self.petsVersion=list,petsSerial
	end
	return self.petList
end

-- My Army and the HUD: ids is the Flock in slot order, laying is who lays right now.
function PlayerSession:FlockSnapshot(flock: {string}, laying: {string}, production: number)
	local eggs=0
	for _,id in laying do local pet=self.pets[id];if pet then eggs+=layerRate(pet) end end
	return {size=flockSize(self),mode=if self.flockSelection==nil then "Auto" else "Manual",
		ids=flock,laying=laying,eggsPerSecond=eggs*production}
end

function PlayerSession:Snapshot(now: number)
	local rank=Progression.Get(self.promotion)
	local best=self:BestPetIds()
	local deployedIds={}
	if self:IsArmyLocked() then
		for _,pet in self:Lineup() do table.insert(deployedIds,pet.id) end
	end
	local flock,laying=self:FlockIds(),self:LayingIds()
	local pets=self:PetEntries(best,deployedIds,flock,laying)
	local offers={}
	for slot=1,self.rollSlotCount or 1 do
		local value=self.offers and self.offers[slot]
		if value then
			local offer=table.clone(value);offer.slot=slot
			offer.advice,offer.improvesArmy=self:OfferAdvice(offer.species,offer.level,offer.mutation,best)
			table.insert(offers,offer)
		end
	end
	local offer=offers[1]
	local campsWon=0
	for i=1,#Progression.Camps(1) do if self.firstWins[i] then campsWon+=1 end end
	local eggProduction=self:EggProductionMultiplier()
	local layingIncome=self:Income(laying)
	local income=self:EarnedAmount(layingIncome*eggProduction,"eggs")*(1+(self.territoryBonus or 0))
	return {research=ResearchService.Snapshot(self,os.time()),nextSlot=self:NextSlot(),
		progression={rank=self.promotion,name=rank.name,total=Progression.Count(),capacityCap=Config.MaxSlots+(if self.entitlements.BiggerArmy then ShopCatalog.ArmyBonus else 0),
			levelCap=self:LevelCap(),ready=false,
            goal=Progression.NextGoal(self.firstWins,self.frontierWins,self.kingCleared),
            requirement=Progression.Requirement(math.min(self.promotion+1,4)),
			nextName=if self.promotion<Progression.Count() then Progression.Get(self.promotion+1).name else nil,
			recruitTier=self.recruitTier,recruitName=Progression.Get(self.recruitTier).name,
			nextUnlock=Progression.NextGoal(self.firstWins,self.frontierWins,self.kingCleared)},
		incomeUpgrade=self:GlobalUpgrade("Income"),luckUpgrade=self:GlobalUpgrade("Luck"),
		frontierWins=table.clone(self.frontierWins),kingCleared=self.kingCleared,
        firstWins=table.clone(self.firstWins),homeCount=#laying,reserveCount=#pets-#best,homeIncome=income,incomeLevel=self.incomeLevel,
		offlineCash=if self.offlineCashReceipt then table.clone(self.offlineCashReceipt) else nil,
		autoRoll={enabled=self.autoRoll.enabled==true,stopAt=self.autoRoll.stopAt,
			recruitAt=self.autoRoll.recruitAt,mutationStop=self.autoRoll.mutationStop~=false,
			unlocked=(self.researchEffects.autoRoll or 0)>=1,holding=self.autoRoll.heldOffer~=nil},
		-- October 20 economy (contract §8); GameServer adds upgradeTree and gemUpgrades.
		gems=self.gems,gemsEarned=self.gemsEarned,effects=table.clone(self.researchEffects),
		-- Rally timing (server epoch seconds) outside the retired research snapshot (S9).
		rally={readyAt=self.research.rallyReadyAt or 0,activeUntil=self.rallyActiveUntil or 0},
		tutorial=table.clone(self.tutorial),saveStatus=self.saveStatus,saveMessage=self.saveMessage,
		-- October 20: Fuse is removed; always false until the last readers (the old
		-- My Army hint and the guide's Fuse goal) are gone. fusionUnlocked still saves.
		mergeUnlocked=false,
		campsWon=campsWon,allCampsWon=self:Completed(),territoryBonus=self.territoryBonus or 0,
		userId=self.userId,name=self.name,plotIndex=self.plotIndex,revision=self.revision,
		coins=self.coins,starterCashReserve=self:StarterCashReserve(),starterArmyReserve=self:StarterArmyReserve(),
		starterRecruitPrice=if self:StarterRecruitPending() then Config.Economy.StarterRecruitPrice else 0,
		income=income,eggUnitValue=Rules.EggUnitValue(self.incomeLevel)*(1+self.researchEffects.eggValue),
		homeEggsPerSecond=layingIncome/(Rules.EggUnitValue(self.incomeLevel)*(1+self.researchEffects.eggValue))*eggProduction,
		capacity=self:Capacity(),baseCapacity=self.capacity,count=#pets,pets=pets,discovered=table.clone(self.discovered),
		petsVersion=self.petsVersion,flock=self:FlockSnapshot(flock,laying,eggProduction),
		collectionLimit=self:CollectionLimit(),selectedIds=best,deployedIds=deployedIds,
		selectionMode=if self.armySelection==nil then "Auto" else "Manual",
		selectedCount=#best,deployedCount=#deployedIds,overflowCount=math.max(0,#pets-self:CollectionLimit()),
		offer=offer,offers=offers,rollSlotCount=self.rollSlotCount or 1,rollRemaining=math.max(0,self.rollReadyAt-now),odds=Rules.Odds(self.luck,self.recruitTier,self:PaidLuckMultiplier(),self:RollLuckBonus()),luck=self.luck,
		campUnlocked=self.campUnlocked,armyState=self.armyState,outgoing=self.outgoing,incoming=self.incoming,stationedAt=self.stationedAt,
		returnRemaining=math.max(0,self.returnAt-now),passiveEarned=self.passiveEarned,battleEarned=self.battleEarned,
		power=Rules.Power(self:Lineup()),deployed=#deployedIds,lastResult=self.lastResult,banner=self.banner,
		rebirth=RebirthService.Quote(self),giantPity=self.giantPity or 0,
		freeGift={enabled=Config.FreeGift.Enabled==true,claimed=self.freeGiftClaimed==true,species=Config.FreeGift.Species,groupId=Config.FreeGift.GroupId},
		chickenOfferStep=self.chickenOfferStep or 0,
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
		giantSize=pet.retiredGiantSize,mutation=pet.mutation,cashLevels=pet.cashLevels,
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
		autoRoll=AutoRollRules.Save(self.autoRoll),
		guaranteedLuckRolls=self.guaranteedLuckRolls,
		-- October 20 economy (docs/team/OVERHAUL_CONTRACT_20261020.md §2). The derived
		-- capacity/luck/... fields below are written for reference only.
		upgradeTree=table.clone(self.upgradeTree),gems=self.gems,gemsEarned=self.gemsEarned,
		gemUpgrades=table.clone(self.gemUpgrades),autoRebirth=self.autoRebirth==true,rebirthSkips=self.rebirthSkips,
		rebirthChickenCredits=table.clone(self.rebirthChickenCredits),passGemGifts=table.clone(self.passGemGifts),
		missionTierLegacy=self.missionTierLegacy,mutationKeep=self.mutationKeep,
		upgradeTreeVersion=TreeMigrations.Version,
		flockSelection=if self.flockSelection then table.clone(self.flockSelection) else nil,
		eggVacuum=self.eggVacuum==true,vacuumCargo=table.clone(self.vacuumCargo),goldRolls=table.clone(self.goldRolls),
		eggCarry=table.clone(self.eggCarry),enemyKills=self.enemyKills,robuxSpent=self.robuxSpent,
		eggProcessor=EggProcessor.Copy(self.eggProcessor),
		offlineCash=table.clone(self.offlineCash),
		promotion=self.promotion,recruitTier=self.recruitTier,
		coins=self.coins,capacity=self.capacity,luck=self.luck,incomeLevel=self.incomeLevel,
		armySelection=armySelection,
		eggSpeedLevel=self.eggSpeedLevel,plotSizeLevel=self.plotSizeLevel,rollSlotsUnlocked=self.rollSlotsUnlocked,
		pets=pets,discovered=discovered,firstWins=wins,laneCamps=table.clone(self.laneCamps or {}),adminAssisted=self.adminAssisted==true,freeGiftClaimed=self.freeGiftClaimed==true,chickenOfferStep=self.chickenOfferStep or 0,frontierWins=frontier,kingCleared=self.kingCleared,kingBountyPaid=self.kingBountyPaid==true,tutorial=table.clone(self.tutorial),
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

-- A saved whole-number count; anything malformed reads as 0, too large clamps.
local function readCount(value,maximum): number
 if type(value)~="number" or value~=value or value<0 then return 0 end
 return math.min(math.floor(value),maximum)
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
 -- Auto Roll settings (October 20, S12): "1 in X" stop and recruit values. AutoRollRules
 -- reads them leniently and converts older rarity names; it never fails a load.
 local autoRoll=AutoRollRules.Read(data.autoRoll)
 local revision=data.dataRevision or 1
	if not numberIn(revision,1,Config.DataRevision,true) then return false,"Unsupported saved profile revision." end
	-- October 20: revision ≤ 11 saves hold the old cash tracks and research.
	-- EconomyMigration converts them once, after the whole profile validates.
	local legacyEconomy=revision<12
	local Legacy=EconomyMigration.Legacy
	local eggSpeedLevel,rollSlotsUnlocked=0,1
	if legacyEconomy then
		-- Additive fields: never reduce the six slots an existing profile already had.
		eggSpeedLevel = if data.eggSpeedLevel == nil then 0 else data.eggSpeedLevel
		local plotSizeLevel = if data.plotSizeLevel == nil then 0 else data.plotSizeLevel
		rollSlotsUnlocked = if data.rollSlotsUnlocked == nil then 6 else data.rollSlotsUnlocked
		-- Revision 11 prepended three plot purchases; the yard level itself no longer
		-- converts (Flock Size follows the owned chickens) but must still be valid.
		if not numberIn(eggSpeedLevel,0,Legacy.EggSpeedLevels,true)
			or not numberIn(plotSizeLevel,0,if revision<11 then 4 else Legacy.PlotLevels,true)
			or not numberIn(rollSlotsUnlocked,1,Legacy.RollSlots,true) then
			return false,"Invalid saved board upgrades."
		end
	end
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
	-- Revision 12: the tree is the source of every run upgrade (lenient read).
	local tree: {[string]: number}=if legacyEconomy then {} else UpgradeCatalog.ReadTree(data.upgradeTree)
	-- Live since October 20: a tree saved before a tier changed meaning is moved once
	-- (TreeMigrations; a missing version is 0). Conversions below are already current.
	if not legacyEconomy then TreeMigrations.Run(tree,readCount(data.upgradeTreeVersion,1e6)) end
	local capacity,grant=data.capacity,data.legacyCapacityGrant or 0
	if legacyEconomy then
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
		if not numberIn(capacity,Config.StartingSlots,Config.MaxSlots,true) or not table.find(Legacy.SlotLevels,capacity)
			or grant>capacity or not numberIn(data.luck,0,Legacy.LuckLevels,true)
			or not numberIn(data.incomeLevel,0,Legacy.IncomeLevels,true) then return false,"Invalid saved profile." end
	else
		-- Derived from the tree; the historical grant is kept for reference only.
		capacity=UpgradeCatalog.Value(tree,"ArmySize")
		grant=if numberIn(grant,0,Config.MaxSlots,true) then grant else 0
	end
	local coins=clampHigh(data.coins,0,Currency.MaxCoins)
	-- Storage is unlimited up to Config.StorageLimit; loading never cuts a collection
	-- (a paid offer may go over), so only an absurd list is refused.
	if not coins or type(data.pets)~="table" or #data.pets>Config.StorageLimit*5
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
		-- October 20 (S7b): Feed Max Level allows levels up to Config.PetLevelLimit; a
		-- higher saved level reads as the limit instead of failing the load.
		local level=clampHigh(if revision<3 then 1 else pet.level,1,Config.PetLevelLimit,true)
		if not level then return false,"Invalid saved chicken level." end
		-- October 20: Giants are retired. A saved size is kept for the next save but never
		-- loaded as giantSize, so old Giants are ordinary chickens. Bad values are dropped.
		local retiredGiantSize=if Giant.IsValidSize(pet.giantSize) then pet.giantSize else nil
		local investment=if revision<5 then Rules.Investment(pet.species,level,true) else pet.investment
		-- Feed levels can cost more than 1e12 (S7b); the limit is the Coins cap.
		investment=clampHigh(investment,0,Currency.MaxCoins)
		if not investment then return false,"Invalid saved chicken investment." end
		-- Additive launch field: an unknown or malformed mutation is dropped, never the chicken.
		pets[pet.id]={id=pet.id,species=pet.species,stars=1,level=level,retiredGiantSize=retiredGiantSize,favorite=pet.favorite,collected=math.ceil(collected),investment=math.ceil(investment),
			mutation=if MutationCatalog.IsValid(pet.mutation) then pet.mutation else nil,
			-- Additive October 14 field: levels bought with cash, removed on Rebirth.
			-- Missing or malformed reads as none, never a load failure.
			cashLevels=if type(pet.cashLevels)=="number" and pet.cashLevels==pet.cashLevels and pet.cashLevels>=1
				then math.min(math.floor(pet.cashLevels),level-1) else nil}
	end
	if count~=#data.pets then return false,"Invalid saved collection." end
	-- Optional additive field; existing profiles continue selecting their best chickens.
	-- Revision 12 trims a selection longer than today's Army Size instead of refusing it.
	local selectionLimit=if legacyEconomy then capacity+ShopCatalog.ArmyBonus else Config.MaxSlots+ShopCatalog.ArmyBonus
	local armySelection
	if data.armySelection~=nil then
		if type(data.armySelection)~="table" or #data.armySelection>selectionLimit then
			return false,"Invalid saved army selection."
		end
		local seen,entries={},0
		armySelection={}
		for index,id in data.armySelection do
			entries+=1
			if entries>selectionLimit or not numberIn(index,1,#data.armySelection,true)
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
	for _,key in TUTORIAL_KEYS do tutorial[key]=data.tutorial[key]==true end
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
	local rebirths=readRebirths(data.rebirths)
	-- October 20 economy (docs/team/OVERHAUL_CONTRACT_20261020.md §2, §9). Revision ≤ 11
	-- converts the old tracks and research once; the research record then shows its
	-- running jobs as finished and its paid skip time as spent (both converted).
	-- Revision 12 reads the saved fields leniently. Nothing here refuses a profile.
	local gemUpgrades,gems,gemsEarned,missionTierLegacy,eggVacuum,conversion
	if legacyEconomy then
		local feedLevels,petCount=false,0
		for _,pet in pets do
			petCount+=1
			if pet.cashLevels then feedLevels=true end
		end
		conversion=EconomyMigration.Convert({eggSpeedLevel=eggSpeedLevel,incomeLevel=data.incomeLevel,luck=data.luck,
			capacity=capacity,rollSlotsUnlocked=rollSlotsUnlocked,petCount=petCount,rebirths=rebirths,
			research=research,tutorial=tutorial,cashLevels=feedLevels})
		tree,gemUpgrades=conversion.tree,conversion.gemUpgrades
		gems,gemsEarned=conversion.gems,conversion.gems
		missionTierLegacy,eggVacuum=conversion.missionTierLegacy,conversion.eggVacuum
		for _,job in research.jobs do research.completed[job.nodeId]=true end
		research.jobs,research.skipCredit={},0
	else
		gemUpgrades=GemUpgradeCatalog.Read(data.gemUpgrades)
		gems=readCount(data.gems,1e12)
		gemsEarned=math.max(gems,readCount(data.gemsEarned,1e12))
		missionTierLegacy=readCount(data.missionTierLegacy,3)
		eggVacuum=data.eggVacuum==true
	end
	-- Stevin, October 20 (S14): the Egg Vacuum is bought in Upgrades > Tools and resets
	-- on Rebirth. A legacy grant (a finished or skipped guide, converted above, or an
	-- earlier revision-12 gift) becomes this run's EggVacuum node, once.
	if eggVacuum then tree.EggVacuum=1 end
	-- S9c: mutations are an Upgrades tree family. A save keeps what its Rebirth rank
	-- allowed on live servers (Golden at any rank, Rainbow 1, Shadow 5, Cosmic 10): set
	-- once at its first load under that family, never raised, and the tree's Mutation
	-- tier never loads below it. Before the family exists nothing is derived.
	local mutationKeep=if type(data.mutationKeep)=="number" and data.mutationKeep==data.mutationKeep
		then math.clamp(math.floor(data.mutationKeep),0,#MutationCatalog.Order) else nil
	local mutationFamily=UpgradeCatalog.Families.Mutation
	if mutationFamily then
		if mutationKeep==nil then
			mutationKeep=if rebirths>=10 then 4 elseif rebirths>=5 then 3 elseif rebirths>=1 then 2 else 1
		end
		if mutationKeep>UpgradeCatalog.Tier(tree,"Mutation") then tree.Mutation=math.min(mutationKeep,#mutationFamily.tiers) end
	end
	local passGemGifts={}
	if type(data.passGemGifts)=="table" then
		for key,given in data.passGemGifts do
			if type(key)=="string" and given==true and ShopCatalog.Definitions[key] then passGemGifts[key]=true end
		end
	end
	local chickenCredits={}
	if type(data.rebirthChickenCredits)=="table" then
		for _,species in data.rebirthChickenCredits do
			if #chickenCredits<Config.Rebirth.MaxRank and type(species)=="string" and Catalog[species] and Catalog[species].rebirthRank then
				table.insert(chickenCredits,species)
			end
		end
	end
	-- S10's manual Flock layers: owned chickens only, in order, no repeats.
	local flockSelection
	if type(data.flockSelection)=="table" then
		flockSelection={}
		local seen={}
		for _,id in data.flockSelection do
			if #flockSelection<50 and type(id)=="string" and pets[id] and not seen[id] then
				seen[id]=true;table.insert(flockSelection,id)
			end
		end
	end
	-- S11's hand-vacuum cargo; an unreadable pair is emptied, never refused.
	local cargo=data.vacuumCargo
	local cargoCount=if type(cargo)=="table" then clampHigh(cargo.count,0,PlayerSession.CarryLimit,true) else nil
	local cargoValue=if type(cargo)=="table" then clampHigh(cargo.value,0,PlayerSession.CarryLimit,true) else nil
	if not cargoCount or not cargoValue or (cargoCount==0)~=(cargoValue==0) then cargoCount,cargoValue=0,0 end
	-- Commit only after every field validates. Old egg values were already valued;
	-- never multiply them again, and omit them from the current save payload.
	self.purchaseReceipts,self.crateCredits,self.commerceAutomatic=receipts,data.crateCredits or 0,automatic
	self.autoRoll=autoRoll
	self.guaranteedLuckRolls=guaranteedLuckRolls%(ShopCatalog.GuaranteedLuck.interval*#ShopCatalog.GuaranteedLuck.sequence)
	self.dataRevision,self.legacyCapacityGrant=Config.DataRevision,grant
	self.upgradeTree,self.gemUpgrades=tree,gemUpgrades
	self.gems,self.gemsEarned=gems,gemsEarned
	self.autoRebirth=data.autoRebirth~=false
	self.rebirthSkips=readCount(data.rebirthSkips,1000)
	self.passGemGifts,self.rebirthChickenCredits=passGemGifts,chickenCredits
	self.missionTierLegacy,self.mutationKeep=missionTierLegacy,mutationKeep
	self.flockSelection,self.eggVacuum=flockSelection,false
	self.vacuumCargo={count=cargoCount,value=cargoValue}
	-- S12b: one pull count per machine (count = Gold, diamond, prism); missing means 0.
	local goldRolls:any=if type(data.goldRolls)=="table" then data.goldRolls else {}
	self.goldRolls={count=readCount(goldRolls.count,1e6),diamond=readCount(goldRolls.diamond,1e6),prism=readCount(goldRolls.prism,1e6)}
	self.plotBuild=nil
	self.eggCarry={count=carryCount,value=carryValue};self.enemyKills=enemyKills;self.robuxSpent=robuxSpent
	self.eggProcessor=processor
	self.offlineCash,self.offlineCashReceipt=offlineCash,nil
	self.research=research
	self:RefreshEffects()
	self.researchRecap={};self.rallyActiveUntil=0
	-- Preserve saved ranks and validation; always use the best earned odds now.
	self.promotion,self.recruitTier=promotion,promotion
 self.frontierWins,self.kingCleared=frontier,king
 self.kingBountyPaid=data.kingBountyPaid==true
 self.hillWins,self.hillRollCredits,self.hillChampion=hillWins,hillRollCredits,data.hillChampion==true
 -- Additive launch fields: missing or malformed values read as their defaults.
 self.rebirths=rebirths
 self.daily=readDaily(data.daily)
 self.dailyGranted=nil
 -- Additive October 14 field: anything but a whole number below the guarantee reads as 0.
 self.giantPity=if numberIn(data.giantPity,0,Giant.PityLimit-1,true) then data.giantPity else 0
	-- Preserve old saves: round any historical cents up once, never reset progress.
	self.coins=math.min(Currency.MaxCoins,math.ceil(coins+converted))
	self.pets,self.slots,self.firstWins,self.tutorial=pets,{},wins,tutorial
	self.laneCamps=readLaneCamps(data.laneCamps,data.laneWins)
	-- Additive field; anything but true reads as false.
	self.adminAssisted=data.adminAssisted==true
	self.freeGiftClaimed=data.freeGiftClaimed==true
	-- Additive and lenient: anything unexpected reads as no offers bought.
	local offerStep=data.chickenOfferStep
	self.chickenOfferStep=if type(offerStep)=="number" and offerStep==offerStep then math.clamp(math.floor(offerStep),0,#ShopCatalog.ChickenOfferOrder) else 0
	self.fusionUnlocked=fusionUnlocked
	self.armySelection=if armySelection then self:FilterArmyIds(armySelection,self.capacity+ShopCatalog.ArmyBonus) else nil
	self.discovered = discovered
	self.unrecognizedPets,self.unrecognizedDiscovered=unrecognizedPets,unrecognizedDiscovered
	if #unrecognizedPets>0 or next(unrecognizedDiscovered) then
		warn("[PetRoll] Profile "..tostring(self.userId).." keeps "..#unrecognizedPets.." unrecognized saved chickens for a later build.")
	end
	-- Rebirth veterans get the Rebirth chicken of every rank they already hold (once).
	if conversion then
		for rank=1,conversion.rebirthChickenRanks do RebirthChickens.Grant(self,rank) end
		self.economyConversion=conversion.summary -- Transient: GameServer reports it once.
	end
	self.passiveEarned,self.battleEarned=math.ceil(passiveEarned),math.ceil(battleEarned)
	self.armyState,self.outgoing,self.incoming,self.defending="Home",nil,nil,nil
	self.returnAt,self.stationedAt=0,nil
	self.campUnlocked=1
	while self.firstWins[self.campUnlocked] and self.campUnlocked<#Progression.Camps(1) do self.campUnlocked+=1 end
	self.offer,self.offers=nil,{}
	self:UnlockProgress();self:RefreshArmy();self:Touch()
	return true,if legacy then "Loaded and converted stored egg value to coins."
		elseif conversion then "Loaded and converted to the new Upgrades." else "Loaded."
end

function PlayerSession:Destroy()
	self.pets, self.slots = {}, {}
end

return PlayerSession
