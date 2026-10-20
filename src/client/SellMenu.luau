--!strict
-- October 20 Sell screen (docs/team/FUSE_REMOVAL_AND_SELL.md). Stevin's reference is
-- Drop a Fruit's "Sell Fruits" mode, copied 1:1: My Army's Sell button opens this
-- panel, clicks mark several chickens, "N Selected · Coins" totals them, Sell (N)
-- asks "Sell N Chickens?" and the server sells the exact IDs at the quoted total.
-- Only chickens the server marks sellable appear (never Army, Flock or favorites).
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local Theme=require(script.Parent.UITheme)
local Preview=require(script.Parent.ChickenPreview)
local MutationVFX=require(script.Parent.SpecialChickenVFX)
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local Catalog=require(Shared.PetCatalog)
local Mutations=require(Shared.MutationCatalog)
local WHITE=Color3.fromRGB(249,251,242)
local MUTED=Color3.fromRGB(181,205,223)
local GREEN=Theme.ReferenceColors.Army
local EDGE=Color3.fromRGB(66,119,149)
local INK=Color3.fromRGB(3,11,14)
local CYAN=Color3.fromRGB(0,223,255)
local GOLD=Theme.Colors.coins
local Art={
	Helmet="rbxassetid://80504375672119",
	Search="rbxassetid://111902627409710",
	CoinPile="rbxassetid://107445346366690", -- Pocket Coins (GOLD_COINS.md)
	-- S6's SellTrash icon (approved and uploaded October 20). Empty would show a SELL tag.
	Trash="rbxassetid://111469244237912",
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
	Red={Color3.fromRGB(255,102,84),Color3.fromRGB(243,36,59),Color3.fromRGB(142,16,40),Color3.fromRGB(255,180,186)},
	Purple={Color3.fromRGB(207,72,255),Color3.fromRGB(138,20,219),Color3.fromRGB(74,12,118),Color3.fromRGB(224,167,255)},
	Off={Color3.fromRGB(122,132,138),Color3.fromRGB(86,95,101),Color3.fromRGB(48,54,58),Color3.fromRGB(160,170,176)},
}
-- Storage holds up to 1,000 chickens; cards load a page at a time (as My Army does).
local PAGE=48
local COLUMNS=6
local SORTS={"Value","Name"}
-- Design units: the shared My Army panel (1274/876) drawn 1474 wide.
local W=1474
local H=1474*876/1274
local BH=H-121 -- Body below the shared 116-unit header and 5-unit foot.
local GRID_W=1414
local CELL_W=(GRID_W-(COLUMNS-1)*16)/COLUMNS
local CELL_H=CELL_W*220/210
local Menu={}
Menu.__index=Menu

local function frame(parent,name)
	local item=Instance.new("Frame")
	item.Name,item.BorderSizePixel,item.BackgroundTransparency=name,0,1
	item.ZIndex=parent.ZIndex+1;item.Parent=parent
	return item
end

local function label(parent,name,text,color,prominent)
	local item=Theme.Label(parent,name,text,24,color or WHITE)
	item.TextWrapped,item.TextScaled,item.TextTruncate=false,true,Enum.TextTruncate.None
	item.ZIndex=parent.ZIndex+4
	item.TextOutline.Color=INK
	item.TextOutline.Thickness=if prominent then 0.055 else 0.045
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

local function tone(item)
	local key=if not item.Active then "Off" else item:GetAttribute("SellTone") or "Green"
	local colors=TONES[key]
	Theme.ApplyReferenceAccent(item,ColorSequence.new(colors[1],colors[2]))
	local visual=item.Visual
	visual.LowerLip.BackgroundColor3=colors[3]
	visual.UIStroke.Color=INK
	visual.Face.InsetHighlight.UIStroke.Color=colors[4]
	visual.Face.InsetHighlight.UIStroke.Transparency=0.2
end

