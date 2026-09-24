--!strict
-- Focused merge checks use disposable sessions, never a saved player profile.
local Server=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Config=require(Shared.Config)
local Checks={}

local function setup()
	local s=Session.new(-731,"Merge check",1)
	s.pets,s.slots={},{}
	local a,b=s:AddPet("Mallard",1),s:AddPet("Mallard",1)
	s.slots[1],s.slots[2]=a.id,b.id
	return s,a,b
end

function Checks.Run()
	local results={}
	local function check(name,fn)
		local ok,why=pcall(fn)
		table.insert(results,{name=name,passed=ok,error=if not ok then tostring(why) else nil})
	end
	check("Two matching home birds become one level higher, without payment",function()
		local s,a,b=setup();local coins=s.coins
		assert(Army.Merge(s,a.id,b.id,1));assert(s:Count()==1 and a.level==2 and a.stars==1)
		assert(s.pets[b.id]==nil and s.slots[1]==a.id and s.coins==coins)
		local data=s:ToData();local restored=Session.new(-732,"Round trip",1)
		assert(restored:LoadData(data));assert(restored.pets[a.id].level==2 and restored:Count()==1)
	end)
	check("Replaying consumed IDs cannot merge again",function()
		local s,a,b=setup();assert(Army.Merge(s,a.id,b.id,1))
		assert(not Army.Merge(s,a.id,b.id,1));assert(a.level==2 and s:Count()==1)
	end)
	check("Same ID, foreign ID, different variant, different level and stale level fail atomically",function()
		local s,a,b=setup();local coins=s.coins
		assert(not Army.Merge(s,a.id,a.id,1));assert(not Army.Merge(s,a.id,"foreign",1))
		b.species="Duck";assert(not Army.Merge(s,a.id,b.id,1));b.species=a.species
		b.level=2;assert(not Army.Merge(s,a.id,b.id,1));b.level=1
		assert(not Army.Merge(s,a.id,b.id,2));assert(s:Count()==2 and a.level==1 and s.coins==coins)
	end)
	check("Kept, deployed and defending birds are excluded",function()
		local s,a,b=setup();a.favorite=true
		assert(#Army.MergeOptions(s)==0 and not Army.Merge(s,a.id,b.id,1))
		a.favorite=false;s.armyState="Deployed"
		assert(#Army.MergeOptions(s)==0 and not Army.Merge(s,a.id,b.id,1))
		s.armyState="Home";s.incoming="battle"
		assert(#Army.MergeOptions(s)==0 and not Army.Merge(s,a.id,b.id,1));assert(s:Count()==2)
	end)
	check("Home reserves can merge while the squad is deployed",function()
		local s,a,b=setup();s.slots={};local fighter=s:AddPet("Dragon",1);s.slots[1]=fighter.id
		s.armyState="Deployed";assert(Army.Merge(s,a.id,b.id,1))
		assert(s.slots[1]==fighter.id and fighter.level==1 and s:Count()==2)
	end)
	check("Level cap prevents further merges",function()
		local s,a,b=setup();a.level,b.level=Config.MaxPetLevel,Config.MaxPetLevel
		assert(#Army.MergeOptions(s)==0 and not Army.Merge(s,a.id,b.id,Config.MaxPetLevel))
		assert(s:Count()==2 and a.level==Config.MaxPetLevel)
	end)
	check("Grouped recipes disclose pair count and exact income loss",function()
		local s,a,b=setup();s:AddPet("Mallard",1);s:AddPet("Mallard",1)
		s.incomeLevel=2;local offers=Army.MergeOptions(s);assert(#offers==1 and offers[1].pairs==2)
		local r=offers[1];assert(r.firstId==a.id and r.secondId==b.id)
		assert(r.beforeIncome>r.afterIncome)
		local income=s:Income();assert(Army.Merge(s,r.firstId,r.secondId,r.level))
		assert(math.abs(s:Income()-(income-r.beforeIncome+r.afterIncome))<0.0001)
	end)
	return results
end

return Checks
