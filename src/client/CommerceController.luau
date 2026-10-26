--!strict
-- Client owns product display and Roblox's native prompt. The server owns benefits.
local Players=game:GetService("Players")
local Marketplace=game:GetService("MarketplaceService")
local GuiService=game:GetService("GuiService")
local Catalog=require(game:GetService("ReplicatedStorage").PetRoll.Shared.ShopCatalog)
local GalaxyPresentation=require(game:GetService("ReplicatedStorage").PetRoll.Shared.GalaxyCratePresentation)
local CrateRoll=require(script.Parent.GalaxyCrateRollPresentation)
local Theme=require(script.Parent.UITheme)
local Controller={}
Controller.__index=Controller
-- Lifetime Coins earned before a Coins shortfall may open a pack's checkout (BuyCoins).
local COINS_PROMPT_EARNED=2000

function Controller.new(app,dependencies)
	local deps=dependencies or {}
	return setmetatable({app=app,products={},connections={},alive=true,pending=nil,revision=0,
		marketplace=deps.marketplace or Marketplace,player=deps.player or Players.LocalPlayer,
		catalog=deps.catalog or Catalog,clock=deps.clock or os.clock,spawn=deps.spawn or task.spawn,
		delay=deps.delay or task.delay,togglePending={},justBought={},cratePresenting=false,crateResults={},crateResultOrder={},
		presentationFactory=deps.presentationFactory or CrateRoll.new,presentationCatalog=deps.presentationCatalog or GalaxyPresentation},Controller)
end

function Controller:Definition(key)
	local pass=self.catalog.Definitions[key]
	if pass then
		if pass.enabled==false then return nil end
		return pass,"Pass",pass.passId
	end
	local product=self.catalog.Products and self.catalog.Products[key]
	if product and product.enabled~=false then return product,"Product",product.productId end
	return nil
end

function Controller:Changed()
	self.revision+=1
	if self.alive and self.app.shopBrowser and self.app.page=="Shop" and self.app.panel.Visible then
		self.app.shopBrowser:Render()
	end
end

function Controller:Load(key,force)
	local definition,kind,id=self:Definition(key)
	if not definition then return end
	local current=self.products[key]
	if current and (current.loading or (not force and self.clock()-current.at<120)) then return end
	if type(id)~="number" or id<=0 then
		self.products[key]={status="unconfigured",at=self.clock()};return
	end
	local entry={status="loading",loading=true,at=self.clock()}
	self.products[key]=entry
	self.spawn(function()
		local ok,info=pcall(function()
			return self.marketplace:GetProductInfoAsync(id,if kind=="Pass" then Enum.InfoType.GamePass else Enum.InfoType.Product)
		end)
		if not self.alive or self.products[key]~=entry then return end
		entry.loading=false
		if ok and type(info)=="table" then
			entry.price=info.PriceInRobux
			local forSale=if kind=="Pass" then info.IsForSale==true else info.IsForSale~=false
			entry.status=if forSale and type(entry.price)=="number" and entry.price>=0 then "ready" else "offsale"
		else entry.status="error" end
		self:Changed()
	end)
end

function Controller:Open()
	for _,key in self.catalog.Order do self:Load(key) end
	for _,key in self.catalog.ProductOrder or {} do
		local definition=self.catalog.Products[key]
		if definition and (not definition.crates or (self.catalog.Crate and self.catalog.Crate.enabled)) then self:Load(key) end
	end
	self.app:Request("RefreshShop")
end

