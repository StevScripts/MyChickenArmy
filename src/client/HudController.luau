--!strict
-- Compact play HUD; menus and economy actions remain owned by AppController.
local Theme=require(script.Parent.UITheme)
local GuiService=game:GetService("GuiService")
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local ResearchAssets=require(script.Parent.ResearchAssets)
local HillHud=require(script.Parent.HillHud)
local BoostReadout=require(script.Parent.BoostReadout)
local RebirthPanel=require(script.Parent.RebirthPanel)
local FreeGiftController=require(script.Parent.FreeGiftController)
local ToolController=require(script.Parent.ToolController)
local ShopCatalog=require(game.ReplicatedStorage.PetRoll.Shared.ShopCatalog)
local A=Theme.Arcade
local GEAR_PEEK_SECONDS=4
-- The Settings gear's hit area grows this much past its circle (phone 28 -> 48 px).
local GEAR_PAD=1.72
local ARMY_HOME_SCALE=0.82
local Hud={}
Hud.__index=Hud


-- October 20: Call Army is free for everyone (effects.callArmy is always 1).
local function callArmyUnlocked(state)
	local effects=state and state.effects
	return effects~=nil and (effects.callArmy or 0)>=1
end

function Hud.new(app,shell)
	local self=setmetatable({app=app},Hud)
	-- October 20 (Stevin): My Army sits centred just above Roblox's own hotbar, one
	-- layout for every device, 20% smaller than before so a phone keeps room above it.
	-- October 21 (Stevin): it floated too far up; it now sits close over the hotbar with
	-- just room for the vacuum's egg bar in between. The space comes from the hotbar's
	-- own size (ToolController.BottomReserve): 84 px on PC, more with consoles' slots.
	local navigation=Theme.Frame(shell,"Navigation",UDim2.fromScale(0.248,0.204))
	self.navigation=navigation
	navigation.AnchorPoint,navigation.Position,navigation.BackgroundTransparency=Vector2.new(0.5,1),UDim2.new(0.5,0,1,-ToolController.BottomReserve),1
	self.army=Theme.IconButton(navigation,"Army","My Army",Theme.Assets.ArmyHud or Theme.Assets.Army,function() app:TogglePage("Army") end)
	local function command(action)
		app.audio:Play("Click")
		app:Request(action)
	end
	-- Shown with My Army's commands; free for everyone since October 20.
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
	-- (October 21 the coin/clover boosts rode here for a while; they now sit small in
	-- the bottom-right corner, BoostSlot below.) Later October 21 (Stevin): no yard
	-- "Carrying: N eggs" line; the Coins and Friend Boost rows sit at the bottom (was
	-- 0.176 tall, aspect 2.545; rows rescaled by 1/0.735 to keep their size).
	cash.AnchorPoint,cash.Position,cash.Size=Vector2.new(0,1),UDim2.fromScale(0.012,0.98),UDim2.fromScale(0.3,0.1294)
	Theme.Aspect(cash,3.463)
	-- October 15 owner UI Lab tweak: larger coin number with a gradient face; October 20
	-- (gold Coins): the face is gold beside the gold coin, and the number has no "$".
	self.money=Theme.Display(cash,"Money","0",46,Color3.fromRGB(252,248,255))
	local moneyGradient=Instance.new("UIGradient")
	moneyGradient.Rotation=90
	moneyGradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,247,57)),
		ColorSequenceKeypoint.new(0.4744,Color3.fromRGB(255,214,48)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,153,0))})
	moneyGradient.Parent=self.money.TextFace
	self.cashIcon=Theme.Image(cash,"CashIcon",Theme.Assets.Coin,UDim2.fromScale(0.22,0.6925),UDim2.fromScale(0.0021,0.0576))
	Theme.Aspect(self.cashIcon,1)
	self.money.Position,self.money.Size=UDim2.fromScale(0.24,0.0835),UDim2.fromScale(0.76,0.6091)
	-- Friend Boost row (FriendBoost.luau mounts into it) is the last row.
	self.friendBoostSlot=Theme.Container(cash,"FriendBoostSlot")
	self.friendBoostSlot.Position,self.friendBoostSlot.Size=UDim2.fromScale(0,0.7007),UDim2.fromScale(1,0.2721)
	-- Later October 21 (Stevin, reference image): the coin/clover boosts
	-- (BoostReadout.luau) are a very small icon pair in the bottom-right corner.
	self.boostSlot=Theme.Container(shell,"BoostSlot")
	self.boostSlot.AnchorPoint,self.boostSlot.Position,self.boostSlot.Size=Vector2.new(1,1),BoostReadout.Position,BoostReadout.Size
	Theme.Aspect(self.boostSlot,BoostReadout.Aspect)
	self.territory=Theme.Display(cash,"TerritoryIncome","",18,A.gold)
	self.territory.Position,self.territory.Size,self.territory.Visible=UDim2.fromScale(0,0),UDim2.fromScale(1,0.2163),false
	-- Rebirth rank ("Rebirth 2") sits just above the money; hidden at rank 0.
	self.rank=Theme.Display(cash,"RebirthRank","",24,Theme.ReferenceColors.Army)
	self.rank.AnchorPoint,self.rank.Position,self.rank.Size=Vector2.new(0,1),UDim2.fromScale(0,0),UDim2.fromScale(0.7,0.2816)
	self.rank.Visible=false
	-- October 20 (S19, Stevin): no Gems counter with the Coins; Gems show only in the
	-- Rebirth screen (GemUpgradeGrid's balance).
	-- October 21 (Stevin): no "Camps held" / "Flock" lines in the bottom-right corner;
	-- the Gold Rush chip (GoldRushController) sits there, just above the boosts.
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
	-- October 20 overhaul (S9): a red count of the upgrades you can buy right now
	-- (server-counted, starter reserve respected); UpdateUpgradesBadge sets it.
	local upgradesBadge=Theme.Frame(shortcuts.Upgrades.Visual,"UpgradesReady",UDim2.fromScale(0.3,0.3),Color3.fromRGB(235,45,45))
	upgradesBadge.AnchorPoint,upgradesBadge.Position,upgradesBadge.ZIndex,upgradesBadge.Visible=Vector2.new(0.5,0.5),UDim2.fromScale(0.86,0.1),8,false
	Theme.Aspect(upgradesBadge,1)
	Theme.Round(upgradesBadge).CornerRadius=UDim.new(0.5,0)
	Theme.Stroke(upgradesBadge,Color3.new(0,0,0),2).LineJoinMode=Enum.LineJoinMode.Round
	local upgradesCount=Theme.Label(upgradesBadge,"Count","",28,Color3.new(1,1,1))
	upgradesCount.AnchorPoint,upgradesCount.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
	upgradesCount.Size,upgradesCount.TextScaled,upgradesCount.ZIndex,upgradesCount.TextXAlignment=UDim2.fromScale(0.8,0.8),true,9,Enum.TextXAlignment.Center
	self.upgradesBadge,self.upgradesCount=upgradesBadge,upgradesCount
	-- October 21 game feel: one gold ring round the badge pulses while anything is
	-- affordable (its own frame: the badge's black outline keeps its stroke).
	local upgradesGlow=Theme.Frame(upgradesBadge,"GlowRing",UDim2.fromScale(1.32,1.32))
	upgradesGlow.AnchorPoint,upgradesGlow.Position,upgradesGlow.BackgroundTransparency,upgradesGlow.ZIndex=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),1,7
	Theme.Round(upgradesGlow).CornerRadius=UDim.new(0.5,0)
	self.upgradesGlow=upgradesGlow
	-- October 16 owner request: Auto Roll is a plain text button on the right, like Mini
	-- War's Auto Sell / Auto Collect; green ON, red OFF, gold while it holds a chicken.
	-- October 20 (S12, S12b): shown once the Auto Roll Gem Upgrade is owned, on the right
	-- edge under Rebirth (clear of the phone jump button). Later October 20 owner request:
	-- pressing it turns Auto Roll on/off; the gear beside it pops out the stop list.
	local autoRoll=Theme.Button(shell,"AutoRoll","",function()
		local auto=app.state and app.state.autoRoll
		if not auto or not auto.unlocked then return end
		app.audio:Play("Click")
		if app.autoRollMenu then app.autoRollMenu:TogglePower() end
	end,A.red)
	autoRoll.AnchorPoint,autoRoll.Position,autoRoll.Size=Vector2.new(1,1),UDim2.fromScale(0.988,0.735),UDim2.fromScale(0.15,0.075)
	autoRoll.TextColor3,autoRoll.Visible=Color3.new(1,1,1),false
	Theme.Aspect(autoRoll,3.2)
	local titleLabel=Theme.Display(autoRoll.Visual,"Title","Auto Roll",24)
	titleLabel.Position,titleLabel.Size,titleLabel.ZIndex=UDim2.fromScale(0.04,0.06),UDim2.fromScale(0.92,0.52),6
	titleLabel.TextXAlignment=Enum.TextXAlignment.Center
	local stateLabel=Theme.Label(autoRoll.Visual,"State","OFF",20)
	stateLabel.Position,stateLabel.Size,stateLabel.ZIndex=UDim2.fromScale(0.04,0.56),UDim2.fromScale(0.92,0.36),6
	stateLabel.TextXAlignment=Enum.TextXAlignment.Center
	local gear=Theme.Button(autoRoll,"Settings","",function()
		local auto=app.state and app.state.autoRoll
		if not auto or not auto.unlocked then return end
		app.audio:Play("Click")
		if app.autoRollMenu then app.autoRollMenu:Toggle() end
	end,Theme.ActionColors.navigation)
	gear.AnchorPoint,gear.Position,gear.Size=Vector2.new(1,0.5),UDim2.fromScale(-0.04,0.5),UDim2.fromScale(1,1)
	Theme.Aspect(gear,1)
	Theme.Image(gear.Visual,"Icon","rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab@2x.png",
		UDim2.fromScale(0.64,0.64),UDim2.fromScale(0.18,0.15)).ZIndex=6
	-- Later October 20 owner request: the gear shows only while the mouse is over the
	-- button or the gear, while either is selected (gamepad), while the board is open,
	-- and for a few seconds after a touch press (phones have no hover).
	gear.Visible=false
	local hovered,selected={},{}
	for _,item in {autoRoll,gear} do
		item.InputBegan:Connect(function(input)
			if input.UserInputType==Enum.UserInputType.MouseMovement then
				hovered[item]=true;self:UpdateAutoRollGear()
			elseif input.UserInputType==Enum.UserInputType.Touch then
				self.autoRollPeekUntil=os.clock()+GEAR_PEEK_SECONDS
				self:UpdateAutoRollGear()
				task.delay(GEAR_PEEK_SECONDS+0.05,function() self:UpdateAutoRollGear() end)
			end
		end)
		item.InputEnded:Connect(function(input)
			if input.UserInputType~=Enum.UserInputType.MouseMovement then return end
			hovered[item]=nil
			-- Grace for the small gap between the button and the gear.
			task.delay(0.2,function() self:UpdateAutoRollGear() end)
		end)
		item.SelectionGained:Connect(function() selected[item]=true;self:UpdateAutoRollGear() end)
		item.SelectionLost:Connect(function() selected[item]=nil;self:UpdateAutoRollGear() end)
	end
	self.autoRollHovered,self.autoRollSelected=hovered,selected
	Theme.ScaleText(autoRoll)
	self.autoRoll,self.autoRollState,self.autoRollSettings=autoRoll,stateLabel,gear
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
	-- October 23 (Stevin): the chunky gift box, not the chicken, and a bit bigger (1.2x;
	-- the chicken is revealed in the popup). Its foot stays clear of Rebirth's top (0.42).
	local giftCorner=Theme.Frame(shell,"FreeGiftCorner",UDim2.fromScale(0.0984,0.192))
	giftCorner.BackgroundTransparency,giftCorner.AnchorPoint=1,Vector2.new(1,0.5)
	giftCorner.Position=UDim2.fromScale(0.988,0.3)
	Theme.Aspect(giftCorner,136/132)
	self.freeGiftCorner=giftCorner
	self.freeGift=Theme.IconButton(giftCorner,"FreeGift","Free Gift!",FreeGiftController.Assets.Gift,function()
		app.audio:Play("Click")
		if app.freeGift then app.freeGift:Open() end
	end)
	self.freeGift.Size,self.freeGift.Visible=UDim2.fromScale(1,1),false
	-- Golden sunburst behind the gift (centred on the icon), slowly spinning.
	local burst=Theme.Image(self.freeGift.Visual,"Sunburst",Theme.Assets.Rays,UDim2.fromScale(1.25,1.25),UDim2.fromScale(0.5,0.37))
	burst.AnchorPoint,burst.ZIndex=Vector2.new(0.5,0.5),2
	burst.ImageColor3,burst.ImageTransparency=Color3.fromRGB(255,184,0),0
	Theme.Aspect(burst,1)
	Theme.Motion:Tween(burst,"spin",{Rotation=360},10,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1,false)
	-- October 23 (Stevin): a plain white "Free Gift!" caption like the other HUD icons
	-- (was "Free Chicken!" with a sweeping gold shine).
	self.freeGift.TextColor3=Color3.new(1,1,1)
	self:BuildChickenOffer(shell)
	-- Below the top-centre line, clear of the Settings corner; errors also raise a toast.
	self.save=Theme.Display(shell,"SaveStatus","",21)
	self.save.AnchorPoint,self.save.Position,self.save.Size,self.save.TextXAlignment=Vector2.new(0.5,0),UDim2.fromScale(0.5,0.08),UDim2.fromScale(0.45,0.04),Enum.TextXAlignment.Center
	self:Layout()
	self:StartIdleMotion()
	-- October 21 game feel: the Army count punches from its middle when it changes.
	Theme.Motion:Center(self.armyCount)
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
	button.BackgroundTransparency,button.BorderSizePixel=1,0
	button.Parent=gui
	Theme.Aspect(button,1)
	-- The dark circle is the art (Visual); the button round it is the hit area, grown
	-- GEAR_PAD times left and down (it sits alone in the corner) so a phone gets 48 px.
	local face=Theme.Frame(button,"Visual",UDim2.fromScale(1,1),Color3.fromRGB(18,19,22))
	face.BackgroundTransparency=0.1
	local corner=face:FindFirstChildWhichIsA("UICorner") or Instance.new("UICorner")
	corner.CornerRadius,corner.Parent=UDim.new(1,0),face
	local icon=Instance.new("ImageLabel")
	icon.Name,icon.BackgroundTransparency="Gear",1
	icon.Image="rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab@2x.png"
	icon.AnchorPoint,icon.Position,icon.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(0.64,0.64)
	icon.Parent=face
	local caption=Instance.new("TextLabel")
	caption.Name,caption.Text,caption.Font,caption.TextSize="Caption","Settings",Theme.Font,16
	caption.AnchorPoint,caption.Position,caption.Size=Vector2.new(1,0),UDim2.fromScale(1,1.18),UDim2.fromScale(1.9,0.64)
	caption.TextScaled=true
	caption.BackgroundColor3,caption.BackgroundTransparency=Color3.fromRGB(18,19,22),0.06
	caption.TextColor3,caption.BorderSizePixel,caption.Visible=Color3.new(1,1,1),0,false
	caption.Parent=face
	local captionCorner=Instance.new("UICorner");captionCorner.CornerRadius=UDim.new(0.03,0);captionCorner.Parent=caption
	Theme.PadHit(button,GEAR_PAD,GEAR_PAD,1,0)
	self.settings,self.settingsFace,self.settingsIcon,self.settingsCaption,self.settingsGui=button,face,icon,caption,gui
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
	Theme.Motion:Tween(self.settingsFace,"topbarColor",{BackgroundColor3=if selected then Color3.fromRGB(239,241,245)
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
	for _,label in {self.objective,self.money,self.territory,self.rank,self.save,self.armyCount} do
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

-- October 23 (Stevin, Drop a Fruit recording): every HUD icon idles with a slow tilt,
-- staggered so neighbours never swing in step, and the red badges ping now and then.
-- Plain looping tweens (UIMotion Sway/Ping); reduced motion keeps them still.
function Hud:StartIdleMotion()
	local buttons={self.shortcuts.Shop,self.shortcuts.Upgrades,self.shortcuts.Index,self.reenlist,
		self.freeGift,self.offer,self.army,self.callArmy,self.myBase}
	for index,button in buttons do
		Theme.Motion:Sway(button.Visual.Icon,5,1.3+(index%3)*0.12,(index-1)*0.23)
	end
	Theme.Motion:Ping(self.upgradesBadge,1.7)
	Theme.Motion:Ping(self.rebirthBadge,1.5)
end

-- October 15 owner request: ONE HUD layout for every device (PC, phone, tablet,
-- gamepad). No touch-only positions; edit it once (UI Lab) and it applies everywhere.
-- settingsBottom: lowest screen Y scale the Settings button can reach (for neighbours).
function Hud:ApplyInputLayout()
	self.cashReadout.AnchorPoint,self.cashReadout.Position=Vector2.new(0,1),UDim2.fromScale(0.012,0.98)
	self:PlaceRebirth()
	-- The hit area (GEAR_PAD times the 0.04 x 0.072 circle, anchored top-right); the
	-- circle's own foot is what neighbours clear.
	self.settings.Size=UDim2.fromScale(0.04*GEAR_PAD,0.072*GEAR_PAD)
	self.settingsBottom=self.settings.Position.Y.Scale+0.072
	-- The Hill chip rides just above the coin readout wherever it sits.
	if self.hill then self.hill:Place() end
end

-- Middle of the right edge (all devices).
function Hud:PlaceRebirth()
	self.rebirthCorner.Position=UDim2.fromScale(0.988,0.5)
end

function Hud:Resize(_width, _height, _scale)
	if not self.settingsPanelBound then
		self.settingsPanelBound=true
		self.app.panel:GetPropertyChangedSignal("Visible"):Connect(function() self:UpdateSettingsTopbar() end)
		self.app.panelTitle:GetPropertyChangedSignal("Text"):Connect(function() self:UpdateSettingsTopbar() end)
	end
	self:UpdateSettingsTopbar()
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
	-- October 23 (Stevin): the icon shows from the start (was: once the Coins reach a
	-- quarter of the next Rebirth or a rank is earned).
	local showIcon=quote.enabled~=false and not self.quiet -- October 23: hidden while the HUD is quiet (lessons 1-2)
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
	-- October 23 empty start: Rebirth 0 (introRebirth) keeps rank 0 but reads "Rebirth 0".
	local introDone=rank==0 and state.introRebirth=="done"
	self.rank.Text=if introDone then "Rebirth 0" else RebirthPanel.Title(rank)
	-- The Hill countdown chip uses the same spot above the coin readout.
	self.rank.Visible=(rank>=1 or introDone) and not self.quiet and not (self.hill and self.hill.waitingShown)
	-- Rebirths come often now, so each new rank re-arms the "Rebirth ready" toast.
	if self.lastRank and rank>self.lastRank then Theme.Motion:PopScale(self.rank,1.15);self.rebirthToastShown=false end
	self.lastRank=rank
	-- Rebirth 0 completing re-arms it too (the next one is Rebirth 1).
	if self.lastIntro=="pending" and state.introRebirth=="done" then
		Theme.Motion:PopScale(self.rank,1.15);self.rebirthToastShown=false
	end
	self.lastIntro=state.introRebirth
	local intro=quote.intro==true
	local guideDone=type(state.tutorial)=="table" and state.tutorial.guideCompleted==true
	-- October 26 (Stevin): the % tag shows on the way to every Rebirth, not only Rebirth 0.
	local cost=tonumber(quote.cost)
	self:UpdateRebirthProgress(showIcon and quote.eligible~=true and cost~=nil and cost>0 and (guideDone or not intro),quote)
	-- Never while the HUD is quiet; Rebirth 0 after the tutorial has its own tip card
	-- (TutorialGuide "Rebirth is ready!"), so it gets no toast as well.
	if quote.eligible==true and quote.enabled~=false and not self.rebirthToastShown and not self.quiet
		and not (intro and guideDone) then
		self.rebirthToastShown=true
		local nextTitle=if intro then "Rebirth 0" else RebirthPanel.Title(rank+1)
		self.app:Notify("Rebirth ready: "..nextTitle.."!",true)
	end
end

-- October 23 empty start (the reference's Rebirth progress): while the next Rebirth is
-- on its way (every rank since October 26), the Rebirth button wears its Coins progress
-- as "42%" at its top-left corner, opposite the red "!" that replaces it once it is
-- ready. Coins covered but the rank's chicken not found yet reads "100%".
function Hud:UpdateRebirthProgress(shown: boolean,quote)
	local tag=self.rebirthProgress
	if not tag then
		if not shown then return end
		tag=Theme.Frame(self.reenlist.Visual,"RebirthProgress",UDim2.fromScale(0.5,0.22),Color3.fromRGB(16,23,18))
		tag.AnchorPoint,tag.Position,tag.ZIndex,tag.BackgroundTransparency=Vector2.new(0.5,0.5),UDim2.fromScale(0.2,0.1),8,0.15
		tag.Visible=false -- Pops in below.
		Theme.Round(tag).CornerRadius=UDim.new(0.5,0)
		-- Round joins: a Miter stroke draws a square box around a pill.
		Theme.Stroke(tag,Color3.new(0,0,0),2).LineJoinMode=Enum.LineJoinMode.Round
		local text=Theme.Label(tag,"Percent","",22,A.gold)
		text.AnchorPoint,text.Position,text.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(0.86,0.86)
		text.TextScaled,text.ZIndex,text.TextXAlignment=true,9,Enum.TextXAlignment.Center
		self.rebirthProgress,self.rebirthProgressText=tag,text
	end
	if shown then
		local cost,coins=tonumber(quote.cost),tonumber(quote.coins) or 0
		local percent=if not cost or cost<=0 then 0 elseif coins>=cost then 100 else math.clamp(math.floor(coins/cost*100),0,99)
		self.rebirthProgressText.Text=percent.."%"
	end
	if tag.Visible~=shown then
		tag.Visible=shown
		if shown then Theme.Motion:PopScale(tag,0.6,0.25) end
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

function Hud:UpdateAutoRollGear()
	local gear=self.autoRollSettings
	if not gear then return end
	local menu=self.app.autoRollMenu
	local shown=next(self.autoRollHovered)~=nil or next(self.autoRollSelected)~=nil
		or os.clock()<(self.autoRollPeekUntil or 0) or (menu~=nil and menu.gui~=nil and not menu.closing)
	if shown==gear.Visible then return end
	gear.Visible=shown
	if shown then Theme.Motion:PopScale(gear.Visual,0.7,0.15) end
end

function Hud:UpdateAutoRoll(state)
	local auto=state.autoRoll
	local unlocked=auto~=nil and auto.unlocked==true
	-- Point at the new button once, when the Gem Upgrade is bought in this session.
	if unlocked and self.autoRollUnlocked==false then self.app:Notify("Auto Roll unlocked! Use the Auto Roll button on the right.",true) end
	if unlocked and self.autoRollUnlocked==false then Theme.Motion:PopScale(self.autoRoll.Visual,0.6,0.3) end
	self.autoRollUnlocked=unlocked
	self.autoRoll.Visible=unlocked
	if not unlocked then return end
	-- A press shows its new state at once, before the snapshot echoes it.
	local menu=self.app.autoRollMenu
	local enabled=if menu then menu:PowerOn() else auto.enabled==true
	local holding=enabled and auto.enabled==true and auto.holding==true
	local color=if not enabled then A.red elseif holding then A.gold else A.green
	if self.autoRoll.BackgroundColor3~=color then self.autoRoll.BackgroundColor3=color end
	self.autoRollState.Text=if not enabled then "OFF" elseif holding then "PAUSED" else "ON"
	-- October 21 game feel: the gear turns while Auto Roll runs (a plain looping tween,
	-- not Motion:Spin, which every menu close stops). Reduced motion leaves it still.
	local turning=enabled and not holding
	if turning~=(self.gearTurning==true) then
		self.gearTurning=turning
		local icon=self.autoRollSettings.Visual.Icon
		if turning then Theme.Motion:Tween(icon,"spin",{Rotation=icon.Rotation+360},4,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1)
		else Theme.Motion:Cancel(icon,"spin");icon.Rotation=0 end
	end
end

-- October 25 (Stevin, supersedes the October 23 quiet lessons): during the tutorial the
-- screen shows nothing but the guide card. stage "bare" hides the whole HUD; "coins"
-- brings in the Coins readout (the first money); "upgrades" adds the Upgrades button
-- (the card that opens it); nil brings everything back once the tutorial is over.
-- Every other HUD piece, including ones other controllers mount later (Settings,
-- Playtime, Gold Rush, boosts, Rally …), waits in a hidden holder, so nobody's own
-- Visible toggles are fought. CommanderGuide drives it. `quiet` stays true for the
-- whole tutorial: Rebirth, Free Gift, the offer, the Upgrades badge and boosts read it.
function Hud:SetTutorialStage(stage: string?)
	if self.tutorialStage==stage then return end
	local was=self.tutorialStage
	self.tutorialStage=stage
	self.quiet=stage~=nil
	local layer=self.cashReadout.Parent :: Instance
	if stage and not self.tutorialHold then
		local hold=Theme.Container(layer,"TutorialHold")
		hold.Visible=false
		self.tutorialHold=hold
		local function park(child: Instance)
			if child~=hold and child~=self.cashReadout and child~=self.shortcuts and child:IsA("GuiObject") then child.Parent=hold end
		end
		for _,child in layer:GetChildren() do park(child) end
		self.tutorialHoldAdded=layer.ChildAdded:Connect(function(child) task.defer(park,child) end)
	elseif not stage and self.tutorialHold then
		if self.tutorialHoldAdded then self.tutorialHoldAdded:Disconnect();self.tutorialHoldAdded=nil end
		for _,child in self.tutorialHold:GetChildren() do child.Parent=layer end
		self.tutorialHold:Destroy();self.tutorialHold=nil
	end
	local cashShown=stage~="bare"
	local shortcuts=self.shortcuts
	local shown={Shop=stage==nil,Index=stage==nil,Upgrades=stage==nil or stage=="upgrades"}
	self.friendBoostSlot.Visible=stage==nil
	-- Each piece that comes in pops in; the first load (was == nil and stage set) does not.
	local reveal=was~=nil
	if self.cashReadout.Visible~=cashShown then
		self.cashReadout.Visible=cashShown
		if cashShown and reveal then
			self.cashRevealedAt=os.clock()
			Theme.Motion:PopScale(self.cashReadout,0.6,0.3)
		end
	end
	-- The first sale also opens card 5, so the Upgrades button waits a beat after the
	-- Coins instead of popping in with them.
	local wait=if stage=="upgrades" and self.cashRevealedAt then math.max(0,self.cashRevealedAt+1.2-os.clock()) else 0
	for page,visible in shown do
		local button=shortcuts[page]
		if button.Visible~=visible then
			local function show()
				if self.tutorialStage~=stage or button.Visible==visible then return end
				button.Visible=visible
				if visible and reveal then Theme.Motion:PopScale(button.Visual,0.6,0.3) end
			end
			if visible and page=="Upgrades" and wait>0 then task.delay(wait,show) else show() end
		end
	end
	local state=self.app.state
	if state then
		self:UpdateRebirth(state);self:UpdateUpgradesBadge(state)
		self:UpdateFreeGift(state);self:UpdateChickenOffer(state)
		if self.app.boostReadout then self.app.boostReadout:Render(state) end
	end
end

-- Shown until the free chicken is claimed; breathes to invite a tap.
function Hud:UpdateFreeGift(state)
	local gift=state.freeGift
	local shown=type(gift)=="table" and gift.enabled==true and gift.claimed~=true and not self.quiet
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
	-- Fit scaling draws the square art the same in a 1.3 x 1.3 box as in the old 1.45 x
	-- 1.3 one, and the narrower box now stays on the screen (the sunburst may not).
	visual.Icon.AnchorPoint,visual.Icon.Size,visual.Icon.Position=Vector2.new(0.5,0.5),UDim2.fromScale(1.3,1.3),UDim2.fromScale(0.5,0.4)
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
	local shown=giftDone and product~=nil and not self.quiet
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

-- October 21 game feel: a confirmed gain punches the number and flicks the coin, at
-- most once per 0.35 s (coin bursts land many shares a second) and never on a spend.
-- The icon is aspect-constrained (anchor 0,0), so it swells from its corner; keep it small.
function Hud:PopCash()
	local now=os.clock()
	if now-(self.lastPopAt or -1)<0.35 then return end
	self.lastPopAt=now
	Theme.Motion:Punch(self.money,1.1,0.28)
	Theme.Motion:PopScale(self.cashIcon,1.14,0.3)
	if Theme.Motion.reduced then return end
	self.cashIcon.Rotation=-18
	Theme.Motion:Tween(self.cashIcon,"flick",{Rotation=0},0.32,Enum.EasingStyle.Back)
end

-- The readout counts toward `value` (Quart Out) with a tick that rises in pitch across
-- the count; spends drop at once. The target is always ShownCoins, never past the
-- server's balance. seconds=0 lands at once without a tick (the first packet).
-- quiet: steady income (the Hill) counts up without a tick, unless a sale's count is
-- still running.
function Hud:CountCoins(value,seconds,quiet)
	local amount=self.money:FindFirstChild("DisplayedAmount")
	local idle=not amount or amount.Value==amount:GetAttribute("Target")
	-- A count already running keeps its start, so the pitch keeps rising as coins land.
	if idle then self.countFrom=if amount then amount.Value else value end
	self.countTo=value
	local silent:boolean=seconds==0 or (quiet==true and (idle or self.countQuiet==true))
	self.countQuiet=silent
	Theme.Motion:CountTo(self.money,value,function(v) return Theme.CompactMoney(v) end,seconds,
		{punch=false,tickGap=0.07,tick=if silent then nil else function(v) self:CoinTick(v) end})
end

function Hud:CoinTick(value)
	local from,to=self.countFrom or 0,self.countTo or 0
	local progress=if to>from then math.clamp((value-from)/(to-from),0,1) else 1
	self.app:Cue("CountTick",nil,0.9+0.25*progress,{voiceKey="CountTick",cooldown=0.06})
end

-- A "+N Coins" float over the readout for a receipt worth showing: a sale whose coins
-- are flying in, or a confirmed action result (claims, chicken sales), of at least
-- 100 Coins or 1% of the balance. Steady income ticks never float.
function Hud:QueueFloat(gain,balance,result)
	local feedback=self.app.feedback
	local flying=if feedback then feedback:CoinsInFlight() else 0
	local receipt=flying>0 or (type(result)=="table" and result.ok==true)
	if not receipt or (gain<100 and gain<balance*0.01) then return end
	self.floatPending=(self.floatPending or 0)+gain
end

-- Shown once the sale's coins have landed and the offline receipt is closed, at most
-- one every 0.6 s (several receipts in that window add up into one float).
function Hud:FlushFloat()
	local pending=self.floatPending or 0
	if pending<=0 then return end
	local feedback=self.app.feedback
	if (if feedback then feedback:CoinsInFlight() else 0)>0 or (self.heldCash or 0)>0 then return end
	if os.clock()-(self.lastFloatAt or -10)<0.6 then return end
	self.floatPending,self.lastFloatAt=0,os.clock()
	Theme.Motion:Float(self.cashReadout,"+"..Theme.CompactCoins(pending),UDim2.fromScale(0.55,0.02),
		{color=Theme.Colors.coins,size=24,rise=0.3,seconds=1.1,limit=3})
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
	self:CountCoins(shown)
	if self.lastCoins and shown>self.lastCoins then self:PopCash() end
	self.lastCoins=shown
	self:FlushFloat()
end

-- Called when the offline receipt closes: a few coins fly from the receipt (origin:
-- absolute screen point, or nil) into the coin readout with a whoosh, then the
-- balance counts up to the real total with a CashTick. Theme.Motion:Fly tweens
-- above every layer; reduced motion (or no origin) settles at once.
function Hud:ReleaseOfflineCash(receiptId,origin)
	if receiptId==nil or self.releasedReceipt==receiptId or self.releasingReceipt==receiptId then return end
	-- Keep holding through the flight; settle() lets the full balance show.
	self.releasingReceipt=receiptId
	local app=self.app
	local function settle()
		self.releasedReceipt,self.heldCash=receiptId,0
		local coins=if app.state then self:ShownCoins(app.state) else 0
		self:CountCoins(coins,1)
		self.lastCoins=coins
		self:PopCash()
		app.audio:Play("CashTick",1,{voiceKey="OfflineCash",maxVoices=2})
	end
	local gui=app.gui
	if app.reducedMotion or not origin or not gui then settle();return end
	local motion=Theme.Motion
	local target=motion:Point(gui,motion:CenterOf(self.cashIcon))
	local size=math.max(36,self.cashIcon.AbsoluteSize.X*0.7)
	local arrived=false
	app:Cue("Whoosh")
	for index=1,5 do
		-- Start in a loose cluster round the amount, then arc one after another into the coin.
		local spread=Vector2.new(math.random(-60,60),math.random(-40,40))
		task.delay((index-1)*0.06,function()
			-- A torn-down HUD or a newer receipt (its own flight settles) ends this one.
			if not app.alive or self.releasingReceipt~=receiptId then return end
			motion:Fly(gui,Theme.Assets.Coin,motion:Point(gui,origin+spread),target,{size=UDim2.fromOffset(size,size),
				seconds=0.55,arc=0.06,spin=math.random(-60,60),onArrive=function()
					motion:PopScale(self.cashIcon,1.12)
					if not arrived then arrived=true;settle() end
				end})
		end)
	end
end

-- October 20 overhaul (S9): state.upgradeTree.badges.total; hidden at zero.
function Hud:UpdateUpgradesBadge(state)
	local tree=state.upgradeTree
	local badges=type(tree)=="table" and tree.badges or nil
	local total=type(badges)=="table" and tonumber(badges.total) or 0
	self.upgradesCount.Text=if total>99 then "99+" else tostring(total)
	local previous=self.upgradesReady
	local ready=total>0 and not self.quiet -- October 23: hidden while the HUD is quiet (lessons 1-2)
	Theme.Motion:Appear(self.upgradesBadge,ready)
	-- October 21 game feel: a rise punches the count with a badge chime (its first
	-- appearance grows in through Appear); the gold ring pulses while any is ready.
	if previous and total>previous then
		if previous>0 then Theme.Motion:Punch(self.upgradesBadge,1.3,0.32) end
		self.app:Cue("Badge","Pop")
	end
	if ready~=(self.upgradesGlowing==true) then
		self.upgradesGlowing=ready
		if ready then Theme.Motion:Glow(self.upgradesGlow,A.gold,2) else Theme.Motion:StopGlow(self.upgradesGlow) end
	end
	self.upgradesReady=total
end

-- result: the packet's action result, if any (October 21: receipts float "+N Coins").
function Hud:Update(state,count,limit,capacity,selected,deployed,result)
	self:UpdateOpening(state)
	self:UpdateAutoRoll(state)
	self:UpdateTerritory(state)
	self:UpdateRebirth(state)
	self:UpdateUpgradesBadge(state)
	self:UpdateFreeGift(state)
	self:UpdateChickenOffer(state)
	-- October 16 owner request: the offline receipt's coins (already saved by the
	-- server) stays out of the displayed balance until the receipt is closed, then
	-- flies in (ReleaseOfflineCash). Display only; state.coins is untouched.
	local receipt=state.offlineCash
	self.heldCash=if type(receipt)=="table" and (tonumber(receipt.amount) or 0)>0 and receipt.id~=self.releasedReceipt
		then receipt.amount else 0
	local shown=self:ShownCoins(state)
	-- October 21 (Stevin): holding the Hill credits coins every few frames; that steady
	-- income counts up silently instead of ticking nonstop. Confirmed results still tick.
	local hill=state.hill
	local steady=type(hill)=="table" and hill.holding==true
		and not (type(result)=="table" and result.ok==true)
	-- The first packet lands at once; later ones count up with ticks.
	self:CountCoins(shown,if self.lastCoins==nil then 0 else nil,steady)
	-- Confirmed gains only (never the first packet or a purchase).
	if self.lastCoins and shown>self.lastCoins then self:PopCash() end
	self.lastCoins=shown
	local coins=state.coins or 0
	if self.lastStateCoins and coins>self.lastStateCoins then self:QueueFloat(coins-self.lastStateCoins,coins,result) end
	self.lastStateCoins=coins
	self:FlushFloat()
	local atHome=state.armyState=="Home"
	local away=state.armyState~=nil and not atHome
	if away~=self.armyAway then self.armyAway=away;self:RefreshCommands(false) end
	local armyText=(if atHome then selected else deployed).."/"..capacity
	if self.armyCount.Text~=armyText then
		self.armyCount.Text=armyText
		-- October 21 game feel: a changed count punches (not on the first packet).
		if self.lastCount then Theme.Motion:Punch(self.armyCount,1.25,0.3) end
	end
	local callUnlocked=callArmyUnlocked(state)
	if callUnlocked~=self.callUnlocked then self.callUnlocked=callUnlocked;self:UpdateArmyCommands(false) end
	self.callArmy.TextColor3=if state.armyState=="Following" then Theme.PageColors.Army else Theme.Colors.ink
	self.save.Text=if state.saveStatus=="error" then "Save unavailable · Settings" elseif state.saveStatus=="loading" then "Loading…" else ""
	self.save.TextColor3=if state.saveStatus=="error" then A.red else Theme.Colors.muted
	if state.saveStatus=="error" and self.lastSaveStatus~="error" then
		self.app:Notify(state.saveMessage or "Saving is unavailable right now. Check Settings.",false)
	end
	self.lastSaveStatus=state.saveStatus
	if self.lastCount and (count~=self.lastCount or capacity~=self.lastCapacity) then Theme.Motion:Pop(self.army.Visual,1.1) end
	self.lastCount,self.lastCapacity=count,capacity
end

return Hud
