--!strict
-- October 20 overhaul Auto Roll menu and hit alert (S12; docs/team/AUTO_ROLL.md).
-- Stevin had no HUD reference and approved the common Roblox RNG-game pattern (Sol's
-- RNG): a HUD toggle with a gear, a settings popup with a typed "1 in X" stop value,
-- and a big alert while Auto Roll holds a chicken on its podium. RollService decides
-- everything; this only presents state.autoRoll / state.goldRolls and sends
-- SetAutoRoll and RecruitHeld.
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Mutations=require(Shared.MutationCatalog)
local AutoRollRules=require(Shared.AutoRollRules)
local GoldRolls=require(Shared.GoldRolls)
local Theme=require(script.Parent.UITheme)
local MutationVFX=require(script.Parent.SpecialChickenVFX)
local Menu={}
Menu.__index=Menu

local GREEN=Theme.ReferenceColors.Army
local GOLD=Theme.ReferenceColors.Base
local BLUE=Theme.ReferenceColors.Upgrades
local OFF=Theme.ActionColors.disabled
local WHITE=Color3.new(1,1,1)
local MUTED=Color3.fromRGB(196,204,208)
local ERROR_RED=Color3.fromRGB(255,120,132)
-- Whole windows, header included (aspect = width / height).
local PANEL_SIZE,PANEL_ASPECT=UDim2.fromScale(0.46,0.74),1.3
local ALERT_SIZE,ALERT_ASPECT=UDim2.fromScale(0.42,0.24),2.6
local ALERT_TOP=0.1
-- The Auto Roll Gem Upgrade icon (S6, approved and uploaded October 20).
Menu.Icon="rbxassetid://83070773137079"
local REASONS={rebirth="Rebirth chicken",rarity="As rare as you asked for",upgrade="Makes your Army stronger"}
-- A just-sent change shows until the server echoes it, at most this long.
local PENDING_SECONDS=2
local ERROR_SECONDS=2.5

function Menu.new(app)
	return setmetatable({app=app,connections={},pending={},errors={},auto=nil::any,gold=nil::any,coins=0,
		recruitDraft=nil::number?,controls=nil::any,alert=nil::any,dismissed=nil::string?,checkAt=0},Menu)
end

local function label(parent: Instance,name: string,text: string,size: number,color: Color3?,align: Enum.TextXAlignment?)
	local item=Theme.Label(parent,name,text,size,color)
	item.TextScaled,item.TextXAlignment=true,align or Enum.TextXAlignment.Left
	return item
end

local function place(item,x,y,w,h)
	item.Position,item.Size=UDim2.fromScale(x,y),UDim2.fromScale(w,h)
end

-- The value to show for a setting: a change just sent, until the state echoes it.
function Menu:Value(key: string): any
	local auto=self.auto or {}
	local pending=self.pending[key]
	if pending then
		if os.clock()<pending.untilAt and auto[key]~=pending.value then return pending.value end
		self.pending[key]=nil
	end
	return auto[key]
end

function Menu:Send(changes: {[string]: any})
	for key,value in changes do
		self.pending[key]={value=if key=="recruitAt" and value==false then nil else value,untilAt=os.clock()+PENDING_SECONDS}
	end
	self.app:Request("SetAutoRoll",changes)
	self:Refresh()
end

function Menu:ShowError(row: string, text: string)
	self.errors[row]={text=text,untilAt=os.clock()+ERROR_SECONDS}
	self:Refresh()
	task.delay(ERROR_SECONDS+0.05,function() if self.gui then self:Refresh() end end)
end

-- state.autoRoll and state.goldRolls arrive with every snapshot.
function Menu:Render(state, _result)
	local auto=state and state.autoRoll
	self.auto=if type(auto)=="table" then auto else nil
	self.gold=state and state.goldRolls
	self.coins=(state and state.coins) or 0
	if self.gui and not self.closing then
		if not (self.auto and self.auto.unlocked) then self:Dismiss(true) else self:Refresh() end
	end
	self:UpdateAlert()
	if not self.watch and self.app.other and not self.app.editPreview then
		-- Menus close without a snapshot; re-check the alert a few times a second.
		self.watch=RunService.Heartbeat:Connect(function()
			local now=os.clock()
			if now<self.checkAt then return end
			self.checkAt=now+0.25
			self:UpdateAlert()
		end)
	end
