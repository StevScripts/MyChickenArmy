--!strict
-- The Galaxy Crate as the Shop rail's pack card (October 21 reference parity, P8:
-- docs/team/REFERENCE_PARITY_20261021.md §2.7, the reference's "Meme Fruit Pack"):
-- title plate, crate art, the five rewards as black-stroke portraits with their
-- income above and odds below, and the x1 / x3 / x10 Robux pills ("Buy 1/3/10").
-- Native checkout and the server's crate rules are unchanged.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(script.Parent.UITheme)
local Art=require(script.Parent.ShopPreviewArt)
local Catalog=require(ReplicatedStorage.PetRoll.Shared.ShopCatalog)
local PetCatalog=require(ReplicatedStorage.PetRoll.Shared.PetCatalog)
local Presentation=require(ReplicatedStorage.PetRoll.Shared.GalaxyCratePresentation)
local Shop={}
Shop.__index=Shop
-- The card in a virtual 480 x 335 space; 335 is the rail's card height, so the card
-- is Shop.Width card-heights wide (the reference's pack column is 410 x 335; ours
-- holds five rewards and no second "Advanced Pack" card, so it is one tall card).
local W,H=480,335
Shop.Width=W/H
-- Card colours: the reference pack's blue-violet under the galaxy art.
local TOP,BOTTOM=Color3.fromRGB(120,82,255),Color3.fromRGB(38,20,112)

local WHITE=Color3.new(1,1,1)
local BLACK=Color3.fromRGB(3,1,4)
-- Every Robux buy button in the shop is this crate pill (owner, October 21).
local GREEN={top=Color3.fromRGB(156,255,19),bottom=Color3.fromRGB(21,216,11),border=Color3.fromRGB(47,116,0),rim=Color3.fromRGB(208,255,138)}
local GOLD={top=Color3.fromRGB(255,234,18),bottom=Color3.fromRGB(255,168,23),border=Color3.fromRGB(173,121,0),rim=Color3.fromRGB(255,246,162)}
Shop.Palettes={green=GREEN,gold=GOLD}
-- The pill's designed proportion (virtual 430 x 145 face).
Shop.PriceAspect=430/145
-- As in the reference, all three pack pills are green; the biggest says so in cyan.
local PACKS={
 {key="OuterSpaceCrate1",quantity=1},
 {key="OuterSpaceCrate3",quantity=3},
 {key="OuterSpaceCrate10",quantity=10,captionColor=Color3.fromRGB(110,226,255)},
}
local STATUS={pending="Check Roblox",preparing="Checking…",unconfigured="Coming soon",loading="Loading…",
 offsale="Off sale",error="Retry price",checking="Checking…",ownership="Retry check",profile="Check save",
 policy="Check eligibility",restricted="Not available"}

local function rect(item,x,y,width,height,parentWidth,parentHeight)
 item.Position=UDim2.fromScale(x/parentWidth,y/parentHeight)
 item.Size=UDim2.fromScale(width/parentWidth,height/parentHeight)
end

local function layer(parent,name,x,y,width,height,parentWidth,parentHeight,color,z)
 local item=Theme.Frame(parent,name,UDim2.fromScale(1,1),color)
 rect(item,x,y,width,height,parentWidth,parentHeight)
 item.BackgroundTransparency=if color then 0 else 1
 item.ZIndex=z or parent.ZIndex+1
 return item
end

local function rounded(item,radius)
 Theme.Round(item).CornerRadius=UDim.new(radius,0)
end

-- White Montserrat Bold with the black stroke at about 8% of the glyph height
-- (contract 2.1). Local until P2's shared label-stroke helper lands in UITheme.
local function label(parent,name,value,x,y,width,height,parentWidth,parentHeight,z)
 local item=Theme.Label(parent,name,value,24,WHITE)
 item.Font=Theme.Font
 item.TextColor3,item.TextScaled,item.TextWrapped=WHITE,true,false
 item.TextXAlignment=Enum.TextXAlignment.Center
 item.TextOutline.Thickness=0.08
 item.ZIndex=z or parent.ZIndex+1
 rect(item,x,y,width,height,parentWidth,parentHeight)
 return item
