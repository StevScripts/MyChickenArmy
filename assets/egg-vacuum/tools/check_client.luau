--!strict
-- Focused Edit-mode renderer check. Does not start Play or require LocalPlayer.
-- Pass a freshly required VacuumController table to avoid Studio's require cache.
-- An optional Config table supports the integrator's temporary dependency clones.
-- UITheme -> UIMotion/UIColors has no LocalPlayer dependency; the real theme is safe.
return function(VacuumControllerOverride, VacuumConfigOverride)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage.PetRoll.Shared
	local Controller = VacuumControllerOverride
	if not Controller then
		Controller = require(game:GetService("StarterPlayer").StarterPlayerScripts.PetRoll.VacuumController)
	elseif typeof(Controller) == "Instance" then
		Controller = require(Controller)
	end
	local Config = VacuumConfigOverride or require(Shared.VacuumConfig)
	local template = ReplicatedStorage.PetRoll.Assets:FindFirstChild(Config.TemplateName)
	assert(template and template:IsA("Model"), "Import Assets.EggVacuum before this renderer check")

	local checks, fixtures, original = {}, {}, {}
	local expected = {"Body", "WheelLeft", "WheelRight", "Nozzle", "Hose", "Socket", "NozzleLeft", "NozzleRight", "Support"}
	for _, object in template:GetDescendants() do
		if object:IsA("BasePart") then
			table.insert(original, {part = object, parent = object.Parent, cf = object.CFrame, size = object.Size})
		end
	end
	local container = Instance.new("Folder")
	container.Name = "VacuumClientSmoke_" .. game:GetService("HttpService"):GenerateGUID(false)
	container.Parent = workspace
	local function expect(condition, description)
		assert(condition, description)
		table.insert(checks, description)
	end
	local function near(a, b)
		-- The isolated fixture sits far from the live map; allow world-position
		-- float precision without hiding any meaningful mesh/animation movement.
		return (a - b).Magnitude < 0.002
	end
	local function sameFrame(a, b)
		return near(a.Position, b.Position) and near(a.LookVector, b.LookVector) and near(a.UpVector, b.UpVector)
	end
	local function snapshot(changes)
		local data = {enabled = true, id = "client-smoke", state = "Idle",
			x = 10000, y = -500, z = 10000, dx = 0, dz = -1,
			cargoCount = 0, cargoValue = 0, suctionSerial = 0, unloadSerial = 0}
		for key, value in changes or {} do data[key] = value end
		return data
	end
	local function fixture()
		local folder = Instance.new("Folder")
		folder.Name = "Renderer" .. tostring(#fixtures + 1)
		folder.Parent = container
		local gui = Instance.new("ScreenGui")
		gui.Name, gui.Parent = "UnusedAppGui", folder
		local sounds = {}
		local app = {gui = gui, reducedMotion = false, hud = nil, audio = {}}
		function app.audio:Play(name, pitch, options)
			table.insert(sounds, {name = name, pitch = pitch, options = options})
		end
		local object = {folder = folder, gui = gui, app = app, sounds = sounds,
			renderer = Controller.new(app, folder), now = 100}
		function object:Advance(seconds)
			local finish = self.now + seconds
			while self.now < finish - 0.000001 do
				self.now = math.min(finish, self.now + 1 / 60)
				self.renderer:Step(self.now)
			end
		end
		table.insert(fixtures, object)
		return object
	end

	local ok, result = pcall(function()
		local a = fixture()
		local renderer = a.renderer
		renderer:Receive(snapshot(), a.now)
		renderer:Step(a.now)
		expect(renderer.model and renderer.model.Parent == a.folder, "renderer clones the actual imported template into its own folder")
		local count = 0
		for _, name in expected do
			local entry = renderer.parts[name]
			expect(entry and entry.part:IsA("MeshPart"), "imported mesh is present: " .. name)
			count += 1
		end
		local actualCount = 0
		for _ in renderer.parts do actualCount += 1 end
		expect(count == 9 and actualCount == 9, "exactly nine mesh parts animate")
		for _, entry in renderer.parts do
			expect(entry.part.Anchored and not entry.part.CanCollide and not entry.part.CanTouch and not entry.part.CanQuery,
				"presentation cannot collide or intercept input: " .. entry.part.Name)
		end
		expect(near(renderer:NozzlePosition(), renderer.rootCF:PointToWorldSpace(Config.NozzleOffset)),
			"rest nozzle matches the shared server pickup offset")
		for _, name in {"WheelLeft", "WheelRight"} do
			local source, rendered = template[name], renderer.parts[name]
			expect(math.abs(rendered.part.Size.Y / source.Size.Y - Config.WheelDiameterScale) < 0.001,
				"wheel diameter grows by the configured factor: " .. name)
			local rest = source:GetAttribute("RestCFrame")
			expect(math.abs((rendered.cf.Y - rendered.size.Y / 2) - (rest.Y - source.Size.Y / 2)) < 0.001,
				"larger wheel retains its original ground contact: " .. name)
		end

		local wheelBefore = renderer.wheelLeft
		a:Advance(0.2)
		renderer:Receive(snapshot({state = "Sweeping", z = 9994}), a.now)
		a:Advance(0.1)
		expect(renderer.rootCF.Z > 9994 and renderer.rootCF.Z < 10000, "march snapshot interpolates through the route instead of teleporting")
		a:Advance(0.1)
		expect(near(renderer.rootCF.Position, Vector3.new(10000, -500, 9994)), "interpolation reaches the authoritative target")
		expect(math.abs(renderer.wheelLeft - wheelBefore) > 0.01, "wheel angle changes when the rover travels")
		expect(math.abs(renderer.wheelLeft - renderer.wheelRight) < 0.0001, "both wheels cover equal distance on a straight row")

		local leftBefore, rightBefore = renderer.wheelLeft, renderer.wheelRight
		renderer:Receive(snapshot({state = "Sweeping", z = 9994, dx = 1, dz = 0}), a.now)
		a:Advance(0.2)
		local function signedAngle(value)
			return math.atan2(math.sin(value), math.cos(value))
		end
		local leftTurn = signedAngle(renderer.wheelLeft - leftBefore)
		local rightTurn = signedAngle(renderer.wheelRight - rightBefore)
		expect(math.abs(leftTurn) > 0.01 and leftTurn * rightTurn < 0, "turning in place rotates the wheels in opposite directions")
		local stoppedLeft, stoppedRight = renderer.wheelLeft, renderer.wheelRight
		renderer:Receive(snapshot({z = 9994, dx = 1, dz = 0}), a.now)
		a:Advance(0.4)
		expect(math.abs(renderer.wheelLeft - stoppedLeft) < 0.0001 and math.abs(renderer.wheelRight - stoppedRight) < 0.0001,
			"stationary wheels do not spin on a timer")

		renderer:Pickup({id = "pickup", count = 2, collector = "rover"}, a.now)
		a:Advance(0.25)
		expect(renderer.popup.Enabled and #a.sounds > 0 and a.sounds[#a.sounds].options.parent == renderer.anchor,
			"confirmed pickup feedback is localized to the vacuum")
		expect(not near(renderer.bodyPose.scale, Vector3.one), "authored suction creates a visible body squish")
		a.app.reducedMotion = true
		a:Advance(1 / 60)
		expect(sameFrame(renderer.bodyPose.cf, CFrame.identity) and near(renderer.bodyPose.scale, Vector3.one)
			and sameFrame(renderer.nozzlePose.cf, CFrame.identity) and near(renderer.nozzlePose.scale, Vector3.one),
			"reduced motion restores both animation groups to their rest pose")
		local body = renderer.parts.Body
		expect(near(body.part.Size, body.size) and sameFrame(renderer.rootCF:ToObjectSpace(body.part.CFrame), body.cf),
			"reduced motion also restores the actual body mesh size and transform")
		a.app.reducedMotion = false

		renderer:Receive(snapshot({state = "Unloading", z = 9994, dx = 1, dz = 0}), a.now)
		local enteredAt = renderer.unloadAt
		expect(renderer.unloadCycle == 1 and enteredAt == a.now, "unloading entry starts its predicted completion cycle")
		a:Advance(Config.UnloadSeconds / 2)
		renderer:Receive(snapshot({state = "Unloading", z = 9994, dx = 1, dz = 0}), a.now)
		expect(renderer.unloadAt == enteredAt, "repeated unloading snapshot does not restart the authored clip")
		a:Advance(Config.UnloadSeconds / 2)
		renderer:Receive(snapshot({z = 9994, dx = 1, dz = 0, unloadSerial = 1}), a.now)
		local receipt = {id = "delivery-1", value = 25, count = 2, collector = "rover"}
		renderer:Deposit(receipt, a.now)
		expect(renderer.unloadAt == enteredAt and renderer.unloadCycle == 1, "completion and payout share the entry clip without a second nod")
		local soundCount, popupUntil = #a.sounds, renderer.popupUntil
		renderer:Deposit(receipt, a.now + 0.05)
		expect(#a.sounds == soundCount and renderer.popupUntil == popupUntil and renderer.unloadAt == enteredAt,
			"duplicate payout receipt cannot replay sound, popup, or unload animation")
		a:Advance(0.2)
		expect(a.now - renderer.unloadAt > Config.UnloadSeconds and renderer.unloadCycle == 1,
			"one delivery finishes within its configured dock interval")

		renderer:Receive(snapshot({z = 9994, dx = 1, dz = 0, unloadSerial = 2}), a.now)
		local recoveredAt = renderer.unloadAt
		expect(recoveredAt == a.now and renderer.unloadCycle == 2, "completion serial recovers a missed unloading entry")
		renderer:Deposit({id = "delivery-2", value = 10, count = 1, collector = "rover"}, a.now + 0.05)
		expect(renderer.unloadAt == recoveredAt, "receipt does not restart a serial-recovered unload")

		local b = fixture()
		b.renderer:Receive(snapshot({id = "first-packet-after-delivery", unloadSerial = 3}), b.now)
		expect(b.renderer.unloadAt == nil, "initial serial alone does not replay a historical delivery")
		b.renderer:Deposit({id = "delivery-3", value = 12, count = 1, collector = "rover"}, b.now)
		expect(b.renderer.unloadCycle == 3 and b.renderer.unloadAt == b.now,
			"fresh payout receipt recovers a first-packet delivery")

		local oldModel, oldAnchor = renderer.model, renderer.anchor
		renderer:Clear()
		expect(oldModel.Parent == nil and oldAnchor.Parent == nil and next(renderer.parts) == nil,
			"Clear removes its model, pickup effects, and part references")
		expect(near(renderer:NozzlePosition({targetX = 4, targetY = 2, targetZ = -3}), Vector3.new(4, 2, -3)),
			"disabled rover pickups retain the server-provided nozzle fallback")
		expect(renderer:NozzlePosition() == nil, "cleared renderer cannot return a stale nozzle target")
		renderer:Destroy(); renderer:Destroy()
		expect(#a.folder:GetChildren() == 1 and a.folder:GetChildren()[1] == a.gui,
			"repeated Destroy is safe and leaves no renderer-owned instances")
		for _, saved in original do
			expect(saved.part.Parent == saved.parent and sameFrame(saved.part.CFrame, saved.cf) and near(saved.part.Size, saved.size),
				"source template remains untouched: " .. saved.part.Name)
		end
		return {passed = #checks, checks = checks, parts = actualCount, noLocalPlayer = true,
			noRealAudio = true, noLiveScriptEdits = true}
	end)
	for _, item in fixtures do pcall(function() item.renderer:Destroy() end) end
	container:Destroy()
	assert(ok, result)
	return result
end