function Controller:State(key)
	local shop=self.app.state and self.app.state.shop
	local definition,kind=self:Definition(key)
	if not definition then return "unconfigured" end
	if definition.crates and (not self.catalog.Crate or not self.catalog.Crate.enabled) then return "unconfigured" end
	if shop and shop.owned and shop.owned[key] then return "owned" end
	if self.pending and self.pending.key==key then return if self.pending.prompted then "pending" else "preparing" end
	if self.autoCrate and self.autoCrate.key==key then return "pending" end
	local product=self.products[key]
	if product and product.status=="ready" then
		if definition.crates and shop and shop.testAllowed==true then
			if not shop.policyReady then return "policy" end
			if shop.paidRandomAllowed~=true then return "restricted" end
			return "studio",product.price
		end
		if kind=="Product" and (not shop or not shop.productReady) then return "profile" end
		if kind=="Pass" and (not shop or not shop.ready) then
			return if shop and shop.checking then "checking" else "ownership"
		end
		if definition.crates or key=="DoubleLuck" then
			if not shop or not shop.policyReady then return "policy" end
			local guaranteed=key=="DoubleLuck" and shop.paidRandomAllowed==false
				and shop.restrictedTreatment=="GuaranteedOffers"
			if shop.paidRandomAllowed~=true and not guaranteed then return "restricted" end
		end
	end
	return if product then product.status else "loading",product and product.price
end

-- `jobId` names the research job a skip product is for (ignored by other items).
function Controller:Buy(key,jobId)
	if not self.alive or self.pending or self.autoCrate or self.cratePending or self.cratePresenting then return end
	local status=self:State(key)
	if status=="ownership" or status=="policy" or status=="profile" then self.app:Request("RefreshShop");return end
	if status=="error" then self:Load(key,true);self:Changed();return end
	local definition,kind,id=self:Definition(key)
	if not definition or status~="ready" then return end
	local pending={key=key,kind=kind,productId=id,prompted=false,jobId=jobId}
	if definition.crates then
		local shop=self.app.state and self.app.state.shop
		local intent={key=key,baseline=(shop and shop.crateCredits) or 0,armed=false}
		pending.crateIntent,self.autoCrate=intent,intent
	end
	self:Prepare(pending)
end

function Controller:Prepare(pending)
	self.pending=pending
	pending.requestId=self.app:Request("PreparePurchase",{key=pending.key,jobId=pending.jobId})
	self:Changed()
	self.delay(20,function()
		if not self.alive or self.pending~=pending or pending.prompted then return end
		if self.autoCrate==pending.crateIntent then self.autoCrate=nil end
		self.pending=nil;self:Changed();self.app:Notify("Purchase check timed out. Try again.",false)
	end)
end

-- October 23 (Stevin): short of Coins, Roblox's checkout opens straight away for the
-- smallest Coins pack that covers the shortfall (the biggest when none does), with
-- no menu first. False means no prompt (a test session, a purchase already open),
-- so the caller shows its usual message; `fallback` is shown if the server refuses.
function Controller:BuyCoins(needed,fallback)
	if not self.alive or type(needed)~="number" or needed<=0 or self.pending or self.autoCrate
		or self.cratePending or self.cratePresenting then return false end
	-- October 23 empty start: not before the tutorial is complete and 2,000 Coins have
	-- been earned in all (eggs and battles); until then the caller's plain message shows.
	local state=self.app.state
	local tutorial=state and state.tutorial
	if type(tutorial)~="table" or tutorial.guideCompleted~=true then return false end
	if (tonumber(state.passiveEarned) or 0)+(tonumber(state.battleEarned) or 0)<COINS_PROMPT_EARNED then return false end
	local shop=self.app.state and self.app.state.shop
	local amounts=shop and shop.cashPacks
	if type(amounts)~="table" or shop.testAllowed==true then return false end
	local closest,closestAmount,biggest,biggestAmount
	for _,key in self.catalog.ProductOrder or {} do
		local product,amount=self.catalog.Products[key],amounts[key]
		if product and product.coins and not product.crates and type(amount)=="number" and self.catalog.ProductOnSale(key) then
			if amount>=needed and (not closestAmount or amount<closestAmount) then closest,closestAmount=key,amount end
			if not biggestAmount or amount>biggestAmount then biggest,biggestAmount=key,amount end
		end
	end
	local key=closest or biggest
	local definition,kind,id=self:Definition(key or "")
	if not definition then return false end
	self:Prepare({key=key,kind=kind,productId=id,prompted=false,fallback=fallback})
	return true
end

