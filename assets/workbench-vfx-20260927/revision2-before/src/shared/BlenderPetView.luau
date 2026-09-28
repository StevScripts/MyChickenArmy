--!strict
-- Imported Blender meshes and their physical shell. PetView owns labels;
-- PetActor owns movement; ChickenClipPlayer owns animation playback.
local CollectionService = game:GetService("CollectionService")
local Catalog = require(script.Parent.PetCatalog)
local Rules = require(script.Parent.Rules)
local Appearances = require(script.Parent.ChickenAppearanceAssets)
local BlenderPetView = {}
local previews = {}

function BlenderPetView.Create(parent, id, species, stars, foot, physical)
	local assets = script.Parent.Parent:FindFirstChild("ChickenAssets")
	local template = assets and assets:FindFirstChild(species)
	if not template then return nil end
	local stats = Rules.Stats(species, stars)
	local model = template:Clone()
	model.Name = id
	local scale = stats.size / 2.25 * 1.15
	model:ScaleTo(template:GetScale() * scale)
	local body = model:FindFirstChild("Body")
	local art = Appearances.Species[species]
	local v3 = body and art and body:FindFirstChild(art.bonePrefix .. "Root") ~= nil
	local boneRoot = body and body:FindFirstChild(if v3 then art.bonePrefix .. "Root" else "root")
	if not body or not boneRoot then model:Destroy() return nil end
	-- Keep the mesh's feet on the floor, but lift the physical shell into its
	-- body. HipHeight then clears low yard lips without jumping. Previews retain
	-- their original pivot; the mesh/joint offsets below preserve the same art pose.
	local offset = stats.size * (if physical then 0.75 else 0.45)
	-- Expansion imports have a foot-level pivot and several separately skinned
	-- surfaces. Keep their authored relative poses and compiled PBR materials.
	if art and art.pivotRig then
		model:PivotTo(CFrame.new(foot) * (if physical then CFrame.Angles(0, math.pi, 0) else CFrame.identity))
	end
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(0.72, 0.72, 0.85) * stats.size
	root.CFrame = CFrame.new(foot + Vector3.new(0, offset, 0))
	root.Transparency = 1
	root.Anchored = not physical
	root.CanCollide, root.CanTouch, root.CanQuery = physical, false, physical
	root.RootPriority = 127
	root.CustomPhysicalProperties = PhysicalProperties.new(1, 0.3, 0, 1, 0)
	root.Parent = model
	model.PrimaryPart = root
	-- The importer preserves Blender-local child-bone poses and converts the
	-- root to Roblox -Z forward. Its rest position also records the mesh origin.
	local orientation = if physical then CFrame.identity else CFrame.Angles(0, math.pi, 0)
	if not (art and art.pivotRig) then
		body.CFrame = root.CFrame * orientation * CFrame.new(-boneRoot.CFrame.Position - Vector3.new(0, offset, 0))
	end
	local minX,minY,minZ,maxX,maxY,maxZ = math.huge,math.huge,math.huge,-math.huge,-math.huge,-math.huge
	for _, surface in model:GetDescendants() do
		if surface:IsA("BasePart") and surface ~= root then
			surface.Anchored, surface.Massless = false, true
			surface.CanCollide, surface.CanTouch, surface.CanQuery = false, false, false
			local joint = Instance.new("Motor6D")
			joint.Name = if surface == body then "MeshJoint" else "SurfaceJoint_" .. surface.Name
			joint.Part0, joint.Part1 = root, surface
			joint.C0 = root.CFrame:ToObjectSpace(surface.CFrame)
			joint.Parent = root
			if surface.Transparency < 1 then
				for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
					local point = surface.CFrame:PointToWorldSpace(surface.Size * Vector3.new(x,y,z) * 0.5)
					minX,minY,minZ = math.min(minX,point.X),math.min(minY,point.Y),math.min(minZ,point.Z)
					maxX,maxY,maxZ = math.max(maxX,point.X),math.max(maxY,point.Y),math.max(maxZ,point.Z)
				end end end
			end
		end
	end
	-- Effects already present in the imported art are controlled by the existing
	-- client visual lifecycle, including hiding, defeat and reduced motion.
	for _, effect in model:GetDescendants() do
		if effect:IsA("ParticleEmitter") or effect:IsA("Beam") or effect:IsA("Trail") then
			effect:SetAttribute("ImportedEffectEnabled", effect.Enabled)
			effect.Enabled = false
		end
	end
	local animationOwner
	if physical then
		local humanoid = Instance.new("Humanoid")
		humanoid.RequiresNeck = false
		humanoid.BreakJointsOnDeath = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.MaxHealth, humanoid.Health = 100, 100
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight = 0, 0, 0
		humanoid.AutoJumpEnabled = false
		humanoid.HipHeight = offset - root.Size.Y / 2
		humanoid.Parent = model
		for _, state in {Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming,
			Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Seated} do humanoid:SetStateEnabled(state, false) end
		animationOwner = humanoid
	else
		animationOwner = Instance.new("AnimationController")
		animationOwner.Parent = model
		previews[model] = {facing = Vector3.zAxis, foot = foot, at = os.clock()}
		model.Destroying:Once(function() previews[model] = nil end)
	end
	Instance.new("Animator", animationOwner)
	model:SetAttribute("Species", species)
	model:SetAttribute("Stars", stars)
	model:SetAttribute("Size", stats.size)
	model:SetAttribute("ClipScale", scale)
	model:SetAttribute("SkinnedChicken", true)
	model:SetAttribute("ChickenVisualV3", v3 == true)
	if v3 then
		model:SetAttribute("Appearance", art.name)
		model:SetAttribute("BonePrefix", art.bonePrefix)
		model:SetAttribute("ClipUnitScale", art.unitScale)
		-- Galaxy's face and feathers share one mesh. Translucency makes its
		-- overlapping surfaces sort over the eyes/beak; keep the mesh opaque.
		if art.name == "Galaxy" then body.Transparency = 0 end
	end
	model:SetAttribute("VisualStyle", if v3 then "VoxelChickenV3" else "BlenderStudChicken")
	model:SetAttribute("FootOffset", offset)
	model:SetAttribute("AttackSerial", 0)
	model:SetAttribute("HitSerial", 0)
	model:SetAttribute("VictorySerial", 0)
	model:SetAttribute("Moving", false)
	model:SetAttribute("MovementBlocked", false)
	model:SetAttribute("DuckRig", physical)
	model:SetAttribute("RigVersion", if v3 then 3 else 2)
	model:SetAttribute("VisualHeight", maxY - foot.Y)
	model:SetAttribute("VisualWidth", maxX - minX)
	model:SetAttribute("VisualDepth", maxZ - minZ)
	model.Parent = parent
	CollectionService:AddTag(model, "ChickenVisual")
	if physical then CollectionService:AddTag(model, "DuckRig") end
	return model
