-- Disposable Edit-mode fixtures. No real checkout, remotes, profiles, or rewards.
-- Run the whole block through Studio Flow execute_luau after syncing the modules.
do
	local Http=game:GetService("HttpService")
	local GuiService=game:GetService("GuiService")
	local report={name="Galaxy crate commerce fixtures",cases={},scope="Cloned client modules with injected Marketplace, app, timers, and reel"}
	if game:GetService("RunService"):IsRunning() then
		return Http:JSONEncode({ok=false,error="Run these isolated fixtures in Edit mode."})
	end
	local previousSelection=GuiService.SelectedObject
	local container=Instance.new("Folder")
	container.Name="GalaxyCommerceFixture_"..Http:GenerateGUID(false)
	container.Parent=game:GetService("ServerStorage")
	local harnesses={}
	local Controller
	local function expect(condition,message)
		assert(condition,message or "Expectation failed")
	end
	local function harness(credits)
		local h={now=0,queue={},requests={},notices={},prompts={},infoCalls={},plays={},feedback={},pulses={},closed=0,rendered=0,destroyedReels=0}
		table.insert(harnesses,h)
		local productEvent,passEvent=Instance.new("BindableEvent"),Instance.new("BindableEvent")
		productEvent.Name,passEvent.Name="ProductFinished","PassFinished"
		productEvent.Parent,passEvent.Parent=container,container
		h.productEvent,h.passEvent=productEvent,passEvent
		h.player={UserId=900001}
		h.catalog={Definitions={},Order={},Crate={enabled=true},Products={
			OuterSpaceCrate1={productId=101,crates=1},OuterSpaceCrate3={productId=103,crates=3},
			OuterSpaceCrate10={productId=110,crates=10},PocketCoins={productId=201,coins=100},
		},ProductOrder={"OuterSpaceCrate1","OuterSpaceCrate3","OuterSpaceCrate10","PocketCoins"}}
		local market={PromptProductPurchaseFinished=productEvent.Event,PromptGamePassPurchaseFinished=passEvent.Event}
		function market:GetProductInfoAsync(id,kind)
			table.insert(h.infoCalls,{id=id,kind=tostring(kind)})
			return {PriceInRobux=99,IsForSale=true}
		end
		function market:PromptProductPurchase(player,id)
			if h.failPrompt then error("Fixture prompt failure") end
			table.insert(h.prompts,{userId=player.UserId,id=id})
		end
		function market:PromptGamePassPurchase()
			error("Unexpected pass prompt in crate fixture")
		end
		local app={state={shop={productReady=true,policyReady=true,paidRandomAllowed=true,crateCredits=credits or 0,owned={}}},
			page="Shop",panel={Visible=true},other=container,reducedMotion=false,audio={},requestId=0}
		h.app=app
		function app:Request(action,payload)
			self.requestId+=1
			table.insert(h.requests,{action=action,id=self.requestId,payload=payload})
			return self.requestId
		end
		function app:Notify(message,ok)
			table.insert(h.notices,{message=message,ok=ok})
		end
		function app:ClosePanel()
			h.closed+=1
			self.panel.Visible=false
		end
		app.shopBrowser={Render=function() h.rendered+=1 end}
		app.research={Close=function() end}
		app.feedback={Action=function(_,action) table.insert(h.feedback,action) end}
		app.base={PetPulse=function(_,id,color) table.insert(h.pulses,{id=id,color=color}) end}
		local function presentationFactory()
			local reel={destroyed=false}
			function reel:Play(id,pool,options)
				table.insert(h.plays,{id=id,pool=pool,options=options})
				return not h.rejectPresentation
			end
			function reel:Destroy()
				self.destroyed=true
				h.destroyedReels+=1
			end
			return reel
		end
		h.controller=Controller.new(app,{
			marketplace=market,player=h.player,catalog=h.catalog,
			clock=function() return h.now end,spawn=function(callback) callback() end,
			delay=function(seconds,callback) table.insert(h.queue,{at=h.now+seconds,callback=callback}) end,
			presentationFactory=presentationFactory,presentationCatalog={Rewards={
				{id="Astronaut",species="Astronaut",chance=0.4,image="fixture",name="Astronaut"},
				{id="DarkMatter",species="DarkMatter",chance=0.09,image="fixture",name="Dark Matter"},
			}},
		})
		app.commerce=h.controller
		h.controller:Start()
		h.controller:Open()
		function h:Count(action)
			local count=0
			for _,request in self.requests do if request.action==action then count+=1 end end
			return count
		end
		function h:Snapshot(amount,changes)
			local shop=table.clone(self.app.state.shop)
			shop.crateCredits=amount
			for key,value in changes or {} do shop[key]=value end
			self.app.state={shop=shop}
			self.controller:ReceiveState(self.app.state)
		end
		function h:BeginPurchase()
			self.controller:Buy("OuterSpaceCrate3")
			expect(self.controller.pending~=nil,"Purchase should enter preparation")
			local pending=self.controller.pending
			self.controller:Receive({action="PreparePurchase",id=pending.requestId,ok=true,
				purchase={key="OuterSpaceCrate3",kind="Product",id=103}})
			expect(#self.prompts==1,"Exactly one injected native prompt expected")
			return pending
		end
		function h:Finish(purchased,userId,productId)
			self.productEvent:Fire(userId or self.player.UserId,productId or 103,purchased)
			-- BindableEvent callbacks are scheduled by Studio, not by our fake timer.
			task.wait()
		end
		function h:Advance(seconds)
			self.now+=seconds
			local again=true
			while again do
				again=false
				for _,item in self.queue do
					if not item.fired and item.at<=self.now then
						item.fired=true
						item.callback()
						again=true
					end
				end
			end
		end
		function h:Award(id)
			return {action="OpenCrate",id=id or self.controller.cratePending,ok=true,message="Dark Matter joined your flock!",
				crate={species="DarkMatter",level=1,petId="fixture-pet-1"}}
		end
		function h:Destroy()
			if self.cleaned then return end
			self.cleaned=true
			self.controller:Destroy()
			self.productEvent:Destroy()
			self.passEvent:Destroy()
		end
		return h
	end
	local function check(name,credits,callback)
		local h
		local ok,err=pcall(function()
			h=harness(credits)
			callback(h)
		end)
		if h then h:Destroy() end
		table.insert(report.cases,{name=name,ok=ok,error=if ok then nil else tostring(err)})
	end
	local ran,bootstrapError=pcall(function()
		local source=game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("PetRoll")
		expect(source~=nil,"Missing synced StarterPlayerScripts.PetRoll")
		local modules=Instance.new("Folder")
		modules.Name,modules.Parent="FreshClientModules",container
		for _,name in {"CommerceController","GalaxyCrateRollPresentation","UITheme","UIMotion"} do
			local item=source:FindFirstChild(name)
			expect(item and item:IsA("ModuleScript"),"Missing synced module "..name)
			item:Clone().Parent=modules
		end
		Controller=require(modules.CommerceController)
		check("Loads enabled crate prices through injected Marketplace",0,function(h)
			local loaded={}
			for _,call in h.infoCalls do loaded[call.id]=true end
			expect(loaded[101] and loaded[103] and loaded[110],"Every enabled crate price must load")
			expect(h.controller:State("OuterSpaceCrate3")=="ready","Crate should be purchasable after price load")
		end)
		check("Native success cannot spend existing baseline credits",4,function(h)
			h:BeginPurchase();h:Finish(true)
			h:Snapshot(4);h:Snapshot(4)
			expect(h:Count("OpenCrate")==0,"Prompt success alone must not open a crate")
			expect(h.controller.autoCrate and h.controller.autoCrate.armed,"Should await verified delivery")
		end)
		check("Snapshot before checkout closes opens exactly one",2,function(h)
			h:BeginPurchase();h:Snapshot(5)
			expect(h:Count("OpenCrate")==0,"Must wait for checkout closure")
			h:Finish(true);h:Snapshot(5);h:Snapshot(5)
			expect(h:Count("OpenCrate")==1,"One new-credit presentation expected")
			expect(h.controller.autoCrate==nil,"Intent must be consumed before request")
		end)
		check("Snapshot after checkout closes opens exactly one",0,function(h)
			h:BeginPurchase();h:Finish(true)
			h:Snapshot(3);h:Snapshot(3);h:Snapshot(3)
			expect(h:Count("OpenCrate")==1,"Repeated snapshots must not consume multipack credits")
			expect(h.app.state.shop.crateCredits==3,"Client must never mutate confirmed credit balance")
		end)
		check("Unrelated checkout callbacks cannot arm purchase",1,function(h)
			h:BeginPurchase();h:Snapshot(4)
			h:Finish(true,900002,103);h:Finish(true,900001,110)
			expect(h:Count("OpenCrate")==0 and h.controller.pending~=nil,"Unmatched callbacks should be ignored")
			h:Finish(true)
			expect(h:Count("OpenCrate")==1,"Matching callback should finish the intent")
		end)
		check("Cancelled checkout never automatically opens credits",2,function(h)
			h:BeginPurchase();h:Snapshot(5);h:Finish(false);h:Snapshot(5)
			expect(h.controller.autoCrate==nil and h.controller.pending==nil,"Cancellation must clear intent")
			expect(h:Count("OpenCrate")==0,"Cancellation must not consume any credits")
		end)
		check("Failed preparation clears intent and ignores late callback",2,function(h)
			h.controller:Buy("OuterSpaceCrate3")
			local id=h.controller.pending.requestId
			h.controller:Receive({action="PreparePurchase",id=id,ok=false,message="Unavailable"})
			h:Snapshot(5);h:Finish(true)
			expect(#h.prompts==0 and h:Count("OpenCrate")==0,"Preparation failure cannot reach checkout or opening")
			expect(h.controller.autoCrate==nil and h.controller.pending==nil,"Failed preparation must clean up")
		end)
		check("Preparation timeout cannot consume later delivery",2,function(h)
			h.controller:Buy("OuterSpaceCrate3");h:Advance(21);h:Snapshot(5);h:Finish(true)
			expect(h.controller.autoCrate==nil and h.controller.pending==nil,"Timeout must clear intent")
			expect(h:Count("OpenCrate")==0,"Expired preparation must not open later credits")
		end)
		check("Native prompt failure cleans up safely",2,function(h)
			h.failPrompt=true
			h.controller:Buy("OuterSpaceCrate3")
			local id=h.controller.pending.requestId
			h.controller:Receive({action="PreparePurchase",id=id,ok=true,purchase={key="OuterSpaceCrate3",kind="Product",id=103}})
			h:Snapshot(5)
			expect(h.controller.pending==nil and h.controller.autoCrate==nil,"Prompt failure must clear purchase")
			expect(h:Count("OpenCrate")==0 and #h.notices==1,"Report prompt failure without opening")
		end)
		check("Delivery intent expires without spending late credits",1,function(h)
			h:BeginPurchase();h:Finish(true);h:Advance(61);h:Snapshot(4)
			expect(h.controller.autoCrate==nil,"Intent should expire")
			expect(h:Count("OpenCrate")==0,"Late delivery remains manually openable")
		end)
		check("Manual opening supersedes automatic intent",2,function(h)
			h:BeginPurchase();h:Finish(true)
			expect(h.controller:OpenCrate()==true,"Existing credits may be opened explicitly")
			local id=h.controller.cratePending
			h.controller:Receive({action="OpenCrate",id=id,ok=false,message="Fixture inventory full"})
			h:Snapshot(5)
			expect(h.controller.autoCrate==nil,"Manual opening cancels auto intent")
			expect(h:Count("OpenCrate")==1,"Later snapshot must not add another automatic open")
		end)
		check("Restricted account cannot buy or manually open crates",2,function(h)
			h:Snapshot(2,{paidRandomAllowed=false})
			h.controller:Buy("OuterSpaceCrate3")
			expect(h.controller:OpenCrate()==false,"Policy restriction must block manual open")
			expect(h:Count("PreparePurchase")==0 and h:Count("OpenCrate")==0,"Restricted actions must not send requests")
		end)
		check("Policy revoked during checkout prevents automatic open",2,function(h)
			h:BeginPurchase();h:Finish(true);h:Snapshot(5,{paidRandomAllowed=false})
			expect(h:Count("OpenCrate")==0,"New credits cannot bypass revoked policy")
			h:Advance(61);h:Snapshot(5,{paidRandomAllowed=true})
			expect(h:Count("OpenCrate")==0,"Expired policy-blocked intent must stay cleared")
		end)
		check("Disabled crate and unready profile block requests",2,function(h)
			h.catalog.Crate.enabled=false
			h.controller:Buy("OuterSpaceCrate3")
			expect(h.controller:OpenCrate()==false,"Disabled feature must block opening")
			h.catalog.Crate.enabled=true;h:Snapshot(2,{productReady=false})
			expect(h.controller:OpenCrate()==false,"Unready profile must block opening")
			expect(h:Count("OpenCrate")==0 and h:Count("PreparePurchase")==0,"No purchase/open request expected")
		end)
		check("Matched award waits for reel and acknowledges exactly once",1,function(h)
			h.app.reducedMotion=true
			h.controller:OpenCrate()
			local result=h:Award()
			expect(h.controller:Receive(h:Award(result.id+1000))~=true and #h.plays==0,"Unmatched reply cannot start reel")
			expect(h.controller:Receive(result)==true,"Matched award must own its notification")
			expect(h.controller.cratePresenting and #h.plays==1 and h.closed==1,"Reel should own focus and close Shop")
			expect(h.plays[1].id=="DarkMatter" and h.plays[1].options.reducedMotion==true,"Use supplied species and reduced-motion setting")
			expect(#h.notices==0 and #h.feedback==0 and #h.pulses==0,"Reward feedback must wait for completion")
			h.controller:Receive(result);h.controller:Buy("OuterSpaceCrate3");h.controller:OpenCrate()
			expect(#h.plays==1 and h:Count("OpenCrate")==1 and h:Count("PreparePurchase")==0,"Duplicates and concurrent actions must be blocked")
			h.plays[1].options.onComplete();h.plays[1].options.onComplete();h.controller:Receive(result)
			expect(not h.controller.cratePresenting,"Completion must release focus guard")
			expect(#h.notices==1 and #h.feedback==1 and #h.pulses==1,"Completion feedback must fire exactly once")
			expect(h.pulses[1].id=="fixture-pet-1","Pulse the server-awarded pet")
		end)
		check("Failed opening leaves no presentation running",1,function(h)
			h.controller:OpenCrate()
			local handled=h.controller:Receive({action="OpenCrate",id=h.controller.cratePending,ok=false,message="Full"})
			expect(not handled and h.controller.cratePending==nil,"App should retain ordinary failure notification")
			expect(#h.plays==0 and not h.controller.cratePresenting,"Failed opening must not reveal a reward")
		end)
		check("Late opening reply after timeout cannot revive a reel",1,function(h)
			h.controller:OpenCrate();local result=h:Award();h:Advance(21)
			expect(h.controller.cratePending==nil,"Opening timeout should clear pending state")
			expect(h.controller:Receive(result)~=true and #h.plays==0,"Late unmatched reply must not revive presentation")
			expect(h:Count("OpenCrate")==1,"Late reply cannot issue another opening")
		end)
		check("Rejected reel falls back without trapping input",1,function(h)
			h.rejectPresentation=true;h.controller:OpenCrate();h.controller:Receive(h:Award())
			expect(not h.controller.cratePresenting,"Failed playback must release guard")
			expect(#h.notices==1 and #h.pulses==1,"Already-awarded reward must still be acknowledged")
		end)
		check("Destroy disconnects pending checkout and delayed callbacks",1,function(h)
			h:BeginPurchase();h.controller:Destroy();h:Snapshot(4);h:Finish(true);h:Advance(120)
			expect(h:Count("OpenCrate")==0 and h.controller.autoCrate==nil,"Destroyed controller must never auto-open")
			expect(#h.controller.connections==0 and not h.controller.cratePresenting,"Destroy must clear connections and focus")
		end)
		check("Destroy cancels reel and ignores late completion/reply",1,function(h)
			h.controller:OpenCrate();local result=h:Award();h.controller:Receive(result)
			local complete=h.plays[1].options.onComplete
			h.controller:Destroy();complete();h.controller:Receive(result);h:Advance(120)
			expect(h.destroyedReels==1 and not h.controller.cratePresenting,"Destroy must dispose the reel")
			expect(#h.notices==0 and #h.pulses==0,"Late completion must not emit feedback")
		end)
	end)
	for _,h in harnesses do pcall(function() h:Destroy() end) end
	container:Destroy()
	if previousSelection and previousSelection.Parent then GuiService.SelectedObject=previousSelection else GuiService.SelectedObject=nil end
	report.passed,report.failed=0,0
	for _,case in report.cases do
		if case.ok then report.passed+=1 else report.failed+=1 end
	end
	report.ok=ran and report.failed==0
	report.cleanup=true
	if not ran then report.bootstrapError=tostring(bootstrapError) end
	return Http:JSONEncode(report)
end
