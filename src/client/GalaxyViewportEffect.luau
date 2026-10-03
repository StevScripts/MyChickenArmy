--!strict
-- One local world-depth surface using the authored zero-alpha planes. The real
-- chicken stays intact, so unsupported assets and quality changes fail safely.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetService = game:GetService("AssetService")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Effect = {}
Effect.__index = Effect
type Candidate = {model: Model, body: MeshPart, distance: number, points: {Vector3}}

local GALAXY_MESH = "90513010317322"
local FACE_TEXTURE = "rbxassetid://88919583329083"
local MAX_DISTANCE, CHECK_INTERVAL = 65, 0.1
-- The reference covers a tall avatar. Fit its cloud/star detail to our smaller
-- chicken while retaining all four authored layer proportions and loop periods.
local PATTERN_SCALE = 0.28
local FACE_REGIONS = { -- Only eyes/highlights and beak; original 1024-pixel atlas.
	{128,896,512,960}, -- Beak; the adjacent wattle tiles stay transparent.
	{384,576,1024,640}, {0,512,896,576}, -- Eyes and highlights.
}
local LAYERS = {
	-- Preserve the Character2 planes' distinct angles and wrapped local origins.
	{name="Stars1", size=Vector3.new(16,34,0.001), axis="Y", speed=0.4, z=-0.002,
		angle=math.rad(56.25), origin=Vector2.new(3.652608,-4.114572)},
	{name="Galaxy1", size=Vector3.new(12,12,0.001), axis="X", speed=0.08, z=-0.001,
		angle=math.rad(-22.5), origin=Vector2.new(1.635473,1.942528)},
	{name="Stars2", size=Vector3.new(22,48,0.001), axis="Y", speed=0.2, z=0.001,
		angle=math.rad(56.25), origin=Vector2.new(0.652608,-11.114572)},
	{name="Galaxy2", size=Vector3.new(18,18,0.001), axis="Y", speed=0.05, z=0.002,
		angle=math.rad(-123.75), origin=Vector2.new(-2.652608,-3.885428)},
}

local function candidate(model: Model, camera: Camera, retained: boolean?): Candidate?
	if not model:IsDescendantOf(workspace) or model:GetAttribute("Appearance") ~= "Galaxy"
		or model:GetAttribute("GalaxyMaskPreview") ~= true
		or model:GetAttribute("ReducedMotion") == true or model:GetAttribute("PresentationHidden") == true
		or model:GetAttribute("Defeated") == true then return nil end
	local root, body = model.PrimaryPart, model:FindFirstChild("Body")
	if not root or not body or not body:IsA("MeshPart") or root.LocalTransparencyModifier >= 0.5
		or body.LocalTransparencyModifier >= 0.5 or body.Transparency >= 0.98
		or string.match(body.MeshId, "%d+$") ~= GALAXY_MESH then return nil end
	local distance = (camera.CFrame.Position - body.Position).Magnitude
	if distance > MAX_DISTANCE+(if retained then 5 else 0) or distance < 2 then return nil end
	local center = camera:WorldToViewportPoint(body.Position)
	if center.Z <= 1 then return nil end
	local points = {body.Position}
	local minX,minY,maxX,maxY = center.X,center.Y,center.X,center.Y
	for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
		local point = body.CFrame:PointToWorldSpace(body.Size * Vector3.new(x,y,z) * 0.5)
		local screen = camera:WorldToViewportPoint(point)
		if screen.Z <= 1 then return nil end
		minX,minY,maxX,maxY = math.min(minX,screen.X),math.min(minY,screen.Y),math.max(maxX,screen.X),math.max(maxY,screen.Y)
		table.insert(points,point)
	end end end
	local width,height = maxX-minX,maxY-minY
	local viewport = camera.ViewportSize
	-- Native clipping handles a chicken partly outside the screen. Requiring
	-- every corner to be on screen repeatedly unloaded an otherwise visible rig.
	if maxX<=0 or maxY<=0 or minX>=viewport.X or minY>=viewport.Y then return nil end
	-- Cull tiny distant birds, but keep the effect during close-ups. An upper
	-- pixel/area cutoff swapped to the plain texture as the chicken approached.
	-- The renderer already has a fixed one-viewport resource budget.
	if math.max(width,height) < (if retained then 28 else 36) then return nil end
	return {model=model,body=body,distance=distance,points=points}
end

