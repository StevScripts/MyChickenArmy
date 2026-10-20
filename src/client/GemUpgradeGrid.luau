--!strict
-- October 20 overhaul (S8): the Rebirth screen's Gem Upgrades panel, copied 1:1
-- from the owner's reference (Drop a Fruit's Rebirth "Upgrades!" panel) in the
-- game's style. As in the reference, the title row and Gems balance scroll away
-- with two columns of studded cards: "Roll Speed [1/5]", the next level's effect,
-- the Gem price and the icon; locked rows say which Rebirth opens them. The server
-- owns levels, prices and status (state.gemUpgrades,
-- docs/team/OVERHAUL_CONTRACT_20261020.md §6 and §8); names and icons come from
-- the shared GemUpgradeCatalog. RebirthPanel builds this in its right-hand inset.
local Theme=require(script.Parent.UITheme)
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
-- S7 ships GemUpgradeCatalog with the economy core; without it cards use the snapshot.
local catalogModule=Shared:FindFirstChild("GemUpgradeCatalog")
local Catalog:any=if catalogModule then (require::any)(catalogModule) else nil
local Grid={}
Grid.__index=Grid

local WHITE,BLACK=Color3.new(1,1,1),Color3.new(0,0,0)
local GOLD=Color3.fromRGB(255,214,0)
local SHORT=Color3.fromRGB(255,120,132)
local LOCKED_TOP,LOCKED_BOTTOM=Color3.fromRGB(35,42,36),Color3.fromRGB(18,22,18)
local ON_TOP,ON_BOTTOM=Color3.fromRGB(176,255,1),Color3.fromRGB(23,223,0)
local OFF_TOP,OFF_BOTTOM=Color3.fromRGB(255,82,104),Color3.fromRGB(219,18,57)
local C=Theme.GemColors
-- Mock pixels of the 945 x 685 panel and its 430 x 153 cards (plan v2 element spec).
local PANEL_W=945
local CARD_X,CARD_W,CARD_H={27,483},430,153
local CARDS_TOP,ROW_PITCH,BOTTOM=97,178,14
-- After it is bought, Auto Rebirth's card is the On/Off switch (gemUpgrades.autoRebirth).
local TOGGLE_ID="AutoRebirth"
local PENDING_SECONDS=10

local function rect(item,x,y,w,h,width,height)
	item.Position,item.Size=UDim2.fromScale(x/width,y/height),UDim2.fromScale(w/width,h/height)
	return item
end

local function text(parent,name,value,size,color,align)
	local label=Theme.Label(parent,name,value,size,color)
	label.TextScaled,label.TextXAlignment,label.ZIndex=true,align or Enum.TextXAlignment.Left,6
	return label
end

-- "RollSpeed" -> "Roll Speed" when neither the catalog nor the snapshot names it.
local function spaced(id: string): string
	return (id:gsub("(%l)(%u)","%1 %2"))
end

function Grid.new(app,parent,frameAspect: number)
	local self=setmetatable({app=app,cards={},pending={},alive=true,frameAspect=frameAspect,gems=0},Grid)
	local scroll=Instance.new("ScrollingFrame")
	scroll.Name,scroll.Size="GemUpgrades",UDim2.fromScale(1,1)
	scroll.BackgroundTransparency,scroll.BorderSizePixel,scroll.ZIndex=1,0,2
	scroll.ScrollBarThickness,scroll.ScrollBarImageColor3,scroll.ScrollBarImageTransparency=8,WHITE,0.62
	scroll.VerticalScrollBarInset,scroll.ScrollingDirection=Enum.ScrollBarInset.None,Enum.ScrollingDirection.Y
	scroll.AutomaticCanvasSize,scroll.CanvasSize,scroll.Selectable=Enum.AutomaticSize.None,UDim2.new(),false
	-- Cards keep their own colours; ApplyPopupStyle would darken them.
	scroll:SetAttribute("OwnsPopupStyle",true)
	scroll.Parent=parent
	self.scroll=scroll
	return self
