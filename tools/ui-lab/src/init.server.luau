-- Chicken UI Lab: a local Studio plugin for My Chicken Army.
-- Edit mode: pick a story (screen), sample data and device shape; the real UI renders
-- into the viewport (StarterGui.PetRollGui.MenuLayouts.UILab). Tweak it in
-- Explorer/Properties, then Save tweaks: the change list goes to
-- ServerStorage.UILab.Tweaks for an agent to apply to the source.
-- Play mode: Capture this state saves the client's current game state as a preset.
-- The story code lives in the place (ServerStorage.PetRoll.UIAuthoring, synced by
-- Rojo), so this shell rarely needs reinstalling. Guide: docs/UI_LAB.md.
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local Selection=game:GetService("Selection")
local ChangeHistoryService=game:GetService("ChangeHistoryService")

local running=RunService:IsRunning()
if running and not RunService:IsClient() then return end -- Play server: nothing to show.

local PRESET_KEY="ChickenUILabPresets"
local MAX_PRESETS=8

local toolbar=plugin:CreateToolbar("Chicken Army")
local toggle=toolbar:CreateButton("UI Lab","Preview, tweak and save the game UI","rbxassetid://106238480346679")
toggle.ClickableWhenViewportHidden=true
local widget=plugin:CreateDockWidgetPluginGui("ChickenUILab",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left,false,false,320,620,260,420))
widget.Title="Chicken UI Lab"
widget.Name="ChickenUILab"
toggle:SetActive(widget.Enabled)
toggle.Click:Connect(function() widget.Enabled=not widget.Enabled end)
widget:GetPropertyChangedSignal("Enabled"):Connect(function() toggle:SetActive(widget.Enabled) end)

-- UI -----------------------------------------------------------------------
local INK,PANEL,LINE=Color3.fromRGB(24,26,30),Color3.fromRGB(38,41,47),Color3.fromRGB(70,74,82)
local TEXT,MUTED=Color3.fromRGB(235,235,235),Color3.fromRGB(160,165,172)
local GREEN,BLUE,RED,GOLD=Color3.fromRGB(70,170,70),Color3.fromRGB(40,120,210),Color3.fromRGB(190,60,55),Color3.fromRGB(220,170,30)

local scroll=Instance.new("ScrollingFrame")
scroll.Size,scroll.BackgroundColor3,scroll.BorderSizePixel=UDim2.fromScale(1,1),INK,0
scroll.ScrollBarThickness,scroll.AutomaticCanvasSize,scroll.CanvasSize=6,Enum.AutomaticSize.Y,UDim2.new()
scroll.Parent=widget
local pad=Instance.new("UIPadding")
pad.PaddingLeft,pad.PaddingRight,pad.PaddingTop,pad.PaddingBottom=UDim.new(0,10),UDim.new(0,14),UDim.new(0,10),UDim.new(0,10)
pad.Parent=scroll
local list=Instance.new("UIListLayout");list.Padding,list.SortOrder,list.Parent=UDim.new(0,6),Enum.SortOrder.LayoutOrder,scroll
local order=0
local function nextOrder() order+=1;return order end

local function label(text,size,color)
	local item=Instance.new("TextLabel")
	item.BackgroundTransparency,item.Size,item.AutomaticSize=1,UDim2.new(1,0,0,0),Enum.AutomaticSize.Y
	item.Font,item.TextSize,item.TextColor3,item.TextWrapped=Enum.Font.SourceSansBold,size or 15,color or TEXT,true
	item.TextXAlignment,item.Text,item.LayoutOrder,item.Parent=Enum.TextXAlignment.Left,text,nextOrder(),scroll
	return item
end

local function button(text,color,callback,parent)
	local item=Instance.new("TextButton")
	item.Size,item.BackgroundColor3,item.BorderSizePixel=UDim2.new(1,0,0,30),color or PANEL,0
	item.Font,item.TextSize,item.TextColor3,item.Text,item.AutoButtonColor=Enum.Font.SourceSansBold,15,TEXT,text,true
	local corner=Instance.new("UICorner");corner.CornerRadius,corner.Parent=UDim.new(0,4),item
	item.LayoutOrder=nextOrder()
	item.Parent=parent or scroll
	item.Activated:Connect(callback)
	return item
