--!strict
-- One client animator for every streamed duck rig. It only poses joints;
-- Humanoid physics and authoritative positions remain on the server.
-- October 21 game feel: home chickens near the player cluck now and then
-- (Cluck1/2/3, one at a time), and a fed chicken hops (Celebrate): V3 rigs play
-- their Victory clip, Motor6D rigs lift through the Root joint pose. Nothing here
-- moves a model. Budgets in CollectionFeel.Feel.
-- October 27 (WS6, docs/team/MOBILE_PERFORMANCE_20261027.md): one scheduler for every
-- rig, V3 included (they used to pose every bone each frame within 170 studs). Every
-- 0.1 s each record is ranked by camera distance and screen: the nearest on-screen
-- chickens step every frame, the rest at PerfTier's mid/far/off-screen rates; only the
-- nearest fxMaxChickens on screen run particles (rates scaled by fxRateScale).
-- Attributes are cached per model (invalidated by AttributeChanged) and shared with
-- the VFX and voxel animators. Config.Performance.AnimLOD=false restores per-frame steps.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Feel = require(game:GetService("ReplicatedStorage").PetRoll.Shared.CollectionFeel)
local Config = require(game:GetService("ReplicatedStorage").PetRoll.Shared.Config)
local PerfTier = require(script.Parent.PerfTier)
local ChickenClipPlayer = require(script.Parent.ChickenClipPlayer)
local RareChickenVFX = require(script.Parent.RareChickenVFX)
local SpecialChickenVFX = require(script.Parent.SpecialChickenVFX)
local GlitchEditableMesh = require(script.Parent.GlitchEditableMesh)
local VoxelChickenAnimator = require(script.Parent.VoxelChickenAnimator)
local GalaxyDragonAnimator = require(script.Parent.GalaxyDragonAnimator)
local ChickenEffectQuality = require(script.Parent.ChickenEffectQuality)
local GalaxyViewportEffect = require(script.Parent.GalaxyViewportEffect)
local KingVisual = require(game:GetService("ReplicatedStorage").PetRoll.Shared.KingVisual)
local DuckAnimator = {}
DuckAnimator.__index = DuckAnimator
local JOINTS = {"Root", "Neck", "WingLeft", "WingRight", "FootLeft", "FootRight"}
local CLUCKS = {"Cluck1", "Cluck2", "Cluck3"}
local ANIM_LOD = ((Config :: any).Performance or {}).AnimLOD ~= false
local RANK_SECONDS = 0.1 -- how often records are re-ranked (a rig turning into view waits at most this)
local SLEEP_HZ = 1 -- beyond the far radius: cues and resets still run, about once a second
local FX_MIN_HZ = 10 -- a chicken showing particles steps at least this often
local SCREEN_MARGIN = 0.15 -- viewport share added around the screen
local SCREEN_PAD = 4 -- studs around a root that still count as on screen (wings, hats, size)
local NIL = {} -- attribute cache sentinel for a missing attribute

-- One cached GetAttribute per model; AttributeChanged drops the stale entry so the
-- next read fetches it again (one frame late at most under deferred signals).
local function attributeCache(model: Model): ((string) -> any, RBXScriptConnection)
	local values: {[string]: any} = {}
	local connection = model.AttributeChanged:Connect(function(name: string) values[name] = nil end)
	return function(name: string): any
		local value = values[name]
		if value == nil then
			local fresh = model:GetAttribute(name)
			values[name] = if fresh == nil then NIL else fresh
			return fresh
		end
		return if value == NIL then nil else value
	end, connection
end

local function release(record: any)
	if record.blender then record.blender:Destroy() end
	if record.fx then record.fx:Destroy() end
	if record.glitch then record.glitch:Destroy() end
	if record.attrConnection then record.attrConnection:Disconnect(); record.attrConnection = nil end
end

local function byDistance(a: any, b: any): boolean return a.distance < b.distance end

local function phaseFor(name: string): number
	local phase = 0
	for i = 1, #name do phase += string.byte(name, i) * 0.071 end
	return phase % (math.pi * 2)
end

