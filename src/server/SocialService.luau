--!strict
-- October 27 (WS7, docs/team/SOCIAL_MOMENTS.md): other players' moments in this server,
-- the Visit teleport and the one invite prompt per session. The rules (who sees what,
-- the copy, the rate limits) live in Shared.SocialMoments; this service fires the
-- ServerMoment remote to every other loaded player and owns the server checks. Nothing
-- here changes Coins, chickens or saves: invitePrompt and the announced marks are
-- transient session fields, never saved. Every entry point is guarded, so a social
-- failure never breaks the action that caused it.
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Progression=require(Shared.Progression)
local SocialMoments=require(Shared.SocialMoments)
local PlaytimeService=require(script.Parent.PlaytimeService)
local SocialService={}
SocialService.__index=SocialService
-- Shared with ArmyCommandService:GoBase (session.lastGoBase, same wait and message).
local BASE_TELEPORT_SECONDS=2
local warned=false

local function ready(session: any): boolean
	return type(session)=="table" and session.loaded==true and not session.closing and not session.saveLost
end

local function guard(call: () -> ...any): any
	local ok,result=pcall(call)
	if ok then return result end
	if not warned then warned=true;warn("[SocialService] "..tostring(result)) end
	return nil
end

local function social(): any
	return (Config :: any).Social or {}
end

-- server: GameServer (sessions, remotes, world, armyCommands, analytics).
function SocialService.new(server)
	return setmetatable({server=server,limiter=SocialMoments.Limiter.new(),
		playerFor=function(userId: number): Player? return Players:GetPlayerByUserId(userId) end},SocialService)
end

function SocialService:Event(session,name: string,detail: string?)
	local analytics=self.server.analytics
	if analytics then pcall(analytics.ServerEvent,analytics,session,name,detail) end
end

-- Fires one moment to everyone else in the server. data: species / campIndex+camp / rank,
-- plus exclude = {[userId]=true} for players who already saw it another way (Hill
-- participants get the round result). A once-per-visit `key` skips a repeat.
function SocialService:Moment(session,kind: string,data: any?,now: number?): boolean
	return guard(function()
		if not ready(session) then return false end
		local input: any=data or {}
		if type(input.key)=="string" then
			session.socialAnnounced=session.socialAnnounced or {}
			if session.socialAnnounced[input.key] then return false end
		end
		local payload={kind=kind,userId=session.userId,name=session.name,plotIndex=session.plotIndex,
			species=input.species,rarity=SocialMoments.Rarity(input),campIndex=input.campIndex,camp=input.camp,
			rank=input.rank}
		if not SocialMoments.Classify(kind,payload) then return false end
		local remotes=self.server.remotes
		local remote=remotes and remotes:FindFirstChild("ServerMoment")
		if not remote then return false end
		local exclude: any=if type(input.exclude)=="table" then input.exclude else {}
		local recipients={}
		for userId,other in self.server.sessions do
			if other~=session and ready(other) and not exclude[userId] then
				local player=self.playerFor(userId)
				if player then table.insert(recipients,player) end
			end
		end
		-- An empty server spends nothing: the actor's next moment may still be seen.
		if #recipients==0 then return false end
		if not self.limiter:Allow(session.userId,now or os.clock()) then return false end
		if type(input.key)=="string" then session.socialAnnounced[input.key]=true end
		for _,player in recipients do remote:FireClient(player,payload) end
		self:Event(session,"social.moment",kind)
		return true
	end)==true
end

-- Before RollService:Buy: is the offer's chicken still missing from the Index? The
-- fallback for a Buy receipt without WS4's recruit.offer.firstFind.
function SocialService:Unseen(session,offerId: any): boolean
	return guard(function()
		if type(session)~="table" or type(session.discovered)~="table" then return false end
		for _,offer: any in session.offers or {} do
			if type(offer)=="table" and offer.id==offerId then return not session.discovered[offer.species] end
		end
		return false
	end)==true
end

-- After a successful Buy: a first find of a Rare+ is a moment; an Epic+ one may also
-- open the player's own invite prompt.
function SocialService:Bought(session,recruit: any,unseen: boolean?)
	guard(function()
		local offer=type(recruit)=="table" and recruit.offer or nil
		if type(offer)~="table" or type(offer.species)~="string" then return end
		local first=if offer.firstFind~=nil then offer.firstFind==true else unseen==true
		if not first then return end
		self:Moment(session,"find",{species=offer.species,key="find:"..offer.species})
		local rarity=SocialMoments.Rarity({species=offer.species})
		if (SocialMoments.RarityRank[rarity or ""] or 0)>=SocialMoments.RarityRank.Epic then
			self:HighMoment(session,"EpicFind")
		end
	end)
