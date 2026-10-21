--!strict
-- Local podium presentation; RollCamera moves the view. RollStation owns the offer.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.PetCatalog)
local Rules = require(Shared.Rules)
local PetView = require(Shared.PetView)
local UIColors = require(Shared.UIColors)
local Theme = require(script.Parent.UITheme)
local Mutations = require(Shared.MutationCatalog)
local MutationVFX = require(script.Parent.SpecialChickenVFX)
local RollCamera = require(script.Parent.RollCamera)
local GoldRolls = require(Shared.GoldRolls)
local RollPresentationController = {}
RollPresentationController.__index = RollPresentationController

-- A quick shuffle that slows steadily, then a short suspense hold. Sound and
-- preview changes use these exact beats, rather than independent repeating timers.
-- Oct 20: more beats for the ~4 s Drop a Fruit-length roll (every 0.12–0.38 s).
local BEATS = {0.04, 0.07, 0.105, 0.145, 0.19, 0.245, 0.3, 0.365, 0.435, 0.51, 0.59, 0.675, 0.765, 0.86}
local GOLD = UIColors.Rewards
local BLUE = Color3.fromRGB(67, 181, 222)
local RARITY = {Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5, Mythic=6, Secret=7}
-- Camera feel (push-in, reveal pop, flash, speed lines, shake) is tuned at the top of
-- RollCamera. The camera always stays with the player; there is no orbit.
-- Mutation tag: pops in this long after the species lands; Rainbow and rarer also flash.
local MUTATION_BADGE_DELAY = 0.3
-- October 20 Gold rolls: the special pull's tag stays this long after the reveal.
local SPECIAL_TAG_HOLD = 1.2

-- A special pull's glow; the Prism glow cycles through the rainbow.
local function specialColor(kind: string?, now: number): Color3
	if kind == "Prism" then return Color3.fromHSV((now * 0.45) % 1, 0.55, 1) end
	return (kind and GoldRolls.Colors[kind]) or GOLD
end

function RollPresentationController.new(app)
 return setmetatable({app=app, records={}, connections={}, scanAt=0, rollCamera=RollCamera.new(app)}, RollPresentationController)
end

-- The roll camera follows the local player's own lever podium (slot 1) within
-- 24 studs, with motion on, the normal camera, and no menu, Upgrades screen,
-- dialogue or crate opening up. Reveals follow the rarest chicken appearing on
-- any of their podiums this frame (StepRecord notes it).
function RollPresentationController:StepCamera(now)
 local app=self.app
 local camera=workspace.CurrentCamera
 local player=Players.LocalPlayer
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 local ok=camera~=nil and camera.CameraType==Enum.CameraType.Custom and not app.reducedMotion
  and root~=nil and humanoid~=nil and humanoid.Health>0 and not app.panel.Visible and not app.dialogueActive
  and not (app.research and app.research.root.Visible) and not (app.commerce and app.commerce.cratePresenting)
 local near,roll=false,nil
 if ok then
  for station,record in self.records do
   if record.active and (station:GetAttribute("RollSlot") or 1)==1 and station:GetAttribute("OwnerId")==player.UserId then
    near=(root.Position-record.foot).Magnitude<=24
    local startedAt=station:GetAttribute("RollStartedAt")
    local duration=station:GetAttribute("RollDuration") or Config.RollRevealSeconds
    local rollId=station:GetAttribute("RollId")
    if near and rollId and startedAt and now>=startedAt and now-startedAt<duration then
     roll={key=rollId,startedAt=startedAt,duration=duration}
    end
    break
   end
  end
 end
 -- Auto Roll repeats every few seconds, so it gets the lighter version.
 local auto=app.state and app.state.autoRoll
 local reveal=self.reveal
 self.reveal=nil
 self.rollCamera:Step(camera,now,{ok=ok,near=near,roll=roll,reveal=reveal,
  auto=auto~=nil and auto.enabled==true and auto.unlocked~=false})
end

