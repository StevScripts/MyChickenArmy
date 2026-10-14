--!strict
-- Who may use admin commands (AdminService). Server-only: this module lives in
-- ServerStorage, so clients never see the list.
--
-- Owner: every command, including ban/unban and adding or removing admins.
-- Admin: every command except ban/unban and managing admins; cannot kick owners or other admins.
--
-- Two ways to give someone admin:
--   1. Add their user ID to Admins below and republish (permanent, in code).
--   2. In game, as an owner: /admin admin add <player or user ID> (saved in a
--      DataStore, works in every server within a minute, no republish needed).
local AdminConfig = {}

AdminConfig.Owners = {
	146710616, -- Stevin (game owner)
}

AdminConfig.Admins = {
	-- 123456789, -- Example: a friend's user ID
}

-- Optional: everyone at or above this rank in the owning group is an admin.
-- nil turns it off. Example: GroupId = 778575811, GroupAdminRank = 250.
AdminConfig.GroupId = nil :: number?
AdminConfig.GroupAdminRank = nil :: number?

-- A player an admin gives chickens, research, camp wins or army size to is left
-- off the Strongest Army leaderboard, so rankings stay earned. Cash grants do
-- not affect rankings. Set false to let assisted players rank anyway.
AdminConfig.KeepRankingsClean = true

-- Largest single cash change one command may make.
AdminConfig.MaxCashPerCommand = 1e12

return AdminConfig
