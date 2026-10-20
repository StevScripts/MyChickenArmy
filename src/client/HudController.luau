--!strict
-- Compact play HUD; menus and economy actions remain owned by AppController.
local Theme=require(script.Parent.UITheme)
local GuiService=game:GetService("GuiService")
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local ResearchAssets=require(script.Parent.ResearchAssets)
local HillHud=require(script.Parent.HillHud)
local RebirthPanel=require(script.Parent.RebirthPanel)
local FreeGiftController=require(script.Parent.FreeGiftController)
local ShopCatalog=require(game.ReplicatedStorage.PetRoll.Shared.ShopCatalog)
local Progression=require(game.ReplicatedStorage.PetRoll.Shared.Progression)
local A=Theme.Arcade
local ARMY_HOME_SCALE=0.82
local Hud={}
Hud.__index=Hud


local function callArmyUnlocked(state)
	local research=state and state.research
	return research~=nil and research.effects~=nil and (research.effects.callArmy or 0)>=1
end

function Hud.new(app,shell)
	local self=setmetatable({app=app},Hud)
	local navigation=Theme.Frame(shell,"Navigation",UDim2.fromScale(0.31,0.255))
	self.navigation=navigation
	navigation.AnchorPoint,navigation.Position,navigation.BackgroundTransparency=Vector2.new(0.5,1),UDim2.fromScale(0.5,0.985),1
	self.army=Theme.IconButton(navigation,"Army","My Army",Theme.Assets.ArmyHud or Theme.Assets.Army,function() app:TogglePage("Army") end)
	local function command(action)
		app.audio:Play("Click")
		app:Request(action)
	end
	-- Hidden until the CallArmy research completes (no locked teaser on the HUD).
	self.callArmy=Theme.IconButton(navigation,"CallArmy","Call Army",Theme.Assets.CallArmy or "",function()
		if callArmyUnlocked(app.state) then app:Request("CallArmy") end
	end)
	self.callUnlocked=false
	self.myBase=Theme.IconButton(navigation,"MyBase","My Base",Theme.Assets.MyBase or "",function() command("GoBase") end)
	self.army.ZIndex=2
	self.commandsExpanded=false
	for _,button in {self.callArmy,self.myBase} do
		button.Visible,button.Interactable,button.Selectable=false,false,false
		button.Size=UDim2.fromScale(0,0)
	end
	self.army.Size,self.army.TextSize=UDim2.fromScale(1,1),32
	self.armyIcon=self.army.Visual.Icon
	self.armyLabel=self.army.Visual.Label
	self.armyCount=Theme.Display(self.army.Visual,"ArmyCount","",20,Theme.PageColors.Army)
	self.armyCount.TextXAlignment=Enum.TextXAlignment.Center
	self.armyCount.ZIndex=4
	-- October 20 (owner): no top army status line ("Marching to X", "Returning home"…).
	self.objective=Theme.Display(shell,"OpeningObjective","",21,A.gold)
	self.objective.AnchorPoint,self.objective.Position,self.objective.Size,self.objective.TextXAlignment=Vector2.new(0.5,0),UDim2.fromScale(0.5,0.035),UDim2.fromScale(0.45,0.04),Enum.TextXAlignment.Center
	self.objective.Visible=false
	local cash=Theme.Container(shell,"CashReadout")
	self.cashReadout=cash
	-- October 20: one row taller (was 0.14, aspect 3.2) for the Friend Boost line under
	-- the number. Rows below are rescaled so every item keeps its on-screen size.
	cash.AnchorPoint,cash.Position,cash.Size=Vector2.new(0,1),UDim2.fromScale(0.012,0.98),UDim2.fromScale(0.3,0.176)
	Theme.Aspect(cash,2.545)
	-- October 15 owner UI Lab tweak: larger coin number with a gradient face; October 20
	-- (gold Coins): the face is gold beside the gold coin, and the number has no "$".
	self.money=Theme.Display(cash,"Money","0",46,Color3.fromRGB(252,248,255))
	local moneyGradient=Instance.new("UIGradient")
	moneyGradient.Rotation=90
	moneyGradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,247,57)),
		ColorSequenceKeypoint.new(0.4744,Color3.fromRGB(255,214,48)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,153,0))})
	moneyGradient.Parent=self.money.TextFace
	self.cashIcon=Theme.Image(cash,"CashIcon",Theme.Assets.Coin,UDim2.fromScale(0.22,0.509),UDim2.fromScale(0.0021,0.0423))
	Theme.Aspect(self.cashIcon,1)
	self.money.Position,self.money.Size=UDim2.fromScale(0.24,0.0614),UDim2.fromScale(0.76,0.4477)
	-- Friend Boost row (FriendBoost.luau mounts into it); the yard Bag line stays last.
	self.friendBoostSlot=Theme.Container(cash,"FriendBoostSlot")
	self.friendBoostSlot.Position,self.friendBoostSlot.Size=UDim2.fromScale(0,0.515),UDim2.fromScale(1,0.2)
	self.income=Theme.Display(cash,"Income","",20)
	self.income.Position,self.income.Size=UDim2.fromScale(0,0.735),UDim2.fromScale(1,0.239)
	self.income.TextWrapped,self.income.Visible=false,false
	self.territory=Theme.Display(cash,"TerritoryIncome","",18,A.gold)
	self.territory.Position,self.territory.Size,self.territory.Visible=UDim2.fromScale(0,0),UDim2.fromScale(1,0.159),false
	-- Rebirth rank ("Rebirth 2") sits just above the money; hidden at rank 0.
	self.rank=Theme.Display(cash,"RebirthRank","",24,Theme.ReferenceColors.Army)
	self.rank.AnchorPoint,self.rank.Position,self.rank.Size=Vector2.new(0,1),UDim2.fromScale(0,0),UDim2.fromScale(0.7,0.207)
	self.rank.Visible=false
	local totals=Theme.Container(shell,"ArmyTotals")
	self.totals=totals
	totals.AnchorPoint,totals.Position,totals.Size=Vector2.new(1,1),UDim2.fromScale(0.988,0.98),UDim2.fromScale(0.3,0.09)
	Theme.Aspect(totals,4.2)
	self.conquered=Theme.Display(totals,"Conquered","Camps held 0/8",27,A.gold)
	self.conquered.Position,self.conquered.Size,self.conquered.TextXAlignment=UDim2.fromScale(0,0),UDim2.fromScale(1,0.45),Enum.TextXAlignment.Right
	self.flock=Theme.Display(totals,"Flock","Flock 0/40",25,A.gold)
	self.flock.Position,self.flock.Size,self.flock.TextXAlignment=UDim2.fromScale(0,0.55),UDim2.fromScale(1,0.45),Enum.TextXAlignment.Right
	-- Pops grow from the middle of the line, not its corner (same place at rest).
	Theme.Motion:Center(self.conquered);Theme.Motion:Center(self.flock)
	self.hill=HillHud.new(app,shell,cash)
	self:BuildSettingsTopbar()
	-- The list centers whatever is visible.
	-- Later October 15 owner request: a little smaller, centered on the left edge,
	-- order Shop / Upgrades / Index.
	local shortcuts=Theme.Frame(shell,"CollectionNavigation",UDim2.fromScale(0.096,0.53))
	shortcuts.BackgroundTransparency=1
	shortcuts.AnchorPoint,shortcuts.Position=Vector2.new(0,0.5),UDim2.fromScale(0.009,0.5)
	self.shortcuts=shortcuts
	local shortcutLayout=Instance.new("UIListLayout")
	shortcutLayout.SortOrder,shortcutLayout.Padding=Enum.SortOrder.LayoutOrder,UDim.new(0.0286,0)
	shortcutLayout.VerticalAlignment=Enum.VerticalAlignment.Center
	shortcutLayout.Parent=shortcuts
	for i,page in {"Shop","Upgrades","Index"} do
		local button=Theme.IconButton(shortcuts,page,page,if page=="Upgrades" then ResearchAssets.lab else Theme.Assets[page],function() app:TogglePage(page) end)
		button.LayoutOrder=i
	end
	-- October 16 owner request: Auto Roll is a plain text toggle on the right, like
	-- Mini War's Auto Sell / Auto Collect, just above the Camps/Flock totals. Shown
	-- once researched; green ON, red OFF, gold while a keeper waits on the podium.
	local autoRoll=Theme.Button(shell,"AutoRoll","Auto Roll",function()
		local auto=app.state and app.state.autoRoll
		if auto and auto.unlocked then app.audio:Play("Click");app:Request("SetAutoRoll",{enabled=not auto.enabled}) end
	end,A.red)
	autoRoll.AnchorPoint,autoRoll.Position,autoRoll.Size=Vector2.new(1,1),UDim2.fromScale(0.988,0.875),UDim2.fromScale(0.15,0.08)
	autoRoll.TextColor3,autoRoll.Visible=Color3.new(1,1,1),false
	Theme.Aspect(autoRoll,3.4);Theme.ScaleText(autoRoll)
	self.autoRoll=autoRoll
	-- Rebirth: its own icon at the middle of the right edge (October 14 owner
	-- request; the left column keeps Shop, Index and Upgrades).
	local rebirthCorner=Theme.Frame(shell,"RebirthCorner",UDim2.fromScale(0.082,0.16))
	rebirthCorner.BackgroundTransparency,rebirthCorner.AnchorPoint=1,Vector2.new(1,0.5)
	Theme.Aspect(rebirthCorner,136/132)
	self.rebirthCorner=rebirthCorner
	self.reenlist=Theme.IconButton(rebirthCorner,"Reenlist","Rebirth",Theme.Assets.Reenlist or Theme.Assets.ArmyHud,function()
		app.audio:Play("Click")
		if app.rebirthPanel then app.rebirthPanel:Open() end
	end)
	self.reenlist.Visible=false
	-- October 15 owner request: a red "!" notification badge on the icon's corner
	-- whenever a Rebirth is available (UpdateRebirth toggles it).
	local badge=Theme.Frame(self.reenlist.Visual,"RebirthReady",UDim2.fromScale(0.3,0.3),Color3.fromRGB(235,45,45))
	badge.AnchorPoint,badge.Position,badge.ZIndex,badge.Visible=Vector2.new(0.5,0.5),UDim2.fromScale(0.86,0.1),8,false
	Theme.Aspect(badge,1)
	Theme.Round(badge).CornerRadius=UDim.new(0.5,0)
	-- Round joins: a Miter stroke draws a square box around a circle.
	Theme.Stroke(badge,Color3.new(0,0,0),2).LineJoinMode=Enum.LineJoinMode.Round
	local mark=Theme.Label(badge,"Mark","!",28,Color3.new(1,1,1))
	mark.Size,mark.TextScaled,mark.ZIndex,mark.TextXAlignment=UDim2.fromScale(1,1),true,9,Enum.TextXAlignment.Center
	self.rebirthBadge=badge
	-- October 16 free gift: a gift icon above Rebirth until the free chicken is claimed.
	local giftCorner=Theme.Frame(shell,"FreeGiftCorner",UDim2.fromScale(0.082,0.16))
	giftCorner.BackgroundTransparency,giftCorner.AnchorPoint=1,Vector2.new(1,0.5)
	giftCorner.Position=UDim2.fromScale(0.988,0.31)
	Theme.Aspect(giftCorner,136/132)
	self.freeGiftCorner=giftCorner
	self.freeGift=Theme.IconButton(giftCorner,"FreeGift","Free Chicken!",FreeGiftController.Assets.Gift,function()
		app.audio:Play("Click")
		if app.freeGift then app.freeGift:Open() end
	end)
	self.freeGift.Size,self.freeGift.Visible=UDim2.fromScale(1,1),false
	-- Golden sunburst behind the chicken (centred on the icon), slowly spinning.
	local burst=Theme.Image(self.freeGift.Visual,"Sunburst",Theme.Assets.Rays,UDim2.fromScale(1.25,1.25),UDim2.fromScale(0.5,0.37))
	burst.AnchorPoint,burst.ZIndex=Vector2.new(0.5,0.5),2
	burst.ImageColor3,burst.ImageTransparency=Color3.fromRGB(255,184,0),0
	Theme.Aspect(burst,1)
	Theme.Motion:Tween(burst,"spin",{Rotation=360},10,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1,false)
	-- Golden caption with a shine sweeping across it on repeat.
	self.freeGift.TextColor3=Color3.new(1,1,1)
	local shine=Instance.new("UIGradient")
	shine.Name="GoldShine"
	shine.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,178,2)),
		ColorSequenceKeypoint.new(0.4,Color3.fromRGB(255,214,40)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(255,250,205)),
		ColorSequenceKeypoint.new(0.6,Color3.fromRGB(255,214,40)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,178,2))})
	shine.Rotation,shine.Offset=20,Vector2.new(-1,0)
	shine.Parent=self.freeGift.Visual.Label
	Theme.Motion:Tween(shine,"shine",{Offset=Vector2.new(1,0)},1.8,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1,false)
	self:BuildChickenOffer(shell)
	-- Below the top-centre line, clear of the Settings corner; errors also raise a toast.
	self.save=Theme.Display(shell,"SaveStatus","",21)
	self.save.AnchorPoint,self.save.Position,self.save.Size,self.save.TextXAlignment=Vector2.new(0.5,0),UDim2.fromScale(0.5,0.08),UDim2.fromScale(0.45,0.04),Enum.TextXAlignment.Center
	self:Layout()
	self:BindBasePresence()
	local inputConnection=UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function() self:ApplyInputLayout() end)
	navigation.Destroying:Once(function() inputConnection:Disconnect() end)
	return self
