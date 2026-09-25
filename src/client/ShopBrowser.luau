--!strict
-- Approved Chicken Command shop composition with server-approved native checkout.
local TweenService=game:GetService("TweenService")
local Theme=require(script.Parent.UITheme)
local Art=require(script.Parent.ShopPreviewArt)
local Catalog=require(game:GetService("ReplicatedStorage").PetRoll.Shared.ShopCatalog)
local PetCatalog=require(game:GetService("ReplicatedStorage").PetRoll.Shared.PetCatalog)
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
 purchase=ColorSequence.new({
  ColorSequenceKeypoint.new(0,Color3.fromRGB(176,255,1)),
  ColorSequenceKeypoint.new(0.009346,Color3.fromRGB(173,254,0)),
  ColorSequenceKeypoint.new(0.037383,Color3.fromRGB(169,253,0)),
  ColorSequenceKeypoint.new(0.074766,Color3.fromRGB(164,252,0)),
  ColorSequenceKeypoint.new(0.16821999999999998,Color3.fromRGB(149,250,1)),
  ColorSequenceKeypoint.new(0.26167999999999997,Color3.fromRGB(136,246,0)),
  ColorSequenceKeypoint.new(0.35514,Color3.fromRGB(122,243,1)),
  ColorSequenceKeypoint.new(0.4486,Color3.fromRGB(107,240,0)),
  ColorSequenceKeypoint.new(0.54206,Color3.fromRGB(93,238,0)),
  ColorSequenceKeypoint.new(0.63551,Color3.fromRGB(77,235,0)),
  ColorSequenceKeypoint.new(0.72897,Color3.fromRGB(63,232,0)),
  ColorSequenceKeypoint.new(0.82243,Color3.fromRGB(49,229,1)),
  ColorSequenceKeypoint.new(0.91589,Color3.fromRGB(36,226,2)),
  ColorSequenceKeypoint.new(0.98131,Color3.fromRGB(26,224,1)),
  ColorSequenceKeypoint.new(1,Color3.fromRGB(23,223,0)),
 }),
 vaultPurchase=ColorSequence.new({
  ColorSequenceKeypoint.new(0,Color3.fromRGB(255,217,0)),
  ColorSequenceKeypoint.new(0.041237,Color3.fromRGB(255,213,0)),
  ColorSequenceKeypoint.new(0.09278399999999999,Color3.fromRGB(255,210,0)),
  ColorSequenceKeypoint.new(0.19588,Color3.fromRGB(255,202,0)),
  ColorSequenceKeypoint.new(0.29896999999999996,Color3.fromRGB(255,194,1)),
  ColorSequenceKeypoint.new(0.40206000000000003,Color3.fromRGB(255,186,0)),
  ColorSequenceKeypoint.new(0.5051599999999999,Color3.fromRGB(255,178,2)),
  ColorSequenceKeypoint.new(0.6082500000000001,Color3.fromRGB(255,170,1)),
  ColorSequenceKeypoint.new(0.71134,Color3.fromRGB(255,162,2)),
  ColorSequenceKeypoint.new(0.81443,Color3.fromRGB(255,155,0)),
  ColorSequenceKeypoint.new(0.91753,Color3.fromRGB(255,147,1)),
  ColorSequenceKeypoint.new(0.97938,Color3.fromRGB(255,142,0)),
  ColorSequenceKeypoint.new(1,Color3.fromRGB(255,140,0)),
 }),
}
local PASSES={
 {key="AutoCollectEggs",name="Auto Collect Eggs",description="Collect eggs without walking over them.",color=Color3.fromRGB(255,188,32),top=Color3.fromRGB(233,103,10),rim=Color3.fromRGB(255,232,174),title=Color3.fromRGB(255,244,216),icon="EggMagnet",background="orange"},
 {key="DoubleCash",name="2x Cash",description="Earn twice as much cash.",color=Color3.fromRGB(167,230,50),top=Color3.fromRGB(42,169,44),rim=Color3.fromRGB(233,255,160),title=Color3.fromRGB(242,255,216),icon="Cash",background="cash",double=true},
 {key="DoubleEggSpawn",name="2x Egg Spawn",description="Chickens lay eggs twice as often.",color=Color3.fromRGB(9,215,240),top=Color3.fromRGB(1,122,231),rim=Color3.fromRGB(188,239,255),title=Color3.fromRGB(227,250,255),icon="Eggs",background="eggs",double=true},
 {key="AutoMerge",name="Auto Merge",description="Merge matching chickens for you.",color=Color3.fromRGB(8,207,243),top=Color3.fromRGB(0,110,228),rim=Color3.fromRGB(179,240,255),title=Color3.fromRGB(222,248,255),icon="AutoMerge",background="cyan"},
 {key="BiggerArmy",name="Bigger Army",description="+5 deployment slots. Field 15 chickens.",color=Color3.fromRGB(109,229,42),top=Color3.fromRGB(36,163,47),rim=Color3.fromRGB(205,255,160),title=Color3.fromRGB(238,255,207),icon="BiggerArmy",background="army"},
 {key="DoubleLuck",name="2x Luck",description="Twice the luck on every spin.",color=Color3.fromRGB(255,199,37),top=Color3.fromRGB(240,159,7),rim=Color3.fromRGB(255,236,173),title=Color3.fromRGB(255,242,205),icon="DoubleLuck",background="gold",double=true},
}
local EXISTING_STYLES={
 EggMagnet={icon="EggMagnet",background="cyan",palette=4},
 CommanderBanner={icon="CommanderBanner",background="gold",palette=6},
 DoubleBounty={icon="DoubleBounty",background="army",palette=5},
}
local PASS_COPY={
 AutoCollectEggs="Collect eggs into your bag.",DoubleCash="2x earned egg and combat coins.",
 AutoMerge="Merge eligible home chickens.",BiggerArmy="+5 slots. Up to 15 chickens.",DoubleLuck="2x Rare+ roll weights.",
}
-- Quantities match the server catalog; checkout prices always come from Roblox.
local CASH_TIERS={
 {key="ArmyChest",name="Cash Sack",tier=3,amount="1M Cash",art={62.5,46,176}},
 {key="CoopStash",name="Coop Stash",tier=2,amount="100K Cash",art={62.5,46,176}},
 {key="PocketCoins",name="Pocket Cash",tier=1,amount="10K Cash",art={62.5,46,176}},
}

