-- October 27 Lucky Start and discovery (WS4 retention; docs/team/LUCKY_START_20261027.md).
-- Isolated sessions only: no DataStore, live world, Players or product prompts. Run in
-- Studio: require(game.ServerStorage.PetRollTests.LuckyStartChecks).Run(), or headless
-- from tools/sim: lune run harness.luau ../.. runsuite.luau LuckyStartChecks
local Server=game:GetService("ServerStorage").PetRoll
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Catalog=require(Shared.PetCatalog)
local Rules=require(Shared.Rules)
local IndexProgress=require(Shared.IndexProgress)
local Session=require(Server.PlayerSession)
local Rolls=require(Server.RollService)
local LuckyStart=require(Server.LuckyStart)
local RebirthChickens=require(Server.RebirthChickens)
local Checks={}

local RANK=LuckyStart.Rank

-- A fixed draw: Rules.Draw lands on a Common, FavoredRolls fires (below 50%), no mutation.
local function fixed(value)
	return {NextNumber=function() return value end}
end

-- An empty-start profile right after the tutorial: two basic Chickens, guide complete,
-- the tutorial's two pulls counted, one podium.
local function fixture(userId)
	local s=Session.new(userId,"Lucky Start fixture",1)
	s.loaded=true
	for _=1,2 do s:AddPet("Duck",1) end
	s.tutorial.bought,s.tutorial.guideCompleted,s.tutorial.rollCount=true,true,2
	s.rollSlotCount=1
	s.coins=0
	s.debugRandom=fixed(0.3)
	return s
end

-- One lever pull (Auto Roll style, no guard), then back to a ready lever.
local function pull(s,rolls,manual)
	s.rollReadyAt=0
	local ok,message=rolls:Roll(s,0,manual)
	return ok,message
end

