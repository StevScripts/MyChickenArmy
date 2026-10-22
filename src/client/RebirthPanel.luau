--!strict
-- Rebirth screen (October 20 overhaul, S8): a 1:1 copy of the owner's reference
-- (Drop a Fruit's Rebirth screen) in the game's style, built to plan v2's element
-- spec. Left: the warning, Rebirth to Earn (Time Skip, Gems, Multiplier), the Coins
-- bar toward the next Rebirth with the chicken to find for it (October 22: a
-- silhouette until it is in the Index), Rebirth and Skip! KEEP UPGRADES. Right: Gem Upgrades
-- (GemUpgradeGrid). As in the reference, Rebirth is one tap and the screen stays
-- open afterwards, with confetti. The server quote (state.rebirth,
-- docs/team/OVERHAUL_CONTRACT_20261020.md §7) is authoritative; this module never
-- changes saved state. Opened from the HUD Rebirth button; AppController calls
-- Render(state, result) on every packet. Contract: docs/team/REBIRTH_SCREEN.md.
local GuiService=game:GetService("GuiService")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Theme=require(script.Parent.UITheme)
local MenuLayout=require(script.Parent.MenuLayout)
local Assets=require(script.Parent.ResearchAssets)
local Portraits=require(script.Parent.ChickenPortraits)
local GemUpgradeGrid=require(script.Parent.GemUpgradeGrid)
local PetCatalog=require(Shared.PetCatalog)
local MutationCatalog=require(Shared.MutationCatalog)
local ShopCatalog=require(Shared.ShopCatalog)
local Panel={}
Panel.__index=Panel

local GREEN=Theme.ReferenceColors.Army
local WHITE,BLACK=Color3.new(1,1,1),Color3.new(0,0,0)
local WARNING=Color3.fromRGB(255,120,132)
local QUIET=Color3.fromRGB(84,102,91)
local TRACK=Color3.fromRGB(11,14,10)
local GOLD_TOP,GOLD_BOTTOM=Color3.fromRGB(255,214,0),Color3.fromRGB(255,149,0)
local ROBUX_GREEN=Color3.fromRGB(76,250,32)
local KEEP_GOLD=Color3.fromRGB(255,226,92)
local TAG=Color3.fromRGB(16,23,18)
local ROBUX=utf8.char(0xE002)
local TILES={
	TimeSkip={Color3.fromRGB(63,186,255),Color3.fromRGB(22,119,223)},
	Gems={Theme.GemColors.Top,Theme.GemColors.Bottom},
	Multiplier={Color3.fromRGB(95,207,71),Color3.fromRGB(44,154,39)},
}
local CONFETTI={Color3.fromRGB(255,214,48),Color3.fromRGB(99,239,0),Color3.fromRGB(63,186,255),
	Color3.fromRGB(255,94,139),Color3.fromRGB(168,94,242)}
-- Mock pixels of the 1710 x 883 reference window (plan v2 element spec, 1.94:1).
local W,H=1710,883
local HEADER=W/Theme.HeaderAspect
local BODY={0,HEADER,W,H-HEADER}
local EARN={18,235,695,203}
local RANK={18,453,695,282}
local CHICKEN={268,589,195,143}
local GEM_PANEL={743,158,945,685}
local PENDING_SECONDS=10
-- October 21 (P4): the boom, fanfare and confetti take about this long; the Time Skip
-- claim popup (TimeSkipController) waits for celebratingUntil before it opens.
local CELEBRATE_SECONDS=2.2
-- October 21 game feel (docs/team/GAME_FEEL_20261021.md): an authored cue, or its
-- fallback until the sound session adds it (UI Lab previews stub audio without Has).
-- Presentation only; one client audio.
local Audio=nil
local function cue(name,fallback,pitch,options)
	if not Audio then return end
	if type(Audio.Has)=="function" and Audio:Has(name) then Audio:Play(name,pitch,options)
	elseif fallback then Audio:Play(fallback,pitch,options) end
end

-- Places `item` at a mock-pixel rectangle, relative to `frame` (another rectangle
-- in the same pixels; by default the body under the header).
local function rect(item,x,y,w,h,frame)
	local box=frame or BODY
	item.Position=UDim2.fromScale((x-box[1])/box[3],(y-box[2])/box[4])
	item.Size=UDim2.fromScale(w/box[3],h/box[4])
	return item
end

local function label(parent,name,text,size,color)
	local item=Theme.Label(parent,name,text,size,color or WHITE)
	item.TextScaled,item.TextXAlignment,item.ZIndex=true,Enum.TextXAlignment.Center,6
	return item
end

-- The reference's dark see-through boxes (DESIGN.md inset); they own their colours.
local function inset(parent,name,box)
	local frame=rect(Theme.Frame(parent,name,UDim2.new(),BLACK),box[1],box[2],box[3],box[4])
	frame.BackgroundTransparency=0.66
	frame:SetAttribute("OwnsPopupStyle",true)
	Theme.Stroke(frame,QUIET,3).Transparency=0.3
	return frame
end

-- Player-facing rank names are "Rebirth 1", "Rebirth 2", … (October 14 glossary).
-- The server quote's title/nextTitle strings are ignored; only the numbers count.
function Panel.Title(rank: number): string
	rank=math.max(0,math.floor(rank or 0))
	if rank==0 then return "No rebirths yet" end
	return "Rebirth "..rank
end

-- The foundation stub carries only {rank, eligible, reason}; the full quote has
-- version = 2 (a launch-era quote has kingCleared instead).
local function full(quote): boolean
	return type(quote)=="table" and (quote.version==2 or quote.kingCleared~=nil)
end

local function enabled(quote): boolean
	return type(quote)=="table" and quote.enabled~=false
end

-- The rank the Coins bar buys, or nil at the maximum (the server omits nextRank).
local function nextRank(quote): number?
	return if quote.nextRank~=nil then tonumber(quote.nextRank) else nil
end

local function multiplierText(value): string
	local text=string.format("%.2f",tonumber(value) or 1)
	text=text:gsub("0+$","")
	text=text:gsub("%.$","")
	return "×"..text
end

-- Readable reason for a refused tap (the server reason has raw digits).
local function refusal(quote): string
	local cost,coins=tonumber(quote.cost),tonumber(quote.coins) or 0
	if cost and coins<cost then return "Need "..Theme.Number(cost-coins).." more Coins" end
	if quote.armyHome==false or quote.missionRunning==true then return "Bring your Army home first" end
	return if type(quote.reason)=="string" and quote.reason~="" then quote.reason else "Not ready yet"
end

-- Rebirth chickens use their base look until the art pass adds their portraits.
local function portraitSpecies(species: string): string
	local images=Portraits::any
	if images[species] then return species end
	local definition=PetCatalog[species]
	local base=definition and definition.baseSpecies
	return if base and images[base] then base else species
end

local function mutationName(id): string
	local definition=MutationCatalog.Defs and MutationCatalog.Defs[id]
	return if definition and definition.name then definition.name else tostring(id)
end

function Panel.new(app)
	Audio=app.audio
	return setmetatable({app=app,connections={},quote=nil,state=nil,lastRank=nil,pending=nil,ready=false,skipReady=false,celebratingUntil=0},Panel)
end

-- Panel --------------------------------------------------------------------
function Panel:Open()
	local quote=self.quote
	if not enabled(quote) or self.app.commerce.cratePresenting then return end
	if not full(quote) then self.app:Notify(quote.reason or "Coming soon","info");return end
	if self.gui and not self.closing then self:RenderPanel();return end
	self:Dismiss(true)
	local research=self.app.research
	self.fromResearch=research~=nil and research.root.Visible
	-- Acquire the blur before closing the other menu so its exit cannot clear it.
	self.app:SetMenuBlur("rebirth",true)
	-- One modal at a time (Close reopens the Upgrades tree when Rebirth came from it).
	self.app:CloseOtherMenus("rebirth")
	self.previousSelection=GuiService.SelectedObject
	self:Build()
	self:RenderPanel()
	if self.app.editPreview then return end
	ContextActionService:BindActionAtPriority("PetRollReenlistClose",function(_,inputState)
		if inputState==Enum.UserInputState.Begin then self:Close() end
		return Enum.ContextActionResult.Sink
	end,false,3000,Enum.KeyCode.ButtonB)
	local function connect(signal,callback) table.insert(self.connections,signal:Connect(callback)) end
	connect(UserInputService.InputBegan,function(input)
		-- Escape over the Time Skip popup claims there; this window stays open beneath it.
		local timeSkip=self.app.timeSkip
		if input.KeyCode==Enum.KeyCode.Escape and not (timeSkip and timeSkip.gui) then self:Close() end
	end)
	-- Another menu opening replaces this one.
	if self.app.panel then
		connect(self.app.panel:GetPropertyChangedSignal("Visible"),function() if self.app.panel.Visible then self.fromResearch=false;self:Dismiss(true) end end)
	end
	if research then
		connect(research.root:GetPropertyChangedSignal("Visible"),function() if research.root.Visible then self.fromResearch=false;self:Dismiss(true) end end)
	end
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=self.rebirthButton end
end

function Panel:Build()
	local app=self.app
	local gui=if app.editPreview then Theme.Container(app.other,"Reenlist")
		else Theme.InsetContainer(app.other,"Reenlist",Enum.ScreenInsets.CoreUISafeInsets)
	gui.ZIndex=30
	self.gui,self.closing=gui,false
	local frames=Theme.Container(gui,"FRAMES")
	-- The blocker covers the full device screen, past phone notches; a tap on it closes.
	local backdropParent=if app.editPreview then frames else Theme.InsetContainer(frames,"BackdropLayer",Enum.ScreenInsets.None)
	local backdrop=Theme.Frame(backdropParent,"Backdrop",UDim2.fromScale(1,1))
	backdrop.BackgroundTransparency,backdrop.Active=1,true
	table.insert(self.connections,backdrop.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then self:Close() end
	end))
	local panel=Instance.new("CanvasGroup")
	panel.Name="Reenlist"
	panel.BackgroundTransparency,panel.BorderSizePixel,panel.GroupTransparency=1,0,1
	panel.Active,panel.ZIndex=true,2
	panel.Parent,self.panel=frames,panel
	-- Studio may author PetRollGui.MenuLayouts.Rebirth; the default is the reference
	-- window, 0.86 of the screen wide at 1.94:1.
	MenuLayout.Apply(app.gui,"Rebirth",panel)
	-- Edit previews (UI Lab, menu editor) pass a frame that already has the saved geometry.
	if app.editPreview then
		panel.Size,panel.Position,panel.AnchorPoint=UDim2.fromScale(1,1),UDim2.fromScale(0.5,0.5),Vector2.new(0.5,0.5)
	end
	self.panelSize,self.panelPosition=panel.Size,panel.Position
	local header=Theme.Header(panel,"Header","Rebirth",GREEN)
	-- The shared header's icon slot carries the Rebirth badge (title shifts right).
	header.PageIcon.Image,header.PageIcon.Visible=Theme.Assets.Reenlist,true
	Theme.LayoutHeader(header)
	local main=Theme.Container(panel,"Main")
	Theme.BelowHeader(header,main)
	Theme.Surface(main,Theme.PageSurfaces.Army)
	main.UIStroke.BorderStrokePosition=Enum.BorderStrokePosition.Inner
	self:BuildRewards(main)
	self:BuildButtons(main)
	local gemPanel=inset(main,"GemUpgradesPanel",GEM_PANEL)
	local aspect=panel:FindFirstChildWhichIsA("UIAspectRatioConstraint")
	local ratio=if aspect then aspect.AspectRatio else W/H
	-- The inset's own width:height on screen sizes the grid's scroll canvas.
	local frameAspect=(GEM_PANEL[3]/W)/((GEM_PANEL[4]/BODY[4])*(1/ratio-1/Theme.HeaderAspect))
	self.grid=GemUpgradeGrid.new(app,gemPanel,frameAspect)
	Theme.HeaderClose(header,function() self:Close() end,1.22) -- phone hit area: 48 px
	Theme.ApplyPopupStyle(panel)
	Theme.ScaleText(panel)
	local restingSize,restingPosition=self.panelSize,self.panelPosition
	if not app.reducedMotion then
		panel.Size=UDim2.fromScale(restingSize.X.Scale*.94,restingSize.Y.Scale*.94)
		panel.Position=UDim2.fromScale(restingPosition.X.Scale,restingPosition.Y.Scale+.035)
	end
	Theme.Motion:Tween(panel,"reenlist-size",{Size=restingSize},.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out)
	Theme.Motion:Tween(panel,"position",{Position=restingPosition},.28)
	Theme.Motion:Tween(panel,"reenlist-fade",{GroupTransparency=0},.22)
	-- The HUD button's Click already answered the press; MenuOpen joins it once authored.
	cue("MenuOpen",nil,nil,{voiceKey="MenuOpen",cooldown=0.2})
	-- The Rebirth to Earn tiles grow in one after another.
	Theme.Motion:Reveal(self.earn,{limit=6,window=0.3,from=0.75})
	self.ready,self.skipReady=false,false
