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

function Feedback.new(app)
	return setmetatable({app = app, alive = false, flights = {}, cashBursts = {}, cashSerial = 0, bursts = 0, last = {}, nextDeposit = 0, collectionSerial = 0}, Feedback)
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

function Feedback:CashSprite(parent, position, bill)
	local anchor=self:Anchor(if bill then "LooseBill" else "CashBundle",position)
	anchor.Parent=parent
	local gui=Instance.new("BillboardGui")
	gui.Name,gui.Adornee,gui.Size="CashSprite",anchor,UDim2.fromScale(Feel.Cash.SpriteStuds,Feel.Cash.SpriteStuds)
	gui.AlwaysOnTop,gui.LightInfluence,gui.Brightness,gui.MaxDistance=false,0,2,100
	gui.Enabled,gui.Parent=false,anchor
	local face
	if bill then
		face=Instance.new("Frame")
		face.BackgroundColor3,face.BorderSizePixel=Color3.fromRGB(50,212,69),0
		face.Size=UDim2.fromScale(1,0.46)
		local outline=Instance.new("UIStroke")
		outline.Color,outline.Thickness,outline.Parent=Color3.fromRGB(13,66,29),1.5,face
		local band=Instance.new("Frame")
		band.Size,band.Position=UDim2.fromScale(0.3,1),UDim2.fromScale(0.35,0)
		band.BackgroundColor3,band.BorderSizePixel,band.Parent=Color3.fromRGB(255,206,42),0,face
	else
		face=Instance.new("ImageLabel")
		face.Size,face.BackgroundTransparency,face.Image=UDim2.fromScale(1,1),1,Theme.Assets.Cash
	end
	face.AnchorPoint,face.Position,face.Parent=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),gui
	local trails={}
	if not bill then
		local a,b=Instance.new("Attachment"),Instance.new("Attachment")
		a.Position,b.Position=Vector3.new(-Feel.Cash.TrailWidth/2,0,0),Vector3.new(Feel.Cash.TrailWidth/2,0,0)
		a.Parent,b.Parent=anchor,anchor
		for i=1,2 do
			local trail=Instance.new("Trail")
			trail.Attachment0,trail.Attachment1,trail.FaceCamera=a,b,true
			trail.Lifetime,trail.MinLength,trail.LightEmission=Feel.Cash.TrailSeconds,0,1
			trail.Color=ColorSequence.new(if i==1 then Color3.fromRGB(255,241,134) else Color3.new(1,1,1))
			trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,if i==1 then 0.65 else 0),NumberSequenceKeypoint.new(0.7,0.3),NumberSequenceKeypoint.new(1,1)})
			trail.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,if i==1 then 3 else 1),NumberSequenceKeypoint.new(1,0)})
			trail.Enabled,trail.Parent=false,anchor
			table.insert(trails,trail)
		end
	end
	return {anchor=anchor,gui=gui,face=face,trails=trails,bill=bill}
end