local function frame(parent,name,size,position,color)
 local item=Theme.Frame(parent,name,size,color)
 item.Position=position or UDim2.new()
 return item
end

local function text(parent,name,value,size,position,bounds,color,center)
 local label=Theme.Display(parent,name,value,size,color or P.white)
 label.Position,label.Size,label.ZIndex=position,bounds,7
 label.TextXAlignment=if center then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
 return label
end

local function plain(parent,name,value,size,position,bounds,color,center)
 local label=Theme.Label(parent,name,value,size,color or P.muted)
 label.Font=Enum.Font.SourceSans
 label.Position,label.Size,label.ZIndex=position,bounds,7
 label.TextXAlignment=if center then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
 return label
end

local function panel(parent,name,accent)
 local item=frame(parent,name,UDim2.fromScale(1,1))
 item.ClipsDescendants=true
 Theme.Surface(item,accent)
 return item
end

local function dress(button,color)
 button.ZIndex,button.Font,button.TextColor3=9,Theme.Font,P.white
 button.BackgroundColor3=color
 local sequence=if color==P.gold then Theme.ReferenceGradients.Base
  elseif color==P.green then Theme.ReferenceGradients.Army
  elseif color==P.cyan then Theme.ReferenceGradients.Upgrades else nil
 if sequence then Theme.ApplyReferenceAccent(button,sequence) end
 return button
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
 local self=setmetatable({app=app,alive=true,sections={},tabs={},cards={},existingCards={},
  passCount=0,connections={},cashViews={},motionViews={},entranceSerial=0,activeSection="Passes"},Browser)
 local root=frame(parent,"ShopBrowser",UDim2.fromScale(1,1))
 root.BackgroundTransparency,root.Visible,root.ZIndex=1,false,2
 -- The shared popup visitor must also skip this subtree while another page is open.
 root:SetAttribute("OwnsPopupStyle",true)
 self.root=root
 local scale=Instance.new("UIScale")
 scale.Name,scale.Parent="ShopScale",root
 self.scale=scale
 local header=Theme.Header(root,"Header","Shop",P.gold)
 header.Size,header.ZIndex=UDim2.new(1,0,0,64),4
 header.PageIcon.Visible,header.PageIcon.Image=true,Theme.Assets.Shop
 header.PageIcon.Size,header.PageIcon.Position=UDim2.fromOffset(50,50),UDim2.fromOffset(8,7)
 header.Title.Position,header.Title.Size,header.Title.TextSize=UDim2.fromOffset(64,0),UDim2.new(1,-126,1,0),36
 self.header=header
 local close=Theme.ActionButton(header,"Close","X",function()
  self.app.audio:Play("Click");self.app:ClosePanel()
 end,Theme.ActionColors.danger)
 close.Position,close.Size,close.TextSize=UDim2.new(1,-56,0,8),UDim2.fromOffset(48,48),28
 dress(close,Theme.ActionColors.danger)
 self.closeButton=close
 local body=frame(root,"Body",UDim2.new(1,0,1,-72),UDim2.fromOffset(0,72))
 Theme.Surface(body)
 body.ClipsDescendants=true
 self.body=body
 self.previewStatus=plain(body,"PurchaseStatus","Prices from Roblox · purchases deliver to this account",14,UDim2.new(0,12,1,-32),UDim2.new(1,-24,0,24),P.muted,true)
 -- Use the main HUD's icon buttons, outside the scrolling content.
 local nav=frame(root,"SectionNavigation",UDim2.fromOffset(68,300),UDim2.fromOffset(0,72))
 nav.BackgroundTransparency,nav.ZIndex=1,5
 self.navigation=nav
 local navLayout=Instance.new("UIListLayout")
 navLayout.FillDirection,navLayout.Padding,navLayout.SortOrder,navLayout.Parent=Enum.FillDirection.Vertical,UDim.new(0,8),Enum.SortOrder.LayoutOrder,nav
 for index,key in {"Passes","Cash"} do
  local button=Theme.IconButton(nav,key,key,"",function()
   self.app.audio:Play("Click");self:ScrollTo(key)
  end)
  button.LayoutOrder,button.ZIndex=index,6
  button.TextColor3=if index==1 then P.gold else P.white
  button:SetAttribute("Selected",index==1)
  local icon=button.Visual.Icon
  if key=="Passes" then Art.PassIcon(icon,"BiggerArmy")
  else Art.CashPile(icon,1) end
  local indicator=frame(button.Visual,"SelectedIndicator",UDim2.new(1,-8,0,3),UDim2.new(0,4,1,-3),P.gold)
  indicator.Visible,indicator.ZIndex=index==1,7
  self.tabs[key]=button
 end
 local scroll=Instance.new("ScrollingFrame")
 scroll.Name,scroll.Position,scroll.Size="ShopSections",UDim2.fromOffset(12,10),UDim2.new(1,-24,1,-34)
 scroll.BackgroundTransparency,scroll.BorderSizePixel,scroll.ScrollBarThickness=1,0,6
 scroll.ScrollingDirection,scroll.ScrollBarImageColor3,scroll.ClipsDescendants=Enum.ScrollingDirection.Y,P.gold,true
 scroll.CanvasSize,scroll.AutomaticCanvasSize=UDim2.new(),Enum.AutomaticSize.Y
 scroll.VerticalScrollBarInset,scroll.ElasticBehavior=Enum.ScrollBarInset.Always,Enum.ElasticBehavior.WhenScrollable
 scroll.ZIndex,scroll.Parent=3,body
 self.scroll,self.grid=scroll,scroll
 local padding=Instance.new("UIPadding")
 padding.PaddingLeft,padding.PaddingRight,padding.PaddingTop,padding.PaddingBottom=UDim.new(0,4),UDim.new(0,4),UDim.new(0,4),UDim.new(0,12)
 padding.Parent=scroll
 local layout=Instance.new("UIListLayout")
 layout.Padding,layout.SortOrder,layout.Parent=UDim.new(0,24),Enum.SortOrder.LayoutOrder,scroll
 self.layout=layout
 self:CreatePasses();self:CreateCash();self:CreateDetails()
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
 table.insert(self.connections,parent:GetPropertyChangedSignal("Size"):Connect(function() self:Resize() end))
 table.insert(self.connections,root:GetPropertyChangedSignal("Visible"):Connect(function()
  if root.Visible then self:Resize();self:AnimateSection(self.activeSection) else self:CloseDetails();self:CancelScroll();self:CancelArtworkMotion() end
 end))
 table.insert(self.connections,parent:GetPropertyChangedSignal("Visible"):Connect(function()
  if parent.Visible and root.Visible then self:AnimateSection(self.activeSection)
  else self:CloseDetails();self:CancelArtworkMotion() end
 end))
 self:ApplyPresentation()
 self:Resize()
 return self