end

function Hud:BindBasePresence()
	local player=Players.LocalPlayer
	if not player then return end -- Edit-mode UI Lab previews have no player.
	local alive=true
	local presenceConnection
	local function reset()
		if presenceConnection then presenceConnection:Disconnect();presenceConnection=nil end
		self.outsideBase=false
		self:RefreshCommands(true)
	end
	local function bind(character)
		reset()
		local humanoid=character:WaitForChild("Humanoid",10)
		if not alive or character~=player.Character or not humanoid then return end
		local function update()
			-- Reuse the server's whole-base boundary, including its edge hysteresis.
			self.outsideBase=humanoid:GetAttribute("OutsideHomeBase")==true
			self:RefreshCommands(false)
		end
		presenceConnection=humanoid:GetAttributeChangedSignal("OutsideHomeBase"):Connect(update)
		update()
	end
	local added=player.CharacterAdded:Connect(bind)
	local removing=player.CharacterRemoving:Connect(reset)
	self.navigation.Destroying:Once(function()
		alive=false
		added:Disconnect();removing:Disconnect()
		if presenceConnection then presenceConnection:Disconnect() end
	end)
	if player.Character then task.spawn(bind,player.Character) end
end

-- Call Army / My Base show outside the base, and also inside it whenever the
-- army is away (at a camp, marching or following), so it can always be recalled.
function Hud:RefreshCommands(immediate)
	local expanded=self.outsideBase==true or self.armyAway==true
	if expanded==self.commandsExpanded and not immediate then return end
	self.commandsExpanded=expanded
	self:UpdateArmyCommands(immediate)
