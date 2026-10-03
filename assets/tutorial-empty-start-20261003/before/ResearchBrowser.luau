--!strict
-- A full-screen research map. Graph geometry uses a native aspect constraint;
-- input changes only its pan/zoom, never the layout of individual nodes.
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.ResearchCatalog)
local Rules=require(Shared.ResearchRules)
local Theme=require(script.Parent.UITheme)
local Assets=require(script.Parent.ResearchAssets)
local CashNodes=require(script.Parent.CashUpgradeNodes)
-- Cash tiers and research share display positions, but keep their saved progress
-- separate. These coordinate overrides never alter ResearchCatalog's contracts.
local displayOrder,displayNodes=table.clone(Catalog.Order),{}
for id,node in Catalog.Nodes do
	local display=table.clone(node)
	local position=CashNodes.ResearchPositions[id]
	if position then display.q,display.r=position.q,position.r end
	displayNodes[id]=display
end
for _,id in CashNodes.Order do table.insert(displayOrder,id);displayNodes[id]=CashNodes.Nodes[id] end
local Browser={}
Browser.__index=Browser
local GREEN=Color3.fromRGB(76,250,32)
local CYAN=Color3.fromRGB(0,226,250)
local WHITE=Color3.fromRGB(255,255,255)
local MUTED=Color3.fromRGB(64,67,65)
local RED=Color3.fromRGB(255,77,86)
local TOOLTIP_WIDTH=.218
local NODE_SIZE=UDim2.fromScale(144/1440,164/930)
-- Presentation tuning only: seconds and relative scales, never purchase timing.
local MOTION={
	OpenScale=0,OpenSeconds=.24,OpenStaggerSeconds=.045,OpenWaveSeconds=.80,
	FrontierEntryScale=.88,FrontierSeconds=.18,FrontierWaveSeconds=.08,FrontierScale=1.025,
	HoverScale=1.025,PressScale=.96,PressSeconds=.055,SettleSeconds=.13,
	ConfirmScale=1.045,ConfirmRiseSeconds=.10,ConfirmSettleSeconds=.18,
	TintSeconds=.20,FlashSeconds=.35,CompletionLimit=3,CompletionStaggerSeconds=.04,
}
local function cancelTween(owner,key)
	local tween=owner[key]
	if tween then owner[key]=nil;tween:Cancel();tween:Destroy() end
end
local function cancelSize(view)
	view.revealing=false
	if view.revealSoundConnection then view.revealSoundConnection:Disconnect();view.revealSoundConnection=nil end
	if view.sizeConnection then view.sizeConnection:Disconnect();view.sizeConnection=nil end
	cancelTween(view,"sizeTween")
end
local function point(node)
	return Vector2.new((690+154*(node.q+node.r/2))/1440,(450+133.4*node.r)/930)
end
local function timeText(seconds)
	seconds=math.max(0,math.ceil(seconds))
	if seconds>=86400 then return string.format("%dd %dh",math.floor(seconds/86400),math.floor(seconds%86400/3600)) end
	if seconds>=3600 then return string.format("%dh %dm",math.floor(seconds/3600),math.floor(seconds%3600/60)) end
	if seconds>=60 then return string.format("%dm %02ds",math.floor(seconds/60),seconds%60) end
	return seconds.."s"
end
local function priceText(amount)
	if amount>=1e6 then return string.format("%g",amount/1e6).."M" end
	if amount>=1000 then return string.format("%g",amount/1000).."K" end
	return tostring(amount)
end
local function cashStatus(offer,coins)
	if not offer or not offer.ready then return "Loading" end
	if not offer.price then return "Unavailable" end
	if not offer.unlocked then return "Unavailable" end
	return if coins<offer.price then "Unaffordable" else "Available"
end
local function label(parent,name,text,x,y,w,h,color)
	local item=Theme.Label(parent,name,text,20,color or WHITE)
	item.Position,item.Size=UDim2.fromScale(x,y),UDim2.fromScale(w,h)
	item.TextScaled,item.TextXAlignment=true,Enum.TextXAlignment.Center
	item.TextOutline.Thickness=.035
	return item
end
local function inside(item,position)
	local p,s=item.AbsolutePosition,item.AbsoluteSize
	return position.X>=p.X and position.Y>=p.Y and position.X<=p.X+s.X and position.Y<=p.Y+s.Y
