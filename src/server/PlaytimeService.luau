--!strict
-- October 20 Playtime Rewards and the boosts readout (S16, docs/team/PLAYTIME_REWARDS.md).
-- The server owns the visit's playtime, the claims, the timed boosts and the total
-- Coins/Luck multipliers the HUD shows top right. Stevin, October 20: the clock and
-- the claims reset every join, so nothing here is saved.
--   session.playtime = {startedAt = server time the save finished loading, claimed = {[index]=true}}
--   session.playtimeBoosts = {[kind] = {bonus, endsAt}} -- kind "Luck" | "Coins", server time
-- Coins tiles pay minutes of the steady egg income through DailyService.CashFor (2x
-- Coins, Rebirth and Coin Boost included; Gold Rush and Friend Boost never), credited
-- as source "playtime". A Luck boost multiplies roll Luck the way a Gold roll does
-- (PlayerSession:RollLuckBonus); a Coins boost is a live factor on earned Coins next
-- to Gold Rush (PlayerSession:EarnedAmount), never offline. Free Rolls are Hill-roll
-- credits that HillService delivers as chickens.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local PlaytimeRewards = require(Shared.PlaytimeRewards)
local UpgradeCatalog = require(Shared.UpgradeCatalog)
local Rules = require(Shared.Rules)
local Currency = require(Shared.CurrencyLimits)
local Catalog = require(Shared.PetCatalog)
local DailyService = require(script.Parent.DailyService)
local PlaytimeService = {}

type Visit = {startedAt: number?, claimed: {[number]: boolean}}
type Boost = {bonus: number, endsAt: number}

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- The visit's record, created on first use (PlayerSession:Reset clears it).
local function record(session): Visit
	local playtime = session.playtime
	if type(playtime) ~= "table" then
		local fresh: Visit = {startedAt = nil, claimed = {}}
		session.playtime = fresh
		return fresh
	end
	return playtime
end

-- Starts the clock once the save is ready; a session that never loads never counts.
function PlaytimeService.Begin(session, now: number?)
	local playtime = record(session)
	if playtime.startedAt == nil and session.loaded == true then playtime.startedAt = now or serverNow() end
	return playtime
end

-- Seconds played in this visit (0 until the save is ready).
function PlaytimeService.Played(session, now: number?): number
	local startedAt = record(session).startedAt
	if type(startedAt) ~= "number" then return 0 end
	return math.max(0, (now or serverNow()) - startedAt)
end

-- The running bonus of a boost kind (+1 = +100%), 0 when none runs.
function PlaytimeService.Boost(session, kind: string, now: number?): number
	local boosts = session.playtimeBoosts
	local boost: Boost? = if type(boosts) == "table" then boosts[kind] else nil
	if boost == nil or (now or serverNow()) >= boost.endsAt then return 0 end
	return boost.bonus
end

-- A second boost of the same kind adds its time; the bonus never drops while one runs.
function PlaytimeService.AddBoost(session, kind: string, bonus: number, seconds: number, now: number?)
	local at = now or serverNow()
	local boosts: {[string]: Boost} = session.playtimeBoosts
	if type(boosts) ~= "table" then
		boosts = {}
		session.playtimeBoosts = boosts
	end
	local running = boosts[kind]
	if running and running.endsAt > at then
		boosts[kind] = {bonus = math.max(running.bonus, bonus), endsAt = running.endsAt + seconds}
	else
		boosts[kind] = {bonus = bonus, endsAt = at + seconds}
	end
end

local function tileAt(index: any): PlaytimeRewards.Tile?
	if type(index) ~= "number" or index ~= index or index % 1 ~= 0 then return nil end
	return PlaytimeRewards.Tiles[index]
end

