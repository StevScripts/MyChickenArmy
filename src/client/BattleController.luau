--!strict
-- Server Humanoids own movement and life cycles. This client adds health, sound, and bounded local effects.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog = require(Shared.PetCatalog)
local Theme = require(script.Parent.UITheme)
local CombatEffects = require(script.Parent.CombatEffects)
local C = Theme.Colors
local HIT_COLOR = Color3.fromRGB(255, 65, 65)
local HIT_FADE = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- October 21 game feel timings (docs/team/GAME_FEEL_20261021.md); tune in ConquestPresentation.
local Feel = Theme.Conquest
-- UIMotion helpers are untyped; an any-typed alias keeps strict inference out of presentation calls.
local Motion: any = Theme.Motion
local BattleController = {}
BattleController.__index = BattleController

function BattleController.new(app)
	return setmetatable({app = app, views = {}, modelViews = {}, captureViews = {}, snapshots = {}, connections = {}, phases = {}, rewardSerials = {}, coinEffects = 0, effects = 0, alive = true,
		marches = {}, lastHitShake = 0, lastKnockoutShake = 0}, BattleController)
end

local function isMission(battle)
	return type(battle.target) == "string" and string.sub(battle.target, 1, 10) == "operation:"
end

-- The player's own chicken on their own side, or an enemy of their army, in their own battle.
local function ownUnit(battle, unit, userId)
	return unit.petId ~= nil and ((unit.side == "A" and battle.attacker == userId) or (unit.side == "B" and battle.defender == userId))
end

local function enemyUnit(battle, unit, userId)
	return (battle.attacker == userId and unit.side == "B") or (battle.defender == userId and unit.side == "A")
end


-- The world meter displays server-owned control values.
local function capturePresentation(battle)
	-- October 15: progress left at a camp drains while its guards regroup.
	if battle.abandoned then
		local down=battle.defendersDown or 0
		return {completed=false,paused=false,value=math.clamp(battle.captureProgress or 0,0,1),stage="Conquest",
			title="Progress fading",color=Theme.Conquest.Progress,
			detail=(battle.name or "Camp")..(if down>0 then " · "..down.." defenders regrouping" else ""),active=true}
	end
	local completed=battle.captureProgress==1 and (battle.phase=="Holding" or (battle.phase=="Returning" and battle.outcome=="A"))
	local reclaiming=battle.enemyReclaiming==true
	if battle.conquest then
		return {completed=completed,paused=battle.capturePaused==true,
			value=math.clamp(battle.captureProgress or 0,0,1),stage="Conquest",
			title=if reclaiming then "Conquest lost" else "⚔ Conquering ⚔",
			color=Theme.Conquest.Progress,detail=battle.name or "Base",
			active=not completed and (reclaiming or battle.phase=="Capture" or (battle.captureStarted and battle.phase=="Fight"))}
	end
	local enemy=reclaiming or battle.captureStage=="Enemy"
	local paused=battle.capturePaused==true
	local value=math.clamp((if enemy then battle.enemyControl else battle.playerControl) or 0,0,1)
	local territory=battle.target=="income:1"
	local title=if reclaiming then (if battle.enemyReclaimComplete then "Enemy control restored" else "Enemy control · "..math.floor(value*100+0.001).."%")
		elseif completed then "Conquered!" elseif paused then "Conquest paused"
		elseif enemy then (if territory then "Owner control · " else "Enemy control · ")..math.floor(value*100+0.001).."%"
		else (if territory then "Capturing · " else "Your control · ")..math.floor(value*100+0.001).."%"
	return {completed=completed,paused=paused,value=value,stage=if enemy then "Enemy" else "Player",title=title,
		color=if enemy and not completed then Theme.Arcade.red else Theme.Arcade.green,
		detail=if reclaiming then battle.reclaimReason or "Army defeated · returning home" elseif paused then (if territory then "Fighting pauses capture" elseif battle.waitingForArmy then "Waiting for your chickens to return" else "Defeat defenders to resume")
			else battle.name or "Base",
		active=reclaiming or battle.phase=="Capture" or (battle.captureStarted and battle.phase=="Fight")}
end