end
-- Wrap by content, not by viewport; native aspect constraints size the card.
local function wrap(text,limit)
	local rows,line={},""
	for word in text:gmatch("%S+") do
		if #line>0 and #line+1+#word>limit then table.insert(rows,line);line=word
		else line=if line=="" then word else line.." "..word end
	end
	if line~="" then table.insert(rows,line) end
	return table.concat(rows,"\n"),math.max(1,#rows)
end
local function round(item,radius)
	Theme.Round(item).CornerRadius=UDim.new(radius,0)
end
local function glow(parent,asset,ratio)
	local layers={}
	for i=1,6 do
		local spread=(7-i)*.018
		local image=Theme.Image(parent,"Halo"..i,asset,UDim2.fromScale(1+spread,1+spread),UDim2.fromScale(.5,.5))
		image.AnchorPoint,image.ZIndex=Vector2.new(.5,.5),1
		image.ImageTransparency=1-(.025+i*.009)
		if ratio then Theme.Aspect(image,ratio) end
		table.insert(layers,image)
	end
	return layers
end

function Browser.new(app,parent)
	local self=setmetatable({app=app,nodes={},links={},connections={},zoom=1,pan=Vector2.zero,alive=true,receivedAt=0,serverTime=0,cashPending={},cashRequests={}},Browser)
	local root=Instance.new("TextButton")
	root.Name,root.Text,root.Size="Research","",UDim2.fromScale(1,1)
	root:SetAttribute("HoverAudioCue","SkillTreeHover")
	root.BackgroundColor3,root.BorderSizePixel=Color3.new(0,0,0),0
	root.Visible,root.Active,root.Modal,root.AutoButtonColor=false,true,true,false
	root.Selectable,root.ClipsDescendants,root.ZIndex=false,true,15
	root.Parent=parent;self.root=root
	local map=Theme.Container(root,"Map")
	map.AnchorPoint,map.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
	-- Keep native height-relative geometry without capping zoom at the parent.
	map.SizeConstraint=Enum.SizeConstraint.RelativeYY
	Theme.Aspect(map,1440/930)
	map.UIAspectRatioConstraint.DominantAxis=Enum.DominantAxis.Height
	self.map=map
	-- Adjacent hexes already read as a path. Bridge only longer prerequisite
	-- gaps, using the same map coordinates so native aspect/pan/zoom owns sizing.
	for _,id in displayOrder do
		local node=displayNodes[id]
		local parentNode=node.prerequisite and displayNodes[node.prerequisite]
		if parentNode then
			local dq,dr=node.q-parentNode.q,node.r-parentNode.r
			if math.max(math.abs(dq),math.abs(dr),math.abs(dq+dr))>1 then
				local from,to=point(parentNode),point(node)
				local delta=Vector2.new((to.X-from.X)*1440,(to.Y-from.Y)*930)
				local line=Theme.Frame(map,"Link_"..id,UDim2.fromScale(delta.Magnitude/1440,2/930),Color3.fromRGB(51,58,54))
				line.AnchorPoint,line.Position=Vector2.new(.5,.5),UDim2.fromScale((from.X+to.X)/2,(from.Y+to.Y)/2)
				line.Rotation=math.deg(math.atan2(delta.Y,delta.X))
				line.BackgroundTransparency,line.Visible,line.ZIndex=.35,false,1
				self.links[id]={line=line,parentId=node.prerequisite}
			end
		end
	end
	for _,id in displayOrder do
		local node=displayNodes[id];local p=point(node)
		local button=Instance.new("ImageButton")
		button.Name,button.Image,button.BackgroundTransparency=id,"",1
		button.Size,button.AnchorPoint,button.Position=NODE_SIZE,Vector2.new(.5,.5),UDim2.fromScale(p.X,p.Y)
		button.AutoButtonColor,button.Visible,button.Parent=false,false,map
		Theme.Aspect(button,144/164)
		local visual=Theme.Container(button,"Visual")
		visual.AnchorPoint,visual.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
		local halos=glow(visual,Assets.hexMask)
		local outline=Theme.Image(visual,"Outline",Assets.hexMask,UDim2.fromScale(1,1));outline.ZIndex=2
		local fill=Theme.Image(visual,"Fill",Assets.hexFill,UDim2.fromScale(.951,.951),UDim2.fromScale(.0245,.0245));fill.ZIndex=3
		local gradient=Theme.Gradient(fill,WHITE,Color3.fromRGB(226,244,221))
		local icon=Theme.Image(visual,"Icon",Assets[node.icon],UDim2.fromScale(.60,.52),UDim2.fromScale(.20,.14));icon.ZIndex=4
		local title=label(visual,"Title",node.name,.025,.665,.95,.12);title.ZIndex=5
		local cost=Theme.Container(visual,"Cost");cost.Position,cost.Size,cost.ZIndex=UDim2.fromScale(.22,.795),UDim2.fromScale(.56,.115),5
		local cashIcon=Theme.Image(cost,"CashIcon",Assets.cash,UDim2.fromScale(.27,1));cashIcon.ZIndex=5
		local price=label(cost,"Price","",.28,0,.72,1,GREEN);price.TextXAlignment=Enum.TextXAlignment.Left;price.ZIndex=5
		local hidden=label(visual,"Hidden","?",.16,.24,.68,.43);hidden.ZIndex=5
		local bar=Theme.Frame(visual,"Progress",UDim2.fromScale(.70,.085),Color3.fromRGB(0,157,184))
		bar.Position,bar.ZIndex=UDim2.fromScale(.15,.735),5;round(bar,.12)
		local progress=Theme.Frame(bar,"Fill",UDim2.fromScale(0,1),Color3.fromRGB(87,246,255));progress.ZIndex=6;round(progress,.12)
		local timer=label(bar,"Time","",.035,.04,.93,.9);timer.ZIndex=7
		local level,change
		if CashNodes.Nodes[id] then
			level=label(visual,"Level","",.21,.055,.58,.085,CYAN);level.ZIndex=5
			change=label(visual,"Benefit","",.09,.665,.82,.105);change.ZIndex=5
		end
		self.nodes[id]={button=button,visual=visual,halos=halos,outline=outline,fill=fill,gradient=gradient,icon=icon,title=title,cost=cost,cashIcon=cashIcon,price=price,hidden=hidden,bar=bar,progress=progress,timer=timer,level=level,change=change}
		button.Activated:Connect(function(input)
			if not self.root.Visible or os.clock()<(self.suppressUntil or 0) then return end
			self:Select(id,input and input.UserInputType~=Enum.UserInputType.MouseButton1)
			if self.selected==id then self:Activate() end
		end)
		button.MouseEnter:Connect(function()
			if self.pinchScale or (self.drag and self.drag.moved) then return end
			local view=self.nodes[id];view.hovered=true;self:RestNode(view)
			if self.root.Visible and not self.options.Visible and not self.drag then self:Select(id,false) end
		end)
		button.MouseLeave:Connect(function()
			local view=self.nodes[id];view.hovered=false;view.pressed=false;self:RestNode(view)
			if not self.persistent and self.selected==id then self:DismissTooltip() end
		end)
		button.MouseButton2Click:Connect(function() self:ShowOptions(id) end)
		button.SelectionGained:Connect(function()
			local view=self.nodes[id];view.focused=true;self:RestNode(view)
			if self.root.Visible then self:Select(id,true) end
		end)
		button.SelectionLost:Connect(function()
			local view=self.nodes[id];view.focused=false;view.pressed=false;self:RestNode(view)
		end)
		button.InputBegan:Connect(function(input)
			if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
				local view=self.nodes[id];view.pressInput=input;view.pressed=true;self:RestNode(view)
			end
			if input.UserInputType~=Enum.UserInputType.Touch then return end
			task.delay(.55,function()
				local drag=self.drag
				if self.alive and self.root.Visible and drag and drag.input==input and not drag.moved then
					drag.inspected=true;self.suppressUntil=os.clock()+.8;self:ShowOptions(id)
				end
			end)
		end)
	end
	self.banner=label(root,"OfflineMessage","Your research works offline!",.225,.03,.55,.044)
	self.banner.ZIndex=5
	local money=Theme.Container(root,"ResearchBalance")
	money.AnchorPoint,money.Position,money.Size=Vector2.new(0,1),UDim2.fromScale(.012,.975),UDim2.fromScale(.26,.105)
	Theme.Aspect(money,3.6);money.ZIndex=5
	Theme.Image(money,"ResearcherIcon",Assets.lab,UDim2.fromScale(.075,.34))
	self.researchers=label(money,"Researchers","Researchers: 0/1",.085,0,.915,.34,CYAN);self.researchers.TextXAlignment=Enum.TextXAlignment.Left
	Theme.Image(money,"CashIcon",Assets.cash,UDim2.fromScale(.13,.53),UDim2.fromScale(0,.44))
	self.cash=label(money,"Cash","$0",.15,.37,.85,.63,GREEN);self.cash.TextXAlignment=Enum.TextXAlignment.Left
	self.exit=Instance.new("TextButton")
	self.exit.Name,self.exit.Text,self.exit.AutoButtonColor="Exit","",false
	self.exit.BackgroundColor3,self.exit.BorderSizePixel=Color3.fromRGB(239,5,31),0
	self.exit.AnchorPoint,self.exit.Position,self.exit.Size,self.exit.ZIndex=Vector2.new(.5,1),UDim2.fromScale(.5,.955),UDim2.fromScale(.155,.09),6
	self.exit.Parent=root;self.exit.BackgroundTransparency=1;Theme.Aspect(self.exit,3.03)
	for i=1,6 do
		local spread=(7-i)*.045
		local halo=Theme.Frame(self.exit,"RedHalo"..i,UDim2.fromScale(1+spread/3.03,1+spread),Color3.fromRGB(255,0,35))
		halo.Position,halo.AnchorPoint,halo.BackgroundTransparency,halo.ZIndex=UDim2.fromScale(.5,.5),Vector2.new(.5,.5),.965,1
		round(halo,.14)
	end
	local exitFace=Theme.Frame(self.exit,"Face",UDim2.fromScale(1,1),WHITE);exitFace.ZIndex=2;round(exitFace,.14)
	exitFace.AnchorPoint,exitFace.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
	self.exitMotion={button=self.exit,visual=exitFace}
	self.exit.MouseEnter:Connect(function() self.exitMotion.hovered=true;self:RestNode(self.exitMotion) end)
	self.exit.MouseLeave:Connect(function() self.exitMotion.hovered=false;self.exitMotion.pressed=false;self:RestNode(self.exitMotion) end)
	self.exit.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
			self.exitMotion.pressInput=input;self.exitMotion.pressed=true;self:RestNode(self.exitMotion)
		end
	end)
	Theme.Stroke(exitFace,Color3.fromRGB(85,0,10),3).LineJoinMode=Enum.LineJoinMode.Round
	Theme.Gradient(exitFace,Color3.fromRGB(212,0,18),Color3.fromRGB(255,7,38))
	local studs=Theme.Studs(exitFace,.045,28,0);studs:SetAttribute("StudScaleHeight",13);studs.ZIndex=3
	local exitText=label(exitFace,"Caption","Exit",.08,.07,.84,.81);exitText.ZIndex=4;exitText.TextOutline.Thickness=.07
	self.exit.Activated:Connect(function() self.app.audio:Play("Click");self:Close() end)
	self.message=label(root,"Feedback","",.15,.17,.70,.055,CYAN)
	self.message.ZIndex,self.message.Visible=12,false

	self:BuildTooltip()
	self:BindInput()
	local elapsed=0
	table.insert(self.connections,RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt
		if elapsed>=.25 then elapsed=0;if self.root.Visible then self:Step() end end
	end))
	return self
