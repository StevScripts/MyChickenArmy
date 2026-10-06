local s=assert(_G.GuardHandoffService)
local player=game.Players:GetPlayers()[1]
local session=s.sessions[player.UserId]
assert(session.saveStatus=="studio-session")
session.tutorial.guideSkipped=true
session:Touch()
_G.GuardHandoffResults={}
_G.GuardHandoffProbe=function(target)
 local before={}
 local record
 if target=="king:1" then
  record=s.world.kingArena
  before[1]={actor=record.actor}
  for i,actor in record.guards do before[i+1]={actor=actor} end
 else
  local kind,index=target:match("^(%a+):(%d+)$");index=tonumber(index)
  record=if kind=="camp" then s.world.lanes[session.plotIndex][index] else s.world.outposts[index]
  for i,actor in record.actors do before[i]={actor=actor} end
 end
 for _,entry in before do
  local actor=entry.actor
  entry.position=actor:Position();entry.rotation=actor.root.CFrame.Rotation
  entry.model=actor.model;entry.scale=actor.model:GetScale()
 end
 local ok,why=s:Attack(session,target,os.clock());assert(ok,why)
 local battle=s.battles[session.outgoing];assert(battle.target==target)
 local report={target=target,count=#before,guards={},idleCleared=if target=="king:1" then record.actor==nil and next(record.guards)==nil and record.kingPatrol==nil and next(record.guardPatrols)==nil else next(record.actors)==nil and next(record.patrols)==nil}
 local i=0
 for _,unit in battle.units do if unit.side=="B" then
  i+=1
  local entry=assert(before[i]);local actor=battle.actors.actors[unit.id]
  local delta=(actor:Position()-entry.position).Magnitude
  local _,angle=entry.rotation:ToObjectSpace(actor.root.CFrame.Rotation):ToAxisAngle()
  local identical=actor==entry.actor and actor.model==entry.model
  assert(identical and delta<.001 and math.abs(angle)<.001,"Guard changed identity or transform at deployment")
  assert(actor.model:GetScale()==entry.scale,"Guard scale changed")
  assert(math.abs(unit.x-entry.position.X)<.001 and math.abs(unit.z-entry.position.Z)<.001)
  if unit.boss then assert(actor.model:GetAttribute("ChickenKing") and actor.model:FindFirstChild("RoyalCrown")) end
  table.insert(report.guards,{id=unit.id,sameActorAndModel=identical,positionDelta=delta,rotationDelta=angle,sameScale=true,boss=unit.boss})
 end end
 assert(i==#before and report.idleCleared)
 table.insert(_G.GuardHandoffResults,report)
 return report
end
return _G.GuardHandoffProbe("camp:1")
