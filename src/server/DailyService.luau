--!strict
-- 7-day login streak. Foundation stub: does nothing until worker D1 fills it in.
-- Contract: docs/team/launch/13_D1_DAILY_STREAK.md. GameServer calls Check after
-- a profile loads and once a minute for every loaded session.
local DailyService = {}

function DailyService.Check(_session, _now: number, _server) end

return DailyService
