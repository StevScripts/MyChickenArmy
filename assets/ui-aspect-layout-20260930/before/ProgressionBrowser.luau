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

local function display(parent,name,value,size,x,y,width,height,color)
 local text=Theme.Display(parent,name,value,size,color or WHITE)
 text.Position,text.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(width,height)
 text.TextXAlignment,text.TextWrapped=Enum.TextXAlignment.Center,false
 return text
end

local function surface(parent,name,x,y,width,height,body)
 local frame=Theme.Frame(parent,name,UDim2.fromOffset(width,height),Color3.new(1,1,1))
 frame.Position=UDim2.fromOffset(x,y)
 local gradient=Theme.Gradient(frame,Color3.fromRGB(20,22,24),Color3.fromRGB(3,4,5))
 gradient.Transparency=NumberSequence.new(if body then 0.24 else 0.62,if body then 0.48 else 0.80)
 Theme.Stroke(frame,if body then INK else CYAN,2)
 return frame
end

local function studs(parent)
 return Theme.Studs(parent,0.14,28,0)
end

local function dress(button,sequence,width,height,fontSize)
 button.Size,button.TextSize,button.TextWrapped=UDim2.fromOffset(width,height),fontSize,false
 button.TextColor3=WHITE
 Theme.ApplyReferenceAccent(button,sequence)
 local visual=button.Visual
 visual.UIStroke.Color,visual.UIStroke.Thickness=sequence.Keypoints[1].Value,3
 visual.LowerLip.BackgroundColor3=INK
 visual.Caption.Position,visual.Caption.Size=UDim2.fromOffset(10,0),UDim2.new(1,-20,1,-5)
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
 self.root=root
 self.header,self.parent=nil,parent
 local header,title=Theme.Header(root,"Header","Upgrades!",CYAN)
 header.Size,header.ZIndex=UDim2.new(1,0,0,64),4
 self.header,self.title=header,title
 header.UIStroke.Color=INK
 studs(header)
 header.PageIcon.Visible,header.PageIcon.Image=true,Theme.Assets.Luck
 header.PageIcon.Size,header.PageIcon.Position=UDim2.fromOffset(78,78),UDim2.fromOffset(12,1)
 title.Position,title.Size,title.TextColor3=UDim2.fromOffset(104,0),UDim2.fromOffset(910,84),WHITE
 local close=Theme.ActionButton(header,"Close","X",function() self.app.audio:Play("Click");self.app:ClosePanel() end,Theme.ActionColors.danger)
 dress(close,RED,84,84,60);close.Position=UDim2.fromOffset(1036,0)
 self.closeButton=close
 self.body=surface(root,"Main",0,72,1120,564,true)
 local row=Instance.new("ScrollingFrame")
 row.Name,row.BackgroundTransparency,row.BorderSizePixel="UpgradeCards",1,0
 row.AutomaticCanvasSize,row.CanvasSize=Enum.AutomaticSize.Y,UDim2.new()
 row.ScrollBarThickness,row.ScrollingDirection=6,Enum.ScrollingDirection.Y
 row.VerticalScrollBarInset=Enum.ScrollBarInset.Always
 row.Parent=self.body
 row.Position,row.BackgroundTransparency,row.ZIndex=UDim2.fromOffset(20,40),1,3
 local layout=Instance.new("UIGridLayout")
 layout.CellPadding,layout.SortOrder=UDim2.fromOffset(12,12),Enum.SortOrder.LayoutOrder
 self.layout=layout
 layout.Parent=row;self.row=row
 local images={header.PageIcon}
 for order,definition in {{"Capacity","Army Size","Expand"},{"Income","Egg Value","Income"},{"Luck","Roll Luck","Luck"}} do
  local name,heading,action=table.unpack(definition)
  local card=surface(row,name,0,0,352,532,false);card.LayoutOrder=order
  display(card,"Title",heading,50,12,12,328,44)
  local current=display(card,"Current","",27,12,68,328,40)
  current.Font=Enum.Font.SourceSansSemibold
  local art=Theme.Image(card,"Icon",ART[name],UDim2.fromOffset(222,214.071426),UDim2.fromOffset(65,118))
  art.ScaleType=Enum.ScaleType.Fit;table.insert(images,art)
  local nextLabel=display(card,"Next","",23,12,340,328,40,MUTED)
  local buy=Theme.ActionButton(card,"Buy","",function() self:Purchase(name) end,Theme.ActionColors.purchase)
  dress(buy,Theme.ReferenceGradients.Army,320,64,32);buy.Position=UDim2.fromOffset(16,388)
  -- No skip products exist: never substitute a cash pack or grant a paid upgrade locally.
  local skip=Theme.ActionButton(card,"Skip","Skip",function() end,Theme.Arcade.purple)
  dress(skip,PURPLE,200,48,26);skip.Position=UDim2.fromOffset(76,470)
  skip.Active,skip.Selectable=false,false
  skip:SetAttribute("UnavailableReason","Upgrade skips are not available yet.")
  local hint=display(card,"SkipStatus","Not available",16,76,449,200,20,MUTED)
  hint.Visible=false
  table.insert(self.connections,skip.MouseEnter:Connect(function() hint.Visible=true end))
  table.insert(self.connections,skip.MouseLeave:Connect(function() hint.Visible=false end))
  self.cards[name]={root=card,current=current,nextLabel=nextLabel,buy=buy,skip=skip,hint=hint,action=action}
 end
 -- Preserve access to existing odds without adding a fourth card or footer.
 local luck=self.cards.Luck
 local odds=Instance.new("TextButton")
 odds.Name,odds.Text,odds.BackgroundTransparency="ViewOdds","",1
 odds.Position,odds.Size,odds.ZIndex=UDim2.fromOffset(12,340),UDim2.fromOffset(328,40),7
 odds.Parent=luck.root
 table.insert(self.connections,odds.Activated:Connect(function() self.app.audio:Play("Click");self.app:OpenPage("Odds") end))
 table.insert(self.connections,odds.MouseEnter:Connect(function() luck.hover=true;self:Render() end))
 table.insert(self.connections,odds.MouseLeave:Connect(function() luck.hover=false;self:Render() end))
 task.spawn(function() pcall(function() ContentProvider:PreloadAsync(images) end) end)
