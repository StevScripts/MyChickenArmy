-- Chicken UI Lab (October 15): Edit-mode story previews for the Studio plugin in
-- tools/ui-lab. Renders the real client UI modules with fixture state under
-- StarterGui.PetRollGui.MenuLayouts.UILab (hidden at runtime with MenuLayouts, so
-- there is still one game ScreenGui), snapshots the rendered tree, and saves the
-- owner's property edits as a JSON change list in ServerStorage.UILab.Tweaks for an
-- agent to apply to the source. Nothing here runs in game. Contract: docs/UI_LAB.md.
local HttpService=game:GetService("HttpService")
local RunService=game:GetService("RunService")
local Lab={}

Lab.Devices={
	{id="Desktop",name="PC 16:9",aspect=16/9},
	{id="Phone",name="Phone 19.5:9",aspect=844/390},
	{id="Tablet",name="Tablet 4:3",aspect=4/3},
}

-- Built-in presets; the plugin adds states captured during Play.
function Lab.Presets()
	local tools=script.Parent
	return {
		{id="LateGame",name="Late game (Test everything)",state=function() return require(tools.LateGameState) end},
		{id="Starter",name="Starter sample",state=function() return require(tools.PreviewState) end},
	}
end

local function copy(value)
	return HttpService:JSONDecode(HttpService:JSONEncode(value))
end

local function session()
	local folder=game.ServerStorage:FindFirstChild("UIAuthoringPreview")
	if not folder then folder=Instance.new("Folder");folder.Name,folder.Parent="UIAuthoringPreview",game.ServerStorage end
	return folder
end

-- Unmounts the story and restores the menu layout controls the old editor uses.
function Lab.Unmount()
	local gui=game.StarterGui:FindFirstChild("PetRollGui")
	local layouts=gui and gui:FindFirstChild("MenuLayouts")
	local labFrame=layouts and layouts:FindFirstChild("UILab")
	if labFrame then labFrame:Destroy() end
	local code=session():FindFirstChild("LabCode")
	if code then code:Destroy() end
	if layouts then
		for _,child in layouts:GetChildren() do
			if child:IsA("GuiObject") and child:GetAttribute("UILabHidden") then
				child.Visible=true;child:SetAttribute("UILabHidden",nil)
			end
		end
	end
	-- Remove anything a story added outside the UI (for example the Hill tint in Lighting).
	for _,service in {game:GetService("Lighting"),workspace} do
		for _,child in service:GetChildren() do if child:GetAttribute("UILabCreated") then child:Destroy() end end
	end
	-- Restore the owner's "show UI in Edit" choice.
	local previous=game.StarterGui:GetAttribute("UILabShowDevelopmentGui")
	if previous~=nil then
		game.StarterGui.ShowDevelopmentGui=previous
		game.StarterGui:SetAttribute("UILabShowDevelopmentGui",nil)
	end
end