end

function Hud:UpdateArmyCommands(immediate)
	local expanded=self.commandsExpanded
	local seconds=if immediate then 0 else 0.32
	local armyFactor=if expanded then 1 else ARMY_HOME_SCALE
	Theme.Motion:Tween(self.army,"baseSize",{Size=UDim2.fromScale(0.38*armyFactor,armyFactor)},
		seconds,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut)
	for index,button in {self.callArmy,self.myBase} do
		local shown=expanded and (button~=self.callArmy or self.callUnlocked==true)
		button.Visible=true
		button.Interactable,button.Selectable=false,false
		if GuiService.SelectedObject==button then GuiService.SelectedObject=self.army end
		local x=if index==1 then 0.14 else 0.86
		Theme.Motion:Tween(button,"basePosition",{Position=UDim2.fromScale(if shown then x else 0.5,
			if shown then 0.66 else 0.52)},seconds,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut)
		Theme.Motion:Tween(button,"baseSize",{Size=UDim2.fromScale(if shown then 0.28 else 0,if shown then 0.7 else 0)},
			seconds,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut,function()
				button.Visible=shown
				button.Interactable,button.Selectable=shown,shown
			end)
	end
end

function Hud:BuildSettingsTopbar()
	local app=self.app
	local gui=Theme.Container(app.hudLayer,"Topbar")
	gui.ZIndex=30
	local button=Instance.new("TextButton")
	button.Name,button.Text,button.AutoButtonColor="Settings","",false
	button.Size,button.AnchorPoint,button.Position=UDim2.fromScale(0.04,0.072),Vector2.new(1,0),UDim2.fromScale(0.994,0.012)
	button.BackgroundColor3,button.BackgroundTransparency,button.BorderSizePixel=Color3.fromRGB(18,19,22),0.1,0
	button.Parent=gui
	Theme.Aspect(button,1)
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=button
	local icon=Instance.new("ImageLabel")
	icon.Name,icon.BackgroundTransparency="Gear",1
	icon.Image="rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab@2x.png"
	icon.AnchorPoint,icon.Position,icon.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(0.64,0.64)
	icon.Parent=button
	local caption=Instance.new("TextLabel")
	caption.Name,caption.Text,caption.Font,caption.TextSize="Caption","Settings",Theme.Font,16
	caption.AnchorPoint,caption.Position,caption.Size=Vector2.new(1,0),UDim2.fromScale(1,1.18),UDim2.fromScale(1.9,0.64)
	caption.TextScaled=true
	caption.BackgroundColor3,caption.BackgroundTransparency=Color3.fromRGB(18,19,22),0.06
	caption.TextColor3,caption.BorderSizePixel,caption.Visible=Color3.new(1,1,1),0,false
	caption.Parent=button
	local captionCorner=Instance.new("UICorner");captionCorner.CornerRadius=UDim.new(0.03,0);captionCorner.Parent=caption
	self.settings,self.settingsIcon,self.settingsCaption,self.settingsGui=button,icon,caption,gui
	-- The button Size is rewritten by ApplyInputLayout; press the centred gear instead.
	Theme.Motion:BindButton(button,icon)
	local function hover(value) self.settingsHovered=value;self:UpdateSettingsTopbar() end
	button.MouseEnter:Connect(function() hover(true) end)
	button.MouseLeave:Connect(function() hover(false) end)
	button.SelectionGained:Connect(function() hover(true) end)
	button.SelectionLost:Connect(function() hover(false) end)
	button.Activated:Connect(function() app:TogglePage("Settings");self:UpdateSettingsTopbar() end)
	local function syncEnabled()
		gui.Visible=app.gui.Enabled and not GuiService.MenuIsOpen
		if not gui.Visible then hover(false) end
	end
	local menuConnection=GuiService:GetPropertyChangedSignal("MenuIsOpen"):Connect(syncEnabled)
	gui.Destroying:Connect(function() menuConnection:Disconnect() end)
	app.gui:GetPropertyChangedSignal("Enabled"):Connect(syncEnabled)
	syncEnabled()
