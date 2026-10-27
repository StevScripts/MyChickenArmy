--!strict
-- Discovery remains server-owned. This browser only presents the approved roster.
-- October 21 reference parity (docs/team/REFERENCE_PARITY_20261021.md, frame t43/t47):
-- the reference Index. A column of mutation tabs outside the window's left edge
-- (Normal, Golden, Rainbow, Shadow, Cosmic); inside, "Normal (x1)" beside a progress
-- bar "7 / 52", then one section per rarity ("Common 5/8" and a rule) of cards with
-- the name on top ("???" until found), the portrait (a black silhouette until found)
-- and the zero-Luck odds ("1 in 19K") underneath. The reference's Rewards column is a
-- new economy feature and is not built. Mutation tabs count the chickens owned with
-- that mutation (the save keeps no per-mutation discovery).
local Theme=require(script.Parent.UITheme)
local MenuLayout=require(script.Parent.MenuLayout)
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Config=require(Shared.Config)
local IndexProgress=require(Shared.IndexProgress)
local Mutations=require(Shared.MutationCatalog)
local Portraits=require(script.Parent.ChickenPortraits)
local Browser={}
Browser.__index=Browser

-- October 20 overhaul (S8): the Rebirth chickens (PetCatalog.RebirthOrder, one per
-- rank) close the Index as "Rebirth N" silhouettes until owned. Catalog.Order may
-- already list them, so only missing ones are added.
local ORDER=table.clone(Catalog.Order)
do
	local listed={}
	for _,species in ORDER do listed[species]=true end
	for _,species in (Catalog::any).RebirthOrder or {} do
		if not listed[species] and Catalog[species] then table.insert(ORDER,species);listed[species]=true end
	end
end

-- Rarity sections in the order they first appear in the roster (Common first).
local RARITIES={}
do
	local seen={}
	for _,species in ORDER do
		local rarity=Catalog[species].rarity
		if not seen[rarity] then seen[rarity]=true;table.insert(RARITIES,rarity) end
	end
end

-- Normal, then the mutations in their catalog order.
local TABS={{id="Normal",name="Normal",multiplier=1,color=Color3.new(1,1,1)}}
for _,id in Mutations.Order do
	local def=Mutations.Get(id)
	if def then table.insert(TABS,{id=id,name=def.name,multiplier=def.multiplier,color=def.color}) end
end

-- Rebirth chickens wear their base look until the art pass adds their portraits.
local function portraitSpecies(species)
	local definition=Catalog[species]
	if (Portraits::any)[species] or not definition.rebirthRank or not definition.baseSpecies then return species end
	return definition.baseSpecies
end

local REST=UDim2.fromScale(0.5,0.5)
local CARD_SIZE=UDim2.fromScale(0.976,0.976)
local WHITE=Color3.new(1,1,1)
local BLACK=Color3.new(0,0,0)
local BAR_GOLD=Color3.fromRGB(255,200,40)
-- Grid units: the cards' content frame is 1 wide. Four columns keep names and odds at
-- the readable floor on a phone (the reference fits five beside its Rewards column).
local COLUMNS=4
local GAP=0.03
local CELL_W=(1-(COLUMNS-1)*GAP)/COLUMNS
local CELL_H=CELL_W*1.12
local SECTION_H=0.06
local SECTION_GAP=0.035
-- The mutation tab column outside the window: its share of the window's width and
-- height (five tabs about 48 px each on a phone, nearly square everywhere).
local TAB_COLUMN=Vector2.new(0.145,1.04)
-- October 21 game feel (docs/team/GAME_FEEL_20261021.md): an authored cue, or its
-- fallback until the sound session adds it (UI Lab previews stub audio without Has).
-- Presentation only; one client audio.
local Audio=nil
local function cue(name,fallback,pitch,options)
	if not Audio then return end
	if type(Audio.Has)=="function" and Audio:Has(name) then Audio:Play(name,pitch,options)
	elseif fallback then Audio:Play(fallback,pitch,options) end
end
local DISCOVERY_GLOW_SECONDS=2

local function previewPosition(_collected)
	return UDim2.fromScale(0.5,0.53)
end

-- "Mushroom Chicken" reads "Mushroom" on a card (the tooltip-free grid has no room).
local function shortName(species)
	local name=Catalog[species].name
	return (name:gsub(" Chicken$",""))
