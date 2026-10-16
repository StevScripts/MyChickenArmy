--!strict
-- World presentation/input only; CommerceController owns native checkout and
-- CommerceService remains the authority for verified ownership and benefits.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.UITheme)
local Stand = {}
Stand.__index = Stand

local PASS = "AutoCollectEggs"
local PRESS_DEPTH = 0.18
local COOLDOWN = 3
local SPIN_SECONDS = 16
local BOB_SECONDS = 1.8
local BOB_HEIGHT = 0.24
local MOTION_DISTANCE = 80
local PRICE_REFRESH_SECONDS = 120
local LABEL_DISTANCE = 55
-- {top, height} as billboard scale; small gaps keep outlines from touching.
local LABEL_ROWS = {Title = {0, 0.4}, Price = {0.43, 0.33}, Hint = {0.79, 0.21}}
local BUYING = {preparing = true, pending = true}

function Stand.new(app)
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.RespectCanCollide = true
	return setmetatable({app=app, views={}, connections={}, alive=true,
		groundRay=ray, nextPromptAt=0, nextPriceAt=0}, Stand)
end

function Stand:Bind(source)
	if self.views[source] or source:GetAttribute("AutoCollectStand") ~= true then return end
	local pad = source:FindFirstChild("AutoCollectPad")
	local preview = source:FindFirstChild("AutoCollectPreview")
	local anchor = source:FindFirstChild("OfferAnchor")
	local offer = anchor and anchor:FindFirstChild("AutoCollectOffer")
	local plot = source.Parent and source.Parent.Parent
	if not pad or not pad:IsA("BasePart") or not preview or not preview:IsA("Model")
		or not offer or not offer:IsA("BillboardGui") or not plot then return end
	local gui = offer:Clone()
	gui.Adornee, gui.Enabled, gui.ResetOnSpawn = anchor, true, false
	self:Layout(gui)
	gui.Parent = self.playerGui
	local view = {source=source, pad=pad, padFrame=pad.CFrame, preview=preview,
		previewFrame=preview:GetPivot(), gui=gui, offer=offer, offerEnabled=offer.Enabled,
		plot=plot, connections={}, alive=true, visitUsed=false, retried=false, glow={}}
	self.views[source] = view
	offer.Enabled = false
	for _,item in source:GetDescendants() do
		if item:IsA("ParticleEmitter") and item:GetAttribute("AutoCollectGlow") then
			table.insert(view.glow, {item=item, enabled=item.Enabled})
		end
	end
	view.yaw, view.bob = Instance.new("NumberValue"), Instance.new("NumberValue")
	local function pose()
		if view.alive then
			preview:PivotTo(view.previewFrame * CFrame.new(0, view.bob.Value, 0)
				* CFrame.Angles(0, math.rad(view.yaw.Value), 0))
		end
	end
	table.insert(view.connections, view.yaw.Changed:Connect(pose))
	table.insert(view.connections, view.bob.Changed:Connect(pose))
	view.spin = TweenService:Create(view.yaw, TweenInfo.new(SPIN_SECONDS, Enum.EasingStyle.Linear,
		Enum.EasingDirection.InOut, -1), {Value=360})
	view.hover = TweenService:Create(view.bob, TweenInfo.new(BOB_SECONDS, Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut, -1, true), {Value=BOB_HEIGHT})
	table.insert(view.connections, source.AncestryChanged:Connect(function()
		if not source:IsDescendantOf(self.world) then self:Unbind(source) end
	end))
end

