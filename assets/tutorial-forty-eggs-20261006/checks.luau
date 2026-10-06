-- Disposable fixture entrypoint: Run({Session=..., EggService=..., Guide=...}).
-- The caller supplies freshly required clones of the synced modules in Studio
-- Edit. No live player sessions, DataService, remotes, or parented Instances.
return function(modules)
 local Session,EggService,Guide=modules.Session,modules.EggService,modules.Guide
 local checks,sessions={},{}
 local pad=Instance.new("Part")
 pad.Size,pad.CFrame=Vector3.new(10,1,10),CFrame.new()
 local function check(name,ok)
  table.insert(checks,{name=name,ok=ok==true});assert(ok,name)
 end
 local function fresh()
  local s=Session.new(-104000-#sessions,"Forty eggs fixture",1)
  s.loaded,s.saveStatus=true,"session";table.insert(sessions,s);return s
 end
 local function eggsFor(s)
  return EggService.new({EggDeposit=function() return pad,s.userId end})
 end
 local function snapshot(s)
  local state=s:Snapshot(100)
  state.eggs={carriedCount=s.eggCarry.count,carriedValue=s.eggCarry.value}
  return state
 end
 local function load(data)
  local s=fresh();assert(s:LoadData(data));return s
 end
 local ok,why=xpcall(function()
  local s=fresh();local eggs=eggsFor(s);local yard=eggs:Yard(s)
  check("fresh zero uses progress instruction",s.tutorial.collectedEggCount==0
   and Guide.Resolve(snapshot(s)).text=="Collect 40 eggs (0/40)")
  local fakeBag=snapshot(s);fakeBag.eggs={carriedCount=100,carriedValue=400}
  check("carried bag cannot bypass counter",not Guide.Facts(fakeBag).Collect)
  local drop={id="stack",stack=39,value=3900}
  eggs:Pay(s,yard,drop,100)
  check("39 units remain on Collect regardless of value",not s.tutorial.collectedEggs
   and s.eggCarry.count==39 and Guide.Resolve(snapshot(s)).text=="Collect 40 eggs (39/40)")
  local revision=s.revision
  eggs:Pay(s,yard,drop,101)
  check("same pickup counted only once",s.tutorial.collectedEggCount==39
   and s.eggCarry.count==39 and s.revision==revision and #yard.receipts==1)
  eggs:Pay(s,yard,{id="single",value=4},102)
  check("unstacked fortieth egg advances to Sell",s.tutorial.collectedEggCount==40
   and s.tutorial.collectedEggs and Guide.Resolve(snapshot(s)).id=="Sell")
  eggs:Pay(s,yard,{id="extra",stack=100,value=400},103)
  check("overshoot caps progress but not earned eggs",s.tutorial.collectedEggCount==40
   and s.eggCarry.count==140 and yard.receipts[3].count==100)

  local partial=fresh();local partialEggs=eggsFor(partial)
  partialEggs:Pay(partial,partialEggs:Yard(partial),{id="partial",stack=12,value=48},104)
  check("actual early sale succeeds",partialEggs:Deposit(partial,pad.Position,105))
  check("sale retains partial progress",partial.eggCarry.count==0 and partial.tutorial.soldEggs
   and Guide.Resolve(snapshot(partial)).text=="Collect 40 eggs (12/40)")
  local restored=load(partial:ToData())
  check("save/load retains partial count without sale bypass",restored.tutorial.collectedEggCount==12
   and restored.tutorial.soldEggs and not restored.tutorial.collectedEggs
   and Guide.Resolve(snapshot(restored)).id=="Collect")
  local restoredEggs=eggsFor(restored)
  restoredEggs:Pay(restored,restoredEggs:Yard(restored),{id="remainder",stack=28,value=112},106)
  check("cumulative collection advances after earlier sale",restored.tutorial.collectedEggCount==40
   and restored.eggCarry.count==28 and Guide.Resolve(snapshot(restored)).id=="Roll")
  check("completed count survives round trip",load(restored:ToData()).tutorial.collectedEggCount==40)

  local rover=fresh();local roverEggs=eggsFor(rover);local roverYard=roverEggs:Yard(rover)
  roverYard.rover={enabled=true,pendingCount=39,cargoCount=0,cargoValue=0}
  revision=rover.revision
  local roverDrop={id="rover",collector="rover",stack=39,value=156}
  roverEggs:Pay(rover,roverYard,roverDrop,107)
  check("active rover advances saved progress and revision",rover.tutorial.collectedEggCount==39
   and rover.revision>revision and rover.eggCarry.count==0 and roverYard.rover.cargoCount==39)
  revision=rover.revision;roverEggs:Pay(rover,roverYard,roverDrop,108)
  check("rover pickup is deduplicated",rover.revision==revision and roverYard.rover.cargoCount==39)
  roverYard.rover.enabled=false
  roverEggs:Pay(rover,roverYard,{id="disabled",collector="rover",stack=1,value=4},109)
  check("disabled rover fallback reaches forty once",rover.tutorial.collectedEggCount==40
   and rover.eggCarry.count==1 and roverYard.rover.cargoCount==39)

  local baseline=fresh():ToData()
  for _,key in {"collectedEggs","soldEggs","wonCamp","guideCompleted","carriedEggs","unfinished"} do
   local data=table.clone(baseline);data.tutorial=table.clone(baseline.tutorial)
   data.tutorial.collectedEggCount=nil
   if key=="carriedEggs" then data.eggCarry={count=1,value=4}
   elseif key~="unfinished" then data.tutorial[key]=true end
   local legacy=load(data)
   check("legacy migration: "..key,legacy.tutorial.collectedEggCount==(if key=="unfinished" then 0 else 40))
  end
  local data=table.clone(baseline)
  data.tutorial={starterArmy=true,collectedEggCount=12,collectedEggs=true,soldEggs=true}
  local numeric=load(data)
  check("present numeric count overrides stale boolean",numeric.tutorial.collectedEggCount==12
   and not numeric.tutorial.collectedEggs and Guide.Resolve(snapshot(numeric)).id=="Collect")
  data.tutorial={starterArmy=true,collectedEggCount=100}
  check("over-target saved counter is bounded",load(data).tutorial.collectedEggCount==40)
  for _,value in {0/0,math.huge,-1,1.5,"40"} do
   data.tutorial={starterArmy=true,collectedEggCount=value}
   local untouched=fresh();revision=untouched.revision
   check("invalid count rejected atomically: "..tostring(value),not untouched:LoadData(data)
    and untouched.revision==revision and untouched.tutorial.collectedEggCount==0)
  end
 end,debug.traceback)
 pad:Destroy()
 for _,s in sessions do s:Destroy() end
 assert(ok,why)
 return {passed=#checks,checks=checks,playerDataWrites=0,liveSessionsUsed=0}
end