end

-- Settings popup ---------------------------------------------------------------

function Menu:Dismiss(immediate: boolean?)
	local gui,panel=self.gui,self.panel
	if not gui or (self.closing and not immediate) then return end
	self.closing=true
	ContextActionService:UnbindAction("PetRollAutoRollClose")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject=if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	self.app:SetMenuBlur("autoRoll",false)
	local function finish()
		if self.gui~=gui then return end
		self.gui,self.panel,self.controls,self.closing=nil,nil,nil,false
		gui:Destroy()
		self:UpdateAlert()
	end
	if immediate then finish();return end
	Theme.Motion:Tween(panel,"autoroll-size",{Size=UDim2.fromScale(PANEL_SIZE.X.Scale*0.97,PANEL_SIZE.Y.Scale*0.97)},0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	Theme.Motion:Tween(panel,"autoroll-fade",{GroupTransparency=1},0.16,nil,nil,finish)
end

function Menu:Toggle(parent,name,callback)
	return Theme.Button(parent,name,"OFF",function()
		self.app.audio:Play("Click")
		callback()
	end,OFF)
end

-- [-] 1 in [ 20,000 ] [+]. The -/+ step through Config.AutoRoll.Presets; typing any
-- whole number from 2 to 10,000,000 works too.
function Menu:Stepper(parent,name,row,onStep,onTyped)
	local box=Theme.Container(parent,name)
	local minus=Theme.Button(box,"Lower","-",function() self.app.audio:Play("Click");onStep(-1) end,BLUE)
	place(minus,0,0,0.17,1);Theme.Aspect(minus,1)
	local prefix=label(box,"Prefix","1 in",22,WHITE,Enum.TextXAlignment.Right)
	place(prefix,0.18,0.18,0.16,0.64)
	local input=Instance.new("TextBox")
	input.Name,input.Text,input.PlaceholderText,input.ClearTextOnFocus="Value","","20,000",false
	input.Font,input.TextScaled,input.TextColor3=Theme.Font,true,WHITE
	input.BackgroundColor3,input.BackgroundTransparency,input.BorderSizePixel=Color3.fromRGB(8,10,12),0.28,0
	place(input,0.36,0.05,0.45,0.9)
	Theme.Stroke(input,Theme.Arcade.border,2)
	input.Parent=box
	local plus=Theme.Button(box,"Higher","+",function() self.app.audio:Play("Click");onStep(1) end,BLUE)
	plus.AnchorPoint=Vector2.new(1,0)
	place(plus,1,0,0.17,1);Theme.Aspect(plus,1)
	input.FocusLost:Connect(function()
		local digits=string.gsub(input.Text,"[^%d]","")
		local typed=tonumber(digits)
		if not typed or typed<AutoRollRules.Min or typed>AutoRollRules.Max then
			self:ShowError(row,"Enter a number from "..AutoRollRules.Min.." to "..string.sub(AutoRollRules.Text(AutoRollRules.Max),6))
			return
		end
		onTyped(AutoRollRules.Clean(typed) or typed)
	end)
	return box,input
end

function Menu:Build(main)
	local controls={}
	local function row(name,y,h)
		local frame=Theme.Container(main,name)
		place(frame,0.05,y,0.9,h)
		return frame
	end
	-- Auto Roll on/off.
	local power=row("Power",0.035,0.13)
	place(label(power,"Title","Auto Roll",30,WHITE),0,0,0.6,0.58)
	place(label(power,"Hint","Rolls your podiums for you, from anywhere",18,MUTED),0,0.58,0.72,0.4)
	controls.power=self:Toggle(power,"Toggle",function() self:Send({enabled=not self:Value("enabled")}) end)
	controls.power.AnchorPoint=Vector2.new(1,0.5)
	place(controls.power,1,0.5,0.24,0.85);Theme.Aspect(controls.power,2.6)
	-- Stop at 1 in X.
	local stop=row("StopAt",0.2,0.2)
	place(label(stop,"Title","Stop at",28,WHITE),0,0,0.38,0.5)
	controls.stopBox,controls.stopInput=self:Stepper(stop,"Stepper","stop",function(direction)
		self:Send({stopAt=AutoRollRules.Step(self:Value("stopAt") or AutoRollRules.Presets[3],direction)})
	end,function(value) self:Send({stopAt=value}) end)
	place(controls.stopBox,0.4,0,0.6,0.5)
	controls.stopHint=label(stop,"Hint","",18,MUTED)
	place(controls.stopHint,0,0.55,1,0.42)
	-- Auto-recruit at 1 in X when the Coins are there.
	local recruit=row("Recruit",0.43,0.2)
	place(label(recruit,"Title","Auto-recruit",28,WHITE),0,0,0.38,0.5)
	controls.recruitBox,controls.recruitInput=self:Stepper(recruit,"Stepper","recruit",function(direction)
		local value=AutoRollRules.Step(self:RecruitValue(),direction)
		self.recruitDraft=value
		if self:Value("recruitAt") then self:Send({recruitAt=value}) else self:Refresh() end
	end,function(value)
		self.recruitDraft=value
		if self:Value("recruitAt") then self:Send({recruitAt=value}) else self:Refresh() end
	end)
	place(controls.recruitBox,0.38,0,0.42,0.5)
	controls.recruit=self:Toggle(recruit,"Toggle",function()
		if self:Value("recruitAt") then self:Send({recruitAt=false}) else self:Send({recruitAt=self:RecruitValue()}) end
	end)
	controls.recruit.AnchorPoint=Vector2.new(1,0)
	place(controls.recruit,1,0,0.18,0.5);Theme.Aspect(controls.recruit,2.2)
	controls.recruitHint=label(recruit,"Hint","",18,MUTED)
	place(controls.recruitHint,0,0.55,1,0.42)
	-- Mutations and Army upgrades.
	local mutation=row("Mutations",0.66,0.1)
	place(label(mutation,"Title","Stop on mutations",24,WHITE),0,0.05,0.7,0.9)
	controls.mutation=self:Toggle(mutation,"Toggle",function() self:Send({mutationStop=not self:Value("mutationStop")}) end)
	controls.mutation.AnchorPoint=Vector2.new(1,0.5)
	place(controls.mutation,1,0.5,0.18,0.95);Theme.Aspect(controls.mutation,2.2)
	local upgrade=row("Upgrades",0.775,0.1)
	place(label(upgrade,"Title","Stop on Army upgrades",24,WHITE),0,0.05,0.7,0.9)
	controls.upgrade=self:Toggle(upgrade,"Toggle",function() self:Send({upgradeStop=not self:Value("upgradeStop")}) end)
	controls.upgrade.AnchorPoint=Vector2.new(1,0.5)
	place(controls.upgrade,1,0.5,0.18,0.95);Theme.Aspect(controls.upgrade,2.2)
	-- Rebirth chickens, and the Gold Machine count when owned.
	local note=row("Note",0.885,0.095)
	controls.note=label(note,"Text","",18,MUTED,Enum.TextXAlignment.Center)
	place(controls.note,0,0,1,1)
	self.controls=controls
end

-- The recruit value shown while auto-recruit is off: the last one picked.
function Menu:RecruitValue(): number
	return self:Value("recruitAt") or self.recruitDraft or AutoRollRules.Presets[3]
end

local function setToggle(button,on: boolean)
	button.Text=if on then "ON" else "OFF"
	local color=if on then GREEN else OFF
	if button.BackgroundColor3~=color then button.BackgroundColor3=color end
end

local function setInput(input,value: number)
	if input:IsFocused() then return end
	input.Text=string.sub(AutoRollRules.Text(value),6)
end

function Menu:Refresh()
	local controls=self.controls
	if not controls or not self.auto then return end
	local now=os.clock()
	setToggle(controls.power,self:Value("enabled")==true)
	local stopAt=self:Value("stopAt") or AutoRollRules.Presets[3]
	setInput(controls.stopInput,stopAt)
	local stopError=self.errors.stop
	controls.stopHint.Text=if stopError and now<stopError.untilAt then stopError.text else AutoRollRules.Describe(stopAt)
	controls.stopHint.TextColor3=if stopError and now<stopError.untilAt then ERROR_RED else MUTED
	local recruitOn=self:Value("recruitAt")~=nil
	setToggle(controls.recruit,recruitOn)
	setInput(controls.recruitInput,self:RecruitValue())
	local recruitError=self.errors.recruit
	controls.recruitHint.Text=if recruitError and now<recruitError.untilAt then recruitError.text
		elseif recruitOn then AutoRollRules.Describe(self:RecruitValue(),"Recruits").." when you have the Coins"
		else "Off: Auto Roll never spends your Coins"
	controls.recruitHint.TextColor3=if recruitError and now<recruitError.untilAt then ERROR_RED else MUTED
	setToggle(controls.mutation,self:Value("mutationStop")~=false)
	setToggle(controls.upgrade,self:Value("upgradeStop")~=false)
	local gold=self.gold
	local line="Rebirth chickens always stop Auto Roll."
	if type(gold)=="table" and gold.kind then
		line..="  "..gold.kind.." Machine: "..(if gold.ready then "next roll" else gold.left.." rolls left").." · "..gold.luck.."x Luck"
	end
	controls.note.Text=line
end

function Menu:Open()
	local auto=self.auto
	if not auto or not auto.unlocked then return end
	if self.gui and not self.closing then return end
	self:Dismiss(true)
	local app=self.app
	-- Acquire the blur before closing other menus so their exit cannot clear it.
	app:SetMenuBlur("autoRoll",true)
	app:CloseOtherMenus("autoRoll")
	self.previousSelection=GuiService.SelectedObject
	local gui=Theme.InsetContainer(app.other,"AutoRollMenu",Enum.ScreenInsets.CoreUISafeInsets)
	gui.ZIndex=30
	self.gui,self.closing=gui,false
	self:HideAlert()
	local frames=Theme.Container(gui,"FRAMES")
	local backdrop=Theme.Frame(Theme.InsetContainer(frames,"BackdropLayer",Enum.ScreenInsets.None),"Backdrop",UDim2.fromScale(1,1))
	backdrop.BackgroundTransparency,backdrop.Active=1,true
	local panel=Instance.new("CanvasGroup")
	panel.Name="AutoRoll"
	panel.BackgroundTransparency,panel.BorderSizePixel,panel.GroupTransparency=1,0,1
	panel.Active,panel.ZIndex=true,2
	panel.AnchorPoint,panel.Position,panel.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),PANEL_SIZE
	panel.Parent,self.panel=frames,panel
	Theme.Aspect(panel,PANEL_ASPECT)
	local header=Theme.Header(panel,"Header","Auto Roll",GREEN)
	header.PageIcon.Image,header.PageIcon.Visible=Menu.Icon,true
	Theme.LayoutHeader(header)
	local main=Theme.Container(panel,"Main")
	Theme.BelowHeader(header,main)
	Theme.Surface(main,Theme.PageSurfaces.Army)
	main.UIStroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	local function close()
		if not self.gui or self.closing then return end
		app.audio:Play("Click")
		self:Dismiss()
	end
	Theme.HeaderClose(header,close)
	self:Build(main)
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	self:Refresh()
	if not app.reducedMotion then panel.Size=UDim2.fromScale(PANEL_SIZE.X.Scale*0.94,PANEL_SIZE.Y.Scale*0.94) end
	Theme.Motion:Tween(panel,"autoroll-size",{Size=PANEL_SIZE},0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
	Theme.Motion:Tween(panel,"autoroll-fade",{GroupTransparency=0},0.22)
	ContextActionService:BindActionAtPriority("PetRollAutoRollClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	table.insert(self.connections,UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode==Enum.KeyCode.Escape then close() end
	end))
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=self.controls.power end
end

