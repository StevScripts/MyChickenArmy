--!strict
-- October 20 Gold Rush presentation (docs/team/GOLD_RUSH_FRIEND_BOOST.md). Reads the
-- server's window (ReplicatedStorage.PetRoll attributes GoldRushStartsAt and
-- GoldRushEndsAt, in server time) and shows a countdown chip in the bottom-right
-- corner, a start notice, a warm gold tint, a gold sky and gold sparkles and coins
-- drifting around the camera. Visual only: there is nothing to pick up, and the
-- server already applies the Coins multiplier. Reduced motion keeps the tint and
-- sky (no fades) and skips the particles.
local Lighting=game:GetService("Lighting")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Config=require(ReplicatedStorage.PetRoll.Shared.Config)
local Theme=require(script.Parent.UITheme)
local BoostReadout=require(script.Parent.BoostReadout)
local Controller={}
Controller.__index=Controller

-- Warm light over the 3D view only (HUD and menus are unaffected).
local TINT={TintColor=Color3.fromRGB(255,231,176),Saturation=0.12,Contrast=0.05,Brightness=0.02}
local TINT_OFF={TintColor=Color3.new(1,1,1),Saturation=0,Contrast=0,Brightness=0}
-- The gold sky: the map's Atmosphere turns gold, then returns to its own values.
local SKY={Color=Color3.fromRGB(255,214,140),Decay=Color3.fromRGB(255,163,64),Haze=1.6,Glare=0.5}
local FADE_IN,FADE_OUT=2,2.5
local IDLE_COLOR,RUSH_COLOR=Theme.Arcade.gold,Color3.fromRGB(255,236,92)
-- The drifting air: a box around the camera focus; particles stay where emitted,
-- so the box can jump a few studs as it follows without anything popping.
local SPARKLE="rbxasset://textures/particles/sparkles_main.dds"
local AIR_SIZE,AIR_LIFT,AIR_LINGER=Vector3.new(110,34,110),8,8

