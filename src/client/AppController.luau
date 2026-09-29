--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Shared = ReplicatedStorage:WaitForChild("PetRoll"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Catalog = require(Shared.PetCatalog)
local Rules = require(Shared.Rules)
local ChickenPreview = require(script.Parent.ChickenPreview)
local Theme = require(script.Parent.UITheme)
local AudioController = require(script.Parent.AudioController)
local ActionFeedback = require(script.Parent.ActionFeedback)
local EggController = require(script.Parent.EggController)
local EggFeedback = require(script.Parent.EggFeedback)
local HudController = require(script.Parent.HudController)
local PromptStyleController = require(script.Parent.PromptStyleController)
local ProgressionBrowser = require(script.Parent.ProgressionBrowser)
local UpgradeBoardController = require(script.Parent.UpgradeBoardController)
local EggProcessorController = require(script.Parent.EggProcessorController)
local OfflineCashController = require(script.Parent.OfflineCashController)
local ChickenBrowser = require(script.Parent.ChickenBrowser)
local MergeBrowser = if Config.Features.Merging then require(script.Parent.MergeBrowser) else nil
local ShopBrowser = require(script.Parent.ShopBrowser)
local IndexBrowser = require(script.Parent.IndexBrowser)
local CommerceController = require(script.Parent.CommerceController)
local BaseController = require(script.Parent.BaseController)
local BattleController = require(script.Parent.BattleController)
local DuckAnimator = require(script.Parent.DuckAnimator)
local AppController = {}
AppController.__index = AppController
local C = Theme.Colors
local DESKTOP_POPUP_SIZE = 0.873

function AppController.new()
	local self = setmetatable({connections = {}, requestId = 0, page = "Army", selected = nil,
		confirm = nil, panelKey = "", reducedMotion = false, toastSerial = 0, alive = true,
		recruitIntents = {}, recruitReceipts = {}, productionRequests = {}, productionReceipts = {}}, AppController)
	self.audio = AudioController.new()
	self.feedback = ActionFeedback.new(self)
	self.eggs = EggController.new(self)
	self.commerce = CommerceController.new(self)
	self.progression=ProgressionBrowser.new(self)
	self.upgradeBoard=UpgradeBoardController.new(self)
	self.eggBoard=EggProcessorController.new(self)
	self.offlineCash=OfflineCashController.new(self)
	self.base, self.battle = BaseController.new(self), BattleController.new(self)
	return self
end

function AppController:Request(action, payload)
	if not Config.Features.Merging and (action=="OpenMerge" or action=="Merge" or action=="MergeAll") then return nil end
	self.requestId += 1
	local request = payload or {}
	request.action, request.id = action, self.requestId
	local productionKey=if action=="Income" then "EggValue" elseif action=="BoardUpgrade" then request.upgradeKey else nil
	if productionKey=="EggValue" or productionKey=="EggSpeed" then
		local offer=self.state and self.state.boardUpgrades and self.state.boardUpgrades[productionKey]
		if offer then
			-- Keep the displayed server offer with this request; the reply has no upgrade key.
			self.productionRequests[request.id]={key=productionKey,level=offer.level,currentText=offer.currentText,
				expiresAt=os.clock()+30}
		end
	end
	self.remotes.RequestAction:FireServer(request)
	return self.requestId
end


function AppController:NoticePosition()
	-- Menu feedback sits over the dimmed HUD, away from purchase controls.
	local height=self.gui.AbsoluteSize.Y
	local noticeHeight=self.toastFrame.Size.Y.Scale*height+self.toastFrame.Size.Y.Offset
	local top=math.max(if self.panel.Visible then 82 else height*0.24,noticeHeight+12)
	return UDim2.new(0.5,0,0,top)
end

function AppController:SizeNotice()
	local available=self.gui.AbsoluteSize
	if available.X<=0 or available.Y<=0 then return end
	local width=math.max(48,math.min(720,available.X-24))
	local compact=available.X<700 or available.Y<500
	local outline=if compact then 2.5 else 3
	self.toast:SetAttribute("OutlineThickness",outline)
	self.toast.TextSize=if compact then 28 else 34
	self.toast.TextOutline.Thickness=outline
	local bounds=TextService:GetTextSize(self.toast:GetAttribute("PlainText") or "",self.toast.TextSize,
		self.toast.Font,Vector2.new(width-24,10000))
	-- Wrap naturally instead of shrinking text or clipping two-line receipts.
	self.toastFrame.Size=UDim2.fromScale(width/available.X,math.max(52,bounds.Y+24)/available.Y)
end

function AppController:Notify(text, ok)
	if not text or text == "" then return end
	local kind=if type(ok)=="string" and Theme.NotificationStyles[ok] then ok
		elseif ok==false then "error" elseif ok==true then "success" else "info"
	if kind=="error" then
		self.audio:Play("Error",nil,{voiceKey="ErrorNotification",cooldown=0.25})
	end
	local repeated=self.toastFrame.Visible and self.noticeText==text and self.noticeKind==kind
	self.noticeText,self.noticeKind=text,kind
	self.toastSerial += 1
	local serial = self.toastSerial
	Theme.SetNotification(self.toast,text,kind)
	self:SizeNotice()
	Theme.Motion:Toast(self.toastFrame,true,self:NoticePosition(),repeated)
	if self.toastDelay then task.cancel(self.toastDelay) end
	local duration=math.clamp(#text/24+1,if kind=="error" or kind=="warning" then 5 else 4,8)
	self.toastDelay=task.delay(duration, function()
		self.toastDelay=nil
		if self.alive and serial == self.toastSerial then Theme.Motion:Toast(self.toastFrame,false) end
	end)
end

function AppController:Pet(id)
	if not self.state or not id then return nil end
	for _, pet in self.state.pets do if pet.id == id then return pet end end
	return nil
end

function AppController:TrackProductionUpgrade(result)
	if result.action~="BoardUpgrade" and result.action~="Income" then return false end
	if self.productionReceipts[result.id] then return true,false end
	local requested=self.productionRequests[result.id]
	if not requested then return false end
	self.productionRequests[result.id]=nil
	if not result.ok then return false end
	self.productionReceipts[result.id]=os.clock()+600
	local offer=self.state.boardUpgrades and self.state.boardUpgrades[requested.key]
	if not offer or offer.level~=requested.level+1 then
		self:Notify(result.message,true)
		return true,true
	end
	local name=if requested.key=="EggSpeed" then "Egg Speed" else "Egg Value"
	local benefit=if requested.key=="EggSpeed" then "Every chicken produces more eggs" else "Same value for every new egg"
	self:Notify(name..": "..requested.currentText.." → "..offer.currentText.."\n"..benefit,true)
	return true,true
end

-- Purchase classification describes selection, not a bird arriving at a battle.
-- Keep that identity independently of any encounter so late replication and a
-- later first deployment cannot drop the acknowledgement or replay an old one.
function AppController:TrackRecruit(result)
	local recruit, id = result.recruit, result.petId
	if type(recruit) ~= "table" or type(id) ~= "string"
		or (recruit.assignment ~= "Added" and recruit.assignment ~= "Replacement" and recruit.assignment ~= "Reserve") then return false end
	if self.recruitReceipts[id] then return true, false end
	local now = os.clock()
	self.recruitReceipts[id] = now + 600
	local pet = self:Pet(id)
	local definition = pet and Catalog[pet.species]
	local name = definition and definition.name or "Chicken"
	local assignment = recruit.assignment
	self.recruitIntents[id] = {petId = id, assignment = assignment, createdAt = now, expiresAt = now + 600,
		pendingBattleId = recruit.pendingBattleId, deferred = recruit.deferredUntilContestEnds == true,
		selectedOnce = assignment ~= "Reserve",
		homeAcknowledged = false, arrivalAcknowledged = false, contributionAcknowledged = false}
	local classification
	if assignment == "Reserve" then
		classification = "Reserve"
	else
		classification = if assignment == "Added" and type(recruit.selectedBefore) == "number" and type(recruit.selectedAfter) == "number"
			then "Squad " .. recruit.selectedBefore .. " → " .. recruit.selectedAfter else assignment
		if recruit.deferredUntilContestEnds then classification ..= " · joins after this contest"
		elseif recruit.pendingBattleId then classification ..= " · marching" end
	end
	-- Per-bird potential, not a promise of net home income or cash paid immediately.
	local identity=name
	if pet and type(pet.eggsPerSecond)=="number" then
		local width=math.max(1,self.toast.AbsoluteSize.X)
		identity=EggFeedback.Fit(pet.eggsPerSecond,name.." · "," eggs/s at home",width,self.toast.TextSize,false,true)
		if EggFeedback.Width(identity,self.toast.TextSize)>width then
			identity=EggFeedback.Fit(pet.eggsPerSecond,name.." · "," eggs/s",width,self.toast.TextSize,false,true)
		end
		-- Preserve identity and assignment if a very narrow viewport cannot fit the optional rate.
		if EggFeedback.Width(identity,self.toast.TextSize)>width then identity=name end
	end
	local text=identity.."\n"..classification
	self:Notify(text, true)
	self.feedback:Action("Buy")
	-- Bound presentation history independently of inventory size.
	local count, oldestId, oldest = 0, nil, math.huge
	for petId, intent in self.recruitIntents do
		count += 1
		if intent.createdAt < oldest then oldestId, oldest = petId, intent.createdAt end
	end
	if count > 24 and oldestId then self.recruitIntents[oldestId] = nil end
	return true, true
end

function AppController:StepRecruitFeedback()
	if not self.state then return end
	local now = os.clock()
	for id, expires in self.recruitReceipts do if now >= expires then self.recruitReceipts[id] = nil end end
	for id, expires in self.productionReceipts do if now >= expires then self.productionReceipts[id] = nil end end
	for id, request in self.productionRequests do if now >= request.expiresAt then self.productionRequests[id] = nil end end
	for id, intent in self.recruitIntents do
		local pet = self:Pet(id)
		if now >= intent.expiresAt or not pet then self.recruitIntents[id] = nil;continue end
		if intent.deferred then
			-- Buy confirms the active lock. BattleChanged uses another stream and
			-- may still cache the same encounter's earlier, unlocked NPC approach.
			-- Release on the state transition (or the actual new unit below), not
			-- that older snapshot. Same-ID holding can still confirm real arrival.
			if self.state.outgoing ~= intent.pendingBattleId or self.state.armyState == "Home" then intent.deferred = false end
		end
		if self:IsSelected(pet) then intent.selectedOnce = true
		elseif intent.selectedOnce then
			-- A better later roll can supersede a recruit before it arrives.
			self.recruitIntents[id] = nil;continue
		end
		if pet.home and not intent.homeAcknowledged and not intent.deferred then
			local model = self.base:HomePet(id)
			if model and model:IsA("Model") and model.PrimaryPart then
				intent.homeAcknowledged = true
				self.base:PulseModel(model, C.gold)
			end
		end
	end
end

function AppController:ObserveRecruitUnit(battle, unit, model)
	local intent = unit.petId and self.recruitIntents[unit.petId]
	local state = self.state
	if not intent or not state or state.outgoing ~= battle.id then return end
	local side = if battle.attacker == state.userId then "A" elseif battle.defender == state.userId then "B" else nil
	if not side or unit.side ~= side or not model or not model.PrimaryPart then return end
	if intent.deferred and battle.rosterLocked then return end
	if battle.phase ~= "Fight" and battle.phase ~= "Capture" and battle.phase ~= "Holding" then return end
	if (unit.hp or 0) <= 0 or unit.reinforcing or unit.retiring then return end
	local pet = self:Pet(unit.petId)
	if not pet or not self:IsSelected(pet) then return end
	intent.selectedOnce = true
	-- Both authoritative coordinates and the displayed rig must be at the site.
	local radius = battle.captureRadius or Config.CaptureRadius
	local position = model.PrimaryPart.Position
	if (unit.x - battle.x)^2 + (unit.z - battle.z)^2 > radius^2
		or (position.X - battle.x)^2 + (position.Z - battle.z)^2 > radius^2 then return end
	if intent.battleId ~= battle.id then
		intent.battleId = battle.id
		intent.pendingBattleId = nil
		intent.deferred = false
	end
	if not intent.arrivalAcknowledged then
		intent.arrivalAcknowledged = true
		self.base:PulseModel(model, C.blue)
		if os.clock() - (self.lastRecruitArrivalNotice or -10) > 1.2 then
			self.lastRecruitArrivalNotice = os.clock()
			self:Notify((Catalog[pet.species] and Catalog[pet.species].name or "Chicken") .. " joined your army", true)
		end
	end
	if not intent.contributionAcknowledged and (unit.impactSerial or 0) > 0 then
		-- This may be the first replicated view after a hit already occurred. A
		-- quiet bird emphasis confirms it; never replay that old hit or sound.
		intent.contributionAcknowledged = true
		self.base:PulseModel(model, C.gold)
		self.recruitIntents[unit.petId] = nil
	end
end

function AppController:SelectPet(id)
	self.selected, self.confirm = id, nil
	self:OpenPage("Army")
end

function AppController:OpenPage(page)
	if page=="Recruits" then page="Odds" end -- Older UI callbacks cannot reopen the removed selector.
	if page=="Sell" then page="Army" end -- Legacy navigation uses the Army inspector.
	if page=="Merge" and not self.mergeBrowser then return end
	if self.mergeBrowser and self.page=="Merge" and page~="Merge" then self.mergeBrowser:Close() end
	local switching=self.panel.Visible and not self.panelClosing
	self.panelClosing=false
	if not self.panel.Visible then self.previousSelection=GuiService.SelectedObject end
	self.page = page
	if page=="Merge" and self.mergeBrowser then self.mergeBrowser:Reset() end
	if page=="Shop" then self.commerce:Open() end
	if page=="Army" then self.chickenBrowser:OpenInventory() end
	local tint=Theme.HeaderColors[page] or Theme.ActionColors.navigation
	Theme.SetHeaderColor(self.panelHeader,tint)
	Theme.Surface(self.panel.Body,Theme.PageSurfaces[page] or C.panel)
	self.content.ScrollBarImageColor3=tint
	local icon=self.panelHeader.PageIcon
	icon.Visible=page=="Army" or page=="Upgrades" or page=="Odds" or page=="Merge" or page=="Shop" or page=="Index"
	icon.Image=if page=="Shop" then Theme.Assets.Shop elseif page=="Index" then Theme.Assets.Index
		elseif page=="Army" or page=="Merge" then Theme.Assets.Army else Theme.Assets.Luck
	self.panelTitle.Position=UDim2.fromOffset(if icon.Visible then 104 else 24,0)
	self.panelTitle.Size=UDim2.new(1,if icon.Visible then -204 else -132,1,0)
	self.panel.Visible, self.backdrop.Visible = true, true
	self:RenderPanel(true)
	Theme.Motion:OpenPanel(self.panel,self.backdrop,switching)
	if self.toastFrame.Visible then Theme.Motion:Toast(self.toastFrame,true,self:NoticePosition()) end
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=if page=="Upgrades" then self.progression.closeButton elseif page=="Merge" and self.mergeBrowser then self.mergeBrowser.closeButton else self.closeButton end
	ContextActionService:BindActionAtPriority("PetRollClosePanel",function(_,state)
		if state==Enum.UserInputState.Begin then self:ClosePanel() end
		return Enum.ContextActionResult.Sink
	end,false,2500,Enum.KeyCode.ButtonB)
end

function AppController:ClosePanel()
	if not self.panel.Visible or self.panelClosing then return end
	self.panelClosing=true
	if self.page=="Merge" and self.mergeBrowser then self.mergeBrowser:Close() end
	ContextActionService:UnbindAction("PetRollClosePanel")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.panel) then
		GuiService.SelectedObject=if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	Theme.Motion:ClosePanel(self.panel,self.backdrop,function()
		self.panelClosing=false
		if self.toastFrame.Visible then Theme.Motion:Toast(self.toastFrame,true,self:NoticePosition()) end
	end)
	self.confirm = nil
end

function AppController:TogglePage(page)
	self.audio:Play("Click")
	if self.panel.Visible and not self.panelClosing and self.page == page then self:ClosePanel() else self:OpenPage(page) end
end

function AppController:BuildUI()
	Theme.Motion:Reset()
	Theme.Motion:SetReduced(self.reducedMotion)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("PetRollGui")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.ZIndexBehavior = "PetRollGui", false, Enum.ZIndexBehavior.Sibling
	-- The backdrop covers the viewport; the HUD reserves horizontal space for Roblox controls.
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	gui.DisplayOrder, gui.Parent = 5, playerGui
	self.gui = gui
	local shell = Theme.Frame(gui,"Shell",UDim2.fromScale(1,1))
	shell.BackgroundTransparency=1
	-- Keep screen coordinates in rendered pixels; each menu owns its content layout.
	self.hud=HudController.new(self,shell)
	local backdrop=Theme.Frame(shell,"Backdrop",UDim2.fromScale(1,1),C.dark)
	backdrop.BackgroundTransparency,backdrop.Visible,backdrop.Active=0.44,false,true
	backdrop.ZIndex,self.backdrop=10,backdrop
	Theme.Round(backdrop,0)
	local panel=Theme.Frame(shell,"Panel",UDim2.fromOffset(1120,660))
	panel.BackgroundTransparency=1
	panel.AnchorPoint,panel.Position,panel.Visible=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),false
	panel.ZIndex,panel.Active,self.panel=11,true,panel
	self.panelMotionScale=Theme.Motion:Scale(panel)
	local body=Theme.Frame(panel,"Body",UDim2.new(1,0,1,-96))
	body.Position=UDim2.fromOffset(0,96)
	Theme.Surface(body)
	self.panelBody=body
	self.panelHeader,self.panelTitle=Theme.Header(panel,"Header","Your Chickens!",Theme.HeaderColors.Army)
	local close=Theme.ActionButton(self.panelHeader,"Close","X",function() self.audio:Play("Click");self:ClosePanel() end,Theme.Arcade.red)
	close.Position,close.Size,close.TextSize=UDim2.new(1,-84,0,0),UDim2.fromOffset(84,84),60
	self.closeButton=close
	local content=Instance.new("ScrollingFrame")
	content.Name,content.Position,content.Size="Content",UDim2.fromOffset(20,114),UDim2.new(1,-40,1,-134)
	content.BackgroundTransparency,content.BorderSizePixel,content.ZIndex=1,0,2
	content.ScrollBarThickness,content.ScrollBarImageColor3=6,Theme.Arcade.green
	content.VerticalScrollBarInset=Enum.ScrollBarInset.Always
	content.AutomaticCanvasSize,content.CanvasSize,content.Parent=Enum.AutomaticSize.Y,UDim2.new(),panel
	local padding=Instance.new("UIPadding")
	padding.PaddingLeft,padding.PaddingTop,padding.PaddingBottom=UDim.new(0,6),UDim.new(0,5),UDim.new(0,10)
	padding.Parent=content
	self.content=content
	local list=Instance.new("UIListLayout")
	list.Padding,list.SortOrder,list.Parent=UDim.new(0,12),Enum.SortOrder.LayoutOrder,content
	self.contentLayout=list
	self.chickenBrowser=ChickenBrowser.new(self,panel)
	self.mergeBrowser=if MergeBrowser then MergeBrowser.new(self,panel) else nil
	self.shopBrowser=ShopBrowser.new(self,panel)
	self.indexBrowser=IndexBrowser.new(self,panel)
	self.progression:Mount(panel)
	table.insert(self.connections,list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() self:FitPanel() end))
	self.toastFrame,self.toast=Theme.Notification(shell)
	local function resize()
		local available=gui.AbsoluteSize
		if available.X<=0 or available.Y<=0 then return end
		local width,height=available.X,available.Y
		self.uiScale=1
		self.panelMaxHeight=math.min(740,height-24)
		self.panelMaxWidth=math.min(1120,width-24)
		self:FitPanel()
		self.hud:Resize(width,height,1)
		self:SizeNotice()
		if self.toastFrame.Visible then Theme.Motion:Toast(self.toastFrame,true,self:NoticePosition(),true) end
		if self.state and self.panel.Visible then self:RenderPanel(true) end
	end
	table.insert(self.connections,gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))
	resize()
