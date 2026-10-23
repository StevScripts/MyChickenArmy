--!strict
-- The full-screen Upgrades tree (October 20 overhaul, docs/team/UPGRADES_SCREEN.md):
-- a main map around Start, plus Tools, Player and Army subtrees opened from orange
-- Open hexes and left through a red Back hex. Graph geometry uses a native aspect
-- constraint; input changes only each map's pan/zoom, never the layout of individual
-- nodes. The server owns every status, price and badge (state.upgradeTree).
local UserInputService=game:GetService("UserInputService")
local TextService=game:GetService("TextService")
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local TweenService=game:GetService("TweenService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Theme=require(script.Parent.UITheme)
local Assets=require(script.Parent.ResearchAssets)
local View=require(script.Parent.CashUpgradeNodes)
local GoldRolls=require(Shared.GoldRolls)
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
-- October 21 (owner): hex prices are green when you can afford them, red when not.
local COIN=Theme.Colors.coins
-- October 20 overhaul: bought and maxed hexes use the bright Army green.
local GREEN=Color3.fromRGB(163,255,0)
local ALERT=Color3.fromRGB(235,45,45)
local RED_FACE=ColorSequence.new(Color3.fromRGB(255,102,84),Color3.fromRGB(243,36,59))
-- Reference parity (October 21, docs/team/REFERENCE_PARITY_20261021.md §2.3): the card
-- is a dark translucent slate with a 2 px dark stroke; its body is light grey with the
-- changing value in green, like the reference's highlighted number.
local TIP_FILL=Color3.fromRGB(26,32,40)
local TIP_STROKE=Color3.fromRGB(6,8,10)
local TIP_BODY=Color3.fromRGB(208,214,220)
local TIP_LINE=Color3.fromRGB(74,84,96)
local GREEN_TAG=string.format('<font color="#%02X%02X%02X">',math.round(GREEN.R*255),math.round(GREEN.G*255),math.round(GREEN.B*255))
-- Outline weight (share of the glyph) for every label laid over the hexes and the
-- world, so names, numerals and prices read on any background.
local STROKE=.075
-- Each hex look: the art, its tint or vertical gradient, and the rim around it.
-- Unbought hexes are dark like the reference, with a grey rim; "?" ghosts are a
-- see-through grey with a dark "?", so the blurred world shows faintly through them.
local LOOKS={
	owned={art="hexMask",gradient=ColorSequence.new(GREEN,Color3.fromRGB(0,211,0)),rim=Color3.fromRGB(14,84,0)},
	start={art="hexMask",gradient=Theme.ReferenceGradients.Upgrades,rim=Color3.fromRGB(0,72,112)},
	open={art="hexMask",gradient=Theme.ReferenceGradients.Base,rim=Color3.fromRGB(122,64,0)},
	back={art="hexMask",gradient=RED_FACE,rim=Color3.fromRGB(112,10,22)},
	available={art="hexFill",rim=Color3.fromRGB(96,98,104)},
	unknown={art="hexMask",tint=Color3.fromRGB(118,118,124),rim=Color3.fromRGB(34,34,38),transparency=.22},
}
-- Price color (and the "!" badge) alone mark unaffordable.
LOOKS.unaffordable=LOOKS.available
-- The Gold / Diamond / Prism "N Rolls Left" rows, in the machine's order.
local COUNTER_KINDS={"Gold","Diamond","Prism"}
-- UI Lab only: the reference's two counters when the fixture has none.
local PREVIEW_COUNTERS={{kind="Gold",every=10,count=2,left=8,luck=2},{kind="Diamond",every=100,count=0,left=100,luck=5}}
local TOOLTIP_WIDTH=.218
-- Hex text rows in shares of the hex's height (round 2, phone 844 x 390): a hex is
-- 60 px tall there at zoom 1, so a .22 line renders 13 px (the 12 px readable floor
-- with room to spare) and a .215 price row 12 px; desktops get the same proportions,
-- larger. One layout for every device: only the name's line count changes, and that
-- comes from the name itself (NameLines), never from the screen.
local HEX={Line=.22,NameWidth=.96,PriceRow=.215,PriceTop=.775,IconTop=.04}
-- The price row's coin is a square of the row's height: its share of the row's width.
local COST_WIDTH=.76
local COST_ICON=HEX.PriceRow*144/(COST_WIDTH*164)
local COST_TEXT=COST_ICON+.02
-- October 20 tree v2 (S9c): flat-topped hexes like the reference, 164 wide x 144 tall.
local NODE_SIZE=UDim2.fromScale(164/1440,144/930)
-- Presentation tuning only: seconds and relative scales, never purchase timing.
-- October 21 game feel (docs/team/GAME_FEEL_20261021.md): LinkSeconds is the spark
-- that runs from a bought hex to the hex it opens before that one pulses; GlowLimit
-- caps the affordable glow at the hexes nearest the map's centre hex; LaneLimit and
-- LaneWindow are the short reveal when Back returns to the main map.
-- Reference parity: a hovered or focused hex grows clearly (HoverScale) and draws over
-- its neighbours; DeltaHoldSeconds/DeltaFadeSeconds time the red "-price" beside Coins.
local MOTION={
	OpenScale=0,OpenSeconds=.24,OpenStaggerSeconds=.045,OpenWaveSeconds=.80,
	FrontierEntryScale=.88,FrontierSeconds=.18,FrontierWaveSeconds=.08,FrontierScale=1.025,
	HoverScale=1.12,PressScale=.96,PressSeconds=.055,SettleSeconds=.13,
	DeltaHoldSeconds=1.1,DeltaFadeSeconds=.45,
	ConfirmScale=1.045,ConfirmRiseSeconds=.10,ConfirmSettleSeconds=.18,FlashSeconds=.35,
	LinkSeconds=.3,GlowLimit=8,GlowSeconds=.9,ReadyScale=1.06,LaneLimit=24,LaneWindow=.3,
	TipSeconds=.16,TipLeaveSeconds=.1,TipScale=.92,TipSlide=.05,MaxFlashSeconds=.6,SparkSize=.022,
}
local GOLD=Theme.Motion.Palette[1]
-- Lane colours for the affordable glow, purchase flash, link spark and confetti:
-- eggs and Gold rolls gold, Army lime, rolls and Player sky, mutations and Prism
-- violet, Diamond paper, Tools orange. Presentation only; the hex art is unchanged.
local LANE_FAMILY={
	EggSpeed=GOLD,EggValue=GOLD,Flock=GOLD,GoldMachine=GOLD,GoldRate=GOLD,ArmySize=Theme.Motion.Palette[2],
	RollSlot=Theme.Motion.Palette[3],RollSpeed=Theme.Motion.Palette[3],Luck=Theme.Motion.Palette[3],
	Mutation=Theme.Motion.Palette[5],PrismMachine=Theme.Motion.Palette[5],PrismRate=Theme.Motion.Palette[5],
	DiamondMachine=Theme.Motion.Palette[6],DiamondRate=Theme.Motion.Palette[6],
}
local LANE_CATEGORY={Main=GOLD,Tools=Theme.ReferenceColors.Base,Player=Theme.Motion.Palette[3],Army=Theme.Motion.Palette[2]}
local function laneColor(node)
	return (node.family and LANE_FAMILY[node.family]) or LANE_CATEGORY[node.category] or GOLD
end
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
-- Hex grid in canvas pixels, flat-topped (S9c): a q step is 133.4 right and 77 down, an
-- r step 154 down; each hex is 164 x 144. Offset(side) is a neighbour cell's centre
-- offset in the same units. CommanderGuide reads it to rest its arrow in an empty cell.
Browser.Grid={step=133.4,row=154,width=164,height=144,flat=true}
function Browser.Grid.Offset(side:{number}):Vector2
	return Vector2.new(Browser.Grid.step*side[1],Browser.Grid.row*(side[2]+side[1]/2))
end
local function point(node)
	local offset=Browser.Grid.Offset({node.q,node.r})
	return Vector2.new((690+offset.X)/1440,(450+offset.Y)/930)
end
local function label(parent,name,text,x,y,w,h,color)
	local item=Theme.Label(parent,name,text,20,color or WHITE)
	item.Position,item.Size=UDim2.fromScale(x,y),UDim2.fromScale(w,h)
	-- Setting TextWrapped=false turns TextScaled off in Roblox, leaving fixed 20px text
	-- that overflows small phone hexes; keep the default wrapping.
	item.TextScaled,item.TextXAlignment=true,Enum.TextXAlignment.Center
	-- Every label carries the black outline (reference parity §2.1), so it reads over
	-- any hex and any world behind the tint.
	item.TextOutline.Thickness=STROKE
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
local function escape(text:string):string
	return (text:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"))
end
-- The card's effect sentence: the same word wrap, as RichText, with the words of the
-- green segments (the changing value) wrapped in the green font tag.
local function richWrap(segments:{{text:string,green:boolean?}},limit:number):(string,number)
	local rows,row,length={},{},0
	for _,segment in segments do
		for word in segment.text:gmatch("%S+") do
			local size=utf8.len(word) or #word
			if #row>0 and length+1+size>limit then table.insert(rows,row);row,length={},0 end
			length+=(if #row>0 then 1 else 0)+size
			table.insert(row,{text=word,green=segment.green==true})
		end
	end
	if #row>0 then table.insert(rows,row) end
	local lines={}
	for _,words in rows do
		local parts,green={},false
		for index,word in words do
			if word.green~=green then
				table.insert(parts,if word.green then GREEN_TAG else "</font>")
				green=word.green
			end
			table.insert(parts,(if index>1 then " " else "")..escape(word.text))
		end
		if green then table.insert(parts,"</font>") end
		table.insert(lines,table.concat(parts))
	end
	return table.concat(lines,"\n"),math.max(1,#rows)
end
-- A hex name's lines: one when it fits the hex's inner width at the line height, else
-- the two-line split whose wider line is narrowest ("Vacuum\nCapacity IV"). Widths are
-- Roblox's own font metrics per unit of text size, so the answer is the same on every
-- device (the map scales as a whole). Without TextService it estimates from length.
local function nameWidth(text:string):number
	local ok,size=pcall(function() return TextService:GetTextSize(text,100,Theme.Font,Vector2.new(1e5,1e5)) end)
	return if ok and size.Y>0 then size.X/size.Y else #text*.5
end
local function nameLines(text:string):(string,number)
	-- The widest a line may be, in units of its own height (3% kept for the outline).
	local limit=HEX.NameWidth*(164/144)/HEX.Line*.97
	if nameWidth(text)<=limit then return text,1 end
	local words=string.split(text," ")
	local best,widest=text,math.huge
	for index=1,#words-1 do
		local first,second=table.concat(words," ",1,index),table.concat(words," ",index+1)
		local width=math.max(nameWidth(first),nameWidth(second))
		if width<widest then best,widest=first.."\n"..second,width end
	end
	return best,if widest<math.huge then 2 else 1
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
	local self=setmetatable({app=app,nodes={},layers={},connections={},zoom=1,pan=Vector2.zero,alive=true,
		category="Main",saved={},coins=0,pending={},requests={}},Browser)
	local root=Instance.new("TextButton")
	root.Name,root.Text,root.Size="Research","",UDim2.fromScale(1,1)
	root:SetAttribute("HoverAudioCue","SkillTreeHover")
	-- Reference parity (October 21, supersedes the October 20 solid black): the tree lies
	-- over the blurred world (SetMenuBlur in Open) under a black tint at 35% transparency.
	root.BackgroundColor3,root.BackgroundTransparency,root.BorderSizePixel=Color3.new(0,0,0),.35,0
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
		for _,id in View.Order[category] do self:BuildNode(id,layer) end
	end
	-- Reference parity: no title or dark bands; the map runs edge to edge and the
	-- controls (wallet column, Close/Back, X) sit over it, each stroked to read anywhere.
	self:BuildWallet()
	-- The shared square close X (Theme.HeaderClose's button and accent), in the
	-- top-right corner like every other menu; large enough for a thumb on phones.
	self.exit=Theme.ActionButton(root,"Exit","X",function() self.app.audio:Play("Click");self:Close() end,Theme.ActionColors.danger)
	Theme.ApplyReferenceAccent(self.exit,RED_FACE)
	self.exit.AnchorPoint,self.exit.Position,self.exit.Size,self.exit.ZIndex=Vector2.new(1,0),UDim2.fromScale(.985,.012),UDim2.fromScale(.14,.105),6
	Theme.Aspect(self.exit,120/115)
	-- Phone hit area: 1.2x, growing left and down (the page clips its top-right corner).
	Theme.PadHit(self.exit,1.2,1.2,1,0)
	-- The reference's wide red button at the bottom centre: Close on the main tree,
	-- Back in a subtree (SetCategory renames it). Its rectangle is height-relative
	-- (one layout on every device); the hit area grows to 48 px on a phone, mostly
	-- upward, without moving the art. Its action plays its own cue (no extra Click).
	local bottom=Theme.ActionButton(root,"Close","Close",function()
		if not self.root.Visible then return end
		if self.category~="Main" then self:ShowCategory("Main") else self:Close() end
	end,Theme.ActionColors.danger)
	Theme.ApplyReferenceAccent(bottom,RED_FACE)
	bottom:SetAttribute("ClickSound",false)
	bottom.SizeConstraint=Enum.SizeConstraint.RelativeYY
	bottom.AnchorPoint,bottom.Position,bottom.Size,bottom.ZIndex=Vector2.new(.5,1),UDim2.fromScale(.5,.975),UDim2.fromScale(.064*3.6,.064),6
	Theme.PadHit(bottom,1.25,2,.5,.75)
	self.closeButton=bottom
	self.message=label(root,"Feedback","",.15,.17,.70,.055,GREEN)
	self.message.ZIndex,self.message.Visible=12,false
	-- Centre-anchored once so its pop grows from the middle; the rendered spot is the same.
	Theme.Motion:Center(self.message)
	-- Link sparks fly above every map layer; the holder never takes input.
	local sparks=Theme.Container(map,"Sparks")
	sparks.ZIndex,sparks.Active=2,false
	self.sparks=sparks

	self:BuildTooltip()
	-- Tapping empty map closes a gamepad card (nodes sink their own input).
	root.Activated:Connect(function()
		if self.persistent and os.clock()>=(self.suppressUntil or 0) then self:DismissTooltip() end
	end)
	self:BindInput()
	return self
end

-- Upper left while the tree is open (the reference's t9/t15): the Gold / Diamond /
-- Prism "N Rolls Left" rows with their dice (owned machines only), then the Coins
-- pill, and the red "-price" that pops beside it on a buy. One column in screen-height
-- units (SizeConstraint RelativeYY) so every device gets the same proportions; a list
-- keeps the rows packed from the top when a machine is not owned yet.
function Browser:BuildWallet()
	-- Column units: 520 wide x 300 tall (three 66-unit rows, the 46-unit pill, gaps).
	local column=Theme.Container(self.root,"Wallet")
	column.SizeConstraint=Enum.SizeConstraint.RelativeYY
	column.Position,column.Size,column.ZIndex=UDim2.fromScale(.012,.335),UDim2.fromScale(.52,.3),5
	column.Active=false
	local list=Instance.new("UIListLayout")
	list.SortOrder,list.VerticalAlignment=Enum.SortOrder.LayoutOrder,Enum.VerticalAlignment.Top
	list.Padding,list.Parent=UDim.new(8/300,0),column
	self.counters={}
	for order,kind in COUNTER_KINDS do
		local row=Theme.Container(column,kind.."Rolls")
		row.Size,row.LayoutOrder,row.Visible,row.ZIndex=UDim2.fromScale(340/520,66/300),order,false,5
		-- A dark translucent strip under the text; the die overhangs its left end.
		local strip=Theme.Frame(row,"Strip",UDim2.fromScale(310/340,46/66),Color3.new(0,0,0))
		strip.Position,strip.BackgroundTransparency,strip.ZIndex=UDim2.fromScale(30/340,10/66),.45,5
		Theme.Stroke(strip,Color3.new(0,0,0),2).Transparency=.35
		local die=Theme.Image(row,"Die",GoldRolls.Icons[kind] or "",UDim2.fromScale(66/340,1))
		die.ZIndex=7
		local text=label(row,"Count","",82/340,10/66,250/340,46/66,GoldRolls.Colors[kind] or WHITE)
		text.TextXAlignment,text.ZIndex=Enum.TextXAlignment.Left,7
		self.counters[kind]={frame=row,label=text}
	end
	local coins=Theme.Container(column,"Coins")
	coins.Size,coins.LayoutOrder,coins.ZIndex=UDim2.fromScale(1,46/300),10,5
	-- The Coins pill: dark gold translucent with a 2 px dark stroke, coin + gold amount.
	local pill=Theme.Frame(coins,"Pill",UDim2.fromScale(290/520,1),Color3.fromRGB(64,48,8))
	pill.BackgroundTransparency,pill.ZIndex=.3,5
	Theme.Stroke(pill,Color3.new(0,0,0),2).Transparency=.2
	local icon=Theme.Image(pill,"CashIcon",Assets.cash,UDim2.fromScale(38/290,38/46),UDim2.fromScale(6/290,4/46))
	icon.ZIndex=6
	self.cash=label(pill,"Cash","0",50/290,4/46,232/290,38/46,COIN)
	self.cash.TextXAlignment,self.cash.ZIndex=Enum.TextXAlignment.Left,6
	-- The spend delta right of the pill, about two thirds of its text height; anchored at
	-- its left middle so its pop grows out of the pill's side.
	local delta=label(coins,"SpendDelta","",304/520,.5,210/520,.64,RED)
	delta.AnchorPoint,delta.TextXAlignment,delta.ZIndex,delta.Visible=Vector2.new(0,.5),Enum.TextXAlignment.Left,6,false
	self.wallet,self.delta=column,delta
end

-- The counters from state.goldRolls (the server's GoldRolls.Counters: owned machines
-- only, Gold first). A count that changes while the tree is open (Auto Roll keeps
-- rolling) punches its row; opening the tree only snaps the text.
function Browser:RenderCounters(state,live)
	local data=type(state)=="table" and state.goldRolls or nil
	local counters=type(data)=="table" and type(data.counters)=="table" and data.counters or nil
	if not counters and self.app.editPreview then counters=PREVIEW_COUNTERS end
	local shown={}
	for _,counter in counters or {} do
		if type(counter)=="table" and type(counter.kind)=="string" and type(counter.left)=="number" then shown[counter.kind]=counter end
	end
	for kind,row in self.counters do
		local counter=shown[kind]
		if counter then
			local text=GoldRolls.Text(counter)
			if live and row.frame.Visible and row.label.Text~=text then Theme.Motion:Punch(row.frame,1.12,.28) end
			row.label.Text=text
		end
		row.frame.Visible=counter~=nil
	end
end

-- The red "-2,850,000" beside the Coins pill after a buy: it pops, holds, then fades
-- (reduced motion: it shows, then hides). A second buy restarts it with its price.
function Browser:SpendDelta(amount)
	if type(amount)~="number" or amount<=0 then return end
	local delta=self.delta
	local outline=delta:FindFirstChild("TextOutline") :: UIStroke?
	Theme.Motion:Cancel(delta,"fade")
	if outline then Theme.Motion:Cancel(outline,"fade");outline.Transparency=0 end
	delta.Text,delta.TextTransparency,delta.Visible="-"..Theme.Money(amount),0,true
	self.deltaVersion=(self.deltaVersion or 0)+1
	local version=self.deltaVersion
	if not self.app.reducedMotion then Theme.Motion:PopScale(delta,1.3,.26) end
	task.delay(MOTION.DeltaHoldSeconds,function()
		if not self.alive or version~=self.deltaVersion then return end
		if self.app.reducedMotion then delta.Visible=false;return end
		if outline then Theme.Motion:Tween(outline,"fade",{Transparency=1},MOTION.DeltaFadeSeconds) end
		Theme.Motion:Tween(delta,"fade",{TextTransparency=1},MOTION.DeltaFadeSeconds,nil,nil,function()
			if version==self.deltaVersion then delta.Visible=false end
		end)
	end)
end

function Browser:BuildNode(id,layer)
	local node=View.Nodes[id];local p=point(node)
	local kind=node.kind
	local button=Instance.new("ImageButton")
	button.Name,button.Image,button.BackgroundTransparency=id,"",1
	button.Size,button.AnchorPoint,button.Position=NODE_SIZE,Vector2.new(.5,.5),UDim2.fromScale(p.X,p.Y)
	button.AutoButtonColor,button.Visible,button.Parent=false,false,layer
	Theme.Aspect(button,164/144)
	local visual=Theme.Container(button,"Visual")
	visual.AnchorPoint,visual.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
	-- The pointy-top hex art turned a quarter: sized 144 x 164 so it lies 164 x 144.
	local function flat(name,asset,inset)
		local image=Theme.Image(visual,name,asset,UDim2.fromScale(inset*144/164,inset*164/144),UDim2.fromScale(.5,.5))
		image.AnchorPoint,image.Rotation=Vector2.new(.5,.5),90
		return image
	end
	-- A thin lane-coloured hex behind the rim: the affordable glow (hex-shaped, so no
	-- rectangular stroke boxes the hex). Hidden until RefreshGlow lights it.
	local glow=flat("Glow",Assets.hexMask,1.07);glow.ZIndex,glow.ImageTransparency,glow.Visible=1,1,false
	local outline=flat("Outline",Assets.hexMask,1);outline.ZIndex=2
	local fill=flat("Fill",Assets.hexFill,.92);fill.ZIndex=3
	-- The purchase flash: a lane-coloured copy of the fill that sits above the fill and
	-- under the icon (a child renders between its parent and the next sibling).
	local flash=Theme.Image(fill,"Flash",Assets.hexMask,UDim2.fromScale(1,1))
	flash.ImageTransparency,flash.Visible=1,false
	-- Rotation 0 on the turned art reads top to bottom on screen.
	local gradient=Instance.new("UIGradient")
	gradient.Rotation,gradient.Enabled,gradient.Parent=0,false,fill
	-- Reference parity (t9, t11, t15): the icon fills the hex's upper middle; the name runs
	-- across the hex over the icon in one stroked line (it may pass the hex's edges, and
	-- TextScaled shrinks long names); the tier numeral sits in the icon's bottom-right
	-- corner; the coin and compact price sit on the hex's bottom edge.
	local icon=Theme.Image(visual,"Icon",Assets.upgrades[node.icon] or Assets.index,UDim2.fromScale(.56,.64),UDim2.fromScale(.22,.1));icon.ZIndex=4
	local title=label(visual,"Title",node.name,-.09,.4,1.18,.14)
	title.ZIndex=6
	local numeral=label(visual,"Numeral",if node.numeral then tostring(node.numeral) else "",.55,.54,.24,.27)
	numeral.ZIndex,numeral.Visible=6,kind=="upgrade" and node.numeral~=nil
	numeral.TextOutline.Thickness=STROKE*1.4
	-- "Open" under an Open hex's name; the category's name under Back.
	local caption=label(visual,"Caption","",.1,.68,.8,.17,if kind=="open" then Color3.fromRGB(255,240,90) else WHITE)
	caption.ZIndex,caption.Visible=6,kind=="open" or kind=="back"
	local cost=Theme.Container(visual,"Cost");cost.ZIndex=5
	cost.Position,cost.Size=UDim2.fromScale((1-COST_WIDTH)/2,HEX.PriceTop),UDim2.fromScale(COST_WIDTH,HEX.PriceRow)
	local cashIcon=Theme.Image(cost,"CashIcon",Assets.cash,UDim2.fromScale(COST_ICON,1));cashIcon.ZIndex=5
	local price=label(cost,"Price","",COST_TEXT,0,1-COST_TEXT,1,GREEN);price.TextXAlignment,price.ZIndex=Enum.TextXAlignment.Left,5
	-- The "?" ghost: a dark question mark on the see-through grey hex (LOOKS.unknown).
	local hidden=label(visual,"Hidden","?",.25,.15,.5,.7,Color3.fromRGB(58,58,64));hidden.ZIndex=5
	hidden.TextOutline.Color=Color3.fromRGB(20,20,24)
	-- Red circle at the top right: "!" on an upgrade you can buy now, or on an Open hex
	-- how many upgrades inside you can buy.
	local badge=Theme.Frame(visual,"Alert",UDim2.fromScale(.26,.26),ALERT)
	badge.AnchorPoint,badge.Position,badge.ZIndex,badge.Visible=Vector2.new(.5,.5),UDim2.fromScale(.8,.12),7,false
	Theme.Aspect(badge,1);round(badge,.5)
	-- Round joins: a Miter stroke draws a square box around a circle.
	Theme.Stroke(badge,Color3.new(0,0,0),2).LineJoinMode=Enum.LineJoinMode.Round
	local badgeText=label(badge,"Text","!",.1,.1,.8,.8);badgeText.ZIndex=8
	if kind=="start" then
		icon.Position,icon.Size=UDim2.fromScale(.2,.04),UDim2.fromScale(.6,.6)
		title.Position,title.Size=UDim2.fromScale(.02,.62),UDim2.fromScale(.96,HEX.Line)
	elseif kind=="open" or kind=="back" then
		icon.Position,icon.Size=UDim2.fromScale(.24,.03),UDim2.fromScale(.52,.5)
		title.Position,title.Size=UDim2.fromScale(.02,.46),UDim2.fromScale(.96,HEX.Line)
		caption.Position,caption.Size=UDim2.fromScale(.1,.46+HEX.Line),UDim2.fromScale(.8,HEX.Line)
		local category=if kind=="back" then View.OpenNode(node.category) else nil
		caption.Text=if kind=="open" then "Open" elseif category then category.name else ""
		-- Without its arrow icon, Back's words fill the hex instead.
		if icon.Image=="" then
			title.Position,title.Size=UDim2.fromScale(.1,.2),UDim2.fromScale(.8,.24)
			caption.Position,caption.Size=UDim2.fromScale(.1,.48),UDim2.fromScale(.8,.24)
		end
	else
		-- Round 2 (phone floor): rows from the bottom up. The price row sits on the hex's
		-- bottom edge; the name (one or two .22 lines across the hex's inner width) sits
		-- just above it, over the lower part of the icon like the reference; the icon
		-- fills the space above the name; the numeral sits on the icon's bottom-right
		-- corner, right above the name (smaller when the name takes two lines).
		local text,lines=nameLines(node.name)
		local nameTop=HEX.PriceTop-lines*HEX.Line
		title.Text=text
		title.Position,title.Size=UDim2.fromScale((1-HEX.NameWidth)/2,nameTop),UDim2.fromScale(HEX.NameWidth,lines*HEX.Line)
		local iconSize=nameTop+.06-HEX.IconTop
		local iconWidth=iconSize*144/164
		icon.Position,icon.Size=UDim2.fromScale((1-iconWidth)/2,HEX.IconTop),UDim2.fromScale(iconWidth,iconSize)
		local numeralSize=if lines==1 then HEX.Line else .17
		local numeralLeft=if lines==1 then .6 else .58
		numeral.Position,numeral.Size=UDim2.fromScale(numeralLeft,nameTop-numeralSize),UDim2.fromScale(if lines==1 then .24 else .16,numeralSize)
		-- The name and the price never render under the 12 px floor (their rows are sized
		-- for it; this only guards a smaller screen). The numeral may shrink.
		Theme.ScaleText(title);Theme.ScaleText(price)
		-- Upgrade hexes never move these again, so their punches grow from the middle.
		Theme.Motion:Center(title);Theme.Motion:Center(cost)
	end
	if kind=="start" or kind=="open" or kind=="back" then
		-- The hubs and Back: their short words keep the readable floor.
		Theme.ScaleText(title);Theme.ScaleText(caption)
	end
	if kind=="start" or kind=="open" then
		-- The Main hubs' hit area is 48 px on a phone (hex art untouched; the hubs' boxes
		-- already meet at the corners).
		Theme.PadHit(button,1.1,1.27,0.5,0.5,true)
	end
	self.nodes[id]={id=id,button=button,visual=visual,outline=outline,fill=fill,gradient=gradient,icon=icon,glow=glow,flashFill=flash,
		title=title,numeral=numeral,caption=caption,cost=cost,cashIcon=cashIcon,price=price,hidden=hidden,badge=badge,badgeText=badgeText}
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

-- The card beside a hovered/focused hex (reference t15/t17): a dark translucent slate
-- with a 2 px dark stroke and square corners; the name, the effect sentence with the
-- changing value in green, a divider, the coin and price on a faint gold strip, and
-- "Resets on Rebirth". Every line is stroked.
function Browser:BuildTooltip()
	local tip=Theme.Frame(self.root,"NodeTooltip",UDim2.fromScale(1,TOOLTIP_WIDTH),TIP_FILL)
	tip.BackgroundTransparency=.08
	Theme.Aspect(tip,1)
	local aspect=tip.UIAspectRatioConstraint
	-- A constant height-relative width keeps this card independent of map zoom.
	aspect.AspectType,aspect.DominantAxis=Enum.AspectType.ScaleWithParentSize,Enum.DominantAxis.Height
	Theme.Stroke(tip,TIP_STROKE,2)
	tip.Visible,tip.Active,tip.ZIndex=false,false,8
	self.tip,self.tipAspect=tip,aspect
	self.tipTitle=label(tip,"Name","",.055,.06,.89,.18);self.tipTitle.ZIndex=9
	self.tipTitle.TextXAlignment=Enum.TextXAlignment.Left
	self.tipEffect=label(tip,"Effect","",.055,.31,.89,.39,TIP_BODY);self.tipEffect.ZIndex=9
	self.tipEffect.TextXAlignment,self.tipEffect.RichText=Enum.TextXAlignment.Left,true
	self.tipDivider=Theme.Frame(tip,"Divider",UDim2.fromScale(.89,.005),TIP_LINE)
	self.tipDivider.Position,self.tipDivider.ZIndex=UDim2.fromScale(.055,.7),9
	self.tipCost=Theme.Container(tip,"Cost");self.tipCost.ZIndex=9
	local strip=Theme.Frame(self.tipCost,"Strip",UDim2.fromScale(1,1),Color3.fromRGB(96,74,14))
	strip.ZIndex=9
	local fade=Instance.new("UIGradient")
	fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.35),NumberSequenceKeypoint.new(.55,.8),NumberSequenceKeypoint.new(1,1)})
	fade.Parent=strip
	self.tipCash=Theme.Image(self.tipCost,"CashIcon",Assets.cash,UDim2.fromScale(.13,.84),UDim2.fromScale(.02,.08));self.tipCash.ZIndex=10
	self.tipPrice=label(self.tipCost,"Price","",.17,.08,.8,.84,COIN);self.tipPrice.TextXAlignment=Enum.TextXAlignment.Left;self.tipPrice.ZIndex=10
	self.tipFooter=label(tip,"Resets","Resets on Rebirth",.055,.9,.89,.08,MUTED);self.tipFooter.ZIndex=9
	self.tipFooter.TextXAlignment=Enum.TextXAlignment.Left
end

function Browser:RestScale(view)
	if self.app.reducedMotion or view.look=="unknown" then return 1 end
	return if view.pressed then MOTION.PressScale elseif view.hovered or view.focused then MOTION.HoverScale else 1
end

function Browser:SizeNode(view,scale,seconds,delay,complete)
	cancelSize(view)
	-- A padded hub's art rests smaller than its hit area (Theme.PadHit); scale from there.
	local rest=Theme.Motion.restingSizes[view.visual] or UDim2.fromScale(1,1)
	if self.app.reducedMotion then view.visual.Size=rest;view.pulsing=false;return end
	local tween=TweenService:Create(view.visual,TweenInfo.new(seconds,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,false,delay or 0),{Size=UDim2.fromScale(rest.X.Scale*scale,rest.Y.Scale*scale)})
	view.sizeTween=tween
	if complete then
		view.sizeConnection=tween.Completed:Connect(function(state)
			if state==Enum.PlaybackState.Completed and self.alive and self.root.Visible and view.sizeTween==tween then complete() end
		end)
	end
	tween:Play()
end

function Browser:RestNode(view,seconds)
	-- The hovered, focused or pressed hex draws above its neighbours (sibling order),
	-- so its grown art, long name and price are never cut by the next hex.
	view.button.ZIndex=if view.hovered or view.focused or view.pressed then 2 else 1
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
	-- After a purchase, a spark runs from the bought hex to each hex it opens; those
	-- hexes pulse once it lands (LinkSeconds), the rest follow the frontier wave.
	local linked=not opening and self.revealOrigin
	for index,entry in reveals do
		local view=self.nodes[entry.id]
		local distance=(point(View.Nodes[entry.id])-origin).Magnitude
		local delay=if opening then (index-1)*stagger else (if linked then MOTION.LinkSeconds else 0)+(if far>0 then distance/far else 0)*MOTION.FrontierWaveSeconds
		if linked and View.Nodes[entry.id].prerequisite==linked then self:Spark(linked,entry.id,laneColor(View.Nodes[entry.id])) end
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
	view.pressInput=nil;view.visual.Size=UDim2.fromScale(1,1);view.button.ZIndex=1
	if view.rimColor then view.outline.ImageColor3=view.rimColor end
	self:StopGlow(view)
	Theme.Motion:Cancel(view.flashFill,"flash");view.flashFill.Visible,view.flashFill.ImageTransparency=false,1
end

-- ===== October 21 game feel helpers (docs/team/GAME_FEEL_20261021.md) =====
-- Plays the first authored cue of a list (a missing cue is silent, never an error).
function Browser:Cue(names,options)
	local audio=self.app.audio
	-- UI Lab stub apps carry an audio table without Has: stay silent there.
	if type(audio)~="table" or type(audio.Has)~="function" then return end
	for _,name in names do
		if audio:Has(name) then audio:Play(name,nil,options);return end
	end
end

-- The affordable glow: a slow lane-coloured pulse behind the rim (steady under reduced motion).
function Browser:GlowNode(view,color)
	if view.glowing and view.glowColor==color then return end
	view.glowing,view.glowColor=true,color
	view.glow.ImageColor3,view.glow.Visible=color,true
	Theme.Motion:Loop(view.glow,"glow",{ImageTransparency=.85},{ImageTransparency=.3},MOTION.GlowSeconds)
end

function Browser:StopGlow(view)
	if not view.glowing then return end
	view.glowing,view.glowColor=false,nil
	Theme.Motion:Cancel(view.glow,"glow")
	view.glow.Visible,view.glow.ImageTransparency=false,1
end

-- Lights the GlowLimit affordable hexes nearest the open map's centre hex and puts
-- every other glow out. Unchanged hexes are left alone, so snapshots do not restart it.
function Browser:RefreshGlow()
	local keep={}
	if self.root.Visible then
		local ready={}
		local origin=point(View.Nodes[View.Roots[self.category]])
		for _,id in View.Order[self.category] or {} do
			local view=self.nodes[id]
			if view.look=="available" and view.button.Visible and not self.pending[id] then
				table.insert(ready,{view=view,distance=(point(View.Nodes[id])-origin).Magnitude})
			end
		end
		table.sort(ready,function(a,b) return if a.distance==b.distance then a.view.id<b.view.id else a.distance<b.distance end)
		for index,entry in ready do
			if index>MOTION.GlowLimit then break end
			keep[entry.view]=entry.view
		end
	end
	for _,view in self.nodes do
		if keep[view] then self:GlowNode(view,laneColor(View.Nodes[view.id])) else self:StopGlow(view) end
	end
end

-- A hex-shaped colour wash over the fill that fades out (purchase, MAX).
function Browser:FlashNode(view,color,seconds)
	local flash=view.flashFill
	Theme.Motion:Cancel(flash,"flash")
	if self.app.reducedMotion then flash.Visible=false;return end
	flash.ImageColor3,flash.ImageTransparency,flash.Visible=color,.25,true
	Theme.Motion:Tween(flash,"flash",{ImageTransparency=1},seconds or MOTION.FlashSeconds,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,function() flash.Visible=false end)
end

-- A hex that grows out of the bought one and fades: the ripple (Motion:Ripple is a
-- rectangle, which would box the hex). Transient, above the hex, never takes input.
function Browser:RippleNode(view,color)
	if self.app.reducedMotion then return end
	local ring=Theme.Image(view.button,"Ripple",Assets.hexMask,UDim2.fromScale(144/164,164/144),UDim2.fromScale(.5,.5))
	ring.AnchorPoint,ring.Rotation,ring.ZIndex=Vector2.new(.5,.5),90,2
	ring.ImageColor3,ring.ImageTransparency=color,.55
	Theme.Motion:Tween(ring,"ripple",{Size=UDim2.fromScale(1.45*144/164,1.45*164/144),ImageTransparency=1},.45,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,function() ring:Destroy() end)
end

-- A lane-coloured spark that runs from a bought hex to the hex it opens (LinkSeconds,
-- Quart Out), then fades. Nothing travels under reduced motion.
function Browser:Spark(fromId,toId,color)
	if self.app.reducedMotion or not self.root.Visible then return end
	local a,b=point(View.Nodes[fromId]),point(View.Nodes[toId])
	local size=MOTION.SparkSize
	local spark=Theme.Frame(self.sparks,"Spark",UDim2.fromScale(size*930/1440,size),color)
	spark.AnchorPoint,spark.Position,spark.BackgroundTransparency=Vector2.new(.5,.5),UDim2.fromScale(a.X,a.Y),.1
	round(spark,.5)
	Theme.Motion:Tween(spark,"spark",{Position=UDim2.fromScale(b.X,b.Y),Size=UDim2.fromScale(size*.6*930/1440,size*.6)},MOTION.LinkSeconds,Enum.EasingStyle.Quart,Enum.EasingDirection.Out,function()
		Theme.Motion:Tween(spark,"spark",{BackgroundTransparency=1,Size=UDim2.fromScale(size*1.6*930/1440,size*1.6)},.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,function() spark:Destroy() end)
	end)
end

function Browser:ClearSparks()
	self.sparks:ClearAllChildren()
end

-- Dragging or pinching mutes the hover tick (the shared UI hover binding reads this
-- attribute), so sweeping across hexes does not machine-gun it.
function Browser:MuteHover(muted)
	self.root:SetAttribute("HoverAudioCue",if muted then "" else "SkillTreeHover")
end

-- Back to the main map: a short grow-in of the hexes nearest the middle of the view
-- (LaneLimit within LaneWindow) through each hex's own size owner, so it never fights
-- hover or press. The opening wave (Open, subtrees) is untouched.
function Browser:RevealLane()
	if self.app.reducedMotion or not self.root.Visible then return end
	local root=self.root.AbsoluteSize
	local sx,sy=root.Y/math.max(1,root.X)*1440/930*self.zoom,math.max(self.zoom,.01)
	local centre=Vector2.new(.5-self.pan.X/math.max(sx,.01),.5-self.pan.Y/sy)
	local items={}
	for _,id in View.Order[self.category] or {} do
		local view=self.nodes[id]
		if view.button.Visible and not view.pressed then table.insert(items,{view=view,distance=(point(View.Nodes[id])-centre).Magnitude}) end
	end
	table.sort(items,function(a,b) return if a.distance==b.distance then a.view.id<b.view.id else a.distance<b.distance end)
	local count=math.min(#items,MOTION.LaneLimit)
	local step=math.min(MOTION.OpenStaggerSeconds,MOTION.LaneWindow/math.max(1,count-1))
	for index=1,count do
		local view=items[index].view
		cancelSize(view)
		view.visual.Size=UDim2.fromScale(MOTION.FrontierEntryScale,MOTION.FrontierEntryScale)
		self:SizeNode(view,self:RestScale(view),MOTION.FrontierSeconds,(index-1)*step,function() view.revealing=false;self:RestNode(view) end)
		view.revealing=true
	end
end

-- The card grows in from the pointer corner with a small upward slide (Enter ease).
function Browser:EnterTooltip()
	local tip=self.tip
	local scale=Theme.Motion:ScaleOf(tip)
	Theme.Motion:Cancel(scale,"pop");Theme.Motion:Cancel(tip,"slide")
	if self.app.reducedMotion then scale.Scale,tip.AnchorPoint=1,Vector2.zero;return end
	scale.Scale,tip.AnchorPoint=MOTION.TipScale,Vector2.new(0,-MOTION.TipSlide)
	local ease=Theme.Motion.Ease.Enter
	Theme.Motion:Tween(scale,"pop",{Scale=1},MOTION.TipSeconds,ease.style,ease.direction)
	Theme.Motion:Tween(tip,"slide",{AnchorPoint=Vector2.zero},MOTION.TipSeconds,ease.style,ease.direction)
end

-- Server clock for older callers (ResearchExtras' Rally countdown).
function Browser:Now()
	return workspace:GetServerTimeNow()
end

-- The hex's rim flashes a colour and settles back (red refusals also wiggle the hex).
function Browser:FlashRim(view,color)
	if not view then return end
	cancelTween(view,"flash")
	if not self.app.reducedMotion then
		view.outline.ImageColor3=color
		view.flash=TweenService:Create(view.outline,TweenInfo.new(MOTION.FlashSeconds,Enum.EasingStyle.Quad),{ImageColor3=view.rimColor or WHITE})
		view.flash:Play()
	end
	-- Position-only wiggle; SizeNode owns the same Visual's Size.
	if color==RED then Theme.Motion:Shake(view.visual) end
end

-- A short line in the tree (loading, "owned", an unlock's how-to); refusals use Refuse.
function Browser:Feedback(text,color,id)
	self.message.Text,self.message.TextColor3,self.message.Visible=text,color,true
	self.message.TextTransparency=0
	Theme.Motion:PopScale(self.message,.9,.2)
	self.feedbackVersion=(self.feedbackVersion or 0)+1
	local version=self.feedbackVersion
	self:FlashRim(id and self.nodes[id],color)
	task.delay(2.2,function()
		if self.alive and version==self.feedbackVersion then self.message.Visible=false end
	end)
end

-- A refused buy, like the reference's t23: the red top banner (the shared notice),
-- the hex's rim flashes red and wiggles, and one soft "nope" (Locked). Locked shares
-- the banner's voice key, so the notice's own Error cue does not double it; without
-- an authored Locked the banner's Error plays alone.
function Browser:Refuse(text,id)
	self:Cue({"Locked"},{noFallback=true,voiceKey="ErrorNotification",cooldown=.25})
	self.app:Notify(text,false)
	self:FlashRim(id and self.nodes[id],RED)
end

-- "You need 3,096,960 more Coins!" from the server's price and balance; a starter
-- reserve hold (enough Coins, but kept for Army Size I) shows the server's reason.
function Browser:Shortfall(info)
	-- A hex with a server requirement says that first (none since October 22's Auto Vacuum).
	if type(info.requirement)=="string" and info.requirement~="" then return info.requirement end
	local price=type(info.price)=="number" and info.price or nil
	if price and self.coins<price then
		local short=math.ceil(price-self.coins)
		return "You need "..Theme.Money(short).." more "..(if short==1 then "Coin" else "Coins").."!"
	end
	return if type(info.spendReason)=="string" and info.spendReason~="" then info.spendReason else "Not enough Coins"
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

-- Special hexes (Start, Open, Back) always count as owned.
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
	self.state=state
	-- The UI Lab's Edit-mode fixture has no tree; it gets a display-only one there.
	self.tree=if type(state.upgradeTree)=="table" then state.upgradeTree
		elseif self.app.editPreview then View.PreviewTree() else nil
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
		-- Reference parity (t15): a buy shows the red "-price" beside the Coins and the
		-- hex's own payoff, no line of text; only unlocks (Egg Vacuum, Chicken Feed,
		-- machines) keep the server's how-to line, since it says what to do next.
		self:SpendDelta(request.price)
		if View.Plain(node) then
			self:Feedback(if type(result.message)=="string" and result.message~="" then result.message else request.text,GREEN,id)
		else self:FlashRim(self.nodes[id],GREEN) end
		local view=self.nodes[id]
		self:PulseNode(view)
		-- The last tier of a track: gold instead of the lane colour, a longer wash, the
		-- name punches (the tier lives in the name) and the MAX cue with fallbacks.
		local family=View.Family(node.family)
		local maxed=family~=nil and View.Tier(node.family,self.tree and self.tree.families)>=#family.tiers
		local color=if maxed then GOLD else laneColor(node)
		if maxed then
			self:Cue({"UpgradeMax","Shimmer","SkillTreeResearchCompleted"},{noFallback=true,voiceKey="UpgradeTier"})
			Theme.Motion:Punch(view.title,1.2,.35)
		else self:Cue({"TierUp"},{noFallback=true,voiceKey="UpgradeTier"}) end
		self:FlashNode(view,color,if maxed then MOTION.MaxFlashSeconds else MOTION.FlashSeconds)
		self:RippleNode(view,color)
		local p=point(node)
		Theme.Motion:Confetti(self.map,{count=12,origin=UDim2.fromScale(p.X,p.Y),spread=.15,seconds=1,
			colors=if maxed then {GOLD,WHITE,Theme.ReferenceColors.Base} else {color,WHITE,GOLD}})
		-- Keep gamepad focus on the family: its next tier is now the one to buy.
		local nextId=View.NextId(node.family,self.tree)
		local nextView=nextId and nextId~=id and self.nodes[nextId]
		if nextView and nextView.button.Visible and nextView.look~="unknown" and GuiService.SelectedObject==view.button then
			GuiService.SelectedObject=nextView.button
		end
	else
		-- The server's plain "Not enough coins." reads as the reference's shortfall.
		local message=if type(result.message)=="string" and result.message~="" then result.message else "Upgrade changed. Try again."
		local info=self:Info(id)
		if message:lower():find("^not enough coins") and info and type(info.price)=="number" then message=self:Shortfall(info) end
		-- October 23: short of Coins opens the closest Coins pack's checkout instead.
		if not (type(result.needCoins)=="number" and self.app.commerce and self.app.commerce:BuyCoins(result.needCoins,message)) then self:Refuse(message,id) end
	end
	return true
end

function Browser:Render()
	local reveals={}
	self.badgeRose=false
	for _,category in View.Categories do
		for _,id in View.Order[category] do
			local entry=self:RenderNode(id)
			if entry and category==self.category then table.insert(reveals,entry) end
		end
	end
	-- A badge that appears or rises while the tree is open (Coins came in: a price turned
	-- green, a hub's count went up) chimes once. A purchase render has its own payoff,
	-- and the HUD's Badge in the same frame is held back by the shared cooldown.
	if self.badgeRose and not self.revealOrigin then self:Cue({"Badge"},{noFallback=true}) end
	self:RevealNodes(reveals)
	self:RefreshGlow()
	-- The Coins readout counts up with ticks and a small punch on gains; a spend drops
	-- at once. Opening snaps to the balance instead of counting from the last visit.
	local snap=self.snapCoins;self.snapCoins=nil
	self:RenderCounters(self.state,not snap)
	Theme.Motion:CountTo(self.cash,self.coins or 0,Theme.Money,if snap then 0 else .45,if snap then {punch=false} else {
		punch=1.08,punchTarget=self.cash.Parent,tickGap=.06,
		tick=function() self.app.audio:Play("CountTick",nil,{noFallback=true,voiceKey="UpgradesCountTick",cooldown=.05,pitchVariance=.05}) end,
	})
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
		view.fill.ImageTransparency,view.outline.ImageTransparency=style.transparency or 0,style.transparency or 0
		if not view.flash or view.flash.PlaybackState~=Enum.PlaybackState.Playing then view.outline.ImageColor3=style.rim end
	end
	local waiting=self.pending[id]~=nil
	view.icon.Visible=not hidden and view.icon.Image~=""
	view.title.Visible,view.hidden.Visible=not hidden,hidden
	view.numeral.Visible=not hidden and kind=="upgrade" and node.numeral~=nil
	-- Prices only on hexes you can still buy: green when affordable, red when not.
	local buyable=look=="available" or look=="unaffordable"
	-- Live state changes (not the first styling after Open): a red price turning green
	-- pulses the hex once; a price that appears punches.
	local live=view.look~=nil and view.button.Visible and self.root.Visible and not self.opening
	if live and view.look=="unaffordable" and look=="available" then self:PulseNode(view,MOTION.ReadyScale) end
	if live and buyable and not view.cost.Visible then Theme.Motion:Punch(view.cost,1.15,.3) end
	view.cost.Visible=buyable
	view.cashIcon.Visible=not waiting
	view.price.Position=UDim2.fromScale(if waiting then 0 else COST_TEXT,0)
	view.price.Size=UDim2.fromScale(if waiting then 1 else 1-COST_TEXT,1)
	view.price.TextXAlignment=if waiting then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
	view.price.Text=if waiting then "…" elseif info and type(info.price)=="number" then Theme.Number(info.price) else ""
	view.price.TextColor3=if look=="unaffordable" then RED else GREEN
	-- Reference parity (supersedes the October 21 "no ! on hexes" note): a red "!" on
	-- every upgrade you can buy now, and on an Open hex how many inside you can buy.
	local count=if kind=="open" then self:Badge(node.opens) else 0
	local ready=kind=="upgrade" and look=="available" and not waiting
	local shown=count>0 or ready
	if live and shown and ((ready and view.look=="unaffordable") or (kind=="open" and count>(view.badgeCount or 0))) then
		Theme.Motion:Punch(view.badge,1.35,.3)
		self.badgeRose=true
	end
	view.badge.Visible=shown
	view.badgeText.Text=if ready then "!" elseif count>99 then "99+" else tostring(count)
	view.badgeCount=count
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
	local shown=self.tip.Visible and not self.tipHiding
	self.selected,self.persistent=id,persistent
	self.tipHiding=nil
	self.tip.Visible=true
	self:RenderTooltip()
	if changed or not shown then self:EnterTooltip() end
end

-- The card leaves quickly (a small shrink); re-selecting during the shrink cancels it.
function Browser:DismissTooltip()
	self.selected,self.persistent=nil,false
	local tip=self.tip
	if not tip.Visible or self.tipHiding then return end
	Theme.Motion:Cancel(tip,"slide");tip.AnchorPoint=Vector2.zero
	local scale=Theme.Motion:ScaleOf(tip)
	if self.app.reducedMotion then Theme.Motion:Cancel(scale,"pop");scale.Scale,tip.Visible=1,false;return end
	self.tipHiding=true
	local ease=Theme.Motion.Ease.Leave
	Theme.Motion:Tween(scale,"pop",{Scale=.94},MOTION.TipLeaveSeconds,ease.style,ease.direction,function()
		if not self.tipHiding then return end
		self.tipHiding=nil;tip.Visible,scale.Scale=false,1
	end)
end

function Browser:PlaceTooltip()
	if not self.selected then return end
	local rootSize,origin=self.root.AbsoluteSize,self.root.AbsolutePosition
	if rootSize.X<=0 or rootSize.Y<=0 then return end
	-- Reference parity (t15, t17): the card sits beside the hex, its top near the hex's
	-- top, on the right unless it would leave the screen (then on the left). The gap
	-- clears the hex's hover growth. It stays above the bottom Close/Back button.
	local button=self.nodes[self.selected].button
	local p,s=button.AbsolutePosition-origin,button.AbsoluteSize
	local tipSize=self.tip.AbsoluteSize
	local margin=rootSize.Y*.012
	local gap=s.X*(MOTION.HoverScale-1)/2+margin
	local floor=rootSize.Y*.88
	local x=p.X+s.X+gap
	if x+tipSize.X>rootSize.X-margin then x=p.X-gap-tipSize.X end
	local y=p.Y+s.Y*.05
	x=math.clamp(x,margin,math.max(margin,rootSize.X-tipSize.X-margin))
	y=math.clamp(y,margin,math.max(margin,floor-tipSize.Y))
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
	if look=="unknown" then
		local prerequisite=node.prerequisite and View.Nodes[node.prerequisite]
		return "Locked",if prerequisite then "Buy "..prerequisite.name.." first." else "Not available yet.",nil,nil,nil
	end
	local info=self:Info(id) or {}
	local body=View.Description(node)
	local before,after=View.Change(node)
	local special,specialOwned=View.Lines(node,self.app.state and self.app.state.effects)
	local change=if special then (if look=="owned" then "Owned: "..specialOwned else special)
		elseif View.Plain(node) then (if look=="owned" then "Owned" else nil)
		elseif look=="owned" then "Owned: "..after else before.." → "..after
	if node.family=="Luck" then
		local nextId=View.NextId("Luck",self.tree)
		local odds=if id==nextId and self.tree then luckText(self.tree.luck,look~="owned") else nil
		if odds then body..=" "..odds end
		body..=" All normal chickens remain possible."
		local eventOdds=Browser.EventOdds(workspace:GetServerTimeNow())
		if eventOdds then body..=" "..eventOdds.."." end
	end
	-- A starter-reserve hold (enough Coins, but kept back) says why; a plain shortfall
	-- needs no words, the red price already says it.
	local held=look=="unaffordable" and type(info.price)=="number" and self.coins>=info.price
	if look=="unaffordable" and type(info.requirement)=="string" and info.requirement~="" then body..=" "..info.requirement
	elseif held and type(info.spendReason)=="string" and info.spendReason~="" then body..=" "..info.spendReason end
	local price=if look~="owned" and type(info.price)=="number" then info.price else nil
	return node.name,body,change,price,"Resets on Rebirth"
end

function Browser:RenderTooltip()
	local id=self.selected;if not id or not self.nodes[id] then return end
	local title,body,change,price,footer=self:TooltipText(id)
	local titleText,titleRows=wrap(title,20)
	-- One effect sentence: the description, then the changing value in green
	-- (current → next, or what an owned tier gives).
	local segments:{{text:string,green:boolean?}}={{text=body}}
	if change then table.insert(segments,{text=change,green=true}) end
	local bodyText,bodyRows=richWrap(segments,26)
	-- Heights in card units; the card is 240 units wide (TipWidth).
	local y=10
	local titleY=y;y+=28*titleRows+6
	local bodyY=y;y+=bodyRows*23+6
	local dividerY,costY=y,y
	if price then costY=y+10;y=costY+30+6 end
	local footerY=y;if footer then y+=20 end
	local height=y+8
	local tipWidth=self:TipWidth()
	self.tip.Size=UDim2.fromScale(1,tipWidth*height/240)
	self.tipAspect.AspectRatio=240/height
	self.tipTitle.Text=titleText
	self.tipTitle.Position,self.tipTitle.Size=UDim2.fromScale(.055,titleY/height),UDim2.fromScale(.89,28*titleRows/height)
	-- The same card re-rendered with a new value (a purchase under the pointer): the
	-- sentence punches. Switching hexes only animates the card itself.
	local same=self.tipId==id
	self.tipId=id
	if same and self.tipEffect.Text~=bodyText then Theme.Motion:Punch(self.tipEffect,1.06,.3) end
	self.tipEffect.Text=bodyText
	self.tipEffect.Position,self.tipEffect.Size=UDim2.fromScale(.055,bodyY/height),UDim2.fromScale(.89,bodyRows*23/height)
	self.tipDivider.Visible=price~=nil
	self.tipDivider.Position,self.tipDivider.Size=UDim2.fromScale(.055,(dividerY+2)/height),UDim2.fromScale(.89,2/height)
	local priceText=if price then Theme.Money(price) else ""
	if same and self.tipCost.Visible and price~=nil and self.tipPrice.Text~=priceText then Theme.Motion:Punch(self.tipCost,1.1,.3) end
	self.tipCost.Visible=price~=nil
	self.tipCost.Position,self.tipCost.Size=UDim2.fromScale(.055,costY/height),UDim2.fromScale(.89,30/height)
	self.tipPrice.Text=priceText
	-- Gold like every Coins amount; red when it is more than you have (or held back).
	self.tipPrice.TextColor3=if self.nodes[id].look=="unaffordable" then RED else COIN
	self.tipFooter.Visible=footer~=nil
	self.tipFooter.Position,self.tipFooter.Size=UDim2.fromScale(.055,footerY/height),UDim2.fromScale(.89,18/height)
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
	-- Open and Back hexes answer with the map-change cues in ShowCategory, not a Click.
	if node.kind=="open" then self:ShowCategory(node.opens);return end
	if node.kind=="back" then self:ShowCategory("Main");return end
	local info=if node.kind=="upgrade" then self:Info(id) else nil
	local refused=info~=nil and not self.pending[id] and info.status~="Owned" and not (info.status=="Available" and type(info.price)=="number")
	-- A press answers with a Click at once; a refusal answers with its own "nope" instead.
	if not refused then self.app.audio:Play("Click") end
	if node.kind~="upgrade" or self.pending[id] then return end
	if not info then self:Feedback("Upgrades are loading…",WHITE,id);return end
	if info.status=="Owned" then self:Feedback(node.name..": owned",GREEN,id)
	elseif info.status=="Available" and type(info.price)=="number" then self:Purchase(id,info.price)
	elseif info.status=="Unaffordable" then
		-- October 23: short of Coins opens the closest Coins pack's checkout instead.
		local short=if type(info.price)=="number" and (info.requirement or "")=="" then info.price-self.coins else 0
		if not (short>0 and self.app.commerce and self.app.commerce:BuyCoins(math.ceil(short),self:Shortfall(info))) then self:Refuse(self:Shortfall(info),id) end
	else
		local prerequisite=node.prerequisite and View.Nodes[node.prerequisite]
		self:Refuse(if prerequisite then "Buy "..prerequisite.name.." first" else "Not available yet",id)
	end
end

function Browser:Purchase(id,price)
	-- The success line, worded from the card's state before the purchase.
	local node=View.Nodes[id]
	local before,after=View.Change(node)
	local special=View.Lines(node,self.app.state and self.app.state.effects)
	local text=if special then node.name..": "..special elseif View.Plain(node) then node.name.." bought!" else node.name..": "..before.." → "..after
	local requestId=self.app:Request("BuyUpgrade",{nodeId=id,expectedPrice=price})
	if not requestId then return end
	self.pending[id]=requestId
	self.requests[requestId]={nodeId=id,text=text,price=price}
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
	-- The reference's bottom button: Close on the main tree, Back in a subtree (the
	-- subtree's name is on its red Back hex, so there is no title).
	self.closeButton.Text=if category=="Main" then "Close" else "Back"
end

-- Open a subtree (its hexes pop in from Back) or return to the main tree where
-- the player left it.
function Browser:ShowCategory(category)
	if not self.layers[category] or category==self.category then return end
	self:DismissTooltip()
	self:ClearSparks()
	-- A hidden map gets no MouseLeave, so its hexes forget the pointer here.
	for _,id in View.Order[self.category] or {} do
		local view=self.nodes[id];view.hovered,view.focused,view.pressed,view.pressInput=false,false,false,nil
	end
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
	else self:Cue({"TabSwitch","Click"},{voiceKey="Click"}) end
	self:Render()
	self.opening=false
	if saved then self.zoom,self.pan=saved.zoom,saved.pan;self:Transform();self:RevealLane() else self.zoom=1;self:Center(View.Roots[category]) end
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
		if delta.Magnitude>8 and not drag.moved then drag.moved=true;self:MuteHover(true);self:ReleasePress(nil,true);self:DismissTooltip() end
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
		if not inside(self.root,p) or inside(self.exit,p) or inside(self.closeButton,p) then return end
		if self.drag then self.drag=nil;self:MuteHover(false);self.suppressUntil=os.clock()+.4;return end
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
			self:MuteHover(false)
		end
	end)
	connect(UserInputService.TouchPinch,function(positions,scale,_,state)
		if not self.root.Visible or #positions<2 then return end
		self.drag=nil;self:ReleasePress(nil,true);self.suppressUntil=os.clock()+.4
		self:MuteHover(state~=Enum.UserInputState.End)
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
	-- The world blurs behind the tinted tree. Taken before closing the other menu so
	-- the shared blur never drops in between (AppController.CloseOtherMenus).
	self.app:SetMenuBlur("research",true)
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
	self.snapCoins=true
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
	self.app:SetMenuBlur("research",false)
	self:MuteHover(false)
	self.message.Visible=false;self.feedbackVersion=(self.feedbackVersion or 0)+1
	self.delta.Visible=false;self.deltaVersion=(self.deltaVersion or 0)+1
	self.opening,self.revealOrigin,self.pinchScale=false,nil,nil
	self:ClearSparks()
	local confetti=self.map:FindFirstChild("MotionConfetti")
	if confetti then confetti:Destroy() end
	for _,view in self.nodes do
		self:ResetNodeMotion(view)
		for _,child in view.button:GetChildren() do if child.Name=="Ripple" then child:Destroy() end end
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
