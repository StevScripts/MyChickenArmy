--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Config = require(game:GetService("ReplicatedStorage").PetRoll.Shared.Config)
local Catalog = require(game:GetService("ReplicatedStorage").PetRoll.Shared.PetCatalog)
local Progression = require(game:GetService("ReplicatedStorage").PetRoll.Shared.Progression)
local CampCommand=require(game:GetService("ReplicatedStorage").PetRoll.Shared.CampCommand)
local Theme = require(script.Parent.UITheme)
local RollPresentationController = require(script.Parent.RollPresentationController)
local C = Theme.Colors
local BaseController = {}
BaseController.__index = BaseController

function BaseController.new(app)
	return setmetatable({app = app, connections = {}, promptFilters = {}, alive = true, effects = 0, poll = 0}, BaseController)
end

function BaseController:HitAt(point)
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	-- GetMouseLocation includes the topbar offset; preserve matching viewport coordinates.
	local ray = camera:ViewportPointToRay(point.X, point.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	if Players.LocalPlayer.Character then table.insert(exclude, Players.LocalPlayer.Character) end
	for _, name in {"PetRollBattleVisuals", "PetRollLocalEffects"} do
		local folder = workspace:FindFirstChild(name)
		if folder then table.insert(exclude, folder) end
	end
	params.FilterDescendantsInstances = exclude
	return workspace:Raycast(ray.Origin, ray.Direction * 1200, params)
end

function BaseController:CommandFor(part)
	local state = self.app.state
	if not state or (state.armyState ~= "Home" and state.armyState ~= "Deployed") then return nil end
	local target = part
	while target and target ~= workspace and not target:GetAttribute("CommandTarget") do target = target.Parent end
	if not target or target == workspace then return nil end
	local id = target:GetAttribute("CommandTarget")
	local foreignCamp = string.sub(id, 1, 5) == "camp:" and target:GetAttribute("LaneOwnerIndex") ~= nil and target:GetAttribute("LaneOwnerIndex") ~= state.plotIndex
	if foreignCamp then return nil end
	if string.sub(id,1,5)=="base:" then return nil end
	for _, entry in state.targets or {} do
		if entry.id ~= id then continue end
		local income = if id == "income:1" then state.incomeOutpost else nil
		if id == "income:1" and not income then return nil end
		local _, _, _, selectedCount, deployedCount = self.app:Counts()
		local armyCount = if state.armyState == "Home" then selectedCount else deployedCount
		local available = if income then income.available else entry.available
		local allowed = available and armyCount > 0
		local reason = if not available then (if income then income.reason else entry.reason) elseif armyCount == 0 then "Buy a chicken at your podium first"
			else ""
		local ratio = (state.power or 0) / math.max(entry.power or 1, 1)
		local strength = if (entry.power or 0) == 0 then "Undefended" elseif ratio >= 1.5 then "You look stronger"
			elseif ratio >= 0.85 then "A close match" else "A tough fight"
		local text = if allowed then "Send army · " .. strength .. "\n" .. entry.count .. " defenders · $" .. Theme.Money(entry.killRewardMin or 0) .. (if entry.killRewardMax~=entry.killRewardMin then "–"..Theme.Money(entry.killRewardMax or 0) else "") .. "/kill"
			else reason
		if allowed and entry.via then text = "Via " .. entry.via .. "\nEarlier camps are fought in order" end
        if allowed and entry.ownerId and not entry.via then text=if entry.owned then "Station army" else "Capture territory" end
		if income then
			text = if allowed then income.action or "Conquer" else reason or "Territory busy"
			local deadline = if (income.retryEndsAt or 0) > workspace:GetServerTimeNow() then income.retryEndsAt else income.graceEndsAt
			if not allowed and deadline and deadline > workspace:GetServerTimeNow() then
				text ..= " · " .. math.ceil(deadline - workspace:GetServerTimeNow()) .. "s"
			end
		end
		return {model = target, action = if allowed then "Attack" else nil, targetId = id,
			title = entry.name, text = text, promptAction = income and text,
			owned=entry.owned and not entry.via, color = if not allowed then C.line elseif entry.owned and not entry.via then C.green else C.red}
	end
	return nil
end

function BaseController:HomePet(id)
	local state = self.app.state
	local root = workspace:FindFirstChild("PetRollWorld")
	local plot = state and root and root:FindFirstChild("Plot" .. state.plotIndex)
	local pets = plot and plot:FindFirstChild("Pets")
	return pets and pets:FindFirstChild(id)
end

-- Snapshot-only guidance is shared by the small HUD line and destination beacon.
-- It never blocks a purchase, roll or early deployment.
function BaseController.OpeningGuidance(state)
	if not state or state.armyState ~= "Home" or state.outgoing or state.incoming
		or (state.capacity or 3) > 4 or (state.campsWon or 0) > 0 or state.kingCleared
		or (state.progression and state.progression.rank or 1) > 1
		or (state.tutorial and state.tutorial.wonCamp) then return nil end
	for _, won in state.firstWins or {} do if won then return nil end end
	for _, won in state.frontierWins or {} do if won then return nil end end
	local coins, selected = state.coins or 0, state.selectedCount or #(state.selectedIds or {})
	local processor=state.eggs and state.eggs.processor
	if processor and processor.enabled and processor.readyCash>0 then
		return {target="EggCash",text="Collect your cash from the pad in front of the egg board"}
	end
	if state.eggs and state.eggs.requiresDeposit and (state.eggs.carriedValue or 0)>0 then
		return {target="EggDeposit",text=if processor and processor.enabled then "Deposit eggs at your stand to start selling" else "Walk onto the green pad to sell eggs"}
	end
	if (state.capacity or 3) < 4 then
		local slot = state.nextSlot
		if not slot or not slot.unlocked then return nil end
		if coins < slot.price then return {target = "Yard", text = "Collect eggs for your fourth slot"} end
		return {text = "Open Upgrades to add a fourth chicken"}
	end
	if selected >= 4 then return {target = "Camp1", text = "Try your bigger army"} end
	local offer = state.offer
	local definition = offer and Catalog[offer.species]
	local offerPrice = if definition then offer.price or definition.price else nil
	if definition and offerPrice and coins < offerPrice then
		if coins < Catalog.Duck.price then
			return {target = "Yard", text = if offerPrice > Catalog.Duck.price
				then "Collect eggs · keep this offer or roll FREE" else "Collect eggs for your fourth fighter"}
		end
		-- Keeping a rare offer is valid. Free rerolls remain a visible alternative.
		return {target = "RollStation", text = "Save for this chicken · or roll again FREE"}
	elseif definition then
		return {target = "RollStation", text = "Buy your fourth fighter"}
	end
	return {target = "RollStation", text = "Roll a fourth fighter · FREE"}
end

function BaseController:PulseModel(model, color)
	if not model or not model.Parent or not self.folder then return end
	local highlight = Instance.new("Highlight")
	highlight.FillColor, highlight.FillTransparency = color or C.gold, if self.app.reducedMotion then 1 else 0.35
	highlight.OutlineColor, highlight.OutlineTransparency = color or C.gold, 0.1
	highlight.Adornee, highlight.Parent = model, self.folder
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	if not self.app.reducedMotion then
		TweenService:Create(highlight, TweenInfo.new(0.45), {FillTransparency = 1, OutlineTransparency = 1}):Play()
	end
	Debris:AddItem(highlight, 0.55)
end

function BaseController:PetPulse(id, color)
	if not id or self.app.reducedMotion then return end
	task.delay(0.15, function()
		if not self.alive then return end
		local model = self:HomePet(id)
		if not model then return end
		self:PulseModel(model, color)
	end)
end



-- Keep Enabled exclusively server-owned. Suppressing a foreign prompt's range
-- hides its native UI without remembering (and later restoring) stale cooldown state.
-- Reserve E for the side the player actually walks toward, even during cooldown
-- or an empty podium. A reveal alone must never switch a lever press into a buy.
function BaseController:RollPromptChoice(station)
	local character=Players.LocalPlayer.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local plot=station.Parent
	local primary=plot and plot:FindFirstChild("RollStation")
	local lever=primary and primary:FindFirstChild("LeverBase")
	if not root or not lever then return nil end
	local function distance(part)
		return Vector2.new(root.Position.X-part.Position.X,root.Position.Z-part.Position.Z).Magnitude
	end
	local nearest,best=nil,math.huge
	for _,candidate in plot:GetChildren() do
		local podium=candidate:FindFirstChild("Podium")
		if candidate:GetAttribute("IsRollStation") and candidate:GetAttribute("Unlocked")~=false and podium then
			local value=distance(podium)
			if value<best then nearest,best=candidate,value end
		end
	end
	local rollDistance=distance(lever)
	local choice=if rollDistance<=best then "RollPrompt" else "BuyPrompt"
	if self.rollPromptPlot==plot then
		if self.rollPromptChoice=="RollPrompt" and best+0.75>=rollDistance then choice="RollPrompt"
		elseif self.rollPromptChoice=="BuyPrompt" and rollDistance+0.75>=best then choice="BuyPrompt" end
	end
	self.rollPromptPlot,self.rollPromptChoice=plot,choice
	if choice=="RollPrompt" then return if station==primary then choice else nil end
	return if station==nearest then choice else nil
end

function BaseController:FilterStationPrompt(prompt, world)
	if not prompt:IsA("ProximityPrompt") or self.promptFilters[prompt] then return end
	local isMerge = prompt.Name == "MergePrompt"
	if prompt.Name ~= "RollPrompt" and prompt.Name ~= "BuyPrompt" and prompt.Name ~= "RecruitTierPrompt" and not isMerge then return end
	local anchorName = if isMerge then "MergeStand" else "RollStation"
	local station = prompt.Parent
	while station and station~=world and station.Name~=anchorName and not (not isMerge and station:GetAttribute("IsRollStation")) do station=station.Parent end
	if not station or station == world then return end
	local ownerSource = station
	local entry = {distance = prompt.MaxActivationDistance, connections = {}, closed = false}
	self.promptFilters[prompt] = entry
	local function apply()
		if entry.closed or not prompt.Parent then return end
		local owner = ownerSource:GetAttribute("OwnerUserId") or ownerSource:GetAttribute("OwnerId")
		local allowedOwner = owner == Players.LocalPlayer.UserId and (not isMerge or Config.Features.Merging)
		if allowedOwner and (prompt.Name=="RollPrompt" or prompt.Name=="BuyPrompt") then
			allowedOwner=self:RollPromptChoice(station)==prompt.Name
		end
		local distance = if allowedOwner and not self.app.panel.Visible and not self.app.dialogueActive then entry.distance else 0
		entry.appliedDistance = distance
		if prompt.MaxActivationDistance ~= distance then prompt.MaxActivationDistance = distance end
	end
	entry.apply = apply
	function entry.cleanup()
		if entry.closed then return end
		entry.closed = true
		for _, connection in entry.connections do connection:Disconnect() end
		self.promptFilters[prompt] = nil
		if prompt.Parent and prompt.MaxActivationDistance == entry.appliedDistance then prompt.MaxActivationDistance = entry.distance end
	end
	for _, attribute in {"OwnerUserId", "OwnerId"} do
		table.insert(entry.connections, ownerSource:GetAttributeChangedSignal(attribute):Connect(apply))
	end
	table.insert(entry.connections, prompt:GetPropertyChangedSignal("MaxActivationDistance"):Connect(function()
		-- Comparing the last applied value also handles deferred signal delivery.
		if entry.closed or prompt.MaxActivationDistance == entry.appliedDistance then return end
		entry.distance = prompt.MaxActivationDistance
		apply()
	end))
	table.insert(entry.connections, prompt.AncestryChanged:Connect(function()
		if not prompt:IsDescendantOf(world) then entry.cleanup() end
	end))
	apply()
end

function BaseController:RefreshPromptOwnership()
	for _, entry in self.promptFilters do entry.apply() end
end

function BaseController:UpdateMergeStand()
	if self.app.panel.Visible and self.app.page=="Merge" then
		local browser=self.app.mergeBrowser
		if not browser or not browser:NearStand() then self.app:ClosePanel() else browser:UpdateAction() end
	end
end

function BaseController:Start()
	local player = Players.LocalPlayer
	table.insert(self.connections,self.app.panel:GetPropertyChangedSignal("Visible"):Connect(function()
		self:RefreshPromptOwnership();self:UpdateObjective()
		if self.app.hud then self.app.hud:UpdateOpening(self.app.state);self.app.hud:UpdateTerritory(self.app.state) end
	end))
	local function restoreCamera(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if self.alive and humanoid and character == player.Character and workspace.CurrentCamera then
			workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
			workspace.CurrentCamera.CameraSubject = humanoid
		end
	end
	table.insert(self.connections, player.CharacterAdded:Connect(restoreCamera))
	if player.Character then task.spawn(restoreCamera, player.Character) end
	local old = workspace:FindFirstChild("PetRollLocalEffects")
	if old then old:Destroy() end
	self.folder = Instance.new("Folder")
	self.folder.Name, self.folder.Parent = "PetRollLocalEffects", workspace
	local function localHomeTagsOnly(item)
		if not item:IsA("BillboardGui") or item.Name ~= "Tag" then return end
		local model = item:FindFirstAncestorOfClass("Model")
		if not model or not model:GetAttribute("PetId") then return end
		local owner = model:GetAttribute("OwnerUserId") or model:GetAttribute("OwnerId")
		if owner and owner ~= player.UserId then item.Enabled = false end
	end
	local world = workspace:WaitForChild("PetRollWorld", 15)
	if world then
		self.roller = RollPresentationController.new(self.app)
		self.roller:Start(world)
		for _, item in world:GetDescendants() do localHomeTagsOnly(item);self:FilterStationPrompt(item, world) end
		table.insert(self.connections, world.DescendantAdded:Connect(function(item)
			if item:IsA("BillboardGui") or item:IsA("ProximityPrompt") then
				task.defer(function()
					if self.alive and item.Parent then localHomeTagsOnly(item);self:FilterStationPrompt(item, world) end
				end)
			end
		end))
	end
	local prompt=Instance.new("ProximityPrompt")
	prompt.Name,prompt.KeyboardKeyCode,prompt.ActionText="ArmyCommandPrompt",Enum.KeyCode.E,"Send army"
	prompt.MaxActivationDistance,prompt.HoldDuration,prompt.RequiresLineOfSight=Config.CommandDistance,0.15,false
	prompt.Exclusivity,prompt.Enabled=Enum.ProximityPromptExclusivity.OneGlobally,false
	prompt.Style=Enum.ProximityPromptStyle.Default
	self.commandPrompt=prompt
	local highlight=Instance.new("Highlight")
	highlight.Name,highlight.Enabled,highlight.Parent="AttackCampHighlight",false,self.folder
	highlight.FillColor,highlight.OutlineColor=C.red,C.red
	highlight.FillTransparency,highlight.OutlineTransparency=0.9,0.05
	highlight.DepthMode=Enum.HighlightDepthMode.Occluded
	self.commandHighlight=highlight
	self.commandAnchor=Instance.new("Attachment")
	self.commandAnchor.Name,self.commandAnchor.Position="ArmyCommandAnchor",Vector3.new(0,2.5,0)
	prompt.Parent=self.commandAnchor
	self:CreateCommandHeading()
	table.insert(self.connections,prompt.Triggered:Connect(function()
		local command=self.nearestCommand
		command=command and self:CommandFor(command.model)
		if command and command.action and not self.app.panel.Visible and not self.app.dialogueActive and not UserInputService:GetFocusedTextBox() then
			self.app.audio:Play("Click")
			self.app:Request(command.action,{targetId=command.targetId})
		end
	end))
	table.insert(self.connections,RunService.Heartbeat:Connect(function(dt)
		self.poll+=dt
		if self.poll<0.1 then return end
		self.poll=0;self:RefreshPromptOwnership();self:PollCommand();self:UpdateObjective();self.app:StepRecruitFeedback();self:UpdateMergeStand()
		self.app.hud:UpdateTerritory(self.app.state)
	end))
	-- Clicking a chicken still opens its inventory entry. Ground clicks never issue army orders.
	table.insert(self.connections,UserInputService.InputBegan:Connect(function(input,processed)
		if processed or self.app.panel.Visible or self.app.dialogueActive or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
		local state=self.app.state
		local hit=state and self:HitAt(UserInputService:GetMouseLocation())
		local model=hit and hit.Instance:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("PetId") and (model:GetAttribute("OwnerUserId") or model:GetAttribute("OwnerId"))==state.userId then self.app:SelectPet(model:GetAttribute("PetId")) end
	end))

end

-- A world-space heading supplements the native E prompt; it never replaces its input UI.
function BaseController:CreateCommandHeading()
	local gui=Instance.new("BillboardGui")
	gui.Name,gui.Size,gui.SizeOffset="CampAttackHeading",UDim2.fromOffset(260,44),Vector2.new(0,2)
	gui.AlwaysOnTop,gui.LightInfluence,gui.MaxDistance=true,0,150
	gui.Enabled,gui.Adornee,gui.Parent=false,self.commandAnchor,Players.LocalPlayer.PlayerGui
	local label=Theme.Display(gui,"Attack","⚔ ATTACK",36,C.red)
	label.Size,label.TextXAlignment=UDim2.fromScale(1,1),Enum.TextXAlignment.Center
	self.commandHeading=gui
	self.commandPromptShown=false
	table.insert(self.connections,self.commandPrompt.PromptShown:Connect(function()
		self.commandPromptShown=true
		self:UpdateCommandPresentation()
	end))
	table.insert(self.connections,self.commandPrompt.PromptHidden:Connect(function()
		self.commandPromptShown=false
		self:UpdateCommandPresentation()
	end))
end

function BaseController:UpdateCommandPresentation()
	local command=self.nearestCommand
	local visible=command~=nil and self.commandPrompt.Enabled and self.commandPromptShown
		and not self.app.panel.Visible and not self.app.dialogueActive and not UserInputService:GetFocusedTextBox()
	local hostile=command and command.action=="Attack" and not command.owned
	self.commandHighlight.Enabled=visible
	self.commandHighlight.Adornee=command and command.model
	if command then
		self.commandHighlight.FillColor,self.commandHighlight.OutlineColor=command.color,command.color
	end
	self.commandHeading.Enabled=visible and hostile==true
end

-- One local destination beacon: exploration stays readable without another map menu.
function BaseController:UpdateObjective()
 local state=self.app.state
 local world=workspace:FindFirstChild("PetRollWorld")
 if not state or not world then return end
 if not self.objective then
  local gui=Instance.new("BillboardGui")
  gui.Name,gui.Size,gui.StudsOffsetWorldSpace="NextDestination",UDim2.fromOffset(90,46),Vector3.new(0,7,0)
  gui.AlwaysOnTop,gui.MaxDistance,gui.Parent=true,500,Players.LocalPlayer.PlayerGui
  local label=Instance.new("TextLabel")
  label.Size,label.BackgroundTransparency=UDim2.fromScale(1,1),1
  label.Font,label.TextSize,label.Text=Enum.Font.SourceSansBold,22,"NEXT\n▼"
  label.TextColor3,label.TextStrokeColor3,label.TextStrokeTransparency=Theme.Arcade.gold,Color3.fromRGB(25,35,20),0
  label.Parent=gui;self.objective=gui
 end
 local target
 local guidance=BaseController.OpeningGuidance(state)
 local plot=world:FindFirstChild("Plot"..state.plotIndex)
 local lane=world:FindFirstChild("Lane"..state.plotIndex)
 if guidance then
  if guidance.target=="Camp1" then target=lane and lane:FindFirstChild("Camp1")
  elseif guidance.target=="EggDeposit" then target=plot and plot:FindFirstChild("sellpart",true)
  elseif guidance.target=="EggCash" then
   local board=world:FindFirstChild("EggCollectionBoard") or (plot and plot:FindFirstChild("EggCollectionBoard",true))
   target=board and board:FindFirstChild("TouchPart",true)
  elseif guidance.target=="Yard" then
   local pets=plot and plot:FindFirstChild("Pets")
   local model=pets and pets:FindFirstChildWhichIsA("Model")
   target=model and model.PrimaryPart
  elseif guidance.target then target=plot and plot:FindFirstChild(guidance.target) end
 end
 if not guidance then
 for i=1,#Progression.Camps(1) do if not (state.routeCamps or {})[i] then target=lane and lane:FindFirstChild("Camp"..i);break end end
 if not target and state.ownsKing then
  local frontier=world:FindFirstChild("Outposts")
  for i=1,#Progression.Outposts() do if not (state.routeOutposts or {})[i] then target=frontier and frontier:FindFirstChild("Outpost"..i);break end end
 end
 if not target and not state.ownsKing then
  local arena=world:FindFirstChild("KingArena")
	 target=arena
 end
 end
 local anchor=if target and target:IsA("BasePart") then target
  elseif target and target.Name=="RollStation" then target:FindFirstChild("RevealPad")
  else CampCommand.Anchor(target)
 self.objective.Adornee=anchor
 self.objective.Enabled=anchor~=nil and not self.app.panel.Visible and not self.app.dialogueActive
  and state.armyState=="Home" and not state.incoming
  and not (self.commandHeading.Enabled and self.nearestCommand and self.nearestCommand.model==target)
end

function BaseController:PollCommand()
	local state=self.app.state
	local character=Players.LocalPlayer.Character
	local body=character and character:FindFirstChild("HumanoidRootPart")
	local world=workspace:FindFirstChild("PetRollWorld")
	local nearest,bestPart,bestDistance=nil,nil,math.huge
	if state and body and world and not self.app.panel.Visible and not self.app.dialogueActive and not UserInputService:GetFocusedTextBox() then
		local candidates={}
		local arena=world:FindFirstChild("KingArena")
		if arena then table.insert(candidates,arena) end
		local income=state.incomeOutpost and world:FindFirstChild("IncomeOutpost")
		if income then table.insert(candidates,income) end
		local frontier=world:FindFirstChild("Outposts")
  if frontier then for _,camp in frontier:GetChildren() do table.insert(candidates,camp) end end
  local lane=world:FindFirstChild("Lane"..state.plotIndex)
		if lane then for _,camp in lane:GetChildren() do table.insert(candidates,camp) end end
		for i=1,#Config.PlotPositions do local plot=world:FindFirstChild("Plot"..i);if plot then table.insert(candidates,plot) end end
		for _,model in candidates do
			local part=CampCommand.Anchor(model)
			if not part then continue end
			local distance=(body.Position-(part.Position+Vector3.new(0,2.5,0))).Magnitude
			if distance>bestDistance or not CampCommand.InRange(model,body.Position) then continue end
			local camera=workspace.CurrentCamera
			local visible=false
			if camera then local _,onScreen=camera:WorldToViewportPoint(part.Position+Vector3.new(0,2.5,0));visible=onScreen end
			if not visible then continue end
			local command=self:CommandFor(model)
			if command then nearest,bestPart,bestDistance=command,part,distance end
		end
	end
	self.nearestCommand=nearest
	if nearest then
		self.commandAnchor.Parent=bestPart
		self.commandPrompt.MaxActivationDistance=CampCommand.Radius(nearest.model)
		self.commandPrompt.ActionText=if not nearest.action then nearest.text elseif nearest.owned then "Station army" else "Attack"
		self.commandPrompt.ObjectText=nearest.title..(if nearest.action=="Attack" and nearest.text:find("Via ") then " · earlier camps first" else "")
	end
	self.commandPrompt.Enabled=nearest~=nil
	self:UpdateCommandPresentation()
end

function BaseController:Destroy()
	self.alive = false
	if self.roller then self.roller:Destroy() end
	for _, connection in self.connections do connection:Disconnect() end
	local filters = {}
	for _, entry in self.promptFilters do table.insert(filters, entry) end
	for _, entry in filters do entry.cleanup() end
	if self.folder then self.folder:Destroy() end
	if self.commandPrompt then self.commandPrompt:Destroy() end
	if self.commandAnchor then self.commandAnchor:Destroy() end
	if self.commandHeading then self.commandHeading:Destroy() end
 if self.objective then self.objective:Destroy() end
end

return BaseController
