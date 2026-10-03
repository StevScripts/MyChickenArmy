--!strict
-- A cutout over the real control, never a cloned or intercepted purchase button.
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.UITheme)
local GuideArrow = require(script.Parent.GuideArrow)
local Focus = {}
Focus.__index = Focus
local DIM_TRANSPARENCY = .8

function Focus.new(parent)
	local self = setmetatable({connections={}, targetConnections={}}, Focus)
	self.root = Theme.Container(parent, "CommanderSpotlight")
	self.root.ZIndex, self.root.Visible = 24, false
	self.window = Theme.Container(self.root, "ClearTarget")
	self.window.ZIndex, self.window.Active, self.window.Selectable = 2, false, false
	-- The transparent frame is the opening; its enormous OUTER stroke shades
	-- everything around it without extra mask frames or covering the real button.
	self.dim = Instance.new("UIStroke")
	self.dim.Name, self.dim.Color, self.dim.Transparency = "ViewportShade", Color3.new(0,0,0), 1
	self.dim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	self.dim.BorderStrokePosition = Enum.BorderStrokePosition.Outer
	self.dim.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
	self.dim.LineJoinMode, self.dim.Thickness, self.dim.ZIndex = Enum.LineJoinMode.Miter, 10000, 1
	self.dim.Parent = self.window
	self.stroke = Theme.Stroke(self.window, Theme.ReferenceColors.Army, 3)
	self.stroke.ZIndex = 2
	self.pointer = Theme.Container(self.root, "Arrow")
	self.pointer.AnchorPoint, self.pointer.Size, self.pointer.ZIndex = Vector2.new(.5,.5), UDim2.fromScale(.11,.145), 3
	Theme.Aspect(self.pointer, 1)
	self.arrow = GuideArrow(self.pointer, "Pointer")
	self.arrow.AnchorPoint, self.arrow.Position, self.arrow.Size = Vector2.new(.5,.5), UDim2.fromScale(.5,.5), UDim2.fromScale(1,1)
	for _,property in {"AbsolutePosition", "AbsoluteSize"} do
		table.insert(self.connections, self.root:GetPropertyChangedSignal(property):Connect(function() self:Layout() end))
	end
	table.insert(self.connections, self.pointer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:Layout() end))
	return self
end

function Focus:StopLoops()
	for _,key in {"pulse", "bounce"} do
		if self[key] then self[key]:Cancel(); self[key]:Destroy(); self[key]=nil end
	end
	self.stroke.Transparency = 0
	self.arrow.Position = UDim2.fromScale(.5,.5)
end

function Focus:Animate()
	self:StopLoops()
	if self.reduced or not self.root.Visible then return end
	self.pulse = TweenService:Create(self.stroke, TweenInfo.new(.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency=.6})
	self.arrow.Position = UDim2.fromScale(.40,.5)
	self.bounce = TweenService:Create(self.arrow, TweenInfo.new(.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Position=UDim2.fromScale(.56,.5)})
	self.pulse:Play(); self.bounce:Play()
end

function Focus:HideGeometry()
	self.root.Visible=false
	self:StopLoops()
end

function Focus:Layout()
	local target = self.target
	local size, origin = self.root.AbsoluteSize, self.root.AbsolutePosition
	if not target or not target.Parent or size.X<=0 or size.Y<=0 then self:HideGeometry(); return end
	local p, s = target.AbsolutePosition-origin, target.AbsoluteSize
	local x1,y1,x2,y2 = math.max(0,p.X),math.max(0,p.Y),math.min(size.X,p.X+s.X),math.min(size.Y,p.Y+s.Y)
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
	-- Pixel padding follows a measured control; menu layout itself remains native.
	x1,y1,x2,y2 = math.max(0,x1-8),math.max(0,y1-8),math.min(size.X,x2+8),math.min(size.Y,y2+8)
	local function rect(item,x,y,w,h)
		item.Position, item.Size = UDim2.fromScale(x/size.X,y/size.Y), UDim2.fromScale(w/size.X,h/size.Y)
	end
	self.dim.Thickness = math.max(10000, size.X+size.Y)
	rect(self.window,x1,y1,x2-x1,y2-y1)
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
	local entering = not self.root.Visible
	self.root.Visible = true
	if entering then self:Animate() end
end

function Focus:SetTarget(target, reduced)
	if target==self.target and reduced==self.reduced then if target then self:Layout() end; return end
	for _,connection in self.targetConnections do connection:Disconnect() end
	table.clear(self.targetConnections)
	self:StopLoops()
	self.target, self.reduced = target, reduced
	if not target then
		self.pointer.Visible, self.stroke.Enabled = false, false
		Theme.Motion:Tween(self.dim,"guide-dim",{Transparency=1},if reduced then 0 else .14,nil,nil,function()
			if not self.target then self.root.Visible=false end
		end)
		return
	end
	self.pointer.Visible,self.window.Visible = true,true
	self.stroke.Enabled = true
	local function layout() self:Layout() end
	for _,property in {"AbsolutePosition", "AbsoluteSize", "Visible"} do
		table.insert(self.targetConnections,target:GetPropertyChangedSignal(property):Connect(layout))
	end
	table.insert(self.targetConnections,target.AncestryChanged:Connect(layout))
	local ancestor=target.Parent
	while ancestor and not ancestor:IsA("ScreenGui") do
		if ancestor:IsA("GuiObject") then
			table.insert(self.targetConnections,ancestor:GetPropertyChangedSignal("Visible"):Connect(layout))
		end
		ancestor=ancestor.Parent
	end
	self:Layout(); self:Animate()
	Theme.Motion:Tween(self.dim,"guide-dim",{Transparency=DIM_TRANSPARENCY},if reduced then 0 else .18)
end

function Focus:Destroy()
	self:StopLoops()
	for _,connection in self.connections do connection:Disconnect() end
	for _,connection in self.targetConnections do connection:Disconnect() end
	self.root:Destroy()
end

return Focus
