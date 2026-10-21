--!strict
-- October 20 hand tools, client side (docs/team/COLLECTION_TOOLS.md). The Egg Vacuum
-- and Chicken Feed are real Tools in Roblox's own hotbar (Stevin, October 20): Roblox
-- equips them by slot key, tap or gamepad. This keeps that hotbar switched on, shows
-- the vacuum's "carried / capacity" pill above the hotbar, gives the Commander guide
-- one invisible anchor over each tool's slot (hintAnchors), and puts the native Feed
-- prompt on the nearest of your chickens at home. ToolService owns the tools, levels
-- and Coins.
-- October 21 game feel (docs/team/GAME_FEEL_20261021.md): the fill flashes and the
-- count punches; full, the pill glows red, floats "Full!" and plays "VacuumFull". A
-- confirmed Feed crunches, puffs crumbs, flashes the chicken in its rarity colour, hops
-- it (DuckAnimator) and clucks. Budgets in CollectionFeel.Feel.
-- October 21 reference parity (P6, docs/team/REFERENCE_PARITY_20261021.md 2.6): the
-- counter is the reference's dark translucent pill centred above the hotbar ("14 / 25"
-- on a gold fill), with the prompt line under it: "[hand] Collect (Hold)" ("(Tap)" on
-- touch, the R2 glyph on a gamepad) and "[coin] Sell on the pad". Only the words and
-- glyph change with the input; the layout is one Scale layout for every device. A full
-- pill shakes and plays "Locked" when it refuses an egg in reach (VacuumRefused).
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local StarterGui=game:GetService("StarterGui")
local GuiService=game:GetService("GuiService")
local TextService=game:GetService("TextService")
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Config=require(Shared.Config)
local Feel=require(Shared.CollectionFeel)
local Tools=require(Shared.VacuumConfig)
local Theme=require(script.Parent.UITheme)
local Controller={}
Controller.__index=Controller

local POLL_SECONDS=0.1
local PROMPT_LIFT=Vector3.new(0,1.2,0)
-- Roblox's hotbar (CoreGui BackpackScript): 60 px slots (100 px on consoles) with
-- 5 px gaps, at the bottom of the whole screen. Only filled slots show, centred,
-- and a new tool takes the lowest free slot. Our anchors follow that.
local ICON=if GuiService:IsTenFootInterface() then 100 else 60
local GAP=5
-- Pixels up from the screen's bottom that Roblox's hotbar and a 10 px margin take: the
-- vacuum pill sits right above (75 with 60 px slots, 115 with consoles' 100 px slots).
-- The pill and its prompt line then take PillHeight of the screen height above that, so
-- anything else at the bottom centre clears BottomReserve px + PillHeight.
Controller.BottomReserve=ICON+GAP+10
Controller.PillHeight=118/1014
-- The pill's composition, measured on the reference recording (1014 px tall): a 602 x 118
-- box holding the 248 x 58 pill at the top and the 34 px prompt row at its foot, with a
-- gap in the middle of the row between the two hints.
local BOX_ASPECT=602/118
local PILL_W,PILL_H=248/602,58/118
local ROW_Y,ROW_H=84/118,34/118
local ROW_ASPECT=602/34
local ROW_GAP=0.06 -- Share of the row between the two hints.
local HALF=(1-ROW_GAP)/2
local HAND="rbxassetid://74062853444480" -- The egg-click hand (assets/egg-hover-cursor-20261021).
local GOLD=Theme.Arcade.gold
local RED=Theme.Arcade.red
-- Feed crumbs: yellow grain to green.
local CRUMBS=ColorSequence.new(Color3.fromRGB(236,206,96),Color3.fromRGB(158,214,92))

function Controller.new(app)
 local self=setmetatable({app=app,connections={},nextPollAt=0,slots={},hintAnchors={},anchorFrames={}},Controller)
 -- Roblox's own hotbar is the tool bar now; a cutscene restores whatever it saved.
 pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,true) end)
 -- The hotbar is drawn on the whole screen, not inside the device safe area.
 self.screen=Theme.InsetContainer(app.hudLayer,"ToolHotbar",Enum.ScreenInsets.None)
 self.pill=Controller.BuildPill(self.screen)
 self:BuildPrompt()
 table.insert(self.connections,RunService.Heartbeat:Connect(function() self:Step(os.clock()) end))
 table.insert(self.connections,Players.LocalPlayer.CharacterAdded:Connect(function() table.clear(self.slots) end))
 return self
