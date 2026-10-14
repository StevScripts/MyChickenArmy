--!strict
-- Limited events (Halloween 2026). Foundation stub: never active until worker
-- H1 fills it in. Contract: docs/team/launch/15_H1_HALLOWEEN.md.
local EventService = {}

function EventService.Active(_now: number): boolean return false end

-- Called for each non-starter, non-forced roll slot after its normal draw.
function EventService.MaybeReplace(_session, species: string, _rng, _slot: number, _now: number): string
	return species
end

return EventService
