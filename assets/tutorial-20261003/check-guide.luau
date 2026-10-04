-- Studio server check: isolated tables and unsaved PlayerSession objects only.
local Guide=require(game.ReplicatedStorage.PetRoll.Shared.TutorialGuide)
local Tutorial=require(game.ServerStorage.PetRoll.TutorialService)
local Session=require(game.ServerStorage.PetRoll.PlayerSession)
local passed={}
local function check(name,condition) assert(condition,name);table.insert(passed,name) end
local function fresh()
 return {tutorial={},pets={{},{},{}},coins=2400,capacity=3,selectedCount=3,
  eggs={carriedCount=0,carriedValue=0},armyState="Home",saveStatus="session-only",
  offer={price=600},nextSlot={price=1200}}
end
local s=fresh()
check("starter points at real podium",Guide.Resolve(s).id=="Recruit")
s.saveStatus="loading";check("loading profile does not show objectives",Guide.Resolve(s)==nil);s.saveStatus="session-only"
s.offer.price=5000;check("unaffordable recruit routes to eggs",Guide.Resolve(s).id=="RecoverCollect")
s.eggs.carriedValue=30;check("small recovery bag keeps collecting",Guide.Resolve(s).id=="RecoverCollect")
s.eggs.carriedValue=2600;check("funded recovery bag routes to instant sale",Guide.Resolve(s).id=="RecoverSell")
s=fresh();s.tutorial.bought=true;table.insert(s.pets,{});check("purchase advances to collection",Guide.Resolve(s).id=="Collect")
s.eggs.carriedCount=1;s.eggs.carriedValue=20;check("carried egg advances to sale",Guide.Resolve(s).id=="Sell")
s.tutorial.collectedEggs=true;s.tutorial.soldEggs=true;check("cash army upgrade precedes camp without a gate",Guide.Resolve(s).id=="Expand")
s.coins=0;check("underfunded slot keeps collecting",Guide.Resolve(s).id=="RecoverCollect")
s.eggs.carriedValue=1200;check("funded slot bag routes to sale",Guide.Resolve(s).id=="RecoverSell")
s.capacity=4;check("existing capacity is recognized",Guide.Resolve(s).id=="Select")
s.selectedCount=4;check("existing squad advances to deploy",Guide.Resolve(s).id=="Deploy")
s.outgoing="battle";check("in-progress battle replaces directions",Guide.Resolve(s).id=="Battle")
s.outgoing=nil;s.armyState="Returning";check("returning army gets recovery guidance",Guide.Resolve(s).id=="Return")
s.incoming="raid";check("home defense has priority",Guide.Resolve(s).id=="Defend")
s=fresh();s.tutorial.wonCamp=true;check("established veterans are not restarted",Guide.Resolve(s)==nil)
s.tutorial.guideStarted=true;check("new guide victory can end early",Guide.Resolve(s).id=="Complete")
s.tutorial.guideSkipped=true;check("skip removes instructions",Guide.Resolve(s)==nil)

local events={}
local service=Tutorial.new(function(e) table.insert(events,e) end)
local session={userId=-20261003,loaded=true,tutorial={},coins=2400,Touch=function() end}
local function count(name,detail)
 local n=0;for _,e in events do if e.name==name and (not detail or e.detail==detail) then n+=1 end end;return n
end
local function observe(state) state.tutorial=session.tutorial;service:Observe(session,state) end
service:Begin(nil,session);s=fresh();observe(s)
check("first guide entry persisted once",session.tutorial.guideStarted and count("FTUEEntered")==1)
session.BestPetIds=function() return {"a","b","c"} end
service:Action(session,"SelectBest",true,2400,{},"a:b:c")
check("unchanged selection is not a meaningful first action",count("FTUEFirstActionSeconds")==0)
service:Action(session,"CashUpgrade",false,2400,{})
service:Action(session,"CashUpgrade",false,2400,{})
check("cash-node attempts are bounded per step",count("FTUEInteraction","AttemptCashUpgrade")==1)
observe(s);check("repeated snapshots do not repeat entry",count("FTUEEntered")==1)
s.eggs.receipts={{id="rover1",collector="rover"}};observe(s)
check("automatic vacuum is not a player first action",count("FTUEFirstActionSeconds")==0)
s.eggs.receipts={{id="player1",collector="player"}};observe(s);observe(s)
check("real pickup logs one first action",count("FTUEFirstActionSeconds")==1)
service:Signal(session,"Skip");observe(s)
check("skip is not fake completion",session.tutorial.guideSkipped and not session.tutorial.guideCompleted and count("FTUEOutcome","Skipped")==1)
service:Action(session,"Roll",true,2400,{})
check("independent play tracked after skip",count("FTUEIndependentAction")==1)
service:Signal(session,"Resume");observe(s)
check("resume clears skipped state without reset",not session.tutorial.guideSkipped and session.tutorial.guideStarted)
service:Signal(session,"Bogus");check("invalid tutorial signal cannot complete",not session.tutorial.guideCompleted)
service:Action(session,"Attack",false,2400,{targetId="camp:1:1"})
check("rejected attack cannot complete deployment",not session.tutorial.guideDeployed)
service:Action(session,"Attack",true,2400,{targetId="camp:1:1"});observe(s)
check("accepted camp command records deployment",session.tutorial.guideDeployed and count("FTUEMilestone")==1)
session.tutorial.wonCamp=true;observe(s);observe(s)
check("victory completes exactly once",session.tutorial.guideCompleted and count("FTUEOutcome","EarlyVictory")==1)
service:Signal(session,"Finish");service:Action(session,"CashUpgrade",true,2400,{})
check("independent play tracked after completion",count("FTUEIndependentAction")==2)
service.records[session.userId].at-=600;observe(s)
check("survival checkpoints have separate reportable categories",count("FTUESurvival","T30")==1 and count("FTUESurvival","T600")==1)
service:Release(session);check("release removes visit and income callback",service.records[session.userId]==nil and session.onTutorialIncome==nil)
session.tutorial={};service:Begin(nil,session);s=fresh();observe(s)
service.records[session.userId].starts.Recruit-=31;session.tutorial.bought=true;observe(s)
check("step duration is numerically measured and bucketed",count("FTUEStepCompletedSeconds","30To59")==1)
service:Release(session)

local before=Session.new(-20261004,"Isolated tutorial check",1)
before.tutorial={guideStarted=true,guideSkipped=true,guideDeployed=true,guideCompleted=false,bought=true}
local saved=before:ToData();local after=Session.new(-20261005,"Isolated reload",1);after:LoadData(saved)
check("save round trip preserves guide and gameplay facts",after.tutorial.guideStarted and after.tutorial.guideSkipped and after.tutorial.guideDeployed and after.tutorial.bought and not after.tutorial.guideCompleted)
return {passed=#passed,checks=passed,events=events,scope="Isolated in-memory data; no DataStore or published analytics calls"}
