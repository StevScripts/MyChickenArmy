--!strict
-- Bind the builder's SurfaceGui verbatim. Only live text and interaction change.
-- Interactive SurfaceGuis live in PlayerGui and adorn the original world screen.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Definitions = require(Shared.UpgradeCatalog)
local Theme = require(script.Parent.UITheme)
local Board = {}
Board.__index = Board

-- Presentation only. Hover/press timing stays in the shared UIMotion helper.
local FEEL = {SuccessScale = 1.06, RejectDistance = 0.012, RejectSeconds = 0.07,
	SuccessVolume = 0.28}

local function buttonVisual(button)
	local children = button:GetChildren()
	local visual = Instance.new("Frame")
	visual.Name, visual.BackgroundTransparency, visual.BorderSizePixel = "BoardMotionVisual", 1, 0
	visual.AnchorPoint, visual.Position, visual.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
	visual.ZIndex, visual.Parent = button.ZIndex, button
	-- Animate the artwork, not the hit target. Child geometry remains unchanged.
	for _, child in children do
		if child:IsA("GuiObject") then child.Parent = visual end
	end
	return visual
end

local function money(value)
	local whole = tostring(math.floor(value))
	local formatted = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "$" .. formatted
end

local function plotIndex(screen, root)
	local node = screen
	while node and node ~= root do
		local index = node:GetAttribute("PlotIndex")
		if type(index) == "number" then return index end
		node = node.Parent
	end
	return nil
end

function Board.new(app)
	return setmetatable({app = app, views = {}, connections = {}, pending = {}, alive = true}, Board)
end

function Board:Unbind(source)
	local view = self.views[source]
	if not view then return end
	self.views[source] = nil
	for _, connection in view.connections do connection:Disconnect() end
	for _, card in view.cards do Theme.Motion:DisconnectButtonBindings(card.button) end
	view.gui:Destroy()
	if source.Parent then source.Enabled = view.originalEnabled end
end

function Board:Bind(source)
	if not self.alive or self.views[source] or not source:IsA("SurfaceGui") then return end
	local world = workspace:FindFirstChild("PetRollWorld")
	if not world or not source:IsDescendantOf(world) or not source:FindFirstChild("UpgradesBoard") then return end
	local screen = if source.Parent:IsA("BasePart") then source.Parent else source.Adornee
	if not screen or not screen:IsA("BasePart") then return end
	local gui = source:Clone()
	if not gui then return end
	local root = gui:FindFirstChild("UpgradesBoard")
	local cards = root and root:FindFirstChild("UpgradeCards")
	if not cards then gui:Destroy(); return end
	gui.Name, gui.Adornee, gui.Active, gui.ResetOnSpawn = "LiveUpgradeBoard", screen, true, false
	root:SetAttribute("DesignPreviewOnly", false)
	root:SetAttribute("GameplayConnected", true)
	local view = {gui = gui, cards = {}, connections = {}, originalEnabled = source.Enabled,
		plotIndex = plotIndex(screen, world)}
	for _, key in Definitions.Order do
		local card = cards:FindFirstChild(key)
		local button = card and card:FindFirstChild("UpgradeButton")
		local current = card and card:FindFirstChild("CurrentValue")
		local contents = button and button:FindFirstChild("PriceContents")
		local price = contents and contents:FindFirstChild("Price")
		if button and button:IsA("GuiButton") and current and current:IsA("TextLabel") and price and price:IsA("TextLabel") then
			button.AutoButtonColor = false
			button:SetAttribute("DesignPreviewOnly", false)
			local face = button:FindFirstChild("Face")
			local visual = buttonVisual(button)
			Theme.Motion:BindButton(button, visual, face)
			view.cards[key] = {button = button, current = current, price = price, visual = visual, face = face}
			table.insert(view.connections, button.Activated:Connect(function() self:Purchase(key) end))
		end
	end
	self.views[source] = view
	source.Enabled = false
	gui.Parent = self.playerGui
	Theme.BindStudTextures(gui)
	table.insert(view.connections, source.AncestryChanged:Connect(function()
		if not source:IsDescendantOf(workspace) then self:Unbind(source) end
	end))
	self:Render()
end

