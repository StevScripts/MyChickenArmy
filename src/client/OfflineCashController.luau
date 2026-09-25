--!strict
-- Displays an already-saved server receipt; dismissal never grants currency.
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local Theme = require(script.Parent.UITheme)
local Controller = {}
Controller.__index = Controller

-- Exact icon: assets/offline-cash/compact-ui/saved-check.png (Figma 360:3844).
-- Studio image import is pending; an empty URI avoids an invalid asset request.
local SAVED_CHECK = ""
local GREEN = Theme.ReferenceColors.Army

-- Keep money on one line, using the same measured fitting as ChickenBrowser.
-- Setting TextWrapped=false also disables Roblox's automatic TextScaled fit.
local function fitSingleLine(item, width, maximum, minimum)
	item.TextScaled,item.TextWrapped=false,false
	local size=maximum
	while size>minimum and TextService:GetTextSize(item.Text,size,item.Font,Vector2.new(100000,100000)).X>width-8 do
		size-=1
	end
	item.TextSize=size
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
	-- Figma 359:3508: 448×394, with an inset body and one clear action.
	local panel=Theme.Frame(gui,"OfflineCash",UDim2.fromOffset(448,394))
	panel.BackgroundTransparency,panel.Active,panel.ZIndex=1,true,2
	panel.AnchorPoint,panel.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
	-- Reflow the receipt inside the safe viewport; keep Continue at touch size.
	local header,title=Theme.Header(panel,"Header","Offline Earnings",GREEN)
	header.Size=UDim2.new(1,0,0,64)
	title.Position,title.Size=UDim2.fromOffset(16,8),UDim2.new(1,-32,0,48)
	title.TextXAlignment=Enum.TextXAlignment.Center
	Theme.Stroke(header,Theme.Arcade.border,3)
	local function close()
		if not self.gui then return end
		self.app.audio:Play("Click")
		self:Dismiss()
	end
	local body=Theme.Frame(panel,"Body",UDim2.new(1,-24,0,330))
	body.Position=UDim2.fromOffset(12,64)
	Theme.Surface(body);Theme.ApplyPopupStyle(panel)
	body.UIGradient.Transparency=NumberSequence.new(0.13)
	Theme.Stroke(body,Theme.Arcade.border,3).Transparency=0
	Theme.Studs(header,0.16,28,0).ZIndex=header.ZIndex
	local content=Theme.Frame(body,"Content",UDim2.new(1,-32,1,-36))
	content.Position,content.BackgroundTransparency=UDim2.fromOffset(16,20),1
	local list=Instance.new("UIListLayout")
	list.Padding,list.SortOrder,list.Parent=UDim.new(0,16),Enum.SortOrder.LayoutOrder,content
	local function label(parent,name,value,size,height,color)
		local item=Theme.Label(parent,name,value,size,color)
		item.Size=UDim2.new(1,0,0,height)
		item.TextXAlignment=Enum.TextXAlignment.Center
		return item
	end
	local hero=Theme.Frame(content,"CashEarned",UDim2.new(1,0,0,170))
	hero.BackgroundTransparency,hero.LayoutOrder=1,1
	local lead=label(hero,"LeadIn","You've earned",38,38)
	local amount=label(hero,"Amount","+$"..Theme.Money(reward.amount),92,94,Color3.new(1,1,1))
	-- SourceSans uses smaller em metrics in Roblox. Scale the amount's glyphs
	-- to the Figma size without exceeding Roblox's 100px TextSize ceiling.
	local amountScale=Instance.new("UIScale")
	amountScale.Scale,amountScale.Parent=1.25,amount
	amount.AnchorPoint,amount.Position=Vector2.new(0.5,0.5),UDim2.new(0.5,0,0,85)
	amount.Size=UDim2.new(0.8,0,0,94)
	local gradient=Instance.new("UIGradient")
	gradient.Color,gradient.Rotation,gradient.Parent=Theme.ReferenceGradients.Army,90,amount
	local explanation=label(hero,"Explanation","while you were away!",35,38)
	explanation.Position=UDim2.fromOffset(0,132)
	local saved=Theme.Frame(content,"Saved",UDim2.new(1,0,0,30))
	saved.BackgroundTransparency,saved.LayoutOrder=1,2
	local savedLayout=Instance.new("UIListLayout")
	savedLayout.FillDirection=Enum.FillDirection.Horizontal
	savedLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center
	savedLayout.VerticalAlignment=Enum.VerticalAlignment.Center
	savedLayout.SortOrder,savedLayout.Padding=Enum.SortOrder.LayoutOrder,UDim.new(0,8)
	savedLayout.Parent=saved
	local check=Theme.Image(saved,"SavedCheck",SAVED_CHECK,UDim2.fromOffset(28,28))
	check.LayoutOrder=1
	local savedText=label(saved,"SavedText","Added to your cash",30,30,GREEN)
	savedText.Size,savedText.LayoutOrder=UDim2.fromOffset(220,30),2
	savedText.TextXAlignment=Enum.TextXAlignment.Left
	local continue=Theme.ActionButton(content,"Continue","Continue",close,GREEN)
	continue.Size,continue.LayoutOrder,continue.TextSize=UDim2.new(1,0,0,62),3,40
	Theme.Studs(continue.Visual.Face,0.16,28,0)
	continue.Visual.Caption.Position=UDim2.fromOffset(0,0)
	continue.Visual.Caption.Size=UDim2.fromScale(1,1)
	-- Figma uses a single outlined text face. Keep the shared title/button
	-- components, with their motion and selection behavior, but hide shadows.
	title.TextShadow.Visible=false
	continue.Visual.Caption.TextShadow.Visible=false
	local function resize()
		local available=gui.AbsoluteSize
		if available.X<=0 or available.Y<=0 then return end
		local width,height=math.min(448,available.X-24),math.min(394,available.Y-24)
		local short=height<370
		local headerHeight=if short then 56 else 64
		local buttonHeight=if short then 52 else 62
		local gap=if short then 8 else 16
		local heroHeight=height-headerHeight-24-buttonHeight-30-gap*2
		panel.Size=UDim2.fromScale(width/available.X,height/available.Y)
		header.Size=UDim2.new(1,0,0,headerHeight)
		title.Position,title.Size=UDim2.fromOffset(16,0),UDim2.new(1,-32,1,0)
		body.Position,body.Size=UDim2.fromOffset(12,headerHeight),UDim2.new(1,-24,1,-headerHeight)
		content.Position,content.Size=UDim2.fromOffset(16,12),UDim2.new(1,-32,1,-24)
		list.Padding=UDim.new(0,gap)
		hero.Size=UDim2.new(1,0,0,heroHeight)
		lead.Size=UDim2.new(1,0,0,if short then 26 else 38)
		amount.Position,amount.Size=UDim2.fromScale(0.5,0.5),UDim2.new(0.8,0,0,(heroHeight-60)/1.25)
		explanation.Position,explanation.Size=UDim2.new(0,0,1,if short then -26 else -38),UDim2.new(1,0,0,if short then 26 else 38)
		continue.Size,continue.TextSize=UDim2.new(1,0,0,buttonHeight),if short then 30 else 40
		local contentWidth=width-56
		fitSingleLine(title,width-32,if short then 34 else 45,20)
		fitSingleLine(lead,contentWidth,if short then 26 else 38,18)
		fitSingleLine(amount,contentWidth/1.25,math.min(92,(heroHeight-60)/1.25),12)
		fitSingleLine(explanation,contentWidth,if short then 24 else 35,16)
		local savedWidth=math.min(220,contentWidth-36)
		savedText.Size=UDim2.fromOffset(savedWidth,30)
		fitSingleLine(savedText,savedWidth,30,16)
		title.TextFace.TextOutline.Thickness=2
		lead.TextOutline.Thickness=1.3
		amount.TextOutline.Thickness=math.min(2.4,amount.TextSize*0.04)
		explanation.TextOutline.Thickness=1.5
		savedText.TextOutline.Thickness=1.2
		continue.Visual.Caption.TextFace.TextOutline.Thickness=1.5
	end
	table.insert(self.connections,gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	resize()
	ContextActionService:BindActionAtPriority("PetRollOfflineCashClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	-- Escape is also a Roblox core menu key; follow AppController's input path.
	table.insert(self.connections,UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode==Enum.KeyCode.Escape then close() end
	end))
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=continue end
end

function Controller:Destroy()
	self:Dismiss()
end

return Controller