function BattleController:ReleaseCapture(id)
	local view=self.captureViews[id]
	if not view then return end
	self.captureViews[id]=nil
	if view.dimTween then view.dimTween:Cancel();view.dimTween:Destroy() end
	Motion:Cancel(view.fill,"progress")
	local gui,anchor,zone=view.gui,view.anchor,view.zone
	local function drop() gui:Destroy();anchor:Destroy();if zone then zone:Destroy() end end
	if self.app.reducedMotion or not self.alive or not gui.Enabled then drop();return end
	-- Shrink out, then free the meter; a same-id meter can be rebuilt meanwhile.
	Motion:Appear(view.body,false,nil)
	task.delay(Feel.LeaveSeconds+0.05,drop)
end

-- "CaptureTick" (fallback "Pop") rising a step per section: on the HUD for the
-- player's own conquest, at the camp for a spectator.
function BattleController:CaptureTick(battle,view,section)
	local audio=self.app.audio
	local cue=if audio:Has("CaptureTick") then "CaptureTick" else "Pop"
	local pitch=Feel.TickPitchBase+Feel.TickPitchStep*section
	local userId=Players.LocalPlayer.UserId
	if battle.attacker==userId or battle.defender==userId then
		audio:Play(cue,pitch,{noFallback=true,voiceKey="CaptureTick",cooldown=0.1})
	elseif self.app.worldFeel then
		self.app.worldFeel:Sound(cue,view.anchor.Position,pitch,{noFallback=true,voiceKey="CaptureTickFar",cooldown=0.1,volume=0.5})
	end
end

function BattleController:UpdateCapture(battle)
	local presentation=capturePresentation(battle)
	local completed=presentation.completed
	if (not presentation.active and not completed) or (battle.conquest and completed) then self:ReleaseCapture(battle.id);return end
	local view: any=self.captureViews[battle.id]
	if not view then
		local anchor=Instance.new("Part")
		anchor.Name,anchor.Size="Capture_"..battle.id,Vector3.one
		anchor.Anchored,anchor.CanCollide,anchor.CanTouch,anchor.CanQuery,anchor.Transparency=true,false,false,false,1
		anchor.Position,anchor.Parent=Vector3.new(battle.x,(battle.y or 1.2)+Theme.Conquest.Elevation,battle.z),self.folder
		local zone
		if not battle.conquest then
		zone=Instance.new("Part")
		zone.Name,zone.Shape="CaptureZone_"..battle.id,Enum.PartType.Cylinder
		local radius=battle.captureRadius or 12
		zone.Size=Vector3.new(0.06,radius*2,radius*2)
		zone.CFrame=CFrame.new(battle.x,1.14,battle.z)*CFrame.Angles(0,0,math.pi/2)
		zone.Anchored,zone.CanCollide,zone.CanTouch,zone.CanQuery,zone.CastShadow=true,false,false,false,false
		zone.Color,zone.Material,zone.Transparency,zone.Parent=C.gold,Enum.Material.Neon,0.87,self.folder
		end
		local gui=Instance.new("BillboardGui")
		gui.Name,gui.Size,gui.Adornee="ConquestMeter",UDim2.fromScale(Theme.Conquest.Width,Theme.Conquest.Height),anchor
		gui.AlwaysOnTop,gui.MaxDistance,gui.LightInfluence,gui.Parent=true,Theme.Conquest.MaxDistance,0,Players.LocalPlayer.PlayerGui
		-- One group holds the whole meter so it grows in, shrinks out and dims as one.
		local body=Instance.new("CanvasGroup")
		body.Name,body.Size,body.BackgroundTransparency,body.BorderSizePixel="Body",UDim2.fromScale(1,1),1,0
		body.AnchorPoint,body.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5) -- grows from the middle
		body.Visible,body.Parent=false,gui
		local title=Theme.Display(body,"Title","Conquering",27,Theme.Arcade.red)
		title.Position,title.Size,title.TextXAlignment=UDim2.fromScale(0.08,0),UDim2.fromScale(0.84,0.35),Enum.TextXAlignment.Center
		Motion:Center(title) -- stage pops grow from the middle; same place at rest
		local detail=Theme.Display(body,"Detail","",20)
		detail.Position,detail.Size,detail.TextXAlignment=UDim2.fromScale(0.1,0.36),UDim2.fromScale(0.8,0.23),Enum.TextXAlignment.Center
		local track,fill=Theme.SegmentedBar(body,"Progress",UDim2.fromScale(1,0.27),Theme.Conquest.Segments)
		track.Position=UDim2.fromScale(0,0.66)
		fill.Parent.BackgroundColor3=Theme.Conquest.Track
		Theme.Gradient(fill.Parent,Color3.fromRGB(235,245,248),Color3.fromRGB(160,180,186))
		view={anchor=anchor,zone=zone,gui=gui,body=body,title=title,detail=detail,fill=fill,progress=-1,section=-1,dimmed=false,dimTween=nil,stage=nil,completedAt=nil}
		self.captureViews[battle.id]=view
		Motion:Appear(body,true,Feel.AppearFrom)
	end
	if completed and not view.completedAt then view.completedAt=os.clock() end
	local progress=presentation.value
	local stageChanged=view.stage~=presentation.stage
	-- Pop the title on a real stage change, not when the meter first appears.
	if stageChanged and view.stage~=nil then Motion:PopScale(view.title,1.15) end
	view.stage=presentation.stage
	view.title.Text,view.title.TextColor3=presentation.title,presentation.color
	view.detail.Text=presentation.detail
	if view.zone then
		view.zone.Transparency=if completed then 1 else 0.87
		view.zone.Color=presentation.color
	end
	view.fill.BackgroundColor3=presentation.color
	-- Paused (no attacker counting) dims the whole meter; resuming restores it.
	local dimmed=presentation.paused and not completed
	if dimmed~=view.dimmed then
		view.dimmed=dimmed
		if view.dimTween then view.dimTween:Cancel();view.dimTween:Destroy();view.dimTween=nil end
		local goal=if dimmed then Feel.PausedTransparency else 0
		if self.app.reducedMotion then view.body.GroupTransparency=goal
		else view.dimTween=TweenService:Create(view.body,TweenInfo.new(Feel.DimSeconds,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{GroupTransparency=goal});view.dimTween:Play() end
	end
	-- Interpolate only toward a received server value; never predict a victory.
	if progress~=view.progress or stageChanged or presentation.paused then
		view.progress=progress
		if completed or stageChanged or presentation.paused then Motion:Cancel(view.fill,"progress");view.fill.Size=UDim2.fromScale(progress,1)
		else Motion:Progress(view.fill,progress,Feel.FillSeconds,false) end
	end
	-- A section just filled on the player's side: white wash and a rising tick.
	local section=if presentation.stage=="Enemy" then 0 else math.floor(progress*Feel.Segments+1e-4)
	if stageChanged then view.section=section
	elseif section>view.section then
		if view.section>=0 and not completed then
			Motion:Flash(view.fill,Color3.new(1,1,1),Feel.TickFlashSeconds,Feel.TickFlashPeak)
			self:CaptureTick(battle,view,section)
		end
		view.section=section
	elseif section<view.section then view.section=section end
end

function BattleController:Within(position, range)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - position).Magnitude < range
end

