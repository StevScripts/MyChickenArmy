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
local Config = require(game:GetService("ReplicatedStorage").PetRoll.Shared.Config)
local CommerceService = {}
CommerceService.__index = CommerceService
local RefreshSeconds = 8
local AutomaticRetries = 2

-- Income behind cash pack payouts (ProductService delivers the same rule).
local function packIncome(session): number?
	return if type(session.PackIncome)=="function" then session:PackIncome() else nil
end

-- October 27 (WS3): the Coins-shortfall gate's runtime log, per session object and never
-- saved: auto-prompts opened this session and the server time the next one may open.
local function promptLog(session)
	local log = session.coinsPromptLog
	if type(log) ~= "table" then log = {count = 0, readyAt = 0}; session.coinsPromptLog = log end
	return log
end

local function playSeconds(session): number
	return if type(session.PlaySeconds) == "function" then session:PlaySeconds() else tonumber(session.playSeconds) or 0
end

local function configured(id)
	return type(id) == "number" and id > 0 and id < math.huge and id % 1 == 0
end

-- Every pass whose ownership is verified: on sale (benefits) and retired (October
-- 20: a one-time Gems gift; only keepsBenefit passes still apply).
local function passKeys(catalog): {string}
	local keys = table.clone(catalog.Order)
	for _, key in catalog.RetiredOrder or {} do table.insert(keys, key) end
	return keys
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
		serverNow = dependencies.serverNow,
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
	for _, key in passKeys(self.catalog) do owned[key] = false end
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
	-- October 20: a retired pass's benefit ends (its owner got Gems instead), except
	-- the Commander Banner cosmetic.
	for _, key in self.catalog.RetiredOrder or {} do
		if not self.catalog.Definitions[key].keepsBenefit then owned[key] = false end
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
	for _, key in passKeys(self.catalog) do
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
	self:_GiftRetiredPasses(record)
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

-- October 20: owners of a retired pass get its Gems once (session.passGemGifts is
-- saved). Only verified ownership counts: never a Studio test preset.
-- October 23 (Stevin: "I have 300 gems to begin with ... That should be zero"): the
-- game's creator owns every pass, so the developer (Studio, the creator, DebugUserIds)
-- gets no gift and loses any already given. Real buyers keep theirs.
local function developer(player: Player): boolean
	return RunService:IsStudio() or table.find(Config.DebugUserIds or {}, player.UserId) ~= nil
		or (game.CreatorType == Enum.CreatorType.User and game.CreatorId == player.UserId)
end

function CommerceService:_GiftRetiredPasses(record)
	local session = record.session
	if not session.loaded or session.closing or session.saveLost or type(session.passGemGifts) ~= "table" then return end
	if developer(record.player) then
		local given = 0
		for key in session.passGemGifts do
			local gems = self.catalog.Definitions[key] and self.catalog.Definitions[key].retiredGems
			if type(gems) == "number" then given += gems end
		end
		if next(session.passGemGifts) then
			table.clear(session.passGemGifts)
			session.gems = math.max(0, (session.gems or 0) - given)
			session.gemsEarned = math.max(0, (session.gemsEarned or 0) - given)
			session:Touch()
		end
		return
	end
	for _, key in self.catalog.RetiredOrder or {} do
		local definition = self.catalog.Definitions[key]
		local gems = definition.retiredGems
		if record.owned[key] == true and type(gems) == "number" and gems > 0 and not session.passGemGifts[key] then
			session.passGemGifts[key] = true
			session.gems = math.min(1e12, (session.gems or 0) + gems)
			session.gemsEarned = math.min(1e12, (session.gemsEarned or 0) + gems)
			session.banner = definition.name .. " left the Shop. Thanks for owning it: +" .. gems .. " Gems!"
			session:Touch()
			-- Observation hook (Analytics); never affects the gift.
			if self.onPassGems then pcall(self.onPassGems, session, key, gems) end
		end
	end
end

-- The shared clock of the Coins-shortfall gate (the client's mirror compares readyAt
-- with its own workspace:GetServerTimeNow()).
function CommerceService:_ServerNow(): number
	return if self.serverNow then self.serverNow() else workspace:GetServerTimeNow()
end