end

function Browser:Section(key,title,order)
 local section=frame(self.scroll,key,UDim2.new(1,-6,0,400))
 section.LayoutOrder,section.BackgroundTransparency=order,1
 text(section,"Heading",title,24,UDim2.new(),UDim2.new(1,0,0,32),P.white,true)
 self.sections[key]=section
 return section
end

function Browser:PurchaseButton(parent,key,color)
 local button
 button=Theme.ActionButton(parent,"Buy"..key,"Loading",function()
  if not button.Active then return end
  self.app.audio:Play("Click")
  local state=self.app.commerce:State(key)
  if state=="owned" then self.app.commerce:Toggle(key)
  elseif state=="ready" and key=="DoubleLuck" then
   self:ShowDetails("Luck",key)
  else self.app.commerce:Buy(key) end
 end,color or P.green)
 button.TextSize=20
 button.Active,button.Selectable=false,false
 button:SetAttribute("CatalogKey",key)
 dress(button,color or P.green)
 button.Visual.Caption.TextColor3=P.white
 return button
end

function Browser:CreatePasses()
 local section=self:Section("Passes","Game passes",1)
 local grid=frame(section,"PassCards",UDim2.new(1,0,0,500),UDim2.fromOffset(0,42))
 grid.BackgroundTransparency=1
 self.passGrid=grid
 local layout=Instance.new("UIGridLayout")
 layout.CellPadding,layout.SortOrder,layout.Parent=UDim2.fromOffset(14,14),Enum.SortOrder.LayoutOrder,grid
 self.passLayout=layout
 for _,definition in PASSES do
  local offer=Catalog.Definitions[definition.key]
  if not offer or offer.enabled==false then continue end
  self.passCount+=1
  local card=panel(grid,definition.key,definition.color)
  card.LayoutOrder=self.passCount
  local title=text(card,"Title",definition.name,24,UDim2.fromOffset(16,12),UDim2.new(1,-32,0,44),definition.color,true)
  local art=frame(card,"Artwork",UDim2.new(0.46,0,0,108),UDim2.fromOffset(8,61))
  art.BackgroundTransparency,art.ZIndex=1,3
  local rays=Art.PassBackdrop(card,definition.background)
  local multiplier=Art.PassIcon(art,definition.icon,definition.double)
  -- Figma uses the display face with a dark outline and 2px hard shadow, not plain copy.
  local description=text(card,"Description",PASS_COPY[definition.key] or Catalog.Definitions[definition.key].description,18,UDim2.new(0.48,0,0,59),UDim2.new(0.52,-16,0,116),FIGMA.text,true)
  local buy=self:PurchaseButton(card,definition.key)
  buy.Position,buy.Size=UDim2.new(0,14,1,-64),UDim2.new(1,-28,0,50)
  card:SetAttribute("Owned",false)
  self.cards[definition.key]={root=card,title=title,art=art,rays=rays,multiplier=multiplier,description=description,buy=buy,palette=definition}
  if definition.key=="DoubleLuck" then
   local details=Theme.ActionButton(card,"Details","Details",function()
    self.app.audio:Play("Click");self:ShowDetails("Luck")
   end,P.cyan)
   dress(details,P.cyan);self.cards[definition.key].details=details
  end
  self:BindOfferMotion(self.cards[definition.key],"Passes")
 end
 self:CreateExistingPasses(section)
end

function Browser:CreateExistingPasses(_section)
 -- Keep configured offers adjacent in the same grid when release features are hidden.
 for _,key in {"EggMagnet","CommanderBanner","DoubleBounty"} do
  local definition=Catalog.Definitions[key]
  if not definition or definition.enabled==false then continue end
  self.passCount+=1
  local style=EXISTING_STYLES[key]
  local palette=PASSES[style.palette]
  local entry=panel(self.passGrid,key,palette.color)
  entry.LayoutOrder=self.passCount
  local title=text(entry,"Title",definition.name,24,UDim2.new(),UDim2.new(),palette.title,true)
  local description=text(entry,"Description",definition.description,22,UDim2.new(),UDim2.new(),FIGMA.text,true)
  local art=frame(entry,"Artwork",UDim2.fromOffset(140,140))
  art.BackgroundTransparency,art.ZIndex=1,3
  Art.PassIcon(art,style.icon)
  local rays=Art.PassBackdrop(entry,style.background)
  local buy=self:PurchaseButton(entry,key)
  local view={root=entry,title=title,description=description,art=art,rays=rays,buy=buy,palette=palette}
  self.existingCards[key],self.cards[key]=view,view
  self:BindOfferMotion(view,"Passes")
 end
