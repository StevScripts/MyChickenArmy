--!strict
-- Saved quantity/value ledger. No world, GUI, clock, receipt or wallet ownership.
local Config = require(game:GetService("ReplicatedStorage").PetRoll.Shared.EggProcessorConfig)
local Processor = {}

function Processor.New()
	return {level = 0, batches = {}, readyValue = 0, progress = 0, finishCredits = 0}
end

function Processor.Copy(state)
	local copy = table.clone(state)
	copy.batches = {}
	for _, batch in state.batches do table.insert(copy.batches, table.clone(batch)) end
	return copy
end

function Processor.Totals(state)
	local count, value = 0, 0
	for _, batch in state.batches do count += batch.count; value += batch.value end
	return count, value
end

function Processor.Read(data)
	if data == nil then return Processor.New() end
	local function valid(n, max)
		return type(n) == "number" and n == n and n >= 0 and n <= max and n % 1 == 0
	end
	if type(data) ~= "table" or not valid(data.level, #Config.Prices)
		or not valid(data.readyValue, Config.MaxValue) or not valid(data.finishCredits, 1e9)
		or type(data.progress) ~= "number" or data.progress ~= data.progress or data.progress < 0 or data.progress >= 1
		or type(data.batches) ~= "table" or #data.batches > Config.MaxBatches then return nil end
	local state = Processor.New()
	state.level, state.readyValue, state.progress, state.finishCredits = data.level, data.readyValue, data.progress, data.finishCredits
	local entries, count, value = 0, 0, state.readyValue
	for key, batch in data.batches do
		if not valid(key, #data.batches) or key < 1 or type(batch) ~= "table"
			or not valid(batch.count, Config.MaxValue) or batch.count < 1 or not valid(batch.value, Config.MaxValue) then return nil end
		entries += 1; count += batch.count; value += batch.value
		if count > Config.MaxValue or value > Config.MaxValue then return nil end
		state.batches[key] = {count = batch.count, value = batch.value}
	end
	if entries ~= #data.batches then return nil end
	return state
end

function Processor.Rate(state, doubleSpawn)
	return Config.Rates[state.level + 1] * (if doubleSpawn then 2 else 1)
end

function Processor.Finish(state)
	local count, value = Processor.Totals(state)
	state.readyValue += value
	table.clear(state.batches)
	state.progress = 0
	return count
end

function Processor.Deposit(state, count, value)
	local oldCount, oldValue = Processor.Totals(state)
	if count < 1 or value < 1 or oldCount + count > Config.MaxValue
		or oldValue + state.readyValue + value > Config.MaxValue then return false end
	local last = state.batches[#state.batches]
	if #state.batches >= Config.MaxBatches then
		-- Bound profile size without dropping any remaining quantity or value.
		last.count += count; last.value += value
	else table.insert(state.batches, {count = count, value = value}) end
	if state.finishCredits > 0 then
		state.finishCredits -= 1
		Processor.Finish(state)
	end
	return true
end

function Processor.Step(state, dt, rate)
	if #state.batches == 0 then state.progress = 0; return false end
	local elapsed = state.progress + dt * rate
	local remaining = math.floor(elapsed + 1e-9)
	state.progress = math.max(0, elapsed - remaining)
	while remaining > 0 and #state.batches > 0 do
		local batch = state.batches[1]
		local take = math.min(remaining, batch.count)
		-- Split integer value conservatively. The last egg retains all rounding remainder.
		local value = if take == batch.count then batch.value else math.floor(batch.value * (take / batch.count))
		batch.count -= take; batch.value -= value
		state.readyValue += value; remaining -= take
		if batch.count == 0 then table.remove(state.batches, 1) end
	end
	if #state.batches == 0 then state.progress = 0 end
	return true
end

function Processor.GrantFinish(state)
	if #state.batches > 0 then Processor.Finish(state)
	elseif state.finishCredits < 1e9 then
		-- A delayed receipt may arrive after the queue empties. Preserve the paid benefit.
		state.finishCredits += 1
	else return false end
	return true
end

return Processor