-- Mounts one story. Returns the story root, or nil and an error message.
function Lab.Mount(storyId:string,state,deviceId:string?)
	assert(not RunService:IsRunning(),"Stop Play to preview UI stories.")
	Lab.Unmount()
	local gui=game.StarterGui:FindFirstChild("PetRollGui")
	if not gui then return nil,"StarterGui.PetRollGui is missing." end
	-- A fresh require cache previews the current Rojo source.
	local code=game.StarterPlayer.StarterPlayerScripts.PetRoll:Clone()
	code.Name,code.Parent="LabCode",session()
	local Layout=require(code.MenuLayout)
	local Theme=require(code.UITheme)
	Theme.Motion:SetReduced(true)
	local layouts=Layout.CreateControls(gui)
	layouts.Visible=true
	-- StarterGui only draws in the Edit viewport with ShowDevelopmentGui; Unmount restores it.
	if game.StarterGui:GetAttribute("UILabShowDevelopmentGui")==nil then
		game.StarterGui:SetAttribute("UILabShowDevelopmentGui",game.StarterGui.ShowDevelopmentGui)
	end
	game.StarterGui.ShowDevelopmentGui=true
	for _,child in layouts:GetChildren() do
		if child:IsA("GuiObject") and child.Visible then child.Visible=false;child:SetAttribute("UILabHidden",true) end
	end
	local labFrame=Instance.new("Frame")
	labFrame.Name,labFrame.Size,labFrame.BackgroundTransparency,labFrame.BorderSizePixel="UILab",UDim2.fromScale(1,1),1,0
	labFrame.ZIndex=50
	labFrame.Parent=layouts
	local device
	for _,entry in Lab.Devices do if entry.id==deviceId then device=entry end end
	device=device or Lab.Devices[1]
	-- The device frame letterboxes the viewport to the chosen screen shape.
	local screen=Instance.new("Frame")
	screen.Name,screen.AnchorPoint,screen.Position,screen.Size="Screen",Vector2.new(.5,.5),UDim2.fromScale(.5,.5),UDim2.fromScale(1,1)
	screen.BackgroundTransparency,screen.BorderSizePixel,screen.ClipsDescendants=1,0,true
	-- A thin outline marks the device edges without tinting the scene.
	local edge=Instance.new("UIStroke")
	edge.Name,edge.Color,edge.Thickness,edge.Transparency=("DeviceEdge"),Color3.fromRGB(255,214,10),2,0.1
	edge.Parent=screen
	local aspect=Instance.new("UIAspectRatioConstraint");aspect.AspectRatio,aspect.Parent=device.aspect,screen
	screen.Parent=labFrame
	local story=Theme.Container(screen,"Story")
	story:SetAttribute("UILabStory",storyId)
	story:SetAttribute("UILabDevice",device.id)
	local Stories=require(script.Parent.LabStories)
	local existing={}
	for _,service in {game:GetService("Lighting"),workspace} do for _,child in service:GetChildren() do existing[child]=true end end
	local ok,err=pcall(function() Stories.Render(storyId,{code=code,gui=gui,root=story,state=copy(state),Theme=Theme,Layout=Layout}) end)
	for _,service in {game:GetService("Lighting"),workspace} do
		for _,child in service:GetChildren() do if not existing[child] then child:SetAttribute("UILabCreated",true) end end
	end
	if not ok then
		story:SetAttribute("UILabError",tostring(err))
		return story,tostring(err)
	end
	return story,nil
end

-- Easy edit (October 15 owner request: "not nested inside so many things"): bakes the
-- rendered layout into plain Scale positions so everything can be dragged freely.
-- Measures every element first, then removes layout helpers, hoists invisible
-- wrapper Frames into their parents (renumbering ZIndex so draw order is unchanged
-- under Sibling ZIndexBehavior) and pins each element at its measured rectangle.
-- Each element keeps its original path in the UILabPath attribute for the diff.
local LAYOUT_HELPERS={UIListLayout=true,UIGridLayout=true,UITableLayout=true,UIPageLayout=true,
	UIAspectRatioConstraint=true,UISizeConstraint=true,UIPadding=true,UIScale=true,UIFlexItem=true}

local function isWrapper(item:Instance,root:Instance):boolean
	if item==root or item.ClassName~="Frame" then return false end
	local frame=item::Frame
	if frame.BackgroundTransparency<0.999 or not frame.Visible or frame.ClipsDescendants or frame.Rotation~=0 then return false end
	if frame:FindFirstChildWhichIsA("UIStroke") then return false end
	return true
end

