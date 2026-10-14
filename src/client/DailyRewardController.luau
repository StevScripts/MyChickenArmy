--!strict
-- 7-day login streak popup (docs/team/launch/13_D1_DAILY_STREAK.md). Displays the
-- reward the server already granted (state.daily.granted); Collect only closes it.
-- AppController calls Render(state, result) on every state packet, after the
-- offline receipt (app.offlineCash.gui is set while that receipt is open).
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.UITheme)
local MenuLayout = require(script.Parent.MenuLayout)
local ShopArt = require(script.Parent.ShopPreviewArt)
local Controller = {}
Controller.__index = Controller

local GOLD = Theme.ReferenceColors.Base
local GREEN = Theme.ReferenceColors.Army
local DONE = Color3.fromRGB(112,222,98)
-- Presentation mirror of DailyService.Rewards (server). Keep the two in step.
local TILES = {
	{minutes=5, rolls=0}, {minutes=10, rolls=0}, {minutes=0, rolls=1}, {minutes=20, rolls=0},
	{minutes=30, rolls=0}, {minutes=0, rolls=2}, {minutes=60, rolls=3},
}
local CASH_TIER = {1,1,0,2,2,0,4}
-- Wait for the offline receipt (and the first-visit film) before showing.
local RETRY_SECONDS = 0.4
local AFTER_RECEIPT_SECONDS = 0.6
-- Studio may author MenuLayouts.DailyStreak; otherwise this native Scale frame
-- is height-led on wide screens and width-led on narrow ones.
local LAYOUT_NAME = "DailyStreak"
local DEFAULT_SIZE, DEFAULT_ASPECT = UDim2.fromScale(0.92,0.6), 1.5

local function rolls(n: number): string
	return n.." "..(if n==1 then "roll" else "rolls")
end

-- The client has no income rate, so only today's tile (whose cash the server
-- already granted) shows a dollar amount; other days describe minutes of income.
local function tileText(reward,cash: number?): string
	local money = if cash and cash>0 then "$"..Theme.Number(cash) else nil
	if reward.minutes>0 and reward.rolls>0 then
		return (money or reward.minutes.." min income").." + "..rolls(reward.rolls)
	end
	if reward.minutes>0 then return money or reward.minutes.." min of income" end
	return rolls(reward.rolls)
end

local function rewardText(granted): string
	local parts = {}
	local cash = granted.cash or 0
	local count = granted.rolls or 0
	if cash>0 or count==0 then table.insert(parts,"+$"..Theme.Number(cash)) end
	if count>0 then table.insert(parts,"+"..count.." free "..(if count==1 then "roll" else "rolls")) end
	return table.concat(parts,"  ")
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
	if self.pulse then self.pulse:Cancel();self.pulse = nil end
	self.app:SetMenuBlur("daily",false)
	local function finish()
		if self.gui~=gui then return end
		self.gui,self.panel,self.closing = nil,nil,false
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

