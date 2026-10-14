--!strict
-- In-game admin commands for owners and chosen admins (AdminConfig). Works in
-- live servers and Studio. Two inputs share one parser:
--   * chat: "/admin cash me 1m" or the short "/a cash me 1m" (hidden from other players)
--   * the Admin panel (Settings > Admin, or F2), sent as the "Admin" request
-- Every command is checked here against the sender's rank; clients only send text.
-- Changes go through the normal saved session, so they persist like real
-- progress and never invalidate a save.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TextService=game:GetService("TextService")
local TextChatService=game:GetService("TextChatService")
local DataStoreService=game:GetService("DataStoreService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Catalog=require(Shared.PetCatalog)
local Rules=require(Shared.Rules)
local Progression=require(Shared.Progression)
local ResearchCatalog=require(Shared.ResearchCatalog)
local ResearchRules=require(Shared.ResearchRules)
local Currency=require(Shared.CurrencyLimits)
local Commands=require(Shared.AdminCommands)
local AdminConfig=require(script.Parent.AdminConfig)

local Admin={}
Admin.__index=Admin

local LOG_LIMIT=40
local REFRESH_SECONDS=60
local STORE_KEY="admins"

function Admin.new(server)
	local self=setmetatable({server=server,ranks={},saved={},log={},lastCommand={},alive=true,connections={}},Admin)
	-- Studio and save-disabled builds keep the saved admin list in memory only.
	if not RunService:IsStudio() and Config.SaveEnabled then
		local ok,store=pcall(function() return DataStoreService:GetDataStore(Config.SaveName.."_Admins_v1") end)
		if ok then self.store=store end
	end
	return self
end

-- Ranks -------------------------------------------------------------------

local function listed(list,userId) return table.find(list,userId)~=nil end

function Admin:ComputeRank(player): string?
	local userId=player.UserId
	if listed(AdminConfig.Owners,userId) then return "Owner" end
	if listed(AdminConfig.Admins,userId) or self.saved[userId] then return "Admin" end
	if AdminConfig.GroupId and AdminConfig.GroupAdminRank then
		local ok,rank=pcall(function() return player:GetRankInGroup(AdminConfig.GroupId) end)
		if ok and rank>=AdminConfig.GroupAdminRank then return "Admin" end
	end
	return nil
end

function Admin:Rank(player): string?
	local rank=self.ranks[player.UserId]
	if rank==nil then rank=self:ComputeRank(player) or false;self.ranks[player.UserId]=rank end
	return if rank then rank else nil
end

local function rankOfUser(self,userId): string?
	if listed(AdminConfig.Owners,userId) then return "Owner" end
	if listed(AdminConfig.Admins,userId) or self.saved[userId] then return "Admin" end
	local player=Players:GetPlayerByUserId(userId)
	return if player then self:Rank(player) else nil
end

local POWER={Owner=2,Admin=1}
-- Admins may act on regular players only; owners on anyone but other owners.
local function canModerate(self,actor,targetId): boolean
	if targetId==actor.UserId then return false end
	return (POWER[self:Rank(actor) or ""] or 0)>(POWER[rankOfUser(self,targetId) or ""] or 0)
end

function Admin:LoadSaved()
	if not self.store then return end
	local ok,data=pcall(function() return self.store:GetAsync(STORE_KEY) end)
	if not ok or type(data)~="table" then return end
	local saved={}
	for _,id in data do if type(id)=="number" and id>0 and id%1==0 then saved[id]=true end end
	self.saved=saved
	for _,player in Players:GetPlayers() do self.ranks[player.UserId]=nil end
end

function Admin:SaveChange(userId,add): (boolean,string?)
	if not self.store then
		self.saved[userId]=if add then true else nil
		return true,nil
	end
	local result
	local ok,err=pcall(function()
		self.store:UpdateAsync(STORE_KEY,function(old)
			local ids={}
			for _,id in (if type(old)=="table" then old else {}) do
				if type(id)=="number" and id~=userId then table.insert(ids,id) end
			end
			if add then table.insert(ids,userId) end
			result=ids
			return ids
		end)
	end)
	if not ok then return false,tostring(err) end
	self.saved={}
	for _,id in result or {} do self.saved[id]=true end
	return true,nil
end

-- Parsing -----------------------------------------------------------------

local function words(text)
	local list={}
	for word in string.gmatch(text,"%S+") do table.insert(list,word) end
	return list
end

local function rest(list,from)
	return table.concat(list," ",from)
end

-- 250k, 1.5m, 2b, 3t, -500
local function amount(text): number?
	if type(text)~="string" then return nil end
	local number,suffix=string.match(string.lower(text),"^(%-?[%d%.]+)([kmbt]?)$")
	local value=tonumber(number)
	if not value then return nil end
	local scale=({k=1e3,m=1e6,b=1e9,t=1e12})[suffix] or 1
	value=value*scale
	if value~=value or math.abs(value)==math.huge then return nil end
	return math.floor(value+0.5)
end

local function squash(text) return (string.gsub(string.lower(text),"[%s%-_']","")) end

local function findSpecies(text): string?
	if type(text)~="string" then return nil end
	local wanted=squash(text)
	local prefix
	for _,id in Catalog.Order do
		local entry=Catalog[id]
		if squash(id)==wanted or squash(entry.name)==wanted then return id end
		if not prefix and (string.sub(squash(entry.name),1,#wanted)==wanted or string.sub(squash(id),1,#wanted)==wanted) then prefix=id end
	end
	return prefix
end

local function findResearch(text): string?
	local wanted=squash(text)
	for _,id in ResearchCatalog.Order do
		local node=ResearchCatalog.Nodes[id]
		if squash(id)==wanted or squash(node.name)==wanted then return id end
	end
	return nil
end

-- me / all / others / user ID / start of a username or display name.
function Admin:Targets(actor,token): ({Player}?,string?)
	if type(token)~="string" or token=="" then return nil,"Choose a player: me, all, others or a name." end
	local lower=string.lower(token)
	if lower=="me" then return {actor},nil end
	if lower=="all" or lower=="others" then
		local list={}
		for _,player in Players:GetPlayers() do if lower=="all" or player~=actor then table.insert(list,player) end end
		if #list==0 then return nil,"Nobody else is in this server." end
		return list,nil
	end
	local id=tonumber(token)
	if id then
		local player=Players:GetPlayerByUserId(id)
		return if player then {player} else nil,if player then nil else "No player with ID "..token.." is in this server."
	end
	local exact,matches={},{}
	for _,player in Players:GetPlayers() do
		local name,display=string.lower(player.Name),string.lower(player.DisplayName)
		if name==lower or display==lower then table.insert(exact,player)
		elseif string.sub(name,1,#lower)==lower or string.sub(display,1,#lower)==lower then table.insert(matches,player) end
	end
	local found=if #exact>0 then exact else matches
	if #found==0 then return nil,"No player matches \""..token.."\"." end
	if #found>1 then
		local names={}
		for _,player in found do table.insert(names,player.Name) end
		return nil,"\""..token.."\" matches "..table.concat(names,", ")..". Type more of the name."
	end
	return found,nil
end

-- A user ID or username, for players who may be offline.
local function userIdFrom(token): (number?,string?)
	if type(token)~="string" or token=="" then return nil,"Give a username or user ID." end
	local id=tonumber(token)
	if id and id>0 and id%1==0 then return id,nil end
	local online=Players:FindFirstChild(token)
	if online and online:IsA("Player") then return online.UserId,nil end
	local ok,result=pcall(function() return Players:GetUserIdFromNameAsync(token) end)
	if ok and type(result)=="number" then return result,nil end
	return nil,"No Roblox user named \""..token.."\"."
end

local function duration(text): number?
	if type(text)~="string" then return nil end
	text=string.lower(text)
	if text=="perm" or text=="permanent" or text=="forever" then return -1 end
	local value,unit=string.match(text,"^(%d+)([mhdw]?)$")
	local number=tonumber(value)
	if not number or number<=0 then return nil end
	return number*(({m=60,h=3600,d=86400,w=604800})[unit] or 3600)
end

local function plural(count,word) return count.." "..word..(if count==1 then "" else "s") end

-- Session helpers ---------------------------------------------------------

function Admin:Session(player)
	local session=self.server.sessions[player.UserId]
	if not session or not session.loaded or session.closing or session.saveLost then return nil end
	return session
end

-- Applies fn to each target's loaded session; returns how many changed.
function Admin:EachSession(players,fn): (number,string?)
	local changed,lastError=0,nil
	for _,player in players do
		local session=self:Session(player)
		if not session then lastError=player.Name.."'s save is not loaded yet."
		else
			local ok,why=fn(session,player)
			if ok==false then lastError=why or lastError
			else
				changed+=1
				session:Touch()
				if self.server.world.root then self.server.world:UpdateSession(session) end
			end
		end
	end
	return changed,lastError
end

-- Chickens, research, camps and army size can move the Strongest Army board.
local function assisted(session) session.adminAssisted=true end

local function root(player)
	local character=player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function teleport(player,frame)
	local character=player.Character
	if not character then return false end
	character:PivotTo(frame)
	local part=root(player)
	if part then part.AssemblyLinearVelocity,part.AssemblyAngularVelocity=Vector3.zero,Vector3.zero end
	return true
end

-- Commands ----------------------------------------------------------------

local handlers={}

handlers.help=function(self,actor,args)
	local rank=self:Rank(actor)
	if args[1] then
		local command=Commands.Resolve(args[1])
		if not command or not Commands.Allowed(rank,command) then return false,"No command called \""..args[1].."\"." end
		return true,command.usage.."\n"..command.help
	end
	local lines={"Type /a <command> in chat, or use the Admin panel. Targets: me, all, others or a name."}
	for _,command in Commands.List do
		if Commands.Allowed(rank,command) then table.insert(lines,command.usage) end
	end
	return true,table.concat(lines,"\n")
end

handlers.players=function(self)
	local lines={}
	for _,player in Players:GetPlayers() do
		local rank=self:Rank(player)
		table.insert(lines,player.DisplayName.." (@"..player.Name..") "..player.UserId..(if rank then " · "..rank else ""))
	end
	return true,table.concat(lines,"\n")
end

handlers.logs=function(self)
	if #self.log==0 then return true,"No admin actions yet in this server." end
	local lines={}
	for index=#self.log,math.max(1,#self.log-14),-1 do
		local entry=self.log[index]
		table.insert(lines,os.date("!%H:%M",entry.at).." UTC "..entry.by..": "..entry.text)
	end
	return true,table.concat(lines,"\n")
end

handlers.cash=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	local value=amount(args[2])
	if not value or value==0 then return false,"Give an amount, like 50k or 1.5m." end
	if math.abs(value)>AdminConfig.MaxCashPerCommand then return false,"That is more than one command may change." end
	local changed,last=self:EachSession(players,function(session)
		if value>0 then
			local room=Currency.MaxCoins-session.coins
			if room<=0 then return false,"That wallet is full." end
			session.coins+=math.min(value,room)
		else session.coins=math.max(0,session.coins+value) end
		return true
	end)
	if changed==0 then return false,last end
	return true,(if value>0 then "Gave $"..value else "Took $"..(-value)).." to "..plural(changed,"player").."."
end

handlers.setcash=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	local value=amount(args[2])
	if not value or value<0 then return false,"Give a cash amount of 0 or more." end
	value=math.min(value,Currency.MaxCoins)
	local changed,last=self:EachSession(players,function(session) session.coins=value;return true end)
	if changed==0 then return false,last end
	return true,"Set cash to $"..value.." for "..plural(changed,"player").."."
end

handlers.chicken=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	local species=findSpecies(args[2])
	if not species then return false,"Unknown chicken. Try a name from the Chicken Index." end
	local level=if args[3] then tonumber(args[3]) else 1
	if not level or level<1 or level>Config.MaxPetLevel or level%1~=0 then return false,"Level must be 1 to "..Config.MaxPetLevel.."." end
	local count=if args[4] then tonumber(args[4]) else 1
	if not count or count<1 or count>25 or count%1~=0 then return false,"Count must be 1 to 25." end
	local given=0
	local changed,last=self:EachSession(players,function(session)
		local added=0
		for _=1,count do
			if session:Count()>=session:CollectionLimit() then break end
			local pet=session:AddPet(species,1)
			pet.level=level;pet.investment=Rules.Investment(species,level)
			added+=1
		end
		if added==0 then return false,"Their flock is full." end
		given+=added;assisted(session);session:RefreshArmy()
		return true
	end)
	if changed==0 then return false,last end
	return true,"Gave "..plural(given,Catalog[species].name).." (level "..level..")."..(if given<count*#players then " Some flocks were full." else "")
end

handlers.research=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	if type(args[2])~="string" then return false,"Say all or a research node." end
	local ids
	if string.lower(args[2])=="all" then ids=ResearchCatalog.Order
	else
		local id=findResearch(rest(args,2))
		if not id then return false,"No research called \""..rest(args,2).."\"." end
		ids={id}
	end
	local changed,last=self:EachSession(players,function(session)
		local research=session.research
		local wanted={};for _,id in ids do wanted[id]=true;research.completed[id]=true end
		for index=#research.jobs,1,-1 do if wanted[research.jobs[index].nodeId] then table.remove(research.jobs,index) end end
		research.revision+=1
		session.researchEffects=ResearchRules.Effects(research)
		if research.completed.FuseMachine then session.fusionUnlocked=true end
		assisted(session)
		return true
	end)
	if changed==0 then return false,last end
	return true,"Finished "..(if #ids>1 then "all research" else ResearchCatalog.Nodes[ids[1]].name).." for "..plural(changed,"player").."."
end

handlers.army=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	local size=tonumber(args[2])
	if not size or not table.find(Config.SlotLevels,size) then
		return false,"Army size must be one of "..table.concat(Config.SlotLevels,", ").."."
	end
	local changed,last=self:EachSession(players,function(session)
		if session:IsArmyLocked() then return false,"Bring the army home first." end
		session.capacity=size
		session.legacyCapacityGrant=math.min(session.legacyCapacityGrant or 0,size)
		for slot in session.slots do if slot>size then session.slots[slot]=nil end end
		assisted(session);session:RefreshArmy()
		return true
	end)
	if changed==0 then return false,last end
	return true,"Army size set to "..size.." for "..plural(changed,"player").."."
end

handlers.roll=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	local species=nil
	if args[2] then
		species=findSpecies(args[2])
		if not species then return false,"Unknown chicken." end
	end
	local changed,last=self:EachSession(players,function(session)
		session.rollReadyAt=0
		if species then session.debugNext=species;assisted(session) end
		return true
	end)
	if changed==0 then return false,last end
	return true,"Next roll ready"..(if species then " with "..Catalog[species].name else "").." for "..plural(changed,"player").."."
end

handlers.camps=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	local changed,last=self:EachSession(players,function(session)
		for index=1,#Progression.Camps(1) do session.firstWins[index]=true end
		session.campUnlocked=#Progression.Camps(1)
		session.tutorial.wonCamp=true
		session:UnlockProgress();assisted(session)
		return true
	end)
	if changed==0 then return false,last end
	return true,"All camps beaten for "..plural(changed,"player").."."
end

handlers.king=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	local changed,last=self:EachSession(players,function(session)
		for index=1,#Progression.Camps(1) do session.firstWins[index]=true end
		session.campUnlocked=#Progression.Camps(1)
		session.tutorial.wonCamp=true
		session.kingCleared=true
		session:UnlockProgress();assisted(session)
		return true
	end)
	if changed==0 then return false,last end
	return true,"Camps and the Chicken King beaten for "..plural(changed,"player").."."
end

handlers.clearflags=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	local battles=self.server.battles
	local cleared=0
	for _,player in players do
		local keys={}
		for key,owner in battles.campOwners do if owner.userId==player.UserId then table.insert(keys,key) end end
		for _,key in keys do battles:SetTerritoryOwner(key,nil);cleared+=1 end
	end
	return true,"Removed "..plural(cleared,"flag").."."
end

handlers.hill=function(self,_,args)
	local hill=self.server.hill
	local choice=args[1] and string.lower(args[1])
	local now=os.clock()
	if choice=="open" or choice=="start" then
		if hill.phase=="Open" then return false,"A Hill round is already open." end
		if not hill:Open(now) then return false,"The King's arena is busy. Try again in a moment." end
		return true,"Hill round opened."
	elseif choice=="close" or choice=="end" or choice=="stop" then
		if hill.phase~="Open" then return false,"No Hill round is open." end
		hill:Close(now)
		return true,"Hill round closed."
	end
	return false,"Say hill open or hill close."
end

handlers.tp=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	local target=players[1]
	local destination=root(target)
	if target==actor or not destination then return false,"That player has no character to go to." end
	teleport(actor,destination.CFrame*CFrame.new(0,0,4))
	return true,"Teleported to "..target.Name.."."
end

handlers.bring=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	local here=root(actor)
	if not here then return false,"You have no character right now." end
	local moved=0
	for index,player in players do
		if player~=actor and teleport(player,here.CFrame*CFrame.new((index-1)%5*3-6,0,-5)) then moved+=1 end
	end
	return true,"Brought "..plural(moved,"player").."."
end

handlers.home=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	local moved=0
	for _,player in players do
		local session=self.server.sessions[player.UserId]
		if session and teleport(player,self.server.world:SpawnFrame(session.plotIndex)) then moved+=1 end
	end
	return true,"Sent "..plural(moved,"player").." home."
end

handlers.speed=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	local reset=args[2] and string.lower(args[2])=="reset"
	local value=tonumber(args[2])
	if not reset and (not value or value<0 or value>200) then return false,"Speed must be 0 to 200, or reset." end
	local changed=0
	for _,player in players do
		local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- WorldService:UpdatePlayerSpeed honors this until reset or respawn.
			humanoid:SetAttribute("AdminWalkSpeed",if reset then nil else value)
			if not reset then humanoid.WalkSpeed=value :: number end
			changed+=1
		end
	end
	return true,(if reset then "Reset speed" else "Speed "..value).." for "..plural(changed,"player").."."
end

handlers.announce=function(self,actor,args)
	local text=rest(args,1)
	if text=="" then return false,"Type a message to announce." end
	if #text>200 then return false,"Keep announcements under 200 characters." end
	-- Roblox requires filtering text shown to other players.
	local ok,filtered=pcall(function()
		return TextService:FilterStringAsync(text,actor.UserId,Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
	end)
	if not ok then return false,"The text filter is busy. Try again." end
	for _,session in self.server.sessions do
		if session.loaded and not session.closing then session.banner=actor.DisplayName..": "..filtered;session:Touch() end
	end
	return true,"Announced."
end

handlers.kick=function(self,actor,args)
	local players,why=self:Targets(actor,args[1]);if not players then return false,why end
	local reason=rest(args,2)
	local kicked,skipped=0,0
	for _,player in players do
		if canModerate(self,actor,player.UserId) then
			player:Kick(if reason~="" then reason else "Removed by an admin.")
			kicked+=1
		else skipped+=1 end
	end
	if kicked==0 then return false,"You can't kick yourself, owners or other admins." end
	return true,"Kicked "..plural(kicked,"player").."."..(if skipped>0 then " Skipped "..skipped.." you can't kick." else "")
end

handlers.ban=function(self,actor,args)
	local userId,why=userIdFrom(args[1]);if not userId then return false,why end
	if not canModerate(self,actor,userId) then return false,"You can't ban yourself or another owner." end
	local seconds=duration(args[2])
	if not seconds then return false,"Give a length: 30m, 6h, 3d, 2w or perm." end
	local reason=rest(args,3)
	local ok,err=pcall(function()
		Players:BanAsync({UserIds={userId},ApplyToUniverse=true,Duration=seconds,
			DisplayReason=if reason~="" then reason else "Banned by an admin.",
			PrivateReason="Banned by "..actor.Name.." ("..actor.UserId..")",ExcludeAltAccounts=false})
	end)
	if not ok then return false,"Ban failed: "..tostring(err) end
	return true,"Banned "..userId..(if seconds<0 then " permanently." else " for "..args[2].."." )
end

handlers.unban=function(self,_,args)
	local userId,why=userIdFrom(args[1]);if not userId then return false,why end
	local ok,err=pcall(function() Players:UnbanAsync({UserIds={userId},ApplyToUniverse=true}) end)
	if not ok then return false,"Unban failed: "..tostring(err) end
	return true,"Unbanned "..userId.."."
end

handlers.admin=function(self,actor,args)
	local choice=args[1] and string.lower(args[1])
	if choice~="add" and choice~="remove" then return false,"Say admin add <player> or admin remove <player>." end
	local userId,why=userIdFrom(args[2]);if not userId then return false,why end
	if listed(AdminConfig.Owners,userId) then return false,"Owners are set in AdminConfig." end
	if choice=="remove" and listed(AdminConfig.Admins,userId) then return false,"That admin is listed in AdminConfig; remove them there." end
	local ok,err=self:SaveChange(userId,choice=="add")
	if not ok then return false,"Could not save: "..tostring(err) end
	self.ranks[userId]=nil
	local player=Players:GetPlayerByUserId(userId)
	if player then self.server:PushState(player) end
	return true,(if choice=="add" then "Made "..userId.." an admin." else "Removed admin from "..userId..".")
		..(if self.store then " Other servers update within a minute." else " (Studio: not saved.)")
end

handlers.admins=function(self)
	local lines={"Owners: "..table.concat(AdminConfig.Owners,", ")}
	local config={};for _,id in AdminConfig.Admins do table.insert(config,tostring(id)) end
	local saved={};for id in self.saved do table.insert(saved,tostring(id)) end
	table.insert(lines,"Admins in AdminConfig: "..(if #config>0 then table.concat(config,", ") else "none"))
	table.insert(lines,"Admins added in game: "..(if #saved>0 then table.concat(saved,", ") else "none"))
	if AdminConfig.GroupId then table.insert(lines,"Group "..AdminConfig.GroupId.." rank "..tostring(AdminConfig.GroupAdminRank).."+ are admins") end
	return true,table.concat(lines,"\n")
end

-- Entry -------------------------------------------------------------------

function Admin:Record(actor,text,ok,message)
	table.insert(self.log,{at=os.time(),by=actor.Name,text=text,ok=ok})
	if #self.log>LOG_LIMIT then table.remove(self.log,1) end
	print("[Admin] "..actor.Name.." ("..actor.UserId.."): "..text.." -> "..(if ok then "ok" else "failed").." · "..tostring(message))
end

-- Returns ok, message. text is the command without the "/admin" prefix.
function Admin:Run(actor,text): (boolean,string)
	local rank=self:Rank(actor)
	if not rank then return false,"Admin commands are for admins only." end
	if type(text)~="string" or #text>300 then return false,"Command too long." end
	local now=os.clock()
	if now-(self.lastCommand[actor.UserId] or -math.huge)<0.25 then return false,"Slow down a little." end
	self.lastCommand[actor.UserId]=now
	text=(string.gsub(text,"^%s*;?","")) :: string
	local list=words(text)
	if #list==0 then return handlers.help(self,actor,{}) end
	local command=Commands.Resolve(table.remove(list,1) :: string)
	if not command or not handlers[command.name] then return false,"Unknown command. Type /a help for the list." end
	if not Commands.Allowed(rank,command) then return false,"Only owners can use "..command.name.."." end
	local ok,result,message=pcall(handlers[command.name],self,actor,list)
	if not ok then
		warn("[Admin] "..command.name.." error: "..tostring(result))
		message,result="That command hit an error. Check the server output.",false
	end
	message=message or "Done."
	if command.name~="help" and command.name~="players" and command.name~="logs" and command.name~="admins" then
		self:Record(actor,command.name.." "..table.concat(list," "),result==true,message)
	end
	return result==true,message :: string
end

function Admin:PlayerAdded(player)
	self.ranks[player.UserId]=nil
	task.spawn(function() self:Rank(player);if self:Rank(player) then self.server:PushState(player) end end)
end

function Admin:PlayerRemoving(player)
	self.ranks[player.UserId],self.lastCommand[player.UserId]=nil,nil
end

function Admin:Start()
	task.spawn(function()
		self:LoadSaved()
		while self.alive and task.wait(REFRESH_SECONDS) do self:LoadSaved() end
	end)
	-- One hidden chat command; the rest of the message is the admin command.
	local folder=TextChatService:FindFirstChild("TextChatCommands")
	if folder then
		local command=Instance.new("TextChatCommand")
		command.Name,command.PrimaryAlias,command.SecondaryAlias="PetRollAdmin","/admin","/a"
		command.AutocompleteVisible=false
		command.Parent=folder
		self.chatCommand=command
		table.insert(self.connections,command.Triggered:Connect(function(source,message)
			local player=Players:GetPlayerByUserId(source.UserId)
			if not player or not self:Rank(player) then return end
			local text=(string.gsub(message,"^%s*/%a+%s*",""))
			local ok,result=self:Run(player,text)
			self.server:Reply(player,ok,result)
		end))
	end
end

function Admin:Destroy()
	self.alive=false
	for _,connection in self.connections do connection:Disconnect() end
	if self.chatCommand then self.chatCommand:Destroy() end
end

return Admin
