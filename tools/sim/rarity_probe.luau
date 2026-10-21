-- Instrumented ProgressionSimulation: first offer / first recruit per rarity, Luck purchases, Playtime share.
local options = {}
for _, arg in ARGS do
	local k, v = string.match(arg, "^(%w+)=(.*)$")
	if k then options[k] = if v == "true" then true elseif v == "false" then false elseif tonumber(v) then tonumber(v) else v end
end
local Catalog = Harness.require(Harness.Shared.PetCatalog)
local Rolls = Harness.require(Harness.Server.RollService)
local Playtime = Harness.require(Harness.Server.PlaytimeService)
local Sim = Harness.require(Harness.Tests.ProgressionSimulation)
local RARITIES = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Secret"}
local records, current = {}, nil
local function record(session)
	if current == nil or current.session ~= session then
		current = {session = session, seen = {}, owned = {}, luckLog = {}, counts = {}, counts60 = {}, pulls = 0, pulls60 = 0, lastLuck = 0}
		table.insert(records, current)
	end
	return current
end
local function scanOwned(session, now)
	for _, pet in session.pets do
		local d = Catalog[pet.species]
		if d and not current.owned[d.rarity] then
			current.owned[d.rarity] = {minutes = now / 60, luck = session.luck, rank = session.rebirths, species = pet.species}
		end
	end
end
local origRoll, origBuy, origFree = Rolls.Roll, Rolls.Buy, Playtime.FreeRolls
Rolls.Roll = function(self, session, now)
	local r = record(session)
	local ok, msg = origRoll(self, session, now)
	if ok then
		r.pulls += 1
		if now <= 3600 then r.pulls60 += 1 end; r.lastNow = now
		if session.luck ~= r.lastLuck then
			table.insert(r.luckLog, {tier = session.luck, minutes = now / 60, rank = session.rebirths})
			r.lastLuck = session.luck
		end
		for _, offer in session.offers or {} do
			local d = Catalog[offer.species]
			if d and not offer.starter then
				r.counts[d.rarity] = (r.counts[d.rarity] or 0) + 1
				if now <= 3600 then r.counts60[d.rarity] = (r.counts60[d.rarity] or 0) + 1 end
				if not r.seen[d.rarity] then
					r.seen[d.rarity] = {minutes = now / 60, luck = session.luck, rank = session.rebirths, species = offer.species,
						price = offer.price, coins = math.floor(session.coins), special = offer.special, boost = session:RollLuckBonus()}
				end
			end
		end
	end
	return ok, msg
end
Rolls.Buy = function(self, session, id, now, ...)
	local ok, msg = origBuy(self, session, id, now, ...)
	if ok then record(session); scanOwned(session, now) end
	return ok, msg
end
Playtime.FreeRolls = function(session, rolls)
	local granted = origFree(session, rolls)
	record(session); scanOwned(session, current.lastNow or 0)
	return granted
end
options.print = options.print == nil and false or options.print
-- Run the whole ladder unless told otherwise (ProgressionSimulation's own default stops at 30).
options.targetRank = options.targetRank or Harness.require(Harness.Shared.Config).Rebirth.MaxRank
local results = Sim.Run(options)
local function m(x) return if x then string.format("%6.1f", x) else "  -   " end
print(string.format("=== profile %s · rollEvery %ss · hours %s · seeds %s · play %s/away %s ===", results.options.profile,
	tostring(results.options.rollEverySeconds), tostring(results.options.hours), tostring(results.options.seeds),
	tostring(results.options.playMinutes), tostring(results.options.awayMinutes)))
for i, run in results.runs do
	local r = records[i]
	print(string.format("-- seed %d: %d pulls (%d in first hour), rank %d after %.0f min", run.seed, r.pulls, r.pulls60, run.final.rank, run.minutes))
	print("   rarity      first offer (min, Luck tier, rank, species, price, coins then)   first owned (min, Luck, rank, species)   offers 1st hour / total")
	for _, rarity in RARITIES do
		local s, o = r.seen[rarity], r.owned[rarity]
		print(string.format("   %-10s  %s  L%-2s R%-2s %-12s %10s %10s %s   |  %s  L%-2s R%-2s %-12s  | %5d / %d",
			rarity, m(s and s.minutes), s and s.luck or "-", s and s.rank or "-", s and s.species or "-", s and tostring(s.price) or "-",
			s and tostring(s.coins) or "-", s and (s.special and ("[" .. s.special .. "]") or (s.boost > 0 and "[boost]" or "")) or "",
			m(o and o.minutes), o and o.luck or "-", o and o.rank or "-", o and o.species or "-", r.counts60[rarity] or 0, r.counts[rarity] or 0))
	end
	local luck = {}
	for _, e in r.luckLog do table.insert(luck, string.format("L%d@%.1fm(R%d)", e.tier, e.minutes, e.rank)) end
	print("   Luck tier changes: " .. table.concat(luck, " "))
	local st = run.stats
	local total = st.eggCash + st.battleCash + st.invasionCash + (st.playtimeCash or 0) + (st.dailyCash or 0) + (st.offlineCash or 0) + (st.timeSkip or 0)
	print(string.format("   Coins: eggs %.0f (%.0f%%), battles %.0f, Missions %.0f, playtime %.0f (%.0f%%), daily %.0f, offline %.0f, time skip %.0f; recruits %d, tree buys %d",
		st.eggCash, 100 * st.eggCash / math.max(1, total), st.battleCash, st.invasionCash, st.playtimeCash or 0, 100 * (st.playtimeCash or 0) / math.max(1, total),
		st.dailyCash or 0, st.offlineCash or 0, st.timeSkip or 0, st.recruits, st.treeBuys))
	local ms = {}
	for _, key in {"Min10","Min30","Min60","Rebirth1","Rebirth2","Rebirth3","Rebirth5","MythicSeen","MythicOwned"} do
		local v = run.milestones[key]
		if v then table.insert(ms, string.format("%s=%.0fm(%s Coins, %.0f/s)", key, v.minutes, tostring(math.floor(v.coins)), v.income)) end
	end
	print("   milestones: " .. table.concat(ms, "  "))
end
