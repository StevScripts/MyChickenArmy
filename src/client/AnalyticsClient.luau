--!strict
-- Device, performance and client-error reports for server Analytics. The server
-- validates and clamps everything; this never affects gameplay. One report after
-- load, then one per minute (server ignores more than one per 20 seconds).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ScriptContext = game:GetService("ScriptContext")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnalyticsClient = {}
local REPORT_SECONDS = 60
local FIRST_REPORT_SECONDS = 8
local MAX_ERROR_KINDS = 5

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
	RunService.Heartbeat:Connect(function()
		frames += 1; windowFrames += 1
		local now = os.clock()
		if now - windowAt >= 1 then
			worst = math.min(worst, windowFrames / (now - windowAt))
			windowFrames, windowAt = 0, now
		end
	end)
	local function send(first: boolean)
		local now = os.clock()
		local elapsed = math.max(0.001, now - windowStart)
		local report: {[string]: any} = {fps = frames / elapsed, fpsMin = if worst < math.huge then worst else nil}
		local okMem, mem = pcall(function() return Stats:GetTotalMemoryUsageMb() end)
		if okMem then report.memMb = mem end
		if first then
			local camera = workspace.CurrentCamera
			local size = if camera then camera.ViewportSize else Vector2.new(0, 0)
			report.platform, report.screenX, report.screenY = platform(), size.X, size.Y
			report.touch, report.keyboard, report.gamepad = UserInputService.TouchEnabled,
				UserInputService.KeyboardEnabled, UserInputService.GamepadEnabled
		end
		if #errorOrder > 0 then
			local list = {}
			for _, key in errorOrder do table.insert(list, errors[key]) end
			report.errors = list
			table.clear(errors); table.clear(errorOrder)
		end
		frames, windowStart, worst = 0, now, math.huge
		remote:FireServer({action = "ClientReport", id = 0, report = report})
	end
	task.delay(FIRST_REPORT_SECONDS, function()
		send(true)
		while true do
			task.wait(REPORT_SECONDS)
			send(false)
		end
	end)
end

return AnalyticsClient
