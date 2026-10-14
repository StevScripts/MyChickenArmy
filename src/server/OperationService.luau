--!strict
-- Missions (October 14, 2026; formerly Invasions/Operations): after the Chicken King
-- falls, loyalist sites spawn on their own around the island for each commander.
-- The player sends the army to conquer one before it leaves. Finite encounters on
-- the real island; this service never reserves public camps or writes territory
-- ownership. Plan: docs/team/MISSIONS_PLAN.md.
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local HttpService=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.OperationCatalog)
local Battle=require(script.Parent.Battle)
local LiveActors=require(script.Parent.LiveBattleActors)
local Airship=require(script.Parent.InvasionAirship)
local Camp=require(script.Parent.InvasionCamp)
local MissionSite=require(script.Parent.MissionSite)
local FlockLayout=require(Shared.FlockLayout)
local InvasionLayout=require(Shared.InvasionLayout)
local March=require(Shared.ArmyMarch)
local Config=require(Shared.Config)
local DailyService=require(script.Parent.DailyService)
local Service={}
Service.__index=Service

function Service.new(battles,world,sessions)
	-- missions[userId] = {sites={[siteId]=site}, nextAt=os.clock() of the next spawn}
	local self=setmetatable({battles=battles,world=world,sessions=sessions,missions={},serial=0},Service)
	battles.operations=self
	return self
end

-- October 14 launch: a King clear opens Veteran Operations without research.
-- Research S15 still opens them on its own; S16/S17 remain the Elite/Royal gates.
function Service.Tier(session): number
	-- Rebirth resets kingCleared; a rebirthed player keeps Veteran Invasions.
	return math.max(session.researchEffects.operations or 0,
		if session.kingCleared or (session.rebirths or 0)>=1 then 1 else 0)
end
function Service.LockedMessage(tier): string
	return if tier==1 then "Defeat the Chicken King or research Coastal Watch first." else "Research this Mission tier first."
end

-- Each mission site is a loyalist camp on a random open patch of the island
-- (InvasionLayout.Pick, InvasionCamp). The airship drops its supply crates when the
-- site appears; the loyalists step out when the army is sent. The army marches
-- there on foot with the normal travel code, fights the finite roster and walks
-- home. After Service.TimeLimit seconds, on Leave or a loss, the loyalists fade
-- away one by one and nothing is paid.
local CRATE_FALL_SECONDS=2
-- The airship flies in, releases the crates, and the loyalists appear as they land.
local HOVER_SECONDS=CRATE_FALL_SECONDS+.8
Service.TimeLimit=180
local FADE_SPREAD,FADE_SECONDS=8,.9
local rng=Random.new()

