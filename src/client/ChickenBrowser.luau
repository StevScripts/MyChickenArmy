--!strict
-- Simulator-style inventory from the approved Figma Army frames.
-- The server still owns selection, capacity, stats and every transaction.
local UserInputService=game:GetService("UserInputService")
local Theme=require(script.Parent.UITheme)
local Preview=require(script.Parent.ChickenPreview)
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Rules=require(Shared.Rules)
local Catalog=require(Shared.PetCatalog)
local Giant=require(Shared.GiantChicken)
local Mutations=require(Shared.MutationCatalog)
local Upgrades=require(Shared.UpgradeCatalog)
local EggArt=require(Shared.EggArt)
local MutationVFX=require(script.Parent.SpecialChickenVFX)
-- Approved Figma 456:3625, 1536 x 1024. Only this browser owns these local tokens.
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
 Legendary=Color3.fromRGB(255,213,0),Mythic=Color3.fromRGB(255,54,114),Secret=Color3.fromRGB(64,255,233),
}
local TONES={
 Green={Color3.fromRGB(165,255,0),Color3.fromRGB(38,227,0),Color3.fromRGB(40,125,6),Color3.fromRGB(217,255,154)},
 Blue={Color3.fromRGB(0,231,255),Color3.fromRGB(0,154,255),Color3.fromRGB(0,91,157),Color3.fromRGB(179,233,255)},
 Red={Color3.fromRGB(255,102,84),Color3.fromRGB(243,36,59),Color3.fromRGB(142,16,40),Color3.fromRGB(255,180,186)},
 Off={Color3.fromRGB(122,132,138),Color3.fromRGB(86,95,101),Color3.fromRGB(48,54,58),Color3.fromRGB(160,170,176)},
 Gold={Color3.fromRGB(255,214,48),Color3.fromRGB(255,153,0),Color3.fromRGB(140,82,0),Color3.fromRGB(255,240,170)},
}
-- October 20 (owner): the Stats button and Army Info's Formations button stay
-- hidden for now; their code is kept. Set true to show both again.
local SHOW_ARMY_INFO=false
-- October 20 storage holds up to Config.StorageLimit chickens: cards are built a page at a time.
local STORAGE_PAGE=48
local FLOCK_ACTIONS={FlockEquip=true,FlockUnequip=true,FlockBest=true}
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
 item.TextWrapped,item.TextScaled=false,true
 item.TextTruncate=Enum.TextTruncate.None
 item.ZIndex=parent.ZIndex+4
 item.TextOutline.Color=INK
 item.TextOutline.Thickness=if prominent then 0.055 else 0.045
 return item
end

-- Native text sizing follows the same scale-only boxes as the restored GUI.
local function fitInspectorLine(item)
 Theme.ScaleText(item)
end

local function surface(item,top,bottom,border,thickness)
 item.BackgroundColor3,item.BackgroundTransparency=Color3.new(1,1,1),0
 Theme.Round(item)
 local gradient=Theme.Gradient(item,top,bottom)
 gradient.Transparency=NumberSequence.new(0)
 local stroke=Theme.Stroke(item,border or EDGE,thickness or 1.5)
 stroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
 return stroke
end

-- October 20 (owner): every My Army panel is black at 10% transparency; strokes stay.
local function blackPanel(item,border,thickness)
 local stroke=surface(item,Color3.new(0,0,0),Color3.new(0,0,0),border,thickness)
 item.BackgroundTransparency=0.1
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
 local pattern=Theme.Studs(parent,0.07,24,0)
 pattern.ZIndex=parent.ZIndex+1
 return pattern
end

local function applyButtonColor(item)
 local color=item:GetAttribute("ArmyAccent")
 -- Unavailable actions turn gray so they never look pressable.
 local tone=if not item.Active then TONES.Off elseif color==RED then TONES.Red elseif color==CYAN then TONES.Blue
  elseif color==GOLD then TONES.Gold else TONES.Green
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
 visual.BackgroundColor3,visual.BackgroundTransparency=INK,1
 visual.UIStroke.Color,visual.UIStroke.BorderStrokePosition=INK,Enum.BorderStrokePosition.Inner
 Theme.Round(visual)
 local face=visual.Face
 face.Position,face.Size=UDim2.fromScale(0.006,0),UDim2.fromScale(0.988,0.94)
 face.ZIndex,face.ClipsDescendants=visual.ZIndex+2,true
 Theme.Round(face)
 local lip=visual.LowerLip
 lip.Position,lip.Size=UDim2.fromScale(0.006,0.90),UDim2.fromScale(0.988,0.085)
 lip.ZIndex=visual.ZIndex+1
 Theme.Round(lip)
 local rim=face.InsetHighlight
 rim.Position,rim.Size,rim.ZIndex=UDim2.fromScale(0.025,0.06),UDim2.fromScale(0.95,0.88),face.ZIndex+2
 rim.UIStroke.Thickness=Theme.Border.Detail
 Theme.Round(rim)
 local caption=visual.Caption
 caption.Position,caption.Size=UDim2.fromScale(0.045,0.06),UDim2.fromScale(0.91,0.75)
 Theme.ScaleText(item)
 caption.TextColor3,caption.ZIndex=WHITE,visual.ZIndex+5
 caption.TextShadow.TextTransparency=0.35;caption.TextShadow.TextOutline.Enabled=false
 caption.TextFace.TextOutline.Thickness=0.055
 caption.TextFace.TextOutline.Color=INK
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

-- AutomaticCanvasSize undercounts aspect-constrained Scale rows: the canvas stays
-- one window tall and nothing scrolls. The canvas follows the layout's measured
-- content instead (same workaround as ShopBrowser).
local function fitCanvas(scroll,layout)
 scroll.AutomaticCanvasSize=Enum.AutomaticSize.None
 local function fit() scroll.CanvasSize=UDim2.fromOffset(0,math.ceil(layout.AbsoluteContentSize.Y)) end
 layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
 fit()
 -- A list rebuilt while hidden misses that signal; renders re-fit on the next frame.
 return function() task.defer(fit) end
end

-- The same for the sideways Flock strip.
local function fitCanvasX(scroll,layout)
 scroll.AutomaticCanvasSize=Enum.AutomaticSize.None
 local function fit() scroll.CanvasSize=UDim2.fromOffset(math.ceil(layout.AbsoluteContentSize.X),0) end
 layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
 fit()
 return function() task.defer(fit) end
end

local function scrollingPanel(parent,name)
 local item=Instance.new("ScrollingFrame")
 item.Name,item.BackgroundTransparency,item.BorderSizePixel=name,1,0
 item.CanvasSize,item.AutomaticCanvasSize=UDim2.new(),Enum.AutomaticSize.None
 item.ScrollBarThickness,item.ScrollingDirection=0,Enum.ScrollingDirection.Y
 item.VerticalScrollBarInset=Enum.ScrollBarInset.Always
 item.ZIndex,item.Parent=parent.ZIndex+1,parent
 return item
end

