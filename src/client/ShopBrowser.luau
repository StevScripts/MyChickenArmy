--!strict
-- Approved Chicken Command shop composition with server-approved native checkout.
local TweenService=game:GetService("TweenService")
local Theme=require(script.Parent.UITheme)
local Art=require(script.Parent.ShopPreviewArt)
local GalaxyCrateShop=require(script.Parent.GalaxyCrateShop)
local GalaxyPresentation=require(game:GetService("ReplicatedStorage").PetRoll.Shared.GalaxyCratePresentation)
local Catalog=require(game:GetService("ReplicatedStorage").PetRoll.Shared.ShopCatalog)
local Browser={}
Browser.__index=Browser
local P={
 ink=Theme.Arcade.border,white=Theme.Colors.white,
 gold=Theme.Colors.gold,goldTop=Theme.ReferenceGradients.Base.Keypoints[1].Value,
 green=Theme.Colors.green,greenTop=Theme.ReferenceGradients.Army.Keypoints[1].Value,
 cyan=Theme.Colors.blue,muted=Theme.Colors.muted,tab=Theme.ActionColors.disabled,
}
-- Exact offer tokens from Figma 4lJjZOqNhR8K7rfMbVIjaK / 9:2742.
-- Shop-only: do not recolor the shared header, HUD or other popup screens.
local FIGMA={
 text=Color3.fromRGB(255,251,233),
 cash=Color3.fromRGB(99,239,0),cashTop=Color3.fromRGB(29,57,13),cashRim=Color3.fromRGB(200,247,151),
}
-- Card styles for the passes on sale (Catalog.Order, October 20: four passes).
local PASSES={
 {key="DoubleCash",name="2x Coins",description="Earn twice as many coins.",color=Color3.fromRGB(167,230,50),top=Color3.fromRGB(42,169,44),rim=Color3.fromRGB(233,255,160),title=Color3.fromRGB(242,255,216),icon="Cash",background="cash",double=true},
 {key="DoubleEggSpawn",name="2x Egg Spawn",description="Chickens lay eggs twice as often.",color=Color3.fromRGB(9,215,240),top=Color3.fromRGB(1,122,231),rim=Color3.fromRGB(188,239,255),title=Color3.fromRGB(227,250,255),icon="Eggs",background="eggs",double=true},
 {key="BiggerArmy",name="Bigger Army",description="+5 Army slots. Up to 17 chickens.",color=Color3.fromRGB(109,229,42),top=Color3.fromRGB(36,163,47),rim=Color3.fromRGB(205,255,160),title=Color3.fromRGB(238,255,207),icon="BiggerArmy",background="army",double=false},
 {key="DoubleLuck",name="2x Luck",description="2x Luck strength. Favor stronger chickens.",color=Color3.fromRGB(255,199,37),top=Color3.fromRGB(240,159,7),rim=Color3.fromRGB(255,236,173),title=Color3.fromRGB(255,242,205),icon="DoubleLuck",background="gold",double=true},
}
-- October 15 shop redesign (owner reference: StarterGui.GUI.FRAMES.Shop): one short
-- line per offer; the card itself is the button.
local PASS_COPY={
 DoubleCash="2x coins from eggs and fights!",DoubleEggSpawn="Chickens lay 2x the eggs!",
 BiggerArmy="+5 army slots!",DoubleLuck="Stronger chickens more often!",
}
-- Placeholder quantities; RenderCashAmounts shows the live payout. Checkout prices always come from Roblox.
local CASH_TIERS={
 {key="ArmyChest",name="Coin Chest",tier=3,amount="1M Coins",art={62.5,46,176}},
 {key="CoopStash",name="Coop Stash",tier=2,amount="100K Coins",art={62.5,46,176}},
 {key="PocketCoins",name="Pocket Coins",tier=1,amount="10K Coins",art={62.5,46,176}},
}
-- October 20 gold coins: coin packs sit on blue cards so the gold art stands out.
local COIN_CARD_TOP,COIN_CARD_BOTTOM=Color3.fromRGB(56,198,255),Color3.fromRGB(0,96,226)
-- Recording-led spacing, expressed relative to section width on every screen.
local OFFER_COLUMNS=3
-- Passes sit two per row (2x2) on wide cards (owner, October 21).
local PASS_COLUMNS=2
local OFFER_GAP=0.016
-- Section title bars follow the reference's 21.9:1 dark bar at 93% width.
local TITLE_WIDTH=0.93
local HEADING_HEIGHT=TITLE_WIDTH/21.94
local SECTION_CONTENT_TOP=HEADING_HEIGHT+0.018
-- Wider than the old 1.48 GUI.FRAMES proportion; matches MenuLayout.Defaults.Shop.
local SHOP_ASPECT=1.78
local PASS_RATIO=1.62
local CASH_RATIO=1.05
-- Rounded offer cards (owner, October 21): corner radius as a share of the card's
-- shorter side, about the same on every card; the wide vault card is shorter.
local CARD_CORNER,VAULT_CORNER=0.065,0.09
local SECTION_TITLES={Galaxy="Galaxy Crates",Passes="Passes",Cash="Coin Packs"}
local TAB_TITLES={Galaxy="Crates",Passes="Passes",Cash="Coins"}
local TITLE_GRADIENTS={
 Galaxy={Color3.fromRGB(205,140,255),Color3.fromRGB(110,235,255)},
 Passes={Color3.fromRGB(21,255,0),Color3.fromRGB(255,255,0)},
 Cash={Color3.fromRGB(255,166,0),Color3.fromRGB(255,244,120)},
}
local SECTION_ICONS={Galaxy=GalaxyPresentation.CrateImage,Passes=Theme.Assets.Army,Cash=Theme.Assets.Coin}
-- October 21 game feel (docs/team/GAME_FEEL_20261021.md): an authored cue, or its
-- fallback until the sound session adds it (UI Lab previews stub audio without Has).
-- Presentation only; one client audio.
local Audio=nil
local function cue(name,fallback,pitch,options)
 if not Audio then return end
 if type(Audio.Has)=="function" and Audio:Has(name) then Audio:Play(name,pitch,options)
 elseif fallback then Audio:Play(fallback,pitch,options) end
