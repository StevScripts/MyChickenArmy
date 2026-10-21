--!strict
-- Compact play HUD; menus and economy actions remain owned by AppController.
-- October 21 reference parity (docs/team/REFERENCE_PARITY_20261021.md §2.2): Drop a
-- Fruit's HUD 1:1 in our art. Left: studded plates (a wide Shop, then Rebirth | Upgrades
-- and Index | My Army). Bottom-left: the lines above the Coins pill, the pill with its
-- "+N" delta, Friend Boost. Right rail: the Free Reward gift, the ▶ offer carousel and
-- the 2x Coins card. Bottom-right: the boosts (BoostReadout). Geometry was measured on
-- the reference's 1568 x 1014 frames and is kept in each group's own units; every box is
-- Scale with a native aspect constraint, one layout for every device.
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
local BLACK,WHITE=Color3.new(0,0,0),Color3.new(1,1,1)
local GAIN=Color3.fromRGB(76,250,32) -- UIColors.Money: the reference's green "+61,722"
local SPEND=A.red
local ROBUX=utf8.char(0xE002)
local Hud={}
Hud.__index=Hud

-- Left stack in reference units (188 x 226 at 1568 px wide): Shop 188 x 60, a 13-unit
-- gap, then two rows of 90 x 72 squares 8 apart with a 9-unit gap. Call Army / My Base
-- slide out to the right of My Army. Width 0.13 of the screen (reference 0.119): the
-- extra 9% lets every phone plate reach 48 px with its PadHit below.
local STACK={W=188,H=226,width=0.13,x=0.014,y=0.51}
local PLATE_RECTS={
	Shop={0,0,188,60},
	Reenlist={0,73,90,72},Upgrades={98,73,90,72},
	Index={0,154,90,72},Army={98,154,90,72},
	CallArmy={196,154,90,72},MyBase={294,154,90,72},
}
-- Phone hit areas (844 x 390: the stack is 110 px wide, a square plate 53 x 42 px). Each
-- plate's input grows to 48 px into room no other control uses: the Shop and the Rebirth
-- row upward (the Shop's own pad never reaches down), the Index row downward.
local PLATE_PADS={Shop={1.38,1},Reenlist={1.15,1},Upgrades={1.15,1},Index={1.15,0},Army={1.15,0},CallArmy={1.15,0},MyBase={1.15,0}}
-- The reference's plate colours, from the shared palette where one matches (Index teal
-- and My Army orange have no Theme token yet).
local PLATE_COLORS={
	Shop=Theme.PageColors.Shop,Reenlist=Theme.PageColors.Index,Upgrades=Theme.ReferenceColors.Army,
	Index=Color3.fromRGB(28,201,140),Army=Color3.fromRGB(255,124,28),
	CallArmy=Color3.fromRGB(255,124,28),MyBase=Theme.ReferenceColors.Upgrades,
}
-- Three stud rows per plate face (the tile sheet is this many face heights tall).
local PLATE_STUD_SCALE=8

-- Bottom-left in reference units (229 x 83): the Coins pill 192 x 46, Friend Boost's pill
-- 192 x 27 ten units under it with its + beside it; the lines sit above the pill and the
-- "+N" delta right of it.
local CASH={W=229,H=83,width=0.1586,x=0.012,y=0.968}
local PILL_COLOR,PILL_TRANSPARENCY=Color3.fromRGB(8,9,10),0.5
local LINE_UNITS=24
local DELTA_HOLD,DELTA_FADE=0.8,0.35

-- Right rail in reference units (210 x 324), its top-right corner at x 0.9885, y 0.363.
local RAIL={W=210,H=324,width=0.134,height=0.42,x=0.9885,y=0.363}
local RAIL_RECTS={Gift={57,0,153,95},Next={8,137,27,32},Card={57,142,153,95},Coins={64,268,141,56}}
local CAROUSEL_SECONDS=6
local WOBBLE_EVERY=4

-- October 20: Call Army is free for everyone (effects.callArmy is always 1).
local function callArmyUnlocked(state)
	local effects=state and state.effects
	return effects~=nil and (effects.callArmy or 0)>=1
end

-- The reference's wallet: exact Coins with commas (2,039,714) below a billion, then compact.
local function wallet(value: number): string
	local whole=math.floor(value or 0)
	if math.abs(whole)<1e9 then return Theme.Money(whole) end
	return Theme.Number(whole)
end

local function outline(label,thickness)
	local stroke=label:FindFirstChild("TextOutline")
	if stroke and stroke:IsA("UIStroke") then stroke.Color,stroke.Thickness,stroke.Enabled=BLACK,thickness or 0.08,true end
	return label
end

-- TextWrapped first: turning it off after TextScaled switches TextScaled back off.
local function centred(label)
	label.TextXAlignment=Enum.TextXAlignment.Center
	label.TextWrapped=false
	label.TextScaled=true
	return label
end

local function unitRect(item,rect,units)
	item.Position=UDim2.fromScale(rect[1]/units[1],rect[2]/units[2])
	item.Size=UDim2.fromScale(rect[3]/units[1],rect[4]/units[2])
end

-- A red count circle with a black stroke on a plate's top-right corner.
local function badge(visual,name,text)
	local circle=Theme.Frame(visual,name,UDim2.fromScale(0.3,0.375),Color3.fromRGB(235,45,45))
	circle.AnchorPoint,circle.Position,circle.ZIndex,circle.Visible=Vector2.new(0.5,0.5),UDim2.fromScale(0.97,0.04),8,false
	Theme.Aspect(circle,1)
	Theme.Round(circle).CornerRadius=UDim.new(0.5,0)
	-- Round joins: a Miter stroke draws a square box around a circle.
	Theme.Stroke(circle,BLACK,2).LineJoinMode=Enum.LineJoinMode.Round
	local count=Theme.Label(circle,"Count",text,28,WHITE)
	count.AnchorPoint,count.Position,count.Size,count.ZIndex=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(0.8,0.8),9
	centred(count)
	return circle,count
end

