--!strict
-- October 27 (WS7, docs/team/SOCIAL_MOMENTS.md): server moments. Other players' firsts in
-- this server (a Rare+ find, Fort Roost / Ironbeak HQ, the King, Rebirth N, the Hill) as a
-- system chat line; Epic+ finds, the King and Rebirth 5+ also get a toast and a far
-- beacon over that plot. Pure rules shared by SocialService (server) and ServerMoments
-- (client); tests/SocialMomentsChecks.luau runs them headless.
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.PetCatalog)
local UIColors = require(script.Parent.UIColors)
local SocialMoments = {}

-- The same ranks as ShopCatalog's (Common 1 .. Secret 7).
SocialMoments.RarityRank = {Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5, Mythic=6, Secret=7}
SocialMoments.Kinds = {find=true, camp=true, king=true, rebirth=true, hill=true}
-- Only the two later home camps are announced: Cluck Camp is the tutorial's own win.
SocialMoments.CampIndices = {[2]=true, [3]=true}

local function social(): any
	return (Config :: any).Social or {}
end

-- Config.Social.Moments with defaults, so a Config without the block reads as off.
function SocialMoments.Settings(): any
	local root = social()
	local moments: any = root.Moments or {}
	return {
		enabled = root.Enabled == true and moments.Enabled == true,
		chatMin = moments.ChatMinRarity or "Rare",
		toastMin = moments.ToastMinRarity or "Epic",
		rebirthToastRank = moments.RebirthToastRank or 5,
		actorGap = moments.ActorGapSeconds or 45,
		serverPerMinute = moments.ServerPerMinute or 6,
		toastGap = moments.ToastGapSeconds or 20,
		beaconSeconds = moments.BeaconSeconds or 10,
	}
end

-- The chicken's rarity: the payload's own, else the catalog's.
function SocialMoments.Rarity(data: any): string?
	if type(data) ~= "table" then return nil end
	if type(data.rarity) == "string" and SocialMoments.RarityRank[data.rarity] then return data.rarity end
	local definition: any = type(data.species) == "string" and Catalog[data.species] or nil
	return if definition and type(definition.rarity) == "string" then definition.rarity else nil
end

-- How a moment is presented, or nil when it is not shown at all.
--   chat   a system chat line for everyone else in the server
--   toast  the top-centre banner (and the 20 s client gap)
--   beacon a far light beam over the actor's plot
--   visit  a Visit button inside the toast
function SocialMoments.Classify(kind: string, data: any): {chat: boolean, toast: boolean, beacon: boolean, visit: boolean}?
	local settings = SocialMoments.Settings()
	if not settings.enabled or not SocialMoments.Kinds[kind] then return nil end
	data = if type(data) == "table" then data else {}
	local ranks = SocialMoments.RarityRank
	if kind == "find" then
		local rarity = SocialMoments.Rarity(data)
		local rank = rarity and ranks[rarity] or 0
		if rank < (ranks[settings.chatMin] or 3) then return nil end
		local big = rank >= (ranks[settings.toastMin] or 4)
		return {chat=true, toast=big, beacon=big, visit=big}
	elseif kind == "camp" then
		if not SocialMoments.CampIndices[tonumber(data.campIndex) or 0] then return nil end
		return {chat=true, toast=false, beacon=false, visit=false}
	elseif kind == "king" then
		return {chat=true, toast=true, beacon=true, visit=true}
	elseif kind == "rebirth" then
		-- Rebirth 0 (the intro reset) is too common to announce.
		local rank = math.floor(tonumber(data.rank) or 0)
		if rank < 1 then return nil end
		local big = rank >= settings.rebirthToastRank
		return {chat=true, toast=big, beacon=big, visit=false}
	end
	return {chat=true, toast=false, beacon=false, visit=false} -- hill
end

local function camp(data: any): string
	if type(data.camp) == "string" and data.camp ~= "" then return data.camp end
	return if tonumber(data.campIndex) == 3 then "Ironbeak HQ" else "Fort Roost"
end

