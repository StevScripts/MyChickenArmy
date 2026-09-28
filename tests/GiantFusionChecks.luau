--!strict
-- Disposable profiles/rigs only. No DataStore, purchases or real player grants.
local Server=game.ServerStorage.PetRoll
local Shared=game.ReplicatedStorage.PetRoll.Shared
local Giant=require(Shared.GiantChicken)
local Catalog=require(Shared.PetCatalog)
local Rules=require(Shared.Rules)
local View=require(Shared.PetView)
local Session=require(Server.PlayerSession)
local Army=require(Server.ArmyService)
local Actor=require(Server.PetActor)
local Battle=require(Server.Battle)
local LiveActors=require(Server.LiveBattleActors)
local Checks={}

local function setup(species)
	local s=Session.new(-928,"Giant fixture",1)
	s.pets,s.slots={},{};s.coins=1e9;s.loaded=true;s.promotion=4
	local a,b,c=s:AddPet(species,1),s:AddPet(species,1),s:AddPet(species,1)
	s.armySelection={a.id};s:RefreshArmy()
	return s,a,b,c
end

function Checks.Run()
	local results={}
	local function check(name,fn)
		local ok,err=pcall(fn)
		table.insert(results,{name=name,passed=ok,error=if not ok then tostring(err) else nil})
	end
	check("Every rarity guarantees a Giant; inventory, stats, lineup and saves retain it",function()
		for _,species in {"Duck","Camo","Bucket","Knight","Wizard","Dragon"} do
			local s,a,b,c=setup(species)
			local coins=s.coins
			assert(Army.Merge(s,a.id,b.id,c.id,1,Rules.MergePrice(a.species,1)))
			assert(s:Count()==1 and a.level==2 and Giant.IsValidSize(a.giantSize) and s.coins==coins-Rules.MergePrice(a.species,1))
			assert(s:Lineup()[1].giantSize==a.giantSize and s:Snapshot(0).pets[1].giantSize==a.giantSize)
			local data=s:ToData();assert(data.pets[1].giantSize==a.giantSize)
			local restored=Session.new(-929,"Restored",1);assert(restored:LoadData(data))
			assert(restored.pets[a.id].giantSize==a.giantSize)
			assert(Rules.Income(a.species,1,2)==Rules.Income(a.species,1,1)*2)
			assert(not Army.Merge(s,a.id,b.id,c.id,1,Rules.MergePrice(a.species,1)) and restored.pets[a.id].giantSize==a.giantSize)
		end
	end)
	check("Rarity bands keep Common Giants small and quantiles ordered",function()
		local rarities={"Common","Uncommon","Rare","Epic","Legendary","Mythic"}
		for i=0,1000 do
			local previous=Giant.MinSize
			for _,rarity in rarities do
				local size=Giant.SizeFromRoll(rarity,i/1000)
				assert(Giant.IsValidSize(size) and size>=previous);previous=size
				local minimum,maximum=Giant.Range(rarity)
				assert(size>=minimum and size<=maximum)
				if i==0 then assert(size==minimum) elseif i==1000 then assert(size==maximum) end
			end
		end
		assert(Giant.SizeFromRoll("Mythic",0.5)>Giant.SizeFromRoll("Common",0.5))
	end)
	check("Fusing Giants retains the largest input regardless of survivor order",function()
		local s,a,b,c=setup("Duck")
		a.level,b.level,c.level=2,2,2;a.giantSize,b.giantSize,c.giantSize=7,27.5,12
		assert(Army.Merge(s,a.id,b.id,c.id,2,Rules.MergePrice(a.species,2)))
		assert(a.giantSize==27.5 and a.level==3 and s:Count()==1)
	end)
	check("Old profiles stay normal; invalid optional sizes reject without loading",function()
		local s=setup("Duck");local data=s:ToData()
		local restored=Session.new(-930,"Old profile",1);assert(restored:LoadData(data))
		for _,p in restored.pets do assert(p.giantSize==nil) end
		for _,invalid in {0,3.9,27.6,math.huge,0/0,"27",true} do
			data.pets[1].giantSize=invalid
			assert(not restored:LoadData(data))
		end
	end)
	check("Rejected batch does not change size or consume any input",function()
		local s,a,b,c=setup("Duck");a.giantSize=12
		local triple={firstId=a.id,secondId=b.id,thirdId=c.id,level=1,expectedPrice=Rules.MergePrice("Duck",1)}
		assert(not Army.MergeAll(s,{triple,triple}))
		assert(s:Count()==3 and a.giantSize==12 and a.level==1)
	end)
	local folder=Instance.new("Folder");folder.Name="GiantChecks";folder.Parent=workspace
	check("Every catalog appearance respects the maximum body extent",function()
		for _,species in Catalog.Order do
			local model=View.Create(folder,"Extent",species,1,Vector3.new(380,1.05,15))
			View.Level(model,2,27.5)
			local extent=math.max(model:GetAttribute("VisualHeight"),model:GetAttribute("VisualWidth"),model:GetAttribute("VisualDepth"))
			assert(math.abs(extent-27.5)<0.001,species.." exceeds bounds")
			model:Destroy()
		end
	end)
	check("Growth stays grounded, keeps small collider, and is idempotent",function()
		local actor=Actor.new(folder,"Growth","Duck",1,Vector3.new(380,1.05,15))
		for _,size in {4,6,18,27.5} do
			View.Level(actor.model,2,size);task.wait(0.05)
			local scale=actor.model:GetScale();local before=actor:Position()
			for _=1,10 do View.Level(actor.model,2,size) end
			View.Level(actor.model,3,size)
			assert(math.abs(actor.model:GetScale()-scale)<0.0001)
			assert(actor.root.Size.Magnitude<3 and actor.model:GetAttribute("NavigationHeight")<4)
			assert((actor:Position()-before).Magnitude<0.05)
			local cf,bounds=actor.model:GetBoundingBox()
			assert(math.abs(cf.Y-bounds.Y/2-actor:Position().Y)<0.12,"Floating or buried mesh")
		end
		assert(actor:Recover(actor:Position(),"Giant recovery fixture",os.clock()+2))
		task.wait(0.05)
		assert(actor.model:GetAttribute("GiantSize")==27.5 and actor.root.Size.Magnitude<3)
		assert(math.abs(actor.model:GetAttribute("VisualHeight")-27.5)<0.001)
		actor:Destroy()
	end)
	check("Battle lineup, new rig, respawn and snapshot retain Giant size",function()
		local s,a=setup("Duck");a.level=2;a.giantSize=27.5
		local battle=Battle.new("GiantBattle",s.userId,1,Vector3.new(380,1.05,15),Vector3.new(380,1.05,15),0)
		battle:AddArmy("A",s:Lineup(),Vector3.new(380,1.05,15))
		assert(battle.units[1].giantSize==27.5)
		local live=LiveActors.new(folder,battle)
		live:Sync(os.clock());live:Publish(os.clock())
		local unit=battle.units[1];local actor=live.actors[unit.id]
		assert(actor.model:GetAttribute("GiantSize")==27.5)
		live:Respawn(unit,380,15)
		assert(actor.model:GetAttribute("GiantSize")==27.5)
		assert(battle:Snapshot(0).units[1].giantSize==27.5)
		live:Destroy()
	end)
	folder:Destroy()
	return results
end
return Checks
