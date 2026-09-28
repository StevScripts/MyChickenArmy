--!strict
-- Compact play HUD; menus and economy actions remain owned by AppController.
local Theme=require(script.Parent.UITheme)
local EggFeedback=require(script.Parent.EggFeedback)
local GuiService=game:GetService("GuiService")
local Progression=require(game.ReplicatedStorage.PetRoll.Shared.Progression)
local A=Theme.Arcade
local Hud={}
Hud.__index=Hud

function Hud.new(app,shell)
	local self=setmetatable({app=app},Hud)
	local navigation=Theme.Frame(shell,"Navigation",UDim2.fromOffset(180,236))
	self.navigation=navigation
	navigation.AnchorPoint,navigation.Position,navigation.BackgroundTransparency=Vector2.new(0.5,1),UDim2.new(0.5,0,1,-18),1
	self.army=Theme.IconButton(navigation,"Army","My Army",Theme.Assets.ArmyHud or Theme.Assets.Army,function() app:TogglePage("Army") end)
	self.army.Size,self.army.TextSize=UDim2.fromScale(1,1),32
	self.armyIcon=self.army.Visual.Icon
	self.armyLabel=self.army.Visual.Label
	self.armyCount=Theme.Display(self.army.Visual,"ArmyCount","",20,Theme.PageColors.Army)
	self.armyCount.TextXAlignment=Enum.TextXAlignment.Center
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
	self.income.TextWrapped=false
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
	self.settings.Visible=not (app.panel and app.panel.Visible)
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
	local touch=game:GetService("UserInputService").TouchEnabled
	local compact=touch or width<1280 or height<600
	local shell=self.navigation.Parent
	local reference=math.min(width/1920,height/1080,1.25)
	local inset=GuiService.TopbarInset
	local statusTop=math.max(12,inset.Max.Y-shell.AbsolutePosition.Y+8)
	-- One standalone shortcut centered inside the device-safe area.
	local iconSize=if width<600 or height<500 then 96 else math.clamp(math.floor(180*reference+0.5),120,216)
	local labelHeight=if compact then 28 else 36
	local countHeight=if compact then 20 else 24
	local navWidth=math.max(120,iconSize)
	local navHeight=iconSize+labelHeight+countHeight
	local bottom=if compact then 12 else 18
	self.navigation.AnchorPoint=Vector2.new(0.5,1)
	self.navigation.Position=UDim2.new(0.5,0,1,-bottom)
	self.navigation.Size=UDim2.fromOffset(navWidth,navHeight)
	self.army.Size=UDim2.fromScale(1,1)
	self.army.TextSize=if compact then 26 else 34
	self.armyIcon.AnchorPoint=Vector2.new(0.5,0)
	self.armyIcon.Position,self.armyIcon.Size=UDim2.fromScale(0.5,0),UDim2.fromOffset(iconSize,iconSize)
	self.armyLabel.Position,self.armyLabel.Size=UDim2.fromOffset(0,iconSize-4),UDim2.fromOffset(navWidth,labelHeight)
	self.armyCount.Position,self.armyCount.Size=UDim2.fromOffset(0,iconSize+labelHeight-6),UDim2.fromOffset(navWidth,countHeight)
	self.armyCount.TextSize=if compact then 18 else 22
	for _,label in {self.status,self.objective} do
		label.Position=UDim2.new(0.5,0,0,statusTop)
		label.Size=UDim2.fromScale(math.min(570,width-24)/width,28/height)
		label.TextSize=if compact then 18 else 22
	end
	-- Anchor the PAIR to screen center; the old fixed utilityTop made it drift on PC.
	local utilityHeight=math.clamp(height*0.34,112,296)
	local utilityWidth=(utilityHeight-8)*136/264
	local center=height*0.5
	if touch then
		local minCenter=statusTop+32+utilityHeight/2
		local maxCenter=height-136-utilityHeight/2
		center=if minCenter<=maxCenter then math.clamp(center,minCenter,maxCenter) else (statusTop+28+height-116)/2
	end
	self.shortcuts.AnchorPoint=Vector2.new(0,0.5)
	self.shortcuts.Position=UDim2.fromScale(0.012,center/height)
	self.shortcuts.Size=UDim2.fromScale(utilityWidth/width,utilityHeight/height)
	for i,page in {"Shop","Index"} do
		local button=self.shortcuts:FindFirstChild(page)
		button.Size=UDim2.fromScale(1,(utilityHeight-8)/(2*utilityHeight))
		button.Position=UDim2.fromScale(0,(i-1)*(0.5+4/utilityHeight))
		button.TextSize=math.clamp(utilityWidth*0.23,18,32)
	end
	self.save.Position,self.save.Size=UDim2.fromScale(0.988,statusTop/height),UDim2.fromScale(math.min(200,width*0.4)/width,28/height)
	local small=width<850
	local lowerSides=touch or width<600
	local moneyY=if lowerSides then math.min(0.73,1-124/height) else 0.925
	self.cashIcon.AnchorPoint=Vector2.new(0,0.5)
	self.cashIcon.Position,self.cashIcon.Size=UDim2.fromScale(0.012,moneyY),UDim2.fromScale((if small then 48 else 88)/width,(if small then 46 else 80)/height)
	self.money.AnchorPoint=Vector2.new(0,0.5)
	self.money.Position,self.money.Size=UDim2.fromScale(0.012+(if small then 52 else 94)/width,moneyY),UDim2.fromScale(math.min(265,width*0.46)/width,54/height)
	self.money.TextSize=if small then 28 else 46
	self.eggLineCompact=width*0.45<420 or (touch and height<500)
	self.eggLineWidth=if touch and height<500 then 150 else width*0.45
	local eggHeight=if self.eggLineCompact then 44 else 24
	self.income.TextSize=if self.eggLineCompact then 18 else 20
	self.income.Position,self.income.Size=UDim2.fromScale(0.012,moneyY+28/height),UDim2.fromScale(0.45,eggHeight/height)
	if touch and height<500 then
		self.money.Size=UDim2.fromScale(144/width,54/height)
		self.income.Position,self.income.Size=UDim2.fromScale(218/width,moneyY-10/height),UDim2.fromScale(150/width,eggHeight/height)
	end
	self:UpdateEggLine(self.app.state and self.app.state.eggs or {})
	self.territory.Position,self.territory.Size=UDim2.fromScale(0.012,moneyY-48/height),UDim2.fromScale(0.48,24/height)
	self.conquered.Position,self.flock.Position=UDim2.fromScale(0.988,if lowerSides then 0.76 else 0.95),UDim2.fromScale(0.988,if lowerSides then 0.76+26/height else 0.98)
	self.conquered.Size,self.flock.Size=UDim2.fromScale(0.48,28/height),UDim2.fromScale(0.48,28/height)
	self.conquered.TextSize,self.flock.TextSize=if small then 18 else 27,if small then 18 else 25
end

function Hud:UpdateEggLine(eggs)
	if eggs.requiresDeposit then
		local count=eggs.carriedCount or 0
		local width=self.eggLineWidth or 290
		local budget=if self.eggLineCompact then width else (width-20)/2
		self.income.Text=EggFeedback.Fit(count,"Bag: ",if count==1 then " egg" else " eggs",budget,self.income.TextSize,false)
			..(if self.eggLineCompact then "\n" else " · ")
			..EggFeedback.Fit(eggs.carriedValue or 0,"Worth ","",budget,self.income.TextSize,true)
	else self.income.Text="Yard eggs: $"..Theme.Money(eggs.value or 0) end
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
	self:UpdateEggLine(state.eggs or {})
	self.flock.Text="Chickens "..count.."/"..limit
	local atHome=state.armyState=="Home"
	self.armyCount.Text=(if atHome then selected else deployed).."/"..capacity
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
end

return Hud
