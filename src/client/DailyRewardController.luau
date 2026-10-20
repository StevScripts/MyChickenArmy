--!strict
-- 7-day login streak popup (docs/team/launch/13_D1_DAILY_STREAK.md). Displays the
-- reward the server already granted (state.daily.granted); Collect! only closes it.
-- October 14 layout: a Daily Rewards card grid (Days 1–6 + a tall Day 7).
-- AppController calls Render(state, result) on every state packet, after the
-- offline receipt (app.offlineCash.gui is set while that receipt is open).
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.UITheme)
local MenuLayout = require(script.Parent.MenuLayout)
local ShopArt = require(script.Parent.ShopPreviewArt)
local Controller = {}
Controller.__index = Controller

local GOLD = Theme.ReferenceColors.Base
local GREEN = Theme.ReferenceColors.Army
local DONE = Color3.fromRGB(112,222,98)
local WHITE = Color3.new(1,1,1)
-- Presentation mirror of DailyService.Rewards (server). Keep the two in step.
local TILES = {
	{minutes=5, rolls=0}, {minutes=10, rolls=0}, {minutes=0, rolls=1}, {minutes=20, rolls=0},
	{minutes=30, rolls=0}, {minutes=0, rolls=2}, {minutes=60, rolls=3},
}
local CASH_TIER = {1,2,0,3,3,0,4}
-- October 14 grid (owner reference): coin days orange/blue, roll days purple, Day 7 rainbow.
local CARD_COLORS = {
	Color3.fromRGB(255,166,38), Color3.fromRGB(52,186,255), Color3.fromRGB(176,82,255), Color3.fromRGB(255,166,38),
	Color3.fromRGB(52,186,255), Color3.fromRGB(176,82,255), Color3.fromRGB(255,214,64),
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0,Color3.fromRGB(255,70,190)), ColorSequenceKeypoint.new(0.25,Color3.fromRGB(255,200,40)),
	ColorSequenceKeypoint.new(0.5,Color3.fromRGB(90,230,90)), ColorSequenceKeypoint.new(0.75,Color3.fromRGB(60,200,255)),
	ColorSequenceKeypoint.new(1,Color3.fromRGB(255,90,60)),
})
local MIN_INCOME = 10 -- DailyService.MinIncome
local DAY_SECONDS = 86400 -- DailyService.DaySeconds (UTC days)
-- Wait for the offline receipt (and the first-visit film) before showing.
local RETRY_SECONDS = 0.4
local AFTER_RECEIPT_SECONDS = 0.6
-- Studio may author MenuLayouts.DailyStreak; otherwise this native Scale frame
-- is height-led on wide screens and width-led on narrow ones.
local LAYOUT_NAME = "DailyStreak"
local DEFAULT_SIZE, DEFAULT_ASPECT = UDim2.fromScale(0.9,0.72), 1.5

-- Today's tile shows the coins the server granted. Other days estimate from the
-- HUD income (the server pays minutes of income at claim time).
local function rewardText(reward,cash: number): string
	local parts = {}
	if reward.minutes>0 then table.insert(parts,"+"..Theme.CompactCoins(cash)) end
	if reward.rolls>0 then table.insert(parts,"+"..reward.rolls.." Free "..(if reward.rolls==1 then "Roll" else "Rolls")) end
	return table.concat(parts,"\n")
end

