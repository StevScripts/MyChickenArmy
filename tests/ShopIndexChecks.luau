-- Isolated checks: fake Marketplace, fake Players, unsaved PlayerSession objects.
-- No prompts, Roblox purchases, profiles, real characters or world writes.
-- Root runner in Studio Server/Edit:
-- require(game.ServerStorage.PetRollTests.ShopIndexChecks).Run()
local Server = game.ServerStorage.PetRoll
local Shared = game.ReplicatedStorage.PetRoll.Shared
local Session = require(Server.PlayerSession)
local Army = require(Server.ArmyService)
local Commerce = require(Server.CommerceService)
local Battles = require(Server.BattleService)
local Eggs = require(Server.EggService)
local ShopCatalog = require(Shared.ShopCatalog)
local Config = require(Shared.Config)
local CombatRewards = require(Shared.CombatRewards)
local King = require(Server.KingEncounter)
local Checks = {}

local function setup(configured)
	local fixture = {now=0, calls=0, answers={}, callbacks={}, scheduled={}}
	local signal = {}
	function signal:Connect(callback)
		local link = {connected=true, callback=callback}
		function link:Disconnect() self.connected=false end
		table.insert(fixture.callbacks, link)
		return link
	end
	local marketplace = {PromptGamePassPurchaseFinished=signal}
	function marketplace:UserOwnsGamePassAsync(userId, passId)
		assert(userId==1001, "Fixture queried an unexpected user")
		fixture.calls+=1
		if fixture.check then return fixture.check(passId) end
		local answer=fixture.answers[passId]
		if answer=="fail" then error("Simulated Marketplace outage") end
		return answer==true
	end
	function fixture:Fire(passId, claimedPurchase)
		for _, link in self.callbacks do if link.connected then link.callback(self.player,passId,claimedPurchase) end end
	end
	function fixture:Advance(seconds)
		self.now+=seconds
		local pending=self.scheduled;self.scheduled={}
		for _, item in pending do
			if item.at<=self.now then item.fn() else table.insert(self.scheduled,item) end
		end
	end
	local catalog={Order=ShopCatalog.Order,Definitions={}}
	for index,key in ShopCatalog.Order do
		catalog.Definitions[key]=table.clone(ShopCatalog.Definitions[key])
		catalog.Definitions[key].passId=if configured then 100+index else 0
	end
	local player={UserId=1001,Parent={},attributes={}}
	function player:SetAttribute(name,value) self.attributes[name]=value end
	fixture.player=player
	local session=Session.new(1001,"Shop Fixture",1)
	session.loaded=true
	local commerce=Commerce.new({marketplace=marketplace,catalog=catalog,
		clock=function() return fixture.now end,
		delay=function(seconds,fn) table.insert(fixture.scheduled,{at=fixture.now+seconds,fn=fn}) end})
	return commerce,player,session,fixture
end

