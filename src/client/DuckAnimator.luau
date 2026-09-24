--!strict
-- One client animator for every streamed duck rig. It only poses joints;
-- Humanoid physics and authoritative positions remain on the server.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ChickenClipPlayer = require(script.Parent.ChickenClipPlayer)
local RareChickenVFX = require(script.Parent.RareChickenVFX)
local SpecialChickenVFX = require(script.Parent.SpecialChickenVFX)
local GlitchEditableMesh = require(script.Parent.GlitchEditableMesh)
local VoxelChickenAnimator = require(script.Parent.VoxelChickenAnimator)
local KingVisual = require(game:GetService("ReplicatedStorage").PetRoll.Shared.KingVisual)
local DuckAnimator = {}
DuckAnimator.__index = DuckAnimator
local JOINTS = {"Root", "Neck", "WingLeft", "WingRight", "FootLeft", "FootRight"}

local function phaseFor(name: string): number
	local phase = 0
	for i = 1, #name do phase += string.byte(name, i) * 0.071 end
	return phase % (math.pi * 2)
end

function DuckAnimator.new()
	local self = setmetatable({records = {}, connections = {}, reducedMotion = false, destroyed = false}, DuckAnimator)
	local function discover(item: Instance)
		if item:IsA("Model") and (item:GetAttribute("DuckRig") == true or item:GetAttribute("SkinnedChicken") == true) and not self.records[item] then
			self.records[item] = {model = item, root = nil, joints = {}, phase = phaseFor(item.Name),
				lastPose = 0, lastScan = -1, attackSerial = item:GetAttribute("AttackSerial") or 0,
				attackAt = -10, sleeping = false, fx = if item:GetAttribute("ChickenVisualV3") then SpecialChickenVFX.new(item) else RareChickenVFX.new(item),
				glitch = GlitchEditableMesh.new(item),
				blender = if item:GetAttribute("ChickenVisualV3") then VoxelChickenAnimator.new(item) elseif item:GetAttribute("SkinnedChicken") then ChickenClipPlayer.new(item) else nil}
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
			if record and record.blender then record.blender:Destroy() end
			if record and record.fx then record.fx:Destroy() end
			if record and record.glitch then record.glitch:Destroy() end
			self.records[item] = nil
		end
	end))
	table.insert(self.connections, RunService.RenderStepped:Connect(function(dt) self:_step(dt) end))
	return self
end

function DuckAnimator:SetReducedMotion(reduced: boolean)
	self.reducedMotion = reduced == true
end

function DuckAnimator:_step(dt: number)
	local now = os.clock()
	local camera = workspace.CurrentCamera
	for model, record in self.records do
		if not model:IsDescendantOf(workspace) then
			if record.blender then record.blender:Destroy() end
			if record.fx then record.fx:Destroy() end
			if record.glitch then record.glitch:Destroy() end
			self.records[model] = nil continue
		end
		if model:GetAttribute("ChickenKing") then KingVisual.Update(model) end
		if record.fx then record.fx:Step(now, self.reducedMotion, camera) end
		if record.glitch then record.glitch:Step(now, self.reducedMotion, camera) end
		if record.blender then
			record.blender:Step(now, self.reducedMotion or model:GetAttribute("ReducedMotion") == true)
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
		local hidden = model:GetAttribute("PresentationHidden") == true or root.LocalTransparencyModifier >= 1
		local reduced = self.reducedMotion or model:GetAttribute("ReducedMotion") == true
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
		local serial = model:GetAttribute("AttackSerial") or 0
		if serial ~= record.attackSerial then
			local started=model:GetAttribute("AttackStartedAt")
			record.attackSerial,record.attackAt=serial,now-(if started then math.max(0,workspace:GetServerTimeNow()-started) else 0)
		end
		local attackAge = now - record.attackAt
		local attack = if attackAge>=0 and attackAge<0.6 and not model:GetAttribute("Defeated") then math.sin(attackAge/0.6*math.pi) else 0
		if reduced then walk, attack = 0, 0 end
		local wave = math.sin(record.phase)
		local size = model:GetAttribute("Size") or 2.5
		local bob = if reduced then 0 else (math.abs(wave) * walk * 0.024 + math.sin(record.phase * 0.5) * 0.004) * size
		local roll = if reduced then 0 else wave * (0.012 + walk * 0.065)
		local joints = record.joints
		if joints.Root then joints.Root.Transform = CFrame.new(0, bob, -attack * size * 0.06) * CFrame.Angles(-attack * 0.11, 0, roll) end
		if joints.Neck then joints.Neck.Transform = CFrame.Angles(-attack * 0.32, 0, -roll * 0.4) end
		if joints.WingLeft then joints.WingLeft.Transform = CFrame.Angles(wave * walk * 0.08, 0, -walk * 0.07 - attack * 0.24) end
		if joints.WingRight then joints.WingRight.Transform = CFrame.Angles(-wave * walk * 0.08, 0, walk * 0.07 + attack * 0.24) end
		if joints.FootLeft then joints.FootLeft.Transform = CFrame.new(0, math.max(wave, 0) * walk * size * 0.035, -wave * walk * size * 0.035) * CFrame.Angles(wave * walk * 0.24, 0, 0) end
		if joints.FootRight then joints.FootRight.Transform = CFrame.new(0, math.max(-wave, 0) * walk * size * 0.035, wave * walk * size * 0.035) * CFrame.Angles(-wave * walk * 0.24, 0, 0) end
	end
end

function DuckAnimator:Destroy()
	if self.destroyed then return end
	self.destroyed = true
	for _, connection in self.connections do connection:Disconnect() end
	for _, record in self.records do
		if record.blender then record.blender:Destroy() end
		if record.fx then record.fx:Destroy() end
			if record.glitch then record.glitch:Destroy() end
		for _, joint in record.joints do if joint.Parent then joint.Transform = CFrame.identity end end
	end
	table.clear(self.connections)
	table.clear(self.records)
end

return DuckAnimator
