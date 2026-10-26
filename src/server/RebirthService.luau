--!strict
-- Rebirth v2 (October 20 overhaul; docs/team/OVERHAUL_CONTRACT_20261020.md §7).
-- Coins on hand are the only requirement (no camps, no King). A Rebirth resets the
-- run: Coins, the whole Upgrades tree, Chicken Feed levels and carried eggs. It keeps
-- the collection, Gems, Gem Upgrades and camp/King progress (flags are released),
-- and pays a permanent egg multiplier and Gems. A Skip credit (Robux) rebirths
-- without the Coins and resets nothing.
-- October 23 (Stevin: "no extra time skip coins ... no matter what"): Coins stay 0
-- after a Rebirth. Time Skip is removed: no Coins, no claim, no Gem card.
-- October 23 empty start (Stevin, like Drop a Fruit's "Rebirth LVL 0"): new profiles
-- (session.introRebirth == "pending") get one Rebirth 0 after the tutorial for
-- Config.Rebirth.Intro.Cost Coins: the same reset without a rank, Intro.Gems Gems and
-- x Intro.Multiplier egg income while the rank is 0 (IntroMultiplier). Saves from
-- before it (introRebirth nil) never see it.
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

-- Permanent egg Coins multiplier, rounded to a whole number: x(1 + rank); each rank from
-- EggBoostFromRank to EggBoostToRank multiplies it by EggBoostPerRank as well, and each
-- rank after that by EggLateGrowthPerRank. October 21 later (P5, REBIRTH_PACING_20261021.md
-- "reference-shaped ladder"): x2, x3, x4, x5 at Rebirth 1-4, then x10, x20, x39, x75, x142,
-- x266 at 5-10, so Rebirths 5-10 step up like the reference's ladder; the late growth
-- (x908 at 20, x2,400 at 30, x12,662 at 50) keeps a late Rebirth near an hour of play.
function RebirthService.Multiplier(rank: number): number
	local rules = settings()
	local r = clampRank(rank)
	local from, to = rules.EggBoostFromRank or 1, rules.EggBoostToRank or 0
	local boosted = math.clamp(r - from + 1, 0, math.max(0, to - from + 1))
	local late = math.max(0, r - math.max(to, 0))
	return math.floor((1 + rules.EggBonusPerRank * r) * (rules.EggBoostPerRank or 1) ^ boosted
		* (rules.EggLateGrowthPerRank or 1) ^ late + 0.5)
end

-- October 23 Rebirth 0: still to take (a new profile at rank 0 that has not taken it).
function RebirthService.IntroPending(session: any): boolean
	local intro = settings().Intro
	return intro ~= nil and intro.Enabled == true and session.introRebirth == "pending"
		and clampRank(session.rebirths) == 0
end

-- The Rebirth 0 egg income factor: Intro.Multiplier once it is taken, while the rank
-- is 0 (Rebirth 1's x2 replaces it); 1 otherwise. Separate from Multiplier(rank), which
-- stays a whole number (Multiplier(0) == 1).
function RebirthService.IntroMultiplier(session: any): number
	local intro = settings().Intro
	if intro and session.introRebirth == "done" and clampRank(session.rebirths) == 0 then
		local multiplier = intro.Multiplier
		if type(multiplier) == "number" and multiplier == multiplier and multiplier >= 1 and multiplier < math.huge then
			return multiplier
		end
	end
	return 1
end

-- The guide is complete (TutorialService sets both with the last lesson). A skipped
-- guide counts too, so a player who skipped it is never locked out of Rebirth.
local function tutorialDone(session: any): boolean
	local tutorial = session.tutorial
	return type(tutorial) == "table"
		and (tutorial.guideCompleted == true or tutorial.coreDone == true or tutorial.guideSkipped == true)
end

-- One scale for camp and King health and damage, by the attacker's rank: x1
-- through EnemyFreeRanks, then +EnemyScalePerRank per rank (x3 at 10, x8 at 30).
-- October 21: capped at EnemyScaleMaxRank, so the ranks added past 30 keep x8.
function RebirthService.EnemyScale(rank: number): number
	local rules = settings()
	local counted = math.min(clampRank(rank), rules.EnemyScaleMaxRank or rules.MaxRank)
	return 1 + rules.EnemyScalePerRank * math.max(0, counted - rules.EnemyFreeRanks)
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

-- October 23 Rebirth 0's quote (IntroPending): rank and next rank 0, no chicken to find,
-- no Skip. Not eligible until the tutorial is complete; the request is RebirthIntro.
local function introQuote(session: any): any
	local rules = settings()
	local intro = rules.Intro
	local cost: number = intro.Cost
	local coins = session.coins or 0
	local home = armyHome(session)
	local reason: string?
	if not tutorialDone(session) then reason = "Finish the tutorial first"
	elseif coins < cost then
		local short = math.ceil(cost - coins)
		reason = "Need " .. Currency.Grouped(short) .. " more " .. (if short == 1 then "Coin" else "Coins")
	elseif not home then reason = ARMY_AWAY
	end
	local effects: any = session.researchEffects or {}
	local resets, keeps = manifest(session)
	return {
		version = 2,
		intro = true,
		enabled = rules.Enabled == true,
		rank = 0,
		maxRank = rules.MaxRank,
		nextRank = 0,
		title = "Rebirth 0",
		nextTitle = "Rebirth 0",
		cost = cost,
		coins = coins,
		kingCleared = session.kingCleared == true,
		kingRequired = false,
		cashLevels = feedLevels(session),
		unlockNext = nil,
		armyHome = home,
		eligible = reason == nil,
		reason = reason,
		multiplierNow = 1,
		multiplierNext = intro.Multiplier,
		enemyScaleNext = RebirthService.EnemyScale(0),
		gemsNext = intro.Gems,
		nextChicken = nil,
		find = nil,
		keepTiers = effects.keepTiers or 0,
		resets = resets,
		keeps = keeps,
		skip = nil,
		autoRebirth = {owned = (effects.autoRebirth or 0) >= 1, enabled = session.autoRebirth == true},
	}
end

-- Cheap and server-free: it is part of every snapshot. GameServer adds missionRunning.
function RebirthService.Quote(session)
	if RebirthService.IntroPending(session) then return introQuote(session) end
	local rules = settings()
	local rank = clampRank(session.rebirths)
	local nextRank = if rank < rules.MaxRank then rank + 1 else nil
	local cost = if nextRank then RebirthService.Cost(nextRank) else nil
	local coins = session.coins or 0
	local home = armyHome(session)
	-- October 22 (Stevin): ranks 1..FindRanks need their chicken in the Index first.
	local findSpecies = if nextRank then RebirthChickens.Required(nextRank) else nil
	local findDefinition = findSpecies and PetCatalog[findSpecies]
	local found = if nextRank then RebirthChickens.Found(session, nextRank) else true
	local reason: string?
	if not rules.Enabled then reason = "Coming soon"
	elseif not nextRank or not cost then reason = "Max Rebirth reached"
	elseif coins < cost then
		local short = math.ceil(cost - coins)
		reason = "Need " .. Currency.Grouped(short) .. " more " .. (if short == 1 then "Coin" else "Coins")
	elseif not found then reason = "Find " .. (findDefinition and findDefinition.name or findSpecies) .. " first"
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
		-- After Rebirth 0 the rank is still 0, but it reads "Rebirth 0" at x1.5.
		title = if rank == 0 and session.introRebirth == "done" then "Rebirth 0" else RebirthService.Title(rank),
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
		multiplierNow = RebirthService.Multiplier(rank) * RebirthService.IntroMultiplier(session),
		multiplierNext = if nextRank then RebirthService.Multiplier(nextRank) else nil,
		enemyScaleNext = if nextRank then RebirthService.EnemyScale(nextRank) else nil,
		gemsNext = if nextRank then RebirthService.Gems(session, nextRank) else nil,
		nextChicken = chickenInfo(nextRank),
		-- October 22: the chicken to find before this Rebirth (ranks 1..FindRanks), or nil.
		find = if findSpecies then {species = findSpecies, name = findDefinition and findDefinition.name or findSpecies,
			rarity = findDefinition and findDefinition.rarity or "Common", found = found} else nil,
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
-- {rank, gems, skip, automatic}.
function RebirthService.Rebirth(session, expectedRank, server, useSkip: boolean?, automatic: boolean?): (boolean, string, any?)
	-- 1. Loaded and writable, like every other transaction.
	if not session or not session.loaded or session.closing or session.saveLost or session.dataReleasing then
		return false, "Your flock is not ready yet."
	end
	-- October 23: Rebirth 0 comes before Rebirth 1 (its own request, RebirthIntro); a
	-- Skip credit or Auto Rebirth never passes over it.
	if RebirthService.IntroPending(session) then return false, "Rebirth 0 comes first." end
	-- 2. A double tap or stale panel can't rebirth twice.
	if expectedRank ~= session.rebirths then return false, "Your Rebirth changed. Try again." end
	local skip = useSkip == true
	local quote = RebirthService.Quote(session)
	-- 3. Disabled, max rank, Coins (not for a Skip), army home: the quote's own order.
	if skip then
		if (session.rebirthSkips or 0) < 1 then return false, "You have no Skip ready." end
		if not quote.enabled then return false, "Coming soon" end
		if not quote.nextRank then return false, "Max Rebirth reached" end
		-- October 22: a Skip still needs the rank's chicken found (it is not a reward).
		if quote.find and quote.find.found ~= true then return false, "Find " .. quote.find.name .. " first" end
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
		-- October 20 (Stevin): "When you rebirth your money resets to zero." October 23: it
		-- stays 0 (no Time Skip).
		session.coins = 0
		resetFeedLevels(session)
		session.eggCarry = {count = 0, value = 0}
		session.vacuumCargo = {count = 0, value = 0}
		session.goldRolls = {count = 0}
	end
	session.rebirths = nextRank
	-- Derived run state (Army Size, podiums, Flock, Luck tiers) follows the tree.
	session:RefreshEffects()
	-- 7. Rewards: Gems.
	local gems = RebirthService.Gems(session, nextRank)
	session.gems = math.min(1e12, (session.gems or 0) + gems)
	session.gemsEarned = math.min(1e12, (session.gemsEarned or 0) + gems)
	-- October 22: no chicken is granted; the rank's chicken was found beforehand.
	-- The checkpoint at the new rate; DataService:Capture rewrites it on every save.
	session.offlineCash = OfflineCash.Checkpoint(session, os.time())
	-- 8. Derived state. GameServer runs armyCommands:Sync and world:UpdateSession after.
	session:RefreshArmy()
	session:Touch()
	-- 9. Durable right away.
	requestSave(server, session)
	-- 10. Observation only.
	record(server, session, nextRank, coinsBefore, gems, skip, automatic == true)
	return true, "Rebirth complete: " .. RebirthService.Title(nextRank),
		{rank = nextRank, gems = gems, skip = skip, automatic = automatic == true}
end

-- October 23 Rebirth 0 (request RebirthIntro). Refused unless it is pending, the
-- tutorial is complete, the Coins are on hand and no battle or Mission holds the army.
-- The same reset as a Rebirth (Coins to 0, the tree except Keep Upgrades and
-- mutationKeep, Feed levels, carried eggs, Gold roll counts, camps released, yard eggs
-- settled) without changing the rank; then introRebirth = "done" and Intro.Gems Gems.
-- Returns ok, message and (on success) a receipt {rank = 0, gems, intro = true}.
function RebirthService.RebirthIntro(session: any, server: any): (boolean, string, any?)
	if not session or not session.loaded or session.closing or session.saveLost or session.dataReleasing then
		return false, "Your flock is not ready yet."
	end
	if not RebirthService.IntroPending(session) then
		return false, if session.introRebirth == "done" then "Rebirth 0 is already done." else "Rebirth 0 isn't available."
	end
	local intro = settings().Intro
	local quote = RebirthService.Quote(session)
	if not quote.eligible then
		if quote.reason == ARMY_AWAY and operationRunning(session, server) then return false, MISSION end
		return false, quote.reason or "You can't rebirth right now."
	end
	if operationRunning(session, server) then return false, MISSION end
	if session.defending ~= nil or battleInvolves(session, server) then return false, ARMY_AWAY end
	releaseTerritories(session, server)
	-- Settle yard eggs into the bag, then empty it (as a Rebirth does).
	local eggs = server and server.eggs
	if eggs and eggs.Release then eggs:Release(session) end
	-- The reset. No yields from here to the save request.
	session.upgradeTree = keptTree(session)
	session.coins = 0
	resetFeedLevels(session)
	session.eggCarry = {count = 0, value = 0}
	session.vacuumCargo = {count = 0, value = 0}
	session.goldRolls = {count = 0}
	session.introRebirth = "done"
	session:RefreshEffects()
	local gems = math.max(0, math.floor(tonumber(intro.Gems) or 0))
	session.gems = math.min(1e12, (session.gems or 0) + gems)
	session.gemsEarned = math.min(1e12, (session.gemsEarned or 0) + gems)
	-- The checkpoint at the new rate (x Intro.Multiplier); DataService rewrites it on save.
	session.offlineCash = OfflineCash.Checkpoint(session, os.time())
	session:RefreshArmy()
	session:Touch()
	requestSave(server, session)
	-- Observation only.
	local analytics: any = server and server.analytics
	if analytics then
		analytics:LaunchCount(session, "rebirth0.count")
		if gems > 0 then
			analytics:LaunchCount(session, "gems.earned", gems)
			if analytics.Gems then analytics:Gems(session, "Source", gems, "Rebirth0") end
		end
	end
	return true, "Rebirth complete: Rebirth 0", {rank = 0, gems = gems, intro = true, skip = false, automatic = false}
end

-- Server step (GameServer, about once a second): a waiting Skip credit rebirths as
-- soon as the army is home; Auto Rebirth rebirths as soon as the quote is eligible.
-- October 23: neither passes over a pending Rebirth 0 (RebirthIntro is the player's).
function RebirthService.Step(session, server): (boolean, string?, any?)
	if not session.loaded or session.closing or session.saveLost or session.dataReleasing then return false end
	if RebirthService.IntroPending(session) then return false end
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
