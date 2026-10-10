--!strict
-- Owns home flock presentation, physical recruitment, and personal camp landmarks.
-- Each visible chicken has one PetActor; encounter handoffs transfer that ownership.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local Config = require(Shared.Config)
local Progression = require(Shared.Progression)
local PetView = require(Shared.PetView)
local FlockLayout = require(Shared.FlockLayout)
local HomePlot = require(Shared.HomePlotLayout)
local MapLayout = require(Shared.MapLayout)
local CampCommand=require(Shared.CampCommand)
local UIColors = require(Shared.UIColors)
local PetActor = require(script.Parent.PetActor)
local IdlePatrol = require(script.Parent.IdlePatrol)
local RollStation = require(script.Parent.RollStation)
local MergeStand = require(script.Parent.MergeStand)
local Builder = require(script.Parent.WorldBuilder)
local KingArena = require(script.Parent.KingArena)
local AuthoredMap = require(script.Parent.AuthoredMap)
local PlotUpgradeService = require(script.Parent.PlotUpgradeService)
local OperationRewards=require(script.Parent.OperationRewards)
local WorldService = {}
WorldService.__index = WorldService

local YARD_MIN_X, YARD_MAX_X, YARD_MIN_Z, YARD_MAX_Z = HomePlot.YardMinX, HomePlot.YardMaxX, HomePlot.YardMinZ, HomePlot.YardMaxZ
local MAX_WANDERING = 12
local MAX_VISIBLE = Config.LegacyCollectionLimit
local FOOT_Y = HomePlot.FootY

local function attribute(instance, name, value)
	if instance:GetAttribute(name) ~= value then instance:SetAttribute(name, value) end
end

local function disposeActors(actors)
	for _, actor in actors do actor:Destroy() end
	table.clear(actors)
end

function WorldService.new()
	return setmetatable({plots = {}, lanes = {}, outposts = {}, campModels = {}, campAppearance = {}, revisions = {},
		lastRoamAt = 0, random = Random.new(4129)}, WorldService)
end

function WorldService:Position(index: number): Vector3
	return self:PlotFrame(index).Position
end

function WorldService:PlotFrame(index: number): CFrame
	return MapLayout.HomeFrame(index)
end

function WorldService:CampPosition(index: number, plotIndex: number): Vector3
	local record = self.lanes[plotIndex] and self.lanes[plotIndex][index]
	if record then return record.frame.Position end
	local plot = self:Position(plotIndex)
	local radius = Config.CampRadii[index]
	assert(radius, "Unknown camp index")
	local outward = Vector3.new(plot.X, 0, plot.Z).Unit
	return outward * radius + Vector3.new(0, 1.05, 0)
end

function WorldService:CampFrame(index: number, plotIndex: number): CFrame
	local record = self.lanes[plotIndex] and self.lanes[plotIndex][index]
	if record then return record.frame end
	local p = self:CampPosition(index, plotIndex)
	return CFrame.lookAt(p, Vector3.new(0, p.Y, 0))
end

function WorldService:OutpostFrame(index)
 -- Interleave six exploration destinations between the six home spokes.
 local angle=-math.pi/3+(index-1)*math.pi/3
 local radius=Config.Map.OutpostRadius
 local p=Vector3.new(math.cos(angle)*radius,1.05,math.sin(angle)*radius)
 return CFrame.lookAt(p,Vector3.new(0,p.Y,0))
end

local function hillEnabled() return Config.Hill~=nil and Config.Hill.Enabled==true end

function WorldService:IncomeFrame()
 local p=Config.IncomeOutpost.Position
 local position=Vector3.new(p[1],p[2],p[3])
 -- The Hill sits at the arena center, where a look-at-center frame is undefined.
 if Vector3.new(position.X,0,position.Z).Magnitude<1 then return CFrame.new(position) end
 return CFrame.lookAt(position,Vector3.new(0,position.Y,0))
end

function WorldService:SetHillMode(open)
 if self.kingArena then self.kingArena:SetHillMode(open) end
end

function WorldService:SetHillStatus(status)
 if self.kingArena then self.kingArena:SetHillStatus(status) end
end

function WorldService:HomePosition(index: number, ordinal: number): Vector3
	local layout=HomePlot.ForPlot(index)
	local x,z=HomePlot.Home(ordinal,index)
	return (self:PlotFrame(index)*CFrame.new(x,layout.FootY,z)).Position
end

function WorldService:ReservePosition(index: number, ordinal: number): Vector3
	return self:HomePosition(index, ordinal)
end

function WorldService:AssemblyPosition(index: number, ordinal: number, count: number): Vector3
	local x, z = FlockLayout.Assembly(ordinal, count)
	z=HomePlot.ForPlot(index).AssemblyZ+(ordinal-1)*3.4
	return (self:PlotFrame(index) * CFrame.new(x, HomePlot.ForPlot(index).FootY, z)).Position
