assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning(),"Edit-only canonical place")
local gui=game.StarterGui.PetRollGui
local control=gui.MenuLayouts.MyArmy
local savedSize=control.Size
local Layout=require(game.ServerStorage.UIAuthoringPreview.PreviewCode.MenuLayout)
local cases={}
for _,viewport in {Vector2.new(1920,1080),Vector2.new(1280,720),Vector2.new(1024,768),Vector2.new(844,390),Vector2.new(390,844)} do
 local w,h=Layout.Size(gui,"Army",viewport)
 table.insert(cases,{viewport=viewport,w=w,h=h})
end
local report={}
local baseline,baselineText
local function rect(node,root,scale)
 local p=(node.AbsolutePosition-root.AbsolutePosition)/scale
 local s=node.AbsoluteSize/scale
 return {x=p.X,y=p.Y,w=s.X,h=s.Y}
end
local ok,err=pcall(function()
 for _,case in cases do
  control.Size=UDim2.fromOffset(case.w,case.h)
  task.wait(0.15)
  assert(not control:GetAttribute("PreviewError"),control:GetAttribute("PreviewError"))
  local root=control.Preview.ChickenBrowser
  local scale=root.UIScale.Scale
  local inventory=root.ArmyContent.Inventory.InventoryPanel
  local grid=inventory.ChickenInventory
  local cards={}
  for _,node in grid:GetChildren() do if node:IsA("GuiButton") and node.Visible then table.insert(cards,node) end end
  table.sort(cards,function(a,b) return a.LayoutOrder<b.LayoutOrder end)
  local firstRow=0
  for _,card in cards do if math.abs(card.AbsolutePosition.Y-cards[1].AbsolutePosition.Y)<1 then firstRow+=1 end end
  assert(firstRow==4,"Expected four columns")
  local detail=root.ArmyContent.SelectedChicken
  assert(detail.Visible and inventory.Visible,"Both panes must stay visible")
  local actual={inventory=rect(inventory,root,scale),detail=rect(detail,root,scale),first=rect(cards[1],root,scale),fourth=rect(cards[4],root,scale)}
  local textSizes={}
  for _,node in root:GetDescendants() do
   if node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox") then textSizes[node:GetFullName():sub(#root:GetFullName()+1)]=node.TextSize end
  end
  if baselineText then
   for name,value in textSizes do assert(math.abs(value-(baselineText[name] or value))<0.01,"Text rescaled independently: "..name) end
  else baselineText=textSizes end
  local drift=0
  if baseline then
   for name,bounds in actual do for k,value in bounds do drift=math.max(drift,math.abs(value-baseline[name][k])) end end
   assert(drift<2,"Layout drift exceeds pixel rounding: "..drift)
  else baseline=actual end
  assert(math.abs(root.AbsoluteSize.X/root.AbsoluteSize.Y-1274/876)<0.001,"Aspect changed")
  assert(case.w<=case.viewport.X-24+0.01 and case.h<=case.viewport.Y-24+0.01,"Menu exceeds safe bounds")
  table.insert(report,{viewport={case.viewport.X,case.viewport.Y},panel={case.w,case.h},scale=scale,firstRow=firstRow,inspectorVisible=detail.Visible,textSizesStable=true,maxCanvasPixelDrift=drift,bounds=actual})
 end
end)
control.Size=savedSize
task.wait(0.15)
assert(control.Size==savedSize,"Saved size not restored")
if not ok then error(err) end
return {passed=true,placeId=game.PlaceId,mode="Edit preview",savedSizeRestored=tostring(savedSize),cases=report}

