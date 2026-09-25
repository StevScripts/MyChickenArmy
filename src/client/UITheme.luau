--!strict
-- Country screenshot vocabulary. This module owns presentation, never game state.
local Theme = {}
local Palette = require(game:GetService("ReplicatedStorage").PetRoll.Shared.UIColors)
Theme.Motion = require(script.Parent.UIMotion).new()
Theme.Font = Enum.Font.SourceSansBold
Theme.Arcade = {
	blue=Palette.Navigation, gold=Palette.Rewards, purple=Palette.Upgrade,
	red=Palette.Danger, green=Palette.Purchase, border=Palette.Border,
	army=Palette.Army, sell=Palette.Sell,
}
Theme.Colors = {
	ink=Palette.Text, muted=Palette.Muted,
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
	Settings=Theme.Arcade.blue, Test=Theme.Arcade.blue, Odds=Theme.NavigationColors.Orange, Recruits=Theme.NavigationColors.Orange,
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
-- Opt-in cash affordability feedback for the yard and egg-collection upgrades.
Theme.UnaffordableGradient = ColorSequence.new(Color3.fromRGB(166,166,166),Color3.fromRGB(92,92,92))
Theme.Assets = {
	Cash="rbxassetid://101788696120931", Studs="rbxassetid://93331178043153",
	Rays="rbxassetid://120904904160174", Multiplier="rbxassetid://124712149166140",
	Army="rbxassetid://100291580520125", Luck="rbxassetid://111087925336083",
	Shop="rbxassetid://119358432410091", Index="rbxassetid://96489791857751", EggMagnet="rbxassetid://131332157337305",
}
Theme.Rarities = Palette.Rarities
-- Background-free simulator feedback: bold status-colored text and a clear outline.
Theme.NotificationStyles = {
	success={symbol="✓",color=Color3.fromRGB(112,222,98)},
	error={symbol="×",color=Color3.fromRGB(255,120,132)},
	warning={symbol="!",color=Color3.fromRGB(244,194,71)},
	info={symbol="i",color=Theme.Arcade.blue:Lerp(Palette.Text,0.35)},
	pending={symbol="…",color=Palette.Muted},
}

function Theme.SetNotification(label, text, kind)
	local style=Theme.NotificationStyles[kind] or Theme.NotificationStyles.info
	-- Names remain literal; color the full message so status reads at a glance.
	local escaped=text:gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")
	label.TextColor3=style.color
	label.Text=style.symbol.."  "..escaped
	label:SetAttribute("PlainText",style.symbol.."  "..text)
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
	local pixels=spacing or pattern:GetAttribute("StudSpacing") or pattern.TileSize.X.Offset
	pattern:SetAttribute("StudSpacing",if type(pixels)=="number" and pixels>0 then pixels else 28)
	pattern.Image,pattern.ScaleType=Theme.Assets.Studs,Enum.ScaleType.Stretch
	pattern.ImageRectOffset,pattern.ImageRectSize=Vector2.zero,Vector2.zero
	pattern.Position,pattern.AnchorPoint,pattern.Rotation=UDim2.new(),Vector2.zero,0
	pattern.BackgroundTransparency,pattern.BorderSizePixel,pattern.Active=1,0,false
	if studBindings[pattern] then return pattern end
	local function resize()
		-- AbsoluteSize includes ancestor UIScales; offset sizes must use local pixels.
		local scale=1
		local ancestor: Instance?=clip
		while ancestor do
			if ancestor:IsA("GuiObject") then
				for _,child in ancestor:GetChildren() do
					if child:IsA("UIScale") then scale*=child.Scale end
				end
			end
			ancestor=ancestor.Parent
		end
		local size=clip.AbsoluteSize/math.max(scale,0.001)
		local relativeWidth=pattern:GetAttribute("StudScaleWidth")
		if type(relativeWidth)=="number" and relativeWidth>0 then
			-- Opt-in for fully scale-authored surfaces; keep the cropped sheet square.
			local side=math.max(size.X*relativeWidth,size.X,size.Y)
			pattern.Size=UDim2.fromScale(side/math.max(size.X,0.001),side/math.max(size.Y,0.001))
			return
		end
		local side=math.max((pattern:GetAttribute("StudSpacing") or 28)*24,size.X,size.Y)
		pattern.Size=UDim2.fromOffset(side,side)
	end
	local function layer()
		clip.ZIndex,clip.Visible=pattern.ZIndex,pattern.Visible
	end
	local connections={
		clip:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize),
		pattern.AncestryChanged:Connect(resize),
		pattern:GetAttributeChangedSignal("StudSpacing"):Connect(resize),
		pattern:GetAttributeChangedSignal("StudScaleWidth"):Connect(resize),
		pattern:GetPropertyChangedSignal("ZIndex"):Connect(layer),
		pattern:GetPropertyChangedSignal("Visible"):Connect(layer),
	}
	studBindings[pattern]=connections
	table.insert(connections,pattern.Destroying:Connect(function()
		for _,connection in connections do connection:Disconnect() end
		studBindings[pattern]=nil
	end))
	resize()
	layer()
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
	bounds.Size,bounds.Position=UDim2.new(1,-padding*2,1,-padding*2),UDim2.fromOffset(padding,padding)
	pattern.ImageTransparency, pattern.ZIndex = 1-(opacity or 0.14), 2
	return pattern
