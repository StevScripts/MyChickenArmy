--!strict
-- October 20 hand tools (docs/team/COLLECTION_TOOLS.md). Keeps every Backpack holding
-- exactly the tools its player owns (both are bought in Upgrades > Tools, so a Rebirth
-- takes them back), builds the held models from parts and sells chicken levels to an
-- equipped Chicken Feed. EggService runs the vacuum itself; ToolController and
-- ToolDock are the client side.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Shared=ReplicatedStorage.PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Tools=require(Shared.VacuumConfig)
local ArmyService=require(script.Parent.ArmyService)
local ToolService={}
ToolService.__index=ToolService
local SYNC_SECONDS=0.5

function ToolService.new(world)
 return setmetatable({world=world,templates={},nextSyncAt=0},ToolService)
end

-- Both tools are Upgrades tree nodes (Stevin, October 20: the vacuum is bought too).
function ToolService.Owns(session,name: string): boolean
 if name=="EggVacuum" then return (session.researchEffects.eggVacuum or 0)>=1 end
 if name=="ChickenFeed" then return (session.researchEffects.chickenFeed or 0)>=1 end
 return false
end

-- Server-granted tools only: a client-made Tool never replicates to the server.
function ToolService.Holding(player: Player?,name: string): boolean
 local character=player and player.Character
 local tool=character and character:FindFirstChild(name)
 return tool~=nil and tool:IsA("Tool") and tool:GetAttribute("PetRollTool")==name
end

-- The Duck's voxel egg, shrunk to `height` with its centre at `at` (its mesh origin is
-- the egg's bottom centre). Nil in a scripts-only build without the egg meshes.
local function voxelEgg(height: number): BasePart?
 local assets=ReplicatedStorage.PetRoll:FindFirstChild("Assets")
 local meshes=assets and assets:FindFirstChild("EggMeshes")
 local source=meshes and meshes:FindFirstChild("Duck")
 if not source or not source:IsA("BasePart") then return nil end
 local egg=source:Clone()
 for _,child in egg:GetChildren() do
  if child:IsA("BasePart") or child:IsA("ParticleEmitter") or child:IsA("Attachment") then child:Destroy() end
 end
 local native=tonumber(egg:GetAttribute("EggHeight")) or egg.Size.Y
 egg.Size*=height/math.max(native,0.01)
 egg:SetAttribute("EggHeight",height)
 return egg
end

-- One held model from VacuumConfig.Models: an invisible Handle at the hand, with every
-- visible part welded to it in grip space. Massless and never in the way of anything.
local function build(name: string): Tool
 local model=Tools.Models[name]
 local scale=model.Scale
 local tool=Instance.new("Tool")
 tool.Name=name
 tool.ToolTip=Tools.ToolNames[name] or name
 tool.TextureId=Tools.ToolIcons[name] or ""
 tool.CanBeDropped,tool.RequiresHandle,tool.ManualActivationOnly=false,true,true
 tool.Grip=model.Grip
 tool:SetAttribute("PetRollTool",name)
 local handle=Instance.new("Part")
 handle.Name="Handle"
 handle.Size=Vector3.one*0.2
 handle.Transparency=1
 handle.CanCollide,handle.CanTouch,handle.CanQuery,handle.Massless,handle.CastShadow=false,false,false,true,false
 handle.CFrame=CFrame.new()
 handle.Parent=tool
 if model.Nozzle then
  local nozzle=Instance.new("Attachment")
  nozzle.Name="Nozzle"
  nozzle.Position=model.Nozzle*scale
  nozzle.Parent=handle
 end
 for _,spec in model.Parts do
  local frame=CFrame.new(spec.At*scale)*CFrame.Angles(math.rad(spec.Rot.X),math.rad(spec.Rot.Y),math.rad(spec.Rot.Z))
  local part: BasePart?=nil
  if spec.Shape=="Egg" then
   local egg=voxelEgg(spec.Size.Y*scale)
   if egg then
    egg.CFrame=frame*CFrame.new(0,-spec.Size.Y*scale/2,0)
    part=egg
   end
  end
  if not part then
   local block=Instance.new("Part")
   block.Shape=if spec.Shape=="Cylinder" then Enum.PartType.Cylinder
    elseif spec.Shape=="Egg" then Enum.PartType.Ball else Enum.PartType.Block
   block.Size=if spec.Shape=="Egg" then Vector3.one*spec.Size.X*scale else spec.Size*scale
   block.Color=model.Colors[spec.Color]
   block.Material=(Enum.Material :: any)[spec.Material]
   block.Transparency=spec.Transparency or 0
   block.TopSurface,block.BottomSurface=Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
   block.CFrame=frame
   part=block
  end
  local placed=part :: BasePart
  placed.Name=spec.Name
  placed.Anchored=false
  placed.CanCollide,placed.CanTouch,placed.CanQuery,placed.Massless=false,false,false,true
  local weld=Instance.new("WeldConstraint")
  weld.Part0,weld.Part1=handle,placed
  weld.Parent=placed
  placed.Parent=tool
 end
 return tool