end

function Hud:UpdateSettingsTopbar()
	local app=self.app
	local selected=app.panel and app.panel.Visible and not app.panelClosing and app.page=="Settings"
	self.settings.Visible=not (app.panel and app.panel.Visible)
	local hot=self.settingsHovered==true
	self.settingsCaption.Visible=hot and self.settingsGui.Visible
	if self.settingsSelected==selected and self.settingsHot==hot then return end
	self.settingsSelected,self.settingsHot=selected,hot
	Theme.Motion:Tween(self.settings,"topbarColor",{BackgroundColor3=if selected then Color3.fromRGB(239,241,245)
		elseif hot then Color3.fromRGB(48,50,55) else Color3.fromRGB(18,19,22)},0.12)
	Theme.Motion:Tween(self.settingsIcon,"topbarColor",{ImageColor3=if selected then Color3.fromRGB(28,30,34) else Color3.new(1,1,1)},0.12)
end

-- Like GUI.HUD: scale-only regions, native aspect constraints and scaled text.
-- The composition is authored once; viewport changes are handled by Roblox.
function Hud:Layout()
	Theme.Aspect(self.navigation,558/272)
	Theme.Aspect(self.shortcuts,136/420) -- Three slots: 3 x 0.314 + 2 x 0.0286 padding.
	self.army.AnchorPoint,self.army.Position=Vector2.new(0.5,1),UDim2.fromScale(0.5,1)
	for _,button in {self.callArmy,self.army,self.myBase} do
		local primary=button==self.army
		if not primary then button.AnchorPoint=Vector2.new(0.5,0.5) end
		local icon,label=button.Visual.Icon,button.Visual.Label
		icon.AnchorPoint=Vector2.new(0.5,0)
		icon.Position,icon.Size=UDim2.fromScale(0.5,0.03),UDim2.fromScale(1,if primary then 0.8 else 0.82)
		Theme.Aspect(icon,1)
		label.Position,label.Size=UDim2.fromScale(0,0.73),UDim2.fromScale(1,if primary then 0.13 else 0.2)
		label.TextScaled,label.ZIndex=true,4
	end
	self.armyCount.Position,self.armyCount.Size=UDim2.fromScale(0,0.86),UDim2.fromScale(1,0.135)
	-- October 15 owner request: labels sit closer to their icons (0.712 -> 0.64).
	for _,page in {"Shop","Index","Upgrades"} do
		local button=self.shortcuts:FindFirstChild(page)
		Theme.Aspect(button,136/132)
		button.Visual.Label.TextScaled=true
		button.Visual.Label.Position=UDim2.fromScale(0,0.64)
	end
	self:LayoutShortcuts()
	self.reenlist.Size=UDim2.fromScale(1,1)
	self.reenlist.Visual.Label.TextScaled=true
	self.reenlist.Visual.Label.Position=UDim2.fromScale(0,0.64)
	self.freeGift.Visual.Label.TextScaled=true
	self.freeGift.Visual.Label.Position=UDim2.fromScale(0,0.64)
	for _,label in {self.objective,self.money,self.income,self.territory,self.rank,self.conquered,self.flock,self.save,self.armyCount} do
		label.TextScaled=true
	end
	Theme.Aspect(self.objective,19)
	Theme.Aspect(self.save,19)
	Theme.ScaleText(self.navigation)
	Theme.ScaleText(self.shortcuts)
	Theme.ScaleText(self.rebirthCorner)
	Theme.ScaleText(self.freeGiftCorner)
	Theme.ScaleText(self.settings)
	-- Top status lines get the shared readable text floor (wide boxes, no overlap risk).
	for _,label in {self.objective,self.save} do Theme.ScaleText(label) end
	self:ApplyInputLayout()
	self:UpdateArmyCommands(true)