-- Detach the loyalist rigs from the battle and fade them out one at a time.
local function fadeInvaders(battle,parent)
	local actors=battle.actors
	if not actors then return end
	local fading={}
	for _,unit in battle.units do
		if unit.side~="B" then continue end
		local actor=actors:TakeUnit(unit.id)
		if actor and not actor.destroyed then actor.model.Parent=parent;table.insert(fading,actor) end
	end
	local step=if #fading>0 then math.min(.6,FADE_SPREAD/#fading) else 0
	local info=TweenInfo.new(FADE_SECONDS,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	for i,actor in fading do
		task.delay((i-1)*step,function()
			if actor.destroyed or not actor.model.Parent then return end
			if actor.root then actor.root.Anchored=true end
			for _,item in actor.model:GetDescendants() do
				if item:IsA("BasePart") and item.Transparency<1 then TweenService:Create(item,info,{Transparency=1}):Play()
				elseif item:IsA("Decal") or item:IsA("Texture") then TweenService:Create(item,info,{Transparency=1}):Play()
				elseif item:IsA("BillboardGui") then item.Enabled=false end
			end
			task.delay(FADE_SECONDS,function() actor:Destroy() end)
		end)
	end
end

-- Mission pacing (owner-approved plan defaults, October 14).
Service.FirstSpawnSeconds=30 -- after Missions unlock or the player joins
Service.SpawnEverySeconds=240
Service.MaxWaiting=2
Service.WaitSeconds=360 -- a site leaves if nobody attacks it in time
Service.RareChance=.1 -- gold sites pay double
-- Cash reward: minutes of the player's egg income by tier, never below the
-- encounter's old replay reward.
Service.RewardMinutes={8,12,15}

function Service.Reward(session,id,rare)
	local definition=Catalog.Encounters[id]
	local minutes=Service.RewardMinutes[definition.tier] or 8
	local cash=math.max(definition.replayCash,math.floor(DailyService.Income(session)*minutes*60))
	return if rare then cash*2 else cash
end

-- The highest unlocked tier comes up most often (weight 3), lower tiers weight 1.
local function pickEncounter(session)
	local tier=math.clamp(Service.Tier(session),1,#Catalog.Tiers)
	local pool={}
	for _,id in Catalog.Order do
		local definition=Catalog.Encounters[id]
		if definition.tier<=tier then
			for _=1,(if definition.tier==tier then 3 else 1) do table.insert(pool,id) end
		end
	end
	return pool[rng:NextInteger(1,#pool)]
end

-- Every spot already used by a live site or Mission battle (all players).
function Service:Taken()
	local taken={}
	for _,entry in self.missions do for _,site in entry.sites do table.insert(taken,site.landing) end end
	for _,other in self.battles.battles do
		if other.operationId and not other.paid then table.insert(taken,other.destination) end
	end
	return taken
end

-- Spawn one waiting site: the camp, the airship drop and its open crates.
function Service:Spawn(session,now,forcedId,forcedTheme)
	local root=self.world.root
	if not root then return nil end
	local landing=InvasionLayout.Pick(rng,self:Taken())
	if not landing then return nil end
	local id=if forcedId and Catalog.Encounters[forcedId] then forcedId else pickEncounter(session)
	local definition=Catalog.Encounters[id]
	self.serial+=1
	local siteId="m"..self.serial
	local home=self.world:Position(session.plotIndex)
	local away=Vector3.new(landing.X-home.X,0,landing.Z-home.Z)
	away=if away.Magnitude>1e-3 then away.Unit else Vector3.new(0,0,1)
	-- -Z faces away from the owner's base, so the open front faces the arriving army.
	local frame=CFrame.lookAt(landing,landing+away)
	local folder=root:FindFirstChild("Missions")
	if not folder then folder=Instance.new("Folder");folder.Name="Missions";folder.Parent=root end
	-- Each site is a seeded build of one theme (MissionSite + MissionKits).
	local theme=if forcedTheme then forcedTheme else MissionSite.Themes[rng:NextInteger(1,#MissionSite.Themes)]
	local seed=rng:NextInteger(1,2^30)
	local model=MissionSite.Build(folder,theme,frame,session.userId,seed)
	model.Name="Mission_"..siteId
	local rare=rng:NextNumber()<Service.RareChance
	model:SetAttribute("MissionId",siteId)
	model:SetAttribute("CommandTarget","mission:"..siteId)
	model:SetAttribute("Rare",rare)
	-- The airship drops one crate behind each column of the loyalist formation;
	-- the open crates stay until the loyalists step out of them.
	local enemies=Catalog.Roster(id)
	local columns,rows=FlockLayout.Dimensions(#enemies)
	local spots={}
	for c=1,columns do
		local x=(c-1-(columns-1)/2)*FlockLayout.SpacingX
		local z=-3-(rows-1)*FlockLayout.SpacingZ/2-2.8-(c%2)*.8
		table.insert(spots,(frame*CFrame.new(x,.15,z)).Position)
	end
	-- The Loyalist Landing arrives by airship; built themes rise in place.
	if MissionSite.UsesAirship[theme] then
		local seaward=Vector3.new(landing.X,0,landing.Z)
		seaward=if seaward.Magnitude>1e-3 then seaward.Unit else away
		Airship.Arrive(root,landing,seaward,HOVER_SECONDS)
		task.delay(Airship.InboundSeconds,function()
			if not model.Parent then return end
			Airship.DropCrates(model,landing+Vector3.new(0,Airship.HoverHeight,0)+Airship.HatchOffset,spots,CRATE_FALL_SECONDS)
		end)
	end
	local site={id=siteId,encounterId=id,landing=landing,frame=frame,model=model,rare=rare,
		spawnedAt=now,expiresAt=now+Service.WaitSeconds}
	if self.analytics then self.analytics:LaunchCount(session,"mission.spawn."..definition.tier) end
	return site
end

-- Studio test tools: spawn a waiting site right away (ignores pacing, not the cap).
function Service:SpawnNow(session,now,forcedId,forcedTheme)
	local entry=self.missions[session.userId]
	if not entry then entry={sites={},nextAt=now+Service.SpawnEverySeconds};self.missions[session.userId]=entry end
	local site=self:Spawn(session,now,forcedId,forcedTheme)
	if not site then return false,"No free spot on the island." end
	entry.sites[site.id]=site;session:Touch()
	return true,"TEST: "..Catalog.Encounters[site.encounterId].name.." landed on the island."
end

-- Spawn, expire and clean up waiting sites for every player.
function Service:StepSites(now)
	for userId,entry in self.missions do
		local session=self.sessions[userId]
		if not session or session.closing then
			for _,site in entry.sites do if site.model then site.model:Destroy() end end
			self.missions[userId]=nil
		end
	end
	for userId,session in self.sessions do
		if not session.loaded or session.closing or session.saveLost or Service.Tier(session)<1 then continue end
		local entry=self.missions[userId]
		if not entry then
			entry={sites={},nextAt=now+Service.FirstSpawnSeconds}
			self.missions[userId]=entry
		end
		for siteId,site in entry.sites do
			if now>=site.expiresAt then
				entry.sites[siteId]=nil
				if site.model then Camp.FadeOut(site.model,0) end
				if self.analytics then self.analytics:LaunchCount(session,"mission.expired."..Catalog.Encounters[site.encounterId].tier) end
			end
		end
		local waiting=0
		for _ in entry.sites do waiting+=1 end
		if now>=entry.nextAt and waiting<Service.MaxWaiting then
			local site=self:Spawn(session,now)
			-- No free spot: try again shortly instead of waiting a full interval.
			entry.nextAt=now+(if site then Service.SpawnEverySeconds else 15)
			if site then entry.sites[site.id]=site;session:Touch() end
		end
	end
end

-- Send the army from home to a waiting site. The site's camp becomes the battle
-- zone; the loyalists step out of the crates and the 3-minute limit starts.
function Service:StartMission(session,siteId,now)
	local entry=self.missions[session.userId]
	local site=entry and type(siteId)=="string" and entry.sites[siteId]
	if not site or not site.model or not site.model.Parent then return false,"That mission has already left." end
	local id=site.encounterId
	local definition=Catalog.Encounters[id]
	if Service.Tier(session)<definition.tier then return false,Service.LockedMessage(definition.tier) end
	if session.research.pendingOperationReward>0 then return false,"Spend some cash to receive your saved mission reward first." end
	if session.outgoing or session.incoming or session:IsArmyLocked() or session.armyState~="Home" then return false,"Bring your army home before starting a mission." end
	local roster=session:Lineup()
	if #roster==0 then return false,"Select an army first." end
	local root=self.world.root
	if not root then return false,"Missions are not ready yet." end
	entry.sites[siteId]=nil
	local landing,frame=site.landing,site.frame
	local home=self.world:Position(session.plotIndex)
	local battle=Battle.new(HttpService:GenerateGUID(false),session.userId,"operation:"..id,home,landing,now)
	battle.operationId,battle.name,battle.plotIndex=id,definition.name,session.plotIndex
	battle.missionSite,battle.missionRare=siteId,site.rare
	battle.finiteRoster,battle.frame=true,frame
	battle.invasionExpiresAt=now+Service.TimeLimit
	battle.operationReadyAt=now+.5
	battle:AddArmy("A",roster,home)
	battle.marchDestination=(frame*CFrame.new(0,0,Config.CampHalfSize-2)).Position
	for i,u in battle.units do
		local slot=roster[i].slot
		local returnAt=if self.world.ReturnPosition then self.world:ReturnPosition(session,u.petId,slot) else home
		local start=(if self.world.PetPosition then self.world:PetPosition(session.plotIndex,u.petId) else nil) or returnAt
		u.x,u.z,u.startX,u.startZ=start.X,start.Z,start.X,start.Z
		u.homeX,u.homeZ=returnAt.X,returnAt.Z
	end
	local actorsFolder=root:FindFirstChild("Battles")
	if not actorsFolder then actorsFolder=Instance.new("Folder");actorsFolder.Name="Battles";actorsFolder.Parent=root end
	battle.actors=LiveActors.new(actorsFolder,battle)
	session.outgoing,session.armyState,session.awayPets=battle.id,"Traveling",{}
	session.stationedAt,session.returnAt=nil,0
	for _,unit in battle.units do
		session.awayPets[unit.petId]=true
		local actor=self.world.TakeActor and self.world:TakeActor(session.plotIndex,unit.petId)
		if actor then battle.actors:Adopt(unit,actor) end
		March.Approach(unit,battle.destination,now)
	end
	battle:ApplyResearch("A",session.researchEffects,os.time()<(session.rallyActiveUntil or 0))
	battle.zone=site.model
	battle:AddArmy("B",Catalog.Roster(id),landing)
	self.battles.battles[battle.id]=battle
	session:Touch();self.world:UpdateSession(session)
	battle.actors:Sync(now);battle.actors:Publish(now)
	if self.analytics then self.analytics:LaunchCount(session,"mission.start."..definition.tier) end
	return true,"Army sent to "..definition.name.."! You have 3 minutes to win."
end

function Service.ClaimReward(session)
	local amount=session.research.pendingOperationReward
	if amount==0 then return 0 end
	local credited=session:Credit(amount,"operation")
	if credited>0 then session.research.pendingOperationReward=0;session.research.revision+=1;session:Touch() end
	return credited
end

function Service:Resolve(battle,outcome,now)
	if battle.paid then return end
	battle.paid=true -- Exactly once, before reward or cleanup.
	local session=self.sessions[battle.attacker]
	local definition=Catalog.Encounters[battle.operationId]
	if session then
		local won=outcome=="A" and not session.closing and not session.saveLost
		local first=won and not session.research.operationWins[battle.operationId]
		local reward=0
		if won then
			-- Keep the exact earned amount if the wallet fills during this fight.
			-- A pending reward prevents another deployment, so these cannot overflow.
			-- Missions pay the income-scaled reward (doubled on gold sites); first
			-- clears still record banner progress in operationWins.
			local amount=if battle.missionSite then Service.Reward(session,battle.operationId,battle.missionRare)
				elseif first then definition.firstCash else definition.replayCash
			session.research.pendingOperationReward=session:EarnedAmount(amount,"battle")
			reward=Service.ClaimReward(session)
			if first then session.research.operationWins[battle.operationId]=true;session.research.revision+=1 end
		end
		session.operationResult={id=battle.id,operationId=battle.operationId,won=won,first=first==true,reward=reward,
			heldReward=session.research.pendingOperationReward,
			bannerTier=Catalog.BannerTier(session.research.operationWins)}
			if self.analytics then self.analytics:LaunchCount(session,"mission."..(if won then "won." elseif outcome=="Expired" then "timeout." else "lost.")..definition.tier) end
			session.lastResult=if won then definition.name.." conquered! "..(if reward>0 then "+$"..reward else "$"..session.research.pendingOperationReward.." saved until your wallet has room")..(if first then " · first clear" else "")
				elseif outcome=="Expired" then "Time's up! The loyalists held out. Your army is marching home."
				else definition.name.." ended. Your army is marching home; no completion reward."
		session:Touch()
	end
	-- The loyalists (standing or fallen) fade away, then their camp packs up.
	fadeInvaders(battle,self.world.root or workspace)
	if battle.zone then Camp.FadeOut(battle.zone,FADE_SPREAD*.6);battle.zone=nil end
	-- The army walks home through the normal Returning flow (BattleService restores
	-- the rigs and the session on arrival). A leaving player is simply removed.
	if session and not session.closing and session.outgoing==battle.id then
		session.armyState="Returning"
		-- Fallen chickens never respawn mid-Invasion; they get back up where they
		-- fell and walk home with the rest (the homecoming waits for every bird).
		for _,unit in battle.units do
			if unit.side=="A" and unit.petId and unit.hp<=0 then
				unit.hp,unit.respawnAt=unit.maxHp,nil
				if battle.actors then battle.actors:Respawn(unit,unit.x,unit.z) end
			end
		end
		battle:Finish(if outcome=="A" then "A" else "B",now)
		self.world:UpdateSession(session)
	else
		self.battles:Remove(battle)
	end
end

function Service:Detach(battle)
	-- Invasions use the real island; only the airship prop may still be in flight.
	if battle.airship and battle.airship.Parent then battle.airship:Destroy() end
	if battle.zone then battle.zone:Destroy() end
	battle.airship,battle.zone=nil,nil
end

function Service:Step(now)
	self:StepSites(now)
	for _,session in self.sessions do
		if session.loaded and not session.closing and not session.saveLost and session.research.pendingOperationReward>0 then Service.ClaimReward(session) end
	end
	-- Invasions are fought by the army alone; the commander may stay at the base.
	-- Only a commander who left the game abandons one.
	local aborted={}
	for _,battle in self.battles.battles do if battle.operationId and not battle.paid then
		if not Players:GetPlayerByUserId(battle.attacker) then table.insert(aborted,{battle,"Abandoned"})
		elseif battle.invasionExpiresAt and now>=battle.invasionExpiresAt then table.insert(aborted,{battle,"Expired"}) end
	end end
	for _,entry in aborted do self:Resolve(entry[1],entry[2],now) end
end

function Service:Snapshot(session)
	local battle=self.battles.battles[session.outgoing]
	return {tier=Service.Tier(session),wins=table.clone(session.research.operationWins),pendingReward=session.research.pendingOperationReward,
		-- While the army walks home after a finished Invasion, nothing is active.
		activeId=battle and not battle.paid and battle.operationId or nil,encounterId=battle and battle.operationId and battle.id,
			center=battle and battle.operationId and {x=battle.destination.X,y=battle.destination.Y,z=battle.destination.Z},
			expiresIn=battle and not battle.paid and battle.invasionExpiresAt and math.max(0,math.ceil(battle.invasionExpiresAt-os.clock())) or nil,
		result=session.operationResult,bannerTier=Catalog.BannerTier(session.research.operationWins),
		activeSite=battle and not battle.paid and battle.missionSite or nil,
		missions=self:MissionList(session)}
end

-- Waiting sites for the HUD, markers and the walk-up prompt (client presentation).
function Service:MissionList(session)
	local list={}
	local entry=self.missions[session.userId]
	if not entry then return list end
	local now=os.clock()
	for _,site in entry.sites do
		local definition=Catalog.Encounters[site.encounterId]
		table.insert(list,{id=site.id,name=definition.name,tier=definition.tier,boss=definition.boss~=nil,
			power=Catalog.Power(site.encounterId),count=#Catalog.Roster(site.encounterId),
			-- What a win would pay now, including 2x Cash (same as Resolve).
			reward=session:EarnedAmount(Service.Reward(session,site.encounterId,site.rare),"battle"),rare=site.rare,
			expiresIn=math.max(0,math.ceil(site.expiresAt-now)),x=site.landing.X,z=site.landing.Z})
	end
	table.sort(list,function(a,b) return a.expiresIn<b.expiresIn end)
	return list
end

function Service:Destroy()
	for _,battle in self.battles.battles do if battle.operationId then self:Detach(battle) end end
	for _,entry in self.missions do for _,site in entry.sites do if site.model then site.model:Destroy() end end end
	table.clear(self.missions)
end

return Service
