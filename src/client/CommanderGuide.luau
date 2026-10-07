--!strict
-- Small non-modal guide. Gameplay and completion remain server-owned.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.UITheme)
local Guide = require(game.ReplicatedStorage.PetRoll.Shared.TutorialGuide)
local CashNodes = require(script.Parent.CashUpgradeNodes)
local GuideFocus = require(script.Parent.GuideFocus)
local CARD_POSITION = UDim2.fromScale(.5,.005)
local ENTER_SECONDS = .18
local TYPE_SECONDS_PER_GRAPHEME = .02
local TYPE_MAX_SECONDS = .65
local Commander = {}
Commander.__index = Commander

function Commander.new(app)
	local self = setmetatable({app=app, connections={}, sent={}, prompts={}, alive=true,wasTree=false,wasArmy=false}, Commander)
	local root = Theme.InsetContainer(app.other, "CommanderGuide", Enum.ScreenInsets.CoreUISafeInsets)
	root.ZIndex, root.Visible = 25, false
	self.root = root
	self.pointerGuide = GuideFocus.new(app.other)
	local card = Theme.Container(root, "Card")
	card.AnchorPoint, card.Position, card.Size = Vector2.new(.5,0), CARD_POSITION, UDim2.fromScale(.86,.115)
	Theme.Aspect(card, 7.4)
	self.card = card
	local body = Theme.Frame(card,"Instruction",UDim2.fromScale(.9,.78),Theme.OverlayColors.Bottom)
	body.Position, body.BackgroundTransparency = UDim2.fromScale(.1,.13), .28
	Theme.Stroke(body,Theme.Arcade.border,Theme.Border.Control)
	self.instruction=Theme.Display(card,"Objective","",27)
	self.instruction.Position,self.instruction.Size=UDim2.fromScale(.18,.19),UDim2.fromScale(.795,.66)
	self.instruction.TextXAlignment=Enum.TextXAlignment.Center
	self.portrait=Theme.Image(card,"Commander",Theme.Assets.Commander,UDim2.fromScale(.165,1.15),UDim2.fromScale(0,-.015))
	Theme.Aspect(self.portrait,1)
	self.portrait.ZIndex=4
	Theme.ScaleText(card)
	self.instructionLimits={}
	for _,label in {self.instruction,self.instruction.TextFace,self.instruction.TextShadow} do
		local limit=Instance.new("UITextSizeConstraint")
		limit.MinTextSize,limit.MaxTextSize=1,100
		limit.Parent=label
		table.insert(self.instructionLimits,limit)
	end
	for _,property in {"Text","AbsoluteSize"} do
		table.insert(self.connections,self.instruction:GetPropertyChangedSignal(property):Connect(function() self:FitInstruction() end))
	end
	self:FitInstruction()
	table.insert(self.connections,ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt:FindFirstAncestor("RollStation") or prompt.Name=="ArmyCommandPrompt" then self.prompts[prompt]=true;self:Update() end
	end))
	table.insert(self.connections,ProximityPromptService.PromptHidden:Connect(function(prompt)
		self.prompts[prompt]=nil;self:Update()
	end))
	return self
end

function Commander:FitInstruction()
	-- TextScaled enables wrapping in Roblox. Cap it at the largest one-line
	-- size; only text/frame changes remeasure, never a frame-by-frame loop.
	local label=self.instruction
	local space=label.AbsoluteSize
	if space.X<=0 or space.Y<=0 then return end
	local low,high,best=1,100,1
	while low<=high do
		local size=math.floor((low+high)/2)
		local bounds=TextService:GetTextSize(label.Text,size,label.Font,Vector2.new(100000,100000))
		if bounds.X<=math.max(1,space.X-4) and bounds.Y<=space.Y*.96 then
			best,low=size,size+1
		else high=size-1 end
	end
	for _,limit in self.instructionLimits do limit.MaxTextSize=best end
end

function Commander:CancelTypewriter()
	if not self.typeTweens then return end
	for _,tween in self.typeTweens do tween:Cancel() end
	self.typeTweens=nil
end

