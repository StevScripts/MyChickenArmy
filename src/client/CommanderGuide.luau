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
	self.card, self.cardAspect = card, card:FindFirstChildOfClass("UIAspectRatioConstraint")
	local body = Theme.Frame(card,"Instruction",UDim2.fromScale(.9,.78),Theme.OverlayColors.Bottom)
	body.Position, body.BackgroundTransparency = UDim2.fromScale(.1,.13), .28
	self.body = body
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
	-- TextScaled enables wrapping in Roblox. Cap it at the largest size that fits;
	-- only text/frame changes remeasure, never a frame-by-frame loop. The full guide
	-- card stays one line. October 15 (owner, mobile): the quiet post-guide line may
	-- wrap to two lines, so long goals stay readable on a phone instead of shrinking.
	local label=self.instruction
	local space=label.AbsoluteSize
	if space.X<=0 or space.Y<=0 then return end
	if self.quiet then self:FitQuiet();return end
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

-- October 9: post-guide goals use a quiet line: half width, no portrait,
-- no typewriter or entrance motion. The full card belongs to the guide itself.
local FULL = {card=UDim2.fromScale(.86,.115), aspect=7.4, bodyPosition=UDim2.fromScale(.1,.13), bodySize=UDim2.fromScale(.9,.78),
	bodyTransparency=.28, textPosition=UDim2.fromScale(.18,.19), textSize=UDim2.fromScale(.795,.66)}
-- The quiet card's height allowance (.3) only matters when FitQuiet lowers its aspect.
local QUIET = {card=UDim2.fromScale(.46,.3), aspect=7.5, bodyPosition=UDim2.fromScale(0,.1), bodySize=UDim2.fromScale(1,.8),
	bodyTransparency=.45, textPosition=UDim2.fromScale(.04,.18), textSize=UDim2.fromScale(.92,.64)}

-- October 16 (owner, mobile: "super shrunk"): a landscape phone is short, so the
-- 7.5:1 quiet line was only ~40pt tall and long goals fell to ~12pt. One layout for
-- every device: when the text would drop below QUIET_MIN_TEXT, the card gets taller
-- (lower aspect) so it wraps at that size instead. Measured from the screen width
-- allowance only, so the resize it causes cannot change the answer (no feedback loop).
local QUIET_MIN_TEXT, QUIET_MAX_TEXT, QUIET_MIN_ASPECT = 20, 30, 3
function Commander:FitQuiet()
	local label,area=self.instruction,self.card.Parent.AbsoluteSize
	local cardWidth=math.min(area.X*QUIET.card.X.Scale,area.Y*QUIET.card.Y.Scale*QUIET.aspect)
	local textWidth=math.max(1,cardWidth*QUIET.textSize.X.Scale-4)
	local function largest(textHeight)
		local low,high,best=1,QUIET_MAX_TEXT,1
		while low<=high do
			local size=math.floor((low+high)/2)
			local bounds=TextService:GetTextSize(label.Text,size,label.Font,Vector2.new(textWidth,100000))
			if bounds.X<=textWidth and bounds.Y<=textHeight*.96 then best,low=size,size+1 else high=size-1 end
		end
		return best
	end
	local aspect=QUIET.aspect
	local best=largest(cardWidth/aspect*QUIET.textSize.Y.Scale)
	if best<QUIET_MIN_TEXT then
		local bounds=TextService:GetTextSize(label.Text,QUIET_MIN_TEXT,label.Font,Vector2.new(textWidth,100000))
		-- 2% headroom so the minimum size itself passes the fit test after rounding.
		aspect=math.clamp(cardWidth*QUIET.textSize.Y.Scale*.96/(math.max(1,bounds.Y)*1.02),QUIET_MIN_ASPECT,QUIET.aspect)
		best=largest(cardWidth/aspect*QUIET.textSize.Y.Scale)
	end
	if self.cardAspect and self.cardAspect.AspectRatio~=aspect then self.cardAspect.AspectRatio=aspect end
	for _,limit in self.instructionLimits do limit.MaxTextSize=best end
end