function RollPresentationController:Track(station)
 if self.records[station] then return end
 local frame, foot = station:GetAttribute("DisplayFrame"), station:GetAttribute("DisplayFoot")
 local arm, knob = station:FindFirstChild("LeverArm"), station:FindFirstChild("LeverHandle")
 local top, anchor = station:FindFirstChild("RevealPad"), station:FindFirstChild("EffectAnchor")
 if not frame or not foot or not top or not anchor then return end
 if (station:GetAttribute("RollSlot") or 1)==1 and (not arm or not knob) then return end
 local glow = Instance.new("Highlight")
 glow.Name, glow.FillColor, glow.FillTransparency = "MysterySilhouette", Color3.fromRGB(15,20,18), 0
 glow.OutlineColor, glow.OutlineTransparency = Color3.fromRGB(255,250,225), 0.15
 glow.DepthMode, glow.Enabled, glow.Parent = Enum.HighlightDepthMode.Occluded, false, self.folder
 self.records[station] = {station=station, frame=frame, foot=foot, arm=arm, knob=knob, top=top,
  leverPivot=station:GetAttribute("LeverPivot") or frame*CFrame.new(6.1,1.85,-5), anchor=anchor,
  armRest=station:GetAttribute("LeverArmRest") or CFrame.new(0,1.4,0),
  knobRest=station:GetAttribute("LeverHandleRest") or CFrame.new(0,2.8,0),
  light=anchor:FindFirstChild("RevealGlow"), burst=anchor:FindFirstChild("RevealSparkles",true),
  cache={}, appearances={}, hidden={}, glow=glow, active=false, lastStage=0, landedAt=-100,
  voiceKey="Roll"..tostring(station:GetAttribute("PlotIndex"))}
end

-- October 15: build the roll's result (and its shuffle birds) the moment the roll
-- starts, unparented, and preload their meshes/textures so the reveal pops in loaded.
function RollPresentationController:Warm(record, species)
 if type(species)~="string" or not Catalog[species] or record.cache[species] then return end
 local model=self:Preview(record,species,true,true)
 if model then task.spawn(function() pcall(ContentProvider.PreloadAsync,ContentProvider,{model}) end) end
end

function RollPresentationController:Preview(record, species, mystery: boolean?, warmOnly: boolean?)
 local model = record.cache[species]
 if not model then
  model = PetView.Create(self.folder, "RollPreview_"..species, species, 1, record.foot)
  if warmOnly then model.Parent=nil end
  local appearance={parts={}, surfaces={}}
  for _, item in model:GetDescendants() do
   if item:IsA("BillboardGui") then item.Enabled=false end
   if item:IsA("BasePart") then
    item.CanQuery=false;item.CanTouch=false;item.CanCollide=false
    -- Invisible rig/effect helpers must never become part of the silhouette.
    if item.Transparency<1 then
     appearance.parts[item]={transparency=item.Transparency,localTransparency=item.LocalTransparencyModifier}
    end
   elseif item:IsA("SurfaceAppearance") then
    appearance.surfaces[item]=item.AlphaMode
   end
  end
  record.cache[species] = model
  record.appearances[species] = appearance
 end
 if warmOnly then return model end
 -- Suppress species effects during the mystery shuffle, then restore them for
 -- the revealed offer, including when it reuses the last cached shuffle bird.
 model:SetAttribute("ReducedMotion",mystery == true)
 -- The shuffle never teases a mutation; the reveal sets the real one.
 if mystery then model:SetAttribute("Mutation",nil) end
	-- The expensive silhouette material is reserved for revealed offers. Roaming
	-- Galaxies all use the shared animated world texture.
	model:SetAttribute("GalaxyMaskPreview",not mystery and species=="StormDuck")
 -- Highlights do not fully cover translucent art. Change only these local
 -- previews; restore on every reveal, even when it reuses the last shuffle bird.
 local appearance=record.appearances[species]
 for part, original in appearance.parts do
  part.Transparency=if mystery then 0 else original.transparency
  part.LocalTransparencyModifier=if mystery then 0 else original.localTransparency
 end
 for surface, alphaMode in appearance.surfaces do
  surface.AlphaMode=if mystery then Enum.AlphaMode.Overlay else alphaMode
 end
 if record.preview ~= model then
  if record.preview then record.preview.Parent=nil end
  -- Position before parenting prevents a frame at the cached model's old location.
  PetView.Move(model,record.foot,record.frame.LookVector,0)
  model.Parent=self.folder
  record.preview=model
  record.glow.Adornee=model
 end
 return model
