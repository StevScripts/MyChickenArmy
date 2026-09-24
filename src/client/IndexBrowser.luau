--!strict
-- Discovery remains server-owned. This browser only presents the approved roster.
local Theme=require(script.Parent.UITheme)
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local C=Theme.Colors
local Browser={}
Browser.__index=Browser

local GAP=14
local REST=UDim2.fromScale(0.5,0.5)
local WHITE=Color3.new(1,1,1)
local BLACK=Color3.new(0,0,0)

local function previewPosition(collected)
	return if collected then UDim2.fromOffset(9,8) else UDim2.fromOffset(9,9)
end

function Browser.new(app,parent)
	local self=setmetatable({
		app=app,parent=parent,cards={},connections={},pending={},alive=true,opened=false,columns=4,
	},Browser)
	local root=Theme.Frame(parent,"IndexBrowser",UDim2.new(1,-40,1,-132))
	root.Position,root.BackgroundTransparency,root.Visible=UDim2.fromOffset(20,114),1,false
	root:SetAttribute("OwnsPopupStyle",true)
	self.root=root

	-- One scrolling collection, no filters, selection controls, or information on missing birds.
	local grid=Instance.new("ScrollingFrame")
	grid.Name,grid.Position,grid.Size="IndexGrid",UDim2.new(),UDim2.fromScale(1,1)
	grid.BackgroundTransparency,grid.BorderSizePixel,grid.ScrollBarThickness=1,0,6
	grid.ScrollBarImageColor3=Theme.ActionColors.navigation
	grid.AutomaticCanvasSize,grid.CanvasSize=Enum.AutomaticSize.Y,UDim2.new()
	grid.ScrollingDirection,grid.VerticalScrollBarInset=Enum.ScrollingDirection.Y,Enum.ScrollBarInset.Always
	grid.ClipsDescendants,grid.Parent=true,root
	local padding=Instance.new("UIPadding")
	padding.PaddingLeft,padding.PaddingRight=UDim.new(0,10),UDim.new(0,14)
	padding.PaddingTop,padding.PaddingBottom=UDim.new(0,8),UDim.new(0,12)
	padding.Parent=grid
	local layout=Instance.new("UIGridLayout")
	layout.CellSize,layout.CellPadding=UDim2.fromOffset(248,248),UDim2.fromOffset(GAP,GAP)
	layout.SortOrder,layout.HorizontalAlignment=Enum.SortOrder.LayoutOrder,Enum.HorizontalAlignment.Center
	layout.Parent=grid
	self.grid,self.layout=grid,layout

	table.insert(self.connections,grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Resize() end))
	table.insert(self.connections,root:GetPropertyChangedSignal("Visible"):Connect(function() self:SyncVisibility() end))
	table.insert(self.connections,parent:GetPropertyChangedSignal("Visible"):Connect(function() self:SyncVisibility() end))
	self:Resize()
	return self
end

function Browser:BuildCards()
	if next(self.cards) then return end
	for i,species in Catalog.Order do
		local slot=Theme.Frame(self.grid,"Entry_"..i,UDim2.fromOffset(248,248))
		slot.LayoutOrder,slot.BackgroundTransparency=i,1
		local visual=Theme.Frame(slot,"Visual",UDim2.new(1,-6,1,-6),WHITE)
		visual.Position,visual.AnchorPoint,visual.ClipsDescendants=REST,Vector2.new(0.5,0.5),true
		Theme.Stroke(visual,Theme.Arcade.border,3)
		local scale=Theme.Motion:Scale(visual)
		local studs=Theme.Studs(visual,0.15,32,3)
		local inset=Theme.Frame(visual,"InnerRim",UDim2.new(1,-8,1,-8))
		inset.Position,inset.BackgroundTransparency,inset.ZIndex=UDim2.fromOffset(4,4),1,4
		local rim=Theme.Stroke(inset,C.white,1)
		rim.Transparency=0.42
		local preview=self.app:Preview(visual,{species=species,stars=1,level=1},
			UDim2.new(1,-18,1,-64),previewPosition(true))
		preview.ImageColor3,preview.ImageTransparency=BLACK,0

		-- Reserve a separate bottom strip so even two-line names never cross the chicken.
		local caption=Theme.Frame(visual,"Caption",UDim2.new(1,-10,0,48),WHITE)
		caption.Position,caption.AnchorPoint,caption.ZIndex=UDim2.new(0,5,1,-5),Vector2.new(0,1),4
		local gradient=Theme.Gradient(caption,Color3.fromRGB(14,20,24),Color3.fromRGB(5,9,12))
		gradient.Transparency=NumberSequence.new(0.22,0.06)
		local name=Theme.Label(caption,"Name","",24,C.white)
		name.Position,name.Size=UDim2.fromOffset(6,2),UDim2.new(1,-12,1,-4)
		name.TextXAlignment,name.TextYAlignment=Enum.TextXAlignment.Center,Enum.TextYAlignment.Center
		name.TextScaled=true
		local textLimit=Instance.new("UITextSizeConstraint")
		textLimit.MinTextSize,textLimit.MaxTextSize,textLimit.Parent=18,24,name
		caption.Visible=false
		local view={root=slot,visual=visual,scale=scale,preview=preview,caption=caption,
			name=name,rim=rim,studs=studs,collected=nil}
		self.cards[species]=view

		local function hover(active)
			if not self.alive or not self.opened then return end
			local moving=active and not Theme.Motion.reduced
			Theme.Motion:Tween(scale,"index-scale",{Scale=if moving then 1.018 else 1},0.15)
			Theme.Motion:Tween(preview,"index-lift",{
				Position=previewPosition(view.collected==true)+UDim2.fromOffset(0,if moving then -4 else 0),
			},0.17)
			Theme.Motion:Tween(rim,"index-highlight",{Transparency=if active then 0.1 else 0.42},0.15)
		end
		table.insert(self.connections,visual.MouseEnter:Connect(function() hover(true) end))
		table.insert(self.connections,visual.MouseLeave:Connect(function() hover(false) end))
	end
