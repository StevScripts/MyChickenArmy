-- ProgressionSimulation (rewritten October 14, 2026 for Re-enlist pacing; plan §6.9).
-- Free-player pacing model: fresh profile -> first camp -> Chicken King ->
-- Rebirth 1, 2, 3. Isolated design experiment: one in-memory PlayerSession,
-- no DataStore, world, BattleService, live players or saved profiles.
--
-- Run from the Studio command bar in Edit mode (Rojo maps tests/ to ServerStorage.PetRollTests):
--   require(game.ServerStorage.PetRollTests.ProgressionSimulation)()
--   require(game.ServerStorage.PetRollTests.ProgressionSimulation).Run({seeds=3, hours=40})
-- Prints a milestone table and returns the results table.
--
-- REAL MODULES USED (no duplicated prices or reset rules)
--  * RollService: rolls, offers, mutations, recruit level/price, Buy.
--  * UpgradeService:Buy: Egg Speed, Egg Value, Army Size, Luck, Plot Size, Roll Slots.
--  * ArmyService: chicken cash levels, fusion (Giant odds via SizeRandom), selling.
--  * ResearchService.Start/Complete + ResearchRules effects and durations.
--  * RebirthService: Quote, Cost, Rebirth (reset), Multiplier, EnemyScale.
--  * PlayerSession: Credit/EarnedAmount (Re-enlist egg multiplier), EggProductionMultiplier,
--    IsPetHome, CanSpendCash (tutorial reserve), RefreshArmy, UnlockProgress.
--  * Production per second = the EggService:Produce formula: for each home chicken
--    Rules.EggRate * MutationCatalog.Multiplier * EggProductionMultiplier, priced at
--    Rules.EggUnitValue(incomeLevel) * (1 + research eggValue) * (1 + territoryBonus).
--  * Camp/King/Invasion strength: Progression.Roster, KingEncounter.Definition and
--    OperationCatalog.Power, scaled like BattleService (Power * RebirthService.EnemyScale).
--  * Fight decision: TutorialGuide.Difficulty on Rules.Power(session:Lineup()), the
--    same number the camp prompt / Invasions panel shows.
--
-- MODELLING ASSUMPTIONS (quote these with any number)
--  1. Continuous active play, no offline time, no PvP, no other commanders, no Hill
--     boost, no passes or Robux (free player), no daily rewards, no mistakes.
--  2. Coarse ticks (default 15 s). Eggs accrue in closed form; the yard is
--     collected and deposited (instant sale) every 60 s. No walking overhead.
--  3. One lever pull every 8 s; each podium offer is judged once at reveal and
--     forgotten at the next pull (real offers wait; this is slightly pessimistic).
--  4. Battles are not simulated. A camp/King is attacked when Difficulty is
--     "Close fight" or better (>= 1.3x); an Invasion first clear when "Should win"
--     (>= 2x). Every attack is assumed to win. Research combat bonuses (damage,
--     health, armor), Rally, Giants' stomp and the Colossal aura are ignored
--     because the displayed power ignores them. Cluck Camp first, then any camp.
--  5. Time away: camp 90 s, King 150 s, Invasion 150 s. The deployed squad lays
--     no eggs while away (PlayerSession:IsPetHome). The King's Hill-round lock is ignored.
--  6. Kill cash: each defender is killed once (option killsPerDefender), via
--     CombatRewards.ForUnit with research bounty; the King's full bounty once per rank.
--  7. Captured camps and the King keep their flags (territory egg bonus) until
--     Re-enlist releases them; nobody contests them.
--  8. Invasions: Tier = max(research operations, King cleared) as OperationService.Tier.
--     First clears pay firstCash; if invasionReplays is on, the best "Should win"
--     replay is farmed whenever its cash beats the squad's lost egg income.
--  9. Greedy spending each tick, in this order:
--     a) Economy: the lowest payback (price / extra $ per s, plus research duration)
--        among chicken cash levels, Egg Speed, Egg Value, Plot Size (when nearly
--        full) and production/egg-value research, if payback <= 1800 s (600 s while
--        blocked by a fight). If the best is unaffordable it saves, except for a
--        cheaper item at most 2x the best payback.
--     b) Combat (only while the next fight is out of reach): best power per $ among
--        squad chicken levels, Army Size and fusions.
--     c) Utility, up to 10% of the tick's starting cash: Luck, Roll Slots and
--        research in a fixed priority (Fuse Machine path, research speed/slots,
--        Invasion tiers, rolling luck). Rolling speed and combat research are skipped.
--     Offers: bought if their payback passes (a) or they raise squad power while
--     blocked; a full flock sells its lowest-income reserve first.
-- 10. Rebirth: as soon as RebirthService.Quote is eligible. After a King clear the
--     player saves: economy items must pay back within half the time it would take
--     to afford the next rank at current income; combat and utility budgets shrink.
-- 11. The opening follows the real reserve rules: Army Size 4, then the guaranteed
--     $600 recruit; the guide is treated as complete after the first camp.
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local Progression=require(Shared.Progression)
local Guide=require(Shared.TutorialGuide)
local UpgradeCatalog=require(Shared.UpgradeCatalog)
local MutationCatalog=require(Shared.MutationCatalog)
local PetCatalog=require(Shared.PetCatalog)
local GiantChicken=require(Shared.GiantChicken)
local ResearchCatalog=require(Shared.ResearchCatalog)
local ResearchRules=require(Shared.ResearchRules)
local Operations=require(Shared.OperationCatalog)
local CombatRewards=require(Shared.CombatRewards)
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Rolls=require(Server.RollService)
local Upgrades=require(Server.UpgradeService)
local Research=require(Server.ResearchService)
local Rebirth=require(Server.RebirthService)
local King=require(Server.KingEncounter)
local Simulation={}

