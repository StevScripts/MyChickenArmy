--!strict
-- Country screenshot vocabulary. This module owns presentation, never game state.
local Theme = {}
local Palette = require(game:GetService("ReplicatedStorage").PetRoll.Shared.UIColors)
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
Theme.Motion = require(script.Parent.UIMotion).new()
Theme.Font = Enum.Font.SourceSansBold
-- One edge hierarchy across menus; secondary surfaces never outweigh the shell.
Theme.Border = {Shell=3, Control=2, Card=1.5, Detail=1}
Theme.OverlayColors = {Top=Color3.fromRGB(20,22,24), Bottom=Color3.fromRGB(3,4,5)}
Theme.Arcade = {
	blue=Palette.Navigation, gold=Palette.Rewards, purple=Palette.Upgrade,
	red=Palette.Danger, green=Palette.Purchase, border=Palette.Border,
	army=Palette.Army, sell=Palette.Sell,
}
Theme.Colors = {
	ink=Palette.Text, muted=Palette.Muted, money=Palette.Money,
	paper=Palette.Body, white=Palette.Text,
	panel=Palette.Body, line=Palette.Line,
	card=Palette.Card, cardInk=Palette.CardText, cardMuted=Palette.CardMuted, cardMoney=Palette.CardMoney,
	gold=Theme.Arcade.gold, green=Theme.Arcade.green, blue=Theme.Arcade.blue,
	red=Theme.Arcade.red, dark=Palette.Body,
}
Theme.NavigationColors = {
	Cyan=Color3.fromRGB(0,221,255),
	HotPink=Color3.fromRGB(255,0,94),
	Orange=Color3.fromRGB(255,162,0),
}
-- Exact reference swatches shared by the top navigation and its menus.
Theme.PageColors = {
	Base=Theme.NavigationColors.HotPink,
	Army=Theme.NavigationColors.Cyan, Upgrades=Theme.NavigationColors.Orange, Sell=Theme.Arcade.sell, Merge=Theme.Arcade.purple,
	Settings=Theme.Arcade.blue, Test=Theme.Arcade.blue, Admin=Theme.Arcade.blue, Odds=Theme.NavigationColors.Orange, Recruits=Theme.NavigationColors.Orange,
	Shop=Theme.Arcade.gold, Index=Theme.Arcade.blue,
}
Theme.HeaderColors = table.clone(Theme.PageColors)
Theme.PageSurfaces = {
	Army=Theme.PageColors.Army:Lerp(Color3.new(0,0,0),0.55),
	Upgrades=Theme.PageColors.Upgrades:Lerp(Color3.new(0,0,0),0.55),
}
Theme.PageSurfaces.Odds,Theme.PageSurfaces.Recruits=Theme.PageSurfaces.Upgrades,Theme.PageSurfaces.Upgrades
Theme.ActionColors = {
	navigation=Theme.Arcade.blue, purchase=Theme.Arcade.green, sell=Theme.Arcade.sell,
	danger=Theme.Arcade.red, disabled=Palette.Disabled, selected=Palette.Rewards,
}
-- October 6 conquest recording: red four-section meter, green owned marker.
Theme.Conquest = require(game:GetService("ReplicatedStorage").PetRoll.Shared.ConquestPresentation)
-- Opt-in cash affordability feedback for the yard and egg-collection upgrades.
Theme.UnaffordableGradient = ColorSequence.new(Color3.fromRGB(166,166,166),Color3.fromRGB(92,92,92))
Theme.Assets = {
	Commander="rbxassetid://122076338993517",
	Merge = "rbxassetid://122096168414414",
	Cash="rbxassetid://101788696120931", Studs="rbxassetid://93331178043153",
	Rays="rbxassetid://120904904160174", Multiplier="rbxassetid://124712149166140",
	Army="rbxassetid://100291580520125", Luck="rbxassetid://111087925336083",
	ArmyHud="rbxassetid://107457338807219", CallArmy="rbxassetid://125964672530167", MyBase="rbxassetid://76117843071069",
	Shop="rbxassetid://119358432410091", Index="rbxassetid://96489791857751", EggMagnet="rbxassetid://131332157337305",
}
Theme.Rarities = Palette.Rarities
-- Background-free messages in the UI kit's lettering: status-gradient text with a
-- dark outline and a hard drop, led by a matching self-drawing mark.
local INK=Color3.fromRGB(16,23,16)
Theme.NotificationStyles = {
	conquest={symbol="⚔",color=Theme.Conquest.Owned},
	-- Success and error reuse the kit's header green and close-button red.
	success={symbol="✓",color=Color3.fromRGB(112,222,98),top=Color3.fromRGB(176,255,1),bottom=Color3.fromRGB(23,223,0)},
	error={symbol="×",color=Color3.fromRGB(255,120,132),top=Color3.fromRGB(255,107,83),bottom=Color3.fromRGB(233,51,43)},
	warning={symbol="!",color=Color3.fromRGB(244,194,71)},
	info={symbol="i",color=Theme.Arcade.blue:Lerp(Palette.Text,0.35)},
	pending={symbol="…",color=Palette.Muted},
}
-- Pen strokes (polylines) in a 46-unit box, drawn in order. Path2D renders them as
-- smooth vector lines; rotated Frames stair-stepped and jittered when scaled.
local NOTIFICATION_MARKS={
	success={{{8,24},{18,34},{38,12}}},
	error={{{11,11},{35,35}},{{35,11},{11,35}}},
	conquest={{{11,11},{35,35}},{{35,11},{11,35}}},
	-- A single point is a square dot. Stacked pieces leave room for the outlines and the
	-- drop shadow, which would otherwise fill the gap and merge them.
	warning={{{23,0},{23,21}},{{23,39}}},
	info={{{23,4}},{{23,21},{23,44}}},
	pending={{{4,23}},{{23,23}},{{42,23}}},
}

-- The first `progress` share of a polyline, optionally lengthened at both ends
-- (outlines need square ends because Path2D caps are flat).
-- Narrow marks read thin next to the check and X, so they draw heavier.
local NOTIFICATION_MARK_WEIGHT={info=1.3,warning=1.3,pending=1.3}

