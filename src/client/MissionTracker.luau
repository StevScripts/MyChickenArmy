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
local Motion: any=Theme.Motion -- untyped helpers; the alias keeps strict inference out of presentation calls
local Tracker={}
Tracker.__index=Tracker

local WHITE=Color3.new(1,1,1)
local GOLD=Color3.fromRGB(255,204,64)
local MUTED=Color3.fromRGB(200,214,210)
local RED=Color3.fromRGB(255,65,65)

local function clock(seconds: number): string
	seconds=math.max(0,math.floor(seconds))
	return string.format("%d:%02d",seconds//60,seconds%60)
end

local function label(parent,name,text,y,h,color)
	local item=Theme.Label(parent,name,text,20,color or WHITE)
	-- Centre-anchored (same row) so the arrival pop grows from the middle.
	item.AnchorPoint,item.Position,item.Size=Vector2.new(.5,.5),UDim2.fromScale(.5,y+h/2),UDim2.fromScale(1,h)
	item.TextScaled,item.TextXAlignment=true,Enum.TextXAlignment.Center
	return item
end

function Tracker.new(app)
	-- announced: sites that already played their arrival cue; lastResultId/lastCenter:
	-- the player's last Mission result and the site it was fought at (for the Coins float).
	local self=setmetatable({app=app,deadlines={},markers={},connections={},guideId=nil,announced={}::{[string]:boolean},lastResultId=nil::any,lastCenter=nil::Vector3?},Tracker)
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
	for id in self.announced do if not present[id] then self.announced[id]=nil end end
	-- October 21 game feel: the player's own Mission result (won/lost/left) answers once.
	if ops and ops.center then self.lastCenter=Vector3.new(ops.center.x,ops.center.y,ops.center.z) end
	local result=ops and ops.result
	local resultId=if result then result.id else nil
	if self.lastResultId==nil then self.lastResultId=resultId or false
	elseif resultId and resultId~=self.lastResultId then self.lastResultId=resultId;self:Resulted(result) end
	self:UpdateMarkers()
end

-- Where "+N Coins" floats: over the fought site while it is on screen, else near the top.
function Tracker:MarkerPoint(gui)
	local camera=workspace.CurrentCamera
	local center: Vector3?=self.lastCenter
	if camera and center then
		local point,onScreen=camera:WorldToViewportPoint(center+Vector3.new(0,10,0))
		if onScreen and point.Z>0 then return Motion:Point(gui,Vector2.new(point.X,point.Y)) end
	end
	return UDim2.fromScale(.5,.24)
end

-- Win: MissionWin (Fanfare when unauthored; Victory already plays under the camp
-- burst), confetti, a gold celebrate and the reward floating up. Loss or an early
-- leave: MissionLose (Error, soft) under a short red flash. HUD cues, any distance.
function Tracker:Resulted(result)
	local audio,feel,gui=self.app.audio,self.app.screenFeel,self.app.gui
	if result.won then
		local cue=if audio:Has("MissionWin") then "MissionWin" elseif audio:Has("Fanfare") then "Fanfare" else nil
		if cue then audio:Play(cue,1,{noFallback=true,voiceKey="MissionResult",cooldown=1}) end
		if feel then feel:Celebrate(GOLD,2) end
		if not gui then return end
		Motion:Confetti(gui,{origin=UDim2.fromScale(.5,.12)})
		local reward=tonumber(result.reward) or 0
		if reward>0 then Motion:Float(gui,"+"..Theme.CompactCoins(reward),self:MarkerPoint(gui),{color=GOLD,size=34,seconds=1.5,rise=.1,limit=4,font=Theme.Font}) end
	else
		local soft=not audio:Has("MissionLose")
		audio:Play(if soft then "Error" else "MissionLose",1,{noFallback=true,voiceKey="MissionResult",cooldown=1,volume=if soft then .4 else nil})
		if feel then feel:Flash(RED,.12,.3) end
	end
end

-- A site just appeared for this player: MissionAppear once (HUD) and, when the
-- player is close, a small celebrate in the site's tier colour.
function Tracker:Appeared(mission: any,anchor: any,tint: Color3)
	local tracker: any=self
	if tracker.announced[mission.id] then return end
	tracker.announced[mission.id]=true
	local audio=tracker.app.audio
	audio:Play(if audio:Has("MissionAppear") then "MissionAppear" else "Pop",1,{noFallback=true,voiceKey="MissionAppear",cooldown=1})
	local feel=tracker.app.worldFeel
	if feel and feel:Near(anchor.Position,120) then feel:Celebrate(anchor.Position,tint,1) end
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
			Motion:PopScale(marker.name,.6,.3);Motion:PopScale(marker.info,.6,.3)
			-- The name bobs while the site is live (StopBob when it leaves; still under reduced motion).
			Motion:Bob(marker.name,.04,.7)
			self:Appeared(mission,anchor,tint)
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
		-- A leaving site makes no sound: its label just settles and goes.
		if not wanted[id] then Motion:StopBob(marker.name);marker.gui:Destroy();self.markers[id]=nil end
	end
end

function Tracker:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	for _,marker in self.markers do Motion:StopBob(marker.name);marker.gui:Destroy() end
	table.clear(self.markers)
end

return Tracker
