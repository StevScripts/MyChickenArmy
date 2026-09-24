-- Edit-only import tool. Does not require or mutate gameplay services/player data.
local A = game:GetService("AssetService")
local H = game:GetService("HttpService")
local S = game:GetService("ServerStorage")
local BASE = "http://127.0.0.1:18788/"
assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning(), "Wrong import target")
assert(game.CreatorId == 778575811, "Unexpected asset owner")
local function folder(parent, name)
    local f = parent:FindFirstChild(name)
    if not f then f = Instance.new("Folder"); f.Name = name; f.Parent = parent end
    return f
end
local receiptFolder = folder(S, "ChickenSkinsV2ImportReceipts")
local library = folder(S, "ChickenSkinsV2Library")
local models = folder(library, "Models")
local clips = folder(library, "Clips")
local function get(path) return H:JSONDecode(H:GetAsync(BASE .. path)) end
local function upload(obj, kind, name)
    local status, id = A:CreateAssetAsync(obj, kind, {
        Name = string.sub("CA Skin V2 " .. name, 1, 48),
        Description = "Authored blocky chicken expansion; original PBR textures and skeletal mesh",
        CreatorId = 778575811, CreatorType = Enum.AssetCreatorType.Group,
    })
    assert(status == Enum.CreateAssetResult.Success, tostring(status) .. ": " .. tostring(id))
    return tonumber(id)
end
local function asset(key)
    local id = receiptFolder:GetAttribute("image_" .. key)
    assert(id, "Missing uploaded image " .. key)
    return "rbxassetid://" .. id
