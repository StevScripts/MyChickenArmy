--!strict
-- Image-led fuse UI, Figma 437:2024. Server-owned exact triple; reversible local slots.
local Players=game:GetService("Players")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Theme=require(script.Parent.UITheme)
local Selection=require(script.Parent.MergeSelection)
local Giant=require(Shared.GiantChicken)
local Presentation=require(script.Parent.MergePresentation)
local Browser={}
Browser.__index=Browser
local PURPLE=Color3.fromRGB(186,67,239)
local INK=Color3.fromRGB(13,9,19)
local WHITE=Color3.new(1,1,1)
local MUTED=Color3.fromRGB(185,182,199)
local LINE=Color3.fromRGB(99,92,113)
local PIPE_IDLE=Color3.fromRGB(67,38,83)
local ACCENT=ColorSequence.new(Color3.fromRGB(207,72,255),Color3.fromRGB(138,20,219))
local function place(item,x,y,w,h)
 item.Position,item.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)
end
local function frame(parent,name,color)
 local item=Theme.Frame(parent,name,UDim2.new(),color)
 item.BackgroundTransparency,item.ZIndex=if color then 0 else 1,parent.ZIndex+1
 return item
end
local function label(parent,name,text,size,color)
 local item=Theme.Label(parent,name,text,size,color or WHITE)
 item.ZIndex,item.TextWrapped,item.TextXAlignment=parent.ZIndex+4,false,Enum.TextXAlignment.Center
 item.TextOutline.Color=Color3.new()
 return item
end
local function fitText(item,maxSize,minSize)
 item.TextScaled=true
 local constraint=Instance.new("UITextSizeConstraint",item)
 constraint.MinTextSize,constraint.MaxTextSize=minSize or 12,maxSize
 return constraint
end
local function button(parent,name,text,callback,secondary)
 local item=Theme.ActionButton(parent,name,text,callback,if secondary=="close" then Theme.Arcade.red else PURPLE)
 item.ZIndex,item.TextColor3=parent.ZIndex+5,WHITE
 local visual=item.Visual
 visual.ZIndex,visual.Face.ZIndex,visual.LowerLip.ZIndex=item.ZIndex,item.ZIndex+1,item.ZIndex
 visual.Caption.ZIndex=item.ZIndex+4
 Theme.ApplyReferenceAccent(item,if secondary=="close" then ColorSequence.new(Color3.fromRGB(255,101,79),Color3.fromRGB(246,43,65)) else ACCENT)
 for _,node in {item,visual,visual.Face,visual.LowerLip} do Theme.Round(node).CornerRadius=UDim.new(0,0) end
 visual.Face.InsetHighlight.ZIndex=item.ZIndex+2
 visual.Face.InsetHighlight.UIStroke.Color=if secondary=="close" then Color3.fromRGB(255,193,190) else Color3.fromRGB(224,167,255)
 visual.Face.InsetHighlight.UIStroke.Transparency=0.15
 if secondary==true then
  visual.Face.BackgroundColor3=INK;visual.Face.UIGradient.Enabled=false
  for _,node in visual.Face:GetDescendants() do
   if node:IsA("ImageLabel") and node.Name=="StudTexture" then node.Visible=false end
  end
 end
 return item
end
local function scroll(parent,name)
 local item=Instance.new("ScrollingFrame")
 item.Name,item.BackgroundTransparency,item.BorderSizePixel=name,1,0
 item.ScrollBarThickness,item.ScrollBarImageColor3=4,PURPLE
 item.ScrollingDirection,item.CanvasSize=Enum.ScrollingDirection.Y,UDim2.new()
 item.ZIndex,item.Parent=parent.ZIndex+2,parent
 return item
end
local function preview(app,parent,pet)
 local item=app:Preview(parent,pet,UDim2.fromScale(1,1))
 item.ZIndex=parent.ZIndex+2
 return item
end
local function line(parent,name)
 local item=frame(parent,name,PIPE_IDLE)
 item.AnchorPoint=Vector2.new(0.5,0.5)
 Theme.Stroke(item,Color3.new(),3)
 return item
end
local function segment(item,from,to,thickness)
 local delta=to-from
 item.Position,item.Size=UDim2.fromOffset((from.X+to.X)/2,(from.Y+to.Y)/2),UDim2.fromOffset(delta.Magnitude,thickness)
 item.Rotation=math.deg(math.atan2(delta.Y,delta.X))
