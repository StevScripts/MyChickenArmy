-- Studio Edit asset recipe. Does not write any mapped script source.
assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning())
local board = workspace.MyChickenArmyMap["03_HomePlots"].EggCollectionBoard
local screen, pad = board.Screen, board.CollectionPart.TouchPart
local gui = screen:FindFirstChildOfClass("SurfaceGui")
assert(gui and pad:FindFirstChildOfClass("SurfaceGui"))
local storage = game:GetService("ServerStorage")
if not storage:FindFirstChild("EggCollectionBoardBefore20260924") then
	local backup = board:Clone()
	backup.Name, backup.Parent = "EggCollectionBoardBefore20260924", storage
end
local Theme = require(game.StarterPlayer.StarterPlayerScripts.PetRoll.UITheme)
local ink, white, gold = Color3.fromRGB(16,23,16), Color3.fromRGB(255,254,245), Color3.fromRGB(255,222,41)
local prior = gui:FindFirstChild("EggSellingBoard")
if prior then prior:Destroy() end
board:SetAttribute("PlotIndex", 1)
gui.SizingMode, gui.CanvasSize = Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(576,864)
gui.AlwaysOnTop, gui.LightInfluence, gui.MaxDistance, gui.Active = false, 0, 100, true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local panel = Theme.Frame(gui,"EggSellingBoard",UDim2.fromScale(1,1),Color3.new(1,1,1))
panel:SetAttribute("FigmaNode", "328:885")
local gradient = Theme.Gradient(panel,Color3.fromRGB(20,22,24),Color3.fromRGB(3,4,5))
gradient.Transparency = NumberSequence.new(0.42,0.62)
Theme.Stroke(panel,white,1)
-- Preserve the Figma component's aspect and typography on the taller authored screen.
local content = Theme.Frame(panel,"Content",UDim2.fromOffset(576,588))
content.AnchorPoint,content.Position,content.BackgroundTransparency = Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),1
local function label(name,text,y,height,size,color)
	local item = Theme.Label(content,name,text,size,color)
	item.Position,item.Size = UDim2.fromOffset(25,y),UDim2.fromOffset(526,height)
	item.TextXAlignment,item.TextWrapped = Enum.TextXAlignment.Center,false
	item.TextOutline.Color = ink
	item.TextOutline.Thickness = if name=="QueuedCount" then 6 else 3
	return item
end
local count=label("QueuedCount","0",54,190,88,gold)
-- Roblox caps TextSize at 100; native UIScale keeps the 176px Figma headline.
count.Position,count.Size=UDim2.fromOffset(25,54),UDim2.fromOffset(263,95)
count.TextScaled=false
count.TextOutline.Thickness=3
local countScale=Instance.new("UIScale")
countScale.Scale,countScale.Parent=2,count
label("Rate","2 eggs/sec",256,60,48,white)
label("UpgradeCost","Cost: $480",328,42,34,gold)
local function action(name,text,x,y,width,height,size)
	local button = Theme.Button(content,name,text,function() end,Theme.Arcade.green)
	button.Position,button.Size,button.TextSize,button.TextColor3 = UDim2.fromOffset(x,y),UDim2.fromOffset(width,height),size,white
	local visual = button.Visual
	visual.UIStroke.Color = ink
	visual.LowerLip.BackgroundColor3 = ink
	local face = visual.Face
	Theme.Gradient(face,Color3.fromRGB(176,255,1),Color3.fromRGB(23,223,0))
	Theme.Studs(face,0.14,28,0)
	face.InsetHighlight.UIStroke.Color = white
	return button
end
action("Upgrade","Upgrade",25,378,526,84,44)
action("FinishNow","Finish Now",104,474,368,60,32)
local title = board.Text.BillboardGui:FindFirstChildWhichIsA("TextLabel")
if title then title.Text="EGGS SELLING";board.Text.BillboardGui.Enabled=true end
local cashGui = pad:FindFirstChildOfClass("SurfaceGui")
cashGui:SetAttribute("EggCashDisplay",true)
cashGui.AlwaysOnTop,cashGui.LightInfluence,cashGui.MaxDistance = false,0,100
local cash = cashGui:FindFirstChildWhichIsA("TextLabel")
assert(cash)
cash.Name,cash.Text = "ReadyCash","$0"
return {board=board:GetFullName(),surface=gui:GetFullName(),cash=cash:GetFullName(),buttons=2,backup="ServerStorage.EggCollectionBoardBefore20260924"}
