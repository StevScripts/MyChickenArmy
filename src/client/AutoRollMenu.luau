--!strict
-- October 20 overhaul Auto Roll panel (S12b; docs/team/AUTO_ROLL.md). Stevin: copy Drop
-- a Fruit's Auto Roll board 1:1 in My Chicken Army's art style. The header carries the
-- Auto Roll ON/OFF pill; "Stop When Appear" lists one ON/OFF row per rarity; the bottom
-- "< Rarity >" switcher pages Rarity, Mutation and New. Later October 20 owner request:
-- the HUD button itself turns Auto Roll on/off, and the gear beside it pops this board
-- out next to it (no power pill, no blur; a press outside closes it). When Auto Roll stops, the banner
-- "Auto Roll found a Rare chicken!" crosses the top with confetti. RollService decides
-- everything; this only presents state.autoRoll and sends SetAutoRoll.
local GuiService=game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Mutations=require(Shared.MutationCatalog)
local UIColors=require(Shared.UIColors)
local AutoRollRules=require(Shared.AutoRollRules)
local Theme=require(script.Parent.UITheme)
local Menu={}
Menu.__index=Menu

local GREEN=Theme.ReferenceColors.Army
local BLUE=Theme.ReferenceColors.Upgrades
local RED=Theme.ActionColors.danger
local WHITE=Color3.new(1,1,1)
local ROW_FILL=Color3.fromRGB(30,35,39)
-- The reference banner's light blue display text.
local BANNER_BLUE=Color3.fromRGB(84,176,255)
local CONFETTI={Color3.fromRGB(255,214,0),Color3.fromRGB(0,221,255),Color3.fromRGB(255,95,180),
	Color3.fromRGB(99,239,0),Color3.fromRGB(255,140,0),WHITE}
-- Whole window, header included (aspect = width / height): a tall board like theirs,
-- popped out beside the HUD gear.
local PANEL_SIZE,PANEL_ASPECT=UDim2.fromScale(0.3,0.6),0.74
local VISIBLE_ROWS=4
local BANNER_SECONDS=3
local BANNER_POSITION=UDim2.fromScale(0.5,0.22)
local PENDING_SECONDS=2
-- The Auto Roll Gem Upgrade icon (S6, uploaded October 20).
Menu.Icon="rbxassetid://83070773137079"
Menu.Pages={"Rarity","Mutation","New"}

function Menu.new(app)
	return setmetatable({app=app,connections={},pending={},auto=nil::any,page=1,pills={},
		bannerOffer=nil::string?,banner=nil::any,powerGlowing=false},Menu)
end

local function place(item,x,y,w,h)
	item.Position,item.Size=UDim2.fromScale(x,y),UDim2.fromScale(w,h)
end

