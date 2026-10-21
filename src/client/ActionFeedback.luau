--!strict
-- Local, short-lived feedback for confirmed actions. Never changes currency or rigs.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.PetRoll.Shared
local Feel = require(Shared.CollectionFeel)
local Theme = require(script.Parent.UITheme)
local CoinBurst = require(script.Parent.CoinBurst)
local Feedback = {}
Feedback.__index = Feedback
local GOLD = Theme.Colors.gold
local GREEN = Theme.Arcade.green

function Feedback.new(app)
	return setmetatable({app = app, alive = false, depositEffects = {}, cashEffects = {}, conquestEffects = {}, bursts = 0, last = {}, nextDeposit = 0, collectionSerial = 0,
		coinBurst = CoinBurst.new(), coinsHeld = 0, holdUntil = 0}, Feedback)
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
	gui.Name, gui.Adornee, gui.Size = "CashReceived", anchor, UDim2.fromOffset(260, 50)
	gui.MaxDistance, gui.AlwaysOnTop, gui.Parent = 80, true, anchor
	-- October 20: the gold coin stands in for the old "$".
	local _, label, icon = Theme.CoinAmount(gui, "CoinAmount", "+" .. Theme.Money(value), 32, GOLD)
	if not self.app.reducedMotion then
		TweenService:Create(anchor, TweenInfo.new(1), {Position = position + Vector3.new(0, 2, 0)}):Play()
		TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.75),
			{TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		TweenService:Create(icon, TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.75),
			{ImageTransparency = 1}):Play()
		for _, child in label:GetDescendants() do
			local goals = if child:IsA("UIStroke") then {Transparency = 1}
				elseif child:IsA("TextLabel") then {TextTransparency = 1, TextStrokeTransparency = 1} else nil
			if goals then TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.75), goals):Play() end
		end
	end
	Debris:AddItem(anchor, 1.1)
end

-- Emit the authored Money attachment at the collecting player's root.
function Feedback:Cash(_position, confirm)
	if not self.alive then return end
	if confirm then confirm() end
	if self.app.reducedMotion then return end
	local root = self:Root()
	if not root or not root:IsA("BasePart") then return end
	local assets = Shared.Parent:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("Money")
	if not template or not template:IsA("Attachment") then
		warn("Coin effect needs ReplicatedStorage.PetRoll.Assets.Money")
		return
	end
	if #self.cashEffects >= 3 then table.remove(self.cashEffects, 1):Destroy() end
	local effect = template:Clone()
	-- Imported attachment coordinates must not offset the burst from the player.
	effect.CFrame = CFrame.identity
	local emitters = {}
	for _, child in effect:GetDescendants() do
		if child:IsA("ParticleEmitter") then
			child.Enabled = false
			table.insert(emitters, child)
		end
	end
	effect.Parent = root
	table.insert(self.cashEffects, effect)
	effect.Destroying:Once(function()
		local index = table.find(self.cashEffects, effect)
		if index then table.remove(self.cashEffects, index) end
	end)
	Debris:AddItem(effect, Feel.Cash.Lifetime)
	for _, emitter in emitters do emitter:Emit(Feel.Cash.Count) end
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
		self.app.audio:Play("CashTick",1,{volume=Feel.Cash.Volume,voiceKey="CashPayoff",maxVoices=3,cooldown=0.08})
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
	local pending = self.depositPending[key] or {value = 0, count = 0, held = 0, queued=receipt.queued,collector=receipt.collector}
	pending.value += receipt.value
	pending.count += receipt.count
	if receipt.targetX then pending.origin=Vector3.new(receipt.targetX,receipt.targetY,receipt.targetZ) end
	-- A player's sale waits for its coin burst. Held here, before this snapshot
	-- reaches the HUD, so the Coins readout never jumps ahead of the coins.
	if self.alive and not receipt.queued and receipt.collector~="rover" and not self.app.reducedMotion then
		pending.held += receipt.value
		self:HoldCoins(receipt.value)
	end
	self.depositPending[key] = pending
end

-- October 20 coin burst: held Coins stay out of the HUD readout until their coins
-- land (HudController:ShownCoins). Display only; the server has already paid.
function Feedback:CoinsInFlight()
	return self.coinsHeld
end

function Feedback:HoldCoins(value: number)
	if value <= 0 then return end
	self.coinsHeld += value
	self.holdUntil = math.max(self.holdUntil, os.clock() + Feel.CoinBurst.HoldTimeout)
end

function Feedback:ReleaseCoins(value: number?)
	if not value or value <= 0 or self.coinsHeld <= 0 then return end
	self.coinsHeld = math.max(0, self.coinsHeld - value)
	if self.app.hud then self.app.hud:RefreshCoins() end
end

function Feedback:ReleaseAllCoins()
	self.coinBurst:Clear()
	if self.coinsHeld <= 0 then return end
	self.coinsHeld = 0
	if self.alive and self.app.hud then self.app.hud:RefreshCoins() end
