-- Studio Edit asset migration from Figma 328:844, 640 x 600 (September 24, 2026).
-- Preserves builder geometry, cash-pad art/behavior and all mapped source.
assert(game.PlaceId == 96683186622050 and not game:GetService("RunService"):IsRunning())
local board = workspace.MyChickenArmyMap["03_HomePlots"].EggCollectionBoard
local screen = board.Screen
local original = screen:FindFirstChildOfClass("SurfaceGui")
local storage = game:GetService("ServerStorage")
assert(original and not storage:FindFirstChild("EggSellerCompactBackup20260924"), "Inspect the existing migration/backup before rerunning")

-- Edit-time require caches can predate Rojo edits; use the current mapped sources.
local loaded = {}
local function fresh(module)
	if loaded[module] then return loaded[module] end
	local run=assert(loadstring(module.Source,module.Name))
	setfenv(run,setmetatable({script=module,require=fresh},{__index=getfenv()}))
	local value=run()
	loaded[module]=value
	return value
end
local Theme = fresh(game.StarterPlayer.StarterPlayerScripts.PetRoll.UITheme)
local ink, white = Color3.fromRGB(16,23,16), Color3.fromRGB(255,254,245)
-- Build off-tree first. The original surface remains intact until completion.
local gui = original:Clone()
gui.Parent = nil
gui:ClearAllChildren()
gui.Name = "SurfaceGui"
gui.CanvasSize, gui.SizingMode = Vector2.new(320,300), Enum.SurfaceGuiSizingMode.FixedSize
gui.LightInfluence, gui.AlwaysOnTop, gui.Active = 0, false, true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Reference measurements become ordinary native Scale properties, not UIScale.
local dimensions={[gui]=Vector2.new(640,600)}
local function layout(item,parent,x,y,w,h)
	local size=dimensions[parent]
	item.Position,item.Size=UDim2.fromScale(x/size.X,y/size.Y),UDim2.fromScale(w/size.X,h/size.Y)
	dimensions[item]=Vector2.new(w,h)
end
local function frame(parent,name,x,y,w,h,color)
	local item=Theme.Frame(parent,name,UDim2.fromScale(1,1),color)
	layout(item,parent,x,y,w,h)
	item.BackgroundTransparency=if color then 0 else 1
	return item
end
local function label(parent,name,text,x,y,w,h,size)
	local item=Theme.Label(parent,name,text,size,white)
	layout(item,parent,x,y,w,h)
	item.TextWrapped,item.TextXAlignment=false,Enum.TextXAlignment.Center
	item.TextScaled=true
	item.TextOutline.Color,item.TextOutline.Thickness=ink,2
	return item
end
local panel=frame(gui,"EggSellingBoard",0,0,640,600)
panel:SetAttribute("FigmaNode","328:844")
panel:SetAttribute("InlineUpgradePrice",true)
panel.ClipsDescendants=true

local header=frame(panel,"Header",32,32,576,84,Color3.new(1,1,1))
header.ClipsDescendants=true
Theme.ApplyReferenceAccent(header,Theme.ReferenceGradients.Upgrades)
Theme.Stroke(header,ink,3)
Theme.Studs(header,0.14,28,0)
local rim=frame(header,"InsetHighlight",7,7,562,70)
rim.ZIndex=3
Theme.Stroke(rim,white,1)
local title=label(header,"Title","EGG SELLER",24,8,528,68,54)
title.TextOutline.Thickness=3

local content=frame(panel,"Content",32,128,576,440,Color3.new(1,1,1))
content.ClipsDescendants=true
local bodyGradient=Theme.Gradient(content,Color3.fromRGB(16,23,18),Color3.fromRGB(16,23,18))
bodyGradient.Transparency=NumberSequence.new(0.18,0.44)
label(content,"QueueLabel","EGGS QUEUED",24,88,528,36,26)
local count=label(content,"QueuedCount","10,000",24,124,528,124,100)
count.TextOutline.Thickness=2
local divider=frame(content,"Divider",24,262,528,2,white)
divider.BackgroundTransparency=0.65
label(content,"RateLabel","Selling speed",24,278,217,48,30)
label(content,"Rate","2 eggs/sec",342,278,210,48,30)

local function action(name,text,x,y,w,h,size,sequence)
	local button=Theme.Button(content,name,text,function() end,Theme.Arcade.green)
	layout(button,content,x,y,w,h)
	button.TextSize,button.TextColor3,button.TextWrapped=size,white,false
	button.TextScaled=true
	Theme.ApplyReferenceAccent(button,sequence)
	button.Visual.UIStroke.Color,button.Visual.LowerLip.BackgroundColor3=ink,ink
	local face=button.Visual.Face
	face.InsetHighlight.UIStroke.Color=white
	Theme.Studs(face,0.14,28,0)
	-- Dynamic captions stay native and explicitly editable in the stored surface.
	local caption=button.Visual.Caption
	caption.Text,caption.TextSize,caption.TextColor3,caption.TextWrapped=text,size,white,false
	caption.Position,caption.Size=UDim2.fromScale(0.04,0.08),UDim2.fromScale(0.92,0.76)
	caption.TextScaled=true
	face.Size=UDim2.fromScale(1,1-5/h)
	face.InsetHighlight.Position=UDim2.fromScale(3/w,3/(h-5))
	face.InsetHighlight.Size=UDim2.fromScale(1-7/w,1-7/(h-5))
	for _,child in caption:GetChildren() do
		if child:IsA("TextLabel") then
			child.Text,child.TextSize,child.TextWrapped=text,size,false
			child.TextScaled=true
			child.Position=UDim2.fromScale(0,if child.Name=="TextShadow" then 0.03 else 0)
			child.TextOutline.Color,child.TextOutline.Thickness=ink,2
			if child.Name=="TextFace" then child.TextColor3=white end
		end
	end
	return button
end
-- Latest Figma edit: small Finish Now above the queue; Upgrade at the bottom.
action("FinishNow","Finish Now",156,16,264,58,32,
	ColorSequence.new(Color3.fromRGB(201,117,245),Color3.fromRGB(139,53,209)))
action("Upgrade","Upgrade • $480",24,340,528,84,44,Theme.ReferenceGradients.Army)

local backup=Instance.new("Folder")
backup.Name,backup.Parent="EggSellerCompactBackup20260924",storage
original.Parent=backup -- Recoverable original, not deleted.
local billboard=board.Text:FindFirstChildOfClass("BillboardGui")
if billboard then
	backup:SetAttribute("OriginalBillboardEnabled",billboard.Enabled)
	billboard.Enabled=false -- The title is now on the SurfaceGui, not floating above it.
end
gui.Parent=screen
for _,item in gui:GetDescendants() do
	if item:IsA("ImageLabel") and item.Name=="StudTexture" then
		local face=item.Parent.Parent
		item:SetAttribute("StudScaleWidth",672/dimensions[if face==header then header else face.Parent.Parent].X)
		item.TileSize=UDim2.fromScale(1,1)
	end
end
Theme.BindStudTextures(gui)
return {surface=gui:GetFullName(),canvas=tostring(gui.CanvasSize),figma="328:844",
	backup=backup:GetFullName(),geometryChanged=false,buttons=2}