-- One reference HUD plate (lift into UITheme as Theme.HudPlate): a page-colour face with
-- the stud tile at the button opacity, a darker lip and a 3 px black outline; the icon
-- overhangs the top edge by about a quarter of its height; a white stroked label sits in
-- the lower third; an optional tag (spec.tag = its name) rides the top-left corner.
-- spec: {rect={x,y,w,h}, units={W,H}, wide=boolean?, pad={padY,alignY}?, tag=string?,
-- tagColor=Color3?}. The button is the hit area (Theme.PadHit grows it on phones);
-- Visual holds the art (Face, Icon, Label) and takes hover/press from BindButton.
function Hud.Plate(parent,name,text,asset,color,callback,spec)
	local button=Instance.new("TextButton")
	button.Name,button.Text,button.AutoButtonColor,button.Selectable=name,"",false,true
	button.BackgroundTransparency,button.BorderSizePixel,button.TextTransparency=1,0,1
	unitRect(button,spec.rect,spec.units)
	button.Parent=parent
	local visual=Theme.Frame(button,"Visual",UDim2.fromScale(1,1))
	visual.AnchorPoint,visual.Position,visual.BackgroundTransparency=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),1
	Theme.Stroke(visual,BLACK,3)
	local lip=Theme.Frame(visual,"LowerLip",UDim2.fromScale(1,1),color:Lerp(BLACK,0.42))
	lip.ZIndex=1
	local face=Theme.Frame(visual,"Face",UDim2.fromScale(1,0.88),WHITE)
	face.ZIndex=2
	Theme.Gradient(face,color:Lerp(WHITE,0.2),color)
	Theme.Studs(face,0.07,28,0):SetAttribute("StudScaleHeight",PLATE_STUD_SCALE)
	local rim=Theme.Frame(face,"InsetHighlight",UDim2.fromScale(0.94,0.86))
	rim.Position,rim.BackgroundTransparency,rim.ZIndex=UDim2.fromScale(0.03,0.07),1,3
	local rimStroke=Theme.Stroke(rim,WHITE,1)
	rimStroke.Transparency=0.46
	local w,h=spec.rect[3],spec.rect[4]
	local side=if spec.wide then 66 else h*0.92
	local icon=Theme.Image(visual,"Icon",asset,UDim2.fromScale(side/w,side/h),UDim2.fromScale(0.5,if spec.wide then -0.32 else -0.2))
	icon.AnchorPoint,icon.ZIndex=Vector2.new(0.5,0),4
	Theme.Aspect(icon,1)
	local label=outline(centred(Theme.Label(visual,"Label",text,28,WHITE)))
	label.AnchorPoint,label.Position,label.ZIndex=Vector2.new(0.5,1),UDim2.fromScale(0.5,0.96),6
	label.Size=if spec.wide then UDim2.fromScale(0.7,0.36) else UDim2.fromScale(1.1,0.3)
	if spec.tag then
		local tag=Theme.Display(visual,spec.tag,"",24,spec.tagColor or A.gold)
		tag.AnchorPoint,tag.Position,tag.Size,tag.ZIndex=Vector2.new(0,0.5),UDim2.fromScale(-0.04,0.02),UDim2.fromScale(0.8,0.3),7
		tag.TextXAlignment,tag.TextWrapped=Enum.TextXAlignment.Left,false
		tag.TextScaled=true
		tag.TextFace.TextOutline.Thickness=0.08
	end
	if spec.pad then Theme.PadHit(button,1,spec.pad[1],0.5,spec.pad[2]) end
	-- After PadHit: BindButton reads the padded art's resting size.
	Theme.Motion:BindButton(button,visual,face,rimStroke)
	button.Activated:Connect(function() if button.Active then callback() end end)
	return button
end

function Hud.new(app,shell)
	local self=setmetatable({app=app,commandRest={},commandShown={}},Hud)
	-- October 21 reference parity: My Army moved into the left stack; the vacuum pill
	-- (ToolController, P6) owns the spot above the hotbar now. This empty, input-
	-- transparent frame only keeps hud.navigation for AppController's menu toggle.
	local navigation=Theme.Container(shell,"Navigation")
	navigation.AnchorPoint,navigation.Position,navigation.Size=Vector2.new(0.5,1),UDim2.new(0.5,0,1,-ToolController.BottomReserve),UDim2.fromScale(0.248,0.204)
	Theme.Aspect(navigation,558/272)
	self.navigation=navigation
	self:BuildStack(shell)
	-- October 20 (owner): no top army status line ("Marching to X", "Returning home"…).
	self.objective=Theme.Display(shell,"OpeningObjective","",21,A.gold)
	self.objective.AnchorPoint,self.objective.Position,self.objective.Size,self.objective.TextXAlignment=Vector2.new(0.5,0),UDim2.fromScale(0.5,0.035),UDim2.fromScale(0.45,0.04),Enum.TextXAlignment.Center
	self.objective.Visible=false
	self:BuildCash(shell)
	-- Later October 21 (Stevin, reference image): the coin/clover boosts
	-- (BoostReadout.luau) are a very small icon pair in the bottom-right corner.
	self.boostSlot=Theme.Container(shell,"BoostSlot")
	self.boostSlot.AnchorPoint,self.boostSlot.Position,self.boostSlot.Size=Vector2.new(1,1),BoostReadout.Position,BoostReadout.Size
	Theme.Aspect(self.boostSlot,BoostReadout.Aspect)
	self:BuildSettingsTopbar()
	self:BuildAutoRoll(shell)
	self:BuildRail(shell)
	-- Below the top-centre line, clear of the Settings corner; errors also raise a toast.
	self.save=Theme.Display(shell,"SaveStatus","",21)
	self.save.AnchorPoint,self.save.Position,self.save.Size,self.save.TextXAlignment=Vector2.new(0.5,0),UDim2.fromScale(0.5,0.08),UDim2.fromScale(0.45,0.04),Enum.TextXAlignment.Center
	self:Layout()
	self:BindBasePresence()
	local inputConnection=UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function() self:ApplyInputLayout() end)
	navigation.Destroying:Once(function() inputConnection:Disconnect() end)
	self:StartRailLoop()
	return self
end