-- October 27 (WS3, live 1.25.0 data: 2,429 Coins-pack auto-prompts, 3 bought; 6.6 a
-- prompted player; 75% before minute 7.5 of play). Whether a Coins shortfall of `need`
-- may open Roblox's checkout for a Coins pack (October 23 rule). Returns the first
-- failing reason: Off, Tutorial, New (under Config.CoinsPrompt.MinPlaySeconds of play
-- and no Rebirth 1), Cap (SessionCap auto-prompts this session), Cooldown, Small (steady
-- income covers the gap within MinShortfallIncomeSeconds), Test (a test session never
-- checks out; checked last so Studio shows the real reason); else true, "Open" (or
-- "Legacy": Mode "Legacy" is the exact October 23 gate, tutorial + 2,000 Coins earned).
-- `need` nil checks everything but Small. docs/team/COINS_SHORTFALL_PROMPT.md "Gate".
function CommerceService:CoinsPromptGate(session, need: number?, now: number?): (boolean, string)
	local cfg = (Config :: any).CoinsPrompt or {}
	local mode = cfg.Mode or "Gated"
	if mode == "Off" then return false, "Off" end
	local tutorial = session.tutorial
	if type(tutorial) ~= "table" or tutorial.guideCompleted ~= true then return false, "Tutorial" end
	if mode == "Legacy" then
		if (session.passiveEarned or 0) + (session.battleEarned or 0) < (cfg.LegacyEarned or 2000) then return false, "Tutorial" end
		if self:TestAllowed(session) then return false, "Test" end
		return true, "Legacy"
	end
	if (session.rebirths or 0) < (cfg.MinRebirths or 1) and playSeconds(session) < (cfg.MinPlaySeconds or 600) then
		return false, "New"
	end
	local log = promptLog(session)
	if log.count >= (cfg.SessionCap or 2) then return false, "Cap" end
	if (now or self:_ServerNow()) < log.readyAt then return false, "Cooldown" end
	if type(need) == "number" and need < (packIncome(session) or 0) * (cfg.MinShortfallIncomeSeconds or 0) then
		return false, "Small"
	end
	if self:TestAllowed(session) then return false, "Test" end
	return true, "Open"
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
	-- October 27 (WS3): a mirror of the Coins-shortfall gate for the client's local
	-- pre-checks (Upgrades hexes, the world board); the server stays the authority.
	local cfg = (Config :: any).CoinsPrompt or {}
	local eligible, reason = self:CoinsPromptGate(session, nil)
	local coinsPrompt = {eligible = eligible, reason = reason, readyAt = promptLog(session).readyAt, income = income or 0,
		minShortfallSeconds = cfg.MinShortfallIncomeSeconds or 0, hintSeconds = cfg.ShopHintIncomeSeconds or 300}
	return {owned = owned, coinsPrompt = coinsPrompt, ready = active and (record.ready == true or record.testPreset ~= nil) or false,
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

-- October 27 (WS3): `source` "Shortfall" marks the client's automatic Coins-shortfall
-- checkout (BuyCoins) for `need` Coins. It passes CoinsPromptGate again, buys only Coins
-- packs and, once every other check passes, counts toward the session cap and cooldown.
-- Any other source (the Shop, HUD offers) is never gated.
function CommerceService:PreparePurchase(player,session,key,productReady,_jobId,source,need)
 if self:TestAllowed(session) then return false,"Purchases are disabled in a test session." end
 if type(key)~="string" or #key>48 then return false,"Unknown shop item." end
 local shortfall=source=="Shortfall"
 local now=if shortfall then self:_ServerNow() else 0
 if shortfall then
  local amount=tonumber(need)
  amount=if amount and amount==amount then math.clamp(amount,0,Currency.MaxCoins) else nil
  local pack=self.catalog.Products and self.catalog.Products[key]
  if not pack or not pack.coins or pack.crates then return false,"Not enough coins." end
  if not self:CoinsPromptGate(session,amount,now) then return false,"Not enough coins." end
 end
 -- October 20 Rebirth Skip: the client asks for "RebirthSkip"; the next rank picks the band.
 if key=="RebirthSkip" then
  local rank=(session.rebirths or 0)+1
  if rank>Config.Rebirth.MaxRank then return false,"Max Rebirth reached" end
  key=self.catalog.RebirthSkipFor(rank) or ""
  if not self.catalog.ProductOnSale(key) then return false,"Skip isn't on sale yet." end
 end
 local definition=self.catalog.Definitions[key] or self.catalog.Products[key]
 local record=self.records[player.UserId]
 if not definition or definition.enabled==false or not record or record.session~=session or not self:_Active(record) then return false,"Shop unavailable." end
 if definition.offSale then return false,"This pass is no longer for sale." end
 if definition.retired then return false,"Research is now instant in Upgrades." end
 if definition.rebirthSkip then
  local rank=(session.rebirths or 0)+1
  if not self.catalog.ProductOnSale(key) or rank<definition.ranks[1] or rank>definition.ranks[2] then
   return false,"Your Rebirth changed. Try again."
  end
  if (session.rebirthSkips or 0)>=1 then return false,"Your Skip is ready: bring your army home." end
 end
 if definition.passId then
  if not record.ready then return false,"Please wait while passes are checked." end
  if record.owned[key] then return false,"You already own this pass." end
 elseif not productReady then return false,"Purchases need a safely loaded, saved profile." end
 if definition.coins and session.coins>Currency.MaxCoins-definition.coins then return false,"Spend some coins before buying this pack." end
 if definition.chickenOffer then
  -- One step at a time; the chicken needs a free Flock spot.
  if (session.chickenOfferStep or 0)>=definition.chickenOffer then return false,"You already own this offer." end
  if (session.chickenOfferStep or 0)+1~=definition.chickenOffer then return false,"Unlock the earlier offers first." end
  if session:Count()>=session:CollectionLimit() then return false,"You have the most chickens you can keep ("..Config.StorageLimit.."). Sell some first." end
 end
 if definition.finishEggs and #session.eggProcessor.batches==0 then return false,"There are no eggs waiting to sell." end
 if definition.crates and session.crateCredits>1e9-definition.crates then return false,"Open some crates before buying more." end
 if definition.crates and not self.catalog.Crate.enabled then return false,"Crate rewards are being prepared." end
 if definition.paidRandom then
  if not record.policyReady then return false,"Please wait while purchase availability is checked." end
  local guaranteed=key=="DoubleLuck" and self.catalog.RestrictedTreatment=="GuaranteedOffers"
  if not record.paidRandomAllowed and not guaranteed then return false,"This random purchase is unavailable for your account." end
 end
 if shortfall then
  local log,cfg=promptLog(session),(Config :: any).CoinsPrompt or {}
  log.count+=1
  log.readyAt=now+(cfg.CooldownSeconds or 0)
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
