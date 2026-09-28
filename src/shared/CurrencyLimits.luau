--!strict
-- Exact whole-coin arithmetic with the existing numeric save format.
-- This is a representation boundary, not a designed economy/upgrade ceiling.
return table.freeze({MaxCoins = 2^53 - 1})
