--!strict
-- Snapshot-only guidance. Never changes prices, eligibility or player actions.
local Guide = {}
Guide.Version = "cluck-3-starter-army"
Guide.Milestones = {"Roll", "Recruit", "Collect", "Sell", "Grow", "Expand", "Select", "Deploy", "Win"}

function Guide.Facts(state)
	local t = state.tutorial or {}
	local won = t.wonCamp == true or (state.campsWon or 0) > 0 or state.kingCleared == true
	for _, value in state.firstWins or {} do if value then won = true end end
	return {
		Roll = t.rolled == true,
		-- The free squad must not count as completing the recruit lesson.
		Recruit = if t.starterArmy then t.bought == true
			else t.bought == true or #(state.pets or {}) >= (if t.emptyStart then 1 else 4),
		Collect = t.collectedEggs == true or ((state.eggs or {}).carriedCount or 0) > 0,
		Sell = t.soldEggs == true,
		Grow = #(state.pets or {}) >= 4,
		Expand = (state.capacity or 3) >= 4,
		Select = (state.selectedCount or #(state.selectedIds or {})) >= 4,
		Deploy = t.guideDeployed == true,
		Win = won,
	}
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
	return step(id, if growing then "Buy a chicken ("..count.."/4)" else "Buy the chicken for $"..offer.price, "RollStation")
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
	if not f.Recruit or #(state.pets or {})==0 then return recruit(state, false) end
	if not f.Collect then
		return step("Collect", "Walk over an egg", "Yard")
	end
	if not f.Sell then
		if ((state.eggs or {}).carriedValue or 0) <= 0 then return earn(state) end
		return step("Sell", "Step on the green sell pad", "EggDeposit")
	end
	-- The new squad already has four birds after Recruit. Older empty-yard saves
	-- can still grow their flock without resetting or granting them extra birds.
	if not f.Grow then return recruit(state, true) end
	if not f.Expand then
		local offer = state.nextSlot
		if offer and (state.coins or 0) < offer.price then return earn(state, offer.price) end
		return step("Expand", "Upgrades → Army Size 1", "Upgrades")
	end
	if not f.Select then
		return step("Select", "My Army → Select Best", "Army")
	end
	return step("Deploy", "Cluck Camp → Move Troops Here", "Camp1")
end

return Guide
