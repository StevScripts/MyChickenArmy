--!strict
-- October 27 (WS6, docs/team/MOBILE_PERFORMANCE_20261027.md): one client performance
-- governor. It picks a quality tier ("low" | "mid" | "high") from the device class and
-- the measured frame rate, and every presentation system reads its budget here
-- instead of keeping a private one (owner rule: the shared vocabulary). Budgets only
-- change how many and how often (animated chickens, particles, eggs, bursts, coins),
-- never a whole effect class, a position or a size: one layout for every device.
-- Reduced motion keeps priority over every tier.
--
-- Interface (RETENTION_PLAN_20261027.md §7): PerfTier.Start(), PerfTier.Get(),
-- PerfTier.Critical(), PerfTier.Budget(), PerfTier.Changed (Connect(fn(tier))),
-- PerfTier.Stats(), PerfTier.Enabled().
--
-- Config.Performance.TiersEnabled=false pins "high" (today's budgets). Tuning values
-- below are starting points from the plan, not device measurements; the lead moves
-- them into Config.Performance once Studio captures confirm them.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("PetRoll"):WaitForChild("Shared"):WaitForChild("Config"))

local PerfTier = {}

export type Tier = "low" | "mid" | "high"
export type Budget = {
	animFullRadius: number, animMidRadius: number, animMidHz: number,
	animFarRadius: number, animFarHz: number, animFullMax: number, offscreenHz: number,
	fxMaxChickens: number, fxCull: number, fxRateScale: number,
	eggBobRadius: number, eggHz: number, podiumOtherPlotHz: number,
	worldFeelLimit: number, coinsMaxActive: number,
	menuBlur: boolean, bloom: boolean, sunRays: boolean, beacon: boolean,
	textureCeiling: "static" | "animated" | "masked",
	hillVfxRadius: number?,
}
export type State = {
	tier: number, ceiling: number, average: number?,
	badSeconds: number, goodSeconds: number,
	critical: boolean, criticalBad: number, criticalGood: number,
	demotions: number, hitches: number,
}

local TIERS: {Tier} = {"low", "mid", "high"}
local INDEX: {[string]: number} = {low = 1, mid = 2, high = 3}

-- Tuning (plan §4.1). Frame times in seconds.
local AVERAGE_SECONDS = 1.0     -- EMA time constant
local DEMOTE_FRAME = 0.040      -- under 25 FPS ...
local DEMOTE_SECONDS = 4        -- ... for 4 s drops one tier; the ceiling follows
local PROMOTE_FRAME = 0.020     -- 50+ FPS ...
local PROMOTE_SECONDS = 20      -- ... for 20 s climbs one tier, never past the ceiling
local CRITICAL_FRAME = 0.045    -- low and under 22 FPS ...
local CRITICAL_SECONDS = 10     -- ... for 10 s: critical (shadows off, half the particles)
local RECOVER_FRAME = 0.028     -- critical clears after 30 s at 36+ FPS
local RECOVER_SECONDS = 30
local HITCH_FRAME = 0.1         -- a frame over 100 ms counts as a hitch (telemetry)
local PHONE_SHORT_SIDE = 700    -- AnalyticsClient's Mobile/Tablet split

