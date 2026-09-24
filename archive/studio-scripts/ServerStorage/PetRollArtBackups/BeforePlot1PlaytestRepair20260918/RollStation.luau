--!strict
-- One physical offer display. Economy, ownership and result selection stay server-owned.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.PetCatalog)
local Rules = require(Shared.Rules)
local Progression = require(Shared.Progression)
local PetView = require(Shared.PetView)
local UIColors = require(Shared.UIColors)
local Builder = require(script.Parent.WorldBuilder)
local RollStation = {}
RollStation.__index = RollStation
local colors = Builder.Palette

local function prompt(parent, name, key, text)
	local p = Instance.new("ProximityPrompt")
	p.Style = Enum.ProximityPromptStyle.Default
	p.Name, p.KeyboardKeyCode, p.ActionText = name, key, text
	p.ObjectText = "Your chicken roller"
	p.HoldDuration, p.MaxActivationDistance, p.RequiresLineOfSight = 0, 11, false
	p.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	p.Enabled, p.Parent = false, parent
	return p
end

local function offerLabel(parent, frame)
	local anchor = Builder.Part(parent, "OfferLabelAnchor", Vector3.one, frame * CFrame.new(0, 6, -3.5), colors.white, false)
	anchor.Transparency, anchor.CanQuery, anchor.CastShadow = 1, false, false
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Size = "OfferLabel", UDim2.fromOffset(300, 112)
	gui.AlwaysOnTop, gui.MaxDistance, gui.StudsOffset = true, 38, Vector3.new(0, 0, 0)
	gui.LightInfluence, gui.Parent = 0, anchor
	local label = Instance.new("TextLabel")
	label.Name, label.Size, label.BackgroundTransparency = "Text", UDim2.fromScale(1, 1), 1
	label.Font, label.TextSize, label.TextColor3 = Enum.Font.SourceSansBold, 21, UIColors.Text
	label.TextStrokeColor3, label.TextStrokeTransparency = UIColors.Border, 0.05
	label.Text, label.Parent = "PLOT AVAILABLE", gui
	return label
end