end

-- The card's bottom line: zero-Luck odds, or where a chicken without odds comes from.
local function oddsText(species)
	local definition=Catalog[species]
	if definition.rebirthRank then return "Rebirth "..definition.rebirthRank end
	if definition.oneIn then return "1 in "..Theme.Number(definition.oneIn) end
	if definition.hillExclusive then return "The Hill" end
	if definition.limited then return "Limited" end
	if definition.vaulted then return "Retired" end
	return "Galaxy Crate"
end

local function label(parent,name,text,color,align)
	local item=Theme.Label(parent,name,text,24,color or WHITE)
	item.TextScaled,item.TextWrapped=true,false
	item.TextXAlignment=align or Enum.TextXAlignment.Left
	item.ZIndex=parent.ZIndex+3
	return item
end

local function place(item,x,y,w,h)
	item.Position,item.Size=UDim2.fromScale(x,y),UDim2.fromScale(w,h)
	return item
end

function Browser.new(app,parent)
	local self=setmetatable({
		app=app,parent=parent,cards={},sections={},tabs={},connections={},pending={},alive=true,opened=false,
		reveal=nil::any,mutation="Normal",layoutKey=nil::string?,switching=false,column=nil::any,contentHeight=nil::number?,
	},Browser)
	Audio=app.audio
	local root=Theme.Frame(parent,"IndexBrowser",UDim2.fromScale(0.98,0.96))
	root.Position,root.BackgroundTransparency,root.Visible=UDim2.fromScale(0.01,0.02),1,false
	root:SetAttribute("OwnsPopupStyle",true)
	self.root=root

	-- Top row: "Normal (x1)" and the progress bar with the Index book at its left end.
	local tabTitle=label(root,"TabTitle","Normal (x1)",WHITE)
	place(tabTitle,0,0.01,0.27,0.085)
	self.tabTitle=tabTitle
	local bar=Theme.Frame(root,"Progress",UDim2.new(),BLACK)
	place(bar,0.34,0.018,0.66,0.068)
	bar.BackgroundTransparency=0.2
	Theme.Stroke(bar,BLACK,2)
	bar.ClipsDescendants=false
	local fill=Theme.Frame(bar,"Fill",UDim2.fromScale(0,1),WHITE)
	Theme.Gradient(fill,BAR_GOLD:Lerp(WHITE,0.25),BAR_GOLD)
	fill.ZIndex=bar.ZIndex+1
	local count=label(bar,"Count","0 / 0",WHITE,Enum.TextXAlignment.Center)
	place(count,0.1,0.06,0.8,0.88)
	local book=Theme.Image(root,"Book",Theme.Assets.Index,UDim2.new())
	book.AnchorPoint=Vector2.new(0.5,0.5)
	place(book,0.345,0.052,0.08,0.115)
	Theme.Aspect(book,1)
	book.ZIndex=bar.ZIndex+4
	self.bar,self.fill,self.count,self.book=bar,fill,count,book

	-- One scrolling collection: rarity sections of cards.
	local grid=Instance.new("ScrollingFrame")
	grid.Name="IndexGrid"
	place(grid,0,0.12,1,0.88)
	grid.BackgroundTransparency,grid.BorderSizePixel,grid.ScrollBarThickness=1,0,0
	grid.ScrollBarImageColor3=Theme.ActionColors.navigation
	grid.AutomaticCanvasSize,grid.CanvasSize=Enum.AutomaticSize.None,UDim2.new()
	grid.ScrollingDirection,grid.VerticalScrollBarInset=Enum.ScrollingDirection.Y,Enum.ScrollBarInset.Always
	grid.ClipsDescendants,grid.Parent=true,root
	-- The canvas follows one width-constrained content frame laid out in grid units,
	-- so row heights never depend on the growing canvas.
	local content=Theme.Frame(grid,"Cards",UDim2.fromScale(0.96,1000))
	content.Position,content.BackgroundTransparency=UDim2.fromScale(0.02,0),1
	Theme.Aspect(content,1)
	self.grid,self.cardHolder=grid,content

	self:BuildTabs()
	table.insert(self.connections,root:GetPropertyChangedSignal("Visible"):Connect(function() self:SyncVisibility() end))
	table.insert(self.connections,parent:GetPropertyChangedSignal("Visible"):Connect(function() self:SyncVisibility() end))
	table.insert(self.connections,app.panel:GetPropertyChangedSignal("Visible"):Connect(function() self:SyncVisibility() end))
	Theme.ScaleText(root)
	self:Resize()
	return self
