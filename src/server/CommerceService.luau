--!strict
-- Roblox owns pass persistence. This service holds only verified session benefits;
-- client refresh requests and purchase-finished booleans never grant ownership.
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Rules = require(game:GetService("ReplicatedStorage").PetRoll.Shared.Rules)
local ShopCatalog = require(game:GetService("ReplicatedStorage").PetRoll.Shared.ShopCatalog)
local CommerceService = {}
CommerceService.__index = CommerceService
local RefreshSeconds = 8
local AutomaticRetries = 2

local function configured(id)
	return type(id) == "number" and id > 0 and id < math.huge and id % 1 == 0
end

-- Dependencies are injectable for isolated checks; production uses Roblox APIs.
function CommerceService.new(dependencies)
	dependencies = dependencies or {}
	local self = setmetatable({
		marketplace = dependencies.marketplace or MarketplaceService,
		policy = dependencies.policy or PolicyService,
		catalog = dependencies.catalog or ShopCatalog,
		clock = dependencies.clock or os.clock,
		delay = dependencies.delay or task.delay,
		records = {}, destroyed = false,
	}, CommerceService)
	self.connection = self.marketplace.PromptGamePassPurchaseFinished:Connect(function(player, passId, _wasPurchased)
		self:_PurchaseFinished(player, passId)
	end)
	return self
end

function CommerceService:_Active(record)
	return not self.destroyed and self.records[record.player.UserId] == record
		and not record.session.closing and not record.session.saveLost
		and record.player.Parent ~= nil
end

function CommerceService:_ScheduleRefresh(record)
	if not self:_Active(record) or record.busy or record.scheduled or not (record.pending or record.retryPending) then return end
	record.scheduled = true
	self.delay(math.max(0, record.nextAt - self.clock()), function()
		record.scheduled = false
		if not self:_Active(record) then return end
		-- A manual check may have satisfied this work or moved its throttle window.
		if record.busy or not (record.pending or record.retryPending) then return end
		if self.clock() < record.nextAt then self:_ScheduleRefresh(record); return end
		local freshCycle = record.pending
		record.pending, record.retryPending = false, false
		self:_Refresh(record.player, record.session, freshCycle)
	end)
end

function CommerceService:_PurchaseFinished(player, passId)
	if not configured(passId) then return end
	local record = self.records[player.UserId]
	if not record or record.player ~= player or not self:_Active(record) then return end
	for _, key in self.catalog.Order do
		if self.catalog.Definitions[key].passId == passId then
			-- Also safe on cancellation: only a fresh ownership check can enable it.
			record.pending = true
			self:_ScheduleRefresh(record)
			return
		end
	end
end

function CommerceService:Load(player, session)
	if self.destroyed or session.userId ~= player.UserId or session.closing or session.saveLost or player.Parent == nil then
		return false, "Shop unavailable."
	end
	local existing = self.records[player.UserId]
	if existing and existing.player == player and existing.session == session then
		return self:Refresh(player, session)
	end
	if existing then self:Release(existing.player) end
	local owned = {}
	for _, key in self.catalog.Order do owned[key] = false end
	local record = {player = player, session = session, owned = owned,
		ready = false, busy = false, nextAt = -math.huge, pending = false, scheduled = false,
		retryPending = false, retriesLeft = 0}
	self.records[player.UserId] = record
	session.entitlements = owned
	player:SetAttribute("PetRollCommanderBanner", false)
	return self:Refresh(player, session)
end

function CommerceService:Refresh(player, session)
	return self:_Refresh(player, session, true)
end

