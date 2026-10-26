--!strict
-- October 24 (Stevin): the eggs you carry ride on your back, the way arcade-idle games
-- stack what the character carries (My Perfect Hotel, Burger Please): rows of
-- CollectionFeel.BackStack.RowSize eggs side by side, one row on top of the other, a
-- new row starting once the top row is full, up to Rows rows; the bag keeps counting
-- past that (the HUD's Carrying line is the number). October 25 (Stevin): the stack
-- rides rigidly with the player (the earlier per-row lag and lean read as dragging).
-- Presentation only: the server's
-- eggCarry (snapshot bagCount) is the truth. EggController owns one of these:
-- Update(count) each frame with the eggs the bag holds that are not still flying in,
-- Step(now) after it, Dump(origin) when the pad sells the bag, LandingPoint() as the
-- goal of a clicked egg's flight, NoteArrival(species) as one lands.
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Feel = require(Shared.CollectionFeel).BackStack
local Motion = require(Shared.EggMotion)
local EggView = require(script.Parent.EggView)

-- The voxel egg's decorated corner faces +X/+Z (EggView); turned to face behind the player.
local FRONT = CFrame.Angles(0, 3 * math.pi / 4, 0)
local POP = TweenInfo.new(Feel.PopSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local MAX_VISIBLE = Feel.RowSize * Feel.Rows

local Stack = {}
Stack.__index = Stack

type Item = {part: BasePart, height: number, width: number, position: Vector3}
type Flier = {part: BasePart, from: Vector3, to: Vector3, at: number, seed: number, size: Vector3}

function Stack.new(app, folder: Instance)
	return setmetatable({app = app, folder = folder, items = {} :: {Item}, fliers = {} :: {Flier},
		rows = {} :: {Vector3}, target = 0, species = {} :: {string}}, Stack)
end

-- The part the stack rides: the upper back of the character (R15 or R6), else the root.
local function back(): BasePart?
	local character = Players.LocalPlayer.Character
	if not character then return nil end
	local part = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

-- A clicked egg that just landed: its kind is the next egg on the stack.
function Stack:NoteArrival(species: string?)
	if type(species) == "string" and #self.species < MAX_VISIBLE then table.insert(self.species, species) end
end

-- Row and column (0-based) of a slot.
local function place(slot: number): (number, number)
	local row = math.ceil(slot / Feel.RowSize)
	local column = (slot - 1) % Feel.RowSize
	return row, column
end

-- A column's sideways offset in studs, centred on the back.
local function across(self, column: number): number
	local sample: Item? = self.items[1]
	local spacing = (if sample then sample.width else 0.6) + Feel.Gap
	return (column - (Feel.RowSize - 1) / 2) * spacing
end

local function rowHeight(self): number
	local sample: Item? = self.items[1]
	return (if sample then sample.height else 0.875) + Feel.Gap
end

-- World position of a slot's bottom centre, from the row anchors.
local function slotPosition(self, anchor: BasePart, slot: number): Vector3
	local row, column = place(slot)
	local rowPosition: Vector3? = self.rows[row]
	if not rowPosition then
		local below: Vector3? = self.rows[row - 1]
		rowPosition = if below then below + Vector3.new(0, rowHeight(self), 0)
			else (anchor.CFrame * CFrame.new(0, Feel.Lift, Feel.Behind)).Position
	end
	return (rowPosition :: Vector3) + anchor.CFrame.RightVector * across(self, column)
end

-- World position where the next egg lands (its slot on the stack), or nil without a back.
function Stack:LandingPoint(): Vector3?
	local anchor = back()
	if not anchor then return nil end
	return slotPosition(self, anchor, math.min(#self.items + 1, MAX_VISIBLE))
end

local function makeItem(self, at: Vector3): Item?
	local species = table.remove(self.species, 1)
	local source = EggView.Template(species)
	if not source then return nil end
	local part = source:Clone()
	part.Name = "BackEgg" .. (#self.items + 1)
	for _, child in part:GetChildren() do
		-- One part per egg on the back: no glow, sparkle or attachments ride along.
		if not child:IsA("SpecialMesh") and not child:IsA("SurfaceAppearance") then child:Destroy() end
	end
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	local full = source.Size * Feel.Scale
	local reduced = self.app.reducedMotion == true
	part.Size = if reduced then full else full * 0.4
	part.CFrame = CFrame.new(at)
	part.Parent = self.folder
	if not reduced then TweenService:Create(part, POP, {Size = full}):Play() end
	local height = (tonumber(source:GetAttribute("EggHeight")) or 1.75) * Feel.Scale
	return {part = part, height = height, width = full.X, position = at}
end

-- How many eggs the stack should show right now (the bag minus eggs still flying in).
function Stack:Update(count: number)
	self.target = math.clamp(math.floor(count), 0, MAX_VISIBLE)
end

function Stack:Count(): number
	return #self.items
end

-- Pour the stack into the pad (a sale): every egg flies to `origin` and is gone.
function Stack:Dump(origin: Vector3?, now: number)
	if #self.items == 0 then return end
	for index = #self.items, 1, -1 do
		local item: Item = self.items[index]
		if origin and not self.app.reducedMotion then
			table.insert(self.fliers, {part = item.part, from = item.position, to = origin,
				at = now + (#self.items - index) * Feel.DumpStagger, seed = index, size = item.part.Size})
		else
			item.part:Destroy()
		end
		self.items[index] = nil
	end
	table.clear(self.rows)
	table.clear(self.species)
end

function Stack:Step(now: number)
	local anchor = back()
	-- Grow or shrink toward the target, one egg a frame so a burst of pickups still reads.
	if anchor and #self.items < self.target then
		local item = makeItem(self, slotPosition(self, anchor, #self.items + 1))
		if item then table.insert(self.items, item) end
	elseif #self.items > self.target then
		local item: Item? = table.remove(self.items)
		if item then item.part:Destroy() end
	end
	if anchor then
		local cf = anchor.CFrame
		local look, right = cf.LookVector, cf.RightVector
		local base = (cf * CFrame.new(0, Feel.Lift, Feel.Behind)).Position
		local rowCount = math.ceil(#self.items / Feel.RowSize)
		for row = #self.rows, rowCount + 1, -1 do self.rows[row] = nil end
		local height = rowHeight(self)
		-- October 25 (Stevin): the stack rides rigidly with the player, no drag or sway;
		-- each row sits straight on the one below.
		for row = 1, rowCount do
			self.rows[row] = base + Vector3.new(0, height * (row - 1), 0)
		end
		for slot, item in ipairs(self.items :: {Item}) do
			local row, column = place(slot)
			local rowPosition: Vector3 = self.rows[row] or base
			item.position = rowPosition + right * across(self, column)
			item.part.CFrame = CFrame.lookAt(item.position, item.position + look) * FRONT
		end
	end
	-- Eggs pouring into the pad.
	for index = #self.fliers, 1, -1 do
		local flier: Flier = self.fliers[index]
		local t = (now - flier.at) / Feel.DumpSeconds
		if t >= 1 then
			flier.part:Destroy()
			table.remove(self.fliers, index)
		elseif t >= 0 then
			local position = Motion.Flight(flier.from, flier.to, t, flier.seed, false)
			local shrink = 1 - math.clamp((t - 0.6) / 0.4, 0, 1) * 0.8
			flier.part.CFrame = CFrame.new(position) * FRONT
			flier.part.Size = flier.size * shrink
			flier.part.Transparency = math.clamp((t - 0.7) / 0.3, 0, 1)
		end
	end
end

function Stack:Destroy()
	for _, item in self.items do item.part:Destroy() end
	for _, flier in self.fliers do flier.part:Destroy() end
	table.clear(self.items);table.clear(self.fliers);table.clear(self.rows);table.clear(self.species)
end

return Stack
