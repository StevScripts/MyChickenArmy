-- Time Skip vs the Coins tree (October 22): at each Rebirth, the Time Skip Coins, how many
-- tree tiers they buy (cheapest first), their share of the tree the player just lost and
-- of the next rank. Any ProgressionSimulation option works (profile=fast hours=12 seeds=1).
local options = {}
for _, arg in ARGS do
	local k, v = string.match(arg, "^(%w+)=(.*)$")
	if k then options[k] = if v == "true" then true elseif v == "false" then false elseif tonumber(v) then tonumber(v) else v end
end
local Tree = Harness.require(Harness.Shared.UpgradeCatalog)
local Rebirth = Harness.require(Harness.Server.RebirthService)
local Sim = Harness.require(Harness.Tests.ProgressionSimulation)

local prices = {}
local total = 0
for id, family in Tree.Families do
	for tier = 1, #family.tiers do
		local p = Tree.Price(id, tier, 0)
		if p then table.insert(prices, p); total += p end
	end
end
table.sort(prices)
local function buys(coins)
	local n, spent = 0, 0
	for _, p in prices do
		if spent + p > coins then break end
		spent += p; n += 1
	end
	return n
end
local function fmt(n)
	if n >= 1e12 then return string.format("%.1fT", n/1e12) elseif n >= 1e9 then return string.format("%.1fB", n/1e9)
	elseif n >= 1e6 then return string.format("%.1fM", n/1e6) elseif n >= 1e3 then return string.format("%.1fK", n/1e3) end
	return tostring(math.floor(n))
end
print(string.format("Tree: %d tiers, %s total", #prices, fmt(total)))
local orig = Rebirth.Rebirth
Rebirth.Rebirth = function(session, ...)
	local minutes = session.researchEffects and session.researchEffects.timeSkipMinutes or 0
	local owned = 0
	for id, family in Tree.Families do
		for tier = 1, Tree.Tier(session.upgradeTree, id) do owned += Tree.Price(id, tier, 0) or 0 end
	end
	local ok, msg, receipt = orig(session, ...)
	if ok and receipt then
		local pre = if session.timeSkipPending then session.timeSkipPending.coins else receipt.timeSkipCoins or 0
		local nextCost = Rebirth.Cost(session.rebirths + 1) or 0
		print(string.format("R%2d  min=%2d  skip=%8s  buys %3d/%d tiers  = %6.2f%% of the tree you had (%s)  %5.2f%% of next rank %s",
			session.rebirths, minutes, fmt(pre), buys(pre), #prices, owned > 0 and pre / owned * 100 or 0, fmt(owned),
			nextCost > 0 and pre / nextCost * 100 or 0, fmt(nextCost)))
	end
	return ok, msg, receipt
end
options.print = options.print or false
Sim.Run(options)