end

local function frame(parent,name,size,position,color)
 local item=Theme.Frame(parent,name,size,color)
 item.Position=position or UDim2.new()
 return item
end

local function text(parent,name,value,size,position,bounds,color,center)
 local label=Theme.Display(parent,name,value,size,color or P.white)
 label.Position,label.Size,label.ZIndex=position,bounds,7
 label.TextXAlignment=if center then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
 label.TextScaled=true
 return label
end

local function plain(parent,name,value,size,position,bounds,color,center)
 local label=Theme.Label(parent,name,value,size,color or P.muted)
 label.Position,label.Size,label.ZIndex=position,bounds,7
 label.TextXAlignment=if center then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
 label.TextScaled=true
 return label
end

local function panel(parent,name,accent)
 local item=frame(parent,name,UDim2.fromScale(1,1))
 item.ClipsDescendants=true
 Theme.Surface(item,accent)
 return item
end

local function ready(state)
 return state=="ready" or state=="error" or state=="ownership" or state=="policy" or state=="profile"
end

local function statusText(state,price)
 if state=="ready" then return "R$ "..Theme.Money(price) end
 return ({owned="Owned",pending="Check Roblox",preparing="Checking…",unconfigured="Coming soon",loading="Loading",
  offsale="Off sale",error="Retry price",checking="Checking passes",ownership="Retry check",
  profile="Check save",policy="Check eligibility",restricted="Not available"})[state] or "Unavailable"
end

local function guaranteedOffers(shop)
 return shop~=nil and shop.policyReady==true and shop.paidRandomAllowed==false
  and shop.restrictedTreatment=="GuaranteedOffers"
end

function Browser.new(app,parent)
 local self=setmetatable({app=app,alive=true,sections={},tabs={},cards={},
  passCount=0,connections={},priceViews={},cashViews={},motionViews={},entranceSerial=0,activeSection="Galaxy",revealed=false},Browser)
 Audio=app.audio
 local root=frame(parent,"ShopBrowser",UDim2.fromScale(1,1))
 root.BackgroundTransparency,root.Visible,root.ZIndex=1,false,2
 -- The shared popup visitor must also skip this subtree while another page is open.
 root:SetAttribute("OwnsPopupStyle",true)
 self.root=root
 Theme.Aspect(root,SHOP_ASPECT)
 local window=Theme.Container(root,"Window")
 self.window=window
 local header=Theme.Header(window,"Header","Shop",P.gold)
 header.PageIcon.Visible,header.PageIcon.Image=true,Theme.Assets.Shop
 self.header=header
 self.closeButton=Theme.HeaderClose(header,function()
  self.app.audio:Play("Click");self.app:ClosePanel()
 end,1.55) -- phone hit area: 48 px
 local body=frame(window,"Main",UDim2.fromScale(0.9983333,0.825),UDim2.fromScale(0.50025,0.585))
 body.AnchorPoint=Vector2.new(0.5,0.5)
 Theme.BelowHeader(header,body)
 Theme.Surface(body)
 body.ClipsDescendants=true
 self.body=body
 self.previewStatus=plain(body,"PurchaseStatus","Prices from Roblox · purchases deliver to this account",14,UDim2.fromScale(0.015,0.945),UDim2.fromScale(0.97,0.045),P.muted,true)
 -- Section shortcuts sit outside the window's left edge so the inside is all offers.
 local nav=frame(root,"SectionNavigation",UDim2.fromScale(0.085,0.7),UDim2.fromScale(-0.014,0.56))
 nav.AnchorPoint=Vector2.new(1,0.5)
 nav.BackgroundTransparency,nav.ZIndex=1,5
 nav:SetAttribute("OwnsPopupStyle",true)
 self.navigation=nav
 local navLayout=Instance.new("UIListLayout")
 navLayout.FillDirection,navLayout.Padding,navLayout.SortOrder,navLayout.Parent=Enum.FillDirection.Vertical,UDim.new(0.03,0),Enum.SortOrder.LayoutOrder,nav
 navLayout.VerticalAlignment,navLayout.HorizontalAlignment=Enum.VerticalAlignment.Center,Enum.HorizontalAlignment.Center
 for index,key in {"Galaxy","Passes","Cash"} do
  self.tabs[key]=self:SectionTab(nav,key,index)
 end
 local scroll=Instance.new("ScrollingFrame")
 scroll.Name,scroll.Position,scroll.Size="ShopSections",UDim2.fromScale(0.01,0.015),UDim2.fromScale(0.98,0.915)
 -- A visible gold scrollbar and a soft fade say "there is more below".
 scroll.BackgroundTransparency,scroll.BorderSizePixel,scroll.ScrollBarThickness=1,0,8
 scroll.ScrollingDirection,scroll.ScrollBarImageColor3,scroll.ClipsDescendants=Enum.ScrollingDirection.Y,P.gold,true
 scroll.CanvasSize,scroll.AutomaticCanvasSize=UDim2.new(),Enum.AutomaticSize.None
 scroll.VerticalScrollBarInset,scroll.ElasticBehavior=Enum.ScrollBarInset.Always,Enum.ElasticBehavior.WhenScrollable
 scroll.ZIndex,scroll.Parent=3,body
 self.scroll,self.grid=scroll,scroll
 local fade=frame(body,"ScrollFade",UDim2.fromScale(0.975,0.08),UDim2.fromScale(0.005,0.85),Theme.Colors.panel)
 fade.ZIndex,fade.Active=6,false
 Theme.Round(fade).CornerRadius=UDim.new(0,0)
 local fadeGradient=Instance.new("UIGradient")
 fadeGradient.Rotation=90
 fadeGradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})
 fadeGradient.Parent=fade
 self.scrollFade=fade
 local footer=frame(body,"PurchaseStatusBacking",UDim2.fromScale(1,0.07),UDim2.fromScale(0,0.93),Theme.Colors.panel)
 footer.ZIndex,footer.Active=6,false
 Theme.Round(footer).CornerRadius=UDim.new(0,0)
 self.previewStatus.ZIndex=8
 self.previewBacking=footer
 local padding=Instance.new("UIPadding")
 padding.PaddingLeft,padding.PaddingRight,padding.PaddingTop,padding.PaddingBottom=UDim.new(0.01,0),UDim.new(0.01,0),UDim.new(0.01,0),UDim.new(0.02,0)
 padding.Parent=scroll
 local layout=Instance.new("UIListLayout")
 layout.Padding,layout.SortOrder,layout.Parent=UDim.new(0.05,0),Enum.SortOrder.LayoutOrder,scroll
 layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
 self.layout=layout
 local featured=self:Section("Galaxy",SECTION_TITLES.Galaxy,0)
 self.galaxy=GalaxyCrateShop.new(app,featured)
 self:CreatePasses();self:CreateCash()
 for _,property in {"CanvasPosition","AbsoluteCanvasSize","AbsoluteWindowSize"} do
  table.insert(self.connections,scroll:GetPropertyChangedSignal(property):Connect(function() self:UpdateSection() end))
 end
 table.insert(self.connections,layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:UpdateSection() end))
 table.insert(self.connections,scroll.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then self:CancelScroll() end
 end))
 table.insert(self.connections,scroll.InputChanged:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseWheel then self:CancelScroll() end
 end))
 table.insert(self.connections,root:GetPropertyChangedSignal("Visible"):Connect(function()
  if root.Visible then self:Resize();self:AnimateSection(self.activeSection);self:RevealCards()
  else self:CancelScroll();self:CancelArtworkMotion();self.galaxy:Settle() end
 end))
 table.insert(self.connections,parent:GetPropertyChangedSignal("Visible"):Connect(function()
  if parent.Visible and root.Visible then self:AnimateSection(self.activeSection)
  else self:CancelArtworkMotion() end
 end))
 self:ApplyPresentation()
 self:Resize()
 return self
