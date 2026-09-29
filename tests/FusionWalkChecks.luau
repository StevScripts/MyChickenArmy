--!strict
-- Disposable actors on the unused second plot; never edits a player profile.
local Server=game.ServerStorage.PetRoll
local World=require(Server.WorldService)
local Session=require(Server.PlayerSession)
local Actor=require(Server.PetActor)
local Stand=require(Server.MergeStand)
local Checks={}
function Checks.Run()
 local results={}
 local function check(name,fn)
  local folder=Instance.new('Folder');folder.Name='FusionWalkFixture';folder.Parent=workspace
  local world=World.new()
  local session=Session.new(-9289,'Fusion walk fixture',2);session.loaded=true
  session.pets,session.slots={},{}
  local pets=Instance.new('Folder');pets.Name='Pets';pets.Parent=folder
  local plot={index=2,folder=folder,pets=pets,actors={},roaming={},homeOrdinals={},stations={}}
  world.plots[2]=plot
  local template=workspace.PetRollWorld.Plot2:FindFirstChild('Fuse_Machine',true)
  local stand=Stand.new(folder,world:PlotFrame(2),2,function() end,template,world:PlotFrame(2))
  plot.mergeStand=stand;stand:Sync(session)
  local function add(size)
   local pet=session:AddPet('Duck',1);pet.level,pet.giantSize=2,size
   local actor=Actor.new(pets,pet.id,pet.species,1,world:ReturnPosition(session,pet.id))
   assert(world:RestoreActor(session,pet.id,actor))
   return pet,actor
  end
  local function step(seconds)
   local untilAt=os.clock()+seconds
   repeat world:Step(os.clock());task.wait(.08) until os.clock()>=untilAt
  end
  local ok,detail=pcall(fn,world,session,plot,stand,add,step)
  for _,actor in plot.actors do actor:Destroy() end
  stand:Destroy();folder:Destroy()
  table.insert(results,{name=name,passed=ok,detail=if ok then detail else nil,error=if not ok then tostring(detail) else nil})
 end
 for _,size in {4.5,27.5} do
  check(tostring(size)..'-stud result keeps the same rig and walks from the garage toward its yard',function(world,session,plot,stand,add,step)
   local pet,actor=add(size);local model,root=actor.model,actor.root
   world:CelebrateMerge(session,pet.id)
   assert(stand:IsRevealing(pet.id) and stand.birds[1]==model and root.Anchored)
   assert(#plot.pets:GetChildren()==1 and not stand.prompt.Enabled)
   step(2.5)
   local before=actor:Position()
   assert(actor.model==model and actor.root==root and root.Anchored)
   step(.3)
   local released=actor:Position();local target=plot.roaming[pet.id].target
   assert(not stand:IsRevealing(pet.id) and not root.Anchored and not model:GetAttribute('PresentationHidden'))
   assert(actor.model==model and (released-before).Magnitude<4,'Release must not teleport to yard')
   assert(model:GetAttribute('Moving') and model:GetAttribute('GiantSize')==size)
   local startDistance=(released-target).Magnitude
   step(6)
   local finishDistance=(actor:Position()-target).Magnitude
   assert(actor.model==model and actor.root==root and model.Parent==plot.pets,'No replacement rig')
   assert(finishDistance<startDistance-8,'Chicken did not walk toward yard')
   assert(not model:GetAttribute('RecoveryCount'),'Normal handoff must not need teleport recovery')
   assert(#stand.birds==0 and #stand.tracks==0 and #stand.scaleDrivers==0)
   return {distanceBefore=startDistance,distanceAfter=finishDistance,walked=(actor:Position()-released).Magnitude,sameModel=true}
  end)
 end
 check('Taking an army actor mid-reveal releases its anchor and keeps its identity',function(world,session,plot,stand,add)
  local pet,actor=add(20);local model=actor.model
  world:CelebrateMerge(session,pet.id)
  local taken=world:TakeActor(2,pet.id)
  assert(taken==actor and actor.model==model and not actor.root.Anchored and not stand.reveal)
  assert(not plot.actors[pet.id] and #stand.tracks==0 and #stand.scaleDrivers==0)
  actor:Destroy();return true
 end)
 check('A home teleport cancels the reveal without moving back to the garage',function(world,session,plot,stand,add)
  local pet,actor=add(20)
  world:CelebrateMerge(session,pet.id)
  local home=world:ReturnPosition(session,pet.id)
  actor:Teleport(home);world:RestoreActor(session,pet.id,actor)
  assert(not stand.reveal and not actor.root.Anchored and (actor:Position()-home).Magnitude<.01)
  return true
 end)
 check('Deleting a revealed chicken cancels safely without resurrecting it',function(world,session,plot,stand,add,step)
  local pet,actor=add(8)
  world:CelebrateMerge(session,pet.id);session.pets[pet.id]=nil
  actor:Destroy();plot.actors[pet.id],plot.roaming[pet.id]=nil,nil
  step(.8)
  assert(not stand.reveal and #stand.birds==0 and #plot.pets:GetChildren()==0)
  return true
 end)
 return results
end
return Checks
