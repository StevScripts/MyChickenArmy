--!strict
-- Local presentation only. EggRover owns the route, claims, cargo and cash.
-- Blender's editable Idle/Move/Suction/Unload poses are exported in VacuumClips.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.PetRoll.Shared
local Config = require(Shared.VacuumConfig)
local Clips = require(Shared.VacuumClips)
local Feel = require(Shared.CollectionFeel)
local Theme = require(script.Parent.UITheme)

local Vacuum = {}
Vacuum.__index = Vacuum

-- Edit these without re-authoring the Blender clips.
local MOTION = {
	SnapshotBlendSeconds = 0.2,
	PoseResponse = 16,
	WalkCycleSpeed = 5,
	MovingThreshold = 0.2,
	TemplateRetrySeconds = 1,
}
local IDENTITY = {cf = CFrame.identity, scale = Vector3.one}
local GROUPS = {
	Body = "body", Hose = "body", Socket = "body",
	Nozzle = "nozzle", NozzleLeft = "nozzle", NozzleRight = "nozzle",
}

local function vector(values)
	return Vector3.new(values[1], values[2], values[3])
end

local function multiply(a, b)
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end

local function lerpPose(a, b, alpha)
	return {cf = a.cf:Lerp(b.cf, alpha), scale = a.scale:Lerp(b.scale, alpha)}
end

local compiled = {}
for name, clip in Clips.clips do
	local frames = {}
	for _, frame in clip.frames do
		local result = {time = frame.time}
		for _, group in {"body", "nozzle"} do
			local pose = frame[group]
			result[group] = {cf = CFrame.new(table.unpack(pose.cf)), scale = vector(pose.scale)}
		end
		table.insert(frames, result)
	end
	compiled[name] = {duration = clip.duration, loop = clip.loop, frames = frames}
end

