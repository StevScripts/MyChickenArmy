--!strict
-- October 20 boosts readout (S16, docs/team/PLAYTIME_REWARDS.md): the reference's coin
-- "x9.2" and clover "x4.5", showing the player's total Coins and Luck multipliers.
-- October 21 (Stevin): moved from the top-right to one row under Friend Boost, then
-- (later October 21, his reference image) to a very small pair of icons in the
-- bottom-right corner (HudController's BoostSlot). The server computes both totals
-- (state.boosts, PlaytimeService.Boosts); this module only presents. Stevin, October 20,
-- approved one addition to the reference: while a Playtime Rewards boost runs, its number
-- turns green with the time left over its icon.
-- October 21 reference parity (docs/team/REFERENCE_PARITY_20261021.md §2.2): the number
-- sits under its icon like the reference's "x9.2", and hovering an icon (a tap on touch,
-- selection on a gamepad) opens the reference's breakdown list above the pair: what
-- makes up the total, active parts gold, idle parts grey. The rows only restate values
-- the client already has (state, effects, the Gold Rush window, the Friend Boost
-- attribute); nothing new is computed by the server for it.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Theme=require(script.Parent.UITheme)
local Shared=ReplicatedStorage.PetRoll.Shared
local Config=require(Shared.Config)
local PlaytimeRewards=require(Shared.PlaytimeRewards)
local Rules=require(Shared.Rules)
local UpgradeCatalog=require(Shared.UpgradeCatalog)
local Readout={}
Readout.__index=Readout