-- The authored world-sized billboard shrinks with distance while its labels kept
-- a 10px minimum, so far away the three lines grew past their rows and overlapped.
-- Re-stack the local clone only: title, status, hint in fixed non-overlapping
-- rows that scale freely, hidden beyond reading distance.
function Stand:Layout(gui)
	gui.Size, gui.MaxDistance, gui.ClipsDescendants = UDim2.fromScale(6.2, 2.3), LABEL_DISTANCE, true
	-- A layout object would override the explicit rows below.
	for _, item in gui:GetChildren() do
		if item:IsA("UIGridStyleLayout") then item:Destroy() end
	end
	for name, row in LABEL_ROWS do
		local label = gui:FindFirstChild(name)
		if not label or not label:IsA("TextLabel") then continue end
		-- Centre-anchored (same rows) so a status pop grows from the middle.
		label.AnchorPoint, label.AutomaticSize = Vector2.new(0.5, 0.5), Enum.AutomaticSize.None
		label.Position, label.Size = UDim2.fromScale(0.5, row[1] + row[2]/2), UDim2.fromScale(1, row[2])
		label.TextScaled, label.TextWrapped = true, false
		label.TextXAlignment, label.TextYAlignment = Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
		local limit = label:FindFirstChildOfClass("UITextSizeConstraint")
		if limit then limit.MinTextSize = 1 end
	end
end

function Stand:SetMotion(view, enabled)
	if view.motion == enabled then return end
	view.motion = enabled
	if enabled then
		view.spin:Play(); view.hover:Play()
	else
		view.spin:Cancel(); view.hover:Cancel()
		view.yaw.Value, view.bob.Value = 0, 0
		view.preview:PivotTo(view.previewFrame)
	end
	for _,entry in view.glow do
		entry.item.Enabled = enabled and entry.enabled
		if not enabled then entry.item:Clear() end
	end
end

function Stand:SetPressed(view, pressed)
	local reduced = self.app.reducedMotion == true
	if view.pressed == pressed and view.reduced == reduced then return end
	view.pressed, view.reduced = pressed, reduced
	if view.press then view.press:Cancel(); view.press:Destroy(); view.press=nil end
	local goal = if pressed and not reduced then view.padFrame + Vector3.new(0, -PRESS_DEPTH, 0) else view.padFrame
	if reduced then view.pad.CFrame=goal; return end
	view.press = TweenService:Create(view.pad, TweenInfo.new(if pressed then 0.25 else 0.1,
		Enum.EasingStyle.Circular, Enum.EasingDirection.Out), {CFrame=goal})
	view.press:Play()
end

function Stand:Render(view, status, price)
	local text, hint, color = "Checking price…", "", Theme.Colors.muted
	if status == "owned" then
		text, color = "Owned", Theme.Colors.green
		local shop = self.app.state and self.app.state.shop
		hint = if shop and shop.automatic and shop.automatic[PASS] then "Auto Collect is on" else "Enable in Shop"
	elseif status == "ready" then
		text, color = utf8.char(0xE002).." "..Theme.Money(price), Theme.Colors.green
		hint = "Step on pad to buy"
	elseif status == "pending" or status == "preparing" then
		text = "Purchase pending…"
	elseif status == "checking" or status == "ownership" or status == "profile" then
		text = "Checking ownership…"
		if status ~= "checking" then hint="Step on pad to retry" end
	elseif status == "error" then
		text, hint = "Price unavailable", "Step on pad to retry"
	elseif status == "offsale" or status == "unconfigured" then
		text = "Unavailable"
	end
	view.gui.Price.Text, view.gui.Price.TextColor3 = text, color
	view.gui.Hint.Text = hint
	-- Pop on purchase steps only (checkout opens, then Owned); join-time checks
	-- and the periodic price refresh (loading -> ready) stay still.
	local previous = view.shownStatus
	if previous ~= status and ((BUYING[status] and previous ~= nil) or (status == "owned" and BUYING[previous])) then
		Theme.Motion:PopScale(view.gui.Price, 1.15)
	end
	view.shownStatus = status
end

function Stand:Contact(view, root, humanoid)
	if not root or not humanoid or humanoid.Health <= 0 then return false, false end
	local point = view.padFrame:PointToObjectSpace(root.Position)
	-- Jumping in place must not rearm checkout. Only leaving the footprint does.
	local inside = math.abs(point.X) <= view.pad.Size.X/2 + 0.4
		and math.abs(point.Z) <= view.pad.Size.Z/2 + 0.4
	if not inside or humanoid.Jump or humanoid.Sit or humanoid.PlatformStand
		or humanoid.FloorMaterial == Enum.Material.Air then return false, inside end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then return false, inside end
	self.groundRay.FilterDescendantsInstances = {root.Parent}
	self.groundRay.CollisionGroup = root.CollisionGroup
	local reach = humanoid.HipHeight + root.Size.Y/2 + 2.5
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), self.groundRay)
	return hit ~= nil and hit.Instance == view.pad, inside