end

function WorldService:ReturnPosition(session, petId: string, fallback: number?): Vector3
	local plot = self.plots[session.plotIndex]
	if not plot then return self:HomePosition(session.plotIndex, fallback or 1) end
	local ordinal = plot.homeOrdinals[petId]
	if not ordinal then
		local used = {}
		for id, n in plot.homeOrdinals do if session.pets[id] then used[n] = true else plot.homeOrdinals[id] = nil end end
		for n = 1, MAX_VISIBLE do if not used[n] then ordinal = n; break end end
		ordinal = ordinal or fallback or 1 -- Legacy over-capacity birds share the bounded yard temporarily.
		plot.homeOrdinals[petId] = ordinal
	end
	return self:HomePosition(session.plotIndex, ordinal)
end

function WorldService:RoamTarget(index: number, from: Vector3, petId: string?): Vector3
	local cf = self:PlotFrame(index)
	local layout=HomePlot.ForPlot(index)
	local plot = self.plots[index]
	local actor = plot and petId and plot.actors[petId]
	local best, bestScore = from, -math.huge
	local localFrom = cf:PointToObjectSpace(from)
	if layout.YardRegions then
		local x, z = HomePlot.Clamp(layout, localFrom.X, localFrom.Z)
		if math.abs(x - localFrom.X) + math.abs(z - localFrom.Z) > 0.05 then
			return (cf * CFrame.new(x, layout.FootY, z)).Position
		end
	end
	-- Sample the whole walkable yard and favor space not occupied or reserved by
	-- another chicken. Small random steps kept the flock near its starting row.
	for _ = 1, 12 do
		local x, z = HomePlot.Sample(layout, self.random:NextNumber(), self.random:NextNumber())
		if not HomePlot.CanWalkDirect(layout, localFrom.X, localFrom.Z, x, z) then continue end
		local candidate = (cf * CFrame.new(x, layout.FootY, z)).Position
		if actor and not actor:CanStandAt(candidate) then continue end
		local travel = (candidate - from).Magnitude
		local clearance = 24
		if plot then for id, home in plot.roaming do if id ~= petId then
			clearance = math.min(clearance, (candidate - home.position).Magnitude)
			if home.moving then clearance = math.min(clearance, (candidate - home.target).Magnitude) end
		end end end
		local score = clearance - (if travel < 6 then 20 else 0)
		if score > bestScore then best, bestScore = candidate, score end
	end
	return best
end

function WorldService:TakeActor(index: number, petId: string)
	local plot = self.plots[index]
	if not plot then return nil end
	local actor = plot.actors[petId]
	if plot.mergeStand and plot.mergeStand:IsRevealing(petId) then plot.mergeStand:ResetAnimation() end
	plot.actors[petId], plot.roaming[petId] = nil, nil
	if actor then actor:Stop(); attribute(actor.model, "AtHome", false) end
	return actor
end

function WorldService:RestoreActor(session, petId: string, actor)
	local plot, pet = self.plots[session.plotIndex], session.pets[petId]
	if not plot or not pet then actor:Destroy(); return end
	-- Explicit home/teleport commands can reclaim a rig during the reveal.
	-- Release the temporary scale/anchor while retaining the commanded position.
	if plot.mergeStand and plot.mergeStand:IsRevealing(petId) and plot.mergeStand.reveal.actor==actor then
		local at=actor:Position()
		plot.mergeStand:ResetAnimation();actor:Teleport(at)
	end
	local previous = plot.actors[petId]
	if not previous then
		local count = 0
		for _ in plot.actors do count += 1 end
		if count >= MAX_VISIBLE then
			local best = {}
			for _, id in session:BestPetIds() do best[id] = true end
			if not best[petId] then actor:Destroy(); return false end
			local evicted = false
			for id, old in plot.actors do
				if not best[id] then
					old:Destroy(); plot.actors[id], plot.roaming[id] = nil, nil
					evicted = true; break
				end
			end
			if not evicted then actor:Destroy(); return false end
		end
	end
	if previous and previous ~= actor then previous:Destroy() end
	actor:Stop()
	actor.model.Name = petId
	actor:SetParent(plot.pets)
	for _, name in {"BattleId", "UnitId", "Side", "Defeated", "AttackSerial", "Reinforcing"} do actor.model:SetAttribute(name, nil) end
	actor.model:SetAttribute("AtHome", true)
	actor.model:SetAttribute("OwnerUserId", session.userId)
	actor.model:SetAttribute("OwnerId", session.userId)
	actor.model:SetAttribute("PetId", petId)
	actor.model:SetAttribute("Recruiting", false)
	PetView.Level(actor.model,pet.level or 1,pet.giantSize)
	if PetView.Flash then PetView.Flash(actor.model, false) end
	if PetView.Cash then PetView.Cash(actor.model, 0, false) end
	local at = actor:Position()
	plot.actors[petId] = actor
	plot.roaming[petId] = {position = at, target = at, moving = false, pauseUntil = os.clock() + self.random:NextNumber(1, 4),
		recoveryFoot = self:ReturnPosition(session, petId)}
	return true
