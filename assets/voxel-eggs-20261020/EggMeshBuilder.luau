-- Studio-only builder (run from Edit through Studio MCP). Not part of the game:
-- it turns mesh/<Id>.json (export_meshes.py, served on localhost:8765) into
-- published Mesh assets and MeshPart templates under
-- ReplicatedStorage.PetRoll.Assets.EggMeshes. See docs/team/VOXEL_EGGS.md.
local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")

local Builder = {}
local VOX = 1.75 / 18 -- egg body is 1.75 studs tall, matching the old sprite's egg
local H = 18
local OTHER = {[0] = {2, 3}, [1] = {1, 3}, [2] = {1, 2}}
local AXIS = {[0] = Vector3.xAxis, [1] = Vector3.yAxis, [2] = Vector3.zAxis}
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local LADDER = { -- rarity -> reflectance, sparkle rate
	Common = {0, 0}, Uncommon = {0, 0}, Rare = {0.06, 0}, Epic = {0.08, 0},
	Legendary = {0.1, 1.5}, Mythic = {0.12, 3}, Secret = {0.14, 5},
}

local function mesh(data, wantGlow)
	local em = AssetService:CreateEditableMesh()
	local colors, normals, faces = {}, {}, 0
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, q in data.quads do
		local axis, d, plane, u0, v0, du, dv, ci, glow = q[1], q[2], q[3], q[4], q[5], q[6], q[7], q[8], q[9]
		if (glow == 1) ~= wantGlow then continue end
		local ua, va = OTHER[axis][1], OTHER[axis][2]
		local function P(u, v)
			local t = {0, 0, 0}; t[axis + 1] = plane; t[ua] = u; t[va] = v
			return Vector3.new(t[1], t[2], t[3]) * VOX
		end
		local p = {P(u0, v0), P(u0 + du, v0), P(u0 + du, v0 + dv), P(u0, v0 + dv)}
		for _, v in p do lo, hi = lo:Min(v), hi:Max(v) end
		local nvec = AXIS[axis] * d
		local key = axis * 2 + (if d > 0 then 1 else 0)
		if not normals[key] then normals[key] = em:AddNormal(nvec) end
		if not colors[ci] then
			local c = data.palette[ci + 1]
			colors[ci] = em:AddColor(Color3.fromRGB(c[1], c[2], c[3]), 1)
		end
		local ids = {}
		for i = 1, 4 do ids[i] = em:AddVertex(p[i]) end
		local flip = (p[2] - p[1]):Cross(p[3] - p[1]):Dot(nvec) < 0
		for _, t in (if flip then {{1, 3, 2}, {1, 4, 3}} else {{1, 2, 3}, {1, 3, 4}}) do
			local f = em:AddTriangle(ids[t[1]], ids[t[2]], ids[t[3]])
			em:SetFaceColors(f, {colors[ci], colors[ci], colors[ci]})
			em:SetFaceNormals(f, {normals[key], normals[key], normals[key]})
			faces += 1
		end
	end
	if faces == 0 then em:Destroy(); return nil end
	return em, faces, (lo + hi) / 2
end

local function publish(em, name)
	local result, assetId = AssetService:CreateAssetAsync(em, Enum.AssetType.Mesh, {Name = name, Description = "My Chicken Army voxel egg"})
	em:Destroy()
	assert(result == Enum.CreateAssetResult.Success, name .. ": " .. tostring(result))
	return assetId
end

local function part(assetId)
	local p = AssetService:CreateMeshPartAsync(Content.fromAssetId(assetId), {
		CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Automatic})
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.Material = Enum.Material.SmoothPlastic
	return p
end

function Builder.Folder()
	local assets = game.ReplicatedStorage.PetRoll.Assets
	local folder = assets:FindFirstChild("EggMeshes")
	if not folder then
		folder = Instance.new("Folder"); folder.Name = "EggMeshes"; folder.Parent = assets
	end
	return folder
end

-- species = {{id=..., rarity=...}, ...}; returns {[id] = {body=assetId, glow=assetId?, tris=n}}
function Builder.Build(species, base: string)
	local folder, out = Builder.Folder(), {}
	for _, s in species do
		local data = HttpService:JSONDecode(HttpService:GetAsync(base .. s.id .. ".json"))
		local em, faces, center = mesh(data, false)
		local bodyId = publish(em, "MCA Egg " .. s.id)
		local body = part(bodyId)
		body.Name = s.id
		-- From the part's centre (its mesh bounds) to the egg body's centre.
		body:SetAttribute("EggCenter", Vector3.new(0, H / 2 * VOX, 0) - center)
		body:SetAttribute("Rarity", s.rarity)
		local ladder = LADDER[s.rarity] or LADDER.Common
		body.Reflectance = ladder[1]
		local tris, glowId = faces, nil
		local gem, gfaces, gcenter = mesh(data, true)
		if gem then
			glowId = publish(gem, "MCA Egg " .. s.id .. " Glow")
			local glow = part(glowId)
			glow.Name, glow.Material = "Glow", Enum.Material.Neon
			glow:SetAttribute("Offset", gcenter - center)
			glow.CFrame = body.CFrame + (gcenter - center)
			glow.Parent = body
			tris += gfaces
		end
		if ladder[2] > 0 then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Name, sparkle.Texture, sparkle.Rate = "Sparkle", SPARKLE, ladder[2]
			sparkle.Lifetime, sparkle.Speed = NumberRange.new(0.6, 1.1), NumberRange.new(0.3, 0.8)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.28), NumberSequenceKeypoint.new(1, 0)})
			sparkle.LightEmission, sparkle.LockedToPart = 1, true
			sparkle.Parent = body
		end
		local old = folder:FindFirstChild(s.id)
		if old then old:Destroy() end
		body.Parent = folder
		out[s.id] = {body = bodyId, glow = glowId, tris = tris}
	end
	return out
end

return Builder
