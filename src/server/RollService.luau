--!strict
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.PetCatalog)
local Rules = require(Shared.Rules)
local MutationCatalog = require(Shared.MutationCatalog)
local Currency = require(Shared.CurrencyLimits)
local AutoRollRules = require(Shared.AutoRollRules)
local GoldRolls = require(Shared.GoldRolls)
local EventService = require(script.Parent.EventService)
local RebirthChickens = require(script.Parent.RebirthChickens)
local RollService = {}
RollService.__index = RollService

function RollService.new()
	return setmetatable({random=Random.new(),analytics=nil::any}, RollService)
end

function RollService:Roll(session, now: number)
	if now < session.rollReadyAt then return false, "Roll ready in " .. math.max(1, math.ceil(session.rollReadyAt - now)) .. "s." end
	local starter = session:StarterRecruitPending()
	-- Rank metadata remains compatible with saved sessions; rolls use the full roster.
	session.recruitTier=session.promotion
	local rng = session.debugRandom or self.random
	local paidLuck = session:PaidLuckMultiplier()
	-- Extra Luck plus a running Playtime Rewards Luck boost (S16).
	local researchLuck = session:RollLuckBonus()
	-- October 20 Gold rolls (GoldRolls): with the Gold Machine every Nth lever pull,
	-- manual or Auto Roll, is special and every podium on it rolls with extra Luck.
	local special = if starter then nil else GoldRolls.Advance(session.goldRolls, session.researchEffects)
	if special then researchLuck = (1 + researchLuck) * GoldRolls.Luck(special) - 1 end
	local duration = Config.RollRevealSeconds / (1 + (session.researchEffects.rollingSpeed or 0))
	local debugRoll = session.debugNext ~= nil or session.debugRandom ~= nil
	-- Only verified restricted owners advance the disclosed fixed offer schedule.
	-- Debug rolls, cooldown failures and unverified ownership cannot consume progress.
	local guaranteed = if not debugRoll and not starter then session:AdvanceGuaranteedLuck() else nil
	local offers={}
	local odds=Rules.Odds(session.luck,session.recruitTier,paidLuck,researchLuck)
	local count=if starter then 1 else math.clamp(session.rollSlotCount or 1,1,Config.RollSlotsUnlocked)
	-- Mutation Luck (Gem Upgrade) scales every mutation chance.
	local mutationChance=1+(session.researchEffects.mutationLuck or 0)
	for slot=1,count do
		-- The disclosed guarantee advances once per lever pull, not once per display.
		local forced=if slot==1 then session.debugNext or guaranteed else nil
		local species=if starter then "Duck" else forced or Rules.Draw(session.luck,rng:NextNumber(),session.recruitTier,paidLuck,researchLuck)
		-- Launch hooks: never the starter or a forced first slot.
		local drawn=species
		local event,rebirthChicken=false,false
		if not starter and not forced then
			local replaced=EventService.MaybeReplace(session,species,rng,slot,os.time())
			event=replaced~=drawn
			-- October 20 Rebirth chickens (contract §5): only ever replace a weaker offer.
			species=RebirthChickens.MaybeReplace(session,replaced,rng,slot)
			rebirthChicken=species~=replaced
			if rebirthChicken then event=false end
		end
		local level=if starter then 1 else Rules.RecruitLevel(session.pets,species,session.promotion)
		offers[slot]={id=HttpService:GenerateGUID(false),slot=slot,species=species,debug=debugRoll,
			level=level,price=if starter then Config.Economy.StarterRecruitPrice else Rules.RecruitPrice(species,level),tier=session.recruitTier,starter=starter,
			luck=session.luck,paidLuck=paidLuck,researchLuck=researchLuck,duration=duration,guaranteed=slot==1 and guaranteed~=nil,
			chance=if starter or (slot==1 and guaranteed) then 1 elseif event then Config.Event.OfferChance else odds[species],
			event=event or nil,rebirthChicken=rebirthChicken or nil,special=special}
		if not starter then offers[slot].mutation=MutationCatalog.Roll(rng,session.rebirths or 0,mutationChance) end
	end
	session.offers,session.offer=offers,offers[1]
	session.debugNext=nil
	session.tutorial.rolled=true
	-- A new roll replaces every offer, so an Auto Roll hold or skip is over.
	session.autoRoll.held,session.autoRoll.heldReason,session.autoRoll.skipped=nil,nil,nil
	-- Freeze this roll: completing research cannot move an accepted reveal deadline.
	session.rollRevealAt = now + duration
	-- The lever unlocks with the reveal, without a second post-roll cooldown.
	session.rollReadyAt = session.rollRevealAt
	session:Touch()
	if special then return true, special .. " roll! Every podium has " .. GoldRolls.Luck(special) .. "x Luck." end
	return true, "Rolling on your podiums…"
