--!strict
-- The Shop: one horizontal rail of tall offer cards with server-approved native
-- checkout (October 21 reference parity, P8: docs/team/REFERENCE_PARITY_20261021.md
-- §2.7, docs/team/SHOP_FORMATTING.md). Only the existing catalog is on the rail;
-- prices always come live from the Marketplace through CommerceController.
local TweenService=game:GetService("TweenService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(script.Parent.UITheme)
local Art=require(script.Parent.ShopPreviewArt)
local GalaxyCrateShop=require(script.Parent.GalaxyCrateShop)
local Catalog=require(ReplicatedStorage.PetRoll.Shared.ShopCatalog)
local Browser={}
Browser.__index=Browser

local WHITE=Color3.new(1,1,1)
local GOLD=Theme.Colors.gold
-- The reference window, measured on the recording (818 x 469 at 1568 px wide).
local SHOP_ASPECT=818/469
-- The rail's inner card inside the body (Scale of the body), as in the reference:
-- a lighter translucent area 20 px in from the window's sides that clips the rail.
local RAIL={x=0.024,y=0.044,w=0.952,h=0.903}
-- Inside the rail (share of its height): cards start 10/365 down and are 335/365
-- tall; the thin scrollbar runs in the strip left under them.
local CARD_TOP,CARD_H=10/365,335/365
-- Widths in card heights (H). Reference: 15 px lead-in, 10 px gaps, tall cards
-- 245 x 335, the small 2x2 cards 178 x 160 (ours a little wider so pack names fit).
local PAD,GAP=15/335,10/335
local TALL=245/335
local SMALL_W,SMALL_H=0.62,(1-GAP)/2
local COIN_BLOCK=SMALL_W*2+GAP
-- Virtual layouts (card-height 335 units).
local TALL_V=Vector2.new(245,335)
local SMALL_V=Vector2.new(SMALL_W*335,SMALL_H*335)
local BLOCK_V=Vector2.new(COIN_BLOCK*335,335)

-- Card styles for the passes on sale (Catalog.Order, October 20: four passes).
local PASSES={
 {key="DoubleCash",name="2x Coins",color=Color3.fromRGB(167,230,50),top=Color3.fromRGB(42,169,44),icon="Cash",double=true},
 {key="DoubleEggSpawn",name="2x Egg Spawn",color=Color3.fromRGB(9,215,240),top=Color3.fromRGB(1,122,231),icon="Eggs",double=true},
 {key="BiggerArmy",name="Bigger Army",color=Color3.fromRGB(109,229,42),top=Color3.fromRGB(36,163,47),icon="BiggerArmy",double=false},
 {key="DoubleLuck",name="2x Luck",color=Color3.fromRGB(255,199,37),top=Color3.fromRGB(240,159,7),icon="DoubleLuck",double=true},
}
-- One benefit line per pass (the reference's "Gain 2x Luck to get better Fruits!").
local PASS_COPY={
 DoubleCash="2x coins from eggs and fights!",DoubleEggSpawn="Chickens lay 2x the eggs!",
 BiggerArmy="+5 Army slots!",DoubleLuck="Gain 2x Luck to get better chickens!",
}
-- Coin packs as the reference's 2x2 block of small cards (its 5m/15m/1h/4h Time
-- Skips pay Coins; ours pay 10 min / 45 min / 3 h / 10 h of income). Placeholder
-- amounts; RenderCashAmounts shows the server's live payout.
local COIN_PACKS={
 {key="PocketCoins",name="Pocket Coins",tier=1},
 {key="CoopStash",name="Coop Stash",tier=2},
 {key="ArmyChest",name="Coin Chest",tier=3},
 {key="CommandersVault",name="Commander's Vault",tier=4},
}
-- October 20 gold coins: coin packs sit on blue cards so the gold art stands out.
local COIN_TOP,COIN_BOTTOM=Color3.fromRGB(56,198,255),Color3.fromRGB(0,96,226)
-- Rebirth Skip: the Gem purple of RebirthPanel's Skip! button.
local SKIP_TOP,SKIP_BOTTOM=Theme.GemColors.SkipTop,Theme.GemColors.SkipBottom
-- The rail, left to right. The reference opens on a tall green card beside the pack
-- column with the next card peeking in; the 2x Luck card sits right before the 2x2.
local SECTION_ALIASES={Passes="DoubleCash",Cash="CoinPacks",Coins="CoinPacks",Crates="Galaxy"}

-- October 21 game feel (docs/team/GAME_FEEL_20261021.md): an authored cue, or its
-- fallback until the sound session adds it (UI Lab previews stub audio without Has).
local Audio=nil
local function cue(name,fallback,pitch,options)
 if not Audio then return end
 if type(Audio.Has)=="function" and Audio:Has(name) then Audio:Play(name,pitch,options)
 elseif fallback then Audio:Play(fallback,pitch,options) end
end

local function rect(item,x,y,width,height,parentWidth,parentHeight)
 Theme.RelativeRect(item,x,y,width,height,parentWidth,parentHeight)
end

-- White Montserrat Bold with the black stroke at about 8% of the glyph height
-- (contract 2.1). Local until P2's shared label-stroke helper lands in UITheme.
local function label(parent,name,value,color,z)
 local item=Theme.Label(parent,name,value,24,color or WHITE)
 item.TextScaled,item.TextWrapped,item.ZIndex=true,false,z or 9
 item.TextXAlignment=Enum.TextXAlignment.Center
 item.TextOutline.Thickness=0.08
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

-- The rail's own width/height. The window keeps SHOP_ASPECT (its constraint), the
-- shared header takes SHOP_ASPECT/HeaderAspect of its height (BelowHeader) and the
-- body spans the full width, so this is the same on every device.
local function railAspect(): number
 local bodyHeight=1-SHOP_ASPECT/Theme.HeaderAspect
 return RAIL.w*SHOP_ASPECT/(RAIL.h*bodyHeight)
end

-- The Rebirth quote's Skip, when RebirthPanel would show its Skip! button.
local function rebirthSkip(state)
 local quote=state and state.rebirth
 local skip=type(quote)=="table" and quote.skip
 if type(skip)~="table" or quote.enabled==false or quote.nextRank==nil or skip.restricted==true then return nil end
 local credits=tonumber(skip.credits) or 0
 if credits<=0 and skip.onSale~=true then return nil end
 return skip
end

function Browser.new(app,parent)
 local self=setmetatable({app=app,alive=true,cards={},cashViews={},columns={} :: {{key:string,width:number,frame:Frame}},columnByKey={},
  connections={},priceViews={},scrollTween=nil,scrollFinished=nil},Browser)
 Audio=app.audio
 local root=Theme.Container(parent,"ShopBrowser")
 root.Visible,root.ZIndex=false,2
 -- The shared popup visitor must also skip this subtree while another page is open.
 root:SetAttribute("OwnsPopupStyle",true)
 self.root=root
 Theme.Aspect(root,SHOP_ASPECT)
 local window=Theme.Container(root,"Window")
 self.window=window
 local header=Theme.Header(window,"Header","Shop",GOLD)
 header.PageIcon.Visible,header.PageIcon.Image=true,Theme.Assets.Shop
 self.header=header
 self.closeButton=Theme.HeaderClose(header,function()
  self.app.audio:Play("Click");self.app:ClosePanel()
 end,1.65) -- phone hit area: 48 px
 local body=Theme.Frame(window,"Main",UDim2.fromScale(1,0.86))
 body.Position=UDim2.fromScale(0,0.14)
 Theme.BelowHeader(header,body)
 Theme.Surface(body)
 body.ClipsDescendants=true
 self.body=body
 -- The lighter translucent inner card (ApplyPopupStyle gives it the shared look).
 local rail=Theme.Frame(body,"Rail",UDim2.fromScale(RAIL.w,RAIL.h),Color3.fromRGB(40,44,48))
 rail.Position,rail.BackgroundTransparency,rail.ZIndex=UDim2.fromScale(RAIL.x,RAIL.y),0.55,2
 local railEdge=Theme.Stroke(rail,Color3.fromRGB(6,8,9),2)
 railEdge.Transparency=0.42
 self.rail=rail
 local scroll=Instance.new("ScrollingFrame")
 scroll.Name,scroll.Size,scroll.ZIndex="OfferRail",UDim2.fromScale(1,1),3
 scroll.BackgroundTransparency,scroll.BorderSizePixel,scroll.ClipsDescendants=1,0,true
 scroll.ScrollingDirection=Enum.ScrollingDirection.X
 -- One thin light bar along the bottom (the reference's); a native px property.
 scroll.ScrollBarThickness,scroll.ScrollBarImageColor3,scroll.ScrollBarImageTransparency=6,Color3.fromRGB(205,210,214),0.15
 scroll.HorizontalScrollBarInset,scroll.VerticalScrollBarInset=Enum.ScrollBarInset.None,Enum.ScrollBarInset.None
 scroll.AutomaticCanvasSize,scroll.ElasticBehavior=Enum.AutomaticSize.None,Enum.ElasticBehavior.WhenScrollable
 scroll.CanvasSize=UDim2.fromScale(1,1)
 scroll.Selectable=false
 scroll.Parent=rail
 self.scroll=scroll
 -- Rail order (reference: Server Luck, pack column, VIP, 2x Luck, Time Skips, 1 Day).
 local passes={}
 for _,definition in PASSES do
  -- Only passes on sale (Catalog.Order); off-sale passes keep their server benefits.
  if table.find(Catalog.Order,definition.key) then table.insert(passes,definition) end
 end
 for index,definition in passes do
  self:CreatePass(definition)
  if index==1 then
   local column=self:Column("Galaxy",GalaxyCrateShop.Width)
   self.galaxy=GalaxyCrateShop.new(app,column)
   for _,pack in {"OuterSpaceCrate1","OuterSpaceCrate3","OuterSpaceCrate10"} do self.columnByKey[pack]=column end
  end
 end
 if not self.galaxy then
  local column=self:Column("Galaxy",GalaxyCrateShop.Width)
  self.galaxy=GalaxyCrateShop.new(app,column)
 end
 self:CreateCoinPacks()
 self:CreateRebirthSkip()
 self:CreateGift()
 table.insert(self.connections,scroll.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then self:CancelScroll() end
 end))
 table.insert(self.connections,scroll.InputChanged:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.MouseWheel then self:CancelScroll() end
 end))
 -- The root stays visible while the panel closes and reopens on the Shop page, so
 -- the panel's own visibility counts as opening too.
 local function visibility()
  if root.Visible and parent.Visible then self:Opened()
  else self:CancelScroll();self.galaxy:Settle() end
 end
 table.insert(self.connections,root:GetPropertyChangedSignal("Visible"):Connect(visibility))
 table.insert(self.connections,parent:GetPropertyChangedSignal("Visible"):Connect(visibility))
 self:Layout()
 Theme.ScaleText(root)
 self:ApplyPresentation()
 return self
