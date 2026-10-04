-- Run in the temporary StrokeFixture client, never a player profile.
local f=_G.StrokeFixture
local focus,target=f.focus,f.target
local run=game:GetService("RunService")
local function frames(n) for i=1,n or 3 do run.RenderStepped:Wait() end end
local checks={}
local function check(ok,name) assert(ok,name);table.insert(checks,name) end
frames()
check(focus.dim.Parent==focus.window and focus.window.BackgroundTransparency==1,"One clear frame owns the shading stroke")
check(focus.root:FindFirstChild("Top")==nil and focus.masks==nil,"No four-frame mask")
check(focus.dim.Thickness>=10000,"Huge stroke covers beyond every screen edge")
check(math.abs(focus.dim.Transparency-.5)<.001,"Exact requested 0.5 transparency")
check(focus.dim.BorderStrokePosition==Enum.BorderStrokePosition.Outer,"Outer stroke cannot cover the target interior")
check(focus.dim.LineJoinMode==Enum.LineJoinMode.Miter,"Square joined corners")
check(not focus.window.Active and not focus.window.Selectable,"Spotlight does not intercept input")
check(focus.arrow:IsA("ImageLabel") and focus.arrow.IsLoaded,"Generated arrow image loaded")
local bounce=focus.bounce
for i=1,20 do focus:SetTarget(target,false) end
check(focus.bounce==bounce,"Repeated state updates preserve motion")
for _,pos in {Vector2.new(.01,.01),Vector2.new(.84,.01),Vector2.new(.01,.86),Vector2.new(.84,.86)} do
 target.Position=UDim2.fromScale(pos.X,pos.Y);frames()
 local p,s=target.AbsolutePosition,target.AbsoluteSize
 local a,b=focus.window.AbsolutePosition,focus.window.AbsoluteSize
 check(focus.root.Visible and a.X<=p.X and a.Y<=p.Y and a.X+b.X>=p.X+s.X-1 and a.Y+b.Y>=p.Y+s.Y-1,"Clear frame tracks corner "..tostring(pos))
end
target.Visible=false;frames()
check(not focus.root.Visible,"Hidden target clears spotlight")
target.Visible=true;frames()
check(focus.root.Visible,"Visible target restores spotlight")
target.Position=UDim2.fromScale(2,2);frames()
check(not focus.root.Visible,"Offscreen target clears spotlight")
target.Position=UDim2.fromScale(.45,.45);frames()
focus:SetTarget(target,true)
check(not focus.bounce and not focus.pulse and math.abs(focus.dim.Transparency-.5)<.001,"Reduced motion stays static")
focus:SetTarget(nil,false);frames(8)
check(not focus.root.Visible and focus.dim.Transparency==1,"Handoff fades out the stroke")
focus:SetTarget(target,false);focus:SetTarget(nil,false);focus:SetTarget(target,false);frames(8)
check(focus.root.Visible and math.abs(focus.dim.Transparency-.5)<.001,"Rapid handoff cancels stale fade-out")
return {checks=checks,passed=#checks,viewport=tostring(workspace.CurrentCamera.ViewportSize)}