end

local function picture(parent,name,asset,x,y,width,height,parentWidth,parentHeight,z)
 local item=Theme.Image(parent,name,asset or "",UDim2.fromScale(1,1))
 rect(item,x,y,width,height,parentWidth,parentHeight)
 item.ZIndex=z or parent.ZIndex+1
 return item
end

local function percentage(value)
 return string.format("%g%%",value*100)
end

-- Dark translucent title strip with the card's name, as on every reference card.
-- `inset` is the text's side margin as a share of the plate (default 0.04).
function Shop.TitlePlate(parent,text,x,y,width,height,parentWidth,parentHeight,z,inset)
 local plate=layer(parent,"TitlePlate",x,y,width,height,parentWidth,parentHeight,Color3.new(0,0,0),z)
 plate.BackgroundTransparency=0.5
 rounded(plate,0.22)
 local edge=Theme.Stroke(plate,Color3.new(0,0,0),2)
 edge.Transparency,edge.LineJoinMode=0.35,Enum.LineJoinMode.Round
 local side=inset or 0.04
 local title=label(plate,"Title",text,side,0.08,1-side*2,0.84,1,1,z+1)
 return plate,title
end

function Shop.new(app,parent)
 local self=setmetatable({app=app,buttons={},connections={},tiles={}},Shop)
 local root=Theme.Container(parent,"Galaxy")
 root.ZIndex=2
 root:SetAttribute("OwnsPopupStyle",true)
 self.root=root
 local visual,face=Art.CardFace(root,TOP,BOTTOM,Art.CardRadius)
 self.visual,self.face=visual,face
 -- The galaxy sky behind everything, softened so the portraits and text read.
 local sky=picture(face,"Atmosphere",Presentation.Background,0,0,W,H,W,H,2)
 sky.ScaleType,sky.ImageTransparency=Enum.ScaleType.Crop,0.45
 rounded(sky,Art.CardRadius)
 local _,title=Shop.TitlePlate(visual,"Galaxy Crate!",12,12,272,44,W,H,8)
 self.title=title
 self.creditLabel=label(visual,"Credits","",16,60,268,22,W,H,9)
 self.creditLabel.TextXAlignment=Enum.TextXAlignment.Left
 self.crate=picture(visual,"GalaxyCrate",Presentation.CrateImage,296,2,176,120,W,H,7)
 -- Five rewards: income above each portrait, odds in its lower corner (the reference
 -- shows "$37.5K/s" above and "1%" in the tile; ours is the coin and Coins a second).
 local tileWidth,tileGap=84,10
 for index,reward in Presentation.Rewards do
  local x=10+(index-1)*(tileWidth+tileGap)
  local species=reward.species or reward.id
  local income=layer(visual,"Income"..index,x,126,tileWidth,20,W,H,nil,9)
  local coin=Theme.CoinIcon(income,"Coin",UDim2.fromScale(20/tileWidth,1),UDim2.fromScale(4/tileWidth,0))
  coin.ZIndex=10
  local definition=PetCatalog[species]
  local amount=label(income,"Amount",Theme.Number(definition and definition.income or 0).."/s",26,0,tileWidth-28,20,tileWidth,20,10)
  amount.TextColor3=Theme.Colors.coins
  local tile=layer(visual,"Reward"..index,x,148,tileWidth,tileWidth,W,H,Color3.new(1,1,1),8)
  tile.ClipsDescendants=true
  tile:SetAttribute("Species",species)
  tile:SetAttribute("Chance",reward.chance)
  rounded(tile,0.12)
  local tint=(reward :: any).color or WHITE
  Theme.Gradient(tile,tint:Lerp(BLACK,0.35),tint:Lerp(BLACK,0.8)).Transparency=NumberSequence.new(0.15)
  Theme.Stroke(tile,BLACK,2).LineJoinMode=Enum.LineJoinMode.Round
  -- The portraits carry transparent padding; overscan so the chicken reads big.
  local holder=layer(tile,"Portrait",-10,-4,104,104,tileWidth,tileWidth,nil,9)
  Art.OutlinedPortrait(holder,reward.image,0.025,9)
  label(tile,"Chance",percentage(reward.chance),24,54,56,28,tileWidth,tileWidth,12).TextXAlignment=Enum.TextXAlignment.Right
  self.tiles[index]=tile
 end
 local purchaseRow=layer(visual,"Purchases",12,240,456,50,W,H,nil,10)
 for index,pack in PACKS do
  self:CreatePurchase(purchaseRow,pack,index)
 end
 self.note=label(visual,"Disclosure","One chicken per crate · Chances shown above",14,304,452,24,W,H,9)
 self.note.TextColor3=Color3.fromRGB(224,230,233)
 self.note.TextXAlignment=Enum.TextXAlignment.Left
 -- Bought crates waiting (or the Studio test roll) open from a pill on the crate art.
 local open=Theme.ActionButton(visual,"OpenCrate","Open 1",function()
  if not self.openButton.Active then return end
  app.audio:Play("Click")
  if app.state and app.state.shop and app.state.shop.testAllowed==true then
   app.commerce:TestCrate()
  else app.commerce:OpenCrate() end
 end,Theme.Colors.green)
 rect(open,312,84,144,40,W,H)
 open.ZIndex=14
 -- Phone hit area: 48 px tall, all of it upward over the crate art (no button there).
 Theme.PadHit(open,1,1.95,0.5,1)
 open.Visible=false
 self.openButton=open
 self:Render()
 return self
