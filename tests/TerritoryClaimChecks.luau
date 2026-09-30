-- Isolated sessions and stub worlds; no saved profiles, map edits or purchases.
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local Battles=require(Server.BattleService)
local Config=require(Shared.Config)
local Checks={}

local function setup()
 local s=Session.new(-929,"Territory fixture",1);s.loaded=true
 local world={owners={},busy={},spawns={}}
 function world:Position() return Vector3.new(10000,1,-100) end
 function world:CampPosition(i) return Vector3.new(10000,1,i*80) end
 function world:CampFrame(i) return CFrame.new(self:CampPosition(i)) end
 function world:ReturnPosition(_,_,slot) return self:Position()+Vector3.new(slot*3,0,0) end
 function world:Populate(i) if not self.busy[i] and not self.owners[i] then self.spawns[i]=(self.spawns[i] or 0)+1 end end
 function world:SetCampBusy(i,busy) self.busy[i]=busy;self:Populate(i) end
 function world:SetTerritoryOwner(location,userId) self.owners[location.index]=userId;self:Populate(location.index) end
 local service=Battles.new({[s.userId]=s},world)
 assert(service:Attack(s,"camp:1",0))
 local b=service.battles[s.outgoing]
 b.captureElapsed=Config.CaptureSeconds
 for _,u in b.units do if u.side=="A" then u.x,u.z=b.destination.X,b.destination.Z;u.marchPath=nil end end
 service:Finish(b,"A",1)
 return s,service,world,b
end

