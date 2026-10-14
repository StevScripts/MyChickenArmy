--!strict
-- Re-enlist (rebirth). Resets the economy and the war, keeps the collection and
-- research, and pays a permanent egg multiplier; camps and the King get stronger
-- per rank. Contract: docs/team/launch/11_R1_REBIRTH_SERVER.md. Every number is
-- Config.Rebirth. PlayerSession and BattleService require this module, so it must
-- never require either of them.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local CampaignRoute = require(Shared.CampaignRoute)
local OfflineCash = require(script.Parent.OfflineCash)
local KingEncounter = require(script.Parent.KingEncounter)
local RebirthService = {}

local ARMY_AWAY = "Bring your army back to your base first"

local function settings()
	return Config.Rebirth
end

-- Saved ranks are whole numbers in 0..MaxRank (PlayerSession.readRebirths); junk reads as 0.
local function clampRank(rank: any): number
	if type(rank) ~= "number" or rank ~= rank or rank < 0 then return 0 end
	return math.min(math.floor(rank), settings().MaxRank)
end

-- Player-facing names are "Rebirth 1", "Rebirth 2", … (October 14 glossary);
-- Veteran/Elite/Royal are Invasion tier names only. Matches RebirthPanel.Title.
-- The saved rank stays a plain number.
function RebirthService.Title(rank: number): string
	local r = clampRank(rank)
	return if r == 0 then "No rebirths yet" else "Rebirth " .. r
end

-- Earned ranks keep their bonus and their stronger enemies even while Enabled is
-- false: the switch only stops new re-enlists.
function RebirthService.Multiplier(rank: number): number
	return 1 + settings().EggBonusPerRank * clampRank(rank)
end

-- One scale for camp and King health and damage (the foundation hooks pass a
-- single number). EnemyDamagePerRank is not read; see the R1-S handoff.
function RebirthService.EnemyScale(rank: number): number
	return 1 + settings().EnemyHealthPerRank * clampRank(rank)
end

-- Cash to reach `rank`; nil outside 1..MaxRank.
function RebirthService.Cost(rank: number): number?
	local rules = settings()
	if type(rank) ~= "number" or rank ~= rank or rank % 1 ~= 0 or rank < 1 or rank > rules.MaxRank then return nil end
	return math.floor(rules.BaseCost * rules.CostGrowth ^ (rank - 1) + 0.5)
end

local function armyHome(session): boolean
	return session.armyState == "Home" and session.outgoing == nil and session.incoming == nil
end

-- Cheap and server-free: it is part of every snapshot.
function RebirthService.Quote(session)
	local rules = settings()
	local rank = clampRank(session.rebirths)
	local nextRank = if rank < rules.MaxRank then rank + 1 else nil
	local cost = if nextRank then RebirthService.Cost(nextRank) else nil
	local coins = session.coins or 0
	local home = armyHome(session)
	local kingCleared = session.kingCleared == true
	local reason: string?
	if not rules.Enabled then reason = "Coming soon"
	elseif not nextRank or not cost then reason = "Max Rebirth reached"
	elseif not kingCleared then reason = "Defeat the Chicken King first"
	elseif coins < cost then reason = "Need $" .. string.format("%d", math.ceil(cost - coins)) .. " more"
	elseif not home then reason = ARMY_AWAY
	end
	return {
		enabled = rules.Enabled == true,
		rank = rank,
		nextRank = nextRank,
		title = RebirthService.Title(rank),
		nextTitle = if nextRank then RebirthService.Title(nextRank) else nil,
		cost = cost,
		coins = coins,
		kingCleared = kingCleared,
		armyHome = home,
		eligible = reason == nil,
		reason = reason,
		multiplierNow = RebirthService.Multiplier(rank),
		multiplierNext = if nextRank then RebirthService.Multiplier(nextRank) else nil,
		enemyScaleNext = if nextRank then RebirthService.EnemyScale(nextRank) else nil,
	}
end

local function operationRunning(session, server): boolean
	local battles = server and server.battles
	local battle = battles and battles.battles and session.outgoing and battles.battles[session.outgoing]
	return battle ~= nil and battle.operationId ~= nil
end

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

local function record(server, session, rank: number, coinsBefore: number)
	local analytics = server and server.analytics
	if not analytics then return end
	analytics:LaunchCount(session, "rebirth.count")
	analytics:LaunchHist(session, "rebirth.cashAtRebirth", coinsBefore)
	if analytics:LaunchFirst(session, "rebirth.rank." .. rank) then
		local seconds = analytics:PlaySeconds(session)
		if seconds then analytics:LaunchHist(session, "rebirth.playSeconds." .. rank, seconds) end
	end
end

-- Spawned like DataService:Step's autosave: Save captures ToData before its first
-- yield, so this snapshot already holds the re-enlist. A save already in flight
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

function RebirthService.Rebirth(session, expectedRank, server): (boolean, string)
	-- 1. Loaded and writable, like every other transaction.
	if not session or not session.loaded or session.closing or session.saveLost or session.dataReleasing then
		return false, "Your flock is not ready yet."
	end
	-- 2. A double tap or stale panel can't re-enlist twice.
	if expectedRank ~= session.rebirths then return false, "Your Rebirth changed. Try again." end
	-- 3. Disabled, max rank, King, cash, army home (the quote's own order).
	local quote = RebirthService.Quote(session)
	if not quote.eligible then
		if quote.reason == ARMY_AWAY and operationRunning(session, server) then
			return false, "Finish your Invasion first."
		end
		return false, quote.reason or "You can't rebirth right now."
	end
	-- 4. No Operation and no battle that still holds part of the army.
	if operationRunning(session, server) then return false, "Finish your Invasion first." end
	if session.defending ~= nil or battleInvolves(session, server) then return false, ARMY_AWAY end
	local nextRank = quote.nextRank :: number
	local coinsBefore = session.coins
	-- 5. Release every held camp, outpost and the King.
	releaseTerritories(session, server)
	-- Yard eggs: EggService:Release settles in-flight claims and rover cargo into
	-- the bag, then drops the yard; the next step lays a fresh one. The bag is
	-- emptied below, so pre-rank eggs never pay at the new multiplier.
	local eggs = server and server.eggs
	if eggs and eggs.Release then eggs:Release(session) end
	-- 6. The reset. No yields from here to the save request.
	session.coins = Config.StartingCoins
	session.eggSpeedLevel, session.incomeLevel, session.luck = 0, 0, 0
	session.firstWins, session.frontierWins, session.laneCamps = {}, {}, {}
	session.campUnlocked = 1 -- Derived from firstWins (PlayerSession:LoadData).
	session.kingCleared, session.kingBountyPaid = false, false
	session.eggCarry = {count = 0, value = 0}
	session.rebirths = nextRank
	-- The checkpoint at the new rate; DataService:Capture rewrites it on every save.
	session.offlineCash = {at = os.time(), rate = OfflineCash.Rate(session),
		maxSeconds = (session.researchEffects and session.researchEffects.offlineHours or 8) * 3600}
	-- 7. Derived state. Research effects read only research, which is kept.
	-- GameServer runs armyCommands:Sync and world:UpdateSession after this returns.
	session:RefreshArmy()
	session:Touch()
	-- 8. Durable right away.
	requestSave(server, session)
	-- 9. Observation only.
	record(server, session, nextRank, coinsBefore)
	-- 10.
	return true, "Rebirth complete: " .. RebirthService.Title(nextRank)
end

return RebirthService
