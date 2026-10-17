--!strict
-- Roblox owns pass persistence. This service holds only verified session benefits.
-- Client refresh requests never grant. The server-side PromptGamePassPurchaseFinished
-- (fired by Roblox, not clients) with wasPurchased=true grants for this session at
-- once, because UserOwnsGamePassAsync can return a cached false for a while.
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")
local Rules = require(game:GetService("ReplicatedStorage").PetRoll.Shared.Rules)
local ShopCatalog = require(game:GetService("ReplicatedStorage").PetRoll.Shared.ShopCatalog)
local Currency = require(game:GetService("ReplicatedStorage").PetRoll.Shared.CurrencyLimits)
local CommerceService = {}
CommerceService.__index = CommerceService
local RefreshSeconds = 8
local AutomaticRetries = 2

-- Income behind cash pack payouts (ProductService delivers the same rule).
local function packIncome(session): number?
	return if type(session.PackIncome)=="function" then session:PackIncome() else nil
end

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
	self.connection = self.marketplace.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		self:_PurchaseFinished(player, passId, wasPurchased)
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

-- Top Supporters leaderboard and the analytics hook: the pass's current Robux price
-- (cached 10 minutes), looked up off the purchase path. Never affects ownership or benefits.
function CommerceService:_RecordPassSpend(record, passId, key)
	self.passPrices = self.passPrices or {}
	task.spawn(function()
		local cached = self.passPrices[passId]
		local price = if cached and self.clock() - cached.at < 600 then cached.price else nil
		if not price then
			local ok, info = pcall(function() return self.marketplace:GetProductInfoAsync(passId, Enum.InfoType.GamePass) end)
			if not ok then ok, info = pcall(function() return self.marketplace:GetProductInfo(passId, Enum.InfoType.GamePass) end) end
			price = if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then info.PriceInRobux else nil
			if price then self.passPrices[passId] = {price = price, at = self.clock()} end
		end
		-- Observation hook (Analytics) with the Robux charged, if known; never grants or blocks anything.
		if self.onPassPurchased then pcall(self.onPassPurchased, record.player, key, price) end
		local session = record.session
		if price and price > 0 and not session.closing and not session.saveLost then
			session.robuxSpent = math.min(1e12, (session.robuxSpent or 0) + math.floor(price))
			session:Touch()
		end
	end)
end

function CommerceService:_PurchaseFinished(player, passId, wasPurchased)
	if not configured(passId) then return end
	local record = self.records[player.UserId]
	if not record or record.player ~= player or not self:_Active(record) then return end
	for _, key in self.catalog.Order do
		if self.catalog.Definitions[key].passId == passId then
			if wasPurchased == true then
				-- Kept for the session even if the follow-up check still reads a cached false.
				record.purchased[key] = true
				record.owned[key] = true
				self:_ApplyBenefits(record)
				-- Also fires the Analytics hook once the price lookup finishes.
				self:_RecordPassSpend(record, passId, key)
			end
			-- Cancellation grants nothing; a fresh ownership check still runs.
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
		retryPending = false, retriesLeft = 0, purchased = {}}
	self.records[player.UserId] = record
	session.entitlements = owned
	player:SetAttribute("PetRollCommanderBanner", false)
	return self:Refresh(player, session)
end

function CommerceService:Refresh(player, session)
	return self:_Refresh(player, session, true)
end

function CommerceService:TestAllowed(session)
	-- Studio test sessions, or a live "test as a new player" session (never saved).
	return (RunService:IsStudio() or session.newPlayerTest == true) and session.saveStatus == "studio-session"
		and session.loaded == true and not session.closing and not session.saveLost
end

-- Overrides never alter verified ownership or serialize into a player profile.
-- Reapply after every yielding marketplace refresh so it cannot restore paid perks.
function CommerceService:_ApplyBenefits(record)
	local session = record.session
	local preset = if self:TestAllowed(session) then record.testPreset else nil
	session.commerceTestPreset = preset
	local owned = table.clone(record.owned)
	if preset then
		for _, key in self.catalog.Order do
			owned[key] = preset == "AllPasses" or (preset == "EggSpawn" and key == "DoubleEggSpawn")
		end
	end
	session.entitlements = owned
	record.player:SetAttribute("PetRollCommanderBanner", owned.CommanderBanner == true)
	session:RefreshArmy()
	session:Touch()
end