end

function Browser:Resize()
 local width=self.app.panelWidth or 1120
 local short=(self.app.panelHeight or 660)<500
 local cardHeight=if short then 260 else 440
 self.root.Size=UDim2.fromScale(1,1)
 self.header.PageIcon.Size,self.header.PageIcon.Position=UDim2.fromOffset(52,52),UDim2.fromOffset(6,6)
 self.title.Position,self.title.Size,self.title.TextSize=UDim2.fromOffset(68,0),UDim2.new(1,-132,1,0),36
 self.closeButton.Size,self.closeButton.Position,self.closeButton.TextSize=UDim2.fromOffset(52,52),UDim2.new(1,-58,0,6),32
 self.body.Position,self.body.Size=UDim2.fromOffset(0,72),UDim2.new(1,0,1,-72)
 self.row.Position,self.row.Size=UDim2.fromOffset(12,12),UDim2.new(1,-24,1,-24)
 local columns=if width>=920 then 3 elseif width>=620 then 2 else 1
 local cardWidth=(width-36-(columns-1)*12)/columns
 self.layout.CellSize,self.layout.FillDirectionMaxCells=UDim2.new(1/columns,-math.ceil((12+12*(columns-1))/columns),0,cardHeight),columns
 for _,view in self.cards do
  local card=view.root
  card.Title.Position,card.Title.Size,card.Title.TextSize=UDim2.fromOffset(8,8),UDim2.new(1,-16,0,44),34
  view.current.Position,view.current.Size,view.current.TextSize=UDim2.fromOffset(8,54),UDim2.new(1,-16,0,32),24
  card.Icon.AnchorPoint=Vector2.new(0.5,0)
  card.Icon.Position,card.Icon.Size=UDim2.fromScale(0.5,0.21),UDim2.fromOffset(math.min(190,cardWidth-32),168)
  view.nextLabel.Position,view.nextLabel.Size=UDim2.fromOffset(8,270),UDim2.new(1,-16,0,48)
  view.buy.Position,view.buy.Size=UDim2.fromOffset(12,324),UDim2.new(1,-24,0,56)
  view.buy.TextSize=28
  view.skip.Position,view.skip.Size=UDim2.new(0.15,0,0,388),UDim2.new(0.7,0,0,48)
  view.hint.Position,view.hint.Size=UDim2.fromOffset(12,302),UDim2.new(1,-24,0,22)
  view.skip.Visible=not short
  if short then
   card.Title.Position,card.Title.Size,card.Title.TextSize=UDim2.fromOffset(8,4),UDim2.new(1,-16,0,32),28
   view.current.Position,view.current.Size,view.current.TextSize=UDim2.fromOffset(8,38),UDim2.new(1,-16,0,26),22
   card.Icon.Position,card.Icon.Size=UDim2.new(0.5,0,0,65),UDim2.fromOffset(90,80)
   view.nextLabel.Position,view.nextLabel.Size=UDim2.fromOffset(8,145),UDim2.new(1,-16,0,48)
   view.buy.Position,view.buy.Size=UDim2.fromOffset(12,200),UDim2.new(1,-24,0,52)
  end
  local odds=card:FindFirstChild("ViewOdds")
  if odds then odds.Position,odds.Size=view.nextLabel.Position,view.nextLabel.Size end
 end
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
