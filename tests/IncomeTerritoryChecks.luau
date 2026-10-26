-- Isolated service fixtures. No profiles, live player sessions or world edits.
local Server=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Session=require(Server.PlayerSession)
local Battles=require(Server.BattleService)
local Battle=require(Server.Battle)
local Transfer=require(Server.TerritoryContest)
local Reinforcements=require(Server.ArmyReinforcements)
local Config=require(Shared.Config)
local Layout=require(Shared.FlockLayout)
local March=require(Shared.ArmyMarch)
local Checks={}

local function setup()
 local a,b,c=Session.new(1001,"First",1),Session.new(1002,"Second",2),Session.new(1003,"Third",3)
 -- October 23 empty start: a new profile has no chickens; these checks assume the old three-Duck flock.
 for _,fixture in {a,b,c} do for _=1,3 do fixture:AddPet("Duck",1).investment=0 end end
 a.loaded,b.loaded,c.loaded=true,true,true
 local world={}
 function world:Position(plot)
  local p=Config.PlotPositions[plot];return Vector3.new(p[1],1.05,p[2])
 end
 function world:IncomeFrame() return CFrame.lookAt(Vector3.new(79,1.05,-79),Vector3.new(0,1.05,0)) end
 function world:ReturnPosition(session,_,slot) local x,z=Layout.Home(slot);return self:Position(session.plotIndex)+Vector3.new(x,0,z) end
 function world:PetPosition(...) return nil end
 function world:SetIncomeBusy(...) end
 function world:SetIncomeStatus(...) end
 function world:SetTerritoryOwner(...) end
 function world:SetCampBusy(...) end
 function world:SetOutpostBusy(...) end
 function world:OutpostFrame(i) return CFrame.new(145*math.cos(i*math.pi/3),1.05,145*math.sin(i*math.pi/3)) end
 function world:CampPosition(index,plot) return self:Position(plot).Unit*Config.CampRadii[index] end
 function world:CampFrame(index,plot) return CFrame.new(self:CampPosition(index,plot)) end
 local service=Battles.new({[a.userId]=a,[b.userId]=b,[c.userId]=c},world)
 service.isRealPlayer=function(_) return true end
 return service,a,b,c,world
end

local function front(battle,side)
 for _,unit in battle.units do if unit.side==side then
  unit.x,unit.z=battle.destination.X,battle.destination.Z+(if side=="A" then 1 else -1)
  unit.marchPath=nil;unit.reinforcing=false;unit.retiring=false
 end end
 battle.assembling=false
end

local function capture(service,battle,now)
 front(battle,"A")
 for _,unit in battle.units do if unit.side=="B" then unit.hp=0;unit.respawnAt=nil end end
 battle.incomeActiveAt=now
 battle:BeginCapture(now);battle.captureElapsed=Config.CaptureSeconds-.2
 service:Step(.1,now+.1);assert(not battle.paid,"Capture completed early")
 service:Step(.1,now+.2)
 assert(battle.paid,"Capture did not resolve")
 return service.battles[service.sessions[battle.attacker] and service.sessions[battle.attacker].outgoing]
end

local function holder(service,owner,now)
 assert(service:Attack(owner,"income:1",now))
 local result=capture(service,service.battles[owner.outgoing],now+1)
 service.income.graceUntil=0
 return result
end

