--!strict
-- October 21 My Army (docs/team/ARMY_GRID.md). Stevin's reference is a simulator
-- "Pets" window, copied 1:1 in the game's art: one grid of every chicken (Army
-- chickens checked and first), a hover tooltip, a detail card on click, Equip Best /
-- Unequip All, lock and sell modes with a Confirm bar, two sorts, a compact grid and
-- search. The Flock is never picked here: it is always the best egg layers, and a
-- layer away with the Army leaves its slot to the next best one at home.
-- The server still owns selection, capacity, stats and every transaction.
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local Theme=require(script.Parent.UITheme)
local Preview=require(script.Parent.ChickenPreview)
local MutationVFX=require(script.Parent.SpecialChickenVFX)
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Rules=require(Shared.Rules)
local Catalog=require(Shared.PetCatalog)
local Giant=require(Shared.GiantChicken)
local Mutations=require(Shared.MutationCatalog)
local Upgrades=require(Shared.UpgradeCatalog)
local EggArt=require(Shared.EggArt)
local WHITE=Color3.fromRGB(249,251,242)
local MUTED=Color3.fromRGB(181,205,223)
local INK=Color3.fromRGB(3,11,14)
local EDGE=Color3.fromRGB(66,119,149)
local EQUIPPED=Color3.fromRGB(127,255,0)
local SELECTED=Color3.fromRGB(0,223,255)
local POWER=Color3.fromRGB(255,72,72)
local GOLD=Color3.fromRGB(255,221,96)
local UNEQUIPPED=Color3.fromRGB(170,180,186)
-- October 21 game feel (docs/team/GAME_FEEL_20261021.md): an authored cue, or its
-- fallback until the sound session adds it (UI Lab previews stub audio without Has).
-- Presentation only; one client audio.
local Audio=nil
local function cue(name,fallback,pitch,options)
	if not Audio then return end
	if type(Audio.Has)=="function" and Audio:Has(name) then Audio:Play(name,pitch,options)
	elseif fallback then Audio:Play(fallback,pitch,options) end
end
local function denied(item)
	Theme.Motion:Shake(item,5)
	cue("Locked","Error",nil,{volume=0.5,voiceKey="Locked",cooldown=0.2})
end
local Art={
	Helmet="rbxassetid://80504375672119",
	Damage="rbxassetid://127164621014549",
	Check="rbxassetid://102978514196695",
	Search="rbxassetid://111902627409710",
	Trash="rbxassetid://111469244237912", -- S6's SellTrash icon
	Padlock=Theme.Assets.Padlock,
	ArmySlot=Theme.GemArt.ArmySlot,
	FlockSlot=Theme.GemArt.FlockSlot,
	Index=Theme.Assets.Index,
	Card={
		Common="rbxassetid://122916116818277",Uncommon="rbxassetid://125764068767248",
		Rare="rbxassetid://99342664851264",Epic="rbxassetid://81561273552383",
		Legendary="rbxassetid://92160625350901",Mythic="rbxassetid://89442120797640",
	},
}
local RARITIES={
	Common=Color3.fromRGB(211,228,207),Uncommon=Color3.fromRGB(53,255,23),
	Rare=Color3.fromRGB(0,212,255),Epic=Color3.fromRGB(198,75,255),
	Legendary=Color3.fromRGB(255,213,0),Mythic=Color3.fromRGB(255,54,114),Secret=Color3.fromRGB(64,255,233),
}
local TONES={
	Green={Color3.fromRGB(165,255,0),Color3.fromRGB(38,227,0),Color3.fromRGB(40,125,6),Color3.fromRGB(217,255,154)},
	Blue={Color3.fromRGB(0,231,255),Color3.fromRGB(0,154,255),Color3.fromRGB(0,91,157),Color3.fromRGB(179,233,255)},
	Red={Color3.fromRGB(255,102,84),Color3.fromRGB(243,36,59),Color3.fromRGB(142,16,40),Color3.fromRGB(255,180,186)},
	Gold={Color3.fromRGB(255,214,48),Color3.fromRGB(255,153,0),Color3.fromRGB(140,82,0),Color3.fromRGB(255,240,170)},
	Dark={Color3.fromRGB(58,72,81),Color3.fromRGB(30,41,48),Color3.fromRGB(14,20,24),Color3.fromRGB(120,138,150)},
	Off={Color3.fromRGB(122,132,138),Color3.fromRGB(86,95,101),Color3.fromRGB(48,54,58),Color3.fromRGB(160,170,176)},
}
-- Design units measured from the reference recording (half of 3456 x 2234): the
-- window with its side rail and overhanging buttons is 960 x 557 on a 1728 x 1084
-- game view, i.e. 55.6% of the width and 51.4% of the height (MenuLayout's Army
-- default). Everything below is placed in these units with Scale only.
local W,H=960,557
-- October 21 (owner): a shared studded top bar (title + close, like every other menu)
-- sits on the body; the lock, sell and counts controls ride in it.
-- 65.3 = 830 / Theme.HeaderAspect, so the header fills the bar's full width.
local TOPBAR={x=100,y=0,w=830,h=65.3}
local BODY={x=100,y=65.3,w=830,h=463.7}
local GRID={x=10,y=10,w=812,h=420} -- inside BODY
local DETAIL={x=537,y=8,w=275,h=422} -- inside BODY
-- Seven 108-unit tiles (8 apart) normally; ten 75-unit tiles (6 apart) compact.
local LAYOUTS={Normal={columns=7,cell=108,gap=8},Compact={columns=10,cell=75,gap=6}}
local PAGE=70 -- cards are built a page at a time; storage can hold 1,000 chickens
local SORTS={"Power","Eggs"}
local Browser={}
Browser.__index=Browser

local function frame(parent,name,size,position)
	local item=Instance.new("Frame")
	item.Name,item.Size,item.Position=name,size or UDim2.new(),position or UDim2.new()
	item.BorderSizePixel,item.BackgroundTransparency=0,1
	item.ZIndex=parent.ZIndex+1;item.Parent=parent
	return item
end

local function rect(item,x,y,width,height,parentWidth,parentHeight)
	Theme.RelativeRect(item,x,y,width,height,parentWidth,parentHeight)
	return item
end

local function label(parent,name,text,color,prominent)
	local item=Theme.Label(parent,name,text,24,color or WHITE)
	item.TextWrapped,item.TextScaled,item.TextTruncate=false,true,Enum.TextTruncate.None
	item.TextXAlignment=Enum.TextXAlignment.Center
	item.ZIndex=parent.ZIndex+4
	item.TextOutline.Color=INK
	item.TextOutline.Thickness=if prominent then 0.07 else 0.05
	return item
end

local function surface(item,top,bottom,border,thickness)
	item.BackgroundColor3,item.BackgroundTransparency=Color3.new(1,1,1),0
	Theme.Round(item)
	Theme.Gradient(item,top,bottom).Transparency=NumberSequence.new(0)
	local stroke=Theme.Stroke(item,border or EDGE,thickness or 1.5)
	stroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	return stroke
end

-- October 20 (owner): every My Army panel is black at 10% transparency; strokes stay.
local function blackPanel(item,border,thickness)
	local stroke=surface(item,Color3.new(0,0,0),Color3.new(0,0,0),border or INK,thickness or 3)
	item.BackgroundTransparency=0.1
	Theme.Studs(item,0.14,28,0).ZIndex=item.ZIndex
	return stroke
end

local function image(parent,name,asset)
	local item=Theme.Image(parent,name,asset,UDim2.new(),UDim2.new())
	item.ZIndex=parent.ZIndex+1
	return item
end

local function tone(item)
	local colors=if not item.Active then TONES.Off else TONES[item:GetAttribute("Tone") or "Green"] or TONES.Green
	Theme.ApplyReferenceAccent(item,ColorSequence.new(colors[1],colors[2]))
	local visual=item.Visual
	visual.LowerLip.BackgroundColor3=colors[3]
	visual.UIStroke.Color=INK
	visual.Face.InsetHighlight.UIStroke.Color=colors[4]
	visual.Face.InsetHighlight.UIStroke.Transparency=0.2