function CommerceService:_Refresh(player, session, freshCycle)
	local record = self.records[player.UserId]
	if not record or record.player ~= player or record.session ~= session or not self:_Active(record) then
		return false, "Shop unavailable."
	end
	if record.busy then return false, "Checking passes…" end
	if self.clock() < record.nextAt then
		return record.ready, if record.ready then "Passes checked." else "Please try again in a moment."
	end
	-- Only accepted external checks reset the budget. Automatic retries enter this
	-- private path with false, so an outage cannot create an endless polling loop.
	if freshCycle then
		record.retriesLeft = AutomaticRetries
		record.pending, record.retryPending = false, false
	end
	record.busy, record.ready = true, false
	record.nextAt = self.clock() + RefreshSeconds
	local policyOk,policyInfo=pcall(function() return self.policy:GetPolicyInfoForPlayerAsync(player) end)
	if not self:_Active(record) then record.busy=false;return false,"Shop unavailable." end
	record.policyReady=policyOk and type(policyInfo)=="table" and type(policyInfo.ArePaidRandomItemsRestricted)=="boolean"
	record.paidRandomAllowed=record.policyReady and policyInfo.ArePaidRandomItemsRestricted==false
	session.paidRandomAllowed=record.paidRandomAllowed
	session.paidRandomRestricted=record.policyReady and policyInfo.ArePaidRandomItemsRestricted==true
	local allChecked = true
	for _, key in self.catalog.Order do
		local passId = self.catalog.Definitions[key].passId
		if not configured(passId) then
			record.owned[key] = false
		else
			local ok, owns = pcall(function()
				return self.marketplace:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			-- A player can leave, reload or lose the profile lease during this yield.
			if not self:_Active(record) then record.busy = false; return false, "Shop unavailable." end
			if ok and type(owns) == "boolean" then
				record.owned[key] = owns
			else
				-- Preserve a previously verified benefit during a transient API failure.
				-- First-time failures remain false because Load initialized every key.
				allChecked = false
			end
		end
	end
	if not self:_Active(record) then record.busy = false; return false, "Shop unavailable." end
	record.busy, record.ready = false, allChecked
	session.entitlements = record.owned
	player:SetAttribute("PetRollCommanderBanner", record.owned.CommanderBanner == true)
	session:RefreshArmy()
	session:Touch()
	local fullyChecked=allChecked and record.policyReady==true
	if fullyChecked then
		record.retriesLeft, record.retryPending = 0, false
	elseif record.retriesLeft > 0 then
		record.retriesLeft -= 1
		record.retryPending = true
	end
	self:_ScheduleRefresh(record)
	return fullyChecked, if fullyChecked then "Passes checked." else "Couldn't check every shop benefit. Retrying shortly."
end

function CommerceService:Snapshot(session)
	local record = self.records[session.userId]
	local owned = {}
	local active = record and record.session == session and self:_Active(record)
	for _, key in self.catalog.Order do owned[key] = active and record.owned[key] == true or false end
	return {owned = owned, ready = active and record.ready == true or false,
		checking = active and (record.busy or record.scheduled) == true or false,
		automatic=table.clone(session.commerceAutomatic),crateCredits=session.crateCredits,
		policyReady=active and record.policyReady==true or false,
		paidRandomAllowed=active and record.paidRandomAllowed==true or false,
		restrictedTreatment=self.catalog.RestrictedTreatment,luckGuarantee=session:LuckGuarantee(),
		luckOdds={withoutPass=Rules.Odds(session.luck,session.recruitTier,1),withPass=Rules.Odds(session.luck,session.recruitTier,2)}}
end

function CommerceService:SetAutomatic(session,key,enabled)
 local definition=if type(key)=="string" then self.catalog.Definitions[key] else nil
 if not definition or definition.enabled==false or not definition.automatic or type(enabled)~="boolean" or session.entitlements[key]~=true then
  return false,"You need that pass to change its setting."
 end
 session.commerceAutomatic[key]=enabled
 session:Touch()
 return true,definition.name..(if enabled then " on." else " off.")
end

function CommerceService:PreparePurchase(player,session,key,productReady)
 if type(key)~="string" or #key>48 then return false,"Unknown shop item." end
 local definition=self.catalog.Definitions[key] or self.catalog.Products[key]
 local record=self.records[player.UserId]
 if not definition or definition.enabled==false or not record or record.session~=session or not self:_Active(record) then return false,"Shop unavailable." end
 if definition.passId then
  if not record.ready then return false,"Please wait while passes are checked." end
  if record.owned[key] then return false,"You already own this pass." end
 elseif not productReady then return false,"Purchases need a safely loaded, saved profile." end
 if definition.coins and session.coins>1e12-definition.coins then return false,"Spend some coins before buying this pack." end
 if definition.finishEggs and #session.eggProcessor.batches==0 then return false,"There are no eggs waiting to sell." end
 if definition.crates and session.crateCredits>1e9-definition.crates then return false,"Open some crates before buying more." end
 if definition.crates and not self.catalog.Crate.enabled then return false,"Crate rewards are being prepared." end
 if definition.paidRandom then
  if not record.policyReady then return false,"Please wait while purchase availability is checked." end
  local guaranteed=key=="DoubleLuck" and self.catalog.RestrictedTreatment=="GuaranteedOffers"
  if not record.paidRandomAllowed and not guaranteed then return false,"This random purchase is unavailable for your account." end
 end
 return true,"",{key=key,kind=if definition.passId then "Pass" else "Product",id=definition.passId or definition.productId}
end

function CommerceService:Release(player)
	local record = self.records[player.UserId]
	if not record or record.player ~= player then return end
	self.records[player.UserId] = nil
	record.session.entitlements = {}
	record.session.paidRandomAllowed=false
	record.session.paidRandomRestricted=false
	player:SetAttribute("PetRollCommanderBanner", false)
end

function CommerceService:Destroy()
	self.destroyed = true
	if self.connection then self.connection:Disconnect(); self.connection = nil end
	for _, record in self.records do self:Release(record.player) end
end

return CommerceService