end

-- October 20 Auto Roll (S12, docs/team/AUTO_ROLL.md). The Auto Roll Gem Upgrade
-- unlocks it and the server runs it from anywhere. Each tick with the lever ready it
-- recruits offers at or above recruitAt that the player can afford, then holds while a
-- chicken worth keeping waits on a podium (the client shows the alert), else rolls.
function RollService.AutoUnlocked(session): boolean
	return (session.researchEffects.autoRoll or 0)>=1
end

local function findOffer(session, offerId: any)
	for slot=1,session.rollSlotCount or 1 do
		local offer=session.offers and session.offers[slot]
		if offer and offer.id==offerId then return offer end
	end
	return nil
end

-- The weakest chicken in the Army the player picked. October 20 fix: BestPetIds keeps
-- a manual selection; the old rule read the automatic best list, so it stopped for
-- chickens that would not join (the launch review's manual-selection trap). An empty
-- slot counts only while the Army is automatic, where a new recruit joins it.
local function weakestArmyPower(session): number
	local army=session:BestPetIds()
	if #army==0 or (session.armySelection==nil and #army<session:Capacity()) then return -math.huge end
	local weakest=math.huge
	for _,id in army do
		local pet=session.pets[id]
		if pet then weakest=math.min(weakest,Rules.PetPower(pet.species,pet.stars,pet.level,pet.giantSize)) end
	end
	return weakest
end

-- Why Auto Roll stops for this offer ("rebirth", "mutation", "rarity", "upgrade"), or
-- nil to roll on. cache keeps one Army lookup across a pull's podiums.
function RollService.Keeper(session, offer, cache: {[string]: number}?): string?
	if offer.starter then return nil end
	local auto=session.autoRoll
	local definition=Catalog[offer.species]
	if offer.rebirthChicken or (definition and definition.rebirthRank) then return "rebirth" end
	if auto.mutationStop~=false and offer.mutation then return "mutation" end
	if AutoRollRules.Meets(offer.species,auto.stopAt,offer.chance) then return "rarity" end
	if auto.upgradeStop~=false then
		local known=cache or {}
		known.weakest=known.weakest or weakestArmyPower(session)
		if Rules.PetPower(offer.species,1,offer.level)>known.weakest then return "upgrade" end
	end
	return nil
end

-- The chicken the alert shows: Rebirth chickens first, then the rarest. Offers the
-- player skipped are ignored until the next pull replaces them.
function RollService.BestKeeper(session)
	local skipped=session.autoRoll.skipped
	local cache={}
	local best,bestReason,bestScore=nil,nil,-1
	for slot=1,session.rollSlotCount or 1 do
		local offer=session.offers and session.offers[slot]
		if offer and not (skipped and skipped[offer.id]) then
			local reason=RollService.Keeper(session,offer,cache)
			if reason then
				local score=(AutoRollRules.OneIn(offer.species,offer.chance) or 1)*(if offer.mutation then 2 else 1)
					+(if reason=="rebirth" then 1e15 else 0)
				if score>bestScore then best,bestReason,bestScore=offer,reason,score end
			end
		end
	end
	return best,bestReason
end

-- Returns "rolled", "recruited" (with the receipts) or "held" when something changed.
function RollService:StepAuto(session, now: number, context): (string?, {any}?)
	local auto=session.autoRoll
	if not auto.enabled or not RollService.AutoUnlocked(session) then
		if auto.held then auto.held=nil;session:Touch() end
		return nil
	end
	if session:StarterRecruitPending() or now<session.rollReadyAt then return nil end
	-- Still holding the same chicken: wait for Recruit, Skip, a settings change or the lever.
	if auto.held and findOffer(session,auto.held) and not (auto.skipped and auto.skipped[auto.held]) then return nil end
	if auto.recruitAt then
		local bought={}
		for slot=1,session.rollSlotCount or 1 do
			local offer=session.offers and session.offers[slot]
			if offer and not offer.starter and AutoRollRules.Meets(offer.species,auto.recruitAt,offer.chance)
				and session.coins>=offer.price and session:CanSpendCash(offer.price) then
				local before=session.coins
				local ok,message,petId,recruit=self:Buy(session,offer.id,now,context)
				if ok then table.insert(bought,{petId=petId,message=message,recruit=recruit,before=before,after=session.coins}) end
			end
		end
		if #bought>0 then
			auto.held=nil
			return "recruited",bought
		end
	end
	local keeper,reason=RollService.BestKeeper(session)
	if keeper then
		auto.held,auto.heldReason=keeper.id,reason
		session:Touch()
		-- Observation only (Analytics ServerEvent, set by GameServer): why Auto Roll stopped.
		local analytics=self.analytics
		if analytics then pcall(function() analytics:ServerEvent(session,"autoroll.stop",reason) end) end
		return "held"
	end
	if auto.held then auto.held=nil;session:Touch() end
	if self:Roll(session,now) then return "rolled" end
	return nil
end

-- SetAutoRoll {enabled?, stopAt?, recruitAt? (a "1 in X" number, or false for off),
-- mutationStop?, upgradeStop?, skip?}. skip rolls on past the chickens on the podiums.
function RollService:SetAutoRoll(session, request): (boolean, string)
	if not RollService.AutoUnlocked(session) then return false,"Unlock Auto Roll in Gem Upgrades." end
	local function flag(value) return value==nil or type(value)=="boolean" end
	if not flag(request.enabled) or not flag(request.mutationStop) or not flag(request.upgradeStop) or not flag(request.skip) then
		return false,"Invalid Auto Roll setting."
	end
	local stopAt=if request.stopAt~=nil then AutoRollRules.Clean(request.stopAt) else nil
	local recruitAt=if request.recruitAt~=nil and request.recruitAt~=false then AutoRollRules.Clean(request.recruitAt) else nil
	if (request.stopAt~=nil and not stopAt) or (request.recruitAt~=nil and request.recruitAt~=false and not recruitAt) then
		return false,"Invalid Auto Roll setting."
	end
	local auto=session.autoRoll
	if request.enabled~=nil then auto.enabled=request.enabled end
	if stopAt then auto.stopAt=stopAt end
	if request.recruitAt==false then auto.recruitAt=nil elseif recruitAt then auto.recruitAt=recruitAt end
	if request.mutationStop~=nil then auto.mutationStop=request.mutationStop end
	if request.upgradeStop~=nil then auto.upgradeStop=request.upgradeStop end
	if request.skip==true then
		-- The next pull replaces these offers anyway; skip all of them.
		local skipped={}
		for slot=1,session.rollSlotCount or 1 do
			local offer=session.offers and session.offers[slot]
			if offer then skipped[offer.id]=true end
		end
		auto.skipped=skipped
	end
	auto.held=nil
	session:Touch()
	if request.skip==true then return true,"Skipped. Auto Roll rolls on." end
	return true,if auto.enabled then "Auto Roll on." else "Auto Roll off."
end

-- Recruit from the Auto Roll alert without walking to the podium.
function RollService:RecruitHeld(session, offerId, now: number, context)
	if not RollService.AutoUnlocked(session) then return false,"Unlock Auto Roll in Gem Upgrades." end
	if type(offerId)~="string" or #offerId>80 or not findOffer(session,offerId) then
		return false,"That chicken is no longer on your podium."
	end
	return self:Buy(session,offerId,now,context)
end

-- state.autoRoll (contract §8): the settings, unlocked = the Auto Roll Gem Upgrade,
-- and the chicken it is holding for the alert.
function RollService.AutoSnapshot(session)
	local auto=session.autoRoll
	local held=if auto.held then findOffer(session,auto.held) else nil
	local snapshot={enabled=auto.enabled==true,unlocked=RollService.AutoUnlocked(session),
		stopAt=auto.stopAt,recruitAt=auto.recruitAt,mutationStop=auto.mutationStop~=false,
		upgradeStop=auto.upgradeStop~=false,holding=held~=nil,held=nil::any}
	if held then
		local affordable=session.coins>=held.price and session:CanSpendCash(held.price)
		snapshot.held={offerId=held.id,slot=held.slot,species=held.species,level=held.level,price=held.price,
			mutation=held.mutation,oneIn=AutoRollRules.OneIn(held.species,held.chance),reason=auto.heldReason,
			rebirthChicken=held.rebirthChicken==true,canAfford=affordable==true,
			storageFull=session:Count()>=session:CollectionLimit(),special=held.special}
	end
	return snapshot
end

-- state.goldRolls: what the machine counter shows (GoldRolls.State).
function RollService.GoldSnapshot(session)
	return GoldRolls.State(session.goldRolls and session.goldRolls.count,session.researchEffects)
end

function RollService:Buy(session, offerId, now: number?, context)
	if (now or os.clock()) < session.rollRevealAt then return false, "Wait for the chicken to land on the podium." end
	if type(offerId)~="string" or #offerId>80 then return false,"That offer is no longer available." end
	local offer,slot
	for index=1,session.rollSlotCount or 1 do
		local candidate=session.offers and session.offers[index]
		if candidate and candidate.id==offerId then offer,slot=candidate,index;break end
	end
	if not offer then return false,"That offer is no longer available." end
	local species = offer.species
	local level = math.clamp(offer.level or 1, 1, Config.MaxPetLevel)
	local price = offer.price or Rules.RecruitPrice(species, level)
	if session:Count() >= session:CollectionLimit() then return false, "Storage full — sell chickens in My Army." end
	if session.coins < price then return false, "Not enough coins. This offer will wait for you." end
	local starter=offer.starter==true and session:StarterRecruitPending()
		and species=="Duck" and level==1 and price==Config.Economy.StarterRecruitPrice
	local canSpend,reason=session:CanSpendCash(price,if starter then "StarterRecruit" else nil)
	if not canSpend then return false,reason end
	local before=session:BestPetIds()
	-- This transaction does not yield: an offer cannot be bought twice.
	session.coins -= price
 session.tutorial.bought=true
	local pet = session:AddPet(species, 1, offer.mutation)
	pet.level, pet.investment = level, price
	session.offers[slot]=nil
	session.offer=nil
	for index=1,session.rollSlotCount or 1 do
		if session.offers[index] then session.offer=session.offers[index];break end
	end
	session:RefreshArmy()
	session:Touch()
	local after=session:BestPetIds()
	local selected=table.find(after,pet.id)~=nil
	local assignment=if not selected then "Reserve" elseif #after>#before then "Added" else "Replacement"
	local pending=selected and context and context.phase~="Returning" and context.battleId or nil
	-- October 20 Flock (S10): only Flock chickens lay; one that goes to storage lays
	-- nothing. Before S10's FlockIds exists, every chicken lays.
	local laying=if session.FlockIds then table.find(session:FlockIds(),pet.id)~=nil else true
	local status=if not selected and not laying then "In storage."
		elseif not selected then "Flock · eggs +"..Currency.Rate(session:DisplayedPetIncome(pet.species,pet.stars,pet.level,pet.mutation)).."/s at your base."
		elseif session.armyState=="Returning" then "Ready when your army gets home."
		elseif session:IsArmyLocked() and pending then "Joining your army on foot."
		elseif session:IsArmyLocked() then "Ready for your next deployment."
		elseif assignment=="Added" then "Army "..#before.." → "..#after.."."
		else "Your army got stronger."
	return true, "Bought " .. Catalog[species].name .. " Lv " .. level .. ". "..status, pet.id, {
		assignment=assignment,selectedBefore=#before,selectedAfter=#after,
		pendingBattleId=pending,deferredUntilContestEnds=false,
		-- Analytics only (GameServer:CountRecruit): what kind of offer this was.
		offer={species=species,mutation=offer.mutation,event=offer.event,rebirthChicken=offer.rebirthChicken,special=offer.special},
	}
end

return RollService