end

function Browser:UpdatePurchase(button,key,root)
 local state,price=self.app.commerce:State(key)
 local shop=self.app.state and self.app.state.shop
 local automatic=state=="owned" and (key=="AutoMerge" or key=="AutoCollectEggs")
 local toggling=self.app.commerce.togglePending[key]~=nil
 button.Text=if automatic then (if toggling then "Updating…" elseif shop.automatic and shop.automatic[key] then "Auto: ON" else "Auto: OFF") else statusText(state,price)
 button.Active=(ready(state) or automatic) and self.app.commerce.pending==nil and not toggling
 button.Selectable=button.Active
 dress(button,if state=="owned" then P.gold elseif button.Active then P.green else P.tab)
 button:SetAttribute("State",state)
 button:SetAttribute("UnavailableReason",if ready(state) or automatic then nil else state)
 if root then root:SetAttribute("Owned",state=="owned") end
end

function Browser:RenderExisting()
 for key,view in self.cards do self:UpdatePurchase(view.buy,key,view.root) end
 for _,view in self.cashViews do self:UpdatePurchase(view.buy,view.key) end
 self:UpdatePurchase(self.cashBuy,"CommandersVault")
 local shop=self.app.state and self.app.state.shop
 local luck=self.cards.DoubleLuck
 local guaranteed=guaranteedOffers(shop)
 local normal=shop and shop.policyReady==true and shop.paidRandomAllowed==true
 luck.title.Text=if guaranteed then "Guaranteed Offers" elseif normal then "2x Luck" else "Luck pass"
 luck.description.Text=if guaranteed then "A Rare+ offer every 10 rolls"
  elseif normal then PASS_COPY.DoubleLuck else "Checking your available benefit…"
 if luck.multiplier then luck.multiplier.Visible=normal==true end
 local saving=not shop or not shop.productReady
 self.previewStatus.Text=if saving then "Cash purchases wait for a saved profile."
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
 self.cashSubtitle.Text=if bestVault then "Best value" else "Largest cash pack"
 self:RenderDetails()
end

function Browser:CreateCash()
 local section=self:Section("Cash","Cash packs",2)
 local vault=panel(section,"CommandersVault",FIGMA.cash)
 self.cashFeatured=vault
 self.cashRays=Art.ProductRays(vault,Color3.new(1,1,1))
 local art=frame(vault,"CashOverflow",UDim2.fromOffset(940,346.0764))
 art.BackgroundTransparency,art.ZIndex=1,3
 self.cashArt=art
 self.cashOverflow=Art.CashOverflow(art)
 self.cashShade=frame(vault,"CashCopyShade",UDim2.fromOffset(651,248),UDim2.fromOffset(289,0))
 -- The current Figma banner has no extra copy overlay; keep the cash artwork unmuted.
 self.cashShade.Visible,self.cashShade.ZIndex=false,6
 self.cashTitle=text(vault,"Title","Commander's Vault",28,UDim2.new(),UDim2.fromOffset(513.2,48))
 self.cashSubtitle=text(vault,"PackSize","Best Value",22,UDim2.new(),UDim2.fromOffset(513.2,32),Color3.fromRGB(176,255,1))
 self.cashNote=text(vault,"PreviewAmount","10M Cash",56,UDim2.new(),UDim2.fromOffset(500,64),FIGMA.text,false)
 self.cashNote.Font=Theme.Font
 vault:SetAttribute("CashAmount",Catalog.Products.CommandersVault.coins)
 self.cashBuy=self:PurchaseButton(vault,"CommandersVault",P.gold)
 local shelf=frame(section,"CashTiers",UDim2.new(1,0,0,288))
 shelf.BackgroundTransparency=1
 self.cashShelf=shelf
 local layout=Instance.new("UIGridLayout")
 layout.CellPadding,layout.SortOrder,layout.Parent=UDim2.fromOffset(16,16),Enum.SortOrder.LayoutOrder,shelf
 self.cashLayout=layout
 for i,definition in CASH_TIERS do
  local card=panel(shelf,definition.key,FIGMA.cash)
  card.LayoutOrder=i
  local title=text(card,"Title",definition.name,24,UDim2.fromOffset(16,12),UDim2.new(1,-32,0,32),P.white,true)
  local rays=Art.ProductRays(card,Color3.new(1,1,1))
  local icon=frame(card,"Artwork",UDim2.fromOffset(definition.art[3],definition.art[3]),UDim2.fromOffset(definition.art[1],definition.art[2]))
  icon.BackgroundTransparency,icon.ZIndex=1,3
  Art.CashPile(icon,definition.tier)
  local note=text(card,"PreviewAmount",definition.amount,40,UDim2.new(),UDim2.fromOffset(269,48),FIGMA.text,true)
  note.Font=Theme.Font
  local buy=self:PurchaseButton(card,definition.key)
  self.cashViews[i]={root=card,key=definition.key,title=title,art=icon,rays=rays,note=note,buy=buy}
  self:BindOfferMotion(self.cashViews[i],"Cash")
 end
end

