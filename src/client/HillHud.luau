--!strict
-- King of the Hill HUD (docs/team/KING_OF_THE_HILL.md), in Mini War's event
-- pattern: while a round runs the world takes a warm event tint, and a big
-- outlined title with a wide round bar sits top-center (no panel behind it) only
-- while your army fights there or you stand near the Hill. Otherwise (and between
-- rounds) a small chip above the cash readout shows the clock. Presentation only.
local Lighting=game:GetService("Lighting")
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local Config=require(game.ReplicatedStorage.PetRoll.Shared.Config)
local Theme=require(script.Parent.UITheme)
local A=Theme.Arcade
local HillHud={}
HillHud.__index=HillHud

local KINDS={
	idle={title="KING OF THE HILL",color=A.gold},
	march={title="MARCHING TO THE HILL",color=A.gold},
	attack={title="CAPTURING THE HILL",color=A.red},
	hold={title="YOU HOLD THE HILL",color=Theme.PageColors.Army},
	defend={title="HILL UNDER ATTACK!",color=A.red},
}
local TINT=Color3.fromRGB(255,232,196)
-- Within this many studs of the Hill site the full banner shows even without a fight.
local NEAR_STUDS=120

local function clock(seconds: number): string
	seconds=math.max(0,math.ceil(seconds))
	return string.format("%d:%02d",seconds//60,seconds%60)
end

local function scaled(label: TextLabel, align: Enum.TextXAlignment?)
	label.TextScaled,label.TextWrapped=true,false
	label.TextXAlignment=align or Enum.TextXAlignment.Center
	return label
end

function HillHud.new(app,shell: Instance,cash: Instance)
	local self=setmetatable({app=app,cash=cash,bannerVisible=false,kind=nil,tinted=false},HillHud)
	-- Slim boss bar (user pick "A", October 10): title, a studded square meter
	-- with the clock inside on the kit's slate track, one short line under it.
	local top=Theme.Container(shell,"HillEvent")
	top.AnchorPoint,top.Position,top.Size=Vector2.new(0.5,0),UDim2.fromScale(0.5,0.03),UDim2.fromScale(0.375,0.15)
	top.Visible=false
	Theme.Aspect(top,400/90)
	self.top=top
	self.title=scaled(Theme.Display(top,"Title","KING OF THE HILL",30,A.gold))
	self.title.Position,self.title.Size=UDim2.fromScale(0,0),UDim2.fromScale(1,0.38)
	Theme.Motion:Center(self.title) -- title pops grow from its middle; same place at rest
	local trackColor=Theme.Conquest.Track
	local track=Theme.Frame(top,"Round",UDim2.fromScale(0.9,0.245),trackColor)
	track.Position,track.ZIndex=UDim2.fromScale(0.05,0.445),2
	Theme.Gradient(track,trackColor:Lerp(Color3.new(1,1,1),0.12),trackColor:Lerp(Color3.new(0,0,0),0.2))
	Theme.Stroke(track,A.border,2)
	local fill=Theme.Frame(track,"Fill",UDim2.fromScale(1,1),Color3.new(1,1,1))
	fill.ZIndex=3
	self.fillGradient=Theme.Gradient(fill,A.gold:Lerp(Color3.new(1,1,1),0.35),A.gold)
	local studs=Theme.Studs(fill,0.16,22,0)
	studs.ZIndex=4
	self.track,self.fill=track,fill
	self.clock=scaled(Theme.Display(track,"Clock","5:00",17))
	self.clock.AnchorPoint,self.clock.Position,self.clock.Size,self.clock.ZIndex=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(0.5,0.78),6
	self.detail=scaled(Theme.Display(top,"Detail","",16))
	self.detail.Position,self.detail.Size=UDim2.fromScale(0.05,0.76),UDim2.fromScale(0.9,0.22)
	Theme.Motion:Center(self.detail) -- a new leader punches it from its middle

	-- Compact chip just above the cash readout (Place follows the touch layout).
	local waiting=Theme.Container(shell,"HillCountdown")
	waiting.AnchorPoint,waiting.Size=Vector2.new(0,1),UDim2.fromScale(0.2,0.058)
	waiting.Visible=false
	local icon=Theme.Image(waiting,"Icon",Theme.Assets.Army,UDim2.fromScale(0.3,1),UDim2.fromScale(0,0))
	Theme.Aspect(icon,1)
	self.waitClock=scaled(Theme.Display(waiting,"Clock","",26,A.gold),Enum.TextXAlignment.Left)
	self.waitClock.Position,self.waitClock.Size=UDim2.fromScale(0.2,0.1),UDim2.fromScale(0.8,0.8)
	self.waiting=waiting
	self:Place()

	local tint=Instance.new("ColorCorrectionEffect")
	tint.Name,tint.TintColor,tint.Enabled,tint.Parent="PetRollHillTint",Color3.new(1,1,1),false,Lighting
	self.tint=tint
	top.Destroying:Once(function() tint:Destroy() end)
	return self
end

function HillHud:Place()
	local cash=self.cash
	self.waiting.Position=UDim2.fromScale(cash.Position.X.Scale+0.002,cash.Position.Y.Scale-cash.Size.Y.Scale-0.008)
end

local function nearHill(): boolean
	local site=Config.IncomeOutpost and Config.IncomeOutpost.Position
	local character=Players.LocalPlayer.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if not site or not root or not root:IsA("BasePart") then return false end
	local dx,dz=root.Position.X-site[1],root.Position.Z-site[3]
	return dx*dx+dz*dz<=NEAR_STUDS*NEAR_STUDS
end

function HillHud:Kind(hill): string
	if hill.holding and hill.contested then return "defend" end
	if hill.holding then return "hold" end
	if hill.engaged and hill.contested then return "attack" end
	if hill.engaged then return "march" end
	return "idle"
end

function HillHud:SetTint(on: boolean)
	if self.tinted==on then return end
	self.tinted=on
	local goal={TintColor=if on then TINT else Color3.new(1,1,1),Saturation=if on then 0.08 else 0,Contrast=if on then 0.04 else 0}
	if on then self.tint.Enabled=true end
	local tween=TweenService:Create(self.tint,TweenInfo.new(if self.app.reducedMotion then 0 else 1.2),goal)
	tween.Completed:Once(function() if not self.tinted then self.tint.Enabled=false end end)
	tween:Play()
end

function HillHud:Update(state)
	local hill=state and state.hill
	local app=self.app
	local eligible=hill~=nil and hill.enabled==true and (state.allCampsWon==true or state.kingCleared==true
		or hill.engaged==true or hill.holding==true or (hill.wins or 0)>0 or (hill.mySeconds or 0)>0)
	local remaining=if hill then math.max(0,(hill.endsAt or 0)-workspace:GetServerTimeNow()) else 0
	local quiet=app.panel.Visible or app.dialogueActive==true
	local open=eligible and hill.phase=="Open"
	-- The full banner is for players at the Hill; a lesson card outranks it.
	local involved=open and (hill.engaged==true or hill.holding==true or nearHill())
	local lesson=app.commander~=nil and app.commander.lessonVisible==true
	self.bannerVisible=involved and not quiet and not lesson
	-- waitingShown is the wanted state; Visible lingers through Appear's shrink-out.
	self.waitingShown=eligible and not quiet and not self.bannerVisible
	Theme.Motion:Appear(self.waiting,self.waitingShown,0.8)
	if self.waitingShown then
		self.waitClock.Text=if open then "Hill fight "..clock(remaining)
			elseif hill.phase=="Opening" then "Hill opening soon" else "Hill in "..clock(remaining)
	end
	Theme.Motion:Appear(self.top,self.bannerVisible,0.85)
	self:SetTint(open)
	if not open then self.kind,self.lastLeader=nil,nil;return end

	local kind=self:Kind(hill)
	local style=KINDS[kind]
	if kind~=self.kind then
		local first=self.kind==nil
		self.kind=kind
		self.title.Text,self.title.TextColor3=style.title,style.color
		self.fillGradient.Color=ColorSequence.new(style.color:Lerp(Color3.new(1,1,1),0.35),style.color)
		if not first then
			Theme.Motion:Punch(self.title,1.18,0.3)
			if kind=="defend" then Theme.Motion:Shake(self.track,6)
			elseif kind=="hold" then Theme.Motion:Burst(self.top,UDim2.fromScale(0.5,0.2),style.color) end
		end
	end
	self.clock.Text=clock(remaining)
	Theme.Motion:Tween(self.fill,"fill",{Size=UDim2.fromScale(math.clamp(remaining/math.max(1,hill.roundSeconds or 300),0,1),1)},0.3)

	local leader=hill.leaderName
	-- October 21 game feel: a change of leader (the king of the round) punches the line.
	if self.lastLeader~=nil and (leader or false)~=self.lastLeader then Theme.Motion:Punch(self.detail,1.12,0.3) end
	self.lastLeader=leader or false
	local leaderText=if leader and leader~=state.name then leader.." leads "..clock(hill.leaderSeconds or 0)
		elseif leader then "You lead "..clock(hill.mySeconds or 0) else "Hold it longest to win"
	if kind=="hold" or kind=="defend" then
		self.detail.Text=string.format("+%d%% farm  ·  %s",math.floor(math.clamp(hill.myBoost or 0,0,0.5)*100+0.5),leaderText)
	else
		self.detail.Text=(if hill.holderName then "Held by "..hill.holderName else "Hill Guards hold it").."  ·  "..leaderText
	end
end

return HillHud
