--!strict
-- October 14 Missions (docs/team/MISSIONS_PLAN.md): the client side of waiting
-- mission sites. A small HUD list (tap an entry to send the Army), a marker over
-- each of this commander's sites and "landed / left" notices. Presentation only:
-- the server (OperationService) owns spawning, expiry and every start request.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Operations=require(Shared.OperationCatalog)
local Guide=require(Shared.TutorialGuide)
local Theme=require(script.Parent.UITheme)
local Tracker={}
Tracker.__index=Tracker

local WHITE=Color3.new(1,1,1)
local MUTED=Color3.fromRGB(200,214,210)
local GOLD=Color3.fromRGB(255,204,64)
local RED=Color3.fromRGB(255,96,80)
local GREEN=Color3.fromRGB(120,240,100)
local CARD=Color3.fromRGB(22,28,32)
local MAX_ROWS=2

local function clock(seconds: number): string
	seconds=math.max(0,math.floor(seconds))
	return string.format("%d:%02d",seconds//60,seconds%60)
end

local function verdictColor(verdict: string): Color3
	return if verdict=="Very tough" then RED elseif verdict=="Close fight" then GOLD else GREEN
end

local function label(parent,name,text,x,y,w,h,color,align)
	local item=Theme.Label(parent,name,text,20,color or WHITE)
	item.Position,item.Size=UDim2.fromScale(x,y),UDim2.fromScale(w,h)
	item.TextScaled,item.TextXAlignment=true,align or Enum.TextXAlignment.Left
	return item
end

function Tracker.new(app)
	local self=setmetatable({app=app,deadlines={},known=nil,rows={},markers={},connections={}},Tracker)
	-- Takes the old Invasions icon slot on the right edge.
	local root=Theme.Container(app.hudLayer,"MissionTracker")
	root.AnchorPoint,root.Position,root.Size=Vector2.new(1,.5),UDim2.fromScale(.988,.56),UDim2.fromScale(.21,.17)
	root.Visible=false
	self.root=root
	local list=Instance.new("UIListLayout")
	list.FillDirection,list.SortOrder,list.Padding=Enum.FillDirection.Vertical,Enum.SortOrder.LayoutOrder,UDim.new(.06,0)
	list.Parent=root
	for index=1,MAX_ROWS do
		local row=Theme.Frame(root,"Mission"..index,UDim2.fromScale(1,.47),CARD)
		row.LayoutOrder=index
		row:SetAttribute("OwnsPopupStyle",true)
		local stroke=Theme.Stroke(row,WHITE,3)
		local name=label(row,"Name","",.05,.06,.6,.5,WHITE)
		local reward=label(row,"Reward","",.62,.06,.34,.5,GOLD,Enum.TextXAlignment.Right)
		local status=label(row,"Status","",.05,.56,.9,.38,MUTED)
		local hit=Instance.new("TextButton")
		hit.Name,hit.Text,hit.BackgroundTransparency,hit.Size,hit.ZIndex="Send","",1,UDim2.fromScale(1,1),20
		hit.Parent=row
		hit.Activated:Connect(function() self:Send(index) end)
		Theme.ScaleText(row)
		self.rows[index]={frame=row,stroke=stroke,name=name,reward=reward,status=status}
	end
	local elapsed=0
	table.insert(self.connections,RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt
		if elapsed<.5 then return end
		elapsed=0
		self:Update()
	end))
	return self
end

-- Seconds until a waiting site leaves (nil when unknown).
function Tracker:Remaining(id: string): number?
	local deadline=self.deadlines[id]
	return if deadline then math.max(0,math.ceil(deadline-os.clock())) else nil
end

function Tracker:Missions()
	local ops=self.app.state and self.app.state.operations
	return ops and ops.missions or {}
end

function Tracker:Send(index: number)
	local mission=self:Missions()[index]
	if not mission then return end
	local app=self.app
	app.audio:Play("Click")
	app:Request("StartOperation",{missionId=mission.id})
