--!strict
-- Limited events (Halloween 2026). Contract: docs/team/launch/15_H1_HALLOWEEN.md.
-- While Config.Event runs, each eligible podium has OfferChance to offer the
-- event species instead of its normal draw. Normal odds and saves are untouched;
-- the species has zero catalog weight, so it is only ever offered from here.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.PetCatalog)
local EventService = {}

-- Enabled, inside [StartsAt, EndsAt), and the species exists. Malformed config is inactive.
function EventService.Active(now: number): boolean
	local event = Config.Event
	if type(event) ~= "table" or event.Enabled ~= true or type(now) ~= "number" then return false end
	if type(event.StartsAt) ~= "number" or type(event.EndsAt) ~= "number" then return false end
	if type(event.OfferChance) ~= "number" or not (event.OfferChance > 0 and event.OfferChance <= 1) then return false end
	return type(event.Species) == "string" and Catalog[event.Species] ~= nil
		and event.StartsAt <= now and now < event.EndsAt
end

-- Called by RollService for each non-starter, non-forced slot after its normal
-- draw. Inactive: returns `species` and never touches rng. Active: exactly one
-- rng:NextNumber() per call, so seeded rolls stay reproducible.
function EventService.MaybeReplace(_session, species: string, rng, _slot: number, now: number): string
	if not EventService.Active(now) then return species end
	if rng:NextNumber() < Config.Event.OfferChance then return Config.Event.Species end
	return species
end

return EventService
