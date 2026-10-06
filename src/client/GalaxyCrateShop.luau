--!strict
-- Editable native rendering of the approved Figma Galaxy banner (520:885).
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(script.Parent.UITheme)
local Catalog=require(ReplicatedStorage.PetRoll.Shared.ShopCatalog)
local Presentation=require(ReplicatedStorage.PetRoll.Shared.GalaxyCratePresentation)
local Shop={}
Shop.__index=Shop
Shop.Height=0.405

local WHITE=Color3.new(1,1,1)
local BLACK=Color3.fromRGB(3,1,4)
local PACKS={
 {key="OuterSpaceCrate10",quantity=10,top=Color3.fromRGB(255,234,18),bottom=Color3.fromRGB(255,168,23),border=Color3.fromRGB(173,121,0),rim=Color3.fromRGB(255,246,162)},
 {key="OuterSpaceCrate3",quantity=3,top=Color3.fromRGB(156,255,19),bottom=Color3.fromRGB(21,216,11),border=Color3.fromRGB(47,116,0),rim=Color3.fromRGB(208,255,138)},
 {key="OuterSpaceCrate1",quantity=1,top=Color3.fromRGB(156,255,19),bottom=Color3.fromRGB(21,216,11),border=Color3.fromRGB(47,116,0),rim=Color3.fromRGB(208,255,138)},
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

local function portrait(parent,asset)
 -- The Figma exports retain their alpha; dark underlays outline the silhouette.
 for index,offset in {{-1,-1},{0,-1},{1,-1},{-1,0},{1,0},{-1,1},{0,1},{1,1}} do
  local outline=picture(parent,"PortraitOutline"..index,asset,3+offset[1]*2.5,offset[2]*2.5,254,235,260,326,8)
  outline.ImageColor3=BLACK
 end
 return picture(parent,"Portrait",asset,3,0,254,235,260,326,9)
end

function Shop.new(app,parent)
 local self=setmetatable({app=app,buttons={},connections={}},Shop)
 local root=layer(parent,"Galaxy",0,0,0.98,1,1,1,nil,4)
 root.LayoutOrder=0
 root:SetAttribute("OwnsPopupStyle",true)
 Theme.Aspect(root,1/Shop.Height)
 self.root=root
 local banner=layer(root,"GalaxyCrateBanner",0,0,1,0.325,1,Shop.Height,Color3.fromRGB(17,9,37),4)
 banner.ClipsDescendants=true
 rounded(banner,34/650)
 self.banner=banner
 local border=Theme.Stroke(banner,WHITE,3)
 border.StrokeSizingMode,border.Thickness=Enum.StrokeSizingMode.ScaledSize,7/650
 border.LineJoinMode=Enum.LineJoinMode.Round
 Theme.Gradient(border,Color3.fromRGB(154,251,255),Color3.fromRGB(148,64,255))
 local background=picture(banner,"Atmosphere",Presentation.Background,0,0,2000,650,2000,650,5)
 background.ScaleType=Enum.ScaleType.Crop
 rounded(background,34/650)
 local vignette=layer(banner,"VioletVignette",0,0,2000,650,2000,650,WHITE,6)
 local shading=Theme.Gradient(vignette,WHITE,WHITE)
 shading.Rotation=0
 shading.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(34,6,44)),ColorSequenceKeypoint.new(0.48,Color3.fromRGB(6,4,29)),ColorSequenceKeypoint.new(1,Color3.fromRGB(16,5,37))})
 shading.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.74),NumberSequenceKeypoint.new(0.48,0.9),NumberSequenceKeypoint.new(1,0.7)})
 rounded(vignette,34/650)
 self.crate=picture(banner,"GalaxyCrate",Presentation.CrateImage,-58,112,718,610,2000,650,7)
 local new=label(banner,"New","NEW!",32,20,260,110,2000,650,9)
 new.TextXAlignment=Enum.TextXAlignment.Left
 Theme.Gradient(new,Color3.fromRGB(204,155,255),Color3.fromRGB(61,239,255))
 local title=label(banner,"Title","Galaxy Crate!",310,20,600,110,2000,650,9)
 title.TextXAlignment=Enum.TextXAlignment.Left
 local rewards=layer(banner,"Rewards",650,139,1320,326,2000,650,nil,8)
 for index,reward in Presentation.Rewards do
  local card=layer(rewards,reward.id or reward.species,(index-1)*265,0,260,326,1320,326,nil,8)
  card:SetAttribute("Species",reward.species or reward.id)
  card:SetAttribute("Chance",reward.chance)
  portrait(card,reward.image)
  label(card,"Name",reward.name,0,235,260,33,260,326,10)
  label(card,"Chance",percentage(reward.chance),0,267,260,59,260,326,10)
 end
 local purchaseRow=layer(banner,"Purchases",650,481,1318,150,2000,650,nil,9)
 for index,pack in PACKS do
  self:CreatePurchase(purchaseRow,pack,index)
 end
 local inner=layer(banner,"InnerEdge",9,9,1982,632,2000,650,nil,11)
 rounded(inner,27/632)
 local innerBorder=Theme.Stroke(inner,Color3.fromRGB(170,223,255),1)
 innerBorder.StrokeSizingMode,innerBorder.Thickness,innerBorder.Transparency=Enum.StrokeSizingMode.ScaledSize,2/632,0.62
 local footer=layer(root,"CrateControls",0,0.34,1,0.065,1,Shop.Height,nil,7)
 self.creditLabel=label(footer,"Credits","",0,0,0.66,0.53,1,1,8)
 self.creditLabel.TextXAlignment=Enum.TextXAlignment.Left
 self.note=label(footer,"Disclosure","One chicken per crate · Chances shown above",0,0.56,0.66,0.4,1,1,8)
 self.note.Font,self.note.TextColor3=Enum.Font.SourceSans,Theme.Colors.muted
 self.note.TextXAlignment=Enum.TextXAlignment.Left
 local open=Theme.ActionButton(footer,"OpenCrate","Open 1",function()
  if not self.openButton.Active then return end
  app.audio:Play("Click")
  app.commerce:OpenCrate()
 end,Theme.Colors.green)
 open.Position,open.Size,open.ZIndex=UDim2.fromScale(0.71,0.05),UDim2.fromScale(0.29,0.85),9
 self.openButton=open
 self:Render()
 return self
