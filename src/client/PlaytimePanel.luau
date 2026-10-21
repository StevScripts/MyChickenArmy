--!strict
-- October 20 Playtime Rewards (S16, docs/team/PLAYTIME_REWARDS.md), copied 1:1 from
-- Stevin's Drop a Fruit recording in the game's style:
-- - a round dark gift button right after Roblox's own top-bar buttons, with a red
--   count of rewards ready to claim;
-- - a "Free Reward Ready!" corner notice (CornerNotice) when one unlocks;
-- - the Playtime Rewards window: a purple studded header and twelve tiles that count
--   down ("05:04"), then say "Claim!", then show a check once claimed.
-- The server owns the clock, the claims and every payout (PlaytimeService); this
-- module draws state.playtime and sends ClaimPlaytime {index}.
local GuiService=game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Theme=require(script.Parent.UITheme)
local MenuLayout=require(script.Parent.MenuLayout)
local ShopArt=require(script.Parent.ShopPreviewArt)
local PlaytimeRewards=require(game:GetService("ReplicatedStorage").PetRoll.Shared.PlaytimeRewards)
local Panel={}
Panel.__index=Panel

-- The green gift box (assets/free-gift-20261016), the Luck clover
-- (assets/upgrade-icons-20261020) and the Daily reward's Free Roll art.
Panel.Gift="rbxassetid://85740083144452"
Panel.Clover="rbxassetid://136683191941433"
Panel.Rolls=Theme.Assets.Luck
-- Top-bar slot after Roblox's buttons. A later Quests button takes slot 0 (the
-- reference shows its calendar first) and moves the gift to slot 1.
Panel.Slot=0
local TILE_COLORS={
	Blue=Color3.fromRGB(52,186,255), Green=Color3.fromRGB(86,214,58),
	Pink=Color3.fromRGB(255,92,152), Gold=Color3.fromRGB(255,184,38),
}
local HEADER=Color3.fromRGB(168,75,219) -- the reference's purple (UIColors.Upgrade)
local CLAIM=Theme.ReferenceColors.Army
local WHITE=Color3.new(1,1,1)
local BADGE=Color3.fromRGB(235,45,45)
local TOPBAR=Color3.fromRGB(18,19,22) -- like the Settings gear
local NOTICE_BODY="Open the gift at the top to claim it!"
-- Studio may author MenuLayouts.PlaytimeRewards; otherwise this native Scale frame.
local LAYOUT_NAME="PlaytimeRewards"
local PANEL_SIZE,PANEL_ASPECT=UDim2.fromScale(0.46,0.82),1.25
-- Four columns and three rows of square tiles, 8% of a tile apart.
local GAP=0.08
local GRID_ASPECT=(4+3*GAP)/(3+2*GAP)
local TILE_W,TILE_H=1/(4+3*GAP),1/(3+2*GAP)
local STEP_X,STEP_Y=(1+GAP)/(4+3*GAP),(1+GAP)/(3+2*GAP)
-- October 21 game feel (docs/team/GAME_FEEL_20261021.md): an authored cue, or its
-- fallback until the sound session adds it (UI Lab previews stub audio without Has).
-- Presentation only; one client audio.
local Audio=nil
local function cue(name,fallback,pitch,options)
	if not Audio then return end
	if type(Audio.Has)=="function" and Audio:Has(name) then Audio:Play(name,pitch,options)
	elseif fallback then Audio:Play(fallback,pitch,options) end
end

function Panel.new(app)
	local self=setmetatable({app=app,connections={},windowConnections={},alive=true,seen={},primed=false,
		pendingUntil=0,ready=0,nextStepAt=0,attention=false},Panel)
	Audio=app.audio
	if not app.editPreview then
		self:BuildButton()
		table.insert(self.connections,RunService.Heartbeat:Connect(function() self:Step() end))
	end
	return self
end