end

-- BattleService.onFirstWin (WS1): the own-lane first win on a home camp, or the King.
function SocialService:FirstWin(session,campIndex: any,isKing: any)
	guard(function()
		if isKing then self:Moment(session,"king",{key="king"});return end
		local index=tonumber(campIndex)
		if not index or not SocialMoments.CampIndices[index] then return end
		local camp=Progression.Camps(1)[index]
		self:Moment(session,"camp",{campIndex=index,camp=camp and camp.name,key="camp"..index})
		if index==2 then self:HighMoment(session,"FortRoost") end
	end)
end

-- Rebirth N succeeded (ranks 1–50; SocialMoments skips Rebirth 0).
function SocialService:Rebirthed(session)
	guard(function()
		local rank=tonumber(session.rebirths) or 0
		self:Moment(session,"rebirth",{rank=rank,key="rebirth"..rank})
	end)
end

-- The player's own high moment: once per visit, after the tutorial, at least
-- MinSessionSeconds into the visit, never with a friend here. The client opens Roblox's
-- invite prompt (FriendBoost:Prompted) and keeps it clear of purchase prompts.
function SocialService:HighMoment(session,trigger: string): boolean
	return guard(function()
		if not ready(session) then return false end
		local facts={invited=session.socialInvited==true,tutorialDone=SocialMoments.TutorialDone(session.tutorial),
			sessionSeconds=PlaytimeService.Played(session),friendBoost=session.friendBoost}
		if not SocialMoments.InviteDue(trigger,facts) then return false end
		session.socialInvited=true
		session.invitePrompt=trigger
		session:Touch()
		self:Event(session,"invite.prompt",trigger)
		return true
	end)==true
end

-- The snapshot carries a pending invite trigger once.
function SocialService:TakeInvite(session): string?
	local trigger=session.invitePrompt
	session.invitePrompt=nil
	return if type(trigger)=="string" then trigger else nil
end

-- Visit: the Visit button on a toast teleports to that plot's sign. Shares the GoBase
-- wait; the army stays where it is (a following army walks home first). Prompts on a
-- foreign plot stay off (WorldService:CanUseStation is unchanged) and home plots are
-- safe from attack, so a visitor can only look.
function SocialService:Visit(player: Player,session,plotIndex: any,now: number): (boolean,string)
	local ok,allowed,message=pcall(function(): (boolean,string)
		local rule: any=social().Visit or {}
		if social().Enabled~=true or rule.Enabled~=true then return false,"Visiting is off right now." end
		if type(plotIndex)~="number" or plotIndex%1~=0 or plotIndex<1 or plotIndex>#Config.PlotPositions then
			return false,"That base is empty."
		end
		if not SocialMoments.TutorialDone(session.tutorial) then return false,"Finish the tutorial first." end
		if plotIndex==session.plotIndex then return false,"That's your own base." end
		local host=nil
		for _,other in self.server.sessions do
			if other.plotIndex==plotIndex and other~=session and ready(other) then host=other;break end
		end
		if not host then return false,"That base is empty." end
		local character=player.Character
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		local root=character and character:FindFirstChild("HumanoidRootPart")
		if not character or not humanoid or humanoid.Health<=0 or not root or not root:IsA("BasePart") then
			return false,"Your character will be ready in a moment."
		end
		local wait=(session.lastGoBase or -math.huge)+BASE_TELEPORT_SECONDS-now
		if wait>0 then return false,"Base teleport ready in "..math.max(1,math.ceil(wait)).."s." end
		session.lastGoBase=now
		local commands=self.server.armyCommands
		if commands and commands.following and commands.following[session.userId] then commands:Release(session,true) end
		character:PivotTo((self.server.world:SpawnFrame(plotIndex) :: CFrame)*CFrame.new(0,0,6))
		root.AssemblyLinearVelocity,root.AssemblyAngularVelocity=Vector3.zero,Vector3.zero
		self:Event(session,"social.visit")
		return true,SocialMoments.VisitText(host.name)
	end)
	if not ok then
		if not warned then warned=true;warn("[SocialService] "..tostring(allowed)) end
		return false,"That base is empty."
	end
	return allowed==true,message
end

return SocialService
