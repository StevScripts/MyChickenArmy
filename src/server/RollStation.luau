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
	gui.Name, gui.Size = "OfferLabel", UDim2.fromOffset(340, 96)
	gui.AlwaysOnTop, gui.MaxDistance, gui.StudsOffset = true, 38, Vector3.new(0, 0, 0)
	gui.LightInfluence, gui.Enabled, gui.Parent = 0, false, anchor
	local function line(name, top, height, textSize)
		local label = Instance.new("TextLabel")
		label.Name, label.BackgroundTransparency = name, 1
		label.Position, label.Size = UDim2.fromOffset(0, top), UDim2.new(1, 0, 0, height)
		label.Font, label.TextSize, label.TextColor3 = Enum.Font.SourceSansBold, textSize, UIColors.Text
		label.Text, label.Parent = "", gui
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness, stroke.Transparency = UIColors.Border, 2, 0.05
		stroke.Parent = label
		return label
	end
	-- Fixed sizes keep short and long names consistent; rarity and price are the accents.
	local price = line("Price", 64, 30, 24)
	price.TextColor3 = UIColors.Money
	return gui, line("Text", 0, 34, 28), line("Rarity", 36, 28, 21), price
end

local function commas(value)
	return (tostring(math.floor(value)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- Stable authored names keep display identity independent of GetDescendants order.
function RollStation.DisplayAnchors(parent)
 local found={}
 for _,item in parent:GetDescendants() do
  if item.Name=="RollDisplay" and item:IsA("BasePart") then table.insert(found,item) end
 end
 table.sort(found,function(a,b)
  local ai=tonumber(a.Parent.Name:match("DisplayPodium(%d+)$")) or 1
  local bi=tonumber(b.Parent.Name:match("DisplayPodium(%d+)$")) or 1
  if ai~=bi then return ai<bi end
  return a:GetFullName()<b:GetFullName()
 end)
 return found
end

function RollStation.new(parent, frame, index, onAction, slot, display)
	slot=slot or 1
	local self = setmetatable({frame = frame, index = index, slot=slot, connections = {}, bulbs = {},
		random = Random.new(index * 3157 + slot * 7919), revealAt = 0, readyAt = 0, lastVisualAt = 0}, RollStation)
	local model = Instance.new("Model")
	model.Name, model.Parent = if slot==1 then "RollStation" else "RollStation"..slot, parent
	model:SetAttribute("IsRollStation",true)
	model:SetAttribute("RollSlot",slot)
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("Rolling", false)
	self.model = model
	if parent:GetAttribute("AuthoredPlot") then
		local anchors={RollDisplay=display or parent:FindFirstChild("RollDisplay",true),RollLever=parent:FindFirstChild("RollLever",true)}
		-- Additional stands are authored siblings, outside the runtime station model.
		-- Keep their original properties so unlocking restores the builder's art exactly.
		if slot>1 then
			self.standParts={}
			for _,part in anchors.RollDisplay.Parent:GetDescendants() do
				if part:IsA("BasePart") then
					table.insert(self.standParts,{part=part,transparency=part.Transparency,
						canCollide=part.CanCollide,canTouch=part.CanTouch,canQuery=part.CanQuery,castShadow=part.CastShadow})
				end
			end
		end
		self.frame=anchors.RollDisplay.CFrame;self.foot=anchors.RollDisplay.Position
		self.podium=Builder.Part(model,"Podium",Vector3.new(3,0.2,3),anchors.RollDisplay.CFrame,colors.cream,false)
		self.podium.Transparency,self.podium.CastShadow=1,false
		self.top=Builder.Part(model,"RevealPad",Vector3.new(2.4,0.03,2.4),anchors.RollDisplay.CFrame*CFrame.new(0,-0.01,0),colors.gold,false)
		self.top.Transparency=1
		if slot==1 then
		self.leverBase=Builder.Part(model,"LeverBase",Vector3.one,anchors.RollLever.CFrame,colors.ink,false)
		self.leverBase.Transparency,self.leverBase.CastShadow=1,false
		self.leverPivot=anchors.RollLever.CFrame*CFrame.new(0,0.45,0)
		local spin=parent:FindFirstChild("Spin",true)
		local lever=spin and spin:FindFirstChild("Level",true)
		assert(lever,"Authored roller needs its Level lever assembly inside Spin")
		-- Named roles survive builder resizing, recoloring and nested grouping.
		self.arm=lever:FindFirstChild("LeverArm",true)
		self.knob=lever:FindFirstChild("LeverHandle",true)
		-- Older unnamed plot templates still use the original art-based lookup.
		if not self.arm or not self.knob then
			for _,part in lever:GetDescendants() do
				if part:IsA("BasePart") then
					if not self.knob and part.Color.R>0.8 and part.Color.G<0.1 then self.knob=part
					elseif not self.arm and part.Size.Y>0.7 and part.Size.X<0.3 then self.arm=part end
				end
			end
		end
		assert(self.arm and self.arm:IsA("BasePart") and self.knob and self.knob:IsA("BasePart"),
			"Authored roller needs LeverArm and LeverHandle parts inside Spin.Level")
		self.arm.Name,self.arm.Parent="LeverArm",model
		self.knob.Name,self.knob.Parent="LeverHandle",model
		self.armRest=self.leverPivot:ToObjectSpace(self.arm.CFrame)
		self.knobRest=self.leverPivot:ToObjectSpace(self.knob.CFrame)
		end
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
	self.offerGui, self.label, self.rarityLabel, self.priceLabel = offerLabel(model, if parent:GetAttribute("AuthoredPlot") then self.frame*CFrame.new(0,-1.5,3.5) else frame)
	if #RollStation.DisplayAnchors(parent)>1 then
		-- World-sized labels stay inside their neighboring podium's footprint.
		self.offerGui.Size=UDim2.fromScale(5.6,1.8)
		self.label.Position,self.label.Size=UDim2.fromScale(0,0),UDim2.fromScale(1,0.38)
		self.rarityLabel.Position,self.rarityLabel.Size=UDim2.fromScale(0,0.39),UDim2.fromScale(1,0.3)
		self.priceLabel.Position,self.priceLabel.Size=UDim2.fromScale(0,0.69),UDim2.fromScale(1,0.31)
		self.label.TextScaled,self.rarityLabel.TextScaled,self.priceLabel.TextScaled=true,true,true
	end
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
	if slot==1 then
		self.rollPrompt=prompt(self.leverBase,"RollPrompt",Enum.KeyCode.E,"Pull lever · FREE")
		self.rollPrompt.MaxActivationDistance=8
		table.insert(self.connections,self.rollPrompt.Triggered:Connect(function(player) onAction(player,"Roll",index) end))
	end
	self.buyPrompt = prompt(self.podium, "BuyPrompt", Enum.KeyCode.E, "Buy chicken")
	self.buyPrompt.MaxActivationDistance=6
	table.insert(self.connections, self.buyPrompt.Triggered:Connect(function(player) onAction(player, "Buy", index, self.offer and self.offer.id) end))
	self:SetUnlocked(slot==1)
	return self
end

function RollStation:SetUnlocked(unlocked)
	if self.unlocked==unlocked then return end
	self.unlocked=unlocked
	self.model:SetAttribute("Unlocked",unlocked)
	for _,item in self.standParts or {} do
		local part=item.part
		part.Transparency=if unlocked then item.transparency else 1
		part.CanCollide=unlocked and item.canCollide
		part.CanTouch=unlocked and item.canTouch
		part.CanQuery=unlocked and item.canQuery
		part.CastShadow=unlocked and item.castShadow
	end
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
 self.loaded = session.loaded==true and not session.closing and not session.saveLost and self.slot<=(session.rollSlotCount or 1)
 self:SetUnlocked(self.slot<=(session.rollSlotCount or 1))
	if self.model:GetAttribute("OwnerId") ~= session.userId then
		self.model:SetAttribute("OwnerId", session.userId)
		self.model:SetAttribute("OwnerUserId", session.userId)
		if self.rollPrompt then self.rollPrompt.ObjectText=session.name.."'s chicken roller" end
		self.buyPrompt.ObjectText = session.name .. "'s offer"
	end
	self.readyAt, self.luck = session.rollReadyAt, session.luck
 self.recruitTier = session.recruitTier or session.promotion or 1
 self.cosmeticSpecies = Catalog.Order
 self.model:SetAttribute("RecruitTier",self.recruitTier)
	self.incomeLevel = session.incomeLevel or 0
	self.flockFull = session:Count() >= session:CollectionLimit()
	self.coins=session.coins
 self.offerAdvice,self.offerImprovesArmy="",false
 local offer=if self.loaded then session.offers and session.offers[self.slot] else nil
 if offer then self.offerAdvice,self.offerImprovesArmy=session:OfferAdvice(offer.species,offer.level) end
	local id = if offer then offer.id else "empty"
	if self.offerId == id then return end
	self.offerId, self.offer = id, offer
	self.revealAt, self.stage, self.landed = session.rollRevealAt, nil, false
	local duration = if offer then offer.duration or Config.RollRevealSeconds else Config.RollRevealSeconds
	self.rollStartedAt = self.revealAt - duration
	self.model:SetAttribute("RevealedOfferId", nil)
	self.model:SetAttribute("RevealedSpecies", nil)
	self.model:SetAttribute("RevealedMutation", nil)
	-- Publish a shared cosmetic clock, not the hidden result. Clients animate locally.
	self.model:SetAttribute("RollStartedAt", workspace:GetServerTimeNow() - (os.clock() - self.rollStartedAt))
	self.model:SetAttribute("RollDuration", duration)
	self.model:SetAttribute("RollPaidLuck", if offer then offer.paidLuck or 1 else 1)
	self.model:SetAttribute("RollResearchLuck", if offer then offer.researchLuck or 0 else 0)
	self.model:SetAttribute("RollSeed", self.random:NextInteger(1, 1000000))
	self.model:SetAttribute("RollTier", if self.offer then self.offer.tier or self.recruitTier else self.recruitTier)
	self.model:SetAttribute("RollLuck", if self.offer then self.offer.luck or self.luck else self.luck)
	self.model:SetAttribute("RollId", if self.offer then self.offer.id else nil)
	-- October 15 owner request: name the result at roll start so clients can load
	-- its mesh/texture hidden during the shuffle. The reveal still waits for landing.
	self.model:SetAttribute("PendingSpecies", if self.offer then self.offer.species else nil)
	if self.pet then self.pet:Destroy(); self.pet = nil end
	self:Step(os.clock(), true)
end

function RollStation:Step(now, force)
	if not self.ownerId then return end
	local rolling = self.offer ~= nil and now < self.revealAt
	local canRoll, canBuy = self.loaded and now >= self.readyAt, self.loaded and self.offer ~= nil and not rolling
	if self.rollPrompt and self.rollPrompt.Enabled~=canRoll then self.rollPrompt.Enabled=canRoll end
	if self.buyPrompt.Enabled ~= canBuy then self.buyPrompt.Enabled = canBuy end
	if self.model:GetAttribute("Rolling") ~= rolling then self.model:SetAttribute("Rolling", rolling) end
	local promptText = if canRoll then "Pull lever · FREE" else "Ready in " .. math.ceil(self.readyAt - now) .. "s"
	if self.rollPrompt and self.rollPrompt.ActionText~=promptText then self.rollPrompt.ActionText=promptText end
	-- Server owns prompts and the settled offer. Render-frame movement, sparkle
	-- timing and audio belong together in RollPresentationController.
	if not force and now - self.lastVisualAt < 0.1 then return end
	self.lastVisualAt = now
	-- Low clutter: only the lever's own podium (slot 1) shows a hint while it is
	-- empty; other empty podiums stay unlabeled.
	local idle = self.slot == 1 and self.loaded and self.offer == nil
	self.offerGui.Enabled = canBuy or idle
	if rolling then
		self.label.Text, self.rarityLabel.Text, self.priceLabel.Text = "", "", ""
	elseif self.offer then
		local def = Catalog[self.offer.species]
		local level = self.offer.level or 1
		local price = self.offer.price or Rules.RecruitPrice(self.offer.species, level)
		local tint = Color3.fromRGB(table.unpack(def.color))
		if not self.landed then
			self:SetPet(self.offer.species); self.landed = true
			self.model:SetAttribute("RevealedSpecies", self.offer.species)
			self.model:SetAttribute("RevealedOfferId", self.offer.id)
			self.model:SetAttribute("RevealedMutation", self.offer.mutation)
		end
		self.label.Text = def.name
		self.rarityLabel.Text = def.rarity
		self.rarityLabel.TextColor3 = UIColors.Rarities[def.rarity] or UIColors.Text
		self.priceLabel.Text = "$" .. commas(price)
		local promptText = if self.flockFull then "Flock full · sell in Army" else "Buy " .. def.name .. " · $" .. commas(price)
		if self.buyPrompt.ActionText ~= promptText then self.buyPrompt.ActionText = promptText end
		self.top.Color = tint

	else
		self.label.Text, self.rarityLabel.Text, self.priceLabel.Text = if idle then "Pull the lever to roll" else "", "", ""
		self.top.Color, self.light.Brightness = Color3.fromRGB(67, 181, 222), 0
	end

end

function RollStation:Clear()
	self.ownerId, self.offer, self.offerId, self.loaded = nil, nil, nil, false
	self:SetUnlocked(self.slot==1)
	if self.pet then self.pet:Destroy(); self.pet = nil end
	if self.rollPrompt then self.rollPrompt.Enabled=false end
	self.buyPrompt.Enabled,self.light.Brightness=false,0
	self.offerGui.Enabled = false
	self.label.Text, self.rarityLabel.Text, self.priceLabel.Text = "", "", ""
	self.top.Color = Color3.fromRGB(67, 181, 222)
	if self.arm and self.knob then self.arm.CFrame,self.knob.CFrame=self.leverPivot*self.armRest,self.leverPivot*self.knobRest end
	for _, name in {"OwnerId", "OwnerUserId", "RevealedOfferId", "RevealedSpecies", "RevealedMutation", "PendingSpecies", "RollStage", "RollId", "RollStartedAt", "RollDuration", "RollPaidLuck", "RollResearchLuck", "RollSeed", "RollTier", "RollLuck"} do self.model:SetAttribute(name, nil) end
	self.model:SetAttribute("Rolling", false)
end

function RollStation:Destroy()
	for _, connection in self.connections do connection:Disconnect() end
	self.connections = {}
	self.model:Destroy()
end

return RollStation