-- Each tile's picture: the coin, the clover for Luck, the coin for a Coins boost
-- (as in the reference) and the Free Roll art.
function Panel.Icon(tile: PlaytimeRewards.Tile): string
	if tile.kind=="Rolls" then return Panel.Rolls end
	if tile.kind=="Boost" and tile.boost=="Luck" then return Panel.Clover end
	return Theme.Assets.Coin
end

-- The circle copies Roblox's own buttons: 0.76 of the top bar's height, resting on the
-- bar's bottom edge like them (centring it sat ~7 px too high), one slot = 1.19
-- diameters (S17 agreed the same rule for Quests). It keeps the gap Roblox leaves
-- between its own buttons (~0.2 diameters; the inset already starts 2-3 px past the
-- Roblox menu), so it no longer touches it.
function Panel:BuildButton()
	local app=self.app
	local bar=Theme.InsetContainer(app.hudLayer,"PlaytimeTopbar",Enum.ScreenInsets.TopbarSafeInsets)
	bar.ZIndex,bar.Visible=30,false
	local button=Instance.new("TextButton")
	button.Name,button.Text,button.AutoButtonColor,button.Selectable="PlaytimeRewards","",false,true
	button.AnchorPoint,button.Size=Vector2.new(0,1),UDim2.fromScale(1,0.76)
	button.BackgroundColor3,button.BackgroundTransparency,button.BorderSizePixel=TOPBAR,0.1,0
	button.ZIndex,button.Parent=31,bar
	Theme.Aspect(button,1)
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(1,0);corner.Parent=button
	local icon=Theme.Image(button,"Gift",Panel.Gift,UDim2.fromScale(0.74,0.74),UDim2.fromScale(0.5,0.5))
	icon.AnchorPoint,icon.ZIndex=Vector2.new(0.5,0.5),32
	-- The game's red count badge (the reference's is white) on the top-right corner.
	local badge=Theme.Frame(button,"Ready",UDim2.fromScale(0.48,0.48),BADGE)
	badge.AnchorPoint,badge.Position,badge.ZIndex,badge.Visible=Vector2.new(0.5,0.5),UDim2.fromScale(0.88,0.12),33,false
	Theme.Aspect(badge,1)
	Theme.Round(badge).CornerRadius=UDim.new(0.5,0)
	Theme.Stroke(badge,Color3.new(0,0,0),2).LineJoinMode=Enum.LineJoinMode.Round
	local count=Theme.Label(badge,"Count","",28,WHITE)
	count.AnchorPoint,count.Position,count.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(0.8,0.8)
	count.TextScaled,count.ZIndex,count.TextXAlignment=true,34,Enum.TextXAlignment.Center
	Theme.Motion:BindButton(button,icon)
	button.Activated:Connect(function() self:Toggle() end)
	local function place()
		local diameter=bar.AbsoluteSize.Y*0.76
		button.Position=UDim2.new(0,diameter*(0.16+Panel.Slot*1.19),1,0)
	end
	table.insert(self.connections,bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))
	place()
	-- Hidden with Roblox's own menu, like the Settings gear.
	local function sync() bar.Visible=self.shown==true and app.gui.Enabled and not GuiService.MenuIsOpen end
	table.insert(self.connections,GuiService:GetPropertyChangedSignal("MenuIsOpen"):Connect(sync))
	table.insert(self.connections,app.gui:GetPropertyChangedSignal("Enabled"):Connect(sync))
	self.bar,self.button,self.badge,self.count,self.icon,self.syncBar=bar,button,badge,count,icon,sync
end

-- While a reward waits, the gift wobbles inside a gold ring; Settle squares it.
function Panel:Attention(on: boolean)
	if on==self.attention or not self.button then return end
	self.attention=on
	if on then
		Theme.Motion:Wobble(self.icon,6,0.35)
		Theme.Motion:Glow(self.button,Theme.ReferenceColors.Base,3)
	else
		Theme.Motion:StopWobble(self.icon)
		Theme.Motion:StopGlow(self.button)
	end
end