end

function Controller:Blocked(): boolean
 local app=self.app
 if app.panel.Visible or app.dialogueActive==true then return true end
 if app.research and app.research.root and app.research.root.Visible then return true end
 if app.commerce and app.commerce.cratePresenting then return true end
 local camera=workspace.CurrentCamera
 return camera==nil or camera.CameraType==Enum.CameraType.Scriptable
end

-- The game tool in the local player's hand.
function Controller:Held(): Tool?
 local character=Players.LocalPlayer.Character
 local tool=character and character:FindFirstChildOfClass("Tool")
 return if tool and tool:GetAttribute("PetRollTool")~=nil then tool else nil
end

-- Mirrors which hotbar slot each tool holds: a slot frees when its tool leaves both
-- the Backpack and the character, and a new tool takes the lowest free slot (tools
-- that arrive together go in the order ToolService gives them).
function Controller:TrackSlots(): {Tool}
 local player=Players.LocalPlayer
 local containers: {Instance}={}
 local backpack=player:FindFirstChildOfClass("Backpack")
 if backpack then table.insert(containers,backpack) end
 if player.Character then table.insert(containers,player.Character) end
 local present: {[Tool]: boolean}={}
 local arrivals: {Tool}={}
 for _,container in containers do
  for _,item in container:GetChildren() do
   if item:IsA("Tool") then present[item]=true end
  end
 end
 for index,tool in self.slots do if not present[tool] then self.slots[index]=nil end end
 local tracked: {[Tool]: boolean}={}
 for _,tool in self.slots do tracked[tool]=true end
 for tool in present do if not tracked[tool] then table.insert(arrivals,tool) end end
 local order=Tools.ToolOrder
 table.sort(arrivals,function(a,b)
  local ia,ib=table.find(order,a.Name) or #order+1,table.find(order,b.Name) or #order+1
  return if ia==ib then a.Name<b.Name else ia<ib
 end)
 for _,tool in arrivals do
  local index=1
  while self.slots[index] do index+=1 end
  self.slots[index]=tool
 end
 local filled: {Tool}={}
 local indices={}
 for index in self.slots do table.insert(indices,index) end
 table.sort(indices)
 for _,index in indices do table.insert(filled,self.slots[index]) end
 return filled
end

-- One invisible, non-interactive anchor over each of our tools' hotbar slots for the
-- Commander guide (hintAnchors.EggVacuum / .ChickenFeed; nil while not owned).
function Controller:PlaceAnchors(filled: {Tool}): number
 local count=#filled
 local right=0
 local shown: {[string]: boolean}={}
 for visual,tool in filled do
  local center=(visual-(count/2+0.5))*(ICON+GAP)
  right=math.max(right,center+ICON/2)
  local name=tool:GetAttribute("PetRollTool")
  if type(name)=="string" and not shown[name] then
   shown[name]=true
   local frame=self.anchorFrames[name]
   if not frame then
    frame=Instance.new("Frame")
    frame.Name="HotbarAnchor"..name
    frame.BackgroundTransparency,frame.BorderSizePixel=1,0
    frame.Active,frame.Selectable,frame.Interactable=false,false,false
    frame.Size=UDim2.fromOffset(ICON,ICON)
    frame.Parent=self.screen
    self.anchorFrames[name]=frame
   end
   frame.Position=UDim2.new(0.5,center-ICON/2,1,-(GAP+ICON))
   frame.Visible=true
  end
 end
 for name,frame in self.anchorFrames do
  frame.Visible=shown[name]==true
  self.hintAnchors[name]=if shown[name] then frame else nil
 end
 return right
