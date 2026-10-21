--!strict
-- October 20 egg-sale coin burst. Presentation only: the server has already paid.
-- Gold coins pop out of the sell pad, bounce, then arc into the player one after
-- another; `land` reports each coin's share as it arrives so the HUD counts up.
-- October 21 (Stevin's reference recording): the first coin to land flashes a white
-- bubble around the player, and a running "N [coin]" counter beside them counts each
-- coin. After a pause the counter stays where it was and fades; the next sale starts
-- a new one. Every move is a native tween: a coin's Attachment slides while its
-- BillboardGui's world offset rises and drops. For the fly-in the Attachment moves
-- onto the HumanoidRootPart, so a walking player is followed without a frame loop.
-- Tune CollectionFeel.CoinBurst.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Feel = require(game:GetService("ReplicatedStorage").PetRoll.Shared.CollectionFeel).CoinBurst
local Theme = require(script.Parent.UITheme)
local CoinBurst = {}
CoinBurst.__index = CoinBurst

type Land = (share: number, index: number, quiet: boolean) -> ()
type Coin = {
	index: number, share: number, size: number, attachment: Attachment, gui: BillboardGui,
	land: Land, flip: Tween, tweens: {Tween}, done: boolean,
}
type Counter = {gui: BillboardGui, scale: UIScale, label: TextLabel, icon: ImageLabel, total: number, serial: number}
type State = {coins: {[Coin]: boolean}, active: number, random: Random, counter: Counter?, leftovers: {[Instance]: boolean}}
type Burst = typeof(setmetatable({} :: State, CoinBurst))

function CoinBurst.new(): Burst
	return setmetatable({coins = {}, active = 0, random = Random.new(), leftovers = {}} :: State, CoinBurst)
end

local function playerRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Effects budget only (one layout for every device): phones draw fewer coins.
local function phone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- The sell pad is an invisible trigger box; coins land on the floor under it.
local function sellPad(origin: Vector3, plotIndex: number?): BasePart?
	local world = workspace:FindFirstChild("PetRollWorld")
	local plot = plotIndex and world and world:FindFirstChild("Plot" .. plotIndex)
	local pad = plot and plot:FindFirstChild("sellpart", true)
	return if pad and pad:IsA("BasePart") and (pad.Position - origin).Magnitude < 3 then pad else nil
end

local function groundBelow(origin: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType, params.RespectCanCollide, params.IgnoreWater = Enum.RaycastFilterType.Exclude, true, true
	local character = Players.LocalPlayer.Character
	params.FilterDescendantsInstances = if character then {character} else {}
	local hit = workspace:Raycast(origin + Vector3.new(0, 2, 0), Vector3.new(0, -10, 0), params)
	return if hit then hit.Position else origin
end

local function tween(coin: Coin, object: Instance, info: TweenInfo, goals: {[string]: any}): Tween
	local animation = TweenService:Create(object, info, goals)
	table.insert(coin.tweens, animation)
	animation:Play()
	return animation
end

-- Draws one coin per egg within the budget and returns false when it drew none (the
-- caller then counts the sale in at once). `land` runs once per coin; the shares add
-- up to exactly `value`.
function CoinBurst.Play(self: Burst, origin: Vector3, value: number, eggs: number, plotIndex: number?, land: Land): boolean
	local root = playerRoot()
	if value <= 0 or not root or (root.Position - origin).Magnitude > Feel.MaxDistance then return false end
	local onPhone = phone()
	local room = (if onPhone then Feel.PhoneMaxActive else Feel.MaxActive) - self.active
	local count = math.min(math.max(Feel.MinCoins, eggs), if onPhone then Feel.PhoneMaxCoins else Feel.MaxCoins,
		room, math.max(1, math.floor(value)))
	if count < 1 then return false end
	local pad = sellPad(origin, plotIndex)
	local base = groundBelow(if pad then pad.Position else origin)
	local halfX = if pad then pad.Size.X / 2 + Feel.Spill else math.huge
	local halfZ = if pad then pad.Size.Z / 2 + Feel.Spill else math.huge
	self:Spill(base)
	local random = self.random
	local released = 0
	for index = 1, count do
		-- Spread around the pad, kept inside its footprint plus a small spill.
		local angle = (index / count + random:NextNumber(-0.15, 0.15)) * math.pi * 2
		local radius = random:NextNumber(Feel.Radius[1], Feel.Radius[2])
		local x = math.clamp(math.cos(angle) * radius, -halfX, halfX)
		local z = math.clamp(math.sin(angle) * radius, -halfZ, halfZ)
		local offset = if pad then pad.CFrame:VectorToWorldSpace(Vector3.new(x, 0, z)) else Vector3.new(x, 0, z)
		local total = if index == count then value else math.floor(value * index / count)
		self:Launch(index, total - released, base, base + Vector3.new(offset.X, 0, offset.Z), land)
		released = total
	end
	return true
end

function CoinBurst.Launch(self: Burst, index: number, share: number, from: Vector3, to: Vector3, land: Land)
	local random = self.random
	local size = Feel.Size * random:NextNumber(0.9, 1.1)
	-- Attachments under Terrain use world coordinates.
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.Position = "SaleCoin", from
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee, gui.Size = "Coin", attachment, UDim2.fromScale(0, 0)
	gui.StudsOffsetWorldSpace, gui.LightInfluence, gui.MaxDistance = Vector3.new(0, size / 2, 0), 0, 150
	-- Walls and the player hide the coins; they are part of the scene, not the HUD.
	gui.AlwaysOnTop, gui.Parent = false, attachment
	local face = Instance.new("ImageLabel")
	face.Name, face.Image, face.BackgroundTransparency = "Face", Theme.Assets.Coin, 1
	face.ScaleType, face.Rotation = Enum.ScaleType.Stretch, random:NextNumber(-25, 25)
	face.AnchorPoint, face.Position, face.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1)
	face.Parent = gui
	attachment.Parent = workspace.Terrain
	local flip = TweenService:Create(face, TweenInfo.new(random:NextNumber(Feel.FlipSeconds[1], Feel.FlipSeconds[2]),
		Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.fromScale(Feel.FlipWidth, 1)})
	flip:Play()
	local coin: Coin = {index = index, share = share, size = size, attachment = attachment, gui = gui,
		land = land, flip = flip, tweens = {}, done = false}
	self.coins[coin] = true
	self.active += 1
	local delay = (index - 1) * Feel.LaunchStagger
	tween(coin, gui, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay),
		{Size = UDim2.fromScale(size, size)})
	tween(coin, attachment, TweenInfo.new(Feel.RiseSeconds + Feel.FallSeconds, Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out, 0, false, delay), {Position = to})
	local apex = random:NextNumber(Feel.Height[1], Feel.Height[2])
	tween(coin, gui, TweenInfo.new(Feel.RiseSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay),
		{StudsOffsetWorldSpace = Vector3.new(0, apex, 0)}).Completed:Once(function(state)
		if state ~= Enum.PlaybackState.Completed or coin.done then return end
		tween(coin, gui, TweenInfo.new(Feel.FallSeconds, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
			{StudsOffsetWorldSpace = Vector3.new(0, size / 2, 0)}).Completed:Once(function(fallState)
			if fallState ~= Enum.PlaybackState.Completed or coin.done then return end
			-- Fly in one after another, so the counter ticks once per coin.
			task.delay(Feel.RestSeconds + (index - 1) * math.max(0, Feel.FlyStagger - Feel.LaunchStagger),
				function() self:Fly(coin) end)
		end)
	end)
end

function CoinBurst.Fly(self: Burst, coin: Coin)
	if coin.done then return end
	local root = playerRoot()
	if not root or coin.attachment.Parent == nil then self:Finish(coin, true);return end
	local world = coin.attachment.WorldPosition + coin.gui.StudsOffsetWorldSpace
	-- A respawned player may be across the map; count the coin in without the flight.
	local distance = (root.Position - world).Magnitude
	if distance > Feel.MaxDistance then self:Finish(coin, true);return end
	for _, animation in coin.tweens do animation:Cancel() end
	table.clear(coin.tweens)
	coin.gui.StudsOffsetWorldSpace = Vector3.zero
	coin.attachment.Parent = root
	coin.attachment.Position = root.CFrame:PointToObjectSpace(world)
	-- The Attachment closes in on the player while the world offset rises and drops
	-- again, so each coin arcs up and over into them.
	local half = Feel.FlySeconds / 2
	local arc = math.clamp(distance * Feel.FlyArcPerStud, Feel.FlyArc[1], Feel.FlyArc[2])
	local small = coin.size * 0.6
	tween(coin, coin.gui, TweenInfo.new(Feel.FlySeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Size = UDim2.fromScale(small, small)})
	tween(coin, coin.gui, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{StudsOffsetWorldSpace = Vector3.new(0, arc, 0)}).Completed:Once(function(state)
		if state ~= Enum.PlaybackState.Completed or coin.done then return end
		tween(coin, coin.gui, TweenInfo.new(half, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{StudsOffsetWorldSpace = Vector3.zero})
	end)
	tween(coin, coin.attachment, TweenInfo.new(Feel.FlySeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{Position = Vector3.new(0, 0.5, 0)}).Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then self:Finish(coin, false) end
	end)
end

function CoinBurst.Remove(self: Burst, coin: Coin)
	coin.done = true
	self.coins[coin] = nil
	self.active = math.max(0, self.active - 1)
	coin.flip:Cancel()
	for _, animation in coin.tweens do animation:Cancel() end
	coin.attachment:Destroy()
end

function CoinBurst.Finish(self: Burst, coin: Coin, quiet: boolean)
	if coin.done then return end
	self:Remove(coin)
	if not quiet then
		local root = playerRoot()
		if root then
			if coin.index == 1 then self:Flash(root) end
			self:Count(root, coin.share)
		end
	end
	coin.land(coin.share, coin.index, quiet)
end

-- A gold puff where the coins burst out of the pad.
function CoinBurst.Spill(self: Burst, base: Vector3)
	local spill = Feel.SpillPuff
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.Transparency = "CoinSpill", Vector3.one, 1
	anchor.Anchored, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.CastShadow = true, false, false, false, false
	anchor.Position = base + Vector3.new(0, 0.5, 0)
	local puff = Instance.new("ParticleEmitter")
	puff.Name, puff.Texture = "Sparkles", "rbxasset://textures/particles/sparkles_main.dds"
	puff.Color = ColorSequence.new(Color3.fromRGB(255, 221, 87), Color3.new(1, 1, 1))
	puff.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0)})
	puff.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
	puff.Lifetime, puff.Speed = NumberRange.new(0.35, 0.7), NumberRange.new(6, 12)
	puff.SpreadAngle, puff.Acceleration = Vector2.new(40, 40), Vector3.new(0, -20, 0)
	puff.EmissionDirection, puff.Rate, puff.LightEmission = Enum.NormalId.Top, 0, 1
	puff.Parent = anchor
	anchor.Parent = workspace.CurrentCamera
	self.leftovers[anchor] = true
	anchor.Destroying:Once(function() self.leftovers[anchor] = nil end)
	puff:Emit(spill.Sparkles)
	Debris:AddItem(anchor, 1)
