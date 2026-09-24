--!strict
-- Displays an already-saved server receipt; dismissal never grants currency.
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.UITheme)
local Art = require(script.Parent.ShopPreviewArt)
local Controller = {}
Controller.__index = Controller

local function duration(seconds)
	local minutes = math.floor(seconds / 60)
	if minutes < 60 then return minutes .. "m" end
	return math.floor(minutes / 60) .. "h " .. minutes % 60 .. "m"
end

function Controller.new(app)
	return setmetatable({app=app,seen=nil,connections={}},Controller)
end

function Controller:Dismiss()
	if not self.gui then return end
	ContextActionService:UnbindAction("PetRollOfflineCashClose")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.gui) then
		GuiService.SelectedObject=if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	self.gui:Destroy();self.gui=nil
end

function Controller:Receive(state)
	local reward=state.offlineCash
	if not reward or reward.amount<=0 or reward.id==self.seen then return end
	self.seen=reward.id
	self:Dismiss()
	self.app:ClosePanel()
	self.previousSelection=GuiService.SelectedObject
	local gui=Instance.new("ScreenGui")
	gui.Name,gui.ResetOnSpawn,gui.DisplayOrder="OfflineCashGui",false,15
	gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent=self.app.gui.Parent
	self.gui=gui
	local backdrop=Theme.Frame(gui,"Backdrop",UDim2.fromScale(1,1),Theme.Arcade.border)
	backdrop.BackgroundTransparency,backdrop.Active=0.5,true
	local panel=Theme.Frame(gui,"OfflineCash",UDim2.fromOffset(560,454))
	panel.BackgroundTransparency,panel.Active,panel.ZIndex=1,true,2
	panel.AnchorPoint,panel.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
	local scale=Instance.new("UIScale");scale.Parent=panel
	local header,title=Theme.Header(panel,"Header","Welcome back!",Theme.Arcade.gold)
	header.Size=UDim2.new(1,0,0,64)
	title.Position,title.Size,title.TextSize=UDim2.fromOffset(18,0),UDim2.new(1,-110,1,0),32
	local function close() self.app.audio:Play("Click");self:Dismiss() end
	local closeButton=Theme.ActionButton(header,"Close","×",close,Theme.ActionColors.danger)
	closeButton.Position,closeButton.Size,closeButton.TextSize=UDim2.new(1,-84,0,0),UDim2.fromOffset(84,64),32
	local body=Theme.Frame(panel,"Body",UDim2.new(1,0,1,-64))
	body.Position=UDim2.fromOffset(0,64)
	Theme.Surface(body);Theme.ApplyPopupStyle(panel)
	local content=Theme.Frame(body,"Content",UDim2.new(1,-40,1,-40))
	content.Position,content.BackgroundTransparency=UDim2.fromOffset(20,20),1
	local list=Instance.new("UIListLayout")
	list.Padding,list.SortOrder,list.Parent=UDim.new(0,14),Enum.SortOrder.LayoutOrder,content
	local function label(parent,name,value,size,height,color)
		local item=Theme.Label(parent,name,value,size,color)
		item.Size=UDim2.new(1,0,0,height)
		return item
	end
	local hero=Theme.Frame(content,"CashEarned",UDim2.new(1,0,0,106))
	hero.BackgroundTransparency,hero.LayoutOrder=1,1
	local art=Art.CashPile(hero,1)
	art.Position=UDim2.fromOffset(0,3)
	local eyebrow=label(hero,"Eyebrow","OFFLINE CASH",16,22,Theme.Colors.muted)
	local amount=label(hero,"Amount","+$"..Theme.Money(reward.amount),56,68)
	amount.TextScaled,amount.TextWrapped=true,false
	local amountSize=Instance.new("UITextSizeConstraint")
	amountSize.MaxTextSize,amountSize.MinTextSize,amountSize.Parent=56,20,amount
	local explanation=label(content,"Explanation","Your flock earned cash while you were away.",20,24)
	explanation.LayoutOrder=2
	local stats=Theme.Frame(content,"Statistics",UDim2.new(1,0,0,48))
	stats.BackgroundTransparency,stats.LayoutOrder=1,3
	local cents=math.floor(reward.rate*100+0.5)
	local rateText="$"..Theme.Money(math.floor(cents/100))..string.format(".%02d / sec",cents%100)
	for index,entry in {{"TIME AWAY",duration(reward.awaySeconds)},{"OFFLINE RATE",rateText}} do
		local column=Theme.Frame(stats,"Stat"..index,UDim2.new(0.5,-8,1,0))
		column.Position,column.BackgroundTransparency=UDim2.new((index-1)*0.5,if index==2 then 8 else 0,0,0),1
		label(column,"Name",entry[1],14,20,Theme.Colors.muted)
		local value=label(column,"Value",entry[2],22,28)
		value.Position,value.TextScaled=UDim2.fromOffset(0,20),true
		local size=Instance.new("UITextSizeConstraint");size.MaxTextSize,size.MinTextSize,size.Parent=22,14,value
	end
	local hours=math.floor(reward.maxSeconds/3600)
	local limit=label(content,"Limit",if reward.capped then hours.."-hour limit reached · "..hours.."h counted"
		else math.floor(reward.efficiency*100+0.5).."% earnings · Up to "..hours.." hours",16,20,Theme.Colors.muted)
	limit.LayoutOrder=4
	local continue=Theme.ActionButton(content,"Continue","Let's go!",close,Theme.ActionColors.purchase)
	continue.Size,continue.LayoutOrder=UDim2.new(1,0,0,56),5
	local saved=label(content,"Saved","Cash already added. Closing this keeps it.",16,20,Theme.Colors.muted)
	saved.LayoutOrder=6
	local function resize()
		local available=gui.AbsoluteSize
		if available.X<=0 or available.Y<=0 then return end
		local width=math.min(560,math.max(280,available.X-24))
		local compact=width<460
		local height=if compact then 474 else 454
		panel.Size=UDim2.fromOffset(width,height)
		scale.Scale=math.min(1,(available.X-24)/width,(available.Y-24)/height)
		title.TextSize=if compact then 28 else 32
		explanation.TextSize,explanation.Size=if compact then 18 else 20,UDim2.new(1,0,0,if compact then 44 else 24)
		local iconWidth=if compact then 84 else 108
		art.Size=UDim2.fromOffset(iconWidth,100)
		eyebrow.Position,eyebrow.Size=UDim2.fromOffset(iconWidth+16,15),UDim2.new(1,-iconWidth-16,0,22)
		amount.Position,amount.Size=UDim2.fromOffset(iconWidth+16,37),UDim2.new(1,-iconWidth-16,0,68)
		amountSize.MaxTextSize=if compact then 42 else 56
	end
	table.insert(self.connections,gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	resize()
	ContextActionService:BindActionAtPriority("PetRollOfflineCashClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB,Enum.KeyCode.Escape)
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=continue end
end

function Controller:Destroy()
	self:Dismiss()
end

return Controller
