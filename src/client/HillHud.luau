--!strict
-- King of the Hill HUD (docs/team/KING_OF_THE_HILL.md), in Mini War's event
-- pattern: while a round runs, a big outlined title with a wide round bar sits
-- top-center (no panel behind it) and the world takes a warm event tint.
-- Between rounds only a small icon with the countdown waits at bottom-left.
-- Presentation only.
local Lighting=game:GetService("Lighting")
local TweenService=game:GetService("TweenService")
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
	local self=setmetatable({app=app,bannerVisible=false,kind=nil,tinted=false},HillHud)
	-- Slim boss bar (user pick "A", October 10): title, a studded square meter
	-- with the clock inside on the kit's slate track, one short line under it.
	local top=Theme.Container(shell,"HillEvent")
	top.AnchorPoint,top.Position,top.Size=Vector2.new(0.5,0),UDim2.fromScale(0.5,0.03),UDim2.fromScale(0.375,0.15)
	top.Visible=false
	Theme.Aspect(top,400/90)
	self.top=top
	self.title=scaled(Theme.Display(top,"Title","KING OF THE HILL",30,A.gold))
	self.title.Position,self.title.Size=UDim2.fromScale(0,0),UDim2.fromScale(1,0.38)
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

	-- Bottom-left countdown chip, in the gap between Upgrades and the cash readout.
	local waiting=Theme.Container(shell,"HillCountdown")
	waiting.AnchorPoint,waiting.Size=Vector2.new(0,1),UDim2.fromScale(0.2,0.058)
	waiting.Position=UDim2.fromScale(0.014,cash.Position.Y.Scale-cash.Size.Y.Scale-0.008)
	waiting.Visible=false
	local icon=Theme.Image(waiting,"Icon",Theme.Assets.Army,UDim2.fromScale(0.3,1),UDim2.fromScale(0,0))
	Theme.Aspect(icon,1)
	self.waitClock=scaled(Theme.Display(waiting,"Clock","",26,A.gold),Enum.TextXAlignment.Left)
	self.waitClock.Position,self.waitClock.Size=UDim2.fromScale(0.2,0.1),UDim2.fromScale(0.8,0.8)
	self.waiting=waiting

	local tint=Instance.new("ColorCorrectionEffect")
	tint.Name,tint.TintColor,tint.Enabled,tint.Parent="PetRollHillTint",Color3.new(1,1,1),false,Lighting
	self.tint=tint
	top.Destroying:Once(function() tint:Destroy() end)
	return self
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
	self.waiting.Visible=eligible and not open and not quiet
	if self.waiting.Visible then
		self.waitClock.Text=if hill.phase=="Opening" then "Hill opening soon" else "Hill in "..clock(remaining)
	end
	self.bannerVisible=open and not quiet
	self.top.Visible=self.bannerVisible
	self:SetTint(open)
	if not open then self.kind=nil;return end

	local kind=self:Kind(hill)
	local style=KINDS[kind]
	if kind~=self.kind then
		local first=self.kind==nil
		self.kind=kind
		self.title.Text,self.title.TextColor3=style.title,style.color
		self.fillGradient.Color=ColorSequence.new(style.color:Lerp(Color3.new(1,1,1),0.35),style.color)
		if not first and not app.reducedMotion and Theme.Motion and Theme.Motion.Pop then
			pcall(function() Theme.Motion:Pop(self.title,1.08) end)
		end
	end
	self.clock.Text=clock(remaining)
	self.fill.Size=UDim2.fromScale(math.clamp(remaining/math.max(1,hill.roundSeconds or 300),0,1),1)

	local leader=hill.leaderName
	local leaderText=if leader and leader~=state.name then leader.." leads "..clock(hill.leaderSeconds or 0)
		elseif leader then "You lead "..clock(hill.mySeconds or 0) else "Hold it longest to win"
	if kind=="hold" or kind=="defend" then
		self.detail.Text=string.format("+%d%% farm  ·  %s",math.floor(math.clamp(hill.myBoost or 0,0,0.5)*100+0.5),leaderText)
	else
		self.detail.Text=(if hill.holderName then "Held by "..hill.holderName else "Hill Guards hold it").."  ·  "..leaderText
	end
end

return HillHud