end

-- A big icon with a stroked caption; the selected section's caption turns gold.
function Browser:SectionTab(parent,key,index)
 local button=Instance.new("TextButton")
 button.Name,button.Text,button.BackgroundTransparency,button.AutoButtonColor=key,"",1,false
 -- The rail is narrower than 0.3 of its height, so a 0.86 tab is width-limited: its
 -- height is the rail width / 0.86, written out so the list stacks the same once
 -- PadHit widens the hit area (phone: 42 -> 52 px) and moves the aspect to the art.
 button.Size,button.LayoutOrder,button.ZIndex,button.Selectable=UDim2.fromScale(1,(0.085/0.7*SHOP_ASPECT)/0.86),index,6,true
 button.Parent=parent
 Theme.Aspect(button,0.86)
 local visual=Theme.Container(button,"Visual")
 visual.AnchorPoint,visual.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
 Theme.PadHit(button,1.25,1)
 -- Transparent: just the art and its caption (owner, October 15).
 local icon=Theme.Image(visual,"Icon","",UDim2.fromScale(0.92,0.74),UDim2.fromScale(0.04,0.02))
 icon.ZIndex=8
 Theme.Aspect(icon,1)
 if key=="Galaxy" then icon.Image=GalaxyPresentation.CrateImage
 elseif key=="Passes" then Art.PassIcon(icon,"BiggerArmy")
 else Art.CashPile(icon,1) end
 local caption=Theme.Display(visual,"Caption",TAB_TITLES[key],26,P.white)
 caption.Position,caption.Size,caption.ZIndex=UDim2.fromScale(-0.1,0.76),UDim2.fromScale(1.2,0.24),9
 caption.TextXAlignment,caption.TextScaled,caption.TextWrapped=Enum.TextXAlignment.Center,true,false
 Theme.Motion:BindButton(button,visual)
 button:SetAttribute("ClickSound",false)
 table.insert(self.connections,button.Activated:Connect(function()
  cue("TabSwitch","Click");self:ScrollTo(key)
 end))
 return button
end

-- The offer cards grow in the first time the Shop opens; later opens keep the
-- section's artwork entrance only.
function Browser:RevealCards()
 if self.revealed or not self.alive then return end
 self.revealed=true
 Theme.Motion:Reveal(self.passGrid,{limit=8,window=0.35,from=0.8})
 Theme.Motion:Reveal(self.cashShelf,{limit=6,window=0.35,from=0.8})
end

function Browser:Section(key,title,order)
 local section=frame(self.scroll,key,UDim2.fromScale(0.98,4))
 section.LayoutOrder,section.BackgroundTransparency=order,1
 -- Dark translucent bar with a gradient title and an icon on each side.
 local bar=frame(section,"TitleBar",UDim2.fromScale(TITLE_WIDTH,0.05),UDim2.fromScale(0.5,0),Color3.new(0,0,0))
 bar.AnchorPoint,bar.BackgroundTransparency,bar.ZIndex=Vector2.new(0.5,0),0.55,5
 bar:SetAttribute("OwnsPopupStyle",true)
 Theme.Stroke(bar,Color3.new(0,0,0),3)
 local heading=text(bar,"Heading",title,30,UDim2.fromScale(0.5,0.5),UDim2.fromScale(0.3,1),P.white,true)
 heading.AnchorPoint,heading.TextWrapped,heading.ZIndex=Vector2.new(0.5,0.5),false,8
 local colors=TITLE_GRADIENTS[key]
 local shine=Instance.new("UIGradient")
 shine.Rotation=90
 shine.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,colors[1]),ColorSequenceKeypoint.new(0.5,colors[2]),ColorSequenceKeypoint.new(1,colors[1])})
 shine.Parent=heading.TextFace
 for _,side in {-1,1} do
  local icon=Theme.Image(bar,if side<0 then "HeadingLeft" else "HeadingRight",SECTION_ICONS[key],UDim2.fromScale(0.09,1.8))
  icon.AnchorPoint,icon.ZIndex=Vector2.new(0.5,0.5),9
  icon.Position=UDim2.fromScale(0.5+side*0.2,0.5)
  Theme.Aspect(icon,1)
 end
 self.sections[key]=section
 return section
