--!strict
-- Runs only in an explicitly requested, isolated StudioTestService acceptance session.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AcceptanceClient = {}

function AcceptanceClient.Run(app)
	if not RunService:IsStudio() or not game.ReplicatedStorage.PetRoll:GetAttribute("AcceptanceTest") then return end
	local wire = game.ReplicatedStorage.PetRoll:WaitForChild("AcceptanceWire", 15)
	if not wire then return end
	local frames, pending, connections = {}, {}, {}
	local function report(token, result)
		local copy = table.clone(frames)
		table.sort(copy)
		local world = workspace:FindFirstChild("PetRollWorld")
		local battle = app.battle:Current()
		local foreignPrompts, visibleForeign, battleModels, localCopies = 0, 0, 0, 0
		if world then
			for _, item in world:GetDescendants() do
				if not item:IsA("ProximityPrompt") then continue end
				if item.Name ~= "RollPrompt" and item.Name ~= "BuyPrompt" and item.Name ~= "SlotPrompt" then continue end
				local ancestor, owner, plot = item.Parent, nil, nil
				while ancestor and ancestor ~= world do
					owner = owner or ancestor:GetAttribute("OwnerUserId") or ancestor:GetAttribute("OwnerId")
					plot = plot or ancestor:GetAttribute("PlotIndex")
					ancestor = ancestor.Parent
				end
				local foreign = (owner and owner ~= Players.LocalPlayer.UserId) or (plot and app.state and plot ~= app.state.plotIndex)
				if foreign then foreignPrompts += 1;if item.MaxActivationDistance > 0 then visibleForeign += 1 end end
			end
			local root = world:FindFirstChild("Battles")
			if root and battle then
				local folder = root:FindFirstChild(battle.id)
				if folder then
					for _, model in folder:GetChildren() do
						if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") and model:GetAttribute("DuckRig") then battleModels += 1 end
					end
				end
			end
		end
		local effects = workspace:FindFirstChild("PetRollBattleVisuals")
		if effects then for _, child in effects:GetDescendants() do if child:IsA("Model") then localCopies += 1 end end end
		local memoryOk, memoryMb = pcall(function() return game:GetService("Stats"):GetTotalMemoryUsageMb() end)
		wire:FireServer({token = token, result = result, ready = app.state ~= nil, gui = app.gui ~= nil,
			memoryMb = if memoryOk then memoryMb else nil, memoryAvailable = memoryOk,
			foreignPrompts = foreignPrompts, visibleForeign = visibleForeign, actualBattleModels = battleModels, localCombatCopies = localCopies,
			camera = workspace.CurrentCamera and workspace.CurrentCamera.CameraType.Name,
			viewport = workspace.CurrentCamera and tostring(workspace.CurrentCamera.ViewportSize),
			state = app.state and {count = app.state.count, deployed = app.state.deployedCount or 0, selected = app.state.selectedCount or 0, capacity = app.state.capacity,
				armyState = app.state.armyState, campsWon = app.state.campsWon},
			battleId = battle and battle.id, battleUnits = if battle then #battle.units else 0,
			frameSamples = #copy, medianFrameMs = if #copy > 0 then copy[math.ceil(#copy * 0.5)] * 1000 else 0,
			p95FrameMs = if #copy > 0 then copy[math.ceil(#copy * 0.95)] * 1000 else 0})
	end
	table.insert(connections, RunService.RenderStepped:Connect(function(dt) if #frames < 3600 then table.insert(frames, dt) end end))
	table.insert(connections, app.remotes.StateChanged.OnClientEvent:Connect(function(packet)
		local result = type(packet) == "table" and packet.result
		local token = result and pending[result.id]
		if token then pending[result.id] = nil;report(token, {ok = result.ok, message = result.message, action = result.action}) end
	end))
	table.insert(connections, wire.OnClientEvent:Connect(function(command)
		if command.kind == "Action" then
			-- Register before firing the request, so a fast local response cannot be missed.
			pending[app.requestId + 1] = command.token
			app:Request(command.action, command.payload)
		elseif command.kind == "Probe" then report(command.token)
		elseif command.kind == "FramesReset" then frames = {}
		elseif command.kind == "OpenCollection" then app:OpenPage("Army")
		elseif command.kind == "CloseCollection" then app:ClosePanel()
		elseif command.kind == "Leave" then
			report(command.token)
			for _, connection in connections do connection:Disconnect() end
			local service = game:GetService("StudioTestService")
			if service:CanLeaveTest() then service:LeaveTest() end
		end
	end))
	local deadline = os.clock() + 20
	while not app.state and os.clock() < deadline do task.wait(0.1) end
	report("Ready")
end

return AcceptanceClient
