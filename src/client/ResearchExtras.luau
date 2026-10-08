--!strict
-- Research-unlocked actions use the existing menu shell; the tree itself stays full screen.
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Research=require(Shared.ResearchCatalog)
local Operations=require(Shared.OperationCatalog)
local Theme=require(script.Parent.UITheme)
local Extras={}
Extras.__index=Extras
-- Matches ArmyService.SaveFormation / ResearchRules.Read: 1-40 bytes of UTF-8.
local MAX_FORMATION_NAME=40

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
	self.rally=Theme.Button(app.hudLayer,"Rally","Rally",function() app:Request("Rally") end,Theme.ActionColors.purchase)
	self.rally.AnchorPoint,self.rally.Position,self.rally.Size=Vector2.new(1,.5),UDim2.fromScale(.985,.58),UDim2.fromScale(.16,.07)
	Theme.Aspect(self.rally,3.9);Theme.ScaleText(self.rally);self.rally.Visible=false
	self.goal=Theme.Button(app.hudLayer,"ResearchGoal","",function()
		local data=app.state and app.state.research
		if data and data.pinned then app:OpenPage("Research");app.research:Center(data.pinned);app.research:Select(data.pinned,true) end
	end,Theme.ActionColors.navigation)
	self.goal.AnchorPoint,self.goal.Position,self.goal.Size=Vector2.new(1,0),UDim2.fromScale(.985,.12),UDim2.fromScale(.24,.045)
	Theme.Aspect(self.goal,7);Theme.ScaleText(self.goal);self.goal.Visible=false
	local elapsed=0
	table.insert(self.connections,RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt;if elapsed>=.25 then elapsed=0;self:UpdateRally() end
	end))
	ContextActionService:BindAction("PetRollRally",function(_,state)
		if state~=Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() or app.panel.Visible or app.research.root.Visible or not self.rally.Visible then return Enum.ContextActionResult.Pass end
		app:Request("Rally");return Enum.ContextActionResult.Sink
	end,false,Enum.KeyCode.G,Enum.KeyCode.ButtonL2)
	return self
end

function Extras:UpdateRally()
	local state=self.app.state;local data=state and state.research
	self.rally.Visible=data~=nil and data.effects.rallySeconds>0 and state.armyState=="Fighting" and not self.app.panel.Visible
	if not self.rally.Visible then return end
	local now=self.app.research:Now()
	local active=math.max(0,math.ceil((data.rallyActiveUntil or 0)-now))
	local cooldown=math.max(0,math.ceil(data.rallyReadyAt-now))
	local input=UserInputService.PreferredInput
	local hint=if input==Enum.PreferredInput.Gamepad then " (LT)" elseif input==Enum.PreferredInput.KeyboardAndMouse then " (G)" else ""
	self.rally.Text=if active>0 then "Rally active · "..active.."s" elseif cooldown>0 then "Rally · "..cooldown.."s" else "Rally"..hint
	self.rally.Active,self.rally.Interactable=cooldown==0,cooldown==0
end

function Extras:Receive(state,result)
	local data=state.research;if not data then return end
	local id=data.pinned
	self.goal.Visible=id~=nil
	if id then
		local steps,cursor=0,id
		while cursor and not data.completed[cursor] do steps+=1;cursor=Research.Nodes[cursor].prerequisite end
		self.goal.Text=Research.Nodes[id].name..(if steps>0 then " · "..steps.." to go" else " · completed")
	end
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
	if count==0 then
		app:Text("Unlock","Research Formation Book to save your selected army.",22,55)
		app:Button("ResearchFormations","View Formation Book",function() app:OpenPage("Research");app.research:Center("S12");app.research:Select("S12",true) end)
		return
	end
	app:Text("Help","Save your current army, then switch back to it here. Missing chickens are skipped; capacity and the one-Colossal limit still apply.",18,65)
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
		app:Button("SaveFormation"..slot,if preset then "Replace with current army" else "Save current army",function()
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
	app.panelTitle.Text="Operations"
	if not data then return end
	if (data.pendingReward or 0)>0 then
		app:Text("PendingReward","$"..Theme.Money(data.pendingReward).." earned and saved. Spend some cash; this reward pays automatically when your wallet has room.",20,70)
		return
	end
	if data.activeId then
		app:Text("Current",Operations.Encounters[data.activeId].name.." is in progress.",24,48)
		app:Button("Leave","Leave Operation · no completion reward",function() app:Request("LeaveOperation") end,Theme.ActionColors.danger)
		return
	end
	app:Text("Rules","Deploy your selected army to a separate arena. Defeat every enemy and capture the center. Your starting lineup fights without reinforcements; leaving ends the challenge.",18,80)
	local tabs=app:Text("Tiers","",20,45)
	for index,name in Operations.Tiers do
		local button=Theme.Button(tabs,name,name,function() self.tier=index;app:RenderPanel(true) end,Operations.Colors[index])
		button.Position,button.Size=UDim2.fromScale((index-1)*.335,0),UDim2.fromScale(.32,1)
		Theme.ScaleText(button)
	end
	if data.tier<self.tier then
		local researchId=({"S15","S16","S17"})[self.tier]
		app:Text("Locked","Research "..Research.Nodes[researchId].name.." to open these challenges.",22,55)
		app:Button("UnlockOperations","View research",function() app:OpenPage("Research");app.research:Center(researchId);app.research:Select(researchId,true) end)
		return
	end
	for index=1,3 do
		local id=self.tier..":"..index;local definition=Operations.Encounters[id];local cleared=data.wins[id]
		app:Text("Title"..index,(if cleared then "✓ " else "")..definition.name,25,40,Operations.Colors[self.tier])
		app:Text("Details"..index,definition.description.."\nEnemy power "..Theme.Money(Operations.Power(id)),18,50)
		app:Button("Start"..index,(if cleared then "Replay" else "Deploy").." · $"..Theme.Money(if cleared then definition.replayCash else definition.firstCash).." reward",function()
			app:Request("StartOperation",{operationId=id,expectedRevision=state.research.revision})
		end,Theme.ActionColors.purchase)
	end
	app:Text("Banner","Clear all three to earn the "..Operations.Tiers[self.tier].." banner"..(if self.tier==3 then " and Royal Commander title." else "."),19,50)
	app:Button("Formations","Manage army formations",function() app:OpenPage("Formations") end)
end

function Extras:Destroy()
	ContextActionService:UnbindAction("PetRollRally")
	for _,connection in self.connections do connection:Disconnect() end
	self.rally:Destroy();self.goal:Destroy()
end

return Extras