end

-- One card per upgrade, placed by its catalog row and column. Rebuilt only when
-- the list of ids changes.
function Grid:Build(order: {string},items)
	if self.content then self.content:Destroy() end
	table.clear(self.cards)
	local places,rows={},1
	for index,id in order do
		local item=items[id]
		local definition=Catalog and Catalog.Upgrades[id]
		local row=tonumber(item and item.row) or tonumber(definition and definition.row) or math.ceil(index/2)
		local column=tonumber(item and item.column) or tonumber(definition and definition.column) or (index-1)%2+1
		places[id]={row=math.max(1,row),column=math.clamp(column,1,2)}
		rows=math.max(rows,places[id].row)
	end
	local height=CARDS_TOP+(rows-1)*ROW_PITCH+CARD_H+BOTTOM
	-- The canvas keeps the content at its designed aspect, so cards never stretch.
	self.scroll.CanvasSize=UDim2.fromScale(0,self.frameAspect*height/PANEL_W)
	local content=Theme.Container(self.scroll,"Content")
	Theme.Aspect(content,PANEL_W/height)
	self.content=content
	rect(text(content,"Title","Gem Upgrades",52,WHITE,Enum.TextXAlignment.Center),0,10,PANEL_W,62,PANEL_W,height)
	local balance=rect(Theme.Container(content,"Balance"),737,14,190,56,PANEL_W,height)
	self.balance=text(balance,"Amount","0",46,C.Number,Enum.TextXAlignment.Right)
	self.balance.Size=UDim2.fromScale(0.72,1)
	Theme.Aspect(Theme.GemIcon(balance,"Gem","Gems",UDim2.fromScale(0.25,1),UDim2.fromScale(0.75,0)),1)
	local divider=rect(Theme.Frame(content,"Divider",UDim2.new(),WHITE),27,78,886,4,PANEL_W,height)
	divider.BackgroundTransparency=0.8
	for _,id in order do
		local place=places[id]
		self.cards[id]=self:Card(content,id,CARD_X[place.column],CARDS_TOP+(place.row-1)*ROW_PITCH,height)
	end
	Theme.ScaleText(content)
end

function Grid:Card(parent,id: string,x: number,y: number,height: number)
	local button=Instance.new("TextButton")
	button.Name,button.Text,button.TextTransparency=id,"",1
	button.AutoButtonColor,button.BackgroundTransparency,button.BorderSizePixel,button.Selectable=false,1,0,true
	rect(button,x,y,CARD_W,CARD_H,PANEL_W,height)
	button.Parent=parent
	local visual=Theme.Frame(button,"Visual",UDim2.fromScale(1,1),WHITE)
	visual.AnchorPoint,visual.Position,visual.ClipsDescendants=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),true
	local outline=Theme.Stroke(visual,BLACK,3)
	-- Small, subtle studs like the Daily cards (about 15 across).
	local studs=Theme.Studs(visual,0.07,28,0)
	studs:SetAttribute("StudScaleWidth",1.6)
	local rimFrame=rect(Theme.Container(visual,"InsetHighlight"),4,4,422,145,CARD_W,CARD_H)
	rimFrame.ZIndex=3
	local rim=Theme.Stroke(rimFrame,WHITE,1)
	rim.Transparency=0.46
	local title=rect(text(visual,"Title","",31,WHITE),16,8,402,38,CARD_W,CARD_H)
	title.TextWrapped=false
	local effect=rect(text(visual,"Effect","",23,C.Effect),16,48,280,50,CARD_W,CARD_H)
	effect.TextYAlignment=Enum.TextYAlignment.Top
	local price=rect(Theme.Container(visual,"Price"),16,104,220,40,CARD_W,CARD_H)
	price.ZIndex=6
	local gem=Theme.GemIcon(price,"Gem","Gems",UDim2.fromScale(0.2,1))
	Theme.Aspect(gem,1)
	local amount=text(price,"Amount","",33,WHITE)
	local toggle=rect(Theme.Frame(visual,"Toggle",UDim2.new(),WHITE),16,104,150,40,CARD_W,CARD_H)
	toggle.ZIndex,toggle.Visible=6,false
	Theme.Stroke(toggle,BLACK,2)
	local toggleText=text(toggle,"State","ON",28,WHITE,Enum.TextXAlignment.Center)
	toggleText.Size=UDim2.fromScale(1,1)
	local definition=Catalog and Catalog.Upgrades[id]
	local icon=rect(Theme.GemIcon(visual,"Icon",if definition then definition.icon else id,UDim2.new()),306,20,112,112,CARD_W,CARD_H)
	icon.ZIndex=5
	Theme.Aspect(icon,1)
	local lock=rect(Theme.Image(visual,"Lock",Theme.Assets.Padlock,UDim2.new()),306,20,112,112,CARD_W,CARD_H)
	lock.ZIndex,lock.Visible=5,false
	Theme.Aspect(lock,1)
	local view={id=id,button=button,visual=visual,outline=outline,studs=studs,title=title,effect=effect,
		price=price,gem=gem,amount=amount,toggle=toggle,toggleText=toggleText,icon=icon,lock=lock}
	-- Hover grows the card and brightens its rim, like the reference's hovered card.
	Theme.Motion:BindButton(button,visual,visual,rim)
	button.Activated:Connect(function() self:Press(id) end)
	return view