end

function AppController:FitPanel()
	if not self.contentLayout or not self.panelMaxHeight then return end
	local available=self.gui.AbsoluteSize
	if available.X<=0 or available.Y<=0 then return end
	-- Leave more world visible around menus; small screens keep their readable reflow.
	local popupSize=if available.X>=900 and available.Y>=550 then DESKTOP_POPUP_SIZE else 1
	local width=math.min(self.panelMaxWidth,available.X*0.94)*popupSize
	local height=math.min(self.panelMaxHeight,available.Y*0.92)*popupSize
	if self.page=="Army" then
		-- Keep the Figma window's proportions so the inspector footer fits on desktop.
		self.armyCompact=available.X<900 or available.Y<550
		if not self.armyCompact then
			local fit=math.min(1.1,(available.X-24)/1474,available.X*0.96/1474,
				(available.Y-24)/976,available.Y*0.94/976)*popupSize
			width,height=1474*fit,976*fit
		end
	elseif self.page=="Shop" then
		width=math.min(1080*popupSize,width)
	elseif self.page=="Upgrades" then
		height=math.min(660*popupSize,height)
	elseif self.page=="Merge" then
		if available.X>=900 and available.Y>=550 then
			local fit=math.min(1.1,available.X*0.94/900,available.Y*0.92/850)*popupSize
			width,height=900*fit,850*fit
		end
	elseif self.page~="Index" then
		width=math.min(760*popupSize,width)
		local motion=math.max(self.panelMotionScale.Scale,0.01)
		local contentHeight=self.contentLayout.AbsoluteContentSize.Y/motion
		height=math.min(height,math.max(300,math.ceil(contentHeight)+94))
	end
	self.panelWidth,self.panelHeight=width,height
	self.panel.Size=UDim2.fromScale(width/available.X,height/available.Y)
	-- Shared Index/Settings/Odds shell: fixed readable header, flexible scrolling body.
	self.panelHeader.Size=UDim2.new(1,0,0,60)
	self.panelHeader.PageIcon.Size,self.panelHeader.PageIcon.Position=UDim2.fromOffset(48,48),UDim2.fromOffset(8,6)
	self.panelTitle.TextSize=32
	self.panelTitle.Position=UDim2.fromOffset(if self.panelHeader.PageIcon.Visible then 64 else 16,0)
	self.panelTitle.Size=UDim2.new(1,if self.panelHeader.PageIcon.Visible then -128 else -80,1,0)
	self.closeButton.Size,self.closeButton.Position,self.closeButton.TextSize=UDim2.fromOffset(52,52),UDim2.new(1,-56,0,4),32
	self.panelBody.Position,self.panelBody.Size=UDim2.fromOffset(0,68),UDim2.new(1,0,1,-68)
	self.content.Position,self.content.Size=UDim2.fromOffset(12,80),UDim2.new(1,-24,1,-92)
	self.indexBrowser.root.Position,self.indexBrowser.root.Size=UDim2.fromOffset(12,80),UDim2.new(1,-24,1,-92)