local function sample(name, elapsed)
	local clip = compiled[name]
	if not clip or #clip.frames == 0 then return IDENTITY, IDENTITY end
	local t = if clip.loop then elapsed % math.max(clip.duration, 0.001) else math.clamp(elapsed, 0, clip.duration)
	local frames = clip.frames
	local low, high = 1, #frames
	while low < high do
		local mid = math.ceil((low + high) / 2)
		if frames[mid].time <= t then low = mid else high = mid - 1 end
	end
	local a, b = frames[low], frames[math.min(low + 1, #frames)]
	local alpha = if b.time > a.time then math.clamp((t - a.time) / (b.time - a.time), 0, 1) else 0
	return lerpPose(a.body, b.body, alpha), lerpPose(a.nozzle, b.nozzle, alpha)
end

local function forward(data)
	local direction = Vector3.new(data.dx or 0, 0, data.dz or -1)
	return if direction.Magnitude > 0.001 then direction.Unit else -Vector3.zAxis
end

function Vacuum.new(app, folder)
	return setmetatable({app = app, folder = folder, parts = {}, retryAt = 0,
		wheelLeft = 0, wheelRight = 0, moveTime = 0, moveWeight = 0,
		bodyPose = IDENTITY, nozzlePose = IDENTITY,
		startedAt = os.clock(), lastEffect = -10, pickupTotal = 0}, Vacuum)
end

function Vacuum:Clear()
	if self.model then self.model:Destroy() end
	if self.anchor then self.anchor:Destroy() end
	self.model, self.anchor, self.popup, self.spark = nil, nil, nil, nil
	table.clear(self.parts)
	self.rootCF, self.targetCF, self.data, self.id = nil, nil, nil, nil
	self.fromCF, self.receivedAt, self.blendSeconds = nil, nil, nil
	self.suctionSerial, self.unloadSerial, self.suctionAt, self.unloadAt = nil, nil, nil, nil
	self.unloadCycle, self.lastDepositId = nil, nil
	self.bodyPose, self.nozzlePose = IDENTITY, IDENTITY
	self.wheelLeft, self.wheelRight, self.moveTime, self.moveWeight = 0, 0, 0, 0
	self.lastAt, self.popupUntil, self.depositUntil = nil, nil, nil
	self.pickupTotal, self.lastEffect = 0, -10
end

function Vacuum:EnsureModel(now)
	if self.model then return true end
	if now < self.retryAt then return false end
	self.retryAt = now + MOTION.TemplateRetrySeconds
	local assets = ReplicatedStorage.PetRoll:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild(Config.TemplateName)
	if not template or not template:IsA("Model") then
		if not self.warned then
			warn("Egg vacuum visuals are waiting for ReplicatedStorage.PetRoll.Assets." .. Config.TemplateName)
			self.warned = true
		end
		return false
	end
	local model = template:Clone()
	model.Name = "EggVacuumLocal"
	local pivot = model:GetPivot()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			local restCF = part:GetAttribute("RestCFrame")
			local restSize = part:GetAttribute("RestSize")
			local cf = if typeof(restCF) == "CFrame" then restCF else pivot:ToObjectSpace(part.CFrame)
			local size = if typeof(restSize) == "Vector3" then restSize else part.Size
			if part.Name == "WheelLeft" or part.Name == "WheelRight" then
				local enlarged = multiply(size, Vector3.new(Config.WheelWidthScale, Config.WheelDiameterScale, Config.WheelDiameterScale))
				-- Keep the tread on the ground and the inner face clear of the body.
				local side = if cf.X < 0 then -1 else 1
				cf = CFrame.new(cf.Position + Vector3.new(side * (enlarged.X - size.X) / 2,
					(enlarged.Y - size.Y) / 2, 0)) * cf.Rotation
				size = enlarged
			end
			self.parts[part.Name] = {part = part, cf = cf, size = size}
		end
	end
	-- Pose before parenting, so the imported template never flashes at world origin.
	self.model = model
	self:ApplyPose()
	model.Parent = self.folder
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.Transparency = "VacuumSuctionTarget", Vector3.one * 0.1, 1
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.CastShadow = true, false, false, false, false
	anchor.Position = self:NozzlePosition() or self.rootCF.Position
	anchor.Parent = self.folder
	self.anchor = anchor
	local popup = Instance.new("BillboardGui")
	popup.Name, popup.Adornee, popup.Size = "VacuumPickup", anchor, UDim2.fromOffset(150, 42)
	popup.StudsOffset, popup.MaxDistance, popup.AlwaysOnTop = Vector3.new(0, 1.1, 0), 55, false
	popup.Enabled, popup.Parent = false, anchor
	self.label = Theme.Label(popup, "Amount", "", 24, Theme.Arcade.gold)
	self.label.Size, self.label.TextXAlignment = UDim2.fromScale(1, 1), Enum.TextXAlignment.Center
	self.popup = popup
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	local spark = Instance.new("ParticleEmitter")
	spark.Name, spark.Texture, spark.Rate = "VacuumPickupSpark", "rbxasset://textures/particles/sparkles_main.dds", 0
	spark.Color = ColorSequence.new(Color3.fromRGB(255, 226, 92), Color3.new(1, 1, 1))
	spark.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0)})
	spark.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1)})
	spark.Lifetime, spark.Speed, spark.SpreadAngle = NumberRange.new(0.12, 0.22), NumberRange.new(1, 2), Vector2.new(180, 180)
	spark.LightEmission, spark.Parent = 0.5, attachment
	self.spark = spark
	return true
end

function Vacuum:Receive(data, now)
	if not data or data.enabled ~= true then self:Clear();return end
	if self.id and self.id ~= data.id then self:Clear() end
	local previous = self.data
	self.id, self.data = data.id, data
	local position = Vector3.new(data.x, data.y, data.z)
	self.targetCF = CFrame.lookAt(position, position + forward(data))
	if not self.rootCF then self.rootCF = self.targetCF;self.startedAt = now end
	self.fromCF = self.rootCF
	self.blendSeconds = if self.receivedAt then math.clamp(now - self.receivedAt, 0.1, 0.35) else MOTION.SnapshotBlendSeconds
	self.receivedAt = now
	if self.suctionSerial ~= nil and self.suctionSerial ~= data.suctionSerial then self:PulseSuction(now) end
	-- The server increments its serial on completion. While unloading, serial+1
	-- identifies this delivery; completion and its receipt refer to that same ID.
	if data.state == "Unloading" then
		self:StartUnload((data.unloadSerial or 0) + 1, now)
	elseif previous and self.unloadSerial ~= data.unloadSerial then
		self:StartUnload(data.unloadSerial, now) -- Fallback if entry was never received.
	end
	self.suctionSerial, self.unloadSerial = data.suctionSerial, data.unloadSerial
	self:EnsureModel(now)
