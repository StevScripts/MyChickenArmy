--!strict
-- "Time Skip!" claim popup (October 21 reference parity, P4;
-- docs/team/REFERENCE_PARITY_20261021.md §2.4, docs/team/REBIRTH_SCREEN.md).
-- A Rebirth leaves the Coins at 0 and the server keeps its Time Skip Coins as a
-- saved claim (state.rebirth.timeSkipPending = {coins, rank}). This popup offers it in
-- the reference's "Welcome Back!" style: gold stud header, "TIME SKIP:", the offline
-- receipt's coin art, "+N Coins" and one green Claim!. It opens once the Rebirth
-- celebration has played (the Rebirth window stays open underneath, as in the
-- reference) or, on join, once the offline receipt and the daily reward have closed.
-- Claim! (and the X, Escape or B, which claim too, like the offline receipt's close)
-- sends ClaimTimeSkip; the server pays it and the HUD counts up from that packet.
-- Another menu opening sets the popup aside; the claim waits and it comes back.
-- Display only: this module never changes saved state or Coins.
-- Mounted by AppController:Start (one line); it reads its own StateChanged packets,
-- deferred so AppController:Receive has rendered the Rebirth window and receipts first.
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.UITheme)
local MenuLayout = require(script.Parent.MenuLayout)
local ShopArt = require(script.Parent.ShopPreviewArt)
local Controller = {}
Controller.__index = Controller

local GOLD = Theme.ReferenceColors.Base
local GREEN = Theme.ReferenceColors.Army
local WHITE = Color3.new(1,1,1)
local SUBTLE = Color3.fromRGB(214,222,226)
local ACTION = "PetRollTimeSkipClaim"
-- Re-check while something else is on screen; then wait a short beat after it closes.
local RETRY_SECONDS, SETTLE_SECONDS = 0.5, 0.6
-- A refused claim ("not ready yet") waits before offering again; a lost reply unlocks.
local SNOOZE_SECONDS, REPLY_SECONDS = 5, 10
-- Coins flying into the HUD readout on a claim (touch screens get fewer; layout never changes).
local FLYERS, TOUCH_FLYERS = 6, 4

function Controller.new(app: any)
	local self = setmetatable({app=app, connections={} :: {RBXScriptConnection}, watchers={} :: {RBXScriptConnection},
		alive=true, pending=nil :: {coins: number, rank: number}?, minutes=nil :: number?, claimId=nil :: number?,
		retry=nil :: thread?, snoozeUntil=0, blockedAt=-math.huge, closing=false, shownCoins=nil :: number?,
		-- The open popup's pieces (nil while closed).
		gui=nil :: any, panel=nil :: any, art=nil :: any, amount=nil :: any, subline=nil :: any, claimButton=nil :: any,
		panelSize=nil :: any, panelPosition=nil :: any, previousSelection=nil :: any}, Controller)
	local remotes = app.remotes
	local changed = remotes and remotes:FindFirstChild("StateChanged")
	if changed then
		table.insert(self.connections, changed.OnClientEvent:Connect(function(packet)
			task.defer(function() self:Receive(packet) end)
		end))
	end
	-- AppController:Destroy ends with gui:Destroy(); go with it.
	if app.gui then
		table.insert(self.connections, app.gui.Destroying:Connect(function() self:Destroy() end))
	end
	return self
end

-- A {coins, rank} claim with coins > 0, or nil.
local function readPending(quote: any): {coins: number, rank: number}?
	local pending = type(quote) == "table" and quote.timeSkipPending or nil
	if type(pending) ~= "table" then return nil end
	local coins = tonumber(pending.coins) or 0
	if coins < 1 then return nil end
	return {coins = math.floor(coins), rank = math.max(0, math.floor(tonumber(pending.rank) or 0))}
end

function Controller:Receive(packet: any)
	if not self.alive or type(packet) ~= "table" or type(packet.state) ~= "table" then return end
	local quote = packet.state.rebirth
	self.pending = readPending(quote)
	if type(quote) == "table" then self.minutes = tonumber(quote.timeSkipMinutes) end
	local result = packet.result
	if type(result) == "table" and result.action == "ClaimTimeSkip" and self.claimId ~= nil and result.id == self.claimId then
		self:Answered(result)
	end
	self:Consider()