local DEFAULTS={
	seeds=1,hours=40,tickSeconds=15,depositSeconds=60,rollEverySeconds=8,
	campSeconds=90,kingSeconds=150,invasionSeconds=150,
	maxPaybackSeconds=1800,blockedPaybackSeconds=600,savingPaybackFraction=0.5,
	utilityFraction=0.10,savingUtilityFraction=0.02,savingCombatFraction=0.10,
	targetRank=3,invasionReplays=true,killsPerDefender=1,maxBuysPerTick=40,
	print=true,
}

-- Utility research, cheapest-useful first. Prerequisites are enforced by ResearchRules.Status.
local RESEARCH_PRIORITY={"L1","R1","FuseMachine","S1","S4","S2","L2","S15","L3","S5","S16","S3","L4","S17","L5","L6"}

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
		if math.abs(n)>=unit[1] then return string.format("$%.2f%s",n/unit[1],unit[2]) end
	end
	return "$"..math.floor(n)
end

-- Egg economy (EggService:Produce + instant deposit through PlayerSession:Credit) ---------
local function unitValue(s)
	return Rules.EggUnitValue(s.incomeLevel)*(1+s.researchEffects.eggValue)*(1+(s.territoryBonus or 0))
end
local function petEggs(pet,level)
	return Rules.EggRate(pet.species,pet.stars or 1,level or pet.level)*MutationCatalog.Multiplier(pet.mutation)
end
-- Raw egg value per second before EarnedAmount (what the yard lays).
local function rawRate(s,homeOnly)
	local eggs=0
	for id,pet in s.pets do
		if not homeOnly or s:IsPetHome(id) then eggs+=petEggs(pet) end
	end
	return eggs*s:EggProductionMultiplier()*unitValue(s)
end
-- Cash per second once sold (Re-enlist multiplier included).
local function cashRate(s,homeOnly) return s:EarnedAmount(rawRate(s,homeOnly),"eggs") end
local function petCash(s,pet,level)
	return s:EarnedAmount(petEggs(pet,level)*s:EggProductionMultiplier()*unitValue(s),"eggs")
end

