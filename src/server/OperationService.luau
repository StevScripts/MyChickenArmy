--!strict
-- Separate finite encounters, using clones of the authored arena and existing rigs.
-- This service never reserves/replaces public camps or writes territory ownership.
local Players=game:GetService("Players")
local ServerStorage=game:GetService("ServerStorage")
local HttpService=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.OperationCatalog)
local MapLayout=require(Shared.MapLayout)
local Battle=require(script.Parent.Battle)
local LiveActors=require(script.Parent.LiveBattleActors)
local Service={}
Service.__index=Service

function Service.new(battles,world,sessions)
	local self=setmetatable({battles=battles,world=world,sessions=sessions,arenas={}},Service)
	battles.operations=self
	return self
end

function Service:CreateArena(session)
	local authored=ServerStorage:FindFirstChild("MyChickenArmyMap") or workspace:FindFirstChild("MyChickenArmyMap")
	local section=authored and authored:FindFirstChild("06_ChickenKing")
	local source=section and section:FindFirstChild("KingArena")
	local anchor=source and source:FindFirstChild("KingSpawn")
	if not source or not anchor or not self.world.root then return nil end
	local arena=Instance.new("Model");arena.Name="OperationArena_"..session.userId
	arena.WorldPivot=CFrame.new(anchor.Position)
	for _,child in source:GetChildren() do child:Clone().Parent=arena end
	-- Authored art is cloned intact; public prompts, names and capture ownership are not.
	for _,item in arena:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("ProximityPrompt") or item:IsA("BillboardGui") or item:IsA("SurfaceGui") then item:Destroy()
		else
			for _,name in {"CommandTarget","OwnerUserId","ConquerorUserId","Conquered","Occupied"} do item:SetAttribute(name,nil) end
			if item:IsA("BasePart") then
				item.Anchored=true
				if not item:GetAttribute("WalkSurface") then item.CollisionGroup="DuckScenery" end
			end
		end
	end
	arena:ScaleTo(3)
	local center=Vector3.new(2000+session.plotIndex*240,anchor.Position.Y,0)
	arena:PivotTo(CFrame.new(center));arena.ModelStreamingMode=Enum.ModelStreamingMode.Persistent
	arena.Parent=self.world.root
	self.world.root:SetAttribute("WalkSurfaceRevision",(self.world.root:GetAttribute("WalkSurfaceRevision") or 0)+1)
	self.arenas[session.userId]=arena
	return arena,center
end

