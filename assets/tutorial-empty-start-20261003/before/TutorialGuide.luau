--!strict
-- Snapshot-only guidance. Never changes prices, eligibility or player actions.
local Guide = {}
Guide.Version = "cluck-1"
Guide.Milestones = {"Recruit", "Collect", "Sell", "Expand", "Select", "Deploy", "Win"}

function Guide.Facts(state)
	local t = state.tutorial or {}
	local won = t.wonCamp == true or (state.campsWon or 0) > 0 or state.kingCleared == true
	for _, value in state.firstWins or {} do if value then won = true end end
	return {
		Recruit = t.bought == true or #(state.pets or {}) > 3,
		Collect = t.collectedEggs == true or ((state.eggs or {}).carriedCount or 0) > 0,
		Sell = t.soldEggs == true,
		Expand = (state.capacity or 3) >= 4,
		Select = (state.selectedCount or #(state.selectedIds or {})) >= 4,
		Deploy = t.guideDeployed == true,
		Win = won,
	}
end

local function step(id, title, text, target, help)
	return {id=id, title=title, text=text, target=target, help=help or text}
end

local function earn(state, purpose)
	if ((state.eggs or {}).carriedValue or 0) > 0 then
		return step("RecoverSell", "Sell your eggs", "Green pad → instant cash.", "EggDeposit", "Earn enough cash for " .. purpose .. ".")
	end
	return step("RecoverCollect", "Collect more eggs", "Walk near the eggs in your yard.", "Yard",
		"Collect eggs in your yard, then walk onto the green sell pad.")
end

function Guide.Resolve(state)
	if not state or state.saveStatus=="loading" or state.saveStatus=="error" then return nil end
	local t, f = state.tutorial or {}, Guide.Facts(state)
	if t.guideSkipped then return nil end
	if f.Win or t.guideCompleted then
		if not t.guideStarted then return nil end -- Established players are not forced through a new tutorial.
		return step("Complete", "Cluck Camp captured!", "Recruit, upgrade, or battle again.", nil)
	end
	if state.incoming then
		return step("Defend", "Defend your base", "Your chickens fight for you.", nil)
	end
	if state.outgoing then
		return step("Battle", "Your flock is fighting", "Earn cash while they fight.", nil,
			"Chickens recover after a knockout. Change squads in My Army.")
	end
	if state.armyState == "Returning" or state.armyState == "Recovering" then
		return step("Return", "Your flock is returning", "Collect eggs as they recover.", "Yard")
	end
	if not f.Recruit or (f.Expand and #(state.pets or {}) < 4) then
		local offer = state.offer
		if not offer then
			return step("Recruit", "Roll a chicken for FREE", "Use the lever at your rolling station.", "RollStation",
				"Use the lever beside your podium. Rolling is free; buying uses cash.")
		end
		if (offer.price or 0) > (state.coins or 0) then
			local recovery = earn(state, "your recruit")
			recovery.help = "Earn cash for this chicken, or use the lever to roll again FREE."
			return recovery
		end
		return step("Recruit", "Recruit a chicken", "More chickens, more eggs.", "RollStation",
			"At your podium, use Buy. The lever rolls a new offer FREE.")
	end
	if not f.Collect then
		return step("Collect", "Collect an egg", "Walk near an egg in your yard.", "Yard",
			"Walk close to an egg. Your bag fills; sell the eggs for cash.")
	end
	if not f.Sell then
		if ((state.eggs or {}).carriedValue or 0) <= 0 then return earn(state, "your first sale") end
		return step("Sell", "Sell your eggs", "Green pad → instant cash.", "EggDeposit",
			"Walk onto your green sell pad with eggs in your bag.")
	end
	if not f.Expand then
		local offer = state.nextSlot
		if offer and (state.coins or 0) < offer.price then return earn(state, "an army slot") end
		return step("Expand", "Grow your army", "Upgrades → Army Size 1.", "Upgrades",
			"Buy Army Size 1 above Start. Cash buys one more army slot.")
	end
	if not f.Select then
		return step("Select", "Choose four fighters", "My Army → Select Best.", "Army",
			"Select Best fills your slots, or choose four chickens yourself.")
	end
	return step("Deploy", "Capture Cluck Camp", "Use Move Troops Here.", "Camp1",
		"Follow the marker to Cluck Camp. Use Move Troops Here.")
end

return Guide