local function emptyCamp(service,s)
 assert(service:RecallForCommand(s,2,false))
 service:ReleaseClearedCamps(2);service:ReleaseClearedCamps(2+Config.CampRespawnGrace+.01)
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,why=pcall(fn);table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
 end
 test("Recall/Go Base departure leaves the conquered mark and no enemies",function()
  local s,service,world=setup();emptyCamp(service,s)
  assert(service.campOwners["1:1"].userId==s.userId and world.owners[1]==s.userId)
  assert(not service.campBusy["1:1"] and not world.spawns[1])
  service:StepTerritoryReclaims(100,100)
  assert(service.campOwners["1:1"] and s.firstWins[1])
 end)
 test("Empty base unclaims immediately but enemy control refills over eight seconds",function()
  local s,service,world=setup();emptyCamp(service,s)
  assert(service:Unclaim(s,"camp:1",5));assert(not service.campOwners["1:1"] and not world.owners[1])
  assert(world.spawns[1]==1 and s.firstWins[1])
  local first=service:Snapshots(5)[1];assert(first.territoryReclaim and first.enemyControl==0)
  service:StepTerritoryReclaims(Config.CaptureSeconds/2,9)
  local half=service:Snapshots(9)[1];assert(half.enemyControl==.5 and not half.enemyReclaimComplete)
  service:StepTerritoryReclaims(Config.CaptureSeconds/2,13)
  assert(service:Snapshots(13)[1].enemyControl==1)
  service:StepTerritoryReclaims(1,14);assert(#service:Snapshots(14)==0 and world.spawns[1]==1)
 end)
 test("Unclaim is ownership-checked, repeat-safe and independent of selected chickens",function()
  local s,service=setup();emptyCamp(service,s)
  local foreign=Session.new(-930,"Foreign",1)
  for _,id in {"camp:1","outpost:1","king:1","income:1","base:1","camp:99","garbage"} do
   assert(not service:Unclaim(foreign,id,5))
  end
  assert(not service:Unclaim(s,{},5))
  s.selected={};s.slots={}
  assert(service:Unclaim(s,"camp:1",5));assert(not service:Unclaim(s,"camp:1",5))
 end)
 test("Unclaim while stationed keeps exact player lives and restarts defender combat",function()
  local s,service,_,b=setup();local count=#b.units
  local u=b.units[1];u.hp=math.max(1,u.hp-2);local hp,x,z=u.hp,u.x,u.z
  local dead=b.units[2];dead.hp=0;dead.respawnAt=20
  assert(service:Unclaim(s,"camp:1",2))
  assert(service.battles[s.outgoing]==b and b.phase=="Fight" and not b.paid and b:Alive("B")>0)
  assert(b.units[1]==u and u.hp==hp and u.x==x and u.z==z and dead.hp==0 and dead.respawnAt==20)
  local players=0;for _,unit in b.units do if unit.side=="A" then players+=1 end end;assert(players==count)
  service:StepTerritoryReclaims(2,4);assert(b.captureElapsed==Config.CaptureSeconds-2)
  for _,unit in b.units do if unit.side=="B" then unit.hp=0;unit.respawnAt=nil end end
  service:StepTerritoryReclaims(0,4);assert(not service.territoryReclaims["1:1"])
  b:BeginCapture(4)
  assert(b:StepCapture(2,6)=="A");service:Finish(b,"A",6)
  assert(service.campOwners["1:1"].userId==s.userId and b.phase=="Holding")
 end)
 test("An army can return mid-reclaim without resetting the meter",function()
  local s,service=setup();emptyCamp(service,s);assert(service:Unclaim(s,"camp:1",5))
  service:StepTerritoryReclaims(3,8)
  assert(service:Attack(s,"camp:1",8));local b=service.battles[s.outgoing]
  assert(b.captureElapsed==Config.CaptureSeconds-3 and b:Alive("B")>0)
  local snapshots=service:Snapshots(8);assert(#snapshots==1 and snapshots[1].enemyControl==3/Config.CaptureSeconds)
  service:SetTerritoryOwner("1:1",s,service.campLocations["1:1"])
  service:StepTerritoryReclaims(100,108);assert(service.campOwners["1:1"] and not service.territoryReclaims["1:1"])
 end)
 test("Recall during released-base combat preserves the independent recovery",function()
  local s,service,world=setup();assert(service:Unclaim(s,"camp:1",2))
  service:StepTerritoryReclaims(2,4);emptyCamp(service,s)
  local reclaim=service.territoryReclaims["1:1"];assert(reclaim.captureElapsed==Config.CaptureSeconds-2)
  service:StepTerritoryReclaims(2,6);assert(reclaim.captureElapsed==Config.CaptureSeconds-4)
  assert(not service.campOwners["1:1"] and world.spawns[1]==1)
 end)
 test("Unclaiming a friendly destination during travel restores its defenders",function()
  local s,service=setup();emptyCamp(service,s);assert(service:Attack(s,"camp:1",5))
  local b=service.battles[s.outgoing];assert(b.friendlyTerritory and b:Alive("B")==0)
  assert(service:Unclaim(s,"camp:1",6))
  assert(b.phase=="Travel" and s.armyState=="Traveling" and b:Alive("B")>0 and not b.friendlyTerritory)
  service:StepTerritoryReclaims(2,8);assert(b.captureElapsed==Config.CaptureSeconds-2)
 end)
 test("Explicitly unclaimed ground refills after vacancy without waiting for the next destination",function()
  local s,service,world=setup();assert(service:Attack(s,"camp:2",2))
  local b=service.battles[s.outgoing]
  for _,u in b.units do if u.side=="A" then u.x,u.z=10060,120 end end
  assert(service:Unclaim(s,"camp:1",3))
  service:ReleaseClearedCamps(3);service:ReleaseClearedCamps(3+Config.CampRespawnGrace+.01)
  assert(not b.arrivedAt and not service.campBusy["1:1"] and world.spawns[1]==1)
  service:StepTerritoryReclaims(2,7)
  assert(service.territoryReclaims["1:1"].captureElapsed==Config.CaptureSeconds-2)
 end)
 test("Returning/empty armies still get the owner's unclaim action",function()
  local Controller=require(game:GetService("StarterPlayer").StarterPlayerScripts.PetRoll.BaseController)
  local s,service=setup();emptyCamp(service,s)
  local app={state={armyState="Returning",plotIndex=1,targets=service:Targets(s,4)},Counts=function() return 0,0,3,0,0 end}
  local c=Controller.new(app);local model={Parent=workspace}
  function model:GetAttribute(key) return if key=="CommandTarget" then "camp:1" elseif key=="LaneOwnerIndex" then 1 else nil end
  local command=c:CommandFor(model);assert(command.canUnclaim and not command.action)
  assert(service:Unclaim(s,"camp:1",5));app.state.targets=service:Targets(s,5)
  assert(c:CommandFor(model)==nil)
 end)
 test("Disconnect clears pending claims without touching earned wins",function()
  local s,service=setup();emptyCamp(service,s);assert(service:Unclaim(s,"camp:1",5))
  service:CancelPlayer(s.userId,6)
  assert(next(service.territoryReclaims)==nil and next(service.campOwners)==nil and s.firstWins[1])
 end)
 return results
end
return Checks
