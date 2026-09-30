--!strict
-- Displays an already-saved server receipt; dismissal never grants currency.
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local Theme = require(script.Parent.UITheme)
local MenuLayout = require(script.Parent.MenuLayout)
local Controller = {}
Controller.__index = Controller
local GREEN = Theme.ReferenceColors.Army
local EDGE = 8 -- Keep outlines and button motion inside the fading canvas.

local function fitSingleLine(item, width, maximum, minimum)
	item.TextScaled,item.TextWrapped=false,false
	local size=math.max(minimum,maximum)
	while size>minimum and TextService:GetTextSize(item.Text,size,item.Font,Vector2.new(100000,100000)).X>width-8 do
		size-=1
	end
	item.TextSize=size
end

function Controller.new(app)
	return setmetatable({app=app,seen=nil,connections={}},Controller)
end

function Controller:Dismiss(immediate)
	local gui,panel=self.gui,self.panel
	if not gui or (self.closing and not immediate) then return end
	self.closing=true
	ContextActionService:UnbindAction("PetRollOfflineCashClose")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject=if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	self.app:SetMenuBlur("offline",false)
	local function finish()
		if self.gui~=gui then return end
		self.gui,self.panel,self.closing=nil,nil,false
		gui:Destroy()
	end
	if immediate then finish();return end
	Theme.Motion:Tween(Theme.Motion:Scale(panel),"scale",{Scale=0.97},0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	Theme.Motion:Tween(panel,"position",{Position=UDim2.new(0.5,0,0.5,12)},0.16)
	Theme.Motion:Tween(panel,"receipt-fade",{GroupTransparency=1},0.16,nil,nil,finish)
end

function Controller:Receive(state)
	local reward=state.offlineCash
	if not reward or reward.amount<=0 or reward.id==self.seen then return end
	self.seen=reward.id
	self:Dismiss(true)
	-- Acquire before closing the main panel so its exit cannot clear our blur.
	self.app:SetMenuBlur("offline",true)
	self.app:ClosePanel()
	self.previousSelection=GuiService.SelectedObject
	local gui=if self.app.editPreview then Theme.Container(self.app.other,"OfflineEarnings")
		else Theme.InsetContainer(self.app.other,"OfflineEarnings",Enum.ScreenInsets.CoreUISafeInsets)
	gui.ZIndex=30
	self.gui,self.closing=gui,false
	local frames=Theme.Container(gui,"FRAMES")
	local backdrop=Theme.Frame(frames,"Backdrop",UDim2.fromScale(1,1))
	backdrop.BackgroundTransparency,backdrop.Active=1,true
	local panel=Instance.new("CanvasGroup")
	panel.Name,panel.Size="OfflineCash",UDim2.fromOffset(576,456)
	panel.BackgroundTransparency,panel.BorderSizePixel,panel.GroupTransparency=1,0,1
	panel.Active,panel.ZIndex=true,2
	panel.AnchorPoint,panel.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
	panel.Parent,self.panel=frames,panel
	local header,title=Theme.Header(panel,"Header","Offline Earnings",GREEN)
	title.TextXAlignment=Enum.TextXAlignment.Center
	title.TextShadow.Visible=false
	Theme.Stroke(header,Theme.Arcade.border,3)
	local main=Theme.Container(panel,"Main")
	local actions=Theme.Container(main,"Actions")
	actions.AnchorPoint=Vector2.new(0,1)
	local body=Instance.new("ScrollingFrame")
	body.Name,body.BackgroundTransparency,body.BorderSizePixel="Content",1,0
	body.AutomaticCanvasSize,body.CanvasSize=Enum.AutomaticSize.Y,UDim2.new()
	body.ScrollingDirection,body.ScrollBarThickness=Enum.ScrollingDirection.Y,3
	body.ScrollBarImageColor3,body.Parent=GREEN,main
	local list=Instance.new("UIListLayout")
	list.SortOrder,list.Parent=Enum.SortOrder.LayoutOrder,body
	local function label(parent,name,value,size,height,color)
		local item=Theme.Label(parent,name,value,size,color)
		item.Size=UDim2.new(1,0,0,height)
		item.TextXAlignment=Enum.TextXAlignment.Center
		return item
	end
	local hero=Theme.Frame(body,"CashEarned",UDim2.new(1,0,0,224))
	hero.BackgroundTransparency,hero.LayoutOrder=1,1
	local lead=label(hero,"LeadIn","You've earned",30,32)
	local amount=label(hero,"Amount","+$"..Theme.Money(reward.amount),88,120,Color3.new(1,1,1))
	local gradient=Instance.new("UIGradient")
	gradient.Color,gradient.Rotation,gradient.Parent=Theme.ReferenceGradients.Army,90,amount
	local explanation=label(hero,"Explanation","while you were away!",28,30)
	local saved=label(body,"Saved","✓ Added to your cash",24,28,GREEN)
	saved.LayoutOrder=2
	local function close()
		if not self.gui or self.closing then return end
		self.app.audio:Play("Click")
		self:Dismiss()
	end
	local continue=Theme.ActionButton(actions,"Continue","Continue",close,GREEN)
	Theme.Studs(continue.Visual.Face,0.16,28,0)
	continue.Visual.Caption.Position,continue.Visual.Caption.Size=UDim2.new(),UDim2.fromScale(1,1)
	continue.Visual.Caption.TextShadow.Visible=false
	local function resize()
		local available=gui.AbsoluteSize
		if available.X<=0 or available.Y<=0 then return end
		local width,height=MenuLayout.Size(self.app.gui,"Offline",available)
		if self.app.editPreview then width,height=available.X,available.Y end
		local innerWidth,innerHeight=width-EDGE*2,height-EDGE*2
		local short=innerHeight<390
		local headerHeight=if short then 52 else 64
		local buttonHeight=if short then 52 else 60
		local padding,gap=if short then 12 else 20,if short then 8 else 14
		local contentWidth=math.max(1,innerWidth-padding*2)
		local contentHeight=math.max(1,innerHeight-headerHeight-buttonHeight-padding*3-gap)
		local heroHeight=math.max(124,contentHeight-28-gap)
		local leadHeight,explanationHeight=if short then 26 else 32,if short then 26 else 30
		local amountHeight=heroHeight-leadHeight-explanationHeight-12
		panel.Size=UDim2.fromScale(width/available.X,height/available.Y)
		header.Position,header.Size=UDim2.fromOffset(EDGE,EDGE),UDim2.new(1,-EDGE*2,0,headerHeight)
		title.Position,title.Size=UDim2.fromOffset(12,0),UDim2.new(1,-24,1,0)
		local mainHeight=innerHeight-headerHeight
		Theme.RelativeRect(main,EDGE,EDGE+headerHeight,innerWidth,mainHeight,width,height)
		Theme.RelativeRect(body,padding,padding,contentWidth,contentHeight,innerWidth,mainHeight)
		actions.Position,actions.Size=UDim2.new(0,padding,1,-padding),UDim2.new(1,-padding*2,0,buttonHeight)
		list.Padding=UDim.new(0,gap)
		hero.Size=UDim2.new(1,0,0,heroHeight)
		lead.Size=UDim2.new(1,0,0,leadHeight)
		amount.Position,amount.Size=UDim2.fromOffset(0,leadHeight+6),UDim2.new(1,0,0,amountHeight)
		explanation.Position,explanation.Size=UDim2.new(0,0,1,-explanationHeight),UDim2.new(1,0,0,explanationHeight)
		continue.Position,continue.Size=UDim2.new(),UDim2.fromScale(1,1)
		continue.TextSize=if short then 28 else 34
		fitSingleLine(title,innerWidth-24,if short then 32 else 42,22)
		fitSingleLine(lead,contentWidth,if short then 24 else 30,20)
		fitSingleLine(amount,contentWidth-8,math.min(88,amountHeight-8),18)
		fitSingleLine(explanation,contentWidth,if short then 22 else 28,18)
		fitSingleLine(saved,contentWidth,24,18)
		title.TextFace.TextOutline.Thickness=2
		lead.TextOutline.Thickness=1.3
		amount.TextOutline.Thickness=math.min(3,amount.TextSize*0.04)
		explanation.TextOutline.Thickness=1.5
		saved.TextOutline.Thickness=1.2
		continue.Visual.Caption.TextFace.TextOutline.Thickness=1.5
	end
	table.insert(self.connections,gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	resize()
	local scale=Theme.Motion:Scale(panel)
	scale.Scale=if self.app.reducedMotion then 1 else 0.94
	panel.Position=UDim2.new(0.5,0,0.5,if self.app.reducedMotion then 0 else 18)
	Theme.Motion:Tween(scale,"scale",{Scale=1},0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	Theme.Motion:Tween(panel,"position",{Position=UDim2.fromScale(0.5,0.5)},0.28)
	Theme.Motion:Tween(panel,"receipt-fade",{GroupTransparency=0},0.22)
	if self.app.editPreview then return end
	ContextActionService:BindActionAtPriority("PetRollOfflineCashClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	table.insert(self.connections,UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode==Enum.KeyCode.Escape then close() end
	end))
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=continue end
end

function Controller:Destroy()
	self:Dismiss(true)
end

return Controller
