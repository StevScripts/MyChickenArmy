--!strict
-- Client presentation only. Timings never gate a request or manufacture a reward.
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
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
		-- October 21 game feel: staggered reveals per container and count-up tick callbacks.
		reveals=setmetatable({}, {__mode = "k"}),
		countTicks=setmetatable({}, {__mode = "k"}),
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
	-- Read the resting size live: Theme.PadHit shrinks a Visual inside a larger hit area.
	local function goal(amount)
		return if scaled then {Scale=amount} else {Size=multiplied(self.restingSizes[visual] or restingSize,amount)}
	end
	local hovering,focused,pressed=false,false,false
	-- October 21 reference parity: shell buttons (UITheme) set HoverScale 1.05 and
	-- PressScale 0.95; anything else keeps the earlier 1.03 / 0.955.
	local function pressScale(): number
		local value=button:GetAttribute("PressScale")
		return if type(value)=="number" then value else 0.955
	end
	local function update()
		local hot=button.Active and (hovering or focused)
		local hover=button:GetAttribute("HoverScale")
		local target=if self.reduced then 1 elseif pressed and button.Active then pressScale()
			elseif hot then (if type(hover)=="number" then hover else 1.03) else 1
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
		local amount=if self.reduced then 1 else pressScale()
		-- The live resting size: Theme.PadHit shrinks the art inside a larger hit area.
		if scaled then visual.Scale=amount else visual.Size=multiplied(self.restingSizes[visual] or restingSize,amount) end
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
	for _,handle in self.reveals do handle.cancel() end
	self.panelSerial+=1
end

-- ===== October 21 game-feel vocabulary (docs/team/GAME_FEEL_20261021.md) =====
-- Every helper below is an ordinary TweenService tween through Motion:Tween, so it
-- cancels on Destroying, never fights a button press, and settles to its resting
-- state under reduced motion. Presentation only: nothing here changes game state.

-- Named easings so every screen punctuates the same way.
Motion.Ease={
	Pop={style=Enum.EasingStyle.Back,direction=Enum.EasingDirection.Out},
	Snap={style=Enum.EasingStyle.Quart,direction=Enum.EasingDirection.Out},
	Soft={style=Enum.EasingStyle.Sine,direction=Enum.EasingDirection.InOut},
	Bouncy={style=Enum.EasingStyle.Elastic,direction=Enum.EasingDirection.Out},
	Enter={style=Enum.EasingStyle.Quad,direction=Enum.EasingDirection.Out},
	Leave={style=Enum.EasingStyle.Quad,direction=Enum.EasingDirection.In},
}
-- Confetti colours: the UI kit's gold, lime, sky, pink, violet and paper.
Motion.Palette={Color3.fromRGB(255,214,48),Color3.fromRGB(81,255,59),Color3.fromRGB(66,211,255),
	Color3.fromRGB(255,94,139),Color3.fromRGB(210,116,255),Color3.fromRGB(255,251,233)}

local function touchOnly()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Absolute pixels (Vector2) -> a Scale UDim2 inside `parent`; the inverse for Fly/Float.
function Motion:Point(parent,absolute)
	local size=parent.AbsoluteSize
	if size.X<=0 or size.Y<=0 then return UDim2.fromScale(0.5,0.5) end
	local relative=absolute-parent.AbsolutePosition
	return UDim2.fromScale(relative.X/size.X,relative.Y/size.Y)
end

-- The screen-space centre of a GuiObject, for Point.
function Motion:CenterOf(item)
	return item.AbsolutePosition+item.AbsoluteSize/2
end

