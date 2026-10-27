--!strict
-- Client presentation budget only. DuckAnimator supplies the existing frame clock;
-- the mask controller separately limits the number of selected chickens to one.
-- October 27 (WS6): Automatic never rises above the PerfTier texture ceiling
-- (low static, mid animated, high masked); explicit graphics levels are unchanged.
local PerfTier = require(script.Parent.PerfTier)
local Quality = {}
Quality.__index = Quality

export type Tier = "static" | "animated" | "masked"
export type State = {
	tier: number,
	ceiling: number,
	automatic: boolean,
	average: number?,
	badSeconds: number,
	goodSeconds: number,
}

local TIERS: {Tier} = {"static", "animated", "masked"}
-- Initial conservative tuning, not a measured guarantee for a device class.
local AVERAGE_SECONDS = 0.75
local DOWNGRADE_SECONDS = 3
local BAD_FRAME = {[2] = 0.033, [3] = 0.024}
-- Leave room for ordinary 60 Hz pacing jitter during the recovery window.
-- A 17 ms cutoff repeatedly reset recovery even on a steady 60 FPS client.
local GOOD_FRAME = {[1] = 0.018, [2] = 0.018}
local PROMOTE_SECONDS = {[1] = 12, [2] = 30}

local function manualTier(savedLevel: number): number?
	if savedLevel ~= savedLevel or savedLevel % 1 ~= 0 or savedLevel < 1 or savedLevel > 10 then return nil end
	return if savedLevel <= 4 then 1 elseif savedLevel <= 7 then 2 else 3
end

function Quality.TierForSavedLevel(savedLevel: number): Tier
	return TIERS[manualTier(savedLevel) or 1]
end

-- Zero is Roblox's Automatic setting. It starts static and earns higher tiers
-- from sustained headroom; no protected engine quality property is queried.
function Quality.NewState(savedLevel: number): State
	local manual = manualTier(savedLevel)
	return {tier = manual or 1, ceiling = manual or 3, automatic = manual == nil,
		average = nil, badSeconds = 0, goodSeconds = 0}
end

function Quality.Advance(state: State, dt: number, limit: number?): Tier
	-- Explicit graphics settings are a choice, not a fluctuating FPS budget.
	-- Studio/background throttling previously kept replacing the material even
	-- at level 10. Only Automatic samples performance to choose its tier.
	if not state.automatic then return TIERS[state.tier] end
	-- October 27 (WS6): the PerfTier ceiling caps Automatic without counting as a
	-- failed tier, so the texture climbs again when the device tier does.
	local ceiling = math.min(state.ceiling, limit or 3)
	if state.tier > ceiling then
		state.tier = ceiling
		state.badSeconds, state.goodSeconds = 0, 0
	end
	if dt ~= dt or dt <= 0 then return TIERS[state.tier] end
	if dt > 1 then
		-- A suspended/backgrounded app supplies no useful rendering observation.
		state.average, state.badSeconds, state.goodSeconds = nil, 0, 0
		return TIERS[state.tier]
	end
	local elapsed = math.min(dt, 0.25)
	local sample = math.min(dt, 0.25)
	local previous = state.average or sample
	local average = previous + (sample - previous) * (1 - math.exp(-elapsed / AVERAGE_SECONDS))
	state.average = average
	if state.tier > 1 and average > BAD_FRAME[state.tier] then
		state.badSeconds += elapsed
		state.goodSeconds = 0
		if state.badSeconds >= DOWNGRADE_SECONDS then
			state.tier -= 1
			-- Do not retry a tier that already exceeded this session's budget.
			-- Otherwise removing its cost promotes it again in an endless loop.
			state.ceiling = state.tier
			state.badSeconds = 0
		end
	elseif state.tier < ceiling and average <= GOOD_FRAME[state.tier] then
		state.goodSeconds += elapsed
		state.badSeconds = 0
		if state.goodSeconds >= PROMOTE_SECONDS[state.tier] then
			state.tier += 1
			state.goodSeconds = 0
		end
	else
		state.badSeconds, state.goodSeconds = 0, 0
	end
	return TIERS[state.tier]
end

local function savedLevel(settings: any): number
	local ok, value = pcall(function()
		local quality = settings.SavedQualityLevel
		return if type(quality) == "number" then quality else quality.Value
	end)
	return if ok and type(value) == "number" then value else 0
end

function Quality.new(settings: any?, inputService: any?)
	if not settings then
		local ok, value = pcall(function() return UserSettings():GetService("UserGameSettings") end)
		settings = if ok then value else nil
	end
	if not inputService then
		local ok, value = pcall(function() return game:GetService("UserInputService") end)
		inputService = if ok then value else nil
	end
	local self = setmetatable({state = Quality.NewState(savedLevel(settings)), connection = nil,
		focusConnections = {}, focused = true, destroyed = false}, Quality)
	if settings then
		local ok, connection = pcall(function()
			return settings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
				if not self.destroyed then self.state = Quality.NewState(savedLevel(settings)) end
			end)
		end)
		if ok then self.connection = connection end
	end
	if inputService then
		local function connectFocus(event: string, focused: boolean)
			local ok, connection = pcall(function()
				return inputService[event]:Connect(function()
					if self.destroyed then return end
					self.focused = focused
					-- Pause Automatic sampling without swapping the visible material
					-- or rebuilding its resources when the window regains focus.
					self.state.average, self.state.badSeconds, self.state.goodSeconds = nil, 0, 0
				end)
			end)
			if ok then table.insert(self.focusConnections, connection) end
		end
		connectFocus("WindowFocused", true)
		connectFocus("WindowFocusReleased", false)
	end
	return self
end

function Quality.Step(self: any, dt: number): Tier
	if not self.destroyed and self.focused then
		Quality.Advance(self.state, dt, PerfTier.TextureCeilings[PerfTier.Budget().textureCeiling])
	end
	return self:GetTier()
end

function Quality.GetTier(self: any): Tier
	return TIERS[self.state.tier]
end

-- How far chicken particle effects draw. Low graphics keep the original 110 studs;
-- higher settings (or Automatic once it has earned the tier) see them from further away.
Quality.CullDistances = {static = 110, animated = 220, masked = 400}

function Quality.CullDistance(self: any): number
	return Quality.CullDistances[self:GetTier()] or 110
end

function Quality.Destroy(self: any)
	if self.destroyed then return end
	self.destroyed = true
	if self.connection then self.connection:Disconnect(); self.connection = nil end
	for _, connection in self.focusConnections do connection:Disconnect() end
	table.clear(self.focusConnections)
end

return Quality
