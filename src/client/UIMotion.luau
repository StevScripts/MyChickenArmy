--!strict
-- Client presentation only. Timings never gate a request or manufacture a reward.
local TweenService=game:GetService("TweenService")
local Motion={}
Motion.__index=Motion

function Motion.new()
	return setmetatable({
		reduced=false,
		tracks={},
		restingSizes=setmetatable({}, {__mode="k"}),
		restingPositions=setmetatable({}, {__mode="k"}),
		hiding=setmetatable({}, {__mode="k"}),
		bindings=setmetatable({}, {__mode = "k"}),
		spins=setmetatable({}, {__mode = "k"}),
		panelSerial=0,
	},Motion)
end

function Motion:DisconnectButtonBindings(button)
	local connections = self.bindings[button]
	if not connections then return end
	for _,connection in connections do
		if connection.Connected then connection:Disconnect() end
	end
	self.bindings[button] = nil
end

function Motion:Cancel(object,channel)
	local channels=self.tracks[object]
	local track=channels and channels[channel]
	if not track then return end
	channels[channel]=nil
	if not next(channels) then self.tracks[object]=nil end
	track.completed:Disconnect();track.destroying:Disconnect()
	track.tween:Cancel();track.tween:Destroy()
end

function Motion:Tween(object,channel,goals,seconds,style,direction,complete,repeats,reverses)
	self:Cancel(object,channel)
	if self.reduced or seconds<=0 then
		for property,value in goals do object[property]=value end
		if complete then complete() end
		return
	end
	local tween=TweenService:Create(object,TweenInfo.new(seconds,style or Enum.EasingStyle.Quad,direction or Enum.EasingDirection.Out,repeats or 0,reverses==true),goals)
	local track={tween=tween,goals=goals,finish=complete}
	self.tracks[object]=self.tracks[object] or {}
	self.tracks[object][channel]=track
	track.destroying=object.Destroying:Connect(function() self:Cancel(object,channel) end)
	track.completed=tween.Completed:Connect(function(state)
		self:Cancel(object,channel)
		if state==Enum.PlaybackState.Completed and complete then complete() end
	end)
	tween:Play()
end

local function multiplied(size,amount)
	return UDim2.new(size.X.Scale*amount,size.X.Offset*amount,size.Y.Scale*amount,size.Y.Offset*amount)
end

function Motion:Pop(item,amount)
	if not item or not item.Parent then return end
	local size=self.restingSizes[item] or item.Size
	self.restingSizes[item]=size
	self:Cancel(item,"press")
	self:Cancel(item,"pop")
	item.Size=if self.reduced then size else multiplied(size,amount or 1.08)
	self:Tween(item,"pop",{Size=size},0.24,Enum.EasingStyle.Back)
end

function Motion:Pulse(item,amount)
	self:Pop(item,amount or 1.06)
end

-- A UIScale child animates without changing Size, so layout children, aspect-
-- constrained items and Billboard/SurfaceGui art keep their geometry.
function Motion:ScaleOf(item)
	-- Two UIScales on one object misbehave, so share an authored one if present.
	local scale=item:FindFirstChildWhichIsA("UIScale")
	if not scale then
		scale=Instance.new("UIScale")
		scale.Name="MotionScale"
		scale.Parent=item
	end
	return scale
end

-- UIScale grows from AnchorPoint. Re-anchor a freely placed item at its centre
-- without moving it. Only for items whose Position is not rewritten later.
function Motion:Center(item)
	local parent=item.Parent
	if item.AnchorPoint==Vector2.new(0.5,0.5) or (parent and parent:FindFirstChildWhichIsA("UIGridStyleLayout")) then return end
	if item:FindFirstChildWhichIsA("UIAspectRatioConstraint") or item:FindFirstChildWhichIsA("UISizeConstraint") then return end
	local anchor,size=item.AnchorPoint,item.Size
	local dx,dy=0.5-anchor.X,0.5-anchor.Y
	item.Position+=UDim2.new(size.X.Scale*dx,size.X.Offset*dx,size.Y.Scale*dy,size.Y.Offset*dy)
	item.AnchorPoint=Vector2.new(0.5,0.5)
end