end

local function textBox(placeholder,height)
	local item=Instance.new("TextBox")
	item.Size,item.BackgroundColor3,item.BorderSizePixel=UDim2.new(1,0,0,height or 30),PANEL,0
	item.Font,item.TextSize,item.TextColor3,item.PlaceholderText=Enum.Font.SourceSans,15,TEXT,placeholder
	item.PlaceholderColor3,item.Text,item.ClearTextOnFocus,item.TextWrapped=MUTED,"",false,true
	item.TextXAlignment,item.TextYAlignment=Enum.TextXAlignment.Left,Enum.TextYAlignment.Top
	local inner=Instance.new("UIPadding");inner.PaddingLeft,inner.PaddingTop,inner.Parent=UDim.new(0,6),UDim.new(0,4),item
	item.LayoutOrder,item.Parent=nextOrder(),scroll
	return item
end

local function row(count)
	local frame=Instance.new("Frame")
	frame.Size,frame.BackgroundTransparency,frame.LayoutOrder,frame.Parent=UDim2.new(1,0,0,30),1,nextOrder(),scroll
	local grid=Instance.new("UIGridLayout")
	grid.CellSize,grid.CellPadding,grid.SortOrder,grid.Parent=UDim2.new(1/count,-4,1,0),UDim2.new(0,4,0,0),Enum.SortOrder.LayoutOrder,frame
	return frame
end

label("Chicken UI Lab",20,GOLD)
local status=label("",14,MUTED)
local function say(text,color) status.Text,status.TextColor3=text,color or MUTED end

-- Presets captured in Play live in plugin settings (shared across Studio sessions).
local function capturedPresets()
	local ok,stored=pcall(function() return plugin:GetSetting(PRESET_KEY) end)
	return if ok and type(stored)=="table" then stored else {}
end

-- PLAY MODE: capture ---------------------------------------------------------
if running then
	label("Play mode: capture the state your screen is showing, then stop Play and preview it in Edit.",14,MUTED)
	local nameBox=textBox("Preset name (for example: after first camp)")
	local lastState
	task.spawn(function()
		local remotes=game:GetService("ReplicatedStorage"):WaitForChild("PetRoll",30)
		remotes=remotes and remotes:WaitForChild("Remotes",30)
		local changed=remotes and remotes:WaitForChild("StateChanged",30)
		if not changed then say("Game remotes not found.",RED);return end
		changed.OnClientEvent:Connect(function(packet) if type(packet)=="table" and packet.state then lastState=packet.state end end)
		say("Listening for game state…")
	end)
	button("Capture this state",GREEN,function()
		if not lastState then say("No state received yet. Wait a moment or perform an action.",RED);return end
		local ok,json=pcall(function() return HttpService:JSONEncode(lastState) end)
		if not ok then say("Could not save this state: "..tostring(json),RED);return end
		local name=if nameBox.Text~="" then nameBox.Text else os.date("Captured %H:%M:%S")
		local stored=capturedPresets()
		local count=0
		for _ in stored do count+=1 end
		if count>=MAX_PRESETS and not stored[name] then say("You have "..MAX_PRESETS.." captured presets. Delete one in Edit first.",RED);return end
		stored[name]=json
		plugin:SetSetting(PRESET_KEY,stored)
		say("Captured \""..name.."\". Stop Play and pick it under Sample data.",GREEN)
	end)
	return
end

