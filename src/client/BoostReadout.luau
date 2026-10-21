--!strict
-- October 20 boosts readout (S16, docs/team/PLAYTIME_REWARDS.md): the reference's coin
-- "x9.2" and clover "x4.5" under the top-right buttons, showing the player's total
-- Coins and Luck multipliers. The server computes both (state.boosts,
-- PlaytimeService.Boosts); this module only presents. Stevin, October 20, approved one
-- addition to the reference: while a Playtime Rewards boost runs, its number turns
-- green with the time left underneath.
local RunService=game:GetService("RunService")
local Theme=require(script.Parent.UITheme)
local PlaytimeRewards=require(game:GetService("ReplicatedStorage").PetRoll.Shared.PlaytimeRewards)
local Readout={}
Readout.__index=Readout

-- The coin and the clover (the Luck upgrade's art, assets/upgrade-icons-20261020).
Readout.Icons={Coins=Theme.Assets.Coin,Luck="rbxassetid://136683191941433"}
local KEYS={Coins="coins",Luck="luck"}
local GREEN=Theme.ReferenceColors.Army
local WHITE=Color3.new(1,1,1)
-- Right edge under the Settings gear (0.012 + 0.072); CornerNotice sits over the foot
-- of the numbers for its few seconds, as in the reference.
Readout.Position=UDim2.fromScale(0.994,0.094)
Readout.Size=UDim2.fromScale(0.11,0.106)

local function clock(seconds: number): string
	seconds=math.max(0,math.ceil(seconds))
	return string.format("%d:%02d",seconds//60,seconds%60)
end

function Readout.new(app)
	local self=setmetatable({app=app,connections={},columns={},nextStepAt=0},Readout)
	local root=Theme.Container(app.hudLayer,"BoostReadout")
	root.AnchorPoint,root.Position,root.Size,root.Visible=Vector2.new(1,0),Readout.Position,Readout.Size,false
	Theme.Aspect(root,1.75)
	self.root=root
	for index,kind in PlaytimeRewards.BoostKinds do
		local column=Theme.Container(root,kind)
		column.Position,column.Size=UDim2.fromScale((index-1)*0.5,0),UDim2.fromScale(0.5,1)
		local icon=Theme.Image(column,"Icon",Readout.Icons[kind],UDim2.fromScale(1,0.62),UDim2.fromScale(0.5,0))
		icon.AnchorPoint=Vector2.new(0.5,0)
		Theme.Aspect(icon,1)
		-- The number overlaps the icon's foot, like the reference.
		local value=Theme.Display(column,"Value","x1",30,WHITE)
		value.Position,value.Size,value.ZIndex=UDim2.fromScale(-0.05,0.5),UDim2.fromScale(1.1,0.3),5
		value.TextXAlignment,value.TextWrapped=Enum.TextXAlignment.Center,false
		Theme.Motion:Center(value)
		local timer=Theme.Display(column,"Timer","",20,GREEN)
		timer.Position,timer.Size,timer.ZIndex,timer.Visible=UDim2.fromScale(0,0.79),UDim2.fromScale(1,0.21),5,false
		timer.TextXAlignment,timer.TextWrapped=Enum.TextXAlignment.Center,false
		self.columns[kind]={value=value,timer=timer,endsAt=nil,last=nil}
	end
	Theme.ScaleText(root)
	-- UI Lab previews draw one still frame (Render steps once).
	if not app.editPreview then
		table.insert(self.connections,RunService.Heartbeat:Connect(function() self:Step() end))
	end
	return self
end

function Readout:Render(state)
	local boosts=state and state.boosts
	if type(boosts)~="table" then self.root.Visible=false;return end
	self.root.Visible=true
	local running=type(boosts.running)=="table" and boosts.running or {}
	for kind,column in self.columns do
		local total=tonumber(boosts[KEYS[kind]]) or 1
		column.value.Text=PlaytimeRewards.Times(total)
		local boost=running[kind]
		column.endsAt=if type(boost)=="table" then tonumber(boost.endsAt) else nil
		-- A confirmed rise (a boost, a friend, a Gold Rush, an upgrade) pops the number.
		if column.last and total>column.last*1.001 then Theme.Motion:PopScale(column.value,1.2) end
		column.last=total
	end
	self:Step(true)
end

-- The time left under a running boost; four times a second is plenty for m:ss.
function Readout:Step(force: boolean?)
	local now=os.clock()
	if not force and now<self.nextStepAt then return end
	self.nextStepAt=now+0.25
	local serverNow=workspace:GetServerTimeNow()
	for _,column in self.columns do
		local left=if column.endsAt then column.endsAt-serverNow else 0
		local shown=left>0
		column.timer.Visible=shown
		if shown then column.timer.Text=clock(left) end
		local color=if shown then GREEN else WHITE
		if column.value.TextColor3~=color then column.value.TextColor3=color end
	end
end

function Readout:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if self.root then self.root:Destroy();self.root=nil end
end

return Readout
