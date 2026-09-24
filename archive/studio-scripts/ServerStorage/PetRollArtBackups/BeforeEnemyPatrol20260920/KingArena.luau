--!strict
-- Central landmark and idle guardian; BattleService alone owns challenge/occupancy.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local MapLayout = require(Shared.MapLayout)
local KingVisual = require(Shared.KingVisual)
local PetView = require(Shared.PetView)
local PetActor = require(script.Parent.PetActor)
local Builder = require(script.Parent.WorldBuilder)
local KingEncounter = require(script.Parent.KingEncounter)
local KingArena = {}
KingArena.__index = KingArena

local palette = {
	timber = Color3.fromRGB(170, 85, 0), darkTimber = Color3.fromRGB(117, 59, 0),
	brace = Color3.fromRGB(255, 137, 97), stone = Color3.fromRGB(141, 141, 211),
	stoneLight = Color3.fromRGB(188, 192, 255), cream = Color3.fromRGB(240, 230, 204),
	gold = Color3.fromRGB(255, 170, 0), goldLight = Color3.fromRGB(255, 205, 59),
	red = Color3.fromRGB(198, 66, 53), floorMark = Color3.fromRGB(224, 217, 193),
}

local function model(parent, name, frame)
	local group = Instance.new("Model")
	group.Name, group.Parent = name, parent
	if frame then group.WorldPivot = frame end
	return group
end

local function part(parent, name, size, frame, color, studs, shadow)
	local item = Builder.Part(parent, name, size, frame, color, false)
	item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
	item.Material = Enum.Material.Plastic
	item.TopSurface = if studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.CastShadow = shadow == true
	return item
end

local function disk(parent, name, radius, height, y, color)
	local item = Builder.Disk(parent, name, radius, height, Vector3.new(0, y, 0), color, false)
	item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
	item.Material, item.CastShadow = Enum.Material.Plastic, false
	return item
end

local function radialFrame(bearing, radius)
	local angle = math.rad(bearing)
	local at = Vector3.new(math.sin(angle) * radius, MapLayout.FieldY, -math.cos(angle) * radius)
	return CFrame.lookAt(at, Vector3.new(0, MapLayout.FieldY, 0))
end

local function buildPerimeter(folder)
	local wallRoot = model(folder, "LowPerimeter")
	local bannerRoot = model(folder, "RoyalBanners")
	for sector = 0, 5 do
		local middleBearing = 30 + sector * 60
		local section = model(wallRoot, "Section" .. (sector + 1))
		for segment = -1, 1 do
			local frame = radialFrame(middleBearing + segment * 9, MapLayout.King.Radius - 0.7)
			local suffix = tostring(segment + 2)
			part(section, "StoneFoot" .. suffix, Vector3.new(4.15, 0.65, 0.9), frame * CFrame.new(0, 0.325, 0), palette.stone, true, true)
			part(section, "TimberRail" .. suffix, Vector3.new(4.15, 1.45, 0.65), frame * CFrame.new(0, 1.375, 0),
				if sector % 2 == 0 then palette.timber else palette.stoneLight, true, true)
			part(section, "TopTrim" .. suffix, Vector3.new(4.15, 0.4, 0.85), frame * CFrame.new(0, 2.3, 0), palette.darkTimber, true, true)
		end
		-- Offset toward the sector edge so the first banner does not hide behind the throne.
		local bannerFrame = radialFrame(middleBearing - 10.5, 26.7)
		local banner = model(bannerRoot, "RoyalBanner" .. (sector + 1), bannerFrame)
		part(banner, "Post", Vector3.new(0.5, 8, 0.5), bannerFrame * CFrame.new(0, 4, 0), palette.timber, true, true)
		part(banner, "Crossbar", Vector3.new(3.35, 0.35, 0.5), bannerFrame * CFrame.new(0, 7.7, 0), palette.gold, true, true)
		part(banner, "Cloth", Vector3.new(3, 4, 0.15), bannerFrame * CFrame.new(0, 5.45, -0.35), palette.red, false, false)
		part(banner, "GoldHem", Vector3.new(3, 0.2, 0.18), bannerFrame * CFrame.new(0, 3.55, -0.36), palette.gold, false, false)
		part(banner, "CrownBadge", Vector3.new(0.8, 0.8, 0.12), bannerFrame * CFrame.new(0, 5.6, -0.49), palette.goldLight, false, false)
	end
end

