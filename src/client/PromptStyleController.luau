--!strict
-- Roblox owns prompt appearance and input. This only retires the old custom
-- renderer and keeps existing/new world prompts on the native presentation.
-- October 21 game feel (docs/team/GAME_FEEL_20261021.md): a world prompt appearing
-- for the player (roll lever, Feed, Send Army, Release Camp) gets a soft "UIHover"
-- tick, and using one rings the ground under the player with a "Click". Locked camps
-- have no prompt, only their reason heading, so they stay silent. No dimming or
-- highlighting of prompts (October 21 tutorial rules).
local Players=game:GetService("Players")
local ProximityPromptService=game:GetService("ProximityPromptService")
local Feel=require(game:GetService("ReplicatedStorage").PetRoll.Shared.CollectionFeel)
local Controller={}
Controller.__index=Controller

function Controller.new(app)
	return setmetatable({app=app,connections={},watched={},lastShown=-10},Controller)
end

function Controller:Watch(item)
	if not item:IsA("ProximityPrompt") or self.watched[item] then return end
	local function restore()
		if item.Style~=Enum.ProximityPromptStyle.Default then item.Style=Enum.ProximityPromptStyle.Default end
	end
	self.watched[item]=item:GetPropertyChangedSignal("Style"):Connect(restore)
	restore()
end

-- A native prompt just appeared for the local player.
function Controller:Shown(prompt: ProximityPrompt)
	local app=self.app
	if not app or not app.audio or not prompt:IsDescendantOf(workspace) then return end
	local now=os.clock()
	if now-self.lastShown<Feel.Feel.PromptShowGap then return end
	self.lastShown=now
	app.audio:Play("UIHover",nil,{noFallback=true,voiceKey="PromptShown",cooldown=Feel.Feel.PromptShowGap,maxDuration=0.5})
end

-- The player used a native prompt: a click and a ring at their feet. The same-key
-- cooldown folds this "Click" into the one BaseController already plays for Send Army.
function Controller:Triggered(prompt: ProximityPrompt)
	local app=self.app
	if not app or not prompt:IsDescendantOf(workspace) then return end
	if app.audio then app.audio:Play("Click") end
	local character=Players.LocalPlayer.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if app.worldFeel and root and root:IsA("BasePart") then
		app.worldFeel:Ring(root.Position-Vector3.new(0,2.6,0),{color=Color3.new(1,1,1),radius=3,seconds=0.4,thickness=0.2})
	end
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
	table.insert(self.connections,ProximityPromptService.PromptShown:Connect(function(prompt) self:Shown(prompt) end))
	table.insert(self.connections,ProximityPromptService.PromptTriggered:Connect(function(prompt) self:Triggered(prompt) end))
end

function Controller:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	for _,connection in self.watched do connection:Disconnect() end
	table.clear(self.watched)
	-- Do not restore legacy Custom styles on shutdown.
end

return Controller
