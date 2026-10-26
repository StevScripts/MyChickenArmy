--!strict
-- 7-day login streak popup (docs/team/launch/13_D1_DAILY_STREAK.md). Displays the
-- reward the server already granted (state.daily.granted); claiming it here is
-- presentation only.
-- October 21 reference parity (docs/team/REFERENCE_PARITY_20261021.md §1 t3/t6/t118,
-- §2.7): "Daily Rewards" 1:1 with the reference: a green studded header with the
-- calendar icon; Days 1–6 as two rows of three blue cards and a tall orange Day 7 on
-- the right; each card shows its art over rays, the amount and a "Day N" ribbon.
-- Earlier days are greyed with a big green check and "Claimed!", today's card glows
-- and claims on a tap (Claim cue, confetti, coins flying into the HUD, the green
-- "You earned N Coins!" banner, the card flips to Claimed!), later days are dimmed.
-- Tapping any other card shows the red "Come back later…" banner. A chip under the
-- window counts down to the next reward ("Next reward in: 08:29:14").
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
local BLACK = Color3.new(0,0,0)
local MUTED = Color3.fromRGB(176,184,190)
-- Presentation mirror of DailyService.Rewards (server). Keep the two in step.
local TILES = { -- October 23 empty start: small Day 1 (see DailyService.Rewards)
	{minutes=0.5, rolls=0}, {minutes=1, rolls=0}, {minutes=0, rolls=1}, {minutes=2, rolls=0},
	{minutes=5, rolls=0}, {minutes=0, rolls=2}, {minutes=15, rolls=3},
}
local CASH_TIER = {1,2,0,3,3,0,4}
-- Reference card families: Days 1–6 blue, Day 7 orange; a claimed card goes slate.
local FAMILIES = {
	Day={top=Color3.fromRGB(92,186,255),bottom=Color3.fromRGB(30,108,212),ribbon=Color3.fromRGB(20,66,150)},
	Big={top=Color3.fromRGB(255,190,70),bottom=Color3.fromRGB(242,118,22),ribbon=Color3.fromRGB(176,74,12)},
	Claimed={top=Color3.fromRGB(74,84,94),bottom=Color3.fromRGB(42,50,58),ribbon=Color3.fromRGB(28,34,40)},
}
local CLAIM_RIBBON = Color3.fromRGB(46,176,34)
local COME_BACK = "Come back later for your daily reward! Your chickens keep earning while you're away!"
-- Header calendar (assets/rewards-popups-20261021/Calendar.png). Until the lead
-- uploads it and fills this in, the header shows the Time Skip clock.
Controller.Calendar = "rbxassetid://85849770547707"
local CLOCK = Theme.GemArt.TimeSkip
local MIN_COINS = 60 -- DailyService.MinCoins (October 23: a Coins day pays its minutes of steady income, at least this)
local DAY_SECONDS = 86400 -- DailyService.DaySeconds (UTC days)
-- Wait for the offline receipt (and the first-visit film) before showing.
local RETRY_SECONDS = 0.4
local AFTER_RECEIPT_SECONDS = 0.6
-- Reference geometry (t3): the window is 760 x 426 px, header included, and the
-- "Next reward in" chip sits 10 px under it, 30 px tall. The holder carries both, so
-- the chip stays glued under the window's left edge on every screen (Scale only).
local WINDOW_ASPECT = 760/426
local HOLDER_ASPECT = 760/466
local WINDOW_SHARE = 426/466
local CHIP_TOP, CHIP_HEIGHT = 436/466, 30/466
-- Studio may author MenuLayouts.DailyStreak (size/position); otherwise the window is
-- 0.56 of the screen height (a little larger than the reference's 0.43 so phone text
-- stays readable), centred just below the top banners.
local LAYOUT_NAME = "DailyStreak"
local DEFAULT_SIZE, DEFAULT_POSITION = UDim2.fromScale(0.92,0.613), UDim2.fromScale(0.5,0.55)
-- Cards in body coordinates (the reference's margins and gaps); Day 7 spans both rows.
local COLUMN_X, COLUMN_STEP, CARD_W = 0.042, 0.2276, 0.209
local ROW_Y, ROW_STEP, CARD_H = 0.1, 0.425, 0.395
local BIG_X, BIG_W, BIG_H = 0.729, 0.229, 0.82

-- Today's tile shows the coins the server granted. Other days estimate from the
-- HUD income (the server pays minutes of income at claim time).
local function rollsText(rolls: number): string
	return "+"..rolls.." Free "..(if rolls==1 then "Roll" else "Rolls")
end

local function earnedText(granted): string
	local cash = math.floor(tonumber(granted.cash) or 0)
	local rolls = math.floor(tonumber(granted.rolls) or 0)
	local parts = {}
	if cash>0 then table.insert(parts,Theme.Coins(cash)) end
	if rolls>0 then table.insert(parts,rolls.." Free "..(if rolls==1 then "Roll" else "Rolls")) end
	if #parts==0 then return "Daily reward claimed!" end
	return "You earned "..table.concat(parts," and ").."!"
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
	-- October 21: Day 1 opens right after the guide's core payoff, not over it.
	if app.commander and app.commander:Celebrating() then return true end
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
	local gui,holder = self.gui,self.holder
	if not gui or (self.closing and not immediate) then return end
	self.closing = true
	ContextActionService:UnbindAction("PetRollDailyRewardClose")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if self.reveal then self.reveal.cancel();self.reveal = nil end
	for _,view in self.views or {} do Theme.Motion:Settle(view.button) end
	self.app:SetMenuBlur("daily",false)
	local function finish()
		if self.gui~=gui then return end
		self.gui,self.holder,self.panel,self.chip,self.views,self.closing = nil,nil,nil,nil,nil,false
		gui:Destroy()
		-- A later day granted while this was open (crossing UTC midnight online).
		if self.alive and self.pending then self:Schedule() end
	end
	if immediate or not holder then finish();return end
	self.app:Cue("MenuClose",nil,nil,{voiceKey="MenuClose",cooldown=0.2})
	local motion = Theme.Motion
	motion:Tween(motion:ScaleOf(holder),"pop",{Scale=0.97},0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	motion:Tween(holder,"position",{Position=self.restingPosition+UDim2.fromScale(0,0.025)},0.16)
	if self.chip then motion:Tween(self.chip,"daily-fade",{GroupTransparency=1},0.16) end
	motion:Tween(self.panel,"daily-fade",{GroupTransparency=1},0.16,nil,nil,finish)
end

-- The X and Escape: an unclaimed reward is claimed first (the celebration plays, then
-- the window closes), otherwise the window just closes.
function Controller:Close()
	if not self.gui or self.closing then return end
	if not self.collected then self:Collect(true);return end
	self:Dismiss()
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

-- A square art box centred at (cx, cy) of the card, `size` of the card's height,
-- with the white product rays turning slowly behind it (clipped by the card).
local function artBox(parent,name,cx,cy,size,spin)
	local box = Theme.Container(parent,name)
	box.AnchorPoint,box.Position,box.Size = Vector2.new(0.5,0.5),UDim2.fromScale(cx,cy),UDim2.fromScale(1,size)
	Theme.Aspect(box,1)
	local rays = ShopArt.ProductRays(box,WHITE)
	rays.AnchorPoint,rays.Position,rays.Size,rays.ZIndex = Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(1.7,1.7),3
	if spin then Theme.Motion:Tween(rays,"spin",{Rotation=360},30,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1,false) end
	return box
end

local function coinArt(box,index)
	local icon = ShopArt.CashPile(box,CASH_TIER[index])
	icon.Name,icon.ZIndex = "Icon",4
	return icon
end

local function rollArt(box)
	local icon = Theme.Image(box,"Icon",Theme.Assets.Luck,UDim2.fromScale(1,1))
	icon.ZIndex = 4
	return icon
end

-- One day card: a tappable button whose Visual carries the card colour, studs, art,
-- amount, the "Day N" ribbon and the claimed/dim overlays (SetState switches them).
function Controller:Card(parent,index,granted,x,y,w,h)
	local reward = TILES[index]
	local big = index==#TILES
	local family = if big then FAMILIES.Big else FAMILIES.Day
	local spin = not self.app.reducedMotion
	local button = Instance.new("TextButton")
	button.Name,button.Text,button.AutoButtonColor,button.Selectable = "Day"..index,"",false,true
	button.BackgroundTransparency,button.BorderSizePixel = 1,0
	button.Position,button.Size = UDim2.fromScale(x,y),UDim2.fromScale(w,h)
	button:SetAttribute("ClickSound",false) -- Each tap plays its own answer.
	button.Parent = parent
	-- White base: the gradient carries the colour (a UIGradient multiplies).
	local visual = Theme.Frame(button,"Visual",UDim2.fromScale(1,1),WHITE)
	visual.AnchorPoint,visual.Position,visual.ClipsDescendants = Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),true
	visual:SetAttribute("OwnsPopupStyle",true)
	local gradient = Theme.Gradient(visual,family.top,family.bottom)
	-- Small, subtle studs (owner feedback): about 15 cells across a card.
	Theme.Studs(visual,0.07,28,0):SetAttribute("StudScaleWidth",1.6)
	Theme.Stroke(visual,BLACK,3)
	local income = tonumber(self.app.state and self.app.state.income) or 0
	local cash = if index==self.today then (tonumber(granted.cash) or 0) else math.max(math.floor(income*reward.minutes*60),MIN_COINS)
	local coinIcon
	if big then
		-- The reference's Day 7: the pack (our 3 Free Rolls) + the coins, then the amount.
		local rolls = artBox(visual,"RollArt",0.5,0.2,0.27,spin)
		rollArt(rolls)
		local count = place(label(visual,"Rolls",reward.rolls.." Free Rolls",26,WHITE),0.04,0.3,0.92,0.07)
		count.ZIndex = 6
		local plus = place(label(visual,"Plus","+",40,WHITE),0.3,0.385,0.4,0.08)
		plus.ZIndex = 6
		local coins = artBox(visual,"CoinArt",0.5,0.6,0.22,spin)
		coinIcon = coinArt(coins,index)
		local amount = place(label(visual,"Reward","+"..Theme.Money(cash),28,Theme.Colors.coins),0.04,0.705,0.92,0.08)
		amount.ZIndex = 6
	else
		local box = artBox(visual,"Art",0.5,0.38,0.52,spin)
		if reward.minutes>0 then coinIcon = coinArt(box,index) else rollArt(box) end
		local text = if reward.minutes>0 then "+"..Theme.Money(cash) else rollsText(reward.rolls)
		local amount = place(label(visual,"Reward",text,28,if reward.minutes>0 then Theme.Colors.coins else WHITE),0.04,0.56,0.92,0.17)
		amount.ZIndex = 6
	end
	-- The "Day N" ribbon along the card's foot.
	local ribbonY,ribbonH = if big then 0.885 else 0.78,if big then 0.095 else 0.18
	local ribbon = Theme.Frame(visual,"Ribbon",UDim2.fromScale(0.94,ribbonH),family.ribbon)
	ribbon.Position,ribbon.BackgroundTransparency,ribbon.ZIndex = UDim2.fromScale(0.03,ribbonY),0.08,6
	local ribbonText = place(label(ribbon,"Day","Day "..index,30,WHITE),0.04,0.06,0.92,0.88)
	ribbonText.ZIndex = 7
	-- Later days are dimmed; claimed days go slate with a big green check and "Claimed!".
	local dim = Theme.Frame(visual,"Dim",UDim2.fromScale(1,1),BLACK)
	dim.BackgroundTransparency,dim.ZIndex,dim.Visible = 0.5,8,false
	local shade = Theme.Frame(visual,"Claimed",UDim2.fromScale(1,1),FAMILIES.Claimed.bottom)
	shade.BackgroundTransparency,shade.ZIndex,shade.Visible = 0.22,8,false
	local check = label(visual,"Check","✓",90,DONE)
	check.AnchorPoint,check.Position,check.Size = Vector2.new(0.5,0.5),UDim2.fromScale(0.5,if big then 0.45 else 0.4),UDim2.fromScale(0.86,if big then 0.34 else 0.62)
	check.ZIndex,check.Visible = 9,false
	check.TextOutline.Thickness = 0.09
	local claimed = place(label(visual,"ClaimedText","Claimed!",30,MUTED),0.05,ribbonY+ribbonH*0.06,0.9,ribbonH*0.88)
	claimed.ZIndex,claimed.Visible = 9,false
	Theme.Motion:BindButton(button,visual)
	button.Activated:Connect(function() self:Tap(index) end)
	return {index=index,button=button,visual=visual,gradient=gradient,family=family,ribbon=ribbon,ribbonText=ribbonText,
		dim=dim,shade=shade,check=check,claimed=claimed,coinIcon=coinIcon,state=""}
end

function Controller:SetState(view,state: string)
	view.state = state
	local claimed = state=="claimed"
	view.shade.Visible,view.check.Visible,view.claimed.Visible = claimed,claimed,claimed
	view.ribbonText.Visible = not claimed
	view.dim.Visible = state=="future"
	local family = if claimed then FAMILIES.Claimed else view.family
	view.gradient.Color = ColorSequence.new(family.top,family.bottom)
	view.ribbon.BackgroundColor3 = if state=="today" then CLAIM_RIBBON else family.ribbon
	view.ribbonText.Text = if state=="today" then "Claim!" else "Day "..view.index
	if state=="today" then Theme.Motion:Glow(view.button,GOLD,3) else Theme.Motion:StopGlow(view.button) end
end

-- DailyService grants once per UTC day, so the next reward unlocks at UTC midnight.
function Controller:SecondsToReset(): number
	local now = workspace:GetServerTimeNow()
	return DAY_SECONDS-(now%DAY_SECONDS)
end

-- Today's card claims; every other card (and today's once claimed) answers like the
-- reference: a small shake and the red "Come back later…" banner (its notice plays
-- the refusal sound, so no second cue is stacked on it).
function Controller:Tap(index: number)
	if not self.gui or self.closing then return end
	local view = self.views and self.views[index]
	if view and view.state=="today" and not self.collected then self:Collect(false);return end
	if view then Theme.Motion:Shake(view.visual,5) end
	self.app:Notify(COME_BACK,false)
