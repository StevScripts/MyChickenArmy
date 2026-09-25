assert(workspace:GetAttribute("PetRollPlaytestSessionOnly")==true)
local Actor=require(game.ServerStorage.PetRoll.PetActor)
local Shared=game.ReplicatedStorage.PetRoll.Shared
local View=require(Shared.PetView)
local f=Instance.new("Folder");f.Name="ChickenBumpChecks";f.Parent=workspace
local jobs={}
local function part(name,size,cf)
 local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.Size=size;p.CFrame=cf;p.Parent=f;return p
end
local specs={
 {name="0.30 stud step",h=.3}, {name="0.60 stud step",h=.6},
 {name="Slow 0.60 step",h=.6,speed=4}, {name="Fast 0.60 step",h=.6,speed=16},
 {name="Angled 0.45 ridge",h=.45,ridge=true}, {name="Thin 0.20 ridge",h=.2,ridge=true},
 {name="Mallard 0.60 step",h=.6,species="Mallard"}, {name="Level 10 0.60 step",h=.6,level=10},
 {name="Low overhang",h=0,ceiling=true}, {name="Tall wall stays solid",h=3,wall=true}
}
for i,s in specs do
 local z=2100+i*14
 part("Floor",Vector3.new(40,2,12),CFrame.new(1800,0,z))
 local obstacle=part("Obstacle",Vector3.new(if s.ridge then .4 else 14,s.h>0 and s.h or .05,12),CFrame.new(1807,1+s.h/2,z)*(if s.ridge then CFrame.Angles(0,.35,0) else CFrame.identity))
 if s.h==0 then obstacle:Destroy() end
 if s.ceiling then part("Ceiling",Vector3.new(14,1,12),CFrame.new(1807,4.15,z)) end
 local start=Vector3.new(1794,1.05,z)
 local a=Actor.new(f,s.name,s.species or "Duck",1,start);View.Level(a.model,s.level or 1)
 a:MoveTo(Vector3.new(1810,1+(if s.ridge then 0 else s.h),z),s.speed or 8)
 table.insert(jobs,{a=a,s=s,start=start,stage=1,jumps=0,groundError=0,maxX=1794})
end
local routeStart=Vector3.new(303.0,2.36,-171.3)
local routeEnd=Vector3.new(309.0,2.661,-175.0)
local a=Actor.new(f,"Authored yard lip","Duck",1,routeStart);View.Level(a.model,1);a:MoveTo(routeEnd,8)
table.insert(jobs,{a=a,s={name="Authored yard lip"},start=routeStart,stage=1,jumps=0,groundError=0,maxX=303})
_G.ChickenBumpChecks={done=false}
task.spawn(function()
 local ok,err=xpcall(function()
 local began=os.clock()
 while os.clock()-began<11 do
  local active=false
  for _,j in jobs do if not j.done then
   active=true
   local s=j.a:Step(os.clock());local p=j.a:Position()
   j.maxX=math.max(j.maxX,p.X)
   if j.a.humanoid:GetState()==Enum.HumanoidStateType.Jumping then j.jumps+=1 end
   if s=="arrived" then
    if j.stage==1 then j.outTime=os.clock()-began;j.stage=2;j.a:MoveTo(j.start,j.s.speed or 8)
    else j.done=true;j.time=os.clock()-began end
   end
   if j.s.wall and os.clock()-began>=4 then j.done=true;j.wallBlocked=p.X<1800;j.time=os.clock()-began end
  end end
  if not active then break end
  task.wait(.03)
 end
 task.wait(.2)
 local results={}
 for _,j in jobs do
  local p=j.a:Position()
  local ray=RaycastParams.new();ray.FilterDescendantsInstances={f};ray.FilterType=Enum.RaycastFilterType.Include;ray.CollisionGroup="DuckActors";ray.RespectCanCollide=true
  if j.s.name=="Authored yard lip" then ray.FilterType=Enum.RaycastFilterType.Exclude;ray.FilterDescendantsInstances={f} end
  local hit=workspace:Raycast(p+Vector3.yAxis*2,-Vector3.yAxis*4,ray)
  local e=hit and p.Y-hit.Position.Y or 99
  local recovery=j.a.model:GetAttribute("RecoveryCount") or 0
  local passed=j.done==true and j.jumps==0 and recovery==0 and math.abs(e)<.12 and (not j.s.wall or j.wallBlocked)
  table.insert(results,{name=j.s.name,passed=passed,roundTrip=j.stage==2 and j.done,wallBlocked=j.wallBlocked,duration=j.time,outwardTime=j.outTime,jumps=j.jumps,recoveries=recovery,settledFootError=e,position=tostring(p),clearance=j.a.humanoid.HipHeight})
 end
 _G.ChickenBumpChecks={done=true,results=results}
 end,debug.traceback)
 for _,j in jobs do j.a:Destroy() end
 f:Destroy()
 if not ok then _G.ChickenBumpChecks={done=true,error=err} end
end)
return "11 final geometry and authored-yard walking checks started"
