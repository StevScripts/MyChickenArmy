-- October 27 (WS6, docs/team/MOBILE_PERFORMANCE_20261027.md): headless checks of the
-- client PerfTier state machine (src/client is not mounted by the harness, so the module
-- is loaded from its path). Prints "SUMMARY PerfTierProbe N passed M failed".
--   cd tools/sim && ./lune run harness.luau ../.. perf_tier_probe.luau
local PerfTier = Harness.require({__path = Harness.root .. "/src/client/PerfTier.luau", __name = "PerfTier"})
local passed, failed = 0, 0
local function check(name, ok, detail)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function run(state, frameSeconds, seconds)
	local changed = false
	for _ = 1, math.floor(seconds / frameSeconds + 0.5) do
		if PerfTier.Advance(state, frameSeconds) then changed = true end
	end
	return changed
end

-- Starting tiers.
local t, c = PerfTier.Initial(0, true, 375)
check("phone starts low, ceiling high", t == 1 and c == 3, t .. "/" .. c)
t, c = PerfTier.Initial(0, true, 820)
check("tablet starts mid", t == 2 and c == 3, t .. "/" .. c)
t, c = PerfTier.Initial(0, true, nil)
check("unknown touch viewport starts low", t == 1, t)
t, c = PerfTier.Initial(0, false, 1080)
check("desktop starts high", t == 3 and c == 3, t .. "/" .. c)
t, c = PerfTier.Initial(3, false, 1080)
check("manual level 3 pins low", t == 1 and c == 1, t .. "/" .. c)
t, c = PerfTier.Initial(6, true, 375)
check("manual level 6 pins mid", t == 2 and c == 2, t .. "/" .. c)
t, c = PerfTier.Initial(10, true, 375)
check("manual level 10 starts high", t == 3 and c == 3, t .. "/" .. c)

-- Demotion: under 25 FPS for 4 s drops one tier and lowers the ceiling.
local s = PerfTier.NewState(3, 3)
run(s, 1 / 20, 3)
check("3 s at 20 FPS keeps high", s.tier == 3, s.tier)
run(s, 1 / 20, 2.5)
check("about 4 s at 20 FPS demotes to mid", s.tier == 2 and s.ceiling == 2 and s.demotions == 1, s.tier .. "/" .. s.ceiling)
run(s, 1 / 60, 60)
check("never re-promotes past a failed tier", s.tier == 2, s.tier)

-- Promotion: 50+ FPS for 20 s climbs one tier, up to the ceiling.
s = PerfTier.NewState(1, 3)
run(s, 1 / 60, 19)
check("19 s at 60 FPS stays low", s.tier == 1, s.tier)
run(s, 1 / 60, 3)
check("about 20 s at 60 FPS promotes to mid", s.tier == 2, s.tier)
run(s, 1 / 60, 22)
check("another 20 s promotes to high", s.tier == 3, s.tier)
run(s, 1 / 40, 30)
check("40 FPS neither demotes nor promotes", s.tier == 3 and s.demotions == 0, s.tier)

-- Critical: low and under 22 FPS for 10 s; clears after 30 s at 36+ FPS.
s = PerfTier.NewState(1, 1)
run(s, 1 / 15, 9)
check("9 s at 15 FPS is not critical yet", not s.critical, s.critical)
run(s, 1 / 15, 3)
check("about 10 s at 15 FPS is critical", s.critical, s.critical)
run(s, 1 / 40, 20)
check("20 s at 40 FPS still critical", s.critical, s.critical)
run(s, 1 / 40, 14)
check("about 30 s at 40 FPS clears critical", not s.critical, s.critical)

-- A suspended app (dt over 1 s) resets the timers and counts nothing.
s = PerfTier.NewState(3, 3)
run(s, 1 / 20, 3.5)
PerfTier.Advance(s, 5)
run(s, 1 / 20, 1)
check("a suspend in the middle restarts the 4 s demotion timer", s.tier == 3, s.tier)
s = PerfTier.NewState(3, 3)
PerfTier.Advance(s, 0.2); PerfTier.Advance(s, 0.016)
check("frames over 100 ms count as hitches", s.hitches == 1, s.hitches)

-- Budgets: high keeps today's caps; low only lowers counts and rates.
local low, mid, high = PerfTier.Budgets.low, PerfTier.Budgets.mid, PerfTier.Budgets.high
check("high keeps today's WorldFeel 28 and coins 28", high.worldFeelLimit == 28 and high.coinsMaxActive == 28)
check("mid matches today's phone WorldFeel 14", mid.worldFeelLimit == 14)
for _, key in {"animFullRadius", "animFullMax", "fxMaxChickens", "fxRateScale", "eggBobRadius", "eggHz", "worldFeelLimit", "coinsMaxActive"} do
	check("budget " .. key .. " never rises as the tier falls", low[key] <= mid[key] and mid[key] <= high[key],
		low[key] .. "/" .. mid[key] .. "/" .. high[key])
	check("budget " .. key .. " stays above zero", low[key] > 0, low[key])
end
check("Config.Performance enables tiers", PerfTier.Enabled())
check("Get defaults to high before Start", PerfTier.Get() == "high", PerfTier.Get())

print(("SUMMARY PerfTierProbe %d passed %d failed"):format(passed, failed))
