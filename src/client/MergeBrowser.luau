--!strict
-- Compact pair picker with a one-pass batch of the displayed eligible pairs.
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Theme=require(script.Parent.UITheme)
local MergePresentation=require(script.Parent.MergePresentation)
local C,A=Theme.Colors,Theme.Arcade
local Browser={}
Browser.__index=Browser
local function label(parent,name,text,size,position,bounds,color)
 local item=Theme.Label(parent,name,text,size,color);item.Position,item.Size=position,bounds
 item.TextXAlignment=Enum.TextXAlignment.Center
 return item
end
local function clear(frame)
 for _,item in frame:GetChildren() do if item:IsA("GuiObject") then item:Destroy() end end
end

function Browser.new(app,parent)
 local self=setmetatable({app=app,key="",viewSerial=0,alive=true},Browser)
 local root=Theme.Frame(parent,"MergeBrowser",UDim2.new(1,-32,1,-124))
 root.Position,root.BackgroundTransparency,root.Visible=UDim2.fromOffset(16,108),1,false
 self.root=root
 self.summary=label(root,"ReadyCount","Ready pairs",23,UDim2.fromOffset(0,0),UDim2.new(0.35,0,0,30))
 local grid=Instance.new("ScrollingFrame")
 grid.Name,grid.Position,grid.Size="MatchingPairs",UDim2.fromOffset(0,36),UDim2.new(0.35,-8,1,-126)
 grid.BackgroundTransparency,grid.BorderSizePixel,grid.ScrollBarThickness=1,0,5
 grid.ScrollBarImageColor3,grid.AutomaticCanvasSize,grid.CanvasSize=A.purple,Enum.AutomaticSize.Y,UDim2.new()
 grid.Parent=root;self.grid=grid
 local padding=Instance.new("UIPadding",grid)
 padding.PaddingLeft,padding.PaddingRight,padding.PaddingTop,padding.PaddingBottom=UDim.new(0,5),UDim.new(0,8),UDim.new(0,6),UDim.new(0,8)
 local layout=Instance.new("UIGridLayout",grid)
 layout.CellSize,layout.CellPadding,layout.SortOrder=UDim2.new(0.5,-9,0,143),UDim2.fromOffset(8,10),Enum.SortOrder.LayoutOrder
 self.allIncome=label(root,"BatchIncome","",16,UDim2.new(0,0,1,-82),UDim2.new(0.35,-8,0,25),C.gold)
 self.allAction=Theme.Button(root,"MergeAll","MERGE ALL",function() self:MergeAll() end,Theme.ActionColors.purchase)
 self.allAction.Position,self.allAction.Size,self.allAction.TextSize=UDim2.new(0,5,1,-52),UDim2.new(0.35,-18,0,44),25
 local detail=Theme.Frame(root,"SelectedMerge",UDim2.new(0.65,-8,1,0))
 detail.Position=UDim2.new(0.35,8,0,0);Theme.Surface(detail);self.detail=detail
 self.empty=label(root,"Empty","No matching pairs",25,UDim2.fromOffset(24,60),UDim2.new(1,-48,0,150),C.muted)
 self.empty.Visible=false
 return self
end

function Browser:Reset()
 self:Close()
 self.grid.CanvasPosition=Vector2.zero;self.key=""
end

function Browser:Close()
 self.viewSerial+=1
 self.selected,self.success,self.animating=nil,nil,false
 if self.presentation then self.presentation:Destroy();self.presentation=nil end
 -- Keep an outstanding request tracked, but never replay its animation on reopening.
 self.key=""
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
 local total=0
 for _,recipe in (self.app.state and self.app.state.mergeOptions) or {} do total+=recipe.pairs end
 local busy=self.pending~=nil or self.animating
 local near=self:NearStand()
 local allReady=total>0 and not busy and near
 self.allAction.Active,self.allAction.Selectable=allReady==true,allReady==true
 self.allAction.BackgroundColor3=if allReady then Theme.ActionColors.purchase else Theme.ActionColors.disabled
 self.allAction.Text=if busy then "Merging…" elseif not near then "Return to stand" else "MERGE ALL ("..total..")"
 if not self.action or not self.action.Parent then return end
 local ready=self.recipe~=nil and not self.success and not self.pending and not self.animating and self:NearStand()
 self.action.Active,self.action.Selectable=ready==true,ready==true
 self.action.BackgroundColor3=if ready then Theme.ActionColors.purchase else Theme.ActionColors.disabled
 self.action.Text=if self.pending or self.animating then "Merging…" elseif not self:NearStand() then "Return to stand" else "MERGE"
end

function Browser:Merge()
 if self.pending or self.animating or self.success or not self.recipe or not self:NearStand() then return end
 local recipe=self.recipe
 -- The user acts on the pair currently previewed, never a newly substituted pair.
 local found=false
 for _,live in self.app.state.mergeOptions or {} do
  if live.key==recipe.key and live.firstId==recipe.firstId and live.secondId==recipe.secondId then found=true;break end
 end
 if not found then self.key="";self:Render(true);return end
 self.app.audio:Play("Click")
 self.pending={id=self.app:Request("Merge",{firstId=recipe.firstId,secondId=recipe.secondId,
  level=recipe.level,stationIndex=self.app.state.plotIndex}),species=recipe.species,level=recipe.level+1,viewSerial=self.viewSerial}
 self:UpdateAction()
