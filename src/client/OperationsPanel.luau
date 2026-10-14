--!strict
-- Invasions (formerly Operations). October 14 story: after the Chicken King
-- falls, his loyalists land by airship somewhere on the island; the army marches
-- out to repel them. Three columns (October 14, Anime Vanguards style): tiers,
-- the tier's three invasions with Defend, and Invasion Info. This module also
-- shows the occasional "loyalists are gathering" alert. The server validates every Start/Leave.
local TweenService=game:GetService("TweenService")
local GuiService=game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Operations=require(Shared.OperationCatalog)
local Research=require(Shared.ResearchCatalog)
local Catalog=require(Shared.PetCatalog)
local Theme=require(script.Parent.UITheme)
local MenuLayout=require(script.Parent.MenuLayout)
local Portraits=require(script.Parent.ChickenPortraits)
local TutorialGuide=require(Shared.TutorialGuide)
local Panel={}
Panel.__index=Panel

local BLUE=Theme.ReferenceColors.Upgrades
local GREEN=Theme.ReferenceColors.Army
local GOLD=Theme.ReferenceColors.Base
local WHITE=Color3.new(1,1,1)
local MUTED=Color3.fromRGB(176,190,186)
local RED=Color3.fromRGB(232,62,48)
local CARD=Color3.fromRGB(26,32,36)
local EMBLEMS={Theme.Assets.TierVeteran,Theme.Assets.TierElite,Theme.Assets.TierRoyal}
local UNLOCK_NODES={"S15","S16","S17"}

local function label(parent,name,text,x,y,w,h,color,align)
	local item=Theme.Label(parent,name,text,20,color or WHITE)
	item.Position,item.Size=UDim2.fromScale(x,y),UDim2.fromScale(w,h)
	item.TextScaled,item.TextXAlignment=true,align or Enum.TextXAlignment.Left
	return item
end

local function card(parent,name,x,y,w,h,color,stroke)
	local frame=Theme.Frame(parent,name,UDim2.fromScale(w,h),color or CARD)
	frame.Position=UDim2.fromScale(x,y)
	frame:SetAttribute("OwnsPopupStyle",true)
	Theme.Stroke(frame,stroke or Color3.new(0,0,0),3)
	return frame
end

-- An invisible full-size hit area over a card, so cards stay plain Frames.
local function hitArea(parent,name,callback)
	local button=Instance.new("TextButton")
	button.Name,button.Text,button.BackgroundTransparency=name,"",1
	button.Size,button.ZIndex,button.AutoButtonColor,button.Selectable=UDim2.fromScale(1,1),20,false,true
	button.Parent=parent
	button.Activated:Connect(callback)
	return button
end

-- Rewards of $1M or more read compactly ("$1.25M"); smaller amounts stay exact.
local function money(value)
	return "$"..Theme.CompactMoney(tonumber(value) or 0)
end

function Panel.new(app)
	return setmetatable({app=app,connections={},tier=nil,selected=nil,key=nil},Panel)
end

function Panel:Data()
	local state=self.app.state
	return state and state.operations
end