function Browser.new(app,parent)
	local self=setmetatable({app=app,parent=parent,key="",pending=nil,connections={},slots={},cards={},stripSlots={},
		suppressUntil=0,placing=nil,flockPlacing=nil,notice=nil,inspecting=false,showInfo=false,showCapacity=false,
		query="",sort="Best",storage={},storageShown=0,storageWanted=STORAGE_PAGE},Browser)
	local root=Instance.new("Frame")
	root.Name,root.BackgroundTransparency,root.BorderSizePixel="ChickenBrowser",1,0
	root.Visible,root.ClipsDescendants=false,false
	root.ZIndex,root.Parent=parent.ZIndex+1,parent
	root:SetAttribute("OwnsPopupStyle",true)
	self.root=root
 Theme.Aspect(root,1274/876)
 local background=frame(root,"ArmyBackground",UDim2.new(),UDim2.new())
 -- The shared header's window contour also frames this full-height background.
 -- October 20 (owner): black at 10% transparency.
 surface(background,Color3.new(0,0,0),Color3.new(0,0,0),INK,3).Enabled=false
 background.BackgroundTransparency=0.1
 local header,title=Theme.Header(root,"Header","My Army",GREEN)
 Theme.ApplyReferenceAccent(header,ColorSequence.new(Color3.fromRGB(178,255,16),Color3.fromRGB(33,224,0)))
 header.PageIcon.Image,header.PageIcon.Visible=Art.Helmet,true
 self.header,self.title=header,title
 self.closeButton=Theme.HeaderClose(header,function() app.audio:Play("Click");app:ClosePanel() end)
 self.body=frame(root,"ArmyContent",UDim2.new(),UDim2.new())
 self.inventory=frame(self.body,"Inventory",UDim2.fromScale(1,1))
 local inventory=self.inventory
 self.toolbar=frame(inventory,"CapacityToolbar",UDim2.new())
 blackPanel(self.toolbar,Color3.fromRGB(3,11,16),2)
 self.flockLabel=label(self.toolbar,"FlockLabel","FLOCK",33,UDim2.new(),UDim2.new(),WHITE)
 self.summary=label(self.toolbar,"FlockCount","",36,UDim2.new(),UDim2.new(),WHITE,true)
 self.summary.RichText=true
 -- Both "+" buttons lead to their upgrade in Upgrades; the Robux pass is
 -- the fallback only once Army Size is maxed.
 self.flockPlus=button(self.toolbar,"FlockCapacity","+",function()
  self.app.audio:Play("Click");self:CancelPointer(true)
  if not self:OpenUpgrade("Flock","PlotSize") then
   self.notice,self.noticeUntil="Your Flock is at its biggest size.",os.clock()+4
   self:UpdateAction();self:Refuse()
  end
 end,GREEN)
 self.flockPlus.Position,self.flockPlus.Size,self.flockPlus.TextSize=UDim2.new(),UDim2.new(),44
 local divider=frame(self.toolbar,"Divider",UDim2.new(),UDim2.new())
 divider.BackgroundColor3,divider.BackgroundTransparency=Color3.fromRGB(132,154,167),0.1
 self.capacityLabel=label(self.toolbar,"CapacityLabel","ARMY",33,UDim2.new(),UDim2.new(),WHITE)
 self.capacity=label(self.toolbar,"ArmyCapacity","",36,UDim2.new(),UDim2.new(),WHITE,true)
 self.capacity.RichText=true
 self.capacityPlus=button(self.toolbar,"MoreArmySlots","+",function()
  self.app.audio:Play("Click");self:CancelPointer(true)
  if self:OpenUpgrade("ArmySize","ArmySize") then return end
  self.showCapacity,self.showInfo,self.inspecting=true,false,false;self.placing,self.flockPlacing=nil,nil;self:Render(true)
 end,GREEN)
 self.capacityPlus.Position,self.capacityPlus.Size,self.capacityPlus.TextSize=UDim2.new(),UDim2.new(),44
 for _,plus in {self.flockPlus,self.capacityPlus} do
  plus.Visual.Caption.Position,plus.Visual.Caption.Size=UDim2.fromScale(0.025,-0.04),UDim2.fromScale(0.95,1)
 end
 self.best=button(self.toolbar,"SelectBest","Select Best",function()
  if not self:CanEdit() then return end
  self.placing,self.placingExpected,self.flockPlacing=nil,nil,nil
  self.search.Text="";self.grid.CanvasPosition=Vector2.zero;self:Send("SelectBest")
 end,GREEN)
 self.best.Position,self.best.Size=UDim2.new(),UDim2.new()
 self.infoButton=button(self.toolbar,"ArmyInfo","Stats",function()
  self.app.audio:Play("Click");self:CancelPointer(true)
  self.showInfo,self.showCapacity,self.inspecting=true,false,false;self.placing=nil;self:Render(true)
 end,CYAN)
 self.infoButton.Position,self.infoButton.Size=UDim2.new(),UDim2.new()
 self.infoButton.Visible=SHOW_ARMY_INFO
 self.inventoryPanel=frame(inventory,"InventoryPanel",UDim2.new(),UDim2.new())
 blackPanel(self.inventoryPanel,EDGE,2)
 -- October 20 Flock strip: the chickens laying eggs, above storage. It scrolls
 -- sideways once Flock Size outgrows the panel.
 self.flockHeader=frame(self.inventoryPanel,"FlockHeader",UDim2.new(),UDim2.new())
 self.flockTitle=label(self.flockHeader,"Title","LAYING EGGS",30,UDim2.new(),UDim2.new(),WHITE,true)
 self.flockRate=label(self.flockHeader,"Rate","",26,UDim2.new(),UDim2.new(),GOLD)
 self.flockBest=button(self.flockHeader,"EquipBest","Equip Best",function()
  if not self:CanEdit() then return end
  self.placing,self.placingExpected,self.flockPlacing=nil,nil,nil
  self:Send("FlockBest")
 end,GOLD)
 local strip=Instance.new("ScrollingFrame")
 strip.Name,strip.BackgroundTransparency,strip.BorderSizePixel="FlockStrip",1,0
 strip.ScrollBarThickness,strip.ScrollingDirection=0,Enum.ScrollingDirection.X
 strip.HorizontalScrollBarInset=Enum.ScrollBarInset.Always
 strip.CanvasSize,strip.ClipsDescendants=UDim2.new(),true
 strip.ZIndex,strip.Parent=inventory.ZIndex+2,self.inventoryPanel
 local stripLayout=Instance.new("UIListLayout")
 stripLayout.FillDirection,stripLayout.SortOrder=Enum.FillDirection.Horizontal,Enum.SortOrder.LayoutOrder
 stripLayout.Padding,stripLayout.Parent=UDim.new(0,0),strip
 self.strip=strip
 self.fitStrip=fitCanvasX(strip,stripLayout)
 self.storageDivider=frame(self.inventoryPanel,"StorageDivider",UDim2.new(),UDim2.new())
 self.storageDivider.BackgroundColor3,self.storageDivider.BackgroundTransparency=Color3.fromRGB(132,154,167),0.35
 local searchShell=frame(self.inventoryPanel,"Search",UDim2.new(),UDim2.new())
 surface(searchShell,Color3.fromRGB(28,42,49),Color3.fromRGB(24,38,45),Color3.fromRGB(142,175,193),Theme.Border.Card)
 art(searchShell,"SearchIcon",Art.Search,UDim2.new(),UDim2.new())
 local search=Instance.new("TextBox")
 search.Name,search.Text,search.PlaceholderText="SearchChickens","","Search…"
 search.BackgroundTransparency,search.BorderSizePixel,search.ClearTextOnFocus=1,0,false
 search.Font,search.TextSize,search.TextColor3=Theme.Font,27,WHITE
 search.PlaceholderColor3,search.TextXAlignment=Color3.fromRGB(129,156,170),Enum.TextXAlignment.Left
 search.Position,search.Size=UDim2.new(),UDim2.new()
 search.ZIndex,search.Parent=searchShell.ZIndex+3,searchShell
 self.searchShell,self.search=searchShell,search
 local sort=Instance.new("TextButton")
 sort.Name,sort.Text,sort.AutoButtonColor="InventorySort","Best first",false
 sort.BorderSizePixel,sort.TextTransparency=0,1
 sort.Font,sort.TextSize,sort.TextColor3=Theme.Font,27,WHITE
 sort.Position,sort.Size=UDim2.new(),UDim2.new()
 sort.ZIndex,sort.Parent=inventory.ZIndex+3,self.inventoryPanel
 surface(sort,Color3.fromRGB(34,49,58),Color3.fromRGB(21,32,40),Color3.fromRGB(140,167,184),Theme.Border.Card)
 self.sortButton=sort
 local sortCaption=label(sort,"Caption",sort.Text,27,UDim2.new(),UDim2.new(),WHITE)
 local function syncSort() sortCaption.Text=sort.Text end
 sort:GetPropertyChangedSignal("Text"):Connect(syncSort)
 art(sort,"Chevron",Art.Chevron,UDim2.new(),UDim2.new())
 sort.Activated:Connect(function()
  self.app.audio:Play("Click")
  self.sort=if self.sort=="Best" then "Eggs" elseif self.sort=="Eggs" then "Name" else "Best"
  self.storageWanted=STORAGE_PAGE
  self.grid.CanvasPosition=Vector2.zero;self:Render(true)
  Theme.Motion:PopScale(sortCaption,1.1)
 end)
 Theme.Motion:BindButton(sort,Theme.Motion:ScaleOf(sort),sort)
 -- Opens the Sell screen for picking many chickens at once.
 self.sellMany=button(self.inventoryPanel,"SellChickens","Sell",function() self:OpenSell(nil) end,RED)
 -- Replace mode gets its own Cancel in Sell's place; the sort control stays.
 self.placeCancel=button(self.inventoryPanel,"CancelReplace","Cancel",function()
  self.app.audio:Play("Click")
  self.placing,self.placingExpected,self.flockPlacing=nil,nil,nil
  self:Render(true)
 end,RED)
 self.placeCancel.Visible=false
 local grid=Instance.new("ScrollingFrame")
 grid.Name,grid.BackgroundTransparency,grid.BorderSizePixel="ChickenInventory",1,0
 grid.Position,grid.Size=UDim2.new(),UDim2.new()
 grid.ScrollBarThickness,grid.ScrollBarImageColor3=0,Color3.fromRGB(181,205,223)
 grid.VerticalScrollBarInset=Enum.ScrollBarInset.Always
 grid.ScrollingDirection,grid.CanvasSize=Enum.ScrollingDirection.Y,UDim2.new()
 grid.AutomaticCanvasSize,grid.ClipsDescendants=Enum.AutomaticSize.Y,true
 grid.ZIndex,grid.Parent=inventory.ZIndex+2,self.inventoryPanel
 self.grid=grid
 local padding=Instance.new("UIPadding")
 padding.PaddingLeft,padding.PaddingRight=UDim.new(0,0),UDim.new(0,0)
 padding.PaddingTop,padding.PaddingBottom=UDim.new(0,0),UDim.new(0,0);padding.Parent=grid
 local layout=Instance.new("UIListLayout")
 layout.SortOrder,layout.FillDirection=Enum.SortOrder.LayoutOrder,Enum.FillDirection.Vertical
 layout.Padding,layout.Parent=UDim.new(0,0),grid
 self.fitGrid=fitCanvas(grid,layout)
 self.hint=label(inventory,"InteractionHint","",23,UDim2.new(),UDim2.new(),MUTED)
 self.hint.BackgroundColor3,self.hint.BackgroundTransparency=Color3.fromRGB(20,32,41),0.05
 self.hint.ZIndex,self.hint.Visible=inventory.ZIndex+20,false
 table.insert(self.connections,search:GetPropertyChangedSignal("Text"):Connect(function()
  self.query=string.lower(search.Text):match("^%s*(.-)%s*$") or ""
  self.storageWanted=STORAGE_PAGE
  self.grid.CanvasPosition=Vector2.zero;self:Render(true)
 end))
 -- The next page of storage loads as the grid nears its end.
 table.insert(self.connections,grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
  if not self.moreRow then return end
  local window=grid.AbsoluteWindowSize.Y
  if grid.CanvasPosition.Y+window>=grid.AbsoluteCanvasSize.Y-window*0.5 then self:ShowMoreStorage() end
 end))

	self.armyInfo=scrollingPanel(self.body,"ArmyInfo")
	self.infoTitle=label(self.armyInfo,"Title","Your Army at a glance",30,UDim2.new(),UDim2.new(),WHITE,true)
	self.infoMode=label(self.armyInfo,"Mode","",17,UDim2.new(),UDim2.new(),MUTED)
	local function back()
		self.app.audio:Play("Click");self:CancelPointer(true)
		self.showInfo,self.showCapacity,self.inspecting=false,false,false
		self.app.selected,self.lastSelected,self.placing,self.placingExpected=nil,nil,nil,nil
		self:Render(true)
	end
	self.infoBack=button(self.armyInfo,"BackToChickens","Back to Chickens",back,Theme.ReferenceColors.Upgrades)
	self.infoFormations=button(self.armyInfo,"Formations","Formations",function() self.app:OpenPage("Formations") end,Theme.ActionColors.navigation)
	self.infoFormations.Visible=SHOW_ARMY_INFO
	self.statTiles={}
	for _,definition in {{"Damage","COMBINED DAMAGE",GREEN},{"Health","COMBINED HEALTH",Theme.ReferenceColors.Upgrades},
		{"Deployed","ARMY SELECTED",WHITE},{"Flock","CHICKENS",WHITE}} do
		local tile=frame(self.armyInfo,definition[1],UDim2.new());blackPanel(tile,EDGE,1.5)
		self.statTiles[definition[1]]={
			frame=tile,title=label(tile,"Title",definition[2],14,UDim2.new(),UDim2.new(),MUTED),
			value=label(tile,"Value","",40,UDim2.new(),UDim2.new(),definition[3],true),
			note=label(tile,"Note","",15,UDim2.new(),UDim2.new(),MUTED)}
	end
	self.rosterTitle=label(self.armyInfo,"RosterTitle","Current Army",27,UDim2.new(),UDim2.new(),WHITE,true)
	local roster=Instance.new("ScrollingFrame")
	roster.Name,roster.BackgroundTransparency,roster.BorderSizePixel="EquippedRoster",1,0
	roster.ScrollBarThickness,roster.ScrollBarImageColor3=0,GREEN
	roster.VerticalScrollBarInset=Enum.ScrollBarInset.Always
	roster.CanvasSize,roster.AutomaticCanvasSize=UDim2.new(),Enum.AutomaticSize.Y
	roster.ScrollingDirection,roster.ZIndex,roster.Parent=Enum.ScrollingDirection.Y,self.armyInfo.ZIndex+1,self.armyInfo
	local list=Instance.new("UIListLayout")
	list.SortOrder,list.Padding,list.Parent=Enum.SortOrder.LayoutOrder,UDim.new(0,0),roster
	self.fitRoster=fitCanvas(roster,list)
	self.infoRoster=roster
	self.infoFooter=label(self.armyInfo,"StatsScope","",16,UDim2.new(),UDim2.new(),MUTED)
	self.infoFooter.TextWrapped,self.infoFooter.TextTruncate=true,Enum.TextTruncate.None

	self.capacityPage=scrollingPanel(self.body,"MoreArmySlots")
	self.passTitle=label(self.capacityPage,"Title","Bigger Army",32,UDim2.new(),UDim2.new(),WHITE,true)
	self.passBadge=label(self.capacityPage,"Type","Army Size upgrades maxed · Robux pass",17,UDim2.new(),UDim2.new(),GREEN)
	self.passArt=Theme.Image(self.capacityPage,"BiggerArmy",Theme.Assets.Army,UDim2.new(),UDim2.new())
	self.passArt.ZIndex=self.capacityPage.ZIndex+1
	self.passCopy=label(self.capacityPage,"Description","Bring more chickens into battle.",24,UDim2.new(),UDim2.new(),WHITE)
	self.passCopy.TextWrapped,self.passCopy.TextTruncate=true,Enum.TextTruncate.None
	self.passNote=label(self.capacityPage,"Availability",
		"The Bigger Army pass adds five more Army slots on top of your Army Size upgrades. See the price in Shop.",18,
		UDim2.new(),UDim2.new(),MUTED)
	self.passNote.TextWrapped,self.passNote.TextTruncate=true,Enum.TextTruncate.None
	self.passShop=button(self.capacityPage,"ViewInShop","View in Shop",function()
		self.app.audio:Play("Click");self.app:OpenPage("Shop")
	end,GREEN)
	self.passBack=button(self.capacityPage,"BackToChickens","Back",back,Theme.ReferenceColors.Upgrades)

 -- Fixed inline inspector. Equipment is represented by checks, never a Reserve badge.
 self.detail=scrollingPanel(self.body,"SelectedChicken")
 self.detailBorder=blackPanel(self.detail,CYAN,2)
 self.name=label(self.detail,"Name","Choose a chicken",49,UDim2.new(),UDim2.new(),WHITE,true)
 self.name.TextXAlignment=Enum.TextXAlignment.Center
 fitInspectorLine(self.name,49,16)
 self.metadata=label(self.detail,"LevelRarity","",29,UDim2.new(),UDim2.new(),WHITE)
 self.metadata.TextXAlignment,self.metadata.RichText=Enum.TextXAlignment.Center,true
 self.metadata.TextScaled,self.metadata.TextWrapped=true,false
 Theme.ScaleText(self.metadata)
 self.detailNotice=label(self.detail,"Status","",19,UDim2.new(),UDim2.new(),MUTED)
 self.detailNotice.TextXAlignment=Enum.TextXAlignment.Center
 self.detailHalo=art(self.detail,"RarityGlow",Art.Glow.Rare,UDim2.new(),UDim2.new())
 self.detailHalo.ZIndex=self.detail.ZIndex+2
 self.stats=label(self.detail,"ChickenStats","",37,UDim2.new(),UDim2.new(),WHITE,true)
 self.stats.RichText,self.stats.TextXAlignment=true,Enum.TextXAlignment.Center
 fitInspectorLine(self.stats,37,14)
 self.upgrade=button(self.detail,"UpgradeChicken","Upgrade",function() self:UpgradeSelected() end,CYAN)
 for _,text in {self.upgrade,self.upgrade.Visual.Caption,self.upgrade.Visual.Caption.TextFace,self.upgrade.Visual.Caption.TextShadow} do
  text.RichText=true
 end
 fitInspectorLine(self.upgrade,43,14)
 self.actions=frame(self.detail,"Actions",UDim2.new())
 self.actionLayout=Instance.new("UIListLayout")
 self.actionLayout.FillDirection,self.actionLayout.SortOrder=Enum.FillDirection.Horizontal,Enum.SortOrder.LayoutOrder
 self.actionLayout.Parent=self.actions
 self.assign=button(self.actions,"AssignChicken","Add to Army",function() self:AssignSelected() end,GREEN)
 fitInspectorLine(self.assign,42,14)
 self.sell=button(self.actions,"SellChicken","Sell",function() self:OpenSell(self.app.selected) end,RED)
 self.assign.LayoutOrder,self.sell.LayoutOrder=1,2
 fitInspectorLine(self.sell,38,14)
 -- October 20 Flock: whether this chicken lays, and the button that moves it.
 self.flockStatus=label(self.detail,"FlockStatus","",23,UDim2.new(),UDim2.new(),MUTED)
 self.flockStatus.TextXAlignment,self.flockStatus.TextWrapped=Enum.TextXAlignment.Center,true
 fitInspectorLine(self.flockStatus)
 self.flockAction=button(self.detail,"FlockChicken","Add to Flock",function() self:FlockSelected() end,GOLD)
 fitInspectorLine(self.flockAction)
 self.detailBack=button(self.body,"BackToFlock","Back",function()
  self.app.audio:Play("Click");self.inspecting=false;self.app.selected=nil
  self:Render(true)
 end,CYAN)
 self.detailBack.Visible=false
	table.insert(self.connections,UserInputService.InputChanged:Connect(function(input) self:PointerChanged(input) end))
	table.insert(self.connections,UserInputService.InputEnded:Connect(function(input) self:PointerEnded(input) end))
	table.insert(self.connections,UserInputService.WindowFocusReleased:Connect(function() self:CancelPointer(true) end))
	local function visibilityChanged()
		if not root.Visible or not parent.Visible then
			self:CancelPointer(true);self.placing,self.placingExpected,self.flockPlacing=nil,nil,nil
			self.storageWanted=STORAGE_PAGE
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
 self:Resize()
	return self