end

-- The crate buy pill in a virtual 430x150 space: dark lower lip, gradient face,
-- studs, a light upper rim, and a Robux icon beside the price. The caller places it.
function Shop.PriceButton(parent,name,palette,quantity)
 local button=Instance.new("TextButton")
 button.Name,button.Text,button.BackgroundTransparency=name,"",1
 button.TextTransparency,button.AutoButtonColor,button.BorderSizePixel,button.Font=1,false,0,Theme.Font
 button.Active,button.Selectable,button.ZIndex=false,false,10
 button.Parent=parent
 local visual=layer(button,"Visual",0,0,1,1,1,1,nil,10)
 visual.AnchorPoint,visual.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
 local depth=layer(visual,"LowerLip",0,8,430,142,430,150,BLACK,10)
 rounded(depth,22/142)
 local face=layer(visual,"Face",4,4,422,134,430,150,WHITE,11)
 rounded(face,18/134)
 local outline=Theme.Stroke(face,palette.border,2)
 outline.StrokeSizingMode,outline.Thickness=Enum.StrokeSizingMode.ScaledSize,5/134
 outline.LineJoinMode=Enum.LineJoinMode.Round
 local gradient=Theme.Gradient(face,palette.top,palette.bottom)
 local studs=Theme.Studs(face,0.12,28,0)
 studs.ZIndex=12
 studs:SetAttribute("StudScaleWidth",1200/422)
 local highlight=layer(face,"UpperRim",4,3,404,4,422,134,palette.rim,13)
 highlight.BackgroundTransparency=0.25
 if quantity then label(visual,"Quantity","×"..quantity,356,-19,74,49,430,150,16) end
 local price=label(visual,"Price","Loading…",16,13,398,104,430,150,15)
 local currency
 if Presentation.RobuxImage then
  currency=picture(visual,"Robux",Presentation.RobuxImage,36,29,76,76,430,150,15)
 else
  currency=label(visual,"Robux",utf8.char(0xE002),36,29,76,76,430,150,15)
 end
 currency.Visible=false
 Theme.Motion:BindButton(button,visual,face)
 return {button=button,visual=visual,face=face,gradient=gradient,outline=outline,rim=highlight,price=price,currency=currency}
end

-- A quoted price shows the Robux icon and number; any other state fills the pill.
function Shop.ShowPrice(view,value,quoted,muted)
 view.currency.Visible=quoted
 view.price.Text=value
 rect(view.price,if quoted then 122 else 16,13,if quoted then 280 else 398,104,430,150)
 view.price.TextColor3=if muted then Theme.Colors.muted else WHITE
end

function Shop.SetPalette(view,palette)
 view.gradient.Color=ColorSequence.new(palette.top,palette.bottom)
 view.outline.Color,view.rim.BackgroundColor3=palette.border,palette.rim
