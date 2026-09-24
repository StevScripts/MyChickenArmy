-- Focused Edit fixture. Fresh module environments, fake sessions/store; no Play or profiles.
local loaded={}
local function fresh(module)
	if loaded[module] then return loaded[module] end
	local fn,err=loadstring(module.Source,"="..module.Name)
	assert(fn,err)
	local env=setmetatable({script=module,require=function(dependency)
		if typeof(dependency)=="Instance" and dependency:IsA("ModuleScript") then return fresh(dependency) end
		return require(dependency)
	end},{__index=getfenv()})
	setfenv(fn,env)
	local result=fn();loaded[module]=result;return result
end
local root=game.ServerStorage.PetRoll
local Processor=fresh(root.EggProcessor)
local Session=fresh(root.PlayerSession)
local Eggs=fresh(root.EggService)
local Products=fresh(root.ProductService)
local passed={}
local function check(name,fn) fn();table.insert(passed,name) end
check("integer value conservation, mixed batches and partial processing",function()
	local state=Processor.New()
	assert(Processor.Deposit(state,3,10));assert(Processor.Deposit(state,2,99))
	Processor.Step(state,0.5,2)
	local count,value=Processor.Totals(state)
	assert(count==4 and value+state.readyValue==109)
	Processor.Step(state,100,2)
	assert(#state.batches==0 and state.readyValue==109 and state.progress==0)
end)
check("bounded backlog preserves every egg and coin",function()
	local state=Processor.New()
	for i=1,300 do assert(Processor.Deposit(state,i,i*3)) end
	local count,value=Processor.Totals(state)
	assert(#state.batches==64 and count==45150 and value==135450)
	assert(Processor.Read(Processor.Copy(state)))
	Processor.Finish(state);assert(state.readyValue==135450)
end)
check("snapshot copies, old saves and partial queue survive rejoin",function()
	local session=Session.new(123,"Fixture",1)
	local old=session:ToData();old.eggProcessor=nil;old.dataRevision=8
	assert(session:LoadData(old));assert(session.eggProcessor.level==0)
	Processor.Deposit(session.eggProcessor,120,1200)
	Processor.Step(session.eggProcessor,0.75,2)
	session.eggProcessor.level=2
	local payload=session:ToData()
	Processor.Finish(session.eggProcessor)
	local another=Session.new(123,"Fixture",1)
	assert(another:LoadData(payload))
	assert(Processor.Totals(another.eggProcessor)==119 and another.eggProcessor.readyValue==10
		and another.eggProcessor.progress==0.5 and another.eggProcessor.level==2)
	payload.eggProcessor.readyValue=0/0
	assert(not another:LoadData(payload))
end)
local authored=workspace.MyChickenArmyMap["03_HomePlots"]
local board=authored.EggCollectionBoard
local pad=authored.Plot1:FindFirstChild("sellpart",true)
assert(pad and board.CollectionPart.TouchPart)
local world={root=authored,plots={}}
function world:EggDeposit(index) return pad,if index==1 then 123 else 999 end
local service=Eggs.new(world)
local session=Session.new(123,"Fixture",1)
session.loaded=true
session.entitlements.DoubleCash=true
local initial=session.coins
check("manual deposit queues; pad pays once; Double Cash applies once",function()
	session.eggCarry={count=4,value=101}
	assert(service:Deposit(session,pad.Position+Vector3.new(0,2,0),1))
	assert(session.coins==initial and session.eggCarry.count==0)
	assert(Processor.Totals(session.eggProcessor)==4)
	local cashAt=board.CollectionPart.TouchPart.Position+Vector3.new(0,2,0)
	service:ProcessAndClaim(session,nil,1,2)
	assert(session.eggProcessor.readyValue==50)
	service:ProcessAndClaim(session,cashAt,0,3)
	assert(session.coins==initial+100)
	service:ProcessAndClaim(session,cashAt,1,4)
	assert(session.coins==initial+100 and session.eggProcessor.readyValue==51)
	service:ProcessAndClaim(session,nil,0,5)
	service:ProcessAndClaim(session,cashAt,0,6)
	assert(session.coins==initial+202 and session.eggProcessor.readyValue==0)
end)
check("vacuum unload enters queue once without paying the wallet",function()
	session.entitlements.AutoCollectEggs=true
	session.commerceAutomatic.AutoCollectEggs=true
	local yard=service:Yard(session)
	yard.roverPlotSize=session.plotSizeLevel
	local rover={enabled=true,state="Unload",cargoCount=8,cargoValue=88,pendingCount=0,position=pad.Position}
	function rover:Step() end
	function rover:Nozzle() return self.position end
	function rover:ReadyToUnload() return not self.unloaded end
	function rover:FinishUnload() self.unloaded=true end
	yard.rover=rover
	local balance=session.coins
	service:UpdateRover(session,yard,0.1,7)
	assert(session.coins==balance and Processor.Totals(session.eggProcessor)==8)
	assert(rover.cargoCount==0 and rover.cargoValue==0)
	service:UpdateRover(session,yard,0.1,8)
	assert(Processor.Totals(session.eggProcessor)==8)
	Processor.Finish(session.eggProcessor);session.eggProcessor.readyValue=0
end)
check("upgrade validates distance, price and stale replay",function()
	local character={}
	function character:FindFirstChild() return {Position=board.Screen.Position} end
	function character:FindFirstChildOfClass() return {Health=100} end
	local player={Character=character}
	session.coins=1000
	assert(service:Upgrade(player,session,0,480))
	assert(session.coins==520 and session.eggProcessor.level==1)
	assert(not service:Upgrade(player,session,0,480))
	assert(not service:Upgrade(player,session,1,1))
	assert(Processor.Rate(session.eggProcessor,false)==4 and Processor.Rate(session.eggProcessor,true)==8)
end)
check("wrong owner cannot deposit or bind another player's board",function()
	local foreign=Session.new(999,"Fixture",2);foreign.loaded=true
	foreign.eggCarry={count=1,value=10}
	assert(service:Board(foreign)==nil)
	world.EggDeposit=function() return pad,123 end
	assert(not service:Deposit(foreign,pad.Position,0))
end)
check("finish receipt persists, retries without double grant, defers failed save",function()
	local fakePlayer={Parent=true}
	local sessions={[123]=session}
	local saved={};local fail=true
	local data={}
	function data:CanPurchase() return true end
	function data:IsPurchaseSaved(_,id,productId) return saved[id]==productId end
	function data:CommitPurchase(s,id,productId,grant)
		if not s.purchaseReceipts[id] then assert(grant());s.purchaseReceipts[id]=productId end
		if fail then return false end
		saved[id]=productId;return true
	end
	local products=Products.new(data,sessions,{players={GetPlayerByUserId=function() return fakePlayer end}})
	Processor.Deposit(session.eggProcessor,12,123)
	local receipt={PlayerId=123,ProductId=3714566216,PurchaseId="fixture-finish-1"}
	assert(products:ProcessReceipt(receipt)==Enum.ProductPurchaseDecision.NotProcessedYet)
	assert(Processor.Totals(session.eggProcessor)==0 and session.eggProcessor.readyValue==123)
	fail=false
	assert(products:ProcessReceipt(receipt)==Enum.ProductPurchaseDecision.PurchaseGranted)
	assert(session.eggProcessor.readyValue==123)
	Processor.Deposit(session.eggProcessor,5,15)
	assert(products:ProcessReceipt(receipt)==Enum.ProductPurchaseDecision.PurchaseGranted)
	assert(Processor.Totals(session.eggProcessor)==5)
	Processor.Finish(session.eggProcessor)
	receipt.PurchaseId="fixture-delayed-empty"
	assert(products:ProcessReceipt(receipt)==Enum.ProductPurchaseDecision.PurchaseGranted)
	assert(session.eggProcessor.finishCredits==1)
	Processor.Deposit(session.eggProcessor,7,11)
	assert(session.eggProcessor.finishCredits==0 and Processor.Totals(session.eggProcessor)==0)
	assert(session.eggProcessor.readyValue==149)
end)
check("authored surface binding, live labels and button request routing",function()
	assert(not workspace:FindFirstChild("PetRollWorld"),"Fixture requires Edit with no runtime world")
	local worldFolder=Instance.new("Folder");worldFolder.Name="PetRollWorld";worldFolder.Parent=workspace
	local copy=board:Clone();copy.Parent=worldFolder
	local guiFolder=Instance.new("Folder")
	local controller
	local ok,err=pcall(function()
		local Board=fresh(game.StarterPlayer.StarterPlayerScripts.PetRoll.EggProcessorController)
		local app={state={plotIndex=1,coins=1000,eggs={processor={enabled=true,queuedCount=120,rate=2,
			level=0,upgradePrice=480,readyCash=777}}},audio={Play=function() end}}
		function app:Request(action,args) self.request={action=action,args=args};return 12345 end
		function app:Notify() end
		app.commerce={State=function() return "ready" end,Buy=function(_,key) app.bought=key end}
		controller=Board.new(app);controller.playerGui=guiFolder
		local source=copy.Screen.SurfaceGui
		controller:Bind(source)
		controller:Bind(copy.CollectionPart.TouchPart.SurfaceGui)
		local view=controller.views[source]
		assert(view and view.gui.Enabled and not source.Enabled)
		assert(view.content.QueuedCount.Text=="120" and view.content.Rate.Text=="2 eggs/sec")
		assert(controller.views[copy.CollectionPart.TouchPart.SurfaceGui].cash.Text=="$777")
		controller:Activate("Upgrade")
		assert(app.request.action=="EggSellerUpgrade" and app.request.args.expectedLevel==0 and app.request.args.expectedPrice==480)
		controller:Receive({id=12345});assert(controller.pending==nil)
		controller:Activate("FinishNow");assert(app.bought=="FinishEggs")
		app.state.eggs.processor.queuedCount=1000000000000;controller:Render()
		assert(view.content.QueuedCount.TextSize<88)
		app.state.plotIndex=2;controller:Render();assert(not view.gui.Enabled)
	end)
	if controller then controller:Destroy() end
	guiFolder:Destroy();worldFolder:Destroy()
	assert(ok,err)
end)
return {passed=passed,count=#passed,realProfiles=false,realPurchases=false}