end

function Browser:BuildTooltip()
	local tip=Theme.Frame(self.root,"NodeTooltip",UDim2.fromScale(1,TOOLTIP_WIDTH),Color3.fromRGB(27,27,27))
	Theme.Aspect(tip,1)
	local aspect=tip.UIAspectRatioConstraint
	-- A constant height-relative width keeps this card independent of map zoom.
	aspect.AspectType,aspect.DominantAxis=Enum.AspectType.ScaleWithParentSize,Enum.DominantAxis.Height
	round(tip,.045);Theme.Stroke(tip,Color3.fromRGB(206,206,206),1.5).LineJoinMode=Enum.LineJoinMode.Round
	tip.Visible,tip.Active,tip.ZIndex=false,false,8
	self.tip,self.tipAspect,self.tipMotion=tip,aspect,{}
	self.tipTitle=label(tip,"Name","",.055,.06,.89,.18);self.tipTitle.ZIndex=9
	self.tipTitle.TextOutline.Enabled=false
	self.tipDivider=Theme.Frame(tip,"Divider",UDim2.fromScale(.83,.005),Color3.fromRGB(77,77,77))
	self.tipDivider.Position,self.tipDivider.ZIndex=UDim2.fromScale(.085,.27),9
	self.tipEffect=label(tip,"Effect","",.06,.31,.88,.39,Color3.fromRGB(172,172,172));self.tipEffect.ZIndex=9;self.tipEffect.TextOutline.Enabled=false
	self.tipCost=Theme.Container(tip,"Cost");self.tipCost.ZIndex=9
	self.tipCash=Theme.Image(self.tipCost,"CashIcon",Assets.cash,UDim2.fromScale(.25,1));self.tipCash.ZIndex=10
	self.tipPrice=label(self.tipCost,"Price","",.27,0,.73,1,GREEN);self.tipPrice.TextXAlignment=Enum.TextXAlignment.Left;self.tipPrice.ZIndex=10
	self.tipBar=Theme.Frame(tip,"Progress",UDim2.fromScale(.87,.15),Color3.fromRGB(3,48,56));self.tipBar.ZIndex=9;round(self.tipBar,.14)
	self.tipProgress=Theme.Frame(self.tipBar,"Fill",UDim2.fromScale(0,1),Color3.fromRGB(0,166,206));self.tipProgress.ZIndex=10;round(self.tipProgress,.14)
	self.tipTimer=label(self.tipBar,"Time","",.03,.07,.94,.86);self.tipTimer.ZIndex=11
	local options=Theme.Frame(self.root,"ResearchOptions",UDim2.fromScale(1,.115),Color3.fromRGB(27,27,27))
	Theme.Aspect(options,2.3);local oa=options.UIAspectRatioConstraint;oa.AspectType,oa.DominantAxis=Enum.AspectType.ScaleWithParentSize,Enum.DominantAxis.Height
	round(options,.07);Theme.Stroke(options,Color3.fromRGB(128,128,128),1)
	options.Visible,options.Active,options.ZIndex=false,true,10;self.options=options
	local function action(name,y,text,callback)
		local button=Instance.new("TextButton")
		button.Name,button.Text,button.BackgroundTransparency,button.AutoButtonColor=name,"",1,false
		button.Position,button.Size,button.ZIndex=UDim2.fromScale(.035,y),UDim2.fromScale(.93,.40),11
		button.Parent=options
		local caption=label(button,"Caption",text,.04,.12,.92,.76);caption.ZIndex=12
		button.Activated:Connect(callback)
		return button,caption
	end
	self.goalAction,self.goalCaption=action("Pin",.05,"Pin goal",function() self:Secondary();self.options.Visible=false end)
	self.cancelAction,self.cancelCaption=action("Cancel",.53,"Cancel research",function() self:CancelSelected() end)
end

function Browser:RestScale(view)
	if self.app.reducedMotion or view.kind=="Hidden" then return 1 end
	return if view.pressed then MOTION.PressScale elseif view.hovered or view.focused then MOTION.HoverScale else 1
end

function Browser:SizeNode(view,scale,seconds,delay,complete)
	cancelSize(view)
	if self.app.reducedMotion then view.visual.Size=UDim2.fromScale(1,1);view.pulsing=false;return end
	local tween=TweenService:Create(view.visual,TweenInfo.new(seconds,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,delay or 0),{Size=UDim2.fromScale(scale,scale)})
	view.sizeTween=tween
	if complete then
		view.sizeConnection=tween.Completed:Connect(function(state)
			if state==Enum.PlaybackState.Completed and self.alive and self.root.Visible and view.sizeTween==tween then complete() end
		end)
	end
	tween:Play()
end

function Browser:RestNode(view,seconds)
	if not self.root.Visible or not view.button.Visible then return end
	if (view.pulsing or view.revealing) and not view.pressed then return end
	view.pulsing=false
	self:SizeNode(view,self:RestScale(view),seconds or (if view.pressed then MOTION.PressSeconds else MOTION.SettleSeconds))
end

function Browser:PulseNode(view,scale,delay)
	if not view or not view.button.Visible or self.app.reducedMotion then return end
	view.pulsing=true
	self:SizeNode(view,scale or MOTION.ConfirmScale,MOTION.ConfirmRiseSeconds,delay,function()
		view.pulsing=false;self:RestNode(view,MOTION.ConfirmSettleSeconds)
	end)
end

