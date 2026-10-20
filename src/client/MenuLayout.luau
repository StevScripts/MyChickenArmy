--!strict
-- Studio owns each menu's Scale geometry and native aspect constraint.
local Layout={}
Layout.Names={Army="MyArmy",Shop="Shop",Index="Index",Upgrades="Upgrades",Settings="Settings",Odds="Odds",Offline="OfflineEarnings"}
-- GUI.FRAMES proportions expressed against our full-screen parent (the original
-- FRAMES is a small proxy). No viewport math, size limits, or device breakpoints.
Layout.Defaults={
	Army={size=Vector2.new(0.629404,0.82),aspect=1274/876},
	-- October 15 (owner): wider shop; section tabs sit outside its left edge.
	-- October 16 (owner): a tiny bit less wide (1.78 -> 1.62), same height.
	Shop={size=Vector2.new(0.64,0.80),position=Vector2.new(0.535,0.52),aspect=1.62},
	Index={size=Vector2.new(0.513810,0.624904),aspect=1.481701612},
	Upgrades={size=Vector2.new(0.660243,0.461530),position=Vector2.new(0.514634,0.501785),aspect=2.93},
	Settings={size=Vector2.new(0.411726,0.541205),position=Vector2.new(0.489130,0.5),aspect=1.543928},
	Odds={size=Vector2.new(0.411726,0.541205),aspect=1.543928},
	Offline={size=Vector2.new(0.330251,0.421687),aspect=1.391571045},
}

-- October 20: the Sell screen is My Army's sell mode and uses My Army's saved frame.
Layout.Shared={Sell="Army"}

function Layout.Control(gui,page)
	page=Layout.Shared[page] or page
	local folder=gui:FindFirstChild("MenuLayouts")
	return folder and folder:FindFirstChild(Layout.Names[page] or page)
end

function Layout.Number(gui,page,name,fallback,minimum,maximum)
	local control=Layout.Control(gui,page)
	local value=control and control:GetAttribute(name)
	return if type(value)=="number" and value==value then math.clamp(value,minimum,maximum) else fallback
end

function Layout.Apply(gui,page,panel)
	page=Layout.Shared[page] or page
	local definition=Layout.Defaults[page] or Layout.Defaults.Settings
	local control=Layout.Control(gui,page)
	local sourceAspect=control and control:FindFirstChildWhichIsA("UIAspectRatioConstraint")
	panel.Size=if control then control.Size else UDim2.fromScale(definition.size.X,definition.size.Y)
	panel.Position=if control then control.Position else UDim2.fromScale(0.5,0.5)
	panel.AnchorPoint=if control then control.AnchorPoint else Vector2.new(0.5,0.5)
	local aspect=panel:FindFirstChildWhichIsA("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	aspect.Name,aspect.AspectRatio="UIAspectRatioConstraint",if sourceAspect then sourceAspect.AspectRatio else definition.aspect
	aspect.AspectType=Enum.AspectType.FitWithinMaxSize
	aspect.DominantAxis=Enum.DominantAxis.Width
	aspect.Parent=panel
end

-- Edit-only setup. Existing native controls stay editable after the one-time
-- replacement of the former CompactSize/SizeLimits sizing contract.
function Layout.CreateControls(gui)
	local folder=gui:FindFirstChild("MenuLayouts")
	if not folder then
		folder=Instance.new("Frame")
		folder.Name,folder.Size,folder.BackgroundTransparency="MenuLayouts",UDim2.fromScale(1,1),1
		folder.BorderSizePixel,folder.Parent=0,gui
		folder:SetAttribute("PreviewMenu","MyArmy")
	end
	for page,name in Layout.Names do
		local definition=Layout.Defaults[page]
		local frame=folder:FindFirstChild(name)
		local fresh=not frame
		if not frame then
			frame=Instance.new("Frame")
			frame.Name,frame.BackgroundTransparency,frame.BorderSizePixel,frame.Visible=name,1,0,false
			frame.Parent=folder
		end
		if not frame:GetAttribute("NativeAspectLayout") then
			if fresh or page~="Army" then
				frame.Size=UDim2.fromScale(definition.size.X,definition.size.Y)
				local position=definition.position or Vector2.new(0.5,0.5)
				frame.Position,frame.AnchorPoint=UDim2.fromScale(position.X,position.Y),Vector2.new(0.5,0.5)
			end
			for _,child in frame:GetChildren() do
				if child:IsA("UISizeConstraint") or child:IsA("UIScale") then child:Destroy() end
			end
			local aspect=frame:FindFirstChildWhichIsA("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
			aspect.Name,aspect.AspectRatio="UIAspectRatioConstraint",definition.aspect
			aspect.AspectType,aspect.DominantAxis=Enum.AspectType.FitWithinMaxSize,Enum.DominantAxis.Width
			aspect.Parent=frame
			frame:SetAttribute("CompactSize",nil)
			frame:SetAttribute("NativeAspectLayout",true)
			frame:SetAttribute("EditHelp","Edit Size Scale, Position, and UIAspectRatioConstraint. Contents use native Scale geometry on every screen.")
		end
		if page=="Index" and frame:GetAttribute("PortraitScale")==nil then frame:SetAttribute("PortraitScale",1.15) end
	end
	local readme=folder:FindFirstChild("READ_ME")
	if readme and readme:IsA("StringValue") then readme.Value="Select a menu Frame. Edit Size Scale and UIAspectRatioConstraint; no CompactSize or SizeLimits. PreviewMenu chooses the open menu." end
	return folder
end

return Layout