local function deposit(state)
	local s=state.session
	local whole=math.floor(state.bag)
	if whole<1 then return end
	local credited=s:Credit(whole,"eggs")
	if credited>0 then state.bag-=whole;state.stats.eggCash+=credited end
end

-- Army and targets -------------------------------------------------------------------
local function petPower(pet,level)
	return Rules.PetPower(pet.species,pet.stars or 1,level or pet.level,pet.giantSize)
end
local function armyPower(s) return Rules.Power(s:Lineup()) end
-- Lineup, set of its ids, and the power a newcomer must beat to join (0 if a slot is free).
local function lineupInfo(s)
	local lineup=s:Lineup()
	local ids,weakest={},math.huge
	for _,p in lineup do ids[p.id]=true;weakest=math.min(weakest,petPower(p)) end
	return lineup,ids,(if #lineup<s:Capacity() then 0 else weakest)
end
local function weakestReserve(s)
	if s:Count()<=s:StarterFlockMinimum() then return nil end
	local selected={}
	for _,id in s:BestPetIds() do selected[id]=true end
	local pick,low=nil,math.huge
	for id,pet in s.pets do
		if not selected[id] and not pet.favorite and s:IsPetHome(id) then
			local value=petEggs(pet)
			if value<low then pick,low=pet,value end
		end
	end
	return pick
end

local function enemyScale(s) return Rebirth.EnemyScale(s.rebirths or 0) end
local function campPower(s,index)
	return math.floor(Rules.Power(Progression.Roster(s.promotion,index))*enemyScale(s))
end
local function invasionTier(s)
	return math.max(s.researchEffects.operations or 0,if s.kingCleared then 1 else 0)
end

local function nextTarget(s)
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
	local tier=invasionTier(s)
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

local function refreshTerritory(s)
	local total=0
	for index,won in s.firstWins do
		if won then total+=Config.Territories.CampBonus[index] or 0 end
	end
	if s.kingCleared then total+=Config.Territories.KingBonus end
	s.territoryBonus=math.floor(total*1000+0.5)/1000
end

local function killCash(state,roster)
	local s,total=state.session,0
	for _,unit in roster do
		local repeatBoss=unit.boss==true and (s.kingCleared==true or s.kingBountyPaid==true)
		local times=if unit.boss then 1 else state.options.killsPerDefender
		total+=math.floor(CombatRewards.ForUnit(unit,nil,repeatBoss)*(1+(s.researchEffects.bounty or 0)))*times
	end
	return math.floor(total)
end

local function mark(state,key,now,coins)
	if state.milestones[key] then return end
	local s=state.session
	state.milestones[key]={minutes=now/60,coins=coins or s.coins,income=cashRate(s,false),
		power=armyPower(s),flock=s:Count(),rank=s.rebirths}
end

local function deploy(state,now,kind,data,seconds)
	-- Any non-Home state: the selected squad stops laying (PlayerSession:IsPetHome).
	state.session.armyState="Marching"
	state.deploy={kind=kind,data=data,returnAt=now+seconds}
end

local function resolve(state,now)
	local s,job,stats=state.session,state.deploy,state.stats
	state.deploy=nil
	s.armyState="Home"
	if job.kind=="Camp" then
		local index=job.data.index
		local cash=killCash(state,Progression.Roster(s.promotion,index))
		s.firstWins[index]=true
		s:UnlockProgress()
		s.tutorial.wonCamp=true;s.tutorial.guideCompleted=true
		stats.battleCash+=s:Credit(cash,"battle")
		refreshTerritory(s)
		mark(state,"FirstCamp",now)
		local all=true
		for i=1,#Progression.Camps(s.promotion) do if not s.firstWins[i] then all=false end end
		if all then mark(state,"AllCamps",now) end
	elseif job.kind=="King" then
		local cash=killCash(state,job.data.roster)
		s.kingBountyPaid=true;s.kingCleared=true
		stats.battleCash+=s:Credit(cash,"battle")
		refreshTerritory(s)
		mark(state,"King",now)
		mark(state,"King"..s.rebirths,now)
	elseif job.kind=="Invasion" then
		local id=job.data.id
		local definition=Operations.Encounters[id]
		local first=not s.research.operationWins[id]
		-- OperationService:Resolve: EarnedAmount(...,"battle") credited as "operation".
		local amount=math.floor(s:EarnedAmount(if first then definition.firstCash else definition.replayCash,"battle"))
		local credited=s:Credit(amount,"operation")
		stats.invasionCash+=credited
		if first then stats.invasionFirsts+=1 else stats.invasionReplays+=1 end
		s.research.operationWins[id]=true;s.research.revision+=1
		mark(state,"Invasion",now)
	end
	s:RefreshArmy();s:Touch()
end

local function chooseAttack(state,now)
	local s,options=state.session,state.options
	if state.deploy or s.armyState~="Home" or #s:Lineup()==0 then return end
	local power=armyPower(s)
	local target=nextTarget(s)
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
		if won and definition and definition.tier<=invasionTier(s)
			and Guide.Difficulty(power,Operations.Power(id))=="Should win" and definition.replayCash>bestCash then
			best,bestCash=id,definition.replayCash
		end
	end
	if not best then return end
	local _,ids=lineupInfo(s)
	local squadIncome=0
	for id in ids do squadIncome+=petCash(s,s.pets[id]) end
	if bestCash>squadIncome*options.invasionSeconds then
		deploy(state,now,"Invasion",{id=best},options.invasionSeconds)
	end
end

-- Spending -----------------------------------------------------------------------------
local function startResearch(s,id,now)
	local node=ResearchCatalog.Nodes[id]
	local duration=ResearchRules.Duration(node,s.researchEffects)
	return Research.Start(s,id,s.research.revision,node.price,duration,now)
end
local function researchSlotFree(s) return #s.research.jobs<s.researchEffects.slots end

local function economyCandidates(state,failed,now)
	local s,upgrades=state.session,state.upgrades
	local list={}
	local function add(key,price,gain,delay,buy)
		if failed[key] or not price or price<=0 or gain<=0 then return end
		table.insert(list,{key=key,price=price,payback=price/gain+(delay or 0),buy=buy})
	end
	local full=cashRate(s,false)
	for id,pet in s.pets do
		local level=pet.level or 1
		local price=Rules.ChickenUpgradePrice(pet.species,level)
		if price and s:IsPetHome(id) then
			add("level:"..id,price,petCash(s,pet,level+1)-petCash(s,pet,level),0,
				function() return Army.UpgradeChicken(s,id,level,price) end)
		end
	end
	local speed,rates=s.eggSpeedLevel,UpgradeCatalog.EggSpeedRates
	local speedPrice=UpgradeCatalog.EggSpeedPrices[speed+1]
	if speedPrice and rates[speed+2] then
		add("EggSpeed",speedPrice,full*(rates[speed+2]/rates[speed+1]-1),0,
			function() return upgrades:Buy(nil,s,"EggSpeed",speed,speedPrice) end)
	end
	local value=s:GlobalUpgrade("Income")
	if value then
		local level=s.incomeLevel
		add("EggValue",value.price,full*(Rules.EggUnitValue(level+1)/Rules.EggUnitValue(level)-1),0,
			function() return upgrades:Buy(nil,s,"EggValue",level,value.price) end)
	end
	local plot=s.plotSizeLevel
	local plotPrice=UpgradeCatalog.PlotPrices[plot+1]
	if plotPrice and s:Count()>=s:CollectionLimit()-1 then
		-- Room is only worth what future recruits lay: half the average chicken per new space.
		local extra=UpgradeCatalog.PlotCapacity(plot+1)-s:CollectionLimit()
		add("PlotSize",plotPrice,extra*full/math.max(1,s:Count())*0.5,0,
			function() return upgrades:Buy(nil,s,"PlotSize",plot,plotPrice) end)
	end
	if researchSlotFree(s) then
		for id,node in ResearchCatalog.Nodes do
			if (node.effect=="production" or node.effect=="eggValue")
				and ResearchRules.Status(s.research,id,math.huge)=="Available" then
				local old=s.researchEffects[node.effect] or 0
				local new=math.max(old,node.value)
				add("research:"..id,node.price,full*((1+new)/(1+old)-1),ResearchRules.Duration(node,s.researchEffects),
					function() return startResearch(s,id,now) end)
			end
		end
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
	for _,entry in lineup do
		local pet=s.pets[entry.id]
		local level=pet.level or 1
		local price=Rules.ChickenUpgradePrice(pet.species,level)
		if price then
			add("level:"..pet.id,price,petPower(pet,level+1)-petPower(pet,level),
				function() return Army.UpgradeChicken(s,pet.id,level,price) end)
		end
	end
	local slot=s:NextSlot()
	if slot then
		local bestReserve=0
		for id,pet in s.pets do if not inLineup[id] then bestReserve=math.max(bestReserve,petPower(pet)) end end
		local capacity=s.capacity
		add("ArmySize",slot.price,bestReserve,function() return state.upgrades:Buy(nil,s,"ArmySize",capacity,slot.price) end)
	end
	if s:MergeAccess() then
		for _,option in Army.MergeOptions(s) do
			local inputs=0
			for _,id in {option.firstId,option.secondId,option.thirdId} do if inLineup[id] then inputs+=1 end end
			if inputs<=1 then
				local before=Rules.PetPower(option.species,option.stars,option.level)
				local after=Rules.PetPower(option.species,option.stars,option.level+1)
				add("merge:"..option.key,option.price,after-(if inputs==1 then before else weakest),
					function() return Army.Merge(s,option.firstId,option.secondId,option.thirdId,option.level,option.price) end)
			end
		end
	end
	return list
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

local function chooseUtility(state,failed,budget,now)
	local s=state.session
	local luck=s:GlobalUpgrade("Luck")
	if luck and not failed.Luck and luck.price<=budget then
		local level=s.luck
		return {key="Luck",price=luck.price,buy=function() return state.upgrades:Buy(nil,s,"Luck",level,luck.price) end}
	end
	local slots=s.rollSlotsUnlocked
	local slotPrice=UpgradeCatalog.RollSlotPrices[slots]
	if slotPrice and slots<(s.rollSlotLimit or 1) and not failed.RollSlots and slotPrice<=budget then
		return {key="RollSlots",price=slotPrice,buy=function() return state.upgrades:Buy(nil,s,"RollSlots",slots,slotPrice) end}
	end
	if researchSlotFree(s) then
		for _,id in RESEARCH_PRIORITY do
			local node=ResearchCatalog.Nodes[id]
			local key="research:"..id
			if node and not failed[key] and node.price<=budget and ResearchRules.Status(s.research,id,s.coins)=="Available" then
				return {key=key,price=node.price,buy=function() return startResearch(s,id,now) end}
			end
		end
	end
	return nil
end

local function syncSlots(s)
	-- WorldService binds the physical podiums; every authored podium exists here.
	s.rollSlotCount=math.clamp(s.rollSlotsUnlocked,1,s.rollSlotLimit or 1)
end

local function context(state)
	local s,options=state.session,state.options
	local target=nextTarget(s)
	local blocked=target~=nil and not attackable(armyPower(s),target)
	local limit=if blocked then options.blockedPaybackSeconds else options.maxPaybackSeconds
	local saving=false
	local coins=s.coins
	if (s.kingCleared or s.rebirths>=1) and s.rebirths<options.targetRank then
		local cost=Rebirth.Cost(s.rebirths+1)
		local need=if cost then cost-coins else 0
		if need>0 then
			saving=true
			limit=math.min(limit,need/math.max(1,cashRate(s,false))*options.savingPaybackFraction)
		end
	end
	return {target=target,blocked=blocked,paybackLimit=limit,saving=saving,
		combatBudget=if not blocked then 0 elseif saving then coins*options.savingCombatFraction else math.huge,
		utilityBudget=coins*(if saving then options.savingUtilityFraction else options.utilityFraction)}
end

local function spend(state,ctx,now)
	local s,stats=state.session,state.stats
	local failed={}
	for _=1,state.options.maxBuysPerTick do
		local choice,pool=chooseEconomy(economyCandidates(state,failed,now),s.coins,ctx.paybackLimit),"economy"
		if not choice and ctx.blocked then
			choice,pool=chooseCombat(combatCandidates(state,failed),math.min(s.coins,ctx.combatBudget)),"combat"
		end
		if not choice then
			choice,pool=chooseUtility(state,failed,math.min(s.coins,ctx.utilityBudget),now),"utility"
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

local function judgeOffers(state,ctx,at)
	local s,stats=state.session,state.stats
	-- October 14 difficulty milestones: first Mythic / Galaxy Overlord / Golden offer
	-- seen and owned, first Giant / Colossal in the flock.
	for _,pet in s.pets do
		if GiantChicken.IsValidSize(pet.giantSize) then
			mark(state,"Giant",at)
			if GiantChicken.IsColossal(pet.giantSize) then mark(state,"Colossal",at) end
		end
		local def=PetCatalog[pet.species]
		if def and def.rarity=="Mythic" then mark(state,"MythicOwned",at) end
		if pet.species=="StormDuck" then mark(state,"GalaxyOwned",at) end
		if pet.mutation=="Golden" then mark(state,"GoldenOwned",at) end
	end
	for slot=1,s.rollSlotCount or 1 do
		local offer=s.offers and s.offers[slot]
		if offer then
			local def=PetCatalog[offer.species]
			if def and def.rarity=="Mythic" then mark(state,"MythicSeen",at) end
			if offer.species=="StormDuck" then mark(state,"GalaxySeen",at) end
			if offer.mutation=="Golden" then mark(state,"GoldenSeen",at) end
		end
		if not offer or offer.price>s.coins then continue end
		local pet={species=offer.species,stars=1,level=offer.level,mutation=offer.mutation}
		local gain,netPrice=petCash(s,pet,offer.level),offer.price
		local sell=nil
		if s:Count()>=s:CollectionLimit() then
			sell=weakestReserve(s)
			if not sell then continue end
			gain-=petCash(s,sell)
			netPrice-=Rules.SellValue(sell.investment or Rules.Investment(sell.species,sell.level))
		end
		local _,_,weakest=lineupInfo(s)
		local powerGain=petPower(pet,offer.level)-weakest
		local economy=gain>0 and math.max(0,netPrice)/gain<=ctx.paybackLimit
		local combat=ctx.blocked and powerGain>0 and offer.price<=ctx.combatBudget
		if not (economy or combat or offer.starter==true) then continue end
		if sell then
			local refund=Rules.SellValue(sell.investment or Rules.Investment(sell.species,sell.level))
			if not Army.Sell(s,{sell.id},true,refund) then continue end
			stats.sold+=1
		end
		if state.rolls:Buy(s,offer.id,at) then
			stats.recruits+=1
			if combat and not economy then ctx.combatBudget-=offer.price end
		end
	end
end

local function rollAndBuy(state,ctx,now)
	local s=state.session
	local pulls=0
	while state.nextRollAt<=now and pulls<8 do
		local at=state.nextRollAt
		state.nextRollAt+=state.options.rollEverySeconds
		pulls+=1
		-- Opening: Army Size 4 first, then the guaranteed $600 recruit (both earmarked).
		if s:StarterRecruitPending() and s.capacity<4 then
			local slot=s:NextSlot()
			if slot then state.upgrades:Buy(nil,s,"ArmySize",s.capacity,slot.price) end
		end
		if at>=s.rollReadyAt and state.rolls:Roll(s,at) then
			state.stats.rolls+=1
			judgeOffers(state,ctx,s.rollRevealAt+0.01)
		end
	end
end

local function tryRebirth(state,now)
	local s,options=state.session,state.options
	-- October 14: only Rebirth 1 needs a King clear.
	if (not s.kingCleared and s.rebirths==0) or s.rebirths>=options.targetRank or state.deploy then return end
	local cost=Rebirth.Cost(s.rebirths+1)
	if not cost then return end
	-- Sell the yard first when that makes the rank affordable.
	if s.coins<cost and s.coins+s:EarnedAmount(state.bag,"eggs")>=cost then deposit(state) end
	if not Rebirth.Quote(s).eligible then return end
	local before=s.coins
	local ok=Rebirth.Rebirth(s,s.rebirths,nil)
	if not ok then return end
	-- No BattleService here: release the flags ourselves; yard eggs are cleared.
	s.territoryBonus=0
	state.bag=0
	-- Cash is the balance just before the reset; income is the post-reset rate.
	state.milestones["Rebirth"..s.rebirths]={minutes=now/60,coins=before,income=cashRate(s,false),
		power=armyPower(s),flock=s:Count(),rank=s.rebirths,cost=cost}
end

local function runOnce(seed,options)
	local random=lcg(seed*7919)
	local s=Session.new(-(70000+seed),"Simulation",1)
	s.loaded=true
	s.rollSlotLimit=Config.RollSlotsUnlocked
	s.plotExpansionAvailable=true
	syncSlots(s)
	local rolls=Rolls.new()
	rolls.random=random
	local state={session=s,options=options,rolls=rolls,upgrades=Upgrades.new(nil,rolls),
		bag=0,deploy=nil,nextRollAt=2,milestones={},
		stats={rolls=0,recruits=0,sold=0,eggCash=0,battleCash=0,invasionCash=0,
			invasionFirsts=0,invasionReplays=0,purchases={economy=0,combat=0,utility=0}}}
	local horizon,dt=options.hours*3600,options.tickSeconds
	local nextDeposit,now=options.depositSeconds,0
	while now<horizon and s.rebirths<options.targetRank do
		state.bag+=rawRate(s,true)*dt
		now+=dt
		if now>=nextDeposit then deposit(state);nextDeposit+=options.depositSeconds end
		Research.Complete(s,math.floor(now))
		if state.deploy and now>=state.deploy.returnAt then resolve(state,now) end
		tryRebirth(state,now)
		local ctx=context(state)
		spend(state,ctx,math.floor(now))
		rollAndBuy(state,ctx,now)
		chooseAttack(state,now)
	end
	local research=0
	for _ in s.research.completed do research+=1 end
	return {seed=seed,minutes=now/60,milestones=state.milestones,stats=state.stats,
		final={rank=s.rebirths,coins=s.coins,income=cashRate(s,false),power=armyPower(s),flock=s:Count(),
			capacity=s:Capacity(),collectionLimit=s:CollectionLimit(),eggSpeed=s.eggSpeedLevel,eggValue=s.incomeLevel,
			luck=s.luck,rollSlots=s.rollSlotsUnlocked,research=research,promotion=s.promotion}}
end

local ROWS={
	{"FirstCamp","First camp",nil},
	{"AllCamps","All 3 camps",nil},
	{"King","First King clear","45-90 min"},
	{"Invasion","First Invasion",nil},
	{"Rebirth1","Rebirth 1","1.5-3 h"},
	{"King1","King at Rebirth 1",nil},
	{"Rebirth2","Rebirth 2","4-8 h"},
	{"King2","King at Rebirth 2",nil},
	{"Rebirth3","Rebirth 3","10-20 h"},
	{"GoldenSeen","First Golden offer",nil},
	{"GoldenOwned","First Golden owned",nil},
	{"MythicSeen","First Mythic offer",nil},
	{"MythicOwned","First Mythic owned",nil},
	{"GalaxySeen","First Galaxy offer",nil},
	{"GalaxyOwned","First Galaxy owned",nil},
	{"Giant","First Giant",nil},
	{"Colossal","First Colossal",nil},
}

local function median(values)
	if #values==0 then return nil end
	table.sort(values)
	return values[math.ceil(#values/2)]
end

local function report(results)
	local lines={}
	local function line(text) table.insert(lines,text) end
	local o=results.options
	line(string.format("ProgressionSimulation · %s seed(s) · tick %ss · horizon %sh · Rebirth %s first, +%s per rank after the list, enemies +%s/rank · %.1fs runtime",
		tostring(o.seeds),tostring(o.tickSeconds),tostring(o.hours),money(Config.Rebirth.Costs[1]),money(Config.Rebirth.CostStep),
		tostring(Config.Rebirth.EnemyHealthPerRank),results.seconds))
	line(string.format("%-20s %9s %7s %12s %12s %9s %6s  %s","Milestone","Minutes","Hours","Cash","Egg $/s","Power","Flock","Target (plan 6.9)"))
	for _,row in ROWS do
		local minutes,cash,income,power,flock,reached={}, {}, {}, {}, {},0
		for _,run in results.runs do
			local m=run.milestones[row[1]]
			if m then
				reached+=1
				table.insert(minutes,m.minutes);table.insert(cash,m.coins);table.insert(income,m.income or 0)
				table.insert(power,m.power);table.insert(flock,m.flock)
			end
		end
		local mm=median(minutes)
		line(string.format("%-20s %9s %7s %12s %12s %9s %6s  %s%s",row[2],
			if mm then string.format("%.1f",mm) else "never",if mm then string.format("%.2f",mm/60) else "-",
			money(median(cash)),money(median(income)),tostring(median(power) or "-"),tostring(median(flock) or "-"),
			row[3] or "",if #results.runs>1 then string.format(" (%d/%d runs)",reached,#results.runs) else ""))
	end
	for _,run in results.runs do
		local st,f=run.stats,run.final
		line(string.format("seed %d: ended %.0f min at rank %d · eggs %s, kills %s, Invasions %s (%d first, %d replays) · rolls %d, recruits %d, sold %d · buys econ %d / combat %d / utility %d",
			run.seed,run.minutes,f.rank,money(st.eggCash),money(st.battleCash),money(st.invasionCash),st.invasionFirsts,st.invasionReplays,
			st.rolls,st.recruits,st.sold,st.purchases.economy,st.purchases.combat,st.purchases.utility))
		line(string.format("  final: %s cash, %s/s eggs, power %d, flock %d/%d, army %d, speed L%d, value L%d, luck L%d, podiums %d, research %d",
			money(f.coins),money(f.income),f.power,f.flock,f.collectionLimit,f.capacity,f.eggSpeed,f.eggValue,f.luck,f.rollSlots,f.research))
	end
	line("Medians across seeds. Rebirth rows: Cash = balance just before the reset, Egg $/s = rate right after it.")
	line("Model, not playtime: see the header assumptions in tests/ProgressionSimulation.luau.")
	print(table.concat(lines,"\n"))
end

function Simulation.Run(options)
	local merged=table.clone(DEFAULTS)
	for key,value in options or {} do merged[key]=value end
	local previousSizeRandom=Army.SizeRandom
	local runs={}
	local started=os.clock()
	local ok,problem=pcall(function()
		for seed=1,merged.seeds do
			Army.SizeRandom=lcg(seed*104729) -- Deterministic Giant rolls; restored below.
			table.insert(runs,runOnce(seed,merged))
		end
	end)
	Army.SizeRandom=previousSizeRandom
	if not ok then error(problem,0) end
	local results={options=merged,runs=runs,seconds=os.clock()-started,
		assumptions="Free player, continuous active play, coarse closed-form egg accrual with 60 s deposits; "
			.."fights decided by TutorialGuide.Difficulty (Close fight for camps/King, Should win for Invasions) and always won; "
			.."greedy payback/power/utility spending; rebirth as soon as eligible. See the file header."}
	if merged.print then report(results) end
	return results
end

return setmetatable(Simulation,{__call=function(_,options) return Simulation.Run(options) end})
