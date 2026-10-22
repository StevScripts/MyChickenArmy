--!strict
-- October 21 Auto Vacuum, local presentation only (docs/team/AUTO_VACUUM.md). EggRover
-- owns the route, claims, tank and Coins; this draws the Studio robot
-- (Assets.EggVacuum, Blender Idle/Move/Suction/Unload poses in VacuumClips), its tank
-- meter, the eggs it pulls in and its sales on the pad. Restored from the retired Auto
-- Collect robot (archive/robot-vacuum-20261020/VacuumController.luau).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.PetRoll.Shared
local Config = require(Shared.AutoVacuumConfig)
local Clips = require(Shared.VacuumClips)
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
local SOUND = {PickupGap = 0.12, PickupVolume = 0.35, PickupPitch = 1.08}
local METER = {Height = 3.2, Width = 5, Tall = 1.5, MaxDistance = 80}
local FULL_RED = Color3.fromRGB(255, 92, 82)
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
		bodyPose = IDENTITY, nozzlePose = IDENTITY, startedAt = os.clock()}, Vacuum)
end

function Vacuum:Clear()
	if self.model then self.model:Destroy() end
	if self.anchor then self.anchor:Destroy() end
	self.model, self.anchor, self.spark, self.meter, self.meterFill, self.meterText = nil, nil, nil, nil, nil, nil
	table.clear(self.parts)
	self.rootCF, self.targetCF, self.data, self.id = nil, nil, nil, nil
	self.fromCF, self.receivedAt, self.blendSeconds = nil, nil, nil
	self.suctionSerial, self.unloadSerial, self.suctionAt, self.unloadAt = nil, nil, nil, nil
	self.unloadCycle, self.lastDepositId, self.wasFull = nil, nil, nil
	self.bodyPose, self.nozzlePose = IDENTITY, IDENTITY
	self.wheelLeft, self.wheelRight, self.moveTime, self.moveWeight = 0, 0, 0, 0
	self.lastAt = nil
end

-- "12 / 40" over the robot: gold while it has room, red "Full" while it drives to the pad.
function Vacuum:BuildMeter(body: BasePart)
	local meter = Instance.new("BillboardGui")
	meter.Name, meter.Adornee, meter.Size = "AutoVacuumTank", body, UDim2.fromScale(METER.Width, METER.Tall)
	meter.StudsOffsetWorldSpace, meter.MaxDistance, meter.AlwaysOnTop = Vector3.new(0, METER.Height, 0), METER.MaxDistance, false
	meter.LightInfluence = 0
	local track = Instance.new("Frame")
	track.Name, track.Size, track.Position = "Track", UDim2.fromScale(1, 0.34), UDim2.fromScale(0, 0.66)
	track.BackgroundColor3, track.BackgroundTransparency, track.BorderSizePixel = Color3.fromRGB(30, 24, 18), 0.2, 0
	Instance.new("UICorner", track).CornerRadius = UDim.new(0.5, 0)
	track.Parent = meter
	local fill = Instance.new("Frame")
	fill.Name, fill.Size, fill.BackgroundColor3, fill.BorderSizePixel = "Fill", UDim2.fromScale(0, 1), Theme.Arcade.gold, 0
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)
	fill.Parent = track
	local text = Theme.Label(meter, "Count", "", 20, Theme.Arcade.gold)
	text.Size, text.TextXAlignment, text.TextScaled = UDim2.fromScale(1, 0.62), Enum.TextXAlignment.Center, true
	meter.Parent = self.folder
	self.meter, self.meterFill, self.meterText = meter, fill, text
end

function Vacuum:RenderMeter(now)
	local data = self.data
	if not self.meter or not data then return end
	local count, capacity = tonumber(data.count) or 0, tonumber(data.capacity) or 0
	local full = capacity > 0 and count >= capacity
	local fraction = if capacity > 0 then math.clamp(count / capacity, 0, 1) else 0
	self.meterText.Text = if full then "Full!" else Theme.Number(count) .. " / " .. Theme.Number(capacity)
	self.meterText.TextColor3 = if full then FULL_RED else Theme.Arcade.gold
	self.meterFill.BackgroundColor3 = if full then FULL_RED else Theme.Arcade.gold
	Theme.Motion:Progress(self.meterFill, fraction, if self.app.reducedMotion then 0 else 0.2, false)
	if full and not self.wasFull and self.rootCF then
		Theme.Motion:Punch(self.meterText, 1.2, 0.3)
		self.app.audio:PlayAt("VacuumFull", self.rootCF.Position, 1, {noFallback = true, volume = 0.5})
	end
	self.wasFull = full