end

-- One rail slot: a transparent column `width` card heights wide (Layout places it).
function Browser:Column(key,width)
 local column=Theme.Container(self.scroll,key)
 column.ZIndex,column.LayoutOrder=2,#self.columns+1
 column:SetAttribute("OwnsPopupStyle",true)
 table.insert(self.columns,{key=key,width=width,frame=column})
 self.columnByKey[key]=column
 return column
end

-- A card button filling `parent`, with the shared face. `size` is the card's own
-- virtual size (its corner radius stays the same as every other card's).
local function cardButton(parent,name,top,bottom,size)
 local card=Instance.new("TextButton")
 card.Name,card.Text,card.BackgroundTransparency,card.AutoButtonColor=name,"",1,false
 card.Size,card.ZIndex,card.Selectable=UDim2.fromScale(1,1),2,false
 card:SetAttribute("OwnsPopupStyle",true)
 card.Parent=parent
 local visual,face=Art.CardFace(card,top,bottom,Art.CardRadius*335/math.min(size.X,size.Y))
 return card,visual,face
end

-- Content laid out in the reference tall card (245 x 335): title plate, art on a
-- sunburst, the benefit line and the green price pill.
local function tallContent(visual,titleText,description)
 local rays=Art.ProductRays(visual,WHITE)
 rays.ImageTransparency,rays.ZIndex=0.25,4
 rect(rays,10,12,225,225,245,335)
 local art=Theme.Container(visual,"Artwork")
 art.ZIndex=5
 rect(art,45,58,155,132,245,335)
 local _,title=GalaxyCrateShop.TitlePlate(visual,titleText,10,10,225,40,245,335,8)
 -- Three lines fit at the phone text floor (the reference's lines wrap the same way).
 local copy=label(visual,"Description",description)
 copy.TextWrapped=true
 rect(copy,12,196,221,70,245,335)
 return art,rays,title,copy
end

function Browser:Activate(key,button,cardVisual)
 -- A tap on an unavailable or owned card answers with a soft "no" instead of silence.
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

-- The Galaxy crate's buy pill, 1:1, on every pass and coin pack (owner, October 21).
function Browser:PurchaseButton(parent,key,palette)
 local view=GalaxyCrateShop.PriceButton(parent,"Buy"..key,palette or GalaxyCrateShop.Palettes.green)
 local button=view.button
 button:SetAttribute("CatalogKey",key)
 button.ZIndex=12
 table.insert(self.connections,button.Activated:Connect(function() self:Activate(key,button,parent) end))
 self.priceViews[button]=view
 return button
end

-- A pass as a tall colour card; the whole card does what its pill does.
function Browser:CreatePass(definition)
 local key=definition.key
 local column=self:Column(key,TALL)
 local card,visual,face=cardButton(column,key,definition.color:Lerp(WHITE,0.12),definition.top,TALL_V)
 local art,rays,title,copy=tallContent(visual,definition.name.."!",PASS_COPY[key] or Catalog.Definitions[key].description)
 local multiplier=Art.PassIcon(art,definition.icon,definition.double)
 local buy=self:PurchaseButton(visual,key)
 rect(buy,45,272,155,52,245,335)
 table.insert(self.connections,card.Activated:Connect(function() self:Activate(key,buy,visual) end))
 Theme.Motion:BindButton(card,visual,face)
 card:SetAttribute("Owned",false)
 self.cards[key]={root=card,visual=visual,face=face,title=title,description=copy,art=art,rays=rays,buy=buy,multiplier=multiplier}
end

-- Coin packs: one 2x2 block of small blue cards (title, pack art, the Coins it
-- pays in gold beside the coin, an orange-gold R$ pill), top-left smallest.
function Browser:CreateCoinPacks()
 local column=self:Column("CoinPacks",COIN_BLOCK)
 for _,definition in COIN_PACKS do
  if not Catalog.ProductOnSale(definition.key) then continue end
  local slot=#self.cashViews
  local holder=Theme.Container(column,definition.key)
  holder.ZIndex=2
  rect(holder,(slot%2)*(SMALL_V.X+GAP*335),math.floor(slot/2)*(SMALL_V.Y+GAP*335),SMALL_V.X,SMALL_V.Y,BLOCK_V.X,BLOCK_V.Y)
  local card,visual,face=cardButton(holder,"Card",COIN_TOP,COIN_BOTTOM,SMALL_V)
  local w,h=SMALL_V.X,SMALL_V.Y
  local _,title=GalaxyCrateShop.TitlePlate(visual,definition.name.."!",4,5,w-8,28,w,h,8,0.02)
  local rays=Art.ProductRays(visual,WHITE)
  rays.ImageTransparency,rays.ZIndex=0.3,4
  rect(rays,w/2-62,10,124,124,w,h)
  local art=Theme.Container(visual,"Artwork")
  art.ZIndex=5
  rect(art,w/2-46,36,92,60,w,h)
  Art.CashPile(art,definition.tier)
  local coin=Theme.CoinIcon(visual,"Coin")
  coin.ZIndex=10
  rect(coin,20,96,24,24,w,h)
  local amount=label(visual,"PreviewAmount","",Theme.Colors.coins,10)
  rect(amount,46,95,w-66,26,w,h)
  local tag=label(visual,"ValueTag","",Color3.fromRGB(255,86,86),11)
  rect(tag,w-108,34,102,22,w,h)
  tag.TextXAlignment,tag.Visible=Enum.TextXAlignment.Right,definition.key=="CommandersVault"
  local buy=self:PurchaseButton(visual,definition.key,GalaxyCrateShop.Palettes.gold)
  rect(buy,w/2-52,h-41,104,35,w,h)
  holder:SetAttribute("CashAmount",(Catalog.Products[definition.key] :: any).coins)
  table.insert(self.connections,card.Activated:Connect(function() self:Activate(definition.key,buy,visual) end))
  Theme.Motion:BindButton(card,visual,face)
  table.insert(self.cashViews,{root=card,key=definition.key,title=title,art=art,amount=amount,tag=tag,buy=buy,visual=visual})
  self.columnByKey[definition.key]=column
 end
 if #self.cashViews==0 then column.Visible=false end
end

-- Rebirth Skip ("Skip! KEEP UPGRADES"), the rail's last card, shown exactly when the
-- Rebirth screen shows its Skip! button. A bought Skip waits as a credit: "Ready!"
-- opens the Rebirth screen, where Skip! spends it.
function Browser:CreateRebirthSkip()
 local column=self:Column("RebirthSkip",TALL)
 column.Visible=false
 local card,visual,face=cardButton(column,"RebirthSkip",SKIP_TOP,SKIP_BOTTOM,TALL_V)
 local art,_,title,copy=tallContent(visual,"Rebirth Skip!","Rebirth now and keep your upgrades!")
 Theme.Image(art,"Icon",Theme.GemArt.KeepUpgrades,UDim2.fromScale(1,1)).ZIndex=6
 local view=GalaxyCrateShop.PriceButton(visual,"BuyRebirthSkip",GalaxyCrateShop.Palettes.green)
 local buy=view.button
 buy.ZIndex=12
 rect(buy,45,272,155,52,245,335)
 self.priceViews[buy]=view
 local function press()
  if not buy.Active then
   Theme.Motion:Shake(visual)
   cue("Locked","Error",nil,{volume=0.5,voiceKey="Locked",cooldown=0.2})
   return
  end
  self.app.audio:Play("Click")
  self:PressSkip()
 end
 table.insert(self.connections,buy.Activated:Connect(press))
 table.insert(self.connections,card.Activated:Connect(press))
 Theme.Motion:BindButton(card,visual,face)
 self.skip={root=card,visual=visual,title=title,description=copy,buy=buy,view=view,column=column}
end

function Browser:PressSkip()
 local skip=rebirthSkip(self.app.state)
 if not skip then return end
 if (tonumber(skip.credits) or 0)>0 then
  if self.app.rebirthPanel then self.app.rebirthPanel:Open() end
  return
 end
 local commerce,key=self.app.commerce,skip.productKey
 if type(key)~="string" then return end
 commerce:Load(key)
 local status=commerce:State(key)
 if status=="loading" then self.app:Notify("Getting Skip ready… try again in a moment.","info");return end
 commerce:Buy(key)
 if not (commerce.pending and commerce.pending.key==key) and status~="ready" then
  self.app:Notify("Skip isn't available right now.",false)
 end
end

-- The reference's red Gift! button under the window's right edge: it opens the Free
-- Gift popup exactly as the HUD gift does (FreeGiftController:Open).
function Browser:CreateGift()
 local gift=Theme.ActionButton(self.root,"Gift","Gift!",function()
  self.app.audio:Play("Click")
  if self.app.freeGift then self.app.freeGift:Open() end
 end,Theme.ActionColors.danger)
 Theme.ApplyReferenceAccent(gift,ColorSequence.new(Color3.fromRGB(255,102,84),Color3.fromRGB(243,36,59)))
 gift.AnchorPoint,gift.Position,gift.Size=Vector2.new(1,0),UDim2.fromScale(1,1.023),UDim2.fromScale(160/818,44/469)
 gift.ZIndex=6
 Theme.Aspect(gift,160/44)
 local icon=Theme.Image(gift.Visual,"Icon",Art.GiftBox,UDim2.fromScale(0.27,1.2),UDim2.fromScale(0.03,-0.12))
 icon.ZIndex=8
 local caption=gift.Visual.Caption
 caption.Position,caption.Size=UDim2.fromScale(0.3,0.075),UDim2.fromScale(0.66,0.8)
 -- Phone hit area: 48 px tall, mostly downward (the window edge sits just above).
 Theme.PadHit(gift,1,1.78,0.5,0.2,true)
 gift.Visible=false
 self.gift=gift
end

-- Places the visible columns left to right and sizes the canvas. Content count sets
-- the rail's length; the viewport never chooses columns or sizes.
function Browser:Layout()
 if not self.alive then return end
 local x,places=PAD,{}
 for _,column in self.columns do
  if column.frame.Visible then
   table.insert(places,{column=column,x=x})
   x+=column.width+GAP
  end
 end
 local total=x-GAP+PAD
 local ratio=railAspect()
 local canvas=math.max(1,total*CARD_H/ratio)
 local unit=CARD_H/(ratio*canvas) -- one card height in canvas widths
 for _,place in places do
  local frame=place.column.frame
  frame.Position=UDim2.fromScale(place.x*unit,CARD_TOP)
  frame.Size=UDim2.fromScale(place.column.width*unit,CARD_H)
 end
 self.scroll.CanvasSize=UDim2.fromScale(canvas,1)
end

-- Shop opening: back to the first cards, then the cards grow in one after another.
function Browser:Opened()
 self:CancelScroll()
 self.scroll.CanvasPosition=Vector2.zero
 Theme.Motion:Reveal(self.scroll,{limit=12,window=0.35,from=0.8})
 if self.gift.Visible then Theme.Motion:PopScale(self.gift.Visual,0.7,0.3) end
end

function Browser:CancelScroll()
 if self.scrollFinished then self.scrollFinished:Disconnect();self.scrollFinished=nil end
 if self.scrollTween then self.scrollTween:Cancel();self.scrollTween:Destroy();self.scrollTween=nil end
end

-- Deep link: slide the rail to a card. `key` is a card or catalog key ("Galaxy",
-- "DoubleLuck", "PocketCoins", "RebirthSkip") or an old section name ("Passes",
-- "Cash"/"Coins", "Crates"). Unknown keys leave the rail where it is.
function Browser:ScrollTo(key)
 local column=self.columnByKey[SECTION_ALIASES[key] or key]
 if not column or not column.Visible or not self.alive then return end
 self:CancelScroll()
 local scroll=self.scroll
 local canvas,window=scroll.AbsoluteCanvasSize.X,scroll.AbsoluteWindowSize.X
 local lead=PAD*CARD_H*scroll.AbsoluteSize.Y
 local target=Vector2.new(math.clamp(column.Position.X.Scale*canvas-lead,0,math.max(0,canvas-window)),0)
 if self.app.reducedMotion then scroll.CanvasPosition=target;return end
 self.scrollTween=TweenService:Create(scroll,TweenInfo.new(0.32,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{CanvasPosition=target})
 self.scrollFinished=self.scrollTween.Completed:Connect(function(state)
  if state==Enum.PlaybackState.Completed then Theme.Motion:Punch(column,1.04,0.24) end
 end)
 self.scrollTween:Play()
end
-- The older section API: Show("Passes") scrolls the rail to the passes.
Browser.Show=Browser.ScrollTo

function Browser:UpdatePurchase(button,key,root,palette)
 local state,price=self.app.commerce:State(key)
 local shop=self.app.state and self.app.state.shop
 local automatic=state=="owned" and (key=="AutoMerge" or key=="AutoCollectEggs")
 local toggling=self.app.commerce.togglePending[key]~=nil
 button.Text=if automatic then (if toggling then "Updating…" elseif shop.automatic and shop.automatic[key] then "Auto: ON" else "Auto: OFF") else statusText(state,price)
 local view=self.priceViews[button]
 local quoted=state=="ready" and not automatic and type(price)=="number"
 GalaxyCrateShop.ShowPrice(view,if quoted then Theme.Money(price) else button.Text,quoted,state=="restricted" or state=="offsale")
 -- Owned passes turn gold; coin packs keep the reference's orange-gold pills.
 GalaxyCrateShop.SetPalette(view,if state=="owned" then GalaxyCrateShop.Palettes.gold else palette or GalaxyCrateShop.Palettes.green)
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
   -- One reward emphasis: confetti from the bought card, the purchase chime.
   Theme.Motion:Punch(visual,1.06,0.3)
   Theme.Motion:Confetti(self.body,{origin=Theme.Motion:Point(self.body,Theme.Motion:CenterOf(visual)),spread=0.35,seconds=1.4})
   cue("UIPurchase","Claim",nil,{voiceKey="ShopPurchase",cooldown=0.5})
  end
 end
end

function Browser:RenderSkip()
 local skip=rebirthSkip(self.app.state)
 local view=self.skip
 local shown=skip~=nil
 if view.column.Visible~=shown then
  view.column.Visible=shown
  self:Layout()
 end
 if not skip then self.skipReady=false;return end
 local quote=self.app.state.rebirth
 view.description.Text="Rebirth "..Theme.Money(tonumber(quote.nextRank) or 0).." now and keep your upgrades!"
 local credits=tonumber(skip.credits) or 0
 local button,price=view.buy,nil
 if credits>0 then
  -- A bought Skip arriving as a credit: the pill punches to "Ready!".
  if not self.skipReady then Theme.Motion:Punch(view.view.visual,1.2,0.32);cue("Badge","Pop",nil,{voiceKey="SkipReady",cooldown=1}) end
  self.skipReady=true
  GalaxyCrateShop.ShowPrice(view.view,"Ready!",false,false)
  GalaxyCrateShop.SetPalette(view.view,GalaxyCrateShop.Palettes.gold)
  button.Text,button.Active="Rebirth Skip · Ready",true
 else
  self.skipReady=false
  local commerce,key=self.app.commerce,skip.productKey
  local state="unconfigured"
  if type(key)=="string" then
   commerce:Load(key)
   state,price=commerce:State(key)
  end
  local quoted=state=="ready" and type(price)=="number"
  GalaxyCrateShop.ShowPrice(view.view,if quoted then Theme.Money(price) else statusText(state,price),quoted,state=="restricted" or state=="offsale")
  GalaxyCrateShop.SetPalette(view.view,GalaxyCrateShop.Palettes.green)
  button.Text="Rebirth Skip · "..statusText(state,price)
  button.Active=(ready(state) or state=="loading") and commerce.pending==nil and commerce.autoCrate==nil
 end
 button.Selectable=button.Active
end

function Browser:RenderExisting()
 self.galaxy:Render()
 for key,view in self.cards do self:UpdatePurchase(view.buy,key,view.root) end
 for _,view in self.cashViews do self:UpdatePurchase(view.buy,view.key,view.root,GalaxyCrateShop.Palettes.gold) end
 self:RenderSkip()
 local state=self.app.state
 local shop=state and state.shop
 local luck=self.cards.DoubleLuck
 if luck then
  local guaranteed=guaranteedOffers(shop)
  local normal=shop and shop.policyReady==true and shop.paidRandomAllowed==true
  luck.title.Text=if guaranteed then "Guaranteed Offers!" elseif normal then "2x Luck!" else "Luck pass"
  luck.description.Text=if guaranteed then "A Rare+ offer every 10 rolls!"
   elseif normal then PASS_COPY.DoubleLuck else "Checking your benefit…"
  if luck.multiplier then luck.multiplier.Visible=normal==true end
 end
 -- Regional pricing can change unit value. Compare only verified current prices.
 local products=self.app.commerce.products
 local vault=products.CommandersVault
 local bestVault=vault~=nil and vault.status=="ready" and vault.price~=nil and vault.price>0
 if bestVault then
  local unit=vault.price/Catalog.Products.CommandersVault.coins
  for _,view in self.cashViews do
   local entry=products[view.key]
   if view.key~="CommandersVault" and (not entry or entry.status~="ready" or not entry.price or entry.price<=0
    or unit>=entry.price/Catalog.Products[view.key].coins) then bestVault=false;break end
  end
 end
 for _,view in self.cashViews do
  if view.key=="CommandersVault" then view.tag.Text=if bestVault then "BEST VALUE!" else "BIGGEST!" end
 end
 -- Shown until the free chicken is claimed, the HUD gift's own rule.
 local free=state and state.freeGift
 local giftShown=type(free)=="table" and free.enabled==true and free.claimed~=true
 if giftShown and not self.gift.Visible and self.root.Visible then Theme.Motion:PopScale(self.gift.Visual,0.7,0.3) end
 self.gift.Visible=giftShown
end

-- October 14: coin packs pay minutes of income (at least the catalog amount); show
-- the server's live payout as the number beside the coin.
function Browser:RenderCashAmounts()
 local packs=self.app.state and self.app.state.shop and self.app.state.shop.cashPacks or {}
 for _,view in self.cashViews do
  local product=Catalog.Products[view.key]
  view.amount.Text=Theme.Number(packs[view.key] or (product and product.coins) or 0)
 end
end

function Browser:ApplyPresentation()
 -- Shared neutral shell; the cards own their colours (OwnsPopupStyle).
 Theme.ApplyPopupStyle(self.root)
end

function Browser:Render(_force)
 self:RenderExisting();self:RenderCashAmounts();self:ApplyPresentation()
end

function Browser:Destroy()
 if not self.alive then return end
 self.alive=false
 self:CancelScroll()
 for _,connection in self.connections do connection:Disconnect() end
 table.clear(self.connections)
 self.galaxy:Destroy()
 self.root:Destroy()
end
return Browser