end

function Controller:Schedule(seconds: number)
	if self.retry ~= nil or not self.alive then return end
	self.retry = task.delay(seconds, function()
		self.retry = nil
		self:Consider()
	end)
end

local function open(controller: any): boolean
	return type(controller) == "table" and controller.gui ~= nil
end

-- Anything else on screen that this popup must not cover. The Rebirth window is not
-- in the list: the claim opens over it, as the reference keeps that screen open.
function Controller:Blocked(): boolean
	local app = self.app
	if not app.other or app.dialogueActive then return true end
	if app.commerce and app.commerce.cratePresenting then return true end
	if app.panel and app.panel.Visible then return true end
	local research = app.research
	if research and research.root and research.root.Visible then return true end
	if open(app.offlineCash) or open(app.freeGift) or open(app.playtimePanel) or open(app.operationsPanel)
		or open(app.autoRollMenu) then return true end
	-- On join the daily reward goes first (it waits for the offline receipt itself).
	local daily = app.dailyReward
	if type(daily) == "table" and (daily.gui ~= nil or daily.pending ~= nil) then return true end
	if app.intro and app.intro:Pending() then return true end
	if app.commander and app.commander:Celebrating() then return true end
	return false
end

-- Seconds until the popup may open (0 = now): the Rebirth celebration first
-- (RebirthPanel.celebratingUntil), then every other popup or menu, then a short beat.
function Controller:Wait(): number
	local now = os.clock()
	if now < self.snoozeUntil then return self.snoozeUntil - now end
	local rebirth = self.app.rebirthPanel
	local celebrating = if type(rebirth) == "table" then tonumber(rebirth.celebratingUntil) else nil
	if celebrating and now < celebrating then return celebrating - now end
	if self:Blocked() then
		self.blockedAt = now
		return RETRY_SECONDS
	end
	return math.max(0, self.blockedAt + SETTLE_SECONDS - now)
end

function Controller:Consider()
	if not self.alive then return end
	local pending = self.pending
	if self.gui then
		-- Open and not claiming: follow the server (a later Rebirth adds to the claim).
		if self.claimId == nil and not self.closing then
			if not pending then self:Dismiss()
			elseif pending.coins ~= self.shownCoins then
				self:SetAmount(pending.coins)
				if self.subline then self.subline.Text = self:Subline(pending, self.minutes) end
			end
		end
		return
	end
	if not pending or self.claimId ~= nil then return end
	local wait = self:Wait()
	if wait > 0 then self:Schedule(wait);return end
	self:Show(pending, self.minutes)
end

-- "+48,250 Coins" counting up from the shown value with a rising tick (display only).
function Controller:SetAmount(coins: number)
	local amount = self.amount
	if not amount then return end
	local first = self.shownCoins == nil
	self.shownCoins = coins
	local function money(value) return "+"..Theme.CompactCoins(math.floor(value)) end
	local total = math.max(1, coins)
	if first then Theme.Motion:CountTo(amount, 0, money) end
	Theme.Motion:CountTo(amount, coins, money, 0.8, {tickGap=0.07, punch=1.1, tick=function(value: number)
		self.app:Cue("CountTick", nil, 0.9 + 0.25*math.clamp(value/total, 0, 1), {voiceKey="CountTick", cooldown=0.06})
	end})
end

local function label(parent, name: string, text: string, size: number, color: Color3)
	local item = Theme.Label(parent, name, text, size, color)
	-- TextWrapped first: setting it after TextScaled can switch TextScaled off.
	item.TextXAlignment, item.TextWrapped, item.TextScaled = Enum.TextXAlignment.Center, false, true
	return item
end

function Controller:Subline(pending: any, minutes: number?): string
	local rank = "Rebirth "..pending.rank
	if minutes and minutes > 0 then return math.floor(minutes).." min of egg Coins · "..rank end
	return "Egg Coins from "..rank
end

