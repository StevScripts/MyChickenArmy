--!strict
-- Approved purple Figma 408:818. Selection previews one exact server-issued triple.
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Theme=require(script.Parent.UITheme)
local Presentation=require(script.Parent.MergePresentation)
local Browser={}
Browser.__index=Browser
local PURPLE=Color3.fromRGB(185,63,241)
local INK=Color3.fromRGB(13,9,19)
local WHITE=Color3.fromRGB(255,255,255)
local MUTED=Color3.fromRGB(185,182,199)
local ACCENT=ColorSequence.new(Color3.fromRGB(177,52,246),Color3.fromRGB(112,23,222))
local function frame(parent,name,size,position,color)
 local item=Theme.Frame(parent,name,size,color)
 item.Position,item.BackgroundTransparency,item.ZIndex=position or UDim2.new(),if color then 0 else 1,parent.ZIndex+1
 return item
end
local function label(parent,name,text,size,color)
 local item=Theme.Label(parent,name,text,size,color or WHITE)
 item.ZIndex,item.TextWrapped=parent.ZIndex+4,false
 item.TextOutline.Color=Color3.new()
 return item
end
local function button(parent,name,text,callback,color)
 local item=Theme.ActionButton(parent,name,text,callback,color)
 item.ZIndex=parent.ZIndex+5;item.TextColor3=WHITE
 local visual=item.Visual
 visual.ZIndex,visual.Face.ZIndex,visual.LowerLip.ZIndex=item.ZIndex,item.ZIndex+1,item.ZIndex
 visual.Caption.ZIndex=item.ZIndex+4
 Theme.ApplyReferenceAccent(item,if color==PURPLE then ACCENT else ColorSequence.new(Color3.fromRGB(255,101,79),Color3.fromRGB(246,43,65)))
 for _,node in {item,visual,visual.Face,visual.LowerLip} do Theme.Round(node).CornerRadius=UDim.new(0,0) end
 visual.Face.InsetHighlight.ZIndex=item.ZIndex+2
 visual.Face.InsetHighlight.UIStroke.Color=if color==PURPLE then Color3.fromRGB(224,167,255) else Color3.fromRGB(255,193,190)
 visual.Face.InsetHighlight.UIStroke.Transparency=0.15
 return item
end
local function place(item,x,y,w,h)
 item.Position,item.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)
end
local function number(value)
 return Theme.Number(value or 0)
end

