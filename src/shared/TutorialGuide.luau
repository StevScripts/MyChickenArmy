--!strict
-- Snapshot-only guidance. Never changes prices, eligibility or player actions.
local Guide = {}
Guide.Version = "cluck-5-forty-eggs"
Guide.EggGoal = 40
Guide.Milestones = {"Collect", "Sell", "Roll", "Recruit", "Grow", "Expand", "Select", "Deploy", "Win"}

function Guide.CollectedEggCount(tutorial)
	local count = tutorial.collectedEggCount
	if type(count)=="number" and count==count and count<math.huge then
		return math.clamp(math.floor(count), 0, Guide.EggGoal)
	end
	-- Boolean-only snapshots retain their earned lesson. New profiles always
	-- carry a numeric count, so an early sale or a nonempty bag cannot bypass it.
	return if count==nil and (tutorial.collectedEggs==true or tutorial.guideCompleted==true) then Guide.EggGoal else 0
end

function Guide.Facts(state)
	local t = state.tutorial or {}
	local won = t.wonCamp == true or (state.campsWon or 0) > 0 or state.kingCleared == true
	for _, value in state.firstWins or {} do if value then won = true end end
	return {
		Roll = t.rolled == true,
		-- The free squad must not count as completing the recruit lesson.
		Recruit = if t.starterArmy then t.bought == true
			else t.bought == true or #(state.pets or {}) >= (if t.emptyStart then 1 else 4),
		Collect = Guide.CollectedEggCount(t) >= Guide.EggGoal,
		Sell = t.soldEggs == true,
		Grow = #(state.pets or {}) >= 4,
		Expand = (state.capacity or 3) >= 4,
		Select = (state.selectedCount or #(state.selectedIds or {})) >= 4,
		Deploy = t.guideDeployed == true,
		Win = won,
	}
end

-- The opening Collect/Sell lessons are underway: the guide has not been skipped
-- or completed, its recruit-first route (legacy openings) is done, and either
-- lesson is unfinished. The Auto Collect vacuum pauses meanwhile so a pass
-- cannot finish the lessons by itself (EggService).
function Guide.IncomeLessonActive(state)
	local t = state.tutorial or {}
	if t.guideSkipped or t.guideCompleted then return false end
	local f = Guide.Facts(state)
	if f.Win or (f.Collect and f.Sell) then return false end
	if #(state.pets or {}) == 0 or (not t.starterArmy and not f.Recruit) then return false end
	return true
end

local function step(id, text, target)
	return {id=id, text=text, target=target}
end

local function earn(state, price)
	local carried = (state.eggs or {}).carriedValue or 0
	local needed = if price then math.max(0, price - (state.coins or 0)) else 1
	-- Keep gathering until this trip can fund the purchase. Any nonempty bag
	-- used to send players back to the pad, then straight back to the yard.
	if carried > 0 and carried >= needed then
		return step("RecoverSell", "Step on the green sell pad", "EggDeposit")
	end
	return step("RecoverCollect",
		if price then "Collect $" .. math.ceil(needed - carried) .. " more in eggs" else "Collect eggs in your yard", "Yard")
end

local function recruit(state, growing)
	local count = #(state.pets or {})
	local id = if growing then "Grow" else "Recruit"
	local offer = state.offer
	if not offer then
		return step(if growing then id else "Roll", if growing then "Roll a chicken ("..count.."/4)"
			else "Pull the lever to roll", "RollStation")
	end
	if (offer.price or 0) > (state.coins or 0) then
		if count==0 then
			return step("Roll", "Roll again for free", "RollStation")
		end
		return earn(state, offer.price)
	end
	return step(id, if growing then "Buy a chicken ("..count.."/4)" else "Buy the chicken", "RollStation")
end

-- Army power vs a garrison's power (Rules.PetPower sums). Defenders respawn every
-- 10-15s and capture needs every guard down at once, so an even match usually
-- loses: below 1.3x reads Very tough, 1.3-2x a Close fight, 2x+ Should win.
Guide.CloseFightRatio = 1.3
Guide.ShouldWinRatio = 2
function Guide.Difficulty(power, enemyPower)
	if (enemyPower or 0) <= 0 then return "Undefended" end
	local ratio = (power or 0) / enemyPower
	if ratio >= Guide.ShouldWinRatio then return "Should win" end
	if ratio >= Guide.CloseFightRatio then return "Close fight" end
	return "Very tough"
end

local function target(state, id)
	for _, entry in state.targets or {} do if entry.id == id then return entry end end
	return nil
end

-- Compact cash for one-line goals: 950, 12.5K, 3M, 1.2B.
local CASH_STEPS: {number} = {1e12, 1e9, 1e6, 1e3}
local CASH_SUFFIXES: {string} = {"T", "B", "M", "K"}
local function shortCash(value: number?): string
	local amount = math.max(0, math.floor(value or 0))
	for index, size in CASH_STEPS do
		if amount >= size then
			local scaled = math.floor(amount / size * 10) / 10
			return (if scaled % 1 == 0 then tostring(math.floor(scaled)) else tostring(scaled)) .. CASH_SUFFIXES[index]
		end
	end
	return tostring(amount)
end

-- An open camp on another commander's lane, unless one is already held.
local function rivalCamp(state)
	if (state.holdCount or 0) >= (state.holdLimit or math.huge) then return nil end
	local open = nil
	for _, entry in state.targets or {} do
		if entry.kind == "Camp" and entry.laneOwnerName ~= nil then
			if entry.owned then return nil end
			if entry.available and not open then open = entry end
		end
	end
	return open
end

-- After the opening guide: one compact, snapshot-derived next goal. Never a
-- prerequisite; cash upgrades and every target stay available as before.
-- ignoreSkip: the world NEXT marker predates the guide and stays for skipped players.
function Guide.NextGoal(state, ignoreSkip)
	if not state or state.saveStatus=="loading" or state.saveStatus=="error" then return nil end
	local t = state.tutorial or {}
	if t.guideSkipped and not ignoreSkip then return nil end -- Respect a hidden guide; Settings can resume it.
	-- October 9: goals are opt-out (Settings). October 14 launch: after the King
	-- (or a Rebirth, which keeps them open) they point once at a Veteran mission.
	if t.goalsHidden then return nil end
	local function goal(key, text, where)
		local result = step("Goal:" .. key, text, where)
		result.goal = true
		return result
	end
	if state.incoming or state.outgoing then return nil end -- The battle UI owns this moment.
	local rebirth = state.rebirth or {}
	local rebirths = tonumber(rebirth.rank) or 0
	-- After the first capture: point once at the Fuse Machine when it can be researched now.
	if not state.mergeUnlocked and ((state.campsWon or 0) > 0 or state.kingCleared) then
		local fuse = ((state.research or {}).offers or {}).FuseMachine
		if fuse and fuse.status == "Available" then
			return goal("Fuse", "Research the Fuse Machine in Upgrades", "Upgrades")
		end
	end
	if state.kingCleared or rebirths >= 1 then
		local wins = (state.operations or {}).wins or {}
		if not (wins["1:1"] or wins["1:2"] or wins["1:3"]) then
			return goal("Operations", "Conquer a mission on the island", "Mission")
		end
	end
	-- October 14: only Rebirth 1 needs the King, and Rebirth opens from its HUD button.
	if state.kingCleared or rebirths >= 1 then
		local cost = rebirth.cost
		if rebirth.enabled ~= false and rebirth.nextRank and type(cost) == "number" and cost > 0
			and (state.coins or 0) >= cost * 0.5 then
			if (state.coins or 0) >= cost then return goal("Rebirth", "Rebirth is ready: open Rebirth on the left", nil) end
			return goal("Rebirth", "Rebirth: $" .. shortCash(state.coins) .. " / $" .. shortCash(cost), nil)
		end
	end
	if state.kingCleared then
		if rivalCamp(state) then return goal("Rival", "Take a rival's camp for bonus egg value", nil) end
		return nil
	end
	if state.armyState == "Returning" or state.armyState == "Recovering" then
		return goal("Return", "Collect eggs while your army returns", "Yard")
	end
	if #(state.pets or {}) == 0 then return goal("Recruit", "Roll a chicken at your podium", "RollStation") end
	if (state.selectedCount or #(state.selectedIds or {})) == 0 then return goal("Select", "My Army → Select Best", "Army") end
	local function attack(id, name, where)
		local entry = target(state, id)
		if not entry then return nil end
		if Guide.Difficulty(state.power, entry.power) == "Very tough" then
			-- The cheapest helpful step first: Egg Value while it is affordable, then chickens.
			local value = (state.boardUpgrades or {}).EggValue
			if value and value.price and value.canSpend and value.unlocked ~= false then
				return goal("Value", "Buy Egg Value in Upgrades to grow faster", "Upgrades")
			end
			return goal("Grow:" .. id, "Roll or upgrade chickens for " .. name, "RollStation")
		end
		return goal("Attack:" .. id, if id == "king:1" then "Challenge the Chicken King" else "Attack " .. name, where)
	end
	local camps = state.routeCamps or {}
	for index = 1, 10 do
		local entry = target(state, "camp:" .. index)
		if not entry then break end
		if not camps[index] and not entry.owned then return attack(entry.id, entry.name, "Camp" .. index) end
	end
	if not state.ownsKing then return attack("king:1", "the King", "KingArena") end
	return nil
end

function Guide.Resolve(state)
	if not state or state.saveStatus=="loading" or state.saveStatus=="error" then return nil end
	local t, f = state.tutorial or {}, Guide.Facts(state)
	if t.guideSkipped then return nil end
	if f.Win or t.guideCompleted then
		if not t.guideStarted then return nil end -- Established players are not forced through a new tutorial.
		return step("Complete", "Cluck Camp captured!", nil)
	end
	if state.incoming then
		return step("Defend", "Your army is defending", nil)
	end
	if state.outgoing then
		return step("Battle", "Your army is fighting", nil)
	end
	if state.armyState == "Returning" or state.armyState == "Recovering" then
		if t.starterArmy and f.Sell then
			return step("Return", "Wait for your army to return", nil)
		end
		return step("Return", "Collect eggs while they return", "Yard")
	end
	-- Starter birds can teach income before recruiting. Legacy openings retain
	-- their recruit-first route, and an empty flock always needs an egg producer.
	if #(state.pets or {})==0 or (not t.starterArmy and not f.Recruit) then return recruit(state, false) end
	if not f.Collect then
		return step("Collect", "Collect "..Guide.EggGoal.." eggs ("..Guide.CollectedEggCount(t).."/"..Guide.EggGoal..")", "Yard")
	end
	if not f.Sell then
		if ((state.eggs or {}).carriedValue or 0) <= 0 then return earn(state) end
		return step("Sell", "Step on the green sell pad", "EggDeposit")
	end
	if not f.Recruit then return recruit(state, false) end
	-- The new squad already has four birds after Recruit. Older empty-yard saves
	-- can still grow their flock without resetting or granting them extra birds.
	if not f.Grow then return recruit(state, true) end
	if not f.Expand then
		local offer = state.nextSlot
		if offer and (state.coins or 0) < offer.price then return earn(state, offer.price) end
		return step("Expand", "Buy Army Size → " .. ((state.nextSlot and state.nextSlot.capacity) or 4) .. " in Upgrades", "Upgrades")
	end
	if not f.Select then
		return step("Select", "My Army → Select Best", "Army")
	end
	return step("Deploy", "Cluck Camp → Send Army", "Camp1")
end

return Guide
