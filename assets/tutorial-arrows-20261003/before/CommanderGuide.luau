--!strict
-- Small non-modal guide. Gameplay and completion remain server-owned.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Theme = require(script.Parent.UITheme)
local Guide = require(game.ReplicatedStorage.PetRoll.Shared.TutorialGuide)
local CashNodes = require(script.Parent.CashUpgradeNodes)
local CARD_POSITION = UDim2.fromScale(.5,.005)
local ENTER_SECONDS = .18
local Commander = {}
Commander.__index = Commander

function Commander.new(app)
	local self = setmetatable({app=app, connections={}, sent={}, prompts={}, alive=true,wasTree=false,wasArmy=false}, Commander)
	local root = Theme.InsetContainer(app.other, "CommanderGuide", Enum.ScreenInsets.CoreUISafeInsets)
	root.ZIndex, root.Visible = 25, false
	self.root = root
	local card = Theme.Container(root, "Card")
	card.AnchorPoint, card.Position, card.Size = Vector2.new(.5,0), CARD_POSITION, UDim2.fromScale(.88,.172)
	Theme.Aspect(card, 5.4)
	self.card = card
	local body = Theme.Frame(card,"Instruction",UDim2.fromScale(.87,1),Theme.OverlayColors.Bottom)
	body.Position, body.BackgroundTransparency = UDim2.fromScale(.13,0), .14
	self.body=body
	Theme.Stroke(body,Theme.Arcade.border,Theme.Border.Control)
	local strip = Theme.Frame(body,"CommanderStrip",UDim2.fromScale(.93,.255),Theme.ReferenceColors.Army)
	strip.Position=UDim2.fromScale(.035,.04)
	Theme.ApplyReferenceAccent(strip,Theme.ReferenceGradients.Army)
	local studs=Theme.Studs(strip,.15,28,0)
	studs:SetAttribute("StudScaleWidth",1)
	local name=Theme.Label(strip,"CommanderName","COMMANDER CLUCK  ·  HELP",13,Theme.Arcade.border)
	name.Position,name.Size,name.ZIndex=UDim2.fromScale(.085,0),UDim2.fromScale(.76,1),4
	name.TextOutline.Enabled=false
	self.name,self.strip=name,strip
	self.title=Theme.Display(body,"Objective","",27)
	self.title.Position,self.title.Size=UDim2.fromScale(.105,.345),UDim2.fromScale(.68,.32)
	self.reason=Theme.Label(body,"Reason","",18,Theme.Colors.muted)
	self.reason.Position,self.reason.Size=UDim2.fromScale(.105,.70),UDim2.fromScale(.68,.265)
	self.portrait=Theme.Image(card,"Commander",Theme.Assets.Commander,UDim2.fromScale(.225,1.23),UDim2.fromScale(-.005,-.09))
	Theme.Aspect(self.portrait,1)
	local help=Instance.new("TextButton")
	help.Name,help.Text,help.BackgroundTransparency="Help","",1
	help.Position,help.Size,help.ZIndex=UDim2.fromScale(0,0),UDim2.fromScale(.815,1),10
	help.Parent=card
	self.help=help
	table.insert(self.connections,help.Activated:Connect(function() self:Help(true) end))
	local skip=Instance.new("TextButton")
	skip.Name,skip.Text,skip.Font="Skip","Skip",Theme.Font
	skip.TextColor3,skip.TextScaled=Theme.Colors.white,true
	skip.BackgroundColor3,skip.BackgroundTransparency,skip.BorderSizePixel=Theme.OverlayColors.Bottom,1,0
	skip.Position,skip.Size,skip.ZIndex=UDim2.fromScale(.865,.06),UDim2.fromScale(.17,.95),11
		skip.AnchorPoint=Vector2.new(1,0);skip.Position=UDim2.fromScale(.993,.03)
	skip.Parent=card;self.skip=skip
	local pad=Instance.new("UIPadding");pad.PaddingLeft,pad.PaddingRight=UDim.new(.18,0),UDim.new(.18,0)
	pad.PaddingTop,pad.PaddingBottom=UDim.new(.34,0),UDim.new(.34,0);pad.Parent=skip
	table.insert(self.connections,skip.Activated:Connect(function()
		self:Signal("Skip");self.root.Visible=false;self:ClearFocus();self:Present(false)
		app:Notify("Guide hidden. Resume Commander Cluck in Settings.","info")
	end))
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
		self.card.Position=CARD_POSITION
	elseif (not self.wasVisible or changed) and not self.app.reducedMotion then
		Theme.Motion:Cancel(self.card,"guide-enter")
		self.card.Position=CARD_POSITION+UDim2.fromScale(0,.008)
		Theme.Motion:Tween(self.card,"guide-enter",{Position=CARD_POSITION},ENTER_SECONDS)
	elseif self.app.reducedMotion then
		Theme.Motion:Cancel(self.card,"guide-enter");self.card.Position=CARD_POSITION
	end
	self.card.Visible,self.wasVisible=visible,visible