function Feedback:CashFlash(parent,position)
	local anchor=self:Anchor("CashFlash",position);anchor.Parent=parent
	local gui=Instance.new("BillboardGui")
	gui.Adornee,gui.Size,gui.LightInfluence,gui.Brightness=anchor,UDim2.fromScale(1,1),0,3
	-- Place the flash just camera-side of the torso, retaining world occlusion.
	gui.AlwaysOnTop,gui.Parent=false,anchor
	local flare=Instance.new("Frame")
	flare.BackgroundTransparency,flare.Size,flare.Parent=1,UDim2.fromScale(1,1),gui
	local layers={}
	local function layer(size,color,alpha,rotation,round)
		local frame=Instance.new("Frame")
		frame.AnchorPoint,frame.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
		frame.Size,frame.BackgroundColor3,frame.BackgroundTransparency=size,color,alpha
		frame.BorderSizePixel,frame.Rotation,frame.Parent=0,rotation,flare
		if round then local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=frame end
		table.insert(layers,{frame=frame,alpha=alpha})
		return frame
	end
	-- Native soft halo and tapered star rays avoid a particle-only DDS in an ImageLabel.
	for i=6,1,-1 do layer(UDim2.fromScale(i*0.10,i*0.10),Color3.fromRGB(255,232,20),0.82,0,true) end
	for i=1,8 do
		for j=1,2 do
			local ray=layer(UDim2.fromScale(if j==1 then 1 else 0.85,if j==1 then 0.08 else 0.025),
				if j==1 then Color3.fromRGB(255,236,35) else Color3.new(1,1,1),if j==1 then 0.3 else 0,i*22.5,false)
			local fade=Instance.new("UIGradient")
			fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.35,0.4),NumberSequenceKeypoint.new(0.5,0),NumberSequenceKeypoint.new(0.65,0.4),NumberSequenceKeypoint.new(1,1)})
			fade.Parent=ray
		end
	end
	layer(UDim2.fromScale(0.16,0.16),Color3.new(1,1,1),0,0,true)
	local ring=Instance.new("CylinderHandleAdornment")
	ring.Adornee,ring.Radius,ring.InnerRadius,ring.Height=anchor,0.6,0.52,0.025
	ring.CFrame=CFrame.new(0,-1.4,0)*CFrame.Angles(math.pi/2,0,0)
	ring.Color3,ring.Transparency,ring.Parent=Color3.fromRGB(255,222,35),0.25,anchor
	return {anchor=anchor,gui=gui,flare=flare,layers=layers,ring=ring}
end

function Feedback:Cash(position, count, onBurst)
	-- The reference celebrates payment at the player with an outward spray.
	-- Reward confirmation is immediate and independent of cosmetic lifetime.
	if onBurst then onBurst() end
	if self.app.reducedMotion or not self.alive then return end
	local root=self:Root()
	local origin=if root then root.Position+Vector3.new(0,0.1,0) else position
	if #self.cashBursts>=Feel.Cash.MaxBursts then
		self.cashBursts[1].folder:Destroy();table.remove(self.cashBursts,1)
	end
	self.cashSerial+=1
	local random=Random.new(self.cashSerial*7919)
	local folder=Instance.new("Folder");folder.Name="CashBurst";folder.Parent=self.folder
	local group={at=os.clock(),origin=origin,folder=folder,sprites={},flash=self:CashFlash(folder,origin)}
	local bundles=math.clamp(count,1,Feel.Cash.MaxSprites)
	local total=bundles+Feel.Cash.LooseBills
	for i=1,total do
		local bill=i>bundles
		local index=if bill then i-bundles else i
		local number=if bill then Feel.Cash.LooseBills else bundles
		local angle=index/number*math.pi*2+random:NextNumber(-0.15,0.15)
		local radius=random:NextNumber(Feel.Cash.MinRadius,Feel.Cash.MaxRadius)*(if bill then 0.7 else 1)
		local sprite=self:CashSprite(folder,origin,bill)
		sprite.offset=Vector3.new(math.cos(angle)*radius,random:NextNumber(-0.35,2.4),math.sin(angle)*radius)
		sprite.delay=(index-1)*Feel.Cash.Stagger
		sprite.lifetime=Feel.Cash.Lifetime+random:NextNumber(-0.08,0.08)
		sprite.size=Feel.Cash.SpriteStuds*random:NextNumber(0.85,1.15)*(if bill then 0.68 else 1)
		sprite.rotation=if bill then random:NextNumber(-40,40) else random:NextNumber(-12,12)
		sprite.spin=random:NextNumber(-80,80)
		table.insert(group.sprites,sprite)
	end
	-- Start after construction so the first rendered frame cannot skip the flash.
	group.at=os.clock()
	table.insert(self.cashBursts,group)
	Debris:AddItem(folder,Feel.Cash.Lifetime+0.5)
end