local function partialStroke(points,length,progress,extend,shift)
	local want,walked,out=length*progress,0,{points[1]}
	for index=2,#points do
		local a,b=points[index-1],points[index]
		local piece=(b-a).Magnitude
		if walked+piece>=want then
			if piece>0 then table.insert(out,a+(b-a)*((want-walked)/piece)) else table.insert(out,b) end
			break
		end
		table.insert(out,b);walked+=piece
	end
	if #out<2 or want<=0 then return nil end
	if extend>0 then
		local first,last=out[2]-out[1],out[#out]-out[#out-1]
		if first.Magnitude>0 then out[1]-=first.Unit*extend end
		if last.Magnitude>0 then out[#out]+=last.Unit*extend end
	end
	local control={}
	for _,point in out do table.insert(control,Path2DControlPoint.new(UDim2.fromOffset(point.X,point.Y+shift))) end
	return control
end
local notificationMotion=setmetatable({},{__mode="k"})

local function notificationTones(kind)
	local style=Theme.NotificationStyles[kind] or Theme.NotificationStyles.info
	local top=style.top or style.color:Lerp(Color3.new(1,1,1),0.35)
	return ColorSequence.new(top,style.bottom or style.color)
end

-- Rebuilds the row at rest (fully drawn). NotificationFlair animates it from empty.
local function layoutNotification(group)
	local label,row=group:FindFirstChild("Toast"),group:FindFirstChild("Row")
	if not label or not row then return end
	local kind,text=group:GetAttribute("Kind") or "info",label:GetAttribute("PlainText") or ""
	local size=group.AbsoluteSize
	local width,height=if size.X>1 then size.X else 1000,if size.Y>1 then size.Y else 110
	local lines=select(2,text:gsub("\n",""))+1
	local fontSize=math.clamp(math.floor(math.min(height*0.36,height*0.82/lines)),14,40)
	local measure,iconSize,gap
	repeat
		measure=TextService:GetTextSize(text,fontSize,Theme.Font,Vector2.new(100000,100000))
		iconSize=math.floor(fontSize*1.15);gap=math.floor(fontSize*0.3)
		if measure.X+iconSize+gap<=width*0.96 or fontSize<=14 then break end
		fontSize-=1
	until false
	label.TextSize=fontSize
	local outline=math.max(2,math.floor(fontSize*0.08+0.5))
	local drop=math.max(2,math.floor(fontSize*0.08+0.5))
	local pad=outline+2
	row:ClearAllChildren()
	row.Size=UDim2.fromOffset(iconSize+gap+measure.X+pad,math.max(iconSize,measure.Y)+drop)
	local tones=notificationTones(kind)
	local icon=Instance.new("Frame")
	icon.Name,icon.BackgroundTransparency,icon.AnchorPoint="Icon",1,Vector2.new(0,0.5)
	icon.Position,icon.Size=UDim2.new(0,0,0.5,-drop/2),UDim2.fromOffset(iconSize,iconSize)
	icon.Parent=row
	local pop=Instance.new("UIScale");pop.Name,pop.Parent="Pop",icon
	local scale=iconSize/46
	local thin=7*scale*(NOTIFICATION_MARK_WEIGHT[kind] or 1)
	local thick=thin+6*scale
	local face=tones.Keypoints[1].Value:Lerp(tones.Keypoints[#tones.Keypoints].Value,0.45)
	local strokes={}
	for _,mark in NOTIFICATION_MARKS[kind] or NOTIFICATION_MARKS.info do
		local points,length={},0
		for index,point in mark do points[index]=Vector2.new(point[1],point[2])*scale end
		if #points==1 then
			local half=Vector2.new(0,thin/2)
			points={points[1]-half,points[1]+half}
		end
		for index=2,#points do length+=(points[index]-points[index-1]).Magnitude end
		local progress=Instance.new("NumberValue");progress.Name,progress.Value,progress.Parent="Progress",1,icon
		table.insert(strokes,{points=points,length=length,paths={},progress=progress})
	end
	-- Shadows, then outlines, then faces: crossing strokes never cut each other.
	for layer,spec in {{thick,INK,drop,(thick-thin)/2},{thick,INK,0,(thick-thin)/2},{thin,face,0,0}} do
		for _,stroke in strokes do
			local path=Instance.new("Path2D")
			path.Name,path.Thickness,path.Color3,path.ZIndex=("Stroke"..layer),spec[1],spec[2],layer
			path.Parent=icon
			table.insert(stroke.paths,{path=path,shift=spec[3],extend=spec[4]})
		end
	end
	for _,stroke in strokes do
		local function draw()
			for _,entry in stroke.paths do
				local control=partialStroke(stroke.points,stroke.length,stroke.progress.Value,entry.extend,entry.shift)
				entry.path.Visible=control~=nil
				if control then entry.path:SetControlPoints(control) end
			end
		end
		stroke.progress.Changed:Connect(draw)
		draw()
	end
	local clip=Instance.new("Frame")
	clip.Name,clip.BackgroundTransparency,clip.ClipsDescendants="TextClip",1,true
	-- Padded on every side so the outline and drop are never trimmed at rest.
	clip.Position=UDim2.fromOffset(iconSize+gap-pad,-pad)
	clip.Size=UDim2.fromOffset(measure.X+pad*2,row.Size.Y.Offset+pad*2)
	clip.Parent=row
	for _,layer in {{"Shadow",drop,1},{"Face",0,2}} do
		local face=Instance.new("TextLabel")
		face.Name,face.BackgroundTransparency,face.Text,face.Font,face.TextSize=layer[1],1,text,Theme.Font,fontSize
		face.TextColor3=if layer[1]=="Face" then Color3.new(1,1,1) else INK
		face.TextXAlignment,face.TextYAlignment=Enum.TextXAlignment.Left,Enum.TextYAlignment.Center
		face.AnchorPoint=Vector2.new(0,0.5)
		face.Position=UDim2.new(0,pad,0.5,layer[2]-drop/2)
		face.Size=UDim2.fromOffset(measure.X,measure.Y)
		face.ZIndex=layer[3]
		local stroke=Instance.new("UIStroke");stroke.Color,stroke.Thickness,stroke.Parent=INK,outline,face
		if layer[1]=="Face" then
			local gradient=Instance.new("UIGradient");gradient.Color,gradient.Rotation,gradient.Parent=tones,90,face
		end
		face.Parent=clip
	end
	notificationMotion[group]=notificationMotion[group] or {}
	notificationMotion[group].strokes=strokes
	notificationMotion[group].clipWidth=clip.Size.X.Offset
end

function Theme.SetNotification(label, text, kind)
	label.Text=text
	label:SetAttribute("PlainText",text)
	local group=label.Parent
	if group then group:SetAttribute("Kind",kind);layoutNotification(group) end
end

function Theme.Round(item, radius)
	local corner = item:FindFirstChildWhichIsA("UICorner") or Instance.new("UICorner")
	-- Shared surfaces are square; intentional circular masks override this.
	corner.CornerRadius = UDim.new(0, 0)
	corner.Parent = item
	return corner
end

function Theme.Stroke(item, color, thickness)
	local outline = item:FindFirstChild("UIStroke") or Instance.new("UIStroke")
	outline.Name, outline.Color = "UIStroke", color or Theme.Arcade.border
	outline.Thickness = thickness or 3
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.LineJoinMode = Enum.LineJoinMode.Miter
	outline.Parent = item
	return outline
end

function Theme.Gradient(item, top, bottom)
	local gradient = item:FindFirstChildWhichIsA("UIGradient") or Instance.new("UIGradient")
	gradient.Color, gradient.Rotation = ColorSequence.new(top, bottom), 90
	gradient.Parent = item
	return gradient
end

function Theme.Frame(parent, name, size, color)
	local frame = Instance.new("Frame")
	frame.Name, frame.Size = name, size
	frame.BackgroundColor3, frame.BorderSizePixel = color or Theme.Colors.paper, 0
	frame.Parent = parent
	Theme.Round(frame)
	return frame
end

-- Structural containers are transparent and fill their parent. They do not own
-- a surface, stroke or animation scale (StarterGui.Example uses the same layers).
function Theme.Container(parent, name)
	local container=Instance.new("Frame")
	container.Name,container.Size=name,UDim2.fromScale(1,1)
	container.BackgroundTransparency,container.BorderSizePixel=1,0
	container.Parent=parent
	return container
end

-- Keep inset-specific overlays inside the one game ScreenGui. GetInsetArea
-- rectangles and AbsolutePosition share the Core UI origin. Enum.ScreenInsets.None
-- reaches the full device screen, past notches the safe-area ScreenGui excludes.
function Theme.FitToInset(item, parent, screenInsets)
	local guiService=game:GetService("GuiService")
	local function resize()
		local area=guiService:GetInsetArea(screenInsets)
		local position=area.Min-parent.AbsolutePosition
		local size=area.Max-area.Min
		item.Position,item.Size=UDim2.fromOffset(position.X,position.Y),UDim2.fromOffset(size.X,size.Y)
	end
	local connections={
		parent:GetPropertyChangedSignal("AbsolutePosition"):Connect(resize),
		parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize),
		guiService:GetPropertyChangedSignal("TopbarInset"):Connect(resize),
	}
	item.Destroying:Once(function()
		for _,connection in connections do connection:Disconnect() end
	end)
	resize()
	return item
end

function Theme.InsetContainer(parent, name, screenInsets)
	return Theme.FitToInset(Theme.Container(parent,name),parent,screenInsets)
end

function Theme.Aspect(item, ratio)
	local constraint=item:FindFirstChildWhichIsA("UIAspectRatioConstraint")
	if not ratio then if constraint then constraint:Destroy() end;return end
	constraint=constraint or Instance.new("UIAspectRatioConstraint")
	constraint.Name,constraint.AspectRatio="UIAspectRatioConstraint",ratio
	constraint.AspectType,constraint.DominantAxis=Enum.AspectType.FitWithinMaxSize,Enum.DominantAxis.Width
	constraint.Parent=item
end

-- The restored GUI uses native text fitting inside proportionally sized boxes.
-- October 8 readability floor: TextScaled may shrink text to fit, but never below
-- MinTextSize on phones. Only a minimum is added (MaxTextSize stays at Roblox's
-- 100 ceiling), so desktop layouts are unchanged. The floor is attached on the
-- next frame and skipped when a caller added its own measured constraint.
Theme.MinTextSize = 12
local READABLE_TEXT="ReadableTextSize"
function Theme.ScaleText(root)
	local function apply(item)
		if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
			item.TextScaled=true
			item.TextTruncate=Enum.TextTruncate.None
			for _,child in item:GetChildren() do if child:IsA("UITextSizeConstraint") then child:Destroy() end end
			task.defer(function()
				if not item.Parent or item:FindFirstChildWhichIsA("UITextSizeConstraint") then return end
				local floor=Instance.new("UITextSizeConstraint")
				floor.Name,floor.MinTextSize,floor.MaxTextSize=READABLE_TEXT,Theme.MinTextSize,100
				floor.Parent=item
			end)
		end
	end
	apply(root)
	for _,item in root:GetDescendants() do apply(item) end
end

-- Express a designed rectangle in its own parent's coordinate space. Insets and
-- touch targets may remain pixels; artwork/composition must follow the parent.
function Theme.RelativeRect(item,x,y,width,height,parentWidth,parentHeight)
	item.Position=UDim2.fromScale(x/math.max(1,parentWidth),y/math.max(1,parentHeight))
	item.Size=UDim2.fromScale(width/math.max(1,parentWidth),height/math.max(1,parentHeight))
end

function Theme.Image(parent, name, asset, size, position)
	local image = Instance.new("ImageLabel")
	image.Name, image.Image = name, asset
	image.Size, image.Position = size, position or UDim2.new()
	image.BackgroundTransparency, image.ScaleType, image.ZIndex = 1, Enum.ScaleType.Fit, 3
	image.Parent = parent
	return image
end

-- One full-sheet image cropped by a transparent frame; never individual studs.
local studBindings = setmetatable({}, {__mode="k"})

function Theme.BindStudTexture(pattern: ImageLabel, spacing: number?)
	local parent=pattern.Parent
	if not parent then return end
	local clip
	if parent:IsA("Frame") and parent:GetAttribute("StudSheetClip")==true then
		clip=parent
	else
		clip=Instance.new("Frame")
		clip.Name="StudClip"
		clip:SetAttribute("StudSheetClip",true)
		clip.Size,clip.Position,clip.AnchorPoint=pattern.Size,pattern.Position,pattern.AnchorPoint
		clip.Rotation,clip.LayoutOrder=pattern.Rotation,pattern.LayoutOrder
		clip.BackgroundTransparency,clip.BorderSizePixel,clip.Active=1,0,false
		clip.ClipsDescendants=true
		clip.Parent=parent
		pattern.Parent=clip
	end
	pattern.Image,pattern.ScaleType=Theme.Assets.Studs,Enum.ScaleType.Stretch
	pattern.ImageRectOffset,pattern.ImageRectSize=Vector2.zero,Vector2.zero
	pattern.Position,pattern.AnchorPoint,pattern.Rotation=UDim2.new(),Vector2.zero,0
	pattern.BackgroundTransparency,pattern.BorderSizePixel,pattern.Active=1,0,false
	-- Keep the sheet square. Action surfaces use their height so wide buttons
	-- crop more of the same stud scale instead of enlarging every stud.
	local aspect=pattern:FindFirstChildWhichIsA("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	aspect.Name,aspect.AspectRatio="UIAspectRatioConstraint",1
	aspect.AspectType,aspect.DominantAxis=Enum.AspectType.FitWithinMaxSize,Enum.DominantAxis.Width
	aspect.Parent=pattern
	if studBindings[pattern] then return pattern end
	local function resize()
		local width=pattern:GetAttribute("StudScaleWidth")
		local height=pattern:GetAttribute("StudScaleHeight")
		if height and not width then
			aspect.DominantAxis=Enum.DominantAxis.Height
			pattern.Size=UDim2.fromScale(1000,height)
		else
			aspect.DominantAxis=Enum.DominantAxis.Width
			pattern.Size=UDim2.fromScale(width or 3,1000)
		end
	end
	local function layer() clip.ZIndex,clip.Visible=pattern.ZIndex,pattern.Visible end
	local connections={
		pattern:GetAttributeChangedSignal("StudScaleWidth"):Connect(resize),
		pattern:GetAttributeChangedSignal("StudScaleHeight"):Connect(resize),
		pattern:GetPropertyChangedSignal("ZIndex"):Connect(layer),
		pattern:GetPropertyChangedSignal("Visible"):Connect(layer),
	}
	studBindings[pattern]=connections
	table.insert(connections,pattern.Destroying:Connect(function()
		for _,connection in connections do connection:Disconnect() end
		studBindings[pattern]=nil
	end))
	resize();layer()
	return pattern
end

-- Connections do not clone with authored SurfaceGuis; bind each live copy.
function Theme.BindStudTextures(root: Instance)
	for _,item in root:GetDescendants() do
		if item:IsA("ImageLabel") and item.Name=="StudTexture" then
			Theme.BindStudTexture(item)
		end
	end
end

function Theme.Studs(parent, opacity, tilePixels, inset)
	for _,name in {"CheckerPattern","PopupStudTexture","FigmaStuds","StudPattern"} do
		local old=parent:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local clip=parent:FindFirstChild("StudClip")
	local existing=(clip and clip:FindFirstChild("StudTexture")) or parent:FindFirstChild("StudTexture")
	if existing and not existing:IsA("ImageLabel") then existing:Destroy();existing=nil end
	local pattern = if existing and existing:IsA("ImageLabel") then existing else Theme.Image(parent,"StudTexture",Theme.Assets.Studs,UDim2.fromScale(1,1))
	local padding,spacing=inset or 5,tilePixels or 28
	Theme.BindStudTexture(pattern,spacing)
	local bounds=pattern.Parent
	local insetScale=if padding==0 then 0 else 0.015
	bounds.Size,bounds.Position=UDim2.fromScale(1-insetScale*2,1-insetScale*2),UDim2.fromScale(insetScale,insetScale)
	pattern.ImageTransparency, pattern.ZIndex = 1-(opacity or 0.14), 2
	return pattern
end

local function alignPopupBody(body)
	body.Position=UDim2.fromScale(body.AnchorPoint.X,body.Position.Y.Scale)
	body.Size=UDim2.fromScale(1,body.Size.Y.Scale)
	local stroke=body:FindFirstChildWhichIsA("UIStroke")
	if stroke then stroke.Enabled=false end
end

function Theme.Surface(item, tint)
	tint = tint or Theme.Colors.panel
	item.BackgroundColor3, item.BackgroundTransparency = Color3.new(1,1,1), 0
	Theme.Gradient(item,tint:Lerp(Palette.Text,0.035),tint)
	Theme.Stroke(item,Theme.Arcade.border,3)
	local inset=item:FindFirstChild("InnerRim") or Theme.Frame(item,"InnerRim",UDim2.fromScale(0.98,0.98))
	inset.Position,inset.BackgroundTransparency=UDim2.fromScale(0.01,0.01),1
	Theme.Stroke(inset,Theme.Colors.line,Theme.Border.Detail)
	if item:GetAttribute("PopupBody")==true then alignPopupBody(item) end
	return item
end

function Theme.Label(parent, name, text, size, color)
	local lightSurface = parent:GetAttribute("LightSurface") == true
	local label = Instance.new("TextLabel")
	label.Name, label.Text = name, text
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1,0.1), 1
	label.Font, label.TextSize = Theme.Font, size or 20
	label.TextColor3 = color or (if lightSurface then Theme.Colors.cardInk else Theme.Colors.ink)
	label.TextXAlignment, label.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Center
	label.TextWrapped, label.TextStrokeTransparency, label.ZIndex = true, 1, 4
	local outline=Instance.new("UIStroke")
	outline.Name,outline.Color="TextOutline",Theme.Arcade.border
	-- Native scaling follows the rendered glyph size, including TextScaled.
	-- Using nominal TextSize here made compact labels carry oversized outlines.
	outline.StrokeSizingMode,outline.Thickness=Enum.StrokeSizingMode.ScaledSize,0.055
	outline.Enabled = not lightSurface
	outline.Parent=label
	label.Parent = parent
	return label
end

function Theme.Notification(parent)
	local group=Instance.new("CanvasGroup")
	group.Name,group.Size="Notification",UDim2.fromScale(0.58,0.13)
	group.BackgroundTransparency,group.BorderSizePixel=1,0
	group.Active,group.Visible,group.ZIndex=false,false,20
	group.AnchorPoint,group.Position=Vector2.new(0.5,1),UDim2.fromScale(0.5,0.24)
	group.Parent=parent
	-- Invisible measuring label: callers fit message text to its width and TextSize.
	local label=Theme.Label(group,"Toast","",34,Theme.Colors.ink)
	label.Position,label.Size=UDim2.fromScale(0.02,0.1),UDim2.fromScale(0.96,0.8)
	label.TextTransparency,label.TextOutline.Enabled,label.Active=1,false,false
	local row=Instance.new("Frame")
	row.Name,row.BackgroundTransparency,row.AnchorPoint,row.Position="Row",1,Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
	row.Parent=group
	group:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() layoutNotification(group) end)
	return group,label
end

local function trackNotification(group,item,seconds,goal,style,direction,delay)
	local motion=notificationMotion[group]
	local tween=TweenService:Create(item,TweenInfo.new(seconds,style or Enum.EasingStyle.Quart,direction or Enum.EasingDirection.Out,0,false,delay or 0),goal)
	table.insert(motion.tweens,tween);tween:Play()
	return tween
end

-- Steps on one property must chain: a later Play() on the same property cancels
-- an earlier tween even while the later one is still waiting out its delay.
local function chainNotification(group,item,delay,steps)
	local function play(index,wait)
		local step=steps[index]
		if not step then return end
		local tween=trackNotification(group,item,step[1],step[2],step[3] or Enum.EasingStyle.Quad,step[4],wait)
		tween.Completed:Once(function(state)
			if state==Enum.PlaybackState.Completed then play(index+1,0) end
		end)
	end
	play(1,delay)
end

local function stopNotification(group)
	local motion=notificationMotion[group]
	if not motion then return nil end
	for _,tween in motion.tweens or {} do tween:Cancel() end
	motion.tweens={}
	if motion.leaving then task.cancel(motion.leaving);motion.leaving=nil end
	return motion
end

-- Smooth, signed-off entrance: the mark draws itself like a pen tick, the message
-- wipes in behind the pen, then the check gives one small pop (errors one nudge).
-- Repeats only pop the mark.
function Theme.NotificationFlair(group,label,kind,repeated)
	local row=group:FindFirstChild("Row")
	local motion=stopNotification(group)
	if not row or not motion then return end
	local icon,clip=row:FindFirstChild("Icon"),row:FindFirstChild("TextClip")
	local pop=icon and icon:FindFirstChild("Pop")
	row.Position=UDim2.fromScale(0.5,0.5)
	if Theme.Motion.reduced then return end
	if repeated then
		if pop and icon then
			pop.Scale=1
			chainNotification(group,pop,0,{{0.11,{Scale=1.15}},{0.15,{Scale=1}}})
		end
		return
	end
	-- Draw strokes in order; a check is one continuous pen move, an X two quick ones.
	local total=0
	for _,stroke in motion.strokes do total+=stroke.length end
	local ink,start=0,0
	for index,stroke in motion.strokes do
		local seconds=if kind=="success" then 0.3*stroke.length/math.max(total,1) else 0.17
		local at=if kind=="success" then start else (index-1)*0.15
		stroke.progress.Value=0
		trackNotification(group,stroke.progress,math.max(seconds,0.05),{Value=1},Enum.EasingStyle.Quad,Enum.EasingDirection.InOut,at)
		start+=seconds;ink=math.max(ink,at+seconds)
	end
	if clip then
		local width=motion.clipWidth
		clip.AnchorPoint,clip.Position=Vector2.new(0,0),UDim2.new(0,clip.Position.X.Offset+(if clip.AnchorPoint.X==1 then -width else 0),0,clip.Position.Y.Offset)
		for _,face in clip:GetChildren() do face.AnchorPoint,face.Position=Vector2.new(0,0.5),UDim2.new(0,face.Position.X.Offset,0.5,face.Position.Y.Offset) end
		clip.Size=UDim2.fromOffset(0,clip.Size.Y.Offset)
		trackNotification(group,clip,0.38,{Size=UDim2.fromOffset(width,clip.Size.Y.Offset)},Enum.EasingStyle.Quart,Enum.EasingDirection.Out,ink*0.7)
	end
	local settle=ink*0.7+0.38
	if kind=="error" then
		local sine,inOut=Enum.EasingStyle.Sine,Enum.EasingDirection.InOut
		chainNotification(group,row,settle,{{0.06,{Position=UDim2.new(0.5,6,0.5,0)},sine,inOut},
			{0.08,{Position=UDim2.new(0.5,-3,0.5,0)},sine,inOut},{0.08,{Position=UDim2.fromScale(0.5,0.5)},sine,inOut}})
	elseif pop then
		pop.Scale=1
		chainNotification(group,pop,settle,{{0.12,{Scale=1.12}},{0.16,{Scale=1}}})
	end
end

-- Exit mirrors the entrance: the message wipes away to the right as the row fades.
function Theme.NotificationLeave(group)
	local motion=stopNotification(group)
	local row=group:FindFirstChild("Row")
	local clip=row and row:FindFirstChild("TextClip")
	if not motion or not clip or Theme.Motion.reduced then Theme.Motion:Toast(group,false);return end
	local width=clip.Size.X.Offset
	if clip.AnchorPoint.X~=1 then
		clip.AnchorPoint,clip.Position=Vector2.new(1,0),UDim2.new(0,clip.Position.X.Offset+width,0,clip.Position.Y.Offset)
		for _,face in clip:GetChildren() do
			local offset=face.Position.X.Offset
			face.AnchorPoint,face.Position=Vector2.new(1,0.5),UDim2.new(1,offset-width+face.Size.X.Offset,0.5,face.Position.Y.Offset)
		end
	end
	trackNotification(group,clip,0.3,{Size=UDim2.fromOffset(0,clip.Size.Y.Offset)},Enum.EasingStyle.Quart,Enum.EasingDirection.In)
	motion.leaving=task.delay(0.22,function() motion.leaving=nil;Theme.Motion:Toast(group,false) end)
end

function Theme.Button(parent, name, text, callback, color)
	local button = Instance.new("TextButton")
	button.Name,button.Text,button.Size=name,text,UDim2.fromScale(1,0.15)
	button.BackgroundColor3,button.BackgroundTransparency=color or Theme.ActionColors.navigation,1
	button.TextColor3,button.Font,button.TextSize=Theme.Colors.ink,Theme.Font,23
	-- Caption updates copy this flag; fitting only the caption is undone whenever
	-- the button text or enabled state changes.
	button.TextWrapped,button.TextScaled,button.AutoButtonColor,button.TextTransparency=true,true,false,1
	button.BorderSizePixel,button.Selectable=0,true
	Theme.Round(button,11)
	-- Layout and hitbox stay fixed while only this visual layer squashes or grows.
	local visual=Theme.Frame(button,"Visual",UDim2.fromScale(1,1))
	visual.AnchorPoint,visual.Position,visual.BackgroundTransparency=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),1
	Theme.Stroke(visual,Theme.Arcade.border,Theme.Border.Control)
	local lip=Theme.Frame(visual,"LowerLip",UDim2.fromScale(1,1),Theme.Arcade.border)
	lip.ZIndex=1
	local face=Theme.Frame(visual,"Face",UDim2.fromScale(1,0.93),Color3.new(1,1,1))
	face.ZIndex=2
	Theme.Round(face,10)
	local function recolor()
		local tint=button.BackgroundColor3
		Theme.Gradient(face,tint:Lerp(Palette.Text,if tint==Palette.Card then 0.2 else 0.08),tint)
		lip.BackgroundColor3=tint:Lerp(Theme.Arcade.border,0.62)
	end
	recolor()
	button:GetPropertyChangedSignal("BackgroundColor3"):Connect(recolor)
	Theme.Studs(face,0.07):SetAttribute("StudScaleHeight",1474/116)
	local rim=Theme.Frame(face,"InsetHighlight",UDim2.fromScale(0.96,0.90))
	rim.Position,rim.BackgroundTransparency,rim.ZIndex=UDim2.fromScale(0.02,0.05),1,3
	Theme.Round(rim,7)
	Theme.Stroke(rim,Palette.Text,Theme.Border.Detail).Transparency=0.46
	local caption=Theme.Display(visual,"Caption",text,23)
	caption.Position,caption.Size,caption.TextXAlignment=UDim2.fromScale(0.025,0.075),UDim2.fromScale(0.95,0.8),Enum.TextXAlignment.Center
	caption.ZIndex=5
	local function syncCaption()
		caption.Text,caption.TextSize,caption.Font=button.Text,button.TextSize,button.Font
		caption.TextColor3=if button.Active then button.TextColor3 else Palette.Muted
		caption.TextXAlignment,caption.TextWrapped,caption.TextScaled=button.TextXAlignment,button.TextWrapped,button.TextScaled
	end
	syncCaption()
	for _,property in {"Text","TextSize","Font","TextColor3","TextXAlignment","TextWrapped","TextScaled","Active"} do
		button:GetPropertyChangedSignal(property):Connect(syncCaption)
	end
	Theme.Motion:BindButton(button,visual,face,rim.UIStroke)
	button.Activated:Connect(callback)
	button.Parent=parent
	return button
end

function Theme.Display(parent,name,text,size,color)
	if parent:GetAttribute("LightSurface") then return Theme.Label(parent,name,text,size,color) end
	local label=Theme.Label(parent,name,text,size,color or Theme.Colors.ink)
	label.TextTransparency=1
	label.TextOutline.Enabled=false
	local shadow=Theme.Label(label,"TextShadow",text,size,Theme.Arcade.border)
	local front=Theme.Label(label,"TextFace",text,size,color)
	shadow.Position=UDim2.fromScale(0,0.035)
	shadow.Size,front.Size=UDim2.fromScale(1,1),UDim2.fromScale(1,1)
	local function sync()
		shadow.ZIndex,front.ZIndex=label.ZIndex,label.ZIndex+1
		for _,child in {shadow,front} do
			child.Text,child.Font,child.TextSize=label.Text,label.Font,label.TextSize
			child.TextXAlignment,child.TextYAlignment=label.TextXAlignment,label.TextYAlignment
			child.TextWrapped,child.TextScaled=label.TextWrapped,label.TextScaled
		end
		front.TextColor3=label.TextColor3
	end
	for _,property in {"Text","Font","TextSize","TextColor3","TextXAlignment","TextYAlignment","TextWrapped","TextScaled","ZIndex"} do
		label:GetPropertyChangedSignal(property):Connect(sync)
	end
	sync()
	return label
end

-- Floating HUD art with a radial backdrop; no card face or decorative rim.
function Theme.IconButton(parent,name,text,asset,callback)
	local button=Instance.new("TextButton")
	button.Name,button.Text,button.Size=name,text,UDim2.fromScale(0.1,0.15)
	button.BackgroundTransparency,button.BorderSizePixel,button.TextTransparency=1,0,1
	button.AutoButtonColor,button.Selectable=false,true
	button.Font,button.TextSize,button.TextColor3=Theme.Font,31,Theme.Colors.ink
	local visual=Theme.Frame(button,"Visual",UDim2.fromScale(1,1))
	visual.AnchorPoint,visual.Position,visual.BackgroundTransparency=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),1
	local shade=Theme.Frame(visual,"LabelShade",UDim2.fromScale(160/136,160/132))
	shade.AnchorPoint,shade.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.58)
	shade.BackgroundTransparency,shade.ZIndex=1,1
	-- Circular alpha layers fade in every direction, with no rectangular edge.
	-- Compensate for overlap so the center stays at a light 18% opacity.
	local previousOpacity=0
	for layer=1,40 do
		local t=layer/40
		local opacity=0.18*t*t*(3-2*t)
		local diameter=(41-layer)/41
		local disk=Theme.Frame(shade,"Falloff"..layer,UDim2.fromScale(diameter,diameter),Color3.new(0,0,0))
		disk.AnchorPoint,disk.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
		disk.BackgroundTransparency,disk.ZIndex=1-(opacity-previousOpacity)/(1-previousOpacity),1
		Theme.Round(disk).CornerRadius=UDim.new(0.5,0)
		previousOpacity=opacity
	end
	local icon=Theme.Image(visual,"Icon",asset,UDim2.fromScale(124/136,102/132),UDim2.fromScale(6/136,-2/132))
	local caption=Theme.Label(visual,"Label",text,31)
	caption.Position,caption.Size,caption.TextXAlignment=UDim2.fromScale(0,94/132),UDim2.fromScale(1,36/132),Enum.TextXAlignment.Center
	local function sync()
		caption.Text,caption.TextSize=button.Text,button.TextSize
		caption.TextColor3=if button.Active then button.TextColor3 else Palette.Muted
		icon.ImageTransparency=if button.Active then 0 else 0.5
	end
	for _,property in {"Text","TextSize","TextColor3","Active"} do
		button:GetPropertyChangedSignal(property):Connect(sync)
	end
	sync()
	Theme.Motion:BindButton(button,visual)
	button.Activated:Connect(function() if button.Active then callback() end end)
	button.Parent=parent
	return button