-- Oct 21 game feel (docs/team/GAME_FEEL_20261021.md): the first authored cue among
-- `names`, else the last one (an existing cue), so new cues fall back until the sound
-- session adds them. The UI Lab's audio stub has no Has and keeps the fallback.
local function cue(app,...: string): string
	local audio=app.audio
	local names={...}
	if audio and audio.Has then
		for _,name in names do if audio:Has(name) then return name end end
	end
	return names[#names]
end

-- One page's rows: {id, kind, key, name, color}.
local function pageRows(page: string)
	local rows={}
	if page=="Rarity" then
		for _,rarity in AutoRollRules.Rarities do
			table.insert(rows,{id="rarity:"..rarity,kind="rarity",key=rarity,name=rarity,color=UIColors.Rarities[rarity] or WHITE})
		end
	elseif page=="Mutation" then
		for _,id in AutoRollRules.Mutations do
			local def=Mutations.Get(id)
			table.insert(rows,{id="mutation:"..id,kind="mutation",key=id,name=if def then def.name else id,color=if def then def.color else WHITE})
		end
	else
		table.insert(rows,{id="newChicken",kind="new",key="newChicken",name="New Chicken",color=WHITE})
		table.insert(rows,{id="newMutation",kind="new",key="newMutation",name="New Mutation",color=WHITE})
	end
	return rows
end

-- A row's state from the snapshot, or a change just sent until the snapshot echoes it.
function Menu:Value(row): boolean
	local auto=self.auto or {}
	local current
	if row.kind=="rarity" then current=type(auto.rarities)=="table" and auto.rarities[row.key]==true
	elseif row.kind=="mutation" then current=type(auto.mutations)=="table" and auto.mutations[row.key]==true
	else current=auto[row.key]==true end
	local pending=self.pending[row.id]
	if pending then
		if os.clock()<pending.untilAt and current~=pending.value then return pending.value end
		self.pending[row.id]=nil
	end
	return current==true
end

local POWER={id="enabled",kind="new",key="enabled"}

function Menu:Set(row, on: boolean)
	self.pending[row.id]={value=on,untilAt=os.clock()+PENDING_SECONDS}
	local request=if row.kind=="rarity" then {rarity=row.key,on=on}
		elseif row.kind=="mutation" then {mutation=row.key,on=on}
		else {[row.key]=on}
	self.app:Request("SetAutoRoll",request)
	self:Refresh()
end

-- The HUD Auto Roll button: on/off, shown at once (HudController reads PowerOn).
function Menu:PowerOn(): boolean
	return self:Value(POWER)
end

function Menu:TogglePower()
	self:Set(POWER,not self:Value(POWER))
	local hud=self.app.hud
	if hud and self.app.state then hud:UpdateAutoRoll(self.app.state) end
end

-- The HUD gear: pop the board out, or put it away.
function Menu:Toggle()
	if self.gui and not self.closing then self:Dismiss() else self:Open() end
end

local function setPill(button,on: boolean)
	local text=if on then "ON" else "OFF"
	if button.Text~=text then button.Text=text end
	local color=if on then GREEN else RED
	if button.BackgroundColor3~=color then button.BackgroundColor3=color end
end

function Menu:Refresh()
	if not self.gui then return end
	for _,entry in self.pills do setPill(entry.button,self:Value(entry.row)) end
	self.pageLabel.Text=Menu.Pages[self.page]
end

-- state.autoRoll arrives with every snapshot; a new hold shows the banner once.
function Menu:Render(state, _result)
	local auto=state and state.autoRoll
	self.auto=if type(auto)=="table" then auto else nil
	if self.gui and not self.closing then
		if not (self.auto and self.auto.unlocked) then self:Dismiss(true) else self:Refresh() end
	end
	local held=self.auto and self.auto.held
	if type(held)=="table" and held.offerId~=self.bannerOffer and not (self.app.intro and self.app.intro:Pending()) then
		self.bannerOffer=held.offerId
		self:ShowBanner(if type(held.banner)=="string" then held.banner else "Auto Roll found a chicken!")
	end
	-- Oct 21 game feel: the HUD power button glows while Auto Roll runs (a steady ring
	-- under reduced motion); PAUSED and OFF settle it.
	local hud=self.app.hud
	local power=hud and hud.autoRoll
	if power and power.Parent then
		local running=self.auto~=nil and self.auto.unlocked==true and self:PowerOn() and self.auto.holding~=true
		if running~=self.powerGlowing then
			self.powerGlowing=running
			if running then Theme.Motion:Glow(power,GREEN,3) else Theme.Motion:StopGlow(power) end
		end
	end
end

-- Panel ------------------------------------------------------------------------

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
	local function finish()
		if self.gui~=gui then return end
		self.gui,self.panel,self.closing=nil,nil,false
		table.clear(self.pills)
		gui:Destroy()
		-- The HUD gear hides again unless the mouse is still on it.
		local hud=self.app.hud
		if hud and hud.UpdateAutoRollGear then hud:UpdateAutoRollGear() end
	end
	if immediate then finish();return end
	self.app.audio:Play(cue(self.app,"MenuClose","Click"),nil,{noFallback=true})
	Theme.Motion:Tween(panel,"autoroll-size",{Size=UDim2.fromScale(PANEL_SIZE.X.Scale*0.97,PANEL_SIZE.Y.Scale*0.97)},0.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	Theme.Motion:Tween(panel,"autoroll-fade",{GroupTransparency=1},0.16,nil,nil,finish)
end

-- The list shows four rows at a time and scrolls the rest, like the reference board.
function Menu:BuildRows()
	local list=self.list
	for _,child in list:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	table.clear(self.pills)
	local rows=pageRows(Menu.Pages[self.page])
	local slots=math.max(#rows,VISIBLE_ROWS)
	list.CanvasSize=UDim2.fromScale(0,slots/VISIBLE_ROWS)
	list.CanvasPosition=Vector2.zero
	self.listLayout.Padding=UDim.new(0.14/slots,0)
	for index,row in rows do
		local frame=Theme.Frame(list,row.id,UDim2.fromScale(1,0.86/slots),ROW_FILL)
		frame.LayoutOrder,frame.BackgroundTransparency=index,0.15
		Theme.Stroke(frame,Theme.Arcade.border,2)
		Theme.Studs(frame,0.14,28,0)
		local name=Theme.Display(frame,"Name",row.name,32,row.color)
		name.TextXAlignment,name.TextScaled,name.TextWrapped=Enum.TextXAlignment.Left,true,false
		place(name,0.05,0.14,0.58,0.72)
		name.ZIndex=4
		local pill
		pill=Theme.Button(frame,"Toggle","OFF",function()
			self.app.audio:Play(cue(self.app,"Toggle","Click"),nil,{noFallback=true})
			Theme.Motion:PopScale(pill,1.14,0.24)
			self:Set(row,not self:Value(row))
		end,RED)
		pill.AnchorPoint=Vector2.new(1,0.5)
		place(pill,0.96,0.5,0.3,0.72);Theme.Aspect(pill,2.5)
		-- Phone hit area: the pill answers across its whole row pitch (0.86 row + 0.14 gap
		-- per slot) so neighbouring pills meet without overlapping.
		Theme.PadHit(pill,1,1/(0.72*0.86),0.5,0,true)
		self.pills[row.id]={button=pill,row=row}
	end
	Theme.ScaleText(list)
	self:Refresh()
	-- Rows grow in one after another on open and on each page turn.
	Theme.Motion:Reveal(list,{from=0.8,window=0.3})
end

function Menu:Turn(direction: number)
	self.page=(self.page-1+direction)%#Menu.Pages+1
	self:BuildRows()
	if self.pageLabel then Theme.Motion:Punch(self.pageLabel,1.16,0.26) end
end

function Menu:Open()
	local auto=self.auto
	if not auto or not auto.unlocked then return end
	if self.gui and not self.closing then return end
	self:Dismiss(true)
	local app=self.app
	app:CloseOtherMenus("autoRoll")
	self.previousSelection=GuiService.SelectedObject
	local gui=Theme.InsetContainer(app.other,"AutoRollMenu",Enum.ScreenInsets.CoreUISafeInsets)
	gui.ZIndex=30
	self.gui,self.closing,self.page=gui,false,1
	local frames=Theme.Container(gui,"FRAMES")
	local panel=Instance.new("CanvasGroup")
	panel.Name="AutoRoll"
	panel.BackgroundTransparency,panel.BorderSizePixel,panel.GroupTransparency=1,0,1
	panel.Active,panel.ZIndex=true,2
	panel.AnchorPoint,panel.Position,panel.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),PANEL_SIZE
	panel.Parent,self.panel=frames,panel
	Theme.Aspect(panel,PANEL_ASPECT)
	-- Pop out to the left of the HUD gear, bottom edges level; centred when the gear is
	-- hidden (the UI Lab story).
	local hud=app.hud
	local gear=(hud and hud.autoRollSettings)::GuiObject?
	-- Opened from Settings, the gear shows while the board is open.
	if hud and hud.UpdateAutoRollGear then hud:UpdateAutoRollGear() end
	local function follow()
		if not (gear and gear.Parent and hud.autoRoll.Visible) then
			panel.AnchorPoint,panel.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
			return
		end
		local corner=gear.AbsolutePosition-frames.AbsolutePosition
		local gap=gear.AbsoluteSize.Y*0.2
		panel.AnchorPoint=Vector2.new(1,1)
		panel.Position=UDim2.fromOffset(corner.X-gap,corner.Y+gear.AbsoluteSize.Y)
	end
	follow()
	if gear then
		for _,property in {"AbsolutePosition","AbsoluteSize"} do
			table.insert(self.connections,gear:GetPropertyChangedSignal(property):Connect(follow))
			table.insert(self.connections,frames:GetPropertyChangedSignal(property):Connect(follow))
		end
	end
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
	-- The X's hit area reaches 48 px; the pills' hits start at their own top edge, so
	-- the first row stays clear of it.
	Theme.HeaderClose(header,close,3.75)
	-- Stop When Appear: the title, the list and the page switcher.
	local title=Theme.Display(main,"StopWhenAppear","Stop When Appear",34,WHITE)
	title.TextXAlignment,title.TextScaled=Enum.TextXAlignment.Center,true
	place(title,0.05,0.025,0.9,0.085)
	local list=Instance.new("ScrollingFrame")
	list.Name,list.BackgroundTransparency,list.BorderSizePixel="Rows",1,0
	list.ScrollBarThickness,list.ScrollBarImageColor3=6,Color3.fromRGB(200,206,210)
	list.ScrollingDirection,list.AutomaticCanvasSize=Enum.ScrollingDirection.Y,Enum.AutomaticSize.None
	list.VerticalScrollBarInset=Enum.ScrollBarInset.Always
	list.ZIndex,list.Parent=3,main
	place(list,0.05,0.125,0.9,0.66)
	-- Rows keep their own colors (rarity names, red/green pills).
	list:SetAttribute("OwnsPopupStyle",true)
	local layout=Instance.new("UIListLayout")
	layout.SortOrder,layout.Parent=Enum.SortOrder.LayoutOrder,list
	self.list,self.listLayout=list,layout
	local switcher=Theme.Frame(main,"Switcher",UDim2.fromScale(0.9,0.15),ROW_FILL)
	switcher.Position,switcher.BackgroundTransparency=UDim2.fromScale(0.05,0.815),0.15
	Theme.Stroke(switcher,Theme.Arcade.border,2)
	switcher:SetAttribute("OwnsPopupStyle",true)
	local previous=Theme.Button(switcher,"Previous","<",function() app.audio:Play(cue(app,"TabSwitch","Click"),nil,{noFallback=true});self:Turn(-1) end,BLUE)
	place(previous,0.03,0.12,0.18,0.76);Theme.Aspect(previous,1)
	Theme.PadHit(previous,1.5,1.5,0.5,0.1) -- 48 px, growing down, clear of the last row's pill
	local nextPage=Theme.Button(switcher,"Next",">",function() app.audio:Play(cue(app,"TabSwitch","Click"),nil,{noFallback=true});self:Turn(1) end,BLUE)
	nextPage.AnchorPoint=Vector2.new(1,0)
	place(nextPage,0.97,0.12,0.18,0.76);Theme.Aspect(nextPage,1)
	Theme.PadHit(nextPage,1.5,1.5,0.5,0.1)
	local pageLabel=Theme.Display(switcher,"Page","Rarity",44,WHITE)
	pageLabel.TextXAlignment,pageLabel.TextScaled=Enum.TextXAlignment.Center,true
	place(pageLabel,0.24,0.1,0.52,0.8)
	pageLabel.ZIndex=4
	self.pageLabel=pageLabel
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	self:BuildRows()
	if not app.reducedMotion then panel.Size=UDim2.fromScale(PANEL_SIZE.X.Scale*0.94,PANEL_SIZE.Y.Scale*0.94) end
	Theme.Motion:Tween(panel,"autoroll-size",{Size=PANEL_SIZE},0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
	Theme.Motion:Tween(panel,"autoroll-fade",{GroupTransparency=0},0.22)
	app.audio:Play(cue(app,"MenuOpen","Pop"),nil,{noFallback=true})
	ContextActionService:BindActionAtPriority("PetRollAutoRollClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	-- A press anywhere but the board or its gear closes it; the press still goes
	-- through (the world, the HUD toggle). The gear's own press toggles it instead.
	local playerGui=gui:FindFirstAncestorOfClass("PlayerGui")
	table.insert(self.connections,UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode==Enum.KeyCode.Escape then close();return end
		local kind=input.UserInputType
		if kind~=Enum.UserInputType.MouseButton1 and kind~=Enum.UserInputType.Touch then return end
		if not playerGui or self.closing then return end
		for _,hit in playerGui:GetGuiObjectsAtPosition(input.Position.X,input.Position.Y) do
			if hit==panel or hit:IsDescendantOf(panel) or (gear and (hit==gear or hit:IsDescendantOf(gear))) then return end
		end
		self:Dismiss()
	end))
	if UserInputService.GamepadEnabled then
		local first=self.pills[pageRows(Menu.Pages[1])[1].id]
		if first then GuiService.SelectedObject=first.button end
	end
end

-- Banner ------------------------------------------------------------------------

-- "Auto Roll found a Rare chicken!" in big outlined blue across the top, with confetti
-- (reduced motion keeps it still and skips the confetti), then it fades.
function Menu:ShowBanner(text: string)
	local app=self.app
	if not app.other then return end
	local banner=self.banner
	if not banner then
		local layer=Theme.InsetContainer(app.other,"AutoRollBanner",Enum.ScreenInsets.CoreUISafeInsets)
		layer.ZIndex=27
		local group=Instance.new("CanvasGroup")
		group.Name,group.BackgroundTransparency,group.BorderSizePixel="Banner",1,0
		group.AnchorPoint,group.Position,group.Size=Vector2.new(0.5,0.5),BANNER_POSITION,UDim2.fromScale(0.72,0.09)
		group.GroupTransparency,group.Visible,group.Parent=1,false,layer
		local label=Theme.Display(group,"Text","",64,BANNER_BLUE)
		label.TextXAlignment,label.TextScaled,label.TextWrapped=Enum.TextXAlignment.Center,true,false
		label.Size=UDim2.fromScale(1,1)
		Theme.ScaleText(group)
		banner={layer=layer,group=group,label=label,serial=0}
		self.banner=banner
	end
	banner.serial+=1
	local serial=banner.serial
	banner.label.Text=text
	local group=banner.group
	group.Visible=true
	-- Oct 21 game feel: the hit stinger (RollRare until AutoRollHit is authored).
	app.audio:Play(cue(app,"AutoRollHit","RollRare"),1,{noFallback=true,voiceKey="AutoRollHit"})
	if app.reducedMotion then
		group.GroupTransparency=0
		group.Position=BANNER_POSITION
	else
		group.GroupTransparency=1
		Theme.Motion:Tween(group,"banner-fade",{GroupTransparency=0},0.18)
		-- Slams in from above with a Back overshoot while it pops down to size.
		Theme.Motion:Slide(group,BANNER_POSITION-UDim2.fromScale(0,0.08),BANNER_POSITION,0.34,Theme.Motion.Ease.Pop)
		Theme.Motion:PopScale(group,1.25,0.3)
		self:Confetti(banner.layer)
	end
	-- The UI Lab keeps it up for editing.
	if app.editPreview then return end
	task.delay(BANNER_SECONDS,function()
		if banner.serial~=serial or not group.Parent then return end
		Theme.Motion:Tween(group,"banner-fade",{GroupTransparency=1},0.3,nil,nil,function()
			if banner.serial==serial then group.Visible=false end
		end)
	end)
end

-- A short burst of falling paper squares under the banner (TweenService only).
function Menu:Confetti(layer)
	for index=1,26 do
		local piece=Instance.new("Frame")
		piece.Name,piece.BorderSizePixel="Confetti",0
		piece.BackgroundColor3=CONFETTI[(index-1)%#CONFETTI+1]
		piece.AnchorPoint,piece.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.008,0.016)
		local x=0.16+math.random()*0.68
		piece.Position,piece.Rotation=UDim2.fromScale(x,0.2+math.random()*0.05),math.random(0,90)
		piece.ZIndex,piece.Parent=2,layer
		local seconds=1.1+math.random()*0.8
		local fall=TweenService:Create(piece,TweenInfo.new(seconds,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{
			Position=UDim2.fromScale(x+(math.random()-0.5)*0.12,0.45+math.random()*0.25),
			Rotation=piece.Rotation+math.random(-360,360),BackgroundTransparency=1})
		fall.Completed:Once(function() piece:Destroy() end)
		fall:Play()
	end
end

function Menu:Destroy()
	self:Dismiss(true)
	if self.banner then self.banner.layer:Destroy();self.banner=nil end
end

return Menu
