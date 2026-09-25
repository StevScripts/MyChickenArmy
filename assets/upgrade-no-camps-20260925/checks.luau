-- Run with Lune from the repository root. Real modules; in-memory Roblox boundaries only.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local modules = {}
local function folder(name)
 return setmetatable({Name=name}, {__index=function(self,key)
  local node={Name=key,Parent=self,path="src/"..name.."/"..key..".luau"}
  rawset(self,key,node);return node
 end})
end
local shared, server = folder("shared"), folder("server")
local guid=0
local services={ReplicatedStorage={PetRoll={Shared=shared}},HttpService={GenerateGUID=function()
 guid+=1;return "upgrade-check-"..guid
end}}
local loadModule
loadModule=function(node)
 if modules[node.path] then return modules[node.path] end
 local environment={
  game={GetService=function(_,name) return assert(services[name],"Unexpected service: "..name) end},
  script=node,require=function(dependency) return loadModule(dependency) end,
  Random={new=function() return {NextNumber=function() return 0.5 end} end},
  Vector3=roblox.Vector3,Color3=roblox.Color3,CFrame=roblox.CFrame,Enum=roblox.Enum,
 }
 local value=luau.load(fs.readFile(node.path),{debugName=node.path,environment=environment})()
 modules[node.path]=value;return value
end
local Config=loadModule(shared.Config)
local Definitions=loadModule(shared.UpgradeCatalog)
local Session=loadModule(server.PlayerSession)
local Army=loadModule(server.ArmyService)
local Roll=loadModule(server.RollService)
local Upgrades=loadModule(server.UpgradeService)
local rolls=Roll.new()
local board=Upgrades.new({},rolls)
local canUse=true
board.CanUse=function() return canUse end -- Spatial code is unchanged; no real player or Studio world.
local checked=0
local function check(name,fn)
 fn();checked+=1;print("PASS "..name)
end
local function fresh()
 local s=Session.new(700,"Upgrade check",1)
 s.loaded=true;s.coins=1e9;s.plotExpansionAvailable=true
 s.rollSlotLimit=6;s.rollSlotCount=1
 return s
end
local function buy(s,key)
 local offer=board:Offers(s)[key]
 assert(offer.unlocked and offer.price,key.." must have an available next level")
 local before=s.coins
 local ok,message=board:Buy({},s,key,offer.level,offer.price)
 assert(ok,message);assert(s.coins==before-offer.price,"Incorrect charge: "..key)
end

check("Every board track reaches its configured maximum with zero camp wins",function()
 local s=fresh()
 for _,key in Definitions.Order do
  local steps=0
  while board:Offers(s)[key].price do buy(s,key);steps+=1;assert(steps<20) end
  local before=s.coins;local offer=board:Offers(s)[key]
  assert(not board:Buy({},s,key,offer.level,0));assert(s.coins==before)
 end
 assert(s.capacity==Config.MaxSlots and s.incomeLevel==#Config.IncomePrices)
 assert(s.luck==#Config.LuckPrices and s.eggSpeedLevel==#Definitions.EggSpeedPrices)
 assert(s.plotSizeLevel==#Definitions.PlotPrices and s.rollSlotsUnlocked==6)
 assert(s.promotion==1 and next(s.firstWins)==nil and next(s.frontierWins)==nil)
end)

check("Menu income, luck and army transactions are also independent of conquest",function()
 local s=fresh()
 while s:GlobalUpgrade("Income") do assert(Army.UpgradeIncome(s)) end
 while s:GlobalUpgrade("Luck") do assert(rolls:UpgradeLuck(s)) end
 while s:NextSlot() do assert(Army.Expand(s)) end
 assert(s.promotion==1 and s.capacity==10 and s.incomeLevel==4 and s.luck==4)
end)

check("Rank one and rank four expose the same next prices and eligibility",function()
 local a,b=fresh(),fresh();b.promotion=4;b.recruitTier=4;b.firstWins={true,true,true}
 a.capacity=7;b.capacity=7
 a.incomeLevel=2;b.incomeLevel=2;a.eggSpeedLevel=2;b.eggSpeedLevel=2
 a.plotSizeLevel=2;b.plotSizeLevel=2;a.rollSlotsUnlocked=4;b.rollSlotsUnlocked=4
 for _,key in Definitions.Order do
  local x,y=board:Offers(a)[key],board:Offers(b)[key]
  assert(x.unlocked and y.unlocked and x.price==y.price,key)
  assert(not string.find(x.requirement,"Reach",1,true))
 end
end)

check("Insufficient cash and stale quotes cannot purchase or charge",function()
 for _,key in Definitions.Order do
  local s=fresh();local offer=board:Offers(s)[key]
  s.coins=offer.price-1
  assert(not board:Buy({},s,key,offer.level,offer.price));assert(s.coins==offer.price-1)
  s.coins=1e9
  assert(not board:Buy({},s,key,offer.level+1,offer.price));assert(s.coins==1e9)
  assert(not board:Buy({},s,key,offer.level,offer.price+1));assert(s.coins==1e9)
 end
end)

check("Spatial access, ready state, plot availability and authored slot limits remain enforced",function()
 local s=fresh();local offer=board:Offers(s).EggSpeed
 canUse=false;assert(not board:Buy({},s,"EggSpeed",offer.level,offer.price));canUse=true
 for _,field in {"loaded","closing","saveLost"} do
  local t=fresh();t[field]=field~="loaded"
  assert(not board:Buy({},t,"EggSpeed",0,Definitions.EggSpeedPrices[1]))
 end
 s.plotExpansionAvailable=false;assert(not board:Offers(s).PlotSize.unlocked)
 assert(not board:Buy({},s,"PlotSize",0,Definitions.PlotPrices[1]))
 s.rollSlotLimit=1;assert(board:Offers(s).RollSlots.price==nil)
 assert(s.coins==1e9)
end)

check("Rank-one profiles retain all purchased upgrade levels and balances on roundtrip",function()
 local s=fresh()
 for _,key in Definitions.Order do while board:Offers(s)[key].price do buy(s,key) end end
 local data=s:ToData();local t=fresh()
 local ok,message=t:LoadData(data);assert(ok,message)
 assert(t.coins==s.coins and t.promotion==1 and t.capacity==10)
 assert(t.incomeLevel==4 and t.luck==4 and t.eggSpeedLevel==4 and t.plotSizeLevel==4 and t.rollSlotsUnlocked==6)
 assert(t:Count()==s:Count() and data.dataRevision==Config.DataRevision)
 assert(t:Snapshot(0).progression.capacityCap==Config.MaxSlots)
end)

check("Paid army capacity remains additive without a camp prerequisite",function()
 local s=fresh();s.entitlements.BiggerArmy=true
 while s:NextSlot() do assert(Army.Expand(s)) end
 assert(s.capacity==10 and s:Capacity()==15 and s:Snapshot(0).progression.capacityCap==15)
end)
print("Completed "..checked.." focused upgrade checks; no Studio or saved-player access.")
