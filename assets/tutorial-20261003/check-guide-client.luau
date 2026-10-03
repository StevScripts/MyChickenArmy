-- Run in the Studio client. UI-only fixtures, inside the existing ScreenGui.
local player=game.Players.LocalPlayer
local Commander=require(player.PlayerScripts.PetRoll.CommanderGuide)
local gui=player.PlayerGui.PetRollGui
local real=gui:FindFirstChild("CommanderGuide",true)
local host=Instance.new("Frame");host.Name="CommanderLayoutCheck";host.Size=UDim2.fromScale(1,1);host.BackgroundTransparency=1;host.Parent=gui.Shell.OTHER
local panel=Instance.new("Frame");panel.Visible=false;panel.Parent=host
local tree=Instance.new("Frame");tree.Visible=false;tree.Parent=host
local shortcuts=Instance.new("Frame");shortcuts.Parent=host
local upgrade=Instance.new("TextButton");upgrade.Name="Upgrades";upgrade.Parent=shortcuts
local best=Instance.new("TextButton");best.Parent=host
local requests={}
local app={other=host,panel=panel,page="",reducedMotion=true,research={root=tree},hud={shortcuts=shortcuts,army=best},chickenBrowser={best=best},Request=function(_,action,params) table.insert(requests,params.signal) end,Notify=function() end}
local g=Commander.new(app);g.root.Name="GuideFixture"
local checks={}
local function base()
 return {tutorial={guideStarted=true},pets={{},{},{},{}},coins=2400,capacity=3,selectedCount=3,eggs={carriedCount=0,carriedValue=0},armyState="Home",saveStatus="studio-session",offer={price=600},nextSlot={price=1200}}
end
local function inspect(label,state,help)
 app.state=state;g.step=nil;g:Update();if help then g:Help(false) end
 game:GetService("RunService").RenderStepped:Wait()
 for _,n in g.root:GetDescendants() do
  if (n:IsA("TextLabel") or n:IsA("TextButton")) and n.Text~="" then assert(n.TextFits,label.." clipped "..n.Name) end
  assert(not n:IsA("UIScale"),"No scripted device scaling")
 end
 assert(g.skip.AbsoluteSize.X>=44 and g.skip.AbsoluteSize.Y>=44,"Skip target below 44px")
 table.insert(checks,label)
end
local s=base();inspect("Recruit",s);inspect("Recruit help",s,true)
s.tutorial.bought=true;inspect("Collect",s);inspect("Collect help",s,true)
s.eggs.carriedCount=1;s.eggs.carriedValue=20;inspect("Sell",s);inspect("Sell help",s,true)
s.tutorial.soldEggs=true;inspect("Expand",s);inspect("Expand help",s,true)
assert(g.focus and not g.pulse,"Reduced motion keeps a static outline")
s.capacity=4;inspect("Select",s);inspect("Select help",s,true)
s.selectedCount=4;inspect("Deploy",s);inspect("Deploy help",s,true)
s.outgoing="fixture";inspect("Battle",s);inspect("Battle help",s,true)
s.outgoing=nil;s.tutorial.wonCamp=true;s.tutorial.guideCompleted=true;inspect("Complete",s)
g.stepAt=os.clock()-9;g:Update();assert(not g.root.Visible and table.find(requests,"Finish"),"Completion dismisses itself")
table.insert(checks,"Complete dismisses after eight seconds")
g:Destroy();assert(g.root.Parent==nil and g.focus==nil and g.pulse==nil,"Cleanup releases guide and highlight")
table.insert(checks,"Guide cleanup")
local returning=Commander.new(app);returning:Update();assert(not returning.root.Visible,"Saved completion must not replay")
returning:Destroy();table.insert(checks,"Saved completion stays hidden")
host:Destroy()
return {viewport=tostring(workspace.CurrentCamera.ViewportSize),touch=game:GetService("UserInputService").TouchEnabled,passed=#checks,checks=checks,scope="Native UI-only fixtures in the existing game ScreenGui; all fixtures removed"}
