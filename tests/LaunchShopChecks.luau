--!strict
-- Launch shop checks (docs/team/launch/02_LEAD.md §6, plan P0.4/P0.5) for the
-- passes and cash packs the owner wants to put on sale. Isolated sessions, a
-- fake data service and fake Players; no Marketplace, prompt or DataStore.
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Offline=require(Server.OfflineCash)
local Products=require(Server.ProductService)
local ShopCatalog=require(Shared.ShopCatalog)
local Currency=require(Shared.CurrencyLimits)
local Rules=require(Shared.Rules)
local Config=require(Shared.Config)
local Checks={}

local function near(a,b,why)
 assert(math.abs(a-b)<1e-6,(why or "Values differ")..": "..tostring(a).." ~= "..tostring(b))
end

local function flock(userId)
 local s=Session.new(userId,"Shopper",1);s.loaded=true
 s.tutorial.guideCompleted=true;s.tutorial.bought=true
 return s
end

-- A fake DataService boundary: one saved receipt per purchase id.
local function productFixture()
 local saved={}
 local data={}
 function data:CanPurchase() return true end
 function data:IsPurchaseSaved(session,purchaseId) return session.purchaseReceipts[purchaseId]~=nil end
 function data:CommitPurchase(session,purchaseId,productId,grant)
  local ok=grant()
  if ok then session.purchaseReceipts[purchaseId]=productId;saved[purchaseId]=true end
  return ok==true
 end
 local players={}
 function players:GetPlayerByUserId(userId) return {UserId=userId,Parent=game} end
 local marketplace={}
 return data,players,marketplace
end

