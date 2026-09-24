--!strict
-- Client presentation only. Timings never gate a request or manufacture a reward.
local TweenService=game:GetService("TweenService")
local Motion={}
Motion.__index=Motion

function Motion.new()
	return setmetatable({
		reduced=false,
		tracks={},
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

function Motion:Tween(object,channel,goals,seconds,style,direction,complete,repeats)
	self:Cancel(object,channel)
	if self.reduced or seconds<=0 then
		for property,value in goals do object[property]=value end
		if complete then complete() end
		return
	end
	local tween=TweenService:Create(object,TweenInfo.new(seconds,style or Enum.EasingStyle.Quad,direction or Enum.EasingDirection.Out,repeats or 0),goals)
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

function Motion:Scale(item)
	local scale=item:FindFirstChild("MotionScale")
	if not scale then scale=Instance.new("UIScale");scale.Name="MotionScale";scale.Parent=item end
	return scale
end

function Motion:Pop(item,amount)
	if not item or not item.Parent then return end
	local scale=self:Scale(item)
	self:Cancel(scale,"scale")
	scale.Scale=if self.reduced then 1 else amount or 1.08
	self:Tween(scale,"scale",{Scale=1},0.24,Enum.EasingStyle.Back)
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
	shine.Visible=true
	local gradient=shine.UIGradient
	self:Cancel(gradient,"shine");gradient.Offset=Vector2.new(-1,0)
	self:Tween(gradient,"shine",{Offset=Vector2.new(1,0)},0.42,nil,nil,function() shine.Visible=false end)
end

function Motion:BindButton(button,visual,face,rim)
	self:DisconnectButtonBindings(button)
	local connections={}
	self.bindings[button]=connections
	local scale=self:Scale(visual)
	local hovering,focused,pressed=false,false,false
	local function update()
		local hot=button.Active and (hovering or focused)
		local target=if self.reduced then 1 elseif pressed and button.Active then 0.955 elseif hot then 1.03 else 1
		self:Tween(scale,"scale",{Scale=target},if pressed then 0.065 else 0.13)
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
		if not button.Active then return end
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
		self:Cancel(scale,"scale")
		scale.Scale=if self.reduced then 1 else 0.955
		update()
	end)
	connect(function(cb) return button.Destroying:Connect(cb) end, function()
		self:DisconnectButtonBindings(button)
	end)
end

function Motion:OpenPanel(panel,backdrop,switching)
	self.panelSerial+=1
	local scale=self:Scale(panel)
	self:Cancel(scale,"scale");self:Cancel(panel,"position")
	panel.Visible,backdrop.Visible=true,true
	scale.Scale=if self.reduced then 1 elseif switching then 0.975 else 0.92
	panel.Position=UDim2.new(0.5,0,0.5,if self.reduced then 0 else 14)
	if not switching then backdrop.BackgroundTransparency=1 end
	self:Tween(scale,"scale",{Scale=1},if switching then 0.16 else 0.24,Enum.EasingStyle.Back)
	self:Tween(panel,"position",{Position=UDim2.fromScale(0.5,0.5)},0.2)
	self:Tween(backdrop,"fade",{BackgroundTransparency=0.44},0.15)
end

function Motion:ClosePanel(panel,backdrop,complete)
	self.panelSerial+=1
	local serial=self.panelSerial
	self:StopSpins()
	self:Tween(self:Scale(panel),"scale",{Scale=0.96},0.12,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	self:Tween(backdrop,"fade",{BackgroundTransparency=1},0.12)
	self:Tween(panel,"position",{Position=UDim2.new(0.5,0,0.5,12)},0.12,nil,nil,function()
		if serial~=self.panelSerial then return end
		panel.Visible,backdrop.Visible=false,false
		self:Scale(panel).Scale=1
		panel.Position=UDim2.fromScale(0.5,0.5)
		complete()
	end)
end

function Motion:Toast(frame,show,target)
	target=target or (if show then UDim2.new(0.5,0,1,-140) else frame.Position)
	self:Cancel(frame,"toast")
	if show then
		frame.Visible=true
		frame.Position=target+UDim2.fromOffset(0,16)
		self:Pop(frame,0.94)
		self:Tween(frame,"toast",{Position=target},0.18)
	else
		self:Tween(frame,"toast",{Position=target+UDim2.fromOffset(0,12)},0.12,nil,nil,function() frame.Visible=false end)
	end
end

function Motion:Count(label,value,format)
	local amount=label:FindFirstChild("DisplayedAmount")
	if not amount then
		amount=Instance.new("NumberValue");amount.Name="DisplayedAmount";amount.Value=value;amount.Parent=label
		amount.Changed:Connect(function(v) label.Text=format(v) end)
		label.Text=format(value)
		return
	end
	-- Spend immediately; smooth only confirmed gains. Never count beyond server state.
	self:Tween(amount,"count",{Value=value},if value<amount.Value then 0 else 0.18)
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
		particle.Size,particle.Position,particle.AnchorPoint=UDim2.fromOffset(7+(i%3)*2,7+(i%3)*2),position,Vector2.new(0.5,0.5)
		particle.BackgroundColor3,particle.BorderSizePixel,particle.Rotation,particle.Parent=color,0,i*33,holder
		local angle=math.pi*2*i/10
		self:Tween(particle,"burst",{Position=position+UDim2.fromOffset(math.cos(angle)*(85+i*4),math.sin(angle)*50-22),Rotation=i*33+130,BackgroundTransparency=1,Size=UDim2.fromOffset(2,2)},0.55)
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
			for property,target in entry.goals do entry.object[property]=if entry.object:IsA("UIScale") and property=="Scale" then 1 else target end
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