end

function Browser:MergeAll()
 if self.pending or self.animating or not self:NearStand() then return end
 local recipes=self.app.state.mergeOptions or {}
 local pairs={}
 for _,recipe in recipes do
  local ids=recipe.petIds or {}
  for index=1,#ids-1,2 do
   table.insert(pairs,{firstId=ids[index],secondId=ids[index+1],level=recipe.level})
  end
 end
 if #pairs==0 then self:Render(true);return end
 -- One shared celebration, followed by a receipt for every upgraded chicken.
 self.success=nil;self.selected=recipes[1].key
 self:RenderDetail(recipes[1])
 self.detail.Visible=true
 self.detail.NameLabel.Text="Merging "..#pairs..(if #pairs==1 then " pair" else " pairs")
 self.app.audio:Play("Click")
 self.pending={id=self.app:Request("MergeAll",{pairs=pairs,stationIndex=self.app.state.plotIndex}),
  species=recipes[1].species,level=recipes[1].level+1,viewSerial=self.viewSerial}
 self:UpdateAction()
end

function Browser:Receive(result)
 if not result or not self.pending or result.id~=self.pending.id then return end
 local pending=self.pending;self.pending=nil
 local visible=self.alive and pending.viewSerial==self.viewSerial and self.app.panel.Visible
  and not self.app.panelClosing and self.app.page=="Merge" and self:NearStand()
 self.key=""
 if result.ok and visible and self.presentation then
  local pet=self.app:Pet(result.petId)
  self.success={species=if pet then pet.species else pending.species,level=if pet then pet.level else pending.level,
   receipt=if result.action=="MergeAll" then result.receipt else nil}
  self.animating=true
  self.presentation:Play(function()
   self.levelSummary.Text=if self.success.receipt then "Merged "..self.success.receipt.count.."!" else "Lv. "..self.success.level.." ↑"
   self.levelSummary.TextColor3=Theme.ActionColors.purchase
   self.incomeLabel.Visible=false
  end,function()
   self.animating=false;self.selected=nil;self.key="";self:Render(true)
  end)
 end
 self:UpdateAction()
end

function Browser:RenderReceipt(receipt)
 label(self.detail,"BatchResult","Merged "..receipt.count.." pairs!",29,UDim2.fromOffset(12,9),UDim2.new(1,-24,0,40),Theme.ActionColors.purchase)
 local list=Instance.new("ScrollingFrame")
 list.Name,list.Position,list.Size="MergeResults",UDim2.fromOffset(14,60),UDim2.new(1,-28,1,-76)
 list.BackgroundTransparency,list.BorderSizePixel,list.ScrollBarThickness=1,0,5
 list.ScrollBarImageColor3,list.AutomaticCanvasSize,list.CanvasSize=A.purple,Enum.AutomaticSize.Y,UDim2.new()
 list.Parent=self.detail
 local layout=Instance.new("UIGridLayout",list)
 layout.CellSize,layout.CellPadding=UDim2.new(0.5,-10,0,168),UDim2.fromOffset(10,10)
 local groups,order={},{}
 for _,result in receipt.results do
  local key=result.species..":"..result.level
  if not groups[key] then groups[key]={species=result.species,level=result.level,count=0};table.insert(order,key) end
  groups[key].count+=1
 end
 for index,key in order do
  local group=groups[key]
  local card=Theme.Frame(list,"Result"..index,UDim2.fromOffset(160,168));Theme.Surface(card);card.LayoutOrder=index
  self.app:Preview(card,group,UDim2.new(1,-12,0,110),UDim2.fromOffset(6,0))
  label(card,"Name",Catalog[group.species].name,20,UDim2.fromOffset(5,108),UDim2.new(1,-10,0,26))
  label(card,"Quantity","Lv. "..group.level.." ↑  ×"..group.count,20,UDim2.fromOffset(5,135),UDim2.new(1,-10,0,26),Theme.ActionColors.purchase)
 end
end

