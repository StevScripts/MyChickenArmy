--!strict
-- October 20 Friend Boost (docs/team/GOLD_RUSH_FRIEND_BOOST.md): each Roblox friend
-- in this server adds Config.FriendBoost.PerFriend to a player's earned Coins, up
-- to Max. The server checks friendships (one IsFriendsWithAsync call per pair,
-- made when the newer player joins) and owns the value: session.friendBoost for
-- PlayerSession:EarnedAmount (never saved, never offline), mirrored to the Player
-- attributes FriendBoost and FriendBoostFriends for the HUD line.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Config=require(game:GetService("ReplicatedStorage").PetRoll.Shared.Config)
local FriendBoostService={}

-- friends[userId] = the set of that player's friends in this server.
local friends: {[number]: {[number]: boolean}} = {}

function FriendBoostService.Boost(count: number): number
	local rule=Config.FriendBoost
	return math.min(rule.Max,math.max(0,count)*rule.PerFriend)
end

function FriendBoostService.Count(userId: number): number
	local set=friends[userId]
	local count=0
	if set then for _ in set do count+=1 end end
	return count
end

-- Writes each player's boost; a session is touched only when its value changes.
-- Also runs every second, so a session created after its friendships resolved
-- (GameServer loads profiles separately) still receives its boost.
function FriendBoostService.Refresh(sessions)
	for _,player in Players:GetPlayers() do
		local count=FriendBoostService.Count(player.UserId)
		local boost=FriendBoostService.Boost(count)
		local session=sessions[player.UserId]
		if session and session.friendBoost~=boost then session.friendBoost=boost;session:Touch() end
		if player:GetAttribute("FriendBoost")~=boost then player:SetAttribute("FriendBoost",boost) end
		if player:GetAttribute("FriendBoostFriends")~=count then player:SetAttribute("FriendBoostFriends",count) end
	end
end

local function friendsWith(player: Player, otherId: number): boolean
	-- Studio local test players (negative ids) cannot be looked up; count them as
	-- friends so a two-player test shows the boost. Never applies to live servers.
	if RunService:IsStudio() and Config.FriendBoost.StudioTestPlayersAreFriends and player.UserId<0 and otherId<0 then
		return true
	end
	local ok,result=pcall(player.IsFriendsWithAsync,player,otherId)
	return ok and result==true
end

local function added(player: Player, sessions)
	local userId=player.UserId
	if friends[userId] then return end
	local mine={}
	friends[userId]=mine
	-- Players already registered; each of them checks later arrivals the same way.
	local others={}
	for otherId in friends do if otherId~=userId then table.insert(others,otherId) end end
	for _,otherId in others do
		task.spawn(function()
			local friend=friendsWith(player,otherId)
			-- Either player may have left while Roblox answered.
			local theirs=friends[otherId]
			if not friend or friends[userId]~=mine or not theirs then return end
			mine[otherId],theirs[userId]=true,true
			FriendBoostService.Refresh(sessions)
		end)
	end
end

local function removed(player: Player, sessions)
	local userId=player.UserId
	friends[userId]=nil
	for _,set in friends do set[userId]=nil end
	FriendBoostService.Refresh(sessions)
end

-- GameServer starts it once; the connections join its own list.
function FriendBoostService.Start(sessions, connections)
	if not Config.FriendBoost.Enabled then return end
	table.insert(connections,Players.PlayerAdded:Connect(function(player) added(player,sessions) end))
	table.insert(connections,Players.PlayerRemoving:Connect(function(player) removed(player,sessions) end))
	for _,player in Players:GetPlayers() do added(player,sessions) end
	local nextRefreshAt=0
	table.insert(connections,RunService.Heartbeat:Connect(function()
		local now=os.clock()
		if now<nextRefreshAt then return end
		nextRefreshAt=now+1
		FriendBoostService.Refresh(sessions)
	end))
end

return FriendBoostService