end

-- Each coin carries an equal share of the held sale and counts into the HUD as it lands.
function Feedback:SaleCoins(receipt)
	if receipt.held <= 0 or not receipt.origin or self.app.reducedMotion then return false end
	local state = self.app.state
	local played = self.coinBurst:Play(receipt.origin, receipt.held, receipt.count, state and state.plotIndex, function(share: number, index: number, quiet: boolean)
		self:ReleaseCoins(share)
		if quiet or not self.alive then return end
		local tick = Feel.CoinBurst
		local audio = self.app.audio
		-- The bright shimmer under the bubble flash, then a quick ting per coin.
		if index == 1 then audio:Play("CashTick",1,{volume=Feel.Cash.Volume,voiceKey="CashPayoff",maxVoices=3,cooldown=0.08}) end
		local pitch = math.min(tick.PitchMax,1+(index-1)*tick.PitchStep)+(math.random()*2-1)*tick.PitchJitter
		-- "CoinPickup" is authored in SoundService.MyChickenArmyAudio; older places lack it.
		audio:Play(if audio.templates.CoinPickup then "CoinPickup" else "Collect",pitch,
			{volume=tick.TickVolume,maxDuration=0.5,voiceKey="SaleCoin",maxVoices=4,cooldown=0.03})
	end)
	if played then
		self.holdUntil = math.max(self.holdUntil, os.clock() + Feel.CoinBurst.HoldTimeout)
		-- Coins spilling out of the pad. "CoinDrop" is authored in SoundService.MyChickenArmyAudio.
		self.app.audio:Play("CoinDrop",1,{noFallback=true,volume=Feel.CoinBurst.DropVolume,
			maxDuration=Feel.CoinBurst.DropSeconds,voiceKey="SaleCoinDrop",maxVoices=2,cooldown=0.15})
	end
	return played
end

function Feedback:DepositBurst(root: BasePart)
	if not self.alive or self.app.reducedMotion then return end
	-- Stepping on the pad: the pickup bubble and a gold ring at the feet, at once.
	self.coinBurst:Flash(root)
	self:Burst(root.Position - Vector3.new(0, 2.5, 0), GOLD, true)
	local template = ReplicatedStorage:FindFirstChild("EggDepositEffects")
	if not template or not template:IsA("Attachment") then
		-- Optional extra particles; the bubble and ring above play without it.
		-- Once per session: the place has shipped without this template before.
		if not self.warnedDeposit then
			self.warnedDeposit = true
			warn("Egg deposit effect needs ReplicatedStorage.EggDepositEffects")
		end
		return
	end
	local effect = template:Clone()
	effect.CFrame = CFrame.identity
	local emitters = {}
	for _, child in effect:GetDescendants() do
		if child:IsA("ParticleEmitter") then
			child.Enabled = false
			table.insert(emitters, child)
		end
	end
	effect.Parent = root
	table.insert(self.depositEffects, effect)
	effect.Destroying:Once(function()
		local index = table.find(self.depositEffects, effect)
		if index then table.remove(self.depositEffects, index) end
	end)
	Debris:AddItem(effect, Feel.Deposit.Lifetime)
	for _, emitter in emitters do emitter:Emit(Feel.Deposit.Count) end
end

function Feedback:ClearDeposits()
	while #self.depositEffects > 0 do table.remove(self.depositEffects):Destroy() end
end

function Feedback:ShowDeposit(receipt)
	-- Automatic deliveries keep their rover-local unload/amount feedback; they
	-- must not celebrate at the player every time the machine reaches the pad.
	if not self.alive or receipt.collector=="rover" then return end
	local root = self:Root()
	if not root or not root:IsA("BasePart") then
		self:ReleaseCoins(receipt.held)
		self.app:Notify(if receipt.queued then "Deposited "..Theme.Money(receipt.count).." eggs" else "+"..Theme.Coins(receipt.value),true)
		return
	end
	self:DepositBurst(root)
	self.app.audio:Play("EggDeposit",1.12,{volume=Feel.Deposit.Volume,maxDuration=0.35,voiceKey="EggDeposit",maxVoices=3,cooldown=0.1})
	if receipt.queued then self.app:Notify("Deposited "..Theme.Money(receipt.count).." eggs",true)
	elseif not self:SaleCoins(receipt) then
		-- No burst (reduced motion, coin budget, far away): the Money burst or "+N" text as before.
		self:ReleaseCoins(receipt.held)
		self:ShowCash(root.Position,receipt.value)
	end
end

