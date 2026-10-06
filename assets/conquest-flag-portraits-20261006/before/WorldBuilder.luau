--!strict
-- Authored native-part scenery. Gameplay state and moving pets belong to WorldService.
local WorldBuilder = {}
local CampScenery = require(script.Parent.CampScenery)
local MapScenery = require(script.Parent.MapScenery)
local MapLayout = require(game:GetService("ReplicatedStorage").PetRoll.Shared.MapLayout)
local Config = require(game:GetService("ReplicatedStorage").PetRoll.Shared.Config)
local UIColors = require(game:GetService("ReplicatedStorage").PetRoll.Shared.UIColors)
local Conquest = require(game:GetService("ReplicatedStorage").PetRoll.Shared.ConquestPresentation)

local palette = {
	grass = Color3.fromRGB(106, 185, 79), grassLight = Color3.fromRGB(108, 187, 80),
	grassDark = Color3.fromRGB(87, 161, 72), path = Color3.fromRGB(240, 230, 204),
	sand = Color3.fromRGB(222, 209, 166), water = Color3.fromRGB(82, 198, 224),
	cream = Color3.fromRGB(255, 246, 215), wood = Color3.fromRGB(170, 85, 0),
	darkWood = Color3.fromRGB(102, 51, 0), ink = Color3.fromRGB(42, 67, 66),
	gold = Color3.fromRGB(255, 204, 61), white = Color3.fromRGB(252, 252, 238),
}
WorldBuilder.Palette = palette

function WorldBuilder.Part(parent, name, size, cf, color, collidable)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.CanCollide, p.CanTouch = true, collidable == true, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = size.Y > 0.6
	p.Parent = parent
	return p
end

local function model(parent, name)
	local result = Instance.new("Model")
	result.Name, result.Parent = name, parent
	return result
end

local function disk(parent, name, radius, height, position, color, collidable)
	local p = WorldBuilder.Part(parent, name, Vector3.new(height, radius * 2, radius * 2),
		CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, collidable)
	p.Shape = Enum.PartType.Cylinder
	return p
end
WorldBuilder.Disk = disk

