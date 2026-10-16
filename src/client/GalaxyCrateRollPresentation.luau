--!strict
-- A reveal for a result already supplied by the server (or an explicit preview).
-- Decorative reel entries never choose, grant, or change the real reward.
local Theme=require(script.Parent.UITheme)
local Motion=require(script.Parent.UIMotion)
local Presentation={}
Presentation.__index=Presentation

local GOLD=Color3.fromRGB(255,235,55)
local ORANGE=Color3.fromRGB(239,153,28)
local CENTER=UDim2.fromScale(0.5,0.5)
local BELOW=UDim2.fromScale(0.5,1.2)
local ABOVE=UDim2.fromScale(0.5,-0.1)
local STRIDE=0.1
local CARD_SIZE=UDim2.fromScale(0.07,0.5)
local START=UDim2.fromScale(1.125,0)
local WINNER_INDEX=88
local CARD_COUNT=94
-- Seconds, measured against the user's Oct 6 recording. Entry begins empty;
-- cards enter near its end. See assets/galaxy-roll-20261006/reference-match/.
local DEFAULT_TIMING={entry=1,spinDelay=0.9,spin=8.45,hold=1.5,exit=1,dim=0.65,exitDimDelay=0.15,reducedHold=1.4}

local function markerTip(parent,name,bottom,color)
	local clip=Theme.Container(parent,name)
	clip.Size,clip.Position=UDim2.fromScale(0.012,0.1),UDim2.fromScale(0.5,if bottom then 1 else 0)
	clip.AnchorPoint,clip.ClipsDescendants,clip.ZIndex=Vector2.new(0.5,if bottom then 1 else 0),true,108
	Theme.Aspect(clip,2)
	local diamond=Theme.Frame(clip,"Tip",UDim2.fromScale(0.7071,1.4142),color)
	diamond.AnchorPoint,diamond.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,if bottom then 1 else 0)
	diamond.Rotation,diamond.ZIndex=45,108
end

local function seedFor(id)
	local value=5381
	for i=1,#id do value=(value*33+string.byte(id,i))%2147483647 end
	return value
end

local function positionFor(index)
	return UDim2.fromScale(0.5-(index-1)*STRIDE,0)
end

local function timingFrom(options)
	local timing=table.clone(DEFAULT_TIMING)
	for key,value in options.timings or {} do
		if timing[key] and type(value)=="number" and value>=0 then timing[key]=value end
	end
	return timing
end

function Presentation.new(parent,options)
	options=options or {}
	local self=setmetatable({
		alive=true,playing=false,serial=0,tasks={},sounds={},motion=Motion.new(),
		audio=options.audio,onComplete=options.onComplete,
		reducedMotion=options.reducedMotion==true,timing=timingFrom(options),
	},Presentation)
	local root=Theme.Container(parent,"GalaxyCrateRoll")
	root.ZIndex,root.Visible=100,false
	root:SetAttribute("Phase","Idle")
	self.root=root
	local shield=Instance.new("TextButton")
	shield.Name,shield.Size,shield.Text="InputShield",UDim2.fromScale(1,1),""
	shield.BackgroundColor3,shield.BackgroundTransparency=Color3.new(0,0,0),1
	shield.BorderSizePixel,shield.AutoButtonColor,shield.Selectable=0,false,false
	shield.Active,shield.Modal,shield.ZIndex=true,true,100
	-- The dim reaches the full device screen, past phone notches.
	local shieldLayer=Theme.InsetContainer(root,"ShieldLayer",Enum.ScreenInsets.None)
	shieldLayer.ZIndex=100
	shield.Parent=shieldLayer
	self.shield=shield
	local panel=Theme.Frame(root,"Reel",UDim2.fromScale(0.8,0.15),Color3.new(0,0,0))
	panel.AnchorPoint,panel.Position=Vector2.new(0.5,0.5),CENTER
	panel.BackgroundTransparency,panel.ZIndex=0.6,101
	-- Reference-specific rounded reel/cards; the game's other surfaces stay square.
	panel.UICorner.CornerRadius=UDim.new(0.085,0)
	local panelStroke=Theme.Stroke(panel,Color3.new(1,1,1),1.5)
	panelStroke.LineJoinMode=Enum.LineJoinMode.Round
	Theme.Gradient(panelStroke,GOLD,ORANGE)
	self.panel=panel
	local clip=Theme.Container(panel,"Clip")
	clip.ClipsDescendants,clip.ZIndex=true,102
	local strip=Theme.Container(clip,"Items")
	strip.ZIndex=103
	self.strip=strip
	local marker=Theme.Frame(panel,"CenterMarker",UDim2.fromScale(0.002,1),Color3.new(1,1,1))
	marker.AnchorPoint,marker.Position,marker.ZIndex=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),108
	Theme.Gradient(marker,GOLD,ORANGE)
	markerTip(panel,"TopMarker",false,GOLD)
	markerTip(panel,"BottomMarker",true,ORANGE)
	self.destroying=root.Destroying:Connect(function() self:Destroy() end)
	return self