end

function Browser:CashOffer(key)
	local offers=self.app.state and self.app.state.boardUpgrades
	return offers and offers[key]
end

-- Opens Upgrades at the family's next tier; false once the family is maxed.
function Browser:OpenUpgrade(family,legacyKey): boolean
	local tree=self.app.state and self.app.state.upgradeTree
	local definition=Upgrades.Families and Upgrades.Families[family]
	if type(tree)=="table" and definition then
		local tier=tree.families and tree.families[family] or 0
		if tier>=#definition.tiers then return false end
		self.app.research:OpenNode(Upgrades.NodeId(family,tier+1))
		return true
	end
	-- Snapshots without the Upgrades tree still carry the old cash offers.
	local offer=self:CashOffer(legacyKey)
	if offer and offer.ready and offer.price==nil then return false end
	if self.app.research.OpenCash then self.app.research:OpenCash(legacyKey) else self.app.research:Open() end
	return true
end

-- The Sell screen picks many chickens at once; `petId` starts selected when it can be sold.
function Browser:OpenSell(petId)
	if self.pending or not self.app.OpenSell then return end
	self.app.audio:Play("Click");self:CancelPointer(true)
	self.placing,self.placingExpected,self.flockPlacing=nil,nil,nil
	self.app:OpenSell(petId)
end

-- The Coins level-up button stays until Chicken Feed arrives (the snapshot gains `tools`).
function Browser:UpgradeShown(): boolean
	return Config.Features.ChickenCashUpgrades and self.app.state~=nil and self.app.state.tools==nil
end

function Browser:CanEdit()
	local state=self.app.state
	if not state or self.pending then return false end
	return true
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
			local power=Rules.PetPower(candidate.species,candidate.stars,candidate.level,candidate.giantSize)
			if not pet or (isEquipped and not bestEquipped)
				or (isEquipped==bestEquipped and (power>bestPower or (power==bestPower and candidate.id<pet.id))) then
				pet,bestEquipped,bestPower=candidate,isEquipped,power
			end
		end
	end
	local id=if pet then pet.id else nil
	self.app.selected,self.lastSelected=id,id
	self.inspecting,self.showInfo,self.showCapacity=pet~=nil,false,false
	self.placing,self.placingExpected,self.flockPlacing=nil,nil,nil
	self.storageWanted=STORAGE_PAGE
end