function Feedback:StepCash(now)
	for i=#self.cashBursts,1,-1 do
		local group=self.cashBursts[i]
		local elapsed=now-group.at
		if self.app.reducedMotion or not group.folder.Parent or elapsed>Feel.Cash.Lifetime+0.2 then
			group.folder:Destroy();table.remove(self.cashBursts,i);continue
		end
		local flash=group.flash
		local ft=math.clamp(elapsed/Feel.Cash.FlashSeconds,0,1)
		flash.gui.Enabled=ft<1
		local camera=workspace.CurrentCamera
		if camera then
			local toward=camera.CFrame.Position-flash.anchor.Position
			flash.gui.StudsOffsetWorldSpace=if toward.Magnitude>0.01 then toward.Unit*1.8 else Vector3.zero
		end
		local diameter=Feel.Cash.FlashStuds*(0.35+0.9*(1-(1-ft)^3))
		flash.gui.Size=UDim2.fromScale(diameter,diameter)
		for _,layer in flash.layers do layer.frame.BackgroundTransparency=layer.alpha+(1-layer.alpha)*ft*ft end
		flash.flare.Rotation=ft*35
		flash.ring.Radius=0.6+3*ft;flash.ring.InnerRadius=flash.ring.Radius-0.08
		flash.ring.Transparency=0.25+0.75*ft
		for _,sprite in group.sprites do
			local age=elapsed-sprite.delay
			local t=math.clamp(age/sprite.lifetime,0,1)
			sprite.gui.Enabled=age>=0 and t<1
			local shoot=math.clamp(age/Feel.Cash.BurstSeconds,0,1)
			local travel=1-(1-shoot)^3
			local drift=math.max(0,age-Feel.Cash.BurstSeconds)
			for _,trail in sprite.trails do trail.Enabled=age>=0 and shoot<1 end
			-- Keep this burst anchored where it happened while the player moves on.
			sprite.anchor.Position=group.origin+sprite.offset*travel+Vector3.new(0,-1.1*drift*drift,0)
			local fade=math.clamp((t-0.68)/0.32,0,1)
			local grow=math.min(1,math.max(0,age)/0.035)
			local size=sprite.size*grow*(1-fade*fade)
			sprite.gui.Size=UDim2.fromScale(size,size)
			sprite.face.Rotation=sprite.rotation+sprite.spin*age
		end
	end
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
	self:Cash(position,Feel.Cash.MaxSprites,function()
		if not self.alive or serial~=self.collectionSerial then return end
		self.app.audio:Play("CashTick",1,{volume=Feel.Cash.Volume,maxDuration=0.7,voiceKey="CashPayoff",maxVoices=3,cooldown=0.08})
		self.app.audio:Play("CashFinish",1.05,{volume=Feel.Cash.ChimeVolume,maxDuration=0.85,voiceKey="CashFinish",maxVoices=2,cooldown=0.25})
		local root=self:Root()
		if self.app.reducedMotion then
			self:Amount(if root then root.Position+Vector3.new(0,3.8,0) else position+Vector3.new(0,2,0),value)
		end
		if self.app.hud then Theme.Motion:Pulse(self.app.hud.cashIcon,Feel.Cash.HudPulse) end
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
		self:Burst(basket,if receipt.queued then GREEN else GOLD,false)
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
			if self.app.hud then Theme.Motion:Pulse(self.app.hud.cashIcon,Feel.Cash.HudPulse) end
		end
		if root then self:Cash(root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1, 0),5,arrive) else arrive() end
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
	self:StepCash(now)
end

function Feedback:ResetCollections()
	self.collectionSerial+=1
	self.depositPending,self.cashPending=nil,nil
	self.nextDeposit=0
	for _,flight in self.flights do flight.anchor:Destroy() end
	for _,group in self.cashBursts do group.folder:Destroy() end
	table.clear(self.flights);table.clear(self.cashBursts)
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