-- The left stack (reference: Shop / Rebirth | Upgrade / Index | Fruits). The list is
-- fixed: a hidden plate (Rebirth before it unlocks, My Army during the guide) leaves
-- its slot empty, like the reference.
function Hud:BuildStack(shell)
	local app=self.app
	local shortcuts=Theme.Container(shell,"CollectionNavigation")
	shortcuts.AnchorPoint,shortcuts.Position,shortcuts.Size=Vector2.new(0,0.5),UDim2.fromScale(STACK.x,STACK.y),UDim2.fromScale(STACK.width,0.42)
	Theme.Aspect(shortcuts,STACK.W/STACK.H)
	self.shortcuts=shortcuts
	local function plate(name,text,asset,callback,tag,tagColor)
		return Hud.Plate(shortcuts,name,text,asset,PLATE_COLORS[name],callback,{rect=PLATE_RECTS[name],units={STACK.W,STACK.H},
			wide=name=="Shop",pad=PLATE_PADS[name],tag=tag,tagColor=tagColor})
	end
	plate("Shop","Shop",Theme.Assets.Shop,function() app:TogglePage("Shop") end)
	-- Rebirth: the "x3" egg Coins multiplier rides its top-left like the reference's "%100".
	self.reenlist=plate("Reenlist","Rebirth",Theme.Assets.Reenlist or Theme.Assets.ArmyHud,function()
		if app.rebirthPanel then app.rebirthPanel:Open() end
	end,"Multiplier",A.gold)
	self.reenlist.Visible=false
	self.rebirthTag=self.reenlist.Visual.Multiplier
	-- October 15 owner request: a red "!" badge whenever a Rebirth is available.
	self.rebirthBadge=badge(self.reenlist.Visual,"RebirthReady","!")
	local upgrades=plate("Upgrades","Upgrades",ResearchAssets.lab,function() app:TogglePage("Upgrades") end)
	-- October 20 overhaul (S9): a red count of the upgrades you can buy right now
	-- (server-counted, starter reserve respected); UpdateUpgradesBadge sets it.
	self.upgradesBadge,self.upgradesCount=badge(upgrades.Visual,"UpgradesReady","")
	-- October 21 game feel: one gold ring round the badge pulses while anything is
	-- affordable (its own frame: the badge's black outline keeps its stroke).
	local upgradesGlow=Theme.Frame(self.upgradesBadge,"GlowRing",UDim2.fromScale(1.32,1.32))
	upgradesGlow.AnchorPoint,upgradesGlow.Position,upgradesGlow.BackgroundTransparency,upgradesGlow.ZIndex=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),1,7
	Theme.Round(upgradesGlow).CornerRadius=UDim.new(0.5,0)
	self.upgradesGlow=upgradesGlow
	plate("Index","Index",Theme.Assets.Index,function() app:TogglePage("Index") end)
	-- My Army (the reference's Fruits slot); the green "5/5" tag is the Army count.
	self.army=plate("Army","My Army",Theme.Assets.ArmyHud or Theme.Assets.Army,function() app:TogglePage("Army") end,"ArmyCount",Theme.ReferenceColors.Army)
	self.armyIcon=self.army.Visual.Icon
	self.armyLabel=self.army.Visual.Label
	self.armyCount=self.army.Visual.ArmyCount
	-- Shown with My Army's commands outside the base or while the Army is away.
	self.callArmy=plate("CallArmy","Call Army",Theme.Assets.CallArmy or "",function()
		if callArmyUnlocked(app.state) then app:Request("CallArmy") end
	end)
	self.callUnlocked=false
	self.myBase=plate("MyBase","My Base",Theme.Assets.MyBase or "",function() app:Request("GoBase") end)
	self.commandsExpanded=false
	for _,button in {self.callArmy,self.myBase} do
		self.commandRest[button]=button.Position
		button.Visible,button.Interactable,button.Selectable=false,false,false
	end
end

-- Bottom-left (reference: event line, Coins pill with its delta, Friend Boost).
function Hud:BuildCash(shell)
	local cash=Theme.Container(shell,"CashReadout")
	cash.AnchorPoint,cash.Position,cash.Size=Vector2.new(0,1),UDim2.fromScale(CASH.x,CASH.y),UDim2.fromScale(CASH.width,0.3)
	Theme.Aspect(cash,CASH.W/CASH.H)
	self.cashReadout=cash
	-- The Coins pill: dark see-through, the gold coin, the gold number.
	local pill=Theme.Frame(cash,"CoinsPill",UDim2.fromScale(192/CASH.W,46/CASH.H),PILL_COLOR)
	pill.BackgroundTransparency=PILL_TRANSPARENCY
	self.coinsPill=pill
	self.cashIcon=Theme.Image(pill,"CashIcon",Theme.Assets.Coin,UDim2.fromScale(0.2,0.84),UDim2.fromScale(0.03,0.5))
	self.cashIcon.AnchorPoint,self.cashIcon.ZIndex=Vector2.new(0,0.5),4
	Theme.Aspect(self.cashIcon,1)
	-- October 15 owner UI Lab tweak: a gradient face; October 20 (gold Coins): gold, no "$".
	self.money=Theme.Display(pill,"Money","0",46,Color3.fromRGB(252,248,255))
	self.money.Position,self.money.Size,self.money.ZIndex=UDim2.fromScale(0.255,0.12),UDim2.fromScale(0.72,0.76),4
	self.money.TextXAlignment,self.money.TextWrapped=Enum.TextXAlignment.Left,false
	local moneyGradient=Instance.new("UIGradient")
	moneyGradient.Rotation=90
	moneyGradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,247,57)),
		ColorSequenceKeypoint.new(0.4744,Color3.fromRGB(255,214,48)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,153,0))})
	moneyGradient.Parent=self.money.TextFace
	self.money.TextFace.TextOutline.Thickness=0.08
	-- The reference's "+61,722" right of the pill (green gains, red spends): one label in
	-- a CanvasGroup so a single tween fades text, shadow and stroke together.
	local delta=Instance.new("CanvasGroup")
	delta.Name,delta.BackgroundTransparency,delta.BorderSizePixel,delta.GroupTransparency,delta.Visible="CoinsDelta",1,0,1,false
	delta.AnchorPoint,delta.Position,delta.Size,delta.ZIndex=Vector2.new(0,0.5),UDim2.fromScale(202/CASH.W,23/CASH.H),UDim2.fromScale(130/CASH.W,32/CASH.H),6
	delta.Parent=cash
	local amount=Theme.Display(delta,"Amount","",28,GAIN)
	amount.Position,amount.Size=UDim2.fromScale(0.02,0.06),UDim2.fromScale(0.96,0.84)
	amount.TextXAlignment,amount.TextWrapped=Enum.TextXAlignment.Left,false
	amount.TextFace.TextOutline.Thickness=0.1
	self.deltaGroup,self.deltaLabel=delta,amount
	-- Friend Boost row (FriendBoost.luau mounts its pill and + into it).
	self.friendBoostSlot=Theme.Container(cash,"FriendBoostSlot")
	self.friendBoostSlot.Position,self.friendBoostSlot.Size=UDim2.fromScale(0,56/CASH.H),UDim2.fromScale(1,27/CASH.H)
	-- Lines above the pill (the reference's event-timer line), bottom-up: Rebirth N or the
	-- Hill chip (they share one line: the rank hides while the chip shows), then an
	-- outpost. Left edges on the pill's, so the text lines up with the coin. A list
	-- collapses hidden lines, so whatever shows sits right above the pill. (Later October
	-- 21, Stevin: no yard "Carrying: N eggs" line.)
	local lines=Theme.Container(cash,"Lines")
	lines.AnchorPoint,lines.Position,lines.Size=Vector2.new(0,1),UDim2.fromScale(0,-0.03),UDim2.fromScale(1.5,3*LINE_UNITS/CASH.H)
	local list=Instance.new("UIListLayout")
	list.SortOrder,list.VerticalAlignment,list.Parent=Enum.SortOrder.LayoutOrder,Enum.VerticalAlignment.Bottom,lines
	self.lines=lines
	local function line(name,text,size,color,order)
		local label=Theme.Display(lines,name,text,size,color)
		label.Size,label.LayoutOrder=UDim2.fromScale(1,1/3),order
		label.TextXAlignment,label.TextWrapped=Enum.TextXAlignment.Left,false
		label.TextFace.TextOutline.Thickness=0.08
		return label
	end
	self.territory=line("TerritoryIncome","",18,A.gold,1)
	self.territory.Visible=false
	-- Rebirth rank ("Rebirth 2") just above the money; hidden at rank 0.
	self.rank=line("RebirthRank","",24,Theme.ReferenceColors.Army,4)
	self.rank.Size=UDim2.fromScale(0.66,1/3)
	self.rank.Visible=false
	-- October 20 (S19, Stevin): no Gems counter with the Coins; Gems show only in the
	-- Rebirth screen (GemUpgradeGrid's balance).
	self.hill=HillHud.new(self.app,shell,lines)
	self.hill.waiting.Size,self.hill.waiting.LayoutOrder=UDim2.fromScale(1,1/3),3
end

-- October 16 owner request: Auto Roll is a plain text button on the right; green ON,
-- red OFF, gold while it holds a chicken. October 20 (S12, S12b): shown once the Auto
-- Roll Gem Upgrade is owned; pressing it turns Auto Roll on/off; the gear beside it pops
-- out the stop list. October 21 reference parity: it sits under the offer rail, just above
-- the Gold Rush chip.
function Hud:BuildAutoRoll(shell)
	local app=self.app
	local autoRoll=Theme.Button(shell,"AutoRoll","",function()
		local auto=app.state and app.state.autoRoll
		if not auto or not auto.unlocked then return end
		app.audio:Play("Click")
		if app.autoRollMenu then app.autoRollMenu:TogglePower() end
	end,A.red)
	autoRoll.AnchorPoint,autoRoll.Position,autoRoll.Size=Vector2.new(1,1),UDim2.fromScale(0.988,0.868),UDim2.fromScale(0.15,0.075)
	autoRoll.TextColor3,autoRoll.Visible=WHITE,false
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
-- They step aside while a menu is open (the old My Army row hid with menus too).
function Hud:RefreshCommands(immediate)
	local panel=self.app.panel
	local expanded=(self.outsideBase==true or self.armyAway==true) and not (panel~=nil and panel.Visible)
	if expanded==self.commandsExpanded and not immediate then return end
	self.commandsExpanded=expanded
	self:UpdateArmyCommands(immediate)
end

-- The commands slide out from behind My Army to the right of the stack and grow in.
function Hud:UpdateArmyCommands(immediate)
	local expanded=self.commandsExpanded
	local motion=Theme.Motion
	local grew=false
	for _,button in {self.callArmy,self.myBase} do
		local shown=expanded and (button~=self.callArmy or self.callUnlocked==true)
		local rest=self.commandRest[button]
		if not shown and GuiService.SelectedObject==button then GuiService.SelectedObject=self.army end
		button.Interactable,button.Selectable=shown,shown
		if immediate then
			motion:Cancel(button,"slide")
			button.Position,button.Visible=rest,shown
		elseif shown~=self.commandShown[button] then
			motion:Appear(button,shown,0.4)
			if shown then motion:Slide(button,self.army.Position,rest,0.3,motion.Ease.Pop);grew=true end
		end
		self.commandShown[button]=shown
	end
	if grew and self.army.Visible then
		motion:PopScale(self.army.Visual,1.08,0.25)
		self.app:Cue("Whoosh",nil,1.2,{volume=0.35,voiceKey="HudCommands",cooldown=0.4})
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
	caption.TextColor3,caption.BorderSizePixel,caption.Visible=WHITE,0,false
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
	Theme.Motion:Tween(self.settingsIcon,"topbarColor",{ImageColor3=if selected then Color3.fromRGB(28,30,34) else WHITE},0.12)
end

-- Like GUI.HUD: scale-only regions, native aspect constraints and scaled text.
-- The composition is authored once; viewport changes are handled by Roblox.
function Hud:Layout()
	for _,label in {self.objective,self.money,self.territory,self.rank,self.save,self.armyCount} do
		label.TextScaled=true
	end
	Theme.Aspect(self.objective,19)
	Theme.Aspect(self.save,19)
	Theme.ScaleText(self.shortcuts)
	Theme.ScaleText(self.cashReadout)
	Theme.ScaleText(self.rail)
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
	self.cashReadout.AnchorPoint,self.cashReadout.Position=Vector2.new(0,1),UDim2.fromScale(CASH.x,CASH.y)
	-- The hit area (GEAR_PAD times the 0.04 x 0.072 circle, anchored top-right); the
	-- circle's own foot is what neighbours clear.
	self.settings.Size=UDim2.fromScale(0.04*GEAR_PAD,0.072*GEAR_PAD)
	self.settingsBottom=self.settings.Position.Y.Scale+0.072
	if self.hill then self.hill:Place() end
end

function Hud:Resize(_width, _height, _scale)
	if not self.settingsPanelBound then
		self.settingsPanelBound=true
		self.app.panel:GetPropertyChangedSignal("Visible"):Connect(function()
			self:UpdateSettingsTopbar()
			self:RefreshCommands(false)
		end)
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
	-- Plan v2 (October 20): the plate appears once the Coins reach a quarter of the
	-- next Rebirth or a rank is earned; the King no longer matters.
	local cost,coins=tonumber(quote.cost),tonumber(quote.coins) or 0
	local showIcon=quote.enabled~=false and (rank>=1 or (cost~=nil and cost>0 and coins>=cost/4))
	if self.reenlist.Visible~=showIcon then
		self.reenlist.Visible=showIcon
		-- Grow in only when it newly unlocks this session, not on the first packet.
		if showIcon and self.lastShowIcon==false then
			Theme.Motion:PopScale(self.reenlist.Visual,0.6,0.3)
			self.app:Cue("Badge","Pop")
		end
	end
	self.lastShowIcon=showIcon
	-- The current egg Coins multiplier ("x3" at Rebirth 2) on the plate's top-left.
	local multiplier=tonumber(quote.multiplierNow) or 1
	local tag=if rank>=1 and multiplier>1 then "x"..Theme.Number(multiplier) else ""
	if self.rebirthTag.Text~=tag then
		self.rebirthTag.Text=tag
		if tag~="" and self.lastRank~=nil then Theme.Motion:Punch(self.rebirthTag,1.3,0.32) end
	end
	Theme.Motion:Appear(self.rebirthBadge,showIcon and quote.eligible==true)
	-- UIScale breathing; BindButton's press tween on Visual.Size never cancels it.
	local pulse=showIcon and quote.eligible==true
	if pulse~=(self.reenlistPulse==true) then
		self.reenlistPulse=pulse
		if pulse then Theme.Motion:Breathe(self.reenlist.Visual,1.06,0.8) else Theme.Motion:StopBreathe(self.reenlist.Visual) end
	end
	self.rank.Text=RebirthPanel.Title(rank)
	-- The Hill countdown chip uses the same line.
	self.rank.Visible=rank>=1 and not (self.hill and self.hill.waitingShown)
	-- Rebirths come often now, so each new rank re-arms the "Rebirth ready" toast.
	if self.lastRank and rank>self.lastRank then Theme.Motion:PopScale(self.rank,1.15);self.rebirthToastShown=false end
	self.lastRank=rank
	if quote.eligible==true and quote.enabled~=false and not self.rebirthToastShown then
		self.rebirthToastShown=true
		local nextTitle=RebirthPanel.Title(rank+1)
		self.app:Notify("Rebirth ready: "..nextTitle.."!",true)
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

-- October 16 chicken offers (docs/team/CHICKEN_OFFERS.md) and the reference's offer rail.
local RAINBOW=ColorSequence.new({
	ColorSequenceKeypoint.new(0,Color3.fromRGB(255,72,72)),ColorSequenceKeypoint.new(0.17,Color3.fromRGB(255,170,40)),
	ColorSequenceKeypoint.new(0.33,Color3.fromRGB(255,240,60)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(70,240,110)),
	ColorSequenceKeypoint.new(0.67,Color3.fromRGB(60,190,255)),ColorSequenceKeypoint.new(0.83,Color3.fromRGB(170,100,255)),
	ColorSequenceKeypoint.new(1,Color3.fromRGB(255,72,72))})
local OFFER_RAYS="rbxassetid://90649675688974"
local ROBUX_GREEN=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(0,255,67)),
	ColorSequenceKeypoint.new(0.4744,Color3.fromRGB(105,255,91)),ColorSequenceKeypoint.new(1,Color3.fromRGB(0,223,6))})