function DuckAnimator.new(audio)
	local self = setmetatable({records = {}, connections = {}, reducedMotion = false, destroyed = false, audio = audio, nextCluckAt = 0,
		nextRankAt = 0, rankFull = {}, rankFx = {},
		effectQuality = ChickenEffectQuality.new(), galaxyMask = GalaxyViewportEffect.new()}, DuckAnimator)
	local function discover(item: Instance)
		if item:IsA("Model") and (item:GetAttribute("DuckRig") == true or item:GetAttribute("SkinnedChicken") == true or item:GetAttribute("GalaxyDragonAnimation") == true) and not self.records[item] then
			local attr, attrConnection = attributeCache(item)
			local dragon = attr("GalaxyDragonAnimation") == true
			local v3 = attr("ChickenVisualV3") == true
			self.records[item] = {model = item, root = nil, joints = {}, phase = phaseFor(item.Name),
				lastPose = 0, lastScan = -1, attackSerial = attr("AttackSerial") or 0,
				attackAt = -10, hopAt = -10, sleeping = false, attr = attr, attrConnection = attrConnection,
				-- Scheduler (ANIM_LOD): due time, step interval and the particle slot, set by _rank.
				nextAt = 0, interval = 0, distance = 0, fxAllowed = false, wasAllowed = false,
				fx = if dragon or v3 then SpecialChickenVFX.new(item, audio, attr) else RareChickenVFX.new(item, attr),
				glitch = if dragon then nil else GlitchEditableMesh.new(item),
				blender = if dragon then GalaxyDragonAnimator.new(item) elseif v3 then VoxelChickenAnimator.new(item, attr) elseif attr("SkinnedChicken") then ChickenClipPlayer.new(item) else nil}
			self.nextRankAt = 0
		end
	end
	for _, tag in {"DuckRig", "ChickenVisual"} do
		for _, item in CollectionService:GetTagged(tag) do discover(item) end
	end
	-- Attribute discovery also supports commissioned rigs that omit the tag.
	for _, item in workspace:GetDescendants() do
		if item:IsA("Model") then discover(item) end
	end
	for _, tag in {"DuckRig", "ChickenVisual"} do
		table.insert(self.connections, CollectionService:GetInstanceAddedSignal(tag):Connect(discover))
	end
	table.insert(self.connections, workspace.DescendantAdded:Connect(discover))
	table.insert(self.connections, CollectionService:GetInstanceRemovedSignal("DuckRig"):Connect(function(item)
		if not item:IsDescendantOf(workspace) then
			local record = self.records[item]
			if record then release(record) end
			self.records[item] = nil
		end
	end))
	table.insert(self.connections, RunService.RenderStepped:Connect(function(dt) self:_step(dt) end))
	return self
end

function DuckAnimator:SetReducedMotion(reduced: boolean)
	self.reducedMotion = reduced == true
end

-- A fed chicken's happy hop. V3 rigs play their Victory clip; Motor6D rigs lift
-- through the Root joint in _step. The server owns the model's position, so the
-- PrimaryPart is never moved. Reduced motion skips it (the flash and text remain).
function DuckAnimator:Celebrate(model: Model)
	local record = self.records[model]
	if not record or self.reducedMotion then return end
	local blender: any = record.blender
	if blender then
		if blender.Cue then blender:Cue("Victory", os.clock()) end
	else
		record.hopAt = os.clock()
	end
	-- October 27 (WS6): the hop shows at once, whatever the record's step rate.
	record.nextAt = 0
end

-- Where ambient clucks are heard from: the player's root, else the camera.
function DuckAnimator:Listener(camera: Camera?): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root.Position end
	return if camera then camera.CFrame.Position else nil
end

