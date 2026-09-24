-- Run once in canonical Studio Edit after UITheme has synced through Rojo.
-- Authored art only: no mapped script Source writes and no board rebuilding.
assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning())
local source=game.StarterPlayer.StarterPlayerScripts.PetRoll.UITheme
assert(source.Source:find("93331178043153",1,true),"Sync the full-sheet UITheme first")
local fresh=source:Clone()
fresh.Name="StudSheetThemeMigration"
fresh.Parent=source.Parent
local ok,theme=pcall(require,fresh)
fresh:Destroy()
assert(ok,theme)
local targets={}
for _,root in {workspace,game.StarterGui,game.ReplicatedStorage} do
	for _,item in root:GetDescendants() do
		local path=item:GetFullName()
		if item:IsA("ImageLabel") and item.Name=="StudTexture"
			and not path:find("Backup") and not path:find("Recovery") and not path:find("Before")
			and item.Parent:GetAttribute("StudSheetClip")~=true then
			table.insert(targets,item)
		end
	end
end
if #targets==0 then return {changed=0} end
local history=game:GetService("ChangeHistoryService")
local recording=history:TryBeginRecording("StudSheetMigration","Crop full-sheet stud artwork")
local backup=Instance.new("Folder")
backup.Name="StudSheetBackup_"..tostring(os.time())
backup.Parent=game.ServerStorage
local changed={}
for index,item in targets do
	local entry=Instance.new("Folder")
	entry.Name=tostring(index)
	entry:SetAttribute("OriginalPath",item:GetFullName())
	entry.Parent=backup
	local pointer=Instance.new("ObjectValue")
	pointer.Name,pointer.Value,pointer.Parent="OriginalParent",item.Parent,entry
	item:Clone().Parent=entry
	theme.BindStudTexture(item)
	table.insert(changed,item:GetFullName())
end
if recording then history:FinishRecording(recording,Enum.FinishRecordingOperation.Commit) end
return {changed=changed,backup=backup:GetFullName(),texture=theme.Assets.Studs}