-- Same chunky button as My Army (Figma 456:3625), in green, red or purple.
local function button(parent,name,text,callback,key)
	local item
	item=Theme.ActionButton(parent,name,text,function() if item.Active then callback() end end,GREEN)
	item:SetAttribute("SellTone",key)
	item.TextColor3,item.ZIndex=WHITE,parent.ZIndex+5
	local visual=item.Visual
	visual.ZIndex,visual.BackgroundTransparency=item.ZIndex,1
	visual.UIStroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	visual.Face.Position,visual.Face.Size=UDim2.fromScale(0.006,0),UDim2.fromScale(0.988,0.94)
	visual.Face.ZIndex,visual.Face.ClipsDescendants=visual.ZIndex+2,true
	visual.LowerLip.Position,visual.LowerLip.Size=UDim2.fromScale(0.006,0.90),UDim2.fromScale(0.988,0.085)
	visual.LowerLip.ZIndex=visual.ZIndex+1
	local rim=visual.Face.InsetHighlight
	rim.Position,rim.Size,rim.ZIndex=UDim2.fromScale(0.025,0.06),UDim2.fromScale(0.95,0.88),visual.Face.ZIndex+2
	local caption=visual.Caption
	caption.Position,caption.Size=UDim2.fromScale(0.045,0.06),UDim2.fromScale(0.91,0.75)
	caption.ZIndex=visual.ZIndex+5
	caption.TextShadow.TextTransparency=0.35;caption.TextShadow.TextOutline.Enabled=false
	caption.TextFace.TextOutline.Thickness,caption.TextFace.TextOutline.Color=0.055,INK
	Theme.Studs(visual.Face,0.07,24,0).ZIndex=visual.Face.ZIndex+1
	Theme.ScaleText(item)
	tone(item)
	return item
end

local function enabled(item,value)
	item.Active,item.Selectable=value,value
	tone(item)
end

local function sellable(pet)
	return pet.canSell==true and not pet.favorite and not pet.selected and not pet.deployed and not pet.flock
		and pet.home~=false and type(pet.refund)=="number" and pet.refund>=0 and pet.refund<math.huge
end

local function divider(parent,name,x,y,width,height)
	local line=frame(parent,name)
	line.BackgroundColor3,line.BackgroundTransparency=Color3.fromRGB(132,154,167),0.55
	Theme.RelativeRect(line,x,y,width,2,width+2*x,height)
	return line
end

