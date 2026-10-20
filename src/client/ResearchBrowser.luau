--!strict
-- The full-screen Upgrades tree (October 20 overhaul, docs/team/UPGRADES_SCREEN.md):
-- a main map around Start, plus Tools, Player and Army subtrees opened from orange
-- Open hexes and left through a red Back hex. Graph geometry uses a native aspect
-- constraint; input changes only each map's pan/zoom, never the layout of individual
-- nodes. The server owns every status, price and badge (state.upgradeTree).
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local TweenService=game:GetService("TweenService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Theme=require(script.Parent.UITheme)
local Assets=require(script.Parent.ResearchAssets)
local View=require(script.Parent.CashUpgradeNodes)
local Browser={}
Browser.__index=Browser

-- Launch H1: while a limited event runs, its podium chance stays disclosed beside
-- the normal odds. Mirrors EventService.Active (server-owned); pass server time,
-- e.g. workspace:GetServerTimeNow(). Returns nil when no event is running.
local Config=require(Shared.Config)
local PetCatalog=require(Shared.PetCatalog)
local MONTHS={"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
function Browser.EventOdds(now:number):(string?,Color3?)
	local event=Config.Event
	if type(event)~="table" or event.Enabled~=true or type(now)~="number" then return nil,nil end
	if type(event.StartsAt)~="number" or type(event.EndsAt)~="number" or type(event.OfferChance)~="number" then return nil,nil end
	local definition=PetCatalog[event.Species]
	if not definition or not (event.OfferChance>0 and event.OfferChance<=1) or now<event.StartsAt or now>=event.EndsAt then return nil,nil end
	local ends=os.date("!*t",event.EndsAt)
	local text=string.format("%s (event): %s%% per podium · Limited until %s %d",
		definition.name,string.format("%g",event.OfferChance*100),MONTHS[ends.month],ends.day)
	return text,Theme.Rarities[definition.rarity] or Color3.fromRGB(255,255,255)
end
local WHITE=Color3.fromRGB(255,255,255)
local MUTED=Color3.fromRGB(172,172,172)
local RED=Color3.fromRGB(255,77,86)
-- October 20: affordable coin prices are gold, like every Coin amount.
local COIN=Theme.Colors.coins
-- October 20 overhaul: bought and maxed hexes use the bright Army green.
local GREEN=Color3.fromRGB(163,255,0)
local ALERT=Color3.fromRGB(235,45,45)
local LINK=Color3.fromRGB(70,76,72)
-- Each hex look: the art, its tint or vertical gradient, and the rim around it.
-- Unbought hexes are dark like the reference, with a grey rim so they read on the
-- black backdrop; "?" hexes are a lighter grey.
local LOOKS={
	owned={art="hexMask",gradient=ColorSequence.new(GREEN,Color3.fromRGB(0,211,0)),rim=Color3.fromRGB(14,84,0)},
	start={art="hexMask",gradient=Theme.ReferenceGradients.Upgrades,rim=Color3.fromRGB(0,72,112)},
	open={art="hexMask",gradient=Theme.ReferenceGradients.Base,rim=Color3.fromRGB(122,64,0)},
	back={art="hexMask",gradient=ColorSequence.new(Color3.fromRGB(255,102,84),Color3.fromRGB(243,36,59)),rim=Color3.fromRGB(112,10,22)},
	available={art="hexFill",rim=Color3.fromRGB(78,80,86)},
	unknown={art="hexMask",tint=Color3.fromRGB(86,88,92),rim=Color3.fromRGB(46,47,51)},
}
-- The free Egg Vacuum always counts as owned; price color alone marks unaffordable.
LOOKS.tool,LOOKS.unaffordable=LOOKS.owned,LOOKS.available
local TOOLTIP_WIDTH=.218
local NODE_SIZE=UDim2.fromScale(144/1440,164/930)
-- Presentation tuning only: seconds and relative scales, never purchase timing.
local MOTION={
	OpenScale=0,OpenSeconds=.24,OpenStaggerSeconds=.045,OpenWaveSeconds=.80,
	FrontierEntryScale=.88,FrontierSeconds=.18,FrontierWaveSeconds=.08,FrontierScale=1.025,
	HoverScale=1.025,PressScale=.96,PressSeconds=.055,SettleSeconds=.13,
	ConfirmScale=1.045,ConfirmRiseSeconds=.10,ConfirmSettleSeconds=.18,FlashSeconds=.35,
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
-- October 20 (owner): phones buy on tap and never show the card; a mouse hover or
-- gamepad focus does.
local function touching()
	return UserInputService:GetLastInputType()==Enum.UserInputType.Touch
end
-- Luck odds (docs/team/LUCK_WINDOW.md) from the server's upgradeTree.luck block:
-- Epic+ now → next, or the strongest band once Epic+ rounds to the same value.
local function luckText(luck,withNext)
	if type(luck)~="table" or type(luck.epicPlusChance)~="number" then return nil end
	withNext=withNext and type(luck.nextEpicPlusChance)=="number"
	local top=withNext and type(luck.topBandChance)=="number" and type(luck.nextTopBandChance)=="number"
		and string.format("%.1f",luck.epicPlusChance*100)==string.format("%.1f",luck.nextEpicPlusChance*100)
	local now=if top then luck.topBandChance else luck.epicPlusChance
	local after=if top then luck.nextTopBandChance else luck.nextEpicPlusChance
	local text=(if top then "Strongest chickens: " else "Epic+ per chicken: ")..string.format("%.2f%%",now*100)
	if withNext then text..=" → "..string.format("%.2f%%",after*100) end
	text..=". Bonuses included."
	if type(luck.windowText)=="string" then text..=" Favored now: "..luck.windowText.."." end
	if withNext and type(luck.nextWindowText)=="string" then text..=" Next: "..luck.nextWindowText.."." end
	return text
end

function Browser.new(app,parent)
	local self=setmetatable({app=app,nodes={},links={},layers={},connections={},zoom=1,pan=Vector2.zero,alive=true,
		category="Main",saved={},coins=0,pending={},requests={}},Browser)
	local root=Instance.new("TextButton")
	root.Name,root.Text,root.Size="Research","",UDim2.fromScale(1,1)
	root:SetAttribute("HoverAudioCue","SkillTreeHover")
	-- October 20 (owner): the tree keeps its solid black backdrop.
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
	-- One layer per category map; only the open one shows. They share coordinates,
	-- so every category's center hex sits where Start does.
	for _,category in View.Categories do
		local layer=Theme.Container(map,category)
		layer.Visible=category=="Main"
		self.layers[category]=layer
		self:BuildLinks(category,layer)
		for _,id in View.Order[category] do self:BuildNode(id,layer) end
	end
	-- Soft dark bands so the title, balance and Exit never sit on top of nodes.
	for _,spec in {{"TopFade",0,.15,90,0},{"BottomFade",.8,.2,-90,1}} do
		local fade=Theme.Frame(root,spec[1],UDim2.fromScale(1,spec[3]),Color3.new(0,0,0))
		fade.Position,fade.ZIndex,fade.Active=UDim2.fromScale(0,spec[2]),4,false
		local gradient=Instance.new("UIGradient")
		gradient.Rotation=spec[4]
		gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.55,.15),NumberSequenceKeypoint.new(1,1)})
		gradient.Parent=fade
	end
	-- Screen title in the shared header lettering; a subtree adds its name.
	local title=Theme.Display(root,"Title","Upgrades",50,WHITE)
	title.Position,title.Size,title.ZIndex=UDim2.fromScale(.3,.01),UDim2.fromScale(.4,.06),5
	title.TextScaled,title.TextXAlignment=true,Enum.TextXAlignment.Center
	title.TextFace.TextOutline.Color,title.TextFace.TextOutline.Thickness=Theme.Arcade.border,.055
	title.TextShadow.TextTransparency,title.TextShadow.TextOutline.Enabled=.35,false
	self.title=title
	local money=Theme.Container(root,"ResearchBalance")
	money.AnchorPoint,money.Position,money.Size=Vector2.new(0,1),UDim2.fromScale(.012,.975),UDim2.fromScale(.26,.07)
	Theme.Aspect(money,5.4);money.ZIndex=5
	Theme.Image(money,"CashIcon",Assets.cash,UDim2.fromScale(.19,1))
	self.cash=label(money,"Cash","0",.21,0,.79,1,Theme.Colors.coins);self.cash.TextXAlignment=Enum.TextXAlignment.Left
	-- The shared square close X (Theme.HeaderClose's button and accent), in the
	-- top-right corner like every other menu; large enough for a thumb on phones.
	self.exit=Theme.ActionButton(root,"Exit","X",function() self.app.audio:Play("Click");self:Close() end,Theme.ActionColors.danger)
	Theme.ApplyReferenceAccent(self.exit,ColorSequence.new(Color3.fromRGB(255,102,84),Color3.fromRGB(243,36,59)))
	self.exit.AnchorPoint,self.exit.Position,self.exit.Size,self.exit.ZIndex=Vector2.new(1,0),UDim2.fromScale(.985,.012),UDim2.fromScale(.14,.105),6
	Theme.Aspect(self.exit,120/115)
	self.message=label(root,"Feedback","",.15,.17,.70,.055,GREEN)
	self.message.ZIndex,self.message.Visible=12,false

	self:BuildTooltip()
	-- Tapping empty map closes a gamepad card (nodes sink their own input).
	root.Activated:Connect(function()
		if self.persistent and os.clock()>=(self.suppressUntil or 0) then self:DismissTooltip() end
	end)
	self:BindInput()
	return self
end

-- Adjacent hexes already read as a path. Bridge only longer prerequisite gaps,
-- using the same map coordinates so native aspect/pan/zoom owns sizing.
function Browser:BuildLinks(category,layer)
	for _,id in View.Order[category] do
		local node=View.Nodes[id]
		local parentNode=node.prerequisite and View.Nodes[node.prerequisite]
		if parentNode and parentNode.category==category then
			local dq,dr=node.q-parentNode.q,node.r-parentNode.r
			if math.max(math.abs(dq),math.abs(dr),math.abs(dq+dr))>1 then
				local from,to=point(parentNode),point(node)
				local delta=Vector2.new((to.X-from.X)*1440,(to.Y-from.Y)*930)
				local line=Theme.Frame(layer,"Link_"..id,UDim2.fromScale(delta.Magnitude/1440,4/930),LINK)
				line.AnchorPoint,line.Position=Vector2.new(.5,.5),UDim2.fromScale((from.X+to.X)/2,(from.Y+to.Y)/2)
				line.Rotation=math.deg(math.atan2(delta.Y,delta.X))
				line.BackgroundTransparency,line.Visible,line.ZIndex=.35,false,1
				self.links[id]={line=line,parentId=node.prerequisite}
			end
		end
	end
end

function Browser:BuildNode(id,layer)
	local node=View.Nodes[id];local p=point(node)
	local kind=node.kind
	local button=Instance.new("ImageButton")
	button.Name,button.Image,button.BackgroundTransparency=id,"",1
	button.Size,button.AnchorPoint,button.Position=NODE_SIZE,Vector2.new(.5,.5),UDim2.fromScale(p.X,p.Y)
	button.AutoButtonColor,button.Visible,button.Parent=false,false,layer
	Theme.Aspect(button,144/164)
	local visual=Theme.Container(button,"Visual")
	visual.AnchorPoint,visual.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
	local outline=Theme.Image(visual,"Outline",Assets.hexMask,UDim2.fromScale(1,1));outline.ZIndex=2
	local fill=Theme.Image(visual,"Fill",Assets.hexFill,UDim2.fromScale(.92,.92),UDim2.fromScale(.04,.04));fill.ZIndex=3
	local gradient=Instance.new("UIGradient")
	gradient.Rotation,gradient.Enabled,gradient.Parent=90,false,fill
	local icon=Theme.Image(visual,"Icon",Assets.upgrades[node.icon] or Assets.index,UDim2.fromScale(.62,.5),UDim2.fromScale(.19,.1));icon.ZIndex=4
	-- The tier is live text over the icon's lower right, never part of the art.
	local numeral=label(visual,"Tier",View.Numeral(node) or "",.5,.36,.34,.26)
	numeral.TextXAlignment,numeral.TextWrapped,numeral.ZIndex=Enum.TextXAlignment.Right,false,6
	numeral.TextOutline.Thickness=.09
	local title=label(visual,"Title",node.name,-.12,.585,1.24,.13)
	title.TextWrapped,title.ZIndex=false,6
	-- "Open" under an Open hex's name; the category's name under Back.
	local caption=label(visual,"Caption","",.1,.69,.8,.16,if kind=="open" then Color3.fromRGB(255,240,90) else WHITE)
	caption.TextWrapped,caption.ZIndex,caption.Visible=false,6,kind=="open" or kind=="back"
	local cost=Theme.Container(visual,"Cost");cost.Position,cost.Size,cost.ZIndex=UDim2.fromScale(.17,.725),UDim2.fromScale(.66,.13),5
	local cashIcon=Theme.Image(cost,"CashIcon",Assets.cash,UDim2.fromScale(.27,1));cashIcon.ZIndex=5
	local price=label(cost,"Price","",.29,0,.71,1,COIN);price.TextXAlignment,price.TextWrapped,price.ZIndex=Enum.TextXAlignment.Left,false,5
	-- Undiscovered tiles stay quiet so the reachable ones lead the eye.
	local hidden=label(visual,"Hidden","?",.22,.22,.56,.5,Color3.fromRGB(150,152,156));hidden.ZIndex=5
	-- Red circle at the top right: "!" on a hex you can buy now, a count on Open hexes.
	local badge=Theme.Frame(visual,"Alert",UDim2.fromScale(.3,.3),ALERT)
	badge.AnchorPoint,badge.Position,badge.ZIndex,badge.Visible=Vector2.new(.5,.5),UDim2.fromScale(.82,.17),7,false
	Theme.Aspect(badge,1);round(badge,.5)
	-- Round joins: a Miter stroke draws a square box around a circle.
	Theme.Stroke(badge,Color3.new(0,0,0),2).LineJoinMode=Enum.LineJoinMode.Round
	local badgeText=label(badge,"Text","!",.1,.1,.8,.8);badgeText.TextWrapped,badgeText.ZIndex=false,8
	if kind=="start" then
		icon.Position,icon.Size=UDim2.fromScale(.17,.08),UDim2.fromScale(.66,.54)
		title.Position,title.Size=UDim2.fromScale(.02,.62),UDim2.fromScale(.96,.16)
	elseif kind=="open" or kind=="back" then
		icon.Position,icon.Size=UDim2.fromScale(.2,.07),UDim2.fromScale(.6,.44)
		title.Position,title.Size=UDim2.fromScale(.02,.5),UDim2.fromScale(.96,.16)
		local category=if kind=="back" then View.OpenNode(node.category) else nil
		caption.Text=if kind=="open" then "Open" elseif category then category.name else ""
		-- Without its arrow icon, Back's words fill the hex instead.
		if icon.Image=="" then
			title.Position,title.Size=UDim2.fromScale(.1,.24),UDim2.fromScale(.8,.22)
			caption.Position,caption.Size=UDim2.fromScale(.1,.5),UDim2.fromScale(.8,.2)
		end
	end
	self.nodes[id]={id=id,button=button,visual=visual,outline=outline,fill=fill,gradient=gradient,icon=icon,numeral=numeral,
		title=title,caption=caption,cost=cost,cashIcon=cashIcon,price=price,hidden=hidden,badge=badge,badgeText=badgeText}
	-- A click or tap acts on the hex at once: buy, open a subtree or go back.
	button.Activated:Connect(function()
		if not self.root.Visible or os.clock()<(self.suppressUntil or 0) then return end
		self:Press(id)
	end)
	button.MouseEnter:Connect(function()
		if self.pinchScale or (self.drag and self.drag.moved) or touching() then return end
		local view=self.nodes[id];view.hovered=true;self:RestNode(view)
		if self.root.Visible and not self.persistent and not self.drag then self:Select(id,false) end
	end)
	button.MouseLeave:Connect(function()
		local view=self.nodes[id];view.hovered=false;view.pressed=false;self:RestNode(view)
		if not self.persistent and self.selected==id then self:DismissTooltip() end
	end)
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
	end)
