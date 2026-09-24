--!strict
-- Sole developer-product receipt owner. Prompt-finished events never grant items.
local MarketplaceService=game:GetService("MarketplaceService")
local Players=game:GetService("Players")
local ShopCatalog=require(game:GetService("ReplicatedStorage").PetRoll.Shared.ShopCatalog)
local EggProcessor=require(script.Parent.EggProcessor)
local ProductService={}
ProductService.__index=ProductService
local Granted=Enum.ProductPurchaseDecision.PurchaseGranted
local Pending=Enum.ProductPurchaseDecision.NotProcessedYet
local Owners=setmetatable({}, {__mode="k"})
local MaxCoins=1e12
local MaxCrates=1e9

local function integer(value,minimum,maximum)
 return type(value)=="number" and value==value and value>=minimum and value<=maximum and value%1==0
end

function ProductService.new(dataService,sessions,dependencies)
 dependencies=dependencies or {}
 local self=setmetatable({data=dataService,sessions=sessions,
  marketplace=dependencies.marketplace or MarketplaceService,
  players=dependencies.players or Players,catalog=dependencies.catalog or ShopCatalog,
  wait=dependencies.wait or task.wait,monotonic=dependencies.monotonic or os.clock,
  products={},destroyed=false,started=false},ProductService)
 for _,key in self.catalog.ProductOrder do
  local product=self.catalog.Products[key]
  assert(product and integer(product.productId,1,2^53-1),"Invalid developer product: "..key)
  assert(not self.products[product.productId],"Duplicate developer product ID")
  self.products[product.productId]=product
 end
 return self
end

function ProductService:CanPurchase(session)
 if self.destroyed or not session or self.sessions[session.userId]~=session then return false,"Shop unavailable." end
 local player=self.players:GetPlayerByUserId(session.userId)
 if not player or player.Parent==nil then return false,"Player is no longer here." end
 return self.data:CanPurchase(session)
end

function ProductService:_WaitForSession(userId)
 -- Redelivery can race PlayerAdded/profile loading. Roblox does not retry on a
 -- timer, so briefly await the existing load instead of requiring another rejoin.
 local deadline=self.monotonic()+20
 while not self.destroyed do
  local player=self.players:GetPlayerByUserId(userId)
  if not player or player.Parent==nil then return nil end
  local session=self.sessions[userId]
  if session then
   if session.closing or session.saveLost then return nil end
   if session.loaded then return session end
   if session.saveStatus=="error" then return nil end
  end
  if self.monotonic()>=deadline then return nil end
  self.wait(0.1)
 end
 return nil
end

function ProductService:_ProcessReceipt(receipt)
 if self.destroyed or type(receipt)~="table" or not integer(receipt.PlayerId,1,2^53-1)
  or not integer(receipt.ProductId,1,2^53-1) or type(receipt.PurchaseId)~="string"
  or #receipt.PurchaseId<1 or #receipt.PurchaseId>256 or not utf8.len(receipt.PurchaseId) then return Pending end
 local session=self:_WaitForSession(receipt.PlayerId)
 if not self:CanPurchase(session) then return Pending end
 -- An already delivered discontinued product remains acknowledgeable.
 if self.data:IsPurchaseSaved(session,receipt.PurchaseId,receipt.ProductId) then return Granted end
 local product=self.products[receipt.ProductId]
 if not product then return Pending end
 local saved=self.data:CommitPurchase(session,receipt.PurchaseId,receipt.ProductId,function()
  -- This function must not yield. Recheck presence after waiting for an autosave.
  if not self:CanPurchase(session) then return false,"The player left during delivery." end
  if product.finishEggs==true then
   return EggProcessor.GrantFinish(session.eggProcessor)
  elseif product.coins~=nil and product.crates==nil and integer(product.coins,1,MaxCoins)
   and integer(session.coins,0,MaxCoins-product.coins) then
   -- Exact purchased amount: earned-income passes never multiply paid currency.
   session.coins+=product.coins
  elseif product.crates~=nil and product.coins==nil and integer(product.crates,1,MaxCrates)
   and integer(session.crateCredits,0,MaxCrates-product.crates) then
   session.crateCredits+=product.crates
  else
   return false,"This purchase cannot fit safely yet. Spend or open items, then rejoin."
  end
  return true
 end)
 return if saved then Granted else Pending
end

function ProductService:ProcessReceipt(receipt)
 local ok,decision=pcall(function() return self:_ProcessReceipt(receipt) end)
 if not ok then
  warn("[PetRoll] Product delivery deferred: "..tostring(decision))
  return Pending
 end
 return decision
end

function ProductService:Start()
 if self.destroyed then return false,"Product service is closed." end
 if self.started then return true end
 if Owners[self.marketplace] and Owners[self.marketplace]~=self then return false,"A receipt handler already exists." end
 Owners[self.marketplace]=self
 self.marketplace.ProcessReceipt=function(receipt) return self:ProcessReceipt(receipt) end
 self.started=true
 return true
end

function ProductService:Destroy()
 if self.destroyed then return end
 self.destroyed=true
 if Owners[self.marketplace]==self then
  -- Callback members are write-only in Roblox; keep a safe handler during teardown.
  self.marketplace.ProcessReceipt=function() return Pending end
  Owners[self.marketplace]=nil
 end
 self.started=false
end

return ProductService
