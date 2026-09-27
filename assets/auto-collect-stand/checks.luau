-- Isolated Edit-mode checks. Fake commerce/player; no marketplace call or saved data.
local modules=game.StarterPlayer.StarterPlayerScripts.PetRoll
local function fresh(name)
	local module=modules:FindFirstChild(name)
	return assert(loadstring("local script=...\n"..module.Source))(module)
end
local Stand,Commerce=fresh("AutoCollectStandController"),fresh("CommerceController")
local fixture=Instance.new("Folder"); fixture.Name="AutoCollectStandCheck"; fixture.Parent=workspace
local plot=Instance.new("Folder"); plot.Name="Plot1"; plot:SetAttribute("PlotIndex",1); plot.Parent=fixture
local props=Instance.new("Folder"); props.Name="Props"; props.Parent=plot
local source=workspace.MyChickenArmyMap["03_HomePlots"].Plot1.Props.Gamepass:Clone()
source:PivotTo(CFrame.new(0,5000,0)); source.Parent=props
local guiRoot=Instance.new("Folder"); guiRoot.Parent=fixture
local now,requested,prompted,reloaded=0,{},0,0
local player={UserId=-999}
local app={reducedMotion=false,state={plotIndex=1,shop={ready=true,owned={},automatic={AutoCollectEggs=false}}},
	panel={Visible=false},Notify=function() end}
function app:Request(action,payload)
	table.insert(requested,{action=action,payload=payload}); return #requested
end
local commerce=Commerce.new(app,{player=player,clock=function() return now end,delay=function() end,
	marketplace={PromptGamePassPurchase=function(_,target,id)
		assert(target==player and id==1978713718,"wrong checkout target"); prompted+=1
	end}})
commerce.products.AutoCollectEggs={status="ready",price=347,at=0}
app.commerce=commerce
local board=Stand.new(app); board.world=fixture; board.playerGui=guiRoot
local results={}
local function check(name,passed) assert(passed,name); table.insert(results,name) end
local function visit(contact,inside,status,time,blocked)
	now=time; board:Visit(board.views[source],contact,inside,status,time,blocked or false)