end

-- Warning, Rebirth to Earn and the Coins bar with the next Rebirth's chicken.
function Panel:BuildRewards(main)
	local warning=rect(label(main,"Warning","You will lose all Coins and Upgrades\nwhen you rebirth!",27,WARNING),18,156,695,70)
	warning.TextWrapped=true
	local earn=inset(main,"RebirthToEarn",EARN)
	self.earn=earn
	rect(label(earn,"Title","Rebirth to Earn:",38),18,243,695,46,EARN)
	self.timeSkip=self:Tile(earn,"TimeSkip","TIME SKIP",{48,290,205,140},"TimeSkip")
	self.gemsReward=self:Tile(earn,"Gems","GEMS",{263,290,205,140},"Gems")
	self.multiplier=self:Tile(earn,"Multiplier","MULTIPLIER",{478,290,210,140},nil)
	local rankBox=inset(main,"NextRebirth",RANK)
	self.rankTitle=rect(label(rankBox,"Title","",48),18,466,695,52,RANK)
	-- Same resting rects; the title and Coins line punch from their middles.
	Theme.Motion:Center(self.rankTitle)
	local track=rect(Theme.Frame(rankBox,"CostProgress",UDim2.new(),TRACK),78,525,595,56,RANK)
	track.ZIndex=2
	Theme.Stroke(track,BLACK,3)
	local fill=Theme.Frame(track,"Fill",UDim2.fromScale(0,1),WHITE)
	Theme.Gradient(fill,GOLD_TOP,GOLD_BOTTOM)
	self.costFill=fill
	self.costText=label(track,"Label","",33)
	self.costText.Position,self.costText.Size=UDim2.fromScale(0.08,0.05),UDim2.fromScale(0.84,0.9)
	Theme.Motion:Center(self.costText)
	-- The coin overlaps the bar's left end, as in the reference.
	local coin=rect(Theme.Image(rankBox,"CostIcon",Theme.Assets.Coin,UDim2.new()),33,503,100,100,RANK)
	coin.ZIndex=4
	Theme.Aspect(coin,1)
	self:BuildChicken(rankBox)