end

function Grid:Paint(view,item,rank: number,auto)
	local id=view.id
	local definition=Catalog and Catalog.Upgrades[id]
	local name=(definition and definition.name) or (item and item.name) or spaced(id)
	local level=tonumber(item and item.level) or (definition and definition.startLevel) or 0
	local maxLevel=tonumber(item and item.maxLevel) or (definition and definition.maxLevel) or 1
	local unlockRank=tonumber(item and item.unlockRank) or (definition and definition.unlockRank) or 0
	local status=if item then item.status elseif rank<unlockRank then "Locked" else nil
	local toggle=id==TOGGLE_ID and type(auto)=="table" and auto.owned==true
	view.item,view.status,view.unlockRank,view.isToggle=item,status,unlockRank,toggle
	view.toggleOn=toggle and auto.enabled==true
	if status=="Locked" then
		-- The reference's locked card: "Locked!", the Rebirth that opens it and a padlock.
		Theme.Gradient(view.visual,LOCKED_TOP,LOCKED_BOTTOM)
		view.studs.ImageTransparency,view.outline.Color=0.91,BLACK
		view.title.RichText,view.title.Text=false,"Locked!"
		rect(view.title,16,26,280,44,CARD_W,CARD_H)
		view.effect.Text,view.effect.TextColor3="Rebirth "..unlockRank.." needed",C.LockedText
		rect(view.effect,16,74,280,52,CARD_W,CARD_H)
		view.price.Visible,view.toggle.Visible,view.icon.Visible,view.lock.Visible=false,false,false,true
		return
	end
	Theme.Gradient(view.visual,C.Top,C.Bottom)
	view.studs.ImageTransparency=0.88
	view.title.RichText=true
	view.title.Text=string.format('%s <font color="#%s">[%d/%d]</font>',name,C.Level:ToHex(),math.floor(level),math.floor(maxLevel))
	rect(view.title,16,8,402,38,CARD_W,CARD_H)
	view.effect.TextColor3=C.Effect
	view.effect.Text=if toggle then "Rebirths for you when you have enough Coins"
		else (item and item.text) or (Catalog and Catalog.Text and Catalog.Text(id,level)) or ""
	rect(view.effect,16,48,280,50,CARD_W,CARD_H)
	view.icon.Visible,view.lock.Visible=true,false
	local maxed=status=="Maxed" and not toggle
	view.outline.Color=if maxed then GOLD else BLACK
	view.toggle.Visible,view.price.Visible=toggle,not toggle
	if toggle then
		local on=auto.enabled==true
		view.toggleText.Text=if on then "ON" else "OFF"
		Theme.Gradient(view.toggle,if on then ON_TOP else OFF_TOP,if on then ON_BOTTOM else OFF_BOTTOM)
	elseif maxed then
		view.gem.Visible=false
		view.amount.Position,view.amount.Size=UDim2.new(),UDim2.fromScale(1,1)
		view.amount.Text,view.amount.TextColor3="MAX",GOLD
	else
		view.gem.Visible=true
		view.amount.Position,view.amount.Size=UDim2.fromScale(0.23,0),UDim2.fromScale(0.77,1)
		local price=tonumber(item and item.price)
		view.amount.Text=if price then Theme.Money(price) else "…"
		-- Short on Gems: the price turns red (a tap says how many are missing).
		view.amount.TextColor3=if status=="Unaffordable" then SHORT else WHITE
	end
