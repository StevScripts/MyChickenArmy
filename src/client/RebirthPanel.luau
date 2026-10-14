--!strict
-- Re-enlist (rebirth) presentation: the Upgrades-screen hex and the hold-to-confirm
-- panel. The server quote (state.rebirth) is authoritative; this module never
-- changes saved state. AppController calls Render(state, result) on every packet.
-- Contract: docs/team/launch/12_R1_REBIRTH_CLIENT.md.
local GuiService=game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local Theme=require(script.Parent.UITheme)
local MenuLayout=require(script.Parent.MenuLayout)
local Assets=require(script.Parent.ResearchAssets)
local CashNodes=require(script.Parent.CashUpgradeNodes)
local Panel={}
Panel.__index=Panel

local HEX=CashNodes.Reenlist
local GREEN=Theme.ReferenceColors.Army
local GOLD=Theme.ReferenceColors.Base
local WHITE=Color3.new(1,1,1)
local MUTED=Color3.fromRGB(64,67,65)
local RED=Color3.fromRGB(255,107,83)
local HOLD_SECONDS=2
-- October 13 redesign (simulator rebirth pattern): rank → next rank, two
-- before → after reward pills, one reset line, a cost bar and the hold button.
local RESET_LINE="Resets cash, Egg Speed, Egg Value, Luck and camps"
local KEEP_LINE="Keeps chickens, Giants, research, plot and army size"
local ENEMY_RED=Color3.fromRGB(232,62,48)

local NUMERALS={{1000,"M"},{900,"CM"},{500,"D"},{400,"CD"},{100,"C"},{90,"XC"},{50,"L"},{40,"XL"},{10,"X"},{9,"IX"},{5,"V"},{4,"IV"},{1,"I"}}
-- Fallback title while only the foundation stub quote is available.
function Panel.Title(rank: number): string
	rank=math.max(0,math.floor(rank or 0))
	if rank==0 then return "Recruit" end
	local text=""
	for _,pair in NUMERALS do
		while rank>=pair[1] do text..=pair[2];rank-=pair[1] end
	end
	return "Veteran "..text
end

-- The foundation stub carries only {rank, eligible, reason}; the full quote adds
-- kingCleared (present even at max rank, where cost/nextRank are nil).
local function full(quote): boolean
	return type(quote)=="table" and quote.kingCleared~=nil
end

local function enabled(quote): boolean
	if type(quote)~="table" then return false end
	if quote.enabled==nil then return true end
	return quote.enabled==true
end

local function multiplier(value,decimals)
	return "×"..string.format("%."..decimals.."f",tonumber(value) or 1)
end

local function money(value)
	return "$"..Theme.Number(tonumber(value) or 0)
end

local function label(parent,name,text,x,y,w,h,color)
	local item=Theme.Label(parent,name,text,20,color or WHITE)
	item.Position,item.Size=UDim2.fromScale(x,y),UDim2.fromScale(w,h)
	item.TextScaled,item.TextXAlignment=true,Enum.TextXAlignment.Center
	return item
end

local function bar(parent,name,track,fillColor)
	local frame=Theme.Frame(parent,name,UDim2.fromScale(1,1),track)
	frame:SetAttribute("OwnsPopupStyle",true)
	local fill=Theme.Frame(frame,"Fill",UDim2.fromScale(0,1),fillColor)
	fill.ZIndex=frame.ZIndex+1
	return frame,fill
end

function Panel.new(app)
	return setmetatable({app=app,connections={},hexConnections={},quote=nil,lastRank=nil,
		pending=nil,holding=false,holdToken=0},Panel)
end