function Feedback:Action(kind)
	if not self.alive or os.clock() - (self.last[kind] or -10) < 0.2 then return end
	self.last[kind] = os.clock()
	local root = self:Root()
	if kind == "Sell" then
		local function arrive()
			self.app.audio:Play("CashTick",1,{volume=Feel.Cash.Volume,voiceKey="Sale",maxVoices=3})
		end
		if root then self:Cash(root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1, 0),arrive) else arrive() end
		return
	end
	local color = if kind == "Buy" then GOLD elseif kind == "Expand" then GREEN else Theme.Arcade.blue
	if root then self:Burst(root.Position - Vector3.new(0, 2.5, 0), color, kind == "Promote") end
	if kind == "Buy" then
		self.app.audio:Play("UIPurchase", nil, {noFallback=true,voiceKey = "ChickenPurchase", maxVoices = 3})
	elseif kind=="Expand" or kind=="Income" or kind=="Luck" then
		self.app.audio:Play("UIPurchase",nil,{noFallback=true,voiceKey="ActionSuccess"})
	else
		self.app.audio:Play("RollReveal", 1.12,
			{volume = 0.35, maxDuration = 0.85, voiceKey = "ActionSuccess"})
	end
end

function Feedback:Conquer(position, captureRadius)
	if not self.alive then return end
	self.app.audio:Play("Victory", 1, {volume = 0.35, maxDuration = 2, voiceKey = "CaptureVictory"})
	local root=self:Root()
	if self.app.reducedMotion or self.bursts>=6 or not root or (root.Position-position).Magnitude>180 then return end
	self.bursts+=1
	local style=Theme.Conquest
	local radius=(captureRadius or 7.8)*style.BurstRadiusMultiplier
	local anchor=self:Anchor("ConquestCelebration",position+Vector3.new(0,2,0))
	self.conquestEffects[anchor]=true
	anchor.Size=Vector3.new(radius*1.6,0.3,radius*1.6)
	local sphere=Instance.new("Part")
	sphere.Name,sphere.Shape="ConquestGlow",Enum.PartType.Ball
	sphere.Anchored,sphere.CanCollide,sphere.CanTouch,sphere.CanQuery,sphere.CastShadow=true,false,false,false,false
	sphere.Color,sphere.Material,sphere.Transparency=style.Owned,Enum.Material.Neon,0.84
	sphere.Size,sphere.CFrame,sphere.Parent=Vector3.one*radius,anchor.CFrame,anchor
	TweenService:Create(sphere,TweenInfo.new(style.BurstSeconds,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
		{Size=Vector3.one*radius*2.5,Transparency=1}):Play()
	local sparks=Instance.new("ParticleEmitter")
	sparks.Name,sparks.Texture="ConquestStars","rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color=ColorSequence.new(style.Owned,Color3.new(1,1,0.65))
	sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.7),NumberSequenceKeypoint.new(0.2,1.7),NumberSequenceKeypoint.new(1,0)})
	sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.1),NumberSequenceKeypoint.new(0.6,0.15),NumberSequenceKeypoint.new(1,1)})
	sparks.Lifetime,sparks.Speed,sparks.SpreadAngle=NumberRange.new(1.3,style.BurstSeconds),NumberRange.new(3,8),Vector2.new(70,70)
	sparks.Acceleration,sparks.LightEmission,sparks.Rate=Vector3.new(0,2,0),1,0
	sparks.Parent=anchor;sparks:Emit(style.SparkleCount)
	local ring=Instance.new("CylinderHandleAdornment")
	ring.Name,ring.Adornee,ring.Parent="ConquestRing",anchor,anchor
	ring.Radius,ring.InnerRadius,ring.Height=radius*0.6,radius*0.6-0.2,0.04
	ring.CFrame,ring.Color3,ring.Transparency=CFrame.new(0,-1.8,0)*CFrame.Angles(math.pi/2,0,0),style.Owned,0.2
	TweenService:Create(ring,TweenInfo.new(1.1,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
		{Radius=radius,InnerRadius=radius-0.15,Transparency=1}):Play()
	Debris:AddItem(anchor,style.BurstSeconds+0.2)
	self:Later(style.BurstSeconds+0.2,function()
		self.conquestEffects[anchor]=nil
		self.bursts=math.max(0,self.bursts-1)
	end)
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
	-- A lost coin (destroyed character, long hitch) never keeps Coins out of the HUD.
	if self.coinsHeld>0 and now>=self.holdUntil then self:ReleaseAllCoins() end
	if self.app.reducedMotion then
		if self.coinsHeld>0 or self.coinBurst.active>0 then self:ReleaseAllCoins() end
		self:ClearCash();self:ClearDeposits()
		for effect in self.conquestEffects do effect:Destroy();self.conquestEffects[effect]=nil end
	end
end

function Feedback:ResetCollections()
	self.collectionSerial+=1
	self.depositPending,self.cashPending=nil,nil
	self.nextDeposit=0
	self:ReleaseAllCoins()
	self:ClearCash()
	self:ClearDeposits()
end

function Feedback:Destroy()
	self.alive = false
	if self.connection then self.connection:Disconnect() end
	self:ResetCollections()
	if self.folder then self.folder:Destroy() end
	self.depositPending = nil
end

return Feedback