function Browser.new(app,parent)
 local self=setmetatable({app=app,alive=true,viewSerial=0,key="",query="",cards={},connections={}},Browser)
 local root=frame(parent,"MergeBrowser",UDim2.fromScale(1,1),nil,INK)
 root:SetAttribute("OwnsPopupStyle",true)
 root.Visible,root.ClipsDescendants=false,true
 Theme.Stroke(root,Color3.new(),6)
 self.root=root
 local header,title=Theme.Header(root,"Header","Merge Chickens",PURPLE)
 header.ZIndex=root.ZIndex+2;title.ZIndex=header.ZIndex+4;title.TextColor3=WHITE
 Theme.ApplyReferenceAccent(header,ACCENT)
 header.UIStroke.Color,header.UIStroke.Thickness=PURPLE,2
 header.PageIcon.Image,header.PageIcon.Visible,header.PageIcon.ZIndex=Theme.Assets.Merge,true,header.ZIndex+3
 self.header,self.title=header,title
 self.closeButton=button(root,"Close","X",function() app.audio:Play("Click");app:ClosePanel() end,Theme.Arcade.red)
 self.result=frame(root,"Result",UDim2.new())
 self.resultTitle=label(self.result,"Title","Result",46)
 self.stage=frame(self.result,"Preview",UDim2.new())
 self.level=label(self.result,"Level","",22,MUTED)
 self.level.TextXAlignment=Enum.TextXAlignment.Center
 self.dpsName=label(self.result,"DPS","DPS",30)
 self.cashName=label(self.result,"Cash","Eggs/s",30)
 self.dps=label(self.result,"DPSValue","— → —",32)
 self.cash=label(self.result,"CashValue","— → —",32)
 self.dps.TextXAlignment,self.cash.TextXAlignment=Enum.TextXAlignment.Right,Enum.TextXAlignment.Right
 self.action=button(self.result,"Merge","Merge 3 → 1",function() self:Merge() end,PURPLE)
 self.divider=frame(root,"Divider",UDim2.new(),nil,PURPLE)
 local searchShell=frame(root,"Search",UDim2.new())
 Theme.Stroke(searchShell,Color3.fromRGB(159,98,192),1.5)
 self.searchIcon=Theme.Image(searchShell,"Icon","rbxassetid://111902627409710",UDim2.fromOffset(40,40))
 self.searchIcon.ImageColor3,self.searchIcon.ZIndex=MUTED,searchShell.ZIndex+2
 local search=Instance.new("TextBox")
 search.Name,search.Text,search.PlaceholderText="SearchChickens","","Search..."
 search.BackgroundTransparency,search.BorderSizePixel,search.ClearTextOnFocus=1,0,false
 search.Font,search.TextColor3,search.PlaceholderColor3=Theme.Font,WHITE,MUTED
 search.TextXAlignment,search.ZIndex,search.Parent=Enum.TextXAlignment.Left,searchShell.ZIndex+3,searchShell
 self.searchShell,self.search=searchShell,search
 local grid=Instance.new("ScrollingFrame")
 grid.Name,grid.BackgroundTransparency,grid.BorderSizePixel="MatchingChickens",1,0
 grid.ScrollBarThickness,grid.ScrollBarImageColor3=6,PURPLE
 grid.ScrollingDirection,grid.AutomaticCanvasSize=Enum.ScrollingDirection.Y,Enum.AutomaticSize.Y
 grid.CanvasSize,grid.ZIndex,grid.Parent=UDim2.new(),root.ZIndex+2,root
 local padding=Instance.new("UIPadding",grid)
 padding.PaddingLeft,padding.PaddingTop,padding.PaddingBottom,padding.PaddingRight=UDim.new(0,4),UDim.new(0,4),UDim.new(0,8),UDim.new(0,8)
 local layout=Instance.new("UIGridLayout",grid)
 layout.SortOrder,layout.FillDirectionMaxCells=Enum.SortOrder.LayoutOrder,4
 self.grid,self.layout=grid,layout
 self.empty=label(root,"Empty","Collect 3 matching chickens to merge.",26,MUTED)
 self.empty.TextWrapped,self.empty.TextXAlignment=true,Enum.TextXAlignment.Center
 table.insert(self.connections,search:GetPropertyChangedSignal("Text"):Connect(function()
  self.query=string.lower(search.Text):match("^%s*(.-)%s*$") or ""
  self.grid.CanvasPosition=Vector2.zero;self:Render(true)
 end))
 return self
end

