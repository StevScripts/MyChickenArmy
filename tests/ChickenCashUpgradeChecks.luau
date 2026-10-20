--!strict
-- Disposable profiles only; never loads or writes a player's DataStore.
local Server=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Rules=require(Shared.Rules)
local Config=require(Shared.Config)
local Checks={}
local function setup()
	local s=Session.new(-9291,"Cash upgrade fixture",1)
	s.pets,s.slots,s.armySelection={},{},{}
	s.loaded=true;s.coins=1e9
	return s,s:AddPet("Duck",1)
end
local function buy(s,pet)
	return Army.UpgradeChicken(s,pet.id,pet.level,Rules.ChickenUpgradePrice(pet.species,pet.level))
end
function Checks.Run()
	local results={}
	local function check(name,fn)
		local ok,err=pcall(fn)
		table.insert(results,{name=name,passed=ok,error=if not ok then tostring(err) else nil})
	end
	check("Level one through ten is cash-only, with no camp or rank prerequisite",function()
		local s,pet=setup()
		for level=1,Config.MaxPetLevel-1 do
			local cash,investment=s.coins,pet.investment
			local price=Rules.ChickenUpgradePrice(pet.species,level)
			assert(buy(s,pet))
			assert(pet.level==level+1 and s.coins==cash-price and pet.investment==investment+price)
		end
		assert(s.promotion==1 and next(s.firstWins)==nil and s:Count()==1)
		assert(not buy(s,pet) and not pet.giantSize)
		local shown=s:Snapshot(0).pets[1]
		assert(shown.upgradePrice==nil and shown.canUpgrade==false)
	end)
	check("Exact quote charges once; replayed and malformed requests never change state",function()
		local s,pet=setup();local price=Rules.ChickenUpgradePrice(pet.species,1)
		local cash,investment=s.coins,pet.investment
		for _,quote in {false,0,price-1,price+1,0/0,math.huge,"1800"} do
			assert(not Army.UpgradeChicken(s,pet.id,1,quote))
		end
		for _,level in {false,0,2,0/0,math.huge,"1"} do assert(not Army.UpgradeChicken(s,pet.id,level,price)) end
		assert(not Army.UpgradeChicken(s,{},1,price))
		assert(not Army.UpgradeChicken(s,"another player's chicken",1,price))
		assert(s.coins==cash and pet.investment==investment and pet.level==1)
		s.coins=price
		assert(Army.UpgradeChicken(s,pet.id,1,price) and s.coins==0)
		assert(not Army.UpgradeChicken(s,pet.id,1,price) and pet.level==2 and s.coins==0)
	end)
	check("Insufficient cash and unsafe profile state cannot spend",function()
		local s,pet=setup();local price=Rules.ChickenUpgradePrice(pet.species,1)
		s.coins=price-1;assert(not buy(s,pet) and s.coins==price-1 and pet.level==1)
		s.coins=price
		for _,field in {"closing","saveLost"} do s[field]=true;assert(not buy(s,pet));s[field]=nil end
		s.loaded=false;assert(not buy(s,pet) and s.coins==price and pet.level==1)
	end)
	check("Deployed, traveling and defending birds are blocked; home reserves remain eligible",function()
		local s,pet=setup();s.awayPets[pet.id]=true
		assert(not buy(s,pet) and s:Snapshot(0).pets[1].canUpgrade==false)
		s.awayPets={};s.armySelection={pet.id};s:RefreshArmy();s.armyState="Travel"
		assert(not buy(s,pet))
		local reserve=s:AddPet("Mallard",1);assert(buy(s,reserve))
		s.armyState="Home";s.incoming="defense";assert(not buy(s,pet))
		s.incoming=nil;pet.favorite=true;assert(buy(s,pet))
	end)
	check("Level, cash, investment, favorites and a retired Colossal size survive saving",function()
		local s,pet=setup();pet.favorite=true;pet.retiredGiantSize=24.5
		assert(buy(s,pet))
		local restored=Session.new(-9292,"Restored fixture",1)
		assert(restored:LoadData(s:ToData()))
		local saved=restored.pets[pet.id]
		-- October 20: Giants are retired; the size round-trips but never plays.
		assert(saved.level==2 and saved.investment==pet.investment and saved.favorite
			and saved.retiredGiantSize==24.5 and saved.giantSize==nil)
		assert(restored.coins==s.coins)
	end)
	check("Cash purchases add their real cost to refunds without repricing old saves",function()
		local s,pet=setup();pet.investment=0
		local historical=Rules.Investment("Duck",4)
		assert(buy(s,pet))
		assert(pet.investment==1800 and Rules.SellValue(pet.investment)==900)
		assert(Rules.Investment("Duck",4)==historical)
		pet.investment=1e12;local cash=s.coins
		assert(not buy(s,pet) and s.coins==cash and pet.level==2)
	end)
	check("Snapshot exposes the authoritative quote and updated combat/egg output",function()
		local s,pet=setup();local before=Rules.Stats(pet.species,1,1)
		local quote=s:Snapshot(0).pets[1]
		assert(quote.canUpgrade and quote.upgradePrice==1800)
		assert(buy(s,pet))
		local after=Rules.Stats(pet.species,1,pet.level)
		local shown=s:Snapshot(0).pets[1]
		assert(shown.eggsPerSecond==quote.eggsPerSecond*2 and after.damage==before.damage*1.25)
		assert(shown.upgradePrice==9000 and shown.income==quote.income*2)
	end)
	return results
end
return Checks
