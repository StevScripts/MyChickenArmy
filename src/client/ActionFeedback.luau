--!strict
-- Local, short-lived feedback for confirmed actions. Never changes currency or rigs.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Feel = require(Shared.CollectionFeel)
local Motion = require(Shared.EggMotion)
local Theme = require(script.Parent.UITheme)
local Feedback = {}
Feedback.__index = Feedback
local GOLD = Theme.Colors.gold
local GREEN = Theme.Arcade.green
local random = Random.new()

function Feedback.new(app)
	return setmetatable({app = app, alive = false, flights = {}, cashEffects = {}, bursts = 0, last = {}, nextDeposit = 0, collectionSerial = 0}, Feedback)
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

function Feedback:Fly(image, start, goal, delay, duration, size, seed, arrive)
	if self.app.reducedMotion or #self.flights >= 24 then if arrive then arrive() end;return end
	local anchor = self:Anchor("ActionSprite", start)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.Adornee, gui.MaxDistance = UDim2.fromScale(size, size), anchor, 80
	gui.AlwaysOnTop, gui.LightInfluence, gui.Parent = false, 0, anchor
	gui.Enabled = false
	local icon = Instance.new("ImageLabel")
	icon.Size, icon.BackgroundTransparency, icon.Image = UDim2.fromScale(1, 1), 1, image
	icon.Parent = gui
	table.insert(self.flights, {anchor = anchor, gui = gui, icon = icon, start = start, goal = goal,
		at = os.clock() + delay, duration = duration, size = size, seed = seed, arrive = arrive})
	Debris:AddItem(anchor, delay + duration + 0.2)
end