-- A quick emphasis pop (bigger than PopScale's hover pop) for a value that just changed.
function Motion:Punch(item,amount,seconds)
	self:PopScale(item,amount or 1.18,seconds or 0.3)
end

-- Count a label toward `value` (Quart Out), punching it on gains and calling
-- options.tick(value) at most every options.tickGap seconds for a tick sound.
-- Spends drop at once (options.fallSeconds), like Count: never ahead of the server.
function Motion:CountTo(label,value,format,seconds,options)
	options=options or {}
	local amount=label:FindFirstChild("DisplayedAmount")
	if not amount then
		amount=Instance.new("NumberValue");amount.Name="DisplayedAmount";amount.Value=value;amount.Parent=label
		amount:SetAttribute("Target",value)
		amount.Changed:Connect(function(v)
			label.Text=format(v)
			local tick=self.countTicks[label]
			if tick and os.clock()-(amount:GetAttribute("LastTick") or 0)>=tick.gap then
				amount:SetAttribute("LastTick",os.clock())
				tick.fn(v)
			end
		end)
		label.Text=format(value)
		return
	end
	local previous=amount:GetAttribute("Target")
	if previous==value then return end
	amount:SetAttribute("Target",value)
	local rising=value>(previous or amount.Value)
	if rising and options.tick then self.countTicks[label]={fn=options.tick,gap=options.tickGap or 0.06} else self.countTicks[label]=nil end
	if rising and options.punch~=false then self:Punch(options.punchTarget or label,options.punch or 1.12,0.28) end
	self:Tween(amount,"count",{Value=value},if rising then (seconds or 0.45) else (options.fallSeconds or 0),
		Enum.EasingStyle.Quart,Enum.EasingDirection.Out,function() self.countTicks[label]=nil end)
end

-- Run `each(item,index,delay)` across items with a short gap, the last starting within
-- `window` seconds however long the list is. Returns a handle with cancel().
function Motion:Stagger(items,each,gap,window)
	local handle={alive=true,cancel=nil}
	function handle.cancel() handle.alive=false end
	local count=#items
	if count==0 then return handle end
	local step=math.min(gap or 0.04,(window or 0.45)/math.max(1,count-1))
	for index,item in items do
		local delay=(index-1)*step
		if delay<=0 or self.reduced then each(item,index,0)
		else task.delay(delay,function() if handle.alive and item.Parent then each(item,index,delay) end end) end
	end
	return handle
end

-- Grow a container's visible children in one after another (cards, rows, tiles) when
-- a menu opens or a list refreshes. Replaces any reveal still running on the container.
-- options: from (0.7), seconds (0.26), gap (0.035), window (0.4), limit (40), each(item,index).
function Motion:Reveal(container,options)
	options=options or {}
	local previous=self.reveals[container]
	if previous then previous.cancel() end
	local items={}
	for _,child in container:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then table.insert(items,child) end
	end
	table.sort(items,function(a,b)
		if a.LayoutOrder~=b.LayoutOrder then return a.LayoutOrder<b.LayoutOrder end
		local pa,pb=a.AbsolutePosition,b.AbsolutePosition
		if math.abs(pa.Y-pb.Y)>2 then return pa.Y<pb.Y end
		return pa.X<pb.X
	end)
	local limit=options.limit or 40
	local from=options.from or 0.7
	for index,item in items do
		if index>limit then break end
		local scale=self:ScaleOf(item)
		self:Cancel(scale,"pop");self:Cancel(scale,"press")
		scale.Scale=if self.reduced then 1 else from
	end
	local handle=self:Stagger(items,function(item,index)
		if index>limit then return end
		self:Tween(self:ScaleOf(item),"pop",{Scale=1},options.seconds or 0.26,Enum.EasingStyle.Back)
		if options.each then options.each(item,index) end
	end,options.gap or 0.035,options.window or 0.4)
	local stop=handle.cancel
	function handle.cancel()
		stop()
		for _,item in items do
			local scale=item:FindFirstChildWhichIsA("UIScale")
			if scale then self:Cancel(scale,"pop");scale.Scale=1 end
		end
		if self.reveals[container]==handle then self.reveals[container]=nil end
	end
	self.reveals[container]=handle
	return handle
end

-- A quick colour wash over an item (a bar that filled, a card that confirmed).
function Motion:Flash(item,color,seconds,peak)
	if not item or not item.Parent then return end
	local flash=item:FindFirstChild("MotionFlash")
	if not flash then
		flash=Instance.new("Frame")
		flash.Name,flash.Size,flash.BorderSizePixel,flash.BackgroundTransparency="MotionFlash",UDim2.fromScale(1,1),0,1
		local corner=item:FindFirstChildWhichIsA("UICorner")
		if corner then corner:Clone().Parent=flash end
		flash.Parent=item
	end
	flash.ZIndex=item.ZIndex+6
	flash.BackgroundColor3=color or Color3.new(1,1,1)
	self:Cancel(flash,"flash")
	if self.reduced then flash.Visible=false;return end
	flash.Visible=true
	flash.BackgroundTransparency=1-(peak or 0.55)
	self:Tween(flash,"flash",{BackgroundTransparency=1},seconds or 0.35,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,function() flash.Visible=false end)
end

-- Floating "+12" text that pops in, rises and fades. `position` is a UDim2 inside
-- `parent` (see Point). options: color, size (px), seconds (0.9), rise (0.08 scale),
-- font, stroke, limit (12 alive per parent). Reduced motion shows it still, then removes it.
function Motion:Float(parent,text,position,options)
	options=options or {}
	local holder=parent:FindFirstChild("MotionFloats")
	if not holder then
		holder=Instance.new("Frame")
		holder.Name,holder.Size,holder.BackgroundTransparency,holder.ZIndex="MotionFloats",UDim2.fromScale(1,1),1,30
		holder.Parent=parent
	end
	local alive=holder:GetChildren()
	if #alive>=(options.limit or 12) then alive[1]:Destroy() end
	local size=options.size or 26
	local label=Instance.new("TextLabel")
	label.Name,label.Text,label.BackgroundTransparency="MotionFloat",text,1
	label.Font,label.TextSize,label.TextColor3=options.font or Enum.Font.MontserratBold,size,options.color or Color3.new(1,1,1)
	label.AnchorPoint,label.Position,label.Size=Vector2.new(0.5,0.5),position,UDim2.fromOffset(size,size)
	label.AutomaticSize,label.TextWrapped,label.ZIndex=Enum.AutomaticSize.XY,false,31
	local stroke=Instance.new("UIStroke")
	stroke.Color,stroke.Thickness,stroke.LineJoinMode=options.stroke or Color3.fromRGB(20,32,15),math.max(1.5,size*0.08),Enum.LineJoinMode.Round
	stroke.Parent=label
	label.Parent=holder
	local seconds=options.seconds or 0.9
	if self.reduced then
		task.delay(seconds,function() if label.Parent then label:Destroy() end end)
		return label
	end
	local scale=self:ScaleOf(label)
	scale.Scale=0.6
	self:Tween(scale,"pop",{Scale=1},0.22,Enum.EasingStyle.Back)
	self:Tween(label,"float",{Position=position-UDim2.fromScale(0,options.rise or 0.08)},seconds,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	task.delay(seconds*0.55,function()
		if not label.Parent then return end
		self:Tween(stroke,"float-fade",{Transparency=1},seconds*0.45,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
		self:Tween(label,"float-fade",{TextTransparency=1},seconds*0.45,Enum.EasingStyle.Quad,Enum.EasingDirection.In,function() label:Destroy() end)
	end)
	return label
end

-- An image that flies from one screen point to another in a small arc (a coin into
-- the Coins readout, a chicken into the Army count). from/to are UDim2 inside parent
-- (see Point). options: size (UDim2), seconds (0.55), arc (0.08), spin (180),
-- onArrive(), limit (16). Reduced motion skips the flight and arrives at once.
function Motion:Fly(parent,asset,from,to,options)
	options=options or {}
	local function arrive() if options.onArrive then options.onArrive() end end
	if self.reduced then arrive();return nil end
	local holder=parent:FindFirstChild("MotionFlyers")
	if not holder then
		holder=Instance.new("Frame")
		holder.Name,holder.Size,holder.BackgroundTransparency,holder.ZIndex="MotionFlyers",UDim2.fromScale(1,1),1,32
		holder.Parent=parent
	end
	if #holder:GetChildren()>=(options.limit or 16) then arrive();return nil end
	local image=Instance.new("ImageLabel")
	image.Name,image.Image,image.BackgroundTransparency="MotionFlyer",asset,1
	image.AnchorPoint,image.Position,image.Size=Vector2.new(0.5,0.5),from,options.size or UDim2.fromOffset(36,36)
	image.ScaleType,image.ZIndex=Enum.ScaleType.Fit,33
	image.Parent=holder
	local seconds=options.seconds or 0.55
	local scale=self:ScaleOf(image)
	scale.Scale=0.5
	self:Tween(scale,"pop",{Scale=1.15},0.18,Enum.EasingStyle.Back)
	local mid=from:Lerp(to,0.5)-UDim2.fromScale(0,options.arc or 0.08)
	self:Tween(image,"fly",{Position=mid},seconds*0.45,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,function()
		self:Tween(scale,"pop",{Scale=0.7},seconds*0.55,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
		self:Tween(image,"fly",{Position=to},seconds*0.55,Enum.EasingStyle.Quad,Enum.EasingDirection.In,function()
			image:Destroy()
			arrive()
		end)
	end)
	self:Tween(image,"spin",{Rotation=options.spin or 180},seconds,Enum.EasingStyle.Linear)
	return image
end

-- Confetti pieces thrown from `origin` (UDim2, default upper centre) that fall and
-- fade. options: count (28 desktop / 16 touch), origin, spread (0.5), seconds (1.4),
-- colors. One burst per parent at a time; reduced motion shows none.
function Motion:Confetti(parent,options)
	if self.reduced or not parent or not parent.Parent then return nil end
	options=options or {}
	local existing=parent:FindFirstChild("MotionConfetti")
	if existing then existing:Destroy() end
	local holder=Instance.new("Frame")
	holder.Name,holder.Size,holder.BackgroundTransparency,holder.ZIndex="MotionConfetti",UDim2.fromScale(1,1),1,28
	holder.ClipsDescendants=true
	holder.Parent=parent
	local count=options.count or (if touchOnly() then 16 else 28)
	local origin=options.origin or UDim2.fromScale(0.5,0.3)
	local spread=options.spread or 0.5
	local seconds=options.seconds or 1.4
	local palette=options.colors or Motion.Palette
	local random=Random.new()
	for _=1,count do
		local piece=Instance.new("Frame")
		piece.Size=UDim2.fromOffset(random:NextInteger(7,13),random:NextInteger(6,16))
		piece.BackgroundColor3,piece.BorderSizePixel=palette[random:NextInteger(1,#palette)],0
		piece.AnchorPoint,piece.Position,piece.Rotation,piece.ZIndex=Vector2.new(0.5,0.5),origin,random:NextNumber(0,360),29
		piece.Parent=holder
		local dx=random:NextNumber(-spread,spread)
		local peak=origin+UDim2.fromScale(dx*0.6,-random:NextNumber(0.08,0.28))
		local landing=origin+UDim2.fromScale(dx,random:NextNumber(0.45,0.75))
		local up=random:NextNumber(0.25,0.4)*seconds
		self:Tween(piece,"burst",{Position=peak},up,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,function()
			self:Tween(piece,"burst",{Position=landing,BackgroundTransparency=1},seconds-up,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
		end)
		self:Tween(piece,"spin",{Rotation=piece.Rotation+random:NextNumber(-540,540)},seconds,Enum.EasingStyle.Linear)
	end
	task.delay(seconds+0.1,function() if holder.Parent then holder:Destroy() end end)
	return holder
end

-- A press ring that expands out of an item and fades (big confirms, claims).
function Motion:Ripple(item,color)
	if self.reduced or not item or not item.Parent then return end
	local ring=Instance.new("Frame")
	ring.Name,ring.AnchorPoint,ring.Position="MotionRipple",Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
	ring.Size,ring.BackgroundTransparency,ring.BorderSizePixel,ring.ZIndex=UDim2.fromScale(0.7,0.7),1,0,item.ZIndex+7
	local corner=item:FindFirstChildWhichIsA("UICorner")
	if corner then corner:Clone().Parent=ring end
	local stroke=Instance.new("UIStroke")
	stroke.Color,stroke.Thickness,stroke.Transparency,stroke.LineJoinMode=color or Color3.new(1,1,1),3,0.1,Enum.LineJoinMode.Round
	stroke.Parent=ring
	ring.Parent=item
	self:Tween(stroke,"ripple",{Transparency=1,Thickness=0.5},0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	self:Tween(ring,"ripple",{Size=UDim2.fromScale(1.35,1.35)},0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,function() ring:Destroy() end)
end

-- A pulsing stroke around something ready to use (an affordable node, a claimable
-- tile). StopGlow/Settle removes it. Reduced motion keeps a steady ring instead.
function Motion:Glow(item,color,thickness)
	if not item or not item.Parent then return end
	local stroke=item:FindFirstChild("MotionGlow")
	if not stroke then
		-- An item that already owns a UIStroke keeps it: the glow rides a transparent ring
		-- child instead, so the two strokes never fight over one edge.
		local host=item
		if item:FindFirstChildWhichIsA("UIStroke") then
			local ring=item:FindFirstChild("MotionGlowRing")
			if not ring then
				ring=Instance.new("Frame")
				ring.Name,ring.Size,ring.BackgroundTransparency,ring.BorderSizePixel="MotionGlowRing",UDim2.fromScale(1,1),1,0
				ring.ZIndex,ring.Active=item.ZIndex+1,false
				local corner=item:FindFirstChildWhichIsA("UICorner")
				if corner then corner:Clone().Parent=ring end
				ring.Parent=item
			end
			host=ring
		end
		stroke=host:FindFirstChild("MotionGlow")
		if not stroke then
			stroke=Instance.new("UIStroke")
			stroke.Name,stroke.ApplyStrokeMode,stroke.LineJoinMode="MotionGlow",Enum.ApplyStrokeMode.Border,Enum.LineJoinMode.Round
			stroke.Parent=host
		end
	end
	stroke.Color,stroke.Enabled=color or Motion.Palette[1],true
	local thick=thickness or 3
	self:Loop(stroke,"glow",{Transparency=0.85,Thickness=thick*0.5},{Transparency=0.15,Thickness=thick},0.7)
end

function Motion:StopGlow(item)
	if not item then return end
	local stroke=item:FindFirstChild("MotionGlow")
	if not stroke then
		local ring=item:FindFirstChild("MotionGlowRing")
		stroke=ring and ring:FindFirstChild("MotionGlow")
	end
	if not stroke then return end
	self:StopLoop(stroke,"glow")
	stroke.Enabled=false
end

-- Gentle up-and-down attention bob on the item's own Position. Shake interrupts it.
function Motion:Bob(item,amount,seconds)
	if not item or not item.Parent then return end
	local rest=self.restingPositions[item] or item.Position
	self.restingPositions[item]=rest
	self:Loop(item,"bob",{Position=rest-UDim2.fromScale(0,amount or 0.02)},{Position=rest},seconds or 0.55)
end

function Motion:StopBob(item)
	if not item then return end
	self:StopLoop(item,"bob")
	self.restingPositions[item]=nil
end

-- Side-to-side rotation wobble (a gift waiting to be opened). StopWobble squares it.
function Motion:Wobble(item,degrees,seconds)
	if not item or not item.Parent then return end
	local amount=degrees or 6
	self:Loop(item,"wobble",{Rotation=amount},{Rotation=-amount},seconds or 0.35)
	if self.reduced then item.Rotation=0 end
end

function Motion:StopWobble(item)
	if not item then return end
	self:StopLoop(item,"wobble")
	item.Rotation=0
end

-- Slide an item from one Position to another (`ease` from Motion.Ease).
function Motion:Slide(item,from,to,seconds,ease)
	self:Cancel(item,"slide")
	if self.reduced then item.Position=to;return end
	item.Position=from
	local easing=ease or Motion.Ease.Enter
	self:Tween(item,"slide",{Position=to},seconds or 0.28,easing.style,easing.direction)
end

-- Tween a fill bar's X scale to `fraction`; a gain flashes the bar (flashColor=false skips).
function Motion:Progress(bar,fraction,seconds,flashColor)
	fraction=math.clamp(fraction,0,1)
	local size=bar.Size
	local rising=fraction>size.X.Scale+0.0005
	self:Tween(bar,"progress",{Size=UDim2.new(fraction,size.X.Offset,size.Y.Scale,size.Y.Offset)},seconds or 0.35,Enum.EasingStyle.Quart,Enum.EasingDirection.Out)
	if rising and flashColor~=false then self:Flash(bar,flashColor or Color3.new(1,1,1),0.3,0.4) end
end

-- Stop every attention loop on an item (breathe, glow, bob, wobble) before hiding it.
function Motion:Settle(item)
	if not item then return end
	self:StopBreathe(item)
	self:StopGlow(item)
	self:StopBob(item)
	self:StopWobble(item)
end

return Motion
