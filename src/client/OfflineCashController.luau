--!strict
-- Displays an already-saved server receipt; dismissal never grants currency.
-- October 16: the HUD holds this amount back until the receipt closes, then the
-- coins fly into the balance (HudController:ReleaseOfflineCash; display only).
-- October 21 reference parity (docs/team/REFERENCE_PARITY_20261021.md §1 t0, §2.7):
-- "Welcome Back!" 1:1 with the reference: a gold studded header with the gift icon
-- and the red X, a dark body, the "OFFLINE EARNINGS:" card with the coin pile over
-- rays and "+N Coins" in gold, and one green Claim! (the reference's blue "Claim x2"
-- is a Robux product we do not sell). Claiming shows the green "You earned N Coins!"
-- banner while the coins fly into the HUD.
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
local WHITE = Color3.new(1,1,1)
-- The gift box (assets/free-gift-20261016) heads the window, as in the reference.
Controller.Icon = "rbxassetid://85740083144452"
-- The reference window is 455 x 401 px, header included. MenuLayouts.OfflineEarnings
-- keeps its saved size and position; the window keeps the reference's shape.
local ASPECT = 455/401

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
	if self.claimButton then Theme.Motion:StopBreathe(self.claimButton.Visual);self.claimButton=nil end
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

-- Claim! (button) or the X / Escape (closing): the coins are already saved either
-- way, so both release them into the HUD and confirm with the green banner, like
-- the reference's "You earned 3,391,365 coins!". Only Claim! plays the Claim cue.
function Controller:Claim(button: boolean)
	if not self.gui or self.closing then return end
	local app=self.app
	if button then app:Cue("Claim","UIPurchase",nil,{voiceKey="OfflineClaim",cooldown=0.3})
	else app:Cue("MenuClose","Click",nil,{voiceKey="MenuClose",cooldown=0.2}) end
	local amount=self.amount or 0
	self:Dismiss()
	if amount>0 then app:Notify("You earned "..Theme.Coins(amount).."!",true) end
end

local function label(parent,name,value,size,color)
	local item=Theme.Label(parent,name,value,size,color)
	item.TextXAlignment,item.TextScaled=Enum.TextXAlignment.Center,true
	return item
end