function Browser:Resize()
 -- Native Scale rectangles preserve the approved four-column/inspector composition.
 local width,height=1474,1474*876/1274
 local bodyHeight=height-93
 local inventoryHeight,detailHeight=bodyHeight-92,bodyHeight-95
 local rect=Theme.RelativeRect
 self.root.AnchorPoint,self.root.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
 self.root.Size=UDim2.fromScale(1,1)
 self.narrow,self.hideDetailPreview=false,false
 self.root.ArmyBackground.Position,self.root.ArmyBackground.Size=UDim2.new(),UDim2.fromScale(1,1)
 rect(self.body,0,88,width,bodyHeight,width,height)
 Theme.BelowHeader(self.header,self.body,1-5/height)
 local inventoryVisible=not self.showInfo and not self.showCapacity
 self.inventory.Visible,self.detail.Visible=inventoryVisible,inventoryVisible
 self.detailBack.Visible=false
 self.armyInfo.Visible,self.capacityPage.Visible=self.showInfo,self.showCapacity
 rect(self.toolbar,0,0,width,85,width,bodyHeight)
 rect(self.flockLabel,27,10,110,64,width,85)
 rect(self.summary,143,10,137,64,width,85)
 rect(self.flockPlus,278,13,66,62,width,85)
 Theme.Aspect(self.flockPlus,66/62)
 self.toolbar.Divider.Visible=true
 rect(self.toolbar.Divider,406,21,2,43,width,85)
 rect(self.capacityLabel,454,10,108,64,width,85)
 -- Centre-left anchor (same resting rect) so the count pops in place.
 self.capacity.AnchorPoint=Vector2.new(0,0.5)
 rect(self.capacity,569,10+32,102,64,width,85)
 rect(self.capacityPlus,676,13,66,62,width,85)
 Theme.Aspect(self.capacityPlus,66/62)
 -- With Stats hidden, Select Best takes its place at the toolbar's right edge.
 rect(self.best,if SHOW_ARMY_INFO then 975 else 1166,13,294,64,width,85)
 rect(self.infoButton,1280,13,180,64,width,85)
 rect(self.inventoryPanel,6,92,903,inventoryHeight,width,bodyHeight)
 -- October 20: the Flock strip sits above storage; its cards are 146 x 150 slots.
 rect(self.flockHeader,16,10,871,46,903,inventoryHeight)
 rect(self.flockTitle,0,0,250,46,871,46)
 rect(self.flockRate,262,0,377,46,871,46)
 self.flockTitle.TextXAlignment,self.flockRate.TextXAlignment=Enum.TextXAlignment.Left,Enum.TextXAlignment.Left
 rect(self.flockBest,651,1,220,44,871,46)
 rect(self.strip,13,62,877,150,903,inventoryHeight)
 rect(self.storageDivider,16,222,871,2,903,inventoryHeight)
 rect(self.searchShell,16,234,430,56,903,inventoryHeight)
 rect(self.searchShell.SearchIcon,16,10,36,36,430,56)
 Theme.Aspect(self.searchShell.SearchIcon,1)
 rect(self.search,66,0,340,56,430,56)
 Theme.ScaleText(self.search)
 -- While replacing, Cancel takes Sell's place.
 local placing=self.placing~=nil or self.flockPlacing~=nil
 self.placeCancel.Visible,self.sellMany.Visible=placing,not placing
 rect(self.placeCancel,458,234,146,56,903,inventoryHeight)
 rect(self.sellMany,458,234,146,56,903,inventoryHeight)
 self.sortButton.AnchorPoint=Vector2.new(0.5,0.5)
 rect(self.sortButton,614+135,234+28,270,56,903,inventoryHeight)
 rect(self.sortButton.Caption,18,0,195,56,270,56)
 rect(self.sortButton.Chevron,221,16,34,24,270,56)
 rect(self.grid,13,300,877,inventoryHeight-312,903,inventoryHeight)
 self.grid.ScrollBarThickness=0
 rect(self.hint,19,bodyHeight-48,887,44,width,bodyHeight)
 self.hint.TextWrapped=true
 rect(self.detail,931,95,535,detailHeight,width,bodyHeight)
 self.detail.CanvasSize=UDim2.new()
 self.detail.ScrollBarThickness=0
 self.name.AnchorPoint=Vector2.new(0.5,0.5)
 rect(self.name,14+253.5,16+27,507,54,535,detailHeight)
 rect(self.metadata,14,78,507,28,535,detailHeight)
 -- Two inspector layouts: with the Coins level-up button (until Chicken Feed), and without.
 if self:UpgradeShown() then
  self.previewSize=UDim2.fromScale(330/535,330/detailHeight)
  self.previewPosition=UDim2.fromScale(102.5/535,100/detailHeight)
  rect(self.detailHalo,112.5,110,310,310,535,detailHeight)
  rect(self.stats,14,436,507,40,535,detailHeight)
  rect(self.flockStatus,14,478,507,32,535,detailHeight)
  rect(self.upgrade,14,514,507,72,535,detailHeight)
  rect(self.flockAction,14,594,507,72,535,detailHeight)
  rect(self.actions,14,674,507,72,535,detailHeight)
  rect(self.detailNotice,14,754,507,44,535,detailHeight)
 else
  self.previewSize=UDim2.fromScale(380/535,380/detailHeight)
  self.previewPosition=UDim2.fromScale(77.5/535,100/detailHeight)
  rect(self.detailHalo,89.5,112,356,356,535,detailHeight)
  rect(self.stats,14,484,507,42,535,detailHeight)
  rect(self.flockStatus,14,528,507,40,535,detailHeight)
  rect(self.flockAction,14,576,507,76,535,detailHeight)
  rect(self.actions,14,660,507,76,535,detailHeight)
  rect(self.detailNotice,14,744,507,44,535,detailHeight)
 end
 Theme.Aspect(self.detailHalo,1)
 self.actionLayout.Padding=UDim.new(12/507,0)
 self.assign.Size,self.sell.Size=UDim2.fromScale(331/507,1),UDim2.fromScale(164/507,1)
 self.detailNotice.TextWrapped=true
 self.armyInfo.Position,self.capacityPage.Position=UDim2.fromScale(0.012,0.015),UDim2.fromScale(0.012,0.015)
 self.armyInfo.Size,self.capacityPage.Size=UDim2.fromScale(0.976,0.97),UDim2.fromScale(0.976,0.97)
 self.armyInfo.CanvasSize,self.capacityPage.CanvasSize=UDim2.new(),UDim2.new()
 rect(self.infoTitle,0,0,1030,42,width,bodyHeight)
 rect(self.infoFormations,1048,0,276,48,width,bodyHeight)
 rect(self.infoBack,1342,0,120,48,width,bodyHeight)
 self.infoBack.Text="Back"
 rect(self.infoMode,0,52,1462,28,width,bodyHeight)
 local tileWidth=(1462-36)/4
 for index,name in {"Damage","Health","Deployed","Flock"} do
  local tile=self.statTiles[name]
  rect(tile.frame,(index-1)*(tileWidth+12),88,tileWidth,100,width,bodyHeight)
  rect(tile.title,14,10,tileWidth-28,19,tileWidth,100)
  rect(tile.value,8,30,tileWidth-16,40,tileWidth,100)
  rect(tile.note,8,72,tileWidth-16,24,tileWidth,100)
 end
 rect(self.rosterTitle,0,200,1462,36,width,bodyHeight)
 rect(self.infoRoster,0,244,1462,bodyHeight-304,width,bodyHeight)
 rect(self.infoFooter,0,bodyHeight-52,1462,48,width,bodyHeight)
 rect(self.passTitle,8,0,1446,70,width,bodyHeight)
 rect(self.passBadge,8,76,1446,45,width,bodyHeight)
 rect(self.passArt,50,155,250,250,width,bodyHeight)
 Theme.Aspect(self.passArt,1)
 rect(self.passCopy,350,155,1090,200,width,bodyHeight)
 rect(self.passNote,50,445,1374,135,width,bodyHeight)
 rect(self.passShop,50,620,1374,90,width,bodyHeight)
 rect(self.passBack,50,735,1374,80,width,bodyHeight)
 for _,item in {self.passShop,self.passBack} do
  item.Visual.Face.StudClip.StudTexture:SetAttribute("StudScaleWidth",width/(1374*0.976*0.988))
 end
 return tostring(self.showInfo)..":"..tostring(self.showCapacity)
end

function Browser:Send(action,payload)
	if self.pending then return end
	self.app.audio:Play("Click")
	local id=self.app:Request(action,payload)
	local flock=self.app.state.flock
	self.pending={id=id,at=os.clock(),action=action,petId=payload and payload.petId,
		before=table.clone(self.app.state.selectedIds or {}),flockBefore=table.clone(flock and flock.ids or {})}
	self.notice=nil
	self:UpdateAction()
end

function Browser:Receive(result)
	-- Every snapshot passes through here: keep the world mutation looks current.
	MutationVFX.SetOwnedMutations(self.app.state and self.app.state.pets)
	if self.pending and result and result.id==self.pending.id then
		local pending=self.pending
		self.pending=nil
		if pending.action=="UpgradeChicken" and result.ok then self.app.feedback:Action("Income") end
		-- Confirmed Army and Flock edits pop the changed cards on the next render only.
		if result.ok and (pending.action=="SetArmy" or pending.action=="SelectBest") then self.armyPop={before=pending.before,at=os.clock()} end
		if result.ok and FLOCK_ACTIONS[pending.action] then self.flockPop={before=pending.flockBefore,at=os.clock()} end
		self.notice=if result.ok then nil else result.message
		self.noticeUntil=os.clock()+4
		if not result.ok then self:Refuse() end
	end
end

-- A small "no" on the visible notice lines; only for failed player actions.
function Browser:Refuse()
	Theme.Motion:Shake(self.hint,5);Theme.Motion:Shake(self.detailNotice,5)
end

function Browser:PopArmyChanges(before,ids)
	local was,now,changed={},{},false
	for _,id in before do was[id]=true end
	for _,id in ids do now[id]=true end
	for id,entry in self.cards do
		if (was[id]==true)~=(now[id]==true) then
			changed=true
			Theme.Motion:PopScale(entry.card,1.06)
			local badge=entry.card:FindFirstChild("EquippedCheck")
			if badge then Theme.Motion:PopScale(badge,0.5,0.3) end
		end
	end
	if changed then Theme.Motion:PopScale(self.capacity,1.12) end
end

-- Chickens new to the Flock pop in the strip after a confirmed Flock change.
function Browser:PopFlockChanges(before)
	local was={}
	for _,id in before do was[id]=true end
	for id,entry in self.cards do
		if entry.strip and not was[id] then Theme.Motion:PopScale(entry.card,1.06) end
	end
	Theme.Motion:PopScale(self.summary,1.12)
end

-- What this chicken does for eggs, plus how to level it once Chicken Feed replaces the Coins button.
function Browser:FlockStatus(pet,upgradeShown): string
	if not pet then return "" end
	local text=if pet.flock and pet.laying then "Laying eggs in your Flock"
		elseif pet.flock then "In your Flock · away with your Army"
		elseif pet.laying then "Laying in place of a Flock chicken that's away"
		else "In storage · not laying eggs"
	if upgradeShown or (pet.level or 1)>=(pet.levelCap or Config.MaxPetLevel) then return text end
	local tools=self.app.state.tools
	return text.."\n"..(if type(tools)=="table" and tools.chickenFeed then "Level it up: equip Chicken Feed and walk up to it"
		else "Level it up with Chicken Feed (Upgrades > Tools)")
end