end

-- The chunky studded button used across My Army; `key` names a TONES entry.
local function button(parent,name,text,callback,key)
	local item
	item=Theme.ActionButton(parent,name,text,function() if item.Active then callback() end end,Theme.ReferenceColors.Army)
	item:SetAttribute("Tone",key or "Green")
	item.TextColor3,item.ZIndex=WHITE,parent.ZIndex+5
	local visual=item.Visual
	visual.ZIndex,visual.BackgroundTransparency=item.ZIndex,1
	visual.UIStroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	visual.UIStroke.Thickness=Theme.Border.Shell
	visual.Face.Position,visual.Face.Size=UDim2.fromScale(0.006,0),UDim2.fromScale(0.988,0.92)
	visual.Face.ZIndex,visual.Face.ClipsDescendants=visual.ZIndex+2,true
	visual.LowerLip.Position,visual.LowerLip.Size=UDim2.fromScale(0.006,0.88),UDim2.fromScale(0.988,0.11)
	visual.LowerLip.ZIndex=visual.ZIndex+1
	local rim=visual.Face.InsetHighlight
	rim.Position,rim.Size,rim.ZIndex=UDim2.fromScale(0.03,0.08),UDim2.fromScale(0.94,0.84),visual.Face.ZIndex+2
	local caption=visual.Caption
	caption.Position,caption.Size=UDim2.fromScale(0.05,0.1),UDim2.fromScale(0.9,0.72)
	caption.ZIndex=visual.ZIndex+5
	caption.TextShadow.TextTransparency=0.35;caption.TextShadow.TextOutline.Enabled=false
	caption.TextFace.TextOutline.Thickness,caption.TextFace.TextOutline.Color=0.07,INK
	Theme.Studs(visual.Face,0.07,24,0).ZIndex=visual.Face.ZIndex+1
	Theme.ScaleText(item)
	tone(item)
	-- A press on a greyed button: BindButton's small "no" shake plus a soft Locked cue.
	item.MouseButton1Down:Connect(function()
		if not item.Active then cue("Locked","Error",nil,{volume=0.5,voiceKey="Locked",cooldown=0.2}) end
	end)
	return item
end

-- A square button showing only art (lock, trash, sort, compact).
local function iconButton(parent,name,asset,callback,key)
	local item=button(parent,name,"",callback,key)
	local icon=image(item.Visual,"Icon",asset)
	icon.AnchorPoint,icon.Position,icon.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.47),UDim2.fromScale(0.72,0.72)
	icon.ZIndex=item.Visual.ZIndex+6
	Theme.Aspect(icon,1)
	return item,icon
end

local function setTone(item,key)
	if item:GetAttribute("Tone")~=key then item:SetAttribute("Tone",key);tone(item) end
end

local function enabled(item,value)
	if item.Active~=value then item.Active,item.Selectable=value,value;tone(item) end
end

local function clear(parent)
	for _,item in parent:GetChildren() do if item:IsA("GuiObject") then item:Destroy() end end
end

local function power(pet): number
	return Rules.PetPower(pet.species,pet.stars or 1,pet.level or 1,pet.giantSize)
end

local function displayName(pet): string
	local definition=Catalog[pet.species]
	return (if pet.giantSize then Giant.Kind(pet.giantSize).." " else "")..(definition and definition.name or "Chicken")
end

-- The server's sale rule, read from the snapshot; the reason says why not.
local function sellable(pet): (boolean,string)
	if pet.favorite then return false,"Locked chickens can't be sold." end
	if pet.deployed or pet.home==false then return false,"Sell this chicken once it's back home." end
	if pet.selected then return false,"Remove it from your Army first." end
	if pet.canSell==false then return false,if type(pet.saleReason)=="string" then pet.saleReason else "This chicken can't be sold." end
	if type(pet.refund)~="number" or pet.refund<0 or pet.refund==math.huge then return false,"This chicken can't be sold." end
	return true,""
end

