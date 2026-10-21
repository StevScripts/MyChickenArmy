--!strict
-- Draws every plot's world leaderboards (Leaderboard1 = Strongest Army,
-- Leaderboard2 = Top Rebirths since October 14; its SurfaceGui keeps the old
-- Leaderboard_RobuxSpent name; Leaderboard3 = Most Robux Spent since October 15) from rankings the server publishes in
-- ReplicatedStorage.PetRoll.Leaderboards. Presentation only; uses the shared
-- UITheme kit: studded gradient header, dark content, outlined display text.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.UITheme)
local Motion: any = Theme.Motion -- untyped helpers; the alias keeps strict inference out of presentation calls

local Boards = {}
Boards.__index = Boards

local CANVAS = Vector2.new(500, 750) -- Screen part's Left face is 7.15 x 10.73 studs
-- Title and ranks only. Read from ~20 studs: 8 large rows fill the screen; the
-- list scrolls (mouse wheel or drag) when the server sends more ranks.
local ROWS = 8
local ROW_TOP, ROW_HEIGHT, ROW_GAP = 132, 70, 6
local EMPTY_TILE = Color3.fromRGB(58, 62, 70)
local STYLE = {
	ArmyPower = {model = "Leaderboard1", color = Theme.PageColors.Army, icon = Theme.Assets.Army, valueColor = Theme.Arcade.gold},
	Rebirths = {model = "Leaderboard2", surface = "RobuxSpent", color = Theme.ReferenceColors.Army, icon = Theme.Assets.Reenlist, valueColor = Theme.Arcade.green},
	-- October 15: the third board on every plot.
	RobuxSpent = {model = "Leaderboard3", surface = "MostRobux", color = Theme.PageColors.Shop, icon = Theme.Assets.Shop, valueColor = Theme.Arcade.green, money = true},
}
local MEDALS = {Theme.Arcade.gold, Color3.fromRGB(198, 208, 220), Color3.fromRGB(219, 134, 64)}

local function frame(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3?, transparency: number?)
	local item = Instance.new("Frame")
	item.Name, item.Position, item.Size = name, position, size
	item.BackgroundColor3, item.BackgroundTransparency = color or Color3.new(1, 1, 1), transparency or 0
	item.BorderSizePixel = 0
	item.Parent = parent
	return item
end

local function px(x: number, y: number) return UDim2.fromOffset(x, y) end

local function display(parent: Instance, name: string, text: string, size: number, position: UDim2, box: UDim2,
	color: Color3?, align: Enum.TextXAlignment?)
	local label = Theme.Display(parent, name, text, size, color)
	label.Position, label.Size = position, box
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.TextWrapped = false
	for _, layer in {label.TextFace, label.TextShadow} do layer.TextTruncate = Enum.TextTruncate.AtEnd end
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
end

local function formatValue(style, value: number): string
	if style.money then return "R$ " .. Theme.Money(value) end
	return Theme.Number(value)
end

function Boards.new(app)
	local self = setmetatable({app = app, views = {}, data = {}, thumbs = {}, connections = {}}, Boards)
	task.spawn(function() self:Start() end)
	return self
end

function Boards:Start()
	local folder = ReplicatedStorage:WaitForChild("PetRoll"):WaitForChild("Leaderboards", 120)
	if not folder then return end
	local function read(value: Instance)
		if not value:IsA("StringValue") or not STYLE[value.Name] then return end
		local ok, decoded = pcall(function() return HttpService:JSONDecode(value.Value) end)
		if ok and type(decoded) == "table" then
			self.data[value.Name] = decoded
			for _, view in self.views do if view.key == value.Name then self:Render(view) end end
		end
	end
	local function watch(value: Instance)
		if not value:IsA("StringValue") then return end
		read(value)
		table.insert(self.connections, value:GetPropertyChangedSignal("Value"):Connect(function() read(value) end))
	end
	for _, value in folder:GetChildren() do watch(value) end
	table.insert(self.connections, folder.ChildAdded:Connect(watch))
	-- Boards stream in and out with the map; attach to each Screen as it appears.
	local function consider(item: Instance)
		if item.Name ~= "Screen" or not item:IsA("BasePart") or not item.Parent then return end
		for key, style in STYLE do
			if item.Parent.Name == style.model then self:Attach(key, item) end
		end
	end
	for _, item in workspace:GetDescendants() do consider(item) end
	table.insert(self.connections, workspace.DescendantAdded:Connect(consider))
