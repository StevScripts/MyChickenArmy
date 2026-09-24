--!strict
-- Temporary focused smoke check; no real players, live map edits or DataStore calls.
-- Run this ModuleScript's returned function in Studio after syncing the server code.
-- Optional module overrides let the integrator test fresh clones without require caches.
return function(EggServiceOverride, EggRoverOverride)
	local Server = game:GetService("ServerStorage").PetRoll
	local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
	local Eggs = EggServiceOverride or require(Server.EggService)
	local Rover = EggRoverOverride or require(Server.EggRover)
	local Config = require(Shared.VacuumConfig)
	local Layout = require(Shared.HomePlotLayout)
	local testPlotIndex = 900997
	assert(workspace:GetAttribute(Config.StudioTestAttribute) ~= true,
		"Disable TestEggVacuum before running the entitlement-toggle fixture")
	local fixtures, checks = {}, {}
	local function expect(condition, description)
		assert(condition, description)
		table.insert(checks, description)
	end
	local function fixture(offsetFrame)
		local frame = offsetFrame or CFrame.identity
		local session = {userId = -900001 - #fixtures, plotIndex = 1, pets = {}, loaded = true,
			coins = 0, revision = 0, tutorial = {}, eggCarry = {count = 0, value = 0},
			entitlements = {}, automatic = true, creditCount = 0, multiplier = 2}
		function session:AutomaticEnabled(key) return key == "AutoCollectEggs" and self.automatic end
		function session:EarnedAmount(amount, source) return amount * (if source == "eggs" then self.multiplier else 1) end
		function session:Touch() self.revision += 1 end
		function session:Credit(amount, source)
			local credited = self:EarnedAmount(amount, source)
			self.coins += credited; self.creditCount += 1; self:Touch()
			return credited
		end
		local pad = Instance.new("Part")
		pad.Anchored = true; pad.Size = Vector3.new(7.3505, 1.1121, 3.4914)
		pad.CFrame = frame * CFrame.new(-23.2188, 0.2406, -8.6553) * CFrame.Angles(0, math.pi / 2, 0)
		local world = {ownerId = session.userId, pad = pad}
		function world:PlotFrame(_index) return frame end
		function world:EggDeposit(_index) return self.pad, self.ownerId end
		local service = Eggs.new(world)
		local yard = service:Yard(session)
		service:UpdateRover(session, yard, 0.1, 0)
		local item = {session = session, service = service, yard = yard, world = world, pad = pad, frame = frame}
		table.insert(fixtures, item)
		return item
	end
	local function drop(f, id, value, count, position)
		local at = position or f.yard.rover:Nozzle()
		local valueDrop = {id = id, value = value, stack = count, x = at.X, y = at.Y - 0.8, z = at.Z,
			originX = at.X, originY = at.Y, originZ = at.Z, born = 0, readyAt = 0}
		table.insert(f.yard.drops, valueDrop)
		return valueDrop
	end
	local ok, result = pcall(function()
		local a = fixture()
		local claimed = drop(a, "exclusive", 37, 3)
		expect(a.service:Claim(a.yard, claimed, 0, "rover", a.yard.rover:Nozzle()), "rover owns first claim")
		expect(not a.service:Claim(a.yard, claimed, 0, "player", Vector3.zero), "manual pickup cannot steal a rover claim")
		a.service:SettleClaims(a.session, a.yard, 1, false)
		expect(a.session.coins == 0 and a.session.eggCarry.value == 0
			and a.yard.rover.cargoValue == 37 and a.yard.rover.cargoCount == 3, "pickup remains raw cargo until dock")
		a.service:Pay(a.session, a.yard, claimed, 1)
		expect(a.yard.rover.cargoValue == 37 and #a.yard.receipts == 1, "settled drop cannot pay a second time")
		local robot = a.yard.rover
		robot.state = "Unloading"; robot.position = robot.dock; robot.unloadAt = 0
		a.service:UpdateRover(a.session, a.yard, 0.1, 2)
		expect(a.session.coins == 74 and a.session.creditCount == 1 and robot.cargoValue == 0,
			"owned dock credits the egg multiplier exactly once")
		a.service:UpdateRover(a.session, a.yard, 0.1, 3)
		expect(a.session.coins == 74 and a.session.creditCount == 1, "repeated dock overlap cannot pay again")
		expect(a.yard.deposit.collector == "rover" and a.yard.deposit.targetX ~= nil, "deposit feedback identifies the rover")

		local b = fixture()
		local settled = drop(b, "settled-before-toggle", 10, 2)
		b.service:Claim(b.yard, settled, 0, "rover", b.yard.rover:Nozzle())
		b.service:SettleClaims(b.session, b.yard, 1, false)
		local flying = drop(b, "flying-at-toggle", 20, 4)
		b.service:Claim(b.yard, flying, 100, "rover", b.yard.rover:Nozzle())
		b.session.automatic = false
		b.service:UpdateRover(b.session, b.yard, 0.1, 1.1)
		expect(not b.yard.rover.enabled and b.session.eggCarry.value == 30 and b.session.eggCarry.count == 6
			and #b.yard.drops == 0 and b.session.coins == 0, "toggle preserves settled and in-flight cargo in the saved egg bag")
		b.service:UpdateRover(b.session, b.yard, 0.1, 1.2)
		expect(b.session.eggCarry.value == 30 and b.session.eggCarry.count == 6, "repeated disabled update cannot duplicate cargo")

		local c = fixture()
		local carried = drop(c, "cargo-before-leave", 11, 1)
		c.service:Claim(c.yard, carried, 0, "rover", c.yard.rover:Nozzle())
		c.service:SettleClaims(c.session, c.yard, 1, false)
		local pending = drop(c, "rover-flight-at-leave", 23, 2)
		c.service:Claim(c.yard, pending, 100, "rover", c.yard.rover:Nozzle())
		local manual = drop(c, "manual-flight-at-leave", 17, 3)
		c.service:Claim(c.yard, manual, 100, "player", Vector3.zero)
		c.service:Release(c.session)
		expect(c.session.eggCarry.value == 51 and c.session.eggCarry.count == 6 and c.session.coins == 0
			and #c.yard.drops == 0, "disconnect settles both collectors once before transferring cargo")
		c.service:Release(c.session)
		expect(c.session.eggCarry.value == 51 and c.session.eggCarry.count == 6, "second Release does not duplicate value")

		local d = fixture()
		d.yard.rover.state = "Unloading"; d.yard.rover.position = d.yard.rover.dock
		d.yard.rover.unloadAt = 0; d.yard.rover.cargoValue = 9; d.yard.rover.cargoCount = 1
		d.world.ownerId = 12345
		d.service:UpdateRover(d.session, d.yard, 0.1, 2)
		expect(d.session.coins == 0 and d.session.eggCarry.value == 9 and not d.yard.rover.enabled,
			"changed plot owner prevents stand payment and preserves the original owner's eggs")

		local e = fixture()
		local waiting = drop(e, "pending-before-unload", 15, 1)
		e.service:Claim(e.yard, waiting, 100, "rover", e.yard.rover:Nozzle())
		e.yard.rover.state = "Unloading"; e.yard.rover.position = e.yard.rover.dock; e.yard.rover.unloadAt = 0
		e.service:UpdateRover(e.session, e.yard, 0.1, 1)
		expect(e.session.coins == 0 and e.yard.rover.state == "Unloading", "unloading waits for in-flight claims")
		e.service:SettleClaims(e.session, e.yard, 101, false)
		e.service:UpdateRover(e.session, e.yard, 0.1, 101)
		expect(e.session.coins == 30 and e.session.creditCount == 1, "last flight can finish and unload once")

		local f = fixture(CFrame.new(250, 4, -300) * CFrame.Angles(0, math.rad(67), 0))
		local routeRobot = Rover.new("route-check", f.frame, 1, f.pad, 0)
		expect(Config.PassCount == 4 and #routeRobot.rows == 8, "route contains exactly four parallel passes")
		local layout = Layout.ForPlot(1)
		local stripWidth = (layout.YardMaxX - layout.YardMinX) / 4
		local previousDirection = nil
		for pass = 1, 4 do
			local first = f.frame:PointToObjectSpace(routeRobot.rows[pass * 2 - 1])
			local last = f.frame:PointToObjectSpace(routeRobot.rows[pass * 2])
			local expectedX = layout.YardMinX + (pass - 0.5) * stripWidth
			expect(math.abs(first.X - expectedX) < 0.001 and math.abs(last.X - expectedX) < 0.001
				and math.abs(first.Z - last.Z) > 0.1, "pass " .. pass .. " is straight and centered in its strip")
			local direction = math.sign(last.Z - first.Z)
			if previousDirection then expect(direction == -previousDirection, "pass " .. pass .. " reverses direction") end
			previousDirection = direction
		end
		expect(routeRobot.suctionRadius >= math.sqrt((stripWidth / 2 + Config.SuctionEdgePadding)^2
			+ (0.8 - Config.NozzleOffset.Y)^2), "rover intake covers strip edges including egg height")
		-- A huge ledger must never send the rover back halfway through a sweep.
		routeRobot.cargoCount, routeRobot.cargoValue = 5000, 1234
		local reached, states = {}, {}
		local completedAt = nil
		local travelDistance = 0
		for tick = 1, 2000 do
			local now = tick * 0.1
			local previous = routeRobot.position
			routeRobot:Step(0.1, now, true)
			travelDistance += (routeRobot.position - previous).Magnitude
			states[routeRobot.state] = true
			for index, point in routeRobot.rows do
				if (routeRobot.position - point).Magnitude < 0.09 then reached[index] = true end
			end
			if routeRobot:ReadyToUnload(now) then completedAt = now; break end
		end
		expect(completedAt ~= nil and states.Sweeping and states.Returning and states.Unloading,
			"full rotated-plot row sweep reaches the dock without stalling")
		local reachedCount = 0
		for _ in reached do reachedCount += 1 end
		expect(reachedCount == #routeRobot.rows, "sweep visits every row endpoint")
		expect((routeRobot.position - routeRobot.dock).Magnitude < 0.09 and travelDistance > 100,
			"rover travels the route rather than teleporting to the dock")
		expect(routeRobot.cargoCount == 5000 and routeRobot.cargoValue == 1234,
			"large cargo finishes all four passes without capacity detours")
		f.yard.rover = routeRobot
		f.service:UpdateRover(f.session, f.yard, 0.1, completedAt)
		expect(routeRobot.state == "Idle" and routeRobot.unloadSerial == 1 and f.session.creditCount == 1
			and f.session.coins == 2468 and routeRobot.cargoCount == 0, "four-pass trip deposits the entire ledger once")
		f.service:UpdateRover(f.session, f.yard, 0.1, completedAt + 0.1)
		expect(f.session.creditCount == 1, "finished trip does not repeat its deposit")
		routeRobot:BeginSweep()
		expect(routeRobot.waypoint == 1 and routeRobot.route[routeRobot.collectFrom] == routeRobot.rows[1],
			"next sweep restarts the same four-pass route")

		Layout.SetYard(testPlotIndex, {YardMinX = -20, YardMaxX = 20, YardMinZ = -14,
			YardMaxZ = 14, FootY = 0.193})
		local wide = Rover.new("expanded-yard", CFrame.identity, testPlotIndex, fixtures[1].pad, 0)
		expect(#wide.rows == 8 and wide.suctionRadius >= math.sqrt((5 + Config.SuctionEdgePadding)^2
			+ (0.8 - Config.NozzleOffset.Y)^2), "expanded yard retains four passes with full-width intake")
		Layout.SetYard(testPlotIndex, nil)

		local g = fixture()
		local snapshotBefore = g.service:Snapshot(g.session, 0)
		g.yard.rover:BeginSweep(); g.yard.rover:Move(0.1)
		local snapshotAfter = g.service:Snapshot(g.session, 0.1)
		expect(snapshotBefore.revision == snapshotAfter.revision and snapshotBefore.rover.state == "Idle"
			and snapshotAfter.rover.state == "Sweeping", "snapshot includes new rover phases without an egg ledger revision")
		return {passed = #checks, checks = checks, fullSweepSeconds = completedAt,
			rowEndpoints = reachedCount, travelStuds = math.floor(travelDistance * 100) / 100,
			noDataStoreCalls = true}
	end)
	Layout.SetYard(testPlotIndex, nil)
	for _, item in fixtures do item.service:Destroy(); item.pad:Destroy() end
	assert(ok, result)
	return result
end