function Menu.new(app,parent)
	local self=setmetatable({app=app,parent=parent,chosen={},order={},cards={},query="",sort="Value",
		shown=PAGE,key="",connections={},alive=true},Menu)
	local root=Instance.new("Frame")
	root.Name,root.BackgroundTransparency,root.BorderSizePixel="SellMenu",1,0
	root.Visible,root.ZIndex,root.Parent=false,parent.ZIndex+1,parent
	root:SetAttribute("OwnsPopupStyle",true)
	self.root=root
	Theme.Aspect(root,1274/876)
	root.AnchorPoint,root.Position,root.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(1,1)
	-- My Army's backdrop: black at 10% transparency.
	local background=frame(root,"SellBackground")
	background.Size,background.BackgroundColor3,background.BackgroundTransparency=UDim2.fromScale(1,1),Color3.new(),0.1
	local header,title=Theme.Header(root,"Header","Sell Chickens",GREEN)
	Theme.ApplyReferenceAccent(header,ColorSequence.new(Color3.fromRGB(178,255,16),Color3.fromRGB(33,224,0)))
	header.PageIcon.Image,header.PageIcon.Visible=Art.Helmet,true
	self.header,self.title=header,title
	self.closeButton=Theme.HeaderClose(header,function() app.audio:Play("Click");app:ClosePanel() end)
	self.storage=label(header,"StorageCount","",WHITE,true)
	self.storage.TextXAlignment,self.storage.ZIndex=Enum.TextXAlignment.Right,header.ZIndex+4
	Theme.RelativeRect(self.storage,1040,20,300,76,1474,116)
	local body=frame(root,"SellContent")
	body.Size=UDim2.fromScale(1,1)
	self.body=body
	Theme.BelowHeader(header,body,1-5/H)
	-- "N Selected - 🪙 X" between two faint rules.
	for index,x in {40,1244} do
		local rule=frame(body,"Rule"..index)
		rule.BackgroundColor3,rule.BackgroundTransparency=Color3.fromRGB(140,160,170),0
		Theme.RelativeRect(rule,x,37,190,3,W,BH)
		local fade=Theme.Gradient(rule,Color3.new(1,1,1),Color3.new(1,1,1))
		fade.Rotation=0
		fade.Transparency=NumberSequence.new(if index==1 then 1 else 0.2,if index==1 then 0.2 else 1)
	end
	self.count=label(body,"SelectedCount","0 Selected -",WHITE,true)
	self.count.TextXAlignment=Enum.TextXAlignment.Right
	Theme.RelativeRect(self.count,240,12,450,52,W,BH)
	self.countCoin=Theme.CoinIcon(body,"SelectedCoin",UDim2.new())
	Theme.RelativeRect(self.countCoin,702,14,48,48,W,BH)
	Theme.Aspect(self.countCoin,1)
	self.countValue=label(body,"SelectedValue","0",GOLD,true)
	Theme.RelativeRect(self.countValue,760,12,420,52,W,BH)
	local panel=frame(body,"SellPanel")
	surface(panel,Color3.fromRGB(27,40,47),Color3.fromRGB(13,29,38),EDGE,2)
	local panelHeight=BH-76-110
	Theme.RelativeRect(panel,14,76,1446,panelHeight,W,BH)
	self.panel=panel
	local grid=Instance.new("ScrollingFrame")
	grid.Name,grid.BackgroundTransparency,grid.BorderSizePixel="SellableChickens",1,0
	grid.ScrollBarThickness,grid.ScrollBarImageColor3=0,MUTED
	grid.ScrollingDirection,grid.CanvasSize=Enum.ScrollingDirection.Y,UDim2.new()
	grid.AutomaticCanvasSize,grid.ClipsDescendants=Enum.AutomaticSize.None,true
	grid.ZIndex,grid.Parent=panel.ZIndex+1,panel
	Theme.RelativeRect(grid,16,14,GRID_W,panelHeight-28,1446,panelHeight)
	local layout=Instance.new("UIListLayout")
	layout.SortOrder,layout.FillDirection,layout.Padding=Enum.SortOrder.LayoutOrder,Enum.FillDirection.Vertical,UDim.new(0,0)
	layout.Parent=grid
	-- AutomaticCanvasSize undercounts aspect-constrained rows (ShopBrowser workaround).
	local function fit() grid.CanvasSize=UDim2.fromOffset(0,math.ceil(layout.AbsoluteContentSize.Y)) end
	table.insert(self.connections,layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit))
	self.fitGrid=function() task.defer(fit) end
	self.grid=grid
	self.empty=label(panel,"Empty","",MUTED)
	self.empty.TextWrapped,self.empty.TextXAlignment=true,Enum.TextXAlignment.Center
	Theme.RelativeRect(self.empty,120,panelHeight/2-60,1206,120,1446,panelHeight)
	-- Bottom bar, reference order: Search, Back, Sort, Sell (N).
	local barY=BH-96
	local searchShell=frame(body,"Search")
	surface(searchShell,Color3.fromRGB(28,42,49),Color3.fromRGB(24,38,45),Color3.fromRGB(142,175,193),Theme.Border.Card)
	Theme.RelativeRect(searchShell,14,barY,440,82,W,BH)
	local searchIcon=Theme.Image(searchShell,"SearchIcon",Art.Search,UDim2.new())
	searchIcon.ZIndex=searchShell.ZIndex+1
	Theme.RelativeRect(searchIcon,18,20,42,42,440,82)
	Theme.Aspect(searchIcon,1)
	local search=Instance.new("TextBox")
	search.Name,search.Text,search.PlaceholderText="SearchChickens","","Search…"
	search.BackgroundTransparency,search.BorderSizePixel,search.ClearTextOnFocus=1,0,false
	search.Font,search.TextColor3=Theme.Font,WHITE
	search.PlaceholderColor3,search.TextXAlignment=Color3.fromRGB(129,156,170),Enum.TextXAlignment.Left
	search.ZIndex,search.Parent=searchShell.ZIndex+3,searchShell
	Theme.RelativeRect(search,76,6,348,70,440,82)
	Theme.ScaleText(search)
	self.search=search
	self.back=button(body,"Back","Back",function()
		app.audio:Play("Click");app:OpenPage("Army")
	end,"Red")
	Theme.RelativeRect(self.back,488,barY,234,82,W,BH)
	self.sortButton=button(body,"Sort","Sort: Value",function()
		app.audio:Play("Click")
		self.sort=SORTS[(table.find(SORTS,self.sort) or 1)%#SORTS+1]
		self.grid.CanvasPosition=Vector2.zero;self:Render(true)
	end,"Purple")
	Theme.RelativeRect(self.sortButton,753,barY,338,82,W,BH)
	self.sell=button(body,"SellSelected","Sell (0)",function() self:Review() end,"Green")
	Theme.RelativeRect(self.sell,1122,barY,338,82,W,BH)
	for item,width in {[self.back]=234,[self.sortButton]=338,[self.sell]=338} do
		item.Visual.Face.StudClip.StudTexture:SetAttribute("StudScaleWidth",W/width)
	end
	self:BuildConfirm()
	self:BuildTooltip()
	table.insert(self.connections,search:GetPropertyChangedSignal("Text"):Connect(function()
		self.query=string.lower(search.Text):match("^%s*(.-)%s*$") or ""
		self.shown=PAGE;self.grid.CanvasPosition=Vector2.zero
		if root.Visible then self:Render(true) end
	end))
	table.insert(self.connections,root:GetPropertyChangedSignal("Visible"):Connect(function()
		if not root.Visible then self:Close() end
	end))
	return self
end

-- The reference confirmation: gold "Sell N Chickens?" card, "YOU WILL GET:", the
-- coin pile with "+X", then Sell! and Cancel. It covers the grid until answered.
function Menu:BuildConfirm()
	local shade=frame(self.root,"ConfirmSale")
	shade.Size,shade.ZIndex=UDim2.fromScale(1,1),self.root.ZIndex+40
	shade.BackgroundTransparency,shade.Active,shade.Visible=1,true,false
	local card=frame(shade,"Card")
	card.AnchorPoint,card.Position,card.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.53),UDim2.fromScale(708/W,1)
	Theme.Aspect(card,708/610)
	surface(card,Color3.fromRGB(26,30,33),Color3.fromRGB(10,12,14),INK,3)
	local top=frame(card,"Header")
	top.BackgroundColor3,top.BackgroundTransparency=Color3.new(1,1,1),0
	Theme.RelativeRect(top,0,0,708,86,708,610)
	Theme.ApplyReferenceAccent(top,Theme.ReferenceGradients.Base)
	Theme.Stroke(top,INK,2).BorderStrokePosition=Enum.BorderStrokePosition.Inner
	local studs=Theme.Studs(top,0.14,28,0)
	studs.ZIndex=top.ZIndex;studs:SetAttribute("StudScaleWidth",W/708)
	local coin=Theme.CoinIcon(top,"CoinIcon",UDim2.new())
	coin.ZIndex=top.ZIndex+3
	Theme.RelativeRect(coin,12,4,78,78,708,86)
	Theme.Aspect(coin,1)
	local heading=Theme.Display(top,"Title","Sell 0 Chickens?",40,WHITE)
	heading.ZIndex=top.ZIndex+3
	heading.TextFace.TextOutline.Color,heading.TextFace.TextOutline.Thickness=INK,0.055
	Theme.RelativeRect(heading,104,8,584,70,708,86)
	local get=Theme.Display(card,"YouWillGet","YOU WILL GET:",30,WHITE)
	get.ZIndex,get.TextXAlignment=card.ZIndex+3,Enum.TextXAlignment.Center
	Theme.RelativeRect(get,40,108,628,54,708,610)
	local pile=Theme.Image(card,"CoinPile",Art.CoinPile,UDim2.new())
	pile.ZIndex=card.ZIndex+2
	Theme.RelativeRect(pile,229,166,250,250,708,610)
	Theme.Aspect(pile,1)
	local amount=Theme.Display(card,"Amount","+0",56,GOLD)
	amount.ZIndex,amount.TextXAlignment=card.ZIndex+4,Enum.TextXAlignment.Center
	amount.TextFace.TextOutline.Color,amount.TextFace.TextOutline.Thickness=INK,0.07
	Theme.RelativeRect(amount,154,352,400,84,708,610)
	self.confirmSell=button(card,"ConfirmSell","Sell!",function() self:Confirm() end,"Green")
	Theme.RelativeRect(self.confirmSell,40,466,296,92,708,610)
	self.confirmCancel=button(card,"Cancel","Cancel",function()
		self.app.audio:Play("Click");self:HideConfirm()
	end,"Red")
	Theme.RelativeRect(self.confirmCancel,372,466,296,92,708,610)
	for _,item in {self.confirmSell,self.confirmCancel} do
		item.Visual.Face.StudClip.StudTexture:SetAttribute("StudScaleWidth",W/296)
	end
	self.confirmNote=label(card,"Note","",MUTED)
	self.confirmNote.TextXAlignment=Enum.TextXAlignment.Center
	Theme.RelativeRect(self.confirmNote,40,566,628,34,708,610)
	Theme.ScaleText(card)
	self.confirm,self.confirmCard,self.confirmTitle,self.confirmAmount=shade,card,heading,amount
