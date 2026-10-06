-- Read-only structural and transform audit after apply.luau.
assert(game.PlaceId == 96683186622050)
local homes = workspace.MyChickenArmyMap["03_HomePlots"]
local archive = game.ServerStorage.PlotParityArchive20261006
local template = archive.Plot1Template
local function close(a, b, tolerance)
    if typeof(a) == "CFrame" then
        local aa, bb = {a:GetComponents()}, {b:GetComponents()}
        for k, value in aa do assert(math.abs(value - bb[k]) < tolerance, "CFrame mismatch") end
    elseif typeof(a) == "Vector3" then
        assert((a-b).Magnitude < tolerance, "Vector mismatch")
    else assert(a == b, "Property mismatch") end
end
local function sibling(parent, name, class, ordinal)
    local n = 0
    for _, child in parent:GetChildren() do
        if child.Name == name and child.ClassName == class then
            n += 1
            if n == ordinal then return child end
        end
    end
    return nil
end
local function audit(reference, plot, index)
    local pairs, partCount, jointCount = {}, 0, 0
    local function authoredChildren(root)
        local children = {}
        for _, child in root:GetChildren() do
            -- Humanoid/accessory engine bookkeeping can appear after parenting.
            if child.ClassName == "Status" or child:IsA("TouchTransmitter") then continue end
            if child.Archivable then table.insert(children, child)
            else assert(child.ClassName == "Status", "Unexpected non-archivable content") end
        end
        return children
    end
    local function visit(a, b)
        assert(b and a.ClassName == b.ClassName, "Hierarchy mismatch")
        pairs[a] = b
        assert(#authoredChildren(a) == #authoredChildren(b), "Child count mismatch: " .. a:GetFullName() .. " -> " .. b:GetFullName())
        local seen = {}
        for _, child in authoredChildren(a) do
            local key = child.ClassName .. ":" .. child.Name
            seen[key] = (seen[key] or 0) + 1
            visit(child, sibling(b, child.Name, child.ClassName, seen[key]))
        end
    end
    visit(reference, plot)
    for a, b in pairs do
        for key, value in a:GetAttributes() do
            if a == reference and key == "PlotIndex" then close(b:GetAttribute(key), index, 0)
            else close(b:GetAttribute(key), value, 0.0001) end
        end
        if a:IsA("BasePart") then
            partCount += 1
            close(a.Size, b.Size, 0.0001)
            if index == 1 then close(a.CFrame, b.CFrame, 0.0001) end
            local expected = reference.Deck.CFrame:ToObjectSpace(a.CFrame)
            local actual = plot.Deck.CFrame:ToObjectSpace(b.CFrame)
            close(expected, actual, 0.003)
            for _, key in {"Anchored", "CanCollide", "CanTouch", "CanQuery", "CollisionGroup", "Color", "Material", "Transparency"} do
                close(a[key], b[key], 0)
            end
        end
        local props = {}
        if a:IsA("ObjectValue") then table.insert(props, "Value") end
        if a:IsA("JointInstance") or a:IsA("WeldConstraint") then
            table.insert(props, "Part0"); table.insert(props, "Part1")
        end
        if a:IsA("Constraint") or a:IsA("Beam") or a:IsA("Trail") then
            table.insert(props, "Attachment0"); table.insert(props, "Attachment1")
        end
        if a:IsA("BillboardGui") or a:IsA("SurfaceGui") or a:IsA("Highlight") then table.insert(props, "Adornee") end
        if a:IsA("Model") then table.insert(props, "PrimaryPart") end
        for _, key in props do
            local ok, value = pcall(function() return a[key] end)
            if ok then
                local expected = if value and pairs[value] then pairs[value] else value
                assert(b[key] == expected, "Reference mismatch: " .. a:GetFullName() .. "." .. key)
                jointCount += 1
            end
        end
    end
    local title = plot.Props["Your Plot"]:FindFirstChildWhichIsA("TextLabel", true)
    assert(title.Text == "HOME " .. index .. " · OPEN")
    local ramp = plot:FindFirstChild("EntranceWalkRamp", true)
    local old = archive.OriginalPlots:FindFirstChild(plot.Name)
    local error = if old then (ramp.Position-old:FindFirstChild("EntranceWalkRamp", true).Position).Magnitude else 0
    assert(error < 0.002)
    return {plot=index,parts=partCount,references=jointCount,descendants=#plot:GetDescendants(),entranceDelta=error,
        deck=tostring(plot.Deck.Size),yard=plot.ChickenYard:GetAttribute("ExpansionShape")}
end
local result = {}
for index=1,6 do table.insert(result, audit(template, homes["Plot"..index], index)) end
return {ok=true,plots=result,archive=archive:GetFullName()}
