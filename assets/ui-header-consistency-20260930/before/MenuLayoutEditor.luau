-- Edit-mode preview only. Run from the Studio Command Bar; nothing auto-runs in game.
local Editor={}
local RunService=game:GetService("RunService")

function Editor.Open()
	assert(not RunService:IsRunning(),"Stop Play before editing saved menu layouts.")
	local tools=script.Parent
	local session=game.ServerStorage:FindFirstChild("UIAuthoringPreview")
	if not session then session=Instance.new("Folder");session.Name,session.Parent="UIAuthoringPreview",game.ServerStorage end
	local previous=session:FindFirstChild("StopPreview")
	if previous then
		-- Saved BindableFunctions lose their callback after Studio restarts; Invoke
		-- would then wait forever. Preview cleanup is a non-blocking event.
		if previous:IsA("BindableEvent") then previous:Fire() end
		previous:Destroy()
	end
	local oldCode=session:FindFirstChild("PreviewCode")
	if oldCode then oldCode:Destroy() end
	-- A fresh require cache previews the current Rojo source without starting the game.
	local code=game.StarterPlayer.StarterPlayerScripts.PetRoll:Clone()
	code.Name,code.Parent="PreviewCode",session
	local Layout=require(code.MenuLayout)
	local Theme=require(code.UITheme)
	local App=require(code.AppController)
	Theme.Motion:SetReduced(true)
	local gui=game.StarterGui.PetRollGui
	local layouts=Layout.CreateControls(gui)
	layouts.Visible=true
	local connections,views={},{}
	local stop=Instance.new("BindableEvent")
	stop.Name,stop.Parent="StopPreview",session
	local closed=false
	stop.Event:Connect(function()
		if closed then return end
		closed=true
		for _,c in connections do c:Disconnect() end
		for _,view in views do
			if view.browser and view.browser.Destroy then pcall(function() view.browser:Destroy() end) end
		end
	end)
	local function noop() end
	for page,name in Layout.Names do
		local control=layouts[name]
		local old=control:FindFirstChild("Preview")
		if old then old:Destroy() end
		local canvas=Theme.Container(control,"Preview")
		local app=setmetatable({gui=gui,panel=canvas,other=canvas,page=page,
			connections={},alive=true,editPreview=true,reducedMotion=true,
			state=game:GetService("HttpService"):JSONDecode(game:GetService("HttpService"):JSONEncode(require(tools.PreviewState))),
			audio={Play=noop,SetMusic=noop,SetEffects=noop,musicEnabled=true,sfxEnabled=true},
			Request=noop,Notify=noop,SetMenuBlur=noop,ClosePanel=noop,FitPanel=noop},App)
		app.commerce=require(code.CommerceController).new(app)
		app.OpenPage=function(_,nextPage) layouts:SetAttribute("PreviewMenu",Layout.Names[nextPage] or nextPage) end
		local browser,render
		if page=="Army" then
			browser=require(code.ChickenBrowser).new(app,canvas);app.chickenBrowser=browser;app.panelTitle=browser.title
			app.selected=app.state.pets[1] and app.state.pets[1].id
			render=function() browser:Render(true) end
		elseif page=="Shop" then
			browser=require(code.ShopBrowser).new(app,canvas);app.shopBrowser=browser
			render=function() browser:Render(true) end
		elseif page=="Upgrades" then
			browser=require(code.ProgressionBrowser).new(app);browser:Mount(canvas)
			render=function() browser:Render() end
		elseif page=="Merge" then
			browser=require(code.MergeBrowser).new(app,canvas)
			render=function() browser:Render(true) end
		elseif page=="Offline" then
			browser=require(code.OfflineCashController).new(app)
			browser:Receive({offlineCash={id="editor-preview",amount=12345,seconds=3600}})
			render=noop -- Native Scale geometry follows the parent without a listener.
		else
			local isIndex=page=="Index"
			local body=Theme.Frame(canvas,"Main",UDim2.fromScale(1,if isIndex then 0.825 else 0.85338676));body.Position=UDim2.fromScale(0,if isIndex then 0.175 else 0.14661324)
			Theme.Surface(body,Theme.PageSurfaces[page] or Theme.Colors.panel)
			local header,title=Theme.Header(canvas,"Header",if page=="Index" then "Chicken Index!" elseif page=="Odds" then "Roll Odds" else "Settings",Theme.HeaderColors[page] or Theme.ActionColors.navigation)
			header.Size=UDim2.fromScale(1,if isIndex then 0.1625 else 0.1335698664)
			header.PageIcon.Visible=page=="Index" or page=="Odds"
			header.PageIcon.Image=if page=="Index" then Theme.Assets.Index else Theme.Assets.Luck
			header.PageIcon.Size,header.PageIcon.Position=UDim2.fromScale(0.1,0.88),UDim2.fromScale(0.01,0.06)
			Theme.Aspect(header.PageIcon,1)
			title.Position,title.Size,title.TextSize=UDim2.fromScale(if header.PageIcon.Visible then 0.12 else 0.03,0.12),UDim2.fromScale(if header.PageIcon.Visible then 0.73 else 0.82,0.76),32
			local close=Theme.ActionButton(header,"Close","X",noop,Theme.Arcade.red)
			close.Size,close.Position,close.TextSize=UDim2.fromScale(0.085,0.86),UDim2.fromScale(0.905,0.06),32
			Theme.Aspect(close,1.094339728)
			Theme.ScaleText(header)
			app.panelHeader,app.panelTitle,app.panelBody=header,title,body
			if page=="Index" then
				browser=require(code.IndexBrowser).new(app,body)
				browser.root.Position,browser.root.Size=UDim2.fromScale(0.02,0.02),UDim2.fromScale(0.96,0.96)
				render=function() browser:Render(true) end
			else
				local content=Instance.new("ScrollingFrame")
				content.Name,content.Size,content.Position="Content",UDim2.fromScale(0.96,0.96),UDim2.fromScale(0.02,0.02)
				content.BackgroundTransparency,content.BorderSizePixel,content.ScrollBarThickness=1,0,0
				content.AutomaticCanvasSize,content.CanvasSize,content.Parent=Enum.AutomaticSize.Y,UDim2.new(),body
				local list=Instance.new("UIListLayout");list.Padding,list.SortOrder,list.Parent=UDim.new(0.025,0),Enum.SortOrder.LayoutOrder,content
				app.content=content
				render=function()
					app:ClearPanel()
					if page=="Settings" then app:RenderSettings()
					else
						local catalog=require(game.ReplicatedStorage.PetRoll.Shared.PetCatalog)
						local rules=require(game.ReplicatedStorage.PetRoll.Shared.Rules)
						for _,id in catalog.Order do local chance=app.state.odds[id];if chance and chance>0 then app:Text("Odds"..id,catalog[id].name.." · "..rules.FormatOdds(chance),15,30) end end
					end
				end
			end
		end
		if browser and browser.root then browser.root.Visible=true end
		local busy=false
		local function resize()
			if closed or busy or RunService:IsRunning() then return end
			local size=control.AbsoluteSize
			if size.X<=0 or size.Y<=0 then return end
			busy=true
			local ok,err=pcall(render)
			if page=="Index" or page=="Settings" or page=="Odds" then Theme.ApplyPopupStyle(canvas) end
			control:SetAttribute("PreviewError",if ok then nil else tostring(err))
			busy=false
		end
		app.RenderPanel=resize
		table.insert(views,{browser=browser})
		table.insert(connections,control:GetAttributeChangedSignal("PortraitScale"):Connect(resize))
		resize()
	end
	local choosing=false
	local function choose(name)
		if closed or choosing or RunService:IsRunning() then return end
		choosing=true
		for _,controlName in Layout.Names do layouts[controlName].Visible=controlName==name end
		layouts:SetAttribute("PreviewMenu",name)
		choosing=false
	end
	for _,name in Layout.Names do
		local control=layouts[name]
		table.insert(connections,control:GetPropertyChangedSignal("Visible"):Connect(function()
			if control.Visible and not choosing then choose(name) end
		end))
	end
	table.insert(connections,layouts:GetAttributeChangedSignal("PreviewMenu"):Connect(function() choose(layouts:GetAttribute("PreviewMenu")) end))
	choose(layouts:GetAttribute("PreviewMenu") or "MyArmy")
	game:GetService("Selection"):Set({layouts.MyArmy})
	return "Menu previews ready. Select a menu, edit Size, or change MenuLayouts.PreviewMenu. Save the place to retain your settings."
end

return Editor
