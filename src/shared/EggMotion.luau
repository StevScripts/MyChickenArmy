--!strict
-- The moving endpoint stays attached to the character throughout pickup flight.
local Feel=require(script.Parent.CollectionFeel)
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
 local distance=delta.Magnitude
 local arc=math.min(Feel.Egg.ArcHeight,distance*0.32+0.18)
 local width=math.min(Feel.Egg.SideArc,distance*0.12)
 local p1=start+Vector3.new(0,arc,0)+side*swing*width
 local p2=goal-delta*0.18+Vector3.new(0,arc*0.35,0)
 -- Immediate lift, then acceleration; no long stationary t^2 windup.
 return Motion.Bezier(start,p1,p2,goal,t*(0.45+0.55*t))
end
return Motion
