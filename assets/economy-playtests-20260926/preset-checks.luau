-- Isolated actual-module checks, fake marketplace/policy/player boundaries.
local Session=require(game.ServerStorage.PetRoll.PlayerSession)
local Debug=require(game.ServerStorage.PetRoll.DebugService)
local module=game.ServerStorage.PetRoll.CommerceService
local nativeGame=game
local studio=true
local fn=assert(loadstring(module.Source,module:GetFullName()..':isolated'))
setfenv(fn,setmetatable({game={GetService=function(_,name)
 if name=='RunService' then return {IsStudio=function() return studio end} end
 return nativeGame:GetService(name)
end}},{__index=getfenv()}))
local Commerce=fn()
local p={UserId=-431,Parent={},attributes={},SetAttribute=function(self,k,v) self.attributes[k]=v end}
local s=Session.new(p.UserId,'Fake purchase tester',1)
s.loaded=true;s.saveStatus='studio-session'
local race
local market={PromptGamePassPurchaseFinished={Connect=function()return {Disconnect=function()end}end},
 UserOwnsGamePassAsync=function() if race then local callback=race;race=nil;callback() end return true end}
local commerce=Commerce.new({marketplace=market,policy={GetPolicyInfoForPlayerAsync=function()
 return {ArePaidRandomItemsRestricted=false} end},delay=function()end})
local debug=Debug.new({[p.UserId]=s},{CancelPlayer=function()end},commerce)
local results={}
local function check(name,callback)
 local ok,err=pcall(callback)
 table.insert(results,{name=name,passed=ok,error=not ok and tostring(err) or nil})
end
assert(commerce:Load(p,s))
check('Free preset suppresses an account owning every pass',function()
 assert(debug:Run(p,s,'FreshEconomy','Free',0))
 for _,owned in s.entitlements do assert(not owned) end
 assert(s.coins==2400 and s:Count()==3 and s:Capacity()==3)
 assert(s.commerceTestPreset=='NoPasses')
end)
check('An in-flight marketplace refresh cannot restore suppressed benefits',function()
 commerce.records[p.UserId].nextAt=0
 race=function() assert(commerce:SetTestPreset(p,s,'NoPasses')) end
 assert(commerce:Refresh(p,s))
 for _,owned in s.entitlements do assert(not owned) end
 assert(not commerce:Snapshot(s).owned.DoubleCash)
end)
check('Low spend enables only Double Egg Spawn',function()
 assert(debug:Run(p,s,'FreshEconomy','LowRobux',0))
 for key,owned in s.entitlements do assert(owned==(key=='DoubleEggSpawn')) end
 assert(s:EggProductionMultiplier()==2 and s:EarnedAmount(10,'eggs')==10)
end)
check('All enabled passes stack once and leave disabled Auto Merge off',function()
 assert(debug:Run(p,s,'FreshEconomy','AllPasses',0))
 assert(s:EggProductionMultiplier()==2 and s:EarnedAmount(10,'eggs')==20)
 assert(s:Capacity()==8 and not s.entitlements.AutoMerge and s.coins==2400)
end)
check('Fresh reset removes consumables while preserving receipt acknowledgements',function()
 s.purchaseReceipts.oldReceipt=123;s.crateCredits=5;s.eggProcessor.finishCredits=4
 s.eggCarry={count=10,value=40};s.eggProcessor.readyValue=100
 assert(debug:Run(p,s,'FreshEconomy','Free',0))
 assert(s.purchaseReceipts.oldReceipt==123 and s.crateCredits==0 and s.eggProcessor.finishCredits==0)
 assert(s.eggCarry.count==0 and s.eggProcessor.readyValue==0)
end)
check('Cash presets reset instead of accumulating repeat grants',function()
 for _=1,2 do assert(debug:Run(p,s,'FreshEconomy','CashPack',0));assert(s.coins==12400) end
 for _=1,2 do assert(debug:Run(p,s,'FreshEconomy','AllItems',0));assert(s.coins==11112400) end
 assert(s.crateCredits==0)
end)
check('Account mode restores verified passes and no override enters saved data',function()
 assert(commerce:SetTestPreset(p,s,'Account'))
 assert(s.entitlements.DoubleCash and s.commerceTestPreset==nil)
 assert(commerce:SetTestPreset(p,s,'NoPasses'))
 local data=s:ToData();assert(data.entitlements==nil and data.commerceTestPreset==nil and data.testPreset==nil)
end)
check('Native checkout blocked for both passes and products in disposable tests',function()
 assert(not commerce:PreparePurchase(p,s,'DoubleCash',true))
 assert(not commerce:PreparePurchase(p,s,'PocketCoins',true))
end)
check('Non-Studio and persistent profiles cannot activate presets',function()
 studio=false;assert(not commerce:SetTestPreset(p,s,'AllPasses'));studio=true
 s.saveStatus='saved';assert(not commerce:SetTestPreset(p,s,'AllPasses'));s.saveStatus='studio-session'
 assert(not commerce:SetTestPreset(p,s,'bogus'))
end)
check('Release removes the override and benefits',function()
 commerce:Release(p);assert(next(s.entitlements)==nil and s.commerceTestPreset==nil)
end)
commerce:Destroy()
return results
