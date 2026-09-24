--!strict
-- Simulator-style inventory from the approved Figma Army frames.
-- The server still owns selection, capacity, stats and every transaction.
local UserInputService=game:GetService("UserInputService")
local Theme=require(script.Parent.UITheme)
local TextService=game:GetService("TextService")
local Preview=require(script.Parent.ChickenPreview)
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local Catalog=require(Shared.PetCatalog)
-- Approved Figma 221:2294, 1536 x 1024. Only this browser owns these local tokens.
local WHITE=Color3.fromRGB(249,251,242)
local MUTED=Color3.fromRGB(181,205,223)
local GREEN=Theme.ReferenceColors.Army
local CYAN=Theme.ReferenceColors.Upgrades
local RED=Color3.fromRGB(255,82,66)
local EDGE=Color3.fromRGB(66,119,149)
local INK=Color3.fromRGB(3,11,14)
local EQUIPPED=Color3.fromRGB(127,255,0)
local SELECTED=Color3.fromRGB(0,223,255)
local GOLD=Color3.fromRGB(255,221,96)
local DESIGN_WIDTH,DESIGN_HEIGHT=1536,1024
local Art={
	Helmet = "rbxassetid://80504375672119",
	Damage = "rbxassetid://127164621014549",
	Heart = "rbxassetid://137324953369813",
	Check = "rbxassetid://102978514196695",
	Search = "rbxassetid://111902627409710",
	Chevron = "rbxassetid://86650290654013",
	Card = {
		Common = "rbxassetid://122916116818277",
		Uncommon = "rbxassetid://125764068767248",
		Rare = "rbxassetid://99342664851264",
		Epic = "rbxassetid://81561273552383",
		Legendary = "rbxassetid://92160625350901",
		Mythic = "rbxassetid://89442120797640",
	},
	Glow = {
		Common = "rbxassetid://126574986960523",
		Uncommon = "rbxassetid://127046919144571",
		Rare = "rbxassetid://137602570995182",
		Epic = "rbxassetid://123023358078379",
		Legendary = "rbxassetid://79234091120170",
		Mythic = "rbxassetid://126020639842111",
	},
}
local RARITIES={
 Common=Color3.fromRGB(211,228,207),Uncommon=Color3.fromRGB(53,255,23),
 Rare=Color3.fromRGB(0,212,255),Epic=Color3.fromRGB(198,75,255),
 Legendary=Color3.fromRGB(255,213,0),Mythic=Color3.fromRGB(255,54,114),
}
local TONES={
 Green={Color3.fromRGB(165,255,0),Color3.fromRGB(38,227,0),Color3.fromRGB(40,125,6),Color3.fromRGB(217,255,154)},
 Blue={Color3.fromRGB(0,231,255),Color3.fromRGB(0,154,255),Color3.fromRGB(0,91,157),Color3.fromRGB(179,233,255)},
 Red={Color3.fromRGB(255,102,84),Color3.fromRGB(243,36,59),Color3.fromRGB(142,16,40),Color3.fromRGB(255,180,186)},
}
local Browser={}
Browser.__index=Browser

local function frame(parent,name,size,position)
 local item=Instance.new("Frame")
 item.Name,item.Size,item.Position=name,size,position or UDim2.new()
 item.BorderSizePixel,item.BackgroundTransparency=0,1
 item.ZIndex=parent.ZIndex+1;item.Parent=parent
 return item
end

local function label(parent,name,text,size,position,bounds,color,prominent)
 local item=Theme.Label(parent,name,text,size,color or WHITE)
 item.Position,item.Size=position,bounds
 item.TextColor3,item.TextSize=color or WHITE,size
 item.TextWrapped,item.TextScaled=false,false
 item.TextTruncate=Enum.TextTruncate.AtEnd
 item.ZIndex=parent.ZIndex+4
 local function outline()
  item.TextOutline.Color=INK
  item.TextOutline.Thickness=math.clamp(item.TextSize*(if prominent then 0.065 else 0.05),1,4)
 end
 item:GetPropertyChangedSignal("TextSize"):Connect(outline);outline()
 return item
end

-- TextScaled enables wrapping in Roblox; these Figma labels are single-line.
local function fitSingleLine(item,maximum,minimum)
 item.TextScaled,item.TextWrapped=false,false
 local function fit()
  local width=math.max(1,item.Size.X.Offset-4)
  local size=maximum
  while size>minimum and TextService:GetTextSize(item.Text,size,item.Font,Vector2.new(100000,100000)).X>width do
   size-=1
  end
  item.TextSize=size
 end
 item:GetPropertyChangedSignal("Text"):Connect(fit)
 item:GetPropertyChangedSignal("Size"):Connect(fit)
 fit()
end

local function surface(item,top,bottom,border,thickness,radius)
 item.BackgroundColor3,item.BackgroundTransparency=Color3.new(1,1,1),0
 Theme.Round(item).CornerRadius=UDim.new(0,radius or 0)
 local gradient=Theme.Gradient(item,top,bottom)
 gradient.Transparency=NumberSequence.new(0)
 local stroke=Theme.Stroke(item,border or EDGE,thickness or 1.5)
 stroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
 return stroke
end

local function dark(item,color,profile)
 local top,bottom=Color3.fromRGB(27,40,47),Color3.fromRGB(23,39,48)
 if profile=="Inspector" then top,bottom=Color3.fromRGB(20,38,47),Color3.fromRGB(33,52,61) end
 return surface(item,top,bottom,color or EDGE,1.5)
end

local function art(parent,name,asset,size,position)
 local image=Theme.Image(parent,name,asset,size,position)
 image.ZIndex=parent.ZIndex+1
 return image
end

local function figmaStuds(parent)
 local pattern=Theme.Studs(parent,0.14,50,0)
 pattern.ZIndex=parent.ZIndex+1
 return pattern
end

local function applyButtonColor(item)
 local color=item:GetAttribute("ArmyAccent")
 local tone=if color==RED then TONES.Red elseif color==CYAN then TONES.Blue else TONES.Green
 Theme.ApplyReferenceAccent(item,ColorSequence.new(tone[1],tone[2]))
 local visual=item.Visual
 visual.Face.UIGradient.Transparency=NumberSequence.new(if item.Active then 0 else 0.35)
 visual.LowerLip.BackgroundColor3=tone[3]
 visual.UIStroke.Color=INK
 visual.Face.InsetHighlight.UIStroke.Color=tone[4]
 visual.Face.InsetHighlight.UIStroke.Transparency=0.2
end

local function figmaButton(item)
 local visual=item.Visual
 visual.ZIndex=item.ZIndex
 visual.BackgroundColor3,visual.BackgroundTransparency=INK,0
 visual.UIStroke.Color,visual.UIStroke.BorderStrokePosition=INK,Enum.BorderStrokePosition.Inner
 Theme.Round(visual).CornerRadius=UDim.new(0,4)
 local face=visual.Face
 face.Position,face.Size=UDim2.fromOffset(2,0),UDim2.new(1,-4,1,-7)
 face.ZIndex,face.ClipsDescendants=visual.ZIndex+2,true
 Theme.Round(face).CornerRadius=UDim.new(0,3)
 local lip=visual.LowerLip
 lip.Position,lip.Size=UDim2.new(0,3,1,-11),UDim2.new(1,-6,0,8)
 lip.ZIndex=visual.ZIndex+1
 Theme.Round(lip).CornerRadius=UDim.new(0,2)
 local rim=face.InsetHighlight
 rim.Position,rim.Size,rim.ZIndex=UDim2.fromOffset(4,4),UDim2.new(1,-8,1,-8),face.ZIndex+2
 rim.UIStroke.Thickness=2
 Theme.Round(rim).CornerRadius=UDim.new(0,1)
 local caption=visual.Caption
 caption.Position,caption.Size=UDim2.fromOffset(8,0),UDim2.new(1,-16,1,-7)
 caption.TextColor3,caption.ZIndex=WHITE,visual.ZIndex+5
 caption.TextShadow.TextTransparency=0.35;caption.TextShadow.TextOutline.Enabled=false
 local function outline()
  caption.TextFace.TextOutline.Thickness=math.clamp(caption.TextSize*0.065,1.5,4)
  caption.TextFace.TextOutline.Color=INK
 end
 caption:GetPropertyChangedSignal("TextSize"):Connect(outline);outline()
 figmaStuds(face)
 applyButtonColor(item)
