--!strict
-- Studio-owned Frames are the saved sizing controls. Client code never rewrites them.
local Layout={}
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
	return math.max(1,math.min(width,available.X-24)),math.max(1,math.min(height,available.Y-24))
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
	return folder
end

return Layout
