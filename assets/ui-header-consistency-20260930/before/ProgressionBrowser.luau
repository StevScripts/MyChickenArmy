--!strict
-- Figma 7:676. Presentation only; authoritative prices and purchases stay on the server.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ContentProvider=game:GetService("ContentProvider")
local Config=require(ReplicatedStorage.PetRoll.Shared.Config)
local Theme=require(script.Parent.UITheme)
local Browser={}
Browser.__index=Browser
local WHITE,INK,MUTED=Color3.fromRGB(255,254,245),Color3.fromRGB(16,23,16),Color3.fromRGB(205,214,199)
local CYAN=Theme.ReferenceColors.Upgrades
-- Original transparent Figma art; receipts in assets/ui/upgrades-figma-20260923.
local ART={Capacity="rbxassetid://116596976255471",Income="rbxassetid://74642843536793",Luck="rbxassetid://89926874802411"}
local PURPLE=ColorSequence.new(Color3.fromRGB(175,43,255),Color3.fromRGB(153,38,223))
local RED=ColorSequence.new(Color3.fromRGB(255,107,83),Color3.fromRGB(233,51,43))

local function display(parent,name,value,position,size,color)
 local text=Theme.Display(parent,name,value,24,color or WHITE)
 text.Position,text.Size=position,size
 text.TextXAlignment,text.TextWrapped,text.TextScaled=Enum.TextXAlignment.Center,true,true
 return text
end

local function surface(parent,name,position,size,body)
 local frame=Theme.Frame(parent,name,size,Color3.new(1,1,1))
 frame.Position=position
 local gradient=Theme.Gradient(frame,Color3.fromRGB(20,22,24),Color3.fromRGB(3,4,5))
 gradient.Transparency=NumberSequence.new(if body then 0.24 else 0.62,if body then 0.48 else 0.80)
 Theme.Stroke(frame,if body then INK else CYAN,2)
 return frame
end

local function studs(parent)
 return Theme.Studs(parent,0.14,28,0)
end

local function dress(button,sequence,position,size)
 button.Position,button.Size=position,size
 button.TextColor3,button.TextWrapped,button.TextScaled=WHITE,false,true
 Theme.ApplyReferenceAccent(button,sequence)
 local visual=button.Visual
 visual.UIStroke.Color,visual.UIStroke.Thickness=sequence.Keypoints[1].Value,3
 visual.LowerLip.BackgroundColor3=INK
 visual.Caption.Position,visual.Caption.Size=UDim2.fromScale(0.035,0),UDim2.fromScale(0.93,0.9)
 studs(visual.Face)
 return button
end

function Browser.new(app)
 return setmetatable({app=app,cards={},connections={},pending={},alive=true},Browser)
end