end

local function button(parent,name,text,callback,color)
 local item
 item=Theme.ActionButton(parent,name,text,function() if item.Active then callback() end end,color)
 item:SetAttribute("ArmyAccent",color)
 item.TextSize,item.TextColor3=32,WHITE
 item.ZIndex=parent.ZIndex+5
 figmaButton(item)
 return item
end

local function enabled(item,value)
 item.Active,item.Selectable=value,value
 applyButtonColor(item)
end

local function clear(parent)
	for _,item in parent:GetChildren() do if item:IsA("GuiObject") then item:Destroy() end end
end

local function inside(item,point)
	local p,s=item.AbsolutePosition,item.AbsoluteSize
	return item.Visible and point.X>=p.X and point.Y>=p.Y and point.X<=p.X+s.X and point.Y<=p.Y+s.Y
end

local function pointOf(input)
	return Vector2.new(input.Position.X,input.Position.Y)
end


function Browser.new(app,parent)
	local self=setmetatable({app=app,parent=parent,key="",pending=nil,connections={},slots={},cards={},
		suppressUntil=0,placing=nil,notice=nil,inspecting=false,showInfo=false,showCapacity=false,
		query="",sort="Best"},Browser)
	local root=Instance.new("Frame")
	root.Name,root.BackgroundTransparency,root.BorderSizePixel="ChickenBrowser",1,0
	root.Visible,root.ClipsDescendants=false,false
	root.ZIndex,root.Parent=parent.ZIndex+1,parent
	root:SetAttribute("OwnsPopupStyle",true)
	local scale=Instance.new("UIScale");scale.Parent=root
	self.root,self.pixelScale=root,scale
 local background=frame(root,"ArmyBackground",UDim2.fromOffset(1478,976),UDim2.fromOffset(29,22))
 surface(background,Color3.fromRGB(18,32,41),Color3.fromRGB(18,32,41),INK,3)
 local header,title=Theme.Header(root,"Header","Your Chickens!",GREEN)
 header.Position,header.Size=UDim2.fromOffset(31,25),UDim2.fromOffset(1474,83)
 header.ZIndex=root.ZIndex+2
 header.UIStroke.Color,header.UIStroke.BorderStrokePosition=INK,Enum.BorderStrokePosition.Inner
 Theme.ApplyReferenceAccent(header,ColorSequence.new(Color3.fromRGB(178,255,16),Color3.fromRGB(33,224,0)))
 figmaStuds(header)
 local headerRim=frame(header,"InsetHighlight",UDim2.new(1,-6,1,-5),UDim2.fromOffset(3,2))
 Theme.Stroke(headerRim,Color3.fromRGB(223,255,171),2).Transparency=0.28
 header.PageIcon.Image,header.PageIcon.Visible=Art.Helmet,true
 header.PageIcon.Position,header.PageIcon.Size=UDim2.fromOffset(21,7),UDim2.fromOffset(96,70)
 header.PageIcon.ZIndex=header.ZIndex+3
 title.Position,title.Size,title.TextColor3=UDim2.fromOffset(128,1),UDim2.fromOffset(1190,80),WHITE
 title.TextSize,title.ZIndex=64,header.ZIndex+4
 title.TextFace.TextOutline.Thickness,title.TextFace.TextOutline.Color=4,INK
 title.TextShadow.TextTransparency,title.TextShadow.TextOutline.Enabled=0.35,false
 self.header,self.title=header,title
 self.closeButton=button(header,"Close","X",function() app.audio:Play("Click");app:ClosePanel() end,RED)
 self.closeButton.Position,self.closeButton.Size,self.closeButton.TextSize=UDim2.fromOffset(1388,1),UDim2.fromOffset(86,82),62
 self.body=frame(root,"ArmyContent",UDim2.fromOffset(1474,875),UDim2.fromOffset(31,113))
 self.inventory=frame(self.body,"Inventory",UDim2.fromScale(1,1))
 local inventory=self.inventory
 self.toolbar=frame(inventory,"CapacityToolbar",UDim2.fromOffset(1474,85))
 surface(self.toolbar,Color3.fromRGB(27,39,45),Color3.fromRGB(32,45,53),Color3.fromRGB(3,11,16),2)
 self.flockLabel=label(self.toolbar,"FlockLabel","FLOCK",33,UDim2.fromOffset(27,10),UDim2.fromOffset(110,64),WHITE)
 self.summary=label(self.toolbar,"FlockCount","",36,UDim2.fromOffset(143,10),UDim2.fromOffset(137,64),WHITE,true)
 self.summary.RichText=true
 self.flockPlus=button(self.toolbar,"FlockCapacity","+",function()
  self.app.audio:Play("Click")
  local limit=self.app.state.collectionLimit or Config.CollectionLimit
  self.notice,self.noticeUntil="Flock storage is currently limited to "..limit.." chickens.",os.clock()+4
  self:UpdateAction()
 end,GREEN)
 self.flockPlus.Position,self.flockPlus.Size,self.flockPlus.TextSize=UDim2.fromOffset(278,13),UDim2.fromOffset(66,62),44
 local divider=frame(self.toolbar,"Divider",UDim2.fromOffset(2,43),UDim2.fromOffset(406,21))
 divider.BackgroundColor3,divider.BackgroundTransparency=Color3.fromRGB(132,154,167),0.1
 self.capacityLabel=label(self.toolbar,"CapacityLabel","ARMY",33,UDim2.fromOffset(454,10),UDim2.fromOffset(108,64),WHITE)
 self.capacity=label(self.toolbar,"ArmyCapacity","",36,UDim2.fromOffset(569,10),UDim2.fromOffset(102,64),WHITE,true)
 self.capacity.RichText=true
 self.capacityPlus=button(self.toolbar,"MoreArmySlots","+",function()
  self.app.audio:Play("Click");self:CancelPointer(true)
  self.showCapacity,self.showInfo,self.inspecting=true,false,false;self.placing=nil;self:Render(true)
 end,GREEN)
 self.capacityPlus.Position,self.capacityPlus.Size,self.capacityPlus.TextSize=UDim2.fromOffset(676,13),UDim2.fromOffset(66,62),44
 self.best=button(self.toolbar,"SelectBest","Select Best",function()
  if not self:CanEdit() then return end
  self.placing,self.placingExpected,self.saleQuote=nil,nil,nil
  self.search.Text="";self.grid.CanvasPosition=Vector2.zero;self:Send("SelectBest")
 end,GREEN)
 self.best.Position,self.best.Size=UDim2.fromOffset(975,13),UDim2.fromOffset(294,64)
 self.infoButton=button(self.toolbar,"ArmyInfo","Stats",function()
  self.app.audio:Play("Click");self:CancelPointer(true)
  self.showInfo,self.showCapacity,self.inspecting=true,false,false;self.placing=nil;self:Render(true)
 end,CYAN)
 self.infoButton.Position,self.infoButton.Size=UDim2.fromOffset(1280,13),UDim2.fromOffset(180,64)
 self.inventoryPanel=frame(inventory,"InventoryPanel",UDim2.fromOffset(903,791),UDim2.fromOffset(6,92))
 surface(self.inventoryPanel,Color3.fromRGB(27,40,47),Color3.fromRGB(23,39,48),EDGE,2)
 local inventoryRim=frame(self.inventoryPanel,"InnerLeftRim",UDim2.fromOffset(1,787),UDim2.fromOffset(3,2))
 inventoryRim.BackgroundColor3,inventoryRim.BackgroundTransparency=Color3.fromRGB(156,182,195),0.7
 local searchShell=frame(inventory,"Search",UDim2.fromOffset(584,60),UDim2.fromOffset(22,104))
 surface(searchShell,Color3.fromRGB(28,42,49),Color3.fromRGB(24,38,45),Color3.fromRGB(142,175,193),1.5,4)
 art(searchShell,"SearchIcon",Art.Search,UDim2.fromOffset(38,38),UDim2.fromOffset(16,12))
 local search=Instance.new("TextBox")
 search.Name,search.Text,search.PlaceholderText="SearchChickens","","Search..."
 search.BackgroundTransparency,search.BorderSizePixel,search.ClearTextOnFocus=1,0,false
 search.Font,search.TextSize,search.TextColor3=Theme.Font,27,WHITE
 search.PlaceholderColor3,search.TextXAlignment=Color3.fromRGB(129,156,170),Enum.TextXAlignment.Left
 search.Position,search.Size=UDim2.fromOffset(75,0),UDim2.fromOffset(480,60)
 search.ZIndex,search.Parent=searchShell.ZIndex+3,searchShell
 self.searchShell,self.search=searchShell,search
 local sort=Instance.new("TextButton")
 sort.Name,sort.Text,sort.AutoButtonColor="InventorySort","Best first",false
 sort.BorderSizePixel,sort.TextTransparency=0,1
 sort.Font,sort.TextSize,sort.TextColor3=Theme.Font,27,WHITE
 sort.Position,sort.Size=UDim2.fromOffset(620,104),UDim2.fromOffset(270,60)
 sort.ZIndex,sort.Parent=inventory.ZIndex+3,inventory
 surface(sort,Color3.fromRGB(34,49,58),Color3.fromRGB(21,32,40),Color3.fromRGB(140,167,184),1.5,4)
 self.sortButton=sort
 local sortCaption=label(sort,"Caption",sort.Text,27,UDim2.fromOffset(18,0),UDim2.fromOffset(195,60),WHITE)
 local function syncSort() sortCaption.Text=sort.Text end
 sort:GetPropertyChangedSignal("Text"):Connect(syncSort)
 art(sort,"Chevron",Art.Chevron,UDim2.fromOffset(34,24),UDim2.fromOffset(221,18))
 sort.Activated:Connect(function()
  self.app.audio:Play("Click")
  if self.placing then self.placing,self.placingExpected=nil,nil
  else self.sort=if self.sort=="Best" then "Name" else "Best" end
  self.grid.CanvasPosition=Vector2.zero;self:Render(true)
 end)
 local scrollTrack=frame(inventory,"InventoryScrollTrack",UDim2.fromOffset(15,704),UDim2.fromOffset(901,167))
 scrollTrack.BackgroundColor3,scrollTrack.BackgroundTransparency=Color3.fromRGB(38,63,77),0
 Theme.Round(scrollTrack).CornerRadius=UDim.new(0,7)
 local grid=Instance.new("ScrollingFrame")
 grid.Name,grid.BackgroundTransparency,grid.BorderSizePixel="ChickenInventory",1,0
 grid.Position,grid.Size=UDim2.fromOffset(19,179),UDim2.fromOffset(897,692)
 grid.ScrollBarThickness,grid.ScrollBarImageColor3=14,Color3.fromRGB(181,205,223)
 grid.ScrollingDirection,grid.CanvasSize=Enum.ScrollingDirection.Y,UDim2.new()
 grid.AutomaticCanvasSize,grid.ClipsDescendants=Enum.AutomaticSize.Y,true
 grid.ZIndex,grid.Parent=inventory.ZIndex+2,inventory
 self.grid=grid
 local padding=Instance.new("UIPadding")
 padding.PaddingLeft,padding.PaddingRight=UDim.new(0,0),UDim.new(0,21)
 padding.PaddingTop,padding.PaddingBottom=UDim.new(0,0),UDim.new(0,4);padding.Parent=grid
 local layout=Instance.new("UIGridLayout")
 layout.SortOrder,layout.FillDirection=Enum.SortOrder.LayoutOrder,Enum.FillDirection.Horizontal
 layout.CellSize,layout.CellPadding=UDim2.fromOffset(210,220),UDim2.fromOffset(12,16)
 layout.FillDirectionMaxCells,layout.Parent=4,grid
 self.gridLayout=layout
 self.hint=label(inventory,"InteractionHint","",23,UDim2.fromOffset(20,839),UDim2.fromOffset(866,34),MUTED)
 self.hint.BackgroundColor3,self.hint.BackgroundTransparency=Color3.fromRGB(20,32,41),0.05
 self.hint.ZIndex,self.hint.Visible=inventory.ZIndex+20,false
 table.insert(self.connections,search:GetPropertyChangedSignal("Text"):Connect(function()
  self.query=string.lower(search.Text):match("^%s*(.-)%s*$") or ""
  self.grid.CanvasPosition=Vector2.zero;self:Render(true)
 end))

	self.armyInfo=frame(self.body,"ArmyInfo",UDim2.fromScale(1,1))
	self.infoTitle=label(self.armyInfo,"Title","Your Army at a glance",30,UDim2.new(),UDim2.new(),WHITE,true)
	self.infoMode=label(self.armyInfo,"Mode","",17,UDim2.new(),UDim2.new(),MUTED)
	local function back()
		self.app.audio:Play("Click");self:CancelPointer(true)
		self.showInfo,self.showCapacity,self.inspecting=false,false,false
		self.app.selected,self.lastSelected,self.placing,self.placingExpected=nil,nil,nil,nil
		self:Render(true)
	end
	self.infoBack=button(self.armyInfo,"BackToChickens","Back to Chickens",back,Theme.ReferenceColors.Upgrades)
	self.statTiles={}
	for _,definition in {{"Damage","COMBINED DAMAGE",GREEN},{"Health","COMBINED HEALTH",Theme.ReferenceColors.Upgrades},
		{"Deployed","ARMY SELECTED",WHITE},{"Flock","TOTAL FLOCK",WHITE}} do
		local tile=frame(self.armyInfo,definition[1],UDim2.new());dark(tile,EDGE)
		self.statTiles[definition[1]]={
			frame=tile,title=label(tile,"Title",definition[2],14,UDim2.fromOffset(14,10),UDim2.new(1,-28,0,19),MUTED),
			value=label(tile,"Value","",40,UDim2.fromOffset(14,33),UDim2.new(1,-28,0,46),definition[3],true),
			note=label(tile,"Note","",15,UDim2.fromOffset(14,83),UDim2.new(1,-28,0,22),MUTED)}
	end
	self.rosterTitle=label(self.armyInfo,"RosterTitle","Current Army",27,UDim2.new(),UDim2.new(),WHITE,true)
	local roster=Instance.new("ScrollingFrame")
	roster.Name,roster.BackgroundTransparency,roster.BorderSizePixel="EquippedRoster",1,0
	roster.ScrollBarThickness,roster.ScrollBarImageColor3=4,GREEN
	roster.CanvasSize,roster.AutomaticCanvasSize=UDim2.new(),Enum.AutomaticSize.Y
	roster.ScrollingDirection,roster.ZIndex,roster.Parent=Enum.ScrollingDirection.Y,self.armyInfo.ZIndex+1,self.armyInfo
	local list=Instance.new("UIListLayout")
	list.SortOrder,list.Padding,list.Parent=Enum.SortOrder.LayoutOrder,UDim.new(0,12),roster
	self.infoRoster=roster
	self.infoFooter=label(self.armyInfo,"StatsScope","",16,UDim2.new(),UDim2.new(),MUTED)
	self.infoFooter.TextWrapped,self.infoFooter.TextTruncate=true,Enum.TextTruncate.None

	self.capacityPage=frame(self.body,"MoreArmySlots",UDim2.fromScale(1,1))
	self.passTitle=label(self.capacityPage,"Title","Bigger Army",32,UDim2.new(),UDim2.new(),WHITE,true)
	self.passBadge=label(self.capacityPage,"Type","GAMEPASS / +5 SLOTS",17,UDim2.new(),UDim2.new(),GREEN)
	self.passArt=Theme.Image(self.capacityPage,"BiggerArmy",Theme.Assets.Army,UDim2.fromOffset(140,140),UDim2.new())
	self.passArt.ZIndex=self.capacityPage.ZIndex+1
	self.passCopy=label(self.capacityPage,"Description","Bring more chickens into battle.",24,UDim2.new(),UDim2.new(),WHITE)
	self.passCopy.TextWrapped,self.passCopy.TextTruncate=true,Enum.TextTruncate.None
	self.passNote=label(self.capacityPage,"Availability",
		"Adds five slots to your army, up to 15 with coin upgrades. View the live price in Shop.",18,
		UDim2.new(),UDim2.new(),MUTED)
	self.passNote.TextWrapped,self.passNote.TextTruncate=true,Enum.TextTruncate.None
	self.passShop=button(self.capacityPage,"ViewInShop","View in Shop",function()
		self.app.audio:Play("Click");self.app:OpenPage("Shop")
	end,GREEN)
	self.passBack=button(self.capacityPage,"BackToChickens","Back",back,Theme.ReferenceColors.Upgrades)

 -- Fixed inline inspector. Equipment is represented by checks, never a Reserve badge.
 self.detail=frame(self.body,"SelectedChicken",UDim2.fromOffset(535,780),UDim2.fromOffset(931,95))
 self.detailBorder=dark(self.detail,Color3.fromRGB(23,199,238),"Inspector")
 self.detailBorder.Thickness=2
 local inset=frame(self.detail,"InsetRim",UDim2.new(1,-8,1,-8),UDim2.fromOffset(4,4))
 Theme.Stroke(inset,Color3.fromRGB(118,149,164),1).Transparency=0.75
 self.detailRibbon=frame(self.detail,"TitleRibbon",UDim2.fromOffset(516,76),UDim2.fromOffset(10,10))
 surface(self.detailRibbon,Color3.fromRGB(0,223,255),Color3.fromRGB(0,141,235),Color3.fromRGB(59,146,192),1)
 figmaStuds(self.detailRibbon)
 self.name=label(self.detailRibbon,"Name","Choose a chicken",50,UDim2.fromOffset(9,0),UDim2.fromOffset(498,76),WHITE,true)
 self.name.TextXAlignment=Enum.TextXAlignment.Center
 fitSingleLine(self.name,50,24)
 self.metadata=label(self.detail,"LevelRarity","",29,UDim2.fromOffset(18,92),UDim2.fromOffset(499,44),WHITE)
 self.metadata.TextXAlignment,self.metadata.RichText=Enum.TextXAlignment.Center,true
 self.detailNotice=label(self.detail,"Status","",19,UDim2.fromOffset(18,759),UDim2.fromOffset(499,20),MUTED)
 self.detailNotice.TextXAlignment=Enum.TextXAlignment.Center
 self.detailHalo=art(self.detail,"RarityGlow",Art.Glow.Rare,UDim2.fromOffset(326,326),UDim2.fromOffset(105,136))
 self.detailHalo.ZIndex=self.detail.ZIndex+2
 self.stats=frame(self.detail,"CombatStats",UDim2.fromOffset(496,86),UDim2.fromOffset(20,466))
 local damage=frame(self.stats,"DamageTile",UDim2.fromOffset(243,86))
 local health=frame(self.stats,"HealthTile",UDim2.fromOffset(241,86),UDim2.fromOffset(255,0))
 for _,tile in {damage,health} do
  surface(tile,Color3.fromRGB(22,48,59),Color3.fromRGB(23,36,46),Color3.fromRGB(77,138,165),1.5,4)
 end
 art(damage,"DamageIcon",Art.Damage,UDim2.fromOffset(74,70),UDim2.fromOffset(16,8))
 art(health,"HealthIcon",Art.Heart,UDim2.fromOffset(70,58),UDim2.fromOffset(18,13))
 self.damageValue=label(damage,"Damage","-- DPS",35,UDim2.fromOffset(108,0),UDim2.fromOffset(130,84),WHITE,true)
 self.healthValue=label(health,"Health","-- HP",35,UDim2.fromOffset(104,0),UDim2.fromOffset(133,84),WHITE,true)
 for _,value in {self.damageValue,self.healthValue} do
  fitSingleLine(value,35,16)
 end
 self.assign=button(self.detail,"AssignChicken","Equip",function() self:AssignSelected() end,GREEN)
 self.assign.Position,self.assign.Size,self.assign.TextSize=UDim2.fromOffset(20,570),UDim2.fromOffset(496,100),49
 self.sell=button(self.detail,"SellChicken","Sell",function() self:ReviewSale() end,RED)
 self.sell.Position,self.sell.Size,self.sell.TextSize=UDim2.fromOffset(100,684),UDim2.fromOffset(340,76),40
 self.mergeHint=label(self.detail,"MergeHint","",12,UDim2.new(),UDim2.new(),MUTED)
 self.mergeHint.Visible=false
	self.salePanel=frame(self.detail,"ConfirmSale",UDim2.new())
	dark(self.salePanel,RED)
	self.salePrompt=label(self.salePanel,"Quote","",14,UDim2.fromOffset(10,6),UDim2.new(1,-20,0,80),WHITE)
	self.salePrompt.TextWrapped,self.salePrompt.TextTruncate=true,Enum.TextTruncate.None
	self.salePrompt.TextYAlignment=Enum.TextYAlignment.Top
	self.saleConfirm=button(self.salePanel,"ConfirmSale","Confirm sale",function() self:ConfirmSale() end,RED)
	self.saleConfirm.Position,self.saleConfirm.Size=UDim2.fromOffset(10,88),UDim2.new(1,-20,0,48)
	self.saleCancel=button(self.salePanel,"KeepChicken","Keep chicken",function()
		self.app.audio:Play("Click");self.saleQuote=nil;self:UpdateAction()
	end,CYAN)
	self.saleCancel.Position,self.saleCancel.Size=UDim2.fromOffset(10,142),UDim2.new(1,-20,0,48)
	self.salePanel.Visible=false
	table.insert(self.connections,UserInputService.InputChanged:Connect(function(input) self:PointerChanged(input) end))
	table.insert(self.connections,UserInputService.InputEnded:Connect(function(input) self:PointerEnded(input) end))
	table.insert(self.connections,UserInputService.WindowFocusReleased:Connect(function() self:CancelPointer(true) end))
	local function visibilityChanged()
		if not root.Visible or not parent.Visible then
			self:CancelPointer(true);self.placing,self.placingExpected=nil,nil
			self.showInfo,self.showCapacity,self.inspecting=false,false,false
			self.app.selected,self.lastSelected=nil,nil
			search:ReleaseFocus()
		end
	end
	table.insert(self.connections,root:GetPropertyChangedSignal("Visible"):Connect(visibilityChanged))
	table.insert(self.connections,parent:GetPropertyChangedSignal("Visible"):Connect(visibilityChanged))
	root.Destroying:Once(function()
		self:CancelPointer(true)
		for _,connection in self.connections do connection:Disconnect() end
	end)
	return self