end

-- The revealed offer's mutation: the station attribute (every viewer) or, on the
-- local player's own podium, the matching offer in their snapshot.
function RollPresentationController:MutationFor(station, offerId)
 local saved=station:GetAttribute("RevealedMutation")
 if Mutations.IsValid(saved) then return saved end
 if station:GetAttribute("OwnerId")~=Players.LocalPlayer.UserId then return nil end
 for _,offer in (self.app.state and self.app.state.offers) or {} do
  if offer.id==offerId then return if Mutations.IsValid(offer.mutation) then offer.mutation else nil end
 end
 return nil
end

function RollPresentationController:HideBadge(record)
 local badge=record.badge
 if not badge then return end
 for _,tween in badge.tweens do tween:Cancel() end
 table.clear(badge.tweens)
 badge.gui.Enabled=false
 badge.mutation=nil
end

-- A world tag above the revealed chicken. TweenService pops it in; Rainbow and
-- rarer add a short colored flash and sparkle burst. Reduced motion shows it still.
function RollPresentationController:ShowBadge(record, mutation, animate)
 local def=Mutations.Get(mutation)
 if not def then self:HideBadge(record);return end
 local badge=record.badge
 if badge and badge.mutation==mutation then return end
 if not badge then
  local gui=Instance.new("BillboardGui")
  gui.Name,gui.Size,gui.LightInfluence="MutationBadge",UDim2.fromScale(4.4,1.2),0
  gui.AlwaysOnTop,gui.MaxDistance,gui.Enabled=true,80,false
  gui.Adornee,gui.Parent=record.top,self.folder
  local holder=Instance.new("Frame")
  holder.Name,holder.BackgroundTransparency,holder.Size="Pop",1,UDim2.fromScale(1,1)
  holder.AnchorPoint,holder.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
  holder.Parent=gui
  local scale=Instance.new("UIScale");scale.Parent=holder
  local flash=Instance.new("Frame")
  flash.Name,flash.BorderSizePixel,flash.BackgroundTransparency="Flash",0,1
  flash.AnchorPoint,flash.Position,flash.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(1,1)
  flash.ZIndex,flash.Parent=1,holder
  local corner=Instance.new("UICorner");corner.CornerRadius,corner.Parent=UDim.new(0.5,0),flash
  badge={gui=gui,holder=holder,scale=scale,flash=flash,tag=nil,tweens={},mutation=nil}
  record.badge=badge
 end
 self:HideBadge(record)
 if badge.tag then badge.tag:Destroy() end
 badge.tag=MutationVFX.Badge(badge.holder,mutation)
 if badge.tag then badge.tag.Size=UDim2.fromScale(1,1) end
 badge.mutation=mutation
 -- Sit just above the revealed chicken's head.
 local height=(record.preview and record.preview:GetAttribute("VisualHeight")) or 3
 badge.gui.StudsOffsetWorldSpace=Vector3.new(0,record.foot.Y-record.top.Position.Y+height+1,0)
 badge.gui.Enabled=true
 badge.flash.BackgroundColor3,badge.flash.BackgroundTransparency,badge.flash.Size=def.color,1,UDim2.fromScale(1,1)
 if not animate or self.app.reducedMotion then badge.scale.Scale=1;return end
 badge.scale.Scale=0
 local pop=TweenService:Create(badge.scale,TweenInfo.new(0.32,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1})
 table.insert(badge.tweens,pop);pop:Play()
 if Mutations.Rank(mutation)>=Mutations.Rank("Rainbow") then
  badge.flash.BackgroundTransparency=0.1
  local flash=TweenService:Create(badge.flash,TweenInfo.new(0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
   {BackgroundTransparency=1,Size=UDim2.fromScale(1.9,2.6)})
  table.insert(badge.tweens,flash);flash:Play()
  if record.burst then
   record.burst.Color=ColorSequence.new(def.color,Color3.new(1,1,1))
   record.burst:Emit(18)
  end
  self:Sound(record,"RollRare",1.25,0.4,nil)
 else
  self:Sound(record,"Pop",1.3,0.3,0.3)
 end
end

-- October 20 Gold rolls: "Gold roll · 2x Luck" over each podium of a special pull,
-- from the lever until just after the reveal. TweenService pops it in.
function RollPresentationController:ShowSpecialTag(record, kind: string)
 local tag=record.specialTag
 if not tag then
  local gui=Instance.new("BillboardGui")
  gui.Name,gui.Size,gui.LightInfluence="GoldRollTag",UDim2.fromScale(5.6,1.3),0
  gui.AlwaysOnTop,gui.MaxDistance,gui.Enabled=true,80,false
  gui.StudsOffsetWorldSpace=Vector3.new(0,7.6,0)
  gui.Adornee,gui.Parent=record.top,self.folder
  local holder=Instance.new("Frame")
  holder.Name,holder.BackgroundTransparency,holder.Size="Pop",1,UDim2.fromScale(1,1)
  holder.AnchorPoint,holder.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
  holder.Parent=gui
  local scale=Instance.new("UIScale");scale.Parent=holder
  local icon=Instance.new("ImageLabel")
  icon.Name,icon.BackgroundTransparency,icon.ScaleType="MachineIcon",1,Enum.ScaleType.Fit
  icon.Size,icon.Parent=UDim2.fromScale(0.24,1),holder
  local label=Instance.new("TextLabel")
  label.Name,label.BackgroundTransparency,label.Font="Text",1,Enum.Font.SourceSansBold
  label.Position,label.Size,label.TextScaled=UDim2.fromScale(0.25,0.08),UDim2.fromScale(0.75,0.84),true
  label.TextXAlignment,label.Parent=Enum.TextXAlignment.Left,holder
  local stroke=Instance.new("UIStroke")
  stroke.Color,stroke.Thickness,stroke.Transparency,stroke.Parent=UIColors.Border,2,0.05,label
  tag={gui=gui,scale=scale,icon=icon,label=label,tween=nil::Tween?}
  record.specialTag=tag
 end
 tag.icon.Image=GoldRolls.Icons[kind] or ""
 tag.label.Text=kind.." roll · "..GoldRolls.Luck(kind).."x Luck"
 tag.label.TextColor3=GoldRolls.Colors[kind] or GOLD
 tag.gui.Enabled=true
 if tag.tween then tag.tween:Cancel() end
 if self.app.reducedMotion then tag.scale.Scale=1;return end
 tag.scale.Scale=0
 tag.tween=TweenService:Create(tag.scale,TweenInfo.new(0.32,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1})
 tag.tween:Play()
end

function RollPresentationController:HideSpecialTag(record)
 local tag=record.specialTag
 if not tag or not tag.gui.Enabled then return end
 if tag.tween then tag.tween:Cancel();tag.tween=nil end
 tag.gui.Enabled=false
end

-- A special pull on your own lever podium while you are too far away to see it
-- (Auto Roll from anywhere): one notice per pull.
function RollPresentationController:NoteSpecial(record, now)
 local station=record.station
 if (station:GetAttribute("RollSlot") or 1)~=1 or station:GetAttribute("OwnerId")~=Players.LocalPlayer.UserId then return end
 local rollId=station:GetAttribute("RollId")
 if rollId==record.specialNoted then return end
 record.specialNoted=rollId
 local special=station:GetAttribute("RollSpecial")
 local startedAt=station:GetAttribute("RollStartedAt")
 if type(special)~="string" or not rollId or type(startedAt)~="number" or now-startedAt>1 then return end
 local character=Players.LocalPlayer.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if root and (root.Position-record.foot).Magnitude<=36 then return end
 self.app:Notify(special.." roll! Every podium has "..GoldRolls.Luck(special).."x Luck.","info")
end

-- RollStation (server) labels only slot 1's empty podium. The local player's
-- other owned, unlocked empty podiums get the same hint locally so they never
-- read as blank boxes. Same look as the server's OfferLabel text line.
function RollPresentationController:SetIdleHint(record, visible: boolean)
 local hint=record.idleHint
 if not visible then
  if hint then hint.Enabled=false end
  if hint and record.idleBob then record.idleBob=nil;Theme.Motion:StopLoop(hint,"bob") end
  return
 end
 if not hint then
  hint=Instance.new("BillboardGui")
  hint.Name,hint.Size,hint.StudsOffsetWorldSpace="EmptyPodiumHint",UDim2.fromOffset(340,34),Vector3.new(0,4.5,0)
  hint.AlwaysOnTop,hint.MaxDistance,hint.LightInfluence=true,38,0
  hint.Adornee,hint.Parent=record.top,self.folder
  local label=Instance.new("TextLabel")
  label.Name,label.BackgroundTransparency,label.Size="Text",1,UDim2.fromScale(1,1)
  label.Font,label.TextSize,label.TextColor3=Enum.Font.SourceSansBold,28,UIColors.Text
  label.Text,label.Parent="Pull the lever to roll",hint
  local stroke=Instance.new("UIStroke")
  stroke.Color,stroke.Thickness,stroke.Transparency=UIColors.Border,2,0.05
  stroke.Parent=label
  record.idleHint=hint
 end
 hint.Enabled=true
 -- Gentle bob, started once per showing; reduced motion keeps it still.
 if record.idleBob then return end
 record.idleBob=true
 Theme.Motion:Loop(hint,"bob",{StudsOffsetWorldSpace=Vector3.new(0,4.8,0)},{StudsOffsetWorldSpace=Vector3.new(0,4.5,0)},0.9)
end

function RollPresentationController:Sound(record, name, pitch, volume, duration)
 -- One shared shuffle soundtrack; secondary rare reveals share the capped voice key.
 if (record.station:GetAttribute("RollSlot") or 1)>1 and name~="RollRare" then return end
 local character=Players.LocalPlayer.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 if not root or (root.Position-record.foot).Magnitude>36 then return end
 self.app.audio:Play(name,pitch,{parent=record.anchor,volume=volume,maxDuration=duration,
  voiceKey=record.voiceKey..name})
end

function RollPresentationController:Reset(record)
 if record.preview then record.preview.Parent=nil;record.preview=nil end
 self:HideBadge(record)
 self:HideSpecialTag(record)
 for part, value in record.hidden do if part.Parent then part.LocalTransparencyModifier=value end end
 table.clear(record.hidden)
 record.serverPet=nil
 record.glow.Enabled=false
 if record.arm and record.knob then
  record.arm.CFrame=record.leverPivot*record.armRest
  record.knob.CFrame=record.leverPivot*record.knobRest
 end
 if record.light then record.light.Brightness=0 end
 local species=record.station:GetAttribute("RevealedSpecies")
 record.top.Color=if species and Catalog[species] then Color3.fromRGB(table.unpack(Catalog[species].color)) else BLUE
 record.active=false
 record.rollId=nil
 record.lastStage=0
 record.result=nil
 record.landedAt=-100
end

function RollPresentationController:StepRecord(record, now)
 local station=record.station
 local camera=workspace.CurrentCamera
 local near=camera and (camera.CFrame.Position-record.foot).Magnitude<100
 if not near or not station:GetAttribute("OwnerId") then
  if record.active then self:Reset(record) end
  self:SetIdleHint(record,false)
  return
 end
 record.active=true
 local rollId=station:GetAttribute("RollId")
 local startedAt=station:GetAttribute("RollStartedAt") or now
 local duration=station:GetAttribute("RollDuration") or Config.RollRevealSeconds
 local elapsed=math.max(0,now-startedAt)
 local rolling=rollId~=nil and (station:GetAttribute("Rolling") or elapsed<duration)
 local reduced=self.app.reducedMotion
 if rollId~=record.rollId then
  if record.preview then record.preview.Parent=nil;record.preview=nil end
  record.rollId,record.lastStage,record.result=rollId,0,nil
  record.sequence={}
  local tier=station:GetAttribute("RollTier") or station:GetAttribute("RecruitTier") or 1
  local luck=station:GetAttribute("RollLuck") or 0
  local paidLuck=station:GetAttribute("RollPaidLuck") or 1
  local researchLuck=station:GetAttribute("RollResearchLuck") or 0
  local random=Random.new(station:GetAttribute("RollSeed") or 1)
  -- Cosmetic candidates use the same weights; rare chickens are not teased equally.
  for i=1,#BEATS do
   record.sequence[i]=Rules.Draw(luck,random:NextNumber(),tier,paidLuck,researchLuck)
  end
  if rollId then
   self:Warm(record,station:GetAttribute("PendingSpecies"))
   for _,shuffled in record.sequence do self:Warm(record,shuffled) end
  end
  if rollId and elapsed<0.3 then self:Sound(record,"RollLever",0.9,0.55,0.3) end
  self:HideBadge(record)
  local special=station:GetAttribute("RollSpecial")
  record.special=if rollId and type(special)=="string" and GoldRolls.Colors[special] then special else nil
  if record.special and elapsed<duration+SPECIAL_TAG_HOLD then self:ShowSpecialTag(record,record.special)
  else self:HideSpecialTag(record) end
 end

 -- Hide only the static server offer. Cosmetics never hide inventory or army pets.
 local serverPet=station:FindFirstChild("DisplayedPet")
 if serverPet~=record.serverPet then
  for part, value in record.hidden do if part.Parent then part.LocalTransparencyModifier=value end end
  table.clear(record.hidden)
  record.serverPet=serverPet
 end
 if serverPet then
  for _, part in serverPet:GetDescendants() do
   if part:IsA("BasePart") and record.hidden[part]==nil then
    record.hidden[part]=part.LocalTransparencyModifier;part.LocalTransparencyModifier=1
   end
  end
 end

 -- Empty-podium hint: own podiums beyond slot 1 (the server labels slot 1).
 self:SetIdleHint(record,not rolling and serverPet==nil
  and (station:GetAttribute("RollSlot") or 1)>1 and station:GetAttribute("Unlocked")~=false
  and station:GetAttribute("OwnerId")==Players.LocalPlayer.UserId)
 if rolling then
  -- Late attribute replication: warm as soon as the pending species arrives.
  self:Warm(record,station:GetAttribute("PendingSpecies"))
  local progress=math.clamp(elapsed/duration,0,1)
  local stage=0
  for i,beat in BEATS do if progress>=beat then stage=i else break end end
  if stage>0 and stage~=record.lastStage then
   record.lastStage=stage
   self:Preview(record,record.sequence[stage],true)
   -- Skip missed sounds when entering mid-roll or recovering from a slow frame.
   if elapsed-BEATS[stage]*duration<0.12 then
    self:Sound(record,"RollTick",1.65-stage*0.055,0.32+stage*0.008,0.14)
   end
  end
  record.glow.Enabled=record.preview~=nil
  local angle=0
  if not reduced then
   if elapsed<0.16 then angle=-0.95*math.sin(elapsed/0.16*math.pi/2)
   elseif elapsed<0.24 then angle=-0.95
   else angle=-0.95*math.max(0,1-(elapsed-0.24)/0.42)^2 end
  end
  local pivot=record.leverPivot*CFrame.Angles(angle,0,0)
  if record.arm and record.knob then
   record.arm.CFrame=pivot*record.armRest
   record.knob.CFrame=pivot*record.knobRest
  end
  local beatAge=if stage>0 then elapsed-BEATS[stage]*duration else 0
  local pulse=math.max(0,1-beatAge/0.18)
  -- A special pull glows in its own color, brighter, on every podium.
  local glow=if record.special then specialColor(record.special,now) else GOLD
  local rest=if record.special then glow:Lerp(Color3.new(0,0,0),0.35) else BLUE
  local strength=if record.special then 1.8 else 1
  record.top.Color=glow:Lerp(rest,0.25*(1-pulse))
  if record.light then record.light.Color=glow;record.light.Brightness=if reduced then 0.2*strength else (0.25+pulse*0.45)*strength end
  if record.preview then
   local hop=if reduced then 0 else math.sin(math.min(beatAge/0.18,1)*math.pi)*0.38
   local yaw=if reduced then 0 else (if stage%2==0 then 1 else -1)*pulse*0.16
   PetView.Move(record.preview,record.foot,(record.frame*CFrame.Angles(0,yaw,0)).LookVector,hop)
  end
  return
 end

 record.glow.Enabled=false
 local result,species=station:GetAttribute("RevealedOfferId"),station:GetAttribute("RevealedSpecies")
 if result and result==rollId and species and Catalog[species] then
  local def=Catalog[species]
  local rank=RARITY[def.rarity] or 1
  local tint=Color3.fromRGB(table.unpack(def.color))
  if result~=record.result then
   local fresh=elapsed<duration+0.65
   record.result=result;record.landedAt=if fresh then now else now-10
   record.finishPlayed=not fresh
   record.revealFresh=fresh
   self:Preview(record,species)
   if fresh then
    self:Sound(record,"Pop",1.12,0.45,0.35)
    -- The roll camera reveals with the rarest chicken appearing on your podiums.
    if station:GetAttribute("OwnerId")==Players.LocalPlayer.UserId and (not self.reveal or rank>self.reveal.rank) then
     self.reveal={rank=rank,color=UIColors.Rarities[def.rarity]}
    end
   end
  end
  local age=now-record.landedAt
  if record.special and age>=SPECIAL_TAG_HOLD then self:HideSpecialTag(record) end
  if not record.finishPlayed and age>=0.16 then
   record.finishPlayed=true
   self:Sound(record,"RollLand",1.4,0.22,0.22)
   self:Sound(record,if rank>=4 then "RollRare" else "RollReveal",if rank>=5 then 1.12 else 1,if rank>=4 then 0.5 else 0.32,nil)
   if record.burst and not reduced then
    record.burst.Color=ColorSequence.new(tint,GOLD)
    record.burst:Emit(if rank>=4 then 26 else 12)
   end
  end
  local hop=0
  if not reduced then
   if age<0.16 then hop=0.9*(1-(age/0.16)^2)
   elseif age<0.42 then hop=math.sin((age-0.16)/0.26*math.pi)*0.22
   else hop=0.08*(1-math.exp(-(age-0.42)*3))*(1+math.sin(age*2)) end
  end
  PetView.Move(record.preview,record.foot,record.frame.LookVector,hop)
  -- The mutation can arrive a moment after the species (snapshot vs attributes).
  local mutation=self:MutationFor(station,result)
  if record.preview and record.preview:GetAttribute("Mutation")~=mutation then record.preview:SetAttribute("Mutation",mutation) end
  if mutation and age>=MUTATION_BADGE_DELAY then
   self:ShowBadge(record,mutation,record.revealFresh==true and age<MUTATION_BADGE_DELAY+1.5)
  elseif not mutation then self:HideBadge(record) end
  record.top.Color=tint:Lerp(GOLD,math.max(0,1-age/0.55)*0.55)
  if record.light then
   record.light.Color=if rank>=4 then GOLD else tint
   record.light.Brightness=if reduced then 0 else math.max(0,1-age/0.9)*(if rank>=4 then 2 else 1.2)
  end
 else
  if record.preview then record.preview.Parent=nil;record.preview=nil end
  self:HideBadge(record)
  self:HideSpecialTag(record)
  record.top.Color=BLUE
  if record.light then record.light.Brightness=0 end
 end
 if record.arm and record.knob then
  record.arm.CFrame=record.leverPivot*record.armRest
  record.knob.CFrame=record.leverPivot*record.knobRest
 end
end

function RollPresentationController:Start(world)
 self.world=world
 self.folder=Instance.new("Folder")
 self.folder.Name,self.folder.Parent="PetRollLocalRolls",workspace
 table.insert(self.connections,RunService.RenderStepped:Connect(function()
  local now=workspace:GetServerTimeNow()
  if now>=self.scanAt then
   self.scanAt=now+0.25
   for _,plot in world:GetChildren() do
    for _,station in plot:GetChildren() do
     if station:GetAttribute("IsRollStation") or station.Name=="RollStation" then self:Track(station) end
    end
   end
  end
  for station,record in self.records do
   if not station:IsDescendantOf(world) then
    self:Reset(record)
    for _,model in record.cache do model:Destroy() end
    if record.badge then record.badge.gui:Destroy() end
    if record.idleHint then record.idleHint:Destroy() end
    if record.specialTag then record.specialTag.gui:Destroy() end
    record.glow:Destroy();self.records[station]=nil
   else
    self:NoteSpecial(record,now)
    self:StepRecord(record,now)
   end
  end
  self:StepCamera(now)
 end))
end

function RollPresentationController:Destroy()
 for _,connection in self.connections do connection:Disconnect() end
 self.rollCamera:Destroy()
 for _,record in self.records do
  self:Reset(record)
  for _,model in record.cache do model:Destroy() end
 end
 table.clear(self.records)
 if self.folder then self.folder:Destroy() end
end

return RollPresentationController
