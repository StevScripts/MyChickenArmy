-- Isolated real-module fixtures; no live players, DataStore, map or remotes.
local cache={}
local function fresh(module)
 if cache[module]~=nil then return cache[module] end
 local chunk,why=loadstring(module.Source,"="..module:GetFullName())
 assert(chunk,why)
 local env=setmetatable({script=module,require=fresh},{__index=getfenv()})
 setfenv(chunk,env)
 local result=chunk();cache[module]=result;return result
end
local Server=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Battle=fresh(Server.Battle)
local Session=fresh(Server.PlayerSession)
local Service=fresh(Server.BattleService)
local Config=fresh(Shared.Config)
local Builder=fresh(Server.WorldBuilder)
local results={}
local function test(name,fn)
 local ok,why=pcall(fn)
 table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
end
local function encounter(target)
 local b=Battle.new("fixture",-106,"camp:1",Vector3.zero,Vector3.zero,0)
 b.target=target or "camp:1";b.name="Cluck Camp";b.phase="Fight"
 b:AddArmy("A",{{id="owned",species="Duck",stars=1,level=1}},Vector3.zero)
 b:AddArmy("B",{{species="Duck",stars=1,level=1}},Vector3.zero)
 for _,u in b.units do u.x,u.z=0,0;u.nextAttack=math.huge end
 return b
end
local function owned()
 local s=Session.new(-106,"Conquest fixture",1);s.loaded=true
 local world={owners={},busy={},spawns={}}
 function world:Position() return Vector3.new(10000,1,-100) end
 function world:CampPosition(i) return Vector3.new(10000,1,i*80) end
 function world:CampFrame(i) return CFrame.new(self:CampPosition(i)) end
 function world:ReturnPosition(_,_,slot) return self:Position()+Vector3.new(slot*3,0,0) end
 function world:Populate(i) if not self.busy[i] and not self.owners[i] then self.spawns[i]=(self.spawns[i] or 0)+1 end end
 function world:SetCampBusy(i,busy) self.busy[i]=busy;self:Populate(i) end
 function world:SetTerritoryOwner(location,userId) self.owners[location.index]=userId;self:Populate(location.index) end
 local service=Service.new({[s.userId]=s},world)
 assert(service:Attack(s,"camp:1",0))
 local b=service.battles[s.outgoing]
 b.captureElapsed=b:CaptureDuration()
 for _,u in b.units do if u.side=="A" then u.x,u.z=b.destination.X,b.destination.Z;u.marchPath=nil end end
 service:Finish(b,"A",1)
 return s,service,world,b