end

function Shop:CreatePurchase(parent,pack,index)
 local view=Shop.PriceButton(parent,pack.key,GREEN)
 local button=view.button
 button:SetAttribute("CatalogKey",pack.key)
 rect(button,(index-1)*156,0,144,50,456,50)
 -- "Buy 1" straddles the pill's lower edge, as in the reference.
 local caption=label(view.visual,"Caption","Buy "..pack.quantity,60,112,310,64,430,150,16)
 if pack.captionColor then caption.TextColor3=pack.captionColor end
 view.caption=caption
 -- Phone hit area: 48 px tall, the extra almost all upward over the portraits.
 Theme.PadHit(button,1,1.56,0.5,0.9)
 table.insert(self.connections,button.Activated:Connect(function()
  if not button.Active then return end
  self.app.audio:Play("Click")
  self.app.commerce:Buy(pack.key)
 end))
 self.buttons[pack.key]=view
end

function Shop:Render()
 local commerce=self.app.commerce
 local shop=self.app.state and self.app.state.shop
 local testing=shop and shop.testAllowed==true
 local busy=commerce.pending~=nil or commerce.cratePending~=nil or commerce.cratePresenting==true
 local purchaseBusy=busy or commerce.autoCrate~=nil
 for key,view in self.buttons do
  local status,price=commerce:State(key)
  local quoted=(status=="ready" or status=="studio") and type(price)=="number"
  Shop.ShowPrice(view,if quoted then Theme.Money(price) else STATUS[status] or "Unavailable",quoted,status=="restricted" or status=="offsale")
  view.button.Text=string.format("%s · %s",Catalog.Products[key].name,if quoted then "R$ "..Theme.Money(price) else view.price.Text)
  view.button.Active=not purchaseBusy and (status=="ready" or status=="error" or status=="policy" or status=="profile")
  view.button.Selectable=view.button.Active
  view.button:SetAttribute("State",status)
  view.button:SetAttribute("UnavailableReason",if view.button.Active then nil else status)
 end
 local credits=if shop and type(shop.crateCredits)=="number" then math.max(0,math.floor(shop.crateCredits)) else 0
 local showOpen=testing or credits>0
 -- Grow in only when crates first become openable, not on every refresh.
 if showOpen and not self.openButton.Visible then Theme.Motion:PopScale(self.openButton.Visual,0.6,0.26) end
 self.openButton.Visible=showOpen
 if self.lastCredits and credits>self.lastCredits then Theme.Motion:Punch(self.creditLabel,1.14,0.3) end
 self.lastCredits=credits
 self.openButton.Active=(testing or credits>0) and not busy and shop~=nil and (testing or shop.productReady==true)
  and shop.policyReady==true and shop.paidRandomAllowed==true and Catalog.Crate.enabled==true
 self.openButton.Selectable=self.openButton.Active
 -- A bought crate waiting to be opened breathes (Render only runs while the Shop
 -- shows); Settle stops it when none is left or the Shop closes.
 if credits>0 and self.openButton.Active then Theme.Motion:Breathe(self.openButton.Visual,1.05,0.7)
 else Theme.Motion:StopBreathe(self.openButton.Visual) end
 self.openButton.Text=if commerce.cratePending then "Opening…" elseif testing then "Test roll" else "Open 1"
 self.creditLabel.Text=if testing then "Studio test roll" elseif credits>0 then "Galaxy Crates: "..Theme.Money(credits) else "Five cosmic chickens!"
 self.note.Text=if shop and shop.policyReady==true and shop.paidRandomAllowed==false then "Paid random items are unavailable for this account."
  elseif commerce.cratePending then "Waiting for your chicken…"
  elseif testing then "No Robux charged · Rewards reset when you stop"
  else "One chicken per crate · Chances shown above"
end

-- Stops the open button's attention loop (the Shop is closing).
function Shop:Settle()
 Theme.Motion:StopBreathe(self.openButton.Visual)
end

function Shop:Destroy()
 self:Settle()
 for _,connection in self.connections do connection:Disconnect() end
 table.clear(self.connections)
 self.root:Destroy()
end

return Shop