-- EDIT MODE: stories ----------------------------------------------------------
local tools -- Fresh clone of ServerStorage.PetRoll.UIAuthoring per load.
local Lab
local function loadLab()
	local source=game:GetService("ServerStorage"):FindFirstChild("PetRoll")
	source=source and source:FindFirstChild("UIAuthoring")
	if not source or not source:FindFirstChild("Lab") then return nil,"ServerStorage.PetRoll.UIAuthoring.Lab is missing. Connect Rojo first." end
	if tools then tools:Destroy() end
	local holder=game:GetService("ServerStorage"):FindFirstChild("UIAuthoringPreview")
	if not holder then holder=Instance.new("Folder");holder.Name,holder.Parent="UIAuthoringPreview",game:GetService("ServerStorage") end
	tools=source:Clone();tools.Name="LabTools";tools.Parent=holder
	local ok,result=pcall(require,tools.Lab)
	if not ok then return nil,tostring(result) end
	Lab=result
	return Lab
end

local current={story=nil,preset=1,device="Desktop",root=nil,baseline=nil,easy=true}
local presets={}

local function refreshPresets()
	presets={}
	if Lab then for _,entry in Lab.Presets() do table.insert(presets,entry) end end
	local names={}
	for name in capturedPresets() do table.insert(names,name) end
	table.sort(names)
	for _,name in names do
		table.insert(presets,{id="captured:"..name,name="Captured: "..name,captured=name,
			state=function() return HttpService:JSONDecode(capturedPresets()[name]) end})
	end
	if current.preset>#presets then current.preset=1 end
end

label("1. Sample data",15,TEXT)
local presetButton=button("…",PANEL,function() end)
local deletePreset=button("Delete this captured preset",RED,function() end)
deletePreset.Visible=false
local easyButton
easyButton=button("Easy edit: ON (drag anything)",GREEN,function()
	current.easy=not current.easy
	easyButton.Text=if current.easy then "Easy edit: ON (drag anything)" else "Easy edit: OFF (exact code layout)"
	easyButton.BackgroundColor3=if current.easy then GREEN else PANEL
	if current.story then show(current.story) end
end)
label("Easy edit removes auto-layout helpers and empty wrapper frames from the preview so you can move things freely. It looks the same; the game code is not changed until Claude applies your tweaks.",13,MUTED)
label("2. Device",15,TEXT)
local deviceRow=row(3)
local deviceButtons={}
label("3. Story (click to show it in the viewport)",15,TEXT)
local storyFrame=Instance.new("Frame")
storyFrame.Size,storyFrame.AutomaticSize,storyFrame.BackgroundTransparency=UDim2.new(1,0,0,0),Enum.AutomaticSize.Y,1
storyFrame.LayoutOrder,storyFrame.Parent=nextOrder(),scroll
local storyList=Instance.new("UIListLayout");storyList.Padding,storyList.SortOrder,storyList.Parent=UDim.new(0,4),Enum.SortOrder.LayoutOrder,storyFrame
local storyButtons={}

local function paint()
	local preset=presets[current.preset]
	presetButton.Text=(preset and preset.name or "No presets").."  ▸"
	deletePreset.Visible=preset~=nil and preset.captured~=nil
	for id,item in deviceButtons do item.BackgroundColor3=if id==current.device then BLUE else PANEL end
	for id,item in storyButtons do item.BackgroundColor3=if id==current.story then GREEN else PANEL end
end

local function show(storyId)
	if RunService:IsRunning() then say("Stop Play to preview stories.",RED);return end
	local lab,why=loadLab()
	if not lab then say(why,RED);return end
	refreshPresets()
	local preset=presets[current.preset]
	if not preset then say("No sample data available.",RED);return end
	local okState,state=pcall(preset.state)
	if not okState then say("Sample data failed: "..tostring(state),RED);return end
	current.story=storyId
	local recording=ChangeHistoryService:TryBeginRecording("UI Lab: show "..storyId)
	local root,err=lab.Mount(storyId,state,current.device)
	if recording then ChangeHistoryService:FinishRecording(recording,Enum.FinishRecordingOperation.Commit) end
	current.root=root
	paint()
	if err then say("Story error: "..err,RED);return end
	say("Rendering "..storyId.."…")
	-- Next-frame helpers (text size floors, layout) settle before the baseline.
	task.delay(0.6,function()
		if current.root~=root or not root.Parent then return end
		if current.easy then
			local ok,result=pcall(lab.Flatten,root)
			if not ok then say("Easy edit failed (showing the exact layout): "..tostring(result),RED) end
		end
		current.baseline=lab.Snapshot(root)
		current.volatile={}
		say("Showing "..storyId..(if current.easy then " in Easy edit: drag or resize anything." else ".").." Then Save tweaks.",GREEN)
		-- A second untouched look: anything that changes by itself is not a tweak.
		local baseline=current.baseline
		task.delay(1.5,function()
			if current.root~=root or current.baseline~=baseline or not root.Parent then return end
			current.volatile=lab.Volatile(baseline,lab.Snapshot(root))
		end)
	end)
