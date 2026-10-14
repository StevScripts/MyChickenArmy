-- 7-day login streak (docs/team/launch/13_D1_DAILY_STREAK.md). Isolated sessions,
-- a stub server and fixed clock values only; no DataStore or live-world access.
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local Daily=require(Server.DailyService)
local Hill=require(Server.HillService)
local Currency=require(Shared.CurrencyLimits)
local Checks={}

local DAY=86400
local BASE_DAY=20740 -- A fixed UTC day number; never the real clock.
local function at(day, hour)
 return (BASE_DAY+day)*DAY+(hour or 9)*3600
end

-- Stub server: records analytics names and UpdateSession calls.
local function stubServer()
 local server={counts={},hist={},updates=0}
 server.world={UpdateSession=function() server.updates+=1 end}
 server.analytics={
  LaunchCount=function(_,_,name) server.counts[name]=(server.counts[name] or 0)+1 end,
  LaunchHist=function(_,_,name,value) table.insert(server.hist,{name=name,value=value}) end,
 }
 return server
end

local function newSession(id)
 local s=Session.new(id,"Daily",1);s.loaded=true
 s.tutorial.guideCompleted=true -- The streak starts after the main tutorial.
 return s
end

local function emptyFlock(s)
 for id in s.pets do s.pets[id]=nil end
 s:RefreshArmy()
end

local function strongFlock(s)
 emptyFlock(s)
 local a=s:AddPet("Knight",1);a.level=3
 local b=s:AddPet("Dragon",1);b.level=2
 s:AddPet("Duck",1)
 s.incomeLevel=2;s.eggSpeedLevel=3
 s:RefreshArmy()
end

