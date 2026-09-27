-- Artificial upper-bound world, disposable Studio profile only.
local g=assert(_G.EconomyTestServer)
local player=game.Players:GetPlayers()[1];local s=g.sessions[player.UserId]
assert(s.saveStatus=='studio-session')
local Session=require(game.ServerStorage.PetRoll.PlayerSession)
local Catalog=require(game.ReplicatedStorage.PetRoll.Shared.PetCatalog)
local Shop=require(game.ReplicatedStorage.PetRoll.Shared.ShopCatalog)
assert(g.debug:Run(player,s,'FreshEconomy','AllPasses',os.clock()))
local function fill(session)
 session.pets={};session.slots={};session.armySelection=nil
 session.promotion=4;session.capacity=10;session.plotSizeLevel=4
 session.incomeLevel=4;session.eggSpeedLevel=4;session.luck=4;session.rollSlotsUnlocked=6
 session.loaded=true;session.saveStatus='studio-session'
 for _,key in Shop.Order do session.entitlements[key]=true end
 for i=1,60 do
  local pet=session:AddPet(Catalog.Order[(i-1)%#Catalog.Order+1],1);pet.level=10
 end
 session:RefreshArmy();g.world:UpdateSession(session)
end
fill(s)
player.Character:PivotTo(g.world:SpawnFrame(s.plotIndex))
player:SetAttribute('EconomyTestDestination',nil)
_G.EconomyStressAddPlots=function()
 for index=2,6 do
  local id=-8600-index
  assert(not g.sessions[id])
  local bot=Session.new(id,'Stress plot '..index,index)
  g.sessions[id]=bot;fill(bot)
 end
end
_G.EconomyStressSample=function()
 local rows={}
 for _,session in g.sessions do
  local snap=g.eggs:Snapshot(session,os.clock())
  local count=0;for _,d in snap.drops do count+=d.stack end
  table.insert(rows,{plot=session.plotIndex,count=session:Count(),drops=#snap.drops,
   groundEggs=count,ready=snap.processor.readyCash,bag=snap.carriedValue,rate=session:Snapshot(os.clock()).income})
 end
 table.sort(rows,function(a,b)return a.plot<b.plot end)
 return {plots=rows,instances=#workspace:GetDescendants(),memoryMb=game:GetService('Stats'):GetTotalMemoryUsageMb()}
end
return _G.EconomyStressSample()