end

-- Width over height of one line of text in the game font, for Scale-only text boxes.
local function textAspect(text: string): number
 local size=TextService:GetTextSize(text,100,Theme.Font,Vector2.new(10000,1000))
 return size.X/math.max(1,size.Y)
end

export type Pill={box: Frame,pill: Frame,fill: Frame,count: TextLabel,collectGlyph: ImageLabel,collectText: TextLabel,
 sellGlyph: ImageLabel,sellText: TextLabel,input: string?}

-- One hint of the prompt row: a glyph and a word strip, packed against the row's middle.
local function hint(row: Frame,name: string,x: number,align: Enum.HorizontalAlignment): (ImageLabel,TextLabel)
 local half=Theme.Container(row,name)
 half.Position,half.Size=UDim2.fromScale(x,0),UDim2.fromScale(HALF,1)
 local layout=Instance.new("UIListLayout")
 layout.FillDirection,layout.SortOrder=Enum.FillDirection.Horizontal,Enum.SortOrder.LayoutOrder
 layout.HorizontalAlignment,layout.VerticalAlignment=align,Enum.VerticalAlignment.Center
 layout.Padding=UDim.new(0.25/ROW_ASPECT/HALF,0)
 layout.Parent=half
 local glyph=Instance.new("ImageLabel")
 glyph.Name,glyph.BackgroundTransparency,glyph.ScaleType="Glyph",1,Enum.ScaleType.Fit
 glyph.Size,glyph.LayoutOrder,glyph.ZIndex=UDim2.fromScale(1/ROW_ASPECT/HALF,1),1,4
 Theme.Aspect(glyph,1)
 glyph.Parent=half
 local label=Theme.Label(half,"Text","",24,Color3.new(1,1,1))
 label.LayoutOrder,label.TextXAlignment=2,Enum.TextXAlignment.Center
 -- The reference's soft dark strip behind each hint keeps it readable on bright grass.
 label.BackgroundColor3,label.BackgroundTransparency=Color3.new(0,0,0),0.6
 label.TextWrapped=false -- Before TextScaled: setting TextWrapped afterwards turns TextScaled off.
 label.TextScaled=true
 return glyph,label
end

-- The pill and its prompt row in `parent` (the full-screen hotbar layer, or a UI Lab
-- story frame). Hidden until RenderMeter shows it.
function Controller.BuildPill(parent: Instance): Pill
 local box=Theme.Container(parent,"VacuumPill")
 box.AnchorPoint,box.Position=Vector2.new(0.5,1),UDim2.new(0.5,0,1,-Controller.BottomReserve)
 box.Size,box.Visible=UDim2.fromScale(1,Controller.PillHeight),false
 Theme.Aspect(box,BOX_ASPECT)
 local pill=Theme.Frame(box,"Pill",UDim2.fromScale(PILL_W,PILL_H),Theme.OverlayColors.Top)
 pill.AnchorPoint,pill.Position,pill.BackgroundTransparency=Vector2.new(0.5,0),UDim2.fromScale(0.5,0),0.4
 Theme.Stroke(pill,Color3.new(0,0,0),2).Transparency=0.15
 local fill=Theme.Frame(pill,"Fill",UDim2.fromScale(0,1),GOLD)
 fill.BackgroundTransparency=0.45
 local count=Theme.Label(pill,"Count","0 / 0",30,Color3.new(1,1,1))
 count.AnchorPoint,count.Position,count.Size=Vector2.new(0.5,0.5),UDim2.fromScale(0.5,0.5),UDim2.fromScale(0.9,0.64)
 count.TextXAlignment=Enum.TextXAlignment.Center
 count.TextWrapped=false
 count.TextScaled=true
 local row=Theme.Container(box,"Prompt")
 row.Position,row.Size=UDim2.fromScale(0,ROW_Y),UDim2.fromScale(1,ROW_H)
 local collectGlyph,collectText=hint(row,"Collect",0,Enum.HorizontalAlignment.Right)
 local sellGlyph,sellText=hint(row,"Sell",HALF+ROW_GAP,Enum.HorizontalAlignment.Left)
 sellGlyph.Image=Theme.Assets.Coin
 Theme.ScaleText(box)
 local ui: Pill={box=box,pill=pill,fill=fill,count=count,collectGlyph=collectGlyph,collectText=collectText,
  sellGlyph=sellGlyph,sellText=sellText,input=nil}
 Controller.SetPillInput(ui,UserInputService.PreferredInput)
 return ui