end

function Browser:BuildTooltip()
	local tip=Theme.Frame(self.root,"NodeTooltip",UDim2.fromScale(1,TOOLTIP_WIDTH),Color3.fromRGB(27,27,27))
	Theme.Aspect(tip,1)
	local aspect=tip.UIAspectRatioConstraint
	-- A constant height-relative width keeps this card independent of map zoom.
	aspect.AspectType,aspect.DominantAxis=Enum.AspectType.ScaleWithParentSize,Enum.DominantAxis.Height
	round(tip,.045);Theme.Stroke(tip,Color3.fromRGB(206,206,206),1.5).LineJoinMode=Enum.LineJoinMode.Round
	tip.Visible,tip.Active,tip.ZIndex=false,false,8
	self.tip,self.tipAspect=tip,aspect
	self.tipTitle=label(tip,"Name","",.055,.06,.89,.18);self.tipTitle.ZIndex=9
	self.tipTitle.TextOutline.Enabled=false
	self.tipDivider=Theme.Frame(tip,"Divider",UDim2.fromScale(.83,.005),Color3.fromRGB(77,77,77))
	self.tipDivider.Position,self.tipDivider.ZIndex=UDim2.fromScale(.085,.27),9
	self.tipEffect=label(tip,"Effect","",.06,.31,.88,.39,MUTED);self.tipEffect.ZIndex=9;self.tipEffect.TextOutline.Enabled=false
	-- Current → next value in green, like the reference's highlighted number.
	self.tipChange=label(tip,"Change","",.06,.5,.88,.1,GREEN);self.tipChange.ZIndex=9;self.tipChange.TextOutline.Enabled=false
	self.tipCost=Theme.Container(tip,"Cost");self.tipCost.ZIndex=9
	self.tipCash=Theme.Image(self.tipCost,"CashIcon",Assets.cash,UDim2.fromScale(.25,1));self.tipCash.ZIndex=10
	self.tipPrice=label(self.tipCost,"Price","",.27,0,.73,1,COIN);self.tipPrice.TextXAlignment=Enum.TextXAlignment.Left;self.tipPrice.ZIndex=10
	self.tipFooter=label(tip,"Resets","Resets on Rebirth",.06,.9,.88,.08,MUTED);self.tipFooter.ZIndex=9;self.tipFooter.TextOutline.Enabled=false