end

-- A Rebirth to Earn tile: uppercase label, icon and big value on a studded card.
function Panel:Tile(parent,name: string,caption: string,box,gemKey: string?)
	local frame=rect(Theme.Frame(parent,name,UDim2.new(),WHITE),box[1],box[2],box[3],box[4],EARN)
	local colors=TILES[name]
	Theme.Gradient(frame,colors[1],colors[2])
	Theme.Studs(frame,0.07,28,0):SetAttribute("StudScaleWidth",1.6)
	Theme.Stroke(frame,BLACK,3)
	local own={0,0,box[3],box[4]}
	rect(label(frame,"Label",caption,20),4,6,box[3]-8,24,own)
	-- Big icons (owner, October 20); the value overlaps the icon's lower edge, as in the reference.
	local icon=if gemKey then Theme.GemIcon(frame,"Icon",gemKey,UDim2.new()) else Theme.Image(frame,"Icon",Assets.cashEggValue,UDim2.new())
	rect(icon,(box[3]-96)/2,22,96,96,own)
	icon.ZIndex=5
	Theme.Aspect(icon,1)
	return rect(label(frame,"Value","",32),4,96,box[3]-8,38,own)
end

-- The chicken to find for the next Rebirth on a glow of its rarity colour: name,
-- picture, then "Find to Rebirth" or "Found!" (October 22).
function Panel:BuildChicken(rankBox)
	local own={0,0,CHICKEN[3],CHICKEN[4]}
	local tile=rect(Theme.Frame(rankBox,"NextChicken",UDim2.new(),BLACK),CHICKEN[1],CHICKEN[2],CHICKEN[3],CHICKEN[4],RANK)
	tile.BackgroundTransparency,tile.ClipsDescendants=0.55,true
	Theme.Stroke(tile,QUIET,3).Transparency=0.2
	self.glow={}
	for index,size in {150,118,88,60} do
		local disk=rect(Theme.Frame(tile,"Glow"..index,UDim2.new(),WHITE),(CHICKEN[3]-size)/2,73-size/2,size,size,own)
		Theme.Round(disk).CornerRadius=UDim.new(0.5,0)
		Theme.Aspect(disk,1)
		disk.BackgroundTransparency,disk.ZIndex=0.84,2
		table.insert(self.glow,disk)
	end
	self.chickenName=rect(label(tile,"Name","",23),4,4,CHICKEN[3]-8,26,own)
	-- One line each: at the readable floor a long name would stack over the art.
	self.chickenName.TextWrapped=false
	local art=rect(Theme.Container(tile,"Art"),47.5,26,100,100,own)
	art.ZIndex=4
	Theme.Aspect(art,1)
	self.chickenRarity=rect(label(tile,"Rarity","",21),4,115,CHICKEN[3]-8,24,own)
	self.chickenRarity.TextWrapped=false
	self.chickenTile,self.chickenArt=tile,art
