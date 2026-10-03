-- Run with the standalone Luau CLI. Loads the actual module, no Studio.
local Quality = require("../../src/client/ChickenEffectQuality")
local checked = 0
local function check(name, fn)
	fn()
	checked += 1
	print("PASS " .. name)
end
local function advance(state, seconds, fps)
	for _ = 1, math.ceil(seconds * fps) do Quality.Advance(state, 1 / fps) end
	return ({"static", "animated", "masked"})[state.tier]
end

check("Every manual setting stays selected across fast and throttled rendering", function()
	for level = 1, 10 do
		local expected = if level <= 4 then "static" elseif level <= 7 then "animated" else "masked"
		assert(Quality.TierForSavedLevel(level) == expected)
		local state = Quality.NewState(level)
		for _, fps in {120, 60, 40, 25, 15, 5, 60} do
			assert(advance(state, 90, fps) == expected)
		end
	end
end)

check("Automatic starts static and needs separate sustained promotion windows", function()
	local state = Quality.NewState(0)
	assert(state.tier == 1)
	assert(advance(state, 11, 60) == "static")
	assert(advance(state, 2, 60) == "animated")
	assert(advance(state, 28, 60) == "animated")
	assert(advance(state, 2, 60) == "masked")
end)

check("Automatic on a slow device never promotes", function()
	assert(advance(Quality.NewState(0), 120, 30) == "static")
	assert(advance(Quality.NewState(0), 120, 45) == "static")
end)

check("Automatic reduces its budget permanently after sustained pressure", function()
	local state = Quality.NewState(0)
	assert(advance(state, 45, 60) == "masked")
	assert(advance(state, 2, 25) == "masked")
	assert(advance(state, 2, 25) == "animated")
	assert(advance(state, 4, 25) == "static")
	assert(advance(state, 120, 120) == "static")
end)

check("Automatic does not re-enable an expensive mask when its removal improves FPS", function()
	local state = Quality.NewState(0)
	assert(advance(state, 45, 60) == "masked")
	assert(advance(state, 5, 40) == "animated")
	for _ = 1, 5 do
		assert(advance(state, 90, 120) == "animated")
		assert(advance(state, 10, 40) == "animated")
	end
end)

check("Automatic accepts normal 60 Hz timing variation", function()
	local state = Quality.NewState(0)
	for i = 1, 60 * 50 do
		-- Small, sustained timing variation must not restart a 30-second window.
		Quality.Advance(state, if i % 120 < 40 then 0.0177 else 1 / 60)
	end
	assert(state.tier == 3)
end)

check("Focus changes retain the material and pause Automatic sampling", function()
	local callbacks, disconnected = {}, 0
	local input = {}
	for _, event in {"WindowFocused", "WindowFocusReleased"} do
		input[event] = {Connect = function(_, fn)
			callbacks[event] = fn
			return {Disconnect = function() disconnected += 1 end}
		end}
	end
	for _, level in {0, 1, 8, 10} do
		local controller = Quality.new({SavedQualityLevel = level}, input)
		if level == 0 then advance(controller.state, 45, 60) end
		local expected = controller:GetTier()
		for _ = 1, 10 do
			callbacks.WindowFocusReleased()
			for _ = 1, 100 do assert(controller:Step(0.25) == expected) end
			callbacks.WindowFocused()
			assert(controller:GetTier() == expected)
		end
		controller:Destroy()
	end
	assert(disconnected == 8)
end)

check("One hitch does not downgrade; suspended time does not earn promotion", function()
	local high = Quality.NewState(10)
	advance(high, 1, 60)
	assert(Quality.Advance(high, 0.5) == "masked")
	assert(advance(high, 5, 60) == "masked")
	local auto = Quality.NewState(0)
	advance(auto, 11, 60)
	assert(Quality.Advance(auto, 20) == "static")
	assert(advance(auto, 2, 60) == "static")
	assert(Quality.Advance(auto, 0 / 0) == "static")
	assert(Quality.Advance(auto, -1) == "static")
end)

check("Live settings updates apply immediately and teardown disconnects", function()
	local callback, disconnected
	local settings = {SavedQualityLevel = {Value = 10}}
	function settings:GetPropertyChangedSignal(property)
		assert(property == "SavedQualityLevel")
		return {Connect = function(_, fn)
			callback = fn
			return {Disconnect = function() disconnected = true end}
		end}
	end
	local controller = Quality.new(settings)
	assert(controller:GetTier() == "masked")
	settings.SavedQualityLevel = {Value = 4}
	callback()
	assert(controller:GetTier() == "static")
	settings.SavedQualityLevel = {Value = 0}
	callback()
	assert(controller:Step(1 / 60) == "static")
	controller:Destroy()
	controller:Destroy()
	assert(disconnected)
	settings.SavedQualityLevel = {Value = 10}
	callback()
	assert(controller:GetTier() == "static")
end)

print(string.format("%d focused quality-policy checks passed", checked))