function Lab.Flatten(root:GuiObject)
	-- 1. Measure everything with the original layout and remember original paths.
	local rects={}
	local function measure(instance:Instance,path:string)
		if instance:IsA("GuiObject") then
			local rect={position=instance.AbsolutePosition,size=instance.AbsoluteSize}
			if instance:IsA("ScrollingFrame") then
				rect.canvasOrigin=instance.AbsolutePosition-instance.CanvasPosition
				rect.canvasSize=instance.AbsoluteCanvasSize
			end
			rects[instance]=rect
			instance:SetAttribute("UILabPath",path)
		end
		local seen={}
		for _,child in instance:GetChildren() do
			seen[child.Name]=(seen[child.Name] or 0)+1
			measure(child,path.."/"..child.Name..(if seen[child.Name]>1 then "["..seen[child.Name].."]" else ""))
		end
	end
	measure(root,root.Name)
	-- 2. Remove layout helpers; freeze automatic sizing at today's size.
	for _,item in root:GetDescendants() do
		if LAYOUT_HELPERS[item.ClassName] then item:Destroy() end
	end
	for item,rect in rects do
		item.AutomaticSize=Enum.AutomaticSize.None
		if item:IsA("ScrollingFrame") and rect.canvasSize then
			item.AutomaticCanvasSize=Enum.AutomaticSize.None
			item.CanvasSize=UDim2.fromOffset(rect.canvasSize.X,rect.canvasSize.Y)
		end
	end
	-- 3. Hoist invisible wrappers, keeping draw order (bottom-up per parent).
	local hoisted=0
	local function ordered(parent:Instance)
		local items={}
		for index,child in parent:GetChildren() do
			if child:IsA("GuiObject") then table.insert(items,{item=child,z=child.ZIndex,index=index}) end
		end
		table.sort(items,function(a,b) return a.z<b.z or (a.z==b.z and a.index<b.index) end)
		local result={}
		for _,entry in items do table.insert(result,entry.item) end
		return result
	end
	local function collapse(parent:Instance)
		local final={}
		for _,child in ordered(parent) do
			collapse(child)
			if isWrapper(child,root) then
				for _,grandchild in ordered(child) do
					grandchild.Parent=parent
					table.insert(final,grandchild)
				end
				child:Destroy()
				hoisted+=1
			else
				table.insert(final,child)
			end
		end
		for z,item in final do item.ZIndex=z end
	end
	collapse(root)
	-- 4. Pin every element at its measured rectangle, as Scale of its new parent.
	local function place(instance:Instance)
		for _,child in instance:GetChildren() do
			local rect=rects[child]
			local parentRect=rects[instance]
			if rect and parentRect and child:IsA("GuiObject") then
				local origin=parentRect.canvasOrigin or parentRect.position
				local size=parentRect.canvasSize or parentRect.size
				if size.X>0 and size.Y>0 then
					child.AnchorPoint=Vector2.zero
					child.Position=UDim2.fromScale((rect.position.X-origin.X)/size.X,(rect.position.Y-origin.Y)/size.Y)
					child.Size=UDim2.fromScale(rect.size.X/size.X,rect.size.Y/size.Y)
				end
			end
			place(child)
		end
	end
	place(root)
	return hoisted
end

-- Properties an owner can tweak and an agent can carry back into source.
local PROPS={
	GuiObject={"Size","Position","AnchorPoint","Rotation","Visible","ZIndex","LayoutOrder","BackgroundColor3","BackgroundTransparency","ClipsDescendants"},
	TextLabel={"Text","TextColor3","TextSize","TextScaled","TextTransparency","TextStrokeTransparency","TextStrokeColor3","FontFace","TextXAlignment","TextYAlignment","TextWrapped","RichText"},
	ImageLabel={"Image","ImageColor3","ImageTransparency","ScaleType","SliceCenter"},
	UIStroke={"Color","Thickness","Transparency","Enabled"},
	UICorner={"CornerRadius"},
	UIPadding={"PaddingTop","PaddingBottom","PaddingLeft","PaddingRight"},
	UIAspectRatioConstraint={"AspectRatio","AspectType","DominantAxis"},
	UIListLayout={"Padding","FillDirection","HorizontalAlignment","VerticalAlignment","SortOrder"},
	UIGridLayout={"CellSize","CellPadding","FillDirection","HorizontalAlignment","VerticalAlignment"},
	UIGradient={"Color","Transparency","Rotation","Offset","Enabled"},
	UITextSizeConstraint={"MinTextSize","MaxTextSize"},
	UIScale={"Scale"},
}
local CLASS_GROUPS={TextLabel={"TextLabel","TextButton","TextBox"},ImageLabel={"ImageLabel","ImageButton"}}

