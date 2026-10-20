--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
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
local CommanderGuide = require(script.Parent.CommanderGuide)
local LeaderboardBoards = require(script.Parent.LeaderboardBoards)
local IntroCutscene = require(script.Parent.IntroCutscene)
local HillIntro = require(script.Parent.HillIntro)
local PromptStyleController = require(script.Parent.PromptStyleController)
local ProgressionBrowser = require(script.Parent.ProgressionBrowser)
local EggProcessorController = require(script.Parent.EggProcessorController)
local OfflineCashController = require(script.Parent.OfflineCashController)
local FreeGiftController = require(script.Parent.FreeGiftController)
local GoldRushController = require(script.Parent.GoldRushController)
local FriendBoost = require(script.Parent.FriendBoost)
local ToolController = require(script.Parent.ToolController)
local RebirthPanel = require(script.Parent.RebirthPanel)
local DailyRewardController = require(script.Parent.DailyRewardController)
local OperationsPanel = require(script.Parent.OperationsPanel)
local AutoRollMenu = require(script.Parent.AutoRollMenu)
local ChickenBrowser = require(script.Parent.ChickenBrowser)
local SellMenu = require(script.Parent.SellMenu)
local ShopBrowser = require(script.Parent.ShopBrowser)
local IndexBrowser = require(script.Parent.IndexBrowser)
local ResearchBrowser = require(script.Parent.ResearchBrowser)
local ResearchExtras = require(script.Parent.ResearchExtras)
local MissionTracker = require(script.Parent.MissionTracker)
local AdminPanel = require(script.Parent.AdminPanel)
local CommerceController = require(script.Parent.CommerceController)
local BaseController = require(script.Parent.BaseController)
local BattleController = require(script.Parent.BattleController)
local DuckAnimator = require(script.Parent.DuckAnimator)
local GalaxyCrateVisuals = require(script.Parent.GalaxyCrateVisuals)
local AppController = {}
AppController.__index = AppController
local C = Theme.Colors
local MenuLayout = require(script.Parent.MenuLayout)
-- Routine army commands confirm themselves on the HUD (status line, Army count); only failures notify.
local QUIET_SUCCESS = {SelectBest = true, SetArmy = true, CallArmy = true, GoBase = true, SetAutoRoll = true,
	-- October 20 (S8): the Rebirth screen shows these itself (card pulse, toggle, Rebirth toast).
	Rebirth = true, BuyGemUpgrade = true, SetAutoRebirth = true}

-- October 20 Flock edits confirm themselves in My Army (the strip, counts and card pops).
for _, action in {"FlockEquip", "FlockUnequip", "FlockBest"} do QUIET_SUCCESS[action] = true end

function AppController.new()
	local self = setmetatable({connections = {}, requestId = 0, page = "Army", selected = nil,
		confirm = nil, panelKey = "", reducedMotion = false, toastSerial = 0, alive = true,
		recruitIntents = {}, recruitReceipts = {}, productionRequests = {}, productionReceipts = {}, menuBlurOwners = {}}, AppController)
	self.audio = AudioController.new()
	self.feedback = ActionFeedback.new(self)
	self.eggs = EggController.new(self)
	self.commerce = CommerceController.new(self)
	self.progression=ProgressionBrowser.new(self)
	self.eggBoard=EggProcessorController.new(self)
	self.offlineCash=OfflineCashController.new(self)
	-- Launch sprint panels (docs/team/launch); foundation stubs render nothing.
	self.rebirthPanel=RebirthPanel.new(self)
	self.dailyReward=DailyRewardController.new(self)
	self.freeGift=FreeGiftController.new(self)
	self.operationsPanel=OperationsPanel.new(self)
	-- October 20 Auto Roll settings popup and hit alert (S12).
	self.autoRollMenu=AutoRollMenu.new(self)
	self.base, self.battle = BaseController.new(self), BattleController.new(self)
	return self
end

function AppController:Request(action, payload)
	self.requestId += 1
	local request = payload or {}
	request.action, request.id = action, self.requestId
	local productionKey=if action=="Income" then "EggValue" elseif action=="BoardUpgrade" or action=="CashUpgrade" then request.upgradeKey else nil
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
	if self.panel.Visible then return UDim2.fromScale(0.5,0.14) end
	-- A live Hill round's title and bar fill the top; notices sit just below them.
	local hill=self.hud and self.hud.hill and self.hud.hill.bannerVisible
	local y=if hill then 0.3 else 0.24
	-- The Commander card stays up during notices; the notice (bottom-anchored) sits below it.
	local commander=self.commander
	local card=commander and commander.root.Visible and commander.card.Visible and commander.card
	local parent=self.toastFrame.Parent
	if card and parent and parent.AbsoluteSize.Y>0 then
		local bottom=card.AbsolutePosition.Y+card.AbsoluteSize.Y-parent.AbsolutePosition.Y
		y=math.max(y,(bottom+self.toastFrame.AbsoluteSize.Y)/parent.AbsoluteSize.Y+0.012)
	end
	return UDim2.fromScale(0.5,y)
end

-- Re-place a showing notice after the layout above it changes (never revives a leaving one).
function AppController:PlaceNotice()
	if self.toastFrame and self.toastFrame.Visible and not self.noticeLeaving then
		Theme.Motion:Toast(self.toastFrame,true,self:NoticePosition(),true)
	end
end

function AppController:SizeNotice()
	self.toastFrame.Size=UDim2.fromScale(0.58,0.13)
	Theme.Aspect(self.toastFrame,9)
	Theme.ScaleText(self.toast)
end

