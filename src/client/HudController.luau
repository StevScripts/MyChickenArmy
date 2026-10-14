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
local Progression=require(game.ReplicatedStorage.PetRoll.Shared.Progression)
local A=Theme.Arcade
local ARMY_HOME_SCALE=0.82
local Hud={}
Hud.__index=Hud

local function touchPrimary()
	return UserInputService.PreferredInput==Enum.PreferredInput.Touch
end

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
	self.status=Theme.Display(shell,"ArmyStatus","",21)
	self.status.AnchorPoint,self.status.Position,self.status.Size,self.status.TextXAlignment=Vector2.new(0.5,0),UDim2.fromScale(0.5,0.035),UDim2.fromScale(0.45,0.04),Enum.TextXAlignment.Center
	self.status.Visible=false
	self.objective=Theme.Display(shell,"OpeningObjective","",21,A.gold)
	self.objective.AnchorPoint,self.objective.Position,self.objective.Size,self.objective.TextXAlignment=Vector2.new(0.5,0),UDim2.fromScale(0.5,0.035),UDim2.fromScale(0.45,0.04),Enum.TextXAlignment.Center
	self.objective.Visible=false
	local cash=Theme.Container(shell,"CashReadout")
	self.cashReadout=cash
	cash.AnchorPoint,cash.Position,cash.Size=Vector2.new(0,1),UDim2.fromScale(0.012,0.98),UDim2.fromScale(0.3,0.14)
	Theme.Aspect(cash,3.2)
	self.money=Theme.Display(cash,"Money","$0",46,Theme.Colors.money)
	self.cashIcon=Theme.Image(cash,"CashIcon",Theme.Assets.Cash,UDim2.fromScale(0.22,0.64),UDim2.fromScale(0,0.04))
	Theme.Aspect(self.cashIcon,1)
	self.money.Position,self.money.Size=UDim2.fromScale(0.24,0.2),UDim2.fromScale(0.76,0.44)
	self.income=Theme.Display(cash,"Income","",20)
	self.income.Position,self.income.Size=UDim2.fromScale(0,0.68),UDim2.fromScale(1,0.3)
	self.income.TextWrapped,self.income.Visible=false,false
	self.territory=Theme.Display(cash,"TerritoryIncome","",18,A.gold)
	self.territory.Position,self.territory.Size,self.territory.Visible=UDim2.fromScale(0,0),UDim2.fromScale(1,0.2),false
	-- Rebirth rank ("Rebirth 2") sits just above the money; hidden at rank 0.
	self.rank=Theme.Display(cash,"RebirthRank","",24,Theme.ReferenceColors.Army)
	self.rank.AnchorPoint,self.rank.Position,self.rank.Size=Vector2.new(0,1),UDim2.fromScale(0,0),UDim2.fromScale(0.7,0.26)
	self.rank.Visible=false
	local totals=Theme.Container(shell,"ArmyTotals")
	self.totals=totals
	totals.AnchorPoint,totals.Position,totals.Size=Vector2.new(1,1),UDim2.fromScale(0.988,0.98),UDim2.fromScale(0.3,0.09)
	Theme.Aspect(totals,4.2)
	self.conquered=Theme.Display(totals,"Conquered","Camps held 0/8",27,A.gold)
	self.conquered.Position,self.conquered.Size,self.conquered.TextXAlignment=UDim2.fromScale(0,0),UDim2.fromScale(1,0.45),Enum.TextXAlignment.Right
	self.flock=Theme.Display(totals,"Flock","Flock 0/40",25,A.gold)
	self.flock.Position,self.flock.Size,self.flock.TextXAlignment=UDim2.fromScale(0,0.55),UDim2.fromScale(1,0.45),Enum.TextXAlignment.Right
	self.hill=HillHud.new(app,shell,cash)
	self:BuildSettingsTopbar()
	-- Four slots (Re-enlist shows once it matters); the list centers whatever is visible.
	local shortcuts=Theme.Frame(shell,"CollectionNavigation",UDim2.fromScale(0.082,0.68))
	shortcuts.BackgroundTransparency=1
	shortcuts.AnchorPoint,shortcuts.Position=Vector2.new(0,0.5),UDim2.fromScale(0.012,0.43)
	self.shortcuts=shortcuts
	local shortcutLayout=Instance.new("UIListLayout")
	shortcutLayout.SortOrder,shortcutLayout.Padding=Enum.SortOrder.LayoutOrder,UDim.new(0.0225,0)
	shortcutLayout.VerticalAlignment=Enum.VerticalAlignment.Center
	shortcutLayout.Parent=shortcuts
	for i,page in {"Shop","Index","Upgrades"} do
		local button=Theme.IconButton(shortcuts,page,page,if page=="Upgrades" then ResearchAssets.lab else Theme.Assets[page],function() app:TogglePage(page) end)
		button.LayoutOrder=i
	end
	-- Re-enlist: its own HUD icon (the hex on the Upgrades screen stays too).
	self.reenlist=Theme.IconButton(shortcuts,"Reenlist","Rebirth",Theme.Assets.Reenlist or Theme.Assets.ArmyHud,function()
		app.audio:Play("Click")
		if app.rebirthPanel then app.rebirthPanel:Open() end
	end)
	self.reenlist.LayoutOrder,self.reenlist.Visible=4,false
	-- Below the status line, clear of the Settings corner; errors also raise a toast.
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
	Theme.Motion:BindButton(button,button)
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
	Theme.Aspect(self.shortcuts,136/544)
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
	for _,page in {"Shop","Index","Upgrades","Reenlist"} do
		local button=self.shortcuts:FindFirstChild(page)
		button.Size=UDim2.fromScale(1,0.235)
		Theme.Aspect(button,136/132)
		button.Visual.Label.TextScaled=true
	end
	for _,label in {self.status,self.objective,self.money,self.income,self.territory,self.rank,self.conquered,self.flock,self.save,self.armyCount} do
		label.TextScaled=true
	end
	Theme.Aspect(self.status,19)
	Theme.Aspect(self.objective,19)
	Theme.Aspect(self.save,19)
	Theme.ScaleText(self.navigation)
	Theme.ScaleText(self.shortcuts)
	Theme.ScaleText(self.settings)
	-- Top status lines get the shared readable text floor (wide boxes, no overlap risk).
	for _,label in {self.status,self.objective,self.save} do Theme.ScaleText(label) end
	self:ApplyInputLayout()
	self:UpdateArmyCommands(true)
