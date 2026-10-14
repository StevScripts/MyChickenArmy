--!strict
-- 7-day login streak. Contract: docs/team/launch/13_D1_DAILY_STREAK.md.
-- GameServer calls Check after a profile loads and once a minute for every
-- loaded session. The reward is granted here, on the server, once per UTC day;
-- the client popup only displays session.dailyGranted.
local Currency = require(game:GetService("ReplicatedStorage").PetRoll.Shared.CurrencyLimits)
local DailyService = {}

-- Tuning. `minutes` of income per second (see Income below); `rolls` become
-- hillRollCredits, which HillService turns into recruits when the flock has room.
-- Never add Galaxy Crate credits here: they are a paid item with disclosed odds.
-- DailyRewardController mirrors these labels for the popup tiles.
DailyService.Rewards = table.freeze({
	table.freeze({minutes = 5, rolls = 0}),
	table.freeze({minutes = 10, rolls = 0}),
	table.freeze({minutes = 0, rolls = 1}),
	table.freeze({minutes = 20, rolls = 0}),
	table.freeze({minutes = 30, rolls = 0}),
	table.freeze({minutes = 0, rolls = 2}),
	table.freeze({minutes = 60, rolls = 3}),
})
DailyService.MinIncome = 10 -- $/second, so brand-new flocks still get something useful.
DailyService.DaySeconds = 86400

-- Cash per second the HUD shows for eggs (2x Cash and the re-enlist multiplier
-- included), floored at MinIncome.
function DailyService.Income(session): number
	local income = session:EarnedAmount(session:Income() * session:EggProductionMultiplier(), "eggs")
	if type(income) ~= "number" or income ~= income or income < DailyService.MinIncome then
		return DailyService.MinIncome
	end
	return income
end

-- Whole coins for `minutes` of income, clamped to the coin cap's headroom.
function DailyService.CashFor(session, minutes: number): number
	if minutes <= 0 then return 0 end
	local headroom = math.max(0, Currency.MaxCoins - session.coins)
	return math.floor(math.min(DailyService.Income(session) * minutes * 60, headroom))
end

-- Returns the grant table when a reward was granted, otherwise nil.
function DailyService.Check(session, now: number, server)
	-- Same guard as other transactions: never write a profile that isn't ready or is leaving.
	if not session or not session.loaded or session.closing or session.saveLost then return nil end
	local daily = session.daily
	if type(daily) ~= "table" or type(now) ~= "number" or now ~= now then return nil end
	local today = math.floor(now / DailyService.DaySeconds)
	-- A later lastDay (clock skew between servers) counts as already claimed.
	if daily.lastDay >= today then return nil end
	local previous = daily.streak
	local reset = false
	if daily.lastDay == today - 1 then
		daily.streak = previous + 1
	else
		daily.streak = 1
		reset = previous >= 2
	end
	daily.lastDay = today
	daily.best = math.max(daily.best, daily.streak)
	local streak = daily.streak
	local slot = ((streak - 1) % #DailyService.Rewards) + 1
	local reward = DailyService.Rewards[slot]
	local cash = DailyService.CashFor(session, reward.minutes)
	if cash > 0 then cash = session:Credit(cash, "daily") end
	if reward.rolls > 0 then session.hillRollCredits = (session.hillRollCredits or 0) + reward.rolls end
	session.dailyGranted = {slot = slot, streak = streak, cash = cash, rolls = reward.rolls, day = today}
	session:Touch()
	if server and server.world then server.world:UpdateSession(session) end
	if server and server.analytics then
		if reset then server.analytics:LaunchCount(session, "daily.reset") end
		server.analytics:LaunchCount(session, "daily.claim." .. slot)
		server.analytics:LaunchHist(session, "daily.streak", streak)
	end
	return session.dailyGranted
end

return DailyService