-- One day tile. States: done (ticked), today (highlighted), future (dim).
local function tile(parent,index,today,todayCash)
	local reward = TILES[index]
	local item = Theme.Frame(parent,"Day"..index,UDim2.fromScale(0.13,if index==today then 1 else 0.9),Color3.new(1,1,1))
	item.LayoutOrder = index
	-- Tiles keep their own colors; ApplyPopupStyle would darken them.
	item:SetAttribute("OwnsPopupStyle",true)
	local done = index<today
	local tint = if index==today then GOLD elseif done then DONE:Lerp(Color3.new(0,0,0),0.55) else Color3.fromRGB(44,50,54)
	Theme.Gradient(item,tint:Lerp(Color3.new(1,1,1),0.12),tint:Lerp(Color3.new(0,0,0),0.25))
	Theme.Stroke(item,if index==today then Color3.new(1,1,1) else Theme.Arcade.border,if index==today then 3 else Theme.Border.Control)
	local day = label(item,"Day","Day "..index,22)
	day.Position,day.Size = UDim2.fromScale(0.06,0.03),UDim2.fromScale(0.88,0.2)
	local art = Theme.Container(item,"Art")
	art.AnchorPoint,art.Position,art.Size = Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.47),UDim2.fromScale(0.8,0.38)
	Theme.Aspect(art,1)
	local icon = if reward.minutes>0 then ShopArt.CashPile(art,CASH_TIER[index]) else Theme.Image(art,"Roll",Theme.Assets.Luck,UDim2.fromScale(1,1))
	icon.Name,icon.ZIndex = "Icon",5
	local text = label(item,"Reward",tileText(reward,if index==today then todayCash else nil),18)
	text.Position,text.Size = UDim2.fromScale(0.05,0.68),UDim2.fromScale(0.9,0.29)
	if done then
		local tick = label(item,"Done","✓",40,DONE)
		tick.AnchorPoint,tick.Position,tick.Size = Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.47),UDim2.fromScale(0.7,0.4)
		tick.ZIndex = 8
		icon.ImageTransparency = 0.45
	elseif index>today then
		local dim = Theme.Frame(item,"Dim",UDim2.fromScale(1,1),Color3.new(0,0,0))
		dim.BackgroundTransparency,dim.ZIndex = 0.5,7
	end
	return item
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
	self.gui,self.closing = gui,false
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
	local streak = math.max(1,granted.streak or 1)
	local today = math.clamp(granted.slot or 1,1,#TILES)
	-- The header names the highlighted tile; a longer streak (past Day 7 the
	-- tiles loop) is stated in the lead-in so the two never disagree.
	local header = Theme.Header(panel,"Header","Day "..today.." reward!",GOLD)
	local main = Theme.Container(panel,"Main")
	Theme.BelowHeader(header,main)
	Theme.Surface(main,GOLD:Lerp(Color3.new(0,0,0),0.55))
	main.UIStroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	local leadText = if streak>=2 then streak.."-day streak! Come back tomorrow for more."
		else "Come back every day for bigger rewards!"
	local lead = label(main,"LeadIn",leadText,28)
	lead.Position,lead.Size = UDim2.fromScale(0.04,0.03),UDim2.fromScale(0.92,0.1)
	-- One row of seven at every width; tiles shrink with the native frame.
	local row = Theme.Container(main,"Days")
	row.Position,row.Size = UDim2.fromScale(0.03,0.16),UDim2.fromScale(0.94,0.4)
	local list = Instance.new("UIListLayout")
	list.FillDirection,list.SortOrder = Enum.FillDirection.Horizontal,Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment,list.VerticalAlignment = Enum.HorizontalAlignment.Center,Enum.VerticalAlignment.Center
	list.Padding,list.Parent = UDim.new(0.012,0),row
	local todayTile
	for index=1,#TILES do
		local item = tile(row,index,today,granted.cash)
		if index==today then todayTile = item end
	end
	local amount = label(main,"Amount",rewardText(granted),54,Color3.new(1,1,1))
	amount.Position,amount.Size = UDim2.fromScale(0.04,0.6),UDim2.fromScale(0.92,0.15)
	local gradient = Instance.new("UIGradient")
	gradient.Color,gradient.Rotation,gradient.Parent = Theme.ReferenceGradients.Army,90,amount
	local note = if (granted.rolls or 0)>0 then "✓ Free rolls join your Flock when it has room" else "✓ Added to your Cash"
	local saved = label(main,"Saved",note,24,GREEN)
	saved.Position,saved.Size = UDim2.fromScale(0.08,0.765),UDim2.fromScale(0.84,0.055)
	local function close()
		if not self.gui or self.closing then return end
		app.audio:Play("Click")
		-- The reward is already in the wallet; this is presentation only.
		if (granted.cash or 0)>0 and app.feedback then
			local root = app.feedback:Root()
			app.feedback:ShowCash(if root then root.Position else Vector3.zero,granted.cash)
		else
			app.audio:Play("Pop",1.05,{volume=0.4,maxDuration=0.35})
		end
		self:Dismiss()
	end
	local actions = Theme.Container(main,"Actions")
	actions.AnchorPoint,actions.Position,actions.Size = Vector2.new(0.5,1),UDim2.fromScale(0.5,0.965),UDim2.fromScale(0.4,0.13)
	Theme.Aspect(actions,4.329331874847412)
	Theme.HeaderClose(header,close)
	local collect = Theme.ActionButton(actions,"Collect","Collect",close,GREEN)
	collect.Position,collect.Size = UDim2.fromScale(0,0),UDim2.fromScale(1,1)
	Theme.Studs(collect.Visual.Face,0.07,28,0)
	collect.Visual.Caption.Position,collect.Visual.Caption.Size = UDim2.fromScale(0.04,0.1),UDim2.fromScale(0.92,0.8)
	collect.Visual.Caption.TextScaled = true
	collect.Visual.Caption.TextShadow.Visible = false
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	local restingSize,restingPosition = self.panelSize,self.panelPosition
	if not app.reducedMotion then
		panel.Size = UDim2.fromScale(restingSize.X.Scale*0.94,restingSize.Y.Scale*0.94)
		panel.Position = UDim2.fromScale(restingPosition.X.Scale,restingPosition.Y.Scale+0.035)
		-- Today's tile breathes; reduced motion keeps it still.
		local scale = Instance.new("UIScale")
		scale.Parent = todayTile
		self.pulse = TweenService:Create(scale,TweenInfo.new(0.7,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Scale=1.06})
		self.pulse:Play()
	end
	Theme.Motion:Tween(panel,"daily-size",{Size=restingSize},0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	Theme.Motion:Tween(panel,"position",{Position=restingPosition},0.28)
	Theme.Motion:Tween(panel,"daily-fade",{GroupTransparency=0},0.22)
	if app.editPreview then return end
	ContextActionService:BindActionAtPriority("PetRollDailyRewardClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	table.insert(self.connections,UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode==Enum.KeyCode.Escape then close() end
	end))
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = collect end
end

function Controller:Destroy()
	self.alive = false
	if self.retry then task.cancel(self.retry);self.retry = nil end
	self.pending = nil
	self:Dismiss(true)
end

return Controller
