-- Isolated Edit checks. Fresh environments and synthetic sessions; no Play/DataStore.
local server=game.ServerStorage.PetRoll
local shared=game.ReplicatedStorage.PetRoll.Shared
local original=getfenv()
local cache={}
local function loadModule(node)
 if cache[node] then return cache[node] end
 if node.Name=='PetView' then return {} end
 if node.Name=='WorldBuilder' then return {Palette={}} end
 local fn,err=loadstring(node.Source,node:GetFullName());assert(fn,err)
 setfenv(fn,setmetatable({script=node,require=loadModule},{__index=original}))
 local value=fn();cache[node]=value;return value
end
local Session=loadModule(server.PlayerSession)
local Roll=loadModule(server.RollService)
local Station=loadModule(server.RollStation)
local Config=loadModule(shared.Config)
local function fresh()
 local s=Session.new(987,'Eight podium check',1);s.loaded=true;return s
end
local results={}
local function check(name,fn)
 local ok,err=pcall(fn);table.insert(results,{name=name,passed=ok,error=if ok then nil else tostring(err)})
end
check('Eight uniquely ordered authored Plot1 anchors; other plots preserve physical counts',function()
 local home=workspace.MyChickenArmyMap['03_HomePlots']
 local anchors=Station.DisplayAnchors(home.Plot1);assert(#anchors==8)
 for index,a in anchors do assert(a.Parent.Name==(if index==1 then 'DisplayPodium' else 'DisplayPodium'..index)) end
 for i=2,6 do assert(#Station.DisplayAnchors(home['Plot'..i])==1) end
end)
check('Fresh profiles start at one; legacy missing field remains six; seven/eight roundtrip; nine rejects',function()
 assert(Config.RollSlotsUnlocked==8)
 local s=fresh();assert(s.rollSlotsUnlocked==1)
 local data=s:ToData();data.rollSlotsUnlocked=nil
 local restored=fresh();assert(restored:LoadData(data));assert(restored.rollSlotsUnlocked==6)
 for _,count in {6,7,8} do
  s.rollSlotsUnlocked=count;assert(restored:LoadData(s:ToData()));assert(restored.rollSlotsUnlocked==count)
 end
 data=s:ToData();data.rollSlotsUnlocked=9
 assert(not restored:LoadData(data));assert(restored.rollSlotsUnlocked==8)
end)
check('Roll creates eight distinct offers; eighth can be bought exactly once',function()
 local s=fresh();s.rollSlotsUnlocked=8;s.rollSlotCount=8
 local rolls=Roll.new();assert(rolls:Roll(s,100));assert(#s.offers==8)
 local ids={};for i,o in s.offers do assert(o.slot==i and not ids[o.id]);ids[o.id]=true end
 local offer=s.offers[8];s.coins=offer.price
 assert(not rolls:Buy(s,offer.id,100))
 assert(rolls:Buy(s,offer.id,200));assert(s.coins==0 and s.offers[8]==nil)
 assert(not rolls:Buy(s,offer.id,200))
end)
check('Runtime display cap controls rolls without deleting stored eight-slot ownership',function()
 for _,physical in {1,3,6,8} do
  local s=fresh();s.rollSlotsUnlocked=8;s.rollSlotCount=physical
  assert(Roll.new():Roll(s,100));assert(#s.offers==physical and s.rollSlotsUnlocked==8)
 end
 local s=fresh();s.rollSlotCount=99;assert(Roll.new():Roll(s,100));assert(#s.offers==8)
end)
return results