function Browser:CreateDetails()
 local root=frame(self.body,"PurchaseDetails",UDim2.fromScale(1,1),UDim2.new(),P.ink)
 root.BackgroundTransparency,root.Visible,root.Active,root.ZIndex=0.04,false,true,20
 root:SetAttribute("OwnsPopupStyle",true)
 self.detailsRoot=root
 self.detailsTitle=text(root,"Title","Details",30,UDim2.fromOffset(20,12),UDim2.fromOffset(948,44))
 self.detailsDescription=plain(root,"Description","",19,UDim2.fromOffset(20,62),UDim2.fromOffset(948,66),P.white)
 self.detailsDescription.TextWrapped=true
 local scroll=Instance.new("ScrollingFrame")
 scroll.Name,scroll.Position,scroll.Size="Outcomes",UDim2.fromOffset(20,144),UDim2.fromOffset(948,392)
 scroll.BackgroundTransparency,scroll.BorderSizePixel,scroll.ScrollBarThickness=1,0,6
 scroll.ScrollBarImageColor3,scroll.AutomaticCanvasSize,scroll.CanvasSize=P.cyan,Enum.AutomaticSize.Y,UDim2.new()
 scroll.ScrollingDirection,scroll.Parent=Enum.ScrollingDirection.Y,root
 scroll.VerticalScrollBarInset=Enum.ScrollBarInset.Always
 local layout=Instance.new("UIListLayout")
 layout.Padding,layout.SortOrder,layout.Parent=UDim.new(0,4),Enum.SortOrder.LayoutOrder,scroll
 self.detailsScroll=scroll
 self.detailsNote=plain(root,"Note","",16,UDim2.fromOffset(20,540),UDim2.fromOffset(948,40),P.muted)
 self.detailsNote.TextWrapped=true
 self.detailsBack=Theme.ActionButton(root,"Back","Back",function()
  self.app.audio:Play("Click");self:CloseDetails()
 end,P.cyan)
 self.detailsBack.Position,self.detailsBack.Size=UDim2.fromOffset(20,596),UDim2.fromOffset(190,48)
 dress(self.detailsBack,P.cyan)
 self.detailsBuy=Theme.ActionButton(root,"Continue","Buy",function()
  if not self.detailsBuy.Active or not self.detailsPurchase then return end
  self.app.audio:Play("Click")
  self.app.commerce:Buy(self.detailsPurchase)
 end,P.green)
 self.detailsBuy.Position,self.detailsBuy.Size=UDim2.fromOffset(230,596),UDim2.fromOffset(738,48)
 dress(self.detailsBuy,P.green)
 for _,item in root:GetDescendants() do if item:IsA("GuiObject") then item.ZIndex+=20 end end
end

function Browser:ShowDetails(kind,purchaseKey)
 self:CancelScroll()
 self.detailsKind,self.detailsPurchase=kind,purchaseKey
 self.detailsRoot.Visible=true
 self.detailsScroll.CanvasPosition=Vector2.zero
 self:RenderDetails()
end

function Browser:CloseDetails()
 if self.detailsRoot then self.detailsRoot.Visible=false end
 self.detailsKind,self.detailsPurchase=nil,nil
end

local function chanceText(chance)
 if type(chance)~="number" or chance<=0 then return "0%" end
 local percent=chance*100
 local digits=math.clamp(4-math.min(0,math.floor(math.log10(percent))),4,12)
 return string.format("%."..digits.."f",percent):gsub("0+$",""):gsub("%.$","").."%"
end

function Browser:RenderDetails()
 if not self.detailsKind or not self.detailsRoot.Visible then return end
 local shop=self.app.state and self.app.state.shop
 local rows={}
 local available=false
 local guaranteed=guaranteedOffers(shop)
 local note="Your available benefit is still being checked."
 if guaranteed then
  local guarantee=shop.luckGuarantee
  available=type(guarantee)=="table" and type(guarantee.sequence)=="table" and #guarantee.sequence>0
   and type(guarantee.interval)=="number" and guarantee.interval>0
   and type(guarantee.rollsRemaining)=="number" and PetCatalog[guarantee.nextSpecies]~=nil
  self.detailsTitle.Text="2x Luck · Guaranteed Offers"
  self.detailsDescription.Text="For this account, 2x Luck gives a known Rare+ offer every 10 manual rolls; regular rolls keep their normal odds. Normal coin price applies; higher-level offers cost more. Offers last until reroll or leaving."
  if available then
   table.insert(rows,{name="Fixed repeating order",value="Level 1 price (coins)"})
   for index,species in guarantee.sequence do
    local pet=PetCatalog[species]
    if not pet or type(pet.price)~="number" then available=false;break end
    table.insert(rows,{name=index..". "..pet.name,value=Theme.Money(pet.price).." coins"})
   end
   if available then
    local owned=shop.owned and shop.owned.DoubleLuck
    note=(if owned then "Next: " else "After purchase, next: ")..PetCatalog[guarantee.nextSpecies].name
     .." in "..guarantee.rollsRemaining..(if guarantee.rollsRemaining==1 then " roll" else " rolls")
     ..". Progress saves; this order repeats."
   end
  end
 elseif shop and shop.policyReady==true and shop.paidRandomAllowed==true then
  self.detailsTitle.Text="2x Luck · roll chances"
  self.detailsDescription.Text="Doubles Rare+ weights before all chances are normalized. Your current coin Luck upgrades are included."
  local odds=shop and shop.luckOdds
  available=odds and type(odds.withoutPass)=="table" and type(odds.withPass)=="table"
  if available then
   table.insert(rows,{name="Every possible chicken",value="Without pass  →  With pass"})
   for _,species in PetCatalog.Order do
    local before,after=odds.withoutPass[species] or 0,odds.withPass[species] or 0
    if before>0 or after>0 then table.insert(rows,{name=PetCatalog[species].name,value=chanceText(before).."  →  "..chanceText(after)}) end
   end
  end
  note="Percentages are rounded; their displayed total may differ slightly from 100%."
 else
  self.detailsTitle.Text="Luck pass"
  self.detailsDescription.Text="Checking which benefit is available for your account."
 end
 if not available then
  rows={{name="Details are not ready. Please check again.",value=""}}
 end
 local signature=self.detailsKind
 for _,row in rows do signature..="|"..row.name..":"..row.value end
 if self.detailsRowsKey~=signature then
  self.detailsRowsKey=signature
  for _,item in self.detailsScroll:GetChildren() do if item:IsA("GuiObject") and item~=self.detailsDescription and item~=self.detailsNote then item:Destroy() end end
  for index,row in rows do
   local entry=frame(self.detailsScroll,"Outcome"..index,UDim2.new(1,-12,0,60))
   entry.BackgroundTransparency,entry.LayoutOrder,entry.ZIndex=1,index,21
   local name=plain(entry,"Name",row.name,20,UDim2.fromOffset(0,0),UDim2.new(0.5,0,1,0),P.white)
   local value=plain(entry,"Chance",row.value,20,UDim2.fromScale(0.5,0),UDim2.new(0.5,0,1,0),P.white)
   name.TextWrapped,value.TextWrapped=true,true
   value.TextXAlignment=Enum.TextXAlignment.Right
   name.ZIndex,value.ZIndex=22,22
  end
 end
 self.detailsNote.Text=note
 self.detailsBuy.Visible=self.detailsPurchase~=nil
 if self.detailsPurchase then
  self:UpdatePurchase(self.detailsBuy,self.detailsPurchase)
  if not available then self.detailsBuy.Active=false end
 end
 self.detailsBuy.Selectable=self.detailsBuy.Active
