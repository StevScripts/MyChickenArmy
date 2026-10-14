--!strict
-- Re-enlist panel. Foundation stub: renders nothing until worker R1-C fills it in.
-- AppController calls Render(state, result) on every state packet.
local RebirthPanel = {}
RebirthPanel.__index = RebirthPanel

function RebirthPanel.new(app)
	return setmetatable({app = app}, RebirthPanel)
end

function RebirthPanel:Render(_state, _result) end

function RebirthPanel:Destroy() end

return RebirthPanel