end

function Browser.new(app,parent)
 local self=setmetatable({app=app,alive=true,viewSerial=0,selection=Selection.new(),mode="Main",query="",cards={},connections={},slots={},key=""},Browser)
 local root=frame(parent,"MergeBrowser",INK)
 root.Size,root.Visible,root.ClipsDescendants=UDim2.fromScale(1,1),false,true
 root:SetAttribute("OwnsPopupStyle",true);Theme.Stroke(root,Color3.new(),6);self.root=root
 local rim=frame(root,"PurpleRim")
 rim.Position,rim.Size=UDim2.fromOffset(3,3),UDim2.new(1,-6,1,-6)
 Theme.Stroke(rim,PURPLE,2)
 self.header,self.title=Theme.Header(root,"Header","Fuse Chickens",PURPLE)
 self.header.ZIndex,self.title.ZIndex=root.ZIndex+2,root.ZIndex+6
 self.title.TextColor3=WHITE;Theme.ApplyReferenceAccent(self.header,ACCENT)
 self.header.UIStroke.Color,self.header.UIStroke.Thickness=PURPLE,2
 self.header.PageIcon.Image,self.header.PageIcon.Visible,self.header.PageIcon.ZIndex=Theme.Assets.Merge,true,self.header.ZIndex+3
 self.closeButton=button(root,"Close","X",function() app.audio:Play("Click");app:ClosePanel() end,"close")
 self.body=Theme.Container(root,"Main")
 self.footer=Theme.Container(root,"Actions")
 self.footer.AnchorPoint=Vector2.new(0.5,1)
 self.main=scroll(self.body,"ThreeChickenFlow")
 self.mainContent=frame(self.main,"Content")
 self.rule=label(self.mainContent,"Rule","3 matching chickens",29)
 self.rule.TextXAlignment=Enum.TextXAlignment.Center
 self.count=label(self.mainContent,"SelectedCount","0/3",30,MUTED)
 self.count.TextXAlignment=Enum.TextXAlignment.Right
 for i=1,3 do
  local box=frame(self.mainContent,"Input"..i,INK);local outline=Theme.Stroke(box,LINE,3)
  box.ZIndex=self.mainContent.ZIndex+3
  local title=label(box,"ChickenName","",28);fitText(title,28,12)
  local art=frame(box,"Portrait")
  local empty=label(art,"Empty","?",80,MUTED);empty.Size=UDim2.fromScale(1,1)
  local level=label(box,"Level","",24);fitText(level,24,16)
  local action=button(box,"AddRemove","+\nAdd",function() self:Slot(i) end)
  action.TextWrapped=true
  self.slots[i]={box=box,title=title,level=level,art=art,empty=empty,action=action,outline=outline,
   stem=line(self.mainContent,"PathStem"..i),path=line(self.mainContent,"Path"..i),
   socket=line(self.mainContent,"InputSocket"..i),outputSocket=line(self.mainContent,"OutputSocket"..i)}
 end
 self.result=frame(self.mainContent,"Result",INK);self.result.ZIndex=self.mainContent.ZIndex+3
 self.resultOutline=Theme.Stroke(self.result,LINE,3)
 self.resultTitle=label(self.result,"Title","",28);fitText(self.resultTitle,28,16)
 self.resultArt=frame(self.result,"Portrait")
 self.resultEmpty=label(self.resultArt,"Empty","?",90,MUTED);self.resultEmpty.Size=UDim2.fromScale(1,1)
 self.resultName=label(self.result,"ChickenLevel","",32,PURPLE);fitText(self.resultName,32,20)
 self.action=button(self.footer,"Fuse","Fuse",function() self:Merge() end)
 fitText(self.action.Visual.Caption,46,14);self.action.Visual.Caption.TextWrapped=false
 self.message=label(self.body,"Status","",20,MUTED);self.message.TextWrapped=true
 self.tradeoff=label(self.footer,"Tradeoff","3 chickens → 1 Giant",23,MUTED)
 self.picker=frame(self.body,"ChickenPicker")
 self.searchShell=frame(self.picker,"Search",Color3.new());Theme.Stroke(self.searchShell,LINE,1.5)
 local search=Instance.new("TextBox")
 search.Name,search.Text,search.PlaceholderText="SearchChickens","","Search…"
 search.BackgroundTransparency,search.BorderSizePixel,search.ClearTextOnFocus=1,0,false
 search.Font,search.TextColor3,search.PlaceholderColor3=Theme.Font,WHITE,MUTED
 search.TextXAlignment,search.ZIndex,search.Parent=Enum.TextXAlignment.Left,self.searchShell.ZIndex+2,self.searchShell
 self.search=search
 self.grid=scroll(self.picker,"EligibleChickens");self.grid.AutomaticCanvasSize=Enum.AutomaticSize.Y
 local padding=Instance.new("UIPadding",self.grid)
 padding.PaddingLeft,padding.PaddingRight,padding.PaddingTop,padding.PaddingBottom=UDim.new(0,4),UDim.new(0,8),UDim.new(0,4),UDim.new(0,8)
 self.layout=Instance.new("UIGridLayout",self.grid);self.layout.SortOrder=Enum.SortOrder.LayoutOrder
 self.emptyIcon=Theme.Image(self.picker,"EmptyIcon",Theme.Assets.Merge,UDim2.new());self.emptyIcon.ZIndex=self.picker.ZIndex+3
 self.empty=label(self.picker,"Empty","No matching trio yet",30);self.empty.TextWrapped=true
 self.hint=label(self.picker,"Hint","Keep collecting chickens.",23,MUTED);self.hint.TextWrapped=true
 self.back=button(self.picker,"Back","Back",function()
  if self.query~="" and #self.cards==0 then self.search.Text="" else self.mode="Main";self:Render(true);self:Focus(self.slots[self.activeSlot or 1].action) end
 end)
 self.summary=scroll(self.body,"FusionResult")
 self.summaryRays=Theme.Image(self.summary,"ResultRays",Theme.Assets.Rays,UDim2.new())
 self.summaryRays.ImageColor3,self.summaryRays.ImageTransparency,self.summaryRays.ZIndex=PURPLE,0.55,self.summary.ZIndex+1
 self.summaryArt=frame(self.summary,"Portrait")
 self.summaryName=label(self.summary,"Name","",44);fitText(self.summaryName,44,22)
 self.summaryLevel=label(self.summary,"Level","",30,Color3.fromRGB(224,167,255))
 fitText(self.summaryLevel,30,16)
 self.eggChip=frame(self.summary,"EggOutputChip",INK);Theme.Stroke(self.eggChip,LINE,2)
 self.dpsChip=frame(self.summary,"CombatChip",INK);Theme.Stroke(self.dpsChip,LINE,2)
 self.summaryEggs=label(self.eggChip,"EggOutput","",30);self.summaryEggs.Size=UDim2.fromScale(1,1);fitText(self.summaryEggs,30,16)
 self.summaryDps=label(self.dpsChip,"Combat","",30);self.summaryDps.Size=UDim2.fromScale(1,1);fitText(self.summaryDps,30,16)
 self.done=button(self.footer,"Done","Done",function()
  if self.pending or self.animating then return end
  self.completed=nil;self.mode="Main";self.selection:Clear();self:Render(true);self:Focus(self.slots[1].action)
 end)
 self.processing=frame(self.body,"Processing")
 self.processingArt=frame(self.processing,"ChickenAnimation")
 self.processingText=label(self.processing,"Status","Fusing…",38)
 self.processingHint=label(self.processing,"Hint","",23,MUTED);self.processingHint.TextWrapped=true
 table.insert(self.connections,search:GetPropertyChangedSignal("Text"):Connect(function()
  self.query=string.lower(search.Text):match("^%s*(.-)%s*$") or ""
  self.grid.CanvasPosition=Vector2.zero;self.key=""
  if self.mode=="Picker" then self:Render(true) end
 end))
 return self
