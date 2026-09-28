--!strict
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local FlockLayout=require(Shared.FlockLayout)
local MapLayout=require(Shared.MapLayout)
local March=require(Shared.ArmyMarch)
local Battle={}
Battle.__index=Battle

local function distance(a,b)
	local x,z=a.x-b.x,a.z-b.z
	return math.sqrt(x*x+z*z)
end

function Battle.new(id, attacker, target, origin: Vector3, destination: Vector3, now: number)
	return setmetatable({id=id,attacker=attacker,target=target,origin=origin,destination=destination,
		phase="Travel",startedAt=now,phaseAt=now,units={},serial=0,paid=false,outcome=nil,
		captureElapsed=0,capturers=0,captureStarted=false,defenderRespawns=0,kills={},coinDrops={},killSerial=0},Battle)
end

function Battle:AddArmy(side: string, roster, home: Vector3)
	for i,pet in roster do
		self.serial+=1
		local stats=pet.combatStats or Rules.Stats(pet.species,pet.stars,pet.level)
		local slot=pet.slot or i
		local hx,hz=FlockLayout.Home(slot)
		local homeX,homeZ=home.X+hx,home.Z+hz
		local ex,ez=FlockLayout.Entry(i,#roster,side)
		if self.isKing and side=="B" then
			if pet.boss then ex,ez=0,-12*(MapLayout.King.Radius/29)
			else ex,ez=FlockLayout.Offset(math.max(1,i-1),math.max(1,#roster-1));ez+=3 end
		end
		local at=(self.frame or CFrame.new(self.destination))*CFrame.new(ex,0,ez)
		local spawn=(self.frame or CFrame.new(self.destination))*CFrame.new(ex,0,-Config.DefenderSpawnDepth-math.max(0,-ez-3))
		local x,z=at.X,at.Z
		table.insert(self.units,{id=tostring(self.serial),petId=pet.id,slot=slot,side=side,species=pet.species,stars=pet.stars,level=pet.level or 1,
			giantSize=pet.giantSize,
			boss=pet.boss==true,noRespawn=pet.noRespawn==true,
			hp=stats.hp,maxHp=stats.hp,damage=stats.damage,interval=stats.interval,size=stats.size,splash=stats.splash,
			x=if side=="A" then homeX else x,z=if side=="A" then homeZ else z,
			homeX=homeX,homeZ=homeZ,startX=homeX,startZ=homeZ,entryX=x,entryZ=z,spawnX=spawn.X,spawnZ=spawn.Z,
			nextAttack=0,attackSerial=0,impactSerial=0,spawnSerial=0,firstAttack=true,
			attackStagger=((i-1)%4)*Config.AttackStaggerSeconds,faceX=0,faceZ=if side=="A" then 1 else -1})
	end
end

function Battle:AddDefenders(roster, home: Vector3, now: number)
	self:AddArmy("B",roster,home)
	if self.phase=="Capture" and #roster>0 then
		self.phase,self.phaseAt,self.capturers="Fight",now,0
	end
end

function Battle:BeginCapture(now: number)
	-- Resuming after defenders never erases the control already removed or gained.
	self.phase,self.phaseAt,self.capturers="Capture",now,0
	self.captureStarted=true
	self:CancelAttacks()
	local survivors={}
	for _,unit in self.units do if unit.side=="A" and unit.hp>0 and not unit.reinforcing and not unit.retiring then table.insert(survivors,unit) end end
	for index,unit in survivors do
		local x,z=FlockLayout.Offset(index,#survivors)
		local scale=math.min(1,Config.CampHalfSize/18)
		x,z=x*scale,z*scale
		local at=((self.frame or CFrame.new(self.destination))*CFrame.new(x,0,z)).Position
		unit.captureX,unit.captureZ=at.X,at.Z
	end
end

function Battle:StepDefenderSpawns(now: number)
	if self.incomeContest or (self.phase~="Fight" and self.phase~="Capture") then return end
	local spawned=false
	for _,unit in self.units do
		if unit.side~="B" or unit.petId or unit.noRespawn or unit.hp>0 or not unit.respawnAt then continue end
		if now+1e-6<unit.respawnAt then continue end
		unit.hp,unit.x,unit.z=unit.maxHp,unit.spawnX,unit.spawnZ
		unit.respawnAt=nil;unit.pendingAttack=nil;unit.targetId=nil
		unit.firstAttack=true;unit.nextAttack=now+Config.AttackWindupSeconds
		unit.spawnSerial+=1
		self.defenderRespawns+=1;spawned=true
		if self.actors then self.actors:Respawn(unit,unit.x,unit.z) end
	end
	-- A pending timer does not contest the flag; a living guard does.
	if spawned and self.phase=="Capture" then
		self.phase,self.phaseAt,self.capturers="Fight",now,0
	end
end

function Battle:NextDefenderRespawn(): number?
	if self.incomeContest or (self.phase~="Fight" and self.phase~="Capture") then return nil end
	local earliest=nil
	for _,unit in self.units do
		if unit.side=="B" and not unit.petId and not unit.noRespawn and unit.hp<=0 and unit.respawnAt then
			earliest=if earliest then math.min(earliest,unit.respawnAt) else unit.respawnAt
		end
	end
	return earliest
end

function Battle:CancelAttacks()
	for _,unit in self.units do unit.pendingAttack=nil;unit.targetId=nil end
end

function Battle:StepCapture(dt: number, now: number)
	if self:Alive("B")>0 then
		self.phase,self.phaseAt,self.capturers="Fight",now,0
		return nil
	end
	local capturers=0
	for _,unit in self.units do
		if unit.side~="A" or unit.hp<=0 or unit.reinforcing or unit.retiring then continue end
		local x,z=unit.captureX or self.destination.X,unit.captureZ or self.destination.Z
		if self.actors then self.actors:Move(unit,x,z,Config.MoveSpeed)
		else
			local dx,dz=x-unit.x,z-unit.z
			local length=math.sqrt(dx*dx+dz*dz)
			if length>0 then local step=math.min(length,Config.MoveSpeed*dt);unit.x+=dx/length*step;unit.z+=dz/length*step end
		end
		-- Count actual living soldiers inside the objective, not the player's avatar
		-- or a visual timer. Leaving the zone pauses capture.
		if (unit.x-self.destination.X)^2+(unit.z-self.destination.Z)^2<=Config.CaptureRadius^2 then capturers+=1 end
	end
	self.capturers=capturers
	if capturers>0 then
		self.captureElapsed=math.min(Config.CaptureSeconds,self.captureElapsed+dt)
		if self.captureElapsed>=Config.CaptureSeconds-1e-6 then self.captureElapsed=Config.CaptureSeconds;return "A" end
	elseif self:Alive("A")>0 and now-self.phaseAt>=Config.TravelTimeout then return "Blocked" end
	return nil
end

function Battle:Alive(side: string): number
	local count=0
	for _,unit in self.units do if unit.side==side and unit.hp>0 and not unit.reinforcing and not unit.retiring then count+=1 end end
	return count
end

-- Only an established attack can lose its foothold. A bird already arriving
-- inside the objective counts. Only a deliberate full lineup swap gets travel time;
-- distant birds do not rescue a frontline killed in battle.
function Battle:LostFoothold(now: number?): boolean
	if self.phase~="Fight" and self.phase~="Capture" then return false end
	if self:Alive("A")>0 then self.reliefUntil=nil;return false end
	for _,unit in self.units do
		if unit.side=="A" and unit.hp>0 and not unit.retiring
			and (unit.x-self.destination.X)^2+(unit.z-self.destination.Z)^2<=Config.CaptureRadius^2 then return false end
	end
	if self.reliefUntil and (now or os.clock())<self.reliefUntil then
		for _,unit in self.units do if unit.side=="A" and unit.hp>0 and unit.reinforcing and not unit.retiring then return false end end
	end
	return true
end

function Battle:StepEnemyReclaim(dt: number)
	if self.enemyReclaimElapsed==nil then return end
	self.enemyReclaimElapsed=math.min(Config.EnemyReclaimSeconds,self.enemyReclaimElapsed+dt)
	self.captureElapsed=self.captureAtDefeat*(1-self.enemyReclaimElapsed/Config.EnemyReclaimSeconds)
end

-- Recovery belongs to the existing unit, so it survives camp-to-camp handoffs.
-- Reinforcements are not combat targets until they physically reach the front.
function Battle:MoveUnit(unit, x, z, dt)
	if self.actors then self.actors:Move(unit,x,z,Config.MoveSpeed);return end
	local dx,dz=x-unit.x,z-unit.z
	local length=math.sqrt(dx*dx+dz*dz)
	if length>0 then
		local step=math.min(length,Config.MoveSpeed*dt)
		unit.x+=dx/length*step;unit.z+=dz/length*step
	end
end

function Battle:DepartureSite()
 return March.Site(self.frame or CFrame.new(self.destination),self.isKing)
end

-- Exit first, then chase a living enemy directly. There is no camp entry slot.
function Battle:ApproachUnit(unit,dt,now)
 if not March.Step(self,unit,dt,now) then return end
 if self:ReachedCamp(unit) then return end
 local target,bestDistance=nil,math.huge
 for _,enemy in self.units do
  if enemy.side~=unit.side and enemy.hp>0 and not enemy.reinforcing and not enemy.retiring then
   local d=distance(unit,enemy)
   if enemy.id==unit.targetId then target=enemy;break end
   if d<bestDistance then target,bestDistance=enemy,d end
  end
 end
 unit.targetId=if target then target.id else nil
 self:MoveUnit(unit,if target then target.x else self.destination.X,if target then target.z else self.destination.Z,dt)
end

-- Real proximity activates combat/capture; no fixed rally point is required.
function Battle:ReachedCamp(unit): boolean
 if unit.marchPath then return false end
 if (unit.x-self.destination.X)^2+(unit.z-self.destination.Z)^2<=Config.CaptureRadius^2 then return true end
 -- A defender can meet the flock at the edge. Do not walk past it to touch a zone.
 for _,enemy in self.units do
  if enemy.side~=unit.side and enemy.hp>0 and not enemy.reinforcing and not enemy.retiring then
   local reach=math.max(Config.AttackRange,(unit.size+enemy.size)*0.5+0.3)
   if distance(unit,enemy)<=reach+1 then return true end
  end
 end
 return false
end

function Battle:StepReinforcements(dt: number, now: number)
	for _,unit in self.units do
		if not unit.petId and unit.side~="A" then continue end
		if unit.hp<=0 then
			if not unit.petId then continue end
			if self.incomeContest and self.rosterLocked and not unit.retiring then continue end
			unit.respawnAt=unit.respawnAt or now+Config.AttackerRespawnSeconds
			if now<unit.respawnAt then continue end
			local x,z=unit.homeX,unit.homeZ
			unit.hp,unit.x,unit.z=unit.maxHp,x,z
			unit.respawnAt=nil;unit.nextAttack=now+unit.interval
			unit.pendingAttack=nil;unit.targetId=nil;unit.firstAttack=true;unit.spawnSerial+=1
			unit.reinforcing=not unit.retiring and self.phase~="Returning"
			if unit.reinforcing then March.Approach(unit,self.destination,now) else unit.marchPath=nil end
			unit.returnX,unit.returnZ=x,z
			if self.actors then self.actors:Respawn(unit,x,z) end
			if unit.side=="B" and self.phase=="Capture" then
				self.phase,self.phaseAt,self.capturers="Fight",now,0
			end
			continue -- Let the revived chicken appear at home before its first step.
		end
		if unit.retiring then
			if March.Step(self,unit,dt,now) then self:MoveUnit(unit,unit.homeX,unit.homeZ,dt) end
			continue
		end
		if unit.reinforcing then
			local approaching=self.phase=="Travel" or self.phase=="Fight" or self.phase=="Capture"
			local x,z=unit.entryX,unit.entryZ
			if self.phase=="Returning" then x,z=unit.homeX,unit.homeZ
			elseif self.phase=="Holding" then x,z=unit.holdX or x,unit.holdZ or z
			elseif self.phase=="Capture" then x,z=unit.captureX or self.destination.X,unit.captureZ or self.destination.Z end
			if approaching then self:ApproachUnit(unit,dt,now)
			elseif March.Step(self,unit,dt,now) then self:MoveUnit(unit,x,z,dt)
			else continue end
			local atFront=approaching and self:ReachedCamp(unit)
			if atFront or (not approaching and (unit.x-x)^2+(unit.z-z)^2<=4) then
				unit.reinforcing=false;unit.nextAttack=now
				unit.startX,unit.startZ=unit.x,unit.z
			end
		end
	end
end

-- Holding is a quiet patrol inside the objective, owned by the same battle loop.
-- Fixed hold points remain arrival targets for recovering/new recruits only.
function Battle:StepHolding(unit, dt: number, now: number)
	self.holdRandom=self.holdRandom or Random.new()
	local random=self.holdRandom
	local frame=self.frame or CFrame.new(self.destination)
	local radius=math.min(Config.CaptureRadius-2,if self.isKing then 18 else Config.CampHalfSize-3)
	local position=frame:PointToObjectSpace(Vector3.new(unit.x,self.destination.Y,unit.z))
	if Vector2.new(position.X,position.Z).Magnitude>radius+0.5 then
		-- Finish entering the camp before wandering; never patrol the road outside it.
		unit.holdWalking=false;unit.holdPauseUntil=nil
		self:MoveUnit(unit,unit.holdX or self.destination.X,unit.holdZ or self.destination.Z,dt)
		return
	end
	unit.holdPauseUntil=unit.holdPauseUntil or now+random:NextNumber(0.3,2)
	if unit.holdWalking then
		local dx,dz=unit.holdRoamX-unit.x,unit.holdRoamZ-unit.z
		local length=math.sqrt(dx*dx+dz*dz)
		if length<=1.4 or now>=unit.holdWalkUntil then
			if self.actors then self.actors:Stop(unit) end
			unit.holdWalking=false;unit.holdPauseUntil=now+random:NextNumber(1.5,3.5)
		elseif self.actors then self.actors:Move(unit,unit.holdRoamX,unit.holdRoamZ,Config.RoamSpeed)
		else
			local step=math.min(length,Config.RoamSpeed*dt)
			unit.x+=dx/length*step;unit.z+=dz/length*step
		end
		return
	end
	if self.actors then self.actors:Stop(unit) end
	if now<unit.holdPauseUntil then return end
	local target,best=nil,-math.huge
	for _=1,8 do
		local angle,r=random:NextNumber(0,math.pi*2),math.sqrt(random:NextNumber())*radius
		local at=(frame*CFrame.new(math.cos(angle)*r,0,math.sin(angle)*r)).Position
		local travel=Vector2.new(at.X-unit.x,at.Z-unit.z).Magnitude
		if travel<3 or travel>9 then continue end
		local space=6
		for _,other in self.units do
			if other==unit or other.hp<=0 or other.reinforcing or other.retiring then continue end
			local x=if other.holdWalking then other.holdRoamX else other.x
			local z=if other.holdWalking then other.holdRoamZ else other.z
			space=math.min(space,Vector2.new(at.X-x,at.Z-z).Magnitude)
		end
		if space>best then target,best=at,space end
	end
	if target then
		unit.holdRoamX,unit.holdRoamZ=target.X,target.Z
		unit.holdWalking=true;unit.holdWalkUntil=now+8
	else unit.holdPauseUntil=now+0.5 end
end

function Battle:StepSimulation(dt: number, now: number)
 if self.incomeActiveAt and self.rosterLocked and now-self.incomeActiveAt>=(self.contestSeconds or 90) then return "Draw" end
 -- Decide from actual positions before an expired respawn timer can resurrect
 -- the last fallen fighter and incorrectly keep an abandoned attack alive.
 if self:LostFoothold(now) then return "B" end
 self:StepReinforcements(dt,now)
 -- Individual respawns take priority over capture completion on this tick.
 self:StepDefenderSpawns(now)
 if self.phase=="Returning" then self:StepEnemyReclaim(dt) end
	if self.phase=="Holding" or self.phase=="Returning" then
		for _,u in self.units do
			if u.hp<=0 or u.reinforcing or u.retiring then continue end
			if self.phase=="Holding" then self:StepHolding(u,dt,now)
			elseif March.Step(self,u,dt,now) then self:MoveUnit(u,u.homeX,u.homeZ,dt) end
		end
		return nil
	end
	if self.phase=="Travel" then

		for _,u in self.units do if u.side=="A" and u.hp>0 and not u.reinforcing and not u.retiring then
			self:ApproachUnit(u,dt,now)
		end end
  local arrived=false
  for _,u in self.units do
   if u.side=="A" and u.hp>0 and not u.reinforcing and not u.retiring and self:ReachedCamp(u) then arrived=true;break end
  end
  if not arrived then
   if (self.actors and self.actors:Blocked()) or now-self.phaseAt>=Config.TravelTimeout then return "Blocked" end
   return nil
  end
  self.arrivedAt=now
  -- Classify each bird before a territory join can transfer this encounter.
  -- The first arrival must never make road stragglers combat-ready on side B.
  for _,u in self.units do
   if u.side=="A" and u.hp>0 and not u.retiring and not self:ReachedCamp(u) then u.reinforcing=true end
  end
  -- Territory joins and NPC commitment occur only after a real hostile arrival.
  if self.beforeIncomeArrival then
   local result=self.beforeIncomeArrival(self,now)
   if result then return result end
  end
  if self.incomeContest then self.incomeActiveAt=self.incomeActiveAt or now end
  -- First contact starts the fight; later birds keep exiting/chasing independently.
  if self:Alive("B")>0 then self.phase,self.phaseAt="Fight",now
  else self:BeginCapture(now) end
  -- Continue into combat on this tick; normal attack windup still applies.
	end
	if self.phase=="Capture" then
		return self:StepCapture(dt,now)
	end
	if self:Alive("A")==0 then
		-- A living reinforcement is already in the vicinity; let it reach its entry point.
		for _,unit in self.units do if unit.side=="B" and self.actors then self.actors:Stop(unit) end end
		self.phaseAt=now
		if self:Alive("B")==0 then self:BeginCapture(now) end
		return nil
	end
	if now-self.phaseAt>=Config.FightTimeout then return "Draw" end
	local byId,targets={},{}
	for _,unit in self.units do byId[unit.id]=unit end
	for _,u in self.units do
		if u.hp<=0 or u.reinforcing or u.retiring then u.pendingAttack=nil;u.targetId=nil;continue end
		-- Keep a living opponent through the exchange. Re-selecting the nearest
		-- enemy every tick made the flock twitch between neighboring targets.
		local best=byId[u.targetId]
		if not best or best.hp<=0 or best.reinforcing or best.retiring or best.side==u.side then
			best=nil;u.pendingAttack=nil
			local bestDistance=math.huge
			for _,enemy in self.units do
				if enemy.side~=u.side and enemy.hp>0 and not enemy.reinforcing and not enemy.retiring then
					local d=distance(u,enemy)
					if d<bestDistance then best,bestDistance=enemy,d end
				end
			end
		end
		u.targetId=if best then best.id else nil
		targets[u.id]=best
	end
	for _,u in self.units do
		-- Reinforcement movement was previously cancelled here by the no-target Stop.
		if u.hp<=0 or u.reinforcing or u.retiring then continue end
		local target=targets[u.id]
		if not target then if self.actors then self.actors:Stop(u) end;continue end
		local dx,dz=target.x-u.x,target.z-u.z
		local d=math.sqrt(dx*dx+dz*dz)
		local reach=math.max(Config.AttackRange,(u.size+target.size)*0.5+0.3)
		if d>0.001 then
			u.faceX,u.faceZ=dx/d,dz/d
			if d>reach+0.15 and not u.pendingAttack then
				if self.actors then
					local endpoint=math.max(0.25,reach-Config.ActorArrivalDistance-0.2)
					self.actors:Move(u,target.x-dx/d*endpoint,target.z-dz/d*endpoint,Config.MoveSpeed)
				else
					local move=math.min(Config.MoveSpeed*dt,d-reach+0.05)
					u.x+=dx/d*move;u.z+=dz/d*move
				end
			elseif self.actors then self.actors:Face(u,target.x,target.z) end
		end
	end
	-- Wind up first, then commit simultaneous damage at the authored peck's
	-- contact frame. Death, retreat or a lost target cancels an unfinished hit.
	local damage={}
	for _,u in self.units do
		local target=targets[u.id]
		if not target then continue end
		local reach=math.max(Config.AttackRange,(u.size+target.size)*0.5+0.3)+0.15
		if u.firstAttack and distance(u,target)<=reach then
			u.firstAttack=false;u.nextAttack=math.max(u.nextAttack,now+u.attackStagger)
		end
		if u.pendingAttack then
			local attack=u.pendingAttack
			if now+1e-6>=attack.hitAt then
				u.pendingAttack=nil
				if target.id==attack.targetId and distance(u,target)<=reach+0.4 then
					u.impactSerial+=1;u.impactX,u.impactZ=target.x,target.z
					damage[target.id]=(damage[target.id] or 0)+u.damage
					if u.splash then
						local others={}
						for _,enemy in self.units do
							if enemy~=target and enemy.side~=u.side and enemy.hp>0 and not enemy.reinforcing and not enemy.retiring and distance(enemy,target)<=Config.SplashRadius then table.insert(others,enemy) end
						end
						table.sort(others,function(a,b) return distance(a,target)<distance(b,target) end)
						for i=1,math.min(2,#others) do local enemy=others[i];damage[enemy.id]=(damage[enemy.id] or 0)+u.damage*Config.SplashDamageFraction end
					end
				end
			end
		elseif now+1e-6>=u.nextAttack and distance(u,target)<=reach then
			u.nextAttack=now+u.interval;u.attackSerial+=1;u.attackStartedAt=now
			u.pendingAttack={targetId=target.id,hitAt=now+Config.AttackWindupSeconds}
		end
	end
	for _,u in self.units do
		local wasAlive=u.hp>0
  u.hp=math.max(0,u.hp-(damage[u.id] or 0))
  if wasAlive and u.hp<=0 then
   -- Schedule once at this chicken's death, never when the last guard falls.
   if u.side=="B" and not u.petId and not u.noRespawn and not self.incomeContest then
    u.respawnAt=now+math.random(Config.DefenderRespawnMinSeconds,Config.DefenderRespawnMaxSeconds)
   end
   self.killSerial+=1
   table.insert(self.kills,{serial=self.killSerial,unitId=u.id,life=u.spawnSerial,
    side=u.side,species=u.species,level=u.level,boss=u.boss,x=u.x,z=u.z})
  end
		if u.hp<=0 then
			u.pendingAttack=nil;u.targetId=nil
			if u.petId and not u.respawnAt then u.respawnAt=now+Config.AttackerRespawnSeconds;u.reinforcing=false end
			if self.actors then self.actors:Stop(u) end
		end
	end
	if self:LostFoothold(now) then return "B" end
	if self:Alive("B")==0 then self:BeginCapture(now) end
	return nil
end

function Battle:Step(dt: number, now: number)
	if self.actors then self.actors:Sync(now) end
	local outcome=self:StepSimulation(dt,now)
	-- Publish this tick's windup and health immediately, not on the next tick.
	if self.actors then self.actors:Publish(now) end
	return outcome
end

-- Draining is destructive: a death can be credited only once, even on the final tick.
function Battle:DrainKills()
 local kills=self.kills
 self.kills={}
 return kills
end

function Battle:Hold(now: number)
	self.outcome,self.phase,self.phaseAt="A","Holding",now
	self:CancelAttacks()
	local army={}
	for _,u in self.units do if u.side=="A" then table.insert(army,u) end end
	self.units=army
	for i,u in army do
		if u.hp>0 and not self.preserveHealth then u.hp=u.maxHp end
		u.holdStartX,u.holdStartZ=u.x,u.z
		local x,z=FlockLayout.Offset(i,#army)
		local scale=math.min(1,Config.CampHalfSize/18)
		x,z=x*scale,z*scale
		local at=((self.frame or CFrame.new(self.destination))*CFrame.new(x,0,z)).Position
		u.holdX,u.holdZ=at.X,at.Z
		u.holdWalking=false;u.holdPauseUntil=nil
		if self.actors and u.hp>0 and not u.reinforcing and not u.retiring then self.actors:Stop(u) end
	end
end

function Battle:Finish(outcome: string, now: number)
	if outcome=="B" then
		self.enemyReclaimElapsed,self.captureAtDefeat=0,self.captureElapsed
		self.enemyControlAtDefeat=math.clamp(1-self.captureElapsed/Config.NeutralizeSeconds,0,1)
		self.playerControlAtDefeat=math.clamp((self.captureElapsed-Config.NeutralizeSeconds)/(Config.CaptureSeconds-Config.NeutralizeSeconds),0,1)
		self.capturers=0
	end
	self.outcome,self.phase,self.phaseAt=outcome,"Returning",now
	self:CancelAttacks()
	-- Only the player's squad marches home; defeated camp guards are handled by the spawner.
	local army={}
	for _,u in self.units do
		if u.side~="A" then continue end
		u.replacementFor=nil;u.retiring=nil
		March.Set(u,March.Path(Vector3.new(u.x,1.05,u.z),Vector3.new(u.homeX,1.05,u.homeZ),self:DepartureSite()),now)
		u.returnX,u.returnZ=u.x,u.z
		if u.hp>0 and not self.preserveHealth then u.hp=u.maxHp end
		table.insert(army,u)
	end
	self.units=army
end

function Battle:Returned(now: number): boolean
 if self.phase~="Returning" then return false end
 if self.enemyReclaimElapsed and self.enemyReclaimElapsed<Config.EnemyReclaimSeconds then return false end
 for _,u in self.units do if u.hp<=0 or u.reinforcing or (u.x-u.homeX)^2+(u.z-u.homeZ)^2>4 then return false end end
 return true
end

function Battle:Destroy()
 if self.actors then self.actors:Destroy();self.actors=nil end
end

function Battle:Snapshot(now: number)
 for i=#self.coinDrops,1,-1 do
  if now-self.coinDrops[i].at>2 then table.remove(self.coinDrops,i) end
 end
	local units={}
	for _,u in self.units do
		table.insert(units,{id=u.id,petId=u.petId,side=u.side,boss=u.boss,species=u.species,stars=u.stars,level=u.level,retiring=u.retiring==true,reinforcing=u.reinforcing==true,respawnRemaining=if u.respawnAt then math.max(0,u.respawnAt-now) else 0,x=u.x,z=u.z,
			giantSize=u.giantSize,
			hp=u.hp,maxHp=u.maxHp,attackSerial=u.attackSerial,impactSerial=u.impactSerial,impactX=u.impactX,impactZ=u.impactZ,
			spawnSerial=u.spawnSerial,faceX=u.faceX,faceZ=u.faceZ})
	end
	local duration=if self.phase=="Travel" then Config.TravelSeconds elseif self.phase=="Capture" then Config.CaptureSeconds
		elseif self.phase=="Returning" then Config.ReturnSeconds else Config.FightTimeout
	local reclaiming=self.enemyReclaimElapsed~=nil
	local reclaimProgress=if reclaiming then math.clamp(self.enemyReclaimElapsed/Config.EnemyReclaimSeconds,0,1) else 0
	local defenderRespawnAt=self:NextDefenderRespawn()
	return {id=self.id,coinDrops=table.clone(self.coinDrops),attacker=self.attacker,target=self.target,defender=self.defender,phase=self.phase,outcome=self.outcome,incomeContest=self.incomeContest==true,rosterLocked=self.rosterLocked==true,travelStage=if self.phase=="Travel" then (if self.assembling then "Assembling" else "Marching") else nil,
		remaining=if self.phase=="Holding" then 0 elseif self.phase=="Capture" then math.max(0,Config.CaptureSeconds-self.captureElapsed) else math.max(0,duration-(now-self.phaseAt)),units=units,a=self:Alive("A"),b=self:Alive("B"),
		captureProgress=math.clamp(self.captureElapsed/Config.CaptureSeconds,0,1),
		captureStarted=self.captureStarted,capturePaused=not reclaiming and self.captureStarted and (self.phase=="Fight" or self:Alive("A")==0),
		enemyReclaiming=reclaiming,enemyReclaimComplete=reclaiming and reclaimProgress>=1,
		captureStage=if reclaiming or self.captureElapsed<Config.NeutralizeSeconds then "Enemy" else "Player",
		enemyControl=if reclaiming then self.enemyControlAtDefeat+(1-self.enemyControlAtDefeat)*reclaimProgress else math.clamp(1-self.captureElapsed/Config.NeutralizeSeconds,0,1),
		playerControl=if reclaiming then self.playerControlAtDefeat*(1-reclaimProgress) else math.clamp((self.captureElapsed-Config.NeutralizeSeconds)/(Config.CaptureSeconds-Config.NeutralizeSeconds),0,1),
		captureRemaining=math.max(0,Config.CaptureSeconds-self.captureElapsed),
		defenderRespawnIn=if defenderRespawnAt then math.max(0,defenderRespawnAt-now) else nil,
		defenderRespawns=self.defenderRespawns,waitingForArmy=self:Alive("A")==0,
		captureActive=self.phase=="Capture" and self.capturers>0,capturers=self.capturers,captureRadius=Config.CaptureRadius,
		x=self.destination.X,z=self.destination.Z,name=self.name,
		promotion=self.promotion,routeGoal=if self.routeGoal then self.routeGoalName else nil}
end

return Battle