end

-- Hover/gamepad tooltip, as in the reference: name, rarity and odds, earnings, level.
function Menu:BuildTooltip()
	local tip=frame(self.root,"ChickenTooltip")
	tip.Size,tip.ZIndex,tip.Visible=UDim2.fromScale(280/W,1),self.root.ZIndex+30,false
	Theme.Aspect(tip,280/330)
	surface(tip,Color3.fromRGB(33,49,58),Color3.fromRGB(20,32,40),INK,3)
	local parts={}
	local function line(name,y,height,color,prominent)
		local item=label(tip,name,"",color,prominent)
		item.TextXAlignment=Enum.TextXAlignment.Center
		Theme.RelativeRect(item,10,y,260,height,280,330)
		parts[name]=item
		return item
	end
	line("Name",8,44,WHITE,true)
	divider(tip,"Divider1",16,58,248,330)
	line("Rarity",64,30,WHITE)
	line("Odds",94,34,WHITE,true)
	divider(tip,"Divider2",16,134,248,330)
	local coin=Theme.CoinIcon(tip,"CoinIcon",UDim2.new())
	Theme.RelativeRect(coin,70,144,42,42,280,330)
	Theme.Aspect(coin,1)
	local value=label(tip,"Value","",GOLD,true)
	Theme.RelativeRect(value,118,142,150,46,280,330)
	parts.Value=value
	line("Caption",186,26,GOLD).Text="Per Second"
	divider(tip,"Divider3",16,220,248,330)
	line("Level",228,40,CYAN,true)
	line("Mutation",276,36,WHITE)
	local arrow=label(tip,"Pointer","◀",WHITE,true)
	arrow.TextXAlignment=Enum.TextXAlignment.Center
	parts.Pointer=arrow
	self.tooltip,self.tipParts=tip,parts