end

function Browser:BindOfferMotion(view,section)
 view.section=section
 table.insert(self.motionViews,view)
 local function pose(hot)
  if not self.alive then return end
  local scale=Theme.Motion:Scale(view.art)
  local active=hot and self.root.Visible and self.root.Parent.Visible and not self.app.reducedMotion
  Theme.Motion:Tween(scale,"shop-art",{Scale=if active then 1.065 else 1},0.2,Enum.EasingStyle.Back)
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
  local scale=view.art:FindFirstChild("MotionScale")
  if scale then
   Theme.Motion:Cancel(scale,"scale");Theme.Motion:Cancel(scale,"shop-art");scale.Scale=1
  end
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
    Theme.Motion:Pop(view.art,0.88)
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
 local first=self.sections.Passes
 local authored=first.Size.Y.Offset
 self.scrollScale=if authored>0 then first.AbsoluteSize.Y/authored else 1
 self.sectionStarts={}
 for key,section in self.sections do
  self.sectionStarts[key]=section.AbsolutePosition.Y-scroll.AbsolutePosition.Y+scroll.CanvasPosition.Y
 end
 self.maxScroll=math.max(0,scroll.AbsoluteCanvasSize.Y-scroll.AbsoluteWindowSize.Y)
end

function Browser:ScrollTo(key)
 self:CloseDetails()
 self:RefreshScrollMetrics()
 if not self.sectionStarts[key] then return end
 self:CancelScroll()
 local target=Vector2.new(0,math.clamp(self.sectionStarts[key]-4*self.scrollScale,0,self.maxScroll))
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
 local y,active=self.scroll.CanvasPosition.Y,"Passes"
 for _,key in {"Passes","Cash"} do
  if y>=self.sectionStarts[key]-28*self.scrollScale then active=key end
 end
 if self.maxScroll>0 and y>=self.maxScroll-2*self.scrollScale then active="Cash" end
 if active==self.activeSection then return end
 self.activeSection=active
 for key,button in self.tabs do
  local selected=key==active
  button.TextColor3=if selected then P.gold else P.white
  button.Visual.SelectedIndicator.Visible=selected
  button:SetAttribute("Selected",selected)
 end
end

function Browser:ApplyPresentation()
 -- Explicit Shop direction: saturated Mini War-style offers, shared neutral shell.
 Theme.ApplyPopupStyle(self.root)
 local function offerSurface(item,color,top,rimColor)
  item.BackgroundColor3,item.BackgroundTransparency=Color3.new(1,1,1),0
  Theme.Gradient(item,top or color:Lerp(P.ink,0.88),color)
  local gradient=item:FindFirstChildWhichIsA("UIGradient")
  if gradient then
   -- The popup visitor assigns a translucent neutral gradient on every render.
   -- Reset its alpha as well as its color so the offer keeps its full saturation.
   gradient.Enabled,gradient.Rotation,gradient.Transparency=true,90,NumberSequence.new(0)
  end
  local edge=Theme.Stroke(item,color,3)
  edge.Transparency=0
  local rim=item:FindFirstChild("InnerRim")
  if rim and rim:IsA("Frame") then
   rim.Visible,rim.BackgroundTransparency=true,1
   local keyline=Theme.Stroke(rim,rimColor or color:Lerp(P.white,0.65),1)
   keyline.Transparency=0.48
  end
 end
 -- Keep native buttons and their unavailable guards, but restore the Figma face
 -- after the shared popup visitor has applied its general-purpose styling.
 local function offerButton(button,sequence)
  Theme.ApplyReferenceAccent(button,sequence)
  button.TextColor3,button.Visual.Caption.TextColor3=FIGMA.text,FIGMA.text
 end
 offerSurface(self.cashFeatured,FIGMA.cash,FIGMA.cashTop,FIGMA.cashRim)
 self.sections.Passes.Heading.TextColor3,self.sections.Cash.Heading.TextColor3=FIGMA.text,FIGMA.text
 for _,definition in PASSES do
  local view=self.cards[definition.key]
  if not view then continue end
  offerSurface(view.root,definition.color,definition.top,definition.rim)
  view.title.TextColor3,view.description.TextColor3=definition.title,FIGMA.text
  view.root.InnerRim.UIStroke.Transparency=0.28
  offerButton(view.buy,FIGMA.purchase)
 end
 for _,view in self.existingCards do
  local definition=view.palette
  offerSurface(view.root,definition.color,definition.top,definition.rim)
  view.root.InnerRim.UIStroke.Transparency=0.28
  view.title.TextColor3,view.description.TextColor3=definition.title,FIGMA.text
  offerButton(view.buy,if view.root:GetAttribute("Owned") then FIGMA.vaultPurchase else FIGMA.purchase)
 end
 for _,view in self.cashViews do
  offerSurface(view.root,FIGMA.cash,FIGMA.cashTop,FIGMA.cashRim)
  view.title.TextColor3,view.note.TextColor3=FIGMA.text,FIGMA.text
  offerButton(view.buy,FIGMA.purchase)
 end
 self.cashTitle.TextColor3,self.cashNote.TextColor3=FIGMA.text,FIGMA.text
 offerButton(self.cashBuy,FIGMA.vaultPurchase)
 -- The shared popup visitor must not recolor the illustration's copy-protection fade.
 self.cashShade.Visible=true
 self.cashShade.BackgroundColor3,self.cashShade.BackgroundTransparency=FIGMA.cashTop,0
 Theme.Gradient(self.cashShade,Color3.new(1,1,1),Color3.new(1,1,1))
 local copyFade=self.cashShade:FindFirstChildWhichIsA("UIGradient")
 if copyFade then
  copyFade.Enabled,copyFade.Rotation=true,0
  copyFade.Transparency=NumberSequence.new({
   NumberSequenceKeypoint.new(0,0.14),NumberSequenceKeypoint.new(0.48,0.5),NumberSequenceKeypoint.new(1,1),
  })
 end
