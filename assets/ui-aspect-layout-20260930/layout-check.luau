assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning())
local menus=game.StarterGui.PetRollGui.MenuLayouts
local originalSize,originalPosition,originalAnchor=menus.Size,menus.Position,menus.AnchorPoint
local report={cases={},forbidden={},offsets={},maxNormalizedDrift=0}
local baselines={}
local function snapshot(control)
 local out={}
 for _,v in control:GetDescendants() do
  if v:IsA("GuiObject") then
   local s,p=v.AbsoluteSize,v.AbsolutePosition-control.AbsolutePosition
   local base=control.AbsoluteSize
   out[v]={s.X/base.X,s.Y/base.Y,p.X/base.X,p.Y/base.Y}
  end
 end
 return out
end
local ok,err=pcall(function()
 menus.Position,menus.AnchorPoint=UDim2.new(),Vector2.zero
 for _,viewport in {Vector2.new(1920,1080),Vector2.new(1280,720),Vector2.new(1024,768),Vector2.new(844,390),Vector2.new(390,844)} do
  menus.Size=UDim2.fromOffset(viewport.X,viewport.Y)
  task.wait(0.2)
  local case={viewport={viewport.X,viewport.Y},menus={}}
  for _,control in menus:GetChildren() do
   if not control:IsA("Frame") then continue end
   assert(not control:GetAttribute("PreviewError"),control.Name..": preview failed")
   local aspect=control:FindFirstChildWhichIsA("UIAspectRatioConstraint")
   assert(aspect,control.Name..": missing aspect")
   assert(math.abs(control.AbsoluteSize.X/control.AbsoluteSize.Y-aspect.AspectRatio)<0.005,control.Name..": wrong shape")
   local current=snapshot(control)
   local baseline=baselines[control.Name]
   local drift=0
   if baseline then
    for node,values in current do
     for i,v in values do drift=math.max(drift,math.abs(v-baseline[node][i])) end
    end
   else baselines[control.Name]=current end
   report.maxNormalizedDrift=math.max(report.maxNormalizedDrift,drift)
   assert(drift<0.002,control.Name..": layout drift "..drift)
   
   local offenders={}
   if baseline then for node,values in current do for i,v in values do local d=math.abs(v-baseline[node][i]);if d>0.01 then table.insert(offenders,{name=node:GetFullName(),component=i,drift=d}) end end end end
   local item={offenders=offenders,size={control.AbsoluteSize.X,control.AbsoluteSize.Y},maxNormalizedDrift=drift,scrolls={}}
   for _,node in control:GetDescendants() do
    if node:IsA("UIScale") or node:IsA("UISizeConstraint") or node:IsA("UITextSizeConstraint") then table.insert(report.forbidden,node:GetFullName()) end
    if node:IsA("GuiObject") and (node.Size.X.Offset~=0 or node.Size.Y.Offset~=0 or node.Position.X.Offset~=0 or node.Position.Y.Offset~=0) then table.insert(report.offsets,node:GetFullName()) end
    if node:IsA("ScrollingFrame") then
     local old=node.CanvasPosition
     node.CanvasPosition=Vector2.new(0,100000)
     task.wait()
     local maximum=math.max(0,node.AbsoluteCanvasSize.Y-node.AbsoluteWindowSize.Y)
     assert(math.abs(node.CanvasPosition.Y-maximum)<2,node.Name..": scroll end inaccessible")
     node.CanvasPosition=old
     table.insert(item.scrolls,{name=node.Name,extent=maximum})
    end
   end
   case.menus[control.Name]=item
  end
  table.insert(report.cases,case)
 end
 assert(#report.forbidden==0 and #report.offsets==0,"Found nonnative layout components")
end)
menus.Size,menus.Position,menus.AnchorPoint=originalSize,originalPosition,originalAnchor
menus:SetAttribute("PreviewMenu","MyArmy")
if not ok then error(err) end
report.passed=true
return report
