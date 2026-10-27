-- ProgressionSimulation with WS2 patches: discount=f fadeAt=N r0keep=true tree=Fam:tier:price,...
local o = {seeds = 3, hours = 6, profile = "fast", discount = 1, fadeAt = 0, r0keep = false, tree = nil, favored = nil, firstSeed = 1, strength2 = nil, strength3 = nil, lucky = false, favoredSpec = nil, ratios = nil}
for _, arg in ARGS do
	local k, v = string.match(arg, "^(%w+)=(.*)$")
	if k then o[k] = if v == "true" then true elseif v == "false" then false elseif tonumber(v) then tonumber(v) else v end
end
local Config = Harness.require(Harness.Shared.Config)
local Rules = Harness.require(Harness.Shared.Rules)
local Tree = Harness.require(Harness.Shared.UpgradeCatalog)
local Rolls = Harness.require(Harness.Server.RollService)
local Rebirth = Harness.require(Harness.Server.RebirthService)
local Sim = Harness.require(Harness.Tests.ProgressionSimulation)
local Catalog = Harness.require(Harness.Shared.PetCatalog)
local Progression = Harness.require(Harness.Shared.Progression)
local Guide = Harness.require(Harness.Shared.TutorialGuide)
if type(o.favoredSpec) == "string" then
	local r, c = string.match(o.favoredSpec, "(%d+)x([%d%.]+)")
	Config.Economy.FavoredRolls = {rolls = tonumber(r), chance = tonumber(c), species = "Duck"}
end
if o.ratios == "ws1" then Guide.CloseFightRatio, Guide.ShouldWinRatio = 1.0, 1.3 end
if o.strength2 or o.strength3 then
	local mark = setmetatable({}, {__mode = "k"})
	local realRoster, realPower = Progression.Roster, Rules.Power
	Progression.Roster = function(rank, index)
		local r = realRoster(rank, index)
		local st = if index == 2 then o.strength2 elseif index == 3 then o.strength3 else nil
		if st then mark[r] = st end
		return r
	end
	Rules.Power = function(roster)
		local v = realPower(roster)
		local st = mark[roster]
		return if st then math.floor(v * st) else v
	end
end
if o.favored == "off" then Config.Economy.FavoredRolls = nil end
if type(o.tree) == "string" then
	local over = {}
	for fam, tier, price in string.gmatch(o.tree, "(%a+):(%d+):(%d+)") do over[fam .. tonumber(tier)] = tonumber(price) end
	local real = Tree.Price
	Tree.Price = function(f, t, r) return over[f .. tostring(t)] or real(f, t, r) end
end
if o.r0keep then
	local real = Rebirth.RebirthIntro
	Rebirth.RebirthIntro = function(s, server)
		local tree = table.clone(s.upgradeTree or {})
		local ok, m, r = real(s, server)
		if ok then s.upgradeTree = tree; s:RefreshEffects() end
		return ok, m, r
	end
end
local RANK = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Secret = 7}
if o.lucky then
	local real = Rolls.Roll
	Rolls.Roll = function(self, s, now)
		local t = s.tutorial
		local active = s.introRebirth ~= nil and type(t) == "table" and t.guideCompleted == true
		s.wsLucky = s.wsLucky or {pulls = 0, nextU = 2, nextR = 8, firesU = 0, firesR = 0}
		local L = s.wsLucky
		local forced
		if active and L.pulls < 40 and now >= (s.rollReadyAt or 0) then
			local function owns(rank)
				for id, yes in s.discovered or {} do if yes and Catalog[id] and (RANK[Catalog[id].rarity] or 0) >= rank then return true end end
				return false
			end
			local k = L.pulls + 1
			if not owns(3) and L.firesR < 2 and k >= L.nextR then forced = "Rare"
			elseif not owns(2) and L.firesU < 2 and k >= L.nextU then forced = "Uncommon" end
			if forced then
				local odds = Rules.Odds(s.luck, s.promotion, s:PaidLuckMultiplier(), s:RollLuckBonus())
				local total = 0
				for _, id in Catalog.Order do if Catalog[id].rarity == forced then total += odds[id] end end
				local rng = self.random
				local x, acc = rng:NextNumber() * total, 0
				for _, id in Catalog.Order do
					if Catalog[id].rarity == forced then acc += odds[id]; if x < acc then s.debugNext = id; break end end
				end
			end
		end
		local ok, m = real(self, s, now)
		if ok and active and L.pulls < 40 then
			L.pulls += 1
			if forced == "Rare" then L.firesR += 1 elseif forced == "Uncommon" then L.firesU += 1 end
			for _, offer in s.offers or {} do
				local r = RANK[Catalog[offer.species].rarity] or 1
				if r >= 2 then L.nextU = math.max(L.nextU, L.pulls + 5) end
				if r >= 3 then L.nextR = math.max(L.nextR, L.pulls + 10) end
			end
		elseif not ok then s.debugNext = nil end
		return ok, m
	end
end
if o.discount < 1 then
	local real = Rolls.Roll
	Rolls.Roll = function(self, s, now)
		local ok, m = real(self, s, now)
		if ok and s.introRebirth ~= nil then
			local f = o.discount
			if o.fadeAt > 0 then
				f = f + (1 - f) * math.clamp((s:Count() - 2) / (o.fadeAt - 2), 0, 1)
			elseif (s.rebirths or 0) > 0 then f = 1 end
			for _, offer in s.offers or {} do
				local catalog = Rules.RecruitPrice(offer.species, offer.level)
				if not offer.starter and offer.price == catalog and f < 1 then
					offer.price = math.min(catalog, math.max(150, math.ceil(catalog * f / 5) * 5))
				end
			end
		end
		return ok, m
	end
end
local results = Sim.Run({seeds = o.seeds, firstSeed = o.firstSeed, hours = o.hours, profile = o.profile, targetRank = o.targetRank, print = true,
	rollEverySeconds = o.rollEverySeconds, depositSeconds = o.depositSeconds})

for _, run in results.runs do
	local parts = {}
	for _, key in {"Rebirth0", "Rebirth1", "Rebirth2", "Rebirth5", "Rebirth10", "Rebirth15", "Rebirth20", "FirstCamp", "AllCamps"} do
		local m = run.milestones[key]
		table.insert(parts, key .. "=" .. (if m then string.format("%.1f", m.played or m.minutes) else "nan"))
	end
	print("SEEDROW seed=" .. run.seed .. " " .. table.concat(parts, " "))
end