function AppController:Notify(text, ok)
	if not text or text == "" then return end
	local kind=if type(ok)=="string" and Theme.NotificationStyles[ok] then ok
		elseif ok==false then "error" elseif ok==true then "success" else "info"
	local urgent=kind=="error" or kind=="warning"
	if not urgent and os.clock()<(self.noticeHoldUntil or 0) then
		-- An error keeps its full reading time; routine notices wait their turn.
		local queue=self.noticeQueue or {}
		self.noticeQueue=queue
		local last=queue[#queue]
		if not (last and last.text==text and last.kind==kind) then
			table.insert(queue,{text=text,kind=kind})
			if #queue>3 then table.remove(queue,1) end
		end
		return
	end
	if kind=="error" then
		self.audio:Play("Error",nil,{voiceKey="ErrorNotification",cooldown=0.25})
	end
	local repeated=self.toastFrame.Visible and self.noticeText==text and self.noticeKind==kind
	self.noticeText,self.noticeKind=text,kind
	self.toastSerial += 1
	local serial = self.toastSerial
	Theme.SetNotification(self.toast,text,kind)
	self:SizeNotice()
	self.noticeLeaving=false
	Theme.Motion:Toast(self.toastFrame,true,self:NoticePosition(),repeated)
	Theme.NotificationFlair(self.toastFrame,self.toast,kind,repeated)
	if self.toastDelay then task.cancel(self.toastDelay) end
	local duration=math.clamp(#text/24+1,if urgent then 5 else 4,8)
	self.noticeHoldUntil=if urgent then os.clock()+duration else 0
	self.toastDelay=task.delay(duration, function()
		self.toastDelay=nil
		if not self.alive or serial ~= self.toastSerial then return end
		self.noticeHoldUntil=0
		local queue=self.noticeQueue
		if queue and #queue>0 then
			local nextNotice=table.remove(queue,1)
			self:Notify(nextNotice.text,nextNotice.kind)
			return
		end
		self.noticeLeaving=true
		Theme.NotificationLeave(self.toastFrame)
	end)
end

function AppController:Pet(id)
	if not self.state or not id then return nil end
	for _, pet in self.state.pets do if pet.id == id then return pet end end
	return nil
end

function AppController:TrackProductionUpgrade(result, quiet)
	if result.action~="BoardUpgrade" and result.action~="CashUpgrade" and result.action~="Income" then return false end
	if self.productionReceipts[result.id] then return true,false end
	local requested=self.productionRequests[result.id]
	if not requested then return false end
	self.productionRequests[result.id]=nil
	if not result.ok then return false end
	self.productionReceipts[result.id]=os.clock()+600
	if quiet then return true,true end
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
			then "Army " .. recruit.selectedBefore .. " → " .. recruit.selectedAfter else assignment
		if recruit.deferredUntilContestEnds then classification ..= " · joins after this contest"
		elseif recruit.pendingBattleId then classification ..= " · marching" end
	end
	-- Per-bird potential, not a promise of net home income or cash paid immediately.
	local identity=name
	if pet and type(pet.eggsPerSecond)=="number" then
		local width=math.max(1,self.toast.AbsoluteSize.X)
		local rate=if math.floor(pet.eggsPerSecond*10+0.5)==10 then " egg/s" else " eggs/s"
		identity=EggFeedback.Fit(pet.eggsPerSecond,name.." · ",rate.." at home",width,self.toast.TextSize,false,true)
		if EggFeedback.Width(identity,self.toast.TextSize)>width then
			identity=EggFeedback.Fit(pet.eggsPerSecond,name.." · ",rate,width,self.toast.TextSize,false,true)
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
			self:Notify((Catalog[pet.species] and Catalog[pet.species].name or "Chicken") .. " joined your Army", true)
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

-- One client-owned blur shared by main pages and the separate offline receipt.
function AppController:SetMenuBlur(owner, visible)
	self.menuBlurOwners[owner] = if visible then true else nil
	if not self.alive then return end
	local target = if next(self.menuBlurOwners) then 18 else 0
	if not self.menuBlur then
		if target == 0 then return end
		local blur = Instance.new("BlurEffect")
		blur.Name, blur.Size, blur.Parent = "PetRollMenuBlur", 0, Lighting
		self.menuBlur = blur
	end
	if self.menuBlurTarget == target then return end
	self.menuBlurTarget = target
	local blur = self.menuBlur
	blur.Enabled = true
	Theme.Motion:Tween(blur,"menu-blur",{Size=target},0.24,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,function()
		if self.menuBlurTarget == 0 then blur.Enabled = false end
	end)
end

function AppController:OpenPage(page)
	if self.commerce.cratePresenting then return end
	-- October 14 Missions: no menu; sites appear on the island (MissionTracker).
	if page=="Operations" then self:Notify("Missions appear on the island by themselves. Follow the marker!","info");return end
	if page=="Upgrades" or page=="Research" then self.research:Open();return end
	if page=="Recruits" then page="Odds" end -- Older UI callbacks cannot reopen the removed selector.
	if page=="Merge" then return end -- October 20: Fuse is removed.
	-- Take the blur first so closing the other menu cannot clear it.
	self:SetMenuBlur("main",true)
	self:CloseOtherMenus("main")
	local switching=self.panel.Visible and not self.panelClosing
	self.panelClosing=false
	if not self.panel.Visible then self.previousSelection=GuiService.SelectedObject end
	self.page = page
	if page=="Shop" then self.commerce:Open() end
	if page=="Army" then self.chickenBrowser:OpenInventory() end
	local tint=Theme.HeaderColors[page] or Theme.ActionColors.navigation
	Theme.SetHeaderColor(self.panelHeader,tint)
	Theme.Surface(self.panelBody,Theme.PageSurfaces[page] or C.panel)
	self.content.ScrollBarImageColor3=tint
	local icon=self.panelHeader.PageIcon
	icon.Visible=page=="Army" or page=="Upgrades" or page=="Odds" or page=="Shop" or page=="Index"
	icon.Image=if page=="Shop" then Theme.Assets.Shop elseif page=="Index" then Theme.Assets.Index
		elseif page=="Army" then Theme.Assets.Army else Theme.Assets.Luck
	self.panel.Visible, self.backdrop.Visible = true, true
	self:FitPanel()
	self:RenderPanel(true)
	Theme.Motion:OpenPanel(self.panel,self.backdrop,switching)
	self:PlaceNotice()
	if UserInputService.GamepadEnabled then GuiService.SelectedObject=if page=="Upgrades" then self.progression.closeButton elseif page=="Sell" then self.sellMenu.sell else self.closeButton end
	ContextActionService:BindActionAtPriority("PetRollClosePanel",function(_,state)
		if state==Enum.UserInputState.Begin then self:ClosePanel() end
		return Enum.ContextActionResult.Sink
	end,false,2500,Enum.KeyCode.ButtonB)
end

-- October 20 Sell screen: My Army's Sell buttons open it; a sellable petId starts selected.
function AppController:OpenSell(petId: string?)
	if self.commerce.cratePresenting then return end
	self.sellMenu:Begin(petId)
	self:OpenPage("Sell")
end

-- One menu at a time. keep: "main" | "research" | "operations" | "rebirth" | "daily" | "freeGift" | "autoRoll".
-- Callers take their own blur (SetMenuBlur(name,true)) BEFORE calling this; each
-- closed menu releases only its own blur owner, so the shared blur stays on.
-- Safe with nothing open. The offline receipt is always dismissed (already paid).
function AppController:CloseOtherMenus(keep: string?)
	if keep~="main" then self:CloseMainPanel() end
	if keep~="research" and self.research and self.research.root.Visible then self.research:Close() end
	local operations=self.operationsPanel
	if keep~="operations" and operations and operations.gui then operations:Dismiss(true) end
	local rebirth=self.rebirthPanel
	if keep~="rebirth" and rebirth and rebirth.gui then
		-- Replaced, not closed by the player: do not reopen the Upgrades screen behind it.
		rebirth.fromResearch=false
		rebirth:Dismiss(true)
	end
	if keep~="daily" and self.dailyReward then self.dailyReward:Dismiss(true) end
	if keep~="freeGift" and self.freeGift then self.freeGift:Dismiss(true) end
	if keep~="autoRoll" and self.autoRollMenu then self.autoRollMenu:Dismiss(true) end
	if self.offlineCash then self.offlineCash:Dismiss(true) end
end

function AppController:ClosePanel()
	if self.research and self.research.root.Visible then self.research:Close();return end
	self:CloseMainPanel()
end

function AppController:CloseMainPanel()
	if not self.panel.Visible or self.panelClosing then return end
	self.panelClosing=true
	self:SetMenuBlur("main",false)
	if self.page=="Sell" then self.sellMenu:Close() end
	ContextActionService:UnbindAction("PetRollClosePanel")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.panel) then
		GuiService.SelectedObject=if self.previousSelection and self.previousSelection.Parent then self.previousSelection else nil
	end
	Theme.Motion:ClosePanel(self.panel,self.backdrop,function()
		self.panelClosing=false
		self:PlaceNotice()
	end)
	self.confirm = nil
end

function AppController:TogglePage(page)
	if self.commerce.cratePresenting then return end
	self.audio:Play("Click")
	if page=="Research" or page=="Upgrades" then
		if self.research.root.Visible then self.research:Close() else self.research:Open() end
		return
	end
	if self.panel.Visible and not self.panelClosing and self.page == page then self:ClosePanel() else self:OpenPage(page) end
end

function AppController:BuildUI()
	Theme.Motion:Reset()
	Theme.Motion:SetReduced(self.reducedMotion)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	-- Reuse the sole StarterGui template instead of adding another ScreenGui.
	local gui=playerGui:WaitForChild("PetRollGui")
	assert(gui:IsA("ScreenGui"),"PetRollGui must be a ScreenGui")
	-- The restored GUI is an Edit-mode reference, not a second live game HUD.
	local function hideReference(child)
		if child.Name=="GUI" and child:IsA("ScreenGui") then child.Enabled=false end
	end
	-- StarterGui clones can arrive after PetRollGui and this controller starts.
	table.insert(self.connections,playerGui.ChildAdded:Connect(hideReference))
	for _,child in playerGui:GetChildren() do hideReference(child) end
	local oldShell=gui:FindFirstChild("Shell")
	if oldShell then oldShell:Destroy() end
	gui.Name, gui.ResetOnSpawn, gui.ZIndexBehavior = "PetRollGui", false, Enum.ZIndexBehavior.Sibling
	-- The backdrop covers the viewport; the HUD reserves horizontal space for Roblox controls.
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.None
	gui.ClipToDeviceSafeArea = false
	gui.DisplayOrder, gui.Parent = 5, playerGui
	self.gui = gui
	local layouts=gui:FindFirstChild("MenuLayouts")
	if layouts then
		layouts.Visible=false
		for _,control in layouts:GetChildren() do
			local preview=control:FindFirstChild("Preview")
			if preview then preview:Destroy() end
		end
	end
	local shell = Theme.Container(gui,"Shell")
	-- Match Example's screen-level organization. Each layer owns one coordinate
	-- space; opening a menu cannot resize the HUD or transient notifications.
	local hudLayer=Theme.Container(shell,"HUD")
	local frames=Theme.Container(shell,"FRAMES");frames.ZIndex=10
	local other=Theme.Container(shell,"OTHER");other.ZIndex=20
	self.hudLayer,self.frames,self.other=hudLayer,frames,other
	-- Keep screen coordinates in rendered pixels; each menu owns its content layout.
	self.hud=HudController.new(self,hudLayer)
	-- The dim covers the whole device screen; panels stay in the safe area.
	local backdropLayer=Theme.InsetContainer(frames,"BackdropLayer",Enum.ScreenInsets.None)
	backdropLayer.ZIndex=10
	local backdrop=Theme.Frame(backdropLayer,"Backdrop",UDim2.fromScale(1,1),C.dark)
	backdrop.BackgroundTransparency,backdrop.Visible,backdrop.Active=1,false,true
	backdrop.ZIndex,self.backdrop=10,backdrop
	Theme.Round(backdrop,0)
	local panel=Theme.Frame(frames,"Panel",UDim2.fromScale(0.63,0.82))
	panel.BackgroundTransparency=1
	panel.AnchorPoint,panel.Position,panel.Visible=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),false
	panel.ZIndex,panel.Active,self.panel=11,true,panel
	local standardPage=Theme.Container(panel,"StandardPage")
	self.standardPage=standardPage
	local body=Theme.Frame(standardPage,"Main",UDim2.fromScale(1,0.825))
	body.Position=UDim2.fromScale(0,0.175)
	Theme.Surface(body)
	self.panelBody=body
	self.panelHeader,self.panelTitle=Theme.Header(standardPage,"Header","My Army",Theme.HeaderColors.Army)
	local close=Theme.HeaderClose(self.panelHeader,function() self.audio:Play("Click");self:ClosePanel() end)
	self.closeButton=close
	local content=Instance.new("ScrollingFrame")
	content.Name,content.Position,content.Size="Content",UDim2.fromScale(0.02,0.025),UDim2.fromScale(0.96,0.95)
	content.BackgroundTransparency,content.BorderSizePixel,content.ZIndex=1,0,2
	content.ScrollBarThickness,content.ScrollBarImageColor3=0,Theme.Arcade.green
	content.VerticalScrollBarInset=Enum.ScrollBarInset.Always
	content.AutomaticCanvasSize,content.CanvasSize,content.Parent=Enum.AutomaticSize.None,UDim2.new(),body
	local padding=Instance.new("UIPadding")
	padding.PaddingLeft,padding.PaddingTop,padding.PaddingBottom=UDim.new(0.01,0),UDim.new(0.01,0),UDim.new(0.02,0)
	padding.Parent=content
	self.content=content
	local list=Instance.new("UIListLayout")
	list.Padding,list.SortOrder,list.Parent=UDim.new(0.025,0),Enum.SortOrder.LayoutOrder,content
	self.contentLayout=list
	self.chickenBrowser=ChickenBrowser.new(self,panel)
	self.sellMenu=SellMenu.new(self,panel)
	self.shopBrowser=ShopBrowser.new(self,panel)
	self.indexBrowser=IndexBrowser.new(self,body)
	self.progression:Mount(panel)
	self.research=ResearchBrowser.new(self,frames)
	self.researchExtras=ResearchExtras.new(self)
	self.missionTracker=MissionTracker.new(self)
	self.adminPanel=AdminPanel.new(self)
	self.toastFrame,self.toast=Theme.Notification(other)
	self:FitPanel()
	self.hud:Resize()
	self:SizeNotice()
	-- The bottom HUD buttons step aside while a popup is open so they never sit on its edge.
	local function syncNavigation() self.hud.navigation.Visible=not panel.Visible end
	panel:GetPropertyChangedSignal("Visible"):Connect(syncNavigation)
	syncNavigation()
