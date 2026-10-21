-- October 21 reference parity (P4; docs/team/REFERENCE_PARITY_20261021.md §2.4): after a
-- Rebirth the Coins read 0 and the Time Skip Coins wait as a saved claim
-- (session.timeSkipPending = {coins, rank}) until ClaimTimeSkip pays them. Isolated
-- sessions only: no DataStore, live world, Players or product prompts. Run in Studio:
-- require(game.ServerStorage.PetRollTests.TimeSkipClaimChecks).Run()
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Currency=require(Shared.CurrencyLimits)
local Session=require(Server.PlayerSession)
local Rebirth=require(Server.RebirthService)
local Checks={}

-- Isolated: no live server, so no analytics, battles, yard eggs or save requests.
local NO_SERVER: any = nil

-- A loaded session past the Commander guide (no starter reserve) at Rebirth 0, with a
-- small run to reset: a few tree tiers and two chickens laying.
local function fixture(userId)
	local session=Session.new(userId,"Time Skip fixture",1)
	session.loaded=true
	session.tutorial.bought,session.tutorial.guideCompleted=true,true
	session.upgradeTree={EggSpeed=2,EggValue=2,Flock=1}
	session:RefreshEffects()
	session:AddPet("Duck",1)
	session:AddPet("Chunky",1)
	return session
end

-- Rebirth 1 from a fresh fixture: returns the session, the quote before and the receipt.
local function firstRebirth(userId)
	local s=fixture(userId)
	s.coins=(Rebirth.Cost(1) :: number)+1234
	local quote=Rebirth.Quote(s)
	assert(quote.eligible and quote.nextRank==1,"Quote: "..tostring(quote.reason))
	assert(quote.timeSkipCoins>0 and quote.timeSkipPending==nil,"Time Skip preview "..tostring(quote.timeSkipCoins))
	local ok,message,receipt=Rebirth.Rebirth(s,0,NO_SERVER,false)
	assert(ok,message)
	return s,quote,receipt
end