function Browser:RenderDetail(recipe)
 if self.presentation then self.presentation:Destroy();self.presentation=nil end
 clear(self.detail);Theme.Surface(self.detail)
 self.action,self.recipe=nil,recipe
 if self.success then
  if self.success.receipt and self.success.receipt.count>1 then self:RenderReceipt(self.success.receipt);return end
  label(self.detail,"Name",Catalog[self.success.species].name,29,UDim2.fromOffset(12,9),UDim2.new(1,-24,0,40))
  self.presentation=MergePresentation.new(self.app,self.detail,{species=self.success.species,level=self.success.level-1})
  self.presentation:ShowResult()
  label(self.detail,"UpgradedLevel","Lv. "..self.success.level.." ↑",29,UDim2.new(0,14,1,-116),UDim2.new(1,-28,0,38),Theme.ActionColors.purchase)
  return
 end
 if not recipe then
  label(self.detail,"Choose","Choose a chicken",28,UDim2.new(0,20,0.4,0),UDim2.new(1,-40,0,50),C.muted)
  return
 end
 label(self.detail,"NameLabel",Catalog[recipe.species].name,29,UDim2.fromOffset(12,9),UDim2.new(1,-24,0,40))
 self.presentation=MergePresentation.new(self.app,self.detail,{species=recipe.species,level=recipe.level})
 self.levelSummary=label(self.detail,"LevelChange","Lv. "..recipe.level.." + Lv. "..recipe.level.." → Lv. "..(recipe.level+1),23,
  UDim2.new(0,14,1,-116),UDim2.new(1,-28,0,30),C.muted)
 self.incomeLabel=label(self.detail,"IncomeChange","Egg income "..Theme.Money(recipe.beforeIncome).." → "..Theme.Money(recipe.afterIncome).."/s",18,
  UDim2.new(0,10,1,-84),UDim2.new(1,-20,0,25),C.gold)
 self.action=Theme.Button(self.detail,"MergePair","MERGE",function() self:Merge() end,Theme.ActionColors.purchase)
 self.action.Position,self.action.Size,self.action.TextSize=UDim2.new(0,14,1,-53),UDim2.new(1,-28,0,42),28
 self:UpdateAction()
end

function Browser:Render(force)
 if not self.alive or self.app.panelClosing or not self.app.panel.Visible or self.app.page~="Merge" then return end
 local state=self.app.state
 if not state then return end
 -- Live inventory packets must not rebuild the pair being submitted or animated.
 if self.animating or (self.pending and self.pending.viewSerial==self.viewSerial and self.presentation) then self:UpdateAction();return end
 local recipes=state.mergeOptions or {}
 local selected
 for _,recipe in recipes do if recipe.key==self.selected then selected=recipe end end
 if not selected then
  self.selected=nil
  if #recipes==1 and not self.success then selected=recipes[1];self.selected=selected.key end
 end
 local total,beforeIncome,afterIncome=0,0,0
 local keys={self.selected or "",tostring(state.incomeLevel),tostring(self.success)}
 for _,recipe in recipes do
  total+=recipe.pairs
  beforeIncome+=recipe.beforeIncome*recipe.pairs;afterIncome+=recipe.afterIncome*recipe.pairs
  table.insert(keys,recipe.key..":"..table.concat(recipe.petIds or {recipe.firstId,recipe.secondId},",")..":"..recipe.pairs..":"..recipe.beforeIncome..":"..recipe.afterIncome)
 end
 self.summary.Text=total.." ready "..(if total==1 then "pair" else "pairs")
 self.allIncome.Text="Egg income "..Theme.Money(beforeIncome).." → "..Theme.Money(afterIncome).."/s"
 self.allAction.Visible,self.allIncome.Visible=total>0,total>0
 local signature=table.concat(keys,"|")
 if signature==self.key and not force then self:UpdateAction();return end
 self.key=signature
 self.empty.Visible=#recipes==0 and not self.success
 self.grid.Visible,self.summary.Visible=#recipes>0,#recipes>0
 self.detail.Visible=#recipes>0 or self.success~=nil
 if self.empty.Visible then
  local matching,capped={},false
  for _,pet in state.pets do
   if pet.home and not pet.favorite then
    local id=pet.species..":"..pet.level;matching[id]=(matching[id] or 0)+1
    if matching[id]>1 and state.progression and pet.level>=state.progression.levelCap then capped=true end
   end
  end
  self.empty.Text=if capped then "Matching chickens are at your level cap." else "No matching pairs\nTwo of the same chicken and level."
 end
 local scroll=self.grid.CanvasPosition;clear(self.grid)
 for i,recipe in recipes do
  local active=selected~=nil and selected.key==recipe.key
  local card=Theme.CollectionCard(self.grid,"Pair"..i,function()
   if self.pending or self.animating then return end
   self.app.audio:Play("Click");self.selected,self.success=recipe.key,nil;self:Render(true)
  end,Theme.Rarities[Catalog[recipe.species].rarity],active)
  card.LayoutOrder=i;card:SetAttribute("RecipeKey",recipe.key)
  label(card.Visual,"Level","Lv. "..recipe.level.." · ×"..recipe.pairs,17,UDim2.fromOffset(5,3),UDim2.new(1,-10,0,23),C.cardMuted)
  self.app:Preview(card.Visual,{species=recipe.species},UDim2.new(1,-12,0,85),UDim2.fromOffset(6,26))
  label(card.Visual,"Name",Catalog[recipe.species].name,19,UDim2.new(0,5,1,-30),UDim2.new(1,-10,0,26))
 end
 self.grid.CanvasPosition=scroll;self:RenderDetail(selected);self:UpdateAction()
end

function Browser:Destroy() self.alive=false;self:Close() end
return Browser