function Browser.new(app,parent)
	local self=setmetatable({app=app,parent=parent,key="",gridKey="",pending=nil,connections={},cards={},
		mode=nil,marked={},markOrder={},placing=nil,inspecting=false,query="",sort="Power",compact=false,
		visible={},shown=0,wanted=PAGE,flashToken=0,revealOnRender=false,detailShown=false,barShown=false},Browser)
	Audio=app.audio
	local root=Instance.new("Frame")
	root.Name,root.BackgroundTransparency,root.BorderSizePixel="ChickenBrowser",1,0
	root.Visible,root.ClipsDescendants=false,false
	root.AnchorPoint,root.Position,root.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(1,1)
	root.ZIndex,root.Parent=parent.ZIndex+1,parent
	root:SetAttribute("OwnsPopupStyle",true)
	Theme.Aspect(root,W/H)
	self.root=root

	-- The window: the shared top bar over one black studded body; the rail and the
	-- bottom buttons overhang it.
	local body=rect(frame(root,"ArmyBody"),BODY.x,BODY.y,BODY.w,BODY.h,W,H)
	blackPanel(body,INK,3)
	self.body=body
	local topBar=rect(frame(root,"TopBar",UDim2.new(),UDim2.new()),TOPBAR.x,TOPBAR.y,TOPBAR.w,TOPBAR.h,W,H)
	topBar.ZIndex=body.ZIndex+1
	local header=Theme.Header(topBar,"Header","My Army",Theme.HeaderColors.Army)
	-- Phone hit areas (DESIGN.md §6), in the reference units, art untouched: the X grows
	-- 2.25x (48 px), its extra room mostly up past the window and right past its edge so
	-- it never meets the Flock "+" (art ends at 853 units; the X's hit starts at 856).
	self.closeButton=Theme.HeaderClose(header,function() self.app.audio:Play("Click");self.app:ClosePanel() end,2.25,0.22,0.7)
	-- Full-window layer so the bar's controls draw above the header's studs and rim.
	local controls=frame(root,"TopBarControls",UDim2.fromScale(1,1),UDim2.new())
	controls.ZIndex=header.ZIndex+4
	self.lock,self.lockIcon=iconButton(controls,"LockMode",Art.Padlock,function() self:SetMode("Lock") end,"Red")
	rect(self.lock,360,7,50,50,W,H)
	self.trash,self.trashIcon=iconButton(controls,"SellMode",Art.Trash,function() self:SetMode("Sell") end,"Red")
	rect(self.trash,418,7,50,50,W,H)
	-- 104 x 104 units (48 px) each: Lock's hit grows left over the title, Sell's grows
	-- right over the Counts pill's icon and label (its "+" hit starts at 596); most of the
	-- height goes up past the window, the rest ends above the grid's first row (75).
	for _,item in {self.lock,self.trash} do Theme.Aspect(item,1) end
	Theme.PadHit(self.lock,104/50,2.08,1,0.73,true)
	Theme.PadHit(self.trash,104/50,2.08,0,0.73,true)

	-- Army and Flock counts, each with a "+" to its next Upgrades tier.
	local pill=rect(frame(root,"Counts"),478,7,380,50,W,H)
	pill.ZIndex=header.ZIndex+4
	surface(pill,Color3.fromRGB(20,38,47),Color3.fromRGB(10,20,26),INK,3)
	Theme.Studs(pill,0.14,28,0).ZIndex=pill.ZIndex
	self.counts=pill
	rect(image(pill,"ArmyIcon",Art.ArmySlot),10,4,48,48,440,56)
	self.capacity=rect(label(pill,"ArmyCount","",WHITE,true),62,6,110,44,440,56)
	self.capacityPlus=button(pill,"MoreArmySlots","+",function()
		self.app.audio:Play("Click")
		if not self:OpenUpgrade("ArmySize") then self.app:OpenPage("Shop") end
	end,"Green")
	rect(self.capacityPlus,176,5,46,46,440,56)
	rect(image(pill,"FlockIcon",Art.FlockSlot),232,4,48,48,440,56)
	self.summary=rect(label(pill,"FlockCount","",GOLD,true),284,6,100,44,440,56)
	self.flockPlus=button(pill,"FlockCapacity","+",function()
		self.app.audio:Play("Click")
		if not self:OpenUpgrade("Flock") then self:Flash("Your Flock is at its biggest size.") end
	end,"Green")
	rect(self.flockPlus,388,5,46,46,440,56)
	for _,item in {self.capacityPlus,self.flockPlus} do Theme.Aspect(item,1) end
	-- Each "+" answers across its count label, 107 units (49 px) wide (the Flock one only
	-- leftward, clear of the X).
	Theme.PadHit(self.capacityPlus,2.7,2.54,0.5,0.73,true)
	Theme.PadHit(self.flockPlus,2.7,2.54,1,0.73,true)

	-- Side rail: My Army and the Chicken Index, then the two sorts.
	local rail=rect(frame(root,"Tabs"),0,140,89,190,W,H)
	blackPanel(rail,INK,3)
	local function tab(name,text,asset,y,callback,alignY)
		local item=Instance.new("TextButton")
		item.Name,item.Text,item.AutoButtonColor,item.BackgroundTransparency=name,"",false,1
		item.ZIndex,item.Parent=rail.ZIndex+2,rail
		rect(item,4,y,81,88,89,190)
		-- The art lives in a Visual so the hit area can reach 104 units (48 px) each way:
		-- out past the rail's left edge, and (the tabs being 2 apart) Army's up past the
		-- rail's top, Index's down past its foot, into the window's empty margin.
		local visual=frame(item,"Visual",UDim2.fromScale(1,1),UDim2.new())
		rect(image(visual,"Icon",asset),10,2,61,61,81,88)
		rect(label(visual,"Caption",text,WHITE,true),0,58,81,28,81,88)
		item.Activated:Connect(callback)
		Theme.Motion:BindButton(item,Theme.Motion:ScaleOf(visual),visual)
		Theme.PadHit(item,104/81,104/88,1,alignY)
		return item
	end
	tab("ArmyTab","Army",Art.Helmet,6,function() self.app.audio:Play("Click") end,1)
	tab("IndexTab","Index",Art.Index,96,function() self.app.audio:Play("Click");self.app:OpenPage("Index") end,0)
	local sortBox=rect(frame(root,"Sort"),0,454,89,78,W,H)
	blackPanel(sortBox,INK,3)
	rect(label(sortBox,"Caption","Sort",WHITE,true),4,4,81,26,89,78)
	self.sortButtons={}
	for index,key in SORTS do
		local item=iconButton(sortBox,"Sort"..key,if key=="Power" then Art.Damage else EggArt.Image("Duck"),function()
			if self.sort==key then return end
			cue("TabSwitch","Click")
			self.sort,self.wanted=key,PAGE
			self.grid.CanvasPosition=Vector2.zero;self:Render(true)
		end,"Dark")
		item:SetAttribute("ClickSound",false)
		rect(item,6+(index-1)*40,34,37,37,89,78)
		Theme.Aspect(item,1)
		-- 104 units (48 px) tall, mostly up into the empty strip above the Sort box. The
		-- two sorts are 3 apart: Power's hit grows left past the window's edge to 104
		-- wide; Eggs' grows right only as far as the grid's cards allow (60, 28 px).
		Theme.PadHit(item,if index==1 then 104/37 else 60/37,104/37,if index==1 then 1 else 0,0.8,true)
		self.sortButtons[key]=item
	end

	-- The grid: every chicken, Army first.
	local grid=Instance.new("ScrollingFrame")
	grid.Name,grid.BackgroundTransparency,grid.BorderSizePixel="ChickenInventory",1,0
	grid.ScrollBarThickness,grid.ScrollBarImageColor3=6,MUTED
	grid.VerticalScrollBarInset,grid.ScrollingDirection=Enum.ScrollBarInset.None,Enum.ScrollingDirection.Y
	grid.CanvasSize,grid.AutomaticCanvasSize,grid.ClipsDescendants=UDim2.new(),Enum.AutomaticSize.None,true
	grid.ZIndex,grid.Parent=body.ZIndex+2,body
	rect(grid,GRID.x,GRID.y,GRID.w,GRID.h,BODY.w,BODY.h)
	local layout=Instance.new("UIGridLayout")
	layout.SortOrder,layout.FillDirection=Enum.SortOrder.LayoutOrder,Enum.FillDirection.Horizontal
	layout.Parent=grid
	-- Scale heights inside a ScrollingFrame follow the canvas, so cells take their
	-- width from Scale and stay square through this constraint; the row gap is the
	-- column gap converted to pixels whenever the grid resizes.
	Theme.Aspect(layout,1)
	self.grid,self.gridLayout=grid,layout
	table.insert(self.connections,grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:FitCells() end))
	-- AutomaticCanvasSize undercounts Scale cells; the canvas follows the layout instead.
	local function fit() grid.CanvasSize=UDim2.fromOffset(0,math.ceil(layout.AbsoluteContentSize.Y)+4) end
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
	self.fitGrid=function() task.defer(fit) end
	table.insert(self.connections,grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		local window=grid.AbsoluteWindowSize.Y
		if self.shown<#self.visible and grid.CanvasPosition.Y+window>=grid.AbsoluteCanvasSize.Y-window*0.5 then
			self.wanted=self.shown+PAGE;self:ShowCards()
		end
	end))
	self.empty=label(body,"Empty","",MUTED)
	rect(self.empty,GRID.x+40,GRID.y+150,GRID.w-80,60,BODY.w,BODY.h)
	self.empty.TextWrapped,self.empty.Visible=true,false
	Theme.Motion:Center(self.empty)

	self:BuildDetail()

	-- Bottom row, overhanging the body like the reference.
	self.best=button(root,"SelectBest","Equip Best",function()
		if not self:CanEdit() then return end
		self:ExitModes();self:Send("SelectBest")
	end,"Green")
	rect(self.best,122,504,190,53,W,H)
	self.unequip=button(root,"UnequipAll","Unequip All",function() self:UnequipAll() end,"Red")
	rect(self.unequip,325,504,195,53,W,H)
	self.compactButton=button(root,"Compact","",function()
		cue("TabSwitch","Click")
		self.compact=not self.compact
		self:Render(true)
	end,"Blue")
	self.compactButton:SetAttribute("ClickSound",false)
	rect(self.compactButton,632,504,55,53,W,H)
	Theme.Aspect(self.compactButton,55/53)
	-- Bottom row: 104 units (48 px) tall, from the grid's clipped edge (499) down past
	-- the window's foot (Unequip All and Compact hide while the mode bar covers them);
	-- Compact also grows left to 104 wide, short of the search box.
	for _,item in {self.best,self.unequip} do Theme.PadHit(item,1,104/53,0.5,5/51,true) end
	Theme.PadHit(self.compactButton,104/55,104/53,1,5/51,true)
	-- A small tile grid on the button: 2 x 2 normally, 3 x 3 when compact is on.
	self.compactIcon=frame(self.compactButton.Visual,"Icon",UDim2.fromScale(0.5,0.5),UDim2.fromScale(0.25,0.21))
	self.compactIcon.ZIndex=self.compactButton.Visual.ZIndex+6
	Theme.Aspect(self.compactIcon,1)
	local searchShell=rect(frame(root,"Search"),697,504,215,53,W,H)
	searchShell.ZIndex=body.ZIndex+6
	surface(searchShell,TONES.Blue[1],TONES.Blue[3],INK,3)
	Theme.Studs(searchShell,0.07,24,0).ZIndex=searchShell.ZIndex
	rect(image(searchShell,"SearchIcon",Art.Search),10,9,34,34,215,53)
	local search=Instance.new("TextBox")
	search.Name,search.Text,search.PlaceholderText="SearchChickens","","Search..."
	search.BackgroundTransparency,search.BorderSizePixel,search.ClearTextOnFocus=1,0,false
	search.Font,search.TextColor3,search.PlaceholderColor3=Theme.Font,WHITE,Color3.fromRGB(220,240,255)
	search.TextXAlignment,search.ZIndex,search.Parent=Enum.TextXAlignment.Left,searchShell.ZIndex+3,searchShell
	rect(search,50,6,158,40,215,53)
	Theme.ScaleText(search)
	local outline=Instance.new("UIStroke")
	outline.Name,outline.Color,outline.StrokeSizingMode,outline.Thickness="TextOutline",INK,Enum.StrokeSizingMode.ScaledSize,0.07
	outline.Parent=search
	self.search=search
	table.insert(self.connections,search:GetPropertyChangedSignal("Text"):Connect(function()
		self.query=string.lower(search.Text):match("^%s*(.-)%s*$") or ""
		self.wanted=PAGE;self.grid.CanvasPosition=Vector2.zero;self:Render(true)
	end))
	-- Engaging the search answers once (its rim lights up); keystrokes stay silent.
	local searchRim=searchShell:FindFirstChild("UIStroke")
	table.insert(self.connections,search.Focused:Connect(function()
		cue("TabSwitch","Click")
		if searchRim then Theme.Motion:Tween(searchRim,"focus",{Color=SELECTED},0.15) end
	end))
	table.insert(self.connections,search.FocusLost:Connect(function()
		if searchRim then Theme.Motion:Tween(searchRim,"focus",{Color=INK},0.2) end
	end))

	-- Lock, Sell and Replace modes: a bar over the bottom row with Confirm / Cancel.
	local bar=rect(frame(root,"ModeBar"),349,464,332,113,W,H)
	-- Active: a click on the bar never reaches Unequip All underneath.
	bar.ZIndex,bar.Visible,bar.Active=body.ZIndex+20,false,true
	surface(bar,TONES.Blue[1],TONES.Blue[3],INK,3)
	Theme.Studs(bar,0.14,28,0).ZIndex=bar.ZIndex
	self.bar,self.barRest=bar,bar.Position
	self.barTitle=rect(label(bar,"Title","Select Chickens",WHITE,true),10,6,312,44,332,113)
	self.confirm=button(bar,"Confirm","Confirm",function() self:ConfirmMode() end,"Green")
	self.confirm:SetAttribute("ClickSound",false)
	rect(self.confirm,12,54,150,50,332,113)
	self.cancel=button(bar,"Cancel","Cancel",function() self.app.audio:Play("Click");self:ExitModes();self:Render(true) end,"Red")
	rect(self.cancel,170,54,150,50,332,113)
	-- 104 units (48 px) tall, up over the bar's title and to its foot.
	for _,item in {self.confirm,self.cancel} do Theme.PadHit(item,1,104/50,0.5,48/54) end

	-- Results and refusals under the window ("9 Chickens Sold!").
	self.flash=label(root,"Result","",POWER,true)
	rect(self.flash,180,566,600,38,W,H)
	self.flash.Visible,self.flash.ZIndex=false,body.ZIndex+20

	Theme.ScaleText(root)
	-- After ScaleText: the tooltip's rows use measured TextSize, not TextScaled.
	self:BuildTooltip()
	local function visibilityChanged()
		if not root.Visible or not parent.Visible then
			self:ExitModes();self:HideTooltip()
			self.inspecting,self.app.selected=false,nil
			search:ReleaseFocus()
		end
	end
	table.insert(self.connections,root:GetPropertyChangedSignal("Visible"):Connect(visibilityChanged))
	table.insert(self.connections,parent:GetPropertyChangedSignal("Visible"):Connect(visibilityChanged))
	root.Destroying:Once(function()
		for _,connection in self.connections do connection:Disconnect() end
	end)
	return self