end

local function layoutSection(section,height)
 Theme.Aspect(section,1/height)
 section.TitleBar.Size=UDim2.fromScale(TITLE_WIDTH,HEADING_HEIGHT/height)
end

-- The reference's offer surface: vertical gradient, dark outer edge, light inner
-- keyline, and a white sunburst behind oversized art. `visual` is what scales on hover.
local function offerFace(card,top,bottom,corner)
 local visual=Theme.Container(card,"Visual")
 visual.AnchorPoint,visual.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
 local face=frame(visual,"Face",UDim2.fromScale(1,1),nil,Color3.new(1,1,1))
 face.ZIndex=2
 corner=corner or CARD_CORNER
 Theme.Round(face).CornerRadius=UDim.new(corner,0)
 local gradient=Theme.Gradient(face,top,bottom)
 gradient.Transparency=NumberSequence.new(0)
 local edge=Theme.Stroke(face,top:Lerp(Color3.new(0,0,0),0.72),3)
 edge.BorderStrokePosition,edge.LineJoinMode=Enum.BorderStrokePosition.Outer,Enum.LineJoinMode.Round
 local rim=Theme.Container(face,"InnerRim")
 rim.Position,rim.Size,rim.ZIndex=UDim2.fromScale(0.012,0.02),UDim2.fromScale(0.976,0.96),3
 Theme.Round(rim).CornerRadius=UDim.new(math.max(0,corner-0.02)/0.96,0)
 local keyline=Theme.Stroke(rim,top:Lerp(Color3.new(1,1,1),0.6),2)
 keyline.Transparency,keyline.LineJoinMode=0.15,Enum.LineJoinMode.Round
 -- A CanvasGroup clips the stud tile to the rounded corners; a Frame clip stays square.
 local mask=Instance.new("CanvasGroup")
 mask.Name,mask.Size,mask.BackgroundTransparency,mask.ZIndex="StudMask",UDim2.fromScale(1,1),1,3
 mask.Parent=face
 Theme.Round(mask).CornerRadius=UDim.new(corner,0)
 local studs=Theme.Studs(mask,0.08,28,0)
 studs.ZIndex=3
 return visual,face
end

function Browser:Activate(key,button,cardVisual)
 -- A tap on an unavailable card answers with a small "no" instead of silence.
 if not button.Active then
  Theme.Motion:Shake(cardVisual or button:FindFirstChild("Visual"))
  cue("Locked","Error",nil,{volume=0.5,voiceKey="Locked",cooldown=0.2})
  return
 end
 self.app.audio:Play("Click")
 local state=self.app.commerce:State(key)
 if state=="owned" then self.app.commerce:Toggle(key)
 else self.app.commerce:Buy(key) end
end

-- The Galaxy crate's buy pill, 1:1, for every pass and coin pack (owner, October 21).
function Browser:PurchaseButton(parent,key)
 local view=GalaxyCrateShop.PriceButton(parent,"Buy"..key,GalaxyCrateShop.Palettes.green)
 local button=view.button
 button:SetAttribute("CatalogKey",key)
 Theme.Aspect(button,GalaxyCrateShop.PriceAspect)
 table.insert(self.connections,button.Activated:Connect(function() self:Activate(key,button) end))
 self.priceViews[button]=view
 return button
end

-- One offer card: the whole card is a button that does what its price pill does.
function Browser:OfferCard(parent,key,definition,order)
 local card=Instance.new("TextButton")
 card.Name,card.Text,card.BackgroundTransparency,card.AutoButtonColor=key,"",1,false
 card.LayoutOrder,card.ZIndex,card.Selectable=order,2,false
 card:SetAttribute("OwnsPopupStyle",true)
 card.Parent=parent
 local visual,face=offerFace(card,definition.color:Lerp(Color3.new(1,1,1),0.12),definition.top)
 local rays=Art.ProductRays(visual,Color3.new(1,1,1))
 rays.AnchorPoint,rays.ImageTransparency,rays.ZIndex=Vector2.new(0.5,0.5),0.25,4
 local art=frame(visual,"Artwork",UDim2.fromScale(0.46,0.74),UDim2.fromScale(0.25,0.56))
 art.BackgroundTransparency,art.ZIndex=1,5
 local title=text(visual,"Title",definition.name,30,UDim2.new(),UDim2.new(),P.white,false)
 local description=text(visual,"Description",PASS_COPY[key] or Catalog.Definitions[key].description,20,UDim2.new(),UDim2.new(),FIGMA.text,false)
 local buy=self:PurchaseButton(visual,key)
 buy.ZIndex=12
 table.insert(self.connections,card.Activated:Connect(function() self:Activate(key,buy,visual) end))
 Theme.Motion:BindButton(card,visual,face)
 card:SetAttribute("Owned",false)
 return {root=card,visual=visual,face=face,title=title,art=art,rays=rays,description=description,buy=buy,palette=definition}
end

