--!strict
-- Rally and the older Formations/Missions pages use the existing menu shell; the
-- Upgrades tree itself stays full screen.
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Operations=require(Shared.OperationCatalog)
local Theme=require(script.Parent.UITheme)
local Extras={}
Extras.__index=Extras
-- Matches ArmyService.SaveFormation / ResearchRules.Read: 1-40 bytes of UTF-8.
local MAX_FORMATION_NAME=40
local RALLY_SHOWN_X,RALLY_HIDDEN_X=.988,1.12

local function clampName(text)
	if #text<=MAX_FORMATION_NAME then return text end
	local last=0
	-- Cut on a character boundary; invalid UTF-8 falls back to a plain byte cut.
	local ok=pcall(function()
		for position,code in utf8.codes(text) do
			local finish=position+#utf8.char(code)-1
			if finish>MAX_FORMATION_NAME then break end
			last=finish
		end
	end)
	return text:sub(1,if ok then last else MAX_FORMATION_NAME)
end

function Extras.new(app)
	local self=setmetatable({app=app,tier=1,connections={}},Extras)
	-- October 16 owner request: a war-horn icon that slides in from the right edge
	-- while the army is fighting, like Call Army / My Base pop out of My Army.
	self.rally=Theme.IconButton(app.hudLayer,"Rally","Rally",Theme.Assets.Rally,function() self:PressRally() end)
	self.rally.AnchorPoint,self.rally.Position,self.rally.Size=Vector2.new(1,.5),UDim2.fromScale(RALLY_HIDDEN_X,.68),UDim2.fromScale(.082,.16)
	Theme.Aspect(self.rally,136/132);self.rally.Visual.Label.TextScaled=true;self.rally.Visual.Label.Position=UDim2.fromScale(0,.64)
	Theme.ScaleText(self.rally);self.rally.Visible,self.rally.Interactable=false,false
	self.rallyShown=false
	-- October 21 game feel: a thin cooldown bar under the label fills as Rally comes
	-- back (Theme.Motion:Progress); hidden while Rally is ready or active.
	local bar=Theme.Frame(self.rally.Visual,"Cooldown",UDim2.fromScale(.72,.05),Color3.new(0,0,0))
	bar.AnchorPoint,bar.Position,bar.BackgroundTransparency,bar.ZIndex,bar.Visible=Vector2.new(.5,1),UDim2.fromScale(.5,.985),.45,5,false
	local fill=Theme.Frame(bar,"Fill",UDim2.fromScale(0,1),Theme.Colors.gold);fill.ZIndex=6
	self.rallyBar,self.rallyFill=bar,fill
	-- October 14 launch: a King clear opens Invasions without research, so the page
	-- needs an entry besides the completed S15 node. Shares Rally's slot; Rally only
	-- shows while Fighting and this only while the army is home.
	-- October 13: an icon button like the left HUD column (mission map art).
	self.operations=Theme.IconButton(app.hudLayer,"OperationsShortcut","Invasions",Theme.Assets.Operations,function() app.audio:Play("Click");app:OpenPage("Operations") end)
	self.operations.AnchorPoint,self.operations.Position,self.operations.Size=Vector2.new(1,.5),UDim2.fromScale(.988,.56),UDim2.fromScale(.082,.16)
	Theme.Aspect(self.operations,136/132);self.operations.Visual.Label.TextScaled=true
	Theme.ScaleText(self.operations);self.operations.Visible=false
	-- October 14 owner request: no pinned-research goal chip on the HUD (the
	-- Upgrades tree still shows the pinned node).
	local elapsed=0
	table.insert(self.connections,RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt;if elapsed>=.25 then elapsed=0;self:UpdateRally() end
	end))
	ContextActionService:BindAction("PetRollRally",function(_,state)
		if state~=Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() or app.panel.Visible or app.research.root.Visible or not self.rallyShown then return Enum.ContextActionResult.Pass end
		self:PressRally();return Enum.ContextActionResult.Sink
	end,false,Enum.KeyCode.G,Enum.KeyCode.ButtonL2)
	return self
end

-- Button, G or LT: the press answers at once (ring + Confirm cue, Click when the
-- cue is not authored); the server still decides whether Rally fires.
function Extras:PressRally()
	local app=self.app
	if self.rally.Active then
		Theme.Motion:Ripple(self.rally.Visual,Theme.Colors.gold)
		if app.audio:Has("Confirm") then app.audio:Play("Confirm",nil,{noFallback=true}) else app.audio:Play("Click") end
	else app.audio:Play("Click") end
	app:Request("Rally")
end

