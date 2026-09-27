--!strict
-- Uses the authored board and cash-pad surfaces, preserving editable Studio art.
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.UITheme)
local Board = {}
Board.__index = Board
local EMPTY_PAD_COLOR = Color3.fromRGB(128, 128, 128)
local PAD_PRESS_DEPTH = 0.18
local PAD_STEP_SECONDS = 0.25 -- Visual tween duration; payout cadence is server-owned.
local PAD_RELEASE_SECONDS = 0.01
local PAD_MIN_HORIZONTAL_SPEED = 0.5 -- Match the server's cash-collection movement threshold.

local function padTween(view, key, seconds, goals, instant, repeats)
	if view[key] then view[key]:Cancel(); view[key]:Destroy(); view[key]=nil end
	if instant then
		for property,value in goals do view.pad[property]=value end
	else
		local info=TweenInfo.new(seconds,Enum.EasingStyle.Circular,Enum.EasingDirection.Out,if repeats then -1 else 0,repeats==true)
		view[key]=TweenService:Create(view.pad,info,goals)
		view[key]:Play()
	end
end

function Board.new(app)
	local groundRay=RaycastParams.new()
	groundRay.FilterType=Enum.RaycastFilterType.Exclude
	groundRay.RespectCanCollide=true
	return setmetatable({app=app,views={},connections={},alive=true,groundRay=groundRay},Board)
end

function Board:Bind(source)
	if not self.alive or self.views[source] or not source:IsA("SurfaceGui") then return end
	local world=workspace:FindFirstChild("PetRollWorld")
	if not world or not source:IsDescendantOf(world) then return end
	local board=source:FindFirstAncestor("EggCollectionBoard")
	if not board then return end
	local content=source:FindFirstChild("EggSellingBoard")
	if not content and source:GetAttribute("EggCashDisplay")~=true then return end
	local screen=if source.Parent:IsA("BasePart") then source.Parent else source.Adornee
	if not screen then return end
	local gui=source:Clone()
	gui.Name,gui.Adornee,gui.Active,gui.ResetOnSpawn="LiveEggBoard",screen,true,false
	local view={gui=gui,source=source,originalEnabled=source.Enabled,index=board:GetAttribute("PlotIndex"),connections={}}
	local root=gui:FindFirstChild("EggSellingBoard")
	if root then
		view.content=root.Content
		view.queuedTextSize=view.content.QueuedCount.TextSize
		for _,name in {"Upgrade","FinishNow"} do
			local button=view.content:FindFirstChild(name)
			if button then button.Visible=false;button.Active=false;button.Selectable=false end
		end
		local cost=view.content:FindFirstChild("UpgradeCost")
		if cost then cost.Visible=false end
		view.content.QueueLabel.Text="READY CASH"
		view.content.RateLabel.Text="SELLING"
	else
		view.cash=gui:FindFirstChild("ReadyCash",true)
		if view.cash then
			view.pad,view.padFrame,view.padColor=screen,screen.CFrame,screen.Color
		end
	end
	self.views[source]=view
	source.Enabled=false
	gui.Parent=self.playerGui
	Theme.BindStudTextures(gui)
	table.insert(view.connections,source.AncestryChanged:Connect(function()
		if not source:IsDescendantOf(workspace) then self:Unbind(source) end
	end))
	self:Render()
end

function Board:Unbind(source)
	local view=self.views[source]
	if not view then return end
	self.views[source]=nil
	for _,connection in view.connections do connection:Disconnect() end
	if view.pad then
		padTween(view,"pressTween",0,{CFrame=view.padFrame},true)
		padTween(view,"colorTween",0,{Color=view.padColor},true)
	end
	view.gui:Destroy()
	if source.Parent then source.Enabled=view.originalEnabled end
end

