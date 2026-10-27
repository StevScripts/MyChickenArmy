--!strict
-- Device, performance and client-error reports for server Analytics. The server
-- validates and clamps everything; this never affects gameplay. One report after
-- load, then one per minute (server ignores more than one per 20 seconds).
-- Also batches client UI events (AnalyticsClient.Track, fed by AnalyticsUiObserver)
-- into one ClientEvents request every 15 seconds. See docs/analytics/TRACKING_PLAN.md §4.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ScriptContext = game:GetService("ScriptContext")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")
local PerfTier = require(script.Parent.PerfTier)

local AnalyticsClient = {}
local REPORT_SECONDS = 60
-- October 27 (WS6, docs/team/MOBILE_PERFORMANCE_20261027.md): the bootstrap starts this
-- before the app, and the first report goes at 4 s (was 8), so a player who leaves
-- during loading still reports a platform. That first window is the "load" window;
-- the veil lifting (VeilLifted) restarts the window so later reports measure play.
local FIRST_REPORT_SECONDS = 4
local MAX_ERROR_KINDS = 5
local HITCH_SECONDS = 0.1 -- a frame longer than this is a hitch
local FRAME_BIN_MS, FRAME_BINS = 4, 64 -- frame-time histogram for the p90 (0-256 ms)

-- Client UI events. Mirrors src/server/AnalyticsSchema.luau (Schema.ClientEvents,
-- Schema.Menus, ClientEventsPerMinute, ClientEventBatch); that module lives in
-- ServerStorage and is not replicated. Keep both lists in sync (append only).
local EVENT_KINDS: {[string]: string} = {
	["menu.open"] = "menu", ["menu.close"] = "menu", ["ui.click"] = "path", ["tab"] = "path",
	["inspect"] = "path", ["prompt.shown"] = "free", ["prompt.result"] = "free",
	["idle.start"] = "none", ["idle.end"] = "none", ["setting"] = "free", ["hint.shown"] = "free",
	["hint.closed"] = "free", ["load.phase"] = "free", ["leaderboard.view"] = "free",
	["camera.zoom"] = "none", ["chat.sent"] = "none", ["emote"] = "none", ["menu.blocked"] = "menu",
	-- October 27 (schema 16, retention package): WS3's Coins gate and WS7's social moments.
	["coins.gated"] = "free", ["moment.seen"] = "free", ["moment.missed"] = "free", ["invite.sent"] = "free",
}
local MENUS: {[string]: boolean} = {
	Army = true, Shop = true, Index = true, Upgrades = true, Fuse = true, Settings = true, Odds = true,
	Offline = true, Rebirth = true, Daily = true, Missions = true, Sell = true, Formations = true,
	Crate = true, Admin = true, Hud = true, Roll = true, Merchant = true, Leaderboard = true, Other = true,
}
local EVENTS_PER_MINUTE = 120
local EVENT_BATCH = 50
local EVENT_FLUSH_SECONDS = 15
local MAX_QUEUE = 200
local PATH_LIMIT, FREE_LIMIT = 48, 32
local H4 = "%x%x%x%x"
local GUID = "{?" .. H4 .. H4 .. "%-" .. H4 .. "%-" .. H4 .. "%-" .. H4 .. "%-" .. H4 .. H4 .. H4 .. "}?"

local queue: {{n: string, d: string?, v: number?}} = {}
local remoteRef: RemoteEvent? = nil
local rateStart, rateCount = os.clock(), 0
-- October 27 (WS6): the measuring window (reset by each report and by VeilLifted).
local resetWindow: (() -> ())? = nil
local veilLifted, firstSent = false, false

local function platform(): string
	if GuiService:IsTenFootInterface() then return "Console" end
	if UserInputService.VREnabled then return "VR" end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(0, 0)
		return if math.min(size.X, size.Y) >= 700 then "Tablet" else "Mobile"
	end
	return "Desktop"
end

local function px(value: number): number
	return math.clamp(math.floor(value + 0.5), 0, 1000)
end

-- Safe-area insets (notch, rounded corners, home indicator) without creating a GUI:
-- the full-screen inset area minus the device-safe area. Falls back to the topbar inset.
local function insets(): (number?, number?, number?, number?)
	local ok, full, safe = pcall(function(): (Rect, Rect)
		return GuiService:GetInsetArea(Enum.ScreenInsets.None), GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
	end)
	if ok and full and safe and full.Width > 0 and safe.Width > 0 then
		return px(safe.Min.Y - full.Min.Y), px(full.Max.Y - safe.Max.Y), px(safe.Min.X - full.Min.X), px(full.Max.X - safe.Max.X)
	end
	local okInset, topLeft, bottomRight = pcall(function(): (Vector2, Vector2) return GuiService:GetGuiInset() end)
	if okInset and topLeft and bottomRight then
		return px(topLeft.Y), px(bottomRight.Y), px(topLeft.X), px(bottomRight.X)
	end
	return nil, nil, nil, nil
