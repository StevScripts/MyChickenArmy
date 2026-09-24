--!strict
-- Real clients and real Humanoid movement. Fixtures exist only in the opt-in
-- acceptance server: never load, overwrite, or release a player's saved profile.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StudioTestService = game:GetService("StudioTestService")
local Shared = game.ReplicatedStorage.PetRoll.Shared
local Config = require(Shared.Config)
local Session = require(game.ServerStorage.PetRoll.PlayerSession)
local LiveAcceptance = {}

function LiveAcceptance.Run(server)
	assert(RunService:IsStudio() and workspace:GetAttribute("PetRollAcceptanceMode") == true, "Acceptance fixtures require the isolated Studio test mode")
	local wire = Instance.new("RemoteEvent")
	wire.Name, wire.Parent = "AcceptanceWire", game.ReplicatedStorage.PetRoll
	local reports, checks, timings = {}, {}, {}
	local started, finished, serial = os.clock(), false, 0
	local stage = "starting"
	local function finish(result)
		if finished then return end
		finished = true
		result.elapsedSeconds, result.stage, result.timings = os.clock() - started, stage, timings
		result.fixtureNotes = "Overpowered temporary squads and completed-Normal unlock fixture; no DataStore entries. Frame timings are observations on this test host, not a universal performance guarantee."
		StudioTestService:EndTest(result)
	end
	task.delay(360, function() finish({passed = false, error = "Acceptance watchdog expired", checks = checks, reports = reports}) end)
	wire.OnServerEvent:Connect(function(player, data)
		if type(data) == "table" and type(data.token) == "string" and #data.token < 80 then reports[tostring(player.UserId) .. ":" .. data.token] = data end
	end)
	local function waitFor(predicate, description, timeout)
		local deadline = os.clock() + (timeout or 10)
		repeat
			if finished then error("Acceptance already ended") end
			if predicate() then return end
			task.wait(0.05)
		until os.clock() >= deadline
		error("Timed out during " .. stage .. ": " .. description)
	end
	local function check(condition, description)
		assert(condition, description)
		table.insert(checks, description)
	end
	local function dispatch(player, action, payload)
		serial += 1
		local token = "Action" .. serial
		wire:FireClient(player, {kind = "Action", action = action, payload = payload or {}, token = token})
		return token
	end
	local function response(player, token)
		local key = tostring(player.UserId) .. ":" .. token
		waitFor(function() return reports[key] ~= nil end, "network response " .. token, 15)
		return reports[key].result
	end
	local function request(player, action, payload)
		return response(player, dispatch(player, action, payload))
	end
	local function probe(player, token)
		local key = tostring(player.UserId) .. ":" .. token
		wire:FireClient(player, {kind = "Probe", token = token})
		waitFor(function() return reports[key] ~= nil end, "client probe " .. token)
		return reports[key]
	end
	local function park(player, session)
		player.Character:PivotTo(server.world:PlotFrame(session.plotIndex) * CFrame.new(0, 4, 29))
	end
	local function sync(session)
		session:Touch();server.world:UpdateSession(session)
		local player = Players:GetPlayerByUserId(session.userId)
		if player then server:Send(player) end
	end
	local function fill(session, species, count, capacity)
		assert(session.armyState == "Home" and not session.outgoing and not session.incoming, "Fixture replacement requires a home squad")
		session.pets, session.slots, session.capacity = {}, {}, capacity
		for _ = 1, count do session:AddPet(species, 1) end
		session.coins = 50000
		session:RefreshArmy();sync(session)
	end
	local function unlockNormal(session)
		for i = 1, #Config.Camps do session.campaignWins[1][i] = true end
		if session.campaign == 1 then session.firstWins = session.campaignWins[1];session.campUnlocked = #Config.Camps end
		sync(session)
	end
	local function fingerprint(session)
		local ids = {}
		for id, pet in session.pets do table.insert(ids, id .. ":" .. pet.species) end
		table.sort(ids)
		return table.concat(ids, "|")
	end
	local function encounter(session)
		return server.battles.battles[session.outgoing]
	end
	local function guardRecord(session, index)
		return server.world.lanes[session.plotIndex][index]
	end
	local function occupiedBySquad(battle, position)
		for _, unit in battle.units do
			if unit.side == "A" then
				local actor = battle.actors and battle.actors.actors[unit.id]
				local at = actor and actor:Position() or Vector3.new(unit.x, 1, unit.z)
				local margin = Config.CampHalfSize + unit.size * 1.35 + 1
				if math.abs(at.X - position.X) <= margin and math.abs(at.Z - position.Z) <= margin then return true end
			end
		end
		return false
	end
	local function awaitVictory(session)
		waitFor(function() local battle = encounter(session);return battle and battle.phase ~= "Travel" end, "physical travel into camp", Config.TravelTimeout)
		waitFor(function()
			local battle = encounter(session)
			if not battle or battle.phase == "Returning" then error("Fixture squad failed to conquer; outcome " .. tostring(battle and battle.outcome)) end
			return battle.phase == "Holding"
		end, "camp victory", Config.FightTimeout + 3)
	end
	local function recall(players, sessions, campIndex)
		local tracks = {}
		for index, session in sessions do
			local battle = encounter(session)
			assert(battle and battle.phase == "Holding", "Recall starts from a held camp")
			tracks[index] = {battle = battle, moved = false, sawOccupied = false, arrived = false}
			local record = guardRecord(session, campIndex)
			check(record.busy and #record.defenders:GetChildren() == 0, "Plot " .. session.plotIndex .. " has no respawned guards while holding camp " .. campIndex)
		end
		-- Observe real actors on their final approach. The extra half stud covers one render/physics sample before the two-stud server arrival boundary.
		local observation = RunService.Heartbeat:Connect(function()
			for index, track in tracks do
				local session, battle = sessions[index], track.battle
				if not battle.actors or not battle.actors.folder.Parent then continue end
				local occupied = occupiedBySquad(battle, server.world:CampPosition(campIndex, session.plotIndex))
				local record = guardRecord(session, campIndex)
				if occupied then
					track.sawOccupied = true
					if #record.defenders:GetChildren() > 0 then track.earlyRespawn = true end
				else track.moved = true end
				local near, total = 0, 0
				for _, unit in battle.units do
					if unit.side == "A" then
						local actor = battle.actors.actors[unit.id]
						if actor then
							local at = actor:Position()
							if Vector2.new(at.X - unit.homeX, at.Z - unit.homeZ).Magnitude <= 2.5 then near += 1 end
							total += 1
						end
					end
				end
				if total > 0 and near == total then track.arrived = true end
			end
		end)
		local ok, why = xpcall(function()
			for index, player in players do assert(request(player, "ReturnHome").ok, "Network recall accepted for player " .. index) end
			waitFor(function()
				for _, session in sessions do if session.armyState ~= "Home" then return false end end
				return true
			end, "real squad arrival at deployment pads", Config.ReturnTimeout)
		end, debug.traceback)
		observation:Disconnect()
		assert(ok, why)
		for index, track in tracks do
			local session = sessions[index]
			check(track.sawOccupied and not track.earlyRespawn and track.moved, "Plot " .. session.plotIndex .. " guards wait for the physical army to leave")
			check(track.arrived, "Plot " .. session.plotIndex .. " return ends after actual Humanoids reach home pads")
			local record = guardRecord(session, campIndex)
			check(not record.busy and #record.defenders:GetChildren() > 0, "Plot " .. session.plotIndex .. " camp guards return after departure")
		end
	end

	local ok, why = xpcall(function()
		stage = "client readiness and safe fixtures"
		waitFor(function() return #Players:GetPlayers() == 2 end, "two actual clients", 25)
		local players = Players:GetPlayers()
		table.sort(players, function(a, b) return a.UserId < b.UserId end)
		local a, b = players[1], players[2]
		waitFor(function() return reports[tostring(a.UserId) .. ":Ready"] and reports[tostring(b.UserId) .. ":Ready"] end, "client interfaces", 25)
		waitFor(function()
			for _, player in players do if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") or not server.sessions[player.UserId] then return false end end
			return true
		end, "character roots and sessions", 20)
		task.wait(0.5)
		local sa, sb = server.sessions[a.UserId], server.sessions[b.UserId]
		check(sa.plotIndex ~= sb.plotIndex, "Two connected clients receive separate pond plots")
		check(next(server.data.entries) == nil and sa.saveStatus == "studio-session" and sb.saveStatus == "studio-session", "Acceptance uses no saved player profiles")
		local readyA, readyB = probe(a, "Initial"), probe(b, "Initial")
		check(readyA.gui and readyB.gui and readyA.camera == "Custom" and readyB.camera == "Custom", "Both clients have their UI and the default Roblox camera")
		check(sa.capacity == 4 and sb.capacity == 4, "Fresh players start with four active slots")
		stage = "network purchase, collection and rejected legacy actions"
		local initialIds, first = fingerprint(sa), sa.slots[1]
		a.Character:PivotTo(CFrame.new(server.world.plots[sa.plotIndex].station.leverBase.Position + Vector3.new(0, 3, 4)))
		task.wait(0.2)
		check(request(a, "Buy", {offerId = sa.offer.id, stationIndex = sa.plotIndex}).ok and sa:Count() == 3, "Physical-podium purchase crosses the real client network")
		check(fingerprint(sa) ~= initialIds and #sa:Lineup() == 3, "Bought duck automatically fills an available active slot")
		check(not request(b, "Place", {petId = first, slot = 3}).ok and sb:Count() == 2, "Manual and cross-client pet placement is rejected")
		check(not request(a, "Merge", {firstId = first, secondId = sa.slots[3]}).ok and sa:Count() == 3, "Merging requires the player’s stand and an exact matching pair")
		park(a, sa);sa:AccrueIncome(10);sync(sa)
		local cash = sa.pets[first].cash
		b.Character:PivotTo(CFrame.new(server.world:PetPosition(sa.plotIndex, first) + Vector3.new(0, 3, 0)))
		task.wait(0.4)
		check(sa.pets[first].cash >= cash, "Visitors cannot collect another player's duck cash")
		a.Character:PivotTo(CFrame.new(server.world:PetPosition(sa.plotIndex, first) + Vector3.new(0, 3, 0)))
		waitFor(function() return sa.passiveEarned > 0 end, "owner's physical cash pickup")
		check(sa.tutorial.collected, "Walking near an owned duck collects its cash and advances onboarding")
		park(a, sa);park(b, sb)
		fill(sa, "StormDuck", 6, 4);fill(sb, "StormDuck", 6, 4)
		check(not request(a, "Campaign", {campaign = 2}).ok and sa.campaign == 1, "Veteran is locked until Normal is conquered")
		check(not request(a, "Expand").ok and sa.capacity == 4, "Coins cannot bypass an active-slot conquest requirement")

		stage = "two independent same-tier NPC encounters"
		local earnedA, earnedB = sa.battleEarned, sb.battleEarned
		local ta, tb = dispatch(a, "Attack", {targetId = "camp:1"}), dispatch(b, "Attack", {targetId = "camp:1"})
		check(response(a, ta).ok and response(b, tb).ok, "Both clients can attack camp one at the same time")
		local ba, bb = encounter(sa), encounter(sb)
		check(ba and bb and ba.id ~= bb.id and ba.campKey ~= bb.campKey, "Concurrent NPC fights have distinct personal encounters and reservations")
		check(#sa:HomePets() == 2 and #sb:HomePets() == 2, "Only four fighters leave; two spare ducks remain at each pond")
		task.wait(0.8)
		local networkA, networkB = probe(a, "ConcurrentCamps"), probe(b, "ConcurrentCamps")
		check(networkA.battleId == ba.id and networkB.battleId == bb.id and networkA.battleUnits == #ba.units and networkB.battleUnits == #bb.units, "Each client receives its own complete squad encounter")
		check(networkA.actualBattleModels == networkA.battleUnits and networkB.actualBattleModels == networkB.battleUnits and networkA.localCombatCopies == 0 and networkB.localCombatCopies == 0, "Combat renders the actual server Humanoids without duplicate local ducks")
		awaitVictory(sa);awaitVictory(sb)
		check(sa.battleEarned - earnedA == Config.Camps[1].reward + Config.Camps[1].bonus and sb.battleEarned - earnedB == Config.Camps[1].reward + Config.Camps[1].bonus, "Each player's first conquest pays its own first-clear bonus")
		task.wait(0.8)
		recall({a, b}, {sa, sb}, 1)
		check(request(a, "Expand").ok and sa.capacity == 5 and #sa:Lineup() == 5, "Conquest unlocks a fifth active slot that equips the next best duck")

		stage = "campaign preservation and cross-difficulty camps"
		unlockNormal(sb)
		local saved = {pets = fingerprint(sb), coins = sb.coins, capacity = sb.capacity, income = sb.incomeLevel}
		check(request(b, "Campaign", {campaign = 2}).ok and sb.campaign == 2, "Unlocked Veteran is selected through the real client network")
		check(fingerprint(sb) == saved.pets and sb.coins == saved.coins and sb.capacity == saved.capacity and sb.incomeLevel == saved.income and sb.campaignWins[1][#Config.Camps], "Switching campaign preserves ducks, coins, upgrades and earlier clears")
		earnedA = sa.battleEarned
		ta, tb = dispatch(a, "Attack", {targetId = "camp:1"}), dispatch(b, "Attack", {targetId = "camp:1"})
		check(response(a, ta).ok and response(b, tb).ok, "Normal and Veteran players fight the same camp tier concurrently")
		ba, bb = encounter(sa), encounter(sb)
		check(ba.campaign == 1 and bb.campaign == 2 and ba:Alive("B") == #Config.Campaigns[1].camps[1].roster and bb:Alive("B") == #Config.Campaigns[2].camps[1].roster, "Each personal encounter uses the selected campaign's own defenders")
		awaitVictory(sa);awaitVictory(sb)
		check(sa.battleEarned - earnedA == Config.Camps[1].reward, "Replaying a conquered camp pays the base reward without a second first-clear bonus")
		recall({a, b}, {sa, sb}, 1)

		stage = "ordered physical conquest"
		check(request(a, "Attack", {targetId = "camp:3"}).ok and encounter(sa).campIndex == 2, "Clicking two camps ahead begins at the first unconquered camp")
		waitFor(function()
			if sa.firstWins[3] then assert(sa.firstWins[2], "Camp three cleared before its prerequisite") end
			return sa.firstWins[3] and sa.armyState == "Deployed"
		end, "two ordered physical camp fights", 95)
		check(sa.firstWins[2] and sa.firstWins[3] and encounter(sa).campIndex == 3, "One order clears the earlier camp and keeps the army at the requested camp")
		recall({a}, {sa}, 3)

		stage = "unilateral PvP and one attacker per base"
		local used = {};for _, session in server.sessions do used[session.plotIndex] = true end
		local targetPlot
		for i = 1, #Config.PlotPositions do if not used[i] then targetPlot = i;break end end
		local target = Session.new(-81000, "Acceptance Raid Target", targetPlot)
		target.loaded, target.saveStatus = true, "studio-session"
		server.sessions[target.userId] = target
		fill(target, "Duck", 2, 4)
		local targetMoney, targetPets = target.coins, fingerprint(target)
		local aMoney, bMoney = sa.coins, sb.coins
		ta, tb = dispatch(a, "Attack", {targetId = "base:" .. target.userId}), dispatch(b, "Attack", {targetId = "base:" .. target.userId})
		local ra, rb = response(a, ta), response(b, tb)
		check(ra.ok ~= rb.ok, "Two actual clients race one base and exactly one attack is accepted")
		local winner, loser = if ra.ok then sa else sb, if ra.ok then sb else sa
		local raid = encounter(winner)
		check(target.incoming == raid.id and target.armyState == "Defending" and loser.outgoing == nil, "An unrestricted raid reserves exactly one defended base")
		local reward = raid.reward
		waitFor(function() return raid.phase ~= "Travel" end, "physical travel to another base", Config.TravelTimeout)
		waitFor(function() return raid.paid end, "PvP result", Config.FightTimeout + 3)
		check(raid.outcome == "A" and target.coins == targetMoney and fingerprint(target) == targetPets, "Defeat preserves the defender's coins and ducks")
		check(sa.coins + sb.coins - aMoney - bMoney == reward, "Exactly one winner receives newly generated raid coins")
		waitFor(function() return winner.armyState == "Home" and target.armyState == "Home" end, "physical raid return and defender recovery", Config.ReturnTimeout)
		local cooldownReward
		for _, entry in server.battles:Targets(winner, os.clock()) do if entry.id == "base:" .. target.userId then cooldownReward = entry.reward end end
		check(cooldownReward == 0, "The recently raided opponent gives no immediate repeat reward")

		stage = "disconnect cleanup"
		check(request(b, "Attack", {targetId = "base:" .. a.UserId}).ok and sa.armyState == "Defending", "A player base can be raided without its owner's permission")
		local remainingPets = fingerprint(sa)
		wire:FireClient(b, {kind = "Leave", token = "Leaving"})
		waitFor(function() return Players:GetPlayerByUserId(b.UserId) == nil and server.sessions[b.UserId] == nil end, "departing real client", 15)
		waitFor(function() return sa.armyState == "Home" and sa.incoming == nil end, "defender recovery after attacker disconnect", 12)
		check(next(server.battles.battles) == nil and next(server.battles.campBusy) == nil and fingerprint(sa) == remainingPets, "Disconnect removes encounters and reservations while preserving the remaining flock")

		stage = "six full ponds and frame observations"
		used = {};for _, session in server.sessions do used[session.plotIndex] = session end
		for i = 1, #Config.PlotPositions do
			local session = used[i]
			if not session then session = Session.new(-82000 - i, "Acceptance Pond " .. i, i);server.sessions[session.userId] = session end
			session.loaded, session.saveStatus = true, "studio-session"
			-- The heaviest native duck recipe and the largest guard campaign are
			-- intentional worst-case fixtures, not claims about a typical starter pond.
			fill(session, "Knight", Config.CollectionLimit, Config.MaxSlots)
			for campaignIndex = 1, 2 do
				for campIndex = 1, #Config.Camps do session.campaignWins[campaignIndex][campIndex] = true end
			end
			session.campaign, session.firstWins = 3, session.campaignWins[3]
			session.firstWins[1], session.firstWins[2], session.campUnlocked = true, true, 3
			sync(session)
		end
		park(a, sa)
		local beforePositions = {}
		for id, actor in server.world.plots[sa.plotIndex].actors do beforePositions[id] = actor:Position() end
		task.wait(4)
		local moved = 0
		for id, actor in server.world.plots[sa.plotIndex].actors do if (actor:Position() - beforePositions[id]).Magnitude > 0.25 then moved += 1 end end
		check(moved > 0, "Pond ducks physically waddle under Humanoid movement during the load test")
		wire:FireClient(a, {kind = "FramesReset"});wire:FireClient(a, {kind = "OpenCollection"})
		task.wait(5)
		local collection = probe(a, "FullCollection")
		wire:FireClient(a, {kind = "CloseCollection"});wire:FireClient(a, {kind = "FramesReset"})
		task.wait(7)
		local load = probe(a, "SixFullPonds")
		local homes, humanoids, guards, totalRigs, lowestFootY = 0, 0, 0, 0, math.huge
		for _, plot in server.world.plots do
			homes += #plot.pets:GetChildren()
			for id, actor in plot.actors do
				local model, at = actor.model, actor:Position()
				lowestFootY = math.min(lowestFootY, at.Y)
				if model:FindFirstChildOfClass("Humanoid") then humanoids += 1 end
				assert(model.PrimaryPart and not model.PrimaryPart.Anchored and at.X == at.X and at.Y > -2, "Invalid or anchored moving home rig")
				local reported = server.world:PetPosition(plot.index, id)
				assert((reported - at).Magnitude < 0.01, "Cash collector diverged from its actual Humanoid")
			end
		end
		local expectedGuards = 0
		for _, camp in Config.Campaigns[3].camps do expectedGuards += #camp.roster * #Config.PlotPositions end
		for _, lane in server.world.lanes do
			for _, record in lane do
				for _, actor in record.actors do
					guards += 1
					lowestFootY = math.min(lowestFootY, actor:Position().Y)
					assert(actor.model:FindFirstChildOfClass("Humanoid"), "Elite guard is missing its Humanoid")
				end
			end
		end
		for _, item in server.world.root:GetDescendants() do
			if item:IsA("Model") and item:GetAttribute("DuckRig") and item:FindFirstChildOfClass("Humanoid") then totalRigs += 1 end
		end
		local memoryOk, memoryMb = pcall(function() return game:GetService("Stats"):GetTotalMemoryUsageMb() end)
		reports.WorstCaseServer = {homeHumanoids = humanoids, eliteGuards = guards, totalRigHumanoids = totalRigs,
			lowestFootY = lowestFootY, recipe = "Knight", campaign = "Elite", memoryMb = if memoryOk then memoryMb else nil,
			memoryAvailable = memoryOk}
		check(homes == #Config.PlotPositions * Config.CollectionLimit and humanoids == homes, "All 360 Knight home ducks are real unanchored Humanoids with matching cash positions")
		check(guards == expectedGuards and totalRigs == homes + guards, "Worst-case load contains every Elite guard alongside all 360 Knight home ducks")
		check(lowestFootY > -2, "All home and Elite guard rig feet remain above the island floor cutoff")
		check(load.foreignPrompts >= (#Config.PlotPositions - 1) * 3 and load.visibleForeign == 0, "Foreign roller and campaign prompts stay hidden across six full ponds")
		check(collection.frameSamples > 20 and load.frameSamples > 20, "Collection-open and world-only frame probes captured usable samples")
		check(next(server.data.entries) == nil, "The complete acceptance run created no DataStore profile entries")
		timings.total = os.clock() - started
		finish({passed = true, checks = checks, reports = reports, players = {a.Name, b.Name}})
	end, debug.traceback)
	if not ok then finish({passed = false, error = tostring(why), checks = checks, reports = reports}) end
end

return LiveAcceptance
