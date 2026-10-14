--!strict
-- Chicken mutations (egg production only). Foundation stub: no mutation exists
-- until worker M1 fills it in. Contract: docs/team/launch/14_M1_MUTATIONS.md.
-- PlayerSession drops any saved mutation IsValid rejects and keeps the chicken.
local MutationCatalog = {}

MutationCatalog.Order = {} :: {string}

function MutationCatalog.IsValid(_id: any): boolean return false end

function MutationCatalog.Multiplier(_id: any): number return 1 end

function MutationCatalog.Roll(_rng, _rebirths: number): string? return nil end

-- The best mutation among fusion inputs (pet records), or nil.
function MutationCatalog.Best(_pets): string? return nil end

return MutationCatalog