end

function Boards:Attach(key: string, screen: BasePart)
	if self.views[screen] then return end
	local style = STYLE[key]
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Adornee, gui.Face = "Leaderboard_" .. (style.surface or key), screen, Enum.NormalId.Left
	gui.SizingMode, gui.CanvasSize = Enum.SurfaceGuiSizingMode.FixedSize, CANVAS
	gui.LightInfluence, gui.MaxDistance, gui.ResetOnSpawn = 0, 160, false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local root = frame(gui, "Board", px(0, 0), UDim2.fromScale(1, 1))
	Theme.Gradient(root, Theme.OverlayColors.Top, Theme.OverlayColors.Bottom)
	Theme.Stroke(root, Theme.Arcade.border, 5)

	-- Header: the menu header recipe (gradient, studs, inset highlight, outlined title).
	local header = frame(root, "Header", px(0, 0), UDim2.new(1, 0, 0, 118))
	Theme.SetHeaderColor(header, style.color)
	local studs = Theme.Studs(header, 0.14, 28, 0)
	studs:SetAttribute("StudScaleWidth", 0.4)
	local rim = frame(header, "InsetHighlight", px(4, 4), UDim2.new(1, -8, 1, -8), nil, 1)
	Theme.Stroke(rim, Color3.new(1, 1, 1), 2).Transparency = 0.46
	frame(header, "Base", UDim2.new(0, 0, 1, -5), UDim2.new(1, 0, 0, 5), Theme.Arcade.border)
	local icon = Instance.new("ImageLabel")
	icon.Name, icon.Image, icon.BackgroundTransparency = "Icon", style.icon, 1
	icon.Position, icon.Size, icon.ZIndex = px(10, 10), px(98, 98), 5
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = header
	local data = self.data[key] or {}
	local title = display(header, "Title", data.title or "", 56, px(114, 16), UDim2.new(1, -124, 0, 82))
	title.ZIndex = 6


	local list = Instance.new("ScrollingFrame")
	list.Name, list.Position, list.Size = "Rows", px(12, ROW_TOP), UDim2.new(1, -24, 1, -(ROW_TOP + 12))
	list.BackgroundTransparency, list.BorderSizePixel, list.Active = 1, 0, true
	list.ScrollingDirection, list.ScrollBarThickness = Enum.ScrollingDirection.Y, 8
	list.ScrollBarImageColor3, list.VerticalScrollBarInset = style.color, Enum.ScrollBarInset.Always
	list.CanvasSize, list.AutomaticCanvasSize = UDim2.new(), Enum.AutomaticSize.None
	list.Parent = root
	local rows = {}
	local view = {key = key, style = style, gui = gui, screen = screen, title = title, rows = rows, list = list}
	self.views[screen] = view
	-- Hide the board's old authored title billboard locally.
	for _, item in (screen.Parent :: Instance):GetDescendants() do
		if item:IsA("BillboardGui") then item.Enabled = false end
	end
	table.insert(self.connections, screen.AncestryChanged:Connect(function()
		if screen:IsDescendantOf(workspace) then return end
		gui:Destroy()
		self.views[screen] = nil
	end))
	self:Render(view)
end