-- The reference's offer price line: "ONLY 64" and the Robux glyph.
local function onlyPrice(robux: number): string
	return "ONLY "..Theme.Money(robux).." "..ROBUX
end

local function spin(image,seconds)
	Theme.Motion:Tween(image,"spin",{Rotation=360},seconds,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1,false)
end

-- One rail card (reference: "Free Reward!" / "x2 Luck!"): a title over the art with a
-- sunburst behind it and a short line under it (Claim! / ONLY 64). No panel behind.
function Hud:RailCard(name,title,asset,rect,callback)
	local button=Instance.new("TextButton")
	button.Name,button.Text,button.AutoButtonColor,button.Selectable=name,"",false,true
	button.BackgroundTransparency,button.BorderSizePixel,button.TextTransparency=1,0,1
	unitRect(button,rect,{RAIL.W,RAIL.H})
	button.Parent=self.rail
	local visual=Theme.Frame(button,"Visual",UDim2.fromScale(1,1))
	visual.AnchorPoint,visual.Position,visual.BackgroundTransparency=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),1
	-- Card units 153 x 95: title 0-18, art 18-78 (60 square), line 78-95.
	local rays=Theme.Image(visual,"Sunburst",Theme.Assets.Rays,UDim2.fromScale(104/153,104/95),UDim2.fromScale(0.5,48/95))
	rays.AnchorPoint,rays.ZIndex=Vector2.new(0.5,0.5),2
	Theme.Aspect(rays,1)
	local icon=Theme.Image(visual,"Icon",asset,UDim2.fromScale(60/153,60/95),UDim2.fromScale(0.5,48/95))
	icon.AnchorPoint,icon.ZIndex=Vector2.new(0.5,0.5),3
	Theme.Aspect(icon,1)
	local titleLabel=outline(centred(Theme.Label(visual,"Title",title,24,WHITE)))
	titleLabel.Position,titleLabel.Size,titleLabel.ZIndex=UDim2.fromScale(-0.05,0),UDim2.fromScale(1.1,20/95),5
	local line=outline(centred(Theme.Label(visual,"Price","",22,WHITE)))
	line.Position,line.Size,line.ZIndex=UDim2.fromScale(0,76/95),UDim2.fromScale(1,19/95),5
	Theme.Motion:BindButton(button,visual)
	button.Activated:Connect(function() if button.Active then callback() end end)
	return button