function Service:Start(session,id,expectedRevision,now)
	local definition=if type(id)=="string" then Catalog.Encounters[id] else nil
	if not definition or session.researchEffects.operations<definition.tier then return false,"Research this Operations set first." end
	if expectedRevision~=session.research.revision then return false,"Your Operations changed. Choose again." end
	if session.research.pendingOperationReward>0 then return false,"Spend some cash to receive your saved Operation reward before deploying again." end
	if session.outgoing or session.incoming or session:IsArmyLocked() or session.armyState~="Home" then return false,"Bring your army home before starting an Operation." end
	local roster=session:Lineup()
	if #roster==0 then return false,"Select an army first." end
	local player=Players:GetPlayerByUserId(session.userId)
	local character=player and player.Character
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health<=0 then return false,"Wait for your character to return." end
	local arena,center=self:CreateArena(session)
	if not arena then return false,"The Operation arena is not available in this place." end
	local battle=Battle.new(HttpService:GenerateGUID(false),session.userId,"operation:"..id,center+Vector3.new(0,0,18),center,now)
	battle.operationId,battle.name,battle.plotIndex=id,definition.name,session.plotIndex
	battle.phase,battle.phaseAt,battle.operationReadyAt="Fight",now+3,now+3
	battle.finiteRoster,battle.frame=true,CFrame.new(center)
	battle:AddArmy("A",roster,center);battle:AddArmy("B",Catalog.Roster(id),center)
	local actorsFolder=self.world.root:FindFirstChild("Battles")
	if not actorsFolder then actorsFolder=Instance.new("Folder");actorsFolder.Name="Battles";actorsFolder.Parent=self.world.root end
	battle.actors=LiveActors.new(actorsFolder,battle)
	session.outgoing,session.armyState,session.awayPets=battle.id,"Fighting",{}
	session.stationedAt,session.returnAt=nil,0
	for _,unit in battle.units do
		if unit.side=="A" then
			unit.x,unit.z=unit.entryX,unit.entryZ
			unit.startX,unit.startZ,unit.homeX,unit.homeZ=unit.x,unit.z,unit.x,unit.z
			session.awayPets[unit.petId]=true
			local actor=self.world:TakeActor(session.plotIndex,unit.petId)
			if actor then actor:Teleport(MapLayout.FootPosition(unit.x,unit.z));battle.actors:Adopt(unit,actor) end
		end
	end
	battle:ApplyResearch("A",session.researchEffects,os.time()<(session.rallyActiveUntil or 0))
	self.battles.battles[battle.id]=battle
	character:PivotTo(CFrame.lookAt(center+Vector3.new(0,5,38),center))
	session:Touch();self.world:UpdateSession(session)
	battle.actors:Sync(now);battle.actors:Publish(now)
	return true,definition.name.." · your selected army fights without reinforcements."
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
		session.outgoing,session.armyState,session.awayPets,session.returnAt,session.stationedAt=nil,"Home",{},0,nil
		session:RefreshArmy()
		if battle.actors then for _,unit in battle.units do if unit.side=="A" and unit.petId then
			local actor=battle.actors:TakePet(unit.petId,"A")
			if actor then actor:Teleport(self.world:ReturnPosition(session,unit.petId));self.world:RestoreActor(session,unit.petId,actor) end
		end end end
		session.lastResult=if won then definition.name.." cleared! "..(if reward>0 then "+$"..reward else "$"..session.research.pendingOperationReward.." saved until your wallet has room")..(if first then " · first clear" else "")
			else definition.name.." ended. Your army is home; no completion reward."
		session:Touch()
	end
	self.battles:Remove(battle)
	if session and not session.closing then self.world:UpdateSession(session) end
end

function Service:Detach(battle)
	local arena=self.arenas[battle.attacker]
	if arena then arena:Destroy();self.arenas[battle.attacker]=nil end
	if self.world.root then self.world.root:SetAttribute("WalkSurfaceRevision",(self.world.root:GetAttribute("WalkSurfaceRevision") or 0)+1) end
	local session=self.sessions[battle.attacker]
	local player=Players:GetPlayerByUserId(battle.attacker)
	if session and not session.closing and player and player.Character then player.Character:PivotTo(self.world:SpawnFrame(session.plotIndex)) end
end

function Service:Step(now)
	for _,session in self.sessions do
		if session.loaded and not session.closing and not session.saveLost and session.research.pendingOperationReward>0 then Service.ClaimReward(session) end
	end
	local aborted={}
	for _,battle in self.battles.battles do if battle.operationId and not battle.paid then
		local player=Players:GetPlayerByUserId(battle.attacker)
		local character=player and player.Character
		local root=character and character:FindFirstChild("HumanoidRootPart")
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health<=0 or root.Position.Y< -10 or (root.Position-battle.destination).Magnitude>110 then
			table.insert(aborted,battle)
		end
	end end
	for _,battle in aborted do self:Resolve(battle,"Abandoned",now) end
end

function Service:Snapshot(session)
	local battle=self.battles.battles[session.outgoing]
	return {tier=session.researchEffects.operations,wins=table.clone(session.research.operationWins),pendingReward=session.research.pendingOperationReward,
		activeId=battle and battle.operationId,encounterId=battle and battle.operationId and battle.id,
		center=battle and battle.operationId and {x=battle.destination.X,y=battle.destination.Y,z=battle.destination.Z},
		result=session.operationResult,bannerTier=Catalog.BannerTier(session.research.operationWins)}
end

function Service:Destroy()
	for _,arena in self.arenas do arena:Destroy() end
	self.arenas={}
end

return Service
