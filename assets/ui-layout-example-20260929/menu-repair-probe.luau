local player=game:GetService("Players").LocalPlayer
local http=game:GetService("HttpService")
local scripts=player:WaitForChild("PlayerScripts")
local Class=require(scripts.PetRoll.AppController)
local app
local original=Class.Receive
Class.Receive=function(self,...)
 app=self
 return original(self,...)
end
script:SetAttribute("Ready",true)
local deadline=os.clock()+10
while not app and os.clock()<deadline do task.wait(0.1) end
Class.Receive=original
if not app then script:SetAttribute("Error","No state packet observed");return end
local wire=Instance.new("BindableFunction")
wire.Name="MenuRepairCommand"
wire.OnInvoke=function(command)
 if command=="Run" then
  local records={}
  for _,page in {"Army","Shop","Index","Upgrades","Settings","Odds","Merge"} do
   local ok,why=xpcall(function()
    app:OpenPage(page)
    task.wait(0.35)
    assert(app.panel.Visible and app.backdrop.Visible,"Window did not open")
    local view=({Army=app.chickenBrowser.root,Shop=app.shopBrowser.root,Index=app.indexBrowser.root,Upgrades=app.progression.root,Merge=app.mergeBrowser and app.mergeBrowser.root})[page] or app.content
    assert(view.Visible and view.AbsoluteSize.X>0 and view.AbsoluteSize.Y>0,"Content is not visible")
    local children=0
    for _,child in view:GetDescendants() do if child:IsA("GuiObject") then children+=1 end end
    assert(children>0,"Page content is empty")
    table.insert(records,{page=page,opened=true,size=tostring(app.panel.AbsoluteSize),contentObjects=children})
    app:ClosePanel()
    task.wait(0.3)
    assert(not app.panel.Visible and not app.backdrop.Visible,"Window did not close")
    records[#records].closed=true
   end,debug.traceback)
   if not ok then table.insert(records,{page=page,error=why}) end
  end
  script:SetAttribute("Results",http:JSONEncode(records))
  return script:GetAttribute("Results")
 elseif command=="OpenArmy" then app:OpenPage("Army");return "Army opened"
 elseif command=="OpenShop" then app:OpenPage("Shop");return "Shop opened"
 elseif command=="OpenIndex" then app:OpenPage("Index");return "Index opened"
 elseif command=="Close" then app:ClosePanel();return "Closed"
 end
end
wire.Parent=script
script:SetAttribute("Captured",true)

