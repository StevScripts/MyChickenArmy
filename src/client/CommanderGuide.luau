--!strict
-- Small non-modal guide. Gameplay and completion remain server-owned.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Theme = require(script.Parent.UITheme)
local Guide = require(game.ReplicatedStorage.PetRoll.Shared.TutorialGuide)
local CashNodes = require(script.Parent.CashUpgradeNodes)
local GuideFocus = require(script.Parent.GuideFocus)
local CARD_POSITION = UDim2.fromScale(.5,.005)
local ENTER_SECONDS = .18
-- Reserve world dimming for the two new interactions, once their prompt is in reach.
local WORLD_SPOTLIGHT_STEPS = {Roll=true, Recruit=true}
local Commander = {}
Commander.__index = Commander

function Commander.new(app)
	local self = setmetatable({app=app, connections={}, sent={}, prompts={}, alive=true,wasTree=false,wasArmy=false}, Commander)
	local root = Theme.InsetContainer(app.other, "CommanderGuide", Enum.ScreenInsets.CoreUISafeInsets)
	root.ZIndex, root.Visible = 25, false
	self.root = root
	self.spotlight = GuideFocus.new(app.other)
	local card = Theme.Container(root, "Card")
	card.AnchorPoint, card.Position, card.Size = Vector2.new(.5,0), CARD_POSITION, UDim2.fromScale(.86,.115)
	Theme.Aspect(card, 7.4)
	self.card = card
	local body = Theme.Frame(card,"Instruction",UDim2.fromScale(.9,.78),Theme.OverlayColors.Bottom)
	body.Position, body.BackgroundTransparency = UDim2.fromScale(.1,.13), .28
	Theme.Stroke(body,Theme.Arcade.border,Theme.Border.Control)
	self.instruction=Theme.Display(card,"Objective","",27)
	self.instruction.Position,self.instruction.Size=UDim2.fromScale(.19,.30),UDim2.fromScale(.77,.42)
	self.portrait=Theme.Image(card,"Commander",Theme.Assets.Commander,UDim2.fromScale(.165,1.15),UDim2.fromScale(0,-.015))
	Theme.Aspect(self.portrait,1)
	self.portrait.ZIndex=4
	Theme.ScaleText(card)
	table.insert(self.connections,ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt:FindFirstAncestor("RollStation") or prompt.Name=="ArmyCommandPrompt" then self.prompts[prompt]=true;self:Update() end
	end))
	table.insert(self.connections,ProximityPromptService.PromptHidden:Connect(function(prompt)
		self.prompts[prompt]=nil;self:Update()
	end))
	return self
end

-- Snapshot refreshes never restart this one short entrance. The shared tween
-- owner cancels on interruption and settles immediately for reduced motion.
function Commander:Present(visible, changed)
	if not visible then
		Theme.Motion:Cancel(self.card,"guide-enter")
		Theme.Motion:Cancel(self.portrait,"guide-salute");self.portrait.Rotation=0
		self.card.Position=CARD_POSITION
	elseif (not self.wasVisible or changed) and not self.app.reducedMotion then
		Theme.Motion:Cancel(self.card,"guide-enter")
		self.card.Position=CARD_POSITION+UDim2.fromScale(0,.008)
		Theme.Motion:Tween(self.card,"guide-enter",{Position=CARD_POSITION},ENTER_SECONDS)
		self.portrait.Rotation=-6
		Theme.Motion:Tween(self.portrait,"guide-salute",{Rotation=0},.24)
	elseif self.app.reducedMotion then
		Theme.Motion:Cancel(self.card,"guide-enter");self.card.Position=CARD_POSITION
		Theme.Motion:Cancel(self.portrait,"guide-salute");self.portrait.Rotation=0
	end
	self.card.Visible,self.wasVisible=visible,visible
end

function Commander:Signal(signal)
	local input=if UserInputService.PreferredInput==Enum.PreferredInput.Touch then "Touch"
		elseif UserInputService.PreferredInput==Enum.PreferredInput.Gamepad then "Gamepad" else "Keyboard"
	self.app:Request("TutorialSignal",{signal=signal,input=input})
end

function Commander:ClearFocus()
	self.spotlight:SetTarget(nil,self.app.reducedMotion)
	self.focus,self.pulse=nil,nil
	self.focusTarget=nil
