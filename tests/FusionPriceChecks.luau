--!strict
-- Disposable profiles; no persistent player data or real purchases.
local Server=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Rules=require(Shared.Rules)
local Giant=require(Shared.GiantChicken)
local Checks={}
local function setup(count)
	local s=Session.new(-9282,"Fusion fee fixture",1)
	s.pets,s.slots={},{};s.loaded=true
	local ids={}
	for _=1,count or 3 do table.insert(ids,s:AddPet("Duck",1).id) end
	local price=Rules.MergePrice("Duck",1)
	return s,ids,price
end
function Checks.Run()
	local results={}
	local function check(name,fn)
		local ok,err=pcall(fn);table.insert(results,{name=name,passed=ok,error=if not ok then tostring(err) else nil})
	end
	check("Fee follows species and level; upgrades and wallet cannot change the quote",function()
		assert(Rules.MergePrice("Duck",1)==600 and Rules.MergePrice("Duck",2)==1200)
		assert(Rules.MergePrice("Bucket",1)==4200 and Rules.MergePrice("Rainbow",1)==40200)
		local s,ids,price=setup();s.coins=0;s.incomeLevel=25;s.luck=20
		assert(Army.MergeOptions(s)[1].price==price)
	end)
	check("Insufficient, missing, stale and malformed quotes never spend or consume",function()
		local s,ids,price=setup();s.coins=price-1
		assert(not Army.Merge(s,ids[1],ids[2],ids[3],1,price))
		assert(s.coins==price-1 and s:Count()==3 and not s.pets[ids[1]].giantSize)
		s.coins=price
		assert(not Army.Merge(s,ids[1],ids[2],ids[3],1))
		for _,quote in {0,price-1,price+1,0/0,math.huge,"600"} do
			assert(not Army.Merge(s,ids[1],ids[2],ids[3],1,quote))
		end
		assert(s.coins==price and s:Count()==3)
	end)
	check("Exact balance succeeds once; service fee is not refunded or duplicated",function()
		local s,ids,price=setup();s.coins=price
		local investment=0;for _,pet in s.pets do investment+=pet.investment end
		assert(Army.Merge(s,ids[1],ids[2],ids[3],1,price))
		local pet=s.pets[ids[1]]
		assert(s.coins==0 and s:Count()==1 and pet.level==2 and pet.investment==investment)
		assert(pet.giantSize>=4 and pet.giantSize<=6)
		assert(not Army.Merge(s,ids[1],ids[2],ids[3],1,price) and s.coins==0)
		local restored=Session.new(-9283,"Restored",1);assert(restored:LoadData(s:ToData()))
		assert(restored.coins==0 and restored.pets[pet.id].giantSize==pet.giantSize)
	end)
	check("Batch affordability and stale last quote reject the entire transaction",function()
		local s,ids,price=setup(6)
		local triples={}
		for i=1,6,3 do table.insert(triples,{firstId=ids[i],secondId=ids[i+1],thirdId=ids[i+2],level=1,expectedPrice=price}) end
		s.coins=price*2-1
		assert(not Army.MergeAll(s,triples) and s:Count()==6 and s.coins==price*2-1)
		s.coins=price*2;triples[2].expectedPrice=0
		assert(not Army.MergeAll(s,triples) and s:Count()==6 and s.coins==price*2)
		triples[2].expectedPrice=price
		local ok,_,receipt=Army.MergeAll(s,triples)
		assert(ok and s:Count()==2 and s.coins==0 and receipt.price==price*2)
	end)
	check("Saved large Commons survive retuning; advertised range honors actual inputs",function()
		local minimum,maximum=Giant.Range("Common",20.4)
		assert(minimum==20.4 and maximum==20.4 and Giant.SizeFromRoll("Common",0,20.4)==20.4)
		local s,ids,price=setup();s.pets[ids[2]].giantSize=20.4
		assert(Army.Merge(s,ids[1],ids[2],ids[3],1,price) and s.pets[ids[1]].giantSize==20.4)
	end)
	return results
end
return Checks
