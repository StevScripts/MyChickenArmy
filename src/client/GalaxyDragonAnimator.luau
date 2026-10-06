--!strict
-- The dragon stays airborne. Native tracks blend its full-body attack back
-- into the authored flight pose; combat timing and damage remain server-owned.
local GalaxyDragonAnimator = {}
GalaxyDragonAnimator.__index = GalaxyDragonAnimator

local ENTRY_FADE = 0.12
local RECOVERY_FADE = 0.14
local DEFAULT_ATTACK_SECONDS = 1.4

local function numberAttribute(model: Model, name: string, fallback: number): number
	local value = model:GetAttribute(name)
	return if typeof(value) == "number" and value == value and math.abs(value) < math.huge then value else fallback
end

function GalaxyDragonAnimator.new(model: Model)
	return setmetatable({model = model, tracks = {}, connections = {}, ready = false,
		destroyed = false, sleeping = false, retryAt = 0, loadedAt = 0,
		serial = model:GetAttribute("AttackSerial"), localAttack = model:GetAttribute("LocalAttackAt"),
		pendingAttackAt = nil, attackAt = nil, recovering = false, warned = false}, GalaxyDragonAnimator)
end

function GalaxyDragonAnimator:_clearTracks()
	self.attackAt, self.recovering, self.ready = nil, false, false
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	for _, track in self.tracks do track:Stop(0); track:Destroy() end
	table.clear(self.tracks)
	self.animator, self.folder, self.flightAnimation, self.attackAnimation = nil, nil, nil, nil
end

function GalaxyDragonAnimator:_finishAttack()
	if self.destroyed or not self.attackAt or self.sleeping then return end
	self.attackAt = nil
	local flight = self.tracks.FlightLoop
	if not flight.IsPlaying then flight:Play(ENTRY_FADE, 1, 0) end
	if not self.recovering then flight.TimePosition = 0 end
	self.recovering = false
	flight:AdjustSpeed(1)
end

function GalaxyDragonAnimator:_load(now: number): boolean
	local model = self.model
	local controller = model:FindFirstChildWhichIsA("Humanoid") or model:FindFirstChildWhichIsA("AnimationController")
	local animator = controller and controller:FindFirstChildWhichIsA("Animator")
	local folder = model:FindFirstChild("RuntimeAnimations")
	local flight = folder and folder:FindFirstChild("FlightLoop")
	local attack = folder and folder:FindFirstChild("Attack")
	if not animator or not flight or not flight:IsA("Animation") or flight.AnimationId == ""
		or not attack or not attack:IsA("Animation") or attack.AnimationId == "" then return false end
	-- Store each track immediately so a partial load failure is cleaned up too.
	self.tracks.FlightLoop = animator:LoadAnimation(flight)
	self.tracks.Attack = animator:LoadAnimation(attack)
	self.tracks.FlightLoop.Priority = Enum.AnimationPriority.Movement
	self.tracks.FlightLoop.Looped = true
	self.tracks.Attack.Priority = Enum.AnimationPriority.Action
	self.tracks.Attack.Looped = false
	table.insert(self.connections, self.tracks.Attack.Stopped:Connect(function()
		-- A deferred stop from the previous attack must not finish a new play.
		local track = self.tracks.Attack
		if not self.destroyed and track and not track.IsPlaying then self:_finishAttack() end
	end))
	self.animator, self.folder, self.flightAnimation, self.attackAnimation = animator, folder, flight, attack
	self.flightId, self.attackId = flight.AnimationId, attack.AnimationId
	self.ready, self.loadedAt = true, now
	return true
end

