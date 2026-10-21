--!strict
-- A pointer beside the real GUI control; never intercepts input.
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.UITheme)
local GuideArrow = require(script.Parent.GuideArrow)
local Focus = {}
Focus.__index = Focus
local POINTER_SIZE = UDim2.fromScale(.11,.145)
-- October 21 (Stevin, like the Drop a Fruit tutorial): menu lessons dim the screen
-- around the control and ring it in gold. Never intercepts input (Active=false).
-- Later October 21 (Stevin: "the black screen"): as dark as the recording's.
local SHADE_TRANSPARENCY, HOLE_PADDING = .3, 6
local RING_COLOR = Color3.fromRGB(255,214,64)

-- An optional fixed spot for the arrow, measured in the target's own size: `offset`
-- from the target's centre to the arrow's centre, and `size` (a share of the target's
-- height). The arrow turns to point at the target. Without it, the arrow takes the
-- side of the target with the most room.
export type Placement = {offset: Vector2, size: number}

local function samePlacement(a: Placement?, b: Placement?): boolean
	if a == nil or b == nil then return a == b end
	return a.offset == b.offset and a.size == b.size
end

function Focus.new(parent)
	local self = setmetatable({connections={}, targetConnections={}, placement=nil :: Placement?}, Focus)
	self.root = Theme.Container(parent, "CommanderPointer")
	self.root.ZIndex, self.root.Visible = 24, false
	self.pointer = Theme.Container(self.root, "Arrow")
	self.pointer.AnchorPoint, self.pointer.Size, self.pointer.ZIndex = Vector2.new(.5,.5), POINTER_SIZE, 3
	Theme.Aspect(self.pointer, 1)
	self.shade = {}
	for _, name in {"ShadeTop", "ShadeBottom", "ShadeLeft", "ShadeRight"} do
		local part = Instance.new("Frame")
		part.Name, part.BackgroundColor3, part.BackgroundTransparency, part.BorderSizePixel = name, Color3.new(0,0,0), 1, 0
		part.Active, part.ZIndex, part.Visible = false, 1, false
		part.Parent = self.root
		table.insert(self.shade, part)
	end
	self.ring = Instance.new("Frame")
	self.ring.Name, self.ring.BackgroundTransparency, self.ring.Active, self.ring.ZIndex, self.ring.Visible = "Ring", 1, false, 2, false
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.ApplyStrokeMode = RING_COLOR, 3, Enum.ApplyStrokeMode.Border
	stroke.Parent = self.ring
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0,8); corner.Parent = self.ring
	self.ring.Parent = self.root
	self.arrow = GuideArrow(self.pointer, "Pointer")
	self.arrow.AnchorPoint, self.arrow.Position, self.arrow.Size = Vector2.new(.5,.5), UDim2.fromScale(.5,.5), UDim2.fromScale(1,1)
	for _,property in {"AbsolutePosition", "AbsoluteSize"} do
		table.insert(self.connections, self.root:GetPropertyChangedSignal(property):Connect(function() self:Layout() end))
	end
	table.insert(self.connections, self.pointer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Layout() end))
	return self
end

function Focus:StopLoops()
	if self.bounce then self.bounce:Cancel(); self.bounce:Destroy(); self.bounce=nil end
	self.arrow.Position = UDim2.fromScale(.5,.5)
end

function Focus:Animate()
	self:StopLoops()
	if self.reduced or not self.root.Visible then return end
	self.arrow.Position = UDim2.fromScale(.40,.5)
	self.bounce = TweenService:Create(self.arrow, TweenInfo.new(.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Position=UDim2.fromScale(.56,.5)})
	self.bounce:Play()
end

function Focus:HideGeometry()
	self.root.Visible=false
	self:StopLoops()
	self:Shade(nil)
end

-- The dark screen around the hole (x1, y1, x2, y2 in root pixels), or nothing.
function Focus:Shade(hole: {number}?)
	local show = hole ~= nil and self.dim == true
	self.ring.Visible = show
	for _, part in self.shade do part.Visible = show end
	if not hole or not show then self.shaded = false; return end
	local size = self.root.AbsoluteSize
	-- Edges snap to whole screen pixels (the root may sit at a fractional position), so
	-- neighbouring panels share one exact edge: no 1 px seam across the screen.
	local origin: Vector2 = self.root.AbsolutePosition
	local function snapX(x: number): number return math.round(origin.X + x) - origin.X end
	local function snapY(y: number): number return math.round(origin.Y + y) - origin.Y end
	local x1, y1 = snapX(math.max(0, hole[1]-HOLE_PADDING)), snapY(math.max(0, hole[2]-HOLE_PADDING))
	local x2, y2 = snapX(math.min(size.X, hole[3]+HOLE_PADDING)), snapY(math.min(size.Y, hole[4]+HOLE_PADDING))
	local top, bottom, left, right = self.shade[1], self.shade[2], self.shade[3], self.shade[4]
	top.Position, top.Size = UDim2.fromOffset(0,0), UDim2.new(1,0,0,y1)
	bottom.Position, bottom.Size = UDim2.fromOffset(0,y2), UDim2.new(1,0,0,math.max(0,size.Y-y2))
	left.Position, left.Size = UDim2.fromOffset(0,y1), UDim2.fromOffset(x1,y2-y1)
	right.Position, right.Size = UDim2.fromOffset(x2,y1), UDim2.fromOffset(math.max(0,size.X-x2),y2-y1)
	self.ring.Position, self.ring.Size = UDim2.fromOffset(x1,y1), UDim2.fromOffset(x2-x1,y2-y1)
	if self.shaded then return end
	self.shaded = true
	for _, part in self.shade do part.BackgroundTransparency = if self.reduced then SHADE_TRANSPARENCY else 1 end
	if not self.reduced then
		for _, part in self.shade do
			TweenService:Create(part, TweenInfo.new(.2), {BackgroundTransparency=SHADE_TRANSPARENCY}):Play()
		end
	end
