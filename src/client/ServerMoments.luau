--!strict
-- October 27 (WS7, docs/team/SOCIAL_MOMENTS.md): other players' moments in this server.
-- Every moment the server sends (ServerMoment remote, never the player's own) becomes a
-- system chat line; Epic+ finds, the King and Rebirth 5+ also get the top-centre toast
-- (at most one every Social.Moments.ToastGapSeconds) and a far beacon over that plot
-- (WorldFeel:Beacon, WS6; skipped while it is missing). Epic+ finds and the King carry a
-- Visit button inside the same toast. During the viewer's own tutorial nothing shows
-- (Oct 25 rule: only the guide card); the moment is counted as moment.missed.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TextChatService=game:GetService("TextChatService")
local Shared=ReplicatedStorage:WaitForChild("PetRoll"):WaitForChild("Shared")
local Config=require(Shared:WaitForChild("Config"))
local SocialMoments=require(Shared:WaitForChild("SocialMoments"))
local Theme=require(script.Parent.UITheme)
local AnalyticsClient=require(script.Parent.AnalyticsClient)
local ServerMoments={}
ServerMoments.__index=ServerMoments
-- Trailing no-break spaces keep the toast's text clear of the Visit button: the banner
-- centres its text in the strip, so the button sits at the strip's right end without a
-- layout change (no-break, so text measuring never trims them).
local VISIT_ROOM=string.rep("\u{A0}",14)

local function escape(text: string): string
	return (text:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"))
end

function ServerMoments.new(app: any)
	local self=setmetatable({app=app,connections={},lastToastAt=nil,visit=nil,destroyed=false} :: any,ServerMoments)
	task.spawn(function()
		local remotes=app.remotes or ReplicatedStorage.PetRoll:WaitForChild("Remotes")
		local remote=remotes:WaitForChild("ServerMoment",30)
		if not remote or self.destroyed then return end
		table.insert(self.connections,remote.OnClientEvent:Connect(function(payload) self:Receive(payload) end))
	end)
	return self
end

-- The viewer's tutorial is over: WS5's app:TutorialComplete when present, else the
-- signal behind Hud:SetTutorialStage (a stage means the tutorial is on) and the saved facts.
function ServerMoments:TutorialDone(): boolean
	local app=self.app
	if type(app.TutorialComplete)=="function" then return app:TutorialComplete()==true end
	if app.hud and app.hud.tutorialStage~=nil then return false end
	local state=app.state
	return type(state)=="table" and SocialMoments.TutorialDone(state.tutorial)
end

function ServerMoments:Receive(payload: any)
	if self.destroyed or type(payload)~="table" or type(payload.kind)~="string" then return end
	local player=Players.LocalPlayer
	if player and payload.userId==player.UserId then return end
	local shown=SocialMoments.Classify(payload.kind,payload)
	if not shown then return end
	if not self:TutorialDone() then AnalyticsClient.Track("moment.missed",payload.kind);return end
	local text=SocialMoments.Text(payload.kind,payload)
	local color=SocialMoments.Color(payload.kind,payload)
	if shown.chat then self:Chat(text,color) end
	local now=os.clock()
	if (shown.toast or shown.beacon) and SocialMoments.ToastOpen(self.lastToastAt,now) then
		self.lastToastAt=now
		if shown.toast then self:Toast(text,payload,shown.visit) end
		if shown.beacon then self:Beacon(payload,color) end
	end
	AnalyticsClient.Track("moment.seen",payload.kind)
end

-- A system line in the chat window (our own text: no filtering needed), in the moment's colour.
function ServerMoments:Chat(text: string,color: Color3)
	pcall(function()
		local channels=TextChatService:FindFirstChild("TextChannels")
		local system=channels and channels:FindFirstChild("RBXSystem")
		if system and system:IsA("TextChannel") then
			system:DisplaySystemMessage(string.format('<font color="#%s">%s</font>',color:ToHex(),escape(text)))
		end
	end)
end

function ServerMoments:ClearVisit()
	local visit: any=self.visit
	if not visit then return end
	self.visit=nil
	for _,connection in visit.connections do connection:Disconnect() end
	if visit.button then visit.button:Destroy() end
end

-- The existing notice banner (app:Notify, "event" style); a Visit button rides inside it
-- while it shows this moment. No new HUD element; Scale only.
function ServerMoments:Toast(text: string,payload: any,visit: boolean)
	local app=self.app
	local rule=(Config :: any).Social and (Config :: any).Social.Visit or {}
	local withVisit=visit and rule.Enabled==true and type(payload.plotIndex)=="number"
	local shown=if withVisit then text..VISIT_ROOM else text
	app:Notify(shown,"event")
	self:ClearVisit()
	local frame: any,label: any=app.toastFrame,app.toast
	if not withVisit or not frame or not label then return end
	local plotIndex=payload.plotIndex
	local button=Theme.ActionButton(frame,"Visit","Visit",function()
		if app.audio then app.audio:Play("Click") end
		self:ClearVisit()
		app:Request("VisitPlot",{plotIndex=plotIndex})
	end,Theme.ReferenceColors.Base)
	button.AnchorPoint,button.Size=Vector2.new(1,0.5),UDim2.fromScale(0.13,0.62)
	button.ZIndex=frame.ZIndex+5
	Theme.Aspect(button,2.4)
	local record={button=button,connections={}}
	self.visit=record
	-- At the strip's right end; the strip is centred, so its half width from the middle.
	local function place()
		local row: any=frame:FindFirstChild("Row")
		local width=math.max(1,frame.AbsoluteSize.X)
		local half=if row and row:IsA("GuiObject") then row.AbsoluteSize.X/width/2 else 0.4
		button.Position=UDim2.fromScale(math.clamp(0.5+half-0.01,0.6,0.99),0.5)
	end
	local row: any=frame:FindFirstChild("Row")
	if row and row:IsA("GuiObject") then
		table.insert(record.connections,row:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))
	end
	table.insert(record.connections,frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(place))
	-- Another notice takes the banner: the button leaves with this moment.
	table.insert(record.connections,label:GetAttributeChangedSignal("PlainText"):Connect(function()
		local current=label:GetAttribute("PlainText")
		if type(current)~="string" or string.sub(current,1,#shown)~=shown then
			if self.visit==record then self:ClearVisit() end
		end
	end))
	Theme.ScaleText(button)
	place()
end

-- A far light beam over the actor's plot (client-local at Config.PlotPositions, so
-- streaming never hides it). WS6 owns WorldFeel:Beacon and its RareFind cue.
function ServerMoments:Beacon(payload: any,color: Color3)
	local feel=self.app.worldFeel
	if not feel or type(feel.Beacon)~="function" then return end
	local spot=Config.PlotPositions[tonumber(payload.plotIndex) or 0]
	if not spot then return end
	local player=Players.LocalPlayer
	local root=player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local y=if root and root:IsA("BasePart") then root.Position.Y-3 else 0
	pcall(feel.Beacon,feel,Vector3.new(spot[1],y,spot[2]),color,SocialMoments.Settings().beaconSeconds)
end

function ServerMoments:Destroy()
	self.destroyed=true
	self:ClearVisit()
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
end

return ServerMoments
