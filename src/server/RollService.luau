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
local TutorialGuide = require(Shared.TutorialGuide)
local EventService = require(script.Parent.EventService)
local RebirthChickens = require(script.Parent.RebirthChickens)
local RollService = {}
RollService.__index = RollService

function RollService.new()
	return setmetatable({random=Random.new(),analytics=nil::any}, RollService)
end

-- October 25 (Stevin): an empty-start profile's lever keeps the next starter-ladder Common
-- on the first podium, at its tutorial price, until the guide completes or it owns the
-- ladder's three (Config.Economy.StarterLadder). Nil for everyone else.
local function ladderStep(session): any
	local ladder = Config.Economy.StarterLadder
	if type(ladder) ~= "table" or session.introRebirth == nil then return nil end
	local t = session.tutorial
	if type(t) ~= "table" or t.guideCompleted == true or t.guideSkipped == true or t.coreDone == true then return nil end
	local step = ladder[(session:Count() :: number) + 1]
	return if type(step) == "table" and Catalog[step.species] then step else nil
end

-- October 25 (Stevin): after the guide, the next Config.Economy.FavoredRolls.rolls pulls
-- have `chance` of the basic Chicken on the first podium (at its normal price), counted
-- on tutorial.rollCount; nil for everyone else.
local function favoredSpecies(session, rng): string?
	local favor = Config.Economy.FavoredRolls
	if type(favor) ~= "table" or session.introRebirth == nil then return nil end
	local t = session.tutorial
	if type(t) ~= "table" or t.guideCompleted ~= true or t.guideSkipped == true then return nil end
	local ladder = Config.Economy.StarterLadder
	local tutorialPulls = if type(ladder) == "table" then #ladder else 2
	if (tonumber(t.rollCount) or 0) >= tutorialPulls + (favor.rolls or 0) then return nil end
	if not Catalog[favor.species] or rng:NextNumber() >= (favor.chance or 0) then return nil end
	return favor.species
end

function RollService:Roll(session, now: number)
	if now < session.rollReadyAt then return false, "Roll ready in " .. math.max(1, math.ceil(session.rollReadyAt - now)) .. "s." end
	local starter = session:StarterRecruitPending()
	local ladder = if starter then nil else ladderStep(session)
	local favored = if starter or ladder then nil else favoredSpecies(session, session.debugRandom or self.random)
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
		local forced=if slot==1 then session.debugNext or (ladder and ladder.species) or favored or guaranteed else nil
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
			level=level,price=if starter then Config.Economy.StarterRecruitPrice
				elseif slot==1 and ladder and type(ladder.price)=="number" then ladder.price else Rules.RecruitPrice(species,level),tier=session.recruitTier,starter=starter,
			luck=session.luck,paidLuck=paidLuck,researchLuck=researchLuck,duration=duration,guaranteed=slot==1 and guaranteed~=nil,
			chance=if starter or (slot==1 and guaranteed) then 1 elseif event then Config.Event.OfferChance else odds[species],
			event=event or nil,rebirthChicken=rebirthChicken or nil,special=special}
		-- October 20 tree v2 (S9c): mutations open in the Upgrades tree; mutationKeep keeps rank unlocks.
		if not starter then offers[slot].mutation=MutationCatalog.Roll(rng,math.max(session.researchEffects.mutations or 0,session.mutationKeep or 0),mutationChance) end
	end
	session.offers,session.offer=offers,offers[1]
	session.debugNext=nil
	session.tutorial.rolled=true
	-- October 24: card 7 ("Pull the lever again!") counts pulls; saved up to the limit.
	session.tutorial.rollCount=math.min((tonumber(session.tutorial.rollCount) or 0)+1,TutorialGuide.RollCountLimit)
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

-- October 20 Auto Roll (S12, S12b; docs/team/AUTO_ROLL.md). The Auto Roll Gem Upgrade
-- unlocks it and the server runs it from anywhere. With the lever ready it holds while a
-- chicken worth keeping waits on a podium (the client shows the hit banner), else rolls.
-- The player recruits it by walking over, pulls the lever, or turns Auto Roll off and on.
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

-- A mutation this chicken has not had yet (among the chickens owned now).
local function newMutation(session, species: string, mutation: string): boolean
	for _,pet in session.pets do
		if pet.species==species and pet.mutation==mutation then return false end
	end
	return true
end

-- Why Auto Roll stops for this offer, or nil to roll on: "rebirth" (always), else
-- the panel's rows (AutoRollRules.Reason: rarity, mutation, normal, new chicken, new mutation).
function RollService.Keeper(session, offer): string?
	if offer.starter then return nil end
	local definition=Catalog[offer.species]
	if offer.rebirthChicken or (definition and definition.rebirthRank) then return "rebirth" end
	-- October 22: the chicken the next Rebirth needs, while it is still missing from the Index.
	if RebirthChickens.Wanted(session,offer.species) then return "rebirth" end
	local auto=session.autoRoll
	local mutation=if MutationCatalog.IsValid(offer.mutation) then offer.mutation else nil
	local fresh=mutation~=nil and auto.newMutation==true and newMutation(session,offer.species,mutation)
	return AutoRollRules.Reason(auto,definition and definition.rarity,mutation,
		not session.discovered[offer.species],fresh)