end

-- October 15 owner request: ONE HUD layout for every device (PC, phone, tablet,
-- gamepad). No touch-only positions; edit it once (UI Lab) and it applies everywhere.
-- settingsBottom: lowest screen Y scale the Settings button can reach (for neighbours).
function Hud:ApplyInputLayout()
	self.cashReadout.AnchorPoint,self.cashReadout.Position=Vector2.new(0,1),UDim2.fromScale(0.012,0.98)
	self:PlaceRebirth()
	self.settings.Size=UDim2.fromScale(0.04,0.072)
	self.settingsBottom=self.settings.Position.Y.Scale+self.settings.Size.Y.Scale
	-- The Hill chip rides just above the coin readout wherever it sits.
	if self.hill then self.hill:Place() end
end

-- Middle of the right edge; the totals keep the bottom-right corner (all devices).
function Hud:PlaceRebirth()
	self.rebirthCorner.Position=UDim2.fromScale(0.988,0.5)
	self.totals.Position=UDim2.fromScale(0.988,0.98)
end

function Hud:Resize(_width, _height, _scale)
	if not self.settingsPanelBound then
		self.settingsPanelBound=true
		self.app.panel:GetPropertyChangedSignal("Visible"):Connect(function() self:UpdateSettingsTopbar() end)
		self.app.panelTitle:GetPropertyChangedSignal("Text"):Connect(function() self:UpdateSettingsTopbar() end)
	end
	self:UpdateSettingsTopbar()
end

function Hud:UpdateEggLine(eggs)
	if eggs.requiresDeposit then
		local count=eggs.carriedCount or 0
		self.income.Text="Bag: "..Theme.Money(count)..(if count==1 then " egg" else " eggs")
			.." · Worth "..Theme.Coins(eggs.carriedValue or 0)
	else self.income.Text="Yard eggs: "..Theme.Coins(eggs.value or 0) end
end

function Hud:UpdateOpening(state)
	local guidance=self.app.base.OpeningGuidance(state)
	self.objective.Text=if guidance then guidance.text else ""
	self.objective.Visible=guidance~=nil and not self.app.panel.Visible and self.app.commander==nil
end

function Hud:UpdateTerritory(state)
	if self.hill then self.hill:Update(state) end
	local site = state and state.incomeOutpost
	local owned = site and site.ownerId == state.userId
	self.territory.Visible = owned == true and not self.app.panel.Visible
	if not owned then self.territory.Text = "";return end
	-- The Hill banner (HillHud) carries the holder's boost and clock instead.
	if state.hill and state.hill.enabled then self.territory.Visible = false;return end
	local rate = math.max(0, math.floor(site.effectiveRate or 0))
	self.territory.Text = if site.contested then "Income paused · contested" else "Outpost +" .. Theme.Coins(rate) .. "/s"
	self.territory.TextColor3 = if site.contested then A.red else A.gold
	if not site.contested then
		if site.npcApproaching then self.territory.Text ..= " · raid approaching"
		elseif site.npcWarningEndsAt then
			local remaining = math.max(0, math.ceil(site.npcWarningEndsAt - workspace:GetServerTimeNow()))
			if remaining > 0 then self.territory.Text ..= " · raid in " .. remaining .. "s" end
		end
	end
end