end

-- A white bubble swells around the player and fades, with a puff of sparkles.
function CoinBurst.Flash(self: Burst, root: BasePart)
	local flash = Feel.Flash
	local bubble = Instance.new("Part")
	bubble.Name, bubble.Shape, bubble.Material = "CoinPickupFlash", Enum.PartType.Ball, Enum.Material.ForceField
	bubble.Color, bubble.Transparency, bubble.Size = Color3.new(1, 1, 1), flash.Transparency, Vector3.one * flash.Size[1]
	bubble.Anchored, bubble.CanCollide, bubble.CanTouch, bubble.CanQuery, bubble.CastShadow = true, false, false, false, false
	bubble.CFrame = root.CFrame
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name, sparkles.Texture = "Sparkles", "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 221, 87))
	sparkles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)})
	sparkles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
	sparkles.Lifetime, sparkles.Speed = NumberRange.new(0.3, 0.55), NumberRange.new(5, 10)
	sparkles.SpreadAngle, sparkles.Rate, sparkles.LightEmission = Vector2.new(180, 180), 0, 1
	sparkles.Parent = bubble
	-- A brief white glow inside the bubble, like the reference's bright pop.
	local glow = Instance.new("Part")
	glow.Name, glow.Shape, glow.Material = "Glow", Enum.PartType.Ball, Enum.Material.Neon
	glow.Color, glow.Transparency, glow.Size = Color3.new(1, 1, 1), flash.GlowTransparency, Vector3.one * flash.Size[1] * 0.6
	glow.Anchored, glow.CanCollide, glow.CanTouch, glow.CanQuery, glow.CastShadow = true, false, false, false, false
	glow.CFrame, glow.Parent = root.CFrame, bubble
	bubble.Parent = workspace.CurrentCamera
	self.leftovers[bubble] = true
	sparkles:Emit(flash.Sparkles)
	TweenService:Create(bubble, TweenInfo.new(flash.Seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.one * flash.Size[2], Transparency = 1}):Play()
	TweenService:Create(glow, TweenInfo.new(flash.Seconds * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.one * flash.Size[2] * 0.7, Transparency = 1}):Play()
	Debris:AddItem(bubble, 0.7)
	bubble.Destroying:Once(function() self.leftovers[bubble] = nil end)