end
local Import = {}
function Import.Images(first, last)
    local items = get("images.json")
    for i = first, math.min(last, #items) do
        local info = items[i]
        if not receiptFolder:GetAttribute("image_" .. info.key) then
            local data = H:GetAsync(BASE .. "rgba/" .. info.file)
            local im = A:CreateEditableImage({Size = Vector2.new(info.size[1], info.size[2])})
            assert(im, "Image memory allocation failed")
            im:WritePixelsBuffer(Vector2.zero, im.Size, buffer.fromstring(data))
            local ok, id = pcall(upload, im, Enum.AssetType.Image, info.name)
            im:Destroy()
            assert(ok, id)
            receiptFolder:SetAttribute("image_" .. info.key, id)
        end
        receiptFolder:SetAttribute("ImagesDone", i)
    end
    return {done=receiptFolder:GetAttribute("ImagesDone"), total=#items}
end
local function v3(a) return Vector3.new(a[1], a[2], a[3]) end
local function cf(a) return CFrame.new(table.unpack(a)) end
function Import.Model(id)
    if models:FindFirstChild(id) then return {id=id,alreadyImported=true} end
    local data = get("payload/" .. id .. ".json")
    local model = Instance.new("Model")
    model.Name = id
    model:SetAttribute("DisplayName", data.displayName)
    model:SetAttribute("ExpansionPBR", true)
    model:SetAttribute("Rollable", false)
    local metadata = {}
    local ok, err = pcall(function()
        for i, part in data.parts do
            local min, max = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
            for _, xyz in part.positions do local v=v3(xyz); min=min:Min(v); max=max:Max(v) end
            local center = (min+max)/2
            local meshId = receiptFolder:GetAttribute("geometry_" .. part.geometryKey)
            if not meshId then
                local e = A:CreateEditableMesh()
                assert(e, "Mesh allocation failed")
                local success, result = pcall(function()
                    local boneIds = {}
                    for bi,b in data.bones do boneIds[bi]=e:AddBone({Name=b.name, CFrame=cf(b.cf)-center, Virtual=false}) end
                    for bi,b in data.bones do if b.parent>0 then e:SetBoneParent(boneIds[bi],boneIds[b.parent]) end end
                    local vertices, normals, uvs = {},{},{}
                    for vi,p in part.positions do
                        vertices[vi]=e:AddVertex(v3(p)-center)
                        normals[vi]=e:AddNormal(v3(part.normals[vi]))
                        uvs[vi]=e:AddUV(Vector2.new(part.uvs[vi][1],part.uvs[vi][2]))
                        local bs,ws={},{}
                        for k,w in part.weights[vi] do if w>0 then table.insert(bs,boneIds[part.joints[vi][k]]); table.insert(ws,w) end end
                        assert(#bs>0,"Unweighted vertex")
                        e:SetVertexBones(vertices[vi],bs); e:SetVertexBoneWeights(vertices[vi],ws)
                    end
                    for k=1,#part.indices,3 do
                        local x,y,z=part.indices[k],part.indices[k+1],part.indices[k+2]
                        local face=e:AddTriangle(vertices[x],vertices[y],vertices[z])
                        e:SetFaceNormals(face,{normals[x],normals[y],normals[z]})
                        e:SetFaceUVs(face,{uvs[x],uvs[y],uvs[z]})
                    end
                    return upload(e,Enum.AssetType.Mesh,id.." "..part.name)
                end)
                e:Destroy()
                assert(success,result)
                meshId=result
                receiptFolder:SetAttribute("geometry_" .. part.geometryKey, meshId)
            end
            local mesh=A:CreateMeshPartAsync(Content.fromUri("rbxassetid://"..meshId))
            mesh.Name=if i==1 then "Body" else part.name
            mesh.Anchored=true; mesh.CanCollide=false; mesh.CanTouch=false; mesh.CanQuery=false
            mesh.CFrame=CFrame.new(center); mesh.Color=Color3.new(1,1,1); mesh.Material=Enum.Material.SmoothPlastic
            mesh:SetAttribute("SourceMaterial",part.material)
            local allocated,contents={},{}
            local imageInfo={}
            for _,item in get("images.json") do imageInfo[item.key]=item end
            local compiled,material=pcall(function()
                for channel,property in {color="ColorMap",normal="NormalMap",metalness="MetalnessMap",roughness="RoughnessMap"} do
                    local info=imageInfo[part.maps[channel]]
                    local im=A:CreateEditableImage({Size=Vector2.new(info.size[1],info.size[2])});assert(im)
                    table.insert(allocated,im)
                    im:WritePixelsBuffer(Vector2.zero,im.Size,buffer.fromstring(H:GetAsync(BASE.."rgba/"..info.file)))
                    contents[property]=Content.fromObject(im)
                end
                local appearance=A:CreateSurfaceAppearanceAsync(contents)
                appearance.Name="PBR"
                appearance.ColorMap=asset(part.maps.color)
                appearance.NormalMap=asset(part.maps.normal)
                appearance.MetalnessMap=asset(part.maps.metalness)
                appearance.RoughnessMap=asset(part.maps.roughness)
                appearance.EmissiveStrength=0
                appearance.AlphaMode=Enum.AlphaMode.Overlay
                return appearance
            end)
            for _,im in allocated do im:Destroy() end
            assert(compiled,material)
            material.Parent=mesh
            mesh:SetAttribute("NativePBRCompiled",true)
            -- The uploaded mesh contains bind data; materialize matching Bone instances.
            if not mesh:FindFirstChild("Root") then
                local bones={}
                for bi,b in data.bones do
                    local bone=Instance.new("Bone");bone.Name=b.name
                    local rest=cf(b.cf)-center
                    bone.CFrame=if b.parent>0 then (cf(data.bones[b.parent].cf)-center):ToObjectSpace(rest) else rest
                    bones[bi]=bone
                end
                for bi,b in data.bones do bones[bi].Parent=if b.parent>0 then bones[b.parent] else mesh end
            end
            mesh.Parent=model
            table.insert(metadata,{name=mesh.Name,meshId=meshId,material=part.material,maps=part.maps,center={center.X,center.Y,center.Z}})
        end
        local controller=Instance.new("AnimationController");controller.Parent=model;Instance.new("Animator",controller)
        model.WorldPivot=CFrame.identity
        model:ScaleTo(0.670163170)
        local module=Instance.new("ModuleScript");module.Name=id;module.Source=H:GetAsync(BASE.."payload/"..id.."-Clips.luau");module.Parent=clips
        model.Parent=models
        receiptFolder:SetAttribute("model_"..id,H:JSONEncode(metadata))
    end)
    if not ok then model:Destroy();error(err) end
    return {id=id,parts=#data.parts,bones=18,clips=6}
end
function Import.Receipts()
    local r={placeId=game.PlaceId,creatorId=game.CreatorId,attributes=receiptFolder:GetAttributes()}
    H:PostAsync(BASE.."import-receipts.json",H:JSONEncode(r),Enum.HttpContentType.ApplicationJson)
    return r
end
return Import
