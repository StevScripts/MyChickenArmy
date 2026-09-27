--!strict
-- Ready-cash ledger, retaining old queue/upgrade fields for save compatibility.
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

function Processor.Finish(state)
	local count, value = Processor.Totals(state)
	state.readyValue += value
	table.clear(state.batches)
	state.progress = 0
	return count
end

function Processor.Deposit(state, count, value)
	local oldCount, oldValue = Processor.Totals(state)
	if type(count) ~= "number" or count ~= count or count % 1 ~= 0
		or type(value) ~= "number" or value ~= value or value % 1 ~= 0
		or count < 1 or value < 1 or oldCount + count > Config.MaxValue
		or oldValue + state.readyValue + value > Config.MaxValue then return false end
	-- Convert the entire batch at deposit, including any legacy queued balance.
	Processor.Finish(state)
	state.readyValue += value
	return true
end

function Processor.GrantFinish(state)
	-- Old receipts create a durable compensation credit. PlayerSession owns its
	-- exact cash settlement; retaining the counter also handles a full wallet.
	if state.finishCredits >= 1e9 then return false end
	state.finishCredits += 1
	return true
end

return Processor
