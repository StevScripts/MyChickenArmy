-- UI fixtures only: native layout, interruption, snapshot stability and cleanup.
local p=game.Players.LocalPlayer
local Commander=require(p.PlayerScripts.PetRoll.CommanderGuide)
local Theme=require(p.PlayerScripts.PetRoll.UITheme)
local host=Instance.new("Frame");host.Name="CommanderPolishCheck";host.Size=UDim2.fromScale(1,1);host.BackgroundTransparency=1;host.Parent=p.PlayerGui.PetRollGui.Shell.OTHER
local panel=Instance.new("Frame");panel.Visible=false;panel.Parent=host
local tree=panel:Clone();tree.Parent=host
local toast=panel:Clone();toast.Parent=host
local shortcuts=Instance.new("Frame");shortcuts.Parent=host
local upgrade=Instance.new("TextButton");upgrade.Name="Upgrades";upgrade.Parent=shortcuts
local best=upgrade:Clone();best.Parent=host
local app={other=host,panel=panel,toastFrame=toast,page="",reducedMotion=false,research={root=tree},hud={shortcuts=shortcuts,army=best},chickenBrowser={best=best},Request=function() end,Notify=function() end}
app.state={tutorial={guideStarted=true},pets={{},{},{}},coins=2400,capacity=3,selectedCount=3,eggs={carriedCount=0,carriedValue=0},armyState="Home",saveStatus="studio-session",offer={price=600},nextSlot={price=1200}}
local g=Commander.new(app);g:Update()
local track=Theme.Motion.tracks[g.card] and Theme.Motion.tracks[g.card]["guide-enter"]
assert(track,"Entry tween exists")
for _=1,20 do g:Update() end
assert(Theme.Motion.tracks[g.card]["guide-enter"]==track,"Snapshots must not restart entry")
toast.Visible=true;g:Update();assert(not g.card.Visible and not Theme.Motion.tracks[g.card],"Notification interrupts entry cleanly")
toast.Visible=false;g:Update();app.reducedMotion=true;g:Update()
assert(not Theme.Motion.tracks[g.card] and g.card.Position==UDim2.fromScale(.5,.005),"Reduced motion cancels and settles")
local run=game:GetService("RunService");run.RenderStepped:Wait()
local size=g.card.AbsoluteSize
local viewport=workspace.CurrentCamera.ViewportSize
assert(g.skip.AbsoluteSize.X>=48 and g.skip.AbsoluteSize.Y>=48,"Skip touch target >=48")
assert(g.help.AbsolutePosition.X+g.help.AbsoluteSize.X<=g.skip.AbsolutePosition.X,"Help and Skip do not overlap")
for _,n in g.root:GetDescendants() do
 assert(not n:IsA("UIScale") and not n:IsA("UISizeConstraint") and not n:IsA("UITextSizeConstraint"),"Native composition only")
 if n:IsA("TextLabel") or n:IsA("TextButton") then assert(n.TextFits,"Clipped text: "..n.Name) end
end
local titlePosition=g.title.AbsolutePosition
g:Help(false);run.RenderStepped:Wait()
assert((g.title.AbsolutePosition-titlePosition).Magnitude<.01,"Help keeps the title stationary")
assert(g.reason.TextFits,"Help fits")
g:Help(true);assert(not g.hint,"Help toggles closed")
g.stepAt=os.clock()-40;g:Update();assert(not g.hint,"Closed help does not reopen automatically")
tree.Visible=true;g:Update();assert(not g.card.Visible,"Guide yields to full-screen research")
tree.Visible=false;panel.Visible=true;g:Update();assert(not g.card.Visible,"Guide yields to menus")
panel.Visible=false;g:Update()
app.state.tutorial.bought=true;g:Update();assert(g.current.id=="Collect","Real step advances")
app.state.tutorial.soldEggs=true;app.state.tutorial.collectedEggs=true;g:Update();assert(g.focus and not g.pulse,"Reduced focus is static")
app.reducedMotion=false;g:Update();assert(g.pulse,"Normal focus pulses")
local card=g.card;g:Destroy();assert(not Theme.Motion.tracks[card] and g.focus==nil and g.pulse==nil,"Destruction clears tweens and focus")
host:Destroy()
return {passed=14,viewport=tostring(viewport),card=tostring(size),normalBoundingAreaPercent=100*size.X*size.Y/(viewport.X*viewport.Y),scope="Temporary UI fixtures removed; no gameplay or profile changes"}