-- User's CashDrop sequence: curved burst, then tween back and fade.
function Feedback:Cash(_position, confirm)
	if not self.alive then return end
	if confirm then confirm() end
	if self.app.reducedMotion then return end
	local root = self:Root()
	if not root then return end
	local assets = Shared.Parent:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("CashDrop")
	if not template or not template:IsA("BasePart") then
		warn("Cash effect needs ReplicatedStorage.PetRoll.Assets.CashDrop")
		return
	end
	if #self.cashEffects >= 3 then table.remove(self.cashEffects, 1):Destroy() end
	local group = Instance.new("Folder")
	group.Name, group.Parent = "CashPickup", self.folder
	local origin = root.Position
	local parts, tweens, outwardTweens, connections = {}, {}, {}, {}
	local returning = false
	local rootGone = root.Destroying:Once(function() group:Destroy() end)
	table.insert(self.cashEffects, group)
	group.Destroying:Once(function()
		rootGone:Disconnect()
		for _, connection in connections do connection:Disconnect() end
		for _, tween in tweens do tween:Cancel(); tween:Destroy() end
		local index = table.find(self.cashEffects, group)
		if index then table.remove(self.cashEffects, index) end
	end)

	for _ = 1, Feel.Cash.Count do
		local cashDrop = template:Clone()
		cashDrop.Anchored = true
		cashDrop.CanCollide, cashDrop.CanTouch, cashDrop.CanQuery = false, false, false
		cashDrop.Position = origin
		cashDrop.Parent = group
		table.insert(parts, cashDrop)

		local randomUnitVector = random:NextUnitVector() * Vector3.new(1, 0, 1)
		local middle = origin + randomUnitVector * 3 + Vector3.new(0, 1, 0)
		local finish = origin + randomUnitVector * 6 - Vector3.new(0, 2.5, 0)
		-- BezierTween isn't installed: tween a scalar along the same three waypoints.
		local progress = Instance.new("NumberValue")
		progress.Name, progress.Parent = "CurveProgress", cashDrop
		table.insert(connections, progress.Changed:Connect(function(t)
			if returning or not group.Parent then return end
			cashDrop.Position = origin:Lerp(middle, t):Lerp(middle:Lerp(finish, t), t)
		end))
		local outward = TweenService:Create(progress,
			TweenInfo.new(Feel.Cash.OutSeconds, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
			{Value = 1})
		table.insert(tweens, outward)
		table.insert(outwardTweens, outward)
		outward:Play()
	end

	task.delay(Feel.Cash.ReturnDelay, function()
		if not group.Parent then return end
		if not root.Parent then group:Destroy(); return end
		-- Stop the curve before returning so two animations never fight over Position.
		returning = true
		for _, tween in outwardTweens do tween:Cancel() end
		for _, connection in connections do connection:Disconnect() end
		for _, part in parts do
			local imageLabel = (part :: any).BillboardGui.ImageLabel
			local fade = TweenService:Create(imageLabel,
				TweenInfo.new(Feel.Cash.InSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ImageTransparency = 1})
			local inward = TweenService:Create(part,
				TweenInfo.new(Feel.Cash.InSeconds, Enum.EasingStyle.Exponential, Enum.EasingDirection.In),
				{Position = root.Position})
			table.insert(tweens, fade); table.insert(tweens, inward)
			fade:Play()
			inward:Play()
		end
		task.delay(Feel.Cash.InSeconds + 0.05, function() group:Destroy() end)
	end)
	Debris:AddItem(group, Feel.Cash.ReturnDelay + Feel.Cash.InSeconds + 0.15)
end

function Feedback:ClearCash()
	while #self.cashEffects > 0 do table.remove(self.cashEffects):Destroy() end
end

function Feedback:CashReward(receipt)
	-- Exact server receipt amount; never infer this from wallet deltas.
	local pending=self.cashPending or {value=0,at=os.clock()+0.06}
	pending.value+=receipt.value
	pending.position=Vector3.new(receipt.x,receipt.y,receipt.z)
	self.cashPending=pending
end

function Feedback:ShowCash(position,value)
	local serial=self.collectionSerial
	self:Cash(position,function()
		if not self.alive or serial~=self.collectionSerial then return end
		self.app.audio:Play("CashTick",1,{volume=Feel.Cash.Volume,maxDuration=0.7,voiceKey="CashPayoff",maxVoices=3,cooldown=0.08})
		local root=self:Root()
		if self.app.reducedMotion then
			self:Amount(if root then root.Position+Vector3.new(0,3.8,0) else position+Vector3.new(0,2,0),value)
		end
	end)
end

function Feedback:Deposit(receipt)
	-- A player standing on the pad can deposit many tiny bags. Group presentation,
	-- keeping exact confirmed totals and the distinction between queued and paid.
	if not self.depositPending then self.depositPending={};self.nextDeposit=math.max(self.nextDeposit,os.clock()+Feel.Deposit.GroupWindow) end
	local key=(if receipt.queued then "queue" else "paid")..(receipt.collector or "player")
	local pending = self.depositPending[key] or {value = 0, count = 0, queued=receipt.queued,collector=receipt.collector}
	pending.value += receipt.value
	pending.count += receipt.count
	pending.targetX,pending.targetY,pending.targetZ=receipt.targetX,receipt.targetY,receipt.targetZ
	self.depositPending[key] = pending
end

function Feedback:ShowDeposit(receipt)
	local root = self:Root()
	if not root then
		self.app:Notify(if receipt.queued then "Deposited "..Theme.Money(receipt.count).." eggs" else "+$"..Theme.Money(receipt.value),true)
		return
	end
	local state = self.app.state
	local world = workspace:FindFirstChild("PetRollWorld")
	local plot = world and state and state.plotIndex and world:FindFirstChild("Plot" .. state.plotIndex)
	local pad = plot and plot:FindFirstChild("sellpart", true)
	local position = if receipt.targetX then Vector3.new(receipt.targetX,receipt.targetY,receipt.targetZ)
		elseif pad and pad:IsA("BasePart") then pad.Position + Vector3.new(0, pad.Size.Y / 2 + 0.15, 0)
		else root.Position - Vector3.new(0, 2.5, 0)
	local basket = position + Vector3.new(0, 1.6, 0)
	local serial=self.collectionSerial
	local function contact()
		if not self.alive or serial~=self.collectionSerial then return end
		self.app.audio:Play("EggDeposit",1.12,{volume=Feel.Deposit.Volume,maxDuration=0.35,voiceKey="EggDeposit",maxVoices=3,cooldown=0.1})
		if receipt.queued then self.app:Notify("Deposited "..Theme.Money(receipt.count).." eggs",true)
		else self:ShowCash(basket,receipt.value) end
	end
	if receipt.collector=="rover" then contact();return end
	local count=math.clamp(receipt.count,1,Feel.Deposit.MaxSprites)
	for i=1,count do
		self:Fly(Config.EggSpriteImage,root.Position+Vector3.new((i%3-1)*0.35,0.5,0),
			function() return basket end,(i-1)*Feel.Deposit.Stagger,Feel.Deposit.FlightSeconds,0.9,i,
			if i==count then contact else nil)
	end
end

function Feedback:Action(kind)
	if not self.alive or os.clock() - (self.last[kind] or -10) < 0.2 then return end
	self.last[kind] = os.clock()
	local root = self:Root()
	if kind == "Sell" then
		local function arrive()
			self.app.audio:Play("CashTick",1,{volume=Feel.Cash.Volume,maxDuration=0.7,voiceKey="Sale",maxVoices=3})
		end
		if root then self:Cash(root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1, 0),arrive) else arrive() end
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
	if self.cashPending and now>=self.cashPending.at then
		local pending=self.cashPending;self.cashPending=nil
		self:ShowCash(pending.position,pending.value)
	end
	if self.depositPending and now >= self.nextDeposit then
		local pending = self.depositPending
		self.depositPending, self.nextDeposit = nil, now + Feel.Deposit.GroupGap
		for _,receipt in pending do self:ShowDeposit(receipt) end
	end
	for i = #self.flights, 1, -1 do
		local flight = self.flights[i]
		local alpha = (now - flight.at) / flight.duration
		if not flight.anchor.Parent or alpha >= 1 or self.app.reducedMotion then
			flight.anchor:Destroy();table.remove(self.flights, i)
			if flight.arrive then flight.arrive() end
		elseif alpha >= 0 then
			flight.gui.Enabled = true
			flight.anchor.Position = Motion.Flight(flight.start, flight.goal(), alpha, flight.seed, false)
			local scale = 1 - math.clamp((alpha - 0.7) / 0.3, 0, 1) * 0.75
			flight.gui.Size = UDim2.fromScale(flight.size * scale, flight.size * scale)
			flight.icon.Rotation = math.sin(alpha * math.pi) * (if flight.seed % 2 == 0 then 18 else -18)
		end
	end
	if self.app.reducedMotion then self:ClearCash() end
end

function Feedback:ResetCollections()
	self.collectionSerial+=1
	self.depositPending,self.cashPending=nil,nil
	self.nextDeposit=0
	for _,flight in self.flights do flight.anchor:Destroy() end
	self:ClearCash()
	table.clear(self.flights)
end

function Feedback:Destroy()
	self.alive = false
	if self.connection then self.connection:Disconnect() end
	self:ResetCollections()
	if self.folder then self.folder:Destroy() end
	table.clear(self.flights)
	self.depositPending = nil
end

return Feedback