end

function Commander:Focus(target, worldParts)
	self.spotlight:SetTarget(target,self.app.reducedMotion,worldParts)
	self.focusTarget=target
	self.focus=if target then self.spotlight.stroke else nil
	self.pulse=self.spotlight.pulse
end

function Commander:Update()
	if not self.alive then return end
	local app,state=self.app,self.app.state
	if not state then return end
	if state.saveStatus=="loading" or state.saveStatus=="error" then self.root.Visible=false;self:ClearFocus();self:Present(false);return end
	if not self.observedProfile then
		self.observedProfile=true
		self.completedBeforeVisit=(state.tutorial or {}).guideCompleted==true
	end
	local blocked=app.dialogueActive or (app.offlineCash and app.offlineCash.gui~=nil)
	local character=Players.LocalPlayer.Character
	if not self.ready and not blocked and character and character:FindFirstChild("HumanoidRootPart") then
		self.ready=true;self:Signal("Ready")
	end
	local current=Guide.Resolve(state)
	if self.completedBeforeVisit and current and current.id=="Complete" then current=nil end
	self.current=current
	if not current then self.root.Visible=false;self:ClearFocus();self:Present(false);return end
	local id=current.id
	local changed=self.step~=id
	if changed then
		self.step,self.stepAt=id,os.clock()
		self:ClearFocus()
	end
	self.root.Visible=not blocked
	local inTree=app.research.root.Visible
	local inArmy=app.panel.Visible and app.page=="Army"
	-- Keep menu headers and controls unobstructed; their one relevant control is outlined.
	local atTarget=false
	for prompt in self.prompts do
		if not prompt.Parent then self.prompts[prompt]=nil
		elseif (current.target=="RollStation" and prompt:FindFirstAncestor("RollStation"))
			or (id=="Deploy" and prompt.Name=="ArmyCommandPrompt") then atTarget=true end
	end
	-- Let the game's native action prompt take over when the player reaches it.
	local visible=not app.panel.Visible and not inTree and not blocked and not atTarget
		and not (app.toastFrame and app.toastFrame.Visible)
	self:Present(visible,changed)
	if id=="Complete" then
		if os.clock()-self.stepAt>=8 then
			self.root.Visible=false
			if not self.sent.Finish then self.sent.Finish=true;self:Signal("Finish") end
			self:ClearFocus();self:Present(false);return
		end
	end
	self.instruction.Text=current.text
	if inTree~=self.wasTree then
		self.wasTree=inTree;self:Signal(if inTree then "TreeOpen" else "TreeClose")
		if inTree and id=="Expand" then
			local node=CashNodes.NextId("ArmySize",state.boardUpgrades.ArmySize)
			app.research:Center(node)
			if UserInputService.GamepadEnabled then app.research:Select(node,true);GuiService.SelectedObject=app.research.nodes[node].button end
		end
	end
	if inArmy~=self.wasArmy then self.wasArmy=inArmy;self:Signal(if inArmy then "ArmyOpen" else "ArmyClose") end
	local target,worldParts
	if not blocked and id=="Expand" then
		if inTree then
			local node=CashNodes.NextId("ArmySize",state.boardUpgrades.ArmySize)
			target=app.research.nodes[node] and app.research.nodes[node].button
			if app.research.selected==node and not self.sent.NodeInspect then self.sent.NodeInspect=true;self:Signal("NodeInspect") end
		elseif not app.panel.Visible then target=app.hud.shortcuts:FindFirstChild("Upgrades") end
	elseif not blocked and id=="Select" then
		target=if inTree then app.research.root:FindFirstChild("Exit",true)
			elseif inArmy then app.chickenBrowser.best elseif not app.panel.Visible then app.hud.army else nil
	elseif WORLD_SPOTLIGHT_STEPS[id] and atTarget and not blocked and not inTree and not app.panel.Visible and not state.incoming
		and (state.armyState=="Home" or state.armyState=="Following")
		and app.base and app.base.guideWorldStep==id then
		target,worldParts=app.base.guideWorldTarget,app.base.guideWorldParts
	end
	self:Focus(target,worldParts)
end

function Commander:Destroy()
	self.alive=false;self:ClearFocus();self:Present(false)
	self.spotlight:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	self.root:Destroy()
end

return Commander
