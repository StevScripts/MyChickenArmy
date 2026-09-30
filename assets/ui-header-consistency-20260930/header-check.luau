assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning())
local menus=game.StarterGui.PetRollGui.MenuLayouts
local originalSize,originalPosition,originalAnchor=menus.Size,menus.Position,menus.AnchorPoint
local report={cases={},errors={}}
local ok,err=pcall(function()
 menus.Position,menus.AnchorPoint=UDim2.new(),Vector2.zero
 for _,viewport in {Vector2.new(1280,720),Vector2.new(844,390)} do
  menus.Size=UDim2.fromOffset(viewport.X,viewport.Y)
  task.wait(0.1)
  local case={viewport=tostring(viewport),menus={}}
  for _,menu in menus:GetChildren() do
   if not menu:IsA("Frame") then continue end
   local header=menu:FindFirstChild("Header",true)
   assert(header,menu.Name..": missing header")
   assert(not menu:GetAttribute("PreviewError"),menu.Name..": preview error")
   assert(math.abs(header.AbsoluteSize.X/header.AbsoluteSize.Y-1474/83)<0.0001,menu.Name..": header shape")
   local close=header.Close
   assert(math.abs(close.AbsoluteSize.X/close.AbsoluteSize.Y-86/82)<0.0001,menu.Name..": close shape")
   assert(header.Title.AbsolutePosition.X+header.Title.AbsoluteSize.X<close.AbsolutePosition.X,menu.Name..": title overlaps X")
   local body=header.Parent:FindFirstChild("ArmyContent") or header.Parent:FindFirstChild("Main")
   assert(body,menu.Name..": missing body")
   assert(body.AbsolutePosition.Y>=header.AbsolutePosition.Y+header.AbsoluteSize.Y,menu.Name..": body overlaps header")
   for _,node in header:GetDescendants() do
    assert(not node:IsA("UIScale") and not node:IsA("UISizeConstraint") and not node:IsA("UITextSizeConstraint"),menu.Name..": forbidden constraint")
    if node:IsA("GuiObject") then
     assert(node.Size.X.Offset==0 and node.Size.Y.Offset==0 and node.Position.X.Offset==0 and node.Position.Y.Offset==0,menu.Name..": offset layout")
    end
   end
   case.menus[menu.Name]={header={header.AbsoluteSize.X,header.AbsoluteSize.Y},close={close.AbsoluteSize.X,close.AbsoluteSize.Y}}
  end
  table.insert(report.cases,case)
 end
end)
menus.Size,menus.Position,menus.AnchorPoint=originalSize,originalPosition,originalAnchor
menus:SetAttribute("PreviewMenu","MyArmy")
if not ok then error(err) end
report.passed=true
return game:GetService("HttpService"):JSONEncode(report)
