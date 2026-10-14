--!strict
-- Daily streak popup. Foundation stub: renders nothing until worker D1 fills it in.
-- AppController calls Render(state, result) on every state packet, after the
-- offline receipt (app.offlineCash.gui is set while that receipt is open).
local DailyRewardController = {}
DailyRewardController.__index = DailyRewardController

function DailyRewardController.new(app)
	return setmetatable({app = app}, DailyRewardController)
end

function DailyRewardController:Render(_state, _result) end

function DailyRewardController:Destroy() end

return DailyRewardController