function Browser:Mount(parent)
 local root=Theme.Frame(parent,"UpgradesBrowser",UDim2.fromScale(1,1))
 root.BackgroundTransparency,root.Visible,root.ZIndex=1,false,2
 root:SetAttribute("OwnsPopupStyle",true)
 self.root,self.parent=root,parent
 -- GUI.FRAMES.UpgradesShop: native scale geometry with one wide menu aspect.
 Theme.Aspect(root,2.93)
 local header,title=Theme.Header(root,"Header","Upgrades!",CYAN)
 header.Size,header.ZIndex=UDim2.fromScale(1,0.1625),4
 self.header,self.title=header,title
 header.UIStroke.Color=INK
 studs(header)
 header.PageIcon.Visible,header.PageIcon.Image=true,Theme.Assets.Luck
 header.PageIcon.Size,header.PageIcon.Position=UDim2.fromScale(0.08,0.85),UDim2.fromScale(0.015,0.075)
 Theme.Aspect(header.PageIcon,1)
 title.Position,title.Size,title.TextColor3=UDim2.fromScale(0.1,0.16),UDim2.fromScale(0.78,0.66),WHITE
 local close=Theme.ActionButton(header,"Close","X",function() self.app.audio:Play("Click");self.app:ClosePanel() end,Theme.ActionColors.danger)
 dress(close,RED,UDim2.fromScale(0.936,0.06),UDim2.fromScale(0.058,0.86))
 Theme.Aspect(close,1.0943396091461182)
 self.closeButton=close
 self.body=surface(root,"Main",UDim2.fromScale(0,0.175),UDim2.fromScale(1,0.825),true)
 local row=Instance.new("Frame")
 row.Name,row.BackgroundTransparency,row.BorderSizePixel="UpgradeCards",1,0
 row.Position,row.Size,row.ZIndex=UDim2.fromScale(0.02,0.025),UDim2.fromScale(0.96,0.95),3
 row.Parent=self.body
 local layout=Instance.new("UIListLayout")
 layout.FillDirection,layout.HorizontalAlignment,layout.VerticalAlignment=Enum.FillDirection.Horizontal,Enum.HorizontalAlignment.Center,Enum.VerticalAlignment.Center
 layout.Padding,layout.SortOrder=UDim.new(0.04,0),Enum.SortOrder.LayoutOrder
 self.layout,self.row=layout,row
 layout.Parent=row
 local images={header.PageIcon}
 for order,definition in {{"Capacity","Army Size","Expand"},{"Income","Egg Value","Income"},{"Luck","Roll Luck","Luck"}} do
  local name,heading,action=table.unpack(definition)
  local card=surface(row,name,UDim2.new(),UDim2.fromScale(0.3066667,0.96),false)
  card.LayoutOrder=order
  Theme.Aspect(card,1.146)
  display(card,"Title",heading,UDim2.fromScale(0.035,0.025),UDim2.fromScale(0.93,0.1))
  local current=display(card,"Current","",UDim2.fromScale(0.035,0.13),UDim2.fromScale(0.93,0.07))
  current.Font=Enum.Font.SourceSansSemibold
  local art=Theme.Image(card,"Icon",ART[name],UDim2.fromScale(0.58,0.33),UDim2.fromScale(0.5,0.22))
  art.AnchorPoint=Vector2.new(0.5,0)
  Theme.Aspect(art,222/214.071426)
  table.insert(images,art)
  local nextLabel=display(card,"Next","",UDim2.fromScale(0.035,0.57),UDim2.fromScale(0.93,0.09),MUTED)
  local buy=Theme.ActionButton(card,"Buy","",function() self:Purchase(name) end,Theme.ActionColors.purchase)
  dress(buy,Theme.ReferenceGradients.Army,UDim2.fromScale(0.045,0.69),UDim2.fromScale(0.91,0.14))
  -- No skip products exist: keep the current disabled action and its explanation.
  local skip=Theme.ActionButton(card,"Skip","Skip",function() end,Theme.Arcade.purple)
  dress(skip,PURPLE,UDim2.fromScale(0.2,0.865),UDim2.fromScale(0.6,0.105))
  skip.Active,skip.Selectable=false,false
  skip:SetAttribute("UnavailableReason","Upgrade skips are not available yet.")
  local hint=display(card,"SkipStatus","Not available",UDim2.fromScale(0.2,0.835),UDim2.fromScale(0.6,0.04),MUTED)
  hint.Visible=false
  table.insert(self.connections,skip.MouseEnter:Connect(function() hint.Visible=true end))
  table.insert(self.connections,skip.MouseLeave:Connect(function() hint.Visible=false end))
  self.cards[name]={root=card,current=current,nextLabel=nextLabel,buy=buy,skip=skip,hint=hint,action=action}
 end
 local luck=self.cards.Luck
 local odds=Instance.new("TextButton")
 odds.Name,odds.Text,odds.BackgroundTransparency="ViewOdds","",1
 odds.Position,odds.Size,odds.ZIndex=luck.nextLabel.Position,luck.nextLabel.Size,7
 odds.Parent=luck.root
 table.insert(self.connections,odds.Activated:Connect(function() self.app.audio:Play("Click");self.app:OpenPage("Odds") end))
 table.insert(self.connections,odds.MouseEnter:Connect(function() luck.hover=true;self:Render() end))
 table.insert(self.connections,odds.MouseLeave:Connect(function() luck.hover=false;self:Render() end))
 Theme.ScaleText(root)
 task.spawn(function() pcall(function() ContentProvider:PreloadAsync(images) end) end)
