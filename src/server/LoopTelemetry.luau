--!strict
-- Optional local observations only. Never retries gameplay or sends production analytics.
local LoopTelemetry = {}
LoopTelemetry.__index = LoopTelemetry

local EVENT_LIMIT, KEY_LIMIT, FIELD_LIMIT = 256, 512, 16
type Event = {name: string, fields: {[string]: any}, at: number}
type SeenKey = {id: string, userId: number?}
type Sink = (Event) -> ()
type State = {sink: Sink?, events: {Event}, seen: {[string]: boolean}, keys: {SeenKey}, destroyed: boolean}
type Telemetry = typeof(setmetatable({} :: State, LoopTelemetry))

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

local function cleanFields(fields: any): {[string]: any}
	local clean = {}
	if type(fields) ~= "table" then return clean end
	-- userId is local lifecycle metadata. It is never an analytics custom-field category.
	if type(fields.userId) == "number" and finite(fields.userId) then clean.userId = fields.userId end
	local count = if clean.userId ~= nil then 1 else 0
	for key, value in fields do
		if count >= FIELD_LIMIT then break end
		if type(key) ~= "string" or #key > 64 or key == "userId" then continue end
		local kind = type(value)
		if kind == "string" then
			clean[key] = string.sub(value, 1, 160)
		elseif kind == "boolean" or (kind == "number" and finite(value)) then
			clean[key] = value
		else
			continue
		end
		count += 1
	end
	return clean
end

function LoopTelemetry.new(sink: Sink?): Telemetry
	return setmetatable({
		sink = sink, events = {} :: {Event}, seen = {} :: {[string]: boolean},
		keys = {} :: {SeenKey}, destroyed = false,
	}, LoopTelemetry)
end

function LoopTelemetry.Record(self: Telemetry, name: string, fields: any, key: (string | number)?): boolean
	if self.destroyed or type(name) ~= "string" or #name == 0 or #name > 64 then return false end
	local clean = cleanFields(fields)
	if key ~= nil then
		if type(key) ~= "string" and type(key) ~= "number" then return false end
		if type(key) == "number" and not finite(key) then return false end
		local text = tostring(key)
		if #text > 256 then return false end
		local id = tostring(clean.userId or "session") .. ":" .. #name .. ":" .. name .. ":" .. text
		if self.seen[id] then return false end
		self.seen[id] = true
		table.insert(self.keys, {id = id, userId = clean.userId})
		if #self.keys > KEY_LIMIT then
			local oldest = table.remove(self.keys, 1)
			if oldest then self.seen[oldest.id] = nil end
		end
	end
	local event = {name = name, fields = clean, at = os.clock()}
	table.insert(self.events, event)
	if #self.events > EVENT_LIMIT then table.remove(self.events, 1) end
	-- Reserve the key and retain the local receipt before a fallible, possibly reentrant sink.
	if type(self.sink) == "function" then
		pcall(self.sink, {name = name, fields = table.clone(clean), at = event.at})
	end
	return true
end

function LoopTelemetry.Drain(self: Telemetry): {Event}
	local events = self.events
	self.events = {}
	return events
end

function LoopTelemetry.Release(self: Telemetry, userId: number)
	for index = #self.events, 1, -1 do
		if self.events[index].fields.userId == userId then table.remove(self.events, index) end
	end
	for index = #self.keys, 1, -1 do
		local item = self.keys[index]
		if item.userId == userId then
			self.seen[item.id] = nil
			table.remove(self.keys, index)
		end
	end
end

function LoopTelemetry.Destroy(self: Telemetry)
	self.destroyed = true
	self.sink = nil
	table.clear(self.events)
	table.clear(self.seen)
	table.clear(self.keys)
end

return LoopTelemetry