end

-- Touch: lift the corner readouts above the thumbstick and jump button (the
-- cash readout moves beside the left shortcut column; the Camps held/Flock lines
-- sit above the right-side Invasions icon, which spans about 0.48-0.64) and
-- enlarge Settings to a thumb-sized target that ends above the research goal chip
-- (top 0.12). Keyboard/gamepad keep the authored bottom corners.
-- settingsBottom: lowest screen Y scale the Settings button can reach (for neighbours).
function Hud:ApplyInputLayout()
	local touch=touchPrimary()
	self.cashReadout.AnchorPoint=Vector2.new(0,1)
	self.cashReadout.Position=if touch then UDim2.fromScale(0.105,0.7) else UDim2.fromScale(0.012,0.98)
	self.totals.Position=if touch then UDim2.fromScale(0.988,0.47) else UDim2.fromScale(0.988,0.98)
	self.settings.Size=if touch then UDim2.fromScale(0.065,0.105) else UDim2.fromScale(0.04,0.072)
	self.settingsBottom=self.settings.Position.Y.Scale+self.settings.Size.Y.Scale
	-- The Hill chip rides just above the cash readout wherever it sits.
	if self.hill then self.hill:Place() end
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
			.." · Worth $"..Theme.Money(eggs.carriedValue or 0)
	else self.income.Text="Yard eggs: $"..Theme.Money(eggs.value or 0) end
end

function Hud:UpdateOpening(state)
	local guidance=self.app.base.OpeningGuidance(state)
	self.objective.Text=if guidance then guidance.text else ""
	self.objective.Visible=guidance~=nil and not self.app.panel.Visible and self.app.commander==nil
end

