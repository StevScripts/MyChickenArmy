--!strict
-- Separate finite encounters, using clones of the authored arena and existing rigs.
-- This service never reserves/replaces public camps or writes territory ownership.
local Players=game:GetService("Players")
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

-- October 14 Invasions: the Chicken King's loyalists land by airship beside the
-- player's base (InvasionLayout). The army marches there on foot with the normal
-- travel code, fights the finite roster, and walks home. No arena clone, no teleport.
local ARRIVAL_SECONDS=3.2 -- Airship inbound (3 s) before the loyalists drop.
local HOVER_SECONDS=2.2

function Service:Start(session,id,expectedRevision,now)
	local definition=if type(id)=="string" then Catalog.Encounters[id] else nil
	if not definition or Service.Tier(session)<definition.tier then return false,Service.LockedMessage(definition and definition.tier) end
	if expectedRevision~=session.research.revision then return false,"Your Invasions changed. Choose again." end
	if session.research.pendingOperationReward>0 then return false,"Spend some cash to receive your saved Invasion reward before deploying again." end
	if session.outgoing or session.incoming or session:IsArmyLocked() or session.armyState~="Home" then return false,"Bring your army home before repelling an Invasion." end
	local roster=session:Lineup()
	if #roster==0 then return false,"Select an army first." end
	local landing=InvasionLayout.Landing(session.plotIndex)
	if not landing or not self.world.root then return false,"No landing zone near this base." end
	local home=self.world:Position(session.plotIndex)
	local away=Vector3.new(landing.X-home.X,0,landing.Z-home.Z)
	away=if away.Magnitude>1e-3 then away.Unit else Vector3.new(0,0,1)
	-- -Z faces away from the base, so the army's approach point (+Z) is on the base side.
	local frame=CFrame.lookAt(landing,landing+away)
	local battle=Battle.new(HttpService:GenerateGUID(false),session.userId,"operation:"..id,home,landing,now)
	battle.operationId,battle.name,battle.plotIndex=id,definition.name,session.plotIndex
	battle.finiteRoster,battle.frame=true,frame
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
	task.delay(ARRIVAL_SECONDS,function()
		if self.battles.battles[battle.id]~=battle or battle.paid then return end
		battle:AddArmy("B",Catalog.Roster(id),landing)
		if battle.actors then battle.actors:Sync(os.clock());battle.actors:Publish(os.clock()) end
	end)
	session:Touch();self.world:UpdateSession(session)
	battle.actors:Sync(now);battle.actors:Publish(now)
	return true,"Loyalist airship spotted! "..definition.name.." · your selected army marches out without reinforcements."
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
			else definition.name.." ended. Your army is marching home; no completion reward."
		session:Touch()
	end
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
	battle.airship=nil
end

function Service:Step(now)
	for _,session in self.sessions do
		if session.loaded and not session.closing and not session.saveLost and session.research.pendingOperationReward>0 then Service.ClaimReward(session) end
	end
	-- Invasions are fought by the army alone; the commander may stay at the base.
	-- Only a commander who left the game abandons one.
	local aborted={}
	for _,battle in self.battles.battles do if battle.operationId and not battle.paid then
		if not Players:GetPlayerByUserId(battle.attacker) then table.insert(aborted,battle) end
	end end
	for _,battle in aborted do self:Resolve(battle,"Abandoned",now) end
end

function Service:Snapshot(session)
	local battle=self.battles.battles[session.outgoing]
	return {tier=Service.Tier(session),wins=table.clone(session.research.operationWins),pendingReward=session.research.pendingOperationReward,
		-- While the army walks home after a finished Invasion, nothing is active.
		activeId=battle and not battle.paid and battle.operationId or nil,encounterId=battle and battle.operationId and battle.id,
		center=battle and battle.operationId and {x=battle.destination.X,y=battle.destination.Y,z=battle.destination.Z},
		result=session.operationResult,bannerTier=Catalog.BannerTier(session.research.operationWins)}
end

function Service:Destroy()
	for _,battle in self.battles.battles do if battle.operationId then self:Detach(battle) end end
end

return Service