end

function AppController:FitPanel()
	MenuLayout.Apply(self.gui,self.page,self.panel)
	Theme.BelowHeader(self.panelHeader,self.panelBody)
	self.content.Position,self.content.Size=UDim2.fromScale(0.02,0.02),UDim2.fromScale(0.96,0.96)
	self.indexBrowser.root.Position,self.indexBrowser.root.Size=UDim2.fromScale(0.02,0.02),UDim2.fromScale(0.96,0.96)
	Theme.ScaleText(self.panelHeader)
end

function AppController:ClearPanel()
	for _, child in self.content:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	self.order = 0
end

function AppController:FitContentCanvas()
	-- Sum authored row proportions: automatic canvas measurement omits part of
	-- aspect-constrained content. Keep gaps at their original viewport proportion.
	local rows,count=0,0
	for _,item in self.content:GetChildren() do
		if item:IsA("GuiObject") then
			rows+=item.Size.X.Scale/item.UIAspectRatioConstraint.AspectRatio
			count+=1
		end
	end
	local padding=self.content.UIPadding
	local innerWidth=1-padding.PaddingLeft.Scale-padding.PaddingRight.Scale
	local innerHeight=1-padding.PaddingTop.Scale-padding.PaddingBottom.Scale
	local aspect=self.panel:FindFirstChildWhichIsA("UIAspectRatioConstraint") or self.panel.Parent:FindFirstChildWhichIsA("UIAspectRatioConstraint")
	local bodyAspect=aspect.AspectRatio*self.panelBody.Size.X.Scale/self.panelBody.Size.Y.Scale
	local gap=0.025*self.content.Size.Y.Scale
	local height=math.max(self.content.Size.Y.Scale,(rows*bodyAspect*self.content.Size.X.Scale*innerWidth+math.max(0,count-1)*gap)/innerHeight)
	self.content.CanvasSize=UDim2.fromScale(0,height)
	self.contentLayout.Padding=UDim.new(gap/(height*innerHeight),0)