function Board:Render()
	local state=self.app.state
	local offer=state and state.eggs and state.eggs.processor
	for _,view in self.views do
		view.gui.Enabled=view.originalEnabled and offer~=nil and offer.enabled and view.index==state.plotIndex
		if not offer then continue end
		if view.cash then view.cash.Text="$"..Theme.Money(offer.readyCash) end
		if view.content then
			local c=view.content
			c.QueuedCount.Text="$"..Theme.Money(offer.readyCash)
			if not c.QueuedCount.TextScaled then
				-- Keep the Studio-authored headline size; shrink only if the full count cannot fit.
				local label=c.QueuedCount
				local scale=label:FindFirstChildWhichIsA("UIScale")
				local factor=if scale then scale.Scale else 1
				local width=TextService:GetTextSize(label.Text,view.queuedTextSize,label.Font,Vector2.new(10000,1000)).X
				local outline=label:FindFirstChildWhichIsA("UIStroke")
				local available=label.AbsoluteSize.X/math.max(factor,0.001)-(if outline then outline.Thickness*2 else 0)
				if available>0 then
					local size=math.min(view.queuedTextSize,math.max(12,math.floor(view.queuedTextSize*available/math.max(1,width))))
					-- Scaled font rasterization rounds differently from the base-size estimate.
					while size>12 and TextService:GetTextSize(label.Text,math.floor(size*factor),label.Font,Vector2.new(10000,1000)).X>available*factor do size-=1 end
					label.TextSize=size
				end
			end
			c.Rate.Text="Instant"
		end
	end
end

function Board:UpdatePad(view, root, humanoid)
	if not view.pad or not view.pad.Parent then return end
	local state=self.app.state
	local offer=state and state.eggs and state.eggs.processor
	local owned=offer~=nil and offer.enabled and view.index==state.plotIndex
	local ready=owned and offer.readyCash>0
	local color=if not owned then view.padColor elseif ready then view.padColor else EMPTY_PAD_COLOR
	local reduced=self.app.reducedMotion==true
	if view.targetColor~=color or view.reduced~=reduced then
		view.targetColor=color
		padTween(view,"colorTween",0.12,{Color=color},reduced)
	end
	local pressed=false
	local velocity=root and root.AssemblyLinearVelocity
	local moving=velocity~=nil and velocity.X^2+velocity.Z^2>PAD_MIN_HORIZONTAL_SPEED^2
	if owned and root and humanoid and humanoid.Health>0 and not reduced
		and moving
		and not humanoid.Jump and not humanoid.Sit and not humanoid.PlatformStand
		and humanoid.FloorMaterial~=Enum.Material.Air then
		local state=humanoid:GetState()
		if state~=Enum.HumanoidStateType.Jumping and state~=Enum.HumanoidStateType.Freefall then
			-- Require the actual supporting pad, not just the wider cash-claim region.
			self.groundRay.FilterDescendantsInstances={root.Parent}
			self.groundRay.CollisionGroup=root.CollisionGroup
			local reach=humanoid.HipHeight+root.Size.Y/2+2.5 -- Includes R6 leg height.
			local hit=workspace:Raycast(root.Position,Vector3.new(0,-reach,0),self.groundRay)
			pressed=hit~=nil and hit.Instance==view.pad
		end
	end
	if view.pressed~=pressed or view.reduced~=reduced then
		view.pressed=pressed
		local frame=if pressed then view.padFrame+Vector3.new(0,-PAD_PRESS_DEPTH,0) else view.padFrame
		padTween(view,"pressTween",if pressed then PAD_STEP_SECONDS else PAD_RELEASE_SECONDS,{CFrame=frame},reduced,pressed)
	end
	view.reduced=reduced
end

function Board:Receive(_result)
	self:Render()
end

function Board:Start()
	self.playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(self.connections,RunService.Heartbeat:Connect(function()
		local character=Players.LocalPlayer.Character
		local root=character and character:FindFirstChild("HumanoidRootPart")
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		for _,view in self.views do self:UpdatePad(view,root,humanoid) end
	end))
	table.insert(self.connections,workspace.DescendantAdded:Connect(function(item)
		if item:IsA("SurfaceGui") or item.Name=="EggSellingBoard" or item.Name=="ReadyCash" then
			task.defer(function()
				local source=if item:IsA("SurfaceGui") then item else item:FindFirstAncestorWhichIsA("SurfaceGui")
				if source then self:Bind(source) end
			end)
		end
	end))
	local world=workspace:FindFirstChild("PetRollWorld")
	if world then for _,item in world:GetDescendants() do if item:IsA("SurfaceGui") then self:Bind(item) end end end
end

function Board:Destroy()
	self.alive=false
	for _,connection in self.connections do connection:Disconnect() end
	local sources={}
	for source in self.views do table.insert(sources,source) end
	for _,source in sources do self:Unbind(source) end
end

return Board