end

function Theme.ActionButton(parent,name,text,callback,color)
	local button=Theme.Button(parent,name,text,callback,color or Theme.Arcade.gold)
	button.TextSize=36
	return button
end

function Theme.PriceButton(parent,name,text,callback,color)
	local button=Theme.ActionButton(parent,name,text,callback,color or Theme.ActionColors.purchase)
	local icon=Theme.Image(button.Visual,"Currency",Theme.Assets.Cash,UDim2.fromScale(0.16,0.72),UDim2.fromScale(0.03,0.1))
	icon.ZIndex=6
	button.Visual.Caption.Position,button.Visual.Caption.Size=UDim2.fromScale(0.2,0.075),UDim2.fromScale(0.77,0.8)
	return button
end

function Theme.SetHeaderColor(header,color)
	local highlight=if color==Palette.Army then color:Lerp(Palette.HeaderHighlight,0.3) else color:Lerp(Palette.Text,0.18)
	Theme.Gradient(header,highlight,color)
end

-- Every popup uses the shared, enlarged width-relative header. Native aspect
-- constraints own resizing; there are no viewport measurements or resize loops.
Theme.HeaderAspect = 1474/116

function Theme.LayoutHeader(header)
	header.AnchorPoint,header.Position,header.Size=Vector2.zero,UDim2.fromScale(0,0),UDim2.fromScale(1,1)
	header.ZIndex=header.Parent.ZIndex+2
	Theme.Aspect(header,Theme.HeaderAspect)
	-- The window owns one continuous contour around the header and content.
	local stroke=Theme.Stroke(header.Parent,Color3.new(),Theme.Border.Shell)
	stroke.BorderStrokePosition=Enum.BorderStrokePosition.Outer
	Theme.Stroke(header,Theme.Arcade.border,Theme.Border.Shell).Enabled=false
	local studs=Theme.Studs(header,0.14,28,0)
	studs.ZIndex=header.ZIndex;studs:SetAttribute("StudScaleWidth",1)
	local rim=header:FindFirstChild("InsetHighlight") or Theme.Container(header,"InsetHighlight")
	Theme.RelativeRect(rim,3,3,1468,109,1474,116)
	rim.ZIndex=header.ZIndex+1
	Theme.Stroke(rim,Palette.Text,Theme.Border.Detail).Transparency=0.46
	local icon=header.PageIcon
	icon.AnchorPoint=Vector2.new(0,0.5)
	icon.Position,icon.Size=UDim2.fromScale(21/1474,0.5),UDim2.fromScale(98/1474,98/116)
	icon.ZIndex=header.ZIndex+2
	Theme.Aspect(icon,1)
	local title=header.Title
	local left=if icon.Visible then 141 else 21
	Theme.RelativeRect(title,left,7,1332-left,102,1474,116)
	title.TextColor3,title.TextXAlignment,title.TextYAlignment=Palette.Text,Enum.TextXAlignment.Left,Enum.TextYAlignment.Center
	title.TextWrapped,title.ZIndex=false,header.ZIndex+3
	title.TextFace.TextOutline.Color,title.TextFace.TextOutline.Thickness=Theme.Arcade.border,0.055
	title.TextShadow.Visible,title.TextShadow.TextTransparency,title.TextShadow.TextOutline.Enabled=true,0.35,false
	local close=header:FindFirstChild("Close")
	if close then
		close.AnchorPoint=Vector2.new(1,0)
		close.Position,close.Size=UDim2.fromScale(1-14/1474,14/116),UDim2.fromScale(92/1474,88/116)
		Theme.Aspect(close,120/115)
		close.ZIndex=header.ZIndex+4
		local visual=close.Visual
		visual.UIStroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
		-- Crop the same header-width sheet inside the smaller close face. The
		-- generic button crop made this control's studs much smaller than its header.
		local closeStuds=Theme.Studs(visual.Face,0.07,28,0)
		closeStuds:SetAttribute("StudScaleWidth",1474/92)
		visual.ZIndex,visual.LowerLip.ZIndex,visual.Face.ZIndex=close.ZIndex,close.ZIndex,close.ZIndex+1
		closeStuds.ZIndex=close.ZIndex+1
		visual.Face.InsetHighlight.ZIndex,visual.Caption.ZIndex=close.ZIndex+2,close.ZIndex+3
	end
	Theme.ScaleText(header)