function BattleController:IsNearby(position)
	return self:Within(position, 120)
end

-- October 21 game feel: the camera answers the player's own fight. A hit on one of
-- their chickens close by gives a small shake (cooldown so a brawl never rumbles);
-- their chicken knocking an enemy out shakes once more; losing one shakes harder
-- under a short red flash. Spectated fights never move the camera.
function BattleController:HitFeel(battle, unit, view, now)
	local feel = self.app.screenFeel
	if not feel or not ownUnit(battle, unit, Players.LocalPlayer.UserId) then return end
	if now - self.lastHitShake < Feel.HitShakeGap or not self:Within(view.position, Feel.HitShakeRange) then return end
	self.lastHitShake = now
	feel:Impact(1)
end

function BattleController:KnockoutFeel(battle, unit, view, now)
	local feel = self.app.screenFeel
	if not feel or not self:Within(view.position, Feel.KnockoutShakeRange) then return end
	local userId = Players.LocalPlayer.UserId
	if ownUnit(battle, unit, userId) then
		if now - self.lastKnockoutShake < Feel.KnockoutShakeGap then return end
		self.lastKnockoutShake = now
		feel:Impact(2)
		feel:Flash(HIT_COLOR, 0.15, 0.3)
	elseif enemyUnit(battle, unit, userId) and now - self.lastHitShake >= Feel.HitShakeGap then
		self.lastHitShake = now
		feel:Impact(1)
	end
end

