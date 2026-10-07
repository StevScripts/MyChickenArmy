--!strict
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.PetCatalog)
local Rules = require(Shared.Rules)
local RollService = {}
RollService.__index = RollService

function RollService.new()
	return setmetatable({random=Random.new()}, RollService)
end

function RollService:Roll(session, now: number)
	if now < session.rollReadyAt then return false, "Roll is cooling down." end
	local starter = session:StarterRecruitPending()
	-- Rank metadata remains compatible with saved sessions; rolls use the full roster.
	session.recruitTier=session.promotion
	local rng = session.debugRandom or self.random
	local paidLuck = session:PaidLuckMultiplier()
	local researchLuck = session.researchEffects.rollingLuck or 0
	local duration = Config.RollRevealSeconds / (1 + (session.researchEffects.rollingSpeed or 0))
	local debugRoll = session.debugNext ~= nil or session.debugRandom ~= nil
	-- Only verified restricted owners advance the disclosed fixed offer schedule.
	-- Debug rolls, cooldown failures and unverified ownership cannot consume progress.
	local guaranteed = if not debugRoll and not starter then session:AdvanceGuaranteedLuck() else nil
	local offers={}
	local odds=Rules.Odds(session.luck,session.recruitTier,paidLuck,researchLuck)
	local count=if starter then 1 else math.clamp(session.rollSlotCount or 1,1,Config.RollSlotsUnlocked)
	for slot=1,count do
		-- The disclosed guarantee advances once per lever pull, not once per display.
		local forced=if slot==1 then session.debugNext or guaranteed else nil
		local species=if starter then "Duck" else forced or Rules.Draw(session.luck,rng:NextNumber(),session.recruitTier,paidLuck,researchLuck)
		local level=if starter then 1 else Rules.RecruitLevel(session.pets,species,session.promotion)
		offers[slot]={id=HttpService:GenerateGUID(false),slot=slot,species=species,debug=debugRoll,
			level=level,price=if starter then Config.Economy.StarterRecruitPrice else Rules.RecruitPrice(species,level),tier=session.recruitTier,starter=starter,
			luck=session.luck,paidLuck=paidLuck,researchLuck=researchLuck,duration=duration,guaranteed=slot==1 and guaranteed~=nil,
			chance=if starter or (slot==1 and guaranteed) then 1 else odds[species]}
	end
	session.offers,session.offer=offers,offers[1]
	session.debugNext=nil
	session.tutorial.rolled=true
	-- Freeze this roll: completing research cannot move an accepted reveal deadline.
	session.rollRevealAt = now + duration
	-- The lever unlocks with the reveal, without a second post-roll cooldown.
	session.rollReadyAt = session.rollRevealAt
	session:Touch()
	return true, "Rolling on your podiums…"
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
	if session:Count() >= session:CollectionLimit() then return false, "Flock full — sell reserve chickens in the Army menu." end
	if session.coins < price then return false, "Not enough cash. This offer will wait for you." end
	local starter=offer.starter==true and session:StarterRecruitPending()
		and species=="Duck" and level==1 and price==Config.Economy.StarterRecruitPrice
	local canSpend,reason=session:CanSpendCash(price,if starter then "StarterRecruit" else nil)
	if not canSpend then return false,reason end
	local before=session:BestPetIds()
	-- This transaction does not yield: an offer cannot be bought twice.
	session.coins -= price
 session.tutorial.bought=true
	local pet = session:AddPet(species, 1)
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
	local status=if not selected then "Reserve · eggs +$"..session:DisplayedPetIncome(pet.species,pet.stars,pet.level).."/s at home."
		elseif session.armyState=="Returning" then "Ready when your army gets home."
		elseif session:IsArmyLocked() and pending then "Joining your army on foot."
		elseif session:IsArmyLocked() then "Ready for your next deployment."
		elseif assignment=="Added" then "Squad "..#before.." → "..#after.."."
		else "Stronger squad."
	return true, "Bought " .. Catalog[species].name .. " Lv " .. level .. ". "..status, pet.id, {
		assignment=assignment,selectedBefore=#before,selectedAfter=#after,
		pendingBattleId=pending,deferredUntilContestEnds=false,
	}
end

function RollService:UpgradeLuck(session)
	local upgrade=session:GlobalUpgrade("Luck")
	if not upgrade then return false, "Luck is at its maximum." end
	if not upgrade.unlocked then return false,upgrade.requirement.." to improve luck again." end
	local price=upgrade.price
	local canSpend,reason=session:CanSpendCash(price)
	if not canSpend then return false,reason end
	session.coins -= price
	session.luck += 1
 session.tutorial.upgraded=true
	session:Touch()
	return true, "Luck upgraded. Your next podium roll uses the improved chances."
end

return RollService