end

function Shop:CreatePurchase(parent,pack,index)
 local button=Instance.new("TextButton")
 button.Name,button.Text,button.BackgroundTransparency=pack.key,"",1
 button.TextTransparency,button.AutoButtonColor,button.BorderSizePixel=1,false,0
 button.Active,button.Selectable,button.ZIndex=false,false,10
 button.Parent=parent
 button:SetAttribute("CatalogKey",pack.key)
 rect(button,(index-1)*444,0,430,150,1318,150)
 local visual=layer(button,"Visual",0,0,1,1,1,1,nil,10)
 visual.AnchorPoint,visual.Position=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5)
 local depth=layer(visual,"LowerLip",0,8,430,142,430,150,BLACK,10)
 rounded(depth,22/142)
 local face=layer(visual,"Face",4,4,422,134,430,150,WHITE,11)
 rounded(face,18/134)
 local outline=Theme.Stroke(face,pack.border,2)
 outline.StrokeSizingMode,outline.Thickness=Enum.StrokeSizingMode.ScaledSize,5/134
 outline.LineJoinMode=Enum.LineJoinMode.Round
 Theme.Gradient(face,pack.top,pack.bottom)
 local studs=Theme.Studs(face,0.12,28,0)
 studs.ZIndex=12
 studs:SetAttribute("StudScaleWidth",1200/422)
 local highlight=layer(face,"UpperRim",4,3,404,4,422,134,pack.rim,13)
 highlight.BackgroundTransparency=0.25
 label(visual,"Quantity","×"..pack.quantity,356,-19,74,49,430,150,16)
 local price=label(visual,"Price","Loading…",16,13,398,104,430,150,15)
 local currency
 if Presentation.RobuxImage then
  currency=picture(visual,"Robux",Presentation.RobuxImage,36,29,76,76,430,150,15)
 else
  currency=label(visual,"Robux",utf8.char(0xE002),36,29,76,76,430,150,15)
 end
 currency.Visible=false
 Theme.Motion:BindButton(button,visual,face)
 table.insert(self.connections,button.Activated:Connect(function()
  if not button.Active then return end
  self.app.audio:Play("Click")
  self.app.commerce:Buy(pack.key)
 end))
 self.buttons[pack.key]={button=button,price=price,currency=currency}
end

function Shop:Render()
 local commerce=self.app.commerce
 local shop=self.app.state and self.app.state.shop
 local busy=commerce.pending~=nil or commerce.cratePending~=nil or commerce.cratePresenting==true
 for key,view in self.buttons do
  local status,price=commerce:State(key)
  local quoted=status=="ready" and type(price)=="number"
  view.currency.Visible=quoted
  view.price.Text=if quoted then Theme.Money(price) else STATUS[status] or "Unavailable"
  rect(view.price,if quoted then 122 else 16,13,if quoted then 280 else 398,104,430,150)
  view.button.Text=string.format("%s · %s",Catalog.Products[key].name,if quoted then "R$ "..Theme.Money(price) else view.price.Text)
  view.button.Active=not busy and (status=="ready" or status=="error" or status=="policy" or status=="profile")
  view.button.Selectable=view.button.Active
  view.button:SetAttribute("State",status)
  view.button:SetAttribute("UnavailableReason",if view.button.Active then nil else status)
  view.price.TextColor3=if status=="restricted" or status=="offsale" then Theme.Colors.muted else WHITE
 end
 local credits=if shop and type(shop.crateCredits)=="number" then math.max(0,math.floor(shop.crateCredits)) else 0
 self.openButton.Visible=credits>0
 self.openButton.Active=credits>0 and not busy and shop~=nil and shop.productReady==true
  and shop.policyReady==true and shop.paidRandomAllowed==true and Catalog.Crate.enabled==true
 self.openButton.Selectable=self.openButton.Active
 self.openButton.Text=if commerce.cratePending then "Opening…" else "Open 1"
 self.creditLabel.Text=if credits>0 then "Galaxy Crates: "..Theme.Money(credits) else "Five cosmic chickens to collect"
 self.note.Text=if shop and shop.policyReady==true and shop.paidRandomAllowed==false then "Paid random items are unavailable for this account."
  elseif commerce.cratePending then "Waiting for your chicken…"
  else "One chicken per crate · Chances shown above"
end

function Shop:Destroy()
 for _,connection in self.connections do connection:Disconnect() end
 table.clear(self.connections)
 self.root:Destroy()
end

return Shop