function BattleController:Ring(position, color, large)
	if self.app.reducedMotion or self.effects >= 24 or not self:IsNearby(position) then return end
	self.effects += 1
	local ring = Instance.new("Part")
	ring.Name, ring.Shape, ring.Size = "ImpactRing", Enum.PartType.Cylinder, Vector3.new(0.08, 1, 1)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Anchored, ring.CanCollide, ring.CanTouch, ring.CanQuery = true, false, false, false
	ring.Material, ring.Color, ring.Transparency = Enum.Material.Neon, color, 0.55
	ring.Parent = self.folder
	local size = if large then 11 else 4
	TweenService:Create(ring, TweenInfo.new(0.35), {Size = Vector3.new(0.08, size, size), Transparency = 1}):Play()
	Debris:AddItem(ring, 0.45)
	task.delay(0.45, function() self.effects = math.max(0, self.effects - 1) end)
end

-- These are references to replicated actors, never client-created combat copies.
function BattleController:FindActor(battleId, unitId)
	local world = workspace:FindFirstChild("PetRollWorld")
	local battles = world and world:FindFirstChild("Battles")
	local battle = battles and battles:FindFirstChild(battleId)
	local model = battle and battle:FindFirstChild(unitId)
	if model and model:IsA("Model") and model.PrimaryPart and model:GetAttribute("BattleId") == battleId and model:GetAttribute("UnitId") == unitId then return model end
	return nil
end

function BattleController:IsCurrentView(view)
	return not view.released and self.modelViews[view.model] == view and self:FindActor(view.battleId, view.unitId) == view.model
end

function BattleController:ReleaseView(view)
	if view.released then return end
	view.released = true
	if view.descendantConnection then view.descendantConnection:Disconnect() end
	self:ClearFlash(view)
	-- Only this view's model owner may restore shared presentation. An older
	-- encounter must never undo a view already adopted by the next encounter.
	if self.modelViews[view.model] ~= view then return end
	self.modelViews[view.model] = nil
	for part, value in view.transparencies do
		if part.Parent then part.LocalTransparencyModifier = value end
	end
	for gui, enabled in view.tags do if gui.Parent then gui.Enabled = enabled end end
end

-- The floor under the rig, for dust kicks and knockout shockwaves.
function BattleController:Feet(view)
	local offset=view.model:GetAttribute("FootOffset")
	return view.position-Vector3.new(0,(if type(offset)=="number" then offset else 1)-0.1,0)
end

-- Where hit effects burst: a little above the rig's pivot, scaled to its height.
function BattleController:Chest(view)
	local model=view.model
	local height=model:GetAttribute("VisualHeight")
	return model:GetPivot().Position+Vector3.new(0,(if type(height)=="number" then height else 2.5)*0.15,0)
end

function BattleController:Defeat(view)
	if not self.app.reducedMotion then self:Ring(view.position, C.paper, false) end
	view.defeatedAt=os.clock();view.spawnedAt=nil
	if self.app.reducedMotion then
		for part in view.transparencies do if part.Parent then part.LocalTransparencyModifier=1 end end
	end
	for gui in view.tags do if gui.Parent then gui.Enabled = false end end
end

function BattleController:Respawn(view, unit, now)
	view.defeatedAt=nil;self:ClearFlash(view)
	view.spawnedAt=if self.app.reducedMotion then nil else now
	view.spawnFadeSeconds=if unit.side=="B" and not unit.petId then 0.55 else 0.28
	-- Start hidden on the receipt itself; never flash opaque before the next frame.
	for part,original in view.transparencies do
		if part.Parent then part.LocalTransparencyModifier=if self.app.reducedMotion then original else 1 end
	end
	if not self.app.reducedMotion then self:Ring(view.position,if unit.side=="A" then C.blue else Theme.Arcade.red,false) end
end

function BattleController:StepFade(view, alive, now)
	local fade=nil
	if not alive and view.defeatedAt then
		fade=if self.app.reducedMotion then 1 else math.clamp((now-view.defeatedAt-0.12)/0.36,0,1)
	elseif alive and view.spawnedAt then
		local progress=math.clamp((now-view.spawnedAt)/(view.spawnFadeSeconds or 0.28),0,1)
		fade=if self.app.reducedMotion then 0 else 1-TweenService:GetValue(progress,Enum.EasingStyle.Sine,Enum.EasingDirection.Out)
		if fade<=0 then view.spawnedAt=nil end
	end
	if fade then
		for part,original in view.transparencies do
			if part.Parent then part.LocalTransparencyModifier=original+(1-original)*fade end
		end
	end