end

function Browser:BuildDetail()
	local detail=rect(frame(self.body,"SelectedChicken"),DETAIL.x,DETAIL.y,DETAIL.w,DETAIL.h,BODY.w,BODY.h)
	detail.ZIndex,detail.Visible,detail.Active=self.grid.ZIndex+10,false,true
	surface(detail,Color3.fromRGB(0,196,255),Color3.fromRGB(0,105,190),INK,3)
	Theme.Studs(detail,0.14,28,0).ZIndex=detail.ZIndex
	-- Same resting rect; the card pops open from its centre.
	Theme.Motion:Center(detail)
	self.detail=detail
	local close=button(detail,"CloseDetail","X",function()
		self.app.audio:Play("Click");self.inspecting,self.app.selected=false,nil;self:Render()
	end,"Red")
	rect(close,9,7,53,53,DETAIL.w,DETAIL.h)
	-- Phone hit areas in the detail card (48 px = 104 units): the X grows right and down
	-- (the Counts "+" hits sit above it); Equip grows up over the rarity lines; Lock
	-- takes what is left down to the bottom row's hits (78 units, 36 px).
	Theme.PadHit(close,104/53,104/53,0,0)
	Theme.Aspect(close,1)
	self.detailName=rect(label(detail,"Name","",WHITE,true),8,64,259,38,DETAIL.w,DETAIL.h)
	self.detailCard=rect(frame(detail,"Portrait"),83,106,109,109,DETAIL.w,DETAIL.h)
	Theme.Aspect(self.detailCard,1)
	self.detailRarity=rect(label(detail,"Rarity","",WHITE,true),8,222,259,30,DETAIL.w,DETAIL.h)
	self.detailRarity.RichText=true
	self.detailVariant=rect(label(detail,"Variant","",WHITE,true),8,254,259,30,DETAIL.w,DETAIL.h)
	self.equip=button(detail,"AssignChicken","Equip",function() self:EquipSelected() end,"Green")
	rect(self.equip,11,296,253,56,DETAIL.w,DETAIL.h)
	Theme.PadHit(self.equip,1,104/56,0.5,1)
	self.lockOne=button(detail,"LockChicken","Lock",function() self:LockSelected() end,"Gold")
	rect(self.lockOne,11,360,253,54,DETAIL.w,DETAIL.h)
	Theme.PadHit(self.lockOne,1,78/54,0.5,8/24)
end

-- Hover / gamepad tooltip: name, rarity and odds, a divider, then power and eggs.
-- Rows are sized from the window's current scale so the text matches the grid.
function Browser:BuildTooltip()
	local tip=Instance.new("Frame")
	tip.Name,tip.BorderSizePixel,tip.Visible="ChickenTooltip",0,false
	tip.AutomaticSize,tip.ZIndex,tip.Parent=Enum.AutomaticSize.Y,self.root.ZIndex+40,self.root
	surface(tip,Color3.fromRGB(33,49,58),Color3.fromRGB(16,26,33),SELECTED,3)
	local list=Instance.new("UIListLayout")
	list.SortOrder,list.HorizontalAlignment,list.Parent=Enum.SortOrder.LayoutOrder,Enum.HorizontalAlignment.Center,tip
	local padding=Instance.new("UIPadding");padding.Parent=tip
	local rows={}
	local function row(name,order,color)
		local item=Theme.Label(tip,name,"",20,color or WHITE)
		item.LayoutOrder,item.AutomaticSize,item.TextWrapped=order,Enum.AutomaticSize.Y,true
		item.TextXAlignment,item.ZIndex=Enum.TextXAlignment.Center,tip.ZIndex+2
		item.TextOutline.Color,item.TextOutline.Thickness=INK,0.07
		rows[name]=item
		return item
	end
	row("Name",1)
	row("Rarity",2).RichText=true
	local divider=frame(tip,"Divider");divider.LayoutOrder=3
	divider.BackgroundColor3,divider.BackgroundTransparency=Color3.fromRGB(132,154,167),0.4
	local function stat(name,order,asset,color)
		local line=frame(tip,name);line.LayoutOrder=order
		local layout=Instance.new("UIListLayout")
		layout.FillDirection,layout.HorizontalAlignment=Enum.FillDirection.Horizontal,Enum.HorizontalAlignment.Center
		layout.VerticalAlignment,layout.SortOrder,layout.Parent=Enum.VerticalAlignment.Center,Enum.SortOrder.LayoutOrder,line
		local icon=Theme.Image(line,"Icon",asset,UDim2.new());icon.ZIndex=tip.ZIndex+2
		local text=Theme.Label(line,"Value","",20,color)
		text.LayoutOrder,text.AutomaticSize,text.TextWrapped,text.ZIndex=2,Enum.AutomaticSize.X,false,tip.ZIndex+2
		text.TextOutline.Color,text.TextOutline.Thickness=INK,0.07
		rows[name]={line=line,icon=icon,text=text,layout=layout}
	end
	stat("Power",4,Art.Damage,POWER)
	stat("Eggs",5,EggArt.Image("Duck"),GOLD)
	row("Extra",6,SELECTED)
	self.tooltip,self.tipRows,self.tipDivider,self.tipPadding,self.tipList=tip,rows,divider,padding,list
