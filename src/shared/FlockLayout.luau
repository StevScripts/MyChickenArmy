--!strict
-- Pure deterministic offsets shared by homecoming, assembly, camp combat and holding.
local FlockLayout = {}
local HomePlot = require(script.Parent.HomePlotLayout)
FlockLayout.SpacingX = 3.1
FlockLayout.SpacingZ = 3.2

function FlockLayout.Dimensions(count: number): (number, number)
	local amount = math.max(1, math.floor(count))
	local columns = math.min(6, amount)
	return columns, math.ceil(amount / columns)
end

function FlockLayout.Offset(index: number, count: number): (number, number)
	local columns, rows = FlockLayout.Dimensions(count)
	local ordinal = math.max(1, math.floor(index)) - 1
	local row = math.floor(ordinal / columns)
	local rowCount = math.min(columns, math.max(1, count - row * columns))
	return (ordinal % columns - (rowCount - 1) / 2) * FlockLayout.SpacingX,
		(row - (rows - 1) / 2) * FlockLayout.SpacingZ
end

function FlockLayout.Entry(index: number, count: number, side: string): (number, number)
	local x, z = FlockLayout.Offset(index, count)
	local _, rows = FlockLayout.Dimensions(count)
	return x, if side == "A" then 8.5 + z + (rows - 1) * FlockLayout.SpacingZ / 2 else z - 3
end

function FlockLayout.Assembly(index: number, count: number): (number, number)
	return 0, HomePlot.AssemblyZ+(index-1)*3.4
end

function FlockLayout.Home(index: number): (number, number)
	return HomePlot.Home(index)
end

return FlockLayout