end

presetButton.Activated:Connect(function()
	if not Lab then loadLab() end
	refreshPresets()
	if #presets==0 then return end
	current.preset=current.preset%#presets+1
	paint()
	if current.story then show(current.story) end
end)
deletePreset.Activated:Connect(function()
	local preset=presets[current.preset]
	if not preset or not preset.captured then return end
	local stored=capturedPresets()
	stored[preset.captured]=nil
	plugin:SetSetting(PRESET_KEY,stored)
	current.preset=1
	refreshPresets();paint()
	say("Deleted "..preset.name..".")
end)

for _,device in {{"Desktop","PC"},{"Phone","Phone"},{"Tablet","Tablet"}} do
	deviceButtons[device[1]]=button(device[2],PANEL,function()
		current.device=device[1];paint()
		if current.story then show(current.story) end
	end,deviceRow)
end

local function buildStories()
	for _,item in storyButtons do item:Destroy() end
	storyButtons={}
	local lab,why=loadLab()
	if not lab then say(why,RED);return end
	refreshPresets()
	for index,story in lab.Stories() do
		local item=button(story.name,PANEL,function() show(story.id) end,storyFrame)
		item.LayoutOrder=index
		storyButtons[story.id]=item
	end
	paint()
	say("Pick a story. The UI appears in the viewport.")
end

label("4. Tweak and save",15,TEXT)
button("Select story in Explorer",PANEL,function()
	if current.root and current.root.Parent then Selection:Set({current.root}) else say("Show a story first.",RED) end
end)
local noteBox=textBox("What should change? (optional note for Claude)",54)
button("Save tweaks",GOLD,function()
	if not Lab or not current.root or not current.root.Parent or not current.baseline then say("Show a story first.",RED);return end
	local changes=Lab.Diff(current.baseline,current.root,current.volatile)
	if #changes==0 and noteBox.Text=="" then say("No changes yet. Edit something in Properties, or write a note.",RED);return end
	local preset=presets[current.preset]
	local name=Lab.SaveTweaks(current.story,preset and preset.name or "?",current.device,changes,noteBox.Text,if current.easy then "easy" else "exact")
	noteBox.Text=""
	current.baseline,current.volatile=Lab.Snapshot(current.root),{}
	say("Saved "..#changes.." change(s) as ServerStorage.UILab.Tweaks."..name..". Tell Claude: \"apply my UI Lab tweaks\". Save the place to keep them.",GREEN)
end)
button("Reset story (discard unsaved tweaks)",PANEL,function()
	if current.story then show(current.story) end
end)
button("Close preview",RED,function()
	if Lab then Lab.Unmount() end
	current.root,current.baseline,current.story=nil,nil,nil
	if tools then tools:Destroy();tools=nil end
	paint()
	say("Preview closed.")
end)
button("Reload stories (after code changes)",PANEL,buildStories)
label("Tweaks are a request for Claude, not live game changes: the game rebuilds its UI from code. Menu size/position also lives in StarterGui.PetRollGui.MenuLayouts.",13,MUTED)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	if widget.Enabled and next(storyButtons)==nil then buildStories() end
end)
if widget.Enabled then buildStories() end

plugin.Unloading:Connect(function()
	if Lab then pcall(Lab.Unmount) end
	if tools then tools:Destroy() end
end)