end

function Browser:Resize()
	if not self.alive then return end
	-- Cancel the outer popup's animated scale when measuring the logical grid.
	local motionScale=self.app.panelMotionScale and self.app.panelMotionScale.Scale or 1
	local scale=math.max((self.app.uiScale or 1)*motionScale,0.01)
	local width=math.floor(self.grid.AbsoluteSize.X/scale+0.5)-30
	if width<=0 then return end
	local columns=math.clamp(math.floor((width+GAP)/224),1,4)
	local cellWidth=math.max(1,math.floor((width-GAP*(columns-1))/columns))
	self.columns=columns
	self.layout.CellSize=UDim2.fromOffset(cellWidth,cellWidth)
	self.layout.FillDirectionMaxCells=columns
end

function Browser:StopMotion()
	for thread in self.pending do task.cancel(thread) end
	table.clear(self.pending)
	for _,view in self.cards do
		Theme.Motion:Cancel(view.scale,"index-scale")
		Theme.Motion:Cancel(view.visual,"index-enter")
		Theme.Motion:Cancel(view.preview,"index-lift")
		Theme.Motion:Cancel(view.rim,"index-highlight")
		view.scale.Scale,view.visual.Position,view.rim.Transparency=1,REST,0.42
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
	for _,species in Catalog.Order do
		local view=self.cards[species]
		local y=view.root.AbsolutePosition.Y
		if y+view.root.AbsoluteSize.Y>=top and y<bottom then
			view.scale.Scale,view.visual.Position=0.91,REST+UDim2.fromOffset(0,10)
			local thread
			thread=task.delay(math.min(order*0.035,0.24),function()
				self.pending[thread]=nil
				if not self.alive or not self.opened then return end
				Theme.Motion:Tween(view.scale,"index-scale",{Scale=1},0.28,Enum.EasingStyle.Back)
				Theme.Motion:Tween(view.visual,"index-enter",{Position=REST},0.24)
			end)
			self.pending[thread]=true
			order+=1
		end
	end
end

function Browser:SyncVisibility()
	if not self.alive then return end
	local visible=self.root.Visible and self.parent.Visible and self.app.page=="Index"
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
		for _,species in Catalog.Order do
			if state.discovered[species]==true then discovered[species]=true end
		end
	end
	for _,species in Catalog.Order do
		local view=self.cards[species]
		local collected=discovered[species]==true
		if view.collected~=collected then
			local newlyCollected=view.collected==false and collected
			view.collected=collected
			view.root:SetAttribute("Collected",collected)
			view.caption.Visible=collected
			view.name.Text=if collected then Catalog[species].name else ""
			view.preview.ImageColor3=if collected then WHITE else BLACK
			view.preview.Position=previewPosition(collected)
			view.preview.Size=if collected then UDim2.new(1,-18,1,-64) else UDim2.new(1,-18,1,-18)
			if collected then
				local color=Theme.Rarities[Catalog[species].rarity] or Theme.ActionColors.navigation
				Theme.Gradient(view.visual,color:Lerp(WHITE,0.27),color:Lerp(Theme.Arcade.border,0.36))
				view.rim.Color=color:Lerp(WHITE,0.65)
				view.studs.ImageTransparency=0.82
			else
				Theme.Gradient(view.visual,Color3.fromRGB(117,131,136),Color3.fromRGB(67,78,85))
				view.rim.Color=Color3.fromRGB(176,194,201)
				view.studs.ImageTransparency=0.91
			end
			if newlyCollected and self.opened and not Theme.Motion.reduced then
				view.scale.Scale=0.94
				Theme.Motion:Tween(view.scale,"index-scale",{Scale=1},0.32,Enum.EasingStyle.Back)
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
