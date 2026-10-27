--!strict
-- October 27 (WS4 retention, docs/team/LUCKY_START_20261027.md): the Index's found/total
-- rule in one place, so the server's "NEW CHICKEN! … · Index 4/83" receipt and the Index
-- menu always show the same numbers. Event-only chickens (.limited) count only while
-- their event runs or once found; chickens retired from the roll pool (.vaulted) only
-- once found.
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.PetCatalog)
local IndexProgress = {}

local function eventRunning(): boolean
	local event = (Config :: any).Event
	return type(event) == "table" and event.Enabled == true
end

-- Whether a species has an Index card: ever found, or neither vaulted nor an event
-- chicken outside its event.
function IndexProgress.Visible(species: string, everFound: boolean, eventOn: boolean?): boolean
	local definition = Catalog[species] :: any
	if not definition then return false end
	local running = if eventOn == nil then eventRunning() else eventOn
	return everFound or not (definition.vaulted or (definition.limited and not running))
end

-- (found, total) over Catalog.Order. `found` is a discovered map ({[species]=true}) or a
-- session/state carrying one in `.discovered`; eventOn defaults to Config.Event.Enabled.
function IndexProgress.Count(found: any, eventOn: boolean?): (number, number)
	local map = if type(found) == "table" and type(found.discovered) == "table" then found.discovered else found
	if type(map) ~= "table" then map = {} end
	local running = if eventOn == nil then eventRunning() else eventOn
	local collected, total = 0, 0
	for _, species in Catalog.Order do
		local ever = map[species] == true
		if IndexProgress.Visible(species, ever, running) then
			total += 1
			if ever then collected += 1 end
		end
	end
	return collected, total
end

return IndexProgress
