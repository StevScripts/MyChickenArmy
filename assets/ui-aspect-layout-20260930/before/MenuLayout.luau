--!strict
-- Studio-owned Frames are the saved sizing controls. Client code never rewrites them.
local Layout={}
-- September 29 reference screenshot: one composition, uniformly scaled on every device.
Layout.ArmyCanvas=Vector2.new(1274,876)

function Layout.FitArmy(width,height)
	local scale=math.max(0.001,math.min(width/Layout.ArmyCanvas.X,height/Layout.ArmyCanvas.Y))
	return Layout.ArmyCanvas.X*scale,Layout.ArmyCanvas.Y*scale,scale
end
Layout.Names={Army="MyArmy",Shop="Shop",Index="Index",Upgrades="Upgrades",Settings="Settings",Odds="Odds",Merge="Fuse",Offline="OfflineEarnings"}
Layout.Defaults={
	Army={size=Vector2.new(0.54,0.82),maximum=Vector2.new(1100,780)},
	Shop={size=Vector2.new(0.64,0.80),maximum=Vector2.new(900,680)},
	Index={size=Vector2.new(0.66,0.80),maximum=Vector2.new(940,680)},
	Upgrades={size=Vector2.new(0.67,0.80),maximum=Vector2.new(950,660)},
	Settings={size=Vector2.new(0.46,0.80),maximum=Vector2.new(640,620)},
	Odds={size=Vector2.new(0.46,0.70),maximum=Vector2.new(640,560)},
	Merge={size=Vector2.new(0.39,0.82),maximum=Vector2.new(760,760)},
	Offline={size=Vector2.new(0.38,0.64),maximum=Vector2.new(520,440)},
}

function Layout.Control(gui,page)
	local folder=gui:FindFirstChild("MenuLayouts")
	return folder and folder:FindFirstChild(Layout.Names[page] or page)
end

function Layout.Number(gui,page,name,fallback,minimum,maximum)
	local control=Layout.Control(gui,page)
	local value=control and control:GetAttribute(name)
	return if type(value)=="number" and value==value then math.clamp(value,minimum,maximum) else fallback
end

function Layout.Size(gui,page,available)
	local definition=Layout.Defaults[page] or Layout.Defaults.Settings
	local control=Layout.Control(gui,page)
	local size=if control and control:IsA("GuiObject") then control.Size else UDim2.fromScale(definition.size.X,definition.size.Y)
	if available.X<900 or available.Y<550 then
		local compact=control and control:GetAttribute("CompactSize")
		if typeof(compact)~="Vector2" then compact=Vector2.new(0.94,0.92) end
		size=UDim2.fromScale(compact.X,compact.Y)
	end
	local limit=control and control:FindFirstChildWhichIsA("UISizeConstraint")
	local maximum=if limit then limit.MaxSize else definition.maximum
	local minimum=if limit then limit.MinSize else Vector2.new(300,240)
	local width=math.clamp(available.X*size.X.Scale+size.X.Offset,minimum.X,math.max(minimum.X,maximum.X))
	local height=math.clamp(available.Y*size.Y.Scale+size.Y.Offset,minimum.Y,math.max(minimum.Y,maximum.Y))
	width,height=math.max(1,math.min(width,available.X-24)),math.max(1,math.min(height,available.Y-24))
	if page=="Army" then return Layout.FitArmy(width,height) end
	return width,height
end

-- Used only by the Edit-mode authoring tool. Existing user values are preserved.
function Layout.CreateControls(gui)
	local folder=gui:FindFirstChild("MenuLayouts")
	if not folder then
		folder=Instance.new("Frame")
		folder.Name,folder.Size,folder.BackgroundTransparency="MenuLayouts",UDim2.fromScale(1,1),1
		folder.BorderSizePixel,folder.Parent=0,gui
		folder:SetAttribute("PreviewMenu","MyArmy")
	end
	for page,name in Layout.Names do
		if folder:FindFirstChild(name) then continue end
		local definition=Layout.Defaults[page]
		local frame=Instance.new("Frame")
		frame.Name,frame.Size=name,UDim2.fromScale(definition.size.X,definition.size.Y)
		frame.Position,frame.AnchorPoint=UDim2.fromScale(0.5,0.5),Vector2.new(0.5,0.5)
		frame.BackgroundTransparency,frame.BorderSizePixel,frame.Visible=1,0,false
		frame:SetAttribute("CompactSize",Vector2.new(0.94,0.92))
		frame:SetAttribute("EditHelp","Size.X.Scale = width; Size.Y.Scale = height. SizeLimits caps large screens. CompactSize controls phones.")
		if page=="Index" then frame:SetAttribute("PortraitScale",1.15) end
		local limit=Instance.new("UISizeConstraint")
		limit.Name,limit.MinSize,limit.MaxSize,limit.Parent="SizeLimits",Vector2.new(300,240),definition.maximum,frame
		frame.Parent=folder
	end
	-- Apply the same reference shape to existing saved controls without replacing
	-- the user's Size, position, or limits. Contents use their own single UIScale.
	local army=folder.MyArmy
	local aspect=army:FindFirstChildWhichIsA("UIAspectRatioConstraint")
	if not aspect then aspect=Instance.new("UIAspectRatioConstraint");aspect.Parent=army end
	aspect.AspectRatio=Layout.ArmyCanvas.X/Layout.ArmyCanvas.Y
	aspect.AspectType,aspect.DominantAxis=Enum.AspectType.FitWithinMaxSize,Enum.DominantAxis.Width
	army:SetAttribute("EditHelp","Size sets the available space. Army scales as one fixed layout; adjust both Scale values to make it larger or smaller. CompactSize sets available space on phones.")
	return folder
end

return Layout