end

local function fadeCounter(counter: Counter, seconds: number, delay: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, delay)
	for _, item in counter.gui:GetDescendants() do
		local goals = if item:IsA("TextLabel") then {TextTransparency = 1}
			elseif item:IsA("ImageLabel") then {ImageTransparency = 1}
			elseif item:IsA("UIStroke") then {Transparency = 1} else nil
		if goals then TweenService:Create(item, info, goals):Play() end
	end
end

-- Leaves the counter where the player stood; it lingers, then fades out.
function CoinBurst.Drop(self: Burst, counter: Counter)
	if self.counter == counter then self.counter = nil end
	local gui = counter.gui
	local adornee = gui.Adornee
	if not gui.Parent or not adornee or not adornee:IsA("BasePart") then gui:Destroy();return end
	local spot = Instance.new("Attachment")
	spot.Name, spot.WorldPosition = "CoinCounterSpot", adornee.Position
	spot.Parent = workspace.Terrain
	gui.Adornee, gui.Parent = spot, spot
	self.leftovers[spot] = true
	spot.Destroying:Once(function() self.leftovers[spot] = nil end)
	local style = Feel.Counter
	fadeCounter(counter, style.Fade, style.Linger)
	Debris:AddItem(spot, style.Linger + style.Fade + 0.1)
