--!strict
-- One high-detail material and UV-only mesh per appearance, shared by the flock.
-- The original small face islands stay intact in the lower half of the atlas.
-- Feather UVs use its previously empty upper-left 512-square field instead of
-- stretching 2–28 authored texels over each entire face. Skinning is unchanged.
local AssetService=game:GetService("AssetService")
local TweenService=game:GetService("TweenService")
local Pattern=require(script.Parent.ChickenTexturePattern)
local Flow={}
Flow.__index=Flow
local CONFIG={
	Galaxy={mesh="90513010317322",seconds=45},
	Rainbow={mesh="125504522932099",seconds=6},
}
local caches: {[string]: any}={}
local FIELD=Vector2.new(512,512)
local ATLAS=Vector2.new(1024,1024)

local function apply(body: MeshPart, template: MeshPart)
	local size,pose,texture=body.Size,body.CFrame,body.TextureContent
	local bones={}
	for _,child in body:GetChildren() do
		if child:IsA("Bone") then table.insert(bones,child);child.Parent=nil end
	end
	local ok,problem=pcall(function() body:ApplyMesh(template) end)
	for _,bone in bones do bone.Parent=body end
	body.Size,body.CFrame,body.TextureContent=size,pose,texture
	if not ok then error(problem,0) end
end

local function release(cache: any)
	cache.generation+=1
	if cache.tween then cache.tween:Cancel();cache.tween:Destroy() end
	for _,name in {"phase","surface","display","mesh","image","field","pattern","emissive"} do
		if cache[name] then cache[name]:Destroy();cache[name]=nil end
	end
	cache.state,cache.error,cache.lastUpdate,cache.updates="idle",nil,nil,0
end

local function animateFace(appearance: string, uv: Vector2): boolean
	local tile=(15-math.floor(uv.Y*16))*16+math.floor(uv.X*16)
	local cuboid=math.floor(tile/6)
	if appearance=="Galaxy" then return cuboid~=3 and cuboid<17 end
	return cuboid==0 or cuboid==1 or cuboid==2 or cuboid==5 or cuboid==11
end

local function remap(mesh: EditableMesh, appearance: string)
	local extent=mesh:GetSize()
	local scale=0.45/math.max(extent.X,extent.Y,extent.Z)
	local changes: {[number]: Vector2}={}
	local protected: {[number]: boolean}={}
	for _,face in mesh:GetFaces() do
		local ids,vertices=mesh:GetFaceUVs(face),mesh:GetFaceVertices(face)
		local midpoint=Vector2.zero
		for _,id in ids do midpoint+=mesh:GetUV(id) end
		midpoint/=#ids
		if animateFace(appearance,midpoint) then
			local a,b,c=mesh:GetPosition(vertices[1]),mesh:GetPosition(vertices[2]),mesh:GetPosition(vertices[3])
			local normal=(b-a):Cross(c-a)
			for index,id in ids do
				local p=mesh:GetPosition(vertices[index])
				local horizontal=if math.abs(normal.X)>math.abs(normal.Z) then p.Z else p.X
				local vertical=if math.abs(normal.Y)>math.max(math.abs(normal.X),math.abs(normal.Z)) then p.Z else p.Y
				changes[id]=Vector2.new(0.25+horizontal*scale,0.25-vertical*scale)
			end
		else for _,id in ids do protected[id]=true end end
	end
	for id,uv in changes do
		assert(not protected[id],"Feathers share a UV with a protected facial feature")
		assert(uv.X>0 and uv.X<0.5 and uv.Y>0 and uv.Y<0.5,"Flow UV exceeds reserved atlas field")
		mesh:SetUV(id,uv)
	end
	assert(next(changes),"No feather UVs found")
end

local function update(cache: any, now: number)
	if cache.lastUpdate==now then return end
	local phase=cache.phase.Value
	local x=if cache.appearance=="Galaxy" then phase*512 else 0
	local y=if cache.appearance=="Galaxy" then (phase*2%1)*512 else phase*512
	local options={CombineType=Enum.ImageCombineType.Overwrite,PivotPoint=Vector2.zero}
	-- The scratch canvas clips each wrapped copy before touching the atlas.
	-- A fractional draw offset uses native bilinear sampling for smooth motion.
	for _,dx in (if x==0 then {0} else {0,-512}) do
		for _,dy in (if y==0 then {0} else {0,-512}) do
			cache.field:DrawImageTransformed(Vector2.new(x+dx,y+dy),Vector2.one,0,cache.pattern,options)
		end
	end
	cache.image:DrawImage(Vector2.zero,cache.field,Enum.ImageCombineType.Overwrite)
	cache.lastUpdate=now
	cache.updates+=1
end