function Extras:UpdateRally()
	local state=self.app.state
	-- October 20 overhaul: Rally is a Gem Upgrade. Its length is in the shared effect
	-- table (state.effects) and its timing in state.rally; older servers sent both in
	-- state.research.
	local effects=state and (state.effects or (state.research and state.research.effects))
	local timing=state and (state.rally or state.research)
	-- October 14 Missions replace the Invasions menu; MissionTracker owns this slot.
	self.operations.Visible=false
	local shown=effects~=nil and timing~=nil and (effects.rallySeconds or 0)>0 and state.armyState=="Fighting" and not self.app.panel.Visible
	if shown~=self.rallyShown then
		self.rallyShown=shown
		local rally=self.rally
		if shown then rally.Visible=true else self.rallyCooling=false end
		rally.Interactable=shown
		Theme.Motion:Tween(rally,"slide",{Position=UDim2.fromScale(if shown then RALLY_SHOWN_X else RALLY_HIDDEN_X,.68)},
			.32,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,function()
				if not self.rallyShown then rally.Visible=false end
			end)
	end
	if not shown then return end
	local now=workspace:GetServerTimeNow()
	local active=math.max(0,math.ceil((timing.activeUntil or timing.rallyActiveUntil or 0)-now))
	local cooldown=math.max(0,math.ceil((timing.readyAt or timing.rallyReadyAt or 0)-now))
	local input=UserInputService.PreferredInput
	local hint=if input==Enum.PreferredInput.Gamepad then " (LT)" elseif input==Enum.PreferredInput.KeyboardAndMouse then " (G)" else ""
	self.rally.Text=if active>0 then "Active "..active.."s" elseif cooldown>0 then "Rally "..cooldown.."s" else "Rally"..hint
	-- The bar fills as the cooldown runs down; its length is the longest remaining
	-- time seen this cooldown (the server only sends the ready time).
	local cooling=cooldown>0 and active==0
	if cooling then
		self.rallyTotal=math.max(self.rallyTotal or 0,cooldown)
		if not self.rallyBar.Visible then self.rallyBar.Visible=true;self.rallyFill.Size=UDim2.fromScale(0,1) end
		Theme.Motion:Progress(self.rallyFill,1-cooldown/math.max(1,self.rallyTotal),.25,false)
	elseif self.rallyBar.Visible then
		self.rallyTotal=nil
		Theme.Motion:Cancel(self.rallyFill,"progress");self.rallyBar.Visible=false
	end
	-- A small pop the moment the cooldown ends, once per cooldown.
	if cooldown==0 and self.rallyCooling then Theme.Motion:Pop(self.rally.Visual,1.12) end
	self.rallyCooling=cooldown>0
	self.rally.Active=cooldown==0
end

function Extras:Receive(state,result)
	self:UpdateRally()
	if result and result.ok and result.action=="StartOperation" then self.app:ClosePanel() end
	local encounter=state.operations
	if encounter and encounter.encounterId~=self.viewedEncounter then
		self.viewedEncounter=encounter.encounterId
		if encounter.center then
			local c=encounter.center;local center=Vector3.new(c.x,c.y,c.z)
			-- Orient the normal player camera toward the fight once on arrival.
			local camera=workspace.CurrentCamera
			if camera then camera.CFrame=CFrame.lookAt(center+Vector3.new(0,22,56),center+Vector3.new(0,3,0)) end
		end
	end
	local operation=state.operations and state.operations.result
	if operation and operation.id~=self.lastOperation then
		self.lastOperation=operation.id
		if operation.first and operation.bannerTier>(self.bannerTier or 0) then
			self.app:Notify(Operations.Tiers[operation.bannerTier].." banner earned!",true)
		end
	end
	self.bannerTier=state.operations and state.operations.bannerTier or 0
end

