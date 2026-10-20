--!strict
-- Discovery remains server-owned. This browser only presents the approved roster.
local Theme=require(script.Parent.UITheme)
local MenuLayout=require(script.Parent.MenuLayout)
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Config=require(Shared.Config)
local Portraits=require(script.Parent.ChickenPortraits)
local C=Theme.Colors
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

-- Every card now has a caption (name, or rarity and source), so portraits sit high.
local function previewPosition(_collected)
	return UDim2.fromScale(0.5,0.44)
end

function Browser.new(app,parent)
	local self=setmetatable({
		app=app,parent=parent,cards={},connections={},pending={},alive=true,opened=false,columns=4,
	},Browser)
	local root=Theme.Frame(parent,"IndexBrowser",UDim2.fromScale(0.98,0.96))
	root.Position,root.BackgroundTransparency,root.Visible=UDim2.fromScale(0.01,0.02),1,false
	root:SetAttribute("OwnsPopupStyle",true)
	self.root=root

	-- One scrolling collection, no filters, selection controls, or information on missing birds.
	local grid=Instance.new("ScrollingFrame")
	grid.Name,grid.Position,grid.Size="IndexGrid",UDim2.new(),UDim2.fromScale(1,1)
	grid.BackgroundTransparency,grid.BorderSizePixel,grid.ScrollBarThickness=1,0,0
	grid.ScrollBarImageColor3=Theme.ActionColors.navigation
	grid.AutomaticCanvasSize,grid.CanvasSize=Enum.AutomaticSize.None,UDim2.new()
	grid.ScrollingDirection,grid.VerticalScrollBarInset=Enum.ScrollingDirection.Y,Enum.ScrollBarInset.Always
	grid.ClipsDescendants,grid.Parent=true,root
	-- The canvas follows one width-constrained content frame. Grid row height
	-- therefore never depends on the growing scroll canvas.
	local rows=math.ceil(#ORDER/4)
	local contentHeight=rows*0.21+math.max(0,rows-1)*0.04
	local content=Theme.Frame(grid,"Cards",UDim2.fromScale(0.96,math.max(1,rows)))
	content.Position,content.BackgroundTransparency=UDim2.fromScale(0.02,0.03),1
	Theme.Aspect(content,1/contentHeight)
	local layout=Instance.new("UIGridLayout")
	-- GUI.FRAMES.Index uses proportional slots and gaps with square constraints.
	layout.CellSize,layout.CellPadding=UDim2.fromScale(0.21,0.21/contentHeight),UDim2.fromScale(0.04,0.04/contentHeight)
	layout.FillDirectionMaxCells=4
	layout.SortOrder,layout.HorizontalAlignment=Enum.SortOrder.LayoutOrder,Enum.HorizontalAlignment.Center
	layout.Parent=content
	self.grid,self.layout,self.cardHolder=grid,layout,content

	table.insert(self.connections,root:GetPropertyChangedSignal("Visible"):Connect(function() self:SyncVisibility() end))
	table.insert(self.connections,parent:GetPropertyChangedSignal("Visible"):Connect(function() self:SyncVisibility() end))
	table.insert(self.connections,app.panel:GetPropertyChangedSignal("Visible"):Connect(function() self:SyncVisibility() end))
	self:Resize()
	return self
end

function Browser:BuildCards()
	if next(self.cards) then return end
	for i,species in ORDER do
		local slot=Theme.Frame(self.cardHolder,"Entry_"..i,UDim2.fromScale(1,1))
		slot.LayoutOrder,slot.BackgroundTransparency=i,1
		Theme.Aspect(slot,1)
		local visual=Theme.Frame(slot,"Visual",CARD_SIZE,WHITE)
		visual.Position,visual.AnchorPoint,visual.ClipsDescendants=REST,Vector2.new(0.5,0.5),false
		Theme.Stroke(visual,Theme.Arcade.border,Theme.Border.Card)
		local studs=Theme.Studs(visual,0.15,32,3)
		local inset=Theme.Frame(visual,"InnerRim",UDim2.fromScale(0.968,0.968))
		inset.Position,inset.BackgroundTransparency,inset.ZIndex=UDim2.fromScale(0.016,0.016),1,4
		local rim=Theme.Stroke(inset,C.white,1)
		rim.Transparency=0.42
		local preview=self.app:Preview(visual,{species=portraitSpecies(species),stars=1,level=1},
			UDim2.fromScale(0.927,0.742),previewPosition(true))
		preview.ImageColor3,preview.ImageTransparency=BLACK,0
		preview.AnchorPoint=Vector2.new(0.5,0.5)
		preview.ZIndex=3

		-- Larger portraits may overlap the card a little; captions stay readable in front.
		local caption=Theme.Frame(visual,"Caption",UDim2.fromScale(0.96,0.194),WHITE)
		caption.Position,caption.AnchorPoint,caption.ZIndex=UDim2.fromScale(0.02,0.98),Vector2.new(0,1),4
		local gradient=Theme.Gradient(caption,Color3.fromRGB(14,20,24),Color3.fromRGB(5,9,12))
		gradient.Transparency=NumberSequence.new(0.22,0.06)
		local name=Theme.Label(caption,"Name","",24,C.white)
		name.Position,name.Size=UDim2.fromScale(0.025,0.042),UDim2.fromScale(0.95,0.916)
		name.TextXAlignment,name.TextYAlignment=Enum.TextXAlignment.Center,Enum.TextYAlignment.Center
		name.TextScaled=true
		caption.Visible=false
		-- October 15: every rollable chicken shows its zero-Luck odds in the corner;
		-- a Rebirth chicken shows its rank there instead (plan v2).
		local rebirthRank=Catalog[species].rebirthRank
		local oneIn=if rebirthRank then "Rebirth "..rebirthRank else Catalog.OneInText(species)
		if oneIn then
			local odds=Theme.Label(visual,"OneIn",oneIn,20,if rebirthRank then Theme.ReferenceColors.Army else Theme.Rarities[Catalog[species].rarity] or C.white)
			odds.AnchorPoint,odds.Position,odds.Size=Vector2.new(1,0),UDim2.fromScale(0.96,0.035),UDim2.fromScale(0.8,0.13)
			odds.TextXAlignment,odds.TextScaled,odds.ZIndex=Enum.TextXAlignment.Right,true,5
		end
		local view={root=slot,visual=visual,preview=preview,caption=caption,
			name=name,rim=rim,studs=studs,collected=nil}
		self.cards[species]=view

		local function hover(active)
			if not self.alive or not self.opened then return end
			local moving=active and not Theme.Motion.reduced
			Theme.Motion:Tween(visual,"index-size",{Size=if moving then UDim2.fromScale(0.994,0.994) else CARD_SIZE},0.15)
			Theme.Motion:Tween(preview,"index-lift",{
				Position=previewPosition(view.collected==true)+UDim2.fromScale(0,if moving then -0.016 else 0),
			},0.17)
			Theme.Motion:Tween(rim,"index-highlight",{Transparency=if active then 0.1 else 0.42},0.15)
		end
		table.insert(self.connections,visual.MouseEnter:Connect(function() hover(true) end))
		table.insert(self.connections,visual.MouseLeave:Connect(function() hover(false) end))
	end
end

function Browser:Resize()
	-- CanvasSize is relative to the grid's parent. Use the saved menu aspect and
	-- its native body proportions so the last constrained row remains reachable.
	local panel=self.root.Parent.Parent.Parent
	local aspect=panel:FindFirstChildWhichIsA("UIAspectRatioConstraint")
	if not aspect then return end
	local body=self.root.Parent
	local rootAspect=aspect.AspectRatio*body.Size.X.Scale/body.Size.Y.Scale*self.root.Size.X.Scale/self.root.Size.Y.Scale
	local height=rootAspect*self.grid.Size.X.Scale*self.cardHolder.Size.X.Scale/self.cardHolder.UIAspectRatioConstraint.AspectRatio
	local canvasHeight=height+0.05*self.grid.Size.Y.Scale
	self.grid.CanvasSize=UDim2.fromScale(0,canvasHeight)
	self.cardHolder.Position=UDim2.fromScale(0.02,0.03*self.grid.Size.Y.Scale/canvasHeight)
end

function Browser:StopMotion()
	for thread in self.pending do task.cancel(thread) end
	table.clear(self.pending)
	for _,view in self.cards do
		Theme.Motion:Cancel(view.visual,"index-size")
		Theme.Motion:Cancel(view.visual,"index-enter")
		Theme.Motion:Cancel(view.preview,"index-lift")
		Theme.Motion:Cancel(view.rim,"index-highlight")
		view.visual.Size,view.visual.Position,view.rim.Transparency=CARD_SIZE,REST,0.42
		view.preview.Position=previewPosition(view.collected==true)
		local shine=view.visual:FindFirstChild("MotionShine")
		if shine then
			local gradient=shine:FindFirstChildWhichIsA("UIGradient")
			if gradient then Theme.Motion:Cancel(gradient,"shine") end
			shine.Visible=false
		end
	end
end

function Browser:Reveal()
	self:StopMotion()
	if Theme.Motion.reduced then return end
	local top,bottom=self.grid.AbsolutePosition.Y,self.grid.AbsolutePosition.Y+self.grid.AbsoluteSize.Y
	local order=0
	for _,species in ORDER do
		local view=self.cards[species]
		local y=view.root.AbsolutePosition.Y
		if y+view.root.AbsoluteSize.Y>=top and y<bottom then
			view.visual.Size,view.visual.Position=UDim2.fromScale(0.888,0.888),REST+UDim2.fromScale(0,0.04)
			local thread
			thread=task.delay(math.min(order*0.035,0.24),function()
				self.pending[thread]=nil
				if not self.alive or not self.opened then return end
				Theme.Motion:Tween(view.visual,"index-size",{Size=CARD_SIZE},0.28,Enum.EasingStyle.Back)
				Theme.Motion:Tween(view.visual,"index-enter",{Position=REST},0.24)
			end)
			self.pending[thread]=true
			order+=1
		end
	end
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
	self:Resize()
	-- Apply the approved cyan header only to this page, without changing the shared palette.
	Theme.ApplyReferenceAccent(self.app.panelHeader,Theme.ReferenceGradients.Upgrades)
	local discovered={}
	for _,pet in state.pets or {} do
		if self.cards[pet.species] then discovered[pet.species]=true end
	end
	if type(state.discovered)=="table" then
		for _,species in ORDER do
			if state.discovered[species]==true then discovered[species]=true end
		end
	end
	-- Event-only chickens (Catalog .limited) appear only while their event runs
	-- or once owned/discovered; otherwise they are hidden and not counted.
	local eventOn=Config.Event and Config.Event.Enabled==true
	local found,total=0,0
	for _,species in ORDER do
		local shown=discovered[species]==true or not Catalog[species].limited or eventOn
		self.cards[species].root.Visible=shown
		if shown then total+=1 end
		if discovered[species] then found+=1 end
	end
	self.app.panelTitle.Text="Chicken Index · "..found.."/"..total
	for _,species in ORDER do
		local view=self.cards[species]
		local portraitScale=MenuLayout.Number(self.app.gui,"Index","PortraitScale",1.15,0.8,1.35)
		view.preview.Size=UDim2.fromScale(portraitScale,portraitScale)
		local collected=discovered[species]==true
		if view.collected~=collected then
			local newlyCollected=view.collected==false and collected
			view.collected=collected
			view.root:SetAttribute("Collected",collected)
			-- Undiscovered birds stay silhouettes but say how rare they are and
			-- where they come from (crate-only species have no normal roll weight).
			local definition=Catalog[species]
			local crateOnly=definition.crateExclusive==true or (definition.weight or 0)<=0
			view.caption.Visible=true
			view.name.RichText=not collected
			view.name.Text=if collected then definition.name
				else string.format('<font color="#%s">%s</font> · %s',(Theme.Rarities[definition.rarity] or WHITE):ToHex(),definition.rarity,
					if definition.hillExclusive then "Win the Hill "..Config.Hill.ChampionWins.." times" elseif definition.rebirthRank then "Reach Rebirth "..definition.rebirthRank elseif definition.limitedLabel then definition.limitedLabel elseif crateOnly then "Galaxy Crate only" else "Roll")
			view.preview.ImageColor3=if collected then WHITE else BLACK
			view.preview.Position=previewPosition(collected)
			if collected then
				local color=Theme.Rarities[Catalog[species].rarity] or Theme.ActionColors.navigation
				Theme.Gradient(view.visual,color:Lerp(WHITE,0.27),color:Lerp(Theme.Arcade.border,0.36))
				view.rim.Color=color:Lerp(WHITE,0.65)
				view.studs.ImageTransparency=0.82
			else
				-- Locked birds stay silhouettes; a faint rarity tint hints at what is left to find.
				local color=Theme.Rarities[Catalog[species].rarity] or Color3.fromRGB(117,131,136)
				Theme.Gradient(view.visual,Color3.fromRGB(117,131,136):Lerp(color,0.3),Color3.fromRGB(67,78,85):Lerp(color,0.18))
				view.rim.Color=Color3.fromRGB(176,194,201):Lerp(color,0.55)
				view.studs.ImageTransparency=0.91
			end
			if newlyCollected and self.opened and not Theme.Motion.reduced then
				view.visual.Size=UDim2.fromScale(0.917,0.917)
				Theme.Motion:Tween(view.visual,"index-size",{Size=CARD_SIZE},0.32,Enum.EasingStyle.Back)
				Theme.Motion:Shine(view.visual)
			end
		end
	end
	self:SyncVisibility()
end

function Browser:Destroy()
	self.alive,self.opened=false,false
	self:StopMotion()
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	self.root:Destroy()
	table.clear(self.cards)
end

return Browser