function Board:Render()
	local state = self.app.state
	for _, view in self.views do
		view.gui.Enabled = view.originalEnabled and state ~= nil
			and (view.plotIndex == nil or view.plotIndex == state.plotIndex)
		for key, card in view.cards do
			local offer = state and state.boardUpgrades and state.boardUpgrades[key]
			local waiting = self.pending[key] ~= nil
			if offer then
				card.current.Text = if offer.nextText then offer.currentText .. " > " .. offer.nextText else offer.currentText
			end
			card.price.Text = if not offer or not offer.ready then "Loading"
				elseif waiting then "..." elseif not offer.price then "MAX"
				elseif not offer.unlocked then "Locked" else money(offer.price)
			-- Leave colors, font, artwork, geometry and scale exactly as authored.
			-- Unaffordable/locked clicks explain why through the existing game toast.
			local active = offer ~= nil and offer.ready == true and offer.price ~= nil and not waiting
			card.button.Active, card.button.Selectable = active, active
		end
	end
end

function Board:Reject(key)
	if self.app.reducedMotion or Theme.Motion.reduced then return end
	for _, view in self.views do
		local card = view.cards[key]
		if not view.gui.Enabled or not card then continue end
		local visual = card.visual
		local center = UDim2.fromScale(0.5, 0.5)
		local distance = FEEL.RejectDistance
		Theme.Motion:Tween(visual, "board-reject", {Position = center + UDim2.fromScale(-distance, 0)}, FEEL.RejectSeconds,
			nil, nil, function()
				Theme.Motion:Tween(visual, "board-reject", {Position = center + UDim2.fromScale(distance, 0)}, FEEL.RejectSeconds,
					nil, nil, function()
						Theme.Motion:Tween(visual, "board-reject", {Position = center}, FEEL.RejectSeconds)
					end)
			end)
	end
end

function Board:Confirm(key)
	for _, view in self.views do
		local card = view.cards[key]
		if not view.gui.Enabled or not card then continue end
		Theme.Motion:Cancel(card.visual, "board-reject")
		card.visual.Position = UDim2.fromScale(0.5, 0.5)
		-- Add a bounded impulse from the current motion instead of resetting it.
		Theme.Motion:Pulse(card.visual, FEEL.SuccessScale)
		if card.face then Theme.Motion:Shine(card.face) end
	end
	self.app.audio:Play("RollReveal", 1.12, {volume = FEEL.SuccessVolume, maxDuration = 0.7,
		voiceKey = "BoardUpgradeSuccess", maxVoices = 2, cooldown = 0.1})
end

function Board:Purchase(key)
	local state = self.app.state
	local offer = state and state.boardUpgrades and state.boardUpgrades[key]
	if not self.alive or self.pending[key] or not offer or not offer.ready or not offer.price then return end
	self.app.audio:Play("Click")
	if not offer.unlocked then self:Reject(key); self.app:Notify(offer.requirement, false); return end
	if state.coins < offer.price then self:Reject(key); self.app:Notify("Not enough cash for this upgrade.", false); return end
	local id = self.app:Request("BoardUpgrade", {upgradeKey = key, expectedLevel = offer.level, expectedPrice = offer.price})
	self.pending[key] = id
	self:Render()
	task.delay(8, function()
		if self.alive and self.pending[key] == id then
			self.pending[key] = nil
			self:Render()
		end
	end)
end

function Board:Receive(result)
	local confirmedKey
	if result then
		for key, id in self.pending do
			if result.id == id then self.pending[key] = nil; confirmedKey = key end
		end
	end
	self:Render()
	-- A snapshot alone never celebrates; match one pending request to its receipt.
	if confirmedKey then
		if result.ok then self:Confirm(confirmedKey) else self:Reject(confirmedKey) end
	end
end

function Board:Start()
	self.playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	table.insert(self.connections, workspace.DescendantAdded:Connect(function(item)
		if item:IsA("SurfaceGui") or item.Name == "UpgradeCards" then
			task.defer(function()
				if not self.alive then return end
				local source = if item:IsA("SurfaceGui") then item else item:FindFirstAncestorWhichIsA("SurfaceGui")
				if source then self:Bind(source) end
			end)
		end
	end))
	local world = workspace:FindFirstChild("PetRollWorld")
	if world then
		for _, item in world:GetDescendants() do
			if item:IsA("SurfaceGui") then self:Bind(item) end
		end
	end
end

function Board:Destroy()
	self.alive = false
	for _, connection in self.connections do connection:Disconnect() end
	local sources = {}
	for source in self.views do table.insert(sources, source) end
	for _, source in sources do self:Unbind(source) end
	table.clear(self.pending)
end

return Board