end

function Focus:Layout()
	local target = self.target
	local size, origin = self.root.AbsoluteSize, self.root.AbsolutePosition
	if not target or not target.Parent or size.X<=0 or size.Y<=0 then self:HideGeometry(); return end
	-- A button whose hit area was grown (Theme.PadHit) is ringed around its art.
	local art=if target:GetAttribute("HitPadded") then target:FindFirstChild("Visual") else nil
	local box: GuiObject=if art and art:IsA("GuiObject") then art else target
	local p,s=box.AbsolutePosition-origin,box.AbsoluteSize
	local x1,y1,x2,y2=math.max(0,p.X),math.max(0,p.Y),math.min(size.X,p.X+s.X),math.min(size.Y,p.Y+s.Y)
	local ancestor = target
	while ancestor and not ancestor:IsA("ScreenGui") do
		if ancestor:IsA("GuiObject") then
			if not ancestor.Visible then self:HideGeometry(); return end
			if ancestor~=target and ancestor.ClipsDescendants then
				local at, extent = ancestor.AbsolutePosition-origin, ancestor.AbsoluteSize
				x1,y1,x2,y2 = math.max(x1,at.X),math.max(y1,at.Y),math.min(x2,at.X+extent.X),math.min(y2,at.Y+extent.Y)
			end
		end
		ancestor = ancestor.Parent
	end
	if x2-x1<2 or y2-y1<2 then self:HideGeometry(); return end
	self:Shade({x1,y1,x2,y2})
	local placement = self.placement
	if placement then
		-- Sized from the target, so it follows a zoomed map; the arrow art points right.
		local length = math.max(8, placement.size*s.Y)
		local center = p+s/2
		local at = center+Vector2.new(placement.offset.X*s.X, placement.offset.Y*s.Y)
		local toward = center-at
		self.pointer.Size = UDim2.fromOffset(length,length)
		self.pointer.Position = UDim2.fromScale(at.X/size.X,at.Y/size.Y)
		self.pointer.Rotation = math.deg(math.atan2(toward.Y,toward.X))
	else
		-- Pixel padding follows a measured control; menu layout itself remains native.
		x1,y1,x2,y2 = math.max(0,x1-8),math.max(0,y1-8),math.min(size.X,x2+8),math.min(size.Y,y2+8)
		self.pointer.Size = POINTER_SIZE
		local half = math.max(self.pointer.AbsoluteSize.X,self.pointer.AbsoluteSize.Y)*.6
		local cx,cy,rotation = (x1+x2)/2,(y1+y2)/2,0
		local spaces = {x1,size.X-x2,y1,size.Y-y2}
		local side = 1
		for i=2,4 do if spaces[i]>spaces[side] then side=i end end
		if side==1 then cx,rotation=x1-half-10,0
		elseif side==2 then cx,rotation=x2+half+10,180
		elseif side==3 then cy,rotation=y1-half-10,90
		else cy,rotation=y2+half+10,-90 end
		self.pointer.Position = UDim2.fromScale(math.clamp(cx,half,size.X-half)/size.X,math.clamp(cy,half,size.Y-half)/size.Y)
		self.pointer.Rotation = rotation
	end
	local entering = not self.root.Visible
	self.root.Visible = true
	if entering then self:Animate() end
end

-- dim: shade the screen around the target (menu lessons only, never Next goals).
function Focus:SetTarget(target, reduced, placement: Placement?, dim: boolean?)
	if (dim == true) ~= (self.dim == true) then
		self.dim = dim == true
		if target and target==self.target then self.shaded = false; self:Layout() end
	end
	if target==self.target and reduced==self.reduced and samePlacement(placement,self.placement) then
		if target then self:Layout() end
		return
	end
	self.placement = placement
	if target==self.target and reduced==self.reduced then self:Layout(); return end
	for _,connection in self.targetConnections do connection:Disconnect() end
	table.clear(self.targetConnections)
	self:StopLoops()
	self.target, self.reduced = target, reduced
	if not target then
		self:HideGeometry()
		return
	end
	local function layout() self:Layout() end
	table.insert(self.targetConnections,target.AncestryChanged:Connect(layout))
	for _,property in {"AbsolutePosition", "AbsoluteSize", "Visible"} do
		table.insert(self.targetConnections,target:GetPropertyChangedSignal(property):Connect(layout))
	end
	local ancestor=target.Parent
	while ancestor and not ancestor:IsA("ScreenGui") do
		if ancestor:IsA("GuiObject") then
			table.insert(self.targetConnections,ancestor:GetPropertyChangedSignal("Visible"):Connect(layout))
		end
		ancestor=ancestor.Parent
	end
	self:Layout(); self:Animate()
end

function Focus:Destroy()
	self:StopLoops()
	for _,connection in self.connections do connection:Disconnect() end
	for _,connection in self.targetConnections do connection:Disconnect() end
	self.root:Destroy()
end

return Focus