end

function Menu:ShowTooltip(card,pet)
	local definition=Catalog[pet.species]
	if not definition or not self.root.Visible or self.confirm.Visible then return end
	local parts,tip=self.tipParts,self.tooltip
	parts.Name.Text=definition.name
	parts.Rarity.Text,parts.Rarity.TextColor3=definition.rarity,RARITIES[definition.rarity] or RARITIES.Common
	parts.Odds.Text=Catalog.OneInText(pet.species) or ""
	parts.Value.Text=Theme.Number(pet.income or 0)
	parts.Level.Text="Level "..(pet.level or 1)
	local mutation=Mutations.Get(pet.mutation)
	parts.Mutation.Text=if mutation then mutation.name else ""
	parts.Mutation.TextColor3=if mutation then mutation.color else WHITE
	-- Beside the card, flipping left near the right edge; the arrow points at it.
	local rootPosition,rootSize=self.root.AbsolutePosition,self.root.AbsoluteSize
	if rootSize.X<1 or rootSize.Y<1 then return end
	local width=rootSize.X*280/W
	local height=width*330/280
	local right=card.AbsolutePosition.X+card.AbsoluteSize.X+width*0.12
	local flip=right+width>rootPosition.X+rootSize.X
	local x=if flip then card.AbsolutePosition.X-width*1.12 else right
	local y=math.clamp(card.AbsolutePosition.Y+card.AbsoluteSize.Y/2-height/2,rootPosition.Y,rootPosition.Y+rootSize.Y-height)
	tip.Position=UDim2.fromScale((x-rootPosition.X)/rootSize.X,(y-rootPosition.Y)/rootSize.Y)
	parts.Pointer.Text=if flip then "▶" else "◀"
	Theme.RelativeRect(parts.Pointer,if flip then 282 else -36,140,34,50,280,330)
	tip.Visible=true
	self.tipFor=card
end

function Menu:HideTooltip(card)
	if card==nil or self.tipFor==card then self.tooltip.Visible=false;self.tipFor=nil end
end

