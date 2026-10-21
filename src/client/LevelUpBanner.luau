--!strict
-- October 20 level-up banner (docs/team/CHICKEN_LABELS.md), copied from the Drop a
-- Fruit reference: "Duck leveled up! LVL 3 → 4" in gold lettering at the top centre,
-- with no panel behind it, when Chicken Feed levels a chicken. It pops in, holds for
-- about 4.5 s, then shrinks up and fades. It stands in for the green notice a Feed
-- level used to show (AppController's QUIET_SUCCESS); a failed feed still notifies.
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Theme=require(script.Parent.UITheme)
local Banner={}
Banner.__index=Banner

-- The reference shows it for about 4.6 s in all.
local HOLD_SECONDS=4.3
-- Screen shares: one line of lettering, the reference's size and height on screen.
local WIDTH,HEIGHT=0.62,0.055
local REFERENCE_Y=0.22

function Banner.new(app)
	local self=setmetatable({app=app,connections={},serial=0,leaving=false,alive=true},Banner)
	local group=Instance.new("CanvasGroup")
	group.Name,group.BackgroundTransparency,group.BorderSizePixel="LevelUpBanner",1,0
	group.AnchorPoint,group.Size=Vector2.new(0.5,0.5),UDim2.fromScale(WIDTH,HEIGHT)
	group.Active,group.Visible,group.ZIndex,group.GroupTransparency=false,false,21,1
	group.Parent=app.other
	local text=Theme.Display(group,"Text","",40,Theme.Arcade.gold)
	text.Size,text.TextScaled,text.TextWrapped=UDim2.fromScale(1,1),true,false
	text.TextXAlignment=Enum.TextXAlignment.Center
	self.group,self.text,self.scale=group,text,Theme.Motion:ScaleOf(group)
	-- A notice that turns up meanwhile moves the banner just below it.
	table.insert(self.connections,app.toastFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if group.Visible and not self.leaving then self:Place(true) end
	end))
	return self
end

-- The reference's height, lower when the notice's slot moves down for the Commander
-- card or the Hill title, and just under a notice that is showing, so the two never
-- overlap.
function Banner:Place(animate: boolean)
	local app=self.app
	local slot=app:NoticePosition().Y.Scale
	local toast=app.toastFrame
	local parent=self.group.Parent
	local tall=if parent and parent:IsA("GuiObject") and parent.AbsoluteSize.Y>0
		then toast.AbsoluteSize.Y/parent.AbsoluteSize.Y else 0.115
	local y=if toast.Visible and not app.noticeLeaving then slot+HEIGHT/2+0.012 else math.max(REFERENCE_Y,slot-tall/2)
	local goal=UDim2.fromScale(0.5,y)
	if animate then
		Theme.Motion:Tween(self.group,"banner-place",{Position=goal},0.15)
	else
		Theme.Motion:Cancel(self.group,"banner-place")
		self.group.Position=goal
	end
end

function Banner:Show(text: string)
	self.serial+=1
	local serial=self.serial
	local group,scale=self.group,self.scale
	local entering=not group.Visible or self.leaving
	self.leaving=false
	self.text.Text=text
	Theme.Motion:Cancel(group,"banner-rise")
	self:Place(false)
	group.Visible=true
	-- A new level while it shows only bumps it.
	if entering then group.GroupTransparency=1 end
	scale.Scale=if entering then 0.7 else 1.12
	Theme.Motion:Tween(group,"banner-fade",{GroupTransparency=0},0.16)
	Theme.Motion:Tween(scale,"banner-pop",{Scale=1},0.28,Enum.EasingStyle.Back)
	task.delay(HOLD_SECONDS,function()
		if self.alive and serial==self.serial then self:Leave() end
	end)
end

-- Shrinks up and fades, as in the reference.
function Banner:Leave()
	local group=self.group
	self.leaving=true
	Theme.Motion:Cancel(group,"banner-place")
	local style,direction=Enum.EasingStyle.Quad,Enum.EasingDirection.In
	Theme.Motion:Tween(self.scale,"banner-pop",{Scale=0.75},0.26,style,direction)
	Theme.Motion:Tween(group,"banner-rise",{Position=group.Position-UDim2.fromScale(0,0.03)},0.26,style,direction)
	Theme.Motion:Tween(group,"banner-fade",{GroupTransparency=1},0.26,style,direction,function()
		if self.leaving then group.Visible,self.leaving=false,false end
	end)
end

-- A Feed level. The numbers come from ToolService's reply ("Duck leveled up! Lv 3 → 4"),
-- else from the chicken's new level in the snapshot.
function Banner:Receive(_state,result)
	if not result or not result.ok or result.action~="FeedChicken" then return end
	local message=if type(result.message)=="string" then result.message else ""
	local pet=self.app:Pet(result.petId)
	local definition=pet and Catalog[pet.species]
	local before,after=string.match(message,"Lv (%d+) → (%d+)")
	local level=tonumber(after) or (pet and pet.level) or 1
	local previous=tonumber(before) or math.max(1,level-1)
	local name=if definition then definition.name else string.match(message,"^(.-) leveled up!") or "Chicken"
	self:Show(name.." leveled up! LVL "..previous.." → "..level)
end

function Banner:Destroy()
	self.alive=false
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	self.group:Destroy()
end

return Banner
