-- Number-only authored asset adjustment; execute in canonical Studio Edit.
assert(game.PlaceId == 96683186622050, "Wrong place")
assert(not game:GetService("RunService"):IsRunning(), "Edit only")
local gui = workspace.MyChickenArmyMap["03_HomePlots"].EggCollectionBoard.Screen.SurfaceGui
local count = gui.EggSellingBoard.Content.QueuedCount
assert(not count:FindFirstChild("FigmaTextScale"), "Already applied; inspect rather than scaling twice")
assert(count.TextScaled and count.TextSize == 100, "Authored count changed; compare before applying")
local storage = game:GetService("ServerStorage")
assert(not storage:FindFirstChild("EggQueueTypographyBefore20260925"), "Backup exists; inspect before retrying")
local backup = gui:Clone()
backup.Name = "EggQueueTypographyBefore20260925"
backup.Parent = storage
local originalSize = count.Size
local factor = 1.375 -- 10,000 occupies ~63% of its row, matching the Figma reference.
count.Size = UDim2.new(originalSize.X.Scale / factor, originalSize.X.Offset / factor,
 originalSize.Y.Scale / factor, originalSize.Y.Offset / factor)
count.TextScaled = false
count.TextWrapped = false
local scale = Instance.new("UIScale")
scale.Name, scale.Scale, scale.Parent = "FigmaTextScale", factor, count
-- Retain the existing visible outline thickness while enlarging the glyphs.
local outline = count:FindFirstChildWhichIsA("UIStroke")
if outline then outline.Thickness /= factor end
return {backup = backup:GetFullName(), count = count:GetFullName(), factor = factor}
