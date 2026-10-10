--!strict
-- BattleService supplies only eligible simulation time; this helper owns no clock or territory.
local TerritoryIncome = {}
TerritoryIncome.__index = TerritoryIncome
type Carry = {session: any, pets: any, value: number}
type State = {rate: number, carry: {[number]: Carry}, destroyed: boolean}
type Income = typeof(setmetatable({} :: State, TerritoryIncome))

local COIN_EPSILON = 1e-7

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function TerritoryIncome.new(rate: number): Income
	assert(finite(rate) and rate >= 0, "Territory income rate must be finite and nonnegative")
	return setmetatable({rate = rate, carry = {} :: {[number]: Carry}, destroyed = false}, TerritoryIncome)
end

-- rateOverride (coins/sec) replaces the fixed rate for this slice; the Hill pays a
-- boost that depends on the holder's farm and hold time.
function TerritoryIncome.Step(self: Income, session: any, eligibleDt: number, rateOverride: number?): number
	if self.destroyed or type(session) ~= "table" then return 0 end
	local userId = session.userId
	if not finite(userId) or userId % 1 ~= 0 then return 0 end
	if session.closing or session.saveLost then
		local entry = self.carry[userId]
		if entry and entry.session == session then self:Release(userId) end
		return 0
	end
	if session.loaded ~= true or type(session.Credit) ~= "function" then return 0 end
	local rate = if rateOverride ~= nil then rateOverride else self.rate
	if not finite(eligibleDt) or eligibleDt <= 0 or not finite(rate) or rate <= 0 then return 0 end
	local earned = rate * eligibleDt
	if not finite(earned) then return 0 end

	local entry = self.carry[userId]
	-- Rejoin and an isolated test reset must not inherit an earlier session's fraction.
	if not entry or entry.session ~= session or entry.pets ~= session.pets then
		entry = {session = session, pets = session.pets, value = 0}
		self.carry[userId] = entry
	end
	local value = entry.value + earned
	if not finite(value) then return 0 end
	local whole = math.floor(value + COIN_EPSILON)
	local credit = session.Credit :: (any, number, string) -> ()
	if whole > 0 then credit(session, whole, "territory") end
	-- Tolerance absorbs floating point drift at a whole-coin boundary, not per-frame rounding.
	entry.value = math.max(0, value - whole)
	return whole
end

function TerritoryIncome.Release(self: Income, userId: number)
	self.carry[userId] = nil
end

function TerritoryIncome.Destroy(self: Income)
	self.destroyed = true
	table.clear(self.carry)
end

return TerritoryIncome