end

function Browser:Focus(item)
 if UserInputService.GamepadEnabled and self.root.Visible then GuiService.SelectedObject=item end
end

function Browser:Resize()
 local w,h=self.app.panelWidth,self.app.panelHeight
 local k=math.min(1.1,w/900)
 local compact=w<600
 local hh=math.max(56,96*k)
 local margin=if compact then 12 else 24*k
 local gap=if compact then 12 else 18*k
 local inner=w-margin*2
 local flowW=inner-8
 local bh=math.max(56,80*k)
 local top=hh+20*k
 local footer=h-bh-math.max(32,32*k)
 local actionW=if compact then inner else 632*k
 local bodyHeight=h-top-20
 Theme.RelativeRect(self.body,margin,top,inner,bodyHeight,w,h)
 self.footer.Position=UDim2.new(0.5,0,1,-math.max(32,32*k)+28)
 self.footer.Size=UDim2.new(inner/w,0,0,bh+28)
 self.root.Size=UDim2.fromScale(1,1)
 place(self.header,4,4,w-hh-12,hh)
 place(self.header.PageIcon,6,3,hh-6,hh-6)
 place(self.title,hh+4,0,w-hh*2-24,hh)
 self.title.TextSize=if compact then 28 else 58*k
 self.title.TextFace.TextOutline.Thickness=if compact then 2 else 3
 place(self.closeButton,w-hh-4,4,hh,hh);self.closeButton.TextSize=hh*0.75
 Theme.RelativeRect(self.action,(inner-actionW)/2,0,actionW,bh,inner,bh+28);self.action.TextSize=math.max(26,46*k)
 self.done.Position,self.done.Size=UDim2.new(),UDim2.new(1,0,0,bh);self.done.TextSize=self.action.TextSize
 place(self.tradeoff,0,bh+2,inner,26);self.tradeoff.TextSize=math.max(17,23*k)
 local noticeH=if self.notice or self.costNotice then 38 else 0
 place(self.message,0,footer-top-noticeH-5,inner,noticeH)
 Theme.RelativeRect(self.main,0,0,inner,math.max(60,footer-top-18-noticeH),inner,bodyHeight)
 local empty=self.selection:Count()==0
 local rowH=if compact then 30 else 44*k
 place(self.rule,0,0,flowW,rowH);self.rule.TextSize=if compact then 21 else 34*k
 self.rule.Visible=empty;self.count.Visible=false
 local slotW=(flowW-gap*2)/3
 local slotH=if compact then (if empty then 142 else 176) else (if empty then 194 else 244)*k
 local slotY=if empty then rowH+12*k else 4*k
 local sw=math.max(44,52*k)
 for i,slot in self.slots do
  local x=(i-1)*(slotW+gap)
  place(slot.box,x,slotY,slotW,slotH)
  place(slot.title,4,2,slotW-8,math.max(24,34*k))
  place(slot.level,3,slotH-sw-math.max(24,28*k)-7,slotW-6,math.max(24,28*k))
  local artSide=if compact then slotW+16 else math.min(slotW+12,slotH-sw-20*k)
  place(slot.art,(slotW-artSide)/2,if compact then 12 else 14*k,artSide,artSide)
  if self.selection.slots[i] then
   place(slot.action,6,slotH-sw-4,slotW-12,sw)
   slot.action.TextSize=if compact then 19 else 30*k
  else
   local addW=math.min(slotW-20,184*k)
   local addH=math.max(72,94*k)
   place(slot.action,(slotW-addW)/2,(slotH-addH)/2,addW,addH)
   slot.action.TextSize=if compact then 24 else 36*k
  end
 end
 local resultW=if compact then 176 else 256*k
 local resultH=if compact then 182 else 250*k
 local pathGap=if compact then 42 else 66*k
 local resultY=slotY+slotH+pathGap
 place(self.result,(flowW-resultW)/2,resultY,resultW,resultH)
 place(self.resultTitle,4,2,resultW-8,math.max(28,36*k))
 local resultArt=if compact then 166 else resultH-16*k
 place(self.resultArt,(resultW-resultArt)/2,if compact then 4 else 14*k,resultArt,resultArt)
 place(self.resultName,4,resultH-math.max(32,38*k),resultW-8,math.max(32,38*k))
 for i,slot in self.slots do
  local start=Vector2.new((i-1)*(slotW+gap)+slotW/2,slotY+slotH)
  local bend=start+Vector2.new(0,if i==2 then pathGap/2 else pathGap)
  local finish=Vector2.new(flowW/2+(i-2)*resultW/2,resultY+(if i==2 then 0 else resultH/2))
  local thickness=math.max(12,26*k)
  segment(slot.stem,start,bend,thickness);segment(slot.path,bend,finish,thickness)
  slot.socket.Position,slot.socket.Size=UDim2.fromOffset(start.X,start.Y+6*k),UDim2.fromOffset(math.max(26,48*k),math.max(8,14*k))
  slot.outputSocket.Position=UDim2.fromOffset(finish.X,finish.Y)
  slot.outputSocket.Size=if i==2 then UDim2.fromOffset(math.max(26,48*k),math.max(8,14*k)) else UDim2.fromOffset(math.max(8,14*k),math.max(26,48*k))
 end
 local canvasH=resultY+resultH+6
 place(self.mainContent,4,0,flowW,canvasH);self.main.CanvasSize=UDim2.fromOffset(0,canvasH)
 self.picker.Position,self.picker.Size=UDim2.new(),UDim2.fromScale(1,1)
 place(self.searchShell,0,0,inner,math.max(44,60*k))
 place(self.search,12,0,inner-24,self.searchShell.Size.Y.Offset);self.search.TextSize=math.max(23,29*k)
 local gridY=self.searchShell.Size.Y.Offset+16*k
 local gridH=math.max(56,bodyHeight-gridY-bh-18)
 place(self.grid,0,gridY,inner,gridH)
 local cols=if compact then 2 else 3
 local cellGap=if compact then 12 else 18*k
 local cellW=math.floor((inner-16-(cols-1)*cellGap)/cols)
 self.layout.CellSize,self.layout.CellPadding=UDim2.fromOffset(cellW,math.max(168,cellW*0.94)),UDim2.fromOffset(cellGap,cellGap)
 self.layout.FillDirectionMaxCells=cols
 self.back.AnchorPoint=Vector2.new(0,1)
 self.back.Position,self.back.Size=UDim2.fromScale(0,1),UDim2.new(1,0,0,bh);self.back.TextSize=math.max(28,46*k)
 local iconH=math.min(270*k,gridH*0.5)
 place(self.emptyIcon,(inner-iconH)/2,gridY+math.max(0,gridH/2-iconH),iconH,iconH)
 place(self.empty,0,gridY+gridH/2+12,inner,50);self.empty.TextSize=if compact then 26 else 40*k
 place(self.hint,0,gridY+gridH/2+62,inner,48);self.hint.TextSize=if compact then 20 else 28*k
 local sh=math.max(100,footer-top-16)
 Theme.RelativeRect(self.summary,0,0,inner,sh,inner,bodyHeight)
 local artH=math.min(inner,414*k,math.max(80,sh-184))
 local blockH=artH+184;local sy=math.max(0,(sh-blockH)/2)
 self.summary.CanvasSize=UDim2.fromOffset(0,blockH)
 place(self.summaryRays,(inner-artH)/2,sy,artH,artH)
 place(self.summaryArt,(inner-artH)/2,sy,artH,artH)
 place(self.summaryName,0,sy+artH-10,inner,54)
 place(self.summaryLevel,0,sy+artH+44,inner,40)
 local chipGap=if compact then 12 else 20*k
 local chipW=(inner-chipGap)/2
 place(self.eggChip,0,sy+artH+102,chipW,60)
 place(self.dpsChip,chipW+chipGap,sy+artH+102,chipW,60)
 local ph=bodyHeight-4
 self.processing.Position,self.processing.Size=UDim2.new(),UDim2.new(1,0,1,-4)
 place(self.processingArt,inner*0.04,math.max(0,ph/2-210*k),inner*0.92,math.min(340*k,ph*0.6))
 place(self.processingText,0,ph*0.69,inner,64);self.processingText.TextSize=if compact then 36 else 62*k
 place(self.processingHint,12,ph*0.69+66,inner-24,60)
