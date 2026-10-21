--!strict
-- Displays an already-saved server receipt; dismissal never grants currency.
-- October 16: the HUD holds this amount back until the receipt closes, then the
-- coins fly into the balance (HudController:ReleaseOfflineCash; display only).
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.UITheme)
local MenuLayout = require(script.Parent.MenuLayout)
local ShopArt = require(script.Parent.ShopPreviewArt)
local Controller = {}
Controller.__index = Controller
local GREEN = Theme.ReferenceColors.Army
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
	if self.continueButton then Theme.Motion:StopBreathe(self.continueButton.Visual);self.continueButton=nil end
	self.app:SetMenuBlur("offline",false)
	if self.app.hud and self.receiptId then
		local amount=self.amountLabel
		local origin=if amount and amount.Parent then amount.AbsolutePosition+amount.AbsoluteSize/2 else nil
		self.app.hud:ReleaseOfflineCash(self.receiptId,origin)
	end
	local function finish()
		if self.gui~=gui then return end
		self.gui,self.panel,self.closing=nil,nil,false
		gui:Destroy()
	end
	if immediate then finish();return end
	Theme.Motion:Tween(panel,"receipt-size",{Size=UDim2.fromScale(self.panelSize.X.Scale*0.97,self.panelSize.Y.Scale*0.97)},0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	Theme.Motion:Tween(panel,"position",{Position=UDim2.fromScale(self.panelPosition.X.Scale,self.panelPosition.Y.Scale+0.025)},0.16)
	Theme.Motion:Tween(panel,"receipt-fade",{GroupTransparency=1},0.16,nil,nil,finish)
end

function Controller:Receive(state)
	local reward=state.offlineCash
	if not reward or reward.amount<=0 or reward.id==self.seen then return end
	self:Dismiss(true)
	self.seen,self.receiptId=reward.id,reward.id
	-- Acquire before closing the main panel so its exit cannot clear our blur.
	self.app:SetMenuBlur("offline",true)
	self.app:ClosePanel()
	self.previousSelection=GuiService.SelectedObject
	local gui=if self.app.editPreview then Theme.Container(self.app.other,"OfflineEarnings")
		else Theme.InsetContainer(self.app.other,"OfflineEarnings",Enum.ScreenInsets.CoreUISafeInsets)
	gui.ZIndex=30
	self.gui,self.closing=gui,false
	local frames=Theme.Container(gui,"FRAMES")
	-- The tap blocker covers the full device screen, past phone notches.
	local backdropParent=if self.app.editPreview then frames
		else Theme.InsetContainer(frames,"BackdropLayer",Enum.ScreenInsets.None)
	local backdrop=Theme.Frame(backdropParent,"Backdrop",UDim2.fromScale(1,1))
	backdrop.BackgroundTransparency,backdrop.Active=1,true
	local panel=Instance.new("CanvasGroup")
	panel.Name="OfflineCash"
	panel.BackgroundTransparency,panel.BorderSizePixel,panel.GroupTransparency=1,0,1
	panel.Active,panel.ZIndex=true,2
	panel.AnchorPoint,panel.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
	panel.Parent,self.panel=frames,panel
	MenuLayout.Apply(self.app.gui,"Offline",panel)
	if self.app.editPreview then
		panel.Size,panel.Position,panel.AnchorPoint=UDim2.fromScale(1,1),UDim2.fromScale(0.5,0.5),Vector2.new(0.5,0.5)
	end
	self.panelSize,self.panelPosition=panel.Size,panel.Position
	local header,title=Theme.Header(panel,"Header","Offline Earnings",GREEN)
	local main=Theme.Container(panel,"Main")
	Theme.BelowHeader(header,main)
	Theme.Surface(main,Theme.PageSurfaces.Army)
	main.UIStroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	local function label(parent,name,value,size,color)
		local item=Theme.Label(parent,name,value,size,color)
		item.TextXAlignment,item.TextScaled=Enum.TextXAlignment.Center,true
		return item
	end
	local lead=label(main,"LeadIn","While offline you earned!",30)
	lead.Position,lead.Size=UDim2.fromScale(0.04,0),UDim2.fromScale(0.92,0.12068965286016464)
	local rewardView=Theme.Container(main,"Reward")
	rewardView.AnchorPoint,rewardView.Position,rewardView.Size=Vector2.new(0.5,0),UDim2.fromScale(0.5,0.13568965),UDim2.fromScale(0.370244562625885,0.6379310488700867)
	Theme.Aspect(rewardView,0.9747434854507446)
	local icon=ShopArt.CashPile(rewardView,1)
	icon.Name,icon.ZIndex="Icon",3
	icon.AnchorPoint,icon.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
	-- The coin pile above is the unit, so the amount is just "+12,345" (October 20).
	local amount=label(rewardView,"Amount","+"..Theme.Money(reward.amount),54,Color3.new(1,1,1))
	amount.AnchorPoint,amount.Position,amount.Size=Vector2.new(0.5,1),UDim2.fromScale(0.5,0.95),UDim2.fromScale(1,0.18918919563293457)
	amount.ZIndex=4
	self.amountLabel=amount
	local gradient=Instance.new("UIGradient")
	gradient.Color,gradient.Rotation,gradient.Parent=Theme.ReferenceGradients.Base,90,amount
	local saved=label(main,"Saved","Collect it to add it to your Coins!",24,GREEN)
	saved.Position,saved.Size=UDim2.fromScale(0.1,0.745),UDim2.fromScale(0.8,0.055)
	local function close()
		if not self.gui or self.closing then return end
		self.app.audio:Play("Click")
		self:Dismiss()
	end
	local actions=Theme.Container(main,"Actions")
	actions.AnchorPoint,actions.Position,actions.Size=Vector2.new(0.5,1),UDim2.fromScale(0.5,0.965),UDim2.fromScale(0.4,0.1551724076271057)
	Theme.Aspect(actions,4.329331874847412)
	Theme.HeaderClose(header,close)
	local continue=Theme.ActionButton(actions,"Continue","Collect",close,GREEN)
	continue.Position,continue.Size=UDim2.fromScale(0,0),UDim2.fromScale(1,1)
	Theme.Studs(continue.Visual.Face,0.07,28,0)
	continue.Visual.Caption.Position,continue.Visual.Caption.Size=UDim2.fromScale(0.04,0.1),UDim2.fromScale(0.92,0.8)
	continue.Visual.Caption.TextScaled=true
	continue.Visual.Caption.TextShadow.Visible=false
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	local restingSize,restingPosition=self.panelSize,self.panelPosition
	if not self.app.reducedMotion then
		panel.Size=UDim2.fromScale(restingSize.X.Scale*0.94,restingSize.Y.Scale*0.94)
		panel.Position=UDim2.fromScale(restingPosition.X.Scale,restingPosition.Y.Scale+0.035)
	end
	Theme.Motion:Tween(panel,"receipt-size",{Size=restingSize},0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out,function()
		Theme.Motion:Punch(icon,1.18,0.3)
		Theme.Motion:Burst(rewardView,UDim2.fromScale(0.5,0.45),GREEN)
	end)
	-- Display only: the receipt is already saved; the number rolls up to it with a
	-- rising tick (October 21). Reduced motion shows the amount at once.
	local function money(value) return "+"..Theme.Money(math.floor(value)) end
	local total=math.max(1,reward.amount)
	Theme.Motion:CountTo(amount,0,money)
	Theme.Motion:CountTo(amount,reward.amount,money,0.8,{tickGap=0.07,punch=1.1,tick=function(value)
		self.app:Cue("CountTick",nil,0.9+0.25*math.clamp(value/total,0,1),{voiceKey="CountTick",cooldown=0.06})
	end})
	self.app:Cue("MenuOpen","Pop")
	-- Collect breathes until pressed (StopBreathe in Dismiss).
	self.continueButton=continue
	Theme.Motion:Breathe(continue.Visual,1.05,0.7)
	Theme.Motion:Tween(panel,"position",{Position=restingPosition},0.28)
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