-- Budget table (plan §4.1). High keeps today's values wherever today had one
-- (WorldFeel 28, coins 28, particle cull up to the quality setting's 400 studs).
local BUDGETS: {[string]: Budget} = {
	low = {animFullRadius = 30, animMidRadius = 70, animMidHz = 15, animFarRadius = 120, animFarHz = 5,
		animFullMax = 10, offscreenHz = 2, fxMaxChickens = 6, fxCull = 70, fxRateScale = 0.5,
		eggBobRadius = 40, eggHz = 20, podiumOtherPlotHz = 4, worldFeelLimit = 8, coinsMaxActive = 8,
		menuBlur = false, bloom = false, sunRays = false, beacon = true, textureCeiling = "static",
		hillVfxRadius = 150},
	mid = {animFullRadius = 45, animMidRadius = 100, animMidHz = 20, animFarRadius = 150, animFarHz = 8,
		animFullMax = 20, offscreenHz = 4, fxMaxChickens = 12, fxCull = 110, fxRateScale = 0.75,
		eggBobRadius = 80, eggHz = 30, podiumOtherPlotHz = 10, worldFeelLimit = 14, coinsMaxActive = 14,
		menuBlur = true, bloom = true, sunRays = false, beacon = true, textureCeiling = "animated",
		hillVfxRadius = nil},
	high = {animFullRadius = 60, animMidRadius = 120, animMidHz = 30, animFarRadius = 170, animFarHz = 10,
		animFullMax = 999, offscreenHz = 6, fxMaxChickens = 24, fxCull = 400, fxRateScale = 1,
		eggBobRadius = 120, eggHz = 60, podiumOtherPlotHz = 30, worldFeelLimit = 28, coinsMaxActive = 28,
		menuBlur = true, bloom = true, sunRays = true, beacon = true, textureCeiling = "masked",
		hillVfxRadius = nil},
}
-- Critical (low and still under 22 FPS): half the particle chickens, no beacon, and
-- (PerfTier's lighting) GlobalShadows off locally until it clears.
local CRITICAL_BUDGET: Budget = table.clone(BUDGETS.low)
CRITICAL_BUDGET.fxMaxChickens = math.max(1, math.floor(BUDGETS.low.fxMaxChickens / 2))
CRITICAL_BUDGET.beacon = false

PerfTier.Budgets = BUDGETS
PerfTier.TextureCeilings = {static = 1, animated = 2, masked = 3}

local function performance(): any
	return (Config :: any).Performance or {}
end

function PerfTier.Enabled(): boolean
	return performance().TiersEnabled ~= false
end

-- Pure state machine (headless: tools/sim/perf_tier_probe.luau) -------------------

function PerfTier.NewState(tier: number, ceiling: number): State
	return {tier = math.clamp(tier, 1, 3), ceiling = math.clamp(ceiling, 1, 3), average = nil,
		badSeconds = 0, goodSeconds = 0, critical = false, criticalBad = 0, criticalGood = 0,
		demotions = 0, hitches = 0}
end

-- One frame of `dt` seconds. Returns true when the tier or critical flag changed.
-- A suspended app (dt over 1 s) supplies no observation and resets the timers.
function PerfTier.Advance(state: State, dt: number): boolean
	if dt ~= dt or dt <= 0 then return false end
	if dt > 1 then
		state.average, state.badSeconds, state.goodSeconds = nil, 0, 0
		state.criticalBad, state.criticalGood = 0, 0
		return false
	end
	if dt > HITCH_FRAME then state.hitches += 1 end
	local sample = math.min(dt, 0.25)
	local previous = state.average or sample
	local average = previous + (sample - previous) * (1 - math.exp(-sample / AVERAGE_SECONDS))
	state.average = average
	local changed = false
	if state.tier > 1 and average > DEMOTE_FRAME then
		state.badSeconds += sample
		state.goodSeconds = 0
		if state.badSeconds >= DEMOTE_SECONDS then
			state.tier -= 1
			-- Never retry a tier this session already failed (ChickenEffectQuality's rule).
			state.ceiling = state.tier
			state.badSeconds = 0
			state.demotions += 1
			changed = true
		end
	elseif state.tier < state.ceiling and average <= PROMOTE_FRAME then
		state.goodSeconds += sample
		state.badSeconds = 0
		if state.goodSeconds >= PROMOTE_SECONDS then
			state.tier += 1
			state.goodSeconds = 0
			changed = true
		end
	else
		state.badSeconds, state.goodSeconds = 0, 0
	end
	if state.tier == 1 and not state.critical then
		if average > CRITICAL_FRAME then
			state.criticalBad += sample
			if state.criticalBad >= CRITICAL_SECONDS then
				state.critical, state.criticalBad, state.criticalGood = true, 0, 0
				changed = true
			end
		else state.criticalBad = 0 end
	elseif state.critical then
		if state.tier > 1 or average <= RECOVER_FRAME then
			state.criticalGood += sample
			if state.tier > 1 or state.criticalGood >= RECOVER_SECONDS then
				state.critical, state.criticalBad, state.criticalGood = false, 0, 0
				changed = true
			end
		else state.criticalGood = 0 end
	end
	return changed
end

-- Starting tier and ceiling (plan §4.1). A manual graphics level fixes the ceiling
-- (1-4 low, 5-7 mid, 8-10 high); Automatic starts phones low and tablets mid.
function PerfTier.Initial(savedLevel: number, touchOnly: boolean, shortSide: number?): (number, number)
	if savedLevel == savedLevel and savedLevel % 1 == 0 and savedLevel >= 1 and savedLevel <= 10 then
		local manual = if savedLevel <= 4 then 1 elseif savedLevel <= 7 then 2 else 3
		return manual, manual
	end
	if touchOnly then
		-- Unknown viewport (still 1x1 at boot): treat as a phone; it promotes in 20 s.
		return (if shortSide and shortSide >= PHONE_SHORT_SIDE then 2 else 1), 3
	end
	return 3, 3
end

-- Runtime ------------------------------------------------------------------------

local state: State = PerfTier.NewState(3, 3)
local started = false
local focused = true
local focusLost = false
local override: Tier? = nil
local listeners: {(Tier) -> ()} = {}
local lighting: {[Instance]: {[string]: any}} = {}
local authoredShadows: boolean? = nil

local function current(): number
	if override then return INDEX[override] end
	if not PerfTier.Enabled() then return 3 end
	return state.tier
end

function PerfTier.Get(): Tier
	return TIERS[current()]
end

function PerfTier.Critical(): boolean
	if override or not PerfTier.Enabled() then return false end
	return state.critical and state.tier == 1
end

function PerfTier.Budget(): Budget
	if PerfTier.Critical() then return CRITICAL_BUDGET end
	return BUDGETS[TIERS[current()]]
end

-- Telemetry for AnalyticsClient: fps from the EMA, hitches and demotions so far.
function PerfTier.Stats(): {fps: number?, hitches: number, focusLost: boolean, tier: Tier, demotions: number, critical: boolean}
	local average = state.average
	return {fps = if average and average > 0 then 1 / average else nil, hitches = state.hitches,
		focusLost = focusLost, tier = PerfTier.Get(), demotions = state.demotions, critical = PerfTier.Critical()}
end

-- A small signal (works without BindableEvent, headless too). Listeners run in
-- their own thread so one failing system never blocks the others.
PerfTier.Changed = {
	Connect = function(_self: any, callback: (Tier) -> ())
		table.insert(listeners, callback)
		return {Disconnect = function()
			local index = table.find(listeners, callback)
			if index then table.remove(listeners, index) end
		end}
	end,
}

local function fire()
	local tier = PerfTier.Get()
	for _, callback in table.clone(listeners) do task.spawn(callback :: any, tier) end
end

-- Low-tier render budget (plan §4.10, kept here so AppController stays a one-hunk
-- wiring file): Bloom and SunRays follow the budget, GlobalShadows goes off only while
-- critical. Authored values are remembered once and restored on promotion. Only the
-- local copy of Lighting changes; the server's values are untouched.
local function applyLighting()
	local Lighting = game:GetService("Lighting")
	local budget = PerfTier.Budget()
	for _, item in Lighting:GetChildren() do
		local key = if item:IsA("BloomEffect") then "bloom" elseif item:IsA("SunRaysEffect") then "sunRays" else nil
		if not key then continue end
		local saved = lighting[item]
		if not saved then
			saved = {enabled = (item :: any).Enabled}
			lighting[item] = saved
		end
		local want = saved.enabled == true and (budget :: any)[key] ~= false
		if (item :: any).Enabled ~= want then (item :: any).Enabled = want end
	end
	if authoredShadows == nil then authoredShadows = Lighting.GlobalShadows end
	local shadows = authoredShadows == true and not PerfTier.Critical()
	if Lighting.GlobalShadows ~= shadows then Lighting.GlobalShadows = shadows end
end

local function changed()
	pcall(applyLighting)
	fire()
end

local function savedQuality(): number
	local ok, value = pcall(function()
		local quality = (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel
		return if type(quality) == "number" then quality else quality.Value
	end)
	return if ok and type(value) == "number" then value else 0
end

local function touchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function shortSide(): number?
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else nil
	return if size and math.min(size.X, size.Y) > 2 then math.min(size.X, size.Y) else nil
end

-- Idempotent; the bootstrap calls it first. Heartbeat samples, focus listeners and
-- the Studio-only override attribute ReplicatedStorage.PetRoll.PerfTierOverride.
function PerfTier.Start()
	if started then return end
	started = true
	local level = savedQuality()
	local side = shortSide()
	local tier, ceiling = PerfTier.Initial(level, touchOnly(), side)
	state = PerfTier.NewState(tier, ceiling)
	-- A phone-or-tablet guess made before the viewport existed is settled once it does.
	local classified = side ~= nil or not touchOnly() or (level >= 1 and level <= 10)
	local petRoll = ReplicatedStorage:FindFirstChild("PetRoll")
	if RunService:IsStudio() and petRoll then
		local function readOverride()
			local value = petRoll:GetAttribute("PerfTierOverride")
			local before = PerfTier.Get()
			override = if type(value) == "string" and INDEX[value] then (value :: any) else nil
			if PerfTier.Get() ~= before then changed() end
		end
		readOverride()
		petRoll:GetAttributeChangedSignal("PerfTierOverride"):Connect(readOverride)
	end
	pcall(function()
		UserInputService.WindowFocusReleased:Connect(function()
			focused, focusLost = false, true
			state.average, state.badSeconds, state.goodSeconds = nil, 0, 0
		end)
		UserInputService.WindowFocused:Connect(function()
			focused = true
			state.average, state.badSeconds, state.goodSeconds = nil, 0, 0
		end)
	end)
	pcall(function()
		game:GetService("Lighting").ChildAdded:Connect(function(item)
			if item:IsA("BloomEffect") or item:IsA("SunRaysEffect") then pcall(applyLighting) end
		end)
	end)
	RunService.Heartbeat:Connect(function(dt)
		if not classified then
			local now = shortSide()
			if now then
				classified = true
				if state.demotions == 0 and now >= PHONE_SHORT_SIDE and state.tier == 1 then
					state.tier = 2
					changed()
				end
			end
		end
		if not focused then return end
		if PerfTier.Advance(state, dt) and PerfTier.Enabled() and not override then changed() end
	end)
	if current() ~= 3 then pcall(applyLighting) end
	local player = Players.LocalPlayer
	if player and RunService:IsStudio() then
		print(("[PerfTier] start %s (ceiling %s, quality %d)"):format(PerfTier.Get(), TIERS[state.ceiling], level))
	end
end

return PerfTier