end

function Theme.Surface(item, tint)
	tint = tint or Theme.Colors.panel
	item.BackgroundColor3, item.BackgroundTransparency = Color3.new(1,1,1), 0
	Theme.Gradient(item,tint:Lerp(Palette.Text,0.035),tint)
	Theme.Stroke(item,Theme.Arcade.border,3)
	local inset=item:FindFirstChild("InnerRim") or Theme.Frame(item,"InnerRim",UDim2.new(1,-10,1,-10))
	inset.Position,inset.BackgroundTransparency=UDim2.fromOffset(5,5),1
	Theme.Stroke(inset,Theme.Colors.line,1.5)
	return item
end

function Theme.Label(parent, name, text, size, color)
	local lightSurface = parent:GetAttribute("LightSurface") == true
	local label = Instance.new("TextLabel")
	label.Name, label.Text = name, text
	label.Size, label.BackgroundTransparency = UDim2.new(1,0,0,28), 1
	label.Font, label.TextSize = Theme.Font, size or 20
	label.TextColor3 = color or (if lightSurface then Theme.Colors.cardInk else Theme.Colors.ink)
	label.TextXAlignment, label.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Center
	label.TextWrapped, label.TextStrokeTransparency, label.ZIndex = true, 1, 4
	local outline=Instance.new("UIStroke")
	outline.Name,outline.Color,outline.Thickness="TextOutline",Theme.Arcade.border,math.clamp((size or 20)*0.068,1.25,4)
	outline.Enabled = not lightSurface
	outline.Parent=label
	label:GetPropertyChangedSignal("TextSize"):Connect(function()
		outline.Thickness=label:GetAttribute("OutlineThickness") or math.clamp(label.TextSize*0.068,1.25,4)
	end)
	label.Parent = parent
	return label
end

function Theme.Notification(parent)
	local group=Instance.new("CanvasGroup")
	group.Name,group.Size="Notification",UDim2.fromOffset(720,80)
	group.BackgroundTransparency,group.BorderSizePixel=1,0
	group.Active,group.Visible,group.ZIndex=false,false,20
	group.AnchorPoint,group.Position=Vector2.new(0.5,1),UDim2.fromScale(0.5,0.24)
	group.Parent=parent
	local label=Theme.Label(group,"Toast","",34,Theme.Colors.ink)
	label:SetAttribute("OutlineThickness",3)
	label.TextOutline.Thickness=3
	label.Position,label.Size=UDim2.fromOffset(12,8),UDim2.new(1,-24,1,-16)
	label.RichText,label.TextXAlignment,label.TextYAlignment=true,Enum.TextXAlignment.Center,Enum.TextYAlignment.Center
	label.Active=false
	return group,label
end

function Theme.Button(parent, name, text, callback, color)
	local button = Instance.new("TextButton")
	button.Name,button.Text,button.Size=name,text,UDim2.new(1,0,0,46)
	button.BackgroundColor3,button.BackgroundTransparency=color or Theme.ActionColors.navigation,1
	button.TextColor3,button.Font,button.TextSize=Theme.Colors.ink,Theme.Font,23
	button.TextWrapped,button.AutoButtonColor,button.TextTransparency=true,false,1
	button.BorderSizePixel,button.Selectable=0,true
	Theme.Round(button,11)
	-- Layout and hitbox stay fixed while only this visual layer squashes or grows.
	local visual=Theme.Frame(button,"Visual",UDim2.fromScale(1,1))
	visual.AnchorPoint,visual.Position,visual.BackgroundTransparency=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),1
	Theme.Stroke(visual,Theme.Arcade.border,3)
	local lip=Theme.Frame(visual,"LowerLip",UDim2.fromScale(1,1),Theme.Arcade.border)
	lip.ZIndex=1
	local face=Theme.Frame(visual,"Face",UDim2.new(1,0,1,-5),Color3.new(1,1,1))
	face.ZIndex=2
	Theme.Round(face,10)
	local function recolor()
		local tint=button.BackgroundColor3
		Theme.Gradient(face,tint:Lerp(Palette.Text,if tint==Palette.Card then 0.2 else 0.08),tint)
		lip.BackgroundColor3=tint:Lerp(Theme.Arcade.border,0.62)
	end
	recolor()
	button:GetPropertyChangedSignal("BackgroundColor3"):Connect(recolor)
	Theme.Studs(face)
	local rim=Theme.Frame(face,"InsetHighlight",UDim2.new(1,-7,1,-7))
	rim.Position,rim.BackgroundTransparency,rim.ZIndex=UDim2.fromOffset(3.5,3.5),1,3
	Theme.Round(rim,7)
	Theme.Stroke(rim,Palette.Text,1.5).Transparency=0.46
	local caption=Theme.Display(visual,"Caption",text,23)
	caption.Position,caption.Size,caption.TextXAlignment=UDim2.fromOffset(6,-2),UDim2.new(1,-12,1,-3),Enum.TextXAlignment.Center
	caption.ZIndex=5
	local function syncCaption()
		caption.Text,caption.TextSize,caption.Font=button.Text,button.TextSize,button.Font
		caption.TextColor3=if button.Active then button.TextColor3 else Palette.Muted
		caption.TextXAlignment,caption.TextWrapped=button.TextXAlignment,button.TextWrapped
	end
	syncCaption()
	for _,property in {"Text","TextSize","Font","TextColor3","TextXAlignment","TextWrapped","Active"} do
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
	shadow.Position=UDim2.fromOffset(0,2)
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
	button.Name,button.Text,button.Size=name,text,UDim2.fromOffset(136,132)
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
	local icon=Theme.Image(button.Visual,"Currency",Theme.Assets.Cash,UDim2.fromOffset(44,42),UDim2.new(0,8,0.5,-23))
	icon.ZIndex=6
	button.Visual.Caption.Position,button.Visual.Caption.Size=UDim2.fromOffset(55,-2),UDim2.new(1,-65,1,-3)
	return button
