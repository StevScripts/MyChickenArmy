--!strict
-- Invasions (formerly Operations). October 14 story: after the Chicken King
-- falls, his loyalists land by airship somewhere on the island; the army marches
-- out to repel them. One column (October 14): tier tabs, three invasion bars,
-- a status row and one big button. This module also
-- shows the occasional "loyalists are gathering" alert. The server validates every Start/Leave.
local GuiService=game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Operations=require(Shared.OperationCatalog)
local Research=require(Shared.ResearchCatalog)
local Theme=require(script.Parent.UITheme)
local MenuLayout=require(script.Parent.MenuLayout)
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
-- October 21 game feel (docs/team/GAME_FEEL_20261021.md): an authored cue, or its
-- fallback until the sound session adds it (UI Lab previews stub audio without Has).
-- Presentation only; one client audio.
local Audio=nil
local function cue(name,fallback,pitch,options)
	if not Audio then return end
	if type(Audio.Has)=="function" and Audio:Has(name) then Audio:Play(name,pitch,options)
	elseif fallback then Audio:Play(fallback,pitch,options) end
end

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
	-- Press feedback scales the card; it is rebuilt on Refresh, never repositioned.
	-- The callback plays TabSwitch itself.
	Theme.Motion:Center(parent)
	Theme.Motion:BindButton(button,Theme.Motion:ScaleOf(parent))
	button:SetAttribute("ClickSound",false)
	button.Activated:Connect(callback)
	return button
end

-- Rewards of 1M or more read compactly ("1.25M Coins"); smaller amounts stay exact.
local function money(value)
	return Theme.CompactCoins(tonumber(value) or 0)
end