-- Pop through UIScale: from >1 bounces down, from <1 grows in.
function Motion:PopScale(item,from,seconds)
	if not item or not item.Parent then return end
	local scale=self:ScaleOf(item)
	self:Cancel(scale,"press")
	scale.Scale=if self.reduced then 1 else (from or 1.08)
	self:Tween(scale,"pop",{Scale=1},seconds or 0.24,Enum.EasingStyle.Back)
end

-- Short horizontal "no" wiggle that always settles on the resting Position.
function Motion:Shake(item,pixels)
	if self.reduced or not item or not item.Parent then return end
	local rest=self.restingPositions[item] or item.Position
	self.restingPositions[item]=rest
	local offset=UDim2.fromOffset(pixels or 6,0)
	item.Position=rest+offset
	self:Tween(item,"shake",{Position=rest-offset},0.045,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,function()
		self:Tween(item,"shake",{Position=rest},0.05,nil,nil,function() self.restingPositions[item]=nil end)
	end,2,true)
	local track=self.tracks[item] and self.tracks[item].shake
	if track then track.goals={Position=rest} end
end

-- Endless back-and-forth. Cancel, StopLoop and reduced motion settle on `rest`.
function Motion:Loop(object,channel,goals,rest,seconds,style)
	self:Cancel(object,channel)
	for property,value in rest do object[property]=value end
	if self.reduced then return end
	self:Tween(object,channel,goals,seconds,style or Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,nil,-1,true)
	local track=self.tracks[object] and self.tracks[object][channel]
	if track then track.goals=rest end
end

function Motion:StopLoop(object,channel)
	local track=self.tracks[object] and self.tracks[object][channel]
	local rest=track and track.goals
	self:Cancel(object,channel)
	if rest then for property,value in rest do object[property]=value end end
end

-- Gentle "ready" breathing through UIScale; it never fights button presses.
function Motion:Breathe(item,amount,seconds)
	self:Loop(self:ScaleOf(item),"breathe",{Scale=amount or 1.06},{Scale=1},seconds or 0.6)
end

function Motion:StopBreathe(item)
	local scale=item:FindFirstChildWhichIsA("UIScale")
	if scale then self:StopLoop(scale,"breathe") end
end

-- Visible toggle with a grow-in and a quick shrink-out.
function Motion:Appear(item,shown,from)
	if not item then return end
	local scale=self:ScaleOf(item)
	if shown then
		if item.Visible and not self.hiding[item] then return end
		self.hiding[item]=nil
		item.Visible=true
		self:Cancel(scale,"press")
		scale.Scale=if self.reduced then 1 else (from or 0.6)
		self:Tween(scale,"pop",{Scale=1},0.26,Enum.EasingStyle.Back)
	else
		if not item.Visible or self.hiding[item] then return end
		if self.reduced then
			self:Cancel(scale,"pop")
			item.Visible,scale.Scale=false,1
			return
		end
		self.hiding[item]=true
		self:Tween(scale,"pop",{Scale=0.6},0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.In,function()
			self.hiding[item]=nil
			item.Visible,scale.Scale=false,1
		end)
	end
end

function Motion:Shine(face)
	if self.reduced then return end
	local shine=face:FindFirstChild("MotionShine")
	if not shine then
		shine=Instance.new("Frame")
		shine.Name,shine.Size,shine.BackgroundColor3,shine.BorderSizePixel,shine.ZIndex="MotionShine",UDim2.fromScale(1,1),Color3.new(1,1,1),0,4
		local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,0);corner.Parent=shine
		local gradient=Instance.new("UIGradient")
		gradient.Rotation=-20
		gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.38,1),NumberSequenceKeypoint.new(0.5,0.66),NumberSequenceKeypoint.new(0.62,1),NumberSequenceKeypoint.new(1,1)})
		gradient.Parent=shine;shine.Parent=face
	end
	-- Authored world/shop faces can sit above the default UITheme layers.
	shine.ZIndex=face.ZIndex+2
	shine.Visible=true
	local gradient=shine.UIGradient
	self:Cancel(gradient,"shine");gradient.Offset=Vector2.new(-1,0)
	self:Tween(gradient,"shine",{Offset=Vector2.new(1,0)},0.42,nil,nil,function() shine.Visible=false end)
end

