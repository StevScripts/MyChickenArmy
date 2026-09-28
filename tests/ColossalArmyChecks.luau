--!strict
-- Disposable sessions and encounter tables; no real player profile writes.
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Server=game.ServerStorage.PetRoll
local Giant=require(Shared.GiantChicken)
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Rules=require(Shared.Rules)
local Battle=require(Server.Battle)
local Reinforcements=require(Server.ArmyReinforcements)
local Checks={}
local function setup()
	local s=Session.new(-9284,"Colossal fixture",1)
	s.pets,s.slots={},{};s.loaded=true;s.coins=1e9
	local a,b=s:AddPet("Dragon",1),s:AddPet("StormDuck",1)
	a.giantSize,b.giantSize=20,27.5
	local c,d,e=s:AddPet("Duck",1),s:AddPet("Mallard",1),s:AddPet("Camo",1)
	c.giantSize,d.giantSize,e.giantSize=4.5,5,6
	return s,a,b,c,d,e
end
local function count(s,ids)
	local total=0
	for _,id in ids do if Giant.IsColossal(s.pets[id].giantSize) then total+=1 end end
	return total
end
function Checks.Run()
	local results={}
	local function check(name,fn)
		local ok,err=pcall(fn);table.insert(results,{name=name,passed=ok,error=if not ok then tostring(err) else nil})
	end
	check("Fresh Colossal odds are 1% Legendary and 3% Mythic; near-max is rarer",function()
		for rarity,expected in {Common=0,Uncommon=0,Rare=0,Epic=0,Legendary=100,Mythic=300} do
			local colossal,nearMax=0,0
			for i=0,9999 do
				local size=Giant.SizeFromRoll(rarity,(i+0.5)/10000)
				if Giant.IsColossal(size) then colossal+=1 end
				if size>=27 then nearMax+=1 end
			end
			assert(colossal==expected,rarity.." incorrect Colossal odds: "..colossal)
			if rarity=="Mythic" then assert(nearMax>0 and nearMax<15) else assert(nearMax==0) end
		end
		assert(not Giant.IsColossal(19.9) and Giant.IsColossal(20))
		assert(Giant.ColossalChance("Common",20.4)==1 and Giant.SizeFromRoll("Common",0,20.4)==20.4)
	end)
	check("Select Best keeps one highest-power Colossal and fills ordinary Giant slots",function()
		local s,a,b,c,d,e=setup();assert(Army.SelectBest(s))
		local ids=s:BestPetIds();assert(#ids==3 and count(s,ids)==1 and table.find(ids,b.id) and not table.find(ids,a.id))
		s.armySelection={c.id,d.id,e.id};s:RefreshArmy()
		assert(#s:BestPetIds()==3 and count(s,s:BestPetIds())==0 and #s:Lineup()==3)
	end)
	check("Manual second Colossal rejects atomically; explicit replacement and stale protection work",function()
		local s,a,b,c=setup();s.armySelection={a.id,c.id};s:RefreshArmy()
		local before=s:BestPetIds()
		assert(not Army.SetSelection(s,{a.id,b.id,c.id},before))
		assert(table.concat(s:BestPetIds())==table.concat(before))
		assert(Army.SetSelection(s,{b.id,c.id},before))
		assert(not Army.SetSelection(s,{a.id,c.id},before))
		assert(count(s,s:BestPetIds())==1 and s:BestPetIds()[1]==b.id)
	end)
	check("Older saved multi-Colossal selections normalize without deleting or shrinking birds",function()
		local s,a,b,c=setup();local data=s:ToData();data.armySelection={a.id,b.id,c.id}
		local restored=Session.new(-9285,"Restore",1);assert(restored:LoadData(data))
		assert(restored:Count()==5 and restored.pets[a.id].giantSize==20 and restored.pets[b.id].giantSize==27.5)
		assert(#restored:BestPetIds()==2 and count(restored,restored:BestPetIds())==1)
		assert(#restored:ToData().armySelection==2 and #restored:Lineup()==2)
		restored.slots={a.id,b.id,c.id};assert(#restored:Lineup()==2)
	end)
	check("Fusion cannot leave two Colossals equipped; retained size and price are unchanged",function()
		local s,a,b,c=setup();local d,e=s:AddPet("Duck",1),s:AddPet("Duck",1);e.giantSize=22
		s.armySelection={a.id,c.id};s:RefreshArmy();local before=s.coins
		assert(Army.Merge(s,c.id,d.id,e.id,1,Rules.MergePrice("Duck",1)))
		assert(s.pets[c.id].giantSize==22 and s.coins==before-600)
		assert(count(s,s:BestPetIds())==1 and s:BestPetIds()[1]==a.id)
	end)
	check("Buying a slot skips a conflicting Colossal and adds an ordinary reserve",function()
		local s,a,b,c,d=setup();s.armySelection={a.id,c.id,d.id};s:RefreshArmy()
		assert(Army.Expand(s))
		assert(#s:BestPetIds()==4 and count(s,s:BestPetIds())==1 and table.find(s:BestPetIds(),a.id))
	end)
	check("Battle swaps wait for old Colossal to return on either side; rapid reversals reuse it",function()
		for _,side in {"A","B"} do
			local s,a,b,c=setup();s.armySelection={a.id,c.id};s:RefreshArmy()
			local battle=Battle.new("ColossalSwap",if side=="A" then s.userId else -999,1,Vector3.zero,Vector3.new(100,1.05,100),0)
			battle.defender=if side=="B" then s.userId else -999
			battle.phase="Fight";battle:AddArmy(side,s:Lineup(),Vector3.new(0,1.05,0))
			local old=battle.units[1];old.x,old.z=40,40
			local world={ReturnPosition=function() return Vector3.new(0,1.05,0) end,PetPosition=function() return nil end}
			s.armyState="Deployed";s.armySelection={b.id,c.id}
			Reinforcements.Sync(s,battle,world,1)
			assert(old.retiring and #battle.units==2)
			for _,unit in battle.units do assert(unit.petId~=b.id) end
			s.armySelection={a.id,c.id};Reinforcements.Sync(s,battle,world,2);assert(not old.retiring)
			s.armySelection={b.id,c.id};old.x,old.z=old.homeX,old.homeZ
			Reinforcements.Sync(s,battle,world,3);Reinforcements.Sync(s,battle,world,4)
			local colossals=0;for _,unit in battle.units do if Giant.IsColossal(unit.giantSize) then colossals+=1;assert(unit.petId==b.id) end end
			assert(colossals==1 and count(s,s:BestPetIds())==1)
		end
	end)
	check("A dead retiring Colossal returns through respawn before replacement; finite lives stay spent",function()
		for _,finite in {false,true} do
			local s,a,b,c=setup();s.armySelection={a.id,c.id};s:RefreshArmy()
			local battle=Battle.new("ColossalRespawn",s.userId,1,Vector3.zero,Vector3.new(100,1.05,100),0)
			battle.phase="Fight";battle:AddArmy("A",s:Lineup(),Vector3.new(0,1.05,0))
			battle.incomeContest,battle.rosterLocked=finite,finite
			local old=battle.units[1];old.hp,old.x,old.z,old.respawnAt=0,40,40,2
			local world={ReturnPosition=function() return Vector3.new(0,1.05,0) end,PetPosition=function() return nil end}
			s.armyState="Deployed";s.armySelection={b.id,c.id};Reinforcements.Sync(s,battle,world,1)
			assert(old.retiring and #battle.units==2)
			battle:StepReinforcements(.1,3);assert(old.hp>0 and not old.reinforcing and old.x==old.homeX)
			Reinforcements.Sync(s,battle,world,3);Reinforcements.Sync(s,battle,world,4)
			local colossals=0;for _,u in battle.units do if Giant.IsColossal(u.giantSize) then colossals+=1;assert(u.petId==b.id) end end
			assert(colossals==1)
			if finite then assert(battle.reliefHistory.A[a.id].hp==0) end
		end
	end)
	return results
end
return Checks