-- Pays one ready tile. Returns ok, the player's message and a receipt for the client
-- ({index, kind, coins?, boost?, species?}). `server` supplies HillService for rolls.
function PlaytimeService.Claim(session, index: any, server: any?): (boolean, string, any)
	if not PlaytimeRewards.Enabled then return false, "Playtime Rewards are resting right now.", nil end
	local tile = tileAt(index)
	if not tile then return false, "Choose a Playtime reward.", nil end
	local playtime = PlaytimeService.Begin(session)
	if playtime.claimed[index] then return false, "You already claimed this reward.", nil end
	local now = serverNow()
	local remaining = tile.at * 60 - PlaytimeService.Played(session, now)
	if remaining > 0 then return false, "Keep playing! This reward unlocks in " .. PlaytimeRewards.Clock(remaining) .. ".", nil end
	local receipt: {[string]: any} = {index = index, kind = tile.kind}
	local message
	if tile.kind == "Coins" then
		local coins = DailyService.CashFor(session, tile.coinMinutes or 0)
		if coins > 0 then coins = session:Credit(coins, "playtime") end
		-- Nothing paid (the wallet is full): the tile stays ready.
		if coins <= 0 then return false, "You can't hold any more Coins right now.", nil end
		receipt.coins = coins
		message = "+" .. Currency.Text(coins) .. "!"
	elseif tile.kind == "Boost" then
		local kind = tile.boost or "Luck"
		PlaytimeService.AddBoost(session, kind, tile.bonus or 0, (tile.minutes or 0) * 60, now)
		receipt.boost = kind
		message = PlaytimeRewards.BoostMessage(tile)
	else
		local rolls = tile.rolls or 0
		session.hillRollCredits = (session.hillRollCredits or 0) + rolls
		local hill = if server then server.hill else nil
		local granted: {string} = if hill then hill:Deliver(session) else {}
		receipt.species = granted
		if #granted == 0 then
			message = PlaytimeRewards.RollsText(rolls) .. "! They arrive when you have room for more chickens."
		else
			local names = {}
			for _, species in granted do
				local definition = Catalog[species]
				table.insert(names, if definition then definition.name else species)
			end
			message = PlaytimeRewards.RollsText(rolls) .. ": " .. table.concat(names, ", ") .. "!"
		end
	end
	playtime.claimed[index] = true
	session:Touch()
	return true, message, receipt
end

-- state.playtime: every tile with its server-time unlock and, for Coins, what it pays
-- right now (the steady income moves, so the number does too). The same sum as
-- DailyService.CashFor, with the income read once instead of once per tile.
function PlaytimeService.Snapshot(session)
	local playtime = PlaytimeService.Begin(session)
	local startedAt = playtime.startedAt
	local income = DailyService.Income(session)
	local headroom = math.max(0, Currency.MaxCoins - session.coins)
	local tiles = {}
	for index, tile in PlaytimeRewards.Tiles do
		tiles[index] = {
			index = index, kind = tile.kind, at = tile.at,
			unlockAt = if startedAt then startedAt + tile.at * 60 else nil,
			claimed = playtime.claimed[index] == true,
			coins = if tile.kind == "Coins" then math.floor(math.min(income * (tile.coinMinutes or 0) * 60, headroom)) else nil,
		}
	end
	return {enabled = PlaytimeRewards.Enabled, startedAt = startedAt, tiles = tiles}
end

-- state.boosts: the readout's totals and any running playtime boost.
-- Coins = what one egg sells for compared with no upgrades or boosts: Egg Value tier,
-- 2x Coins, Rebirth, Coin Boost, Gold Rush, Friend Boost, the playtime boost and a
-- held outpost's egg bonus. Luck = Luck tier, 2x Luck, Extra Luck and the playtime
-- boost (Stevin, October 20: "Everything"). One-pull Gold rolls are not counted.
function PlaytimeService.Boosts(session)
	local eggValue = UpgradeCatalog.EggValueMultiplier(session.incomeLevel) / UpgradeCatalog.EggValueMultiplier(0)
		* (1 + (session.researchEffects.eggValue or 0))
	local coins = eggValue * session:EarnedAmount(1, "eggs") * (1 + (session.territoryBonus or 0))
	local luck = Rules.LuckWindow(session.luck, session:PaidLuckMultiplier(), session:RollLuckBonus()).multiplier
	local now = serverNow()
	local running: {[string]: Boost} = {}
	local boosts = session.playtimeBoosts
	for _, kind in PlaytimeRewards.BoostKinds do
		local boost: Boost? = if type(boosts) == "table" then boosts[kind] else nil
		if boost and boost.endsAt > now then running[kind] = {bonus = boost.bonus, endsAt = boost.endsAt} end
	end
	return {coins = coins, luck = luck, running = running}
end

return PlaytimeService