end

function AppController:ClearPanel()
	for _, child in self.content:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	self.order = 0
end

function AppController:Text(name, text, size, height, color)
	self.order += 1
	local item = Theme.Label(self.content, name, text, math.max(18,size or 20), color)
	item.Size, item.LayoutOrder = UDim2.new(1, -8, 0, height or 28), self.order
	item.AutomaticSize=Enum.AutomaticSize.Y
	return item
end

function AppController:Button(name, text, callback, color)
	self.order += 1
	local item = Theme.Button(self.content, name, text, function() self.audio:Play("Click");callback() end, color)
	item.LayoutOrder, item.Size = self.order, UDim2.new(1, -8, 0, 48)
	return item
end

function AppController:Preview(parent, pet, size, position)
 return ChickenPreview.Create(parent,pet,size,position)
end

local function groupKey(pet)
	return pet.id -- Each chicken has its own level and upgrade action.
end

function AppController:Counts()
	local state = self.state or {}
	local count = state.count or #(state.pets or {})
	local capacity = state.capacity or Config.StartingSlots
	local selected = state.selectedCount
	if selected == nil then selected = if state.selectedIds then #state.selectedIds else math.min(count, capacity) end
	local deployed = state.deployedCount
	if deployed == nil then
		deployed = if state.deployedIds then #state.deployedIds elseif state.armyState and state.armyState ~= "Home" then state.deployed or 0 else 0
	end
	return count, state.collectionLimit or Config.CollectionLimit, capacity, selected, deployed