end

function WorldService:Recruit(session, petId: string)
	local plot, pet = self.plots[session.plotIndex], session.pets[petId]
	if not plot or not pet or not session:IsPetHome(petId) or plot.actors[petId] then return end
	if #plot.pets:GetChildren() >= MAX_VISIBLE then return end
	local at = (plot.station.frame * CFrame.new(0, FOOT_Y, -9)).Position
	local actor = PetActor.new(plot.pets, petId, pet.species, pet.stars, at, self:PlotFrame(session.plotIndex).RightVector)
	if not self:RestoreActor(session, petId, actor) then return end
	local home = plot.roaming[petId]
	home.target, home.moving, home.startedAt = self:ReturnPosition(session, petId), true, os.clock()
	home.recruiting = true
	actor.model:SetAttribute("Recruiting", true)
	actor:MoveTo(home.target, math.max(5, Config.RoamSpeed))
end

function WorldService:PetPosition(index: number, petId: string): Vector3?
	local plot = self.plots[index]
	local actor = plot and plot.actors[petId]
	return actor and actor:Position()
end

function WorldService:SpawnFrame(index: number): CFrame
	local record=self.plots[index]
	local anchors=record and record.folder:FindFirstChild("Anchors",true)
	local spawn=anchors and anchors:FindFirstChild("Spawn")
	if spawn and spawn:IsA("BasePart") then return spawn.CFrame end
	local plot = self:PlotFrame(index)
	local at = (plot * HomePlot.ForPlot(index).Spawn).Position
	return CFrame.lookAt(at, at+plot.LookVector*20)
end

-- Player travel uses the whole owned plot, not the smaller chicken-wandering yard.
function WorldService:UpdatePlayerSpeed(player, index: number)
	local character=player and player.Character
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local plot=self.plots[index]
	local deck=plot and plot.folder:FindFirstChild("Deck")
	if not humanoid or humanoid.Health<=0 or not root or not deck or not deck:IsA("BasePart") then return end
	local position=deck.CFrame:PointToObjectSpace(root.Position)
	-- Start the boost just beyond the edge; restore normal speed on re-entry.
	-- Ignoring height keeps jumps on the base at the home speed.
	local padding=if humanoid:GetAttribute("OutsideHomeBase")==true then 0 else Config.PlayerTravelBoundaryPadding
	local outside=math.abs(position.X)>deck.Size.X/2+padding or math.abs(position.Z)>deck.Size.Z/2+padding
	local speed=if outside then Config.PlayerTravelWalkSpeed else Config.PlayerHomeWalkSpeed
	speed*=1+(plot.researchWalk or 0)
	if humanoid.WalkSpeed~=speed then humanoid.WalkSpeed=speed end
	attribute(humanoid,"OutsideHomeBase",outside)
end

function WorldService:CanUseStation(player, session, index, action, offerId): boolean
	if index ~= session.plotIndex then return false end
	local plot = self.plots[index]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not plot or not root then return false end
	if action=="Buy" then
		if type(offerId)~="string" or #offerId>80 then return false end
		for slot,station in plot.stations do
			local offer=session.offers and session.offers[slot]
			if slot<=session.rollSlotCount and offer and offer.id==offerId then
				return (root.Position-station.podium.Position).Magnitude<=8
			end
		end
		return false
	end
	return (root.Position - plot.station.leverBase.Position).Magnitude <= Config.RollInteractDistance
end

function WorldService:EggDeposit(index)
 local plot=self.plots[index]
 if not plot or not plot.folder:GetAttribute("EggDepositEnabled") then return nil end
 return plot.folder:FindFirstChild("sellpart",true),plot.ownerId
end

-- Match the physical prompt's entrance position; all client attack requests pass here.
function WorldService:CanCommand(player,session,targetId,sessions): boolean
	if type(targetId)~="string" then return false end
 local kind,id=targetId:match("^(%a+):([%-]?%d+)$")
	local index=tonumber(id)
	local model
	if targetId=="king:1" then model=self.kingArena and self.kingArena.folder
	elseif targetId=="income:1" and hillEnabled() then model=self.kingArena and self.kingArena.folder
	elseif targetId=="income:1" and Config.IncomeOutpost.Enabled then model=self.incomeOutpost and self.incomeOutpost.folder
	elseif kind=="camp" and index then
		local record=self.lanes[session.plotIndex] and self.lanes[session.plotIndex][index]
		model=record and record.folder
	elseif kind=="outpost" and index then
  local record=self.outposts[index];model=record and record.folder
	end
	local body=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return model~=nil and body~=nil and CampCommand.InRange(model,body.Position,2)
