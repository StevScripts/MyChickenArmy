local ps=script.Parent
local Class=require(ps.PetRoll.AppController)
local Layout=require(ps.PetRoll.MenuLayout)
local old=Class.Receive
local app
Class.Receive=function(self,...) app=self;Class.Receive=old;return old(self,...) end
local deadline=os.clock()+12
repeat task.wait() until app or os.clock()>deadline
if not app then Class.Receive=old;script:SetAttribute("Error","No app");return end
local results={}
local oldNear=app.mergeBrowser.NearStand
app.mergeBrowser.NearStand=function() return true end
for _,page in {"Army","Shop","Index","Upgrades","Settings","Odds","Merge"} do
 local ok,err=pcall(function()
  app:OpenPage(page);task.wait(.4)
  local w,h=Layout.Size(app.gui,page,app.gui.AbsoluteSize)
  assert(app.panel.Visible,"Not open")
  assert(math.abs(app.panel.AbsoluteSize.X-w)<2 and math.abs(app.panel.AbsoluteSize.Y-h)<2,"Saved size not used")
  if page=="Army" then assert(app.chickenBrowser.gridLayout.FillDirectionMaxCells==4,"Not four columns") end
  if page=="Index" then local _,card=next(app.indexBrowser.cards);assert(math.abs(card.preview.Size.X.Scale-app.gui.MenuLayouts.Index:GetAttribute("PortraitScale"))<0.00001,"Portrait control ignored") end
  app:ClosePanel();task.wait(.35);assert(not app.panel.Visible,"Did not close")
 end)
 table.insert(results,{page=page,passed=ok,error=if ok then nil else tostring(err)})
end
app.mergeBrowser.NearStand=oldNear
local hidden=not app.gui.MenuLayouts.Visible
local previews=0
for _,c in app.gui.MenuLayouts:GetChildren() do if c:FindFirstChild("Preview") then previews+=1 end end
script:SetAttribute("Results",game:GetService("HttpService"):JSONEncode({menus=results,previewsHidden=hidden,previewCopies=previews}))
local call=Instance.new("BindableFunction");call.Name="OpenShop";call.OnInvoke=function()app:OpenPage("Shop");return true end;call.Parent=script

