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
-- October 23 empty start: Day 1 lands right after a six-card tutorial, before Rebirth 0
-- (350 Coins). The reference pays +90 on Day 1 and grows fast; at one chicken's 4 Coins/s
-- these minutes pay about 120 / 240 / roll / 480 / 1,200 / rolls / 3,600 (was 5-60 min,
-- so Day 1 alone bought Rebirth 0).
DailyService.Rewards = table.freeze({
	table.freeze({minutes = 0.5, rolls = 0}),
	table.freeze({minutes = 1, rolls = 0}),
	table.freeze({minutes = 0, rolls = 1}),
	table.freeze({minutes = 2, rolls = 0}),
	table.freeze({minutes = 5, rolls = 0}),
	table.freeze({minutes = 0, rolls = 2}),
	table.freeze({minutes = 15, rolls = 3}),
})
-- Coins/second floor of DailyService.Income, which Playtime Coins tiles and Mission
-- rewards read. Daily rewards no longer use it (October 23, MinCoins below).
DailyService.MinIncome = 10
-- October 23 empty start: a daily Coins day pays its minutes of the real steady income,
-- at least this many Coins (was the MinIncome floor: Day 1 paid at least 3,000 Coins,
-- far more than a one-chicken flock earns).
DailyService.MinCoins = 60
DailyService.DaySeconds = 86400

-- Coins per second the HUD shows for eggs (2x Coins and the Rebirth multiplier
-- included), with no floor; junk reads as 0. October 20 (owner): steady, so a live
-- Gold Rush or Friend Boost never changes a daily reward.
function DailyService.SteadyIncome(session): number
	local income = session:EarnedAmount(session:Income() * session:EggProductionMultiplier(), "eggs", true)
	if type(income) ~= "number" or income ~= income or income < 0 or income == math.huge then return 0 end
	return income
end

-- SteadyIncome floored at MinIncome (Playtime Coins tiles, Mission rewards).
function DailyService.Income(session): number
	return math.max(DailyService.SteadyIncome(session), DailyService.MinIncome)
end

-- Whole Coins for a daily Coins day: `minutes` of the steady income, at least MinCoins,
-- clamped to the coin cap's headroom.
function DailyService.CashFor(session, minutes: number): number
	if minutes <= 0 then return 0 end
	local headroom = math.max(0, Currency.MaxCoins - session.coins)
	return math.floor(math.min(math.max(DailyService.SteadyIncome(session) * minutes * 60, DailyService.MinCoins), headroom))
end

-- October 13 owner decision: the streak starts once the main tutorial is done
-- (the guide completes on the first camp win; wonCamp covers pre-guide saves).
-- Until then no day is claimed, so Day 1 is granted the day the guide finishes.
-- October 21 (Stevin, like the reference): Day 1 pops right after the short core
-- (tutorial.coreDone), before the tips.
function DailyService.TutorialDone(session): boolean
	local tutorial = session.tutorial
	return type(tutorial) == "table"
		and (tutorial.guideCompleted == true or tutorial.wonCamp == true or tutorial.coreDone == true)
end

-- Returns the grant table when a reward was granted, otherwise nil.
function DailyService.Check(session, now: number, server)
	-- Same guard as other transactions: never write a profile that isn't ready or is leaving.
	if not session or not session.loaded or session.closing or session.saveLost then return nil end
	if not DailyService.TutorialDone(session) then return nil end
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