end

-- Rebirth (one tap, as in the reference) and Skip! KEEP UPGRADES with its Robux tag.
function Panel:BuildButtons(main)
	local rebirth=rect(Theme.ActionButton(main,"Rebirth","Rebirth",function() self:PressRebirth() end,GREEN),23,758,335,90)
	Theme.PadHit(rebirth,1,123/90) -- phone hit area: 48 px tall (123 units)
	local caption=rebirth.Visual.Caption
	caption.Position,caption.Size,caption.TextScaled=UDim2.fromScale(0.04,0.1),UDim2.fromScale(0.92,0.8),true
	caption.TextShadow.Visible=false
	self.rebirthButton=rebirth
	local skip=rect(Theme.ActionButton(main,"Skip","Skip!",function() self:PressSkip() end,Theme.Arcade.purple),378,758,335,90)
	Theme.PadHit(skip,1,123/90)
	Theme.ApplyReferenceAccent(skip,ColorSequence.new(Theme.GemColors.SkipTop,Theme.GemColors.SkipBottom))
	local skipCaption=skip.Visual.Caption
	skipCaption.Position,skipCaption.Size,skipCaption.TextScaled=UDim2.fromScale(0.04,0.02),UDim2.fromScale(0.92,0.62),true
	skipCaption.TextShadow.Visible=false
	local keep=label(skip.Visual,"KeepUpgrades","KEEP UPGRADES",21,KEEP_GOLD)
	keep.Position,keep.Size=UDim2.fromScale(0.04,0.64),UDim2.fromScale(0.92,0.3)
	self.skipButton=skip
	local tag=rect(Theme.Frame(main,"RobuxTag",UDim2.new(),TAG),612,733,116,48)
	tag.ZIndex=8
	tag:SetAttribute("OwnsPopupStyle",true)
	Theme.Stroke(tag,WHITE,3).Transparency=0.45
	Theme.Motion:Center(tag)
	self.robuxText=label(tag,"Price","",30,ROBUX_GREEN)
	self.robuxText.Position,self.robuxText.Size=UDim2.fromScale(0.06,0.06),UDim2.fromScale(0.88,0.88)
	self.robuxTag=tag