end

function BattleController:ClearFlash(view)
	if view.hitConnection then view.hitConnection:Disconnect();view.hitConnection=nil end
	if view.hitTween then view.hitTween:Cancel();view.hitTween:Destroy();view.hitTween=nil end
	if view.highlight then view.highlight:Destroy();view.highlight=nil end
end

function BattleController:Flash(view)
	-- Replace the previous pulse so rapid hits never stack highlights or callbacks.
	self:ClearFlash(view)
	if self.app.reducedMotion or not self:IsCurrentView(view) or not self:IsNearby(view.position) then return end
	local highlight = Instance.new("Highlight")
	highlight.Name, highlight.Adornee = "DuckHit", view.model
	highlight.FillColor, highlight.OutlineColor = HIT_COLOR, HIT_COLOR
	highlight.FillTransparency, highlight.OutlineTransparency = 0.35, 0.1
	highlight.DepthMode, highlight.Parent = Enum.HighlightDepthMode.Occluded, self.folder
	view.highlight = highlight
	local tween=TweenService:Create(highlight,HIT_FADE,{FillTransparency=1,OutlineTransparency=1})
	view.hitTween=tween
	view.hitConnection=tween.Completed:Connect(function()
		if view.hitTween==tween then self:ClearFlash(view) end
	end)
	tween:Play()
end

-- The Army sets off: one whistle and one dust wave where it stands (once per march leg).
function BattleController:MarchStart(battle)
	local audio = self.app.audio
	if audio:Has("MarchStart") then audio:Play("MarchStart", 1, {noFallback = true, voiceKey = "MarchStart", cooldown = 1})
	else audio:Play("CallArmyWhistle", 1, {noFallback = true, voiceKey = "CallArmyWhistle", cooldown = 0.75, volume = 0.2}) end
	local feel = self.app.worldFeel
	if not feel then return end
	local sum, count = Vector3.zero, 0
	for _, unit in battle.units do
		if unit.side ~= "A" or unit.hp <= 0 then continue end
		local model = self:FindActor(battle.id, unit.id)
		sum += if model and model.PrimaryPart then model.PrimaryPart.Position else Vector3.new(unit.x, 1.2, unit.z)
		count += 1
	end
	if count > 0 then feel:Poof(sum / count - Vector3.new(0, 1, 0), {count = 12, size = 1.6}) end
end

-- Camp victory: the ActionFeedback burst and Victory cue, plus a green celebrate,
-- confetti on the HUD and a Fanfare a beat later. Missions are MissionTracker's.
function BattleController:Victory(battle)
	self.app.feedback:Conquer(Vector3.new(battle.x, battle.y or 1.2, battle.z), battle.captureRadius)
	if isMission(battle) then return end
	local feel = self.app.screenFeel
	if feel then feel:Celebrate(Theme.Arcade.green, 2) end
	if self.app.gui then Motion:Confetti(self.app.gui, {origin = UDim2.fromScale(0.5, 0.12)}) end
	if not self.app.audio:Has("Fanfare") then return end
	task.delay(Feel.FanfareDelay, function()
		if self.alive then self.app.audio:Play("Fanfare", 1, {noFallback = true, voiceKey = "Fanfare", cooldown = 1}) end
	end)
end

-- An authored flag that becomes owned: a burst and ring at the cloth with "FlagRaise".
function BattleController:FlagRaised(group)
	local feel = self.app.worldFeel
	if not feel then return end
	local flags = group:FindFirstChild("Flags")
	local part = if flags and flags:IsA("BasePart") then flags elseif flags then flags:FindFirstChildWhichIsA("BasePart", true) else nil
	local position = (if part then part.Position elseif group:IsA("Model") then group:GetPivot().Position else nil)
	if not position then return end
	position += Vector3.new(0, 4, 0)
	if not feel:Near(position, 120) then return end
	feel:Celebrate(position, Feel.Owned, 2)
	local audio = self.app.audio
	local cue = if audio:Has("FlagRaise") then "FlagRaise" elseif audio:Has("Whoosh") then "Whoosh" else "Pop"
	feel:Sound(cue, position, 1, {voiceKey = "FlagRaise", cooldown = 0.5})
end

