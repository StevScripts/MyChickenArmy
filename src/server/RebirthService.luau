--!strict
-- Rebirth v2 (October 20 overhaul; docs/team/OVERHAUL_CONTRACT_20261020.md §7).
-- Coins on hand are the only requirement (no camps, no King). A Rebirth resets the
-- run: Coins, the whole Upgrades tree, Chicken Feed levels and carried eggs. It keeps
-- the collection, Gems, Gem Upgrades and camp/King progress (flags are released),
-- and pays a permanent egg multiplier, Gems, Time Skip Coins and the rank's Rebirth
-- chicken. A Skip credit (Robux) rebirths without the Coins and resets nothing.
-- Every number is Config.Rebirth. PlayerSession and BattleService require this
-- module, so it must never require either of them.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local CampaignRoute = require(Shared.CampaignRoute)
local OfflineCash = require(script.Parent.OfflineCash)
local KingEncounter = require(script.Parent.KingEncounter)
local MutationCatalog = require(Shared.MutationCatalog)
local Rules = require(Shared.Rules)
local Currency = require(Shared.CurrencyLimits)
local UpgradeCatalog = require(Shared.UpgradeCatalog)
local ShopCatalog = require(Shared.ShopCatalog)
local PetCatalog = require(Shared.PetCatalog)
local DailyService = require(script.Parent.DailyService)
local RebirthChickens = require(script.Parent.RebirthChickens)
local RebirthService = {}

local ARMY_AWAY = "Bring your army back to your base first"
local MISSION = "Finish your mission first."
-- Run upgrades Keep Upgrades protects, up to keepTiers tiers each.
local KEPT_FAMILIES = {"EggSpeed", "EggValue", "Luck"}

local function settings()
	return Config.Rebirth
end

-- Saved ranks are whole numbers in 0..MaxRank (PlayerSession.readRebirths); junk reads as 0.
local function clampRank(rank: any): number
	if type(rank) ~= "number" or rank ~= rank or rank < 0 then return 0 end
	return math.min(math.floor(rank), settings().MaxRank)
end

-- Player-facing names are "Rebirth 1", "Rebirth 2", … (October 14 glossary).
function RebirthService.Title(rank: number): string
	local r = clampRank(rank)
	return if r == 0 then "No rebirths yet" else "Rebirth " .. r
end

-- Permanent egg Coins multiplier: x2 at Rebirth 1, x3 at Rebirth 2, …
function RebirthService.Multiplier(rank: number): number
	return 1 + settings().EggBonusPerRank * clampRank(rank)
end

-- One scale for camp and King health and damage, by the attacker's rank: x1
-- through EnemyFreeRanks, then +EnemyScalePerRank per rank (x3 at 10, x8 at 30).
function RebirthService.EnemyScale(rank: number): number
	local rules = settings()
	return 1 + rules.EnemyScalePerRank * math.max(0, clampRank(rank) - rules.EnemyFreeRanks)
end

-- October 20 tree v2 (Stevin, S9c): mutations are bought in the Upgrades tree, so no rank
-- unlocks one any more. Kept for the panel's `unlockNext` field, which stays empty.
function RebirthService.Unlock(_rank: number): {name: string, multiplier: number}?
	return nil
end