end

-- A Studio-authored Tool in Assets.Tools wins over the parts-built model.
function ToolService:Template(name: string): Tool
 local cached=self.templates[name]
 if cached then return cached end
 local assets=ReplicatedStorage.PetRoll:FindFirstChild("Assets")
 local folder=assets and assets:FindFirstChild("Tools")
 local authored=folder and folder:FindFirstChild(name)
 local template: Tool
 if authored and authored:IsA("Tool") then
  template=authored:Clone()
  template:SetAttribute("PetRollTool",name)
  template.CanBeDropped=false
 else
  template=build(name)
 end
 self.templates[name]=template
 return template
end

-- Exactly one of each owned tool between the Backpack and the character; none of the rest.
function ToolService:Sync(player: Player,session)
 local backpack=player:FindFirstChildOfClass("Backpack")
 if not backpack then return end
 local containers: {Instance}={backpack}
 if player.Character then table.insert(containers,player.Character) end
 for _,name in Tools.ToolOrder do
  local found={}
  for _,container in containers do
   for _,item in container:GetChildren() do
    if item:IsA("Tool") and item:GetAttribute("PetRollTool")==name then table.insert(found,item) end
   end
  end
  if not ToolService.Owns(session,name) then
   for _,tool in found do tool:Destroy() end
  elseif #found==0 then
   self:Template(name):Clone().Parent=backpack
  else
   for index=2,#found do found[index]:Destroy() end
  end
 end
end

function ToolService:Step(sessions,now: number)
 if now<self.nextSyncAt then return end
 self.nextSyncAt=now+SYNC_SECONDS
 for _,session in sessions do
  if not session.loaded or session.closing or session.saveLost then continue end
  local player=Players:GetPlayerByUserId(session.userId)
  if player then self:Sync(player,session) end
 end
end

-- Chicken Feed: one level for one of your chickens at home, at the server's quote,
-- while Feed is in hand and the chicken is within reach (ArmyService does the rest).
function ToolService:Feed(player: Player,session,petId,expectedLevel,expectedPrice): (boolean,string,string?)
 local pet=if type(petId)=="string" then session.pets[petId] else nil
 if not pet then return false,"Choose one of your chickens.",nil end
 if not ToolService.Owns(session,"ChickenFeed") then return false,"Buy Chicken Feed in Upgrades > Tools first.",nil end
 if not ToolService.Holding(player,"ChickenFeed") then return false,"Equip Chicken Feed first.",nil end
 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local at: Vector3?=self.world:PetPosition(session.plotIndex,petId)
 if not root or not root:IsA("BasePart") or not at then return false,"Walk up to your chicken to feed it.",nil end
 local from=(root :: BasePart).Position
 if Vector2.new(from.X-at.X,from.Z-at.Z).Magnitude>Tools.FeedRange+Tools.FeedSlack then
  return false,"Walk up to your chicken to feed it.",nil
 end
 local before=pet.level or 1
 local ok,message=ArmyService.UpgradeChicken(session,petId,expectedLevel,expectedPrice)
 if not ok then return false,message,nil end
 local definition=Catalog[pet.species]
 return true,(if definition then definition.name else "Chicken").." leveled up! Lv "..before.." → "..(pet.level or before+1),petId
end

-- state.tools (docs/team/OVERHAUL_CONTRACT_20261020.md §8). Its presence also tells
-- ChickenBrowser that levels are bought with Chicken Feed now.
function ToolService:Snapshot(session,eggs)
 return {eggVacuum=ToolService.Owns(session,"EggVacuum"),chickenFeed=ToolService.Owns(session,"ChickenFeed"),
  order=Tools.ToolOrder,vacuum=eggs and eggs.vacuum,clickRange=eggs and eggs.clickRange,feedRange=Tools.FeedRange}
end

return ToolService