end

function AppController:Text(name, text, size, height, color)
	self.order += 1
	local item = Theme.Label(self.content, name, text, math.max(18,size or 20), color)
	item.Size, item.LayoutOrder = UDim2.fromScale(0.96,(height or 28)/400), self.order
	item.AutomaticSize=Enum.AutomaticSize.None
	Theme.Aspect(item,500/(height or 28))
	item.UIAspectRatioConstraint.AspectType=Enum.AspectType.ScaleWithParentSize
	Theme.ScaleText(item)
	return item
end

function AppController:Button(name, text, callback, color)
	self.order += 1
	local item = Theme.Button(self.content, name, text, function() self.audio:Play("Click");callback() end, color)
	item.LayoutOrder, item.Size = self.order, UDim2.fromScale(0.96,0.14161)
	Theme.Aspect(item,12.265)
	item.UIAspectRatioConstraint.AspectType=Enum.AspectType.ScaleWithParentSize
	item.Visual.Face.StudClip.StudTexture:SetAttribute("StudScaleWidth",1.12)
	Theme.ScaleText(item)
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
		local ap, bp = Rules.PetPower(a.species, a.stars, a.level, a.giantSize), Rules.PetPower(b.species, b.stars, b.level, b.giantSize)
		if ap ~= bp then return ap > bp end
		return a.key < b.key
	end)
	return groups, byKey