end

function Stand:Visit(view, contact, inside, status, now, blocked)
	if not inside then view.visitUsed=false; view.retried=false; return end
	if not contact or view.visitUsed then return end
	-- Consuming a blocked entry prevents a surprise prompt when a menu closes.
	if blocked or now < self.nextPromptAt or status == "owned" then view.visitUsed=true; return end
	if status == "ready" then
		view.visitUsed = true
		self.nextPromptAt = now + COOLDOWN
		self.app.commerce:Buy(PASS)
	elseif not view.retried then
		view.retried = true
		if status == "error" then self.app.commerce:Load(PASS, true)
		elseif status == "ownership" or status == "profile" then self.app:Request("RefreshShop") end
	end
end

function Stand:Step()
	if not self.alive then return end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local state, commerce, now = self.app.state, self.app.commerce, os.clock()
	local pending = commerce.pending ~= nil
	if self.wasPending and not pending then self.nextPromptAt=now+COOLDOWN end
	self.wasPending = pending
	local status, price = commerce:State(PASS)
	local blocked = pending or self.app.panel.Visible or self.app.dialogueActive
		or UserInputService:GetFocusedTextBox() ~= nil
	for _,view in self.views do
		if view.character ~= character then
			view.character=character; view.visitUsed=false; view.retried=false
		end
		self:Render(view, status, price)
		local near = root ~= nil and (root.Position-view.padFrame.Position).Magnitude < MOTION_DISTANCE
		if near and now >= self.nextPriceAt and not pending and status ~= "owned" then
			self.nextPriceAt = now + PRICE_REFRESH_SECONDS
			commerce:Load(PASS) -- Reuse its cache/throttle; never substitute the catalog's proposed price.
		end
		self:SetMotion(view, near and not self.app.reducedMotion)
		local own = state ~= nil and view.plot:GetAttribute("PlotIndex") == state.plotIndex
		local contact, inside = false, false
		if own then contact, inside=self:Contact(view, root, humanoid) end
		self:SetPressed(view, contact)
		self:Visit(view, contact, inside, status, now, blocked)
	end
end

function Stand:Start(world)
	self.world, self.playerGui = world, Players.LocalPlayer:WaitForChild("PlayerGui")
	self.app.commerce:Load(PASS)
	self.nextPriceAt = os.clock() + PRICE_REFRESH_SECONDS
	for _,item in world:GetDescendants() do self:Bind(item) end
	table.insert(self.connections, world.DescendantAdded:Connect(function(item)
		local source = if item:GetAttribute("AutoCollectStand") then item else item:FindFirstAncestor("Gamepass")
		if source then task.defer(function()
			if self.alive and source:IsDescendantOf(world) then self:Bind(source) end
		end) end
	end))
end

function Stand:Unbind(source)
	local view = self.views[source]
	if not view then return end
	self.views[source], view.alive = nil, false
	for _,connection in view.connections do connection:Disconnect() end
	for _,tween in {view.spin, view.hover, view.press} do tween:Cancel(); tween:Destroy() end
	view.yaw:Destroy(); view.bob:Destroy(); view.gui:Destroy()
	if view.pad.Parent then view.pad.CFrame=view.padFrame end
	if view.preview.Parent then view.preview:PivotTo(view.previewFrame) end
	if view.offer.Parent then view.offer.Enabled=view.offerEnabled end
	for _,entry in view.glow do if entry.item.Parent then entry.item.Enabled=entry.enabled end end
end

function Stand:Destroy()
	self.alive = false
	for _,connection in self.connections do connection:Disconnect() end
	local sources = {}
	for source in self.views do table.insert(sources, source) end
	for _,source in sources do self:Unbind(source) end
end

return Stand