-- state.rebirth is missing on the first packets and is only a stub until the
-- server quote ships; every field is optional here.
function Hud:UpdateRebirth(state)
	local quote=state and state.rebirth
	if type(quote)~="table" then self.rank.Visible=false;self.reenlist.Visible=false;return end
	local rank=tonumber(quote.rank) or 0
	-- The Re-enlist icon appears once it matters: the King is beaten or a rank is earned.
	local showIcon=quote.enabled~=false and (rank>=1 or quote.kingCleared==true)
	if self.reenlist.Visible~=showIcon then
		self.reenlist.Visible=showIcon;self:PlaceRebirth()
		-- Grow in only when it newly unlocks this session, not on the first packet.
		if showIcon and self.lastShowIcon==false then Theme.Motion:PopScale(self.reenlist.Visual,0.6,0.3) end
	end
	self.lastShowIcon=showIcon
	Theme.Motion:Appear(self.rebirthBadge,showIcon and quote.eligible==true)
	-- UIScale breathing; BindButton's press tween on Visual.Size never cancels it.
	local pulse=showIcon and quote.eligible==true
	if pulse~=(self.reenlistPulse==true) then
		self.reenlistPulse=pulse
		if pulse then Theme.Motion:Breathe(self.reenlist.Visual,1.08,0.8) else Theme.Motion:StopBreathe(self.reenlist.Visual) end
	end
	self.rank.Text=RebirthPanel.Title(rank)
	-- The Hill countdown chip uses the same spot above the coin readout.
	self.rank.Visible=rank>=1 and not (self.hill and self.hill.waitingShown)
	if self.lastRank and rank>self.lastRank then Theme.Motion:PopScale(self.rank,1.15) end
	self.lastRank=rank
	if quote.eligible==true and quote.enabled~=false and not self.rebirthToastShown then
		self.rebirthToastShown=true
		local nextTitle=RebirthPanel.Title(rank+1)
		self.app:Notify("Rebirth ready: "..nextTitle.."!",true)
	end
end

-- Three slots: Shop, Upgrades, Index (Auto Roll moved to the right on October 16).
function Hud:LayoutShortcuts()
	local column=self.shortcuts
	column.Size=UDim2.fromScale(0.096,0.53)
	local aspect=column:FindFirstChildOfClass("UIAspectRatioConstraint")
	if aspect then aspect.AspectRatio=136/420 end
	local layout=column:FindFirstChildOfClass("UIListLayout")
	if layout then layout.Padding=UDim.new(0.0286,0) end
	for _,page in {"Shop","Index","Upgrades"} do
		column[page].Size=UDim2.fromScale(1,0.314)
	end
end

function Hud:UpdateAutoRoll(state)
	local auto=state.autoRoll
	local unlocked=auto~=nil and auto.unlocked==true
	-- Point at the new button once, when the research finishes in this session.
	if unlocked and self.autoRollUnlocked==false then self.app:Notify("Auto Roll unlocked! Use the Auto Roll button on the right to start rolling.",true) end
	if unlocked and self.autoRollUnlocked==false then Theme.Motion:PopScale(self.autoRoll.Visual,0.6,0.3) end
	self.autoRollUnlocked=unlocked
	self.autoRoll.Visible=unlocked
	if not unlocked then return end
	local color=if not auto.enabled then A.red elseif auto.holding then A.gold else A.green
	if self.autoRoll.BackgroundColor3~=color then self.autoRoll.BackgroundColor3=color end
end

-- Shown until the free chicken is claimed; breathes to invite a tap.
function Hud:UpdateFreeGift(state)
	local gift=state.freeGift
	local shown=type(gift)=="table" and gift.enabled==true and gift.claimed~=true
	if shown==(self.freeGiftShown==true) then return end
	self.freeGiftShown=shown
	self.freeGift.Visible=shown
	if shown then Theme.Motion:Breathe(self.freeGift.Visual,1.08,0.8) else Theme.Motion:StopBreathe(self.freeGift.Visual) end
end

-- October 16 chicken offers: the Robux ladder takes the free gift's spot once the
-- free chicken is claimed. Tapping opens Roblox's purchase prompt; the server checks
-- the step and grants the chicken (docs/team/CHICKEN_OFFERS.md).
local RAINBOW=ColorSequence.new({
	ColorSequenceKeypoint.new(0,Color3.fromRGB(255,72,72)),ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,170,40)),
	ColorSequenceKeypoint.new(0.33,Color3.fromRGB(255,240,60)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(70,240,110)),
	ColorSequenceKeypoint.new(0.67,Color3.fromRGB(60,190,255)),ColorSequenceKeypoint.new(0.83,Color3.fromRGB(170,100,255)),
	ColorSequenceKeypoint.new(1,Color3.fromRGB(255,72,72))})
local OFFER_RAYS="rbxassetid://90649675688974"
local ROBUX_GREEN=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(0,255,67)),
	ColorSequenceKeypoint.new(0.4744,Color3.fromRGB(105,255,91)),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,223,6))})