end

function Tracker:Render(state)
	local ops=state and state.operations
	local missions=ops and ops.missions or {}
	local now=os.clock()
	local present={}
	for _,mission in missions do
		present[mission.id]=mission
		-- Re-sync only on a real drift, so the countdown never jitters between packets.
		local deadline=now+mission.expiresIn
		local old=self.deadlines[mission.id]
		if not old or math.abs(old-deadline)>2 then self.deadlines[mission.id]=deadline end
	end
	-- Notices: a new site landed, or a site left without being attacked.
	if self.known then
		for _,mission in missions do
			if not self.known[mission.id] then
				self.app:Notify((if mission.rare then "Gold mission! " else "Loyalists landed: ")..mission.name
					.." · "..clock(mission.expiresIn).." to conquer it","info")
			end
		end
		for id,old in self.known do
			if not present[id] and (ops and ops.activeSite)~=id then
				self.app:Notify(old.name.." packed up and left.","info")
			end
		end
	end
	self.known=present
	for id in self.deadlines do if not present[id] then self.deadlines[id]=nil end end
	self:Update()
end

-- Rows, markers and countdowns (every half second and on each state packet).
function Tracker:Update()
	local app=self.app
	local state=app.state
	local missions=self:Missions()
	local home=state~=nil and (state.armyState=="Home" or state.armyState=="Following")
	self.root.Visible=#missions>0 and home and not app.panel.Visible and not app.dialogueActive
		and not (app.research and app.research.root.Visible)
	for index,row in self.rows do
		local mission=missions[index]
		row.frame.Visible=mission~=nil
		if not mission then continue end
		local tierColor=Operations.Colors[mission.tier] or WHITE
		row.stroke.Color=if mission.rare then GOLD else tierColor
		row.name.Text=mission.name
		row.name.TextColor3=if mission.rare then GOLD else WHITE
		row.reward.Text="$"..Theme.CompactMoney(mission.reward)
		local verdict=Guide.Difficulty(state.power,mission.power)
		row.status.Text=clock(self:Remaining(mission.id) or mission.expiresIn).." · "..verdict
		row.status.TextColor3=verdictColor(verdict)
	end
	self:UpdateMarkers(missions)
end

-- A marker over each of this commander's waiting sites: name, time left, reward.
function Tracker:UpdateMarkers(missions)
	local world=workspace:FindFirstChild("PetRollWorld")
	local folder=world and world:FindFirstChild("Missions")
	local wanted={}
	for _,mission in missions do
		local site=folder and folder:FindFirstChild("Mission_"..mission.id)
		local anchor=site and site:FindFirstChild("CommandCenter")
		if not anchor or site:GetAttribute("OwnerUserId")~=Players.LocalPlayer.UserId then continue end
		wanted[mission.id]=true
		local marker=self.markers[mission.id]
		if not marker or not marker.gui.Parent then
			local gui=Instance.new("BillboardGui")
			gui.Name,gui.Size,gui.StudsOffset="MissionMarker",UDim2.fromScale(26,8),Vector3.new(0,14,0)
			gui.AlwaysOnTop,gui.MaxDistance,gui.LightInfluence=true,900,0
			gui.Adornee,gui.Parent=anchor,anchor
			local title=label(gui,"Name",mission.name,0,0,1,.55,if mission.rare then GOLD else WHITE,Enum.TextXAlignment.Center)
			title.TextColor3=if mission.rare then GOLD else (Operations.Colors[mission.tier] or WHITE):Lerp(WHITE,.35)
			local info=label(gui,"Info","",0,.55,1,.45,WHITE,Enum.TextXAlignment.Center)
			marker={gui=gui,info=info}
			self.markers[mission.id]=marker
		end
		marker.info.Text=clock(self:Remaining(mission.id) or mission.expiresIn).."  ·  $"..Theme.CompactMoney(mission.reward)
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
	self.root:Destroy()
end

return Tracker
