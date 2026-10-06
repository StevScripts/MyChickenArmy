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
local GuideArrow = require(script.Parent.GuideArrow)
local RollPresentationController = require(script.Parent.RollPresentationController)
local AutoCollectStandController = require(script.Parent.AutoCollectStandController)
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
	if not state then return nil end
	local canMove=state.armyState=="Home" or state.armyState=="Following" or state.armyState=="Deployed"
		or state.armyState=="Traveling" or state.armyState=="Fighting"
	local target = part
	while target and target ~= workspace and not target:GetAttribute("CommandTarget") do target = target.Parent end
	if not target or target == workspace then return nil end
	local id = target:GetAttribute("CommandTarget")
	local foreignCamp = string.sub(id, 1, 5) == "camp:" and target:GetAttribute("LaneOwnerIndex") ~= nil and target:GetAttribute("LaneOwnerIndex") ~= state.plotIndex
	if foreignCamp then return nil end
	if string.sub(id,1,5)=="base:" then return nil end
	for _, entry in state.targets or {} do
		if entry.id ~= id then continue end
		if not canMove and not entry.canUnclaim then return nil end
		local income = if id == "income:1" then state.incomeOutpost else nil
		if id == "income:1" and not income then return nil end
		local _, _, _, selectedCount, deployedCount = self.app:Counts()
		local armyCount = if state.armyState == "Home" or state.armyState == "Following" then selectedCount else deployedCount
		local available = if income then income.available else entry.available
		local allowed = canMove and available and armyCount > 0
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
			canUnclaim=entry.canUnclaim==true,
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
 local guide=require(game.ReplicatedStorage.PetRoll.Shared.TutorialGuide).Resolve(state)
 if not guide or guide.id=="Complete" then return nil end
 return {target=guide.target,text=guide.text,id=guide.id}
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
		self.autoCollectStand = AutoCollectStandController.new(self.app)
		self.autoCollectStand:Start(world)
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
	prompt.Exclusivity,prompt.Enabled=Enum.ProximityPromptExclusivity.OnePerButton,false
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
	local unclaim=Instance.new("ProximityPrompt")
	unclaim.Name,unclaim.ActionText="UnclaimBasePrompt","Unclaim Base"
	unclaim.KeyboardKeyCode,unclaim.GamepadKeyCode=Enum.KeyCode.R,Enum.KeyCode.ButtonY
	unclaim.Exclusivity,unclaim.Style=Enum.ProximityPromptExclusivity.OnePerButton,Enum.ProximityPromptStyle.Default
	unclaim.RequiresLineOfSight,unclaim.HoldDuration,unclaim.Enabled=false,0.15,false
	unclaim.UIOffset=Vector2.new(0,68)
	unclaim.Parent=self.commandAnchor
	self.unclaimPrompt=unclaim
	self:CreateCommandHeading()
	table.insert(self.connections,prompt.Triggered:Connect(function()
		local command=self.nearestCommand
		command=command and self:CommandFor(command.model)
		if command and command.action and not self.app.panel.Visible and not self.app.dialogueActive and not UserInputService:GetFocusedTextBox() then
			self.app.audio:Play("Click")
			self.app:Request(command.action,{targetId=command.targetId})
		end
	end))
	table.insert(self.connections,unclaim.Triggered:Connect(function()
		local command=self.nearestCommand
		command=command and self:CommandFor(command.model)
		if command and command.canUnclaim and not self.app.panel.Visible and not self.app.dialogueActive and not UserInputService:GetFocusedTextBox() then
			self.app.audio:Play("Click")
			self.app:Request("UnclaimTerritory",{targetId=command.targetId})
		end
	end))
	table.insert(self.connections,RunService.Heartbeat:Connect(function(dt)
		self.poll+=dt
		if self.poll<0.1 then return end
		self.poll=0;self:RefreshPromptOwnership();self:PollCommand();self:UpdateObjective();self.app:StepRecruitFeedback();self:UpdateMergeStand()
		if self.autoCollectStand then self.autoCollectStand:Step() end
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

-- Attachments follow the character and objective natively. The existing poll
-- only selects endpoints/visibility; Beam.TextureSpeed animates the white arrows.
function BaseController:StopGuideMotion()
	for _,tween in self.guideTweens or {} do tween:Cancel();tween:Destroy() end
	self.guideTweens={}
	if self.objective then self.objective.StudsOffsetWorldSpace=Vector3.new(0,6,0) end
end

function BaseController:UpdateGuideTrail(anchor, enabled)
	if not self.folder then return end
	local character=Players.LocalPlayer.Character
	local body=character and character:FindFirstChild("HumanoidRootPart")
	local goal=if anchor and anchor:IsDescendantOf(workspace) then (if anchor:IsA("Attachment") then anchor.WorldPosition else anchor.Position) else nil
	local delta=body and goal and Vector3.new(goal.X-body.Position.X,0,goal.Z-body.Position.Z)
	local visible=enabled and delta~=nil and delta.Magnitude>4
	local reduced=self.app.reducedMotion
	if self.guideMotionVisible~=visible or self.guideMotionReduced~=reduced then
		self:StopGuideMotion()
		self.guideMotionVisible,self.guideMotionReduced=visible,reduced
		if visible and not reduced then
			local bob=TweenService:Create(self.objective,TweenInfo.new(.65,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{StudsOffsetWorldSpace=Vector3.new(0,6.7,0)})
			table.insert(self.guideTweens,bob);bob:Play()
		end
	end
	if not visible then
		if self.guideBeam then self.guideBeam.Enabled=false end
		return
	end
	if not self.guideBeam then
		local beam=Instance.new("Beam")
		beam.Name,beam.Enabled="CommanderGuideBeam",false
		beam.Color,beam.Transparency=ColorSequence.new(Color3.new(1,1,1)),NumberSequence.new(.08)
		-- Roblox's beam-ready tutorial arrows run along the texture's vertical axis.
		beam.Texture,beam.TextureMode="rbxassetid://5886559421",Enum.TextureMode.Static
		beam.TextureLength,beam.Width0,beam.Width1=4,3,3
		beam.FaceCamera,beam.LightInfluence,beam.LightEmission=true,0,0
		beam.Segments,beam.Parent=1,self.folder
		self.guideBeam=beam
	end
	if not self.guideStart or self.guideStart.Parent~=body then
		if self.guideStart then self.guideStart:Destroy() end
		self.guideStart=Instance.new("Attachment")
		self.guideStart.Name,self.guideStart.Position="CommanderGuideStart",Vector3.new(0,-2,0)
		self.guideStart.Parent=body
	end
	local destination=anchor
	if not anchor:IsA("Attachment") then
		if not self.guideEnd or self.guideEnd.Parent~=anchor then
			if self.guideEnd then self.guideEnd:Destroy() end
			self.guideEnd=Instance.new("Attachment")
			self.guideEnd.Name,self.guideEnd.Position="CommanderGuideEnd",Vector3.new(0,anchor.Size.Y*.5+.15,0)
			self.guideEnd.Parent=anchor
		end
		destination=self.guideEnd
	elseif self.guideEnd then
		self.guideEnd:Destroy();self.guideEnd=nil
	end
	self.guideBeam.Attachment0,self.guideBeam.Attachment1=self.guideStart,destination
	self.guideBeam.TextureSpeed=if reduced then 0 else 1
	self.guideBeam.Enabled=true
end

-- A destination arrow remains visible while the Beam indicates the route.
function BaseController:UpdateObjective()
 local state=self.app.state
 local world=workspace:FindFirstChild("PetRollWorld")
 if not state or not world then
  self.guideWorldTarget,self.guideWorldParts,self.guideWorldStep=nil,nil,nil
  if self.objective then self.objective.Enabled=false end
  self:UpdateGuideTrail(nil,false)
  if self.app.commander then self.app.commander:ClearFocus() end
  return
 end
 if not self.objective then
  local gui=Instance.new("BillboardGui")
  gui.Name,gui.Size,gui.StudsOffsetWorldSpace="NextDestination",UDim2.fromOffset(140,108),Vector3.new(0,6,0)
  gui.AlwaysOnTop,gui.MaxDistance,gui.Parent=true,500,Players.LocalPlayer.PlayerGui
  local label=Theme.Display(gui,"Destination","NEXT",22,Color3.new(1,1,1))
  label.Size,label.TextScaled,label.TextXAlignment=UDim2.fromScale(1,.28),true,Enum.TextXAlignment.Center
  local arrow=GuideArrow(gui,"Arrow")
  arrow.Size,arrow.Position,arrow.AnchorPoint=UDim2.fromScale(.72,.72),UDim2.fromScale(.5,.64),Vector2.new(.5,.5)
  arrow.Rotation=90
  self.objective,self.objectiveCaption=gui,label
 end
 local target,focusTarget,focusParts
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
   local drop
   for _,egg in (state.eggs or {}).drops or {} do if not egg.flightAge then drop=egg;break end end
   local anchor=plot and plot:FindFirstChildWhichIsA("BasePart",true)
   if drop and anchor then
    if not self.eggObjective then self.eggObjective=Instance.new("Attachment");self.eggObjective.Name="CommanderEggTarget" end
    self.eggObjective.Parent=anchor
    self.eggObjective.WorldPosition=Vector3.new(drop.x,drop.y,drop.z)
    target=self.eggObjective
    local view=self.app.eggs and self.app.eggs.views[drop.id]
    focusTarget=view and view.gui
   else
    local pets=plot and plot:FindFirstChild("Pets")
    local model=pets and pets:FindFirstChildWhichIsA("Model")
    target=model and model.PrimaryPart
    focusTarget=model
   end
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
 local anchor=if target and (target:IsA("BasePart") or target:IsA("Attachment")) then target
  elseif target and target.Name=="RollStation" then target:FindFirstChild(if state.offer then "Podium" else "LeverBase") or target:FindFirstChild("RevealPad")
  else CampCommand.Anchor(target)
 if guidance and target and target.Name=="RollStation" and anchor then
  focusTarget=anchor
  focusParts={anchor}
  if state.offer then
   local record=self.roller and self.roller.records[target]
   if record and record.preview then table.insert(focusParts,record.preview) end
  else
   for _,name in {"LeverArm","LeverHandle"} do
    local part=target:FindFirstChild(name)
    if part then table.insert(focusParts,part) end
   end
  end
 end
 self.guideWorldTarget=if guidance then focusTarget or target else nil
 self.guideWorldParts,self.guideWorldStep=focusParts,guidance and guidance.id
 self.objective.Adornee=anchor
 self.objectiveCaption.Text=if not guidance then "NEXT" elseif guidance.target=="RollStation" then (if state.offer then "BUY CHICKEN" else "ROLL FREE")
  elseif guidance.target=="Yard" then "COLLECT EGGS" elseif guidance.target=="EggDeposit" then "SELL EGGS" else "CLUCK CAMP"
 self.objective.Enabled=anchor~=nil and not self.app.panel.Visible and not self.app.dialogueActive
  and not (self.app.research and self.app.research.root.Visible) and not (self.app.offlineCash and self.app.offlineCash.gui)
  and (state.armyState=="Home" or state.armyState=="Following") and not state.incoming
  and not (self.commandHeading.Enabled and self.nearestCommand and self.nearestCommand.model==target)
 self:UpdateGuideTrail(anchor,self.objective.Enabled and guidance~=nil)
 if self.app.commander then self.app.commander:Update() end
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
		self.commandPrompt.ActionText=if not nearest.action then nearest.text else "Move Troops Here"
		self.commandPrompt.ObjectText=nearest.title..(if nearest.action=="Attack" and nearest.text:find("Via ") then " · earlier camps first" else "")
		self.unclaimPrompt.MaxActivationDistance=self.commandPrompt.MaxActivationDistance
		self.unclaimPrompt.ObjectText=nearest.title
	end
	self.commandPrompt.Enabled=nearest~=nil
	self.unclaimPrompt.Enabled=nearest~=nil and nearest.canUnclaim==true
	self:UpdateCommandPresentation()
end

function BaseController:Destroy()
	self.alive = false
	self:StopGuideMotion()
	if self.guideStart then self.guideStart:Destroy() end
	if self.guideEnd then self.guideEnd:Destroy() end
	if self.autoCollectStand then self.autoCollectStand:Destroy() end
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
 if self.eggObjective then self.eggObjective:Destroy() end
end

return BaseController
