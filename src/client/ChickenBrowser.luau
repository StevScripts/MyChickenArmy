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
 Legendary=Color3.fromRGB(255,213,0),Mythic=Color3.fromRGB(255,54,114),
}
local TONES={
 Green={Color3.fromRGB(165,255,0),Color3.fromRGB(38,227,0),Color3.fromRGB(40,125,6),Color3.fromRGB(217,255,154)},
 Blue={Color3.fromRGB(0,231,255),Color3.fromRGB(0,154,255),Color3.fromRGB(0,91,157),Color3.fromRGB(179,233,255)},
 Red={Color3.fromRGB(255,102,84),Color3.fromRGB(243,36,59),Color3.fromRGB(142,16,40),Color3.fromRGB(255,180,186)},
 Off={Color3.fromRGB(122,132,138),Color3.fromRGB(86,95,101),Color3.fromRGB(48,54,58),Color3.fromRGB(160,170,176)},
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
 local tone=if not item.Active then TONES.Off elseif color==RED then TONES.Red elseif color==CYAN then TONES.Blue else TONES.Green
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
	local self=setmetatable({app=app,parent=parent,key="",pending=nil,connections={},slots={},cards={},
		suppressUntil=0,placing=nil,notice=nil,inspecting=false,showInfo=false,showCapacity=false,
		query="",sort="Best"},Browser)
	local root=Instance.new("Frame")
	root.Name,root.BackgroundTransparency,root.BorderSizePixel="ChickenBrowser",1,0
	root.Visible,root.ClipsDescendants=false,false
	root.ZIndex,root.Parent=parent.ZIndex+1,parent
	root:SetAttribute("OwnsPopupStyle",true)
	self.root=root
 Theme.Aspect(root,1274/876)
 local background=frame(root,"ArmyBackground",UDim2.new(),UDim2.new())
 -- The shared header's window contour also frames this full-height background.
 surface(background,Color3.fromRGB(18,32,41),Color3.fromRGB(18,32,41),INK,3).Enabled=false
 local header,title=Theme.Header(root,"Header","Your Chickens",GREEN)
 Theme.ApplyReferenceAccent(header,ColorSequence.new(Color3.fromRGB(178,255,16),Color3.fromRGB(33,224,0)))
 header.PageIcon.Image,header.PageIcon.Visible=Art.Helmet,true
 self.header,self.title=header,title
 self.closeButton=Theme.HeaderClose(header,function() app.audio:Play("Click");app:ClosePanel() end)
 self.body=frame(root,"ArmyContent",UDim2.new(),UDim2.new())
 self.inventory=frame(self.body,"Inventory",UDim2.fromScale(1,1))
 local inventory=self.inventory
 self.toolbar=frame(inventory,"CapacityToolbar",UDim2.new())
 surface(self.toolbar,Color3.fromRGB(27,39,45),Color3.fromRGB(32,45,53),Color3.fromRGB(3,11,16),2)
 self.flockLabel=label(self.toolbar,"FlockLabel","FLOCK",33,UDim2.new(),UDim2.new(),WHITE)
 self.summary=label(self.toolbar,"FlockCount","",36,UDim2.new(),UDim2.new(),WHITE,true)
 self.summary.RichText=true
 -- Both "+" buttons lead to their cash upgrade in Upgrades; the Robux pass is
 -- the fallback only once cash Army Size is maxed.
 self.flockPlus=button(self.toolbar,"FlockCapacity","+",function()
  self.app.audio:Play("Click")
  local offer=self:CashOffer("PlotSize")
  if offer and offer.ready and offer.price==nil then
   local limit=self.app.state.collectionLimit or Config.CollectionLimit
   self.notice,self.noticeUntil="Your flock is at its maximum of "..limit.." chickens.",os.clock()+4
   self:UpdateAction();return
  end
  self:CancelPointer(true);self.app.research:OpenCash("PlotSize")
 end,GREEN)
 self.flockPlus.Position,self.flockPlus.Size,self.flockPlus.TextSize=UDim2.new(),UDim2.new(),44
 local divider=frame(self.toolbar,"Divider",UDim2.new(),UDim2.new())
 divider.BackgroundColor3,divider.BackgroundTransparency=Color3.fromRGB(132,154,167),0.1
 self.capacityLabel=label(self.toolbar,"CapacityLabel","ARMY",33,UDim2.new(),UDim2.new(),WHITE)
 self.capacity=label(self.toolbar,"ArmyCapacity","",36,UDim2.new(),UDim2.new(),WHITE,true)
 self.capacity.RichText=true
 self.capacityPlus=button(self.toolbar,"MoreArmySlots","+",function()
  self.app.audio:Play("Click");self:CancelPointer(true)
  local offer=self:CashOffer("ArmySize")
  if not (offer and offer.ready and offer.price==nil) then self.app.research:OpenCash("ArmySize");return end
  self.showCapacity,self.showInfo,self.inspecting=true,false,false;self.placing=nil;self:Render(true)
 end,GREEN)
 self.capacityPlus.Position,self.capacityPlus.Size,self.capacityPlus.TextSize=UDim2.new(),UDim2.new(),44
 for _,plus in {self.flockPlus,self.capacityPlus} do
  plus.Visual.Caption.Position,plus.Visual.Caption.Size=UDim2.fromScale(0.025,-0.04),UDim2.fromScale(0.95,1)
 end
 self.best=button(self.toolbar,"SelectBest","Select Best",function()
  if not self:CanEdit() then return end
  self.placing,self.placingExpected,self.saleQuote=nil,nil,nil
  self.search.Text="";self.grid.CanvasPosition=Vector2.zero;self:Send("SelectBest")
 end,GREEN)
 self.best.Position,self.best.Size=UDim2.new(),UDim2.new()
 self.infoButton=button(self.toolbar,"ArmyInfo","Stats",function()
  self.app.audio:Play("Click");self:CancelPointer(true)
  self.showInfo,self.showCapacity,self.inspecting=true,false,false;self.placing=nil;self:Render(true)
 end,CYAN)
 self.infoButton.Position,self.infoButton.Size=UDim2.new(),UDim2.new()
 self.inventoryPanel=frame(inventory,"InventoryPanel",UDim2.new(),UDim2.new())
 surface(self.inventoryPanel,Color3.fromRGB(27,40,47),Color3.fromRGB(13,29,38),EDGE,2)
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
  if self.placing then self.placing,self.placingExpected=nil,nil
  else self.sort=if self.sort=="Best" then "Name" else "Best" end
  self.grid.CanvasPosition=Vector2.zero;self:Render(true)
 end)
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
 self.hint=label(inventory,"InteractionHint","",23,UDim2.new(),UDim2.new(),MUTED)
 self.hint.BackgroundColor3,self.hint.BackgroundTransparency=Color3.fromRGB(20,32,41),0.05
 self.hint.ZIndex,self.hint.Visible=inventory.ZIndex+20,false
 table.insert(self.connections,search:GetPropertyChangedSignal("Text"):Connect(function()
  self.query=string.lower(search.Text):match("^%s*(.-)%s*$") or ""
  self.grid.CanvasPosition=Vector2.zero;self:Render(true)
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
	self.statTiles={}
	for _,definition in {{"Damage","COMBINED DAMAGE",GREEN},{"Health","COMBINED HEALTH",Theme.ReferenceColors.Upgrades},
		{"Deployed","ARMY SELECTED",WHITE},{"Flock","TOTAL FLOCK",WHITE}} do
		local tile=frame(self.armyInfo,definition[1],UDim2.new());dark(tile,EDGE)
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
	self.infoRoster=roster
	self.infoFooter=label(self.armyInfo,"StatsScope","",16,UDim2.new(),UDim2.new(),MUTED)
	self.infoFooter.TextWrapped,self.infoFooter.TextTruncate=true,Enum.TextTruncate.None

	self.capacityPage=scrollingPanel(self.body,"MoreArmySlots")
	self.passTitle=label(self.capacityPage,"Title","Bigger Army",32,UDim2.new(),UDim2.new(),WHITE,true)
	self.passBadge=label(self.capacityPage,"Type","Cash Army Size is maxed · Robux pass",17,UDim2.new(),UDim2.new(),GREEN)
	self.passArt=Theme.Image(self.capacityPage,"BiggerArmy",Theme.Assets.Army,UDim2.new(),UDim2.new())
	self.passArt.ZIndex=self.capacityPage.ZIndex+1
	self.passCopy=label(self.capacityPage,"Description","Bring more chickens into battle.",24,UDim2.new(),UDim2.new(),WHITE)
	self.passCopy.TextWrapped,self.passCopy.TextTruncate=true,Enum.TextTruncate.None
	self.passNote=label(self.capacityPage,"Availability",
		"The Bigger Army pass adds five more army slots on top of your cash upgrades. See the price in Shop.",18,
		UDim2.new(),UDim2.new(),MUTED)
	self.passNote.TextWrapped,self.passNote.TextTruncate=true,Enum.TextTruncate.None
	self.passShop=button(self.capacityPage,"ViewInShop","View in Shop",function()
		self.app.audio:Play("Click");self.app:OpenPage("Shop")
	end,GREEN)
	self.passBack=button(self.capacityPage,"BackToChickens","Back",back,Theme.ReferenceColors.Upgrades)

 -- Fixed inline inspector. Equipment is represented by checks, never a Reserve badge.
 self.detail=scrollingPanel(self.body,"SelectedChicken")
 self.detailBorder=surface(self.detail,Color3.fromRGB(16,35,44),Color3.fromRGB(16,35,44),CYAN,2)
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
 self.assign=button(self.actions,"AssignChicken","Equip",function() self:AssignSelected() end,GREEN)
 fitInspectorLine(self.assign,42,14)
 self.sell=button(self.actions,"SellChicken","Sell",function() self:ReviewSale() end,RED)
 self.assign.LayoutOrder,self.sell.LayoutOrder=1,2
 fitInspectorLine(self.sell,38,14)
 self.mergeHint=label(self.detail,"MergeHint","",23,UDim2.new(),UDim2.new(),MUTED)
 self.mergeHint.TextXAlignment=Enum.TextXAlignment.Center
 fitInspectorLine(self.mergeHint,23,12)
 self.detailBack=button(self.body,"BackToFlock","Back to flock",function()
  self.app.audio:Play("Click");self.inspecting=false;self.app.selected=nil
  self.saleQuote=nil;self:Render(true)
 end,CYAN)
 self.detailBack.Visible=false

	self.salePanel=frame(self.detail,"ConfirmSale",UDim2.new())
	dark(self.salePanel,RED)
	self.salePrompt=label(self.salePanel,"Quote","",14,UDim2.new(),UDim2.new(),WHITE)
	self.salePrompt.TextWrapped,self.salePrompt.TextTruncate=true,Enum.TextTruncate.None
	self.salePrompt.TextYAlignment=Enum.TextYAlignment.Top
	self.saleConfirm=button(self.salePanel,"ConfirmSale","Confirm sale",function() self:ConfirmSale() end,RED)
	self.saleConfirm.Position,self.saleConfirm.Size=UDim2.new(),UDim2.new()
	self.saleCancel=button(self.salePanel,"KeepChicken","Keep chicken",function()
		self.app.audio:Play("Click");self.saleQuote=nil;self:UpdateAction()
	end,CYAN)
	self.saleCancel.Position,self.saleCancel.Size=UDim2.new(),UDim2.new()
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
 self:Resize()
	return self
end

function Browser:CashOffer(key)
	local offers=self.app.state and self.app.state.boardUpgrades
	return offers and offers[key]
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
 rect(self.capacity,569,10,102,64,width,85)
 rect(self.capacityPlus,676,13,66,62,width,85)
 Theme.Aspect(self.capacityPlus,66/62)
 rect(self.best,975,13,294,64,width,85)
 rect(self.infoButton,1280,13,180,64,width,85)
 rect(self.inventoryPanel,6,92,903,inventoryHeight,width,bodyHeight)
 rect(self.searchShell,16,12,584,60,903,inventoryHeight)
 rect(self.searchShell.SearchIcon,16,12,38,38,584,60)
 Theme.Aspect(self.searchShell.SearchIcon,1)
 rect(self.search,75,0,480,60,584,60)
 Theme.ScaleText(self.search)
 rect(self.sortButton,614,12,270,60,903,inventoryHeight)
 rect(self.sortButton.Caption,18,0,195,60,270,60)
 rect(self.sortButton.Chevron,221,18,34,24,270,60)
 rect(self.grid,13,87,877,inventoryHeight-99,903,inventoryHeight)
 self.grid.ScrollBarThickness=0
 rect(self.hint,19,bodyHeight-48,887,44,width,bodyHeight)
 self.hint.TextWrapped=true
 rect(self.detail,931,95,535,detailHeight,width,bodyHeight)
 self.detail.CanvasSize=UDim2.new()
 self.detail.ScrollBarThickness=0
 rect(self.name,14,16,507,54,535,detailHeight)
 rect(self.metadata,14,78,507,28,535,detailHeight)
 self.previewSize=UDim2.fromScale(414/535,414/detailHeight)
 self.previewPosition=UDim2.fromScale(60.5/535,102/detailHeight)
 rect(self.detailHalo,73.5,114,388,388,535,detailHeight)
 Theme.Aspect(self.detailHalo,1)
 rect(self.stats,14,510,507,48,535,detailHeight)
 rect(self.upgrade,14,566,507,86,535,detailHeight)
 rect(self.mergeHint,14,660,507,28,535,detailHeight)
 rect(self.actions,14,696,507,72,535,detailHeight)
 self.actionLayout.Padding=UDim.new(12/507,0)
 self.assign.Size,self.sell.Size=UDim2.fromScale(331/507,1),UDim2.fromScale(164/507,1)
 rect(self.detailNotice,14,780,507,44,535,detailHeight)
 self.detailNotice.TextWrapped=true
 rect(self.salePanel,14,510,507,266,535,detailHeight)
 rect(self.salePrompt,8,8,491,120,507,266)
 rect(self.saleConfirm,8,140,491,52,507,266)
 rect(self.saleCancel,8,204,491,48,507,266)
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
	self.pending={id=id,at=os.clock(),action=action,petId=if action=="Sell" and payload then payload.petIds[1] else payload and payload.petId}
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
		if pending.action=="UpgradeChicken" and result.ok then self.app.feedback:Action("Income") end
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
	self.best.Text=if self.pending and self.pending.action=="SelectBest" then "Selecting…" else "Select Best"
	self.hint.Text=if self.notice then self.notice
		elseif self.pending then (if self.pending.action=="Sell" then "Selling chicken…" elseif self.pending.action=="UpgradeChicken" then "Upgrading chicken…" else "Updating army…")
		elseif self.placing then "Choose a green-checked chicken to replace, or tap Cancel."
		elseif not canEdit then "Updating army…"
		else ""
	self.hint.Visible=self.hint.Text~=""
	self.hint.TextColor3=if self.notice then Color3.fromRGB(255,120,132) else MUTED
	self.detailNotice.Text=if self.notice then self.notice
		elseif self.pending then "Updating…"
		elseif pet and self:ColossalSlot(pet.id) then "Only 1 Colossal per army."
		else ""
	self.detailNotice.TextColor3=self.hint.TextColor3
	local price=pet and pet.upgradePrice
	local affordable=type(price)=="number" and state.coins>=price
	enabled(self.upgrade,canEdit and pet~=nil and pet.canUpgrade==true and affordable)
	self.upgrade.Text=if self.pending and self.pending.action=="UpgradeChicken" then "Upgrading…"
		elseif pet and pet.level>=Config.MaxPetLevel then "Max Level"
		elseif type(price)=="number" then 'Upgrade  <font color="#FFDE29">$'..Theme.Money(price)..'</font>' else "Upgrade"
	enabled(self.assign,canEdit and pet~=nil)
	self.assign.Text=if pet and pet.selected then "Unequip"
		elseif pet and self:ColossalSlot(pet.id) then "Replace Colossal"
		elseif #(state.selectedIds or {})>=state.capacity then "Replace…" else "Equip"
	-- A home reserve can be sold even while the rest of the squad is away.
	local canSell=self.pending==nil and self:SaleEligible(pet)
	enabled(self.sell,canSell)
	self.sell.Text=if self.pending and self.pending.action=="Sell" then "Selling…" else "Sell"
	local reviewing=self.saleQuote~=nil
	self.salePanel.Visible=reviewing

	self.stats.Visible,self.assign.Visible,self.sell.Visible=not reviewing,not reviewing,not reviewing
	self.upgrade.Visible,self.mergeHint.Visible=not reviewing,not reviewing and pet~=nil
	self.detailNotice.Visible=not reviewing and self.detailNotice.Text~=""
	enabled(self.saleConfirm,canSell and reviewing)
	enabled(self.saleCancel,self.pending==nil)
	if self.saleQuote then
		local quote=self.saleQuote
		self.salePrompt.Text="Sell "..quote.name.." permanently?\nHome egg income -$"..Theme.Money(quote.income).."/s."
		self.saleConfirm.Text=if self.pending then "Selling…" else "Sell for $"..Theme.Money(quote.refund)
	end
	self.mergeHint.Text=""
	if pet then
		self.mergeHint.Text=if self.pending and self.pending.action=="UpgradeChicken" then ""
			elseif pet.level>=Config.MaxPetLevel then "Max level reached"
			elseif pet.canUpgrade==false then pet.upgradeReason or "Return this chicken home to upgrade."
			elseif not affordable then "Not enough cash"
			else "Upgrades boost damage and egg production"
	end
end

function Browser:UpgradeSelected()
	local pet=self.app:Pet(self.app.selected)
	if not self:CanEdit() or not pet or pet.canUpgrade~=true or type(pet.upgradePrice)~="number"
		or self.app.state.coins<pet.upgradePrice or self.saleQuote then return end
	self:CancelPointer(true);self.placing,self.placingExpected=nil,nil
	self:Send("UpgradeChicken",{petId=pet.id,expectedLevel=pet.level,expectedPrice=pet.upgradePrice})
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
	elseif self:ColossalSlot(id) then self:Drop(id,self:ColossalSlot(id),false,ids)
	elseif #ids<self.app.state.capacity then self:Drop(id,#ids+1,false,ids)
	else
		self.app.audio:Play("Click")
		self.placing,self.placingExpected=id,table.clone(ids)
		self.inspecting,self.showInfo=false,false
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
	local colossals=0
	for _,petId in ids do local pet=self.app:Pet(petId);if pet and Giant.IsColossal(pet.giantSize) then colossals+=1 end end
	if colossals>Giant.MaxArmyColossals then
		self.notice,self.noticeUntil="Only 1 Colossal per army. Replace your equipped Colossal.",os.clock()+4
		self:UpdateAction();return
	end
	self.placing,self.placingExpected=nil,nil
	self:Send("SetArmy",{petIds=ids,expectedIds=table.clone(expected)})
end


function Browser:Highlight(target,toFlock)
	for _,entry in self.cards do
		local targetSlot=entry.slot and entry.slot==target
		local viewing=self.inspecting and self.app.selected==entry.id
		entry.border.Color=if targetSlot then WHITE elseif viewing then SELECTED elseif entry.equipped then EQUIPPED else entry.color
		entry.border.Thickness=if targetSlot or viewing then 2.5 elseif entry.equipped then 2 else Theme.Border.Card
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
		pointer.ghost.Position=UDim2.fromOffset(pointer.point.X,pointer.point.Y)
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


function Browser:Card(parent,pet,slot,order)
 local card=Instance.new("TextButton")
 card.Name,card.Text,card.AutoButtonColor="Chicken_"..pet.id,"",false
 local cellWidth=(877-36)/4
 local cellHeight=cellWidth*220/210
 card.Size,card.LayoutOrder=UDim2.fromScale(cellWidth/877,cellHeight/(cellHeight+16)),order
 card.Position=UDim2.fromScale(((order-1)%4)*(cellWidth+12)/877,0)
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
 card.Activated:Connect(function()
  if os.clock()<self.suppressUntil then return end
  if self.placing then self:TogglePet(pet.id) else self:Inspect(pet.id) end
 end)
 card.MouseButton2Click:Connect(function() self:Inspect(pet.id) end)
 card.InputBegan:Connect(function(input) self:BeginPointer(pet,input) end)
 return card
end

-- Permanent army research is visible in inventory and combined stats.
function Browser:ResearchStats(pet)
 local stats=Rules.Stats(pet.species,pet.stars,pet.level)
 local research=self.app.state and self.app.state.research
 if research then
  stats.damage*=1+research.effects.damage
  stats.hp*=1+research.effects.health
 end
 return stats
end

function Browser:RenderArmyInfo(pets,ids)
	clear(self.infoRoster)
	local dps,hp,homeCount=0,0,0
	for _,pet in pets do
		if pet.home then homeCount+=1 end
	end
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
		label(row,"Status","Lv. "..pet.level.." / "..(if pet.deployed then "Away" else "In Army"),15,
			UDim2.fromScale(118/1462,49/84),UDim2.fromScale(990/1462,23/84),GREEN)
		local damage=label(row,"DPS",Theme.Number(stats.damage/stats.interval).." DPS",25,
			UDim2.fromScale(1138/1462,27/84),UDim2.fromScale(150/1462,32/84),WHITE,true)
		damage.TextXAlignment=Enum.TextXAlignment.Center
		local health=label(row,"HP",Theme.Number(stats.hp).." HP",25,
			UDim2.fromScale(1300/1462,27/84),UDim2.fromScale(150/1462,32/84),WHITE,true)
		health.TextXAlignment=Enum.TextXAlignment.Center
	end
	local state=self.app.state
	self.statTiles.Damage.value.Text=Theme.Number(dps)
	self.statTiles.Damage.note.Text=if state.research and state.research.effects.damage>0 then "includes +"..math.round(state.research.effects.damage*100).."% research" else "damage per second"
	self.statTiles.Health.value.Text=Theme.Number(hp)
	self.statTiles.Health.note.Text=if state.research and state.research.effects.health>0 then "includes +"..math.round(state.research.effects.health*100).."% research" else "maximum hit points"
	self.statTiles.Deployed.value.Text=#ids.." / "..state.capacity
	self.statTiles.Deployed.note.Text="army slots in use"
	self.statTiles.Flock.value.Text=tostring(#(state.pets or {}))
	self.statTiles.Flock.note.Text="owned chickens"
	self.infoMode.Text=if state.selectionMode=="Manual" then "Your manual lineup is selected." else "Best chickens selected automatically."
	self.infoFooter.Text="Equipped stats only. Best uses damage, health and splash.\nHome flock: "..homeCount.." chickens / "..Theme.Count(state.homeEggsPerSecond or 0,"egg/s","eggs/s")
	if #ids==0 then
		label(self.infoRoster,"Empty","No chickens selected. Return to your flock and equip a team.",18,
			UDim2.fromScale(0.01,0.01),UDim2.fromScale(0.98,0.12),MUTED)
	end
end

function Browser:RenderDetail(pet)
 if self.detailPreview then self.detailPreview:Destroy();self.detailPreview=nil end
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
 self.metadata.Text=string.format('<font color="#%s">%s</font> • Lv. %d',rarity:ToHex(),definition.rarity,pet.level)
  ..(if pet.giantSize then " · "..Giant.Label(pet.giantSize) else "")
 self.detailHalo.Image,self.detailHalo.Visible=Art.Glow[definition.rarity] or Art.Glow.Common,not self.hideDetailPreview
 local eggs=pet.eggsPerSecond or Rules.EggRate(pet.species,pet.stars,pet.level)
 self.stats.Text=Theme.Number(stats.damage/stats.interval)..' <font color="#CDD6C7">DPS</font>  •  '
  ..Theme.Number(eggs)..' <font color="#CDD6C7">'..(if Theme.Number(eggs)=="1" then "egg/s" else "eggs/s")..'</font>'
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
		elseif self.showCapacity then "More Army Slots" else "Your Chickens"
	self.title.Text=self.app.panelTitle.Text
	local mode=if state.selectionMode=="Manual" then "Manual lineup" else "Best selected"
	self.summary.Text=string.format('<font color="#F9CE43">%d</font> / %d',#ordered,state.collectionLimit or Config.CollectionLimit)
	self.capacity.Text=string.format('<font color="#F9CE43">%d</font> / %d',#ids,state.capacity)
	self.sortButton.Text=if self.placing then "Cancel" elseif self.sort=="Name" then "Name A-Z" else "Best first"
	local keys={dimensions,self.app.selected or "",table.concat(ids,","),tostring(state.capacity),mode,
		tostring(state.incoming),tostring(state.outgoing),state.armyState,tostring(state.incomeLevel),
		tostring(state.homeEggsPerSecond),self.query,self.sort,self.placing or ""}
	table.insert(keys,tostring(state.research and state.research.revision))
	for _,pet in state.pets or {} do
		table.insert(keys,pet.id..":"..pet.species..":"..pet.stars..":"..pet.level..":"..tostring(pet.giantSize)..":"..tostring(pet.home)..":"..tostring(pet.deployed)..":"..tostring(pet.levelCap))
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
	local row
 for index,pet in visible do
  if (index-1)%4==0 then
   row=frame(self.grid,"Row"..math.ceil(index/4),UDim2.fromScale(1,1))
   row.LayoutOrder=math.ceil(index/4)
   Theme.Aspect(row,877/(((877-36)/4)*220/210+16))
  end
  self:Card(row,pet,chosen[pet.id],index)
 end
	self.grid.CanvasPosition=scroll
	if #visible==0 then
		local holder=frame(self.grid,"EmptyRow",UDim2.fromScale(1,1))
  Theme.Aspect(holder,877/220)
		local empty=label(holder,"Empty",if self.query~="" then "No matching chickens"
			else "Your flock is empty. Roll chickens at the lever in your yard!",
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
	if self.showInfo then self:RenderArmyInfo(pets,ids) end
	self:RenderDetail(pets[self.app.selected])
	self:Highlight(nil,false);self:UpdateAction()
end

return Browser
