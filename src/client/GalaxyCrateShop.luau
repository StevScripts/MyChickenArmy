--!strict
-- Editable native rendering of the approved Figma Galaxy banner (520:885).
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(script.Parent.UITheme)
local Catalog=require(ReplicatedStorage.PetRoll.Shared.ShopCatalog)
local Presentation=require(ReplicatedStorage.PetRoll.Shared.GalaxyCratePresentation)
local Shop={}
Shop.__index=Shop
-- October 15 (owner): taller banner so the reward chickens and names read larger.
Shop.Height=0.44
local BANNER=0.36 -- Banner height as a fraction of width (virtual 2000x720).

local WHITE=Color3.new(1,1,1)
local BLACK=Color3.fromRGB(3,1,4)
-- Every Robux buy button in the shop is this crate pill (owner, October 21).
local GREEN={top=Color3.fromRGB(156,255,19),bottom=Color3.fromRGB(21,216,11),border=Color3.fromRGB(47,116,0),rim=Color3.fromRGB(208,255,138)}
local GOLD={top=Color3.fromRGB(255,234,18),bottom=Color3.fromRGB(255,168,23),border=Color3.fromRGB(173,121,0),rim=Color3.fromRGB(255,246,162)}
Shop.Palettes={green=GREEN,gold=GOLD}
-- The pill's rendered proportion inside the banner's purchase row.
Shop.PriceAspect=430/145
local PACKS={
 {key="OuterSpaceCrate1",quantity=1,palette=GREEN},
 {key="OuterSpaceCrate3",quantity=3,palette=GREEN},
 {key="OuterSpaceCrate10",quantity=10,palette=GOLD},
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

local function label(parent,name,value,x,y,width,height,parentWidth,parentHeight,z)
 local item=Theme.Label(parent,name,value,24,WHITE)
 item.Font=Enum.Font.SourceSansBold
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

-- Reward card in a virtual 268x430 space: portrait, name, chance.
local CARD_W,CARD_H,PORTRAIT_H=268,430,300
local function portrait(parent,asset)
 -- The Figma exports retain their alpha; dark underlays outline the silhouette.
 for index,offset in {{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}} do
  local outline=picture(parent,"PortraitOutline"..index,asset,-45+offset[1]*3,-40+offset[2]*3,CARD_W+90,PORTRAIT_H+50,CARD_W,CARD_H,8)
  outline.ImageColor3=BLACK
 end
 -- The exports carry transparent padding; overscan so the chicken itself reads big.
 return picture(parent,"Portrait",asset,-45,-40,CARD_W+90,PORTRAIT_H+50,CARD_W,CARD_H,9)
end

function Shop.new(app,parent)
 local self=setmetatable({app=app,buttons={},connections={}},Shop)
 local root=layer(parent,"Galaxy",0,0,0.98,1,1,1,nil,4)
 root.LayoutOrder=0
 root:SetAttribute("OwnsPopupStyle",true)
 Theme.Aspect(root,1/Shop.Height)
 self.root=root
 local banner=layer(root,"GalaxyCrateBanner",0,0,1,BANNER,1,Shop.Height,Color3.fromRGB(17,9,37),4)
 banner.ClipsDescendants=true
 rounded(banner,34/720)
 self.banner=banner
 local border=Theme.Stroke(banner,WHITE,3)
 border.StrokeSizingMode,border.Thickness=Enum.StrokeSizingMode.ScaledSize,7/720
 border.LineJoinMode=Enum.LineJoinMode.Round
 Theme.Gradient(border,Color3.fromRGB(154,251,255),Color3.fromRGB(148,64,255))
 local background=picture(banner,"Atmosphere",Presentation.Background,0,0,2000,720,2000,720,5)
 background.ScaleType=Enum.ScaleType.Crop
 rounded(background,34/720)
 local vignette=layer(banner,"VioletVignette",0,0,2000,720,2000,720,WHITE,6)
 local shading=Theme.Gradient(vignette,WHITE,WHITE)
 shading.Rotation=0
 shading.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(34,6,44)),ColorSequenceKeypoint.new(0.48,Color3.fromRGB(6,4,29)),ColorSequenceKeypoint.new(1,Color3.fromRGB(16,5,37))})
 shading.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.74),NumberSequenceKeypoint.new(0.48,0.9),NumberSequenceKeypoint.new(1,0.7)})
 rounded(vignette,34/720)
 self.crate=picture(banner,"GalaxyCrate",Presentation.CrateImage,-58,170,718,610,2000,720,7)
 local new=label(banner,"New","NEW!",32,20,260,110,2000,720,9)
 new.TextXAlignment=Enum.TextXAlignment.Left
 Theme.Gradient(new,Color3.fromRGB(204,155,255),Color3.fromRGB(61,239,255))
 local title=label(banner,"Title","Galaxy Crate!",310,20,600,110,2000,720,9)
 title.TextXAlignment=Enum.TextXAlignment.Left
 local rewards=layer(banner,"Rewards",640,118,1340,CARD_H,2000,720,nil,8)
 for index,reward in Presentation.Rewards do
  local card=layer(rewards,reward.id or reward.species,(index-1)*CARD_W,0,CARD_W,CARD_H,1340,CARD_H,nil,8)
  card:SetAttribute("Species",reward.species or reward.id)
  card:SetAttribute("Chance",reward.chance)
  portrait(card,reward.image)
  label(card,"Name",reward.name,0,PORTRAIT_H,CARD_W,52,CARD_W,CARD_H,10)
  label(card,"Chance",percentage(reward.chance),0,PORTRAIT_H+50,CARD_W,CARD_H-PORTRAIT_H-50,CARD_W,CARD_H,10)
 end
 local purchaseRow=layer(banner,"Purchases",650,560,1318,145,2000,720,nil,9)
 for index,pack in PACKS do
  self:CreatePurchase(purchaseRow,pack,index)
 end
 local inner=layer(banner,"InnerEdge",9,9,1982,702,2000,720,nil,11)
 rounded(inner,27/702)
 local innerBorder=Theme.Stroke(inner,Color3.fromRGB(170,223,255),1)
 innerBorder.StrokeSizingMode,innerBorder.Thickness,innerBorder.Transparency=Enum.StrokeSizingMode.ScaledSize,2/702,0.62
 local footer=layer(root,"CrateControls",0,BANNER+0.015,1,0.065,1,Shop.Height,nil,7)
 self.creditLabel=label(footer,"Credits","",0,0,0.66,0.53,1,1,8)
 self.creditLabel.TextXAlignment=Enum.TextXAlignment.Left
 self.note=label(footer,"Disclosure","One chicken per crate · Chances shown above",0,0.56,0.66,0.4,1,1,8)
 self.note.TextColor3=Theme.Colors.muted
 self.note.TextXAlignment=Enum.TextXAlignment.Left
 local open=Theme.ActionButton(footer,"OpenCrate","Open 1",function()
  if not self.openButton.Active then return end
  app.audio:Play("Click")
  if app.state and app.state.shop and app.state.shop.testAllowed==true then
   app.commerce:TestCrate()
  else app.commerce:OpenCrate() end
 end,Theme.Colors.green)
 open.Position,open.Size,open.ZIndex=UDim2.fromScale(0.71,0.05),UDim2.fromScale(0.29,0.85),9
 -- Phone hit area: 1.6x tall, mostly downward (the crate's price pills sit just above).
 Theme.PadHit(open,1,1.6,0.5,0.25)
 self.openButton=open
 self:Render()
 return self
end

-- The crate buy pill in a virtual 430x150 space: dark lower lip, gradient face,
-- studs, a light upper rim, and a Robux icon beside the price. The caller places it.
function Shop.PriceButton(parent,name,palette,quantity)
 local button=Instance.new("TextButton")
 button.Name,button.Text,button.BackgroundTransparency=name,"",1
 button.TextTransparency,button.AutoButtonColor,button.BorderSizePixel=1,false,0
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
 local view=Shop.PriceButton(parent,pack.key,pack.palette,pack.quantity)
 local button=view.button
 button:SetAttribute("CatalogKey",pack.key)
 rect(button,(index-1)*444,0,430,150,1318,150)
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
 self.creditLabel.Text=if testing then "Studio test roll" elseif credits>0 then "Galaxy Crates: "..Theme.Money(credits) else "Five cosmic chickens to collect"
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