end

function Theme.SetHeaderColor(header,color)
	local highlight=if color==Palette.Army then color:Lerp(Palette.HeaderHighlight,0.3) else color:Lerp(Palette.Text,0.18)
	Theme.Gradient(header,highlight,color)
end

function Theme.Header(parent,name,title,color)
	local header=Theme.Frame(parent,name,UDim2.new(1,0,0,84),Color3.new(1,1,1))
	Theme.SetHeaderColor(header,color)
	Theme.Stroke(header,Theme.Arcade.border,4)
	Theme.Studs(header,0.14,28,0).ZIndex=header.ZIndex
	local text=Theme.Display(header,"Title",title,50)
	text.Position,text.Size=UDim2.fromOffset(24,0),UDim2.new(1,-132,1,0)
	local icon=Theme.Image(header,"PageIcon",Theme.Assets.Army,UDim2.fromOffset(78,78),UDim2.fromOffset(12,1))
	icon.Visible=false
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
	local rays=Theme.Image(card,"IconRays",Theme.Assets.Rays,UDim2.new(1,-12,0,190),UDim2.fromOffset(6,44))
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

function Theme.Number(value)
	value=value or 0
	if value>=1000000 then return string.format("%.1fm",value/1000000) end
	if value>=10000 then return string.format("%.1fk",value/1000) end
	if value==math.floor(value) then return tostring(math.floor(value)) end
	return string.format("%.1f",value)
end

-- Currency has whole coins. Keep exact prices readable instead of abbreviating
-- them to decimals; the floor also hides fractional frames in wallet tweens.
function Theme.Money(value)
	local whole=math.floor(value or 0)
	local digits=string.format("%.0f",math.abs(whole))
	local grouped=(digits:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,",""))
	return (if whole<0 then "-" else "")..grouped
end

function Theme.SegmentedBar(parent,name,size)
	local track=Theme.Frame(parent,name,size,Theme.Arcade.border)
	Theme.Round(track,7);Theme.Stroke(track,Theme.Arcade.border,3)
	local inside=Theme.Frame(track,"Inside",UDim2.new(1,-8,1,-8),Theme.Colors.dark)
	inside.Position,inside.ClipsDescendants=UDim2.fromOffset(4,4),true
	Theme.Round(inside,3)
	local fill=Theme.Frame(inside,"Fill",UDim2.fromScale(0,1),Theme.Arcade.red)
	Theme.Round(fill,3)
	Theme.Gradient(fill,Color3.new(1,1,1),Color3.fromRGB(224,224,224))
	for i=1,4 do
		local line=Instance.new("Frame")
		line.Name,line.Size,line.Position="Segment"..i,UDim2.new(0,3,1,0),UDim2.fromScale(i/5,0)
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
	local header=panel:FindFirstChild("Header")
	if header then
		Theme.Studs(header,0.14,28,0).ZIndex=header.ZIndex
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
		gradient.Color=ColorSequence.new(Color3.fromRGB(20,22,24),Color3.fromRGB(3,4,5))
		gradient.Transparency=NumberSequence.new({
			NumberSequenceKeypoint.new(0,if isBody then 0.24 else 0.62),
			NumberSequenceKeypoint.new(1,if isBody then 0.48 else 0.80),
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
		if item:GetAttribute("OwnsPopupStyle")==true then return end
		if protected[item.Name] or item:IsA("ViewportFrame") then return end
		-- Action-button visuals and their captions retain their authored colors.
		if item:IsA("GuiButton") and (item:FindFirstChild("Visual") or item.Name=="Buy") then return end
		if item:IsA("Frame") or item:IsA("GuiButton") then
			if item.BackgroundTransparency<1 or item:FindFirstChildWhichIsA("UIGradient") then
				darkSurface(item,item==panel:FindFirstChild("Body"))
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