end

function Theme.HeaderClose(header,callback)
	local close=Theme.ActionButton(header,"Close","X",callback,Theme.ActionColors.danger)
	Theme.ApplyReferenceAccent(close,ColorSequence.new(Color3.fromRGB(255,102,84),Color3.fromRGB(243,36,59)))
	Theme.LayoutHeader(header)
	return close
end

-- Join the shared header directly to its body in native Scale coordinates.
-- Only authored aspect ratios are used; body contents retain their own layout.
function Theme.BelowHeader(header,body,bottom)
	Theme.LayoutHeader(header)
	local parent=header.Parent
	local aspect
	while parent and not aspect do
		aspect=parent:FindFirstChildWhichIsA("UIAspectRatioConstraint")
		parent=parent.Parent
	end
	assert(aspect,"A popup needs its authored UIAspectRatioConstraint")
	local top=aspect.AspectRatio/Theme.HeaderAspect
	local height=(bottom or 1)-top
	body.Position=UDim2.fromScale(body.Position.X.Scale,top+height*body.AnchorPoint.Y)
	body.Size=UDim2.fromScale(body.Size.X.Scale,height)
	body:SetAttribute("PopupBody",true)
	-- Painted bodies meet the shell edges; transparent content containers keep
	-- their authored insets. Surface also applies this when called afterward.
	if body.BackgroundTransparency<1 or body:FindFirstChildWhichIsA("UIStroke") then
		alignPopupBody(body)
	end