function RollStation.new(parent, frame, index, onAction)
	local self = setmetatable({frame = frame, index = index, connections = {}, bulbs = {},
		random = Random.new(index * 3157), revealAt = 0, readyAt = 0, lastVisualAt = 0}, RollStation)
	local model = Instance.new("Model")
	model.Name, model.Parent = "RollStation", parent
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("Rolling", false)
	self.model = model
	if parent:GetAttribute("AuthoredPlot") then
		local anchors={RollDisplay=parent:FindFirstChild("RollDisplay",true),RollLever=parent:FindFirstChild("RollLever",true)}
		self.frame=anchors.RollDisplay.CFrame;self.foot=anchors.RollDisplay.Position
		self.podium=Builder.Part(model,"Podium",Vector3.new(3,0.2,3),anchors.RollDisplay.CFrame,colors.cream,false)
		self.podium.Transparency,self.podium.CastShadow=1,false
		self.top=Builder.Part(model,"RevealPad",Vector3.new(2.4,0.03,2.4),anchors.RollDisplay.CFrame*CFrame.new(0,-0.01,0),colors.gold,false)
		self.top.Transparency=1
		self.leverBase=Builder.Part(model,"LeverBase",Vector3.one,anchors.RollLever.CFrame,colors.ink,false)
		self.leverBase.Transparency,self.leverBase.CastShadow=1,false
		self.leverPivot=anchors.RollLever.CFrame*CFrame.new(0,0.45,0)
		for _,part in parent.Spin.Level:GetChildren() do
			if part:IsA("BasePart") then
				if part.Color.R>0.8 and part.Color.G<0.1 then self.knob=part
				elseif part.Size.Y>0.7 and part.Size.X<0.3 then self.arm=part end
			end
		end
		assert(self.arm and self.knob,"Authored rolling lever parts missing")
		self.arm.Name,self.arm.Parent="LeverArm",model
		self.knob.Name,self.knob.Parent="LeverHandle",model
		self.armRest=self.leverPivot:ToObjectSpace(self.arm.CFrame)
		self.knobRest=self.leverPivot:ToObjectSpace(self.knob.CFrame)
	else
	-- The podium and kiosk shell are authored in Blender; retain moving gameplay parts.
	self.podium = Builder.Disk(model, "Podium", 4.9, 2.4, (frame * CFrame.new(0, 1.7, 0)).Position, colors.cream, true)
	self.podium.Transparency, self.podium.CastShadow = 1, false
	self.top = Builder.Disk(model, "RevealPad", 4.5, 0.12, (frame * CFrame.new(0, 3.08, 0)).Position, Color3.fromRGB(67, 181, 222), false)
	self.foot = (frame * CFrame.new(0, 3.18, 0)).Position
	model:SetAttribute("DisplayFrame", frame)
	model:SetAttribute("DisplayFoot", self.foot)
	self.leverBase = Builder.Part(model, "LeverBase", Vector3.new(3.3, 1.5, 3.3), frame * CFrame.new(6.1, 1.1, -5), colors.ink, true)
	self.leverBase.Transparency, self.leverBase.CastShadow = 1, false
	self.leverPivot = frame * CFrame.new(6.1, 1.85, -5)
	self.arm = Builder.Part(model, "LeverArm", Vector3.new(0.5, 2.8, 0.5), self.leverPivot * CFrame.new(0, 1.4, 0), colors.cream, false)
	self.knob = Builder.Part(model, "LeverHandle", Vector3.one * 1.5, self.leverPivot * CFrame.new(0, 2.8, 0), Color3.fromRGB(249, 107, 94), false)
	self.knob.Shape = Enum.PartType.Ball
	end
	self.armRest=self.armRest or CFrame.new(0,1.4,0)
	self.knobRest=self.knobRest or CFrame.new(0,2.8,0)
	model:SetAttribute("DisplayFrame",self.frame);model:SetAttribute("DisplayFoot",self.foot)
	model:SetAttribute("LeverPivot",self.leverPivot)
	model:SetAttribute("LeverArmRest",self.armRest);model:SetAttribute("LeverHandleRest",self.knobRest)
	self.label = offerLabel(model, if parent:GetAttribute("AuthoredPlot") then self.frame*CFrame.new(0,-1.5,3.5) else frame)
	-- The cylinder is rotated, so world-space emission uses a separate upright anchor.
	local emitterAnchor = Builder.Part(model, "EffectAnchor", Vector3.one, CFrame.new(self.foot + Vector3.new(0, 0.6, 0)), colors.white, false)
	emitterAnchor.Transparency, emitterAnchor.CanQuery, emitterAnchor.CastShadow = 1, false, false
	local attachment = Instance.new("Attachment")
	attachment.Parent = emitterAnchor
	local burst = Instance.new("ParticleEmitter")
	burst.Name, burst.Texture = "RevealSparkles", "rbxasset://textures/particles/sparkles_main.dds"
	burst.Rate, burst.Lifetime, burst.Speed = 0, NumberRange.new(0.45, 0.85), NumberRange.new(6, 11)
	burst.SpreadAngle, burst.Acceleration = Vector2.new(180, 180), Vector3.new(0, -8, 0)
	burst.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0)})
	burst.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1)})
	burst.LightEmission, burst.LightInfluence, burst.Parent = 0.4, 0, attachment
	self.burst = burst
	local light = Instance.new("PointLight")
	light.Name, light.Brightness, light.Range, light.Shadows = "RevealGlow", 0, 13, false
	light.Parent, self.light = emitterAnchor, light
	self.rollPrompt = prompt(self.leverBase, "RollPrompt", Enum.KeyCode.E, "Pull lever · FREE")
	self.rollPrompt.MaxActivationDistance=8
	self.buyPrompt = prompt(self.podium, "BuyPrompt", Enum.KeyCode.E, "Buy chicken")
	self.buyPrompt.MaxActivationDistance=6
	table.insert(self.connections, self.rollPrompt.Triggered:Connect(function(player) onAction(player, "Roll", index) end))
	table.insert(self.connections, self.buyPrompt.Triggered:Connect(function(player) onAction(player, "Buy", index, self.offer and self.offer.id) end))
	return self
end

function RollStation:SetPet(species)
	if self.pet then self.pet:Destroy() end
	self.pet = PetView.Create(self.model, "DisplayedPet", species, 1, self.foot)
	local tag = self.pet.PrimaryPart and self.pet.PrimaryPart:FindFirstChild("Tag")
	if tag then tag.Enabled = false end
	for _, p in self.pet:GetDescendants() do if p:IsA("BasePart") then p.CanQuery = false end end
	self.displayAt = os.clock()
	PetView.Move(self.pet, self.foot, self.frame.LookVector, 0)
end

function RollStation:Sync(session)
	self.ownerId = session.userId
 self.loaded = session.loaded==true and not session.closing and not session.saveLost
	if self.model:GetAttribute("OwnerId") ~= session.userId then
		self.model:SetAttribute("OwnerId", session.userId)
		self.model:SetAttribute("OwnerUserId", session.userId)
		self.rollPrompt.ObjectText = session.name .. "'s chicken roller"
		self.buyPrompt.ObjectText = session.name .. "'s offer"
	end
	self.readyAt, self.luck = session.rollReadyAt, session.luck
 self.recruitTier = session.recruitTier or session.promotion or 1
 local tier = Progression.Get(self.recruitTier)
 self.cosmeticSpecies = tier.pool
 self.model:SetAttribute("RecruitTier",self.recruitTier)
	self.incomeLevel = session.incomeLevel or 0
	self.flockFull = session:Count() >= Config.CollectionLimit
	self.coins=session.coins
 self.offerAdvice,self.offerImprovesArmy="",false
 if session.offer then self.offerAdvice,self.offerImprovesArmy=session:OfferAdvice(session.offer.species,session.offer.level) end
	local id = if session.offer then session.offer.id else "empty"
	if self.offerId == id then return end
	self.offerId, self.offer = id, session.offer
	self.revealAt, self.stage, self.landed = session.rollRevealAt, nil, false
	self.rollStartedAt = self.revealAt - Config.RollRevealSeconds
	self.model:SetAttribute("RevealedOfferId", nil)
	self.model:SetAttribute("RevealedSpecies", nil)
	-- Publish a shared cosmetic clock, not the hidden result. Clients animate locally.
	self.model:SetAttribute("RollStartedAt", workspace:GetServerTimeNow() - (os.clock() - self.rollStartedAt))
	self.model:SetAttribute("RollSeed", self.random:NextInteger(1, 1000000))
	self.model:SetAttribute("RollTier", if self.offer then self.offer.tier or self.recruitTier else self.recruitTier)
	self.model:SetAttribute("RollLuck", if self.offer then self.offer.luck or self.luck else self.luck)
	self.model:SetAttribute("RollId", if self.offer then self.offer.id else nil)
	if self.pet then self.pet:Destroy(); self.pet = nil end
	self:Step(os.clock(), true)