end

function Browser:ShowTooltip(card,pet,point)
	if not self.root.Visible or self.app.state==nil then return end
	local definition=Catalog[pet.species]
	if not definition then return end
	local u=self.root.AbsoluteSize.Y/H
	if u<=0 then return end
	local tip,rows=self.tooltip,self.tipRows
	local width=310*u
	tip.Size=UDim2.fromOffset(width,0)
	local inner=width-24*u
	local pad=self.tipPadding
	pad.PaddingTop,pad.PaddingBottom=UDim.new(0,10*u),UDim.new(0,12*u)
	pad.PaddingLeft,pad.PaddingRight=UDim.new(0,12*u),UDim.new(0,12*u)
	self.tipList.Padding=UDim.new(0,4*u)
	for _,name in {"Name","Rarity","Extra"} do rows[name].Size=UDim2.fromOffset(inner,0) end
	rows.Name.Text,rows.Name.TextSize=displayName(pet),34*u
	local rarity=RARITIES[definition.rarity] or RARITIES.Common
	local oneIn=Catalog.OneInText(pet.species)
	rows.Rarity.TextSize=26*u
	rows.Rarity.Text=string.format('<font color="#%s">%s</font>%s',rarity:ToHex(),definition.rarity,if oneIn then " · "..oneIn else "")
	self.tipDivider.Size=UDim2.fromOffset(inner*0.92,2*u)
	for key,text in {Power=Theme.Number(power(pet)).." Power",
		-- October 21 one egg = one egg: stronger chickens lay more valuable eggs, not more.
		Eggs=Theme.CompactCoins(pet.eggValue or 0).."/egg"} do
		local stat=rows[key]
		stat.line.Size=UDim2.fromOffset(inner,40*u)
		stat.layout.Padding=UDim.new(0,6*u)
		stat.icon.Size=UDim2.fromOffset(34*u,34*u)
		stat.text.Size,stat.text.TextSize,stat.text.Text=UDim2.fromOffset(0,40*u),32*u,text
	end
	local mutation=Mutations.Get(pet.mutation)
	local extra={}
	table.insert(extra,"Lv. "..(pet.level or 1))
	if mutation then table.insert(extra,mutation.name.." · Eggs ×"..mutation.multiplier) end
	if Giant.IsColossal(pet.giantSize) then table.insert(extra,"Colossal · Army +"..math.floor(Giant.ColossalArmyDamage*100+0.5).."% damage") end
	if pet.laying then table.insert(extra,"Laying eggs in your Flock") end
	if pet.favorite then table.insert(extra,"Locked") end
	rows.Extra.TextSize,rows.Extra.Text=24*u,table.concat(extra,"\n")
	rows.Extra.TextColor3=if mutation then mutation.color else SELECTED
	-- The tooltip's corner sits at the pointer, as in the reference (the card's
	-- centre for gamepads), kept inside the game view.
	local origin=self.root.AbsolutePosition
	local at=point or (card.AbsolutePosition+card.AbsoluteSize/2)
	Theme.Motion:Appear(tip,true,0.85)
	local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1e4,1e4)
	local height=tip.AbsoluteSize.Y
	local x=math.min(at.X+6*u,viewport.X-width-4)
	local y=math.min(at.Y+6*u,viewport.Y-GuiService:GetGuiInset().Y-height-4)
	tip.Position=UDim2.fromOffset(x-origin.X,y-origin.Y)
	self.tipFor=card
end

function Browser:HideTooltip(card)
	if card==nil or self.tipFor==card then Theme.Motion:Appear(self.tooltip,false);self.tipFor=nil end
end

-- Opens Upgrades at the family's next tier; false once the family is maxed.
function Browser:OpenUpgrade(family): boolean
	local tree=self.app.state and self.app.state.upgradeTree
	local definition=Upgrades.Families and Upgrades.Families[family]
	if type(tree)~="table" or not definition then return false end
	local tier=tree.families and tree.families[family] or 0
	if tier>=#definition.tiers then return false end
	self.app.research:OpenNode(Upgrades.NodeId(family,tier+1))
	return true
end

function Browser:CanEdit(): boolean
	return self.app.state~=nil and self.pending==nil
end

-- Opening My Army never selects or equips anything; the detail card waits for a click.
function Browser:OpenInventory()
	if self.pending then return end
	self:ExitModes();self:HideTooltip()
	self.inspecting,self.app.selected=false,nil
	self.wanted=PAGE
	if self.grid then self.grid.CanvasPosition=Vector2.zero end
	-- The grid grows in once per open, never on every snapshot re-render.
	self.revealOnRender=true
end

-- `extra.cue`/`extra.fallback` replace the plain Click for confirms.
function Browser:Send(action,payload,extra)
	if self.pending then return end
	if extra and extra.cue then cue(extra.cue,extra.fallback) else self.app.audio:Play("Click") end
	local id=self.app:Request(action,payload)
	self.pending={id=id,at=os.clock(),action=action,extra=extra,before=table.clone(self.app.state.selectedIds or {})}
	self:UpdateAction()
end

-- A refusal: the line under the window, a "no" shake on `item` and the Locked cue.
function Browser:Deny(text,item)
	self:Flash(text)
	denied(item or self.flash)
end

-- Three to five coins fly from `from` (a GuiObject) into the HUD Coins readout.
function Browser:CoinsToHud(from,count)
	local app=self.app
	local gui=app.gui
	if not (app.hud and app.hud.money and gui and from and from.Parent) then return end
	local target=Theme.Motion:Point(gui,Theme.Motion:CenterOf(app.hud.money))
	local origin=Theme.Motion:Point(gui,Theme.Motion:CenterOf(from))
	cue("Whoosh",nil,nil,{voiceKey="CoinWhoosh",cooldown=0.3})
	for index=1,math.clamp(count or 4,3,5) do
		local spread=UDim2.fromScale((index-3)*0.012,0)
		Theme.Motion:Fly(gui,Theme.Assets.Coin,origin+spread,target,{seconds=0.5+index*0.04,arc=0.1,onArrive=function()
			if index==1 then cue("CoinPickup","Collect",1,{voiceKey="CoinArrive",cooldown=0.15,pitchVariance=0.05}) end
		end})
	end
end

function Browser:Receive(result)
	-- Every snapshot passes through here: keep the world mutation looks current.
	MutationVFX.SetOwnedMutations(self.app.state and self.app.state.pets)
	local pending=self.pending
	if not pending or not result or result.id~=pending.id then return end
	self.pending=nil
	-- A server refusal: AppController's toast already plays Error, so only the line and a shake.
	if not result.ok then self:Flash(result.message or "That didn't work. Try again.");Theme.Motion:Shake(self.flash,5);return end
	if pending.action=="Sell" then
		local count,total=pending.extra.count,pending.extra.total
		self:ExitModes()
		self:Flash(count.." "..(if count==1 then "Chicken" else "Chickens").." Sold! +"..Theme.CompactCoins(total))
		-- ActionFeedback's sale payoff already ticks the Coins; the flyers add the flight.
		self:CoinsToHud(self.flash,math.clamp(count,3,5))
	elseif pending.action=="Favorite" then
		local locking=pending.extra and pending.extra.locked==true
		self:ExitModes()
		self:Flash(result.message or "Done.",WHITE)
		cue(if locking then "Lock" else "Unlock","Click",if locking then 0.9 else 1.1)
		Theme.Motion:Punch(self.lockIcon,1.3,0.32)
		self.lockPop={ids=pending.extra and pending.extra.ids or {},locked=locking,at=os.clock()}
	elseif pending.action=="SetArmy" or pending.action=="SelectBest" then
		self.armyPop={before=pending.before,at=os.clock(),action=pending.action}
	end
