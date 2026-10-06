local RunService=game:GetService("RunService")
local source=game.ReplicatedStorage.GalaxyCrateChickenAssets20261002.DragonChickenFlight
local clone=source:Clone() clone.Name="DragonAttackRuntimeCheck" clone:PivotTo(CFrame.new(440,3,-42)*CFrame.Angles(0,math.pi,0))
for _,o in clone:GetDescendants() do if o:IsA("ParticleEmitter") or o:IsA("Light") or o:IsA("Beam") or o:IsA("Trail") then o.Enabled=false end end
clone.Parent=workspace
local camera=workspace.CurrentCamera camera.CameraType=Enum.CameraType.Scriptable
camera.CFrame=CFrame.lookAt(Vector3.new(453,10,-19),Vector3.new(440,7,-42))
local engine=require(game.Players.LocalPlayer.PlayerScripts.PetRoll.DuckAnimator).new(nil)
local function advance(seconds) local untilAt=os.clock()+seconds repeat RunService.RenderStepped:Wait() until os.clock()>=untilAt end
local result={}
local ok,err=pcall(function()
 advance(1)
 local rec=assert(engine.records[clone],"Dragon not discovered")
 local a=assert(rec.blender,"Dragon adapter absent")
 assert(a.ready,"Animation not ready")
 local flight=a.tracks.FlightLoop local attack=a.tracks.Attack
 assert(flight.Length>0 and attack.Length>0,"Published clips not loaded")
 result.loaded={flightLength=flight.Length,attackLength=attack.Length,flightPlaying=flight.IsPlaying}
 local initial=clone.DragonChickenMesh:FindFirstChild("FlightRoot",true).Transform
 advance(.18)
 result.flightChanges=(initial.Position-clone.DragonChickenMesh:FindFirstChild("FlightRoot",true).Transform.Position).Magnitude>0.00001
 clone:SetAttribute("AttackStartedAt",workspace:GetServerTimeNow()) clone:SetAttribute("AttackSerial",1)
 advance(.54)
 local root=clone.DragonChickenMesh:FindFirstChild("FlightRoot",true)
 result.contact={playing=attack.IsPlaying,time=attack.TimePosition,weight=attack.WeightCurrent,root={root.Transform.Position.X,root.Transform.Position.Y,root.Transform.Position.Z}}
 assert(attack.IsPlaying and attack.WeightCurrent>.95,"Attack did not replace flight")
 assert(math.abs(root.Transform.Position.X)<.001,"Sideways root displacement")
 advance(1.0)
 result.recovered={flightPlaying=flight.IsPlaying,flightSpeed=flight.Speed,attackPlaying=attack.IsPlaying,active=a.attackAt~=nil}
 assert(flight.IsPlaying and flight.Speed==1 and not attack.IsPlaying and not a.attackAt,"Failed flight recovery")
 clone:SetAttribute("AttackStartedAt",workspace:GetServerTimeNow()) clone:SetAttribute("AttackSerial",2)
 advance(.3)
 result.retriggerWeight=attack.WeightCurrent assert(attack.IsPlaying and attack.WeightCurrent>.95,"Retrigger faded out")
 engine:SetReducedMotion(true) advance(.2)
 clone:SetAttribute("AttackStartedAt",workspace:GetServerTimeNow()) clone:SetAttribute("AttackSerial",3)
 advance(.05)
 result.reduced={flightStopped=not flight.IsPlaying,attackStopped=not attack.IsPlaying}
 engine:SetReducedMotion(false) advance(.25)
 result.reducedResume={flight=flight.IsPlaying,attack=attack.IsPlaying}
 assert(flight.IsPlaying and not attack.IsPlaying,"Reduced event replayed")
 clone:SetAttribute("AttackStartedAt",workspace:GetServerTimeNow()-3) clone:SetAttribute("AttackSerial",4)
 advance(.1) result.staleSkipped=not attack.IsPlaying assert(result.staleSkipped,"Stale event played")
 clone.DragonChickenMesh.LocalTransparencyModifier=1 advance(.2)
 result.hiddenStopped=not flight.IsPlaying
 clone.DragonChickenMesh.LocalTransparencyModifier=0 advance(.2)
 result.visibleResumed=flight.IsPlaying
 local animator=clone.AnimationController.Animator
 engine:Destroy() advance(.1)
 result.cleaned=#animator:GetPlayingAnimationTracks()==0
 assert(result.cleaned,"Tracks leaked")
end)
engine:Destroy() clone:Destroy()
result.ok=ok result.error=if ok then nil else tostring(err)
return result