end

function AppController:PetIncome(pet)
	if type(pet.income) == "number" then return pet.income end
	return Rules.Income(pet.species,pet.stars or 1,pet.level,self.state.incomeLevel or 0)
end

function AppController:IsSelected(pet)
	if pet.selected ~= nil then return pet.selected == true end
	if self.state.selectedIds then return table.find(self.state.selectedIds, pet.id) ~= nil end
	return pet.slot ~= nil
end

function AppController:IsDeployed(pet)
	if pet.deployed ~= nil then return pet.deployed == true end
	if self.state.deployedIds then return table.find(self.state.deployedIds, pet.id) ~= nil end
	return self.state.armyState ~= "Home" and pet.slot ~= nil
end

function AppController:Groups()
	local groups, byKey = {}, {}
	for _, pet in self.state.pets or {} do
		local key = groupKey(pet)
		local group = byKey[key]
		if not group then
			group = {key = key, species = pet.species, stars = pet.stars, level = pet.level or 1, pets = {}, sellable = {}, ready = 0, deployed = 0, favorites = 0, income = 0}
			byKey[key] = group;table.insert(groups, group)
		end
		table.insert(group.pets, pet)
		if self:IsSelected(pet) then group.ready += 1 end
		if self:IsDeployed(pet) then group.deployed += 1 end
		if pet.canSell == true then table.insert(group.sellable, pet) end
		if pet.favorite then group.favorites += 1;group.favorite = group.favorite or pet end
		group.income += self:PetIncome(pet)
	end
	for _, group in groups do
		table.sort(group.sellable, function(a, b) return a.id < b.id end)
		group.representative = group.sellable[1] or group.favorite or group.pets[1]
		group.protected = #group.pets - #group.sellable
	end
	table.sort(groups, function(a, b)
		local ap, bp = Rules.PetPower(a.species, a.stars, a.level), Rules.PetPower(b.species, b.stars, b.level)
		if ap ~= bp then return ap > bp end
		return a.key < b.key
	end)
	return groups, byKey