function Browser:Resize()
 local w,h=self.app.panelWidth,self.app.panelHeight
 self.root.Size=UDim2.fromScale(1,1)
 local desktop=w>=780 and h>=490
 local sideBySide=w>=650 or (w>=540 and h<480)
 local k=if desktop then w/1318 else 1
 local hh=if desktop then 84*k else 56
 local margin=if desktop then 24*k else 12
 place(self.header,4,4,w-hh-12,hh)
 place(self.header.PageIcon,14*k,4*k,80*k,hh-8*k)
 if not desktop then place(self.header.PageIcon,6,4,48,48) end
 self.title.TextSize=if desktop then 68*k else 31
 self.title.TextFace.TextOutline.Thickness=if desktop then 5*k else 2
 place(self.title,if desktop then 108*k else 60,0,w-hh-(if desktop then 130*k else 72),hh)
 place(self.closeButton,w-hh-4,4,hh,hh);self.closeButton.TextSize=hh*0.78
 local top=hh+24*k
 if desktop then
  place(self.result,margin,top,376*k,h-top-24*k)
  place(self.divider,416*k,top,2*k,h-top-18*k)
  place(self.searchShell,w-392*k,top,370*k,62*k)
  place(self.grid,434*k,top+76*k,w-454*k,h-top-94*k)
  local cellWidth=math.floor((self.grid.Size.X.Offset-24-45*k)/4)
  self.layout.CellSize,self.layout.CellPadding=UDim2.fromOffset(cellWidth,268*k),UDim2.fromOffset(15*k,10*k)
  self.layout.FillDirectionMaxCells=4
 elseif sideBySide then
  place(self.result,margin,top,230,h-top-12)
  place(self.divider,252,top,1,h-top-12)
  place(self.searchShell,w-250,top,236,42)
  place(self.grid,263,top+54,w-275,h-top-66)
  local cols=math.max(2,math.floor((w-275)/140))
  self.layout.CellSize,self.layout.CellPadding=UDim2.new(1/cols,-10,0,165),UDim2.fromOffset(7,8)
  self.layout.FillDirectionMaxCells=cols
 else
  -- Narrow screens keep tap targets readable: result summary above a two-column grid.
  place(self.result,margin,top,w-margin*2,188)
  place(self.divider,margin,top+198,w-margin*2,1)
  place(self.searchShell,margin,top+210,w-margin*2,42)
  place(self.grid,margin,top+262,w-margin*2,h-top-274)
  self.layout.CellSize,self.layout.CellPadding=UDim2.new(0.5,-10,0,168),UDim2.fromOffset(8,10)
  self.layout.FillDirectionMaxCells=2
 end
 local rw,rh=self.result.Size.X.Offset,self.result.Size.Y.Offset
 if not desktop and not sideBySide then
  place(self.resultTitle,0,0,rw,30);self.resultTitle.TextSize=28
  place(self.stage,0,30,math.min(130,rw*0.36),130)
  place(self.level,0,163,math.min(130,rw*0.36),22);self.level.TextSize=16
  local x=math.min(134,rw*0.38);local sw=rw-x
  place(self.dpsName,x,30,72,28);place(self.cashName,x,58,90,28)
  place(self.dps,x+72,30,sw-72,28);place(self.cash,x+90,58,sw-90,28)
  place(self.action,x,102,sw,68);self.action.TextSize=math.min(32,sw*0.17)
  self.dpsName.TextSize,self.cashName.TextSize,self.dps.TextSize,self.cash.TextSize=18,18,18,18
 elseif not desktop then
  local ph=math.max(52,rh-174)
  place(self.resultTitle,8,0,rw-16,30);self.resultTitle.TextSize=28
  place(self.stage,0,30,rw,ph)
  place(self.level,0,30+ph,rw,20);self.level.TextSize=16
  place(self.dpsName,5,52+ph,70,24);place(self.cashName,5,76+ph,86,24)
  place(self.dps,78,52+ph,rw-83,24);place(self.cash,94,76+ph,rw-99,24)
  self.dpsName.TextSize,self.cashName.TextSize,self.dps.TextSize,self.cash.TextSize=18,18,18,18
  place(self.action,0,rh-60,rw,60);self.action.TextSize=32
 else
  local scale=k
  place(self.resultTitle,14*scale,0,rw-28*scale,58*scale);self.resultTitle.TextSize=46*scale
  local footer=if desktop then 246*k else 161
  place(self.stage,0,58*scale,rw,rh-footer-88*scale)
  place(self.level,0,rh-footer-28*scale,rw,26*scale);self.level.TextSize=22*scale
  local by=rh-(if desktop then 244*k else 151)
  place(self.dpsName,12*scale,by,110*scale,42*scale)
  place(self.cashName,12*scale,by+42*scale,128*scale,42*scale)
  place(self.dps,132*scale,by,rw-144*scale,42*scale)
  place(self.cash,132*scale,by+42*scale,rw-144*scale,42*scale)
  self.dpsName.TextSize,self.cashName.TextSize=30*scale,30*scale
  self.dps.TextSize,self.cash.TextSize=32*scale,32*scale
  local bh=if desktop then 120*k else 64
  place(self.action,0,rh-bh,rw,bh);self.action.TextSize=if desktop then 58*k else 34
 end
 local sh=self.searchShell.Size.Y.Offset
 place(self.searchIcon,14*k,sh*0.2,sh*0.6,sh*0.6)
 place(self.search,sh+8*k,0,self.searchShell.Size.X.Offset-sh-20*k,sh)
 self.search.TextSize=if desktop then 32*k else 23
 self.empty.Position,self.empty.Size=self.grid.Position,self.grid.Size
 self.cardScale=if desktop then k else 0.68