function Browser:CreatePasses()
 local section=self:Section("Passes",SECTION_TITLES.Passes,1)
 local grid=frame(section,"PassCards",UDim2.fromScale(1,0.9),UDim2.fromScale(0,0.1))
 grid.BackgroundTransparency=1
 self.passGrid=grid
 local layout=Instance.new("UIGridLayout")
 layout.CellPadding,layout.SortOrder,layout.Parent=UDim2.fromScale(OFFER_GAP,OFFER_GAP),Enum.SortOrder.LayoutOrder,grid
 layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
 self.passLayout=layout
 for _,definition in PASSES do
  -- Only passes on sale (Catalog.Order); off-sale passes keep their server benefits.
  if not table.find(Catalog.Order,definition.key) then continue end
  self.passCount+=1
  local view=self:OfferCard(grid,definition.key,definition,self.passCount)
  view.multiplier=Art.PassIcon(view.art,definition.icon,definition.double)
  self.cards[definition.key]=view
  self:BindOfferMotion(view,"Passes")
 end
end

function Browser:UpdatePurchase(button,key,root)
 local state,price=self.app.commerce:State(key)
 local shop=self.app.state and self.app.state.shop
 local automatic=state=="owned" and (key=="AutoMerge" or key=="AutoCollectEggs")
 local toggling=self.app.commerce.togglePending[key]~=nil
 button.Text=if automatic then (if toggling then "Updating…" elseif shop.automatic and shop.automatic[key] then "Auto: ON" else "Auto: OFF") else statusText(state,price)
 local view=self.priceViews[button]
 local quoted=state=="ready" and not automatic and type(price)=="number"
 GalaxyCrateShop.ShowPrice(view,if quoted then Theme.Money(price) else button.Text,quoted,state=="restricted" or state=="offsale")
 -- Gold like the crate's 10-pack: owned passes and the biggest coin pack.
 GalaxyCrateShop.SetPalette(view,if state=="owned" or key=="CommandersVault" then GalaxyCrateShop.Palettes.gold else GalaxyCrateShop.Palettes.green)
 button.Active=(ready(state) or automatic) and self.app.commerce.pending==nil and not toggling
  and (automatic or self.app.commerce.autoCrate==nil)
 button.Selectable=button.Active
 button:SetAttribute("State",state)
 button:SetAttribute("UnavailableReason",if ready(state) or automatic then nil else state)
 if root then root:SetAttribute("Owned",state=="owned") end
 -- Presentation only: celebrate a purchase Roblox's checkout just confirmed.
 local commerce=self.app.commerce
 local bought=commerce.justBought and commerce.justBought[key]
 if bought and (state=="owned" or Catalog.Products[key]~=nil) then
  commerce.justBought[key]=nil
  local visual=button.Parent
  if commerce.clock()-bought<30 and visual and visual.Name=="Visual" then
   -- One reward emphasis: a gold wash on the bought card under a confetti burst
   -- over the window, with the Jingle.
   Theme.Motion:Flash(visual,P.gold,0.5,0.6)
   Theme.Motion:Confetti(self.body,{origin=Theme.Motion:Point(self.body,Theme.Motion:CenterOf(visual)),spread=0.35,seconds=1.4})
   cue("Jingle","UIPurchase",nil,{voiceKey="ShopJingle",cooldown=0.5})
  end
 end
end

function Browser:RenderExisting()
 self.galaxy:Render()
 for key,view in self.cards do self:UpdatePurchase(view.buy,key,view.root) end
 for _,view in self.cashViews do self:UpdatePurchase(view.buy,view.key) end
 self:UpdatePurchase(self.cashBuy,"CommandersVault")
 local shop=self.app.state and self.app.state.shop
 local luck=self.cards.DoubleLuck
 local guaranteed=guaranteedOffers(shop)
 local normal=shop and shop.policyReady==true and shop.paidRandomAllowed==true
 luck.title.Text=if guaranteed then "Guaranteed Offers" elseif normal then "2x Luck" else "Luck pass"
 luck.description.Text=if guaranteed then "A Rare+ offer every 10 rolls"
  elseif normal then PASS_COPY.DoubleLuck else "Checking your benefit…"
 if luck.multiplier then luck.multiplier.Visible=normal==true end
 local saving=not shop or not shop.productReady
 self.previewStatus.Text=if shop and shop.testAllowed then "Studio test · Use Test roll above · No Robux charged"
  elseif saving then "Coin packs wait for a saved profile."
  elseif self.app.commerce.pending then "Complete or cancel the Roblox purchase prompt."
  else "Prices from Roblox · purchases deliver to this account"
 -- Regional pricing can change unit value. Compare only verified current prices.
 local vault=self.app.commerce.products.CommandersVault
 local bestVault=vault and vault.status=="ready" and vault.price and vault.price>0
 if bestVault then
  local unit=vault.price/Catalog.Products.CommandersVault.coins
  for _,view in self.cashViews do
   local entry=self.app.commerce.products[view.key]
   if not entry or entry.status~="ready" or not entry.price or entry.price<=0
    or unit>=entry.price/Catalog.Products[view.key].coins then bestVault=false;break end
  end
 end
 self.cashSubtitle.Text=if bestVault then "BEST VALUE!" else "Biggest pack!"
end