function Hud:BuildChickenOffer(shell)
	local app=self.app
	local corner=Theme.Frame(shell,"ChickenOfferCorner",UDim2.fromScale(0.082,0.16))
	corner.BackgroundTransparency,corner.AnchorPoint=1,Vector2.new(1,0.5)
	corner.Position=UDim2.fromScale(0.988,0.31)
	Theme.Aspect(corner,136/132)
	self.offerCorner=corner
	local button=Theme.IconButton(corner,"ChickenOffer","",ShopCatalog.Products.ChickenOffer1.image,function()
		local key=self.offerKey
		if not key or not app.commerce then return end
		app.audio:Play("Click")
		app.commerce:Load(key)
		if app.commerce:State(key)~="ready" then app:Notify("Getting the offer ready… try again in a moment.",false);return end
		app.commerce:Buy(key)
	end)
	button.Size,button.Visible,button.TextColor3=UDim2.fromScale(1,1),false,Color3.new(1,1,1)
	self.offer=button
	local visual=button.Visual
	-- Brighter rainbow sunburst: a smooth gradient that turns while the rays spin.
	-- Solid white rays (assets/chicken-ladder-20261016/sunburst-white.png) so the
	-- rainbow gradient shows at full strength; the gradient turns while the rays spin.
	local rays=Theme.Image(visual,"Sunburst",OFFER_RAYS,UDim2.fromScale(1.75,1.75),UDim2.fromScale(0.5,0.4))
	rays.AnchorPoint,rays.ZIndex,rays.ImageColor3,rays.ImageTransparency=Vector2.new(0.5,0.5),2,Color3.new(1,1,1),0.1
	Theme.Aspect(rays,1)
	local rainbow=Instance.new("UIGradient")
	rainbow.Name,rainbow.Color,rainbow.Parent="Rainbow",RAINBOW,rays
	Theme.Motion:Tween(rays,"spin",{Rotation=360},10,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1,false)
	Theme.Motion:Tween(rainbow,"hue",{Rotation=360},4,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1,false)
	-- Offer art has padding around the chicken; draw it larger than a menu icon.
	visual.Icon.AnchorPoint,visual.Icon.Size,visual.Icon.Position=Vector2.new(0.5,0.5),UDim2.fromScale(1.45,1.3),UDim2.fromScale(0.5,0.4)
	local price=Instance.new("UIGradient")
	price.Rotation,price.Color,price.Parent=90,ROBUX_GREEN,visual.Label
	visual.Label.TextScaled=true
	visual.Label.Position,visual.Label.Size=UDim2.fromScale(-0.1,0.74),UDim2.fromScale(1.2,0.36)
	Theme.ScaleText(corner)
end

function Hud:UpdateChickenOffer(state)
	local gift=state.freeGift
	local giftDone=type(gift)~="table" or gift.enabled~=true or gift.claimed==true
	local step=tonumber(state.chickenOfferStep) or 0
	local key=ShopCatalog.ChickenOfferOrder[step+1]
	local product=key and ShopCatalog.Products[key]
	local shown=giftDone and product~=nil
	-- A step bought this session: celebrate, then show the next offer.
	if self.offerStep~=nil and step>self.offerStep then
		local bought=ShopCatalog.Products[ShopCatalog.ChickenOfferOrder[step]]
		if bought then self.app:Notify(bought.name.." joined your Flock!",true) end
		if shown then Theme.Motion:PopScale(self.offer.Visual,0.6,0.35) end
	end
	self.offerStep=step
	if product and key~=self.offerKey then
		self.offerKey=key
		self.offer.Visual.Icon.Image=product.image
		if self.app.commerce then self.app.commerce:Load(key) end
	end
	if product then
		local entry=self.app.commerce and self.app.commerce.products[key]
		local robux=if entry and type(entry.price)=="number" then entry.price else product.proposedPrice
		self.offer.Text=utf8.char(0xE002)..Theme.Money(robux)
	end
	if shown==(self.offerShown==true) then return end
	self.offerShown=shown
	self.offer.Visible=shown
	if shown then Theme.Motion:Breathe(self.offer.Visual,1.06,0.8) else Theme.Motion:StopBreathe(self.offer.Visual) end
end

-- The icon is aspect-constrained (anchor 0,0), so it swells from its corner; keep it small.
function Hud:PopCash()
	Theme.Motion:PopScale(self.cashIcon,1.12)
	Theme.Motion:PopScale(self.money,1.06)
end

-- October 20 egg-sale coin burst: Coins still flying in from the sell pad stay out of
-- the readout until each coin lands (ActionFeedback). Display only.
function Hud:ShownCoins(state)
	local feedback=self.app.feedback
	local flying=if feedback then feedback:CoinsInFlight() else 0
	return math.max(0,(state.coins or 0)-(self.heldCash or 0)-flying)
end

-- A coin landed: count the readout up to it and pop the icon.
function Hud:RefreshCoins()
	local state=self.app.state
	if not state then return end
	local shown=self:ShownCoins(state)
	Theme.Motion:Count(self.money,shown,function(value) return Theme.CompactMoney(value) end)
	if self.lastCoins and shown>self.lastCoins then self:PopCash() end
	self.lastCoins=shown
end

