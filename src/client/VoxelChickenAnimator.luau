--!strict
-- Plays baked Blender-local poses on the imported V3 bones. DuckAnimator owns
-- scheduling and teardown; server movement, damage and mesh appearance stay separate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VoxelChickenAnimator = {}
VoxelChickenAnimator.__index = VoxelChickenAnimator

type Frame = {time: number, poses: {CFrame}}
type Clip = {duration: number, loop: boolean, frames: {Frame}}
type ClipSet = {bones: {string}, clips: {[string]: Clip}}
type Cue = {name: string, started: number}
type State = {
	model: Model, bones: {Bone}, mirrors: {{Bone}}, original: {CFrame}, poses: {CFrame},
	data: ClipSet?, rootIndex: number?, retryAt: number, warned: boolean,
	serials: {[string]: any}, cues: {[string]: Cue}, localAttack: any,
	lastStep: number?, base: string, baseTime: number, mode: string?,
	transitionAt: number, transition: {CFrame}, defeatAt: number?,
	sleeping: boolean, destroyed: boolean,
}
type Controller = typeof(setmetatable({} :: State, VoxelChickenAnimator))

local decoded: {[ModuleScript]: ClipSet} = setmetatable({}, {__mode = "k"}) :: any
local EVENTS: {[string]: string} = {AttackSerial = "Attack", HitSerial = "Hit", VictorySerial = "Victory"}
local CUE_PRIORITY = {"Hit", "Attack", "Victory"}

local function numericAttribute(model: Model, name: string, fallback: number): number
	local value = model:GetAttribute(name)
	return if typeof(value) == "number" and value == value and math.abs(value) < math.huge then value else fallback
end

