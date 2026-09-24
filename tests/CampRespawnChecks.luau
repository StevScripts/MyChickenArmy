-- Isolated ownership/departure fixtures. No profiles or live world changes.
local Server=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Session=require(Server.PlayerSession)
local Service=require(Server.BattleService)
local Battle=require(Server.Battle)
local Config=require(Shared.Config)
local Layout=require(Shared.FlockLayout)
local Checks={}

local function setup()
 local a,b=Session.new(901,"First",1),Session.new(902,"Second",2)
 a.loaded,b.loaded=true,true
 local world={owners={},busy={},restored={},events={}}
 local function key(location)
  return if location.king then "king:1" elseif location.income then "income:1"
   elseif location.outpost then "outpost:"..location.outpost else location.plot..":"..location.index
 end
 function world:Position(plot) return Vector3.new((plot-1)*100,1.05,-240) end
 function world:CampPosition(index,plot) return Vector3.new((plot-1)*100,1.05,if index==1 then -177 else -89) end
 function world:CampFrame(index,plot) return CFrame.new(self:CampPosition(index,plot)) end
 function world:OutpostFrame(index) return CFrame.new(145*math.cos(index*math.pi/3),1.05,145*math.sin(index*math.pi/3)) end
 function world:IncomeFrame() return CFrame.new(79,1.05,-79) end
 function world:ReturnPosition(session,_,slot) local x,z=Layout.Home(slot);return self:Position(session.plotIndex)+Vector3.new(x,0,z) end
 function world:PetPosition(...) return nil end
 function world:SetTerritoryOwner(location,userId)
  local id=key(location);self.owners[id]=userId
  table.insert(self.events,{kind="owner",key=id,value=userId})
 end
 function world:Busy(id,value)
  self.busy[id]=value
  table.insert(self.events,{kind="busy",key=id,value=value})
  if not value and not self.owners[id] then self.restored[id]=(self.restored[id] or 0)+1 end
 end
 function world:SetCampBusy(index,value,plot) self:Busy(plot..":"..index,value) end
 function world:SetOutpostBusy(index,value) self:Busy("outpost:"..index,value) end
 function world:SetIncomeBusy(value) self:Busy("income:1",value) end
 function world:SetIncomeStatus(...) end
 world.kingArena={SetBusy=function(_,value) world:Busy("king:1",value) end}
 return Service.new({[a.userId]=a,[b.userId]=b},world),a,b,world
end

local function holding(service,session,target,now)
 assert(service:Attack(session,target,now))
 local battle=service.battles[session.outgoing]
 for _,unit in battle.units do
  if unit.side=="A" then unit.x,unit.z=battle.destination.X,battle.destination.Z
  else unit.hp=0 end
  unit.marchPath=nil;unit.reinforcing=false
 end
 battle.captureElapsed=Config.CaptureSeconds
 service:Finish(battle,"A",now+1)
 assert(battle.phase=="Holding")
 return battle
end

local function leave(battle)
 for _,unit in battle.units do unit.x,unit.z=800,800 end
end

local function release(service,now)
 service:ReleaseClearedCamps(now)
 service:ReleaseClearedCamps(now+Config.CampRespawnGrace+.01)
end

