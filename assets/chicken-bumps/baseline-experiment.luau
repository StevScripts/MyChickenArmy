assert(workspace:GetAttribute("PetRollPlaytestSessionOnly")==true)
local Actor=require(game.ServerStorage.PetRoll.PetActor)
local View=require(game.ReplicatedStorage.PetRoll.Shared.PetView)
local f=Instance.new("Folder");f.Name="BumpExperiment";f.Parent=workspace
local jobs={}
local function part(name,size,pos)
 local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.Size=size;p.Position=pos;p.Parent=f;return p
end
for i,h in {0.2,0.3,0.45,0.6,0.8,1.5} do
 for k,raised in {false,true} do
  local z=1800+(i*2+k)*12
  part("Floor",Vector3.new(30,2,10),Vector3.new(1800,0,z))
  part("Step",Vector3.new(12,h,10),Vector3.new(1806,1+h/2,z))
  local a=Actor.new(f,"Trial"..i.."_"..k,"Duck",1,Vector3.new(1794,1.05,z));View.Level(a.model,1)
  if raised then
   local d=a.model:GetAttribute("Size")*.3
   for _,j in a.root:GetChildren() do if j:IsA("Motor6D") then j.C0=CFrame.new(0,-d,0)*j.C0 end end
   a.root.CFrame+=Vector3.new(0,d,0)
   a.model:SetAttribute("FootOffset",a.model:GetAttribute("FootOffset")+d);a.footOffset=a.model:GetAttribute("FootOffset")
   a.humanoid.HipHeight+=d
  end
  a:MoveTo(Vector3.new(1809,1+h,z),8)
  table.insert(jobs,{a=a,h=h,raised=raised,minY=math.huge,maxY=-math.huge,jumps=0})
 end
end
_G.BumpExperiment={done=false}
task.spawn(function()
 local start=os.clock()
 while os.clock()-start<6 do
  for _,j in jobs do if not j.done then local a=j.a;local s=a:Step(os.clock());local p=a:Position()
   j.minY=math.min(j.minY,p.Y);j.maxY=math.max(j.maxY,p.Y)
   if a.humanoid:GetState()==Enum.HumanoidStateType.Jumping then j.jumps+=1 end
   if s=="arrived" then j.done=true;j.duration=os.clock()-start end
  end end
  task.wait(.05)
 end
 local r={}
 for _,j in jobs do table.insert(r,{step=j.h,raised=j.raised,arrived=j.done==true,duration=j.duration,x=j.a:Position().X,minY=j.minY,maxY=j.maxY,jumps=j.jumps,recovery=j.a.model:GetAttribute("RecoveryCount") or 0});j.a:Destroy() end
 f:Destroy();_G.BumpExperiment={done=true,results=r}
end)
return "started 12 isolated baseline/raised-collider walking lanes"