function GalaxyDragonAnimator:_events(now: number, allow: boolean, duration: number)
	local model = self.model
	local serial = model:GetAttribute("AttackSerial")
	if serial ~= self.serial then
		self.serial, self.pendingAttackAt = serial, nil
		if serial ~= nil then
			local serverNow = workspace:GetServerTimeNow()
			local age = math.max(0, serverNow - numberAttribute(model, "AttackStartedAt", serverNow))
			if allow and age < duration then self.pendingAttackAt = now - age end
		end
	end
	local localAttack = model:GetAttribute("LocalAttackAt")
	if localAttack ~= self.localAttack then
		self.localAttack = localAttack
		if allow and serial == nil and typeof(localAttack) == "number" then
			local age = math.max(0, now - localAttack)
			if age < duration then self.pendingAttackAt = now - age end
		end
	end
	-- Consume hidden/reduced-motion events now; never replay them on reappearance.
	if not allow then self.pendingAttackAt = nil end
end

function GalaxyDragonAnimator:Step(now: number, reduced: boolean?)
	if self.destroyed then return end
	local model = self.model
	local body = model:FindFirstChild("DragonChickenMesh") or model:FindFirstChild("Body")
	local root = model.PrimaryPart
	local hidden = model:GetAttribute("PresentationHidden") == true
		or (root ~= nil and root.LocalTransparencyModifier >= 1)
		or (body ~= nil and body:IsA("BasePart") and body.LocalTransparencyModifier >= 1)
	local sleeping = hidden or reduced == true or model:GetAttribute("Defeated") == true
	local duration = math.max(0.1, numberAttribute(model, "AttackAnimationSeconds", DEFAULT_ATTACK_SECONDS))
	self:_events(now, not sleeping, duration)
	if sleeping then
		if not self.sleeping then
			self.sleeping, self.attackAt, self.recovering = true, nil, false
			for _, track in self.tracks do track:Stop(ENTRY_FADE) end
		end
		return
	end
	self.sleeping = false
	if self.ready and (not self.animator:IsDescendantOf(model) or self.folder.Parent ~= model
		or self.flightAnimation.Parent ~= self.folder or self.attackAnimation.Parent ~= self.folder
		or self.flightAnimation.AnimationId ~= self.flightId or self.attackAnimation.AnimationId ~= self.attackId) then
		self:_clearTracks()
	end
	if not self.ready then
		if now < self.retryAt then return end
		self.retryAt = now + 2
		local ok, result = pcall(function() return self:_load(now) end)
		if not ok then
			self:_clearTracks()
			if not self.warned then warn("Galaxy dragon animation: " .. tostring(result)); self.warned = true end
			return
		end
		if not result then return end
	end
	local flight, attack = self.tracks.FlightLoop, self.tracks.Attack
	-- LoadAnimation returns before its asset is ready. Keep the event's original
	-- age while loading, and retry failed assets without accumulating tracks.
	if flight.Length <= 0 or attack.Length <= 0 then
		if now - self.loadedAt > 10 then
			self:_clearTracks()
			self.retryAt = now + 5
			if not self.warned then warn("Galaxy dragon animation assets have not loaded"); self.warned = true end
		end
		return
	end
	if not flight.IsPlaying then flight:Play(ENTRY_FADE, 1, 1) end
	if self.pendingAttackAt then
		local started = self.pendingAttackAt
		self.pendingAttackAt = nil
		local age = now - started
		if age >= 0 and age < duration then
			self.attackAt, self.recovering = started, false
			flight:AdjustSpeed(1)
			attack:Play(ENTRY_FADE, 1, 1)
			attack.TimePosition = math.min(age, attack.Length)
		end
	end
	if self.attackAt then
		local age = now - self.attackAt
		if age >= duration - RECOVERY_FADE and not self.recovering then
			-- The attack finishes at flight frame zero. Hold that exact pose below
			-- the Action track while native weight blending completes the recovery.
			self.recovering = true
			flight.TimePosition = 0
			flight:AdjustSpeed(0)
			attack:AdjustWeight(0, math.max(0.01, duration - age))
		end
		if age >= duration then
			self:_finishAttack()
			attack:Stop(0.04)
		end
	end
end

function GalaxyDragonAnimator:Destroy()
	if self.destroyed then return end
	self.destroyed, self.pendingAttackAt = true, nil
	self:_clearTracks()
end

return GalaxyDragonAnimator
