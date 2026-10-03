-- Run through Studio Flow in Edit after sync. No player data or world edits.
assert(not game:GetService("RunService"):IsRunning())
local module=game.StarterPlayer.StarterPlayerScripts.PetRoll.FlowingChickenTexture
assert(module.Source:find("cache.tween=nil",1,true),"Final cleanup fix is not synced")
local Flow=require(module)
local folder=Instance.new("Folder")
local model=game.ReplicatedStorage.PetRoll.ChickenAssets.StormDuck:Clone()
model:PivotTo(CFrame.identity)
model.Parent=folder
local camera=Instance.new("Camera")
camera.CFrame=CFrame.new(0,0,10)
local body=model.Body
local originalMesh=body.MeshId
local originalSurface=body:FindFirstChildOfClass("SurfaceAppearance")
local animation=Flow.new(model,"Galaxy")
local cache=animation.cache
local ok,result=pcall(function()
 animation:Step(os.clock(),false,camera)
 local deadline=os.clock()+15
 while cache.state=="loading" and os.clock()<deadline do task.wait() end
 animation:Step(os.clock(),false,camera)
 assert(animation.state=="ready",tostring(animation.error or cache.error))
 assert(body:FindFirstChildOfClass("SurfaceAppearance").Name=="GalaxyAnimatedPBR")
 animation:Destroy()
 assert(cache.references==0 and cache.state=="idle")
 for _,name in {"tween","phase","mesh","image","display","surface","emissive","uvs"} do
  assert(cache[name]==nil,"Resource retained: "..name)
 end
 assert(body.MeshId==originalMesh)
 assert(body:FindFirstChildOfClass("SurfaceAppearance")==originalSurface)
 local bones=0
 for _,item in body:GetDescendants() do if item:IsA("Bone") then bones+=1 end end
 assert(bones==18)
 -- A cancelled load must never attach after its last consumer is destroyed.
 local cancelled=Flow.new(model,"Galaxy")
 cancelled:Step(os.clock(),false,camera)
 cancelled:Destroy()
 task.wait(0.5)
 assert(cache.state=="idle" and cache.references==0 and cache.mesh==nil)
 assert(body.MeshId==originalMesh and body:FindFirstChildOfClass("SurfaceAppearance")==originalSurface)
 return {ready=true,allResourcesReleased=true,originalMeshAndMaterialRestored=true,bones=bones,cancelledLoadStaysDetached=true}
end)
animation:Destroy()
folder:Destroy()
camera:Destroy()
if not ok then error(result) end
return result