end

-- A short line under the window; refusals shake it.
function Browser:Flash(text,color)
	self.flashToken+=1
	local token=self.flashToken
	self.flash.Text,self.flash.TextColor3,self.flash.Visible=text,color or POWER,true
	Theme.Motion:PopScale(self.flash,1.12)
	task.delay(2.5,function() if self.flashToken==token then self.flash.Visible=false end end)
end

function Browser:ExitModes()
	self.mode,self.placing,self.placingExpected=nil,nil,nil
	self.marked,self.markOrder={},{}
end

function Browser:SetMode(mode)
	if not self:CanEdit() then return end
	self.app.audio:Play("Click")
	local leaving=self.mode==mode
	self:ExitModes()
	if not leaving then self.mode=mode;self.inspecting,self.app.selected=false,nil end
	self:Render(true)
end

function Browser:Mark(pet)
	local id=pet.id
	if self.marked[id] then
		self.marked[id]=nil
		local index=table.find(self.markOrder,id)
		if index then table.remove(self.markOrder,index) end
	else
		if self.mode=="Sell" then
			local ok,reason=sellable(pet)
			if not ok then
				local entry=self.cards[id]
				self:Deny(reason,entry and entry.background)
				return
			end
		end
		self.marked[id]=true;table.insert(self.markOrder,id)
	end
	self:UpdateMarks()
	local entry=self.cards[id]
	if self.marked[id] then
		cue("Select","Click",nil,{pitchVariance=0.04})
		if entry then Theme.Motion:Punch(entry.mark,1.2,0.3) end
	else
		self.app.audio:Play("Click")
		if entry then Theme.Motion:PopScale(entry.card,0.94) end
	end
end

-- Marked chickens still owned (and, for Sell, still sellable) with the sale total.
function Browser:MarkedIds(): ({string},number,boolean)
	local ids,total,anyUnlocked={},0,false
	for index=#self.markOrder,1,-1 do
		local id=self.markOrder[index]
		local pet=self.app:Pet(id)
		if not pet or (self.mode=="Sell" and not sellable(pet)) then
			self.marked[id]=nil;table.remove(self.markOrder,index)
		end
	end
	for _,id in self.markOrder do
		local pet=self.app:Pet(id)
		table.insert(ids,id)
		total+=pet.refund or 0
		if not pet.favorite then anyUnlocked=true end
	end
	return ids,total,anyUnlocked
end