-- Hit alert ---------------------------------------------------------------------

-- The alert waits while a menu, popup, dialogue or film is up, then shows.
function Menu:AlertBlocked(): boolean
	local app=self.app
	if self.gui or app.dialogueActive then return true end
	if app.panel and app.panel.Visible then return true end
	if app.research and app.research.root and app.research.root.Visible then return true end
	for _,popup in {app.rebirthPanel,app.operationsPanel,app.dailyReward,app.freeGift,app.offlineCash} do
		if popup and popup.gui then return true end
	end
	if app.commerce and app.commerce.cratePresenting then return true end
	return app.intro~=nil and app.intro:Pending()
end

function Menu:BuildAlert()
	local app=self.app
	local layer=Theme.InsetContainer(app.other,"AutoRollAlert",Enum.ScreenInsets.CoreUISafeInsets)
	layer.ZIndex=26
	local card=Instance.new("CanvasGroup")
	card.Name,card.BackgroundColor3,card.BackgroundTransparency="Alert",Color3.new(0,0,0),0.1
	card.BorderSizePixel,card.Active,card.GroupTransparency,card.Visible=0,true,1,false
	card.AnchorPoint,card.Position,card.Size=Vector2.new(0.5,0),UDim2.fromScale(0.5,ALERT_TOP),ALERT_SIZE
	card.Parent=layer
	Theme.Aspect(card,ALERT_ASPECT)
	Theme.Stroke(card,Theme.Arcade.border,3)
	local rim=Theme.Container(card,"Rim")
	place(rim,0.008,0.03,0.984,0.94)
	local rimStroke=Theme.Stroke(rim,GOLD,2)
	local art=Theme.Container(card,"Art")
	place(art,0.02,0.06,0.24,0.88)
	local rays=Theme.Image(art,"Rays",Theme.Assets.Rays,UDim2.fromScale(1.3,1.3),UDim2.fromScale(-0.15,-0.15))
	rays.ImageTransparency,rays.ZIndex=0.35,2
	if not app.reducedMotion then
		Theme.Motion:Tween(rays,"spin",{Rotation=360},12,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1,false)
	end
	local portrait=Theme.Container(art,"Portrait")
	local kicker=label(card,"Kicker","Auto Roll stopped",22,GOLD)
	place(kicker,0.28,0.05,0.55,0.13)
	local headline=Theme.Display(card,"Headline","",48,WHITE)
	headline.TextXAlignment,headline.TextScaled,headline.TextWrapped=Enum.TextXAlignment.Left,true,false
	place(headline,0.28,0.16,0.6,0.29)
	local name=label(card,"ChickenName","",26,WHITE)
	place(name,0.28,0.45,0.43,0.14)
	local reason=label(card,"Reason","",20,MUTED)
	place(reason,0.28,0.59,0.42,0.12)
	local tag=Theme.Container(card,"MutationTag")
	place(tag,0.72,0.59,0.25,0.12)
	-- The price as the podium shows it: the gold coin beside the amount.
	local price=Theme.Container(card,"Price")
	place(price,0.72,0.45,0.25,0.14)
	local coin=Theme.CoinIcon(price,"CoinIcon",UDim2.fromScale(0.24,1))
	Theme.Aspect(coin,1)
	local amount=label(price,"Amount","",26,Theme.Colors.coins)
	place(amount,0.26,0,0.74,1)
	local recruit=Theme.ActionButton(card,"Recruit","Recruit",function()
		local held=self.alert and self.alert.held
		if not held then return end
		app.audio:Play("Click")
		app:Request("RecruitHeld",{offerId=held.offerId})
	end,GREEN)
	place(recruit,0.28,0.74,0.42,0.21)
	local skip=Theme.ActionButton(card,"Skip","Skip",function()
		if not (self.alert and self.alert.held) then return end
		app.audio:Play("Click")
		app:Request("SetAutoRoll",{skip=true})
		self:HideAlert()
	end,BLUE)
	place(skip,0.72,0.74,0.25,0.21)
	local close=Theme.Button(card,"Close","X",function()
		local held=self.alert and self.alert.held
		app.audio:Play("Click")
		-- Closing keeps the hold; the gold Auto Roll button brings the alert back.
		self.dismissed=held and held.offerId
		self:HideAlert()
	end,Theme.ActionColors.danger)
	close.AnchorPoint=Vector2.new(1,0)
	place(close,0.985,0.06,0.07,0.18);Theme.Aspect(close,1)
	Theme.ScaleText(card)
	self.alert={layer=layer,card=card,rim=rimStroke,rays=rays,portrait=portrait,headline=headline,name=name,
		reason=reason,tag=tag,amount=amount,recruit=recruit,skip=skip,held=nil::any,offerId=nil::string?,shown=false}
