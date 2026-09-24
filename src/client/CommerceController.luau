--!strict
-- Client owns product display and Roblox's native prompt. The server owns benefits.
local Players=game:GetService("Players")
local Marketplace=game:GetService("MarketplaceService")
local Catalog=require(game:GetService("ReplicatedStorage").PetRoll.Shared.ShopCatalog)
local Controller={}
Controller.__index=Controller

function Controller.new(app,dependencies)
	local deps=dependencies or {}
	return setmetatable({app=app,products={},connections={},alive=true,pending=nil,revision=0,
		marketplace=deps.marketplace or Marketplace,player=deps.player or Players.LocalPlayer,
		catalog=deps.catalog or Catalog,clock=deps.clock or os.clock,spawn=deps.spawn or task.spawn,
		delay=deps.delay or task.delay,togglePending={}},Controller)
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
		if definition and not definition.crates then self:Load(key) end
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
	local product=self.products[key]
	if product and product.status=="ready" then
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

function Controller:Buy(key)
	if self.pending then return end
	local status=self:State(key)
	if status=="ownership" or status=="policy" or status=="profile" then self.app:Request("RefreshShop");return end
	if status=="error" then self:Load(key,true);self:Changed();return end
	local definition,kind,id=self:Definition(key)
	if not definition or status~="ready" then return end
	local pending={key=key,kind=kind,productId=id,prompted=false}
	self.pending=pending
	pending.requestId=self.app:Request("PreparePurchase",{key=key})
	self:Changed()
	self.delay(20,function()
		if not self.alive or self.pending~=pending or pending.prompted then return end
		self.pending=nil;self:Changed();self.app:Notify("Purchase check timed out. Try again.",false)
	end)
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

function Controller:OpenCrate()
	local shop=self.app.state and self.app.state.shop
	if self.pending or self.cratePending or not shop or not shop.productReady or not shop.policyReady
		or shop.paidRandomAllowed~=true or (shop.crateCredits or 0)<1
		or not self.catalog.Crate or not self.catalog.Crate.enabled then return end
	local id=self.app:Request("OpenCrate")
	self.cratePending=id;self:Changed()
	self.delay(20,function()
		if not self.alive or self.cratePending~=id then return end
		self.cratePending=nil;self:Changed()
	end)
end

function Controller:Receive(result)
	if not self.alive or type(result)~="table" then return end
	if result.action=="SetCommerceToggle" then
		for key,id in self.togglePending do if result.id==id then self.togglePending[key]=nil end end
	elseif result.action=="OpenCrate" and result.id==self.cratePending then
		self.cratePending=nil
		if result.ok and type(result.crate)=="table" then self.latestCrate=result.crate end
	elseif result.action=="PreparePurchase" then
		local pending=self.pending
		if not pending or result.id~=pending.requestId or pending.prompted then return end
		if not self:Definition(pending.key) then self.pending=nil;self:Changed();return end
		local purchase=result.purchase
		if result.ok~=true or type(purchase)~="table" or purchase.key~=pending.key
			or purchase.kind~=pending.kind or purchase.id~=pending.productId then
			self.pending=nil;self:Changed();return
		end
		-- A validated server response permits the native checkout, never a local grant.
		pending.prompted=true
		local ok=pcall(function()
			if pending.kind=="Pass" then self.marketplace:PromptGamePassPurchase(self.player,pending.productId)
			else self.marketplace:PromptProductPurchase(self.player,pending.productId) end
		end)
		if not ok then
			self.pending=nil;self.app:Notify("Roblox couldn't open the purchase. Try again.",false)
		end
	end
	self:Changed()
end

function Controller:Start()
	table.insert(self.connections,self.marketplace.PromptGamePassPurchaseFinished:Connect(function(player,passId,_purchased)
		if player~=self.player or not self.alive then return end
		local pending=self.pending
		if not pending or pending.kind~="Pass" or pending.productId~=passId then return end
		self.pending=nil
		-- This notification requests verification; it never grants an entitlement.
		self.app:Request("RefreshShop")
		self:Changed()
	end))
	table.insert(self.connections,self.marketplace.PromptProductPurchaseFinished:Connect(function(userId,productId,_purchased)
		if userId~=self.player.UserId or not self.alive then return end
		local pending=self.pending
		if not pending or pending.kind~="Product" or pending.productId~=productId then return end
		self.pending=nil
		-- Closing checkout is not proof of payment or receipt delivery.
		self.app:Request("RefreshShop")
		self:Changed()
	end))
end

function Controller:Destroy()
	self.alive=false
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
end
return Controller