function Panel:Render(state, result)
	local playtime=state and state.playtime
	if type(playtime)~="table" or type(playtime.tiles)~="table" then playtime=nil end
	-- A new visit clock (a new-player test resets it) re-arms every notice.
	local startedAt=playtime and playtime.startedAt
	if startedAt~=self.startedAt then self.startedAt,self.primed=startedAt,false;table.clear(self.seen) end
	self.playtime=playtime
	local shown=playtime~=nil and playtime.enabled==true
	if shown~=self.shown then
		self.shown=shown
		if self.syncBar then self.syncBar() end
		if not shown then self:Dismiss(true);self:Attention(false) end
	end
	if result and result.action=="ClaimPlaytime" then self:Claimed(result) end
	if self.gui then self:RefreshTiles() end
	self:Step(true)
end

-- Ready tiles: the badge, the corner notice when one unlocks, and the open window's
-- timers. Four times a second is plenty for the reference's mm:ss.
function Panel:Step(force: boolean?)
	local clock=os.clock()
	if not force and clock<self.nextStepAt then return end
	self.nextStepAt=clock+0.25
	local playtime=self.playtime
	if not playtime then return end
	local now=workspace:GetServerTimeNow()
	local ready=0
	for index,data in playtime.tiles do
		local open=data.claimed~=true and type(data.unlockAt)=="number" and now>=data.unlockAt
		if open then
			ready+=1
			if not self.seen[index] then
				self.seen[index]=true
				-- Tiles already ready on the first look were announced before.
				if self.primed then self:Announce(index) end
			end
		end
	end
	self.primed=true
	self:SetBadge(ready)
	if self.gui then
		for index,view in self.views or {} do
			local data=playtime.tiles[index]
			if data then self:RefreshStatus(view,data,now) end
		end
	end
end

function Panel:SetBadge(ready: number)
	local previous=self.ready
	self.ready=ready
	if not self.badge then return end
	self.count.Text=tostring(ready)
	Theme.Motion:Appear(self.badge,ready>0)
	if ready>previous and previous>0 then Theme.Motion:Punch(self.badge,1.3,0.3) end
	self:Attention(ready>0 and self.shown==true)
end

-- "Free Reward Ready!" with the reward's own icon, like the reference.
function Panel:Announce(index: number)
	local tile=PlaytimeRewards.Tiles[index]
	if not tile then return end
	local app=self.app
	if app.cornerNotice then
		app.cornerNotice:Show({title="Free Reward Ready!",body=NOTICE_BODY,icon=Panel.Icon(tile),tag="New!"})
	else
		app:Notify("Free Reward Ready! "..NOTICE_BODY,true)
	end
end

function Panel:Toggle()
	if self.gui and not self.closing then self:Close() else self:Open() end
end

function Panel:Close()
	if not self.gui or self.closing then return end
	-- Same voice key as the close button's own Click, so the two never double.
	cue("MenuClose","Click")
	self:Dismiss()
end