end

-- Buy a pass from the HUD the way the Shop does (CommerceController owns the prompt).
function Hud:BuyPass(key: string)
	local commerce=self.app.commerce
	if not commerce then return end
	commerce:Load(key)
	local status=commerce:State(key)
	-- Buy also answers the not-ready states: it asks for a fresh shop check or reloads.
	commerce:Buy(key)
	if status~="ready" then self.app:Notify("Getting the offer ready… try again in a moment.","info") end
end

-- Right rail (reference x 0.94): Free Reward gift on top, then the ▶ carousel (chicken
-- offer / 2x Luck), then the 2x Coins card that opens the Shop. Nothing new is on sale.
function Hud:BuildRail(shell)
	local app=self.app
	local rail=Theme.Container(shell,"OfferRail")
	rail.AnchorPoint,rail.Position,rail.Size=Vector2.new(1,0),UDim2.fromScale(RAIL.x,RAIL.y),UDim2.fromScale(RAIL.width,RAIL.height)
	Theme.Aspect(rail,RAIL.W/RAIL.H)
	self.rail=rail
	-- October 16 free gift: until the free chicken is claimed. "Free Reward!" above the
	-- gift chicken, a gold sunburst turning behind it, a green "Claim!" under it; the art
	-- wobbles every few seconds (StartRailLoop).
	local gift=self:RailCard("FreeGift","Free Reward!",FreeGiftController.Assets.Gift,RAIL_RECTS.Gift,function()
		if app.freeGift then app.freeGift:Open() end
	end)
	gift.Visible=false
	local giftRays=gift.Visual.Sunburst
	giftRays.ImageColor3,giftRays.ImageTransparency=Color3.fromRGB(255,184,0),0
	spin(giftRays,10)
	gift.Visual.Price.Text,gift.Visual.Price.TextColor3="Claim!",Theme.ReferenceColors.Army
	self.freeGift=gift
	self:BuildChickenOffer()
	-- The 2x Luck pass card in the same slot (reference "x2 Luck! ONLY 64").
	local luck=self:RailCard("LuckOffer","x2 Luck!",BoostReadout.Icons.Luck,RAIL_RECTS.Card,function() self:BuyPass("DoubleLuck") end)
	luck.Visible=false
	local luckRays=luck.Visual.Sunburst
	luckRays.ImageColor3,luckRays.ImageTransparency=WHITE,0.45
	spin(luckRays,14)
	local luckPrice=Instance.new("UIGradient")
	luckPrice.Rotation,luckPrice.Color,luckPrice.Parent=90,ROBUX_GREEN,luck.Visual.Price
	self.luckOffer=luck
	-- ▶ at the carousel's left: the next offer now (they also turn every few seconds).
	local nextButton=Instance.new("TextButton")
	nextButton.Name,nextButton.Text,nextButton.AutoButtonColor,nextButton.Selectable="NextOffer","",false,true
	nextButton.BackgroundTransparency,nextButton.BorderSizePixel,nextButton.TextTransparency=1,0,1
	nextButton:SetAttribute("ClickSound",false) -- it plays TabSwitch itself
	unitRect(nextButton,RAIL_RECTS.Next,{RAIL.W,RAIL.H})
	nextButton.Visible,nextButton.Parent=false,rail
	local arrowArt=Theme.Frame(nextButton,"Visual",UDim2.fromScale(1,1))
	arrowArt.AnchorPoint,arrowArt.Position,arrowArt.BackgroundTransparency=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),1
	local arrow=outline(centred(Theme.Label(arrowArt,"Arrow","▶",30,WHITE)),0.12)
	arrow.Size,arrow.ZIndex=UDim2.fromScale(1,1),5
	-- Phone: 14 x 16 px art; the hit area grows to 48 px, mostly away from the card.
	Theme.PadHit(nextButton,3.5,3,0.75,0.5)
	Theme.Motion:BindButton(nextButton,arrowArt)
	nextButton.Activated:Connect(function()
		app:Cue("TabSwitch","Click",nil,{voiceKey="HudCarousel",cooldown=0.15})
		self:RefreshCarousel(true)
	end)
	self.nextOffer=nextButton
	self:BuildCoinsOffer()