-- Called when the offline receipt closes: a few coin icons fly from the receipt
-- (origin: absolute screen point, or nil) into the coin readout, then the
-- balance counts up to the real total. Plain TweenService tweens.
function Hud:ReleaseOfflineCash(receiptId,origin)
	if receiptId==nil or self.releasedReceipt==receiptId or self.releasingReceipt==receiptId then return end
	-- Keep holding through the flight; settle() lets the full balance show.
	self.releasingReceipt=receiptId
	local app=self.app
	local function settle()
		self.releasedReceipt,self.heldCash=receiptId,0
		local coins=if app.state then self:ShownCoins(app.state) else 0
		Theme.Motion:Count(self.money,coins,function(value) return Theme.CompactMoney(value) end,1)
		self.lastCoins=coins
		self:PopCash()
		app.audio:Play("CashTick",1,{voiceKey="OfflineCash",maxVoices=2})
	end
	local layer=app.hudLayer
	if app.reducedMotion or not origin or not layer then settle();return end
	local base=layer.AbsolutePosition
	local target=self.cashIcon.AbsolutePosition+self.cashIcon.AbsoluteSize/2-base
	local start=origin-base
	local size=math.max(36,self.cashIcon.AbsoluteSize.X*0.7)
	local arrived=false
	for index=1,7 do
		local icon=Instance.new("ImageLabel")
		icon.Name,icon.Image,icon.BackgroundTransparency="OfflineCashFly",Theme.Assets.Coin,1
		icon.AnchorPoint,icon.Size,icon.ZIndex=Vector2.new(0.5,0.5),UDim2.fromOffset(size,size),40
		-- Start in a loose cluster, then arc down-left into the readout.
		local spread=Vector2.new(math.random(-60,60),math.random(-40,40))
		icon.Position=UDim2.fromOffset(start.X+spread.X,start.Y+spread.Y)
		icon.Parent=layer
		local delay=(index-1)*0.07
		local flight=TweenService:Create(icon,TweenInfo.new(0.55,Enum.EasingStyle.Quad,Enum.EasingDirection.In,0,false,delay),
			{Position=UDim2.fromOffset(target.X,target.Y),Size=UDim2.fromOffset(size*0.6,size*0.6),Rotation=math.random(-40,40)})
		flight.Completed:Once(function()
			icon:Destroy()
			Theme.Motion:PopScale(self.cashIcon,1.12)
			if not arrived then arrived=true;settle() end
		end)
		flight:Play()
	end
end

function Hud:Update(state,count,limit,capacity,selected,deployed)
	self:UpdateOpening(state)
	self:UpdateAutoRoll(state)
	self:UpdateTerritory(state)
	self:UpdateRebirth(state)
	self:UpdateFreeGift(state)
	self:UpdateChickenOffer(state)
	-- October 16 owner request: the offline receipt's coins (already saved by the
	-- server) stays out of the displayed balance until the receipt is closed, then
	-- flies in (ReleaseOfflineCash). Display only; state.coins is untouched.
	local receipt=state.offlineCash
	self.heldCash=if type(receipt)=="table" and (tonumber(receipt.amount) or 0)>0 and receipt.id~=self.releasedReceipt
		then receipt.amount else 0
	local shown=self:ShownCoins(state)
	Theme.Motion:Count(self.money,shown,function(value) return Theme.CompactMoney(value) end)
	-- Confirmed gains only (never the first packet or a purchase).
	if self.lastCoins and shown>self.lastCoins then self:PopCash() end
	self.lastCoins=shown
	self:UpdateEggLine(state.eggs or {})
	-- October 20: the Flock is the chickens laying (Flock Size); storage has no visible cap.
	local flock=state.flock
	self.flock.Text=if type(flock)=="table" and type(flock.size)=="number"
		then "Flock "..#(flock.ids or {}).."/"..flock.size else "Flock "..count.."/"..limit
	local atHome=state.armyState=="Home"
	local away=state.armyState~=nil and not atHome
	if away~=self.armyAway then self.armyAway=away;self:RefreshCommands(false) end
	self.armyCount.Text=(if atHome then selected else deployed).."/"..capacity
	local callUnlocked=callArmyUnlocked(state)
	if callUnlocked~=self.callUnlocked then self.callUnlocked=callUnlocked;self:UpdateArmyCommands(false) end
	self.callArmy.TextColor3=if state.armyState=="Following" then Theme.PageColors.Army else Theme.Colors.ink
	local explored=0
 for _,won in state.frontierWins or {} do if won then explored+=1 end end
 local outpostCount=#Progression.Outposts()
 -- Territories held now (limit from research) and the live egg-value bonus they pay.
 local held=state.holdCount or 0
 local bonus=math.floor((state.territoryBonus or 0)*100+0.5)
 self.conquered.Text="Camps held "..held.."/"..(state.holdLimit or 8)..(if bonus>0 then " · +"..bonus.."% eggs" else "")
  ..(if outpostCount>0 then " · Outposts "..explored.."/"..outpostCount else "")
	self.conquered.TextColor3=if held>0 then A.green else A.gold
	self.save.Text=if state.saveStatus=="error" then "Save unavailable · Settings" elseif state.saveStatus=="loading" then "Loading…" else ""
	self.save.TextColor3=if state.saveStatus=="error" then A.red else Theme.Colors.muted
	if state.saveStatus=="error" and self.lastSaveStatus~="error" then
		self.app:Notify(state.saveMessage or "Saving is unavailable right now. Check Settings.",false)
	end
	self.lastSaveStatus=state.saveStatus
	if self.lastCount and (count~=self.lastCount or capacity~=self.lastCapacity) then Theme.Motion:Pop(self.army.Visual,1.1) end
	if self.lastCount and count>self.lastCount then Theme.Motion:PopScale(self.flock,1.1) end
	if self.lastConquered and held>self.lastConquered then
		Theme.Motion:PopScale(self.conquered,1.13)
		self:PopCash()
		Theme.Motion:Burst(self.app.gui.Shell,UDim2.fromScale(0.92,0.94),A.gold)
	end
	self.lastCount,self.lastCapacity,self.lastConquered=count,capacity,held
end

return Hud