end

-- Keep the established SourceSans fonts while matching Figma's measured metrics.
-- Fixed authored sizes prevent repeated renders from compounding the conversion.
function Browser:ApplyTypography()
 local function apply(label,size,lineHeight)
  local nativeSize=size*(if self.compact then 1 else 1.23)
  local leading=(lineHeight or size*1.2)/nativeSize
  label.TextSize,label.LineHeight,label.TextScaled=nativeSize,leading,false
  -- Theme.Display and buttons draw their visible glyphs in child text labels.
  for _,copy in label:GetDescendants() do
   if copy:IsA("TextLabel") then
    copy.TextSize,copy.LineHeight,copy.TextScaled=nativeSize,leading,false
   end
  end
 end
 apply(self.header.Title,36)
 apply(self.closeButton,28)
 apply(self.previewStatus,14)
 for _,button in self.tabs do apply(button,16) end
 for _,section in self.sections do apply(section.Heading,24) end
 for _,view in self.cards do
  apply(view.title,24,32)
  apply(view.description,22,26)
  apply(view.buy,20)
  if view.details then apply(view.details,17) end
  if view.multiplier then apply(view.multiplier,53.04) end
 end
 apply(self.cashTitle,32,40)
 apply(self.cashNote,56,64)
 apply(self.cashSubtitle,24,32)
 apply(self.cashBuy,26.3214)
 for _,view in self.cashViews do
  apply(view.title,24,30)
  apply(view.note,40,48)
  apply(view.buy,20)
 end
end

