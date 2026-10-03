-- Isolated native GUI fixture. Does not change gameplay or saved data.
local player=game.Players.LocalPlayer
local Focus=require(player.PlayerScripts.PetRoll.GuideFocus)
local Theme=require(player.PlayerScripts.PetRoll.UITheme)
local run=game:GetService("RunService")
local function layoutFrames() for _=1,3 do run.RenderStepped:Wait() end end
local host=Theme.Container(player.PlayerGui.PetRollGui.Shell.OTHER,"ArrowTestFixture")
local holder=Theme.Container(host,"Holder")
local button=Instance.new("TextButton")
button.Name,button.Text="Target","Test target"
button.Position,button.Size,button.Parent=UDim2.fromScale(.45,.45),UDim2.fromScale(.14,.12),holder
local focus=Focus.new(host)
local checks={}
local function check(ok,name) assert(ok,name);table.insert(checks,name) end
local ok,err=pcall(function()
 layoutFrames()
 focus:SetTarget(button,false)
 for _=1,20 do if focus.masks[1].BackgroundTransparency<.3 then break end;run.RenderStepped:Wait() end
 check(focus.root.Visible and focus.pointer.Visible,"Spotlight and arrow appear")
 local p,s=button.AbsolutePosition,button.AbsoluteSize
 local center=p+s/2
 local w=focus.window
 check(w.AbsolutePosition.X<=p.X and w.AbsolutePosition.Y<=p.Y and w.AbsolutePosition.X+w.AbsoluteSize.X>=p.X+s.X and w.AbsolutePosition.Y+w.AbsoluteSize.Y>=p.Y+s.Y,"Cutout contains the actual button")
 for _,mask in focus.masks do
  local a,b=mask.AbsolutePosition,mask.AbsolutePosition+mask.AbsoluteSize
  check(not (center.X>a.X and center.X<b.X and center.Y>a.Y and center.Y<b.Y),"Mask leaves button center clear: "..mask.Name)
  check(not mask.Active and not mask.Selectable,"Mask does not capture input: "..mask.Name)
 end
 check(focus.masks[1].BackgroundTransparency<.3,"Background fades dark")
 local bounce=focus.bounce
 for _=1,20 do focus:SetTarget(button,false) end
 check(focus.bounce==bounce,"Snapshots preserve running arrow tween")
 local old=w.AbsolutePosition
 button.Position=UDim2.fromScale(.6,.55)
 layoutFrames()
 check((w.AbsolutePosition-old).Magnitude>10,"Cutout follows moving target")
 holder.Visible=false
 layoutFrames()
 check(not focus.root.Visible,"Hidden ancestors remove spotlight")
 holder.Visible=true
 layoutFrames()
 check(focus.root.Visible,"Spotlight resumes when target reappears")
 button.Position=UDim2.fromScale(2,2)
 layoutFrames()
 check(not focus.root.Visible,"Off-screen target never leaves a dark empty screen")
 button.Position=UDim2.fromScale(.45,.45)
 layoutFrames()
 focus:SetTarget(button,true)
 check(not focus.bounce and not focus.pulse and focus.arrow.Position==UDim2.fromScale(.5,.5),"Reduced motion is static")
 focus:SetTarget(nil,false)
 for _=1,20 do if not focus.root.Visible then break end;run.RenderStepped:Wait() end
 check(not focus.root.Visible,"Spotlight fades away at handoff")
 focus:SetTarget(button,false)
 button:Destroy()
 layoutFrames()
 check(not focus.root.Visible,"Destroyed target clears overlay")
end)
focus:Destroy();host:Destroy()
assert(ok,err)
return {passed=#checks,checks=checks,viewport=tostring(workspace.CurrentCamera.ViewportSize),scope="Temporary fixture removed; no profile changes"}