end

-- The mutation tabs sit outside the window's left edge, top to bottom, like the
-- reference's fruit tabs; they show and hide with the Index.
function Browser:BuildTabs()
	local window=self.parent.Parent
	local column=Theme.Container(window,"IndexMutationTabs")
	column.AnchorPoint,column.Position=Vector2.new(1,0.5),UDim2.fromScale(-0.012,0.5)
	column.Size=UDim2.fromScale(TAB_COLUMN.X,TAB_COLUMN.Y)
	column.Visible,column.ZIndex=false,self.root.ZIndex
	column:SetAttribute("OwnsPopupStyle",true)
	self.column=column
	local pitch=1/#TABS
	for index,tab in TABS do
		local button=Instance.new("TextButton")
		button.Name,button.Text,button.AutoButtonColor,button.BackgroundTransparency="Tab"..tab.id,"",false,1
		button.BorderSizePixel,button.Selectable=0,true
		place(button,0,(index-1)*pitch,1,pitch)
		button.ZIndex=column.ZIndex+1
		button.Parent=column
		local visual=Theme.Frame(button,"Visual",UDim2.fromScale(0.96,0.92),Theme.Shell.Card)
		visual.AnchorPoint,visual.Position=Vector2.new(0.5,0.5),REST
		visual.ZIndex=button.ZIndex
		Theme.ShellCard(visual)
		-- The shell's darker cards read on bright worlds; tabs sit on the world itself.
		visual.BackgroundColor3,visual.BackgroundTransparency=Theme.Shell.Body,0.3
		local icon=self.app:Preview(visual,{species="Duck",stars=1,level=1},UDim2.fromScale(0.86,0.66),UDim2.fromScale(0.5,0.4))
		icon.AnchorPoint=Vector2.new(0.5,0.5)
		icon.ZIndex=visual.ZIndex+1
		if icon:IsA("ImageLabel") and tab.id~="Normal" then icon.ImageColor3=tab.color:Lerp(WHITE,0.2) end
		local name=label(visual,"Name",tab.name,WHITE,Enum.TextXAlignment.Center)
		place(name,0.04,0.72,0.92,0.24)
		Theme.Motion:BindButton(button,visual)
		button:SetAttribute("ClickSound",false)
		button.Activated:Connect(function() self:SelectTab(tab.id) end)
		self.tabs[tab.id]={button=button,visual=visual,stroke=visual:FindFirstChildWhichIsA("UIStroke")}
	end
	Theme.ScaleText(column)
	self:PaintTabs()
	table.insert(self.connections,self.root:GetPropertyChangedSignal("Visible"):Connect(function()
		column.Visible=self.root.Visible
	end))
	column.Visible=self.root.Visible
end

function Browser:PaintTabs()
	for id,view in self.tabs do
		local selected=id==self.mutation
		if view.stroke then
			view.stroke.Color=if selected then Color3.fromRGB(226,232,238) else BLACK
			view.stroke.Transparency=if selected then 0 else Theme.Shell.CardStrokeTransparency
			view.stroke.Thickness=if selected then 3 else Theme.Shell.CardStroke
		end
		view.visual.BackgroundTransparency=if selected then 0.12 else 0.3
	end
end

function Browser:SelectTab(id)
	if id==self.mutation or not self.alive then return end
	cue("TabSwitch","Click")
	self.mutation=id
	self:PaintTabs()
	local view=self.tabs[id]
	if view then Theme.Motion:PopScale(view.visual,1.08) end
	self.switching=true
	self:Render(true)
	self.switching=false
	Theme.Motion:Punch(self.bar,1.05,0.24)
	if self.opened then self:Reveal() end
end