function Commander:SetQuiet(quiet)
	if self.quiet == quiet then return end
	self.quiet = quiet
	local layout = if quiet then QUIET else FULL
	self.card.Size = layout.card
	if self.cardAspect then self.cardAspect.AspectRatio = layout.aspect end
	self.body.Position, self.body.Size, self.body.BackgroundTransparency = layout.bodyPosition, layout.bodySize, layout.bodyTransparency
	self.instruction.Position, self.instruction.Size = layout.textPosition, layout.textSize
	self.portrait.Visible = not quiet
	self:FitInstruction()
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
	elseif (not self.wasVisible or changed) and not self.app.reducedMotion and not self.quiet then
		Theme.Motion:Cancel(self.card,"guide-enter")
		self.card.Position=CARD_POSITION+UDim2.fromScale(0,.008)
		Theme.Motion:Tween(self.card,"guide-enter",{Position=CARD_POSITION},ENTER_SECONDS)
		self.portrait.Rotation=-6
		Theme.Motion:Tween(self.portrait,"guide-salute",{Rotation=0},.24)
	elseif self.app.reducedMotion or self.quiet then
		Theme.Motion:Cancel(self.card,"guide-enter");self.card.Position=CARD_POSITION
		Theme.Motion:Cancel(self.portrait,"guide-salute");self.portrait.Rotation=0
	end
	self.card.Visible,self.wasVisible=visible,visible
	-- Top-centre priority: a lesson card hides the Hill banner (HillHud reads this).
	self.lessonVisible=visible and not self.quiet
	local app=self.app
	-- Notices sit below the card, so move a showing one when the card appears, hides or resizes.
	local layout=if visible then (if self.quiet then "quiet" else "lesson") else "hidden"
	if layout~=self.noticeLayout then
		self.noticeLayout=layout
		if app.PlaceNotice then app:PlaceNotice() end
	end
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

function Commander:InputKind()
	return if UserInputService.PreferredInput==Enum.PreferredInput.Touch then "Touch"
		elseif UserInputService.PreferredInput==Enum.PreferredInput.Gamepad then "Gamepad" else "Keyboard"
end

function Commander:Signal(signal)
	self.app:Request("TutorialSignal",{signal=signal,input=self:InputKind()})
end

function Commander:ClearFocus()
	self.pointerGuide:SetTarget(nil,self.app.reducedMotion)
end

function Commander:Focus(target,placement)
	self.pointerGuide:SetTarget(target,self.app.reducedMotion,placement)
end

-- Arrow spots in the target's own size (GuideFocus.Placement). Hotbar slots sit side by
-- side, so their arrow comes from above, pointing down (October 20 playtest).
local ABOVE: GuideFocus.Placement={offset=Vector2.new(0,-1),size=.8}
-- A hex with hexes on all six sides: a short arrow in the gap just under it, between
-- the two lower hexes and above their names.
local UNDER_HEX: GuideFocus.Placement={offset=Vector2.new(0,.68),size=.32}
local HEX_ARROW=.6 -- Share of a hex's height: fits inside the empty cell beside it.
type Grid={step:number,row:number,width:number,height:number}

-- October 20 playtest: beside a hex, the arrow covered the next hex's name. It rests in
-- an empty neighbouring cell instead (TutorialGuide.PointerSide), on the map's own grid.
function Commander:HexPlacement(id:string):GuideFocus.Placement?
	local research=self.app.research
	local grid:Grid?,view=research.Grid,research.nodes[id]
	if type(grid)~="table" or not view then return nil end
	local hex=grid :: Grid
	local button:GuiObject=view.button
	local scale=button.AbsoluteSize.Y/hex.height
	local center=button.AbsolutePosition+button.AbsoluteSize/2
	local area,areaSize=research.root.AbsolutePosition,research.root.AbsoluteSize
	local margin=button.AbsoluteSize.Y*HEX_ARROW/2
	local function step(side:{number}):Vector2 return Vector2.new(hex.step*(side[1]+side[2]/2),hex.row*side[2]) end
	local function shown(other:string):boolean
		local neighbour=research.nodes[other]
		return neighbour~=nil and neighbour.button.Visible
	end
	-- Skip cells whose arrow would leave the screen.
	local function fits(side:{number}):boolean
		local at=center+step(side)*scale
		return at.X-margin>=area.X and at.X+margin<=area.X+areaSize.X and at.Y-margin>=area.Y and at.Y+margin<=area.Y+areaSize.Y
	end
	local side=Guide.PointerSide(id,shown,fits)
	if not side then return UNDER_HEX end
	local cell=step(side)
	return {offset=Vector2.new(cell.X/hex.width,cell.Y/hex.height),size=HEX_ARROW}
end

-- The guided Upgrades hex: the HUD Upgrades button, the hex itself, or the Open or
-- Back hex on the way to its map. In My Army, the Flock or Army "+" opens the same
-- hex (October 20 launch review: Expand quitters opened My Army, not Upgrades).
function Commander:UpgradeTarget(nodeId:string,inTree:boolean,inArmy:boolean):(any,GuideFocus.Placement?)
	local app=self.app
	local node=CashNodes.Nodes[nodeId]
	if not node then return nil,nil end
	if inTree then
		local research=app.research
		local category=research.category or "Main"
		local open=CashNodes.OpenNode(node.category)
		local show=if node.category==category then nodeId
			elseif category=="Main" then (open and open.id) else CashNodes.Roots[category]
		local view=show and research.nodes[show]
		if not view then return nil,nil end
		return view.button,self:HexPlacement(show)
	end
	if inArmy then
		local browser=app.chickenBrowser
		return if node.family=="Flock" then browser.flockPlus elseif node.family=="ArmySize" then browser.capacityPlus else nil,nil
	end
	return if app.panel.Visible then nil else app.hud.shortcuts:FindFirstChild("Upgrades"),nil