local function propsFor(instance:Instance)
	local list={}
	if instance:IsA("GuiObject") then for _,p in PROPS.GuiObject do table.insert(list,p) end end
	for group,classes in CLASS_GROUPS do
		for _,class in classes do if instance.ClassName==class then for _,p in PROPS[group] do table.insert(list,p) end end end
	end
	if PROPS[instance.ClassName] and instance.ClassName~="TextLabel" and instance.ClassName~="ImageLabel" then
		for _,p in PROPS[instance.ClassName] do table.insert(list,p) end
	end
	return list
end

local function round(n) return math.floor(n*10000+0.5)/10000 end
local function hex(c:Color3) return string.format("#%02X%02X%02X",math.floor(c.R*255+.5),math.floor(c.G*255+.5),math.floor(c.B*255+.5)) end

-- JSON-friendly text an agent can paste back into Luau.
local function encode(value):string
	local kind=typeof(value)
	if kind=="UDim2" then return string.format("UDim2.new(%s,%s,%s,%s)",round(value.X.Scale),value.X.Offset,round(value.Y.Scale),value.Y.Offset)
	elseif kind=="UDim" then return string.format("UDim.new(%s,%s)",round(value.Scale),value.Offset)
	elseif kind=="Vector2" then return string.format("Vector2.new(%s,%s)",round(value.X),round(value.Y))
	elseif kind=="Color3" then return string.format("Color3.fromRGB(%d,%d,%d) %s",math.floor(value.R*255+.5),math.floor(value.G*255+.5),math.floor(value.B*255+.5),hex(value))
	elseif kind=="Font" then return string.format("Font.new(%q,%s,%s)",value.Family,tostring(value.Weight),tostring(value.Style))
	elseif kind=="EnumItem" then return tostring(value)
	elseif kind=="Rect" then return string.format("Rect.new(%s,%s,%s,%s)",value.Min.X,value.Min.Y,value.Max.X,value.Max.Y)
	elseif kind=="ColorSequence" then
		local parts={} for _,k in value.Keypoints do table.insert(parts,round(k.Time)..":"..hex(k.Value)) end
		return "ColorSequence{"..table.concat(parts,", ").."}"
	elseif kind=="NumberSequence" then
		local parts={} for _,k in value.Keypoints do table.insert(parts,round(k.Time)..":"..round(k.Value)) end
		return "NumberSequence{"..table.concat(parts,", ").."}"
	elseif kind=="number" then return tostring(round(value))
	end
	return tostring(value)
end

-- Paths use names; repeated sibling names get [n] in child order.
local function walk(root:Instance,visit)
	local function step(instance,path)
		visit(instance,path)
		local seen={}
		for _,child in instance:GetChildren() do
			local name=child.Name
			seen[name]=(seen[name] or 0)+1
			local key=if seen[name]>1 then name.."["..seen[name].."]" else name
			step(child,path.."/"..key)
		end
	end
	step(root,root.Name)
end

-- Captures every tweakable property of the rendered story.
-- Theme.Display's TextShadow/TextFace copy these from their parent label, so only
-- the parent's value is the owner's choice (colors and gradients stay per face).
local MIRRORED={Text=true,FontFace=true,TextSize=true,TextXAlignment=true,TextYAlignment=true,TextWrapped=true,TextScaled=true,ZIndex=true}