end

function Panel:SetPortrait(species: string)
	local look=portraitSpecies(species)
	if self.portraitLook==look then return end
	if self.portrait then self.portrait:Destroy();self.portrait=nil end
	self.portraitLook=look
	-- A chicken this client's catalog doesn't know yet shows no picture.
	if not (Portraits::any)[look] and not PetCatalog[look] then return end
	self.portrait=self.app:Preview(self.chickenArt,{species=look,stars=1,level=1},UDim2.fromScale(1,1),UDim2.new())
	self.portrait.ZIndex=4
end

function Panel:RenderPanel()
	if not self.gui or not self.panel or self.closing then return end
	local quote=self.quote
	if type(quote)~="table" then return end
	local rank=tonumber(quote.rank) or 0
	local target=nextRank(quote)
	local cost,coins=tonumber(quote.cost),tonumber(quote.coins) or 0
	local minutes=tonumber(quote.timeSkipMinutes)
	self.timeSkip.Text=if minutes then math.floor(minutes).." min" else "—"
	local gems=tonumber(quote.gemsNext)
	self.gemsReward.Text=if gems then "+"..Theme.Money(gems) else "—"
	self.multiplier.Text=multiplierText(quote.multiplierNext or quote.multiplierNow)
	self.rankTitle.Text=Panel.Title(target or rank)
	local progress=if cost and cost>0 then math.clamp(coins/cost,0,1) else 1
	-- The bar fills with the shared Progress (no flash: Coins arrive every packet).
	Theme.Motion:Progress(self.costFill,progress,.3,false)
	-- As in the reference, the bar shows the real balance, even past the cost. October 22
	-- (Stevin): abbreviated numbers (50K, 1M, 14.6M … 3.13Qa), never the full digits.
	self.costText.Text=if target and cost then Theme.Number(coins).." / "..Theme.Number(cost) else "Highest rank reached"
	self:RenderChicken(quote,target~=nil)
	-- Rebirth stays green and answers every tap; a refused tap says why.
	local rebirth=self.rebirthButton
	rebirth.Text=if self.pending then "Rebirthing…" elseif target then "Rebirth" else "Max rank"
	rebirth.Active=target~=nil
	local tint=if target then GREEN else Theme.ActionColors.disabled
	if rebirth.BackgroundColor3~=tint then
		rebirth.BackgroundColor3=tint
		if tint==GREEN then Theme.ApplyReferenceAccent(rebirth,Theme.ReferenceGradients.Army) end
	end
	-- Affordable (and the Army home): the button breathes inside a green glow. The
	-- loops stop the moment it is not, when a Rebirth is in flight, and on Dismiss.
	local ready=quote.eligible==true and target~=nil and self.pending==nil
	if ready~=self.ready then
		self.ready=ready
		if ready then
			Theme.Motion:Breathe(rebirth.Visual,1.05,0.7)
			Theme.Motion:Glow(rebirth,GREEN,4)
		else
			Theme.Motion:StopBreathe(rebirth.Visual)
			Theme.Motion:StopGlow(rebirth)
		end
	end
	self:RenderSkip(quote,target~=nil)
	if self.grid then self.grid:Render(self.state) end
