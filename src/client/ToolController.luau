--!strict
-- October 20 hand tools, client side (docs/team/COLLECTION_TOOLS.md). The Egg Vacuum
-- and Chicken Feed are real Tools in Roblox's own hotbar (Stevin, October 20): Roblox
-- equips them by slot key, tap or gamepad. This keeps that hotbar switched on, shows
-- the vacuum's thin "carried / capacity" egg bar between My Army and the hotbar, gives the
-- Commander guide one invisible anchor over each tool's slot (hintAnchors), and puts
-- the native Feed prompt on the nearest of your chickens at home. ToolService owns the
-- tools, levels and Coins.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local StarterGui=game:GetService("StarterGui")
local GuiService=game:GetService("GuiService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Config=require(Shared.Config)
local Tools=require(Shared.VacuumConfig)
local Theme=require(script.Parent.UITheme)
local Controller={}
Controller.__index=Controller

local POLL_SECONDS=0.1
local PROMPT_LIFT=Vector3.new(0,1.2,0)
-- Roblox's hotbar (CoreGui BackpackScript): 60 px slots (100 px on consoles) with
-- 5 px gaps, at the bottom of the whole screen. Only filled slots show, centred,
-- and a new tool takes the lowest free slot. Our anchors and meter follow that.
local ICON=if GuiService:IsTenFootInterface() then 100 else 60
local GAP=5
-- The vacuum's egg bar: thin (a quarter of a slot) and about as wide as My Army's row.
local BAR_HEIGHT=math.round(ICON*0.27)
local BAR_WIDTH=0.9
-- Pixels up from the screen's bottom that the hotbar, the egg bar and a 3 px margin
-- take: My Army sits right above (HudController). One rule for every device: 84 with
-- 60 px slots, 135 with consoles' 100 px slots.
Controller.BottomReserve=ICON+GAP+BAR_HEIGHT+3
local GOLD=Theme.Arcade.gold
local RED=Theme.Arcade.red

function Controller.new(app)
 local self=setmetatable({app=app,connections={},nextPollAt=0,slots={},hintAnchors={},anchorFrames={}},Controller)
 -- Roblox's own hotbar is the tool bar now; a cutscene restores whatever it saved.
 pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,true) end)
 -- The hotbar is drawn on the whole screen, not inside the device safe area.
 self.screen=Theme.InsetContainer(app.hudLayer,"ToolHotbar",Enum.ScreenInsets.None)
 self:BuildMeter()
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

-- The vacuum's egg bar (Stevin, October 20): a thin bar in the gap between the My Army
-- row and the hotbar. Gold fills as the vacuum fills, with "120 / 300" on it; full,
-- it turns red and reads "Full! Sell on the pad".
function Controller:BuildMeter()
 local meter=Theme.Frame(self.screen,"VacuumMeter",UDim2.fromOffset(300,BAR_HEIGHT),Color3.new(0,0,0))
 meter.AnchorPoint,meter.BackgroundTransparency,meter.Visible=Vector2.new(0.5,0.5),0.35,false
 Theme.Stroke(meter,Color3.new(0,0,0),2)
 local fill=Theme.Frame(meter,"Fill",UDim2.fromScale(0,1),GOLD)
 local count=Theme.Label(meter,"Count","0 / 0",14,Color3.new(1,1,1))
 count.Position,count.Size=UDim2.fromScale(0.02,0),UDim2.fromScale(0.96,1)
 count.TextScaled,count.TextWrapped,count.TextXAlignment=true,false,Enum.TextXAlignment.Center
 self.meter,self.meterFill,self.meterCount=meter,fill,count
end

function Controller:RenderMeter(held: Tool?,_right: number)
 local tools=self.app.state and self.app.state.tools
 local vacuum=tools and tools.vacuum
 local shown=held~=nil and held.Name=="EggVacuum" and type(vacuum)=="table" and not self.app.panel.Visible
 self.meter.Visible=shown
 if not shown then return end
 -- Midway between My Army's row and the hotbar's top, centred under that row.
 local origin:Vector2,size:Vector2=self.screen.AbsolutePosition,self.screen.AbsoluteSize
 local hotbarTop=size.Y-(GAP+ICON)
 local x,y,width=size.X/2,hotbarTop-GAP-BAR_HEIGHT,300
 local navigation:GuiObject?=self.app.hud and self.app.hud.navigation
 if navigation and navigation.AbsoluteSize.X>0 then
  local bottom=navigation.AbsolutePosition.Y-origin.Y+navigation.AbsoluteSize.Y
  x=navigation.AbsolutePosition.X-origin.X+navigation.AbsoluteSize.X/2
  width=navigation.AbsoluteSize.X*BAR_WIDTH
  if bottom<hotbarTop then y=(bottom+hotbarTop)/2 end
 end
 self.meter.Position,self.meter.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(width,BAR_HEIGHT)
 local count,capacity=math.floor(vacuum.count or 0),math.max(1,math.floor(vacuum.capacity or 0))
 local full=count>=capacity
 local text=if full then "Full! Sell on the pad" else Theme.Money(count).." / "..Theme.Money(capacity)
 if self.meterCount.Text~=text then self.meterCount.Text=text end
 local ratio=math.clamp(count/capacity,0,1)
 if ratio~=self.meterRatio then
  -- Reduced motion sets the fill at once (UIMotion).
  self.meterRatio=ratio
  Theme.Motion:Tween(self.meterFill,"fill",{Size=UDim2.fromScale(ratio,1)},0.15)
 end
 self.meterFill.BackgroundColor3=if full then RED else GOLD
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
  local right=self:PlaceAnchors(self:TrackSlots())
  self:RenderMeter(held,right)
  self:UpdateTarget(held~=nil and held.Name=="ChickenFeed")
 end
 -- Chickens roam: the prompt follows its chicken every frame.
 local target=self.target
 local part=target and target.part
 if part and part.Parent then self.anchor.CFrame=CFrame.new(part.Position+PROMPT_LIFT) end
end

-- A fed chicken flashes gold and the purchase burst plays at the player.
function Controller:Receive(_state,result)
 if not result or result.action~="FeedChicken" or not result.ok then return end
 self.app.feedback:Action("Income")
 if result.petId then self.app.base:PetPulse(result.petId,Theme.Arcade.gold) end
end

function Controller:Destroy()
 for _,connection in self.connections do connection:Disconnect() end
 table.clear(self.connections)
 if self.screen then self.screen:Destroy() end
 if self.folder then self.folder:Destroy() end
end

return Controller