function Browser:CreateCash()
 local section=self:Section("Cash",SECTION_TITLES.Cash,2)
 local vaultButton=Instance.new("TextButton")
 vaultButton.Name,vaultButton.Text,vaultButton.BackgroundTransparency,vaultButton.AutoButtonColor="CommandersVault","",1,false
 vaultButton.ZIndex,vaultButton.Selectable=2,false
 vaultButton:SetAttribute("OwnsPopupStyle",true)
 vaultButton.Parent=section
 local vault,vaultFace=offerFace(vaultButton,COIN_CARD_TOP,COIN_CARD_BOTTOM,VAULT_CORNER)
 vault.ClipsDescendants=true
 self.cashFeatured,self.cashFeaturedButton=vaultButton,vaultButton
 self.cashRays=Art.ProductRays(vault,Color3.new(1,1,1))
 self.cashRays.ZIndex=4
 -- October 16 (owner): the biggest pack's art is the card's full background; the
 -- text sits on top of it (labels are ZIndex 7). The rays would only cover it.
 self.cashRays.Visible=false
 local art=frame(vault,"CashOverflow",UDim2.fromScale(1,1),UDim2.fromScale(0,0))
 art.BackgroundTransparency,art.ZIndex=1,3
 self.cashArt=art
 self.cashOverflow=Art.CashOverflow(art)
 self.cashOverflow.ScaleType,self.cashOverflow.ZIndex=Enum.ScaleType.Crop,3
 Theme.Round(self.cashOverflow).CornerRadius=UDim.new(VAULT_CORNER,0)
 self.cashTitle=text(vault,"Title","Commander's Vault",30,UDim2.fromScale(0.03,0.07),UDim2.fromScale(0.5,0.2))
 self.cashNote=text(vault,"PreviewAmount","10M Coins",56,UDim2.fromScale(0.03,0.29),UDim2.fromScale(0.5,0.3),FIGMA.text,false)
 self.cashSubtitle=text(vault,"PackSize","Best value",22,UDim2.fromScale(0.03,0.56),UDim2.fromScale(0.4,0.12),Color3.fromRGB(255,240,90))
 vaultButton:SetAttribute("CashAmount",Catalog.Products.CommandersVault.coins)
 self.cashBuy=self:PurchaseButton(vault,"CommandersVault")
 self.cashBuy.ZIndex=12
 table.insert(self.connections,vaultButton.Activated:Connect(function() self:Activate("CommandersVault",self.cashBuy,vault) end))
 Theme.Motion:BindButton(vaultButton,vault,vaultFace)
 local shelf=frame(section,"CashTiers",UDim2.fromScale(1,0.45),UDim2.fromScale(0,0.55))
 shelf.BackgroundTransparency=1
 self.cashShelf=shelf
 local layout=Instance.new("UIGridLayout")
 layout.CellPadding,layout.SortOrder,layout.Parent=UDim2.fromScale(OFFER_GAP,0),Enum.SortOrder.LayoutOrder,shelf
 layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
 self.cashLayout=layout
 for i,definition in CASH_TIERS do
  local card=Instance.new("TextButton")
  card.Name,card.Text,card.BackgroundTransparency,card.AutoButtonColor=definition.key,"",1,false
  card.LayoutOrder,card.ZIndex,card.Selectable=i,2,false
  card:SetAttribute("OwnsPopupStyle",true)
  card.Parent=shelf
  local visual,face=offerFace(card,COIN_CARD_TOP,COIN_CARD_BOTTOM)
  local title=text(visual,"Title",definition.name,26,UDim2.fromScale(0.04,0.03),UDim2.fromScale(0.92,0.12),P.white,true)
  local rays=Art.ProductRays(visual,Color3.new(1,1,1))
  rays.ZIndex=4
  local icon=frame(visual,"Artwork",UDim2.fromScale(0.66,0.5),UDim2.fromScale(0.17,0.18))
  icon.BackgroundTransparency,icon.ZIndex=1,5
  Art.CashPile(icon,definition.tier)
  local note=text(visual,"PreviewAmount",definition.amount,40,UDim2.fromScale(0.04,0.69),UDim2.fromScale(0.92,0.13),FIGMA.text,true)
  note.Font=Theme.Font
  local buy=self:PurchaseButton(visual,definition.key)
  buy.ZIndex=12
  table.insert(self.connections,card.Activated:Connect(function() self:Activate(definition.key,buy,visual) end))
  Theme.Motion:BindButton(card,visual,face)
  self.cashViews[i]={root=card,key=definition.key,title=title,art=icon,rays=rays,note=note,buy=buy}
  self:BindOfferMotion(self.cashViews[i],"Cash")
 end
end

function Browser:BindOfferMotion(view,section)
 view.section=section
 table.insert(self.motionViews,view)
 local function pose(hot)
  if not self.alive then return end
  local active=hot and self.root.Visible and self.root.Parent.Visible and not self.app.reducedMotion
  local rest=view.artRestSize or view.art.Size
  local factor=if active then 1.065 else 1
  Theme.Motion:Tween(view.art,"shop-art",{Size=UDim2.fromScale(rest.X.Scale*factor,rest.Y.Scale*factor)},0.2,Enum.EasingStyle.Back)
  -- Keep GUI ancestors upright so scrolling still clips the hover animation.
  view.art.Rotation=0
 end
 table.insert(self.connections,view.root.MouseEnter:Connect(function() pose(true) end))
 table.insert(self.connections,view.root.MouseLeave:Connect(function() pose(false) end))
 if view.buy then
  table.insert(self.connections,view.buy.SelectionGained:Connect(function() pose(true) end))
  table.insert(self.connections,view.buy.SelectionLost:Connect(function() pose(false) end))
 end
end

function Browser:CancelArtworkMotion()
 self.entranceSerial+=1
 for _,view in self.motionViews do
  Theme.Motion:Cancel(view.art,"shop-tilt")
  Theme.Motion:Cancel(view.art,"shop-art")
  if view.artRestSize then view.art.Size=view.artRestSize end
  view.art.Rotation=0
 end
end

function Browser:AnimateSection(section)
 self:CancelArtworkMotion()
 if self.app.reducedMotion or not self.root.Visible or not self.root.Parent.Visible then return end
 local serial=self.entranceSerial
 local index=0
 for _,view in self.motionViews do
  if view.section==section then
   local delay=index*0.035
   index+=1
   task.delay(delay,function()
    if not self.alive or self.entranceSerial~=serial or self.app.reducedMotion or not self.root.Visible or not self.root.Parent.Visible then return end
    local rest=view.artRestSize or view.art.Size
    view.art.Size=UDim2.fromScale(rest.X.Scale*0.88,rest.Y.Scale*0.88)
    Theme.Motion:Tween(view.art,"shop-art",{Size=rest},0.24,Enum.EasingStyle.Back)
   end)
  end
 end