function Checks.Run()
 local results={}
 local function test(name,fn)
  local ok,why=pcall(fn)
  table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
  print((if ok then "PASS " else "FAIL ")..name..(if ok then "" else " :: "..tostring(why)))
 end

 test("2x Cash doubles egg deposits, battle and territory cash only",function()
  local s=flock(-971);s.coins=0
  s.entitlements.DoubleCash=true
  assert(s:Credit(100,"eggs")==200,"eggs")
  assert(s:Credit(100,"battle")==200,"battle")
  assert(s:Credit(100,"territory")==200,"territory")
  assert(s:Credit(100,"sale")==100,"chicken sale was doubled")
  assert(s:Credit(100,"daily")==100,"daily reward was doubled")
  assert(s:Credit(100,"operation")==100,"operation reward was doubled again")
  -- The displayed income follows the same rule.
  local plain=flock(-972)
  near(s:DisplayedPetIncome("Knight",1,3),2*plain:DisplayedPetIncome("Knight",1,3),"Displayed income")
 end)

 test("A cash pack grants its exact coins once per receipt and respects the cap",function()
  local data,players,marketplace=productFixture()
  local s=flock(97301);s.coins=0;s.entitlements.DoubleCash=true -- receipts need a positive PlayerId
  local sessions={[s.userId]=s}
  local service=Products.new(data,sessions,{players=players,marketplace=marketplace,wait=function() end})
  local key=ShopCatalog.ProductOrder[1]
  local pack
  for _,k in ShopCatalog.ProductOrder do
   local p=ShopCatalog.Products[k]
   if p.coins and not p.crates then pack=p;key=k;break end
  end
  assert(pack,"No cash pack in ShopCatalog")
  local granted=Enum.ProductPurchaseDecision.PurchaseGranted
  local receipt={PlayerId=s.userId,ProductId=pack.productId,PurchaseId="lead-receipt-1",CurrencyType=Enum.CurrencyType.Robux,CurrencySpent=49}
  assert(service:ProcessReceipt(receipt)==granted,"First receipt not granted")
  assert(s.coins==pack.coins,"Pack paid "..s.coins.." for "..key.." (2x Cash must not apply)")
  assert(service:ProcessReceipt(receipt)==granted,"Replay not acknowledged")
  assert(s.coins==pack.coins,"Replayed receipt paid twice")
  -- Near the cap: the receipt stays pending (retried later), nothing is lost or overpaid.
  s.coins=Currency.MaxCoins-1
  local second={PlayerId=s.userId,ProductId=pack.productId,PurchaseId="lead-receipt-2"}
  assert(service:ProcessReceipt(second)==Enum.ProductPurchaseDecision.NotProcessedYet,"Over-cap receipt was granted")
  assert(s.coins==Currency.MaxCoins-1,"Over-cap receipt changed coins")
  -- Every listed cash pack is a positive whole amount below the cap.
  for _,k in ShopCatalog.ProductOrder do
   local p=ShopCatalog.Products[k]
   if p.coins and not p.crates then assert(p.coins%1==0 and p.coins>0 and p.coins<Currency.MaxCoins,k) end
  end
  service:Destroy()
 end)

 test("2x Egg Spawn doubles production and the offline rate",function()
  local s=flock(-974);local plain=flock(-975)
  s.entitlements.DoubleEggSpawn=true
  near(s:EggProductionMultiplier(),2*plain:EggProductionMultiplier(),"Production")
  near(Offline.Rate(s),2*Offline.Rate(plain),"Offline rate")
  near(s:PetEggRate("Duck",1,1),2*plain:PetEggRate("Duck",1,1),"Eggs per second")
 end)

 test("Bigger Army adds its bonus and Select Best and saved lineups respect it",function()
  -- October 20: Army Size comes from the Upgrades tree; its top tier plus both +1 Army Slot
  -- Gem Upgrades (S7b) is MaxSlots, and both survive a save.
  local s=flock(-976);s.upgradeTree.ArmySize=#require(Shared.UpgradeCatalog).Families.ArmySize.tiers
  s.gemUpgrades.ArmySlot=2;s:RefreshEffects()
  for i=1,Config.MaxSlots+ShopCatalog.ArmyBonus+3 do s:AddPet("Knight",1) end
  s.plotSizeLevel=#require(Shared.UpgradeCatalog).PlotPrices
  assert(s:Capacity()==Config.MaxSlots,"Without the pass")
  s.entitlements.BiggerArmy=true
  assert(s:Capacity()==Config.MaxSlots+ShopCatalog.ArmyBonus,"Capacity "..s:Capacity())
  local ok,message=Army.SelectBest(s);assert(ok,message)
  s:RefreshArmy()
  assert(#s:BestPetIds()==s:Capacity(),"Select Best chose "..#s:BestPetIds())
  local lineup=s:Lineup();assert(#lineup==s:Capacity(),"Lineup "..#lineup)
  -- A manual selection saves up to the bonus capacity and reloads intact.
  s.armySelection=table.clone(s:BestPetIds())
  local data=s:ToData();assert(#data.armySelection==s:Capacity())
  local loaded=Session.new(-976,"Shopper",1);assert(loaded:LoadData(data))
  loaded.entitlements.BiggerArmy=true
  assert(#loaded:BestPetIds()==loaded:Capacity(),"Reloaded selection lost the bonus")
  -- Losing the pass trims the active army back without deleting chickens.
  loaded.entitlements.BiggerArmy=false
  assert(#loaded:BestPetIds()==Config.MaxSlots and loaded:Count()==s:Count())
 end)

 test("2x Luck doubles disclosed odds only for unrestricted accounts",function()
  local s=flock(-977);s.luck=3
  s.entitlements.DoubleLuck=true
  s.paidRandomAllowed=true
  assert(s:PaidLuckMultiplier()==2)
  local shown=s:Snapshot(0).odds
  local expected=Rules.Odds(s.luck,s.recruitTier,2,s.researchEffects.rollingLuck)
  for species,chance in expected do near(shown[species] or 0,chance,"Odds for "..species) end
  local base=Rules.Odds(s.luck,s.recruitTier,1,s.researchEffects.rollingLuck)
  local differs=false
  for species,chance in expected do if math.abs(chance-(base[species] or 0))>1e-9 then differs=true end end
  assert(differs,"2x Luck did not change the odds")
  -- Restricted (or unknown) policy: no paid multiplier; the disclosed fixed schedule applies.
  s.paidRandomAllowed=false;s.paidRandomRestricted=true
  assert(s:PaidLuckMultiplier()==1)
  local restricted=s:Snapshot(0).odds
  for species,chance in base do near(restricted[species] or 0,chance,"Restricted odds for "..species) end
  local guarantee=s:LuckGuarantee()
  assert(guarantee.interval>0 and #guarantee.sequence>0)
  s.paidRandomAllowed=nil;s.paidRandomRestricted=nil
  assert(s:PaidLuckMultiplier()==1,"Unknown policy got paid luck")
 end)

 local failed=0
 for _,r in results do if not r.passed then failed+=1 end end
 print(("LaunchShopChecks: %d passed, %d failed"):format(#results-failed,failed))
 return results
end
return Checks