local function beginLoad(cache: any, body: MeshPart, base: SurfaceAppearance)
	if cache.state~="idle" then return end
	cache.state="loading";cache.generation+=1
	local generation=cache.generation
	local function current() return cache.generation==generation and cache.references>0 end
	task.spawn(function()
		local owned: {any}={}
		local function own(value: any)
			assert(value,"Animated material allocation unavailable")
			table.insert(owned,value);return value
		end
		local ok,problem=pcall(function()
			local input=own(AssetService:CreateEditableImageAsync(base.ColorMapContent))
			if not current() then return end
			local image=own(AssetService:CreateEditableImage({Size=ATLAS}))
			image:DrawImageTransformed(Vector2.zero,ATLAS/input.Size,0,input,
				{CombineType=Enum.ImageCombineType.Overwrite,PivotPoint=Vector2.zero})
			local pattern=Pattern.Create(cache.appearance,current)
			if not current() then if pattern then pattern:Destroy() end;return end
			own(pattern)
			local field=own(AssetService:CreateEditableImage({Size=FIELD}))
			image:DrawImage(Vector2.zero,pattern,Enum.ImageCombineType.Overwrite)
			local mesh=own(AssetService:CreateEditableMeshAsync(Content.fromUri("rbxassetid://"..CONFIG[cache.appearance].mesh),{FixedSize=true}))
			if not current() then return end
			assert(#mesh:GetVertices()==504 and #mesh:GetBones()>=18,"Unexpected chicken rig")
			remap(mesh,cache.appearance)
			local display=own(AssetService:CreateMeshPartAsync(Content.fromObject(mesh),
				{CollisionFidelity=body.CollisionFidelity,RenderFidelity=body.RenderFidelity}))
			if not current() then return end
			local material: any={ColorMap=Content.fromObject(image)}
			local emissive
			if cache.appearance=="Galaxy" then
				emissive=own(AssetService:CreateEditableImage({Size=Vector2.new(32,32)}))
				emissive:DrawRectangle(Vector2.zero,emissive.Size,Color3.new(0,0,0),0,Enum.ImageCombineType.Overwrite)
				emissive:DrawRectangle(Vector2.zero,Vector2.new(16,16),Color3.new(1,1,1),0,Enum.ImageCombineType.Overwrite)
				material.EmissiveMask=Content.fromObject(emissive)
			end
			local surface=own(AssetService:CreateSurfaceAppearanceAsync(material))
			if not current() then return end
			surface.Name=cache.appearance.."AnimatedPBR"
			surface.AlphaMode,surface.Color=Enum.AlphaMode.Overlay,Color3.new(1,1,1)
			surface.ResampleMode=Enum.ResamplerMode.Default
			surface.EmissiveStrength=if cache.appearance=="Galaxy" then 0.65 else 0
			local phase=own(Instance.new("NumberValue"))
			local tween=own(TweenService:Create(phase,TweenInfo.new(CONFIG[cache.appearance].seconds,
				Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1),{Value=1}))
			cache.image,cache.pattern,cache.field,cache.mesh,cache.display=image,pattern,field,mesh,display
			cache.surface,cache.emissive,cache.phase,cache.tween=surface,emissive,phase,tween
			cache.state,cache.error,cache.updates="ready",nil,0
			input:Destroy();table.clear(owned)
			tween:Play()
		end)
		for _,value in owned do value:Destroy() end
		if not ok and current() then cache.state,cache.error="failed",tostring(problem) end
	end)
end

function Flow.new(model: Model, appearance: string)
	if model:GetAttribute("ChickenVisualV3")~=true or model:GetAttribute("Appearance")~=appearance then return nil end
	local cache=caches[appearance]
	if not cache then cache={appearance=appearance,references=0,generation=0,state="idle",updates=0};caches[appearance]=cache end
	cache.references+=1
	return setmetatable({model=model,appearance=appearance,cache=cache,body=nil,original=nil,
		baseSurface=nil,animatedSurface=nil,destroyed=false,state="idle",frame=0,frameCount=1},Flow)
end

function Flow._restore(self: any)
	if self.original then
		if self.body and self.body.Parent then apply(self.body,self.original) end
		self.original:Destroy();self.original=nil
	end
	if self.animatedSurface then self.animatedSurface:Destroy();self.animatedSurface=nil end
	if self.baseSurface then
		if self.baseSurface.Parent==nil then
			if self.body and self.body.Parent and not self.body:FindFirstChildOfClass("SurfaceAppearance") then
				self.baseSurface.Parent=self.body
			else self.baseSurface:Destroy() end
		end
		self.baseSurface=nil
	end
end

function Flow.Step(self: any, now: number, reduced: boolean, camera: Camera?)
	if self.destroyed then return end
	local model=self.model
	if not model.Parent or model:GetAttribute("Appearance")~=self.appearance then self:Destroy();return end
	local body,root=model:FindFirstChild("Body"),model.PrimaryPart
	if body~=self.body then self:_restore();self.body=if body and body:IsA("MeshPart") then body else nil end
	if not self.body or not root then return end
	local visible=not reduced and model:GetAttribute("ReducedMotion")~=true and model:GetAttribute("Defeated")~=true
		and model:GetAttribute("PresentationHidden")~=true and root.LocalTransparencyModifier<0.5
		and self.body.LocalTransparencyModifier<0.5 and self.body.Transparency<0.98
		and camera~=nil and (camera.CFrame.Position-root.Position).Magnitude<=110
	if not visible then self:_restore();self.state="hidden";return end
	local surface=self.body:FindFirstChildOfClass("SurfaceAppearance")
	if self.animatedSurface and surface~=self.animatedSurface then self:_restore();surface=self.body:FindFirstChildOfClass("SurfaceAppearance") end
	if not surface then self.state="no-material";return end
	if not self.original and string.match(self.body.MeshId,"%d+$")~=CONFIG[self.appearance].mesh then self.state="unsupported-mesh";return end
	local cache=self.cache
	beginLoad(cache,self.body,surface)
	self.state,self.error=cache.state,cache.error
	if cache.state~="ready" then return end
	if not self.animatedSurface then
		local original=self.body:Clone();assert(original)
		original:ClearAllChildren();self.original=original
		apply(self.body,cache.display)
		self.baseSurface=surface;surface.Parent=nil
		self.animatedSurface=cache.surface:Clone();self.animatedSurface.Parent=self.body
	end
	local ok,problem=pcall(update,cache,now)
	if not ok then self:_restore();cache.state,cache.error="failed",tostring(problem);self.state,self.error=cache.state,cache.error;return end
	self.frame=cache.updates
end

function Flow.Destroy(self: any)
	if self.destroyed then return end
	self:_restore();self.destroyed=true
	local cache=self.cache;cache.references-=1
	if cache.references==0 then release(cache) end
end

return Flow