end

function Browser:CanEdit()
	local state=self.app.state
	if not state or self.pending then return false end
	return true
end


function Browser:OpenInventory()
	-- This is an explicit navigation action, never a state-refresh side effect.
	-- Inspection selection is local UI state; it does not equip or sell a chicken.
	if self.pending then return end
	local state=self.app.state
	if not state then return end
	self:CancelPointer(true)
	local pet=self.app:Pet(self.app.selected)
	if not pet then
		local equipped={}
		for _,id in state.selectedIds or {} do equipped[id]=true end
		local bestEquipped,bestPower=false,-math.huge
		for _,candidate in state.pets or {} do
			local isEquipped=equipped[candidate.id]==true or candidate.selected==true
			local power=Rules.PetPower(candidate.species,candidate.stars,candidate.level)
			if not pet or (isEquipped and not bestEquipped)
				or (isEquipped==bestEquipped and (power>bestPower or (power==bestPower and candidate.id<pet.id))) then
				pet,bestEquipped,bestPower=candidate,isEquipped,power
			end
		end
	end
	local id=if pet then pet.id else nil
	if self.app.selected~=id then self.saleQuote=nil end
	self.app.selected,self.lastSelected=id,id
	self.inspecting,self.showInfo,self.showCapacity=pet~=nil,false,false
	self.placing,self.placingExpected=nil,nil