end

function AppController:RenderSettings()
	local tutorial=(self.state and self.state.tutorial) or {}
	-- Only offer to resume the guide after the player actually skipped it.
	if tutorial.guideSkipped and not tutorial.guideCompleted and not tutorial.wonCamp then
		local resume=self:Button("ResumeCommander", "Resume Commander Cluck", function() self:Request("TutorialSignal",{signal="Resume"});self:ClosePanel() end)
		Theme.Aspect(resume,5.6)
		resume.UIAspectRatioConstraint.AspectType=Enum.AspectType.ScaleWithParentSize
	end
	self.panelTitle.Text = "Settings"
	-- Toggles read at a glance: green when ON, gray when OFF.
	local function toggle(name, label, on, callback)
		return self:Button(name, label .. "  ·  " .. (if on then "ON" else "OFF"), function()
			callback()
			-- The row is rebuilt with its new state; let the fresh switch land with a pop.
			local fresh=self.content:FindFirstChild(name)
			if fresh and fresh:FindFirstChild("Visual") then Theme.Motion:Pop(fresh.Visual,1.06) end
		end, if on then Theme.Arcade.green else Theme.ActionColors.disabled)
	end
	toggle("ToggleMusic", "Music", self.audio.musicEnabled, function() self.audio:SetMusic(not self.audio.musicEnabled);self:RenderPanel(true) end)
	toggle("ToggleEffects", "Sound effects", self.audio.sfxEnabled, function() self.audio:SetEffects(not self.audio.sfxEnabled);self:RenderPanel(true) end)
	toggle("ReducedMotion", "Reduced motion", self.reducedMotion, function() self.reducedMotion = not self.reducedMotion;Theme.Motion:SetReduced(self.reducedMotion);if self.animator then self.animator:SetReducedMotion(self.reducedMotion) end;if self.galaxyCrateVisuals then self.galaxyCrateVisuals:SetReducedMotion(self.reducedMotion) end;self:RenderPanel(true) end)
	-- October 20 Auto Roll (Gem Upgrade): its settings live in their own popup (S12).
	local auto=self.state.autoRoll
	if auto and auto.unlocked then
		self:Button("AutoRollSettings", "Auto Roll settings", function() self.autoRollMenu:Open() end, Theme.ActionColors.navigation)
	end
	-- After the guide, a quiet next-goal line points to the next camp until the King.
	if tutorial.guideCompleted or tutorial.wonCamp then
		local hidden=tutorial.goalsHidden==true
		toggle("ToggleGoals", "Next goal hints", not hidden, function()
			self:Request("TutorialSignal",{signal=if hidden then "ShowGoals" else "HideGoals"})
		end)
	end
	-- Testers: a disposable brand-new profile; the real save is kept and returns on rejoin.
	if self.state.newPlayerTestAllowed then
		if self.confirm and self.confirm.kind == "NewPlayerTest" then
			self:Text("NewPlayerTestWarning", "Start fresh as a new player? Your real save is kept. Rejoin to go back.", 14, 44, C.gold)
			self:Button("ConfirmNewPlayerTest", "Start new-player test", function()
				self.confirm = nil
				self:Request("TestNewPlayer")
				self:ClosePanel()
			end, Theme.ActionColors.danger)
			self:Button("CancelNewPlayerTest", "Cancel", function() self.confirm = nil;self:RenderPanel(true) end)
		else
			self:Button("TestNewPlayer", if self.state.newPlayerTest then "Restart new-player test" else "Test as a new player", function()
				self.confirm = {kind = "NewPlayerTest"};self:RenderPanel(true)
			end, Theme.ActionColors.navigation)
		end
	end
	if self.intro and self.intro:CanReplay() then
		self:Button("ReplayIntro", "Replay intro", function() self:ClosePanel();self.intro:Replay() end, Theme.ActionColors.navigation)
	end
	-- Mirrors the real bindings: Start (B/U/R/O), ResearchExtras (G), native E prompts.
	local input=UserInputService.PreferredInput
	if input==Enum.PreferredInput.KeyboardAndMouse then
		self:Text("ControlsHeading", "KEYBOARD CONTROLS", 13, 24, C.green)
		self:Text("Controls", "WASD move · Space jump · E interact\nB My Army · U or R Upgrades · O Settings\nG Rally in battle · Esc close", 16, 72, C.muted)
	elseif input==Enum.PreferredInput.Touch then
		self:Text("Controls", "Tap the on-screen buttons and prompts to interact.", 16, 36, C.muted)
	end
	self:Text("SaveInfo", self.state.saveMessage or "Chickens, Coins and upgrades are saved between visits.", 12, 32, C.muted)
	if self.state.admin then self:Button("OpenAdmin", "Admin commands  ·  F2", function() self:OpenPage("Admin") end, Theme.ActionColors.navigation) end
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
	-- October 14 launch features. Server commands need a session-only test profile.
	local function launch(command,argument) self:Request("Debug",{command=command,argument=argument}) end
	self:Text("LaunchHeading","LAUNCH FEATURES",14,30,C.green)
	self:Button("TestEverything","TEST EVERYTHING · unlock all, showcase flock, all passes",function() launch("TestEverything") end,Theme.ActionColors.purchase)
	self:Button("TestRebirthReady","Rebirth · King cleared + coins for the next rank",function() launch("RebirthReady") end)
	self:Button("TestInvasion","Mission · spawn Scout Landing on the island now",function() launch("StartInvasion","1:1") end)
	self:Button("TestInvasionBoss","Mission · spawn The King Returns (Royal boss)",function() launch("StartInvasion","3:3") end)
	self:Button("TestDailyNextDay","Daily streak · jump to the next day",function() launch("DailyNextDay") end)
	self:Button("TestOldGiants","Old Giants · add a saved Giant and Colossal (now ordinary)",function() launch("OldGiants") end)
	self:Button("TestMutations","Mutations · one chicken with each mutation",function() launch("Mutations") end)
	self:Button("TestHalloween","Halloween event · toggle on/off (this Studio server)",function() launch("Halloween") end)
	local shop=self.state.shop
	self:Text("TestHelp", if shop and shop.testAllowed then "Disposable Studio session · test progress disappears when Play stops."
		else "Changes here affect your test progress. Use the protected reset to start a fresh playthrough.", 13, 42, C.muted)
	if shop and shop.testAllowed then
		local presetNames={Account="My account's passes",NoPasses="No paid passes",EggSpawn="2x Egg Spawn only",AllPasses="All enabled passes"}
		self:Text("PurchaseTestStatus", "PURCHASE TEST · "..(presetNames[shop.testPreset] or presetNames.Account), 14, 30, C.green)
		self:Text("PurchaseTestHelp", "Session only. Fresh starts clear test coins, chickens, upgrades and consumables. Your real purchases and save stay intact.", 13, 62, C.muted)
		self:Button("TestNoPasses", "Ignore all owned passes · keep test progress", function() self:Request("Debug",{command="TestPurchases",argument="NoPasses"}) end)
		self:Button("TestAccountPasses", "Use my account's passes again", function() self:Request("Debug",{command="TestPurchases",argument="Account"}) end)
		for _,preset in {{"Free","Fresh free player · no paid items"},{"LowRobux","Fresh low spend · 2x Egg Spawn only"},
			{"CashPack","Fresh coin pack · +10,000 Coins, no passes"},{"AllPasses","Fresh all enabled passes · no coin packs"},
			{"AllItems","Fresh all items · passes + one of each coin pack"}} do
			self:Button("FreshEconomy"..preset[1],preset[2],function() self:Request("Debug",{command="FreshEconomy",argument=preset[1]}) end)
		end
	else
		self:Text("PurchaseTestUnavailable", "Purchase presets need Studio session-only mode (PetRollPlaytestSessionOnly).", 13, 46, C.muted)
	end
	local actions = {{"Coins", "+10,000 test Coins"}, {"Unlock", "Clear 2 route camps + test capacity"},
		{"Pair", "Add two common chickens"}, {"FillCommon", "Replace flock with common chickens"},
		{"FillMixed", "Replace flock with varied chickens"}, {"FillReserves", "Fill flock to 40"}, {"Opponent", "Create a defended test base"},
		{"EmptyOpponent", "Create an empty test base"}, {"AwayOpponent", "Test opponent returns in 7s"},
		{"BotAttack", "Test opponent attacks my base"}, {"Seed", "Use repeatable test rolls"}}
	self:Button("DebugKnockout", "Knock out one Army chicken · test 5s respawn", function() self:Request("Debug", {command="Knockout"}) end)
	for _, item in actions do self:Button("Debug" .. item[1], item[2], function() self:Request("Debug", {command = item[1]}) end) end
	for rank=1,4 do self:Button("DebugPromotion"..rank,"Test rank "..rank.." · keep territory wins",function() self:Request("Debug",{command="Promotion",argument=rank}) end) end
	for _, count in {3, 6, 10} do self:Button("DebugCapacity" .. count, "Set Army size to " .. count, function() self:Request("Debug", {command = "Capacity", argument = count}) end) end
	for _, id in Catalog.Order do
		self:Button("DebugGrant" .. id, "Give one " .. Catalog[id].name, function() self:Request("Debug", {command = "Grant", argument = id}) end)
	end
	self:Button("DebugOfferDragon", "Put Golden Emperor on next roll", function() self:Request("Debug", {command = "Offer", argument = "Dragon"}) end)
	self:Button("DebugReset", "Reset my test progress…", function() self.confirm = {kind = "Reset"};self:RenderPanel(true) end, Theme.ActionColors.danger)