end

-- Adds a landed coin to the running counter beside the player, starting one if needed.
function CoinBurst.Count(self: Burst, root: BasePart, share: number)
	local style = Feel.Counter
	local counter = self.counter
	if counter and (not counter.gui.Parent or counter.gui.Adornee ~= root) then
		self:Drop(counter)
		counter = nil
	end
	if not counter then
		local width = style.Height * 6
		local gui = Instance.new("BillboardGui")
		gui.Name, gui.Adornee, gui.Size = "CoinCounter", root, UDim2.fromScale(width, style.Height)
		-- Camera-relative: the row starts just right of the character.
		-- Pulled toward the camera, and AlwaysOnTop so walls and chickens never hide it.
		-- (Studio Flow screenshots skip AlwaysOnTop billboards; check it by eye in play.)
		gui.StudsOffset = Vector3.new(style.Gap + width / 2, style.Lift, style.Toward)
		gui.AlwaysOnTop, gui.LightInfluence, gui.MaxDistance = true, 0, 120
		local row = Instance.new("Frame")
		row.Name, row.BackgroundTransparency = "Row", 1
		row.AnchorPoint, row.Position, row.Size = Vector2.new(0, 0.5), UDim2.fromScale(0, 0.5), UDim2.fromScale(1, 1)
		row.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.FillDirection, layout.SortOrder = Enum.FillDirection.Horizontal, Enum.SortOrder.LayoutOrder
		layout.VerticalAlignment, layout.Padding = Enum.VerticalAlignment.Center, UDim.new(0.01, 0)
		layout.Parent = row
		local scale = Instance.new("UIScale")
		scale.Parent = row
		local label = Theme.Label(row, "Amount", "0", 20, Color3.new(1, 1, 1))
		-- Order matters: setting TextWrapped=false after TextScaled turns scaling off.
		label.LayoutOrder, label.TextWrapped = 1, false
		label.TextScaled = true
		label.TextXAlignment, label.SizeConstraint = Enum.TextXAlignment.Right, Enum.SizeConstraint.RelativeYY
		local outline = label:FindFirstChild("TextOutline")
		if outline and outline:IsA("UIStroke") then outline.Thickness = 0.09 end
		local icon = Theme.CoinIcon(row, "CoinIcon", UDim2.fromScale(0.9, 0.9), UDim2.new())
		icon.LayoutOrder, icon.SizeConstraint = 2, Enum.SizeConstraint.RelativeYY
		gui.Parent = root
		counter = {gui = gui, scale = scale, label = label, icon = icon, total = 0, serial = 0}
		self.counter = counter
	end
	assert(counter)
	counter.total += share
	local text = if counter.total < 1000 then Theme.Money(counter.total) else Theme.Number(counter.total)
	-- Roughly 0.6 of the height per glyph keeps the coin hugging the number.
	counter.label.Text, counter.label.Size = text, UDim2.fromScale(0.62 * #text, 1)
	counter.scale.Scale = style.Pop
	TweenService:Create(counter.scale, TweenInfo.new(style.PopSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = 1}):Play()
	counter.serial += 1
	local serial = counter.serial
	task.delay(style.Idle, function()
		if self.counter == counter and counter.serial == serial then self:Drop(counter) end
	end)
end

-- Removes every coin without landing it; ActionFeedback releases the held value.
function CoinBurst.Clear(self: Burst)
	for coin in self.coins do self:Remove(coin) end
	if self.counter then self.counter.gui:Destroy();self.counter = nil end
	for item in self.leftovers do item:Destroy() end
	table.clear(self.leftovers)
end

return CoinBurst
