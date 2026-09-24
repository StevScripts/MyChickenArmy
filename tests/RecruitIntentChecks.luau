-- Controller-method fixtures; no player profiles, remotes or world mutations.
-- Inject the actual AppController module from a client test context.
local Checks = {}

function Checks.Run(Controller)
	assert(Controller and Controller.TrackRecruit and Controller.ObserveRecruitUnit, "Inject AppController")
	local results = {}
	local function test(name, fn)
		local ok, detail = pcall(fn)
		table.insert(results, {name = name, passed = ok, detail = tostring(detail)})
	end
	local function fixture(assignment, deferred)
		local pet = {id = "new-pet", species = "Duck", income = 4, selected = assignment ~= "Reserve", home = true}
		local model = {PrimaryPart = {Position = {X = 0, Z = 0}}, IsA = function(_, name) return name == "Model" end}
		local app = setmetatable({recruitIntents = {}, recruitReceipts = {}, pulses = 0, notices = 0, sounds = 0,
			state = {userId = 11, armyState = if deferred then "Deployed" else "Home", outgoing = if deferred then "same-id" else nil, pets = {pet}},
			battle = {snapshots = {{id = "same-id", rosterLocked = false, phase = "Travel"}}}}, {__index = Controller})
		function app:Notify() self.notices += 1 end
		function app:IsSelected(value) return value.selected end
		app.audio = {Play = function() app.sounds += 1 end}
		app.base = {HomePet = function() return model end, PulseModel = function() app.pulses += 1 end}
		local result = {petId = pet.id, recruit = {assignment = assignment, selectedBefore = 3, selectedAfter = 3,
			pendingBattleId = if deferred then "same-id" else nil, deferredUntilContestEnds = deferred}}
		app:TrackRecruit(result)
		return app, pet, model, result
	end
	local function encounter(pet, id, impact)
		return {id = id, attacker = 11, phase = "Fight", x = 0, z = 0, captureRadius = 12},
			{petId = pet.id, side = "A", hp = 42, x = 0, z = 0, impactSerial = impact or 0}
	end
	test("Buy-before-expand reserve survives home acknowledgement and later contributes", function()
		local app, pet, model = fixture("Reserve", false)
		app:StepRecruitFeedback()
		local intent = app.recruitIntents[pet.id]
		assert(intent and intent.homeAcknowledged and app.pulses == 1)
		app:StepRecruitFeedback();assert(app.pulses == 1)
		pet.selected, pet.home = true, false
		app.state.outgoing, app.state.armyState = "first-deploy", "Deployed"
		local battle, unit = encounter(pet, "first-deploy")
		app:ObserveRecruitUnit(battle, unit, model)
		assert(intent.arrivalAcknowledged and intent.selectedOnce)
		unit.impactSerial = 1
		app:ObserveRecruitUnit(battle, unit, model)
		assert(intent.contributionAcknowledged and not app.recruitIntents[pet.id])
		return "Reserve purchase becomes a real fighter after capacity grows"
	end)
	test("Cached unlocked NPC approach cannot release a later Buy lock", function()
		local app, pet = fixture("Replacement", true)
		app:StepRecruitFeedback()
		local intent = app.recruitIntents[pet.id]
		assert(intent.deferred and not intent.homeAcknowledged and app.pulses == 0)
		app.battle.snapshots = {{id = "same-id", rosterLocked = false, phase = "Holding"}}
		app:StepRecruitFeedback();assert(intent.deferred and app.pulses == 0)
		app.state.outgoing, app.state.armyState = nil, "Home"
		app:StepRecruitFeedback()
		assert(not intent.deferred and intent.homeAcknowledged and app.pulses == 1)
		return "Only the confirmed home transition releases this deferred home acknowledgement"
	end)
	test("Same-ID successor can acknowledge its actual new unit after unlock", function()
		local app, pet, model = fixture("Replacement", true)
		pet.home = false
		local battle, unit = encounter(pet, "same-id", 1)
		battle.rosterLocked = true
		app:ObserveRecruitUnit(battle, unit, model)
		assert(app.recruitIntents[pet.id].deferred and app.pulses == 0)
		battle.rosterLocked, battle.phase = false, "Holding"
		local intent = app.recruitIntents[pet.id]
		app:ObserveRecruitUnit(battle, unit, model)
		assert(not intent.deferred and intent.arrivalAcknowledged and intent.contributionAcknowledged)
		return "Real new-pet presence provides causal evidence without changing encounter ID"
	end)
	test("Late model with an existing hit acknowledges once without an impact sound", function()
		local app, pet, model, result = fixture("Added", false)
		pet.home = false
		app.state.outgoing, app.state.armyState = "battle", "Deployed"
		local battle, unit = encounter(pet, "battle", 1)
		app:ObserveRecruitUnit(battle, unit, nil)
		assert(app.recruitIntents[pet.id] and app.pulses == 0)
		app:ObserveRecruitUnit(battle, unit, model)
		local pulses, notices, sounds = app.pulses, app.notices, app.sounds
		app:ObserveRecruitUnit(battle, unit, model);app:TrackRecruit(result)
		assert(app.pulses == pulses and app.notices == notices and app.sounds == sounds and sounds == 1)
		return "No historical hit sound or repeated purchase/arrival celebration"
	end)
	test("Reserve history is bounded and superseded selected recruits are discarded", function()
		local app, pet = fixture("Reserve", false)
		app:StepRecruitFeedback();assert(app.recruitIntents[pet.id])
		pet.selected = true;app:StepRecruitFeedback()
		pet.selected = false;app:StepRecruitFeedback();assert(not app.recruitIntents[pet.id])
		local expired, expiredPet = fixture("Reserve", false)
		expired.recruitIntents[expiredPet.id].expiresAt = 0
		expired:StepRecruitFeedback();assert(not expired.recruitIntents[expiredPet.id])
		return "Selection supersession and expiry both clear retained intent"
	end)
	return results
end

return Checks
