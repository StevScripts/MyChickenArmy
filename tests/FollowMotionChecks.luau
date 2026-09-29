-- Pure motion checks; no saved profiles, map writes or live player mutations.
local Motion=require(game.ReplicatedStorage.PetRoll.Shared.FollowMotion)
local Checks={}
function Checks.Run()
	local results={}
	local function check(name,fn)
		local ok,why=pcall(fn)
		table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
	end
	check("Steady motion has no arrival stop at 30, 60 or 144 Hz",function()
		local errors={}
		for _,hz in {30,60,144} do
			local dt=1/hz;local position=Vector3.new(0,0,7);local velocity=Vector3.zero
			local minimum=math.huge
			for tick=1,hz*8 do
				local goal=Vector3.new(16*tick*dt,0,7)
				velocity=Motion.Velocity(velocity,goal-position,Vector3.new(16,0,0),24,dt)
				position+=velocity*dt
				if tick>hz*2 then minimum=math.min(minimum,velocity.Magnitude) end
				assert(velocity.Magnitude<=24.0001,"Exceeded catch-up limit")
			end
			assert(minimum>15,"Follower keeps stopping behind moving leader")
			table.insert(errors,math.abs(position.X-128))
		end
		assert(math.max(table.unpack(errors))-math.min(table.unpack(errors))<0.6,"Frame rate changes following materially")
	end)
	check("Arrival settles without oscillating or waking inside the rest band",function()
		local position=Vector3.zero;local velocity=Vector3.new(16,0,0);local goal=Vector3.new(5,0,0)
		for _=1,600 do
			velocity=Motion.Velocity(velocity,goal-position,Vector3.zero,24,1/60)
			position+=velocity/60
		end
		assert((position-goal).Magnitude<0.76 and velocity.Magnitude==0,"Never settled")
		assert(Motion.Velocity(Vector3.zero,Vector3.new(0.2,0,0),Vector3.zero,24,1/60)==Vector3.zero)
	end)
	check("At the slot a moving leader still produces motion",function()
		local v=Motion.Velocity(Vector3.new(16,0,0),Vector3.zero,Vector3.new(16,0,0),24,1/60)
		assert((v-Vector3.new(16,0,0)).Magnitude<0.001)
	end)
	check("Vertical jumps cannot make chickens fly or increase their walking speed",function()
		local a=Motion.Velocity(Vector3.zero,Vector3.new(2,50,0),Vector3.new(10,100,0),24,1/60)
		local b=Motion.Velocity(Vector3.zero,Vector3.new(2,0,0),Vector3.new(10,0,0),24,1/60)
		assert(a==b and a.Y==0)
	end)
	check("Formation does not orbit at rest; turns have a bounded yaw",function()
		local old=CFrame.new(0,0,0);local goal=CFrame.Angles(0,math.pi,0)
		local still=Motion.Frame(old,goal,Vector3.zero,1/60)
		assert(still.LookVector:Dot(old.LookVector)>0.99999)
		local turned=Motion.Frame(old,goal,Vector3.new(16,0,0),1/60)
		local angle=math.acos(math.clamp(turned.LookVector:Dot(old.LookVector),-1,1))
		assert(angle>0 and angle<=Motion.TurnRate/60+0.0001)
	end)
	check("Formation centers partial rows and retains Giant spacing",function()
		for count=1,15 do
			for row=0,math.floor((count-1)/3) do
				local sum=0
				for index=row*3+1,math.min(count,row*3+3) do
					local p=Motion.Offset(index,count,19.25);sum+=p.X
					assert(p.Z==7+row*19.25)
				end
				assert(math.abs(sum)<0.001)
			end
		end
	end)
	check("Long frames and large target jumps remain bounded and finite",function()
		local v=Motion.Velocity(Vector3.new(48,0,0),Vector3.new(-1000,1000,0),Vector3.new(-1000,0,0),48,5)
		assert(v.X==v.X and v.Magnitude<=48.0001 and v.Y==0)
		assert(Motion.Velocity(Vector3.zero,Vector3.new(5,0,0),Vector3.zero,24,0)==Vector3.zero)
	end)
	check("Waypoint crossings preserve speed before final approach",function()
		local v=Motion.Velocity(Vector3.new(24,0,0),Vector3.new(1.6,0,0),Vector3.zero,24,1/60,true)
		assert(v.X>23.99)
	end)
	return results
end
return Checks
