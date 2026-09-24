-- Run in canonical Studio Edit via Studio Flow. Never writes mapped script Source.
-- Historical first pass; already applied. Use apply-sheet-studio.luau for the full sheet.
local TEXTURE = "rbxassetid://114518181344801"
assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning())
local legacyNames = {StudPattern=true, FigmaStuds=true, PopupStudTexture=true, CheckerPattern=true}
local targets = {}
local function isBackup(item)
	local path=item:GetFullName()
	return string.find(path,"Before") or string.find(path,"Backup") or string.find(path,"Recovery")
end
for _,service in {workspace,game.StarterGui,game.ReplicatedStorage,game.ServerStorage} do
	for _,item in service:GetDescendants() do
		if item:IsA("Frame") and legacyNames[item.Name] and not isBackup(item) then
			table.insert(targets,item)
		end
	end
end
local history=game:GetService("ChangeHistoryService")
local recording=history:TryBeginRecording("StudTextureMigration","Replace generated UI studs with tiled images")
local backup=Instance.new("Folder")
backup.Name="StudTextureBackup_"..tostring(os.time())
backup.Parent=game.ServerStorage
local replaced,removed={},0
for index,old in targets do
	local parent=old.Parent
	assert(not parent:FindFirstChild("StudTexture"),"Unexpected duplicate pattern: "..parent:GetFullName())
	local entry=Instance.new("Folder")
	entry.Name=tostring(index)
	entry:SetAttribute("OriginalPath",old:GetFullName())
	entry.Parent=backup
	local pointer=Instance.new("ObjectValue")
	pointer.Name,pointer.Value,pointer.Parent="OriginalParent",parent,entry
	local image=Instance.new("ImageLabel")
	image.Name,image.Image="StudTexture",TEXTURE
	image.Size,image.Position,image.AnchorPoint=old.Size,old.Position,old.AnchorPoint
	image.Rotation,image.LayoutOrder,image.Visible=old.Rotation,old.LayoutOrder,old.Visible
	image.ZIndex,image.BackgroundTransparency,image.BorderSizePixel=old.ZIndex,1,0
	image.Active,image.Selectable=false,false
	image.ScaleType,image.TileSize=Enum.ScaleType.Tile,UDim2.fromOffset(28,28)
	image.ImageTransparency=0.86
	image.Parent=parent
	removed+=#old:GetDescendants()
	table.insert(replaced,{path=image:GetFullName(),oldInstances=1+#old:GetDescendants(),newInstances=1})
	old.Parent=entry -- Recoverable; no original art is destroyed.
end
if recording then history:FinishRecording(recording,Enum.FinishRecordingOperation.Commit) end
return {backup=backup:GetFullName(),replaced=replaced,activeInstancesRemoved=removed,texture=TEXTURE}