-- The coin and the clover (the Luck upgrade's art, assets/upgrade-icons-20261020).
Readout.Icons={Coins=Theme.Assets.Coin,Luck="rbxassetid://136683191941433"}
local KEYS={Coins="coins",Luck="luck"}
local GREEN=Theme.ReferenceColors.Army
local WHITE=Color3.new(1,1,1)
local ACTIVE=Theme.Colors.coins -- the reference's gold "Upgrades: x6"
local IDLE=Color3.fromRGB(196,203,210) -- its grey "+0" rows
-- October 21 game feel: a running boost's column glows in its own colour.
local GLOW={Coins=Theme.Colors.coins,Luck=GREEN}
-- The bottom-right corner, very small: two square icons with a gap between them.
-- HudController's BoostSlot uses these too; without it (UI Lab story) the readout
-- places itself on the HUD layer.
local COLUMN_GAP=0.15 -- of one icon's width
Readout.Aspect=2+COLUMN_GAP
Readout.Position=UDim2.fromScale(0.988,0.98)
Readout.Size=UDim2.fromScale(0.2,0.055)
-- The breakdown: 0.15 of the screen wide, right-aligned with the pair, just above it
-- (the pair's top is Position.Y - Size.Y: the slot is always height-limited). Rows are
-- a tenth of the panel's width tall, with a small margin top and bottom.
local PANEL_WIDTH,ROW,MARGIN=0.15,0.1,0.03
local PANEL_TOP_GAP=0.01
local PIN_SECONDS=5

local function clock(seconds: number): string
	seconds=math.max(0,math.ceil(seconds))
	return string.format("%d:%02d",seconds//60,seconds%60)
end

local function percent(value: number): string
	return "+"..math.floor(value*100+0.5).."%"
end

local function goldRushActive(): boolean
	local folder=ReplicatedStorage:FindFirstChild("PetRoll")
	if not folder then return false end
	local startsAt,endsAt=folder:GetAttribute("GoldRushStartsAt"),folder:GetAttribute("GoldRushEndsAt")
	if type(startsAt)~="number" or type(endsAt)~="number" then return false end
	local now=workspace:GetServerTimeNow()
	return now>=startsAt and now<endsAt
end

local function friendBoost(): number
	local player=Players.LocalPlayer
	return if player then tonumber(player:GetAttribute("FriendBoost")) or 0 else 0
end

-- The rows behind one total, as {text, active}. Coins = Egg Value tier (with its tree
-- bonus) x Rebirth x Coin Boost x 2x Coins x Gold Rush x Friend Boost x held camps x a
-- Playtime boost; Luck = Luck tier x 2x Luck x Extra Luck x a Playtime boost (the
-- factors PlaytimeService.Boosts multiplies).
function Readout.Rows(kind: string, state): {{any}}
	local effects=if type(state.effects)=="table" then state.effects else {}
	local shop=if type(state.shop)=="table" then state.shop else {}
	local owned=if type(shop.owned)=="table" then shop.owned else {}
	local boosts=if type(state.boosts)=="table" then state.boosts else {}
	local running=if type(boosts.running)=="table" then boosts.running else {}
	local rows={}
	local function add(name: string, value: string, active: boolean) table.insert(rows,{name..": "..value,active}) end
	local playtime=running[kind]
	local play=if type(playtime)=="table" then tonumber(playtime.bonus) or 0 else 0
	if kind=="Coins" then
		local tier=UpgradeCatalog.EggValueMultiplier(tonumber(state.incomeLevel) or 0)/math.max(1e-9,UpgradeCatalog.EggValueMultiplier(0))
			*(1+(tonumber(effects.eggValue) or 0))
		add("Upgrades",PlaytimeRewards.Times(tier),tier>1.001)
		local rebirth=if type(state.rebirth)=="table" then tonumber(state.rebirth.multiplierNow) or 1 else 1
		add("Rebirth",PlaytimeRewards.Times(rebirth),rebirth>1.001)
		local coinBoost=tonumber(effects.coinBoost) or 0
		add("Coin Boost",percent(coinBoost),coinBoost>0)
		add("2x Coins",if owned.DoubleCash then "x2" else "x1",owned.DoubleCash==true)
		local rush=goldRushActive()
		add("Gold Rush",if rush then PlaytimeRewards.Times(Config.GoldRush.CoinMultiplier) else "x1",rush)
		local friends=friendBoost()
		add("Friend Boost",percent(friends),friends>0)
		local camps=tonumber(state.territoryBonus) or 0
		add("Camps held",percent(camps),camps>0)
		add("Playtime",percent(play),play>0)
	else
		local tier=Rules.LuckMultiplier(tonumber(state.luck) or 0)
		add("Upgrades",PlaytimeRewards.Times(tier),tier>1.001)
		local extra=tonumber(effects.rollingLuck) or 0
		add("Extra Luck",percent(extra),extra>0)
		add("2x Luck",if owned.DoubleLuck then "x2" else "x1",owned.DoubleLuck==true)
		add("Playtime",percent(play),play>0)
	end
	return rows
end

function Readout.new(app)
	local self=setmetatable({app=app,connections={},columns={},nextStepAt=0,hovered=nil,pinned=nil,shownKind=nil},Readout)
	local slot=app.hud and app.hud.boostSlot
	local root=Theme.Container(slot or app.hudLayer,"BoostReadout")
	if not slot then
		root.AnchorPoint,root.Position,root.Size=Vector2.new(1,1),Readout.Position,Readout.Size
		Theme.Aspect(root,Readout.Aspect)
	end
	root.Visible=false
	self.root=root
	for index,kind in PlaytimeRewards.BoostKinds do
		local column=Theme.Container(root,kind)
		column.Position=UDim2.fromScale((index-1)*(1+COLUMN_GAP)/Readout.Aspect,0)
		column.Size=UDim2.fromScale(1/Readout.Aspect,1)
		Theme.Image(column,"Icon",Readout.Icons[kind],UDim2.fromScale(1,1))
		-- The number under its icon, over the icon's foot (reference "x9.2").
		local value=Theme.Display(column,"Value","x1",30,WHITE)
		value.AnchorPoint,value.Position,value.Size=Vector2.new(0.5,1),UDim2.fromScale(0.5,1.1),UDim2.fromScale(1.3,0.44)
		value.ZIndex=5
		value.TextXAlignment,value.TextWrapped=Enum.TextXAlignment.Center,false
		value.TextFace.TextOutline.Thickness=0.1
		-- A running Playtime boost's time left sits over the icon.
		local timer=Theme.Display(column,"Timer","",20,GREEN)
		timer.AnchorPoint,timer.Position,timer.Size=Vector2.new(0.5,1),UDim2.fromScale(0.5,0.02),UDim2.fromScale(1.3,0.38)
		timer.ZIndex,timer.Visible=5,false
		timer.TextXAlignment,timer.TextWrapped=Enum.TextXAlignment.Center,false
		self.columns[kind]={root=column,value=value,timer=timer,endsAt=nil,last=nil,glowing=false}
	end
	self:BuildBreakdown(slot)
	Theme.ScaleText(root)
	-- UI Lab previews draw one still frame (Render steps once).
	if not app.editPreview then
		table.insert(self.connections,RunService.Heartbeat:Connect(function() self:Step() end))
	end
	return self
end

-- The hover/tap breakdown above the pair, and the input area that opens it.
function Readout:BuildBreakdown(slot)
	local panel=Theme.Frame(if slot and slot.Parent then slot.Parent else self.app.hudLayer,"BoostBreakdown",UDim2.fromScale(PANEL_WIDTH,0.6),Theme.OverlayColors.Top)
	panel.AnchorPoint=Vector2.new(1,1)
	panel.Position=UDim2.fromScale(Readout.Position.X.Scale,Readout.Position.Y.Scale-Readout.Size.Y.Scale-PANEL_TOP_GAP)
	panel.BackgroundTransparency,panel.ZIndex,panel.Visible,panel.Active=0.3,15,false,false
	self.panel,self.rows=panel,{}
	-- One input area over both icons: the half under the pointer picks Coins or Luck.
	-- Phone: the pair is 46 x 21 px; the area grows to 60 x 46 px, mostly up and right
	-- (the Gold Rush chip sits to the left, the screen's edge to the right).
	local hit=Instance.new("TextButton")
	hit.Name,hit.Text,hit.AutoButtonColor,hit.Selectable="BreakdownHit","",false,true
	hit.BackgroundTransparency,hit.BorderSizePixel,hit.TextTransparency=1,0,1
	hit.Size,hit.ZIndex,hit.Parent=UDim2.fromScale(1,1),6,self.root
	Theme.PadHit(hit,1.3,2.2,0.2,0.7)
	local function touch(): boolean return UserInputService:GetLastInputType()==Enum.UserInputType.Touch end
	local function kindAt(x: number): string
		local root=self.root
		return if x<root.AbsolutePosition.X+root.AbsoluteSize.X/2 then "Coins" else "Luck"
	end
	table.insert(self.connections,hit.MouseEnter:Connect(function(x) if not touch() then self:Hover(kindAt(x)) end end))
	table.insert(self.connections,hit.MouseMoved:Connect(function(x) if not touch() then self:Hover(kindAt(x)) end end))
	table.insert(self.connections,hit.MouseLeave:Connect(function() self:Hover(nil) end))
	table.insert(self.connections,hit.SelectionGained:Connect(function() self:Hover("Coins") end))
	table.insert(self.connections,hit.SelectionLost:Connect(function() self:Hover(nil) end))
	-- Touch (no hover): a tap toggles that half's list; it closes itself after a while.
	table.insert(self.connections,hit.InputBegan:Connect(function(input)
		if input.UserInputType~=Enum.UserInputType.Touch then return end
		local kind=kindAt(input.Position.X)
		self.pinned=if self.pinned==kind then nil else kind
		self.pinnedUntil=os.clock()+PIN_SECONDS
		if self.pinned then self.app.audio:Play("Click") end
		self:ShowBreakdown()
	end))
	-- A gamepad's A on the pair swaps between the two lists.
	table.insert(self.connections,hit.Activated:Connect(function()
		if not string.find(UserInputService:GetLastInputType().Name,"Gamepad") or not self.hovered then return end
		self:Hover(if self.hovered=="Coins" then "Luck" else "Coins")
	end))
	self.hit=hit
end

function Readout:Hover(kind: string?)
	if kind==self.hovered then return end
	self.hovered=kind
	self:ShowBreakdown()
end

-- Which list shows: a pinned tap wins, else the hovered half.
function Readout:ShowBreakdown()
	local kind=self.pinned or self.hovered
	if not self.root.Visible then kind=nil end
	local changed=kind~=self.shownKind
	self.shownKind=kind
	if kind then self:FillBreakdown(kind) end
	if changed then
		Theme.Motion:Appear(self.panel,kind~=nil,0.85)
		if kind then Theme.Motion:Punch(self.columns[kind].value,1.15,0.22) end
	end
end

-- Rows for `kind`: a white title, then one row per factor. The panel's aspect follows
-- its row count, so it always fits its list exactly (Scale only).
function Readout:FillBreakdown(kind: string)
	local state=self.app.state or self.state
	if not state then return end
	local rows=Readout.Rows(kind,state)
	local count=#rows+1
	local height=ROW*count+MARGIN*2
	Theme.Aspect(self.panel,1/height)
	local function row(index: number): TextLabel
		local label=self.rows[index]
		if not label then
			label=Theme.Label(self.panel,"Row"..index,"",22,WHITE)
			label.TextWrapped,label.ZIndex=false,16
			label.TextScaled=true
			label.TextOutline.Thickness=0.1
			self.rows[index]=label
			Theme.ScaleText(label)
		end
		label.Position=UDim2.fromScale(0.05,(MARGIN+ROW*(index-1)+ROW*0.08)/height)
		label.Size=UDim2.fromScale(0.92,ROW*0.84/height)
		label.Visible=true
		return label
	end
	local title=row(1)
	title.Text,title.TextColor3=kind,WHITE
	for index,entry in rows do
		local label=row(index+1)
		label.Text=entry[1]
		label.TextColor3=if entry[2] then ACTIVE else IDLE
	end
	for index=count+1,#self.rows do self.rows[index].Visible=false end
end

function Readout:Render(state)
	self.state=state
	local boosts=state and state.boosts
	if type(boosts)~="table" then self.root.Visible=false;self:ShowBreakdown();return end
	self.root.Visible=true
	local running=type(boosts.running)=="table" and boosts.running or {}
	for kind,column in self.columns do
		local total=tonumber(boosts[KEYS[kind]]) or 1
		column.value.Text=PlaytimeRewards.Times(total)
		local boost=running[kind]
		column.endsAt=if type(boost)=="table" then tonumber(boost.endsAt) else nil
		-- A confirmed rise (a boost, a friend, a Gold Rush, an upgrade) pops the number.
		if column.last and total>column.last*1.001 then Theme.Motion:Punch(column.value,1.25,0.3) end
		column.last=total
	end
	if self.shownKind then self:FillBreakdown(self.shownKind) end
	self:Step(true)
end

-- The time left under a running boost; four times a second is plenty for m:ss.
function Readout:Step(force: boolean?)
	local now=os.clock()
	if not force and now<self.nextStepAt then return end
	self.nextStepAt=now+0.25
	local serverNow=workspace:GetServerTimeNow()
	for kind,column in self.columns do
		local left=if column.endsAt then column.endsAt-serverNow else 0
		local shown=left>0
		column.timer.Visible=shown
		if shown then column.timer.Text=clock(left) end
		local color=if shown then GREEN else WHITE
		if column.value.TextColor3~=color then column.value.TextColor3=color end
		-- One glow while the boost runs; nothing loops once it ends.
		if shown~=column.glowing then
			column.glowing=shown
			if shown then Theme.Motion:Glow(column.root,GLOW[kind] or WHITE,2) else Theme.Motion:StopGlow(column.root) end
		end
	end
	-- A pinned list closes itself; an open one follows live parts (Gold Rush, friends).
	if self.pinned and now>=(self.pinnedUntil or 0) then self.pinned=nil;self:ShowBreakdown() end
	if self.shownKind then self:FillBreakdown(self.shownKind) end
end

function Readout:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if self.panel then self.panel:Destroy();self.panel=nil end
	if self.root then self.root:Destroy();self.root=nil end
end

return Readout