end

-- Each read is guarded: a missing or restricted property just leaves the field out.
local function read(getter: () -> any): any
	local ok, value = pcall(getter)
	return if ok then value else nil
end

local function deviceFields(report: {[string]: any})
	report.insetTop, report.insetBottom, report.insetLeft, report.insetRight = insets()
	report.quality = read(function() return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value end)
	report.locale = read(function() return LocalizationService.RobloxLocaleId end)
	report.sysLocale = read(function() return LocalizationService.SystemLocaleId end)
	report.accel = read(function() return UserInputService.AccelerometerEnabled end)
	report.gyro = read(function() return UserInputService.GyroscopeEnabled end)
	report.preferredInput = read(function() return (UserInputService :: any).PreferredInput.Name end)
	report.reducedMotion = read(function() return (GuiService :: any).ReducedMotionEnabled end)
	report.osHint = read(function() return (UserInputService :: any):GetPlatform().Name end)
end

-- Keeps details low-cardinality: ids, GUIDs and long numbers become "*".
local function clean(kind: string, detail: any): string?
	if kind == "none" then return nil end
	if kind == "menu" then return if type(detail) == "string" and MENUS[detail] then detail else "Other" end
	if type(detail) ~= "string" then return nil end
	local text: string = detail
	text = string.gsub(text, GUID, "*")
	text = string.gsub(text, "%x+", function(run: string): string
		return if #run >= 8 and string.find(run, "%d") then "*" else run
	end)
	text = string.gsub(text, "%d%d%d%d+", "*")
	text = string.gsub(text, if kind == "path" then "[^%w_ /:%-%.%*]" else "[^%w_ /:%-%.=%*]", "")
	text = string.gsub(text, "%*+", "*")
	text = string.sub(text, 1, if kind == "path" then PATH_LIMIT else FREE_LIMIT)
	return if text ~= "" then text else nil
end

