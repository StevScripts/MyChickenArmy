-- Edit-only, task-scoped asset import. No gameplay source writes or map replacement.
local A=game:GetService('AssetService')
local H=game:GetService('HttpService')
local BASE='http://127.0.0.1:18794/'
assert(game.PlaceId==96683186622050 and not game:GetService('RunService'):IsRunning(),'Wrong place/state')
assert(game.CreatorId==778575811,'Unexpected owner')
local function folder(p,n)local f=p:FindFirstChild(n);if not f then f=Instance.new('Folder');f.Name=n;f.Parent=p end;return f end
local receipts=folder(game.ServerStorage,'EggVacuumImportReceipts')
local staged=folder(game.ServerStorage,'EggVacuumImport')
local function get(path)return H:JSONDecode(H:GetAsync(BASE..path))end
local function upload(o,kind,name)
 local status,id=A:CreateAssetAsync(o,kind,{CreatorId=778575811,CreatorType=Enum.AssetCreatorType.Group,Name='Chicken Army Vacuum '..name,Description='User supplied Tripo egg vacuum; articulated wheel/nozzle parts'})
 assert(status==Enum.CreateAssetResult.Success,tostring(status)..': '..tostring(id));return tonumber(id)
end
local function v3(t)return Vector3.new(t[1],t[2],t[3])end
local Import={}
function Import.Images(first,last)
 local images=get('export/images.json')
 for i=first,math.min(last,#images) do
  local def=images[i];local key='image_'..def.key
  if not receipts:GetAttribute(key) then
   local img=A:CreateEditableImage({Size=Vector2.new(def.width,def.height)});assert(img)
   local ok,id=pcall(function()
    img:WritePixelsBuffer(Vector2.zero,img.Size,buffer.fromstring(H:GetAsync(BASE..'export/image-'..def.key..'.rgba')))
    return upload(img,Enum.AssetType.Image,def.key..' Color')
   end)
   img:Destroy();assert(ok,id);receipts:SetAttribute(key,id)
  end
 end
 return {done=last,total=#images}
end
function Import.Part(index)
 local data=get('export/model.json');local part=data.parts[index];assert(part)
 local existing=staged:FindFirstChild(part.name);if existing then return {part=part.name,existing=true} end
 local min,max=Vector3.one*math.huge,-Vector3.one*math.huge
 for _,p in part.positions do local v=v3(p);min=min:Min(v);max=max:Max(v) end
 local center=(min+max)/2
 local id=receipts:GetAttribute('mesh_'..part.name)
 if not id then
  local em=A:CreateEditableMesh();assert(em)
  local ok,result=pcall(function()
   local verts,norms,uvs={},{},{}
   for i,p in part.positions do
    verts[i]=em:AddVertex(v3(p)-center);norms[i]=em:AddNormal(v3(part.normals[i]));uvs[i]=em:AddUV(Vector2.new(part.uvs[i][1],part.uvs[i][2]))
   end
   for i=1,#part.indices,3 do
    local x,y,z=part.indices[i],part.indices[i+1],part.indices[i+2]
    local face=em:AddTriangle(verts[x],verts[y],verts[z]);em:SetFaceNormals(face,{norms[x],norms[y],norms[z]});em:SetFaceUVs(face,{uvs[x],uvs[y],uvs[z]})
   end
   return upload(em,Enum.AssetType.Mesh,part.name)
  end)
  em:Destroy();assert(ok,result);id=result;receipts:SetAttribute('mesh_'..part.name,id)
 end
 local p=A:CreateMeshPartAsync(Content.fromUri('rbxassetid://'..id));p.Name=part.name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true
 p.CFrame=CFrame.new(center);p.Color=Color3.new(1,1,1);p.Material=Enum.Material.SmoothPlastic;p.RenderFidelity=Enum.RenderFidelity.Precise
 local key=part.texture:match('_part_(%d+)_');local imageId=receipts:GetAttribute('image_'..key);assert(imageId,'Upload image first')
 -- Native TextureID stays portable in saved places; source JPEGs stay in the Blender master.
 p.TextureID='rbxassetid://'..imageId
 p:SetAttribute('RestCFrame',p.CFrame);p:SetAttribute('RestSize',p.Size);p:SetAttribute('SourceTriangles',part.sourceTriangles);p.Parent=staged
 return {part=part.name,id=id,size={p.Size.X,p.Size.Y,p.Size.Z},center={center.X,center.Y,center.Z}}
end
function Import.Finish()
 assert(#staged:GetChildren()==9,'Expected nine articulated pieces')
 local assets=folder(game.ReplicatedStorage.PetRoll,'Assets')
 assert(not assets:FindFirstChild('EggVacuum'),'Template already exists; preserve it')
 local m=Instance.new('Model');m.Name='EggVacuum'
 for _,p in staged:GetChildren() do p:Clone().Parent=m end
 m.WorldPivot=CFrame.identity;m:SetAttribute('AuthoredScale',4.2);m:SetAttribute('Source','EggVacuum-Animated.blend');m.Parent=assets
 H:PostAsync(BASE..'export/receipts.json',H:JSONEncode({placeId=game.PlaceId,attributes=receipts:GetAttributes()}),Enum.HttpContentType.ApplicationJson)
 game:GetService('ChangeHistoryService'):SetWaypoint('Import animated egg vacuum template')
 return {parts=#m:GetChildren(),path=m:GetFullName()}
end
return Import