end

function Browser:Resize()
 -- Native scale properties and aspect constraints handle every viewport.
end

function Browser:Offer(name)
 local state=self.app.state
 if not state then return nil end
 if name=="Capacity" then
  local slot=state.nextSlot
  return {current=tostring(state.capacity).." fighters",benefit=if slot then state.capacity.." → "..(slot.displayCapacity or slot.capacity).." fighters" else "Largest squad",
   price=slot and slot.price,blocked=slot and not slot.unlocked,reason=slot and slot.requirement}
 end
 local income=name=="Income"
 local level=if income then state.incomeLevel or 0 else state.luck or 0
 local upgrade=if income then state.incomeUpgrade else state.luckUpgrade
 local prices=if income then Config.IncomePrices else Config.LuckPrices
 return {current="Level "..level,benefit=if income then "+"..math.floor(Config.IncomeMultiplierPerLevel*100).."% egg value" else "Better top-recruit odds",
  price=if upgrade then upgrade.price else prices[level+1],blocked=upgrade and not upgrade.unlocked,reason=upgrade and upgrade.requirement}
end

function Browser:Render()
 if not self.root or not self.app.state then return end
 self:Resize()
 for name,view in self.cards do
  local offer=self:Offer(name)
  if not offer then continue end
  local waiting=self.pending[view.action]~=nil
  local affordable=offer.price~=nil and self.app.state.coins>=offer.price
  local enabled=affordable and not offer.blocked and not waiting
  view.current.Text=offer.current
  view.nextLabel.Text=if view.hover then "View roll odds →" elseif offer.blocked then offer.reason or "Conquer more camps" else offer.benefit
  view.nextLabel.TextWrapped=offer.blocked==true
  view.nextLabel.TextSize=if offer.blocked then 20 else 23
  view.nextLabel.TextColor3=if view.hover then CYAN else MUTED
  view.buy.Text=if waiting then "…" elseif offer.blocked then "Locked" elseif offer.price then "$"..Theme.Money(offer.price) else "MAX"
  view.buy.Active,view.buy.Selectable=enabled,enabled
  view.buy:SetAttribute("Price",offer.price)
  view.buy.BackgroundColor3=if enabled then Theme.ActionColors.purchase else Theme.ActionColors.disabled
  if enabled then Theme.ApplyReferenceAccent(view.buy,Theme.ReferenceGradients.Army) end
  view.buy.Visual.UIStroke.Color=if enabled then Theme.ReferenceGradients.Army.Keypoints[1].Value else Theme.ActionColors.disabled
  view.buy.Visual.LowerLip.BackgroundColor3=INK
  view.hint.Visible=view.hint.Visible and self.root.Visible
 end
end

function Browser:Purchase(name)
 local view,offer=self.cards[name],self:Offer(name)
 if not view or not offer or not self.root.Visible or not self.app.panel.Visible
  or self.pending[view.action] or offer.blocked or not offer.price or self.app.state.coins<offer.price then return end
 self.app.audio:Play("Click")
 local id=self.app:Request(view.action)
 self.pending[view.action]=id
 self:Render()
 task.delay(8,function()
  if self.alive and self.pending[view.action]==id then self.pending[view.action]=nil;self:Render() end
 end)
end

function Browser:Receive(result)
 if result and self.pending[result.action] then self.pending[result.action]=nil end
end

function Browser:Destroy()
 self.alive=false
 for _,connection in self.connections do connection:Disconnect() end
 if self.root then self.root:Destroy() end
end

return Browser
