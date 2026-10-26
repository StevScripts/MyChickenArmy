--!strict
-- October 20 boosts readout (S16, docs/team/PLAYTIME_REWARDS.md): the reference's coin
-- "x9.2" and clover "x4.5", showing the player's total Coins and Luck multipliers.
-- October 21 (Stevin): moved from the top-right to one row under Friend Boost, then
-- (later October 21, his reference image) to a very small pair of icons in the
-- bottom-right corner (HudController's BoostSlot), each number a badge overlaid on
-- its icon's top-right. The server computes both (state.boosts,
-- PlaytimeService.Boosts); this module only presents. Stevin, October 20, approved one
-- addition to the reference: while a Playtime Rewards boost runs, its number turns
-- green with the time left over the foot of its icon.
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
-- October 21 game feel: a running boost's column glows in its own colour.
local GLOW={Coins=Theme.Colors.coins,Luck=GREEN}
-- The bottom-right corner, very small: two square icons with a gap between them.
-- HudController's BoostSlot uses these too; without it (UI Lab story) the readout
-- places itself on the HUD layer.
local COLUMN_GAP=0.15 -- of one icon's width
Readout.Aspect=2+COLUMN_GAP
Readout.Position=UDim2.fromScale(0.988,0.98)
Readout.Size=UDim2.fromScale(0.2,0.055)

local function clock(seconds: number): string
	seconds=math.max(0,math.ceil(seconds))
	return string.format("%d:%02d",seconds//60,seconds%60)
end

function Readout.new(app)
	local self=setmetatable({app=app,connections={},columns={},nextStepAt=0},Readout)
	local slot=app.hud and app.hud.boostSlot
	local root=Theme.Container(slot or app.hudLayer,"BoostReadout")
	if not slot then
		root.AnchorPoint,root.Position,root.Size=Vector2.new(1,1),Readout.Position,Readout.Size
		Theme.Aspect(root,Readout.Aspect)
	end
	root.Visible=false
	self.root=root
	for index,kind in PlaytimeRewards.BoostKinds do
		local column=Theme.Container(root,kind)
		column.Position=UDim2.fromScale((index-1)*(1+COLUMN_GAP)/Readout.Aspect,0)
		column.Size=UDim2.fromScale(1/Readout.Aspect,1)
		-- October 23: the icons idle with the HUD's slow tilt (Motion:Sway).
		Theme.Motion:Sway(Theme.Image(column,"Icon",Readout.Icons[kind],UDim2.fromScale(1,1)),5,1.4,index*0.4)
		-- The number is a tilted badge over the icon's top-right corner.
		local value=Theme.Display(column,"Value","x1",30,WHITE)
		value.AnchorPoint,value.Position,value.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.8,0.16),UDim2.fromScale(0.9,0.46)
		value.Rotation,value.ZIndex=-8,5
		value.TextXAlignment,value.TextWrapped=Enum.TextXAlignment.Center,false
		local timer=Theme.Display(column,"Timer","",20,GREEN)
		timer.AnchorPoint,timer.Position,timer.Size=Vector2.new(0.5,1),UDim2.fromScale(0.5,1.08),UDim2.fromScale(1.15,0.38)
		timer.ZIndex,timer.Visible=5,false
		timer.TextXAlignment,timer.TextWrapped=Enum.TextXAlignment.Center,false
		self.columns[kind]={root=column,value=value,timer=timer,endsAt=nil,last=nil,glowing=false}
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
	-- October 23: hidden while the tutorial keeps the HUD quiet (lessons 1-2); Hud re-renders it.
	self.root.Visible=not (self.app.hud~=nil and self.app.hud.quiet==true)
	local running=type(boosts.running)=="table" and boosts.running or {}
	for kind,column in self.columns do
		local total=tonumber(boosts[KEYS[kind]]) or 1
		column.value.Text=PlaytimeRewards.Times(total)
		local boost=running[kind]
		column.endsAt=if type(boost)=="table" then tonumber(boost.endsAt) else nil
		-- A confirmed rise (a boost, a friend, a Gold Rush, an upgrade) pops the number.
		if column.last and total>column.last*1.001 then Theme.Motion:Punch(column.value,1.25,0.3) end
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
	for kind,column in self.columns do
		local left=if column.endsAt then column.endsAt-serverNow else 0
		local shown=left>0
		column.timer.Visible=shown
		if shown then column.timer.Text=clock(left) end
		local color=if shown then GREEN else WHITE
		if column.value.TextColor3~=color then column.value.TextColor3=color end
		-- One glow while the boost runs; nothing loops once it ends.
		if shown~=column.glowing then
			column.glowing=shown
			if shown then Theme.Motion:Glow(column.root,GLOW[kind] or WHITE,2) else Theme.Motion:StopGlow(column.root) end
		end
	end
end

function Readout:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if self.root then self.root:Destroy();self.root=nil end
end

return Readout