function Controller:Toggle(key)
	local shop=self.app.state and self.app.state.shop
	if not self:Definition(key) then return end
	if self.pending or self.togglePending[key] or not shop or not shop.owned or not shop.owned[key] then return end
	if key~="AutoMerge" and key~="AutoCollectEggs" then return end
	local id=self.app:Request("SetCommerceToggle",{key=key,enabled=not (shop.automatic and shop.automatic[key])})
	self.togglePending[key]=id;self:Changed()
	self.delay(20,function()
		if not self.alive or self.togglePending[key]~=id then return end
		self.togglePending[key]=nil;self:Changed()
	end)
end

function Controller:CanOpenCrate(shop)
	if not self.alive or self.pending or self.cratePending or self.cratePresenting or not shop or not shop.productReady or not shop.policyReady
		or shop.paidRandomAllowed~=true or (shop.crateCredits or 0)<1
		or not self.catalog.Crate or not self.catalog.Crate.enabled then return false end
	return true
end

function Controller:RequestCrate(shop)
	if not self:CanOpenCrate(shop) then return false end
	local id=self.app:Request("OpenCrate")
	if id==nil then return false end
	self.cratePending=id;self:Changed()
	self.delay(20,function()
		if not self.alive or self.cratePending~=id then return end
		self.cratePending=nil;self:Changed()
	end)
	return true
end

function Controller:OpenCrate()
	-- Manual opening supersedes checkout's one-shot automatic presentation.
	self.autoCrate=nil
	return self:RequestCrate(self.app.state and self.app.state.shop)
end

function Controller:TestCrate()
	local shop=self.app.state and self.app.state.shop
	if not self.alive or self.pending or self.autoCrate or self.cratePending or self.cratePresenting
		or not shop or shop.testAllowed~=true or not shop.policyReady or shop.paidRandomAllowed~=true
		or not self.catalog.Crate or not self.catalog.Crate.enabled then return false end
	-- The server permits this only for disposable Studio sessions; no checkout
	-- or purchased credit is involved in the explicit test action.
	local id=self.app:Request("TestCrate")
	if id==nil then return false end
	self.cratePending=id;self:Changed()
	self.delay(20,function()
		if not self.alive or self.cratePending~=id then return end
		self.cratePending=nil;self:Changed()
	end)
	return true
end

function Controller:ReceiveState(state)
	local intent=self.autoCrate
	if not self.alive or not intent or not intent.armed then return end
	if self.clock()>=intent.expiresAt then self.autoCrate=nil;self:Changed();return end
	local shop=state and state.shop
	-- Native checkout success only arms this intent. A server snapshot must prove
	-- new credits were delivered beyond those owned before this purchase began.
	if not shop or (shop.crateCredits or 0)<=intent.baseline or not self:CanOpenCrate(shop) then return end
	self.autoCrate=nil
	self:RequestCrate(shop)
end

function Controller:PresentCrate(result)
	local crate=result.crate
	self.latestCrate=crate
	if not self.crateRoll then
		self.crateRoll=self.presentationFactory(self.app.other or self.app.gui,{audio=self.app.audio})
	end
	if self.app.research then self.app.research:Close() end
	self.app:ClosePanel()
	self.crateSelection=GuiService.SelectedObject
	GuiService.SelectedObject=nil
	self.cratePresenting=true
	local completed=false
	local function complete()
		if not self.alive or completed then return end
		completed=true
		self.cratePresenting=false
		if self.crateSelection and self.crateSelection.Parent then GuiService.SelectedObject=self.crateSelection end
		self.crateSelection=nil
		self.app:Notify(result.message,true)
		self.app.feedback:Action("Buy")
		if crate.petId then self.app.base:PetPulse(crate.petId,Theme.Colors.gold) end
		self:Changed()
	end
	local played=self.crateRoll:Play(crate.species,self.presentationCatalog.Rewards,{
		seed=result.id,reducedMotion=self.app.reducedMotion,onComplete=complete,preview=crate.preview==true,
	})
	if not played then complete() end
end