local function flush()
	local current = remoteRef
	if not current then return end
	local remote: RemoteEvent = current
	local chunks = 0
	while #queue > 0 and chunks < 4 do
		chunks += 1
		local list = {}
		for _ = 1, math.min(EVENT_BATCH, #queue) do table.insert(list, table.remove(queue, 1)) end
		pcall(function() remote:FireServer({action = "ClientEvents", id = 0, events = list}) end)
	end
end

-- Public: queue one UI event. Unknown names are ignored; at most 120 per minute.
-- Never errors into the caller.
function AnalyticsClient.Track(name: string, detail: string?, value: number?)
	pcall(function()
		local kind = EVENT_KINDS[name]
		if not kind then return end
		local now = os.clock()
		if now - rateStart >= 60 then rateStart, rateCount = now, 0 end
		if rateCount >= EVENTS_PER_MINUTE or #queue >= MAX_QUEUE then return end
		rateCount += 1
		local amount: number? = nil
		if type(value) == "number" and value == value then amount = math.clamp(value, 0, 86400) end
		table.insert(queue, {n = name, d = clean(kind, detail), v = amount})
		if #queue >= EVENT_BATCH or name == "idle.start" then flush() end
	end)
end

-- October 27 (WS6): LoadingController calls this as the veil lifts. Once the first
-- (load) report is out, the window restarts so the next report is play only.
function AnalyticsClient.VeilLifted()
	if veilLifted then return end
	veilLifted = true
	local reset = resetWindow
	if firstSent and reset then reset() end
end

function AnalyticsClient.Start()
	local remotes = ReplicatedStorage:WaitForChild("PetRoll"):WaitForChild("Remotes", 60)
	local remote = remotes and remotes:WaitForChild("RequestAction", 60)
	if not remote then return end
	local player = Players.LocalPlayer
	local ours = {player:WaitForChild("PlayerScripts"), ReplicatedStorage:WaitForChild("PetRoll")}
	local errors, errorOrder = {} :: {[string]: any}, {} :: {string}
	ScriptContext.Error:Connect(function(message, _trace, source)
		if typeof(source) ~= "Instance" then return end
		local mine = false
		for _, root in ours do if (source :: Instance):IsDescendantOf(root) then mine = true end end
		if not mine then return end
		local key = (source :: Instance).Name .. "|" .. string.sub(tostring(message), 1, 80)
		local entry = errors[key]
		if entry then entry.n += 1; return end
		if #errorOrder >= MAX_ERROR_KINDS then return end
		errors[key] = {s = (source :: Instance).Name, m = string.sub(tostring(message), 1, 80), n = 1}
		table.insert(errorOrder, key)
	end)
	-- FPS: average over the report window and the worst one-second window.
	local frames, windowFrames, windowStart, worst = 0, 0, os.clock(), math.huge
	local windowAt = os.clock()
	-- October 27 (WS6): hitches, a frame-time histogram (p90) and window focus.
	local hitches, bins, binTotal = 0, table.create(FRAME_BINS, 0), 0
	local focused, focusLost = true, false
	pcall(function()
		UserInputService.WindowFocusReleased:Connect(function() focused, focusLost = false, true end)
		UserInputService.WindowFocused:Connect(function() focused = true end)
	end)
	RunService.Heartbeat:Connect(function(dt)
		frames += 1; windowFrames += 1
		if dt > HITCH_SECONDS and dt <= 1 then hitches += 1 end
		local bin = math.clamp(math.floor(dt * 1000 / FRAME_BIN_MS) + 1, 1, FRAME_BINS)
		bins[bin] += 1; binTotal += 1
		local now = os.clock()
		if now - windowAt >= 1 then
			worst = math.min(worst, windowFrames / (now - windowAt))
			windowFrames, windowAt = 0, now
		end
	end)
	local function frameP90(): number?
		if binTotal < 10 then return nil end
		local running = 0
		for index, count in bins do
			running += count
			if running >= binTotal * 0.9 then return index * FRAME_BIN_MS end
		end
		return FRAME_BINS * FRAME_BIN_MS
	end
	resetWindow = function()
		frames, windowStart, worst = 0, os.clock(), math.huge
		windowFrames, windowAt = 0, os.clock()
		hitches, binTotal = 0, 0
		table.clear(bins); for index = 1, FRAME_BINS do bins[index] = 0 end
		focusLost = not focused
	end
	local function send(first: boolean)
		local now = os.clock()
		local elapsed = math.max(0.001, now - windowStart)
		local report: {[string]: any} = {fps = frames / elapsed, fpsMin = if worst < math.huge then worst else nil}
		local okMem, mem = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
		if okMem then report.memMb = mem end
		-- October 27 (WS6): which window this is, the PerfTier state and frame pacing.
		report.window = if first or not veilLifted then "load" else "play"
		report.hitches, report.focusLost, report.frameMsP90 = hitches, focusLost, frameP90()
		pcall(function()
			local stats = PerfTier.Stats()
			report.tier, report.critical, report.demotions = stats.tier, stats.critical, stats.demotions
		end)
		if first then
			local camera = workspace.CurrentCamera
			local size = if camera then camera.ViewportSize else Vector2.new(0, 0)
			report.platform, report.screenX, report.screenY = platform(), size.X, size.Y
			report.touch, report.keyboard, report.gamepad = UserInputService.TouchEnabled,
				UserInputService.KeyboardEnabled, UserInputService.GamepadEnabled
			pcall(deviceFields, report)
		end
		if #errorOrder > 0 then
			local list = {}
			for _, key in errorOrder do table.insert(list, errors[key]) end
			report.errors = list
			table.clear(errors); table.clear(errorOrder)
		end
		local reset = resetWindow
		if reset then reset() end
		firstSent = firstSent or first
		remote:FireServer({action = "ClientReport", id = 0, report = report})
	end
	task.delay(FIRST_REPORT_SECONDS, function()
		send(true)
		while true do
			task.wait(REPORT_SECONDS)
			send(false)
		end
	end)
	-- UI events: flush queued ones now, then every 15 seconds and when the Roblox
	-- menu opens (often just before leaving).
	if remote:IsA("RemoteEvent") then remoteRef = remote end
	flush()
	task.spawn(function()
		while true do
			task.wait(EVENT_FLUSH_SECONDS)
			flush()
		end
	end)
	pcall(function() GuiService.MenuOpened:Connect(flush) end)
	task.spawn(function()
		local module = script.Parent and script.Parent:FindFirstChild("AnalyticsUiObserver")
		if not module or not module:IsA("ModuleScript") then return end
		local ok, observer = pcall(require, module)
		if ok and type(observer) == "table" and type(observer.Start) == "function" then
			pcall(observer.Start, AnalyticsClient.Track)
		end
	end)
end

return AnalyticsClient