end
local ok,err=xpcall(function()
	board:Bind(source); board:Bind(source)
	local view=board.views[source]
	check("authored stand binds exactly once",view~=nil and #guiRoot:GetChildren()==1)
	board:Render(view,commerce:State("AutoCollectEggs"))
	check("price comes from commerce, not proposed catalog price",view.gui.Price.Text==utf8.char(0xE002).." 347")
	visit(true,true,"ready",0)
	check("touch sends one existing PreparePurchase request",#requested==1 and requested[1].action=="PreparePurchase" and requested[1].payload.key=="AutoCollectEggs")
	check("native checkout waits for server preparation",prompted==0)
	commerce:Receive({action="PreparePurchase",id=1,ok=true,purchase={key="AutoCollectEggs",kind="Pass",id=1978713718}})
	check("validated response opens correct native gamepass",prompted==1)
	visit(true,true,"pending",1,true)
	commerce.pending=nil -- Cancelled native checkout; no entitlement was granted.
	visit(true,true,"ready",10)
	check("cancel while standing cannot reopen",#requested==1 and app.state.shop.owned.AutoCollectEggs==nil)
	visit(false,true,"ready",11); visit(true,true,"ready",12)
	check("jump in same footprint cannot reopen",#requested==1)
	visit(false,false,"ready",13); visit(true,true,"ready",14)
	check("leaving and returning permits another request",#requested==2)
	commerce.pending=nil
	visit(false,false,"ready",14.1); visit(true,true,"ready",14.2)
	check("rapid reentry is throttled",#requested==2)
	visit(false,false,"ready",20); visit(true,true,"ready",21,true); visit(true,true,"ready",22,false)
	check("menu-blocked visit does not prompt on menu close",#requested==2)
	visit(false,false,"ready",23)
	app.state.shop.owned.AutoCollectEggs=true
	board:Render(view,commerce:State("AutoCollectEggs"))
	visit(true,true,"owned",24)
	check("owned replaces price and never purchases",view.gui.Price.Text=="Owned" and #requested==2)
	check("owned preserves disabled Auto Collect setting",not app.state.shop.automatic.AutoCollectEggs and view.gui.Hint.Text=="Enable in Shop")
	app.state.shop.automatic.AutoCollectEggs=true; board:Render(view,"owned")
	check("enabled ownership is described accurately",view.gui.Hint.Text=="Auto Collect is on")
	app.state.shop.owned.AutoCollectEggs=nil
	for _,status in {"loading","checking","offsale","unconfigured"} do
		visit(false,false,status,30); visit(true,true,status,31)
		board:Render(view,status)
		check(status.." does not buy or show a fake price",#requested==2 and not view.gui.Price.Text:find("347",1,true))
	end
	local originalLoad=commerce.Load
	commerce.Load=function(_,key,force) assert(key=="AutoCollectEggs" and force); reloaded+=1 end
	visit(false,false,"error",32); visit(true,true,"error",33); visit(true,true,"error",34)
	check("price error retries once per visit",reloaded==1)
	commerce.Load=originalLoad
	visit(false,false,"ownership",35); visit(true,true,"ownership",36); visit(true,true,"ownership",37)
	check("ownership error refreshes once without purchase",#requested==3 and requested[3].action=="RefreshShop")
	local basePart
	for _,item in source:GetChildren() do if item:IsA("BasePart") and item~=view.pad and item.Transparency==0 then basePart=item end end
	local baseFrame=basePart.CFrame
	board:SetPressed(view,true); task.wait(0.35)
	check("pad depresses by 0.18 studs",math.abs(view.pad.Position.Y-(view.padFrame.Position.Y-0.18))<0.005)
	check("base stays still when pad depresses",(basePart.Position-baseFrame.Position).Magnitude<0.001)
	board:SetPressed(view,false); task.wait(0.2)
	check("pad returns after leaving",(view.pad.Position-view.padFrame.Position).Magnitude<0.005)
	board:SetMotion(view,true); task.wait(0.25)
	check("normal tweens drive rotation and bob",view.yaw.Value>0 and view.bob.Value>0)
	check("spin and bob loop with native repeat/reverse",view.spin.TweenInfo.RepeatCount==-1 and view.hover.TweenInfo.Reverses and view.hover.TweenInfo.RepeatCount==-1)
	board:SetMotion(view,false)
	app.reducedMotion=true; board:SetPressed(view,true)
	check("reduced motion restores pad and preview",(view.pad.Position-view.padFrame.Position).Magnitude<0.005 and view.yaw.Value==0 and view.bob.Value==0)
	local character=Instance.new("Model"); character.Parent=fixture
	local root=Instance.new("Part"); root.Name="HumanoidRootPart"; root.Size=Vector3.new(2,2,1)
	root.Anchored,root.CanCollide=true,false; root.Parent=character
	root.CFrame=view.padFrame*CFrame.new(0,view.pad.Size.Y/2+3,0)
	local hum={Health=100,HipHeight=2,FloorMaterial=Enum.Material.Plastic,
		GetState=function() return Enum.HumanoidStateType.Running end}
	local contact,inside=board:Contact(view,root,hum)
	check("actual supporting pad is detected even in reduced motion",contact and inside)
	hum.Jump=true; contact,inside=board:Contact(view,root,hum)
	check("jump stops contact but keeps visit latched",not contact and inside)
	hum.Jump=false; root.CFrame=view.padFrame*CFrame.new(view.pad.Size.X+1,3,0)
	contact,inside=board:Contact(view,root,hum)
	check("outside footprint rejects contact",not contact and not inside)
	root.CFrame=view.padFrame*CFrame.new(0,view.pad.Size.Y/2+3,0)
	local blocker=Instance.new("Part");blocker.Size=Vector3.new(2,0.2,2);blocker.Anchored=true
	blocker.CFrame=view.padFrame*CFrame.new(0,1,0);blocker.Parent=fixture
	contact=board:Contact(view,root,hum)
	check("standing on another object over the pad does not purchase",not contact)
	board:Unbind(source)
	check("unbind restores source UI and destroys local display",#guiRoot:GetChildren()==0 and source.OfferAnchor.AutoCollectOffer.Enabled and board.views[source]==nil)
	check("unbind disconnects tween callbacks",not view.connections[1].Connected)
end,debug.traceback)
board:Destroy(); commerce:Destroy(); fixture:Destroy()
assert(ok,err)
return {passed=#results,checks=results}
