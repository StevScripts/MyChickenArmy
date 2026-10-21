-- October 20 Playtime Rewards and the boosts readout (S16; docs/team/PLAYTIME_REWARDS.md).
-- Isolated sessions only: no DataStore, live world, Players or analytics. Time is
-- moved by rewinding the visit's start, so it runs the same in Studio and headless.
-- Run in Studio: require(game.ServerStorage.PetRollTests.PlaytimeChecks).Run()
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Rewards=require(Shared.PlaytimeRewards)
local Rules=require(Shared.Rules)
local Tree=require(Shared.UpgradeCatalog)
local Currency=require(Shared.CurrencyLimits)
local Session=require(Server.PlayerSession)
local Playtime=require(Server.PlaytimeService)
local DailyService=require(Server.DailyService)
local Checks={}

local function near(a,b,why)
	assert(math.abs(a-b)<1e-6*math.max(1,math.abs(b)),(why or "Values differ")..": "..tostring(a).." ~= "..tostring(b))
end

-- A loaded session past the Commander guide (no starter reserve).
local function fixture(userId)
	local session=Session.new(userId,"Playtime fixture",1)
	session.loaded=true
	session.tutorial.bought,session.tutorial.guideCompleted=true,true
	return session
end

-- `minutes` into the visit: the clock starts, then its start moves back.
local function played(session,minutes)
	local visit=Playtime.Begin(session)
	visit.startedAt-=minutes*60
	return visit
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,detail=pcall(fn)
		table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
	end

	test("Twelve tiles copy the reference's unlock times and Coins ratios",function()
		local tiles=Rewards.Tiles
		assert(#tiles==12,"Tiles "..#tiles)
		local at={}
		for index,tile in tiles do at[index]=tile.at end
		assert(table.concat(at,",")=="1,3,5,8,12,15,20,25,30,40,50,60",table.concat(at,","))
		local coins={}
		for _,tile in tiles do if tile.kind=="Coins" then table.insert(coins,tile.coinMinutes) end end
		assert(table.concat(coins,",")=="0.4,0.6,1,2,2.4,3,5,7",table.concat(coins,","))
		assert(tiles[4].boost=="Luck" and tiles[4].bonus==1 and tiles[4].minutes==5,"Tile 4")
		assert(tiles[8].boost=="Coins" and tiles[8].bonus==0.5 and tiles[8].minutes==10,"Tile 8")
		assert(tiles[10].boost=="Luck" and tiles[10].minutes==10,"Tile 10")
		assert(tiles[12].kind=="Rolls" and tiles[12].rolls==3,"Tile 12")
		return "1-60 min; 8 Coins, 3 boosts, 3 Free Rolls"
	end)

	test("Readout and timer text match the reference",function()
		assert(Rewards.Times(9.2)=="x9.2" and Rewards.Times(4.5)=="x4.5" and Rewards.Times(1)=="x1","Small")
		assert(Rewards.Times(12.34)=="x12.3" and Rewards.Times(250)=="x250","Middle "..Rewards.Times(12.34))
		assert(Rewards.Times(1860)=="x1.86K" and Rewards.Times(2.5e6)=="x2.5M","Large "..Rewards.Times(1860))
		assert(Rewards.Times(0/0)=="x1" and Rewards.Times(-3)=="x1","Bad input")
		assert(Rewards.Clock(4)=="00:04" and Rewards.Clock(3424)=="57:04" and Rewards.Clock(3724)=="1:02:04","Clock")
		assert(Rewards.BoostText(Rewards.Tiles[4])=="+100% 5m" and Rewards.BoostText(Rewards.Tiles[8])=="+50% 10m","Tile text")
		return "x9.2 / 00:04 / +100% 5m"
	end)

	test("Nothing counts until the save is ready, and nothing is saved",function()
		local s=Session.new(-9601,"Loading",1)
		assert(Playtime.Begin(s).startedAt==nil and Playtime.Played(s)==0,"Clock started while loading")
		local snapshot=Playtime.Snapshot(s)
		assert(#snapshot.tiles==12 and snapshot.tiles[1].unlockAt==nil,"Unlock before load")
		s.loaded=true
		assert(type(Playtime.Begin(s).startedAt)=="number","Clock did not start")
		local data=s:ToData()
		assert(data.playtime==nil and data.playtimeBoosts==nil,"Playtime was saved")
		return "Live only"
	end)

	test("A locked tile waits; a ready Coins tile pays minutes of steady income once",function()
		local s=fixture(-9602)
		Playtime.Begin(s)
		local ok,message=Playtime.Claim(s,1)
		assert(not ok and string.find(message,"^Keep playing!")~=nil,"Locked: "..tostring(message))
		played(s,1.02)
		local before=s.coins
		local expected=math.floor(math.min(math.floor(DailyService.Income(s)*Rewards.Tiles[1].coinMinutes*60),Currency.MaxCoins-s.coins))
		local receipt
		ok,message,receipt=Playtime.Claim(s,1)
		assert(ok,message)
		assert(receipt.kind=="Coins" and receipt.coins==expected and s.coins==before+expected,
			"Paid "..tostring(receipt.coins).." of "..expected)
		ok,message=Playtime.Claim(s,1)
		assert(not ok and message=="You already claimed this reward.",tostring(message))
		assert(Playtime.Snapshot(s).tiles[1].claimed==true,"Snapshot claimed")
		return "Paid "..expected.." Coins"
	end)

	test("Bad tile numbers are refused",function()
		local s=fixture(-9603)
		played(s,90)
		for _,index in {0,13,1.5,"1",0/0,-1} do
			local ok,message=Playtime.Claim(s,index)
			assert(not ok and message=="Choose a Playtime reward.",tostring(index)..": "..tostring(message))
		end
		local ok,message=Playtime.Claim(s,nil)
		assert(not ok and message=="Choose a Playtime reward.","nil: "..tostring(message))
		return "Refused"
	end)

	test("A Luck boost doubles roll Luck and the clover, then ends; another adds its time",function()
		local s=fixture(-9604)
		s.gemUpgrades={ExtraLuck=2}
		s.upgradeTree={Luck=1}
		s:RefreshEffects()
		local research=s.researchEffects.rollingLuck
		local base=Rules.LuckWindow(s.luck,s:PaidLuckMultiplier(),research).multiplier
		played(s,41)
		local ok,message=Playtime.Claim(s,4)
		assert(ok and message=="+100% Luck for 5 minutes!",tostring(message))
		near(s:RollLuckBonus(),(1+research)*2-1,"Roll Luck bonus")
		near(Playtime.Boosts(s).luck,base*2,"Clover")
		local first=s.playtimeBoosts.Luck.endsAt
		ok=Playtime.Claim(s,10)
		assert(ok,"Second boost")
		near(s.playtimeBoosts.Luck.endsAt,first+600,"Second boost did not add its 10 minutes")
		assert(Playtime.Boost(s,"Luck",first+601)==0,"Boost outlived its time")
		assert(Playtime.Boosts(s).running.Luck~=nil,"Readout lost the running boost")
		return ("Clover x%.2f -> x%.2f"):format(base,base*2)
	end)

	test("The Coins boost multiplies earned Coins live, never steady, daily or playtime Coins",function()
		local s=fixture(-9605)
		played(s,26)
		local live,steady=s:EarnedAmount(100,"eggs"),s:EarnedAmount(100,"eggs",true)
		local ok,message=Playtime.Claim(s,8)
		assert(ok and message=="+50% Coins for 10 minutes!",tostring(message))
		near(s:EarnedAmount(100,"eggs"),live*1.5,"Live eggs")
		near(s:EarnedAmount(100,"battle"),s:EarnedAmount(100,"battle",true)*1.5,"Battle")
		near(s:EarnedAmount(100,"eggs",true),steady,"Steady (offline)")
		near(s:EarnedAmount(100,"daily"),100,"Daily")
		near(s:EarnedAmount(100,"playtime"),100,"Playtime Coins")
		return "x1.5 live only"
	end)

	test("The Coins readout counts Egg Value, 2x Coins, Rebirth and live boosts",function()
		local s=fixture(-9606)
		s.upgradeTree={EggValue=2}
		s:RefreshEffects()
		s.rebirths=2
		s.entitlements.DoubleCash=true
		local expected=Tree.EggValueMultiplier(2)*s:EarnedAmount(1,"eggs")
		near(Playtime.Boosts(s).coins,expected,"Coins readout")
		assert(expected>=Tree.EggValueMultiplier(2)*2*3-1e-9,"Missing 2x Coins or Rebirth: "..expected)
		s.friendBoost=0.2
		near(Playtime.Boosts(s).coins,expected*1.2,"Friend Boost")
		return ("Coins x%.2f"):format(expected*1.2)
	end)

	test("Free Rolls draw at lever Luck (no Hill bonus) and wait for storage room",function()
		local s=fixture(-9607)
		s.gemUpgrades={ExtraLuck=1}
		s:RefreshEffects()
		played(s,61)
		assert(Playtime.Claim(s,4),"Luck boost")
		-- The lever's Luck input, Luck boost included; a Hill roll would add RollLuckBonus.
		local paid,bonus=s:PaidLuckMultiplier(),s:RollLuckBonus()
		local function draws(seed,extra)
			local rng,list=Random.new(seed),{}
			for index=1,3 do list[index]=Rules.Draw(s.luck,rng:NextNumber(),s.promotion,paid,bonus+extra) end
			return table.concat(list,",")
		end
		-- A seed whose lever and Hill draws differ, so the check can tell them apart.
		local seed
		for candidate=1,500 do
			if draws(candidate,0)~=draws(candidate,Config.Hill.RollLuckBonus) then seed=candidate;break end
		end
		assert(seed,"No seed tells lever Luck from Hill Luck")
		s.debugRandom=Random.new(seed)
		local owned,credits={},s.hillRollCredits or 0
		for id in s.pets do owned[id]=true end
		local ok,message,receipt=Playtime.Claim(s,12)
		assert(ok,message)
		assert(table.concat(receipt.species,",")==draws(seed,0),"Draws "..table.concat(receipt.species,",").." ~= lever "..draws(seed,0))
		local added=0
		for id,pet in s.pets do
			if not owned[id] then added+=1;assert(pet.level==1 and pet.investment==0,"New chicken level or refund") end
		end
		assert(added==3 and (s.hillRollCredits or 0)==credits,"Hill credits used or chickens missing")
		assert(string.find(message,"^3 Free Rolls: ")~=nil,message)
		-- Storage full: refused, the tile stays ready, then pays once there is room.
		local t=fixture(-9608)
		played(t,61)
		t.CollectionLimit=function() return t:Count()+2 end
		local refused,why=Playtime.Claim(t,12)
		assert(not refused and string.find(why,"most chickens you can keep")~=nil,tostring(why))
		assert(Playtime.Snapshot(t).tiles[12].claimed==false and (t.hillRollCredits or 0)==0,"Tile spent while full")
		t.CollectionLimit=function() return t:Count()+3 end
		assert(Playtime.Claim(t,12),"Claim after making room")
		return message.." (seed "..seed..")"
	end)

	test("A Coins tile's amount is fixed when it unlocks, so claiming later pays no more",function()
		local s=fixture(-9611)
		played(s,1.02)
		local shown=Playtime.Snapshot(s).tiles[1].coins
		assert(shown and shown>0,"Shown "..tostring(shown))
		s.rebirths=(s.rebirths or 0)+1 -- steady income doubles; the unlocked tile does not
		assert(DailyService.CashFor(s,Rewards.Tiles[1].coinMinutes)>shown,"Income grew")
		local ok,message,receipt=Playtime.Claim(s,1)
		assert(ok,message)
		assert(receipt.coins==shown,"Paid "..tostring(receipt.coins).." for a tile shown as "..shown)
		return "Shown "..shown..", paid "..receipt.coins
	end)

	test("The snapshot lists every tile with its server-time unlock and current Coins",function()
		local s=fixture(-9609)
		local visit=played(s,2)
		local snapshot=Playtime.Snapshot(s)
		local income=DailyService.Income(s)
		for index,tile in Rewards.Tiles do
			local entry=snapshot.tiles[index]
			near(entry.unlockAt,visit.startedAt+tile.at*60,"Unlock "..index)
			if tile.kind=="Coins" then
				assert(entry.coins==math.floor(income*tile.coinMinutes*60),"Coins "..index)
			else
				assert(entry.coins==nil,"Coins on "..index)
			end
		end
		return #snapshot.tiles.." tiles"
	end)

	test("A reset starts a new visit with no boosts",function()
		local s=fixture(-9610)
		played(s,9)
		assert(Playtime.Claim(s,4),"Claim")
		s:Reset()
		s.loaded=true
		assert(s.playtime==nil and s.playtimeBoosts==nil and Playtime.Boost(s,"Luck")==0,"Visit kept")
		assert(Playtime.Played(s)==0,"Played kept")
		return "Fresh"
	end)

	local passed=0
	for _,result in results do if result.passed then passed+=1 end end
	print(("[PlaytimeChecks] %d/%d passed"):format(passed,#results))
	for _,result in results do
		print((if result.passed then "  PASS " else "  FAIL ")..result.name.." — "..result.detail)
	end
	return results
end

return Checks