-- Hex ----------------------------------------------------------------------
-- A fixed overlay on the research screen (same hex art and states as the cash
-- tiers), so it stays visible regardless of map pan/zoom and occupies no map cell.
function Panel:BuildHex()
	local research=self.app.research
	if self.hex or not research or not research.root then return end
	local root=research.root
	local button=Instance.new("ImageButton")
	button.Name,button.Image,button.BackgroundTransparency="ReenlistHex","",1
	button.AnchorPoint,button.Position,button.Size=Vector2.new(1,0),UDim2.fromScale(.985,.12),UDim2.fromScale(.16,.25)
	button.AutoButtonColor,button.Selectable,button.Visible,button.ZIndex=false,true,false,6
	button:SetAttribute("HoverAudioCue","SkillTreeHover")
	button.Parent=root
	Theme.Aspect(button,144/164)
	local visual=Theme.Container(button,"Visual")
	visual.AnchorPoint,visual.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
	local halos={}
	for i=1,6 do
		local spread=(7-i)*.018
		local halo=Theme.Image(visual,"Halo"..i,Assets.hexMask,UDim2.fromScale(1+spread,1+spread),UDim2.fromScale(.5,.5))
		halo.AnchorPoint,halo.ZIndex=Vector2.new(.5,.5),1
		table.insert(halos,halo)
	end
	local outline=Theme.Image(visual,"Outline",Assets.hexMask,UDim2.fromScale(1,1));outline.ZIndex=2
	local fill=Theme.Image(visual,"Fill",Assets.hexFill,UDim2.fromScale(.951,.951),UDim2.fromScale(.0245,.0245));fill.ZIndex=3
	local gradient=Theme.Gradient(fill,WHITE,Color3.fromRGB(226,244,221))
	local icon=Theme.Image(visual,"Icon",Assets[HEX.icon],UDim2.fromScale(.56,.38),UDim2.fromScale(.22,.15));icon.ZIndex=4
	local title=label(visual,"Title",HEX.name,.025,.53,.95,.11);title.ZIndex=5
	title.TextOutline.Thickness=.035
	local status=label(visual,"Status","",.1,.645,.8,.085);status.ZIndex=5
	status.TextOutline.Thickness=.035
	local track=Theme.Frame(visual,"Progress",UDim2.fromScale(.6,.055),Color3.fromRGB(16,40,12))
	track.Position,track.ZIndex=UDim2.fromScale(.2,.75),5
	Theme.Stroke(track,Color3.new(0,0,0),1)
	local progress=Theme.Frame(track,"Fill",UDim2.fromScale(0,1),GREEN);progress.ZIndex=6
	local badge=Theme.Frame(visual,"RankBadge",UDim2.fromScale(.56,.115),Color3.fromRGB(22,84,30))
	badge.AnchorPoint,badge.Position,badge.ZIndex=Vector2.new(.5,0),UDim2.fromScale(.5,.04),6
	Theme.Stroke(badge,Color3.fromRGB(179,255,155),1.5)
	local badgeText=label(badge,"Text","",.06,.02,.88,.96);badgeText.ZIndex=7
	badgeText.TextOutline.Thickness=.02
	-- Gamepad: the research map's D-pad only walks its own hexes, so L2 opens this one.
	local hint=label(visual,"GamepadHint","L2",.36,.84,.28,.08,WHITE);hint.ZIndex=5
	hint.TextOutline.Thickness=.035
	self.hex={button=button,visual=visual,halos=halos,outline=outline,fill=fill,gradient=gradient,icon=icon,
		title=title,status=status,track=track,progress=progress,badge=badge,badgeText=badgeText,hint=hint}
	table.insert(self.hexConnections,button.Activated:Connect(function()
		-- A map drag that started on the hex must not also open the panel.
		if os.clock()<(research.suppressUntil or 0) then return end
		self.app.audio:Play("Click")
		self:Open()
	end))
	local function syncShortcut()
		local want=root.Visible and button.Visible
		if want==self.shortcutBound then return end
		self.shortcutBound=want
		if want then
			ContextActionService:BindActionAtPriority("PetRollReenlistShortcut",function(_,inputState)
				if inputState==Enum.UserInputState.Begin then self.app.audio:Play("Click");self:Open() end
				return Enum.ContextActionResult.Sink
			end,false,3600,Enum.KeyCode.ButtonL2)
		else ContextActionService:UnbindAction("PetRollReenlistShortcut") end
	end
	self.syncShortcut=syncShortcut
	table.insert(self.hexConnections,root:GetPropertyChangedSignal("Visible"):Connect(syncShortcut))
	table.insert(self.hexConnections,button:GetPropertyChangedSignal("Visible"):Connect(syncShortcut))
end

function Panel:Pulse(view,on)
	if view.pulse then view.pulse:Cancel();view.pulse:Destroy();view.pulse=nil end
	view.visual.Size=UDim2.fromScale(1,1)
	if not on or self.app.reducedMotion then return end
	view.pulse=TweenService:Create(view.visual,TweenInfo.new(.8,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Size=UDim2.fromScale(1.04,1.04)})
	view.pulse:Play()
end

