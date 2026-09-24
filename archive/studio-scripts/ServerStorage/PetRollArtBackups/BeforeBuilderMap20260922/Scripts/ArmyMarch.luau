--!strict
-- Shared exits, independent departures. Waypoints never wait for another bird.
local Config=require(script.Parent.Config)
local HomePlot=require(script.Parent.HomePlotLayout)
local MapLayout=require(script.Parent.MapLayout)
local March={}
local function flat(v) return Vector3.new(v.X,1.05,v.Z) end
local function homeAt(point)
 for index,position in Config.PlotPositions do
  local layout=HomePlot.ForPlot(index)
  local center=Vector3.new(position[1],1.05,position[2])
  local frame=CFrame.lookAt(center,Vector3.new(0,1.05,0))
  local localPoint=frame:PointToObjectSpace(point)
  if math.abs(localPoint.X)<=layout.Width/2+1 and math.abs(localPoint.Z)<=layout.Depth/2+1 then return frame,layout end
 end
 return nil
end
function March.Site(frame,isKing)
 return {frame=frame,halfSize=if isKing then MapLayout.King.Radius else Config.CampHalfSize,isKing=isKing}
end
function March.Path(origin,destination,departure)
 local points={flat(origin)}
 local function add(v) if (flat(v)-points[#points]).Magnitude>0.5 then table.insert(points,flat(v)) end end
 local home,homeLayout=homeAt(origin)
 local destinationHome,destinationLayout=homeAt(destination)
 if home and destinationHome and (home.Position-destinationHome.Position).Magnitude<1 then
  add(destination);return points
 end
 if home then
  add((home*CFrame.new(MapLayout.GateX,0,homeLayout.Entrance.Z)).Position)
  add((home*CFrame.new(MapLayout.GateX,0,MapLayout.ExitZ())).Position)
 elseif departure then
  local at=departure.frame:PointToObjectSpace(origin)
  if math.abs(at.X)<=departure.halfSize+3 and math.abs(at.Z)<=departure.halfSize+3 then
   if departure.isKing then
    local direction=destination-departure.frame.Position
    local angle=-math.pi/2+math.round((math.atan2(direction.Z,direction.X)+math.pi/2)/(math.pi/3))*math.pi/3
    add(departure.frame.Position+Vector3.new(math.cos(angle)*MapLayout.King.ExitRadius,0,math.sin(angle)*MapLayout.King.ExitRadius))
   else
    local toward=departure.frame:PointToObjectSpace(destination)
    add((departure.frame*CFrame.new(0,0,(if toward.Z<0 then -1 else 1)*(departure.halfSize+3))).Position)
   end
  end
 end
 local arrival=if destinationHome then (destinationHome*CFrame.new(MapLayout.GateX,0,MapLayout.ExitZ())).Position else destination
 local a,b=Vector3.new(points[#points].X,0,points[#points].Z),Vector3.new(arrival.X,0,arrival.Z)
 -- Only the main home-to-King spokes are roads. Side destinations use grass.
 local function homeSpoke(point)
  local nearest,distance=nil,18
  for _,position in Config.PlotPositions do
   local direction=Vector3.new(position[1],0,position[2]).Unit
   local projection=point:Dot(direction)
   local lateral=(point-direction*projection).Magnitude
   if projection>0 and lateral<distance then nearest,distance=direction,lateral end
  end
  return nearest
 end
 local spokeA,spokeB=homeSpoke(a),homeSpoke(b)
 if a.Magnitude<MapLayout.King.NearRouteRadius then spokeA=spokeB end
 if b.Magnitude<MapLayout.King.NearRouteRadius then spokeB=spokeA end
 if spokeA and spokeB and spokeA:Dot(spokeB)>0.999 then
  add(spokeA*math.max(0,a:Dot(spokeA)))
  add(spokeB*math.max(0,b:Dot(spokeB)))
 elseif a.Magnitude>MapLayout.King.DetourEligibility and b.Magnitude>MapLayout.King.DetourEligibility then
  -- Cross-field travel skirts the King arena instead of cutting through it.
  local segment=b-a
  local fraction=if segment.Magnitude>0 then math.clamp(-a:Dot(segment)/segment:Dot(segment),0,1) else 0
  if (a+segment*fraction).Magnitude<MapLayout.King.ObstacleRadius then
   local angleA,angleB=math.atan2(a.Z,a.X),math.atan2(b.Z,b.X)
   local delta=(angleB-angleA+math.pi)%(2*math.pi)-math.pi
   local steps=math.max(1,math.ceil(math.abs(delta)/(math.pi/18)))
   for i=0,steps do
    local angle=angleA+delta*i/steps
    add(Vector3.new(math.cos(angle)*MapLayout.King.DetourRadius,1.05,math.sin(angle)*MapLayout.King.DetourRadius))
   end
  end
 end
 -- Returning birds enter through the open home gate, not the side walls.
 if destinationHome then
  add(arrival)
  add((destinationHome*CFrame.new(MapLayout.GateX,0,destinationLayout.Entrance.Z)).Position)
 end
 add(destination)
 return points
end
function March.Set(unit,points,delayUntil)
 unit.marchPath=points;unit.marchIndex=2;unit.marchReadyAt=delayUntil or 0
end
function March.Approach(unit,destination,now,departure)
 local points=March.Path(Vector3.new(unit.x,1.05,unit.z),destination,departure)
 -- Keep only exit/obstacle waypoints. Battle chooses the actual live target.
 if #points>1 then table.remove(points) end
 March.Set(unit,points,now)
end
function March.Step(battle,unit,dt,now)
 local path=unit.marchPath
 if not path then return true end
 if now<(unit.marchReadyAt or 0) then if battle.actors then battle.actors:Stop(unit) end;return false end
 local point=path[unit.marchIndex]
 while point and (Vector3.new(unit.x,1.05,unit.z)-point).Magnitude<=1.5 do
  unit.marchIndex+=1;point=path[unit.marchIndex]
 end
 if not point then unit.marchPath=nil;return true end
 battle:MoveUnit(unit,point.X,point.Z,dt)
 return false
end
return March
