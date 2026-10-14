--!strict
-- Reconciles selected intent with real walking chickens on either player side.
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Giant=require(Shared.GiantChicken)
local Layout=require(Shared.FlockLayout)
local March=require(Shared.ArmyMarch)
local Reinforcements={}
function Reinforcements.Sync(session,battle,world,now)
	if battle.operationId then return end -- Operation lineups are fixed at deployment.
 if battle.phase=="Returning" then return end
 local side=if battle.attacker==session.userId then "A" elseif battle.defender==session.userId then "B" else nil
 if not side then return end
 local ids=session:BestPetIds()
 local desired={};for slot,id in ids do desired[id]=slot end
 local byPet,removedFront={},false
 local finite=battle.incomeContest and battle.rosterLocked
 -- Returning home cannot grant another life in the same finite territory contest.
 battle.reliefHistory=battle.reliefHistory or {}
 local history=battle.reliefHistory[side] or {};battle.reliefHistory[side]=history
 for _,u in battle.units do if u.side==side and u.petId then
  byPet[u.petId]=u
  u.replacementFor=nil
  if not desired[u.petId] and not u.retiring then
   removedFront=removedFront or (u.hp>0 and not u.reinforcing)
   u.retiring=true;u.reinforcing=false;u.pendingAttack=nil;u.targetId=nil
   if finite then u.retiringHp=u.hp end
   March.Set(u,March.Path(Vector3.new(u.x,1.05,u.z),Vector3.new(u.homeX,1.05,u.homeZ),battle:DepartureSite()),now)
  elseif desired[u.petId] then
   u.slot=desired[u.petId]
   if u.retiring then
    if finite and (u.retiringHp or u.hp)<=0 then continue end
    -- Reuse the same life and rig when a player reverses a change mid-walk.
    u.retiring=false;u.retiringHp=nil;u.reinforcing=true;u.pendingAttack=nil;u.targetId=nil
    March.Approach(u,battle.destination,now,battle:DepartureSite())
   end
  end
 end end
 for slot,id in ids do
  if byPet[id] then continue end
  local record=finite and history[id]
  if record and record.hp<=0 then continue end
  local pet=session.pets[id]
  -- A replaced Colossal walks home before the next one leaves. This also covers
  -- rapid selection changes and dead/respawning units still owned by the battle.
  if Giant.IsColossal(pet.giantSize) then
   local occupied=false
   for _,other in battle.units do
    if other.side==side and other.petId~=id and Giant.IsColossal(other.giantSize) then occupied=true;break end
   end
   if occupied then continue end
  end
  local home=world:ReturnPosition(session,id,slot)
  local start=world:PetPosition(session.plotIndex,id) or home
  battle:AddArmy(side,{{id=id,species=pet.species,stars=pet.stars,level=pet.level,giantSize=pet.giantSize,mutation=pet.mutation,slot=slot}},start)
  local u=battle.units[#battle.units]
  u.x,u.z,u.startX,u.startZ=start.X,start.Z,start.X,start.Z
  u.homeX,u.homeZ=home.X,home.Z;u.reinforcing=true
  if record then u.hp=math.min(u.maxHp,record.hp) end
  local ex,ez=Layout.Entry(slot,session:Capacity(),side)
  local entry=((battle.frame or CFrame.new(battle.destination))*CFrame.new(ex,0,ez)).Position
  u.entryX,u.entryZ=entry.X,entry.Z
  u.holdX,u.holdZ=battle.destination.X,battle.destination.Z
  March.Approach(u,battle.destination,now)
  if battle.actors and world.TakeActor then local actor=world:TakeActor(session.plotIndex,id);if actor then battle.actors:Adopt(u,actor) end end
  byPet[id]=u
 end
 if side=="A" and removedFront and battle:Alive(side)==0 and #ids>0 then
  -- A voluntary full swap is not a death wipe; capture still needs a real arrival.
  battle.reliefUntil=now+Config.TravelTimeout
 end
 -- A chicken remains away (and cannot earn/sell/merge) until it physically gets home.
 local away,slots,restored={},{},{}
 for i=#battle.units,1,-1 do
  local u=battle.units[i]
  if u.side~=side or not u.petId then continue end
  if u.retiring and (u.x-u.homeX)^2+(u.z-u.homeZ)^2<=4 and u.hp>0 then
   local actor=battle.actors and battle.actors:TakePet(u.petId,side)
   if finite then history[u.petId]={hp=u.retiringHp or u.hp} end
   table.remove(battle.units,i)
   if actor then table.insert(restored,{id=u.petId,actor=actor}) end
  else
   away[u.petId]=true
   if not u.retiring then slots[u.slot]=u.petId end
  end
 end
 local changed=false
 for i=1,session:Capacity() do if session.slots[i]~=slots[i] then changed=true end end
 for id in session.awayPets or {} do if not away[id] then changed=true end end
 for id in away do if not (session.awayPets or {})[id] then changed=true end end
 session.slots,session.awayPets=slots,away
 if changed or #restored>0 then session:Touch() end
 for _,entry in restored do world:RestoreActor(session,entry.id,entry.actor) end
end
return Reinforcements
