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
local Guide=require(game:GetService("ReplicatedStorage").PetRoll.Shared.TutorialGuide)
local Feel=require(game:GetService("ReplicatedStorage").PetRoll.Shared.CollectionFeel)
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
	-- A returning squad can turn around; the server says when it must recover first.
	local canMove=state.armyState=="Home" or state.armyState=="Following" or state.armyState=="Deployed"
		or state.armyState=="Traveling" or state.armyState=="Fighting" or state.armyState=="Returning"
	local target = part
	while target and target ~= workspace and not target:GetAttribute("CommandTarget") do target = target.Parent end
	if not target or target == workspace then return nil end
	local id = target:GetAttribute("CommandTarget")
	if string.sub(id,1,5)=="base:" then return nil end
	if string.sub(id,1,8)=="mission:" then return self:MissionCommand(target,string.sub(id,9)) end
	-- Camps on another commander's lane are "camp:P:N" in the target list.
	if string.match(id, "^camp:%d+$") then
		local holder = target
		while holder and holder ~= workspace and holder:GetAttribute("LaneOwnerIndex") == nil do holder = holder.Parent end
		local lane = holder and holder ~= workspace and holder:GetAttribute("LaneOwnerIndex")
		if lane and lane ~= state.plotIndex then id = "camp:" .. lane .. ":" .. string.sub(id, 6) end
	end
	for _, entry in state.targets or {} do
		if entry.id ~= id then continue end
		local income = if id == "income:1" then state.incomeOutpost else nil
		if id == "income:1" and not income then return nil end
		if not canMove and not entry.canUnclaim then
			-- Status only: feeds the locked heading, never a prompt or an order.
			return {model = target, targetId = id, title = entry.name, locked = not entry.current,
				reason = entry.reason or "Your Army is busy", color = C.line}
		end
		local ownedCount, _, _, selectedCount, deployedCount = self.app:Counts()
		local armyCount = if state.armyState == "Home" or state.armyState == "Following" then selectedCount else deployedCount
		local available = if income then income.available else entry.available
		-- October 21 (Stevin: no locks at any camp): an empty Army sends the best
		-- chickens (the server fills it), so only owning none at all stops an order.
		local allowed = canMove and available and (armyCount > 0 or ownedCount > 0)
		local reason = if not available then (if income then income.reason else entry.reason) elseif not allowed then "You have no chickens to send yet"
			else ""
		-- Shared bands (TutorialGuide.Difficulty): <1.3x Very tough, 1.3-2x Close fight, 2x+ Should win.
		local strength = Guide.Difficulty(state.power, entry.power)
		local bounty = Theme.Money(entry.killRewardMin or 0) .. (if entry.killRewardMax~=entry.killRewardMin then "–"..Theme.Money(entry.killRewardMax or 0) else "") .. " Coins/kill"
		-- Held territories pay egg value while the flag stands (Mini War style).
		local pays = if (entry.holdBonus or 0) > 0 then " · +" .. math.floor(entry.holdBonus * 100 + 0.5) .. "% eggs" else ""
		local hint = if entry.via then "Fights " .. entry.via .. " first"
			else strength .. " · " .. (entry.count or 0) .. " defenders · " .. bounty .. pays
		local text = if allowed then "Send Army · " .. hint else reason
		if allowed and entry.via then text = "Via " .. entry.via .. "\nEarlier camps are fought in order" end
        if allowed and entry.ownerId and not entry.via then text=if entry.owned then "Station Army" else "Capture territory" end
		if income then
			text = if allowed then income.action or "Conquer" else reason or "Territory busy"
			local deadline = if (income.retryEndsAt or 0) > workspace:GetServerTimeNow() then income.retryEndsAt else income.graceEndsAt
			if not allowed and deadline and deadline > workspace:GetServerTimeNow() then
				text ..= " · " .. math.ceil(deadline - workspace:GetServerTimeNow()) .. "s"
			end
		end
		return {model = target, action = if allowed then "Attack" else nil, targetId = id,
			canUnclaim=entry.canUnclaim==true,
			hint = if allowed and income then (if (income.count or 0) > 0 then strength .. " · " .. income.count .. " defenders" else "Undefended")
				elseif allowed then hint else nil,
			-- Unavailable targets explain why on a heading; the current target and
			-- held ground stay quiet (no inactive prompt over a fight).
			locked = not allowed and not entry.current and not entry.owned, reason = reason,
			title = entry.name, text = text, promptAction = income and text,
			owned=entry.owned and not entry.via, color = if not allowed then C.line elseif entry.owned and not entry.via then C.green else C.red}
	end
	return nil
