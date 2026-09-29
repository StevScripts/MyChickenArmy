assert(game.PlaceId==96683186622050 and not game:GetService("RunService"):IsRunning(),"Expected canonical Edit mode")
local p=workspace.MyChickenArmyMap["03_HomePlots"].Plot1
local deck=p.Deck
assert(math.abs(deck.Size.Z-131.85366821289062)<0.01,"Plot deck changed since inspection")
local fence=p.Props.BoundaryFence
assert(fence:GetAttribute("ExpansionMaxBack")==52.5 and fence:GetAttribute("ExpansionLateDepth")==nil,"Fence settings changed")
local history=game:GetService("ChangeHistoryService")
local record=history:TryBeginRecording("PlotCapacity10020260929","Fit final plot expansions to enlarged deck")
assert(record,"Unable to record asset undo")
local ok,err=pcall(function()
fence:SetAttribute("ExpansionMaxBack",62.5)
fence:SetAttribute("ExpansionLateDepth",20)
p.ChickenYard:SetAttribute("BuilderNote","30x30 square starter; stages 0-5 stay fixed. Final stages add a 72x30 then 84x45 back section for 75 and 100 chickens. HomePlotLayout.TeeYard anchors to the authored starter square.")
end)
history:FinishRecording(record,if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
assert(ok,err)
return game:GetService("HttpService"):JSONEncode({fence=fence:GetAttributes(),yard=p.ChickenYard:GetAttributes()})