function Extras:RenderFormations()
	local app=self.app;local state=app.state;local data=state.research
	app.panelTitle.Text="Army Formations"
	local count=data and data.effects.formations or 0
	-- October 20 overhaul: the Formation Book research left the Upgrades tree.
	if count==0 then
		app:Text("Unlock","Saved formations are not available right now.",22,55)
		app:Button("Army","Choose chickens",function() app:OpenPage("Army") end)
		return
	end
	app:Text("Help","Save your current Army, then switch back to it here. Missing chickens are skipped; capacity and the one-Colossal limit still apply.",18,65)
	for slot=1,count do
		local preset=data.formations[tostring(slot)]
		local row=app:Text("Formation"..slot,"",20,45)
		local name=Instance.new("TextBox")
		-- Shows the server's saved (filtered) name; input is capped at the server limit.
		name.Name,name.Text="Name",if preset then preset.name else "Formation "..slot
		name.PlaceholderText,name.ClearTextOnFocus="Formation name",false
		name.Font,name.TextScaled,name.TextColor3=Theme.Font,true,Theme.Colors.ink
		name.BackgroundColor3,name.BorderSizePixel=Theme.Colors.card,0
		name.Position,name.Size=UDim2.fromScale(.015,.02),UDim2.fromScale(.97,.94)
		name.Parent=row;Theme.Stroke(name,Theme.Colors.line,1)
		name:GetPropertyChangedSignal("Text"):Connect(function()
			local clamped=clampName(name.Text)
			if clamped~=name.Text then name.Text=clamped end
		end)
		app:Button("SaveFormation"..slot,if preset then "Replace with current Army" else "Save current Army",function()
			local text=clampName(name.Text:match("^%s*(.-)%s*$") or "")
			if text=="" then text="Formation "..slot end
			app:Request("SaveFormation",{slot=slot,name=text,expectedIds=state.selectedIds,expectedRevision=data.revision})
		end,Theme.ActionColors.navigation)
		if preset then
			app:Button("ApplyFormation"..slot,"Use "..preset.name.." · "..#preset.petIds.." chickens",function()
				app:Request("ApplyFormation",{slot=slot,expectedIds=state.selectedIds,expectedRevision=data.revision})
			end,Theme.ActionColors.purchase)
		end
	end
	app:Button("Army","Choose chickens",function() app:OpenPage("Army") end)
end

function Extras:RenderOperations()
	local app=self.app;local state=app.state;local data=state.operations
	app.panelTitle.Text="Invasions"
	if not data then return end
	if (data.pendingReward or 0)>0 then
		app:Text("PendingReward",Theme.Coins(data.pendingReward).." earned and saved. Spend some coins; this reward pays automatically when your wallet has room.",20,70)
		return
	end
	if data.activeId then
		app:Text("Current",Operations.Encounters[data.activeId].name.." is in progress.",24,48)
		app:Button("Leave","Leave Invasion · no completion reward",function() app:Request("LeaveOperation") end,Theme.ActionColors.danger)
		return
	end
	app:Text("Rules","Send your Army to repel the loyalists. Defeat every enemy to win. Your Army fights without reinforcements; leaving ends the Invasion.",18,80)
	local tabs=app:Text("Tiers","",20,45)
	for index,name in Operations.Tiers do
		local button=Theme.Button(tabs,name,name,function() self.tier=index;app:RenderPanel(true) end,Operations.Colors[index])
		button.Position,button.Size=UDim2.fromScale((index-1)*.335,0),UDim2.fromScale(.32,1)
		Theme.ScaleText(button)
	end
	-- data.tier is the server's combined tier. October 20 overhaul: tiers open by a King
	-- clear or Rebirth rank, no longer by research in Upgrades.
	if (data.tier or 0)<self.tier then
		local rebirth=type(Config.Rebirth)=="table" and Config.Rebirth.MissionTierRanks
		local rank=type(rebirth)=="table" and rebirth[self.tier] or ({5,10,15})[self.tier]
		app:Text("Locked",(if self.tier==1 then "Defeat the Chicken King or reach Rebirth "..rank else "Reach Rebirth "..rank).." to open these Missions.",22,55)
		return
	end
	for index=1,3 do
		local id=self.tier..":"..index;local definition=Operations.Encounters[id];local cleared=data.wins[id]
		app:Text("Title"..index,(if cleared then "✓ " else "")..definition.name,25,40,Operations.Colors[self.tier])
		app:Text("Details"..index,definition.description.."\nEnemy power "..Theme.Money(Operations.Power(id)),18,50)
		app:Button("Start"..index,(if cleared then "Defend again" else "Defend").." · "..Theme.CompactCoins(if cleared then definition.replayCash else definition.firstCash).." reward",function()
			app:Request("StartOperation",{operationId=id,expectedRevision=state.research and state.research.revision})
		end,Theme.ActionColors.purchase)
	end
	app:Text("Banner","Clear all three to earn the "..Operations.Tiers[self.tier].." banner"..(if self.tier==3 then " and Royal Commander title." else "."),19,50)
	app:Button("Formations","Manage Army formations",function() app:OpenPage("Formations") end)
end

function Extras:Destroy()
	ContextActionService:UnbindAction("PetRollRally")
	for _,connection in self.connections do connection:Disconnect() end
	self.rally:Destroy();self.operations:Destroy()
end

return Extras