end

function Browser:NearStand()
 local world=workspace:FindFirstChild("PetRollWorld")
 local plot=self.app.state and world and world:FindFirstChild("Plot"..self.app.state.plotIndex)
 local stand=plot and plot:FindFirstChild("MergeStand")
 local counter=stand and stand:FindFirstChild("Counter")
 local body=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
 return counter~=nil and body~=nil and (counter.Position-body.Position).Magnitude<=14
end

function Browser:UpdateAction()
 local busy=self.pending~=nil or self.animating
 local ready=self.recipe~=nil and not busy and self:NearStand()
 self.action.Active,self.action.Selectable=ready==true,ready==true
 self.action.Text=if busy then "Merging…" else "Merge 3 → 1"
 self.action.Visual.Face.UIGradient.Transparency=NumberSequence.new(if ready then 0 else 0.55)
end

function Browser:RenderDetail(recipe)
 if self.presentation then self.presentation:Destroy();self.presentation=nil end
 for _,item in self.stage:GetChildren() do if item:IsA("GuiObject") then item:Destroy() end end
 self.recipe=recipe
 if recipe then
  self.presentation=Presentation.new(self.app,self.stage,recipe)
  self.level.Text="Lv. "..recipe.level.." → "..(recipe.level+1)
  self.dps.Text=number(recipe.beforeDps).." → "..number(recipe.afterDps)
  self.cash.Text=number(recipe.inputEggRate).." → "..number(recipe.afterEggRate)
 else
  self.level.Text=""
  self.dps.Text,self.cash.Text="— → —","— → —"
 end
end

function Browser:Render(force)
 if not self.app.state then return end
 self:Resize()
 if self.pending or self.animating then self:UpdateAction();return end
 local recipes=self.app.state.mergeOptions or {}
 local keyParts={self.query,tostring(self.selected),tostring(self.app.panelWidth),tostring(self.app.panelHeight)}
 local visible={}
 for _,r in recipes do
  if (r.count or 0)>=3 and string.find(string.lower(Catalog[r.species].name),self.query,1,true) then
   table.insert(visible,r)
   table.insert(keyParts,table.concat({r.key,r.firstId,r.secondId,r.thirdId,r.count,r.inputEggRate,r.afterEggRate,r.beforeDps,r.afterDps},":"))
  end
 end
 local signature=table.concat(keyParts,"|")
 if not force and self.key==signature then self:UpdateAction();return end
 self.key=signature
 local selected=nil
 for _,r in visible do if r.key==self.selected then selected=r;break end end
 selected=selected or visible[1];self.selected=selected and selected.key or nil
 self:RenderDetail(selected)
 for _,card in self.cards do card:Destroy() end;table.clear(self.cards)
 for index,r in visible do
  local card=Instance.new("TextButton")
  card.Name,card.Text,card.BackgroundTransparency,card.BorderSizePixel="Group_"..r.key,"",1,0
  card.AutoButtonColor,card.LayoutOrder,card.ZIndex,card.Parent=false,index,self.grid.ZIndex+1,self.grid
  local outline=Theme.Stroke(card,PURPLE,4*self.cardScale)
  outline.Enabled,outline.BorderStrokePosition=r.key==self.selected,Enum.BorderStrokePosition.Inner
  local portrait=self.app:Preview(card,r,UDim2.new(1.2,0,1,-30*self.cardScale),UDim2.new(0.5,0,0,-10*self.cardScale))
  portrait.ZIndex=card.ZIndex+1;portrait.AnchorPoint=Vector2.new(0.5,0)
  local title=label(card,"Name",Catalog[r.species].name,28*self.cardScale)
  title.TextXAlignment,title.TextScaled=Enum.TextXAlignment.Center,true
  title.Position,title.Size=UDim2.new(0,4,1,-44*self.cardScale),UDim2.new(1,-8,0,40*self.cardScale)
  local constraint=Instance.new("UITextSizeConstraint",title);constraint.MaxTextSize=28*self.cardScale;constraint.MinTextSize=12
  local count=label(card,"Count","×"..r.count,34*self.cardScale)
  count.TextXAlignment=Enum.TextXAlignment.Right
  count.Position,count.Size=UDim2.new(1,-90*self.cardScale,0,4),UDim2.fromOffset(84*self.cardScale,40*self.cardScale)
  if r.level>1 then
   local level=label(card,"Level","Lv. "..r.level,18*self.cardScale,MUTED)
   level.Position,level.Size=UDim2.fromOffset(5,50*self.cardScale),UDim2.fromOffset(65*self.cardScale,24*self.cardScale)
  end
  if r.key==self.selected then
   local check=frame(card,"Selected",UDim2.fromOffset(48*self.cardScale,48*self.cardScale),UDim2.fromOffset(5,5),PURPLE)
   check.ZIndex=card.ZIndex+6;Theme.ApplyReferenceAccent(check,ACCENT)
   local icon=Theme.Image(check,"Check","rbxassetid://102978514196695",UDim2.new(1,-6,1,-6),UDim2.fromOffset(3,3));icon.ZIndex=check.ZIndex+1
  end
  card.Activated:Connect(function()
   if self.pending or self.animating then return end
   self.app.audio:Play("Click");self.selected=r.key;self:Render(true)
  end)
  table.insert(self.cards,card)
 end
 self.empty.Visible=#visible==0
 local capped=false
 local counts={}
 for _,pet in self.app.state.pets or {} do
  if (pet.level or 1)>=(pet.levelCap or math.huge) then
   local key=pet.species..":"..(pet.level or 1)
   counts[key]=(counts[key] or 0)+1
   if counts[key]>=3 then capped=true end
  end
 end
 self.empty.Text=if self.query~="" then "No matching chickens."
  elseif capped then "These chickens have reached your current merge level cap."
  else "Collect 3 matching chickens to merge.\nFavorites and away chickens stay protected."
 self:UpdateAction()
