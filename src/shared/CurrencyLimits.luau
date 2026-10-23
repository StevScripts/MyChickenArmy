--!strict
-- Exact whole-coin arithmetic with the existing numeric save format.
-- This is a representation boundary, not a designed economy/upgrade ceiling.
-- October 20 owner decision: the earned currency is shown as gold Coins (it was
-- "Cash" with a "$" prefix). Saved `coins` values and every amount stay 1:1.
-- Icon: the gold chicken-crest coin (assets/gold-coins-20261020/upload-receipts.json).
local Currency = {MaxCoins = 2^53 - 1, Name = "Coins", Icon = "rbxassetid://116489091471628"}

-- "1,200" with thousands separators; whole coins only.
function Currency.Grouped(value: number): string
	local whole = math.floor(tonumber(value) or 0)
	local digits = string.format("%.0f", math.abs(whole))
	local grouped = (digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
	return (if whole < 0 then "-" else "") .. grouped
end

-- Player-facing amount for text without room for the coin image: "1,200 Coins", "1 Coin".
function Currency.Text(value: number): string
	local text = Currency.Grouped(value)
	return text .. (if text == "1" then " Coin" else " Coins")
end

-- Per-second rates in whole Coins: "1 Coin", "13 Coins", "1,234 Coins". October 23
-- (Stevin: "never give a decimal number"): rounded, and any positive rate shows at least 1.
function Currency.Rate(value: number): string
	local number = tonumber(value) or 0
	if number ~= number then number = 0 end
	local whole = math.floor(number + 0.5)
	if number > 0 and whole < 1 then whole = 1 end
	return Currency.Text(whole)
end

return table.freeze(Currency)