-- One positioned cluck from a home chicken (only cues the library has; Effects off
-- is silent inside AudioController).
function DuckAnimator:Cluck(position: Vector3)
	local audio = self.audio
	if not audio or not audio.Has then return end
	local names = {}
	for _, name in CLUCKS do
		if audio:Has(name) then table.insert(names, name) end
	end
	if #names == 0 then return end
	audio:PlayAt(names[math.random(#names)], position, nil,
		{noFallback = true, voiceKey = "AmbientCluck", cooldown = Feel.Feel.CluckGap * 0.5, pitchVariance = 0.1, maxDuration = 1.5})
end

-- October 27 (WS6): rank every record by distance and screen (a dot-product test
-- against the camera frustum plus a margin, no WorldToViewportPoint), then keep the
-- full-rate and particle slots for the nearest ones.
function DuckAnimator:_rank(now: number, camera: Camera, budget: PerfTier.Budget, cullDistance: number)
	local frame = camera.CFrame
	local origin, look, right, up = frame.Position, frame.LookVector, frame.RightVector, frame.UpVector
	local viewport = camera.ViewportSize
	local tanV = math.tan(math.rad(camera.FieldOfView) / 2) * (1 + SCREEN_MARGIN)
	local tanH = tanV * (if viewport.Y > 0 then viewport.X / viewport.Y else 1)
	local full, fx = self.rankFull, self.rankFx
	table.clear(full)
	table.clear(fx)
	for model, record in self.records do
		local before = record.interval
		record.wasAllowed, record.fxAllowed = record.fxAllowed, false
		local part = record.root or model.PrimaryPart
		if not part then
			record.interval, record.distance = 1 / SLEEP_HZ, math.huge
			continue
		end
		local offset = part.Position - origin
		local distance = offset.Magnitude
		local depth = offset:Dot(look)
		local onScreen = distance <= SCREEN_PAD * 2 or (depth > 0
			and math.abs(offset:Dot(right)) <= depth * tanH + SCREEN_PAD
			and math.abs(offset:Dot(up)) <= depth * tanV + SCREEN_PAD)
		record.distance = distance
		local interval
		if distance > budget.animFarRadius then interval = 1 / SLEEP_HZ
		elseif not onScreen then interval = 1 / budget.offscreenHz
		elseif distance <= budget.animFullRadius then interval = 0; table.insert(full, record)
		elseif distance <= budget.animMidRadius then interval = 1 / budget.animMidHz
		else interval = 1 / budget.animFarHz end
		record.interval = interval
		if onScreen and distance <= cullDistance then table.insert(fx, record) end
		-- A faster rate (turned into view, walked closer) applies at once.
		if interval < before then record.nextAt = math.min(record.nextAt, now) end
	end
	-- The nearest animFullMax on-screen rigs step every frame; the rest drop to mid.
	if #full > budget.animFullMax then
		table.sort(full, byDistance)
		for i = budget.animFullMax + 1, #full do full[i].interval = 1 / budget.animMidHz end
	end
	if #fx > budget.fxMaxChickens then table.sort(fx, byDistance) end
	for i = 1, math.min(#fx, budget.fxMaxChickens) do
		local record = fx[i]
		record.fxAllowed = true
		record.interval = math.min(record.interval, 1 / FX_MIN_HZ)
	end
	-- Particles switching on or off step this frame.
	for _, record in self.records do
		if record.fxAllowed ~= record.wasAllowed then record.nextAt = now end
	end
end

function DuckAnimator:_step(dt: number)
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local tier = self.effectQuality:Step(dt)
	local cullDistance = self.effectQuality:CullDistance()
	local lod = ANIM_LOD and camera ~= nil
	local rateScale: number? = nil
	if lod then
		local budget = PerfTier.Budget()
		cullDistance = math.min(cullDistance, budget.fxCull)
		rateScale = budget.fxRateScale
		if now >= self.nextRankAt then
			self.nextRankAt = now + RANK_SECONDS
			self:_rank(now, camera :: Camera, budget, cullDistance)
		end
	end
	-- Every CluckGap seconds one home chicken within CluckRange is picked at random
	-- (reservoir sample inside the pose loop: no extra pass over the yard).
	local picking = now >= self.nextCluckAt
	local listener = if picking then self:Listener(camera) else nil
	local cluckAt: Vector3?, cluckCount = nil, 0
	for model, record in self.records do
		if not model:IsDescendantOf(workspace) then
			release(record)
			self.records[model] = nil continue
		end
		local attr = record.attr
		if listener and attr("PetId") ~= nil and attr("AtHome") ~= false
			and not attr("Defeated") and attr("PresentationHidden") ~= true then
			local part = model.PrimaryPart
			if part and (part.Position - listener).Magnitude <= Feel.Feel.CluckRange then
				cluckCount += 1
				if math.random() * cluckCount < 1 then cluckAt = part.Position end
			end
		end
		-- October 27 (WS6): a record that is not due keeps its last pose this frame.
		if lod then
			if now < record.nextAt then continue end
			record.nextAt = now + record.interval
		end
		if attr("ChickenKing") then KingVisual.Update(model) end
		-- Revealed offers reserve the original mesh for masking. Every roaming
		-- Galaxy uses the same shared animated material at medium/high quality.
		local textureTier = if tier == "static" or (tier == "masked" and attr("GalaxyMaskPreview") == true)
			then "static" else "animated"
		if record.fx then record.fx:Step(now, self.reducedMotion, camera, textureTier, cullDistance,
			if lod then record.fxAllowed else nil, rateScale) end
		if record.glitch then record.glitch:Step(now, self.reducedMotion, camera) end
		if record.blender then
			record.blender:Step(now, self.reducedMotion or attr("ReducedMotion") == true)
			continue
		end
		if now - record.lastScan > 0.5 and (not record.root or not record.joints.Root or not record.joints.Neck) then
			record.lastScan = now
			record.root = model:FindFirstChild("HumanoidRootPart")
			for _, name in JOINTS do
				local joint = model:FindFirstChild(name, true)
				if joint and joint:IsA("Motor6D") then record.joints[name] = joint end
			end
		end
		local root = record.root
		if not root or not root:IsA("BasePart") then continue end
		local distance = if camera then (camera.CFrame.Position - root.Position).Magnitude else 0
		local hidden = attr("PresentationHidden") == true or root.LocalTransparencyModifier >= 1
		local reduced = self.reducedMotion or attr("ReducedMotion") == true
		if distance > 170 or hidden then
			if not record.sleeping then
				for _, joint in record.joints do joint.Transform = CFrame.identity end
				record.sleeping = true
			end
			continue
		end
		record.sleeping = false
		local interval = if distance > 85 then 0.1 elseif distance > 40 then 1 / 30 else 0
		if now - record.lastPose < interval then continue end
		local elapsed = math.min(now - record.lastPose, 0.15)
		record.lastPose = now
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local walk = math.clamp(speed / 5, 0, 1)
		record.phase += elapsed * (1.8 + speed * 1.6)
		local serial = attr("AttackSerial") or 0
		if serial ~= record.attackSerial then
			local started=attr("AttackStartedAt")
			record.attackSerial,record.attackAt=serial,now-(if started then math.max(0,workspace:GetServerTimeNow()-started) else 0)
		end
		local attackAge = now - record.attackAt
		local attack = if attackAge>=0 and attackAge<0.6 and not attr("Defeated") then math.sin(attackAge/0.6*math.pi) else 0
		if reduced then walk, attack = 0, 0 end
		local wave = math.sin(record.phase)
		local size = attr("Size") or 2.5
		local bob = if reduced then 0 else (math.abs(wave) * walk * 0.024 + math.sin(record.phase * 0.5) * 0.004) * size
		local roll = if reduced then 0 else wave * (0.012 + walk * 0.065)
		-- Celebrate: a short lift and back on the Root joint.
		local hop = (now - record.hopAt) / Feel.Feel.HopSeconds
		local lift = if reduced or hop < 0 or hop >= 1 then 0 else math.sin(hop * math.pi) * Feel.Feel.HopHeight
		local joints = record.joints
		if joints.Root then joints.Root.Transform = CFrame.new(0, bob + lift, -attack * size * 0.06) * CFrame.Angles(-attack * 0.11, 0, roll) end
		if joints.Neck then joints.Neck.Transform = CFrame.Angles(-attack * 0.32, 0, -roll * 0.4) end
		if joints.WingLeft then joints.WingLeft.Transform = CFrame.Angles(wave * walk * 0.08, 0, -walk * 0.07 - attack * 0.24) end
		if joints.WingRight then joints.WingRight.Transform = CFrame.Angles(-wave * walk * 0.08, 0, walk * 0.07 + attack * 0.24) end
		if joints.FootLeft then joints.FootLeft.Transform = CFrame.new(0, math.max(wave, 0) * walk * size * 0.035, -wave * walk * size * 0.035) * CFrame.Angles(wave * walk * 0.24, 0, 0) end
		if joints.FootRight then joints.FootRight.Transform = CFrame.new(0, math.max(-wave, 0) * walk * size * 0.035, wave * walk * size * 0.035) * CFrame.Angles(-wave * walk * 0.24, 0, 0) end
	end
	-- Copy the final bone pose, not last frame's pose, into the cosmetic viewport.
	self.galaxyMask:Step(now, camera, self.records, tier, self.reducedMotion)
	if picking then
		self.nextCluckAt = now + Feel.Feel.CluckGap
		if cluckAt then self:Cluck(cluckAt) end
	end
end

function DuckAnimator:Destroy()
	if self.destroyed then return end
	self.destroyed = true
	for _, connection in self.connections do connection:Disconnect() end
	self.galaxyMask:Destroy()
	self.effectQuality:Destroy()
	for _, record in self.records do
		release(record)
		for _, joint in record.joints do if joint.Parent then joint.Transform = CFrame.identity end end
	end
	table.clear(self.connections)
	table.clear(self.records)
end

return DuckAnimator
