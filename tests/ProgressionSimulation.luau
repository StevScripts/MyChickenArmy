-- ProgressionSimulation (rewritten October 20, 2026 for the overhaul economy; S7 P0).
-- Free-player pacing model for the Upgrades tree, Flock-only laying, the
-- reset-everything Rebirth v2, Gems and Gem Upgrades, Chicken Feed and Gold Rush.
-- Isolated design experiment: one in-memory PlayerSession, no DataStore, world,
-- BattleService, live players or saved profiles.
--
-- Run from the Studio command bar in Edit mode (Rojo maps tests/ to ServerStorage.PetRollTests):
--   require(game.ServerStorage.PetRollTests.ProgressionSimulation)()
--   require(game.ServerStorage.PetRollTests.ProgressionSimulation).Run({seeds=3, hours=12, profile="casual"})
-- Prints a milestone table and returns the results table.
--
-- REAL MODULES USED (no duplicated prices or reset rules)
--  * UpgradeCatalog / UpgradeService:BuyNode: every tree price, tier value and prerequisite.
--  * GemUpgradeCatalog / GemUpgradeService.Buy: Gem prices, row locks and effects.
--  * RebirthService: Quote, Cost, Rebirth (reset, Gems, Time Skip, Rebirth chicken), EnemyScale.
--  * RollService: rolls, offers, mutations, recruit level/price, Buy.
--  * ArmyService.UpgradeChicken: Chicken Feed levels (server quote, reset on Rebirth).
--  * PlayerSession: Credit/EarnedAmount (Rebirth multiplier, Coin Boost), CanSpendCash
--    (tutorial reserve), EggProductionMultiplier, RefreshEffects, FlockSize, IsPetHome.
--  * Production per second mirrors the Flock rule S10 builds: the best FlockSize home
--    chickens by egg rate lay (Rules.EggRate * mutation * EggProductionMultiplier),
--    priced at Rules.EggUnitValue(Egg Value tier) * (1 + territory bonus).
--  * Camp/King/Mission strength: Progression.Roster, KingEncounter.Definition and
--    OperationCatalog.Power, scaled by RebirthService.EnemyScale(attacker's rank).
--  * Fight decision: TutorialGuide.Difficulty on Rules.Power(session:Lineup()).
--
-- MODELLING ASSUMPTIONS (quote these with any number)
--  1. Continuous active play, no offline time, no PvP, no other commanders, no Hill
--     boost, no passes or Robux (free player), no daily rewards, no Friend Boost.
--  2. Coarse ticks (default 15 s); eggs accrue in closed form. The fast player clicks
--     every egg and sells every 60 s (clicking is unlimited, so the hand vacuum is a
--     convenience here; the report lists the egg capacity a vacuum would need to hold
--     a minute of laying). The casual profile sells every 120 s, pulls the lever every
--     20 s and accepts slower paybacks.
--  3. Gold Rush: x2 Coins for 5 of every 20 minutes (seeded phase), on egg sales and
--     battle/Mission Coins; never offline. Steady sellers get about +25%; the
--     rushSaver option sells only during rushes (up to x2 egg Coins, slower spending).
--  4. Battles are not simulated. A camp/King is attacked at "Close fight" or better,
--     a Mission first clear at "Should win"; every attack wins. Army upgrades (Damage,
--     Health, Armor) are ignored because the displayed power ignores them.
--  5. Away: camp 90 s, King 150 s, Mission 150 s. The army's chickens stop laying while
--     away; the next best home chickens fill the Flock (S10 backfill rule).
--  6. Rebirth keeps camp/King progress but releases flags: the player re-takes camps
--     (and the King) when attackable, for kill Coins and the territory egg bonus.
--  7. Greedy spending each tick: economy (best payback among Egg Speed, Egg Value,
--     Flock, Chicken Feed levels on layers, recruits), combat while blocked (Army Size,
--     Feed levels on fighters, recruits), then utility within a budget (Luck, Roll
--     Slots, Roll Speed). Paybacks must beat the time left to afford the next Rebirth
--     (savingPaybackFraction). Gem Upgrades are bought after each Rebirth in a fixed
--     priority. Rebirth happens as soon as the quote is eligible.
--  8. Auto Roll (Gem Upgrade) lets the lever run at the reveal speed instead of the
--     player's pull rate. Rebirth-chicken podium offers and Mutation Luck are not
--     modelled (they land with S12's RollService hooks).
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local Progression=require(Shared.Progression)
local Guide=require(Shared.TutorialGuide)
local Tree=require(Shared.UpgradeCatalog)
local Gems=require(Shared.GemUpgradeCatalog)
local MutationCatalog=require(Shared.MutationCatalog)
local PetCatalog=require(Shared.PetCatalog)
local Operations=require(Shared.OperationCatalog)
local CombatRewards=require(Shared.CombatRewards)
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Rolls=require(Server.RollService)
local Upgrades=require(Server.UpgradeService)
local GemService=require(Server.GemUpgradeService)
local Rebirth=require(Server.RebirthService)
local King=require(Server.KingEncounter)
local Simulation={}

local PROFILES={
	fast={depositSeconds=60,rollEverySeconds=8,maxPaybackSeconds=1800,blockedPaybackSeconds=600},
	casual={depositSeconds=120,rollEverySeconds=20,maxPaybackSeconds=1200,blockedPaybackSeconds=480},
}
local DEFAULTS={
	seeds=1,hours=40,tickSeconds=15,profile="fast",
	campSeconds=90,kingSeconds=150,invasionSeconds=150,
	savingPaybackFraction=0.5,utilityFraction=0.10,savingUtilityFraction=0.04,savingCombatFraction=0.25,
	targetRank=30,invasionReplays=true,killsPerDefender=1,maxBuysPerTick=60,
	-- rushSaver: sell only during Gold Rush (S4: up to 2x egg Coins for savers).
	goldRush=true,rushEvery=1200,rushSeconds=300,rushSaver=false,
	print=true,
}

-- Gem Upgrades in buying order (the first affordable unlocked one each time).
local GEM_PRIORITY={"CoinBoost","AutoRoll","ExtraLuck","RollSpeed","TimeSkip","MoreGems","KeepUpgrades",
	"CoinBoost","ExtraLuck","RollSpeed","CoinBoost","AutoRebirth","VacuumCapacity","MutationLuck","ArmyPower",
	"OfflineCoins","RebirthChickenOdds","Rally"}

-- Same Park-Miller generator as the old simulation; Random-compatible NextNumber.
local function lcg(seed)
	local state=math.max(1,seed%2147483647)
	local object={}
	function object:NextNumber(low,high)
		state=state*48271%2147483647
		local x=(state-1)/2147483646
		return if low and high then low+(high-low)*x else x
	end
	return object
end

local function money(n)
	if n==nil then return "-" end
	for _,unit in {{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}} do
		if math.abs(n)>=unit[1] then return string.format("%.2f%s",n/unit[1],unit[2]) end
	end
	return tostring(math.floor(n))
end

-- Flock production (the S10 rule) ---------------------------------------------------
local function petEggs(pet,level)
	return Rules.EggRate(pet.species,pet.stars or 1,level or pet.level)*MutationCatalog.Multiplier(pet.mutation)
end
-- Home chickens, best layers first.
local function homeLayers(s)
	local list={}
	for id,pet in s.pets do if s:IsPetHome(id) then table.insert(list,pet) end end
	table.sort(list,function(a,b)
		local ea,eb=petEggs(a),petEggs(b)
		if ea~=eb then return ea>eb end
		return a.id<b.id
	end)
	return list
end
local function unitValue(s)
	return Rules.EggUnitValue(s.incomeLevel)*(1+s.researchEffects.eggValue)*(1+(s.territoryBonus or 0))
end
-- Eggs per second from the best FlockSize home layers, and the layer list.
local function flockEggs(s,size)
	local layers=homeLayers(s)
	local eggs=0
	for i=1,math.min(size or s:FlockSize(),#layers) do eggs+=petEggs(layers[i]) end
	return eggs*s:EggProductionMultiplier(),layers
end
local function rawRate(s) return flockEggs(s)*unitValue(s) end
local function cashRate(s) return s:EarnedAmount(rawRate(s),"eggs") end
-- Coins/s one layer adds at `level` (EarnedAmount included).
local function layerCash(s,pet,level)
	return s:EarnedAmount(petEggs(pet,level)*s:EggProductionMultiplier()*unitValue(s),"eggs")
end

local function rushFactor(state,now)
	local options=state.options
	if not options.goldRush then return 1 end
	local phase=(now+state.rushPhase)%options.rushEvery
	return if phase<options.rushSeconds then 2 else 1
end

local function deposit(state,now)
	local s=state.session
	-- A rush saver keeps clicked eggs in the bag and sells only during Gold Rush.
	if state.options.rushSaver and state.options.goldRush and rushFactor(state,now)<2 then return end
	local whole=math.floor(state.bag*rushFactor(state,now))
	if whole<1 then return end
	local credited=s:Credit(whole,"eggs")
	if credited>0 then state.bag=0;state.stats.eggCash+=credited end
end

-- Army and targets -------------------------------------------------------------------
local function petPower(pet,level)
	return Rules.PetPower(pet.species,pet.stars or 1,level or pet.level,pet.giantSize)
end
local function armyPower(s) return Rules.Power(s:Lineup()) end
local function lineupInfo(s)
	local lineup=s:Lineup()
	local ids,weakest={},math.huge
	for _,p in lineup do ids[p.id]=true;weakest=math.min(weakest,petPower(p)) end
	return lineup,ids,(if #lineup<s:Capacity() then 0 else weakest)
end

local function enemyScale(s) return Rebirth.EnemyScale(s.rebirths or 0) end
local function campPower(s,index)
	return math.floor(Rules.Power(Progression.Roster(s.promotion,index))*enemyScale(s))
end
-- Mirrors OperationService.Tier (King clear or Rebirth rank; legacy access).
local function missionTier(s)
	local ranks=Config.Rebirth.MissionTierRanks
	local rank=s.rebirths or 0
	local tier=if rank>=ranks[3] then 3 elseif rank>=ranks[2] then 2 elseif rank>=ranks[1] or s.kingCleared then 1 else 0
	return math.max(tier,s.missionTierLegacy or 0)
end

local function nextTarget(state)
	local s=state.session
	local camps=Progression.Camps(s.promotion)
	if not s.firstWins[1] then return {kind="Camp",index=1,power=campPower(s,1)} end
	local best=nil
	for index=2,#camps do
		if not s.firstWins[index] then
			local power=campPower(s,index)
			if not best or power<best.power then best={kind="Camp",index=index,power=power} end
		end
	end
	if best then return best end
	if not s.kingCleared then
		local king=King.Definition(4,enemyScale(s))
		return {kind="King",power=king.power,roster=king.roster}
	end
	-- Rebirth released the flags: re-take camps, then the King, for their egg bonus.
	for index=1,#camps do
		if not state.flags[index] then return {kind="Camp",index=index,power=campPower(s,index),recapture=true} end
	end
	if not state.flags.king then
		local king=King.Definition(4,enemyScale(s))
		return {kind="King",power=king.power,roster=king.roster,recapture=true}
	end
	local tier=missionTier(s)
	for _,id in Operations.Order do
		local definition=Operations.Encounters[id]
		if definition.tier<=tier and not s.research.operationWins[id] then
			local power=Operations.Power(id)
			if not best or power<best.power then best={kind="Invasion",id=id,power=power} end
		end
	end
	return best
end

local function attackable(power,target)
	local verdict=Guide.Difficulty(power,target.power)
	if target.kind=="Invasion" then return verdict=="Should win" end
	return verdict~="Very tough"
end

local function refreshTerritory(state)
	local s,total=state.session,0
	for index in state.flags do
		if type(index)=="number" then total+=Config.Territories.CampBonus[index] or 0 end
	end
	if state.flags.king then total+=Config.Territories.KingBonus end
	s.territoryBonus=math.floor(total*1000+0.5)/1000
end

local function killCash(state,roster)
	local s,total=state.session,0
	for _,unit in roster do
		local repeatBoss=unit.boss==true and s.kingBountyPaid==true
		local times=if unit.boss then 1 else state.options.killsPerDefender
		total+=math.floor(CombatRewards.ForUnit(unit,nil,repeatBoss)*(1+(s.researchEffects.bounty or 0)))*times
	end
	return math.floor(total)
end

local function mark(state,key,now,coins)
	if state.milestones[key] then return end
	local s=state.session
	state.milestones[key]={minutes=now/60,coins=coins or s.coins,income=cashRate(s),
		power=armyPower(s),flock=s:Count(),rank=s.rebirths,eggs=flockEggs(s)}
end

local function deploy(state,now,kind,data,seconds)
	state.session.armyState="Marching"
	state.deploy={kind=kind,data=data,returnAt=now+seconds}
end

local function resolve(state,now)
	local s,job,stats=state.session,state.deploy,state.stats
	state.deploy=nil
	s.armyState="Home"
	local rush=rushFactor(state,now)
	if job.kind=="Camp" then
		local index=job.data.index
		local cash=killCash(state,Progression.Roster(s.promotion,index))
		s.firstWins[index]=true
		state.flags[index]=true
		s:UnlockProgress()
		s.tutorial.wonCamp=true;s.tutorial.guideCompleted=true;s.eggVacuum=true
		stats.battleCash+=s:Credit(math.floor(cash*rush),"battle")
		refreshTerritory(state)
		mark(state,"FirstCamp",now)
		local all=true
		for i=1,#Progression.Camps(s.promotion) do if not s.firstWins[i] then all=false end end
		if all then mark(state,"AllCamps",now) end
	elseif job.kind=="King" then
		local cash=killCash(state,job.data.roster)
		s.kingBountyPaid=true;s.kingCleared=true
		state.flags.king=true
		stats.battleCash+=s:Credit(math.floor(cash*rush),"battle")
		refreshTerritory(state)
		mark(state,"King",now)
	elseif job.kind=="Invasion" then
		local id=job.data.id
		local definition=Operations.Encounters[id]
		local first=not s.research.operationWins[id]
		local amount=math.floor(s:EarnedAmount((if first then definition.firstCash else definition.replayCash)*rush,"battle"))
		stats.invasionCash+=s:Credit(amount,"operation")
		if first then stats.invasionFirsts+=1 else stats.invasionReplays+=1 end
		s.research.operationWins[id]=true
		mark(state,"Invasion",now)
	end
	s:RefreshArmy();s:Touch()
end

local function chooseAttack(state,now)
	local s,options=state.session,state.options
	if state.deploy or s.armyState~="Home" or #s:Lineup()==0 then return end
	local power=armyPower(s)
	local target=nextTarget(state)
	if target and attackable(power,target) then
		local seconds=if target.kind=="Camp" then options.campSeconds
			elseif target.kind=="King" then options.kingSeconds else options.invasionSeconds
		deploy(state,now,target.kind,target,seconds)
		return
	end
	if not options.invasionReplays then return end
	local best,bestCash=nil,0
	for id,won in s.research.operationWins do
		local definition=Operations.Encounters[id]
		if won and definition and definition.tier<=missionTier(s)
			and Guide.Difficulty(power,Operations.Power(id))=="Should win" and definition.replayCash>bestCash then
			best,bestCash=id,definition.replayCash
		end
	end
	if not best then return end
	local _,ids=lineupInfo(s)
	local squadIncome=0
	for id in ids do squadIncome+=layerCash(s,s.pets[id]) end
	if s:EarnedAmount(bestCash,"battle")>squadIncome*options.invasionSeconds then
		deploy(state,now,"Invasion",{id=best},options.invasionSeconds)
	end
end

-- Spending -----------------------------------------------------------------------------
local function nodePrice(s,familyId,tier) return Tree.Price(familyId,tier,s.rebirths) end
local function nextTier(s,familyId)
	local tier=Tree.Tier(s.upgradeTree,familyId)+1
	return if Tree.Families[familyId].tiers[tier] then tier else nil
end
local function buyNode(state,familyId,tier)
	local s=state.session
	local ok=state.upgrades:BuyNode(s,Tree.NodeId(familyId,tier),nodePrice(s,familyId,tier))
	if ok then state.stats.treeBuys+=1;state.stats.treeSpent+=nodePrice(s,familyId,tier) end
	return ok
end

local function economyCandidates(state,failed)
	local s=state.session
	local list={}
	local function add(key,price,gain,buy)
		if failed[key] or not price or price<=0 or gain<=0 then return end
		table.insert(list,{key=key,price=price,payback=price/gain,buy=buy})
	end
	local full=cashRate(s)
	local _,layers=flockEggs(s)
	local size=s:FlockSize()
	local speed=nextTier(s,"EggSpeed")
	if speed then
		local rates=Tree.EggSpeedRates
		add("EggSpeed",nodePrice(s,"EggSpeed",speed),full*(rates[speed+1]/rates[speed]-1),function() return buyNode(state,"EggSpeed",speed) end)
	end
	local value=nextTier(s,"EggValue")
	if value then
		add("EggValue",nodePrice(s,"EggValue",value),full*(Rules.EggUnitValue(value)/Rules.EggUnitValue(value-1)-1),
			function() return buyNode(state,"EggValue",value) end)
	end
	local flock=nextTier(s,"Flock")
	if flock then
		local newSize=Tree.Families.Flock.tiers[flock].value
		local gain=0
		for i=size+1,math.min(newSize,#layers) do gain+=layerCash(s,layers[i]) end
		add("Flock",nodePrice(s,"Flock",flock),gain,function() return buyNode(state,"Flock",flock) end)
	end
	-- Chicken Feed levels on current layers (the Feed node first).
	local feedOwned=(s.researchEffects.chickenFeed or 0)>=1
	local bestFeedGain,bestFeedPrice=0,nil
	for i=1,math.min(size,#layers) do
		local pet=layers[i]
		local level=pet.level or 1
		local price=Rules.ChickenUpgradePrice(pet.species,level)
		if price and s:IsPetHome(pet.id) then
			local gain=layerCash(s,pet,level+1)-layerCash(s,pet,level)
			if feedOwned then
				add("feed:"..pet.id,price,gain,function() return Army.UpgradeChicken(s,pet.id,level,price) end)
			elseif gain/price>bestFeedGain/(bestFeedPrice or math.huge) then
				bestFeedGain,bestFeedPrice=gain,price
			end
		end
	end
	if not feedOwned and bestFeedPrice then
		local price=nodePrice(s,"ChickenFeed",1)
		add("ChickenFeed",price+bestFeedPrice,bestFeedGain,function() return buyNode(state,"ChickenFeed",1) end)
	end
	return list
end

local function chooseEconomy(list,coins,limit)
	table.sort(list,function(a,b) return a.payback<b.payback end)
	local best=list[1]
	if not best or best.payback>limit then return nil end
	if best.price<=coins then return best end
	for _,candidate in list do
		if candidate.payback>best.payback*2 or candidate.payback>limit then break end
		if candidate.price<=coins then return candidate end
	end
	return nil
end

local function combatCandidates(state,failed)
	local s=state.session
	local list={}
	local function add(key,price,gain,buy)
		if failed[key] or not price or gain<=0 then return end
		table.insert(list,{key=key,price=price,ratio=gain/price,buy=buy})
	end
	local lineup,inLineup,weakest=lineupInfo(s)
	if (s.researchEffects.chickenFeed or 0)>=1 then
		for _,entry in lineup do
			local pet=s.pets[entry.id]
			local level=pet.level or 1
			local price=Rules.ChickenUpgradePrice(pet.species,level)
			if price then
				add("feed:"..pet.id,price,petPower(pet,level+1)-petPower(pet,level),
					function() return Army.UpgradeChicken(s,pet.id,level,price) end)
			end
		end
	end
	local army=nextTier(s,"ArmySize")
	if army then
		local slots=Tree.Families.ArmySize.tiers[army].value-s.capacity
		local reserves={}
		for id,pet in s.pets do if not inLineup[id] then table.insert(reserves,petPower(pet)) end end
		table.sort(reserves,function(a,b) return a>b end)
		local gain=0
		for i=1,math.min(slots,#reserves) do gain+=reserves[i] end
		add("ArmySize",nodePrice(s,"ArmySize",army),gain,function() return buyNode(state,"ArmySize",army) end)
	end
	return list,weakest
end

local function chooseCombat(list,budget)
	table.sort(list,function(a,b) return a.ratio>b.ratio end)
	local best=list[1]
	if not best then return nil end
	if best.price<=budget then return best end
	for _,candidate in list do
		if candidate.ratio<best.ratio*0.5 then break end
		if candidate.price<=budget then return candidate end
	end
	return nil
end

-- Luck, Roll Slots and Roll Speed, cheapest first, inside the utility budget.
local UTILITY={"Luck","RollSlot","RollSpeed"}
local function chooseUtility(state,failed,budget)
	local s=state.session
	local best
	for _,familyId in UTILITY do
		local tier=nextTier(s,familyId)
		local price=tier and nodePrice(s,familyId,tier)
		if tier and price and price<=budget and not failed[familyId] and (not best or price<best.price) then
			best={key=familyId,price=price,buy=function() return buyNode(state,familyId,tier) end}
		end
	end
	return best
end

local function syncSlots(s)
	s.rollSlotCount=math.clamp(s.rollSlotsUnlocked,1,s.rollSlotLimit or 1)
end

local function context(state)
	local s,options=state.session,state.options
	local target=nextTarget(state)
	local blocked=target~=nil and not attackable(armyPower(s),target) and not target.recapture
	local limit=if blocked then options.blockedPaybackSeconds else options.maxPaybackSeconds
	local saving=false
	local coins=s.coins
	local cost=Rebirth.Cost(s.rebirths+1)
	if cost and s.rebirths<options.targetRank then
		local need=cost-coins
		if need>0 then
			saving=true
			limit=math.min(limit,need/math.max(1,cashRate(s))*options.savingPaybackFraction)
		end
	end
	return {target=target,blocked=blocked,paybackLimit=limit,saving=saving,
		combatBudget=if not blocked then 0 elseif saving then coins*options.savingCombatFraction else math.huge,
		utilityBudget=coins*(if saving then options.savingUtilityFraction else options.utilityFraction)}
end

local function spend(state,ctx)
	local s,stats=state.session,state.stats
	local failed={}
	for _=1,state.options.maxBuysPerTick do
		local choice,pool=chooseEconomy(economyCandidates(state,failed),s.coins,ctx.paybackLimit),"economy"
		if not choice and ctx.blocked then
			choice,pool=chooseCombat((combatCandidates(state,failed)),math.min(s.coins,ctx.combatBudget)),"combat"
		end
		if not choice then
			choice,pool=chooseUtility(state,failed,math.min(s.coins,ctx.utilityBudget)),"utility"
		end
		if not choice then break end
		local ok=choice.buy()
		if ok then
			stats.purchases[pool]+=1
			if pool=="combat" then ctx.combatBudget-=choice.price end
			if pool=="utility" then ctx.utilityBudget-=choice.price end
			syncSlots(s)
		else
			failed[choice.key]=true
		end
	end
end

local function spendGems(state,now)
	local s=state.session
	for _=1,10 do
		local bought=false
		for _,id in GEM_PRIORITY do
			local status,level,price=GemService.Status(s,id)
			if status=="Available" and price then
				if GemService.Buy(s,id,level,price) then
					state.stats.gemsSpent+=price;bought=true
					break
				end
			end
		end
		if not bought then break end
	end
	for _,id in Gems.Order do
		if GemService.Status(s,id)~="Maxed" then return end
	end
	mark(state,"GemBoardDone",now)
end

local function judgeOffers(state,ctx,at)
	local s,stats=state.session,state.stats
	for _,pet in s.pets do
		local def=PetCatalog[pet.species]
		if def and def.rarity=="Mythic" then mark(state,"MythicOwned",at) end
		if pet.mutation=="Golden" then mark(state,"GoldenOwned",at) end
	end
	local _,layers=flockEggs(s)
	local size=s:FlockSize()
	local floorLayer=layers[size]
	for slot=1,s.rollSlotCount or 1 do
		local offer=s.offers and s.offers[slot]
		if offer then
			local def=PetCatalog[offer.species]
			if def and def.rarity=="Mythic" then mark(state,"MythicSeen",at) end
			if offer.mutation=="Golden" then mark(state,"GoldenSeen",at) end
		end
		if not offer or offer.price>s.coins then continue end
		local pet={species=offer.species,stars=1,level=offer.level,mutation=offer.mutation}
		-- A new chicken earns only if it beats the weakest current layer.
		local gain=layerCash(s,pet,offer.level)-(if floorLayer and #layers>=size then layerCash(s,floorLayer) else 0)
		local _,_,weakest=lineupInfo(s)
		local powerGain=petPower(pet,offer.level)-weakest
		local economy=gain>0 and offer.price/gain<=ctx.paybackLimit
		local combat=ctx.blocked and powerGain>0 and offer.price<=ctx.combatBudget
		if not (economy or combat or offer.starter==true) then continue end
		if state.rolls:Buy(s,offer.id,at) then
			stats.recruits+=1
			if combat and not economy then ctx.combatBudget-=offer.price end
			_,layers=flockEggs(s)
			floorLayer=layers[size]
		end
	end
end

local function rollAndBuy(state,ctx,now)
	local s=state.session
	local pulls=0
	local every=state.options.rollEverySeconds
	if (s.researchEffects.autoRoll or 0)>=1 then
		every=math.min(every,Config.RollRevealSeconds/(1+(s.researchEffects.rollingSpeed or 0)))
	end
	while state.nextRollAt<=now and pulls<12 do
		local at=state.nextRollAt
		state.nextRollAt+=every
		pulls+=1
		-- Opening: Army Size 4 first, then the guaranteed starter recruit (both earmarked).
		if s:StarterRecruitPending() and s.capacity<4 then buyNode(state,"ArmySize",1) end
		if at>=s.rollReadyAt and state.rolls:Roll(s,at) then
			state.stats.rolls+=1
			judgeOffers(state,ctx,s.rollRevealAt+0.01)
		end
	end
	if state.nextRollAt<now then state.nextRollAt=now end
end

local function tryRebirth(state,now)
	local s,options=state.session,state.options
	if s.rebirths>=options.targetRank or state.deploy then return end
	local cost=Rebirth.Cost(s.rebirths+1)
	if not cost then return end
	-- Sell the bag first when that makes the rank affordable.
	if s.coins<cost and s.coins+s:EarnedAmount(state.bag*rushFactor(state,now),"eggs")>=cost then deposit(state,now) end
	if not Rebirth.Quote(s).eligible then return end
	local before=s.coins
	local ok,_,receipt=Rebirth.Rebirth(s,s.rebirths,nil,false)
	if not ok then return end
	-- No BattleService here: release the flags ourselves; the bag is cleared.
	table.clear(state.flags)
	s.territoryBonus=0
	state.bag=0
	state.stats.gemsEarned+=receipt.gems
	state.stats.timeSkip+=receipt.timeSkipCoins
	spendGems(state,now)
	state.milestones["Rebirth"..s.rebirths]={minutes=now/60,coins=before,income=cashRate(s),
		power=armyPower(s),flock=s:Count(),rank=s.rebirths,cost=cost,eggs=state.peakEggs,timeSkip=receipt.timeSkipCoins}
	state.peakEggs=0
end

local function runOnce(seed,options)
	local random=lcg(seed*7919)
	local s=Session.new(-(70000+seed),"Simulation",1)
	s.loaded=true
	s.rollSlotLimit=Config.RollSlotsUnlocked
	syncSlots(s)
	local rolls=Rolls.new()
	rolls.random=random
	local state={session=s,options=options,rolls=rolls,upgrades=Upgrades.new(nil,rolls),
		bag=0,deploy=nil,nextRollAt=2,milestones={},flags={},peakEggs=0,
		rushPhase=(seed*277)%options.rushEvery,
		stats={rolls=0,recruits=0,eggCash=0,battleCash=0,invasionCash=0,invasionFirsts=0,invasionReplays=0,
			treeBuys=0,treeSpent=0,gemsEarned=0,gemsSpent=0,timeSkip=0,purchases={economy=0,combat=0,utility=0}}}
	local horizon,dt=options.hours*3600,options.tickSeconds
	local nextDeposit,now=options.depositSeconds,0
	while now<horizon and s.rebirths<options.targetRank do
		local eggs=flockEggs(s)
		state.peakEggs=math.max(state.peakEggs,eggs)
		state.bag+=rawRate(s)*dt
		now+=dt
		if now>=nextDeposit then deposit(state,now);nextDeposit+=options.depositSeconds end
		for _,minutes in {10,30,60,120,180} do
			if now>=minutes*60 and not state.milestones["Min"..minutes] then mark(state,"Min"..minutes,now) end
		end
		if state.deploy and now>=state.deploy.returnAt then resolve(state,now) end
		tryRebirth(state,now)
		local ctx=context(state)
		spend(state,ctx)
		rollAndBuy(state,ctx,now)
		chooseAttack(state,now)
	end
	return {seed=seed,minutes=now/60,milestones=state.milestones,stats=state.stats,
		final={rank=s.rebirths,coins=s.coins,gems=s.gems,income=cashRate(s),power=armyPower(s),flock=s:Count(),
			flockSize=s:FlockSize(),capacity=s:Capacity(),tree=table.clone(s.upgradeTree),gemUpgrades=table.clone(s.gemUpgrades)}}
end

local function median(values)
	if #values==0 then return nil end
	table.sort(values)
	return values[math.ceil(#values/2)]
end

local ROWS={
	{"Min10","At 10 min",nil},{"Min30","At 30 min",nil},{"Min60","At 60 min",nil},{"Min120","At 2 h",nil},
	{"FirstCamp","First camp",nil},{"AllCamps","All 3 camps",nil},{"King","First King clear",nil},
	{"Invasion","First Mission",nil},
	{"Rebirth1","Rebirth 1","~10 min"},{"Rebirth2","Rebirth 2","~18 min"},{"Rebirth3","Rebirth 3",nil},
	{"Rebirth5","Rebirth 5","~54 min"},{"Rebirth7","Rebirth 7",nil},{"Rebirth10","Rebirth 10","~2.9 h"},
	{"Rebirth12","Rebirth 12",nil},{"Rebirth15","Rebirth 15","~6.4 h"},{"Rebirth20","Rebirth 20","~11.6 h"},
	{"Rebirth25","Rebirth 25",nil},{"Rebirth30","Rebirth 30","~34 h"},
	{"GoldenSeen","First Golden offer",nil},{"MythicSeen","First Mythic offer",nil},{"MythicOwned","First Mythic owned",nil},
	{"GemBoardDone","Gem Upgrades complete","~R25-28"},
}

local function report(results)
	local lines={}
	local function line(text) table.insert(lines,text) end
	local o=results.options
	line(string.format("ProgressionSimulation (Oct 20 economy) · profile %s · %s seed(s) · tick %ss · horizon %sh · %.1fs runtime",
		o.profile,tostring(o.seeds),tostring(o.tickSeconds),tostring(o.hours),results.seconds))
	line(string.format("%-20s %8s %6s %10s %10s %9s %7s %10s  %s","Milestone","Minutes","Hours","Coins","Coins/s","Eggs/s","Power","Gap min","Target (plan v2, fast)"))
	local previous=nil
	for _,row in ROWS do
		local minutes,cash,income,eggs,power,reached={}, {}, {}, {}, {},0
		for _,run in results.runs do
			local m=run.milestones[row[1]]
			if m then
				reached+=1
				table.insert(minutes,m.minutes);table.insert(cash,m.coins);table.insert(income,m.income or 0)
				table.insert(eggs,m.eggs or 0);table.insert(power,m.power)
			end
		end
		local mm=median(minutes)
		local gap=""
		if string.sub(row[1],1,7)=="Rebirth" then
			if mm and previous then gap=string.format("%.1f",mm-previous) end
			previous=mm or previous
		end
		line(string.format("%-20s %8s %6s %10s %10s %9s %7s %10s  %s%s",row[2],
			if mm then string.format("%.1f",mm) else "never",if mm then string.format("%.2f",mm/60) else "-",
			money(median(cash)),money(median(income)),money(median(eggs)),tostring(median(power) or "-"),gap,
			row[3] or "",if #results.runs>1 then string.format(" (%d/%d)",reached,#results.runs) else ""))
	end
	for _,run in results.runs do
		local st,f=run.stats,run.final
		line(string.format("seed %d: %.0f min, rank %d · eggs %s, kills %s, Missions %s (%d first, %d replays) · rolls %d, recruits %d · tree buys %d (%s) · Gems %d earned, %d spent · Time Skip %s",
			run.seed,run.minutes,f.rank,money(st.eggCash),money(st.battleCash),money(st.invasionCash),st.invasionFirsts,st.invasionReplays,
			st.rolls,st.recruits,st.treeBuys,money(st.treeSpent),st.gemsEarned,st.gemsSpent,money(st.timeSkip)))
		local gems={}
		for id,level in f.gemUpgrades do table.insert(gems,id.."="..level) end
		table.sort(gems)
		line(string.format("  final: %s Coins, %s/s, power %d, owned %d, Flock %d, army %d · Gem Upgrades %s",
			money(f.coins),money(f.income),f.power,f.flock,f.flockSize,f.capacity,table.concat(gems,",")))
	end
	line("Medians across seeds. Rebirth rows: Coins = balance just before the reset, Coins/s = rate right after it,")
	line("Eggs/s = the run's peak laying rate (a hand vacuum holding a minute of eggs needs 60x that).")
	line("Model, not playtime: see the header assumptions in tests/ProgressionSimulation.luau.")
	print(table.concat(lines,"\n"))
end

function Simulation.Run(options)
	local merged=table.clone(DEFAULTS)
	for key,value in options or {} do merged[key]=value end
	for key,value in PROFILES[merged.profile] or PROFILES.fast do
		if not (options and options[key]~=nil) then merged[key]=value end
	end
	local previousSizeRandom=Army.SizeRandom
	local runs={}
	local started=os.clock()
	local ok,problem=pcall(function()
		for seed=1,merged.seeds do
			Army.SizeRandom=lcg(seed*104729)
			table.insert(runs,runOnce(seed,merged))
		end
	end)
	Army.SizeRandom=previousSizeRandom
	if not ok then error(problem,0) end
	local results={options=merged,runs=runs,seconds=os.clock()-started,
		assumptions="Free player, continuous active play; Flock-only laying with clicked eggs sold every deposit; "
			.."Gold Rush x2 for 5 of 20 minutes; fights decided by TutorialGuide.Difficulty and always won; "
			.."greedy payback/power/utility spending; Rebirth as soon as eligible; Gem Upgrades in a fixed priority."}
	if merged.print then report(results) end
	return results
end

return setmetatable(Simulation,{__call=function(_,options) return Simulation.Run(options) end})