end

function Browser:Resize()
 -- Preserve the approved canvas and four-column landscape inventory at every size.
 local width,bodyHeight=1474,875
 self.pixelScale.Scale=self.parent.Size.X.Offset/DESIGN_WIDTH
 self.root.Position,self.root.Size=UDim2.new(),UDim2.fromOffset(DESIGN_WIDTH,DESIGN_HEIGHT)
 self.width,self.height,self.narrow=width,bodyHeight,false
 local inventoryVisible=not self.showInfo and not self.showCapacity
 self.inventory.Visible,self.detail.Visible=inventoryVisible,inventoryVisible
 self.armyInfo.Visible,self.capacityPage.Visible=self.showInfo,self.showCapacity
 self.cellWidth,self.cellHeight=210,220
 self.previewPosition,self.previewSize=UDim2.fromOffset(125,156),UDim2.fromOffset(286,286)
 local function place(item,x,y,w,h) item.Position,item.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h) end
	local infoBackWidth=if width>=700 then 230 else 116
	place(self.infoTitle,0,0,width-infoBackWidth-14,37)
	self.infoTitle.TextSize=if width>=700 then 30 else 23
	place(self.infoMode,1,42,width-infoBackWidth-12,25)
	place(self.infoBack,width-infoBackWidth,4,infoBackWidth,50)
	self.infoBack.Text=if width>=700 then "Back to Chickens" else "Back"
	local statColumns=if width>=700 then 4 else 2
	local tileWidth=math.floor((width-12*(statColumns-1))/statColumns)
	local tileHeight=if statColumns==4 then 116 else 96
	for index,name in {"Damage","Health","Deployed","Flock"} do
		local tile=self.statTiles[name]
		place(tile.frame,((index-1)%statColumns)*(tileWidth+12),86+math.floor((index-1)/statColumns)*(tileHeight+12),tileWidth,tileHeight)
		tile.value.TextSize=if statColumns==4 then 40 else 32
		place(tile.value,14,31,tileWidth-28,44)
		place(tile.note,14,tileHeight-28,tileWidth-28,23)
	end
	local rosterTitleY=86+math.ceil(4/statColumns)*(tileHeight+12)+8
	place(self.rosterTitle,0,rosterTitleY,width,34)
	place(self.infoRoster,0,rosterTitleY+42,width,math.max(80,bodyHeight-rosterTitleY-106))
	place(self.infoFooter,0,bodyHeight-54,width,50)
	self.infoFooter.TextSize=if width>=700 then 16 else 14

	local passWidth=math.min(width,620)
	local passX=math.floor((width-passWidth)/2)
	place(self.passTitle,passX,0,passWidth,40)
	place(self.passBadge,passX,46,passWidth,24)
	place(self.passArt,passX,88,if passWidth>=440 then 144 else 90,140)
	local copyX=if passWidth>=440 then 166 else 106
	place(self.passCopy,passX+copyX,98,passWidth-copyX,100)
	place(self.passNote,passX,238,passWidth,66)
	place(self.passShop,passX,bodyHeight-58,math.floor(passWidth*0.61),52)
	place(self.passBack,passX+math.floor(passWidth*0.65),bodyHeight-58,math.floor(passWidth*0.35),52)

 place(self.salePanel,20,466,496,294)
 place(self.salePrompt,14,10,468,114);self.salePrompt.TextSize=26
 place(self.saleConfirm,12,132,472,70);self.saleConfirm.TextSize=32
 place(self.saleCancel,12,212,472,68);self.saleCancel.TextSize=30
 return width..":"..bodyHeight..":"..tostring(self.inspecting)..":"..tostring(self.showInfo)..":"..tostring(self.showCapacity)