end

function Browser:NearStand()
 local world=workspace:FindFirstChild("PetRollWorld")
 local plot=self.app.state and world and world:FindFirstChild("Plot"..self.app.state.plotIndex)
 local stand=plot and plot:FindFirstChild("MergeStand")
 local counter=stand and stand:FindFirstChild("Counter")
 local body=Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
 return counter~=nil and body~=nil and (counter.Position-body.Position).Magnitude<=14
end

function Browser:Slot(index)
 if self.pending or self.animating or self.mode~="Main" then return end
 self.app.audio:Play("Click");self.notice=nil
 if self.selection.slots[index] then
  self.selection:Remove(index);self:Render(true)
 else
  self.activeSlot=index;self.mode="Picker";self.search.Text="";self.query="";self.grid.CanvasPosition=Vector2.zero
  self:Render(true);self:Focus(self.cards[1] or self.back)
 end
end

function Browser:Choose(key)
 if self.pending or self.animating or self.mode~="Picker" then return end
 self.selection:Reconcile(self.app.state.mergeOptions)
 if not self.selection:Add(self.app.state.mergeOptions,key,self.activeSlot or 1) then self:Render(true);return end
 self.app.audio:Play("Click");self.mode="Main";self.notice=nil;self.main.CanvasPosition=Vector2.zero
 self:Render(true)
 Theme.Motion:Pop(self.slots[self.activeSlot].art,1.08)
 local focus=self.action
 for i=1,3 do if not self.selection.slots[i] then focus=self.slots[i].action;break end end
 self:Focus(focus)