function Browser:Resize()
 if not self.alive then return end
 local width,height=self.app.panelWidth or 1080,self.app.panelHeight or 740
 local key=width..":"..height
 if self.layoutKey==key then self:ApplyTypography();self:UpdateSection();return end
 self.layoutKey=key
 self:CancelScroll()
 self.compact=width<900 or height<600
 local rail=if width<600 then 64 else 92
 local mainWidth=width-rail
 local contentWidth=mainWidth-36
 local columns=math.clamp(math.floor((contentWidth+16)/276),1,3)
 local cardWidth=(contentWidth-(columns-1)*16)/columns
 local passRows=math.ceil(self.passCount/columns)
 local passHeight=passRows*300+math.max(0,passRows-1)*16
 self.scale.Scale=1
 self.root.Size,self.root.Position,self.root.AnchorPoint=UDim2.fromScale(1,1),UDim2.new(),Vector2.zero
 self.header.Position,self.header.Size=UDim2.fromScale(rail/width,0),UDim2.new(1,-rail,0,64)
 self.header.Title.Position,self.header.Title.Size=UDim2.fromOffset(58,0),UDim2.new(1,-116,1,0)
 self.header.PageIcon.Size,self.header.PageIcon.Position=UDim2.fromOffset(48,48),UDim2.fromOffset(4,8)
 self.closeButton.Size,self.closeButton.Position=UDim2.fromOffset(52,52),UDim2.new(1,-56,0,6)
 self.body.Position,self.body.Size=UDim2.new(rail/width,0,0,72),UDim2.new(1,-rail,1,-72)
 self.navigation.AnchorPoint=Vector2.new(0,0.5)
 self.navigation.Position,self.navigation.Size=UDim2.fromScale(0,0.5),UDim2.fromOffset(rail-8,184)
 self.scroll.Position,self.scroll.Size=UDim2.fromOffset(12,8),UDim2.new(1,-24,1,-44)
 self.previewStatus.Position,self.previewStatus.Size=UDim2.new(0,8,1,-32),UDim2.new(1,-16,0,28)
 self.previewStatus.TextWrapped=true
 self.layout.Padding=UDim.new(0,24)
 for _,button in self.tabs do
  button.Size=UDim2.new(1,0,0,88)
  local visual=button.Visual
  visual.Icon.Size,visual.Icon.Position=UDim2.fromScale(1,0.74),UDim2.new()
  visual.Label.Position,visual.Label.Size=UDim2.fromScale(0,0.76),UDim2.fromScale(1,0.24)
  visual.LabelShade.Size,visual.LabelShade.Position=UDim2.fromScale(1.2,1.2),UDim2.fromScale(0.5,0.42)
 end
 self.passGrid.Position,self.passGrid.Size=UDim2.fromOffset(0,40),UDim2.new(1,0,0,passHeight)
 self.passLayout.CellPadding,self.passLayout.CellSize=UDim2.fromOffset(16,16),UDim2.new(1/columns,-math.ceil(16*(columns-1)/columns),0,300)
 self.passLayout.FillDirectionMaxCells=columns
 local function layoutPass(view)
  view.title.Position,view.title.Size=UDim2.fromOffset(8,8),UDim2.new(1,-16,0,44)
  view.title.TextWrapped=true
  view.art.AnchorPoint=Vector2.new(0.5,0.5)
  view.art.Position,view.art.Size=UDim2.fromScale(0.26,0.46),UDim2.fromOffset(math.min(156,cardWidth*0.48),math.min(156,cardWidth*0.48))
  view.description.Position,view.description.Size=UDim2.new(0.52,0,0,56),UDim2.new(0.48,-8,0,if view.details then 110 else 164)
  view.description.TextWrapped,view.description.TextXAlignment=true,Enum.TextXAlignment.Center
  if view.details then
   view.details.Position,view.details.Size=UDim2.new(0.52,0,0,176),UDim2.new(0.48,-8,0,48)
  end
  view.buy.Position,view.buy.Size=UDim2.new(0,12,1,-64),UDim2.new(1,-24,0,52)
 end
 for _,view in self.cards do layoutPass(view) end
 for _,view in self.existingCards do layoutPass(view) end
 self.sections.Passes.Size=UDim2.new(1,-6,0,40+passHeight)
 local featuredHeight=if contentWidth<500 then 284 else 248
 self.cashFeatured.Position,self.cashFeatured.Size=UDim2.fromOffset(0,40),UDim2.new(1,0,0,featuredHeight)
 local copyWidth=if contentWidth<500 then 1 else 0.58
 self.cashTitle.Position,self.cashTitle.Size=UDim2.fromOffset(16,12),UDim2.new(copyWidth,-32,0,40)
 self.cashNote.Position,self.cashNote.Size=UDim2.fromOffset(16,54),UDim2.new(copyWidth,-32,0,64)
 self.cashSubtitle.Position,self.cashSubtitle.Size=UDim2.fromOffset(16,120),UDim2.new(copyWidth,-32,0,56)
 self.cashTitle.TextWrapped,self.cashSubtitle.TextWrapped=true,true
 self.cashTitle.TextXAlignment,self.cashNote.TextXAlignment,self.cashSubtitle.TextXAlignment=Enum.TextXAlignment.Left,Enum.TextXAlignment.Left,Enum.TextXAlignment.Left
 self.cashRays.Visible=false
 self.cashShade.Position,self.cashShade.Size=UDim2.new(),UDim2.fromScale(copyWidth+0.1,1)
 self.cashArt.Position,self.cashArt.Size=UDim2.fromScale(0,-0.3),UDim2.fromScale(1,1.3)
 self.cashBuy.Position,self.cashBuy.Size=UDim2.new(if contentWidth<500 then 0 else 0.63,16,1,-76),UDim2.new(if contentWidth<500 then 1 else 0.37,-32,0,60)
 local cashRows=math.ceil(#self.cashViews/columns)
 local cashHeight=cashRows*348+math.max(0,cashRows-1)*16
 self.cashShelf.Position,self.cashShelf.Size=UDim2.fromOffset(0,featuredHeight+56),UDim2.new(1,0,0,cashHeight)
 self.cashLayout.CellPadding,self.cashLayout.CellSize=UDim2.fromOffset(16,16),UDim2.new(1/columns,-math.ceil(16*(columns-1)/columns),0,348)
 self.cashLayout.FillDirectionMaxCells=columns
 for _,view in self.cashViews do
  view.title.Position,view.title.Size=UDim2.fromOffset(12,8),UDim2.new(1,-24,0,36)
  view.art.AnchorPoint=Vector2.new(0.5,0.5)
  view.art.Position,view.art.Size=UDim2.fromScale(0.5,0.41),UDim2.fromOffset(math.min(200,cardWidth-24),180)
  view.rays.Position,view.rays.Size=UDim2.fromScale(0,-0.1),UDim2.fromScale(1,1)
  view.note.Position,view.note.Size=UDim2.fromOffset(12,230),UDim2.new(1,-24,0,48)
  view.buy.Position,view.buy.Size=UDim2.new(0,12,1,-64),UDim2.new(1,-24,0,52)
 end
 self.sections.Cash.Size=UDim2.new(1,-6,0,featuredHeight+56+cashHeight)
 -- Details keep their actions fixed while explanation/outcomes scroll on short phones.
 self.detailsTitle.Position,self.detailsTitle.Size=UDim2.fromOffset(12,4),UDim2.new(1,-24,0,44)
 self.detailsTitle.TextSize=if mainWidth<400 then 22 else 30
 self.detailsScroll.Position,self.detailsScroll.Size=UDim2.fromOffset(12,52),UDim2.new(1,-24,1,-116)
 self.detailsDescription.Parent,self.detailsDescription.LayoutOrder=self.detailsScroll,-1
 self.detailsDescription.Size=UDim2.new(1,-12,0,if mainWidth<400 then 190 else 110)
 self.detailsNote.Parent,self.detailsNote.LayoutOrder=self.detailsScroll,1000
 self.detailsNote.Size=UDim2.new(1,-12,0,72)
 self.detailsBack.Position,self.detailsBack.Size=UDim2.new(0,12,1,-60),UDim2.new(0.35,-18,0,48)
 self.detailsBuy.Position,self.detailsBuy.Size=UDim2.new(0.35,0,1,-60),UDim2.new(0.65,-12,0,48)
 self:ApplyTypography()
 self.scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
 self.scroll.CanvasSize=UDim2.new()
 self:UpdateSection()
end

function Browser:Render(_force)
 self:RenderExisting();self:ApplyPresentation();self:Resize();self:UpdateSection()
end

function Browser:Destroy()
 if not self.alive then return end
 self.alive=false
 self:CancelScroll()
 self:CancelArtworkMotion()
 for _,connection in self.connections do connection:Disconnect() end
 table.clear(self.connections)
 self.root:Destroy()
end
return Browser