end

-- October 16 chicken offers: the Robux ladder, one step after another, once the free
-- chicken is claimed. Tapping opens Roblox's purchase prompt; the server checks the
-- step and grants the chicken (docs/team/CHICKEN_OFFERS.md). Rainbow sunburst, the
-- offer art, the chicken's name above, "ONLY 9" in Robux green under it.
function Hud:BuildChickenOffer()
	local app=self.app
	local button=self:RailCard("ChickenOffer","",ShopCatalog.Products.ChickenOffer1.image,RAIL_RECTS.Card,function()
		local key=self.offerKey
		if not key or not app.commerce then return end
		app.commerce:Load(key)
		if app.commerce:State(key)~="ready" then app:Notify("Getting the offer ready… try again in a moment.","info");return end
		app.commerce:Buy(key)
	end)
	button.Visible=false
	self.offer=button
	local visual=button.Visual
	-- Solid white rays (assets/chicken-ladder-20261016/sunburst-white.png) tinted by an
	-- animated rainbow gradient, both turning with TweenService.
	local rays=visual.Sunburst
	rays.Image,rays.ImageColor3,rays.ImageTransparency=OFFER_RAYS,WHITE,0.1
	rays.Size=UDim2.fromScale(140/153,140/95)
	local rainbow=Instance.new("UIGradient")
	rainbow.Name,rainbow.Color,rainbow.Parent="Rainbow",RAINBOW,rays
	spin(rays,10)
	Theme.Motion:Tween(rainbow,"hue",{Rotation=360},4,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1,false)
	-- Offer art has padding around the chicken; draw it larger than the other cards.
	visual.Icon.Size=UDim2.fromScale(80/153,80/95)
	local price=Instance.new("UIGradient")
	price.Rotation,price.Color,price.Parent=90,ROBUX_GREEN,visual.Price
end

-- The reference's wide "x10 Coin! ONLY 400" card, here the 2x Coins pass: it opens the
-- Shop (the pass's own card buys it there). A rainbow studded plate with the coin in the
-- middle, the title over it and the price under its bottom edge.
function Hud:BuildCoinsOffer()
	local app=self.app
	local button=Instance.new("TextButton")
	button.Name,button.Text,button.AutoButtonColor,button.Selectable="CoinsOffer","",false,true
	button.BackgroundTransparency,button.BorderSizePixel,button.TextTransparency=1,0,1
	unitRect(button,RAIL_RECTS.Coins,{RAIL.W,RAIL.H})
	button.Visible,button.Parent=false,self.rail
	local visual=Theme.Frame(button,"Visual",UDim2.fromScale(1,1))
	visual.AnchorPoint,visual.Position,visual.BackgroundTransparency=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),1
	-- Card units 141 x 56: the plate 0-44, the price line 40-56 over its foot.
	local face=Theme.Frame(visual,"Face",UDim2.fromScale(1,44/56),WHITE)
	face.ZIndex=2
	Theme.Stroke(face,BLACK,3)
	local rainbow=Instance.new("UIGradient")
	rainbow.Color,rainbow.Rotation,rainbow.Parent=RAINBOW,0,face
	Theme.Studs(face,0.07,28,0):SetAttribute("StudScaleHeight",PLATE_STUD_SCALE)
	local coin=Theme.CoinIcon(visual,"Icon",UDim2.fromScale(40/141,40/56),UDim2.fromScale(0.5,22/56))
	coin.AnchorPoint,coin.ZIndex=Vector2.new(0.5,0.5),4
	Theme.Aspect(coin,1)
	local title=outline(centred(Theme.Label(visual,"Title","x2 Coins!",24,WHITE)))
	title.Position,title.Size,title.ZIndex=UDim2.fromScale(0.04,8/56),UDim2.fromScale(0.92,26/56),6
	local price=outline(centred(Theme.Label(visual,"Price","",20,WHITE)))
	price.Position,price.Size,price.ZIndex=UDim2.fromScale(0.08,40/56),UDim2.fromScale(0.84,16/56),6
	local green=Instance.new("UIGradient")
	green.Rotation,green.Color,green.Parent=90,ROBUX_GREEN,price
	-- Phone: 71 x 28 px; the hit area grows to 48 px, mostly upward into the rail's gap.
	Theme.PadHit(button,1,1.7,0.5,0.8)
	Theme.Motion:BindButton(button,visual,face)
	button.Activated:Connect(function()
		if not button.Active then return end
		app:OpenPage("Shop")
	end)
	self.coinsOffer=button
