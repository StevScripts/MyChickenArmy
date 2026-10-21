--!strict
-- October 20 Playtime Rewards (S16, docs/team/PLAYTIME_REWARDS.md). Twelve tiles that
-- unlock with minutes played in this server visit, copied 1:1 from Stevin's Drop a
-- Fruit reference: the same unlock times (1-60 min), Coins in the reference's
-- 1 : 1.5 : 2.5 : 5 : 6 : 7.5 : 12.5 : 17.5 ratios (minutes of steady egg income), two
-- Luck boosts, one Coins boost and Free Rolls on the last tile. Stevin, October 20:
-- the clock and the claims reset every join; nothing is saved.
-- Server: PlaytimeService pays the tiles and owns the timed boosts. Client:
-- PlaytimePanel draws them from state.playtime; BoostReadout shows state.boosts.
local PlaytimeRewards = {}

PlaytimeRewards.Enabled = true

export type Tile = {
	at: number, -- minutes played before it can be claimed
	kind: string, -- "Coins" | "Boost" | "Rolls"
	coinMinutes: number?, -- Coins: minutes of steady egg income (DailyService.CashFor)
	boost: string?, -- Boost: "Luck" | "Coins"
	bonus: number?, -- Boost: +1 = +100%
	minutes: number?, -- Boost: how long it runs
	rolls: number?, -- Rolls: free roll credits (a chicken each, like Hill rolls)
	color: string, -- tile colour in the panel (the reference's blue/green/pink/gold)
}

-- Each entry is checked against Tile (optional fields may be left out).
local function tile(entry: Tile): Tile
	return table.freeze(entry)
end

PlaytimeRewards.Tiles = table.freeze({
	tile({at = 1, kind = "Coins", coinMinutes = 1, color = "Blue"}),
	tile({at = 3, kind = "Coins", coinMinutes = 1.5, color = "Blue"}),
	tile({at = 5, kind = "Coins", coinMinutes = 2.5, color = "Blue"}),
	tile({at = 8, kind = "Boost", boost = "Luck", bonus = 1, minutes = 5, color = "Pink"}),
	tile({at = 12, kind = "Coins", coinMinutes = 5, color = "Blue"}),
	tile({at = 15, kind = "Coins", coinMinutes = 6, color = "Green"}),
	tile({at = 20, kind = "Coins", coinMinutes = 7.5, color = "Blue"}),
	tile({at = 25, kind = "Boost", boost = "Coins", bonus = 0.5, minutes = 10, color = "Gold"}),
	tile({at = 30, kind = "Coins", coinMinutes = 12.5, color = "Blue"}),
	tile({at = 40, kind = "Boost", boost = "Luck", bonus = 1, minutes = 10, color = "Pink"}),
	tile({at = 50, kind = "Coins", coinMinutes = 17.5, color = "Green"}),
	tile({at = 60, kind = "Rolls", rolls = 3, color = "Gold"}),
}) :: {Tile}

-- Timed boosts a tile can give, in readout order (coin first, then clover).
PlaytimeRewards.BoostKinds = table.freeze({"Coins", "Luck"})

-- "+100%" for a +1 bonus, "+50%" for +0.5.
function PlaytimeRewards.Percent(bonus: number): string
	return "+" .. math.floor(bonus * 100 + 0.5) .. "%"
end

-- The reference's tile line for a boost: "+100% 5m".
function PlaytimeRewards.BoostText(tile: Tile): string
	return PlaytimeRewards.Percent(tile.bonus or 0) .. " " .. (tile.minutes or 0) .. "m"
end

-- What a claimed boost says: "+100% Luck for 5 minutes!".
function PlaytimeRewards.BoostMessage(tile: Tile): string
	local minutes = tile.minutes or 0
	return PlaytimeRewards.Percent(tile.bonus or 0) .. " " .. (tile.boost or "") .. " for " .. minutes
		.. (if minutes == 1 then " minute!" else " minutes!")
end

-- "3 Free Rolls" / "1 Free Roll".
function PlaytimeRewards.RollsText(rolls: number): string
	return rolls .. " Free " .. (if rolls == 1 then "Roll" else "Rolls")
end

-- The reference's timers: "00:04", "57:04"; past an hour "1:02:04".
function PlaytimeRewards.Clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
	end
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

-- The readout's "x9.2": one decimal below 100 (trailing ".0" dropped), whole numbers
-- to 1,000, then K/M/B/T.
local SUFFIXES = {"", "K", "M", "B", "T"}
function PlaytimeRewards.Times(value: number): string
	if type(value) ~= "number" or value ~= value or value <= 0 or value == math.huge then return "x1" end
	if value < 100 then
		local text = string.format("%.1f", math.floor(value * 10 + 0.5) / 10)
		return "x" .. (text:gsub("%.0$", ""))
	end
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	if index == 1 then return "x" .. math.floor(value + 0.5) end
	local decimals = if value < 10 then 2 elseif value < 100 then 1 else 0
	local text = string.format("%." .. decimals .. "f", value)
	if decimals > 0 then text = text:gsub("0+$", ""):gsub("%.$", "") end
	return "x" .. text .. SUFFIXES[index]
end

return PlaytimeRewards