end

-- The hint words and glyph for the player's input; the boxes keep the text's own
-- width (Scale), so the layout never moves. Holding the mouse or R2 keeps grabbing eggs
-- (EggController); a tap grabs one. The pad sells the vacuum and the bag together.
function Controller.SetPillInput(ui: Pill,input: Enum.PreferredInput)
 local key=input.Name
 if ui.input==key then return end
 ui.input=key
 local gamepad=input==Enum.PreferredInput.Gamepad
 local glyph=if gamepad then UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonR2) else ""
 ui.collectGlyph.Image=if glyph~="" then glyph else HAND
 local words={[ui.collectText]=if input==Enum.PreferredInput.Touch then "Collect (Tap)" else "Collect (Hold)",
  [ui.sellText]="Sell on the pad"}
 for label,text in words do
  label.Text=text
  label.Size=UDim2.fromScale(textAspect(text)*1.12/ROW_ASPECT/HALF,1)
 end
end

-- "N / cap" on a gold fill that tweens and flashes as eggs land (red, with a red flash,
-- once full); the count punches when it changes. Returns whether the pill is full.
function Controller.SetPillCount(ui: Pill,count: number,capacity: number,previous: number?): boolean
 local full=count>=capacity
 local text=Theme.Money(count).." / "..Theme.Money(capacity)
 if ui.count.Text~=text then
  ui.count.Text=text
  Theme.Motion:Punch(ui.count,1.12,0.22)
 end
 local ratio=math.clamp(count/capacity,0,1)
 if ratio~=previous then Theme.Motion:Progress(ui.fill,ratio,0.3,if full then RED else nil) end
 ui.fill.BackgroundColor3=if full then RED else GOLD
 return full
end

-- UI Lab: the pill as the Hud story shows it, with a fixture count (no connections).
-- LabStories' Render.Hud can add: require(ctx.code.ToolController).Preview(ctx.root,14,25)
function Controller.Preview(parent: Instance,count: number,capacity: number): Pill
 local ui=Controller.BuildPill(parent)
 Controller.SetPillCount(ui,count,math.max(1,capacity),nil)
 ui.fill.Size=UDim2.fromScale(math.clamp(count/math.max(1,capacity),0,1),1)
 ui.box.Visible=true
 return ui
end

function Controller:RenderMeter(held: Tool?)
 local ui=self.pill
 local tools=self.app.state and self.app.state.tools
 local vacuum=tools and tools.vacuum
 local shown=held~=nil and held.Name=="EggVacuum" and type(vacuum)=="table" and not self.app.panel.Visible
 Theme.Motion:Appear(ui.box,shown)
 if not shown then
  if self.meterGlow then
   Theme.Motion:StopGlow(ui.pill)
   Theme.Motion:StopGlow(ui.sellText)
   self.meterGlow=false
  end
  return
 end
 Controller.SetPillInput(ui,UserInputService.PreferredInput)
 local count,capacity=math.floor(vacuum.count or 0),math.max(1,math.floor(vacuum.capacity or 0))
 local full=Controller.SetPillCount(ui,count,capacity,self.meterRatio)
 self.meterRatio=math.clamp(count/capacity,0,1)
 -- Full: the pill's ring pulses red and the "Sell on the pad" hint glows gold until it empties.
 if full~=self.meterGlow then
  self.meterGlow=full
  if full then
   Theme.Motion:Glow(ui.pill,RED,3)
   Theme.Motion:Glow(ui.sellText,GOLD,2)
  else
   Theme.Motion:StopGlow(ui.pill)
   Theme.Motion:StopGlow(ui.sellText)
  end
 end
 if full and not self.meterFull then self:MeterFull() end
 self.meterFull=full