end

function Vacuum:StartUnload(cycle, now)
	if type(cycle) ~= "number" or cycle <= (self.unloadCycle or 0) then return end
	self.unloadCycle, self.unloadAt = cycle, now
end

function Vacuum:PulseSuction(now)
	-- Several eggs can settle in one packet. Finish most of the squeeze before
	-- starting another, instead of pinning the pose to its first frame.
	if not self.suctionAt or now - self.suctionAt >= compiled.Suction.duration * 0.75 then self.suctionAt = now end
end

function Vacuum:NozzlePosition(fallback)
	if self.rootCF and self.data and self.data.enabled then
		local pivot = vector(Clips.pivots.nozzle)
		local pose = self.nozzlePose
		return (self.rootCF * CFrame.new(pivot) * pose.cf):PointToWorldSpace(multiply(Config.NozzleOffset - pivot, pose.scale))
	end
	if fallback and fallback.targetX and fallback.targetY and fallback.targetZ then
		return Vector3.new(fallback.targetX, fallback.targetY, fallback.targetZ)
	end
	return nil
end

function Vacuum:PickupCue(now)
	if not self.data or not self.data.enabled or now-(self.lastPickupCue or -10)<Feel.Egg.SoundGap then return end
	self.lastPickupCue=now
	self:PulseSuction(now)
	if self.anchor then
		self.app.audio:Play("EggPickup",1.08,{volume=Feel.Egg.RoverVolume,parent=self.anchor,
			maxDuration=Feel.Egg.SoundTail,voiceKey="VacuumPickup",cooldown=Feel.Egg.SoundGap,maxVoices=Feel.Egg.MaxVoices})
		if self.spark and not self.app.reducedMotion then self.spark:Emit(2) end
	end
end

function Vacuum:Pickup(receipt, now)
	-- Called only for a server-confirmed rover receipt, never a local touch.
	if not self.data or not self.data.enabled then return end
	if now - self.lastEffect > 0.65 then self.pickupTotal = 0 end
	self.pickupTotal += receipt.count or 1
	if self.popup and (not self.depositUntil or now >= self.depositUntil) then
		self.label.Text = "+" .. Theme.Money(self.pickupTotal)
		self.popup.Enabled, self.popupUntil = true, now + 0.7
	end
	self.lastEffect = now
end

function Vacuum:Deposit(receipt, now)
	if receipt.id and receipt.id == self.lastDepositId then return end
	self.lastDepositId = receipt.id
	-- A first snapshot can already contain the payout. Otherwise the state entry
	-- or serial change started this clip, so cash feedback must not restart it.
	if self.data then self:StartUnload(self.data.unloadSerial, now) end
	if self.popup then
		self.label.Text = if receipt.queued then Theme.Money(receipt.count).." eggs deposited" else "+$" .. Theme.Money(receipt.value)
		self.popup.Enabled, self.popupUntil, self.depositUntil = true, now + 1.1, now + 1.1
	end
	-- Automatic deliveries stay local to the rover; no player cash burst or sound.
end

function Vacuum:ApplyPose()
	if not self.rootCF then return end
	for name, entry in self.parts do
		local restCF, part = entry.cf, entry.part
		local group = GROUPS[name]
		if group then
			local pivot = vector(Clips.pivots[group])
			local pose = if group == "body" then self.bodyPose else self.nozzlePose
			part.CFrame = self.rootCF * CFrame.new(pivot) * pose.cf
				* CFrame.new(multiply(restCF.Position - pivot, pose.scale)) * restCF.Rotation
			part.Size = multiply(entry.size, pose.scale)
		elseif name == "WheelLeft" or name == "WheelRight" then
			local angle = if name == "WheelLeft" then self.wheelLeft else self.wheelRight
			part.CFrame = self.rootCF * CFrame.new(restCF.Position) * CFrame.Angles(angle, 0, 0) * restCF.Rotation
			part.Size = entry.size
		else
			part.CFrame = self.rootCF * restCF
		end
	end
