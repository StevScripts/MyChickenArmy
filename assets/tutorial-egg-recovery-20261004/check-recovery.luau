-- Pure tutorial routing regression checks; no player or place mutations.
local Guide = require(game.ReplicatedStorage.PetRoll.Shared.TutorialGuide)
local passed = {}
local function check(name, condition)
	assert(condition, name)
	table.insert(passed, name)
end
local function state(pets)
	local flock = {}
	for _ = 1, pets or 1 do table.insert(flock, {}) end
	return {
		saveStatus="studio-session", armyState="Home", coins=100, capacity=3,
		tutorial={emptyStart=true, bought=true, collectedEggs=true, soldEggs=true},
		pets=flock, offer={price=600}, nextSlot={price=1200},
		eggs={carriedCount=0, carriedValue=0},
	}
end
local s=state()
s.eggs.carriedCount=1;s.eggs.carriedValue=4
local current=Guide.Resolve(s)
check("one egg does not send an underfunded recruit back to sell", current.id=="RecoverCollect" and current.target=="Yard")
check("copy explains the remaining shortfall", current.text=="Collect $496 more in eggs.")
for value=4,496,4 do
	s.eggs.carriedValue=value
	assert(Guide.Resolve(s).id=="RecoverCollect", "collection must remain stable below the price")
end
check("124 successive partial bags retain the collection objective", true)
s.eggs.carriedValue=500
check("exact recruit shortfall sends one trip to the pad", Guide.Resolve(s).id=="RecoverSell" and Guide.Resolve(s).target=="EggDeposit")
s.eggs.carriedValue=504
check("overshooting the shortfall still sends to sell", Guide.Resolve(s).id=="RecoverSell")
s.coins+=s.eggs.carriedValue;s.eggs.carriedValue=0;s.eggs.carriedCount=0
check("paid bag advances to buying rather than back to collection", Guide.Resolve(s).id=="Grow")
s=state(4);s.eggs.carriedValue=1099
check("army slot also waits for the whole shortfall", Guide.Resolve(s).id=="RecoverCollect")
s.eggs.carriedValue=1100
check("army slot exact shortfall sends to sell", Guide.Resolve(s).id=="RecoverSell")
s.coins+=s.eggs.carriedValue;s.eggs.carriedValue=0
check("army slot payment advances to upgrade", Guide.Resolve(s).id=="Expand")
s=state();s.tutorial.soldEggs=false;s.eggs.carriedCount=1;s.eggs.carriedValue=4
check("first sale lesson still needs only one egg", Guide.Resolve(s).id=="Sell")
s.eggs.carriedValue=0;s.eggs.carriedCount=0
check("empty first-sale bag recovers to the yard", Guide.Resolve(s).id=="RecoverCollect")
s=state();s.eggs.carriedValue=200;s.coins=600
check("other income can make the recruit affordable immediately", Guide.Resolve(s).id=="Grow")
s=state();s.eggs.carriedValue=500;s.offer.price=1000
check("changed offer recalculates the actual shortfall", Guide.Resolve(s).id=="RecoverCollect")
s.offer.price=400
check("cheaper reroll uses the new price", Guide.Resolve(s).id=="RecoverSell")
check("free reroll alternative remains in recruit help", string.find(Guide.Resolve(s).help,"FREE",1,true)~=nil)
s=state();s.eggs=nil
check("missing bag snapshot safely stays at collection", Guide.Resolve(s).id=="RecoverCollect")
s=state();s.tutorial.guideSkipped=true
check("skip still removes guidance", Guide.Resolve(s)==nil)
return {passed=#passed, checks=passed, scope="Pure in-memory snapshots; no place, player, economy, persistence or analytics mutations"}