function Panel:RenderHex()
	self:BuildHex()
	local view,quote=self.hex,self.quote
	if not view then return end
	local visible=type(quote)=="table" and enabled(quote)
	view.button.Visible=visible
	if not visible then self:Pulse(view,false);return end
	local complete=full(quote)
	local king=complete and quote.kingCleared==true
	local eligible=complete and quote.eligible==true
	local locked=not king
	local cost,coins=tonumber(quote.cost),tonumber(quote.coins) or 0
	local ratio=if eligible then 1 elseif cost and cost>0 then math.clamp(coins/cost,0,1) else 0
	local color=if eligible then GREEN elseif locked then Color3.fromRGB(62,62,62) else Color3.fromRGB(164,164,164)
	view.fill.Image=if eligible then Assets.hexMask else Assets.hexFill
	view.fill.ImageColor3=color
	view.gradient.Enabled=eligible
	view.outline.ImageColor3=if eligible then Color3.fromRGB(179,255,155) elseif locked then MUTED else GREEN:Lerp(Color3.new(0,0,0),.5)
	for i,halo in view.halos do
		halo.ImageColor3=GREEN
		halo.ImageTransparency=if locked then 1 elseif eligible then 1-(.045+i*.016) else 1-(.01+i*.004)
	end
	view.icon.ImageTransparency=if locked then .65 else 0
	view.title.TextTransparency=if locked then .35 else 0
	view.title.TextOutline.Transparency=if locked then .35 else 0
	view.status.Text=if not complete then (quote.reason or "Coming soon")
		elseif not king then "Defeat the Chicken King"
		elseif eligible then "Tap to rebirth"
		else quote.reason or (if cost then money(cost) else "")
	view.status.TextColor3=if eligible then WHITE elseif locked then Color3.fromRGB(176,176,176) else RED
	view.track.Visible=king and (cost~=nil or eligible)
	view.progress.Size=UDim2.fromScale(ratio,1)
	view.progress.BackgroundColor3=if eligible then Color3.fromRGB(176,255,1) else GREEN
	local nextTitle=if complete then quote.nextTitle else Panel.Title((tonumber(quote.rank) or 0)+1)
	view.badge.Visible=nextTitle~=nil
	view.badgeText.Text=nextTitle or ""
	view.hint.Visible=UserInputService.GamepadEnabled
	view.button:SetAttribute("ReenlistState",if eligible then "Eligible" elseif locked then "Locked" else "Progress")
	if (view.pulsing==true)~=eligible or self.app.reducedMotion~=view.reduced then
		view.pulsing,view.reduced=eligible,self.app.reducedMotion
		self:Pulse(view,eligible)
	end
	if self.syncShortcut then self.syncShortcut() end
end

-- Panel --------------------------------------------------------------------
function Panel:Open()
	local quote=self.quote
	if type(quote)~="table" or not enabled(quote) or self.app.commerce.cratePresenting then return end
	if not full(quote) then self.app:Notify(quote.reason or "Coming soon","info");return end
	if self.gui and not self.closing then self:RenderPanel();return end
	self:Dismiss(true)
	local research=self.app.research
	self.fromResearch=research~=nil and research.root.Visible
	-- Acquire the blur before closing the other menu so its exit cannot clear it.
	self.app:SetMenuBlur("rebirth",true)
	self.app:ClosePanel()
	self.app.offlineCash:Dismiss(true)
	if self.app.dailyReward then self.app.dailyReward:Dismiss(true) end
	self.previousSelection=GuiService.SelectedObject
	self.message,self.messageColor=nil,nil
	self:Build()
	self:RenderPanel()
	if self.app.editPreview then return end
	ContextActionService:BindActionAtPriority("PetRollReenlistClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then self:Close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	ContextActionService:BindActionAtPriority("PetRollReenlistHold",function(_,inputState)
		if GuiService.SelectedObject~=self.hold then return Enum.ContextActionResult.Pass end
		if inputState==Enum.UserInputState.Begin then self:BeginHold("gamepad")
		elseif inputState==Enum.UserInputState.End or inputState==Enum.UserInputState.Cancel then self:EndHold() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonA)
	local function connect(signal,callback) table.insert(self.connections,signal:Connect(callback)) end
	connect(UserInputService.InputBegan,function(input)
		if input.KeyCode==Enum.KeyCode.Escape then self:Close() end
	end)
	connect(UserInputService.InputEnded,function(input)
		local holdInput=self.holdInput
		if holdInput and holdInput~="gamepad" and (input==holdInput
			or (input.UserInputType==Enum.UserInputType.MouseButton1 and holdInput.UserInputType==Enum.UserInputType.MouseButton1)) then
			self:EndHold()
		end
	end)
	-- Another menu opening replaces this one.
	if self.app.panel then
		connect(self.app.panel:GetPropertyChangedSignal("Visible"),function() if self.app.panel.Visible then self.fromResearch=false;self:Dismiss(true) end end)
	end
	if research then
		connect(research.root:GetPropertyChangedSignal("Visible"),function() if research.root.Visible then self.fromResearch=false;self:Dismiss(true) end end)
	end
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=self.hold end
end

