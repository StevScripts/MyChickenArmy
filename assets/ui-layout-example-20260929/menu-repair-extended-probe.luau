local player=game:GetService("Players").LocalPlayer
local http=game:GetService("HttpService")
local Class=require(player.PlayerScripts.PetRoll.AppController)
local app
local original=Class.Receive
Class.Receive=function(self,...)
 app=self
 return original(self,...)
end
local deadline=os.clock()+12
while not app and os.clock()<deadline do task.wait(0.1) end
Class.Receive=original
if not app then script:SetAttribute("Error","No state packet observed");return end
local records={}
local function check(name,body)
 local ok,why=xpcall(body,debug.traceback)
 table.insert(records,{name=name,passed=ok,error=if not ok then why else nil})
end
local merge=app.mergeBrowser
local nearStand=merge and merge.NearStand
if merge then merge.NearStand=function() return true end end
check("Fuse window and picker (presentation fixture at stand)",function()
 assert(merge,"Fuse browser missing")
 app:OpenPage("Merge")
 task.wait(0.35)
 assert(app.panel.Visible and merge.root.Visible and merge.main.Visible,"Fuse did not open")
 assert(merge.root.AbsoluteSize.X>0 and merge.root.AbsoluteSize.Y>0,"Fuse has no bounds")
 merge.mode="Picker";merge:Render(true)
 task.wait(0.1)
 assert(merge.picker.Visible and merge.back.Visible,"Picker did not open")
 merge.mode="Main";merge:Render(true)
 app:ClosePanel();task.wait(0.3)
 assert(not app.panel.Visible,"Fuse did not close")
end)
if merge then merge.NearStand=nearStand end
local seen=app.offlineCash.seen
check("Offline receipt under the single root (display-only fixture)",function()
 app.offlineCash:Receive({offlineCash={id="menu-repair-display-only",amount=12345}})
 task.wait(0.35)
 local receipt=app.offlineCash.gui
 assert(receipt and receipt:IsA("Frame"),"Receipt created another GUI or did not open")
 assert(receipt:IsDescendantOf(app.gui),"Receipt is outside main GUI")
 local area=game:GetService("GuiService"):GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
 assert((receipt.AbsolutePosition-area.Min).Magnitude<1,"Receipt inset origin is incorrect")
 assert((receipt.AbsoluteSize-(area.Max-area.Min)).Magnitude<1,"Receipt inset bounds are incorrect")
 assert(receipt:FindFirstChild("Continue",true),"Continue is missing")
 app.offlineCash:Dismiss();task.wait(0.3)
 assert(not app.offlineCash.gui,"Receipt did not dismiss")
end)
app.offlineCash:Dismiss(true);app.offlineCash.seen=seen
check("Transient drag layer and topbar use their original coordinate regions",function()
 local Theme=require(player.PlayerScripts.PetRoll.UITheme)
 local layer=Theme.InsetContainer(app.other,"MenuRepairDragFixture",Enum.ScreenInsets.None)
 task.wait()
 local area=game:GetService("GuiService"):GetInsetArea(Enum.ScreenInsets.None)
 local aligned=(layer.AbsolutePosition-area.Min).Magnitude<1
 layer:Destroy()
 assert(aligned,"Drag origin is shifted")
 local topbar=game:GetService("GuiService"):GetInsetArea(Enum.ScreenInsets.TopbarSafeInsets)
 assert((app.hud.settingsGui.AbsolutePosition-topbar.Min).Magnitude<1,"Topbar origin is shifted")
end)
script:SetAttribute("Results",http:JSONEncode(records))
app:ClosePanel()