local function buildThrone(folder)
	local frame = radialFrame(30, 23.5)
	local throne = model(folder, "Throne", frame)
	throne:SetAttribute("GroundWidth", 6)
	throne:SetAttribute("GroundDepth", 5)
	part(throne, "Dais", Vector3.new(6, 0.5, 5), frame * CFrame.new(0, 0.25, 0), palette.stone, true, true)
	part(throne, "Step", Vector3.new(5.25, 0.5, 4), frame * CFrame.new(0, 0.75, -0.4), palette.stoneLight, true, true)
	part(throne, "SeatFrame", Vector3.new(4.8, 1.4, 3), frame * CFrame.new(0, 1.7, -0.25), palette.timber, true, true)
	part(throne, "SeatCushion", Vector3.new(4.4, 0.45, 2.8), frame * CFrame.new(0, 2.625, -0.3), palette.red, false, true)
	part(throne, "Back", Vector3.new(6, 10.5, 0.7), frame * CFrame.new(0, 6.25, 2.1), palette.timber, true, true)
	part(throne, "BackCushion", Vector3.new(4.75, 8.3, 0.15), frame * CFrame.new(0, 6.15, 1.675), palette.red, false, true)
	for _, side in { -1, 1 } do
		part(throne, "Arm" .. side, Vector3.new(0.6, 2.3, 3.75), frame * CFrame.new(side * 2.7, 2.15, 0.1), palette.timber, true, true)
		part(throne, "ArmCap" .. side, Vector3.new(0.6, 0.3, 3.75), frame * CFrame.new(side * 2.7, 3.45, 0.1), palette.gold, true, true)
		part(throne, "BackTrim" .. side, Vector3.new(0.45, 10.5, 0.8), frame * CFrame.new(side * 2.75, 6.25, 2.05), palette.gold, true, true)
	end
	local crown = model(throne, "CrownLandmark", frame * CFrame.new(0, 11.5, 2.05))
	part(crown, "Band", Vector3.new(6, 0.7, 0.75), frame * CFrame.new(0, 11.85, 2.05), palette.gold, true, true)
	for index, x in { -2.4, -1.2, 0, 1.2, 2.4 } do
		local height = if index == 3 then 3.3 elseif index % 2 == 1 then 2.8 else 2
		part(crown, "Prong" .. index, Vector3.new(if index % 2 == 1 then 1.2 else 1, height, 0.75),
			frame * CFrame.new(x, 12.2 + height / 2, 2.05), palette.goldLight, true, true)
	end
	part(crown, "RedJewel", Vector3.new(0.65, 0.65, 0.15), frame * CFrame.new(0, 11.85, 1.575), palette.red, false, false)
	local offerings = model(folder, "FeedOfferings", frame)
	for _, side in { -1, 1 } do
		local at = frame * CFrame.new(side * 4.15, 0, 1.2)
		part(offerings, "Box" .. side, Vector3.new(2, 1.25, 2), at * CFrame.new(0, 0.625, 0), palette.timber, true, true)
		part(offerings, "Feed" .. side, Vector3.new(1.7, 0.25, 1.7), at * CFrame.new(0, 1.375, 0), palette.goldLight, true, true)
	end
end

function KingArena.new(root)
	local existing=root:GetAttribute("AuthoredMap") and root:FindFirstChild("KingArena")
	if existing then
		local self=setmetatable({folder=existing,entries={},actor=nil,flag=existing.CaptureFlag,status=existing.ArenaStatus.Label.Text},KingArena)
		for i=1,#Config.PlotPositions do table.insert(self.entries,existing["Entrance"..i].EntryStripe) end
		self:SetBusy(false)
		return self
	end
	local folder = Instance.new("Model"); folder.Name, folder.Parent = "KingArena", root
	folder:SetAttribute("CommandTarget",KingEncounter.Target)
	folder:SetAttribute("SceneryVersion", 3)
	folder:SetAttribute("ArenaRadius", MapLayout.King.Radius)
	local self = setmetatable({folder = folder, entries = {}, actor = nil}, KingArena)
	local floorY = MapLayout.FieldY
	disk(folder, "ArenaRim", MapLayout.King.Radius, 0.012, floorY + 0.008, palette.stone)
	disk(folder, "GoldInset", MapLayout.King.FloorRadius + 0.3, 0.008, floorY + 0.014, palette.gold)
	disk(folder, "BattleFloor", MapLayout.King.FloorRadius, 0.008, floorY + 0.020, palette.cream)
	disk(folder, "CaptureBoundary", Config.CaptureRadius + 0.2, 0.008, floorY + 0.026, palette.floorMark)
	disk(folder, "CaptureFloor", Config.CaptureRadius, 0.008, floorY + 0.032, palette.cream)
	for i, at in Config.PlotPositions do
		local outward = Vector3.new(at[1], 0, at[2]).Unit
		local frame = CFrame.lookAt(outward * 26 + Vector3.new(0, floorY, 0), Vector3.new(0, floorY, 0))
		local entry = model(folder, "Entrance" .. i, frame)
		local stripe = part(entry, "EntryStripe", Vector3.new(14, 0.012, 2), frame * CFrame.new(0, 0.046, 0), palette.cream, false, false)
		for _, side in { -1, 1 } do
			local postFrame = frame * CFrame.new(side * 7.7, 0, 0)
			part(entry, "StoneFoot" .. side, Vector3.new(1.35, 0.5, 1.35), postFrame * CFrame.new(0, 0.25, 0), palette.stone, true, true)
			part(entry, "Post" .. side, Vector3.new(1.25, 4.5, 1.25), postFrame * CFrame.new(0, 2.75, 0), palette.timber, true, true)
			part(entry, "Cap" .. side, Vector3.new(1.35, 0.5, 1.35), postFrame * CFrame.new(0, 5.25, 0), palette.gold, true, true)
			part(entry, "Brace" .. side, Vector3.new(0.25, 1.15, 0.15), postFrame * CFrame.new(0, 1.6, -0.7) * CFrame.Angles(0, 0, math.rad(35)), palette.brace, false, false)
		end
		table.insert(self.entries, stripe)
	end
	buildPerimeter(folder)
	buildThrone(folder)
	local emblem = model(folder, "FloorEmblem")
	part(emblem, "Band", Vector3.new(5.5, 0.008, 0.7), CFrame.new(0, floorY + 0.04, 1.2), palette.floorMark, false, false)
	for index, x in { -2, 0, 2 } do
		part(emblem, "Prong" .. index, Vector3.new(1, 0.008, if index == 2 then 3 else 2.3),
			CFrame.new(x, floorY + 0.04, -0.3), palette.floorMark, false, false)
	end
	local flagFrame = radialFrame(210, 23.5)
	part(folder, "CaptureFlagPole", Vector3.new(0.4, 9, 0.4), flagFrame * CFrame.new(0, 4.5, 0), palette.timber, true, true)
	self.flag = part(folder, "CaptureFlag", Vector3.new(4, 2.4, 0.15), flagFrame * CFrame.new(1.8, 7.3, -0.25), palette.red, false, false)
	self.status = Builder.Billboard(folder, "ArenaStatus", Vector3.new(0, 20, 0), "CHICKEN KING", palette.gold, 220, 220)
	for name, position in {KingSpawn = Vector3.new(0, floorY, 0), CaptureAnchor = Vector3.new(0, floorY, 0)} do
		local anchor = part(folder, name, Vector3.one, CFrame.new(position), palette.gold, false, false)
		anchor.Transparency, anchor.CanQuery = 1, false
	end
	local staticParts = 0
	for _, item in folder:GetDescendants() do
		if item:IsA("BasePart") then staticParts += 1 end
	end
	folder:SetAttribute("StaticPartCount", staticParts)
	self:SetBusy(false)
	return self
