--!strict
-- Artist effects retain their original host part, attachment graph and styling.
-- DuckAnimator owns this object's Step/Destroy; gameplay remains server-owned.
local Presets = require(game:GetService("ReplicatedStorage").PetRoll.Shared.ChickenVFXPresets)
local RareVFX = {}
RareVFX.__index = RareVFX

local function scaleSequence(value: NumberSequence, ratio: number): NumberSequence
	local keys = {}
	for _, key in value.Keypoints do
		keys[#keys + 1] = NumberSequenceKeypoint.new(key.Time, key.Value * ratio, key.Envelope * ratio)
	end
	return NumberSequence.new(keys)
end

local function scaled(class: string, name: string, value, ratio: number)
	if class == "Attachment" and name == "CFrame" then
		return CFrame.new(value.Position * ratio) * value.Rotation
	elseif class == "ParticleEmitter" then
		if name == "Size" then return scaleSequence(value, ratio)
		elseif name == "Speed" then return NumberRange.new(value.Min * ratio, value.Max * ratio)
		elseif name == "Acceleration" or name == "ZOffset" then return value * ratio end
	elseif class == "Beam" and (name == "Width0" or name == "Width1" or name == "CurveSize0"
		or name == "CurveSize1" or name == "TextureLength" or name == "ZOffset") then
		return value * ratio
	end
	return value
end

function RareVFX.new(model: Model)
	if Presets.Enabled == false then return nil end
	local preset = Presets.Species[model:GetAttribute("Species")]
	if not preset then return nil end
	return setmetatable({model = model, preset = preset, instances = {}, hosts = {}, visible = false, nextUpdate = 0}, RareVFX)
end

function RareVFX:_attach(root: BasePart): boolean
	local hosts = {}
	for _, node in self.preset.nodes do
		if node.part then
			local host = self.model:FindFirstChild(node.part)
			if not host or not host:IsA("BasePart") then return false end
			hosts[node.part] = host
		end
	end
	self.hosts, self.root = hosts, root
	-- Make every endpoint first; numeric IDs preserve identically named attachments.
	for i, node in self.preset.nodes do
		local item = Instance.new(node.class)
		item.Name = node.name
		item:SetAttribute("ChickenArtistVFX", true)
		item:SetAttribute("ArtistNodeId", i)
		if not item:IsA("Attachment") then item.Enabled = false end
		self.instances[i] = item
		for _, property in node.properties do item[property[1]] = property[2] end
	end
	for i, node in self.preset.nodes do
		local item = self.instances[i]
		if node.attachment0 then
			item.Attachment0, item.Attachment1 = self.instances[node.attachment0], self.instances[node.attachment1]
		end
		item.Parent = if node.parent then self.instances[node.parent] else hosts[node.part]
	end
	return true
end

function RareVFX:_scale(ratio: number)
	self.ratio = ratio
	for i, node in self.preset.nodes do
		local item = self.instances[i]
		for _, property in node.properties do
			local name, original = property[1], property[2]
			local value = scaled(node.class, name, original, ratio)
			if value ~= original or ratio == 1 then item[name] = value end
		end
	end
end

function RareVFX:Step(now: number, reduced: boolean, camera: Camera?)
	if now < self.nextUpdate then return end
	self.nextUpdate = now + 1 / 20
	local model = self.model
	local root = model.PrimaryPart
	if not root then self:Destroy(); return end
	local valid = self.root == root
	for name, host in self.hosts do
		if not host:IsDescendantOf(model) or model:FindFirstChild(name) ~= host then valid = false end
	end
	if not valid then
		self:Destroy()
		if not self:_attach(root) then return end
	end
	local ratio = (model:GetAttribute("Size") or self.preset.referenceSize) / self.preset.referenceSize
	if ratio ~= self.ratio then self:_scale(ratio) end
	local visible = not reduced and not model:GetAttribute("ReducedMotion")
		and not model:GetAttribute("Defeated") and not model:GetAttribute("PresentationHidden")
		and root.LocalTransparencyModifier < 0.5
		and camera ~= nil and (camera.CFrame.Position - root.Position).Magnitude <= Presets.CullDistance
	if visible ~= self.visible then
		for i, node in self.preset.nodes do
			local item = self.instances[i]
			if not item:IsA("Attachment") then
				item.Enabled = visible and node.enabled == true
				if not visible and item:IsA("ParticleEmitter") then item:Clear() end
			end
		end
		self.visible = visible
	end
end

function RareVFX:Destroy()
	for _, item in self.instances do item:Destroy() end
	table.clear(self.instances)
	table.clear(self.hosts)
	self.root, self.ratio, self.visible = nil, nil, false
end

return RareVFX