local function crossing(service,session,location,id)
 local battle=Battle.new(id,session.userId,"outpost:6",Vector3.new(800,1,800),Vector3.new(900,1,900),0)
 battle:AddArmy("A",session:Lineup(),Vector3.new(800,1,800))
 local unit=battle.units[1];unit.x,unit.z=location.X,location.Z
 service.battles[battle.id]=battle
 return battle,unit
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,result=pcall(fn);table.insert(results,{name=name,passed=ok,detail=tostring(result)})
 end
 test("Conquered holding camp suppresses enemies beyond the respawn timer",function()
  local service,a,_,world=setup();local battle=holding(service,a,"camp:1",0)
  for i=1,200 do battle:Step(.1,1+i*.1);service:ReleaseClearedCamps(1+i*.1) end
  assert(battle:Alive("B")==0 and battle.defenderRespawnAt==nil)
  assert(service.campOwners["1:1"].userId==a.userId and not world.restored["1:1"])
  service:Destroy();return "No timer-driven garrison while the victorious army stays"
 end)
 test("Recall releases after physical vacancy and preserves earned progress",function()
  local service,a,_,world=setup();local battle=holding(service,a,"camp:1",0)
  a.frontierWins[4]=true;a.kingCleared=true;a.promotion=4
  assert(service:ReturnHome(a,2));release(service,3)
  assert(service.campBusy["1:1"] and service.campOwners["1:1"],"Recall command released an occupied camp")
  leave(battle);service:ReleaseClearedCamps(4)
  assert(service.campBusy["1:1"],"Vacancy grace was skipped")
  service:ReleaseClearedCamps(4+Config.CampRespawnGrace+.01)
  assert(not service.campBusy["1:1"] and not service.campOwners["1:1"] and world.restored["1:1"]==1)
  local n=#world.events;assert(world.events[n-1].kind=="owner" and world.events[n].kind=="busy")
  assert(a.firstWins[1] and a.frontierWins[4] and a.kingCleared and a.promotion==4)
  assert(a.lastResult~="A territory was captured by another army.")
  service:Destroy();return "Owner clears before NPC restoration; saved progression remains"
 end)
 test("Other armies and either player side postpone departure release",function()
  local service,a,b,world=setup();local holder=holding(service,a,"camp:1",0)
  assert(service:ReturnHome(a,2));leave(holder)
  local other,first=crossing(service,b,holder.destination,"crossing")
  first.reinforcing=true
  release(service,3);assert(not world.restored["1:1"])
  first.x,first.z=800,800
  other.defender=a.userId;other:AddArmy("B",a:Lineup(),holder.destination)
  for _,unit in other.units do if unit.side=="B" then unit.x,unit.z=800,800 end end
  local tail=other.units[#other.units];tail.x,tail.z=holder.destination.X,holder.destination.Z;tail.retiring=true
  release(service,4);assert(not world.restored["1:1"],"Side B retiring bird did not count")
  leave(other);release(service,5);assert(world.restored["1:1"]==1)
  service:Destroy();return "All live player birds count, including reinforcements and relief birds"
 end)
 test("Hidden casualties and neutral NPCs do not pin occupancy",function()
  local service,a,b,world=setup();local holder=holding(service,a,"camp:1",0)
  assert(service:ReturnHome(a,2));leave(holder)
  local other,dead=crossing(service,b,holder.destination,"dead-crossing");dead.hp=0
  other:AddArmy("B",{{species="Duck",stars=1,level=1}},holder.destination)
  local neutral=other.units[#other.units];neutral.x,neutral.z=holder.destination.X,holder.destination.Z
  release(service,3);assert(world.restored["1:1"]==1)
  service:Destroy();return "Only living player chickens suppress the garrison"
 end)
 test("Removing the holder transfers vacancy tracking to another physical army",function()
  local service,a,b,world=setup();local holder=holding(service,a,"camp:1",0)
  local other=crossing(service,b,holder.destination,"remaining-army")
  service:Remove(holder)
  assert(service.campBusy["1:1"]==other.id and service.departingCamps["1:1"]==other.id)
  release(service,3);assert(not world.restored["1:1"])
  leave(other);release(service,4);assert(world.restored["1:1"]==1)
  service:Destroy();return "Removing the original battle does not respawn beneath its replacement occupant"
 end)
 test("Disconnecting a holder retains another army's physical reservation",function()
  local service,a,b,world=setup();local holder=holding(service,a,"camp:1",0)
  local other=crossing(service,b,holder.destination,"remaining-after-disconnect")
  service:CancelPlayer(a.userId,2)
  assert(service.campBusy["1:1"]==other.id and not world.restored["1:1"])
  assert(a.firstWins[1] and service.battles[other.id]==other)
  leave(other);release(service,3);assert(world.restored["1:1"]==1)
  service:Destroy();return "Departing player loses ownership; surviving armies still keep the camp quiet"
 end)
 test("Removing the last battle still observes vacancy grace",function()
  local service,a,_,world=setup();local holder=holding(service,a,"camp:1",0)
  service:Remove(holder);assert(not world.restored["1:1"])
  service:ReleaseClearedCamps(3);assert(not world.restored["1:1"])
  service:ReleaseClearedCamps(3+Config.CampRespawnGrace+.01)
  assert(world.restored["1:1"]==1 and not service.campBusy["1:1"])
  service:Destroy();return "An expired reservation safely waits for the same vacancy check"
 end)
 test("King garrison returns after departure while its first win survives",function()
  local service,a,_,world=setup()
  for index=1,2 do service:SetTerritoryOwner("1:"..index,a,{plot=1,index=index,position=world:CampPosition(index,1)}) end
  local king=holding(service,a,"king:1",0)
  assert(king.isKing and a.kingCleared and king:Alive("B")==0)
  assert(service:ReturnHome(a,2));release(service,3);assert(not world.restored["king:1"])
  leave(king);release(service,4)
  assert(not service.campOwners["king:1"] and world.restored["king:1"]==1 and a.kingCleared)
  service:Destroy();return "King uses the same physical vacancy rule without erasing its earned win"
 end)
 test("Supply Outpost keeps its distinct persistent ownership rule",function()
  local service,a,_,world=setup();local location={income=true,position=world:IncomeFrame().Position}
  service:SetTerritoryOwner("income:1",a,location)
  service.campLocations["income:1"]=location;service.campBusy["income:1"]="departed"
  service:ReleaseCamp("income:1")
  assert(service.campOwners["income:1"].userId==a.userId and not world.restored["income:1"])
  service:Destroy();return "Ordinary camp reset does not change the separate income territory contract"
 end)
 return results
end
return Checks