end

function AppController:RenderPanel(force)
	if not self.state or not self.panel.Visible then return end
	local browsing=self.page=="Army"
	local selling=self.page=="Sell"
	local shopping,indexing=self.page=="Shop",self.page=="Index"
	local upgrading=self.page=="Upgrades"
	self.progression.root.Visible=upgrading
	self.content.Visible,self.chickenBrowser.root.Visible=not browsing and not selling and not shopping and not indexing and not upgrading,browsing
	self.sellMenu.root.Visible=selling
	local standard=not shopping and not browsing and not selling and not upgrading
	self.panelHeader.Visible,self.panelBody.Visible=standard,standard
	self.standardPage.Visible=standard
	self.shopBrowser.root.Visible,self.indexBrowser.root.Visible=shopping,indexing
	if upgrading then
		self.progression:Render();return
	end
	if shopping then
		self.panelTitle.Text="Shop";self.shopBrowser:Render(force);return
	end
	if indexing then
		self.panelTitle.Text="Chicken Index";self.indexBrowser:Render(force);return
	end
	if browsing then
		self.panelTitle.Text="My Army"
		self.chickenBrowser:Render(force)
		return
	end
	if selling then
		self.panelTitle.Text="Sell Chickens"
		self.sellMenu:Render(force)
		return
	end
	local state = self.state
	local keys = {self.page, tostring(self.selected), tostring(self.confirm), tostring(state.capacity), tostring(state.luck), tostring(state.incomeLevel), state.armyState, tostring(state.campsWon),tostring(state.incoming)}
	if self.page=="Formations" or self.page=="Operations" then
		table.insert(keys,tostring(state.research and state.research.revision))
		table.insert(keys,table.concat(state.selectedIds or {},","))
		table.insert(keys,tostring(state.operations and state.operations.activeId))
	end
	local p=state.progression
	if p then table.insert(keys,p.rank..":"..p.recruitTier..":"..tostring(p.goal)..":"..tostring(p.requirement)..":"..tostring(state.kingCleared)) end
	if self.page == "Settings" then table.insert(keys, tostring(state.newPlayerTest));table.insert(keys, tostring((state.tutorial or {}).goalsHidden));table.insert(keys, tostring(state.saveStatus));table.insert(keys, tostring(state.saveMessage));table.insert(keys, tostring(UserInputService.PreferredInput)) end
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
	elseif self.page == "Formations" then self.researchExtras:RenderFormations()
	elseif self.page == "Operations" then self.researchExtras:RenderOperations()
	elseif self.page == "Admin" then self.adminPanel:Render()
	else self:RenderTest() end
	self:FitContentCanvas()
	self.content.CanvasPosition = scroll