function Browser:BuildCards()
	if next(self.cards) then return end
	for _,rarity in RARITIES do
		local header=Theme.Container(self.cardHolder,"Section"..rarity)
		header.ZIndex=self.cardHolder.ZIndex+1
		local name=label(header,"Rarity",rarity,Theme.Rarities[rarity] or WHITE)
		place(name,0,0.05,0.3,0.9)
		name.TextXAlignment=Enum.TextXAlignment.Left
		local count=label(header,"Count","0/0",WHITE)
		place(count,0.31,0.15,0.16,0.7)
		local rule=Theme.Frame(header,"Rule",UDim2.new(),Theme.Tones.Secondary)
		place(rule,0.49,0.48,0.51,0.05)
		rule.BackgroundTransparency=0.55
		self.sections[rarity]={root=header,count=count}
	end
	for i,species in ORDER do
		local slot=Theme.Frame(self.cardHolder,"Entry_"..i,UDim2.fromScale(CELL_W,CELL_H),WHITE)
		slot.LayoutOrder,slot.BackgroundTransparency=i,1
		local visual=Theme.Frame(slot,"Visual",CARD_SIZE,Theme.Shell.Card)
		visual.Position,visual.AnchorPoint,visual.ClipsDescendants=REST,Vector2.new(0.5,0.5),false
		Theme.ShellCard(visual)
		local rim=visual:FindFirstChildWhichIsA("UIStroke")::UIStroke
		local preview=self.app:Preview(visual,{species=portraitSpecies(species),stars=1,level=1},
			UDim2.fromScale(0.8,0.8),previewPosition(true))
		preview.ImageColor3,preview.ImageTransparency=BLACK,0
		preview.AnchorPoint=Vector2.new(0.5,0.5)
		preview.ZIndex=visual.ZIndex+1
		Theme.Aspect(preview,1)
		-- Name on top, odds underneath; both stay readable in front of the portrait.
		local name=label(visual,"Name","???",WHITE,Enum.TextXAlignment.Center)
		place(name,0.04,0.03,0.92,0.19)
		local odds=label(visual,"OneIn",oddsText(species),WHITE,Enum.TextXAlignment.Center)
		place(odds,0.04,0.8,0.92,0.17)
		local view={root=slot,visual=visual,preview=preview,name=name,odds=odds,rim=rim,collected=nil::boolean?,rimRest=nil::number?}
		self.cards[species]=view

		local function hover(active)
			if not self.alive or not self.opened then return end
			local moving=active and not Theme.Motion.reduced
			Theme.Motion:Tween(visual,"index-size",{Size=if moving then UDim2.fromScale(1.02,1.02) else CARD_SIZE},0.15)
			Theme.Motion:Tween(preview,"index-lift",{
				Position=previewPosition(view.collected==true)+UDim2.fromScale(0,if moving then -0.02 else 0),
			},0.17)
			Theme.Motion:Tween(rim,"index-highlight",{Transparency=if active then 0 else (view.rimRest or 0.2)},0.15)
		end
		table.insert(self.connections,visual.MouseEnter:Connect(function() hover(true) end))
		table.insert(self.connections,visual.MouseLeave:Connect(function() hover(false) end))
	end
	-- Names, counts and odds keep the shared readable floor (UITheme.MinTextSize) on phones.
	Theme.ScaleText(self.cardHolder)
end

