-- Run only after an explicit request to restore timed processing, in Studio Edit.
-- Set EggProcessorConfig.Enabled=true in the local source and sync through Rojo first.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning(),"Expected Pet Roll Test Edit")
local archive=game.ServerStorage:FindFirstChild("EggProcessingArchive20260929")
assert(archive and archive:FindFirstChild("Boards"),"Missing processor board archive")
local moves={}
for _,slot in archive.Boards:GetChildren() do
 local board=slot:FindFirstChild("EggCollectionBoard")
 assert(board,"Missing archived board for "..slot.Name)
 local parent=game
 for name in string.gmatch(assert(slot:GetAttribute("OriginalParent")),"[^.]+") do
  parent=assert(parent:FindFirstChild(name),"Missing original parent: "..name)
 end
 assert(not parent:FindFirstChild("EggCollectionBoard"),"A board already exists at "..parent:GetFullName())
 table.insert(moves,{board=board,parent=parent})
end
assert(#moves==6,"Expected all six boards")
for _,move in moves do move.board.Parent=move.parent end
return "Restored six original boards. Restart Play, then save the place separately."
