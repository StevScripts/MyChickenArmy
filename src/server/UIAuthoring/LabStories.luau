-- Chicken UI Lab stories: one adapter per screen. Each builds the real client
-- module against a display-only app (editPreview) and fixture state. Requests,
-- notices and menu switching are no-ops; nothing reaches the server. Add a story
-- here when a new screen ships (docs/UI_LAB.md).
local Stories={}

Stories.List={
	{id="Hud",name="HUD (in-game overlay)"},
	{id="MyArmy",name="My Army"},
	{id="Sell",name="Sell Chickens"},
	{id="SellConfirm",name="Sell Chickens · confirm"},
	{id="Shop",name="Shop"},
	{id="Index",name="Chicken Index"},
	{id="Upgrades",name="Upgrades tree"},
	{id="Rebirth",name="Rebirth"},
	{id="RebirthFirst",name="Rebirth (first, not ready)"},
	{id="Invasions",name="Invasions / Missions"},
	{id="Daily",name="Daily reward"},
	{id="Offline",name="Offline earnings"},
	{id="Settings",name="Settings"},
	{id="AutoRoll",name="Auto Roll settings"},
	{id="AutoRollAlert",name="Auto Roll hit alert"},
}

local function noop() end

local function makeApp(ctx)
	local App=require(ctx.code.AppController)
	local app=setmetatable({gui=ctx.gui,panel=ctx.root,other=ctx.root,frames=ctx.root,hudLayer=ctx.root,
		connections={},alive=true,editPreview=true,reducedMotion=true,state=ctx.state,page="Army",
		audio={Play=noop,SetMusic=noop,SetEffects=noop,musicEnabled=true,sfxEnabled=true},
		Request=noop,Notify=noop,SetMenuBlur=noop,ClosePanel=noop,FitPanel=noop,CloseOtherMenus=noop,
		TogglePage=noop,OpenPage=noop,PlaceNotice=noop},App)
	app.commerce=require(ctx.code.CommerceController).new(app)
	return app
end

-- A menu-sized frame at the saved MenuLayouts geometry, like the live panel.
local function menuFrame(ctx,page,name)
	local frame=ctx.Theme.Container(ctx.root,name or page)
	ctx.Layout.Apply(ctx.gui,page,frame)
	return frame
end

local function standardPage(ctx,app,page,title)
	local Theme=ctx.Theme
	local frame=menuFrame(ctx,page)
	local body=Theme.Frame(frame,"Main",UDim2.fromScale(1,1))
	Theme.Surface(body,Theme.PageSurfaces[page] or Theme.Colors.panel)
	local header,titleLabel=Theme.Header(frame,"Header",title,Theme.HeaderColors[page] or Theme.ActionColors.navigation)
	header.PageIcon.Visible=page=="Index"
	header.PageIcon.Image=if page=="Index" then Theme.Assets.Index else Theme.Assets.Luck
	Theme.HeaderClose(header,noop)
	Theme.BelowHeader(header,body)
	app.panel,app.panelHeader,app.panelTitle,app.panelBody=frame,header,titleLabel,body
	return frame,body
end

local Render={}

Render.Hud=function(ctx)
	local app=makeApp(ctx)
	-- The HUD watches the (closed) main panel and its title; give it hidden stand-ins.
	local closed=ctx.Theme.Container(ctx.root,"ClosedPanel");closed.Visible=false
	local title=Instance.new("TextLabel");title.Name,title.Parent="Title",closed
	app.panel,app.panelTitle=closed,title
	app.base=require(ctx.code.BaseController) -- Only its static OpeningGuidance is read.
	local hud=require(ctx.code.HudController).new(app,ctx.root)
	app.hud=hud
	if hud.Resize then hud:Resize() end
	local count,limit,capacity,selected,deployed=app:Counts()
	hud:Update(ctx.state,count,limit,capacity,selected,deployed)
end

Render.MyArmy=function(ctx)
	local app=makeApp(ctx)
	local frame=menuFrame(ctx,"Army","MyArmy")
	local browser=require(ctx.code.ChickenBrowser).new(app,frame)
	app.chickenBrowser,app.panelTitle,app.page=browser,browser.title,"Army"
	app.selected=ctx.state.pets and ctx.state.pets[1] and ctx.state.pets[1].id
	browser.root.Visible=true
	browser:Render(true)