end

function Theme.Header(parent,name,title,color)
	local header=Theme.Frame(parent,name,UDim2.fromScale(1,1),Color3.new(1,1,1))
	Theme.SetHeaderColor(header,color)
	local text=Theme.Display(header,"Title",title,50)
	local icon=Theme.Image(header,"PageIcon",Theme.Assets.Army,UDim2.fromScale(1,1))
	icon.Visible=false
	Theme.LayoutHeader(header)
	return header,text
end

function Theme.Card(parent,name,size,color)
	local card=Theme.Frame(parent,name,size,Color3.new(1,1,1))
	card.BackgroundTransparency=0
	card:SetAttribute("LightSurface",true)
	card.ClipsDescendants=true
	Theme.Gradient(card,Palette.Card:Lerp(Palette.Text,0.2),Palette.Card)
	local rim=Theme.Stroke(card,Color3.new(1,1,1),4)
	Theme.Gradient(rim,color:Lerp(Palette.Text,0.12),color)
	local rays=Theme.Image(card,"IconRays",Theme.Assets.Rays,UDim2.fromScale(0.96,0.65),UDim2.fromScale(0.02,0.15))
	rays.ImageColor3,rays.ImageTransparency,rays.ZIndex=color,0.76,1
	return card
end

function Theme.CollectionCard(parent,name,callback,rarity,selected)
	local card=Theme.Button(parent,name,"",callback,Palette.Card)
	card.Visual:SetAttribute("LightSurface",true)
	-- Keep the dark outside contour; selection and rarity use the inner rim.
	Theme.Stroke(card.Visual.Face,if selected then Theme.ActionColors.selected else rarity or Palette.Line,if selected then 4 else 2)
	return card