function Panel:Build()
	local app=self.app
	local gui=if app.editPreview then Theme.Container(app.other,"Reenlist")
		else Theme.InsetContainer(app.other,"Reenlist",Enum.ScreenInsets.CoreUISafeInsets)
	gui.ZIndex=30
	self.gui,self.closing=gui,false
	local frames=Theme.Container(gui,"FRAMES")
	-- The tap blocker covers the full device screen, past phone notches.
	local backdropParent=if app.editPreview then frames else Theme.InsetContainer(frames,"BackdropLayer",Enum.ScreenInsets.None)
	local backdrop=Theme.Frame(backdropParent,"Backdrop",UDim2.fromScale(1,1))
	backdrop.BackgroundTransparency,backdrop.Active=1,true
	local panel=Instance.new("CanvasGroup")
	panel.Name="Reenlist"
	panel.BackgroundTransparency,panel.BorderSizePixel,panel.GroupTransparency=1,0,1
	panel.Active,panel.ZIndex=true,2
	panel.AnchorPoint,panel.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.5)
	panel.Parent,self.panel=frames,panel
	-- Studio may author PetRollGui.MenuLayouts.Rebirth; otherwise one native
	-- composition fills most of a phone and stays a centered dialog on desktop.
	if MenuLayout.Control(app.gui,"Rebirth") then MenuLayout.Apply(app.gui,"Rebirth",panel)
	else
		panel.Size=UDim2.fromScale(.94,.66)
		Theme.Aspect(panel,1.4)
	end
	self.panelSize,self.panelPosition=panel.Size,panel.Position
	local header,title=Theme.Header(panel,"Header","Rebirth",GREEN)
	self.title=title
	-- The shared header's icon slot carries the Re-enlist badge (title shifts right).
	header.PageIcon.Image,header.PageIcon.Visible=Theme.Assets.Reenlist,true
	Theme.LayoutHeader(header)
	local main=Theme.Container(panel,"Main")
	Theme.BelowHeader(header,main)
	Theme.Surface(main,Theme.PageSurfaces.Army)
	main.UIStroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	-- Rank row: current badge → next badge.
	local function rankCard(name,x,accent)
		local card=Theme.Frame(main,name,UDim2.fromScale(.34,.3),Color3.fromRGB(24,30,26))
		card.Position=UDim2.fromScale(x,.04)
		card:SetAttribute("OwnsPopupStyle",true)
		Theme.Stroke(card,accent,3)
		local badge=Theme.Image(card,"Badge",Theme.Assets.RecruitBadge,UDim2.fromScale(.5,.66),UDim2.fromScale(.25,.04))
		Theme.Aspect(badge,1)
		local name=label(card,"Rank","",.04,.7,.92,.26,accent)
		return card,badge,name
	end
	local _,nowBadge,nowName=rankCard("Current",.06,Color3.fromRGB(196,206,200))
	local nextCard,nextBadge,nextName=rankCard("Next",.6,GOLD)
	local arrow=label(main,"Arrow","→",.42,.1,.16,.18,WHITE)
	self.nowBadge,self.nowName,self.nextCard,self.nextBadge,self.nextName,self.arrow=nowBadge,nowName,nextCard,nextBadge,nextName,arrow
	-- Reward pills: icon, "×1.00 → ×1.25", caption.
	local function pill(name,x,icon,color,caption)
		local frame=Theme.Frame(main,name,UDim2.fromScale(.43,.2),color)
		frame.Position=UDim2.fromScale(x,.38)
		frame:SetAttribute("OwnsPopupStyle",true)
		Theme.Gradient(frame,color:Lerp(WHITE,.18),color:Lerp(Color3.new(0,0,0),.28))
		Theme.Stroke(frame,Color3.new(0,0,0),3)
		local art=Theme.Image(frame,"Icon",icon,UDim2.fromScale(.26,1.1),UDim2.fromScale(-.02,-.05))
		Theme.Aspect(art,1);art.ZIndex=6
		local value=label(frame,"Value","",.26,.04,.72,.6,WHITE)
		local note=label(frame,"Caption",caption,.26,.62,.72,.32,Color3.fromRGB(240,248,240))
		return value,note
	end
	self.eggValue,self.eggNote=pill("Eggs",.05,Assets.egg,Color3.fromRGB(64,176,36),"Egg value forever")
	self.enemyValue,self.enemyNote=pill("Enemies",.52,Theme.Assets.EnemyStrength,ENEMY_RED,"Camps and King strength")
	local reset=label(main,"Resets",RESET_LINE,.05,.605,.9,.06,Color3.fromRGB(255,120,104))
	local keep=label(main,"Keeps",KEEP_LINE,.05,.665,.9,.05,Color3.fromRGB(176,236,150))
	reset.TextXAlignment,keep.TextXAlignment=Enum.TextXAlignment.Center,Enum.TextXAlignment.Center
	-- Cost bar: progress toward the next rank, or the King requirement.
	local track,fill=bar(main,"CostProgress",Color3.fromRGB(14,24,14),GREEN)
	track.Position,track.Size=UDim2.fromScale(.06,.735),UDim2.fromScale(.88,.08)
	Theme.Stroke(track,Color3.new(0,0,0),3)
	Theme.ApplyReferenceAccent(fill,Theme.ReferenceGradients.Army)
	local lock=Theme.Image(track,"Lock",Theme.Assets.Padlock,UDim2.fromScale(.07,1.5),UDim2.fromScale(.005,-.25))
	Theme.Aspect(lock,1);lock.ZIndex=8
	local costText=label(track,"Label","",.08,.05,.84,.9,WHITE)
	costText.ZIndex,costText.TextXAlignment=8,Enum.TextXAlignment.Center
	self.costTrack,self.costFill,self.costText,self.costLock=track,fill,costText,lock
	local actions=Theme.Container(main,"Actions")
	actions.AnchorPoint,actions.Position,actions.Size=Vector2.new(.5,1),UDim2.fromScale(.5,.975),UDim2.fromScale(.6,.13)
	-- Hold control stays at least 44 points tall on the smallest phones.
	local minimum=Instance.new("UISizeConstraint")
	minimum.MinSize,minimum.Parent=Vector2.new(0,44),actions
	local hold=Theme.ActionButton(actions,"Confirm","Hold to rebirth",function() end,GREEN)
	hold.Position,hold.Size=UDim2.fromScale(0,0),UDim2.fromScale(1,1)
	Theme.Studs(hold.Visual.Face,.07,28,0)
	hold.Visual.Caption.Position,hold.Visual.Caption.Size=UDim2.fromScale(.04,.1),UDim2.fromScale(.92,.8)
	hold.Visual.Caption.TextScaled=true
	hold.Visual.Caption.TextShadow.Visible=false
	-- Fill sits between the studded face and the caption; it drains when released early.
	local holdFill=Theme.Frame(hold.Visual.Face,"HoldFill",UDim2.fromScale(0,1),WHITE)
	holdFill.BackgroundTransparency,holdFill.ZIndex=.55,4
	self.hold,self.holdFill=hold,holdFill
	table.insert(self.connections,hold.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
			self:BeginHold(input)
		end
	end))
	Theme.HeaderClose(header,function() self.app.audio:Play("Click");self:Close() end)
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	local restingSize,restingPosition=self.panelSize,self.panelPosition
	if not app.reducedMotion then
		panel.Size=UDim2.fromScale(restingSize.X.Scale*.94,restingSize.Y.Scale*.94)
		panel.Position=UDim2.fromScale(restingPosition.X.Scale,restingPosition.Y.Scale+.035)
	end
	Theme.Motion:Tween(panel,"reenlist-size",{Size=restingSize},.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	Theme.Motion:Tween(panel,"position",{Position=restingPosition},.28)
	Theme.Motion:Tween(panel,"reenlist-fade",{GroupTransparency=0},.22)
end

function Panel:CanConfirm(): boolean
	local quote=self.quote
	return self.gui~=nil and not self.closing and self.pending==nil and full(quote) and enabled(quote) and quote.eligible==true
end

function Panel:RenderPanel()
	if not self.gui or not self.panel or self.closing then return end
	local quote=self.quote
	if type(quote)~="table" then return end
	local rank=tonumber(quote.rank) or 0
	local nextTitle=quote.nextTitle
	self.title.Text=if nextTitle then "Rebirth to "..nextTitle else "Rebirth"
	-- Rank row.
	self.nowName.Text=quote.title or Panel.Title(rank)
	self.nowBadge.Image=if rank>=1 then Theme.Assets.Reenlist else Theme.Assets.RecruitBadge
	self.nextName.Text=nextTitle or "Max rank"
	self.nextBadge.Image=Theme.Assets.Reenlist
	self.nextBadge.ImageTransparency=if nextTitle then 0 else .5
	-- Reward pills.
	local now=tonumber(quote.multiplierNow) or 1
	self.eggValue.Text=if quote.multiplierNext then multiplier(now,2).." → "..multiplier(quote.multiplierNext,2) else multiplier(now,2)
	-- EnemyScale is linear in rank, so the current scale follows from the next one.
	local scaleNext=tonumber(quote.enemyScaleNext)
	local scaleNow=if scaleNext then 1+(scaleNext-1)*rank/(rank+1) else 1
	self.enemyValue.Text=if scaleNext then multiplier(scaleNow,1).." → "..multiplier(scaleNext,1) else multiplier(scaleNow,1)
	-- Cost bar: King requirement first, then cash progress; server errors replace the label.
	local cost,coins=tonumber(quote.cost),tonumber(quote.coins) or 0
	local needKing=quote.kingCleared==false
	local progress=if needKing then 0 elseif cost and cost>0 then math.clamp(coins/cost,0,1) else 1
	self.costFill.Size=UDim2.fromScale(progress,1)
	self.costLock.Visible=needKing
	if self.message then
		self.costText.Text,self.costText.TextColor3=self.message,self.messageColor or RED
	elseif needKing then
		self.costText.Text,self.costText.TextColor3="Defeat the Chicken King first",WHITE
	elseif cost then
		self.costText.Text,self.costText.TextColor3=money(math.min(coins,cost)).." / "..money(cost),WHITE
	else
		self.costText.Text,self.costText.TextColor3="Highest rank reached",GOLD
	end
	local can=self:CanConfirm()
	local hold=self.hold
	hold.Active=can or self.pending~=nil
	-- Readable refusal from the quote fields (the server reason has raw digits).
	local reason=quote.reason or "Not ready yet"
	if needKing then reason="Defeat the Chicken King"
	elseif cost and coins<cost then reason="Need "..money(cost-coins).." more"
	elseif quote.armyHome==false then reason="Bring your army home first" end
	hold.Text=if self.pending then "Rebirthing…" elseif can then "Hold to rebirth" else reason
	local tint=if can or self.pending then GREEN else Theme.ActionColors.disabled
	if hold.BackgroundColor3~=tint then
		hold.BackgroundColor3=tint
		if tint==GREEN then Theme.ApplyReferenceAccent(hold,Theme.ReferenceGradients.Army) end
	end
	if not can and self.holding then self:EndHold() end
end

function Panel:BeginHold(input)
	if self.holding or not self:CanConfirm() then return end
	self.holding,self.holdInput=true,input
	self.holdToken+=1
	local token=self.holdToken
	local fill=self.holdFill
	if self.drain then self.drain:Cancel();self.drain=nil end
	local progress=fill.Size.X.Scale
	local remaining=HOLD_SECONDS*(1-progress)
	-- The fill is the hold timer itself, so it stays linear even with reduced motion.
	self.fillTween=TweenService:Create(fill,TweenInfo.new(remaining,Enum.EasingStyle.Linear),{Size=UDim2.fromScale(1,1)})
	self.fillTween:Play()
	task.delay(remaining,function()
		if self.holdToken==token and self.holding then self:Confirm() end
	end)
end

function Panel:EndHold()
	if not self.holding then return end
	self.holding,self.holdInput=false,nil
	self.holdToken+=1
	if self.fillTween then self.fillTween:Cancel();self.fillTween=nil end
	local fill=self.holdFill
	if not fill then return end
	local progress=fill.Size.X.Scale
	if self.app.reducedMotion or progress<=0 then fill.Size=UDim2.fromScale(0,1);return end
	self.drain=TweenService:Create(fill,TweenInfo.new(.35*progress,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=UDim2.fromScale(0,1)})
	self.drain:Play()
end

function Panel:Confirm()
	self.holding,self.holdInput=false,nil
	if self.fillTween then self.fillTween:Cancel();self.fillTween=nil end
	if not self:CanConfirm() then self:EndHold();return end
	local rank=tonumber(self.quote.rank) or 0
	local id=self.app:Request("Rebirth",{expectedRank=rank})
	if not id then return end
	self.pending={id=id,rank=rank}
	self.message=nil
	self.app.audio:Play("Click")
	self:RenderPanel()
	-- Unlock after a lost reply; the server's expectedRank check rejects repeats.
	task.delay(10,function()
		if self.pending and self.pending.id==id then
			self.pending=nil
			if self.holdFill then self.holdFill.Size=UDim2.fromScale(0,1) end
			self:RenderPanel()
		end
	end)
end

function Panel:Close()
	if not self.gui or self.closing then return end
	local reopen=self.fromResearch
	self:Dismiss()
	-- Deferred so the same Escape/B press cannot also close the reopened map.
	if reopen then
		task.defer(function()
			local research=self.app.research
			if self.app.alive and research and not research.root.Visible and not self.gui then research:Open() end
		end)
	end
end

function Panel:Dismiss(immediate)
	local gui,panel=self.gui,self.panel
	if not gui or (self.closing and not immediate) then return end
	self.closing=true
	self.holding,self.holdInput=false,nil
	self.holdToken+=1
	if self.fillTween then self.fillTween:Cancel();self.fillTween=nil end
	if self.drain then self.drain:Cancel();self.drain=nil end
	ContextActionService:UnbindAction("PetRollReenlistClose")
	ContextActionService:UnbindAction("PetRollReenlistHold")
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject=if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	self.app:SetMenuBlur("rebirth",false)
	local function finish()
		if self.gui~=gui then return end
		self.gui,self.panel,self.hold,self.holdFill,self.closing=nil,nil,nil,nil,false
		gui:Destroy()
	end
	if immediate then finish();return end
	Theme.Motion:Tween(panel,"reenlist-size",{Size=UDim2.fromScale(self.panelSize.X.Scale*.97,self.panelSize.Y.Scale*.97)},.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	Theme.Motion:Tween(panel,"position",{Position=UDim2.fromScale(self.panelPosition.X.Scale,self.panelPosition.Y.Scale+.025)},.16)
	Theme.Motion:Tween(panel,"reenlist-fade",{GroupTransparency=1},.16,nil,nil,finish)
end

function Panel:Celebrate(quote)
	local title=quote.title or Panel.Title(tonumber(quote.rank) or 0)
	self.app.audio:Play("Victory",nil,{noFallback=true})
	-- UIMotion skips the burst under reduced motion.
	if not self.app.reducedMotion and self.app.gui and self.app.gui:FindFirstChild("Shell") then
		Theme.Motion:Burst(self.app.gui.Shell,UDim2.fromScale(.5,.45),GREEN)
	end
	self.app:Notify("You are now "..title,true)
end

function Panel:Render(state,result)
	if type(state)~="table" then return end
	local quote=state.rebirth
	if type(quote)~="table" then return end -- Nothing until the first quote arrives.
	self.quote=quote
	local rank=tonumber(quote.rank) or 0
	local promoted=self.lastRank~=nil and rank>self.lastRank
	self.lastRank=rank
	if result and result.action=="Rebirth" and self.pending and result.id==self.pending.id then
		self.pending=nil
		if not result.ok then
			self.message,self.messageColor=result.message or "Couldn't rebirth. Try again.",RED
			if self.holdFill then self.holdFill.Size=UDim2.fromScale(0,1) end
		end
	end
	if promoted then
		self.pending=nil
		self.fromResearch=false
		self:Dismiss()
		self:Celebrate(quote)
	end
	self:RenderHex()
	self:RenderPanel()
end

function Panel:Destroy()
	self:Dismiss(true)
	ContextActionService:UnbindAction("PetRollReenlistShortcut")
	for _,connection in self.hexConnections do connection:Disconnect() end
	table.clear(self.hexConnections)
	if self.hex then
		self:Pulse(self.hex,false)
		self.hex.button:Destroy()
		self.hex=nil
	end
end

return Panel