end

function Vacuum:Step(now)
	local dt = math.clamp(now - (self.lastAt or now), 0, 0.1)
	self.lastAt = now
	if not self.data or not self.rootCF or not self.targetCF then return end
	self:EnsureModel(now)
	local old = self.rootCF
	-- Render one snapshot behind. Linear interpolation keeps long rows at a
	-- steady speed rather than accelerating toward each new network packet.
	local alpha = math.clamp((now - self.receivedAt) / self.blendSeconds, 0, 1)
	self.rootCF = self.fromCF:Lerp(self.targetCF, alpha)
	local position = self.rootCF.Position
	local travel = position - old.Position
	local distance = travel:Dot(old.LookVector)
	local speed = if dt > 0 then travel.Magnitude / dt else 0
	local a, b = old.LookVector, self.rootCF.LookVector
	local turn = math.atan2(a.X * b.Z - a.Z * b.X, a:Dot(b))
	-- Differential travel includes turning on the spot; tires never spin on a timer.
	local left = self.parts.WheelLeft
	local right = self.parts.WheelRight
	local halfAxle = if left and right then math.abs(right.cf.X - left.cf.X) * 0.5 else Config.ModelScale * 0.378
	local wheelRadius = Config.WheelRadius * Config.WheelDiameterScale
	self.wheelLeft = (self.wheelLeft - (distance + turn * halfAxle) / wheelRadius) % (math.pi * 2)
	self.wheelRight = (self.wheelRight - (distance - turn * halfAxle) / wheelRadius) % (math.pi * 2)
	local moving = if speed > MOTION.MovingThreshold then 1 else 0
	self.moveWeight += (moving - self.moveWeight) * (1 - math.exp(-MOTION.PoseResponse * dt))
	self.moveTime += dt * math.clamp(speed / MOTION.WalkCycleSpeed, 0, 2)
	local body, nozzle = IDENTITY, IDENTITY
	if not self.app.reducedMotion then
		local idleBody, idleNozzle = sample("Idle", now - self.startedAt)
		local moveBody, moveNozzle = sample("Move", self.moveTime)
		body, nozzle = lerpPose(idleBody, moveBody, self.moveWeight), lerpPose(idleNozzle, moveNozzle, self.moveWeight)
		local unloadDuration = math.max(Config.UnloadSeconds, 0.01)
		local event = if self.unloadAt and now - self.unloadAt < unloadDuration then "Unload"
			elseif self.suctionAt and now - self.suctionAt < compiled.Suction.duration then "Suction" else nil
		if event then
			local elapsed = now - (if event == "Unload" then self.unloadAt else self.suctionAt)
			-- Fit the authored one-second nod to the server's configured dock wait.
			if event == "Unload" then elapsed *= compiled.Unload.duration / unloadDuration end
			local eventBody, eventNozzle = sample(event, elapsed)
			body = {cf = body.cf * eventBody.cf, scale = multiply(body.scale, eventBody.scale)}
			nozzle = {cf = nozzle.cf * eventNozzle.cf, scale = multiply(nozzle.scale, eventNozzle.scale)}
		end
	end
	local blend = if self.app.reducedMotion then 1 else 1 - math.exp(-MOTION.PoseResponse * dt)
	self.bodyPose, self.nozzlePose = lerpPose(self.bodyPose, body, blend), lerpPose(self.nozzlePose, nozzle, blend)
	self:ApplyPose()
	if self.anchor then self.anchor.Position = self:NozzlePosition() end
	if self.popup and self.popupUntil then
		local remaining = self.popupUntil - now
		self.popup.Enabled = remaining > 0
		self.label.TextTransparency = math.clamp(1 - remaining / 0.2, 0, 1)
		self.label.TextOutline.Transparency = self.label.TextTransparency
	end
end

function Vacuum:Destroy()
	self:Clear()
end

return Vacuum
