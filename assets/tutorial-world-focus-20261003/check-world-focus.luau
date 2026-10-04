local p=game.Players.LocalPlayer
local Focus=require(p.PlayerScripts.PetRoll.GuideFocus)
local Theme=require(p.PlayerScripts.PetRoll.UITheme)
local EggView=require(p.PlayerScripts.PetRoll.EggView)
local run=game:GetService("RunService")
local cam=workspace.CurrentCamera
local savedFrame,savedType=cam.CFrame,cam.CameraType
local host=Theme.Container(p.PlayerGui.PetRollGui.Shell.OTHER,"WorldFocusFixture")
local focus=Focus.new(host)
local folder=Instance.new("Folder");folder.Name="WorldFocusFixture";folder.Parent=workspace
local part=Instance.new("Part");part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.Size=Vector3.new(3,5,2);part.CFrame=CFrame.new(310,15,-170)*CFrame.Angles(.1,.7,.2);part.Parent=folder
local checks={}
local function frames() for i=1,3 do run.PreRender:Wait() end end
local function check(ok,name) assert(ok,name);table.insert(checks,name) end
local function surrounds(items)
 local a,b=focus.window.AbsolutePosition,focus.window.AbsoluteSize
 local inset=game:GetService("GuiService"):GetGuiInset()
 for _,item in items do
  for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
   local q=cam:WorldToViewportPoint(item.CFrame:PointToWorldSpace(item.Size*Vector3.new(x,y,z)*.5))
   local screen=Vector2.new(q.X,q.Y)-inset
   if screen.X<a.X-1 or screen.Y<a.Y-1 or screen.X>a.X+b.X+1 or screen.Y>a.Y+b.Y+1 then return false end
  end end end
 end
 return true
end
local ok,err=xpcall(function()
 cam.CameraType=Enum.CameraType.Scriptable
 cam.CFrame=CFrame.lookAt(part.Position+Vector3.new(9,7,12),part.Position)
 focus:SetTarget(part,false);task.wait(.22);frames()
 check(focus.root.Visible and surrounds({part}),"Rotated item corners stay within the cutout with correct GUI inset")
 check(math.abs(focus.dim.Transparency-.5)<.001 and focus.dim.Thickness>=10000,"Same huge black stroke at 0.5 transparency")
 check(not focus.pointer.Visible and not focus.bounce,"World direction keeps the Beam without another GUI arrow")
 local old=focus.window.AbsoluteSize
 cam.CFrame=CFrame.lookAt(part.Position+Vector3.new(-7,4,8),part.Position)
 frames()
 check(surrounds({part}) and (focus.window.AbsoluteSize-old).Magnitude>1,"Camera orbit and zoom resize the cutout automatically")
 part.CFrame+=Vector3.new(2,0,0);frames()
 check(surrounds({part}),"Moving target follows without SetTarget or manual Layout")
 local home=part.CFrame
 part.CFrame=cam.CFrame*CFrame.new(1000,0,-20);frames()
 check(not focus.root.Visible,"Off-screen target clears shading")
 part.CFrame=cam.CFrame*CFrame.new(0,0,10);frames()
 check(not focus.root.Visible,"Target behind camera clears shading")
 part.CFrame=cam.CFrame*CFrame.new(0,0,-.05);frames()
 check(not focus.root.Visible,"Near-plane crossing cannot produce an inverted cutout")
 part.CFrame=home;frames()
 check(focus.root.Visible and surrounds({part}),"Returning target restores aligned cutout")
 local extra=part:Clone();extra.CFrame=part.CFrame*CFrame.new(2,2,0);extra.Parent=folder
 focus:SetTarget(part,false,{part,extra});frames()
 check(surrounds({part,extra}),"Multi-part item includes handle and base")
 local model=Instance.new("Model");model.Parent=folder;part.Parent=model;extra.Parent=model
 focus:SetTarget(model,true);frames()
 check(focus.root.Visible and surrounds({part,extra}) and not focus.pulse,"Model bounds work with static reduced motion")
 local egg=EggView.new(folder,{id="fixture",value=4,stack=1})
 egg:Set(part.Position,1,0,0)
 focus:SetTarget(egg.gui,true);frames()
 check(focus.root.Visible and focus.window.AbsoluteSize.X>20 and focus.window.AbsoluteSize.Y>20,"Egg spotlight uses visible sprite size, not its tiny invisible anchor")
 egg:Set(part.Position+Vector3.new(1,0,0),1,0,0);frames()
 local pixel=cam:WorldToScreenPoint(egg.anchor.Position)
 local a,b=focus.window.AbsolutePosition,focus.window.AbsoluteSize
 check(pixel.X>=a.X and pixel.X<=a.X+b.X and pixel.Y>=a.Y and pixel.Y<=a.Y+b.Y,"Moving egg remains inside its opening")
 egg.gui.Enabled=false;frames()
 check(not focus.root.Visible,"Hidden egg sprite clears shading")
 local button=Instance.new("TextButton");button.Size=UDim2.fromScale(.15,.1);button.Position=UDim2.fromScale(.4,.4);button.Parent=host
 focus:SetTarget(button,true);frames()
 check(not focus.world and focus.pointer.Visible and focus.root.Visible,"World-to-menu handoff retains the existing GUI pointer")
 focus:SetTarget(part,true);frames();part:Destroy();frames()
 check(focus.target==nil and #focus.targetConnections==0 and not focus.root.Visible,"Destroyed world target disconnects tracking")
 focus:SetTarget(nil,true);frames()
 check(not focus.root.Visible and #focus.targetConnections==0,"Clearing guidance leaves no tracking listener")
 egg:Destroy()
end,debug.traceback)
focus:Destroy();host:Destroy();folder:Destroy()
cam.CFrame=savedFrame;cam.CameraType=savedType
assert(ok,err)
return {passed=#checks,checks=checks,viewport=tostring(cam.ViewportSize)}
