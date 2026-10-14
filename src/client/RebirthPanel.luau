--!strict
-- Rebirth presentation: the hold-to-confirm panel, opened from the HUD Rebirth
-- button (October 14: no longer a hex on the Upgrades screen). The server quote (state.rebirth) is authoritative; this module never
-- changes saved state. AppController calls Render(state, result) on every packet.
-- Contract: docs/team/launch/12_R1_REBIRTH_CLIENT.md.
local GuiService=game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local Theme=require(script.Parent.UITheme)
local MutationCatalog=require(game:GetService("ReplicatedStorage").PetRoll.Shared.MutationCatalog)
local Config=require(game:GetService("ReplicatedStorage").PetRoll.Shared.Config)
local MenuLayout=require(script.Parent.MenuLayout)
local Assets=require(script.Parent.ResearchAssets)
local Panel={}
Panel.__index=Panel

local GREEN=Theme.ReferenceColors.Army
local GOLD=Theme.ReferenceColors.Base
local WHITE=Color3.new(1,1,1)
local RED=Color3.fromRGB(255,107,83)
local HOLD_SECONDS=2
-- The warning matches RebirthService:Rebirth step 6 (coins, eggSpeedLevel,
-- incomeLevel, luck, camp wins, the King and bought chicken levels); the rest is kept.
-- quote.cashLevels counts the cash-bought chicken levels this rebirth removes.
local function warningLine(levels: number): string
	local tail=if levels>0 then " and "..levels.." bought chicken level"..(if levels==1 then "" else "s") else ""
	return "WARNING: Resets Cash, Egg Speed, Egg Value, Luck, camps"..tail..". Your chickens stay!"
end
local ENEMY_RED=Color3.fromRGB(232,62,48)
local ORANGE=Color3.fromRGB(255,150,40)
local PILL=Color3.fromRGB(24,30,26)

-- Player-facing rank names are "Rebirth 1", "Rebirth 2", … (October 14 glossary;
-- "Veteran/Elite/Royal" are Invasion tier names only). The server quote's
-- title/nextTitle strings are ignored for display; only the rank numbers count.
function Panel.Title(rank: number): string
	rank=math.max(0,math.floor(rank or 0))
	if rank==0 then return "No rebirths yet" end
	return "Rebirth "..rank
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