function Checks.Run()
 local original=Config.IncomeOutpost
 assert(original,"IncomeOutpost configuration missing")
 Config.IncomeOutpost=table.clone(original)
 Config.IncomeOutpost.Enabled=true;Config.IncomeOutpost.ContestsEnabled=true;Config.IncomeOutpost.NpcEnabled=false
 -- These cover the contest engine itself; HillChecks covers the Hill clock on top.
 local originalHill=Config.Hill;Config.Hill=table.clone(originalHill);Config.Hill.Enabled=false
 local results={}
 local function test(name,fn)
  local ok,detail=pcall(fn);table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
 end
 test("Neutral site captures without route unlocks or kill coins",function()
  local service,a=setup();local before=a.coins
  assert(service:Attack(a,"income:1",0))
  local battle=service.battles[a.outgoing]
  assert(battle:Alive("B")==3 and battle.rosterLocked)
  battle.kills={{side="B",species="Duck",level=1,serial=1,x=0,z=0}}
  service:RewardKills(battle,0);assert(a.coins==before and #battle.kills==0)
  local continuation=capture(service,battle,1)
  assert(service.campOwners["income:1"].userId==a.userId and continuation.phase=="Holding")
  assert(a.coins==before and next(a.firstWins)==nil and next(a.frontierWins)==nil and not a.kingCleared)
  assert(not continuation.rosterLocked and continuation.defenderRespawnAt==nil)
  service:Destroy();return "Full meter owns the site; no kill bounty, permanent unlock or hostile respawn"
 end)
 test("Owner earns eight per simulation second while away; active fighting pauses",function()
  local service,a,b=setup();holder(service,a,0)
  assert(service:ReturnHome(a,3));local before=a.coins
  service:StepIncome(10,13);assert(a.coins-before==80)
  local travel=service.battles[a.outgoing]
  for _,unit in travel.units do unit.x,unit.z=unit.homeX,unit.homeZ;unit.marchPath=nil;unit.reinforcing=false end
  service:Step(.1,14);service:ReleaseClearedCamps(15);service:ReleaseClearedCamps(16)
  assert(a.armyState=="Home")
  assert(service:Attack(b,"income:1",17))
  local contest=service.battles[b.outgoing]
  before=a.coins;service:StepIncome(1,18);assert(a.coins-before==8,"Travel stopped income")
  contest.incomeActiveAt=19;before=a.coins;service:StepIncome(10,29)
  assert(a.coins==before and service:IncomeSummary(a,29).effectiveRate==0)
  service:Destroy();return "Ownership pays during recall/travel and pauses only for active contest"
 end)
 test("Garrison handoff preserves lives and excludes recovering birds",function()
  local service,a,b=setup();local holding=holder(service,b,0)
  local alive,dead=holding.units[1],holding.units[2]
  alive.hp=alive.maxHp-7;dead.hp=0;dead.respawnAt=1
  assert(service:Attack(a,"income:1",3))
  local contest=service.battles[a.outgoing]
  assert(b.outgoing==contest.id and not service.battles[holding.id])
  local found={};for _,unit in contest.units do if unit.side=="B" then found[unit.petId]=unit end end
  assert(found[alive.petId].hp==alive.maxHp-7 and found[dead.petId].hp==0 and found[dead.petId].contestUnavailable)
  contest:StepReinforcements(.1,100);assert(found[dead.petId].hp==0,"Committed dead bird revived")
  local pet=a:AddPet("StormDuck",1);Reinforcements.Sync(a,contest,service.world,100)
  for _,unit in contest.units do assert(unit.petId~=pet.id,"New purchase refilled finite roster") end
  service:Destroy();return "Both session pointers, HP and finite roster preserved"
 end)
 test("Challenger retreat retains defender health without gifting grace",function()
  local service,a,b,c=setup();local holding=holder(service,b,0)
  holding.units[1].hp-=5;local hp=holding.units[1].hp
  assert(service:Attack(a,"income:1",3));local contest=service.battles[a.outgoing]
  assert(service:ReturnHome(a,4))
  local held=service.battles[b.outgoing]
  assert(held.phase=="Holding" and held.units[1].hp==hp and service.campOwners["income:1"].userId==b.userId)
  assert(service.income.graceUntil==0 and service.income.retry[a.userId]==4+Config.IncomeOutpost.RetrySeconds)
  assert(service:IncomeSummary(c,5).available and not service:IncomeSummary(a,5).available)
  local count=0;for _ in service.battles do count+=1 end
  service:Finish(contest,"A",5);local after=0;for _ in service.battles do after+=1 end
  assert(after==count and service.campOwners["income:1"].userId==b.userId,"Repeated finish transferred owner")
  service:Destroy();return "No recall shield, personal retry only, resolution idempotent"
 end)
 test("Defender recall concedes without resetting capture or permitting another life",function()
  local service,a,b=setup();holder(service,b,0)
  assert(service:Attack(a,"income:1",3));local contest=service.battles[a.outgoing]
  contest.captureElapsed=2
  assert(service:ReturnHome(b,4))
  assert(contest.defender==nil and contest.captureElapsed==2 and not contest.paid)
  assert(service.campOwners["income:1"].userId==b.userId and service.battles[b.outgoing].phase=="Returning")
  assert(not service:IncomeSummary(b,5).available,"Defender could refill the same contest")
  service:Destroy();return "Defender returns separately; owner remains until challenger captures"
 end)
 test("Contest casualties recover five seconds after resolution; survivors keep damage",function()
  local service,a,b=setup();holder(service,b,0);assert(service:Attack(a,"income:1",3))
  local contest=service.battles[a.outgoing];contest.incomeActiveAt=4
  local dead,alive
  for _,unit in contest.units do if unit.side=="B" then
   if not dead then dead=unit;unit.hp=0;unit.respawnAt=nil else alive=unit;unit.hp-=3 end
  end end
  local hp=alive.hp
  service:Finish(contest,"Draw",20)
  local nextBattle=service.battles[b.outgoing]
  local recovered,survived
  for _,unit in nextBattle.units do if unit.petId==dead.petId then recovered=unit elseif unit.petId==alive.petId then survived=unit end end
  assert(recovered.hp==0 and recovered.respawnAt==25 and survived.hp==hp)
  nextBattle:StepReinforcements(.1,24.9);assert(recovered.hp==0)
  nextBattle:StepReinforcements(.1,25);assert(recovered.hp>0 and recovered.reinforcing and recovered.marchPath)
  assert(math.abs(recovered.x-recovered.homeX)<.01 and math.abs(recovered.z-recovered.homeZ)<.01)
  assert(service.income.graceUntil==20+Config.IncomeOutpost.GraceSeconds)
  service:Destroy();return "No mid-contest resurrection or instant survivor heal"
 end)
 test("Defender recall keeps inherited camps occupied until its actual tail leaves",function()
  local service,a,b=setup();local holding=holder(service,b,0)
  local previous="outpost:1";local position=service.world:OutpostFrame(1).Position
  local tail=holding.units[1];tail.x,tail.z=position.X,position.Z;tail.reinforcing=true
  March.Set(tail,{position,holding.destination},0)
  service.campBusy[previous]=holding.id;service.departingCamps[previous]=holding.id;service.departingSides[previous]="A"
  service.campLocations[previous]={outpost=1,position=position}
  assert(service:Attack(a,"income:1",3));local contest=service.battles[a.outgoing]
  assert(service.campBusy[previous]==contest.id and service.departingSides[previous]=="B")
  service.campClearedAt[previous]=2
  assert(service:ReturnHome(b,4));local returning=service.battles[b.outgoing]
  assert(service.campBusy[previous]==returning.id and service.departingSides[previous]=="A" and service.campClearedAt[previous]==nil)
  service:ReleaseClearedCamps(5);service:ReleaseClearedCamps(6)
  assert(service.campBusy[previous]==returning.id,"Camp released while the actual returning rig still occupied it")
  for _,unit in returning.units do unit.x,unit.z=unit.homeX,unit.homeZ end
  service:ReleaseClearedCamps(7);service:ReleaseClearedCamps(7+Config.CampRespawnGrace+.01)
  assert(service.campBusy[previous]==nil)
  service:Destroy();return "Prior outpost reservation follows side B tail into its own side A return"
 end)
 test("Returning owner continues stationing if challenger retreats halfway",function()
  local service,a,b=setup();service:SetTerritoryOwner("income:1",b,{income=true,position=service.world:IncomeFrame().Position})
  assert(service:Attack(a,"income:1",0));local contest=service.battles[a.outgoing]
  assert(service:Attack(b,"income:1",1));local returning=service.battles[b.outgoing]
  local x,z=returning.units[1].x,returning.units[1].z
  assert(returning.incomeJoin==contest.id)
  assert(service:ReturnHome(a,2))
  assert(service.battles[b.outgoing]==returning and returning.phase=="Travel" and not returning.incomeJoin and returning.friendlyTerritory)
  assert(returning.units[1].x==x and returning.units[1].z==z,"Returning owner teleported")
  service:Destroy();return "Unchanged owner keeps physical stationing trip after contest removal"
 end)
 test("Returning owner joins only on arrival and pauses capture",function()
  local service,a,b=setup();service:SetTerritoryOwner("income:1",b,{income=true,position=service.world:IncomeFrame().Position})
  assert(service:Attack(a,"income:1",0));local contest=service.battles[a.outgoing]
  front(contest,"A");contest.incomeActiveAt=1;contest:BeginCapture(1);contest.captureElapsed=2
  assert(service:Attack(b,"income:1",1));local returning=service.battles[b.outgoing]
  assert(not contest.defender and contest:Alive("B")==0)
  local first,tail=returning.units[1],returning.units[2]
  first.x,first.z=returning.destination.X,returning.destination.Z-1;first.marchPath=nil
  local path={Vector3.new(tail.x,1.05,tail.z),returning.marchDestination}
  March.Set(tail,path,0)
  local tailId=tail.petId
  service:Step(.1,1.1)
  assert(b.outgoing==contest.id and contest.defender==b.userId and contest.phase=="Fight")
  local adoptedTail
  for _,unit in contest.units do if unit.side=="B" and unit.petId==tailId then adoptedTail=unit end end
  assert(adoptedTail and adoptedTail.reinforcing and adoptedTail.marchPath==path,"Road straggler joined defense remotely")
  assert(contest:Alive("B")==1,"First arrival incorrectly activated the entire defending squad")
  local progress=contest.captureElapsed;service:Step(.1,1.2);assert(contest.captureElapsed==progress)
  service:Destroy();return "No remote defense; physical arrival halts the meter"
 end)
 test("Owner arriving after capture returns home safely",function()
  local service,a,b=setup();service:SetTerritoryOwner("income:1",b,{income=true,position=service.world:IncomeFrame().Position})
  assert(service:Attack(a,"income:1",0));local contest=service.battles[a.outgoing]
  assert(service:Attack(b,"income:1",1));local returning=service.battles[b.outgoing]
  capture(service,contest,2)
  assert(service.campOwners["income:1"].userId==a.userId and returning.phase=="Returning" and not returning.incomeJoin)
  assert(b.armyState=="Returning" and b.outgoing==returning.id)
  service:Destroy();return "No stale contest destination or stolen late garrison"
 end)
 test("Disconnect resolves only the departing participant",function()
  local service,a,b=setup();holder(service,b,0);assert(service:Attack(a,"income:1",3))
  service:CancelPlayer(a.userId,4)
  local holding=service.battles[b.outgoing]
  assert(holding and holding.phase=="Holding" and service.campOwners["income:1"].userId==b.userId)
  assert(not service.income.contestId and a.outgoing==nil and service.income.graceUntil==0)
  service:Destroy();return "Defender keeps one healthy/damaged continuation when challenger disconnects"
 end)
 test("NPC warning works in quiet multiplayer and human challenge cancels approach",function()
  Config.IncomeOutpost.NpcEnabled=true
  local service,a,b=setup();local holding=holder(service,b,0)
  service:StepIncome(120,130)
  assert(service.income.warningUntil==130+Config.IncomeOutpost.WarningSeconds,"Quiet multiplayer never warned")
  local coins=b.coins;service:StepIncome(1,131);assert(b.coins==coins+8)
  service:StepIncome(.1,service.income.warningUntil)
  local raid=service.battles[service.income.raidId]
  assert(raid and not raid.incomeActiveAt and service.battles[b.outgoing]==holding)
  local unit=holding.units[1]
  assert(service:Attack(a,"income:1",170))
  local contest=service.battles[a.outgoing]
  assert(not service.battles[raid.id] and not service.income.raidId and not service.income.warningUntil)
  local preserved=false;for _,u in contest.units do if u.petId==unit.petId and u.hp==unit.hp then preserved=true end end
  assert(preserved and b.outgoing==contest.id)
  service:Destroy();Config.IncomeOutpost.NpcEnabled=false;return "Human order preempts pre-active NPCs without losing holder"
 end)
 test("NPC first arrival commits actual garrison and loss makes site neutral",function()
  Config.IncomeOutpost.NpcEnabled=true
  local service,_,b=setup();local holding=holder(service,b,0)
  service:StartIncomeRaid(service.campOwners["income:1"],10)
  local raid=service.battles[service.income.raidId]
  assert(b.outgoing==holding.id and not raid.defender)
  front(raid,"A");service:Step(.1,10.1)
  assert(raid.incomeActiveAt and b.outgoing==raid.id and raid.defender==b.userId)
  assert(not service.battles[holding.id] and service.income.contestId==raid.id)
  service:Finish(raid,"A",11)
  assert(not service.campOwners["income:1"] and service:IncomeSummary(b,11).effectiveRate==0)
  assert(service.battles[b.outgoing].phase=="Returning" and raid.phase=="Returning")
  service:Destroy();Config.IncomeOutpost.NpcEnabled=false;return "Finite raiders capture to neutral and both groups leave physically"
 end)
 test("Actor transfer takes each rig once and remaps unit references",function()
  local source=Battle.new("old",1002,"income:1",Vector3.zero,Vector3.zero,0)
  source:AddArmy("A",{{id="one",species="Duck",stars=1},{id="two",species="Duck",stars=1}},Vector3.zero)
  source.units[1].hp-=2;source.units[2].replacementFor=source.units[1].id
  local path={Vector3.zero,Vector3.new(5,1,5)};source.units[2].marchPath=path;source.units[2].reinforcing=true
  local actors={one={},two={}};local taken=0
  source.actors={TakeUnit=function(_,id) taken+=1;return if id=="1" then actors.one else actors.two end}
  local destination=Battle.new("new",1001,"income:1",Vector3.zero,Vector3.zero,0)
  destination:AddArmy("A",{{id="attacker",species="Duck",stars=1}},Vector3.zero)
  local adopted={};destination.actors={Adopt=function(_,unit,actor) adopted[unit.id]=actor end}
  local oldHp=source.units[1].hp
  local moved=Transfer.Transfer(source,destination,"A","B")
  assert(#source.units==0 and #moved==2 and taken==2 and #destination.units==3)
  assert(moved[1].id=="2" and moved[2].replacementFor=="2" and moved[1].hp==oldHp)
  assert(moved[2].marchPath==path and adopted["2"]==actors.one and adopted["3"]==actors.two)
  return "Rig identity, damaged health and live reinforcement route survive side A to B handoff"
 end)
 Config.IncomeOutpost=original;Config.Hill=originalHill
 return results
end
return Checks