end

function Browser:Send(action,payload)
	if self.pending then return end
	self.app.audio:Play("Click")
	local id=self.app:Request(action,payload)
	self.pending={id=id,at=os.clock(),action=action,petId=if action=="Sell" and payload then payload.petIds[1] else nil}
	if action~="Sell" then self.saleQuote=nil end
	self.notice=nil
	self:UpdateAction()
end

function Browser:Receive(result)
	if self.pending and result and result.id==self.pending.id then
		local pending=self.pending
		self.pending=nil
		if pending.action=="Sell" then
			self.saleQuote=nil
			if result.ok and (self.app.selected==pending.petId or self.lastSelected==pending.petId) then
				self.app.selected,self.lastSelected,self.inspecting=nil,nil,false
			end
		end
		self.notice=if result.ok then nil else result.message
		self.noticeUntil=os.clock()+4
	end
end

function Browser:UpdateAction()
	local state=self.app.state
	if not state then return end
	if self.pending and os.clock()-self.pending.at>5 then
		self.pending=nil;self.saleQuote=nil
		self.notice="No response yet. Try again.";self.noticeUntil=os.clock()+4
	end
	if self.notice and os.clock()>(self.noticeUntil or 0) then self.notice=nil end
	local pet=self.app:Pet(self.app.selected)
	if self.saleQuote and not self.pending and not self:SaleQuoteValid() then
		self.saleQuote=nil
		self.notice,self.noticeUntil="Your flock changed. Review the chicken again.",os.clock()+4
	end
	local canEdit=self:CanEdit()
	enabled(self.best,canEdit)
	self.best.Text=if self.pending and self.pending.action=="SelectBest" then "Selecting..." else "Select Best"
	self.hint.Text=if self.notice then self.notice
		elseif self.pending then (if self.pending.action=="Sell" then "Selling chicken..." else "Updating army...")
		elseif self.placing then "Choose a green-checked chicken to replace, or tap Cancel."
		elseif not canEdit then "Updating army..."
		else ""
	self.hint.Visible=self.hint.Text~=""
	self.hint.TextColor3=if self.notice then Color3.fromRGB(255,120,132) else MUTED
	self.detailNotice.Text=if self.notice then self.notice
		elseif self.pending then "Updating..."
		elseif pet and not self:SaleEligible(pet) then pet.saleReason or "This chicken is protected."
		else ""
	self.detailNotice.TextColor3=self.hint.TextColor3
	enabled(self.assign,canEdit and pet~=nil)
	self.assign.Text=if pet and pet.selected then "Unequip"
		elseif #(state.selectedIds or {})>=state.capacity then "Replace..." else "Equip"
	-- A home reserve can be sold even while the rest of the squad is away.
	local canSell=self.pending==nil and self:SaleEligible(pet)
	enabled(self.sell,canSell)
	self.sell.Text=if self.pending and self.pending.action=="Sell" then "Selling..." else "Sell"
	local reviewing=self.saleQuote~=nil
	self.salePanel.Visible=reviewing
	self.stats.Visible,self.assign.Visible,self.sell.Visible=not reviewing,not reviewing,not reviewing
	self.detailNotice.Visible=not reviewing
	enabled(self.saleConfirm,canSell and reviewing)
	enabled(self.saleCancel,self.pending==nil)
	if self.saleQuote then
		local quote=self.saleQuote
		self.salePrompt.Text="Sell "..quote.name.." permanently?\nHome egg income -$"..Theme.Money(quote.income).."/s."
		self.saleConfirm.Text=if self.pending then "Selling..." else "Sell for $"..Theme.Money(quote.refund)
	end
	self.mergeHint.Text=""
	if Config.Features.Merging and pet then
		local levelCap=pet.levelCap or (state.progression and state.progression.levelCap) or Config.MaxPetLevel
		self.mergeHint.Text=if pet.level>=Config.MaxPetLevel then "Max level"
			elseif pet.level>=levelCap then "Rank cap reached. Conquer to unlock higher merge levels."
			else "Merge matching chickens at the Merge Stand to level up."
	end
