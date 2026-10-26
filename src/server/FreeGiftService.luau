--!strict
-- October 16 free gift: one free chicken, once per profile, for joining the group.
-- "Like the game" is honor-system copy only; Roblox exposes no like check.
local GroupService=game:GetService("GroupService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Shared=ReplicatedStorage.PetRoll.Shared
local Config=require(Shared.Config)
local Catalog=require(Shared.PetCatalog)
local FreeGift={}

-- Yields. Player:IsInGroup is cached for the whole server session, so someone who
-- joins after arriving would stay "not a member"; GetGroupsAsync reads it fresh.
-- Returns nil when neither lookup answers.
function FreeGift.InGroup(player:Player):boolean?
	local groupId=Config.FreeGift.GroupId
	local ok,groups=pcall(GroupService.GetGroupsAsync,GroupService,player.UserId)
	if ok and type(groups)=="table" then
		for _,group in groups do
			if type(group)=="table" and group.Id==groupId then return true end
		end
		return false
	end
	local cachedOk,member=pcall(player.IsInGroup,player,groupId)
	if cachedOk then return member==true end
	return nil
end

-- Nonyielding; call after InGroup and after rechecking the session.
function FreeGift.Claim(session,inGroup:boolean?)
	local gift=Config.FreeGift
	local definition=Catalog[gift.Species]
	if gift.Enabled~=true or type(definition)~="table" then return false,"The free chicken isn't ready yet." end
	if session.freeGiftClaimed then return false,"You already claimed your free chicken!" end
	-- October 23 (Stevin): 5 minutes of total playtime first (PlayerSession:PlaySeconds).
	local remaining=math.ceil((gift.MinPlaySeconds or 0)-session:PlaySeconds())
	if remaining>0 then
		return false,string.format("Keep playing! Your free chicken unlocks in %d:%02d.",remaining//60,remaining%60)
	end
	if inGroup==nil then return false,"Couldn't check the group right now. Try again in a moment." end
	if not inGroup then return false,"Join the group first, then press Verify!" end
	-- A full flock keeps the claim available for later.
	if session:Count()>=session:CollectionLimit() then return false,"You have the most chickens you can keep ("..Config.StorageLimit.."). Sell some first. Your free chicken is saved." end
	local pet=session:AddPet(gift.Species,1)
	pet.investment=0 -- A free reward never sells back for cash it never cost.
	session.freeGiftClaimed=true
	session:RefreshArmy();session:Touch()
	return true,definition.name.." joined your Flock!",pet.id
end

return FreeGift
