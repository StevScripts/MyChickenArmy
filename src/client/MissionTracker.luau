--!strict
-- October 14 random sites (docs/team/MISSIONS_PLAN.md, owner's latest direction):
-- no mission list. Sites just appear around the island; this module only labels
-- each one in the world (name, "Leaves in m:ss" or "Locked") and keeps the local
-- countdowns that BaseController's objective marker reads. Presentation only: the
-- server (OperationService) owns spawning, expiry and every start request; the
-- walk-up Send Army prompt at a site sends the Army.
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Operations=require(Shared.OperationCatalog)
local Theme=require(script.Parent.UITheme)
local Tracker={}
Tracker.__index=Tracker

local WHITE=Color3.new(1,1,1)
local GOLD=Color3.fromRGB(255,204,64)
local MUTED=Color3.fromRGB(200,214,210)

local function clock(seconds: number): string
	seconds=math.max(0,math.floor(seconds))
	return string.format("%d:%02d",seconds//60,seconds%60)
end

local function label(parent,name,text,y,h,color)
	local item=Theme.Label(parent,name,text,20,color or WHITE)
	item.Position,item.Size=UDim2.fromScale(0,y),UDim2.fromScale(1,h)
	item.TextScaled,item.TextXAlignment=true,Enum.TextXAlignment.Center
	return item
end

function Tracker.new(app)
	local self=setmetatable({app=app,deadlines={},markers={},connections={},guideId=nil},Tracker)
	local elapsed=0
	table.insert(self.connections,RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt
		if elapsed<.5 then return end
		elapsed=0
		self:UpdateMarkers()
	end))
	return self
end

-- Seconds until a site leaves (nil when unknown).
function Tracker:Remaining(id: string): number?
	local deadline=self.deadlines[id]
	return if deadline then math.max(0,math.ceil(deadline-os.clock())) else nil
end

function Tracker:Missions()
	local ops=self.app.state and self.app.state.operations
	return ops and ops.missions or {}
end

function Tracker:Render(state)
	local ops=state and state.operations
	local now=os.clock()
	local present={}
	for _,mission in ops and ops.missions or {} do
		present[mission.id]=true
		-- Re-sync only on a real drift, so the countdown never jitters between packets.
		local deadline=now+mission.expiresIn
		local old=self.deadlines[mission.id]
		if not old or math.abs(old-deadline)>2 then self.deadlines[mission.id]=deadline end
	end
	for id in self.deadlines do if not present[id] then self.deadlines[id]=nil end end
	self:UpdateMarkers()
end

-- A small label over each site: its name (tier colour, gold for gold sites) and
-- "Leaves in m:ss", or "Locked" when this player's tier is too low.
function Tracker:UpdateMarkers()
	local world=workspace:FindFirstChild("PetRollWorld")
	local folder=world and world:FindFirstChild("Missions")
	local wanted={}
	for _,mission in self:Missions() do
		local site=folder and folder:FindFirstChild("Mission_"..mission.id)
		local anchor=site and site:FindFirstChild("CommandCenter")
		if not anchor then continue end
		wanted[mission.id]=true
		local marker=self.markers[mission.id]
		if not marker or not marker.gui.Parent then
			local gui=Instance.new("BillboardGui")
			gui.Name,gui.Size,gui.StudsOffset="SiteMarker",UDim2.fromScale(20,5),Vector3.new(0,12,0)
			-- Not AlwaysOnTop: like the game's other world labels (it did not render on top in Studio).
			gui.AlwaysOnTop,gui.MaxDistance,gui.LightInfluence=false,700,0
			gui.Adornee,gui.Parent=anchor,anchor
			local tint=if mission.rare then GOLD else (Operations.Colors[mission.tier] or WHITE):Lerp(WHITE,.35)
			marker={gui=gui,name=label(gui,"Name",mission.name,0,.6,tint),info=label(gui,"Info","",.6,.4,WHITE)}
			self.markers[mission.id]=marker
		end
		-- October 15: a held site stays while its holder's Army is stationed there.
		local remaining=self:Remaining(mission.id) or mission.expiresIn
		marker.info.Text=if mission.yours then (if mission.busy then "Your Army is defending!" else "Held by your Army")
			elseif mission.holder then "Held by "..mission.holder..(if mission.busy then " · under attack" else "")
			elseif mission.busy then "Battle in progress"
			elseif mission.locked then "Locked · "..(Operations.Tiers[mission.tier] or "").." tier"
			elseif remaining<=0 then "Leaving soon"
			else "Leaves in "..clock(remaining)
		marker.info.TextColor3=if mission.yours then GOLD elseif mission.locked then MUTED else WHITE
	end
	for id,marker in self.markers do
		if not wanted[id] then marker.gui:Destroy();self.markers[id]=nil end
	end
end

function Tracker:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	for _,marker in self.markers do marker.gui:Destroy() end
	table.clear(self.markers)
end

return Tracker