-- The next rank's name, or nil at the maximum (the server omits nextTitle/nextRank).
local function nextName(quote): string?
	if type(quote)~="table" then return nil end
	local rank=tonumber(quote.rank) or 0
	if full(quote) then
		if quote.nextTitle==nil and quote.nextRank==nil then return nil end
		return Panel.Title(tonumber(quote.nextRank) or rank+1)
	end
	return Panel.Title(rank+1)
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
	return setmetatable({app=app,connections={},quote=nil,lastRank=nil,
		pending=nil,holding=false,holdToken=0},Panel)
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
	-- One modal at a time (also closes Invasions and the Upgrades tree; Close
	-- reopens the tree when Rebirth came from it).
	if self.app.CloseOtherMenus then self.app:CloseOtherMenus("rebirth")
	else
		self.app:ClosePanel()
		self.app.offlineCash:Dismiss(true)
		if self.app.dailyReward then self.app.dailyReward:Dismiss(true) end
		if self.app.operationsPanel then self.app.operationsPanel:Dismiss(true) end
	end
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
	-- October 14 layout (owner picks R2/R3 rows + R4 warning and tiles): red warning,
	-- before → after rows, "next rank brings" tiles, then the cash bar beside the button.
	self.warning=label(main,"Warning",warningLine(0),.05,.02,.9,.1,RED)
	local function row(name,y,icon)
		local function pill(side,x)
			local frame=Theme.Frame(main,name..side,UDim2.fromScale(.36,.1),PILL)
			frame.Position=UDim2.fromScale(x,y)
			frame:SetAttribute("OwnsPopupStyle",true)
			Theme.Stroke(frame,Color3.new(0,0,0),3)
			local art=Theme.Image(frame,"Icon",icon,UDim2.fromScale(.24,1.3),UDim2.fromScale(-.07,-.15))
			Theme.Aspect(art,1);art.ZIndex=7
			return label(frame,"Value","",.19,.1,.77,.8,WHITE),art
		end
		local now,nowIcon=pill("Now",.08)
		local nxt,nextIcon=pill("Next",.56)
		label(main,name.."Arrow","→",.445,y,.11,.1,ORANGE)
		return {now=now,next=nxt,nowIcon=nowIcon,nextIcon=nextIcon}
	end
	self.cashRow=row("Cash",.14,Theme.Assets.Cash)
	self.eggRow=row("Eggs",.27,Assets.egg)
	self.rankRow=row("Rank",.4,Theme.Assets.RecruitBadge)
	-- Tiles: the mutation this rank first allows (quote.unlockNext) and the camp scale.
	self.bringsLine=label(main,"Brings","NEXT RANK BRINGS",.04,.515,.92,.055,GOLD)
	local function tile(name,color,top)
		local frame=Theme.Frame(main,name,UDim2.fromScale(.15,.2),color)
		frame.Position=UDim2.fromScale(.425,.58)
		frame:SetAttribute("OwnsPopupStyle",true)
		Theme.Aspect(frame,1)
		Theme.Gradient(frame,color:Lerp(WHITE,.15),color:Lerp(Color3.new(0,0,0),.35))
		Theme.Stroke(frame,Color3.new(0,0,0),3)
		label(frame,"Top",top,.04,.03,.92,.2,WHITE)
		local caption=label(frame,"Caption","",.04,.76,.92,.2,WHITE)
		return frame,caption
	end
	local mutationTile,mutationCaption=tile("MutationTile",Color3.fromRGB(255,118,214),"MUTATION")
	self.mutationName=label(mutationTile,"Name","",.04,.28,.92,.42,WHITE)
	local campTile,campCaption=tile("CampTile",ENEMY_RED,"CAMPS")
	local campIcon=Theme.Image(campTile,"Icon",Theme.Assets.EnemyStrength,UDim2.fromScale(.5,.5),UDim2.fromScale(.25,.24))
	Theme.Aspect(campIcon,1);campIcon.ZIndex=6
	self.mutationTile,self.mutationCaption,self.campTile,self.campCaption=mutationTile,mutationCaption,campTile,campCaption
	-- Cost bar (R2): cash icon, progress toward the next rank, then the button.
	local track,fill=bar(main,"CostProgress",Color3.fromRGB(14,24,14),GOLD)
	track.Position,track.Size=UDim2.fromScale(.1,.845),UDim2.fromScale(.52,.1)
	Theme.Stroke(track,Color3.new(0,0,0),3)
	local costIcon=Theme.Image(main,"CostIcon",Theme.Assets.Cash,UDim2.fromScale(.1,.17),UDim2.fromScale(.035,.81))
	Theme.Aspect(costIcon,1);costIcon.ZIndex=9
	local costText=label(track,"Label","",.08,.05,.84,.9,WHITE)
	costText.ZIndex=8
	self.costTrack,self.costFill,self.costText,self.costIcon=track,fill,costText,costIcon
	local actions=Theme.Container(main,"Actions")
	actions.Position,actions.Size=UDim2.fromScale(.65,.825),UDim2.fromScale(.31,.14)
	-- Hold control stays at least 44 points tall on the smallest phones.
	local minimum=Instance.new("UISizeConstraint")
	minimum.MinSize,minimum.Parent=Vector2.new(0,44),actions
	local hold=Theme.ActionButton(actions,"Confirm","Hold to Rebirth",function() end,GREEN)
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
	local nextTitle=nextName(quote)
	self.title.Text=nextTitle or "Rebirth"
	local max=nextTitle==nil
	self.warning.Text=warningLine(tonumber(quote.cashLevels) or 0)
	-- Cash row: everything you hold now → the fresh starting cash.
	local cost,coins=tonumber(quote.cost),tonumber(quote.coins) or 0
	self.cashRow.now.Text=money(coins)
	self.cashRow.next.Text=if max then money(coins) else money(Config.StartingCoins)
	self.cashRow.next.TextColor3=if max then WHITE else RED
	-- Egg row.
	local now=tonumber(quote.multiplierNow) or 1
	self.eggRow.now.Text=multiplier(now,2)
	self.eggRow.next.Text=if quote.multiplierNext then multiplier(quote.multiplierNext,2) else multiplier(now,2)
	self.eggRow.next.TextColor3=if max then WHITE else Color3.fromRGB(140,255,110)
	-- Rank row.
	self.rankRow.now.Text=Panel.Title(rank)
	self.rankRow.nowIcon.Image=if rank>=1 then Theme.Assets.Reenlist else Theme.Assets.RecruitBadge
	self.rankRow.next.Text=nextTitle or "Max rank"
	self.rankRow.next.TextColor3=GOLD
	self.rankRow.nextIcon.Image=Theme.Assets.Reenlist
	-- Tiles. EnemyScale is linear in rank, so the next camp scale is enough.
	local unlock=quote.unlockNext
	local def=if type(unlock)=="table" and unlock.name then MutationCatalog.Defs[unlock.name] else nil
	self.mutationTile.Visible=def~=nil and not max
	if def then
		self.mutationName.Text=def.name
		self.mutationCaption.Text="×"..tostring(def.multiplier).." eggs"
		self.mutationTile.BackgroundColor3=def.color
		Theme.Gradient(self.mutationTile,def.color:Lerp(WHITE,.15),def.color:Lerp(Color3.new(0,0,0),.35))
	end
	local scaleNext=tonumber(quote.enemyScaleNext)
	self.campTile.Visible=scaleNext~=nil and not max
	self.campCaption.Text=if scaleNext then multiplier(scaleNext,1).." stronger" else ""
	local width,gap=.15,.03
	local tiles={}
	for _,item in {self.mutationTile,self.campTile} do if item.Visible then table.insert(tiles,item) end end
	local start=.5-(#tiles*width+(#tiles-1)*gap)/2
	for index,item in tiles do item.Position=UDim2.fromScale(start+(index-1)*(width+gap),.58) end
	self.bringsLine.Text=if max then "Highest rank reached" else "NEXT RANK BRINGS"
	-- Cost bar: King requirement first, then cash progress; server errors replace the label.
	-- Only the first Rebirth needs the King (quote.kingRequired; older quotes lack it).
	local needKing=quote.kingCleared==false and quote.kingRequired~=false
	local progress=if needKing then 0 elseif cost and cost>0 then math.clamp(coins/cost,0,1) else 1
	self.costFill.Size=UDim2.fromScale(progress,1)
	self.costIcon.Image=if needKing then Theme.Assets.Padlock else Theme.Assets.Cash
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
	if needKing then reason="Locked"
	elseif cost and coins<cost then reason="Need "..money(cost-coins).." more"
	elseif quote.armyHome==false then reason="Bring your Army home first" end
	hold.Text=if self.pending then "Rebirthing…" elseif can then "Hold to Rebirth" else reason
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
	local title=Panel.Title(tonumber(quote.rank) or 0)
	self.app.audio:Play("Victory",nil,{noFallback=true})
	-- UIMotion skips the burst under reduced motion.
	if not self.app.reducedMotion and self.app.gui and self.app.gui:FindFirstChild("Shell") then
		Theme.Motion:Burst(self.app.gui.Shell,UDim2.fromScale(.5,.45),GREEN)
	end
	local rank=tonumber(quote.rank) or 0
	local unlocked
	for _,id in MutationCatalog.Order do if MutationCatalog.Defs[id].unlockRank==rank and rank>0 then unlocked=MutationCatalog.Defs[id].name end end
	local eggs=multiplier(tonumber(quote.multiplierNow) or 1,2)
	self.app:Notify(title.." complete! Eggs "..eggs..(if unlocked then " · "..unlocked.." mutations unlocked" else ""),true)
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
	self:RenderPanel()
end

function Panel:Destroy()
	self:Dismiss(true)
end

return Panel