end

function Browser:RenderSlots()
 local recipe=self.selection:Recipe(self.app.state.mergeOptions)
 self.recipe=recipe
 for i,slot in self.slots do
  local filled=self.selection.slots[i]~=nil and recipe~=nil
  local artKey=if filled then recipe.species else ""
  if slot.artKey~=artKey then
   if slot.portrait then slot.portrait:Destroy();slot.portrait=nil end
   if filled then slot.portrait=preview(self.app,slot.art,recipe) end
   slot.artKey=artKey
  end
  slot.title.Text=if filled then Catalog[recipe.species].name else ""
  slot.empty.Visible=false;slot.action.Text=if filled then "Remove" else "+\nAdd"
  local pet=if filled then self.app:Pet(self.selection.slots[i]) else nil
  slot.level.Text=if pet and pet.giantSize then string.format("Lv. %d · %.1f studs",pet.level,pet.giantSize) elseif filled then "Lv. "..recipe.level else ""
  slot.outline.Color=LINE
  local tint=if filled then PURPLE else PIPE_IDLE
  Theme.Motion:Tween(slot.stem,"fusePath",{BackgroundColor3=tint},0.18)
  Theme.Motion:Tween(slot.path,"fusePath",{BackgroundColor3=tint},0.18)
  Theme.Motion:Tween(slot.socket,"fusePath",{BackgroundColor3=tint},0.18)
  Theme.Motion:Tween(slot.outputSocket,"fusePath",{BackgroundColor3=tint},0.18)
 end
 local artKey=if recipe then recipe.species else ""
 if self.resultArtKey~=artKey then
  if self.resultPortrait then self.resultPortrait:Destroy();self.resultPortrait=nil end
  if recipe then self.resultPortrait=preview(self.app,self.resultArt,recipe) end
  self.resultArtKey=artKey
 end
 self.resultEmpty.Visible=recipe==nil
 self.resultOutline.Color=LINE
 self.resultTitle.Text=if recipe then Catalog[recipe.species].name else ""
 self.resultName.Text=if recipe then "Giant · Lv. "..(recipe.level+1) else ""
 local inherited=0
 for _,id in self.selection.slots do local pet=self.app:Pet(id);inherited=math.max(inherited,pet and pet.giantSize or 0) end
 local minimum,maximum=Giant.Range(if recipe then Catalog[recipe.species].rarity else "Common",inherited)
 self.tradeoff.Text=if recipe then (if minimum==maximum then Giant.Label(minimum)
  else string.format("%s size luck · %g–%g studs",Catalog[recipe.species].rarity,minimum,maximum)) else "3 chickens → 1 Giant"
 if recipe then
  local chance=Giant.ColossalChance(Catalog[recipe.species].rarity,inherited)
  if chance>0 and minimum~=maximum then self.tradeoff.Text=string.format("%g–%g studs · %g%% Colossal",minimum,maximum,chance*100) end
 end
 self.count.Text=self.selection:Count().."/3"
 self:UpdateAction()