local function cleanClone(body: MeshPart, name: string): MeshPart
	local clone = body:Clone()
	assert(clone, "Galaxy mesh cannot be cloned")
	clone.Name = name
	for _,item in clone:GetDescendants() do
		if not item:IsA("Bone") and item.Parent then item:Destroy() end
	end
	clone.Anchored,clone.CanCollide,clone.CanTouch,clone.CanQuery = true,false,false,false
	clone.CastShadow,clone.LocalTransparencyModifier = false,0
	clone.TextureID,clone.MaterialVariant = "",""
	clone.Color,clone.Reflectance = Color3.new(1,1,1),0
	return clone
end

function Effect.new()
	return setmetatable({activeModel=nil,selectedModel=nil,sourceBody=nil,state="idle",error=nil,
		generation=0,destroyed=false,loading=false,retryAt=0,nextSelection=0,
		viewport=nil,depthPlane=nil,surface=nil,world=nil,camera=nil,glass=nil,face=nil,faceImage=nil,faceSurface=nil,
		layers={},bones={}},Effect)
end

function Effect._clear(self: any, state: string, problem: any?)
	self.generation += 1
	self.activeModel,self.selectedModel,self.sourceBody = nil,nil,nil
	self.loading = false
	for _,layer in self.layers do layer.tween:Cancel();layer.tween:Destroy();layer.phase:Destroy() end
	table.clear(self.layers)
	table.clear(self.bones)
	if self.viewport then self.viewport:Destroy() end
	if self.surface then self.surface:Destroy() end
	if self.depthPlane then self.depthPlane:Destroy() end
	if self.faceSurface then self.faceSurface:Destroy() end
	if self.faceImage then self.faceImage:Destroy() end
	self.viewport,self.world,self.camera,self.glass,self.face = nil,nil,nil,nil,nil
	self.depthPlane,self.surface = nil,nil
	self.faceSurface,self.faceImage = nil,nil
	self.state,self.error = state,if problem then tostring(problem) else nil
end

