--[[
Radial map scale for the authored island (workspace.MyChickenArmyMap), Studio Edit only.
Run through Studio Flow execute_luau. K < 1 pulls yards, camps, roads, decor, both island
discs and the invisible border toward the centre; the King arena stays. The transform is
exact and invertible: run again with K = 1 / previous K to restore. The product of every run
is kept in the map root attribute MapRadialScale. Applied 2026-10-23 with K = 0.85, and
Config.Map / CampRadii / PlotPositions were scaled to match (src/shared/Config.luau).
]]
local K = 0.85
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local root = workspace.MyChickenArmyMap
local env = root["01_Environment"]
ChangeHistoryService:SetWaypoint("Before map radial scale " .. K)
local function xzScale(v) return Vector3.new(v.X * K, v.Y, v.Z * K) end
local function centerOf(container)
  local minx, minz, maxx, maxz, n = math.huge, math.huge, -math.huge, -math.huge, 0
  for _, p in ipairs(container:GetDescendants()) do
    if p:IsA("BasePart") then n += 1
      minx = math.min(minx, p.Position.X - p.Size.X/2); maxx = math.max(maxx, p.Position.X + p.Size.X/2)
      minz = math.min(minz, p.Position.Z - p.Size.Z/2); maxz = math.max(maxz, p.Position.Z + p.Size.Z/2)
    end
  end
  if n == 0 then return nil end
  return Vector3.new((minx+maxx)/2, 0, (minz+maxz)/2)
end
local function translateContainer(container, delta)
  for _, child in ipairs(container:GetChildren()) do
    if child:IsA("Model") then child:PivotTo(child:GetPivot() + delta)
    elseif child:IsA("BasePart") then child.CFrame = child.CFrame + delta
    elseif child:IsA("Folder") or child:IsA("Configuration") then translateContainer(child, delta) end
  end
end
for i = 1, 6 do
  local plot = root["03_HomePlots"]:FindFirstChild("Plot" .. i)
  local c = plot and centerOf(plot)
  if c then translateContainer(plot, xzScale(c) - c) end
  for _, camp in ipairs(root["04_MainCamps"]["Lane" .. i]:GetChildren()) do
    local cc = centerOf(camp)
    if cc then
      if camp:IsA("Model") then camp:PivotTo(camp:GetPivot() + (xzScale(cc) - cc)) else translateContainer(camp, xzScale(cc) - cc) end
    end
  end
end
for _, lane in ipairs(root["02_Roads"].Paths:GetChildren()) do
  for _, part in ipairs(lane:GetDescendants()) do
    if part:IsA("BasePart") then
      local cf = part.CFrame
      local radial = Vector3.new(cf.Position.X, 0, cf.Position.Z).Unit
      local s = part.Size
      if math.abs(cf.LookVector:Dot(radial)) >= math.abs(cf.RightVector:Dot(radial)) then part.Size = Vector3.new(s.X, s.Y, s.Z * K) else part.Size = Vector3.new(s.X * K, s.Y, s.Z) end
      part.CFrame = cf - cf.Position + xzScale(cf.Position)
    end
  end
end
local function slideChildren(container)
  for _, child in ipairs(container:GetChildren()) do
    if child:IsA("Model") then
      local c = centerOf(child)
      if c then child:PivotTo(child:GetPivot() + (xzScale(c) - c)) end
    elseif child:IsA("BasePart") then
      local p = child.Position
      child.CFrame = child.CFrame - p + xzScale(p)
    elseif child:IsA("Folder") then slideChildren(child) end
  end
end
slideChildren(env.Decor)
for _, child in ipairs(env.Environment:GetChildren()) do
  if child:IsA("Folder") then slideChildren(child)
  elseif child:IsA("BasePart") and child.Name == "Cylinder" then
    child.Size = Vector3.new(child.Size.X * K, child.Size.Y, child.Size.Z * K)
    local p = child.Position
    child.CFrame = child.CFrame - p + xzScale(p)
  end
end
for _, wall in ipairs(env.MapBorder:GetChildren()) do
  if wall:IsA("BasePart") then
    local p = wall.Position
    wall.Size = Vector3.new(wall.Size.X * K, wall.Size.Y, wall.Size.Z)
    wall.CFrame = wall.CFrame - p + xzScale(p)
  end
end
root:SetAttribute("MapRadialScale", (root:GetAttribute("MapRadialScale") or 1) * K)
ChangeHistoryService:SetWaypoint("After map radial scale " .. K)
