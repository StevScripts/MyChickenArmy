--!strict
-- October 20 egg-sale coin burst. Presentation only: the server has already paid.
-- Gold coins pop out of the sell pad, bounce, then fly into the player one after
-- another; `land` reports each coin's share as it arrives so the HUD counts up.
-- Every move is a native tween: a coin's Attachment slides across the pad while its
-- BillboardGui's world offset rises and drops with a Bounce ease. For the fly-in the
-- Attachment moves onto the HumanoidRootPart, so a walking player is followed
-- without a frame loop. Tune CollectionFeel.CoinBurst.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Feel = require(game:GetService("ReplicatedStorage").PetRoll.Shared.CollectionFeel).CoinBurst
local Theme = require(script.Parent.UITheme)
local CoinBurst = {}
CoinBurst.__index = CoinBurst

type Land = (share: number, index: number, quiet: boolean) -> ()
type Coin = {
	index: number, share: number, size: number, attachment: Attachment, gui: BillboardGui,
	land: Land, flip: Tween, tweens: {Tween}, done: boolean,
}
type State = {coins: {[Coin]: boolean}, active: number, random: Random}
type Burst = typeof(setmetatable({} :: State, CoinBurst))

function CoinBurst.new(): Burst
	return setmetatable({coins = {}, active = 0, random = Random.new()} :: State, CoinBurst)
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
	if (root.Position - world).Magnitude > Feel.MaxDistance then self:Finish(coin, true);return end
	for _, animation in coin.tweens do animation:Cancel() end
	table.clear(coin.tweens)
	coin.gui.StudsOffsetWorldSpace = Vector3.zero
	coin.attachment.Parent = root
	coin.attachment.Position = root.CFrame:PointToObjectSpace(world)
	local small = coin.size * 0.55
	tween(coin, coin.gui, TweenInfo.new(Feel.FlySeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Size = UDim2.fromScale(small, small)})
	tween(coin, coin.attachment, TweenInfo.new(Feel.FlySeconds, Enum.EasingStyle.Back, Enum.EasingDirection.In),
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
	coin.land(coin.share, coin.index, quiet)
end

-- Removes every coin without landing it; ActionFeedback releases the held value.
function CoinBurst.Clear(self: Burst)
	for coin in self.coins do self:Remove(coin) end
end

return CoinBurst