end

-- The pill just filled: "VacuumFull" (else "Collect" pitched up) and "Full!" floats up
-- off it. The red glow stays until it empties.
function Controller:MeterFull()
 self.fullAt=os.clock()
 local audio=self.app.audio
 if audio:Has("VacuumFull") then audio:Play("VacuumFull",nil,{voiceKey="VacuumFull",cooldown=0.5})
 else audio:Play("Collect",Feel.Feel.VacuumFullPitch,{voiceKey="VacuumFull",cooldown=0.5,maxDuration=0.6}) end
 local pill=self.pill.pill
 local centre=Theme.Motion:CenterOf(pill)-Vector2.new(0,pill.AbsoluteSize.Y*1.1)
 Theme.Motion:Float(self.screen,"Full!",Theme.Motion:Point(self.screen,centre),{color=RED,size=22,rise=0.05})
end

-- EggController: a full vacuum just got a new egg in reach that it cannot take. The
-- pill shakes (the "no") with a soft "Locked", at most once per FullShakeGap and never
-- right as it fills (that moment already floats "Full!").
function Controller:VacuumRefused(now: number)
 local knobs=Feel.Feel
 if not self.meterFull or not self.pill.box.Visible then return end
 if now-(self.fullAt or -10)<knobs.FullShakeGap or now-(self.lastRefusal or -10)<knobs.FullShakeGap then return end
 self.lastRefusal=now
 Theme.Motion:Shake(self.pill.pill,knobs.FullShakePixels)
 self.app:Cue("Locked",nil,nil,{voiceKey="VacuumRefused",cooldown=knobs.FullShakeGap})
end

-- One native prompt that rides on the nearest of your chickens at home.
function Controller:BuildPrompt()
 local folder=Instance.new("Folder")
 folder.Name="PetRollTools"
 local anchor=Instance.new("Part")
 anchor.Name="FeedPromptAnchor";anchor.Size=Vector3.one*0.2;anchor.Transparency=1;anchor.Anchored=true
 anchor.CanCollide,anchor.CanTouch,anchor.CanQuery,anchor.CastShadow=false,false,false,false
 anchor.Parent=folder
 local prompt=Instance.new("ProximityPrompt")
 prompt.Name,prompt.ActionText,prompt.ObjectText="FeedChickenPrompt","Feed",""
 prompt.HoldDuration,prompt.RequiresLineOfSight=0,false
 prompt.MaxActivationDistance=Tools.FeedRange
 prompt.Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton
 prompt.Enabled=false
 prompt.Parent=anchor
 folder.Parent=workspace
 self.folder,self.anchor,self.prompt=folder,anchor,prompt
 table.insert(self.connections,prompt.Triggered:Connect(function() self:Feed() end))
end

function Controller:UpdateTarget(feeding: boolean)
 local prompt=self.prompt
 local character=Players.LocalPlayer.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local state=self.app.state
 local world=workspace:FindFirstChild("PetRollWorld")
 local plot=state and world and world:FindFirstChild("Plot"..tostring(state.plotIndex))
 local pets=plot and plot:FindFirstChild("Pets")
 if not feeding or self:Blocked() or not root or not root:IsA("BasePart") or not pets then
  self.target=nil;prompt.Enabled=false;return
 end
 local best,bestDistance=nil,Tools.FeedRange
 for _,model in pets:GetChildren() do
  local part=model:IsA("Model") and model.PrimaryPart
  if part and model:GetAttribute("AtHome")~=false
   and (model:GetAttribute("OwnerUserId") or model:GetAttribute("OwnerId"))==Players.LocalPlayer.UserId then
   local distance=Vector2.new(part.Position.X-root.Position.X,part.Position.Z-root.Position.Z).Magnitude
   if distance<=bestDistance then best,bestDistance=model,distance end
  end
 end
 local pet=best and self.app:Pet(best:GetAttribute("PetId"))
 if not best or not pet then self.target=nil;prompt.Enabled=false;return end
 local definition=Catalog[pet.species]
 local name=if definition then definition.name else "Chicken"
 local level=pet.level or 1
 local maxed=level>=(pet.levelCap or Config.MaxPetLevel)
 -- "Duck · Lv 3 → 4" over "Feed · 9,000 Coins", at the server's quote.
 prompt.ObjectText=if maxed then name.." · Lv "..level else name.." · Lv "..level.." → "..(level+1)
 prompt.ActionText=if maxed then "Max level" else "Feed · "..Theme.Coins(pet.upgradePrice or 0)
 self.target={petId=pet.id,part=best.PrimaryPart,level=level,price=pet.upgradePrice,maxed=maxed}
 prompt.Enabled=true
