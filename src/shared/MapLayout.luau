--!strict
-- Shared spatial contract. Scenery, marching and occupancy use the same bounds.
local Config = require(script.Parent.Config)
local HomePlot = require(script.Parent.HomePlotLayout)
local Layout = {
 FieldY = 1.05,
 RoadWidth = 5.128,
 GateRoadWidth = 5.128,
 HomeDeckHalfWidth = 38,
 HomeDeckHalfDepth = 35.92683410644531,
 RampLength = 6.073166,
 GateX = -0.49,
 King = {Radius=50, FloorRadius=51.2773, ExitRadius=57, NearRouteRadius=60,
  DetourEligibility=66, ObstacleRadius=61, DetourRadius=67, PromptRadius=57},
}

local function authoredRoot()
 return workspace:FindFirstChild("PetRollWorld") or workspace:FindFirstChild("MyChickenArmyMap")
end

local function authoredHome(index)
 local root=authoredRoot()
 if not root then return nil end
 local homes=root:FindFirstChild("03_HomePlots") or root
 return homes:FindFirstChild("Plot"..index)
end

function Layout.HomeHeight(index:number):number
 local home=authoredHome(index)
 local deck=home and home:FindFirstChild("Deck")
 if deck and deck:IsA("BasePart") then return deck.Position.Y+deck.Size.Y/2 end
 return 3
end

function Layout.HomeFootY(index:number):number
 local home=authoredHome(index)
 local anchors=home and home:FindFirstChild("Anchors")
 local yard=anchors and anchors:FindFirstChild("Yard")
 if yard and yard:IsA("BasePart") then return yard.Position.Y end
 return Layout.HomeHeight(index)+HomePlot.ForPlot(index).FootY
end

function Layout.HomeFrame(index:number):CFrame
 local home=authoredHome(index)
 local deck=home and home:FindFirstChild("Deck")
 if deck and deck:IsA("BasePart") then return deck.CFrame+Vector3.new(0,deck.Size.Y/2,0) end
 local at=Config.PlotPositions[index]
 local p=Vector3.new(at[1],Layout.HomeHeight(index),at[2])
 return CFrame.lookAt(p,Vector3.new(0,p.Y,0))
end

function Layout.ExitZ():number
 return -Layout.HomeDeckHalfDepth-Layout.RampLength
end

-- Ground height for a walking foot, not a model pivot. PetActor adds FootOffset once.
-- Only authored walk surfaces participate: roofs, decorations, eggs and birds cannot lift a marching chicken.
local surfaceRoot=nil
local surfaces={}
local surfaceRay=RaycastParams.new()
surfaceRay.FilterType=Enum.RaycastFilterType.Include
function Layout.FootPosition(x:number,z:number):Vector3
 local root=authoredRoot()
 if root and root:GetAttribute("BuilderMapVersion")=="20260922" then
  if surfaceRoot~=root then
   surfaceRoot=root;surfaces={}
   for _,part in root:GetDescendants() do
    if part:IsA("BasePart") and part:GetAttribute("WalkSurface") then table.insert(surfaces,part) end
   end
   surfaceRay.FilterDescendantsInstances=surfaces
  end
  local hit=workspace:Raycast(Vector3.new(x,100,z),Vector3.new(0,-200,0),surfaceRay)
  return Vector3.new(x,if hit then hit.Position.Y else Layout.FieldY,z)
 end
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
