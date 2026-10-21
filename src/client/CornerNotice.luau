--!strict
-- October 20 corner notice (S16, docs/team/PLAYTIME_REWARDS.md): the reference's
-- "Free Reward Ready!" strip (Drop a Fruit uses the same one for "Quest Complete!";
-- S17 measured its timings). It slides in from the right inside a clipped strip under
-- the top-right boosts readout, a dark sunburst spins behind the icon while the icon
-- pops in tilted and settles, a yellow "New!" tag sits on the icon's corner, and a dark
-- see-through band holds a white title and a smaller body. It holds about 7.5 s, then
-- slides back out. One at a time; later ones queue. Display only.
--   app.cornerNotice:Show({title=string, body=string?, icon=imageId, tag="New!"?})
local Theme=require(script.Parent.UITheme)
local Notice={}
Notice.__index=Notice

local HOLD_SECONDS=7.5
local IN_SECONDS,OUT_SECONDS,POP_SECONDS=0.45,0.25,0.6
local MAX_QUEUE=6
local TAG_COLOR=Color3.fromRGB(255,221,46)
local BAND_COLOR=Color3.fromRGB(20,22,24)
local WHITE=Color3.new(1,1,1)
-- Right edge under the Settings gear (0.012 + 0.072). October 21: the coin/clover
-- readout that sat here moved to the bottom-left, so the strip moved up into its
-- place (was Y 0.165); it shows for about 8 s.
Notice.Position=UDim2.fromScale(0.994,0.094)
Notice.Size=UDim2.fromScale(0.24,0.12)
Notice.Aspect=3.6

function Notice.new(app)
	local self=setmetatable({app=app,queue={},alive=true},Notice)
	local root=Theme.Container(app.hudLayer,"CornerNotice")
	root.AnchorPoint,root.Position,root.Size,root.ZIndex=Vector2.new(1,0),Notice.Position,Notice.Size,12
	Theme.Aspect(root,Notice.Aspect)
	self.root=root
	return self
end

function Notice:Show(spec: {title: string, body: string?, icon: string?, tag: string?})
	if not self.alive or type(spec)~="table" or type(spec.title)~="string" then return end
	if #self.queue>=MAX_QUEUE then table.remove(self.queue,1) end
	table.insert(self.queue,spec)
	if not self.current then self:Next() end
end

-- One strip: a CanvasGroup clips the slide (rotated art included).
function Notice:Build(spec)
	local strip=Instance.new("CanvasGroup")
	strip.Name,strip.Size,strip.BackgroundTransparency,strip.BorderSizePixel="Strip",UDim2.fromScale(1,1),1,0
	strip.ZIndex,strip.Parent=self.root.ZIndex,self.root
	local content=Theme.Container(strip,"Content")
	local band=Theme.Frame(content,"Band",UDim2.fromScale(0.88,0.76),BAND_COLOR)
	band.Position,band.BackgroundTransparency,band.ZIndex=UDim2.fromScale(0.12,0.2),0.4,1
	local holder=Theme.Container(content,"IconHolder")
	holder.AnchorPoint,holder.Position,holder.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.12,0.57),UDim2.fromScale(1,0.78)
	Theme.Aspect(holder,1)
	local rays=Theme.Image(holder,"Sunburst",Theme.Assets.Rays,UDim2.fromScale(1.6,1.6),UDim2.fromScale(0.5,0.5))
	rays.AnchorPoint,rays.ImageColor3,rays.ImageTransparency,rays.ZIndex=Vector2.new(0.5,0.5),Color3.new(0,0,0),0.3,2
	local icon=Theme.Image(holder,"Icon",spec.icon or Theme.Assets.Coin,UDim2.fromScale(1,1),UDim2.fromScale(0.5,0.5))
	icon.AnchorPoint,icon.ZIndex=Vector2.new(0.5,0.5),3
	local tag=Theme.Display(content,"Tag",spec.tag or "",22,TAG_COLOR)
	tag.Position,tag.Size,tag.ZIndex,tag.Visible=UDim2.fromScale(0,0),UDim2.fromScale(0.15,0.3),5,spec.tag~=nil
	tag.TextXAlignment=Enum.TextXAlignment.Center
	local title=Theme.Display(content,"Title",spec.title,30,WHITE)
	title.Position,title.Size,title.ZIndex,title.TextWrapped=UDim2.fromScale(0.25,0.22),UDim2.fromScale(0.73,0.3),4,false
	-- Room for the body's two lines at the phone text floor.
	local body=Theme.Label(content,"Body",spec.body or "",20,WHITE)
	body.Position,body.Size,body.ZIndex=UDim2.fromScale(0.25,0.52),UDim2.fromScale(0.73,0.42),4
	Theme.ScaleText(strip)
	return strip,content,icon,rays
end

function Notice:Next()
	local spec=table.remove(self.queue,1)
	if not spec or not self.alive then self.current=nil;return end
	local strip,content,icon,rays=self:Build(spec)
	self.current=strip
	local motion=Theme.Motion
	-- Enters from the strip's right edge with the shared Pop ease and a cue (October 21).
	motion:Slide(content,UDim2.fromScale(1,0),UDim2.fromScale(0,0),IN_SECONDS,motion.Ease.Pop)
	self.app:Cue("NoticeIn","Pop")
	if motion.reduced then
		rays.Visible=false
	else
		-- The icon grows from nothing tilted about -20°, overshoots, then settles upright.
		local scale=motion:ScaleOf(icon)
		scale.Scale,icon.Rotation=0,-20
		motion:Tween(scale,"notice-pop",{Scale=1},POP_SECONDS,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
		motion:Tween(icon,"notice-tilt",{Rotation=0},POP_SECONDS,Enum.EasingStyle.Back,Enum.EasingDirection.Out)
		-- The sunburst spins from the first frame and fades once the icon has settled.
		motion:Tween(rays,"notice-spin",{Rotation=360},2.4,Enum.EasingStyle.Linear,Enum.EasingDirection.In,nil,-1)
		task.delay(POP_SECONDS,function()
			if not rays.Parent then return end
			motion:Tween(rays,"notice-fade",{ImageTransparency=1},0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.In,function()
				motion:Cancel(rays,"notice-spin")
			end)
		end)
	end
	task.delay(IN_SECONDS+HOLD_SECONDS,function()
		if self.current~=strip or not strip.Parent then return end
		local leave=motion.Ease.Leave
		motion:Tween(content,"slide",{Position=UDim2.fromScale(1,0)},OUT_SECONDS,leave.style,leave.direction,function()
			strip:Destroy()
			if self.current==strip then self.current=nil;self:Next() end
		end)
	end)
end

function Notice:Destroy()
	self.alive=false
	table.clear(self.queue)
	self.current=nil
	if self.root then self.root:Destroy();self.root=nil end
end

return Notice
