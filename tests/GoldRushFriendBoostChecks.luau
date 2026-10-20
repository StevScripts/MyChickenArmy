-- October 20 Gold Rush + Friend Boost (docs/team/GOLD_RUSH_FRIEND_BOOST.md).
-- Isolated sessions only; no DataStore or live-world access. The manual-rush check
-- starts a 30-second rush on this VM's GoldRushService and ends it again.
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local GoldRush=require(Server.GoldRushService)
local FriendBoost=require(Server.FriendBoostService)
local Offline=require(Server.OfflineCash)
local Config=require(Shared.Config)
local Checks={}

local function near(a,b,why)
 assert(math.abs(a-b)<1e-6,(why or "Values differ")..": "..tostring(a).." ~= "..tostring(b))
end

local function newSession(id)
 local s=Session.new(id,"Rush",1);s.loaded=true
 s.tutorial.guideCompleted=true;s.tutorial.bought=true
 return s
end

-- The scheduled state at this moment (a real rush may be running).
local function scheduledMultiplier()
 local now=workspace:GetServerTimeNow()
 local from,to=GoldRush.Window(now)
 return if now>=from and now<to then Config.GoldRush.CoinMultiplier else 1
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,why=pcall(fn)
  table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
  print((if ok then "PASS " else "FAIL ")..name..(if ok then "" else " :: "..tostring(why)))
 end

 test("Rushes follow one wall clock",function()
  local rush=Config.GoldRush
  local base=1500*rush.EverySeconds+rush.OffsetSeconds
  local from,to=GoldRush.Window(base)
  near(from,base);near(to,base+rush.Seconds)
  from,to=GoldRush.Window(base+rush.Seconds-0.5)
  near(from,base,"Still inside the rush")
  from,to=GoldRush.Window(base+rush.Seconds)
  near(from,base+rush.EverySeconds,"The next rush after this one ends")
  from,to=GoldRush.Window(base-1)
  near(from,base,"The upcoming rush");near(to,base+rush.Seconds)
 end)

 test("A rush doubles earned Coins only, and never offline earnings",function()
  local s=newSession(-981)
  local offline=Offline.Rate(s)
  GoldRush.StartNow(30);GoldRush.Step({[s.userId]=s})
  local multiplier=Config.GoldRush.CoinMultiplier
  assert(GoldRush.Active() and GoldRush.Multiplier()==multiplier,"Manual rush did not start")
  near(s:EarnedAmount(100,"eggs"),100*multiplier,"Eggs")
  near(s:EarnedAmount(100,"battle"),100*multiplier,"Battles and Missions")
  near(s:EarnedAmount(100,"eggs",true),100,"Steady amount")
  for _,source in {"sale","offline","robux","daily","operation"} do near(s:EarnedAmount(100,source),100,source) end
  near(Offline.Rate(s),offline,"Offline rate froze the rush")
  s.coins=0
  near(s:Credit(100,"eggs"),100*multiplier,"Credited eggs")
  near(s:Credit(100,"sale"),100,"Credited sale")
  GoldRush.StartNow(0);GoldRush.Step({[s.userId]=s})
  near(GoldRush.Multiplier(),scheduledMultiplier(),"Back on the wall clock")
 end)

 test("Friend Boost: +10% per friend here, capped",function()
  local rule=Config.FriendBoost
  near(FriendBoost.Boost(0),0);near(FriendBoost.Boost(1),rule.PerFriend)
  near(FriendBoost.Boost(3),math.min(rule.Max,3*rule.PerFriend))
  near(FriendBoost.Boost(99),rule.Max,"Cap")
  near(FriendBoost.Boost(-2),0,"Never negative")
 end)

 test("Friend Boost applies once to earned Coins, never offline",function()
  local s=newSession(-982)
  local offline=Offline.Rate(s)
  near(s.friendBoost,0,"New sessions start without a boost")
  s.friendBoost=0.3
  local rush=GoldRush.Multiplier()
  near(s:EarnedAmount(100,"eggs"),100*rush*1.3,"Eggs")
  near(s:EarnedAmount(100,"eggs",true),100,"Steady amount")
  near(s:EarnedAmount(100,"sale"),100,"Sales are refunds")
  near(s:EarnedAmount(100,"robux"),100,"Purchases")
  near(Offline.Rate(s),offline,"Offline rate froze the boost")
  -- The boost is live only: never saved.
  assert(s:ToData().friendBoost==nil,"Friend Boost was saved")
 end)

 local failed=0
 for _,r in results do if not r.passed then failed+=1 end end
 print(("GoldRushFriendBoostChecks: %d passed, %d failed"):format(#results-failed,failed))
 return results
end
return Checks