end

function AppController:RenderSettings()
	self.panelTitle.Text = "Settings"
	self:Button("ToggleMusic", "Music  ·  " .. (if self.audio.musicEnabled then "ON" else "OFF"), function() self.audio:SetMusic(not self.audio.musicEnabled);self:RenderPanel(true) end)
	self:Button("ToggleEffects", "Sound effects  ·  " .. (if self.audio.sfxEnabled then "ON" else "OFF"), function() self.audio:SetEffects(not self.audio.sfxEnabled);self:RenderPanel(true) end)
	self:Button("ReducedMotion", "Reduced motion  ·  " .. (if self.reducedMotion then "ON" else "OFF"), function() self.reducedMotion = not self.reducedMotion;Theme.Motion:SetReduced(self.reducedMotion);if self.animator then self.animator:SetReducedMotion(self.reducedMotion) end;self:RenderPanel(true) end)
	self:Text("ControlsHeading", "PC CONTROLS", 13, 30, C.green)
	self:Text("Controls", "WASD move · Mouse look\nE interact · F buy\nB chickens · U upgrades · O settings · Esc close", 16, 76, C.muted)
	self:Text("SaveInfo", self.state.saveMessage or "Pets, coins and upgrades are saved between visits.", 12, 50, C.muted)
	if self.state.debugAllowed then self:Button("OpenTest", "Studio test tools  ·  F8", function() self:OpenPage("Test") end) end
