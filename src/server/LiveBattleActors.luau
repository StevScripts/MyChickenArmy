--!strict
-- Owns physical rigs for one encounter. Battle remains the sole combat-state owner.
local PetActor=require(script.Parent.PetActor)
local PetView=require(game:GetService("ReplicatedStorage").PetRoll.Shared.PetView)
local KingVisual=require(game:GetService("ReplicatedStorage").PetRoll.Shared.KingVisual)
local KingEncounter=require(script.Parent.KingEncounter)
local LiveBattleActors={}
LiveBattleActors.__index=LiveBattleActors

-- Same surface resolver for first spawn, recovery and every movement target.
local MapLayout=require(game:GetService("ReplicatedStorage").PetRoll.Shared.MapLayout)
local function spawnFoot(x,z)
 return MapLayout.FootPosition(x,z)
end

function LiveBattleActors.new(parent,battle)
 local folder=Instance.new("Folder");folder.Name=battle.id;folder.Parent=parent
 return setmetatable({folder=folder,battle=battle,actors={}},LiveBattleActors)
end

function LiveBattleActors:Adopt(unit,actor)
 local existing=self.actors[unit.id]
 if existing and existing~=actor then existing:Destroy() end
 actor:Stop()
 actor.model.Name=unit.id
 actor:SetParent(self.folder)
 actor.model:SetAttribute("AtHome",false)
 actor.model:SetAttribute("Recruiting",false)
 actor.model:SetAttribute("InArmy",true)
 actor.model:SetAttribute("BattleId",self.battle.id);actor.model:SetAttribute("UnitId",unit.id)
 actor.model:SetAttribute("PetId",unit.petId);actor.model:SetAttribute("Side",unit.side)
 actor.model:SetAttribute("OwnerUserId",if unit.side=="A" then self.battle.attacker else self.battle.defender)
 actor.model:SetAttribute("OwnerId",if unit.side=="A" then self.battle.attacker else self.battle.defender)
 self.actors[unit.id]=actor
 PetView.Level(actor.model,unit.level or 1,unit.giantSize)
 local at=actor:Position();unit.x,unit.z=at.X,at.Z
end

function LiveBattleActors:TakePet(petId,side)
 for _,unit in self.battle.units do
  if unit.petId==petId and (not side or unit.side==side) then
   local actor=self.actors[unit.id];self.actors[unit.id]=nil
   if actor then actor:Stop() end
   return actor
  end
 end
 return nil
end

-- Transfers are keyed by encounter unit, since two owners can have different
-- birds on the same side of a former encounter during a territory handoff.
function LiveBattleActors:TakeUnit(unitId)
 local actor=self.actors[unitId]
 self.actors[unitId]=nil
 if actor then actor:Stop() end
 return actor
end

function LiveBattleActors:Sync(now)
 local desired={}
 for _,u in self.battle.units do
  desired[u.id]=true
  local actor=self.actors[u.id]
  if not actor then
   actor=PetActor.new(self.folder,u.id,u.species,u.stars,spawnFoot(u.x,u.z))
   if u.boss then
    KingVisual.Apply(actor.model,KingEncounter.Scale)
    actor.footOffset=actor.model:GetAttribute("FootOffset")
   end
   self:Adopt(u,actor)
  end
  actor:Step(now)
  local at=actor:Position();u.x,u.z=at.X,at.Z
 end
 for id,actor in self.actors do if not desired[id] then actor:Destroy();self.actors[id]=nil end end
end

function LiveBattleActors:Publish(now)
 for _,u in self.battle.units do
  local actor=self.actors[u.id]
  if not actor then continue end
  if actor.model:GetAttribute("AttackSerial")~=u.attackSerial then
   actor.model:SetAttribute("AttackStartedAt",if u.attackStartedAt then workspace:GetServerTimeNow()-math.max(0,now-u.attackStartedAt) else nil)
   actor.model:SetAttribute("AttackSerial",u.attackSerial)
  end
  actor.model:SetAttribute("Attacking",u.pendingAttack~=nil)
  actor.model:SetAttribute("Defeated",u.hp<=0)
  actor.model:SetAttribute("Reinforcing",u.reinforcing==true)
  actor.model:SetAttribute("SpawnSerial",u.spawnSerial)
  PetView.Level(actor.model,u.level or 1,u.giantSize)
  PetView.Health(actor.model,u.hp/u.maxHp)
 end
end

-- Revive the same defending roster at its spawn line; never create extra soldiers.
function LiveBattleActors:Respawn(unit,x,z)
 local actor=self.actors[unit.id]
 if not actor then return end -- Sync creates a missing rig at the unit's new position.
 actor:Stop()
 local footOffset=actor.model:GetAttribute("FootOffset") or actor.footOffset
 local position=spawnFoot(x or unit.entryX,z or unit.entryZ)+Vector3.new(0,footOffset,0)
 actor.model:PivotTo(CFrame.new(position)*actor.root.CFrame.Rotation)
 actor.root.AssemblyLinearVelocity,actor.root.AssemblyAngularVelocity=Vector3.zero,Vector3.zero
 actor.safeFoot=spawnFoot(x or unit.entryX,z or unit.entryZ)
 actor.healthPosition,actor.healthAt=actor.safeFoot,os.clock()
 actor.model:SetAttribute("Defeated",false)
 PetView.Health(actor.model,1)
end

function LiveBattleActors:Move(unit,x,z,speed)
 local actor=self.actors[unit.id]
 if actor then actor:MoveTo(MapLayout.FootPosition(x,z),speed) end
end

function LiveBattleActors:Stop(unit)
 local actor=self.actors[unit.id];if actor then actor:Stop() end
end

function LiveBattleActors:Face(unit,x,z)
 local actor=self.actors[unit.id]
 if actor then actor:Face(Vector3.new(x,1.05,z)) end
end

function LiveBattleActors:Blocked(): boolean
 for _,actor in self.actors do if actor.model:GetAttribute("MovementBlocked") then return true end end
 return false
end

function LiveBattleActors:Destroy()
 for _,actor in self.actors do actor:Destroy() end
 self.actors={};self.folder:Destroy()
end
return LiveBattleActors