function Lab.Snapshot(root:Instance)
	local snap={}
	walk(root,function(instance,path)
		-- UITheme.ScaleText adds/removes ReadableTextSize on its own; never a tweak.
		if instance.Name=="ReadableTextSize" and instance:IsA("UITextSizeConstraint") then return end
		local mirror=(instance.Name=="TextFace" or instance.Name=="TextShadow") and instance.Parent and instance.Parent:IsA("TextLabel")
		local props={}
		for _,p in propsFor(instance) do
			if mirror and MIRRORED[p] then continue end
			local ok,value=pcall(function() return (instance::any)[p] end)
			if ok then props[p]=encode(value) end
		end
		local entry={class=instance.ClassName,props=props,original=instance:GetAttribute("UILabPath")}
		-- Where it sits on the device screen (0..1), unambiguous after Easy edit.
		local screen=root.Parent
		if instance:IsA("GuiObject") and screen and screen:IsA("GuiObject") and screen.AbsoluteSize.X>0 then
			local origin,size=screen.AbsolutePosition,screen.AbsoluteSize
			entry.screenRect=string.format("x=%.4f y=%.4f w=%.4f h=%.4f",(instance.AbsolutePosition.X-origin.X)/size.X,
				(instance.AbsolutePosition.Y-origin.Y)/size.Y,instance.AbsoluteSize.X/size.X,instance.AbsoluteSize.Y/size.Y)
		end
		snap[path]=entry
	end)
	return snap
end

-- Properties that changed by themselves between two untouched snapshots (clocks,
-- counters, deferred layout). Diff skips them so only the owner's edits are saved.
function Lab.Volatile(first,second)
	local volatile={}
	for path,entry in second do
		local old=first[path]
		if not old then volatile[path]=true
		else for p,value in entry.props do if old.props[p]~=value then volatile[path.."|"..p]=true end end end
	end
	for path in first do if not second[path] then volatile[path]=true end end
	return volatile
end

-- What the owner changed since the snapshot: edits, additions and removals.
function Lab.Diff(before,root:Instance,volatile)
	volatile=volatile or {}
	local after=Lab.Snapshot(root)
	local changes={}
	for path,entry in after do
		local old=before[path]
		if volatile[path] then continue end
		if not old then
			table.insert(changes,{path=path,class=entry.class,kind="added",props=entry.props,screenRect=entry.screenRect})
		else
			for p,value in entry.props do
				if old.props[p]~=value and not volatile[path.."|"..p] then
					table.insert(changes,{path=path,originalPath=entry.original,class=entry.class,kind="changed",property=p,
						from=old.props[p],to=value,screenRect=entry.screenRect,screenRectBefore=old.screenRect})
				end
			end
		end
	end
	for path,entry in before do
		if not after[path] and not volatile[path] then table.insert(changes,{path=path,originalPath=entry.original,class=entry.class,kind="removed"}) end
	end
	table.sort(changes,function(a,b) return a.path<b.path or (a.path==b.path and (a.property or "")<(b.property or "")) end)
	return changes
end

-- Stores a change list for an agent ("apply my UI Lab tweaks"). Returns its name.
function Lab.SaveTweaks(storyId:string,presetName:string,deviceId:string,changes,note:string?,mode:string?)
	local root=game.ServerStorage:FindFirstChild("UILab")
	if not root then root=Instance.new("Folder");root.Name,root.Parent="UILab",game.ServerStorage end
	local tweaks=root:FindFirstChild("Tweaks")
	if not tweaks then tweaks=Instance.new("Folder");tweaks.Name,tweaks.Parent="Tweaks",root end
	local stamp=os.date("!%Y%m%d-%H%M%S")
	local record=Instance.new("StringValue")
	record.Name=stamp.."_"..storyId
	record.Value=HttpService:JSONEncode({story=storyId,preset=presetName,device=deviceId,note=note or "",savedAt=stamp,mode=mode or "exact",
		status="new",changes=changes})
	record:SetAttribute("Status","new")
	record:SetAttribute("Story",storyId)
	record:SetAttribute("Changes",#changes)
	record.Parent=tweaks
	return record.Name
end

function Lab.Stories()
	return require(script.Parent.LabStories).List
end

return Lab