local function reward(service,attacker,defender,kills,incomeSite)
	local battle={attacker=attacker,defender=defender,kills=kills,coinDrops={},incomeSite=incomeSite}
	function battle:DrainKills() local result=self.kills;self.kills={};return result end
	service:RewardKills(battle,0)
	return battle
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,detail=pcall(fn)
		table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
	end
	test("Legacy saves seed owned discoveries without changing balances or save revision",function()
		local original=Session.new(1001,"Legacy",1)
		original:AddPet("Viking",1)
		local data=original:ToData();data.discovered=nil
		local restored=Session.new(1002,"Restored",2)
		assert(restored:LoadData(data))
		assert(restored.discovered.Duck and restored.discovered.Mallard and restored.discovered.Viking)
		assert(not restored.discovered.StormDuck and restored:Count()==original:Count())
		assert(restored.coins==data.coins and restored:ToData().dataRevision==data.dataRevision)
		return "Owned roster preserved; no invented historical discoveries"
	end)
	test("Buying discovers; unbought offers do not; selling and merging retain discovery",function()
		local session=Session.new(1001,"Collector",1)
		session.offer={species="StormDuck"}
		assert(not session:Snapshot(0).discovered.StormDuck)
		local sailor=session:AddPet("Sailor",1)
		local dragon=session:AddPet("Dragon",1)
		local other=session:AddPet("Dragon",1)
		session:AddPet("Dragon",1);session:RefreshArmy()
		assert(Army.Sell(session,{sailor.id},true))
		assert(Army.Merge(session,dragon.id,other.id,1))
		assert(session.discovered.Sailor and session.discovered.Dragon)
		local restored=Session.new(1002,"Restored",2)
		assert(restored:LoadData(session:ToData()))
		assert(restored.discovered.Sailor and restored.discovered.Dragon)
		local snapshot=restored:Snapshot(0);snapshot.discovered.Sailor=nil
		assert(restored.discovered.Sailor,"Snapshot exposed mutable discovery state")
		return "Discovery survives reserve sale, merge and save round trip"
	end)
	test("Invalid discovery fields cannot partially replace a loaded session",function()
		local session=Session.new(1001,"Validation",1)
		local data=session:ToData();data.coins=123;data.discovered={Robot=true}
		local coins,pets=session.coins,session.pets
		assert(not session:LoadData(data))
		assert(session.coins==coins and session.pets==pets and session.discovered.Duck)
		return "Art-only/unknown IDs rejected before committing any profile values"
	end)
	test("Unconfigured passes fail closed and never call Marketplace",function()
		local commerce,player,session,fixture=setup(false)
		assert(commerce:Load(player,session))
		fixture:Fire(0,true);fixture:Fire(101,true);fixture:Advance(20)
		assert(fixture.calls==0)
		local snapshot=commerce:Snapshot(session)
		assert(snapshot.ready)
		for _,key in ShopCatalog.Order do assert(snapshot.owned[key]==false and session.entitlements[key]==false) end
		assert(player.attributes.PetRollCommanderBanner==false)
		commerce:Destroy()
		return "All ID-zero benefits inactive, including claimed purchase events"
	end)
	test("Server verification grants permanent-pass benefits without saving ownership",function()
		local commerce,player,session,fixture=setup(true)
		fixture.answers[101],fixture.answers[102],fixture.answers[103]=true,true,true
		assert(commerce:Load(player,session))
		assert(fixture.calls==3 and player.attributes.PetRollCommanderBanner==true)
		assert(session.entitlements.EggMagnet and session.entitlements.DoubleBounty)
		local payload=session:ToData();assert(payload.entitlements==nil and payload.shop==nil)
		local owned=commerce:Snapshot(session).owned;owned.EggMagnet=false
		assert(session.entitlements.EggMagnet)
		session:Reset();assert(session.entitlements.EggMagnet,"Gameplay reset erased a verified Roblox pass")
		commerce:Destroy();assert(player.attributes.PetRollCommanderBanner==false)
		return "Session-only entitlement table, copied snapshot and replicated cosmetic attribute"
	end)
	test("Refresh is throttled and transient failures preserve only previously verified benefits",function()
		local commerce,player,session,fixture=setup(true)
		fixture.answers[101]=true;fixture.answers[102]="fail"
		assert(not commerce:Load(player,session))
		assert(session.entitlements.EggMagnet and not session.entitlements.CommanderBanner)
		for _=1,20 do commerce:Refresh(player,session) end
		assert(fixture.calls==3)
		fixture.answers[101]="fail";fixture:Advance(8)
		assert(not commerce:Refresh(player,session))
		assert(fixture.calls==6 and session.entitlements.EggMagnet and not session.entitlements.CommanderBanner)
		fixture.answers[101],fixture.answers[102]=false,true;fixture:Advance(8)
		assert(commerce:Refresh(player,session))
		assert(not session.entitlements.EggMagnet and session.entitlements.CommanderBanner)
		commerce:Destroy()
		return "Requests cannot bypass the eight-second check window; verified false can revoke"
	end)
	test("Purchase completion and duplicate signals schedule verification, never grants",function()
		local commerce,player,session,fixture=setup(true)
		commerce:Load(player,session)
		fixture:Fire(101,true);fixture:Fire(101,true);fixture:Fire(999,true)
		assert(not session.entitlements.EggMagnet and #fixture.scheduled==1)
		fixture:Advance(8);assert(not session.entitlements.EggMagnet and fixture.calls==6)
		fixture.answers[101]=true
		fixture:Fire(101,false) -- Claimed cancellation is ignored; actual ownership decides.
		fixture:Advance(8);assert(session.entitlements.EggMagnet and fixture.calls==9)
		fixture:Fire(101,true);commerce:Destroy();fixture:Advance(20)
		assert(fixture.calls==9 and next(session.entitlements)==nil)
		return "Coalesced refreshes, untrusted booleans ignored, delayed work canceled on destroy"
	end)
	test("A transient join ownership failure recovers automatically without client interaction",function()
		local commerce,player,session,fixture=setup(true)
		fixture.answers[101]="fail"
		assert(not commerce:Load(player,session))
		assert(fixture.calls==3 and not session.entitlements.EggMagnet)
		local state=commerce:Snapshot(session);assert(not state.ready and state.checking)
		fixture:Advance(7);assert(fixture.calls==3)
		fixture.answers[101]=true;fixture:Advance(1)
		state=commerce:Snapshot(session)
		assert(fixture.calls==6 and state.ready and not state.checking and session.entitlements.EggMagnet)
		fixture:Advance(40);assert(fixture.calls==6 and #fixture.scheduled==0)
		commerce:Destroy()
		return "One failed join check retries after eight seconds, grants verified ownership and stops"
	end)
	test("Persistent ownership failure has exactly two automatic retries; manual requests can retry again",function()
		local commerce,player,session,fixture=setup(true)
		fixture.answers[101]="fail"
		assert(not commerce:Load(player,session));assert(fixture.calls==3)
		fixture:Advance(8);assert(fixture.calls==6 and commerce:Snapshot(session).checking)
		fixture:Advance(8);assert(fixture.calls==9)
		local state=commerce:Snapshot(session);assert(not state.ready and not state.checking)
		fixture:Advance(80);assert(fixture.calls==9 and #fixture.scheduled==0)
		assert(not commerce:Refresh(player,session));assert(fixture.calls==12)
		for _=1,20 do commerce:Refresh(player,session) end
		assert(fixture.calls==12 and #fixture.scheduled==1)
		fixture:Advance(8);assert(fixture.calls==15)
		fixture:Advance(8);assert(fixture.calls==18 and not commerce:Snapshot(session).checking)
		fixture:Advance(80);assert(fixture.calls==18 and not session.entitlements.EggMagnet)
		-- A later native purchase completion gets its own bounded verification cycle.
		fixture.answers[101]=true;fixture:Fire(101,true);fixture:Advance(0)
		assert(fixture.calls==21 and session.entitlements.EggMagnet and commerce:Snapshot(session).ready)
		commerce:Destroy()
		return "Three checks per cycle, no endless polling or budget resets from throttled requests"
	end)
	test("Queued ownership retries stop when the player releases",function()
		local commerce,player,session,fixture=setup(true)
		fixture.answers[101]="fail";commerce:Load(player,session)
		assert(commerce:Snapshot(session).checking and #fixture.scheduled==1)
		commerce:Release(player);fixture:Advance(20)
		assert(fixture.calls==3 and next(session.entitlements)==nil)
		local state=commerce:Snapshot(session);assert(not state.ready and not state.checking)
		commerce:Destroy()
		return "Delayed failure retries perform no API requests or grants after player release"
	end)
	test("A purchase event during an in-flight failure is preserved by the retry queue",function()
		local commerce,player,session,fixture=setup(true)
		local first=true
		fixture.check=function(passId)
			if passId==101 and first then
				first=false;coroutine.yield("checking");error("Initial ownership check failed")
			end
			return fixture.answers[passId]==true
		end
		local thread=coroutine.create(function() return commerce:Load(player,session) end)
		local ok,why=coroutine.resume(thread);assert(ok and why=="checking")
		fixture.answers[101]=true;fixture:Fire(101,true)
		assert(not session.entitlements.EggMagnet and #fixture.scheduled==0)
		local resumed,success=coroutine.resume(thread);assert(resumed and success==false)
		assert(#fixture.scheduled==1 and commerce:Snapshot(session).checking)
		fixture:Advance(8)
		assert(fixture.calls==6 and session.entitlements.EggMagnet and commerce:Snapshot(session).ready)
		fixture:Advance(30);assert(fixture.calls==6)
		commerce:Destroy()
		return "Pending purchase verification survives the old yielded check and coalesces with its retry"
	end)
	test("An in-flight ownership check cannot apply after player release",function()
		local commerce,player,session,fixture=setup(true)
		fixture.check=function(_) coroutine.yield("checking");return true end
		local thread=coroutine.create(function() return commerce:Load(player,session) end)
		local ok,why=coroutine.resume(thread);assert(ok and why=="checking")
		local before=fixture.calls
		assert(not commerce:Refresh(player,session) and fixture.calls==before)
		commerce:Release(player)
		local resumed,success=coroutine.resume(thread)
		assert(resumed and success==false and coroutine.status(thread)=="dead")
		assert(next(session.entitlements)==nil and player.attributes.PetRollCommanderBanner==false)
		assert(not commerce:Snapshot(session).ready)
		commerce:Destroy()
		return "No stale grant or attribute update after yielding across release"
	end)
	test("Bounty doubles ordinary NPC kills and King guards, excluding boss, PvP and Supply",function()
		local commerce,player,session,fixture=setup(true)
		fixture.answers[103]=true;commerce:Load(player,session)
		local defender=Session.new(1002,"Opponent",2)
		local service=setmetatable({sessions={[session.userId]=session,[defender.userId]=defender}},Battles)
		local ordinary={side="B",species="Duck",level=1,serial=1,x=0,z=0}
		local guard={side="B",species="Sailor",level=2,serial=2,x=0,z=0}
		local boss={side="B",species="Duck",boss=true,level=2,serial=3,x=0,z=0}
		local before=session.coins
		local battle=reward(service,session.userId,nil,{ordinary,guard,boss})
		assert(session.coins-before==2*CombatRewards.ForUnit(ordinary)+2*CombatRewards.ForUnit(guard)+Config.KingKillCoins)
		local paid=session.coins;service:RewardKills(battle,1);assert(session.coins==paid)
		before=session.coins;reward(service,session.userId,defender.userId,{ordinary})
		assert(session.coins-before==CombatRewards.ForUnit(ordinary,1))
		before=session.coins;reward(service,session.userId,nil,{ordinary},true);assert(session.coins==before)
		-- The pass still must not apply when a PvP defender session has left.
		service.sessions[defender.userId]=nil;before=session.coins
		reward(service,session.userId,defender.userId,{ordinary})
		assert(session.coins-before==CombatRewards.ForUnit(ordinary))
		commerce:Destroy()
		return "Per-life drain avoids duplicates; the bounty pass never changes excluded reward paths"
	end)
	test("Advertised camp and King reward ranges match verified bounty scope",function()
		local commerce,player,session,fixture=setup(true)
		fixture.answers[103]=true;commerce:Load(player,session)
		local service=Battles.new({[session.userId]=session},{})
		local targets=service:Targets(session,0)
		local found={};for _,entry in targets do found[entry.id]=entry end
		assert(found["camp:1"].killRewardMin==200 and found["camp:1"].killRewardMax==200)
		local low,high=math.huge,0
		for _,unit in King.Definition(4).roster do
			local amount=CombatRewards.ForUnit(unit)*(if unit.boss then 1 else 2)
			low,high=math.min(low,amount),math.max(high,amount)
		end
		assert(found["king:1"].killRewardMin==low and found["king:1"].killRewardMax==high)
		assert(found["income:1"].killRewardMin==0 and found["income:1"].killRewardMax==0)
		commerce:Destroy()
		return "UI reward ranges use the same scoped bonus as real kill payouts"
	end)
	test("Egg Magnet changes radius only; batch, payout value and laying interval stay unchanged",function()
		local commerce,player,session,fixture=setup(true)
		commerce:Load(player,session)
		local eggs=Eggs.new({})
		local yard=eggs:Yard(session)
		local petId=next(session.pets)
		for index=1,6 do table.insert(yard.drops,{id=tostring(index),petId=petId,species="Duck",
			x=15,y=0,z=0,value=7,stack=1,readyAt=0,born=0}) end
		eggs:Collect(session,Vector3.new(0,0.8,0),0)
		for _,drop in yard.drops do assert(drop.claimAt==nil) end
		fixture.answers[101]=true;fixture:Advance(8);commerce:Refresh(player,session)
		eggs:Collect(session,Vector3.new(0,0.8,0),1)
		local count=0;for _,drop in yard.drops do if drop.claimAt then count+=1 end;assert(drop.value==7) end
		assert(count==Config.EggPickupBatch and Config.EggMagnetRadius==10 and Config.EggLaySeconds==3)
		local before=session.coins;eggs:Collect(session,nil,3)
		assert(session.coins-before==7*Config.EggPickupBatch)
		eggs:Destroy();commerce:Destroy()
		return "15-stud eggs collect only after verified ownership; original coin value and batch remain"
	end)
	return results
end

return Checks