end

-- October 14 Missions: a waiting site of this commander (state.operations.missions).
function BaseController:MissionCommand(model,missionId)
	local state=self.app.state
	local mission
	for _,entry in (state.operations or {}).missions or {} do if entry.id==missionId then mission=entry end end
	if not mission then return nil end
	local ownedCount, _, _, selectedCount = self.app:Counts()
	-- October 15: an army already out can be sent straight here (the server
	-- forfeits a Mission it leaves and keeps a camp's progress draining there).
	local canMove=state.armyState=="Home" or state.armyState=="Following" or state.armyState=="Deployed"
		or state.armyState=="Traveling" or state.armyState=="Fighting" or state.armyState=="Returning"
	-- October 15: a won site stays held by its army; any other Army may take it.
	local allowed=canMove and (selectedCount>0 or ownedCount>0) and not mission.locked and not mission.yours and not mission.busy
	local reason=if mission.yours then "Your Army holds this territory"
		elseif mission.busy then "A battle is already going on here"
		elseif mission.locked then "Unlock this Mission tier in Upgrades"
		elseif not canMove then "Your Army is busy" elseif not allowed then "You have no chickens to send yet" else ""
	local enemies=if mission.holder then mission.count.." chickens of "..mission.holder else mission.count.." loyalists"
	local payout=if mission.rewarded then "already rewarded" else Theme.CompactCoins(mission.reward)
	local hint=Guide.Difficulty(state.power,mission.power).." · "..enemies.." · "..payout
	return {model=model,action=if allowed then "StartOperation" else nil,missionId=missionId,targetId="mission:"..missionId,
		hint=if allowed then hint else nil,locked=not allowed,reason=reason,title=mission.name,
		text=if allowed then "Send Army · "..hint else reason,color=if allowed then C.red else C.line}
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
-- October 23: `skip` is the Commander's dismissed tip cards, so the beacon follows the
-- tip the card shows (the Cluck Camp tip's beam; menu tips have no world target).
function BaseController.OpeningGuidance(state, skip: {[string]: boolean}?): {target: any, text: any, id: any}?
 local guide=require(game.ReplicatedStorage.PetRoll.Shared.TutorialGuide).Resolve(state,nil,skip)
 if not guide or guide.id=="Complete" then return nil end
 if guide.target=="Rebirth" or guide.target=="Gems" then return nil end
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

-- October 21 game feel: My Base (any teleport) lands with a poof, a ring, a whoosh
-- and a short white flash. A jump of ArrivalJump studs in one frame by the same
-- character is a teleport; a new character (respawn) only resets the tracker.
-- Cutscenes (scriptable camera) move the player quietly.
function BaseController:StepArrival()
	local character=Players.LocalPlayer.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		self.lastRoot=nil
		return
	end
	local position=root.Position
	local last=self.lastRootPosition
	if root==self.lastRoot and last and (position-last).Magnitude>=Feel.Feel.ArrivalJump then self:Arrived(position) end
	self.lastRoot,self.lastRootPosition=root,position
end

function BaseController:Arrived(position: Vector3)
	local camera=workspace.CurrentCamera
	if camera and camera.CameraType==Enum.CameraType.Scriptable then return end
	local app=self.app
	local ground=position-Vector3.new(0,2.6,0)
	if app.worldFeel then
		app.worldFeel:Poof(ground+Vector3.new(0,0.6,0),{count=12,size=1.6})
		app.worldFeel:Ring(ground,{color=C.gold,radius=5,seconds=0.5})
	end
	local audio=app.audio
	if audio:Has("Whoosh") then audio:Play("Whoosh",nil,{voiceKey="Arrival",cooldown=0.5})
	else audio:Play("Pop",0.8,{voiceKey="Arrival",cooldown=0.5,volume=0.5}) end
	if app.screenFeel then app.screenFeel:Flash(Color3.new(1,1,1),0.12,0.3) end
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
	-- October 25: during the tutorial the server holds the lever while an affordable
	-- chicken waits (RollStation TutorialHold), so E always takes that chicken.
	if primary:GetAttribute("TutorialHold")==true then
		self.rollPromptPlot,self.rollPromptChoice=plot,"BuyPrompt"
		return if station==primary then "BuyPrompt" else nil
	end
	-- October 27: until the tutorial's first pull, E is the lever's from the spawn
	-- (RollStation FirstPull); the podium is nearer there but still empty.
	if primary:GetAttribute("FirstPull")==true then
		self.rollPromptPlot,self.rollPromptChoice=plot,"RollPrompt"
		return if station==primary then "RollPrompt" else nil
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
	if prompt.Name ~= "RollPrompt" and prompt.Name ~= "BuyPrompt" and prompt.Name ~= "RecruitTierPrompt" then return end
	local station = prompt.Parent
	while station and station~=world and station.Name~="RollStation" and not station:GetAttribute("IsRollStation") do station=station.Parent end
	if not station or station == world then return end
	local ownerSource = station
	local entry = {distance = prompt.MaxActivationDistance, connections = {}, closed = false}
	self.promptFilters[prompt] = entry
	local function apply()
		if entry.closed or not prompt.Parent then return end
		local owner = ownerSource:GetAttribute("OwnerUserId") or ownerSource:GetAttribute("OwnerId")
		local allowedOwner = owner == Players.LocalPlayer.UserId
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
	self:UpdateOwnSign()
end

-- Your own plot's sign stays visible from anywhere on the map. The real sign is a
-- 100-stud billboard that can also stream out when you travel, so this keeps a local
-- copy on its own anchor (your name and headshot) and hides the real one for you only.
-- Other players' signs are unchanged.
function BaseController:UpdateOwnSign()
	local state = self.app.state
	local index = state and state.plotIndex
	local world = workspace:FindFirstChild("PetRollWorld")
	local plot = index and world and world:FindFirstChild("Plot" .. index)
	local sign = plot and plot:FindFirstChild("Your Plot", true)
	local real = sign and sign:IsA("BasePart") and sign:FindFirstChildWhichIsA("BillboardGui") or nil
	if self.ownSignIndex ~= index then
		if self.ownSign then self.ownSign:Destroy();self.ownSign = nil end
		if self.hiddenSign and self.hiddenSign.Parent then self.hiddenSign.Enabled = true end
		self.hiddenSign, self.ownSignIndex = nil, index
	end
	if not index then return end
	if real and sign then
		if not self.ownSign then
			local anchor = Instance.new("Part")
			anchor.Name, anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = "OwnPlotSign", true, false, false, false
			anchor.Transparency, anchor.Size, anchor.CastShadow = 1, Vector3.one, false
			local copy = real:Clone()
			copy.Adornee, copy.MaxDistance, copy.Enabled = anchor, math.huge, true
			-- A pixel floor keeps it readable from across the island; up close it matches the original.
			copy.Size = UDim2.new(real.Size.X.Scale * 0.6, 110, real.Size.Y.Scale * 0.6, 22)
			copy.Parent = anchor
			anchor.Parent = workspace
			self.ownSign = anchor
		end
		self.ownSign.CFrame = sign.CFrame
		local text = real:FindFirstChildWhichIsA("TextLabel", true)
		local mine = self.ownSign:FindFirstChildWhichIsA("TextLabel", true)
		if text and mine and mine.Text ~= text.Text then mine.Text = text.Text end
		local portrait = mine and mine:FindFirstChildWhichIsA("ImageLabel")
		if portrait then
			local userId = Players.LocalPlayer.UserId
			portrait.Image = if userId > 0 then "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150" else ""
			portrait.ScaleType, portrait.Visible = Enum.ScaleType.Fit, portrait.Image ~= ""
		end
		if real.Enabled then real.Enabled = false end
		self.hiddenSign = real
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
	-- The real sign can stream back in as a fresh copy; keep it hidden behind ours.
	task.spawn(function()
		while self.alive do
			self:UpdateOwnSign()
			task.wait(0.5)
		end
	end)
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
	prompt.Name,prompt.KeyboardKeyCode,prompt.ActionText="ArmyCommandPrompt",Enum.KeyCode.E,"Send Army"
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
	-- The instance name stays (docs/tests); the player-facing words follow the glossary.
	unclaim.Name,unclaim.ActionText="UnclaimBasePrompt","Release Camp"
	-- X, not R: R opens Upgrades globally. A 1 s hold guards against accidental unclaims.
	unclaim.KeyboardKeyCode,unclaim.GamepadKeyCode=Enum.KeyCode.X,Enum.KeyCode.ButtonY
	unclaim.Exclusivity,unclaim.Style=Enum.ProximityPromptExclusivity.OnePerButton,Enum.ProximityPromptStyle.Default
	unclaim.RequiresLineOfSight,unclaim.HoldDuration,unclaim.Enabled=false,1,false
	unclaim.UIOffset=Vector2.new(0,68)
	unclaim.Parent=self.commandAnchor
	self.unclaimPrompt=unclaim
	self:CreateCommandHeading()
	table.insert(self.connections,prompt.Triggered:Connect(function()
		local command=self.nearestCommand
		command=command and self:CommandFor(command.model)
		if command and command.action and not self.app.panel.Visible and not self.app.dialogueActive and not UserInputService:GetFocusedTextBox() then
			self.app.audio:Play("Click")
			if command.missionId then self.app:Request("StartOperation",{missionId=command.missionId})
			else self.app:Request(command.action,{targetId=command.targetId}) end
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
		self:StepArrival()
		self.poll+=dt
		if self.poll<0.1 then return end
		self.poll=0;self:RefreshPromptOwnership();self:PollCommand();self:UpdateObjective();self.app:StepRecruitFeedback()
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
	Theme.Motion:Center(label) -- grow-ins start from the middle; same place at rest
	self.commandHeading,self.commandLabel=gui,label
	-- Unavailable targets have no native prompt; this heading carries the reason.
	local locked=Instance.new("BillboardGui")
	locked.Name,locked.Size,locked.StudsOffsetWorldSpace="CampLockedHeading",UDim2.fromOffset(320,34),Vector3.new(0,5,0)
	locked.AlwaysOnTop,locked.LightInfluence,locked.MaxDistance=true,0,150
	locked.Enabled,locked.Parent=false,Players.LocalPlayer.PlayerGui
	local reason=Theme.Display(locked,"Reason","",26,C.white)
	reason.Size,reason.TextScaled,reason.TextXAlignment=UDim2.fromScale(1,1),true,Enum.TextXAlignment.Center
	Theme.Motion:Center(reason)
	self.lockedHeading,self.lockedLabel=locked,reason
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
	local heading=visible and hostile==true
	if heading and not self.commandHeading.Enabled then Theme.Motion:PopScale(self.commandLabel,0.7) end
	self.commandHeading.Enabled=heading
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
		beam.Color,beam.Transparency=ColorSequence.new(Color3.new(1,1,1)),NumberSequence.new(0)
		-- Original white/black-contour arrow, drawn upward along the texture's vertical axis.
		beam.Texture,beam.TextureMode="rbxassetid://78163165437840",Enum.TextureMode.Static
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
	-- Reverse the texture orientation; negative scrolling still travels toward the destination.
	self.guideBeam.Attachment0,self.guideBeam.Attachment1=destination,self.guideStart
	self.guideBeam.TextureSpeed=if reduced then 0 else -1
	self.guideBeam.Enabled=true
end

-- A destination arrow remains visible while the Beam indicates the route.
function BaseController:UpdateObjective()
 local state=self.app.state
 local world=workspace:FindFirstChild("PetRollWorld")
 if not state or not world or (self.app.intro and self.app.intro.playing) then
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
  Theme.Motion:Center(label)
  local arrow=GuideArrow(gui,"Arrow")
  arrow.Size,arrow.Position,arrow.AnchorPoint=UDim2.fromScale(.72,.72),UDim2.fromScale(.5,.64),Vector2.new(.5,.5)
  arrow.Rotation=90
  self.objective,self.objectiveCaption=gui,label
 end
 local target
 local commander=self.app.commander
 local guidance=BaseController.OpeningGuidance(state,commander and commander.tipSkip)
 local plot=world:FindFirstChild("Plot"..state.plotIndex)
 local lane=world:FindFirstChild("Lane"..state.plotIndex)
 if guidance then
  local campIndex=tonumber(string.match(tostring(guidance.target),"^Camp(%d)$"))
  if campIndex then target=lane and lane:FindFirstChild("Camp"..campIndex)
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
   else
    local pets=plot and plot:FindFirstChild("Pets")
    local model=pets and pets:FindFirstChildWhichIsA("Model")
    target=model and model.PrimaryPart
   end
  elseif guidance.target then target=plot and plot:FindFirstChild(guidance.target) end
 end
 -- Later October 21 (Stevin): no instructions after the tutorial. The marker only
 -- follows the tutorial's own lessons and a Mission the player picked with GUIDE in
 -- the Missions panel (the automatic NEXT camp goal and first-Mission hints are gone).
 local ops=state.operations
 local missionFolder=world:FindFirstChild("Missions")
 local waiting=nil
 local tracker=self.app.missionTracker
 local guided=tracker and tracker.guideId
 local nextMission=nil
 for _,mission in (ops and ops.missions) or {} do
  if not mission.locked and not mission.yours and not mission.busy and mission.id==guided then nextMission=mission;break end
 end
 if guided~=nil and nextMission and missionFolder then
  local site=missionFolder:FindFirstChild("Mission_"..nextMission.id)
  waiting=site and site.PrimaryPart and site.PrimaryPart:FindFirstChild("Marker")
  if waiting then target=waiting end
 end
 -- October 26 (Stevin): once Cluck Camp is won, a NEXT marker stays over the next camp
 -- on the route until it is won (its tip card shows for a few seconds; this does not).
 local nextCamp=nil
 if not guidance and not waiting then
  nextCamp=Guide.NextCamp(state)
  target=if nextCamp then lane and lane:FindFirstChild("Camp"..nextCamp) else nil
  if not target then nextCamp=nil end
 end
 local campIndex=guidance and tonumber(string.match(tostring(guidance.target),"^Camp(%d)$")) or nextCamp
 local campName=campIndex and Progression.Camps(1)[campIndex] and Progression.Camps(1)[campIndex].name
 -- October 24: card 7 ("Pull the lever again!") points at the lever even with a chicken
 -- waiting on the podium; buying it is the player's call.
 local lever=guidance~=nil and guidance.id=="RollAgain"
 local anchor=if target and (target:IsA("BasePart") or target:IsA("Attachment")) then target
  elseif target and target.Name=="RollStation" then target:FindFirstChild(if state.offer and not lever then "Podium" else "LeverBase") or target:FindFirstChild("RevealPad")
  else CampCommand.Anchor(target)
 self.objective.Adornee=anchor
 local waitLeft=waiting and tracker and tracker:Remaining(nextMission.id)
 self.objectiveCaption.Text=if waiting then (if waitLeft then ("ATTACK %d:%02d"):format(waitLeft//60,waitLeft%60) else "ATTACK")
  elseif nextCamp and campName then "NEXT: "..string.upper(campName)
  elseif not guidance then "NEXT" elseif guidance.target=="RollStation" then (if state.offer and not lever then "BUY CHICKEN" else "ROLL")
  elseif guidance.target=="Yard" then "COLLECT EGGS" elseif guidance.target=="EggDeposit" then "SELL EGGS"
  elseif campName then string.upper(campName) else "CLUCK CAMP"
 -- Pop on a new goal only; the ticking countdown digits are ignored.
 local captionKey=self.objectiveCaption.Text:gsub("[%d:]","")
 if self.objectiveKey and captionKey~=self.objectiveKey then Theme.Motion:PopScale(self.objectiveCaption,1.15) end
 self.objectiveKey=captionKey
 self.objective.Enabled=anchor~=nil and not self.app.panel.Visible and not self.app.dialogueActive
  and not (self.app.research and self.app.research.root.Visible) and not (self.app.offlineCash and self.app.offlineCash.gui)
  and (state.armyState=="Home" or state.armyState=="Following") and not state.incoming
  and not (self.commandHeading.Enabled and self.nearestCommand and self.nearestCommand.model==target)
  and not (self.lockedHeading.Enabled and self.lockedHeading.Adornee==anchor)
 self:UpdateGuideTrail(anchor,self.objective.Enabled and (guidance~=nil or waiting~=nil))
 if self.app.commander then self.app.commander:Update() end
end

function BaseController:PollCommand()
	local state=self.app.state
	local character=Players.LocalPlayer.Character
	local body=character and character:FindFirstChild("HumanoidRootPart")
	local world=workspace:FindFirstChild("PetRollWorld")
	local nearest,bestPart,bestDistance=nil,nil,math.huge
	local locked,lockedPart,lockedDistance=nil,nil,math.huge
	if state and body and world and not self.app.panel.Visible and not self.app.dialogueActive and not UserInputService:GetFocusedTextBox() then
		local candidates={}
		local arena=world:FindFirstChild("KingArena")
		if arena then table.insert(candidates,arena) end
		local income=state.incomeOutpost and world:FindFirstChild("IncomeOutpost")
		if income then table.insert(candidates,income) end
		-- This commander's waiting mission sites (others' sites are visible but not theirs).
		local missions=world:FindFirstChild("Missions")
		if missions then for _,site in missions:GetChildren() do
			if site:GetAttribute("OwnerUserId")==Players.LocalPlayer.UserId or site:GetAttribute("Shared") then table.insert(candidates,site) end
		end end
		local frontier=world:FindFirstChild("Outposts")
  if frontier then for _,camp in frontier:GetChildren() do table.insert(candidates,camp) end end
		-- Every lane's camps: any commander's camp can be attacked.
		for _,lane in world:GetChildren() do
			if string.match(lane.Name,"^Lane%d+$") then for _,camp in lane:GetChildren() do table.insert(candidates,camp) end end
		end
		for i=1,#Config.PlotPositions do local plot=world:FindFirstChild("Plot"..i);if plot then table.insert(candidates,plot) end end
		for _,model in candidates do
			local part=CampCommand.Anchor(model)
			if not part then continue end
			local distance=(body.Position-(part.Position+Vector3.new(0,2.5,0))).Magnitude
			if (distance>bestDistance and distance>lockedDistance) or not CampCommand.InRange(model,body.Position) then continue end
			local camera=workspace.CurrentCamera
			local visible=false
			if camera then local _,onScreen=camera:WorldToViewportPoint(part.Position+Vector3.new(0,2.5,0));visible=onScreen end
			if not visible then continue end
			local command=self:CommandFor(model)
			-- Status sentences are not actions. In particular, never cover an
			-- ongoing fight with an "already attacking/stationed" prompt.
			if command and (command.action or command.canUnclaim) then
				if distance<=bestDistance then nearest,bestPart,bestDistance=command,part,distance end
			elseif command and command.locked and (command.reason or "")~="" and distance<lockedDistance then
				locked,lockedPart,lockedDistance=command,part,distance
			end
		end
	end
	self.nearestCommand=nearest
	-- An unavailable target gets no prompt; its heading says why. A usable
	-- command nearby always wins.
	local lockedShown=nearest==nil and locked~=nil
	if lockedShown then
		self.lockedHeading.Adornee=lockedPart
		self.lockedLabel.Text="🔒 "..locked.reason
	end
	if lockedShown and not self.lockedHeading.Enabled then Theme.Motion:PopScale(self.lockedLabel,0.7) end
	self.lockedHeading.Enabled=lockedShown
	if nearest then
		self.commandAnchor.Parent=bestPart
		-- Center the compact controls; inactive commands remain hidden in combat.
		self.commandAnchor.Position=Vector3.new(0,2.5,0)
		self.commandPrompt.MaxActivationDistance=CampCommand.Radius(nearest.model)
		self.commandPrompt.ActionText="Send Army"
		-- Odds and bounty, e.g. "Close fight · 4 defenders · 100–520 Coins/kill".
		self.commandPrompt.ObjectText=nearest.hint or ""
		self.commandPrompt.UIOffset=Vector2.new(0,if nearest.canUnclaim then 28 else 0)
		self.unclaimPrompt.MaxActivationDistance=self.commandPrompt.MaxActivationDistance
		self.unclaimPrompt.ObjectText=""
		self.unclaimPrompt.UIOffset=Vector2.new(0,if nearest.action then -28 else 0)
	end
	self.commandPrompt.Enabled=nearest~=nil and nearest.action~=nil
	self.unclaimPrompt.Enabled=nearest~=nil and nearest.canUnclaim==true
	self:UpdateCommandPresentation()
end

function BaseController:Destroy()
	self.alive = false
	if self.ownSign then self.ownSign:Destroy();self.ownSign = nil end
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
	if self.lockedHeading then self.lockedHeading:Destroy() end
 if self.objective then self.objective:Destroy() end
 if self.eggObjective then self.eggObjective:Destroy() end
end

return BaseController