end

function RollStation:Step(now, force)
	if not self.ownerId then return end
	local rolling = self.offer ~= nil and now < self.revealAt
	local canRoll, canBuy = self.loaded and now >= self.readyAt, self.loaded and self.offer ~= nil and not rolling
	if self.rollPrompt.Enabled ~= canRoll then self.rollPrompt.Enabled = canRoll end
	if self.buyPrompt.Enabled ~= canBuy then self.buyPrompt.Enabled = canBuy end
	if self.model:GetAttribute("Rolling") ~= rolling then self.model:SetAttribute("Rolling", rolling) end
	local promptText = if canRoll then "Pull lever · FREE" else "Ready in " .. math.ceil(self.readyAt - now) .. "s"
	if self.rollPrompt.ActionText ~= promptText then self.rollPrompt.ActionText = promptText end
	-- Server owns prompts and the settled offer. Render-frame movement, sparkle
	-- timing and audio belong together in RollPresentationController.
	if not force and now - self.lastVisualAt < 0.1 then return end
	self.lastVisualAt = now
	if rolling then
		self.label.Text, self.label.TextColor3 = "", UIColors.Rewards
	elseif self.offer then
		local def = Catalog[self.offer.species]
		local level = self.offer.level or 1
		local price = self.offer.price or Rules.RecruitPrice(self.offer.species, level)
		local tint = Color3.fromRGB(table.unpack(def.color))
		if not self.landed then
			self:SetPet(self.offer.species); self.landed = true
			self.model:SetAttribute("RevealedSpecies", self.offer.species)
			self.model:SetAttribute("RevealedOfferId", self.offer.id)
		end
		local odds = self.offer.chance or Rules.Odds(self.offer.luck or self.luck,self.offer.tier or self.recruitTier)[self.offer.species] or 0
		self.label.Text = def.name .. " Lv " .. level .. "\n" .. (if self.offer.starter or self.offer.guaranteed or self.offer.debug then def.rarity else def.rarity .. " · " .. Rules.FormatOdds(odds))
			.. "\n$" .. price .. " · +$" .. Rules.Income(self.offer.species,1,level,self.incomeLevel) .. "/s"
			.. "\n" .. (if (self.coins or 0)<price then "Save for this · or roll FREE" else self.offerAdvice or "")
		self.label.TextColor3 = UIColors.Text
		local promptText = if self.flockFull then "Flock full · sell in Army or merge" else "Buy " .. def.name .. " · " .. price .. " coins"
		if self.buyPrompt.ActionText ~= promptText then self.buyPrompt.ActionText = promptText end
		self.top.Color = tint

	else
		self.label.Text, self.label.TextColor3 = Progression.Get(self.recruitTier).name, UIColors.Text
		self.top.Color, self.light.Brightness = Color3.fromRGB(67, 181, 222), 0
	end

end

function RollStation:Clear()
	self.ownerId, self.offer, self.offerId, self.loaded = nil, nil, nil, false
	if self.pet then self.pet:Destroy(); self.pet = nil end
	self.rollPrompt.Enabled, self.buyPrompt.Enabled, self.light.Brightness = false, false, 0
	self.label.Text, self.label.TextColor3 = "PLOT AVAILABLE", UIColors.Text
	self.top.Color = Color3.fromRGB(67, 181, 222)
	self.arm.CFrame, self.knob.CFrame = self.leverPivot * self.armRest, self.leverPivot * self.knobRest
	for _, name in {"OwnerId", "OwnerUserId", "RevealedOfferId", "RevealedSpecies", "RollStage", "RollId", "RollStartedAt", "RollSeed", "RollTier", "RollLuck"} do self.model:SetAttribute(name, nil) end
	self.model:SetAttribute("Rolling", false)
end

function RollStation:Destroy()
	for _, connection in self.connections do connection:Disconnect() end
	self.connections = {}
	self.model:Destroy()
end

return RollStation