end

function Menu:FillAlert(held)
	local alert=self.alert
	local definition=Catalog[held.species]
	if not definition then return end
	alert.offerId=held.offerId
	local color=Theme.Rarities[definition.rarity] or WHITE
	local oneIn=Catalog.OneInText(held.species)
		or (if type(held.oneIn)=="number" then AutoRollRules.Text(math.floor(held.oneIn+0.5)) else nil)
	alert.headline.Text=if held.rebirthChicken then "Rebirth chicken!" elseif oneIn then oneIn.."!" else definition.rarity.."!"
	alert.headline.TextColor3=color
	alert.name.Text=definition.name.." · "..definition.rarity..(if (held.level or 1)>1 then " · Lv "..held.level else "")
	local mutation=if Mutations.IsValid(held.mutation) then held.mutation else nil
	alert.reason.Text=if held.reason=="mutation" and mutation then mutation.." mutation" else REASONS[held.reason] or ""
	alert.rim.Color,alert.rays.ImageColor3=color,color
	for _,child in alert.portrait:GetChildren() do child:Destroy() end
	local portrait=self.app:Preview(alert.portrait,{species=held.species,stars=1,level=held.level or 1,mutation=mutation},UDim2.fromScale(1,1))
	portrait.ZIndex=4
	for _,child in alert.tag:GetChildren() do child:Destroy() end
	if mutation then
		local badge=MutationVFX.Badge(alert.tag,mutation)
		if badge then badge.Size=UDim2.fromScale(1,1) end
	end
	Theme.ScaleText(alert.card)