end

-- One compact formatter for prices and stats: about three significant figures
-- with K/M/B/T (2,880 → 2.88K, 725,760 → 726K, 3,628,800 → 3.63M, 1.2e9 → 1.2B).
local SUFFIXES={"","K","M","B","T"}
local function significant(x)
	if x<=0 then return 0,0 end
	local decimals=math.clamp(2-math.floor(math.log10(x)),0,3)
	local scale=10^decimals
	return math.round(x*scale)/scale,decimals
end
function Theme.Number(value)
	value=value or 0
	if value~=value or value==math.huge or value==-math.huge then return "0" end
	local sign=if value<0 then "-" else ""
	local n,index=math.abs(value),1
	while n>=1000 and index<#SUFFIXES do n/=1000;index+=1 end
	local rounded,decimals=significant(n)
	if rounded>=1000 and index<#SUFFIXES then rounded,decimals=significant(rounded/1000);index+=1 end
	local text=string.format("%."..decimals.."f",rounded)
	if decimals>0 then text=text:gsub("0+$",""):gsub("%.$","") end
	if text=="0" then sign="" end
	return sign..text..SUFFIXES[index]
end

-- "1 egg/s" but "2 eggs/s": singular only when the shown number is exactly 1.
function Theme.Count(value,singular,plural)
	local text=Theme.Number(value)
	return text.." "..(if text=="1" then singular else plural)