local function rarityOf(offer)
	return Catalog[offer.species].rarity
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,detail=pcall(fn)
		table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
	end

	test("Config: Lucky Start on, Uncommon at pull 2, Rare at pull 8, FavoredRolls 3 x 50%",function()
		local c=Config.LuckyStart
		assert(c.Enabled==true and c.UncommonAt==2 and c.RareAt==8 and c.UncommonAgain==5 and c.RareAgain==10)
		assert(c.MaxForced==2 and c.Window==40 and c.Guard==true)
		assert(Config.Economy.FavoredRolls.rolls==3 and Config.Economy.FavoredRolls.chance==0.5)
	end)

	test("Never buying: Uncommon on 2 and 7, Rare on 8 and 18, nothing forced after the caps",function()
		local s,rolls=fixture(-9101),Rolls.new()
		local forced={}
		for k=1,40 do
			assert(pull(s,rolls,false),"pull "..k.." failed")
			local offer=s.offers[1]
			if offer.lucky then
				forced[k]=offer.lucky
				assert(rarityOf(offer)==offer.lucky,"pull "..k.." forced "..offer.lucky.." but drew "..rarityOf(offer))
				assert(offer.chance==1,"A Lucky Start offer discloses chance 1")
			end
			-- Every offer is new to the Index here (nothing is bought).
			assert(offer.new==true or s.discovered[offer.species],"new flag")
		end
		local list={}
		for k=1,40 do if forced[k] then table.insert(list,k..":"..forced[k]) end end
		assert(table.concat(list,",")=="2:Uncommon,7:Uncommon,8:Rare,18:Rare","Forced pulls: "..table.concat(list,","))
		assert(s.luckyStart.pulls==40 and s.luckyStart.firesU==2 and s.luckyStart.firesR==2)
		assert(not LuckyStart.Active(s),"The window ends at 40 pulls")
		assert(pull(s,rolls,false))
		assert(s.luckyStart.pulls==40 and s.offers[1].lucky==nil,"Nothing counts or forces past the window")
	end)

	test("Pulls 1-3 favour the basic Chicken except where Lucky Start forces",function()
		local s,rolls=fixture(-9102),Rolls.new()
		assert(pull(s,rolls,false));assert(s.offers[1].species=="Duck","pull 1 is the favoured Chicken")
		assert(pull(s,rolls,false));assert(s.offers[1].lucky=="Uncommon","pull 2 is Lucky Start, not the favoured Chicken")
		assert(pull(s,rolls,false));assert(s.offers[1].species=="Duck","pull 3 is the favoured Chicken")
	end)

	test("Owning the rarity stops its guarantee; owning a Rare stops both",function()
		local s,rolls=fixture(-9103),Rolls.new()
		s.discovered.Bee=true -- an Uncommon in the Index
		for _=1,12 do assert(pull(s,rolls,false));assert(s.offers[1].lucky~="Uncommon","Uncommon forced while owned") end
		assert(s.luckyStart.firesR==1,"The Rare still comes at pull 8")
		local r,rolls2=fixture(-9104),Rolls.new()
		for _,id in Catalog.Order do
			if Catalog[id].rarity=="Rare" then r.discovered[id]=true;break end
		end
		assert(LuckyStart.State(r)==nil,"No counter once a Rare is owned")
		for _=1,40 do assert(pull(r,rolls2,false));assert(r.offers[1].lucky==nil,"Forced while a Rare is owned") end
	end)

	test("Natural offers push the next guarantee; Record counts forced ones",function()
		local s=fixture(-9105)
		local uncommon,rare
		for _,id in Catalog.Order do
			local rarity=Catalog[id].rarity
			if rarity=="Uncommon" and not uncommon then uncommon=id end
			if rarity=="Rare" and not rare then rare=id end
		end
		LuckyStart.Record(s,{{species=uncommon}},nil)
		assert(s.luckyStart.pulls==1 and s.luckyStart.nextU==6 and s.luckyStart.nextR==8 and s.luckyStart.firesU==0)
		LuckyStart.Record(s,{{species="Duck"},{species=rare}},"Rare")
		assert(s.luckyStart.pulls==2 and s.luckyStart.nextU==7 and s.luckyStart.nextR==12 and s.luckyStart.firesR==1)
	end)

	test("Old saves (introRebirth nil), skipped or unfinished tutorials never force",function()
		local old,rolls=fixture(-9106),Rolls.new()
		old.introRebirth=nil
		for _=1,20 do assert(pull(old,rolls,false));assert(old.offers[1].lucky==nil) end
		assert(old.luckyStart.pulls==0 and LuckyStart.State(old)==nil)
		local skipped=fixture(-9107);skipped.tutorial.guideSkipped=true
		assert(not LuckyStart.Active(skipped))
		local early=fixture(-9108);early.tutorial.guideCompleted=nil
		assert(not LuckyStart.Active(early))
		local off=fixture(-9109)
		local saved=Config.LuckyStart.Enabled
		Config.LuckyStart.Enabled=false
		local active=LuckyStart.Active(off)
		Config.LuckyStart.Enabled=saved
		assert(not active,"Enabled=false turns it off")
	end)

	test("Read never errors and clamps garbage; the save round-trips",function()
		for _,value in {nil,"x",5,true,{},{pulls="a",nextU=-5,nextR=1e9,firesU=0/0,firesR=-1}} do
			local state=LuckyStart.Read(value)
			assert(type(state.pulls)=="number" and state.pulls>=0 and state.nextU>=1 and state.nextR<=1000)
			assert(state.firesU>=0 and state.firesR>=0 and state.firesU==state.firesU)
		end
		local s,rolls=fixture(-9110),Rolls.new()
		for _=1,9 do assert(pull(s,rolls,false)) end
		local data=s:ToData()
		local back=LuckyStart.Read(data.luckyStart)
		for _,key in {"pulls","nextU","nextR","firesU","firesR"} do assert(back[key]==s.luckyStart[key],key) end
	end)

	test("Counter: Uncommon next Roll, then Rare in 6 Rolls, in the snapshot",function()
		local s,rolls=fixture(-9111),Rolls.new()
		local state=LuckyStart.State(s)
		assert(state and state.kind=="Uncommon" and state.left==2,"fresh: Uncommon in 2")
		assert(LuckyStart.CounterText(state)=="Uncommon in 2 Rolls")
		assert(pull(s,rolls,false))
		assert(LuckyStart.CounterText(LuckyStart.State(s) :: any)=="Uncommon next Roll!")
		assert(pull(s,rolls,false)) -- the Uncommon lands
		s.discovered[s.offers[1].species]=true -- bought
		state=LuckyStart.State(s) :: any
		assert(state.kind=="Rare" and state.left==6,"Rare in 6 after pull 2, got "..tostring(state.kind).." "..tostring(state.left))
		assert(LuckyStart.CounterText(state)=="Rare in 6 Rolls")
		local snap=s:Snapshot(0)
		assert(snap.luckyStart and snap.luckyStart.kind=="Rare" and snap.luckyStart.left==6,"state.luckyStart")
	end)

	test("Guard refuses the first manual pull past a lucky offer once; Auto Roll ignores it",function()
		local s,rolls=fixture(-9112),Rolls.new()
		assert(pull(s,rolls,false));assert(pull(s,rolls,false))
		local lucky=s.offers[1]
		assert(lucky.lucky=="Uncommon")
		local ok,message=pull(s,rolls,true)
		assert(not ok and message==LuckyStart.GuardText(lucky),"Guard message: "..tostring(message))
		assert(message:find("is still on your podium! Pull again to roll past it.",1,true))
		assert(s.offers[1].id==lucky.id and s.luckyStart.pulls==2,"The refused pull changes nothing")
		assert(pull(s,rolls,true),"The second pull rolls")
		assert(s.offers[1].id~=lucky.id and s.rollPastWarned==nil)
		-- Auto Roll (no manual flag) is never guarded.
		local a,autoRolls=fixture(-9113),Rolls.new()
		assert(pull(a,autoRolls,false));assert(pull(a,autoRolls,false))
		assert(pull(a,autoRolls,false),"Auto Roll rolls past")
	end)

	test("Guard keeps the next Rebirth's find for old saves too",function()
		local s,rolls=fixture(-9114),Rolls.new()
		s.introRebirth=nil
		local find=RebirthChickens.Required(1)
		assert(find,"Rebirth 1 has a find")
		s.debugNext=find
		assert(pull(s,rolls,false))
		local ok=pull(s,rolls,true)
		assert(not ok,"Rolling past the Rebirth find is refused once")
		assert(pull(s,rolls,true))
	end)

	test("Buy receipt: firstFind, found/total from IndexProgress; offer carries lucky/new/firstFind",function()
		local s,rolls=fixture(-9115),Rolls.new()
		assert(pull(s,rolls,false));assert(pull(s,rolls,false))
		local offer=s.offers[1]
		s.coins=1e9
		local ok,_,_,recruit=rolls:Buy(s,offer.id,1e9)
		assert(ok,"buy failed")
		assert(recruit.firstFind==true and recruit.offer.firstFind==true and recruit.offer.lucky=="Uncommon")
		local found,total=IndexProgress.Count(s.discovered)
		assert(recruit.found==found and recruit.total==total and found==2,"found "..tostring(recruit.found))
		assert(recruit.offer.rarity=="Uncommon")
		-- Same species again: not a first find.
		s.debugNext=offer.species
		assert(pull(s,rolls,false))
		local again=s.offers[1]
		assert(again.new==nil)
		local ok2,_,_,recruit2=rolls:Buy(s,again.id,1e9)
		assert(ok2 and recruit2.firstFind==nil and recruit2.offer.firstFind==nil)
	end)

	test("IndexProgress matches the Index menu's rule and takes a session or a map",function()
		local s=fixture(-9116)
		s.discovered.Bee=true
		local function browserRule(found,eventOn)
			local collected,total=0,0
			for _,species in Catalog.Order do
				local definition=Catalog[species]
				local ever=found[species]==true
				if ever or not (definition.vaulted or (definition.limited and not eventOn)) then
					total+=1;if ever then collected+=1 end
				end
			end
			return collected,total
		end
		for _,eventOn in {true,false} do
			local a,b=IndexProgress.Count(s.discovered,eventOn)
			local c,d=browserRule(s.discovered,eventOn)
			assert(a==c and b==d,"Count differs")
		end
		local a,b=IndexProgress.Count(s)
		local c,d=IndexProgress.Count(s.discovered)
		assert(a==c and b==d and a==2 and b>=78,"Session form: "..a.."/"..b)
	end)

	test("Starter prices (WS2): podium quote, struck list price, Buy charges the quote",function()
		local s,rolls=fixture(-9117),Rolls.new()
		assert(pull(s,rolls,false));assert(pull(s,rolls,false))
		local offer=s.offers[1]
		local list=Rules.RecruitPrice(offer.species,offer.level)
		assert(offer.price==Rules.StarterPrice(list,s:Count()) and offer.price<list and offer.listPrice==list,
			"price "..offer.price.." list "..tostring(offer.listPrice))
		s.coins=offer.price
		local ok,_,_,recruit=rolls:Buy(s,offer.id,1e9)
		assert(ok and s.coins==0 and recruit.offer.price==offer.price and recruit.offer.listPrice==list)
		local old,rolls2=fixture(-9118),Rolls.new()
		old.introRebirth=nil
		assert(pull(old,rolls2,false))
		assert(old.offers[1].listPrice==nil and old.offers[1].price==Rules.RecruitPrice(old.offers[1].species,old.offers[1].level))
	end)

	test("Advice line: Flock first, then the Army, else its own rate",function()
		local s=fixture(-9119)
		local text,good=s:OfferAdvice("Bee",1)
		assert(good and text:match("^%+[%d,]+ Coins/s in your Flock$"),"Flock advice: "..text)
		local rate=s:DisplayedPetIncome("Bee",1,1)
		assert(text=="+"..require(Shared.CurrencyLimits).Rate(rate).."/s in your Flock")
		assert(not text:find("%$") and not text:lower():find("cash"))
	end)

	test("Every Lucky Start draw stays inside its rarity and is rollable",function()
		local s=fixture(-9120)
		for _,rarity in ({"Uncommon","Rare"} :: {string}) do
			for i=0,19 do
				local id=LuckyStart.Draw(s,fixed((i+0.5)/20),rarity,1,0)
				assert(id and Catalog[id].rarity==rarity and (RANK[rarity] or 0)>=2,"Draw "..tostring(id))
				assert(Rules.Odds(s.luck,s.recruitTier,1,0)[id]>0,"Unrollable "..tostring(id))
			end
		end
	end)

	return results
end

return Checks