end

-- Which carousel cards are on offer; `rotate` moves to the next one (▶ or the timer).
function Hud:RefreshCarousel(rotate: boolean?)
	local cards={}
	if self.offerAvailable then table.insert(cards,self.offer) end
	if self.luckAvailable then table.insert(cards,self.luckOffer) end
	local current=self.carouselCurrent
	local index=if current then table.find(cards,current) else nil
	if rotate and #cards>1 then current=cards[(index or 0)%#cards+1]
	elseif not index then current=cards[1] end
	if rotate or not self.carouselTurnedAt then self.carouselTurnedAt=os.clock() end
	local changed=current~=self.carouselCurrent
	self.carouselCurrent=current
	for _,card in {self.offer,self.luckOffer} do card.Visible=card==current end
	self.nextOffer.Visible=#cards>1
	if changed and current and self.carouselStarted then
		local motion=Theme.Motion
		motion:PopScale(current.Visual,0.7,0.28)
		if not motion.reduced then motion:Slide(current.Visual,UDim2.fromScale(0.62,0.5),UDim2.fromScale(0.5,0.5),0.28,motion.Ease.Pop) end
	end
	self.carouselStarted=true
end

-- Shown until the free chicken is claimed.
function Hud:UpdateFreeGift(state)
	local gift=state.freeGift
	local shown=type(gift)=="table" and gift.enabled==true and gift.claimed~=true
	if shown==(self.freeGiftShown==true) then return end
	self.freeGiftShown=shown
	self.freeGift.Visible=shown
	if not shown then Theme.Motion:StopWobble(self.freeGift.Visual.Icon) end
end

-- A gift waiting to be opened: three quick swings, then rest (reduced motion: still).
function Hud:WobbleGift()
	local motion=Theme.Motion
	if motion.reduced or not self.freeGift.Visible then return end
	local icon=self.freeGift.Visual.Icon
	motion:Wobble(icon,10,0.09)
	task.delay(0.55,function() if icon.Parent then motion:StopWobble(icon) end end)
end