function Motion:BindButton(button,visual,face,rim)
	self:DisconnectButtonBindings(button)
	local connections={}
	self.bindings[button]=connections
	-- `visual` may be a UIScale for buttons that have no centred Visual frame.
	local scaled=visual:IsA("UIScale")
	local restingSize=if scaled then nil else visual.Size
	if not scaled then self.restingSizes[visual]=restingSize end
	local function goal(amount)
		return if scaled then {Scale=amount} else {Size=multiplied(restingSize,amount)}
	end
	local hovering,focused,pressed=false,false,false
	local function update()
		local hot=button.Active and (hovering or focused)
		local target=if self.reduced then 1 elseif pressed and button.Active then 0.955 elseif hot then 1.03 else 1
		self:Cancel(visual,"pop")
		self:Tween(visual,"press",goal(target),if pressed then 0.065 else 0.13)
		if rim then self:Tween(rim,"highlight",{Transparency=if button.Active then (if hot then 0.05 else 0.46) else 0.66},0.12) end
	end
	local function connect(fn,callback)
		if typeof(callback) ~= "function" then return end
		local connection = fn(callback)
		table.insert(connections, connection)
	end
	connect(function(cb) return button.MouseEnter:Connect(cb) end, function()
		hovering=true
		update()
		if button.Active and face then self:Shine(face) end
	end)
	connect(function(cb) return button.MouseLeave:Connect(cb) end, function()
		hovering=false
		pressed=false
		update()
	end)
	connect(function(cb) return button.SelectionGained:Connect(cb) end, function()
		focused=true
		update()
	end)
	connect(function(cb) return button.SelectionLost:Connect(cb) end, function()
		focused=false
		pressed=false
		update()
	end)
	connect(function(cb) return button.MouseButton1Down:Connect(cb) end, function()
		if not button.Active then
			-- A locked control answers with a small "no" instead of silence.
			if button:GetAttribute("RejectShake")~=false then self:Shake(if scaled then button else visual,4) end
			return
		end
		pressed=true
		update()
	end)
	connect(function(cb) return button.MouseButton1Up:Connect(cb) end, function()
		if not button.Active then return end
		pressed=false
		update()
	end)
	connect(function(cb) return button:GetPropertyChangedSignal("Active"):Connect(cb) end, function()
		if not button.Active then
			pressed=false
			hovering=false
			focused=false
		end
		update()
	end)
	connect(function(cb) return button.Activated:Connect(cb) end, function()
		if not button.Active then return end
		pressed=false
		self:Cancel(visual,"press")
		local amount=if self.reduced then 1 else 0.955
		if scaled then visual.Scale=amount else visual.Size=multiplied(restingSize,amount) end
		update()
		-- Same frame and voice key as hand-written Click calls, so it never doubles.
		if self.sound and button:GetAttribute("ClickSound")~=false then self.sound("Click") end
	end)
	connect(function(cb) return button.Destroying:Connect(cb) end, function()
		self:DisconnectButtonBindings(button)
	end)
end

function Motion:OpenPanel(panel,backdrop,switching)
	self.panelSerial+=1
	self:Cancel(panel,"position")
	local position=panel.Position
	panel:SetAttribute("RestingPosition",position)
	panel.Visible,backdrop.Visible=true,true
	panel.Position=if self.reduced then position else position+UDim2.fromScale(0,0.02)
	backdrop.BackgroundTransparency=1
	self:Tween(panel,"position",{Position=position},if switching then 0.16 else 0.2)
	local scale=self:ScaleOf(panel)
	scale.Scale=if self.reduced then 1 elseif switching then 0.985 else 0.94
	self:Tween(scale,"open",{Scale=1},if switching then 0.18 else 0.26,Enum.EasingStyle.Back)
end

