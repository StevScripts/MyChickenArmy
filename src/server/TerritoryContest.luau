--!strict
-- Physical participant handoffs only. Battle owns combat; BattleService owns
-- reservations, ownership, rewards and the lifetime of these encounters.
local HttpService=game:GetService("HttpService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Layout=require(Shared.FlockLayout)
local March=require(Shared.ArmyMarch)
local Battle=require(script.Parent.Battle)
local Actors=require(script.Parent.LiveBattleActors)
local TerritoryContest={}

function TerritoryContest.Side(battle,userId)
 if battle.attacker==userId then return "A" end
 if battle.defender==userId then return "B" end
 return nil
end

function TerritoryContest.CreateActors(battle,world)
 if not world.root then return end
 local folder=world.root:FindFirstChild("Battles")
 if not folder then folder=Instance.new("Folder");folder.Name="Battles";folder.Parent=world.root end
 battle.actors=Actors.new(folder,battle)
end

-- Take before removing source units; never create a fresh full-health garrison.
-- Unit IDs are encounter-local, so replacement references need the same remap.
function TerritoryContest.Transfer(source,destination,fromSide,toSide)
 local moved,retained,ids={},{},{}
 for _,old in source.units do
  if old.side~=fromSide then table.insert(retained,old);continue end
  destination.serial+=1
  local unit=table.clone(old)
  unit.id=tostring(destination.serial);unit.side=toSide
  unit.pendingAttack=nil;unit.targetId=nil;unit.firstAttack=true
  ids[old.id]=unit.id
  table.insert(destination.units,unit);table.insert(moved,unit)
  if source.actors then
   local actor=source.actors:TakeUnit(old.id)
   if actor and destination.actors then destination.actors:Adopt(unit,actor)
   elseif actor then actor:Destroy() end
  end
 end
 source.units=retained
 for _,unit in moved do unit.replacementFor=unit.replacementFor and ids[unit.replacementFor] end
 return moved
end

function TerritoryContest.Lock(battle)
 battle.incomeContest=true;battle.rosterLocked=true;battle.preserveHealth=true
 for _,unit in battle.units do
  unit.pendingAttack=nil;unit.targetId=nil
  if not unit.petId then unit.noRespawn=true end
  if unit.hp<=0 then unit.respawnAt=nil;unit.contestUnavailable=true end
 end
end

function TerritoryContest.Assign(session,battle,side,state)
 local away,slots={},{}
 for _,unit in battle.units do if unit.side==side and unit.petId then
  away[unit.petId]=true
  if not unit.retiring and not unit.replacementFor then slots[unit.slot]=unit.petId end
 end end
 session.outgoing=battle.id;session.armyState=state;session.returnAt=0
 session.stationedAt=if state=="Deployed" then battle.name else nil
 session.awayPets,session.slots=away,slots
 session:Touch()
end

function TerritoryContest.AddPlayer(battle,session,world,now,side,previous,stationed)
 local units
 if previous then
  units=TerritoryContest.Transfer(previous,battle,TerritoryContest.Side(previous,session.userId),side)
 else
  local origin=world:Position(session.plotIndex)
  local first=#battle.units+1
  battle:AddArmy(side,session:Lineup(),origin)
  units={}
  for i=first,#battle.units do
   local unit=battle.units[i];table.insert(units,unit)
   local hx,hz=Layout.Home(unit.slot)
   local home=if world.ReturnPosition then world:ReturnPosition(session,unit.petId,unit.slot)
    else origin+Vector3.new(hx,0,hz)
   local start=(world.PetPosition and world:PetPosition(session.plotIndex,unit.petId)) or home
   unit.x,unit.z,unit.startX,unit.startZ=start.X,start.Z,start.X,start.Z
   unit.homeX,unit.homeZ=home.X,home.Z
   if battle.actors and world.TakeActor then
    local actor=world:TakeActor(session.plotIndex,unit.petId)
    if actor then battle.actors:Adopt(unit,actor) end
   end
  end
 end
 for _,unit in units do
  local ex,ez=Layout.Entry(unit.slot or 1,session:Capacity(),side)
  local entry=(battle.frame*CFrame.new(ex,0,ez)).Position
  unit.entryX,unit.entryZ=entry.X,entry.Z
  if not stationed and unit.hp>0 and not unit.retiring then
   unit.reinforcing=false
   March.Approach(unit,battle.destination,now,if previous then previous:DepartureSite() else nil)
  end
 end
 return units
end

function TerritoryContest.Continue(source,session,side,world,now,holding)
 local result=Battle.new(HttpService:GenerateGUID(false),session.userId,source.target,source.destination,source.destination,now)
 result.name,result.frame,result.plotIndex=source.name,source.frame,session.plotIndex
 result.marchDestination=source.marchDestination;result.promotion=session.promotion or 1
 result.routeCamps,result.routeOutposts=table.clone(source.routeCamps or {}),table.clone(source.routeOutposts or {})
 result.incomeSite=true;result.preserveHealth=true;result.paid=true
 result.campKey=if holding then "income:1" else nil
 result.friendlyTerritory=holding
 result.captureElapsed=if holding then Config.CaptureSeconds else 0
 TerritoryContest.CreateActors(result,world)
 TerritoryContest.Transfer(source,result,side,"A")
 for _,unit in result.units do
  unit.contestUnavailable=nil
  if unit.hp<=0 then unit.respawnAt=now+Config.AttackerRespawnSeconds end
 end
 if holding then result:Hold(now) else result:Finish("Territory resolved",now) end
 TerritoryContest.Assign(session,result,"A",if holding then "Deployed" else "Returning")
 if not holding then session.returnAt=now+Config.ReturnSeconds end
 return result
end

return TerritoryContest