end

function Browser:RestScale(view)
	if self.app.reducedMotion or view.look=="unknown" then return 1 end
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
	local root=View.Roots[self.category]
	local origin=point(View.Nodes[if opening then root else self.revealOrigin or root])
	table.sort(reveals,function(a,b)
		local da,db=(point(View.Nodes[a.id])-origin).Magnitude,(point(View.Nodes[b.id])-origin).Magnitude
		return if da==db then a.id<b.id else da<db
	end)
	local far=(point(View.Nodes[reveals[#reveals].id])-origin).Magnitude
	local stagger=math.min(MOTION.OpenStaggerSeconds,MOTION.OpenWaveSeconds/math.max(1,#reveals-1))
	for index,entry in reveals do
		local view=self.nodes[entry.id]
		local distance=(point(View.Nodes[entry.id])-origin).Magnitude
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

function Browser:ReleasePress(input,clearHover)
	local function release(view)
		if clearHover or view.pressInput==input then
			view.pressInput,view.pressed=nil,false
			if clearHover then view.hovered=false end
			self:RestNode(view)
		end
	end
	for _,view in self.nodes do release(view) end
end

function Browser:ResetNodeMotion(view)
	cancelSize(view);cancelTween(view,"flash")
	view.pulsing,view.hovered,view.focused,view.pressed=false,false,false,false
	view.pressInput=nil;view.visual.Size=UDim2.fromScale(1,1)
	if view.rimColor then view.outline.ImageColor3=view.rimColor end
end

-- Server clock for older callers (ResearchExtras' Rally countdown).
function Browser:Now()
	return workspace:GetServerTimeNow()
end

function Browser:Feedback(text,color,id)
	self.message.Text,self.message.TextColor3,self.message.Visible=text,color,true
	self.message.TextTransparency=0
	self.feedbackVersion=(self.feedbackVersion or 0)+1
	local version=self.feedbackVersion
	if color==RED then self.app.audio:Play("SkillTreeError",nil,{noFallback=true,voiceKey="ErrorNotification",cooldown=.25}) end
	local view=id and self.nodes[id]
	if view then
		cancelTween(view,"flash")
		if not self.app.reducedMotion then
			view.outline.ImageColor3=color
			view.flash=TweenService:Create(view.outline,TweenInfo.new(MOTION.FlashSeconds,Enum.EasingStyle.Quad),{ImageColor3=view.rimColor or WHITE})
			view.flash:Play()
		end
		-- Position-only wiggle; SizeNode owns the same Visual's Size.
		if color==RED then Theme.Motion:Shake(view.visual) end
	end
	task.delay(2.2,function()
		if self.alive and version==self.feedbackVersion then self.message.Visible=false end
	end)
end

-- The server's entry for a node ({status, price?, spendReason?}); nil while loading.
function Browser:Info(id)
	local tree=self.tree;if not tree then return nil end
	local info=type(tree.nodes)=="table" and tree.nodes[id] or nil
	return if type(info)=="table" then info else {status="Locked"}
end

-- Affordable upgrades in a category, counted by the server (starter reserve included).
function Browser:Badge(category)
	local badges=self.tree and self.tree.badges
	local count=type(badges)=="table" and badges[category] or 0
	return if type(count)=="number" then count else 0
end

-- Special hexes (Start, Open, Back, the free Egg Vacuum) always count as owned.
function Browser:Known(id)
	local node=id and View.Nodes[id]
	if not node then return false end
	if node.kind~="upgrade" then return true end
	local info=self:Info(id)
	return info~=nil and (info.status=="Owned" or info.status=="Available" or info.status=="Unaffordable")
end

function Browser:Receive(state,result)
	if not state then return false end
	self.coins=state.coins or 0
	self.tree=if type(state.upgradeTree)=="table" then state.upgradeTree else nil
	View.Remember(self.tree and self.tree.families)
	local request=result and result.action=="BuyUpgrade" and self.requests[result.id] or nil
	if request then
		self.requests[result.id]=nil
		if self.pending[request.nodeId]==result.id then self.pending[request.nodeId]=nil end
	end
	if not self.root.Visible then return false end
	local id=request and request.nodeId
	self.revealOrigin=if request and result.ok and View.Nodes[id].category==self.category then id else nil
	self:Render();self.revealOrigin=nil
	if not request then return false end
	if result.ok then
		self.app.audio:Play("SkillTreePurchase",nil,{noFallback=true})
		local node=View.Nodes[id]
		self:Feedback(if View.Plain(node) then node.name.." bought!" else node.name..": "..request.before.." → "..request.after,GREEN,id)
		local view=self.nodes[id]
		self:PulseNode(view)
		local p=point(node);Theme.Motion:Burst(self.map,UDim2.fromScale(p.X,p.Y),GREEN)
		-- Keep gamepad focus on the family: its next tier is now the one to buy.
		local nextId=View.NextId(node.family,self.tree)
		local nextView=nextId and nextId~=id and self.nodes[nextId]
		if nextView and nextView.button.Visible and nextView.look~="unknown" and GuiService.SelectedObject==view.button then
			GuiService.SelectedObject=nextView.button
		end
	else self:Feedback(result.message or "Upgrade changed. Try again.",RED,id) end
	return true
end

function Browser:Render()
	local reveals={}
	for _,category in View.Categories do
		for _,id in View.Order[category] do
			local entry=self:RenderNode(id)
			if entry and category==self.category then table.insert(reveals,entry) end
		end
	end
	self:RevealNodes(reveals)
	for id,link in self.links do
		local view=self.nodes[id]
		link.line.Visible=view.button.Visible and self.nodes[link.parentId].button.Visible
		local owned=view.look=="owned"
		link.line.BackgroundColor3=if owned then GREEN else LINK
		link.line.BackgroundTransparency=if owned then .45 else .35
	end
	Theme.Motion:Count(self.cash,self.coins or 0,function(v) return Theme.Money(v) end)
	if self.selected then self:RenderTooltip() end
end

-- Styles one hex from the snapshot; returns a reveal entry when it newly shows.
function Browser:RenderNode(id)
	local node,view=View.Nodes[id],self.nodes[id]
	local kind=node.kind
	local look,visible=kind,true
	local info=if kind=="upgrade" then self:Info(id) else nil
	if kind=="upgrade" then
		local status=info and info.status
		look=if status=="Owned" then "owned" elseif status=="Available" then "available" elseif status=="Unaffordable" then "unaffordable" else "unknown"
		-- A locked hex shows as "?" beside one you can see; further out it stays hidden.
		visible=info~=nil and (look~="unknown" or self:Known(node.prerequisite))
	end
	local hidden=look=="unknown"
	if view.look~=look then
		local style=LOOKS[look] or LOOKS.available
		view.fill.Image,view.fill.ImageColor3=Assets[style.art],style.tint or WHITE
		view.gradient.Enabled=style.gradient~=nil
		if style.gradient then view.gradient.Color=style.gradient end
		view.rimColor=style.rim
		if not view.flash or view.flash.PlaybackState~=Enum.PlaybackState.Playing then view.outline.ImageColor3=style.rim end
	end
	local waiting=self.pending[id]~=nil
	view.icon.Visible=not hidden and view.icon.Image~=""
	view.title.Visible,view.hidden.Visible=not hidden,hidden
	view.numeral.Visible=not hidden and view.numeral.Text~=""
	-- Prices only on hexes you can still buy: gold when affordable, red when not.
	local buyable=look=="available" or look=="unaffordable"
	view.cost.Visible=buyable
	view.cashIcon.Visible=not waiting
	view.price.Position=UDim2.fromScale(if waiting then 0 else .29,0)
	view.price.Size=UDim2.fromScale(if waiting then 1 else .71,1)
	view.price.TextXAlignment=if waiting then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
	view.price.Text=if waiting then "…" elseif info and type(info.price)=="number" then Theme.Number(info.price) else ""
	view.price.TextColor3=if look=="unaffordable" then RED else COIN
	-- Red badge (October 20 owner): "!" when you can buy this hex right now; on an
	-- Open hex, how many upgrades inside you can buy.
	local count=if kind=="open" then self:Badge(node.opens) else 0
	view.badge.Visible=(look=="available" and not waiting) or count>0
	view.badgeText.Text=if kind=="open" then (if count>99 then "99+" else tostring(count)) else "!"
	local entry
	if visible and (not view.button.Visible or view.lastHidden and not hidden) then entry={id=id,new=not view.button.Visible} end
	view.button.Visible,view.button.Selectable=visible,visible and not hidden
	view.look,view.lastHidden=look,hidden
	view.button:SetAttribute("UpgradeState",look)
	return entry
end

function Browser:Select(id,persistent)
	local view=id and self.nodes[id]
	-- October 20 (owner): no card on phones, even when a shortcut opens a node.
	if not view or not view.button.Visible or touching() then self:DismissTooltip();return end
	local changed=self.selected~=id
	self.selected,self.persistent=id,persistent
	self.tip.Visible=true
	self:RenderTooltip()
	if changed then Theme.Motion:PopScale(self.tip,.94,.14) end
end

function Browser:DismissTooltip()
	self.selected,self.persistent=nil,false
	self.tip.Visible=false
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
end

-- Card text: name, what it does (current → next), price and "Resets on Rebirth".
function Browser:TooltipText(id)
	local node,view=View.Nodes[id],self.nodes[id]
	local look=view.look
	if node.kind=="start" then return "Start","Buy upgrades with Coins. Everything here resets on Rebirth.",nil,nil,nil end
	if node.kind=="back" then return "Back","Return to the main Upgrades tree.",nil,nil,nil end
	if node.kind=="open" then
		local count=self:Badge(node.opens)
		return node.name,"Open the "..node.name.." upgrades.",if count>0 then count.." ready to buy" else nil,nil,nil
	end
	if node.kind=="tool" then
		local tools=self.app.state and self.app.state.tools
		local owned=type(tools)=="table" and tools.eggVacuum==true
		return node.name,if owned then "Your Egg Vacuum. Upgrade it here." else "Free when the Commander guide ends. You can upgrade it before then.",nil,nil,nil
	end
	if look=="unknown" then
		local prerequisite=node.prerequisite and View.Nodes[node.prerequisite]
		return "Locked",if prerequisite then "Buy "..prerequisite.name.." first." else "Not available yet.",nil,nil,nil
	end
	local info=self:Info(id) or {}
	local body=View.Description(node)
	local before,after=View.Change(node)
	local change=if View.Plain(node) then (if look=="owned" then "Owned" else nil)
		elseif look=="owned" then "Owned: "..after else before.." → "..after
	if node.family=="Luck" then
		local nextId=View.NextId("Luck",self.tree)
		local odds=if id==nextId and self.tree then luckText(self.tree.luck,look~="owned") else nil
		if odds then body..=" "..odds end
		body..=" All normal chickens remain possible."
		local eventOdds=Browser.EventOdds(workspace:GetServerTimeNow())
		if eventOdds then body..=" "..eventOdds.."." end
	end
	if look=="unaffordable" and type(info.spendReason)=="string" and info.spendReason~="" then body..=" "..info.spendReason end
	local price=if look~="owned" and type(info.price)=="number" then info.price else nil
	return node.name,body,change,price,"Resets on Rebirth"
end

function Browser:RenderTooltip()
	local id=self.selected;if not id or not self.nodes[id] then return end
	local title,body,change,price,footer=self:TooltipText(id)
	local titleText,titleRows=wrap(title,22)
	local bodyText,bodyRows=wrap(body,26)
	local changeText,changeRows=wrap(change or "",22)
	if not change then changeRows=0 end
	-- Heights in card units; the card is 240 units wide (TipWidth).
	local y=10+30*titleRows+5
	local dividerY=y;y+=8
	local bodyY=y;y+=bodyRows*24+4
	local changeY=y;y+=changeRows*27+(if change then 4 else 0)
	local costY=y;if price then y+=42 end
	local footerY=y;if footer then y+=24 end
	local height=y+8
	local tipWidth=self:TipWidth()
	self.tip.Size=UDim2.fromScale(1,tipWidth*height/240)
	self.tipAspect.AspectRatio=240/height
	self.tip.UICorner.CornerRadius=UDim.new(10/height,0)
	self.tipTitle.Text=titleText
	self.tipTitle.Position,self.tipTitle.Size=UDim2.fromScale(.055,10/height),UDim2.fromScale(.89,30*titleRows/height)
	self.tipDivider.Position,self.tipDivider.Size=UDim2.fromScale(.085,dividerY/height),UDim2.fromScale(.83,1/height)
	self.tipEffect.Text=bodyText;self.tipEffect.Position,self.tipEffect.Size=UDim2.fromScale(.06,bodyY/height),UDim2.fromScale(.88,bodyRows*24/height)
	self.tipChange.Visible=change~=nil
	self.tipChange.Text=changeText;self.tipChange.Position,self.tipChange.Size=UDim2.fromScale(.06,changeY/height),UDim2.fromScale(.88,changeRows*27/height)
	self.tipCost.Visible=price~=nil
	self.tipCost.Position,self.tipCost.Size=UDim2.fromScale(.22,(costY+4)/height),UDim2.fromScale(.62,34/height)
	self.tipPrice.Text=if price then Theme.Money(price) else ""
	self.tipPrice.TextColor3=if self.nodes[id].look=="unaffordable" then RED else COIN
	self.tipFooter.Visible=footer~=nil
	self.tipFooter.Position,self.tipFooter.Size=UDim2.fromScale(.06,footerY/height),UDim2.fromScale(.88,20/height)
	self:PlaceTooltip()
end

-- Height-relative card width, with a ~200 px floor so phone text stays usable.
function Browser:TipWidth()
	local rootHeight=self.root.AbsoluteSize.Y
	if rootHeight<=0 then return TOOLTIP_WIDTH end
	return math.clamp(200/rootHeight,TOOLTIP_WIDTH,.5)
end

-- A click, tap or gamepad A: a small press, then the hex's action.
function Browser:Press(id)
	local view=self.nodes[id]
	if view then
		view.pulsing=false
		self:SizeNode(view,MOTION.PressScale,MOTION.PressSeconds,0,function() self:RestNode(view) end)
	end
	self:Activate(id)
end

function Browser:Activate(id)
	local node=View.Nodes[id];if not node then return end
	self.app.audio:Play("Click")
	if node.kind=="open" then self:ShowCategory(node.opens);return end
	if node.kind=="back" then self:ShowCategory("Main");return end
	if node.kind~="upgrade" or self.pending[id] then return end
	local info=self:Info(id)
	if not info then self:Feedback("Upgrades are loading…",WHITE,id);return end
	if info.status=="Owned" then self:Feedback(node.name..": owned",GREEN,id)
	elseif info.status=="Available" and type(info.price)=="number" then self:Purchase(id,info.price)
	elseif info.status=="Unaffordable" then
		self:Feedback(if type(info.spendReason)=="string" and info.spendReason~="" then info.spendReason else "Not enough Coins",RED,id)
	else
		local prerequisite=node.prerequisite and View.Nodes[node.prerequisite]
		self:Feedback(if prerequisite then "Buy "..prerequisite.name.." first" else "Not available yet",RED,id)
	end
end

function Browser:Purchase(id,price)
	local before,after=View.Change(View.Nodes[id])
	local requestId=self.app:Request("BuyUpgrade",{nodeId=id,expectedPrice=price})
	if not requestId then return end
	self.pending[id]=requestId
	self.requests[requestId]={nodeId=id,before=before,after=after}
	self:Render()
	-- Unlock the hex after a lost reply; its server quote still rejects repeats.
	task.delay(8,function()
		if self.alive and self.pending[id]==requestId then
			self.pending[id]=nil
			if self.root.Visible then self:Render() end
		end
	end)
	task.delay(30,function() if self.alive then self.requests[requestId]=nil end end)
end

function Browser:SetCategory(category)
	self.category=category
	for name,layer in self.layers do layer.Visible=name==category end
	local open=category~="Main" and View.OpenNode(category)
	self.title.Text=if open then "Upgrades · "..open.name else "Upgrades"
end

-- Open a subtree (its hexes pop in from Back) or return to the main tree where
-- the player left it.
function Browser:ShowCategory(category)
	if not self.layers[category] or category==self.category then return end
	self:DismissTooltip()
	self.saved[self.category]={zoom=self.zoom,pan=self.pan}
	self:SetCategory(category)
	local saved=self.saved[category]
	if category~="Main" then
		saved=nil
		for _,id in View.Order[category] do
			local view=self.nodes[id];self:ResetNodeMotion(view);view.button.Visible=false
		end
		self.opening=true
		self.app.audio:Play("SkillTreeOpen",nil,{noFallback=true})
	end
	self:Render()
	self.opening=false
	if saved then self.zoom,self.pan=saved.zoom,saved.pan;self:Transform() else self.zoom=1;self:Center(View.Roots[category]) end
	if UserInputService.GamepadEnabled then
		local root=self.nodes[View.Roots[category]]
		if root then GuiService.SelectedObject=root.button end
	end
end

function Browser:ClampPan()
	-- Bound navigation by node positions so touch users cannot lose the map.
	local root=self.root.AbsoluteSize
	if root.X>0 and root.Y>0 then
		local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
		for _,id in View.Order[self.category] or {} do
			if self.nodes[id].button.Visible then
				local p=point(View.Nodes[id]);minX=math.min(minX,p.X);minY=math.min(minY,p.Y);maxX=math.max(maxX,p.X);maxY=math.max(maxY,p.Y)
			end
		end
		if minX==math.huge then return false end
		local sx,sy=root.Y/root.X*1440/930*self.zoom,self.zoom
		self.pan=Vector2.new(math.clamp(self.pan.X,-.3-(maxX-.5)*sx,.3-(minX-.5)*sx),math.clamp(self.pan.Y,-.3-(maxY-.5)*sy,.3-(minY-.5)*sy))
	end
	return true
end

function Browser:Transform()
	if not self:ClampPan() then return end
	self.map.Size=UDim2.fromScale(self.zoom*1440/930,self.zoom)
	self.map.Position=UDim2.fromScale(.5+self.pan.X,.5+self.pan.Y)
	self:PlaceTooltip()
end

-- Pan to a node, switching to its map first (callers may name any category's node).
function Browser:Center(id)
	local node=id and View.Nodes[id];if not node then return end
	if node.category~=self.category and self.root.Visible then self:ShowCategory(node.category) end
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
	local current=View.Nodes[self.selected or View.Roots[self.category]]
	if not current then return false end
	local from=point(current)
	local best,score=nil,math.huge
	for _,id in View.Order[self.category] do
		local delta=point(View.Nodes[id])-from
		local d=Vector2.new(delta.X*1440,delta.Y*930)
		if self.nodes[id].button.Visible and self.nodes[id].look~="unknown" and d.Magnitude>0 and d.Unit:Dot(direction)>.5 then
			local value=d.Magnitude/(d.Unit:Dot(direction)^3)
			if value<score then best,score=id,value end
		end
	end
	if best then self:Center(best);self:Select(best,true);GuiService.SelectedObject=self.nodes[best].button end
	return best~=nil
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
		if not inside(self.root,p) or inside(self.exit,p) then return end
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
			if self.drag.moved then self.suppressUntil=os.clock()+.3 end
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
	local root=View.Roots[self.category]
	self:Center(root)
	local view=root and self.nodes[root]
	if UserInputService.GamepadEnabled and view then self:Select(root,true);GuiService.SelectedObject=view.button end
end

-- Older entry points (My Army's Flock/Army Size shortcuts) name a board key or family.
function Browser:OpenCash(upgradeKey)
	local id=upgradeKey and View.NextId(upgradeKey,self.tree)
	if id then self:OpenNode(id) else self:Open() end
end

function Browser:OpenNode(id)
	self:Open()
	local view=self.nodes[id]
	if not view then return end
	self:Center(id)
	self:Select(id,true)
	-- Phones get no card, so the hex pulses once the opening wave has passed.
	if touching() then task.delay(MOTION.OpenWaveSeconds,function() if self.alive and self.root.Visible then self:PulseNode(view) end end) end
	if UserInputService.GamepadEnabled and self.selected then
		GuiService.SelectedObject=self.nodes[self.selected].button
	end
end

function Browser:Open()
	if self.root.Visible then self:Focus();return end
	self.app.audio:Play("SkillTreeOpen",nil,{noFallback=true})
	-- Never stack over Invasions, Rebirth, Daily or another panel.
	if self.app.CloseOtherMenus then self.app:CloseOtherMenus("research")
	else self.app:ClosePanel();self.app.offlineCash:Dismiss(true) end
	self.previousSelection=GuiService.SelectedObject
	self.previousInsets=self.app.gui.ScreenInsets
	self.previousSafeAreaCompatibility=self.app.gui.SafeAreaCompatibility
	-- Native safe-area extension keeps the backdrop full-screen and controls clear
	-- of phone corners, without a second ScreenGui or viewport sizing code.
	self.app.gui.SafeAreaCompatibility=Enum.SafeAreaCompatibility.FullscreenExtension
	self.app.gui.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets
	-- Every visit starts on the main tree around Start.
	self:SetCategory("Main");self.saved={}
	for _,view in self.nodes do view.button.Visible=false end
	self.opening=true
	self.root.Visible=true;self.app.hudLayer.Visible=false
	self:Receive(self.app.state)
	self.opening=false
	self:Focus()
	ContextActionService:BindActionAtPriority("ResearchNavigation",function(_,state,input)
		if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
		local key=input.KeyCode
		if key==Enum.KeyCode.ButtonB then
			-- Back goes up one level; on the main tree it closes.
			if self.category~="Main" then self:ShowCategory("Main") else self:Close() end
		elseif key==Enum.KeyCode.Escape then self:Close()
		elseif key==Enum.KeyCode.ButtonA then if self.selected then self:Press(self.selected) end
		elseif key==Enum.KeyCode.ButtonX or key==Enum.KeyCode.Home then self:Focus()
		elseif key==Enum.KeyCode.ButtonR1 then self:Zoom(1.12)
		elseif key==Enum.KeyCode.ButtonL1 then self:Zoom(1/1.12)
		else
			local directions={[Enum.KeyCode.DPadLeft]=Vector2.new(-1,0),[Enum.KeyCode.DPadRight]=Vector2.new(1,0),[Enum.KeyCode.DPadUp]=Vector2.new(0,-1),[Enum.KeyCode.DPadDown]=Vector2.new(0,1),
				[Enum.KeyCode.Left]=Vector2.new(-1,0),[Enum.KeyCode.Right]=Vector2.new(1,0),[Enum.KeyCode.Up]=Vector2.new(0,-1),[Enum.KeyCode.Down]=Vector2.new(0,1)}
			if directions[key] then self:Navigate(directions[key]) end
		end
		return Enum.ContextActionResult.Sink
	end,false,3500,Enum.KeyCode.ButtonB,Enum.KeyCode.ButtonA,Enum.KeyCode.Escape,Enum.KeyCode.ButtonX,Enum.KeyCode.Home,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1,
		Enum.KeyCode.DPadLeft,Enum.KeyCode.DPadRight,Enum.KeyCode.DPadUp,Enum.KeyCode.DPadDown,Enum.KeyCode.Left,Enum.KeyCode.Right,Enum.KeyCode.Up,Enum.KeyCode.Down)
	local root=self.nodes[View.Roots.Main]
	if UserInputService.GamepadEnabled and root then GuiService.SelectedObject=self.nodes[self.selected or View.Roots.Main].button end
end

function Browser:Close()
	if not self.root.Visible then return end
	self.app.audio:Play("SkillTreeClose",nil,{noFallback=true})
	self.root.Visible=false;self.app.hudLayer.Visible=true;self.drag=nil
	self.message.Visible=false;self.feedbackVersion=(self.feedbackVersion or 0)+1
	self.opening,self.revealOrigin,self.pinchScale=false,nil,nil
	for _,view in self.nodes do
		self:ResetNodeMotion(view)
		-- Re-style the stable saved state on the next visit even if a flash was cut.
		view.look=nil
	end
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