end

-- October 22 (Stevin: "you had to find that chicken first"): the tile is the chicken to
-- FIND before this Rebirth, not a reward. A black silhouette captioned "Find to
-- Rebirth" until it is in the Index (owned once, sold or not), then in colour with
-- "Found!". Ranks past Config.Rebirth.FindRanks have no tile (quote.find is nil).
function Panel:RenderChicken(quote,hasNext: boolean)
	local find=quote.find
	local shown=hasNext and type(find)=="table" and type(find.species)=="string"
	self.chickenTile.Visible=shown
	if not shown then self.findFound=nil;return end
	local definition=PetCatalog[find.species]
	local rarity=find.rarity or (definition and definition.rarity) or "Common"
	local color=Theme.Rarities[rarity] or WHITE
	local found=find.found==true
	self.chickenName.Text=find.name or (definition and definition.name) or ""
	self.chickenRarity.Text=if found then "Found!" else "Find to Rebirth"
	self.chickenRarity.TextColor3=if found then GREEN else color
	for _,disk in self.glow do disk.BackgroundColor3=color end
	self:SetPortrait(find.species)
	if self.portrait then self.portrait.ImageColor3=if found then WHITE else BLACK end
	-- The tile punches once when the find lands while the screen is open.
	if found and self.findFound==false then Theme.Motion:Punch(self.chickenTile,1.15,0.35) end
	self.findFound=found
end

-- Skip! hides where paid random items are restricted (its Gems buy luck) and while
-- its products are off sale. A bought Skip waits as a credit and reads "Ready!".
function Panel:RenderSkip(quote,hasNext: boolean)
	local skip=if type(quote.skip)=="table" then quote.skip else nil
	local credits=tonumber(skip and skip.credits) or 0
	local shown=skip~=nil and hasNext and skip.restricted~=true and (credits>0 or skip.onSale==true)
	self.skipButton.Visible,self.robuxTag.Visible=shown,shown
	if not shown then return end
	-- A bought Skip arriving as a credit: the tag punches to "Ready!".
	local skipReady=credits>0
	if skipReady and not self.skipReady then Theme.Motion:Punch(self.robuxTag,1.25,0.32);cue("Badge","Pop",nil,{voiceKey="SkipReady",cooldown=1}) end
	self.skipReady=skipReady
	if credits>0 then self.robuxText.Text="Ready!";return end
	local key=skip.productKey
	local commerce=self.app.commerce
	if type(key)~="string" then self.robuxText.Text=ROBUX.." …";return end
	if commerce then commerce:Load(key) end
	local entry=commerce and commerce.products[key]
	local definition=ShopCatalog.Products and ShopCatalog.Products[key]
	local price=if entry and type(entry.price)=="number" then entry.price elseif definition then definition.proposedPrice else nil
	self.robuxText.Text=ROBUX.." "..(if type(price)=="number" then Theme.Money(price) else "…")
end

function Panel:SetPending(id,rank: number)
	self.pending={id=id,rank=rank}
	self:RenderPanel()
	-- Unlock after a lost reply; the server's expectedRank check rejects repeats.
	task.delay(PENDING_SECONDS,function()
		if self.pending and self.pending.id==id then self.pending=nil;self:RenderPanel() end
	end)
end