function Browser:UpdateAction()
	local state=self.app.state
	if not state then return end
	if self.pending and os.clock()-self.pending.at>5 then
		self.pending=nil
		self.notice="No response yet. Try again.";self.noticeUntil=os.clock()+4
	end
	if self.notice and os.clock()>(self.noticeUntil or 0) then self.notice=nil end
	local pet=self.app:Pet(self.app.selected)
	local canEdit=self:CanEdit()
	local flock=state.flock
	local members=if flock then flock.ids or {} else {}
	enabled(self.best,canEdit)
	self.best.Text=if self.pending and self.pending.action=="SelectBest" then "Selecting…" else "Select Best"
	enabled(self.flockBest,canEdit and flock~=nil)
	self.flockBest.Text=if self.pending and self.pending.action=="FlockBest" then "Equipping…" else "Equip Best"
	self.hint.Text=if self.notice then self.notice
		elseif self.pending then (if self.pending.action=="UpgradeChicken" then "Upgrading chicken…"
			elseif FLOCK_ACTIONS[self.pending.action] then "Updating Flock…" else "Updating Army…")
		elseif self.placing then "Choose a green-checked chicken to replace, or choose Cancel."
		elseif self.flockPlacing then "Choose a Flock chicken to swap out, or choose Cancel."
		elseif not canEdit then "Updating Army…"
		else ""
	self.hint.Visible=self.hint.Text~=""
	self.hint.TextColor3=if self.notice then Color3.fromRGB(255,120,132) else MUTED
	-- A home chicken in storage can be sold even while the rest of the Army is away.
	local canSell=self.pending==nil and self.app.OpenSell~=nil and self:SaleEligible(pet)
	self.detailNotice.Text=if self.notice then self.notice
		elseif self.pending then "Updating…"
		elseif pet and self:ColossalSlot(pet.id) then "Only 1 Colossal per Army."
		elseif pet and not self:SaleEligible(pet) then self:SaleBlockedReason(pet)
		else ""
	self.detailNotice.TextColor3=self.hint.TextColor3
	local upgradeShown=self:UpgradeShown()
	local price=pet and pet.upgradePrice
	local affordable=type(price)=="number" and state.coins>=price
	enabled(self.upgrade,canEdit and pet~=nil and pet.canUpgrade==true and affordable)
	self.upgrade.Text=if self.pending and self.pending.action=="UpgradeChicken" then "Upgrading…"
		elseif pet and pet.level>=(pet.levelCap or Config.MaxPetLevel) then "Max Level"
		elseif type(price)=="number" then 'Upgrade  <font color="#FFDE29">'..Theme.Coins(price)..'</font>' else "Upgrade"
	enabled(self.assign,canEdit and pet~=nil)
	self.assign.Text=if pet and pet.selected then "Remove from Army"
		elseif pet and self:ColossalSlot(pet.id) then "Replace Colossal"
		elseif #(state.selectedIds or {})>=state.capacity then "Replace…" else "Add to Army"
	enabled(self.sell,canSell)
	enabled(self.sellMany,self.pending==nil and self.app.OpenSell~=nil)
	-- The last Flock chicken stays: an empty Flock would lay nothing.
	enabled(self.flockAction,canEdit and pet~=nil and flock~=nil and not (pet.flock and #members<=1))
	self.flockAction.Text=if self.pending and FLOCK_ACTIONS[self.pending.action] then "Updating…"
		elseif pet and self.flockPlacing==pet.id then "Pick one to swap…"
		elseif pet and pet.flock then "Remove from Flock"
		elseif flock and #members>=flock.size then "Swap into Flock…" else "Add to Flock"
	self.flockStatus.Text=self:FlockStatus(pet,upgradeShown)
	self.flockStatus.TextColor3=if pet and pet.laying then GOLD else MUTED
	self.upgrade.Visible=upgradeShown
	self.flockStatus.Visible,self.flockAction.Visible=pet~=nil,pet~=nil
	self.detailNotice.Visible=self.detailNotice.Text~=""
end

function Browser:UpgradeSelected()
	local pet=self.app:Pet(self.app.selected)
	if not self:CanEdit() or not pet or pet.canUpgrade~=true or type(pet.upgradePrice)~="number"
		or self.app.state.coins<pet.upgradePrice then return end
	self:CancelPointer(true);self.placing,self.placingExpected,self.flockPlacing=nil,nil,nil
	self:Send("UpgradeChicken",{petId=pet.id,expectedLevel=pet.level,expectedPrice=pet.upgradePrice})
end

function Browser:SaleEligible(pet)
	return pet~=nil and pet.canSell==true and not pet.selected and not pet.flock and not pet.favorite
		and not pet.deployed and pet.home~=false and type(pet.refund)=="number"
		and pet.refund>=0 and pet.refund<math.huge
end

-- Why Sell is disabled, short and in glossary words; the server's saleReason
-- covers anything else (e.g. the starter-flock minimum).
function Browser:SaleBlockedReason(pet): string
	if pet.favorite then return "Favorited chickens can't be sold." end
	if pet.deployed or pet.home==false then return "Sell this chicken once it's back home." end
	if pet.selected then return "Remove this chicken from your Army to sell it." end
	if pet.flock then return "Remove this chicken from your Flock to sell it." end
	if pet.canSell==false and type(pet.saleReason)=="string" then return pet.saleReason end
	return ""
end

-- The inspector's Flock button: add, remove, or (when full) pick a Flock chicken to swap out.
function Browser:FlockSelected()
	local pet=self.app:Pet(self.app.selected)
	local flock=self.app.state and self.app.state.flock
	if not pet or not flock or not self:CanEdit() then return end
	self:CancelPointer(true);self.placing,self.placingExpected=nil,nil
	if pet.flock then self:Send("FlockUnequip",{petId=pet.id});return end
	if #(flock.ids or {})<flock.size then self:Send("FlockEquip",{petId=pet.id});return end
	self.app.audio:Play("Click")
	self.flockPlacing=if self.flockPlacing==pet.id then nil else pet.id
	self:Render(true)
end

function Browser:SwapIntoFlock(targetId)
	local id=self.flockPlacing
	self.flockPlacing=nil
	if id and self:CanEdit() then self:Send("FlockEquip",{petId=id,replaceId=targetId}) end
	self:Render(true)
end

-- An empty strip slot takes the chicken being inspected.
function Browser:FillFlockSlot()
	local pet=self.app:Pet(self.app.selected)
	if pet and not pet.flock and self:CanEdit() then self:Send("FlockEquip",{petId=pet.id});return end
	self.app.audio:Play("Click")
	self.notice,self.noticeUntil="Choose a chicken in storage, then Add to Flock.",os.clock()+4
	self:UpdateAction()
end

-- A drag dropped on the strip (slot index, 0 for an open spot) or out of it (-1).
function Browser:FlockDrop(id,target)
	local pet=self.app:Pet(id)
	local flock=self.app.state and self.app.state.flock
	if not pet or not flock or not self:CanEdit() then return end
	local members=flock.ids or {}
	if target==-1 then
		if pet.flock then self:Send("FlockUnequip",{petId=id}) end
		return
	end
	if pet.flock then return end
	local replaceId=if target>0 then members[target] else nil
	if replaceId then self:Send("FlockEquip",{petId=id,replaceId=replaceId})
	elseif #members<flock.size then self:Send("FlockEquip",{petId=id})
	else
		self.notice,self.noticeUntil="Your Flock is full. Drop it on a Flock chicken to swap.",os.clock()+4
		self:UpdateAction();self:Refuse()
	end
end


function Browser:Inspect(id)
	if os.clock()<self.suppressUntil then return end
	self.app.audio:Play("Click")
	self.app.selected,self.placing,self.inspecting=id,nil,true
	self.placingExpected,self.flockPlacing=nil,nil
	self.showInfo,self.showCapacity=false,false
	-- Not forced: a selection change keeps the grid, so the clicked card can animate.
	self:Render()
	local entry=self.cards[id]
	-- Deferred past the card's own press settle so the selection bounce shows.
	if entry then local card=entry.card;task.defer(function() Theme.Motion:PopScale(card,1.05) end) end
	Theme.Motion:PopScale(self.name,1.06)
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
		self:UpdateAction();self:Refuse();return
	end
	local pet=self.app:Pet(id)
	if not pet then return end
	self.flockPlacing=nil
	local ids=self.app.state.selectedIds or {}
	local slot=table.find(ids,id)
	if self.placing then
		if slot then self:Drop(self.placing,slot,false,self.placingExpected or ids) end
	elseif slot then self:Drop(id,nil,true,ids)
	elseif self:ColossalSlot(id) then self:Drop(id,self:ColossalSlot(id),false,ids)
	elseif #ids<self.app.state.capacity then self:Drop(id,#ids+1,false,ids)
	else
		self.app.audio:Play("Click")
		self.placing,self.placingExpected=id,table.clone(ids)
		self.inspecting,self.showInfo=false,false
		self.search.Text="";self.grid.CanvasPosition=Vector2.zero;self:Render(true)
	end
end

function Browser:Drop(id,slot,leaveArmy,expected)
	if not self:CanEdit() then return end
	local current=self.app.state.selectedIds or {}
	if table.concat(current,"|")~=table.concat(expected,"|") then
		self.notice,self.noticeUntil="Army changed. Choose again.",os.clock()+4
		self:Render(true);self:Refuse();return
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
	if colossals>Giant.MaxArmyColossals then
		self.notice,self.noticeUntil="Only 1 Colossal per Army. Replace the Colossal in your Army.",os.clock()+4
		self:UpdateAction();self:Refuse();return
	end
	self.placing,self.placingExpected=nil,nil
	self:Send("SetArmy",{petIds=ids,expectedIds=table.clone(expected)})
end


-- `target`: an Army slot being dragged onto; `flockTarget`: a Flock strip slot (0 = any open one).
function Browser:Highlight(target,flockTarget)
	for _,entry in self.cards do
		local targetSlot=(entry.slot~=nil and entry.slot==target)
			or (flockTarget~=nil and flockTarget>0 and entry.flockIndex==flockTarget)
		local viewing=self.inspecting and self.app.selected==entry.id
		-- While swapping into the Flock, the strip's chickens are the choices.
		local swapping=self.flockPlacing~=nil and entry.strip==true
		local color=if targetSlot then WHITE elseif viewing then SELECTED elseif swapping then GOLD
			elseif entry.equipped then EQUIPPED else entry.color
		local thickness=if targetSlot or viewing or swapping then 2.5 elseif entry.equipped then 2 else Theme.Border.Card
		-- Fresh cards snap; later changes (selection, drag target) ease. Drag moves repeat values.
		if entry.shownColor==nil then entry.border.Color,entry.border.Thickness=color,thickness
		elseif entry.shownColor~=color or entry.shownThickness~=thickness then
			Theme.Motion:Tween(entry.border,"state",{Color=color,Thickness=thickness},0.12)
		end
		entry.shownColor,entry.shownThickness=color,thickness
		if entry.viewing then entry.viewing.Visible=viewing end
		if entry.selectedEdge then entry.selectedEdge.Visible=viewing end
	end
	for index,slot in self.stripSlots do
		if slot.empty then slot.border.Color=if flockTarget==index or flockTarget==0 then WHITE else EDGE end
	end
end

-- Returns an Army slot (or leaving the Army) for storage drops, and for the Flock
-- strip a slot index (0 for anywhere on it); a Flock chicken dragged out gives -1.
function Browser:DropTarget(point)
	if not inside(self.root,point) then return nil,false,nil end
	local pointer=self.pointer
	if inside(self.strip,point) then
		for index,slot in self.stripSlots do
			if inside(slot.card,point) then return nil,false,index end
		end
		return nil,false,0
	end
	if not inside(self.grid,point) then return nil,false,nil end
	if pointer and pointer.fromStrip then return nil,false,-1 end
	for index,entry in self.slots do
		if inside(entry.card,point) then return index,false,nil end
	end
	if pointer then
		if table.find(pointer.expected,pointer.id) then return nil,true,nil end
		if #pointer.expected<self.app.state.capacity then return #pointer.expected+1,false,nil end
	end
	return nil,false,nil
end

function Browser:CancelPointer(suppress)
	if suppress and self.pointer then self.suppressUntil=os.clock()+0.3 end
	self.pointer=nil
	if self.dragGui then self.dragGui:Destroy();self.dragGui=nil end
	self.grid.ScrollingEnabled,self.strip.ScrollingEnabled=true,true
	self:Highlight(nil,nil)
end

function Browser:StartDrag()
	local pointer=self.pointer
	if not pointer or not self:CanEdit() or not self.root.Visible or not self.parent.Visible then return end
	local pet=self.app:Pet(pointer.id)
	local playerGui=self.root:FindFirstAncestorOfClass("PlayerGui")
	if not pet or not playerGui then return end
	pointer.dragging=true
	self.grid.ScrollingEnabled,self.strip.ScrollingEnabled=false,false
	local gui=Theme.InsetContainer(self.app.other,"ArmyDragPreview",Enum.ScreenInsets.None)
	gui.ZIndex=40
	self.dragGui=gui
	local ghost=Instance.new("Frame")
	ghost.Name,ghost.Size,ghost.BorderSizePixel="Chicken",UDim2.fromScale(0.085,0.14),0
 Theme.Aspect(ghost,112/106)
 ghost.AnchorPoint=Vector2.new(0.5,0.66)
	ghost.Parent=gui;dark(ghost,GREEN)
	local portrait=Preview.Create(ghost,pet,UDim2.fromScale(100/112,76/106),UDim2.fromScale(6/112,2/106))
	portrait.ZIndex=2
	local name=label(ghost,"Name",Catalog[pet.species].name,13,UDim2.fromScale(4/112,80/106),UDim2.fromScale(104/112,20/106))
	name.TextXAlignment=Enum.TextXAlignment.Center
	pointer.ghost=ghost
	ghost.Position=UDim2.fromOffset(pointer.point.X,pointer.point.Y)
	local target,_,flockTarget=self:DropTarget(pointer.point);self:Highlight(target,flockTarget)
end

function Browser:BeginPointer(pet,input,fromStrip)
	local touch=input.UserInputType==Enum.UserInputType.Touch
	if not touch and input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
	if not self:CanEdit() then return end
	self:CancelPointer(false)
	local point=pointOf(input)
	local pointer={id=pet.id,input=input,touch=touch,start=point,point=point,fromStrip=fromStrip==true,
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
		pointer.ghost.Position=UDim2.fromOffset(pointer.point.X,pointer.point.Y)
		local target,_,flockTarget=self:DropTarget(pointer.point);self:Highlight(target,flockTarget)
	end
end

function Browser:PointerEnded(input)
	local pointer=self.pointer
	if not pointer then return end
	if pointer.touch then if input~=pointer.input then return end
	elseif input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
	local target,leaveArmy,flockTarget=self:DropTarget(pointer.point)
	local dragged=pointer.dragging
	self:CancelPointer(dragged)
	if dragged then
		if flockTarget then self:FlockDrop(pointer.id,flockTarget)
		else self:Drop(pointer.id,target,leaveArmy,pointer.expected) end
		self:Render(true)
	end
end


function Browser:Card(parent,pet,slot,order)
 local card=Instance.new("TextButton")
 card.Name,card.Text,card.AutoButtonColor="Chicken_"..pet.id,"",false
 local cellWidth=(877-36)/4
 local cellHeight=cellWidth*220/210
 local cellX,cellY=cellWidth/877,cellHeight/(cellHeight+16)
 card.Size,card.LayoutOrder=UDim2.fromScale(cellX,cellY),order
 -- Centre-anchored (same resting rect) so hover/press scale from the middle.
 card.AnchorPoint=Vector2.new(0.5,0.5)
 card.Position=UDim2.fromScale(((order-1)%4)*(cellWidth+12)/877+cellX/2,cellY/2)
 Theme.Aspect(card,210/220)
 card.BorderSizePixel,card.BackgroundTransparency,card.ClipsDescendants=0,1,true
 card.ZIndex,card.Parent=parent.ZIndex+1,parent
 Theme.Round(card)
 local definition=Catalog[pet.species]
 local rarity=definition.rarity
 local color=RARITIES[rarity] or RARITIES.Common
 local background=art(card,"RarityBackground",Art.Card[rarity] or Art.Card.Common,UDim2.fromScale(1,1))
 background.ScaleType=Enum.ScaleType.Stretch
 Theme.Round(background)
 local ribbon=frame(card,"RarityRibbon",UDim2.fromScale(198/210,26/220),UDim2.fromScale(6/210,6/220))
 ribbon.ZIndex=card.ZIndex+2
 surface(ribbon,color,color:Lerp(Color3.new(0,0,0),0.22),Color3.fromRGB(7,16,22),Theme.Border.Detail)
 local rarityLabel=label(ribbon,"Rarity",string.upper(rarity),18,UDim2.new(),UDim2.fromScale(1,1),WHITE)
 rarityLabel.TextXAlignment=Enum.TextXAlignment.Center
 -- Let the actual chicken fill the card; its PNG already includes transparent padding.
 local portrait=Preview.Create(card,pet,UDim2.fromScale(224.4/210,224.4/220),UDim2.fromScale((210-224.4)/420,(32-224.4*0.16)/220))
 Theme.Aspect(portrait,1)
 portrait.ZIndex=card.ZIndex+3
 if portrait:IsA("ViewportFrame") then
  portrait.Ambient,portrait.LightColor=Color3.fromRGB(202,216,229),Color3.new(1,1,1)
 end
 local name=label(card,"Name",(if pet.giantSize then Giant.Kind(pet.giantSize).." " else "")..definition.name:gsub(" Chicken$",""),27,
  UDim2.fromScale(5/210,161/220),UDim2.fromScale(200/210,26/220),WHITE)
 name.TextXAlignment=Enum.TextXAlignment.Center
 local stats=self:ResearchStats(pet)
 local strength=label(card,"Damage",Theme.Number(stats.damage/stats.interval).." DPS",25,
  UDim2.fromScale(5/210,188/220),UDim2.fromScale(200/210,22/220),GOLD,true)
 strength.TextXAlignment=Enum.TextXAlignment.Center
 local outline=frame(card,"StateOutline",UDim2.fromScale(1,1))
 outline.ZIndex=card.ZIndex+7
 Theme.Round(outline)
 local equipped=slot~=nil
 local border=Theme.Stroke(outline,if equipped then EQUIPPED else color,if equipped then 2 else Theme.Border.Card)
 border.BorderStrokePosition=Enum.BorderStrokePosition.Inner
 local entry={card=card,border=border,id=pet.id,color=color,equipped=equipped,slot=slot}
 self.cards[pet.id]=entry
 if slot then self.slots[slot]=entry end
 card:SetAttribute("PetId",pet.id);card:SetAttribute("InArmy",equipped)
 if equipped then
  local badge=frame(card,"EquippedCheck",UDim2.fromScale(0.25,0.27))
  badge.ZIndex=card.ZIndex+8
  surface(badge,EQUIPPED,EQUIPPED,Color3.fromRGB(23,57,23),Theme.Border.Control)
  art(badge,"Check",Art.Check,UDim2.fromScale(0.75,0.65),UDim2.fromScale(0.1,0.15))
 end
 -- Mutation tag under the rarity ribbon, clear of the equipped check.
 local mutation=MutationVFX.Badge(card,pet.mutation)
 if mutation then
  mutation.Position,mutation.Size=UDim2.fromScale(92/210,36/220),UDim2.fromScale(112/210,28/220)
 end
 -- Laying in place of a Flock chicken that's away: its own egg in the corner.
 if pet.laying then
  local egg=art(card,"Laying",EggArt.Image(pet.species),UDim2.fromScale(40/210,40/220),UDim2.fromScale(166/210,2/220))
  egg.ZIndex=card.ZIndex+8
  Theme.Aspect(egg,1)
 end
 card.Activated:Connect(function()
  if os.clock()<self.suppressUntil then return end
  if self.placing then self:TogglePet(pet.id) else self:Inspect(pet.id) end
 end)
 card.MouseButton2Click:Connect(function() self:Inspect(pet.id) end)
 card.InputBegan:Connect(function(input) self:BeginPointer(pet,input) end)
 Theme.Motion:BindButton(card,Theme.Motion:ScaleOf(card),background)
 return card
end

-- A Flock strip card: compact, with eggs per second instead of DPS. 138 x 150 inside a 146 x 150 slot.
function Browser:SlotCard(holder,pet,armySlot,index)
 local card=Instance.new("TextButton")
 card.Name,card.Text,card.AutoButtonColor="Chicken_"..pet.id,"",false
 card.AnchorPoint,card.Position,card.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(138/146,1)
 card.BorderSizePixel,card.BackgroundTransparency,card.ClipsDescendants=0,1,true
 card.ZIndex,card.Parent=holder.ZIndex+1,holder
 Theme.Round(card)
 local definition=Catalog[pet.species]
 local rarity=definition.rarity
 local color=RARITIES[rarity] or RARITIES.Common
 local background=art(card,"RarityBackground",Art.Card[rarity] or Art.Card.Common,UDim2.fromScale(1,1))
 background.ScaleType=Enum.ScaleType.Stretch
 Theme.Round(background)
 local portrait=Preview.Create(card,pet,UDim2.fromScale(118/138,118/150),UDim2.fromScale(10/138,2/150))
 Theme.Aspect(portrait,1)
 portrait.ZIndex=card.ZIndex+3
 if portrait:IsA("ViewportFrame") then
  portrait.Ambient,portrait.LightColor=Color3.fromRGB(202,216,229),Color3.new(1,1,1)
 end
 local name=label(card,"Name",(if pet.giantSize then Giant.Kind(pet.giantSize).." " else "")..definition.name:gsub(" Chicken$",""),20,
  UDim2.fromScale(4/138,110/150),UDim2.fromScale(130/138,20/150),WHITE)
 name.TextXAlignment=Enum.TextXAlignment.Center
 local eggs=label(card,"Eggs",Theme.Count(pet.eggsPerSecond or 0,"egg/s","eggs/s"),20,
  UDim2.fromScale(4/138,130/150),UDim2.fromScale(130/138,18/150),GOLD,true)
 eggs.TextXAlignment=Enum.TextXAlignment.Center
 -- A Flock chicken out with the Army: another chicken lays in its place until it's back.
 if not pet.laying then
  local away=frame(card,"Away",UDim2.fromScale(1,1))
  away.BackgroundColor3,away.BackgroundTransparency,away.ZIndex=Color3.new(0,0,0),0.45,card.ZIndex+6
  local text=label(away,"Text","AWAY",28,UDim2.fromScale(0,0.3),UDim2.fromScale(1,0.28),WHITE,true)
  text.TextXAlignment=Enum.TextXAlignment.Center
 end
 local outline=frame(card,"StateOutline",UDim2.fromScale(1,1))
 outline.ZIndex=card.ZIndex+7
 Theme.Round(outline)
 local equipped=armySlot~=nil
 local border=Theme.Stroke(outline,if equipped then EQUIPPED else color,if equipped then 2 else Theme.Border.Card)
 border.BorderStrokePosition=Enum.BorderStrokePosition.Inner
 self.cards[pet.id]={card=card,border=border,id=pet.id,color=color,equipped=equipped,flockIndex=index,strip=true}
 self.stripSlots[index]={card=card}
 card:SetAttribute("PetId",pet.id);card:SetAttribute("InArmy",equipped);card:SetAttribute("InFlock",true)
 if equipped then
  local badge=frame(card,"EquippedCheck",UDim2.fromScale(0.26,0.24))
  badge.ZIndex=card.ZIndex+8
  surface(badge,EQUIPPED,EQUIPPED,Color3.fromRGB(23,57,23),Theme.Border.Control)
  art(badge,"Check",Art.Check,UDim2.fromScale(0.75,0.65),UDim2.fromScale(0.1,0.15))
 end
 card.Activated:Connect(function()
  if os.clock()<self.suppressUntil then return end
  if self.placing then self:TogglePet(pet.id)
  elseif self.flockPlacing then self:SwapIntoFlock(pet.id)
  else self:Inspect(pet.id) end
 end)
 card.MouseButton2Click:Connect(function() self:Inspect(pet.id) end)
 card.InputBegan:Connect(function(input) self:BeginPointer(pet,input,true) end)
 Theme.Motion:BindButton(card,Theme.Motion:ScaleOf(card),background)
 return card
end

-- An open Flock slot: tapping it adds the chicken being inspected.
function Browser:EmptySlot(holder,index)
 local slot=Instance.new("TextButton")
 slot.Name,slot.Text,slot.AutoButtonColor="EmptySlot","",false
 slot.AnchorPoint,slot.Position,slot.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(138/146,1)
 slot.BorderSizePixel,slot.ZIndex,slot.Parent=0,holder.ZIndex+1,holder
 local border=dark(slot,EDGE)
 local plus=label(slot,"Plus","+",48,UDim2.fromScale(0,0.18),UDim2.fromScale(1,0.4),MUTED,true)
 plus.TextXAlignment=Enum.TextXAlignment.Center
 local text=label(slot,"Open","Open slot",20,UDim2.fromScale(0.05,0.62),UDim2.fromScale(0.9,0.16),MUTED)
 text.TextXAlignment=Enum.TextXAlignment.Center
 self.stripSlots[index]={card=slot,border=border,empty=true}
 slot.Activated:Connect(function()
  if os.clock()<self.suppressUntil then return end
  self:FillFlockSlot()
 end)
 Theme.Motion:BindButton(slot,Theme.Motion:ScaleOf(slot),slot)
 return slot
end

-- The strip shows every Flock slot: its chickens in order, then open slots.
function Browser:RenderStrip(pets,flock,chosen)
 clear(self.strip)
 self.stripSlots={}
 local members=if flock then flock.ids or {} else {}
 local size=if flock then flock.size or 0 else 0
 for index=1,math.max(size,#members) do
  local pet=members[index] and pets[members[index]]
  local holder=frame(self.strip,"Slot"..index,UDim2.fromScale(1,1))
  holder.LayoutOrder=index
  Theme.Aspect(holder,146/150)
  if pet then self:SlotCard(holder,pet,chosen[pet.id],index) else self:EmptySlot(holder,index) end
 end
 self.fitStrip()
end

-- Storage cards are added a page at a time (storage can hold up to Config.StorageLimit chickens).
function Browser:ShowStorage(count)
 local visible=self.storage
 local target=math.min(#visible,count)
 if self.moreRow then self.moreRow:Destroy();self.moreRow=nil end
 for index=self.storageShown+1,target do
  if (index-1)%4==0 then
   local row=frame(self.grid,"Row"..math.ceil(index/4),UDim2.fromScale(1,1))
   row.LayoutOrder=math.ceil(index/4)
   Theme.Aspect(row,877/(((877-36)/4)*220/210+16))
   self.storageRow=row
  end
  local pet=visible[index]
  self:Card(self.storageRow,pet,self.chosen[pet.id],index)
 end
 self.storageShown=math.max(self.storageShown,target)
 if self.storageShown<#visible then
  local more=Instance.new("TextButton")
  more.Name,more.Text,more.AutoButtonColor="ShowMore","",false
  more.Size,more.LayoutOrder,more.BackgroundTransparency=UDim2.fromScale(1,1),100000,1
  more.ZIndex,more.Parent=self.grid.ZIndex+1,self.grid
  Theme.Aspect(more,877/80)
  local text=label(more,"Text","Show more chickens ("..(#visible-self.storageShown).." more)",22,
   UDim2.fromScale(0,0.15),UDim2.fromScale(1,0.7),MUTED)
  text.TextXAlignment=Enum.TextXAlignment.Center
  more.Activated:Connect(function() self:ShowMoreStorage() end)
  self.moreRow=more
 end
end

function Browser:ShowMoreStorage()
 if not self.moreRow then return end
 self.storageWanted=self.storageShown+STORAGE_PAGE
 self:ShowStorage(self.storageWanted)
 self:Highlight(nil,nil);self.fitGrid()
end

-- Permanent army research is visible in inventory and combined stats.
function Browser:ResearchStats(pet)
 local stats=Rules.Stats(pet.species,pet.stars,pet.level,pet.giantSize)
 -- Upgrades effects (state.effects since October 20; research.effects before).
 local state=self.app.state
 local effects=state and (state.effects or (state.research and state.research.effects))
 if effects then
  stats.damage*=1+(effects.damage or 0)
  stats.hp*=1+(effects.health or 0)
 end
 return stats
end

function Browser:RenderArmyInfo(pets,ids)
	clear(self.infoRoster)
	local dps,hp=0,0
	for index,id in ids do
		local pet=pets[id]
		if not pet then continue end
		local stats=self:ResearchStats(pet)
		dps+=stats.damage/stats.interval;hp+=stats.hp
		local holder=frame(self.infoRoster,"Equipped_"..id,UDim2.fromScale(1,1))
  holder.LayoutOrder=index
  Theme.Aspect(holder,1462/96)
  local row=frame(holder,"Content",UDim2.fromScale(1,84/96))
  Theme.Aspect(row,1462/84)
		dark(row,GREEN)
		local stripe=frame(row,"EquippedStripe",UDim2.fromScale(4/1462,1))
		stripe.BackgroundColor3,stripe.BackgroundTransparency=GREEN,0
		local portrait=Preview.Create(row,pet,UDim2.fromScale(94/1462,76/84),UDim2.fromScale(10/1462,4/84))
  Theme.Aspect(portrait,1)
		portrait.ZIndex=row.ZIndex+1
		label(row,"Name",Catalog[pet.species].name,26,
			UDim2.fromScale(118/1462,13/84),UDim2.fromScale(990/1462,30/84),WHITE,true)
		local mutation=Mutations.Get(pet.mutation)
		label(row,"Status","Lv. "..pet.level.." / "..(if pet.deployed then "Away" else "In Army")
			..(if mutation then " / "..mutation.name else ""),15,
			UDim2.fromScale(118/1462,49/84),UDim2.fromScale(990/1462,23/84),GREEN)
		local damage=label(row,"DPS",Theme.Number(stats.damage/stats.interval).." DPS",25,
			UDim2.fromScale(1138/1462,27/84),UDim2.fromScale(150/1462,32/84),WHITE,true)
		damage.TextXAlignment=Enum.TextXAlignment.Center
		local health=label(row,"HP",Theme.Number(stats.hp).." HP",25,
			UDim2.fromScale(1300/1462,27/84),UDim2.fromScale(150/1462,32/84),WHITE,true)
		health.TextXAlignment=Enum.TextXAlignment.Center
	end
	local state=self.app.state
	local effects=state.effects or (state.research and state.research.effects) or {}
	local damage,health=effects.damage or 0,effects.health or 0
	self.statTiles.Damage.value.Text=Theme.Number(dps)
	self.statTiles.Damage.note.Text=if damage>0 then "includes +"..math.round(damage*100).."% from Upgrades" else "damage per second"
	self.statTiles.Health.value.Text=Theme.Number(hp)
	self.statTiles.Health.note.Text=if health>0 then "includes +"..math.round(health*100).."% from Upgrades" else "maximum hit points"
	self.statTiles.Deployed.value.Text=#ids.." / "..state.capacity
	self.statTiles.Deployed.note.Text="Army slots in use"
	self.statTiles.Flock.value.Text=tostring(#(state.pets or {}))
	self.statTiles.Flock.note.Text="owned chickens"
	self.infoMode.Text=if state.selectionMode=="Manual" then "Your manual Army is selected." else "Best chickens selected automatically."
	local flock=state.flock
	self.infoFooter.Text="Army stats only. Best uses damage, health and splash.\nFlock: "..(if flock then #(flock.laying or {}) else 0)
		.." laying · "..Theme.Count(state.homeEggsPerSecond or 0,"egg/s","eggs/s")
	if #ids==0 then
		label(self.infoRoster,"Empty","No chickens in your Army. Go back and add some.",18,
			UDim2.fromScale(0.01,0.01),UDim2.fromScale(0.98,0.12),MUTED)
	end
end

function Browser:RenderDetail(pet)
 if self.detailPreview then self.detailPreview:Destroy();self.detailPreview=nil end
 if self.detailMutation then self.detailMutation:Destroy();self.detailMutation=nil end
 if not pet or not self.inspecting or not self.detail.Visible then
  self.name.Text,self.metadata.Text="Choose a chicken",""
  self.stats.Text=""
  self.detailHalo.Visible=false
  return
 end
 local definition=Catalog[pet.species]
 self.detailBorder.Color=Color3.fromRGB(23,199,238)
 local stats=self:ResearchStats(pet)
 self.name.Text=definition.name
 local rarity=RARITIES[definition.rarity] or RARITIES.Common
 local oneIn=Catalog.OneInText(pet.species)
 self.metadata.Text=string.format('<font color="#%s">%s</font>%s • Lv. %d',rarity:ToHex(),definition.rarity,if oneIn then " · "..oneIn else "",pet.level)
  ..(if Giant.IsColossal(pet.giantSize) then string.format(' · <font color="#FF6AD5">COLOSSAL</font> · army +%d%% dmg',math.floor(Giant.ColossalArmyDamage*100+0.5))
   elseif pet.giantSize then string.format(' · <font color="#FFB347">GIANT</font> · ×%g HP ×%g dmg · stomp',Giant.HealthMultiplier,Giant.DamageMultiplier)
   else "")
 self.detailHalo.Image,self.detailHalo.Visible=Art.Glow[definition.rarity] or (if definition.rarity=="Secret" then Art.Glow.Mythic else nil) or Art.Glow.Common,not self.hideDetailPreview
 local eggs=pet.eggsPerSecond or Rules.EggRate(pet.species,pet.stars,pet.level)
 self.stats.Text=Theme.Number(stats.damage/stats.interval)..' <font color="#CDD6C7">DPS</font>  •  '
  ..Theme.Number(eggs)..' <font color="#CDD6C7">'..(if Theme.Number(eggs)=="1" then "egg/s" else "eggs/s")..'</font>'
 -- The snapshot's eggs/s already includes the mutation; this tag says why.
 local mutation=Mutations.Get(pet.mutation)
 if mutation then
  self.detailMutation=MutationVFX.Badge(self.detail,pet.mutation,"MutationEggs",
   string.format("Eggs ×%g (%s)",mutation.multiplier,mutation.name))
  if self.detailMutation then
   local preview,at=self.previewSize,self.previewPosition
   self.detailMutation.Size=UDim2.fromScale(preview.X.Scale*0.62,preview.Y.Scale*40/414)
   self.detailMutation.Position=UDim2.fromScale(at.X.Scale+preview.X.Scale*0.19,at.Y.Scale+preview.Y.Scale*0.01)
  end
 end
 if self.hideDetailPreview then return end
 self.detailPreview=Preview.Create(self.detail,pet,self.previewSize,self.previewPosition)
 Theme.Aspect(self.detailPreview,1)
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
	local flock=state.flock
	local members=if flock then flock.ids or {} else {}
	local pets,chosen,inFlock={},{},{}
	for _,id in members do inFlock[id]=true end
	local stored=0
	for _,pet in state.pets or {} do
		pets[pet.id]=pet
		if not inFlock[pet.id] then stored+=1 end
	end
	for slot,id in ids do chosen[id]=slot end
	if self.app.selected and not pets[self.app.selected] then self.app.selected=nil;self.inspecting=false end
	if self.app.selected and self.app.selected~=self.lastSelected then
		self.inspecting,self.showInfo,self.showCapacity=true,false,false
	end
	self.lastSelected=self.app.selected
	if not self:CanEdit() or (self.placing and not pets[self.placing]) then self.placing,self.placingExpected=nil,nil end
	if not self:CanEdit() or (self.flockPlacing and (not pets[self.flockPlacing] or inFlock[self.flockPlacing])) then
		self.flockPlacing=nil
	end
	local dimensions=self:Resize()
	self.app.panelTitle.Text=if self.showInfo then "Army Info"
		elseif self.showCapacity then "More Army Slots" else "My Army"
	self.title.Text=self.app.panelTitle.Text
	local mode=if state.selectionMode=="Manual" then "Manual Army" else "Best selected"
	-- October 20: FLOCK counts the chickens laying against Flock Size; storage shows no cap.
	self.summary.Text=if flock then string.format('<font color="#F9CE43">%d</font> / %d',#members,flock.size)
		else string.format('<font color="#F9CE43">%d</font> / %d',#(state.pets or {}),state.collectionLimit or Config.CollectionLimit)
	self.capacity.Text=string.format('<font color="#F9CE43">%d</font> / %d',#ids,state.capacity)
	self.flockRate.Text=Theme.Count(if flock then flock.eggsPerSecond or 0 else state.homeEggsPerSecond or 0,"egg/s","eggs/s")
	self.sortButton.Text=if self.sort=="Name" then "Name A-Z" elseif self.sort=="Eggs" then "Most eggs" else "Best first"
	self.search.PlaceholderText="Search "..stored.." "..(if stored==1 then "chicken" else "chickens").."…"
	local effects=state.effects or (state.research and state.research.effects)
	local keys={dimensions,table.concat(ids,","),tostring(state.capacity),mode,
		tostring(state.incoming),tostring(state.outgoing),state.armyState,tostring(state.incomeLevel),
		tostring(state.homeEggsPerSecond),self.query,self.sort,tostring(self.placing~=nil),
		table.concat(members,","),tostring(flock and flock.size),
		tostring(effects and effects.damage),tostring(effects and effects.health)}
	table.insert(keys,tostring(state.research and state.research.revision))
	-- The server's version number stands for the whole chicken list when it sends one.
	if state.petsVersion~=nil then table.insert(keys,"v"..state.petsVersion)
	else
		for _,pet in state.pets or {} do
			table.insert(keys,pet.id..":"..pet.species..":"..pet.stars..":"..pet.level..":"..tostring(pet.giantSize)..":"..tostring(pet.home)
				..":"..tostring(pet.deployed)..":"..tostring(pet.levelCap)..":"..tostring(pet.mutation)..":"..tostring(pet.laying))
		end
	end
	-- Cards never read selection/placing; those only re-highlight, so the grid survives a click.
	local gridKey=table.concat(keys,"|")
	local key=gridKey.."|"..(self.app.selected or "").."|"..tostring(self.inspecting).."|"..(self.placing or "").."|"..(self.flockPlacing or "")
	if key==self.key and not force then self:UpdateAction();return end
	self.key=key
	if force or gridKey~=self.gridKey then
		self.gridKey=gridKey
		self.slots,self.cards={},{}
		self:RenderStrip(pets,flock,chosen)
		local scroll=self.grid.CanvasPosition
		clear(self.grid)
		-- Storage: every chicken outside the Flock strip.
		local visible,power={},{}
		for _,pet in state.pets or {} do
			if inFlock[pet.id] then continue end
			-- Player-facing words only: never internal species IDs such as "Duck".
			local mutation=Mutations.Get(pet.mutation)
			local searchText=string.lower(Catalog[pet.species].name.." "..Catalog[pet.species].rarity
				..(if mutation then " "..mutation.name else ""))
			if self.query=="" or string.find(searchText,self.query,1,true) then
				table.insert(visible,pet)
				power[pet.id]=Rules.PetPower(pet.species,pet.stars,pet.level,pet.giantSize)
			end
		end
		local replacing=self.placing~=nil
		table.sort(visible,function(a,b)
			-- While replacing an Army chicken, the Army comes first.
			if replacing and (chosen[a.id]~=nil)~=(chosen[b.id]~=nil) then return chosen[a.id]~=nil end
			if self.sort=="Name" then
				local an,bn=Catalog[a.species].name,Catalog[b.species].name
				if an~=bn then return an<bn end
			elseif self.sort=="Eggs" then
				local ea,eb=a.eggsPerSecond or 0,b.eggsPerSecond or 0
				if ea~=eb then return ea>eb end
			end
			if power[a.id]~=power[b.id] then return power[a.id]>power[b.id] end
			return a.id<b.id
		end)
		self.storage,self.chosen,self.storageShown,self.storageRow,self.moreRow=visible,chosen,0,nil,nil
		self:ShowStorage(self.storageWanted)
		self.grid.CanvasPosition=scroll
		if #visible==0 then
			local holder=frame(self.grid,"EmptyRow",UDim2.fromScale(1,1))
	  Theme.Aspect(holder,877/220)
			local empty=label(holder,"Empty",if self.query~="" then "No matching chickens"
				elseif #(state.pets or {})>0 then "Every chicken is in your Flock. Roll more at the lever in your yard!"
				else "No chickens yet. Roll chickens at the lever in your yard!",
				18,UDim2.new(),UDim2.fromScale(1,1),MUTED)
			empty.TextWrapped,empty.TextTruncate=true,Enum.TextTruncate.None
			empty.TextXAlignment=Enum.TextXAlignment.Center
		elseif #visible<8 and self.query=="" then
			-- A sparse grid points at where more chickens come from.
			local holder=frame(self.grid,"RollHint",UDim2.fromScale(1,1))
			holder.LayoutOrder,holder.BackgroundTransparency=10000,1
			Theme.Aspect(holder,877/90)
			local hint=label(holder,"Hint","Roll more chickens at the lever in your yard!",18,UDim2.new(),UDim2.fromScale(1,1),MUTED)
			hint.TextWrapped,hint.TextTruncate=true,Enum.TextTruncate.None
			hint.TextXAlignment=Enum.TextXAlignment.Center
		end
	end
	if self.showInfo then self:RenderArmyInfo(pets,ids) end
	self:RenderDetail(pets[self.app.selected])
	self:Highlight(nil,nil);self:UpdateAction()
	self.fitGrid();self.fitRoster();self.fitStrip()
	local pop=self.armyPop
	if pop then
		self.armyPop=nil
		if os.clock()-pop.at<1 then self:PopArmyChanges(pop.before,ids) end
	end
	local flockPop=self.flockPop
	if flockPop then
		self.flockPop=nil
		if os.clock()-flockPop.at<1 then self:PopFlockChanges(flockPop.before) end
	end
end

return Browser