end

-- A tool's hotbar slot: S11b's anchor over that slot in Roblox's own hotbar, then its
-- single hotbar anchor, then the older custom dock's slot (which hides behind menus).
function Commander:ToolSlot(name:string):GuiObject?
	local tools=self.app.tools
	if not tools then return nil end
	local anchors=tools.hintAnchors
	local anchor=(if type(anchors)=="table" then anchors[name] else nil) or tools.hintAnchor
	if typeof(anchor)=="Instance" and anchor:IsA("GuiObject") then return anchor end
	local dock=tools.dock
	local slot=dock and dock.slots and dock.slots[name]
	return slot and slot.button
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
	local current=Guide.Resolve(state,self:InputKind())
	if self.completedBeforeVisit and current and current.id=="Complete" then current=nil end
	-- The victory line stays eight seconds, then the same strip carries a
	-- snapshot-derived next goal (also for players who finished earlier).
	if current and current.id=="Complete" then
		if self.step=="Complete" and os.clock()-self.stepAt>=8 then self.completeShown=true end
		if self.completeShown then
			if not self.sent.Finish then self.sent.Finish=true;self:Signal("Finish") end
			current=nil
		end
	end
	if not current then current=Guide.NextGoal(state) end
	-- A live Hill round takes the top slot; quiet next-goal lines wait (lessons never do).
	if current and current.goal and app.hud and app.hud.hill and app.hud.hill.bannerVisible then current=nil end
	-- A lesson flipping to done queues the celebration until the card can show it.
	local facts=Guide.Facts(state)
	if self.facts and current and not current.goal then
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
			or ((id=="Deploy" or string.sub(id,1,12)=="Goal:Attack:") and prompt.Name=="ArmyCommandPrompt") then atTarget=true end
	end
	-- Let the game's native action prompt take over when the player reaches it.
	-- Notices no longer hide the card; AppController:NoticePosition places them below it.
	local visible=not app.panel.Visible and not inTree and not blocked and not atTarget
	local quiet=current.goal==true
	self:SetQuiet(quiet)
	self:SetInstruction(if quiet then "Next: "..current.text else current.text,visible and self.pendingType and not quiet)
	if visible then self.pendingType=false end
	self:Present(visible,changed)
	if visible and self.celebrate then self.celebrate=false;self:Celebrate() end
	if inTree~=self.wasTree then
		self.wasTree=inTree;self:Signal(if inTree then "TreeOpen" else "TreeClose")
	end
	-- The Flock Size I and Army Size I lessons center their hex once per tree visit,
	-- including when the second lesson starts with the tree still open.
	local lessonNode=if id=="Flock" or id=="Expand" then current.node else nil
	if not inTree then
		self.centered=nil
	elseif lessonNode and self.centered~=lessonNode and app.research.nodes[lessonNode] then
		self.centered=lessonNode
		app.research:Center(lessonNode)
		if UserInputService.GamepadEnabled then app.research:Select(lessonNode,true);GuiService.SelectedObject=app.research.nodes[lessonNode].button end
	end
	if inArmy~=self.wasArmy then self.wasArmy=inArmy;self:Signal(if inArmy then "ArmyOpen" else "ArmyClose") end
	local target,placement
	local where=current.target
	local exit=app.research.exit or app.research.root:FindFirstChild("Exit",true)
	if blocked then
		target=nil
	elseif id=="Select" then
		target=if inTree then exit elseif inArmy then app.chickenBrowser.best elseif not app.panel.Visible then app.hud.army else nil
	elseif id=="Deploy" then
		-- October 20 launch review: 60% of Deploy quitters were still inside Upgrades.
		target=if inTree then exit else nil
	elseif where=="Upgrades" and current.node then
		target,placement=self:UpgradeTarget(current.node,inTree,inArmy)
		if id=="Expand" and inTree and app.research.selected==current.node and not self.sent.NodeInspect then
			self.sent.NodeInspect=true;self:Signal("NodeInspect")
		end
	elseif where=="VacuumTool" or where=="FeedTool" then
		target=if app.panel.Visible or inTree then nil else self:ToolSlot(if where=="VacuumTool" then "EggVacuum" else "ChickenFeed")
		placement=if target then ABOVE else nil
	elseif where=="Rebirth" then
		target=if app.panel.Visible or inTree then nil else app.hud.reenlist
	end
	self:Focus(target,placement)
end

function Commander:Destroy()
	self:CancelTypewriter()
	self.alive=false;self:ClearFocus();self:Present(false)
	self.pointerGuide:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	self.root:Destroy()
end

return Commander
