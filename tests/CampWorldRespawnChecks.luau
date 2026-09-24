-- Real camp/King spawner transitions, using disposable models and synthetic state.
local S=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Config=require(Shared.Config)
local Progression=require(Shared.Progression)
local Session=require(S.PlayerSession)
local Battles=require(S.BattleService)
local World=require(S.WorldService)
local Builder=require(S.WorldBuilder)
local KingArena=require(S.KingArena)
local Checks={}

function Checks.Run()
 local results={}
 for _,kind in {"camp","outpost","king"} do
  local folder=Instance.new("Folder");folder.Name="CampRespawnFixture";folder.Parent=workspace
  local world=World.new()
  local record
  local ok,detail=pcall(function()
   local session=Session.new(-7391,"Occupancy fixture",1)
   local service=Battles.new({[session.userId]=session},world)
   local key,location,countGuards
   if kind=="king" then
    key,location="king:1",{king=true,position=Vector3.new(0,1.05,0),halfSize=40}
    world.kingArena=KingArena.new(folder)
    countGuards=function() return (if world.kingArena.actor then 1 else 0)+#world.kingArena.guards end
   else
    local frame=CFrame.new(10000,1.05,10000)
    local definition=if kind=="camp" then Progression.Camps(1)[1] else Progression.Outposts()[1]
    local model=Builder.BuildCamp(folder,1,definition,Config.CampHalfSize,false,frame,if kind=="camp" then 1 else nil)
    local defenders=Instance.new("Folder");defenders.Name="Defenders";defenders.Parent=model
    record={folder=model,defenders=defenders,frame=frame,actors={},busy=false,promotion=1,
     roster=if kind=="camp" then Progression.Roster(1,1) else Progression.OutpostRoster(1)}
    if kind=="camp" then
     key,location="1:1",{plot=1,index=1,position=frame.Position};world.lanes[1]={[1]=record}
    else key,location="outpost:1",{outpost=1,position=frame.Position};world.outposts[1]=record end
    world:PopulateCamp(record)
    countGuards=function() return #record.actors end
   end
   local initial=countGuards();assert(initial>0,"Missing initial NPC garrison")
   if kind=="camp" then world:SetCampBusy(1,true,1)
   elseif kind=="outpost" then world:SetOutpostBusy(1,true)
   else world.kingArena:SetBusy(true) end
   service:SetTerritoryOwner(key,session,location)
   service.campLocations[key]=location
   local unit={side="A",petId="fixture-pet",hp=10,size=2,x=location.position.X,z=location.position.Z}
   local army={id="occupant",attacker=session.userId,units={unit},phase="Returning"}
   service.battles[army.id]=army;service.campBusy[key]=army.id;service.departingCamps[key]=army.id
   service:ReleaseClearedCamps(1);service:ReleaseClearedCamps(20)
   assert(countGuards()==0 and service.campOwners[key],"Enemies returned on an occupied camp")
   unit.x+=100
   service:ReleaseClearedCamps(21)
   assert(countGuards()==0,"Respawn skipped clear grace")
   service:ReleaseClearedCamps(21+Config.CampRespawnGrace+.01)
   assert(service.campOwners[key]==nil and service.campBusy[key]==nil)
   assert(countGuards()==initial,"NPC garrison failed to return")
   return tostring(initial).." real NPC rigs restored after the last live unit left"
  end)
  if world.kingArena then world.kingArena:Destroy() end
  if record then for _,actor in record.actors do actor:Destroy() end end
  folder:Destroy()
  table.insert(results,{name=kind.." real garrison respawns on vacancy",passed=ok,detail=tostring(detail)})
 end
 return results
end
return Checks