function BattleController:WatchFlags(world)
	-- Saved ownership restored right after joining is not a new capture: a short grace.
	local watchedAt = os.clock()
	local function watch(item)
		if not item:IsA("Model") or (item:GetAttribute("CampName") == nil and item.Name ~= "KingArena") then return end
		table.insert(self.connections, item:GetAttributeChangedSignal("Conquered"):Connect(function()
			if self.alive and os.clock() - watchedAt > 3 and item:GetAttribute("Conquered") == true then self:FlagRaised(item) end
		end))
	end
	for _, item in world:GetDescendants() do watch(item) end
	table.insert(self.connections, world.DescendantAdded:Connect(watch))
end

function BattleController:PhaseFeedback(battle)
	local old = self.phases[battle.id]
	self.phases[battle.id] = battle.phase
	local userId = Players.LocalPlayer.UserId
	local marching = battle.attacker == userId and battle.phase == "Travel" and battle.travelStage == "Marching"
	if marching and not self.marches[battle.id] then self.marches[battle.id] = true; self:MarchStart(battle)
	elseif not marching then self.marches[battle.id] = nil end
	if old == battle.phase or not old then return end
	if battle.attacker ~= userId and battle.defender ~= userId then return end
	if old == "Travel" and (battle.phase == "Fight" or battle.phase == "Capture") then
		self:Ring(Vector3.new(battle.x, 1.2, battle.z), if battle.attacker == userId then C.gold else Theme.Arcade.red, true)
	end
	if battle.phase == "Holding" then
		local won = if battle.defender == userId then battle.outcome == "B" else battle.outcome == nil or battle.outcome == "A"
		if won and not battle.friendlyTerritory then self:Victory(battle) end
	elseif battle.phase == "Returning" and battle.outcome then
		local won = (battle.attacker == userId and battle.outcome == "A") or (battle.defender == userId and battle.outcome == "B")
		if won and old ~= "Holding" and not battle.friendlyTerritory then self:Victory(battle)
		elseif won then return
		-- Mission losses and early leaves answer through MissionTracker; camps stay quiet.
		elseif battle.outcome ~= "Recall" and not isMission(battle) then self.app.audio:Play("Pop", 0.65) end
	elseif battle.phase == "Fight" and self:IsNearby(Vector3.new(battle.x, 1.2, battle.z)) then self.app.audio:Play("Pop", 0.9) end
end

-- Presentation consumes server-issued kill receipts; it never awards currency.
function BattleController:KillFeedback(battle)
 local last=self.rewardSerials[battle.id] or 0
 local newest=last
 for _,drop in battle.coinDrops or {} do
  newest=math.max(newest,drop.serial)
  if drop.serial<=last or drop.userId~=Players.LocalPlayer.UserId then continue end
  local position=Vector3.new(drop.x,4,drop.z)
  if not self:IsNearby(position) or self.coinEffects>=12 then continue end
  self.coinEffects+=1
  local anchor=Instance.new("Part")
  anchor.Name,anchor.Size,anchor.Position="KillCoins",Vector3.one,position
  anchor.Anchored,anchor.CanCollide,anchor.CanTouch,anchor.CanQuery,anchor.Transparency=true,false,false,false,1
  anchor.Parent=self.folder
  local gui=Instance.new("BillboardGui")
  gui.Name,gui.Size,gui.Adornee,gui.AlwaysOnTop="KillReward",UDim2.fromOffset(180,36),anchor,true
  gui.Parent=anchor
  -- October 20: a gold coin beside the amount instead of "$".
  local row,text,coin=Theme.CoinAmount(gui,"CoinAmount","+"..Theme.Money(drop.amount),25,C.gold)
  Motion:Center(row)
  Motion:PopScale(row,0.6)
  if not self.app.reducedMotion then
   TweenService:Create(anchor,TweenInfo.new(0.85,Enum.EasingStyle.Quad),{Position=position+Vector3.new(0,3,0)}):Play()
   -- The root label is a transparent Display holder; its visible text is on these children.
   local fade=TweenInfo.new(0.3,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,0.55)
   for _,name in {"TextFace","TextShadow"} do
    local child=text:FindFirstChild(name)
    if not child then continue end
    TweenService:Create(child,fade,{TextTransparency=1}):Play()
    local outline=child:FindFirstChild("TextOutline")
    if outline then TweenService:Create(outline,fade,{Transparency=1}):Play() end
   end
   TweenService:Create(coin,fade,{ImageTransparency=1}):Play()
  end
  Debris:AddItem(anchor,0.9)
  task.delay(0.9,function() self.coinEffects=math.max(0,self.coinEffects-1) end)
  -- No coin sound: the knockout poof already marks the kill.
 end
 self.rewardSerials[battle.id]=newest