end

function Vacuum:EnsureModel(now)
	if self.model then return true end
	if now < self.retryAt then return false end
	self.retryAt = now + MOTION.TemplateRetrySeconds
	local assets = ReplicatedStorage.PetRoll:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild(Config.TemplateName)
	if not template or not template:IsA("Model") then
		if not self.warned then
			warn("Auto Vacuum visuals are waiting for ReplicatedStorage.PetRoll.Assets." .. Config.TemplateName)
			self.warned = true
		end
		return false
	end
	local model = template:Clone()
	model.Name = "AutoVacuumLocal"
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
	-- Pose before parenting, so the template never flashes at the world origin.
	self.model = model
	self:ApplyPose()
	model.Parent = self.folder
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.Transparency = "AutoVacuumNozzle", Vector3.one * 0.1, 1
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.CastShadow = true, false, false, false, false
	anchor.Position = self:NozzlePosition() or self.rootCF.Position
	anchor.Parent = self.folder
	self.anchor = anchor
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor
	local spark = Instance.new("ParticleEmitter")
	spark.Name, spark.Texture, spark.Rate = "AutoVacuumSpark", "rbxasset://textures/particles/sparkles_main.dds", 0
	spark.Color = ColorSequence.new(Color3.fromRGB(255, 226, 92), Color3.new(1, 1, 1))
	spark.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0)})
	spark.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1)})
	spark.Lifetime, spark.Speed, spark.SpreadAngle = NumberRange.new(0.12, 0.22), NumberRange.new(1, 2), Vector2.new(180, 180)
	spark.LightEmission, spark.Parent = 0.5, attachment
	self.spark = spark
	local body = self.parts.Body
	self:BuildMeter(if body then body.part else anchor)
	self:RenderMeter(now)
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
	-- The server counts a delivery when it finishes; while unloading, serial+1 is this one.
	if data.state == "Unloading" then
		self:StartUnload((data.unloadSerial or 0) + 1, now)
	elseif previous and self.unloadSerial ~= data.unloadSerial then
		self:StartUnload(data.unloadSerial, now)
	end
	self.suctionSerial, self.unloadSerial = data.suctionSerial, data.unloadSerial
	if self:EnsureModel(now) then self:RenderMeter(now) end
end

function Vacuum:StartUnload(cycle, now)
	if type(cycle) ~= "number" or cycle <= (self.unloadCycle or 0) then return end
	self.unloadCycle, self.unloadAt = cycle, now
end

function Vacuum:PulseSuction(now)
	-- Finish most of the squeeze before starting another.
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

-- An egg reached the nozzle: a soft positioned tick and a few sparks (no "+N" over the
-- player: the robot's eggs pay when it sells them).
function Vacuum:PickupCue(now)
	if not self.data or not self.data.enabled or now - (self.lastPickupCue or -10) < SOUND.PickupGap then return end
	self.lastPickupCue = now
	self:PulseSuction(now)
	if self.anchor then
		self.app.audio:PlayAt("EggPickup", self.anchor.Position, SOUND.PickupPitch,
			{volume = SOUND.PickupVolume, voiceKey = "AutoVacuumPickup", cooldown = SOUND.PickupGap, maxVoices = 2})
		if self.spark and not self.app.reducedMotion then self.spark:Emit(2) end
	end
end

-- The robot sold its tank on the pad: the Coins float up from it with a gold burst.
function Vacuum:Deposit(receipt, now)
	if receipt.id and receipt.id == self.lastDepositId then return end
	self.lastDepositId = receipt.id
	if self.data then self:StartUnload(self.data.unloadSerial, now) end
	local feel = self.app.worldFeel
	local at = if self.rootCF then self.rootCF.Position
		elseif receipt.targetX then Vector3.new(receipt.targetX, receipt.targetY, receipt.targetZ) else nil
	if not at then return end
	if feel then
		local text = if receipt.queued then Theme.Number(receipt.count) .. " eggs" else "+" .. Theme.Number(receipt.value)
		feel:Text(at + Vector3.new(0, 3, 0), text, {coin = not receipt.queued, size = 30, range = 90})
		feel:Burst(at + Vector3.new(0, 1.5, 0), {color = Theme.Arcade.gold, count = 12, size = 0.4, range = 90})
		feel:Sound("EggDeposit", at, 1.05, {volume = 0.6})
	end
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
	-- Render one snapshot behind at a steady speed between packets.
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
			-- Fit the authored one-second nod to the server's dock wait.
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
end

function Vacuum:Destroy()
	self:Clear()
end

return Vacuum