end

function Commander:Signal(signal)
	local input=if UserInputService.PreferredInput==Enum.PreferredInput.Touch then "Touch"
		elseif UserInputService.PreferredInput==Enum.PreferredInput.Gamepad then "Gamepad" else "Keyboard"
	self.app:Request("TutorialSignal",{signal=signal,input=input})
end

function Commander:ClearFocus()
	if self.pulse then self.pulse:Cancel();self.pulse:Destroy();self.pulse=nil end
	if self.focus then self.focus:Destroy();self.focus=nil end
	self.focusTarget=nil
end

function Commander:Focus(target)
	if target==self.focusTarget and self.focus and self.focus.Parent and self.focusReduced==self.app.reducedMotion then return end
	self:ClearFocus()
	if not target or not target.Parent or not target.Visible then return end
	self.focusTarget,self.focusReduced=target,self.app.reducedMotion
	local stroke=Instance.new("UIStroke")
	stroke.Name,stroke.Color,stroke.Thickness="CommanderFocus",Theme.ReferenceColors.Army,3
	stroke.ApplyStrokeMode,stroke.Parent=Enum.ApplyStrokeMode.Border,target
	self.focus=stroke
	if not self.app.reducedMotion then
		self.pulse=TweenService:Create(stroke,TweenInfo.new(.65,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Transparency=.7})
		self.pulse:Play()
	end
end

function Commander:Help(navigate)
	if not self.current or self.current.id=="Complete" then return end
	self.hint=if navigate then not self.hint else true
	self.autoHintShown=true
	local key=self.current.id..":Help"
	if self.hint and not self.sent[key] then self.sent[key]=true;self:Signal("Help") end
	if navigate and self.hint and self.current.target=="Upgrades" then self.app:OpenPage("Upgrades")
	elseif navigate and self.hint and self.current.target=="Army" then self.app:OpenPage("Army") end
	self:Update()
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
		self.step,self.stepAt,self.hint,self.autoHintShown=id,os.clock(),false,false
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
		self.skip.Visible=false
		if os.clock()-self.stepAt>=8 then
			self.root.Visible=false
			if not self.sent.Finish then self.sent.Finish=true;self:Signal("Finish") end
		end
	else
		self.skip.Visible=true
		if os.clock()-self.stepAt>=20 and not self.autoHintShown and self.card.Visible then self:Help(false);return end
	end
	self.title.Text=current.title
	self.reason.Text=if self.hint then current.help else current.text
	local height=if self.hint then 1.42 else 1
	self.body.Size=UDim2.fromScale(.87,height)
	self.strip.Position,self.strip.Size=UDim2.fromScale(.035,.04/height),UDim2.fromScale(.93,.255/height)
	self.title.Position,self.title.Size=UDim2.fromScale(.105,.345/height),UDim2.fromScale(.68,.32/height)
	self.reason.Position,self.reason.Size=UDim2.fromScale(.105,.70/height),UDim2.fromScale(.68,(if self.hint then .65 else .265)/height)
	self.reason.TextYAlignment=Enum.TextYAlignment.Top
	self.name.Text=if id=="Complete" then "COMMANDER CLUCK" elseif self.hint then "COMMANDER CLUCK  ·  CLOSE" else "COMMANDER CLUCK  ·  HELP"
	if inTree~=self.wasTree then
		self.wasTree=inTree;self:Signal(if inTree then "TreeOpen" else "TreeClose")
		if inTree and id=="Expand" then
			local node=CashNodes.NextId("ArmySize",state.boardUpgrades.ArmySize)
			app.research:Center(node)
			if UserInputService.GamepadEnabled then app.research:Select(node,true);GuiService.SelectedObject=app.research.nodes[node].button end
		end
	end
	if inArmy~=self.wasArmy then self.wasArmy=inArmy;self:Signal(if inArmy then "ArmyOpen" else "ArmyClose") end
	local target
	if not blocked and id=="Expand" then
		if inTree then
			local node=CashNodes.NextId("ArmySize",state.boardUpgrades.ArmySize)
			target=app.research.nodes[node] and app.research.nodes[node].button
			if app.research.selected==node and not self.sent.NodeInspect then self.sent.NodeInspect=true;self:Signal("NodeInspect") end
		elseif not app.panel.Visible then target=app.hud.shortcuts:FindFirstChild("Upgrades") end
	elseif not blocked and id=="Select" then target=if inArmy then app.chickenBrowser.best elseif not app.panel.Visible then app.hud.army else nil
	elseif not blocked and inTree and id~="Expand" then target=app.research.root:FindFirstChild("Exit",true) end
	self:Focus(target)
end

function Commander:Destroy()
	self.alive=false;self:ClearFocus();self:Present(false)
	for _,connection in self.connections do connection:Disconnect() end
	self.root:Destroy()
end

return Commander