local function clock(seconds: number): string
	seconds=math.max(0,math.ceil(seconds))
	return string.format("%d:%02d",seconds//60,seconds%60)
end

-- "2x" (tostring keeps a tuned 1.5 readable; %d would throw on it).
local function times(): string
	return tostring(Config.GoldRush.CoinMultiplier).."x"
end

function Controller.new(app)
	local self=setmetatable({app=app,connections={},active=false,seen=false,nextStepAt=0},Controller)
	local tint=Instance.new("ColorCorrectionEffect")
	tint.Name,tint.Enabled="PetRollGoldRushTint",false
	for property,value in TINT_OFF do (tint::any)[property]=value end
	tint.Parent=Lighting
	self.tint=tint
	self:BuildChip()
	table.insert(self.connections,RunService.Heartbeat:Connect(function() self:Step() end))
	self:Step()
	return self
end

function Controller:BuildChip()
	local app=self.app
	local chip=Instance.new("TextButton")
	chip.Name,chip.Text,chip.AutoButtonColor,chip.Selectable="GoldRushChip","",false,false
	chip.BackgroundTransparency,chip.BorderSizePixel=1,0
	chip.AnchorPoint,chip.Size,chip.Visible=Vector2.new(1,1),UDim2.fromScale(0.3,0.05),false
	chip.Parent=app.hudLayer
	Theme.Aspect(chip,10)
	-- Text right-aligned against the coin, which sits on the right edge like the totals below.
	local icon=Theme.Image(chip,"Icon",Theme.Assets.Coin,UDim2.fromScale(0.1,1),UDim2.fromScale(1,0.5))
	icon.AnchorPoint=Vector2.new(1,0.5)
	Theme.Aspect(icon,1)
	local text=Theme.Display(chip,"Clock","",26,IDLE_COLOR)
	text.Position,text.Size=UDim2.fromScale(0,0.05),UDim2.fromScale(0.885,0.9)
	text.TextXAlignment,text.TextScaled,text.TextWrapped=Enum.TextXAlignment.Right,true,false
	Theme.Motion:Center(text) -- the last-ten-seconds breathing grows from its middle
	Theme.ScaleText(chip)
	chip.Activated:Connect(function()
		local rush=Config.GoldRush
		app.audio:Play("Click")
		app:Notify(string.format("Gold Rush: %s Coins for %d minutes, every %d minutes!",
			times(),rush.Seconds//60,rush.EverySeconds//60),"info")
	end)
	self.chip,self.icon,self.clock=chip,icon,text
	self:Place()
end

-- October 21 (Stevin): the bottom-right corner, where Camps held / Flock were (Auto
-- Roll sits higher on the right edge, so the two never meet). Later that day the
-- small coin/clover boosts (BoostReadout) took the very corner; the chip rests on them.
function Controller:Place()
	local boosts=BoostReadout.Position.Y.Scale-BoostReadout.Size.Y.Scale
	self.chip.Position=UDim2.fromScale(0.988,boosts-0.008)
end

function Controller:Step()
	local now=os.clock()
	if now<self.nextStepAt then return end
	self.nextStepAt=now+0.2
	local folder=ReplicatedStorage.PetRoll
	local startsAt,endsAt=folder:GetAttribute("GoldRushStartsAt"),folder:GetAttribute("GoldRushEndsAt")
	local known=type(startsAt)=="number" and type(endsAt)=="number"
	local serverNow=workspace:GetServerTimeNow()
	local active=known and serverNow>=startsAt and serverNow<endsAt
	if active~=self.active then self:SetActive(active,if known then endsAt-startsAt else 0) end
	self.seen=true
	local app=self.app
	local quiet=(app.panel~=nil and app.panel.Visible) or app.dialogueActive==true
	Theme.Motion:Appear(self.chip,known and not quiet,0.8)
	if known then
		self.clock.Text=if active then times().." Coins! "..clock(endsAt-serverNow)
			elseif startsAt>serverNow then "Gold Rush in "..clock(startsAt-serverNow) else "Gold Rush soon"
	end
	-- October 21 game feel: the clock breathes through the last ten seconds.
	local ending=active and known and endsAt-serverNow<=10
	if ending~=(self.clockBreathing==true) then
		self.clockBreathing=ending
		if ending then Theme.Motion:Breathe(self.clock,1.1,0.5) else Theme.Motion:StopBreathe(self.clock) end
	end
	if self.active then self:StepAir() end
end

function Controller:SetActive(active: boolean, seconds: number)
	self.active=active
	local app=self.app
	local reduced=app.reducedMotion==true
	if active then self.tint.Enabled=true end
	Theme.Motion:Tween(self.tint,"goldRush",if active then TINT else TINT_OFF,if reduced then 0 elseif active then FADE_IN else FADE_OUT,
		Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,function() if not self.active then self.tint.Enabled=false end end)
	self:SetSky(active,reduced)
	self.clock.TextColor3=if active then RUSH_COLOR else IDLE_COLOR
	if active then
		Theme.Motion:Breathe(self.icon,1.15,0.5)
		-- October 21 game feel: the chip's gold ring pulses for the whole rush.
		Theme.Motion:Glow(self.chip,RUSH_COLOR,2)
		self:StartAir()
		-- Not on the first look: someone joining mid-rush already sees the gold world.
		if self.seen then
			local minutes=math.max(1,math.floor(seconds/60+0.5))
			app:Notify(string.format("Gold Rush! %s Coins for %d minute%s!",times(),minutes,
				if minutes==1 then "" else "s"),true)
			-- "GoldRushStart" from the library (GAME_FEEL §3); an older "GoldRush" cue, then
			-- Victory, stand in until it exists.
			local audio=app.audio
			local fallback=if type(audio.Has)=="function" and audio:Has("GoldRush") then "GoldRush" else "Victory"
			app:Cue("GoldRushStart",fallback)
			if app.screenFeel then app.screenFeel:Flash(Theme.Arcade.gold,0.2,0.5) end
			Theme.Motion:Punch(self.chip,1.2,0.35)
		end
	else
		Theme.Motion:StopBreathe(self.icon)
		Theme.Motion:StopGlow(self.chip)
		self:StopAir()
		if self.seen then app:Cue("GoldRushEnd") end
	end
end

function Controller:SetSky(active: boolean, reduced: boolean)
	local atmosphere=Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then return end
	if active then
		-- Remember the map's own sky once; a quick second rush keeps the first capture.
		if not self.skyRest or self.skyAtmosphere~=atmosphere then
			self.skyAtmosphere=atmosphere
			self.skyRest={Color=atmosphere.Color,Decay=atmosphere.Decay,Haze=atmosphere.Haze,Glare=atmosphere.Glare}
		end
		Theme.Motion:Tween(atmosphere,"goldRush",SKY,if reduced then 0 else FADE_IN,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
	elseif self.skyRest and self.skyAtmosphere==atmosphere then
		Theme.Motion:Tween(atmosphere,"goldRush",self.skyRest,if reduced then 0 else FADE_OUT,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,
			function() if not self.active then self.skyRest,self.skyAtmosphere=nil,nil end end)
	end
end

local function emitter(parent: Instance, name: string, texture: string): ParticleEmitter
	local item=Instance.new("ParticleEmitter")
	item.Name,item.Texture=name,texture
	item.SpreadAngle=Vector2.new(180,180)
	item.Rotation=NumberRange.new(0,360)
	item.Shape,item.ShapeStyle=Enum.ParticleEmitterShape.Box,Enum.ParticleEmitterShapeStyle.Volume
	item.Parent=parent
	return item
end

function Controller:StartAir()
	local camera=workspace.CurrentCamera
	if self.air or self.app.reducedMotion or not camera then return end
	local part=Instance.new("Part")
	part.Name,part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch,part.CastShadow="GoldRushAir",true,false,false,false,false
	part.Transparency,part.Size=1,AIR_SIZE
	-- Gold sparkles hang in the air and drift slightly upward.
	local sparkles=emitter(part,"Sparkles",SPARKLE)
	sparkles.Color=ColorSequence.new(Color3.fromRGB(255,240,150),Color3.fromRGB(255,190,40))
	sparkles.LightEmission,sparkles.LightInfluence=1,0
	sparkles.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.2,0.45,0.15),
		NumberSequenceKeypoint.new(0.8,0.35,0.1),NumberSequenceKeypoint.new(1,0)})
	sparkles.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.2,0.1),
		NumberSequenceKeypoint.new(0.8,0.25),NumberSequenceKeypoint.new(1,1)})
	sparkles.Lifetime,sparkles.Rate,sparkles.Speed=NumberRange.new(3,5),40,NumberRange.new(0.3,1.2)
	sparkles.Acceleration,sparkles.Drag,sparkles.RotSpeed=Vector3.new(0,0.35,0),0.6,NumberRange.new(-90,90)
	-- Gold coins tumble slowly down.
	local coins=emitter(part,"Coins",Theme.Assets.Coin)
	coins.LightEmission,coins.LightInfluence=0.2,0.4
	coins.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,1.1,0.3),NumberSequenceKeypoint.new(1,1.1,0.3)})
	coins.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.12,0),
		NumberSequenceKeypoint.new(0.85,0),NumberSequenceKeypoint.new(1,1)})
	coins.Lifetime,coins.Rate,coins.Speed=NumberRange.new(6,8),7,NumberRange.new(0.5,1.5)
	coins.Acceleration,coins.Drag,coins.RotSpeed=Vector3.new(0,-1.1,0),0.35,NumberRange.new(-140,140)
	part.CFrame=CFrame.new(camera.Focus.Position+Vector3.new(0,AIR_LIFT,0))
	part.Parent=camera
	self.air=part
end

function Controller:StepAir()
	-- Reduced motion can change mid-rush in Settings.
	local reduced=self.app.reducedMotion==true
	if reduced and self.air then self:StopAir() elseif not reduced and not self.air then self:StartAir() end
	local camera=workspace.CurrentCamera
	if self.air and camera then self.air.CFrame=CFrame.new(camera.Focus.Position+Vector3.new(0,AIR_LIFT,0)) end
end

function Controller:StopAir()
	local part=self.air
	if not part then return end
	self.air=nil
	for _,child in part:GetChildren() do
		if child:IsA("ParticleEmitter") then child.Enabled=false end
	end
	-- The last sparkles and coins finish drifting before the box goes.
	task.delay(AIR_LINGER,function() part:Destroy() end)
end

function Controller:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if self.air then self.air:Destroy();self.air=nil end
	local atmosphere,rest=self.skyAtmosphere,self.skyRest
	if atmosphere and rest then
		Theme.Motion:Cancel(atmosphere,"goldRush")
		for property,value in rest do (atmosphere::any)[property]=value end
	end
	self.skyRest,self.skyAtmosphere=nil,nil
	self.tint:Destroy()
	self.chip:Destroy()
end

return Controller