end

function Menu:FillRecruit(held)
	local alert=self.alert
	local button=alert.recruit
	local amount=Theme.Money(held.price or 0)
	if alert.amount.Text~=amount then alert.amount.Text=amount end
	local short=math.max(0,(held.price or 0)-self.coins)
	local text=if held.storageFull then "Storage full"
		elseif short>0 then "Need "..Theme.CompactCoins(short)
		else "Recruit"
	if button.Text~=text then button.Text=text end
	local color=if held.canAfford and not held.storageFull then GREEN else OFF
	if button.BackgroundColor3~=color then button.BackgroundColor3=color end
end

-- The gold (holding) Auto Roll button brings a closed alert back.
function Menu:ShowAlert()
	self.dismissed=nil
	self:UpdateAlert()
end

function Menu:HideAlert()
	local alert=self.alert
	if not alert or not alert.shown then return end
	alert.shown=false
	local card=alert.card
	Theme.Motion:Tween(card,"alert-fade",{GroupTransparency=1},0.14,nil,nil,function()
		if not alert.shown then card.Visible=false end
	end)
end

function Menu:UpdateAlert()
	local auto=self.auto
	local held=if auto and auto.enabled and auto.unlocked then auto.held else nil
	if type(held)~="table" or held.offerId==self.dismissed or self:AlertBlocked() then
		if self.alert then self.alert.held=nil end
		self:HideAlert()
		return
	end
	if not self.alert then self:BuildAlert() end
	local alert=self.alert
	alert.held=held
	local fresh=alert.offerId~=held.offerId
	if fresh then self:FillAlert(held) end
	self:FillRecruit(held)
	if alert.shown then return end
	alert.shown=true
	local card=alert.card
	card.Visible=true
	if fresh then self.app.audio:Play("RollRare",1.1,{volume=0.45,voiceKey="AutoRollAlert",cooldown=0.5}) end
	if self.app.reducedMotion then
		card.GroupTransparency,card.Position=0,UDim2.fromScale(0.5,ALERT_TOP)
		return
	end
	card.Position=UDim2.fromScale(0.5,ALERT_TOP-0.04)
	Theme.Motion:Tween(card,"alert-fade",{GroupTransparency=0},0.2)
	Theme.Motion:Tween(card,"position",{Position=UDim2.fromScale(0.5,ALERT_TOP)},0.32,Enum.EasingStyle.Back,Enum.EasingDirection.Out,function()
		Theme.Motion:PopScale(alert.headline,1.15,0.3)
	end)
end

function Menu:Destroy()
	self:Dismiss(true)
	if self.watch then self.watch:Disconnect();self.watch=nil end
	if self.alert then self.alert.layer:Destroy();self.alert=nil end
end

return Menu
