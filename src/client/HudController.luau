--!strict
-- Compact play HUD; menus and economy actions remain owned by AppController.
local Theme=require(script.Parent.UITheme)
local GuiService=game:GetService("GuiService")
local Progression=require(game.ReplicatedStorage.PetRoll.Shared.Progression)
local A=Theme.Arcade
local Hud={}
Hud.__index=Hud

function Hud.new(app,shell)
	local self=setmetatable({app=app},Hud)
	local top=Theme.Frame(shell,"Navigation",UDim2.fromOffset(660,66))
	self.navigation=top
	top.AnchorPoint,top.Position,top.BackgroundTransparency=Vector2.new(0.5,0),UDim2.new(0.5,0,0,6),1
	local list=Instance.new("UIListLayout")
	list.FillDirection,list.Padding,list.SortOrder,list.Parent=Enum.FillDirection.Horizontal,UDim.new(0,12),Enum.SortOrder.LayoutOrder,top
	local base=Theme.ActionButton(top,"Base","Base",function() app:Request("GoBase") end,Theme.PageColors.Base)
	base.Size,base.LayoutOrder,base.TextSize=UDim2.new(1/3,-8,0,60),1,30
	self.army=Theme.ActionButton(top,"Army","My Army",function() app:TogglePage("Army") end,Theme.PageColors.Army)
	self.army.Size,self.army.LayoutOrder,self.army.TextSize=UDim2.new(1/3,-8,0,64),2,26
	local upgrades=Theme.ActionButton(top,"Upgrades","Upgrades",function() app:TogglePage("Upgrades") end,Theme.PageColors.Upgrades)
	upgrades.TextSize=30
	upgrades.Size,upgrades.LayoutOrder=UDim2.new(1/3,-8,0,60),3
	self.upgrades=upgrades
	self.status=Theme.Display(shell,"ArmyStatus","",21)
	self.status.AnchorPoint,self.status.Position,self.status.Size,self.status.TextXAlignment=Vector2.new(0.5,0),UDim2.new(0.5,0,0,86),UDim2.fromOffset(520,30),Enum.TextXAlignment.Center
	self.status.Visible=false
	self.objective=Theme.Display(shell,"OpeningObjective","",21,A.gold)
	self.objective.AnchorPoint,self.objective.Position,self.objective.Size,self.objective.TextXAlignment=Vector2.new(0.5,0),UDim2.new(0.5,0,0,86),UDim2.fromOffset(570,30),Enum.TextXAlignment.Center
	self.objective.Visible=false
	self.money=Theme.Display(shell,"Money","$0",46,A.gold)
	self.cashIcon=Theme.Image(shell,"CashIcon",Theme.Assets.Cash,UDim2.fromOffset(96,86),UDim2.new(0,14,1,-119))
	self.money.Position,self.money.Size=UDim2.new(0,108,1,-84),UDim2.fromOffset(265,54)
	self.income=Theme.Display(shell,"Income","",20)
	self.income.Position,self.income.Size=UDim2.new(0,23,1,-35),UDim2.fromOffset(290,22)
	self.income.Visible=false
	self.territory=Theme.Display(shell,"TerritoryIncome","",18,A.gold)
	self.territory.Position,self.territory.Size,self.territory.Visible=UDim2.new(0,108,1,-111),UDim2.fromOffset(360,22),false
	self.conquered=Theme.Display(shell,"Conquered","Conquered 0/"..#Progression.Camps(1),27,A.gold)
	self.conquered.AnchorPoint,self.conquered.Position,self.conquered.Size,self.conquered.TextXAlignment=Vector2.new(1,1),UDim2.new(1,-20,1,-46),UDim2.fromOffset(270,28),Enum.TextXAlignment.Right
	self.flock=Theme.Display(shell,"Flock","Chickens 0/40",25,A.gold)
	self.flock.AnchorPoint,self.flock.Position,self.flock.Size,self.flock.TextXAlignment=Vector2.new(1,1),UDim2.new(1,-20,1,-17),UDim2.fromOffset(270,28),Enum.TextXAlignment.Right
	self:BuildSettingsTopbar()
	local shortcuts=Theme.Frame(shell,"CollectionNavigation",UDim2.fromOffset(144,284))
	shortcuts.BackgroundTransparency=1
	shortcuts.AnchorPoint,shortcuts.Position=Vector2.new(0,0.5),UDim2.new(0,16,0.48,0)
	self.shortcuts=shortcuts
	for i,page in {"Shop","Index"} do
		local button=Theme.IconButton(shortcuts,page,page,Theme.Assets[page],function() app:TogglePage(page) end)
		button.Position=UDim2.fromOffset(0,(i-1)*152)
	end
	self.save=Theme.Display(shell,"SaveStatus","",12)
	self.save.AnchorPoint,self.save.Position,self.save.Size,self.save.TextXAlignment=Vector2.new(1,0),UDim2.new(1,-18,0,52),UDim2.fromOffset(165,30),Enum.TextXAlignment.Right
	return self
end

function Hud:BuildSettingsTopbar()
	local app=self.app
	local gui=Instance.new("ScreenGui")
	gui.Name,gui.ResetOnSpawn,gui.DisplayOrder="PetRollTopbar",false,app.gui.DisplayOrder+1
	gui.ScreenInsets=Enum.ScreenInsets.TopbarSafeInsets
	gui.SafeAreaCompatibility=Enum.SafeAreaCompatibility.None
	gui.ClipToDeviceSafeArea=false
	gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
	gui.Parent=app.gui.Parent
	local button=Instance.new("TextButton")
	button.Name,button.Text,button.AutoButtonColor="Settings","",false
	button.Size,button.AnchorPoint,button.Position=UDim2.fromOffset(44,44),Vector2.new(1,0.5),UDim2.new(1,-8,0.5,0)
	button.BackgroundColor3,button.BackgroundTransparency,button.BorderSizePixel=Color3.fromRGB(18,19,22),0.1,0
	button.Parent=gui
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=button
	local icon=Instance.new("ImageLabel")
	icon.Name,icon.BackgroundTransparency="Gear",1
	icon.Image="rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab@2x.png"
	icon.AnchorPoint,icon.Position,icon.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromOffset(28,28)
	icon.Parent=button
	local caption=Instance.new("TextLabel")
	caption.Name,caption.Text,caption.Font,caption.TextSize="Caption","Settings",Theme.Font,16
	caption.AnchorPoint,caption.Position,caption.Size=Vector2.new(1,0),UDim2.new(1,0,1,8),UDim2.fromOffset(84,28)
	caption.BackgroundColor3,caption.BackgroundTransparency=Color3.fromRGB(18,19,22),0.06
	caption.TextColor3,caption.BorderSizePixel,caption.Visible=Color3.new(1,1,1),0,false
	caption.Parent=button
	local captionCorner=Instance.new("UICorner");captionCorner.CornerRadius=UDim.new(0,8);captionCorner.Parent=caption
	self.settings,self.settingsIcon,self.settingsCaption,self.settingsGui=button,icon,caption,gui
	Theme.Motion:BindButton(button,button)
	local function hover(value) self.settingsHovered=value;self:UpdateSettingsTopbar() end
	button.MouseEnter:Connect(function() hover(true) end)
	button.MouseLeave:Connect(function() hover(false) end)
	button.SelectionGained:Connect(function() hover(true) end)
	button.SelectionLost:Connect(function() hover(false) end)
	button.Activated:Connect(function() app:TogglePage("Settings");self:UpdateSettingsTopbar() end)
	local function syncEnabled()
		gui.Enabled=app.gui.Enabled and not GuiService.MenuIsOpen
		if not gui.Enabled then hover(false) end
	end
	local menuConnection=GuiService:GetPropertyChangedSignal("MenuIsOpen"):Connect(syncEnabled)
	gui.Destroying:Connect(function() menuConnection:Disconnect() end)
	app.gui:GetPropertyChangedSignal("Enabled"):Connect(syncEnabled)
	app.gui.Destroying:Connect(function() gui:Destroy() end)
	syncEnabled()
end

function Hud:UpdateSettingsTopbar()
	local app=self.app
	local selected=app.panel and app.panel.Visible and not app.panelClosing and app.page=="Settings"
	local hot=self.settingsHovered==true
	self.settingsCaption.Visible=hot and self.settingsGui.Enabled
	if self.settingsSelected==selected and self.settingsHot==hot then return end
	self.settingsSelected,self.settingsHot=selected,hot
	Theme.Motion:Tween(self.settings,"topbarColor",{BackgroundColor3=if selected then Color3.fromRGB(239,241,245)
		elseif hot then Color3.fromRGB(48,50,55) else Color3.fromRGB(18,19,22)},0.12)
	Theme.Motion:Tween(self.settingsIcon,"topbarColor",{ImageColor3=if selected then Color3.fromRGB(28,30,34) else Color3.new(1,1,1)},0.12)
end

function Hud:Resize(width, height, scale)
	self.layoutWidth,self.layoutHeight,self.layoutScale=width,height,scale
	if not self.settingsPanelBound then
		self.settingsPanelBound=true
		self.app.panel:GetPropertyChangedSignal("Visible"):Connect(function() self:UpdateSettingsTopbar() end)
		self.app.panelTitle:GetPropertyChangedSignal("Text"):Connect(function() self:UpdateSettingsTopbar() end)
		local insetConnection=GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
			self:Resize(self.layoutWidth,self.layoutHeight,self.layoutScale)
		end)
		self.navigation.Destroying:Once(function() insetConnection:Disconnect() end)
	end
	self:UpdateSettingsTopbar()
	local screenWidth,screenHeight=width*scale,height*scale
	local touch=game:GetService("UserInputService").TouchEnabled
	local compact=touch or screenWidth<1280 or screenHeight<600
	local shellTop=self.navigation.Parent.AbsolutePosition.Y
	-- Cancel the menu canvas scale for controls, not for the menus themselves.
	local function controlScale(item,visualScale)
		local sizing=item:FindFirstChild("HudControlScale")
		if not sizing then
			sizing=Instance.new("UIScale")
			sizing.Name,sizing.Parent="HudControlScale",item
		end
		sizing.Scale=(visualScale or 1)/scale
	end
	-- Reference proportions at 1920x1080: 230x72, 400x94, 230x72; 32px gaps.
	local referenceScale=math.min(screenWidth/1920,screenHeight/1080,1.25)
	-- The ScreenGui ignores the core inset: position top controls from the shell edge.
	-- Subtracting its negative AbsolutePosition would add the topbar gap back again.
	local topPadding=6
	local top=topPadding
	local navigationMinX,navigationMaxX=12,screenWidth-12
	if compact then
		local inset=GuiService.TopbarInset
		local hasInset=inset.Width>0 and inset.Height>0
		local freeLeft=if hasInset then math.max(12,inset.Min.X+8) else 168
		-- The settings target is 44px wide, 8px from the safe right edge; retain a 12px gap.
		local freeRight=math.min(screenWidth-12,if hasInset then inset.Max.X-64 else screenWidth-64)
		if freeRight-freeLeft>=280 then
			navigationMinX,navigationMaxX=freeLeft,freeRight
			top=if hasInset then math.max(topPadding,inset.Min.Y+topPadding) else topPadding
		else
			-- Exceptional narrow/split-screen layouts cannot safely share the native top bar.
			top=if hasInset then inset.Max.Y+topPadding else 56
		end
	end
	local buttonHeight=math.max(64,math.floor(94*referenceScale+0.5))
	local sideHeight=math.max(52,math.floor(72*referenceScale+0.5))
	local toolbarGap=math.max(8,math.floor(32*referenceScale+0.5))
	local gap=if compact then 6 else 8
	local navigationWidth=math.min(math.max(math.floor(924*referenceScale+0.5),if compact then 520 else 660),navigationMaxX-navigationMinX)
	local contentWidth=navigationWidth-toolbarGap*2
	local armyFraction=if screenWidth<600 then 0.4 else 400/860
	local armyWidth=math.floor(contentWidth*armyFraction+0.5)
	local sideWidth=(contentWidth-armyWidth)/2
	local navigationLeft=math.clamp(math.floor((screenWidth-navigationWidth)/2),navigationMinX,navigationMaxX-navigationWidth)
	local navigationCenter=navigationLeft+navigationWidth/2
	controlScale(self.navigation,1)
	self.navigation.Size=UDim2.fromOffset(navigationWidth,buttonHeight)
	self.navigation.AnchorPoint=Vector2.new(0,0)
	self.navigation.Position=UDim2.fromOffset(navigationLeft/scale,top/scale)
	local list=self.navigation:FindFirstChildWhichIsA("UIListLayout")
	if list then
		list.Padding=UDim.new(0,toolbarGap)
		list.VerticalAlignment=Enum.VerticalAlignment.Center
	end
	for _,button in self.navigation:GetChildren() do
		if button:IsA("TextButton") then
			local isArmy=button.Name=="Army"
			button.Size=UDim2.fromOffset(if isArmy then armyWidth else sideWidth,if isArmy then buttonHeight else sideHeight)
			button.TextSize=if isArmy then math.clamp(math.floor(34*referenceScale+0.5),21,42)
				else math.min(math.max(22,math.floor(42*referenceScale+0.5)),math.floor(sideWidth/4.6))
		end
	end
	local statusTop=top+buttonHeight+6
	controlScale(self.status,1)
	self.status.Position=UDim2.fromOffset(navigationCenter/scale,statusTop/scale)
	self.status.Size=UDim2.fromOffset(math.min(520,screenWidth-24),28)
	self.status.TextSize=if compact then 20 else 22
	controlScale(self.objective,1)
	self.objective.Position=self.status.Position
	self.objective.Size=UDim2.fromOffset(math.min(570,screenWidth-24),28)
	self.objective.TextSize=if compact then 19 else 22
	-- Keep the two large utility targets together and above phone movement controls.
	local utilityTop=if screenWidth<600 then statusTop+94 else 64
	local utilityBottom=screenHeight-136
	local iconScale=math.clamp((utilityBottom-utilityTop-gap)/264,0.42,if compact then 0.9 else 1.1)
	local utilityHeight=264*iconScale+gap
	controlScale(self.shortcuts,iconScale)
	self.shortcuts.Size=UDim2.fromOffset(136,264+gap/iconScale)
	self.shortcuts.AnchorPoint=Vector2.new(0,0.5)
	self.shortcuts.Position=UDim2.new(0,12/scale,0,(utilityTop+utilityHeight/2-shellTop)/scale)
	for i,page in {"Shop","Index"} do
		local button=self.shortcuts:FindFirstChild(page)
		if button then
			button.Size=UDim2.fromOffset(136,132)
			button.Position=UDim2.fromOffset(0,(i-1)*(132+gap/iconScale))
		end
	end
	self.save.Position=UDim2.new(1,-18,0,(if compact then 64 else top+64)/scale)
	local narrow=screenWidth<850
	self.money.TextSize=if narrow then 32 else 46
	self.money.Size=UDim2.fromOffset(if narrow then 180 else 265,54)
	self.cashIcon.Size=UDim2.fromOffset(if narrow then 70 else 96,86)
	self.money.Position=UDim2.new(0,if narrow then 82 else 108,1,-84)
	self.territory.Position=UDim2.new(0,if narrow then 82 else 108,1,-111)
	self.conquered.TextSize=if narrow then 21 else 27
	self.flock.TextSize=if narrow then 20 else 25
	self.conquered.Size=UDim2.fromOffset(if narrow then 260 else 360,28)
	self.flock.Size=self.conquered.Size