function Panel.new(app)
	Audio=app.audio
	return setmetatable({app=app,connections={},tier=nil,selected=nil,key=nil,revealOnBuild=false},Panel)
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
	self.revealOnBuild=true
	self:Refresh(true)
	cue("MenuOpen",nil,nil,{voiceKey="MenuOpen",cooldown=0.2})
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
		panel.Size=UDim2.fromScale(.62,.72)
		Theme.Aspect(panel,1)
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
	local pop=self.pop;self.pop=nil
	local wins={}
	for id in data.wins or {} do table.insert(wins,id) end
	table.sort(wins)
	local key=table.concat({tostring(self.tier),tostring(self.selected),tostring(data.tier),table.concat(wins,","),
		tostring(data.activeId),tostring(data.pendingReward),tostring(state.power),
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
	-- First build after Open: tabs, bars, status and the button grow in one after another.
	if self.revealOnBuild then
		self.revealOnBuild=false
		Theme.Motion:Reveal(content,{limit=10,window=0.35,from=0.8})
	end
	-- The clicked card was rebuilt; give the new selection a small pop.
	local picked=pop and content:FindFirstChild(pop)
	if picked then Theme.Motion:PopScale(picked,1.06) end
	if not app.editPreview and self.deploy and UserInputService.PreferredInput==Enum.PreferredInput.Gamepad then
		GuiService.SelectedObject=self.deploy
	end
end

-- October 14 third pass (owner: "too cluttered"; minimal layout taken from an
-- uninstructed image-generator mockup): tier tabs, three wide invasion bars, one
-- status row with a verdict chip, one big button.
function Panel:BuildTabs(content,data)
	local open=tonumber(data.tier) or 0
	for index,name in Operations.Tiers do
		local color=Operations.Colors[index]
		local locked=open<index
		local selected=self.tier==index
		local tab=card(content,"Tab"..name,.04+(index-1)*.32,.03,.28,.12,
			if selected then color:Lerp(CARD,.45) else CARD,if selected then color:Lerp(WHITE,.35) else Color3.new(0,0,0))
		if selected then tab.UIStroke.Thickness=4;Theme.Gradient(tab,color:Lerp(WHITE,.1),color:Lerp(Color3.new(0,0,0),.45)) end
		local emblem=Theme.Image(tab,"Emblem",if locked then Theme.Assets.Padlock else EMBLEMS[index],UDim2.fromScale(.3,.8),UDim2.fromScale(.04,.1))
		Theme.Aspect(emblem,1);emblem.ZIndex=6
		label(tab,"Name",name,.36,.15,.6,.7,if locked then MUTED else WHITE)
		hitArea(tab,"Select",function()
			cue("TabSwitch","Click")
			self.tier,self.selected=index,self:DefaultMission(data,index)
			self.pop="Tab"..name
			self:Refresh()
		end)
	end
end

function Panel:BuildMissions(content,data)
	local tier=self.tier
	local color=Operations.Colors[tier]
	local locked=(tonumber(data.tier) or 0)<tier
	for index=1,3 do
		local id=tier..":"..index
		local definition=Operations.Encounters[id]
		local cleared=(data.wins or {})[id]==true
		local selected=self.selected==index
		local row=card(content,"Mission"..index,.04,.19+(index-1)*.14,.92,.12,
			if selected then color:Lerp(CARD,.5) else CARD,if selected then color:Lerp(WHITE,.35) else Color3.new(0,0,0))
		if selected then row.UIStroke.Thickness=4 end
		label(row,"Name",definition.name,.04,.14,.6,.72,if locked then MUTED else WHITE)
		-- Right chip: CLEAR!, a padlock, or the first-clear cash.
		local chipColor=if locked then MUTED elseif cleared then GREEN else GOLD
		local chip=card(row,"Chip",.67,.14,.3,.72,chipColor:Lerp(CARD,.6),chipColor)
		if locked then
			local lock=Theme.Image(chip,"Lock",Theme.Assets.Padlock,UDim2.fromScale(.4,.8),UDim2.fromScale(.3,.1))
			Theme.Aspect(lock,1);lock.ZIndex=7
		else
			label(chip,"Text",if cleared then "CLEAR!" else money(definition.firstCash),.06,.08,.88,.84,WHITE,Enum.TextXAlignment.Center)
		end
		hitArea(row,"Select",function()
			cue("Select","Click")
			self.selected=index
			self.pop="Mission"..index
			self:Refresh()
		end)
	end
end

function Panel:BuildDetail(content,data,state)
	local app=self.app
	local tier=self.tier
	local id=tier..":"..self.selected
	local definition=Operations.Encounters[id]
	local locked=(tonumber(data.tier) or 0)<tier
	local cleared=(data.wins or {})[id]==true
	self.deploy=nil
	-- Status row (the mockup's "CURRENT INVASION [NONE]"): power on the left, verdict chip right.
	local status=card(content,"Status",.04,.63,.92,.11,Color3.fromRGB(16,20,24))
	local enemy=Operations.Power(id)
	local mine=tonumber(state.power) or 0
	local node=Research.Nodes[UNLOCK_NODES[tier]]
	if locked then
		label(status,"Requirement",if tier==1 then "Beat the King or unlock "..node.name else "Unlock "..node.name,.04,.14,.92,.72,WHITE,Enum.TextXAlignment.Center)
	else
		local pending=(data.pendingReward or 0)>0
		label(status,"Power",if pending then money(data.pendingReward).." saved" else "Enemy "..Theme.Number(enemy).." · You "..Theme.Number(mine),
			.04,.14,.6,.72,if pending then GOLD else WHITE)
		-- Same wording and thresholds as camps (TutorialGuide.Difficulty).
		local verdict=TutorialGuide.Difficulty(mine,enemy)
		local tone=if verdict=="Very tough" then RED elseif verdict=="Close fight" then GOLD else GREEN
		local chip=card(status,"Verdict",.67,.14,.3,.72,tone:Lerp(CARD,.35),tone)
		label(chip,"Text",verdict,.06,.08,.88,.84,WHITE,Enum.TextXAlignment.Center)
	end
	-- One big button.
	local button
	if locked then
		button=Theme.ActionButton(content,"ViewResearch","View in Upgrades",function()
			app:OpenPage("Research");app.research:Center(node.id);app.research:Select(node.id,true)
		end,BLUE)
	elseif data.activeId then
		-- The world marker carries the countdown; this panel only redraws on data changes.
		button=Theme.ActionButton(content,"Leave","Leave",function() app:Request("LeaveOperation") end,Theme.ActionColors.danger)
	else
		local home=state.armyState=="Home" or state.armyState=="Following"
		button=Theme.ActionButton(content,"Deploy",if not home then "Army busy" elseif cleared then "Defend again" else "Defend",function()
			if not home then return end
			cue("Confirm","UIPurchase")
			Theme.Motion:Ripple(button,WHITE)
			app:Request("StartOperation",{operationId=id})
		end,if home then GREEN else Theme.ActionColors.disabled)
		button.Active=home
		-- Army busy: the press answers with BindButton's "no" and the Locked cue.
		button.MouseButton1Down:Connect(function()
			if not button.Active then cue("Locked","Error",nil,{volume=0.5,voiceKey="Locked",cooldown=0.2}) end
		end)
	end
	button.Position,button.Size=UDim2.fromScale(.15,.79),UDim2.fromScale(.7,.17)
	self.deploy=button
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
	cue("MenuClose",nil,nil,{voiceKey="MenuClose",cooldown=0.2})
	Theme.Motion:Tween(panel,"operations-size",{Size=UDim2.fromScale(self.panelSize.X.Scale*.97,self.panelSize.Y.Scale*.97)},.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	Theme.Motion:Tween(panel,"position",{Position=UDim2.fromScale(self.panelPosition.X.Scale,self.panelPosition.Y.Scale+.025)},.16)
	Theme.Motion:Tween(panel,"operations-fade",{GroupTransparency=1},.16,nil,nil,finish)
end

-- October 14 Missions: sites announce themselves (MissionTracker), so the old
-- "loyalists are gathering" scout alert no longer runs.
function Panel:StepAlert(_state) end

-- The scout report itself (also reachable from Studio test tools).
function Panel:ShowAlert()
	self.app:Notify("Loyalists are gathering. Open Invasions to repel them.","info")
	local icon=self.app.researchExtras and self.app.researchExtras.operations
	local visual=icon and icon:FindFirstChild("Visual")
	if visual then
		-- Shared Motion: honours reduced motion and the icon's own press channel.
		Theme.Motion:Tween(visual,"pop",{Size=UDim2.fromScale(1.15,1.15)},.35,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,
			function() visual.Size=UDim2.fromScale(1,1) end,5,true)
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
	if result and not result.ok and result.action=="StartOperation" and self.deploy then Theme.Motion:Shake(self.deploy.Visual) end
end

function Panel:Destroy()
	self:Dismiss(true)
end

return Panel