function Motion:ClosePanel(panel,backdrop,complete)
	self.panelSerial+=1
	local serial=self.panelSerial
	self:StopSpins()
	local position=panel:GetAttribute("RestingPosition") or panel.Position
	self:Tween(backdrop,"fade",{BackgroundTransparency=1},0.12)
	local scale=self:ScaleOf(panel)
	self:Tween(scale,"open",{Scale=0.96},0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	self:Tween(panel,"position",{Position=position+UDim2.fromScale(0,0.02)},0.12,nil,nil,function()
		if serial~=self.panelSerial then return end
		panel.Visible,backdrop.Visible=false,false
		panel.Position=position
		self:Cancel(scale,"open")
		scale.Scale=1
		complete()
	end)
end

function Motion:Toast(frame,show,target,quiet)
	target=target or (if show then UDim2.fromScale(0.5,0.82) else frame.Position)
	self:Cancel(frame,"toast")
	self:Cancel(frame,"toast-fade")
	if show then
		local entering=not frame.Visible
		frame.Visible=true
		frame.Position=if entering and not self.reduced then target+UDim2.fromScale(0,0.01) else frame.Position
		if frame:IsA("CanvasGroup") then
			if not quiet then frame.GroupTransparency=1 end
			self:Tween(frame,"toast-fade",{GroupTransparency=0},0.14)
		end
		self:Tween(frame,"toast",{Position=target},0.18)
	else
		if frame:IsA("CanvasGroup") then
			self:Tween(frame,"toast-fade",{GroupTransparency=1},0.16,nil,nil,function() frame.Visible=false end)
		else frame.Visible=false end
	end
end

function Motion:Count(label,value,format,seconds)
	local amount=label:FindFirstChild("DisplayedAmount")
	if not amount then
		amount=Instance.new("NumberValue");amount.Name="DisplayedAmount";amount.Value=value;amount.Parent=label
		amount:SetAttribute("Target",value)
		amount.Changed:Connect(function(v) label.Text=format(v) end)
		label.Text=format(value)
		return
	end
	local previous=amount:GetAttribute("Target")
	if previous==value then return end
	amount:SetAttribute("Target",value)
	-- Spend immediately; smooth only confirmed gains. Never count beyond server state.
	self:Tween(amount,"count",{Value=value},if value<(previous or amount.Value) then 0 else seconds or 0.18)
end

function Motion:Spin(image)
	if self.reduced then return end
	self.spins[image]=true
	self:Tween(image,"spin",{Rotation=image.Rotation+360},28,Enum.EasingStyle.Linear,nil,nil,-1)
end

function Motion:StopSpins()
	for image in self.spins do self:Cancel(image,"spin") end
	table.clear(self.spins)
end

function Motion:Burst(parent,position,color)
	if self.reduced then return end
	local existing=parent:FindFirstChild("RewardSparkles")
	if existing then existing:Destroy() end
	local holder=Instance.new("Frame")
	holder.Name,holder.Size,holder.Position,holder.BackgroundTransparency,holder.ZIndex="RewardSparkles",UDim2.fromScale(1,1),UDim2.new(),1,25
	holder.Parent=parent
	for i=1,10 do
		local particle=Instance.new("Frame")
		particle.Size,particle.Position,particle.AnchorPoint=UDim2.fromScale(0.01+(i%3)*0.003,0.01+(i%3)*0.003),position,Vector2.new(0.5,0.5)
		particle.BackgroundColor3,particle.BorderSizePixel,particle.Rotation,particle.Parent=color,0,i*33,holder
		local angle=math.pi*2*i/10
		self:Tween(particle,"burst",{Position=position+UDim2.fromScale(math.cos(angle)*(0.12+i*0.006),math.sin(angle)*0.12-0.04),Rotation=i*33+130,BackgroundTransparency=1,Size=UDim2.fromScale(0.003,0.003)},0.55)
	end
	task.delay(0.6,function() holder:Destroy() end)
end

function Motion:SetReduced(value)
	self.reduced=value
	if not value then return end
	self:StopSpins()
	local pending={}
	for object,channels in self.tracks do for channel,track in channels do table.insert(pending,{object=object,channel=channel,goals=track.goals,finish=track.finish}) end end
	for _,entry in pending do
		self:Cancel(entry.object,entry.channel)
		if entry.object.Parent then
			for property,target in entry.goals do entry.object[property]=target end
			if entry.finish then entry.finish() end
		end
	end
end

function Motion:Reset()
	self:StopSpins()
	local pending={}
	for object,channels in self.tracks do for channel in channels do table.insert(pending,{object,channel}) end end
	for _,pair in pending do self:Cancel(pair[1],pair[2]) end
	self.panelSerial+=1
end

return Motion