end

-- October 20 Sell screen: two chickens chosen, optionally with the confirmation open.
local function sellStory(ctx,confirm)
	local app=makeApp(ctx)
	local frame=menuFrame(ctx,"Sell")
	local menu=require(ctx.code.SellMenu).new(app,frame)
	app.sellMenu,app.page=menu,"Sell"
	menu.root.Visible=true
	menu:Begin(nil)
	local chosen=0
	for _,pet in ctx.state.pets or {} do
		if chosen<2 and pet.canSell and not pet.favorite and not pet.selected and pet.home~=false then menu:Toggle(pet.id,true);chosen+=1 end
	end
	menu:Render(true)
	if confirm then menu:Review() end
end
Render.Sell=function(ctx) sellStory(ctx,false) end
Render.SellConfirm=function(ctx) sellStory(ctx,true) end

Render.Shop=function(ctx)
	local app=makeApp(ctx)
	app.page="Shop"
	local browser=require(ctx.code.ShopBrowser).new(app,menuFrame(ctx,"Shop"))
	app.shopBrowser=browser
	browser.root.Visible=true
	browser:Render(true)
end

Render.Index=function(ctx)
	local app=makeApp(ctx)
	app.page="Index"
	local _,body=standardPage(ctx,app,"Index","Chicken Index")
	local browser=require(ctx.code.IndexBrowser).new(app,body)
	browser.root.Position,browser.root.Size=UDim2.fromScale(0.02,0.02),UDim2.fromScale(0.96,0.96)
	browser.root.Visible=true
	browser:Render(true)
	ctx.Theme.ApplyPopupStyle(app.panel)
end

Render.Upgrades=function(ctx)
	local app=makeApp(ctx)
	local browser=require(ctx.code.ResearchBrowser).new(app,ctx.root)
	app.research=browser
	browser.root.Visible=true
	browser:Receive(ctx.state)
	browser:Render()
end

-- October 20 overhaul (S8): the reference Rebirth screen at its saved geometry.
-- The late-game preset is a Rebirth 10 player who can afford Rebirth 11.
Render.Rebirth=function(ctx)
	local app=makeApp(ctx)
	app.other=menuFrame(ctx,"Rebirth","Rebirth")
	local panel=require(ctx.code.RebirthPanel).new(app)
	app.rebirthPanel=panel
	panel:Render(ctx.state)
	panel:Open()
end