end

function Browser:SaleEligible(pet)
	return pet~=nil and pet.canSell==true and not pet.selected and not pet.favorite
		and not pet.deployed and pet.home~=false and type(pet.refund)=="number"
		and pet.refund>=0 and pet.refund<math.huge
end

function Browser:SaleQuoteValid()
	local quote=self.saleQuote
	if not quote or self.app.selected~=quote.id or not self.app.state then return false end
	local pet=self.app:Pet(quote.id)
	return self:SaleEligible(pet) and pet.level==quote.level and pet.refund==quote.refund
		and self.app:PetIncome(pet)==quote.income
end

function Browser:ReviewSale()
	local pet=self.app:Pet(self.app.selected)
	if self.pending or not self:SaleEligible(pet) then return end
	self.app.audio:Play("Click");self:CancelPointer(true)
	self.placing,self.placingExpected=nil,nil
	self.saleQuote={id=pet.id,name=Catalog[pet.species].name,level=pet.level,
		refund=pet.refund,income=self.app:PetIncome(pet)}
	self:UpdateAction()
end

function Browser:ConfirmSale()
	if self.pending or not self.root.Visible or not self.parent.Visible then return end
	if not self:SaleQuoteValid() then
		self.saleQuote=nil
		self.notice,self.noticeUntil="Your flock changed. Review the chicken again.",os.clock()+4
		self:UpdateAction();return
	end
	local quote=self.saleQuote
	-- The server rechecks ownership, protection and the exact refund; no stand is required.
	self:Send("Sell",{petIds={quote.id},expectedTotal=quote.refund,sparesOnly=true})
end


function Browser:Inspect(id)
	if os.clock()<self.suppressUntil or (self.pending and self.pending.action=="Sell") then return end
	self.app.audio:Play("Click")
	self.app.selected,self.placing,self.inspecting=id,nil,true
	self.placingExpected,self.saleQuote=nil,nil
	self.showInfo,self.showCapacity=false,false
	self:Render(true)
end

function Browser:AssignSelected()
	local pet=self.app:Pet(self.app.selected)
	if not pet then return end
	self:TogglePet(pet.id)
end

function Browser:TogglePet(id)
	if self.pending then return end
	if not self:CanEdit() then
		self.notice,self.noticeUntil="Wait for the current change.",os.clock()+4
		self:UpdateAction();return
	end
	local pet=self.app:Pet(id)
	if not pet then return end
	self.saleQuote=nil
	local ids=self.app.state.selectedIds or {}
	local slot=table.find(ids,id)
	if self.placing then
		if slot then self:Drop(self.placing,slot,false,self.placingExpected or ids) end
	elseif slot then self:Drop(id,nil,true,ids)
	elseif #ids<self.app.state.capacity then self:Drop(id,#ids+1,false,ids)
	else
		self.app.audio:Play("Click")
		self.placing,self.placingExpected=id,table.clone(ids)
		self.inspecting,self.showInfo=true,false
		self.search.Text="";self.grid.CanvasPosition=Vector2.zero;self:Render(true)
	end
end