end

function Grid:Hold(id: string,requestId)
	self.pending[id]=requestId
	task.delay(PENDING_SECONDS,function()
		if self.pending[id]==requestId then self.pending[id]=nil end
	end)
end

function Grid:Press(id: string)
	local view=self.cards[id]
	if not view or not self.alive then return end
	local app=self.app
	if view.status=="Locked" then
		app:Notify("Reach Rebirth "..view.unlockRank.." to unlock","info")
		Theme.Motion:Shake(view.visual,4)
		return
	end
	if self.pending[id] then return end
	if view.isToggle then
		local requestId=app:Request("SetAutoRebirth",{enabled=not view.toggleOn})
		if requestId then self:Hold(id,requestId) end
		Theme.Motion:PopScale(view.toggle,1.12)
		return
	end
	local item=view.item
	local price=tonumber(item and item.price)
	if view.status=="Unaffordable" and price then
		local need=math.max(1,price-self.gems)
		app:Notify("Need "..Theme.Money(need).." more "..(if need==1 then "Gem" else "Gems"),false)
		Theme.Motion:Shake(view.price,4)
		return
	end
	if view.status~="Available" or not price then Theme.Motion:Shake(view.visual,4);return end
	local requestId=app:Request("BuyGemUpgrade",{upgradeId=id,expectedLevel=tonumber(item.level) or 0,expectedPrice=price})
	if not requestId then return end
	self:Hold(id,requestId)
	Theme.Motion:PopScale(view.visual,1.06)
end

function Grid:Receive(result)
	if type(result)~="table" or (result.action~="BuyGemUpgrade" and result.action~="SetAutoRebirth") then return end
	for id,requestId in self.pending do
		if requestId==result.id then
			self.pending[id]=nil
			local view=self.cards[id]
			if view and result.ok then
				if result.action=="BuyGemUpgrade" then self.app.audio:Play("UIPurchase",nil,{noFallback=true}) end
				Theme.Motion:Shine(view.visual)
			elseif view then Theme.Motion:Shake(view.visual,4) end
		end
	end
end

function Grid:Render(state)
	if not self.alive or type(state)~="table" then return end
	local data=state.gemUpgrades
	local items=if type(data)=="table" and type(data.items)=="table" then data.items else {}
	local order=if type(data)=="table" and type(data.order)=="table" then data.order
		elseif Catalog then Catalog.Order else {}
	local signature=table.concat(order,",")
	if signature~=self.signature or not self.content then
		self.signature=signature
		self:Build(order,items)
	end
	local gems=math.max(0,math.floor(tonumber(state.gems) or 0))
	self.gems=gems
	Theme.Motion:Count(self.balance,gems,function(value) return Theme.Money(value) end,0.5)
	local rank=tonumber(type(state.rebirth)=="table" and state.rebirth.rank) or 0
	local auto=if type(data)=="table" then data.autoRebirth else nil
	for _,id in order do
		local view=self.cards[id]
		if view then self:Paint(view,items[id],rank,auto) end
	end
end

function Grid:Destroy()
	self.alive=false
	table.clear(self.pending)
	self.scroll:Destroy()
end

return Grid
