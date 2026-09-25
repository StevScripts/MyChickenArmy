--!strict
-- Isolated live-physics faults. No real pets, profiles, purchases or rewards.
local Server=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local PetActor=require(Server.PetActor)
local Live=require(Server.LiveBattleActors)
local Battle=require(Server.Battle)
local World=require(Server.WorldService)
local PetView=require(Shared.PetView)
local KingVisual=require(Shared.KingVisual)
local Checks={}
function Checks.Run()
 assert(game:GetService("RunService"):IsRunning(),"Run in session-only Studio Play")
 assert(workspace:GetAttribute("PetRollPlaytestSessionOnly")==true)
 local folder=Instance.new("Folder");folder.Name="ChickenRecoveryFixture";folder.Parent=workspace
 local actors,results={},{}
 local origin=Vector3.new(1800,1.05,1800)
 local function part(name,size,at)
  local p=Instance.new("Part");p.Name,p.Size,p.Position=name,size,at;p.Anchored=true;p.Parent=folder;return p
 end
 part("Ground",Vector3.new(220,2,220),origin-Vector3.yAxis)
 local function actor(name,offset)
  local a=PetActor.new(folder,name,"Duck",1,origin+(offset or Vector3.zero));table.insert(actors,a);return a
 end
 local function test(name,fn)
  local ok,why=xpcall(fn,debug.traceback);table.insert(results,{name=name,passed=ok,detail=if ok then nil else tostring(why)})
 end
 local function count(name,parent)
  local n=0;for _,v in (parent or folder):GetChildren() do if v.Name==name then n+=1 end end;return n
 end
 local function fault(name,damage)
  test(name,function()
   local a=actor(name);PetView.Level(a.model,4);a.model:SetAttribute("PetId","owned-1");a.model:SetAttribute("AtHome",true)
   task.wait(.15);a:Step(os.clock());local old=a.model;local scale=old:GetScale()
   damage(a);a:Step(os.clock());task.wait(.05)
   assert(a.model~=old and old.Parent==nil,"Broken model was not replaced")
   assert(a:RigIssue()==nil,"Replacement is not healthy: "..tostring(a:RigIssue()))
   assert(a.model:GetAttribute("PetId")=="owned-1" and a.model:GetAttribute("Level")==4,"Identity/level lost")
   assert(math.abs(a.model:GetScale()-scale)<.001,"Growth changed")
   assert(count(name)==1,"Duplicate physical chicken")
   assert(a.root:GetNetworkOwner()==nil,"Repair lost server physics ownership")
   assert((a:Position()-origin).Magnitude<2,"Repair advanced the route")
   a:Destroy()
  end)
 end
 local fatal,why=xpcall(function()
  fault("Idle Humanoid death",function(a)a.humanoid.Health=0 end)
  fault("Deleted whole model",function(a)a.model:Destroy() end)
  fault("Detached whole model",function(a)a.model.Parent=nil end)
  fault("Deleted root",function(a)a.root:Destroy() end)
  fault("Deleted Humanoid",function(a)a.humanoid:Destroy() end)
  fault("Deleted visual body",function(a)a.body:Destroy() end)
  fault("Anchored chicken",function(a)a.root.Anchored=true end)
  fault("Idle fall below map",function(a)a.model:PivotTo(a.root.CFrame-Vector3.new(0,35,0)) end)
  test("Physics fling returns to previous ground",function()
   local a=actor("Fling");a:Step(os.clock());local old=a.model
   a.model:PivotTo(a.root.CFrame+Vector3.new(60,0,0));a.healthAt=os.clock()-.6;a:Step(os.clock())
   assert(a.model~=old and (a:Position()-origin).Magnitude<2);a:Destroy()
  end)
  test("King crown, scale and metadata survive repair",function()
   local a=actor("King",Vector3.new(-45,0,0));KingVisual.Apply(a.model,3);PetView.Level(a.model,6)
   local scale=a.model:GetScale();a.humanoid.Health=0;a:Step(os.clock())
   assert(a.model:FindFirstChild("RoyalCrown") and a.model:GetAttribute("ChickenKing"))
   assert(math.abs(a.model:GetScale()-scale)<.001 and a.model:GetAttribute("Level")==6)
   a:Destroy()
  end)
  test("Transfer repairs into current owner, explicit Destroy never respawns",function()
   local other=Instance.new("Folder");other.Parent=folder
   local a=actor("Transferred");a:SetParent(other);a.model:Destroy();a:Step(os.clock())
   assert(a.model.Parent==other and count("Transferred",other)==1)
   a:Destroy();a:Destroy();assert(a:Step(os.clock())=="destroyed")
   assert(not a:Recover(origin,"must not resurrect") and count("Transferred",other)==0);other:Destroy()
  end)
  test("Combat HP, death timer and rewards remain authoritative",function()
   local b=Battle.new("FaultBattle",-1,"camp:1",origin,origin,os.clock());b.phase="Fight"
   b:AddArmy("A",{{id="pet-1",species="Duck",stars=1,level=2}},origin)
   local u=b.units[1];u.hp=7;local live=Live.new(folder,b);b.actors=live;live:Sync(os.clock());live:Publish(os.clock())
   local a=live.actors[u.id];a.humanoid.Health=0;live:Sync(os.clock());live:Publish(os.clock())
   assert(u.hp==7 and u.spawnSerial==0 and #b:DrainKills()==0,"Physical repair changed combat state")
   a.repairAt=0;u.hp=0;u.respawnAt=os.clock()+5;local timer=u.respawnAt;live:Publish(os.clock())
   a.model:Destroy();live:Sync(os.clock());live:Publish(os.clock())
   assert(u.hp==0 and u.respawnAt==timer and a.model:GetAttribute("Defeated"),"Early gameplay resurrection")
   b:StepReinforcements(.1,timer-.1);assert(u.hp==0)
   b:StepReinforcements(.1,timer+.1);assert(u.hp==u.maxHp and u.spawnSerial==1 and #b:DrainKills()==0)
   live:Destroy()
  end)
  test("Stuck home recruitment recovers to yard",function()
   local a=actor("Recruit",Vector3.new(15,0,0));local w=World.new()
   a:MoveTo(origin+Vector3.new(70,0,0),5);a:_block("Fixture wall")
   local home={position=a:Position(),target=origin+Vector3.new(70,0,0),moving=true,recruiting=true,startedAt=os.clock(),recoveryFoot=origin}
   w.plots[1]={index=1,stations={},actors={recruit=a},roaming={recruit=home},ownerId=-1}
   w:Step(os.clock());assert(not home.moving and not home.recruiting and (a:Position()-origin).Magnitude<2)
   assert(count("Recruit")==1);a:Destroy()
  end)
  test("Home detours keep progressing but still have a hard deadline",function()
   local a=actor("Detour");local now=os.clock();a:MoveTo(origin+Vector3.new(70,0,0),2.5)
   local home={position=origin,target=origin+Vector3.new(70,0,0),moving=true,recruiting=true,startedAt=now-20,travelTimeout=14,recoveryFoot=origin}
   local w=World.new();w.plots[1]={index=1,stations={},actors={detour=a},roaming={detour=home},ownerId=-1}
   w:Step(now);assert(home.moving and not a.model:GetAttribute("RecoveryCount"),"Healthy detour cancelled")
   home.startedAt=now-60;w.lastRoamAt=0;w:Step(now+.2)
   assert(not home.moving and a.model:GetAttribute("RecoveryReason")=="Home walk timed out","Hard deadline missing")
   a:Destroy()
  end)
  test("Wander destinations reject solid props and missing ground",function()
   local a=actor("Standability");local at=origin+Vector3.new(70,0,0)
   assert(a:CanStandAt(at));local wall=part("TargetObstruction",Vector3.new(4,6,4),at+Vector3.new(0,3,0))
   assert(not a:CanStandAt(at));assert(not a:CanStandAt(origin+Vector3.new(500,0,0)))
   wall:Destroy();a:Destroy()
  end)
  test("Invalid inputs do not poison movement",function()
   local a=actor("Inputs");assert(not a:MoveTo(Vector3.new(0/0,0,0),8));assert(not a:MoveTo(origin,math.huge))
   assert(not a:MoveTo(origin,0/0));a:Destroy()
  end)
  test("Normal walking does not teleport or falsely recover",function()
   local a=actor("Walking",Vector3.new(-35,0,-50));local target=origin+Vector3.new(-11,0,-50)
   a:MoveTo(target,8);local begin=os.clock();local previous=a:Position();local previousAt=begin;local state
   repeat task.wait(.05);local now=os.clock();state=a:Step(now)
    assert((a:Position()-previous).Magnitude<=8*(now-previousAt)*2+1,"Normal walk teleported")
    previous,previousAt=a:Position(),now
   until state=="arrived" or os.clock()-begin>8
   assert(state=="arrived" and not a.model:GetAttribute("RecoveryCount"),"Ordinary walk failed")
   a:Destroy()
  end)
  test("Closed route fails boundedly, then retries after obstruction opens",function()
   local at=origin+Vector3.new(35,0,45);local walls={}
   for _,sign in {-1,1} do
    table.insert(walls,part("WallX",Vector3.new(2,12,12),at+Vector3.new(sign*5,6,0)))
    table.insert(walls,part("WallZ",Vector3.new(12,12,2),at+Vector3.new(0,6,sign*5)))
   end
   local a=actor("Enclosed",at-origin);a:MoveTo(at+Vector3.new(24,0,0),8);local begin=os.clock();local state
   repeat task.wait(.1);state=a:Step(os.clock()) until state=="blocked" or os.clock()-begin>18
   assert(state=="blocked","Unreachable trip never yielded")
   assert(math.abs(a:Position().X-at.X)<5 and not a.model:GetAttribute("RecoveryCount"),"Teleported through walls")
   for _,wall in walls do wall:Destroy() end
   begin=os.clock()
   repeat task.wait(.1);state=a:Step(os.clock()) until state=="arrived" or os.clock()-begin>12
   assert(state=="arrived","Temporary blockage left permanent stall")
   a:Destroy()
  end)
 end,debug.traceback)
 for _,a in actors do a:Destroy() end;folder:Destroy()
 if not fatal then table.insert(results,{name="Fixture",passed=false,detail=tostring(why)}) end
 local passed=0;for _,r in results do if r.passed then passed+=1 end end
 return {passed=passed,total=#results,results=results}
end
return Checks