end

function AppController:Receive(packet)
	if type(packet) ~= "table" or type(packet.state) ~= "table" then return end
	local old = self.state
	-- October 20 storage: the server leaves out an unchanged chicken list (same
	-- petsVersion). Keep the last one; anything else asks for a full snapshot.
	if packet.state.pets == nil then
		local same = old ~= nil and old.pets ~= nil and old.petsVersion == packet.state.petsVersion
		packet.state.pets = if old and old.pets then old.pets else {}
		if not same then
			-- The kept list stays labeled with its own version until a full one arrives.
			packet.state.petsVersion = if old then old.petsVersion else nil
			if os.clock() >= (self.petsSyncAt or 0) then
				self.petsSyncAt = os.clock() + 2
				self:Request("Sync")
			end
		end
	end
	self.state = packet.state
	local state = self.state
	-- Before any guide/objective refresh, so a first-visit intro can hold them.
	if self.intro then self.intro:Observe(state) end
	self.commerce:ReceiveState(state)
	local researchFeedback=self.research:Receive(state,packet.result)
	self.eggs:Receive(state.eggs)
	-- October 20 hand tools: the dock, the Feed prompt and Feed results.
	if self.tools then self.tools:Receive(state, packet.result) end
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
	if result and result.ok and result.action=="CallArmy" then
		self.audio:Play("CallArmyWhistle",nil,{volume=0.18,noFallback=true,voiceKey="CallArmyWhistle",cooldown=0.75})
	end
	if result and result.ok and (result.action=="UpgradeChicken" or result.action=="BoardUpgrade") then
		self.audio:Play("UIPurchase",nil,{noFallback=true})
	end
	self.researchExtras:Receive(state,result)
	self.missionTracker:Render(state)
	-- Admin replies go to the Admin page's output when it is open.
	if self.adminPanel and self.adminPanel:Receive(result) then result=nil end
	local shownRecruit, newRecruit = false, false
	local shownProduction,newProduction=false,false
	if result then shownProduction,newProduction=self:TrackProductionUpgrade(result,researchFeedback) end
	self.chickenBrowser:Receive(result)
	self.sellMenu:Receive(result)
	local shownCrate=self.commerce:Receive(result)
	self.progression:Receive(result)
	self.eggBoard:Receive(result)
	if result and result.action~="RefreshShop" and result.action~="PreparePurchase" and result.action~="AcknowledgeResearch" then
  if result.ok and result.action=="Buy" then shownRecruit,newRecruit=self:TrackRecruit(result) end
		if not researchFeedback and not shownProduction and not shownCrate
			and not (result.ok and (result.action=="Roll" or shownRecruit or QUIET_SUCCESS[result.action])) then self:Notify(result.message,result.ok) end
		if result.ok and result.action == "Buy" and not shownRecruit then self.feedback:Action("Buy");self.base:PetPulse(result.petId, C.gold) end
		if result.ok and (result.action == "Sell" or result.action == "Promote") then self.feedback:Action(result.action) end
		if result.ok and (result.action == "Income" or result.action == "Luck" or result.action == "Expand")
			and (not shownProduction or newProduction) then self.feedback:Action(result.action) end
		if result.ok and result.action == "Attack" then self:ClosePanel() end
	end
	local count, limit, capacity, selectedCount, deployedCount = self:Counts()
	self.hud:Update(state, count, limit, capacity, selectedCount, deployedCount)
	self.base:UpdateObjective()
	self:StepRecruitFeedback()
	-- Rank-ups arrive as the server's own message (e.g. "Fusion up to Lv 5 unlocked!"); show it as sent.
	if state.banner and state.banner ~= "" and state.banner ~= self.lastBanner then self:Notify(state.banner,true);self.lastBanner = state.banner end
	if old and state.lastResult ~= old.lastResult and not packet.result then
		local kind=if state.lastResult:match("^You've conquered ") then "conquest" else nil
		self:Notify(state.lastResult,kind)
	end
	self:RenderPanel(old == nil)
	self.offlineCash:Receive(state)
	-- After the offline receipt so the daily popup can wait for it.
	self.rebirthPanel:Render(state,result)
	self.dailyReward:Render(state,result)
	self.freeGift:Render(state,result)
	self.operationsPanel:Render(state,result)
	self.autoRollMenu:Render(state,result)
	if self.commander then self.commander:Update() end
	-- After menus and popups render, so the first-time Hill film sees them open.
	if self.hillIntro then self.hillIntro:Observe(state) end
	if result and not result.ok then
		local source=self:CommandButton(result.action)
		if source then Theme.Motion:Shake(source.Visual,6) end
	end
	if result and result.ok then
		local changed=if (result.action=="Expand" or result.action=="Income" or result.action=="Luck")
			and (not shownProduction or newProduction) then self.progression.row else nil
		if changed then
			local name=if result.action=="Expand" then "Capacity" else result.action
			local card=changed:FindFirstChild(name)
			if card and card:FindFirstChild("Icon") then Theme.Motion:Pop(card.Icon,1.18) end
		end
		-- Quiet HUD commands confirm on the button that sent them. (Cash gains pop in HudController.)
		local source=self:CommandButton(result.action)
		if source then Theme.Motion:Pop(source.Visual,1.1) end
		if result.action=="TestNewPlayer" and self.intro then self.intro:PlayAsNewPlayer() end
	end
