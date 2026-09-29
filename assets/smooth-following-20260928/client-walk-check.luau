local Run=game:GetService("RunService")
local p=game.Players.LocalPlayer
local char=p.Character
local hum=char:FindFirstChildOfClass("Humanoid")
local root=char.HumanoidRootPart
local folder=workspace.PetRollWorld:FindFirstChild("FollowingArmy_"..p.UserId)
assert(folder and #folder:GetChildren()==3,"Call Army did not produce the selected three")
local records={}
for _,model in folder:GetChildren() do
	local part=model:FindFirstChild("HumanoidRootPart")
	records[model]={root=part,last=part.Position,speeds={},minDistance=math.huge}
end
local started=os.clock()
_G.FollowClientWalk={status="running",start=tostring(root.Position)}
Run:BindToRenderStep("FollowingWalkFixture",Enum.RenderPriority.Character.Value+1,function(dt)
	local age=os.clock()-started
	local direction=if age<5 then Vector3.new(-1,0,0) elseif age<8 then Vector3.new(0,0,1) else Vector3.zero
	hum:Move(direction,false)
	for model,r in records do
		local at=r.root.Position
		if age>2 and age<4.8 then
			local delta=(at-r.last)*Vector3.new(1,0,1)
			table.insert(r.speeds,delta.Magnitude/math.max(dt,0.001))
		end
		r.last=at
	end
	if age>=11 then
		Run:UnbindFromRenderStep("FollowingWalkFixture");hum:Move(Vector3.zero,false)
		local out={}
		for model,r in records do
			local sum=0;local stops=0;for _,v in r.speeds do sum+=v;if v<4 then stops+=1 end end
			local mean=sum/#r.speeds;local variance=0;for _,v in r.speeds do variance+=(v-mean)^2 end
			table.insert(out,{id=model.Name,samples=#r.speeds,meanClientSpeed=mean,clientSpeedDeviation=math.sqrt(variance/#r.speeds),
				nearStopSamples=stops,playerDistance=((r.root.Position-root.Position)*Vector3.new(1,0,1)).Magnitude,
				recoveryCount=model:GetAttribute("RecoveryCount") or 0,blocked=model:GetAttribute("MovementBlocked"),
				endSpeed=(r.root.AssemblyLinearVelocity*Vector3.new(1,0,1)).Magnitude})
		end
		_G.FollowClientWalk={status="done",followers=out,finish=tostring(root.Position)}
	end
end)
return {status="started",seconds=11}