local function clock(seconds: number): string
	seconds = math.max(0,math.floor(seconds))
	return string.format("%02d:%02d:%02d",seconds//3600,(seconds//60)%60,seconds%60)
end

function Controller.new(app)
	return setmetatable({app=app,alive=true,shownDay=nil,pending=nil,connections={}},Controller)
end

function Controller:Render(state, _result)
	local daily = state and state.daily
	local granted = daily and daily.granted
	if type(granted)~="table" or type(granted.day)~="number" then return end
	if granted.day==self.shownDay or (self.pending and self.pending.day==granted.day) then return end
	self.pending = table.clone(granted)
	self:TryShow()
end

function Controller:Schedule()
	if self.retry or not self.alive then return end
	self.retry = task.delay(RETRY_SECONDS,function()
		self.retry = nil
		self:TryShow()
	end)
end

function Controller:Blocked(): boolean
	local app = self.app
	if self.gui or not app.other then return true end
	local offline = app.offlineCash
	if offline and offline.gui~=nil then self.receiptAt = os.clock();return true end
	if self.receiptAt and os.clock()-self.receiptAt<AFTER_RECEIPT_SECONDS then return true end
	return app.intro~=nil and app.intro:Pending()
end

function Controller:TryShow()
	if not self.alive or not self.pending then return end
	if self:Blocked() then
		-- An open popup re-checks when it closes; everything else polls briefly.
		if not self.gui then self:Schedule() end
		return
	end
	local granted = self.pending
	self.pending, self.shownDay = nil, granted.day
	self:Show(granted)
end

function Controller:Dismiss(immediate: boolean?)
	local gui,panel = self.gui,self.panel
	if not gui or (self.closing and not immediate) then return end
	self.closing = true
	ContextActionService:UnbindAction("PetRollDailyRewardClose")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if self.todayCard then Theme.Motion:StopBreathe(self.todayCard) end
	self.app:SetMenuBlur("daily",false)
	local function finish()
		if self.gui~=gui then return end
		self.gui,self.panel,self.closing,self.collecting,self.todayCard = nil,nil,false,false,nil
		gui:Destroy()
		-- A later day granted while this was open (crossing UTC midnight online).
		if self.alive and self.pending then self:Schedule() end
	end
	if immediate then finish();return end
	Theme.Motion:Tween(panel,"daily-size",{Size=UDim2.fromScale(self.panelSize.X.Scale*0.97,self.panelSize.Y.Scale*0.97)},0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	Theme.Motion:Tween(panel,"position",{Position=UDim2.fromScale(self.panelPosition.X.Scale,self.panelPosition.Y.Scale+0.025)},0.16)
	Theme.Motion:Tween(panel,"daily-fade",{GroupTransparency=1},0.16,nil,nil,finish)
end

local function label(parent,name,value,size,color)
	local item = Theme.Label(parent,name,value,size,color)
	item.TextXAlignment,item.TextScaled = Enum.TextXAlignment.Center,true
	return item
end

local function place(item,x,y,w,h)
	item.Position,item.Size = UDim2.fromScale(x,y),UDim2.fromScale(w,h)
	return item
end

-- A dark status plate at the bottom of a card ("Not Ready" or tomorrow's timer).
local function plate(parent,text,y,h)
	-- White base: a UIGradient multiplies the background color.
	local frame = Theme.Frame(parent,"Status",UDim2.fromScale(0.8,h),WHITE)
	frame.Position = UDim2.fromScale(0.1,y)
	frame:SetAttribute("OwnsPopupStyle",true)
	frame.ZIndex = 8
	Theme.Gradient(frame,Color3.fromRGB(96,100,106),Color3.fromRGB(52,55,60))
	Theme.Stroke(frame,Color3.new(0,0,0),3)
	local caption = place(label(frame,"Text",text,26,WHITE),0.06,0.1,0.88,0.8)
	caption.ZIndex = 9
	return caption
end

-- One day card. States: claimed (dark, check), today (Collect!), tomorrow (timer), later (Not Ready).
function Controller:Card(parent,index,today,granted,x,y,w,h)
	local reward = TILES[index]
	local big = index==#TILES
	local claimed = index<today
	local color = CARD_COLORS[index]
	-- White base: the card's gradient carries its color (a UIGradient multiplies).
	local card = Theme.Frame(parent,"Day"..index,UDim2.fromScale(w,h),WHITE)
	card.Position = UDim2.fromScale(x,y)
	-- Cards keep their own colors; ApplyPopupStyle would darken them.
	card:SetAttribute("OwnsPopupStyle",true)
	if big then
		local gradient = Instance.new("UIGradient")
		gradient.Color,gradient.Rotation,gradient.Parent = RAINBOW,35,card
	else
		Theme.Gradient(card,color:Lerp(WHITE,0.15),color:Lerp(Color3.new(0,0,0),0.12))
	end
	-- Small, subtle studs (owner feedback): about 15 cells across a card, like the reference.
	Theme.Studs(card,0.07,28,0):SetAttribute("StudScaleWidth",1.6)
	Theme.Stroke(card,if index==today then WHITE else Color3.new(0,0,0),if index==today then 4 else 3)
	-- Layout in card space; Day 7 is tall, so its rows are thinner.
	local title = place(label(card,"Day","Day "..index,32,WHITE),0.06,if big then 0.02 else 0.03,0.88,if big then 0.09 else 0.17)
	title.ZIndex = 6
	if big then
		local insane = place(label(card,"Insane","Insane!",30,Color3.fromRGB(255,52,52)),0.1,0.11,0.8,0.08)
		insane.ZIndex = 6
		Theme.Gradient(insane,Color3.fromRGB(255,96,80),Color3.fromRGB(220,20,40))
	end
	local art = Theme.Container(card,"Art")
	art.AnchorPoint,art.Position,art.Size = Vector2.new(0.5,0.5),UDim2.fromScale(0.5,if big then 0.43 else 0.42),UDim2.fromScale(if big then 0.8 else 0.66,if big then 0.36 else 0.38)
	Theme.Aspect(art,1)
	local rays = ShopArt.ProductRays(art,WHITE)
	rays.Size,rays.Position,rays.AnchorPoint = UDim2.fromScale(1.6,1.6),UDim2.fromScale(0.5,0.5),Vector2.new(0.5,0.5)
	rays.ZIndex = 4
	local icon = if reward.minutes>0 then ShopArt.CashPile(art,CASH_TIER[index]) else Theme.Image(art,"Roll",Theme.Assets.Luck,UDim2.fromScale(1,1))
	icon.Name,icon.ZIndex = "Icon",5
	local income = math.max(MIN_INCOME,tonumber(self.app.state and self.app.state.income) or 0)
	local cash = if index==today then (granted.cash or 0) else math.floor(income*reward.minutes*60)
	local rewardLabel = place(label(card,"Reward",rewardText(reward,cash),28,
		if reward.minutes>0 then Color3.fromRGB(120,255,90) else Color3.fromRGB(255,224,60)),0.04,if big then 0.63 else 0.61,0.92,if big then 0.15 else 0.14)
	rewardLabel.ZIndex = 6
	local statusY,statusH = if big then 0.8 else 0.77,if big then 0.14 else 0.19
	if claimed then
		local shade = Theme.Frame(card,"Claimed",UDim2.fromScale(1,1),Color3.fromRGB(14,22,34))
		shade.BackgroundTransparency,shade.ZIndex = 0.25,7
		local tick = place(label(card,"Check","✓",80,DONE),0.15,if big then 0.25 else 0.2,0.7,if big then 0.3 else 0.42)
		tick.ZIndex = 8
		local done = place(label(card,"ClaimedText","CLAIMED",30,DONE),0.06,statusY,0.88,statusH*0.85)
		done.ZIndex = 8
	elseif index==today then
		local holder = Theme.Container(card,"Actions")
		holder.Position,holder.Size,holder.ZIndex = UDim2.fromScale(0.1,statusY),UDim2.fromScale(0.8,statusH),8
		local collect = Theme.ActionButton(holder,"Collect","Collect!",function() self:Collect(granted) end,GREEN)
		collect.Position,collect.Size = UDim2.fromScale(0,0),UDim2.fromScale(1,1)
		collect.Visual.Caption.Position,collect.Visual.Caption.Size = UDim2.fromScale(0.04,0.1),UDim2.fromScale(0.92,0.8)
		collect.Visual.Caption.TextScaled = true
		collect.Visual.Caption.TextShadow.Visible = false
		self.collect = collect
	elseif index==today+1 then
		self.timer = plate(card,clock(self:SecondsToReset()),statusY,statusH)
	else
		plate(card,"Not Ready",statusY,statusH)
	end
	return card
end

-- DailyService grants once per UTC day, so the next reward unlocks at UTC midnight.
function Controller:SecondsToReset(): number
	local now = workspace:GetServerTimeNow()
	return DAY_SECONDS-(now%DAY_SECONDS)
end

function Controller:Collect(granted)
	-- collecting: a second click during the short celebration does nothing.
	if not self.gui or self.closing or self.collecting then return end
	self.collecting = true
	local app = self.app
	app.audio:Play("Click")
	-- The reward is already in the wallet; this is presentation only.
	if (granted.cash or 0)>0 and app.feedback then
		local root = app.feedback:Root()
		app.feedback:ShowCash(if root then root.Position else Vector3.zero,granted.cash)
	else
		app.audio:Play("Pop",1.05,{volume=0.4,maxDuration=0.35})
	end
	local card,gui = self.todayCard,self.gui
	if not card or Theme.Motion.reduced then self:Dismiss();return end
	Theme.Motion:StopBreathe(card)
	Theme.Motion:PopScale(card,1.12,0.26)
	if card.Parent then Theme.Motion:Burst(card.Parent,card.Position,GOLD) end
	task.delay(0.25,function() if self.gui==gui then self:Dismiss() end end)
end

function Controller:Show(granted)
	local app = self.app
	self:Dismiss(true)
	-- Acquire before closing the main panel so its exit cannot clear our blur.
	app:SetMenuBlur("daily",true)
	-- One modal at a time: AppController closes every other menu.
	if app.CloseOtherMenus then app:CloseOtherMenus("daily")
	else
		app:ClosePanel()
		if app.operationsPanel then app.operationsPanel:Dismiss(true) end
		if app.rebirthPanel then app.rebirthPanel:Dismiss(true) end
	end
	self.previousSelection = GuiService.SelectedObject
	local gui = if app.editPreview then Theme.Container(app.other,"DailyStreak")
		else Theme.InsetContainer(app.other,"DailyStreak",Enum.ScreenInsets.CoreUISafeInsets)
	gui.ZIndex = 30
	self.gui,self.closing,self.collecting = gui,false,false
	local frames = Theme.Container(gui,"FRAMES")
	local backdropParent = if app.editPreview then frames
		else Theme.InsetContainer(frames,"BackdropLayer",Enum.ScreenInsets.None)
	local backdrop = Theme.Frame(backdropParent,"Backdrop",UDim2.fromScale(1,1))
	backdrop.BackgroundTransparency,backdrop.Active = 1,true
	local panel = Instance.new("CanvasGroup")
	panel.Name = "DailyStreak"
	panel.BackgroundTransparency,panel.BorderSizePixel,panel.GroupTransparency = 1,0,1
	panel.Active,panel.ZIndex = true,2
	panel.AnchorPoint,panel.Position = Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
	panel.Parent,self.panel = frames,panel
	if MenuLayout.Control(app.gui,LAYOUT_NAME) then
		MenuLayout.Apply(app.gui,LAYOUT_NAME,panel)
	else
		panel.Size = DEFAULT_SIZE
		Theme.Aspect(panel,DEFAULT_ASPECT)
	end
	if app.editPreview then
		panel.Size,panel.Position,panel.AnchorPoint = UDim2.fromScale(1,1),UDim2.fromScale(0.5,0.5),Vector2.new(0.5,0.5)
	end
	self.panelSize,self.panelPosition = panel.Size,panel.Position
	-- Past Day 7 the cards loop (granted.slot); the streak itself keeps counting.
	local today = math.clamp(granted.slot or 1,1,#TILES)
	local header = Theme.Header(panel,"Header","Daily Rewards",GOLD)
	Theme.LayoutHeader(header)
	local main = Theme.Container(panel,"Main")
	Theme.BelowHeader(header,main)
	Theme.Surface(main,Color3.fromRGB(24,30,26))
	main.UIStroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	-- October 14 grid (owner reference): Days 1–6 in two rows of three, Day 7 tall on the right.
	self.timer,self.collect = nil,nil
	local todayCard
	for index=1,6 do
		local column,row = (index-1)%3,(index-1)//3
		local card = self:Card(main,index,today,granted,0.025+column*0.232,0.035+row*0.48,0.215,0.45)
		if index==today then todayCard = card end
	end
	local seventh = self:Card(main,7,today,granted,0.72,0.035,0.255,0.93)
	if today==7 then todayCard = seventh end
	Theme.HeaderClose(header,function() self:Collect(granted) end)
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	-- Tomorrow's countdown (a plain once-a-second text update, not an animation).
	if self.timer then
		local timer = self.timer
		task.spawn(function()
			while self.gui==gui and timer.Parent do
				timer.Text = clock(self:SecondsToReset())
				task.wait(1)
			end
		end)
	end
	local restingSize,restingPosition = self.panelSize,self.panelPosition
	if not app.reducedMotion then
		panel.Size = UDim2.fromScale(restingSize.X.Scale*0.94,restingSize.Y.Scale*0.94)
		panel.Position = UDim2.fromScale(restingPosition.X.Scale,restingPosition.Y.Scale+0.035)
	end
	-- Today's card breathes from its centre (same place at rest); reduced motion keeps it still.
	self.todayCard = todayCard
	if todayCard then
		Theme.Motion:Center(todayCard)
		Theme.Motion:Breathe(todayCard,1.04,0.7)
	end
	Theme.Motion:Tween(panel,"daily-size",{Size=restingSize},0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
	Theme.Motion:Tween(panel,"position",{Position=restingPosition},0.28)
	Theme.Motion:Tween(panel,"daily-fade",{GroupTransparency=0},0.22)
	if app.editPreview then return end
	ContextActionService:BindActionAtPriority("PetRollDailyRewardClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then self:Collect(granted) end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	table.insert(self.connections,UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode==Enum.KeyCode.Escape then self:Collect(granted) end
	end))
	if UserInputService.GamepadEnabled and self.collect then GuiService.SelectedObject = self.collect end
end

function Controller:Destroy()
	self.alive = false
	if self.retry then task.cancel(self.retry);self.retry = nil end
	self.pending = nil
	self:Dismiss(true)
end

return Controller
