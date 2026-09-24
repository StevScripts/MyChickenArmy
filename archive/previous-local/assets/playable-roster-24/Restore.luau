-- Manual Edit-only recovery. Preserves the previous library before replacing it.
-- The cloud model contains compiled PBR materials; URI-only reconstruction loses them.
return function()
 assert(not game:GetService("RunService"):IsRunning(), "Stop Play before restoring assets")
 assert(game.PlaceId==96683186622050 or game.PlaceId==0, "Wrong place")
 local pr=game.ReplicatedStorage:FindFirstChild("PetRoll");assert(pr,"PetRoll scripts missing")
 local loaded=game:GetService("InsertService"):LoadAsset(90448514099760)
 local assets=loaded:FindFirstChild("ChickenAssets",true)
 local clips=loaded:FindFirstChild("ChickenClips",true)
 assert(assets and clips and #assets:GetChildren()==32 and #clips:GetChildren()==32,"Incomplete asset recovery")
 -- The classic rider and its compiled material postdate the full roster archive.
 local riderPackage=game:GetService("InsertService"):LoadAsset(93328318042523)
 local rider=riderPackage:FindFirstChild("Jockey",true)
 assert(rider and rider:FindFirstChild("Body"),"Updated Jockey recovery missing")
 assets.Jockey:Destroy() -- This is the freshly loaded archive, not the live library.
 rider.Parent=assets;riderPackage:Destroy()
 local before=Instance.new("Folder");before.Name="BeforeRosterRestore_"..os.time();before.Parent=game.ServerStorage
 for _,name in {"ChickenAssets","ChickenClips"} do
  local old=pr:FindFirstChild(name);if old then old.Parent=before end
 end
 assets.Parent=pr;clips.Parent=pr;loaded:Destroy()
 return {models=32,clips=32,backup=before:GetFullName()}
end
