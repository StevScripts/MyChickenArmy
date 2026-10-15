-- Editor-only import of one roster-expansion chicken (route of the Sept 27 approved-eight import).
-- Reads http://127.0.0.1:18797/<ID>.json/.rgba; uploads mesh + 512px atlas as group assets;
-- builds Model{Body MeshPart + bone tree + AnimationController} under ServerStorage staging.
local A = game:GetService("AssetService")
local H = game:GetService("HttpService")
assert(game.PlaceId == 96683186622050 and game.CreatorId == 778575811)
assert(not game:GetService("RunService"):IsRunning())
local BASE = "http://127.0.0.1:18797/"
local function folder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new("Folder"); f.Name = name; f.Parent = parent end
	return f
end
local root = folder(game.ServerStorage, "RosterExpansionImport20261015")
local receipts = folder(root, "Receipts")
local models = folder(root, "Models")
local function upload(object, kind, name)
	local lastErr
	for attempt = 1, 4 do
		local ok, status, id = pcall(function()
			return A:CreateAssetAsync(object, kind, {CreatorId = 778575811, CreatorType = Enum.AssetCreatorType.Group,
				Name = "MCA " .. name .. " 20261015", Description = "My Chicken Army roster expansion chicken (rigid skinned voxel art)."})
		end)
		if ok and status == Enum.CreateAssetResult.Success then return tonumber(id) end
		lastErr = if ok then tostring(status) .. ": " .. tostring(id) else tostring(status)
		task.wait(3 * attempt)
	end
	error(lastErr)
end
local function vec(a) return Vector3.new(a[1], a[2], a[3]) end
local function cf(a) return CFrame.new(table.unpack(a)) end
local function Import(name)
	if models:FindFirstChild(name) then return {name = name, already = true} end
	local data = H:JSONDecode(H:GetAsync(BASE .. name .. ".json"))
	local imageId = receipts:GetAttribute("image_" .. name)
	if not imageId then
		local im = assert(A:CreateEditableImage({Size = Vector2.new(512, 512)}))
		im:WritePixelsBuffer(Vector2.zero, im.Size, buffer.fromstring(H:GetAsync(BASE .. name .. ".rgba")))
		local ok, result = pcall(upload, im, Enum.AssetType.Image, name .. " Atlas"); im:Destroy(); assert(ok, result)
		imageId = result; receipts:SetAttribute("image_" .. name, result)
	end
	local min, max = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in data.positions do local v = vec(p); min = min:Min(v); max = max:Max(v) end
	local center = (min + max) / 2
	local meshId = receipts:GetAttribute("mesh_" .. name)
	if not meshId then
		local e = assert(A:CreateEditableMesh())
		local ok, result = pcall(function()
			local bones = {}
			for i, b in data.bones do bones[i] = e:AddBone({Name = b.name, CFrame = cf(b.cf) - center, Virtual = false}) end
			for i, b in data.bones do if b.parent > 0 then e:SetBoneParent(bones[i], bones[b.parent]) end end
			local vertices, normals, uvs = {}, {}, {}
			for i, p in data.positions do
				vertices[i] = e:AddVertex(vec(p) - center); normals[i] = e:AddNormal(vec(data.normals[i])); uvs[i] = e:AddUV(Vector2.new(table.unpack(data.uvs[i])))
				local bs, ws = {}, {}
				for k, w in data.weights[i] do if w > 0 then table.insert(bs, bones[data.joints[i][k]]); table.insert(ws, w) end end
				assert(#bs > 0); e:SetVertexBones(vertices[i], bs); e:SetVertexBoneWeights(vertices[i], ws)
			end
			for i = 1, #data.indices, 3 do
				local x, y, z = data.indices[i], data.indices[i + 1], data.indices[i + 2]
				local f = e:AddTriangle(vertices[x], vertices[y], vertices[z]); e:SetFaceNormals(f, {normals[x], normals[y], normals[z]}); e:SetFaceUVs(f, {uvs[x], uvs[y], uvs[z]})
			end
			return upload(e, Enum.AssetType.Mesh, name .. " Skin")
		end)
		e:Destroy(); assert(ok, result); meshId = result; receipts:SetAttribute("mesh_" .. name, result)
	end
	local part = A:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. meshId))
	part.Name = "Body"; part.Anchored = true; part.CanCollide = false; part.CanTouch = false; part.CanQuery = false; part.Massless = true
	part.CFrame = CFrame.new(center); part.Color = Color3.new(1, 1, 1); part.Material = Enum.Material.SmoothPlastic; part.TextureID = "rbxassetid://" .. imageId
	if not part:FindFirstChild(name .. "_Root") then
		local bones = {}
		for i, b in data.bones do
			local bone = Instance.new("Bone"); bone.Name = b.name; local rest = cf(b.cf) - center
			bone.CFrame = if b.parent > 0 then (cf(data.bones[b.parent].cf) - center):ToObjectSpace(rest) else rest; bones[i] = bone
		end
		for i, b in data.bones do bones[i].Parent = if b.parent > 0 then bones[b.parent] else part end
	end
	local model = Instance.new("Model"); model.Name = name; part.Parent = model; model.WorldPivot = CFrame.identity
	model:ScaleTo(0.670163170); model:SetAttribute("RosterRevision", "Expansion-20261015"); model:SetAttribute("BonePrefix", name .. "_")
	local controller = Instance.new("AnimationController"); controller.Parent = model; Instance.new("Animator", controller)
	model.Parent = models; receipts:SetAttribute("model_" .. name, true)
	return {name = name, mesh = meshId, image = imageId, bones = #data.bones, triangles = #data.indices / 3}
end

return Import