function Panel:PressRebirth()
	local quote=self.quote
	if not self.gui or self.closing or self.pending or type(quote)~="table" then return end
	if quote.eligible~=true then
		self.app:Notify(refusal(quote),false)
		Theme.Motion:Shake(self.rebirthButton.Visual,4)
		return
	end
	local rank=tonumber(quote.rank) or 0
	local id=self.app:Request("Rebirth",{expectedRank=rank})
	if not id then return end
	self:SetPending(id,rank)
	Theme.Motion:Pop(self.rebirthButton.Visual,1.06)
	Theme.Motion:Shine(self.rebirthButton.Visual.Face)
end

function Panel:PressSkip()
	local quote=self.quote
	local skip=if type(quote)=="table" and type(quote.skip)=="table" then quote.skip else nil
	if not skip or self.pending then return end
	local rank=tonumber(quote.rank) or 0
	if (tonumber(skip.credits) or 0)>0 then
		-- Spending a bought Skip rebirths now, resets nothing and pays every reward.
		local id=self.app:Request("Rebirth",{expectedRank=rank,useSkip=true})
		if id then
			self:SetPending(id,rank)
			cue("Whoosh",nil,nil,{voiceKey="TimeSkip",cooldown=0.3})
			Theme.Motion:Punch(self.costText,1.15,0.3)
		end
		return
	end
	-- Otherwise the Robux prompt; the receipt adds a credit the server then spends.
	local commerce,key=self.app.commerce,skip.productKey
	if not commerce or type(key)~="string" then return end
	commerce:Load(key)
	local status=commerce:State(key)
	if status=="loading" then self.app:Notify("Getting Skip ready… try again in a moment.","info");return end
	commerce:Buy(key)
	if commerce.pending and commerce.pending.key==key then self.skipRequest=commerce.pending.requestId
	elseif status~="ready" then self.app:Notify("Skip isn't available right now.",false) end
end