end

function AppController:RenderTest()
	self.panelTitle.Text = "Studio Test Tools"
	if not self.state.debugAllowed then self:Text("Denied", "Test tools are available only to approved testers.", 14, 60);return end
	if self.confirm and self.confirm.kind == "Reset" then
		self:Text("ResetWarning", "Reset your saved test flock, coins, upgrades, camp progress and tutorial? This cannot be undone.", 14, 58, C.red)
		self:Button("ConfirmReset", "Yes, reset my test progress", function()
			self:Request("Debug", {command = "ResetProtected", argument = "RESET MY TEST SAVE"})
			self.confirm, self.selected = nil, nil
		end, Theme.ActionColors.danger)
		self:Button("CancelReset", "Keep my progress", function() self.confirm = nil;self:RenderPanel(true) end)
		return
	end
	local shop=self.state.shop
	self:Text("TestHelp", if shop and shop.testAllowed then "Disposable Studio session · test progress disappears when Play stops."
		else "Changes here affect your test progress. Use the protected reset to start a fresh playthrough.", 13, 42, C.muted)
	if shop and shop.testAllowed then
		local presetNames={Account="My account's passes",NoPasses="No paid passes",EggSpawn="2x Egg Spawn only",AllPasses="All enabled passes"}
		self:Text("PurchaseTestStatus", "PURCHASE TEST · "..(presetNames[shop.testPreset] or presetNames.Account), 14, 30, C.green)
		self:Text("PurchaseTestHelp", "Session only. Fresh starts clear test cash, chickens, upgrades and consumables. Your real purchases and save stay intact.", 13, 62, C.muted)
		self:Button("TestNoPasses", "Ignore all owned passes · keep test progress", function() self:Request("Debug",{command="TestPurchases",argument="NoPasses"}) end)
		self:Button("TestAccountPasses", "Use my account's passes again", function() self:Request("Debug",{command="TestPurchases",argument="Account"}) end)
		for _,preset in {{"Free","Fresh free player · no paid items"},{"LowRobux","Fresh low spend · 2x Egg Spawn only"},
			{"CashPack","Fresh cash pack · +10,000 cash, no passes"},{"AllPasses","Fresh all enabled passes · no cash packs"},
			{"AllItems","Fresh all items · passes + one of each cash pack"}} do
			self:Button("FreshEconomy"..preset[1],preset[2],function() self:Request("Debug",{command="FreshEconomy",argument=preset[1]}) end)
		end
	else
		self:Text("PurchaseTestUnavailable", "Purchase presets need Studio session-only mode (PetRollPlaytestSessionOnly).", 13, 46, C.muted)
	end
	local actions = {{"Coins", "+10,000 test coins"}, {"Unlock", "Clear 2 route camps + test capacity"},
		{"Pair", "Add two common chickens"}, {"FillCommon", "Replace flock with common chickens"},
		{"FillMixed", "Replace flock with varied chickens"}, {"FillReserves", "Fill flock to 40"}, {"Opponent", "Create a defended test base"},
		{"EmptyOpponent", "Create an empty test base"}, {"AwayOpponent", "Test opponent returns in 7s"},
		{"BotAttack", "Test opponent attacks my base"}, {"Seed", "Use repeatable test rolls"}}
	self:Button("DebugKnockout", "Knock out one active fighter · test 5s respawn", function() self:Request("Debug", {command="Knockout"}) end)
	for _, item in actions do self:Button("Debug" .. item[1], item[2], function() self:Request("Debug", {command = item[1]}) end) end
	for rank=1,4 do self:Button("DebugPromotion"..rank,"Test rank "..rank.." · keep territory wins",function() self:Request("Debug",{command="Promotion",argument=rank}) end) end
	for _, count in {3, 6, 10} do self:Button("DebugCapacity" .. count, "Set army capacity to " .. count, function() self:Request("Debug", {command = "Capacity", argument = count}) end) end
	for _, id in Catalog.Order do
		self:Button("DebugGrant" .. id, "Give one " .. Catalog[id].name, function() self:Request("Debug", {command = "Grant", argument = id}) end)
	end
	self:Button("DebugOfferDragon", "Put Golden Emperor on next roll", function() self:Request("Debug", {command = "Offer", argument = "Dragon"}) end)
	self:Button("DebugReset", "Reset my test progress…", function() self.confirm = {kind = "Reset"};self:RenderPanel(true) end, Theme.ActionColors.danger)
