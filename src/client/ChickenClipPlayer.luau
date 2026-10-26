--!strict
-- Plays the authored Blender poses through one Animator per chicken. Clip IDs
-- are registered locally for this Studio PC prototype; no cloud uploads needed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClipProvider = game:GetService("AnimationClipProvider")
local ChickenClipPlayer = {}
ChickenClipPlayer.__index = ChickenClipPlayer
local registered = {}
local priorities = {Idle = Enum.AnimationPriority.Idle, Walk = Enum.AnimationPriority.Movement,
	Attack = Enum.AnimationPriority.Action, Hit = Enum.AnimationPriority.Action2, Victory = Enum.AnimationPriority.Action}
-- October 25: conquering actions (attributes ActionSerial / Action) reuse authored clips.
local ACTION_CLIPS: {[string]: string} = {Peck = "Attack", Hop = "Victory"}

local function clipIds(species, scale)
	local key = species .. "/" .. string.format("%.4f", scale)
	if registered[key] then return registered[key] end
	local folder = ReplicatedStorage.PetRoll:FindFirstChild("ChickenClips")
	local module = folder and folder:FindFirstChild(species)
	if not module then return nil end
	local data = require(module)
	local result = {}
	for name, clip in data.clips do
		local sequence = Instance.new("KeyframeSequence")
		sequence.Name, sequence.Loop, sequence.Priority = species .. "_" .. name, clip.loop, priorities[name]
		for _, frame in clip.frames do
			local keyframe = Instance.new("Keyframe")
			keyframe.Time = frame.time
			keyframe.Parent = sequence
			local shell = Instance.new("Pose")
			shell.Name, shell.Weight, shell.Parent = "HumanoidRootPart", 0, keyframe
			local mesh = Instance.new("Pose")
			mesh.Name, mesh.Weight, mesh.Parent = "Body", 0, shell
			local poses = {}
			for i, bone in data.bones do
				local values = table.clone(frame.poses[i])
				for n = 1, 3 do values[n] *= scale end
				local pose = Instance.new("Pose")
				pose.Name = bone
				pose.CFrame = CFrame.new(table.unpack(values))
				pose.EasingStyle = Enum.PoseEasingStyle.Linear
				pose.Parent = if data.parents[i] == 0 then mesh else poses[data.parents[i]]
				poses[i] = pose
			end
		end
		local animation = Instance.new("Animation")
		animation.Name = name
		animation.AnimationId = ClipProvider:RegisterAnimationClip(sequence)
		result[name] = animation
		sequence:Destroy()
	end
	registered[key] = result
	return result
end

function ChickenClipPlayer.new(model)
	return setmetatable({model = model, tracks = {}, ready = false, retryAt = 0,
		serials = {AttackSerial = model:GetAttribute("AttackSerial") or 0,
			HitSerial = model:GetAttribute("HitSerial") or 0, VictorySerial = model:GetAttribute("VictorySerial") or 0,
			ActionSerial = model:GetAttribute("ActionSerial") or 0},
		base = nil, sleeping = false}, ChickenClipPlayer)
end

function ChickenClipPlayer:_load()
	local animator = self.model:FindFirstChildWhichIsA("Animator", true)
	if not animator or not self.model:FindFirstChild("root", true) then return false end
	local scale = self.model:GetAttribute("ClipScale") or 1
	local ids = clipIds(self.model:GetAttribute("Species"), scale)
	if not ids then return false end
	for name, animation in ids do
		local track = animator:LoadAnimation(animation)
		track.Priority = priorities[name]
		track.Looped = name == "Idle" or name == "Walk"
		self.tracks[name] = track
	end
	self.ready, self.loadedScale = true, scale
	return true
end

function ChickenClipPlayer:Step(now, reduced)
	-- Bone translations are authored in model space, so merge growth needs
	-- matching clips even when a streamed actor was already animating.
	if self.ready and self.loadedScale ~= (self.model:GetAttribute("ClipScale") or 1) then
		self:Destroy()
		self.ready, self.base, self.retryAt, self.sleeping = false, nil, 0, false
	end
	if not self.ready then
		if now < self.retryAt then return end
		self.retryAt = now + 2
		local ok, result = pcall(function() return self:_load() end)
		if not ok then
			if not self.warned then warn("Chicken animation: " .. tostring(result)); self.warned = true end
			return
		end
		if not result then return end
	end
	local model = self.model
	local hidden = model:GetAttribute("PresentationHidden") == true
	local defeated = model:GetAttribute("Defeated") == true
	if hidden or defeated or reduced then
		if not self.sleeping then for _, track in self.tracks do track:Stop(0.12) end end
		self.sleeping, self.base = true, nil
		return
	end
	self.sleeping = false
	local root = model.PrimaryPart
	local v = root and root.AssemblyLinearVelocity or Vector3.zero
	local speed = if model:GetAttribute("DuckRig") then Vector3.new(v.X, 0, v.Z).Magnitude else model:GetAttribute("PreviewSpeed") or 0
	local name = if speed > 0.45 then "Walk" else "Idle"
	if name ~= self.base then
		if self.base then self.tracks[self.base]:Stop(0.13) end
		self.tracks[name]:Play(0.13)
		self.base = name
	end
	if name == "Walk" then self.tracks.Walk:AdjustSpeed(math.clamp(speed / 4, 0.65, 2.4)) end
	for attribute, clip in {AttackSerial = "Attack", HitSerial = "Hit", VictorySerial = "Victory"} do
		local serial = model:GetAttribute(attribute) or 0
		if serial ~= self.serials[attribute] then
			self.serials[attribute] = serial
			local started=if clip=="Attack" then model:GetAttribute("AttackStartedAt") else nil
			local age=if started then math.max(0,workspace:GetServerTimeNow()-started) else 0
			-- Match the server windup even when a pose reaches this client a little
			-- late. Old streamed attacks must not replay after their damage.
			if clip~="Attack" or age<0.75 then
				local track=self.tracks[clip]
				track:Play(0.035)
				if age>0 and track.Length>0 then track.TimePosition=math.min(age,track.Length) end
			end
		end
	end
	local actionSerial = model:GetAttribute("ActionSerial") or 0
	if actionSerial ~= self.serials.ActionSerial then
		self.serials.ActionSerial = actionSerial
		local action = model:GetAttribute("Action")
		local clip = if typeof(action) == "string" then ACTION_CLIPS[action] else nil
		local track = if clip then self.tracks[clip] else nil
		if track then track:Play(0.035) end
	end
	local localAttack = model:GetAttribute("LocalAttackAt")
	if model:GetAttribute("AttackSerial") == nil and localAttack and localAttack ~= self.localAttack then self.localAttack = localAttack; self.tracks.Attack:Play(0.045) end
end

function ChickenClipPlayer:Destroy()
	for _, track in self.tracks do track:Stop(0); track:Destroy() end
	table.clear(self.tracks)
end

return ChickenClipPlayer