end

function WorldService:Build()
	self:Destroy()
	local old = workspace:FindFirstChild("PetRollWorld")
	if old then assert(old:GetAttribute("PetRollGenerated"), "PetRollWorld is not ours"); old:Destroy() end
	local root = AuthoredMap.Instantiate() or Instance.new("Folder")
	root.Name = "PetRollWorld"
	root:SetAttribute("PetRollGenerated", true)
	root:SetAttribute("BuildVersion", "ChickenKingdomMap20260917")
	-- AuthoredMap clones section contents; preserve the surface-binding revision on the runtime root.
	local source=game:GetService("ServerStorage"):FindFirstChild("MyChickenArmyMap")
	if source then root:SetAttribute("BuilderMapVersion",source:GetAttribute("BuilderMapVersion")) end
	root.Parent, self.root = workspace, root
	if not root:GetAttribute("AuthoredMap") then
		Builder.ApplyLighting()
		Builder.BuildIsland(root, Config.PlotPositions, Config.CampRadii, Config.Map)
	end
	self.kingArena = KingArena.new(root)
	self.kingArena:SnapshotIntroSet()
	local starterCamps=Progression.Camps(1)
	-- The standalone machine was authored against Plot 1. Keep it intact in
	-- ServerStorage during Play and clone that same placement into each home.
	local mergeTemplate=workspace:FindFirstChild("Fuse_Machine")
	local firstPlot=root:FindFirstChild("Plot1")
	if not mergeTemplate and firstPlot then mergeTemplate=firstPlot:FindFirstChild("Fuse_Machine",true) end
	if mergeTemplate and not mergeTemplate:IsA("Model") then mergeTemplate=nil end
	local mergeOrigin=self:PlotFrame(1)
	if Config.Features.Merging and mergeTemplate and mergeTemplate.Parent==workspace then
		mergeTemplate.Parent=game:GetService("ServerStorage")
	end
	Builder.BuildIslandChickenRamps(root)
	for index = 1, #Config.PlotPositions do
		-- Authored homes are opt-in: removing a plot for editing must not regenerate it.
		if not root:GetAttribute("AuthoredMap") or root:FindFirstChild("Plot"..index) then
			local cf = self:PlotFrame(index)
			local folder, title = Builder.BuildPlot(root, index, cf)
			Builder.BuildChickenRamps(folder)
			local pets = Instance.new("Folder")
			pets.Name, pets.Parent = "Pets", folder
			local displays=RollStation.DisplayAnchors(folder)
			local stations={}
			for slot=1,math.max(1,#displays) do
				stations[slot]=RollStation.new(folder,cf*HomePlot.Roll,index,function(player,action,plotIndex,offerId)
					if self.onAction then self.onAction(player,action,plotIndex,offerId) end
				end,slot,displays[slot])
			end
			local station=stations[1]
			local conquestTitle=if folder:GetAttribute("AuthoredPlot") then nil else Builder.Sign(folder,"ConquestSign",cf*CFrame.new(21,4.8,-26),
				#starterCamps.." CAMPS → CHICKEN KING",Builder.Palette.ink,15,3.5)
			local plot={folder=folder,pets=pets,title=title,station=station,stations=stations,actors={},roaming={},
				homeOrdinals={},index=index,connections={},conquestTitle=conquestTitle}
			plot.upgrades=PlotUpgradeService.new(folder,index,cf)
			if Config.Features.Merging then
				plot.mergeStand=MergeStand.new(folder,cf,index,function(player,action,plotIndex)
					if self.onAction then self.onAction(player,action,plotIndex) end
				end,mergeTemplate,mergeOrigin)
			else
				-- Runtime clones only; original buildings are archived in ServerStorage.
				-- Also suppress the stand when loading an older authored recovery template.
				local shops=folder:FindFirstChild("Shops")
				local building=shops and shops:FindFirstChild("Merge")
				if building then building:Destroy() end
				local anchor=folder:FindFirstChild("MergePrompt",true)
				if anchor then anchor:Destroy() end
			end
			self.plots[index]=plot
		end
		local lane = root:FindFirstChild("Lane" .. index) or Instance.new("Folder")
		lane.Name, lane.Parent = "Lane" .. index, root
		lane:SetAttribute("LaneOwnerIndex", index)
		self.lanes[index], self.campModels[index], self.campAppearance[index] = {}, {}, {}
		for campIndex, camp in starterCamps do
			local campFolder, campFrame = Builder.BuildCamp(lane, campIndex, camp, Config.CampHalfSize,
				false, self:CampFrame(campIndex, index), index)
			local defenders = Instance.new("Folder")
			defenders.Name, defenders.Parent = "Defenders", campFolder
			self.lanes[index][campIndex] = {folder = campFolder, defenders = defenders, frame = campFrame,
				actors = {}, busy = false, roster = nil}
			self.campModels[index][campIndex] = defenders
		end
	end
	local frontier=root:FindFirstChild("Outposts") or Instance.new("Folder")
 frontier.Name,frontier.Parent="Outposts",root
 for i,camp in Progression.Outposts() do
  local folder,frame=Builder.BuildCamp(frontier,math.min(i+1,5),camp,Config.CampHalfSize,false,self:OutpostFrame(i),nil,frontier:FindFirstChild("Outpost"..i))
  folder.Name="Outpost"..i
  folder:SetAttribute("CommandTarget","outpost:"..i)
  folder:SetAttribute("OutpostIndex",i)
  folder:SetAttribute("RequiredTier",camp.tier)
  local defenders=Instance.new("Folder");defenders.Name,defenders.Parent="Defenders",folder
  local record={folder=folder,frame=frame,defenders=defenders,actors={},busy=false,roster=Progression.OutpostRoster(i),promotion=camp.tier}
  self.outposts[i]=record
  Builder.ApplyCampPromotion(folder,camp.tier,i.." · "..camp.name)
  self:PopulateCamp(record)
 end
 if Config.IncomeOutpost and Config.IncomeOutpost.Enabled and not hillEnabled() then
  local definition=Config.IncomeOutpost
  local folder,frame,label=Builder.BuildIncomeOutpost(root,self:IncomeFrame(),definition)
  local defenders=Instance.new("Folder");defenders.Name,defenders.Parent="Defenders",folder
  self.incomeOutpost={folder=folder,frame=frame,label=label,defenders=defenders,
   actors={},busy=false,roster=definition.NeutralRoster,promotion=1}
  self:PopulateCamp(self.incomeOutpost)
 end
 self.lastRoamAt = os.clock()
end

function WorldService:CanUseMergeStand(player,session,index)
 local plot=self.plots[session.plotIndex]
 return Config.Features.Merging and plot~=nil and plot.mergeStand~=nil and index==session.plotIndex and plot.mergeStand:CanUse(player)
end

function WorldService:CelebrateMerge(session,petId)
 local plot=self.plots[session.plotIndex]
 local pet=session.pets[petId]
 if not plot or not plot.mergeStand or not pet or not session:IsPetHome(petId) then return end
 local actor=plot.actors[petId]
 if not actor then
  actor=PetActor.new(plot.pets,petId,pet.species,pet.stars,self:ReturnPosition(session,petId),self:PlotFrame(session.plotIndex).LookVector)
  if not self:RestoreActor(session,petId,actor) then return end
 end
 plot.mergeStand:Celebrate(pet,actor,function(released)
  if self.plots[session.plotIndex]~=plot or plot.actors[petId]~=released
   or not session.pets[petId] or not session:IsPetHome(petId) or session.closing then return end
  local home=plot.roaming[petId]
  if not home then return end
  home.position=released:Position()
  home.target,home.recoveryFoot=self:ReturnPosition(session,petId),released:Position()
  home.moving,home.recruiting,home.startedAt=true,true,os.clock()
  home.travelTimeout=math.max(14,(home.target-home.position).Magnitude/math.max(5,Config.RoamSpeed)+4)
  released.model:SetAttribute("Recruiting",true)
  released:MoveTo(home.target,math.max(5,Config.RoamSpeed))
 end)
end

function WorldService:PopulateCamp(record)
	disposeActors(record.actors)
	record.patrols = {}
	if record.busy or record.conquerorId or not record.roster then return end
	for ordinal, pet in record.roster do
		local x, z = FlockLayout.Offset(ordinal, #record.roster)
		local foot = (record.frame * CFrame.new(x, 0, z)).Position
		local actor = PetActor.new(record.defenders, "Guard" .. ordinal, pet.species, pet.stars or 1, foot, -record.frame.LookVector)
		PetView.Level(actor.model,pet.level or 1)
		actor.model:SetAttribute("CampGuard", record.folder:GetAttribute("Difficulty"))
		actor.model:SetAttribute("Promotion",record.promotion)
		actor.model:SetAttribute("LaneOwnerIndex", record.folder:GetAttribute("LaneOwnerIndex"))
		actor.model:SetAttribute("OwnerUserId", record.ownerId)
		actor:Stop()
		table.insert(record.actors, actor)
		table.insert(record.patrols, IdlePatrol.new(actor, self.random, Config.RoamSpeed, 0.5, 2))
	end
end

function WorldService:StepCampPatrol(record, now)
	if record.busy or record.conquerorId then return end
	local radius = record.folder:GetAttribute("PatrolRadius") or math.max(2, Config.CampHalfSize - 3)
	for _, patrol in record.patrols or {} do
		patrol:Step(now, function()
			return IdlePatrol.DiskTarget(record.frame, radius, record.patrols, patrol, self.random)
		end)
	end
end

-- Presentation is queued while an encounter owns this camp. Releasing one lane
-- never rebuilds any other player's guards or changes an active battle roster.
function WorldService:ApplyCampStage(record)
 if record.busy or not record.pendingStage then return false end
 local stage=record.pendingStage
 record.pendingStage=nil
 record.roster,record.rosterKey,record.ownerId=stage.roster,stage.key,stage.ownerId
 record.promotion=stage.promotion
 attribute(record.folder,"OwnerUserId",stage.ownerId)
 Builder.ApplyCampPromotion(record.folder,stage.promotion,stage.name)
 Builder.ApplyCampOwnership(record.folder,record.frame,record.conquerorId,record.conquerorName)
 self:PopulateCamp(record)
 return true
end

function WorldService:UpdateSession(session)
	local plot = self.plots[session.plotIndex]
	if not plot then return end
	plot.ownerId = session.userId
	plot.researchWalk=session.researchEffects.walk
	local rank=session.promotion or 1
	local promotion=Progression.Get(rank)
	local camps=Progression.Camps(rank)
	local completed=session:Completed()
	local earnedTrophy = session.kingCleared==true
	if earnedTrophy and not plot.trophy and not plot.folder:GetAttribute("AuthoredPlot") then
		plot.trophy = Builder.BuildConquestTrophy(plot.folder, self:PlotFrame(session.plotIndex) * CFrame.new(25, 0.3, 25))
	elseif not earnedTrophy and plot.trophy then
		plot.trophy:Destroy(); plot.trophy = nil
	end
	attribute(plot.folder, "ConquestCompleted", earnedTrophy)
	attribute(plot.folder,"Promotion",rank)
	plot.upgrades:SetLevel(session.plotSizeLevel)
	session.plotExpansionAvailable=plot.upgrades.available
	session.rollSlotLimit=math.min(#plot.stations,Config.RollSlotsUnlocked)
	session.rollSlotCount=math.min(session.rollSlotLimit,session.rollSlotsUnlocked)
	for _,station in plot.stations do station:Sync(session) end
	if plot.mergeStand then plot.mergeStand:Sync(session) end
	for name, value in {CommandTarget = "base:" .. session.userId, OwnerUserId = session.userId,
		ArmyState = session.armyState} do attribute(plot.folder, name, value) end
	local bannerTier=OperationRewards.Apply(session,plot,self:PlotFrame(session.plotIndex))
	local title = session.name .. "'S ARMY"..(if bannerTier==3 then "\nROYAL COMMANDER" else "")
	if plot.title.Text ~= title then plot.title.Text = title end
	local won=0
	for index in camps do if session.firstWins[index] then won+=1 end end
 if plot.conquestTitle then plot.conquestTitle.Text=if earnedTrophy then "CHICKEN CROWN" else won.."/"..#camps.." CAMPS → KING" end

	for index, camp in camps do
		local record = self.lanes[session.plotIndex][index]
  local roster=Progression.Roster(rank,index)
  local entries={camp.name}
  for _,pet in roster do table.insert(entries,pet.species..":"..tostring(pet.level)) end
		local key = table.concat(entries, ",")
		if record.rosterKey ~= key or record.ownerId ~= session.userId then
   record.pendingStage={roster=roster,key=key,ownerId=session.userId,promotion=index,name=camp.name}
   self:ApplyCampStage(record)
		end
	end
	local desired, visibleCount = {}, 0
	local homePets = session:HomePets()
	local best = {}
	for _, id in session:BestPetIds() do best[id] = true end
	-- Retain current home actors first; new snapshots never reshuffle their destinations.
	table.sort(homePets, function(a, b)
		if best[a.id] ~= best[b.id] then return best[a.id] == true end
		if (plot.actors[a.id] ~= nil) ~= (plot.actors[b.id] ~= nil) then return plot.actors[a.id] ~= nil end
		return a.id < b.id
	end)
	for ordinal, pet in homePets do
		if ordinal > MAX_VISIBLE then break end
		desired[pet.id] = true
	end
	for id, actor in plot.actors do
		if not desired[id] then actor:Destroy(); plot.actors[id], plot.roaming[id] = nil, nil end
	end
	for ordinal, pet in homePets do
		if ordinal > MAX_VISIBLE then break end
		visibleCount += 1
		local actor = plot.actors[pet.id]
		if actor and plot.mergeStand and plot.mergeStand:IsRevealing(pet.id) then continue end
		if actor and actor.model:GetAttribute("Species") ~= pet.species then actor:Destroy(); plot.actors[pet.id] = nil; actor = nil end
		if not actor then
			local position = self:ReturnPosition(session, pet.id, ordinal)
			actor = PetActor.new(plot.pets, pet.id, pet.species, pet.stars, position, self:PlotFrame(session.plotIndex).LookVector)
			if not self:RestoreActor(session, pet.id, actor) then visibleCount -= 1; continue end
		end
		for name, value in {PetId = pet.id, OwnerId = session.userId, OwnerUserId = session.userId, AtHome = true,
			InArmy = best[pet.id] == true} do attribute(actor.model, name, value) end
		PetView.Level(actor.model, pet.level or 1, pet.giantSize)
		actor.model:SetAttribute("DeploymentSlot", nil)
		actor.model:SetAttribute("StoredCash", nil)
		if PetView.Cash then PetView.Cash(actor.model, 0, false) end
	end
	for id, actor in plot.actors do
		if not desired[id] then actor:Destroy(); plot.actors[id], plot.roaming[id] = nil, nil end
	end
	for id in plot.homeOrdinals do if not session.pets[id] then plot.homeOrdinals[id] = nil end end
	attribute(plot.folder, "HomeCount", visibleCount)
	attribute(plot.folder, "HiddenHomeCount", math.max(0, #homePets - visibleCount))
	self.revisions[session.userId] = session.revision
end

function WorldService:Step(now)
	if self.kingArena then self.kingArena:Step(now) end
	for _,plot in self.plots do for _,station in plot.stations do station:Step(now) end end
	if now - self.lastRoamAt < Config.RoamStep then return end
	self.lastRoamAt = now
	local viewers = {}
	for _, player in Players:GetPlayers() do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then table.insert(viewers, root.Position) end
	end
	for _, plot in self.plots do
		if plot.ownerId and plot.ownerId>0 then self:UpdatePlayerSpeed(Players:GetPlayerByUserId(plot.ownerId),plot.index) end
		local near, active = false, 0
		for _, at in viewers do if (at - self:Position(plot.index)).Magnitude < 115 then near = true; break end end
		for _, home in plot.roaming do if home.moving then active += 1 end end
		for id, home in plot.roaming do
			local actor = plot.actors[id]
			if not actor then plot.roaming[id] = nil; continue end
			if plot.mergeStand and plot.mergeStand:IsRevealing(id) then continue end
			local state = actor:Step(now)
			home.position = actor:Position()
			if home.moving then
				local delta = home.target - home.position
				local arrived = Vector2.new(delta.X, delta.Z).Magnitude < 1.3 or state == "arrived"
				local timeout = home.travelTimeout or 14
				-- A path around scenery takes longer than the straight-line estimate.
				-- Allow real progress, while retaining a hard cap on endless detours.
				local elapsed = now - home.startedAt
				local timedOut = (elapsed > timeout and now - actor.progressAt > 4)
					or elapsed > math.max(45, timeout * 3)
				if arrived or state == "blocked" or timedOut or (not near and not home.recruiting) then
					-- Failed home walks must not leave a bought/idle bird lodged forever.
					if not arrived and (state == "blocked" or timedOut) then
						actor:Recover(home.recoveryFoot, if timedOut then "Home walk timed out" else "Home route blocked", now)
						home.position = actor:Position()
					end
					actor:Stop(); home.moving, home.recruiting = false, false
					actor.model:SetAttribute("Recruiting", false)
					home.pauseUntil = now + self.random:NextNumber(2, 6)
					active -= 1
				end
			elseif near and now >= home.pauseUntil and active < MAX_WANDERING then
				home.target = self:RoamTarget(plot.index, home.position, id)
				home.travelTimeout = math.max(14, (home.target - home.position).Magnitude / Config.RoamSpeed + 4)
				home.startedAt, home.moving = now, true
				active += 1
				actor:MoveTo(home.target, Config.RoamSpeed)
			end
		end
	end
	for _, lane in self.lanes do for _, record in lane do self:StepCampPatrol(record, now) end end
	for _, record in self.outposts do self:StepCampPatrol(record, now) end
	if self.incomeOutpost then self:StepCampPatrol(self.incomeOutpost, now) end
end

function WorldService:SetTerritoryOwner(location,userId,name)
 if location.king or (location.income and hillEnabled()) then
  if self.kingArena then self.kingArena:SetOwner(userId,name) end
  return
 end
 local record=if location.income then self.incomeOutpost elseif location.outpost then self.outposts[location.outpost]
  else self.lanes[location.plot] and self.lanes[location.plot][location.index]
 if not record then return end
 record.conquerorId,record.conquerorName=userId,name
 Builder.ApplyCampOwnership(record.folder,record.frame,userId,name)
 self:PopulateCamp(record)
end

-- Transfer the patrolling rigs before SetBusy clears the idle presentation.
-- Roster order matches PopulateCamp; the encounter adopts their live positions.
function WorldService:TakeTerritoryDefenders(location)
 if location.king then return if self.kingArena then self.kingArena:TakeDefenders() else {} end
 local record=if location.outpost then self.outposts[location.outpost]
  else self.lanes[location.plot] and self.lanes[location.plot][location.index]
 if not record or record.busy or record.conquerorId then return {} end
 local actors=record.actors
 record.actors,record.patrols={},{}
 for _,actor in actors do actor:Stop() end
 return actors
end

function WorldService:SetIncomeBusy(busy)
 if hillEnabled() then
  if self.kingArena and self.kingArena.busy~=busy then self.kingArena:SetBusy(busy) end
  return
 end
 local record=self.incomeOutpost
 if not record or record.busy==busy then return end
 record.busy=busy;attribute(record.folder,"Occupied",busy)
 self:PopulateCamp(record)
end

function WorldService:SetIncomeStatus(summary)
 local record=self.incomeOutpost
 if not record or not summary then return end
 local text
 if summary.contested then text="Income paused · contested"
 elseif summary.npcWarningEndsAt then
  text="Raid in "..math.max(0,math.ceil(summary.npcWarningEndsAt-workspace:GetServerTimeNow())).."s · +$"..summary.effectiveRate.."/s"
 elseif summary.ownerId then text="+$"..summary.effectiveRate.."/s · owned"
 else text="Capture · +$"..summary.configuredRate.."/s" end
 if record.label.Text~=text then record.label.Text=text end
 attribute(record.folder,"TerritoryRate",summary.effectiveRate)
 attribute(record.folder,"Contested",summary.contested==true)
 attribute(record.folder,"GraceEndsAt",summary.graceEndsAt)
 attribute(record.folder,"NpcWarningEndsAt",summary.npcWarningEndsAt)
end

function WorldService:SetOutpostBusy(index,busy)
 local record=self.outposts[index]
 if not record or record.busy==busy then return end
 record.busy=busy;attribute(record.folder,"Occupied",busy)
 Builder.ApplyCampTitle(record.folder)
 self:PopulateCamp(record)
end

function WorldService:SetCampBusy(index: number, busy: boolean, plotIndex: number)
	local record = self.lanes[plotIndex] and self.lanes[plotIndex][index]
	if not record or record.busy == busy then return end
	record.busy = busy
	attribute(record.folder, "Occupied", busy)
	Builder.ApplyCampTitle(record.folder)
	if not self:ApplyCampStage(record) then self:PopulateCamp(record) end
end

function WorldService:Release(session)
	local plot = self.plots[session.plotIndex]
	if plot then
		disposeActors(plot.actors)
		OperationRewards.Clear(plot)
		plot.researchWalk=0
		plot.roaming, plot.homeOrdinals, plot.ownerId = {}, {}, nil
		plot.upgrades:SetLevel(0)
		for _,station in plot.stations do station:Clear() end
		if plot.mergeStand then plot.mergeStand:Clear() end
		if plot.trophy then plot.trophy:Destroy(); plot.trophy = nil end
		attribute(plot.folder, "ConquestCompleted", nil)
		plot.title.Text = "HOME " .. session.plotIndex .. " · OPEN"
		if plot.conquestTitle then plot.conquestTitle.Text = #Progression.Camps(1).." CAMPS → CHICKEN KING" end
		for _, name in {"CommandTarget", "OwnerUserId", "ArmyState", "HomeCount", "HiddenHomeCount", "Promotion"} do plot.folder:SetAttribute(name, nil) end
		for index, record in self.lanes[session.plotIndex] do
			disposeActors(record.actors)
			record.patrols = {}
			record.roster, record.rosterKey, record.ownerId, record.busy = nil, nil, nil, false
			record.pendingStage,record.promotion=nil,nil
			record.conquerorId,record.conquerorName=nil,nil
			Builder.ApplyCampOwnership(record.folder,record.frame,nil,nil)
			Builder.ApplyCampPromotion(record.folder,index,Progression.Camps(1)[index].name)
			attribute(record.folder, "Occupied", false)
			Builder.ApplyCampTitle(record.folder)
			attribute(record.folder, "OwnerUserId", nil)
		end
	end
	self.revisions[session.userId] = nil
end

function WorldService:Destroy()
	if self.kingArena then self.kingArena:Destroy(); self.kingArena = nil end
	for _, plot in self.plots do
		disposeActors(plot.actors)
		plot.upgrades:Destroy()
		for _,station in plot.stations do station:Destroy() end
		if plot.mergeStand then plot.mergeStand:Destroy() end
		for _, connection in plot.connections do connection:Disconnect() end
	end
	for _, lane in self.lanes do for _, record in lane do disposeActors(record.actors) end end
	for _,record in self.outposts do disposeActors(record.actors) end
 if self.incomeOutpost then disposeActors(self.incomeOutpost.actors);self.incomeOutpost=nil end
 self.outposts={}
 self.plots, self.lanes, self.campModels, self.campAppearance, self.revisions = {}, {}, {}, {}, {}
	if self.root then self.root:Destroy(); self.root = nil end
end

return WorldService