end

function AppController:RenderPanel(force)
	if not self.state or not self.panel.Visible then return end
	local browsing=self.page=="Army"
	local merging=self.page=="Merge" and self.mergeBrowser~=nil
	local shopping,indexing=self.page=="Shop",self.page=="Index"
	local upgrading=self.page=="Upgrades"
	self.progression.root.Visible=upgrading
	self.content.Visible,self.chickenBrowser.root.Visible=not browsing and not merging and not shopping and not indexing and not upgrading,browsing
	if self.mergeBrowser then self.mergeBrowser.root.Visible=merging end
	self.panelHeader.Visible,self.panelBody.Visible=not shopping and not browsing and not upgrading and not merging,not shopping and not browsing and not upgrading and not merging
	self.shopBrowser.root.Visible,self.indexBrowser.root.Visible=shopping,indexing
	if upgrading then
		self:FitPanel();self.progression:Render();return
	end
	if shopping then
		self.panelTitle.Text="Shop!";self:FitPanel();self.shopBrowser:Render(force);return
	end
	if indexing then
		self.panelTitle.Text="Chicken Index!";self:FitPanel();self.indexBrowser:Render(force);return
	end
	if merging then
		self.panelTitle.Text="Fuse Chickens"
		self:FitPanel();self.mergeBrowser:Render(force)
		return
	end
	if browsing then
		self.panelTitle.Text="Your Chickens!"
		self:FitPanel()
		self.chickenBrowser:Render(force)
		return
	end
	local state = self.state
	local keys = {self.page, tostring(self.selected), tostring(self.confirm), tostring(state.capacity), tostring(state.luck), tostring(state.incomeLevel), state.armyState, tostring(state.campsWon),tostring(state.incoming)}
	local p=state.progression
	if p then table.insert(keys,p.rank..":"..p.recruitTier..":"..tostring(p.goal)..":"..tostring(p.requirement)..":"..tostring(state.kingCleared)) end
	if self.page == "Settings" then table.insert(keys, tostring(state.saveStatus));table.insert(keys, tostring(state.saveMessage)) end
	if self.page == "Test" then
		table.insert(keys, tostring(state.shop and state.shop.testAllowed))
		table.insert(keys, tostring(state.shop and state.shop.testPreset))
	end
	local key = table.concat(keys, "|")
	if not force and key == self.panelKey then return end
	self.panelKey = key
	local scroll = self.content.CanvasPosition
	if self.renderedPage ~= self.page or self.renderedSelection ~= self.selected or self.renderedConfirm ~= self.confirm then scroll = Vector2.zero end
	self.renderedPage, self.renderedSelection, self.renderedConfirm = self.page, self.selected, self.confirm
	self:ClearPanel()
	if self.page == "Odds" then
		self.panelTitle.Text = "Roll Odds"
		for _, id in Catalog.Order do
			local chance = state.odds and state.odds[id]
			if chance and chance > 0 then self:Text("Odds"..id, Catalog[id].name.." · "..Rules.FormatOdds(chance),15,30) end
		end
	elseif self.page == "Settings" then self:RenderSettings()
	else self:RenderTest() end
	self.content.CanvasPosition = scroll
end

