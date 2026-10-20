--!strict
-- October 20 overhaul: research is retired. Its nodes merged into the instant
-- Upgrades tree (UpgradeService); EconomyMigration converted saved research once.
-- PlayerSession still saves `research` for the parts other systems use
-- (operationWins, rallyReadyAt, formations, pendingOperationReward). These entry
-- points stay so older callers and clients get a clear answer instead of an error.
local Catalog = require(game:GetService("ReplicatedStorage").PetRoll.Shared.ResearchCatalog)
local Rules = require(game:GetService("ReplicatedStorage").PetRoll.Shared.ResearchRules)
local Service = {}

local RETIRED = "Research is now instant in Upgrades."

-- Nothing runs on a timer any more; converted saves have no jobs.
function Service.Complete(_session, _now)
	return {}
end

function Service.Start(_session, _nodeId, _expectedRevision, _expectedPrice, _expectedDuration, _now)
	return false, RETIRED
end

function Service.Cancel(_session, _jobId, _expectedRevision, _now)
	return false, RETIRED
end

function Service.Skip(_session, _jobId, _expectedRevision, _now)
	return false, RETIRED
end

function Service.Pin(_session, _nodeId)
	return false, RETIRED
end

-- Legacy shape for the old research screen until S9 replaces it: every node reads
-- as completed (if the old save had it) or locked, so nothing looks buyable there.
function Service.Snapshot(session, now)
	local data = Rules.Copy(session.research)
	data.jobs = {}
	data.rallyActiveUntil = session.rallyActiveUntil or 0
	data.serverTime = now
	data.effects = table.clone(session.researchEffects)
	data.offers = {}
	for _, id in Catalog.Order do
		local node = Catalog.Nodes[id]
		data.offers[id] = {status = if data.completed[id] then "Completed" else "Locked", price = node.price,
			duration = node.duration, spendReason = RETIRED}
	end
	data.recap = {}
	data.retired = true
	return data
end

return Service