function Browser:Drop(id,slot,toFlock,expected)
	if not self:CanEdit() then return end
	local current=self.app.state.selectedIds or {}
	if table.concat(current,"|")~=table.concat(expected,"|") then
		self.notice,self.noticeUntil="Army changed. Choose again.",os.clock()+4
		self:Render(true);return
	end
	local ids=table.clone(expected)
	local old=table.find(ids,id)
	if slot then
		if old==slot then return end
		if old then
			if ids[slot] then ids[old],ids[slot]=ids[slot],id
			else table.remove(ids,old);table.insert(ids,id) end
		else ids[math.min(slot,#ids+1)]=id end
	elseif toFlock and old then table.remove(ids,old)
	else return end
	self.placing,self.placingExpected=nil,nil
	self:Send("SetArmy",{petIds=ids,expectedIds=table.clone(expected)})
end


function Browser:Highlight(target,toFlock)
	for _,entry in self.cards do
		local targetSlot=entry.slot and entry.slot==target
		local viewing=self.inspecting and self.app.selected==entry.id
		entry.border.Color=if targetSlot then WHITE elseif viewing then SELECTED elseif entry.equipped then EQUIPPED else entry.color
		entry.border.Thickness=if targetSlot or viewing then 4 elseif entry.equipped then 3 else 1.8
		if entry.viewing then entry.viewing.Visible=viewing end
		if entry.selectedEdge then entry.selectedEdge.Visible=viewing end
	end
end

function Browser:DropTarget(point)
	if not inside(self.root,point) then return nil,false end
	if not inside(self.grid,point) then return nil,false end
	for index,entry in self.slots do
		if inside(entry.card,point) then return index,false end
	end
	local pointer=self.pointer
	if pointer then
		if table.find(pointer.expected,pointer.id) then return nil,true end
		if #pointer.expected<self.app.state.capacity then return #pointer.expected+1,false end
	end
	return nil,false
end

function Browser:CancelPointer(suppress)
	if suppress and self.pointer then self.suppressUntil=os.clock()+0.3 end
	self.pointer=nil
	if self.dragGui then self.dragGui:Destroy();self.dragGui=nil end
	self.grid.ScrollingEnabled=true
	self:Highlight(nil,false)
end

function Browser:StartDrag()
	local pointer=self.pointer
	if not pointer or not self:CanEdit() or not self.root.Visible or not self.parent.Visible then return end
	local pet=self.app:Pet(pointer.id)
	local playerGui=self.root:FindFirstAncestorOfClass("PlayerGui")
	if not pet or not playerGui then return end
	pointer.dragging=true
	self.grid.ScrollingEnabled=false
	local gui=Instance.new("ScreenGui")
	local owner=self.root:FindFirstAncestorOfClass("ScreenGui")
	gui.Name,gui.IgnoreGuiInset,gui.ResetOnSpawn="ArmyDragPreview",true,false
	gui.DisplayOrder=(if owner then owner.DisplayOrder else 0)+10
	gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
	gui.Parent=playerGui;self.dragGui=gui
	local ghost=Instance.new("Frame")
	ghost.Name,ghost.Size,ghost.BorderSizePixel="Chicken",UDim2.fromOffset(112,106),0
	ghost.Parent=gui;dark(ghost,GREEN)
	local portrait=Preview.Create(ghost,pet,UDim2.fromOffset(100,76),UDim2.fromOffset(6,2))
	portrait.ZIndex=2
	local name=label(ghost,"Name",Catalog[pet.species].name,13,UDim2.fromOffset(4,80),UDim2.fromOffset(104,20))
	name.TextXAlignment=Enum.TextXAlignment.Center
	pointer.ghost=ghost
	ghost.Position=UDim2.fromOffset(pointer.point.X-56,pointer.point.Y-70)
	local target,toFlock=self:DropTarget(pointer.point);self:Highlight(target,toFlock)
end

function Browser:BeginPointer(pet,input)
	local touch=input.UserInputType==Enum.UserInputType.Touch
	if not touch and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
	if not self:CanEdit() then return end
	if self.saleQuote then self.saleQuote=nil;self:UpdateAction() end
	self:CancelPointer(false)
	local point=pointOf(input)
	local pointer={id=pet.id,input=input,touch=touch,start=point,point=point,
		expected=table.clone(self.app.state.selectedIds or {}),dragging=false}
	self.pointer=pointer
	if touch then
		task.delay(0.22,function()
			if self.pointer==pointer and (pointer.point-pointer.start).Magnitude<10 then self:StartDrag() end
		end)
	end
end

function Browser:PointerChanged(input)
	local pointer=self.pointer
	if not pointer then return end
	if pointer.touch then if input~=pointer.input then return end
	elseif input.UserInputType~=Enum.UserInputType.MouseMovement then return end
	pointer.point=pointOf(input)
	if not pointer.dragging then
		local distance=(pointer.point-pointer.start).Magnitude
		if pointer.touch and distance>=10 then self:CancelPointer(true);return
		elseif not pointer.touch and distance>=6 then self:StartDrag() end
	end
	if pointer.dragging and pointer.ghost then
		pointer.ghost.Position=UDim2.fromOffset(pointer.point.X-56,pointer.point.Y-70)
		local target,toFlock=self:DropTarget(pointer.point);self:Highlight(target,toFlock)
	end
end

function Browser:PointerEnded(input)
	local pointer=self.pointer
	if not pointer then return end
	if pointer.touch then if input~=pointer.input then return end
	elseif input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
	local target,toFlock=self:DropTarget(pointer.point)
	local dragged=pointer.dragging
	self:CancelPointer(dragged)
	if dragged then
		self:Drop(pointer.id,target,toFlock,pointer.expected)
		self:Render(true)
	end
end


function Browser:Card(parent,pet,slot,width,height,order)
 local card=Instance.new("TextButton")
 card.Name,card.Text,card.AutoButtonColor="Chicken_"..pet.id,"",false
 card.Size,card.LayoutOrder=UDim2.fromOffset(width,height),order
 card.BorderSizePixel,card.BackgroundTransparency,card.ClipsDescendants=0,1,true
 card.ZIndex,card.Parent=parent.ZIndex+1,parent
 Theme.Round(card).CornerRadius=UDim.new(0,5)
 local definition=Catalog[pet.species]
 local rarity=definition.rarity
 local color=RARITIES[rarity] or RARITIES.Common
 local background=art(card,"RarityBackground",Art.Card[rarity] or Art.Card.Common,UDim2.fromScale(1,1))
 background.ScaleType=Enum.ScaleType.Stretch
 Theme.Round(background).CornerRadius=UDim.new(0,5)
 local ribbon=frame(card,"RarityRibbon",UDim2.fromOffset(196,30),UDim2.fromOffset(7,7))
 ribbon.ZIndex=card.ZIndex+2
 surface(ribbon,color,color:Lerp(Color3.new(0,0,0),0.22),Color3.fromRGB(7,16,22),1.5,1)
 local rarityLabel=label(ribbon,"Rarity",string.upper(rarity),21,UDim2.new(),UDim2.fromScale(1,1),WHITE)
 rarityLabel.TextXAlignment=Enum.TextXAlignment.Center
 local portrait=Preview.Create(card,pet,UDim2.fromOffset(132,132),UDim2.fromOffset(39,38))
 portrait.ZIndex=card.ZIndex+3
 if portrait:IsA("ViewportFrame") then
  portrait.Ambient,portrait.LightColor=Color3.fromRGB(202,216,229),Color3.new(1,1,1)
 end
 local name=label(card,"Name",definition.name:gsub(" Chicken$",""),27,UDim2.fromOffset(5,166),UDim2.fromOffset(200,29),WHITE)
 name.TextXAlignment=Enum.TextXAlignment.Center
 local stats=Rules.Stats(pet.species,pet.stars,pet.level)
 local strength=label(card,"Damage",Theme.Number(stats.damage/stats.interval).." DPS",25,UDim2.fromOffset(5,193),UDim2.fromOffset(200,25),GOLD,true)
 strength.TextXAlignment=Enum.TextXAlignment.Center
 local outline=frame(card,"StateOutline",UDim2.fromScale(1,1))
 outline.ZIndex=card.ZIndex+7
 Theme.Round(outline).CornerRadius=UDim.new(0,5)
 local equipped=slot~=nil
 local border=Theme.Stroke(outline,if equipped then EQUIPPED else color,if equipped then 3 else 1.8)
 border.BorderStrokePosition=Enum.BorderStrokePosition.Inner
 local entry={card=card,border=border,id=pet.id,color=color,equipped=equipped,slot=slot}
 self.cards[pet.id]=entry
 if slot then self.slots[slot]=entry end
 card:SetAttribute("PetId",pet.id);card:SetAttribute("InArmy",equipped)
 if equipped then
  local badge=frame(card,"EquippedCheck",UDim2.fromOffset(54,59))
  badge.ZIndex=card.ZIndex+8
  surface(badge,EQUIPPED,EQUIPPED,Color3.fromRGB(23,57,23),2,5)
  art(badge,"Check",Art.Check,UDim2.fromOffset(40,38),UDim2.fromOffset(5,9))
 end
 card.Activated:Connect(function()
  if os.clock()<self.suppressUntil then return end
  if self.placing then self:TogglePet(pet.id) else self:Inspect(pet.id) end
 end)
 card.MouseButton2Click:Connect(function() self:Inspect(pet.id) end)
 card.InputBegan:Connect(function(input) self:BeginPointer(pet,input) end)
 return card
end

function Browser:RenderArmyInfo(pets,ids)
	clear(self.infoRoster)
	local dps,hp,homeIncome,homeCount=0,0,0,0
	for _,pet in pets do
		if pet.home then homeCount+=1;homeIncome+=self.app:PetIncome(pet) end
	end
	for index,id in ids do
		local pet=pets[id]
		if not pet then continue end
		local stats=Rules.Stats(pet.species,pet.stars,pet.level)
		dps+=stats.damage/stats.interval;hp+=stats.hp
		local row=frame(self.infoRoster,"Equipped_"..id,UDim2.new(1,-8,0,84))
		row.LayoutOrder=index;dark(row,GREEN)
		local stripe=frame(row,"EquippedStripe",UDim2.new(0,4,1,0))
		stripe.BackgroundColor3,stripe.BackgroundTransparency=GREEN,0
		local imageWidth=if self.width>=700 then 94 else 62
		local portrait=Preview.Create(row,pet,UDim2.fromOffset(imageWidth,76),UDim2.fromOffset(10,4))
		portrait.ZIndex=row.ZIndex+1
		local titleX=imageWidth+24
		local valueWidth=if self.width>=700 then 150 else 72
		local titleWidth=math.max(60,self.width-titleX-valueWidth*2-42)
		local name=label(row,"Name",Catalog[pet.species].name,if self.width>=700 then 26 else 18,
			UDim2.fromOffset(titleX,13),UDim2.fromOffset(titleWidth,30),WHITE,true)
		label(row,"Status","Lv. "..pet.level.." / "..(if pet.deployed then "Away" else "In Army"),15,
			UDim2.fromOffset(titleX,49),UDim2.fromOffset(titleWidth,23),GREEN)
		local damage=label(row,"DPS",Theme.Number(stats.damage/stats.interval).." DPS",if self.width>=700 then 25 else 18,
			UDim2.new(1,-valueWidth*2-24,0,27),UDim2.fromOffset(valueWidth,32),WHITE,true)
		damage.TextXAlignment=Enum.TextXAlignment.Center
		local health=label(row,"HP",Theme.Number(stats.hp).." HP",if self.width>=700 then 25 else 18,
			UDim2.new(1,-valueWidth-12,0,27),UDim2.fromOffset(valueWidth,32),WHITE,true)
		health.TextXAlignment=Enum.TextXAlignment.Center
	end
	local state=self.app.state
	self.statTiles.Damage.value.Text=Theme.Number(dps)
	self.statTiles.Damage.note.Text="damage per second"
	self.statTiles.Health.value.Text=Theme.Number(hp)
	self.statTiles.Health.note.Text="maximum hit points"
	self.statTiles.Deployed.value.Text=#ids.." / "..state.capacity
	self.statTiles.Deployed.note.Text="army slots in use"
	self.statTiles.Flock.value.Text=tostring(#(state.pets or {}))
	self.statTiles.Flock.note.Text="owned chickens"
	self.infoMode.Text=if state.selectionMode=="Manual" then "Your manual lineup is selected." else "Best chickens selected automatically."
	self.infoFooter.Text="Equipped stats only. Best uses damage, health and splash.\nHome flock: "..homeCount.." chickens / $"..Theme.Money(homeIncome).."/s egg income"
	if #ids==0 then
		label(self.infoRoster,"Empty","No chickens selected. Return to your flock and equip a team.",18,
			UDim2.fromOffset(10,10),UDim2.new(1,-20,0,52),MUTED)
	end
end

function Browser:RenderDetail(pet)
 if self.detailPreview then self.detailPreview:Destroy();self.detailPreview=nil end
 if not pet or not self.inspecting or not self.detail.Visible then
  self.name.Text,self.metadata.Text="Choose a chicken",""
  self.damageValue.Text,self.healthValue.Text="-- DPS","-- HP"
  self.detailHalo.Visible=false
  return
 end
 local definition=Catalog[pet.species]
 self.detailBorder.Color=Color3.fromRGB(23,199,238)
 local stats=Rules.Stats(pet.species,pet.stars,pet.level)
 self.name.Text=definition.name
 local rarity=RARITIES[definition.rarity] or RARITIES.Common
 self.metadata.Text=string.format('<font color="#%s">%s</font> / Lv. %d',rarity:ToHex(),definition.rarity,pet.level)
 self.detailHalo.Image,self.detailHalo.Visible=Art.Glow[definition.rarity] or Art.Glow.Common,true
 self.damageValue.Text=Theme.Number(stats.damage/stats.interval).." DPS"
 self.healthValue.Text=Theme.Number(stats.hp).." HP"
 self.detailPreview=Preview.Create(self.detail,pet,self.previewSize,self.previewPosition)
 self.detailPreview.ZIndex=self.detail.ZIndex+3
 if self.detailPreview:IsA("ViewportFrame") then
  self.detailPreview.Ambient,self.detailPreview.LightColor=Color3.fromRGB(202,216,229),Color3.new(1,1,1)
 end
end

function Browser:Render(force)
	local state=self.app.state
	if not state then return end
	if self.pointer then
		if not self:CanEdit() or not self.app:Pet(self.pointer.id) then self:CancelPointer(true)
		else self:UpdateAction();return end
	end
	local ids=state.selectedIds or {}
	local pets,chosen,ordered={},{},{}
	for _,pet in state.pets or {} do pets[pet.id]=pet;table.insert(ordered,pet) end
	for slot,id in ids do chosen[id]=slot end
	table.sort(ordered,function(a,b)
		if self.sort=="Name" then
			local an,bn=Catalog[a.species].name,Catalog[b.species].name
			if an~=bn then return an<bn end
		end
		local pa,pb=Rules.PetPower(a.species,a.stars,a.level),Rules.PetPower(b.species,b.stars,b.level)
		if pa~=pb then return pa>pb end
		return a.id<b.id
	end)
	if self.app.selected and not pets[self.app.selected] then self.app.selected=nil;self.inspecting=false end
	if self.app.selected and self.app.selected~=self.lastSelected then
		self.inspecting,self.showInfo,self.showCapacity=true,false,false
	end
	self.lastSelected=self.app.selected
	if not self.inspecting or self.showInfo or self.showCapacity or not self.app.selected then self.saleQuote=nil end
	if not self:CanEdit() or (self.placing and not pets[self.placing]) then self.placing,self.placingExpected=nil,nil end
	local dimensions=self:Resize()
	self.app.panelTitle.Text=if self.showInfo then "Army Info"
		elseif self.showCapacity then "More Army Slots" else "Your Chickens!"
	self.title.Text=self.app.panelTitle.Text
	local mode=if state.selectionMode=="Manual" then "Manual lineup" else "Best selected"
	self.summary.Text=string.format('<font color="#F9CE43">%d</font> / %d',#ordered,state.collectionLimit or Config.CollectionLimit)
	self.capacity.Text=string.format('<font color="#F9CE43">%d</font> / %d',#ids,state.capacity)
	self.sortButton.Text=if self.placing then "Cancel" elseif self.sort=="Name" then "Name A-Z" else "Best first"
	local keys={dimensions,self.app.selected or "",table.concat(ids,","),tostring(state.capacity),mode,
		tostring(state.incoming),tostring(state.outgoing),state.armyState,tostring(state.incomeLevel),
		self.query,self.sort,self.placing or ""}
	for _,pet in state.pets or {} do
		table.insert(keys,pet.id..":"..pet.species..":"..pet.stars..":"..pet.level..":"..tostring(pet.home)..":"..tostring(pet.deployed)..":"..tostring(pet.levelCap))
	end
	local key=table.concat(keys,"|")
	if key==self.key and not force then self:UpdateAction();return end
	self.key=key
	local scroll=self.grid.CanvasPosition
	clear(self.grid);self.slots,self.cards={},{}
	local visible={}
	for _,pet in ordered do
		local searchText=string.lower(Catalog[pet.species].name.." "..Catalog[pet.species].rarity.." "..pet.species)
		if self.query=="" or string.find(searchText,self.query,1,true) then table.insert(visible,pet) end
	end
	for index,pet in visible do self:Card(self.grid,pet,chosen[pet.id],self.cellWidth,self.cellHeight,index) end
	self.grid.CanvasPosition=scroll
	if #visible==0 then
		local empty=label(self.grid,"Empty",if self.query~="" then "No matching chickens"
			else "Your flock is empty",
			18,UDim2.new(),UDim2.fromOffset(self.cellWidth,self.cellHeight),MUTED)
		empty.TextWrapped,empty.TextTruncate=true,Enum.TextTruncate.None
		empty.TextXAlignment=Enum.TextXAlignment.Center
	end
	if self.showInfo then self:RenderArmyInfo(pets,ids) end
	self:RenderDetail(pets[self.app.selected])
	self:Highlight(nil,false);self:UpdateAction()
end

return Browser