-- The first Rebirth before it is affordable (the reference's 3,019 / 50,000 screen):
-- a silhouette reward, no Gems, and the Rebirth 2+ rows locked.
local FIRST_PRICES={RollSpeed=5,ExtraLuck=5,VacuumCapacity=10,AutoRoll=15,CoinBoost=10,AutoRebirth=25,
	TimeSkip=20,MoreGems=25,KeepUpgrades=40,Rally=30,MutationLuck=40,OfflineCoins=30,ArmyPower=50,RebirthChickenOdds=30}
Render.RebirthFirst=function(ctx)
	local state=ctx.state
	state.gems,state.gemsEarned=0,0
	local quote=state.rebirth or {}
	state.rebirth=quote
	quote.rank,quote.nextRank,quote.cost,quote.coins,quote.eligible=0,1,50000,3019,false
	quote.multiplierNow,quote.multiplierNext,quote.gemsNext,quote.timeSkipMinutes=1,2,50,5
	quote.nextChicken={species="Veteran1",name="Private Peck",rarity="Uncommon"}
	quote.skip={credits=0,productKey="RebirthSkip1",onSale=true,restricted=false}
	local upgrades=state.gemUpgrades or {}
	upgrades.autoRebirth={owned=false,enabled=true}
	for id,item in upgrades.items or {} do
		item.level,item.price=(if id=="TimeSkip" then 1 else 0),FIRST_PRICES[id]
		item.status=if (item.unlockRank or 0)>0 then "Locked" else "Unaffordable"
	end
	Render.Rebirth(ctx)
end

Render.Invasions=function(ctx)
	local app=makeApp(ctx)
	local panel=require(ctx.code.OperationsPanel).new(app)
	app.operationsPanel=panel
	panel:Render(ctx.state)
	panel:Open()
end

Render.Daily=function(ctx)
	local app=makeApp(ctx)
	local daily=ctx.state.daily or {}
	local controller=require(ctx.code.DailyRewardController).new(app)
	controller:Show({day=math.max(1,(daily.streak or 0)+1),cash=50000,slot=math.max(1,(daily.streak or 0)+1),
		streak=math.max(1,(daily.streak or 0)+1),rolls=1})
end

Render.Offline=function(ctx)
	local app=makeApp(ctx)
	app.other=menuFrame(ctx,"Offline","OfflineEarnings")
	require(ctx.code.OfflineCashController).new(app):Receive({offlineCash={id="ui-lab",amount=25920,awaySeconds=10800,countedSeconds=10800}})
end

Render.Settings=function(ctx)
	local app=makeApp(ctx)
	app.page="Settings"
	local _,body=standardPage(ctx,app,"Settings","Settings")
	local content=Instance.new("ScrollingFrame")
	content.Name,content.Size,content.Position="Content",UDim2.fromScale(0.96,0.96),UDim2.fromScale(0.02,0.02)
	content.BackgroundTransparency,content.BorderSizePixel,content.ScrollBarThickness=1,0,0
	content.AutomaticCanvasSize,content.CanvasSize,content.Parent=Enum.AutomaticSize.None,UDim2.new(),body
	local padding=Instance.new("UIPadding")
	padding.PaddingLeft,padding.PaddingTop,padding.PaddingBottom=UDim.new(0.01,0),UDim.new(0.01,0),UDim.new(0.02,0)
	padding.Parent=content
	local list=Instance.new("UIListLayout");list.Padding,list.SortOrder,list.Parent=UDim.new(0.025,0),Enum.SortOrder.LayoutOrder,content
	app.content,app.contentLayout=content,list
	app:ClearPanel()
	app:RenderSettings()
	app:FitContentCanvas()
	ctx.Theme.ApplyPopupStyle(app.panel)
end

-- October 20 Auto Roll (S12): unlocked, holding the rarest Mythic, Gold Machine owned.
local function autoRollFixture(state)
	local Catalog=require(game:GetService("ReplicatedStorage").PetRoll.Shared.PetCatalog)
	local held
	for _,id in Catalog.Order do
		local definition=Catalog[id]
		if definition.rarity=="Mythic" and definition.oneIn and (not held or definition.oneIn>Catalog[held].oneIn) then held=id end
	end
	held=held or "Duck"
	state.autoRoll={enabled=true,unlocked=true,stopAt=20000,recruitAt=1000,mutationStop=true,upgradeStop=true,holding=true,
		held={offerId="ui-lab",slot=2,species=held,level=1,price=250000,mutation="Golden",oneIn=Catalog[held].oneIn,
			reason="rarity",canAfford=true,storageFull=false}}
	state.goldRolls={machine=1,kind="Gold",every=10,count=7,left=3,luck=2,ready=false}
	state.coins=math.max(state.coins or 0,500000)
end

Render.AutoRoll=function(ctx)
	local app=makeApp(ctx)
	autoRollFixture(ctx.state)
	local menu=require(ctx.code.AutoRollMenu).new(app)
	app.autoRollMenu=menu
	menu:Render(ctx.state)
	menu:Open()
end

Render.AutoRollAlert=function(ctx)
	local app=makeApp(ctx)
	-- The alert waits while a menu is open; the story has none.
	local closed=ctx.Theme.Container(ctx.root,"ClosedPanel");closed.Visible=false
	app.panel=closed
	autoRollFixture(ctx.state)
	local menu=require(ctx.code.AutoRollMenu).new(app)
	app.autoRollMenu=menu
	menu:Render(ctx.state)
end

function Stories.Render(id,ctx)
	local render=Render[id]
	assert(render,"Unknown UI Lab story: "..tostring(id))
	render(ctx)
end

return Stories
