--!strict
-- Local, short-lived feedback for confirmed actions. Never changes currency or rigs.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Motion = require(Shared.EggMotion)
local Theme = require(script.Parent.UITheme)
local Feedback = {}
Feedback.__index = Feedback
local GOLD = Theme.Colors.gold
local GREEN = Theme.Arcade.green

function Feedback.new(app)
	return setmetatable({app = app, alive = false, flights = {}, bursts = 0, last = {}, nextDeposit = 0}, Feedback)
end

function Feedback:Root()
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

function Feedback:Start()
	self.alive = true
	self.folder = Instance.new("Folder")
	self.folder.Name, self.folder.Parent = "PetRollActionFeedback", workspace
	self.connection = RunService.RenderStepped:Connect(function() self:Step(os.clock()) end)
end

function Feedback:Later(seconds, callback)
	task.delay(seconds, function()
		if self.alive and self.folder.Parent then callback() end
	end)
end

function Feedback:Anchor(name, position)
	local part = Instance.new("Part")
	part.Name, part.Size, part.Position = name, Vector3.one, position
	part.Anchored, part.Transparency = true, 1
	part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false
	part.Parent = self.folder
	return part
end

function Feedback:Burst(position, color, large)
	local root = self:Root()
	if not self.alive or self.app.reducedMotion or self.bursts >= 6
		or not root or (root.Position - position).Magnitude > 100 then return end
	self.bursts += 1
	local anchor = self:Anchor("ActionBurst", position)
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	local spark = Instance.new("ParticleEmitter")
	spark.Name, spark.Texture = "ActionSparkles", "rbxasset://textures/particles/sparkles_main.dds"
	spark.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	spark.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, if large then 0.65 else 0.4), NumberSequenceKeypoint.new(1, 0)})
	spark.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.25), NumberSequenceKeypoint.new(1, 1)})
	spark.Lifetime, spark.Speed = NumberRange.new(0.3, 0.65), NumberRange.new(4, if large then 12 else 7)
	spark.SpreadAngle, spark.Acceleration = Vector2.new(100, 100), Vector3.new(0, -9, 0)
	spark.Rate, spark.LightEmission, spark.Parent = 0, 0.65, attachment
	spark:Emit(if large then 24 else 12)
	-- Hollow ring: the ground and chickens remain visible inside it.
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Name, ring.Adornee, ring.Parent = "ActionRing", anchor, anchor
	ring.Radius, ring.InnerRadius, ring.Height = 0.8, 0.55, 0.025
	ring.CFrame, ring.Color3, ring.Transparency = CFrame.Angles(math.pi / 2, 0, 0), color, 0.25
	ring.AlwaysOnTop = false
	local radius = if large then 7 else 3.5
	TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Radius = radius, InnerRadius = radius - 0.2, Transparency = 1}):Play()
	Debris:AddItem(anchor, 1)
	self:Later(1, function() self.bursts = math.max(0, self.bursts - 1) end)
end

function Feedback:Amount(position, value)
	local anchor = self:Anchor("DepositValue", position)
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee, gui.Size = "CashReceived", anchor, UDim2.fromOffset(200, 50)
	gui.MaxDistance, gui.AlwaysOnTop, gui.Parent = 80, true, anchor
	local label = Theme.Display(gui, "Amount", "+$" .. Theme.Money(value), 32, GOLD)
	label.Size, label.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	if not self.app.reducedMotion then
		TweenService:Create(anchor, TweenInfo.new(1), {Position = position + Vector3.new(0, 2, 0)}):Play()
		TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.75),
			{TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		for _, child in label:GetDescendants() do
			local goals = if child:IsA("UIStroke") then {Transparency = 1}
				elseif child:IsA("TextLabel") then {TextTransparency = 1, TextStrokeTransparency = 1} else nil
			if goals then TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.75), goals):Play() end
		end
	end
	Debris:AddItem(anchor, 1.1)
end

function Feedback:Fly(image, start, goal, delay, duration, size, seed)
	if self.app.reducedMotion or #self.flights >= 24 then return end
	local anchor = self:Anchor("ActionSprite", start)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.Adornee, gui.MaxDistance = UDim2.fromScale(size, size), anchor, 80
	gui.AlwaysOnTop, gui.LightInfluence, gui.Parent = false, 0, anchor
	gui.Enabled = false
	local icon = Instance.new("ImageLabel")
	icon.Size, icon.BackgroundTransparency, icon.Image = UDim2.fromScale(1, 1), 1, image
	icon.Parent = gui
	table.insert(self.flights, {anchor = anchor, gui = gui, icon = icon, start = start, goal = goal,
		at = os.clock() + delay, duration = duration, size = size, seed = seed})
	Debris:AddItem(anchor, delay + duration + 0.2)
end