end

-- The reward is already in the wallet; this is presentation only: the Claim cue, the
-- card flips to Claimed! with a stamped check, a ring and a small confetti burst over
-- it, coins fly from its art into the HUD readout, and the green banner names it.
function Controller:Collect(closeAfter: boolean)
	if not self.gui or self.closing or self.collected then return end
	self.collected = true
	local app,granted,gui = self.app,self.granted,self.gui
	local motion = Theme.Motion
	app:Cue("Claim","UIPurchase",nil,{voiceKey="DailyClaim",cooldown=0.3})
	local view = self.views and self.views[self.today]
	if view then
		motion:StopBreathe(view.button)
		self:SetState(view,"claimed")
		motion:PopScale(view.check,1.6,0.3)
		motion:Ripple(view.visual,GOLD)
		local screen = app.gui
		if screen then
			motion:Confetti(screen,{count=16,origin=motion:Point(screen,motion:CenterOf(view.visual)),spread=0.3,seconds=1.3})
			local hud = app.hud
			local target = hud and (hud.cashIcon or hud.money)
			local cash = tonumber(granted.cash) or 0
			if cash>0 and target and target.Parent and view.coinIcon and view.coinIcon.Parent then
				local to = motion:Point(screen,motion:CenterOf(target))
				local from = motion:Point(screen,motion:CenterOf(view.coinIcon))
				for coin=1,5 do
					motion:Fly(screen,Theme.Assets.Coin,from+UDim2.fromScale((coin-3)*0.012,0),to,{seconds=0.5+coin*0.05,arc=0.1,onArrive=function()
						if coin==1 then app:Cue("CoinPickup","Collect",1,{voiceKey="CoinArrive",cooldown=0.15,pitchVariance=0.05}) end
					end})
				end
			end
		end
	end
	app:Notify(earnedText(granted),true)
	if closeAfter then
		task.delay(0.6,function() if self.gui==gui then self:Dismiss() end end)
	end
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
	-- Past Day 7 the cards loop (granted.slot); the streak itself keeps counting.
	self.gui,self.closing,self.collected,self.granted = gui,false,false,granted
	self.today = math.clamp(tonumber(granted.slot) or 1,1,#TILES)
	local frames = Theme.Container(gui,"FRAMES")
	local backdropParent = if app.editPreview then frames
		else Theme.InsetContainer(frames,"BackdropLayer",Enum.ScreenInsets.None)
	local backdrop = Theme.Frame(backdropParent,"Backdrop",UDim2.fromScale(1,1))
	backdrop.BackgroundTransparency,backdrop.Active = 1,true
	local holder = Theme.Container(frames,"DailyStreak")
	holder.AnchorPoint,holder.ZIndex = Vector2.new(0.5,0.5),2
	if MenuLayout.Control(app.gui,LAYOUT_NAME) then MenuLayout.Apply(app.gui,LAYOUT_NAME,holder)
	else holder.Size,holder.Position = DEFAULT_SIZE,DEFAULT_POSITION end
	Theme.Aspect(holder,HOLDER_ASPECT)
	self.holder,self.restingPosition = holder,holder.Position
	-- The window: header and body in one CanvasGroup (it owns the shell outline).
	local panel = Instance.new("CanvasGroup")
	panel.Name = "Window"
	panel.BackgroundTransparency,panel.BorderSizePixel,panel.GroupTransparency = 1,0,1
	panel.Active,panel.ZIndex = true,2
	panel.Position,panel.Size = UDim2.fromScale(0,0),UDim2.fromScale(1,WINDOW_SHARE)
	panel.Parent,self.panel = holder,panel
	Theme.Aspect(panel,WINDOW_ASPECT)
	local header = Theme.Header(panel,"Header","Daily Rewards",GREEN)
	header.PageIcon.Image = if Controller.Calendar~="" then Controller.Calendar else CLOCK
	header.PageIcon.Visible = true
	Theme.LayoutHeader(header)
	local main = Theme.Container(panel,"Main")
	Theme.BelowHeader(header,main)
	Theme.Surface(main,Theme.OverlayColors.Top)
	main.UIStroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	-- Days 1–6 in two rows of three, Day 7 tall on the right (reference t3).
	self.views = {}
	local buttons = {}
	for index=1,#TILES do
		local view
		if index==#TILES then view = self:Card(main,index,granted,BIG_X,ROW_Y,BIG_W,BIG_H)
		else
			local column,row = (index-1)%3,(index-1)//3
			view = self:Card(main,index,granted,COLUMN_X+column*COLUMN_STEP,ROW_Y+row*ROW_STEP,CARD_W,CARD_H)
		end
		self.views[index] = view
		self:SetState(view,if index<self.today then "claimed" elseif index==self.today then "today" else "future")
		Theme.Motion:Center(view.button)
		table.insert(buttons,view.button)
	end
	-- Phone hit area: 48 px; the pad stays inside the header and the cards' top margin.
	local close = Theme.HeaderClose(header,function() self:Close() end,2.1)
	close:SetAttribute("ClickSound",false)
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	-- "Next reward in:" + clock + the HH:MM:SS pill, under the window's left edge.
	local chip = Instance.new("CanvasGroup")
	chip.Name = "NextReward"
	chip.BackgroundTransparency,chip.BorderSizePixel,chip.GroupTransparency,chip.ZIndex = 1,0,1,2
	chip.Position,chip.Size = UDim2.fromScale(0,CHIP_TOP),UDim2.fromScale(1,CHIP_HEIGHT)
	chip.Parent,self.chip = holder,chip
	local lead = place(Theme.Label(chip,"Label","Next reward in:",26,WHITE),0,0.04,0.3,0.92)
	lead.TextScaled,lead.ZIndex = true,4
	local pill = Theme.Frame(chip,"Timer",UDim2.fromScale(0.262,0.92),Color3.fromRGB(20,22,24))
	pill.Position,pill.BackgroundTransparency,pill.ZIndex = UDim2.fromScale(0.33,0.04),0.35,3
	Theme.Stroke(pill,BLACK,2)
	local icon = Theme.Image(chip,"Clock",CLOCK,UDim2.fromScale(0.1,1))
	icon.AnchorPoint,icon.Position,icon.ZIndex = Vector2.new(0.5,0.5),UDim2.fromScale(0.35,0.5),5
	Theme.Aspect(icon,1)
	local timer = place(label(pill,"Time",clock(self:SecondsToReset()),26,WHITE),0.2,0.08,0.74,0.84)
	timer.ZIndex = 4
	Theme.ApplyPopupStyle(chip)
	Theme.ScaleText(chip)
	-- The countdown ticks once a second (a plain text update, not an animation).
	task.spawn(function()
		while self.gui==gui and timer.Parent do
			timer.Text = clock(self:SecondsToReset())
			task.wait(1)
		end
	end)
	-- The window pops in, the cards grow in one after another, then today's card
	-- breathes inside its gold ring; reduced motion keeps everything still.
	local motion = Theme.Motion
	local scale = motion:ScaleOf(holder)
	if not app.reducedMotion then holder.Position = self.restingPosition+UDim2.fromScale(0,0.035) end
	scale.Scale = if app.reducedMotion then 1 else 0.94
	motion:Tween(scale,"pop",{Scale=1},0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
	motion:Tween(holder,"position",{Position=self.restingPosition},0.28)
	motion:Tween(panel,"daily-fade",{GroupTransparency=0},0.22)
	motion:Tween(chip,"daily-fade",{GroupTransparency=0},0.3)
	self.reveal = motion:Stagger(buttons,function(button) motion:PopScale(button,0.75,0.28) end,0.05,0.35)
	local todayView = self.views[self.today]
	if todayView then
		-- After the last card's grow-in, so the two never share the UIScale.
		task.delay(0.75,function()
			if self.gui==gui and not self.collected then motion:Breathe(todayView.button,1.04,0.7) end
		end)
	end
	app:Cue("MenuOpen","Pop",nil,{voiceKey="MenuOpen",cooldown=0.2})
	if app.editPreview then return end
	ContextActionService:BindActionAtPriority("PetRollDailyRewardClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then self:Close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	table.insert(self.connections,UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode==Enum.KeyCode.Escape then self:Close() end
	end))
	if UserInputService.GamepadEnabled and todayView then GuiService.SelectedObject = todayView.button end
end

function Controller:Destroy()
	self.alive = false
	if self.retry then task.cancel(self.retry);self.retry = nil end
	self.pending = nil
	self:Dismiss(true)
end

return Controller