end

-- The chicken the banner names: Rebirth chickens first, then the rarest. Offers the
-- player rolled on past are ignored until the next pull replaces them.
function RollService.BestKeeper(session)
	local skipped=session.autoRoll.skipped
	local best,bestReason,bestScore=nil,nil,-1
	for slot=1,session.rollSlotCount or 1 do
		local offer=session.offers and session.offers[slot]
		if offer and not (skipped and skipped[offer.id]) then
			local reason=RollService.Keeper(session,offer)
			if reason then
				local definition=Catalog[offer.species]
				local score=((definition and definition.oneIn) or 1)*(if offer.mutation then 2 else 1)
					+(if reason=="rebirth" then 1e15 else 0)
				if score>bestScore then best,bestReason,bestScore=offer,reason,score end
			end
		end
	end
	return best,bestReason
end

-- Returns "rolled" or "held" when something changed.
function RollService:StepAuto(session, now: number): string?
	local auto=session.autoRoll
	if not auto.enabled or not RollService.AutoUnlocked(session) then
		if auto.held then auto.held=nil;session:Touch() end
		return nil
	end
	if session:StarterRecruitPending() or now<session.rollReadyAt then return nil end
	-- Still holding the same chicken: wait for the player.
	if auto.held and findOffer(session,auto.held) and not (auto.skipped and auto.skipped[auto.held]) then return nil end
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

-- SetAutoRoll {enabled?}, {rarity=<name>, on=<bool>}, {mutation=<id or "Normal">,
-- on=<bool>}, {newChicken=<bool>} or {newMutation=<bool>}. Turning Auto Roll back on
-- rolls on past the chickens already on the podiums.
function RollService:SetAutoRoll(session, request): (boolean, string)
	if not RollService.AutoUnlocked(session) then return false,"Unlock Auto Roll in Gem Upgrades." end
	local function flag(value) return value==nil or type(value)=="boolean" end
	local valid=flag(request.enabled) and flag(request.on) and flag(request.newChicken) and flag(request.newMutation)
		and (request.rarity==nil or table.find(AutoRollRules.Rarities,request.rarity)~=nil)
		and (request.mutation==nil or table.find(AutoRollRules.Mutations,request.mutation)~=nil)
		and ((request.rarity==nil and request.mutation==nil) or request.on~=nil)
	if not valid then return false,"Invalid Auto Roll setting." end
	local auto=session.autoRoll
	if request.enabled==true and not auto.enabled then
		local skipped={}
		for slot=1,session.rollSlotCount or 1 do
			local offer=session.offers and session.offers[slot]
			if offer then skipped[offer.id]=true end
		end
		auto.skipped=skipped
	end
	if request.enabled~=nil then auto.enabled=request.enabled end
	if request.rarity then auto.rarities[request.rarity]=if request.on then true else nil end
	if request.mutation then auto.mutations[request.mutation]=if request.on then true else nil end
	if request.newChicken~=nil then auto.newChicken=request.newChicken end
	if request.newMutation~=nil then auto.newMutation=request.newMutation end
	auto.held=nil
	session:Touch()
	return true,if auto.enabled then "Auto Roll on." else "Auto Roll off."
end

-- state.autoRoll (contract §8): the rows, unlocked = the Auto Roll Gem Upgrade, and the
-- chicken it is holding with the banner line.
function RollService.AutoSnapshot(session)
	local auto=session.autoRoll
	local held=if auto.held then findOffer(session,auto.held) else nil
	local snapshot={enabled=auto.enabled==true,unlocked=RollService.AutoUnlocked(session),
		rarities=table.clone(auto.rarities),mutations=table.clone(auto.mutations),
		newChicken=auto.newChicken==true,newMutation=auto.newMutation==true,holding=held~=nil,held=nil::any}
	if held then
		local definition=Catalog[held.species]
		local rarity=definition and definition.rarity
		snapshot.held={offerId=held.id,slot=held.slot,species=held.species,mutation=held.mutation,
			reason=auto.heldReason,rarity=rarity,banner=AutoRollRules.Banner(auto.heldReason,rarity,held.mutation)}
	end
	return snapshot
end

-- state.goldRolls: the machine's counters, Gold first (GoldRolls.Counters).
function RollService.GoldSnapshot(session)
	return {counters=GoldRolls.Counters(session.goldRolls,session.researchEffects)}
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
	if session.coins < price then session.coinShortfall=price-session.coins;return false, "Not enough coins. This offer will wait for you." end
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