end

function BattleController:Receive(snapshots)
	if type(snapshots) ~= "table" then return end
	-- A recovering empty territory has a meter, but no troop combat effects.
	local reclaims,battles={},{}
	for _,snapshot in snapshots do
		if snapshot.territoryReclaim then
			-- Left progress is shown only to the commander who left it.
			if not snapshot.abandoned or snapshot.attacker==Players.LocalPlayer.UserId then table.insert(reclaims,snapshot) end
		else table.insert(battles,snapshot) end
	end
	snapshots=battles
	self.snapshots = snapshots
	local now = os.clock()
	local seen, battlesSeen = {}, {}
	for _, battle in snapshots do
		for _, unit in battle.units do seen[battle.id .. ":" .. unit.id] = true end
	end
	-- Restore old bindings before any new encounter caches the same actor.
	for key, view in self.views do
		if not seen[key] or not self:IsCurrentView(view) then self:ReleaseView(view);self.views[key] = nil end
	end
	for _, battle in snapshots do
		battlesSeen[battle.id] = true
		self:PhaseFeedback(battle)
  self:KillFeedback(battle)
		self:UpdateCapture(battle)
		for _, unit in battle.units do
			local key = battle.id .. ":" .. unit.id
			seen[key] = true
			local view = self.views[key]
			if view and not self:IsCurrentView(view) then self:ReleaseView(view);self.views[key] = nil;view = nil end
			if not view then
				local model = self:FindActor(battle.id, unit.id)
				-- The snapshot may arrive before the replicated rig. Retry on the next snapshot.
				if not model then continue end
				local previous = self.modelViews[model]
				if previous then self:ReleaseView(previous) end
				view = {model = model, battleId = battle.id, unitId = unit.id, position = model.PrimaryPart.Position, attack = unit.attackSerial, impact=unit.impactSerial or 0, hp = unit.hp,
					damage=unit.damageSerial or 0, spawnSerial=unit.spawnSerial or 0, transparencies = {}, tags = {}}
				self.modelViews[model] = view
				local actorView = view
				local function cachePart(item)
					if not self:IsCurrentView(actorView) then return end
					if item:IsA("BasePart") then
						actorView.transparencies[item] = item.LocalTransparencyModifier
						if actorView.hp <= 0 or actorView.spawnedAt then item.LocalTransparencyModifier = 1 end
					elseif item:IsA("BillboardGui") then
						actorView.tags[item] = item.Enabled
						item.Enabled = actorView.hp > 0 and actorView.phase == "Fight"
					end
				end
				for _, item in model:GetDescendants() do cachePart(item) end
				actorView.descendantConnection = model.DescendantAdded:Connect(cachePart)
				self.views[key] = view
			end
			view.position = if view.model.PrimaryPart then view.model.PrimaryPart.Position else Vector3.new(unit.x, 1.2, unit.z)
			if unit.attackSerial ~= view.attack then
				view.model:SetAttribute("LocalAttackAt", os.clock())
				if self:IsNearby(view.position) then self.combat:Swing(view.position,self:Feet(view)) end
			end
			if (unit.impactSerial or 0)~=view.impact then
				if Catalog[unit.species].splash then
					local dragon = unit.species == "Dragon" or Catalog[unit.species].baseSpecies == "Dragon"
					self:Ring(Vector3.new(unit.impactX or unit.x,1.2,unit.impactZ or unit.z), if dragon then Color3.fromRGB(255, 151, 62) else C.blue, true)
				end
			end
			-- A victim receipt represents committed damage, not an attack windup or
			-- a health-stat change. Seed it on binding; don't replay a prior life.
			if (unit.damageSerial or 0)>view.damage and (unit.spawnSerial or 0)==view.spawnSerial then
				self:Flash(view)
				if self:IsNearby(view.position) then
					local damage=math.max(0,(view.hp or unit.hp)-unit.hp)
					self.combat:Hit(self:Chest(view),damage,damage>=(unit.maxHp or 40)*0.25,Vector3.new(unit.faceX or 0,0,unit.faceZ or 1))
					self:HitFeel(battle,unit,view,now)
				end
			end
			if unit.hp <= 0 and (view.hp > 0 or not view.unit) then
				-- Only a knockout seen happening gets a poof, not one already down on binding.
				if view.unit and self:IsNearby(view.position) then self.combat:Knockout(self:Chest(view),self:Feet(view));self:KnockoutFeel(battle,unit,view,now) end
				self:Defeat(view)
			elseif unit.hp > 0 and (view.hp <= 0 or (unit.spawnSerial or 0)>(view.spawnSerial or 0)) then
				self:Respawn(view,unit,os.clock())
			end
			view.spawnSerial=unit.spawnSerial or 0
			view.damage=unit.damageSerial or 0
			view.attack, view.hp, view.unit, view.phase = unit.attackSerial, unit.hp, unit, battle.phase
			view.impact=unit.impactSerial or 0
			self.app:ObserveRecruitUnit(battle, unit, view.model)
			-- Health contents are already replicated by the server actor owner.
			for gui in view.tags do if gui.Parent then gui.Enabled = unit.hp > 0 and battle.phase == "Fight" end end
		end
	end
	for key, view in self.views do if not seen[key] then self:ReleaseView(view);self.views[key] = nil end end
	for id in self.phases do if not battlesSeen[id] then self.phases[id] = nil;self.rewardSerials[id]=nil;self.marches[id]=nil end end
	for _,reclaim in reclaims do battlesSeen[reclaim.id]=true;self:UpdateCapture(reclaim) end
	for id in self.captureViews do if not battlesSeen[id] then self:ReleaseCapture(id) end end
	self:UpdateStatus()
