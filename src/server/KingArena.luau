--!strict
-- Central landmark and idle guardian; BattleService alone owns challenge/occupancy.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Conquest = require(Shared.ConquestPresentation)
local MapLayout = require(Shared.MapLayout)
local KingVisual = require(Shared.KingVisual)
local PetView = require(Shared.PetView)
local PetActor = require(script.Parent.PetActor)
local IdlePatrol = require(script.Parent.IdlePatrol)
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

-- The King occupies roster slot one, followed by the Royal Flock in order.
-- Clear idle ownership before SetBusy so it cannot destroy transferred rigs.
function KingArena:TakeDefenders()
 if self.busy or self.ownerId then return {} end
 local actors={[1]=self.actor}
 for i,guard in self.guards or {} do actors[i+1]=guard end
 self.actor,self.guards,self.kingPatrol,self.guardPatrols=nil,{},nil,{}
 for _,actor in actors do actor:Stop() end
 return actors
end

function KingArena:SetBusy(busy, ownerName)
	self.busy=busy
	self.random = self.random or Random.new()
	self.kingPatrol, self.guardPatrols = nil, {}
	if self.actor then self.actor:Destroy(); self.actor = nil end
	for _,guard in self.guards or {} do guard:Destroy() end;self.guards={}
	self.folder:SetAttribute("Occupied", busy)
	self.folder:SetAttribute("OwnerUserId", self.ownerId)
	self.folder:SetAttribute("ConquerorUserId", self.ownerId)
	self.folder:SetAttribute("Conquered", self.ownerId~=nil)
	if not Builder.ApplyOwnershipFlag(self.folder,self.ownerId) then
		self.flag.Color = if self.ownerId then Conquest.Owned else Color3.fromRGB(228,59,49)
	end
	self.status.Text = if self.ownerId then (if self.hillMode then "⛰ Hill held ⛰\n" else "⚔ Conquered ⚔\n")..self.ownerName
		elseif busy then (if self.hillMode then "THE HILL\nContested" else "CHICKEN KING\nContested") else "CHICKEN KING"
	self.status.TextColor3=if self.ownerId then Conquest.Owned else palette.gold
	-- The living boss already owns its name/health label; only show this marker after capture.
	self.status.Parent.Enabled = self.ownerId~=nil
	if not busy and not self.ownerId and self.hillMode then
		-- An empty Hill shows its Hill Guards (the same roster an attacker fights).
		local roster=Config.IncomeOutpost.NeutralRoster
		for i,pet in roster do
			local angle=(i-1)*math.pi*2/#roster
			local radius=MapLayout.King.Radius*(10/29)
			local at=self.folder.KingSpawn.Position+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
			local guard=PetActor.new(self.folder,"HillGuard"..i,pet.species,pet.stars or 1,at,-at)
			PetView.Level(guard.model,pet.level or 1);guard:Stop();table.insert(self.guards,guard)
			local patrol=IdlePatrol.new(guard,self.random,3.4,0.25,1)
			patrol.angle=angle
			table.insert(self.guardPatrols,patrol)
		end
	elseif not busy and not self.ownerId then
		self.actor = PetActor.new(self.folder, "ChickenKing", "Duck", 1, self.folder.KingSpawn.Position, Vector3.new(0, 0, -1))
		KingVisual.Apply(self.actor.model, KingEncounter.Scale)
		self.actor.footOffset = self.actor.model:GetAttribute("FootOffset")
		self.actor:Stop()
		self.kingPatrol = IdlePatrol.new(self.actor, self.random, 2.1, 0.7, 2)
		local roster=KingEncounter.Definition().roster
		local guardCount=math.max(1,#roster-1)
		for i,pet in roster do if not pet.boss then
			local angle=(i-2)*math.pi*2/guardCount
			local radius=MapLayout.King.Radius*(13/29)
			local at=self.folder.KingSpawn.Position+Vector3.new(math.cos(angle)*radius,0,math.sin(angle)*radius)
			local guard=PetActor.new(self.folder,"RoyalFlock"..i,pet.species,1,at,-at)
			PetView.Level(guard.model,pet.level);guard:Stop();table.insert(self.guards,guard)
			local patrol = IdlePatrol.new(guard, self.random, 3.4, 0.25, 1)
			patrol.angle = angle
			table.insert(self.guardPatrols, patrol)
		end end
	end
end

function KingArena:Hold(userId, name)
	self.ownerId,self.ownerName=userId,name
	self.folder:SetAttribute("OwnerUserId", userId)
	self.folder:SetAttribute("ConquerorUserId", userId)
	self.folder:SetAttribute("Conquered",true)
	if not Builder.ApplyOwnershipFlag(self.folder,userId) then self.flag.Color = Conquest.Owned end
	self.status.Text = (if self.hillMode then "⛰ Hill held ⛰\n" else "⚔ Conquered ⚔\n") .. name
	self.status.TextColor3=Conquest.Owned
	self.status.Parent.Enabled = true
end

function KingArena:SetOwner(userId,name)
	self.ownerId,self.ownerName=userId,name
	self:SetBusy(self.busy==true)
	if userId then self:Hold(userId,name) end
end

-- The Hill takes over the arena during a round: Hill Guards replace the King
-- and the native command prompt targets the Hill (CommandTarget "income:1").
function KingArena:SetHillMode(open)
	if self.hillMode==open then return end
	self.hillMode=open
	self.folder:SetAttribute("CommandTarget",if open then Config.IncomeOutpost.TargetId else KingEncounter.Target)
	self.folder:SetAttribute("HillOpen",open)
	self:SetBusy(self.busy==true)
	if self.ownerId then self:Hold(self.ownerId,self.ownerName) end
end

-- One sign above the arena, readable from the plots, carries the round clock.
function KingArena:SetHillStatus(status)
	if not self.hillTimer then
		self.hillTimer=Builder.Billboard(self.folder,"HillTimer",self.folder.KingSpawn.Position+Vector3.new(0,30,0),"",palette.goldLight,420,1200)
		local gui=self.hillTimer.Parent :: BillboardGui
		gui.Size,gui.AlwaysOnTop=UDim2.fromOffset(420,96),true
		self.hillTimer.TextScaled=true
	end
	local remaining=math.max(0,math.ceil(status.remaining or 0))
	local clock=string.format("%d:%02d",remaining//60,remaining%60)
	local text
	if status.phase=="Open" then
		text="THE HILL · "..clock.."\n"..(if status.holderName then "Held by "..status.holderName else "Hill Guards hold it")
	elseif status.phase=="Opening" then text="THE HILL\nOpening soon"
	else text="THE HILL opens in "..clock..(if status.lastWinner then "\nLast winner: "..status.lastWinner else "") end
	if self.hillTimer.Text~=text then self.hillTimer.Text=text end
	self.hillTimer.TextColor3=if status.phase=="Open" then Conquest.Owned else palette.goldLight
end

function KingArena:Step(now)
	if self.hillMode and not self.busy and not self.ownerId then
		local center=self.folder.KingSpawn.Position
		for _,patrol in self.guardPatrols do
			patrol:Step(now,function()
				local angle=patrol.angle+self.random:NextNumber(-0.4,0.4)
				local radius=MapLayout.King.Radius*self.random:NextNumber(0.25,0.4)
				return Vector3.new(center.X+math.cos(angle)*radius,center.Y,center.Z+math.sin(angle)*radius)
			end)
		end
		return
	end
	if self.busy or self.ownerId or not self.kingPatrol then return end
	local center = self.folder.KingSpawn.Position
	local kingRadius = MapLayout.King.Radius * 0.16
	self.kingPatrol:Step(now, function()
		return IdlePatrol.DiskTarget(CFrame.new(center), kingRadius, {self.kingPatrol}, self.kingPatrol, self.random)
	end)
	local kingAt = self.actor:Position()
	-- Each soldier keeps its own sector around the living King. Small arc patrols
	-- and staggered pauses suggest an escort without a rigid orbit or extra animation.
	for _, patrol in self.guardPatrols do
		patrol:Step(now, function()
			local angle = patrol.angle + self.random:NextNumber(-0.3, 0.3)
			local radius = MapLayout.King.Radius * self.random:NextNumber(0.35, 0.42)
			return Vector3.new(kingAt.X + math.cos(angle) * radius, center.Y, kingAt.Z + math.sin(angle) * radius)
		end)
	end
end

-- First-visit film set: a copy of the idle arena (King, crown, Royal Flock, red
-- flag) kept in ReplicatedStorage, which is never drawn. A client clones it only on
-- its own screen while its film plays, so conquests and fights never reach the film.
-- Tags are parked in an attribute so no client manager adopts the stored copy.
function KingArena:SnapshotIntroSet()
	local set = self.folder:Clone()
	local CollectionService = game:GetService("CollectionService")
	local removed = {}
	local function strip(item: Instance)
		if item:IsA("BaseScript") or item:IsA("ProximityPrompt") or item:IsA("ClickDetector") or item:IsA("Sound") or item.Name == "HillTimer" then
			table.insert(removed, item);return
		end
		local tags = CollectionService:GetTags(item)
		if #tags > 0 then
			for _, tag in tags do CollectionService:RemoveTag(item, tag) end
			item:SetAttribute("IntroTags", table.concat(tags, ","))
		end
	end
	strip(set)
	for _, item in set:GetDescendants() do strip(item) end
	for _, item in removed do item:Destroy() end
	for _, name in {"Occupied", "OwnerUserId", "ConquerorUserId", "Conquered", "HillOpen"} do set:SetAttribute(name, nil) end
	set.Name = "PetRollIntroSet"
	set.Parent = game:GetService("ReplicatedStorage")
	return set
end

function KingArena:Destroy()
	self.kingPatrol, self.guardPatrols = nil, {}
	if self.actor then self.actor:Destroy(); self.actor = nil end
	for _,guard in self.guards or {} do guard:Destroy() end
	self.folder:Destroy()
end

return KingArena