local function perSecond(s)
 return s:EarnedAmount(s:Income()*s:EggProductionMultiplier(),"eggs")
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,why=pcall(fn)
  table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
  print((if ok then "PASS " else "FAIL ")..name..(if ok then "" else " :: "..tostring(why)))
 end

 test("First ever check grants streak 1, slot 1 and cash",function()
  local s,server=newSession(-961),stubServer()
  emptyFlock(s)
  local coins,revision=s.coins,s.revision
  local granted=Daily.Check(s,at(0),server)
  assert(granted,"Nothing granted")
  assert(s.daily.streak==1 and s.daily.lastDay==BASE_DAY and s.daily.best==1,"daily state")
  assert(granted.slot==1 and granted.streak==1 and granted.day==BASE_DAY and granted.rolls==0,"grant fields")
  assert(granted.cash==Daily.MinIncome*5*60,"Slot 1 cash "..tostring(granted.cash))
  assert(s.coins==coins+granted.cash,"Coins not credited")
  assert(s.dailyGranted==granted and s.revision>revision and server.updates==1,"Touch/UpdateSession")
  assert(server.counts["daily.claim.1"]==1 and server.counts["daily.reset"]==nil,"claim analytics")
  assert(#server.hist==1 and server.hist[1].name=="daily.streak" and server.hist[1].value==1,"streak histogram")
 end)

 test("A second check the same day grants nothing",function()
  local s,server=newSession(-962),stubServer()
  assert(Daily.Check(s,at(0,1),server))
  -- The snapshot carries the grant for the popup; the save never does.
  local snap=s:Snapshot(0)
  assert(snap.daily.granted and snap.daily.granted.day==BASE_DAY and snap.daily.streak==1,"snapshot")
  assert(s:ToData().dailyGranted==nil,"dailyGranted was saved")
  local coins,revision,credits=s.coins,s.revision,s.hillRollCredits
  assert(Daily.Check(s,at(0,23),server)==nil,"Granted twice in one day")
  assert(Daily.Check(s,at(0,12),server)==nil)
  assert(s.coins==coins and s.revision==revision and s.hillRollCredits==credits and s.daily.streak==1)
  assert(server.counts["daily.claim.1"]==1 and server.updates==1)
  -- An earlier day (another server's clock behind) never re-grants or resets.
  assert(Daily.Check(s,at(-1),server)==nil and s.daily.streak==1 and s.daily.lastDay==BASE_DAY)
 end)

 test("The next day continues the streak; a skipped day resets it",function()
  local s,server=newSession(-963),stubServer()
  Daily.Check(s,at(0,23),server)
  local granted=Daily.Check(s,at(1,0),server)
  assert(granted and granted.slot==2 and s.daily.streak==2 and s.daily.best==2,"Day 2")
  assert(server.counts["daily.reset"]==nil)
  -- Skip day 2: day 3 starts over.
  granted=Daily.Check(s,at(3),server)
  assert(granted and granted.slot==1 and granted.streak==1 and s.daily.streak==1,"Reset streak")
  assert(s.daily.best==2,"best kept")
  assert(server.counts["daily.reset"]==1,"daily.reset not recorded")
  -- A broken streak of 1 is not a reset.
  Daily.Check(s,at(5),server)
  assert(s.daily.streak==1 and server.counts["daily.reset"]==1,"Streak of 1 counted as reset")
  assert(server.counts["daily.claim.1"]==3 and server.counts["daily.claim.2"]==1)
 end)

 test("Day 8 grants slot 1 again and best keeps 8",function()
  local s,server=newSession(-964),stubServer()
  for day=0,7 do assert(Daily.Check(s,at(day),server)) end
  assert(s.daily.streak==8 and s.dailyGranted.slot==1 and s.dailyGranted.streak==8,"Day 8 slot")
  assert(s.daily.best==8)
  Daily.Check(s,at(10),server)
  assert(s.daily.streak==1 and s.daily.best==8,"best lost after reset")
  assert(server.counts["daily.claim.1"]==3 and server.counts["daily.claim.7"]==1)
 end)

 test("Roll days add hill roll credits; day 7 adds 3 rolls plus cash",function()
  local s,server=newSession(-965),stubServer()
  emptyFlock(s)
  s.hillRollCredits=0
  Daily.Check(s,at(0),server);Daily.Check(s,at(1),server)
  local coins=s.coins
  local day3=Daily.Check(s,at(2),server)
  assert(day3 and day3.slot==3 and day3.rolls==1 and day3.cash==0,"Day 3 grant")
  assert(s.hillRollCredits==1 and s.coins==coins,"Day 3 credits/coins")
  for day=3,5 do Daily.Check(s,at(day),server) end
  assert(s.hillRollCredits==3,"Day 6 adds 2 rolls")
  coins=s.coins
  local day7=Daily.Check(s,at(6),server)
  assert(day7 and day7.slot==7 and day7.rolls==3,"Day 7 grant")
  assert(day7.cash==Daily.MinIncome*60*60 and s.coins==coins+day7.cash,"Day 7 cash")
  assert(s.hillRollCredits==6,"Day 7 rolls")
  assert((s.crateCredits or 0)==0,"Galaxy Crate credits granted")
  -- HillService turns the credits into recruits while the flock has room.
  local count=s:Count()
  local granted=Hill.Deliver({random=Random.new(7)},s)
  assert(#granted==6 and s:Count()==count+6 and s.hillRollCredits==0,"Credits were not delivered")
 end)

 test("Cash scales with income, uses the $10/s floor and respects the cap",function()
  local s,server=newSession(-966),stubServer()
  strongFlock(s)
  local rate=perSecond(s)
  assert(rate>Daily.MinIncome,"Fixture income too small: "..rate)
  local coins=s.coins
  local granted=Daily.Check(s,at(0),server)
  assert(granted and granted.cash==math.floor(rate*300),"Income cash "..tostring(granted and granted.cash))
  assert(s.coins==coins+granted.cash)
  -- 2x Cash doubles the income figure (daily itself is never doubled again).
  local doubled=newSession(-967);strongFlock(doubled);doubled.entitlements.DoubleCash=true
  local cash2=Daily.Check(doubled,at(0),stubServer()).cash
  assert(math.abs(cash2-2*granted.cash)<=1,"2x Cash "..cash2.." vs "..granted.cash)
  -- Floor: an empty flock still earns $10/s worth.
  local poor=newSession(-968);emptyFlock(poor)
  assert(Daily.Check(poor,at(0),stubServer()).cash==3000)
  -- Near the cap: only what fits is credited, never above MaxCoins.
  local rich=newSession(-969);strongFlock(rich);rich.coins=Currency.MaxCoins-100
  local capped=Daily.Check(rich,at(0),stubServer())
  assert(capped.cash==100 and rich.coins==Currency.MaxCoins,"Cap headroom")
  -- At the cap: no cash, but the streak still advances.
  local after=Daily.Check(rich,at(1),stubServer())
  assert(after and after.cash==0 and rich.coins==Currency.MaxCoins and rich.daily.streak==2,"At cap")
 end)

 test("An unloaded, closing or save-lost session is untouched",function()
  for _,case in {"unloaded","closing","saveLost"} do
   local s,server=newSession(-970),stubServer()
   if case=="unloaded" then s.loaded=false elseif case=="closing" then s.closing=true else s.saveLost=true end
   local coins,revision,credits=s.coins,s.revision,s.hillRollCredits
   assert(Daily.Check(s,at(0),server)==nil,case.." granted")
   assert(s.daily.streak==0 and s.daily.lastDay==0 and s.daily.best==0,case.." daily changed")
   assert(s.coins==coins and s.revision==revision and s.hillRollCredits==credits and s.dailyGranted==nil,case.." changed")
   assert(server.updates==0 and next(server.counts)==nil,case.." side effects")
  end
 end)

 test("A save round trip keeps the streak and the next day continues it",function()
  local s,server=newSession(-971),stubServer()
  Daily.Check(s,at(0),server);Daily.Check(s,at(1),server)
  local loaded=Session.new(-971,"Daily",1)
  assert(loaded:LoadData(s:ToData()))
  loaded.loaded=true
  assert(loaded.dailyGranted==nil and loaded.daily.streak==2)
  assert(Daily.Check(loaded,at(1,20),server)==nil,"Rejoin same day re-granted")
  local granted=Daily.Check(loaded,at(2),server)
  assert(granted and granted.slot==3 and loaded.daily.streak==3)
 end)

 test("Nothing is claimed until the main tutorial is done",function()
  local s,server=newSession(-973),stubServer()
  s.tutorial.guideCompleted=false
  local coins=s.coins
  assert(Daily.Check(s,at(0),server)==nil,"Granted during the tutorial")
  assert(s.daily.lastDay==0 and s.daily.streak==0 and s.coins==coins and s.dailyGranted==nil)
  -- Finishing the guide later the same day grants Day 1 that day.
  s.tutorial.guideCompleted=true
  local granted=Daily.Check(s,at(0,10),server)
  assert(granted and granted.slot==1 and s.daily.streak==1)
  -- A pre-guide save that already won Cluck Camp counts as done.
  local old=newSession(-974);old.tutorial.guideCompleted=false;old.tutorial.wonCamp=true
  assert(Daily.Check(old,at(0),server),"Pre-guide veteran got nothing")
 end)

 test("The stub server without analytics or world is safe",function()
  local s=newSession(-972)
  assert(Daily.Check(s,at(0),{world={UpdateSession=function() end},analytics=nil}))
  assert(Daily.Check(s,at(1),nil))
  assert(s.daily.streak==2)
 end)

 local failed=0
 for _,r in results do if not r.passed then failed+=1 end end
 print(("DailyChecks: %d passed, %d failed"):format(#results-failed,failed))
 return results
end
return Checks