-- Called by AppController:OpenSell before the page opens. A sellable petId starts
-- selected (the inspector's Sell); otherwise nothing is selected.
function Menu:Begin(petId)
	if self.pending then return end
	self.chosen,self.order={},{}
	self.shown,self.search.Text=PAGE,""
	self:HideConfirm();self:HideTooltip()
	local pet=if type(petId)=="string" then self.app:Pet(petId) else nil
	if pet and sellable(pet) then self:Toggle(pet.id,true) end
	self.focusSelected=pet and self.chosen[pet.id] and pet.id or nil
	self.grid.CanvasPosition=Vector2.zero
end

function Menu:Sellable()
	local pets=(self.app.state and self.app.state.pets) or {}
	local cache=self.cache
	if cache and cache.pets==pets and cache.sort==self.sort then return cache.list end
	local list,power={},{}
	for _,pet in pets do
		if sellable(pet) then
			table.insert(list,pet)
			-- Once per chicken, not per comparison: storage can hold 1,000.
			power[pet.id]=Rules.PetPower(pet.species,pet.stars or 1,pet.level)
		end
	end
	local sort=self.sort
	table.sort(list,function(a,b)
		if sort=="Name" then
			local an,bn=Catalog[a.species].name,Catalog[b.species].name
			if an~=bn then return an<bn end
			if a.level~=b.level then return a.level>b.level end
		elseif a.refund~=b.refund then
			return a.refund>b.refund
		end
		if power[a.id]~=power[b.id] then return power[a.id]>power[b.id] end
		return a.id<b.id
	end)
	self.cache={pets=pets,sort=sort,list=list}
	return list
end

function Menu:Toggle(id,on)
	if on==nil then on=not self.chosen[id] end
	if on and not self.chosen[id] then
		self.chosen[id]=true;table.insert(self.order,id)
	elseif not on and self.chosen[id] then
		self.chosen[id]=nil
		local index=table.find(self.order,id)
		if index then table.remove(self.order,index) end
	end
end

-- Current quote of the selection, dropping chickens that stopped being sellable.
function Menu:Quote()
	local byId={}
	for _,pet in (self.app.state and self.app.state.pets) or {} do byId[pet.id]=pet end
	local ids,total={},0
	for index=#self.order,1,-1 do
		local id=self.order[index]
		local pet=byId[id]
		if not pet or not sellable(pet) then self.chosen[id]=nil;table.remove(self.order,index) end
	end
	for _,id in self.order do table.insert(ids,id);total+=byId[id].refund end
	return ids,total
end

function Menu:Card(parent,pet,order)
	local card=Instance.new("TextButton")
	card.Name,card.Text,card.AutoButtonColor="Chicken_"..pet.id,"",false
	local cellX,cellY=CELL_W/GRID_W,CELL_H/(CELL_H+16)
	card.AnchorPoint,card.Size,card.LayoutOrder=Vector2.new(0.5,0.5),UDim2.fromScale(cellX,cellY),order
	card.Position=UDim2.fromScale(((order-1)%COLUMNS)*(CELL_W+16)/GRID_W+cellX/2,cellY/2)
	Theme.Aspect(card,210/220)
	card.BorderSizePixel,card.BackgroundTransparency,card.ClipsDescendants=0,1,true
	card.ZIndex,card.Parent=parent.ZIndex+1,parent
	Theme.Round(card)
	local definition=Catalog[pet.species]
	local rarity=definition.rarity
	local color=RARITIES[rarity] or RARITIES.Common
	local background=Theme.Image(card,"RarityBackground",Art.Card[rarity] or Art.Card.Common,UDim2.fromScale(1,1))
	background.ScaleType,background.ZIndex=Enum.ScaleType.Stretch,card.ZIndex+1
	local ribbon=frame(card,"RarityRibbon")
	ribbon.Position,ribbon.Size,ribbon.ZIndex=UDim2.fromScale(6/210,6/220),UDim2.fromScale(198/210,26/220),card.ZIndex+2
	surface(ribbon,color,color:Lerp(Color3.new(0,0,0),0.22),Color3.fromRGB(7,16,22),Theme.Border.Detail)
	local rarityLabel=label(ribbon,"Rarity",string.upper(rarity),WHITE)
	rarityLabel.Size,rarityLabel.TextXAlignment=UDim2.fromScale(1,1),Enum.TextXAlignment.Center
	local portrait=Preview.Create(card,pet,UDim2.fromScale(224.4/210,224.4/220),UDim2.fromScale((210-224.4)/420,(32-224.4*0.16)/220))
	Theme.Aspect(portrait,1)
	portrait.ZIndex=card.ZIndex+3
	if portrait:IsA("ViewportFrame") then portrait.Ambient,portrait.LightColor=Color3.fromRGB(202,216,229),Color3.new(1,1,1) end
	local name=label(card,"Name",(definition.name:gsub(" Chicken$","")),WHITE)
	name.Position,name.Size,name.TextXAlignment=UDim2.fromScale(5/210,161/220),UDim2.fromScale(200/210,26/220),Enum.TextXAlignment.Center
	local stats=Rules.Stats(pet.species,pet.stars or 1,pet.level)
	local effects=self.app.state and self.app.state.research and self.app.state.research.effects
	local damage=stats.damage*(1+(effects and effects.damage or 0))
	local strength=label(card,"Damage",Theme.Number(damage/stats.interval).." DPS",Color3.fromRGB(255,221,96),true)
	strength.Position,strength.Size,strength.TextXAlignment=UDim2.fromScale(5/210,188/220),UDim2.fromScale(200/210,22/220),Enum.TextXAlignment.Center
	local mutation=MutationVFX.Badge(card,pet.mutation)
	if mutation then mutation.Position,mutation.Size=UDim2.fromScale(92/210,36/220),UDim2.fromScale(112/210,28/220) end
	-- Selected for sale: a dark cell under the red trash can (or a SELL tag until uploaded).
	local mark=frame(card,"SellMark")
	mark.Size,mark.ZIndex,mark.Visible=UDim2.fromScale(1,1),card.ZIndex+9,false
	mark.BackgroundColor3,mark.BackgroundTransparency=Color3.new(),0.3
	if Art.Trash~="" then
		local trash=Theme.Image(mark,"Trash",Art.Trash,UDim2.fromScale(0.62,0.62),UDim2.fromScale(0.19,0.17))
		trash.ZIndex=mark.ZIndex+1
		Theme.Aspect(trash,1)
	else
		local tag=frame(mark,"SellTag")
		tag.AnchorPoint,tag.Position,tag.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.45),UDim2.fromScale(0.62,0.22)
		surface(tag,TONES.Red[1],TONES.Red[2],INK,2)
		local text=label(tag,"Caption","SELL",WHITE,true)
		text.Size,text.TextXAlignment=UDim2.fromScale(1,1),Enum.TextXAlignment.Center
	end
	local outline=frame(card,"StateOutline")
	outline.Size,outline.ZIndex=UDim2.fromScale(1,1),card.ZIndex+11
	local border=Theme.Stroke(outline,color,Theme.Border.Card)
	border.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	self.cards[pet.id]={card=card,mark=mark}
	card.Activated:Connect(function()
		if self.pending or self.confirm.Visible then return end
		self.app.audio:Play("Click")
		self:Toggle(pet.id)
		self:UpdateSelection()
		Theme.Motion:PopScale(card,if self.chosen[pet.id] then 1.08 else 0.94)
	end)
	card.MouseEnter:Connect(function()
		if UserInputService.PreferredInput~=Enum.PreferredInput.Touch then self:ShowTooltip(card,pet) end
	end)
	card.MouseLeave:Connect(function() self:HideTooltip(card) end)
	card.SelectionGained:Connect(function() self:ShowTooltip(card,pet) end)
	card.SelectionLost:Connect(function() self:HideTooltip(card) end)
	Theme.Motion:BindButton(card,Theme.Motion:ScaleOf(card),background)
	return card