end

function KingArena:SetBusy(busy, ownerName)
	self.busy=busy
	if self.actor then self.actor:Destroy(); self.actor = nil end
	for _,guard in self.guards or {} do guard:Destroy() end;self.guards={}
	self.folder:SetAttribute("Occupied", busy)
	self.folder:SetAttribute("OwnerUserId", self.ownerId)
	self.folder:SetAttribute("ConquerorUserId", self.ownerId)
	self.folder:SetAttribute("Conquered", self.ownerId~=nil)
	self.flag.Color = if self.ownerId then Color3.fromRGB(98,226,56) else Color3.fromRGB(228,59,49)
	self.status.Text = if busy then "CHICKEN KING\nContested" elseif self.ownerId then "CROWN CAPTURED\n"..self.ownerName else "CHICKEN KING"
	-- The living boss already owns its name/health label; only show this marker after capture.
	self.status.Parent.Enabled = self.ownerId~=nil and not busy
	if not busy and not self.ownerId then
		self.actor = PetActor.new(self.folder, "ChickenKing", "Duck", 1, self.folder.KingSpawn.Position, Vector3.new(0, 0, -1))
		KingVisual.Apply(self.actor.model, KingEncounter.Scale)
		self.actor.footOffset = self.actor.model:GetAttribute("FootOffset")
		self.actor:Stop()
		local roster=KingEncounter.Definition().roster
		local guardCount=math.max(1,#roster-1)
		for i,pet in roster do if not pet.boss then
			local angle=(i-2)*math.pi*2/guardCount
			local radius=MapLayout.King.Radius*(13/29)
			local at=self.folder.KingSpawn.Position+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
			local guard=PetActor.new(self.folder,"RoyalFlock"..i,pet.species,1,at,-at)
			PetView.Level(guard.model,pet.level);guard:Stop();table.insert(self.guards,guard)
		end end
	end
end

function KingArena:Hold(userId, name)
	self.ownerId,self.ownerName=userId,name
	self.folder:SetAttribute("OwnerUserId", userId)
	self.folder:SetAttribute("ConquerorUserId", userId)
	self.folder:SetAttribute("Conquered",true)
	self.flag.Color = Color3.fromRGB(98, 226, 56)
	self.status.Text = "CROWN CAPTURED\n" .. name
	self.status.Parent.Enabled = true
end

function KingArena:SetOwner(userId,name)
	self.ownerId,self.ownerName=userId,name
	self:SetBusy(self.busy==true)
	if userId then self:Hold(userId,name) end
end

function KingArena:Step(now)
	if self.actor then self.actor:Step(now) end
	for _,guard in self.guards or {} do guard:Step(now) end
end

function KingArena:Destroy()
	if self.actor then self.actor:Destroy(); self.actor = nil end
	for _,guard in self.guards or {} do guard:Destroy() end
	self.folder:Destroy()
end

return KingArena