end

function BlenderPetView.Move(model, foot, direction, hop)
	local pose = previews[model]
	if not pose then return end
	local now = os.clock()
	local distance = (foot - pose.foot).Magnitude
	model:SetAttribute("PreviewSpeed", if distance < 10 then distance / math.max(now - pose.at, 0.001) else 0)
	if direction then
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude > 0.01 then pose.facing = flat.Unit end
	end
	local position = foot + Vector3.new(0, model:GetAttribute("FootOffset") + math.max(hop or 0, 0), 0)
	model:PivotTo(CFrame.lookAt(position, position - pose.facing))
	pose.foot, pose.at = foot, now
end

function BlenderPetView.Flash(model, active)
	local glow = model:FindFirstChild("HitGlow")
	if not glow and not active then return end
	if not glow then
		glow = Instance.new("Highlight")
		glow.Name = "HitGlow"
		glow.FillColor = Color3.new(1, 1, 1)
		glow.FillTransparency = 0.35
		glow.OutlineTransparency = 1
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Adornee = model
		glow.Enabled = false
		glow.Parent = model
	end
	if active and not glow.Enabled then model:SetAttribute("HitSerial", (model:GetAttribute("HitSerial") or 0) + 1) end
	glow.Enabled = active
end

return BlenderPetView