function Commander:SetInstruction(text, animate)
	if self.instruction.Text==text and not animate then return end
	self:CancelTypewriter()
	self.instruction.Text=text
	self:FitInstruction()
	local length=utf8.len(text) or #text
	local typing=animate and not self.app.reducedMotion and length>0
	self.typeTweens=if typing then {} else nil
	for _,layer in {self.instruction.TextFace,self.instruction.TextShadow} do
		layer.MaxVisibleGraphemes=if typing then 0 else -1
		if typing then
			local duration=math.min(TYPE_MAX_SECONDS,length*TYPE_SECONDS_PER_GRAPHEME)
			local tween=TweenService:Create(layer,TweenInfo.new(duration,Enum.EasingStyle.Linear),
				{MaxVisibleGraphemes=length})
			table.insert(self.typeTweens,tween)
			tween:Play()
		end
	end
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

-- A quick "done!" each time a lesson completes: a green check pops beside the
-- Commander, sparks burst from it and the card flashes. Presentation only.
function Commander:Celebrate()
	self.app.audio:Play("SkillTreeResearchCompleted",nil,{noFallback=true,cooldown=.3})
	local card,reduced=self.card,self.app.reducedMotion
	local old=card:FindFirstChild("StepComplete");if old then old:Destroy() end
	local holder=Theme.Container(card,"StepComplete")
	holder.ZIndex=10
	local at=UDim2.fromScale(.13,.78)
	-- Plain circles: a dark ring with a green face, nothing square behind them.
	local function circle(parent,name,size,color,z)
		local disc=Instance.new("Frame")
		disc.Name,disc.Size,disc.BackgroundColor3,disc.BorderSizePixel,disc.ZIndex=name,size,color,0,z
		disc.AnchorPoint=Vector2.new(.5,.5)
		local corner=Instance.new("UICorner");corner.CornerRadius,corner.Parent=UDim.new(.5,0),disc
		disc.Parent=parent
		return disc
	end
	local badge=circle(holder,"Check",UDim2.fromScale(.075,.62),Theme.Arcade.border,12)
	badge.Position=at
	Theme.Aspect(badge,1)
	local face=circle(badge,"Face",UDim2.fromScale(.84,.84),Theme.Arcade.green,13)
	face.Position=UDim2.fromScale(.5,.5)
	for _,arm in {{.37,.6,.16,.38,-45},{.6,.47,.16,.68,40}} do
		local tick=Instance.new("Frame")
		tick.Name,tick.Size,tick.BackgroundColor3,tick.BorderSizePixel=("Tick"),UDim2.fromScale(arm[3],arm[4]),Color3.new(1,1,1),0
		tick.AnchorPoint,tick.Position,tick.Rotation,tick.ZIndex=Vector2.new(.5,.5),UDim2.fromScale(arm[1],arm[2]),arm[5],14
		tick.Parent=face
	end
	local scale=Instance.new("UIScale");scale.Parent=badge
	local flash=Theme.Frame(card:FindFirstChild("Instruction") or card,"CompleteFlash",UDim2.fromScale(1,1),Color3.fromRGB(150,255,120))
	flash.BackgroundTransparency,flash.ZIndex=.45,9
	local function tween(item,seconds,goal,style,direction)
		local motion=TweenService:Create(item,TweenInfo.new(seconds,style or Enum.EasingStyle.Quad,direction or Enum.EasingDirection.Out),goal)
		motion:Play();return motion
	end
	tween(flash,.5,{BackgroundTransparency=1})
	if not reduced then
		scale.Scale=0
		tween(scale,.32,{Scale=1},Enum.EasingStyle.Back)
		local bump=card:FindFirstChild("CompleteBump") or Instance.new("UIScale")
		bump.Name,bump.Scale,bump.Parent="CompleteBump",1.05,card
		tween(bump,.3,{Scale=1},Enum.EasingStyle.Back)
		local colors={Theme.Arcade.gold,Theme.Arcade.green,Color3.new(1,1,1)}
		for i=1,10 do
			local angle=(i/10)*math.pi*2+math.random()*.4
			local spark=Theme.Frame(holder,"Spark",UDim2.fromScale(.012,.1),colors[i%3+1])
			Theme.Aspect(spark,1)
			spark.AnchorPoint,spark.Position,spark.ZIndex,spark.Rotation=Vector2.new(.5,.5),at,11,math.random(0,90)
			local reach=.7+math.random()*.4
			tween(spark,.55,{Position=at+UDim2.fromScale(math.cos(angle)*.07*reach,math.sin(angle)*.75*reach),
				BackgroundTransparency=1,Rotation=spark.Rotation+180})
		end
	end
	task.delay(1.1,function()
		if not holder.Parent then return end
		tween(scale,.25,{Scale=0},Enum.EasingStyle.Back,Enum.EasingDirection.In)
		task.delay(.27,function() holder:Destroy();flash:Destroy() end)
	end)