function Feedback:Cash(position, count)
	local root = self:Root()
	if not root then return end
	for i = 1, count do
		local angle = i * math.pi * 2 / count
		self:Fly(Theme.Assets.Cash, position + Vector3.new(math.cos(angle), 0.3, math.sin(angle)), function()
			return if root.Parent then root.Position + Vector3.new(0, 0.8, 0) else position
		end, i * 0.035, 0.45, 1.15, i)
	end
end

function Feedback:Deposit(receipt)
	-- A player standing on the pad can deposit many tiny bags. Group presentation,
	-- keeping the exact sum of confirmed receipts; the server already paid them.
	local pending = self.depositPending or {value = 0, count = 0}
	pending.value += receipt.value
	pending.count += receipt.count
	self.depositPending = pending
end

function Feedback:ShowDeposit(receipt)
	local root = self:Root()
	if not root then self.app:Notify("+$" .. Theme.Money(receipt.value), true);return end
	local state = self.app.state
	local world = workspace:FindFirstChild("PetRollWorld")
	local plot = world and state and state.plotIndex and world:FindFirstChild("Plot" .. state.plotIndex)
	local pad = plot and plot:FindFirstChild("sellpart", true)
	local position = if pad and pad:IsA("BasePart") then pad.Position + Vector3.new(0, pad.Size.Y / 2 + 0.15, 0)
		else root.Position - Vector3.new(0, 2.5, 0)
	local basket = position + Vector3.new(0, 1.6, 0)
	if not self.app.reducedMotion then
		for i = 1, math.clamp(receipt.count, 3, 7) do
			self:Fly(Config.EggSpriteImage, root.Position + Vector3.new((i % 3 - 1) * 0.5, 0.8, 0),
				function() return basket end, i * 0.025, 0.35, 0.9, i)
		end
	end
	self.app.audio:Play("RollLand", 1.2, {volume = 0.18, maxDuration = 0.25, voiceKey = "DepositStart"})
	self:Later(if self.app.reducedMotion then 0 else 0.52, function()
		self:Burst(position, GOLD, false)
		self:Cash(basket, 6)
		self:Amount(if root.Parent then root.Position + Vector3.new(0, 4, 0) else basket + Vector3.new(0, 2, 0), receipt.value)
		self.app.audio:Play("Collect", 1.12, {volume = 0.45, maxDuration = 0.7, voiceKey = "DepositCash"})
		self.app.audio:Play("RollReveal", 1.2, {volume = 0.2, maxDuration = 0.65, voiceKey = "DepositChime"})
		if self.app.hud then Theme.Motion:Pop(self.app.hud.cashIcon, 1.12) end
	end)
end

function Feedback:Action(kind)
	if not self.alive or os.clock() - (self.last[kind] or -10) < 0.2 then return end
	self.last[kind] = os.clock()
	local root = self:Root()
	if kind == "Sell" then
		if root then self:Cash(root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1, 0), 5) end
		self.app.audio:Play("Collect", 1.12, {volume = 0.4, maxDuration = 0.7, voiceKey = "Sale"})
		return
	end
	local color = if kind == "Buy" then GOLD elseif kind == "Expand" then GREEN else Theme.Arcade.blue
	if root then self:Burst(root.Position - Vector3.new(0, 2.5, 0), color, kind == "Promote") end
	self.app.audio:Play(if kind == "Buy" then "Pop" else "RollReveal", if kind == "Buy" then 1.08 else 1.12,
		{volume = 0.35, maxDuration = 0.85, voiceKey = "ActionSuccess"})
end

function Feedback:Conquer(position)
	self:Burst(position, GREEN, true)
	self.app.audio:Play("Victory", 1, {volume = 0.35, maxDuration = 2, voiceKey = "CaptureVictory"})
end

function Feedback:Step(now)
	if self.depositPending and now >= self.nextDeposit then
		local receipt = self.depositPending
		self.depositPending, self.nextDeposit = nil, now + 1.1
		self:ShowDeposit(receipt)
	end
	for i = #self.flights, 1, -1 do
		local flight = self.flights[i]
		local alpha = (now - flight.at) / flight.duration
		if not flight.anchor.Parent or alpha >= 1 or self.app.reducedMotion then
			flight.anchor:Destroy();table.remove(self.flights, i)
		elseif alpha >= 0 then
			flight.gui.Enabled = true
			flight.anchor.Position = Motion.Flight(flight.start, flight.goal(), alpha, flight.seed, false)
			local scale = 1 - math.clamp((alpha - 0.7) / 0.3, 0, 1) * 0.75
			flight.gui.Size = UDim2.fromScale(flight.size * scale, flight.size * scale)
			flight.icon.Rotation = math.sin(alpha * math.pi) * (if flight.seed % 2 == 0 then 18 else -18)
		end
	end
end

function Feedback:Destroy()
	self.alive = false
	if self.connection then self.connection:Disconnect() end
	if self.folder then self.folder:Destroy() end
	table.clear(self.flights)
	self.depositPending = nil
end

return Feedback
