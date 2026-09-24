--!strict
-- Shared spatial contract. Scenery, marching and occupancy use the same bounds.
local Config = require(script.Parent.Config)
local HomePlot = require(script.Parent.HomePlotLayout)
local Layout = {
 FieldY = 1.05,
 RoadWidth = 14,
 GateRoadWidth = 12,
 HomeDeckHalfWidth = 38,
 HomeDeckHalfDepth = 35.92683410644531,
 RampLength = 14,
 GateX = -0.49,
 King = {Radius=23.5625, FloorRadius=21.9375, ExitRadius=26.5625, NearRouteRadius=26.5625,
  DetourEligibility=31.5625, ObstacleRadius=27.5625, DetourRadius=31.5625, PromptRadius=28.5625},
}

function Layout.HomeHeight(index:number):number
 return 3
end

function Layout.HomeFootY(index:number):number
 return Layout.HomeHeight(index)+HomePlot.ForPlot(index).FootY
end

function Layout.HomeFrame(index:number):CFrame
 local at=Config.PlotPositions[index]
 local p=Vector3.new(at[1],Layout.HomeHeight(index),at[2])
 return CFrame.lookAt(p,Vector3.new(0,p.Y,0))
end

function Layout.ExitZ():number
 return -Layout.HomeDeckHalfDepth-Layout.RampLength
end

-- Ground height for a walking foot, not a model pivot. PetActor adds FootOffset once.
function Layout.FootPosition(x:number,z:number):Vector3
 local p=Vector3.new(x,Layout.FieldY,z)
 for i in Config.PlotPositions do
  local frame=Layout.HomeFrame(i)
  local at=frame:PointToObjectSpace(p)
  local homeY=Layout.HomeFootY(i)
  if math.abs(at.X)<=Layout.HomeDeckHalfWidth and math.abs(at.Z)<=Layout.HomeDeckHalfDepth then
   return Vector3.new(x,homeY,z)
  end
  if math.abs(at.X-Layout.GateX)<=Layout.GateRoadWidth/2+0.5
   and at.Z>=Layout.ExitZ() and at.Z< -Layout.HomeDeckHalfDepth then
   local t=math.clamp((-at.Z-Layout.HomeDeckHalfDepth)/Layout.RampLength,0,1)
   return Vector3.new(x,homeY+(Layout.FieldY-homeY)*t,z)
  end
 end
 return p
end

function Layout.Contains(location, x:number, z:number, padding:number?):boolean
 if not location or not location.position then return false end
 local pad=padding or 0
 local half=(location.halfSize or Config.CampHalfSize)+pad
 if location.king then
  return Vector2.new(x-location.position.X,z-location.position.Z).Magnitude<=half
 end
 local frame=location.frame or CFrame.new(location.position)
 local at=frame:PointToObjectSpace(Vector3.new(x,frame.Y,z))
 return math.abs(at.X)<=half and math.abs(at.Z)<=half
end

return Layout
