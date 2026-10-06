-- Studio Edit operation. Run once in Pet Roll Test, after stopping Play.
-- All geometry comes from the authored Plot1; no gameplay scripts are changed.
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local History = game:GetService("ChangeHistoryService")
assert(game.PlaceId == 96683186622050 and not RunService:IsRunning(), "Pet Roll Test Edit required")

local homes = workspace.MyChickenArmyMap["03_HomePlots"]
local source = homes.Plot1
local archiveName = "PlotParityArchive20261006"
assert(not ServerStorage:FindFirstChild(archiveName), "Parity archive already exists; inspect before repeating")
local sourceDeck = source:FindFirstChild("Deck")
local sourceRamp = source:FindFirstChild("EntranceWalkRamp", true)
assert(sourceDeck and sourceDeck:IsA("BasePart") and sourceRamp and sourceRamp:IsA("BasePart"))

local function count(root, predicate)
    local n = 0
    for _, child in root:GetDescendants() do if predicate(child) then n += 1 end end
    return n
end
local function facilities(plot, index)
    assert(plot:GetAttribute("PlotIndex") == index, "Wrong plot identity")
    assert(plot:GetAttribute("AuthoredPlot") and plot:GetAttribute("EggDepositEnabled"))
    assert(count(plot, function(x) return x.Name == "RollDisplay" and x:IsA("BasePart") end) == 8)
    assert(count(plot, function(x) return x.Name == "RollLever" and x:IsA("BasePart") end) == 1)
    assert(count(plot, function(x) return x.Name == "Fuse_Machine" end) == 1)
    assert(count(plot, function(x) return x.Name == "sellpart" and x:IsA("BasePart") end) == 1)
    assert(count(plot, function(x) return x:GetAttribute("AutoCollectStand") == true end) == 1)
    assert(count(plot, function(x) return x:IsA("LuaSourceContainer") end) == 0)
    assert(plot.ChickenYard:GetAttribute("ExpansionShape") == "T")
    assert(plot.Anchors:FindFirstChild("Spawn") and plot.Anchors:FindFirstChild("Yard"))
    for n = 1, 8 do
        local podium = plot.Spin:FindFirstChild("DisplayPodium" .. (if n == 1 then "" else tostring(n)))
        assert(podium and podium:FindFirstChild("RollDisplay"), "Missing numbered podium")
    end
end
facilities(source, 1)
local function cloneCount(root)
    local n = 0
    for _, child in root:GetChildren() do
        if child.ClassName == "Status" or child:IsA("TouchTransmitter") then continue end
        if child.Archivable then n += 1 + cloneCount(child)
        else assert(child.ClassName == "Status", "Non-archivable authored content: " .. child:GetFullName()) end
    end
    return n
end

local originals, copies, report = {}, {}, {}
for index = 2, 6 do
    local old = homes:FindFirstChild("Plot" .. index)
    assert(old and old:GetAttribute("PlotIndex") == index)
    originals[index] = old
end

-- References from outside a replaced plot must be explicitly handled, never broken.
for _, object in game:GetDescendants() do
    local properties = {}
    if object:IsA("ObjectValue") then table.insert(properties, "Value") end
    if object:IsA("JointInstance") or object:IsA("WeldConstraint") then
        table.insert(properties, "Part0"); table.insert(properties, "Part1")
    end
    if object:IsA("Constraint") or object:IsA("Beam") or object:IsA("Trail") then
        table.insert(properties, "Attachment0"); table.insert(properties, "Attachment1")
    end
    if object:IsA("BillboardGui") or object:IsA("SurfaceGui") or object:IsA("Highlight") then
        table.insert(properties, "Adornee")
    end
    for _, property in properties do
        local ok, reference = pcall(function() return object[property] end)
        if ok and typeof(reference) == "Instance" then
            for _, old in originals do
                if reference == old or reference:IsDescendantOf(old) then
                    assert(object == old or object:IsDescendantOf(old), "External plot reference: " .. object:GetFullName())
                end
            end
        end
    end
end

-- Prepare every copy detached before changing the map. Preserve each existing
-- entrance/road connection while the enlarged deck extends out behind it.
for index = 2, 6 do
    local old = originals[index]
    local deck = old:FindFirstChild("Deck")
    local ramp = old:FindFirstChild("EntranceWalkRamp", true)
    assert(deck and deck:IsA("BasePart") and ramp and ramp:IsA("BasePart"))
    local rotation = deck.CFrame.Rotation * sourceDeck.CFrame.Rotation:Inverse()
    local delta = CFrame.new(ramp.Position) * rotation * CFrame.new(-sourceRamp.Position)
    local copy = source:Clone()
    assert(copy and cloneCount(copy) == cloneCount(source), "Incomplete template clone")
    copy.Name = "Plot" .. index
    copy:SetAttribute("PlotIndex", index)
    local title = copy.Props["Your Plot"]:FindFirstChildWhichIsA("TextLabel", true)
    assert(title and title.Text == "HOME 1 · OPEN", "Unexpected editor owner label")
    title.Text = "HOME " .. index .. " · OPEN"

    -- Native PivotTo moves parts and nested model pivots as one assembly. Local
    -- attachments, rig joints, vacuum RestCFrame and size metadata stay local.
    local carrier = Instance.new("Model")
    copy.Parent = carrier
    carrier:PivotTo(delta * carrier:GetPivot())
    copy.Parent = nil
    carrier:Destroy()
    facilities(copy, index)
    local newRamp = copy:FindFirstChild("EntranceWalkRamp", true)
    assert((newRamp.Position - ramp.Position).Magnitude < 0.002, "Entrance moved")
    assert((copy.Deck.Size - sourceDeck.Size).Magnitude < 0.001)
    copies[index] = copy
    table.insert(report, {plot = index, descendants = #copy:GetDescendants(),
        entranceDelta = (newRamp.Position - ramp.Position).Magnitude,
        deckFrame = {copy.Deck.CFrame:GetComponents()}, deckSize = {copy.Deck.Size.X, copy.Deck.Size.Y, copy.Deck.Size.Z}})
end

local recording = History:TryBeginRecording("ChickenArmyPlotParity20261006", "Match all homes to Plot 1")
assert(recording, "Another Studio change recording is active")
local archive = Instance.new("Folder")
archive.Name = archiveName
archive:SetAttribute("OriginalParent", homes:GetFullName())
archive:SetAttribute("SourcePlot", source:GetFullName())
local template = source:Clone()
template.Name = "Plot1Template"
template.Parent = archive
local previous = Instance.new("Folder")
previous.Name = "OriginalPlots"
previous.Parent = archive
local ok, problem = pcall(function()
    archive.Parent = ServerStorage
    for index = 2, 6 do
        originals[index].Parent = previous
        copies[index].Parent = homes
    end
    for index = 1, 6 do facilities(homes["Plot" .. index], index) end
end)
if not ok then
    for index = 2, 6 do
        copies[index].Parent = nil
        originals[index].Parent = homes
        copies[index]:Destroy()
    end
    archive:Destroy()
    History:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
    error(problem)
end
History:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
return {ok = true, archive = archive:GetFullName(), sourceUnchanged = true, plots = report}