end

function AppController:CommandButton(action)
	local hud=self.hud
	local button=if action=="CallArmy" then hud.callArmy elseif action=="GoBase" then hud.myBase elseif action=="SetAutoRoll" then hud.autoRoll else nil
	return if button and button.Parent and button:FindFirstChild("Visual") then button else nil
end

function AppController:Start()
	self.remotes = ReplicatedStorage.PetRoll:WaitForChild("Remotes")
	self:BuildUI()
	-- October 20 live Coin boosts: the Gold Rush chip/sky/air and the Friend Boost line.
	self.goldRush=GoldRushController.new(self)
	self.friendBoost=FriendBoost.new(self)
	self.commander=CommanderGuide.new(self)
	self.leaderboards=LeaderboardBoards.new(self)
	self.intro=IntroCutscene.new(self)
	self.hillIntro=HillIntro.new(self)
	self.eggBoard:Start()
	self.audio:Start()
	self.audio:BindUI(self.gui)
	-- Every Motion-bound button clicks; hand-written Click calls share the voice key and cooldown.
	Theme.Motion.sound=function(cue) self.audio:Play(cue) end
	self.feedback:Start()
	self.commerce:Start()
	self.eggs:Start()
	self.tools=ToolController.new(self)
	self.animator = DuckAnimator.new(self.audio)
	self.animator:SetReducedMotion(self.reducedMotion)
	self.galaxyCrateVisuals = GalaxyCrateVisuals.new()
	self.galaxyCrateVisuals:SetReducedMotion(self.reducedMotion)
	self.prompts=PromptStyleController.new(self)
	self.prompts:Start()
	self.base:Start()
	self.battle:Start(self.remotes:WaitForChild("BattleChanged"))
	table.insert(self.connections, self.remotes:WaitForChild("StateChanged").OnClientEvent:Connect(function(packet) self:Receive(packet) end))
	for _, entry in {{"Army", Enum.KeyCode.B}, {"Upgrades", Enum.KeyCode.U}, {"Research", Enum.KeyCode.R}, {"Settings", Enum.KeyCode.O}, {"Test", Enum.KeyCode.F8}, {"Admin", Enum.KeyCode.F2}} do
		local page, key = entry[1], entry[2]
		ContextActionService:BindAction("PetRoll" .. page, function(_, inputState)
			if inputState ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
			if self.commerce.cratePresenting then return Enum.ContextActionResult.Sink end
			if page == "Test" and (not self.state or not self.state.debugAllowed) then return Enum.ContextActionResult.Pass end
			if page == "Admin" and (not self.state or not self.state.admin) then return Enum.ContextActionResult.Pass end
			self:TogglePage(page)
			return Enum.ContextActionResult.Sink
		end, false, key)
	end
	table.insert(self.connections, UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
		if self.page == "Settings" then self:RenderPanel() end
	end))
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input)
		if self.commerce.cratePresenting then return end
		if input.KeyCode == Enum.KeyCode.Escape and (self.panel.Visible or self.research.root.Visible) then self:ClosePanel() end
	end))
	self:Request("Sync")
	if RunService:IsStudio() then print("[PetRoll] My Chicken Army! client ready") end
end

function AppController:Destroy()
	self.alive = false
	if self.toastDelay then task.cancel(self.toastDelay);self.toastDelay=nil end
	Theme.Motion:Reset()
	ContextActionService:UnbindAction("PetRollClosePanel")
	for _, connection in self.connections do connection:Disconnect() end
	for _, page in {"Army", "Upgrades", "Research", "Settings", "Test", "Admin"} do ContextActionService:UnbindAction("PetRoll" .. page) end
	if self.commander then self.commander:Destroy() end
	if self.leaderboards then self.leaderboards:Destroy() end
	if self.intro then self.intro:Destroy() end
	if self.hillIntro then self.hillIntro:Destroy() end
	if self.animator then self.animator:Destroy() end
	if self.galaxyCrateVisuals then self.galaxyCrateVisuals:Destroy() end
	if self.prompts then self.prompts:Destroy() end
	self.commerce:Destroy();self.shopBrowser:Destroy();self.indexBrowser:Destroy();self.sellMenu:Destroy()
	self.progression:Destroy()
	self.research:Destroy()
	self.researchExtras:Destroy()
	self.missionTracker:Destroy()
	self.eggBoard:Destroy()
	self.offlineCash:Destroy()
	self.rebirthPanel:Destroy();self.dailyReward:Destroy();self.operationsPanel:Destroy();self.autoRollMenu:Destroy()
	if self.goldRush then self.goldRush:Destroy() end
	if self.friendBoost then self.friendBoost:Destroy() end
	if self.menuBlur then self.menuBlur:Destroy();self.menuBlur=nil end
	table.clear(self.menuBlurOwners)
	if self.tools then self.tools:Destroy() end
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
