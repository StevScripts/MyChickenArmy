-- Isolated Edit binding checks. Cloned surfaces and fake requests only.
assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning())
assert(not workspace:FindFirstChild("PetRollWorld"), "An existing runtime world must not be changed")
local cache = {}
local function fresh(module)
	if cache[module] then return cache[module] end
	local fn, err = loadstring(module.Source, module.Name)
	assert(fn, err)
	setfenv(fn, setmetatable({script = module, require = fresh}, {__index = getfenv()}))
	local result = fn()
	cache[module] = result
	return result
end
local modules = game.StarterPlayer.StarterPlayerScripts.PetRoll
local Board, Theme = fresh(modules.EggProcessorController), fresh(modules.UITheme)
local world = Instance.new("Folder")
world.Name = "PetRollWorld"
world.Parent = workspace
local guiParent = Instance.new("Folder")
local calls = {upgrade = 0, finish = 0}
local app = {state = {plotIndex = 1, coins = 1000, eggs = {processor = {
	enabled = true, queuedCount = 1000, rate = 4, level = 0,
	upgradePrice = 480, readyCash = 20,
}}}, audio = {Play = function() end}}
app.commerce = {State = function() return "ready" end,
	Buy = function(_, key) assert(key == "FinishEggs"); calls.finish += 1 end}
function app:Request(action, data)
	assert(action == "EggSellerUpgrade" and data.expectedLevel == 0 and data.expectedPrice == 480)
	calls.upgrade += 1
	return "fixture-upgrade"
end
local controller = Board.new(app)
controller.playerGui = guiParent
local ok, result = xpcall(function()
	local home = workspace.MyChickenArmyMap["03_HomePlots"]
	for index = 1, 6 do
		local original = if index == 1 then home.EggCollectionBoard else home["Plot" .. index].EggCollectionBoard
		assert(original:GetAttribute("PlotIndex") == index)
		assert(original.Screen.SurfaceGui.EggSellingBoard.Content.Upgrade.Visible)
		local clone = original:Clone()
		clone.Parent = world
		for _, source in clone:GetDescendants() do
			if source:IsA("SurfaceGui") then controller:Bind(source) end
		end
	end
	for index = 1, 6 do
		app.state.plotIndex = index
		controller:Render()
		local enabled = 0
		for _, view in controller.views do
			if view.gui.Enabled then
				enabled += 1
				assert(view.index == index)
				if view.content then
					assert(view.content.QueuedCount.Text == Theme.Money(1000))
					assert(view.content.Rate.Text == "4 eggs/sec")
					assert(view.content.Upgrade.Visible and view.content.Upgrade.Active)
					assert(view.content.FinishNow.Visible and view.content.FinishNow.Active)
				else assert(view.cash.Text == "$20") end
			end
		end
		assert(enabled == 2, "Each owner must see exactly the board and its cash pad")
	end
	controller:Activate("Upgrade")
	controller:Receive({id = "fixture-upgrade"})
	controller:Activate("FinishNow")
	assert(calls.upgrade == 1 and calls.finish == 1)
	app.state.eggs.processor.queuedCount = 0
	controller:Render()
	for _, view in controller.views do
		if view.content then assert(not view.content.FinishNow.Active) end
	end
	return {plots = 6, liveSurfaces = 12, upgradeRequests = calls.upgrade,
		finishRequests = calls.finish, realRemoteCalls = 0, passed = true}
end, debug.traceback)
controller:Destroy()
world:Destroy()
guiParent:Destroy()
assert(ok, result)
return result