-- Sections and cards in grid units (content width 1), rebuilt when which chickens
-- show changes (event-only chickens come and go).
function Browser:Layout(shown)
	local keyParts={}
	for _,species in ORDER do if shown[species] then table.insert(keyParts,species) end end
	local key=table.concat(keyParts,",")
	if key==self.layoutKey then return end
	self.layoutKey=key
	local placements,y={},0
	for _,rarity in RARITIES do
		local members={}
		for _,species in ORDER do
			if shown[species] and Catalog[species].rarity==rarity then table.insert(members,species) end
		end
		local section=self.sections[rarity]
		section.root.Visible=#members>0
		if #members>0 then
			if y>0 then y+=SECTION_GAP end
			table.insert(placements,{item=section.root,x=0,y=y,w=1,h=SECTION_H})
			y+=SECTION_H+GAP*0.5
			for index,species in members do
				local column=(index-1)%COLUMNS
				local row=math.floor((index-1)/COLUMNS)
				table.insert(placements,{item=self.cards[species].root,x=column*(CELL_W+GAP),y=y+row*(CELL_H+GAP),w=CELL_W,h=CELL_H})
			end
			y+=math.ceil(#members/COLUMNS)*(CELL_H+GAP)-GAP
		end
	end
	local height=math.max(y,0.01)
	for index,entry in placements do
		entry.item.Position=UDim2.fromScale(entry.x,entry.y/height)
		entry.item.Size=UDim2.fromScale(entry.w,entry.h/height)
		-- Reveal order: each section title, then its cards.
		entry.item.LayoutOrder=index
	end
	self.contentHeight=height
	self.cardHolder.UIAspectRatioConstraint.AspectRatio=1/height
	self:Resize()
end

-- CanvasSize is relative to the grid's own height. Use the saved menu aspect and the
-- native body proportions so the last row remains reachable (no viewport reads).
function Browser:Resize()
	local height=self.contentHeight
	if not height then return end
	local aspect: UIAspectRatioConstraint?=nil
	local node: Instance?=self.root.Parent
	while node and not aspect do
		aspect=node:FindFirstChildWhichIsA("UIAspectRatioConstraint")
		node=node.Parent
	end
	if not aspect then return end
	local body=self.root.Parent::GuiObject
	local rootAspect=aspect.AspectRatio*body.Size.X.Scale/body.Size.Y.Scale*self.root.Size.X.Scale/self.root.Size.Y.Scale
	local gridAspect=rootAspect*self.grid.Size.X.Scale/self.grid.Size.Y.Scale
	local contentHeight=gridAspect*self.cardHolder.Size.X.Scale*height
	local margin=0.03
	local canvasHeight=contentHeight+margin
	self.grid.CanvasSize=UDim2.fromScale(0,canvasHeight)
	self.cardHolder.Position=UDim2.fromScale(0.02,0.005/canvasHeight)
end

function Browser:StopMotion()
	for thread in self.pending do task.cancel(thread) end
	table.clear(self.pending)
	if self.reveal then self.reveal.cancel();self.reveal=nil end
	for _,view in self.cards do
		Theme.Motion:Cancel(view.visual,"index-size")
		Theme.Motion:Cancel(view.visual,"index-enter")
		Theme.Motion:Cancel(view.preview,"index-lift")
		Theme.Motion:Cancel(view.rim,"index-highlight")
		Theme.Motion:StopGlow(view.root)
		view.visual.Size,view.visual.Position,view.rim.Transparency=CARD_SIZE,REST,view.rimRest or 0.2
		view.preview.Position=previewPosition(view.collected==true)
		local shine=view.visual:FindFirstChild("MotionShine")
		if shine then
			local gradient=shine:FindFirstChildWhichIsA("UIGradient")
			if gradient then Theme.Motion:Cancel(gradient,"shine") end
			shine.Visible=false
		end
	end
end

-- The sections and cards grow in one after another when the Index opens or a tab
-- changes (the shared Reveal; it settles at once under reduced motion).
function Browser:Reveal()
	self:StopMotion()
	self.reveal=Theme.Motion:Reveal(self.cardHolder,{limit=32,window=0.4,from=0.8})
end

-- A chicken found while the Index is open: a sweep of light, a glow in its rarity
-- colour around the slot (the card keeps its own stroke) that fades after a moment,
-- and the Shimmer cue.
function Browser:Discovered(view,color)
	Theme.Motion:Shine(view.visual)
	Theme.Motion:Glow(view.root,color,3)
	cue("Shimmer","RollReveal",nil,{volume=0.4,voiceKey="IndexDiscovery",cooldown=0.3})
	local thread
	thread=task.delay(DISCOVERY_GLOW_SECONDS,function()
		self.pending[thread]=nil
		if self.alive then Theme.Motion:StopGlow(view.root) end
	end)
	self.pending[thread]=true
end

function Browser:SyncVisibility()
	if not self.alive then return end
	local visible=self.root.Visible and self.parent.Visible and self.app.panel.Visible and self.app.page=="Index"
	if visible and not next(self.cards) then return end
	if visible==self.opened then return end
	self.opened=visible
	if visible then self:Resize();self:Reveal() else self:StopMotion() end
end

function Browser:Render(_force)
	local state=self.app.state
	if not state or not self.alive then return end
	self:BuildCards()
	-- The reference's teal-green Index bar on this page only.
	Theme.ApplyReferenceAccent(self.app.panelHeader,Theme.ReferenceGradients.Index)
	local tab=TABS[1]
	for _,entry in TABS do if entry.id==self.mutation then tab=entry end end
	local mutation=if tab.id=="Normal" then nil else tab.id
	-- Normal counts every chicken ever found; a mutation tab counts the chickens owned
	-- with that mutation.
	local found={}
	for _,pet in state.pets or {} do
		if self.cards[pet.species] and (mutation==nil or pet.mutation==mutation) then found[pet.species]=true end
	end
	if mutation==nil and type(state.discovered)=="table" then
		for _,species in ORDER do
			if state.discovered[species]==true then found[species]=true end
		end
	end
	-- Event-only chickens (Catalog .limited) appear only while their event runs or once
	-- found; chickens retired from the roll pool (.vaulted, October 22) only once found.
	-- Otherwise they are hidden and not counted. October 27 (WS4): the rule lives in
	-- IndexProgress, shared with the "NEW CHICKEN! … · Index 4/83" receipt.
	local eventOn=Config.Event and Config.Event.Enabled==true
	local everFound={}
	if type(state.discovered)=="table" then for species,value in state.discovered do everFound[species]=value==true end end
	for _,pet in state.pets or {} do everFound[pet.species]=true end
	local shown,total,collected={},0,0
	local sectionFound,sectionTotal={},{}
	for _,species in ORDER do
		local visible=IndexProgress.Visible(species,everFound[species]==true,eventOn)
		shown[species]=visible
		self.cards[species].root.Visible=visible
		if visible then
			total+=1
			local rarity=Catalog[species].rarity
			sectionTotal[rarity]=(sectionTotal[rarity] or 0)+1
			if found[species] then collected+=1;sectionFound[rarity]=(sectionFound[rarity] or 0)+1 end
		end
	end
	self:Layout(shown)
	self.app.panelTitle.Text="Index"
	self.tabTitle.Text=tab.name.." (x"..Theme.Number(tab.multiplier)..")"
	self.tabTitle.TextColor3=if mutation then tab.color:Lerp(WHITE,0.25) else WHITE
	self.count.Text=collected.." / "..total
	local fraction=if total>0 then collected/total else 0
	if self.opened and not self.switching then Theme.Motion:Progress(self.fill,fraction,0.35,BAR_GOLD:Lerp(WHITE,0.5))
	else Theme.Motion:Cancel(self.fill,"progress");self.fill.Size=UDim2.fromScale(fraction,1) end
	for rarity,section in self.sections do
		section.count.Text=(sectionFound[rarity] or 0).."/"..(sectionTotal[rarity] or 0)
	end
	local portraitScale=MenuLayout.Number(self.app.gui,"Index","PortraitScale",1.15,0.8,1.35)
	for _,species in ORDER do
		local view=self.cards[species]
		view.preview.Size=UDim2.fromScale(portraitScale*0.72,portraitScale*0.72)
		local isFound=found[species]==true
		local definition=Catalog[species]
		local rarityColor=Theme.Rarities[definition.rarity] or Theme.ActionColors.navigation
		local tint=if isFound and mutation then tab.color:Lerp(WHITE,0.35) elseif isFound then WHITE else BLACK
		view.preview.ImageColor3=tint
		if view.collected~=isFound then
			local newlyFound=view.collected==false and isFound and not self.switching
			view.collected=isFound
			view.root:SetAttribute("Collected",isFound)
			view.name.Text=if isFound then shortName(species) else "???"
			-- Found cards carry a thin rarity edge; silhouettes keep the shell's dark one.
			view.rim.Color=if isFound then rarityColor else BLACK
			view.rimRest=if isFound then 0.35 else Theme.Shell.CardStrokeTransparency
			view.rim.Transparency=view.rimRest
			view.preview.Position=previewPosition(isFound)
			if newlyFound and self.opened then self:Discovered(view,rarityColor) end
		end
	end
	self:SyncVisibility()
end

function Browser:Destroy()
	self.alive,self.opened=false,false
	self:StopMotion()
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if self.column then self.column:Destroy() end
	self.root:Destroy()
	table.clear(self.cards)
end

return Browser