-- Coins needed for `rank`; nil outside 1..MaxRank.
function RebirthService.Cost(rank: number): number?
	local rules = settings()
	if type(rank) ~= "number" or rank ~= rank or rank % 1 ~= 0 or rank < 1 or rank > rules.MaxRank then return nil end
	local listed = rules.Costs[rank]
	if type(listed) == "number" then return listed end
	return rules.Costs[#rules.Costs] + rules.CostStep * (rank - #rules.Costs)
end

-- Gems the Rebirth to `rank` pays, with More Gems.
function RebirthService.Gems(session, rank: number): number
	local rules = settings()
	local bonus = session.researchEffects and session.researchEffects.gemBonus or 0
	return math.floor((rules.GemsBase + rules.GemsPerRank * clampRank(rank)) * (1 + bonus) + 1e-9)
end

-- Levels bought with Chicken Feed (pet.cashLevels). A Rebirth removes them; levels
-- a chicken was rolled or fused with stay, as do Giants, sizes and mutations.
local function feedLevels(session): number
	local total = 0
	for _, pet in session.pets or {} do total += pet.cashLevels or 0 end
	return total
end

local function resetFeedLevels(session)
	for _, pet in session.pets or {} do
		local bought = pet.cashLevels or 0
		if bought > 0 then
			local level = math.max(1, (pet.level or 1) - bought)
			-- Refunds follow what the chicken is now worth, never more than was paid.
			local investment = pet.investment or Rules.Investment(pet.species, pet.level)
			pet.level = level
			pet.investment = math.min(investment, Rules.Investment(pet.species, level))
		end
		pet.cashLevels = nil
	end
end

-- The tree a Rebirth leaves: only Keep Upgrades' tiers of Egg Speed, Egg Value and Luck,
-- plus the mutations a save already had by rank (mutationKeep, S9c), which never reset.
local function keptTree(session): {[string]: number}
	local keep = session.researchEffects and session.researchEffects.keepTiers or 0
	local tree = {}
	for _, family in KEPT_FAMILIES do
		local tier = math.min(UpgradeCatalog.Tier(session.upgradeTree, family), keep)
		if tier > 0 then tree[family] = tier end
	end
	local mutations = UpgradeCatalog.Families.Mutation
	local kept = if type(session.mutationKeep) == "number" then math.floor(session.mutationKeep) else 0
	if mutations and kept > 0 then tree.Mutation = math.min(kept, #mutations.tiers) end
	return tree
end

-- Egg Coins per second for Time Skip: what the player earns right now, before the
-- reset. That is the best Flock-size chickens at today's tiers, Chicken Feed levels and
-- rank, with 2x Egg Spawn, 2x Coins and Coin Boost, but no live Gold Rush or Friend
-- Boost (a steady rate, like offline and daily rewards). The daily income floor applies.
local function eggIncome(session): number
	local tree = session.upgradeTree
	-- Flock Size with +1 Flock Slot Gem Upgrades (S7b), as PlayerSession:FlockSize.
	local flockSize = session.researchEffects and session.researchEffects.flockSize
	local layers = if type(flockSize) == "number" then math.floor(flockSize) else UpgradeCatalog.Value(tree, "Flock")
	local rates = {}
	for _, pet in session.pets or {} do
		table.insert(rates, Rules.EggRate(pet.species, pet.stars or 1, pet.level) * MutationCatalog.Multiplier(pet.mutation))
	end
	table.sort(rates, function(a, b) return a > b end)
	local eggs = 0
	for index = 1, math.min(#rates, layers) do eggs += rates[index] end
	local entitlements = session.entitlements or {}
	local effects = session.researchEffects or {}
	local speed = UpgradeCatalog.EggSpeedRates[UpgradeCatalog.Tier(tree, "EggSpeed") + 1] or 1
	local rate = eggs * speed * (if entitlements.DoubleEggSpawn then 2 else 1)
		* Rules.EggUnitValue(UpgradeCatalog.Tier(tree, "EggValue"))
		* (if entitlements.DoubleCash then 2 else 1) * RebirthService.Multiplier(session.rebirths or 0)
		* (1 + (effects.coinBoost or 0))
	if rate ~= rate or rate == math.huge then return DailyService.MinIncome end
	return math.max(DailyService.MinIncome, rate)
end

-- Coins Time Skip pays on the next Rebirth: timeSkipMinutes of today's egg income,
-- measured just before the reset (the panel's preview is the same number). P0 chose
-- this over the post-reset income, which paid a few millionths of a rank's cost.
function RebirthService.TimeSkipCoins(session): number
	local minutes = session.researchEffects and session.researchEffects.timeSkipMinutes or 0
	if minutes <= 0 then return 0 end
	local coins = math.floor(eggIncome(session) * minutes * 60)
	return math.max(0, math.min(coins, Currency.MaxCoins))
end

local function armyHome(session): boolean
	return session.armyState == "Home" and session.outgoing == nil and session.incoming == nil
end

local function chickenInfo(rank: number?)
	local species = if rank then RebirthChickens.Species(rank) else nil
	local definition = species and PetCatalog[species]
	return if definition then {species = species, name = definition.name, rarity = definition.rarity} else nil
end

-- The reset manifest the Rebirth screen shows (same lists the transaction applies).
local function manifest(session)
	local keep = session.researchEffects and session.researchEffects.keepTiers or 0
	local resets = {"All your Coins", "Every upgrade in the Upgrades tree, mutations included",
		"Chicken levels bought with Chicken Feed", "Carried eggs"}
	if keep > 0 then
		resets[2] = "The Upgrades tree (you keep " .. keep .. (if keep == 1 then " tier" else " tiers")
			.. " of Egg Speed, Egg Value and Luck)"
	end
	local keeps = {"Every chicken and the Index", "Gems and Gem Upgrades", "Camps and the King you beat", "Passes"}
	-- Mutations a save had by rank before the tree sold them (S9c) never reset.
	local kept = if type(session.mutationKeep) == "number" then math.floor(session.mutationKeep) else 0
	if kept > 0 then
		local names = {}
		for index = 1, math.min(kept, #MutationCatalog.Order) do table.insert(names, MutationCatalog.Order[index]) end
		table.insert(keeps, "Your " .. table.concat(names, ", ") .. " mutation unlocks")
	end
	return resets, keeps
end

-- Cheap and server-free: it is part of every snapshot. GameServer adds missionRunning.
function RebirthService.Quote(session)
	local rules = settings()
	local rank = clampRank(session.rebirths)
	local nextRank = if rank < rules.MaxRank then rank + 1 else nil
	local cost = if nextRank then RebirthService.Cost(nextRank) else nil
	local coins = session.coins or 0
	local home = armyHome(session)
	local reason: string?
	if not rules.Enabled then reason = "Coming soon"
	elseif not nextRank or not cost then reason = "Max Rebirth reached"
	elseif coins < cost then
		local short = math.ceil(cost - coins)
		reason = "Need " .. Currency.Grouped(short) .. " more " .. (if short == 1 then "Coin" else "Coins")
	elseif not home then reason = ARMY_AWAY
	end
	local effects = session.researchEffects or {}
	local resets, keeps = manifest(session)
	local skipKey = if nextRank then ShopCatalog.RebirthSkipFor(nextRank) else nil
	return {
		version = 2,
		enabled = rules.Enabled == true,
		rank = rank,
		maxRank = rules.MaxRank,
		nextRank = nextRank,
		title = RebirthService.Title(rank),
		nextTitle = if nextRank then RebirthService.Title(nextRank) else nil,
		cost = cost,
		coins = coins,
		-- Kept for the pre-v2 panel until S8 ships: no King requirement any more.
		kingCleared = session.kingCleared == true,
		kingRequired = false,
		cashLevels = feedLevels(session),
		unlockNext = if nextRank then RebirthService.Unlock(nextRank) else nil,
		armyHome = home,
		eligible = reason == nil,
		reason = reason,
		multiplierNow = RebirthService.Multiplier(rank),
		multiplierNext = if nextRank then RebirthService.Multiplier(nextRank) else nil,
		enemyScaleNext = if nextRank then RebirthService.EnemyScale(nextRank) else nil,
		gemsNext = if nextRank then RebirthService.Gems(session, nextRank) else nil,
		timeSkipMinutes = effects.timeSkipMinutes or 0,
		timeSkipCoins = if nextRank then RebirthService.TimeSkipCoins(session) else 0,
		nextChicken = chickenInfo(nextRank),
		keepTiers = effects.keepTiers or 0,
		resets = resets,
		keeps = keeps,
		skip = {credits = session.rebirthSkips or 0, productKey = skipKey,
			onSale = skipKey ~= nil and ShopCatalog.ProductOnSale(skipKey),
			restricted = session.paidRandomRestricted == true},
		autoRebirth = {owned = (effects.autoRebirth or 0) >= 1, enabled = session.autoRebirth == true},
	}
end

local function operationRunning(session, server): boolean
	local battles = server and server.battles
	local battle = battles and battles.battles and session.outgoing and battles.battles[session.outgoing]
	return battle ~= nil and battle.operationId ~= nil
end
RebirthService.OperationRunning = operationRunning

-- Any live battle that still names this player (march, fight, hold, return,
-- defense or a Hill contest) means part of the army is away.
local function battleInvolves(session, server): boolean
	local battles = server and server.battles
	if not battles or not battles.battles then return false end
	for _, battle in battles.battles do
		if battle.attacker == session.userId or battle.defender == session.userId then return true end
	end
	return false
end

-- Territory key -> the target id BattleService:Unclaim accepts.
local function unclaimTarget(session, key: string): string?
	if key == KingEncounter.Target then return key end
	if key:match("^outpost:%d+$") then return key end
	local plot, index = key:match("^(%-?%d+):(%d+)$")
	if plot and index then
		return CampaignRoute.CampId(tonumber(index), tonumber(plot), session.plotIndex)
	end
	return nil
end

-- Releases camps, outposts and the King through the player's own Unclaim path.
-- The Hill ("income:1") is a timed round owned by HillService and is left alone.
local function releaseTerritories(session, server): number
	local battles = server and server.battles
	if not battles or not battles.campOwners then return 0 end
	local keys = {}
	for key, owner in battles.campOwners do
		if owner.userId == session.userId and key ~= "income:1" then table.insert(keys, key) end
	end
	local now = os.clock()
	for _, key in keys do
		local target = unclaimTarget(session, key)
		local released = target ~= nil and battles:Unclaim(session, target, now)
		-- Closest public fallback when Unclaim can't name or locate the base.
		if not released and battles.campOwners[key] and battles.campOwners[key].userId == session.userId then
			battles:SetTerritoryOwner(key, nil)
		end
	end
	-- The held-territory egg bonus ends now, not at the next battle step.
	if #keys > 0 and battles.RefreshTerritoryBonus then battles:RefreshTerritoryBonus() end
	return #keys
end

-- Observation only (AnalyticsSchema version 7 names).
local function record(server, session, rank: number, coinsBefore: number, gems: number, skip: boolean, automatic: boolean)
	local analytics = server and server.analytics
	if not analytics then return end
	analytics:LaunchCount(session, "rebirth.count")
	analytics:LaunchHist(session, "rebirth.cashAtRebirth", coinsBefore)
	if analytics:LaunchFirst(session, "rebirth2.rank." .. rank) then
		local seconds = analytics:PlaySeconds(session)
		if seconds then analytics:LaunchHist(session, "rebirth2.playSeconds." .. rank, seconds) end
	end
	if skip then analytics:LaunchCount(session, "rebirth2.skip") end
	if automatic then analytics:LaunchCount(session, "rebirth2.auto") end
	if gems > 0 then
		analytics:LaunchCount(session, "gems.earned", gems)
		if analytics.Gems then analytics:Gems(session, "Source", gems, "Rebirth") end
	end
end

-- Spawned like DataService:Step's autosave: Save captures ToData before its first
-- yield, so this snapshot already holds the Rebirth. A save already in flight
-- refuses; the next autosave or the release on leave then carries the new rank.
local function requestSave(server, session)
	local data = server and server.data
	if not data or not data.Save or session.closing or session.dataReleasing then return end
	local entry = data.entries and data.entries[session.userId]
	if not entry or entry.session ~= session then return end
	task.spawn(function()
		pcall(function() data:Save(session, false) end)
	end)
end

-- Returns ok, message and (on success) a receipt for the reveal:
-- {rank, gems, timeSkipCoins, petId?, species?, skip, automatic}.
function RebirthService.Rebirth(session, expectedRank, server, useSkip: boolean?, automatic: boolean?): (boolean, string, any?)
	-- 1. Loaded and writable, like every other transaction.
	if not session or not session.loaded or session.closing or session.saveLost or session.dataReleasing then
		return false, "Your flock is not ready yet."
	end
	-- 2. A double tap or stale panel can't rebirth twice.
	if expectedRank ~= session.rebirths then return false, "Your Rebirth changed. Try again." end
	local skip = useSkip == true
	local quote = RebirthService.Quote(session)
	-- 3. Disabled, max rank, Coins (not for a Skip), army home: the quote's own order.
	if skip then
		if (session.rebirthSkips or 0) < 1 then return false, "You have no Skip ready." end
		if not quote.enabled then return false, "Coming soon" end
		if not quote.nextRank then return false, "Max Rebirth reached" end
		if not quote.armyHome then
			return false, if operationRunning(session, server) then MISSION else "Skip ready: bring your army home."
		end
	elseif not quote.eligible then
		if quote.reason == ARMY_AWAY and operationRunning(session, server) then return false, MISSION end
		return false, quote.reason or "You can't rebirth right now."
	end
	-- 4. No Mission and no battle that still holds part of the army.
	if operationRunning(session, server) then return false, MISSION end
	if session.defending ~= nil or battleInvolves(session, server) then return false, ARMY_AWAY end
	local nextRank = quote.nextRank :: number
	local coinsBefore = session.coins
	-- Time Skip is measured on today's run, before anything resets.
	local timeSkip = RebirthService.TimeSkipCoins(session)
	-- 5. Release every held camp, outpost and the King. Camp and King progress stay.
	releaseTerritories(session, server)
	-- Yard eggs: EggService:Release settles in-flight claims and rover cargo into the
	-- bag, then drops the yard; the next step lays a fresh one. The bag is emptied
	-- below, so pre-Rebirth eggs never pay at the new multiplier.
	local eggs = server and server.eggs
	if eggs and eggs.Release then eggs:Release(session) end
	-- 6. The reset. No yields from here to the save request.
	if skip then
		-- A Skip keeps the whole run: Coins, tree, Feed levels and carried eggs.
		session.rebirthSkips -= 1
	else
		session.upgradeTree = keptTree(session)
		-- October 20 (Stevin): "When you rebirth your money resets to zero." Time Skip still pays below.
		session.coins = 0
		resetFeedLevels(session)
		session.eggCarry = {count = 0, value = 0}
		session.vacuumCargo = {count = 0, value = 0}
		session.goldRolls = {count = 0}
	end
	session.rebirths = nextRank
	-- Derived run state (Army Size, podiums, Flock, Luck tiers) follows the tree.
	session:RefreshEffects()
	-- 7. Rewards: Gems, Time Skip Coins (measured above) and the chicken.
	local gems = RebirthService.Gems(session, nextRank)
	session.gems = math.min(1e12, (session.gems or 0) + gems)
	session.gemsEarned = math.min(1e12, (session.gemsEarned or 0) + gems)
	timeSkip = math.max(0, math.floor(math.min(timeSkip, Currency.MaxCoins - session.coins)))
	-- "rebirth" is not an earned source, so Credit pays it exactly (analytics: TimeSkip).
	if timeSkip > 0 then timeSkip = session:Credit(timeSkip, "rebirth") end
	local petId = RebirthChickens.Grant(session, nextRank)
	-- The checkpoint at the new rate; DataService:Capture rewrites it on every save.
	session.offlineCash = OfflineCash.Checkpoint(session, os.time())
	-- 8. Derived state. GameServer runs armyCommands:Sync and world:UpdateSession after.
	session:RefreshArmy()
	session:Touch()
	-- 9. Durable right away.
	requestSave(server, session)
	-- 10. Observation only.
	record(server, session, nextRank, coinsBefore, gems, skip, automatic == true)
	if petId and server and server.analytics then server.analytics:LaunchCount(session, "rebirthChicken.granted") end
	return true, "Rebirth complete: " .. RebirthService.Title(nextRank),
		{rank = nextRank, gems = gems, timeSkipCoins = timeSkip, petId = petId,
			species = RebirthChickens.Species(nextRank), skip = skip, automatic = automatic == true}
end

-- Server step (GameServer, about once a second): a waiting Skip credit rebirths as
-- soon as the army is home; Auto Rebirth rebirths as soon as the quote is eligible.
function RebirthService.Step(session, server): (boolean, string?, any?)
	if not session.loaded or session.closing or session.saveLost or session.dataReleasing then return false end
	if not armyHome(session) or session.defending ~= nil or operationRunning(session, server)
		or battleInvolves(session, server) then return false end
	if (session.rebirthSkips or 0) > 0 and clampRank(session.rebirths) < settings().MaxRank then
		return RebirthService.Rebirth(session, session.rebirths, server, true, false)
	end
	local effects = session.researchEffects
	if effects and (effects.autoRebirth or 0) >= 1 and session.autoRebirth == true
		and RebirthService.Quote(session).eligible then
		return RebirthService.Rebirth(session, session.rebirths, server, false, true)
	end
	return false
end

return RebirthService