end

function Presentation:_Later(seconds,callback)
	local serial=self.serial
	local pending
	pending=task.delay(seconds,function()
		self.tasks[pending]=nil
		if self.alive and self.playing and self.serial==serial and self.root.Parent then callback() end
	end)
	self.tasks[pending]=true
end

function Presentation:_Sound(name,pitch,volume,duration)
	if not self.audio then return end
	local sound=self.audio:Play(name,pitch,{volume=volume,maxDuration=duration,voiceKey="GalaxyCrate"..name,
		maxVoices=if name=="RollTick" then 3 else nil,noFallback=true})
	if sound then self.sounds[sound]=true end
end

function Presentation:_Card(entry,index)
	local color=entry.color or Theme.Arcade.purple
	local card=Theme.Frame(self.strip,"Card"..index,CARD_SIZE,color)
	card.AnchorPoint,card.Position=Vector2.new(0.5,0.5),UDim2.fromScale((index-1)*STRIDE,0.5)
	card.ZIndex=103
	card:SetAttribute("RewardId",entry.id)
	Theme.Aspect(card,1.2)
	card.UICorner.CornerRadius=UDim.new(0.075,0)
	local edge=Theme.Frame(card,"LightRim",UDim2.fromScale(1,1),Color3.new(0,0,0))
	edge.BackgroundTransparency,edge.ZIndex=1,103
	edge.UICorner.CornerRadius=UDim.new(0.075,0)
	-- Child strokes render above their parent in the game's sibling Z order.
	-- Put the wider dark border on the card and the thin white line above it.
	Theme.Stroke(card,Color3.fromRGB(27,28,24),3.5).LineJoinMode=Enum.LineJoinMode.Round
	Theme.Stroke(edge,Color3.fromRGB(248,245,231),1.5).LineJoinMode=Enum.LineJoinMode.Round
	Theme.Gradient(card,color:Lerp(Color3.new(1,1,1),0.13),color:Lerp(Color3.new(0,0,0),0.12))
	for _,offset in {Vector2.new(-1,-1),Vector2.new(0,-1),Vector2.new(1,-1),Vector2.new(-1,0),Vector2.new(1,0),Vector2.new(-1,1),Vector2.new(0,1),Vector2.new(1,1)} do
		local outline=Theme.Image(card,"SilhouetteStroke",entry.image,UDim2.fromScale(0.96,0.96),UDim2.fromScale(0.02+offset.X*0.008,0.02+offset.Y*0.008))
		outline.ImageColor3,outline.ZIndex=Color3.new(0,0,0),104
	end
	local portrait=Theme.Image(card,"Chicken",entry.image,UDim2.fromScale(0.96,0.96),UDim2.fromScale(0.02,0.02))
	portrait.ZIndex=105
	local chance=entry.chance
	if chance~=nil then
		local text=if type(chance)=="number" then string.format("%.2f",chance*100):gsub("0+$",""):gsub("%.$","").."%" else tostring(chance)
		local label=Theme.Label(card,"Chance",text,20,Theme.Colors.white)
		label.AnchorPoint,label.Position,label.Size=Vector2.new(1,1),UDim2.fromScale(0.99,0.99),UDim2.fromScale(0.5,0.29)
		label.BackgroundColor3,label.BackgroundTransparency=Color3.fromRGB(15,17,16),0.08
		Theme.Round(label).CornerRadius=UDim.new(0.2,0)
		label.TextScaled,label.TextWrapped,label.TextXAlignment=true,false,Enum.TextXAlignment.Right
		label.ZIndex=106
	end
	return card