function Panel:Dismiss(immediate: boolean?)
	local gui,panel=self.gui,self.panel
	if not gui or (self.closing and not immediate) then return end
	self.closing=true
	ContextActionService:UnbindAction("PetRollPlaytimeClose")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject=if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	for _,connection in self.windowConnections do connection:Disconnect() end
	table.clear(self.windowConnections)
	self.app:SetMenuBlur("playtime",false)
	-- The claimable tiles' rings stop before the window leaves.
	for _,view in self.views or {} do Theme.Motion:StopGlow(view.button) end
	local function finish()
		if self.gui~=gui then return end
		self.gui,self.panel,self.views,self.closing=nil,nil,nil,false
		gui:Destroy()
	end
	if immediate or not panel then finish();return end
	-- Leaves the way it came in: up and away.
	Theme.Motion:Tween(panel,"playtime-slide",{Position=self.restingPosition-UDim2.fromScale(0,0.12)},0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	Theme.Motion:Tween(panel,"playtime-fade",{GroupTransparency=1},0.15,nil,nil,finish)
end

function Panel:Open()
	if not self.playtime or (self.gui and not self.closing) then return end
	self:Dismiss(true)
	local app=self.app
	-- Acquire the blur before closing other menus so their exit cannot clear it.
	app:SetMenuBlur("playtime",true)
	app:CloseOtherMenus("playtime")
	self.previousSelection=GuiService.SelectedObject
	local gui=if app.editPreview then Theme.Container(app.other,"PlaytimeRewards")
		else Theme.InsetContainer(app.other,"PlaytimeRewards",Enum.ScreenInsets.CoreUISafeInsets)
	gui.ZIndex=30
	self.gui,self.closing=gui,false
	local frames=Theme.Container(gui,"FRAMES")
	local backdropParent=if app.editPreview then frames else Theme.InsetContainer(frames,"BackdropLayer",Enum.ScreenInsets.None)
	local backdrop=Theme.Frame(backdropParent,"Backdrop",UDim2.fromScale(1,1))
	backdrop.BackgroundTransparency,backdrop.Active=1,true
	local panel=Instance.new("CanvasGroup")
	panel.Name="PlaytimeRewards"
	panel.BackgroundTransparency,panel.BorderSizePixel,panel.GroupTransparency=1,0,1
	panel.Active,panel.ZIndex=true,2
	panel.AnchorPoint,panel.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
	panel.Parent,self.panel=frames,panel
	if MenuLayout.Control(app.gui,LAYOUT_NAME) then
		MenuLayout.Apply(app.gui,LAYOUT_NAME,panel)
	else
		panel.Size=PANEL_SIZE
		Theme.Aspect(panel,PANEL_ASPECT)
	end
	if app.editPreview then panel.Size,panel.Position=UDim2.fromScale(1,1),UDim2.fromScale(0.5,0.5) end
	self.restingPosition=panel.Position
	local header=Theme.Header(panel,"Header","Playtime Rewards",HEADER)
	header.PageIcon.Image,header.PageIcon.Visible=Panel.Gift,true
	Theme.LayoutHeader(header)
	local main=Theme.Container(panel,"Main")
	Theme.BelowHeader(header,main)
	Theme.Surface(main,Color3.fromRGB(30,24,40))
	main.UIStroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	Theme.HeaderClose(header,function() self:Close() end,1.7) -- phone hit area: 48 px
	local grid=Theme.Container(main,"Grid")
	grid.AnchorPoint,grid.Position,grid.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(0.94,0.92)
	Theme.Aspect(grid,GRID_ASPECT)
	self.grid,self.views=grid,{}
	for index,tile in PlaytimeRewards.Tiles do
		self.views[index]=self:Tile(grid,index,tile,((index-1)%4)*STEP_X,((index-1)//4)*STEP_Y)
	end
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	self:RefreshTiles()
	-- Slides down from the top, like the reference; the tiles grow in behind it.
	if not app.reducedMotion then panel.Position=self.restingPosition-UDim2.fromScale(0,0.75) end
	Theme.Motion:Tween(panel,"playtime-slide",{Position=self.restingPosition},0.32,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
	Theme.Motion:Tween(panel,"playtime-fade",{GroupTransparency=0},0.18)
	Theme.Motion:Reveal(grid,{limit=12,window=0.4,from=0.75})
	cue("MenuOpen","Pop",nil,{voiceKey="MenuOpen",cooldown=0.2})
	if app.editPreview then return end
	ContextActionService:BindActionAtPriority("PetRollPlaytimeClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then self:Close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	table.insert(self.windowConnections,UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode==Enum.KeyCode.Escape then self:Close() end
	end))
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=self.views[1] and self.views[1].button or nil end
end

-- One tile: the reward's colour, studs and rays, its icon, the amount over the icon's
-- foot, and a dark plate with the timer, "Claim!" or "Claimed!".
function Panel:Tile(grid,index: number,tile: PlaytimeRewards.Tile,x: number,y: number)
	local color=TILE_COLORS[tile.color] or TILE_COLORS.Blue
	local button=Instance.new("TextButton")
	button.Name,button.Text,button.AutoButtonColor,button.Selectable="Tile"..index,"",false,true
	button.BackgroundTransparency,button.BorderSizePixel=1,0
	button.Position,button.Size=UDim2.fromScale(x,y),UDim2.fromScale(TILE_W,TILE_H)
	button.Parent=grid
	-- White base: the gradient carries the colour (a UIGradient multiplies).
	local card=Theme.Frame(button,"Card",UDim2.fromScale(1,1),WHITE)
	card.AnchorPoint,card.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
	-- Tiles keep their own colours; ApplyPopupStyle would darken them.
	card:SetAttribute("OwnsPopupStyle",true)
	Theme.Gradient(card,color:Lerp(WHITE,0.18),color:Lerp(Color3.new(0,0,0),0.18))
	Theme.Studs(card,0.07,28,0):SetAttribute("StudScaleWidth",1.6)
	Theme.Stroke(card,Color3.new(0,0,0),3)
	local art=Theme.Container(card,"Art")
	art.AnchorPoint,art.Position,art.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.38),UDim2.fromScale(0.62,0.62)
	Theme.Aspect(art,1)
	local rays=ShopArt.ProductRays(art,WHITE)
	rays.Size,rays.Position,rays.AnchorPoint,rays.ZIndex=UDim2.fromScale(1.7,1.7),UDim2.fromScale(0.5,0.5),Vector2.new(0.5,0.5),4
	local icon=Theme.Image(art,"Icon",Panel.Icon(tile),UDim2.fromScale(1,1))
	icon.ZIndex=5
	local text=if tile.kind=="Boost" then PlaytimeRewards.BoostText(tile)
		elseif tile.kind=="Rolls" then PlaytimeRewards.RollsText(tile.rolls or 0) else "+0"
	local amount=Theme.Display(card,"Amount",text,30,if tile.kind=="Coins" then Theme.Colors.coins else WHITE)
	amount.Position,amount.Size,amount.ZIndex=UDim2.fromScale(0.04,0.56),UDim2.fromScale(0.92,0.2),7
	amount.TextXAlignment,amount.TextWrapped=Enum.TextXAlignment.Center,false
	-- The plate stays above the claimed shade so "Claimed!" shows.
	local plate=Theme.Frame(card,"Plate",UDim2.fromScale(0.88,0.18),Color3.fromRGB(14,16,18))
	plate.Position,plate.BackgroundTransparency,plate.ZIndex=UDim2.fromScale(0.06,0.77),0.3,11
	local status=Theme.Display(plate,"Status","",26,WHITE)
	status.Position,status.Size,status.ZIndex=UDim2.fromScale(0.04,0.06),UDim2.fromScale(0.92,0.88),12
	status.TextXAlignment,status.TextWrapped=Enum.TextXAlignment.Center,false
	Theme.Motion:Center(status) -- same resting rect; "Claim!" punches from its middle
	-- Claimed: darkened, with the Daily reward's green check.
	local shade=Theme.Frame(card,"Claimed",UDim2.fromScale(1,1),Color3.fromRGB(14,22,34))
	shade.BackgroundTransparency,shade.ZIndex,shade.Visible=0.3,9,false
	local check=Theme.Display(card,"Check","✓",80,CLAIM)
	check.Position,check.Size,check.ZIndex,check.Visible=UDim2.fromScale(0.15,0.1),UDim2.fromScale(0.7,0.55),10,false
	check.TextXAlignment=Enum.TextXAlignment.Center
	Theme.Motion:BindButton(button,card)
	button.Activated:Connect(function() self:TryClaim(index) end)
	return {button=button,card=card,amount=amount,status=status,shade=shade,check=check,icon=icon,glowing=false}
end

-- Amounts (the steady income moves) and claimed looks from the latest state.
function Panel:RefreshTiles()
	local playtime=self.playtime
	if not playtime or not self.views then return end
	for index,view in self.views do
		local data=playtime.tiles[index]
		if data then
			if data.kind=="Coins" then view.amount.Text="+"..Theme.Money(tonumber(data.coins) or 0) end
			local claimed=data.claimed==true
			view.shade.Visible,view.check.Visible=claimed,claimed
		end
	end
	self:Step(true)
end

function Panel:RefreshStatus(view,data,now: number)
	local claimed=data.claimed==true
	local remaining=if type(data.unlockAt)=="number" then data.unlockAt-now else (tonumber(data.at) or 0)*60
	local ready=not claimed and remaining<=0
	local text=if claimed then "Claimed!" elseif ready then "Claim!" else PlaytimeRewards.Clock(remaining)
	if view.status.Text~=text then
		view.status.Text=text
		-- "Claim!" arrives with a punch; the countdown stays quiet.
		if ready then Theme.Motion:Punch(view.status,1.2,0.3) end
	end
	local color=if claimed or ready then CLAIM else WHITE
	if view.status.TextColor3~=color then view.status.TextColor3=color end
	-- A claimable tile glows until it is claimed (steady ring under reduced motion).
	if ready~=view.glowing then
		view.glowing=ready
		if ready then Theme.Motion:Glow(view.button,CLAIM,3) else Theme.Motion:StopGlow(view.button) end
	end
end

-- Locked tiles do nothing, as in the reference; one claim request at a time.
function Panel:TryClaim(index: number)
	local data=self.playtime and self.playtime.tiles[index]
	if not data or data.claimed==true or type(data.unlockAt)~="number" then return end
	if workspace:GetServerTimeNow()<data.unlockAt then return end
	if os.clock()<self.pendingUntil then return end
	self.pendingUntil=os.clock()+3
	self.app.audio:Play("Click")
	self.app:Request("ClaimPlaytime",{index=index})
end

-- The server's answer: a ring ripples out of the tile with the Claim cue and the
-- reward floats up ("+1,200 Coins", "+100% Luck", "3 Free Rolls"); Coins also fly
-- from the tile into the HUD Coins readout. Boosts and rolls keep the server's
-- message. A refusal is shown by AppController's normal notice.
function Panel:Claimed(result)
	self.pendingUntil=0
	if not result.ok then return end
	local receipt=result.receipt
	local app=self.app
	local coins=type(receipt)=="table" and receipt.kind=="Coins" and (tonumber(receipt.coins) or 0)>0
	local view=self.views and type(receipt)=="table" and self.views[receipt.index]
	-- Boosts and rolls keep the server's message; so do Coins once the window has closed.
	if not coins or not view then app:Notify(result.message,true) end
	if not view or not self.grid then return end
	local motion=Theme.Motion
	cue("Claim","UIPurchase",nil,{voiceKey="PlaytimeClaim",cooldown=0.3})
	motion:Ripple(view.card,WHITE)
	local centre=view.button.Position+UDim2.fromScale(TILE_W/2,TILE_H/2)
	local text=if coins then view.amount.Text.." Coins" else view.amount.Text
	motion:Float(self.grid,text,centre-UDim2.fromScale(0,TILE_H*0.2),{color=if coins then Theme.Colors.coins else WHITE,size=30,rise=0.12})
	local gui=app.gui
	if coins and app.hud and app.hud.money and gui and view.icon.Parent then
		local target=motion:Point(gui,motion:CenterOf(app.hud.money))
		local origin=motion:Point(gui,motion:CenterOf(view.icon))
		cue("Whoosh",nil,nil,{voiceKey="CoinWhoosh",cooldown=0.3})
		for index=1,4 do
			motion:Fly(gui,Theme.Assets.Coin,origin+UDim2.fromScale((index-2.5)*0.012,0),target,{seconds=0.5+index*0.05,arc=0.1,onArrive=function()
				if index==1 then cue("CoinPickup","Collect",1,{voiceKey="CoinArrive",cooldown=0.15,pitchVariance=0.05}) end
			end})
		end
	end
end

function Panel:Destroy()
	self.alive=false
	self:Dismiss(true)
	self:Attention(false)
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if self.bar then self.bar:Destroy();self.bar=nil end
end

return Panel