end

function Browser:CancelScroll()
 if self.scrollFinished then self.scrollFinished:Disconnect();self.scrollFinished=nil end
 if self.scrollTween then self.scrollTween:Cancel();self.scrollTween:Destroy();self.scrollTween=nil end
end

function Browser:RefreshScrollMetrics()
 if not self.alive then return end
 local scroll=self.scroll
 self.sectionStarts={}
 for key,section in self.sections do
  self.sectionStarts[key]=section.AbsolutePosition.Y-scroll.AbsolutePosition.Y+scroll.CanvasPosition.Y
 end
 self.maxScroll=math.max(0,scroll.AbsoluteCanvasSize.Y-scroll.AbsoluteWindowSize.Y)
end

function Browser:ScrollTo(key)
 self:RefreshScrollMetrics()
 if not self.sectionStarts[key] then return end
 self:CancelScroll()
 local target=Vector2.new(0,math.clamp(self.sectionStarts[key]-self.scroll.AbsoluteWindowSize.Y*0.005,0,self.maxScroll))
 if self.app.reducedMotion then self.scroll.CanvasPosition=target;return end
 self.scrollTween=TweenService:Create(self.scroll,TweenInfo.new(0.32,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{CanvasPosition=target})
 self.scrollFinished=self.scrollTween.Completed:Connect(function(state)
  if state==Enum.PlaybackState.Completed then self:AnimateSection(key) end
 end)
 self.scrollTween:Play()
end

function Browser:UpdateSection()
 if not self.alive then return end
 self:RefreshScrollMetrics()
 local y,active=self.scroll.CanvasPosition.Y,"Galaxy"
 for _,key in {"Galaxy","Passes","Cash"} do
  if y>=self.sectionStarts[key]-self.scroll.AbsoluteWindowSize.Y*0.04 then active=key end
 end
 if self.maxScroll>0 and y>=self.maxScroll-self.scroll.AbsoluteWindowSize.Y*0.003 then active="Cash" end
 if active==self.activeSection then return end
 self.activeSection=active
 local animate=self.root.Visible
 for key,button in self.tabs do
  local selected=key==active
  local color=if selected then P.gold else P.white
  if animate then Theme.Motion:Tween(button.Visual.Caption,"tab-color",{TextColor3=color},0.15) else button.Visual.Caption.TextColor3=color end
  if animate and selected then Theme.Motion:Pop(button.Visual,1.08) end
  button:SetAttribute("Selected",selected)
 end
end

function Browser:ApplyPresentation()
 -- Shared neutral shell; offer cards and title bars own their colors (OwnsPopupStyle).
 Theme.ApplyPopupStyle(self.root)
 for key,button in self.tabs do
  local selected=key==self.activeSection
  local caption=button.Visual.Caption
  caption.TextColor3=if selected then P.gold else P.white
 end
end

-- Native proportional layout mirrors GUI.FRAMES.Shop. Content count determines
-- section length; viewport changes never choose columns, fonts, or arrangements.
function Browser:Resize()
 if not self.alive or self.layoutReady then return end
 self.layoutReady=true
 self.root.Size,self.root.Position,self.root.AnchorPoint=UDim2.fromScale(1,1),UDim2.new(),Vector2.zero
 self.window.Position,self.window.Size=UDim2.new(),UDim2.fromScale(1,1)
 local featuredSectionHeight=SECTION_CONTENT_TOP+GalaxyCrateShop.Height
 layoutSection(self.sections.Galaxy,featuredSectionHeight)
 self.galaxy.root.Position,self.galaxy.root.Size=UDim2.fromScale(0,SECTION_CONTENT_TOP/featuredSectionHeight),UDim2.fromScale(1,GalaxyCrateShop.Height/featuredSectionHeight)
 local passRatio=PASS_RATIO
 local cardWidth=(1-OFFER_GAP*(OFFER_COLUMNS-1))/OFFER_COLUMNS
 local passCardWidth=(1-OFFER_GAP*(PASS_COLUMNS-1))/PASS_COLUMNS
 local passRows=math.ceil(self.passCount/PASS_COLUMNS)
 local passCardHeight=passCardWidth/passRatio
 local gridHeight=passRows*passCardHeight+math.max(0,passRows-1)*OFFER_GAP
 local passHeight=SECTION_CONTENT_TOP+gridHeight
 self.sections.Passes.Size=UDim2.fromScale(0.98,passRows+1)
 layoutSection(self.sections.Passes,passHeight)
 self.passGrid.Position,self.passGrid.Size=UDim2.fromScale(0,SECTION_CONTENT_TOP/passHeight),UDim2.fromScale(1,gridHeight/passHeight)
 self.passLayout.CellPadding,self.passLayout.CellSize=UDim2.fromScale(OFFER_GAP,OFFER_GAP/gridHeight),UDim2.fromScale(passCardWidth,passCardHeight/gridHeight)
 self.passLayout.FillDirectionMaxCells=PASS_COLUMNS
 for _,view in self.cards do
  -- Wide card: art and sunburst on the left, name top-right, one line of
  -- copy, then a big price pill bottom-right.
  view.rays.AnchorPoint,view.rays.Position,view.rays.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.25,0.56),UDim2.fromScale(0.62,1.0)
  Theme.Aspect(view.rays,1)
  view.art.AnchorPoint=Vector2.new(0.5,0.5)
  view.art.Position,view.art.Size=UDim2.fromScale(0.25,0.56),UDim2.fromScale(0.47,0.76)
  Theme.Aspect(view.art,1)
  view.artRestSize=view.art.Size
  view.title.AnchorPoint,view.title.Position,view.title.Size=Vector2.new(1,0),UDim2.fromScale(0.965,0.06),UDim2.fromScale(0.56,0.25)
  view.title.TextWrapped,view.title.TextXAlignment=false,Enum.TextXAlignment.Right
  view.description.AnchorPoint,view.description.Position=Vector2.new(1,0),UDim2.fromScale(0.965,0.33)
  view.description.Size=UDim2.fromScale(0.5,0.27)
  view.description.TextWrapped,view.description.TextXAlignment=true,Enum.TextXAlignment.Right
  view.buy.AnchorPoint,view.buy.Position,view.buy.Size=Vector2.new(1,1),UDim2.fromScale(0.965,0.93),UDim2.fromScale(0.5,0.25)
 end
 local cashCardWidth=cardWidth
 local cashCardHeight=cashCardWidth/CASH_RATIO
 local featuredHeight=0.22
 local cashHeight=SECTION_CONTENT_TOP+featuredHeight+OFFER_GAP+cashCardHeight
 -- AutomaticCanvasSize undercounts these aspect-constrained sections. Express
 -- their full height in the body's native Scale coordinates instead. CanvasSize
 -- uses the scroll parent's height; padding and list gaps use the canvas height.
 local padding=self.scroll.UIPadding
 local innerWidth=1-padding.PaddingLeft.Scale-padding.PaddingRight.Scale
 local innerHeight=1-padding.PaddingTop.Scale-padding.PaddingBottom.Scale
 local bodyAspect=self.root.UIAspectRatioConstraint.AspectRatio*self.body.Size.X.Scale/self.body.Size.Y.Scale
 local sectionWidth=self.scroll.Size.X.Scale*innerWidth*self.sections.Passes.Size.X.Scale
 local gap=0.025*self.scroll.Size.Y.Scale
 local canvasHeight=(bodyAspect*sectionWidth*(featuredSectionHeight+passHeight+cashHeight)+gap*2)/innerHeight
 self.scroll.CanvasSize=UDim2.fromScale(0,canvasHeight)
 self.layout.Padding=UDim.new(gap/(canvasHeight*innerHeight),0)
 layoutSection(self.sections.Cash,cashHeight)
 self.cashFeatured.Position,self.cashFeatured.Size=UDim2.fromScale(0,SECTION_CONTENT_TOP/cashHeight),UDim2.fromScale(1,featuredHeight/cashHeight)
 Theme.Aspect(self.cashFeatured,1/featuredHeight)
 self.cashRays.AnchorPoint,self.cashRays.Position,self.cashRays.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.75,0.5),UDim2.fromScale(0.5,1.6)
 Theme.Aspect(self.cashRays,1)
 self.cashBuy.AnchorPoint,self.cashBuy.Position,self.cashBuy.Size=Vector2.new(0,1),UDim2.fromScale(0.03,0.93),UDim2.fromScale(0.3,0.22)
 self.cashTitle.TextWrapped,self.cashSubtitle.TextWrapped=true,true
 self.cashTitle.TextXAlignment,self.cashNote.TextXAlignment,self.cashSubtitle.TextXAlignment=Enum.TextXAlignment.Left,Enum.TextXAlignment.Left,Enum.TextXAlignment.Left
 self.cashShelf.Position,self.cashShelf.Size=UDim2.fromScale(0,(SECTION_CONTENT_TOP+featuredHeight+OFFER_GAP)/cashHeight),UDim2.fromScale(1,cashCardHeight/cashHeight)
 self.cashLayout.CellSize,self.cashLayout.FillDirectionMaxCells=UDim2.fromScale(cashCardWidth,1),OFFER_COLUMNS
 for _,view in self.cashViews do
  Theme.Aspect(view.root,CASH_RATIO)
  view.rays.AnchorPoint,view.rays.Position,view.rays.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.42),UDim2.fromScale(0.9,0.9)
  Theme.Aspect(view.rays,1)
  view.title.Position,view.title.Size=UDim2.fromScale(0.04,0.03),UDim2.fromScale(0.92,0.13)
  view.art.AnchorPoint=Vector2.new(0.5,0.5)
  view.art.Position,view.art.Size=UDim2.fromScale(0.5,0.42),UDim2.fromScale(0.62,0.48)
  view.artRestSize=view.art.Size
  view.note.Position,view.note.Size=UDim2.fromScale(0.04,0.63),UDim2.fromScale(0.92,0.12)
  view.buy.AnchorPoint,view.buy.Position,view.buy.Size=Vector2.new(0.5,0),UDim2.fromScale(0.5,0.77),UDim2.fromScale(0.84,0.19)
 end
 Theme.ScaleText(self.root)
 self:UpdateSection()
end

-- October 14: coin packs pay minutes of income (at least the catalog amount); show the server's live payout.
function Browser:RenderCashAmounts()
 local packs=self.app.state and self.app.state.shop and self.app.state.shop.cashPacks or {}
 local function amount(key)
  local product=Catalog.Products[key]
  return Theme.Number(packs[key] or (product and product.coins) or 0).." Coins"
 end
 for _,view in self.cashViews do view.note.Text=amount(view.key) end
 if self.cashNote then self.cashNote.Text=amount("CommandersVault") end
end

function Browser:Render(_force)
 self:RenderExisting();self:RenderCashAmounts();self:ApplyPresentation();self:Resize();self:UpdateSection()
end

function Browser:Destroy()
 if not self.alive then return end
 self.alive=false
 self:CancelScroll()
 self:CancelArtworkMotion()
 for _,connection in self.connections do connection:Disconnect() end
 table.clear(self.connections)
 self.galaxy:Destroy()
 self.root:Destroy()
end
return Browser