end

function BattleController:Current()
	local userId = Players.LocalPlayer.UserId
	for _, battle in self.snapshots do if battle.attacker == userId then return battle end end
	for _, battle in self.snapshots do if battle.defender == userId then return battle end end
	return nil
end

function BattleController:UpdateStatus()
 local camera=workspace.CurrentCamera
 for _,view in self.captureViews do
  local visible=false
  if camera and not self.app.panel.Visible then
   local point,onScreen=camera:WorldToViewportPoint(view.anchor.Position)
   visible=onScreen and point.Z>0 and (camera.CFrame.Position-view.anchor.Position).Magnitude<Theme.Conquest.MaxDistance
  end
  view.gui.Enabled=visible
 end
end

function BattleController:Start(remote)
	local old = workspace:FindFirstChild("PetRollBattleVisuals")
	if old then old:Destroy() end
	self.folder = Instance.new("Folder")
	self.folder.Name, self.folder.Parent = "PetRollBattleVisuals", workspace
	self.combat = CombatEffects.new(self.app, self.folder)
	-- Owned flags celebrate when their camp's Conquered attribute turns on (server-owned).
	task.spawn(function()
		local world = workspace:WaitForChild("PetRollWorld", 120)
		if world and self.alive then self:WatchFlags(world) end
	end)
	table.insert(self.connections, remote.OnClientEvent:Connect(function(snapshots) self:Receive(snapshots) end))
	table.insert(self.connections, RunService.RenderStepped:Connect(function()
		local now = os.clock()
		self:UpdateStatus()
		-- A settled snapshot can precede its rig, or state.outgoing can arrive
		-- after BattleChanged. Recheck confirmed data without fabricating movement.
		if now >= (self.nextRecruitCheck or 0) then
			self.nextRecruitCheck = now + 0.1
			for _, battle in self.snapshots do
				for _, unit in battle.units do
					if unit.petId and self.app.recruitIntents[unit.petId] then
						self.app:ObserveRecruitUnit(battle, unit, self:FindActor(battle.id, unit.id))
					end
				end
			end
		end
		for key, view in self.views do
			if not self:IsCurrentView(view) then self:ReleaseView(view);self.views[key] = nil;continue end
			local alive = view.unit and view.unit.hp > 0
			if self.app.reducedMotion and view.highlight then self:ClearFlash(view) end
			self:StepFade(view,alive,now)
		end
	end))
end

function BattleController:Destroy()
	self.alive = false
	for _, connection in self.connections do connection:Disconnect() end
	for _, view in self.views do self:ReleaseView(view) end
	for id in self.captureViews do self:ReleaseCapture(id) end
	if self.folder then self.folder:Destroy() end
	if self.card then self.card:Destroy() end
	self.views, self.modelViews, self.snapshots, self.phases, self.marches = {}, {}, {}, {}, {}
end

return BattleController
