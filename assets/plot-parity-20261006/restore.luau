-- Recovery only. Requires a later explicit request to restore the old plots.
assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning())
local homes = workspace.MyChickenArmyMap["03_HomePlots"]
local archive = game.ServerStorage.PlotParityArchive20261006
assert(not archive:FindFirstChild("ParityPlotsAfterRestore"), "Already restored; inspect archive")
for index=2,6 do assert(archive.OriginalPlots:FindFirstChild("Plot"..index) and homes:FindFirstChild("Plot"..index)) end
local history=game:GetService("ChangeHistoryService")
local recording=history:TryBeginRecording("RestoreOldHomePlots20261006", "Restore previous home plots")
assert(recording)
local preserved=Instance.new("Folder")
preserved.Name="ParityPlotsAfterRestore"
preserved.Parent=archive
for index=2,6 do
    homes["Plot"..index].Parent=preserved
    archive.OriginalPlots["Plot"..index].Parent=homes
end
history:FinishRecording(recording,Enum.FinishRecordingOperation.Commit)
return {restored=true,newPlotsPreserved=preserved:GetFullName()}