-- The exact player-facing copy (docs/team/SOCIAL_MOMENTS.md "Copy"). Name is the actor's
-- DisplayName (Roblox-moderated), never typed text; "1 in X" is the podium's own
-- whole-number figure (PetCatalog.OneInText).
function SocialMoments.Text(kind: string, data: any): string
	data = if type(data) == "table" then data else {}
	local name = if type(data.name) == "string" and data.name ~= "" then data.name else "A player"
	if kind == "find" then
		local definition: any = type(data.species) == "string" and Catalog[data.species] or nil
		local chicken = if definition and definition.name then definition.name else "a rare chicken"
		local odds = if definition then Catalog.OneInText(data.species) else nil
		return name .. " found " .. chicken .. "!" .. (if odds then " " .. odds else "")
	elseif kind == "camp" then
		return name .. " conquered " .. camp(data) .. "!"
	elseif kind == "king" then
		return name .. " defeated the Chicken King!"
	elseif kind == "rebirth" then
		return name .. " reached Rebirth " .. math.floor(tonumber(data.rank) or 0) .. "!"
	elseif kind == "hill" then
		return name .. " won the Hill!"
	end
	return name .. " did something great!"
end

-- The Visit reply, shown to the visitor after the teleport.
function SocialMoments.VisitText(name: string?): string
	if type(name) ~= "string" or name == "" then return "You're at their base." end
	return "You're at " .. name .. "'s base."
end

-- Beacon and chat colour: the rarity's for a find, gold for the King and Rebirths.
function SocialMoments.Color(kind: string, data: any): Color3
	if kind == "find" then
		local rarity = SocialMoments.Rarity(data)
		local color = rarity and (UIColors.Rarities :: any)[rarity]
		if color then return color end
	elseif kind == "camp" then
		return UIColors.Conquest
	elseif kind == "hill" then
		return UIColors.Rewards
	end
	return UIColors.Coins
end

-- The tutorial quiet rule: the viewer's tutorial is complete (or this profile predates it).
-- Same facts as RebirthService/DailyService: the guide completed, the short core done,
-- the guide skipped, or a pre-guide save (no starterArmy cohort mark).
function SocialMoments.TutorialDone(tutorial: any): boolean
	if type(tutorial) ~= "table" then return false end
	return tutorial.starterArmy ~= true or tutorial.guideCompleted == true or tutorial.coreDone == true
		or tutorial.guideSkipped == true or tutorial.wonCamp == true
end

-- Server rate limits: one moment per actor every ActorGapSeconds, at most ServerPerMinute
-- across the server in any rolling minute. Allow records the moment when it passes.
local Limiter = {}
Limiter.__index = Limiter
SocialMoments.Limiter = Limiter

function Limiter.new()
	return setmetatable({lastByActor = {} :: {[number]: number}, recent = {} :: {number}}, Limiter)
end

function Limiter:Allow(actorId: number, now: number): boolean
	local settings = SocialMoments.Settings()
	local last = self.lastByActor[actorId]
	if last and now - last < settings.actorGap then return false end
	local recent = self.recent
	while recent[1] and now - recent[1] >= 60 do table.remove(recent, 1) end
	if #recent >= settings.serverPerMinute then return false end
	table.insert(recent, now)
	self.lastByActor[actorId] = now
	return true
end

function Limiter:Forget(actorId: number)
	self.lastByActor[actorId] = nil
end

-- Client gap: at most one toast or beacon every ToastGapSeconds (chat lines always show).
function SocialMoments.ToastOpen(lastAt: number?, now: number): boolean
	return lastAt == nil or now - lastAt >= SocialMoments.Settings().toastGap
end

-- The one invite prompt per session (docs/team/SOCIAL_MOMENTS.md "Invite"). facts:
-- {invited, tutorialDone, sessionSeconds, friendBoost}.
SocialMoments.InviteTriggers = {Rebirth0=true, EpicFind=true, FortRoost=true}
function SocialMoments.InviteDue(trigger: string, facts: any): boolean
	local invite: any = social().Invite or {}
	if social().Enabled ~= true or invite.Enabled ~= true then return false end
	if not SocialMoments.InviteTriggers[trigger] or type(facts) ~= "table" then return false end
	if facts.invited == true or facts.tutorialDone ~= true then return false end
	if (tonumber(facts.friendBoost) or 0) > 0 then return false end
	return (tonumber(facts.sessionSeconds) or 0) >= (invite.MinSessionSeconds or 240)
end

return SocialMoments
