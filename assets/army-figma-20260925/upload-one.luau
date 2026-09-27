-- Run via Studio Flow in Edit; returns a function. Never writes mapped Source.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning())
assert(game.CreatorId==778575811 and game.CreatorType==Enum.CreatorType.Group)
local Http=game:GetService("HttpService")
local Assets=game:GetService("AssetService")
local root=game.ServerStorage:FindFirstChild("ArmyPortraitOutlineUploads20260925")
if not root then
 root=Instance.new("Folder");root.Name="ArmyPortraitOutlineUploads20260925";root.Parent=game.ServerStorage
end
return function(species)
 assert(type(species)=="string" and species:match("^[%w]+$"))
 local base="http://127.0.0.1:18825/"
 local metadata=Http:JSONDecode(Http:GetAsync(base.."metadata/"..species,true))
 local record=root:FindFirstChild(species)
 if record then assert(record:GetAttribute("SourceSha256")==metadata.outlinedSha256,"Different portrait already recorded") end
 if metadata.outlinedAssetId then
  return {species=species,assetId=metadata.outlinedAssetId,reused=true}
 end
 if not record then
  record=Instance.new("Folder");record.Name=species
  record:SetAttribute("SourceSha256",metadata.outlinedSha256);record.Parent=root
 end
 local id=record:GetAttribute("ImageAssetId")
 if not id then
  assert(not record:GetAttribute("UploadStarted"),"Unresolved upload: inspect its retained operation before retrying")
  local bytes=Http:GetAsync(base.."pixels/"..species,true)
  assert(#bytes==metadata.width*metadata.height*4,"Invalid pixel buffer")
  local image=assert(Assets:CreateEditableImage({Size=Vector2.new(metadata.width,metadata.height)}),"No editable image memory")
  image:WritePixelsBuffer(Vector2.zero,image.Size,buffer.fromstring(bytes))
  record:SetAttribute("UploadStarted",true)
  local ok,status,assetId=pcall(function()
   return Assets:CreateAssetAsync(image,Enum.AssetType.Image,{
    Name="MCA Outlined "..species.." 20260925",
    Description="Original My Chicken Army portrait with a black silhouette border. Original artwork preserved.",
    CreatorId=778575811,CreatorType=Enum.AssetCreatorType.Group,
   })
  end)
  image:Destroy()
  if not ok then record:SetAttribute("UploadError",tostring(status));error(status) end
  record:SetAttribute("UploadResult",tostring(status))
  assert(status==Enum.CreateAssetResult.Success,tostring(status)..": "..tostring(assetId))
  id=tostring(assetId);record:SetAttribute("ImageAssetId",id)
 end
 local receipt={assetId=tostring(id),sha256=metadata.outlinedSha256,creatorGroupId=778575811}
 local response=Http:RequestAsync({Url=base.."receipt/"..species,Method="POST",
  Headers={["Content-Type"]="application/json"},Body=Http:JSONEncode(receipt)})
 assert(response.Success,"Upload succeeded; receipt write needs recovery: "..tostring(id))
 return {species=species,assetId=tostring(id),receipt=Http:JSONDecode(response.Body)}
end