function Controller:Receive(result)
	if not self.alive or type(result)~="table" then return end
	local handledCrate=false
	if result.action=="SetCommerceToggle" then
		for key,id in self.togglePending do if result.id==id then self.togglePending[key]=nil end end
	elseif result.action=="OpenCrate" or result.action=="TestCrate" then
		if self.crateResults[result.id] then return true end
		if self.cratePending~=nil and result.id==self.cratePending then
			self.cratePending=nil
			if result.ok and type(result.crate)=="table" then
				self.crateResults[result.id]=true
				table.insert(self.crateResultOrder,result.id)
				if #self.crateResultOrder>64 then self.crateResults[table.remove(self.crateResultOrder,1)]=nil end
				handledCrate=true
				self:PresentCrate(result)
			end
		end
	elseif result.action=="PreparePurchase" then
		local pending=self.pending
		if not pending or result.id~=pending.requestId or pending.prompted then return end
		if not self:Definition(pending.key) then
			if self.autoCrate==pending.crateIntent then self.autoCrate=nil end
			self.pending=nil;self:Changed();return
		end
		local purchase=result.purchase
		if result.ok~=true or type(purchase)~="table" or purchase.key~=pending.key
			or purchase.kind~=pending.kind or purchase.id~=pending.productId then
			if self.autoCrate==pending.crateIntent then self.autoCrate=nil end
			-- Research skips are bought outside the Shop page, so say why it stopped.
			-- Chicken offers are bought from the HUD, so they say why too.
			local definition=self.catalog.Products[pending.key]
			if (pending.jobId or (definition and definition.chickenOffer)) and type(result.message)=="string" and result.message~="" then self.app:Notify(result.message,false)
			elseif type(pending.fallback)=="string" and pending.fallback~="" then self.app:Notify(pending.fallback,false) end
			self.pending=nil;self:Changed();return
		end
		-- A validated server response permits the native checkout, never a local grant.
		pending.prompted=true
		local ok=pcall(function()
			if pending.kind=="Pass" then self.marketplace:PromptGamePassPurchase(self.player,pending.productId)
			else self.marketplace:PromptProductPurchase(self.player,pending.productId) end
		end)
		if not ok then
			if self.autoCrate==pending.crateIntent then self.autoCrate=nil end
			self.pending=nil;self.app:Notify(pending.fallback or "Roblox couldn't open the purchase. Try again.",false)
		end
	end
	self:Changed()
	return handledCrate
end

function Controller:Start()
	table.insert(self.connections,self.marketplace.PromptGamePassPurchaseFinished:Connect(function(player,passId,purchased)
		if player~=self.player or not self.alive then return end
		local pending=self.pending
		if not pending or pending.kind~="Pass" or pending.productId~=passId then return end
		self.pending=nil
		-- Presentation mark only: the Shop celebrates once the server confirms ownership.
		if purchased==true then self.justBought[pending.key]=self.clock() end
		-- This notification requests verification; it never grants an entitlement.
		self.app:Request("RefreshShop")
		self:Changed()
	end))
	table.insert(self.connections,self.marketplace.PromptProductPurchaseFinished:Connect(function(userId,productId,purchased)
		if userId~=self.player.UserId or not self.alive then return end
		local pending=self.pending
		if not pending or not pending.prompted or pending.kind~="Product" or pending.productId~=productId then return end
		self.pending=nil
		if purchased==true then self.justBought[pending.key]=self.clock() end
		-- Closing checkout is not proof of payment or receipt delivery.
		local intent=pending.crateIntent
		if intent and self.autoCrate==intent then
			if purchased==true then
				intent.armed,intent.expiresAt=true,self.clock()+60
				self.delay(60,function()
					if not self.alive or self.autoCrate~=intent then return end
					self.autoCrate=nil;self:Changed()
				end)
				-- Delivery can precede the native dialog's completion callback.
				self:ReceiveState(self.app.state)
			else self.autoCrate=nil end
		end
		self.app:Request("RefreshShop")
		self:Changed()
	end))
end

function Controller:Destroy()
	self.alive=false
	self.autoCrate,self.pending,self.cratePending=nil,nil,nil
	self.cratePresenting=false
	if self.crateRoll then self.crateRoll:Destroy();self.crateRoll=nil end
	if self.crateSelection then GuiService.SelectedObject=nil;self.crateSelection=nil end
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
end
return Controller
