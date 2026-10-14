--!strict
-- Re-enlist (rebirth). Foundation stub: neutral until worker R1-S fills it in.
-- Contract: docs/team/launch/11_R1_REBIRTH_SERVER.md. PlayerSession requires
-- this module, so it must never require PlayerSession.
local RebirthService = {}

function RebirthService.Multiplier(_rank: number): number return 1 end

function RebirthService.EnemyScale(_rank: number): number return 1 end

function RebirthService.Quote(session)
	return {rank = session.rebirths or 0, eligible = false, reason = "Coming soon"}
end

function RebirthService.Rebirth(_session, _expectedRank, _server): (boolean, string)
	return false, "Coming soon"
end

return RebirthService
