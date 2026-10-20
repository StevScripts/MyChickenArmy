--!strict
-- Observation-only UI analytics (docs/analytics/TRACKING_PLAN.md §4). Watches the
-- runtime PlayerGui.PetRollGui tree built by AppController and the menu modules;
-- never edits, creates or destroys GUI instances and never changes gameplay.
-- Renaming a menu root or button below only changes the reported label.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Observer = {}

type Track = (name: string, detail: string?, value: number?) -> ()
type Root = {path: string, menu: string, open: string?}

-- THE menu table. path is from PetRollGui; the last two segments ("Parent/Name")
-- attribute clicks to the nearest menu root. menu is a Schema.Menus key, or "@main"
-- for the shared main panel whose page is resolved below. open says how the menu
-- shows: "page" = a page root visible inside the visible main panel, "visible" =
-- the root's Visible, "exists" = the root is created on open and destroyed on close.
local ROOTS: {Root} = {
	{path = "Shell/FRAMES/Panel", menu = "@main"},                          -- AppController:BuildUI
	{path = "Shell/FRAMES/Panel/StandardPage", menu = "@main"},             -- Odds/Settings/Admin/Formations (title)
	{path = "Shell/FRAMES/Panel/ChickenBrowser", menu = "Army", open = "page"},
	{path = "Shell/FRAMES/Panel/SellMenu", menu = "Sell", open = "page"},     -- October 20 (Fuse removed)
	{path = "Shell/FRAMES/Panel/ShopBrowser", menu = "Shop", open = "page"},
	{path = "Shell/FRAMES/Panel/UpgradesBrowser", menu = "Upgrades", open = "page"}, -- legacy cash board
	{path = "Shell/FRAMES/Panel/StandardPage/Main/IndexBrowser", menu = "Index", open = "page"},
	{path = "Shell/FRAMES/Research", menu = "Upgrades", open = "visible"},   -- the Upgrades tree
	{path = "Shell/OTHER/Reenlist", menu = "Rebirth", open = "exists"},
	{path = "Shell/OTHER/DailyStreak", menu = "Daily", open = "exists"},
	{path = "Shell/OTHER/OfflineEarnings", menu = "Offline", open = "exists"},
	{path = "Shell/OTHER/Operations", menu = "Missions", open = "exists"},
	{path = "Shell/OTHER/GalaxyCrateRoll", menu = "Crate", open = "visible"},
	{path = "Shell/OTHER/MerchantDialogue/Responses", menu = "Merchant", open = "visible"},
	{path = "Shell/OTHER/CommanderGuide", menu = "Other"},
	{path = "Shell/HUD", menu = "Hud"},
}
-- Standard-page titles (AppController/AdminPanel/ResearchExtras set panelTitle.Text);
-- matched as a prefix when no page root above is visible.
local PAGE_TITLES: {{string}} = {
	{"Roll Odds", "Odds"}, {"Settings", "Settings"}, {"Admin", "Admin"}, {"Army Formations", "Formations"},
	{"Invasions", "Missions"}, {"Chicken Index", "Index"}, {"Shop", "Shop"}, {"Fuse", "Fuse"}, {"My Army", "Army"},
}
-- Sub-views: "<Parent>/<Name>" whose property turning true is a tab or inspect.
local VIEWS: {[string]: {event: string, detail: string, property: string}} = {
	["ArmyContent/ArmyInfo"] = {event = "tab", detail = "Army/Stats", property = "Visible"},
	["ArmyContent/MoreArmySlots"] = {event = "tab", detail = "Army/Slots", property = "Visible"},
	["Main/PurchaseDetails"] = {event = "inspect", detail = "Shop/details", property = "Visible"},
	-- The research card sinks input only while pinned (right-click / long press).
	["Research/NodeTooltip"] = {event = "inspect", detail = "Upgrades/node", property = "Active"},
}
-- Settings rows (AppController:RenderSettings): button name -> setting name. The
-- value is read from the button text after "·" ("Music  ·  ON").
local SETTINGS: {[string]: string} = {
	ToggleMusic = "music", ToggleEffects = "sfx", ReducedMotion = "reducedMotion",
	ToggleAutoRoll = "autoRoll", AutoRollStop = "autoRollStop", ToggleGoals = "goals",
}
-- Leaderboard SurfaceGui names (LeaderboardBoards STYLE surface) -> board key.
local BOARDS: {[string]: string} = {
	Leaderboard_ArmyPower = "ArmyPower", Leaderboard_RobuxSpent = "Rebirths", Leaderboard_MostRobux = "RobuxSpent",
}
local IDLE_SECONDS = 120 -- Schema.IdleSeconds
local POLL_SECONDS = 0.5
local CLICK_DEBOUNCE = 0.2
local SCAN_PER_FRAME = 300
local BOARD_NEAR, BOARD_FAR = 40, 70

