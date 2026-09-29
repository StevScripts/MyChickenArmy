-- Disposable physical rigs on a remote floor; no player inventory or saves.
local RunService=game:GetService("RunService")
local Actor=require(game.ServerStorage.PetRoll.PetActor)
local PetView=require(game.ReplicatedStorage.PetRoll.Shared.PetView)
local Checks={}
function Checks.Run(BaselineActor)
	local folder=Instance.new("Folder");folder.Name="FollowingPhysicsFixture";folder.Parent=workspace
	local floor=Instance.new("Part");floor.Name="FixtureGround";floor.Size=Vector3.new(500,2,500)
	floor.Anchored=true;floor.Position=Vector3.new(10000,0,0);floor.Parent=folder
	local obstacle=Instance.new("Part");obstacle.Name="FixtureProp";obstacle.Size=Vector3.new(2,8,45)
	obstacle.Anchored=true;obstacle.Position=Vector3.new(10045,5,0);obstacle.CollisionGroup="DuckScenery";obstacle.Parent=folder
	local actors={};local results={};local metrics={}
	local function check(name,fn)
		local ok,why=pcall(fn);table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
	end
	local ok,why=xpcall(function()
		for index,spec in {{name="ordinary",giant=nil},{name="colossal",giant=27.5},{name="baseline",baseline=true}} do
			local class=if spec.baseline then BaselineActor else Actor
			local foot=Vector3.new(10000,1,(index-2)*15)
			local actor=class.new(folder,"Follow_"..spec.name,"Duck",1,foot)
			if spec.giant then PetView.Level(actor.model,2,spec.giant) end
			actors[index]={actor=actor,original=actor.model,spec=spec,foot=foot,nextCommand=0,speeds={},errors={},stops=0}
		end
		local started=os.clock()
		while os.clock()-started<8 do
			RunService.Heartbeat:Wait();local now=os.clock();local age=now-started
			for _,r in actors do
				local goal=r.foot+Vector3.new(math.min(age,6)*16,0,0)
				local leader=if age<6 then Vector3.new(16,0,0) else Vector3.zero
				if r.spec.baseline then
					if now>=r.nextCommand then
						r.nextCommand=now+0.2;r.actor:Step(now)
						if (r.actor:Position()-goal).Magnitude>2 then r.actor:MoveTo(goal,22) else r.actor:Stop() end
					end
				else r.actor:Follow(goal,leader,24);r.actor:Step(now) end
				if age>2 and age<6 then
					local speed=r.actor.root.AssemblyLinearVelocity*Vector3.new(1,0,1)
					table.insert(r.speeds,speed.Magnitude);table.insert(r.errors,(r.actor:Position()-goal).Magnitude)
					if speed.Magnitude<4 then r.stops+=1 end
				end
			end
		end
		for _,r in actors do
			local mean=0;for _,v in r.speeds do mean+=v end;mean/=#r.speeds
			local variance=0;for _,v in r.speeds do variance+=(v-mean)^2 end;variance/=#r.speeds
			metrics[r.spec.name]={meanSpeed=mean,speedDeviation=math.sqrt(variance),stopSamples=r.stops,samples=#r.speeds,
				endError=(r.actor:Position()-(r.foot+Vector3.new(96,0,0))).Magnitude,
				endSpeed=(r.actor.root.AssemblyLinearVelocity*Vector3.new(1,0,1)).Magnitude,
				recovery=r.actor.model:GetAttribute("RecoveryCount") or 0}
		end
		check("Following ordinary and Colossal rigs sustain walking without stop cycles",function()
			for _,name in {"ordinary","colossal"} do
				local m=metrics[name];assert(m.meanSpeed>14 and m.stopSamples==0,name.." interrupted walking")
				assert(m.speedDeviation<metrics.baseline.speedDeviation*0.7,name.." did not reduce speed variation")
			end
		end)
		check("Followers settle near their slots without recovery or replacing rigs",function()
			for index=1,2 do local r=actors[index];local m=metrics[r.spec.name]
				assert(m.endError<1.25 and m.endSpeed<0.5,r.spec.name.." failed to settle: "..m.endError)
				assert(m.recovery==0 and r.actor.model==r.original,"Unexpected recovery/replacement")
			end
		end)
		check("Props are crossed while the floor still supports both follower sizes",function()
			for index=1,2 do local r=actors[index]
				assert(r.actor:Position().X>10080 and math.abs(r.actor:Position().Y-1)<0.75)
				assert(r.actor.root:GetNetworkOwner()==nil,"Lost server physics ownership")
			end
		end)
		local actor=actors[1].actor
		check("Invalid follow input cannot corrupt the live goal",function()
			local goal=actor.goal;assert(not actor:Follow(Vector3.new(0/0,0,0),Vector3.zero,24));assert(actor.goal==goal)
		end)
		check("Stop and ordinary movement immediately release follow steering",function()
			actor:Stop();assert(not actor.followMotion and actor.goal==nil and actor.humanoid.WalkSpeed==0)
			actor:Follow(actor:Position()+Vector3.new(10,0,0),Vector3.zero,24)
			actor:MoveTo(actor:Position()+Vector3.new(0,0,12),16)
			assert(not actor.followMotion and actor.goal~=nil)
		end)
		local start=actor:Position();local untilAt=os.clock()+2
		while os.clock()<untilAt do RunService.Heartbeat:Wait();actor:Step(os.clock()) end
		check("A normal walking command works after the follow handoff",function()
			assert(actor:Position().Z>start.Z+9 and not actor.followMotion)
		end)
		check("Physical recovery preserves following and its current destination",function()
			local goal=actor:Position()+Vector3.new(12,0,0)
			actor:Follow(goal,Vector3.new(10,0,0),24)
			assert(actor:Recover(actor:Position(),"Follow fixture recovery",os.clock()))
			assert(actor.followMotion and actor.goal==goal and actor.followMotion.maxSpeed==24)
			actor:Step(os.clock());assert(actor.humanoid.WalkSpeed>0)
		end)
	end,debug.traceback)
	for _,r in actors do r.actor:Destroy() end;folder:Destroy()
	if not ok then table.insert(results,{name="Fixture execution",passed=false,error=why}) end
	return {checks=results,metrics=metrics}
end
return Checks
