--!strict
-- Keep the authored dragon and native animation hierarchy inside an ordinary
-- walking shell. Its large silhouette does not create a Giant or large collider.
local CollectionService = game:GetService("CollectionService")
local Rules = require(script.Parent.Rules)
local View = {}
local previews = {}

function View.Create(parent, id, species, stars, foot, physical)
	local assets = script.Parent.Parent:FindFirstChild("ChickenAssets")
	local template = assets and assets:FindFirstChild(species)
	if not template then return nil end
	local model = template:Clone()
	model.Name = id
	for _,name in {"Animations","InitialPoses","AnimSaves","HookupNotes"} do
		local authoring = model:FindFirstChild(name)
		if authoring and authoring:IsA("Folder") then authoring:Destroy() end
	end
	local body = model:FindFirstChild("DragonChickenMesh")
	local controller = model:FindFirstChildOfClass("AnimationController")
	if not body or not body:IsA("MeshPart") or not controller or not body:FindFirstChild("FlightRoot") then
		model:Destroy()
		return nil
	end
	-- Template pivot is at the feet and native flight/attack face -Z. Physical
	-- LookVector therefore already matches the authored forward lunge.
	local rotation = if physical then CFrame.identity else CFrame.Angles(0,math.pi,0)
	model:PivotTo(CFrame.new(foot)*rotation)
	for _,item in model:GetDescendants() do
		if item:IsA("JointInstance") or item:IsA("WeldConstraint") then item:Destroy() end
	end
	for _,name in {"RootPart","HumanoidRootPart"} do
		local old = model:FindFirstChild(name)
		if old and old:IsA("BasePart") and not old:FindFirstChildWhichIsA("Bone",true) then old:Destroy() end
	end
	local oldHumanoid = model:FindFirstChildOfClass("Humanoid")
	if oldHumanoid then oldHumanoid:Destroy() end
	local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator",controller)

	local stats = Rules.Stats(species,stars)
	local offset = stats.size*(if physical then 0.75 else 0.45)
	local root = Instance.new("Part")
	root.Name,root.Size = "HumanoidRootPart",Vector3.new(0.72,0.72,0.85)*stats.size
	root.CFrame = CFrame.new(foot+Vector3.new(0,offset,0))*rotation
	root.Transparency,root.Anchored = 1,not physical
	root.CanCollide,root.CanTouch,root.CanQuery = physical,false,physical
	root.RootPriority = 127
	root.CustomPhysicalProperties = PhysicalProperties.new(1,0.3,0,1,0)
	root.Parent,model.PrimaryPart = model,root
	local minX,minZ,maxX,maxY,maxZ = math.huge,math.huge,-math.huge,-math.huge,-math.huge
	for _,surface in model:GetDescendants() do
		if surface:IsA("BasePart") and surface~=root then
			surface.Anchored,surface.Massless = false,true
			surface.CanCollide,surface.CanTouch,surface.CanQuery = false,false,false
			local joint = Instance.new("Motor6D")
			joint.Name = if surface==body then "MeshJoint" else "SurfaceJoint_"..surface.Name
			joint.Part0,joint.Part1 = root,surface
			joint.C0,joint.Parent = root.CFrame:ToObjectSpace(surface.CFrame),root
			if surface.Transparency<1 then
				for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
					local point = surface.CFrame:PointToWorldSpace(surface.Size*Vector3.new(x,y,z)*0.5)
					minX,minZ = math.min(minX,point.X),math.min(minZ,point.Z)
					maxX,maxY,maxZ = math.max(maxX,point.X),math.max(maxY,point.Y),math.max(maxZ,point.Z)
				end end end
			end
		end
	end
	-- Keep authored effects, but let the same client lifecycle as other imported
	-- chickens control hiding, defeat, reduced motion and distance culling.
	for _, effect in model:GetDescendants() do
		if effect:IsA("ParticleEmitter") or effect:IsA("Beam") or effect:IsA("Trail") or effect:IsA("Light") then
			effect:SetAttribute("ImportedEffectEnabled", effect.Enabled)
			effect.Enabled = false
		end
	end
	if physical then
		local humanoid = Instance.new("Humanoid")
		humanoid.RequiresNeck,humanoid.BreakJointsOnDeath = false,false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.MaxHealth,humanoid.Health = 100,100
		humanoid.WalkSpeed,humanoid.JumpPower,humanoid.JumpHeight = 0,0,0
		humanoid.AutoJumpEnabled = false
		humanoid.HipHeight = offset-root.Size.Y/2
		humanoid.Parent = model
		-- Roblox advances the native track on the Humanoid for physical actors;
		-- keeping a competing AnimationController leaves its pose clock frozen.
		animator.Parent = humanoid
		controller:Destroy()
		for _,state in {Enum.HumanoidStateType.Climbing,Enum.HumanoidStateType.Swimming,
			Enum.HumanoidStateType.Jumping,Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.FallingDown,Enum.HumanoidStateType.Seated} do humanoid:SetStateEnabled(state,false) end
	else
		previews[model] = {facing=Vector3.zAxis,foot=foot,at=os.clock()}
		model.Destroying:Once(function() previews[model]=nil end)
	end
	for key,value in {
		Species=species,Stars=stars,Size=stats.size,ClipScale=1,
		SkinnedChicken=true,ChickenVisualV3=false,GalaxyDragonAnimation=true,
		VisualStyle="GalaxyDragon",BaseVisualScale=1,FootOffset=offset,
		VisualHeight=maxY-foot.Y,VisualWidth=maxX-minX,VisualDepth=maxZ-minZ,
		NavigationHeight=stats.size*1.5,AttackSerial=0,HitSerial=0,VictorySerial=0,
		Moving=false,MovementBlocked=false,DuckRig=physical,RigVersion=4,
		Defeated=false,PresentationHidden=false,ReducedMotion=false,
		IntegrationStatus="GameplayEnabled",
	} do model:SetAttribute(key,value) end
	model.Parent = parent
	CollectionService:AddTag(model,"ChickenVisual")
	if physical then CollectionService:AddTag(model,"DuckRig") end
	return model
end

function View.Move(model, foot, direction, hop)
	local pose = previews[model]
	if not pose then return end
	local now = os.clock()
	local distance = (foot-pose.foot).Magnitude
	model:SetAttribute("PreviewSpeed",if distance<10 then distance/math.max(now-pose.at,0.001) else 0)
	if direction then
		local flat = Vector3.new(direction.X,0,direction.Z)
		if flat.Magnitude>0.01 then pose.facing=flat.Unit end
	end
	local position = foot+Vector3.new(0,model:GetAttribute("FootOffset")+math.max(hop or 0,0),0)
	model:PivotTo(CFrame.lookAt(position,position+pose.facing))
	pose.foot,pose.at = foot,now
end

return View