end

function Browser:UpdateAction()
 local price=self.recipe and self.recipe.price
 local affordable=type(price)=="number" and (self.app.state.coins or 0)>=price
 local ready=not self.pending and not self.animating and self.selection:Count()==3 and self:NearStand() and affordable
 local remaining=3-self.selection:Count()
 self.action.Text=if remaining>0 then remaining.." more chicken"..(if remaining==1 then "" else "s")
  elseif not self:NearStand() then "Move closer"
  elseif type(price)~="number" then "Updating price…"
  elseif not affordable then "Need $"..Theme.Money(price-(self.app.state.coins or 0)).." more"
  else "Fuse · $"..Theme.Money(price)
 self.action.Active,self.action.Selectable=ready==true,ready==true
 Theme.ApplyReferenceAccent(self.action,if ready then ACCENT else ColorSequence.new(Color3.fromRGB(50,24,66),Color3.fromRGB(37,17,49)))
 self.action.Visual.Face.InsetHighlight.UIStroke.Color=if ready then Color3.fromRGB(224,167,255) else LINE
 self.action.Visual.Caption.TextColor3=if ready then WHITE else MUTED
end

function Browser:RenderPicker()
 local available={}
 local parts={self.query,tostring(self.app.panelWidth),tostring(self.selection.key)}
 for _,recipe in self.app.state.mergeOptions or {} do
  local ids=self.selection:Available(recipe)
  if #ids>0 and string.find(string.lower(Catalog[recipe.species].name),self.query,1,true) then
   table.insert(available,{recipe=recipe,count=#ids})
   table.insert(parts,recipe.key..":"..table.concat(ids,","))
  end
 end
 local key=table.concat(parts,"|")
 if key~=self.key then
  self.key=key
  for _,card in self.cards do card:Destroy() end;table.clear(self.cards)
  for index,entry in available do
   local recipe=entry.recipe
   local card=Instance.new("TextButton")
   card.Name,card.Text,card.BackgroundTransparency,card.BorderSizePixel="Chicken_"..recipe.key,"",0,0
   card.AutoButtonColor,card.LayoutOrder,card.ZIndex,card.Parent=false,index,self.grid.ZIndex+1,self.grid
   card.BackgroundColor3=INK
   local rarity=Catalog[recipe.species].rarity
   local tint=Theme.Rarities[rarity] or Theme.Rarities.Common
   Theme.Stroke(card,tint,2)
   local ribbon=frame(card,"RarityRibbon",tint)
   ribbon.Position,ribbon.Size=UDim2.fromOffset(6,6),UDim2.new(1,-58,0,28)
   local rarityLabel=label(ribbon,"Rarity",string.upper(rarity),20)
   rarityLabel.Size=UDim2.fromScale(1,1);fitText(rarityLabel,20,12)
   local art=self.app:Preview(card,recipe,UDim2.new(1,12,1,-40),UDim2.fromOffset(-6,18));art.ZIndex=card.ZIndex+1
   local count=label(card,"Count","×"..entry.count,28);count.TextXAlignment=Enum.TextXAlignment.Right
   count.Position,count.Size=UDim2.new(1,-50,0,4),UDim2.fromOffset(44,30)
   local title=label(card,"Name",Catalog[recipe.species].name,24);fitText(title,24,14)
   title.Position,title.Size=UDim2.new(0,2,1,-56),UDim2.new(1,-4,0,30)
   local level=label(card,"Level","Lv. "..recipe.level..(if recipe.stars>1 then " · "..recipe.stars.."★" else ""),20)
   level.Position,level.Size=UDim2.new(0,2,1,-26),UDim2.new(1,-4,0,24)
   card.Activated:Connect(function() self:Choose(recipe.key) end)
   table.insert(self.cards,card)
  end
 end
 local empty=#available==0
 self.empty.Visible,self.hint.Visible,self.emptyIcon.Visible=empty,empty,empty
 self.empty.Text=if self.query~="" then "No matches" else "No matching trio yet"
 self.hint.Text=if self.query~="" then "Try another name." else "Collect 3 matching chickens."
 self.back.Text=if empty and self.query~="" then "Clear search" else "Back"
end

function Browser:Render(force)
 if not self.app.state then return end
 if not self.pending and not self.animating and self.selection:Reconcile(self.app.state.mergeOptions) then
  self.notice="Your flock changed. Choose available chickens.";self.key=""
 end
 if self.pending then self.mode="Processing" end
 local recipe=self.selection:Recipe(self.app.state.mergeOptions)
 self.costNotice=if recipe and recipe.price and self.selection:Count()==3 and (self.app.state.coins or 0)<recipe.price
  then "Fusion cost: $"..Theme.Money(recipe.price) else nil
 self:Resize()
 self.main.Visible,self.action.Visible=self.mode=="Main",self.mode=="Main"
 self.tradeoff.Visible=self.mode=="Main" and self.selection:Count()==3
 self.picker.Visible=self.mode=="Picker"
 self.summary.Visible,self.done.Visible=self.mode=="Result",self.mode=="Result"
 self.processing.Visible=self.mode=="Processing"
 self.message.Text=self.notice or self.costNotice or "";self.message.Visible=self.mode=="Main" and self.message.Text~=""
 self.title.Text=if self.mode=="Picker" then "Choose Chicken" elseif self.mode=="Result" then "Fusion Complete!"
  else "Fuse Chickens"
 if self.mode=="Main" then self:RenderSlots()
 elseif self.mode=="Picker" then self:RenderPicker()
 elseif self.mode=="Processing" then
  self.processingText.Text=if self.pending and self.pending.checking then "Checking your flock…" else "Fusing…"
  self.processingHint.Text=if self.pending and self.pending.checking then "You can close this while we check." else ""
 end
 self.root:SetAttribute("FusePhase",self.mode)
end

function Browser:Merge()
 if self.pending or self.animating or self.mode~="Main" or not self:NearStand() then return end
 local payload=self.selection:Payload(self.app.state.mergeOptions,self.app.state.plotIndex)
 local recipe=self.selection:Recipe(self.app.state.mergeOptions)
 if not payload or not recipe then self:Render(true);return end
 if type(recipe.price)~="number" or (self.app.state.coins or 0)<recipe.price then self:Render(true);return end
 self.app.audio:Play("Click")
 self.pending={id=self.app:Request("Merge",payload),payload=payload,recipe=table.clone(recipe),viewSerial=self.viewSerial}
 local pending=self.pending
 self.mode="Processing";self.notice=nil
 if self.presentation then self.presentation:Destroy() end
 self.presentation=Presentation.new(self.app,self.processingArt,recipe)
 self.presentation:Waiting()
 self:Render(true)
 task.delay(12,function()
  if not self.alive or self.pending~=pending then return end
  pending.checking=true;pending.syncId=self.app:Request("Sync")
  if self.root.Visible then self:Render(true) end
 end)
end

function Browser:ShowResult(chicken,recipe)
 self.completed=chicken;self.selection:Clear();self.notice=nil
 if self.summaryPortrait then self.summaryPortrait:Destroy() end
 self.summaryPortrait=preview(self.app,self.summaryArt,chicken)
 self.summaryName.Text=Catalog[chicken.species].name
 self.summaryLevel.Text=(if chicken.giantSize then Giant.Label(chicken.giantSize).." · " else "").."Lv. "..chicken.level
 self.summaryEggs.Text=Theme.Number(chicken.eggsPerSecond or recipe.afterEggRate).." eggs/s"
 self.summaryDps.Text=Theme.Number(recipe.afterDps).." DPS"
 self.mode="Result";self.animating=false;self:Render(true)
 Theme.Motion:Pop(self.summaryArt,1.08);self:Focus(self.done)
end

function Browser:Receive(result)
 local pending=self.pending
 if not pending or not result or (result.id~=pending.id and result.id~=pending.syncId) then return end
 local chicken=nil
 if result.ok then chicken=Selection.Result(self.app.state.pets,pending.payload,pending.recipe.species) end
 if result.id==pending.syncId and not result.ok then return end
 self.pending=nil;self.key="";self.selection:Clear()
 local visible=self.alive and pending.viewSerial==self.viewSerial and self.app.panel.Visible
  and not self.app.panelClosing and self.app.page=="Merge"
 if not visible then
  if self.presentation then self.presentation:Destroy();self.presentation=nil end
  self.mode="Main";return
 end
 if chicken then
  -- The confirmed result is revealed by the world machine. Clear the popup and
  -- its waiting presentation through the normal close/focus cleanup path.
  self.app:ClosePanel()
  return
 else
  if self.presentation then self.presentation:Destroy();self.presentation=nil end
  self.notice=if result.ok then "Fusion was not completed. Choose your chickens again." else (result.message or "Your flock changed. Choose available chickens.")
  self.mode="Main"
 end
 self:Render(true)
end

function Browser:Close()
 self.viewSerial+=1;self.animating=false;self.selection:Clear();self.recipe=nil;self.key="";self.notice=nil
 if self.presentation then self.presentation:Destroy();self.presentation=nil end
 self.mode="Main";self.completed=nil
end
function Browser:Reset()
 self:Close();self.search.Text="";self.query="";self.main.CanvasPosition=Vector2.zero
 self.grid.CanvasPosition=Vector2.zero
 -- Closing a popup never cancels its request. A reopened popup follows that request.
 if self.pending then
  self.pending.viewSerial=self.viewSerial;self.mode="Processing"
  if self.pending.checking then self.pending.syncId=self.app:Request("Sync") end
  self.presentation=Presentation.new(self.app,self.processingArt,self.pending.recipe);self.presentation:Waiting()
 end
end
function Browser:Destroy()
 self.alive=false;self:Close()
 for _,connection in self.connections do connection:Disconnect() end
 self.root:Destroy()
end
return Browser