function Effect._start(self: any, record: Candidate, assets: Instance, playerGui: PlayerGui)
	self:_clear("loading")
	self.selectedModel,self.sourceBody = record.model,record.body
	self.loading = true
	local generation = self.generation
	-- A ScreenGui draws over world geometry and particles. This camera-facing
	-- SurfaceGui participates in world depth, including CanQuery=false objects
	-- and egg billboards that raycasts cannot detect. It never receives input.
	local depthPlane = Instance.new("Part")
	self.depthPlane = depthPlane
	depthPlane.Name = "GalaxyWorldEffectPlane"
	depthPlane.Anchored,depthPlane.CanCollide,depthPlane.CanTouch,depthPlane.CanQuery = true,false,false,false
	depthPlane.Transparency,depthPlane.CastShadow = 1,false
	local surface = Instance.new("SurfaceGui")
	self.surface = surface
	surface.Name,surface.Face = "GalaxyWorldSurface",Enum.NormalId.Back
	surface.AlwaysOnTop,surface.Active = false,false
	surface.LightInfluence,surface.Brightness = 0,1
	surface.MaxDistance = MAX_DISTANCE+10
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	-- ViewportFrames need a PlayerGui host to render on this world surface.
	surface.Adornee = depthPlane
	surface.Parent,depthPlane.Parent = playerGui,workspace
	local viewport = Instance.new("ViewportFrame")
	self.viewport = viewport
	viewport.Name,viewport.ZIndex = "GalaxyWorldEffect",0
	viewport.BackgroundTransparency,viewport.BorderSizePixel = 1,0
	-- Glass reveals this color through the zero-alpha planes even though the
	-- viewport background itself is transparent. Default gray washes out space.
	viewport.BackgroundColor3 = Color3.new(0,0,0)
	viewport.Active,viewport.Selectable,viewport.Interactable = false,false,false
	viewport.Ambient,viewport.LightColor = Color3.new(1,1,1),Color3.new(0,0,0)
	viewport.Size = UDim2.fromScale(1,1)
	viewport.Visible,viewport.Parent = false,surface
	local world = Instance.new("WorldModel")
	world.Name,world.Parent = "GalaxyMask",viewport
	self.world = world
	local camera = Instance.new("Camera")
	camera.Parent,viewport.CurrentCamera,self.camera = viewport,camera,camera
	local glass = cleanClone(record.body,"GalaxyGlass")
	glass.Material,glass.Transparency,glass.Parent = Enum.Material.Glass,0.99,world
	self.glass = glass
	local face = cleanClone(record.body,"GalaxyFace")
	face.Material,face.Transparency,face.Parent = Enum.Material.SmoothPlastic,0,world
	self.face = face
	for _,bone in record.body:GetDescendants() do
		if bone:IsA("Bone") then
			local a,b = glass:FindFirstChild(bone.Name,true),face:FindFirstChild(bone.Name,true)
			assert(a and a:IsA("Bone") and b and b:IsA("Bone"),"Galaxy skeleton mismatch")
			table.insert(self.bones,{source=bone,glass=a,face=b})
		end
	end
	assert(#self.bones>0,"Galaxy skeleton missing")
	local planes = {}
	for _,definition in LAYERS do
		local template = assets:FindFirstChild(definition.name)
		assert(template and template:IsA("MeshPart"),"Galaxy layer missing: "..definition.name)
		local plane = template:Clone()
		for _,item in plane:GetDescendants() do if not item:IsA("SurfaceAppearance") then item:Destroy() end end
		plane.Anchored,plane.CanCollide,plane.CanTouch,plane.CanQuery = true,false,false,false
		plane.Transparency,plane.LocalTransparencyModifier,plane.CastShadow = 0,0,false
		plane.Color,plane.Parent = Color3.new(1,1,1),world
		local surface = plane:FindFirstChildOfClass("SurfaceAppearance")
		assert(surface, "Galaxy layer material missing")
		-- Preserve the reference textures' bright lavender/white cloud detail.
		surface.Color = Color3.new(1,1,1)
		local phase = Instance.new("NumberValue")
		phase.Name,phase.Parent = definition.name.."Phase",viewport
		local axisSize = if definition.axis=="X" then definition.size.X else definition.size.Y
		local tween = TweenService:Create(phase,TweenInfo.new(axisSize/2/definition.speed,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1),{Value=1})
		table.insert(self.layers,{part=plane,phase=phase,tween=tween,definition=definition})
		table.insert(planes,plane)
		tween:Play()
	end
	local function current(): boolean
		return not self.destroyed and self.generation==generation and self.selectedModel==record.model
			and record.body.Parent==record.model and viewport.Parent==self.surface
	end
	task.spawn(function()
		local input,output,surface
		local ok,problem = pcall(function()
			local failed = false
			ContentProvider:PreloadAsync(planes,function(_,status)
				if status~=Enum.AssetFetchStatus.Success then failed=true end
			end)
			if not current() then return end
			assert(not failed,"Galaxy layer assets failed to load")
			input = AssetService:CreateEditableImageAsync(Content.fromUri(FACE_TEXTURE))
			if not current() then return end
			assert(input,"Galaxy foreground image budget unavailable")
			assert(input.Size.X==input.Size.Y and input.Size.X<=1024,"Galaxy foreground atlas dimensions changed")
			output = AssetService:CreateEditableImage({Size=Vector2.new(512,512)})
			assert(output,"Galaxy foreground output budget unavailable")
			output:DrawImageTransformed(Vector2.zero,Vector2.new(512/input.Size.X,512/input.Size.Y),0,input,
				{CombineType=Enum.ImageCombineType.Overwrite,PivotPoint=Vector2.zero})
			input:Destroy();input=nil
			local regions = {}
			for _,rect in FACE_REGIONS do
				local position = Vector2.new(rect[1],rect[2])/2
				local size = Vector2.new(rect[3]-rect[1],rect[4]-rect[2])/2
				table.insert(regions,{position=position,size=size,pixels=output:ReadPixelsBuffer(position,size)})
			end
			output:DrawRectangle(Vector2.zero,output.Size,Color3.new(0,0,0),1,Enum.ImageCombineType.Overwrite)
			for _,region in regions do output:WritePixelsBuffer(region.position,region.size,region.pixels) end
			surface = AssetService:CreateSurfaceAppearanceAsync({ColorMap=Content.fromObject(output)})
			if not current() then return end
			assert(surface,"Galaxy foreground material unavailable")
			surface.Name,surface.AlphaMode = "GalaxyForeground",Enum.AlphaMode.Transparency
			surface.Parent = face
			self.faceImage,self.faceSurface,self.loading = output,surface,false
			self.state,self.error = "ready",nil
			output,surface = nil,nil
		end)
		if input then input:Destroy() end
		if output then output:Destroy() end
		if surface then surface:Destroy() end
		if not ok and current() then
			self:_clear("failed",problem)
			self.retryAt = os.clock()+10
		end
	end)
end

function Effect._align(self: any, record: Candidate, camera: Camera): boolean
	local size = camera.ViewportSize
	if size.X<=0 or size.Y<=0 then return false end
	local nearest = math.huge
	for _,point in record.points do
		nearest=math.min(nearest,-camera.CFrame:PointToObjectSpace(point).Z)
	end
	-- Sit immediately in front of the original rig, which remains the fallback.
	-- World depth clips foreground objects. Do not hide the whole viewport when
	-- a ray touches the rig's bounds: that switches materials during normal motion.
	local depth = math.max(nearest-0.05,0.5)
	local height = 2*depth*math.tan(math.rad(camera.FieldOfView*0.5))
	self.depthPlane.Size = Vector3.new(height*size.X/size.Y,height,0.01)
	self.depthPlane.CFrame = camera.CFrame*CFrame.new(0,0,-depth-0.005)
	self.surface.CanvasSize = size
	self.camera.FieldOfViewMode = camera.FieldOfViewMode
	self.camera.FieldOfView,self.camera.CFrame,self.camera.Focus = camera.FieldOfView,camera.CFrame,camera.Focus
	return true
end

function Effect.Step(self: any, now: number, camera: Camera?, records: {[Model]: any}, tier: string, reduced: boolean)
	if self.destroyed then return end
	if reduced or tier~="masked" or not camera then
		if self.viewport or self.loading then self:_clear(if reduced then "reduced" else "quality") end
		self.activeModel=nil
		return
	end
	if now<self.retryAt then return end
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	local gui = playerGui and playerGui:FindFirstChild("PetRollGui")
	local petRoll = ReplicatedStorage:FindFirstChild("PetRoll")
	local assets = petRoll and petRoll:FindFirstChild("GalaxyViewportAssets")
	if not gui or not gui:IsA("ScreenGui") or not gui.Enabled or not assets then
		if self.viewport or self.loading then self:_clear("unavailable") end
		self.state,self.activeModel = if not assets then "assets-unavailable" else "ui-unavailable",nil
		return
	end
	local selected = if self.selectedModel then candidate(self.selectedModel,camera,true) else nil
	-- Keep this bird while eligible instead of swapping the one-mask budget
	-- between nearby Galaxies as they walk past each other.
	if not selected and now>=self.nextSelection then
		self.nextSelection=now+CHECK_INTERVAL
		for model in records do
			local possible = candidate(model,camera)
			if possible and (not selected or possible.distance<selected.distance) then selected=possible end
		end
	end
	if not selected then
		if self.viewport or self.loading then self:_clear("no-candidate") end
		self.activeModel=nil
		return
	end
	if self.selectedModel~=selected.model or self.sourceBody~=selected.body or not self.viewport
		or self.viewport.Parent~=self.surface or not self.surface or self.surface.Parent~=playerGui
		or not self.depthPlane or self.depthPlane.Parent~=workspace then
		local ok,problem = pcall(function() self:_start(selected,assets,playerGui) end)
		if not ok then self:_clear("failed",problem);self.retryAt=now+10;return end
	end
	if self.loading then self.activeModel=nil;self.viewport.Visible=false;return end
	local body = selected.body
	if not self:_align(selected,camera) then
		self.activeModel=nil;self.viewport.Visible=false;self.state="alignment";return
	end
	-- Camera projection and skinned-bone poses are inputs, not independent motion;
	-- they must mirror the already-posed world rig every render. Drift uses tweens.
	self.glass.Size,self.glass.CFrame=body.Size,body.CFrame
	self.face.Size,self.face.CFrame=body.Size,body.CFrame+(camera.CFrame.Position-body.Position).Unit*0.001
	for _,pair in self.bones do
		if not pair.source:IsDescendantOf(body) then self:_clear("rig-changed");return end
		pair.glass.CFrame,pair.face.CFrame=pair.source.CFrame,pair.source.CFrame
		pair.glass.Transform,pair.face.Transform=pair.source.Transform,pair.source.Transform
	end
	local scale=math.max((selected.distance+6)/2,0.01)*PATTERN_SCALE
	local frame=CFrame.lookAt(body.Position+camera.CFrame.LookVector*6,camera.CFrame.Position)
	for _,layer in self.layers do
		local definition=layer.definition
		local axisSize=if definition.axis=="X" then definition.size.X else definition.size.Y
		local half=axisSize/2
		local travel=layer.phase.Value*half
		local width,height=definition.size.X/2,definition.size.Y/2
		local x=(definition.origin.X+(if definition.axis=="X" then travel else 0)+width/2)%width-width/2
		local y=(definition.origin.Y+(if definition.axis=="Y" then travel else 0)+height/2)%height-height/2
		layer.part.Size=definition.size*scale
		layer.part.CFrame=frame*CFrame.Angles(0,0,definition.angle)*CFrame.new(x*scale,y*scale,definition.z)
	end
	self.viewport.Visible=true
	self.activeModel,self.state,self.error=selected.model,"ready",nil
end

function Effect.Destroy(self: any)
	if self.destroyed then return end
	self:_clear("destroyed")
	self.destroyed=true
end

return Effect