function Controller:Show(pending: any, minutes: number?)
	local app = self.app
	self:Dismiss(true)
	self.shownCoins = nil
	-- Our own blur owner, taken BEFORE CloseOtherMenus so a closing menu cannot clear the
	-- shared blur; Dismiss releases it. One modal at a time, except the Rebirth window,
	-- which the reference keeps open underneath ("rebirth" is the menu kept).
	app:SetMenuBlur("timeSkip", true)
	if app.CloseOtherMenus then app:CloseOtherMenus("rebirth") end
	self.previousSelection = GuiService.SelectedObject
	local gui = if app.editPreview then Theme.Container(app.other, "TimeSkip")
		else Theme.InsetContainer(app.other, "TimeSkip", Enum.ScreenInsets.CoreUISafeInsets)
	-- Above the Rebirth window (30) it covers.
	gui.ZIndex = 32
	self.gui, self.closing = gui, false
	local frames = Theme.Container(gui, "FRAMES")
	-- The tap blocker covers the full device screen, past phone notches.
	local backdropParent = if app.editPreview then frames
		else Theme.InsetContainer(frames, "BackdropLayer", Enum.ScreenInsets.None)
	local backdrop = Theme.Frame(backdropParent, "Backdrop", UDim2.fromScale(1,1))
	backdrop.BackgroundTransparency, backdrop.Active = 1, true
	local panel = Instance.new("CanvasGroup")
	panel.Name = "TimeSkip"
	panel.BackgroundTransparency, panel.BorderSizePixel, panel.GroupTransparency = 1, 0, 1
	panel.Active, panel.ZIndex = true, 2
	panel.AnchorPoint, panel.Position = Vector2.new(0.5,0.5), UDim2.fromScale(0.5,0.5)
	panel.Parent, self.panel = frames, panel
	-- The same window as the Welcome Back receipt (MenuLayouts.OfflineEarnings).
	MenuLayout.Apply(app.gui, "Offline", panel)
	if app.editPreview then
		panel.Size, panel.Position, panel.AnchorPoint = UDim2.fromScale(1,1), UDim2.fromScale(0.5,0.5), Vector2.new(0.5,0.5)
	end
	self.panelSize, self.panelPosition = panel.Size, panel.Position
	local header = Theme.Header(panel, "Header", "Time Skip!", GOLD)
	local clock = Theme.GemArtId("TimeSkip")
	if clock then
		header.PageIcon.Image, header.PageIcon.Visible = clock, true
		Theme.LayoutHeader(header)
	end
	local main = Theme.Container(panel, "Main")
	Theme.BelowHeader(header, main)
	Theme.Surface(main)
	main.UIStroke.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	-- The reference's dark see-through box: the heading, the coin art and the amount.
	local card = Theme.Frame(main, "Reward", UDim2.fromScale(0.96,0.72), Color3.new(0,0,0))
	card.Position, card.BackgroundTransparency, card.ZIndex = UDim2.fromScale(0.02,0.03), 0.55, 2
	card:SetAttribute("OwnsPopupStyle", true)
	Theme.Stroke(card, Color3.fromRGB(6,8,9), 2).Transparency = 0.2
	local heading = label(card, "Heading", "TIME SKIP:", 34, WHITE)
	heading.Position, heading.Size = UDim2.fromScale(0.05,0.02), UDim2.fromScale(0.9,0.15)
	local reward = Theme.Container(card, "Art")
	reward.AnchorPoint, reward.Position, reward.Size = Vector2.new(0.5,0), UDim2.fromScale(0.5,0.15), UDim2.fromScale(0.62,0.62)
	Theme.Aspect(reward, 1)
	local rays = Theme.Image(reward, "Rays", Theme.Assets.Rays, UDim2.fromScale(1.35,1.35), UDim2.fromScale(0.5,0.5))
	rays.AnchorPoint, rays.ImageColor3, rays.ImageTransparency, rays.ZIndex = Vector2.new(0.5,0.5), GOLD, 0.45, 2
	-- The offline receipt's coin pile (ShopPreviewArt.CashPile).
	local art = ShopArt.CashPile(reward, 1)
	art.Name, art.ZIndex = "Icon", 3
	art.AnchorPoint, art.Position = Vector2.new(0.5,0.5), UDim2.fromScale(0.5,0.5)
	self.art = art
	-- The amount overlaps the art's lower edge, as "+3.4M" does in the reference.
	local amount = label(card, "Amount", "+0", 54, Theme.Colors.coins)
	amount.AnchorPoint, amount.Position, amount.Size = Vector2.new(0.5,0), UDim2.fromScale(0.5,0.62), UDim2.fromScale(0.96,0.22)
	amount.ZIndex = 5
	self.amount = amount
	local subline = label(card, "Subline", self:Subline(pending, minutes), 22, SUBTLE)
	-- Full card width: the line still reads at the 12 px floor on a phone.
	subline.Position, subline.Size, subline.ZIndex = UDim2.fromScale(0.01,0.85), UDim2.fromScale(0.98,0.13), 5
	self.subline = subline
	local function claim() self:Claim() end
	-- Phone hit areas (DESIGN.md §6): the same window as the offline receipt, so the
	-- same X pad (3.6x); Claim! grows 2.1x, mostly upward over the card's bottom lines.
	Theme.HeaderClose(header, claim, 3.6)
	local button = Theme.ActionButton(main, "Claim", "Claim!", claim, GREEN)
	button.AnchorPoint, button.Position, button.Size = Vector2.new(0.5,0), UDim2.fromScale(0.5,0.79), UDim2.fromScale(0.46,0.17)
	Theme.PadHit(button, 1, 2.1, 0.5, 0.85)
	Theme.Studs(button.Visual.Face, 0.07, 28, 0)
	local caption = button.Visual.Caption
	caption.Position, caption.Size, caption.TextScaled = UDim2.fromScale(0.04,0.1), UDim2.fromScale(0.92,0.8), true
	caption.TextShadow.Visible = false
	self.claimButton = button
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	self:SetAmount(pending.coins)
	-- Enter like the offline receipt: grow in, then the art punches and sparkles once.
	local restingSize, restingPosition = self.panelSize, self.panelPosition
	if not app.reducedMotion then
		panel.Size = UDim2.fromScale(restingSize.X.Scale*0.94, restingSize.Y.Scale*0.94)
		panel.Position = UDim2.fromScale(restingPosition.X.Scale, restingPosition.Y.Scale + 0.035)
	end
	Theme.Motion:Tween(panel, "timeskip-size", {Size=restingSize}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function()
		Theme.Motion:Punch(art, 1.18, 0.3)
		Theme.Motion:Burst(reward, UDim2.fromScale(0.5,0.5), GOLD)
	end)
	Theme.Motion:Tween(panel, "position", {Position=restingPosition}, 0.28)
	Theme.Motion:Tween(panel, "timeskip-fade", {GroupTransparency=0}, 0.22)
	-- The rays turn slowly (a direct loop: a closing menu's StopSpins must not stop it).
	if not app.reducedMotion then
		Theme.Motion:Tween(rays, "spin", {Rotation=360}, 14, Enum.EasingStyle.Linear, Enum.EasingDirection.In, nil, -1)
	end
	app:Cue("MenuOpen", "Pop")
	-- Claim! breathes until pressed (StopBreathe in Dismiss).
	Theme.Motion:Breathe(button.Visual, 1.05, 0.7)
	if app.editPreview then return end
	ContextActionService:BindActionAtPriority(ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then claim() end
		return Enum.ContextActionResult.Sink
	end, false, 3100, Enum.KeyCode.ButtonB)
	local function watch(signal, callback) table.insert(self.watchers, signal:Connect(callback)) end
	watch(UserInputService.InputBegan, function(input)
		if input.KeyCode == Enum.KeyCode.Escape then claim() end
	end)
	-- Another menu opening (a hotkey) sets the popup aside; the claim waits and returns.
	if app.panel then
		watch(app.panel:GetPropertyChangedSignal("Visible"), function()
			if app.panel.Visible and self.claimId == nil then self:Dismiss(true) end
		end)
	end
	local research = app.research
	if research and research.root then
		watch(research.root:GetPropertyChangedSignal("Visible"), function()
			if research.root.Visible and self.claimId == nil then self:Dismiss(true) end
		end)
	end
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = button end
end

function Controller:Claim()
	if not self.gui or self.closing or self.claimId ~= nil then return end
	local id = self.app:Request("ClaimTimeSkip")
	-- UI Lab previews have no server: the popup just closes.
	if not id then self:Dismiss();return end
	self.claimId = id
	if self.claimButton then Theme.Motion:StopBreathe(self.claimButton.Visual) end
	task.delay(REPLY_SECONDS, function()
		if self.claimId == id then self.claimId = nil end
	end)
end

-- The server's answer to our ClaimTimeSkip. A refusal ("not ready yet") already shows
-- the server's notice through AppController; an empty one (nothing left) shows none.
function Controller:Answered(result: any)
	self.claimId = nil
	if result.ok then
		local receipt = if type(result.receipt) == "table" then result.receipt else {}
		self:Payout(tonumber(receipt.coins) or 0)
	else
		self.snoozeUntil = os.clock() + SNOOZE_SECONDS
	end
	self:Dismiss()
end

-- Claim, then the jingle; coins arc from the art into the HUD's coin while the readout
-- counts up from the same packet (HudController). Reduced motion: no flyers.
function Controller:Payout(coins: number)
	local app = self.app
	app:Cue("Claim", "UIPurchase")
	task.delay(0.3, function() if self.alive and app.alive ~= false then app:Cue("Jingle") end end)
	local art, gui, hud = self.art, app.gui, app.hud
	local target = hud and (hud.cashIcon or hud.cashReadout)
	if app.reducedMotion or coins <= 0 or not art or not art.Parent or not gui or not target then return end
	local motion = Theme.Motion
	local origin = motion:CenterOf(art)
	local destination = motion:Point(gui, motion:CenterOf(target))
	local width = if hud.cashIcon then hud.cashIcon.AbsoluteSize.X*0.7 else 36
	local size = UDim2.fromOffset(math.max(28, width), math.max(28, width))
	local count = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then TOUCH_FLYERS else FLYERS
	local landed = false
	for index = 1, count do
		local spread = Vector2.new(math.random(-50,50), math.random(-30,30))
		task.delay((index-1)*0.06, function()
			if not self.alive or app.alive == false then return end
			motion:Fly(gui, Theme.Assets.Coin, motion:Point(gui, origin + spread), destination, {size=size, seconds=0.55,
				arc=0.06, spin=math.random(-60,60), limit=12, onArrive=function()
					if not landed and hud.cashIcon then landed = true;motion:PopScale(hud.cashIcon, 1.12) end
				end})
		end)
	end
end

function Controller:Dismiss(immediate: boolean?)
	local gui, panel = self.gui, self.panel
	if not gui or (self.closing and not immediate) then return end
	self.closing = true
	ContextActionService:UnbindAction(ACTION)
	for _, connection in self.watchers do connection:Disconnect() end
	table.clear(self.watchers)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	if self.claimButton then Theme.Motion:StopBreathe(self.claimButton.Visual) end
	self.app:SetMenuBlur("timeSkip", false)
	local function finish()
		if self.gui ~= gui then return end
		self.gui, self.panel, self.art, self.amount, self.subline, self.claimButton, self.closing = nil, nil, nil, nil, nil, nil, false
		self.shownCoins = nil
		gui:Destroy()
		-- Set aside by another menu: offer the waiting claim again once it closes.
		if self.alive and self.pending and self.claimId == nil then self:Schedule(RETRY_SECONDS) end
	end
	if immediate or not panel then finish();return end
	Theme.Motion:Tween(panel, "timeskip-size", {Size=UDim2.fromScale(self.panelSize.X.Scale*0.97, self.panelSize.Y.Scale*0.97)},
		0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Theme.Motion:Tween(panel, "position", {Position=UDim2.fromScale(self.panelPosition.X.Scale, self.panelPosition.Y.Scale + 0.025)}, 0.16)
	Theme.Motion:Tween(panel, "timeskip-fade", {GroupTransparency=1}, 0.16, nil, nil, finish)
end

function Controller:Destroy()
	if not self.alive then return end
	self.alive = false
	if self.retry then task.cancel(self.retry);self.retry = nil end
	for _, connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	self:Dismiss(true)
end

return Controller