function Controller:Receive(state)
	local reward=state.offlineCash
	if not reward or reward.amount<=0 or reward.id==self.seen then return end
	self:Dismiss(true)
	self.seen,self.receiptId,self.amount=reward.id,reward.id,reward.amount
	local app=self.app
	-- Acquire before closing the main panel so its exit cannot clear our blur.
	app:SetMenuBlur("offline",true)
	app:ClosePanel()
	self.previousSelection=GuiService.SelectedObject
	local gui=if app.editPreview then Theme.Container(app.other,"OfflineEarnings")
		else Theme.InsetContainer(app.other,"OfflineEarnings",Enum.ScreenInsets.CoreUISafeInsets)
	gui.ZIndex=30
	self.gui,self.closing=gui,false
	local frames=Theme.Container(gui,"FRAMES")
	-- The tap blocker covers the full device screen, past phone notches.
	local backdropParent=if app.editPreview then frames
		else Theme.InsetContainer(frames,"BackdropLayer",Enum.ScreenInsets.None)
	local backdrop=Theme.Frame(backdropParent,"Backdrop",UDim2.fromScale(1,1))
	backdrop.BackgroundTransparency,backdrop.Active=1,true
	local panel=Instance.new("CanvasGroup")
	panel.Name="OfflineCash"
	panel.BackgroundTransparency,panel.BorderSizePixel,panel.GroupTransparency=1,0,1
	panel.Active,panel.ZIndex=true,2
	panel.AnchorPoint,panel.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
	panel.Parent,self.panel=frames,panel
	MenuLayout.Apply(app.gui,"Offline",panel)
	Theme.Aspect(panel,ASPECT)
	if app.editPreview then
		panel.Size,panel.Position,panel.AnchorPoint=UDim2.fromScale(1,1),UDim2.fromScale(0.5,0.5),Vector2.new(0.5,0.5)
	end
	self.panelSize,self.panelPosition=panel.Size,panel.Position
	local header=Theme.Header(panel,"Header","Welcome Back!",GOLD)
	header.PageIcon.Image,header.PageIcon.Visible=Controller.Icon,true
	Theme.LayoutHeader(header)
	local main=Theme.Container(panel,"Main")
	Theme.BelowHeader(header,main)
	Theme.Surface(main,Theme.OverlayColors.Top)
	main.UIStroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	-- The earnings card (the reference's lighter inner box): title, coins, amount.
	local card=Theme.Frame(main,"Earnings",UDim2.fromScale(0.936,0.72),Color3.fromRGB(34,38,42))
	card.Position,card.BackgroundTransparency=UDim2.fromScale(0.032,0.05),0.3
	Theme.Stroke(card,Color3.new(0,0,0),2)
	local title=label(card,"Title","OFFLINE EARNINGS:",30,WHITE)
	title.Position,title.Size,title.ZIndex=UDim2.fromScale(0.06,0.04),UDim2.fromScale(0.88,0.15),6
	local art=Theme.Container(card,"Art")
	art.AnchorPoint,art.Position,art.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.55),UDim2.fromScale(0.5,0.62)
	Theme.Aspect(art,1)
	local rays=ShopArt.ProductRays(art,WHITE)
	rays.AnchorPoint,rays.Position,rays.Size,rays.ZIndex=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(1.75,1.75),3
	-- A slow endless turn of the rays (one plain repeating tween); reduced motion keeps them still.
	if not app.reducedMotion then
		Theme.Motion:Tween(rays,"spin",{Rotation=360},24,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1,false)
	end
	local icon=ShopArt.CashPile(art,1)
	icon.Name,icon.ZIndex="Icon",4
	-- "+3.4M Coins" in gold over the foot of the coins, as in the reference.
	local amount=label(card,"Amount","+"..Theme.CompactCoins(reward.amount),54,WHITE)
	amount.AnchorPoint,amount.Position,amount.Size,amount.ZIndex=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.84),UDim2.fromScale(0.92,0.21),6
	self.amountLabel=amount
	local gradient=Instance.new("UIGradient")
	gradient.Color,gradient.Rotation,gradient.Parent=Theme.ReferenceGradients.Base,90,amount
	-- One green Claim!, centred under the card.
	local actions=Theme.Container(main,"Actions")
	actions.AnchorPoint,actions.Position,actions.Size=Vector2.new(0.5,1),UDim2.fromScale(0.5,0.965),UDim2.fromScale(0.46,0.16)
	Theme.Aspect(actions,3.8)
	local claim=Theme.ActionButton(actions,"Claim","Claim!",function() self:Claim(true) end,GREEN)
	claim.Position,claim.Size=UDim2.fromScale(0,0),UDim2.fromScale(1,1)
	claim:SetAttribute("ClickSound",false) -- Claim plays its own cue.
	Theme.Studs(claim.Visual.Face,0.07,28,0)
	claim.Visual.Caption.Position,claim.Visual.Caption.Size=UDim2.fromScale(0.04,0.1),UDim2.fromScale(0.92,0.8)
	claim.Visual.Caption.TextScaled=true
	claim.Visual.Caption.TextShadow.Visible=false
	-- Phone hit areas (DESIGN.md §6): Claim! grows 2.2x, mostly upward over the card's
	-- foot; the X grows 4.4x down into the title row (nothing else there takes taps).
	Theme.PadHit(claim,1.05,2.2,0.5,0.75)
	local close=Theme.HeaderClose(header,function() self:Claim(false) end,4.4)
	close:SetAttribute("ClickSound",false)
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	local restingSize,restingPosition=self.panelSize,self.panelPosition
	if not app.reducedMotion then
		panel.Size=UDim2.fromScale(restingSize.X.Scale*0.94,restingSize.Y.Scale*0.94)
		panel.Position=UDim2.fromScale(restingPosition.X.Scale,restingPosition.Y.Scale+0.035)
	end
	-- One emphasis: the window pops in, the coins punch once it lands, and the amount
	-- rolls up to the saved receipt with a rising tick (reduced motion shows it at once).
	Theme.Motion:Tween(panel,"receipt-size",{Size=restingSize},0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out,function()
		Theme.Motion:Punch(icon,1.18,0.3)
	end)
	local total=math.max(1,reward.amount)
	local function money(value) return "+"..Theme.CompactCoins(math.floor(value)) end
	Theme.Motion:CountTo(amount,0,money)
	Theme.Motion:CountTo(amount,reward.amount,money,0.8,{tickGap=0.07,punch=1.1,tick=function(value)
		app:Cue("CountTick",nil,0.9+0.25*math.clamp(value/total,0,1),{voiceKey="CountTick",cooldown=0.06})
	end})
	app:Cue("MenuOpen","Pop",nil,{voiceKey="MenuOpen",cooldown=0.2})
	-- Claim! breathes until pressed (StopBreathe in Dismiss).
	self.claimButton=claim
	Theme.Motion:Breathe(claim.Visual,1.05,0.7)
	Theme.Motion:Tween(panel,"position",{Position=restingPosition},0.28)
	Theme.Motion:Tween(panel,"receipt-fade",{GroupTransparency=0},0.22)
	if app.editPreview then return end
	ContextActionService:BindActionAtPriority("PetRollOfflineCashClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then self:Claim(false) end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	table.insert(self.connections,UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode==Enum.KeyCode.Escape then self:Claim(false) end
	end))
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=claim end
end

function Controller:Destroy()
	self:Dismiss(true)
end

return Controller
