--!strict
-- Separate finite encounters, using clones of the authored arena and existing rigs.
-- This service never reserves/replaces public camps or writes territory ownership.
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local HttpService=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.OperationCatalog)
local Battle=require(script.Parent.Battle)
local LiveActors=require(script.Parent.LiveBattleActors)
local Airship=require(script.Parent.InvasionAirship)
local InvasionLayout=require(Shared.InvasionLayout)
local March=require(Shared.ArmyMarch)
local Config=require(Shared.Config)
local Service={}
Service.__index=Service

function Service.new(battles,world,sessions)
	local self=setmetatable({battles=battles,world=world,sessions=sessions},Service)
	battles.operations=self
	return self
end

-- October 14 launch: a King clear opens Veteran Operations without research.
-- Research S15 still opens them on its own; S16/S17 remain the Elite/Royal gates.
function Service.Tier(session): number
	return math.max(session.researchEffects.operations or 0, if session.kingCleared then 1 else 0)
end
function Service.LockedMessage(tier): string
	return if tier==1 then "Defeat the Chicken King or research Coastal Watch first." else "Research this Invasion tier first."
end

-- October 14 Invasions: the Chicken King's loyalists land by airship on a random
-- open patch of the island (InvasionLayout.Pick), marked by a glowing ring. The army
-- marches there on foot with the normal travel code, fights the finite roster, and
-- walks home. No arena clone, no teleport, no cutscene. Other players see the
-- landing but cannot join it. After TIME_LIMIT seconds, on Leave or on a loss, the
-- loyalists fade away one by one and nothing is paid.
local ARRIVAL_SECONDS=3.2 -- Airship inbound (3 s) before the loyalists drop.
local HOVER_SECONDS=2.2
Service.TimeLimit=180
local FADE_SPREAD,FADE_SECONDS=8,.9
local rng=Random.new()

local function zoneRing(parent,landing,userId)
	local zone=Instance.new("Model")
	zone.Name="InvasionZone"..userId
	zone:SetAttribute("OwnerUserId",userId)
	local radius=InvasionLayout.ZoneRadius
	local function disc(name,size,color,transparency)
		local item=Instance.new("Part")
		item.Name,item.Shape,item.Material,item.Color=name,Enum.PartType.Cylinder,Enum.Material.Neon,color
		item.Size,item.Transparency=Vector3.new(.2,size,size),transparency
		item.Anchored,item.CanCollide,item.CanQuery,item.CanTouch,item.CastShadow=true,false,false,false,false
		item.CFrame=CFrame.new(landing+Vector3.new(0,.12,0))*CFrame.Angles(0,0,math.rad(90))
		item.Parent=zone
		return item
	end
	-- A bright rim around a faint fill reads as a ring from the ground and the air.
	local rim=disc("Rim",radius*2,Color3.fromRGB(190,90,255),.15)
	local fill=disc("Fill",radius*2-2.4,Color3.fromRGB(70,20,110),.35)
	fill.CFrame*=CFrame.new(.03,0,0)
	zone.PrimaryPart=rim
	-- The commander's guide arrow and "INVASION" marker point here.
	local marker=Instance.new("Attachment")
	marker.Name,marker.Parent="Marker",rim
	marker.WorldPosition=landing+Vector3.new(0,.3,0)
	zone.Parent=parent
	TweenService:Create(rim,TweenInfo.new(.8,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Transparency=.55}):Play()
	return zone
end

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