function Boards:Row(view, i: number)
	local row = frame(view.list, "Row" .. i, px(0, (i - 1) * (ROW_HEIGHT + ROW_GAP)), UDim2.new(1, -10, 0, ROW_HEIGHT),
		Theme.OverlayColors.Top:Lerp(Color3.new(1, 1, 1), 0.08), if i % 2 == 0 then 0.2 else 0.05)
	local outline = Theme.Stroke(row, Theme.Arcade.border, 2)
	local tile = frame(row, "Rank", px(0, 0), px(ROW_HEIGHT, ROW_HEIGHT), EMPTY_TILE)
	Theme.Stroke(tile, Theme.Arcade.border, 2)
	local rank = display(tile, "Number", tostring(i), if i >= 100 then 30 else 46, px(0, 0), UDim2.fromScale(1, 1), nil, Enum.TextXAlignment.Center)
	local avatar = Instance.new("ImageLabel")
	avatar.Name, avatar.Position, avatar.Size = "Avatar", px(ROW_HEIGHT + 8, 4), px(ROW_HEIGHT - 8, ROW_HEIGHT - 8)
	avatar.BackgroundColor3, avatar.BackgroundTransparency, avatar.ZIndex = Color3.fromRGB(34, 37, 42), 0, 3
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0.5, 0); corner.Parent = avatar
	avatar.Parent = row
	local name = display(row, "Name", "", 38, px(ROW_HEIGHT * 2 + 8, 0), UDim2.new(1, -(ROW_HEIGHT * 2 + 8) - 168, 1, 0))
	local value = display(row, "Value", "", 38, UDim2.new(1, -168, 0, 0), UDim2.new(0, 158, 1, 0), view.style.valueColor, Enum.TextXAlignment.Right)
	local entry = {frame = row, outline = outline, tile = tile, rank = rank, avatar = avatar, name = name, value = value}
	Motion:Center(row) -- the reveal grows each row from its middle; same place at rest
	view.rows[i] = entry
	return entry
end

function Boards:Thumbnail(userId: number, avatar: ImageLabel)
	local cached = self.thumbs[userId]
	if cached then avatar.Image = cached; return end
	avatar.Image = ""
	avatar:SetAttribute("UserId", userId)
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and type(image) == "string" then
			self.thumbs[userId] = image
			if avatar:GetAttribute("UserId") == userId then avatar.Image = image end
		end
	end)
end

function Boards:Render(view: any)
	local data = self.data[view.key] or {}
	local style = view.style
	view.title.Text = data.title or ""
	local entries = type(data.entries) == "table" and data.entries or {}
	local me = Players.LocalPlayer.UserId
	-- Eight slots always show (empty ranks stay dim); more ranks extend the scroll.
	local count = math.max(ROWS, #entries)
	for i = 1, count do if not view.rows[i] then self:Row(view, i) end end
	for i, row in view.rows do row.frame.Visible = i <= count end
	view.list.CanvasSize = UDim2.fromOffset(0, count * (ROW_HEIGHT + ROW_GAP) - ROW_GAP)
	for i = 1, count do
		local row = view.rows[i]
		local entry = entries[i]
		row.avatar.Visible = entry ~= nil
		row.frame.BackgroundTransparency = if entry then (if i % 2 == 0 then 0.2 else 0.05) else 0.6
		if not entry then
			row.rank.Text, row.tile.BackgroundColor3 = tostring(i), EMPTY_TILE
			row.name.Text, row.value.Text = "", ""
			row.outline.Color, row.outline.Thickness = Theme.Arcade.border, 2
			Motion:StopGlow(row.frame)
			continue
		end
		local userId = tonumber(entry.userId) or 0
		row.rank.Text = tostring(entry.rank or i)
		row.tile.BackgroundColor3 = MEDALS[i] or EMPTY_TILE
		row.name.Text = tostring(entry.name or "Player")
		row.value.Text = formatValue(style, tonumber(entry.value) or 0)
		local mine = userId == me
		row.outline.Color, row.outline.Thickness = if mine then style.color else Theme.Arcade.border, if mine then 3 else 2
		-- October 21 game feel: the player's own row keeps a thin gold pulse while shown.
		if mine then Motion:Glow(row.frame, Theme.Arcade.gold, 2) else Motion:StopGlow(row.frame) end
		self:Thumbnail(userId, row.avatar)
	end
	-- Rows grow in one after another on every render; the top rank shines once as it lands.
	Motion:Reveal(view.list, {limit = 10, from = 0.8, window = 0.35, each = function(item, index)
		if index == 1 and entries[1] then Motion:Shine(item) end
	end})
end

function Boards:Destroy()
	for _, connection in self.connections do connection:Disconnect() end
	for _, view in self.views do view.gui:Destroy() end
	table.clear(self.views)
end

return Boards
