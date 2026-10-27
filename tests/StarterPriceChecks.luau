-- October 27 (WS2 retention, docs/team/EARLY_ECONOMY_20261027.md): starter prices and
-- the early economy numbers. Pure checks: Rules.StarterPrice over the whole roll pool,
-- the Config switch, and the flat Army Size I/II prices. Run in Studio:
-- require(game.ServerStorage.PetRollTests.StarterPriceChecks).Run()
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Config=require(Shared.Config)
local Catalog=require(Shared.PetCatalog)
local Rules=require(Shared.Rules)
local Tree=require(Shared.UpgradeCatalog)
local Checks={}

-- Every rollable chicken in its odds order (RollPool: rarity ladders, commonest first).
local function poolOrder(): {string}
	local list={}
	for _,group in Catalog.RollPool do
		for _,band in group.bands do
			for _,id in band.ids do table.insert(list,id) end
		end
	end
	return list
end

-- Runs fn with Config.Economy.StarterPrices replaced, then restores it.
local function withSettings(settings,fn)
	local before=Config.Economy.StarterPrices
	Config.Economy.StarterPrices=settings
	local ok,result=pcall(fn)
	Config.Economy.StarterPrices=before
	if not ok then error(result,0) end
	return result
end

function Checks.Run()
	local results={}
	local function test(name,fn)
		local ok,detail=pcall(fn)
		table.insert(results,{name=name,passed=ok,detail=tostring(detail)})
	end

	test("Settings: 25% at 2 owned, full at 20, floor 150, step 5",function()
		local s=Config.Economy.StarterPrices
		assert(type(s)=="table" and s.Enabled==true and s.Fraction==0.25 and s.FullAt==20 and s.Floor==150 and s.Step==5,
			"StarterPrices")
		return "Enabled, 0.25 -> 1 over 2..20 owned"
	end)

	test("Every rollable chicken: whole, at most the list price, at least the floor, strictly rising along the odds",function()
		local order=poolOrder()
		assert(#order>=70,"Roll pool "..#order)
		for _,owned in {0,2,5,8,11,14,19} do
			local previous=-1
			for _,id in order do
				local list=Rules.RecruitPrice(id,1)
				local price=Rules.StarterPrice(list,owned)
				assert(price==math.floor(price),id.." not whole at "..owned..": "..price)
				assert(price<=list,id.." above its list price at "..owned)
				assert(price>=math.min(list,Config.Economy.StarterPrices.Floor),id.." below the floor at "..owned)
				assert(price%5==0 or price==list,id.." not a step of 5 at "..owned..": "..price)
				assert(price>previous,id.." ("..price..") not above the previous chicken ("..previous..") at "..owned)
				previous=price
			end
		end
		return #order.." chickens at 7 owned counts"
	end)

	test("The fade: 25% at 2 owned, 50% at 8, 75% at 14, the list price from 20 owned",function()
		local list=Rules.RecruitPrice("Rooster",1)
		assert(list==1900,"Rooster list "..list)
		assert(Rules.StarterPrice(list,0)==475 and Rules.StarterPrice(list,2)==475,"25%: "..Rules.StarterPrice(list,2))
		assert(Rules.StarterPrice(list,8)==950,"50%: "..Rules.StarterPrice(list,8))
		assert(Rules.StarterPrice(list,14)==1425,"75%: "..Rules.StarterPrice(list,14))
		for _,owned in {20,21,60,1000} do assert(Rules.StarterPrice(list,owned)==list,"Full at "..owned) end
		-- Higher levels quote from their own list price.
		local level3=Rules.RecruitPrice("Bee",3)
		assert(Rules.StarterPrice(level3,2)==math.ceil(level3*0.25/5)*5,"Level 3 Bee")
		return "Rooster 475 / 950 / 1,425 / 1,900"
	end)

	test("The basic Chicken stays 150; the ladder's free and 20-Coin steps are never raised",function()
		assert(Rules.RecruitPrice("Duck",1)==150,"Chicken list")
		for _,owned in {0,2,10,20} do assert(Rules.StarterPrice(150,owned)==150,"Chicken at "..owned) end
		assert(Rules.StarterPrice(0,2)==0 and Rules.StarterPrice(20,2)==20,"Ladder prices")
		return "150"
	end)

	test("Enabled = false (or no settings) quotes the list price",function()
		withSettings({Enabled=false,Fraction=0.25,FullAt=20,Floor=150,Step=5},function()
			assert(Rules.StarterPrice(1900,2)==1900,"Disabled")
		end)
		withSettings(nil,function()
			assert(Rules.StarterPrice(1900,2)==1900,"Missing")
		end)
		return "list price"
	end)

	test("Army Size I costs 300 and II 6,000, flat for every Rebirth rank",function()
		for _,rank in {0,1,10,30,50} do
			assert(Tree.Price("ArmySize",1,rank)==300,"Army Size I at rank "..rank..": "..tostring(Tree.Price("ArmySize",1,rank)))
			assert(Tree.Price("ArmySize",2,rank)==6000,"Army Size II at rank "..rank)
			assert(Tree.Price("ArmySize",3,rank)==25000 and Tree.Price("ArmySize",4,rank)==90000,"Army Size III/IV at rank "..rank)
		end
		assert(Config.Rebirth.Intro.KeepTree==true,"Rebirth 0 keeps the tree")
		return "300 / 6,000 / 25,000 / 90,000"
	end)

	local passed=0
	for _,result in results do if result.passed then passed+=1 end end
	print(("[StarterPriceChecks] %d/%d passed"):format(passed,#results))
	for _,result in results do
		print((if result.passed then "  PASS " else "  FAIL ")..result.name.." — "..result.detail)
	end
	return results
end

return Checks