-- Falling confetti over the open screen (the reference's Rebirth moment).
function Panel:Confetti()
	if Theme.Motion.reduced or not self.gui then return end
	local layer=self.gui:FindFirstChild("FRAMES")
	if not layer then return end
	local holder=Theme.Container(layer,"Confetti")
	holder.ZIndex=10
	for index=1,28 do
		local piece=Instance.new("Frame")
		piece.Name,piece.BorderSizePixel,piece.AnchorPoint="Piece",0,Vector2.new(0.5,0.5)
		piece.BackgroundColor3=CONFETTI[(index-1)%#CONFETTI+1]
		piece.Size=UDim2.fromScale(0.011,0.022)
		local x=0.08+math.random()*0.84
		piece.Position,piece.Rotation=UDim2.fromScale(x,-0.04),math.random(0,360)
		piece.Parent=holder
		TweenService:Create(piece,TweenInfo.new(1.1+math.random()*0.7,Enum.EasingStyle.Quad,Enum.EasingDirection.In,0,false,math.random()*0.3),
			{Position=UDim2.fromScale(x+(math.random()-0.5)*0.2,1.05),Rotation=piece.Rotation+math.random(-360,360),BackgroundTransparency=0.35}):Play()
	end
	task.delay(2.6,function() holder:Destroy() end)
end

-- `receipt` is the Rebirth result's {rank, gems, species, skip, ...} when this packet
-- carries it (player, Skip credit or Auto Rebirth); otherwise the last quote says
-- what the rank paid.
function Panel:Celebrate(before,quote,receipt)
	local rank=tonumber(quote.rank) or 0
	self.celebratingUntil=os.clock()+CELEBRATE_SECONDS
	-- The deep Rebirth boom, then the Fanfare a beat later; the world flashes green
	-- with a quick zoom (ScreenFeel; the camera stays with the player).
	cue("Rebirth","Victory",nil,{voiceKey="Rebirth",cooldown=1})
	task.delay(0.3,function() if self.app.alive~=false then cue("Fanfare",nil,nil,{voiceKey="Fanfare",cooldown=1}) end end)
	if self.app.screenFeel then self.app.screenFeel:Celebrate(GREEN,3) end
	-- "Rebirth N" punches when the rank changes (October 22: no chicken joins; the
	-- rank's chicken was found beforehand).
	if self.gui and not self.closing and self.rankTitle then Theme.Motion:Punch(self.rankTitle,1.2,0.32) end
	local parts={Panel.Title(rank).."!"}
	if receipt and receipt.skip==true then table.insert(parts,"Upgrades kept") end
	local gems=tonumber(receipt and receipt.gems) or tonumber(type(before)=="table" and before.gemsNext)
	if gems and gems>0 then table.insert(parts,"+"..Theme.Gems(gems)) end
	table.insert(parts,multiplierText(quote.multiplierNow).." egg Coins")
	-- October 21 (P4): the Coins stay at 0; Time Skip waits for its claim popup. A Skip
	-- Rebirth keeps the run, so its Time Skip was paid at once.
	local skipCoins=tonumber(receipt and receipt.timeSkipCoins) or 0
	if receipt and receipt.skip==true then
		if skipCoins>0 then table.insert(parts,"Time Skip: +"..Theme.CompactCoins(skipCoins)) end
	else
		local waiting=if type(quote.timeSkipPending)=="table" then tonumber(quote.timeSkipPending.coins) else nil
		local ready=waiting or skipCoins
		if ready and ready>0 then table.insert(parts,"Time Skip ready: +"..Theme.CompactCoins(ready)) end
	end
	local unlock=if type(before)=="table" then before.unlockNext else nil
	if type(unlock)=="table" and unlock.name then table.insert(parts,mutationName(unlock.name).." mutations unlocked") end
	self.app:Notify(table.concat(parts," · "),true)
	-- As in the reference, an open screen stays up and moves on to the next Rebirth.
	if self.gui and not self.closing then self:Confetti()
	elseif not self.app.reducedMotion and self.app.gui and self.app.gui:FindFirstChild("Shell") then
		Theme.Motion:Burst(self.app.gui.Shell,UDim2.fromScale(.5,.45),GREEN)
	end
end

function Panel:Close()
	if not self.gui or self.closing then return end
	local reopen=self.fromResearch
	self:Dismiss()
	-- Deferred so the same Escape/B press cannot also close the reopened map.
	if reopen then
		task.defer(function()
			local research=self.app.research
			if self.app.alive and research and not research.root.Visible and not self.gui then research:Open() end
		end)
	end
end

function Panel:Dismiss(immediate)
	local gui,panel=self.gui,self.panel
	if not gui or (self.closing and not immediate) then return end
	self.closing=true
	ContextActionService:UnbindAction("PetRollReenlistClose")
	for _,connection in self.connections do connection:Disconnect() end
	table.clear(self.connections)
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject=if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	self.app:SetMenuBlur("rebirth",false)
	-- Stop the button's attention loops before the window leaves.
	if self.rebirthButton then Theme.Motion:StopBreathe(self.rebirthButton.Visual);Theme.Motion:StopGlow(self.rebirthButton) end
	self.ready,self.skipReady=false,false
	local function finish()
		if self.gui~=gui then return end
		if self.grid then self.grid:Destroy();self.grid=nil end
		self.gui,self.panel,self.rebirthButton,self.skipButton,self.closing=nil,nil,nil,nil,false
		self.portrait,self.portraitLook=nil,nil
		gui:Destroy()
	end
	if immediate then finish();return end
	cue("MenuClose",nil,nil,{voiceKey="MenuClose",cooldown=0.2})
	Theme.Motion:Tween(panel,"reenlist-size",{Size=UDim2.fromScale(self.panelSize.X.Scale*.97,self.panelSize.Y.Scale*.97)},.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In)
	Theme.Motion:Tween(panel,"position",{Position=UDim2.fromScale(self.panelPosition.X.Scale,self.panelPosition.Y.Scale+.025)},.16)
	Theme.Motion:Tween(panel,"reenlist-fade",{GroupTransparency=1},.16,nil,nil,finish)
end

function Panel:Render(state,result)
	if type(state)~="table" then return end
	local quote=state.rebirth
	if type(quote)~="table" then return end -- Nothing until the first quote arrives.
	local before=self.quote
	self.state,self.quote=state,quote
	local rank=tonumber(quote.rank) or 0
	local promoted=self.lastRank~=nil and rank>self.lastRank
	self.lastRank=rank
	if type(result)=="table" then
		if result.action=="Rebirth" and self.pending and result.id==self.pending.id then
			self.pending=nil
			-- AppController shows the server's refusal; the button answers with a shake.
			if not result.ok and self.rebirthButton then Theme.Motion:Shake(self.rebirthButton.Visual) end
		elseif result.action=="PreparePurchase" and self.skipRequest and result.id==self.skipRequest then
			self.skipRequest=nil
			if not result.ok and type(result.message)=="string" and result.message~="" then self.app:Notify(result.message,false) end
		end
		if self.grid then self.grid:Receive(result) end
	end
	if promoted then
		self.pending=nil
		local receipt=if type(result)=="table" and result.action=="Rebirth" and result.ok and type(result.receipt)=="table"
			then result.receipt else nil
		self:Celebrate(before,quote,receipt)
	end
	self:RenderPanel()
end

function Panel:Destroy()
	self:Dismiss(true)
end

return Panel