function Browser:RevealNodes(reveals)
	if #reveals==0 then return end
	local opening=self.opening
	if not opening and self.revealOrigin and self.root.Visible then
		self.app.audio:Play("SkillTreeNodeAdded",nil,{noFallback=true,voiceKey="SkillTreeNodeAdded",cooldown=.1})
	end
	local origin=point(displayNodes[if opening then "Start" else self.revealOrigin or "Start"])
	table.sort(reveals,function(a,b)
		local da,db=(point(displayNodes[a.id])-origin).Magnitude,(point(displayNodes[b.id])-origin).Magnitude
		return if da==db then a.id<b.id else da<db
	end)
	local far=(point(displayNodes[reveals[#reveals].id])-origin).Magnitude
	local stagger=math.min(MOTION.OpenStaggerSeconds,MOTION.OpenWaveSeconds/math.max(1,#reveals-1))
	for index,entry in reveals do
		local view=self.nodes[entry.id]
		local distance=(point(displayNodes[entry.id])-origin).Magnitude
		local delay=if opening then (index-1)*stagger else (if self.revealOrigin then MOTION.ConfirmRiseSeconds else 0)+(if far>0 then distance/far else 0)*MOTION.FrontierWaveSeconds
		if self.app.reducedMotion then cancelSize(view);view.visual.Size=UDim2.fromScale(1,1)
		elseif entry.new then
			-- Only newly visible nodes receive an entry scale. Visible questions
			-- grow from their current presentation instead of collapsing to zero.
			cancelSize(view)
			local scale=if opening then MOTION.OpenScale else MOTION.FrontierEntryScale
			view.visual.Size=UDim2.fromScale(scale,scale)
			self:SizeNode(view,self:RestScale(view),if opening then MOTION.OpenSeconds else MOTION.FrontierSeconds,delay,function()
				view.revealing=false;self:RestNode(view)
			end)
			-- Pointer/focus changes must not cut the stagger short. A deliberate
			-- press can still interrupt it through the same size-tween owner.
			view.revealing=true
			if opening then
				local tween=view.sizeTween
				local function playPop()
					if tween.PlaybackState~=Enum.PlaybackState.Playing then return end
					if view.revealSoundConnection then view.revealSoundConnection:Disconnect();view.revealSoundConnection=nil end
					if self.alive and self.root.Visible and view.button.Visible and not self.app.reducedMotion and view.sizeTween==tween then
						self.app.audio:Play("SkillTreeNodePop",nil,{noFallback=true,cooldown=0,maxVoices=4,maxDuration=.35})
					end
				end
				-- Follow the actual tween start, including its stagger delay.
				view.revealSoundConnection=tween:GetPropertyChangedSignal("PlaybackState"):Connect(playPop)
				playPop()
			end
		else self:PulseNode(view,MOTION.FrontierScale,delay) end
	end
	self.opening=false
end

function Browser:StopProgress(owner)
	cancelTween(owner,"progressTween")
	owner.progressJob,owner.progressFinish=nil,nil
end

function Browser:UpdateProgress(owner,fill,job)
	local now=self:Now()
	local ratio=math.clamp((now-job.startedAt)/math.max(1,job.finishAt-job.startedAt),0,1)
	if self.app.reducedMotion then self:StopProgress(owner);fill.Size=UDim2.fromScale(ratio,1);return end
	if owner.progressJob==job.id and owner.progressFinish==job.finishAt then return end
	self:StopProgress(owner)
	owner.progressJob,owner.progressFinish=job.id,job.finishAt
	fill.Size=UDim2.fromScale(ratio,1)
	local remaining=math.max(0,job.finishAt-now)
	if remaining==0 then fill.Size=UDim2.fromScale(1,1);return end
	owner.progressTween=TweenService:Create(fill,TweenInfo.new(remaining,Enum.EasingStyle.Linear),{Size=UDim2.fromScale(1,1)})
	owner.progressTween:Play()
end

function Browser:ReleasePress(input,clearHover)
	local function release(view)
		if clearHover or view.pressInput==input then
			view.pressInput,view.pressed=nil,false
			if clearHover then view.hovered=false end
			self:RestNode(view)
		end
	end
	for _,view in self.nodes do release(view) end
	release(self.exitMotion)
end

function Browser:ResetNodeMotion(view)
	cancelSize(view);cancelTween(view,"tint");cancelTween(view,"flash")
	self:StopProgress(view)
	view.pulsing,view.hovered,view.focused,view.pressed=false,false,false,false
	view.pressInput=nil;view.visual.Size=UDim2.fromScale(1,1)
	if view.fillColor then view.fill.ImageColor3=view.fillColor end
	if view.rimColor then view.outline.ImageColor3=view.rimColor end
end

function Browser:Now()
	return self.serverTime+math.max(0,os.clock()-self.receivedAt)
end

function Browser:Feedback(text,color,id)
	self.message.Text,self.message.TextColor3,self.message.Visible=text,color,true
	self.message.TextTransparency=0
	self.feedbackVersion=(self.feedbackVersion or 0)+1
	local version=self.feedbackVersion
	if color==RED then self.app.audio:Play("SkillTreeError",nil,{noFallback=true,voiceKey="ErrorNotification",cooldown=.25}) end
	if id then
		local view=self.nodes[id]
		cancelTween(view,"flash")
		if not self.app.reducedMotion then
			view.outline.ImageColor3=color
			view.flash=TweenService:Create(view.outline,TweenInfo.new(MOTION.FlashSeconds,Enum.EasingStyle.Quad),{ImageColor3=view.rimColor or WHITE})
			view.flash:Play()
		end
	end
	task.delay(2.2,function()
		if self.alive and version==self.feedbackVersion then self.message.Visible=false end
	end)
end

function Browser:Celebrate(ids)
	local names={}
	for index,id in ids do
		if index>MOTION.CompletionLimit then break end
		table.insert(names,Catalog.Nodes[id].name)
		self:PulseNode(self.nodes[id],nil,(index-1)*MOTION.CompletionStaggerSeconds)
	end
	local more=if #ids>#names then " +"..(#ids-#names).." more" else ""
	self:Feedback("Research complete: "..table.concat(names,", ")..more.."!",CYAN)
end

function Browser:Receive(state,result)
	if not state or not state.research then return end
	local oldSlots=self.data and self.data.effects.slots
	self.data,self.coins,self.cashOffers=state.research,state.coins,state.boardUpgrades or {}
	if oldSlots and self.data.effects.slots>oldSlots then
		self.app.audio:Play("SkillTreeResearchSlotAdded",nil,{noFallback=true})
	end
	-- Integer server snapshots must not rewind the fractional client clock.
	self.serverTime=if self.receivedAt>0 then math.max(self:Now(),state.research.serverTime) else state.research.serverTime
	self.receivedAt=os.clock()
	local recap=state.research.recap or {}
	local completedRecap
	if #recap>0 and not self.acknowledging then
		self.acknowledging=true
		self.app.audio:Play("SkillTreeResearchCompleted",nil,{noFallback=true})
		local names={};for _,id in recap do table.insert(names,Catalog.Nodes[id].name) end
		if self.root.Visible then completedRecap=recap else self.app:Notify("Research complete: "..table.concat(names,", "),true) end
		self.app:Request("AcknowledgeResearch")
	elseif #recap==0 then self.acknowledging=false end
	local attempted=self.pending and self.pending.nodeId
	if self.pending and (self.data.revision~=self.pending.revision or os.clock()-self.pending.at>1) then self.pending=nil end
	local cashRequest=result and result.action=="CashUpgrade" and self.cashRequests[result.id]
	if cashRequest then
		self.cashRequests[result.id]=nil
		if result.ok then self.app.audio:Play("SkillTreePurchase",nil,{noFallback=true}) end
		if self.cashPending[cashRequest.key]==result.id then self.cashPending[cashRequest.key]=nil end
	end
	if result and result.ok and result.action=="StartResearch" then
		self.app.audio:Play("SkillTreeResearchStarted",nil,{noFallback=true})
	end
	if self.root.Visible then
		self.revealOrigin=if cashRequest and result.ok then cashRequest.nodeId elseif completedRecap then completedRecap[1] else nil
		self:Render();self.revealOrigin=nil
		if completedRecap then self:Celebrate(completedRecap) end
	end
	if cashRequest and self.root.Visible then
		local id=cashRequest.nodeId
		local offer=self.cashOffers[cashRequest.key]
		local text=if result.ok and offer then displayNodes[id].name..": "..cashRequest.currentText.." → "..offer.currentText else result.message or "Upgrade changed. Try again."
		self:Feedback(text,if result.ok then CYAN else RED,id)
		if result.ok then self:PulseNode(self.nodes[id]) end
		return true
	end
	local handled=self.root.Visible and result and (result.action=="StartResearch" or result.action=="CancelResearch" or result.action=="PinResearch")
	if handled and (not result.ok or result.action~="StartResearch") then
		self:Feedback(result.message or "Research changed. Try again.",if result.ok then CYAN else RED,if not result.ok then attempted else nil)
	end
	return handled==true
end

function Browser:Render()
	local data=self.data;if not data then return end
	local known={}
	for _,id in Catalog.Order do
		local node=Catalog.Nodes[id]
		known[id]=data.completed[id] or Rules.Job(data,id)~=nil or (node.prerequisite and (data.completed[node.prerequisite] or Rules.Job(data,node.prerequisite)~=nil)) or false
	end
	local reveals={}
	for _,id in Catalog.Order do
		local node,view=Catalog.Nodes[id],self.nodes[id]
		local offer=data.offers[id];local state=offer.status
		local visible=known[id] or (node.prerequisite and known[node.prerequisite]) or false
		local hidden=not known[id]
		local owned,active=state=="Completed",state=="Researching"
		local preview=state=="Locked" and not hidden
		local rim=if owned then Color3.fromRGB(179,255,155) elseif active then Color3.fromRGB(170,255,255) elseif preview then Color3.fromRGB(34,40,37) elseif hidden then MUTED else WHITE
		view.rimColor=rim
		if view.lastState~=state or view.lastHidden~=hidden then
			cancelTween(view,"flash")
			view.outline.ImageColor3=rim
			view.fill.Image=if owned or active then Assets.hexMask else Assets.hexFill
			local color=if owned then GREEN elseif active then CYAN elseif preview then Color3.fromRGB(62,62,62) else Color3.fromRGB(164,164,164)
			view.fillColor=color
			cancelTween(view,"tint")
			if view.button.Visible and view.lastState and not self.app.reducedMotion then
				view.tint=TweenService:Create(view.fill,TweenInfo.new(MOTION.TintSeconds,Enum.EasingStyle.Sine),{ImageColor3=color});view.tint:Play()
			else view.fill.ImageColor3=color end
			view.gradient.Enabled=owned or active
		end
		for i,halo in view.halos do
			halo.ImageColor3=if owned then GREEN elseif active then CYAN else WHITE
			halo.ImageTransparency=if preview then 1 elseif hidden then .99 else 1-(.025+i*.009)
		end
		view.icon.Visible,view.title.Visible,view.hidden.Visible=not hidden,not hidden,hidden
		view.icon.ImageTransparency,view.title.TextTransparency=if preview then .83 else 0,if preview then .77 else 0
		view.title.TextOutline.Transparency=if preview then .8 else 0
		view.cost.Visible=not hidden and not owned and not active and not preview
		view.price.Text=priceText(offer.price)
		view.price.TextColor3=if state=="Unaffordable" then RED else GREEN
		view.bar.Visible=active
		if not active then self:StopProgress(view) end
		view.icon.Position=UDim2.fromScale(.20,if active then .115 else .14)
		view.icon.Size=UDim2.fromScale(.60,if active then .48 else .52)
		view.title.Position=UDim2.fromScale(.025,if active then .615 else .665)
		view.title.Size=UDim2.fromScale(.95,if active then .105 else .12)
		if visible and (not view.button.Visible or view.lastHidden and not hidden) then table.insert(reveals,{id=id,new=not view.button.Visible}) end
		view.button.Visible,view.button.Selectable=visible,visible and not hidden
		view.lastState,view.lastHidden,view.kind=state,hidden,if hidden then "Hidden" else state
		view.button:SetAttribute("ResearchState",view.kind)
	end
	self:RenderCash(reveals)
	self:RevealNodes(reveals)
	for id,link in self.links do
		local view=self.nodes[id]
		link.line.Visible=view.button.Visible and self.nodes[link.parentId].button.Visible
		local completed=view.kind=="Completed"
		link.line.BackgroundColor3=if completed then GREEN else Color3.fromRGB(51,58,54)
		link.line.BackgroundTransparency=if completed then .72 else .35
	end
	self.cash.Text=Theme.Money(self.coins or 0).."$"
	self.researchers.Text="Researchers: "..#data.jobs.."/"..data.effects.slots
	self:Step()
end

function Browser:RenderCash(reveals)
	local ownReveals=not reveals
	reveals=reveals or {}
	for _,id in CashNodes.Order do
		local node,view=CashNodes.Nodes[id],self.nodes[id]
		local offer=self.cashOffers and self.cashOffers[node.upgradeKey]
		local completed=if offer then CashNodes.Completed(node.upgradeKey,offer) else 0
		local owned,nextTier=node.tier<=completed,node.tier==completed+1
		local visible=node.tier<=completed+2
		local hidden=not owned and not nextTier
		local state=if owned then "Completed" elseif hidden then "Hidden" else cashStatus(offer,self.coins or 0)
		local waiting=nextTier and self.cashPending[node.upgradeKey]~=nil
		local unavailable=state=="Unavailable"
		local rim=if owned then Color3.fromRGB(179,255,155) elseif hidden or unavailable then MUTED else WHITE
		view.rimColor=rim
		if view.lastState~=state then
			cancelTween(view,"flash")
			view.outline.ImageColor3=rim
			view.fill.Image=if owned then Assets.hexMask else Assets.hexFill
			local color=if owned then GREEN elseif unavailable then Color3.fromRGB(62,62,62) else Color3.fromRGB(164,164,164)
			view.fillColor=color
			cancelTween(view,"tint")
			if view.button.Visible and view.lastState and not self.app.reducedMotion then
				view.tint=TweenService:Create(view.fill,TweenInfo.new(MOTION.TintSeconds,Enum.EasingStyle.Sine),{ImageColor3=color});view.tint:Play()
			else view.fill.ImageColor3=color end
			view.gradient.Enabled=owned
		end
		for i,halo in view.halos do
			halo.ImageColor3=if owned then GREEN else WHITE
			halo.ImageTransparency=if unavailable then 1 elseif hidden then .99 else 1-(.025+i*.009)
		end
		view.icon.Visible,view.title.Visible,view.hidden.Visible=not hidden,not hidden,hidden
		view.icon.ImageTransparency,view.title.TextTransparency=if unavailable then .65 else 0,if unavailable then .35 else 0
		view.title.TextOutline.Transparency=if unavailable then .35 else 0
		view.bar.Visible=false
		view.level.Visible,view.change.Visible=nextTier,nextTier
		view.icon.Position=UDim2.fromScale(.20,if nextTier then .16 else .14)
		view.icon.Size=UDim2.fromScale(.60,if nextTier then .39 else .52)
		view.title.Position=UDim2.fromScale(.025,if nextTier then .555 else .665)
		view.title.Size=UDim2.fromScale(.95,if nextTier then .105 else .12)
		view.level.Text=if nextTier and offer and offer.ready then "Instant" else ""
		view.change.Text=if not offer or not offer.ready then "Loading…" elseif offer.nextText and not unavailable then offer.currentText.." → "..offer.nextText else offer.currentText
		view.cost.Visible=nextTier
		view.cashIcon.Visible=nextTier and state~="Loading" and not unavailable and not waiting
		view.price.Position=UDim2.fromScale(if view.cashIcon.Visible then .28 else 0,0)
		view.price.Size=UDim2.fromScale(if view.cashIcon.Visible then .72 else 1,1)
		view.price.TextXAlignment=if view.cashIcon.Visible then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
		view.price.Text=if waiting then "…" elseif state=="Loading" then "Loading" elseif unavailable then "No space" else priceText(if nextTier and offer then offer.price or node.price else node.price)
		view.price.TextColor3=if state=="Unaffordable" or unavailable then RED elseif waiting then CYAN else GREEN
		if visible and (not view.button.Visible or view.lastHidden and not hidden) then table.insert(reveals,{id=id,new=not view.button.Visible}) end
		view.button.Visible,view.button.Selectable=visible,visible and not hidden
		view.lastState,view.lastHidden,view.kind=state,hidden,state
		view.button:SetAttribute("UpgradeKey",node.upgradeKey)
		view.button:SetAttribute("CashUpgradeTier",node.tier)
		view.button:SetAttribute("CashUpgradeState",state)
	end
	if ownReveals then self:RevealNodes(reveals) end
end

function Browser:Step()
	if not self.data then return end
	local reduced=self.app.reducedMotion==true
	if reduced~=self.motionReduced then
		self.motionReduced=reduced
		if reduced then
			for _,view in self.nodes do self:ResetNodeMotion(view) end
			self:ResetNodeMotion(self.exitMotion);self:StopProgress(self.tipMotion)
		end
	end
	for _,job in self.data.jobs do
		local view=self.nodes[job.nodeId]
		view.timer.Text=timeText(job.finishAt-self:Now())
		self:UpdateProgress(view,view.progress,job)
	end
	if self.selected then self:RenderTooltip() end
end

function Browser:Select(id,persistent)
	if not self.data or not self.nodes[id] then return end
	local view=self.nodes[id]
	if not view.button.Visible or view.kind=="Hidden" then
		if persistent then
			local prerequisite=displayNodes[id].prerequisite
			while prerequisite and (not self.nodes[prerequisite].button.Visible or self.nodes[prerequisite].kind=="Hidden") do prerequisite=displayNodes[prerequisite].prerequisite end
			if prerequisite then self:Center(prerequisite);self:Select(prerequisite,true);return end
		end
		self:DismissTooltip();return
	end
	if self.selected~=id then self.confirmCancel=nil;self.options.Visible=false;self:StopProgress(self.tipMotion) end
	self.selected,self.persistent=id,persistent
	self.tip.Visible=true
	self:RenderTooltip()
end

function Browser:DismissTooltip()
	self:StopProgress(self.tipMotion)
	self.selected,self.persistent,self.confirmCancel=nil,false,nil
	self.tip.Visible,self.options.Visible=false,false
end

function Browser:PlaceTooltip()
	if not self.selected then return end
	local rootSize,origin=self.root.AbsoluteSize,self.root.AbsolutePosition
	if rootSize.X<=0 or rootSize.Y<=0 then return end
	local button=self.nodes[self.selected].button
	local at
	if not self.persistent then
		at=UserInputService:GetMouseLocation()-GuiService:GetGuiInset()-origin
	else at=button.AbsolutePosition-origin+button.AbsoluteSize*Vector2.new(.75,.55) end
	local tipSize=self.tip.AbsoluteSize
	local margin=rootSize.Y*.012
	local x,y=at.X+margin,at.Y+margin
	if x+tipSize.X>rootSize.X-margin then x=at.X-tipSize.X-margin end
	if y+tipSize.Y>rootSize.Y*.88 then y=at.Y-tipSize.Y-margin end
	x=math.clamp(x,margin,math.max(margin,rootSize.X-tipSize.X-margin))
	y=math.clamp(y,margin,math.max(margin,rootSize.Y*.88-tipSize.Y))
	self.tip.Position=UDim2.fromScale(x/rootSize.X,y/rootSize.Y)
	local osize=self.options.AbsoluteSize
	local oy=if y+tipSize.Y+osize.Y<rootSize.Y*.88 then y+tipSize.Y+margin else y-osize.Y-margin
	self.options.Position=UDim2.fromScale(x/rootSize.X,math.max(margin,oy)/rootSize.Y)
end

function Browser:RenderTooltip()
	local id,data=self.selected,self.data;if not id or not data then return end
	local node=displayNodes[id]
	local cashNode=CashNodes.Nodes[id]
	local offer=if cashNode then self.cashOffers[cashNode.upgradeKey] else data.offers[id]
	local completed=if cashNode and offer then CashNodes.Completed(cashNode.upgradeKey,offer) else 0
	local owned=cashNode and cashNode.tier<=completed
	local state=if owned then "Completed" elseif cashNode then cashStatus(offer,self.coins or 0) else offer.status
	local job=if cashNode then nil else Rules.Job(data,id)
	local effect=node.description
	if cashNode then
		local baseBenefit=if node.benefit:lower():find("base",1,true) then node.benefit else "Base upgrade: "..node.benefit
		if owned then effect=baseBenefit
		elseif not offer or not offer.ready then effect="Waiting for your flock to load."
		elseif state=="Unavailable" then
			effect=baseBenefit.." "..(if offer.requirement~="" then offer.requirement else "No additional upgrade space on this plot.")
		else
			local change=if offer.nextText then offer.currentText.." → "..offer.nextText else offer.currentText
			effect=change..". Instant upgrade. "..node.description
		end
	end
	local title,titleRows=wrap(node.name,22)
	local description,rows=wrap(effect,23)
	local footer=if cashNode then not owned and state~="Loading" and state~="Unavailable" else job~=nil or state~="Completed"
	local titleHeight=30*titleRows
	local height=18+titleHeight+12+rows*27+(if footer then 52 else 14)
	self.tip.Size=UDim2.fromScale(1,TOOLTIP_WIDTH*height/240)
	self.tipAspect.AspectRatio=240/height
	self.tip.UICorner.CornerRadius=UDim.new(10/height,0)
	self.tipTitle.Text=title;self.tipTitle.Position,self.tipTitle.Size=UDim2.fromScale(.055,10/height),UDim2.fromScale(.89,titleHeight/height)
	self.tipDivider.Position,self.tipDivider.Size=UDim2.fromScale(.085,(15+titleHeight)/height),UDim2.fromScale(.83,1/height)
	self.tipEffect.Text=description;self.tipEffect.Position,self.tipEffect.Size=UDim2.fromScale(.06,(24+titleHeight)/height),UDim2.fromScale(.88,rows*27/height)
	self.tipCost.Position,self.tipCost.Size=UDim2.fromScale(.22,(height-44)/height),UDim2.fromScale(.62,34/height)
	self.tipPrice.Text=if offer and offer.price then priceText(offer.price) else "";self.tipPrice.TextColor3=if state=="Unaffordable" or state=="Unavailable" then RED else GREEN
	self.tipCost.Visible,self.tipBar.Visible=footer and not job,job~=nil
	self.tipBar.Position,self.tipBar.Size=UDim2.fromScale(.065,(height-40)/height),UDim2.fromScale(.87,29/height)
	if job then
		self.tipTimer.Text=timeText(job.finishAt-self:Now())
		self:UpdateProgress(self.tipMotion,self.tipProgress,job)
	else self:StopProgress(self.tipMotion) end
	if cashNode then self.options.Visible=false;self:PlaceTooltip();return end
	self.goalCaption.Text=if data.pinned==id then "Clear goal" else "Pin goal"
	self.cancelAction.Visible=job~=nil
	self.options.Size=UDim2.fromScale(1,if job then .10 else .052)
	self.options.UIAspectRatioConstraint.AspectRatio=if job then TOOLTIP_WIDTH/.10 else TOOLTIP_WIDTH/.052
	self.goalAction.Size=UDim2.fromScale(.93,if job then .40 else .86)
	self.cancelCaption.Text=if job and self.confirmCancel==job.id then "Confirm · refund "..priceText(job.paid) else "Cancel research"
	self:PlaceTooltip()
end

function Browser:Activate()
	local id,data=self.selected,self.data;if not id or not data then return end
	self.app.audio:Play("Click")
	if CashNodes.Nodes[id] then self:PurchaseCash(id);return end
	local node,offer=Catalog.Nodes[id],data.offers[id]
	if Rules.Job(data,id) then return end
	if offer.status=="Completed" then
		if node.effect=="formations" then self.app:OpenPage("Formations")
		elseif node.effect=="operations" then self.app:OpenPage("Operations") end
	elseif offer.status=="Locked" then self:Feedback("Research "..Catalog.Nodes[node.prerequisite].name.." first!",RED,id)
	elseif offer.status=="Unaffordable" then self:Feedback("Not enough cash!",RED,id)
	elseif offer.status=="Available" then
		if #data.jobs>=data.effects.slots then self:Feedback("All researchers are busy!",RED,id);return end
		if self.pending and self.pending.revision==data.revision and os.clock()-self.pending.at<1 then return end
		self.pending={nodeId=id,revision=data.revision,at=os.clock()}
		self.app:Request("StartResearch",{nodeId=id,expectedRevision=data.revision,expectedPrice=offer.price,expectedDuration=offer.duration})
	end
end

function Browser:PurchaseCash(id)
	local node=CashNodes.Nodes[id];if not node then return end
	local key=node.upgradeKey
	if self.cashPending[key] then return end
	local offer=self.cashOffers and self.cashOffers[key]
	local completed=if offer then CashNodes.Completed(key,offer) else 0
	-- Old tier clicks inspect that earned benefit; only the exact next node buys.
	if node.tier~=completed+1 then return end
	local state=cashStatus(offer,self.coins or 0)
	if state~="Available" then
		local text=if state=="Loading" then "Wait for your flock to load." elseif state=="Unavailable" then (if offer.requirement~="" then offer.requirement else "No additional upgrade space on this plot.") else "Not enough cash!"
		self:Feedback(text,RED,id);return
	end
	local requestId=self.app:Request("CashUpgrade",{upgradeKey=key,expectedLevel=offer.level,expectedPrice=offer.price})
	if not requestId then return end
	self.cashPending[key]=requestId
	self.cashRequests[requestId]={key=key,nodeId=id,currentText=offer.currentText}
	self:RenderCash()
	-- Unlock the control after a lost reply; its server quote still rejects repeats.
	task.delay(8,function()
		if self.alive and self.cashPending[key]==requestId then
			self.cashPending[key]=nil
			if self.root.Visible then self:RenderCash() end
		end
	end)
	task.delay(30,function() if self.alive then self.cashRequests[requestId]=nil end end)
end

function Browser:ShowOptions(id)
	if not self.root.Visible then return end
	if CashNodes.Nodes[id] then self:Select(id,true);return end
	self:Select(id,true)
	if self.selected~=id then return end
	self.options.Visible=true
	if UserInputService.PreferredInput==Enum.PreferredInput.Gamepad then GuiService.SelectedObject=self.goalAction end
	self:PlaceTooltip()
end

function Browser:CancelSelected()
	local data,id=self.data,self.selected;if not data or not id then return end
	local job=Rules.Job(data,id);if not job then self.options.Visible=false;return end
	if self.confirmCancel~=job.id then self.confirmCancel=job.id;self:RenderTooltip();return end
	self.app:Request("CancelResearch",{jobId=job.id,expectedRevision=data.revision})
	self.confirmCancel=nil;self.options.Visible=false
end

function Browser:Secondary()
	if self.selected and self.data and not CashNodes.Nodes[self.selected] then self.app:Request("PinResearch",{nodeId=if self.data.pinned==self.selected then nil else self.selected}) end
end

function Browser:Transform()
	-- Bound navigation by node positions so touch users cannot lose the map.
	local root=self.root.AbsoluteSize
	if root.X>0 and root.Y>0 then
		local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
		for _,id in displayOrder do
			if self.nodes[id].button.Visible then
				local p=point(displayNodes[id]);minX=math.min(minX,p.X);minY=math.min(minY,p.Y);maxX=math.max(maxX,p.X);maxY=math.max(maxY,p.Y)
			end
		end
		if minX==math.huge then return end
		local sx,sy=root.Y/root.X*1440/930*self.zoom,self.zoom
		self.pan=Vector2.new(math.clamp(self.pan.X,-.3-(maxX-.5)*sx,.3-(minX-.5)*sx),math.clamp(self.pan.Y,-.3-(maxY-.5)*sy,.3-(minY-.5)*sy))
	end
	self.map.Size=UDim2.fromScale(self.zoom*1440/930,self.zoom)
	self.map.Position=UDim2.fromScale(.5+self.pan.X,.5+self.pan.Y)
	self:PlaceTooltip()
end

function Browser:Center(id)
	local node=displayNodes[id or "Start"];if not node then return end
	local p=point(node)-Vector2.new(.5,.5)
	local root=self.root.AbsoluteSize
	-- Use the native height-dominant aspect projection, not a previous frame's
	-- AbsoluteSize immediately after zoom changes. This only changes the pan.
	if root.X>0 and root.Y>0 then self.pan=Vector2.new(-p.X*root.Y/root.X*(1440/930)*self.zoom,-p.Y*self.zoom) end
	self:Transform()
end

function Browser:Zoom(amount,at)
	local old=self.zoom
	local nextZoom=self.zoom*amount
	if nextZoom~=nextZoom or nextZoom==math.huge or amount<=0 then return end
	self.zoom=math.max(nextZoom,.65)
	local size=self.root.AbsoluteSize
	if at and size.X>0 and size.Y>0 then
		local p=at-self.root.AbsolutePosition
		local anchor=Vector2.new(p.X/size.X-.5,p.Y/size.Y-.5)
		self.pan=anchor+(self.pan-anchor)*(self.zoom/old)
	end
	self:Transform()
end

function Browser:Navigate(direction)
	local from=point(displayNodes[self.selected or "Start"])
	local best,score=nil,math.huge
	for _,id in displayOrder do
		local delta=point(displayNodes[id])-from
		local d=Vector2.new(delta.X*1440,delta.Y*930)
		if self.nodes[id].button.Visible and self.nodes[id].kind~="Hidden" and d.Magnitude>0 and d.Unit:Dot(direction)>.5 then
			local value=d.Magnitude/(d.Unit:Dot(direction)^3)
			if value<score then best,score=id,value end
		end
	end
	if best then self:Center(best);self:Select(best,true);GuiService.SelectedObject=self.nodes[best].button end
end

function Browser:BindInput()
	local function connect(signal,fn) table.insert(self.connections,signal:Connect(fn)) end
	local function moveDrag(input)
		local drag=self.drag;if not drag then return end
		local p=Vector2.new(input.Position.X,input.Position.Y);local delta=p-drag.at
		if delta.Magnitude>8 and not drag.moved then drag.moved=true;self:ReleasePress(nil,true);self:DismissTooltip() end
		if drag.moved then
			local size=self.root.AbsoluteSize
			self.pan=drag.pan+Vector2.new(delta.X/math.max(1,size.X),delta.Y/math.max(1,size.Y))
			self.suppressUntil=os.clock()+.3;self:Transform()
		end
	end
	connect(UserInputService.InputBegan,function(input)
		if not self.root.Visible then return end
		local mouse=input.UserInputType==Enum.UserInputType.MouseButton1
		if not mouse and input.UserInputType~=Enum.UserInputType.Touch then return end
		local p=Vector2.new(input.Position.X,input.Position.Y)
		if not inside(self.root,p) or inside(self.exit,p) or (self.options.Visible and inside(self.options,p)) then return end
		self.options.Visible=false
		if self.drag then self.drag=nil;self.suppressUntil=os.clock()+.4;return end
		self.drag={input=input,at=p,pan=self.pan,moved=false,mouse=mouse}
	end)
	connect(UserInputService.InputChanged,function(input)
		if not self.root.Visible then return end
		if input.UserInputType==Enum.UserInputType.MouseWheel then
			local inset=GuiService:GetGuiInset()
			self:Zoom(if input.Position.Z>0 then 1.12 else 1/1.12,UserInputService:GetMouseLocation()-inset);return
		end
		if input.UserInputType==Enum.UserInputType.MouseMovement and not self.drag then self:PlaceTooltip() end
		local drag=self.drag
		if not drag or not (input==drag.input or (drag.mouse and input.UserInputType==Enum.UserInputType.MouseMovement)) then return end
		moveDrag(input)
	end)
	connect(UserInputService.InputEnded,function(input)
		self:ReleasePress(input,false)
		if self.drag and input==self.drag.input then
			-- A quick drag can release before the final movement event is delivered.
			moveDrag(input)
			if self.drag.moved or self.drag.inspected then self.suppressUntil=os.clock()+.3 end
			self.drag=nil
		end
	end)
	connect(UserInputService.TouchPinch,function(positions,scale,_,state)
		if not self.root.Visible or #positions<2 then return end
		self.drag=nil;self:ReleasePress(nil,true);self.suppressUntil=os.clock()+.4
		if state==Enum.UserInputState.Begin then self.pinchScale=scale;return end
		if self.pinchScale and self.pinchScale>0 then self:Zoom(scale/self.pinchScale,(positions[1]+positions[2])/2) end
		self.pinchScale=if state==Enum.UserInputState.End then nil else scale
	end)
	connect(self.root:GetPropertyChangedSignal("AbsoluteSize"),function() self:PlaceTooltip() end)
end

function Browser:Focus()
	self:DismissTooltip()
	self.zoom=1
	self:Center("Start")
	if UserInputService.GamepadEnabled then self:Select("Start",true);GuiService.SelectedObject=self.nodes.Start.button end
end

function Browser:OpenCash(upgradeKey)
	self:Open()
	if upgradeKey and CashNodes.ByKey[upgradeKey] then
		local offer=self.cashOffers and self.cashOffers[upgradeKey]
		local id=CashNodes.NextId(upgradeKey,offer)
		if id then self:Center(id);self:Select(id,true) end
	end
end

function Browser:Open()
	if self.root.Visible then self:Focus();return end
	self.app.audio:Play("SkillTreeOpen",nil,{noFallback=true})
	self.app:ClosePanel()
	self.app.offlineCash:Dismiss(true)
	self.previousSelection=GuiService.SelectedObject
	self.previousInsets=self.app.gui.ScreenInsets
	self.previousSafeAreaCompatibility=self.app.gui.SafeAreaCompatibility
	-- Native safe-area extension keeps the backdrop full-screen and controls clear
	-- of phone corners, without a second ScreenGui or viewport sizing code.
	self.app.gui.SafeAreaCompatibility=Enum.SafeAreaCompatibility.FullscreenExtension
	self.app.gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets
	for _,view in self.nodes do view.button.Visible=false end
	self.opening=true
	self.root.Visible=true;self.app.hudLayer.Visible=false
	self:Receive(self.app.state)
	self:Focus()
	ContextActionService:BindActionAtPriority("ResearchNavigation",function(_,state,input)
		if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		local key=input.KeyCode
		if key==Enum.KeyCode.ButtonB or key==Enum.KeyCode.Escape then
			if self.options.Visible then self.options.Visible=false;GuiService.SelectedObject=self.nodes[self.selected].button else self:Close() end
		elseif key==Enum.KeyCode.ButtonA then
			if self.options.Visible then
				if GuiService.SelectedObject==self.cancelAction then self:CancelSelected() else self:Secondary();self.options.Visible=false end
			else
				local view=self.selected and self.nodes[self.selected]
				if view then
					view.pulsing=false
					self:SizeNode(view,MOTION.PressScale,MOTION.PressSeconds,0,function() self:RestNode(view) end)
				end
				self:Activate()
			end
		elseif self.options.Visible and (key==Enum.KeyCode.DPadDown or key==Enum.KeyCode.DPadUp) then
			GuiService.SelectedObject=if GuiService.SelectedObject==self.goalAction and self.cancelAction.Visible then self.cancelAction else self.goalAction
		elseif key==Enum.KeyCode.ButtonY then if self.selected then self:ShowOptions(self.selected) end
		elseif key==Enum.KeyCode.ButtonX or key==Enum.KeyCode.Home then self:Focus()
		elseif key==Enum.KeyCode.ButtonR1 then self:Zoom(1.12)
		elseif key==Enum.KeyCode.ButtonL1 then self:Zoom(1/1.12)
		else
			local directions={[Enum.KeyCode.DPadLeft]=Vector2.new(-1,0),[Enum.KeyCode.DPadRight]=Vector2.new(1,0),[Enum.KeyCode.DPadUp]=Vector2.new(0,-1),[Enum.KeyCode.DPadDown]=Vector2.new(0,1),
				[Enum.KeyCode.Left]=Vector2.new(-1,0),[Enum.KeyCode.Right]=Vector2.new(1,0),[Enum.KeyCode.Up]=Vector2.new(0,-1),[Enum.KeyCode.Down]=Vector2.new(0,1)}
			if directions[key] then self:Navigate(directions[key]) end
		end
		return Enum.ContextActionResult.Sink
	end,false,3500,Enum.KeyCode.ButtonB,Enum.KeyCode.ButtonA,Enum.KeyCode.ButtonY,Enum.KeyCode.Escape,Enum.KeyCode.ButtonX,Enum.KeyCode.Home,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1,
		Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown,Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Up,Enum.KeyCode.Down)
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=self.nodes[self.selected or "Start"].button end
end

function Browser:Close()
	if not self.root.Visible then return end
	self.app.audio:Play("SkillTreeClose",nil,{noFallback=true})
	self.root.Visible=false;self.app.hudLayer.Visible=true;self.drag=nil
	self.message.Visible=false;self.feedbackVersion=(self.feedbackVersion or 0)+1
	self.opening,self.revealOrigin,self.pinchScale=false,nil,nil
	for _,view in self.nodes do
		self:ResetNodeMotion(view)
		-- Re-render the stable saved state even if a tint was interrupted.
		view.lastState,view.lastHidden=nil,nil
	end
	self:ResetNodeMotion(self.exitMotion);self:StopProgress(self.tipMotion)
	if self.previousInsets then self.app.gui.ScreenInsets=self.previousInsets;self.previousInsets=nil end
	if self.previousSafeAreaCompatibility then self.app.gui.SafeAreaCompatibility=self.previousSafeAreaCompatibility;self.previousSafeAreaCompatibility=nil end
	self:DismissTooltip()
	ContextActionService:UnbindAction("ResearchNavigation")
	GuiService.SelectedObject=if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
end

function Browser:Destroy()
	self:Close();self.alive=false
	for _,connection in self.connections do connection:Disconnect() end
	self.root:Destroy()
end

return Browser