end

-- Marks, totals and buttons only; the grid is rebuilt by Render when it changes.
function Menu:UpdateSelection()
	local ids,total=self:Quote()
	for id,entry in self.cards do
		local on=self.chosen[id]==true
		entry.mark.Visible=on
	end
	self.count.Text=#ids.." Selected -"
	self.countValue.Text=Theme.Money(total)
	self.sell.Text=if self.pending then "Selling…" else "Sell ("..#ids..")"
	enabled(self.sell,self.pending==nil)
	enabled(self.sortButton,self.pending==nil)
	enabled(self.back,self.pending==nil)
	if self.confirm.Visible then self:RenderConfirm(ids,total) end
	return ids,total
end

function Menu:Render(force)
	local state=self.app.state
	if not state or not self.root.Visible then return end
	if self.pending and os.clock()-self.pending.at>8 then
		self.pending=nil;self:Note("No response yet. Try again.",false)
	end
	local all=self:Sellable()
	local visible={}
	for _,pet in all do
		local mutation=Mutations.Get(pet.mutation)
		local text=string.lower(Catalog[pet.species].name.." "..Catalog[pet.species].rarity..(if mutation then " "..mutation.name else ""))
		if self.query=="" or string.find(text,self.query,1,true) then table.insert(visible,pet) end
	end
	-- Keep a preselected chicken on screen even when it sorts past the first page.
	if self.focusSelected then
		for index,pet in visible do
			if pet.id==self.focusSelected then self.shown=math.max(self.shown,math.ceil(index/COLUMNS)*COLUMNS);break end
		end
		self.focusSelected=nil
	end
	local parts={self.sort,self.query,tostring(self.shown)}
	for index,pet in visible do
		if index>self.shown then break end
		table.insert(parts,pet.id..":"..pet.species..":"..tostring(pet.level)..":"..tostring(pet.refund)..":"..tostring(pet.mutation))
	end
	table.insert(parts,tostring(#visible))
	local key=table.concat(parts,"|")
	self.storage.Text=#(state.pets or {}).."/"..(state.collectionLimit or Config.CollectionLimit)
	self.sortButton.Text="Sort: "..self.sort
	if force or key~=self.key then
		self.key=key
		local scroll=self.grid.CanvasPosition
		for _,child in self.grid:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
		table.clear(self.cards);self:HideTooltip()
		local row
		for index,pet in visible do
			if index>self.shown then break end
			if (index-1)%COLUMNS==0 then
				row=frame(self.grid,"Row"..math.ceil(index/COLUMNS))
				row.Size,row.LayoutOrder=UDim2.fromScale(1,1),math.ceil(index/COLUMNS)
				Theme.Aspect(row,GRID_W/(CELL_H+16))
			end
			self:Card(row,pet,index)
		end
		if #visible>self.shown then
			local holder=frame(self.grid,"ShowMoreRow")
			holder.Size,holder.LayoutOrder=UDim2.fromScale(1,1),100000
			Theme.Aspect(holder,GRID_W/110)
			local more=button(holder,"ShowMore","Show more ("..(#visible-self.shown).." left)",function()
				self.app.audio:Play("Click");self.shown+=PAGE;self:Render(true)
			end,"Purple")
			more.AnchorPoint,more.Position,more.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(560/GRID_W,82/110)
			more.Visual.Face.StudClip.StudTexture:SetAttribute("StudScaleWidth",W/560)
		end
		self.grid.CanvasPosition=scroll
		self.fitGrid()
	end
	self.empty.Visible=#visible==0
	if #visible==0 then
		self.empty.Text=if self.query~="" then "No matching chickens" else self:EmptyReason()
	end
	self:UpdateSelection()
end

-- Why nothing can be sold: the starter minimum, else the standing protection rule.
function Menu:EmptyReason(): string
	for _,pet in (self.app.state and self.app.state.pets) or {} do
		if type(pet.saleReason)=="string" and string.find(pet.saleReason,"first mission",1,true) then return pet.saleReason end
	end
	return "Nothing to sell. Chickens in your Army or Flock and favorites are kept."
end

-- Hints and errors use the game's toast, like every other menu.
function Menu:Note(text,ok)
	self.app:Notify(text,ok)
end

function Menu:Review()
	if self.pending or self.confirm.Visible then return end
	local ids,total=self:UpdateSelection()
	if #ids==0 then
		Theme.Motion:Shake(self.sell.Visual,6)
		return
	end
	self.app.audio:Play("Click")
	self:HideTooltip()
	self.confirmNote.Text=""
	self.confirm.Visible=true
	self:RenderConfirm(ids,total)
	Theme.Motion:PopScale(self.confirmCard,0.9)
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=self.confirmSell end
end

function Menu:RenderConfirm(ids,total)
	self.confirmTitle.Text="Sell "..#ids.." "..(if #ids==1 then "Chicken" else "Chickens").."?"
	self.confirmAmount.Text="+"..Theme.CompactMoney(total)
	self.quote={ids=ids,total=total}
	enabled(self.confirmSell,self.pending==nil and #ids>0)
	enabled(self.confirmCancel,self.pending==nil)
	self.confirmSell.Text=if self.pending then "Selling…" else "Sell!"
	if #ids==0 and not self.pending then self:HideConfirm() end
end

function Menu:HideConfirm()
	if self.pending then return end
	self.confirm.Visible=false;self.quote=nil
	if UserInputService.GamepadEnabled and self.root.Visible then GuiService.SelectedObject=self.sell end
end

function Menu:Confirm()
	if self.pending or not self.confirm.Visible or not self.quote then return end
	local ids,total=self:Quote()
	if #ids==0 then self:HideConfirm();return end
	if total~=self.quote.total or #ids~=#self.quote.ids then
		-- The flock changed under the open card: show the new total before selling.
		self:RenderConfirm(ids,total);self.confirmNote.Text="Your chickens changed. Check the new total."
		Theme.Motion:Shake(self.confirmNote,5)
		return
	end
	self.app.audio:Play("Click")
	-- The server rechecks ownership, protection and the exact total atomically.
	self.pending={id=self.app:Request("Sell",{petIds=table.clone(ids),expectedTotal=total,sparesOnly=true}),at=os.clock()}
	self:UpdateSelection()
end

function Menu:Receive(result)
	local pending=self.pending
	if not pending or not result or result.id~=pending.id then return end
	self.pending=nil
	self.confirm.Visible=false;self.quote=nil
	if result.ok then
		-- Sold chickens leave the snapshot; anything left selected was refused already.
		self.chosen,self.order={},{}
		if self.root.Visible then
			Theme.Motion:PopScale(self.countValue,1.2)
			if UserInputService.GamepadEnabled then GuiService.SelectedObject=self.sell end
		end
	end
	-- AppController shows the reply as a toast and renders the page right after.
end

-- Leaving the page hides the card and tooltip. A request in flight still completes.
function Menu:Close()
	self.tooltip.Visible,self.tipFor=false,nil
	if not self.pending then self.confirm.Visible,self.quote=false,nil end
	self.search:ReleaseFocus()
end

function Menu:Destroy()
	self.alive=false
	for _,connection in self.connections do connection:Disconnect() end
	self.root:Destroy()
end

return Menu
