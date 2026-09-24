--!strict
-- Roblox owns prompt appearance and input. This only retires the old custom
-- renderer and keeps existing/new world prompts on the native presentation.
local Players=game:GetService("Players")
local Controller={}
Controller.__index=Controller

function Controller.new(_app)
	return setmetatable({connections={},watched={}},Controller)
end

function Controller:Watch(item)
	if not item:IsA("ProximityPrompt") or self.watched[item] then return end
	local function restore()
		if item.Style~=Enum.ProximityPromptStyle.Default then item.Style=Enum.ProximityPromptStyle.Default end
	end
	self.watched[item]=item:GetPropertyChangedSignal("Style"):Connect(restore)
	restore()
end

function Controller:Start()
	local playerGui=Players.LocalPlayer:FindFirstChild("PlayerGui")
	if playerGui then
		for _,item in playerGui:GetChildren() do
			if item.Name=="CountryPrompt" then item:Destroy() end
		end
	end
	table.insert(self.connections,workspace.DescendantAdded:Connect(function(item) self:Watch(item) end))
	table.insert(self.connections,workspace.DescendantRemoving:Connect(function(item)
		local connection=self.watched[item]
		if connection then connection:Disconnect();self.watched[item]=nil end
	end))
	for _,item in workspace:GetDescendants() do self:Watch(item) end
end

function Controller:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	for _,connection in self.watched do connection:Disconnect() end
	table.clear(self.watched)
	-- Do not restore legacy Custom styles on shutdown.
end

return Controller