end

function Browser:Merge()
 if self.pending or self.animating or not self.recipe or not self:NearStand() then return end
 local recipe=self.recipe
 local found=false
 for _,r in self.app.state.mergeOptions or {} do
  if r.key==recipe.key and r.firstId==recipe.firstId and r.secondId==recipe.secondId and r.thirdId==recipe.thirdId then found=true;break end
 end
 if not found then self:Render(true);return end
 self.app.audio:Play("Click")
 local pending={id=self.app:Request("Merge",{firstId=recipe.firstId,secondId=recipe.secondId,thirdId=recipe.thirdId,
  level=recipe.level,stationIndex=self.app.state.plotIndex}),viewSerial=self.viewSerial}
 self.pending=pending;self:UpdateAction()
 task.delay(12,function()
  if not self.alive or self.pending~=pending then return end
  self.pending=nil;self.key="";self.app:Request("Sync")
  if self.app.page=="Merge" and self.app.panel.Visible then
   self.app:Notify("Refreshing your flock. Check the result before trying again.",false);self:Render(true)
  end
 end)
end

function Browser:Receive(result)
 if not result or not self.pending or result.id~=self.pending.id then return end
 local pending=self.pending;self.pending=nil;self.key=""
 local visible=self.alive and pending.viewSerial==self.viewSerial and self.app.panel.Visible
  and not self.app.panelClosing and self.app.page=="Merge" and self:NearStand()
 if not visible then self:UpdateAction();return end
 if result.ok and self.presentation then
  self.animating=true
  self.presentation:Play(function() self.level.Text="Lv. "..(self.recipe.level+1).." ↑" end,function()
   self.animating=false
   -- Keep the reveal briefly, then the remaining eligible group is ready for another deliberate tap.
   local serial=self.viewSerial
   task.delay(0.6,function() if self.alive and serial==self.viewSerial and not self.pending then self:Render(true) end end)
  end)
 else self:Render(true) end
 self:UpdateAction()
end

function Browser:Close()
 self.viewSerial+=1;self.animating=false;self.recipe=nil;self.selected=nil;self.key=""
 if self.presentation then self.presentation:Destroy();self.presentation=nil end
end
function Browser:Reset()
 self:Close();self.search.Text="";self.query="";self.grid.CanvasPosition=Vector2.zero
end
function Browser:Destroy()
 self.alive=false;self:Close()
 for _,connection in self.connections do connection:Disconnect() end
 self.root:Destroy()
end
return Browser