end

-- Currency has whole coins. Keep exact prices readable instead of abbreviating
-- them to decimals; the floor also hides fractional frames in wallet tweens.
function Theme.Money(value)
	local whole=math.floor(value or 0)
	local digits=string.format("%.0f",math.abs(whole))
	local grouped=(digits:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,",""))
	return (if whole<0 then "-" else "")..grouped
end

function Theme.SegmentedBar(parent,name,size,segments)
	local track=Theme.Frame(parent,name,size,Theme.Arcade.border)
	Theme.Round(track,7);Theme.Stroke(track,Theme.Arcade.border,3)
	local inside=Theme.Frame(track,"Inside",UDim2.fromScale(0.97,0.87),Theme.Colors.dark)
	inside.Position,inside.ClipsDescendants=UDim2.fromScale(0.015,0.065),true
	Theme.Round(inside,3)
	local fill=Theme.Frame(inside,"Fill",UDim2.fromScale(0,1),Theme.Arcade.red)
	Theme.Round(fill,3)
	Theme.Gradient(fill,Color3.new(1,1,1),Color3.fromRGB(224,224,224))
	local count=segments or 5
	for i=1,count-1 do
		local line=Instance.new("Frame")
		line.Name,line.Size,line.Position="Segment"..i,UDim2.fromScale(0.006,1),UDim2.fromScale(i/count,0)
		line.BackgroundColor3,line.BorderSizePixel,line.ZIndex,line.Parent=Theme.Arcade.border,0,2,inside
	end
	return track,fill
end

-- Primary navigation colors also carry through to their menu headers.
Theme.PageColors.Army = Color3.fromRGB(0, 255, 102)
Theme.PageColors.Upgrades = Color3.fromRGB(0, 221, 255)
Theme.HeaderColors.Army = Theme.PageColors.Army
Theme.HeaderColors.Upgrades = Theme.PageColors.Upgrades

-- Popup presentation is applied after rendering so page-specific fills cannot restore old colors.
function Theme.ApplyPopupStyle(panel)
	if not panel then return end
	local window=panel:FindFirstChild("StandardPage") or panel:FindFirstChild("Window") or panel
	local header=window:FindFirstChild("Header")
	local body=window:FindFirstChild("Main") or window:FindFirstChild("Body")
	if header then
		local studs=Theme.Studs(header,0.14,28,0)
	studs.ZIndex=header.ZIndex;studs:SetAttribute("StudScaleWidth",1)
		for _,name in {"Title","PageIcon","Close"} do
			local foreground=header:FindFirstChild(name)
			if foreground and foreground:IsA("GuiObject") then
				foreground.ZIndex=math.max(foreground.ZIndex,header.ZIndex+1)
			end
		end
	end
	local function darkSurface(item,isBody)
		item.BackgroundColor3,item.BackgroundTransparency=Color3.new(1,1,1),0
		local gradient=item:FindFirstChildWhichIsA("UIGradient") or Instance.new("UIGradient")
		gradient.Color=ColorSequence.new(Theme.OverlayColors.Top,Theme.OverlayColors.Bottom)
		gradient.Transparency=NumberSequence.new({
			-- Near-opaque so the bright world never tints the body olive; every popup matches.
			NumberSequenceKeypoint.new(0,if isBody then 0.06 else 0.62),
			NumberSequenceKeypoint.new(1,if isBody then 0.16 else 0.80),
		})
		gradient.Rotation,gradient.Parent=90,item
		local rim=item:FindFirstChild("InnerRim")
		if rim and rim:IsA("GuiObject") then rim.Visible=false end
		local stroke=item:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			if isBody then
				stroke.Color,stroke.Transparency,stroke.Thickness=Color3.fromRGB(6,8,9),0.12,3
			else
				stroke.Transparency=math.max(stroke.Transparency,0.42)
				stroke.Thickness=math.min(stroke.Thickness,2)
			end
		end
	end
	local protected={
		Fill=true,ProgressFill=true,Rarity=true,RarityBadge=true,
		Badge=true,SelectionOutline=true,InnerRim=true,
	}
	local function content(item)
		if item==header or item:GetAttribute("OwnsPopupStyle")==true then return end
		if protected[item.Name] or item:IsA("ViewportFrame") then return end
		-- Action-button visuals and their captions retain their authored colors.
		if item:IsA("GuiButton") and (item:FindFirstChild("Visual") or item.Name=="Buy") then return end
		if item:IsA("Frame") or item:IsA("GuiButton") then
			if item.BackgroundTransparency<1 or item:FindFirstChildWhichIsA("UIGradient") then
				darkSurface(item,item==body)
			end
		elseif item:IsA("TextLabel") and item.Name~="TextShadow" then
			local _,_,value=item.TextColor3:ToHSV()
			if value<0.7 then
				item.TextColor3=if item.Name=="Title" or item.Name=="Current"
					then Color3.fromRGB(255,255,255) else Color3.fromRGB(224,230,233)
			end
		elseif item:IsA("TextBox") then
			item.BackgroundColor3,item.BackgroundTransparency=Color3.fromRGB(8,10,12),0.28
			item.TextColor3,item.PlaceholderColor3=Color3.fromRGB(245,248,250),Color3.fromRGB(172,185,192)
		elseif item:IsA("ImageLabel") and item.Name=="IconRays" then
			item.ImageTransparency=math.max(item.ImageTransparency,0.9)
		end
		for _,child in item:GetChildren() do content(child) end
	end
	for _,child in panel:GetChildren() do
		if child~=header then content(child) end
	end
end

-- Reference PNG sampled in sRGB after converting its Display P3 profile.
-- Preserve these gradients directly; do not run them through a palette filter.
function Theme.ToneAccent(color)
	return color
end

Theme.ReferenceGradients={
	Base=ColorSequence.new({
		ColorSequenceKeypoint.new(0.000000,Color3.fromRGB(255,217,0)),
		ColorSequenceKeypoint.new(0.041237,Color3.fromRGB(255,213,0)),
		ColorSequenceKeypoint.new(0.092784,Color3.fromRGB(255,210,0)),
		ColorSequenceKeypoint.new(0.195876,Color3.fromRGB(255,202,0)),
		ColorSequenceKeypoint.new(0.298969,Color3.fromRGB(255,194,1)),
		ColorSequenceKeypoint.new(0.402062,Color3.fromRGB(255,186,0)),
		ColorSequenceKeypoint.new(0.505155,Color3.fromRGB(255,178,2)),
		ColorSequenceKeypoint.new(0.608247,Color3.fromRGB(255,170,1)),
		ColorSequenceKeypoint.new(0.711340,Color3.fromRGB(255,162,2)),
		ColorSequenceKeypoint.new(0.814433,Color3.fromRGB(255,155,0)),
		ColorSequenceKeypoint.new(0.917526,Color3.fromRGB(255,147,1)),
		ColorSequenceKeypoint.new(0.979381,Color3.fromRGB(255,142,0)),
		ColorSequenceKeypoint.new(1.000000,Color3.fromRGB(255,140,0)),
	}),
	Army=ColorSequence.new({
		ColorSequenceKeypoint.new(0.000000,Color3.fromRGB(176,255,1)),
		ColorSequenceKeypoint.new(0.009346,Color3.fromRGB(173,254,0)),
		ColorSequenceKeypoint.new(0.037383,Color3.fromRGB(169,253,0)),
		ColorSequenceKeypoint.new(0.074766,Color3.fromRGB(164,252,0)),
		ColorSequenceKeypoint.new(0.168224,Color3.fromRGB(149,250,1)),
		ColorSequenceKeypoint.new(0.261682,Color3.fromRGB(136,246,0)),
		ColorSequenceKeypoint.new(0.355140,Color3.fromRGB(122,243,1)),
		ColorSequenceKeypoint.new(0.448598,Color3.fromRGB(107,240,0)),
		ColorSequenceKeypoint.new(0.542056,Color3.fromRGB(93,238,0)),
		ColorSequenceKeypoint.new(0.635514,Color3.fromRGB(77,235,0)),
		ColorSequenceKeypoint.new(0.728972,Color3.fromRGB(63,232,0)),
		ColorSequenceKeypoint.new(0.822430,Color3.fromRGB(49,229,1)),
		ColorSequenceKeypoint.new(0.915888,Color3.fromRGB(36,226,2)),
		ColorSequenceKeypoint.new(0.981308,Color3.fromRGB(26,224,1)),
		ColorSequenceKeypoint.new(1.000000,Color3.fromRGB(23,223,0)),
	}),
	Upgrades=ColorSequence.new({
		ColorSequenceKeypoint.new(0.000000,Color3.fromRGB(3,253,255)),
		ColorSequenceKeypoint.new(0.010417,Color3.fromRGB(0,252,255)),
		ColorSequenceKeypoint.new(0.041667,Color3.fromRGB(2,249,255)),
		ColorSequenceKeypoint.new(0.083333,Color3.fromRGB(2,245,255)),
		ColorSequenceKeypoint.new(0.187500,Color3.fromRGB(1,234,255)),
		ColorSequenceKeypoint.new(0.291667,Color3.fromRGB(0,225,255)),
		ColorSequenceKeypoint.new(0.395833,Color3.fromRGB(0,215,255)),
		ColorSequenceKeypoint.new(0.500000,Color3.fromRGB(4,205,255)),
		ColorSequenceKeypoint.new(0.604167,Color3.fromRGB(3,195,255)),
		ColorSequenceKeypoint.new(0.708333,Color3.fromRGB(2,185,255)),
		ColorSequenceKeypoint.new(0.812500,Color3.fromRGB(2,175,255)),
		ColorSequenceKeypoint.new(0.916667,Color3.fromRGB(1,164,255)),
		ColorSequenceKeypoint.new(0.979167,Color3.fromRGB(0,159,255)),
		ColorSequenceKeypoint.new(1.000000,Color3.fromRGB(0,157,255)),
	}),
}
Theme.ReferenceColors={
	Base=Color3.fromRGB(255,178,2),
	Army=Color3.fromRGB(99,239,0),
	Upgrades=Color3.fromRGB(4,205,255),
}
for name,color in Theme.ReferenceColors do
	Theme.PageColors[name]=color
	Theme.HeaderColors[name]=color
end
-- DESIGN.md: Settings is neutral, not an Upgrades-cyan page.
Theme.HeaderColors.Settings=Color3.fromRGB(82,102,90)
Theme.NavigationColors.HotPink=Theme.ReferenceColors.Base
Theme.NavigationColors.Orange=Theme.ReferenceColors.Base
Theme.NavigationColors.Cyan=Theme.ReferenceColors.Upgrades
Theme.Arcade.gold,Theme.Arcade.sell=Theme.ReferenceColors.Base,Theme.ReferenceColors.Base
Theme.Arcade.green,Theme.Arcade.army=Theme.ReferenceColors.Army,Theme.ReferenceColors.Army
Theme.Arcade.blue=Theme.ReferenceColors.Upgrades
Theme.ActionColors.purchase,Theme.ActionColors.navigation=Theme.ReferenceColors.Army,Theme.ReferenceColors.Upgrades
Theme.ActionColors.selected,Theme.ActionColors.sell=Theme.ReferenceColors.Base,Theme.ReferenceColors.Base
Theme.Colors.gold,Theme.Colors.green,Theme.Colors.blue=Theme.ReferenceColors.Base,Theme.ReferenceColors.Army,Theme.ReferenceColors.Upgrades
Theme.AccentPaletteVersion=4

local function referenceGradient(color)
	for name,reference in Theme.ReferenceColors do
		if color==reference then return Theme.ReferenceGradients[name] end
	end
	return nil
end

function Theme.ApplyReferenceAccent(item,sequence)
	if not item or not sequence then return end
	local visual=item:FindFirstChild("Visual")
	local face=if visual then visual:FindFirstChild("Face") else item
	if not face or not face:IsA("GuiObject") then return end
	face.BackgroundColor3,face.BackgroundTransparency=Color3.new(1,1,1),0
	local gradient=face:FindFirstChildWhichIsA("UIGradient") or Instance.new("UIGradient")
	gradient.Color,gradient.Transparency=sequence,NumberSequence.new(0)
	gradient.Rotation,gradient.Offset,gradient.Enabled=90,Vector2.new(0,0),true
	gradient.Parent=face
	local outline=(visual or item):FindFirstChildWhichIsA("UIStroke")
	if outline then outline.Color=Color3.new(0,0,0) end
	if visual then
		local lip=visual:FindFirstChild("LowerLip")
		if lip and lip:IsA("GuiObject") then
			lip.BackgroundColor3=sequence.Keypoints[#sequence.Keypoints].Value
		end
	end
end

local referenceActionButton=Theme.ActionButton
function Theme.ActionButton(parent,name,text,callback,color,...)
	local button=referenceActionButton(parent,name,text,callback,color,...)
	local sequence=referenceGradient(color)
	if parent and parent.Name=="Navigation" then
		sequence=Theme.ReferenceGradients[name] or sequence
	end
	Theme.ApplyReferenceAccent(button,sequence)
	return button
end

local referenceHeader=Theme.Header
function Theme.Header(parent,name,text,color,...)
	local results=table.pack(referenceHeader(parent,name,text,color,...))
	Theme.ApplyReferenceAccent(results[1],referenceGradient(color))
	return table.unpack(results,1,results.n)
end

local referenceSetHeaderColor=Theme.SetHeaderColor
function Theme.SetHeaderColor(header,color,...)
	local results=table.pack(referenceSetHeaderColor(header,color,...))
	Theme.ApplyReferenceAccent(header,referenceGradient(color))
	return table.unpack(results,1,results.n)
end

return Theme