function Service:Start(session,id,expectedRevision,now)
	local definition=if type(id)=="string" then Catalog.Encounters[id] else nil
	if not definition or Service.Tier(session)<definition.tier then return false,Service.LockedMessage(definition and definition.tier) end
	if expectedRevision~=session.research.revision then return false,"Your Invasions changed. Choose again." end
	if session.research.pendingOperationReward>0 then return false,"Spend some cash to receive your saved Invasion reward before deploying again." end
	if session.outgoing or session.incoming or session:IsArmyLocked() or session.armyState~="Home" then return false,"Bring your army home before repelling an Invasion." end
	local roster=session:Lineup()
	if #roster==0 then return false,"Select an army first." end
	-- A random open spot, never close to another live Invasion; the plot's fixed
	-- spot is the fallback when the island is full.
	local taken={}
	for _,other in self.battles.battles do
		if other.operationId and not other.paid then table.insert(taken,other.destination) end
	end
	local landing=if self.world.root then InvasionLayout.Pick(rng,taken) or InvasionLayout.Landing(session.plotIndex) else nil
	if not landing or not self.world.root then return false,"No landing zone near this base." end
	local home=self.world:Position(session.plotIndex)
	local away=Vector3.new(landing.X-home.X,0,landing.Z-home.Z)
	away=if away.Magnitude>1e-3 then away.Unit else Vector3.new(0,0,1)
	-- -Z faces away from the base, so the army's approach point (+Z) is on the base side.
	local frame=CFrame.lookAt(landing,landing+away)
	local battle=Battle.new(HttpService:GenerateGUID(false),session.userId,"operation:"..id,home,landing,now)
	battle.operationId,battle.name,battle.plotIndex=id,definition.name,session.plotIndex
	battle.finiteRoster,battle.frame=true,frame
	battle.invasionExpiresAt=now+Service.TimeLimit
	-- The army waits while the airship arrives and the loyalists drop, then marches.
	battle.operationReadyAt=now+ARRIVAL_SECONDS+0.3
	battle:AddArmy("A",roster,home)
	battle.marchDestination=(frame*CFrame.new(0,0,Config.CampHalfSize-2)).Position
	for i,u in battle.units do
		local slot=roster[i].slot
		local returnAt=if self.world.ReturnPosition then self.world:ReturnPosition(session,u.petId,slot) else home
		local start=(if self.world.PetPosition then self.world:PetPosition(session.plotIndex,u.petId) else nil) or returnAt
		u.x,u.z,u.startX,u.startZ=start.X,start.Z,start.X,start.Z
		u.homeX,u.homeZ=returnAt.X,returnAt.Z
	end
	local actorsFolder=self.world.root:FindFirstChild("Battles")
	if not actorsFolder then actorsFolder=Instance.new("Folder");actorsFolder.Name="Battles";actorsFolder.Parent=self.world.root end
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
	self.battles.battles[battle.id]=battle
	-- The airship arrives from the sea beyond the landing zone and drops the loyalists.
	local seaward=Vector3.new(landing.X,0,landing.Z)
	seaward=if seaward.Magnitude>1e-3 then seaward.Unit else away
	battle.airship=Airship.Arrive(self.world.root,landing,seaward,HOVER_SECONDS)
	battle.zone=zoneRing(self.world.root,landing,session.userId)
	task.delay(ARRIVAL_SECONDS,function()
		if self.battles.battles[battle.id]~=battle or battle.paid then return end
		battle:AddArmy("B",Catalog.Roster(id),landing)
		if battle.actors then battle.actors:Sync(os.clock());battle.actors:Publish(os.clock()) end
	end)
	session:Touch();self.world:UpdateSession(session)
	battle.actors:Sync(now);battle.actors:Publish(now)
	return true,"Loyalist airship spotted! "..definition.name.." · follow the arrow; you have 3 minutes to repel them."
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
			session.research.pendingOperationReward=session:EarnedAmount(if first then definition.firstCash else definition.replayCash,"battle")
			reward=Service.ClaimReward(session)
			if first then session.research.operationWins[battle.operationId]=true;session.research.revision+=1 end
		end
		session.operationResult={id=battle.id,operationId=battle.operationId,won=won,first=first==true,reward=reward,
			heldReward=session.research.pendingOperationReward,
			bannerTier=Catalog.BannerTier(session.research.operationWins)}
			session.lastResult=if won then definition.name.." repelled! "..(if reward>0 then "+$"..reward else "$"..session.research.pendingOperationReward.." saved until your wallet has room")..(if first then " · first clear" else "")
				elseif outcome=="Expired" then "Time's up! The loyalists slipped away. Your army is marching home."
				else definition.name.." ended. Your army is marching home; no completion reward."
		session:Touch()
	end
	-- The loyalists (standing or fallen) fade away; the ring goes with them.
	fadeInvaders(battle,self.world.root or workspace)
	if battle.zone then battle.zone:Destroy();battle.zone=nil end
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
		result=session.operationResult,bannerTier=Catalog.BannerTier(session.research.operationWins)}
end

function Service:Destroy()
	for _,battle in self.battles.battles do if battle.operationId then self:Detach(battle) end end
end

return Service