local function refused(wanted,ok,message,...)
	assert(not ok,"Expected a refusal: '"..wanted.."'")
	assert(message==wanted,"Wanted '"..wanted.."', got '"..tostring(message).."'")
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,detail=pcall(fn)
		table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
	end

	test("A Rebirth leaves Coins at 0 and saves the Time Skip quote as a claim",function()
		local s,quote,receipt=firstRebirth(-9401)
		assert(s.rebirths==1 and s.coins==0,"Coins "..s.coins)
		local pending=s.timeSkipPending
		assert(pending and pending.coins==quote.timeSkipCoins and pending.rank==1,
			"Pending "..tostring(pending and pending.coins).." vs quote "..quote.timeSkipCoins)
		assert(receipt.timeSkipCoins==quote.timeSkipCoins and receipt.timeSkipPending==true and not receipt.skip,"Receipt")
		-- The screen's bar reads 0 / the next cost; the snapshot carries the claim.
		local after=Rebirth.Quote(s)
		assert(after.coins==0 and after.cost==Rebirth.Cost(2),"Bar "..tostring(after.coins).." / "..tostring(after.cost))
		local snapshot=s:Snapshot(0)
		assert(snapshot.coins==0 and snapshot.rebirth.timeSkipPending
			and snapshot.rebirth.timeSkipPending.coins==pending.coins and snapshot.rebirth.timeSkipPending.rank==1,
			"Snapshot rebirth.timeSkipPending")
		return "0 Coins, "..pending.coins.." Coins waiting"
	end)

	test("Claim pays once through Credit; a second claim is refused quietly",function()
		local s,quote=firstRebirth(-9402)
		s.loaded=false
		refused("Your flock is not ready yet.",Rebirth.ClaimTimeSkip(s,NO_SERVER))
		assert(s.timeSkipPending and s.coins==0,"A refused claim spent the reward")
		s.loaded=true
		local credited={}
		s.onTutorialIncome=function(source,amount) table.insert(credited,source..":"..amount) end
		local ok,message,receipt=Rebirth.ClaimTimeSkip(s,NO_SERVER)
		assert(ok and receipt.coins==quote.timeSkipCoins and receipt.rank==1,tostring(message))
		assert(s.coins==quote.timeSkipCoins and s.timeSkipPending==nil,"Coins "..s.coins)
		assert(#credited==1 and credited[1]=="rebirth:"..quote.timeSkipCoins,"Credit source "..table.concat(credited,", "))
		assert(Rebirth.Quote(s).timeSkipPending==nil,"The quote still shows a claim")
		refused("",Rebirth.ClaimTimeSkip(s,NO_SERVER))
		assert(s.coins==quote.timeSkipCoins and #credited==1,"The second claim paid")
		return "+"..receipt.coins.." Coins once"
	end)

	test("The claim survives ToData/LoadData; junk reads as no claim and never refuses the profile",function()
		local s=firstRebirth(-9403)
		local data=s:ToData()
		assert(data.timeSkipPending and data.timeSkipPending.coins==s.timeSkipPending.coins and data.timeSkipPending.rank==1,
			"Saved claim")
		assert(data.dataRevision==Config.DataRevision,"DataRevision changed")
		local t=Session.new(-9403,"Time Skip reload",1)
		local ok,message=t:LoadData(data)
		assert(ok,message)
		assert(t.timeSkipPending and t.timeSkipPending.coins==s.timeSkipPending.coins and t.timeSkipPending.rank==1
			and t.rebirths==1 and t.coins==0,"Loaded claim")
		t.loaded=true
		local claimed,_,receipt=Rebirth.ClaimTimeSkip(t,NO_SERVER)
		assert(claimed and t.coins==receipt.coins and receipt.coins==s.timeSkipPending.coins,"Claim after reload")
		assert(t:ToData().timeSkipPending==nil,"A claimed reward still saves")
		for _,junk in {"x",{coins=-5,rank=1},{coins=0,rank=1},{coins=0/0,rank=1},{coins=10,rank=1.5},{coins=10},{rank=2},true} do
			local copy=table.clone(data)
			copy.timeSkipPending=junk
			local u=Session.new(-9403,"Time Skip junk",1)
			local loaded,why=u:LoadData(copy)
			assert(loaded and u.timeSkipPending==nil,"Junk "..tostring(junk).." -> "..tostring(why))
		end
		local copy=table.clone(data)
		copy.timeSkipPending={coins=12.7,rank=Config.Rebirth.MaxRank+9}
		local u=Session.new(-9403,"Time Skip lenient",1)
		assert(u:LoadData(copy) and u.timeSkipPending.coins==12 and u.timeSkipPending.rank==Config.Rebirth.MaxRank,
			"Lenient read")
		copy.timeSkipPending=nil
		local v=Session.new(-9403,"Time Skip missing",1)
		assert(v:LoadData(copy) and v.timeSkipPending==nil,"Missing key")
		return "Claim reloads; junk is dropped"
	end)

	test("A second Rebirth before claiming adds to the waiting Time Skip",function()
		local s,_,first=firstRebirth(-9404)
		local waiting=s.timeSkipPending.coins
		assert(waiting==first.timeSkipCoins,"First claim")
		s.coins=Rebirth.Cost(2) :: number
		local quote=Rebirth.Quote(s)
		assert(quote.eligible and quote.timeSkipPending.coins==waiting,"Quote "..tostring(quote.reason))
		local ok,message,receipt=Rebirth.Rebirth(s,1,NO_SERVER,false)
		assert(ok and s.rebirths==2 and s.coins==0,message)
		assert(receipt.timeSkipCoins==quote.timeSkipCoins and receipt.timeSkipPending==true,"Receipt")
		assert(s.timeSkipPending.coins==waiting+quote.timeSkipCoins and s.timeSkipPending.rank==2,
			"Pending "..s.timeSkipPending.coins.." vs "..(waiting+quote.timeSkipCoins))
		local claimed,_,paid=Rebirth.ClaimTimeSkip(s,NO_SERVER)
		assert(claimed and s.coins==waiting+quote.timeSkipCoins and paid.rank==2,"Claimed "..s.coins)
		return waiting.." + "..quote.timeSkipCoins.." Coins in one claim"
	end)

	test("A Skip Rebirth pays its own Time Skip at once and leaves a waiting claim alone",function()
		local s=firstRebirth(-9405)
		local waiting=s.timeSkipPending.coins
		s.coins,s.rebirthSkips=123,1
		s.upgradeTree={EggSpeed=1}
		s:RefreshEffects()
		local ok,message,receipt=Rebirth.Rebirth(s,1,NO_SERVER,true)
		assert(ok and receipt.skip and s.rebirths==2 and s.rebirthSkips==0,message)
		assert(receipt.timeSkipPending==false and s.coins==123+receipt.timeSkipCoins,"Coins "..s.coins)
		assert(s.upgradeTree.EggSpeed==1,"The Skip reset the run")
		assert(s.timeSkipPending.coins==waiting and s.timeSkipPending.rank==1,"The waiting claim changed")
		return "Skip paid "..receipt.timeSkipCoins.." Coins; "..waiting.." still waiting"
	end)

	test("Auto Rebirth also leaves Coins at 0 and adds to the claim",function()
		local s=fixture(-9406)
		s.rebirths,s.autoRebirth=1,true
		s.gemUpgrades={AutoRebirth=1}
		s:RefreshEffects()
		s.timeSkipPending={coins=500,rank=1}
		s.coins=Rebirth.Cost(2) :: number
		local quote=Rebirth.Quote(s)
		local ok,message,receipt=Rebirth.Step(s,NO_SERVER)
		assert(ok and receipt.automatic and s.rebirths==2 and s.coins==0,tostring(message))
		assert(s.timeSkipPending.coins==500+quote.timeSkipCoins and s.timeSkipPending.rank==2,"Pending "..s.timeSkipPending.coins)
		return "Auto Rebirth: 0 Coins, "..s.timeSkipPending.coins.." waiting"
	end)

	test("A claim stops at the Coins cap and is used up; a debug reset clears it",function()
		local s=fixture(-9407)
		s.coins=Currency.MaxCoins-10
		s.timeSkipPending={coins=100,rank=3}
		local ok,_,receipt=Rebirth.ClaimTimeSkip(s,NO_SERVER)
		assert(ok and receipt.coins==10 and s.coins==Currency.MaxCoins and s.timeSkipPending==nil,"Cap "..tostring(receipt and receipt.coins))
		local t=fixture(-9408)
		t.timeSkipPending={coins=100,rank=3}
		t:Reset()
		assert(t.timeSkipPending==nil,"Reset kept the claim")
		return "Paid 10 of 100 at the cap"
	end)

	local passed=0
	for _,result in results do if result.passed then passed+=1 end end
	print(("[TimeSkipClaimChecks] %d/%d passed"):format(passed,#results))
	for _,result in results do
		print((if result.passed then "  PASS " else "  FAIL ")..result.name.." — "..result.detail)
	end
	return results
end

return Checks