local function decode(module: ModuleScript): ClipSet
	local existing = decoded[module]
	if existing then return existing end
	local source = require(module) :: any
	local result: ClipSet = {bones = source.bones, clips = {}}
	for name, sourceClip in source.clips do
		local frames: {Frame} = {}
		for _, frame in sourceClip.frames do
			local poses: {CFrame} = {}
			for i, values in frame.poses do poses[i] = CFrame.new(table.unpack(values)) end
			table.insert(frames, {time = frame.time, poses = poses})
		end
		if #frames > 0 then
			result.clips[name] = {duration = math.max(sourceClip.duration or frames[#frames].time, 0.001),
				loop = sourceClip.loop == true, frames = frames}
		end
	end
	decoded[module] = result
	return result
end

local function sample(clip: Clip, time: number): (Frame, Frame, number)
	local frames = clip.frames
	local at = if clip.loop then time % clip.duration else math.clamp(time, 0, clip.duration)
	if at <= frames[1].time then return frames[1], frames[1], 0 end
	if at >= frames[#frames].time then return frames[#frames], frames[#frames], 0 end
	local low, high = 1, #frames
	while high - low > 1 do
		local middle = math.floor((low + high) / 2)
		if frames[middle].time <= at then low = middle else high = middle end
	end
	local first, second = frames[low], frames[high]
	return first, second, math.clamp((at - first.time) / math.max(second.time - first.time, 0.0001), 0, 1)
end

function VoxelChickenAnimator.new(model: Model): Controller?
	if model:GetAttribute("ChickenVisualV3") ~= true then return nil end
	local phase = 0
	for i = 1, #model.Name do phase += string.byte(model.Name, i) * 0.071 end
	local state: State = {model = model, bones = {}, mirrors = {}, original = {}, poses = {}, data = nil,
		rootIndex = nil, retryAt = 0, warned = false,
		serials = {AttackSerial = model:GetAttribute("AttackSerial") or 0,
			HitSerial = model:GetAttribute("HitSerial") or 0, VictorySerial = model:GetAttribute("VictorySerial") or 0},
		cues = {}, localAttack = model:GetAttribute("LocalAttackAt"), lastStep = nil,
		base = "Idle", baseTime = phase, mode = nil, transitionAt = 0, transition = {},
		defeatAt = nil, sleeping = false, destroyed = false}
	return setmetatable(state, VoxelChickenAnimator)
end

function VoxelChickenAnimator._load(self: Controller): boolean
	local petRoll = ReplicatedStorage:FindFirstChild("PetRoll")
	local clips = petRoll and petRoll:FindFirstChild("ChickenClips")
	local species = self.model:GetAttribute("Species")
	local module = if clips and typeof(species) == "string" then clips:FindFirstChild(species) else nil
	local body = self.model:FindFirstChild("Body")
	if not body or not module or not module:IsA("ModuleScript") then return false end
	local data = decode(module)
	if not data.clips.Idle then return false end
	local bones: {Bone}, original: {CFrame}, poses: {CFrame} = {}, {}, {}
	local rootIndex: number? = nil
	local bonePrefix = self.model:GetAttribute("BonePrefix")
	local rootName = if typeof(bonePrefix) == "string" then bonePrefix .. "Root" else nil
	for i, name in data.bones do
		local bone = body:FindFirstChild(name, true)
		if not bone or not bone:IsA("Bone") then return false end
		bones[i], original[i], poses[i] = bone, bone.Transform, CFrame.identity
		if (rootName and name == rootName) or (not rootName and (name == "Root" or string.match(name, "_Root$") ~= nil)) then
			rootIndex = i
		end
	end
	if not rootIndex then return false end
	self.bones, self.original, self.poses, self.rootIndex = bones, original, poses, rootIndex
	-- Each imported material surface owns a copy of the skeleton. Pose them
	-- together so hats, armor, faces and branches follow the same authored clip.
	local groups: {[string]: {Bone}} = {}
	for _, item in self.model:GetDescendants() do
		if item:IsA("Bone") then
			groups[item.Name] = groups[item.Name] or {}
			table.insert(groups[item.Name], item)
		end
	end
	for i,name in data.bones do self.mirrors[i] = groups[name] or {bones[i]} end
	self.data = data
	return true
end

function VoxelChickenAnimator._reset(self: Controller)
	for i, bone in self.bones do
		for _, target in self.mirrors[i] or {bone} do
			if target.Parent then target.Transform = self.original[i] end
		end
		self.poses[i] = CFrame.identity
	end
	self.mode = nil
	table.clear(self.cues)
	table.clear(self.transition)
end

function VoxelChickenAnimator._events(self: Controller, now: number, allow: boolean)
	for attribute, name in EVENTS do
		local serial = self.model:GetAttribute(attribute) or 0
		if serial ~= self.serials[attribute] then
			self.serials[attribute] = serial
			local started = self.model:GetAttribute("AttackStartedAt")
			local age = if name == "Attack" and typeof(started) == "number"
				then math.max(0, workspace:GetServerTimeNow() - started) else 0
			if allow and (name ~= "Attack" or age < 0.75) then
				self.cues[name] = {name = name, started = now - age}
			end
		end
	end
	local localAttack = self.model:GetAttribute("LocalAttackAt")
	if localAttack ~= self.localAttack then
		self.localAttack = localAttack
		if allow and localAttack ~= nil and self.model:GetAttribute("AttackSerial") == nil then
			self.cues.Attack = {name = "Attack", started = now}
		end
	end
end

-- October 21 game feel: a local clip cue (DuckAnimator:Celebrate plays "Victory" for
-- a fed chicken). Skipped while the rig is asleep, defeated or still loading.
function VoxelChickenAnimator.Cue(self: Controller, name: string, now: number)
	local data = self.data
	if self.destroyed or self.sleeping or self.defeatAt or not data or not data.clips[name] then return end
	self.cues[name] = {name = name, started = now}
end

function VoxelChickenAnimator.Step(self: Controller, now: number, reduced: boolean?, camera: Camera?)
	if self.destroyed then return end
	local model = self.model
	local dt = if self.lastStep then math.clamp(now - self.lastStep, 0, 0.15) else 0
	self.lastStep = now
	local defeated = model:GetAttribute("Defeated") == true
	if defeated then self.defeatAt = self.defeatAt or now else self.defeatAt = nil end
	local root = model.PrimaryPart
	local view = camera or workspace.CurrentCamera
	local distant = root ~= nil and view ~= nil and (view.CFrame.Position - root.Position).Magnitude > 170
	local paused = model:GetAttribute("PresentationHidden") == true or reduced == true
		or model:GetAttribute("ReducedMotion") == true or distant
	self:_events(now, not paused and not defeated)
	if not self.data then
		if now < self.retryAt then return end
		self.retryAt = now + 1
		local ok, loaded = pcall(function() return self:_load() end)
		if not ok or not loaded then
			if not ok and not self.warned then
				self.warned = true
				warn("V3 chicken animation: " .. tostring(loaded))
			end
			return
		end
	end
	if paused then
		if not self.sleeping then self:_reset() end
		self.sleeping = true
		return
	end
	self.sleeping = false
	local data = self.data :: ClipSet
	local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
	local speed = if model:GetAttribute("DuckRig") == true
		then Vector3.new(velocity.X, 0, velocity.Z).Magnitude else numericAttribute(model, "PreviewSpeed", 0)
	local moving = model:GetAttribute("MovementBlocked") ~= true and (speed > 0.45 or model:GetAttribute("Moving") == true)
	local base = if moving and data.clips.Walk then "Walk" else "Idle"
	if base ~= self.base then self.base, self.baseTime = base, 0 end
	local rate = if base == "Walk" then math.clamp((if speed > 0.45 then speed else 3) / 4, 0.65, 2.4) else 1
	self.baseTime += dt * rate
	local name, at, mode = base, self.baseTime, base
	for _, cueName in CUE_PRIORITY do
		local cue, clip = self.cues[cueName], data.clips[cueName]
		if cue and clip then
			local age = now - cue.started
			if age >= 0 and age < clip.duration then
				name, at, mode = cueName, age, cueName .. tostring(cue.started)
				break
			else self.cues[cueName] = nil end
		elseif cue then self.cues[cueName] = nil end
	end
	if defeated then
		table.clear(self.cues)
		name, at, mode = if data.clips.Defeat then "Defeat" else "Idle", now - (self.defeatAt or now), "Defeat"
	end
	if mode ~= self.mode then
		self.mode, self.transitionAt, self.transition = mode, now, table.clone(self.poses)
	end
	local first, second, alpha = sample(data.clips[name], at)
	local blend = math.clamp((now - self.transitionAt) / (if name == "Hit" or name == "Attack" then 0.035 else 0.12), 0, 1)
	local unitScale = math.max(0.0001, numericAttribute(model, "ClipUnitScale", 1))
	local scale = math.max(0.0001, numericAttribute(model, "ClipScale", 1)) * unitScale
	for i, bone in self.bones do
		if bone.Parent then
			local pose = first.poses[i]:Lerp(second.poses[i], alpha)
			if blend < 1 then pose = self.transition[i]:Lerp(pose, blend) end
			self.poses[i] = pose
			local transform = pose.Rotation + pose.Position * scale
			for _, target in self.mirrors[i] or {bone} do
				if target.Parent then target.Transform = transform end
			end
		end
	end
end

function VoxelChickenAnimator.Destroy(self: Controller)
	if self.destroyed then return end
	self.destroyed = true
	self:_reset()
	table.clear(self.bones)
	table.clear(self.mirrors)
	table.clear(self.original)
	table.clear(self.poses)
	self.data = nil
end

return VoxelChickenAnimator