end
test("one 25-second conquest meter; legacy contest duration stays eight",function()
 assert(encounter():CaptureDuration()==25)
 assert(encounter("income:1"):CaptureDuration()==8)
 local b=encounter();b.operationId="fixture";assert(b:CaptureDuration()==8)
 assert(encounter("king:1"):CaptureDuration()==25 and encounter("outpost:1"):CaptureDuration()==25)
end)
test("physical troops advance conquest during a live fight",function()
 local b=encounter();assert(b:StepSimulation(.1,.1)==nil)
 assert(b.phase=="Fight" and b.captureStarted and b.captureElapsed==.1 and b.capturers==1)
 local snap=b:Snapshot(.1);assert(snap.conquest and not snap.capturePaused and snap.captureActive)
end)
test("avatar/absent/reinforcing/retiring/dead birds cannot capture",function()
 for _,kind in {"absent","reinforcing","retiring","dead"} do
  local b=encounter();local u=b.units[1]
  if kind=="absent" then u.x=100 elseif kind=="dead" then u.hp=0 else u[kind]=true end
  b:StepConquest(5);assert(b.captureElapsed==0 and b.capturers==0,kind)
 end
end)
test("leaving the radius pauses without erasing progress",function()
 local b=encounter();b:StepConquest(6);b.units[1].x=100;b:StepConquest(4)
 assert(b.captureElapsed==6 and b:Snapshot(10).capturePaused)
 b.units[1].x=0;b:StepConquest(1);assert(b.captureElapsed==7)
end)
test("full meter cannot bypass surviving defenders",function()
 local b=encounter();assert(b:StepConquest(30)==nil and b.captureElapsed==25)
 b.units[2].hp=0;assert(b:StepConquest(0)=="A")
end)
test("a cleared base completes at the exact server threshold",function()
 local b=encounter();b.units[2].hp=0;b:BeginCapture(0)
 assert(b:StepCapture(24.9,24.9)==nil and b.captureElapsed==24.9)
 assert(b:StepCapture(.1,25)=="A" and b.captureElapsed==25)
end)
test("research accelerates the continuous meter",function()
 local b=encounter();b.researchBySide={A={capture=.25}}
 b:StepConquest(10);assert(b.captureElapsed==12.5 and b:CaptureRemaining()==10)
end)
test("respawning defenders preserve progress and keep combat authoritative",function()
 local b=encounter();b.captureElapsed=10;b:BeginCapture(0)
 local enemy=b.units[2];enemy.hp=0;enemy.respawnAt=1
 b:StepDefenderSpawns(1)
 assert(enemy.hp>0 and b.phase=="Fight" and b.captureElapsed==10)
 b:StepConquest(1);assert(b.captureElapsed==11)
end)
test("loss recovery remains gradual and keeps recent damage receipts",function()
 local b=encounter();b.captureElapsed=12.5;b:Finish("B",0);b:StepEnemyReclaim(2)
 local snap=b:Snapshot(2);assert(snap.captureProgress==.25 and snap.enemyControl==.75)
 assert(snap.units[1].damageSerial==0)
end)
test("legacy contests still pause capture for defenders",function()
 local b=encounter("income:1");b.incomeSite=true;b.captureElapsed=2;b.captureStarted=true
 b:StepSimulation(.1,.1);assert(b.captureElapsed==2 and b:Snapshot(.1).capturePaused)
end)
test("capture awards the existing Cluck milestone and is repeat-safe",function()
 local s,service,_,b=owned();local coins=s.coins
 assert(s.firstWins[1] and s:MergeAccess() and b.phase=="Holding")
 service:Finish(b,"A",2);assert(s.coins==coins)
 assert(s.lastResult=="You've conquered Cluck Camp!")
end)
test("moving away preserves the owner and suppresses the garrison",function()
 local s,service,world=owned()
 assert(service:RecallForCommand(s,2,false))
 service:ReleaseClearedCamps(2);service:ReleaseClearedCamps(5)
 assert(service.campOwners["1:1"].userId==s.userId and world.owners[1]==s.userId and not world.spawns[1])
end)
test("stationing at an owned base carries full progress without another capture",function()
 local s,service=owned();assert(service:RecallForCommand(s,2,false))
 service:ReleaseClearedCamps(2);service:ReleaseClearedCamps(5)
 s.armyState="Home";s.outgoing=nil;s.awayPets={}
 assert(service:Attack(s,"camp:1",6));local b=service.battles[s.outgoing]
 assert(b.friendlyTerritory and b.captureElapsed==25 and b:Snapshot(6).friendlyTerritory)
end)
test("unclaim restores defenders and resets capture while keeping exact player lives",function()
 local s,service,_,b=owned();local unit=b.units[1];unit.hp-=1
 local hp,x,z=unit.hp,unit.x,unit.z;local petCount=s:Count();local coins=s.coins
 assert(service:Unclaim(s,"camp:1",2))
 assert(b.phase=="Fight" and b.captureElapsed==0 and not b.captureStarted and b:Alive("B")>0)
 assert(b.units[1]==unit and unit.hp==hp and unit.x==x and unit.z==z)
 assert(s:Count()==petCount and s.coins==coins and s.firstWins[1] and s:MergeAccess())
 assert(not service.campOwners["1:1"] and not service:Unclaim(s,"camp:1",2))
end)
test("unclaim rejects a foreign owner and malformed targets",function()
 local s,service=owned();local foreign=Session.new(-107,"Other",1)
 assert(not service:Unclaim(foreign,"camp:1",2))
 assert(not service:Unclaim(s,{},2) and not service:Unclaim(s,"camp:99",2))
end)
test("owned marker is persistent native text with a clean release",function()
 local model=Instance.new("Model")
 local ok,why=pcall(function()
  model:SetAttribute("CampName","Cluck Camp")
  local title=Builder.Billboard(model,"Title",Vector3.zero,"Cluck Camp",Color3.new(1,1,1))
  Builder.ApplyCampOwnership(model,CFrame.new(0,1.2,0),-106,"Fixture")
  assert(model:GetAttribute("Conquered") and model.OwnershipFlag.Owner.Label.Text.Text=="⚔ Conquered ⚔")
  assert(model.OwnershipFlag.Owner.Label.OwnerName.Text=="Fixture")
  assert(model.OwnershipFlag.Owner.Label.CampName.Text=="Cluck Camp" and not title.Parent.Enabled)
  Builder.ApplyCampOwnership(model,CFrame.new(),nil,nil)
  assert(not model:GetAttribute("Conquered") and not model:FindFirstChild("OwnershipFlag") and title.Parent.Enabled)
  model:SetAttribute("Occupied",true);Builder.ApplyCampTitle(model);assert(not title.Parent.Enabled)
  model:SetAttribute("Occupied",false);Builder.ApplyCampTitle(model);assert(title.Parent.Enabled)
 end)
 model:Destroy();assert(ok,why)
end)
return results