local started = false

local function split(path: string): {string}
	local parts = {}
	for part in string.gmatch(path, "[^/]+") do table.insert(parts, part) end
	return parts
end

local function find(root: Instance, path: string): Instance?
	local node: Instance? = root
	for _, part in split(path) do
		if not node then return nil end
		node = node:FindFirstChild(part)
	end
	return node
end

local function visible(item: Instance?): boolean
	return item ~= nil and item:IsA("GuiObject") and item.Visible
end

local function slug(text: string): string?
	text = string.gsub(text, "<[^>]*>", "")
	local words = {}
	for word in string.gmatch(text, "%a+") do
		table.insert(words, word)
		if #words >= 4 then break end
	end
	return if #words > 0 then string.sub(table.concat(words, "_"), 1, 32) else nil
end

function Observer.Start(track: Track)
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local foundPlayerGui = player:WaitForChild("PlayerGui", 30)
	local foundGui = foundPlayerGui and foundPlayerGui:WaitForChild("PetRollGui", 60)
	if not foundPlayerGui or not foundGui then return end
	local playerGui: Instance, gui: Instance = foundPlayerGui, foundGui
	local function emit(name: string, detail: string?, value: number?)
		pcall(track, name, detail, value)
	end
	emit("load.phase", "gui", time())

	local rootByKey: {[string]: Root} = {}
	for _, root in ROOTS do
		local parts = split(root.path)
		local key = if #parts >= 2 then parts[#parts - 1] .. "/" .. parts[#parts] else "PetRollGui/" .. parts[1]
		rootByKey[key] = root
	end

	-- Main panel page: a visible page root, else the standard page's title.
	local function mainPage(): string?
		local panel = find(gui, "Shell/FRAMES/Panel")
		if not visible(panel) then return nil end
		for _, root in ROOTS do
			if root.open == "page" and visible(find(gui, root.path)) then return root.menu end
		end
		local title = find(gui, "Shell/FRAMES/Panel/StandardPage/Header/Title")
		local text = if title and title:IsA("TextLabel") then title.Text else ""
		for _, entry in PAGE_TITLES do
			if string.sub(text, 1, #entry[1]) == entry[1] then return entry[2] end
		end
		return "Other"
	end

	local function menuOf(item: Instance): string
		local node: Instance? = item
		while node and node ~= gui do
			local parent: Instance? = node.Parent
			if parent then
				local root = rootByKey[parent.Name .. "/" .. node.Name]
				if root then
					return if root.menu == "@main" then (mainPage() or "Other") else root.menu
				end
			end
			node = parent
		end
		return "Other"
	end

	-- Clicks, tabs and card inspections.
	local lastClick, lastClickAt = "", 0
	local function onClick(button: GuiButton)
		local now = os.clock()
		local menu = menuOf(button)
		local name = button.Name
		local chicken = string.sub(name, 1, 8) == "Chicken_"
		local path = menu .. "/" .. (if chicken then "Chicken_*" else name)
		if path == lastClick and now - lastClickAt < CLICK_DEBOUNCE then return end
		lastClick, lastClickAt = path, now
		emit("ui.click", path)
		local parent = button.Parent
		if parent and parent.Name == "SectionNavigation" then emit("tab", menu .. "/" .. name) end
		if chicken and (menu == "Army" or menu == "Fuse") then emit("inspect", menu .. "/chicken") end
	end

	local connections: {[Instance]: RBXScriptConnection} = {}
	local function release(item: Instance)
		local connection = connections[item]
		if connection then connection:Disconnect(); connections[item] = nil end
	end
	local function consider(item: Instance)
		if connections[item] then return end
		local layouts = gui:FindFirstChild("MenuLayouts")
		if layouts and item:IsDescendantOf(layouts) then return end -- authoring templates
		local parent = item.Parent
		if not parent then return end
		if item:IsA("GuiButton") then
			if rootByKey[parent.Name .. "/" .. item.Name] then return end -- a menu root itself (Research map)
			local button: GuiButton = item
			connections[item] = button.Activated:Connect(function() pcall(onClick, button) end)
			return
		end
		local view = VIEWS[parent.Name .. "/" .. item.Name]
		if view and item:IsA("GuiObject") then
			local object: any = item
			local last = object[view.property] == true
			connections[item] = item:GetPropertyChangedSignal(view.property):Connect(function()
				pcall(function()
					local now = object[view.property] == true
					if now and not last and object.Visible then emit(view.event, view.detail) end
					last = now
				end)
			end)
		end
	end
	local lifetime: {RBXScriptConnection} = {}
	table.insert(lifetime, gui.DescendantAdded:Connect(function(item) pcall(consider, item) end))
	table.insert(lifetime, gui.DescendantRemoving:Connect(function(item)
		if not connections[item] then return end
		-- Moves inside the GUI keep their connection; removal or Destroy releases it.
		task.defer(function() if not item:IsDescendantOf(gui) then release(item) end end)
	end))
	task.spawn(function()
		for index, item in gui:GetDescendants() do
			pcall(consider, item)
			if index % SCAN_PER_FRAME == 0 then task.wait() end
		end
	end)

	-- Purchase prompts. The client has no "prompt opened" event, so prompt.shown is
	-- sent together with the result (value 0) when the Roblox dialog closes.
	local products: {[number]: string}, passes: {[number]: string} = {}, {}
	pcall(function()
		local catalog = require(ReplicatedStorage:WaitForChild("PetRoll"):WaitForChild("Shared"):WaitForChild("ShopCatalog") :: ModuleScript) :: any
		for key, product in catalog.Products or {} do
			if type(product) == "table" and type(product.productId) == "number" then products[product.productId] = key end
		end
		for key, pass in catalog.Definitions or {} do
			if type(pass) == "table" and type(pass.passId) == "number" then passes[pass.passId] = key end
		end
	end)
	local function prompt(kind: string, key: string, bought: boolean)
		emit("prompt.shown", kind .. ":" .. key, 0)
		emit("prompt.result", key .. ":" .. (if bought then "bought" else "cancel"))
	end
	pcall(function()
		table.insert(lifetime, MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: any, productId: any, purchased: any)
			if userId ~= player.UserId then return end
			prompt("product", products[tonumber(productId) or 0] or "unknown", purchased == true)
		end))
	end)
	pcall(function()
		table.insert(lifetime, MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who: any, passId: any, purchased: any)
			if who ~= player then return end
			prompt("pass", passes[tonumber(passId) or 0] or "unknown", purchased == true)
		end))
	end)

	-- Idle and camera zoom from raw input (no per-frame polling).
	local lastInput, idle = os.clock(), false
	local zooms = 0
	local function active()
		local now = os.clock()
		if idle then
			idle = false
			emit("idle.end", nil, now - lastInput)
		end
		lastInput = now
	end
	table.insert(lifetime, UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		active()
		if not processed and (input.KeyCode == Enum.KeyCode.I or input.KeyCode == Enum.KeyCode.O) then zooms += 1 end
	end))
	table.insert(lifetime, UserInputService.InputChanged:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseWheel then
			zooms += 1;active()
		elseif kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch
			or kind == Enum.UserInputType.Gamepad1 then
			active()
		end
	end))
	table.insert(lifetime, UserInputService.TouchPinch:Connect(function(_positions: any, _scale: any, _velocity: any, state: Enum.UserInputState)
		if state == Enum.UserInputState.Begin then zooms += 1 end
	end))

	-- Chat: count only; the message is never read.
	pcall(function()
		table.insert(lifetime, TextChatService.SendingMessage:Connect(function() emit("chat.sent") end))
	end)

	-- Polled state: open menus, guide card, settings values, loading veil, boards.
	local openMenus: {[string]: number} = {}
	local hint: string? = nil
	local settings: {[string]: string} = {}
	local ready = false
	local nearBoards: {[string]: boolean} = {}
	local ticks, zoomAt = 0, os.clock()

	local function currentMenus(): {[string]: boolean}
		local set: {[string]: boolean} = {}
		local page = mainPage()
		if page then set[page] = true end
		for _, root in ROOTS do
			if root.open == "visible" then
				if visible(find(gui, root.path)) then set[root.menu] = true end
			elseif root.open == "exists" then
				if find(gui, root.path) then set[root.menu] = true end
			end
		end
		return set
	end

	local function pollMenus(now: number)
		local current = currentMenus()
		for menu, openedAt in openMenus do
			if not current[menu] then
				openMenus[menu] = nil
				emit("menu.close", menu, now - openedAt)
			end
		end
		for menu in current do
			if not openMenus[menu] then
				openMenus[menu] = now
				emit("menu.open", menu)
			end
		end
	end

	local function pollHint()
		local root = find(gui, "Shell/OTHER/CommanderGuide")
		local card = root and root:FindFirstChild("Card")
		local label = card and card:FindFirstChild("Objective")
		local current: string? = nil
		if visible(root) and visible(card) and label and label:IsA("TextLabel") then current = slug(label.Text) end
		if current ~= hint then
			if hint then emit("hint.closed", hint) end
			if current then emit("hint.shown", current) end
			hint = current
		end
	end

	local function pollSettings()
		if not openMenus.Settings then return end
		local content = find(gui, "Shell/FRAMES/Panel/StandardPage/Main/Content")
		if not content then return end
		for buttonName, setting in SETTINGS do
			local button = content:FindFirstChild(buttonName)
			if button and button:IsA("TextButton") then
				local value = string.match(button.Text, "·%s*(.-)%s*$")
				if value and value ~= "" then
					value = string.gsub(value, "%s+", "_")
					local previous = settings[setting]
					if previous and previous ~= value then emit("setting", setting .. "=" .. value) end
					settings[setting] = value
				end
			end
		end
	end

	local function pollBoards()
		local character = player.Character
		local body = character and character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		if not body or not body:IsA("BasePart") or not camera then return end
		for _, child in playerGui:GetChildren() do
			local board = BOARDS[child.Name]
			if board and child:IsA("SurfaceGui") then
				local screen = child.Adornee
				if screen and screen:IsA("BasePart") then
					local distance = (screen.Position - body.Position).Magnitude
					if distance > BOARD_FAR then
						nearBoards[board] = nil
					elseif distance <= BOARD_NEAR and not nearBoards[board] then
						local _, onScreen = camera:WorldToViewportPoint(screen.Position)
						if onScreen then
							nearBoards[board] = true
							emit("leaderboard.view", board)
						end
					end
				end
			end
		end
	end

	task.spawn(function()
		while gui.Parent do
			task.wait(POLL_SECONDS)
			local now = os.clock()
			ticks += 1
			pcall(pollMenus, now)
			pcall(pollHint)
			pcall(pollSettings)
			if not ready and not gui:FindFirstChild("LoadingOverlay") then
				ready = true
				emit("load.phase", "ready", time())
			end
			if ticks % 4 == 0 then pcall(pollBoards) end
			if not idle and now - lastInput >= IDLE_SECONDS then
				idle = true
				emit("idle.start")
			end
			if now - zoomAt >= 60 then
				if zooms > 0 then emit("camera.zoom", nil, zooms) end
				zooms, zoomAt = 0, now
			end
		end
		for _, connection in lifetime do connection:Disconnect() end
		for item in connections do release(item) end
	end)
end

return Observer