function AppController:Receive(packet)
	if type(packet) ~= "table" or type(packet.state) ~= "table" then return end
	local old = self.state
	self.state = packet.state
	local state = self.state
	self.eggs:Receive(state.eggs)
	if not old or old.plotIndex ~= state.plotIndex then self.base:RefreshPromptOwnership() end
	if self.selected and not self:Pet(self.selected) then
		local previous
		for _, pet in (old and old.pets) or {} do if pet.id == self.selected then previous = pet;break end end
		self.selected, self.confirm = nil, nil
		if previous then
			local _, byKey = self:Groups()
			local group = byKey[groupKey(previous)]
			if group then self.selected = group.representative.id end
		end
	end
	local result = packet.result
	if result and not self.mergeBrowser and (result.action=="OpenMerge" or result.action=="Merge" or result.action=="MergeAll") then result=nil end
	local shownRecruit, newRecruit = false, false
	local shownProduction,newProduction=false,false
	if result then shownProduction,newProduction=self:TrackProductionUpgrade(result) end
	self.chickenBrowser:Receive(result)
	if self.mergeBrowser then self.mergeBrowser:Receive(result) end
	self.commerce:Receive(result)
	self.progression:Receive(result)
	self.upgradeBoard:Receive(result)
	self.eggBoard:Receive(result)
	if result and result.action~="RefreshShop" and result.action~="PreparePurchase" then
		local shownInMerge=result.action=="OpenMerge" or ((result.action=="Merge" or result.action=="MergeAll") and self.page=="Merge" and self.panel.Visible)
  if result.ok and result.action=="Buy" then shownRecruit,newRecruit=self:TrackRecruit(result) end
  if not shownProduction and not (result.ok and (result.action=="Roll" or shownInMerge or shownRecruit)) then self:Notify(result.message,result.ok) end
		if result.ok and result.action == "Buy" and not shownRecruit then self.feedback:Action("Buy");self.base:PetPulse(result.petId, C.gold) end
		if result.ok and (result.action == "Sell" or result.action == "Promote") then self.feedback:Action(result.action) end
		if result.ok and result.action == "OpenMerge" then self:OpenPage("Merge") end
		if result.ok and (result.action == "Merge" or result.action == "MergeAll") then
			self.base:PetPulse(result.petId,C.gold)
		end
		if result.ok and (result.action == "Income" or result.action == "Luck" or result.action == "Expand")
			and (not shownProduction or newProduction) then self.feedback:Action(result.action) end
		if result.ok and result.action == "Attack" then self:ClosePanel() end
	end
	local count, limit, capacity, selectedCount, deployedCount = self:Counts()
	self.hud:Update(state, count, limit, capacity, selectedCount, deployedCount)
	self.base:UpdateObjective()
	self:StepRecruitFeedback()
	if state.banner and state.banner ~= "" and state.banner ~= self.lastBanner then self:Notify(state.banner);self.lastBanner = state.banner end
	if old and state.lastResult ~= old.lastResult and not packet.result then self:Notify(state.lastResult) end
	self:RenderPanel(old == nil)
	self.offlineCash:Receive(state)
	if result and result.ok then
		local changed=if (result.action=="Expand" or result.action=="Income" or result.action=="Luck")
			and (not shownProduction or newProduction) then self.progression.row else nil
		if changed then
			local name=if result.action=="Expand" then "Capacity" else result.action
			local card=changed:FindFirstChild(name)
			if card and card:FindFirstChild("Icon") then Theme.Motion:Pop(card.Icon,1.18) end
		end
		-- Keep reward motion local to the action, not behind notification text.
		if result.action=="Sell" then Theme.Motion:Pop(self.hud.cashIcon,1.14) end
	end
end

function AppController:Start()
	self.remotes = ReplicatedStorage.PetRoll:WaitForChild("Remotes")
	self:BuildUI()
	self.upgradeBoard:Start()
	self.eggBoard:Start()
	self.audio:Start()
	self.feedback:Start()
	self.commerce:Start()
	self.eggs:Start()
	self.animator = DuckAnimator.new()
	self.animator:SetReducedMotion(self.reducedMotion)
	self.prompts=PromptStyleController.new(self)
	self.prompts:Start()
	self.base:Start()
	self.battle:Start(self.remotes:WaitForChild("BattleChanged"))
	table.insert(self.connections, self.remotes:WaitForChild("StateChanged").OnClientEvent:Connect(function(packet) self:Receive(packet) end))
	for _, entry in {{"Army", Enum.KeyCode.B}, {"Upgrades", Enum.KeyCode.U}, {"Settings", Enum.KeyCode.O}, {"Test", Enum.KeyCode.F8}} do
		local page, key = entry[1], entry[2]
		ContextActionService:BindAction("PetRoll" .. page, function(_, inputState)
			if inputState ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
			if page == "Test" and (not self.state or not self.state.debugAllowed) then return Enum.ContextActionResult.Pass end
			self:TogglePage(page)
			return Enum.ContextActionResult.Sink
		end, false, key)
	end
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape and self.panel.Visible then self:ClosePanel() end
	end))
	self:Request("Sync")
	print("[PetRoll] My Chicken Army! client ready")
end

function AppController:Destroy()
	self.alive = false
	if self.toastDelay then task.cancel(self.toastDelay);self.toastDelay=nil end
	Theme.Motion:Reset()
	ContextActionService:UnbindAction("PetRollClosePanel")
	for _, connection in self.connections do connection:Disconnect() end
	for _, page in {"Army", "Upgrades", "Settings", "Test"} do ContextActionService:UnbindAction("PetRoll" .. page) end
	if self.animator then self.animator:Destroy() end
	if self.prompts then self.prompts:Destroy() end
	self.commerce:Destroy();self.shopBrowser:Destroy();self.indexBrowser:Destroy()
	if self.mergeBrowser then self.mergeBrowser:Destroy() end
	self.progression:Destroy()
	self.upgradeBoard:Destroy()
	self.eggBoard:Destroy()
	self.offlineCash:Destroy()
	self.eggs:Destroy();self.base:Destroy();self.battle:Destroy();self.feedback:Destroy();self.audio:Destroy()
	self.recruitIntents,self.recruitReceipts={},{}
	self.productionRequests,self.productionReceipts={},{}
	self.gui:Destroy()
end

-- Apply the shared popup skin after page-specific rendering and reused-page updates.
local renderPanelContent=AppController.RenderPanel
function AppController:RenderPanel(...)
	local results=table.pack(renderPanelContent(self,...))
	Theme.ApplyPopupStyle(self.panel)
	return table.unpack(results,1,results.n)
end

return AppController
