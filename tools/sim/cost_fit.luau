-- ProgressionSimulation with an optional Rebirth cost patch (costs=<json list file>);
-- writes each seed's played minutes per rank (-1 = not reached) to out=<json>. Used for the
-- October 22 Time Skip re-fit: compare against a `git archive HEAD` copy's run and move
-- each cost by (target gap / measured gap)^0.8, smoothed over five ranks.
local options = {}
local costsFile, out
for _, arg in ARGS do
	local k, v = string.match(arg, "^(%w+)=(.*)$")
	if k == "costs" then costsFile = v elseif k == "out" then out = v
	elseif k then options[k] = if v == "true" then true elseif v == "false" then false elseif tonumber(v) then tonumber(v) else v end end
local Config = Harness.require(Harness.Shared.Config)
if costsFile then
	local costs = Harness.serde.decode("json", Harness.fs.readFile(costsFile))
	for i, c in costs do Config.Rebirth.Costs[i] = c end
end
local results = Harness.require(Harness.Tests.ProgressionSimulation).Run(options)
local rows = {}
for _, run in results.runs do
	local ranks = {}
	for r = 1, Config.Rebirth.MaxRank do
		local m = run.milestones["Rebirth" .. r]
		ranks[r] = if m then m.played or m.minutes else -1
	end
	table.insert(rows, ranks)
end
Harness.fs.writeFile(out, Harness.serde.encode("json", rows))