-- Top-centre priority: lesson card > army status > next-goal line. The Hill
-- title also owns the top line while it shows; the army status returns after.
function Hud:SyncStatus()
	local commander=self.app.commander
	local lesson=commander~=nil and commander.lessonVisible==true
	self.status.Visible=self.statusWanted==true and not (self.hill and self.hill.bannerVisible) and not lesson
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

-- state.rebirth is missing on the first packets and is only a stub until the
-- server quote ships; every field is optional here.
function Hud:UpdateRebirth(state)
	local quote=state and state.rebirth
	if type(quote)~="table" then self.rank.Visible=false;self.reenlist.Visible=false;return end
	local rank=tonumber(quote.rank) or 0
	-- The Re-enlist icon appears once it matters: the King is beaten or a rank is earned.
	local showIcon=quote.enabled~=false and (rank>=1 or quote.kingCleared==true)
	if self.reenlist.Visible~=showIcon then self.reenlist.Visible=showIcon end
	local pulse=showIcon and quote.eligible==true and not self.app.reducedMotion
	if pulse~=(self.reenlistPulse~=nil) then
		local visual=self.reenlist.Visual
		if self.reenlistPulse then self.reenlistPulse:Cancel();self.reenlistPulse=nil end
		visual.Size=UDim2.fromScale(1,1)
		if pulse then
			self.reenlistPulse=TweenService:Create(visual,TweenInfo.new(0.8,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Size=UDim2.fromScale(1.08,1.08)})
			self.reenlistPulse:Play()
		end
	end
	self.rank.Text=RebirthPanel.Title(rank)
	-- The Hill countdown chip uses the same spot above the cash readout.
	self.rank.Visible=rank>=1 and not (self.hill and self.hill.waiting and self.hill.waiting.Visible)
	if self.lastRank and rank>self.lastRank then Theme.Motion:Pop(self.rank,1.15) end
	self.lastRank=rank
	if quote.eligible==true and quote.enabled~=false and not self.rebirthToastShown then
		self.rebirthToastShown=true
		local nextTitle=RebirthPanel.Title(rank+1)
		self.app:Notify("Rebirth ready: "..nextTitle.."!",true)
	end
end

function Hud:Update(state,count,limit,capacity,selected,deployed)
	self:UpdateOpening(state)
	self:UpdateTerritory(state)
	self:UpdateRebirth(state)
	Theme.Motion:Count(self.money,state.coins,function(value) return "$"..Theme.CompactMoney(value) end)
	self:UpdateEggLine(state.eggs or {})
	self.flock.Text="Flock "..count.."/"..limit
	local atHome=state.armyState=="Home"
	local away=state.armyState~=nil and not atHome
	if away~=self.armyAway then self.armyAway=away;self:RefreshCommands(false) end
	self.armyCount.Text=(if atHome then selected else deployed).."/"..capacity
	self.status.Text=if atHome then ""
		elseif state.armyState=="Following" then "Army following you"
		elseif state.armyState=="Returning" then "Returning home"
		elseif state.stationedAt then "Holding "..state.stationedAt
		elseif state.marchingTo then "Marching to "..state.marchingTo
		else "Army deployed"
	local callUnlocked=callArmyUnlocked(state)
	if callUnlocked~=self.callUnlocked then self.callUnlocked=callUnlocked;self:UpdateArmyCommands(false) end
	self.callArmy.TextColor3=if state.armyState=="Following" then Theme.PageColors.Army else Theme.Colors.ink
	if state.armyState~="Returning" and (state.recoveringCount or 0)+(state.reinforcingCount or 0)>0 then
		self.status.Text=(state.recoveringCount or 0)+(state.reinforcingCount or 0).." reinforcing"
	end
	self.statusWanted=not atHome and self.status.Text~=""
	self:SyncStatus()
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
	if self.lastConquered and held>self.lastConquered then
		Theme.Motion:Pop(self.conquered,1.13)
		Theme.Motion:Pop(self.cashIcon,1.14)
		Theme.Motion:Burst(self.app.gui.Shell,UDim2.fromScale(0.92,if touchPrimary() then 0.43 else 0.94),A.gold)
	end
	self.lastCount,self.lastCapacity,self.lastConquered=count,capacity,held
end

return Hud
