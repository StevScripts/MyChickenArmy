--!strict
-- October 20 hand tools, client side (docs/team/COLLECTION_TOOLS.md). Equips the Egg
-- Vacuum and Chicken Feed from the dock, number keys 1 and 2 and gamepad L1/R1, keeps
-- Roblox's own hotbar hidden (the dock replaces it) and puts the native Feed prompt on
-- the nearest of your chickens at home. ToolService owns the tools, levels and Coins.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local StarterGui=game:GetService("StarterGui")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Config=require(Shared.Config)
local Tools=require(Shared.VacuumConfig)
local Theme=require(script.Parent.UITheme)
local ToolDock=require(script.Parent.ToolDock)
local Controller={}
Controller.__index=Controller

local KEYS={Enum.KeyCode.One,Enum.KeyCode.Two,Enum.KeyCode.Three}
local POLL_SECONDS=0.1
-- A cutscene restores the CoreGui it saved; hide the default hotbar again soon after.
local HOTBAR_CHECK_SECONDS=2
local PROMPT_LIFT=Vector3.new(0,1.2,0)

function Controller.new(app)
 local self=setmetatable({app=app,connections={},nextPollAt=0,nextHotbarAt=0},Controller)
 self.dock=ToolDock.new(app,function(name) self:Toggle(name) end)
 self:HideHotbar()
 self:BuildPrompt()
 for index,name in Tools.ToolOrder do
  ContextActionService:BindAction("PetRollTool"..index,function(_,state)
   if state~=Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() or not self:Owned()[name] then
    return Enum.ContextActionResult.Pass
   end
   self:Toggle(name)
   return Enum.ContextActionResult.Sink
  end,false,KEYS[index])
 end
 ContextActionService:BindAction("PetRollToolCycle",function(_,state,input)
  if state~=Enum.UserInputState.Begin or self:Blocked() then return Enum.ContextActionResult.Pass end
  self:Cycle(if input.KeyCode==Enum.KeyCode.ButtonL1 then -1 else 1)
  return Enum.ContextActionResult.Sink
 end,false,Enum.KeyCode.ButtonL1,Enum.KeyCode.ButtonR1)
 table.insert(self.connections,RunService.Heartbeat:Connect(function() self:Step(os.clock()) end))
 return self
end

function Controller:HideHotbar()
 pcall(function()
  if StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) then StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false) end
 end)
end

function Controller:Blocked(): boolean
 local app=self.app
 if app.panel.Visible or app.dialogueActive==true then return true end
 if app.research and app.research.root and app.research.root.Visible then return true end
 if app.commerce and app.commerce.cratePresenting then return true end
 local camera=workspace.CurrentCamera
 return camera==nil or camera.CameraType==Enum.CameraType.Scriptable
end

-- Tool name -> true for each tool the server says this player owns.
function Controller:Owned(): {[string]: boolean}
 local tools=self.app.state and self.app.state.tools
 return {EggVacuum=tools~=nil and tools.eggVacuum==true,ChickenFeed=tools~=nil and tools.chickenFeed==true}
end

-- The game tool in the local player's hand.
function Controller:Held(): Tool?
 local character=Players.LocalPlayer.Character
 local tool=character and character:FindFirstChildOfClass("Tool")
 return if tool and tool:GetAttribute("PetRollTool")~=nil then tool else nil
end

function Controller:Humanoid(): Humanoid?
 local character=Players.LocalPlayer.Character
 local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 return if humanoid and humanoid.Health>0 then humanoid else nil
end

-- Equip a tool, or put it away when it is already in hand.
function Controller:Toggle(name: string)
 local humanoid=self:Humanoid()
 if not humanoid then return end
 self.app.audio:Play("Click")
 local held=self:Held()
 if held and held.Name==name then humanoid:UnequipTools();return end
 local backpack=Players.LocalPlayer:FindFirstChildOfClass("Backpack")
 local tool=backpack and backpack:FindFirstChild(name)
 if tool and tool:IsA("Tool") then humanoid:EquipTool(tool) end
end

-- Gamepad bumpers: step through the owned tools, then empty hands.
function Controller:Cycle(direction: number)
 local owned,list=self:Owned(),{}
 for _,name in Tools.ToolOrder do if owned[name] then table.insert(list,name) end end
 if #list==0 then return end
 local held,index=self:Held(),0
 for i,name in list do if held and held.Name==name then index=i end end
 local nextIndex=(index+direction)%(#list+1)
 if nextIndex==0 then
  local humanoid=self:Humanoid()
  if humanoid and held then self.app.audio:Play("Click");humanoid:UnequipTools() end
 else
  self:Toggle(list[nextIndex])
 end
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
 if now>=self.nextHotbarAt then self.nextHotbarAt=now+HOTBAR_CHECK_SECONDS;self:HideHotbar() end
 if now>=self.nextPollAt then
  self.nextPollAt=now+POLL_SECONDS
  local held=self:Held()
  local tools=self.app.state and self.app.state.tools
  self.dock:Render(self:Owned(),held and held.Name,tools and tools.vacuum)
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
 for index in Tools.ToolOrder do ContextActionService:UnbindAction("PetRollTool"..index) end
 ContextActionService:UnbindAction("PetRollToolCycle")
 self.dock:Destroy()
 if self.folder then self.folder:Destroy() end
end

return Controller