end

function Commander:Signal(signal)
	local input=if UserInputService.PreferredInput==Enum.PreferredInput.Touch then "Touch"
		elseif UserInputService.PreferredInput==Enum.PreferredInput.Gamepad then "Gamepad" else "Keyboard"
	self.app:Request("TutorialSignal",{signal=signal,input=input})
end

function Commander:ClearFocus()
	self.pointerGuide:SetTarget(nil,self.app.reducedMotion)
end

function Commander:Focus(target)
	self.pointerGuide:SetTarget(target,self.app.reducedMotion)
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
	local blocked=app.dialogueActive or (app.offlineCash and app.offlineCash.gui~=nil) or (app.intro~=nil and app.intro:Pending())
	local character=Players.LocalPlayer.Character
	if not self.ready and not blocked and character and character:FindFirstChild("HumanoidRootPart") then
		self.ready=true;self:Signal("Ready")
	end
	local current=Guide.Resolve(state)
	if self.completedBeforeVisit and current and current.id=="Complete" then current=nil end
	-- A lesson flipping to done queues the celebration until the card can show it.
	local facts=Guide.Facts(state)
	if self.facts and current then
		for _,milestone in Guide.Milestones do
			if facts[milestone] and not self.facts[milestone] then self.celebrate=true end
		end
	end
	self.facts=facts
	self.current=current
	if not current then
		self.pendingType=false;self:CancelTypewriter()
		self.root.Visible=false;self:ClearFocus();self:Present(false);return
	end
	local id=current.id
	local changed=self.step~=id
	if changed then
		self.step,self.stepAt=id,os.clock()
		self.pendingType=true
		self:ClearFocus()
	end
	self.root.Visible=not blocked
	local inTree=app.research.root.Visible
	local inArmy=app.panel.Visible and app.page=="Army"
	-- Keep menu headers and controls unobstructed; the arrow points beside their relevant control.
	local atTarget=false
	for prompt in self.prompts do
		if not prompt.Parent then self.prompts[prompt]=nil
		elseif (current.target=="RollStation" and prompt:FindFirstAncestor("RollStation"))
			or (id=="Deploy" and prompt.Name=="ArmyCommandPrompt") then atTarget=true end
	end
	-- Let the game's native action prompt take over when the player reaches it.
	local visible=not app.panel.Visible and not inTree and not blocked and not atTarget
		and not (app.toastFrame and app.toastFrame.Visible)
	self:SetInstruction(current.text,visible and self.pendingType)
	if visible then self.pendingType=false end
	self:Present(visible,changed)
	if visible and self.celebrate then self.celebrate=false;self:Celebrate() end
	if id=="Complete" then
		if os.clock()-self.stepAt>=8 then
			self.root.Visible=false
			if not self.sent.Finish then self.sent.Finish=true;self:Signal("Finish") end
			self:ClearFocus();self:Present(false);return
		end
	end
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
	elseif not blocked and id=="Select" then
		target=if inTree then app.research.root:FindFirstChild("Exit",true)
			elseif inArmy then app.chickenBrowser.best elseif not app.panel.Visible then app.hud.army else nil
	end
	self:Focus(target)
end

function Commander:Destroy()
	self:CancelTypewriter()
	self.alive=false;self:ClearFocus();self:Present(false)
	self.pointerGuide:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	self.root:Destroy()
end

return Commander