function Hud:UpdateChickenOffer(state)
	local gift=state.freeGift
	local giftDone=type(gift)~="table" or gift.enabled~=true or gift.claimed==true
	local step=tonumber(state.chickenOfferStep) or 0
	local key=ShopCatalog.ChickenOfferOrder[step+1]
	local product=key and ShopCatalog.Products[key]
	-- The ladder still waits for the free chicken (it used to take the gift's slot).
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
		self.offer.Visual.Title.Text=product.name.."!"
		if self.app.commerce then self.app.commerce:Load(key) end
	end
	if product then
		local entry=self.app.commerce and self.app.commerce.products[key]
		local robux=if entry and type(entry.price)=="number" then entry.price else product.proposedPrice
		self.offer.Visual.Price.Text=onlyPrice(robux)
	end
	self.offerAvailable=shown
end

-- A pass card shows while the pass is on sale to this player and not owned.
function Hud:PassOffer(state,key: string): (boolean, number)
	local definition=ShopCatalog.Definitions[key]
	local commerce=self.app.commerce
	if not definition or definition.enabled==false or definition.offSale or not commerce then return false,0 end
	local shop=state.shop
	if type(shop)=="table" and type(shop.owned)=="table" and shop.owned[key] then return false,0 end
	local status=commerce:State(key)
	local shown=status~="owned" and status~="restricted" and status~="offsale" and status~="unconfigured"
	local entry=commerce.products[key]
	return shown,if entry and type(entry.price)=="number" then entry.price else definition.proposedPrice
end

function Hud:UpdateRail(state)
	if not self.passesLoaded and self.app.commerce then
		self.passesLoaded=true
		self.app.commerce:Load("DoubleLuck")
		self.app.commerce:Load("DoubleCash")
	end
	self:UpdateFreeGift(state)
	self:UpdateChickenOffer(state)
	local luck,luckPrice=self:PassOffer(state,"DoubleLuck")
	self.luckAvailable=luck
	self.luckOffer.Visual.Price.Text=onlyPrice(luckPrice)
	local coins,coinsPrice=self:PassOffer(state,"DoubleCash")
	self.coinsOffer.Visible=coins
	self.coinsOffer.Visual.Price.Text=onlyPrice(coinsPrice)
	self:RefreshCarousel(false)
end

-- One slow loop for the rail: the carousel turns every few seconds, the gift wobbles,
-- and prices that arrive between packets show up. UI Lab previews draw a still frame.
function Hud:StartRailLoop()
	local app=self.app
	if app.editPreview then return end
	task.spawn(function()
		local nextWobble,nextPrices=os.clock()+2,0
		while app.alive~=false and self.rail.Parent do
			task.wait(0.5)
			local now=os.clock()
			if now-(self.carouselTurnedAt or 0)>=CAROUSEL_SECONDS then self:RefreshCarousel(true) end
			if self.freeGiftShown and now>=nextWobble then nextWobble=now+WOBBLE_EVERY;self:WobbleGift() end
			if now>=nextPrices and app.state then nextPrices=now+2;self:UpdateRail(app.state) end
		end
	end)
end

-- October 21 game feel: a confirmed gain punches the number and flicks the coin, at
-- most once per 0.35 s (coin bursts land many shares a second) and never on a spend.
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
function Hud:CountCoins(value,seconds)
	local amount=self.money:FindFirstChild("DisplayedAmount")
	-- A count already running keeps its start, so the pitch keeps rising as coins land.
	if not amount or amount.Value==amount:GetAttribute("Target") then self.countFrom=if amount then amount.Value else value end
	self.countTo=value
	local instant=seconds==0
	Theme.Motion:CountTo(self.money,value,wallet,seconds,
		{punch=false,tickGap=0.07,tick=if instant then nil else function(v) self:CoinTick(v) end})
end

function Hud:CoinTick(value)
	local from,to=self.countFrom or 0,self.countTo or 0
	local progress=if to>from then math.clamp((value-from)/(to-from),0,1) else 1
	self.app:Cue("CountTick",nil,0.9+0.25*progress,{voiceKey="CountTick",cooldown=0.06})
end

-- The reference's delta right of the Coins pill: green "+N" on gains, red "-N" on
-- spends. It pops in, holds DELTA_HOLD seconds and fades; a same-sign change while it
-- shows adds up (the vacuum's stream reads "+60,710"). Reduced motion shows, then hides.
function Hud:ShowDelta(amount: number)
	if amount==0 or amount~=amount then return end
	local sign=if amount>0 then 1 else -1
	local now=os.clock()
	if self.deltaSign==sign and now<(self.deltaUntil or 0) then self.deltaAmount=(self.deltaAmount or 0)+amount else self.deltaAmount=amount end
	self.deltaSign=sign
	self.deltaUntil=now+DELTA_HOLD+DELTA_FADE
	self.deltaSerial=(self.deltaSerial or 0)+1
	local serial=self.deltaSerial
	local group,label=self.deltaGroup,self.deltaLabel
	label.Text=(if sign>0 then "+" else "-")..wallet(math.abs(self.deltaAmount or 0))
	label.TextColor3=if sign>0 then GAIN else SPEND
	local motion=Theme.Motion
	motion:Cancel(group,"delta-fade")
	group.GroupTransparency,group.Visible=0,true
	motion:PopScale(group,0.6,0.22)
	task.delay(DELTA_HOLD,function()
		if self.deltaSerial~=serial or not group.Parent then return end
		if motion.reduced then group.GroupTransparency,group.Visible=1,false;return end
		motion:Tween(group,"delta-fade",{GroupTransparency=1},DELTA_FADE,Enum.EasingStyle.Quad,Enum.EasingDirection.In,function()
			if self.deltaSerial==serial then group.Visible=false end
		end)
	end)
end

-- A receipt worth showing: a sale whose coins are flying in, or a confirmed action
-- result (claims, chicken sales), of at least 100 Coins or 1% of the balance. Steady
-- income ticks never show. Kept as the one entry point other screens feed (P6).
function Hud:QueueFloat(gain,balance,result)
	local feedback=self.app.feedback
	local flying=if feedback then feedback:CoinsInFlight() else 0
	local receipt=flying>0 or (type(result)=="table" and result.ok==true)
	if not receipt or (gain<100 and gain<balance*0.01) then return end
	self.floatPending=(self.floatPending or 0)+gain
end

-- Shown once the sale's coins have landed and the offline receipt is closed, at most
-- one every 0.6 s (several receipts in that window add up into one delta).
function Hud:FlushFloat()
	local pending=self.floatPending or 0
	if pending<=0 then return end
	local feedback=self.app.feedback
	if (if feedback then feedback:CoinsInFlight() else 0)>0 or (self.heldCash or 0)>0 then return end
	if os.clock()-(self.lastFloatAt or -10)<0.6 then return end
	self.floatPending,self.lastFloatAt=0,os.clock()
	self:ShowDelta(pending)
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
	Theme.Motion:Appear(self.upgradesBadge,total>0)
	-- October 21 game feel: a rise punches the count with a badge chime (its first
	-- appearance grows in through Appear); the gold ring pulses while any is ready.
	if previous and total>previous then
		if previous>0 then Theme.Motion:Punch(self.upgradesBadge,1.3,0.32) end
		self.app:Cue("Badge","Pop")
	end
	if (total>0)~=(self.upgradesGlowing==true) then
		self.upgradesGlowing=total>0
		if total>0 then Theme.Motion:Glow(self.upgradesGlow,A.gold,2) else Theme.Motion:StopGlow(self.upgradesGlow) end
	end
	self.upgradesReady=total
end

-- result: the packet's action result, if any (October 21: receipts show the "+N" delta).
function Hud:Update(state,count,limit,capacity,selected,deployed,result)
	local previousRank=self.lastRank
	self:UpdateOpening(state)
	self:UpdateAutoRoll(state)
	self:UpdateTerritory(state)
	self:UpdateRebirth(state)
	self:UpdateUpgradesBadge(state)
	self:UpdateRail(state)
	-- October 16 owner request: the offline receipt's coins (already saved by the
	-- server) stays out of the displayed balance until the receipt is closed, then
	-- flies in (ReleaseOfflineCash). Display only; state.coins is untouched.
	local receipt=state.offlineCash
	self.heldCash=if type(receipt)=="table" and (tonumber(receipt.amount) or 0)>0 and receipt.id~=self.releasedReceipt
		then receipt.amount else 0
	local shown=self:ShownCoins(state)
	-- The first packet lands at once; later ones count up with ticks.
	self:CountCoins(shown,if self.lastCoins==nil then 0 else nil)
	-- Confirmed gains only (never the first packet or a purchase).
	if self.lastCoins and shown>self.lastCoins then self:PopCash() end
	self.lastCoins=shown
	local coins=state.coins or 0
	local before=self.lastStateCoins
	if before then
		local change=coins-before
		if change>0 then self:QueueFloat(change,coins,result)
		elseif change<0 then
			-- Spends of 100 Coins or 1% of the balance show red; a Rebirth's reset to zero
			-- has its own celebration instead.
			local rebirthed=previousRank~=nil and (self.lastRank or 0)>previousRank
			if not rebirthed and (-change>=100 or -change>=before*0.01) then self:ShowDelta(change) end
		end
	end
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
	-- The Call Army plate glows green while the Army follows you.
	local following=state.armyState=="Following"
	if following~=(self.callGlowing==true) then
		self.callGlowing=following
		if following then Theme.Motion:Glow(self.callArmy.Visual,Theme.ReferenceColors.Army,3) else Theme.Motion:StopGlow(self.callArmy.Visual) end
	end
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