end

function Hud:UpdateOpening(state)
	local guidance=self.app.base.OpeningGuidance(state)
	self.objective.Text=if guidance then guidance.text else ""
	self.objective.Visible=guidance~=nil and not self.app.panel.Visible
end

function Hud:UpdateTerritory(state)
	local site = state and state.incomeOutpost
	local owned = site and site.ownerId == state.userId
	self.territory.Visible = owned == true and not self.app.panel.Visible
	if not owned then self.territory.Text = "";return end
	local rate = math.max(0, math.floor(site.effectiveRate or 0))
	self.territory.Text = if site.contested then "Income paused · contested" else "Outpost +$" .. Theme.Money(rate) .. "/s"
	self.territory.TextColor3 = if site.contested then A.red else A.gold
	if not site.contested then
		if site.npcApproaching then self.territory.Text ..= " · raid approaching"
		elseif site.npcWarningEndsAt then
			local remaining = math.max(0, math.ceil(site.npcWarningEndsAt - workspace:GetServerTimeNow()))
			if remaining > 0 then self.territory.Text ..= " · raid in " .. remaining .. "s" end
		end
	end
end

function Hud:Update(state,count,limit,capacity,selected,deployed)
	self:UpdateOpening(state)
	self:UpdateTerritory(state)
	Theme.Motion:Count(self.money,state.coins,function(value) return "$"..Theme.Money(value) end)
	local eggs=state.eggs or {}
	self.income.Text=if eggs.processor and eggs.processor.enabled then "Eggs "..Theme.Money(eggs.carriedCount or 0)
		elseif eggs.requiresDeposit then "Eggs "..Theme.Money(eggs.carriedCount or 0).." · $"..Theme.Money(eggs.carriedValue or 0)
		else "Yard eggs: $"..Theme.Money(eggs.value or 0)
	self.flock.Text="Chickens "..count.."/"..limit
	local atHome=state.armyState=="Home"
	self.army.Text="My Army\n"..(if atHome then selected else deployed).."/"..capacity
	self.status.Visible=not atHome
	self.status.Text=if atHome then ""
		elseif state.armyState=="Returning" then "Returning home"
		elseif state.stationedAt then "Holding "..state.stationedAt
		elseif state.marchingTo then "Marching to "..state.marchingTo
		else "Army deployed"
	if state.armyState~="Returning" and (state.recoveringCount or 0)+(state.reinforcingCount or 0)>0 then
		self.status.Text=(state.recoveringCount or 0)+(state.reinforcingCount or 0).." reinforcing"
	end
	local explored=0
 for _,won in state.frontierWins or {} do if won then explored+=1 end end
 local outpostCount=#Progression.Outposts()
 self.conquered.Text="Route "..(state.routeCampsWon or 0).."/"..#Progression.Camps(1)..(if outpostCount>0 then " · Outposts "..explored.."/"..outpostCount else "")
	self.conquered.TextColor3=if (state.routeCampsWon or 0)>0 then A.green else A.gold
	self.save.Text=if state.saveStatus=="error" then "Save unavailable · Settings" elseif state.saveStatus=="loading" then "Loading…" else ""
	self.save.TextColor3=A.red
	if self.lastCount and (count~=self.lastCount or capacity~=self.lastCapacity) then Theme.Motion:Pop(self.army.Visual,1.1) end
	if self.lastConquered and (state.routeCampsWon or 0)>self.lastConquered then
		Theme.Motion:Pop(self.conquered,1.13)
		Theme.Motion:Pop(self.cashIcon,1.14)
		Theme.Motion:Burst(self.app.gui.Shell,UDim2.new(1,-155,1,-65),A.gold)
	end
	self.lastCount,self.lastCapacity,self.lastConquered=count,capacity,state.routeCampsWon or 0
	local slot=state.nextSlot
	local incomeUpgrade,luckUpgrade=state.incomeUpgrade,state.luckUpgrade
	local prices={if incomeUpgrade and incomeUpgrade.unlocked then incomeUpgrade.price else math.huge,
		if luckUpgrade and luckUpgrade.unlocked then luckUpgrade.price else math.huge,
		if slot and slot.unlocked then slot.price else math.huge}
	local affordable=false
	for _,price in prices do if state.coins>=price then affordable=true;break end end
	if affordable and self.lastAffordable==false then Theme.Motion:Pop(self.upgrades.Visual,1.09) end
	self.lastAffordable=affordable
end

return Hud