function WorldBuilder.Sign(parent, name, cf, text, color, width, height)
	local board = WorldBuilder.Part(parent, name, Vector3.new(width or 22, height or 3.6, 0.5), cf, color, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode, gui.PixelsPerStud = Enum.SurfaceGuiSizingMode.PixelsPerStud, 36
	gui.LightInfluence, gui.Parent = 0.1, board
	local label = Instance.new("TextLabel")
	label.Name, label.Size = "Text", UDim2.fromScale(1, 1)
	label.BackgroundTransparency, label.TextColor3 = 1, UIColors.Text
	label.TextStrokeColor3, label.TextStrokeTransparency = UIColors.Border, 0.15
	label.TextSize, label.Font, label.Text = 29, Enum.Font.SourceSansBold, text
	label.TextWrapped, label.TextScaled, label.Parent = true, true, gui
	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MinTextSize, sizeLimit.MaxTextSize, sizeLimit.Parent = 14, 68, label
	return label, board
end

function WorldBuilder.Billboard(parent, name, at, text, color, width, distance)
	local anchor = WorldBuilder.Part(parent, name, Vector3.one, CFrame.new(at), color, false)
	anchor.Transparency, anchor.CanQuery, anchor.CastShadow = 1, false, false
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Size, gui.MaxDistance = "Label", UDim2.fromOffset(width or 220, 64), distance or 150
	gui.AlwaysOnTop, gui.LightInfluence, gui.Parent = false, 0, anchor
	local label = Instance.new("TextLabel")
	label.Name, label.Size, label.BackgroundTransparency = "Text", UDim2.fromScale(1, 1), 1
	label.Font, label.TextSize, label.TextColor3 = Enum.Font.SourceSansBold, 22, color
	label.TextStrokeColor3, label.TextStrokeTransparency = UIColors.Border, 0.2
	label.Text, label.TextWrapped, label.Parent = text, true, gui
	return label
end

local function road(parent, name, a, b, width, color)
	-- Decorative paths sit above the continuous island collider; their seams cannot trip rigs.
	local from = Vector3.new(a.X, 1.067, a.Z)
	local to = Vector3.new(b.X, 1.067, b.Z)
	local path = WorldBuilder.Part(parent, name, Vector3.new(width, 0.012, (from - to).Magnitude + 0.35),
		CFrame.lookAt((from + to) / 2, to), color or palette.path, false)
	-- Mouse commands still reach the plot or camp floor underneath a painted path.
	path.CanQuery = false
	return path
end
WorldBuilder.Road = road

local function ring(parent, name, radius, width)
 local folder=model(parent,name)
 -- Short segments keep the outside edge round without the old large triangular overlaps.
 local count=240
 for i=1,count do
  local a,b=(i-1)*math.pi*2/count,i*math.pi*2/count
  road(folder,"Path"..i,Vector3.new(math.cos(a)*radius,1.067,math.sin(a)*radius),
   Vector3.new(math.cos(b)*radius,1.067,math.sin(b)*radius),width)
 end
end

function WorldBuilder.BuildIsland(root, positions, campRadii, map)
	local island = model(root, "Island")
	WorldBuilder.Part(island, "Water", Vector3.new(2048, 0.2, 2048), CFrame.new(0, -0.04, 0), palette.water, true)
	-- Keep shore below grass; coplanar cylinder caps produce large triangular flashes.
	disk(island, "Shore", map.ShoreRadius, 1.46, Vector3.new(0, 0.28, 0), palette.sand, true)
	-- The entire playable island shares this top surface (Y=1.05), including camp approaches.
	disk(island, "Grass", map.IslandRadius, 1, Vector3.new(0, 0.55, 0), palette.grass, true)
	local tiles = model(island, "GrassTiles")
	local tileLimit = math.ceil(map.IslandRadius / 28)
	for x = -tileLimit, tileLimit do
		for z = -tileLimit, tileLimit do
			if Vector2.new(math.abs(x * 28) + 14, math.abs(z * 28) + 14).Magnitude > map.IslandRadius - 2 then continue end
			WorldBuilder.Part(tiles, "Tile_" .. x .. "_" .. z, Vector3.new(28, 0.012, 28), CFrame.new(x * 28, 1.053, z * 28),
				if (x + z) % 2 == 0 then palette.grass else palette.grassLight, false)
		end
	end
	local paths = model(root, "Paths")
	-- Only the main approaches are roads. Optional camps are reached across grass.
	ring(paths, "HomeRing", map.HomeRingRadius, 10)
	for index, position in positions do
		local outward = Vector3.new(position[1], 0, position[2]).Unit
  local homeRadius=Vector2.new(position[1],position[2]).Magnitude
  local approachRadius=homeRadius+MapLayout.ExitZ()
  road(paths,"Spoke"..index,outward*MapLayout.King.Radius,outward*(approachRadius-4),MapLayout.RoadWidth)
  road(paths,"GateApproach"..index,outward*(approachRadius-5),outward*approachRadius,MapLayout.GateRoadWidth)
  WorldBuilder.BuildHomeApproach(paths,index,MapLayout.HomeFrame(index))
	end
 MapScenery.Build(WorldBuilder,root,positions,map)
end

function WorldBuilder.BuildPlot(root,index,cf)
 local existing=root:GetAttribute("AuthoredMap") and root:FindFirstChild("Plot"..index)
 if existing then
  local sign=existing:FindFirstChild("Your Plot",true)
  local title=sign and sign:FindFirstChildWhichIsA("TextLabel",true)
  assert(title,"Authored plot is missing its owner sign")
  return existing,title
 end
 return require(script.Parent.AuthoredPlot).Build(root,index,cf)
end

function WorldBuilder.BuildHomeApproach(root,index,cf)
 local group=model(root,"HomeApproach"..index)
 local halfDepth=MapLayout.HomeDeckHalfDepth
 local run=MapLayout.RampLength
 local homeY=MapLayout.HomeFootY(index)
 local fieldY=MapLayout.FieldY
 local rise=homeY-fieldY
 local midpoint=(homeY+fieldY)/2
 local thickness=0.22
 local tilt=-math.atan2(rise,run)
 local center=(cf*CFrame.new(MapLayout.GateX,0,-halfDepth-run/2)).Position
 local ramp=WorldBuilder.Part(group,"WalkRamp",Vector3.new(MapLayout.GateRoadWidth,thickness,math.sqrt(run*run+rise*rise)),
  CFrame.new(center.X,midpoint-thickness/(2*math.cos(tilt)),center.Z)*cf.Rotation*CFrame.Angles(tilt,0,0),palette.path,true)
 ramp:SetAttribute("WalkSurface",true)
 ramp:SetAttribute("PlotIndex",index)
 -- A quiet stone edge belongs to the raised home foundation, outside the walking lane.
 if rise>0.2 then
  for _,side in {-1,1} do
   local trim=WorldBuilder.Part(group,"StoneRampEdge",Vector3.new(0.45,0.14,math.sqrt(run*run+rise*rise)),
    ramp.CFrame*CFrame.new(side*(MapLayout.GateRoadWidth/2+0.23),0.16,0),Color3.fromRGB(141,141,211),false)
   trim.CanQuery=false
  end
 end
 return group
end

function WorldBuilder.BuildConquestTrophy(parent, cf)
	local trophy = model(parent, "ConquestTrophy")
	trophy:SetAttribute("KingRequired", true)
	disk(trophy, "Foot", 2.1, 0.35, (cf * CFrame.new(0, 0.23, 0)).Position, palette.ink, false)
	disk(trophy, "Pedestal", 1.7, 1.25, (cf * CFrame.new(0, 1.03, 0)).Position, palette.cream, false)
	disk(trophy, "GoldRim", 1.9, 0.22, (cf * CFrame.new(0, 1.74, 0)).Position, palette.gold, false)
	disk(trophy, "CrownBand", 1.45, 0.85, (cf * CFrame.new(0, 2.25, 0)).Position, palette.gold, false)
	for i = 1, 5 do
		local angle = (i - 1) * math.pi * 2 / 5
		local at = cf * CFrame.new(math.cos(angle) * 1.2, 3, math.sin(angle) * 1.2)
		WorldBuilder.Part(trophy, "CrownPoint" .. i, Vector3.new(0.48, 1.45, 0.48), at, palette.gold, false)
		local gem = WorldBuilder.Part(trophy, "Jewel" .. i, Vector3.one * 0.5, at * CFrame.new(0, 0.8, 0), palette.water, false)
		gem.Shape = Enum.PartType.Ball
	end
	WorldBuilder.Billboard(trophy, "RewardLabel", (cf * CFrame.new(0, 5.3, 0)).Position,
		"CHICKEN CROWN\nCHICKEN KING DEFEATED", palette.gold, 195, 50)
	return trophy
end

function WorldBuilder.BuildCamp(root, index, camp, halfSize, final, frame, plotIndex, existing)
	existing=existing or root:FindFirstChild("Camp"..index)
	if existing and existing:GetAttribute("AuthoredScenery") then
		local anchor=existing:FindFirstChild("CommandCenter")
		assert(anchor and anchor:IsA("BasePart"),"Authored camp needs its CommandCenter marker")
		return existing,anchor.CFrame
	end
	local group = model(root, "Camp" .. index)
	group:SetAttribute("LaneOwnerIndex", plotIndex)
	group:SetAttribute("Difficulty", index)
	group:SetAttribute("CommandTarget", "camp:" .. index)
	group:SetAttribute("Occupied", false)
	local cf = frame or CFrame.new(camp.position[1], 1, camp.position[2])
	local theme = CampScenery.Theme(index,camp.name)
	local edge = halfSize or Config.CampHalfSize
	group:SetAttribute("CampHalfSize", edge)
	group:SetAttribute("SceneryVersion", 3)
 group:SetAttribute("SceneryName",camp.name)
 group:SetAttribute("CampName",camp.name)
	local commandCenter=WorldBuilder.Part(group,"CommandCenter",Vector3.one,cf,theme.accent,false)
	commandCenter.Transparency,commandCenter.CanQuery=1,false
	local ground=WorldBuilder.Part(group,"Ground",Vector3.new(edge*2,.012,edge*2),cf*CFrame.new(0,.042,0),theme.ground,false)
	ground.TopSurface=Enum.SurfaceType.Studs
	CampScenery.Build(WorldBuilder,group,cf,edge,index,camp.name)
	local title=WorldBuilder.Billboard(group,"Title",(cf*CFrame.new(0,14,-edge+1.5)).Position,
		string.upper(camp.name),theme.accent,210,95)
	title.Parent.Size=UDim2.fromScale(15,2.2)
	title.TextScaled,title.TextWrapped=true,false
	local sizeLimit=Instance.new("UITextSizeConstraint")
	sizeLimit.MinTextSize,sizeLimit.MaxTextSize,sizeLimit.Parent=7,52,title
	return group,cf
end

-- Optional supply landmark reached across the open grass.
function WorldBuilder.BuildIncomeOutpost(root,frame,definition)
 local existing=root:GetAttribute("AuthoredMap") and root:FindFirstChild("IncomeOutpost")
 if existing then return existing,existing.CommandCenter.CFrame,existing.IncomeStatus.Label.Text end
 local group,cf=WorldBuilder.BuildCamp(root,1,{name=definition.Name},Config.CampHalfSize,false,frame,nil)
 group.Name="IncomeOutpost"
 group:SetAttribute("CommandTarget",definition.TargetId)
 group:SetAttribute("IncomeTerritory",true)
 local title=WorldBuilder.Billboard(group,"IncomeStatus",(cf*CFrame.new(0,11.6,-Config.CampHalfSize+1.5)).Position,
  "Unclaimed · +$"..definition.Rate.."/s",palette.gold,225,60)
 title.Parent.Size=UDim2.fromScale(16,2)
 title.TextScaled,title.TextWrapped=true,false
 local size=Instance.new("UITextSizeConstraint")
 size.MinTextSize,size.MaxTextSize,size.Parent=9,28,title
 return group,cf,title
end

-- Recolor existing scenery without rebuilding occupied camps or moving actors.
function WorldBuilder.ApplyCampPromotion(group,rank,name)
 -- The authored landmark retains its identity; progression does not repaint a naval fort purple.
 local theme=CampScenery.Theme(group:GetAttribute("Difficulty") or rank,group:GetAttribute("SceneryName") or name)
 group:SetAttribute("Promotion",rank)
 group:SetAttribute("CampName",name)
 for _,part in group:GetDescendants() do
  if part:IsA("BasePart") and not group:GetAttribute("AuthoredScenery") then
   local tint=part:GetAttribute("CampTint")
   if part.Name=="Ground" then part.Color=theme.ground
   elseif tint and theme[tint] then part.Color=theme[tint] end
  end
 end
 local anchor=group:FindFirstChild("Title")
 local gui=anchor and anchor:FindFirstChild("Label")
 local label=gui and gui:FindFirstChild("Text")
 if label then
  label.Text=string.upper(name)
  label.TextColor3=theme.accent
 end
end

-- The encounter/owned label supplies the camp name while this site is occupied.
function WorldBuilder.ApplyCampTitle(group)
 if group:GetAttribute("IncomeTerritory") then return end
 local anchor=group:FindFirstChild("Title")
 local gui=anchor and anchor:FindFirstChild("Label")
 if gui then gui.Enabled=not group:GetAttribute("Occupied") and not group:GetAttribute("Conquered") end
end

-- This marker belongs to the territory, so it outlives its departing battle.
function WorldBuilder.ApplyCampOwnership(group,frame,userId,name)
 group:SetAttribute("ConquerorUserId",userId)
 group:SetAttribute("Conquered",userId~=nil)
 WorldBuilder.ApplyCampTitle(group)
 local marker=group:FindFirstChild("OwnershipFlag")
 if not userId then if marker then marker:Destroy() end;return end
 if not marker then
  marker=model(group,"OwnershipFlag")
  local scale=Config.CampHalfSize/18
  local cf=frame*CFrame.new(8.75*scale,0,-16.5*scale)
  WorldBuilder.Part(marker,"Pole",Vector3.new(.35,9,.35),cf*CFrame.new(0,4.5,0),Color3.fromRGB(80,88,66),false)
  WorldBuilder.Part(marker,"Flag",Vector3.new(2.5,2,.15),cf*CFrame.new(1.25,7.5,0),Conquest.Owned,false)
  local title=WorldBuilder.Billboard(marker,"Owner",frame.Position+Vector3.new(0,Conquest.Elevation,0),"",Conquest.Owned,150,Conquest.MaxDistance)
  title.Parent.Size=UDim2.fromScale(Conquest.Width,Conquest.Height)
  title.Parent.AlwaysOnTop=true
  title.Size=UDim2.fromScale(1,0.35)
  title.TextScaled=true
  local camp=title:Clone();camp.Name="CampName";camp.Position=UDim2.fromScale(0.1,0.36)
  camp.Size=UDim2.fromScale(0.8,0.23);camp.TextColor3=UIColors.Text;camp.Parent=title.Parent
  local owner=title:Clone();owner.Name="OwnerName";owner.Position=UDim2.fromScale(0.08,0.64)
  owner.Size=UDim2.fromScale(0.84,0.2);owner.TextColor3=UIColors.Rewards;owner.Parent=title.Parent
 end
 marker.Owner.Label.Text.Text="⚔ Conquered ⚔"
 marker.Owner.Label.CampName.Text=group:GetAttribute("CampName") or group:GetAttribute("SceneryName") or "Base"
 marker.Owner.Label.OwnerName.Text=name or ""
end

function WorldBuilder.ApplyLighting()
	local lighting = game:GetService("Lighting")
	lighting.ClockTime, lighting.Brightness = 13.6, 2.5
	lighting.Ambient = Color3.fromRGB(142, 158, 164)
	lighting.OutdoorAmbient = Color3.fromRGB(163, 179, 181)
	lighting.EnvironmentDiffuseScale, lighting.EnvironmentSpecularScale = 0.7, 0.35
	lighting.ShadowSoftness, lighting.GlobalShadows = 0.35, true
	local bloom = lighting:FindFirstChild("PetRollBloom")
	if not bloom then bloom = Instance.new("BloomEffect"); bloom.Name = "PetRollBloom"; bloom.Parent = lighting end
	bloom:SetAttribute("PetRollGenerated", true)
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.08, 18, 1.8
	local atmosphere = lighting:FindFirstChild("PetRollAtmosphere")
	if not atmosphere then atmosphere = Instance.new("Atmosphere"); atmosphere.Name = "PetRollAtmosphere"; atmosphere.Parent = lighting end
	atmosphere:SetAttribute("PetRollGenerated", true)
	atmosphere.Density, atmosphere.Offset, atmosphere.Haze, atmosphere.Glare = 0.16, 0.1, 0.35, 0.08
	atmosphere.Color, atmosphere.Decay = Color3.fromRGB(209, 239, 255), Color3.fromRGB(169, 205, 221)
end


return WorldBuilder