function Browser:ConfirmMode()
	if not self:CanEdit() then return end
	if self.mode=="Sell" or self.mode=="Lock" then
		local ids,total,anyUnlocked=self:MarkedIds()
		if #ids==0 then denied(self.confirm.Visual);return end
		Theme.Motion:Ripple(self.confirm,WHITE)
		if self.mode=="Sell" then
			-- The server rechecks ownership, protection and the exact total atomically.
			self:Send("Sell",{petIds=ids,expectedTotal=total,sparesOnly=true},{count=#ids,total=total,cue="Confirm",fallback="UIPurchase"})
		else
			self:Send("Favorite",{petIds=ids,locked=anyUnlocked},{ids=ids,locked=anyUnlocked,cue="Confirm",fallback="UIPurchase"})
		end
	end
end

function Browser:UnequipAll()
	if not self:CanEdit() then return end
	self:ExitModes()
	local current=self.app.state.selectedIds or {}
	if #current==0 then self:Deny("Your Army is already empty.",self.unequip.Visual);return end
	self:Send("SetArmy",{petIds={},expectedIds=table.clone(current)},{cue="Unequip",fallback="Click"})
end

function Browser:Inspect(id)
	self.app.audio:Play("Click")
	self.app.selected,self.inspecting=id,true
	self:Render()
	local entry=self.cards[id]
	if entry then local card=entry.card;task.defer(function() Theme.Motion:PopScale(card,1.05) end) end
end

function Browser:Tapped(pet)
	if self.mode=="Sell" or self.mode=="Lock" then self:Mark(pet)
	elseif self.mode=="Replace" then
		local ids=self.placingExpected or {}
		local slot=table.find(ids,pet.id)
		if not slot then
			local entry=self.cards[pet.id]
			self:Deny("Choose a checked Army chicken to replace.",entry and entry.background)
			return
		end
		self:Drop(self.placing,slot,false,ids)
	else self:Inspect(pet.id) end
end

function Browser:ColossalSlot(id)
	local pet=self.app:Pet(id)
	if not pet or not Giant.IsColossal(pet.giantSize) then return nil end
	for slot,otherId in self.app.state.selectedIds or {} do
		local other=self.app:Pet(otherId)
		if otherId~=id and other and Giant.IsColossal(other.giantSize) then return slot end
	end
	return nil
end

-- The detail card's Equip / Unequip. A full Army asks which chicken to replace.
function Browser:EquipSelected()
	local pet=self.app:Pet(self.app.selected)
	if not pet or not self:CanEdit() then return end
	local ids=self.app.state.selectedIds or {}
	local slot=table.find(ids,pet.id)
	if slot then self:Drop(pet.id,nil,true,ids)
	elseif self:ColossalSlot(pet.id) then self:Drop(pet.id,self:ColossalSlot(pet.id),false,ids)
	elseif #ids<self.app.state.capacity then self:Drop(pet.id,#ids+1,false,ids)
	else
		self.app.audio:Play("Click")
		self:ExitModes()
		self.mode,self.placing,self.placingExpected="Replace",pet.id,table.clone(ids)
		self.inspecting=false
		self.search.Text="";self.grid.CanvasPosition=Vector2.zero;self:Render(true)
	end
end

function Browser:LockSelected()
	local pet=self.app:Pet(self.app.selected)
	if not pet or not self:CanEdit() then return end
	self:Send("Favorite",{petIds={pet.id},locked=not pet.favorite},{ids={pet.id},locked=not pet.favorite})
end

function Browser:Drop(id,slot,leaveArmy,expected)
	if not self:CanEdit() then return end
	local current=self.app.state.selectedIds or {}
	if table.concat(current,"|")~=table.concat(expected,"|") then
		self:ExitModes();self:Deny("Your Army changed. Choose again.");self:Render(true);return
	end
	local ids=table.clone(expected)
	local old=table.find(ids,id)
	if slot then
		if old==slot then return end
		if old then
			if ids[slot] then ids[old],ids[slot]=ids[slot],id
			else table.remove(ids,old);table.insert(ids,id) end
		else ids[math.min(slot,#ids+1)]=id end
	elseif leaveArmy and old then table.remove(ids,old)
	else return end
	local colossals=0
	for _,petId in ids do local pet=self.app:Pet(petId);if pet and Giant.IsColossal(pet.giantSize) then colossals+=1 end end
	if colossals>Giant.MaxArmyColossals then self:Deny("Only 1 Colossal per Army.",self.equip.Visual);return end
	self:ExitModes()
	-- Leaving the Army answers with Unequip; joining or swapping with Equip.
	local joining=not (leaveArmy and old and not slot)
	self:Send("SetArmy",{petIds=ids,expectedIds=table.clone(expected)},{cue=if joining then "Equip" else "Unequip",fallback=if joining then "Pop" else "Click"})
end

function Browser:Card(pet,order,inArmy)
	local card=Instance.new("TextButton")
	card.Name,card.Text,card.AutoButtonColor="Chicken_"..pet.id,"",false
	card.BorderSizePixel,card.BackgroundTransparency,card.ClipsDescendants=0,1,true
	card.LayoutOrder,card.Selectable=order,true
	card.ZIndex,card.Parent=self.grid.ZIndex+1,self.grid
	local definition=Catalog[pet.species]
	local rarity=definition.rarity
	local color=RARITIES[rarity] or RARITIES.Common
	local background=Theme.Image(card,"RarityBackground",Art.Card[rarity] or Art.Card.Mythic,UDim2.fromScale(1,1))
	background.ScaleType,background.ZIndex=Enum.ScaleType.Stretch,card.ZIndex+1
	local portrait=Preview.Create(card,pet,UDim2.fromScale(1.04,1.04),UDim2.fromScale(-0.02,-0.06))
	Theme.Aspect(portrait,1)
	portrait.ZIndex=card.ZIndex+3
	if portrait:IsA("ViewportFrame") then portrait.Ambient,portrait.LightColor=Color3.fromRGB(202,216,229),Color3.new(1,1,1) end
	local value=label(card,"Power",Theme.Number(power(pet)),WHITE,true)
	rect(value,30,70,74,34,108,108)
	value.TextXAlignment,value.ZIndex=Enum.TextXAlignment.Right,card.ZIndex+6
	if inArmy then
		local check=image(card,"EquippedCheck",Art.Check)
		rect(check,3,3,34,34,108,108)
		check.ImageColor3,check.ZIndex=EQUIPPED,card.ZIndex+8
	end
	if pet.favorite then
		local lock=image(card,"Locked",Art.Padlock)
		rect(lock,78,3,27,27,108,108)
		lock.ZIndex=card.ZIndex+8
	end
	-- Laying in the Flock right now: the chicken's own egg in the corner.
	if pet.laying then
		local egg=image(card,"Laying",EggArt.Image(pet.species))
		rect(egg,4,78,24,24,108,108)
		egg.ZIndex=card.ZIndex+8
	end
	local mutation=MutationVFX.Badge(card,pet.mutation)
	if mutation then rect(mutation,26,4,56,16,108,108) end
	-- Lock / Sell marks: a dark cell under a padlock or a red X (centred so it punches in place).
	local mark=frame(card,"Mark",UDim2.fromScale(1,1),UDim2.fromScale(0.5,0.5))
	mark.AnchorPoint=Vector2.new(0.5,0.5)
	mark.BackgroundColor3,mark.BackgroundTransparency,mark.ZIndex,mark.Visible=Color3.new(),0.45,card.ZIndex+9,false
	local cross=label(mark,"Cross","X",POWER,true)
	rect(cross,14,8,80,80,108,108)
	cross.TextOutline.Thickness=0.1
	local padlock=image(mark,"Padlock",Art.Padlock)
	rect(padlock,24,18,60,60,108,108)
	local outline=frame(card,"StateOutline",UDim2.fromScale(1,1))
	outline.ZIndex=card.ZIndex+11
	local border=Theme.Stroke(outline,if inArmy then EQUIPPED else color,if inArmy then 2.5 else 2)
	border.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	-- `background` is what a refusal shakes: grid cells themselves are laid out.
	self.cards[pet.id]={card=card,border=border,color=color,inArmy=inArmy,mark=mark,cross=cross,padlock=padlock,background=background}
	card:SetAttribute("PetId",pet.id);card:SetAttribute("InArmy",inArmy)
	-- Tapped picks the cue itself (Select, Click or Locked).
	card:SetAttribute("ClickSound",false)
	card.Activated:Connect(function() self:Tapped(pet) end)
	card.MouseButton2Click:Connect(function() if not self.mode then self:Inspect(pet.id) end end)
	card.InputChanged:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseMovement then
			self:ShowTooltip(card,pet,Vector2.new(input.Position.X,input.Position.Y))
		end
	end)
	card.MouseLeave:Connect(function() self:HideTooltip(card) end)
	card.SelectionGained:Connect(function() self:ShowTooltip(card,pet) end)
	card.SelectionLost:Connect(function() self:HideTooltip(card) end)
	Theme.Motion:BindButton(card,Theme.Motion:ScaleOf(card),background)
	return card
end

-- Cards are added a page at a time as the grid scrolls.
function Browser:ShowCards()
	local target=math.min(#self.visible,self.wanted)
	for index=self.shown+1,target do
		local pet=self.visible[index]
		self:Card(pet,index,self.chosen[pet.id]~=nil)
	end
	self.shown=math.max(self.shown,target)
	self:UpdateMarks();self:Highlight();self.fitGrid()
end

function Browser:UpdateMarks()
	for id,entry in self.cards do
		local on=self.marked[id]==true
		entry.mark.Visible=on
		entry.cross.Visible,entry.padlock.Visible=self.mode=="Sell",self.mode=="Lock"
	end
	if self.mode=="Sell" or self.mode=="Lock" then
		local ids,_,anyUnlocked=self:MarkedIds()
		local count=#ids
		local noun=if count==1 then "Chicken" else "Chickens"
		self.barTitle.Text=if count==0 then "Select Chickens"
			elseif self.mode=="Sell" then "Sell "..count.." "..noun.."!"
			elseif anyUnlocked then "Lock "..count.." "..noun.."!" else "Unlock "..count.." "..noun.."!"
	end
end

function Browser:Highlight()
	for id,entry in self.cards do
		local viewing=self.inspecting and self.app.selected==id and not self.mode
		local replacing=self.mode=="Replace" and entry.inArmy
		local color=if viewing then SELECTED elseif replacing then WHITE elseif entry.inArmy then EQUIPPED else entry.color
		entry.border.Color=color
		entry.border.Thickness=if viewing or replacing then 3.5 elseif entry.inArmy then 2.5 else 2
	end
end

function Browser:UpdateAction()
	local state=self.app.state
	if not state then return end
	if self.pending and os.clock()-self.pending.at>5 then
		self.pending=nil;self:Flash("No response yet. Try again.")
	end
	local canEdit=self:CanEdit()
	local action=self.pending and self.pending.action
	enabled(self.best,canEdit);enabled(self.unequip,canEdit)
	self.best.Text=if action=="SelectBest" then "Equipping..." else "Equip Best"
	setTone(self.lock,if self.mode=="Lock" then "Green" else "Red")
	setTone(self.trash,if self.mode=="Sell" then "Green" else "Red")
	setTone(self.compactButton,if self.compact then "Green" else "Blue")
	for key,item in self.sortButtons do setTone(item,if self.sort==key then "Green" else "Dark") end
	local selecting=self.mode=="Sell" or self.mode=="Lock"
	local barShown=self.mode~=nil
	if barShown~=self.barShown then
		self.barShown=barShown
		-- The bar pops up from under the bottom row when a mode starts.
		if barShown then Theme.Motion:Slide(self.bar,self.barRest+UDim2.fromScale(0,0.05),self.barRest,0.3,Theme.Motion.Ease.Pop)
		else Theme.Motion:Cancel(self.bar,"slide");self.bar.Position=self.barRest end
	end
	self.bar.Visible=barShown
	-- The bar covers Unequip All and the compact toggle, as in the reference; they
	-- also hide so a click can never land on them by mistake.
	self.unequip.Visible,self.compactButton.Visible=self.mode==nil,self.mode==nil
	self.confirm.Visible=selecting
	-- y 6: the padded hit area's top (PadHit above lifted it 48 units over the art at 54).
	self.cancel.Position=if selecting then UDim2.fromScale(170/332,6/113) else UDim2.fromScale(91/332,6/113)
	enabled(self.confirm,canEdit);enabled(self.cancel,canEdit)
	self.confirm.Text=if action=="Sell" then "Selling..." elseif action=="Favorite" then "Saving..." else "Confirm"
	if self.mode=="Replace" then self.barTitle.Text="Replace which chicken?" end
	local pet=self.app:Pet(self.app.selected)
	if pet then
		local inArmy=table.find(state.selectedIds or {},pet.id)~=nil
		local full=#(state.selectedIds or {})>=state.capacity
		self.equip.Text=if action=="SetArmy" then "Saving..." elseif inArmy then "Unequip"
			elseif self:ColossalSlot(pet.id) then "Replace Colossal" elseif full then "Replace..." else "Equip"
		setTone(self.equip,if inArmy then "Red" else "Green")
		self.lockOne.Text=if action=="Favorite" then "Saving..." elseif pet.favorite then "Unlock" else "Lock"
		enabled(self.equip,canEdit);enabled(self.lockOne,canEdit)
	end
end

function Browser:RenderDetail(pet)
	local show=pet~=nil and self.inspecting and not self.mode
	local opening=show and not self.detailShown
	local switching=show and self.detailShown and self.detailFor~=pet.id
	self.detailShown,self.detailFor=show,if show then pet.id else nil
	self.detail.Visible=show
	if opening then Theme.Motion:PopScale(self.detail,0.88,0.28) end
	if self.detailPortrait then self.detailPortrait:Destroy();self.detailPortrait=nil end
	if not show then return end
	local definition=Catalog[pet.species]
	self.detailName.Text=displayName(pet)
	local rarity=RARITIES[definition.rarity] or RARITIES.Common
	local oneIn=Catalog.OneInText(pet.species)
	self.detailRarity.Text=string.format('<font color="#%s">%s</font>%s',rarity:ToHex(),definition.rarity,if oneIn then " · "..oneIn else "")
	local mutation=Mutations.Get(pet.mutation)
	self.detailVariant.Text=(if mutation then mutation.name else "Normal").." · Lv. "..(pet.level or 1)
	self.detailVariant.TextColor3=if mutation then mutation.color else WHITE
	-- The same tile as the grid, without the click behaviour (centred so it punches in place).
	local holder=frame(self.detailCard,"Tile",UDim2.fromScale(1,1),UDim2.fromScale(0.5,0.5))
	holder.AnchorPoint,holder.ClipsDescendants=Vector2.new(0.5,0.5),true
	local background=Theme.Image(holder,"RarityBackground",Art.Card[definition.rarity] or Art.Card.Mythic,UDim2.fromScale(1,1))
	background.ScaleType,background.ZIndex=Enum.ScaleType.Stretch,holder.ZIndex+1
	local portrait=Preview.Create(holder,pet,UDim2.fromScale(1.04,1.04),UDim2.fromScale(-0.02,-0.06))
	Theme.Aspect(portrait,1)
	portrait.ZIndex=holder.ZIndex+3
	local value=label(holder,"Power",Theme.Number(power(pet)),WHITE,true)
	rect(value,30,70,74,34,108,108)
	value.TextXAlignment,value.ZIndex=Enum.TextXAlignment.Right,holder.ZIndex+6
	Theme.ScaleText(value)
	local border=Theme.Stroke(holder,INK,3)
	border.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	self.detailPortrait=holder
	-- The portrait punches in when the card opens or shows another chicken.
	if opening or switching then Theme.Motion:Punch(holder,1.16,0.3) end
end

function Browser:FitCells()
	local look=if self.compact then LAYOUTS.Compact else LAYOUTS.Normal
	local gap=self.grid.AbsoluteSize.X*look.gap/GRID.w
	self.gridLayout.CellSize=UDim2.new(look.cell/GRID.w,0,0,100000) -- the aspect fits it by width
	self.gridLayout.CellPadding=UDim2.new(look.gap/GRID.w,0,0,math.floor(gap+1.5))
	self.fitGrid()
end

function Browser:Render(force)
	local state=self.app.state
	if not state then return end
	local ids=state.selectedIds or {}
	local pets,chosen={},{}
	for _,pet in state.pets or {} do pets[pet.id]=pet end
	for slot,id in ids do chosen[id]=slot end
	if self.app.selected and not pets[self.app.selected] then self.app.selected,self.inspecting=nil,false end
	if self.app.selected and not self.inspecting and not self.mode then self.inspecting=true end
	if self.mode=="Replace" and (not pets[self.placing] or table.concat(ids,"|")~=table.concat(self.placingExpected or {},"|")) then
		self:ExitModes()
	end
	self.app.panelTitle.Text="My Army"
	local flock=state.flock
	self.capacity.Text=#ids.."/"..state.capacity
	self.summary.Text=if flock then #(flock.ids or {}).."/"..(flock.size or 0) else "0/0"
	self:FitCells()
	local box=self.compactIcon
	local tiles=if self.compact then 3 else 2
	if box:GetAttribute("Tiles")~=tiles then
		box:SetAttribute("Tiles",tiles);clear(box)
		local size=1/tiles
		for index=0,tiles*tiles-1 do
			local tile=frame(box,"Tile",UDim2.fromScale(size*0.78,size*0.78),UDim2.fromScale((index%tiles)*size,math.floor(index/tiles)*size))
			tile.BackgroundColor3,tile.BackgroundTransparency=WHITE,0
			Theme.Stroke(tile,INK,1.5)
		end
	end
	local keys={table.concat(ids,","),tostring(state.capacity),self.query,self.sort,tostring(self.compact),tostring(self.mode)}
	if state.petsVersion~=nil then table.insert(keys,"v"..state.petsVersion)
	else
		for _,pet in state.pets or {} do
			table.insert(keys,pet.id..":"..pet.level..":"..tostring(pet.favorite)..":"..tostring(pet.laying)..":"..tostring(pet.mutation))
		end
	end
	local gridKey=table.concat(keys,"|")
	if force or gridKey~=self.gridKey then
		self.gridKey=gridKey
		self:HideTooltip()
		local scroll=self.grid.CanvasPosition
		clear(self.grid);self.cards={}
		local visible,score={},{}
		for _,pet in state.pets or {} do
			local definition=Catalog[pet.species]
			if not definition then continue end
			-- Player-facing words only: never internal species IDs such as "Duck".
			local mutation=Mutations.Get(pet.mutation)
			local text=string.lower(definition.name.." "..definition.rarity..(if mutation then " "..mutation.name else ""))
			if self.query=="" or string.find(text,self.query,1,true) then
				table.insert(visible,pet)
				score[pet.id]=if self.sort=="Eggs" then pet.eggValue or 0 else power(pet)
			end
		end
		table.sort(visible,function(a,b)
			-- The Army comes first, as the reference's equipped pets do.
			local aa,ba=chosen[a.id]~=nil,chosen[b.id]~=nil
			if aa~=ba then return aa end
			if score[a.id]~=score[b.id] then return score[a.id]>score[b.id] end
			return a.id<b.id
		end)
		self.visible,self.chosen,self.shown=visible,chosen,0
		self:ShowCards()
		self.grid.CanvasPosition=scroll
		local wasEmpty=self.empty.Visible
		self.empty.Visible=#visible==0
		self.empty.Text=if self.query~="" then "No matching chickens"
			else "No chickens yet. Roll chickens at the lever in your yard!"
		if self.empty.Visible and not wasEmpty then Theme.Motion:PopScale(self.empty,0.9) end
		if self.revealOnRender then
			self.revealOnRender=false
			Theme.Motion:Reveal(self.grid,{limit=32,window=0.4})
		end
	end
	self:RenderDetail(pets[self.app.selected])
	self:UpdateMarks();self:Highlight();self:UpdateAction()
	local pop=self.armyPop
	if pop then
		self.armyPop=nil
		if os.clock()-pop.at<1 then
			local was={}
			for _,id in pop.before do was[id]=true end
			-- Joined: a wash in the Army green; left: a grey wash. Equip Best sweeps
			-- the new Army in a wave and confirms once.
			local joined,left={},{}
			for id,entry in self.cards do
				if (was[id]==true)~=entry.inArmy then table.insert(if entry.inArmy then joined else left,entry.card) end
			end
			table.sort(joined,function(a,b) return a.LayoutOrder<b.LayoutOrder end)
			for _,card in left do Theme.Motion:Flash(card,UNEQUIPPED,0.4,0.45) end
			if pop.action=="SelectBest" then
				Theme.Motion:Stagger(joined,function(card) Theme.Motion:Flash(card,EQUIPPED,0.45,0.6) end,0.05,0.45)
				cue("Confirm","UIPurchase")
			else
				for _,card in joined do Theme.Motion:Flash(card,EQUIPPED,0.45,0.6) end
			end
			Theme.Motion:Punch(self.capacity,1.2,0.3)
		end
	end
	local lockPop=self.lockPop
	if lockPop then
		self.lockPop=nil
		if os.clock()-lockPop.at<1 then
			for _,id in lockPop.ids do
				local entry=self.cards[id]
				local padlock=entry and entry.card:FindFirstChild("Locked")
				if padlock then Theme.Motion:Punch(padlock,1.4,0.32)
				elseif entry then Theme.Motion:PopScale(entry.card,1.06) end
			end
		end
	end
end

return Browser