-- Highest open tier the first time; afterwards the player's own choice.
function Panel:DefaultTier(data)
	local tier=math.clamp(tonumber(data.tier) or 0,1,#Operations.Tiers)
	for t=1,tier do
		for i=1,3 do if not (data.wins or {})[t..":"..i] then return t end end
	end
	return tier
end

function Panel:DefaultMission(data,tier)
	for i=1,3 do if not (data.wins or {})[tier..":"..i] then return i end end
	return 1
end

function Panel:Open()
	local app=self.app
	local data=self:Data()
	if not data or app.commerce.cratePresenting then return end
	if self.gui and not self.closing then self:Refresh(true);return end
	self:Dismiss(true)
	self.tier=self.tier or self:DefaultTier(data)
	self.selected=self.selected or self:DefaultMission(data,self.tier)
	app:SetMenuBlur("operations",true)
	-- One modal at a time: AppController closes every other menu (incl. Rebirth).
	if app.CloseOtherMenus then app:CloseOtherMenus("operations")
	else
		app:ClosePanel()
		if app.research and app.research.root.Visible then app.research:Close() end
		app.offlineCash:Dismiss(true)
		if app.dailyReward then app.dailyReward:Dismiss(true) end
	end
	self.previousSelection=GuiService.SelectedObject
	self:BuildShell()
	self:Refresh(true)
	if app.editPreview then return end
	ContextActionService:BindActionAtPriority("PetRollOperationsClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then self:Close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	local function connect(signal,callback) table.insert(self.connections,signal:Connect(callback)) end
	connect(UserInputService.InputBegan,function(input)
		if input.KeyCode==Enum.KeyCode.Escape then self:Close() end
	end)
	-- Another menu opening replaces this one.
	if app.panel then
		connect(app.panel:GetPropertyChangedSignal("Visible"),function() if app.panel.Visible then self:Dismiss(true) end end)
	end
	if app.research then
		connect(app.research.root:GetPropertyChangedSignal("Visible"),function() if app.research.root.Visible then self:Dismiss(true) end end)
	end
end

function Panel:BuildShell()
	local app=self.app
	local gui=if app.editPreview then Theme.Container(app.other,"Operations")
		else Theme.InsetContainer(app.other,"Operations",Enum.ScreenInsets.CoreUISafeInsets)
	gui.ZIndex=30
	self.gui,self.closing=gui,false
	local frames=Theme.Container(gui,"FRAMES")
	local backdropParent=if app.editPreview then frames else Theme.InsetContainer(frames,"BackdropLayer",Enum.ScreenInsets.None)
	local backdrop=Theme.Frame(backdropParent,"Backdrop",UDim2.fromScale(1,1))
	backdrop.BackgroundTransparency,backdrop.Active=1,true
	local panel=Instance.new("CanvasGroup")
	panel.Name="Operations"
	panel.BackgroundTransparency,panel.BorderSizePixel,panel.GroupTransparency=1,0,1
	panel.Active,panel.ZIndex=true,2
	panel.AnchorPoint,panel.Position=Vector2.new(.5,.5),UDim2.fromScale(.5,.52)
	panel.Parent,self.panel=frames,panel
	-- Studio may author PetRollGui.MenuLayouts.Operations; otherwise one native composition.
	if MenuLayout.Control(app.gui,"Operations") then MenuLayout.Apply(app.gui,"Operations",panel)
	else
		panel.Size=UDim2.fromScale(.88,.72)
		Theme.Aspect(panel,1.72)
	end
	self.panelSize,self.panelPosition=panel.Size,panel.Position
	local header=Theme.Header(panel,"Header","Invasions",BLUE)
	header.PageIcon.Image,header.PageIcon.Visible=Theme.Assets.Operations,true
	Theme.LayoutHeader(header)
	local main=Theme.Container(panel,"Main")
	Theme.BelowHeader(header,main)
	Theme.Surface(main,Theme.PageSurfaces.Upgrades or Theme.Colors.panel)
	main.UIStroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	self.main=main
	Theme.HeaderClose(header,function() app.audio:Play("Click");self:Close() end)
	Theme.ApplyPopupStyle(panel)
	local restingSize,restingPosition=self.panelSize,self.panelPosition
	if not app.reducedMotion then
		panel.Size=UDim2.fromScale(restingSize.X.Scale*.94,restingSize.Y.Scale*.94)
		panel.Position=UDim2.fromScale(restingPosition.X.Scale,restingPosition.Y.Scale+.035)
	end
	Theme.Motion:Tween(panel,"operations-size",{Size=restingSize},.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	Theme.Motion:Tween(panel,"position",{Position=restingPosition},.28)
	Theme.Motion:Tween(panel,"operations-fade",{GroupTransparency=0},.22)
end

-- Rebuild the content only when something it shows has changed.
function Panel:Refresh(force: boolean?)
	if not self.gui or self.closing or not self.main then return end
	local app=self.app
	local state=app.state
	local data=self:Data()
	if not state or not data then return end
	local wins={}
	for id in data.wins or {} do table.insert(wins,id) end
	table.sort(wins)
	local key=table.concat({tostring(self.tier),tostring(self.selected),tostring(data.tier),table.concat(wins,","),
		tostring(data.activeId),tostring(data.pendingReward),tostring(state.power),tostring(state.research and state.research.revision),
		tostring(state.armyState)},"|")
	if not force and key==self.key then return end
	self.key=key
	local content=self.main:FindFirstChild("Content")
	if content then content:Destroy() end
	content=Theme.Container(self.main,"Content")
	self:BuildTabs(content,data)
	self:BuildMissions(content,data)
	self:BuildDetail(content,data,state)
	Theme.ScaleText(content)
	if not app.editPreview and self.deploy and UserInputService.PreferredInput==Enum.PreferredInput.Gamepad then
		GuiService.SelectedObject=self.deploy
	end
end

-- October 14 layout (owner pick I1, Anime Vanguards stage select): Select Tier |
-- Select Invasion | Invasion Info. The middle column carries the main action.
local function heading(parent,name,text,x,w)
	return label(parent,name,text,x,.025,w,.07,WHITE)
end

function Panel:BuildTabs(content,data)
	local open=tonumber(data.tier) or 0
	heading(content,"TierHeading","Select Tier",.03,.27)
	for index,name in Operations.Tiers do
		local color=Operations.Colors[index]
		local locked=open<index
		local selected=self.tier==index
		local tab=card(content,"Tab"..name,.02,.11+(index-1)*.215,.28,.195,
			if selected then color:Lerp(CARD,.45) else CARD,if selected then color:Lerp(WHITE,.35) else Color3.new(0,0,0))
		if selected then tab.UIStroke.Thickness=4;Theme.Gradient(tab,color:Lerp(WHITE,.1),color:Lerp(Color3.new(0,0,0),.45)) end
		local emblem=Theme.Image(tab,"Emblem",EMBLEMS[index],UDim2.fromScale(.3,.9),UDim2.fromScale(.03,.05))
		Theme.Aspect(emblem,1);emblem.ZIndex=6
		emblem.ImageTransparency=if locked then .55 else 0
		label(tab,"Name",name,.34,.08,.62,.46,if locked then MUTED else color:Lerp(WHITE,.35))
		local cleared=0
		for i=1,3 do if (data.wins or {})[index..":"..i] then cleared+=1 end end
		label(tab,"Progress",if locked then "Locked" else "Cleared: "..cleared.."/3",.34,.56,.62,.32,
			if locked then MUTED elseif cleared==3 then GREEN else WHITE)
		if locked then
			local lock=Theme.Image(tab,"Lock",Theme.Assets.Padlock,UDim2.fromScale(.2,.6),UDim2.fromScale(.77,.2))
			Theme.Aspect(lock,1);lock.ZIndex=7
		end
		hitArea(tab,"Select",function()
			self.app.audio:Play("Click")
			self.tier,self.selected=index,self:DefaultMission(data,index)
			self:Refresh()
		end)
	end
	local formations=Theme.Button(content,"Formations","Formations",function() self.app:OpenPage("Formations") end,BLUE)
	formations.Position,formations.Size=UDim2.fromScale(.02,.81),UDim2.fromScale(.28,.16)
end

function Panel:BuildMissions(content,data)
	local tier=self.tier
	local color=Operations.Colors[tier]
	local locked=(tonumber(data.tier) or 0)<tier
	heading(content,"MissionHeading","Select Invasion",.33,.3)
	for index=1,3 do
		local id=tier..":"..index
		local definition=Operations.Encounters[id]
		local cleared=(data.wins or {})[id]==true
		local selected=self.selected==index
		local row=card(content,"Mission"..index,.32,.11+(index-1)*.215,.31,.195,
			if selected then color:Lerp(CARD,.6) else CARD,if selected then color:Lerp(WHITE,.35) else Color3.new(0,0,0))
		if selected then row.UIStroke.Thickness=4 end
		Theme.Gradient(row,WHITE,Color3.fromRGB(150,150,150))
		local emblem=Theme.Image(row,"Emblem",EMBLEMS[tier],UDim2.fromScale(.36,1.3),UDim2.fromScale(.66,-.15))
		Theme.Aspect(emblem,1);emblem.ZIndex=3;emblem.ImageTransparency=if locked then .85 else .65
		local stamped=cleared and not locked
		label(row,"Number",(if definition.boss then "Boss · " else "Invasion ")..index,if stamped then .4 else .05,.1,.55,.3,GOLD)
		label(row,"Name",definition.name,.05,.4,.9,.48,if locked then MUTED else WHITE)
		if stamped then
			local stamp=label(row,"Clear","CLEAR!",-.02,-.12,.4,.48,GREEN)
			stamp.ZIndex,stamp.Rotation=9,-6
		end
		if locked then
			local lock=Theme.Image(row,"Lock",Theme.Assets.Padlock,UDim2.fromScale(.14,.6),UDim2.fromScale(.82,.2))
			Theme.Aspect(lock,1);lock.ZIndex=7
		end
		hitArea(row,"Select",function()
			self.app.audio:Play("Click")
			self.selected=index
			self:Refresh()
		end)
	end
end

-- Enemy squad portraits: one tile per group (×count, Lv), the boss first.
function Panel:BuildSquad(parent,id,y,h)
	local definition=Operations.Encounters[id]
	local tiles={}
	if definition.boss then table.insert(tiles,{species=definition.boss.species,boss=true}) end
	for _,group in definition.groups do table.insert(tiles,{species=group[1],level=group[2],count=group[3]}) end
	local width=math.min(.23,.92/math.max(1,#tiles))
	local gap=.02
	local start=(1-(#tiles*width+(#tiles-1)*gap))/2
	for index,tile in tiles do
		local slot=card(parent,"Enemy"..index,start+(index-1)*(width+gap),y,width,h,
			if tile.boss then Color3.fromRGB(70,20,20) else Color3.fromRGB(34,42,48),if tile.boss then RED else Color3.new(0,0,0))
		local portrait=Theme.Image(slot,"Portrait",Portraits[tile.species] or Theme.Assets.Army,UDim2.fromScale(.8,.8),UDim2.fromScale(.1,.02))
		Theme.Aspect(portrait,1);portrait.ZIndex=6
		local definitionName=Catalog[tile.species] and Catalog[tile.species].name or tile.species
		portrait:SetAttribute("Species",definitionName)
		local caption=if tile.boss then "BOSS" else "×"..tile.count.." Lv "..tile.level
		local tag=label(slot,"Count",caption,.04,.72,.92,.26,if tile.boss then Color3.fromRGB(255,120,104) else WHITE,Enum.TextXAlignment.Center)
		tag.ZIndex=7
	end
end

-- A square reward chip (I1 "Rewards" row): icon with a caption under it.
local function rewardChip(parent,name,x,y,w,h,icon,text,color)
	local chip=card(parent,name,x,y,w,h,color:Lerp(CARD,.55),color)
	local art=Theme.Image(chip,"Icon",icon,UDim2.fromScale(.66,.66),UDim2.fromScale(.17,.04))
	Theme.Aspect(art,1);art.ZIndex=6
	local caption=label(chip,"Caption",text,.04,.68,.92,.3,WHITE,Enum.TextXAlignment.Center)
	caption.ZIndex=7
	return chip
end

function Panel:BuildDetail(content,data,state)
	local app=self.app
	local tier=self.tier
	local color=Operations.Colors[tier]
	local id=tier..":"..self.selected
	local definition=Operations.Encounters[id]
	local locked=(tonumber(data.tier) or 0)<tier
	local cleared=(data.wins or {})[id]==true
	self.deploy=nil
	-- Right column: Invasion Info.
	local info=card(content,"Detail",.65,.025,.33,.95,Color3.fromRGB(16,20,24),color)
	label(info,"Heading","Invasion Info",.04,.015,.92,.08,WHITE,Enum.TextXAlignment.Center)
	local enemy=Operations.Power(id)
	local mine=tonumber(state.power) or 0
	-- Same wording and thresholds as camps (TutorialGuide.Difficulty).
	local verdict=TutorialGuide.Difficulty(mine,enemy)
	label(info,"Recommended","Enemy power: "..Theme.Number(enemy),.04,.1,.92,.055,GOLD,Enum.TextXAlignment.Center)
	label(info,"Verdict",if locked then "Locked" else verdict,.04,.155,.92,.055,
		if locked then MUTED elseif verdict=="Very tough" then RED elseif verdict=="Close fight" then GOLD else GREEN,Enum.TextXAlignment.Center)
	label(info,"Title",definition.name,.04,.225,.92,.07,color:Lerp(WHITE,.35),Enum.TextXAlignment.Center)
	self:BuildSquad(info,id,.31,.2)
	if locked then
		local padlock=Theme.Image(info,"Padlock",Theme.Assets.Padlock,UDim2.fromScale(.22,.16),UDim2.fromScale(.39,.55))
		Theme.Aspect(padlock,1);padlock.ZIndex=6
		local node=Research.Nodes[UNLOCK_NODES[tier]]
		local text=if tier==1 then "Defeat the Chicken King or unlock "..node.name.." in Upgrades" else "Unlock "..node.name.." in Upgrades"
		label(info,"Requirement",text,.06,.7,.88,.11,WHITE,Enum.TextXAlignment.Center)
		local view=Theme.Button(info,"ViewResearch","View in Upgrades",function()
			app:OpenPage("Research");app.research:Center(node.id);app.research:Select(node.id,true)
		end,BLUE)
		view.Position,view.Size=UDim2.fromScale(.1,.83),UDim2.fromScale(.8,.12)
	else
		-- Power comparison: your selected army against the enemy squad.
		local compare=card(info,"Power",.05,.535,.9,.065,Color3.fromRGB(16,20,24))
		local share=if mine+enemy>0 then mine/(mine+enemy) else .5
		local yours=Theme.Frame(compare,"Yours",UDim2.fromScale(share,1),GREEN)
		Theme.ApplyReferenceAccent(yours,Theme.ReferenceGradients.Army)
		local theirs=Theme.Frame(compare,"Theirs",UDim2.fromScale(1-share,1),RED)
		theirs.Position=UDim2.fromScale(share,0)
		Theme.Gradient(theirs,RED:Lerp(WHITE,.15),RED:Lerp(Color3.new(0,0,0),.3))
		local you=label(compare,"You","You "..Theme.Number(mine),.03,.05,.45,.9,WHITE)
		local them=label(compare,"Them","Enemy",.52,.05,.45,.9,WHITE,Enum.TextXAlignment.Right)
		you.ZIndex,them.ZIndex=8,8
		-- First clear reward (I1's red line), then the Rewards row.
		label(info,"FirstClear",if cleared then "FIRST CLEAR: DONE" else "FIRST CLEAR REWARD: "..money(definition.firstCash),
			.04,.625,.92,.055,if cleared then GREEN else Color3.fromRGB(255,96,80),Enum.TextXAlignment.Center)
		label(info,"RewardsHeading","Rewards",.04,.69,.92,.05,WHITE,Enum.TextXAlignment.Center)
		rewardChip(info,"Cash",.13,.75,.34,.2,Theme.Assets.Cash,money(definition.replayCash).." replay",GOLD)
		rewardChip(info,"Banner",.53,.75,.34,.2,EMBLEMS[tier],if tier==3 then "Banner + title" else "Banner (all 3)",color)
	end
	-- Middle column action, under the invasion list (I1's CONFIRM/LEAVE row).
	if locked then return end
	if (data.pendingReward or 0)>0 then
		label(content,"Pending",money(data.pendingReward).." saved; it pays when your wallet has room.",.32,.75,.31,.05,GOLD,Enum.TextXAlignment.Center)
	end
	if data.activeId then
		local active=Operations.Encounters[data.activeId]
		local left=self.expiresAt and math.max(0,math.ceil(self.expiresAt-os.clock()))
		label(content,"Active",(if active then active.name else "An Invasion").." under way"
			..(if left then (" · %d:%02d"):format(left//60,left%60) else ""),.32,.75,.31,.05,WHITE,Enum.TextXAlignment.Center)
		local leave=Theme.ActionButton(content,"Leave","Leave",function() app:Request("LeaveOperation") end,Theme.ActionColors.danger)
		leave.Position,leave.Size=UDim2.fromScale(.32,.81),UDim2.fromScale(.31,.16)
		self.deploy=leave
		return
	end
	local home=state.armyState=="Home" or state.armyState=="Following"
	local deploy=Theme.ActionButton(content,"Deploy",if not home then "Army busy" elseif cleared then "Defend again" else "Defend",function()
		if not home then return end
		app:Request("StartOperation",{operationId=id,expectedRevision=state.research and state.research.revision})
	end,if home then GREEN else Theme.ActionColors.disabled)
	deploy.Active=home
	deploy.Position,deploy.Size=UDim2.fromScale(.32,.81),UDim2.fromScale(.31,.16)
	self.deploy=deploy
end

function Panel:Close()
	if not self.gui or self.closing then return end
	self:Dismiss()
end

function Panel:Dismiss(immediate: boolean?)
	local gui,panel=self.gui,self.panel
	if not gui or (self.closing and not immediate) then return end
	self.closing=true
	ContextActionService:UnbindAction("PetRollOperationsClose")
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject=if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	self.app:SetMenuBlur("operations",false)
	local function finish()
		if self.gui~=gui then return end
		self.gui,self.panel,self.main,self.deploy,self.key,self.closing=nil,nil,nil,nil,nil,false
		gui:Destroy()
	end
	if immediate or not panel then finish();return end
	Theme.Motion:Tween(panel,"operations-size",{Size=UDim2.fromScale(self.panelSize.X.Scale*.97,self.panelSize.Y.Scale*.97)},.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	Theme.Motion:Tween(panel,"position",{Position=UDim2.fromScale(self.panelPosition.X.Scale,self.panelPosition.Y.Scale+.025)},.16)
	Theme.Motion:Tween(panel,"operations-fade",{GroupTransparency=1},.16,nil,nil,finish)
end

-- Every so often, while an Invasion is available and the army is home, a scout
-- reports gathering loyalists and the HUD Invasions icon pulses. Cosmetic only;
-- nothing attacks until the player chooses Defend.
local ALERT_FIRST_SECONDS,ALERT_EVERY_SECONDS=180,600
function Panel:StepAlert(state)
	local data=state.operations
	local now=os.clock()
	self.nextAlertAt=self.nextAlertAt or now+ALERT_FIRST_SECONDS
	if now<self.nextAlertAt then return end
	local ready=data and (tonumber(data.tier) or 0)>=1 and not data.activeId and state.armyState=="Home"
		and (state.tutorial or {}).guideCompleted==true and not self.gui
	if not ready then return end
	self.nextAlertAt=now+ALERT_EVERY_SECONDS
	self:ShowAlert()
end

-- The scout report itself (also reachable from Studio test tools).
function Panel:ShowAlert()
	self.app:Notify("Loyalists are gathering. Open Invasions to repel them.","info")
	local icon=self.app.researchExtras and self.app.researchExtras.operations
	local visual=icon and icon:FindFirstChild("Visual")
	if visual and not self.app.reducedMotion then
		local pulse=TweenService:Create(visual,TweenInfo.new(.35,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,5,true),{Size=UDim2.fromScale(1.15,1.15)})
		pulse:Play()
		pulse.Completed:Once(function() visual.Size=UDim2.fromScale(1,1) end)
	end
end

function Panel:Render(state,result)
	if type(state)~="table" then return end
	local data=state.operations
	local active=data and data.activeId
	-- The world marker counts down from the server's remaining time.
	self.expiresAt=if active and data.expiresIn then os.clock()+data.expiresIn else nil
	self:StepAlert(state)
	-- A successful deploy sends the army off; the menu gets out of the way.
	if result and result.ok and result.action=="StartOperation" then self:Dismiss();return end
	self:Refresh()
end

function Panel:Destroy()
	self:Dismiss(true)
end

return Panel
