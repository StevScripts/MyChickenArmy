--!strict
-- The moving endpoint stays attached to the character throughout pickup flight.
local Motion={}
function Motion.Bezier(a,b,c,d,t)
 local s=1-t
 return s*s*s*a+3*s*s*t*b+3*s*t*t*c+t*t*t*d
end
function Motion.Flight(start,goal,alpha,seed,reduced)
 local t=math.clamp(alpha,0,1)
 if reduced then return start:Lerp(goal,t) end
 local delta=goal-start
 local flat=Vector3.new(delta.X,0,delta.Z)
 local side=if flat.Magnitude>0.01 then Vector3.new(-flat.Z,0,flat.X).Unit else Vector3.xAxis
 local swing=if seed%2==0 then 1 else -1
 local p1=start+Vector3.new(0,3.1,0)+side*swing*1.8
 local p2=goal+Vector3.new(0,1.6,0)-delta*0.2+side*swing*0.9
 return Motion.Bezier(start,p1,p2,goal,t*t)
end
return Motion