function CommerceService:SetTestPreset(player, session, preset)
	if not self:TestAllowed(session) then return false, "Use a disposable Studio session for purchase testing." end
	if preset ~= "Account" and preset ~= "NoPasses" and preset ~= "EggSpawn" and preset ~= "AllPasses" then
		return false, "Choose a valid purchase test preset."
	end
	local record = self.records[player.UserId]
	if not record or record.session ~= session or not self:_Active(record) then return false, "Wait for the shop to load." end
	record.testPreset = if preset == "Account" then nil else preset
	self:_ApplyBenefits(record)
	return true, "TEST: " .. preset .. " benefits. Real purchases are unchanged."
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
				record.owned[key] = owns or record.purchased[key] == true
			else
				-- Preserve a previously verified benefit during a transient API failure.
				-- First-time failures remain false because Load initialized every key.
				allChecked = false
			end
		end
	end
	if not self:_Active(record) then record.busy = false; return false, "Shop unavailable." end
	record.busy, record.ready = false, allChecked
	self:_ApplyBenefits(record)
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
	for _, key in self.catalog.Order do owned[key] = active and session.entitlements[key] == true or false end
	local testing = active and self:TestAllowed(session)
	-- Current cash pack payouts for the Shop display (minutes of income, with a floor).
	local cashPacks, income = {}, packIncome(session)
	for key, product in self.catalog.Products do
		if product.coins and not product.crates then cashPacks[key] = ShopCatalog.CashPackAmount(product, income) end
	end
	return {owned = owned, ready = active and (record.ready == true or record.testPreset ~= nil) or false,
		testAllowed = testing == true, testPreset = if testing then record.testPreset or "Account" else nil,
		checking = active and (record.busy or record.scheduled) == true or false,
		automatic=table.clone(session.commerceAutomatic),crateCredits=session.crateCredits,
		policyReady=active and record.policyReady==true or false,
		paidRandomAllowed=active and record.paidRandomAllowed==true or false,
		restrictedTreatment=self.catalog.RestrictedTreatment,luckGuarantee=session:LuckGuarantee(),
		-- Credits bought before a policy change stay saved; nothing is converted without a disclosed equivalent.
		crateNotice=if active and record.policyReady==true and record.paidRandomAllowed~=true and session.crateCredits>0
			then "Your Galaxy Crates are saved. Paid random items are unavailable for this account, so they stay unopened." else nil,
		cashPacks=cashPacks,
		luckOdds={withoutPass=Rules.Odds(session.luck,session.recruitTier,1,session.researchEffects.rollingLuck),withPass=Rules.Odds(session.luck,session.recruitTier,2,session.researchEffects.rollingLuck)}}
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

function CommerceService:PreparePurchase(player,session,key,productReady,jobId)
 if self:TestAllowed(session) then return false,"Purchases are disabled in a test session." end
 if type(key)~="string" or #key>48 then return false,"Unknown shop item." end
 local definition=self.catalog.Definitions[key] or self.catalog.Products[key]
 local record=self.records[player.UserId]
 if not definition or definition.enabled==false or not record or record.session~=session or not self:_Active(record) then return false,"Shop unavailable." end
 if definition.passId then
  if not record.ready then return false,"Please wait while passes are checked." end
  if record.owned[key] then return false,"You already own this pass." end
 elseif not productReady then return false,"Purchases need a safely loaded, saved profile." end
 if definition.coins and session.coins>Currency.MaxCoins-definition.coins then return false,"Spend some cash before buying this pack." end
 if definition.chickenOffer then
  -- One step at a time; the chicken needs a free Flock spot.
  if (session.chickenOfferStep or 0)>=definition.chickenOffer then return false,"You already own this offer." end
  if (session.chickenOfferStep or 0)+1~=definition.chickenOffer then return false,"Unlock the earlier offers first." end
  if session:Count()>=session:CollectionLimit() then return false,"Make room in your Flock first." end
 end
 if definition.finishEggs and #session.eggProcessor.batches==0 then return false,"There are no eggs waiting to sell." end
 if definition.researchSkipSeconds then
  -- Remaining time only shrinks, so a tier that covers it now still covers it at delivery.
  local now,target=os.time(),nil
  for _,job in session.research.jobs do if job.id==jobId and job.finishAt>now then target=job end end
  if not target then return false,"That research has already finished." end
  if target.finishAt-now>definition.researchSkipSeconds then return false,"Research time changed. Try again." end
  session.researchSkipTarget=target.id
 end
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
	record.session.commerceTestPreset = nil
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