end

function Controller:Feed()
 local target=self.target
 if not target or self:Blocked() then return end
 if target.maxed then self.app:Notify("This chicken is already at the max level.",false);return end
 self.app:Request("FeedChicken",{petId=target.petId,expectedLevel=target.level,expectedPrice=target.price})
end

function Controller:Step(now: number)
 if now>=self.nextPollAt then
  self.nextPollAt=now+POLL_SECONDS
  local held=self:Held()
  self:PlaceAnchors(self:TrackSlots())
  self:RenderMeter(held)
  self:UpdateTarget(held~=nil and held.Name=="ChickenFeed")
 end
 -- Chickens roam: the prompt follows its chicken every frame.
 local target=self.target
 local part=target and target.part
 if part and part.Parent then self.anchor.CFrame=CFrame.new(part.Position+PROMPT_LIFT) end
end

-- A fed chicken: the crunch and a crumbs puff at the chicken, a flash in its rarity
-- colour, a happy hop and, a beat later, a cluck. ChickenLabel and LevelUpBanner do
-- the text. A chicken that isn't in view keeps the old purchase burst at the player.
function Controller:Receive(_state,result)
 if not result or result.action~="FeedChicken" or not result.ok then return end
 local petId=result.petId
 local model=if type(petId)=="string" then self.app.base:HomePet(petId) else nil
 local part=if model and model:IsA("Model") then model.PrimaryPart else nil
 if not model or not part then
  self.app.feedback:Action("Income")
  return
 end
 local pet=self.app:Pet(petId)
 local definition=pet and Catalog[pet.species]
 local color=(definition and Theme.Rarities[definition.rarity]) or GOLD
 local audio,feel=self.app.audio,self.app.worldFeel
 local at=part.Position
 if audio:Has("FeedChicken") then audio:PlayAt("FeedChicken",at,nil,{voiceKey="FeedChicken",cooldown=0.1,pitchVariance=0.05})
 else audio:PlayAt("Collect",at,0.9,{voiceKey="FeedChicken",cooldown=0.1,maxDuration=0.5}) end
 if feel then
  feel:Poof(at-Vector3.new(0,0.5,0),{color=CRUMBS,count=8,size=0.5})
  feel:Highlight(model,color,0.6)
 end
 if self.app.animator then self.app.animator:Celebrate(model) end
 task.delay(Feel.Feel.HappyDelay,function()
  if not self.folder.Parent then return end
  local again=self.app.base:HomePet(petId)
  local root=if again and again:IsA("Model") then again.PrimaryPart else nil
  local where=if root then root.Position else at
  if audio:Has("ChickenHappy") then audio:PlayAt("ChickenHappy",where,nil,{voiceKey="ChickenHappy",cooldown=0.2,pitchVariance=0.06})
  else audio:PlayAt("CombatKnockoutCluck",where,Feel.Feel.HappyPitch,{voiceKey="ChickenHappy",cooldown=0.2,maxDuration=0.8}) end
 end)
end

function Controller:Destroy()
 for _,connection in self.connections do connection:Disconnect() end
 table.clear(self.connections)
 if self.screen then self.screen:Destroy() end
 if self.folder then self.folder:Destroy() end
end

return Controller
