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
-- October 21 (Stevin, like the Drop a Fruit tutorial): the tutorial's payoff line holds
-- this long, with confetti, before Daily Rewards may open.
local CORE_SECONDS = 4
-- October 23 tips: a finished chain's "TIP • COMPLETE!" line holds this long.
local TIP_PAYOFF_SECONDS = 4
-- The card and its pointer sit under the menus (OTHER layer, ZIndex 25/24); over the
-- Rebirth screen (ZIndex 30) the Rebirth tip lifts both above it.
local CARD_Z, POINTER_Z, OVER_MENU_Z = 25, 24, 32
local TAP_WORD = {Touch="TAP!", Gamepad="R2!", Keyboard="CLICK!"}
local Commander = {}
Commander.__index = Commander

function Commander.new(app)
	-- October 23 tips: chains seen this visit, chains paid off, when each timed card first
	-- showed, and the card ids dismissed (Guide.Resolve skips them).
	local self = setmetatable({app=app, connections={}, sent={}, prompts={}, alive=true,wasTree=false,wasArmy=false,
		tipSeen={}, tipPaid={}, tipShownAt={}, tipSkip={}}, Commander)
	local root = Theme.InsetContainer(app.other, "CommanderGuide", Enum.ScreenInsets.CoreUISafeInsets)
	root.ZIndex, root.Visible = CARD_Z, false
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
	self.instruction.Position,self.instruction.Size=UDim2.fromScale(.18,.33),UDim2.fromScale(.795,.53)
	self.instruction.TextXAlignment=Enum.TextXAlignment.Center
	-- "TUTORIAL • 2/7" / "TIP • 3/5" over the instruction (October 21; the count is
	-- TutorialGuide's, seven cards since October 24).
	self.tag=Theme.Label(card,"Step","",14,Theme.Arcade.gold)
	self.tag.Position,self.tag.Size=UDim2.fromScale(.18,.15),UDim2.fromScale(.795,.19)
	self.tag.TextXAlignment,self.tag.TextScaled,self.tag.ZIndex=Enum.TextXAlignment.Center,true,5
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
	-- only text/frame changes remeasure, never a frame-by-frame loop. The guide card
	-- stays one line.
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
	-- Top-centre priority: a lesson card hides the Hill banner (HillHud reads this).
	self.lessonVisible=visible
	local app=self.app
	-- Notices sit below the card, so move a showing one when the card appears, hides or resizes.
	local layout=if visible then "lesson" else "hidden"
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

-- The tutorial's payoff: Guide.CompleteText on the card for CORE_SECONDS and confetti across the
-- screen. Daily Rewards waits for it (DailyRewardController:Blocked). Presentation only.
function Commander:Celebrating(): boolean
	local payoff=self.payoff
	return payoff~=nil and os.clock()-payoff.at<payoff.seconds
end

-- A payoff line holds the card for `seconds` (the core's ending, the vacuum tip's).
function Commander:Payoff(text:string,tag:string,seconds:number)
	self.payoff={text=text,tag=tag,seconds=seconds,at=os.clock()}
	task.delay(seconds+.05,function() if self.alive then self:Update() end end)
end

function Commander:CelebrateCore()
	self:Payoff(Guide.CompleteText,"TUTORIAL COMPLETE!",CORE_SECONDS)
	self.app.audio:Play("SkillTreeResearchCompleted",nil,{noFallback=true,cooldown=.3})
	if self.app.reducedMotion then return end
	local holder=Theme.Container(self.root,"CoreConfetti")
	holder.ZIndex=30
	local colors={Theme.Arcade.gold,Theme.Arcade.green,Color3.fromRGB(80,200,255),Color3.fromRGB(255,90,170),Color3.new(1,1,1)}
	for i=1,40 do
		local piece=Theme.Frame(holder,"Confetti",UDim2.fromScale(.012,.024),colors[i%#colors+1])
		local x=math.random()
		piece.AnchorPoint,piece.Position,piece.Rotation,piece.ZIndex=Vector2.new(.5,.5),UDim2.fromScale(x,-.05),math.random(0,180),30
		local seconds=1.6+math.random()*1.2
		TweenService:Create(piece,TweenInfo.new(seconds,Enum.EasingStyle.Quad,Enum.EasingDirection.In),
			{Position=UDim2.fromScale(x+(math.random()-.5)*.25,1.05),Rotation=piece.Rotation+math.random(180,540)}):Play()
	end
	task.delay(3,function() holder:Destroy() end)
end

-- October 21: My Army stays hidden until the core is done, like the reference's
-- Fruits button. Only this guide hides it, so only this guide shows it again.
function Commander:SetArmyHidden(hidden:boolean)
	local hud=self.app.hud
	local button=hud and hud.army
	if not button then return end
	if hidden and not self.armyHidden then
		self.armyHidden=true;button.Visible=false
	elseif not hidden and self.armyHidden then
		self.armyHidden=false;button.Visible=true
		if not self.app.reducedMotion then
			local pop=button:FindFirstChild("GuidePop") or Instance.new("UIScale")
			pop.Name,pop.Scale,pop.Parent="GuidePop",.6,button
			TweenService:Create(pop,TweenInfo.new(.35,Enum.EasingStyle.Back),{Scale=1}):Play()
		end
	end
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

function Commander:Focus(target,placement,dim)
	self.pointerGuide:SetTarget(target,self.app.reducedMotion,placement,dim)
end

-- Arrow spots in the target's own size (GuideFocus.Placement). Hotbar slots sit side by
-- side, so their arrow comes from above, pointing down (October 20 playtest).
local ABOVE: GuideFocus.Placement={offset=Vector2.new(0,-1),size=.8}
-- A pointy-top hex with hexes on all six sides and no "?" beside it: a short arrow in
-- the gap just under it, between the two lower hexes and above their names.
local UNDER_HEX: GuideFocus.Placement={offset=Vector2.new(0,.68),size=.32}
-- Share of a hex's height: inside the cell beside it and clear of every other hex's
-- name, on pointy-top and flat-top maps alike (checked against both layouts).
local HEX_ARROW=.5
type Grid={step:number,row:number,width:number,height:number,Offset:((side:{number})->Vector2)?}

-- October 20 playtest: beside a hex, the arrow covered the next hex's name. It rests in
-- an empty neighbouring cell instead (TutorialGuide.PointerSide), on the map's own grid,
-- or else on a neighbouring "?" hex, which has no name to hide.
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
	-- A neighbour cell's centre in canvas pixels: the map's own Offset (flat-top hexes,
	-- Upgrades tree v2), or the pointy-top formula the map used before.
	local function step(side:{number}):Vector2
		return if hex.Offset then hex.Offset(side) else Vector2.new(hex.step*(side[1]+side[2]/2),hex.row*side[2])
	end
	-- Sideways first, then lower, then right, wherever the map draws each side.
	local order=table.clone(Guide.PointerSides)
	table.sort(order,function(a,b)
		local pa,pb=step(a),step(b)
		if math.abs(pa.X)~=math.abs(pb.X) then return math.abs(pa.X)>math.abs(pb.X) end
		if pa.Y~=pb.Y then return pa.Y>pb.Y end
		return pa.X>pb.X
	end)
	local function shown(other:string):boolean
		local neighbour=research.nodes[other]
		return neighbour~=nil and neighbour.button.Visible
	end
	local function coverable(other:string):boolean
		local neighbour=research.nodes[other]
		return neighbour~=nil and neighbour.look=="unknown"
	end
	-- Skip cells whose arrow would leave the screen.
	local function fits(side:{number}):boolean
		local at=center+step(side)*scale
		return at.X-margin>=area.X and at.X+margin<=area.X+areaSize.X and at.Y-margin>=area.Y and at.Y+margin<=area.Y+areaSize.Y
	end
	local side=Guide.PointerSide(id,shown,fits,order,coverable)
	if not side then return if hex.Offset then nil else UNDER_HEX end
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
	-- October 21: Daily Rewards now opens mid-guide; its popup is never dimmed or covered.
	local blocked=app.dialogueActive or (app.offlineCash and app.offlineCash.gui~=nil) or (app.intro~=nil and app.intro:Pending())
		or (app.dailyReward~=nil and app.dailyReward.gui~=nil) or (app.marchFilm~=nil and app.marchFilm.playing)
	local character=Players.LocalPlayer.Character
	if not self.ready and not blocked and character and character:FindFirstChild("HumanoidRootPart") then
		self.ready=true;self:Signal("Ready")
	end
	local skip:{[string]:boolean}=self.tipSkip
	local tutorial:any=state.tutorial or {}
	local current=Guide.Resolve(state,self:InputKind(),skip)
	-- October 23: a timed tip card (the Gem Upgrade card) leaves after its seconds on
	-- screen; its chain ends there for this visit (a payoff follows if it was seen).
	if current and current.seconds and self.tipShownAt[current.id]
		and os.clock()-self.tipShownAt[current.id]>=current.seconds then
		self.tipSkip[current.id]=true;skip[current.id]=true
		current=Guide.Resolve(state,self:InputKind(),skip)
	end
	if self.completedBeforeVisit and current and current.id=="Complete" then current=nil end
	-- A tip means the completion moment is over: the completion card never comes back
	-- (and the tutorial's guidance has ended, for the funnel's Finish).
	if current and current.chain then
		self.completeShown=true
		if not self.sent.Finish and tutorial.guideCompleted==true then self.sent.Finish=true;self:Signal("Finish") end
	end
	-- The victory line stays eight seconds, then the same strip carries a
	-- snapshot-derived next goal (also for players who finished earlier).
	if current and current.id=="Complete" then
		if self.step=="Complete" and os.clock()-self.stepAt>=8 then self.completeShown=true end
		if self.completeShown then
			if not self.sent.Finish then self.sent.Finish=true;self:Signal("Finish") end
			current=nil
		end
	end
	-- Later October 21 (Stevin): no instructions after the tutorial, so nothing follows
	-- the completion card (the old quiet "Next:" goals are gone). October 23: tips do.
	-- A lesson flipping to done queues the celebration until the card can show it.
	local facts=Guide.Facts(state)
	if self.facts and not self.completedBeforeVisit then
		if facts.Core and not self.facts.Core then self:CelebrateCore() end
	end
	-- October 23: a tip chain the player saw ends with "TIP • COMPLETE!" and its line,
	-- once it is learned or its last (timed) card has left.
	for _,chain in Guide.Tips do
		if self.tipSeen[chain.id] and not self.tipPaid[chain.id] and not self:Celebrating() then
			local ended=chain.done(facts,state)
			for _,card in chain.cards do if card.seconds and skip[card.id] then ended=true end end
			if ended then
				self.tipPaid[chain.id]=true;self.celebrate=true
				self:Payoff(chain.payoff,"TIP • COMPLETE!",TIP_PAYOFF_SECONDS)
			end
		end
	end
	-- The payoff shares the Complete card's id, so the line types once and its 8 s count on.
	if self:Celebrating() then current={id="Complete",text=self.payoff.text,tag=self.payoff.tag} end
	-- My Army shows again once the tutorial is complete (also an early Camp win's).
	self:SetArmyHidden(current~=nil and not facts.Core and tutorial.guideCompleted~=true
		and tutorial.starterArmy==true and not self.completedBeforeVisit)
	if self.facts and current then
		if current.chain then
			-- A tip ticks when its chain moves to its next card (the vacuum bought, Rebirth 0 done).
			if self.tipChain==current.chain and self.tipStep~=current.id then self.celebrate=true end
		else
			for _,milestone in Guide.Milestones do
				if facts[milestone] and not self.facts[milestone] then self.celebrate=true end
			end
		end
	end
	if current and current.chain then self.tipChain,self.tipStep=current.chain,current.id end
	self.facts=facts
	self.current=current
	-- October 25 (Stevin): nothing but the guide card during the tutorial
	-- (Hud:SetTutorialStage). The Coins come in with the first money, the Upgrades button
	-- with card 5 (claim Start), everything else once the tutorial is over. Read from the
	-- saved facts, not the card on screen, so a hidden card never flashes the HUD in.
	local _,lessonIndex=Guide.Progress(facts)
	local inTutorial=not facts.Core and tutorial.guideCompleted~=true and tutorial.starterArmy==true
		and not self.completedBeforeVisit
	local hudStage=if not inTutorial then nil elseif lessonIndex>=5 then "upgrades"
		elseif facts.Sell or (tonumber(state.coins) or 0)>0 then "coins" else "bare"
	if app.hud and app.hud.SetTutorialStage then app.hud:SetTutorialStage(hudStage) end
	-- October 24 (Stevin): the egg hint (the lit egg with its tapping hand, the Click badge
	-- on every other ready egg) follows the shared rule TutorialGuide.EggHint: on from the
	-- first chicken through the tutorial and the first tips until the Egg Vacuum is owned,
	-- card or no card (EggController hides it while a menu is open). The badges name the
	-- player's input, so a change of input restyles them.
	local input=self:InputKind()
	local eggHint=Guide.EggHint(state,facts)
	if app.eggs and app.eggs.SetGuideHint and (eggHint~=self.eggHint or (eggHint and input~=self.eggHintInput)) then
		self.eggHint,self.eggHintInput=eggHint,input
		app.eggs:SetGuideHint(eggHint,TAP_WORD[input],input)
	end
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
	-- October 21 (one action per line, like the reference): the words for opening the
	-- menu, switching the Upgrades category or equipping the tool come first.
	local character=Players.LocalPlayer.Character
	local holdingVacuum=character~=nil and character:FindFirstChild("EggVacuum")~=nil
	-- October 23: the Rebirth screen (Rebirth 0 tip and its Gem Upgrades card).
	local rebirthPanel=app.rebirthPanel
	local inRebirth=rebirthPanel~=nil and rebirthPanel.gui~=nil and not rebirthPanel.closing
	local text=current.text
	-- A tip numbers each of its lines; the line shown picks the number (TutorialGuide tipCard).
	local index=current.index
	if current.outside then
		local open=if current.target=="Upgrades" then inTree elseif id=="Select" then inArmy
			elseif current.target=="VacuumTool" then holdingVacuum elseif current.target=="Rebirth" then inRebirth else true
		local node=current.node and CashNodes.Nodes[current.node]
		if not open then text,index=current.outside,current.outsideIndex or index
		elseif current.wrongTab and inTree and node and (app.research.category or "Main")~=node.category then
			text,index=current.wrongTab,current.wrongTabIndex or index
		end
	end
	if text~=self.lessonText then self.lessonText=text;self.pendingType=true end
	-- The egg lesson (card 3, and the collect-more step) also turns the camera to the lit
	-- egg once (TurnToEgg); the hint itself is on longer (above).
	local eggLesson=id=="Collect" or id=="RecoverCollect"
	if eggLesson~=self.eggLesson then self.eggLesson,self.eggCharacter=eggLesson,nil end
	if eggLesson then self:TurnToEgg(character,blocked) end
	-- Keep menu headers and controls unobstructed; the arrow points beside their relevant control.
	local atTarget=false
	for prompt in self.prompts do
		if not prompt.Parent then self.prompts[prompt]=nil
		elseif (current.target=="RollStation" and prompt:FindFirstAncestor("RollStation"))
			or (id=="Deploy" and prompt.Name=="ArmyCommandPrompt") then atTarget=true end
	end
	-- Let the game's native action prompt take over when the player reaches it.
	-- Notices no longer hide the card; AppController:NoticePosition places them below it.
	-- Menu lessons stay on screen over their menu, above the dimmed screen (the reference).
	local menuLesson=current.outside~=nil
	local visible=(menuLesson or (not app.panel.Visible and not inTree)) and not blocked and not atTarget
	self:SetInstruction(text,visible and self.pendingType)
	self.tag.Text=if current.tag and index then current.tag.." • "..index.."/"..current.total
		elseif current.tag then current.tag elseif id=="Complete" then "TUTORIAL COMPLETE!" else ""
	if visible then self.pendingType=false end
	self:Present(visible,changed)
	if visible and self.celebrate then self.celebrate=false;self:Celebrate() end
	-- October 23 tips: a chain counts as seen once one of its cards is on screen; a timed
	-- card counts its seconds from then. The Camp tip reports itself once (CampTip).
	if visible and current.chain then
		self.tipSeen[current.chain]=true
		if current.seconds and not self.tipShownAt[id] then
			self.tipShownAt[id]=os.clock()
			task.delay(current.seconds+.05,function() if self.alive then self:Update() end end)
		end
		if id=="TipAttack" and not self.sent.CampTip then self.sent.CampTip=true;self:Signal("CampTip") end
	end
	if inTree~=self.wasTree then
		self.wasTree=inTree;self:Signal(if inTree then "TreeOpen" else "TreeClose")
	end
	-- An Upgrades lesson or tip (Start, Flock Size I, the Egg Vacuum) centers its hex once
	-- per tree visit, including when the next one starts with the tree still open.
	local lessonNode=if current.target=="Upgrades" then current.node else nil
	local lessonView=lessonNode and CashNodes.Nodes[lessonNode]
	if not inTree then
		self.centered=nil
	elseif lessonNode and self.centered~=lessonNode and app.research.nodes[lessonNode]
		and lessonView and lessonView.category==(app.research.category or "Main")
		-- October 25 (Stevin): the plot lesson (card 6) leaves the map where it is and only
		-- rings its hex; the map does not pan to it.
		and current.id~="Expand" then
		self.centered=lessonNode
		app.research:Center(lessonNode)
		if UserInputService.GamepadEnabled then app.research:Select(lessonNode,true);GuiService.SelectedObject=app.research.nodes[lessonNode].button end
	end
	if inArmy~=self.wasArmy then self.wasArmy=inArmy;self:Signal(if inArmy then "ArmyOpen" else "ArmyClose") end
	-- Guide signals (TutorialService; the schema 15 Onboarding funnel ignores them, the
	-- guide.* ledger keys still use them): the Tools map and the vacuum in hand.
	local inTools=inTree and app.research.category=="Tools"
	if inTools~=self.wasTools then self.wasTools=inTools;if inTools then self:Signal("ToolsOpen") end end
	if holdingVacuum~=self.wasHolding then self.wasHolding=holdingVacuum;if holdingVacuum then self:Signal("VacuumEquip") end end
	local target,placement
	local where=current.target
	-- Menu lessons dim the screen around their control (October 23: and the Rebirth tips).
	local dim=where=="Upgrades" or where=="VacuumTool" or id=="Select" or id=="Deploy" or where=="Rebirth" or where=="Gems"
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
		-- Once the vacuum is in hand the lesson is walking, so the slot needs no arrow.
		target=if app.panel.Visible or inTree or (where=="VacuumTool" and holdingVacuum) then nil
			else self:ToolSlot(if where=="VacuumTool" then "EggVacuum" else "ChickenFeed")
		placement=if target then ABOVE else nil
	elseif where=="Rebirth" or where=="Gems" then
		-- October 23: in the Rebirth screen, its Rebirth button (Rebirth 0) or its Gem
		-- Upgrades; outside it, the HUD Rebirth button that opens it.
		if inRebirth and rebirthPanel then
			local grid=rebirthPanel.grid
			target=if where=="Rebirth" then rebirthPanel.rebirthButton
				elseif grid and grid.scroll then grid.scroll.Parent else nil
		else
			target=if app.panel.Visible or inTree then nil else app.hud.reenlist
		end
	end
	-- Over the Rebirth screen the card, the dim and the ring draw above it.
	local over=inRebirth and (where=="Rebirth" or where=="Gems") and target~=nil
	self.root.ZIndex=if over then OVER_MENU_Z else CARD_Z
	self.pointerGuide.root.ZIndex=if over then OVER_MENU_Z-1 else POINTER_Z
	self:Focus(target,placement,dim)
end

-- October 23 (first-minute fix): on a phone the spawn used to face the lane and the lit
-- egg sat behind the camera. If the hinted egg is still off screen a second after the
-- egg lesson shows, turn the camera to it once: yaw only, from where it is (the camera
-- stays with the player). Reduced motion snaps. Once more after a respawn.
function Commander:TurnToEgg(character,blocked)
	local app=self.app
	if character~=self.eggCharacter then self.eggCharacter,self.eggLessonAt,self.cameraTurned=character,os.clock(),false end
	if self.cameraTurned or blocked or not character or os.clock()-self.eggLessonAt<0.25 then return end
	local camera=workspace.CurrentCamera
	if not camera or camera.CameraType==Enum.CameraType.Scriptable or app.panel.Visible or app.research.root.Visible then return end
	if not (app.eggs and app.eggs.GuideTarget) then return end
	local onScreen,at=app.eggs:GuideTarget()
	if onScreen~=false or not at then return end
	self.cameraTurned=true
	local from=camera.CFrame
	local flat=Vector3.new(at.X-from.Position.X,0,at.Z-from.Position.Z)
	if flat.Magnitude<0.5 then return end
	local look=from.LookVector
	local horizontal=math.sqrt(math.max(0,1-look.Y*look.Y))
	local newLook=(flat.Unit*horizontal+Vector3.new(0,look.Y,0)).Unit
	local target=CFrame.lookAt(from.Position,from.Position+newLook)
	-- The default camera keeps its own heading and undoes a plain CFrame write (checked in
	-- Studio), so turn it while Scriptable and hand it back a frame later. ScreenFeel and
	-- RollCamera skip a Scriptable camera, so nothing fights the turn.
	camera.CameraType=Enum.CameraType.Scriptable
	local function handBack()
		task.defer(function() if camera.CameraType==Enum.CameraType.Scriptable then camera.CameraType=Enum.CameraType.Custom end end)
	end
	if app.reducedMotion then camera.CFrame=target;handBack();return end
	local tween=TweenService:Create(camera,TweenInfo.new(0.4,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=target})
	tween.Completed:Once(handBack)
	tween:Play()
end

function Commander:Destroy()
	self:CancelTypewriter()
	if self.app.hud and self.app.hud.SetTutorialStage then self.app.hud:SetTutorialStage(nil) end
	if self.eggHint and self.app.eggs then self.app.eggs:SetGuideHint(false) end
	self:SetArmyHidden(false)
	self.alive=false;self:ClearFocus();self:Present(false)
	self.pointerGuide:Destroy()
	for _,connection in self.connections do connection:Disconnect() end
	self.root:Destroy()
end

return Commander