end

function Presentation:_StopTicks()
	if self.ticks then self.ticks:Disconnect();self.ticks=nil end
end

function Presentation:_Focus()
	-- This is a spatial effect, not a second animation clock: only cards near
	-- the native tween's center change size. Fixed-target tweens would drift
	-- away from the marker as the strip decelerates.
	local center=(0.5-self.strip.Position.X.Scale)/STRIDE+1
	for index in self.focused do
		if math.abs(index-center)>=1.5 then
			self.cards[index].Size=CARD_SIZE
			self.focused[index]=nil
		end
	end
	for index=math.max(1,math.floor(center)-1),math.min(CARD_COUNT,math.ceil(center)+1) do
		local card=self.cards[index]
		local weight=math.max(0,1-math.abs(index-center)/1.5)
		if card and weight>0 then
			local scale=1+0.25*weight
			card.Size=UDim2.fromScale(CARD_SIZE.X.Scale*scale,CARD_SIZE.Y.Scale*scale)
			self.focused[index]=true
		end
	end
end

function Presentation:_Complete()
	local callback,reward=self.completion,self.reward
	self:Cancel()
	self.root:SetAttribute("Phase","Complete")
	if callback then callback(reward) end
end

function Presentation:_Exit()
	self.root:SetAttribute("Phase","Exiting")
	if self.reduced then self:_Complete();return end
	local fadeDelay=math.min(self.timing.exitDimDelay,self.timing.exit)
	self:_Later(fadeDelay,function()
		self.motion:Tween(self.shield,"dim",{BackgroundTransparency=1},math.min(self.timing.dim,self.timing.exit-fadeDelay),Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
	end)
	self.motion:Tween(self.panel,"travel",{Position=ABOVE},self.timing.exit,Enum.EasingStyle.Back,Enum.EasingDirection.In,function()
		self:_Complete()
	end)
end

function Presentation:_Reveal()
	self:_StopTicks()
	self.strip.Visible=true
	self.strip.Position=positionFor(WINNER_INDEX)
	self:_Focus()
	self.root:SetAttribute("Phase","Result")
	self.root:SetAttribute("CenteredRewardId",self.reward.id)
	self:_Sound("RollReveal",1,0.3,0.9)
	-- Landing bounce, a sweep of light and gold sparks above the reel and dim.
	local winner=self.winner
	if winner then
		self.motion:PopScale(winner,1.12,0.3)
		self.motion:Shine(winner)
		local shine=winner:FindFirstChild("MotionShine")
		if shine then (shine :: any).UICorner.CornerRadius=winner.UICorner.CornerRadius end
	end
	self.motion:Burst(self.root,CENTER,GOLD)
	local sparkles=self.root:FindFirstChild("RewardSparkles")
	if sparkles then sparkles.ZIndex=109 end
	self:_Later(if self.reduced then self.timing.reducedHold else self.timing.hold,function() self:_Exit() end)
end

function Presentation:_Spin()
	self.root:SetAttribute("Phase","Spinning")
	self.strip.Visible=true
	local last=0
	-- Native TweenService owns travel. Observe it for marker focus and ticks.
	self.ticks=self.strip:GetPropertyChangedSignal("Position"):Connect(function()
		self:_Focus()
		local centered=math.floor((0.5-self.strip.Position.X.Scale)/STRIDE+1.5)
		if centered<1 or centered>CARD_COUNT then return end
		if centered==last then return end
		last=centered
		self.root:SetAttribute("CenteredRewardId",self.cards[centered]:GetAttribute("RewardId"))
		self:_Sound("RollTick",1.1,0.17,0.13)
	end)
	self.motion:Tween(self.strip,"roll",{Position=positionFor(WINNER_INDEX)},self.timing.spin,Enum.EasingStyle.Quart,Enum.EasingDirection.Out,function()
		self:_Reveal()
	end)
end

-- pool: {{id, name, image, chance?, color?}}. Numeric chance is normalized 0-1;
-- string chance is already-formatted authoritative copy. It is never inferred.
-- reward: a pool id or an entry with that id. Returns false when busy/invalid.
-- options: seed?, reducedMotion?, onComplete?, preview?. No purchase happens here.
function Presentation:Play(reward,pool,options)
	if not self.alive or not self.root.Parent then return false,"Destroyed" end
	if self.playing then return false,"Busy" end
	if type(pool)~="table" or #pool==0 then return false,"MissingPool" end
	options=options or {}
	local id=if type(reward)=="table" then reward.id else reward
	local selected
	for _,entry in pool do
		if type(entry)~="table" or type(entry.id)~="string" or type(entry.image)~="string" or entry.image=="" then
			return false,"InvalidPoolEntry"
		end
		if entry.id==id then selected=entry end
	end
	if not selected then return false,"UnknownReward" end
	self:Cancel()
	self.playing=true
	self.reward=selected
	self.completion=options.onComplete or self.onComplete
	self.reduced=if options.reducedMotion~=nil then options.reducedMotion==true else self.reducedMotion
	self.motion.reduced=self.reduced
	self.root:SetAttribute("Phase","Entering")
	self.root:SetAttribute("RewardId",selected.id)
	self.root:SetAttribute("Preview",options.preview==true)
	self.root:SetAttribute("WinnerIndex",WINNER_INDEX)
	self.cards={}
	self.focused={}
	local random=Random.new(if type(options.seed)=="number" then options.seed else seedFor(selected.id))
	local total=0
	for _,entry in pool do total+=if type(entry.chance)=="number" then math.max(0,entry.chance) else 0 end
	local function decorativeEntry()
		if total<=0 then return pool[random:NextInteger(1,#pool)] end
		local roll=random:NextNumber()*total
		for _,entry in pool do
			roll-=if type(entry.chance)=="number" then math.max(0,entry.chance) else 0
			if roll<0 then return entry end
		end
		return pool[#pool]
	end
	-- Reduced motion needs only the confirmed winner, not a hidden full reel.
	for index=if self.reduced then WINNER_INDEX else 1,if self.reduced then WINNER_INDEX else CARD_COUNT do
		local entry=if index==WINNER_INDEX then selected else decorativeEntry()
		self.cards[index]=self:_Card(entry,index)
	end
	self.winner=self.cards[WINNER_INDEX]
	self.strip.Position=START
	self.strip.Visible=false
	self.panel.Position=if self.reduced then CENTER else BELOW
	self.shield.BackgroundTransparency=if self.reduced then 0.45 else 1
	self.root.Visible=true
	if self.reduced then self:_Reveal();return true end
	local delay=math.min(self.timing.spinDelay,self.timing.entry)
	local entry=math.min(self.timing.entry,delay+self.timing.spin)
	self.motion:Tween(self.shield,"dim",{BackgroundTransparency=0.45},self.timing.dim,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
	self.motion:Tween(self.panel,"travel",{Position=CENTER},entry,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
	self:_Later(delay,function() self:_Spin() end)
	return true
end

function Presentation:IsPlaying()
	return self.playing
end

function Presentation:Cancel()
	self.serial+=1
	self.playing=false
	self.completion=nil
	self:_StopTicks()
	self.motion:Reset()
	for pending in self.tasks do task.cancel(pending) end
	table.clear(self.tasks)
	for sound in self.sounds do if sound.Parent then sound:Destroy() end end
	table.clear(self.sounds)
	self.root.Visible=false
	self.shield.BackgroundTransparency=1
	self.panel.Position=CENTER
	self.strip:ClearAllChildren()
	self.cards={}
	self.focused={}
	self.winner=nil
	self.reward=nil
	self.root:SetAttribute("Phase","Idle")
	self.root:SetAttribute("CenteredRewardId",nil)
end

function Presentation:Destroy()
	if not self.alive then return end
	self.alive=false
	if self.destroying then self.destroying:Disconnect();self.destroying=nil end
	self:Cancel()
	self.root:Destroy()
end

return Presentation
