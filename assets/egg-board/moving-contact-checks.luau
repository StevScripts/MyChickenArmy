-- Supply current disk sources through SOURCES; no world, profile, or purchase mutations.
local passed={}
local function check(name,condition) assert(condition,name);table.insert(passed,name) end
local function load(source,environment)
 local chunk=assert(loadstring(source))
 setfenv(chunk,setmetatable(environment,{__index=getfenv()}))
 return chunk()
end
local Eggs=load(SOURCES.server,{script=game.ServerStorage.PetRoll.EggService,require=function(module)
 return if module.Name=="EggProcessorConfig" then {MaxValue=1e12} else {}
end})
local pad={Position=Vector3.zero,Size=Vector3.new(10,1,10),CFrame=CFrame.new()}
function pad:IsA(name) return name=="BasePart" end
local service=Eggs.new({})
function service:Board() return {FindFirstChild=function() return {FindFirstChild=function() return pad end} end} end
local session={userId=1,pets={},coins=0,eggProcessor={readyValue=100},tutorial={}}
function session:RetireEggSeller() end
function session:EarnedAmount(value) return value end
function session:Credit(value) self.coins+=value;return value end
local center=Vector3.new(0,3,0)
local function tick(now,velocity,grounded,position)
 service:ProcessAndClaim(session,position or center,0.1,now,grounded~=false,velocity)
end
tick(1,Vector3.zero)
check("stationary entry preserves ready cash",session.coins==0 and session.eggProcessor.readyValue==100)
tick(2,Vector3.new(0,5,0));tick(3,Vector3.new(0.2,0,0.2));tick(4,nil)
check("vertical travel, jitter and missing velocity do not collect",session.coins==0)
tick(5,Vector3.new(2,0,0))
check("moving on pad collects",session.coins==100 and session.eggProcessor.readyValue==0)
session.eggProcessor.readyValue=20
tick(5.5,Vector3.new(2,0,0))
check("movement cannot bypass cooldown",session.coins==100)
tick(6,Vector3.zero);tick(20,Vector3.zero)
check("staying still never auto-collects new cash",session.coins==100 and session.eggProcessor.readyValue==20)
tick(21,Vector3.new(0,0,-2))
check("resuming movement collects",session.coins==120)
session.eggProcessor.readyValue=30
tick(23,Vector3.new(2,0,0),false)
tick(24,Vector3.new(2,0,0),true,center+Vector3.new(20,0,0))
check("airborne or outside pad cannot collect",session.coins==120 and session.eggProcessor.readyValue==30)
tick(25,Vector3.new(-2,0,0));tick(27,Vector3.new(-2,0,0))
check("ready cash pays once",session.coins==150 and service:Yard(session).cashSerial==3)

local fakeTween={Create=function(_,target,_,goals)
 return {Play=function() for key,value in goals do target[key]=value end end,Cancel=function() end,Destroy=function() end}
end}
local fakeGame={GetService=function(_,name) return if name=="TweenService" then fakeTween else game:GetService(name) end}
local Board=load(SOURCES.client,{game=fakeGame,script=game.StarterPlayer.StarterPlayerScripts.PetRoll.EggProcessorController,
 require=function() return {} end,workspace={Raycast=function() return {Instance=pad} end}})
pad.Parent=true;pad.Color=Color3.new(0,1,0)
local controller={app={state={plotIndex=1,eggs={processor={enabled=true,readyCash=50}}}},groundRay={}}
local view={pad=pad,padFrame=CFrame.new(),padColor=pad.Color,index=1}
local root={AssemblyLinearVelocity=Vector3.zero,Position=center,Size=Vector3.new(2,2,1),Parent={},CollisionGroup="Default"}
local humanoid={Health=100,Jump=false,Sit=false,PlatformStand=false,FloorMaterial=Enum.Material.Plastic,HipHeight=2,
 GetState=function() return Enum.HumanoidStateType.Running end}
Board.UpdatePad(controller,view,root,humanoid)
check("stationary pad animation stays released",view.pressed==false)
root.AssemblyLinearVelocity=Vector3.new(2,0,0)
Board.UpdatePad(controller,view,root,humanoid)
check("moving pad animation presses",view.pressed==true)
root.AssemblyLinearVelocity=Vector3.new(0,2,0)
Board.UpdatePad(controller,view,root,humanoid)
check("stopping horizontally releases animation",view.pressed==false)
root.AssemblyLinearVelocity=Vector3.new(2,0,0);controller.app.reducedMotion=true
Board.UpdatePad(controller,view,root,humanoid)
check("reduced motion keeps pad still",view.pressed==false)
return passed
